# Kubecost Grafana - Prometheus Metrics Not Showing

## Problem

Grafana can connect to Prometheus, but when selecting Prometheus metrics, no values are displayed in dashboards.

## Current Status

✅ **Prometheus is working:**
- Prometheus pod is Running
- 31 active targets being scraped
- Kubecost and kubecost-aggregator jobs are "up"
- Metrics are being collected

✅ **Grafana connection:**
- Datasource configured correctly: `http://kubecost-prometheus-server.kubecost.svc`
- Connection test should pass

## Common Causes and Solutions

### 1. Time Range Issue (Most Common)

**Problem**: Grafana dashboards default to "Last 6 hours" or "Last 1 hour", but if Prometheus was recently restarted or metrics are sparse, there may not be data in that range.

**Solution**:
1. In Grafana, click the time range selector (top right)
2. Change to **"Last 5 minutes"** or **"Last 15 minutes"**
3. Click **Apply**
4. Enable **Auto-refresh** (dropdown next to time selector) and set to 10s or 30s

**Why this works**: Prometheus collects metrics continuously, but dashboards need to query the right time range. Starting with a shorter range ensures you see recent data.

### 2. Metric Values Are Zero

**Problem**: Some metrics exist but have value `0`, which may appear as "no data" in some visualizations.

**Check**:
```bash
# Port-forward to Prometheus
kubectl port-forward -n kubecost svc/kubecost-prometheus-server 9091:80

# Query a specific metric
curl 'http://localhost:9091/api/v1/query?query=kubecost_cluster_management_cost'
```

**Solution**: 
- Zero values are valid - they indicate no cost yet
- Wait for Kubecost to calculate costs (can take 15-30 minutes)
- Check if workloads are actually running and consuming resources

### 3. Dashboard Query Issues

**Problem**: The dashboard queries might be looking for metrics that don't exist or use different names.

**Solution**:
1. In Grafana, go to **Explore** (compass icon)
2. Select **Prometheus** datasource
3. Try these test queries:
   ```promql
   # Basic test
   up
   
   # Kubecost metrics
   kubecost_cluster_management_cost
   
   # Container metrics
   container_cpu_usage_seconds_total
   
   # Node metrics
   node_cpu_seconds_total
   ```
4. If queries return data in Explore but not in dashboards, the dashboard queries may need adjustment

### 4. Prometheus Storage Retention

**Problem**: If Prometheus is using `emptyDir` storage (ephemeral), data is lost on pod restart.

**Check**:
```bash
kubectl get pvc -n kubecost | grep prometheus
```

**If no PVC exists**: Prometheus data is ephemeral and will be lost on restart. This is fine for testing but means:
- Historical data may be limited
- After pod restart, you need to wait for new data collection

**Solution**: For production, configure persistent storage for Prometheus.

### 5. Metric Collection Delay

**Problem**: Kubecost needs time to:
1. Discover cluster resources
2. Collect metrics from nodes/pods
3. Calculate costs
4. Export to Prometheus

**Timeline**:
- **0-5 minutes**: Basic metrics start appearing
- **5-15 minutes**: Node and pod metrics available
- **15-30 minutes**: Cost calculations begin
- **30-60 minutes**: Full cost data available

**Solution**: Be patient and check again after 30 minutes.

## Step-by-Step Troubleshooting

### Step 1: Verify Prometheus Has Data

```bash
# Port-forward to Prometheus
kubectl port-forward -n kubecost svc/kubecost-prometheus-server 9091:80

# Open in browser: http://localhost:9091
# Go to Status > Targets - should show targets as "up"
# Go to Graph - try query: `up`
```

### Step 2: Test Grafana Datasource

1. In Grafana UI, go to **Configuration > Data Sources**
2. Click on **Prometheus** datasource
3. Click **Save & Test**
4. Should show: "Data source is working"

### Step 3: Test Queries in Grafana Explore

1. In Grafana, go to **Explore** (compass icon on left)
2. Select **Prometheus** datasource
3. Try query: `up`
4. Set time range to **"Last 5 minutes"**
5. Click **Run query**
6. You should see data points

