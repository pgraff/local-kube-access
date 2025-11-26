#!/bin/bash
# Consolidated script to access all cluster services via port-forwarding
# This script starts all port-forwards in the background

KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"
PID_FILE="/tmp/k8s-access-all.pids"
LOG_DIR="/tmp/k8s-access-logs"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if kubeconfig exists
check_kubeconfig() {
    if [ ! -f "$KUBECONFIG_FILE" ]; then
        print_error "Kubeconfig file not found at $KUBECONFIG_FILE"
        echo "Please ensure the kubeconfig file exists."
        exit 1
    fi
    export KUBECONFIG="$KUBECONFIG_FILE"
}

# Function to stop all port-forwards
stop_all() {
    print_status "Stopping all port-forwards..."
    
    if [ -f "$PID_FILE" ]; then
        while read -r pid; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null
                print_status "Stopped process $pid"
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi
    
    # Also kill any remaining port-forwards
    pkill -f "kubectl port-forward" 2>/dev/null || true
    pkill -f "ssh.*-L.*8443.*8444.*k8s-cp-01" 2>/dev/null || true
    
    # Kill Rancher port-forward on remote (both kubectl and any SSH sessions)
    ssh scispike@k8s-cp-01 "pkill -f 'kubectl port-forward.*rancher' || true" 2>/dev/null || true
    
    # Clean up log files
    rm -rf "$LOG_DIR"
    
    print_status "All port-forwards stopped."
    exit 0
}

# Function to check if port is in use
check_port() {
    local port=$1
    # Check for LISTEN state only (ignore CLOSED/ESTABLISHED connections)
    if lsof -i :$port 2>/dev/null | grep -q "LISTEN"; then
        return 1  # Port is in use
    fi
    return 0  # Port is free
}

# Function to start a port-forward
start_port_forward() {
    local name=$1
    local namespace=$2
    local service=$3
    local local_port=$4
    local remote_port=$5
    local log_file="$LOG_DIR/${name}.log"
    
    # Check if port is in use
    if ! check_port "$local_port"; then
        print_warning "Port $local_port is already in use. Skipping $name..."
        return 1
    fi
    
    print_status "Starting $name on port $local_port..."
    
    # Start port-forward in background
    kubectl port-forward -n "$namespace" "service/$service" "$local_port:$remote_port" > "$log_file" 2>&1 &
    local pid=$!
    
    # Wait a moment to check if it started successfully
    sleep 2
    if ! kill -0 "$pid" 2>/dev/null; then
        print_error "Failed to start $name. Check $log_file for details."
        return 1
    fi
    
    # Save PID
    echo "$pid" >> "$PID_FILE"
    print_status "$name started (PID: $pid, Port: $local_port)"
    return 0
}

