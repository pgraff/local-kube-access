# Strimzi with Local-Path Storage Workaround

## Problem

When deploying Strimzi Kafka clusters using the `local-path` storage class with `WaitForFirstConsumer` binding mode, Strimzi's StrimziPodSet controller doesn't automatically create the PersistentVolumeClaims (PVCs) before scheduling pods. This creates a chicken-and-egg problem:

- Pods can't be scheduled without bound PVCs
- PVCs with `WaitForFirstConsumer` won't bind until a pod is scheduled
- Strimzi doesn't create the PVCs automatically

## Root Cause

Strimzi's StrimziPodSet controller creates pods directly without using StatefulSets. Unlike StatefulSets, which automatically create PVCs from `volumeClaimTemplates`, StrimziPodSet expects PVCs to exist before pods can be scheduled.

With `WaitForFirstConsumer` binding mode:
- The PVC must exist and be in `Pending` state
- A pod must be scheduled to trigger binding
- But the pod can't be scheduled if the PVC doesn't exist

## Solution: Manual PVC Creation

We need to manually create the PVCs that Strimzi expects before the pods are created.

## Step-by-Step Workaround

### 1. Identify Required PVCs

First, determine what PVCs Strimzi needs. Check your KafkaNodePool resources:

```bash
kubectl get kafkanodepool -n <namespace>
kubectl describe kafkanodepool <pool-name> -n <namespace>
```

Look for the storage configuration:
- Number of replicas
- Storage size per pod
- Storage class name

### 2. Check StrimziPodSet for PVC Names

The PVC naming follows this pattern:
- Brokers: `data-0-<cluster-name>-<pool-name>-<pod-index>`
- Controllers: `data-0-<cluster-name>-<pool-name>-<pod-index>`

Example:
- Cluster: `kafka-cluster`
- Broker pool: `brokers`
- Pod index: `0`
- PVC name: `data-0-kafka-cluster-brokers-0`

### 3. Create PVCs Manually

Create a script or YAML file to generate all required PVCs:

**For Brokers:**
```bash
# Replace these variables
NAMESPACE="kafka"
CLUSTER_NAME="kafka-cluster"
POOL_NAME="brokers"
REPLICAS=5
STORAGE_SIZE="100Gi"
STORAGE_CLASS="local-path"

# Create PVCs for each broker
for i in $(seq 0 $((REPLICAS-1))); do
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-0-${CLUSTER_NAME}-${POOL_NAME}-${i}
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${STORAGE_SIZE}
  storageClassName: ${STORAGE_CLASS}
EOF
done
```

**For Controllers:**
```bash
# Replace these variables
NAMESPACE="kafka"
CLUSTER_NAME="kafka-cluster"
POOL_NAME="controllers"
REPLICAS=3
STORAGE_SIZE="20Gi"
STORAGE_CLASS="local-path"

# Create PVCs for each controller
for i in $(seq 0 $((REPLICAS-1))); do
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-0-${CLUSTER_NAME}-${POOL_NAME}-${i}
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${STORAGE_SIZE}
  storageClassName: ${STORAGE_CLASS}
EOF
done
```

### 4. Verify PVCs Are Created

```bash
kubectl get pvc -n <namespace>
```

You should see all PVCs in `Pending` state (this is normal with `WaitForFirstConsumer`).

### 5. Let Strimzi Create Pods

Once PVCs exist, Strimzi will create the pods. The PVCs will bind when pods are scheduled:

```bash
kubectl get pods -n <namespace> -w
```

### 6. Verify Everything Works

```bash
# Check PVCs are bound
kubectl get pvc -n <namespace>

# Check pods are running
kubectl get pods -n <namespace>

# Check volumes are created
kubectl get pv | grep <namespace>
```

## Automated Script

Here's a complete script that automates this process:

