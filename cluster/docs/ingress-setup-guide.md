# Ingress Setup Guide - URL-Based Cluster Access

This guide explains how to set up URL-based access to your Kubernetes cluster services using Ingress resources, eliminating the need for `kubectl port-forward`.

**📖 For laptop setup instructions, see [LAPTOP-SETUP.md](../../LAPTOP-SETUP.md)**

## Overview

Instead of using port-forwarding (e.g., `localhost:8080`), you can access services via friendly URLs like:
- `http://longhorn.tailc2013b.ts.net`
- `http://kubecost.tailc2013b.ts.net`
- `http://kafka-ui.tailc2013b.ts.net`

## Prerequisites

- Kubernetes cluster with ingress controller (rke2-ingress-nginx-controller)
- Tailscale VPN connection
- Tailscale MagicDNS enabled (optional but recommended)
- kubectl configured with cluster access

## Quick Start

### 1. Deploy Ingress Resources

```bash
# From project root
./cluster/scripts/setup-ingress.sh
```

This script will:
- Verify ingress controller is ready
- Deploy all ingress resources for core services
- Deploy IoT service ingress resources (if IoT namespace exists)
- Display service URLs

### 2. Configure DNS Resolution (Per Machine)

Since Tailscale MagicDNS doesn't resolve arbitrary subdomains, configure `/etc/hosts` on each machine you use:

```bash
# Automated setup (recommended - run on each laptop/desktop)
sudo ./cluster/scripts/add-hosts-entries.sh
```

**Note:** This is a one-time setup per machine. After running it, the URLs will work immediately and persist across reboots. You only need to run this once on each new machine you use for demos.

Alternatively, manually edit `/etc/hosts` (see Option 1 in DNS Configuration section above).

### 3. List All Service URLs

```bash
./cluster/scripts/list-service-urls.sh
```

This displays all available service URLs and DNS configuration status.

## DNS Configuration

### Important Note About Tailscale MagicDNS

**Tailscale MagicDNS resolves device hostnames** (e.g., `k8s-cp-01.tailc2013b.ts.net`), but **does not automatically resolve arbitrary subdomains** like `longhorn.tailc2013b.ts.net`.

For service subdomains, you have two options:

### Option 1: Configure /etc/hosts (Recommended for Demos)

This is the simplest approach for accessing services via friendly URLs:

```bash
# Run the helper script (requires sudo)
sudo ./cluster/scripts/setup-hosts-file.sh
```

This script automatically adds all cluster service entries to `/etc/hosts`. Alternatively, manually add:

```
100.111.119.104  longhorn.tailc2013b.ts.net
100.111.119.104  kubecost.tailc2013b.ts.net
100.111.119.104  kafka-ui.tailc2013b.ts.net
100.111.119.104  rancher.tailc2013b.ts.net
100.111.119.104  hono.tailc2013b.ts.net
100.111.119.104  thingsboard.tailc2013b.ts.net
100.111.119.104  nodered.tailc2013b.ts.net
100.111.119.104  jupyterhub.tailc2013b.ts.net
100.111.119.104  argo.tailc2013b.ts.net
100.111.119.104  minio.tailc2013b.ts.net
100.111.119.104  twin-service.tailc2013b.ts.net
```

**Benefits:**
- ✅ Works immediately after setup
- ✅ No DNS server configuration needed
- ✅ Works with any browser or HTTP client
- ✅ Simple and reliable

### Option 2: Tailscale MagicDNS (For Device Hostnames)

MagicDNS is useful for resolving device hostnames, but not service subdomains:

1. **Enable MagicDNS:**
   - Go to https://login.tailscale.com/admin/settings/dns
   - Enable "MagicDNS"
   - Save changes

2. **Verify MagicDNS is Enabled:**
   ```bash
   tailscale status --json | grep MagicDNS
   # Should show: "MagicDNS":true
   ```

3. **Test Device Hostname Resolution:**
   ```bash
   nslookup k8s-cp-01.tailc2013b.ts.net
   # Should resolve to device IP (100.x.x.x)
   ```

**Note:** MagicDNS will resolve `k8s-cp-01.tailc2013b.ts.net` but not `longhorn.tailc2013b.ts.net`. For service URLs, use `/etc/hosts` (Option 1).

