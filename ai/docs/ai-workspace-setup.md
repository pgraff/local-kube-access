# AI Workspace Setup Guide

This guide covers the complete setup and deployment of the AI workspace, including JupyterHub, MinIO, Argo Workflows, and notebook execution infrastructure.

## Overview

The AI workspace provides:
- **JupyterHub**: Multi-user Jupyter notebook environment
- **MinIO**: S3-compatible object storage for notebook artifacts
- **Argo Workflows**: Workflow orchestration for notebook pipelines
- **Papermill**: Parameterized notebook execution
- **Kubernetes CronJobs**: Scheduled notebook execution

## Architecture

```
Users → JupyterHub → Notebook Pods (10GB PVC each)
                          │
                          ├──> Papermill Jobs
                          ├──> CronJobs (scheduled)
                          └──> Argo Workflows
                                    │
                                    └──> MinIO (notebook-artifacts bucket)
```

## Prerequisites

- Kubernetes cluster (RKE2)
- kubectl configured
- Helm 3.x installed
- Access to cluster (kubeconfig)
- Tailscale configured (for URL-based access)

## Quick Start

### 1. Deploy Complete Stack

```bash
cd /Users/pettergraff/s/k8s-home
./ai/scripts/deploy-ai-stack.sh
```

This will deploy:
1. MinIO with `notebook-artifacts` bucket
2. Argo Workflows
3. JupyterHub
4. Argo Workflow templates

### 2. Access Services

**Primary (Tailscale URLs):**
- **JupyterHub**: http://jupyterhub.tailc2013b.ts.net
- **Argo Workflows**: http://argo.tailc2013b.ts.net
- **MinIO Console**: http://minio.tailc2013b.ts.net

**Fallback (Port-Forward):**
```bash
./access-all.sh
```

### 3. Login to JupyterHub

- **URL**: http://jupyterhub.tailc2013b.ts.net
- **Username**: Any (dummy authenticator)
- **Password**: `jupyterhub`

## Component Details

### JupyterHub

**Features:**
- Dummy authenticator (any username/password works)
- Python 3.10+ with conda and pip
- 10GB persistent storage per user (Longhorn)
- Pre-installed: Papermill, boto3, s3fs (MinIO client)
- Access to cluster services

**User Storage:**
- Each user gets a dedicated PVC: `claim-<username>`
- Storage class: `longhorn`
- Size: 10GB
- Access mode: ReadWriteOnce

**Configuration:**
- Default interface: JupyterLab
- Image: `jupyter/scipy-notebook:python-3.10`
- Resource limits: 4Gi memory, 2000m CPU

### MinIO

**Configuration:**
- Endpoint: `minio.ai.svc.cluster.local:9000`
- Bucket: `notebook-artifacts`
- Access Key: `minioadmin`
- Secret Key: `minioadmin`
- Storage: 50Gi PVC (Longhorn)

**Usage:**
- Store notebook outputs (PDF, HTML, CSV, PNG)
- Accessible from JupyterHub notebooks
- Accessible from Papermill jobs
- Accessible from Argo Workflows

### Argo Workflows

**Features:**
- Workflow orchestration
- DAG support for multi-step pipelines
- Reusable templates for Papermill execution
- Web UI for workflow management

**Namespace:** `argo`

**Templates:**
- `papermill-template`: Reusable template for notebook execution
- `notebook-dag-pipeline`: Example DAG with multiple notebook steps
- `notebook-parallel-pipeline`: Example parallel execution

### Papermill

**Features:**
- Parameterized notebook execution
- Headless execution
- Output to PVC or MinIO
- CLI available in all execution containers

**Usage:**
- Via Kubernetes Jobs (manual)
- Via CronJobs (scheduled)
- Via Argo Workflows (orchestrated)

## Deployment Phases

### Phase 1: Namespace

```bash
kubectl apply -f ai/k8s/ai-namespace.yaml
```

### Phase 2: MinIO

```bash
./ai/scripts/deploy-minio.sh
```

This creates:
- MinIO deployment with PVC
- Secret with credentials
- ConfigMap with endpoint info
- Service and Ingress
- `notebook-artifacts` bucket

### Phase 3: Argo Workflows

```bash
./ai/scripts/deploy-argo-workflows.sh
```

This installs:
- Argo Workflows via Helm
- Workflow controller
- UI server
- Ingress for UI

### Phase 4: JupyterHub

```bash
./ai/scripts/deploy-jupyterhub.sh
```

This installs:
- JupyterHub via Helm (Zero-to-JupyterHub)
- Hub pod
- Proxy service
- User spawner
- Ingress

### Phase 5: Templates

```bash
kubectl apply -f ai/k8s/argo-papermill-template.yaml
kubectl apply -f ai/k8s/argo-dag-template.yaml
```

## Verification

### Check Status

```bash
./ai/scripts/ai-status-check.sh
```

### Verify Components

```bash
# JupyterHub
kubectl get pods -n ai -l app=jupyterhub

# MinIO
kubectl get pods -n ai -l app=minio

# Argo Workflows
kubectl get pods -n argo -l app=workflow-controller
```

### Test Access

1. **JupyterHub**: Open http://jupyterhub.tailc2013b.ts.net and login
2. **Argo UI**: Open http://argo.tailc2013b.ts.net
3. **MinIO Console**: Open http://minio.tailc2013b.ts.net (login with minioadmin/minioadmin)

## Usage Examples

### Execute Notebook via Job

```bash
./ai/scripts/run-notebook.sh \
  /home/jovyan/work/input.ipynb \
  /home/jovyan/work/output.ipynb \
  '{"param1":"value1"}' \
  claim-username \
  false
```

### Create Scheduled Notebook

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

### Execute via Argo Workflow

See `ai/docs/argo-workflows-guide.md` for detailed examples.

## Storage

### User PVCs

- **Naming**: `claim-<username>`
- **Size**: 10GB
- **Storage Class**: longhorn
- **Access Mode**: ReadWriteOnce

### MinIO Bucket

- **Name**: `notebook-artifacts`
- **Purpose**: Store notebook outputs (PDF, HTML, CSV, PNG)
- **Access**: Via S3 API or MinIO console

## Troubleshooting

### JupyterHub Not Accessible

1. Check pod status: `kubectl get pods -n ai -l app=jupyterhub`
2. Check service: `kubectl get svc -n ai proxy-public`
3. Check ingress: `kubectl get ingress -n ai jupyterhub-ingress`
4. Check logs: `kubectl logs -n ai -l app=jupyterhub`

### MinIO Connection Issues

1. Verify MinIO is running: `kubectl get pods -n ai -l app=minio`
2. Check credentials: `kubectl get secret -n ai minio-credentials -o yaml`
3. Test from pod: `kubectl run -it --rm test --image=minio/mc --restart=Never -n ai -- mc alias set local http://minio:9000 minioadmin minioadmin`

### Argo Workflows Not Working

1. Check controller: `kubectl get pods -n argo -l app=workflow-controller`
2. Check UI: `kubectl get pods -n argo -l app=argo-server`
3. Check logs: `kubectl logs -n argo -l app=workflow-controller`

## Related Documentation

- [JupyterHub User Guide](jupyterhub-guide.md)
- [Papermill Guide](papermill-guide.md)
- [Argo Workflows Guide](argo-workflows-guide.md)
- [MinIO Guide](minio-guide.md)

## Next Steps

1. **Create your first notebook** in JupyterHub
2. **Test Papermill execution** using the run script
3. **Set up a scheduled notebook** using CronJobs
4. **Create an Argo Workflow** for complex pipelines
5. **Store outputs in MinIO** for sharing and archival

