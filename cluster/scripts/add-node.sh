#!/bin/bash
# Script to add a new node to the RKE2 cluster
#
# Usage: ./add-node.sh <current-hostname> <new-hostname>
# Example: ./add-node.sh my-server k8s-worker-11
#
# Prerequisites:
# - Passwordless SSH access to <current-hostname> (via ssh-copy-id)
# - Control plane node accessible (k8s-cp-01)
# - New node has network connectivity (Tailscale recommended)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_error() {
    echo -e "${RED}❌ ERROR:${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
}

# Check arguments
if [ $# -lt 2 ]; then
    print_error "Usage: $0 <current-hostname> <new-hostname> [ssh-user] [sudo-password] [join-token]"
    echo ""
    echo "Example:"
    echo "  $0 my-server k8s-worker-11"
    echo "  $0 my-server k8s-worker-11 petter  # If SSH user is different"
    echo "  $0 my-server k8s-worker-11 scispike mypassword  # With sudo password"
    echo "  $0 my-server k8s-worker-11 scispike '' K10abc123...  # With join token (empty password)"
    echo ""
    echo "Parameters:"
    echo "  current-hostname: The current hostname/IP where passwordless SSH is set up"
    echo "  new-hostname:     The desired hostname for the node (e.g., k8s-worker-11)"
    echo "  ssh-user:         (Optional) SSH username (default: scispike)"
    echo "  sudo-password:    (Optional) Sudo password for control plane (if not passwordless)"
    echo "  join-token:       (Optional) RKE2 join token (if not provided, will attempt to retrieve)"
    echo ""
    echo "Note: For security, consider configuring passwordless sudo on control plane instead:"
    echo "  ssh $CONTROL_PLANE_USER@$CONTROL_PLANE_HOST 'echo \"$CONTROL_PLANE_USER ALL=(ALL) NOPASSWD: ALL\" | sudo tee /etc/sudoers.d/$CONTROL_PLANE_USER-nopasswd'"
    exit 1
fi

CURRENT_HOST="$1"
NEW_HOSTNAME="$2"
SSH_USER="${3:-scispike}"  # Use provided user or default to scispike
SUDO_PASSWORD="${4:-}"     # Optional sudo password (for both control plane and new node)
PROVIDED_TOKEN="${5:-}"    # Optional token provided as 5th parameter

# Configuration
CONTROL_PLANE_HOST="k8s-cp-01"
CONTROL_PLANE_USER="scispike"
CONTROL_PLANE_IP="100.68.247.112"  # Primary control plane Tailscale IP
RKE2_SERVER_PORT="9345"

print_info "Adding new node to RKE2 cluster"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Current Hostname: $CURRENT_HOST"
echo "  New Hostname:     $NEW_HOSTNAME"
echo "  SSH User:         $SSH_USER"
echo "  Control Plane:    $CONTROL_PLANE_HOST ($CONTROL_PLANE_IP)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Verify SSH access to current host
print_info "Step 1: Verifying SSH access to $CURRENT_HOST..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$SSH_USER@$CURRENT_HOST" "echo 'SSH connection successful'" &>/dev/null; then
    print_error "Cannot connect to $CURRENT_HOST via SSH"
    echo ""
    echo "Please ensure:"
    echo "  1. Passwordless SSH is set up: ssh-copy-id $SSH_USER@$CURRENT_HOST"
    echo "  2. The hostname/IP is correct"
    echo "  3. The host is reachable on the network"
    exit 1
fi
print_success "SSH access verified"

# Step 2: Get join token from control plane
if [ -n "$PROVIDED_TOKEN" ]; then
    print_info "Step 2: Using provided join token"
    JOIN_TOKEN="$PROVIDED_TOKEN"
    print_success "Join token provided"
else
    print_info "Step 2: Retrieving join token from control plane..."
    if ! ssh -o ConnectTimeout=5 "$CONTROL_PLANE_USER@$CONTROL_PLANE_HOST" "echo 'Control plane accessible'" &>/dev/null; then
        print_error "Cannot connect to control plane ($CONTROL_PLANE_HOST)"
        exit 1
    fi

    # Try to get token with passwordless sudo first
    JOIN_TOKEN=$(ssh "$CONTROL_PLANE_USER@$CONTROL_PLANE_HOST" "sudo -n cat /var/lib/rancher/rke2/server/node-token 2>/dev/null" || echo "")

    # If that failed and sudo password provided, try with password
    if [ -z "$JOIN_TOKEN" ] && [ -n "$SUDO_PASSWORD" ]; then
        print_info "Attempting to retrieve token with provided sudo password..."
        # Use echo to pipe password to sudo -S (reads password from stdin)
        JOIN_TOKEN=$(ssh "$CONTROL_PLANE_USER@$CONTROL_PLANE_HOST" "echo '$SUDO_PASSWORD' | sudo -S cat /var/lib/rancher/rke2/server/node-token 2>/dev/null" || echo "")
    fi

    # If still failed, prompt user to provide token manually
    if [ -z "$JOIN_TOKEN" ]; then
        print_warning "Failed to retrieve join token from control plane"
        echo ""
        if [ -z "$SUDO_PASSWORD" ]; then
            echo "Options:"
            echo "  1. Provide sudo password as 4th parameter:"
            echo "     $0 $CURRENT_HOST $NEW_HOSTNAME $SSH_USER <sudo-password>"
            echo ""
            echo "  2. Retrieve token manually and provide as 5th parameter:"
            echo "     ssh $CONTROL_PLANE_USER@$CONTROL_PLANE_HOST 'sudo cat /var/lib/rancher/rke2/server/node-token'"
            echo "     $0 $CURRENT_HOST $NEW_HOSTNAME $SSH_USER '' <token>"
            echo ""
            echo "  3. Configure passwordless sudo (recommended):"
            echo "     ssh $CONTROL_PLANE_USER@$CONTROL_PLANE_HOST 'echo \"$CONTROL_PLANE_USER ALL=(ALL) NOPASSWD: ALL\" | sudo tee /etc/sudoers.d/$CONTROL_PLANE_USER-nopasswd'"
        else
            echo "Sudo password provided but still failed. Please retrieve token manually:"
            echo "  ssh $CONTROL_PLANE_USER@$CONTROL_PLANE_HOST 'sudo cat /var/lib/rancher/rke2/server/node-token'"
            echo ""
            echo "Then re-run with token as 5th parameter:"
            echo "  $0 $CURRENT_HOST $NEW_HOSTNAME $SSH_USER '$SUDO_PASSWORD' <token>"
        fi
        exit 1
    else
        print_success "Join token retrieved"
    fi
fi

# Step 3: Set hostname on new node
print_info "Step 3: Setting hostname to $NEW_HOSTNAME..."
if [ -n "$SUDO_PASSWORD" ]; then
    ssh "$SSH_USER@$CURRENT_HOST" "echo '$SUDO_PASSWORD' | sudo -S hostnamectl set-hostname $NEW_HOSTNAME" || {
        print_error "Failed to set hostname (with sudo password)"
        exit 1
    }
else
    ssh "$SSH_USER@$CURRENT_HOST" "sudo hostnamectl set-hostname $NEW_HOSTNAME" || {
        print_error "Failed to set hostname. You may need to provide sudo password as 4th parameter."
        exit 1
    }
fi
print_success "Hostname set to $NEW_HOSTNAME"

# Step 3.5: Reboot to ensure hostname is fully recognized (optional but recommended)
echo ""
read -p "Reboot the node now to ensure the hostname is fully recognized? (recommended) [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Rebooting node $CURRENT_HOST..."
    print_warning "This will disconnect SSH. Waiting for node to come back online..."
    
    # Initiate reboot in background
    if [ -n "$SUDO_PASSWORD" ]; then
        ssh "$SSH_USER@$CURRENT_HOST" "echo '$SUDO_PASSWORD' | sudo -S reboot" 2>/dev/null || true
    else
        ssh "$SSH_USER@$CURRENT_HOST" "sudo reboot" 2>/dev/null || true
    fi
    
    # Wait for node to go down
    sleep 5
    
    # Wait for node to come back up (check SSH connectivity)
    MAX_REBOOT_WAIT=300  # 5 minutes
    REBOOT_ELAPSED=0
    REBOOT_INTERVAL=5
    
    print_info "Waiting for node to reboot (this may take 1-2 minutes)..."
    while [ $REBOOT_ELAPSED -lt $MAX_REBOOT_WAIT ]; do
        if ssh -o ConnectTimeout=5 -o BatchMode=yes "$SSH_USER@$CURRENT_HOST" "echo 'Node is back online'" &>/dev/null; then
            print_success "Node is back online after reboot"
            # Give it a few more seconds for services to fully start
            sleep 10
            break
        fi
        echo -n "."
        sleep $REBOOT_INTERVAL
        REBOOT_ELAPSED=$((REBOOT_ELAPSED + REBOOT_INTERVAL))
    done
    
    if [ $REBOOT_ELAPSED -ge $MAX_REBOOT_WAIT ]; then
        print_warning "Node did not come back online within $MAX_REBOOT_WAIT seconds"
        echo ""
        echo "Please verify the node is online and accessible, then re-run this script."
        echo "The hostname has been set, so you can continue from Step 4 (RKE2 installation)."
        exit 1
    fi
    
    # Verify hostname was set correctly
    ACTUAL_HOSTNAME=$(ssh "$SSH_USER@$CURRENT_HOST" "hostname" 2>/dev/null || echo "")
    if [ "$ACTUAL_HOSTNAME" != "$NEW_HOSTNAME" ]; then
        print_warning "Hostname mismatch after reboot (expected: $NEW_HOSTNAME, got: $ACTUAL_HOSTNAME)"
        print_info "Continuing anyway..."
    else
        print_success "Hostname confirmed after reboot: $ACTUAL_HOSTNAME"
    fi
else
    print_info "Skipping reboot. Hostname change is active, but a reboot is recommended for full consistency."
fi

# Step 4: Install RKE2 agent
print_info "Step 4: Installing RKE2 agent..."
if [ -n "$SUDO_PASSWORD" ]; then
    ssh "$SSH_USER@$CURRENT_HOST" "echo '$SUDO_PASSWORD' | sudo -S bash -c 'if command -v rke2 &>/dev/null; then echo \"RKE2 is already installed, skipping installation\"; exit 0; fi; curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=\"agent\" sh - && systemctl enable rke2-agent.service'" || {
        print_error "Failed to install RKE2 agent"
        exit 1
    }
else
    ssh "$SSH_USER@$CURRENT_HOST" <<'INSTALL_RKE2'
        # Check if RKE2 is already installed
        if command -v rke2 &>/dev/null; then
            echo "RKE2 is already installed, skipping installation"
            exit 0
        fi
        
        # Install RKE2 agent
        curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sudo sh -
        
        # Enable service
        sudo systemctl enable rke2-agent.service
INSTALL_RKE2
    if [ $? -ne 0 ]; then
        print_error "Failed to install RKE2 agent"
        exit 1
    fi
fi

print_success "RKE2 agent installed"

# Step 5: Configure RKE2 agent
print_info "Step 5: Configuring RKE2 agent..."
SERVER_URL="https://${CONTROL_PLANE_IP}:${RKE2_SERVER_PORT}"

if [ -n "$SUDO_PASSWORD" ]; then
    ssh "$SSH_USER@$CURRENT_HOST" "echo '$SUDO_PASSWORD' | sudo -S bash -c 'mkdir -p /etc/rancher/rke2 && cat > /etc/rancher/rke2/config.yaml <<CONFIG
server: ${SERVER_URL}
token: ${JOIN_TOKEN}
CONFIG
'" || {
        print_error "Failed to configure RKE2 agent"
        exit 1
    }
