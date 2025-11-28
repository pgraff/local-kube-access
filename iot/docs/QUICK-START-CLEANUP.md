# Quick Start: Clean Up Ditto and Prepare for Twin Service

## TL;DR

```bash
# 1. Clean up Ditto (interactive - will ask for confirmation)
cd /Users/pettergraff/s/k8s-home
./iot/scripts/cleanup-ditto.sh

# 2. Verify cleanup
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml
kubectl get deployments -n iot | grep -v ditto
helm list -n iot | grep -v ditto

# 3. Build and deploy twin service (when ready)
# See: iot/docs/kafka-twin-service-recommendation.md
```

## What Gets Removed

- ✅ Ditto Helm release
- ✅ All Ditto deployments (connectivity, things, gateway, etc.)
- ✅ MongoDB for Ditto Helm release
- ✅ MongoDB for Ditto resources
- ✅ MongoDB for Ditto PVC (20Gi) - optional

## What Stays

- ✅ Mosquitto (MQTT broker)
- ✅ Hono (device connectivity)
- ✅ ThingsBoard (dashboards)
- ✅ Node-RED (automation)
- ✅ TimescaleDB (telemetry storage)
- ✅ PostgreSQL for ThingsBoard
- ✅ MongoDB for Hono

## Next Steps

1. **Run cleanup** (see above)
2. **Build twin service** - Follow `iot/docs/kafka-twin-service-recommendation.md`
3. **Deploy twin service** - Run `./iot/scripts/deploy-twin-service.sh`
4. **Update integrations** - Point ThingsBoard/Node-RED to new service

## Files Created

- `iot/scripts/cleanup-ditto.sh` - Interactive cleanup
- `iot/scripts/cleanup-ditto-noninteractive.sh` - Non-interactive cleanup
- `iot/scripts/deploy-twin-service.sh` - Deploy twin service
- `iot/twin-service/k8s/deployment.yaml` - Kubernetes deployment
- `iot/twin-service/k8s/ingress.yaml` - Ingress configuration
- `iot/docs/migration-from-ditto.md` - Full migration guide
- `iot/docs/kafka-twin-service-recommendation.md` - Implementation guide

