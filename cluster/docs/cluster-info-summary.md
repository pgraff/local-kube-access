# Kubernetes Cluster Information Summary

**Generated:** November 25, 2025 7:30 AM CST  
**Last Updated:** November 25, 2025 7:30 AM CST  
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
1. **Cilium** (Active - ✅ RESOLVED)
   - DaemonSet: `cilium` (14 desired, 14 ready)
   - Operator: Running
   - Status: All 14 pods Running and Ready
   - **Previous Issue:** 2 pods in CrashLoopBackOff - **RESOLVED**

2. **Calico/Canal** (Removed - ✅ RESOLVED)
   - DaemonSet: `rke2-canal` - **DELETED**
   - Namespace: `calico-system` - **DELETED**
   - **Previous Issue:** All 14 pods failing - **RESOLVED** (removed)

### Network Policies
- Default network policies exist in multiple namespaces
- Policies for DNS, ingress, metrics-server, snapshot validation webhook

### Services
- CoreDNS: `rke2-coredns-rke2-coredns` (ClusterIP: 10.43.0.10)
- Metrics Server: `rke2-metrics-server` (ClusterIP: 10.43.191.25)
- Hubble Peer: `hubble-peer` (ClusterIP: 10.43.107.62) - Cilium observability

### Ingress
- **Ingress Controller:** rke2-ingress-nginx-controller (✅ RESOLVED)
  - DaemonSet: 13 desired, 13 ready (all nodes)
  - Status: All pods Running and Ready
  - **Previous Issue:** 9 pods failing - **RESOLVED**
- **Ingress Resource:**
  - Host: `rancher.tailc2013b.ts.net`
  - Addresses: 13 node IPs (all nodes)
  - Ports: 80, 443
  - Status: Active and accessible

## Storage (✅ RESOLVED)

- **Storage Classes:** 
  - `longhorn` (default) - Distributed block storage
  - `local-path` - Local disk storage for Kafka
  - `hostpath` - Simple hostPath storage
  - `longhorn-static` - Static Longhorn volumes
- **Persistent Volumes:** Multiple volumes in use (Longhorn, local-path)
- **Persistent Volume Claims:** Active PVCs for Kafka, Longhorn, and other workloads
- **Volume Snapshots:** Supported (snapshot controller running)
- **Previous Issue:** No storage classes - **RESOLVED** (Longhorn and local-path configured)

## Workloads

### Deployments
- **Rancher:** 3/3 ready (✅ RESOLVED)
  - Pods: All 3 pods Running and Ready (1/1)
  - Restarts: Minimal (1-3 restarts, all hours ago)
  - Status: Stable
  - **Previous Issue:** Only 1/3 ready, multiple restarts - **RESOLVED**
  
- **Cert Manager:** 1/1 ready
- **Fleet Controller:** 1/1 ready
- **CAPI Controller:** 1/1 ready
- **CoreDNS:** 2/2 ready
- **Cilium Operator:** 1/1 ready

### DaemonSets
- **Cilium:** 14/14 ready (✅ RESOLVED - all nodes healthy)
- **rke2-canal:** Removed (✅ RESOLVED - CNI conflict resolved)
- **rke2-ingress-nginx-controller:** 13/13 ready (✅ RESOLVED - all nodes healthy)

## Issues Status

### ✅ All Critical Issues Resolved

1. **CNI Conflict** - ✅ **RESOLVED**
   - **Previous Status:** Both Cilium and Calico/Canal installed, causing conflicts
   - **Resolution:** 
     - Removed Calico/Canal DaemonSet (`rke2-canal`)
     - Cleaned up `calico-system` namespace
     - Fixed Cilium pods (all 14 now Running)
   - **Current Status:** Cilium is the sole CNI, all 14 pods healthy
   - **Resolved Date:** November 24-25, 2025

2. **Ingress Controller Issues** - ✅ **RESOLVED**
   - **Previous Status:** 9 out of 12 pods failing
   - **Resolution:** Resolved after CNI conflict was fixed
   - **Current Status:** All 13 ingress-nginx pods Running and Ready
   - **Resolved Date:** November 24-25, 2025

3. **Rancher Deployment Issues** - ✅ **RESOLVED**
   - **Previous Status:** Only 1/3 pods ready, multiple restarts
   - **Resolution:** Stabilized after network issues resolved
   - **Current Status:** All 3 Rancher pods Running and Ready (1/1)
   - **Resolved Date:** November 24-25, 2025

4. **Storage Configuration** - ✅ **RESOLVED**
   - **Previous Status:** No storage classes configured
   - **Resolution:** 
     - Installed Longhorn (default storage class)
     - Configured local-path provisioner for Kafka
   - **Current Status:** Multiple storage classes available and working
   - **Resolved Date:** November 24-25, 2025

### Current Warnings (Non-Critical)

