# NATS and JetStream Setup Guide

This guide explains how to deploy and use NATS with JetStream in your Kubernetes cluster.

## Overview

NATS is a high-performance messaging system that provides:
- **Pub/Sub messaging**: Lightweight publish-subscribe messaging
- **Request/Reply**: Synchronous request-reply patterns
- **JetStream**: Persistent messaging and streaming (similar to Kafka)

## Architecture

The deployment consists of:
- **3-node NATS cluster** for high availability
- **JetStream enabled** for persistent messaging
- **Persistent storage** (20Gi per node) using `local-path` storage class
- **Monitoring endpoint** on port 8222

## Prerequisites

- Kubernetes cluster with kubectl configured
- Storage class `local-path` available (or modify the StatefulSet to use your storage class)
- Kubeconfig file at `$HOME/.kube/config-rke2-cluster.yaml` (or set `KUBECONFIG` env var)

## Deployment

### Quick Deploy

```bash
cd /home/petter/dev/scispike/local-kube-access
./nats/scripts/deploy-nats.sh
```

### Manual Deploy

```bash
# Create namespace
kubectl apply -f nats/k8s/nats-namespace.yaml

# Deploy NATS
kubectl apply -f nats/k8s/nats-configmap.yaml
kubectl apply -f nats/k8s/nats-statefulset.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready --timeout=300s statefulset/nats -n nats
```

## Accessing NATS

### Port Forwarding

Use the provided script:

```bash
./nats/scripts/access-nats.sh
```

This will forward:
- **Port 4222**: NATS client connection
- **Port 8222**: NATS monitoring/HTTP endpoint

### Connection Strings

- **Client**: `nats://localhost:4222`
- **Cluster**: `nats://nats-0.nats-headless.nats.svc.cluster.local:4222` (from within cluster)
- **Monitoring**: `http://localhost:8222` (when port-forwarded)

## Using NATS

### NATS CLI

Install the NATS CLI:

```bash
# Using Go
go install github.com/nats-io/natscli/nats@latest

# Or download binary
# https://github.com/nats-io/natscli/releases
```

Basic operations:

```bash
# Publish a message
nats pub test.subject "Hello NATS"

# Subscribe to messages
nats sub test.subject

# Request/Reply
nats request test.request "What's the time?"

# List subjects
nats sub ls
```

### JetStream (Persistent Messaging)

JetStream provides persistent messaging similar to Kafka:

```bash
# Create a stream
nats stream add test-stream --subjects "test.>" --storage file --replicas 3

# Publish to stream
nats pub test.message "Persistent message"

# Subscribe to stream
nats consumer add test-stream test-consumer --pull --deliver all

# Pull messages
nats consumer next test-stream test-consumer
```

### Monitoring

Check NATS status:

```bash
# Server info
curl http://localhost:8222/varz

# JetStream info
curl http://localhost:8222/jsz

# Connections
curl http://localhost:8222/connz
```

## Configuration

### Modify NATS Config

Edit `nats/k8s/nats-configmap.yaml` and reapply:

```bash
kubectl apply -f nats/k8s/nats-configmap.yaml
kubectl rollout restart statefulset/nats -n nats
```

### Storage

To change storage size or class, edit `nats/k8s/nats-statefulset.yaml`:

```yaml
volumeClaimTemplates:
- metadata:
    name: data
  spec:
    accessModes: [ "ReadWriteOnce" ]
    storageClassName: local-path  # Change this
    resources:
      requests:
        storage: 20Gi  # Change this
```

### Resources

Adjust CPU/memory limits in `nats/k8s/nats-statefulset.yaml`:

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n nats
kubectl describe pod nats-0 -n nats
```

### View Logs

```bash
# All pods
kubectl logs -n nats -l app=nats --tail=100

# Specific pod
kubectl logs -n nats nats-0 --tail=100 -f
```

### Check Services

```bash
kubectl get svc -n nats
kubectl describe svc nats -n nats
```

### Verify JetStream

```bash
# Port forward first
./nats/scripts/access-nats.sh

# In another terminal
curl http://localhost:8222/jsz | jq
```

### Common Issues

1. **Pods not starting**: Check storage class availability
   ```bash
   kubectl get storageclass
   ```

2. **Cluster not forming**: Check cluster routes in ConfigMap
   ```bash
   kubectl get configmap nats-config -n nats -o yaml
   ```

3. **JetStream not working**: Verify persistent volumes are mounted
   ```bash
   kubectl exec -n nats nats-0 -- ls -la /data/jetstream
   ```

## Uninstalling

```bash
# Delete StatefulSet (this will delete PVCs if deleteClaim is true)
kubectl delete -f nats/k8s/nats-statefulset.yaml

# Delete ConfigMap
kubectl delete -f nats/k8s/nats-configmap.yaml

# Delete namespace (this deletes everything)
kubectl delete namespace nats
```

## Integration Examples

### From Kubernetes Pods

```go
// Go example
nc, err := nats.Connect("nats://nats.nats.svc.cluster.local:4222")
if err != nil {
    log.Fatal(err)
}
defer nc.Close()

// Publish
nc.Publish("test.subject", []byte("Hello"))
```

### Spring Boot

```yaml
# application.yml
spring:
  nats:
    servers: nats://nats.nats.svc.cluster.local:4222
```

## NATS UI (Management Interface)

A web-based management UI (NUI) has been deployed for monitoring and managing your NATS cluster.

### Access NATS UI

**Option 1: Via Ingress (Recommended)**
```bash
# Apply ingress (if not already applied)
kubectl apply -f nats/k8s/nats-ui-ingress.yaml

# Access at: http://nats-ui.tailc2013b.ts.net
```

**Option 2: Via Port Forwarding**
```bash
./nats/scripts/access-nats-ui.sh
# Then open: http://localhost:31311
```

### Connecting to NATS in NUI

NUI uses a backend proxy architecture: the NUI backend (running in the pod) connects to NATS, and your browser communicates with the NUI backend. This means the connection happens from within the cluster.

**The deployment is already configured correctly:**
- `NATS_URL=nats://nats.nats.svc.cluster.local:4222` (cluster-internal service)
- `NATS_WS_URL=ws://nats.nats.svc.cluster.local:4222` (WebSocket for real-time updates)

**When NUI prompts for connection details (if needed), use:**

- **Host/URL**: `nats://nats.nats.svc.cluster.local:4222`
  - This is the cluster-internal Kubernetes service name
  - Works because NUI backend pod is in the same cluster
- **Port**: `4222` (default NATS port)
- **Authentication**: Leave empty (no authentication configured)
  - Username: (leave blank)
  - Password: (leave blank)
- **TLS**: Disabled (not configured)

**Note:** NUI should automatically use the `NATS_URL` environment variable. If you're prompted to manually add a connection, the service name above is what you need. The browser connects to the NUI backend (via the web interface), and the backend connects to NATS using the cluster-internal service name.

### NATS UI Features

- **Server Monitoring**: View server health, connections, and metrics
- **JetStream Management**: Create and manage streams, consumers, and key-value stores
- **Pub/Sub Testing**: Publish and subscribe to subjects interactively
- **Cluster Status**: Monitor cluster health and routing
- **Real-time Metrics**: View live server statistics

### Check UI Status

```bash
kubectl get pods -n nats -l app=nats-ui
kubectl get svc -n nats -l app=nats-ui
```

## References

- [NATS Documentation](https://docs.nats.io/)
- [JetStream Documentation](https://docs.nats.io/nats-concepts/jetstream)
- [NATS CLI](https://github.com/nats-io/natscli)
- [NUI (NATS User Interface)](https://github.com/nats-nui/nui)
