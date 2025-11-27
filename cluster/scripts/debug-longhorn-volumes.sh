#!/bin/bash
# Script to debug and fix Longhorn volume issues

KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"
export KUBECONFIG="$KUBECONFIG_FILE"
NAMESPACE="longhorn-system"

echo "=========================================="
echo "Longhorn Volume Debug Tool"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check problematic volumes
echo "=== Problematic Volumes ==="
echo ""

# ThingsBoard volume
TB_VOL="pvc-1e03c522-0144-4ef9-a98d-afd46195c1d1"
if kubectl get volume.longhorn.io -n "$NAMESPACE" "$TB_VOL" &>/dev/null; then
    TB_STATE=$(kubectl get volume.longhorn.io -n "$NAMESPACE" "$TB_VOL" -o jsonpath='{.status.state}' 2>/dev/null)
    TB_NODE=$(kubectl get volume.longhorn.io -n "$NAMESPACE" "$TB_VOL" -o jsonpath='{.status.currentNodeID}' 2>/dev/null)
    TB_ROBUSTNESS=$(kubectl get volume.longhorn.io -n "$NAMESPACE" "$TB_VOL" -o jsonpath='{.status.robustness}' 2>/dev/null)
    
    echo "ThingsBoard Volume ($TB_VOL):"
    echo "  State: $TB_STATE"
    echo "  Node: ${TB_NODE:-none}"
    echo "  Robustness: ${TB_ROBUSTNESS:-unknown}"
    
    # Check engine
    TB_ENGINE=$(kubectl get engine.longhorn.io -n "$NAMESPACE" "${TB_VOL}-e-0" -o jsonpath='{.status.currentState}' 2>/dev/null || echo "not found")
    echo "  Engine State: $TB_ENGINE"
    
    # Check replicas
    TB_REPLICAS=$(kubectl get replicas.longhorn.io -n "$NAMESPACE" | grep "$TB_VOL" | grep -c "running" || echo "0")
    TB_TOTAL_REPLICAS=$(kubectl get replicas.longhorn.io -n "$NAMESPACE" | grep "$TB_VOL" | wc -l)
    echo "  Replicas: $TB_REPLICAS/$TB_TOTAL_REPLICAS running"
    echo ""
    
    if [ "$TB_STATE" = "attaching" ] || [ "$TB_STATE" = "detaching" ]; then
        print_warning "Volume is stuck in $TB_STATE state"
        echo "  Attempting to force detach..."
        kubectl patch volume.longhorn.io -n "$NAMESPACE" "$TB_VOL" --type merge -p '{"spec":{"nodeID":""}}' 2>/dev/null
        print_status "Volume detachment requested"
    fi
fi

# MongoDB Hono volume
MONGO_VOL="pvc-5b1dcdb4-8364-42de-962b-c91d4b12ea06"
if kubectl get volume.longhorn.io -n "$NAMESPACE" "$MONGO_VOL" &>/dev/null; then
    MONGO_STATE=$(kubectl get volume.longhorn.io -n "$NAMESPACE" "$MONGO_VOL" -o jsonpath='{.status.state}' 2>/dev/null)
    MONGO_NODE=$(kubectl get volume.longhorn.io -n "$NAMESPACE" "$MONGO_VOL" -o jsonpath='{.status.currentNodeID}' 2>/dev/null)
    
    echo "MongoDB Hono Volume ($MONGO_VOL):"
    echo "  State: $MONGO_STATE"
    echo "  Node: ${MONGO_NODE:-none}"
    
    # Check replicas
    MONGO_REPLICAS=$(kubectl get replicas.longhorn.io -n "$NAMESPACE" | grep "$MONGO_VOL" | grep -c "running" || echo "0")
    MONGO_TOTAL_REPLICAS=$(kubectl get replicas.longhorn.io -n "$NAMESPACE" | grep "$MONGO_VOL" | wc -l)
    echo "  Replicas: $MONGO_REPLICAS/$MONGO_TOTAL_REPLICAS running"
    
    if [ "$MONGO_REPLICAS" -eq 0 ] && [ "$MONGO_TOTAL_REPLICAS" -gt 0 ]; then
        print_warning "All replicas are stopped!"
        echo "  This volume may need to be recreated or repaired"
    fi
    echo ""
fi

echo "=== All Volumes Status ==="
kubectl get volumes.longhorn.io -n "$NAMESPACE" -o wide | grep -E "NAME|pvc-1e03c522|pvc-5b1dcdb4|pvc-4c615e69|pvc-7b73baf8"
echo ""

echo "=== Recommendations ==="
echo ""
echo "1. For stuck volumes, try:"
echo "   - Access Longhorn UI: ./cluster/scripts/access-longhorn.sh"
echo "   - Manually detach/attach volumes in UI"
echo "   - Check volume events and logs"
echo ""
echo "2. For volumes with stopped replicas:"
echo "   - May need to recreate the volume"
echo "   - Or restore from backup if available"
echo ""
echo "3. If volumes won't attach:"
echo "   - Check Longhorn node status: kubectl get nodes.longhorn.io -n $NAMESPACE"
echo "   - Check instance managers: kubectl get instancemanagers.longhorn.io -n $NAMESPACE"
echo "   - Check Longhorn manager logs: kubectl logs -n $NAMESPACE -l app=longhorn-manager --tail=50"
echo ""

