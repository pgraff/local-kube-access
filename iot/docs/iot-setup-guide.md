# IoT Stack Setup Guide

## Overview

This guide covers the deployment and configuration of a complete IoT platform stack in the `iot` namespace. The stack integrates with your existing Kafka cluster and provides a full pipeline from device connectivity to visualization and automation.

## Architecture

```
Home Devices → Mosquitto → Hono → Kafka → ThingsBoard CE (PostgreSQL)
                                    │
                                    └──> Node-RED
```

### Component Flow

1. **Eclipse Mosquitto** - MQTT broker receives messages from IoT devices
2. **Eclipse Hono** - Device connectivity gateway that processes MQTT messages and forwards to Kafka
3. **Apache Kafka** - Message broker (already deployed in `kafka` namespace)
4. **ThingsBoard CE** - Dashboards, rules, device management, and digital twin functionality (stores telemetry in PostgreSQL)
5. **Node-RED** - Visual programming for automation

## Prerequisites

- Kubernetes cluster with kubectl access
- Helm 3.x installed
- Existing Kafka cluster in `kafka` namespace
- Sufficient cluster resources:
  - CPU: ~8-12 cores
  - Memory: ~16-24GB
  - Storage: ~200Gi (Longhorn)

## Quick Start

### Deploy Everything

```bash
# Deploy the complete IoT stack
cd iot/scripts
./deploy-iot-stack.sh
```

This script will:
1. Create the `iot` namespace
2. Add all required Helm repositories
3. Deploy all databases (MongoDB for Hono, PostgreSQL for ThingsBoard)
4. Deploy all IoT components (Mosquitto, Hono, ThingsBoard, Node-RED)
5. Configure integrations

**Note:** ThingsBoard handles digital twin functionality - no separate twin service needed!

### Uninstall Everything

```bash
# Remove the complete IoT stack
cd iot/scripts
./uninstall-iot-stack.sh
```

## Manual Deployment Steps

If you prefer to deploy components individually:

### 1. Create Namespace

```bash
kubectl apply -f iot/k8s/iot-namespace.yaml
```

### 2. Add Helm Repositories

```bash
helm repo add eclipse-iot https://eclipse.org/packages/charts
helm repo add thingsboard https://thingsboard.github.io/helm-charts/
helm repo add timescale https://charts.timescale.com/
helm repo add atnog https://atnog.github.io/ditto-helm-chart/
helm repo add cloudnesil https://cloudnesil.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### 3. Deploy Databases

```bash
# MongoDB for Hono
helm install mongodb-hono bitnami/mongodb \
  -n iot -f iot/k8s/mongodb-hono-values.yaml --wait

# MongoDB for Ditto
helm install mongodb-ditto bitnami/mongodb \
  -n iot -f iot/k8s/mongodb-ditto-values.yaml --wait

# PostgreSQL for ThingsBoard
helm install postgresql-thingsboard bitnami/postgresql \
  -n iot -f iot/k8s/postgresql-thingsboard-values.yaml --wait
```

### 4. Deploy IoT Components

```bash
# Mosquitto (direct YAML deployment)
kubectl apply -f iot/k8s/mosquitto-deployment.yaml -n iot

# Hono
helm install hono eclipse-iot/hono \
  -n iot -f iot/k8s/hono-values.yaml --wait

# ThingsBoard (direct YAML deployment)
# Note: ThingsBoard handles digital twin functionality via device attributes
kubectl apply -f iot/k8s/thingsboard-deployment.yaml -n iot

