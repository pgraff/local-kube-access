#!/bin/bash
# Script to gather comprehensive Kubernetes cluster information
# Run this on k8s-cp-01 after SSH login

set -e

OUTPUT_DIR="./cluster-info-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "Gathering Kubernetes cluster information..."
echo "Output directory: $OUTPUT_DIR"

# Basic cluster info
echo "=== Cluster Information ===" > "$OUTPUT_DIR/00-cluster-info.txt"
kubectl cluster-info >> "$OUTPUT_DIR/00-cluster-info.txt" 2>&1
echo "" >> "$OUTPUT_DIR/00-cluster-info.txt"
kubectl version --output=yaml >> "$OUTPUT_DIR/00-cluster-info.txt" 2>&1

# Nodes
echo "=== Nodes ===" > "$OUTPUT_DIR/01-nodes.txt"
kubectl get nodes -o wide >> "$OUTPUT_DIR/01-nodes.txt" 2>&1
echo "" >> "$OUTPUT_DIR/01-nodes.txt"
kubectl get nodes -o yaml >> "$OUTPUT_DIR/01-nodes-detailed.yaml" 2>&1

# Namespaces
echo "=== Namespaces ===" > "$OUTPUT_DIR/02-namespaces.txt"
kubectl get namespaces >> "$OUTPUT_DIR/02-namespaces.txt" 2>&1

# All resources across all namespaces
echo "=== All Resources Summary ===" > "$OUTPUT_DIR/03-all-resources.txt"
kubectl get all --all-namespaces >> "$OUTPUT_DIR/03-all-resources.txt" 2>&1

# Storage
echo "=== Storage Classes ===" > "$OUTPUT_DIR/04-storage.txt"
kubectl get storageclass >> "$OUTPUT_DIR/04-storage.txt" 2>&1
echo "" >> "$OUTPUT_DIR/04-storage.txt"
kubectl get pv >> "$OUTPUT_DIR/04-storage.txt" 2>&1
echo "" >> "$OUTPUT_DIR/04-storage.txt"
kubectl get pvc --all-namespaces >> "$OUTPUT_DIR/04-storage.txt" 2>&1

# Network
echo "=== Network Policies ===" > "$OUTPUT_DIR/05-network.txt"
kubectl get networkpolicies --all-namespaces >> "$OUTPUT_DIR/05-network.txt" 2>&1
echo "" >> "$OUTPUT_DIR/05-network.txt"
echo "=== Services ===" >> "$OUTPUT_DIR/05-network.txt"
kubectl get services --all-namespaces >> "$OUTPUT_DIR/05-network.txt" 2>&1
echo "" >> "$OUTPUT_DIR/05-network.txt"
echo "=== Ingress ===" >> "$OUTPUT_DIR/05-network.txt"
kubectl get ingress --all-namespaces >> "$OUTPUT_DIR/05-network.txt" 2>&1

# ConfigMaps and Secrets (metadata only for security)
echo "=== ConfigMaps ===" > "$OUTPUT_DIR/06-configmaps.txt"
kubectl get configmaps --all-namespaces >> "$OUTPUT_DIR/06-configmaps.txt" 2>&1

echo "=== Secrets (metadata only) ===" > "$OUTPUT_DIR/07-secrets.txt"
kubectl get secrets --all-namespaces >> "$OUTPUT_DIR/07-secrets.txt" 2>&1

# RBAC
echo "=== Service Accounts ===" > "$OUTPUT_DIR/08-rbac.txt"
kubectl get serviceaccounts --all-namespaces >> "$OUTPUT_DIR/08-rbac.txt" 2>&1
echo "" >> "$OUTPUT_DIR/08-rbac.txt"
echo "=== Roles ===" >> "$OUTPUT_DIR/08-rbac.txt"
kubectl get roles --all-namespaces >> "$OUTPUT_DIR/08-rbac.txt" 2>&1
echo "" >> "$OUTPUT_DIR/08-rbac.txt"
echo "=== RoleBindings ===" >> "$OUTPUT_DIR/08-rbac.txt"
kubectl get rolebindings --all-namespaces >> "$OUTPUT_DIR/08-rbac.txt" 2>&1
echo "" >> "$OUTPUT_DIR/08-rbac.txt"
echo "=== ClusterRoles ===" >> "$OUTPUT_DIR/08-rbac.txt"
kubectl get clusterroles >> "$OUTPUT_DIR/08-rbac.txt" 2>&1
echo "" >> "$OUTPUT_DIR/08-rbac.txt"
echo "=== ClusterRoleBindings ===" >> "$OUTPUT_DIR/08-rbac.txt"
kubectl get clusterrolebindings >> "$OUTPUT_DIR/08-rbac.txt" 2>&1

