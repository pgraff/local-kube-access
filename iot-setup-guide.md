# IoT Stack Setup Guide

## Overview

This guide covers the deployment and configuration of a complete IoT platform stack in the `iot` namespace. The stack integrates with your existing Kafka cluster and provides a full pipeline from device connectivity to visualization and automation.

## Architecture

```
Home Devices → Mosquitto → Hono → Kafka → TimescaleDB
                                    │
                                    ├──> Ditto (Digital Twins) → APIs
                                    │
                                    └──> ThingsBoard CE → Node-RED
```

### Component Flow

1. **Eclipse Mosquitto** - MQTT broker receives messages from IoT devices
2. **Eclipse Hono** - Device connectivity gateway that processes MQTT messages and forwards to Kafka
3. **Apache Kafka** - Message broker (already deployed in `kafka` namespace)
4. **TimescaleDB** - Time-series database for telemetry storage
5. **Eclipse Ditto** - Digital twins platform consuming from Kafka
6. **ThingsBoard CE** - Dashboards, rules, and device management
7. **Node-RED** - Visual programming for automation

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
./deploy-iot-stack.sh
```

This script will:
1. Create the `iot` namespace
2. Add all required Helm repositories
3. Deploy all databases (TimescaleDB, MongoDB, PostgreSQL)
4. Deploy all IoT components (Mosquitto, Hono, Ditto, ThingsBoard, Node-RED)
5. Configure integrations

### Uninstall Everything

```bash
# Remove the complete IoT stack
./uninstall-iot-stack.sh
```

## Manual Deployment Steps

If you prefer to deploy components individually:

### 1. Create Namespace

```bash
kubectl apply -f iot-namespace.yaml
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
# TimescaleDB
helm install timescaledb timescale/timescaledb-single \
  -n iot -f timescaledb-values.yaml --wait

# MongoDB for Hono
helm install mongodb-hono bitnami/mongodb \
  -n iot -f mongodb-hono-values.yaml --wait

# MongoDB for Ditto
helm install mongodb-ditto bitnami/mongodb \
  -n iot -f mongodb-ditto-values.yaml --wait

# PostgreSQL for ThingsBoard
helm install postgresql-thingsboard bitnami/postgresql \
  -n iot -f postgresql-thingsboard-values.yaml --wait
```

### 4. Deploy IoT Components

```bash
# Mosquitto
helm install mosquitto cloudnesil/eclipse-mosquitto-mqtt-broker-helm-chart \
  -n iot -f mosquitto-values.yaml --wait

# Hono
helm install hono eclipse-iot/hono \
  -n iot -f hono-values.yaml --wait

# Ditto
helm install ditto atnog/ditto-helm-chart \
  -n iot -f ditto-values.yaml --wait

# ThingsBoard
helm install thingsboard thingsboard/thingsboard \
  -n iot -f thingsboard-values.yaml --wait

# Node-RED
kubectl apply -f nodered-deployment.yaml -n iot
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

### Port-Forwarding Scripts

Individual service access:

```bash
./access-mosquitto.sh    # MQTT broker on localhost:1883
./access-hono.sh         # Hono HTTP adapter on localhost:8082
./access-ditto.sh        # Ditto API on localhost:8083
./access-thingsboard.sh  # ThingsBoard on localhost:9091
./access-nodered.sh      # Node-RED on localhost:1880
```

### Access All Services

```bash
./access-all.sh
```

This starts port-forwards for all services including IoT stack.

## Component Details

### Eclipse Mosquitto

- **Purpose**: MQTT broker for device connectivity
- **Port**: 1883 (MQTT), 9001 (WebSockets)
- **Configuration**: Configured to bridge messages to Hono
- **Access**: `./access-mosquitto.sh` then connect to `localhost:1883`

### Eclipse Hono

- **Purpose**: Device connectivity gateway
- **Components**:
  - Device Registry (MongoDB)
  - MQTT Adapter
  - HTTP Adapter
- **Kafka Integration**: Publishes telemetry to `hono.telemetry.*` topics
- **Access**: `./access-hono.sh` then `http://localhost:8082`

### Eclipse Ditto

- **Purpose**: Digital twins and device abstraction APIs
- **Storage**: MongoDB for twin data
- **Kafka Integration**: Consumes from Kafka, provides REST APIs
- **APIs**:
  - Things API: `/api/2/things`
  - Policies API: `/api/2/policies`
  - Search API: `/api/2/search`
- **Access**: `./access-ditto.sh` then `http://localhost:8083/api`

### ThingsBoard CE

- **Purpose**: Dashboards, rules, device management
- **Storage**: PostgreSQL
- **Kafka Integration**: Consumes telemetry from Kafka
- **Default Credentials**:
  - Username: `sysadmin@thingsboard.org`
  - Password: `sysadmin` (change after first login)
- **Access**: `./access-thingsboard.sh` then `http://localhost:9091`

### TimescaleDB

- **Purpose**: Time-series database for telemetry storage
- **Storage**: 100Gi on Longhorn
- **Connection**: `timescaledb.iot.svc.cluster.local:5432`
- **Credentials**: See `timescaledb-values.yaml`

### Node-RED

- **Purpose**: Visual programming for automation
- **Storage**: 5Gi for flows and data
- **Integration**: Connect to ThingsBoard, Ditto, Kafka
- **Access**: `./access-nodered.sh` then `http://localhost:1880`

## Data Flow Configuration

### Mosquitto → Hono

Mosquitto is configured to bridge messages to Hono's MQTT adapter. The bridge configuration is in `mosquitto-values.yaml`.

### Hono → Kafka

Hono automatically publishes device telemetry to Kafka topics:
- Telemetry: `hono.telemetry.<tenant>.<device-id>`
- Events: `hono.event.<tenant>.<device-id>`

### Kafka → TimescaleDB

Set up a Kafka consumer to ingest telemetry into TimescaleDB. You can use:
- Kafka Connect with TimescaleDB connector
- Custom consumer application
- ThingsBoard's built-in integration

### Kafka → Ditto

Ditto consumes from Kafka topics configured in `ditto-values.yaml`:
- Things: `ditto.things`
- Policies: `ditto.policies`
- Search: `ditto.search`

### Kafka → ThingsBoard

ThingsBoard consumes telemetry from Kafka topics configured in `thingsboard-values.yaml`.

## Verification

### Check Pod Status

```bash
kubectl get pods -n iot
```

All pods should be in `Running` state.

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
```

### Service Access Issues

```bash
# Check services
kubectl get svc -n iot

# Check port-forward
kubectl get pods -n iot -l app=node-red
lsof -i :1880  # Check if port is in use
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

---

**Last Updated**: December 2024  
**Kubernetes Version**: v1.33.6+rke2r1  
**Namespace**: `iot`

