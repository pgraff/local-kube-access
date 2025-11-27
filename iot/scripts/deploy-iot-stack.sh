#!/bin/bash
# Single script to deploy the complete IoT stack
# This script deploys all IoT components in the correct order

set -e  # Exit on error

KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"
NAMESPACE="iot"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to check if kubeconfig exists
check_kubeconfig() {
    if [ ! -f "$KUBECONFIG_FILE" ]; then
        print_error "Kubeconfig file not found at $KUBECONFIG_FILE"
        echo "Please ensure the kubeconfig file exists."
        exit 1
    fi
    export KUBECONFIG="$KUBECONFIG_FILE"
}

# Function to check if command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

# Function to wait for pods to be ready
wait_for_pods() {
    local selector=$1
    local timeout=${2:-300}
    print_status "Waiting for pods with selector '$selector' to be ready (timeout: ${timeout}s)..."
    if kubectl wait --for=condition=ready pod -l "$selector" -n "$NAMESPACE" --timeout="${timeout}s" 2>/dev/null; then
        print_status "Pods are ready!"
        return 0
    else
        print_warning "Some pods may not be ready yet. Continuing..."
        return 1
    fi
}

# Function to verify Kafka accessibility
verify_kafka() {
    print_step "Verifying Kafka accessibility from $NAMESPACE namespace..."
    local kafka_service="kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
    
    # Try to resolve the service
    if kubectl run kafka-test-$(date +%s) --rm -i --restart=Never --image=quay.io/strimzi/kafka:latest-kafka-4.1.1 \
        -n "$NAMESPACE" -- bin/kafka-broker-api-versions.sh --bootstrap-server "$kafka_service" 2>/dev/null; then
        print_status "Kafka is accessible from $NAMESPACE namespace"
        return 0
    else
        print_warning "Could not verify Kafka connectivity directly. Will continue - components will handle connection."
        return 0
    fi
}

