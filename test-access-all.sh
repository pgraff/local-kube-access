#!/bin/bash
# Test script to verify access-all.sh service discovery

KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"
export KUBECONFIG="$KUBECONFIG_FILE"

echo "=== Testing Service Discovery for access-all.sh ==="
echo ""

# Check if IoT namespace exists
if ! kubectl get namespace iot &>/dev/null; then
    echo "❌ IoT namespace does not exist"
    echo "   Run: ./deploy-iot-stack.sh"
    exit 1
fi

echo "✅ IoT namespace exists"
echo ""

# Test service discovery for each IoT service
echo "🔍 Testing service discovery:"
echo ""

# Mosquitto
echo -n "Mosquitto: "
if kubectl get svc -n iot mosquitto &>/dev/null; then
    echo "✅ Found: mosquitto"
else
    echo "❌ Not found"
fi

# Hono
echo -n "Hono: "
HONO_SERVICE=$(kubectl get svc -n iot -l app=hono,component=http-adapter -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || \
              kubectl get svc -n iot -l app.kubernetes.io/name=hono -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || \
              kubectl get svc -n iot 2>/dev/null | grep -i hono | grep -i http | head -1 | awk '{print $1}' || \
              kubectl get svc -n iot 2>/dev/null | grep -i hono | grep -i adapter | head -1 | awk '{print $1}' || \
              echo "")
if [ -n "$HONO_SERVICE" ]; then
    echo "✅ Found: $HONO_SERVICE"
else
    echo "❌ Not found"
    echo "   Available Hono services:"
    kubectl get svc -n iot | grep -i hono || echo "   (none)"
fi

# Ditto
echo -n "Ditto: "
DITTO_SERVICE=$(kubectl get svc -n iot -o name 2>/dev/null | grep -i ditto | grep -i gateway | head -1 | sed 's|service/||' || \
               kubectl get svc -n iot 2>/dev/null | grep -i ditto | grep -i gateway | head -1 | awk '{print $1}' || \
               kubectl get svc -n iot 2>/dev/null | grep -i ditto | head -1 | awk '{print $1}' || \
               echo "")
if [ -n "$DITTO_SERVICE" ]; then
    echo "✅ Found: $DITTO_SERVICE"
else
    echo "❌ Not found"
    echo "   Available Ditto services:"
    kubectl get svc -n iot | grep -i ditto || echo "   (none)"
fi

# ThingsBoard
echo -n "ThingsBoard: "
if kubectl get svc -n iot thingsboard &>/dev/null; then
    echo "✅ Found: thingsboard"
else
    echo "❌ Not found"
fi

# Node-RED
echo -n "Node-RED: "
if kubectl get svc -n iot node-red &>/dev/null; then
    echo "✅ Found: node-red"
else
    echo "❌ Not found"
fi

echo ""
echo "📋 All services in IoT namespace:"
kubectl get svc -n iot
echo ""
echo "💡 To start port-forwards: ./access-all.sh"
echo "💡 To stop port-forwards: ./kill-access-all.sh"

