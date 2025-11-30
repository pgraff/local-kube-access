# Setting Up Lens for Your Kubernetes Cluster

## What We've Done

1. ✅ Retrieved kubeconfig from control plane node (k8s-cp-01)
2. ✅ Saved kubeconfig to: `~/.kube/config-rke2-cluster.yaml`
3. ✅ API Server: `https://100.68.247.112:6443`

## Using Lens

### Option 1: Import Kubeconfig File (Recommended)

1. Open Lens
2. Click the **"+"** button or **"Add Cluster"**
3. Select **"Browse"** or **"Import from file"**
4. Navigate to: `~/.kube/config-rke2-cluster.yaml`
   - Or use the full path: `/Users/pettergraff/.kube/config-rke2-cluster.yaml`
5. Lens should detect the cluster and add it

### Option 2: Copy to Default Location

If you want to use the default kubeconfig location:

```bash
# Backup your existing config (if any)
cp ~/.kube/config ~/.kube/config.backup 2>/dev/null || true

# Copy the cluster config
cp ~/.kube/config-rke2-cluster.yaml ~/.kube/config

# Or merge with existing configs
export KUBECONFIG=~/.kube/config:~/.kube/config-rke2-cluster.yaml
kubectl config view --flatten > ~/.kube/config-merged
mv ~/.kube/config-merged ~/.kube/config
```

### Option 3: Set KUBECONFIG Environment Variable

```bash
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml
```

Then Lens should automatically detect it.

## Troubleshooting

### If Lens Can't Connect:

1. **Check Network Access**
   - Ensure your Mac can reach `100.68.247.112:6443`
   - Test with: `curl -k https://100.68.247.112:6443/version`

2. **Check Firewall**
   - The API server port 6443 must be accessible from your Mac
   - If behind a firewall, you may need to set up port-forwarding

3. **Certificate Issues**
   - The kubeconfig uses embedded certificates
   - Lens should handle this automatically
   - If issues occur, check that the certificates are valid

4. **Alternative: Use SSH Tunnel**
   If direct access doesn't work, set up an SSH tunnel:
   ```bash
   ssh -L 6443:localhost:6443 scispike@k8s-cp-01
   ```
   Then in Lens, use `https://localhost:6443` as the server URL

## Cluster Information

- **Cluster Name**: default (or "local" in Rancher)
- **API Server**: https://100.68.247.112:6443
- **Context**: default
- **User**: default

## Metrics Configuration

If Lens shows "Metrics are not available due to missing or invalid configuration":

**Important**: Lens requires its own Prometheus-based metrics stack, separate from the Kubernetes metrics-server. The metrics-server (used by `kubectl top`) is different from what Lens needs.

### Enable Lens Metrics (Required)

Lens needs to install Prometheus, Kube State Metrics, and Node Exporter:

1. **Open Lens** and select your cluster
2. **Right-click on the cluster icon** (top-left corner) → Choose **"Settings"**
3. **Navigate to "Lens Metrics"** section
4. **Toggle ON**:
   - Prometheus
   - Kube State Metrics  
   - Node Exporter
5. **Click "Apply"** to deploy the components
6. **Wait 2-5 minutes** for Prometheus to start collecting data

### What Gets Installed

Lens will create:
- **Prometheus** - Metrics collection and storage
- **Kube State Metrics** - Kubernetes object metrics
- **Node Exporter** - Node-level system metrics
- Namespace: `lens-metrics` (or similar)

### Resource Requirements

Lens Metrics requires:
- **CPU**: ~1-2 cores
- **Memory**: ~2-4 GB
- **Storage**: ~20-50 GB for metrics retention

### Verification

After installation, check:

```bash
# Check if Lens metrics components are running
kubectl get pods -A | grep -E "prometheus|kube-state-metrics|node-exporter"

# Check Lens metrics namespace
kubectl get namespace | grep lens
```

### Troubleshooting

**If metrics still don't show:**

1. **Wait longer** - Prometheus needs time to collect initial data (5-10 minutes)
2. **Check pod status**:
   ```bash
   kubectl get pods -A | grep -E "prometheus|kube-state-metrics"
   ```
3. **Check resource availability**:
   ```bash
   kubectl top nodes
   kubectl top pods -A
   ```
4. **Restart Lens** after installation completes
5. **Check Lens logs** (if available in Lens settings)

**Note**: The Kubernetes metrics-server (`kubectl top`) is separate and works independently. Lens Metrics is specifically for Lens dashboards and visualizations.

## Next Steps

1. Open Lens
2. Import the kubeconfig file
3. Lens should connect and show your cluster
4. You'll be able to browse pods, services, deployments, etc.
5. If metrics don't show, wait 2-3 minutes or restart metrics-server

