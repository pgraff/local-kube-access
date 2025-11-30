#!/bin/bash
# Script to display all cluster service URLs for easy demo access
# Shows both Tailscale MagicDNS URLs and node IP fallback options

KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"
TAILSCALE_DOMAIN="tailc2013b.ts.net"
# Storage node IP (k8s-storage-01) - has working ingress controller on port 80
# Note: Control plane nodes don't expose ingress on port 80
NODE_IP="100.111.119.104"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${BLUE}$1${NC}"
}

print_url() {
    echo -e "  ${GREEN}•${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo "Error: Kubeconfig file not found at $KUBECONFIG_FILE"
    exit 1
fi

export KUBECONFIG="$KUBECONFIG_FILE"

# Check Tailscale MagicDNS status
print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_header "  Kubernetes Cluster Service URLs"
print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if Tailscale is available and MagicDNS status
if command -v tailscale &> /dev/null; then
    MAGICDNS_STATUS=$(tailscale status --json 2>/dev/null | grep -o '"MagicDNS":true' || echo "")
    if [ -n "$MAGICDNS_STATUS" ]; then
        print_header "✓ Tailscale MagicDNS: Enabled"
        echo ""
        print_header "Primary Access (via Tailscale MagicDNS):"
        echo ""
    else
        print_warning "Tailscale MagicDNS: Not enabled (or not detected)"
        echo "  Enable in Tailscale admin console: https://login.tailscale.com/admin/settings/dns"
        echo ""
        print_header "Fallback Access (via Node IP):"
        echo ""
    fi
else
    print_warning "Tailscale CLI not found - assuming MagicDNS may be enabled"
    echo ""
    print_header "Service URLs (MagicDNS):"
    echo ""
fi

# Core Services
print_header "Core Services:"
print_url "Rancher:       https://rancher.$TAILSCALE_DOMAIN"
print_url "Longhorn:      http://longhorn.$TAILSCALE_DOMAIN"
print_url "Kubecost:      http://kubecost.$TAILSCALE_DOMAIN"
print_url "Kafka UI:      http://kafka-ui.$TAILSCALE_DOMAIN"
echo ""

# Check IoT namespace
if kubectl get namespace iot &>/dev/null; then
    print_header "IoT Stack Services:"
    print_url "Hono:          http://hono.$TAILSCALE_DOMAIN"
    print_url "ThingsBoard:   http://thingsboard.$TAILSCALE_DOMAIN"
    print_url "Node-RED:      http://nodered.$TAILSCALE_DOMAIN"
    print_url "Twin Service:  http://twin-service.$TAILSCALE_DOMAIN"
    echo ""
    print_warning "Note: Mosquitto (MQTT port 1883) requires port-forwarding (TCP service)"
fi

# Additional services
print_header "Additional Services:"
print_url "JupyterHub:    http://jupyterhub.$TAILSCALE_DOMAIN"
print_url "MinIO:         http://minio.$TAILSCALE_DOMAIN"
print_url "Argo:          http://argo.$TAILSCALE_DOMAIN"
echo ""

echo ""
print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_header "  Node IP Fallback (if MagicDNS not available)"
print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_warning "If MagicDNS is not working, you can access services via node IP:"
echo ""
print_warning "Method 1: Add to /etc/hosts (on your laptop):"
echo "  $NODE_IP  longhorn.$TAILSCALE_DOMAIN"
echo "  $NODE_IP  kubecost.$TAILSCALE_DOMAIN"
echo "  $NODE_IP  kafka-ui.$TAILSCALE_DOMAIN"
echo "  $NODE_IP  rancher.$TAILSCALE_DOMAIN"
if kubectl get namespace iot &>/dev/null; then
    echo "  $NODE_IP  hono.$TAILSCALE_DOMAIN"
    echo "  $NODE_IP  thingsboard.$TAILSCALE_DOMAIN"
    echo "  $NODE_IP  nodered.$TAILSCALE_DOMAIN"
    echo "  $NODE_IP  twin-service.$TAILSCALE_DOMAIN"
fi
echo "  $NODE_IP  jupyterhub.$TAILSCALE_DOMAIN"
echo "  $NODE_IP  minio.$TAILSCALE_DOMAIN"
echo "  $NODE_IP  argo.$TAILSCALE_DOMAIN"
echo ""
print_warning "Method 2: Use curl with Host header:"
echo "  curl -H 'Host: longhorn.$TAILSCALE_DOMAIN' http://$NODE_IP"
echo ""
print_warning "Method 3: Use browser extension to set Host header"
echo ""

# Check ingress status
print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_header "  Ingress Status"
print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

INGRESS_COUNT=$(kubectl get ingress --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$INGRESS_COUNT" -gt 0 ]; then
    print_header "Active Ingress Resources:"
    kubectl get ingress --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTS:.spec.rules[*].host,AGE:.metadata.creationTimestamp 2>/dev/null
    echo ""
else
    print_warning "No ingress resources found. Run ./cluster/scripts/setup-ingress.sh to deploy them."
    echo ""
fi

# Check ingress controller
INGRESS_READY=$(kubectl get daemonset rke2-ingress-nginx-controller -n kube-system -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
INGRESS_DESIRED=$(kubectl get daemonset rke2-ingress-nginx-controller -n kube-system -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")

if [ "$INGRESS_READY" -eq "$INGRESS_DESIRED" ] && [ "$INGRESS_READY" -gt 0 ]; then
    print_header "✓ Ingress Controller: Ready ($INGRESS_READY/$INGRESS_DESIRED pods)"
else
    print_warning "⚠ Ingress Controller: Not ready ($INGRESS_READY/$INGRESS_DESIRED pods)"
fi

echo ""
print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_header "Quick Test:"
echo "  Test DNS resolution: nslookup longhorn.$TAILSCALE_DOMAIN"
echo "  Test HTTP access: curl -I http://longhorn.$TAILSCALE_DOMAIN"
echo ""

