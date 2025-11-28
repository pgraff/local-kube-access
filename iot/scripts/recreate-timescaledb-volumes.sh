#!/bin/bash
# Safely recreate TimescaleDB volumes by deleting and recreating the StatefulSet
# This will delete all TimescaleDB data!

set -euo pipefail

KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config-rke2-cluster.yaml}"
export KUBECONFIG="$KUBECONFIG_FILE"

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

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

NAMESPACE="iot"
STATEFULSET="timescaledb"

print_warning "This script will DELETE all TimescaleDB data!"
echo ""
echo "It will:"
echo "  1. Scale down StatefulSet to 0"
echo "  2. Delete PVCs (which deletes Longhorn volumes)"
echo "  3. Scale StatefulSet back up (creates new volumes)"
echo ""

read -p "Continue? (yes/no) " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_info "Cancelled"
    exit 0
fi

# Step 1: Scale down StatefulSet
print_info "Step 1: Scaling down StatefulSet..."
kubectl scale statefulset -n "$NAMESPACE" "$STATEFULSET" --replicas=0

print_info "Waiting for pod to terminate..."
kubectl wait --for=delete pod -n "$NAMESPACE" "$STATEFULSET-0" --timeout=120s || true

# Step 2: Delete PVCs
print_info "Step 2: Deleting PVCs..."
kubectl delete pvc -n "$NAMESPACE" -l app=timescaledb

print_info "Waiting for PVCs to be deleted..."
sleep 10

# Step 3: Wait for Longhorn volumes to be deleted
print_info "Step 3: Waiting for Longhorn volumes to be deleted..."
for i in {1..30}; do
    VOLUMES=$(kubectl get volumes.longhorn.io -n longhorn-system 2>/dev/null | grep -E "pvc-7a74d07e|pvc-7f8a4ece" || echo "")
    if [ -z "$VOLUMES" ]; then
        print_success "Volumes deleted"
        break
    fi
    echo "Waiting for volumes to be deleted... ($i/30)"
    sleep 5
done

# Step 4: Scale StatefulSet back up
print_info "Step 4: Scaling StatefulSet back up..."
kubectl scale statefulset -n "$NAMESPACE" "$STATEFULSET" --replicas=1

print_info "Waiting for pod to start..."
sleep 10

# Step 5: Monitor pod status
print_info "Step 5: Monitoring pod status..."
kubectl get pods -n "$NAMESPACE" "$STATEFULSET-0" -w

print_success "Done! TimescaleDB should now have fresh volumes."

