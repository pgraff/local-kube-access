# IoT Stack Documentation Index

**Last Updated:** November 28, 2025

## Current Architecture

The IoT stack has been simplified:
- **TimescaleDB** → Removed (using ThingsBoard PostgreSQL)
- **Twin Service** → Removed (using ThingsBoard device attributes)
- **Ditto** → Removed (using ThingsBoard)

**Current Stack:**
- Mosquitto (MQTT broker)
- Hono (device gateway)
- Kafka (message broker)
- ThingsBoard (digital twin, dashboards, rules)
- PostgreSQL (storage for ThingsBoard)
- MongoDB (for Hono device registry)
- Node-RED (automation)

## Active Documentation

### Setup and Deployment
- **[iot-setup-guide.md](iot-setup-guide.md)** ⭐ **START HERE** - Complete setup guide
- **[STACK-SIMPLIFICATION-SUMMARY.md](STACK-SIMPLIFICATION-SUMMARY.md)** - Summary of recent changes
- **[PORTABLE-DEPLOYMENT.md](PORTABLE-DEPLOYMENT.md)** - Deploy to any Kubernetes cluster

### Using ThingsBoard
- **[thingsboard-as-digital-twin.md](thingsboard-as-digital-twin.md)** ⭐ **IMPORTANT** - How to use ThingsBoard for digital twins
- **[IOT-STACK-STATUS.md](IOT-STACK-STATUS.md)** - Current component status

### Testing and Troubleshooting
- **[iot-testing-guide.md](iot-testing-guide.md)** - Testing procedures
- **[IOT-STACK-FIXES.md](IOT-STACK-FIXES.md)** - Common issues and fixes

## Historical Documentation

These documents are kept for reference but reflect older architecture:

- **[MIGRATION-COMPLETE.md](MIGRATION-COMPLETE.md)** - Migration from Ditto to Twin Service (historical)
- **[migration-from-ditto.md](migration-from-ditto.md)** - Ditto migration guide (historical)
- **[kafka-twin-service-recommendation.md](kafka-twin-service-recommendation.md)** - Twin Service design (historical)
- **[ditto-alternatives-analysis.md](ditto-alternatives-analysis.md)** - Alternatives analysis (historical)
- **[cleanup-summary.md](cleanup-summary.md)** - Cleanup procedures (historical)
- **[QUICK-START-CLEANUP.md](QUICK-START-CLEANUP.md)** - Quick cleanup guide (historical)

## Access Methods

### Primary (Tailscale URLs)
- **ThingsBoard:** http://thingsboard.tailc2013b.ts.net
- **Node-RED:** http://nodered.tailc2013b.ts.net
- **Hono:** http://hono.tailc2013b.ts.net

### Fallback (Port-Forward)
```bash
./access-all.sh
# Or individual:
kubectl port-forward -n iot service/thingsboard 9090:9090
```

## Scripts

### Deployment
- `iot/scripts/deploy-iot-stack.sh` - Deploy complete stack
- `iot/scripts/uninstall-iot-stack.sh` - Remove stack
- `iot/scripts/cleanup-iot-stack.sh` - Clean up resources

### Status and Testing
- `iot/scripts/iot-status-check.sh` - Quick status check
- `iot/scripts/test-iot-stack.sh` - Comprehensive tests
- `iot/scripts/test-iot-end-to-end.sh` - End-to-end tests

### Access
- `access-all.sh` - Start all port-forwards
- `kill-access-all.sh` - Stop all port-forwards
- `iot/scripts/access-mosquitto.sh` - MQTT access

## Quick Reference

**Access ThingsBoard:**
```bash
# Primary (Tailscale):
http://thingsboard.tailc2013b.ts.net

# Fallback (port-forward):
kubectl port-forward -n iot service/thingsboard 9090:9090
# Then: http://localhost:9090
```

**Check Stack Status:**
```bash
./iot/scripts/iot-status-check.sh
```

**Deploy Stack:**
```bash
./iot/scripts/deploy-iot-stack.sh
```