else
    ssh "$SSH_USER@$CURRENT_HOST" <<EOF
        # Create config directory
        sudo mkdir -p /etc/rancher/rke2
        
        # Create config file
        sudo tee /etc/rancher/rke2/config.yaml > /dev/null <<CONFIG
server: ${SERVER_URL}
token: ${JOIN_TOKEN}
CONFIG
        
        # Verify config was written
        if [ ! -f /etc/rancher/rke2/config.yaml ]; then
            echo "ERROR: Config file not created"
            exit 1
        fi
EOF
    if [ $? -ne 0 ]; then
        print_error "Failed to configure RKE2 agent"
        exit 1
    fi
fi
print_success "RKE2 agent configured"

# Step 6: Start RKE2 agent
print_info "Step 6: Starting RKE2 agent service..."
if [ -n "$SUDO_PASSWORD" ]; then
    if ssh "$SSH_USER@$CURRENT_HOST" "echo '$SUDO_PASSWORD' | sudo -S systemctl restart rke2-agent.service 2>/dev/null"; then
        print_success "RKE2 agent service started"
    else
        print_error "Failed to start RKE2 agent service"
        exit 1
    fi
else
    if ssh "$SSH_USER@$CURRENT_HOST" "sudo systemctl restart rke2-agent.service"; then
        print_success "RKE2 agent service started"
    else
        print_error "Failed to start RKE2 agent service"
        exit 1
    fi
