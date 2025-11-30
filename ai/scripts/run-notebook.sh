#!/bin/bash
# Execute a notebook using Papermill via Kubernetes Job
# 
# Usage:
#   ./run-notebook.sh <notebook-path> <output-path> [parameters-json] [pvc-name] [output-to-minio]
#
# Example:
#   ./run-notebook.sh /home/jovyan/work/notebook.ipynb /home/jovyan/work/output.ipynb '{"param1":"value1"}' claim-username false

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config-rke2-cluster.yaml}"
NAMESPACE="ai"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}ℹ${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check arguments
if [ $# -lt 2 ]; then
    print_error "Usage: $0 <notebook-path> <output-path> [parameters-json] [pvc-name] [output-to-minio]"
    echo ""
    echo "Arguments:"
    echo "  notebook-path    Path to input notebook (e.g., /home/jovyan/work/input.ipynb)"
    echo "  output-path      Path to output notebook (e.g., /home/jovyan/work/output.ipynb)"
    echo "  parameters-json  Optional JSON string of parameters (default: {})"
    echo "  pvc-name         Optional PVC name (default: claim-username)"
    echo "  output-to-minio  Optional: 'true' to save to MinIO, 'false' for PVC (default: false)"
    exit 1
fi

NOTEBOOK_PATH="$1"
OUTPUT_PATH="$2"
PARAMETERS="${3:-{}}"
PVC_NAME="${4:-claim-username}"
OUTPUT_TO_MINIO="${5:-false}"

export KUBECONFIG="$KUBECONFIG_FILE"

# Generate unique job name
JOB_NAME="papermill-$(date +%s)-$(openssl rand -hex 4 | tr '[:upper:]' '[:lower:]')"

print_info "Creating Papermill Job: $JOB_NAME"
print_info "Notebook: $NOTEBOOK_PATH"
print_info "Output: $OUTPUT_PATH"
print_info "PVC: $PVC_NAME"
print_info "Output to MinIO: $OUTPUT_TO_MINIO"

# Check if template exists, if not create it
if ! kubectl get job papermill-job-template -n "$NAMESPACE" &>/dev/null; then
    print_info "Creating Papermill Job template..."
    kubectl apply -f "$SCRIPT_DIR/../k8s/papermill-job-template.yaml" -n "$NAMESPACE"
fi

# Create job from template
kubectl create job "$JOB_NAME" \
    --from=job/papermill-job-template \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | \
kubectl patch --local -f - -p "{
  \"metadata\": {
    \"name\": \"$JOB_NAME\"
  },
  \"spec\": {
    \"template\": {
      \"spec\": {
        \"containers\": [{
          \"name\": \"papermill\",
          \"env\": [
            {\"name\": \"NOTEBOOK_PATH\", \"value\": \"$NOTEBOOK_PATH\"},
            {\"name\": \"OUTPUT_PATH\", \"value\": \"$OUTPUT_PATH\"},
            {\"name\": \"PARAMETERS\", \"value\": \"$PARAMETERS\"},
            {\"name\": \"OUTPUT_TO_MINIO\", \"value\": \"$OUTPUT_TO_MINIO\"}
          ],
          \"volumeMounts\": [{
            \"name\": \"user-pvc\",
            \"mountPath\": \"/home/jovyan/work\",
            \"subPath\": \"work\"
          }]
        }],
        \"volumes\": [{
          \"name\": \"user-pvc\",
          \"persistentVolumeClaim\": {
            \"claimName\": \"$PVC_NAME\"
          }
        }]
      }
    }
  }
}" -o yaml | kubectl apply -f - -n "$NAMESPACE"

print_info "Job created. Waiting for completion..."
kubectl wait --for=condition=complete job/"$JOB_NAME" -n "$NAMESPACE" --timeout=600s || {
    print_error "Job failed or timed out. Check logs:"
    echo "  kubectl logs job/$JOB_NAME -n $NAMESPACE"
    exit 1
}

print_info "Job completed successfully!"
print_info "View logs: kubectl logs job/$JOB_NAME -n $NAMESPACE"

# Clean up job
read -p "Delete job? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete job "$JOB_NAME" -n "$NAMESPACE"
    print_info "Job deleted"
fi

