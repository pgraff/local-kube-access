#!/bin/bash
# Setup script for remote laptop access
# Run this on your Ubuntu laptop to set up cluster access

set -e

echo "=== Kubernetes Cluster Remote Access Setup ==="
echo ""

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    echo "✅ kubectl installed"
else
    echo "✅ kubectl already installed"
    kubectl version --client
fi

# Check Tailscale
if command -v tailscale &> /dev/null; then
    echo ""
    echo "Checking Tailscale status..."
    tailscale status | head -5 || echo "⚠️  Tailscale may not be connected"
else
    echo "⚠️  Tailscale not found - please install and connect"
fi

# Check for kubeconfig
echo ""
if [ -f "$HOME/.kube/config-rke2-cluster.yaml" ]; then
    echo "✅ Kubeconfig found at ~/.kube/config-rke2-cluster.yaml"
else
    echo "⚠️  Kubeconfig not found"
    echo "   Please copy it from your Mac or generate it:"
    echo "   ssh scispike@k8s-cp-01 'cat ~/.kube/config' > ~/.kube/config-rke2-cluster.yaml"
    echo ""
    read -p "Do you want to copy it from the control plane now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter control plane hostname (default: k8s-cp-01): " CP_HOST
        CP_HOST=${CP_HOST:-k8s-cp-01}
        mkdir -p ~/.kube
        ssh scispike@$CP_HOST "cat ~/.kube/config" > ~/.kube/config-rke2-cluster.yaml
        chmod 600 ~/.kube/config-rke2-cluster.yaml
        echo "✅ Kubeconfig copied"
    fi
fi

# Test connection
echo ""
echo "Testing cluster connection..."
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml

if kubectl cluster-info &> /dev/null; then
    echo "✅ Successfully connected to cluster!"
    kubectl get nodes --no-headers | wc -l | xargs echo "   Nodes available:"
else
    echo "❌ Cannot connect to cluster"
    echo "   Check:"
    echo "   1. Tailscale is connected"
    echo "   2. Can reach API server: curl -k https://100.68.247.112:6443/version"
    echo "   3. Kubeconfig is valid"
    exit 1
fi

# Make scripts executable
echo ""
echo "Making access scripts executable..."
chmod +x access-*.sh 2>/dev/null || echo "   Scripts not found in current directory"

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "You can now use:"
echo "  ./access-rancher.sh    - Access Rancher UI"
echo "  ./access-longhorn.sh   - Access Longhorn UI"
echo "  ./access-kubecost.sh   - Access Kubecost UI"
echo ""

