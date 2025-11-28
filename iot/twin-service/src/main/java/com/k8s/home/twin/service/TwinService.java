package com.k8s.home.twin.service;

import com.k8s.home.twin.model.DeviceTwin;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.StoreQueryParameters;
import org.apache.kafka.streams.state.KeyValueStore;
import org.apache.kafka.streams.state.QueryableStoreTypes;
import org.apache.kafka.streams.state.ReadOnlyKeyValueStore;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.config.StreamsBuilderFactoryBean;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
public class TwinService {
    
    private final StreamsBuilderFactoryBean streamsBuilderFactoryBean;
    
    @Value("${twin.state-store.name:twin-store}")
    private String stateStoreName;
    
    public TwinService(StreamsBuilderFactoryBean streamsBuilderFactoryBean) {
        this.streamsBuilderFactoryBean = streamsBuilderFactoryBean;
    }
    
    private ReadOnlyKeyValueStore<String, DeviceTwin> getTwinStore() {
        KafkaStreams kafkaStreams = streamsBuilderFactoryBean.getKafkaStreams();
        if (kafkaStreams == null) {
            throw new IllegalStateException("Kafka Streams not initialized");
        }
        return kafkaStreams.store(
            StoreQueryParameters.fromNameAndType(
                stateStoreName,
                QueryableStoreTypes.keyValueStore()
            )
        );
    }
    
    public DeviceTwin getTwin(String deviceId) {
        try {
            ReadOnlyKeyValueStore<String, DeviceTwin> store = getTwinStore();
            DeviceTwin twin = store.get(deviceId);
            if (twin == null) {
                // Return empty twin if not found
                return DeviceTwin.builder()
                    .deviceId(deviceId)
                    .reported(Map.of())
                    .desired(Map.of())
                    .build();
            }
            return twin;
        } catch (Exception e) {
            log.error("Error retrieving twin for device: {}", deviceId, e);
            throw new RuntimeException("Failed to retrieve twin", e);
        }
    }
    
    public List<DeviceTwin> getAllTwins() {
        try {
            ReadOnlyKeyValueStore<String, DeviceTwin> store = getTwinStore();
            List<DeviceTwin> twins = new ArrayList<>();
            store.all().forEachRemaining(kv -> twins.add(kv.value));
            return twins;
        } catch (Exception e) {
            log.error("Error retrieving all twins", e);
            throw new RuntimeException("Failed to retrieve twins", e);
        }
    }
    
    public boolean twinExists(String deviceId) {
        try {
            ReadOnlyKeyValueStore<String, DeviceTwin> store = getTwinStore();
            return store.get(deviceId) != null;
        } catch (Exception e) {
            log.error("Error checking twin existence for device: {}", deviceId, e);
            return false;
        }
    }
}

