#!/bin/bash
# Script to deploy and verify all Ingress resources for cluster services
# This enables URL-based access via Tailscale MagicDNS

KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"
INGRESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../k8s/ingress" && pwd)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_FILE" ]; then
    print_error "Kubeconfig file not found at $KUBECONFIG_FILE"
    echo "Please ensure the kubeconfig file exists."
    exit 1
fi

export KUBECONFIG="$KUBECONFIG_FILE"

# Check if ingress controller is ready
print_status "Checking ingress controller status..."
INGRESS_READY=$(kubectl get daemonset rke2-ingress-nginx-controller -n kube-system -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
INGRESS_DESIRED=$(kubectl get daemonset rke2-ingress-nginx-controller -n kube-system -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")

if [ "$INGRESS_READY" -eq "0" ] || [ "$INGRESS_READY" -ne "$INGRESS_DESIRED" ]; then
    print_error "Ingress controller is not ready ($INGRESS_READY/$INGRESS_DESIRED pods ready)"
    print_error "Please ensure the ingress controller is running before deploying ingress resources."
    exit 1
fi

print_status "Ingress controller is ready ($INGRESS_READY/$INGRESS_DESIRED pods)"

# Check if ingress directory exists
if [ ! -d "$INGRESS_DIR" ]; then
    print_error "Ingress directory not found at $INGRESS_DIR"
    exit 1
fi

print_status "Deploying ingress resources from $INGRESS_DIR..."
echo ""

# Core services (always deploy)
CORE_INGRESS=(
    "longhorn-ingress.yaml"
    "kubecost-ingress.yaml"
    "kafka-ui-ingress.yaml"
)

# IoT services (conditional - only if namespace exists)
IOT_INGRESS=(
    "hono-ingress.yaml"
    "ditto-ingress.yaml"
    "thingsboard-ingress.yaml"
    "nodered-ingress.yaml"
)

# Deploy core services
for ingress_file in "${CORE_INGRESS[@]}"; do
    if [ -f "$INGRESS_DIR/$ingress_file" ]; then
        print_status "Applying $ingress_file..."
        if kubectl apply -f "$INGRESS_DIR/$ingress_file" 2>/dev/null; then
            print_status "  ✓ $ingress_file deployed successfully"
        else
            print_error "  ✗ Failed to deploy $ingress_file"
        fi
    else
        print_warning "  ⚠ $ingress_file not found, skipping..."
    fi
done

# Check if IoT namespace exists
if kubectl get namespace iot &>/dev/null; then
    print_status "IoT namespace found, deploying IoT service ingress resources..."
    for ingress_file in "${IOT_INGRESS[@]}"; do
        if [ -f "$INGRESS_DIR/$ingress_file" ]; then
            print_status "Applying $ingress_file..."
            if kubectl apply -f "$INGRESS_DIR/$ingress_file" 2>/dev/null; then
                print_status "  ✓ $ingress_file deployed successfully"
            else
                print_error "  ✗ Failed to deploy $ingress_file"
            fi
        else
            print_warning "  ⚠ $ingress_file not found, skipping..."
        fi
    done
else
    print_warning "IoT namespace not found, skipping IoT service ingress resources..."
fi

echo ""
print_status "Verifying ingress resources..."
echo ""

# Wait a moment for ingress to be processed
sleep 2

# Get all ingress resources
INGRESS_LIST=$(kubectl get ingress --all-namespaces -o json 2>/dev/null)

if [ -z "$INGRESS_LIST" ]; then
    print_warning "No ingress resources found"
else
    print_status "Ingress resources status:"
    kubectl get ingress --all-namespaces
    echo ""
    
    # Show addresses if available
    print_status "Ingress addresses:"
    kubectl get ingress --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTS:.spec.rules[*].host,ADDRESS:.status.loadBalancer.ingress[*].ip 2>/dev/null || \
    kubectl get ingress --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTS:.spec.rules[*].host 2>/dev/null
fi

echo ""
print_status "Ingress deployment complete!"
echo ""
print_status "Service URLs (via Tailscale MagicDNS):"
echo "  • Longhorn:      http://longhorn.tailc2013b.ts.net"
echo "  • Kubecost:      http://kubecost.tailc2013b.ts.net"
echo "  • Kafka UI:      http://kafka-ui.tailc2013b.ts.net"
echo "  • Rancher:       https://rancher.tailc2013b.ts.net (already configured)"

if kubectl get namespace iot &>/dev/null; then
    echo "  • Hono:          http://hono.tailc2013b.ts.net"
    echo "  • Ditto:         http://ditto.tailc2013b.ts.net"
    echo "  • ThingsBoard:   http://thingsboard.tailc2013b.ts.net"
    echo "  • Node-RED:      http://nodered.tailc2013b.ts.net"
fi

echo ""
print_status "Node IP fallback (if MagicDNS not available):"
echo "  Access via storage node IP: http://100.111.119.104"
echo "  (Use Host header: Host: longhorn.tailc2013b.ts.net)"
echo "  Note: Storage node (k8s-storage-01) has working ingress on port 80"
echo ""
print_status "To list all service URLs, run: ./cluster/scripts/list-service-urls.sh"

