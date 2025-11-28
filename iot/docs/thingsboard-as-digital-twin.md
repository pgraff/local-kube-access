# Using ThingsBoard as Digital Twin Platform

**Date:** November 28, 2025  
**Status:** ✅ Recommended Approach

## Overview

Instead of deploying a separate digital twin service (Ditto or custom Twin Service), we're using **ThingsBoard's built-in capabilities** to handle digital twin functionality. This simplifies the stack significantly.

## Why ThingsBoard?

✅ **Already Deployed** - No additional services needed  
✅ **Device State Management** - Built-in reported/desired attributes  
✅ **Telemetry Storage** - PostgreSQL backend  
✅ **REST API** - Full API for device queries and updates  
✅ **Rules Engine** - React to state changes automatically  
✅ **Dashboards** - Built-in visualization  
✅ **Kafka Integration** - Consumes from Kafka topics  

## Architecture

```
Devices → Mosquitto → Hono → Kafka (hono.telemetry)
                                    ↓
                            ThingsBoard
                                    ↓
                    PostgreSQL (device state + telemetry)
                                    ↓
                    REST API / Dashboards / Rules
```

## Configuration

### Kafka Integration

ThingsBoard is configured to use Kafka for message queuing:

```yaml
TB_QUEUE_TYPE: "kafka"
TB_KAFKA_SERVERS: "kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
TB_KAFKA_TOPIC_PREFIX: "tb"
```

### Topics

ThingsBoard uses these Kafka topics:
- `tb-core` - Core messages
- `tb-core-notifications` - Notifications
- `tb.rule-engine` - Rule engine messages
- `tb.transport.*` - Transport layer messages

## Using ThingsBoard as Digital Twin

### 1. Device Attributes (Twin State)

ThingsBoard uses **device attributes** to represent twin state:

- **Server-side attributes** = Desired state (what you want)
- **Client-side attributes** = Reported state (what device reports)
- **Shared attributes** = Shared between server and device

### 2. REST API for Twin Operations

#### Get Device Twin State

```bash
# Get device attributes (twin state)
curl -X GET \
  "http://thingsboard.iot.svc.cluster.local:9090/api/plugins/telemetry/DEVICE/{deviceId}/values/attributes" \
  -H "X-Authorization: Bearer {jwt_token}"
```

#### Update Desired State

```bash
# Update desired state (server-side attributes)
curl -X POST \
  "http://thingsboard.iot.svc.cluster.local:9090/api/plugins/telemetry/DEVICE/{deviceId}/attributes/SERVER_SCOPE" \
  -H "X-Authorization: Bearer {jwt_token}" \
  -H "Content-Type: application/json" \
  -d '{
    "desiredTemperature": 22,
    "desiredMode": "auto"
  }'
```

#### Get Latest Telemetry

```bash
# Get latest telemetry values
curl -X GET \
  "http://thingsboard.iot.svc.cluster.local:9090/api/plugins/telemetry/DEVICE/{deviceId}/values/timeseries" \
  -H "X-Authorization: Bearer {jwt_token}"
```

### 3. Rules Engine (Automation)

ThingsBoard's rules engine can react to:
- Device telemetry changes
- Attribute updates
- Device events
- Time-based triggers

Example: React to temperature change and update desired state.

### 4. Device Management

- Create devices via REST API
- Manage device credentials
- View device dashboards
- Monitor device status

## Data Flow

### Telemetry from Hono

1. Device sends MQTT → Mosquitto
2. Mosquitto → Hono
3. Hono → Kafka (`hono.telemetry.*`)
4. ThingsBoard consumes from Kafka (if configured)
5. ThingsBoard stores in PostgreSQL

**Note:** To have ThingsBoard consume directly from Hono topics, you may need to:
- Configure ThingsBoard Kafka integration
- Or use ThingsBoard's HTTP API to push telemetry
- Or use ThingsBoard's MQTT integration

### Recommended: Use ThingsBoard HTTP API

Instead of consuming from Kafka, have Hono push to ThingsBoard:

```yaml
# In Hono configuration
# Add HTTP endpoint to forward to ThingsBoard
```

Or use ThingsBoard's MQTT integration to receive directly from Mosquitto.

## Accessing ThingsBoard

### Web UI (Recommended - via Tailscale)

```bash
# Direct access via Tailscale (configured in /etc/hosts)
# Access at: http://thingsboard.tailc2013b.ts.net
# Default credentials: sysadmin@thingsboard.org / sysadmin
```

**Note:** If `/etc/hosts` is configured with `100.68.247.112 thingsboard.tailc2013b.ts.net`, you can access ThingsBoard directly without port-forwarding.

### Web UI (Fallback - Port-Forward)

```bash
# Port-forward (if Tailscale access not available)
kubectl port-forward -n iot service/thingsboard 9090:9090

# Access at: http://localhost:9090
# Default credentials: sysadmin@thingsboard.org / sysadmin
```

### REST API

**Via Tailscale (Recommended):**
```bash
# Get JWT token
curl -X POST \
  "http://thingsboard.tailc2013b.ts.net/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "sysadmin@thingsboard.org",
    "password": "sysadmin"
  }'
```

**Via Port-Forward (Fallback):**
```bash
# Get JWT token
curl -X POST \
  "http://localhost:9090/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "sysadmin@thingsboard.org",
    "password": "sysadmin"
  }'
```

**From within cluster:**
```bash
# Internal cluster DNS
curl -X POST \
  "http://thingsboard.iot.svc.cluster.local:9090/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "sysadmin@thingsboard.org",
    "password": "sysadmin"
  }'
```

## Advantages Over Separate Twin Service

| Feature | ThingsBoard | Separate Twin Service |
|---------|-------------|----------------------|
| **Deployment** | ✅ Already running | ❌ Need to deploy |
| **UI** | ✅ Built-in dashboards | ❌ Need to build |
| **Rules** | ✅ Built-in engine | ❌ Need to implement |
| **Storage** | ✅ PostgreSQL | ⚠️ Need separate DB |
| **API** | ✅ Full REST API | ⚠️ Need to build |
| **Maintenance** | ✅ One service | ⚠️ Multiple services |

## Migration from Twin Service

If you were using a separate twin service:

1. **Device State** → Use ThingsBoard device attributes
2. **REST API** → Use ThingsBoard REST API
3. **State Queries** → Use ThingsBoard telemetry/attributes API
4. **Automation** → Use ThingsBoard rules engine

## Next Steps

1. ✅ ThingsBoard is configured with Kafka
2. Configure ThingsBoard to consume from `hono.telemetry` topics (or use HTTP API)
3. Create devices in ThingsBoard
4. Use ThingsBoard REST API for twin operations
5. Set up rules for automation

## Resources

- [ThingsBoard REST API Documentation](https://thingsboard.io/docs/reference/rest-api/)
- [ThingsBoard Device Attributes](https://thingsboard.io/docs/user-guide/attributes/)
- [ThingsBoard Rules Engine](https://thingsboard.io/docs/user-guide/rule-engine-2-0/overview/)

