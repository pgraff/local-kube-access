#!/bin/bash
# Setup local Docker registry in the cluster

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config-rke2-cluster.yaml}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

export KUBECONFIG="$KUBECONFIG_FILE"

print_info "Setting up local Docker registry in cluster..."

# Apply registry deployment
kubectl apply -f "$SCRIPT_DIR/../twin-service/k8s/local-registry.yaml"

# Wait for registry to be ready
print_info "Waiting for registry to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/docker-registry -n docker-registry

# Get registry service IP
REGISTRY_IP=$(kubectl get service docker-registry -n docker-registry -o jsonpath='{.spec.clusterIP}')
REGISTRY_HOST="docker-registry.docker-registry.svc.cluster.local"

print_info "Registry is ready!"
echo ""
echo "Registry endpoint: $REGISTRY_HOST:5000"
echo "Registry IP: $REGISTRY_IP:5000"
echo ""
echo "To push your image:"
echo "  1. Tag: docker tag twin-service:latest $REGISTRY_HOST:5000/twin-service:latest"
echo "  2. Port-forward: kubectl port-forward -n docker-registry service/docker-registry 5000:5000"
echo "  3. Push: docker push $REGISTRY_HOST:5000/twin-service:latest"
echo ""
echo "Or use the automated script:"
echo "  ./iot/scripts/push-twin-service-to-registry.sh"
