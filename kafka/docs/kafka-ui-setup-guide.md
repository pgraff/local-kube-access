# Kafka UI Setup Guide

## Overview

Kafka UI (by provectus) is a modern, open-source web UI for Apache Kafka management. It provides a comprehensive interface for monitoring and managing your Kafka cluster.

## Features

- **Cluster Overview**: View cluster health, brokers, and configuration
- **Topic Management**: Browse topics, partitions, messages, and create/delete topics
- **Consumer Groups**: Monitor consumer groups, lag, and offsets
- **Message Browser**: View and search messages in topics
- **Schema Registry**: Integration with Confluent Schema Registry (if configured)
- **Kafka Connect**: Monitor Kafka Connect clusters (if configured)
- **Real-time Metrics**: View broker and topic metrics

## Installation

### Option 1: Using the Provided YAML (Recommended)

The deployment is already configured and ready to use:

```bash
# Apply the deployment
kubectl apply -f k8s/kafka-ui-deployment.yaml

# Check status
kubectl get pods -n kafka -l app=kafka-ui

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=kafka-ui -n kafka --timeout=300s
```

### Option 2: Using Helm

If you prefer Helm:

```bash
# Add the Helm repo (if not already added)
helm repo add kafka-ui https://provectus.github.io/kafka-ui-charts
helm repo update

# Install Kafka UI
helm install kafka-ui kafka-ui/kafka-ui \
  --namespace kafka \
  --values k8s/kafka-ui-values.yaml
```

## Configuration

### Current Configuration

The deployment is configured to connect to your Kafka cluster:

- **Cluster Name**: `kafka-cluster`
- **Bootstrap Server**: `kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`
- **Read-only Mode**: `false` (allows topic creation/deletion)
- **Resources**: 512Mi-1Gi memory, 200m-500m CPU

### Environment Variables

Key configuration options (in `k8s/kafka-ui-deployment.yaml`):

```yaml
KAFKA_CLUSTERS_0_NAME: "kafka-cluster"
KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: "kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
KAFKA_CLUSTERS_0_READONLY: "false"  # Set to "true" for read-only mode
```

### Adding Multiple Clusters

To add multiple Kafka clusters, add more environment variables:

```yaml
KAFKA_CLUSTERS_1_NAME: "another-cluster"
KAFKA_CLUSTERS_1_BOOTSTRAPSERVERS: "another-bootstrap:9092"
```

### Security Configuration

If your Kafka cluster uses TLS or SASL authentication, add:

```yaml
KAFKA_CLUSTERS_0_PROPERTIES_SECURITY_PROTOCOL: "SASL_PLAINTEXT"
KAFKA_CLUSTERS_0_PROPERTIES_SASL_MECHANISM: "PLAIN"
KAFKA_CLUSTERS_0_PROPERTIES_SASL_JAAS_CONFIG: "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"user\" password=\"pass\";"
```

## Accessing Kafka UI

### Using the Access Script

```bash
# Access via Ingress URL (recommended): http://kafka-ui.tailc2013b.ts.net
# Or use port-forwarding fallback: ./access-all.sh
# Then open: http://localhost:8081
# Note: Port 8081 is used (8080 is reserved for Longhorn)
```

### Manual Port-Forward

```bash
kubectl port-forward -n kafka svc/kafka-ui 8081:8080
# Then open: http://localhost:8081
```

### Direct Service Access (from within cluster)

```bash
# From a pod in the cluster
curl http://kafka-ui.kafka.svc.cluster.local:8080
```

## Using Kafka UI

### 1. Cluster Overview

- View cluster health and broker status
- Check cluster configuration
- Monitor broker metrics

### 2. Topics

- **Browse Topics**: View all topics, partitions, and configurations
- **Create Topic**: Create new topics with custom settings
- **Delete Topic**: Remove topics (if not in read-only mode)
- **View Messages**: Browse messages in topics
- **Search Messages**: Search by key, value, or headers

### 3. Consumer Groups

- View all consumer groups
- Monitor consumer lag
- View offset information
- Reset offsets (if not read-only)

### 4. Brokers

- View broker details
- Check broker configuration
- Monitor broker metrics

### 5. Messages

- Browse messages in real-time
- Search messages
- View message headers and metadata
- Export messages

