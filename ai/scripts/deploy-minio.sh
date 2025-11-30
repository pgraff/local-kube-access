#!/bin/bash
# Deploy MinIO for AI workspace
# This script deploys MinIO with bucket initialization

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config-rke2-cluster.yaml}"
NAMESPACE="ai"

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

# Check prerequisites
if [ ! -f "$KUBECONFIG_FILE" ]; then
    print_error "Kubeconfig file not found: $KUBECONFIG_FILE"
    exit 1
fi

export KUBECONFIG="$KUBECONFIG_FILE"

if ! kubectl cluster-info &>/dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    print_error "Namespace $NAMESPACE does not exist. Create it first:"
    echo "  kubectl apply -f $SCRIPT_DIR/../k8s/ai-namespace.yaml"
    exit 1
fi

print_step "Deploying MinIO..."

# Deploy MinIO components
print_info "Creating MinIO Secret..."
kubectl apply -f "$SCRIPT_DIR/../k8s/minio-secret.yaml"

print_info "Creating MinIO ConfigMap..."
kubectl apply -f "$SCRIPT_DIR/../k8s/minio-configmap.yaml"

print_info "Creating MinIO PVC..."
kubectl apply -f "$SCRIPT_DIR/../k8s/minio-deployment.yaml" || true

print_info "Creating MinIO Service..."
kubectl apply -f "$SCRIPT_DIR/../k8s/minio-service.yaml"

print_info "Waiting for MinIO pod to be ready..."
kubectl wait --for=condition=ready pod -l app=minio -n "$NAMESPACE" --timeout=300s || {
    print_warning "MinIO pod not ready yet. Check status with:"
    echo "  kubectl get pods -n $NAMESPACE -l app=minio"
    exit 1
}

print_info "Creating notebook-artifacts bucket..."
# Wait a bit for MinIO to be fully ready
sleep 5

# Create bucket using MinIO client or API
kubectl run minio-client --rm -i --restart=Never \
    --image=minio/mc:latest \
    -n "$NAMESPACE" \
    -- sh -c "
    mc alias set local http://minio:9000 minioadmin minioadmin && \
    mc mb local/notebook-artifacts || mc ls local/notebook-artifacts || true && \
    echo 'Bucket notebook-artifacts ready'
    " || print_warning "Bucket creation may have failed, but MinIO is running"

print_info "Creating MinIO Ingress..."
kubectl apply -f "$SCRIPT_DIR/../k8s/minio-ingress.yaml"

print_success "MinIO deployed successfully!"
echo ""
echo "MinIO Console: http://minio.tailc2013b.ts.net"
echo "MinIO API: http://minio.ai.svc.cluster.local:9000"
echo "Bucket: notebook-artifacts"
echo "Access Key: minioadmin"
echo "Secret Key: minioadmin"