# Node-RED
kubectl apply -f iot/k8s/nodered-deployment.yaml -n iot
```

## Configuration

### Kafka Integration

All components are configured to connect to your existing Kafka cluster:

- **Bootstrap Server**: `kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`
- **Topics**:
  - `hono.telemetry.*` - Device telemetry from Hono
  - `hono.event.*` - Device events from Hono
  - `ditto.*` - Digital twin updates
  - `thingsboard.*` - ThingsBoard telemetry

### Service Discovery

All services use Kubernetes DNS:
- Within `iot` namespace: `service-name.iot.svc.cluster.local`
- Cross-namespace (Kafka): `kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local`

### Storage

All persistent volumes use Longhorn storage class:
- TimescaleDB: 100Gi
- MongoDB (Hono): 20Gi
- MongoDB (Ditto): 20Gi
- PostgreSQL: 50Gi
- Node-RED: 5Gi

## Accessing Services

### Access Methods

**HTTP Services (via Ingress URLs - Recommended):**
After setting up `/etc/hosts` (see [LAPTOP-SETUP.md](../../LAPTOP-SETUP.md)):
- **Hono:** http://hono.tailc2013b.ts.net
- **Ditto:** http://ditto.tailc2013b.ts.net
- **ThingsBoard:** http://thingsboard.tailc2013b.ts.net
- **Node-RED:** http://nodered.tailc2013b.ts.net

**TCP Services (Port-Forwarding Required):**
```bash
cd iot/scripts
./access-mosquitto.sh    # MQTT broker on localhost:1883 (TCP service)
```

**Access All Services (Port-Forwarding):**
```bash
# From project root
./access-all.sh
```

This starts port-forwards for TCP services and provides fallback access for HTTP services.

## Component Details

### Eclipse Mosquitto

- **Purpose**: MQTT broker for device connectivity
- **Port**: 1883 (MQTT), 9001 (WebSockets)
- **Configuration**: Configured to bridge messages to Hono
- **Access**: `./scripts/access-mosquitto.sh` then connect to `localhost:1883` (TCP service, requires port-forwarding)

### Eclipse Hono

- **Purpose**: Device connectivity gateway
- **Components**:
  - Device Registry (MongoDB)
  - MQTT Adapter
  - HTTP Adapter
- **Kafka Integration**: Publishes telemetry to `hono.telemetry.*` topics
- **Access**: http://hono.tailc2013b.ts.net (via Ingress) or port-forward fallback

### Eclipse Ditto

- **Purpose**: Digital twins and device abstraction APIs
- **Storage**: MongoDB for twin data
- **Kafka Integration**: Consumes from Kafka, provides REST APIs
- **APIs**:
  - Things API: `/api/2/things`
  - Policies API: `/api/2/policies`
  - Search API: `/api/2/search`
- **Access**: http://ditto.tailc2013b.ts.net/api (via Ingress) or port-forward fallback

### ThingsBoard CE

- **Purpose**: Dashboards, rules, device management
- **Storage**: PostgreSQL
- **Kafka Integration**: Consumes telemetry from Kafka
- **Default Credentials**:
  - Username: `sysadmin@thingsboard.org`
  - Password: `sysadmin` (change after first login)
- **Access**: http://thingsboard.tailc2013b.ts.net (via Ingress) or port-forward fallback

### PostgreSQL (ThingsBoard)

- **Purpose**: Database for ThingsBoard (stores telemetry and device data)
- **Storage**: 8Gi on Longhorn
- **Connection**: `postgresql-thingsboard.iot.svc.cluster.local:5432`
- **Credentials**: See `postgresql-thingsboard-values.yaml`
- **Note**: TimescaleDB extension can be added later if time-series optimizations are needed (see `iot/scripts/add-timescaledb-extension.sh`)

### Node-RED

- **Purpose**: Visual programming for automation
- **Storage**: 5Gi for flows and data
- **Integration**: Connect to ThingsBoard, Ditto, Kafka
- **Access**: http://nodered.tailc2013b.ts.net (via Ingress) or port-forward fallback

## Data Flow Configuration

### Mosquitto → Hono

Mosquitto is configured to bridge messages to Hono's MQTT adapter. The bridge configuration is in `mosquitto-values.yaml`.

### Hono → Kafka

Hono automatically publishes device telemetry to Kafka topics:
- Telemetry: `hono.telemetry.<tenant>.<device-id>`
- Events: `hono.event.<tenant>.<device-id>`

### Kafka → ThingsBoard

ThingsBoard can consume from Kafka or receive telemetry via HTTP/MQTT:
- Kafka topics: `tb-core`, `tb.rule-engine` (internal)
- Telemetry: Via HTTP API or MQTT integration
- Storage: PostgreSQL (device state + telemetry)
- Digital Twins: Device attributes (reported/desired state)

ThingsBoard consumes telemetry from Kafka topics configured in `thingsboard-values.yaml`.

## Verification

### Check Pod Status

```bash
kubectl get pods -n iot
```

All pods should be in `Running` state.

### Quick Status Check

```bash
cd iot/scripts
./iot-status-check.sh
```

This script provides a quick overview of all IoT stack components.

### Check Services

```bash
kubectl get svc -n iot
```

### Test MQTT Connection

```bash
# Using mosquitto_pub (install mosquitto-clients)
mosquitto_pub -h localhost -p 1883 -t test/topic -m "Hello World"

