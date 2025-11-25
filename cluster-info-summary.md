# Kubernetes Cluster Information Summary

**Generated:** November 24, 2025 11:51 AM CST
**Cluster Control Plane:** k8s-cp-01 (scispike@k8s-cp-01)

## Cluster Overview

### Cluster Type
- **Distribution:** RKE2 (Rancher Kubernetes Engine 2)
- **Kubernetes Version:** v1.33.6+rke2r1
- **Client kubectl Version:** v1.34.2
- **Container Runtime:** containerd://2.1.5-k3s1
- **Age:** ~15 hours

### Control Plane
- **API Server:** https://100.68.247.112:6443
- **CoreDNS:** Running at https://100.68.247.112:6443/api/v1/namespaces/kube-system/services/rke2-coredns-rke2-coredns:udp-53/proxy

## Node Configuration

### Control Plane Nodes (3 nodes)
1. **k8s-cp-01**
   - IP: 100.68.247.112
   - Roles: control-plane, etcd, master
   - OS: Ubuntu 24.04.3 LTS
   - Kernel: 6.14.0-36-generic
   - CPU: 1123m (28%)
   - Memory: 4336Mi (27%)

2. **k8s-cp-02**
   - IP: 100.122.71.98
   - Roles: control-plane, etcd, master
   - OS: Ubuntu 24.04.3 LTS
   - Kernel: 6.14.0-36-generic
   - CPU: 1437m (35%)
   - Memory: 4828Mi (30%)

3. **k8s-cp-03**
   - IP: 100.68.223.86
   - Roles: control-plane, etcd, master
   - OS: Ubuntu 24.04.3 LTS
   - Kernel: 6.14.0-36-generic
   - CPU: 1270m (31%)
   - Memory: 4290Mi (27%)

### Worker Nodes (10 nodes)
- k8s-worker-01 through k8s-worker-10
- All running Ubuntu 24.04.3 LTS
- Mixed kernel versions (6.14.0-36-generic and 6.8.0-88-generic)
- Resource usage varies (CPU: 114m-2588m, Memory: 1544Mi-2614Mi)

### Storage Node (1 node)
- **k8s-storage-01**
   - IP: 100.111.119.104
   - OS: Ubuntu 24.04.3 LTS
   - Kernel: 6.8.0-88-generic
   - CPU: 182m (3%)
   - Memory: 2315Mi (14%)

**Total Nodes:** 14 nodes (3 control plane + 10 workers + 1 storage)

## RKE2 Configuration

From `/etc/rancher/rke2/config.yaml`:
```yaml
write-kubeconfig-mode: "0644"
token: my-very-secret-cluster-token-2025
node-ip: 100.68.247.112
advertise-address: 100.68.247.112
tls-san:
  - 100.68.247.112
  - rancher.tailc2013b.ts.net
disable:
  - rke2-kube-proxy
```

**Note:** kube-proxy is disabled, likely using Cilium for networking.

## Namespaces

### System Namespaces
- `default`
- `kube-system` - Core Kubernetes components
- `kube-public`
- `kube-node-lease`

### Rancher Namespaces
- `cattle-system` - Main Rancher deployment
- `cattle-fleet-system` - Fleet controller
- `cattle-capi-system` - Cluster API controller
- `cattle-turtles-system` - Turtles (CAPI) controller
- `cattle-global-data`
- `cattle-impersonation-system`
- `cattle-local-user-passwords`
- `cattle-ui-plugin-system`
- `cattle-fleet-clusters-system`
- `fleet-default`
- `fleet-local`
- `local`
- `p-nlkxx`
- `p-qhmgg`

### Other Namespaces
- `cert-manager` - Certificate management
- `calico-system` - Calico CNI (legacy, being replaced by Cilium)
- `cluster-fleet-local-local-1a3d67d0a899`

## Networking

### CNI Plugins
1. **Cilium** (Active)
   - DaemonSet: `cilium` (14 desired, 12 ready)
   - Operator: Running
   - Status: 2 pods in CrashLoopBackOff (cilium-2pz7m, cilium-st9nj)

