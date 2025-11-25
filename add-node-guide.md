# Adding a New Node to RKE2 Cluster

This guide walks through adding a new node to your RKE2 Kubernetes cluster.

## Prerequisites

- New node with:
  - Ubuntu/Debian Linux (or compatible)
  - SSH access from your control plane
  - Network connectivity (Tailscale recommended)
  - Sufficient disk space for workloads
- Access to control plane node (`k8s-cp-01`)
- Root or sudo access on the new node

## Overview

The process involves:
1. Preparing the new node
2. Installing RKE2 agent
3. Getting the join token from control plane
4. Configuring and starting RKE2
5. Verifying the node joins successfully
6. Configuring node labels and storage
7. Verifying workloads can schedule

## Step 1: Prepare the New Node

### 1.1 Basic Setup

SSH into the new node and perform basic setup:

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install basic tools
sudo apt-get install -y curl wget git

# Ensure Tailscale is installed and connected (if using)
# Follow your Tailscale setup process
```

### 1.2 Network Configuration

Ensure the node can reach:
- Control plane nodes (on Tailscale network)
- Other worker nodes
- Internet (for pulling images)

Test connectivity:
```bash
# From new node, test connection to control plane
ping 100.68.247.112  # Replace with your control plane IP
```

### 1.3 Firewall Configuration

RKE2 requires specific ports. Configure firewall if needed:

```bash
# If using UFW
sudo ufw allow 9345/tcp  # RKE2 server port
sudo ufw allow 10250/tcp # Kubelet API
sudo ufw allow 8472/udp  # Flannel/Cilium VXLAN
sudo ufw allow 51820/udp # Flannel/Cilium VXLAN
sudo ufw allow 51821/udp # Flannel/Cilium VXLAN
sudo ufw allow 4789/udp  # Flannel/Cilium VXLAN
```

Or disable firewall if all traffic is on Tailscale:
```bash
sudo ufw disable  # Only if using Tailscale for all traffic
```

## Step 2: Get Join Token from Control Plane

### 2.1 Retrieve the Token

SSH into your control plane node and get the node token:

```bash
# SSH to control plane
ssh scispike@k8s-cp-01

# Get the node token
sudo cat /var/lib/rancher/rke2/server/node-token
```

**Save this token** - you'll need it in the next step.

### 2.2 Get Control Plane Information

Also get the control plane server URL:

```bash
# Get the server URL (usually the control plane IP:9345)
echo "https://100.68.247.112:9345"  # Replace with your control plane IP
```

Or check the current config:
```bash
cat /etc/rancher/rke2/config.yaml | grep server
```

## Step 3: Install RKE2 Agent on New Node

### 3.1 Install RKE2

On the new node, install RKE2 agent:

```bash
# Install RKE2
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sudo sh -

# Enable RKE2 service
sudo systemctl enable rke2-agent.service
```

### 3.2 Configure RKE2 Agent

Create the configuration directory and file:

```bash
sudo mkdir -p /etc/rancher/rke2

# Create config file
sudo tee /etc/rancher/rke2/config.yaml > /dev/null <<EOF
server: https://100.68.247.112:9345
token: <YOUR_NODE_TOKEN_FROM_STEP_2>
EOF
```

**Replace:**
- `100.68.247.112` with your control plane IP
- `<YOUR_NODE_TOKEN_FROM_STEP_2>` with the token from Step 2.1

### 3.3 Start RKE2 Agent

```bash
# Start the service
sudo systemctl start rke2-agent.service

# Check status
sudo systemctl status rke2-agent.service

# View logs if needed
sudo journalctl -u rke2-agent.service -f
```

## Step 4: Verify Node Joined

### 4.1 Check from Control Plane

From your control plane node, verify the new node appears:

```bash
# SSH to control plane
ssh scispike@k8s-cp-01

# Check nodes
~/kubectl get nodes

# Get detailed node info
~/kubectl get nodes -o wide

# Check node status
~/kubectl describe node <new-node-name>
```

The new node should appear with status `Ready` after a minute or two.

### 4.2 Check Node Logs (if issues)

If the node doesn't appear, check logs on the new node:

```bash
# On the new node
sudo journalctl -u rke2-agent.service --no-pager | tail -50
```

Common issues:
- **Token incorrect**: Verify token matches exactly
- **Network connectivity**: Ensure node can reach control plane
- **Firewall blocking**: Check firewall rules
- **Time sync**: Ensure NTP is working (`sudo timedatectl status`)

## Step 5: Configure Node Labels

### 5.1 Label for Longhorn Storage (if applicable)

If you want this node to participate in Longhorn storage:

```bash
# From control plane
ssh scispike@k8s-cp-01

# Label node for Longhorn
~/kubectl label node <new-node-name> node.longhorn.io/create-default-disk=true

# Verify label
~/kubectl get node <new-node-name> --show-labels | grep longhorn
```

### 5.2 Add Custom Labels (optional)

Add any other labels you use:

```bash
# Example: Label as worker
~/kubectl label node <new-node-name> node-role.kubernetes.io/worker=true

