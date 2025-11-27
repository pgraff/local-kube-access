#!/bin/bash
# Script to access Kubecost UI via port-forwarding

PORT=9090
NAMESPACE="kubecost"
SERVICE="kubecost-cost-analyzer"
KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo "Error: Kubeconfig file not found at $KUBECONFIG_FILE"
    echo "Please ensure the kubeconfig file exists."
    exit 1
fi

# Kill any existing port-forwards
echo "Cleaning up any existing port-forwards..."
pkill -f "kubectl port-forward.*kubecost" 2>/dev/null || true
sleep 1

# Check if local port is in use
if lsof -i :$PORT > /dev/null 2>&1; then
    echo "Warning: Port $PORT is already in use locally."
    echo "Trying to use it anyway (may fail)..."
    echo ""
fi

echo "Setting up port-forwarding to Kubecost UI..."
echo ""
echo "Kubecost UI will be available at: http://localhost:$PORT"
echo ""
echo "Note: It may take a few minutes for Kubecost to gather metrics."
echo "A progress indicator will appear at the top of the UI."
echo ""
echo "Press Ctrl+C to stop the port-forward"
echo ""

# Use local kubeconfig to port-forward directly
export KUBECONFIG="$KUBECONFIG_FILE"
kubectl port-forward -n $NAMESPACE service/$SERVICE $PORT:9090

