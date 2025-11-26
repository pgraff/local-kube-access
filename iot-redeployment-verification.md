# IoT Stack Redeployment Verification

## Purpose

This document verifies that the IoT stack can be cleanly uninstalled and redeployed, ensuring the deployment process is reliable and repeatable.

## Uninstall Process

The uninstall script (`uninstall-iot-stack.sh`) successfully removes:

✅ **Applications:**
- Node-RED (deployment, service, configmap, PVC)
- ThingsBoard (deployment, service, configmap, PVC)
- Eclipse Ditto (Helm release)
- Eclipse Hono (Helm release)
- Eclipse Mosquitto (deployment, service, configmap, PVC)
- Ditto MongoDB service alias

✅ **Databases:**
- PostgreSQL for ThingsBoard (Helm release)
- MongoDB for Ditto (Helm release)
- MongoDB for Hono (Helm release)
- TimescaleDB (Helm release)

✅ **Storage:**
- All PVCs (with user confirmation)
- Persistent volumes

## Redeployment Process

The deployment script (`deploy-iot-stack.sh`) redeploys everything in the correct order:

1. **Phase 1:** Namespace creation and Kafka verification
2. **Phase 2:** Helm repository setup
3. **Phase 3:** Database deployment (TimescaleDB, MongoDB, PostgreSQL)
4. **Phase 4:** MQTT and device connectivity (Mosquitto, Hono)
5. **Phase 5:** Digital twins (Ditto)
6. **Phase 6:** Visualization and automation (ThingsBoard, Node-RED)

## Verification Steps

### 1. Uninstall Everything

```bash
./uninstall-iot-stack.sh
# Answer "yes" to confirm deletion
# Answer "yes" to delete PVCs (or "no" to preserve data)
# Answer "yes" to delete namespace (or "no" to keep it)
```

### 2. Verify Clean State

```bash
# Check namespace is clean
kubectl get all -n iot
kubectl get pvc -n iot
helm list -n iot

# Should show minimal or no resources
```

### 3. Redeploy Everything

```bash
./deploy-iot-stack.sh
```

### 4. Verify Deployment

```bash
# Check status
./iot-status-check.sh

# Run tests
./test-iot-stack.sh

# Verify services
./access-all.sh
```

## Known Issues & Workarounds

### Rancher Webhook Timeouts

**Issue:** Sometimes Rancher webhook causes timeouts when deleting secrets/resources.

**Workaround:** 
- Retry the uninstall if it fails
- Manually delete stuck resources if needed:
  ```bash
  kubectl delete secret -n iot <secret-name> --force --grace-period=0
  ```

### Longhorn Volume Attachment Delays

**Issue:** Some pods may take time to start due to Longhorn volume attachment.

**Workaround:**
- Wait 5-10 minutes for volumes to attach
- Check PVC status: `kubectl get pvc -n iot`
- Check pod events: `kubectl describe pod -n iot <pod-name>`

### MongoDB for Hono Volume Issues

**Issue:** MongoDB for Hono sometimes has volume attachment issues.

**Workaround:**
- Delete and recreate if stuck:
  ```bash
  helm uninstall mongodb-hono -n iot
  helm install mongodb-hono bitnami/mongodb -n iot -f mongodb-hono-values.yaml
  ```

## Success Criteria

✅ **Uninstall:**
- All Helm releases removed
- All deployments deleted
- All services removed (except default)
- All PVCs deleted (if confirmed)
- Namespace clean or deleted

✅ **Redeploy:**
- All components deployed successfully
- All pods reach Ready state
- All services accessible
- End-to-end tests pass

## Testing the Process

### Full Cycle Test

```bash
# 1. Uninstall
./uninstall-iot-stack.sh

# 2. Wait for cleanup
sleep 30

# 3. Redeploy
./deploy-iot-stack.sh

# 4. Wait for deployment
sleep 300  # 5 minutes

# 5. Verify
./test-iot-stack.sh
```

### Quick Verification

```bash
# Check if everything is deployed
./iot-status-check.sh

# Test key components
./test-iot-end-to-end.sh
```

## Troubleshooting Redeployment

### If Deployment Fails

1. **Check logs:**
   ```bash
   kubectl get events -n iot --sort-by='.lastTimestamp'
   kubectl logs -n iot <failing-pod>
   ```

2. **Check resources:**
   ```bash
   kubectl get pods,pvc,svc -n iot
   ```

3. **Retry specific component:**
   ```bash
   # Example: Retry TimescaleDB
   helm uninstall timescaledb -n iot
   helm install timescaledb timescale/timescaledb-single -n iot -f timescaledb-values.yaml
   ```

### If Uninstall Fails

1. **Force delete stuck resources:**
   ```bash
   kubectl delete deployment --all -n iot --force --grace-period=0
   kubectl delete statefulset --all -n iot --force --grace-period=0
   ```

2. **Clean up Helm releases:**
   ```bash
   helm list -n iot
   helm uninstall <release> -n iot
   ```

3. **Delete namespace (last resort):**
   ```bash
   kubectl delete namespace iot
   kubectl create namespace iot
   ```

## Best Practices

1. **Always test uninstall/redeploy** before production use
2. **Backup important data** before uninstalling (if preserving PVCs)
3. **Monitor deployment progress** using status check script
4. **Keep values files** in version control for reproducibility
5. **Document custom configurations** for easy redeployment

## Notes

- Uninstall preserves PVCs by default (user confirmation required)
- Redeployment uses same configuration files (values.yaml)
- All components are idempotent (safe to run multiple times)
- Deployment script checks for existing resources before creating

---

**Last Updated**: December 2024  
**Tested**: Uninstall and redeploy process verified

