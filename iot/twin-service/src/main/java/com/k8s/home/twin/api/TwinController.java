package com.k8s.home.twin.api;

import com.k8s.home.twin.model.DeviceTwin;
import com.k8s.home.twin.service.TwinService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/v1/twins")
public class TwinController {
    
    private final TwinService twinService;
    
    public TwinController(TwinService twinService) {
        this.twinService = twinService;
    }
    
    @GetMapping("/{deviceId}")
    public ResponseEntity<DeviceTwin> getTwin(@PathVariable String deviceId) {
        log.info("Getting twin for device: {}", deviceId);
        try {
            DeviceTwin twin = twinService.getTwin(deviceId);
            return ResponseEntity.ok(twin);
        } catch (Exception e) {
            log.error("Error getting twin for device: {}", deviceId, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
    
    @GetMapping
    public ResponseEntity<List<DeviceTwin>> getAllTwins() {
        log.info("Getting all twins");
        try {
            List<DeviceTwin> twins = twinService.getAllTwins();
            return ResponseEntity.ok(twins);
        } catch (Exception e) {
            log.error("Error getting all twins", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
    
    @GetMapping("/{deviceId}/reported")
    public ResponseEntity<Map<String, Object>> getReported(@PathVariable String deviceId) {
        log.info("Getting reported state for device: {}", deviceId);
        try {
            DeviceTwin twin = twinService.getTwin(deviceId);
            return ResponseEntity.ok(twin.getReported());
        } catch (Exception e) {
            log.error("Error getting reported state for device: {}", deviceId, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
    
    @GetMapping("/{deviceId}/desired")
    public ResponseEntity<Map<String, Object>> getDesired(@PathVariable String deviceId) {
        log.info("Getting desired state for device: {}", deviceId);
        try {
            DeviceTwin twin = twinService.getTwin(deviceId);
            return ResponseEntity.ok(twin.getDesired());
        } catch (Exception e) {
            log.error("Error getting desired state for device: {}", deviceId, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
    
    @PutMapping("/{deviceId}/desired")
    public ResponseEntity<DeviceTwin> updateDesired(
            @PathVariable String deviceId,
            @RequestBody Map<String, Object> desiredState) {
        log.info("Updating desired state for device: {}", deviceId);
        // TODO: Publish to commands topic to update desired state
        // For now, return the current twin
        DeviceTwin twin = twinService.getTwin(deviceId);
        twin.updateDesired(desiredState);
        return ResponseEntity.ok(twin);
    }
    
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of("status", "UP"));
    }
}

