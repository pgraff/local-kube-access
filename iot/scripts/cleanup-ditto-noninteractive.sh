#!/bin/bash
# Non-interactive version of cleanup-ditto.sh
# Use this if you want to skip confirmations (e.g., in automation)
# WARNING: This will delete data without confirmation!

set -e

KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"
NAMESPACE="iot"
DELETE_PVC="${DELETE_PVC:-no}"  # Set to "yes" to delete PVC

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check kubeconfig
if [ ! -f "$KUBECONFIG_FILE" ]; then
    print_error "Kubeconfig file not found at $KUBECONFIG_FILE"
    exit 1
fi
export KUBECONFIG="$KUBECONFIG_FILE"

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    print_error "Namespace $NAMESPACE does not exist"
    exit 1
fi

print_status "=========================================="
print_status "Ditto Cleanup Script (Non-Interactive)"
print_status "=========================================="
echo ""
print_warning "Running in non-interactive mode"
print_warning "PVC deletion: $DELETE_PVC"
echo ""

# Uninstall Ditto Helm release
print_step "Step 1: Uninstalling Ditto Helm release..."
if helm list -n "$NAMESPACE" | grep -q "^ditto "; then
    helm uninstall ditto -n "$NAMESPACE" || true
    print_status "Ditto Helm release uninstalled"
else
    print_status "Ditto Helm release not found"
fi

# Delete Ditto deployments
print_step "Step 2: Removing Ditto deployments..."
DITTO_DEPLOYMENTS=(
    "ditto-connectivity"
    "ditto-dittoui"
    "ditto-gateway"
    "ditto-nginx"
    "ditto-policies"
    "ditto-swaggerui"
    "ditto-things"
    "ditto-thingssearch"
)

for deployment in "${DITTO_DEPLOYMENTS[@]}"; do
    kubectl delete deployment "$deployment" -n "$NAMESPACE" --ignore-not-found=true
done

# Delete Ditto services
print_step "Step 3: Removing Ditto services..."
for service in "${DITTO_DEPLOYMENTS[@]}"; do
    kubectl delete service "$service" -n "$NAMESPACE" --ignore-not-found=true
done

# Delete Ditto ConfigMaps and Secrets
print_step "Step 4: Removing Ditto ConfigMaps and Secrets..."
kubectl delete configmap -n "$NAMESPACE" -l app=ditto --ignore-not-found=true
kubectl delete secret -n "$NAMESPACE" -l app=ditto --ignore-not-found=true
kubectl get configmap -n "$NAMESPACE" -o name 2>/dev/null | grep -i ditto | xargs -r kubectl delete -n "$NAMESPACE" --ignore-not-found=true || true
kubectl get secret -n "$NAMESPACE" -o name 2>/dev/null | grep -i ditto | xargs -r kubectl delete -n "$NAMESPACE" --ignore-not-found=true || true

# Delete Ditto jobs and cronjobs
print_step "Step 5: Removing Ditto jobs and cronjobs..."
kubectl delete job -n "$NAMESPACE" -l app=ditto --ignore-not-found=true
kubectl delete cronjob -n "$NAMESPACE" -l app=ditto --ignore-not-found=true
kubectl get job -n "$NAMESPACE" -o name 2>/dev/null | grep -i ditto | xargs -r kubectl delete -n "$NAMESPACE" --ignore-not-found=true || true
kubectl get cronjob -n "$NAMESPACE" -o name 2>/dev/null | grep -i ditto | xargs -r kubectl delete -n "$NAMESPACE" --ignore-not-found=true || true

# Uninstall MongoDB for Ditto
print_step "Step 6: Uninstalling MongoDB for Ditto..."
if helm list -n "$NAMESPACE" | grep -q "^mongodb-ditto "; then
    helm uninstall mongodb-ditto -n "$NAMESPACE" || true
    print_status "MongoDB for Ditto Helm release uninstalled"
else
    print_status "MongoDB for Ditto Helm release not found"
fi

# Delete MongoDB for Ditto resources
print_step "Step 7: Removing MongoDB for Ditto resources..."
kubectl delete deployment mongodb-ditto -n "$NAMESPACE" --ignore-not-found=true
kubectl delete statefulset mongodb-ditto -n "$NAMESPACE" --ignore-not-found=true
kubectl delete service mongodb-ditto -n "$NAMESPACE" --ignore-not-found=true
kubectl delete configmap mongodb-ditto -n "$NAMESPACE" --ignore-not-found=true
kubectl delete secret mongodb-ditto -n "$NAMESPACE" --ignore-not-found=true

# Delete MongoDB for Ditto PVC
print_step "Step 8: Handling MongoDB for Ditto PVC..."
if kubectl get pvc mongodb-ditto -n "$NAMESPACE" &>/dev/null; then
    if [ "$DELETE_PVC" = "yes" ]; then
        kubectl delete pvc mongodb-ditto -n "$NAMESPACE"
        print_status "MongoDB for Ditto PVC deleted"
    else
        print_warning "PVC not deleted (set DELETE_PVC=yes to delete)"
    fi
else
    print_status "MongoDB for Ditto PVC not found"
fi

# Clean up any remaining Ditto pods
print_step "Step 9: Cleaning up any remaining Ditto pods..."
kubectl delete pod -n "$NAMESPACE" -l app=ditto --ignore-not-found=true
kubectl get pod -n "$NAMESPACE" -o name 2>/dev/null | grep -i ditto | xargs -r kubectl delete -n "$NAMESPACE" --ignore-not-found=true || true

# Verify cleanup
print_step "Step 10: Verifying cleanup..."
echo ""
print_status "Remaining deployments in $NAMESPACE:"
kubectl get deployments -n "$NAMESPACE" | grep -v "ditto" || true

echo ""
print_status "Remaining Helm releases in $NAMESPACE:"
helm list -n "$NAMESPACE" | grep -v "ditto" || true

echo ""
print_status "=========================================="
print_status "Cleanup Complete!"
print_status "=========================================="
echo ""