# Deployments, StatefulSets, DaemonSets
echo "=== Deployments ===" > "$OUTPUT_DIR/09-workloads.txt"
kubectl get deployments --all-namespaces >> "$OUTPUT_DIR/09-workloads.txt" 2>&1
echo "" >> "$OUTPUT_DIR/09-workloads.txt"
echo "=== StatefulSets ===" >> "$OUTPUT_DIR/09-workloads.txt"
kubectl get statefulsets --all-namespaces >> "$OUTPUT_DIR/09-workloads.txt" 2>&1
echo "" >> "$OUTPUT_DIR/09-workloads.txt"
echo "=== DaemonSets ===" >> "$OUTPUT_DIR/09-workloads.txt"
kubectl get daemonsets --all-namespaces >> "$OUTPUT_DIR/09-workloads.txt" 2>&1
echo "" >> "$OUTPUT_DIR/09-workloads.txt"
echo "=== Jobs ===" >> "$OUTPUT_DIR/09-workloads.txt"
kubectl get jobs --all-namespaces >> "$OUTPUT_DIR/09-workloads.txt" 2>&1
echo "" >> "$OUTPUT_DIR/09-workloads.txt"
echo "=== CronJobs ===" >> "$OUTPUT_DIR/09-workloads.txt"
kubectl get cronjobs --all-namespaces >> "$OUTPUT_DIR/09-workloads.txt" 2>&1

# Pods with details
echo "=== Pods (all namespaces) ===" > "$OUTPUT_DIR/10-pods.txt"
kubectl get pods --all-namespaces -o wide >> "$OUTPUT_DIR/10-pods.txt" 2>&1

# Custom Resource Definitions
echo "=== Custom Resource Definitions ===" > "$OUTPUT_DIR/11-crds.txt"
kubectl get crds >> "$OUTPUT_DIR/11-crds.txt" 2>&1

# Events (recent)
echo "=== Recent Events ===" > "$OUTPUT_DIR/12-events.txt"
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -100 >> "$OUTPUT_DIR/12-events.txt" 2>&1

# API Resources
echo "=== API Resources ===" > "$OUTPUT_DIR/13-api-resources.txt"
kubectl api-resources >> "$OUTPUT_DIR/13-api-resources.txt" 2>&1

# Component status (deprecated but still useful)
echo "=== Component Status ===" > "$OUTPUT_DIR/14-components.txt"
kubectl get componentstatuses 2>&1 >> "$OUTPUT_DIR/14-components.txt" || echo "Component status not available" >> "$OUTPUT_DIR/14-components.txt"

# Kubeconfig
echo "=== Kubeconfig ===" > "$OUTPUT_DIR/15-kubeconfig.txt"
kubectl config view >> "$OUTPUT_DIR/15-kubeconfig.txt" 2>&1

# For each namespace, get detailed resource info
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
    echo "Gathering detailed info for namespace: $ns"
    mkdir -p "$OUTPUT_DIR/namespaces/$ns"
    
    kubectl get all -n "$ns" -o yaml > "$OUTPUT_DIR/namespaces/$ns/resources.yaml" 2>&1 || true
    kubectl get configmaps -n "$ns" -o yaml > "$OUTPUT_DIR/namespaces/$ns/configmaps.yaml" 2>&1 || true
    kubectl get secrets -n "$ns" -o yaml > "$OUTPUT_DIR/namespaces/$ns/secrets.yaml" 2>&1 || true
    kubectl get pvc -n "$ns" -o yaml > "$OUTPUT_DIR/namespaces/$ns/pvc.yaml" 2>&1 || true
done

echo ""
echo "Cluster information gathering complete!"
echo "All information saved to: $OUTPUT_DIR"
echo ""
echo "Summary files created:"
ls -lh "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.yaml 2>/dev/null | awk '{print $9, "(" $5 ")"}'

