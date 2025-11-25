# Kubecost Grafana 502 Bad Gateway Fix

## Problem

When accessing Grafana through Kubecost UI, you get a **502 Bad Gateway** error with `nginx/1.20.1`.

## Root Cause

The Grafana pod's sidecar container (`grafana-sc-dashboard`) was crashing due to:
- **Read-only root filesystem**: The sidecar has `readOnlyRootFilesystem: true` for security
- **No writable temp directory**: The sidecar couldn't find a usable temporary directory in `/tmp`, `/var/tmp`, `/usr/tmp`, or `/app`
- **Error**: `FileNotFoundError: [Errno 2] No usable temporary directory found`

This caused the pod to be in `CrashLoopBackOff` state (1/2 containers ready), making Grafana inaccessible.

## Solution

Added `TMPDIR` environment variable to the sidecar container pointing to the writable volume mount:

```bash
kubectl patch deployment -n kubecost kubecost-grafana --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/env/-",
    "value": {
      "name": "TMPDIR",
      "value": "/tmp/dashboards"
    }
  }
]'
```

This tells the sidecar to use `/tmp/dashboards` (which is a writable `emptyDir` volume) for temporary files instead of the read-only system directories.

## Verification

After applying the fix:

```bash
# Check pod status (should be 2/2 Running)
kubectl get pods -n kubecost -l app=grafana

# Check sidecar logs (should not show temp directory errors)
kubectl logs -n kubecost -l app=grafana --container=grafana-sc-dashboard --tail=20
```

## Result

✅ Grafana pod is now `2/2 Running`  
✅ Both containers (Grafana + sidecar) are healthy  
✅ Grafana dashboard is accessible through Kubecost UI  
✅ No more 502 Bad Gateway errors

## Accessing Grafana

1. **Through Kubecost UI**:
   - Access Kubecost: `./access-kubecost.sh` then open `http://localhost:9090`
   - Click on "Grafana Dashboard" link in the UI

2. **Direct port-forward** (if needed):
   ```bash
   kubectl port-forward -n kubecost svc/kubecost-grafana 3000:80
   # Then open: http://localhost:3000
   ```

## Technical Details

### Why This Happened

The `k8s-sidecar` container (used by Grafana to sync dashboards from ConfigMaps) uses Python's `multiprocessing` module, which requires a writable temporary directory to create Unix sockets for inter-process communication. With `readOnlyRootFilesystem: true`, the standard temp directories are not writable.

### The Fix

By setting `TMPDIR=/tmp/dashboards`, we redirect all temporary file operations to the writable `emptyDir` volume that's already mounted at that path. This allows the sidecar to function properly while maintaining the security benefits of a read-only root filesystem.

## Related Files

- [Kubecost Cluster ID Fix](kubecost-clusterid-fix.md) - Initial Kubecost installation troubleshooting
- [Kubecost Grafana No Data Fix](kubecost-grafana-no-data-fix.md) - Troubleshooting when Grafana shows no data
- [Access Scripts](README.md#scripts) - How to access Kubecost and Grafana