2. **Calico/Canal** (Legacy - Failing)
   - DaemonSet: `rke2-canal` (14 desired, 0 ready)
   - Status: All pods in Init:CrashLoopBackOff
   - **Issue:** All 14 rke2-canal pods failing to start

### Network Policies
- Default network policies exist in multiple namespaces
- Policies for DNS, ingress, metrics-server, snapshot validation webhook

### Services
- CoreDNS: `rke2-coredns-rke2-coredns` (ClusterIP: 10.43.0.10)
- Metrics Server: `rke2-metrics-server` (ClusterIP: 10.43.191.25)
- Hubble Peer: `hubble-peer` (ClusterIP: 10.43.107.62) - Cilium observability

### Ingress
- **Ingress Controller:** rke2-ingress-nginx-controller
  - DaemonSet: 12 desired, 3 ready
  - **Issue:** 9 pods in CrashLoopBackOff or Error state
- **Ingress Resource:**
  - Host: `rancher.tailc2013b.ts.net`
  - Addresses: Multiple node IPs
  - Ports: 80, 443

## Storage

- **Storage Classes:** None configured
- **Persistent Volumes:** None
- **Persistent Volume Claims:** None
- **Volume Snapshots:** Supported (snapshot controller running)

## Workloads

### Deployments
- **Rancher:** 1/3 ready (3 desired, 1 available)
  - Pods: rancher-84495749b-7s66b (Running)
  - Pods: rancher-84495749b-gwxtl (Running, 65 restarts)
  - Pods: rancher-84495749b-w9qrt (Running, 6 restarts)
  
- **Cert Manager:** 1/1 ready
- **Fleet Controller:** 1/1 ready
- **CAPI Controller:** 1/1 ready
- **CoreDNS:** 2/2 ready
- **Cilium Operator:** 1/1 ready

### DaemonSets
- **Cilium:** 12/14 ready (2 failing)
- **rke2-canal:** 0/14 ready (all failing)
- **rke2-ingress-nginx-controller:** 3/12 ready (9 failing)

## Issues Identified

### Critical Issues

1. **CNI Conflict**
   - Both Cilium and Calico/Canal are installed
   - Calico/Canal is completely failing (all 14 pods in CrashLoopBackOff)
   - 2 Cilium pods in CrashLoopBackOff (cilium-2pz7m, cilium-st9nj)
   - **Impact:** Network connectivity issues, pod creation failures
   - **Error:** "unable to connect to Cilium agent: failed to create cilium agent client after 30s timeout"
   - **Cilium Error Details:** Startup probe failing on port 9879 (healthz endpoint)
   - **Canal Error Details:** install-cni init container failing repeatedly (392+ restarts on some pods)
   - **Root Cause:** Likely conflict between two CNI plugins trying to manage the same network interfaces

2. **Ingress Controller Issues**
   - 9 out of 12 ingress-nginx pods failing
   - Multiple CrashLoopBackOff states
   - **Impact:** Ingress routing may be unreliable
   - **Affected Pods:** rke2-ingress-nginx-controller-8pfn8, j8hfn, vlmrj, h7dhk, qgt79, k8srt, pmf7m, rfl42, tbzfp

3. **Rancher Deployment Issues**
   - Only 1/3 Rancher pods fully ready
   - Multiple restarts on 2 pods (65 and 6 restarts respectively)
   - Startup probe failures: "Get http://10.0.7.157:80/healthz: dial tcp 10.0.7.157:80: connect: connection refused"
   - **Impact:** Rancher UI/API may be unstable

### Warnings

1. **Helm Operations**
   - Multiple helm-operation pods in Error or Init states
   - Some operations stuck in Init:0/1

2. **Network Policy Conflicts**
   - Default network policies may be blocking some traffic

## Custom Resources

### Rancher CRDs
- Extensive Rancher management CRDs (clusters, projects, users, etc.)
- Fleet CRDs (bundles, gitrepos, clusters)
- CAPI (Cluster API) CRDs
- RKE machine config CRDs

### Cilium CRDs
- CiliumNetworkPolicy
- CiliumClusterwideNetworkPolicy
- CiliumEndpoint
- CiliumIdentity
- CiliumNode
- And more...

