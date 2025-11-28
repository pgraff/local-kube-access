# Kafka-Based Digital Twin Service

A lightweight digital twin service built with Spring Boot and Kafka Streams, replacing Eclipse Ditto.

## Features

- **Real-time Twin State Management**: Maintains latest reported and desired state for IoT devices
- **Kafka Streams Processing**: Uses Kafka Streams for scalable, fault-tolerant state management
- **REST API**: Simple REST API for querying and updating twin state
- **Health Checks**: Built-in health endpoints for Kubernetes probes

## Architecture

```
Device → Hono → Kafka (hono.telemetry) → Twin Service → Kafka (device.twins)
                                                      ↓
                                              REST API (queries)
```

## Prerequisites

- Java 17+
- Maven 3.6+
- Docker (for containerization)
- Kubernetes cluster with:
  - Kafka cluster (Strimzi)
  - Hono (for device telemetry)

## Building

### Local Build

```bash
# Build with Maven
mvn clean package

# Build Docker image
./build.sh
```

### Docker Build

```bash
docker build -t twin-service:latest .
```

## Configuration

### Environment Variables

- `SPRING_KAFKA_BOOTSTRAP_SERVERS`: Kafka bootstrap servers (default: `kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`)
- `SPRING_KAFKA_STREAMS_APPLICATION_ID`: Kafka Streams application ID (default: `twin-service`)
- `TWIN_TELEMETRY_TOPIC`: Input topic for telemetry (default: `hono.telemetry`)
- `TWIN_TWINS_TOPIC`: Output topic for twin updates (default: `device.twins`)
- `TWIN_COMMANDS_TOPIC`: Topic for desired state commands (default: `device.commands`)

### Application Properties

See `src/main/resources/application.yml` for full configuration.

## Deployment

### Kubernetes

```bash
# Apply deployment
kubectl apply -f k8s/deployment.yaml

# Check status
kubectl get pods -n iot -l app=twin-service

# View logs
kubectl logs -n iot -l app=twin-service -f
```

### Update Image

1. Build and push your image:
   ```bash
   docker build -t <registry>/twin-service:latest .
   docker push <registry>/twin-service:latest
   ```

2. Update `k8s/deployment.yaml` with your image:
   ```yaml
   image: <registry>/twin-service:latest
   ```

3. Apply:
   ```bash
   kubectl apply -f k8s/deployment.yaml
   ```

## API Endpoints

### Get Twin

```bash
GET /api/v1/twins/{deviceId}
```

Response:
```json
{
  "deviceId": "device-001",
  "reported": {
    "temperature": 25.5,
    "humidity": 60
  },
  "desired": {
    "targetTemperature": 22.0
  },
  "lastUpdateTimestamp": 1234567890,
  "lastReportedTimestamp": 1234567890
}
```

### Get All Twins

```bash
GET /api/v1/twins
```

### Get Reported State

```bash
GET /api/v1/twins/{deviceId}/reported
```

### Get Desired State

```bash
GET /api/v1/twins/{deviceId}/desired
```

### Update Desired State

```bash
PUT /api/v1/twins/{deviceId}/desired
Content-Type: application/json

{
  "targetTemperature": 22.0,
  "mode": "cooling"
}
```

### Health Check

```bash
GET /actuator/health
```

## Development

### Running Locally

1. Start Kafka (or use existing cluster)
2. Configure `application.yml` with your Kafka bootstrap servers
3. Run:
   ```bash
   mvn spring-boot:run
   ```

### Testing

```bash
# Run tests
mvn test

# Integration tests (requires Kafka)
mvn verify
```

## Kafka Topics

The service expects the following topics:

- **Input**: `hono.telemetry` (or configured via `TWIN_TELEMETRY_TOPIC`)
  - Format: JSON with `deviceId`, `data`, `timestamp`
  
- **Output**: `device.twins` (or configured via `TWIN_TWINS_TOPIC`)
  - Format: JSON DeviceTwin objects

- **Commands**: `device.commands` (or configured via `TWIN_COMMANDS_TOPIC`)
  - Format: JSON with `deviceId` and desired state updates

## State Store

The service uses Kafka Streams state store (`twin-store`) to maintain twin state in-memory. The state is:
- Distributed across Kafka Streams instances
- Replicated via Kafka
- Recovered automatically on restart

## Monitoring

### Health Checks

- Liveness: `/actuator/health/liveness`
- Readiness: `/actuator/health/readiness`

### Metrics

- Metrics: `/actuator/metrics`
- Prometheus: `/actuator/prometheus` (if enabled)

## Troubleshooting

### Service Not Starting

1. Check Kafka connectivity:
   ```bash
   kubectl exec -n iot -it <twin-service-pod> -- wget -O- http://localhost:8080/actuator/health
   ```

2. Check logs:
   ```bash
   kubectl logs -n iot -l app=twin-service
   ```

3. Verify Kafka topics exist:
   ```bash
   kubectl exec -n kafka kafka-cluster-kafka-0 -- bin/kafka-topics.sh \
     --bootstrap-server localhost:9092 --list
   ```

### No Twin Data

1. Verify telemetry is flowing:
   ```bash
   kubectl exec -n kafka kafka-cluster-kafka-0 -- bin/kafka-console-consumer.sh \
     --bootstrap-server localhost:9092 \
     --topic hono.telemetry \
     --from-beginning
   ```

2. Check state store:
   - State store is initialized when first message is processed
   - Restart may be needed if state store is corrupted

## Next Steps

- [ ] Add authentication/authorization
- [ ] Add WebSocket support for real-time updates
- [ ] Add twin history/time-series
- [ ] Add search/filtering capabilities
- [ ] Add Redis for distributed caching (optional)
- [ ] Add metrics and monitoring

## License

See LICENSE file.
