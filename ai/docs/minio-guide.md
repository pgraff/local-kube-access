# MinIO Guide

This guide explains how to use MinIO for storing notebook artifacts in the AI workspace.

## Overview

MinIO provides S3-compatible object storage for:
- Notebook outputs (PDF, HTML, CSV, PNG)
- Model artifacts
- Data files
- Shared resources

## Access

### Console (Web UI)

**URL**: http://minio.tailc2013b.ts.net

**Credentials:**
- Access Key: `minioadmin`
- Secret Key: `minioadmin`

### API Endpoint

**Internal (from pods):**
- Endpoint: `http://minio.ai.svc.cluster.local:9000`

**External (if needed):**
- Endpoint: `http://minio.tailc2013b.ts.net:9000`

## Bucket

### Default Bucket

- **Name**: `notebook-artifacts`
- **Purpose**: Store notebook outputs and artifacts
- **Region**: `us-east-1` (default)

## Using MinIO

### From JupyterHub Notebooks

#### Using boto3

```python
import boto3
import os

# Create S3 client
s3_client = boto3.client(
    's3',
    endpoint_url=f"http://{os.environ['MINIO_ENDPOINT']}",
    aws_access_key_id=os.environ['MINIO_ACCESS_KEY'],
    aws_secret_access_key=os.environ['MINIO_SECRET_KEY'],
    region_name=os.environ['MINIO_REGION']
)

bucket = os.environ['MINIO_BUCKET']

# Upload file
s3_client.upload_file('local-file.csv', bucket, 'remote-file.csv')

# Download file
s3_client.download_file(bucket, 'remote-file.csv', 'local-file.csv')

# List files
objects = s3_client.list_objects_v2(Bucket=bucket)
for obj in objects.get('Contents', []):
    print(f"{obj['Key']} ({obj['Size']} bytes)")

# Delete file
s3_client.delete_object(Bucket=bucket, Key='remote-file.csv')
```

#### Using s3fs

```python
import s3fs
import os

fs = s3fs.S3FileSystem(
    key=os.environ['MINIO_ACCESS_KEY'],
    secret=os.environ['MINIO_SECRET_KEY'],
    client_kwargs={
        'endpoint_url': f"http://{os.environ['MINIO_ENDPOINT']}"
    }
)

# Read file directly
with fs.open(f"{os.environ['MINIO_BUCKET']}/file.csv") as f:
    data = f.read()

# Write file
with fs.open(f"{os.environ['MINIO_BUCKET']}/output.csv", 'w') as f:
    f.write(data)

# List files
files = fs.ls(os.environ['MINIO_BUCKET'])
for file in files:
    print(file)
```

#### Using pandas

```python
import pandas as pd
import s3fs
import os

fs = s3fs.S3FileSystem(
    key=os.environ['MINIO_ACCESS_KEY'],
    secret=os.environ['MINIO_SECRET_KEY'],
    client_kwargs={
        'endpoint_url': f"http://{os.environ['MINIO_ENDPOINT']}"
    }
)

# Read CSV from MinIO
df = pd.read_csv(
    f"s3://{os.environ['MINIO_BUCKET']}/data.csv",
    storage_options={
        'key': os.environ['MINIO_ACCESS_KEY'],
        'secret': os.environ['MINIO_SECRET_KEY'],
        'client_kwargs': {
            'endpoint_url': f"http://{os.environ['MINIO_ENDPOINT']}"
        }
    }
)

# Write CSV to MinIO
df.to_csv(
    f"s3://{os.environ['MINIO_BUCKET']}/output.csv",
    storage_options={
        'key': os.environ['MINIO_ACCESS_KEY'],
        'secret': os.environ['MINIO_SECRET_KEY'],
        'client_kwargs': {
            'endpoint_url': f"http://{os.environ['MINIO_ENDPOINT']}"
        }
    }
)
```

### From Papermill Jobs

MinIO credentials are automatically available via environment variables. See [Papermill Guide](papermill-guide.md) for examples.

### From Argo Workflows

MinIO credentials are available in workflow pods. See [Argo Workflows Guide](argo-workflows-guide.md) for examples.

## Console Usage

### Accessing the Console

1. Navigate to http://minio.tailc2013b.ts.net
2. Login with `minioadmin` / `minioadmin`
3. Browse buckets and files
4. Upload/download files
5. Manage access policies

### Creating Additional Buckets

1. Click "Create Bucket"
2. Enter bucket name
3. Configure settings (optional)
4. Click "Create Bucket"

### Uploading Files

1. Select bucket
2. Click "Upload"
3. Select files
4. Click "Upload"

### Downloading Files

1. Navigate to file
2. Click on file name
3. Click "Download"

## Best Practices

1. **Organize files**: Use folders/prefixes (e.g., `outputs/`, `models/`, `data/`)
2. **Version files**: Add timestamps or version numbers to filenames
3. **Clean up**: Delete old files to save space
4. **Use prefixes**: Organize by date, project, or user
5. **Backup important files**: MinIO is for artifacts, not primary storage

## Storage Management

### Check Storage Usage

From MinIO Console:
1. Go to bucket
2. View storage statistics

From command line:
```bash
kubectl exec -n ai -it deployment/minio -- \
  mc du local/notebook-artifacts
```

### Clean Up Old Files

From Python:
```python
import boto3
from datetime import datetime, timedelta

s3_client = boto3.client(
    's3',
    endpoint_url=f"http://{os.environ['MINIO_ENDPOINT']}",
    aws_access_key_id=os.environ['MINIO_ACCESS_KEY'],
    aws_secret_access_key=os.environ['MINIO_SECRET_KEY']
)

bucket = os.environ['MINIO_BUCKET']
cutoff_date = datetime.now() - timedelta(days=30)

objects = s3_client.list_objects_v2(Bucket=bucket)
for obj in objects.get('Contents', []):
    if obj['LastModified'].replace(tzinfo=None) < cutoff_date:
        s3_client.delete_object(Bucket=bucket, Key=obj['Key'])
        print(f"Deleted: {obj['Key']}")
```

## Troubleshooting

### Can't Connect to MinIO

1. Verify MinIO is running:
   ```bash
   kubectl get pods -n ai -l app=minio
   ```

2. Check service:
   ```bash
   kubectl get svc -n ai minio
   ```

3. Test from pod:
   ```bash
   kubectl run -it --rm test --image=minio/mc --restart=Never -n ai -- \
     mc alias set local http://minIO:9000 minioadmin minioadmin && \
     mc ls local
   ```

### Authentication Errors

- Verify credentials match Secret:
  ```bash
  kubectl get secret -n ai minio-credentials -o yaml
  ```

- Check environment variables in notebook:
  ```python
  import os
  print(os.environ.get('MINIO_ACCESS_KEY'))
  ```

### Bucket Not Found

- Verify bucket exists:
  ```bash
  kubectl exec -n ai -it deployment/minio -- \
    mc ls local
  ```

- Create bucket if needed:
  ```bash
  kubectl exec -n ai -it deployment/minio -- \
    mc mb local/new-bucket-name
  ```

## Related Documentation

- [AI Workspace Setup](ai-workspace-setup.md)
- [JupyterHub Guide](jupyterhub-guide.md)
- [Papermill Guide](papermill-guide.md)

