#!/bin/bash
# Script to detect which node IP actually has working ingress on port 80
# This helps identify the correct IP to use in /etc/hosts

KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"
TAILSCALE_DOMAIN="tailc2013b.ts.net"
TEST_HOST="longhorn.tailc2013b.ts.net"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo -e "${RED}Error:${NC} Kubeconfig file not found at $KUBECONFIG_FILE"
    exit 1
fi

export KUBECONFIG="$KUBECONFIG_FILE"

echo -e "${GREEN}Detecting working node IP for ingress...${NC}"
echo ""

# Get all node IPs from ingress status
INGRESS_IPS=$(kubectl get ingress --all-namespaces -o json 2>/dev/null | \
    jq -r '.items[0].status.loadBalancer.ingress[]?.ip' | \
    sort -u)

if [ -z "$INGRESS_IPS" ]; then
    echo -e "${YELLOW}Warning:${NC} No ingress IPs found in status, trying node IPs..."
    INGRESS_IPS=$(kubectl get nodes -o json 2>/dev/null | \
        jq -r '.items[] | .status.addresses[] | select(.type=="InternalIP") | .address' | \
        sort -u)
fi

echo "Testing node IPs for working ingress on port 80..."
echo ""

WORKING_IP=""
for ip in $INGRESS_IPS; do
    echo -n "  Testing $ip... "
    if timeout 2 curl -s -I -H "Host: $TEST_HOST" "http://$ip" >/dev/null 2>&1; then
        HTTP_CODE=$(timeout 2 curl -s -o /dev/null -w "%{http_code}" -H "Host: $TEST_HOST" "http://$ip" 2>/dev/null)
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
            echo -e "${GREEN}✓ Working (HTTP $HTTP_CODE)${NC}"
            WORKING_IP="$ip"
            break
        else
            echo -e "${YELLOW}Responds but HTTP $HTTP_CODE${NC}"
        fi
    else
        echo -e "${RED}✗ Not accessible${NC}"
    fi
done

echo ""
if [ -n "$WORKING_IP" ]; then
    echo -e "${GREEN}✓ Working node IP: $WORKING_IP${NC}"
    echo ""
    echo "Use this IP in /etc/hosts:"
    echo "  $WORKING_IP  longhorn.$TAILSCALE_DOMAIN"
    echo "  $WORKING_IP  kubecost.$TAILSCALE_DOMAIN"
    echo "  ... (etc)"
    exit 0
else
    echo -e "${RED}✗ No working node IP found${NC}"
    echo ""
    echo "Possible issues:"
    echo "  1. Ingress controller not running on any nodes"
    echo "  2. Firewall blocking port 80"
    echo "  3. Network connectivity issues"
    exit 1
fi

