# Kubernetes Cluster Quick Reference

## Access Information

- **SSH to Control Plane:** `ssh scispike@k8s-cp-01`
- **kubectl on Control Plane:** `~/kubectl` (or add to PATH)
- **API Server:** https://100.68.247.112:6443
- **Rancher UI:** https://rancher.tailc2013b.ts.net (DNS not resolving - use port-forward instead)
- **Rancher via Port-Forward:** Run `./access-rancher.sh` then access http://localhost:8443
- **Kubeconfig:** `~/.kube/config` on control plane node

## Quick Commands

### Connect to Cluster
```bash
ssh scispike@k8s-cp-01
export PATH=$PATH:~/kubectl
```

### Check Cluster Status
```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces
```

### Check Issues
```bash
# Check failing pods
kubectl get pods --all-namespaces | grep -E 'Error|CrashLoopBackOff|Init:'

# Check CNI status
kubectl get pods -n kube-system -l k8s-app=cilium
kubectl get pods -n kube-system -l k8s-app=canal

# Check ingress status
kubectl get pods -n kube-system -l app.kubernetes.io/name=rke2-ingress-nginx

# Check Rancher status
kubectl get pods -n cattle-system -l app=rancher
```

### Get Logs
```bash
# Cilium logs
kubectl logs -n kube-system -l k8s-app=cilium --tail=50

# Ingress logs
kubectl logs -n kube-system -l app.kubernetes.io/name=rke2-ingress-nginx --tail=50

# Rancher logs
kubectl logs -n cattle-system -l app=rancher --tail=100
```

### Fix CNI Conflict (Recommended)
```bash
# Remove Calico/Canal
kubectl delete daemonset rke2-canal -n kube-system
kubectl delete namespace calico-system

# Verify Cilium is working
kubectl get pods -n kube-system -l k8s-app=cilium
```

## Node Information

### Control Plane Nodes
- k8s-cp-01: 100.68.247.112
- k8s-cp-02: 100.122.71.98
- k8s-cp-03: 100.68.223.86

### Worker Nodes
- k8s-worker-01 through k8s-worker-10

### Storage Node
- k8s-storage-01: 100.111.119.104

## Key Namespaces

- `kube-system` - Core Kubernetes components
- `cattle-system` - Rancher
- `cert-manager` - Certificate management
- `cattle-fleet-system` - Fleet controller

## Accessing Rancher

### Option 1: Port-Forwarding (Recommended - Works Now)
```bash
# Run the provided script
./access-rancher.sh

# Or manually:
ssh scispike@k8s-cp-01 "~/kubectl port-forward -n cattle-system service/rancher 8443:80"
```
Then open: **http://localhost:8443** in your browser

### Option 2: Fix DNS and TLS (For Production)
The ingress is configured but:
- DNS `rancher.tailc2013b.ts.net` doesn't resolve
- TLS certificate secret `tls-rancher-ingress` is missing

To fix:
1. Configure DNS for `rancher.tailc2013b.ts.net` to point to one of the node IPs
2. Create the TLS certificate or configure cert-manager to issue it

## RKE2 Configuration

Config file: `/etc/rancher/rke2/config.yaml`

Key settings:
- kube-proxy disabled (using Cilium)
- TLS SAN includes: 100.68.247.112, rancher.tailc2013b.ts.net

