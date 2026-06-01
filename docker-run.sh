#!/bin/bash

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

CONTAINER_NAME="${CONTAINER_NAME:-llamaedge-qwen3.5-0.8b}"
IMAGE_NAME="${IMAGE_NAME:-hudzy/llamaedge:qwen3.5-0.8b}"
PORT="${PORT:-8082}"
CPUS="${CPUS:-4.0}"
MEMORY="${MEMORY:-6g}"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-60}"
PULL="${PULL:-true}"

log()     { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[ok] $1${NC}"; }
error()   { echo -e "${RED}[error] $1${NC}" >&2; }
warn()    { echo -e "${YELLOW}[warn] $1${NC}"; }

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Run a LlamaEdge container with health checks and resource limits.

Options:
  -n, --name NAME        Container name (default: $CONTAINER_NAME)
  -i, --image IMAGE      Docker image (default: $IMAGE_NAME)
  -p, --port PORT        Host port (default: $PORT)
  -c, --cpus CPUS        CPU limit (default: $CPUS)
  -m, --memory MEM       Memory limit (default: $MEMORY)
  -t, --timeout SECS     Health check timeout (default: $HEALTH_CHECK_TIMEOUT)
      --no-pull          Skip pulling the image
  -h, --help             Show this help

All options can also be set via environment variables:
  CONTAINER_NAME, IMAGE_NAME, PORT, CPUS, MEMORY, HEALTH_CHECK_TIMEOUT, PULL

Examples:
  $0
  $0 -n llamaedge-llama3.2-1b -i hudzy/llamaedge:llama3.2-1b -p 8079
  PORT=8081 IMAGE_NAME=hudzy/llamaedge:gemma3-1b $0

EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)    CONTAINER_NAME="$2"; shift 2 ;;
        -i|--image)   IMAGE_NAME="$2";     shift 2 ;;
        -p|--port)    PORT="$2";           shift 2 ;;
        -c|--cpus)    CPUS="$2";           shift 2 ;;
        -m|--memory)  MEMORY="$2";         shift 2 ;;
        -t|--timeout) HEALTH_CHECK_TIMEOUT="$2"; shift 2 ;;
        --no-pull)    PULL=false;          shift   ;;
        -h|--help)    usage ;;
        *)
            error "Unknown option: $1"
            usage
            ;;
    esac
done

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        warn "Script interrupted. Container may still be running."
        warn "Check with: docker ps --filter name=${CONTAINER_NAME}"
    fi
    exit "$exit_code"
}
trap cleanup EXIT INT TERM

if ! command -v docker >/dev/null 2>&1; then
    error "Docker is not installed or not in PATH"
    exit 1
fi

if docker ps --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
    warn "Container '$CONTAINER_NAME' is already running"
    docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    exit 0
fi

if docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
    warn "Found stopped container '$CONTAINER_NAME', removing it..."
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1
    success "Old container removed"
fi

log "Starting LlamaEdge container..."
log "Image:  ${CYAN}${IMAGE_NAME}${NC}"
log "Port:   ${CYAN}${PORT}:8080${NC}"
log "CPU:    ${CYAN}${CPUS}${NC} cores"
log "Memory: ${CYAN}${MEMORY}${NC}"

if [[ "$PULL" == true ]]; then
    log "Pulling latest image..."
    if ! docker pull "$IMAGE_NAME"; then
        error "Failed to pull image '$IMAGE_NAME'"
        exit 1
    fi
    success "Image pulled successfully"
fi

log "Creating and starting container..."
if ! CONTAINER_ID=$(docker run -d \
    --name "$CONTAINER_NAME" \
    -p "${PORT}:8080" \
    --cpus="$CPUS" \
    --memory="$MEMORY" \
    --restart unless-stopped \
    --health-cmd='curl -f http://localhost:8080/v1/models || exit 1' \
    --health-interval=30s \
    --health-timeout=10s \
    --health-start-period=60s \
    --health-retries=3 \
    "$IMAGE_NAME"); then
    error "Failed to start container"
    exit 1
fi

success "Container started (${CONTAINER_ID:0:12})"

log "Waiting for container to become healthy (timeout: ${HEALTH_CHECK_TIMEOUT}s)..."
counter=0
while [[ $counter -lt $HEALTH_CHECK_TIMEOUT ]]; do
    health_status=$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "none")

    case "$health_status" in
        healthy)
            echo ""
            success "Container is healthy and ready!"
            break
            ;;
        unhealthy)
            echo ""
            error "Container failed health check"
            docker logs --tail 20 "$CONTAINER_NAME"
            exit 1
            ;;
    esac

    printf "\r  ${CYAN}Waiting... %ds${NC}" "$counter"
    sleep 1
    ((counter++))
done

if [[ $counter -ge $HEALTH_CHECK_TIMEOUT ]]; then
    echo ""
    warn "Health check timed out after ${HEALTH_CHECK_TIMEOUT}s (container may still be loading the model)"
    warn "Check status with: docker inspect --format='{{.State.Health.Status}}' ${CONTAINER_NAME}"
fi

echo ""
log "Container Status:"
docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
log "API:    ${CYAN}http://localhost:${PORT}/v1/chat/completions${NC}"
log "Web UI: ${CYAN}http://localhost:${PORT}${NC}"
success "Setup complete!"
