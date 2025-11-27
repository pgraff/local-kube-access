# Longhorn Storage Setup Guide

## Why Longhorn Instead of Ceph?

### Longhorn Advantages:
1. **Much Simpler** - Designed specifically for Kubernetes, easier to manage
2. **Rancher Integration** - Made by Rancher, works seamlessly with your setup
3. **Great UI** - Beautiful web interface for monitoring and management
4. **Block Storage** - Perfect for Kubernetes PersistentVolumes
5. **Replication** - Built-in 3-way replication for data protection
6. **Snapshots & Backups** - Easy backup and restore capabilities
7. **Less Resource Intensive** - More efficient than Ceph for Kubernetes workloads
8. **Easier Troubleshooting** - Simpler architecture means easier to debug

### Ceph Advantages:
- More mature ecosystem
- Better for object storage (S3-compatible)
- More features for large-scale deployments

**For your use case (Kubernetes cluster storage), Longhorn is the better choice.**

## Installation Status

✅ **Longhorn v1.10.1 is now installed!**

### What's Configured:

1. **Storage Class**: `longhorn` is set as the default storage class
2. **Nodes Labeled**: 11 nodes are configured for storage:
   - k8s-storage-01 (dedicated storage node)
   - k8s-worker-01 through k8s-worker-10
3. **Replication**: Set to 3 replicas for data protection
4. **Data Path**: `/var/lib/longhorn` on each node

### Access Longhorn UI

Run the provided script:
```bash
./access-longhorn.sh
```

Then open: **http://localhost:8080**

Or manually:
```bash
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
```

### Node Configuration (Already Done)

All nodes are labeled and ready:
- ✅ k8s-storage-01 (primary storage node)
- ✅ k8s-worker-01 through k8s-worker-10 (contributing storage)

### Disk Configuration

Longhorn is using:
- **Default path**: `/var/lib/longhorn` on each node
- **Automatic disk discovery**: Longhorn will find available space
- **Storage node**: k8s-storage-01 has ~167GB available on /dev/sda3
- **Worker nodes**: Each has available space for storage

### Next Steps in Longhorn UI

1. **Check Node Status**: Verify all nodes are showing up
2. **Review Disks**: Check that disks are discovered correctly
3. **Configure Settings** (optional):
   - Adjust replica count if needed
   - Set up backup targets (S3/NFS)
   - Configure snapshot settings

## Storage Configuration Strategy

### Option 1: Dedicated Storage Node (Recommended for your setup)
- Use `k8s-storage-01` as primary storage node
- Workers can contribute storage but prioritize storage-01
- Configure Longhorn to prefer storage-01 for new volumes

### Option 2: Distributed Storage
- All nodes contribute storage equally
- Better for high availability
- More distributed load

## Disk Requirements

Longhorn needs:
- At least 1 disk per node (can be a directory)
- Recommended: Dedicated disk or partition
- Minimum: 10GB free space per node
- For production: Use dedicated disks (not OS disk)

## Current Status

✅ **Default StorageClass**: Longhorn is now the default
✅ **Replication**: Set to 3 replicas
✅ **11 Nodes**: All configured and ready
⏳ **Initialization**: Longhorn components are starting up (wait 2-3 minutes)

## Using Longhorn Storage

### For New PVCs

New PersistentVolumeClaims will automatically use Longhorn:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  # No storageClassName needed - Longhorn is default!
```

### Migrating Existing PVCs

To migrate Kubecost (or other apps) to use Longhorn:
1. Update the PVC to use `storageClassName: longhorn`
2. Or delete and recreate PVCs (data will be lost unless backed up)

## Monitoring

- **UI**: Access via `./access-longhorn.sh` then http://localhost:8080
- **Check volumes**: `kubectl get pv,pvc --all-namespaces`
- **Node status**: Check in Longhorn UI under "Nodes"

