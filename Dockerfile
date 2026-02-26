FROM ubuntu:22.04 AS base
ENV DEBIAN_FRONTEND=noninteractive

ARG LLAMAEDGE_VERSION=0.28.1
ARG WASMEDGE_VERSION=0.16.1
ARG MODEL_URL
ARG PROMPT_FORMAT
ARG CONTEXT_SIZE=24576
ARG TEMPERATURE=0.8

LABEL org.opencontainers.image.source="https://github.com/hudzy/llamaedge" \
      org.opencontainers.image.description="LlamaEdge - Run LLMs at the Edge" \
      org.opencontainers.image.licenses="MIT"

RUN apt-get update && \
  apt-get install -y --no-install-recommends curl ca-certificates && \
  curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh \
    | bash -s -- --version "${WASMEDGE_VERSION}" --plugins wasi_nn-ggml wasmedge_rustls -p /usr/local && \
  apt-get purge -y --auto-remove && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN curl -fSL -o llama-api-server.wasm \
  "https://github.com/LlamaEdge/LlamaEdge/releases/download/${LLAMAEDGE_VERSION}/llama-api-server.wasm"

RUN MODEL_FILE="$(basename "${MODEL_URL}")" && \
  curl -fSL -o "${MODEL_FILE}" "${MODEL_URL}"

RUN MODEL_FILE="$(basename "${MODEL_URL}")" && \
  printf '#!/bin/bash\nset -e\nwasmedge \\\n  --dir .:. \\\n  --nn-preload "default:GGML:AUTO:%s" \\\n  llama-api-server.wasm \\\n  --prompt-template "%s" \\\n  --ctx-size "%s" \\\n  --model-name "%s" \\\n  --temp "%s" \\\n  --socket-addr 0.0.0.0:8080 \\\n  --web-ui chatbot-ui\n' \
    "${MODEL_FILE}" "${PROMPT_FORMAT}" "${CONTEXT_SIZE}" "${MODEL_FILE}" "${TEMPERATURE}" \
  > /app/init.sh && \
  chmod +x /app/init.sh

RUN adduser --disabled-password --gecos '' llamaedge && \
  chown -R llamaedge:0 /app && \
  chmod -R g=u /app

USER llamaedge

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

STOPSIGNAL SIGTERM

ENTRYPOINT ["/bin/bash"]
CMD ["/app/init.sh"]
