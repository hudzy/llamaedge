#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly MODELS_FILE="${REPO_ROOT}/models.yaml"
readonly OUTPUT_FILE="${REPO_ROOT}/docker-compose.yaml"

if ! command -v yq >/dev/null 2>&1; then
    echo "error: yq is required to generate docker-compose.yaml" >&2
    exit 1
fi

if [[ ! -f "$MODELS_FILE" ]]; then
    echo "error: models file not found: $MODELS_FILE" >&2
    exit 1
fi

{
    echo "# Generated from models.yaml — run: make generate"
    echo "services:"

    while IFS= read -r model_id; do
        model_url=$(yq -r ".models[\"${model_id}\"].model_url" "$MODELS_FILE")
        prompt_format=$(yq -r ".models[\"${model_id}\"].prompt_format" "$MODELS_FILE")
        context_size=$(yq -r ".models[\"${model_id}\"].context_size" "$MODELS_FILE")
        threads=$(yq -r ".models[\"${model_id}\"].threads" "$MODELS_FILE")
        port=$(yq -r ".models[\"${model_id}\"].port" "$MODELS_FILE")
        cpus=$(yq -r ".models[\"${model_id}\"].cpus" "$MODELS_FILE")
        memory=$(yq -r ".models[\"${model_id}\"].memory" "$MODELS_FILE")
        profiles=$(yq -r ".models[\"${model_id}\"].profiles | map(\"      - \" + .) | join(\"\n\")" "$MODELS_FILE")

        cat <<EOF
  ${model_id}:
    image: hudzy/llamaedge:${model_id}
    build:
      context: .
      args:
        MODEL_URL: ${model_url}
        PROMPT_FORMAT: ${prompt_format}
        CONTEXT_SIZE: "${context_size}"
        THREADS: "${threads}"
    container_name: llamaedge-${model_id}
    ports:
      - "${port}:8080"
    cpus: ${cpus}
    mem_limit: ${memory}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/v1/models"]
      interval: 30s
      timeout: 10s
      start_period: 60s
      retries: 3
    profiles:
${profiles}
EOF
    done < <(yq -r '.models | keys | .[]' "$MODELS_FILE")
} > "$OUTPUT_FILE"

echo "Generated ${OUTPUT_FILE}"
