# Laptop Setup Guide - Accessing Kubernetes Cluster Services

This guide shows you how to set up your Ubuntu laptop (with Tailscale) to access Kubernetes cluster services via friendly URLs instead of port-forwarding.

## Prerequisites

- Ubuntu laptop
- Tailscale installed and connected
- kubectl installed (optional, for verification)
- Access to the cluster (kubeconfig file)

## Quick Setup (5 minutes)

### Step 1: Verify Tailscale Connection

```bash
# Check Tailscale is connected
tailscale status

# Verify you can reach the cluster node
ping 100.68.247.112
```

### Step 2: Add Service URLs to /etc/hosts

Run this command to add all cluster service entries to `/etc/hosts`:

```bash
sudo bash -c 'cat >> /etc/hosts << EOHOSTS

# Kubernetes Cluster Service URLs (via Ingress)
# Added on $(date)
100.68.247.112  longhorn.tailc2013b.ts.net
100.68.247.112  kubecost.tailc2013b.ts.net
100.68.247.112  kafka-ui.tailc2013b.ts.net
100.68.247.112  rancher.tailc2013b.ts.net
100.68.247.112  hono.tailc2013b.ts.net
100.68.247.112  ditto.tailc2013b.ts.net
100.68.247.112  thingsboard.tailc2013b.ts.net
100.68.247.112  nodered.tailc2013b.ts.net
100.68.247.112  jupyterhub.tailc2013b.ts.net
100.68.247.112  argo.tailc2013b.ts.net
100.68.247.112  minio.tailc2013b.ts.net
EOHOSTS
'
```

**Or use the automated script** (if you have the repo cloned):

```bash
# Clone the repo if you haven't already
git clone <your-repo-url>
cd k8s-home

# Run the setup script
sudo ./cluster/scripts/add-hosts-entries.sh
```

### Step 3: Verify Setup

```bash
# Test DNS resolution
nslookup longhorn.tailc2013b.ts.net
# Should show: 100.68.247.112

# Test HTTP access
curl -I http://longhorn.tailc2013b.ts.net
# Should show: HTTP/1.1 200 OK
```

### Step 4: Access Services in Browser

Open your browser and navigate to:

- **Longhorn:** http://longhorn.tailc2013b.ts.net
- **Kubecost:** http://kubecost.tailc2013b.ts.net
- **Kafka UI:** http://kafka-ui.tailc2013b.ts.net
- **Rancher:** https://rancher.tailc2013b.ts.net
- **Hono:** http://hono.tailc2013b.ts.net (if IoT stack deployed)
- **Ditto:** http://ditto.tailc2013b.ts.net (if IoT stack deployed)
- **ThingsBoard:** http://thingsboard.tailc2013b.ts.net (if IoT stack deployed)
- **Node-RED:** http://nodered.tailc2013b.ts.net (if IoT stack deployed)
- **JupyterHub:** http://jupyterhub.tailc2013b.ts.net (if AI workspace deployed)
- **Argo Workflows:** http://argo.tailc2013b.ts.net (if AI workspace deployed)
- **MinIO Console:** http://minio.tailc2013b.ts.net (if AI workspace deployed)

## Detailed Instructions

### What This Setup Does

1. **Adds DNS entries** to `/etc/hosts` that map service hostnames to the cluster node IP
2. **Enables URL-based access** - no need to run `kubectl port-forward`
3. **Persists across reboots** - entries remain until manually removed

### Why /etc/hosts?

Tailscale MagicDNS resolves device hostnames (like `k8s-cp-01.tailc2013b.ts.net`) but not arbitrary subdomains (like `longhorn.tailc2013b.ts.net`). Using `/etc/hosts` provides local DNS resolution for these service URLs.

### Node IP Address

The setup uses `100.68.247.112` (primary control plane node). The ingress controller runs on all nodes, so any node IP will work, but this is the recommended one.

If you need to use a different node IP, replace `100.68.247.112` in the `/etc/hosts` entries.