## Service URLs

### Core Services

| Service | URL | Description |
|---------|-----|-------------|
| Rancher | `https://rancher.tailc2013b.ts.net` | Cluster management UI |
| Longhorn | `http://longhorn.tailc2013b.ts.net` | Storage management UI |
| Kubecost | `http://kubecost.tailc2013b.ts.net` | Cost analysis dashboard |
| Kafka UI | `http://kafka-ui.tailc2013b.ts.net` | Kafka management UI |

### IoT Stack Services (if deployed)

| Service | URL | Description |
|---------|-----|-------------|
| Hono | `http://hono.tailc2013b.ts.net` | Eclipse Hono HTTP adapter |
| Ditto | `http://ditto.tailc2013b.ts.net` | Eclipse Ditto API gateway |
| ThingsBoard | `http://thingsboard.tailc2013b.ts.net` | IoT platform dashboard |
| Node-RED | `http://nodered.tailc2013b.ts.net` | Flow-based programming tool |

**Note:** Mosquitto (MQTT port 1883) and Kafka Bootstrap (port 9092) are TCP services and cannot use HTTP Ingress. These services remain accessible via port-forwarding only, which is actually a **security benefit** - they're not exposed to the network and require explicit port-forwarding, providing better access control.

## Node IP Fallback

If Tailscale MagicDNS is not available or not working, you can access services using node IP addresses.

### Method 1: Configure /etc/hosts

Add entries to `/etc/hosts` on your laptop:

```bash
sudo nano /etc/hosts
```

Add:
```
100.111.119.104  longhorn.tailc2013b.ts.net
100.111.119.104  kubecost.tailc2013b.ts.net
100.111.119.104  kafka-ui.tailc2013b.ts.net
100.111.119.104  rancher.tailc2013b.ts.net
100.111.119.104  hono.tailc2013b.ts.net
100.111.119.104  thingsboard.tailc2013b.ts.net
100.111.119.104  nodered.tailc2013b.ts.net
100.111.119.104  jupyterhub.tailc2013b.ts.net
100.111.119.104  argo.tailc2013b.ts.net
100.111.119.104  minio.tailc2013b.ts.net
100.111.119.104  twin-service.tailc2013b.ts.net
```

**Note:** Use `100.111.119.104` (storage node k8s-storage-01) which has working ingress on port 80. Control plane nodes do not expose ingress on port 80.

To detect which node IP works, use: `./cluster/scripts/detect-working-node-ip.sh`

### Method 2: Use Host Header with curl

```bash
curl -H 'Host: longhorn.tailc2013b.ts.net' http://100.111.119.104
```

### Method 3: Browser Extension

Use a browser extension like "ModHeader" or "Header Editor" to set the `Host` header:
- Header: `Host`
- Value: `longhorn.tailc2013b.ts.net`
- URL: `http://100.111.119.104`

## Ingress Resources

All ingress resources are located in `cluster/k8s/ingress/`:

- `longhorn-ingress.yaml`
- `kubecost-ingress.yaml`
- `kafka-ui-ingress.yaml`
- `hono-ingress.yaml`
- `ditto-ingress.yaml`
- `thingsboard-ingress.yaml`
- `nodered-ingress.yaml`

### Ingress Configuration

Each ingress resource:
- Uses `nginx` ingress class (rke2-ingress-nginx-controller)
- Routes to the appropriate service and port
- Uses hostname-based routing with Tailscale domain

Example:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn-ingress
  namespace: longhorn-system
spec:
  ingressClassName: nginx
  rules:
  - host: longhorn.tailc2013b.ts.net
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: longhorn-frontend
            port:
              number: 80
```

## Verification

### Check Ingress Status

```bash
kubectl get ingress --all-namespaces
```

### Check Ingress Controller

```bash
kubectl get daemonset rke2-ingress-nginx-controller -n kube-system
kubectl get pods -n kube-system -l app.kubernetes.io/name=rke2-ingress-nginx
```

### Test Service Access

```bash
# Test DNS resolution
nslookup longhorn.tailc2013b.ts.net

# Test HTTP access
curl -I http://longhorn.tailc2013b.ts.net

