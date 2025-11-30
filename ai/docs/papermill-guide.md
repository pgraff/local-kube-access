# Papermill Guide

This guide explains how to execute notebooks programmatically using Papermill in the AI workspace.

## Overview

Papermill allows you to:
- Execute notebooks with parameters
- Run notebooks headlessly (without UI)
- Save outputs to PVC or MinIO
- Integrate notebooks into workflows and pipelines

## Prerequisites

- Notebook with parameterized cells (tagged with `parameters`)
- Access to the notebook file (in PVC or MinIO)
- Kubernetes cluster access

## Quick Start

### Execute Notebook via Script

```bash
./ai/scripts/run-notebook.sh \
  /home/jovyan/work/input.ipynb \
  /home/jovyan/work/output.ipynb \
  '{"param1":"value1","param2":42}' \
  claim-username \
  false
```

**Arguments:**
1. Input notebook path
2. Output notebook path
3. Parameters (JSON string)
4. PVC name (e.g., `claim-username`)
5. Output to MinIO (`true` or `false`)

## Creating Parameterized Notebooks

### Tag Cells as Parameters

1. Open notebook in JupyterLab
2. Select a cell
3. Go to View → Cell Toolbar → Tags
4. Add tag: `parameters`

### Example Parameterized Notebook

```python
# Cell tagged with "parameters"
param1 = "default_value"
param2 = 42
param3 = [1, 2, 3]

# Rest of notebook uses these parameters
result = param1 * param2
print(f"Result: {result}")
```

## Execution Methods

### 1. Kubernetes Job (Manual)

**Using the script:**
```bash
./ai/scripts/run-notebook.sh \
  /home/jovyan/work/notebook.ipynb \
  /home/jovyan/work/output.ipynb \
  '{"epochs":10,"learning_rate":0.001}' \
  claim-username \
  false
```

**Using kubectl directly:**
```bash
# Create job from template
kubectl create job my-notebook-job \
  --from=job/papermill-job-template \
  -n ai

# Set parameters
kubectl set env job/my-notebook-job \
  NOTEBOOK_PATH=/home/jovyan/work/input.ipynb \
  OUTPUT_PATH=/home/jovyan/work/output.ipynb \
  PARAMETERS='{"param1":"value1"}' \
  -n ai

# Update PVC
kubectl patch job/my-notebook-job -n ai -p '{
  "spec": {
    "template": {
      "spec": {
        "volumes": [{
          "name": "user-pvc",
          "persistentVolumeClaim": {
            "claimName": "claim-username"
          }
        }]
      }
    }
  }
}'

# Wait for completion
kubectl wait --for=condition=complete job/my-notebook-job -n ai --timeout=600s

# View logs
kubectl logs job/my-notebook-job -n ai
```

### 2. CronJob (Scheduled)

**Using the script:**
```bash
./ai/scripts/create-scheduled-notebook.sh \
  daily-report \
  "0 9 * * *" \
  /home/jovyan/work/report.ipynb \
  /home/jovyan/work/output.ipynb \
  '{"date":"today"}' \
  claim-username \
  false
```

**Schedule Examples:**
- `"0 9 * * *"` - Daily at 9 AM UTC
- `"0 */6 * * *"` - Every 6 hours
- `"0 0 * * 1"` - Every Monday at midnight
- `"*/30 * * * *"` - Every 30 minutes

**View CronJob:**
```bash
kubectl get cronjobs -n ai
kubectl describe cronjob daily-report -n ai
```

**View Jobs created by CronJob:**
```bash
kubectl get jobs -n ai -l app=papermill
```

**View logs:**
```bash
# Get latest job name
JOB=$(kubectl get jobs -n ai -l app=papermill --sort-by=.metadata.creationTimestamp -o name | tail -1)
kubectl logs $JOB -n ai
```

### 3. Argo Workflows

See [Argo Workflows Guide](argo-workflows-guide.md) for detailed examples.

## Output Options

### Save to PVC (Local Storage)

Output is saved to the user's PVC:
```bash
./ai/scripts/run-notebook.sh \
  /home/jovyan/work/input.ipynb \
  /home/jovyan/work/output.ipynb \
  '{}' \
  claim-username \
  false  # Save to PVC
```

### Save to MinIO

Output is saved to MinIO bucket:
```bash
./ai/scripts/run-notebook.sh \
  /home/jovyan/work/input.ipynb \
  outputs/report.ipynb \
  '{}' \
  claim-username \
  true  # Save to MinIO
```

**Note**: When saving to MinIO, a timestamp is automatically added to the filename.

## Parameter Formats

### Simple Parameters

```json
{"param1": "value1", "param2": 42}
```

### Complex Parameters

```json
{
  "epochs": 10,
  "learning_rate": 0.001,
  "batch_size": 32,
  "model_name": "resnet50",
  "data_path": "/home/jovyan/work/data.csv"
}
```

### Lists and Nested Objects

```json
{
  "layers": [64, 128, 256],
  "config": {
    "optimizer": "adam",
    "loss": "categorical_crossentropy"
  }
}
```

## Viewing Results

### From PVC

Access the output notebook from JupyterHub:
1. Open JupyterHub
2. Navigate to the output path
3. Open the `.ipynb` file

### From MinIO

1. Access MinIO Console: http://minio.tailc2013b.ts.net
2. Login with `minioadmin` / `minioadmin`
3. Navigate to `notebook-artifacts` bucket
4. Download the output file

### From Logs

```bash
# Get job logs
kubectl logs job/<job-name> -n ai

# Follow logs in real-time
kubectl logs -f job/<job-name> -n ai
```

## Best Practices

1. **Tag parameter cells**: Always tag cells with `parameters` tag
2. **Use descriptive names**: Name parameters clearly
3. **Validate inputs**: Add validation in your notebooks
4. **Handle errors**: Use try/except blocks
5. **Log outputs**: Print important results
6. **Save artifacts**: Save models, plots, and data to MinIO

## Troubleshooting

### Job Fails

1. Check job status:
   ```bash
   kubectl get job <job-name> -n ai
   ```

2. View logs:
   ```bash
   kubectl logs job/<job-name> -n ai
   ```

3. Check pod events:
   ```bash
   kubectl describe job <job-name> -n ai
   ```

### Parameters Not Applied

- Verify cell is tagged with `parameters`
- Check parameter JSON syntax
- Verify parameter names match notebook variables

### Output Not Saved

- Check output path exists
- Verify PVC is mounted correctly
- Check MinIO credentials if saving to MinIO
- Review job logs for errors

### Timeout

Jobs have a default timeout. For long-running notebooks:
- Increase job timeout
- Break notebook into smaller steps
- Use Argo Workflows for complex pipelines

## Related Documentation

- [AI Workspace Setup](ai-workspace-setup.md)
- [JupyterHub Guide](jupyterhub-guide.md)
- [Argo Workflows Guide](argo-workflows-guide.md)
- [MinIO Guide](minio-guide.md)