# Example: Label for specific workloads
~/kubectl label node <new-node-name> workload-type=general
```

## Step 6: Verify Storage

### 6.1 Check Longhorn (if using)

If you labeled the node for Longhorn:

```bash
# Check Longhorn recognizes the node
# Access Longhorn UI and verify node appears
# Or check via kubectl
~/kubectl get nodes -l node.longhorn.io/create-default-disk=true
```

### 6.2 Verify Local-Path Storage

Local-path provisioner should automatically work on new nodes:

```bash
# Check local-path provisioner
~/kubectl get pods -n local-path-storage

# Verify it can provision on new node
# (It will automatically use new nodes)
```

## Step 7: Test Workload Scheduling

### 7.1 Create Test Pod

Test that pods can schedule on the new node:

```bash
# Create a test pod
cat <<EOF | ~/kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-$(date +%s)
  namespace: default
spec:
  containers:
  - name: test
    image: busybox
    command: ['sleep', '3600']
  nodeSelector:
    kubernetes.io/hostname: <new-node-name>
EOF

# Check pod schedules
~/kubectl get pods -o wide
```

### 7.2 Verify Existing Workloads

Check if existing workloads can use the new node:

```bash
# Check pod distribution
~/kubectl get pods --all-namespaces -o wide | grep <new-node-name>

# For Kafka specifically, new brokers won't automatically move
# But new pods can schedule on the new node
```

## Step 8: Update Kafka/Strimzi (if needed)

### 8.1 Kafka Node Pools

If you want to add more Kafka brokers/controllers, you can scale the node pools:

```bash
# Scale broker pool (example: add one more broker)
~/kubectl get kafkanodepool brokers -n kafka -o yaml | sed 's/replicas: 5/replicas: 6/' | ~/kubectl apply -f -

# Don't forget to create PVCs for new pods!
./create-strimzi-pvcs.sh kafka kafka-cluster
```

### 8.2 Verify Kafka Pods

```bash
# Check Kafka pods
~/kubectl get pods -n kafka -o wide

# New pods may schedule on the new node
```

## Step 9: Post-Join Verification

### 9.1 Complete Health Check

Run a comprehensive check:

```bash
# Node status
~/kubectl get nodes

# All pods running
~/kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

# Node resources
~/kubectl top nodes

# Check for any issues
~/kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20
```

### 9.2 Network Verification

Verify pod networking works:

```bash
# Test pod-to-pod communication
# Create a test pod on new node
# Try to ping pods on other nodes
```

## Troubleshooting

### Node Stuck in NotReady

```bash
# Check kubelet status on new node
sudo systemctl status rke2-agent.service

# Check for errors
sudo journalctl -u rke2-agent.service -n 100

# Verify CNI is working
~/kubectl get pods -n kube-system -o wide | grep -E 'cilium|flannel'
```

### Node Can't Reach Control Plane

```bash
# Test connectivity
ping <control-plane-ip>
telnet <control-plane-ip> 9345

# Check DNS resolution
nslookup <control-plane-hostname>

# Verify Tailscale (if using)
tailscale status
```

### Pods Not Scheduling on New Node

```bash
# Check node conditions
~/kubectl describe node <new-node-name>

# Look for:
# - DiskPressure
# - MemoryPressure
# - PIDPressure
# - NetworkUnavailable

# Check taints
~/kubectl describe node <new-node-name> | grep Taints
```

### Storage Issues

```bash
# Longhorn: Check node in UI or
~/kubectl get nodes -l node.longhorn.io/create-default-disk=true

# Local-path: Check provisioner logs
~/kubectl logs -n local-path-storage -l app=local-path-provisioner
```

## Node Removal (for reference)

If you ever need to remove a node:

```bash
# 1. Drain the node
~/kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# 2. Delete the node
~/kubectl delete node <node-name>

# 3. On the node itself, stop RKE2
sudo systemctl stop rke2-agent.service
sudo systemctl disable rke2-agent.service
```

## Quick Reference

### Essential Commands

```bash
# Get join token
sudo cat /var/lib/rancher/rke2/server/node-token

# Check nodes
kubectl get nodes -o wide

# Label for Longhorn
kubectl label node <node> node.longhorn.io/create-default-disk=true

# Check node details
kubectl describe node <node>

# View node logs (on node)
sudo journalctl -u rke2-agent.service -f
```

### Configuration Files

- **RKE2 Config**: `/etc/rancher/rke2/config.yaml`
- **RKE2 Service**: `rke2-agent.service`
- **Logs**: `journalctl -u rke2-agent.service`

## Security Notes

- **Node Token**: Keep the node token secure. Anyone with it can join nodes to your cluster.
- **Network**: Ensure proper network segmentation if not using Tailscale.
- **Firewall**: Configure firewall rules appropriately for your network setup.

## Next Steps After Adding Node

1. ✅ Verify node is Ready
2. ✅ Label for Longhorn (if needed)
3. ✅ Test workload scheduling
4. ✅ Monitor for any issues
5. ✅ Update documentation with new node name
6. ✅ Consider updating monitoring/alerting

## Related Documentation

- [Cluster Quick Reference](cluster-quick-reference.md)
- [Longhorn Setup Guide](longhorn-setup-guide.md)
- [Kafka Setup Guide](kafka-setup-guide.md)
- [Remote Access Guide](remote-access-guide.md)

