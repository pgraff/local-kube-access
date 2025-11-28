#!/bin/bash
# Push twin-service image to local cluster registry

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

# Check if image exists locally
if ! docker images | grep -q "twin-service.*latest"; then
    print_error "twin-service:latest image not found locally"
    echo ""
    echo "Build it first:"
    echo "  cd iot/twin-service && ./build.sh"
    exit 1
fi

# Check if registry exists
if ! kubectl get service docker-registry -n docker-registry &>/dev/null; then
    print_warning "Local registry not found. Setting it up..."
    "$SCRIPT_DIR/setup-local-registry.sh"
    sleep 5
fi

REGISTRY_HOST="docker-registry.docker-registry.svc.cluster.local"
IMAGE_NAME="$REGISTRY_HOST:5000/twin-service:latest"

print_info "Tagging image..."
docker tag twin-service:latest "$IMAGE_NAME"
print_success "Image tagged"

print_info "Starting port-forward to registry..."
# Start port-forward in background
kubectl port-forward -n docker-registry service/docker-registry 5000:5000 > /tmp/registry-port-forward.log 2>&1 &
PF_PID=$!

# Wait for port-forward to be ready
sleep 3

# Check if port-forward is working
if ! curl -s http://localhost:5000/v2/ > /dev/null 2>&1; then
    print_error "Port-forward not working. Check logs: /tmp/registry-port-forward.log"
    kill $PF_PID 2>/dev/null || true
    exit 1
fi

print_success "Port-forward active (PID: $PF_PID)"

print_info "Pushing image to registry..."
if docker push "$IMAGE_NAME"; then
    print_success "Image pushed successfully!"
else
    print_error "Failed to push image"
    kill $PF_PID 2>/dev/null || true
    exit 1
fi

# Stop port-forward
kill $PF_PID 2>/dev/null || true
print_info "Port-forward stopped"

echo ""
print_success "Image is now available in cluster registry!"
echo ""
echo "Update deployment.yaml:"
echo "  image: $IMAGE_NAME"
echo ""
echo "Then deploy:"
echo "  kubectl apply -f iot/twin-service/k8s/deployment.yaml"
echo "  kubectl scale deployment twin-service -n iot --replicas=2"

