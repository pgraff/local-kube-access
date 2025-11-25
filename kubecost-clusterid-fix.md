# Fixing Kubecost clusterId Error

## Problem
Kubecost installation fails with:
```
Error: INSTALLATION FAILED: execution error at (cost-analyzer/charts/finopsagent/templates/deployment.yaml:161:25): 
clusterId is required. Please set .Values.global.clusterId
```

## Solution

You need to set the `global.clusterId` value when installing Kubecost through Rancher.

### Option 1: Set via Rancher UI (Recommended)

1. In Rancher, go to the App installation page for Kubecost
2. Before clicking "Install", click on "Edit YAML" or "Values" tab
3. Add the following to the values:

```yaml
global:
  clusterId: "local"
```

Or use a more unique identifier:

```yaml
global:
  clusterId: "8dc25c26-ab6a-46f4-aa44-ec765261545f"
```

### Option 2: Use kubectl to install directly

If you prefer to install via command line:

```bash
helm install cost-analyzer \
  --namespace default \
  --create-namespace \
  --set global.clusterId=local \
  /path/to/cost-analyzer-2.9.3.tgz
```

### Cluster Identifiers Available

- **Rancher Cluster Name**: `local`
- **Namespace UID**: `8dc25c26-ab6a-46f4-aa44-ec765261545f`
- **First Node UID**: `fd70705d-f9bf-4f32-9479-560b0a369457`

Any of these can be used as the clusterId. The Rancher cluster name (`local`) is the simplest option.

## After Setting clusterId

1. Save the values in Rancher
2. Click "Install" again
3. Kubecost should install successfully

