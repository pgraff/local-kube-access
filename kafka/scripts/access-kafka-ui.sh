#!/bin/bash
# Script to access Kafka UI via port-forwarding

PORT=8081
NAMESPACE="kafka"
SERVICE="kafka-ui"
KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo "Error: Kubeconfig file not found at $KUBECONFIG_FILE"
    echo "Please ensure the kubeconfig file exists."
    exit 1
fi

# Kill any existing port-forwards
echo "Cleaning up any existing port-forwards..."
pkill -f "kubectl port-forward.*kafka-ui" 2>/dev/null || true
sleep 1

# Check if local port is in use
if lsof -i :$PORT > /dev/null 2>&1; then
    echo "Warning: Port $PORT is already in use locally."
    echo "Trying to use it anyway (may fail)..."
    echo ""
fi

echo "Setting up port-forwarding to Kafka UI..."
echo ""
echo "Kafka UI will be available at: http://localhost:$PORT"
echo ""
echo "Note: Using port $PORT (8080 is used by Longhorn)"
echo ""
echo "Features:"
echo "  - View clusters, brokers, topics, and partitions"
echo "  - Browse messages and consumer groups"
echo "  - Create/delete topics"
echo "  - Monitor cluster health"
echo ""
echo "Press Ctrl+C to stop the port-forward"
echo ""

# Use local kubeconfig to port-forward directly
export KUBECONFIG="$KUBECONFIG_FILE"
kubectl port-forward -n $NAMESPACE service/$SERVICE $PORT:8080

