# Remote Access Guide for Your Kubernetes Cluster

## Overview

Yes, you can absolutely access your cluster from anywhere using the same scripts! Since you're using Tailscale, all your devices (including your laptop) are on the same virtual network.

## How to Identify the Correct Kubeconfig

**What is a kubeconfig?**
- A YAML file that contains authentication and connection information for your Kubernetes cluster
- It tells `kubectl` how to connect to your cluster's API server
- For this cluster, we saved it as `config-rke2-cluster.yaml`

**How to verify you have the right kubeconfig:**

1. **Check the API server address** - It should point to your cluster:
   ```bash
   grep "server:" ~/.kube/config-rke2-cluster.yaml
   # Should show: server: https://100.68.247.112:6443
   ```

2. **Test the connection**:
   ```bash
   export KUBECONFIG=~/.kube/config-rke2-cluster.yaml
   kubectl cluster-info
   # Should show: Kubernetes control plane is running at https://100.68.247.112:6443
   ```

3. **Verify it shows your nodes**:
   ```bash
   kubectl get nodes
   # Should list your 14 nodes (k8s-cp-01, k8s-cp-02, k8s-cp-03, k8s-storage-01, k8s-worker-01 through k8s-worker-10)
   ```

**If you have multiple kubeconfigs**, you can check which one is for this cluster:
```bash
# List all kubeconfig files
ls -la ~/.kube/*.yaml ~/.kube/config 2>/dev/null

# Check each one's API server
for file in ~/.kube/*.yaml ~/.kube/config; do
  [ -f "$file" ] && echo "=== $file ===" && grep "server:" "$file" | head -1
done
# Look for the one with: server: https://100.68.247.112:6443
```

## How It Works

### Network Architecture

```
Your Laptop (Ubuntu, Tailscale)
    ↓ (via Tailscale VPN)
Tailscale Network (100.x.x.x addresses)
    ↓
Kubernetes API Server (100.68.247.112:6443)
    ↓
Cluster Services (Rancher, Longhorn, Kubecost)
```

Since everything is on Tailscale:
- ✅ Your laptop can reach the API server directly
- ✅ No need for SSH tunneling
- ✅ Same kubeconfig works from anywhere
- ✅ Scripts work identically

## Setup on Your Laptop

### 1. Install Prerequisites

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installation
kubectl version --client
```

### 2. Get the Kubeconfig

**What is a kubeconfig file?**
- It's a YAML file that contains credentials and connection info for your cluster
- It tells kubectl how to connect to your Kubernetes API server
- For this cluster, it's named `config-rke2-cluster.yaml`
- Location: `~/.kube/config-rke2-cluster.yaml` (or wherever you save it)

**How to identify the correct kubeconfig:**
1. **Check the API server address** - Should point to `100.68.247.112:6443`
2. **Check the cluster name** - Should be `default` or match your cluster
3. **File location** - Usually in `~/.kube/` directory

**Option A: Clone from Git (Recommended)**
```bash
git clone git@github.com:pgraff/local-kube-access.git
cd local-kube-access
# Check if kubeconfig is in the repo
ls -la .kube/ || ls -la *.yaml
# If found, verify it's the right one:
grep "server:" .kube/config-rke2-cluster.yaml
# Should show: server: https://100.68.247.112:6443
```

**Option B: Copy from your Mac**
```bash
# From your Mac, copy the kubeconfig to your laptop
scp ~/.kube/config-rke2-cluster.yaml your-laptop:/home/youruser/.kube/
```

**Option C: Generate fresh from control plane (Most Reliable)**
```bash
# SSH to control plane and get the kubeconfig
ssh scispike@k8s-cp-01 "cat ~/.kube/config" > ~/.kube/config-rke2-cluster.yaml

