#!/bin/bash
# Script to access Eclipse Mosquitto MQTT broker via port-forwarding
#
# NOTE: This script is still needed because Mosquitto (port 1883) is a TCP/MQTT service
# that cannot use HTTP Ingress. This is a security feature - Mosquitto is not exposed
# via Ingress and requires explicit port-forwarding for access.
#
# For other IoT HTTP services, use Ingress URLs:
#   - Hono:      http://hono.tailc2013b.ts.net
#   - Ditto:     http://ditto.tailc2013b.ts.net
#   - ThingsBoard: http://thingsboard.tailc2013b.ts.net
#   - Node-RED:  http://nodered.tailc2013b.ts.net
# See LAPTOP-SETUP.md for URL-based access setup.

PORT=1883
NAMESPACE="iot"
SERVICE="mosquitto"
KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo "Error: Kubeconfig file not found at $KUBECONFIG_FILE"
    echo "Please ensure the kubeconfig file exists."
    exit 1
fi

# Kill any existing port-forwards
echo "Cleaning up any existing port-forwards..."
pkill -f "kubectl port-forward.*mosquitto" 2>/dev/null || true
sleep 1

# Check if local port is in use
if lsof -i :$PORT > /dev/null 2>&1; then
    echo "Warning: Port $PORT is already in use locally."
    echo "Trying to use it anyway (may fail)..."
    echo ""
fi

echo "Setting up port-forwarding to Eclipse Mosquitto..."
echo ""
echo "Mosquitto MQTT broker will be available at: localhost:$PORT"
echo ""
echo "You can connect using any MQTT client:"
echo "  - Host: localhost"
echo "  - Port: $PORT"
echo "  - Protocol: MQTT (TCP)"
echo ""
echo "Example with mosquitto_pub:"
echo "  mosquitto_pub -h localhost -p $PORT -t test/topic -m 'Hello World'"
echo ""
echo "Press Ctrl+C to stop the port-forward"
echo ""

# Use local kubeconfig to port-forward directly
export KUBECONFIG="$KUBECONFIG_FILE"
kubectl port-forward -n $NAMESPACE service/$SERVICE $PORT:1883

