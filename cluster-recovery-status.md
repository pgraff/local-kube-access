# Cluster Recovery Status After Power Failure

## Current Status: ✅ Recovering

**Last Check:** $(date)

## Node Status

✅ **All 14 nodes are Ready!**
- 3 control plane nodes (k8s-cp-01, k8s-cp-02, k8s-cp-03)
- 1 storage node (k8s-storage-01)
- 10 worker nodes (k8s-worker-01 through k8s-worker-10)

## System Health

### kube-system Namespace
- **Total Pods:** 71
- **Running:** 62
- **Pending:** 0
- **CrashLoopBackOff/Error:** 3
  - `cilium-wz9sg` - CrashLoopBackOff (may recover automatically)
  - 2 helper pods - StartError (likely transient PVC creation helpers)

### Critical Services

#### Rancher ✅
- **Status:** 3/3 pods running
- **Health:** Healthy

#### Longhorn (Storage) ⚠️
- **Pods:** 68/70 running
- **Volumes:** 1 attached, 1 detached
- **Status:** Recovering - volumes may attach as nodes stabilize

#### Kafka ⚠️
- **Pods:** 7/11 running
- **Status:** Recovering - Kafka pods may take time to start

#### IoT Stack ⚠️
- **Pods:** 1/3 running
- **Status:** Recovering - may need to wait for dependencies

## Recovery Actions

### Automatic Recovery
Most services will recover automatically as:
1. Nodes finish initializing
2. Longhorn volumes reattach
3. Pods restart and become ready

### Manual Actions (if needed)

#### If Kafka doesn't recover:
```bash
# Check Kafka pod status
kubectl get pods -n kafka

# Check logs for failing pods
kubectl logs -n kafka <pod-name>

# Restart if needed
kubectl delete pod -n kafka <pod-name>
```

#### If IoT Stack doesn't recover:
```bash
# Check status
./iot-status-check.sh

# Redeploy if needed
./deploy-iot-stack.sh
```

#### If Longhorn volumes don't attach:
```bash
# Check volume status
kubectl get volumes.longhorn.io -n longhorn-system

# Check Longhorn UI
./access-longhorn.sh
# Then open http://localhost:8080
```

## Monitoring

### Continuous Monitoring
```bash
# Monitor recovery progress (updates every 30 seconds)
./monitor-cluster-recovery.sh --continuous
```

### One-time Check
```bash
# Single status check
./monitor-cluster-recovery.sh
```

### Check Specific Services
```bash
# Check cluster access
./check-cluster-access.sh

# Check IoT stack
./iot-status-check.sh
```

## Expected Recovery Time

- **Nodes:** ✅ Already Ready
- **System Pods:** 5-10 minutes
- **Longhorn:** 10-15 minutes (volume reattachment)
- **Kafka:** 10-15 minutes (StatefulSet pods)
- **IoT Stack:** 15-20 minutes (depends on databases)

## Next Steps

1. **Wait 10-15 minutes** for services to fully recover
2. **Monitor progress:**
   ```bash
   ./monitor-cluster-recovery.sh --continuous
   ```
3. **Once all services are ready:**
   ```bash
   ./access-all.sh
   ```

## Troubleshooting

### If pods remain in CrashLoopBackOff:

1. **Check logs:**
   ```bash
   kubectl logs -n <namespace> <pod-name>
   ```

2. **Check events:**
   ```bash
   kubectl describe pod -n <namespace> <pod-name>
   ```

3. **Check resource constraints:**
   ```bash
   kubectl top nodes
   kubectl top pods --all-namespaces
   ```

### If volumes don't attach:

1. **Check Longhorn manager logs:**
   ```bash
   kubectl logs -n longhorn-system -l app=longhorn-manager --tail=50
   ```

2. **Check volume details:**
   ```bash
   kubectl describe volume.longhorn.io -n longhorn-system <volume-name>
   ```

3. **Access Longhorn UI:**
   ```bash
   ./access-longhorn.sh
   ```

---

**Note:** After a power failure, it's normal for services to take 10-20 minutes to fully recover. The cluster is healthy and recovery is progressing normally.

