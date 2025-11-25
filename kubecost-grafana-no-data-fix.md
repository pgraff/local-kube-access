# Kubecost Grafana - No Data Issue

## Problem

Grafana is accessible, but dashboards show no data. Prometheus appears to be running and scraping metrics.

## Diagnosis

### 1. Verify Prometheus Connection

Grafana can connect to Prometheus. The datasource is configured correctly:
- **Datasource URL**: `http://kubecost-prometheus-server.kubecost.svc`
- **Service**: `kubecost-prometheus-server` on port 80 (forwards to Prometheus port 9090)

### 2. Check Prometheus Has Data

Prometheus is actively scraping metrics:
- ✅ `kubecost` job: Scraping successfully
- ✅ `kubecost-aggregator` job: Scraping successfully
- ✅ Node metrics: Being collected

### 3. Common Causes

#### A. Insufficient Historical Data

**Most Likely Cause**: Prometheus was recently restarted or the cluster is new, so there isn't enough historical data yet.

**Solution**: Wait for Prometheus to collect more data (15-30 minutes minimum).

#### B. Time Range Too Narrow

Grafana dashboards might be set to a time range where no data exists.

**Solution**: 
1. In Grafana, check the time range selector (top right)
2. Set it to "Last 1 hour" or "Last 6 hours"
3. Ensure "Auto-refresh" is enabled

#### C. Missing Metrics

Some dashboards require specific metrics that might not be available yet.

**Solution**: Check if required metrics exist in Prometheus.

## Troubleshooting Steps

### Step 1: Verify Prometheus Has Data

```bash
# Port-forward to Prometheus
kubectl port-forward -n kubecost svc/kubecost-prometheus-server 9091:80

# Then open: http://localhost:9091
# Go to Status > Targets - should show all targets as "UP"
# Go to Graph - try query: `up`
```

### Step 2: Test Grafana Datasource

1. In Grafana UI, go to **Configuration > Data Sources**
2. Click on **Prometheus** datasource
3. Click **Test** button
4. Should show: "Data source is working"

### Step 3: Check Time Range

1. In any Grafana dashboard
2. Click the time range selector (top right)
3. Set to **"Last 1 hour"** or **"Last 6 hours"**
4. Click **Apply**

### Step 4: Test a Simple Query

1. In Grafana, go to **Explore** (compass icon on left)
2. Select **Prometheus** datasource
3. Try query: `up`
4. Click **Run query**
5. You should see data points

### Step 5: Check Kubecost-Specific Metrics

Try these queries in Grafana Explore:

```promql
# Check if Kubecost metrics exist
kubecost_cluster_management_cost

# Check node metrics
node_cpu_seconds_total

# Check container metrics
container_cpu_usage_seconds_total
```

If these return "No data", Prometheus might not have collected enough data yet.

## Solutions

### Solution 1: Wait for Data Collection (Recommended)

Kubecost and Prometheus need time to collect metrics:

1. **Minimum wait time**: 15-30 minutes after installation
2. **For full data**: 1-2 hours for comprehensive metrics
3. **For cost data**: Kubecost needs to analyze cluster resources first

**What to do**:
- Wait 30 minutes
- Refresh Grafana dashboards
- Check time range is set correctly

### Solution 2: Verify Prometheus Targets

```bash
# Check Prometheus targets
kubectl port-forward -n kubecost svc/kubecost-prometheus-server 9091:80
# Open http://localhost:9091/targets
# All targets should be "UP"
```

### Solution 3: Check Prometheus Storage

```bash
# Check if Prometheus has storage
kubectl get pvc -n kubecost | grep prometheus

# If no PVC, Prometheus is using emptyDir (ephemeral)
# This means data is lost on pod restart
```

**Note**: If Prometheus is using `emptyDir` storage (as configured in your setup), data is ephemeral and will be lost on pod restart. This is fine for testing but not ideal for production.

### Solution 4: Restart Prometheus (if needed)

If Prometheus seems stuck:

```bash
# Restart Prometheus pod
kubectl delete pod -n kubecost -l app=prometheus

# Wait for it to restart
kubectl get pods -n kubecost -l app=prometheus -w
```

**Warning**: This will lose all historical data if using `emptyDir` storage.

### Solution 5: Check Kubecost Cost Analyzer

Ensure Kubecost cost analyzer is running and collecting data:

```bash
# Check Kubecost pods
kubectl get pods -n kubecost

# Check Kubecost logs
kubectl logs -n kubecost -l app=cost-analyzer --tail=50
```

Look for:
- No errors
- "Metrics server ready" messages
- Successful metric collection

## Expected Timeline

After a fresh Kubecost installation:

- **0-15 minutes**: Basic metrics start appearing
- **15-30 minutes**: Node and pod metrics available
- **30-60 minutes**: Cost data begins to populate
- **1-2 hours**: Full dashboard data available

## Quick Verification

Run this to check if Prometheus has any data:

```bash
# Test Prometheus query from Grafana pod
kubectl exec -n kubecost $(kubectl get pod -n kubecost -l app=grafana -o jsonpath='{.items[0].metadata.name}') \
  --container=grafana \
  -- wget -qO- 'http://kubecost-prometheus-server.kubecost.svc/api/v1/query?query=up' | \
  python3 -m json.tool | head -20
```

If this returns data, Prometheus is working. The issue is likely:
1. Time range in Grafana
2. Not enough historical data yet
3. Dashboard queries looking for specific metrics that don't exist

## Accessing Prometheus Directly

To verify Prometheus directly:

```bash
# Port-forward to Prometheus
kubectl port-forward -n kubecost svc/kubecost-prometheus-server 9091:80

# Open in browser: http://localhost:9091
# Try queries:
# - up
# - kubecost_cluster_management_cost
# - node_cpu_seconds_total
```

## Next Steps

1. ✅ Verify Prometheus has data (see above)
2. ✅ Check Grafana time range (set to "Last 1 hour")
3. ✅ Wait 30 minutes for data collection
4. ✅ Test queries in Grafana Explore
5. ✅ Check if specific dashboards need different metrics

## Related Documentation

- [Kubecost Grafana Fix](kubecost-grafana-fix.md) - Fix for 502 Bad Gateway
- [Kubecost Cluster ID Fix](kubecost-clusterid-fix.md) - Initial installation troubleshooting

