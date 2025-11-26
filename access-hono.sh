#!/bin/bash
# Script to access Eclipse Hono services via port-forwarding

HTTP_PORT=8080
MQTT_PORT=1883
NAMESPACE="iot"
KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo "Error: Kubeconfig file not found at $KUBECONFIG_FILE"
    echo "Please ensure the kubeconfig file exists."
    exit 1
fi

# Kill any existing port-forwards
echo "Cleaning up any existing port-forwards..."
pkill -f "kubectl port-forward.*hono" 2>/dev/null || true
sleep 1

echo "Setting up port-forwarding to Eclipse Hono..."
echo ""
echo "Eclipse Hono services will be available at:"
echo "  - HTTP Adapter: http://localhost:$HTTP_PORT"
echo "  - MQTT Adapter: localhost:$MQTT_PORT"
echo ""
echo "Note: MQTT adapter port may conflict with Mosquitto (1883)"
echo "      Use Mosquitto for device connections, Hono for backend integration"
echo ""
echo "Press Ctrl+C to stop the port-forward"
echo ""

# Use local kubeconfig to port-forward directly
export KUBECONFIG="$KUBECONFIG_FILE"

# Try to find Hono HTTP adapter service (try multiple label selectors)
SERVICE=$(kubectl get svc -n $NAMESPACE -l app=hono,component=http-adapter -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || \
         kubectl get svc -n $NAMESPACE -l app.kubernetes.io/name=hono -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || \
         kubectl get svc -n $NAMESPACE | grep -i hono | grep -i http | head -1 | awk '{print $1}' || echo "")

if [ -n "$SERVICE" ]; then
    kubectl port-forward -n $NAMESPACE service/$SERVICE $HTTP_PORT:8080
else
    echo "Warning: Hono HTTP adapter service not found. Is Hono deployed?"
    echo "Available services in $NAMESPACE namespace:"
    kubectl get svc -n $NAMESPACE
    exit 1
fi

