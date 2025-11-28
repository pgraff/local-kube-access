# Portable IoT Stack Deployment Guide

This guide helps you deploy the IoT stack to any Kubernetes cluster by making it cluster-agnostic.

## Overview

The IoT stack has been refactored to be portable across different Kubernetes clusters by:
- Making storage classes configurable
- Making Kafka bootstrap servers configurable
- Making namespaces configurable
- Using environment variables and templates
- Removing hardcoded cluster-specific values

## Prerequisites

- Kubernetes cluster (any distribution)
- kubectl configured
- Helm 3.x installed
- Storage class available (for persistent volumes)
- Kafka cluster (or install one)

## Configuration

### Step 1: Identify Your Cluster Settings

```bash
# Check available storage classes
kubectl get storageclass

# Check Kafka cluster (if exists)
kubectl get kafka -A

# Check namespace (create if needed)
kubectl get namespace iot || kubectl create namespace iot
```

### Step 2: Create Configuration File

Copy the template and customize:

```bash
cp iot/k8s/config-template.yaml iot/k8s/config.yaml
```

Edit `iot/k8s/config.yaml` with your values:

```yaml
# Example for different clusters:

# For AWS EKS:
STORAGE_CLASS: "gp2"
KAFKA_BOOTSTRAP_SERVERS: "my-kafka-bootstrap.kafka.svc.cluster.local:9092"

# For GKE:
STORAGE_CLASS: "standard"
KAFKA_BOOTSTRAP_SERVERS: "kafka-bootstrap.kafka.svc.cluster.local:9092"

# For local-path (local development):
STORAGE_CLASS: "local-path"
KAFKA_BOOTSTRAP_SERVERS: "kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
```

### Step 3: Set Environment Variables

```bash
# Source the config
export $(kubectl get configmap iot-stack-config -n iot -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key)=\(.value)"')

# Or set manually
export NAMESPACE="iot"
export STORAGE_CLASS="longhorn"  # or "standard", "gp2", "local-path", etc.
export KAFKA_BOOTSTRAP_SERVERS="kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
# Note: Twin Service removed - ThingsBoard handles digital twin functionality
```

## Deployment

### Option A: Using Deployment Script (Recommended)

The deployment script has been updated to use environment variables:

```bash
# Set your configuration
export STORAGE_CLASS="your-storage-class"
export KAFKA_BOOTSTRAP_SERVERS="your-kafka-bootstrap:9092"
export NAMESPACE="iot"

# Deploy
./iot/scripts/deploy-iot-stack.sh
```

### Option B: Manual Deployment with Templates

```bash
# Apply ThingsBoard deployment
kubectl apply -f iot/k8s/thingsboard-deployment.yaml

# Note: ThingsBoard handles digital twin functionality - no separate twin service needed
```

### Option C: Using Helm with Values

Update Helm values files to use variables:

```bash
# Update storage class in values files
sed -i 's/storageClass: "longhorn"/storageClass: "'$STORAGE_CLASS'"/g' iot/k8s/*-values.yaml

# Deploy with Helm
helm install mongodb-hono bitnami/mongodb -n iot \
  -f iot/k8s/mongodb-hono-values.yaml \
  --set persistence.storageClass=$STORAGE_CLASS
```

## Cluster-Specific Adaptations

### AWS EKS

```bash
export STORAGE_CLASS="gp2"
export KAFKA_BOOTSTRAP_SERVERS="your-kafka:9092"
```

### Google GKE

```bash
export STORAGE_CLASS="standard"
export KAFKA_BOOTSTRAP_SERVERS="your-kafka:9092"
```

### Azure AKS

```bash
export STORAGE_CLASS="managed-premium"
export KAFKA_BOOTSTRAP_SERVERS="your-kafka:9092"
```

### Local/Minikube/Kind

```bash
export STORAGE_CLASS="standard"  # or "local-path"
export KAFKA_BOOTSTRAP_SERVERS="kafka:9092"
```

### RKE2 (Current Cluster)

```bash
export STORAGE_CLASS="longhorn"
export KAFKA_BOOTSTRAP_SERVERS="kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
```

## Components and Their Configurability

### ✅ Fully Portable

- **Mosquitto** - No cluster-specific config
- **Node-RED** - Uses ConfigMap for settings
- **ThingsBoard** - Handles digital twin functionality via device attributes

### ⚠️ Needs Configuration

- **Hono** - Kafka bootstrap servers, MongoDB connection
- **ThingsBoard** - PostgreSQL connection, storage class
- **PostgreSQL (ThingsBoard)** - Storage class
- **PostgreSQL** - Storage class
- **MongoDB** - Storage class

## Verification

After deployment, verify:

```bash
# Check all pods
kubectl get pods -n iot

# Check storage
kubectl get pvc -n iot

# Check services
kubectl get svc -n iot

# Test connectivity
kubectl exec -n iot <pod> -- curl http://thingsboard:9090
```

## Troubleshooting

### Storage Class Issues

```bash
# List available storage classes
kubectl get storageclass

# Update PVCs if needed
kubectl patch pvc <pvc-name> -n iot -p '{"spec":{"storageClassName":"new-storage-class"}}'
```

### Kafka Connection Issues

```bash
# Test from a pod
kubectl run -it --rm test-kafka --image=curlimages/curl --restart=Never -- \
  sh -c "echo 'Testing Kafka connectivity' && nslookup $KAFKA_BOOTSTRAP_SERVERS"
```

### Namespace Issues

```bash
# Create namespace if missing
kubectl create namespace iot

# Update all resources to use correct namespace
kubectl get all -n iot
```

## Best Practices

1. **Use ConfigMaps/Secrets** for configuration
2. **Use environment variables** for deployment-time config
3. **Use Helm values** for complex configurations
4. **Document cluster-specific requirements**
5. **Test on a small cluster first**

## Migration Checklist

When moving to a new cluster:

- [ ] Identify storage class
- [ ] Identify Kafka bootstrap servers
- [ ] Update configuration files
- [ ] Set environment variables
- [ ] Deploy namespace
- [ ] Deploy databases first
- [ ] Deploy services
- [ ] Verify connectivity
- [ ] Test end-to-end flow

