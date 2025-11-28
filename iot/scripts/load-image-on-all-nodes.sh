#!/bin/bash
# Load twin-service image on all nodes where pods are scheduled
# Run this script and enter sudo password when prompted

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

IMAGE_TAR="/tmp/twin-service.tar"

if [ ! -f "$IMAGE_TAR" ]; then
    print_error "Image tar not found: $IMAGE_TAR"
    exit 1
fi

# Get nodes where pods are scheduled
print_info "Finding nodes where twin-service pods are scheduled..."
NODES=$(kubectl get pods -n iot -l app=twin-service -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null | tr ' ' '\n' | sort -u)

if [ -z "$NODES" ]; then
    print_error "No pods found. Will load on all worker nodes..."
    NODES=$(kubectl get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n')
fi

echo "Nodes: $NODES"
echo ""

# Process each node
for NODE in $NODES; do
    NODE_IP=$(kubectl get node "$NODE" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    
    if [ -z "$NODE_IP" ]; then
        print_error "Could not get IP for $NODE, skipping..."
        continue
    fi
    
    print_info "Processing $NODE ($NODE_IP)..."
    
    # Copy file if needed
    if ! ssh scispike@$NODE_IP "test -f /tmp/twin-service.tar" 2>/dev/null; then
        print_info "Copying image to $NODE..."
        scp "$IMAGE_TAR" scispike@$NODE_IP:/tmp/twin-service.tar
        print_success "Copied to $NODE"
    else
        print_info "Image tar already exists on $NODE"
    fi
    
    # Load and tag image (will prompt for sudo password)
    print_info "Loading image on $NODE (enter sudo password when prompted)..."
    ssh -t scispike@$NODE_IP << 'REMOTE_SCRIPT'
set -e
echo "Importing image..."
sudo /var/lib/rancher/rke2/bin/ctr -a /run/k3s/containerd/containerd.sock -n k8s.io images import /tmp/twin-service.tar

echo "Listing images to find the imported image..."
IMAGES=$(sudo /var/lib/rancher/rke2/bin/ctr -a /run/k3s/containerd/containerd.sock -n k8s.io images ls)
echo "$IMAGES" | tail -5

# Try to find the image name
IMAGE_NAME=$(echo "$IMAGES" | grep -i "twin\|library" | head -1 | awk '{print $1}' || echo "")

if [ -z "$IMAGE_NAME" ]; then
    # If not found, try the most recent image or check by image ID
    echo "Image name not found with grep, trying alternative..."
    # Import might have created it as docker.io/library/twin-service:latest
    IMAGE_NAME="docker.io/library/twin-service:latest"
fi

echo "Tagging image as: docker-registry.docker-registry.svc.cluster.local:5000/twin-service:latest"
echo "Source image: $IMAGE_NAME"

# Try tagging with the found name
if sudo /var/lib/rancher/rke2/bin/ctr -a /run/k3s/containerd/containerd.sock -n k8s.io images tag "$IMAGE_NAME" docker-registry.docker-registry.svc.cluster.local:5000/twin-service:latest 2>/dev/null; then
    echo "✅ Tagged successfully"
else
    echo "⚠️  Tagging failed, trying with docker.io/library/twin-service:latest..."
    sudo /var/lib/rancher/rke2/bin/ctr -a /run/k3s/containerd/containerd.sock -n k8s.io images tag docker.io/library/twin-service:latest docker-registry.docker-registry.svc.cluster.local:5000/twin-service:latest || true
fi

echo "Verifying..."
sudo /var/lib/rancher/rke2/bin/ctr -a /run/k3s/containerd/containerd.sock -n k8s.io images ls | grep -i twin || echo "⚠️  No twin image found, but import may have succeeded"

echo "Cleaning up..."
rm -f /tmp/twin-service.tar
echo "✅ Done on $(hostname)"
REMOTE_SCRIPT
    
    if [ $? -eq 0 ]; then
        print_success "Image loaded on $NODE"
    else
        print_error "Failed to load image on $NODE"
    fi
    echo ""
done

# Restart pods
print_info "Restarting pods..."
kubectl delete pods -n iot -l app=twin-service 2>/dev/null || true

print_info "Waiting for pods to start..."
sleep 20

kubectl get pods -n iot -l app=twin-service

echo ""
print_success "Done! Monitor pods with:"
echo "  kubectl get pods -n iot -l app=twin-service -w"

