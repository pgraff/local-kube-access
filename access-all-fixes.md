# access-all.sh Fixes

## Issues Fixed

### 1. Service Discovery for IoT Services

**Problem:** `access-all.sh` was using hardcoded service names for Hono and Ditto that might not match the actual Helm-deployed service names.

**Solution:** Updated the script to use dynamic service discovery (same approach as individual access scripts):
- **Hono**: Tries multiple label selectors and grep patterns to find the HTTP adapter service
- **Ditto**: Searches for services matching "ditto" and "gateway" patterns

**Changes in `access-all.sh`:**
```bash
# Before (hardcoded):
start_port_forward "hono" "iot" "hono-http-adapter" 8082 8080 || \
start_port_forward "hono" "iot" "hono-adapter-http" 8082 8080

# After (dynamic discovery):
HONO_SERVICE=$(kubectl get svc -n iot -l app=hono,component=http-adapter ... || ...)
if [ -n "$HONO_SERVICE" ]; then
    start_port_forward "hono" "iot" "$HONO_SERVICE" 8082 8080
fi
```

### 2. Kill Script Hanging

**Problem:** `kill-access-all.sh` (which calls `access-all.sh stop`) was hanging when trying to kill SSH connections to the remote server for Rancher port-forwarding.

**Solution:** Added timeouts and force-kill logic to the `stop_all()` function:
- Added `timeout 5` to SSH commands to prevent hanging
- Added `ConnectTimeout=3` to SSH connections
- Added force-kill (`kill -9`) for processes that don't respond to normal kill
- Improved cleanup order: remote first, then local

**Changes in `access-all.sh`:**
```bash
# Before:
ssh scispike@k8s-cp-01 "pkill -f 'kubectl port-forward.*rancher' || true"

# After:
timeout 5 ssh -o ConnectTimeout=3 scispike@k8s-cp-01 "pkill -f 'kubectl port-forward.*rancher' || true" 2>/dev/null || true
# ... with force-kill fallback
```

## Testing

### Test Service Discovery

```bash
./test-access-all.sh
```

This script verifies that all IoT services can be discovered correctly.

### Test Kill Script

```bash
# Start port-forwards
./access-all.sh

# In another terminal, stop them (should not hang)
./kill-access-all.sh
```

### Test Full Cycle

```bash
# 1. Stop any existing port-forwards
./kill-access-all.sh

# 2. Start all port-forwards
./access-all.sh

# 3. Verify services are accessible
curl http://localhost:8080  # Longhorn
curl http://localhost:9090  # Kubecost
curl http://localhost:8081  # Kafka UI

# 4. Stop all port-forwards
./kill-access-all.sh
```

## Service Names Reference

### Direct Service Names (no discovery needed)
- **Mosquitto**: `mosquitto`
- **ThingsBoard**: `thingsboard`
- **Node-RED**: `node-red`

### Dynamic Discovery Required
- **Hono**: Searches for service with labels `app=hono,component=http-adapter` or `app.kubernetes.io/name=hono`, or greps for "hono" and "http"/"adapter"
- **Ditto**: Searches for service name containing "ditto" and "gateway", or falls back to `ditto-nginx`

## Troubleshooting

### Services Not Found

If `access-all.sh` can't find IoT services:

1. **Check if namespace exists:**
   ```bash
   kubectl get namespace iot
   ```

2. **Check available services:**
   ```bash
   kubectl get svc -n iot
   ```

3. **Run test script:**
   ```bash
   ./test-access-all.sh
   ```

### Kill Script Still Hanging

If `kill-access-all.sh` still hangs:

1. **Manually kill processes:**
   ```bash
   pkill -9 -f "kubectl port-forward"
   pkill -9 -f "ssh.*-L.*8443"
   ```

2. **Kill remote Rancher port-forward:**
   ```bash
   ssh scispike@k8s-cp-01 "pkill -9 -f 'kubectl port-forward.*rancher'"
   ```

3. **Clean up PID file:**
   ```bash
   rm -f /tmp/k8s-access-all.pids
   ```

### Port Already in Use

If you see "Port X is already in use":

1. **Find what's using the port:**
   ```bash
   lsof -i :PORT_NUMBER
   ```

2. **Kill the process:**
   ```bash
   kill -9 $(lsof -t -i :PORT_NUMBER)
   ```

3. **Or stop all port-forwards:**
   ```bash
   ./kill-access-all.sh
   ```

## Files Modified

- `access-all.sh`: Updated service discovery and stop function
- `kill-access-all.sh`: No changes needed (already calls `access-all.sh stop`)

## Files Created

- `test-access-all.sh`: Test script to verify service discovery
- `access-all-fixes.md`: This documentation

---

**Last Updated**: December 2024

