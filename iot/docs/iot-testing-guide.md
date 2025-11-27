# IoT Stack Testing Guide

This guide provides comprehensive testing procedures for verifying that your IoT stack is working correctly.

## Quick Test

Run the automated test script:

```bash
./test-iot-stack.sh
```

This will test all components and their integrations automatically.

## Manual Testing Procedures

### 1. Test Mosquitto MQTT Broker

**From within the cluster:**
```bash
# Subscribe to a topic
kubectl run mqtt-sub --rm -i --restart=Never \
  --image=eclipse-mosquitto:2.0 -n iot \
  -- mosquitto_sub -h mosquitto.iot.svc.cluster.local -p 1883 -t test/topic

# In another terminal, publish a message
kubectl run mqtt-pub --rm -i --restart=Never \
  --image=eclipse-mosquitto:2.0 -n iot \
  -- mosquitto_pub -h mosquitto.iot.svc.cluster.local -p 1883 -t test/topic -m "Hello IoT"
```

**From your local machine (via port-forward):**
```bash
# Start port-forward
./access-mosquitto.sh &
# Or: kubectl port-forward -n iot svc/mosquitto 1883:1883 &

# Test with mosquitto clients (if installed)
mosquitto_sub -h localhost -p 1883 -t test/topic &
mosquitto_pub -h localhost -p 1883 -t test/topic -m "Hello from local machine"
```

### 2. Test Eclipse Ditto API

**Test Ditto Gateway:**
```bash
# Test API endpoint (should return 401 - auth required, but service is up)
kubectl run ditto-test --rm -i --restart=Never \
  --image=curlimages/curl:latest -n iot \
  -- curl -v http://ditto-gateway.iot.svc.cluster.local:8080/api/2/things
```

**From local machine:**
```bash
# Start port-forward
./access-ditto.sh &
# Or: kubectl port-forward -n iot svc/ditto-nginx 8083:8080 &

# Test API
curl http://localhost:8083/api/2/things
# Should return 401 (authentication required) or empty array if auth disabled
```

**Test Ditto UI:**
```bash
# Access via port-forward
./access-ditto.sh
# Then open: http://localhost:8083
```

### 3. Test Eclipse Hono

**Test Device Registry:**
```bash
# Check registry health
kubectl run hono-test --rm -i --restart=Never \
  --image=curlimages/curl:latest -n iot \
  -- curl http://hono-service-device-registry.iot.svc.cluster.local:8080/health
```

**Test MQTT Adapter:**
```bash
# Check adapter logs
kubectl logs -n iot -l app=hono-adapter-mqtt --tail=20
```

**Test HTTP Adapter:**
```bash
# Start port-forward
./access-hono.sh &
# Or: kubectl port-forward -n iot svc/hono-adapter-http 8082:8080 &

# Test telemetry endpoint
curl -X POST http://localhost:8082/telemetry \
  -H "Content-Type: application/json" \
  -d '{"temperature": 25.5, "humidity": 60}'
```

### 4. Test Kafka Integration

**Create a test topic:**
```bash
kubectl run kafka-test --rm -i --restart=Never \
  --image=quay.io/strimzi/kafka:latest-kafka-4.1.1 -n iot \
  -- bin/kafka-topics.sh \
  --bootstrap-server kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092 \
  --create --topic iot-test --partitions 3 --replication-factor 3
```

**Publish test message:**
```bash
kubectl run kafka-producer --rm -i --restart=Never \
  --image=quay.io/strimzi/kafka:latest-kafka-4.1.1 -n iot \
  -- bin/kafka-console-producer.sh \
  --bootstrap-server kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092 \
  --topic iot-test
# Type a message and press Enter, then Ctrl+D to exit
```

**Consume test message:**
```bash
kubectl run kafka-consumer --rm -i --restart=Never \
  --image=quay.io/strimzi/kafka:latest-kafka-4.1.1 -n iot \
  -- bin/kafka-console-consumer.sh \
  --bootstrap-server kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092 \
  --topic iot-test --from-beginning
```

**List topics:**
```bash
kubectl run kafka-list --rm -i --restart=Never \
  --image=quay.io/strimzi/kafka:latest-kafka-4.1.1 -n iot \
  -- bin/kafka-topics.sh \
  --bootstrap-server kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092 \
  --list
```

### 5. Test Database Connectivity

**TimescaleDB:**
```bash
kubectl run timescaledb-test --rm -i --restart=Never \
  --image=postgres:15 -n iot \
  -- psql -h timescaledb.iot.svc.cluster.local -U timescaledb -d timescaledb \
  -c "SELECT version();"
```

**PostgreSQL (ThingsBoard):**
```bash
kubectl run postgresql-test --rm -i --restart=Never \
  --image=postgres:15 -n iot \
  -- psql -h postgresql-thingsboard.iot.svc.cluster.local -U thingsboard -d thingsboard \
  -c "SELECT version();"
```

**MongoDB (Ditto):**
```bash
kubectl run mongodb-test --rm -i --restart=Never \
  --image=mongo:7 -n iot \
  -- mongosh mongodb://mongodb-ditto.iot.svc.cluster.local:27017/ditto \
  --eval "db.adminCommand('ping')"
```

