# access-all.sh Troubleshooting Guide

## Current Issue: Cluster Not Accessible

If you're seeing "Unable to connect to the server" or "i/o timeout" errors, the Kubernetes cluster is not reachable from your machine.

## Quick Diagnosis

### Check Cluster Connectivity

```bash
export KUBECONFIG="$HOME/.kube/config-rke2-cluster.yaml"
kubectl cluster-info
```

**Expected:** Should show cluster API server URL  
**If fails:** Cluster is not accessible (network issue, VPN, firewall, etc.)

### Check Port-Forward Status

```bash
# Check if port-forwards are running
ps aux | grep "kubectl port-forward" | grep -v grep

# Check if ports are listening
lsof -i :8080 -i :9090 -i :8081 -i :9092 | grep LISTEN

# Check PID file
cat /tmp/k8s-access-all.pids
```

## Common Issues and Solutions

### 1. Cluster Not Accessible

**Symptoms:**
- `kubectl cluster-info` times out
- `kubectl get pods` fails with "i/o timeout"
- Port-forwards fail to start

**Solutions:**

1. **Check VPN/Network Connection:**
   ```bash
   # Test if you can reach the cluster IP
   ping <cluster-ip>
   ```

2. **Check SSH Tunnel (if using):**
   ```bash
   # If cluster requires SSH tunnel, ensure it's running
   ssh -L 6443:localhost:6443 user@cluster-node
   ```

3. **Verify Kubeconfig:**
   ```bash
   # Check if kubeconfig points to correct server
   kubectl config view | grep server
   ```

4. **Wait and Retry:**
   - Sometimes cluster nodes are restarting
   - Wait 5-10 minutes and try again

### 2. Stale Port-Forwards

**Symptoms:**
- PID file exists but processes are dead
- Ports show as in use but nothing is listening
- `access-all.sh` says services are already running

**Solution:**

```bash
# Clean up everything
./kill-access-all.sh

# If that doesn't work, manual cleanup:
pkill -9 -f "kubectl port-forward"
pkill -9 -f "ssh.*-L.*8443"
rm -f /tmp/k8s-access-all.pids
rm -rf /tmp/k8s-access-logs
```

### 3. Port Already in Use

**Symptoms:**
- `access-all.sh` says "Port X is already in use"
- Can't start port-forward for specific service

**Solution:**

```bash
# Find what's using the port
lsof -i :PORT_NUMBER

# Kill the process
kill -9 $(lsof -t -i :PORT_NUMBER)

# Or stop all and restart
./kill-access-all.sh
./access-all.sh
```

### 4. Services Not Found

**Symptoms:**
- `access-all.sh` starts but some services show warnings
- "Service not found" or "Pod is not running" messages

**Solution:**

```bash
# Check if namespace exists
kubectl get namespace iot

# Check if services exist
kubectl get svc -n iot

# Check if pods are running
kubectl get pods -n iot

# If IoT stack not deployed:
./deploy-iot-stack.sh
```

### 5. Rancher Port-Forward Issues

**Symptoms:**
- Rancher port-forward fails
- SSH connection to k8s-cp-01 times out

**Solution:**

```bash
# Test SSH connection
ssh scispike@k8s-cp-01 "echo 'SSH works'"

# If SSH fails, check:
# - SSH key is in ~/.ssh/authorized_keys on remote
# - Network connectivity to k8s-cp-01
# - SSH service is running on remote

# Manually start Rancher port-forward on remote:
ssh scispike@k8s-cp-01 "kubectl port-forward -n cattle-system service/rancher 8443:80 8444:443"
```

## Step-by-Step Recovery

### If Nothing Works:

1. **Clean Everything:**
   ```bash
   ./kill-access-all.sh
   pkill -9 -f "kubectl port-forward"
   pkill -9 -f "ssh.*-L.*8443"
   rm -f /tmp/k8s-access-all.pids
   rm -rf /tmp/k8s-access-logs
   ```

2. **Verify Cluster Access:**
   ```bash
   export KUBECONFIG="$HOME/.kube/config-rke2-cluster.yaml"
   kubectl get nodes
   ```

3. **If Cluster is Accessible, Restart:**
   ```bash
   ./access-all.sh
   ```

4. **If Cluster is NOT Accessible:**
   - Check network/VPN connection
   - Wait for cluster to come back online
   - Check with cluster administrator

## Testing Individual Services

If `access-all.sh` doesn't work, try individual scripts:

```bash
./access-longhorn.sh
./access-kubecost.sh
./access-kafka-ui.sh
./access-kafka.sh
```

If these work but `access-all.sh` doesn't, there's an issue with the consolidated script.

## Log Files

Check log files for detailed error messages:

```bash
# View all logs
ls -la /tmp/k8s-access-logs/

# View specific service log
cat /tmp/k8s-access-logs/longhorn.log
cat /tmp/k8s-access-logs/rancher.log
```

## Getting Help

If you're still stuck:

1. **Check cluster status:**
   ```bash
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

2. **Check network:**
   ```bash
   ping <cluster-ip>
   telnet <cluster-ip> 6443
   ```

3. **Check logs:**
   ```bash
   cat /tmp/k8s-access-logs/*.log
   ```

4. **Run test script:**
   ```bash
   ./test-access-all.sh
   ```

---

**Last Updated**: December 2024

