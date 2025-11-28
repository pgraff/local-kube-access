# IoT Stack Issues and Fixes

## Summary

**Status:** ⚠️ 3 Issues Found  
**Working Components:** 13 pods running  
**Issues:** 7 pods with problems

## Issue 1: Twin Service - ImagePullBackOff ✅ FIXED (Deployment Created)

**Status:** Deployment now exists, but image not available (expected)

**Current State:**
- ✅ Deployment created
- ✅ Service exists
- ❌ Pods in `ErrImagePull` (image doesn't exist yet)

**Fix:**
```bash
# Build the Docker image
cd iot/twin-service
./build.sh

# Update deployment.yaml with your image registry
# Then the pods will start
```

**Impact:** Twin service unavailable until image is built (expected)

---

## Issue 2: MongoDB for Hono - CrashLoopBackOff

**Status:** ❌ Critical - Hono device registry affected

**Error:**
```
DBPathInUse: Unable to create/open the lock file: /bitnami/mongodb/data/db/mongod.lock (Input/output error)
```

**Diagnosis:**
- PVC is bound and healthy
- Issue appears to be with the pod/container accessing the storage
- May be a corrupted lock file or storage mount issue

**Fix Options:**

### Option A: Delete and Recreate (Recommended)
```bash
# Uninstall MongoDB
helm uninstall mongodb-hono -n iot

# Wait a moment
sleep 10

# Reinstall
helm install mongodb-hono bitnami/mongodb -n iot \
  -f iot/k8s/mongodb-hono-values.yaml

# Verify
kubectl get pods -n iot -l app.kubernetes.io/name=mongodb
```

### Option B: Delete Lock File (If PVC is accessible)
```bash
# Get the pod name
POD=$(kubectl get pod -n iot -l app.kubernetes.io/name=mongodb -o jsonpath='{.items[0].metadata.name}')

# Delete the lock file (if pod is running)
kubectl exec -n iot $POD -- rm -f /bitnami/mongodb/data/db/mongod.lock

# Restart the pod
kubectl delete pod -n iot -l app.kubernetes.io/name=mongodb
```

**Impact:** Hono device registry may not be fully functional until fixed.

---

## Issue 3: TimescaleDB - Init Container Stuck

**Status:** ❌ Critical - Telemetry storage unavailable

**Error:**
```
unable to attach volume to k8s-worker-11: node.longhorn.io "k8s-worker-11" not found
```

**Diagnosis:**
- `k8s-worker-11` exists and is Ready (added 4h6m ago)
- Longhorn cannot find the node in its registry
- PVCs are bound but volumes cannot attach

**Fix Options:**

### Option A: Register Node with Longhorn (Recommended)
```bash
# Check Longhorn UI or use kubectl
# Longhorn should auto-discover nodes, but k8s-worker-11 is new

# Option 1: Wait for auto-discovery (may take time)
# Option 2: Manually label the node
kubectl label node k8s-worker-11 longhorn.io/node=true

# Option 3: Check Longhorn manager logs
kubectl logs -n longhorn-system -l app=longhorn-manager --tail=50
```

### Option B: Move TimescaleDB to Different Node
```bash
# Delete TimescaleDB
helm uninstall timescaledb -n iot

# Update values to use nodeSelector (target a different node)
# Then reinstall
helm install timescaledb timescale/timescaledb-single -n iot \
  -f iot/k8s/timescaledb-values.yaml
```

### Option C: Delete and Recreate PVCs (Last Resort)
```bash
# WARNING: This will delete data!
# Delete TimescaleDB
helm uninstall timescaledb -n iot

# Delete PVCs
kubectl delete pvc -n iot storage-volume-timescaledb-0 wal-volume-timescaledb-0

# Reinstall
helm install timescaledb timescale/timescaledb-single -n iot \
  -f iot/k8s/timescaledb-values.yaml
```

**Impact:** Telemetry storage unavailable until fixed.

---

## Quick Fix Script

```bash
#!/bin/bash
# Quick fixes for IoT stack issues

export KUBECONFIG=~/.kube/config-rke2-cluster.yaml

echo "=== Fixing MongoDB for Hono ==="
helm uninstall mongodb-hono -n iot
sleep 10
helm install mongodb-hono bitnami/mongodb -n iot \
  -f iot/k8s/mongodb-hono-values.yaml

echo "=== Labeling k8s-worker-11 for Longhorn ==="
kubectl label node k8s-worker-11 longhorn.io/node=true --overwrite

echo "=== Checking TimescaleDB ==="
kubectl get pod -n iot timescaledb-0

echo "=== Done ==="
```

---

## Verification

After fixes, verify:

```bash
# Check all pods
kubectl get pods -n iot

# Check MongoDB
kubectl get pods -n iot -l app.kubernetes.io/name=mongodb
kubectl logs -n iot -l app.kubernetes.io/name=mongodb --tail=20

# Check TimescaleDB
kubectl get pod -n iot timescaledb-0
kubectl describe pod -n iot timescaledb-0

# Check Twin Service (after image is built)
kubectl get pods -n iot -l app=twin-service
```

---

## Expected Final State

After all fixes:
- ✅ All Hono components running
- ✅ MongoDB for Hono running
- ✅ TimescaleDB running
- ✅ Twin Service running (after image build)
- ✅ All 20+ pods in Running state

