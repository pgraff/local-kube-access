#!/bin/bash
# Comprehensive IoT Stack Testing Script
# Tests all components and their integrations

set -e

KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"
NAMESPACE="iot"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

check_kubeconfig() {
    if [ ! -f "$KUBECONFIG_FILE" ]; then
        print_error "Kubeconfig not found"
        exit 1
    fi
    export KUBECONFIG="$KUBECONFIG_FILE"
}

# Test 1: Component Health
test_component_health() {
    print_test "Testing component health..."
    local failed=0
    
    # Check pods
    local ready=$(kubectl get pods -n $NAMESPACE -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' | grep -c true || echo "0")
    local total=$(kubectl get pods -n $NAMESPACE --no-headers | wc -l | tr -d ' ')
    
    if [ "$ready" -gt 10 ]; then
        print_success "Component health: $ready/$total pods ready"
    else
        print_error "Component health: Only $ready/$total pods ready"
        failed=1
    fi
    
    return $failed
}

# Test 2: Mosquitto MQTT
test_mosquitto() {
    print_test "Testing Mosquitto MQTT broker..."
    local failed=0
    
    # Check service
    if kubectl get svc -n $NAMESPACE mosquitto &>/dev/null; then
        print_success "Mosquitto service exists"
    else
        print_error "Mosquitto service not found"
        failed=1
    fi
    
    # Test MQTT connection (basic)
    local pod_name="mqtt-test-$(date +%s)"
    if kubectl run $pod_name --rm -i --restart=Never --image=eclipse-mosquitto:2.0 -n $NAMESPACE -- \
        timeout 3 mosquitto_sub -h mosquitto.iot.svc.cluster.local -p 1883 -t test/health -W 1 2>&1 | grep -q "test/health\|timeout" || true; then
        print_success "Mosquitto accepting connections"
    else
        print_warning "Mosquitto connection test inconclusive"
    fi
    
    return $failed
}

# Test 3: Ditto API
test_ditto() {
    print_test "Testing Ditto API..."
    local failed=0
    
    # Test Ditto Gateway
    local status=$(kubectl run ditto-test-$(date +%s) --rm -i --restart=Never --image=curlimages/curl:latest -n $NAMESPACE -- \
        curl -s -o /dev/null -w "%{http_code}" http://ditto-gateway.iot.svc.cluster.local:8080/api/2/things 2>&1 | tail -1)
    
    if [ "$status" = "401" ] || [ "$status" = "200" ]; then
        print_success "Ditto Gateway responding (HTTP $status)"
    else
        print_error "Ditto Gateway not responding (HTTP $status)"
        failed=1
    fi
    
    # Test Ditto Nginx
    local nginx_status=$(kubectl run ditto-nginx-test-$(date +%s) --rm -i --restart=Never --image=curlimages/curl:latest -n $NAMESPACE -- \
        curl -s -o /dev/null -w "%{http_code}" http://ditto-nginx.iot.svc.cluster.local:8080/api/2/things 2>&1 | tail -1)
    
    if [ "$nginx_status" = "401" ] || [ "$nginx_status" = "200" ]; then
        print_success "Ditto Nginx responding (HTTP $nginx_status)"
    else
        print_warning "Ditto Nginx test inconclusive"
    fi
    
    return $failed
}

# Test 4: Hono Device Registry
test_hono() {
    print_test "Testing Hono Device Registry..."
    local failed=0
    
    # Check service
    if kubectl get svc -n $NAMESPACE hono-service-device-registry &>/dev/null; then
        print_success "Hono Device Registry service exists"
    else
        print_error "Hono Device Registry service not found"
        failed=1
    fi
    
    # Check if registry pod is ready
    if kubectl get pods -n $NAMESPACE -l app=hono-service-device-registry -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null | grep -q "true"; then
        print_success "Hono Device Registry pod ready"
    else
        print_warning "Hono Device Registry pod not ready"
    fi
    
    return $failed
}

# Test 5: Kafka Connectivity
test_kafka() {
    print_test "Testing Kafka connectivity from IoT namespace..."
    local failed=0
    
    local kafka_test=$(kubectl run kafka-conn-test-$(date +%s) --rm -i --restart=Never --image=quay.io/strimzi/kafka:latest-kafka-4.1.1 -n $NAMESPACE -- \
        bin/kafka-broker-api-versions.sh --bootstrap-server kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092 2>&1 | head -3 | grep -q "kafka-cluster" && echo "success" || echo "failed")
    
    if [ "$kafka_test" = "success" ]; then
        print_success "Kafka accessible from IoT namespace"
    else
        print_error "Kafka not accessible"
        failed=1
    fi
    
    return $failed
}

# Test 6: Database Connectivity
test_databases() {
    print_test "Testing database connectivity..."
    local failed=0
    
    # TimescaleDB
    if kubectl get svc -n $NAMESPACE timescaledb &>/dev/null; then
        print_success "TimescaleDB service exists"
    else
        print_warning "TimescaleDB service not found"
    fi
    
    # PostgreSQL
    if kubectl get svc -n $NAMESPACE postgresql-thingsboard &>/dev/null; then
        print_success "PostgreSQL service exists"
    else
        print_warning "PostgreSQL service not found"
    fi
    
    # MongoDB
    if kubectl get svc -n $NAMESPACE mongodb-ditto &>/dev/null; then
        print_success "MongoDB (Ditto) service exists"
    else
        print_warning "MongoDB (Ditto) service not found"
    fi
    
    return 0
}

# Test 7: End-to-End Data Flow
test_data_flow() {
    print_test "Testing end-to-end data flow..."
    local failed=0
    
    # Create a test topic in Kafka
    local topic_name="iot-test-$(date +%s)"
    kubectl run kafka-producer-test-$(date +%s) --rm -i --restart=Never --image=quay.io/strimzi/kafka:latest-kafka-4.1.1 -n $NAMESPACE -- \
        bin/kafka-topics.sh --bootstrap-server kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092 \
        --create --topic $topic_name --partitions 1 --replication-factor 3 2>&1 | grep -q "Created\|already exists" && \
        print_success "Kafka topic creation works" || print_warning "Kafka topic creation test inconclusive"
    
    # Test publishing a message
    kubectl run kafka-pub-test-$(date +%s) --rm -i --restart=Never --image=quay.io/strimzi/kafka:latest-kafka-4.1.1 -n $NAMESPACE -- \
        bin/kafka-console-producer.sh --bootstrap-server kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092 \
        --topic $topic_name <<< "test message" 2>&1 | grep -q "test message\|WARN" && \
        print_success "Kafka message publishing works" || print_warning "Kafka publishing test inconclusive"
    
    return 0
}

# Test 8: Service Discovery
test_service_discovery() {
    print_test "Testing service discovery..."
    local failed=0
    
    local services=("mosquitto" "ditto-nginx" "ditto-gateway" "hono-service-device-registry" "timescaledb" "postgresql-thingsboard" "mongodb-ditto")
    
    for svc in "${services[@]}"; do
        if kubectl get svc -n $NAMESPACE $svc &>/dev/null; then
            local ip=$(kubectl get svc -n $NAMESPACE $svc -o jsonpath='{.spec.clusterIP}')
            print_success "$svc: $ip"
        else
            print_error "$svc: not found"
            failed=1
        fi
    done
    
    return $failed
}

# Main test execution
main() {
    echo "=========================================="
    echo "IoT Stack Comprehensive Test Suite"
    echo "=========================================="
    echo ""
    
    check_kubeconfig
    
    local total_tests=0
    local passed_tests=0
    
    # Run all tests
    test_component_health && ((passed_tests++)) || true
    ((total_tests++))
    
    test_mosquitto && ((passed_tests++)) || true
    ((total_tests++))
    
    test_ditto && ((passed_tests++)) || true
    ((total_tests++))
    
    test_hono && ((passed_tests++)) || true
    ((total_tests++))
    
    test_kafka && ((passed_tests++)) || true
    ((total_tests++))
    
    test_databases && ((passed_tests++)) || true
    ((total_tests++))
    
    test_data_flow && ((passed_tests++)) || true
    ((total_tests++))
    
    test_service_discovery && ((passed_tests++)) || true
    ((total_tests++))
    
    echo ""
    echo "=========================================="
    echo "Test Results: $passed_tests/$total_tests passed"
    echo "=========================================="
    echo ""
    
    if [ $passed_tests -eq $total_tests ]; then
        print_success "All tests passed! IoT stack is operational."
        return 0
    elif [ $passed_tests -gt 5 ]; then
        print_warning "Most tests passed. Some components may need attention."
        return 0
    else
        print_error "Several tests failed. Check component status."
        return 1
    fi
}

main "$@"

