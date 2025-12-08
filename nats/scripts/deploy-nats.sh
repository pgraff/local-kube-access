#!/bin/bash
# Deploy NATS with JetStream to Kubernetes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
NATS_DIR="$PROJECT_ROOT/nats"
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

# Create namespace
print_info "Creating NATS namespace..."
if kubectl get namespace nats &>/dev/null; then
    print_warning "NATS namespace already exists"
else
    kubectl apply -f "$NATS_DIR/k8s/nats-namespace.yaml"
    print_success "NATS namespace created"
fi

# Deploy NATS
print_info "Deploying NATS with JetStream..."

cd "$NATS_DIR/k8s"

# Apply ConfigMap
print_info "Applying NATS configuration..."
kubectl apply -f nats-configmap.yaml
print_success "ConfigMap applied"

# Apply StatefulSet and Services
print_info "Applying NATS StatefulSet and Services..."
kubectl apply -f nats-statefulset.yaml
print_success "StatefulSet and Services applied"

# Wait for StatefulSet to be ready
print_info "Waiting for NATS StatefulSet to be ready..."
if kubectl wait --for=condition=ready --timeout=300s statefulset/nats -n nats 2>/dev/null; then
    print_success "NATS StatefulSet is ready"
else
    print_warning "StatefulSet may still be starting. Check status with: kubectl get pods -n nats"
fi

# Show status
print_info "NATS deployment status:"
kubectl get pods -n nats
kubectl get svc -n nats

print_success "NATS deployment complete!"
echo ""
echo "To access NATS:"
echo "  ./nats/scripts/access-nats.sh"
echo ""
echo "To check NATS status:"
echo "  kubectl get pods -n nats"
echo "  kubectl logs -n nats nats-0"
