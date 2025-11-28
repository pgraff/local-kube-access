# IoT Stack Status Report

**Date:** November 28, 2025  
**Status:** ✅ Simplified and Operational

## Component Status

### ✅ Working Components

| Component | Status | Notes |
|-----------|--------|-------|
| **Mosquitto** | ✅ Running | MQTT broker operational |
| **Hono Adapters** | ✅ Running | MQTT, HTTP, AMQP adapters working |
| **Hono Services** | ✅ Running | Auth, Command Router, Device Registry running |
| **ThingsBoard** | ✅ Running | Dashboard, device management, and digital twin functionality |
| **Node-RED** | ✅ Running | Automation platform working |
| **PostgreSQL (ThingsBoard)** | ✅ Running | Database for ThingsBoard (handles telemetry storage) |
| **MongoDB (Hono)** | ✅ Running | Device registry for Hono |

## Architecture Changes

### Removed Components

| Component | Reason | Replacement |
|-----------|--------|-------------|
| **TimescaleDB** | Not integrated, causing issues | ThingsBoard PostgreSQL |
| **Twin Service** | Deployment complexity | ThingsBoard device attributes |
| **Ditto** | Complex, multiple microservices | ThingsBoard (removed earlier) |

### Current Stack

```
Devices → Mosquitto → Hono → Kafka → ThingsBoard → PostgreSQL
                                              │
                                              ├──> REST API (digital twin)
                                              ├──> Dashboards
                                              └──> Rules Engine
```

## Digital Twin Functionality

**ThingsBoard provides digital twin capabilities via:**
- **Device Attributes** - Server-side (desired) and client-side (reported) state
- **REST API** - Full API for device state queries and updates
- **Rules Engine** - React to state changes automatically
- **Telemetry Storage** - PostgreSQL backend

See: `iot/docs/thingsboard-as-digital-twin.md` for details.

## Access

### Primary Access (Tailscale URLs)
- **ThingsBoard:** http://thingsboard.tailc2013b.ts.net
- **Node-RED:** http://nodered.tailc2013b.ts.net
- **Hono:** http://hono.tailc2013b.ts.net

### Fallback Access (Port-Forward)
```bash
./access-all.sh
# Or individual:
kubectl port-forward -n iot service/thingsboard 9090:9090
```

## Expected Components

1. ✅ **Mosquitto** - MQTT broker
2. ✅ **Hono** - Device connectivity gateway
   - ✅ MQTT Adapter
   - ✅ HTTP Adapter
   - ✅ AMQP Adapter
   - ✅ Device Registry
   - ✅ MongoDB (for device registry)
3. ✅ **ThingsBoard** - Dashboards, device management, digital twins
4. ✅ **Node-RED** - Automation
5. ✅ **PostgreSQL** - For ThingsBoard (telemetry storage)
6. ✅ **MongoDB** - For Hono device registry

## Known Issues

None currently. All components are operational.

## Recommendations

### Next Steps

1. **Configure ThingsBoard:**
   - Access: http://thingsboard.tailc2013b.ts.net
   - Login: sysadmin@thingsboard.org / sysadmin
   - Create devices
   - Set up rules for automation

2. **Use ThingsBoard REST API:**
   - See: `iot/docs/thingsboard-as-digital-twin.md`
   - Device attributes for twin state
   - Telemetry API for data queries

3. **Monitor Stack:**
   ```bash
   ./iot/scripts/iot-status-check.sh
   ```

## Troubleshooting

### ThingsBoard Not Accessible

1. Check pod status: `kubectl get pods -n iot -l app=thingsboard`
2. Check service: `kubectl get svc -n iot thingsboard`
3. Check logs: `kubectl logs -n iot -l app=thingsboard --tail=50`
4. Verify Tailscale: `tailscale status`
5. Check /etc/hosts: `grep thingsboard /etc/hosts`

### Kafka Integration

ThingsBoard is configured with Kafka:
- `TB_QUEUE_TYPE: "kafka"`
- `TB_KAFKA_SERVERS: "kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"`

If Kafka connectivity issues occur, check:
- Kafka cluster status: `kubectl get pods -n kafka`
- ThingsBoard logs for Kafka connection errors

## Related Documentation

- **Setup Guide:** `iot/docs/iot-setup-guide.md`
- **ThingsBoard as Twin:** `iot/docs/thingsboard-as-digital-twin.md`
- **Simplification Summary:** `iot/docs/STACK-SIMPLIFICATION-SUMMARY.md`
