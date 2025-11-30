#!/bin/bash
# Uninstall the complete AI workspace stack

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config-rke2-cluster.yaml}"
NAMESPACE="ai"
ARGO_NAMESPACE="argo"

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

export KUBECONFIG="$KUBECONFIG_FILE"

# Confirm deletion
print_warning "This will delete ALL AI workspace components including:"
echo "  - JupyterHub (all user data)"
echo "  - MinIO (all buckets and data)"
echo "  - Argo Workflows"
echo "  - All CronJobs and Jobs"
echo "  - All PVCs (persistent data)"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_info "Uninstall cancelled"
    exit 0
fi

echo ""

# Uninstall JupyterHub
print_info "Uninstalling JupyterHub..."
if helm list -n "$NAMESPACE" | grep -q jupyterhub; then
    helm uninstall jupyterhub -n "$NAMESPACE" || print_warning "JupyterHub uninstall may have failed"
    print_info "JupyterHub uninstalled"
else
    print_warning "JupyterHub not found"
fi

# Uninstall Argo Workflows
print_info "Uninstalling Argo Workflows..."
if helm list -n "$ARGO_NAMESPACE" | grep -q argo-workflows; then
    helm uninstall argo-workflows -n "$ARGO_NAMESPACE" || print_warning "Argo Workflows uninstall may have failed"
    print_info "Argo Workflows uninstalled"
else
    print_warning "Argo Workflows not found"
fi

# Delete MinIO
print_info "Deleting MinIO..."
kubectl delete -f "$SCRIPT_DIR/../k8s/minio-deployment.yaml" --ignore-not-found=true 2>/dev/null || true
kubectl delete -f "$SCRIPT_DIR/../k8s/minio-service.yaml" --ignore-not-found=true 2>/dev/null || true
kubectl delete -f "$SCRIPT_DIR/../k8s/minio-secret.yaml" --ignore-not-found=true 2>/dev/null || true
kubectl delete -f "$SCRIPT_DIR/../k8s/minio-configmap.yaml" --ignore-not-found=true 2>/dev/null || true
kubectl delete -f "$SCRIPT_DIR/../k8s/minio-ingress.yaml" --ignore-not-found=true 2>/dev/null || true

# Delete Ingress resources
print_info "Deleting Ingress resources..."
kubectl delete -f "$SCRIPT_DIR/../k8s/jupyterhub-ingress.yaml" --ignore-not-found=true 2>/dev/null || true
kubectl delete -f "$SCRIPT_DIR/../k8s/argo-ingress.yaml" --ignore-not-found=true 2>/dev/null || true

# Delete Argo templates
print_info "Deleting Argo Workflow templates..."
kubectl delete -f "$SCRIPT_DIR/../k8s/argo-papermill-template.yaml" --ignore-not-found=true 2>/dev/null || true
kubectl delete -f "$SCRIPT_DIR/../k8s/argo-dag-template.yaml" --ignore-not-found=true 2>/dev/null || true

# Delete CronJobs and Jobs
print_info "Deleting CronJobs..."
kubectl delete cronjobs -n "$NAMESPACE" --all --ignore-not-found=true 2>/dev/null || true

print_info "Deleting Jobs..."
kubectl delete jobs -n "$NAMESPACE" -l app=papermill --ignore-not-found=true 2>/dev/null || true

# Delete PVCs (optional)
echo ""
read -p "Delete PVCs (persistent volumes)? This will delete all user data! (yes/no): " -r
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_warning "Deleting PVCs..."
    kubectl delete pvc -n "$NAMESPACE" --all --ignore-not-found=true 2>/dev/null || true
    print_info "PVCs deleted"
else
    print_info "PVCs preserved"
fi

# Delete namespace (optional)
echo ""
read -p "Delete '$NAMESPACE' namespace? (yes/no): " -r
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_warning "Deleting namespace..."
    kubectl delete namespace "$NAMESPACE" --ignore-not-found=true 2>/dev/null || true
    print_info "Namespace deleted"
else
    print_info "Namespace preserved"
fi

echo ""
print_info "AI workspace cleanup complete!"

