# Rancher Metrics Setup Guide

## Problem

Rancher dashboard shows: "Metrics are not available due to missing or invalid configuration."

This happens because Rancher's monitoring stack (Prometheus/Grafana) is not installed.

## Solution

Rancher needs its own monitoring stack to display metrics. You have two options:

### Option 1: Install via Rancher UI (Recommended)

1. **Log into Rancher UI**: https://rancher.tailc2013b.ts.net
2. **Navigate to**: Apps & Marketplace (or Cluster Explorer > Apps)
3. **Search for**: "Rancher Monitoring"
4. **Install**: Click "Install" and use default settings
5. **Wait**: The installation will create:
   - `cattle-monitoring-system` namespace
   - Prometheus operator
   - Prometheus server
   - Grafana
   - AlertManager

### Option 2: Install via Helm (Command Line)

```bash
# Add Rancher chart repository
helm repo add rancher-charts https://charts.rancher.io
helm repo update

# Install Rancher Monitoring
helm install rancher-monitoring rancher-charts/rancher-monitoring \
  --namespace cattle-monitoring-system \
  --create-namespace \
  --set global.cattle.url=https://rancher.tailc2013b.ts.net \
  --set global.cattle.clusterId=local
```

### Option 3: Use Existing Prometheus (Kubecost)

If you want to use the existing Kubecost Prometheus instead:

1. **Note**: This requires configuration changes and may not work perfectly
2. **Better**: Install dedicated Rancher Monitoring stack

## Verification

After installation, verify:

```bash
# Check monitoring namespace exists
kubectl get namespace cattle-monitoring-system

# Check Prometheus is running
kubectl get pods -n cattle-monitoring-system | grep prometheus

# Check Grafana is running
kubectl get pods -n cattle-monitoring-system | grep grafana
```

## What Gets Installed

- **Prometheus Operator**: Manages Prometheus instances
- **Prometheus Server**: Collects metrics from the cluster
- **Grafana**: Visualization and dashboards
- **AlertManager**: Handles alerts
- **Node Exporter**: Collects node-level metrics
- **Kube State Metrics**: Collects Kubernetes object metrics

## Resource Requirements

Rancher Monitoring requires:
- **CPU**: ~2-4 cores
- **Memory**: ~4-8 GB
- **Storage**: ~50-100 GB for metrics retention

## After Installation

1. **Wait 5-10 minutes** for all components to start
2. **Refresh Rancher dashboard** - metrics should appear
3. **Check Grafana**: Access via Rancher UI or port-forward:
   ```bash
   kubectl port-forward -n cattle-monitoring-system svc/rancher-monitoring-grafana 3000:80
   # Then open: http://localhost:3000
   ```

## Troubleshooting

### Metrics Still Not Showing

1. **Check Prometheus targets**:
   ```bash
   kubectl port-forward -n cattle-monitoring-system svc/rancher-monitoring-prometheus 9090:9090
   # Open: http://localhost:9090
   # Go to: Status > Targets
   ```

2. **Check ServiceMonitor resources**:
   ```bash
   kubectl get servicemonitor -A
   ```

3. **Check Rancher logs**:
   ```bash
   kubectl logs -n cattle-system -l app=rancher --tail=50
   ```

### Installation Fails

1. **Check resource availability**:
   ```bash
   kubectl top nodes
   kubectl top pods -A
   ```

2. **Check storage classes**:
   ```bash
   kubectl get storageclass
   ```

3. **Review installation logs**:
   ```bash
   kubectl get events -n cattle-monitoring-system --sort-by='.lastTimestamp'
   ```

## Notes

- **Kubecost Prometheus**: The existing `kubecost-prometheus-server` is separate and used only for Kubecost cost analysis
- **Dedicated Stack**: Rancher needs its own monitoring stack for dashboard metrics
- **Resource Usage**: Monitoring stack uses significant resources - ensure cluster has capacity