# Test in browser
open http://longhorn.tailc2013b.ts.net
```

## Troubleshooting

### DNS Not Resolving

**Problem:** `nslookup longhorn.tailc2013b.ts.net` fails

**Solutions:**
1. Verify MagicDNS is enabled in Tailscale admin console
2. Restart Tailscale client: `sudo tailscale restart` (Linux) or restart Tailscale app (Mac/Windows)
3. Use node IP fallback method (see above)
4. Check Tailscale connection: `tailscale status`

### 404 Not Found

**Problem:** DNS resolves but getting 404 errors

**Solutions:**
1. Verify ingress resource exists: `kubectl get ingress --all-namespaces`
2. Check ingress controller is running: `kubectl get pods -n kube-system -l app.kubernetes.io/name=rke2-ingress-nginx`
3. Verify service exists: `kubectl get svc -n <namespace>`
4. Check ingress logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=rke2-ingress-nginx --tail=50`

### Connection Refused

**Problem:** Cannot connect to service URL

**Solutions:**
1. Verify you're connected to Tailscale: `tailscale status`
2. Check if service pods are running: `kubectl get pods -n <namespace>`
3. Verify service is ready: `kubectl get svc -n <namespace>`
4. Test from within cluster: `kubectl run test-pod --rm -i --restart=Never --image=curlimages/curl:latest -- curl http://<service>.<namespace>.svc.cluster.local`

### Ingress Not Created

**Problem:** `kubectl get ingress` shows no resources

**Solutions:**
1. Run setup script: `./cluster/scripts/setup-ingress.sh`
2. Manually apply: `kubectl apply -f cluster/k8s/ingress/<service>-ingress.yaml`
3. Check for errors: `kubectl describe ingress <name> -n <namespace>`

### Wrong Service Port

**Problem:** Service loads but shows wrong content or errors

**Solutions:**
1. Verify service port in ingress matches service definition:
   ```bash
   kubectl get svc <service-name> -n <namespace> -o jsonpath='{.spec.ports[*].port}'
   kubectl get ingress <ingress-name> -n <namespace> -o jsonpath='{.spec.rules[*].http.paths[*].backend.service.port.number}'
   ```
2. Update ingress YAML if port mismatch
3. Reapply: `kubectl apply -f cluster/k8s/ingress/<service>-ingress.yaml`

## Comparison: Ingress vs Port-Forwarding

### Port-Forwarding (Old Method)
- ✅ Simple, works immediately
- ❌ Requires running `kubectl port-forward` command
- ❌ Tied to local machine
- ❌ Uses non-standard ports (8080, 9090, etc.)
- ❌ Process must stay running

### Ingress (New Method)
- ✅ No local processes needed
- ✅ Works from any device on Tailscale
- ✅ Standard HTTP port 80
- ✅ Friendly URLs
- ✅ Persistent (survives laptop reboots)
- ❌ Requires DNS configuration (MagicDNS or /etc/hosts)

## Best Practices

1. **Use MagicDNS** when possible - it's the simplest solution
2. **Keep ingress resources in version control** - they're in `cluster/k8s/ingress/`
3. **Test after deployment** - verify services are accessible
4. **Monitor ingress controller** - ensure it's healthy
5. **Use HTTPS for production** - consider adding TLS certificates (future enhancement)

## Advanced: Adding New Services

To add ingress for a new service:

1. Create ingress YAML in `cluster/k8s/ingress/`:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: <service>-ingress
     namespace: <namespace>
   spec:
     ingressClassName: nginx
     rules:
     - host: <service>.tailc2013b.ts.net
       http:
         paths:
         - path: /
           pathType: Prefix
           backend:
             service:
               name: <service-name>
               port:
                 number: <port>
   ```

2. Apply the ingress:
   ```bash
   kubectl apply -f cluster/k8s/ingress/<service>-ingress.yaml
   ```

3. Update `list-service-urls.sh` to include the new service

## Related Documentation

- **[LAPTOP-SETUP.md](../../LAPTOP-SETUP.md)** ⭐ **START HERE** - Complete Ubuntu/Mac laptop setup guide
- [Cluster Quick Reference](cluster-quick-reference.md)
- [Cluster Info Summary](cluster-info-summary.md)
- [Remote Access Guide](remote-access-guide.md)

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review ingress controller logs
3. Verify Tailscale connectivity
4. Check service and pod status