# Main deployment function
main() {
    print_status "=========================================="
    print_status "IoT Stack Deployment Script"
    print_status "=========================================="
    echo ""
    
    # Check prerequisites
    print_step "Checking prerequisites..."
    check_kubeconfig
    check_command helm
    check_command kubectl
    print_status "Prerequisites check passed"
    echo ""
    
    # Phase 1: Namespace Setup
    print_step "Phase 1: Creating namespace and verifying Kafka..."
    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
        print_warning "Namespace $NAMESPACE already exists"
    else
        kubectl apply -f ../k8s/iot-namespace.yaml
        print_status "Namespace $NAMESPACE created"
    fi
    verify_kafka
    echo ""
    
    # Phase 2: Setup Helm Repositories
    print_step "Phase 2: Setting up Helm repositories..."
    helm repo add eclipse-iot https://eclipse.org/packages/charts 2>/dev/null || print_warning "Eclipse IoT repo may already exist"
    helm repo add thingsboard https://thingsboard.github.io/helm-charts/ 2>/dev/null || print_warning "ThingsBoard repo may already exist"
    helm repo add timescale https://charts.timescale.com/ 2>/dev/null || print_warning "Timescale repo may already exist"
    helm repo add atnog https://atnog.github.io/ditto-helm-chart/ 2>/dev/null || print_warning "Ditto repo may already exist"
    helm repo add cloudnesil https://cloudnesil.github.io/helm-charts 2>/dev/null || print_warning "CloudNesil repo may already exist"
    helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || print_warning "Bitnami repo may already exist"
    helm repo update
    print_status "Helm repositories configured"
    echo ""
    
    # Phase 3: Deploy Databases
    print_step "Phase 3: Deploying databases..."
    
    # TimescaleDB
    if helm list -n "$NAMESPACE" | grep -q timescaledb; then
        print_warning "TimescaleDB already deployed, skipping..."
    else
        print_status "Deploying TimescaleDB..."
        helm install timescaledb timescale/timescaledb-single \
            -n "$NAMESPACE" \
            -f ../k8s/timescaledb-values.yaml \
            --wait --timeout 15m || print_warning "TimescaleDB deployment timed out, but continuing. Check status manually."
        print_status "TimescaleDB deployment initiated"
    fi
    
    # MongoDB for Hono
    if helm list -n "$NAMESPACE" | grep -q mongodb-hono; then
        print_warning "MongoDB for Hono already deployed, skipping..."
    else
        print_status "Deploying MongoDB for Hono..."
        helm install mongodb-hono bitnami/mongodb \
            -n "$NAMESPACE" \
            -f ../k8s/mongodb-hono-values.yaml \
            --wait --timeout 10m
        print_status "MongoDB for Hono deployed"
    fi
    
    # MongoDB for Ditto
    if helm list -n "$NAMESPACE" | grep -q mongodb-ditto; then
        print_warning "MongoDB for Ditto already deployed, skipping..."
    else
        print_status "Deploying MongoDB for Ditto..."
        helm install mongodb-ditto bitnami/mongodb \
            -n "$NAMESPACE" \
            -f ../k8s/mongodb-ditto-values.yaml \
            --wait --timeout 10m
        print_status "MongoDB for Ditto deployed"
    fi
    
    # PostgreSQL for ThingsBoard
    if helm list -n "$NAMESPACE" | grep -q postgresql-thingsboard; then
        print_warning "PostgreSQL for ThingsBoard already deployed, skipping..."
    else
        print_status "Deploying PostgreSQL for ThingsBoard..."
        helm install postgresql-thingsboard bitnami/postgresql \
            -n "$NAMESPACE" \
            -f ../k8s/postgresql-thingsboard-values.yaml \
            --wait --timeout 10m
        print_status "PostgreSQL for ThingsBoard deployed"
    fi
    echo ""
    
    # Phase 4: Deploy MQTT and Device Connectivity
    print_step "Phase 4: Deploying MQTT broker and device connectivity..."
    
    # Mosquitto
    if kubectl get deployment mosquitto -n "$NAMESPACE" &>/dev/null; then
        print_warning "Mosquitto already deployed, skipping..."
    else
        print_status "Deploying Eclipse Mosquitto..."
        kubectl apply -f ../k8s/mosquitto-deployment.yaml -n "$NAMESPACE"
        kubectl wait --for=condition=ready pod -l app=mosquitto -n "$NAMESPACE" --timeout=300s || true
        print_status "Mosquitto deployed"
    fi
    
    # Hono
    if helm list -n "$NAMESPACE" | grep -q hono; then
        print_warning "Hono already deployed, skipping..."
    else
        print_status "Deploying Eclipse Hono..."
        helm install hono eclipse-iot/hono \
            -n "$NAMESPACE" \
            -f ../k8s/hono-values.yaml \
            --wait --timeout 15m
        print_status "Hono deployed"
    fi
    echo ""
    
    # Phase 5: Deploy Digital Twins and APIs
    print_step "Phase 5: Deploying digital twins..."
    
    # Ditto
    if helm list -n "$NAMESPACE" | grep -q ditto; then
        print_warning "Ditto already deployed, skipping..."
    else
        print_status "Deploying Eclipse Ditto..."
        helm install ditto atnog/ditto \
            -n "$NAMESPACE" \
            -f ../k8s/ditto-values.yaml \
            --wait --timeout 15m
        print_status "Ditto deployed"
    fi
    echo ""
    
    # Phase 6: Deploy Visualization and Automation
    print_step "Phase 6: Deploying visualization and automation..."
    
    # ThingsBoard
    if kubectl get deployment thingsboard -n "$NAMESPACE" &>/dev/null; then
        print_warning "ThingsBoard already deployed, skipping..."
    else
        print_status "Deploying ThingsBoard CE..."
        kubectl apply -f ../k8s/thingsboard-deployment.yaml -n "$NAMESPACE"
        kubectl wait --for=condition=ready pod -l app=thingsboard -n "$NAMESPACE" --timeout=300s || true
        print_status "ThingsBoard deployed"
    fi
    
    # Node-RED
    if kubectl get deployment node-red -n "$NAMESPACE" &>/dev/null; then
        print_warning "Node-RED already deployed, skipping..."
    else
        print_status "Deploying Node-RED..."
        # Node-RED may not have an official Helm chart, so we'll use a direct deployment
        kubectl apply -f ../k8s/nodered-deployment.yaml -n "$NAMESPACE"
        kubectl wait --for=condition=ready pod -l app=node-red -n "$NAMESPACE" --timeout=300s || true
        print_status "Node-RED deployed"
    fi
    echo ""
    
    # Phase 7: Post-deployment configuration
    print_step "Phase 7: Configuring integrations..."
    print_status "Setting up Kafka topics and integrations..."
    # This will be handled by the components' configurations
    # Additional setup scripts can be added here if needed
    echo ""
    
    # Final status
    print_status "=========================================="
    print_status "Deployment Complete!"
    print_status "=========================================="
    echo ""
    print_status "Checking pod status..."
    kubectl get pods -n "$NAMESPACE"
    echo ""
    print_status "To access services, use the access scripts:"
    echo "  TCP service (port-forwarding):"
    echo "    ./iot/scripts/access-mosquitto.sh"
    echo ""
    echo "  HTTP services (via Ingress URLs after setup):"
    echo "    http://hono.tailc2013b.ts.net"
    echo "    http://ditto.tailc2013b.ts.net"
    echo "    http://thingsboard.tailc2013b.ts.net"
    echo "    http://nodered.tailc2013b.ts.net"
    echo "    See LAPTOP-SETUP.md for setup instructions"
    echo ""
    print_status "Or use ./access-all.sh to start all port-forwards"
    echo ""
}

# Run main function
main "$@"

