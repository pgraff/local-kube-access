#!/bin/bash
# Quick script to add cluster service entries to /etc/hosts
# Run this on any machine (laptop, desktop, etc.) to enable URL-based access
# Usage: sudo ./add-hosts-entries.sh
#
# For complete setup instructions, see: LAPTOP-SETUP.md

# Storage node IP (k8s-storage-01) - has working ingress controller on port 80
# Note: Control plane nodes don't expose ingress on port 80
NODE_IP="100.111.119.104"
HOSTS_FILE="/etc/hosts"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error:${NC} This script must be run with sudo"
    echo "Usage: sudo $0"
    exit 1
fi

echo -e "${GREEN}Adding cluster service entries to $HOSTS_FILE...${NC}"
echo ""

# Check if entries already exist
if grep -q "longhorn.tailc2013b.ts.net" "$HOSTS_FILE" 2>/dev/null; then
    echo -e "${YELLOW}Entries already exist. Current entries:${NC}"
    grep "tailc2013b.ts.net" "$HOSTS_FILE" | grep -v "^#"
    echo ""
    read -p "Remove old entries and add fresh ones? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove old entries (works on both macOS and Linux)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' '/# Kubernetes Cluster Service URLs/,/^$/d' "$HOSTS_FILE" 2>/dev/null
            sed -i '' '/tailc2013b.ts.net/d' "$HOSTS_FILE" 2>/dev/null
        else
            sed -i '/# Kubernetes Cluster Service URLs/,/^$/d' "$HOSTS_FILE" 2>/dev/null
            sed -i '/tailc2013b.ts.net/d' "$HOSTS_FILE" 2>/dev/null
        fi
        echo -e "${GREEN}Removed old entries${NC}"
    else
        echo "Keeping existing entries"
        exit 0
    fi
fi

# Add entries
cat >> "$HOSTS_FILE" << EOHOSTS

# Kubernetes Cluster Service URLs (via Ingress)
# Added on $(date)
$NODE_IP  longhorn.tailc2013b.ts.net
$NODE_IP  kubecost.tailc2013b.ts.net
$NODE_IP  kafka-ui.tailc2013b.ts.net
$NODE_IP  nats-ui.tailc2013b.ts.net
$NODE_IP  rancher.tailc2013b.ts.net
$NODE_IP  hono.tailc2013b.ts.net
$NODE_IP  thingsboard.tailc2013b.ts.net
$NODE_IP  nodered.tailc2013b.ts.net
$NODE_IP  jupyterhub.tailc2013b.ts.net
$NODE_IP  minio.tailc2013b.ts.net
$NODE_IP  argo.tailc2013b.ts.net
$NODE_IP  twin-service.tailc2013b.ts.net
EOHOSTS

echo -e "${GREEN}✓ Entries added successfully!${NC}"
echo ""
echo "Service URLs are now available:"
echo "  • Longhorn:      http://longhorn.tailc2013b.ts.net"
echo "  • Kubecost:      http://kubecost.tailc2013b.ts.net"
echo "  • Kafka UI:      http://kafka-ui.tailc2013b.ts.net"
echo "  • Rancher:       https://rancher.tailc2013b.ts.net"
echo "  • Hono:          http://hono.tailc2013b.ts.net"
echo "  • ThingsBoard:   http://thingsboard.tailc2013b.ts.net"
echo "  • Node-RED:      http://nodered.tailc2013b.ts.net"
echo "  • JupyterHub:    http://jupyterhub.tailc2013b.ts.net"
echo "  • MinIO:         http://minio.tailc2013b.ts.net"
echo "  • Argo:          http://argo.tailc2013b.ts.net"
echo "  • Twin Service:  http://twin-service.tailc2013b.ts.net"
echo ""
echo "Test with: curl -I http://longhorn.tailc2013b.ts.net"

