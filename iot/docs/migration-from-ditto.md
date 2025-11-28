# Migration from Ditto to Kafka-Based Twin Service

**Date:** November 27, 2025  
**Status:** In Progress

## Overview

This document describes the migration from Eclipse Ditto to a custom Kafka-based digital twin service.

## Why Migrate?

- **Simpler Architecture:** Single service vs. multiple microservices
- **No MongoDB Dependency:** Uses Kafka Streams state store
- **Better Resource Usage:** Lower memory and CPU requirements
- **Easier Operations:** Single service to deploy and monitor
- **Full Control:** Build exactly what you need

## Migration Steps

### Step 1: Clean Up Ditto

Run the cleanup script to remove Ditto and MongoDB for Ditto:

```bash
cd iot/scripts
./cleanup-ditto.sh
```

This will:
- Uninstall Ditto Helm release
- Remove all Ditto deployments and services
- Uninstall MongoDB for Ditto Helm release
- Optionally delete MongoDB for Ditto PVC (20Gi)

**What Gets Removed:**
- ✅ Ditto Helm release
- ✅ All Ditto deployments (connectivity, things, gateway, etc.)
- ✅ MongoDB for Ditto
- ✅ Ditto ConfigMaps and Secrets
- ✅ Ditto jobs and cronjobs

**What Stays:**
- ✅ Mosquitto
- ✅ Hono
- ✅ ThingsBoard
- ✅ Node-RED
- ✅ TimescaleDB
- ✅ PostgreSQL for ThingsBoard
- ✅ MongoDB for Hono

### Step 2: Build Twin Service

The twin service is a Spring Boot application using Kafka Streams.

**Project Location:** `iot/twin-service/`

**Key Components:**
- Kafka Streams processor (maintains twin state)
- REST API (query/update twins)
- State store (Kafka Streams built-in)

**See:** `iot/docs/kafka-twin-service-recommendation.md` for implementation details.

### Step 3: Deploy Twin Service

Once the twin service is built and containerized:

```bash
cd iot/scripts
./deploy-twin-service.sh
```

This will:
- Deploy the twin service to Kubernetes
- Configure Kafka connection
- Set up ingress (if configured)
- Wait for service to be ready

### Step 4: Update Integrations

Update any services that were using Ditto:

**ThingsBoard:**
- Update device integration to use twin service API
- Change API endpoints from Ditto to twin service

**Node-RED:**
- Update flows that query Ditto
- Change HTTP nodes to point to twin service

**Custom Applications:**
- Update API endpoints
- Adjust data models if needed

### Step 5: Verify and Monitor

1. **Test Twin Service:**
   ```bash
   # Get all twins
   curl http://twin-service.iot.svc.cluster.local:8080/api/v1/twins
   
   # Get specific twin
   curl http://twin-service.iot.svc.cluster.local:8080/api/v1/twins/{deviceId}
   ```

2. **Monitor Logs:**
   ```bash
   kubectl logs -n iot -l app=twin-service --tail=50 -f
   ```

3. **Check Metrics:**
   ```bash
   kubectl get pods -n iot -l app=twin-service
   kubectl top pods -n iot -l app=twin-service
   ```

## API Compatibility

### Ditto API vs Twin Service API

**Ditto:**
```
GET /api/2/things/{thingId}
PATCH /api/2/things/{thingId}
```

**Twin Service:**
```
GET /api/v1/twins/{deviceId}
PATCH /api/v1/twins/{deviceId}/desired
```

**Migration Notes:**
- Endpoint paths are different
- Some Ditto features may not be available initially
- Can add compatibility layer if needed

## Rollback Plan

If you need to rollback:

1. **Stop Twin Service:**
   ```bash
   kubectl scale deployment twin-service -n iot --replicas=0
   ```

2. **Redeploy Ditto:**
   ```bash
   cd iot/scripts
   # Restore from backup or redeploy
   helm install ditto atnog/ditto -n iot -f ../k8s/ditto-values.yaml
   helm install mongodb-ditto bitnami/mongodb -n iot -f ../k8s/mongodb-ditto-values.yaml
   ```

3. **Restore Data:**
   - If you kept the MongoDB PVC, data may still be there
   - Otherwise, restore from backup

## Current Status

- ✅ Cleanup script created
- ✅ Twin service deployment files created
- ✅ Documentation created
- ⏳ Twin service implementation (in progress)
- ⏳ Cleanup execution (pending)
- ⏳ Twin service deployment (pending)
- ⏳ Integration updates (pending)

## Next Steps

1. **Review and Run Cleanup:**
   ```bash
   ./iot/scripts/cleanup-ditto.sh
   ```

2. **Build Twin Service:**
   - Follow `kafka-twin-service-recommendation.md`
   - Implement MVP features
   - Build Docker image

3. **Deploy and Test:**
   ```bash
   ./iot/scripts/deploy-twin-service.sh
   ```

4. **Update Integrations:**
   - Update ThingsBoard
   - Update Node-RED flows
   - Update any custom apps

5. **Monitor and Iterate:**
   - Monitor performance
   - Add features as needed
   - Optimize as required

## Resources

- **Twin Service Implementation Guide:** `iot/docs/kafka-twin-service-recommendation.md`
- **Ditto Alternatives Analysis:** `iot/docs/ditto-alternatives-analysis.md`
- **Cleanup Script:** `iot/scripts/cleanup-ditto.sh`
- **Deploy Script:** `iot/scripts/deploy-twin-service.sh`