# Using mosquitto_sub
mosquitto_sub -h localhost -p 1883 -t test/topic
```

### Test Hono HTTP Adapter

```bash
curl -X POST http://localhost:8082/telemetry \
  -H "Content-Type: application/json" \
  -d '{"temperature": 25.5}'
```

### Test Ditto API

```bash
curl http://localhost:8083/api/2/things
```

### Test ThingsBoard

Open `http://localhost:9091` in your browser and login with default credentials.

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n iot

# Check pod logs
kubectl logs -n iot <pod-name>

# Describe pod for events
kubectl describe pod -n iot <pod-name>
```

### Longhorn Volume Issues

If pods are stuck in `Pending` or `Init` state due to volume issues:

1. **Check Longhorn Node Registration**:
   ```bash
   kubectl get nodes.longhorn.io -n longhorn-system
   ```
   All nodes should be registered. If a node is missing:
   - Check if Longhorn manager pod is running on that node
   - Verify `open-iscsi` is installed: `sudo apt-get install -y open-iscsi`
   - Restart Longhorn manager daemonset if needed

2. **Check Volume Status**:
   ```bash
   # Get PVC name
   kubectl get pvc -n iot
   
   # Get PV name from PVC
   PVC_NAME=<pvc-name>
   PV_NAME=$(kubectl get pvc -n iot $PVC_NAME -o jsonpath='{.spec.volumeName}')
   
   # Check Longhorn volume status
   kubectl get volume.longhorn.io -n longhorn-system $PV_NAME
   ```

3. **Volume Attachment Issues**:
   - If volume shows "detached" and pod is on unregistered node, reschedule pod:
     ```bash
     kubectl patch deployment -n iot <deployment-name> --type='json' \
       -p='[{"op": "add", "path": "/spec/template/spec/nodeSelector", \
       "value": {"kubernetes.io/hostname": "<known-node>"}}]'
     ```

### MongoDB Issues

#### MongoDB User Not Created

If MongoDB starts but Ditto/Hono can't authenticate:

1. **Check if user exists**:
   ```bash
   kubectl exec -n iot <mongodb-pod> -c mongodb -- \
     mongosh admin -u root -p <root-password> \
     --eval "db.getSiblingDB('ditto').getUsers()"
   ```

2. **Bitnami MongoDB only creates users on first initialization**:
   - If persistent data exists from previous deployment, users may not be created
   - Solution: Delete PVC and let MongoDB reinitialize:
     ```bash
     kubectl scale deployment -n iot mongodb-ditto --replicas=0
     kubectl delete pvc -n iot mongodb-ditto
     kubectl scale deployment -n iot mongodb-ditto --replicas=1
     ```

#### MongoDB Illegal Instruction Error

If MongoDB pod crashes with exit code 132 (Illegal instruction):

- This indicates a CPU architecture mismatch or corrupted binary
- Solution: Reschedule pod to a different node:
  ```bash
  kubectl patch deployment -n iot mongodb-ditto --type='json' \
    -p='[{"op": "add", "path": "/spec/template/spec/nodeSelector", \
    "value": {"kubernetes.io/hostname": "<working-node>"}}]'
  ```

### Ditto Health Issues

If Ditto health shows "DOWN":

1. **Check MongoDB connection**:
   ```bash
   kubectl logs -n iot <ditto-policies-pod> | grep -i mongo
   kubectl logs -n iot <ditto-things-pod> | grep -i mongo
   ```

2. **Verify MongoDB service**:
   ```bash
   kubectl get svc -n iot | grep mongodb
   # Ditto expects service name: ditto-mongodb
   # If service is mongodb-ditto, create alias:
   kubectl apply -f iot/k8s/ditto-mongodb-service.yaml
   ```

3. **Check all Ditto services**:
   ```bash
   kubectl get pods -n iot | grep ditto
   # All services should be Running
   ```

4. **Restart Ditto services**:
   ```bash
   kubectl delete pod -n iot <ditto-policies-pod>
   kubectl delete pod -n iot <ditto-things-pod>
   kubectl delete pod -n iot <ditto-connectivity-pod>
   ```

### Database Connection Issues

```bash
# Check database pods
kubectl get pods -n iot | grep -E "mongodb|postgresql|timescaledb"

# Check database logs
kubectl logs -n iot <database-pod-name>

# Verify service endpoints
kubectl get endpoints -n iot
```

### Kafka Connectivity Issues

```bash
# Verify Kafka is accessible from iot namespace
kubectl run kafka-test --rm -i --restart=Never \
  --image=quay.io/strimzi/kafka:latest-kafka-4.1.1 \
  -n iot \
  -- bin/kafka-broker-api-versions.sh \
  --bootstrap-server kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
