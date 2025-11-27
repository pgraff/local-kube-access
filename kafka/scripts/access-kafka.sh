#!/bin/bash
# Script to access Kafka cluster via port-forwarding
#
# NOTE: This script is still needed because Kafka Bootstrap (port 9092) is a TCP service
# that cannot use HTTP Ingress. This is a security feature - Kafka is not exposed via
# Ingress and requires explicit port-forwarding for access.
#
# For Kafka UI (HTTP), use: http://kafka-ui.tailc2013b.ts.net
# See LAPTOP-SETUP.md for URL-based access setup.

PORT=9092
NAMESPACE="kafka"
SERVICE="kafka-cluster-kafka-bootstrap"
KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo "Error: Kubeconfig file not found at $KUBECONFIG_FILE"
    echo "Please ensure the kubeconfig file exists."
    exit 1
fi

# Kill any existing port-forwards
echo "Cleaning up any existing port-forwards..."
pkill -f "kubectl port-forward.*kafka" 2>/dev/null || true
sleep 1

# Check if local port is in use
if lsof -i :$PORT > /dev/null 2>&1; then
    echo "Warning: Port $PORT is already in use locally."
    echo "Trying to use it anyway (may fail)..."
    echo ""
fi

echo "Setting up port-forwarding to Kafka cluster..."
echo ""
echo "Kafka bootstrap service will be available at: localhost:$PORT"
echo ""
echo "Connection string: localhost:$PORT"
echo ""
echo "Example usage:"
echo "  # Producer"
  echo "  kubectl run kafka-producer -it --rm --image=quay.io/strimzi/kafka:latest-kafka-4.1.1 -- \\"
echo "    bin/kafka-console-producer.sh --bootstrap-server localhost:$PORT --topic test-topic"
echo ""
echo "  # Consumer"
  echo "  kubectl run kafka-consumer -it --rm --image=quay.io/strimzi/kafka:latest-kafka-4.1.1 -- \\"
echo "    bin/kafka-console-consumer.sh --bootstrap-server localhost:$PORT --topic test-topic --from-beginning"
echo ""
echo "Press Ctrl+C to stop the port-forward"
echo ""

# Use local kubeconfig to port-forward directly
export KUBECONFIG="$KUBECONFIG_FILE"
kubectl port-forward -n $NAMESPACE service/$SERVICE $PORT:9092

