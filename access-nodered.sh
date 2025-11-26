#!/bin/bash
# Script to access Node-RED via port-forwarding

PORT=1880
NAMESPACE="iot"
SERVICE="node-red"
KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo "Error: Kubeconfig file not found at $KUBECONFIG_FILE"
    echo "Please ensure the kubeconfig file exists."
    exit 1
fi

# Kill any existing port-forwards
echo "Cleaning up any existing port-forwards..."
pkill -f "kubectl port-forward.*node-red" 2>/dev/null || true
sleep 1

# Check if local port is in use
if lsof -i :$PORT > /dev/null 2>&1; then
    echo "Warning: Port $PORT is already in use locally."
    echo "Trying to use it anyway (may fail)..."
    echo ""
fi

echo "Setting up port-forwarding to Node-RED..."
echo ""
echo "Node-RED will be available at: http://localhost:$PORT"
echo ""
echo "Features:"
echo "  - Visual flow programming"
echo "  - Integration with ThingsBoard, Ditto, and Kafka"
echo "  - MQTT support"
echo "  - HTTP endpoints"
echo ""
echo "Press Ctrl+C to stop the port-forward"
echo ""

# Use local kubeconfig to port-forward directly
export KUBECONFIG="$KUBECONFIG_FILE"
kubectl port-forward -n $NAMESPACE service/$SERVICE $PORT:1880

