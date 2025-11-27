# Troubleshooting NotReady Nodes

## Current Status

- **k8s-worker-08**: ✅ **Ready** (was previously NotReady, now recovered)
- **k8s-worker-09**: ❌ **NotReady** - Node unreachable

## k8s-worker-09 Issue

### Symptoms
- Node status: `NotReady`
- Condition: `NodeStatusUnknown`
- Message: "Kubelet stopped posting node status"
- **SSH**: Connection timeout
- **Ping**: 100% packet loss
- **Last heartbeat**: Wed, 26 Nov 2025 20:21:44 -0600 (over 24 hours ago)

### Root Cause
The node is **completely unreachable**, indicating:
1. **Node is powered off** (most likely)
2. **Network connectivity lost** (Tailscale disconnected or network issue)
3. **System crash** (less likely but possible)
4. **RKE2 agent crashed** (but SSH would still work)

### Diagnosis Steps

#### 1. Check Physical/Network Status
```bash
# Try to ping the node
ping 100.98.68.123

# Check Tailscale status (if you have access to the node physically)
# On the node itself:
tailscale status
```

#### 2. Check from Control Plane
```bash
# From control plane node
ssh scispike@k8s-cp-01 "~/kubectl get node k8s-worker-09 -o yaml | grep -A 10 conditions"
```

#### 3. Check Node Events
```bash
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml
kubectl get events --field-selector involvedObject.name=k8s-worker-09 --sort-by='.lastTimestamp'
```

## Resolution Steps

### Option 1: Node is Powered Off (Most Common)

**If the node is intentionally powered off:**
- This is expected behavior
- The node will remain NotReady until powered back on
- When powered on, it should automatically rejoin the cluster

**To verify when it comes back:**
```bash
# Watch for node to become Ready
watch -n 5 'kubectl get nodes k8s-worker-09'
```

### Option 2: Network Connectivity Issue

**If Tailscale is disconnected:**
1. Physically access the node or use console access
2. Check Tailscale status:
   ```bash
   tailscale status
   ```
3. Restart Tailscale if needed:
   ```bash
   sudo systemctl restart tailscaled
   ```

**If network cable is disconnected:**
- Reconnect network cable
- Node should automatically recover

### Option 3: RKE2 Agent Issue

**If you can SSH to the node but kubelet isn't working:**
```bash
# SSH to the node
ssh scispike@k8s-worker-09

# Check RKE2 agent status
sudo systemctl status rke2-agent.service

# Check logs
sudo journalctl -u rke2-agent.service -n 50

# Restart if needed
sudo systemctl restart rke2-agent.service
```

### Option 4: Node Needs to be Removed

**If the node is permanently unavailable and you want to remove it:**

⚠️ **Warning**: Only do this if you're sure the node won't come back, as this will:
- Evict all pods from the node
- Remove the node from the cluster
- Require manual re-joining if the node comes back

```bash
# Drain the node (removes all pods)
kubectl drain k8s-worker-09 --ignore-daemonsets --delete-emptydir-data --force

# Delete the node
kubectl delete node k8s-worker-09
```

**To rejoin later**, follow the [Add Node Guide](add-node-guide.md).

## Current Impact

### Pods on k8s-worker-09

Some pods are stuck in `Terminating` state on k8s-worker-09:
- `rancher-84495749b-wcfb7` (Terminating)
- `ditto-dittoui-6758fd4dc5-gt2jw` (Terminating)
- `ditto-swaggerui-6bc86d9d84-ptdnf` (Terminating)
- `hono-adapter-amqp-6897456786-7z7mj` (Terminating)
- `kafka-cluster-controllers-7` (Terminating)

**These pods cannot be deleted** until the node comes back or is removed from the cluster.

### Workaround: Force Delete Pods

If you need to remove these pods immediately:

```bash
# Force delete pods stuck in Terminating
kubectl delete pod <pod-name> -n <namespace> --force --grace-period=0

# Example:
kubectl delete pod rancher-84495749b-wcfb7 -n cattle-system --force --grace-period=0
```

⚠️ **Warning**: Force deleting pods can cause data loss if they have unsaved state.

## Prevention

### Monitor Node Health

```bash
# Check all node statuses
kubectl get nodes

# Watch for NotReady nodes
kubectl get nodes | grep NotReady

# Check node conditions
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[?(@.type=="Ready")].status,REASON:.status.conditions[?(@.type=="Ready")].reason
```

### Set Up Alerts

Consider setting up monitoring/alerts for:
- Node NotReady status
- Node heartbeat failures
- Network connectivity issues

## Recovery

When k8s-worker-09 comes back online:

1. **Automatic Recovery** (if RKE2 agent is running):
   - Node should automatically rejoin
   - Status should change from NotReady to Ready
   - Pods will be rescheduled if needed

2. **Manual Recovery** (if RKE2 agent stopped):
   ```bash
   # SSH to the node
   ssh scispike@k8s-worker-09
   
   # Restart RKE2 agent
   sudo systemctl restart rke2-agent.service
   
   # Check status
   sudo systemctl status rke2-agent.service
   ```

3. **Verify Recovery**:
   ```bash
   # From control plane
   kubectl get nodes k8s-worker-09
   
   # Should show Ready status
   ```

## Related Documentation

- [Add Node Guide](add-node-guide.md) - How to add/rejoin nodes
- [Cluster Quick Reference](cluster-quick-reference.md) - Common commands
- [Cluster Info Summary](cluster-info-summary.md) - Cluster status

