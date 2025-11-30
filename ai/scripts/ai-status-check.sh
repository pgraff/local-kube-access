#!/bin/bash
# Quick status check script for AI workspace

KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config-rke2-cluster.yaml}"
NAMESPACE="ai"
ARGO_NAMESPACE="argo"

export KUBECONFIG="$KUBECONFIG_FILE"

echo "=========================================="
echo "AI Workspace Status Check"
echo "=========================================="
echo ""

echo "📊 JupyterHub Pods:"
kubectl get pods -n $NAMESPACE -l app=jupyterhub -o wide 2>/dev/null || echo "  No JupyterHub pods found"
echo ""

echo "🪣 MinIO Pods:"
kubectl get pods -n $NAMESPACE -l app=minio -o wide 2>/dev/null || echo "  No MinIO pods found"
echo ""

echo "⚙️  Argo Workflows Pods:"
kubectl get pods -n $ARGO_NAMESPACE -l app=workflow-controller -o wide 2>/dev/null || echo "  No Argo Workflows pods found"
echo ""

echo "🔧 Services:"
kubectl get svc -n $NAMESPACE | grep -E "jupyterhub|minio|proxy" || echo "  No services found"
echo ""

echo "💾 Storage (PVCs):"
kubectl get pvc -n $NAMESPACE | head -10
echo ""

echo "📅 CronJobs:"
kubectl get cronjobs -n $NAMESPACE 2>/dev/null || echo "  No CronJobs found"
echo ""

echo "🔄 Jobs (recent):"
kubectl get jobs -n $NAMESPACE -l app=papermill --sort-by=.metadata.creationTimestamp | tail -5 2>/dev/null || echo "  No recent jobs found"
echo ""

echo "✅ Ready Components:"
kubectl get pods -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null | grep -E "\ttrue$" | awk '{print "  ✓", $1}' || echo "  None"
echo ""

echo "⏳ Not Ready:"
kubectl get pods -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null | grep -E "\tfalse$" | awk '{print "  •", $1}' || echo "  None"
echo ""

echo "📝 Access URLs:"
echo "  • JupyterHub:    http://jupyterhub.tailc2013b.ts.net"
echo "  • Argo Workflows: http://argo.tailc2013b.ts.net"
echo "  • MinIO Console:  http://minio.tailc2013b.ts.net"
echo ""

echo "📋 To access services:"
echo "  Primary (Tailscale URLs):"
echo "    http://jupyterhub.tailc2013b.ts.net"
echo "    http://argo.tailc2013b.ts.net"
echo "    http://minio.tailc2013b.ts.net"
echo "  Fallback (port-forward):"
echo "    ./access-all.sh"
echo ""

