#!/bin/bash
# Script to access Eclipse Ditto APIs via port-forwarding

PORT=8080
NAMESPACE="iot"
SERVICE="ditto-gateway"
KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo "Error: Kubeconfig file not found at $KUBECONFIG_FILE"
    echo "Please ensure the kubeconfig file exists."
    exit 1
fi

# Kill any existing port-forwards
echo "Cleaning up any existing port-forwards..."
pkill -f "kubectl port-forward.*ditto" 2>/dev/null || true
sleep 1

# Check if local port is in use
if lsof -i :$PORT > /dev/null 2>&1; then
    echo "Warning: Port $PORT is already in use locally."
    echo "Trying to use it anyway (may fail)..."
    echo ""
fi

echo "Setting up port-forwarding to Eclipse Ditto..."
echo ""
echo "Eclipse Ditto API will be available at: http://localhost:$PORT"
echo ""
echo "API Endpoints:"
echo "  - REST API: http://localhost:$PORT/api"
echo "  - Things API: http://localhost:$PORT/api/2/things"
echo "  - Policies API: http://localhost:$PORT/api/2/policies"
echo "  - Search API: http://localhost:$PORT/api/2/search"
echo ""
echo "Example:"
echo "  curl http://localhost:$PORT/api/2/things"
echo ""
echo "Press Ctrl+C to stop the port-forward"
echo ""

# Use local kubeconfig to port-forward directly
export KUBECONFIG="$KUBECONFIG_FILE"

# Try to find Ditto gateway service (try multiple service names)
SERVICE=$(kubectl get svc -n $NAMESPACE -o name | grep -i ditto | grep -i gateway | head -1 | sed 's|service/||' || \
         kubectl get svc -n $NAMESPACE | grep -i ditto | head -1 | awk '{print $1}' || echo "ditto-gateway")

if kubectl get svc -n $NAMESPACE $SERVICE &>/dev/null; then
    kubectl port-forward -n $NAMESPACE service/$SERVICE $PORT:8080
else
    echo "Warning: Ditto gateway service not found. Is Ditto deployed?"
    echo "Available services in $NAMESPACE namespace:"
    kubectl get svc -n $NAMESPACE
    exit 1
fi