```bash
#!/bin/bash
# create-strimzi-pvcs.sh
# Creates PVCs for Strimzi Kafka clusters using local-path storage

set -e

NAMESPACE="${1:-kafka}"
CLUSTER_NAME="${2:-kafka-cluster}"

echo "Creating PVCs for Strimzi cluster: ${CLUSTER_NAME} in namespace: ${NAMESPACE}"

# Get KafkaNodePools
POOLS=$(kubectl get kafkanodepool -n ${NAMESPACE} -o jsonpath='{.items[*].metadata.name}')

for POOL in ${POOLS}; do
  echo "Processing pool: ${POOL}"
  
  # Get pool configuration
  REPLICAS=$(kubectl get kafkanodepool ${POOL} -n ${NAMESPACE} -o jsonpath='{.spec.replicas}')
  STORAGE_SIZE=$(kubectl get kafkanodepool ${POOL} -n ${NAMESPACE} -o jsonpath='{.spec.storage.volumes[0].size}')
  STORAGE_CLASS=$(kubectl get kafkanodepool ${POOL} -n ${NAMESPACE} -o jsonpath='{.spec.storage.volumes[0].class}')
  
  echo "  Replicas: ${REPLICAS}, Size: ${STORAGE_SIZE}, StorageClass: ${STORAGE_CLASS}"
  
  # Create PVCs for each replica
  for i in $(seq 0 $((REPLICAS-1))); do
    PVC_NAME="data-0-${CLUSTER_NAME}-${POOL}-${i}"
    
    # Check if PVC already exists
    if kubectl get pvc ${PVC_NAME} -n ${NAMESPACE} &>/dev/null; then
      echo "  PVC ${PVC_NAME} already exists, skipping"
      continue
    fi
    
    echo "  Creating PVC: ${PVC_NAME}"
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${PVC_NAME}
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${STORAGE_SIZE}
  storageClassName: ${STORAGE_CLASS}
EOF
  done
done

echo ""
echo "PVCs created. Waiting for Strimzi to create pods..."
echo "Monitor with: kubectl get pods -n ${NAMESPACE} -w"
```

**Usage:**
```bash
chmod +x create-strimzi-pvcs.sh
./create-strimzi-pvcs.sh <namespace> <cluster-name>
```

## When to Apply This Workaround

Apply this workaround when:
1. Using Strimzi with `local-path` storage class
2. Using any storage class with `WaitForFirstConsumer` binding mode
3. Strimzi pods are stuck in `Pending` state with "PVC not found" errors
4. You see errors like: `persistentvolumeclaim "data-0-..." not found`

## Alternative: Change Storage Class Binding Mode

If you don't want to manually create PVCs, you can change the storage class to use `Immediate` binding mode instead of `WaitForFirstConsumer`. However, this means:
- Volumes are created immediately (may waste resources)
- Pods can't be scheduled to specific nodes based on storage location
- Less optimal for local storage scenarios

**Not recommended** for local-path storage, as `WaitForFirstConsumer` ensures volumes are created on the node where the pod runs.

## Verification Checklist

After applying the workaround:

- [ ] All required PVCs exist
- [ ] PVCs are in `Pending` state (normal for `WaitForFirstConsumer`)
- [ ] Strimzi pods are being created
- [ ] Pods are scheduled to nodes
- [ ] PVCs transition from `Pending` to `Bound`
- [ ] Pods start successfully
- [ ] Kafka cluster becomes ready

## Troubleshooting

### PVCs Not Binding

If PVCs remain in `Pending` state after pods are scheduled:

```bash
# Check local-path provisioner
kubectl get pods -n local-path-storage

# Check provisioner logs
kubectl logs -n local-path-storage -l app=local-path-provisioner

# Check PVC events
kubectl describe pvc <pvc-name> -n <namespace>
```

### Pods Still Can't Schedule

If pods are still `Pending` after creating PVCs:

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Verify PVC names match exactly
kubectl get pvc -n <namespace>
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.volumes[*].persistentVolumeClaim.claimName}'
```

### Wrong PVC Names

If you get PVC name mismatches:

1. Check the StrimziPodSet to see expected PVC names:
   ```bash
   kubectl get strimzipodset -n <namespace> -o yaml | grep claimName
   ```

2. Update your PVC creation script to match exactly

## Notes

- This workaround is specific to Strimzi's StrimziPodSet implementation
- StatefulSet-based deployments don't have this issue (they auto-create PVCs)
- The workaround is safe - Strimzi will manage the PVCs once they exist
- PVCs created manually will be managed by Strimzi going forward
- If you delete and recreate the Kafka cluster, you'll need to recreate the PVCs

## Related Files

- `k8s/kafka-kraft-cluster.yaml` - Kafka cluster configuration
- `../cluster/k8s/local-path-storageclass.yaml` - Local-path provisioner setup
- `kafka-setup-guide.md` - General Kafka setup guide

