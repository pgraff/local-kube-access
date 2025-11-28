#!/bin/bash
# Script to clean up Ditto and related components from IoT stack
# This removes Ditto and MongoDB for Ditto, keeping other IoT components

set -e

KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"
NAMESPACE="iot"

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
print_status "Ditto Cleanup Script"
print_status "=========================================="
echo ""

# Confirm before proceeding
print_warning "This will remove:"
echo "  - All Ditto deployments and services"
echo "  - MongoDB for Ditto (Helm release and PVC)"
echo "  - Ditto Helm release"
echo ""
echo "This will KEEP:"
echo "  - Mosquitto"
echo "  - Hono"
echo "  - ThingsBoard"
echo "  - Node-RED"
echo "  - TimescaleDB"
echo "  - PostgreSQL for ThingsBoard"
echo "  - MongoDB for Hono"
echo ""

read -p "Are you sure you want to proceed? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_status "Cleanup cancelled"
    exit 0
fi

echo ""

# Step 1: Uninstall Ditto Helm release
print_step "Step 1: Uninstalling Ditto Helm release..."
if helm list -n "$NAMESPACE" | grep -q "^ditto "; then
    helm uninstall ditto -n "$NAMESPACE" || {
        print_warning "Helm uninstall failed, but continuing..."
    }
    print_status "Ditto Helm release uninstalled"
else
    print_status "Ditto Helm release not found (may already be removed)"
fi

# Step 2: Delete Ditto deployments manually (in case Helm didn't clean up)
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
    if kubectl get deployment "$deployment" -n "$NAMESPACE" &>/dev/null; then
        print_status "Deleting deployment: $deployment"
        kubectl delete deployment "$deployment" -n "$NAMESPACE" --ignore-not-found=true
    fi
done

# Step 3: Delete Ditto services
print_step "Step 3: Removing Ditto services..."
DITTO_SERVICES=(
    "ditto-connectivity"
    "ditto-dittoui"
    "ditto-gateway"
    "ditto-nginx"
    "ditto-policies"
    "ditto-swaggerui"
    "ditto-things"
    "ditto-thingssearch"
)

for service in "${DITTO_SERVICES[@]}"; do
    if kubectl get service "$service" -n "$NAMESPACE" &>/dev/null; then
        print_status "Deleting service: $service"
        kubectl delete service "$service" -n "$NAMESPACE" --ignore-not-found=true
    fi
done

# Step 4: Delete Ditto ConfigMaps and Secrets
print_step "Step 4: Removing Ditto ConfigMaps and Secrets..."
kubectl delete configmap -n "$NAMESPACE" -l app=ditto --ignore-not-found=true
kubectl delete secret -n "$NAMESPACE" -l app=ditto --ignore-not-found=true

# Also try to delete by name pattern
kubectl get configmap -n "$NAMESPACE" -o name | grep -i ditto | xargs -r kubectl delete -n "$NAMESPACE" --ignore-not-found=true
kubectl get secret -n "$NAMESPACE" -o name | grep -i ditto | xargs -r kubectl delete -n "$NAMESPACE" --ignore-not-found=true

# Step 5: Delete Ditto jobs and cronjobs
print_step "Step 5: Removing Ditto jobs and cronjobs..."
kubectl delete job -n "$NAMESPACE" -l app=ditto --ignore-not-found=true
kubectl delete cronjob -n "$NAMESPACE" -l app=ditto --ignore-not-found=true
kubectl get job -n "$NAMESPACE" -o name | grep -i ditto | xargs -r kubectl delete -n "$NAMESPACE" --ignore-not-found=true
kubectl get cronjob -n "$NAMESPACE" -o name | grep -i ditto | xargs -r kubectl delete -n "$NAMESPACE" --ignore-not-found=true

# Step 6: Uninstall MongoDB for Ditto
print_step "Step 6: Uninstalling MongoDB for Ditto..."
if helm list -n "$NAMESPACE" | grep -q "^mongodb-ditto "; then
    helm uninstall mongodb-ditto -n "$NAMESPACE" || {
        print_warning "Helm uninstall failed, but continuing..."
    }
    print_status "MongoDB for Ditto Helm release uninstalled"
else
    print_status "MongoDB for Ditto Helm release not found"
fi

# Step 7: Delete MongoDB for Ditto deployment and statefulset
print_step "Step 7: Removing MongoDB for Ditto resources..."
kubectl delete deployment mongodb-ditto -n "$NAMESPACE" --ignore-not-found=true
kubectl delete statefulset mongodb-ditto -n "$NAMESPACE" --ignore-not-found=true
kubectl delete service mongodb-ditto -n "$NAMESPACE" --ignore-not-found=true
kubectl delete configmap mongodb-ditto -n "$NAMESPACE" --ignore-not-found=true
kubectl delete secret mongodb-ditto -n "$NAMESPACE" --ignore-not-found=true

# Step 8: Delete MongoDB for Ditto PVC (with confirmation)
print_step "Step 8: Checking MongoDB for Ditto PVC..."
if kubectl get pvc mongodb-ditto -n "$NAMESPACE" &>/dev/null; then
    print_warning "MongoDB for Ditto PVC found (20Gi). This will delete all data!"
    read -p "Delete PVC? This cannot be undone! (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        kubectl delete pvc mongodb-ditto -n "$NAMESPACE"
        print_status "MongoDB for Ditto PVC deleted"
    else
        print_warning "PVC not deleted. You can delete it manually later:"
        echo "  kubectl delete pvc mongodb-ditto -n $NAMESPACE"
    fi
else
    print_status "MongoDB for Ditto PVC not found"
fi

# Step 9: Clean up any remaining Ditto pods
print_step "Step 9: Cleaning up any remaining Ditto pods..."
kubectl delete pod -n "$NAMESPACE" -l app=ditto --ignore-not-found=true
kubectl get pod -n "$NAMESPACE" -o name | grep -i ditto | xargs -r kubectl delete -n "$NAMESPACE" --ignore-not-found=true

# Step 10: Verify cleanup
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
print_status "Removed components:"
echo "  ✅ Ditto Helm release"
echo "  ✅ All Ditto deployments and services"
echo "  ✅ MongoDB for Ditto Helm release"
echo "  ✅ MongoDB for Ditto resources"
echo ""
print_status "Kept components:"
echo "  ✅ Mosquitto"
echo "  ✅ Hono"
echo "  ✅ ThingsBoard"
echo "  ✅ Node-RED"
echo "  ✅ TimescaleDB"
echo "  ✅ PostgreSQL for ThingsBoard"
echo "  ✅ MongoDB for Hono"
echo ""
print_warning "Note: If you chose not to delete the MongoDB PVC, you can delete it later:"
echo "  kubectl delete pvc mongodb-ditto -n $NAMESPACE"
echo ""

