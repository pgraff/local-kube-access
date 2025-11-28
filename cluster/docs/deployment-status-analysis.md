# Deployment Status Analysis

**Date:** November 27, 2025

## Summary

### ✅ **Cert-Manager (Not a Problem)**
- **Status**: Intentionally scaled to 0 replicas
- **Impact**: None - this is normal behavior
- **Action**: No action needed

### ❌ **Ditto Services (Real Problem)**
- **Status**: CrashLoopBackOff due to MongoDB failure
- **Impact**: Ditto connectivity and things services are unavailable
- **Root Cause**: MongoDB architecture mismatch
- **Action**: Fix MongoDB deployment

---

## Detailed Analysis

### Cert-Manager Deployments

**Deployments:**
- `cert-manager-cainjector`: 0/0 replicas (scaled to 0)
- `cert-manager-webhook`: 0/0 replicas (scaled to 0)
- `cert-manager`: 1/1 replicas (running normally)

**Status**: ✅ **This is normal and not a problem**

**Explanation:**
- Cert-manager can operate with just the main controller running
- The webhook and cainjector are only needed when actively using cert-manager features (issuing certificates, etc.)
- They're scaled to 0 to save resources when not in use
- The deployment status shows "Available: True", meaning they're healthy, just not running

**When they're needed:**
- When you issue certificates via cert-manager
- When you use cert-manager's webhook validation
- They will automatically scale up when needed

**Action**: None required - this is expected behavior.

---

### Ditto Services

**Deployments:**
- `ditto-connectivity`: 0/1 available (CrashLoopBackOff, 84+ restarts)
- `ditto-things`: 0/1 available (CrashLoopBackOff, 91+ restarts)
- `mongodb-ditto`: 0/1 available (CrashLoopBackOff, 108+ restarts)

**Status**: ❌ **This is a real problem that needs fixing**

#### Root Cause: MongoDB Architecture Mismatch

**Error in MongoDB logs:**
```
/opt/bitnami/scripts/libos.sh: line 346:    61 Illegal instruction     (core dumped)
```

**What this means:**
- The MongoDB container image is built for a different CPU architecture
- The node running MongoDB (likely `k8s-worker-08`) has a different CPU architecture than what the image expects
- Common scenarios:
  - Image is x86_64 but node is ARM64 (or vice versa)
  - Image requires specific CPU instructions not available on the node

**Impact:**
1. MongoDB crashes immediately on startup
2. Ditto services can't connect to MongoDB
3. Ditto services fail health checks and crash
4. Ditto cluster communication times out (because services are unhealthy)

#### Secondary Issues

**Ditto Connectivity Errors:**
- Can't connect to MongoDB: `MongoSocketOpenException: Exception opening socket`
- Cluster communication timeouts: `AskTimeoutException` (25 second timeouts)
- Health check failures: Liveness probe returns HTTP 500

**Ditto Things Errors:**
- Similar MongoDB connection failures
- Cluster communication issues

---

## Recommended Actions

### 1. Fix MongoDB Architecture Issue

**Option A: Use architecture-specific MongoDB image**

Check the node's CPU architecture:
```bash
kubectl get nodes k8s-worker-08 -o jsonpath='{.status.nodeInfo.architecture}'
```

Then update the MongoDB deployment to use the correct image:
- For ARM64: Use `arm64v8/mongo` or `bitnami/mongodb` with ARM64 variant
- For x86_64: Use standard `bitnami/mongodb` image

**Option B: Add node selector to MongoDB**

If you have nodes with the correct architecture, add a nodeSelector to the MongoDB deployment:
```bash
kubectl edit deployment mongodb-ditto -n iot
# Add:
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.io/arch: amd64  # or arm64
```

**Option C: Use multi-arch MongoDB image**

Use a MongoDB image that supports multiple architectures:
```yaml
image: mongo:7.0  # Official MongoDB supports multi-arch
```

### 2. Verify Node Architecture

Check all nodes:
```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,ARCH:.status.nodeInfo.architecture,OS:.status.nodeInfo.operatingSystem
```

### 3. After Fixing MongoDB

Once MongoDB is running:
1. Ditto services should automatically recover
2. They will reconnect to MongoDB
3. Cluster communication should stabilize
4. Health checks should pass

---

## Current Pod Status

**Running (Healthy):**
- `ditto-thingssearch`: 1/1 Running ✅
- `ditto-gateway`: 1/1 Running ✅
- `ditto-nginx`: 1/1 Running ✅
- `ditto-dittoui`: 1/1 Running ✅

**Crashing (Need Fix):**
- `ditto-connectivity`: CrashLoopBackOff ❌
- `ditto-things`: CrashLoopBackOff ❌
- `mongodb-ditto`: CrashLoopBackOff ❌

**Note:** Some Ditto cron jobs are failing because they're scheduled on `k8s-worker-09` which is NotReady/unreachable. This is a separate issue from the MongoDB problem.

---

## Quick Diagnostic Commands

```bash
# Check MongoDB pod logs
kubectl logs -n iot mongodb-ditto-<pod-name> --tail=50

# Check node architecture
kubectl get nodes -o custom-columns=NAME:.metadata.name,ARCH:.status.nodeInfo.architecture

# Check Ditto connectivity logs
kubectl logs -n iot ditto-connectivity-<pod-name> --tail=50

# Check MongoDB deployment
kubectl describe deployment mongodb-ditto -n iot

# Check if MongoDB service exists
kubectl get svc -n iot | grep mongodb
```

---

## Conclusion

**Should you worry?**

- **Cert-manager**: No - this is expected behavior
- **Ditto/MongoDB**: Yes - this needs to be fixed for Ditto to function properly

The MongoDB architecture mismatch is preventing the entire Ditto stack from working correctly. Once MongoDB is fixed, the Ditto services should recover automatically.

