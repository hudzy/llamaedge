#!/bin/bash

set -euo pipefail

# Color codes for fancy output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
CONTAINER_NAME="qwen3-0.6b"
IMAGE_NAME="hudzy/llamaedge:qwen3-0.6b"
PORT=8082
CPUS="4.0"
MEMORY="6g"
HEALTH_CHECK_TIMEOUT=30

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

error() {
    echo -e "${RED}✗ Error: $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠ Warning: $1${NC}"
}

# Check if container is already running
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    warn "Container '$CONTAINER_NAME' is already running"
    docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    exit 0
fi

# Check if a stopped container exists and remove it
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    warn "Found stopped container '$CONTAINER_NAME', removing it..."
    docker rm "$CONTAINER_NAME" > /dev/null 2>&1
    success "Old container removed"
fi

log "Starting LlamaEdge container..."
log "Image: ${CYAN}$IMAGE_NAME${NC}"
log "Port: ${CYAN}$PORT:8080${NC}"
log "CPU: ${CYAN}$CPUS${NC} cores"
log "Memory: ${CYAN}$MEMORY${NC}"

# Pull the latest image
log "Pulling latest image..."
if ! docker pull "$IMAGE_NAME"; then
    error "Failed to pull image '$IMAGE_NAME'"
    exit 1
fi
success "Image pulled successfully"

# Run the container
log "Creating and starting container..."
if ! CONTAINER_ID=$(docker run -d \
  --name "$CONTAINER_NAME" \
  -p "$PORT:8080" \
  --cpus="$CPUS" \
  --memory="$MEMORY" \
  --restart unless-stopped \
  --health-cmd='curl -f http://localhost:8080/health || exit 1' \
  --health-interval=30s \
  --health-timeout=10s \
  --health-start-period=40s \
  --health-retries=3 \
  "$IMAGE_NAME"); then
    error "Failed to start container"
    exit 1
fi

success "Container started with ID: $CONTAINER_ID"

# Wait for container to be healthy
log "Waiting for container to be healthy (timeout: ${HEALTH_CHECK_TIMEOUT}s)..."
COUNTER=0
while [ $COUNTER -lt $HEALTH_CHECK_TIMEOUT ]; do
    HEALTH_STATUS=$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "none")
    
    if [ "$HEALTH_STATUS" = "healthy" ]; then
        success "Container is healthy and ready!"
        break
    elif [ "$HEALTH_STATUS" = "unhealthy" ]; then
        error "Container failed health check"
        docker logs "$CONTAINER_NAME" | tail -20
        exit 1
    fi
    
    echo -ne "${CYAN}  [$(printf '%*s' $COUNTER | tr ' ' '=')]${NC}\r"
    sleep 1
    ((COUNTER++))
done

# Display final status
log "Container Status:"
docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

log "Access the API at: ${CYAN}http://localhost:${PORT}${NC}"
success "Setup complete! 🚀"
