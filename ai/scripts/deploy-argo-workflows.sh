#!/bin/bash
# Deploy Argo Workflows into the cluster using Helm

set -euo pipefail

KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config-rke2-cluster.yaml}"
NAMESPACE="argo"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

if [ ! -f "$KUBECONFIG_FILE" ]; then
  error "Kubeconfig not found at $KUBECONFIG_FILE"
  exit 1
fi

export KUBECONFIG="$KUBECONFIG_FILE"

if ! command -v helm >/dev/null 2>&1; then
  error "helm not found. Please install Helm 3.x."
  exit 1
fi

info "Ensuring namespace '$NAMESPACE' exists..."
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

info "Adding Argo Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || warn "Argo repo may already exist"
helm repo update >/dev/null 2>&1 || warn "Helm repo update failed (offline?)"

VALUES_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/k8s/argo-workflows-values.yaml"

info "Installing / upgrading Argo Workflows..."
helm upgrade --install argo-workflows argo/argo-workflows \
  --namespace "$NAMESPACE" \
  -f "$VALUES_FILE"

info "Argo Workflows deployment triggered. Verify with:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl get svc -n $NAMESPACE"


