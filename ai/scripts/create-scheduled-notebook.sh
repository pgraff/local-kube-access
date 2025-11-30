#!/bin/bash
# Create a CronJob for scheduled notebook execution
#
# Usage:
#   ./create-scheduled-notebook.sh <cronjob-name> <schedule> <notebook-path> <output-path> [parameters-json] [pvc-name] [output-to-minio]
#
# Example:
#   ./create-scheduled-notebook.sh daily-report "0 9 * * *" /home/jovyan/work/report.ipynb /home/jovyan/work/output.ipynb '{"date":"today"}' claim-username false

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
if [ $# -lt 4 ]; then
    print_error "Usage: $0 <cronjob-name> <schedule> <notebook-path> <output-path> [parameters-json] [pvc-name] [output-to-minio]"
    echo ""
    echo "Arguments:"
    echo "  cronjob-name    Name for the CronJob (e.g., daily-report)"
    echo "  schedule        Cron schedule (e.g., '0 9 * * *' for daily at 9 AM)"
    echo "  notebook-path   Path to input notebook"
    echo "  output-path     Path to output notebook"
    echo "  parameters-json Optional JSON string of parameters (default: {})"
    echo "  pvc-name        Optional PVC name (default: claim-username)"
    echo "  output-to-minio Optional: 'true' to save to MinIO, 'false' for PVC (default: false)"
    echo ""
    echo "Schedule examples:"
    echo "  '0 9 * * *'     - Daily at 9 AM UTC"
    echo "  '0 */6 * * *'   - Every 6 hours"
    echo "  '0 0 * * 1'     - Every Monday at midnight"
    exit 1
fi

CRONJOB_NAME="$1"
SCHEDULE="$2"
NOTEBOOK_PATH="$3"
OUTPUT_PATH="$4"
PARAMETERS="${5:-{}}"
PVC_NAME="${6:-claim-username}"
OUTPUT_TO_MINIO="${7:-false}"

export KUBECONFIG="$KUBECONFIG_FILE"

print_info "Creating CronJob: $CRONJOB_NAME"
print_info "Schedule: $SCHEDULE"
print_info "Notebook: $NOTEBOOK_PATH"
print_info "Output: $OUTPUT_PATH"
print_info "PVC: $PVC_NAME"
print_info "Output to MinIO: $OUTPUT_TO_MINIO"

# Check if template exists, if not create it
if ! kubectl get cronjob notebook-cronjob-template -n "$NAMESPACE" &>/dev/null; then
    print_info "Creating CronJob template..."
    kubectl apply -f "$SCRIPT_DIR/../k8s/cronjob-template.yaml" -n "$NAMESPACE"
fi

# Create CronJob from template
kubectl create cronjob "$CRONJOB_NAME" \
    --from=cronjob/notebook-cronjob-template \
    --schedule="$SCHEDULE" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | \
kubectl patch --local -f - -p "{
  \"metadata\": {
    \"name\": \"$CRONJOB_NAME\"
  },
  \"spec\": {
    \"schedule\": \"$SCHEDULE\",
    \"jobTemplate\": {
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
    }
  }
}" -o yaml | kubectl apply -f - -n "$NAMESPACE"

print_info "CronJob created successfully!"
print_info "View CronJob: kubectl get cronjob $CRONJOB_NAME -n $NAMESPACE"
print_info "View jobs: kubectl get jobs -n $NAMESPACE -l app=papermill"
print_info "View logs: kubectl logs job/<job-name> -n $NAMESPACE"

