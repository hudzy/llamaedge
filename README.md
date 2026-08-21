# LlamaEdge - Run LLMs at the Edge with Docker

Docker packaging and deployment for [LlamaEdge](https://github.com/LlamaEdge/LlamaEdge) — a WebAssembly LLM inference server with OpenAI-compatible REST APIs and a built-in chat UI.

This repository contains no application source code. It provides a parameterized `Dockerfile`, Docker Compose services, helper scripts, a `Makefile`, and CI that publish pre-built images to Docker Hub.

## Overview

- Run lightweight GGUF-quantized LLMs on CPU with WasmEdge
- Expose OpenAI-compatible endpoints (`/v1/chat/completions`, etc.)
- Choose from four pre-configured models or build your own image
- Start with Docker Compose, `make`, or the standalone run script
- Use the built-in web UI for interactive chat

## Available Models

Each row is one pre-built Docker image (`hudzy/llamaedge:<model-id>`) and a matching Compose service name. Use the **model ID** with `make run MODEL=...`, `docker compose up -d <service>`, or as the image tag in `docker-run.sh -i`.

| Model ID | Model | Context (tokens) | Compose profile |
|----------|-------|------------------|-----------------|
| `qwen3.5-0.8b` | Qwen 3.5 0.8B | 24,576 | `qwen` |
| `llama3.2-1b` | Llama 3.2 1B | 24,576 | `llama` |
| `gemma3-1b` | Gemma 3 1B | 24,576 | `gemma` |
| `gemma3-270m` | Gemma 3 270M | 8,192 | `gemma` |

All models ship as Q5_K_M GGUF weights baked into the image at build time. Context size is set at build time via `CONTEXT_SIZE` in `docker-compose.yaml`.

List model IDs:

```bash
make list-models
```

### Default host ports and resource limits

These values come from [`docker-compose.yaml`](docker-compose.yaml) and the matching defaults in [`docker-run.sh`](docker-run.sh). They are **not** fixed by the model itself — you can change them in Compose or with `docker-run.sh -p`, `-c`, and `-m`.

Inside every container, the API and web UI listen on **port 8080**. The **host port** is what you use from your machine (e.g. `http://localhost:8082`).

| Service / model ID | Host port → container | CPU limit | Memory limit |
|--------------------|------------------------|-----------|--------------|
| `qwen3.5-0.8b` | 8082 → 8080 | 4 | 6 GB |
| `llama3.2-1b` | 8079 → 8080 | 4 | 6 GB |
| `gemma3-1b` | 8081 → 8080 | 4 | 6 GB |
| `gemma3-270m` | 8083 → 8080 | 2 | 4 GB |

Example URLs when using the defaults above:

| Model | Web UI | API base |
|-------|--------|----------|
| Qwen 3.5 0.8B | http://localhost:8082 | http://localhost:8082/v1 |
| Llama 3.2 1B | http://localhost:8079 | http://localhost:8079/v1 |
| Gemma 3 1B | http://localhost:8081 | http://localhost:8081/v1 |
| Gemma 3 270M | http://localhost:8083 | http://localhost:8083/v1 |

Chat endpoint: `POST /v1/chat/completions`

> [!NOTE]
> Compose profile `gemma` starts **both** Gemma services (`gemma3-1b` on 8081 and `gemma3-270m` on 8083). Use a service name directly (e.g. `docker compose up -d gemma3-270m`) to run just one.

## Quick Start

### Prerequisites

- Docker and Docker Compose
- At least 4 GB RAM and 4 GB free disk per model (8 GB+ recommended for 1B models)
- `curl` and `jq` for `query-api.sh`

The examples use Docker Compose v2 (`docker compose`). If your environment still uses the legacy standalone binary, replace `docker compose` with `docker-compose`; the Makefile auto-detects either form.

### Pull and run (Docker Hub)

```bash
# Default: Qwen 3.5 0.8B on port 8082
bash docker-run.sh

# Llama 3.2 1B on port 8079
bash docker-run.sh -i hudzy/llamaedge:llama3.2-1b -n llamaedge-llama3.2-1b -p 8079

# Skip image pull if already local
bash docker-run.sh --no-pull
```

### Using Docker Compose

```bash
# Start one model by service name
docker compose up -d qwen3.5-0.8b

# Or use profiles (note: profile "gemma" starts both Gemma services)
docker compose --profile qwen up -d
docker compose --profile llama up -d
docker compose --profile gemma up -d
docker compose --profile all up -d
```

See [Default host ports and resource limits](#default-host-ports-and-resource-limits) for URLs when using the repo defaults.

### Using Make

```bash
make help                              # Show all targets
make build MODEL=gemma3-270m           # Build one image locally
make build-all                         # Build all model images
make run                               # Start default model (qwen3.5-0.8b)
make run MODEL=llama3.2-1b
make status                            # Show running llamaedge containers
make logs MODEL=gemma3-1b
make stop                              # Stop the selected model
make stop-all                          # Stop all compose services
make query PROMPT="What is AI?"
make clean                             # Remove local containers and images
```

## API Usage

### Chat Completions (OpenAI-compatible)

```bash
curl -X POST http://localhost:8082/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [
      {"role": "user", "content": "Hello, who are you?"}
    ],
    "temperature": 0.7,
    "max_tokens": 1024
  }'
```

### Using the Query Script

```bash
# Simple query
bash query-api.sh "What is machine learning?"

# Custom temperature and streaming
bash query-api.sh -t 0.2 -s "Explain quantum computing"

# Target a different model endpoint
API_BASE_URL=http://localhost:8079 bash query-api.sh "Hello"
```

Query script options:

| Flag | Description | Default |
|------|-------------|---------|
| `-m, --model` | Model name or alias | `default` |
| `-t, --temperature` | Temperature (0–2) | `0.7` |
| `-l, --max-tokens` | Max tokens | `1024` |
| `-s, --stream` | Streaming mode | off |
| `-c, --chat` | Chat completions endpoint | on |
| `-g, --generate` | Text generation endpoint | off |
| `-u, --url` | API base URL | `http://localhost:8082` |

Environment variables: `API_BASE_URL`, `MODEL`, `TEMPERATURE`, `MAX_TOKENS`, `TIMEOUT`

### Run Script Options

`docker-run.sh` wraps `docker run` with health checks and resource limits:

| Flag | Description | Default |
|------|-------------|---------|
| `-n, --name` | Container name | `llamaedge-qwen3.5-0.8b` |
| `-i, --image` | Docker image | `hudzy/llamaedge:qwen3.5-0.8b` |
| `-p, --port` | Host port | `8082` |
| `-c, --cpus` | CPU limit | `4.0` |
| `-m, --memory` | Memory limit | `6g` |
| `-t, --timeout` | Health check wait (seconds) | `60` |
| `--no-pull` | Skip `docker pull` | pull enabled |

Environment variables: `CONTAINER_NAME`, `IMAGE_NAME`, `PORT`, `CPUS`, `MEMORY`, `HEALTH_CHECK_TIMEOUT`, `PULL`

## Server Configuration

The LlamaEdge API server supports extensive runtime options. Common parameters baked into each image via `init.sh`:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--ctx-size` | Context window size (tokens) | varies by model |
| `--temp` | Sampling temperature (0.0–2.0) | `0.8` |
| `--batch-size` | Logical batch size | `512` |
| `--threads` | CPU threads | `2` |
| `--n-gpu-layers` | GPU offload layers | `100` |
| `--top-p` | Nucleus sampling probability | `1.0` |
| `--repeat-penalty` | Repetition penalty | `1.1` |

Full reference: [`llamaedge_api_server_helper.txt`](llamaedge_api_server_helper.txt)

Override at build time with Docker build args (see below) or fork the generated `init.sh` pattern in the `Dockerfile`.

## Docker Image Details

All images are built from a single parameterized multi-stage `Dockerfile`:

| Stage | Base | Purpose |
|-------|------|---------|
| `builder` | `debian:bookworm-slim` | Install WasmEdge, download wasm + GGUF model |
| `runtime` | `debian:bookworm-slim` | Copy artifacts only; no build tools |

Each runtime image includes:

- WasmEdge with `wasi_nn-ggml` and `wasmedge_rustls` plugins
- `llama-api-server.wasm` from LlamaEdge releases
- Pre-downloaded GGUF model weights
- Non-root `llamaedge` user, health check, and `SIGTERM` shutdown

Default upstream versions:

| Component | Version |
|-----------|---------|
| LlamaEdge API Server | `0.29.0` |
| WasmEdge Runtime | `0.17.1` |

Build arguments:

| Arg | Description |
|-----|-------------|
| `MODEL_URL` | HuggingFace URL for the GGUF model |
| `PROMPT_FORMAT` | Chat template (e.g. `llama-3-chat`, `gemma-3`, `qwen3-no-think`) |
| `CONTEXT_SIZE` | Max context window |
| `LLAMAEDGE_VERSION` | LlamaEdge release version |
| `WASMEDGE_VERSION` | WasmEdge runtime version |
| `TEMPERATURE` | Default sampling temperature |

### Building Custom Images

```bash
# Via Make
make build MODEL=gemma3-270m

# Via Docker directly
docker build \
  --build-arg MODEL_URL='https://huggingface.co/your/model.gguf' \
  --build-arg PROMPT_FORMAT='llama-3-chat' \
  --build-arg CONTEXT_SIZE=4096 \
  -t my-llamaedge:custom .
```

### Running Multiple Models

```bash
docker compose --profile all up -d

# Query different endpoints
curl http://localhost:8082/v1/chat/completions ...  # Qwen
curl http://localhost:8079/v1/chat/completions ...  # Llama
curl http://localhost:8081/v1/chat/completions ...  # Gemma 1B
curl http://localhost:8083/v1/chat/completions ...  # Gemma 270M
```

## Project Structure

```
.
├── Dockerfile                 # Multi-stage image for all models
├── docker-compose.yaml        # Four model services with profiles
├── docker-run.sh              # Standalone container runner
├── query-api.sh               # OpenAI-compatible API CLI
├── Makefile                   # build / run / query shortcuts
├── llamaedge_api_server_helper.txt  # Upstream server flag reference
├── .github/workflows/build.yaml     # Multi-arch CI → Docker Hub
└── AGENTS.md                  # Maintainer guide for AI agents
```

## CI/CD

GitHub Actions builds and pushes multi-arch images (`linux/amd64`, `linux/arm64`) to Docker Hub on:

- Push to `master` when `Dockerfile` or the workflow changes
- Manual `workflow_dispatch` (one model or all)

Images are published as `hudzy/llamaedge:<model-id>`.

## Integration Examples

### Python

```python
import requests

def query_llamaedge(prompt, base_url="http://localhost:8082", temperature=0.7):
    response = requests.post(
        f"{base_url}/v1/chat/completions",
        json={
            "model": "default",
            "messages": [{"role": "user", "content": prompt}],
            "temperature": temperature,
        },
    )
    response.raise_for_status()
    return response.json()["choices"][0]["message"]["content"]

print(query_llamaedge("What is AI?"))
```

### JavaScript / Node.js

```javascript
async function queryLlamaEdge(prompt, baseUrl = "http://localhost:8082") {
  const response = await fetch(`${baseUrl}/v1/chat/completions`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "default",
      messages: [{ role: "user", content: prompt }],
      temperature: 0.7,
    }),
  });

  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  const data = await response.json();
  return data.choices[0].message.content;
}

