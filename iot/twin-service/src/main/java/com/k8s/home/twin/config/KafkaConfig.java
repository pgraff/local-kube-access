package com.k8s.home.twin.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.type.MapType;
import com.fasterxml.jackson.databind.type.TypeFactory;
import com.k8s.home.twin.model.DeviceTwin;
import com.k8s.home.twin.model.TelemetryMessage;
import org.apache.kafka.common.serialization.Serde;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.kstream.Materialized;
import org.apache.kafka.streams.state.KeyValueStore;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.support.serializer.JsonSerde;

@Configuration
public class KafkaConfig {
    
    @Bean
    public Serde<TelemetryMessage> telemetrySerde() {
        return new JsonSerde<>(TelemetryMessage.class);
    }
    
    @Bean
    public Serde<DeviceTwin> twinSerde() {
        return new JsonSerde<>(DeviceTwin.class);
    }
    
    @Bean
    public ObjectMapper objectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        mapper.findAndRegisterModules();
        return mapper;
    }
}

