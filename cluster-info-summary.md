# Kubernetes Cluster Information Summary

**Note**: This is a summary file. For the complete, up-to-date cluster information, see:
**[cluster/docs/cluster-info-summary.md](cluster/docs/cluster-info-summary.md)**

## Quick Reference

### Cluster Type
- **Distribution:** RKE2 (Rancher Kubernetes Engine 2)
- **Kubernetes Version:** v1.33.6+rke2r1
- **CNI:** Cilium
- **Storage:** Longhorn (default), local-path, hostpath

### Node Configuration
- **Control Plane:** 3 nodes (k8s-cp-01, k8s-cp-02, k8s-cp-03)
- **Workers:** 10 nodes (k8s-worker-01 through k8s-worker-10)
- **Storage:** 1 dedicated node (k8s-storage-01)
- **Total:** 14 nodes

### Key Services
- **Rancher:** https://rancher.tailc2013b.ts.net
- **Longhorn:** http://longhorn.tailc2013b.ts.net
- **Kubecost:** http://kubecost.tailc2013b.ts.net
- **Kafka UI:** http://kafka-ui.tailc2013b.ts.net

### Cluster Status
✅ **All Critical Issues Resolved**  
✅ **CNI:** Cilium healthy (14/14 pods)  
✅ **Ingress:** All controllers running (13/13 pods)  
✅ **Rancher:** All pods stable (3/3 ready)  
✅ **Storage:** Longhorn and local-path configured  

**Cluster Status:** 🟢 **HEALTHY**

## Access Information

- **Control Plane API:** https://100.68.247.112:6443
- **SSH Access:** scispike@k8s-cp-01
- **kubeconfig:** `~/.kube/config-rke2-cluster.yaml`

## Documentation

For complete cluster information, troubleshooting, and detailed configuration:
- **[Full Cluster Info Summary](cluster/docs/cluster-info-summary.md)** - Comprehensive cluster details
- **[Quick Reference](cluster/docs/cluster-quick-reference.md)** - Quick commands
- **[Remote Access Guide](cluster/docs/remote-access-guide.md)** - Access from anywhere
- **[Ingress Setup Guide](cluster/docs/ingress-setup-guide.md)** - URL-based access

## Recent Updates

- ✅ CNI conflict resolved (Cilium only)
- ✅ Ingress controller issues resolved
- ✅ Rancher deployment stabilized
- ✅ Storage classes configured (Longhorn, local-path)
- ✅ Kafka cluster deployed (3 controllers, 5 brokers)
- ✅ IoT stack deployed (Mosquitto, Hono, Twin Service, ThingsBoard, TimescaleDB, Node-RED)
- ✅ Twin Service migration from Ditto to Kafka-based solution complete

---

**Last Updated:** 2025-11-27  
**For detailed information, see:** [cluster/docs/cluster-info-summary.md](cluster/docs/cluster-info-summary.md)