# Verify it's the right one - should show your API server
cat ~/.kube/config-rke2-cluster.yaml | grep "server:"
# Should show: server: https://100.68.247.112:6443
```

**Option D: Check what kubeconfig files you have**
```bash
# List all kubeconfig files
ls -la ~/.kube/*.yaml ~/.kube/*.config 2>/dev/null

# Check which one points to your cluster
for file in ~/.kube/*.yaml ~/.kube/*.config; do
  echo "=== $file ==="
  grep -A 1 "server:" "$file" 2>/dev/null | head -2
done
```

### 3. Verify You Have the Right Kubeconfig

**First, check the kubeconfig points to your cluster:**
```bash
# View the API server address
cat ~/.kube/config-rke2-cluster.yaml | grep "server:"
# Should show: server: https://100.68.247.112:6443
```

**If you have multiple kubeconfigs, identify the right one:**
```bash
# The correct kubeconfig should have:
# - server: https://100.68.247.112:6443
# - cluster name: default
# - Contains certificate data (long base64 strings)
```

### 4. Verify Connectivity

```bash
# Set kubeconfig (use the path to your file)
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml

# Or if it's in a different location:
export KUBECONFIG=/path/to/your/config-rke2-cluster.yaml

# Test connection
kubectl cluster-info
# Should show: Kubernetes control plane is running at https://100.68.247.112:6443

kubectl get nodes
# Should show your 14 nodes (3 control plane + 10 workers + 1 storage)
```

If this works, you're all set!

## Using the Scripts Remotely

### The Scripts Work the Same Way

All your access scripts (`access-rancher.sh`, `access-longhorn.sh`, `access-kubecost.sh`) will work identically on your laptop because:

1. **They use the kubeconfig file** - which contains all the certificates
2. **They connect directly to the API server** - via Tailscale network
3. **Port-forwarding works the same** - kubectl port-forward works from anywhere

### Example Usage on Laptop

```bash
# Clone your repo
git clone <your-repo>
cd k8s-home

# Make scripts executable
chmod +x *.sh

# Access Rancher
./access-rancher.sh
# Then open http://localhost:8443

# Access Longhorn
./access-longhorn.sh
# Then open http://localhost:8080

# Access Kubecost
./access-kubecost.sh
# Then open http://localhost:9090
```

## Network Requirements

### What You Need

1. **Tailscale running** on your laptop
2. **Tailscale connected** - verify with `tailscale status`
3. **Can reach API server** - test with:
   ```bash
   curl -k https://100.68.247.112:6443/version
   ```

### Firewall Considerations

- The API server (port 6443) must be accessible via Tailscale
- Since all nodes are on Tailscale, this should work automatically
- No port forwarding needed on your router

## Security Best Practices

### 1. Protect Your Kubeconfig

The kubeconfig file contains:
- Cluster CA certificate
- Client certificate
- Client private key

**Keep it secure:**
```bash
# Set proper permissions
chmod 600 ~/.kube/config-rke2-cluster.yaml

# Don't commit to public Git repos
echo ".kube/" >> .gitignore
```

### 2. Use Git Securely

**Option A: Private Repository**
- Use a private Git repo (GitHub private, GitLab, etc.)
- Store kubeconfig in the repo (it's encrypted in transit)

**Option B: Separate Secrets**
- Don't commit kubeconfig to Git
- Copy it manually to each machine
- Or use a secrets manager

**Option C: Use .gitignore**
```bash
# Add to .gitignore
.kube/
*.yaml
!*.md
!*.sh
```

Then manually copy kubeconfig when needed.

### 3. Consider Using Rancher for Remote Access

Instead of port-forwarding, you could:
1. Set up Rancher ingress properly (fix DNS/TLS)
2. Access Rancher via Tailscale IP
3. Use Rancher's built-in kubectl shell
4. Access all services through Rancher UI

## Troubleshooting Remote Access

### Can't Connect to API Server

```bash
# Test Tailscale connectivity
ping 100.68.247.112

# Test API server
curl -k https://100.68.247.112:6443/version

# Check kubectl
kubectl cluster-info
```

### Port-Forward Not Working

```bash
# Check if port is in use
lsof -i :8080

# Try different port
# Edit script to use different port (e.g., 8081)
```

### Certificate Issues

If you get certificate errors:
```bash
# Verify kubeconfig is valid
kubectl config view --kubeconfig=~/.kube/config-rke2-cluster.yaml

# Test connection
kubectl get nodes --kubeconfig=~/.kube/config-rke2-cluster.yaml
```

## Recommended Setup for Travel

### On Your Laptop

1. **Install kubectl**
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install -y kubectl
   ```

2. **Install Tailscale**
   ```bash
   # Already done if you mentioned it's on Tailscale
   tailscale status  # Verify connection
   ```

3. **Clone Your Repo**
   ```bash
   git clone git@github.com:pgraff/local-kube-access.git
   cd local-kube-access
   ```

4. **Get Kubeconfig** (if not in repo)
   ```bash
   mkdir -p ~/.kube
   # Option 1: Copy from Mac
   scp mac-user@mac-ip:~/.kube/config-rke2-cluster.yaml ~/.kube/
   
   # Option 2: Generate fresh from control plane (RECOMMENDED)
   ssh scispike@k8s-cp-01 "cat ~/.kube/config" > ~/.kube/config-rke2-cluster.yaml
   
   # Verify it's correct
   grep "server:" ~/.kube/config-rke2-cluster.yaml
   # Should show: server: https://100.68.247.112:6443
   ```

5. **Test Connection**
   ```bash
   export KUBECONFIG=~/.kube/config-rke2-cluster.yaml
   kubectl get nodes
   ```

6. **Use Scripts**
   ```bash
   ./access-rancher.sh
   ./access-longhorn.sh
   ./access-kubecost.sh
   ```

## Alternative: Rancher UI Access

Instead of port-forwarding, you could configure Rancher to be accessible directly:

1. **Fix Rancher Ingress** (we identified this earlier)
   - Set up DNS for `rancher.tailc2013b.ts.net`
   - Or use Tailscale IP directly
   - Configure TLS properly

2. **Access via Browser**
   - Just go to `https://rancher.tailc2013b.ts.net` or `https://<tailscale-ip>`
   - No port-forwarding needed
   - Access everything through Rancher UI

## Summary

✅ **Yes, the scripts work from anywhere** - as long as you have:
- kubectl installed
- kubeconfig file
- Tailscale connected
- Network access to API server (100.68.247.112:6443)

✅ **Same experience** - scripts work identically on Mac or Ubuntu laptop

✅ **Secure** - Tailscale provides encrypted VPN connection

✅ **Convenient** - Clone repo, copy kubeconfig, run scripts!

## Quick Reference

### Cluster Information
- **API Server**: https://100.68.247.112:6443
- **Control Plane**: k8s-cp-01 (100.68.247.112)
- **Kubeconfig File**: `~/.kube/config-rke2-cluster.yaml`
  - **How to verify**: `grep "server:" ~/.kube/config-rke2-cluster.yaml` should show `https://100.68.247.112:6443`
  - **Where to get it**: From control plane: `ssh scispike@k8s-cp-01 "cat ~/.kube/config" > ~/.kube/config-rke2-cluster.yaml`

### Access Scripts
- `./access-rancher.sh` → http://localhost:8443
- `./access-longhorn.sh` → http://localhost:8080
- `./access-kubecost.sh` → http://localhost:9090

### Setup Script
- `./setup-remote-laptop.sh` - Automated setup for new machines

