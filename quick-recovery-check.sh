#!/bin/bash
# Quick recovery status check

export KUBECONFIG="$HOME/.kube/config-rke2-cluster.yaml"

echo "=== Quick Recovery Check ==="
echo ""

# Nodes
NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo "0")
echo "Nodes: $READY_NODES/$NODES Ready"

# System pods
SYS_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l)
SYS_RUNNING=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c " Running " || echo "0")
echo "System Pods: $SYS_RUNNING/$SYS_PODS Running"

# Longhorn
if kubectl get namespace longhorn-system &>/dev/null 2>&1; then
    LH_PODS=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | wc -l)
    LH_RUNNING=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | grep -c " Running " || echo "0")
    LH_VOLUMES=$(kubectl get volumes.longhorn.io -n longhorn-system --no-headers 2>/dev/null | wc -l)
    LH_ATTACHED=$(kubectl get volumes.longhorn.io -n longhorn-system --no-headers 2>/dev/null | grep -c " attached " || echo "0")
    LH_FAULTED=$(kubectl get volumes.longhorn.io -n longhorn-system --no-headers 2>/dev/null | grep -c " faulted " || echo "0")
    echo "Longhorn: $LH_RUNNING/$LH_PODS pods, $LH_ATTACHED/$LH_VOLUMES volumes attached"
    if [ "$LH_FAULTED" -gt 0 ]; then
        echo "  ⚠️  $LH_FAULTED volume(s) in faulted state"
    fi
fi

# Kafka
if kubectl get namespace kafka &>/dev/null 2>&1; then
    KAFKA_PODS=$(kubectl get pods -n kafka --no-headers 2>/dev/null | wc -l)
    KAFKA_READY=$(kubectl get pods -n kafka --no-headers 2>/dev/null | grep -c " 1/1 Running\| 2/2 Running " || echo "0")
    echo "Kafka: $KAFKA_READY/$KAFKA_PODS pods ready"
fi

# IoT
if kubectl get namespace iot &>/dev/null 2>&1; then
    IOT_PODS=$(kubectl get pods -n iot --no-headers 2>/dev/null | wc -l)
    IOT_READY=$(kubectl get pods -n iot --no-headers 2>/dev/null | grep -c " 1/1 Running\| 2/2 Running " || echo "0")
    echo "IoT Stack: $IOT_READY/$IOT_PODS pods ready"
fi

echo ""
if [ "$READY_NODES" -eq "$NODES" ] && [ "$NODES" -gt 0 ]; then
    echo "✅ Cluster is healthy - services recovering"
else
    echo "⏳ Cluster still recovering"
fi
