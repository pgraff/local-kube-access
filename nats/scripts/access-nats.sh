#!/bin/bash
# Script to access NATS cluster via port-forwarding
#
# NOTE: This script is needed because NATS (port 4222) is a TCP service
# that cannot use HTTP Ingress. This is a security feature - NATS is not exposed via
# Ingress and requires explicit port-forwarding for access.
#
# For NATS monitoring (HTTP), use: http://localhost:8222

CLIENT_PORT=4222
MONITOR_PORT=8222
NAMESPACE="nats"
SERVICE="nats"
KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo "Error: Kubeconfig file not found at $KUBECONFIG_FILE"
    echo "Please ensure the kubeconfig file exists."
    exit 1
fi

# Kill any existing port-forwards
echo "Cleaning up any existing port-forwards..."
pkill -f "kubectl port-forward.*nats" 2>/dev/null || true
sleep 1

# Check if local ports are in use
if lsof -i :$CLIENT_PORT > /dev/null 2>&1; then
    echo "Warning: Port $CLIENT_PORT is already in use locally."
    echo "Trying to use it anyway (may fail)..."
    echo ""
fi

if lsof -i :$MONITOR_PORT > /dev/null 2>&1; then
    echo "Warning: Port $MONITOR_PORT is already in use locally."
    echo "Trying to use it anyway (may fail)..."
    echo ""
fi

echo "Setting up port-forwarding to NATS cluster..."
echo ""
echo "NATS client will be available at: localhost:$CLIENT_PORT"
echo "NATS monitoring will be available at: http://localhost:$MONITOR_PORT"
echo ""
echo "Connection string: nats://localhost:$CLIENT_PORT"
echo ""
echo "Example usage:"
echo "  # Using NATS CLI (install: go install github.com/nats-io/natscli/nats@latest)"
echo "  nats pub test.subject 'Hello NATS'"
echo "  nats sub test.subject"
echo ""
echo "  # Using nats.go client"
echo "  nc, err := nats.Connect(\"nats://localhost:$CLIENT_PORT\")"
echo ""
echo "  # Check JetStream status"
echo "  curl http://localhost:$MONITOR_PORT/jsz"
echo ""
echo "Press Ctrl+C to stop the port-forward"
echo ""

# Use local kubeconfig to port-forward directly
export KUBECONFIG="$KUBECONFIG_FILE"

# Start port-forwards in background
kubectl port-forward -n $NAMESPACE service/$SERVICE $CLIENT_PORT:4222 &
CLIENT_PID=$!

kubectl port-forward -n $NAMESPACE service/$SERVICE $MONITOR_PORT:8222 &
MONITOR_PID=$!

# Wait for both processes
wait $CLIENT_PID $MONITOR_PID
