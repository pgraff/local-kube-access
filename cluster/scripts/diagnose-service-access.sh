#!/bin/bash
# Diagnostic script to check why services might not be accessible
# Usage: ./diagnose-service-access.sh

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Kubernetes Service Access Diagnostic${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check /etc/hosts entries
echo -e "${BLUE}1. Checking /etc/hosts entries...${NC}"
HOSTS_COUNT=$(grep -c "tailc2013b.ts.net" /etc/hosts 2>/dev/null || echo "0")
if [ "$HOSTS_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $HOSTS_COUNT entries in /etc/hosts${NC}"
    echo "   Sample entries:"
    grep "tailc2013b.ts.net" /etc/hosts | head -3 | sed 's/^/   /'
else
    echo -e "${RED}✗ No entries found in /etc/hosts${NC}"
    echo "   Run: sudo ./cluster/scripts/add-hosts-entries.sh"
fi
echo ""

# Check DNS resolution (macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${BLUE}2. Checking macOS DNS cache...${NC}"
    TEST_HOST="longhorn.tailc2013b.ts.net"
    CACHED_IP=$(dscacheutil -q host -a name "$TEST_HOST" 2>/dev/null | grep "ip_address:" | awk '{print $2}')
    if [ -n "$CACHED_IP" ]; then
        echo -e "${GREEN}✓ macOS DNS cache resolves $TEST_HOST -> $CACHED_IP${NC}"
    else
        echo -e "${RED}✗ macOS DNS cache does not resolve $TEST_HOST${NC}"
        echo "   Try: sudo dscacheutil -flushcache"
    fi
    echo ""
fi

# Check Tailscale connection
echo -e "${BLUE}3. Checking Tailscale connection...${NC}"
if command -v tailscale &> /dev/null; then
    TAILSCALE_STATUS=$(tailscale status 2>/dev/null | head -1)
    if [ -n "$TAILSCALE_STATUS" ]; then
        echo -e "${GREEN}✓ Tailscale is connected${NC}"
        echo "   $TAILSCALE_STATUS"
    else
        echo -e "${RED}✗ Tailscale not connected${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Tailscale CLI not found${NC}"
fi
echo ""

# Check node connectivity
echo -e "${BLUE}4. Checking node connectivity...${NC}"
NODE_IP=$(grep "tailc2013b.ts.net" /etc/hosts | head -1 | awk '{print $1}')
if [ -n "$NODE_IP" ]; then
    if ping -c 1 -W 2 "$NODE_IP" &>/dev/null; then
        echo -e "${GREEN}✓ Can ping node $NODE_IP${NC}"
    else
        echo -e "${RED}✗ Cannot ping node $NODE_IP${NC}"
        echo "   Check Tailscale connection"
    fi
else
    echo -e "${RED}✗ Could not determine node IP from /etc/hosts${NC}"
fi
echo ""

# Test HTTP access
echo -e "${BLUE}5. Testing HTTP access to services...${NC}"
SERVICES=(
    "longhorn.tailc2013b.ts.net"
    "kubecost.tailc2013b.ts.net"
    "jupyterhub.tailc2013b.ts.net"
    "argo.tailc2013b.ts.net"
)

for service in "${SERVICES[@]}"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "http://$service" 2>/dev/null)
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        echo -e "${GREEN}✓ $service: HTTP $HTTP_CODE${NC}"
    elif [ -n "$HTTP_CODE" ]; then
        echo -e "${YELLOW}⚠ $service: HTTP $HTTP_CODE${NC}"
    else
        echo -e "${RED}✗ $service: Connection failed${NC}"
    fi
done
echo ""

# Check ingress controller
echo -e "${BLUE}6. Checking ingress controller...${NC}"
export KUBECONFIG="$HOME/.kube/config-rke2-cluster.yaml"
if kubectl get daemonset rke2-ingress-nginx-controller -n kube-system &>/dev/null; then
    READY=$(kubectl get daemonset rke2-ingress-nginx-controller -n kube-system -o jsonpath='{.status.numberReady}' 2>/dev/null)
    DESIRED=$(kubectl get daemonset rke2-ingress-nginx-controller -n kube-system -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
    if [ "$READY" = "$DESIRED" ] && [ "$READY" -gt 0 ]; then
        echo -e "${GREEN}✓ Ingress controller: $READY/$DESIRED pods ready${NC}"
    else
        echo -e "${RED}✗ Ingress controller: $READY/$DESIRED pods ready${NC}"
    fi
else
    echo -e "${RED}✗ Ingress controller not found${NC}"
fi
echo ""

# Browser-specific recommendations
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Troubleshooting Steps${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "If services work with curl but not in browser:"
echo ""
echo "1. ${YELLOW}Clear browser DNS cache:${NC}"
echo "   • Chrome/Edge: chrome://net-internals/#dns (click 'Clear host cache')"
echo "   • Firefox: about:networking#dns (click 'Clear DNS Cache')"
echo "   • Safari: Close and reopen browser"
echo ""
echo "2. ${YELLOW}Flush macOS DNS cache:${NC}"
echo "   sudo dscacheutil -flushcache"
echo "   sudo killall -HUP mDNSResponder"
echo ""
echo "3. ${YELLOW}Try accessing via IP with Host header:${NC}"
echo "   Use a browser extension like 'ModHeader' to set:"
echo "   Host: longhorn.tailc2013b.ts.net"
echo "   Then visit: http://$NODE_IP"
echo ""
echo "4. ${YELLOW}Verify /etc/hosts is being used:${NC}"
echo "   getent hosts longhorn.tailc2013b.ts.net"
echo "   (Should show the IP from /etc/hosts)"
echo ""

