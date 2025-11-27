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
   # Setup URL-based access (recommended)
   sudo ./cluster/scripts/add-hosts-entries.sh
   # Then access: http://longhorn.tailc2013b.ts.net
   
   # Or use port-forwarding for TCP services
   ./kafka/scripts/access-kafka.sh        # Kafka (TCP)
   ./iot/scripts/access-mosquitto.sh     # Mosquitto (TCP)
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
- **IoT Platform**: Complete stack with Mosquitto, Hono, Ditto, ThingsBoard, TimescaleDB, and Node-RED

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

### URL-Based Access (Recommended)

Access services via friendly URLs using Ingress - no port-forwarding needed!

**📖 First Time Setup:**
See **[LAPTOP-SETUP.md](LAPTOP-SETUP.md)** for complete instructions on setting up your laptop (Ubuntu/Mac) to access cluster services.

**Quick Setup:**
1. **Cluster setup (one-time):** `./cluster/scripts/setup-ingress.sh`
2. **Laptop setup (per machine):** `sudo ./cluster/scripts/add-hosts-entries.sh`

See [LAPTOP-SETUP.md](LAPTOP-SETUP.md) for detailed Ubuntu/Tailscale setup instructions.

**Service URLs:**
- **Rancher:** https://rancher.tailc2013b.ts.net
- **Longhorn:** http://longhorn.tailc2013b.ts.net
- **Kubecost:** http://kubecost.tailc2013b.ts.net
- **Kafka UI:** http://kafka-ui.tailc2013b.ts.net
- **Hono:** http://hono.tailc2013b.ts.net (if IoT stack deployed)
- **Ditto:** http://ditto.tailc2013b.ts.net (if IoT stack deployed)
- **ThingsBoard:** http://thingsboard.tailc2013b.ts.net (if IoT stack deployed)
- **Node-RED:** http://nodered.tailc2013b.ts.net (if IoT stack deployed)

**Note:** The `/etc/hosts` setup is a one-time configuration per machine. After that, URLs work immediately without any running processes. See [Ingress Setup Guide](cluster/docs/ingress-setup-guide.md) for details.

### Port-Forwarding Access (TCP Services & Fallback)

Port-forwarding is still needed for **TCP services** that cannot use HTTP Ingress:
- **Kafka Bootstrap** (port 9092) - TCP protocol
- **Mosquitto MQTT** (port 1883) - MQTT/TCP protocol

**Security Note:** Keeping these services behind port-forwarding (rather than exposing via Ingress) is actually a security benefit - they're not exposed to the network and require explicit port-forwarding for access, providing better access control.

It can also be used as a fallback if Ingress is unavailable:

```bash
# Start all port-forwards (includes TCP services and HTTP fallback)
./access-all.sh

# Stop all port-forwards
./kill-access-all.sh
```

**Note:** For HTTP services, URL-based access (Ingress) is recommended. See [LAPTOP-SETUP.md](LAPTOP-SETUP.md) for setup.

### Individual Service Access

**HTTP Services (via Ingress URLs - Recommended):**
- **Rancher:** https://rancher.tailc2013b.ts.net
- **Longhorn:** http://longhorn.tailc2013b.ts.net
- **Kubecost:** http://kubecost.tailc2013b.ts.net
- **Kafka UI:** http://kafka-ui.tailc2013b.ts.net
- **Hono:** http://hono.tailc2013b.ts.net
- **Ditto:** http://ditto.tailc2013b.ts.net
- **ThingsBoard:** http://thingsboard.tailc2013b.ts.net
- **Node-RED:** http://nodered.tailc2013b.ts.net

See [LAPTOP-SETUP.md](LAPTOP-SETUP.md) for setup instructions.

**TCP Services (Port-Forwarding Required):**

### Kafka (Message Broker - TCP Service)
```bash
./kafka/scripts/access-kafka.sh
# Then connect to: localhost:9092
# See [Kafka Setup Guide](kafka/docs/kafka-setup-guide.md) for usage examples
```
**Note:** Kafka Bootstrap is a TCP service and cannot use HTTP Ingress. This is a security feature.

### Mosquitto MQTT (TCP Service)
```bash
./iot/scripts/access-mosquitto.sh
# MQTT broker: localhost:1883
```
**Note:** Mosquitto is a TCP/MQTT service and cannot use HTTP Ingress. This is a security feature.

### IoT Stack
```bash
# Deploy the complete IoT stack
./iot/scripts/deploy-iot-stack.sh

# Access TCP service (requires port-forwarding)
./iot/scripts/access-mosquitto.sh      # MQTT broker: localhost:1883

# Access HTTP services (via Ingress URLs after setup)
# See LAPTOP-SETUP.md for URL-based access

# Uninstall IoT stack
./iot/scripts/uninstall-iot-stack.sh
```
See [IoT Stack Setup Guide](iot/docs/iot-setup-guide.md) for complete documentation.

