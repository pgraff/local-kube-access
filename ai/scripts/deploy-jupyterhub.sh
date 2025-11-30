#!/bin/bash
# Deploy JupyterHub for AI workspace
# This script deploys JupyterHub using Zero-to-JupyterHub Helm chart

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

if ! command -v helm &>/dev/null; then
    print_error "Helm is not installed. Please install Helm first."
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    print_error "Namespace $NAMESPACE does not exist. Create it first:"
    echo "  kubectl apply -f $SCRIPT_DIR/../k8s/ai-namespace.yaml"
    exit 1
fi

# Check if MinIO is deployed (required for JupyterHub configuration)
if ! kubectl get secret minio-credentials -n "$NAMESPACE" &>/dev/null; then
    print_warning "MinIO credentials not found. MinIO should be deployed first."
    print_warning "JupyterHub will still deploy but MinIO integration may not work."
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

print_step "Deploying JupyterHub..."

# Add JupyterHub Helm repository
print_info "Adding JupyterHub Helm repository..."
helm repo add jupyterhub https://hub.jupyter.org/helm-chart/ 2>/dev/null || print_warning "JupyterHub repo may already exist"
helm repo update

# Deploy JupyterHub
print_info "Installing JupyterHub..."
if helm list -n "$NAMESPACE" | grep -q jupyterhub; then
    print_warning "JupyterHub already deployed. Upgrading..."
    helm upgrade jupyterhub jupyterhub/jupyterhub \
        -n "$NAMESPACE" \
        -f "$SCRIPT_DIR/../k8s/jupyterhub-values.yaml" \
        --wait --timeout 15m
else
    helm install jupyterhub jupyterhub/jupyterhub \
        -n "$NAMESPACE" \
        -f "$SCRIPT_DIR/../k8s/jupyterhub-values.yaml" \
        --wait --timeout 15m
fi

print_info "Waiting for JupyterHub pods to be ready..."
kubectl wait --for=condition=ready pod -l app=jupyterhub -n "$NAMESPACE" --timeout=300s || {
    print_warning "Some JupyterHub pods may not be ready yet. Check status with:"
    echo "  kubectl get pods -n $NAMESPACE -l app=jupyterhub"
}

print_info "Creating JupyterHub Ingress..."
kubectl apply -f "$SCRIPT_DIR/../k8s/jupyterhub-ingress.yaml"

print_success "JupyterHub deployed successfully!"
echo ""
echo "JupyterHub URL: http://jupyterhub.tailc2013b.ts.net"
echo "Default password: jupyterhub (for all users)"
echo "Any username/password combination will work with dummy authenticator"

