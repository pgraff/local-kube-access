# Kafka-Based Digital Twin Service - Implementation Recommendation

**Date:** November 27, 2025  
**Context:** Replace Ditto with a simpler, Kafka-native solution

## Recommended Architecture

```
┌─────────────┐
│   Devices   │
└──────┬──────┘
       │ MQTT
       ▼
┌─────────────┐
│  Mosquitto  │ (Already running)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    Hono     │ (Already running)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    Kafka    │ (Already running)
└──────┬──────┘
       │
       ├─────────────────────────────────┐
       │                                 │
       ▼                                 ▼
┌──────────────────┐          ┌──────────────────┐
│ Twin Projection  │          │  TimescaleDB     │
│  (Kafka Streams) │          │  (Telemetry)     │
└────────┬─────────┘          └──────────────────┘
         │
         ▼
┌──────────────────┐
│   Twin Cache     │ (Redis - optional)
│   (State Store)  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│   Twin REST API  │
│   (Queries)      │
└────────┬─────────┘
         │
         ├──> ThingsBoard
         └──> Node-RED
```

## Technology Stack Recommendation

### Core Components

1. **Kafka Streams** (Java/Scala)
   - **Why:** Native Kafka integration, built-in state stores
   - **Alternative:** Kafka Connect with Materialized Views
   - **Language:** Java (most mature) or Scala

2. **REST API Service** (Your choice)
   - **Options:**
     - **Spring Boot** (Java) - Best Kafka Streams integration
     - **Quarkus** (Java) - Lightweight, fast startup
     - **Go** - Simple, fast, good for REST APIs
     - **Python/FastAPI** - If you prefer Python
   - **Recommendation:** **Spring Boot** (best Kafka Streams support)

3. **State Store** (Choose one)
   - **Option A:** Kafka Streams In-Memory State Store (simplest)
   - **Option B:** Redis (for persistence, multi-instance)
   - **Option C:** RocksDB (via Kafka Streams, persistent)
   - **Recommendation:** Start with **Kafka Streams State Store**, add Redis if needed

### Why This Stack?

✅ **Leverages Your Existing Infrastructure**
- Kafka (already running)
- No new databases needed (use Kafka Streams state store)
- Can add Redis later if needed

✅ **Simple Operations**
- Single service to deploy
- No MongoDB dependency
- Easier to troubleshoot

✅ **Scalable**
- Kafka Streams handles partitioning automatically
- Can scale horizontally
- State stores are distributed

✅ **Well-Documented**
- Kafka Streams has extensive documentation
- Spring Boot is widely used
- Lots of examples

## Implementation Approach

### Phase 1: Minimal Viable Twin (MVP)

**Goal:** Replace Ditto's core functionality with simple twin service

**Features:**
1. Consume device telemetry from Kafka
2. Maintain latest state per device (twin)
3. REST API to query twin state
4. REST API to update twin desired state

**Time Estimate:** 1-2 weeks

### Phase 2: Enhanced Features

**Features:**
1. Twin history (time-series)
2. Twin search/filtering
3. WebSocket API (real-time updates)
4. Policy engine (if needed)

**Time Estimate:** 2-4 weeks

### Phase 3: Production Ready

**Features:**
1. Monitoring/metrics
2. Health checks
3. Authentication/authorization
4. Documentation
5. Load testing

**Time Estimate:** 2-4 weeks

## Recommended Implementation: Spring Boot + Kafka Streams

### Project Structure

```
twin-service/
├── src/main/java/
│   └── com/yourcompany/twin/
│       ├── TwinServiceApplication.java
│       ├── stream/
│       │   ├── TwinStreamProcessor.java      # Kafka Streams topology
│       │   └── TwinStateStore.java          # State store configuration
│       ├── model/
│       │   ├── DeviceTwin.java              # Twin data model
│       │   └── TelemetryMessage.java        # Kafka message model
│       ├── api/
│       │   ├── TwinController.java           # REST endpoints
│       │   └── TwinService.java             # Business logic
│       └── config/
│           └── KafkaConfig.java              # Kafka configuration
├── src/main/resources/
│   └── application.yml                       # Configuration
└── pom.xml                                   # Maven dependencies
```

### Key Dependencies (Maven)

```xml
<dependencies>
    <!-- Spring Boot -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    
    <!-- Kafka Streams -->
    <dependency>
        <groupId>org.apache.kafka</groupId>
        <artifactId>kafka-streams</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.kafka</groupId>
        <artifactId>spring-kafka</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-stream-binder-kafka-streams</artifactId>
    </dependency>
    
    <!-- Optional: Redis for distributed cache -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-redis</artifactId>
    </dependency>
</dependencies>
```