### Lens (Kubernetes IDE)
1. Import kubeconfig: `~/.kube/config-rke2-cluster.yaml`
2. See [Lens Setup Guide](cluster/docs/setup-lens.md) for details

## 📚 Documentation

### Getting Started
- **[LAPTOP-SETUP.md](LAPTOP-SETUP.md)** ⭐ **START HERE** - Complete guide for setting up your Ubuntu/Mac laptop to access cluster services

### Core Documentation
- **[Cluster Info Summary](cluster/docs/cluster-info-summary.md)** - Comprehensive cluster information, configuration, and issues
- **[Quick Reference](cluster/docs/cluster-quick-reference.md)** - Quick commands and common tasks
- **[Remote Access Guide](cluster/docs/remote-access-guide.md)** - How to access the cluster from anywhere
- **[Ingress Setup Guide](cluster/docs/ingress-setup-guide.md)** - URL-based access via Ingress (cluster-side configuration)

### Service-Specific Guides
- **[Longhorn Setup Guide](cluster/docs/longhorn-setup-guide.md)** - Distributed storage setup and configuration
- **[Lens Setup Guide](cluster/docs/setup-lens.md)** - Setting up Lens IDE for cluster management
- **[Kubecost Cluster ID Fix](cluster/docs/kubecost-clusterid-fix.md)** - Troubleshooting Kubecost installation
- **[Kubecost Grafana Fix](cluster/docs/kubecost-grafana-fix.md)** - Fix for Grafana 502 Bad Gateway error
- **[Kubecost Grafana No Data](cluster/docs/kubecost-grafana-no-data-fix.md)** - Troubleshooting when Grafana shows no data
- **[Kubecost Grafana Prometheus Metrics](cluster/docs/kubecost-grafana-prometheus-troubleshooting.md)** - Troubleshooting Prometheus metrics not showing in Grafana
- **[Kafka Setup Guide](kafka/docs/kafka-setup-guide.md)** - Kafka cluster with 3 controllers and 5 brokers
- **[Kafka UI Setup Guide](kafka/docs/kafka-ui-setup-guide.md)** - Kafka UI dashboard for monitoring and management
- **[IoT Stack Setup Guide](iot/docs/iot-setup-guide.md)** - Complete IoT platform with Mosquitto, Hono, Ditto, ThingsBoard, TimescaleDB, and Node-RED
- **[Strimzi Local-Path Workaround](kafka/docs/strimzi-local-path-workaround.md)** - Fix for Strimzi with local-path storage
- **[Add Node Guide](cluster/docs/add-node-guide.md)** - How to add new nodes to the RKE2 cluster

### Storage Configuration
- **[Local Path Storage Class](cluster/k8s/local-path-storageclass.yaml)** - Local storage provisioner (backup)
- **[HostPath Storage Class](cluster/k8s/hostpath-storageclass.yaml)** - Simple hostPath storage class

## 🛠️ Scripts

### Access Scripts
All scripts use your local kubeconfig and work from anywhere (Mac, Linux, etc.):

**URL-Based Access (Recommended):**
- **`cluster/scripts/setup-ingress.sh`** - Deploy Ingress resources for URL-based access
- **`cluster/scripts/list-service-urls.sh`** - Display all service URLs (MagicDNS and node IP fallback)

**Port-Forwarding Access (TCP Services & Fallback):**
- **`access-all.sh`** - Start all port-forwards (TCP services + HTTP fallback) - in root
- **`kill-access-all.sh`** - Stop all port-forwards (convenience script) - in root
- **`kafka/scripts/access-kafka.sh`** - Port-forward to Kafka bootstrap service (port 9092) - TCP service
- **`iot/scripts/access-mosquitto.sh`** - Port-forward to Mosquitto MQTT broker (port 1883) - TCP service

**IoT Stack Management:**
- **`iot/scripts/deploy-iot-stack.sh`** - Deploy complete IoT stack (Mosquitto, Hono, Ditto, ThingsBoard, TimescaleDB, Node-RED)
- **`iot/scripts/uninstall-iot-stack.sh`** - Uninstall complete IoT stack

**Note:** HTTP services (Rancher, Longhorn, Kubecost, Kafka UI, Hono, Ditto, ThingsBoard, Node-RED) are now accessible via Ingress URLs. Individual port-forward scripts for these services have been removed. See [LAPTOP-SETUP.md](LAPTOP-SETUP.md) for URL-based access setup.

### Setup Scripts
- **`cluster/scripts/setup-remote-laptop.sh`** - Automated setup for new machines (installs kubectl, verifies connection)
- **`cluster/scripts/gather-cluster-info.sh`** - Comprehensive cluster information gathering (run on control plane)

