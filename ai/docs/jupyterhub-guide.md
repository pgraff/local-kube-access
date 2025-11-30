# JupyterHub User Guide

This guide explains how to use JupyterHub in the AI workspace.

## Access

### Primary Access (Recommended)

**URL**: http://jupyterhub.tailc2013b.ts.net

### Fallback Access

```bash
./ai/scripts/access-jupyterhub.sh
# Then open: http://localhost:8000
```

## Login

- **Username**: Any username (dummy authenticator)
- **Password**: `jupyterhub`

**Note**: With dummy authenticator, any username/password combination will work, but the default password is `jupyterhub`.

## First Login

1. Navigate to http://jupyterhub.tailc2013b.ts.net
2. Enter any username (e.g., `user1`, `alice`, `researcher`)
3. Enter password: `jupyterhub`
4. Click "Sign in"

JupyterHub will:
- Create a dedicated notebook pod for you
- Mount a 10GB PVC for persistent storage
- Launch JupyterLab interface

## Your Workspace

### Storage

- **Home Directory**: `/home/jovyan/work`
- **Persistent**: Data persists across pod restarts
- **Size**: 10GB per user
- **PVC Name**: `claim-<username>`

### Pre-installed Packages

- Python 3.10+
- Conda package manager
- pip package manager
- Papermill (for parameterized notebook execution)
- boto3 (MinIO/S3 client)
- s3fs (S3 filesystem)
- Scientific Python stack (NumPy, Pandas, Matplotlib, etc.)

### Installing Additional Packages

**Via pip:**
```python
!pip install package-name
```

**Via conda:**
```python
!conda install -y package-name
```

**In terminal:**
```bash
pip install package-name
# or
conda install package-name
```

## Accessing MinIO

MinIO is pre-configured and accessible from your notebooks.

### Environment Variables

These are automatically set in your notebook environment:
- `MINIO_ENDPOINT`: `minio.ai.svc.cluster.local:9000`
- `MINIO_BUCKET`: `notebook-artifacts`
- `MINIO_ACCESS_KEY`: `minioadmin`
- `MINIO_SECRET_KEY`: `minioadmin`
- `MINIO_REGION`: `us-east-1`

### Using MinIO in Python

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

# Upload a file
s3_client.upload_file('local-file.csv', os.environ['MINIO_BUCKET'], 'remote-file.csv')

# Download a file
s3_client.download_file(os.environ['MINIO_BUCKET'], 'remote-file.csv', 'local-file.csv')

# List files
objects = s3_client.list_objects_v2(Bucket=os.environ['MINIO_BUCKET'])
for obj in objects.get('Contents', []):
    print(obj['Key'])
```

### Using MinIO with s3fs

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
```

## Accessing Cluster Services

Your notebook pod can access other services in the cluster:

- **MinIO**: `minio.ai.svc.cluster.local:9000`
- **Kafka** (if deployed): `kafka-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092`
- **Other services**: Use `<service-name>.<namespace>.svc.cluster.local`

## Executing Notebooks with Papermill

See [Papermill Guide](papermill-guide.md) for details on executing notebooks programmatically.

## Saving Outputs

### To PVC (Local Storage)

Save files to your home directory:
```python
# Save to local storage
df.to_csv('/home/jovyan/work/output.csv')
```

### To MinIO

Save files to MinIO bucket:
```python
import boto3
import os

s3_client = boto3.client(
    's3',
    endpoint_url=f"http://{os.environ['MINIO_ENDPOINT']}",
    aws_access_key_id=os.environ['MINIO_ACCESS_KEY'],
    aws_secret_access_key=os.environ['MINIO_SECRET_KEY']
)

# Save DataFrame to MinIO
df.to_csv('output.csv', index=False)
s3_client.upload_file('output.csv', os.environ['MINIO_BUCKET'], 'outputs/output.csv')
```

## Resource Limits

- **Memory**: 4Gi limit, 1Gi request
- **CPU**: 2000m limit, 500m request

If you need more resources, contact your administrator.

## Troubleshooting

### Pod Not Starting

1. Check pod status:
   ```bash
   kubectl get pods -n ai -l hub.jupyter.org/username=<your-username>
   ```

2. Check logs:
   ```bash
   kubectl logs -n ai -l hub.jupyter.org/username=<your-username>
   ```

### Storage Full

Your PVC is 10GB. Check usage:
```bash
df -h /home/jovyan/work
```

Clean up old files or request more storage.

### Can't Access MinIO

1. Verify MinIO is running:
   ```bash
   kubectl get pods -n ai -l app=minio
   ```

2. Test connection from notebook:
   ```python
   import os
   print(os.environ.get('MINIO_ENDPOINT'))
   ```

### Package Installation Fails

- Try using `--user` flag: `pip install --user package-name`
- Check if package is available in conda: `conda search package-name`
- Some packages may require system dependencies

## Best Practices

1. **Organize your work**: Use folders in `/home/jovyan/work`
2. **Version control**: Use git to track your notebooks
3. **Save outputs**: Use MinIO for sharing and archival
4. **Clean up**: Remove temporary files to save space
5. **Use Papermill**: For parameterized and scheduled executions

## Related Documentation

- [AI Workspace Setup](ai-workspace-setup.md)
- [Papermill Guide](papermill-guide.md)
- [MinIO Guide](minio-guide.md)