1. **Helm Operations**
   - Status: No stuck helm-operation pods currently
   - Previous issues were transient and have cleared

2. **Network Policies**
   - Status: Network policies are active and functioning
   - No blocking issues identified

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

## Recommendations (Updated)

### ✅ Completed Actions

1. **CNI Conflict** - ✅ **COMPLETED**
   - Removed Calico/Canal DaemonSet
   - Cleaned up Calico namespace
   - All Cilium pods now healthy

2. **Ingress Controller** - ✅ **COMPLETED**
   - All ingress-nginx pods now running
   - Ingress routing working correctly

3. **Rancher Stability** - ✅ **COMPLETED**
   - All Rancher pods stable and ready
   - Health checks passing

4. **Storage Configuration** - ✅ **COMPLETED**
   - Longhorn installed and configured as default
   - Local-path provisioner configured for Kafka
   - Multiple storage classes available

### Ongoing Recommendations

1. **Monitoring and Observability**
   - ✅ Kubecost installed for cost analysis
   - ✅ Kafka UI installed for Kafka monitoring
   - ✅ Longhorn UI available for storage monitoring
   - Consider: Set up Prometheus/Grafana for comprehensive metrics (Kubecost includes Prometheus)
   - Consider: Enable Cilium Hubble UI for network observability

2. **Backup and Disaster Recovery**
   - Longhorn snapshots configured
   - Consider: Set up automated backup strategy
   - Consider: Document disaster recovery procedures

3. **Security Hardening**
   - Network policies active
   - Consider: Review and tighten RBAC policies
   - Consider: Enable Pod Security Standards
   - Consider: Regular security scanning

4. **Performance Optimization**
   - Monitor node resource usage
   - Consider: Resource quotas for namespaces
   - Consider: Limit ranges for pods
   - Consider: Horizontal Pod Autoscaling where appropriate

## Troubleshooting Commands

### Check CNI Status
```bash
# Check Cilium status (should show all 14 pods Running)
kubectl get pods -n kube-system -l k8s-app=cilium
kubectl logs -n kube-system -l k8s-app=cilium --tail=50

# Verify Calico/Canal is removed (should return "not found")
kubectl get daemonset rke2-canal -n kube-system
kubectl get namespace calico-system
```

### Check Ingress Status
```bash
# Get ingress controller status (should show all pods Ready)
kubectl get daemonset rke2-ingress-nginx-controller -n kube-system
kubectl get pods -n kube-system -l app.kubernetes.io/name=rke2-ingress-nginx

# Get ingress controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=rke2-ingress-nginx --tail=50

# Check ingress resources
kubectl get ingress --all-namespaces
```

### Check Rancher Status
```bash
# Get Rancher pod status (should show all 3 pods Ready)
kubectl get pods -n cattle-system -l app=rancher

# Get Rancher deployment status
kubectl get deployment rancher -n cattle-system

# Get Rancher logs
kubectl logs -n cattle-system -l app=rancher --tail=100

# Check Rancher ingress
kubectl get ingress rancher -n cattle-system
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
- **SSH Access:** scispike@k8s-cp-01
- **kubectl:** Available at ~/kubectl on control plane node

### Service Access (URL-Based via Ingress - Recommended)

**Core Services (via Ingress URLs):**
- **Rancher:** https://rancher.tailc2013b.ts.net
- **Longhorn:** http://longhorn.tailc2013b.ts.net
- **Kubecost:** http://kubecost.tailc2013b.ts.net
- **Kafka UI:** http://kafka-ui.tailc2013b.ts.net

**IoT Stack Services (if deployed, via Ingress URLs):**
- **Hono:** http://hono.tailc2013b.ts.net
- **Ditto:** http://ditto.tailc2013b.ts.net
- **ThingsBoard:** http://thingsboard.tailc2013b.ts.net
- **Node-RED:** http://nodered.tailc2013b.ts.net

**Setup:**
- Deploy ingress resources: `./cluster/scripts/setup-ingress.sh`
- List all URLs: `./cluster/scripts/list-service-urls.sh`
- See [Ingress Setup Guide](ingress-setup-guide.md) for detailed setup and troubleshooting

**Note:** Kafka Bootstrap (port 9092) and Mosquitto (port 1883) are TCP services and require port-forwarding: `./kafka/scripts/access-kafka.sh` and `./iot/scripts/access-mosquitto.sh`. These services are not exposed via Ingress for security reasons.

## Cluster Health Summary

✅ **All Critical Issues Resolved**  
✅ **CNI:** Cilium healthy (14/14 pods)  
✅ **Ingress:** All controllers running (13/13 pods)  
✅ **Rancher:** All pods stable (3/3 ready)  
✅ **Storage:** Longhorn and local-path configured  
✅ **Monitoring:** Kubecost, Kafka UI, and Longhorn UI available  

**Cluster Status:** 🟢 **HEALTHY**