## Troubleshooting

### DNS Not Resolving

**Problem:** `nslookup longhorn.tailc2013b.ts.net` fails

**Solution:**
```bash
# Check if entries exist
grep tailc2013b.ts.net /etc/hosts

# If missing, re-run the setup command above
# If present but not working, flush DNS cache:
sudo systemd-resolve --flush-caches  # Ubuntu 18.04+
# or
sudo resolvectl flush-caches  # Ubuntu 20.04+
```

### Connection Refused

**Problem:** DNS resolves but can't connect

**Solution:**
```bash
# 1. Verify Tailscale is connected
tailscale status

# 2. Test connectivity to node
ping 100.68.247.112

# 3. Test with Host header (bypasses DNS)
curl -H "Host: longhorn.tailc2013b.ts.net" http://100.68.247.112

# 4. Check if ingress is working
# (requires kubeconfig - see cluster verification below)
```

### Browser Shows "Site Can't Be Reached"

**Problem:** Browser can't access the URLs

**Solution:**
1. Verify `/etc/hosts` entries: `grep tailc2013b.ts.net /etc/hosts`
2. Clear browser DNS cache or restart browser
3. Try incognito/private mode
4. Test with curl first: `curl -I http://longhorn.tailc2013b.ts.net`

### Services Not Available

**Problem:** Getting 404 or 502 errors

**Solution:**
- Services may not be deployed yet
- Check if ingress resources exist (requires cluster access)
- Some services (like IoT stack) are optional

## Cluster Verification (Optional)

If you have kubectl configured, you can verify the cluster setup:

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml

# Check ingress resources
kubectl get ingress --all-namespaces

# Check ingress controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=rke2-ingress-nginx

# List all service URLs
./cluster/scripts/list-service-urls.sh
```

## Removing Entries

To remove the `/etc/hosts` entries later:

```bash
# Remove cluster service entries
sudo sed -i '/# Kubernetes Cluster Service URLs/,/^$/d' /etc/hosts
sudo sed -i '/tailc2013b.ts.net/d' /etc/hosts
```

Or manually edit:
```bash
sudo nano /etc/hosts
# Remove the cluster service entries
```

## Alternative: Browser Extension

If you prefer not to edit `/etc/hosts`, you can use a browser extension:

1. **Install ModHeader** (Chrome/Firefox extension)
2. **Set Host header:**
   - Header name: `Host`
   - Header value: `longhorn.tailc2013b.ts.net`
3. **Access:** `http://100.68.247.112`

This works but requires setting the header for each service separately.

## Benefits of This Setup

✅ **No port-forwarding needed for HTTP services** - URLs work immediately  
✅ **Persistent** - Survives reboots  
✅ **Standard ports** - All HTTP services on port 80  
✅ **Easy to remember** - Friendly URLs like `longhorn.tailc2013b.ts.net`  
✅ **Works offline** - No external DNS required  
✅ **One-time setup** - Configure once, use forever  

**Note:** TCP services (Kafka Bootstrap port 9092, Mosquitto MQTT port 1883) still require port-forwarding as they cannot use HTTP Ingress. This is actually a **security feature** - these services are not exposed via Ingress and require explicit port-forwarding, providing better access control. Use `./access-all.sh` for these services.  

## Next Steps

After setup, you can:
- Access all services via browser URLs
- Share URLs with team members (they need to run the same setup)
- Use in demos without worrying about port-forwarding processes
- Access from any application that supports HTTP (curl, Postman, etc.)

## Related Documentation

- [Ingress Setup Guide](cluster/docs/ingress-setup-guide.md) - Detailed ingress configuration
- [Cluster Quick Reference](cluster/docs/cluster-quick-reference.md) - Quick commands
- [README](README.md) - Project overview

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Verify Tailscale connectivity: `tailscale status`
3. Test with curl using Host header (bypasses DNS)
4. Check cluster status (if you have kubectl access)

