#!/bin/bash
# Optional: Add TimescaleDB extension to ThingsBoard PostgreSQL
# This enables time-series optimizations if needed later

set -euo pipefail

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

NAMESPACE="iot"
POSTGRES_POD="postgresql-thingsboard-0"
POSTGRES_DB="${POSTGRES_DB:-thingsboard}"
POSTGRES_USER="${POSTGRES_USER:-thingsboard}"

print_info "Adding TimescaleDB extension to ThingsBoard PostgreSQL..."
echo ""

# Check if pod exists
if ! kubectl get pod -n "$NAMESPACE" "$POSTGRES_POD" &>/dev/null; then
    print_error "PostgreSQL pod not found: $POSTGRES_POD"
    exit 1
fi

# Check if pod is ready
if ! kubectl get pod -n "$NAMESPACE" "$POSTGRES_POD" -o jsonpath='{.status.phase}' | grep -q Running; then
    print_error "PostgreSQL pod is not running"
    exit 1
fi

print_info "Checking if TimescaleDB extension is available..."
# Check if timescaledb extension exists in PostgreSQL
if kubectl exec -n "$NAMESPACE" "$POSTGRES_POD" -- psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT * FROM pg_available_extensions WHERE name = 'timescaledb';" 2>/dev/null | grep -q timescaledb; then
    print_info "TimescaleDB extension is available"
else
    print_warning "TimescaleDB extension not available in this PostgreSQL image"
    print_info "You may need to use a PostgreSQL image with TimescaleDB pre-installed"
    print_info "Or install it manually in the container"
    exit 1
fi

print_info "Creating TimescaleDB extension in database: $POSTGRES_DB"
if kubectl exec -n "$NAMESPACE" "$POSTGRES_POD" -- psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;" 2>&1; then
    print_success "TimescaleDB extension created successfully!"
    echo ""
    print_info "You can now use TimescaleDB features in your database"
    print_info "Example: Convert a table to a hypertable:"
    echo "  SELECT create_hypertable('your_table', 'timestamp_column');"
else
    print_error "Failed to create TimescaleDB extension"
    exit 1
fi

print_success "Done!"

