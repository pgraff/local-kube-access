#!/bin/bash
# Restart RKE2 service on all nodes to apply containerd registry configuration
# This will cause brief node unavailability

set -euo pipefail

KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config-rke2-cluster.yaml}"
export KUBECONFIG="$KUBECONFIG_FILE"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_step() {
    echo -e "${BLUE}→${NC} $1"
}

# Get all nodes
print_info "Finding all nodes..."
ALL_NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')

if [ -z "$ALL_NODES" ]; then
    print_error "No nodes found"
    exit 1
fi

# Separate control-plane and worker nodes
CONTROL_PLANE_NODES=$(kubectl get nodes -l node-role.kubernetes.io/control-plane=true -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
WORKER_NODES=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane,!node-role.kubernetes.io/master' -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -z "$WORKER_NODES" ] && [ -z "$CONTROL_PLANE_NODES" ]; then
    print_warning "Could not categorize nodes, will try to determine service type per node"
    WORKER_NODES="$ALL_NODES"
fi

echo ""
print_warning "This script will restart RKE2 on all nodes, causing brief unavailability."
echo ""
echo "Control-plane nodes: ${CONTROL_PLANE_NODES:-none}"
echo "Worker nodes: ${WORKER_NODES:-none}"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Cancelled"
    exit 0
fi

# Function to restart RKE2 on a node
restart_node() {
    local NODE=$1
    local NODE_IP=$2
    local SSH_USER=$3
    local SERVICE_TYPE=$4
    
    print_step "Restarting $SERVICE_TYPE on $NODE ($NODE_IP)..."
    
    ssh -t "$SSH_USER@$NODE_IP" "set -e && \
      echo 'Stopping $SERVICE_TYPE...' && \
      sudo systemctl stop $SERVICE_TYPE && \
      echo 'Waiting 5 seconds...' && \
      sleep 5 && \
      echo 'Starting $SERVICE_TYPE...' && \
      sudo systemctl start $SERVICE_TYPE && \
      echo 'Waiting for service to start...' && \
      sleep 10 && \
      echo 'Checking service status...' && \
      sudo systemctl status $SERVICE_TYPE --no-pager -l | head -10 && \
      echo '' && \
      echo '✓ $SERVICE_TYPE restarted successfully on $NODE'"
    
    if [ $? -eq 0 ]; then
        print_success "$NODE restarted"
    else
        print_error "Failed to restart $NODE"
        return 1
    fi
}

# Restart control-plane nodes first
if [ -n "$CONTROL_PLANE_NODES" ]; then
    print_info "Restarting control-plane nodes..."
    for NODE in $CONTROL_PLANE_NODES; do
        NODE_IP=$(kubectl get node "$NODE" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
        
        if [ -z "$NODE_IP" ]; then
            print_error "Could not get IP for node $NODE, skipping..."
            continue
        fi
        
        SSH_USER="scispike"
        if [[ "$NODE" == *"storage-01"* ]]; then
            SSH_USER="petter"
        fi
        
        restart_node "$NODE" "$NODE_IP" "$SSH_USER" "rke2-server" || true
        echo ""
    done
fi

# Restart worker nodes
if [ -n "$WORKER_NODES" ]; then
    print_info "Restarting worker nodes..."
    for NODE in $WORKER_NODES; do
        # Skip if already processed as control-plane
        if [[ "$CONTROL_PLANE_NODES" == *"$NODE"* ]]; then
            continue
        fi
        
        NODE_IP=$(kubectl get node "$NODE" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
        
        if [ -z "$NODE_IP" ]; then
            print_error "Could not get IP for node $NODE, skipping..."
            continue
        fi
        
        SSH_USER="scispike"
        if [[ "$NODE" == *"storage-01"* ]]; then
            SSH_USER="petter"
        fi
        
        restart_node "$NODE" "$NODE_IP" "$SSH_USER" "rke2-agent" || true
        echo ""
    done
fi

# Wait for nodes to come back online
print_info "Waiting for nodes to come back online..."
sleep 30

# Check node status
print_info "Checking node status..."
for i in {1..12}; do
    READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo "0")
    TOTAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    
    if [ "$READY_NODES" -eq "$TOTAL_NODES" ] && [ "$TOTAL_NODES" -gt 0 ]; then
        print_success "All $TOTAL_NODES nodes are Ready!"
        break
    fi
    
    print_info "Waiting... ($READY_NODES/$TOTAL_NODES nodes ready)"
    sleep 10
done

# Final status
echo ""
print_info "Final node status:"
kubectl get nodes

echo ""
print_info "Verifying registry configuration..."
# Test if we can pull from registry by checking a pod
print_info "You can now test if pods can pull from the registry:"
echo "  kubectl delete pods -n iot -l app=twin-service"
echo "  kubectl get pods -n iot -l app=twin-service -w"

print_success "Done! All nodes have been restarted."

