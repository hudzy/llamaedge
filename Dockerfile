FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

ARG LLAMAEDGE_VERSION=0.29.0
ARG WASMEDGE_VERSION=0.17.1
ARG MODEL_URL
ARG PROMPT_FORMAT
ARG CONTEXT_SIZE=24576
ARG TEMPERATURE=0.8

LABEL org.opencontainers.image.source="https://github.com/hudzy/llamaedge" \
      org.opencontainers.image.description="LlamaEdge - Run LLMs at the Edge" \
      org.opencontainers.image.licenses="MIT"

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    bash ca-certificates curl git libgomp1 libopenblas-dev libopenblas0 libstdc++6 python3 && \
  curl -fSL -o /tmp/wasmedge-install.sh \
    "https://raw.githubusercontent.com/WasmEdge/WasmEdge/${WASMEDGE_VERSION}/utils/install.sh" && \
  bash /tmp/wasmedge-install.sh --version "${WASMEDGE_VERSION}" --plugins wasi_nn-ggml wasmedge_rustls -p /usr/local && \
  rm -f /tmp/wasmedge-install.sh && \
  apt-get purge -y --auto-remove git libopenblas-dev python3 && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN curl -fSLO "https://github.com/LlamaEdge/LlamaEdge/releases/download/${LLAMAEDGE_VERSION}/llama-api-server.wasm" && \
  curl -fSLO "https://github.com/LlamaEdge/LlamaEdge/releases/download/${LLAMAEDGE_VERSION}/SHA256SUM" && \
  sha256sum -c --ignore-missing SHA256SUM && \
  rm SHA256SUM

RUN MODEL_FILE="$(basename "${MODEL_URL}")" && \
  curl -fSL -o "${MODEL_FILE}" "${MODEL_URL}"

RUN MODEL_FILE="$(basename "${MODEL_URL}")" && \
  printf '#!/bin/bash\nset -e\n. /usr/local/env\nwasmedge \\\n  --dir .:. \\\n  --nn-preload "default:GGML:AUTO:%s" \\\n  llama-api-server.wasm \\\n  --prompt-template "%s" \\\n  --ctx-size "%s" \\\n  --model-name "%s" \\\n  --temp "%s" \\\n  --socket-addr 0.0.0.0:8080 \\\n  --web-ui chatbot-ui\n' \
    "${MODEL_FILE}" "${PROMPT_FORMAT}" "${CONTEXT_SIZE}" "${MODEL_FILE}" "${TEMPERATURE}" \
  > /app/init.sh && \
  chmod +x /app/init.sh

RUN adduser --disabled-password --gecos '' llamaedge && \
  chown -R llamaedge:0 /app && \
  chmod -R g=u /app

USER llamaedge

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/v1/models || exit 1

STOPSIGNAL SIGTERM

ENTRYPOINT ["/bin/bash"]
CMD ["/app/init.sh"]