### 6. End-to-End Data Flow Test

**Complete Pipeline: Device → Mosquitto → Hono → Kafka → Ditto**

1. **Publish telemetry via MQTT to Mosquitto:**
```bash
kubectl run device-simulator --rm -i --restart=Never \
  --image=eclipse-mosquitto:2.0 -n iot \
  -- mosquitto_pub -h mosquitto.iot.svc.cluster.local -p 1883 \
  -t telemetry/device001 -m '{"temperature": 22.5, "humidity": 55}'
```

2. **Check if message reached Kafka:**
```bash
kubectl run kafka-check --rm -i --restart=Never \
  --image=quay.io/strimzi/kafka:latest-kafka-4.1.1 -n iot \
  -- bin/kafka-console-consumer.sh \
  --bootstrap-server kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092 \
  --topic hono.telemetry.* --from-beginning --max-messages 1
```

3. **Check Ditto for digital twin updates:**
```bash
# Via Ditto API (if authentication is configured)
curl http://localhost:8083/api/2/things
```

### 7. Test ThingsBoard (when ready)

**Access ThingsBoard:**
```bash
./access-thingsboard.sh
# Then open: http://localhost:9091
# Default credentials: sysadmin@thingsboard.org / sysadmin
```

**Test ThingsBoard API:**
```bash
# Get auth token
TOKEN=$(curl -X POST http://localhost:9091/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"sysadmin@thingsboard.org","password":"sysadmin"}' \
  | jq -r '.token')

# Get devices
curl -H "X-Authorization: Bearer $TOKEN" \
  http://localhost:9091/api/tenant/devices
```

### 8. Test Node-RED (when ready)

**Access Node-RED:**
```bash
./access-nodered.sh
# Then open: http://localhost:1880
```

**Create a test flow:**
1. Open Node-RED UI
2. Drag an "inject" node and a "debug" node
3. Connect them
4. Deploy
5. Click the inject button
6. Check debug output

### 9. Integration Tests

**Test Mosquitto → Hono Flow:**

1. Configure Hono tenant and device (via Hono API or UI)
2. Publish message to Mosquitto with Hono topic format
3. Verify message appears in Kafka topics

**Test Kafka → Ditto Flow:**

1. Publish message to Kafka topic that Ditto consumes
2. Check Ditto API for digital twin updates
3. Verify Ditto connectivity service logs

**Test Kafka → ThingsBoard Flow:**

1. Configure ThingsBoard to consume from Kafka
2. Publish telemetry to Kafka
3. Verify data appears in ThingsBoard

## Verification Checklist

- [ ] All pods are running
- [ ] Mosquitto accepts MQTT connections
- [ ] Ditto API responds
- [ ] Hono Device Registry is accessible
- [ ] Kafka is accessible from IoT namespace
- [ ] Databases are accessible
- [ ] Services can discover each other
- [ ] End-to-end data flow works
- [ ] Port-forwarding scripts work
- [ ] Access scripts are functional

## Troubleshooting

### Mosquitto not accepting connections
- Check pod logs: `kubectl logs -n iot -l app=mosquitto`
- Verify service: `kubectl get svc -n iot mosquitto`
- Check network policies

### Ditto API returns errors
- Check Ditto gateway logs: `kubectl logs -n iot -l app=ditto-gateway`
- Verify MongoDB connection: `kubectl logs -n iot -l app=ditto-connectivity`
- Check service: `kubectl get svc -n iot ditto-nginx`

### Hono adapters not working
- Check adapter logs: `kubectl logs -n iot -l app=hono-adapter-mqtt`
- Verify Kafka connectivity: Check for "bootstrap.servers" in logs
- Verify Device Registry: `kubectl logs -n iot -l app=hono-service-device-registry`

### Kafka connectivity issues
- Test from IoT namespace: Use the test commands above
- Check network policies
- Verify service DNS resolution

### Database connection issues
- Check pod status: `kubectl get pods -n iot | grep -E "timescaledb|postgresql|mongodb"`
- Check service endpoints: `kubectl get endpoints -n iot`
- Verify credentials in values files

## Performance Testing

**Load Test Mosquitto:**
```bash
# Install mosquitto-clients locally
# Then run multiple publishers
for i in {1..10}; do
  mosquitto_pub -h localhost -p 1883 -t test/load -m "Message $i" &
done
```

**Load Test Kafka:**
```bash
# Publish multiple messages
for i in {1..100}; do
  kubectl run kafka-pub-$i --rm -i --restart=Never \
    --image=quay.io/strimzi/kafka:latest-kafka-4.1.1 -n iot \
    -- bin/kafka-console-producer.sh \
    --bootstrap-server kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092 \
    --topic iot-test <<< "Message $i" &
done
```

## Monitoring

**Check resource usage:**
```bash
kubectl top pods -n iot
kubectl top nodes
```

**Check logs:**
```bash
# All IoT stack logs
kubectl logs -n iot --all-containers=true --tail=50

# Specific component
kubectl logs -n iot -l app=mosquitto --tail=50
```

**Check events:**
```bash
kubectl get events -n iot --sort-by='.lastTimestamp'
```

---

**Last Updated**: December 2024  
**Namespace**: `iot`

