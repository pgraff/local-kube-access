# Complete Twin Service Deployment Guide

This is the **complete, step-by-step guide** for building and deploying the Kafka-based Digital Twin Service to the RKE2 cluster.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Local Registry Setup](#local-registry-setup)
3. [Docker Configuration](#docker-configuration)
4. [Building the Image](#building-the-image)
5. [Pushing the Image](#pushing-the-image)
6. [Deploying to Cluster](#deploying-to-cluster)
7. [Verification](#verification)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

- **Java 17+** - For building the application
- **Maven 3.6+** - For building the Spring Boot application
- **Docker Desktop** - For building and pushing images
- **kubectl** - Configured to access your RKE2 cluster
- **KUBECONFIG** - Set to `~/.kube/config-rke2-cluster.yaml`

### Cluster Requirements

- **RKE2 Cluster** - Running and accessible
- **Kafka Cluster** - Strimzi-based, running in `kafka` namespace
- **Hono** - Running in `iot` namespace (for telemetry)
- **Storage** - Longhorn or local-path provisioner available

### Verify Prerequisites

```bash
# Check Java
java -version  # Should be 17+

# Check Maven
mvn -version  # Should be 3.6+

# Check Docker
docker --version

# Check kubectl access
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml
kubectl cluster-info
kubectl get nodes

# Check Kafka
kubectl get pods -n kafka

# Check Hono
kubectl get pods -n iot | grep hono
```

---

## Local Registry Setup

The RKE2 cluster uses a **local Docker registry** running inside the cluster. This registry is accessible from:
- **Inside the cluster**: Via ClusterIP service DNS
- **Outside the cluster**: Via port-forward or NodePort

### Step 1: Deploy the Registry

The registry is deployed using the provided YAML:

```bash
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml

# Deploy registry
kubectl apply -f iot/twin-service/k8s/local-registry.yaml

# Wait for registry to be ready
kubectl wait --for=condition=available --timeout=120s \
  deployment/docker-registry -n docker-registry

# Verify registry is running
kubectl get pods -n docker-registry
kubectl get service -n docker-registry
```

**Expected Output:**
```
NAME                               READY   STATUS    RESTARTS   AGE
docker-registry-xxxxx-xxxxx        1/1     Running   0          1m

NAME              TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
docker-registry   NodePort   10.43.xxx.xxx   <none>        5000:30500/TCP   1m
```

### Step 2: Registry Access Methods

The registry is accessible in two ways:

#### Method A: Cluster DNS (for pods)
- **Service**: `docker-registry.docker-registry.svc.cluster.local:5000`
- **Used by**: Kubernetes pods to pull images
- **No configuration needed** - works automatically

#### Method B: Port-Forward (for pushing from local machine)
- **Local**: `127.0.0.1:5000`
- **Used by**: Docker on your local machine to push images
- **Requires**: Port-forward running (see below)

#### Method C: NodePort (alternative, may need firewall rules)
- **Node IP**: `<node-ip>:30500`
- **Used by**: External access (if firewall allows)
- **Note**: May not work due to Tailscale/firewall restrictions

---

## Docker Configuration

Docker must be configured to allow **insecure registries** for the local registry.

### Step 1: Update Docker Daemon Configuration

Edit `~/.docker/daemon.json`:

```json
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "experimental": false,
  "features": {
    "buildkit": true
  },
  "insecure-registries": [
    "localhost:5000",
    "127.0.0.1:5000"
  ]
}
```

**Important**: If you're using NodePort, also add:
```json
"insecure-registries": [
  "localhost:5000",
  "127.0.0.1:5000",
  "<node-ip>:30500"
]
```

### Step 2: Restart Docker Desktop

**CRITICAL**: Docker Desktop **must be restarted** for the configuration to take effect.

1. **Quit Docker Desktop completely**
   - Click Docker icon in menu bar
   - Select "Quit Docker Desktop"
   - Wait for it to fully quit

2. **Restart Docker Desktop**
   - Open Docker Desktop
   - Wait for it to fully start (whale icon stops animating)

3. **Verify configuration**
   ```bash
   docker info | grep -i "insecure"
   ```
   Should show your configured insecure registries.

---

## Building the Image

### Step 1: Navigate to Project Directory

```bash
cd /Users/pettergraff/s/k8s-home/iot/twin-service
```

### Step 2: Build with Build Script (Recommended)

```bash
./build.sh
```

This script will:
1. Clean previous builds
2. Build the Spring Boot JAR with Maven
3. Build the Docker image
4. Tag it as `twin-service:latest`

**Expected Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Building Twin Service
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Building with Maven...
[INFO] BUILD SUCCESS
✅ Maven build complete

🐳 Building Docker image: twin-service:latest
[+] Building XX.Xs (XX/XX) FINISHED
✅ Build complete!
```

**Time**: ~5-10 minutes (first build downloads dependencies)

### Step 3: Verify Image

```bash
docker images | grep twin-service
```

**Expected Output:**
```
twin-service   latest   <image-id>   X minutes ago   388MB
```

### Troubleshooting Build Issues

#### Maven Build Fails

**Error**: `Could not resolve dependencies`

**Solution**: 
- Check internet connection
- Verify Maven can access Maven Central
- Try: `mvn clean install -U` (force update)

#### Docker Build Fails

**Error**: `no match for platform in manifest`

**Solution**: 
- This was fixed by using `eclipse-temurin:17-jre` instead of `alpine`
- If you see this, check the Dockerfile uses the correct base image

---

## Pushing the Image

### Step 1: Start Port-Forward

**In Terminal 1** (keep this running):

```bash
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml

# Start port-forward
kubectl port-forward -n docker-registry service/docker-registry 5000:5000
```

**Expected Output:**
```
Forwarding from 127.0.0.1:5000 -> 5000
Forwarding from [::1]:5000 -> 5000
```

**Keep this terminal open!** The port-forward must stay running.

### Step 2: Verify Registry is Accessible

**In Terminal 2** (new terminal):

```bash
# Test registry access
curl -s http://127.0.0.1:5000/v2/
```

**Expected Output:**
```
{}
```

If you get `connection refused`, the port-forward isn't working. Check:
- Port 5000 isn't already in use: `lsof -i :5000`
- Kill existing port-forwards: `pkill -f "port-forward.*docker-registry"`
- Restart port-forward

### Step 3: Tag the Image

```bash
docker tag twin-service:latest 127.0.0.1:5000/twin-service:latest
```

### Step 4: Push the Image

```bash
docker push 127.0.0.1:5000/twin-service:latest
```

**Expected Output:**
```
The push refers to repository [127.0.0.1:5000/twin-service]
...
latest: digest: sha256:xxxxx size: xxxx
```

**Time**: ~1-2 minutes (depending on image size and network)

### Step 5: Verify Image in Registry

```bash
# List images in registry
curl -s http://127.0.0.1:5000/v2/_catalog | jq
```

**Expected Output:**
```json
{
  "repositories": ["twin-service"]
}
```

### Troubleshooting Push Issues

#### "connection refused"

**Cause**: Port-forward not running or Docker not restarted

**Solution**:
1. Verify port-forward is running: `ps aux | grep "port-forward.*docker-registry"`
2. Restart Docker Desktop (if you just updated daemon.json)
3. Check port 5000: `lsof -i :5000`

#### "dial tcp [::1]:5000: connect: connection refused"

**Cause**: Docker trying IPv6, port-forward on IPv4

**Solution**: Use `127.0.0.1` explicitly (not `localhost`)

#### "unauthorized" or "authentication required"

**Cause**: Registry requires auth (shouldn't happen with our setup)

**Solution**: Check registry configuration in `local-registry.yaml`

---

## Deploying to Cluster

### Step 1: Verify Deployment Configuration

Check `iot/twin-service/k8s/deployment.yaml`:

```yaml
image: docker-registry.docker-registry.svc.cluster.local:5000/twin-service:latest
imagePullPolicy: IfNotPresent
```

**Important**: 
- Uses **cluster DNS name** (not `127.0.0.1`)
- Pods pull from cluster DNS, not port-forward
- Port-forward is only for pushing from your machine

### Step 2: Apply Deployment

```bash
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml

# Apply deployment
kubectl apply -f iot/twin-service/k8s/deployment.yaml
```

**Expected Output:**
```
deployment.apps/twin-service created
service/twin-service created
serviceaccount/twin-service created
```

### Step 3: Scale Deployment

```bash
kubectl scale deployment twin-service -n iot --replicas=2
```

### Step 4: Wait for Pods

```bash
kubectl wait --for=condition=available --timeout=120s \
  deployment/twin-service -n iot
```

---

## Verification

### Step 1: Check Pod Status

```bash
kubectl get pods -n iot -l app=twin-service
```

**Expected Output:**
```
NAME                            READY   STATUS    RESTARTS   AGE
twin-service-xxxxx-xxxxx        1/1     Running   0          1m
twin-service-xxxxx-xxxxx        1/1     Running   0          1m
```

**All pods should be `Running` and `1/1 Ready`**

### Step 2: Check Pod Logs

```bash
kubectl logs -n iot -l app=twin-service --tail=50
```

**Expected Output:**
```
... Spring Boot startup logs ...
Started TwinServiceApplication in X.XXX seconds
```

Look for:
- ✅ "Started TwinServiceApplication"
- ✅ No Kafka connection errors
- ✅ No image pull errors

### Step 3: Test Health Endpoint

```bash
# Port-forward the service
kubectl port-forward -n iot service/twin-service 8080:8080

# In another terminal
curl http://localhost:8080/actuator/health
```

**Expected Output:**
```json
{
  "status": "UP"
}
```

### Step 4: Test API Endpoints

```bash
# Get all twins (should be empty initially)
curl http://localhost:8080/api/v1/twins

# Expected: []
```

### Step 5: Verify Kafka Integration

```bash
# Check if service is consuming from Kafka
kubectl logs -n iot -l app=twin-service | grep -i kafka

# Should see Kafka Streams initialization
```

---

## Troubleshooting

### Pod Status: ImagePullBackOff

**Symptoms:**
```
NAME                            READY   STATUS             RESTARTS   AGE
twin-service-xxxxx-xxxxx        0/1     ImagePullBackOff   0          2m
```

**Causes & Solutions:**

1. **Image not in registry**
   ```bash
   # Verify image exists
   curl -s http://127.0.0.1:5000/v2/_catalog | jq
   
   # If missing, push again
   docker push 127.0.0.1:5000/twin-service:latest
   ```

2. **Wrong image name in deployment**
   ```bash
   # Check deployment
   kubectl get deployment twin-service -n iot -o yaml | grep image
   
   # Should be: docker-registry.docker-registry.svc.cluster.local:5000/twin-service:latest
   ```

3. **Registry not accessible from pods**
   ```bash
   # Test from a pod
   kubectl run -it --rm test --image=busybox --restart=Never -- \
     wget -O- http://docker-registry.docker-registry.svc.cluster.local:5000/v2/
   ```

### Pod Status: CrashLoopBackOff

**Symptoms:**
```
NAME                            READY   STATUS             RESTARTS   AGE
twin-service-xxxxx-xxxxx        0/1     CrashLoopBackOff   3          2m
```

**Solution:**
```bash
# Check logs
kubectl logs -n iot -l app=twin-service --previous

# Common causes:
# - Kafka connection issues
# - Missing environment variables
# - Application errors
```

### Pod Status: Pending

**Symptoms:**
```
NAME                            READY   STATUS    RESTARTS   AGE
twin-service-xxxxx-xxxxx        0/1     Pending   0          2m
```

**Solution:**
```bash
# Check why pending
kubectl describe pod -n iot -l app=twin-service

# Common causes:
# - Resource constraints
# - Node selector issues
# - PVC issues
```

### Kafka Connection Issues

**Symptoms:**
- Logs show "Connection refused" or "Bootstrap server unreachable"

**Solution:**
```bash
# Verify Kafka is running
kubectl get pods -n kafka

# Test connectivity from pod
kubectl exec -n iot -it <twin-service-pod> -- \
  wget -O- http://kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092

# Check environment variables
kubectl exec -n iot <twin-service-pod> -- env | grep KAFKA
```

### No Twin Data

**Symptoms:**
- API returns empty array: `[]`

**Solution:**
```bash
# 1. Verify Hono is publishing telemetry
kubectl exec -n kafka kafka-cluster-kafka-0 -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic hono.telemetry \
  --from-beginning \
  --max-messages 5

# 2. Check twin service is processing
kubectl logs -n iot -l app=twin-service | grep -i "telemetry\|twin"

# 3. Verify Kafka topics exist
kubectl exec -n kafka kafka-cluster-kafka-0 -- \
  bin/kafka-topics.sh --bootstrap-server localhost:9092 --list | grep -E "hono|device"
```

---

## Quick Reference

### Common Commands

```bash
# Build image
cd iot/twin-service && ./build.sh

# Start port-forward (Terminal 1)
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml
kubectl port-forward -n docker-registry service/docker-registry 5000:5000

# Push image (Terminal 2)
docker tag twin-service:latest 127.0.0.1:5000/twin-service:latest
docker push 127.0.0.1:5000/twin-service:latest

# Deploy
kubectl apply -f iot/twin-service/k8s/deployment.yaml
kubectl scale deployment twin-service -n iot --replicas=2

# Check status
kubectl get pods -n iot -l app=twin-service
kubectl logs -n iot -l app=twin-service -f

# Test API
kubectl port-forward -n iot service/twin-service 8080:8080
curl http://localhost:8080/actuator/health
```

### Registry Endpoints

- **Cluster DNS** (for pods): `docker-registry.docker-registry.svc.cluster.local:5000`
- **Port-Forward** (for pushing): `127.0.0.1:5000`
- **NodePort** (alternative): `<node-ip>:30500`

### Important Files

- **Build script**: `iot/twin-service/build.sh`
- **Dockerfile**: `iot/twin-service/Dockerfile`
- **Deployment**: `iot/twin-service/k8s/deployment.yaml`
- **Registry**: `iot/twin-service/k8s/local-registry.yaml`
- **Docker config**: `~/.docker/daemon.json`

---

## Next Steps

Once the twin service is running:

1. **Monitor logs** for telemetry processing
2. **Test API endpoints** with real device data
3. **Integrate with ThingsBoard** or other dashboards
4. **Set up monitoring** (Prometheus/Grafana)
5. **Configure Ingress** for external access (if needed)

---

## Summary Checklist

- [ ] Prerequisites verified (Java, Maven, Docker, kubectl)
- [ ] Local registry deployed and running
- [ ] Docker daemon.json updated with insecure registries
- [ ] Docker Desktop restarted
- [ ] Image built successfully (`./build.sh`)
- [ ] Port-forward started and running
- [ ] Image pushed to registry
- [ ] Deployment applied to cluster
- [ ] Pods running and healthy
- [ ] Health endpoint responding
- [ ] API endpoints working
- [ ] Kafka integration verified

---

**Last Updated**: 2025-11-27
**Version**: 1.0.0

