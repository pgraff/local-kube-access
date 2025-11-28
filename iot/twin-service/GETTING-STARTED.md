# Getting Digital Twins Working - Step by Step

## Current Status

✅ **What's Done:**
- Complete Spring Boot application with Kafka Streams
- All Java code written and ready
- Dockerfile created
- Kubernetes deployment YAML ready
- Build scripts ready

⏳ **What's Needed:**
- Build the Docker image
- Deploy to cluster
- Verify it's working

## Quick Answer

**Yes, it's primarily about building the Docker image!** The code is complete and ready. Here's what you need to do:

## Step-by-Step Process

### Step 1: Build the Docker Image

You have two options:

#### Option A: Build Locally (if you have Java/Maven)

```bash
cd iot/twin-service
mvn clean package -DskipTests
docker build -t twin-service:latest .
```

#### Option B: Build with Build Script (Recommended)

```bash
cd iot/twin-service
./build.sh
```

This script will:
1. Build the Spring Boot JAR with Maven (if available)
2. Build the Docker image
3. Tag it as `twin-service:latest`

**Time:** ~5-10 minutes (first build downloads dependencies)

### Step 2: Set Up Local Registry in Cluster

**IMPORTANT**: The RKE2 cluster uses a **local Docker registry** running inside the cluster.

#### Step 2a: Deploy the Registry

```bash
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml

# Deploy registry
kubectl apply -f iot/twin-service/k8s/local-registry.yaml

# Wait for registry to be ready
kubectl wait --for=condition=available --timeout=120s \
  deployment/docker-registry -n docker-registry

# Verify
kubectl get pods -n docker-registry
```

#### Step 2b: Configure Docker for Insecure Registry

Edit `~/.docker/daemon.json`:

```json
{
  "insecure-registries": [
    "localhost:5000",
    "127.0.0.1:5000"
  ]
}
```

**CRITICAL**: Restart Docker Desktop after updating this file!

#### Step 2c: Push Image to Registry

**Terminal 1** (keep running):
```bash
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml
kubectl port-forward -n docker-registry service/docker-registry 5000:5000
```

**Terminal 2**:
```bash
# Tag image
docker tag twin-service:latest 127.0.0.1:5000/twin-service:latest

# Push to registry
docker push 127.0.0.1:5000/twin-service:latest
```

**See**: `COMPLETE-DEPLOYMENT-GUIDE.md` for detailed instructions and troubleshooting.

### Step 3: Verify Deployment Configuration

The deployment is already configured to use the local registry:

```yaml
image: docker-registry.docker-registry.svc.cluster.local:5000/twin-service:latest
imagePullPolicy: IfNotPresent
```

**No changes needed** - this uses the cluster DNS name for the registry.

### Step 4: Deploy to Cluster

```bash
# Scale up the deployment
kubectl scale deployment twin-service -n iot --replicas=2

# Or apply the deployment
kubectl apply -f iot/twin-service/k8s/deployment.yaml

# Check status
kubectl get pods -n iot -l app=twin-service
```

### Step 5: Verify It's Working

```bash
# Check pods are running
kubectl get pods -n iot -l app=twin-service

# Check logs
kubectl logs -n iot -l app=twin-service -f

# Test API
kubectl port-forward -n iot service/twin-service 8080:8080
curl http://localhost:8080/actuator/health
curl http://localhost:8080/api/v1/twins
```

## Prerequisites Check

Before building, verify:

✅ **Code is ready** - All Java files exist  
✅ **Dockerfile exists** - Ready for building  
✅ **Kafka cluster** - Running in `kafka` namespace  
✅ **Hono** - Running and publishing to `hono.telemetry` topic  

## What Happens After Deployment

Once the twin service is running:

1. **Consumes telemetry** from `hono.telemetry` Kafka topic
2. **Maintains twin state** in Kafka Streams state store
3. **Exposes REST API** at `/api/v1/twins` for queries
4. **Publishes updates** to `device.twins` topic

## Troubleshooting

### Image Pull Errors

If you see `ImagePullBackOff`:
- Verify image exists: `docker images | grep twin-service`
- Check image name in deployment.yaml matches
- For local clusters, ensure `imagePullPolicy: Never`

### Pod Not Starting

Check logs:
```bash
kubectl logs -n iot -l app=twin-service
```

Common issues:
- Kafka connection issues (check bootstrap servers)
- Missing Kafka topics (will be created automatically)
- Resource constraints (check node resources)

### No Twin Data

1. Verify Hono is publishing telemetry:
   ```bash
   kubectl exec -n kafka kafka-cluster-kafka-0 -- \
     bin/kafka-console-consumer.sh \
     --bootstrap-server localhost:9092 \
     --topic hono.telemetry \
     --from-beginning
   ```

2. Check twin service logs for processing:
   ```bash
   kubectl logs -n iot -l app=twin-service | grep -i twin
   ```

## Next Steps After It's Running

1. **Test the API:**
   - Query twins: `GET /api/v1/twins`
   - Get specific twin: `GET /api/v1/twins/{deviceId}`
   - Update desired state: `PUT /api/v1/twins/{deviceId}/desired`

2. **Integrate with ThingsBoard:**
   - Connect ThingsBoard to query twin service
   - Display twin state in dashboards

3. **Integrate with Node-RED:**
   - Create flows that use twin service API
   - Build automation based on twin state

## Summary

**To get Digital Twins working:**

1. ✅ Code is ready
2. ⏳ Build Docker image (`./build.sh`)
3. ⏳ Push to registry or load into cluster
4. ⏳ Update deployment.yaml with image path
5. ⏳ Scale deployment to 2 replicas
6. ⏳ Verify it's working

**Estimated time:** 15-30 minutes (mostly build time)

The hardest part (writing the code) is done! Now it's just building and deploying. 🚀