### Cert Manager CRDs
- Certificates
- CertificateRequests
- ClusterIssuers
- Issuers

## Security

### Service Accounts
- Multiple service accounts across namespaces
- Impersonation service accounts for helm operations

### Secrets
- TLS certificates for webhooks
- Helm release secrets
- Bootstrap secrets
- User password secrets

### RBAC
- Extensive RBAC configuration (not fully enumerated in this summary)

## Recommendations

1. **Resolve CNI Conflict (HIGHEST PRIORITY)**
   - **Action:** Remove Calico/Canal DaemonSet completely
     ```bash
     kubectl delete daemonset rke2-canal -n kube-system
     ```
   - **Action:** Clean up Calico resources
     ```bash
     kubectl delete namespace calico-system
     ```
   - **Action:** Fix failing Cilium pods
     - Check logs: `kubectl logs cilium-2pz7m -n kube-system`
     - Verify Cilium agent socket: `/var/run/cilium/cilium.sock`
     - Check node resources and kernel compatibility
   - **Action:** Verify Cilium is working on all nodes
     ```bash
     kubectl get pods -n kube-system -l k8s-app=cilium
     ```

2. **Fix Ingress Controller**
   - **Action:** Check logs for failing pods
     ```bash
     kubectl logs rke2-ingress-nginx-controller-8pfn8 -n kube-system
     ```
   - **Action:** Consider reducing DaemonSet to specific nodes or convert to Deployment
   - **Action:** Verify network policies aren't blocking ingress traffic
   - **Note:** Ingress failures may be related to CNI issues

3. **Stabilize Rancher**
   - **Action:** Check Rancher pod logs
     ```bash
     kubectl logs rancher-84495749b-gwxtl -n cattle-system
     kubectl logs rancher-84495749b-w9qrt -n cattle-system
     ```
   - **Action:** Review startup probe timing and thresholds
   - **Action:** Check if network issues are preventing health checks
   - **Action:** Verify Rancher has sufficient resources

4. **Clean Up Failed Resources**
   - **Action:** Remove stuck helm-operation pods
     ```bash
     kubectl delete pod helm-operation-* -n cattle-system --field-selector=status.phase!=Running
     ```
   - **Action:** Clean up failed jobs
     ```bash
     kubectl delete job rancher-post-delete -n cattle-system
     ```

5. **Storage Configuration**
   - **Action:** Configure storage classes for dynamic provisioning
   - **Action:** Set up appropriate storage backend (local-path, NFS, or cloud storage)
   - **Note:** Storage node (k8s-storage-01) exists but no storage classes configured

6. **Monitoring**
   - **Action:** Set up monitoring/alerting for cluster health
   - **Action:** Monitor node resource usage (k8s-worker-07 and k8s-worker-10 at 62-64% CPU)
   - **Action:** Set up Cilium Hubble for network observability (already installed)

## Troubleshooting Commands

### Check CNI Status
```bash
# Check Cilium status
kubectl get pods -n kube-system -l k8s-app=cilium
kubectl logs -n kube-system -l k8s-app=cilium --tail=50

# Check Canal status (should be removed)
kubectl get pods -n kube-system -l k8s-app=canal
```

### Check Ingress Status
```bash
# Get ingress controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=rke2-ingress-nginx --tail=50

# Check ingress resources
kubectl get ingress --all-namespaces
```

### Check Rancher Status
```bash
# Get Rancher pod status
kubectl get pods -n cattle-system -l app=rancher

# Get Rancher logs
kubectl logs -n cattle-system -l app=rancher --tail=100
```

### Network Diagnostics
```bash
# Check network policies
kubectl get networkpolicies --all-namespaces

# Check Cilium endpoints
kubectl get cep -A

# Check Cilium nodes
kubectl get cn
```

## Access Information

- **Control Plane API:** https://100.68.247.112:6443
- **Rancher UI:** https://rancher.tailc2013b.ts.net
- **SSH Access:** scispike@k8s-cp-01
- **kubectl:** Available at ~/kubectl on control plane node

