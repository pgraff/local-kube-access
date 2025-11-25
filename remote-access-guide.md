# Remote Access Guide for Your Kubernetes Cluster

## Overview

Yes, you can absolutely access your cluster from anywhere using the same scripts! Since you're using Tailscale, all your devices (including your laptop) are on the same virtual network.

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

**Option A: Clone from Git (Recommended)**
```bash
git clone <your-repo>
cd k8s-home
# The kubeconfig file should be in the repo
```

**Option B: Copy directly**
```bash
# From your Mac, copy the kubeconfig
scp ~/.kube/config-rke2-cluster.yaml laptop:/home/youruser/.kube/
```

**Option C: Generate new kubeconfig on control plane**
```bash
# SSH to control plane and copy kubeconfig
ssh scispike@k8s-cp-01 "cat ~/.kube/config" > ~/.kube/config-rke2-cluster.yaml
```

### 3. Verify Connectivity

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml

# Test connection
kubectl cluster-info
kubectl get nodes
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
   git clone <your-repo>
   cd k8s-home
   ```

4. **Copy Kubeconfig** (if not in repo)
   ```bash
   mkdir -p ~/.kube
   # Copy from Mac or generate on control plane
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
- **Kubeconfig**: `~/.kube/config-rke2-cluster.yaml`

### Access Scripts
- `./access-rancher.sh` → http://localhost:8443
- `./access-longhorn.sh` → http://localhost:8080
- `./access-kubecost.sh` → http://localhost:9090

### Setup Script
- `./setup-remote-laptop.sh` - Automated setup for new machines

