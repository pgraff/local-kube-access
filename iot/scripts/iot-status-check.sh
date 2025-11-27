#!/bin/bash
# Quick status check script for IoT stack

KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"
NAMESPACE="iot"

export KUBECONFIG="$KUBECONFIG_FILE"

echo "=========================================="
echo "IoT Stack Status Check"
echo "=========================================="
echo ""

echo "📊 Pod Status:"
kubectl get pods -n $NAMESPACE -o wide | head -20
echo ""

echo "🔧 Services:"
kubectl get svc -n $NAMESPACE | grep -E "mosquitto|ditto|hono|node-red|thingsboard|timescaledb|postgresql|mongodb"
echo ""

echo "💾 Storage:"
kubectl get pvc -n $NAMESPACE
echo ""

echo "✅ Ready Components:"
kubectl get pods -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' | grep -E "\ttrue$" | awk '{print "  ✓", $1}'
echo ""

echo "⏳ Not Ready:"
kubectl get pods -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' | grep -E "\tfalse$" | awk '{print "  •", $1}'
echo ""

echo "📝 To access services:"
echo "  ./iot/scripts/access-mosquitto.sh"
echo "  ./iot/scripts/access-ditto.sh"
echo "  ./iot/scripts/access-nodered.sh"
echo "  ./iot/scripts/access-thingsboard.sh"
echo "  ./access-all.sh"
echo ""