fi

# Step 7: Wait for node to join and become Ready
print_info "Step 7: Waiting for node to join cluster and become Ready..."
echo "This may take 1-2 minutes..."

MAX_WAIT=180  # 3 minutes
ELAPSED=0
INTERVAL=5

while [ $ELAPSED -lt $MAX_WAIT ]; do
    # Check if node appears in cluster
    NODE_STATUS=$(ssh "$CONTROL_PLANE_USER@$CONTROL_PLANE_HOST" "~/kubectl get node $NEW_HOSTNAME -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}' 2>/dev/null" || echo "")
    
    if [ "$NODE_STATUS" = "True" ]; then
        print_success "Node $NEW_HOSTNAME is Ready!"
        break
    elif [ -n "$NODE_STATUS" ]; then
        echo -n "."
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
    else
        echo -n "."
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
    fi
done

if [ "$NODE_STATUS" != "True" ]; then
    print_warning "Node did not become Ready within $MAX_WAIT seconds"
    echo ""
    echo "Checking node status..."
    ssh "$CONTROL_PLANE_USER@$CONTROL_PLANE_HOST" "~/kubectl get node $NEW_HOSTNAME" || {
        print_error "Node not found in cluster"
        echo ""
        echo "Troubleshooting steps:"
        echo "  1. Check RKE2 agent logs on the node:"
        echo "     ssh $SSH_USER@$CURRENT_HOST 'sudo journalctl -u rke2-agent.service -n 50'"
        echo "  2. Verify network connectivity:"
        echo "     ssh $SSH_USER@$CURRENT_HOST 'ping -c 3 $CONTROL_PLANE_IP'"
        echo "  3. Check firewall rules (if using UFW):"
        echo "     ssh $SSH_USER@$CURRENT_HOST 'sudo ufw status'"
        exit 1
    }
else
    # Step 8: Display node information
    echo ""
    print_info "Step 8: Node information:"
    ssh "$CONTROL_PLANE_USER@$CONTROL_PLANE_HOST" "~/kubectl get node $NEW_HOSTNAME -o wide"
    echo ""
    
    # Step 9: Ask about Longhorn labeling
    echo ""
    read -p "Do you want to label this node for Longhorn storage? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Labeling node for Longhorn..."
        ssh "$CONTROL_PLANE_USER@$CONTROL_PLANE_HOST" "~/kubectl label node $NEW_HOSTNAME node.longhorn.io/create-default-disk=true --overwrite" && {
            print_success "Node labeled for Longhorn storage"
        } || {
            print_warning "Failed to label node for Longhorn (non-critical)"
        }
    fi
    
    # Final summary
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "Node $NEW_HOSTNAME successfully added to cluster!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Next steps:"
    echo "  1. Verify node is Ready: kubectl get nodes $NEW_HOSTNAME"
    echo "  2. Check node details: kubectl describe node $NEW_HOSTNAME"
    echo "  3. Monitor pod scheduling: kubectl get pods --all-namespaces -o wide | grep $NEW_HOSTNAME"
    echo ""
fi

