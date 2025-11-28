# Final Steps to Complete Deployment

**Status**: Everything is ready except the image push

## ✅ What's Complete

- ✅ Code implemented and tested
- ✅ Docker image built (`twin-service:latest`)
- ✅ Local registry deployed in cluster
- ✅ Docker daemon.json configured
- ✅ Kubernetes deployment configured
- ✅ All documentation complete

## ⏳ Final Step: Push Image to Registry

The port-forward is unreliable in automated scripts, so this needs to be done manually.

### Step 1: Start Port-Forward (Terminal 1)

**Keep this terminal open and running:**

```bash
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml
kubectl port-forward -n docker-registry service/docker-registry 5000:5000
```

**Expected output:**
```
Forwarding from 127.0.0.1:5000 -> 5000
Forwarding from [::1]:5000 -> 5000
```

**Keep this running!** Don't close this terminal.

### Step 2: Push Image (Terminal 2)

**Open a new terminal:**

```bash
# Tag the image
docker tag twin-service:latest 127.0.0.1:5000/twin-service:latest

# Push to registry
docker push 127.0.0.1:5000/twin-service:latest
```

**Expected output:**
```
The push refers to repository [127.0.0.1:5000/twin-service]
...
latest: digest: sha256:xxxxx size: xxxx
```

**If you get "connection refused":**
- Make sure port-forward is still running in Terminal 1
- Wait a few seconds and try again
- Check: `curl http://127.0.0.1:5000/v2/` should return `{}`

### Step 3: Verify Image in Registry

```bash
curl http://127.0.0.1:5000/v2/_catalog | jq
```

**Expected output:**
```json
{
  "repositories": ["twin-service"]
}
```

### Step 4: Wait for Pods to Start

The pods will automatically pull the image once it's in the registry:

```bash
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml

# Watch pods
kubectl get pods -n iot -l app=twin-service -w
```

**Or check status:**
```bash
kubectl get pods -n iot -l app=twin-service
```

**Expected:** Pods should transition from `ImagePullBackOff` → `ContainerCreating` → `Running`

### Step 5: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n iot -l app=twin-service

# Check logs
kubectl logs -n iot -l app=twin-service --tail=20

# Test health endpoint
kubectl port-forward -n iot service/twin-service 8080:8080
# In another terminal:
curl http://localhost:8080/actuator/health
```

## Troubleshooting

### "connection refused" when pushing

1. **Check port-forward is running:**
   ```bash
   ps aux | grep "port-forward.*docker-registry"
   ```

2. **Restart port-forward if needed:**
   ```bash
   pkill -f "port-forward.*docker-registry"
   kubectl port-forward -n docker-registry service/docker-registry 5000:5000
   ```

3. **Verify registry is accessible:**
   ```bash
   curl http://127.0.0.1:5000/v2/
   ```
   Should return `{}`

### Docker push fails with "unauthorized"

**Check Docker was restarted** after updating `~/.docker/daemon.json`:

```bash
docker info | grep -i "insecure"
```

Should show `localhost:5000` and `127.0.0.1:5000`

**If not showing:**
1. Quit Docker Desktop completely
2. Restart Docker Desktop
3. Wait for it to fully start
4. Try push again

### Pods still in ImagePullBackOff

1. **Verify image is in registry:**
   ```bash
   curl http://127.0.0.1:5000/v2/_catalog | jq
   ```

2. **Check pod events:**
   ```bash
   kubectl describe pod -n iot -l app=twin-service | grep -A 10 Events
   ```

3. **Test registry from a pod:**
   ```bash
   kubectl run -it --rm test --image=busybox --restart=Never -- \
     wget -qO- http://docker-registry.docker-registry.svc.cluster.local:5000/v2/
   ```

4. **Delete pods to force fresh pull:**
   ```bash
   kubectl delete pods -n iot -l app=twin-service
   ```

## Quick Command Reference

```bash
# Terminal 1: Port-forward (keep running)
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml
kubectl port-forward -n docker-registry service/docker-registry 5000:5000

# Terminal 2: Push image
docker tag twin-service:latest 127.0.0.1:5000/twin-service:latest
docker push 127.0.0.1:5000/twin-service:latest

# Verify
curl http://127.0.0.1:5000/v2/_catalog | jq

# Check pods
export KUBECONFIG=~/.kube/config-rke2-cluster.yaml
kubectl get pods -n iot -l app=twin-service
```

## Success Criteria

✅ Image pushed to registry  
✅ Pods transition to `Running` status  
✅ Logs show Spring Boot started  
✅ Health endpoint responds  

Once all these are true, the deployment is complete! 🎉

---

**Need more help?** See `COMPLETE-DEPLOYMENT-GUIDE.md` for comprehensive troubleshooting.

