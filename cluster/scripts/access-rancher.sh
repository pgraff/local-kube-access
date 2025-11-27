#!/bin/bash
# Script to access Rancher via port-forwarding
# Run this script to set up port-forwarding to Rancher

HTTP_PORT=8443
HTTPS_PORT=8444
RANCHER_SERVICE="service/rancher"
NAMESPACE="cattle-system"

# Kill any existing port-forwards on remote server
echo "Cleaning up any existing port-forwards..."
ssh scispike@k8s-cp-01 "pkill -f 'kubectl port-forward.*rancher' || true" 2>/dev/null
sleep 1

# Check if local ports are in use
if lsof -i :$HTTP_PORT > /dev/null 2>&1 || lsof -i :$HTTPS_PORT > /dev/null 2>&1; then
    echo "Warning: One or more ports are already in use."
    echo "Trying to use them anyway (may fail)..."
    echo ""
fi

echo "Setting up port-forwarding to Rancher..."
echo ""
echo "Rancher will be available at:"
echo "  - HTTP:  http://localhost:$HTTP_PORT"
echo "  - HTTPS: https://localhost:$HTTPS_PORT (recommended)"
echo ""
echo "Note: HTTPS will show a certificate warning (self-signed), but it's safe to proceed."
echo ""
echo "Press Ctrl+C to stop the port-forward"
echo ""

# Use SSH to run kubectl port-forward on remote, forwarding both HTTP and HTTPS
# This creates tunnels for both ports
ssh -L $HTTP_PORT:localhost:$HTTP_PORT -L $HTTPS_PORT:localhost:$HTTPS_PORT scispike@k8s-cp-01 "~/kubectl port-forward -n $NAMESPACE $RANCHER_SERVICE $HTTP_PORT:80 $HTTPS_PORT:443"

