package com.k8s.home.twin.model;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.HashMap;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class DeviceTwin {
    private String deviceId;
    
    @Builder.Default
    private Map<String, Object> reported = new HashMap<>();
    
    @Builder.Default
    private Map<String, Object> desired = new HashMap<>();
    
    private Long lastUpdateTimestamp;
    private Long lastReportedTimestamp;
    
    public DeviceTwin updateReported(Map<String, Object> newData) {
        if (reported == null) {
            reported = new HashMap<>();
        }
        reported.putAll(newData);
        lastReportedTimestamp = System.currentTimeMillis();
        lastUpdateTimestamp = System.currentTimeMillis();
        return this;
    }
    
    public DeviceTwin updateDesired(Map<String, Object> newData) {
        if (desired == null) {
            desired = new HashMap<>();
        }
        desired.putAll(newData);
        lastUpdateTimestamp = System.currentTimeMillis();
        return this;
    }
}

