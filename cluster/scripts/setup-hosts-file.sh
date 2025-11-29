#!/bin/bash
# Helper script to add cluster service URLs to /etc/hosts
# This enables URL-based access when Tailscale MagicDNS doesn't resolve subdomains

# Primary control plane node IP (k8s-cp-01)
# This should match the first control plane node in the cluster
NODE_IP="100.68.247.112"
HOSTS_FILE="/etc/hosts"
TEMP_FILE=$(mktemp)

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root (needed to edit /etc/hosts)
if [ "$EUID" -ne 0 ]; then 
    print_error "This script must be run with sudo"
    echo "Usage: sudo $0"
    exit 1
fi

# Entries to add
declare -A SERVICES=(
    ["longhorn.tailc2013b.ts.net"]="Longhorn"
    ["kubecost.tailc2013b.ts.net"]="Kubecost"
    ["kafka-ui.tailc2013b.ts.net"]="Kafka UI"
    ["rancher.tailc2013b.ts.net"]="Rancher"
    ["hono.tailc2013b.ts.net"]="Hono"
    ["thingsboard.tailc2013b.ts.net"]="ThingsBoard"
    ["nodered.tailc2013b.ts.net"]="Node-RED"
    ["jupyterhub.tailc2013b.ts.net"]="JupyterHub"
    ["minio.tailc2013b.ts.net"]="MinIO"
    ["argo.tailc2013b.ts.net"]="Argo Workflows"
    ["twin-service.tailc2013b.ts.net"]="Twin Service"
)

print_status "Setting up /etc/hosts entries for cluster services..."
echo ""

# Read existing hosts file
if [ -f "$HOSTS_FILE" ]; then
    cp "$HOSTS_FILE" "$TEMP_FILE"
else
    print_error "Hosts file not found at $HOSTS_FILE"
    exit 1
fi

# Remove existing cluster entries (if any)
print_status "Removing existing cluster service entries..."
# Use sed compatible with both GNU and BSD sed
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS (BSD sed)
    sed -i '' '/# Kubernetes Cluster Service URLs (via Ingress)/,/^$/d' "$TEMP_FILE" 2>/dev/null || true
    sed -i '' '/tailc2013b.ts.net.*# Cluster service/d' "$TEMP_FILE" 2>/dev/null || true
else
    # Linux (GNU sed)
    sed -i.bak '/# Kubernetes Cluster Service URLs (via Ingress)/,/^$/d' "$TEMP_FILE" 2>/dev/null || true
    sed -i.bak '/tailc2013b.ts.net.*# Cluster service/d' "$TEMP_FILE" 2>/dev/null || true
fi

# Add new entries
print_status "Adding cluster service entries..."
echo "" >> "$TEMP_FILE"
echo "# Kubernetes Cluster Service URLs (via Ingress)" >> "$TEMP_FILE"
echo "# Added by setup-hosts-file.sh on $(date)" >> "$TEMP_FILE"

for hostname in "${!SERVICES[@]}"; do
    service_name="${SERVICES[$hostname]}"
    if grep -q "$hostname" "$TEMP_FILE"; then
        print_warning "  Entry for $hostname already exists, skipping..."
    else
        echo "$NODE_IP  $hostname  # Cluster service: $service_name" >> "$TEMP_FILE"
        print_status "  ✓ Added $hostname -> $NODE_IP ($service_name)"
    fi
done

# Backup original hosts file
BACKUP_FILE="${HOSTS_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
cp "$HOSTS_FILE" "$BACKUP_FILE"
print_status "Backed up original hosts file to: $BACKUP_FILE"

# Replace hosts file
cp "$TEMP_FILE" "$HOSTS_FILE"
rm -f "$TEMP_FILE" "${TEMP_FILE}.bak"

print_status "Hosts file updated successfully!"
echo ""
print_status "Service URLs are now available:"
for hostname in "${!SERVICES[@]}"; do
    service_name="${SERVICES[$hostname]}"
    if [[ "$hostname" == *"rancher"* ]]; then
        echo "  • $service_name: https://$hostname"
    else
        echo "  • $service_name: http://$hostname"
    fi
done
echo ""
print_status "Test with: curl -I http://longhorn.tailc2013b.ts.net"
echo ""

