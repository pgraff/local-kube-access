# Twin Service Deployment Guide

This guide walks you through building and deploying the Kafka-based twin service.

## Prerequisites

1. **Kubernetes Cluster** with:
   - Kafka cluster (Strimzi) running in `kafka` namespace
   - Hono deployed in `iot` namespace
   - NGINX Ingress Controller

2. **Local Development Environment**:
   - Java 17+
   - Maven 3.6+
   - Docker
   - kubectl configured

## Step 1: Build the Application

### Option A: Build Locally with Maven

```bash
cd iot/twin-service
mvn clean package -DskipTests
```

### Option B: Build with Docker

```bash
cd iot/twin-service
./build.sh
```

This will:
- Build the Spring Boot application
- Create a Docker image: `twin-service:latest`

## Step 2: Set Up Local Registry

The RKE2 cluster uses a **local Docker registry** running inside the cluster.

### Step 2a: Deploy Registry

```bash
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml

# Deploy registry
kubectl apply -f iot/twin-service/k8s/local-registry.yaml

# Wait for registry
kubectl wait --for=condition=available --timeout=120s \
  deployment/docker-registry -n docker-registry
```

### Step 2b: Configure Docker

Edit `~/.docker/daemon.json`:

```json
{
  "insecure-registries": [
    "localhost:5000",
    "127.0.0.1:5000"
  ]
}
```

**IMPORTANT**: Restart Docker Desktop after this change!

### Step 2c: Push Image

**Terminal 1** (keep running):
```bash
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml
kubectl port-forward -n docker-registry service/docker-registry 5000:5000
```

**Terminal 2**:
```bash
docker tag twin-service:latest 127.0.0.1:5000/twin-service:latest
docker push 127.0.0.1:5000/twin-service:latest
```

**See**: `COMPLETE-DEPLOYMENT-GUIDE.md` for detailed instructions.

## Step 3: Verify Deployment Configuration

The deployment is already configured correctly:

```yaml
image: docker-registry.docker-registry.svc.cluster.local:5000/twin-service:latest
imagePullPolicy: IfNotPresent
```

**No changes needed** - this uses the cluster DNS name for the registry.

## Step 4: Deploy to Kubernetes

### Using the Deployment Script

```bash
./iot/scripts/deploy-twin-service.sh
```

### Manual Deployment

```bash
kubectl apply -f iot/twin-service/k8s/deployment.yaml
```

## Step 5: Verify Deployment

```bash
# Check pods
kubectl get pods -n iot -l app=twin-service

# Check logs
kubectl logs -n iot -l app=twin-service -f

# Check service
kubectl get service -n iot twin-service
```

## Step 6: Test the API

### Port Forward

```bash
kubectl port-forward -n iot service/twin-service 8080:8080
```

### Test Endpoints

```bash
# Health check
curl http://localhost:8080/actuator/health

# Get all twins
curl http://localhost:8080/api/v1/twins

# Get specific twin
curl http://localhost:8080/api/v1/twins/device-001
```

## Troubleshooting

### Pod Not Starting

1. **Check pod status:**
   ```bash
   kubectl describe pod -n iot -l app=twin-service
   ```

2. **Check logs:**
   ```bash
   kubectl logs -n iot -l app=twin-service
   ```

3. **Common issues:**
   - **ImagePullBackOff**: Image not found. Check image name and registry.
   - **CrashLoopBackOff**: Application error. Check logs.
   - **Pending**: Resource constraints or node issues.

### Kafka Connection Issues

1. **Verify Kafka is running:**
   ```bash
   kubectl get pods -n kafka
   ```

2. **Test Kafka connectivity from pod:**
   ```bash
   kubectl exec -n iot -it <twin-service-pod> -- \
     wget -O- http://kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
   ```

3. **Check Kafka topics:**
   ```bash
   kubectl exec -n kafka kafka-cluster-kafka-0 -- \
     bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
   ```

### No Twin Data

1. **Verify telemetry is flowing:**
   ```bash
   kubectl exec -n kafka kafka-cluster-kafka-0 -- \
     bin/kafka-console-consumer.sh \
     --bootstrap-server localhost:9092 \
     --topic hono.telemetry \
     --from-beginning
   ```

2. **Check state store:**
   - State store is created when first message is processed
   - Restart may be needed if state store is corrupted

## Configuration

### Environment Variables

You can override configuration via environment variables in the deployment:

```yaml
env:
- name: SPRING_KAFKA_BOOTSTRAP_SERVERS
  value: "kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
- name: TWIN_TELEMETRY_TOPIC
  value: "hono.telemetry"
```

### Application Properties

Edit `src/main/resources/application.yml` and rebuild if you need to change defaults.

## Scaling

To scale the service:

```bash
kubectl scale deployment twin-service -n iot --replicas=3
```

**Note**: Kafka Streams handles state store distribution automatically across instances.

## Updating

1. Build new image:
   ```bash
   cd iot/twin-service
   ./build.sh
   ```

2. Update image tag in deployment:
   ```yaml
   image: twin-service:v1.0.1
   ```

3. Apply:
   ```bash
   kubectl apply -f iot/twin-service/k8s/deployment.yaml
   ```

4. Rolling update will happen automatically.

## Monitoring

### Health Checks

- Liveness: `/actuator/health/liveness`
- Readiness: `/actuator/health/readiness`

### Metrics

- Metrics: `/actuator/metrics`
- Prometheus: `/actuator/prometheus` (if enabled)

## Next Steps

- [ ] Set up monitoring (Prometheus/Grafana)
- [ ] Configure authentication
- [ ] Add WebSocket support
- [ ] Implement twin history
- [ ] Add search capabilities

