#!/bin/bash
# Script to monitor cluster recovery after power failure

KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"
export KUBECONFIG="$KUBECONFIG_FILE"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Check if cluster is accessible
check_cluster_accessible() {
    if timeout 5 kubectl cluster-info &>/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check node status
check_nodes() {
    echo ""
    print_header "Node Status"
    
    if ! check_cluster_accessible; then
        print_error "Cluster is not accessible yet"
        return 1
    fi
    
    local nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    local ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo "0")
    local not_ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready " | wc -l)
    
    echo "Total Nodes: $nodes"
    echo "Ready: $ready_nodes"
    echo "Not Ready: $not_ready_nodes"
    echo ""
    
    if [ "$nodes" -eq 0 ]; then
        print_warning "No nodes found - cluster may still be initializing"
        return 1
    fi
    
    kubectl get nodes -o wide
    echo ""
    
    # Check for specific issues
    local not_ready=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready " || true)
    if [ -n "$not_ready" ]; then
        echo "Not Ready Nodes:"
        echo "$not_ready" | while read -r line; do
            local node_name=$(echo "$line" | awk '{print $1}')
            local status=$(echo "$line" | awk '{print $2}')
            print_warning "  $node_name: $status"
            
            # Get node conditions
            local conditions=$(kubectl describe node "$node_name" 2>/dev/null | grep -A 5 "Conditions:" | tail -4 || echo "")
            if [ -n "$conditions" ]; then
                echo "$conditions" | sed 's/^/    /'
            fi
        done
        echo ""
    fi
    
    if [ "$ready_nodes" -eq "$nodes" ] && [ "$nodes" -gt 0 ]; then
        print_status "All nodes are Ready!"
        return 0
    else
        return 1
    fi
}

# Check system pods
check_system_pods() {
    echo ""
    print_header "System Pods Status"
    
    if ! check_cluster_accessible; then
        print_error "Cluster is not accessible yet"
        return 1
    fi
    
    # Check kube-system namespace
    local total_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l)
    local ready_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c " Running " || echo "0")
    local pending_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c " Pending " || echo "0")
    local crash_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c " CrashLoopBackOff\|Error" || echo "0")
    
    echo "kube-system namespace:"
    echo "  Total Pods: $total_pods"
    echo "  Running: $ready_pods"
    echo "  Pending: $pending_pods"
    echo "  CrashLoopBackOff/Error: $crash_pods"
    echo ""
    
    if [ "$crash_pods" -gt 0 ]; then
        print_warning "Pods in error state:"
        kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -E "CrashLoopBackOff|Error" | while read -r line; do
            local pod_name=$(echo "$line" | awk '{print $1}')
            local status=$(echo "$line" | awk '{print $3}')
            print_warning "  $pod_name: $status"
        done
        echo ""
    fi
    
    # Check other critical namespaces
    for ns in cattle-system longhorn-system kafka iot; do
        if kubectl get namespace "$ns" &>/dev/null 2>&1; then
            local ns_pods=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l)
            local ns_ready=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -c " Running " || echo "0")
            if [ "$ns_pods" -gt 0 ]; then
                echo "$ns namespace: $ns_ready/$ns_pods pods running"
            fi
        fi
    done
    echo ""
}

# Check storage (Longhorn)
check_storage() {
    echo ""
    print_header "Storage Status (Longhorn)"
    
    if ! check_cluster_accessible; then
        print_error "Cluster is not accessible yet"
        return 1
    fi
    
    if ! kubectl get namespace longhorn-system &>/dev/null 2>&1; then
        print_warning "Longhorn namespace not found"
        return 1
    fi
    
    local longhorn_pods=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | wc -l)
    local longhorn_ready=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | grep -c " Running " || echo "0")
    
    echo "Longhorn Pods: $longhorn_ready/$longhorn_pods running"
    echo ""
    
    # Check volume status
    if kubectl get volumes.longhorn.io -n longhorn-system &>/dev/null 2>&1; then
        local total_volumes=$(kubectl get volumes.longhorn.io -n longhorn-system --no-headers 2>/dev/null | wc -l)
        local attached_volumes=$(kubectl get volumes.longhorn.io -n longhorn-system --no-headers 2>/dev/null | grep -c " attached " || echo "0")
        local detached_volumes=$(kubectl get volumes.longhorn.io -n longhorn-system --no-headers 2>/dev/null | grep -c " detached " || echo "0")
        
        echo "Volumes:"
        echo "  Total: $total_volumes"
        echo "  Attached: $attached_volumes"
        echo "  Detached: $detached_volumes"
        echo ""
        
        if [ "$detached_volumes" -gt 0 ]; then
            print_warning "Some volumes are detached - they may attach as nodes come online"
        fi
    fi
}

