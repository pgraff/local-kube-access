#!/bin/bash
# Load twin-service image directly on a cluster node
# This bypasses Docker Desktop networking issues

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config-rke2-cluster.yaml}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

export KUBECONFIG="$KUBECONFIG_FILE"

# Check if image tar exists
IMAGE_TAR="/tmp/twin-service.tar"
if [ ! -f "$IMAGE_TAR" ]; then
    print_error "Image tar not found: $IMAGE_TAR"
    echo ""
    echo "Build and save the image first:"
    echo "  cd iot/twin-service"
    echo "  ./build.sh"
    echo "  docker save twin-service:latest -o /tmp/twin-service.tar"
    exit 1
fi

# Get first node
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
NODE_IP=$(kubectl get node "$NODE" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

print_info "Target node: $NODE ($NODE_IP)"
print_info "Image tar: $IMAGE_TAR ($(du -h "$IMAGE_TAR" | cut -f1))"

# Check SSH access
print_info "Checking SSH access..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "scispike@$NODE_IP" "echo 'SSH OK'" 2>/dev/null; then
    print_warning "SSH key-based auth may not be set up"
    echo ""
    echo "You'll need to enter your password for:"
    echo "  1. SCP (to copy the image)"
    echo "  2. SSH (to load the image)"
    echo ""
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Copy image to node
print_info "Copying image to node..."
scp "$IMAGE_TAR" "scispike@$NODE_IP:/tmp/twin-service.tar"
print_success "Image copied to node"

# Load image on node
print_info "Loading image on node..."
print_warning "This requires sudo access. If passwordless sudo is not configured,"
print_warning "you'll need to run the commands manually on the node."
echo ""

# Try passwordless sudo first
if ssh "scispike@$NODE_IP" "sudo -n true" 2>/dev/null; then
    print_info "Passwordless sudo available, proceeding..."
    ssh "scispike@$NODE_IP" << 'REMOTE_SCRIPT'
set -e
echo "Importing image into containerd..."
sudo ctr -n k8s.io images import /tmp/twin-service.tar

echo "Tagging image for registry..."
sudo ctr -n k8s.io images tag \
  docker.io/library/twin-service:latest \
  docker-registry.docker-registry.svc.cluster.local:5000/twin-service:latest

echo "Verifying image..."
sudo ctr -n k8s.io images ls | grep twin-service

echo "Cleaning up..."
rm -f /tmp/twin-service.tar
REMOTE_SCRIPT
else
    print_warning "Passwordless sudo not available. Manual steps required:"
    echo ""
    echo "SSH to the node and run:"
    echo "  ssh scispike@$NODE_IP"
    echo "  sudo ctr -n k8s.io images import /tmp/twin-service.tar"
    echo "  sudo ctr -n k8s.io images tag docker.io/library/twin-service:latest docker-registry.docker-registry.svc.cluster.local:5000/twin-service:latest"
    echo "  sudo ctr -n k8s.io images ls | grep twin-service"
    echo "  rm -f /tmp/twin-service.tar"
    echo ""
    read -p "Press Enter after you've completed the manual steps on the node..."
fi

print_success "Image loaded and tagged on node!"

# Delete pods to force fresh pull
print_info "Deleting pods to force fresh pull..."
kubectl delete pods -n iot -l app=twin-service 2>/dev/null || true

print_info "Waiting for pods to start..."
sleep 10

# Check pod status
kubectl get pods -n iot -l app=twin-service

echo ""
print_success "Done! Pods should start pulling the image now."
echo ""
echo "Monitor with:"
echo "  kubectl get pods -n iot -l app=twin-service -w"
echo "  kubectl logs -n iot -l app=twin-service -f"