```

### Storage Issues

```bash
# Check PVCs
kubectl get pvc -n iot

# Check PVs
kubectl get pv | grep iot

# Check storage class
kubectl get storageclass longhorn

# Debug Longhorn volumes (from project root)
cd cluster/scripts
./debug-longhorn-volumes.sh
```

### Service Access Issues

```bash
# Check services
kubectl get svc -n iot

# Check port-forward
kubectl get pods -n iot -l app=node-red
lsof -i :1880  # Check if port is in use

# Check IoT stack status
cd iot/scripts
./iot-status-check.sh
```

## Security Considerations

### Production Deployment

For production, you should:

1. **Change Default Passwords**:
   - Update all database passwords in values files
   - Change ThingsBoard default credentials
   - Set strong credentials for all services

2. **Enable Authentication**:
   - Enable Mosquitto authentication
   - Enable Ditto authentication
   - Configure Kafka security (TLS/SASL)

3. **Network Policies**:
   - Implement network policies to restrict inter-pod communication
   - Limit external access

4. **TLS/SSL**:
   - Enable TLS for all services
   - Use cert-manager for certificate management

5. **Secrets Management**:
   - Use Kubernetes Secrets instead of plain text in values files
   - Consider using external secret management (e.g., Sealed Secrets, Vault)

## Monitoring

### Resource Usage

```bash
# Check resource usage
kubectl top pods -n iot
kubectl top nodes
```

### Logs

```bash
# View logs for all pods
kubectl logs -n iot -l app=mosquitto
kubectl logs -n iot -l app=hono
kubectl logs -n iot -l app=ditto
kubectl logs -n iot -l app=thingsboard
kubectl logs -n iot -l app=node-red
```

## Scaling

### Scale Components

```bash
# Scale Hono adapters
kubectl scale deployment hono-mqtt-adapter -n iot --replicas=3

# Scale Ditto services
kubectl scale deployment ditto-services -n iot --replicas=2

# Scale ThingsBoard
kubectl scale deployment thingsboard -n iot --replicas=2
```

### Database Scaling

For production, consider:
- MongoDB replica sets
- PostgreSQL read replicas
- TimescaleDB high availability

## Backup and Recovery

### Database Backups

```bash
# Backup TimescaleDB
kubectl exec -n iot <timescaledb-pod> -- pg_dump -U timescaledb timescaledb > backup.sql

# Backup MongoDB
kubectl exec -n iot <mongodb-pod> -- mongodump --out /backup

# Backup PostgreSQL
kubectl exec -n iot <postgresql-pod> -- pg_dump -U thingsboard thingsboard > backup.sql
```

### PVC Backups

Use Longhorn's built-in backup features or snapshot capabilities.

## Additional Resources

- [Eclipse Hono Documentation](https://www.eclipse.org/hono/)
- [Eclipse Ditto Documentation](https://www.eclipse.org/ditto/)
- [ThingsBoard Documentation](https://thingsboard.io/docs/)
- [TimescaleDB Documentation](https://docs.timescale.com/)
- [Node-RED Documentation](https://nodered.org/docs/)
- [Eclipse Mosquitto Documentation](https://mosquitto.org/documentation/)

## Support

For issues specific to this deployment:
1. Check the troubleshooting section above
2. Review component logs
3. Verify Kafka connectivity
4. Check resource availability

For component-specific issues, refer to the official documentation for each component.

## Known Issues

### MongoDB Ditto Illegal Instruction

- **Status**: MongoDB Ditto pod may crash with exit code 132 on certain nodes
- **Impact**: Ditto health remains UP (services connect to MongoDB Hono or use cached connections)
- **Workaround**: Reschedule MongoDB Ditto to a different node if needed
- **Tracking**: Monitor MongoDB Ditto pod status

### Node Registration Requirements

- All Kubernetes nodes must have `open-iscsi` installed for Longhorn to work
- If a node is not registered in Longhorn, volumes cannot attach to pods on that node
- Install: `sudo apt-get install -y open-iscsi && sudo systemctl enable iscsid && sudo systemctl start iscsid`

---

**Last Updated**: November 2024  
**Kubernetes Version**: v1.33.6+rke2r1  
**Namespace**: `iot`  
**Project Structure**: Files organized in `iot/k8s/` and `iot/scripts/` directories

