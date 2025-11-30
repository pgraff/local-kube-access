#!/bin/bash
# Main script to deploy the complete AI workspace stack
# This script deploys all AI components in the correct order

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

print_step "=========================================="
print_step "AI Workspace Stack Deployment"
print_step "=========================================="
echo ""

# Phase 1: Namespace Setup
print_step "Phase 1: Creating namespace..."
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    print_warning "Namespace $NAMESPACE already exists"
else
    kubectl apply -f "$SCRIPT_DIR/../k8s/ai-namespace.yaml"
    print_success "Namespace $NAMESPACE created"
fi
echo ""

# Phase 2: Deploy MinIO
print_step "Phase 2: Deploying MinIO..."
if kubectl get deployment minio -n "$NAMESPACE" &>/dev/null; then
    print_warning "MinIO already deployed, skipping..."
else
    "$SCRIPT_DIR/deploy-minio.sh"
    print_success "MinIO deployed"
fi
echo ""

# Phase 3: Deploy Argo Workflows
print_step "Phase 3: Deploying Argo Workflows..."
if helm list -n argo | grep -q argo-workflows; then
    print_warning "Argo Workflows already deployed, skipping..."
else
    "$SCRIPT_DIR/deploy-argo-workflows.sh"
    print_success "Argo Workflows deployed"
fi
echo ""

# Phase 4: Deploy JupyterHub
print_step "Phase 4: Deploying JupyterHub..."
if helm list -n "$NAMESPACE" | grep -q jupyterhub; then
    print_warning "JupyterHub already deployed, skipping..."
else
    "$SCRIPT_DIR/deploy-jupyterhub.sh"
    print_success "JupyterHub deployed"
fi
echo ""

# Phase 5: Deploy Templates
print_step "Phase 5: Deploying templates..."
print_info "Creating Papermill Job template..."
kubectl apply -f "$SCRIPT_DIR/../k8s/papermill-job-template.yaml" || print_warning "Papermill Job template may already exist"
print_info "Creating CronJob template..."
kubectl apply -f "$SCRIPT_DIR/../k8s/cronjob-template.yaml" || print_warning "CronJob template may already exist"
print_info "Creating Argo Workflow templates..."
kubectl apply -f "$SCRIPT_DIR/../k8s/argo-papermill-template.yaml" || print_warning "Argo template may already exist"
kubectl apply -f "$SCRIPT_DIR/../k8s/argo-dag-template.yaml" || print_warning "Argo DAG template may already exist"
print_success "All templates deployed"
echo ""

# Final status
print_step "=========================================="
print_success "AI Workspace Stack Deployment Complete!"
print_step "=========================================="
echo ""
echo "Access URLs (via Tailscale):"
echo "  • JupyterHub:    http://jupyterhub.tailc2013b.ts.net"
echo "  • Argo Workflows: http://argo.tailc2013b.ts.net"
echo "  • MinIO Console:  http://minio.tailc2013b.ts.net"
echo ""
echo "JupyterHub credentials:"
echo "  • Username: any (dummy authenticator)"
echo "  • Password: jupyterhub"
echo ""
echo "MinIO credentials:"
echo "  • Access Key: minioadmin"
echo "  • Secret Key: minioadmin"
echo ""
echo "Check status:"
echo "  ./ai/scripts/ai-status-check.sh"
echo ""

