#!/bin/bash
# Load twin-service image on all nodes where pods are scheduled
# This script will prompt for sudo password on each node

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

# Get nodes where pods are scheduled
print_info "Finding nodes where twin-service pods are scheduled..."
NODES=$(kubectl get pods -n iot -l app=twin-service -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null | tr ' ' '\n' | sort -u)

if [ -z "$NODES" ]; then
    print_error "No pods found. Deploying pods first..."
    exit 1
fi

echo "Nodes: $NODES"
echo ""

# Process each node
for NODE in $NODES; do
    NODE_IP=$(kubectl get node "$NODE" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
    
    print_info "Processing $NODE ($NODE_IP)..."
    
    # Check if file exists
    if ! ssh scispike@$NODE_IP "test -f /tmp/twin-service.tar" 2>/dev/null; then
        print_error "Image tar not found on $NODE. Copying..."
        scp /tmp/twin-service.tar scispike@$NODE_IP:/tmp/twin-service.tar
        print_success "Copied to $NODE"
    else
        print_info "Image tar already exists on $NODE"
    fi
    
    # Load and tag image (will prompt for sudo password)
    print_info "Loading image on $NODE (will prompt for sudo password)..."
    ssh -t scispike@$NODE_IP << 'REMOTE_SCRIPT'
set -e
CTR_BIN="/var/lib/rancher/rke2/bin/ctr"
CONTAINERD_SOCK="/run/k3s/containerd/containerd.sock"

echo "Importing image into containerd..."
# Import without --base-name first to see what happens
IMPORT_OUTPUT=$(sudo $CTR_BIN -a $CONTAINERD_SOCK -n k8s.io images import /tmp/twin-service.tar 2>&1 || true)
echo "$IMPORT_OUTPUT"

echo ""
echo "Checking for imported image..."
# Try to find the image - it might be docker.io/library/twin-service:latest
if sudo $CTR_BIN -a $CONTAINERD_SOCK -n k8s.io images ls 2>&1 | grep -q "twin-service"; then
    echo "Found twin-service image"
    IMAGE_NAME=$(sudo $CTR_BIN -a $CONTAINERD_SOCK -n k8s.io images ls 2>&1 | grep "twin-service" | head -1 | awk '{print $1}')
    echo "Image name: $IMAGE_NAME"
else
    echo "Image not found in listing, trying default names..."
    # Try common names
    for NAME in "docker.io/library/twin-service:latest" "twin-service:latest"; do
        if sudo $CTR_BIN -a $CONTAINERD_SOCK -n k8s.io images tag "$NAME" docker-registry.docker-registry.svc.cluster.local:5000/twin-service:latest 2>/dev/null; then
            echo "✓ Successfully tagged $NAME"
            IMAGE_NAME="$NAME"
            break
        fi
    done
fi

echo ""
echo "Tagging image for registry..."
if [ -n "$IMAGE_NAME" ]; then
    sudo $CTR_BIN -a $CONTAINERD_SOCK -n k8s.io images tag "$IMAGE_NAME" docker-registry.docker-registry.svc.cluster.local:5000/twin-service:latest
else
    # Last resort: try both common names
    sudo $CTR_BIN -a $CONTAINERD_SOCK -n k8s.io images tag docker.io/library/twin-service:latest docker-registry.docker-registry.svc.cluster.local:5000/twin-service:latest || \
    sudo $CTR_BIN -a $CONTAINERD_SOCK -n k8s.io images tag twin-service:latest docker-registry.docker-registry.svc.cluster.local:5000/twin-service:latest
fi

echo ""
echo "Verifying tagged image..."
sudo $CTR_BIN -a $CONTAINERD_SOCK -n k8s.io images ls 2>&1 | grep -i "docker-registry\|twin" || echo "⚠ Warning: Image not visible in listing"

echo ""
echo "Cleaning up..."
rm -f /tmp/twin-service.tar
echo "✅ Image import completed!"
REMOTE_SCRIPT
    
    if [ $? -eq 0 ]; then
        print_success "Image loaded on $NODE"
    else
        print_error "Failed to load image on $NODE"
    fi
    echo ""
done

# Restart pods
print_info "Restarting pods to use loaded images..."
kubectl delete pods -n iot -l app=twin-service 2>/dev/null || true

print_info "Waiting for pods to start..."
sleep 15

kubectl get pods -n iot -l app=twin-service

echo ""
print_success "Done! Monitor pods with:"
echo "  kubectl get pods -n iot -l app=twin-service -w"
echo "  kubectl logs -n iot -l app=twin-service -f"

