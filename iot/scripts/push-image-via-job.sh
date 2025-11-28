#!/bin/bash
# Push twin-service image to in-cluster registry using a Kubernetes Job
# This avoids containerd import issues by using skopeo inside the cluster

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config-rke2-cluster.yaml}"
export KUBECONFIG="$KUBECONFIG_FILE"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

IMAGE_TAR="/tmp/twin-service.tar"

if [ ! -f "$IMAGE_TAR" ]; then
    print_error "Image tar not found: $IMAGE_TAR"
    echo ""
    echo "Build and save the image first:"
    echo "  cd iot/twin-service"
    echo "  ./build.sh"
    echo "  docker save twin-service:latest -o /tmp/twin-service.tar"
    exit 1
fi

# Get a worker node to copy the tar to
print_info "Finding a worker node..."
# Try to find a node that's not a control-plane node and not storage-01
NODE=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane,!node-role.kubernetes.io/master' -o jsonpath='{.items[?(@.metadata.name!="k8s-storage-01")].metadata.name}' 2>/dev/null | awk '{print $1}' || echo "")
if [ -z "$NODE" ]; then
    print_info "No suitable node found, trying any non-control-plane node..."
    NODE=$(kubectl get nodes -l '!node-role.kubernetes.io/control-plane,!node-role.kubernetes.io/master' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
fi
if [ -z "$NODE" ]; then
    print_info "Trying any node..."
    NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
fi

if [ -z "$NODE" ]; then
    print_error "No nodes found. Check your kubeconfig: $KUBECONFIG_FILE"
    kubectl get nodes 2>&1 || true
    exit 1
fi

NODE_IP=$(kubectl get node "$NODE" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
if [ -z "$NODE_IP" ]; then
    print_error "Could not get IP for node $NODE"
    kubectl get node "$NODE" -o yaml | grep -A 5 addresses || true
    exit 1
fi

# Determine SSH username based on node name
SSH_USER="scispike"
if [[ "$NODE" == *"storage-01"* ]]; then
    SSH_USER="petter"
fi

print_info "Target node: $NODE ($NODE_IP) [user: $SSH_USER]"

# Copy image tar to node
print_info "Copying image tar to node..."
if ! scp "$IMAGE_TAR" "$SSH_USER@$NODE_IP:/tmp/twin-service.tar"; then
    print_error "Failed to copy image tar to node. Check SSH access."
    exit 1
fi
print_success "Image tar copied to $NODE"

# Create/update the job manifest with the correct node name
JOB_MANIFEST="/tmp/push-image-job.yaml"
cat > "$JOB_MANIFEST" <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: push-twin-service-image
  namespace: docker-registry
spec:
  ttlSecondsAfterFinished: 300
  template:
    spec:
      nodeName: $NODE
      restartPolicy: Never
      containers:
      - name: skopeo
        image: quay.io/skopeo/stable:latest
        command:
        - /bin/sh
        - -c
        - |
          set -e
          echo "Loading image from tar..."
          skopeo copy docker-archive:/host/twin-service.tar docker://docker-registry.docker-registry.svc.cluster.local:5000/twin-service:latest --dest-tls-verify=false
          echo "✅ Image pushed successfully!"
        volumeMounts:
        - name: image-tar
          mountPath: /host
          readOnly: true
      volumes:
      - name: image-tar
        hostPath:
          path: /tmp
          type: Directory
EOF

# Delete existing job if it exists
print_info "Cleaning up any existing job..."
kubectl delete job -n docker-registry push-twin-service-image 2>/dev/null || true
sleep 2

# Apply the job
print_info "Creating push job..."
kubectl apply -f "$JOB_MANIFEST"

# Wait for job to start
print_info "Waiting for job pod to be ready..."
POD_NAME=""
for i in {1..30}; do
    POD_NAME=$(kubectl get pods -n docker-registry -l job-name=push-twin-service-image -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$POD_NAME" ]; then
        POD_STATUS=$(kubectl get pod -n docker-registry "$POD_NAME" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        if [ "$POD_STATUS" = "Running" ] || [ "$POD_STATUS" = "Succeeded" ] || [ "$POD_STATUS" = "Failed" ]; then
            break
        fi
    fi
    sleep 2
    echo -n "."
done
echo ""

if [ -z "$POD_NAME" ]; then
    print_error "Pod not found. Checking job status..."
    kubectl get job -n docker-registry push-twin-service-image
    kubectl get pods -n docker-registry -l job-name=push-twin-service-image
    exit 1
fi

POD_STATUS=$(kubectl get pod -n docker-registry "$POD_NAME" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
print_info "Pod status: $POD_STATUS"

if [ "$POD_STATUS" = "Failed" ] || [ "$POD_STATUS" = "Error" ]; then
    print_error "Pod failed. Showing events and logs..."
    kubectl describe pod -n docker-registry "$POD_NAME" | tail -20
    kubectl logs -n docker-registry "$POD_NAME" || true
    exit 1
fi

# Follow logs
print_info "Following job logs (Ctrl+C to stop)..."
kubectl logs -n docker-registry "$POD_NAME" -f

# Check job status
print_info "Checking job status..."
kubectl get job -n docker-registry push-twin-service-image

# Verify image in registry (if registry has catalog endpoint)
print_info "Verifying image was pushed..."
sleep 2

# Clean up job
read -p "Delete the job? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete -f "$JOB_MANIFEST"
    print_success "Job deleted"
fi

print_success "Done! The image should now be available in the registry."
echo ""
echo "Restart pods to use the new image:"
echo "  kubectl delete pods -n iot -l app=twin-service"

