# Kubernetes Cluster Management

This repository contains documentation, scripts, and configuration files for managing a Kubernetes cluster running RKE2 with Rancher, Longhorn storage, and Kubecost.

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Cluster Overview](#cluster-overview)
- [Accessing Services](#accessing-services)
- [Documentation](#documentation)
- [Scripts](#scripts)
- [Remote Access](#remote-access)
- [Troubleshooting](#troubleshooting)

## 🚀 Quick Start

### Prerequisites
- kubectl installed
- SSH access to control plane node (k8s-cp-01)
- Tailscale connected (for remote access)

### First Time Setup

1. **Get kubeconfig**:
   ```bash
   ssh scispike@k8s-cp-01 "cat ~/.kube/config" > ~/.kube/config-rke2-cluster.yaml
   ```

2. **Verify connection**:
   ```bash
   export KUBECONFIG=~/.kube/config-rke2-cluster.yaml
   kubectl get nodes
   ```

3. **Access services**:
   ```bash
   ./access-rancher.sh    # Rancher UI
   ./access-longhorn.sh   # Longhorn Storage UI
   ./access-kubecost.sh   # Kubecost Cost Analysis
   ```

## 🖥️ Cluster Overview

### Cluster Information
- **Distribution**: RKE2 (Rancher Kubernetes Engine 2)
- **Kubernetes Version**: v1.33.6+rke2r1
- **CNI**: Cilium
- **Storage**: Longhorn (distributed block storage)
- **Management**: Rancher v2.13.0-rc3
- **Cost Analysis**: Kubecost
- **Message Broker**: Kafka 4.1.1 (KRaft mode, 3 controllers, 5 brokers)

### Node Configuration
- **Control Plane**: 3 nodes (k8s-cp-01, k8s-cp-02, k8s-cp-03)
- **Workers**: 10 nodes (k8s-worker-01 through k8s-worker-10)
- **Storage**: 1 dedicated node (k8s-storage-01)
- **Total**: 14 nodes

### Network
- **API Server**: https://100.68.247.112:6443
- **Network**: Tailscale VPN (100.x.x.x addresses)
- **CNI**: Cilium (replaced Calico/Canal)

## 🔗 Accessing Services

### Rancher (Cluster Management UI)
```bash
./access-rancher.sh
# Then open: http://localhost:8443
# Bootstrap password: See [Cluster Info Summary](cluster-info-summary.md)
```

### Longhorn (Storage Management UI)
```bash
./access-longhorn.sh
# Then open: http://localhost:8080
```

### Kubecost (Cost Analysis UI)
```bash
./access-kubecost.sh
# Then open: http://localhost:9090
# Note: Allow 15-25 minutes for initial metrics collection
```

### Kafka (Message Broker)
```bash
./access-kafka.sh
# Then connect to: localhost:9092
# See [Kafka Setup Guide](kafka-setup-guide.md) for usage examples
```

### Lens (Kubernetes IDE)
1. Import kubeconfig: `~/.kube/config-rke2-cluster.yaml`
2. See [Lens Setup Guide](setup-lens.md) for details

## 📚 Documentation

### Core Documentation
- **[Cluster Info Summary](cluster-info-summary.md)** - Comprehensive cluster information, configuration, and issues
- **[Quick Reference](cluster-quick-reference.md)** - Quick commands and common tasks
- **[Remote Access Guide](remote-access-guide.md)** - How to access the cluster from anywhere

### Service-Specific Guides
- **[Longhorn Setup Guide](longhorn-setup-guide.md)** - Distributed storage setup and configuration
- **[Lens Setup Guide](setup-lens.md)** - Setting up Lens IDE for cluster management
- **[Kubecost Cluster ID Fix](kubecost-clusterid-fix.md)** - Troubleshooting Kubecost installation
- **[Kubecost Grafana Fix](kubecost-grafana-fix.md)** - Fix for Grafana 502 Bad Gateway error
- **[Kubecost Grafana No Data](kubecost-grafana-no-data-fix.md)** - Troubleshooting when Grafana shows no data
- **[Kafka Setup Guide](kafka-setup-guide.md)** - Kafka cluster with 3 controllers and 5 brokers
- **[Strimzi Local-Path Workaround](strimzi-local-path-workaround.md)** - Fix for Strimzi with local-path storage
- **[Add Node Guide](add-node-guide.md)** - How to add new nodes to the RKE2 cluster

### Storage Configuration
- **[Local Path Storage Class](local-path-storageclass.yaml)** - Local storage provisioner (backup)
- **[HostPath Storage Class](hostpath-storageclass.yaml)** - Simple hostPath storage class

## 🛠️ Scripts

### Access Scripts
All scripts use your local kubeconfig and work from anywhere (Mac, Linux, etc.):

- **`access-rancher.sh`** - Port-forward to Rancher UI (ports 8443/8444)
- **`access-longhorn.sh`** - Port-forward to Longhorn UI (port 8080)
- **`access-kubecost.sh`** - Port-forward to Kubecost UI (port 9090)
- **`access-kafka.sh`** - Port-forward to Kafka bootstrap service (port 9092)

### Setup Scripts
- **`setup-remote-laptop.sh`** - Automated setup for new machines (installs kubectl, verifies connection)
- **`gather-cluster-info.sh`** - Comprehensive cluster information gathering (run on control plane)

### Usage
```bash
# Make scripts executable
chmod +x *.sh

# Run any access script
./access-rancher.sh
```

## 🌐 Remote Access

### From Your Laptop (Ubuntu/Linux)

Since all nodes are on Tailscale, you can access the cluster from anywhere:

1. **Install prerequisites**:
   ```bash
   ./setup-remote-laptop.sh
   ```

2. **Or manually**:
   ```bash
   # Install kubectl
   sudo apt-get install -y kubectl
   
   # Get kubeconfig
   ssh scispike@k8s-cp-01 "cat ~/.kube/config" > ~/.kube/config-rke2-cluster.yaml
   
   # Test connection
   export KUBECONFIG=~/.kube/config-rke2-cluster.yaml
   kubectl get nodes
   ```

3. **Use the scripts** - They work identically on any machine!

See [Remote Access Guide](remote-access-guide.md) for complete details.

## 🔧 Troubleshooting

### Common Issues

**Can't connect to cluster:**
- Verify Tailscale is connected: `tailscale status`
- Test API server: `curl -k https://100.68.247.112:6443/version`
- Check kubeconfig: `kubectl config view`

**Port-forward not working:**
- Check if port is in use: `lsof -i :8080`
- Kill existing port-forwards: `pkill -f "kubectl port-forward"`

**Storage issues:**
- Check Longhorn status: `kubectl get pods -n longhorn-system`
- Verify storage class: `kubectl get storageclass`
- See [Longhorn Setup Guide](longhorn-setup-guide.md)

**CNI/Network issues:**
- Check Cilium: `kubectl get pods -n kube-system -l k8s-app=cilium`
- See [Cluster Info Summary](cluster-info-summary.md) for resolved issues

### Getting Help

1. Check the relevant documentation file
2. Review [Cluster Info Summary](cluster-info-summary.md) for known issues
3. Check cluster status: `kubectl get nodes,pods --all-namespaces`

## 📁 File Structure

```
k8s-home/
├── README.md                      # This file
├── cluster-info-summary.md        # Comprehensive cluster documentation
├── cluster-quick-reference.md     # Quick commands reference
├── remote-access-guide.md         # Remote access instructions
├── longhorn-setup-guide.md        # Longhorn storage guide
├── setup-lens.md                  # Lens IDE setup
├── kubecost-clusterid-fix.md      # Kubecost troubleshooting
├── access-rancher.sh              # Rancher access script
├── access-longhorn.sh             # Longhorn access script
├── access-kubecost.sh             # Kubecost access script
├── access-kafka.sh                # Kafka access script
├── setup-remote-laptop.sh         # Remote setup automation
├── gather-cluster-info.sh         # Cluster info gathering script
├── kafka-kraft-cluster.yaml       # Kafka cluster configuration
├── create-strimzi-pvcs.sh         # Script to create PVCs for Strimzi
├── strimzi-local-path-workaround.md # Workaround documentation
├── add-node-guide.md              # Guide for adding new nodes
├── local-path-storageclass.yaml   # Local storage provisioner
└── hostpath-storageclass.yaml     # HostPath storage class
```

## 🔐 Security Notes

### Kubeconfig Security
- The kubeconfig file contains sensitive certificates
- Set proper permissions: `chmod 600 ~/.kube/config-rke2-cluster.yaml`
- Don't commit to public repositories
- Consider using `.gitignore` to exclude sensitive files

### Network Security
- All traffic goes through Tailscale (encrypted VPN)
- API server is only accessible via Tailscale network
- No ports exposed on public internet

## 🎯 Key Features

✅ **Distributed Storage** - Longhorn provides replicated block storage across all nodes  
✅ **Cost Visibility** - Kubecost tracks and reports cluster costs  
✅ **Easy Management** - Rancher provides web UI for cluster management  
✅ **Remote Access** - Access from anywhere via Tailscale  
✅ **High Availability** - 3-node control plane with etcd  
✅ **Modern CNI** - Cilium for advanced networking features  

## 📞 Cluster Access Information

- **SSH to Control Plane**: `ssh scispike@k8s-cp-01`
- **API Server**: https://100.68.247.112:6443
- **Kubeconfig**: `~/.kube/config-rke2-cluster.yaml`
- **Default Storage Class**: `longhorn`

## 🔄 Recent Changes

- ✅ Resolved CNI conflict (removed Calico/Canal, using Cilium)
- ✅ Fixed ingress controller issues
- ✅ Stabilized Rancher deployment
- ✅ Installed Longhorn distributed storage
- ✅ Installed Kubecost for cost analysis
- ✅ Set up remote access capabilities

## 📖 Additional Resources

- [RKE2 Documentation](https://docs.rke2.io/)
- [Rancher Documentation](https://rancher.com/docs/)
- [Longhorn Documentation](https://longhorn.io/docs/)
- [Kubecost Documentation](https://docs.kubecost.com/)
- [Cilium Documentation](https://docs.cilium.io/)

---

**Last Updated**: November 25, 2025  
**Cluster Age**: ~33 hours  
**Status**: Operational ✅