## Monitoring Integration

### Prometheus Metrics (Optional)

Kafka UI can expose Prometheus metrics if you add:

```yaml
env:
- name: KAFKA_CLUSTERS_0_METRICS_PORT
  value: "5556"
```

Then scrape metrics from the pod on port 5556.

### Grafana Dashboards

You can create custom Grafana dashboards using:
- Kafka broker JMX metrics (requires JMX exporter)
- Kafka UI metrics (if enabled)
- Custom Prometheus queries

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl describe pod -n kafka -l app=kafka-ui

# Check logs
kubectl logs -n kafka -l app=kafka-ui

# Check events
kubectl get events -n kafka --sort-by='.lastTimestamp' | grep kafka-ui
```

### Cannot Connect to Kafka

1. **Verify Kafka service is accessible**:
   ```bash
   kubectl get svc -n kafka kafka-cluster-kafka-bootstrap
   ```

2. **Test connectivity from Kafka UI pod**:
   ```bash
   kubectl exec -n kafka -it $(kubectl get pod -n kafka -l app=kafka-ui -o jsonpath='{.items[0].metadata.name}') -- \
     wget -qO- http://kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
   ```

3. **Check bootstrap server address**:
   - Should be: `kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`
   - Verify in the deployment YAML

### UI Shows No Data

1. **Check Kafka cluster is running**:
   ```bash
   kubectl get pods -n kafka | grep kafka-cluster
   ```

2. **Verify bootstrap server in UI**:
   - Go to Settings in Kafka UI
   - Check cluster configuration

3. **Check network policies** (if using):
   - Ensure Kafka UI can reach Kafka brokers

### Read-Only Mode

If you want to prevent topic creation/deletion:

```bash
# Update deployment
kubectl set env deployment/kafka-ui -n kafka KAFKA_CLUSTERS_0_READONLY="true"

# Restart pod
kubectl rollout restart deployment/kafka-ui -n kafka
```

## Upgrading

### Update Image Version

```bash
# Update the image in deployment
kubectl set image deployment/kafka-ui -n kafka kafka-ui=provectuslabs/kafka-ui:v0.7.1

# Or edit the deployment
kubectl edit deployment/kafka-ui -n kafka
```

### Check Latest Version

Visit: https://github.com/provectus/kafka-ui/releases

## Resource Usage

### Current Limits

- **Memory**: 512Mi request, 1Gi limit
- **CPU**: 200m request, 500m limit

### Adjusting Resources

```bash
# Update resources
kubectl set resources deployment/kafka-ui -n kafka \
  --requests=memory=1Gi,cpu=500m \
  --limits=memory=2Gi,cpu=1000m
```

## High Availability

For production, consider:

1. **Multiple Replicas**:
   ```bash
   kubectl scale deployment/kafka-ui -n kafka --replicas=2
   ```

2. **Service with Load Balancer**:
   - Change service type to `LoadBalancer` or use Ingress

3. **Persistent Configuration**:
   - Store configuration in ConfigMap
   - Use StatefulSet if needed

## Related Documentation

- [Kafka Setup Guide](kafka-setup-guide.md) - Main Kafka cluster setup
- [Strimzi Local-Path Workaround](strimzi-local-path-workaround.md) - Storage configuration
- [Access Scripts](README.md#scripts) - How to access Kafka UI

## Alternative Tools

If Kafka UI doesn't meet your needs, consider:

1. **Kowl** (cloudhut/kowl) - Modern alternative with similar features
2. **Kafdrop** - Simple web UI (lighter weight)
3. **Confluent Control Center** - Enterprise solution (requires license)
4. **Grafana + Prometheus** - Custom dashboards with Kafka JMX metrics

## Quick Reference

```bash
# Access Kafka UI
# Access via Ingress URL (recommended): http://kafka-ui.tailc2013b.ts.net
# Or use port-forwarding fallback: ./access-all.sh

# Check status
kubectl get pods -n kafka -l app=kafka-ui

# View logs
kubectl logs -n kafka -l app=kafka-ui -f

# Restart
kubectl rollout restart deployment/kafka-ui -n kafka

# Update configuration
kubectl edit deployment/kafka-ui -n kafka
```