### Step 4: Check Specific Kubecost Metrics

In Grafana Explore, try:
```promql
# Check if Kubecost metrics exist
kubecost_cluster_management_cost

# Check container metrics
container_cpu_usage_seconds_total

# Check node metrics  
node_cpu_seconds_total
```

If these return data in Explore but not in dashboards, the issue is with the dashboard queries or time range.

### Step 5: Check Dashboard Time Range

1. Open any dashboard showing "no data"
2. Click time range selector (top right)
3. Set to **"Last 5 minutes"** or **"Last 15 minutes"**
4. Click **Apply**
5. Enable **Auto-refresh** (10s or 30s)

### Step 6: Verify Kubecost is Collecting Data

```bash
# Check Kubecost cost-analyzer logs
kubectl logs -n kubecost -l app=cost-analyzer --container=cost-model --tail=50

# Look for:
# - "Metrics server ready"
# - No errors
# - Successful metric collection messages
```

## Quick Fixes

### Fix 1: Adjust Time Range

**In Grafana Dashboard:**
1. Click time selector (top right)
2. Select **"Last 5 minutes"**
3. Click **Apply**
4. Enable **Auto-refresh** → **10s**

### Fix 2: Test in Explore First

Before using dashboards:
1. Go to **Explore**
2. Test queries manually
3. Verify data exists
4. Then check dashboards with correct time range

### Fix 3: Wait for Data Collection

If Prometheus was recently restarted:
- Wait 15-30 minutes
- Check again with appropriate time range
- Enable auto-refresh

## Advanced Troubleshooting

### Check Prometheus Targets

```bash
kubectl port-forward -n kubecost svc/kubecost-prometheus-server 9091:80
# Open http://localhost:9091/targets
# All targets should be "up"
```

### Check Available Metrics

```bash
kubectl port-forward -n kubecost svc/kubecost-prometheus-server 9091:80
# Open http://localhost:9091
# Go to Graph
# Type: kubecost_cluster_management_cost
# Execute query
```

### Check Prometheus Storage

```bash
# Check if Prometheus has persistent storage
kubectl get pvc -n kubecost | grep prometheus

# Check Prometheus pod storage
kubectl describe pod -n kubecost -l app=prometheus | grep -A 5 "Volumes:"
```

## Expected Behavior

### What You Should See

1. **In Grafana Explore:**
   - Queries like `up` should return data immediately
   - Container/node metrics should appear within 5-15 minutes
   - Kubecost cost metrics may take 15-30 minutes

2. **In Dashboards:**
   - After setting correct time range, data should appear
   - Auto-refresh keeps data current
   - Some panels may show "No data" if metrics don't exist yet

### What's Normal

- **Zero values**: Valid - means no cost/resource usage yet
- **Sparse data**: Normal in new clusters - data fills in over time
- **Some metrics missing**: Some dashboards query metrics that may not exist yet

## Still Not Working?

If after trying all above steps you still see no data:

1. **Check Prometheus directly:**
   ```bash
   kubectl port-forward -n kubecost svc/kubecost-prometheus-server 9091:80
   # Open http://localhost:9091
   # Try queries directly in Prometheus UI
   ```

2. **Verify Grafana datasource URL:**
   - Should be: `http://kubecost-prometheus-server.kubecost.svc`
   - Not: `http://kubecost-prometheus-server.kubecost.svc:9090`

3. **Check for network policies:**
   ```bash
   kubectl get networkpolicies -n kubecost
   # Should allow Grafana to reach Prometheus
   ```

4. **Restart Grafana pod:**
   ```bash
   kubectl delete pod -n kubecost -l app=grafana
   # Wait for it to restart
   ```

## Related Documentation

- [Kubecost Grafana Fix](kubecost-grafana-fix.md) - Fix for 502 Bad Gateway
- [Kubecost Grafana No Data Fix](kubecost-grafana-no-data-fix.md) - General no data troubleshooting

