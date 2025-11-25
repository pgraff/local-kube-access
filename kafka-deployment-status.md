# Kafka Cluster Deployment Status

## Current Status

**Deployment Time**: November 25, 2025  
**Kafka Version**: 4.1.1  
**Operator Version**: 0.49.0  
**Mode**: KRaft (no Zookeeper)

## Configuration

- **3 KRaft Controllers** - For cluster metadata and coordination
- **5 Kafka Brokers** - For message storage and processing
- **Storage**: Local-path (100Gi per broker, 20Gi per controller) - Using local disk for better performance
- **Replication**: 3x replication factor

## Deployment Progress

### ✅ Completed
- Strimzi operator installed and running
- Kafka cluster resource created
- Controller and broker node pools created
- Persistent volume claims created (8 PVCs, all bound)
- Services created (bootstrap and broker services)

### ⏳ In Progress
- Pods are being created and starting up
- One controller pod is running (but waiting for quorum)
- Image pulls in progress (some network retries happening)

### ⚠️ Known Issues

1. **Image Pull Errors** (temporary)
   - Some pods experiencing TLS errors pulling from quay.io
   - Kubernetes will retry automatically
   - This is typically a transient network issue

2. **Longhorn Volume Attachment**
   - Some nodes experiencing volume attachment delays
   - This is normal during initial deployment
   - Volumes are created and bound, attachment is in progress

3. **Readiness Probe Failures**
   - Controller pod failing readiness (expected - needs quorum)
   - Will resolve once all 3 controllers are running

## Expected Timeline

- **0-5 minutes**: Operator installs, resources created
- **5-10 minutes**: PVCs created and bound, pods scheduled
- **10-15 minutes**: Images pulled, containers starting
- **15-20 minutes**: All pods running, cluster forming
- **20-25 minutes**: Cluster ready, all health checks passing

## Monitoring Commands

```bash
# Check pod status
kubectl get pods -n kafka

# Check PVC status
kubectl get pvc -n kafka

# Check services
kubectl get svc -n kafka

# Check Kafka cluster status
kubectl get kafka kafka-cluster -n kafka

# Watch pod events
kubectl get events -n kafka --sort-by='.lastTimestamp'

# Check specific pod logs
kubectl logs -n kafka kafka-cluster-controllers-7
kubectl logs -n kafka kafka-cluster-brokers-0
```

## Next Steps

1. **Wait for deployment** - Allow 15-20 minutes for all pods to start
2. **Verify cluster health** - Check that all 8 pods (3 controllers + 5 brokers) are running
3. **Test connectivity** - Use `./access-kafka.sh` to port-forward and test
4. **Create test topic** - Verify cluster is functional

## Troubleshooting

If pods remain in ImagePullBackOff:
```bash
# Check image pull secrets
kubectl get secrets -n kafka

# Try manual pull on a node
# SSH to a node and test: docker pull quay.io/strimzi/kafka:0.49.0-kafka-4.1.1
```

If local-path volumes fail to attach:
```bash
# Check volume status
kubectl get pv
kubectl describe pvc <pvc-name> -n kafka

# Check local-path provisioner
kubectl get pods -n local-path-storage
kubectl logs -n local-path-storage -l app=local-path-provisioner
```

If controllers don't form quorum:
```bash
# Check controller logs
kubectl logs -n kafka kafka-cluster-controllers-5
kubectl logs -n kafka kafka-cluster-controllers-6
kubectl logs -n kafka kafka-cluster-controllers-7

# Verify all 3 are running
kubectl get pods -n kafka -l strimzi.io/kind=Kafka
```

## Access Once Ready

```bash
# Port-forward to Kafka
./access-kafka.sh

# In another terminal, test with producer
kubectl run kafka-producer -it --rm --image=quay.io/strimzi/kafka:latest-kafka-4.1.1 \
  -- bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic test-topic
```

