#!/bin/bash
# Build script for twin-service

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Building Twin Service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    exit 1
fi

# Check if Maven is available (for local build)
if command -v mvn &> /dev/null; then
    echo "📦 Building with Maven..."
    mvn clean package -DskipTests
    echo "✅ Maven build complete"
else
    echo "⚠️  Maven not found, will build in Docker"
fi

# Build Docker image
IMAGE_NAME="${IMAGE_NAME:-twin-service}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo ""
echo "🐳 Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

echo ""
echo "✅ Build complete!"
echo ""
echo "To push to registry:"
echo "  docker tag ${IMAGE_NAME}:${IMAGE_TAG} <registry>/${IMAGE_NAME}:${IMAGE_TAG}"
echo "  docker push <registry>/${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "To deploy to cluster:"
echo "  kubectl apply -f k8s/deployment.yaml"
echo "  # Update image in deployment.yaml with your registry path"

