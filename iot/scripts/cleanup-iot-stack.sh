#!/bin/bash
# Clean up IoT stack - remove all components

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config-rke2-cluster.yaml}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Confirm
print_warning "This will remove the entire IoT stack including:"
echo "  - All Helm releases (Hono, MongoDB, PostgreSQL)"
echo "  - All deployments (Mosquitto, ThingsBoard, Node-RED)"
echo "  - All services and ConfigMaps"
echo "  - All PVCs (persistent data)"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_info "Cleanup cancelled"
    exit 0
fi

echo ""

# Uninstall Helm releases
print_info "Uninstalling Helm releases..."
helm uninstall hono -n iot 2>/dev/null && print_success "Hono uninstalled" || print_warning "Hono not found"
helm uninstall mongodb-hono -n iot 2>/dev/null && print_success "MongoDB for Hono uninstalled" || print_warning "MongoDB for Hono not found"
helm uninstall postgresql-thingsboard -n iot 2>/dev/null && print_success "PostgreSQL uninstalled" || print_warning "PostgreSQL not found"

# Delete deployments
print_info "Deleting deployments..."
kubectl delete deployment -n iot mosquitto thingsboard node-red --ignore-not-found=true 2>/dev/null
print_success "Deployments deleted"

# Delete services
print_info "Deleting services..."
kubectl delete service -n iot mosquitto thingsboard node-red --ignore-not-found=true 2>/dev/null
print_success "Services deleted"

# Delete PVCs (optional)
echo ""
read -p "Delete PVCs (persistent volumes)? This will delete all data! (yes/no): " -r
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_warning "Deleting PVCs..."
    kubectl delete pvc -n iot --all --ignore-not-found=true 2>/dev/null
    print_success "PVCs deleted"
else
    print_info "PVCs preserved"
fi

# Clean up stuck pods
print_info "Cleaning up stuck pods..."
kubectl delete pod -n iot --all --force --grace-period=0 2>/dev/null || true

# Delete namespace (optional)
echo ""
read -p "Delete 'iot' namespace? (yes/no): " -r
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_warning "Deleting namespace..."
    kubectl delete namespace iot --ignore-not-found=true 2>/dev/null
    print_success "Namespace deleted"
else
    print_info "Namespace preserved"
fi

echo ""
print_success "IoT stack cleanup complete!"

