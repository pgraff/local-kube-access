# Kafka Cluster Setup Guide

## Overview

This guide sets up an Apache Kafka cluster using KRaft (Kafka Raft) mode with:
- **3 KRaft Controllers** - For cluster metadata and coordination
- **5 Kafka Brokers** - For message storage and processing
- **Longhorn Storage** - Persistent storage for Kafka data

## Architecture

### KRaft Mode
- **No Zookeeper required** - KRaft is the new consensus protocol
- **Controllers** - Manage cluster metadata and coordinate
- **Brokers** - Store and serve messages
- **Replication** - 3x replication for high availability

### Storage
- Uses Longhorn distributed storage
- 100Gi per broker
- 20Gi per controller
- Data persists across pod restarts

## Installation Steps

### 1. Install Strimzi Operator

```bash
# Add Strimzi Helm repo
helm repo add strimzi https://strimzi.io/charts/
helm repo update

# Install Strimzi operator
helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --namespace kafka \
  --create-namespace \
  --version 0.49.0
```

### 2. Wait for Operator to be Ready

```bash
kubectl wait --for=condition=ready pod -l name=strimzi-cluster-operator -n kafka --timeout=300s
```

### 3. Deploy Kafka Cluster

```bash
# Apply the Kafka cluster and node pools
kubectl apply -f k8s/kafka-kraft-cluster.yaml

# This creates:
# - 1 Kafka cluster resource
# - 1 Controller node pool (3 replicas)
# - 1 Broker node pool (5 replicas)
```

### 3a. Create PVCs (Required for Local-Path Storage)

**Important**: When using `local-path` storage class (or any `WaitForFirstConsumer` storage class), Strimzi doesn't automatically create PVCs. You must create them manually:

```bash
# Use the automated script
./create-strimzi-pvcs.sh kafka kafka-cluster

# Or create manually - see strimzi-local-path-workaround.md for details
```

**Why?** StrimziPodSet doesn't auto-create PVCs like StatefulSets do. With `WaitForFirstConsumer` binding mode, PVCs must exist before pods can be scheduled.

See [Strimzi Local-Path Workaround](strimzi-local-path-workaround.md) for complete details.

### 4. Wait for Cluster to be Ready

```bash
# Check controller status
kubectl get pods -n kafka -l strimzi.io/kind=Kafka

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l strimzi.io/cluster=kafka-cluster -n kafka --timeout=600s
```

## Verification

### Check Pods

```bash
kubectl get pods -n kafka
```

Should show:
- 3 controller pods: `kafka-cluster-controller-0`, `kafka-cluster-controller-1`, `kafka-cluster-controller-2`
- 5 broker pods: `kafka-cluster-kafka-0` through `kafka-cluster-kafka-4`
- Entity operator pods: `kafka-cluster-entity-operator-*`

### Check Services

```bash
kubectl get svc -n kafka
```

Should show:
- `kafka-cluster-kafka-bootstrap` - Bootstrap service for clients
- `kafka-cluster-kafka-brokers` - Individual broker services
- `kafka-cluster-controller` - Controller service

### Check Storage

```bash
kubectl get pvc -n kafka
```

Should show persistent volume claims for all brokers and controllers.

## Accessing Kafka

### From Within the Cluster

```bash
# Get bootstrap service address
kubectl get svc kafka-cluster-kafka-bootstrap -n kafka

# Use: kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
```

### From Outside (Port-Forward)

**Option 1: Use the access script**
```bash
./access-kafka.sh
# Then connect to: localhost:9092
```

**Option 2: Manual port-forward**
```bash
kubectl port-forward -n kafka svc/kafka-cluster-kafka-bootstrap 9092:9092

# Then connect to: localhost:9092
```

### Using Kafka Clients

**Producer Example:**
```bash
kubectl run kafka-producer -it --rm --image=quay.io/strimzi/kafka:latest-kafka-4.1.1 \
  -- bin/kafka-console-producer.sh \
  --bootstrap-server kafka-cluster-kafka-bootstrap:9092 \
  --topic test-topic
```

**Consumer Example:**
```bash
kubectl run kafka-consumer -it --rm --image=quay.io/strimzi/kafka:latest-kafka-4.1.1 \
  -- bin/kafka-console-consumer.sh \
  --bootstrap-server kafka-cluster-kafka-bootstrap:9092 \
  --topic test-topic \
  --from-beginning
```

## Configuration

### Replication Settings

- **Default replication factor**: 3
- **Min in-sync replicas**: 2
- **Transaction state replication**: 3
- **Offsets topic replication**: 3

### Resource Limits

- **Brokers**: 2-4GB RAM, 1-2 CPU
- **Controllers**: 512MB-1GB RAM, 500m-1 CPU
- **Entity Operator**: 512MB-1GB RAM, 200m-500m CPU

### Storage

- **Brokers**: 100Gi each (500Gi total)
- **Controllers**: 20Gi each (60Gi total)
- **Storage Class**: local-path (local disk for better performance)
- **Note**: Using local storage instead of Longhorn for better Kafka performance. Kafka handles replication at the application level, so distributed storage overhead is unnecessary.

## Monitoring

### Check Cluster Health

```bash
# Get Kafka resource status
kubectl get kafka kafka-cluster -n kafka -o yaml

# Check pod logs
kubectl logs -n kafka kafka-cluster-kafka-0
kubectl logs -n kafka kafka-cluster-controller-0
```

### Topics Management

```bash
# List topics
kubectl exec -n kafka kafka-cluster-kafka-0 -- bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list

# Create topic
kubectl exec -n kafka kafka-cluster-kafka-0 -- bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --topic my-topic \
  --partitions 3 \
  --replication-factor 3
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl describe pod -n kafka <pod-name>

# Check events
kubectl get events -n kafka --sort-by='.lastTimestamp'
```

### Storage Issues

```bash
# Check PVCs
kubectl get pvc -n kafka

# Check local-path volumes
kubectl get pv | grep kafka

# Verify storage class
kubectl get storageclass local-path
```

### Controller Issues

```bash
# Check controller logs
kubectl logs -n kafka kafka-cluster-controller-0
kubectl logs -n kafka kafka-cluster-controller-1
kubectl logs -n kafka kafka-cluster-controller-2
```

## Scaling

### Scale Brokers

Edit the Kafka resource:
```bash
kubectl edit kafka kafka-cluster -n kafka
# Change: spec.kafka.replicas: 5  (to desired number)
```

### Scale Controllers

Edit the Kafka resource:
```bash
kubectl edit kafka kafka-cluster -n kafka
# Change: spec.controller.replicas: 3  (to desired number)
# Note: Controllers should be odd number (1, 3, 5) for quorum
```

## Cleanup

```bash
# Delete Kafka cluster
kubectl delete kafka kafka-cluster -n kafka

# Delete operator (optional)
helm uninstall strimzi-kafka-operator -n kafka

# Delete namespace (will delete all resources)
kubectl delete namespace kafka
```

## Additional Resources

- [Strimzi Documentation](https://strimzi.io/docs/)
- [Kafka KRaft Documentation](https://kafka.apache.org/documentation/#kraft)
- [Kafka Operations](https://kafka.apache.org/documentation/#operations)