### Usage
```bash
# Make scripts executable
chmod +x access-all.sh kill-access-all.sh
chmod +x cluster/scripts/*.sh
chmod +x kafka/scripts/*.sh
chmod +x iot/scripts/*.sh

# Start all services at once (recommended)
./access-all.sh

# Access TCP services individually:
./kafka/scripts/access-kafka.sh        # Kafka Bootstrap (TCP)
./iot/scripts/access-mosquitto.sh      # Mosquitto MQTT (TCP)

# HTTP services are accessible via Ingress URLs (see LAPTOP-SETUP.md)

# Stop all port-forwards
./kill-access-all.sh
# Or: ./access-all.sh stop
```

## 🌐 Remote Access

### From Your Laptop (Ubuntu/Linux)

Since all nodes are on Tailscale, you can access the cluster from anywhere:

1. **Install prerequisites**:
   ```bash
   ./cluster/scripts/setup-remote-laptop.sh
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

See [Remote Access Guide](cluster/docs/remote-access-guide.md) for complete details.

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
- See [Longhorn Setup Guide](cluster/docs/longhorn-setup-guide.md)

**CNI/Network issues:**
- Check Cilium: `kubectl get pods -n kube-system -l k8s-app=cilium`
- See [Cluster Info Summary](cluster/docs/cluster-info-summary.md) for resolved issues

### Getting Help

1. Check the relevant documentation file
2. Review [Cluster Info Summary](cluster/docs/cluster-info-summary.md) for known issues
3. Check cluster status: `kubectl get nodes,pods --all-namespaces`

## 📁 File Structure

```
k8s-home/
├── README.md                      # This file
├── access-all.sh                  # Start all port-forwards
├── kill-access-all.sh             # Stop all port-forwards
│
├── cluster/                       # Cluster/K8s setup and information
│   ├── docs/                      # Documentation
│   │   ├── cluster-info-summary.md
│   │   ├── cluster-quick-reference.md
│   │   ├── remote-access-guide.md
│   │   ├── longhorn-setup-guide.md
│   │   ├── setup-lens.md
│   │   ├── kubecost-clusterid-fix.md
│   │   ├── kubecost-grafana-fix.md
│   │   ├── kubecost-grafana-no-data-fix.md
│   │   ├── kubecost-grafana-prometheus-troubleshooting.md
│   │   └── add-node-guide.md
│   ├── k8s/                       # Kubernetes YAML files
│   │   ├── local-path-storageclass.yaml
│   │   └── hostpath-storageclass.yaml
│   ├── scripts/                   # Shell scripts
│   │   ├── setup-ingress.sh
│   │   ├── add-hosts-entries.sh
│   │   ├── list-service-urls.sh
│   │   ├── setup-remote-laptop.sh
│   │   ├── gather-cluster-info.sh
│   │   ├── check-cluster-access.sh
│   │   ├── monitor-cluster-recovery.sh
│   │   ├── quick-recovery-check.sh
│   │   ├── debug-longhorn-volumes.sh
│   │   └── test-access-all.sh
│   └── status/                    # Status and todo files
│
├── kafka/                         # Kafka cluster deployment and setup
│   ├── docs/                      # Documentation
│   │   ├── kafka-setup-guide.md
│   │   ├── kafka-ui-setup-guide.md
│   │   └── strimzi-local-path-workaround.md
│   ├── k8s/                       # Kubernetes YAML files
│   │   ├── kafka-kraft-cluster.yaml
│   │   ├── kafka-ui-deployment.yaml
│   │   └── kafka-ui-values.yaml
│   ├── scripts/                   # Shell scripts
│   │   ├── access-kafka.sh          # TCP service (still needed)
│   │   └── create-strimzi-pvcs.sh
│   └── status/                    # Status and todo files
│
└── iot/                           # IoT cluster setup and deployment
    ├── docs/                      # Documentation
    │   ├── iot-setup-guide.md
    │   ├── iot-protocol-analysis.md
    │   └── iot-testing-guide.md
    ├── k8s/                       # Kubernetes YAML files
    │   ├── iot-namespace.yaml
    │   ├── thingsboard-deployment.yaml
    │   ├── thingsboard-values.yaml
    │   ├── mosquitto-deployment.yaml
    │   ├── mosquitto-values.yaml
    │   ├── nodered-deployment.yaml
    │   ├── hono-values.yaml
    │   ├── ditto-values.yaml
    │   ├── mongodb-ditto-values.yaml
    │   ├── mongodb-hono-values.yaml
    │   ├── postgresql-thingsboard-values.yaml
    │   ├── timescaledb-values.yaml
    │   └── ditto-mongodb-service.yaml
    ├── scripts/                   # Shell scripts
    │   ├── deploy-iot-stack.sh
    │   ├── uninstall-iot-stack.sh
    │   ├── access-mosquitto.sh      # TCP service (still needed)
    │   │                             # HTTP services now use Ingress URLs
    │   ├── iot-status-check.sh
    │   ├── test-iot-stack.sh
    │   ├── test-iot-end-to-end.sh
    │   ├── scan-iot-devices.sh
    │   └── detect-iot-protocols.sh
    └── status/                     # Status and todo files
        └── iot-device-scan-results/
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

