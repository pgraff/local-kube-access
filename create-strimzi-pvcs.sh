#!/bin/bash
# create-strimzi-pvcs.sh
# Creates PVCs for Strimzi Kafka clusters using local-path storage
# This is a workaround for StrimziPodSet not auto-creating PVCs with WaitForFirstConsumer storage classes

set -e

NAMESPACE="${1:-kafka}"
CLUSTER_NAME="${2:-kafka-cluster}"

echo "Creating PVCs for Strimzi cluster: ${CLUSTER_NAME} in namespace: ${NAMESPACE}"
echo ""

# Get KafkaNodePools
POOLS=$(kubectl get kafkanodepool -n ${NAMESPACE} -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -z "${POOLS}" ]; then
  echo "Error: No KafkaNodePools found in namespace ${NAMESPACE}"
  echo "Usage: $0 <namespace> <cluster-name>"
  exit 1
fi

for POOL in ${POOLS}; do
  echo "Processing pool: ${POOL}"
  
  # Get pool configuration
  REPLICAS=$(kubectl get kafkanodepool ${POOL} -n ${NAMESPACE} -o jsonpath='{.spec.replicas}')
  STORAGE_SIZE=$(kubectl get kafkanodepool ${POOL} -n ${NAMESPACE} -o jsonpath='{.spec.storage.volumes[0].size}')
  STORAGE_CLASS=$(kubectl get kafkanodepool ${POOL} -n ${NAMESPACE} -o jsonpath='{.spec.storage.volumes[0].class}')
  
  if [ -z "${REPLICAS}" ] || [ -z "${STORAGE_SIZE}" ] || [ -z "${STORAGE_CLASS}" ]; then
    echo "  Warning: Could not get pool configuration, skipping"
    continue
  fi
  
  echo "  Replicas: ${REPLICAS}, Size: ${STORAGE_SIZE}, StorageClass: ${STORAGE_CLASS}"
  
  # Create PVCs for each replica
  CREATED=0
  SKIPPED=0
  for i in $(seq 0 $((REPLICAS-1))); do
    PVC_NAME="data-0-${CLUSTER_NAME}-${POOL}-${i}"
    
    # Check if PVC already exists
    if kubectl get pvc ${PVC_NAME} -n ${NAMESPACE} &>/dev/null; then
      echo "  PVC ${PVC_NAME} already exists, skipping"
      SKIPPED=$((SKIPPED + 1))
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
    CREATED=$((CREATED + 1))
  done
  
  echo "  Pool ${POOL}: Created ${CREATED} PVCs, skipped ${SKIPPED} existing"
  echo ""
done

echo "PVC creation complete!"
echo ""
echo "Next steps:"
echo "1. Monitor PVCs: kubectl get pvc -n ${NAMESPACE} -w"
echo "2. Monitor pods: kubectl get pods -n ${NAMESPACE} -w"
echo "3. PVCs will bind when Strimzi schedules the pods"
echo ""

