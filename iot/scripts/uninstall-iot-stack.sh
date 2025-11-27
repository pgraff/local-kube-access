#!/bin/bash
# Single script to uninstall the complete IoT stack
# This script removes all IoT components in the correct order

set -e  # Exit on error

KUBECONFIG_FILE="$HOME/.kube/config-rke2-cluster.yaml"
NAMESPACE="iot"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to check if kubeconfig exists
check_kubeconfig() {
    if [ ! -f "$KUBECONFIG_FILE" ]; then
        print_error "Kubeconfig file not found at $KUBECONFIG_FILE"
        echo "Please ensure the kubeconfig file exists."
        exit 1
    fi
    export KUBECONFIG="$KUBECONFIG_FILE"
}

# Function to uninstall Helm release
uninstall_helm_release() {
    local release=$1
    if helm list -n "$NAMESPACE" | grep -q "$release"; then
        print_status "Uninstalling $release..."
        helm uninstall "$release" -n "$NAMESPACE" || print_warning "Failed to uninstall $release"
    else
        print_warning "$release not found, skipping..."
    fi
}

# Main uninstall function
main() {
    print_status "=========================================="
    print_status "IoT Stack Uninstall Script"
    print_status "=========================================="
    echo ""
    
    # Confirm deletion
    print_warning "This will delete ALL IoT stack components in the $NAMESPACE namespace!"
    print_warning "This includes all data in databases (unless PVCs are preserved)."
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Uninstall cancelled."
        exit 0
    fi
    echo ""
    
    # Check kubeconfig
    check_kubeconfig
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        print_warning "Namespace $NAMESPACE does not exist. Nothing to uninstall."
        exit 0
    fi
    
    # Phase 1: Uninstall Applications (reverse order of installation)
    print_step "Phase 1: Uninstalling applications..."
    
    # Node-RED
    print_status "Removing Node-RED..."
    kubectl delete -f ../k8s/nodered-deployment.yaml -n "$NAMESPACE" 2>/dev/null || print_warning "Node-RED deployment not found"
    
    # ThingsBoard
    print_status "Removing ThingsBoard..."
    kubectl delete -f ../k8s/thingsboard-deployment.yaml -n "$NAMESPACE" 2>/dev/null || print_warning "ThingsBoard deployment not found"
    
    # Ditto
    uninstall_helm_release "ditto"
    # Remove Ditto MongoDB service alias
    print_status "Removing Ditto MongoDB service alias..."
    kubectl delete svc ditto-mongodb -n "$NAMESPACE" 2>/dev/null || print_warning "Ditto MongoDB service not found"
    
    # Hono
    uninstall_helm_release "hono"
    
    # Mosquitto
    print_status "Removing Mosquitto..."
    kubectl delete -f ../k8s/mosquitto-deployment.yaml -n "$NAMESPACE" 2>/dev/null || print_warning "Mosquitto deployment not found"
    echo ""
    
    # Phase 2: Uninstall Databases
    print_step "Phase 2: Uninstalling databases..."
    
    # PostgreSQL
    uninstall_helm_release "postgresql-thingsboard"
    
    # MongoDB instances
    uninstall_helm_release "mongodb-ditto"
    uninstall_helm_release "mongodb-hono"
    
    # TimescaleDB
    uninstall_helm_release "timescaledb"
    echo ""
    
    # Phase 3: Clean up PVCs (optional)
    print_step "Phase 3: Cleaning up persistent volumes..."
    read -p "Delete persistent volume claims (PVCs)? This will delete all data! (yes/no): " -r
    echo
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Deleting PVCs..."
        kubectl delete pvc --all -n "$NAMESPACE" || print_warning "Some PVCs may not exist"
    else
        print_status "Preserving PVCs. Data will be retained."
    fi
    echo ""
    
    # Phase 4: Delete Namespace (optional)
    print_step "Phase 4: Cleaning up namespace..."
    read -p "Delete the entire $NAMESPACE namespace? (yes/no): " -r
    echo
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Deleting namespace $NAMESPACE..."
        kubectl delete namespace "$NAMESPACE" || print_warning "Namespace may already be deleted"
        print_status "Namespace deleted"
    else
        print_status "Namespace preserved. You can delete it manually with:"
        echo "  kubectl delete namespace $NAMESPACE"
    fi
    echo ""
    
    # Final status
    print_status "=========================================="
    print_status "Uninstall Complete!"
    print_status "=========================================="
    echo ""
    print_status "IoT stack has been removed from the cluster."
    echo ""
}

# Run main function
main "$@"