### Core Implementation

#### 1. Twin Data Model

```java
public class DeviceTwin {
    private String deviceId;
    private Map<String, Object> reported;      // Last reported state
    private Map<String, Object> desired;      // Desired state
    private Long lastUpdateTimestamp;
    private Long lastReportedTimestamp;
    
    // Getters, setters, constructors
}
```

#### 2. Kafka Streams Processor

```java
@Configuration
public class TwinStreamProcessor {
    
    @Bean
    public KStream<String, TelemetryMessage> processTwinState(
            StreamsBuilder streamsBuilder) {
        
        // Consume from Kafka topic (e.g., "device.telemetry")
        KStream<String, TelemetryMessage> telemetryStream = 
            streamsBuilder.stream("device.telemetry", 
                Consumed.with(Serdes.String(), telemetrySerde));
        
        // Group by device ID
        KGroupedStream<String, TelemetryMessage> grouped = 
            telemetryStream.groupByKey();
        
        // Aggregate to maintain latest state per device
        KTable<String, DeviceTwin> twinTable = grouped.aggregate(
            DeviceTwin::new,
            (deviceId, telemetry, twin) -> {
                // Update twin with latest telemetry
                twin.setDeviceId(deviceId);
                twin.getReported().putAll(telemetry.getData());
                twin.setLastReportedTimestamp(System.currentTimeMillis());
                return twin;
            },
            Materialized.<String, DeviceTwin, KeyValueStore<Bytes, byte[]>>as("twin-store")
                .withKeySerde(Serdes.String())
                .withValueSerde(twinSerde)
        );
        
        // Optionally, publish twin updates to another topic
        twinTable.toStream().to("device.twins", 
            Produced.with(Serdes.String(), twinSerde));
        
        return telemetryStream;
    }
}
```

#### 3. REST API Controller

```java
@RestController
@RequestMapping("/api/v1/twins")
public class TwinController {
    
    @Autowired
    private TwinService twinService;
    
    // Get twin state
    @GetMapping("/{deviceId}")
    public ResponseEntity<DeviceTwin> getTwin(@PathVariable String deviceId) {
        DeviceTwin twin = twinService.getTwin(deviceId);
        if (twin == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(twin);
    }
    
    // List all twins
    @GetMapping
    public ResponseEntity<List<DeviceTwin>> listTwins(
            @RequestParam(required = false) String filter) {
        return ResponseEntity.ok(twinService.listTwins(filter));
    }
    
    // Update desired state
    @PatchMapping("/{deviceId}/desired")
    public ResponseEntity<DeviceTwin> updateDesired(
            @PathVariable String deviceId,
            @RequestBody Map<String, Object> desired) {
        DeviceTwin twin = twinService.updateDesired(deviceId, desired);
        return ResponseEntity.ok(twin);
    }
    
    // Get twin history (if implemented)
    @GetMapping("/{deviceId}/history")
    public ResponseEntity<List<DeviceTwin>> getHistory(
            @PathVariable String deviceId,
            @RequestParam Long from,
            @RequestParam Long to) {
        return ResponseEntity.ok(twinService.getHistory(deviceId, from, to));
    }
}
```

#### 4. Twin Service (Business Logic)

```java
@Service
public class TwinService {
    
    @Autowired
    private KafkaStreams kafkaStreams;
    
    public DeviceTwin getTwin(String deviceId) {
        // Query Kafka Streams state store
        ReadOnlyKeyValueStore<String, DeviceTwin> store = 
            kafkaStreams.store(
                StoreQueryParameters.fromNameAndType("twin-store", 
                    QueryableStoreTypes.keyValueStore()));
        
        return store.get(deviceId);
    }
    
    public List<DeviceTwin> listTwins(String filter) {
        // Iterate over all twins in state store
        ReadOnlyKeyValueStore<String, DeviceTwin> store = 
            kafkaStreams.store(
                StoreQueryParameters.fromNameAndType("twin-store", 
                    QueryableStoreTypes.keyValueStore()));
        
        List<DeviceTwin> twins = new ArrayList<>();
        store.all().forEachRemaining(kv -> {
            if (filter == null || matchesFilter(kv.value, filter)) {
                twins.add(kv.value);
            }
        });
        
        return twins;
    }
    
    public DeviceTwin updateDesired(String deviceId, Map<String, Object> desired) {
        // Publish desired state update to Kafka
        // Stream processor will update twin
        // For now, return current twin
        DeviceTwin twin = getTwin(deviceId);
        if (twin == null) {
            twin = new DeviceTwin();
            twin.setDeviceId(deviceId);
        }
        twin.setDesired(desired);
        twin.setLastUpdateTimestamp(System.currentTimeMillis());
        
        // Publish to Kafka topic for desired state updates
        kafkaTemplate.send("device.desired", deviceId, twin);
        
        return twin;
    }
}
```

