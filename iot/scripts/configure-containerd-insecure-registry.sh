#!/bin/bash
# Configure containerd on RKE2 nodes to allow insecure registry
# This allows pods to pull images from the HTTP registry

set -euo pipefail

KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config-rke2-cluster.yaml}"
export KUBECONFIG="$KUBECONFIG_FILE"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

REGISTRY_HOST="docker-registry.docker-registry.svc.cluster.local:5000"
REGISTRY_CONFIG_DIR="/etc/rancher/rke2"
REGISTRY_CONFIG_FILE="$REGISTRY_CONFIG_DIR/registries.yaml"

# Get all nodes (excluding control-plane if possible)
print_info "Finding nodes to configure..."
NODES=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane,!node-role.kubernetes.io/master' -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || kubectl get nodes -o jsonpath='{.items[*].metadata.name}')

if [ -z "$NODES" ]; then
    print_error "No nodes found"
    exit 1
fi

echo "Nodes to configure: $NODES"
echo ""

# Create registries.yaml content
REGISTRY_CONFIG=$(cat <<EOF
mirrors:
  "${REGISTRY_HOST}":
    endpoint:
      - "http://${REGISTRY_HOST}"
EOF
)

print_info "Registry configuration to apply:"
echo "$REGISTRY_CONFIG"
echo ""

# Process each node
for NODE in $NODES; do
    NODE_IP=$(kubectl get node "$NODE" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
    
    if [ -z "$NODE_IP" ]; then
        print_error "Could not get IP for node $NODE, skipping..."
        continue
    fi
    
    # Determine SSH username
    SSH_USER="scispike"
    if [[ "$NODE" == *"storage-01"* ]]; then
        SSH_USER="petter"
    fi
    
    print_info "Configuring $NODE ($NODE_IP) [user: $SSH_USER]..."
    
    # Create the config file on the node using printf to avoid heredoc issues
    ssh -t "$SSH_USER@$NODE_IP" "set -e && \
      echo 'Creating registry config directory...' && \
      sudo mkdir -p $REGISTRY_CONFIG_DIR && \
      echo 'Creating registry config file...' && \
      printf '%s\n' \
        'mirrors:' \
        '  \"docker-registry.docker-registry.svc.cluster.local:5000\":' \
        '    endpoint:' \
        '      - \"http://docker-registry.docker-registry.svc.cluster.local:5000\"' | \
      sudo tee $REGISTRY_CONFIG_FILE > /dev/null && \
      echo 'Registry config created:' && \
      sudo cat $REGISTRY_CONFIG_FILE && \
      echo '' && \
      echo '⚠️  IMPORTANT: You need to restart RKE2 service for this to take effect.' && \
      echo '   Run: sudo systemctl restart rke2-agent (on workers) or rke2-server (on control-plane)' && \
      echo '' && \
      echo '⚠️  WARNING: Restarting RKE2 will cause brief node unavailability.'"
    
    if [ $? -eq 0 ]; then
        print_success "Configuration created on $NODE"
        print_warning "You need to restart RKE2 service on $NODE for this to take effect"
    else
        print_error "Failed to configure $NODE"
    fi
    echo ""
done

print_info "Configuration complete!"
echo ""
print_warning "NEXT STEPS:"
echo "1. Restart RKE2 service on each node:"
echo "   - Workers: sudo systemctl restart rke2-agent"
echo "   - Control-plane: sudo systemctl restart rke2-server"
echo ""
echo "2. After restart, verify the configuration:"
echo "   kubectl get nodes"
echo ""
echo "3. Restart the twin-service pods:"
echo "   kubectl delete pods -n iot -l app=twin-service"