queryLlamaEdge("Hello!").then(console.log);
```

### OpenAI Python SDK

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:8082/v1", api_key="not-needed")

response = client.chat.completions.create(
    model="default",
    messages=[{"role": "user", "content": "What is AI?"}],
)
print(response.choices[0].message.content)
```

## System Requirements

| | Minimum | Recommended |
|---|---------|-------------|
| CPU | 2 cores | 4+ cores |
| RAM | 4 GB | 8 GB+ |
| Storage | 8 GB | 16 GB SSD |
| GPU | — | Optional (CPU inference by default) |

Host RAM needs depend on how you run the container. The Compose defaults allocate 6 GB per 1B-class model and 4 GB for `gemma3-270m` — see [Default host ports and resource limits](#default-host-ports-and-resource-limits). Allow extra headroom on the host when running multiple containers.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Container won't start | Check Docker: `docker ps`, view logs: `docker logs <name>` |
| Port conflict | Check port: `lsof -i :<port>`, change port in compose or run script |
| Model loading slowly | First startup loads weights into memory; health check allows 60s. Image builds download the model at build time. |
| API timeout | Increase client timeout (`TIMEOUT` for `query-api.sh`), reduce `max_tokens`, check `docker stats` |
| Out of memory | Use `gemma3-270m`, reduce Compose `mem_limit`, or run fewer models at once |

## Resources

- [LlamaEdge](https://github.com/LlamaEdge/LlamaEdge) — upstream inference project
- [WasmEdge](https://github.com/WasmEdge/WasmEdge) — WebAssembly runtime
- [second-state on HuggingFace](https://huggingface.co/second-state/) — supported GGUF models
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference) — compatible API spec

## License

MIT License — see [LICENSE](LICENSE) for details.
