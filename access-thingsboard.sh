#!/bin/bash
# Script to access ThingsBoard CE via port-forwarding

PORT=9090
NAMESPACE="iot"
SERVICE="thingsboard"
KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo "Error: Kubeconfig file not found at $KUBECONFIG_FILE"
    echo "Please ensure the kubeconfig file exists."
    exit 1
fi

# Kill any existing port-forwards
echo "Cleaning up any existing port-forwards..."
pkill -f "kubectl port-forward.*thingsboard" 2>/dev/null || true
sleep 1

# Check if local port is in use
if lsof -i :$PORT > /dev/null 2>&1; then
    echo "Warning: Port $PORT is already in use locally."
    echo "Trying to use it anyway (may fail)..."
    echo ""
fi

echo "Setting up port-forwarding to ThingsBoard CE..."
echo ""
echo "ThingsBoard will be available at: http://localhost:$PORT"
echo ""
echo "Default credentials (change after first login):"
echo "  - Username: sysadmin@thingsboard.org"
echo "  - Password: sysadmin"
echo ""
echo "Features:"
echo "  - Device management"
echo "  - Dashboards and widgets"
echo "  - Rule engine"
echo "  - Workflows"
echo ""
echo "Press Ctrl+C to stop the port-forward"
echo ""

# Use local kubeconfig to port-forward directly
export KUBECONFIG="$KUBECONFIG_FILE"
kubectl port-forward -n $NAMESPACE service/$SERVICE $PORT:9090

