#!/bin/bash

set -euo pipefail

# shellcheck source=/dev/null
source /app/.defaults

MODEL_FILE="${MODEL_PATH:-$DEFAULT_MODEL_FILE}"
THREADS="${THREADS:-$DEFAULT_THREADS}"

if [[ ! -f "$MODEL_FILE" ]]; then
    echo "error: model file not found: $MODEL_FILE" >&2
    exit 1
fi

. /usr/local/env

exec wasmedge \
    --dir .:. \
    --nn-preload "default:GGML:AUTO:${MODEL_FILE}" \
    llama-api-server.wasm \
    --prompt-template "${PROMPT_FORMAT}" \
    --ctx-size "${CONTEXT_SIZE}" \
    --model-name "${MODEL_FILE}" \
    --temp "${TEMPERATURE}" \
    --threads "${THREADS}" \
    --socket-addr 0.0.0.0:8080 \
    --web-ui chatbot-ui