# Check critical services
check_critical_services() {
    echo ""
    print_header "Critical Services"
    
    if ! check_cluster_accessible; then
        print_error "Cluster is not accessible yet"
        return 1
    fi
    
    # Check Rancher
    if kubectl get namespace cattle-system &>/dev/null 2>&1; then
        local rancher_pods=$(kubectl get pods -n cattle-system -l app=rancher --no-headers 2>/dev/null | wc -l)
        local rancher_ready=$(kubectl get pods -n cattle-system -l app=rancher --no-headers 2>/dev/null | grep -c " Running " || echo "0")
        if [ "$rancher_pods" -gt 0 ]; then
            echo "Rancher: $rancher_ready/$rancher_pods pods running"
        fi
    fi
    
    # Check Kafka
    if kubectl get namespace kafka &>/dev/null 2>&1; then
        local kafka_pods=$(kubectl get pods -n kafka --no-headers 2>/dev/null | wc -l)
        local kafka_ready=$(kubectl get pods -n kafka --no-headers 2>/dev/null | grep -c " Running " || echo "0")
        if [ "$kafka_pods" -gt 0 ]; then
            echo "Kafka: $kafka_ready/$kafka_pods pods running"
        fi
    fi
    
    # Check IoT stack
    if kubectl get namespace iot &>/dev/null 2>&1; then
        local iot_pods=$(kubectl get pods -n iot --no-headers 2>/dev/null | wc -l)
        local iot_ready=$(kubectl get pods -n iot --no-headers 2>/dev/null | grep -c " Running " || echo "0")
        if [ "$iot_pods" -gt 0 ]; then
            echo "IoT Stack: $iot_ready/$iot_pods pods running"
        fi
    fi
    
    echo ""
}

# Main monitoring loop
main() {
    local continuous=${1:-false}
    local max_iterations=${2:-60}  # Default 60 iterations
    local iteration=0
    
    while true; do
        clear
        print_header "Cluster Recovery Monitor - $(date '+%Y-%m-%d %H:%M:%S')"
        
        # Check cluster accessibility
        if ! check_cluster_accessible; then
            print_error "Cluster is not accessible yet"
            echo ""
            echo "Waiting for cluster API server to come online..."
            echo "This may take several minutes after power restoration."
            echo ""
            echo "Press Ctrl+C to stop monitoring"
            
            if [ "$continuous" = false ]; then
                break
            fi
            
            sleep 10
            continue
        fi
        
        print_status "Cluster is accessible!"
        
        # Run all checks
        check_nodes
        check_system_pods
        check_storage
        check_critical_services
        
        # Summary
        echo ""
        print_header "Recovery Status"
        
        local all_nodes_ready=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready " | wc -l)
        if [ "$all_nodes_ready" -eq 0 ] && [ "$(kubectl get nodes --no-headers 2>/dev/null | wc -l)" -gt 0 ]; then
            print_status "✅ All nodes are Ready!"
            print_status "✅ Cluster appears to be healthy"
            echo ""
            echo "You can now run:"
            echo "  ./access-all.sh"
            echo ""
            
            if [ "$continuous" = false ]; then
                break
            fi
        else
            print_warning "⏳ Cluster is still recovering..."
            echo ""
            echo "Some nodes or services may still be starting up."
            echo "This is normal after a power failure."
        fi
        
        if [ "$continuous" = false ]; then
            break
        fi
        
        iteration=$((iteration + 1))
        if [ "$iteration" -ge "$max_iterations" ]; then
            print_warning "Reached maximum iterations ($max_iterations)"
            break
        fi
        
        echo ""
        echo "Next check in 30 seconds... (Press Ctrl+C to stop)"
        sleep 30
    done
}

# Parse arguments
if [ "$1" = "--continuous" ] || [ "$1" = "-c" ]; then
    main true "${2:-60}"
else
    main false
fi