# Function to start Rancher (special case - uses SSH)
start_rancher() {
    local http_port=8443
    local https_port=8444
    
    # Check ports
    if ! check_port "$http_port" || ! check_port "$https_port"; then
        print_warning "Rancher ports ($http_port/$https_port) are in use. Skipping..."
        return 1
    fi
    
    print_status "Starting Rancher on ports $http_port (HTTP) and $https_port (HTTPS)..."
    
    # Kill any existing Rancher port-forwards on remote
    ssh scispike@k8s-cp-01 "pkill -f 'kubectl port-forward.*rancher' || true" 2>/dev/null
    sleep 1
    
    local log_file="$LOG_DIR/rancher.log"
    
    # First, ensure any existing port-forwards on remote are killed
    ssh scispike@k8s-cp-01 "pkill -f 'kubectl port-forward.*rancher' || true" 2>/dev/null
    sleep 1
    
    # Start kubectl port-forward on remote in background
    # Use nohup and redirect output so it persists after SSH session
    ssh scispike@k8s-cp-01 "nohup ~/kubectl port-forward -n cattle-system service/rancher $http_port:80 $https_port:443 > /tmp/rancher-pf.log 2>&1 < /dev/null &" 2>"$log_file"
    
    # Wait for remote port-forward to start
    sleep 3
    
    # Verify remote port-forward is running
    local remote_pf_running=$(ssh scispike@k8s-cp-01 "ps aux | grep '[k]ubectl port-forward.*rancher.*8443' | wc -l" 2>/dev/null || echo "0")
    if [ "$remote_pf_running" -eq "0" ]; then
        print_error "Failed to start kubectl port-forward on remote server."
        if [ -f "$log_file" ] && [ -s "$log_file" ]; then
            print_error "SSH log:"
            tail -5 "$log_file" | sed 's/^/  /'
        fi
        print_error "Check SSH connectivity and kubectl availability on k8s-cp-01"
        return 1
    fi
    
    # Now start local SSH tunnel to forward to the remote port-forward
    # Use -f -N to run in background without executing remote command
    ssh -f -N -L $http_port:localhost:$http_port -L $https_port:localhost:$https_port scispike@k8s-cp-01 \
        2>>"$log_file" 1>&2
    
    # Wait a moment for SSH tunnel to establish
    sleep 2
    
    # Give it time to establish the connection and start port-forwarding
    sleep 4
    
    # Find the SSH tunnel process PID (the one we just started)
    # Look for SSH process with our specific port forwarding (without the kubectl command part)
    local pid=$(ps aux | grep "ssh.*-f.*-N.*-L $http_port:localhost:$http_port.*-L $https_port:localhost:$https_port.*k8s-cp-01" | grep -v grep | awk '{print $2}' | head -1)
    
    # Verify ports are actually listening (this is the real test)
    local http_listening=false
    local https_listening=false
    
    if lsof -i :$http_port 2>/dev/null | grep -q LISTEN; then
        http_listening=true
    fi
    if lsof -i :$https_port 2>/dev/null | grep -q LISTEN; then
        https_listening=true
    fi
    
    # If ports are listening, it's working (even if we can't find the PID)
    if [ "$http_listening" = true ] || [ "$https_listening" = true ]; then
        if [ -n "$pid" ]; then
            echo "$pid" >> "$PID_FILE"
            print_status "Rancher started (PID: $pid, Ports: $http_port/$https_port)"
        else
            # Ports are listening but we couldn't find PID - still consider it success
            # Try to find any SSH process for Rancher
            local any_pid=$(ps aux | grep "ssh.*k8s-cp-01.*8443\|8444" | grep -v grep | awk '{print $2}' | head -1)
            if [ -n "$any_pid" ]; then
                echo "$any_pid" >> "$PID_FILE"
                print_status "Rancher started (PID: $any_pid, Ports: $http_port/$https_port)"
            else
                print_status "Rancher ports are listening (Ports: $http_port/$https_port)"
                print_warning "Could not determine PID, but ports are active."
            fi
        fi
        return 0
    fi
    
    # Ports are not listening - check if process exists
    if [ -z "$pid" ]; then
        print_error "Failed to start Rancher. Could not find SSH process and ports are not listening."
        if [ -f "$log_file" ] && [ -s "$log_file" ]; then
            print_error "Last few lines of log:"
            tail -5 "$log_file" | sed 's/^/  /'
        else
            print_error "No log output available. Check SSH connectivity to k8s-cp-01"
        fi
        return 1
    fi
    
    # Process exists but ports aren't listening - might need more time
    if ! kill -0 "$pid" 2>/dev/null; then
        print_error "Failed to start Rancher. SSH process died."
        if [ -f "$log_file" ] && [ -s "$log_file" ]; then
            print_error "Last few lines of log:"
            tail -5 "$log_file" | sed 's/^/  /'
        fi
        return 1
    fi
    
    # Process is running but ports not listening yet - give it more time
    print_warning "Rancher process is running (PID: $pid) but ports not listening yet."
    print_warning "This may be normal - waiting a bit longer..."
    sleep 3
    
    # Check again
    if lsof -i :$http_port 2>/dev/null | grep -q LISTEN || lsof -i :$https_port 2>/dev/null | grep -q LISTEN; then
        echo "$pid" >> "$PID_FILE"
        print_status "Rancher started (PID: $pid, Ports: $http_port/$https_port)"
        return 0
    fi
    
    # Still not listening - likely a real failure
    print_error "Rancher ports still not listening after extended wait."
    print_error "Process may be running but connection failed. Check SSH and kubectl on k8s-cp-01"
    return 1
}

# Main function
main() {
    # Handle stop command
    if [ "$1" == "stop" ]; then
        stop_all
    fi
    
    # Check if already running
    if [ -f "$PID_FILE" ]; then
        print_warning "Port-forwards may already be running."
        echo "Run '$0 stop' to stop them first, or continue anyway..."
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        stop_all
    fi
    
    # Check kubeconfig
    check_kubeconfig
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    # Initialize PID file
    > "$PID_FILE"
    
    print_status "Starting all cluster service port-forwards..."
    echo ""
    
    # Start all services
    start_rancher
    start_port_forward "longhorn" "longhorn-system" "longhorn-frontend" 8080 80
    start_port_forward "kubecost" "kubecost" "kubecost-cost-analyzer" 9090 9090
    start_port_forward "kafka-ui" "kafka" "kafka-ui" 8081 8080
    start_port_forward "kafka" "kafka" "kafka-cluster-kafka-bootstrap" 9092 9092
    
    echo ""
    print_status "All port-forwards started!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Service Access Points:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  🐄 Rancher:"
    echo "     HTTP:  http://localhost:8443"
    echo "     HTTPS: https://localhost:8444 (recommended)"
    echo ""
    echo "  🦌 Longhorn:"
    echo "     http://localhost:8080"
    echo ""
    echo "  💰 Kubecost:"
    echo "     http://localhost:9090"
    echo ""
    echo "  📊 Kafka UI:"
    echo "     http://localhost:8081"
    echo ""
    echo "  📨 Kafka Bootstrap:"
    echo "     localhost:9092"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_status "Port-forwards are running in the background."
    echo "Logs are available in: $LOG_DIR"
    echo ""
    echo "To stop all port-forwards, run:"
    echo "  ./kill-access-all.sh"
    echo "  Or: $0 stop"
    echo ""
    echo "Or press Ctrl+C to stop this script (port-forwards will continue running)"
    echo ""
    
    # Wait for user interrupt
    trap 'stop_all' INT TERM
    
    # Keep script running
    while true; do
        sleep 60
        # Check if any process died
        if [ -f "$PID_FILE" ]; then
            while read -r pid; do
                if ! kill -0 "$pid" 2>/dev/null; then
                    print_warning "Process $pid has stopped. Check logs in $LOG_DIR"
                fi
            done < "$PID_FILE"
        fi
    done
}

# Run main function
main "$@"

