package com.k8s.home.twin.stream;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.k8s.home.twin.config.KafkaConfig;
import com.k8s.home.twin.model.DeviceTwin;
import com.k8s.home.twin.model.TelemetryMessage;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.common.serialization.Serde;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.kstream.*;
import org.apache.kafka.streams.state.KeyValueStore;
import org.apache.kafka.streams.state.StoreBuilder;
import org.apache.kafka.streams.state.Stores;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.StreamsBuilderFactoryBean;

import java.util.Map;

@Slf4j
@Configuration
public class TwinStreamProcessor {
    
    private final ObjectMapper objectMapper;
    private final Serde<TelemetryMessage> telemetrySerde;
    private final Serde<DeviceTwin> twinSerde;
    
    @Value("${twin.topics.telemetry:hono.telemetry}")
    private String telemetryTopic;
    
    @Value("${twin.topics.twins:device.twins}")
    private String twinsTopic;
    
    @Value("${twin.state-store.name:twin-store}")
    private String stateStoreName;
    
    public TwinStreamProcessor(
            ObjectMapper objectMapper,
            KafkaConfig kafkaConfig) {
        this.objectMapper = objectMapper;
        this.telemetrySerde = kafkaConfig.telemetrySerde();
        this.twinSerde = kafkaConfig.twinSerde();
    }
    
    @Bean
    public KStream<String, DeviceTwin> processTwinState(StreamsBuilder streamsBuilder) {
        log.info("Setting up Kafka Streams topology for twin processing");
        log.info("Telemetry topic: {}, State store: {}", telemetryTopic, stateStoreName);
        
        // Consume telemetry messages from Kafka
        KStream<String, String> telemetryStream = streamsBuilder.stream(
            telemetryTopic,
            Consumed.with(Serdes.String(), Serdes.String())
        );
        
        // Parse JSON messages to TelemetryMessage
        KStream<String, TelemetryMessage> parsedStream = telemetryStream.mapValues(
            (readOnlyKey, jsonValue) -> {
                try {
                    return objectMapper.readValue(jsonValue, TelemetryMessage.class);
                } catch (Exception e) {
                    log.error("Failed to parse telemetry message: {}", jsonValue, e);
                    return null;
                }
            }
        ).filter((key, value) -> value != null);
        
        // Group by device ID
        KGroupedStream<String, TelemetryMessage> grouped = parsedStream.groupBy(
            (key, telemetry) -> {
                // Extract device ID from message
                if (telemetry.getDeviceId() != null) {
                    return telemetry.getDeviceId();
                }
                // Fallback: use key if deviceId is not in message
                return key != null ? key : "unknown";
            },
            Grouped.with(Serdes.String(), telemetrySerde)
        );
        
        // Aggregate to maintain latest state per device
        KTable<String, DeviceTwin> twinTable = grouped.aggregate(
            () -> DeviceTwin.builder()
                .reported(Map.of())
                .desired(Map.of())
                .build(),
            (deviceId, telemetry, twin) -> {
                log.debug("Updating twin for device: {}", deviceId);
                twin.setDeviceId(deviceId);
                if (telemetry.getData() != null) {
                    twin.updateReported(telemetry.getData());
                }
                return twin;
            },
            Materialized.<String, DeviceTwin, KeyValueStore<org.apache.kafka.common.utils.Bytes, byte[]>>as(stateStoreName)
                .withKeySerde(Serdes.String())
                .withValueSerde(twinSerde)
        );
        
        // Convert KTable to KStream and publish to twins topic
        twinTable.toStream().to(
            twinsTopic,
            Produced.with(Serdes.String(), twinSerde)
        );
        
        log.info("Kafka Streams topology configured successfully");
        
        // Return a stream for further processing if needed
        return twinTable.toStream();
    }
}

