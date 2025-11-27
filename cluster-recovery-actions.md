# Cluster Recovery Actions After Power Failure

## Current Issues Identified

### 1. Longhorn Volumes in Faulted State ⚠️

**Status:** Some volumes are in "faulted" or "detaching" state after power failure.

**Volumes:**
- `pvc-7a74d07e-4509-4953-99a8-37bf0be795ba` - **Faulted** (100Gi, on k8s-storage-01)
- `pvc-7f8a4ece-afd4-4a7b-bccc-26f0d465b33a` - **Faulted** (10Gi, on k8s-storage-01)
- `pvc-5b1dcdb4-8364-42de-962b-c91d4b12ea06` - **Detached** (20Gi)
- `pvc-70f738b8-4bf0-4afc-b51c-f8eefebd10c7` - **Attached but Degraded** (20Gi, on k8s-worker-06)

**Action Required:**
1. Check Longhorn UI to see volume details
2. Volumes may auto-recover, but faulted volumes may need manual intervention
3. If volumes don't recover, may need to restore from backup or recreate

### 2. Kafka Brokers Not Ready ⚠️

**Status:** All 5 Kafka brokers are Running but not Ready (0/1).

**Likely Cause:** Waiting for persistent volumes to attach or initialization.

**Action:**
- Wait for Longhorn volumes to recover
- Kafka brokers should become ready once volumes attach
- Check logs if they don't recover in 15-20 minutes

### 3. IoT Stack Pods in Init State ⚠️

**Status:** MongoDB pods are in Init:0/1 state.

**Likely Cause:** Waiting for persistent volumes to attach.

**Action:**
- Wait for Longhorn volumes to recover
- Pods should start once volumes are available
- May need to redeploy if volumes don't recover

### 4. Cilium Pod CrashLoopBackOff ⚠️

**Status:** One Cilium pod is in CrashLoopBackOff.

**Likely Cause:** Network initialization after power failure.

**Action:**
- Usually recovers automatically
- If it doesn't recover, may need to restart the pod

## Recovery Actions

### Immediate Actions (Wait First)

**Recommended:** Wait 15-20 minutes for automatic recovery before taking manual action.

### If Volumes Don't Recover (After 20 minutes)

#### Option 1: Check Longhorn UI

```bash
# Access Longhorn UI
./access-longhorn.sh

# Open browser to http://localhost:8080
# Navigate to Volumes section
# Check volume status and errors
```

#### Option 2: Check Volume Details

```bash
# List all volumes
kubectl get volumes.longhorn.io -n longhorn-system

# Check specific volume
kubectl describe volume.longhorn.io -n longhorn-system <volume-name>

# Check Longhorn manager logs
kubectl logs -n longhorn-system -l app=longhorn-manager --tail=100
```

#### Option 3: Force Volume Reattachment (if safe)

```bash
# Only if volume is safe to reattach
# Check volume first:
kubectl get volume.longhorn.io -n longhorn-system <volume-name> -o yaml

# If volume is healthy but detached, Longhorn should auto-reattach
# If not, may need to manually trigger reattachment via Longhorn UI
```

### If Kafka Doesn't Recover

```bash
# Check Kafka broker logs
kubectl logs -n kafka kafka-cluster-brokers-0

# Check if volumes are attached
kubectl get pvc -n kafka

# Check Kafka operator logs
kubectl logs -n kafka -l name=strimzi-cluster-operator --tail=50

# If needed, restart a broker (will restart automatically if volume attaches)
kubectl delete pod -n kafka kafka-cluster-brokers-0
```

### If IoT Stack Doesn't Recover

```bash
# Check pod status
./iot-status-check.sh

# Check MongoDB init container logs
kubectl logs -n iot mongodb-ditto-69888788cb-tx5dg -c init-chmod-data

# Check if PVCs exist
kubectl get pvc -n iot

# If volumes are lost, may need to redeploy
# (This will recreate volumes, but data will be lost)
./uninstall-iot-stack.sh
./deploy-iot-stack.sh
```

### If Cilium Doesn't Recover

```bash
# Check Cilium pod
kubectl get pods -n kube-system | grep cilium

# Check logs
kubectl logs -n kube-system <cilium-pod-name>

# Restart if needed (usually recovers automatically)
kubectl delete pod -n kube-system <cilium-pod-name>
```

## Monitoring Recovery

### Continuous Monitoring

```bash
# Monitor every 30 seconds
./monitor-cluster-recovery.sh --continuous
```

### Check Specific Services

```bash
# Check all pods
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

# Check volumes
kubectl get volumes.longhorn.io -n longhorn-system

# Check PVCs
kubectl get pvc --all-namespaces
```

## Expected Recovery Timeline

- **0-5 minutes:** Nodes come online ✅ (Done)
- **5-10 minutes:** System pods recover (In progress)
- **10-15 minutes:** Longhorn volumes reattach (In progress)
- **15-20 minutes:** Kafka brokers become ready (Waiting)
- **20-25 minutes:** IoT stack pods start (Waiting)

## Data Loss Considerations

⚠️ **Important:** After a power failure, there's a risk of data loss if:
- Volumes are in "faulted" state and can't be recovered
- Data wasn't properly flushed to disk before power loss

**Recommendations:**
1. Check Longhorn UI for volume health
2. Verify backups are available (if configured)
3. If volumes are faulted, check if data can be recovered
4. Consider restoring from backup if critical data is lost

## When to Take Action

**Wait and Monitor:**
- First 20 minutes after power restoration
- Most services should recover automatically

**Take Action If:**
- Volumes remain faulted after 20 minutes
- Kafka brokers don't become ready after 30 minutes
- IoT stack pods don't start after volumes are attached
- Critical services remain unavailable after 30 minutes

## Success Criteria

✅ **Cluster Fully Recovered When:**
- All nodes Ready
- All system pods Running
- All Longhorn volumes Attached (or healthy)
- All Kafka brokers Ready
- All IoT stack pods Running
- All services accessible via port-forward

---

**Last Updated:** $(date)  
**Status:** Monitoring recovery in progress

