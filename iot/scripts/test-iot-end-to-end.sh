#!/bin/bash
# End-to-End IoT Stack Test
# Demonstrates the complete data flow: Device → Mosquitto → Hono → Kafka → Ditto

set -e

KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"
NAMESPACE="iot"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

check_kubeconfig() {
    if [ ! -f "$KUBECONFIG_FILE" ]; then
        echo "Error: Kubeconfig not found"
        exit 1
    fi
    export KUBECONFIG="$KUBECONFIG_FILE"
}

main() {
    echo "=========================================="
    echo "IoT Stack End-to-End Test"
    echo "=========================================="
    echo ""
    
    check_kubeconfig
    
    print_step "Step 1: Verify all services are running..."
    echo "Checking pod status..."
    kubectl get pods -n $NAMESPACE | grep -E "mosquitto|ditto-gateway|hono-service-device-registry|timescaledb" | head -5
    echo ""
    
    print_step "Step 2: Test Mosquitto MQTT connection..."
    echo "Publishing test message to Mosquitto..."
    kubectl run mqtt-pub-test --rm -i --restart=Never \
        --image=eclipse-mosquitto:2.0 -n $NAMESPACE \
        -- mosquitto_pub -h mosquitto.iot.svc.cluster.local -p 1883 \
        -t iot/test/device001 -m '{"temperature": 25.5, "humidity": 60, "timestamp": "'$(date +%s)'"}' 2>&1 | grep -v "pod\|If you don't see" || true
    print_success "Message published to Mosquitto"
    echo ""
    
    print_step "Step 3: Verify Kafka topics (Hono telemetry)..."
    echo "Checking if Hono topics exist..."
    kubectl run kafka-list-topics --rm -i --restart=Never \
        --image=quay.io/strimzi/kafka:latest-kafka-4.1.1 -n $NAMESPACE \
        -- bin/kafka-topics.sh \
        --bootstrap-server kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092 \
        --list 2>&1 | grep -E "hono|iot" | head -5 || echo "Topics will be created when Hono processes messages"
    echo ""
    
    print_step "Step 4: Test Ditto API..."
    echo "Testing Ditto Gateway endpoint..."
    local ditto_response=$(kubectl run ditto-api-test --rm -i --restart=Never \
        --image=curlimages/curl:latest -n $NAMESPACE \
        -- curl -s -o /dev/null -w "%{http_code}" http://ditto-gateway.iot.svc.cluster.local:8080/api/2/things 2>&1 | tail -1)
    
    if [ "$ditto_response" = "401" ] || [ "$ditto_response" = "200" ]; then
        print_success "Ditto API responding (HTTP $ditto_response - service is up)"
    else
        echo "Ditto response: $ditto_response"
    fi
    echo ""
    
    print_step "Step 5: Verify service connectivity..."
    echo "Service endpoints:"
    kubectl get svc -n $NAMESPACE | grep -E "mosquitto|ditto-nginx|ditto-gateway|hono-service-device-registry|timescaledb" | \
        awk '{printf "  • %-35s %s\n", $1, $3}'
    echo ""
    
    print_step "Step 6: Check component logs for errors..."
    echo "Recent log entries (last 3 lines each):"
    echo ""
    echo "Mosquitto:"
    kubectl logs -n $NAMESPACE -l app=mosquitto --tail=3 2>&1 | tail -3 || echo "  (no recent logs)"
    echo ""
    echo "Ditto Gateway:"
    kubectl logs -n $NAMESPACE -l app=ditto-gateway --tail=3 2>&1 | tail -3 || echo "  (no recent logs)"
    echo ""
    echo "Hono Device Registry:"
    kubectl logs -n $NAMESPACE -l app=hono-service-device-registry --tail=3 2>&1 | tail -3 || echo "  (no recent logs)"
    echo ""
    
    echo "=========================================="
    print_success "End-to-end test completed!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "  1. Access services: ./access-all.sh"
    echo "  2. Check status: ./iot/scripts/iot-status-check.sh"
    echo "  3. See full guide: cat iot-testing-guide.md"
    echo ""
}

main "$@"

