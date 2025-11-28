#!/bin/bash
# Deploy Twin Service to Kubernetes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TWIN_SERVICE_DIR="$PROJECT_ROOT/iot/twin-service"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config-rke2-cluster.yaml}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Check prerequisites
print_info "Checking prerequisites..."

if [ ! -f "$KUBECONFIG_FILE" ]; then
    print_error "Kubeconfig file not found: $KUBECONFIG_FILE"
    exit 1
fi

export KUBECONFIG="$KUBECONFIG_FILE"

if ! kubectl cluster-info &>/dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_success "Prerequisites check passed"

# Check if namespace exists
if ! kubectl get namespace iot &>/dev/null; then
    print_warning "IoT namespace does not exist. Creating..."
    kubectl create namespace iot
    print_success "IoT namespace created"
fi

# Check if Kafka is available
print_info "Checking Kafka cluster..."
if ! kubectl get kafka kafka-cluster -n kafka &>/dev/null; then
    print_warning "Kafka cluster not found. Twin service requires Kafka."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    print_success "Kafka cluster found"
fi

# Deploy twin service
print_info "Deploying twin service..."
cd "$TWIN_SERVICE_DIR"

if [ ! -f "k8s/deployment.yaml" ]; then
    print_error "Deployment file not found: k8s/deployment.yaml"
    exit 1
fi

# Apply deployment
kubectl apply -f k8s/deployment.yaml

print_success "Deployment applied"

# Wait for deployment
print_info "Waiting for deployment to be ready..."
if kubectl wait --for=condition=available --timeout=300s deployment/twin-service -n iot 2>/dev/null; then
    print_success "Deployment is ready"
else
    print_warning "Deployment not ready yet. Check status with:"
    echo "  kubectl get pods -n iot -l app=twin-service"
    echo "  kubectl logs -n iot -l app=twin-service"
fi

# Show status
echo ""
print_info "Deployment status:"
kubectl get pods -n iot -l app=twin-service

echo ""
print_info "Service status:"
kubectl get service -n iot twin-service

echo ""
print_success "Twin service deployment complete!"
echo ""
echo "To check logs:"
echo "  kubectl logs -n iot -l app=twin-service -f"
echo ""
echo "To access the API:"
echo "  kubectl port-forward -n iot service/twin-service 8080:8080"
echo "  curl http://localhost:8080/api/v1/twins"