### Configuration (application.yml)

```yaml
spring:
  kafka:
    bootstrap-servers: kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
    streams:
      application-id: twin-service
      replication-factor: 3
      state-dir: /tmp/kafka-streams
      properties:
        default.key.serde: org.apache.kafka.common.serialization.Serdes$StringSerde
        default.value.serde: org.apache.kafka.common.serialization.Serdes$StringSerde

server:
  port: 8080

twin:
  store:
    name: twin-store
    retention-ms: 86400000  # 24 hours
```

## Deployment to Kubernetes

### Dockerfile

```dockerfile
FROM maven:3.8-openjdk-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

FROM openjdk:17-jre-slim
WORKDIR /app
COPY --from=build /app/target/twin-service-*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: twin-service
  namespace: iot
spec:
  replicas: 2
  selector:
    matchLabels:
      app: twin-service
  template:
    metadata:
      labels:
        app: twin-service
    spec:
      containers:
      - name: twin-service
        image: your-registry/twin-service:latest
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_KAFKA_BOOTSTRAP_SERVERS
          value: "kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: twin-service
  namespace: iot
spec:
  selector:
    app: twin-service
  ports:
  - port: 8080
    targetPort: 8080
```

## Migration Plan

### Step 1: Build MVP (Week 1-2)
1. Set up Spring Boot project
2. Implement basic Kafka Streams processor
3. Implement REST API
4. Test with sample data

### Step 2: Deploy Alongside Ditto (Week 3)
1. Deploy twin-service to cluster
2. Route some traffic to new service
3. Compare functionality
4. Fix any issues

### Step 3: Migrate Gradually (Week 4-5)
1. Route more traffic to twin-service
2. Update ThingsBoard/Node-RED to use new API
3. Monitor performance

### Step 4: Decommission Ditto (Week 6)
1. Verify all functionality works
2. Remove Ditto deployments
3. Remove MongoDB for Ditto
4. Clean up resources

## Advantages Over Ditto

✅ **Simpler Architecture**
- Single service vs. multiple microservices
- No MongoDB dependency
- Easier to understand and maintain

✅ **Better Resource Usage**
- Lower memory footprint
- No database overhead
- Can run on fewer resources

✅ **Easier Troubleshooting**
- Single service to debug
- Standard Spring Boot logging
- Kafka Streams metrics built-in

✅ **More Control**
- Customize exactly what you need
- No unnecessary features
- Full control over data model

✅ **Better Integration**
- Native Kafka integration
- Can leverage Kafka ecosystem
- Easier to extend

## Next Steps

1. **Create Project Structure**
   ```bash
   mkdir -p twin-service/src/main/java/com/yourcompany/twin
   ```

2. **Initialize Spring Boot Project**
   - Use Spring Initializr: https://start.spring.io/
   - Add dependencies: Web, Kafka, Kafka Streams

3. **Implement MVP**
   - Start with basic twin state store
   - Add REST API
   - Test with your Kafka topics

4. **Deploy to Cluster**
   - Build Docker image
   - Deploy to Kubernetes
   - Test integration

5. **Iterate**
   - Add features as needed
   - Optimize performance
   - Add monitoring

## Resources

- **Kafka Streams Documentation:** https://kafka.apache.org/documentation/streams/
- **Spring Kafka:** https://spring.io/projects/spring-kafka
- **Kafka Streams Examples:** https://github.com/confluentinc/kafka-streams-examples
- **Spring Boot Guide:** https://spring.io/guides

## Alternative: Quick Start with Existing Tools

If you want something even simpler to start:

### Option: Use Kafka Connect + Materialized Views

1. **Use Kafka Connect** to create materialized views
2. **Query via REST API** using Kafka REST Proxy
3. **Or use ksqlDB** (if you want SQL interface)

This requires less code but is less flexible.

---

**Recommendation:** Start with Spring Boot + Kafka Streams for the best balance of simplicity and flexibility.

