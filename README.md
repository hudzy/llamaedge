# LlamaEdge - Run LLMs at the Edge with Docker

Docker packaging for [LlamaEdge](https://github.com/LlamaEdge/LlamaEdge), a WebAssembly LLM inference server with an OpenAI-compatible REST API.

This repository contains no application source code. It provides a parameterized `Dockerfile`, Docker Compose services, helper scripts, a `Makefile`, and CI that publishes pre-built images to Docker Hub as `hudzy/llamaedge:<model-id>`.

## Available Models

Each row is one Docker image tag and one Compose service name. Use the model ID with `make run MODEL=...`, `docker compose up -d <service>`, or as the image tag for `docker-run.sh -i`.

| Model ID | Model | Weights | Context (tokens) | Compose profile |
|----------|-------|---------|------------------|-----------------|
| `qwen3.5-0.8b` | Qwen 3.5 0.8B | 563 MB | 24,576 | `qwen` |
| `llama3.2-1b` | Llama 3.2 1B Instruct | 869 MB | 24,576 | `llama` |
| `gemma3-1b` | Gemma 3 1B IT | 812 MB | 24,576 | `gemma` |
| `gemma3-270m` | Gemma 3 270M IT | 248 MB | 8,192 | `gemma` |

Weights are Q5_K_M GGUF files, downloaded at build time and baked into the image. Every service also belongs to the `all` profile. Context size is fixed per image at build time via the `CONTEXT_SIZE` build arg.

```bash
make list-models
```

### Ports and resource limits

The server always listens on port **8080 inside the container**. The host port and resource limits below are defaults from [`docker-compose.yaml`](docker-compose.yaml) — they are not properties of the models, and you can override them in Compose or with `docker-run.sh -p`, `-c`, and `-m`.

| Service / model ID | Host port | API base URL | CPU limit | Memory limit |
|--------------------|-----------|--------------|-----------|--------------|
| `qwen3.5-0.8b` | 8082 | `http://localhost:8082/v1` | 4 | 6 GB |
| `llama3.2-1b` | 8079 | `http://localhost:8079/v1` | 4 | 6 GB |
| `gemma3-1b` | 8081 | `http://localhost:8081/v1` | 4 | 6 GB |
| `gemma3-270m` | 8083 | `http://localhost:8083/v1` | 2 | 4 GB |

`docker-run.sh` defaults match the `qwen3.5-0.8b` row.

> [!NOTE]
> Profile `gemma` starts **both** Gemma services. Use a service name directly (`docker compose up -d gemma3-270m`) to run only one.

> [!IMPORTANT]
> These images serve the REST API only. The server is launched with `--web-ui chatbot-ui`, but the [chatbot-ui](https://github.com/LlamaEdge/chatbot-ui) bundle is not included in the image, so there is no browser UI at the host port.

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Free RAM matching the limit for your model (4 GB for `gemma3-270m`, 6 GB for the others)
- Disk space for the image: model weights per the table above, plus the Debian base and WasmEdge runtime
- `curl` and `jq` on the host for `query-api.sh`

Examples use Docker Compose v2 (`docker compose`). If your environment uses the legacy standalone binary, substitute `docker-compose`; the Makefile auto-detects either form.

### Run a pre-built image

```bash
# Default: Qwen 3.5 0.8B on port 8082
bash docker-run.sh

# Llama 3.2 1B on port 8079
bash docker-run.sh -i hudzy/llamaedge:llama3.2-1b -n llamaedge-llama3.2-1b -p 8079

# Skip the pull if the image is already local
bash docker-run.sh --no-pull
```

`docker-run.sh` wraps `docker run` with resource limits and waits for the container health check:

| Flag | Description | Default |
|------|-------------|---------|
| `-n, --name` | Container name | `llamaedge-qwen3.5-0.8b` |
| `-i, --image` | Docker image | `hudzy/llamaedge:qwen3.5-0.8b` |
| `-p, --port` | Host port | `8082` |
| `-c, --cpus` | CPU limit | `4.0` |
| `-m, --memory` | Memory limit | `6g` |
| `-t, --timeout` | Health check wait, seconds | `60` |
| `--no-pull` | Skip `docker pull` | pull enabled |

Equivalent environment variables: `CONTAINER_NAME`, `IMAGE_NAME`, `PORT`, `CPUS`, `MEMORY`, `HEALTH_CHECK_TIMEOUT`, `PULL`.

### Docker Compose

```bash
docker compose up -d qwen3.5-0.8b     # one service by name
docker compose --profile qwen up -d   # by profile
docker compose --profile all up -d    # every model
```

### Make

```bash
make help                       # List all targets
make build MODEL=gemma3-270m    # Build one image locally
make build-all                  # Build every model image
make run MODEL=llama3.2-1b      # Start a model (default: qwen3.5-0.8b)
make status                     # Show running llamaedge containers
make logs MODEL=gemma3-1b       # Tail logs
make stop                       # Stop the selected model
make stop-all                   # Stop all Compose services
make query PROMPT="What is AI?" # Send a test prompt
make clean                      # Remove containers and local images
```

## API Usage

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

Because the API is OpenAI-compatible, any OpenAI client works by pointing it at the model's base URL:

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:8082/v1", api_key="not-needed")

response = client.chat.completions.create(
    model="default",
    messages=[{"role": "user", "content": "What is AI?"}],
)
print(response.choices[0].message.content)
```

### query-api.sh

```bash
bash query-api.sh "What is machine learning?"
bash query-api.sh -t 0.2 -s "Explain quantum computing"
API_BASE_URL=http://localhost:8079 bash query-api.sh "Hello"
```

| Flag | Description | Default |
|------|-------------|---------|
| `-m, --model` | Model name or alias | `default` |
| `-t, --temperature` | Temperature, 0–2 | `0.7` |
| `-l, --max-tokens` | Max tokens | `1024` |
| `-s, --stream` | Streaming mode | off |
| `-c, --chat` | Use `/v1/chat/completions` | on |
| `-g, --generate` | Use `/v1/completions` | off |
| `-u, --url` | API base URL | `http://localhost:8082` |

Equivalent environment variables: `API_BASE_URL`, `MODEL`, `TEMPERATURE`, `MAX_TOKENS`, `TIMEOUT`.

## Image Details

One parameterized multi-stage `Dockerfile` builds every model image:

| Stage | Base | Purpose |
|-------|------|---------|
| `builder` | `debian:bookworm-slim` | Install WasmEdge, download the wasm server and GGUF weights, generate `init.sh` |
| `runtime` | `debian:bookworm-slim` | Copy artifacts only, no build tools |

Each runtime image contains WasmEdge with the `wasi_nn-ggml` and `wasmedge_rustls` plugins, `llama-api-server.wasm`, the model weights, and runs as the non-root `llamaedge` user with a health check on `/v1/models` and `STOPSIGNAL SIGTERM`.

Pinned upstream versions: LlamaEdge API Server `0.29.0`, WasmEdge `0.17.1`.

### Build arguments

| Arg | Description | Default |
|-----|-------------|---------|
| `MODEL_URL` | URL of the GGUF weights | required |
| `PROMPT_FORMAT` | Chat template, e.g. `llama-3-chat`, `gemma-3`, `qwen3-no-think` | required |
| `CONTEXT_SIZE` | Context window in tokens | `24576` |
| `TEMPERATURE` | Sampling temperature | `0.8` |
| `LLAMAEDGE_VERSION` | LlamaEdge release | `0.29.0` |
| `WASMEDGE_VERSION` | WasmEdge release | `0.17.1` |

These are the only server settings the image configures, alongside the fixed `--model-name`, `--socket-addr 0.0.0.0:8080`, and `--nn-preload` values written into `/app/init.sh`. Every other server flag falls back to its upstream default, including `--threads 2`, `--batch-size 512`, and `--top-p 1.0`. See [`llamaedge_api_server_helper.txt`](llamaedge_api_server_helper.txt) for the full flag reference; changing those requires editing the `init.sh` template in the `Dockerfile`.

```bash
docker build \
  --build-arg MODEL_URL='https://huggingface.co/your/model.gguf' \
  --build-arg PROMPT_FORMAT='llama-3-chat' \
  --build-arg CONTEXT_SIZE=4096 \
  -t my-llamaedge:custom .
```

## Project Structure

```
.
├── Dockerfile                       # Multi-stage image for all models
├── docker-compose.yaml              # Four model services with profiles
├── docker-run.sh                    # Standalone container runner
├── query-api.sh                     # API query CLI
├── Makefile                         # Build / run / query shortcuts
├── llamaedge_api_server_helper.txt  # Upstream server flag reference
├── .github/workflows/build.yaml     # Multi-arch CI to Docker Hub
└── AGENTS.md                        # Repository guide for AI agents
```

## CI/CD

[`build.yaml`](.github/workflows/build.yaml) builds `linux/amd64` and `linux/arm64` images and pushes them to Docker Hub on push to `master` when the `Dockerfile` or the workflow itself changes, or on manual `workflow_dispatch` for one model or all of them.

## Troubleshooting

| Problem | Suggestion |
|---------|------------|
| Container won't start | `docker ps -a`, then `docker logs <name>` |
| Port already in use | `lsof -i :<port>`, then change the host port in Compose or with `docker-run.sh -p` |
| Slow first response | Weights load into memory on startup; the health check allows a 60s start period |
| Request times out | Raise `TIMEOUT` for `query-api.sh`, lower `max_tokens`, and check `docker stats` |
| Container killed / out of memory | Raise the Compose `mem_limit`, switch to `gemma3-270m`, or run fewer models at once |
| Slow generation | The server defaults to `--threads 2`; raise it by editing the `init.sh` template in the `Dockerfile` |

## Resources

- [LlamaEdge](https://github.com/LlamaEdge/LlamaEdge) — upstream inference server
- [WasmEdge](https://github.com/WasmEdge/WasmEdge) — WebAssembly runtime
- [OpenAI API reference](https://platform.openai.com/docs/api-reference) — the API shape this server implements

## License

MIT License — see [LICENSE](LICENSE) for details.
