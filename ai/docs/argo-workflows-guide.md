# Argo Workflows Guide

This guide explains how to use Argo Workflows for orchestrating notebook execution pipelines.

## Overview

Argo Workflows provides:
- Workflow orchestration
- DAG (Directed Acyclic Graph) support
- Reusable templates
- Multi-step pipelines
- Parallel execution

## Access

### Primary Access (Recommended)

**URL**: http://argo.tailc2013b.ts.net

### Fallback Access

```bash
kubectl port-forward -n argo svc/argo-workflows-server 2746:2746
# Then open: http://localhost:2746
```

## Quick Start

### Execute Simple Notebook Workflow

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: notebook-workflow-
  namespace: ai
spec:
  entrypoint: papermill-notebook
  templates:
  - name: papermill-notebook
    templateRef:
      name: papermill-template
      template: papermill-execution
    arguments:
      parameters:
      - name: notebook-path
        value: "/home/jovyan/work/input.ipynb"
      - name: output-path
        value: "/home/jovyan/work/output.ipynb"
      - name: parameters
        value: '{"param1":"value1"}'
      - name: pvc-name
        value: "claim-username"
      - name: output-to-minio
        value: "false"
```

Apply:
```bash
kubectl create -f workflow.yaml -n ai
```

## Using Pre-built Templates

### Papermill Template

The `papermill-template` is pre-installed and ready to use:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: simple-notebook-
  namespace: ai
spec:
  entrypoint: execute-notebook
  templates:
  - name: execute-notebook
    templateRef:
      name: papermill-template
      template: papermill-execution
    arguments:
      parameters:
      - name: notebook-path
        value: "/home/jovyan/work/my-notebook.ipynb"
      - name: output-path
        value: "/home/jovyan/work/output.ipynb"
      - name: pvc-name
        value: "claim-username"
```

### DAG Pipeline Template

Use the pre-built DAG template for multi-step pipelines:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: notebook-pipeline-
  namespace: ai
spec:
  entrypoint: notebook-pipeline
  templates:
  - name: notebook-pipeline
    templateRef:
      name: notebook-dag-pipeline
      template: notebook-pipeline
```

**Note**: Update PVC names in the template before using.

## Creating Custom Workflows

### Simple Sequential Workflow

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: sequential-notebooks-
  namespace: ai
spec:
  entrypoint: pipeline
  templates:
  - name: pipeline
    steps:
    - - name: step1
        templateRef:
          name: papermill-template
          template: papermill-execution
        arguments:
          parameters:
          - name: notebook-path
            value: "/home/jovyan/work/step1.ipynb"
          - name: output-path
            value: "/home/jovyan/work/step1-output.ipynb"
          - name: pvc-name
            value: "claim-username"
    - - name: step2
        templateRef:
          name: papermill-template
          template: papermill-execution
        arguments:
          parameters:
          - name: notebook-path
            value: "/home/jovyan/work/step2.ipynb"
          - name: output-path
            value: "/home/jovyan/work/step2-output.ipynb"
          - name: pvc-name
            value: "claim-username"
```

### DAG Workflow (Parallel Execution)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: parallel-notebooks-
  namespace: ai
spec:
  entrypoint: parallel-pipeline
  templates:
  - name: parallel-pipeline
    dag:
      tasks:
      - name: notebook1
        templateRef:
          name: papermill-template
          template: papermill-execution
        arguments:
          parameters:
          - name: notebook-path
            value: "/home/jovyan/work/notebook1.ipynb"
          - name: output-path
            value: "/home/jovyan/work/output1.ipynb"
          - name: pvc-name
            value: "claim-username"
      - name: notebook2
        templateRef:
          name: papermill-template
          template: papermill-execution
        arguments:
          parameters:
          - name: notebook-path
            value: "/home/jovyan/work/notebook2.ipynb"
          - name: output-path
            value: "/home/jovyan/work/output2.ipynb"
          - name: pvc-name
            value: "claim-username"
      - name: aggregate
        dependencies: [notebook1, notebook2]
        templateRef:
          name: papermill-template
          template: papermill-execution
        arguments:
          parameters:
          - name: notebook-path
            value: "/home/jovyan/work/aggregate.ipynb"
          - name: output-path
            value: "/home/jovyan/work/final-output.ipynb"
          - name: pvc-name
            value: "claim-username"
```

### Workflow with Parameters

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: parameterized-workflow-
  namespace: ai
spec:
  entrypoint: main
  arguments:
    parameters:
    - name: epochs
      value: "10"
    - name: learning-rate
      value: "0.001"
  templates:
  - name: main
    templateRef:
      name: papermill-template
      template: papermill-execution
    arguments:
      parameters:
      - name: notebook-path
        value: "/home/jovyan/work/train.ipynb"
      - name: output-path
        value: "/home/jovyan/work/train-output.ipynb"
      - name: parameters
        value: "{{workflow.parameters.epochs}},{{workflow.parameters.learning-rate}}"
      - name: pvc-name
        value: "claim-username"
```

## Workflow Management

### List Workflows

```bash
kubectl get workflows -n ai
```

### View Workflow Details

```bash
kubectl get workflow <workflow-name> -n ai -o yaml
```

### View Workflow Status

```bash
kubectl describe workflow <workflow-name> -n ai
```

### View Workflow Logs

```bash
# Get logs from UI or
kubectl logs <workflow-name>-<node-id> -n ai -c main
```

### Delete Workflow

```bash
kubectl delete workflow <workflow-name> -n ai
```

## Using the UI

1. **Access UI**: http://argo.tailc2013b.ts.net
2. **Submit Workflow**: Upload YAML file or create from template
3. **Monitor**: View workflow progress in real-time
4. **Logs**: Click on nodes to view logs
5. **Artifacts**: Download outputs from completed workflows

## Best Practices

1. **Use templates**: Reuse the papermill-template for consistency
2. **Parameterize**: Use workflow parameters for flexibility
3. **Error handling**: Add retry policies for critical steps
4. **Resource limits**: Set appropriate resource requests/limits
5. **Output management**: Save important outputs to MinIO
6. **Version control**: Store workflow definitions in git

## Troubleshooting

### Workflow Not Starting

1. Check workflow status:
   ```bash
   kubectl get workflow <workflow-name> -n ai
   ```

2. Check events:
   ```bash
   kubectl describe workflow <workflow-name> -n ai
   ```

3. Verify template exists:
   ```bash
   kubectl get workflowtemplate -n ai
   ```

### Template Not Found

Ensure templates are deployed:
```bash
kubectl apply -f ai/k8s/argo-papermill-template.yaml -n ai
kubectl apply -f ai/k8s/argo-dag-template.yaml -n ai
```

### PVC Mount Issues

- Verify PVC name is correct
- Check PVC exists: `kubectl get pvc -n ai`
- Ensure PVC is in the same namespace

### Workflow Hangs

- Check pod status: `kubectl get pods -n ai`
- View logs: `kubectl logs <pod-name> -n ai`
- Check resource limits

## Related Documentation

- [AI Workspace Setup](ai-workspace-setup.md)
- [Papermill Guide](papermill-guide.md)
- [MinIO Guide](minio-guide.md)

