#!/bin/bash
# Script to check cluster accessibility and diagnose connection issues

KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"

echo "=========================================="
echo "Cluster Access Diagnostic"
echo "=========================================="
echo ""

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo "❌ Kubeconfig file not found: $KUBECONFIG_FILE"
    exit 1
fi

export KUBECONFIG="$KUBECONFIG_FILE"

# Get cluster server from kubeconfig
CLUSTER_SERVER=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || echo "unknown")
echo "📡 Cluster Server: $CLUSTER_SERVER"
echo ""

# Extract IP and port
if [[ $CLUSTER_SERVER =~ https?://([^:]+):([0-9]+) ]]; then
    CLUSTER_IP="${BASH_REMATCH[1]}"
    CLUSTER_PORT="${BASH_REMATCH[2]}"
else
    CLUSTER_IP=$(echo "$CLUSTER_SERVER" | sed 's|https\?://||' | cut -d: -f1)
    CLUSTER_PORT=$(echo "$CLUSTER_SERVER" | sed 's|https\?://||' | cut -d: -f2)
fi

echo "🔍 Testing Connectivity:"
echo ""

# Test 1: Ping cluster IP
echo -n "  Ping cluster IP ($CLUSTER_IP): "
if ping -c 1 -W 2 "$CLUSTER_IP" &>/dev/null; then
    echo "✅ Reachable"
else
    echo "❌ Not reachable"
fi

# Test 2: Test TCP connection to API server
echo -n "  TCP connection to API server ($CLUSTER_IP:$CLUSTER_PORT): "
if timeout 3 bash -c "echo > /dev/tcp/$CLUSTER_IP/$CLUSTER_PORT" 2>/dev/null; then
    echo "✅ Port is open"
else
    echo "❌ Port is closed or unreachable"
fi

# Test 3: kubectl cluster-info
echo -n "  kubectl cluster-info: "
if timeout 5 kubectl cluster-info &>/dev/null; then
    echo "✅ Accessible"
    kubectl cluster-info 2>&1 | head -1 | sed 's/^/    /'
else
    echo "❌ Timeout or error"
    kubectl cluster-info 2>&1 | head -1 | sed 's/^/    Error: /'
fi

echo ""

# Test 4: SSH to k8s-cp-01 (for Rancher)
echo "🔍 Testing SSH to k8s-cp-01 (for Rancher):"
echo -n "  SSH connection: "
if timeout 3 ssh -o ConnectTimeout=2 -o BatchMode=yes scispike@k8s-cp-01 "echo 'SSH works'" &>/dev/null 2>&1; then
    echo "✅ Accessible"
else
    echo "❌ Not accessible (timeout or connection refused)"
    echo "    Note: This is only needed for Rancher port-forwarding"
fi

echo ""

# Test 5: Check for stale port-forwards
echo "🔍 Checking Port-Forward Status:"
STALE_PIDS=0
if [ -f /tmp/k8s-access-all.pids ]; then
    while read -r pid; do
        if ! kill -0 "$pid" 2>/dev/null; then
            STALE_PIDS=$((STALE_PIDS + 1))
        fi
    done < /tmp/k8s-access-all.pids
    if [ $STALE_PIDS -gt 0 ]; then
        echo "  ⚠️  Found $STALE_PIDS stale PIDs in /tmp/k8s-access-all.pids"
        echo "     Run: ./kill-access-all.sh to clean up"
    else
        echo "  ✅ No stale PIDs"
    fi
else
    echo "  ✅ No PID file (clean state)"
fi

# Check for running port-forwards
RUNNING_PF=$(ps aux | grep -c "[k]ubectl port-forward" 2>/dev/null || echo "0")
if [ "${RUNNING_PF:-0}" -gt 0 ]; then
    echo "  ℹ️  Found $RUNNING_PF running port-forward process(es)"
else
    echo "  ✅ No running port-forwards"
fi

echo ""

# Summary and recommendations
echo "=========================================="
echo "Summary & Recommendations"
echo "=========================================="
echo ""

# Test cluster access one more time for summary
if timeout 5 kubectl get nodes &>/dev/null 2>&1; then
    echo "✅ Cluster is ACCESSIBLE"
    echo ""
    echo "You can now run:"
    echo "  ./access-all.sh"
    echo ""
    echo "To start all port-forwards."
else
    echo "❌ Cluster is NOT ACCESSIBLE"
    echo ""
    echo "Possible causes:"
    echo "  1. Network/VPN not connected"
    echo "  2. Cluster nodes are down or restarting"
    echo "  3. Firewall blocking connection"
    echo "  4. Cluster IP changed"
    echo ""
    echo "Actions:"
    echo "  1. Check your VPN/network connection"
    echo "  2. Wait 5-10 minutes if cluster is restarting"
    echo "  3. Contact cluster administrator"
    echo "  4. Verify kubeconfig is up to date"
    echo ""
    echo "Once cluster is accessible, run:"
    echo "  ./check-cluster-access.sh  # Verify access"
    echo "  ./access-all.sh            # Start port-forwards"
fi

echo ""

