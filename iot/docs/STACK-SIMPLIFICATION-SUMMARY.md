# IoT Stack Simplification Summary

**Date:** November 28, 2025  
**Status:** ✅ Complete

## Overview

We've simplified the IoT stack by removing complex components that were causing issues and leveraging existing services that already provide the needed functionality.

## What Was Removed

### 1. TimescaleDB
- **Reason:** Not actually integrated, causing persistent volume issues
- **Replacement:** ThingsBoard's PostgreSQL (already deployed and working)
- **Benefit:** One less database to maintain, 110Gi storage freed

### 2. Twin Service (Custom Kafka Streams)
- **Reason:** Deployment complexity, image registry issues, not needed
- **Replacement:** ThingsBoard's built-in device attributes and state management
- **Benefit:** No custom code to maintain, built-in UI and API

### 3. Ditto (Eclipse Ditto)
- **Reason:** Complex deployment, multiple microservices, MongoDB dependency
- **Replacement:** ThingsBoard (removed earlier)
- **Benefit:** Simpler architecture

## Current Stack

```
Devices → Mosquitto → Hono → Kafka → ThingsBoard → PostgreSQL
                                              │
                                              ├──> REST API
                                              ├──> Dashboards
                                              └──> Rules Engine
```

### Components

1. **Mosquitto** - MQTT broker
2. **Hono** - Device connectivity gateway
3. **Kafka** - Message broker
4. **ThingsBoard** - Digital twin, dashboards, rules, device management
5. **PostgreSQL** - Storage (for ThingsBoard)
6. **MongoDB** - Storage (for Hono device registry)
7. **Node-RED** - Automation and workflows

## Key Changes

### ThingsBoard Configuration

Updated to use Kafka for message queuing:

```yaml
TB_QUEUE_TYPE: "kafka"
TB_KAFKA_SERVERS: "kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
TB_KAFKA_TOPIC_PREFIX: "tb"
```

### Digital Twin Functionality

ThingsBoard provides digital twin capabilities via:
- **Device Attributes** - Server-side (desired) and client-side (reported)
- **REST API** - Full API for device state queries and updates
- **Rules Engine** - React to state changes automatically
- **Telemetry Storage** - PostgreSQL backend

See: `iot/docs/thingsboard-as-digital-twin.md` for details.

## Benefits

✅ **Simpler Architecture**
- Fewer components to deploy and maintain
- Less complexity in troubleshooting

✅ **More Reliable**
- Using battle-tested components
- No custom code to debug

✅ **Better Resource Usage**
- 110Gi storage freed (TimescaleDB)
- Fewer pods running
- Lower resource overhead

✅ **Easier to Operate**
- One service (ThingsBoard) handles multiple functions
- Built-in UI and API
- Better documentation

## Migration Notes

### From TimescaleDB
- Telemetry storage: Use ThingsBoard's PostgreSQL
- Time-series queries: Use ThingsBoard's telemetry API
- If needed later: Add TimescaleDB extension to PostgreSQL

### From Twin Service
- Device state: Use ThingsBoard device attributes
- REST API: Use ThingsBoard REST API
- State queries: Use ThingsBoard telemetry/attributes endpoints

### From Ditto
- Digital twins: Use ThingsBoard device attributes
- Policies: Use ThingsBoard rules engine
- APIs: Use ThingsBoard REST API

## Documentation

- **Main Guide:** `iot/docs/iot-setup-guide.md`
- **ThingsBoard as Twin:** `iot/docs/thingsboard-as-digital-twin.md`
- **Deployment Script:** `iot/scripts/deploy-iot-stack.sh`

## Next Steps

1. ✅ Stack simplified and running
2. Configure ThingsBoard to consume from Hono/Kafka
3. Create devices in ThingsBoard
4. Set up rules for automation
5. Build dashboards for visualization

## Access

### ThingsBoard UI (Recommended)
```bash
# Direct access via Tailscale (configured in /etc/hosts)
# Access: http://thingsboard.tailc2013b.ts.net
# Login: sysadmin@thingsboard.org / sysadmin
```

### ThingsBoard UI (Fallback - Port-Forward)
```bash
kubectl port-forward -n iot service/thingsboard 9090:9090
# Access: http://localhost:9090
# Login: sysadmin@thingsboard.org / sysadmin
```

### ThingsBoard REST API
```bash
# Via Tailscale (recommended)
curl -X POST http://thingsboard.tailc2013b.ts.net/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"sysadmin@thingsboard.org","password":"sysadmin"}'

# Via Port-Forward (fallback)
curl -X POST http://localhost:9090/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"sysadmin@thingsboard.org","password":"sysadmin"}'
```

## Conclusion

The simplified stack is more maintainable, reliable, and easier to operate. All functionality is preserved while reducing complexity significantly.

