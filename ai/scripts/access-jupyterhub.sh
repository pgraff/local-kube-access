#!/bin/bash
# Port-forward helper for JupyterHub (fallback access)

KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config-rke2-cluster.yaml}"
NAMESPACE="ai"

export KUBECONFIG="$KUBECONFIG_FILE"

echo "Starting port-forward for JupyterHub..."
echo "Access at: http://localhost:8000"
echo ""
echo "Note: Primary access is via Tailscale URL: http://jupyterhub.tailc2013b.ts.net"
echo "Press Ctrl+C to stop"
echo ""

kubectl port-forward -n "$NAMESPACE" svc/proxy-public 8000:80

