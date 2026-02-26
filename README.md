# LlamaEdge - Run LLMs at the Edge with Docker

LlamaEdge is a containerized solution for running lightweight Large Language Models (LLMs) efficiently using Docker and WebAssembly. It provides OpenAI-compatible API endpoints, making it easy to integrate with existing applications.

## Overview

- Run lightweight LLMs on resource-constrained devices
- Expose OpenAI-compatible REST APIs for your LLM models
- Choose from multiple pre-configured models
- Scale easily with Docker and Docker Compose
- Access a built-in web UI for chat interactions

## Available Models

| Model | Size | Context | Port (Compose) |
|-------|------|---------|-----------------|
| Qwen 3 | 0.6B | 24,576 | 8082 |
| Llama 3.2 | 1B | 24,576 | 8079 |
| Gemma 3 | 1B | 24,576 | 8081 |
| Gemma 3 | 270M | 8,192 | 8083 |

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM and 4GB disk space per model
- `curl` and `jq` for the query script

### Using Docker Compose

```bash
# Start the Qwen 0.6B model
docker compose --profile qwen up -d

# Or start Llama 3.2
docker compose --profile llama up -d

# Start all models at once
docker compose --profile all up -d
```

Access the service:

- **Web UI:** http://localhost:8082 (Qwen) / http://localhost:8079 (Llama)
- **API:** `http://localhost:<port>/v1/chat/completions`

### Using the Run Script

```bash
# Default: Qwen 0.6B on port 8082
bash docker-run.sh

# Custom model and port
bash docker-run.sh -i hudzy/llamaedge:llama3.2-1b -n llama3 -p 8079

# Skip image pull
bash docker-run.sh --no-pull
```

### Using Make

```bash
make help           # Show all available targets
make run            # Start default model (qwen3-0.6b)
make run MODEL=gemma3-1b
make status         # Check running containers
make logs           # Tail container logs
make stop           # Stop the model
make query PROMPT="What is AI?"
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
| `-m, --model` | Model name | `qwen3-0.6b` |
| `-t, --temperature` | Temperature (0-2) | `0.7` |
| `-l, --max-tokens` | Max tokens | `1024` |
| `-s, --stream` | Streaming mode | off |
| `-g, --generate` | Text generation endpoint | chat |
| `-u, --url` | API base URL | `http://localhost:8082` |

## Server Configuration

The LlamaEdge API Server supports extensive configuration. Common parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--ctx-size` | Context window size (tokens) | varies |
| `--temp` | Sampling temperature (0.0-2.0) | `0.8` |
| `--batch-size` | Logical batch size | `512` |
| `--threads` | CPU threads | `2` |
| `--n-gpu-layers` | GPU offload layers | `100` |
| `--top-p` | Nucleus sampling probability | `1.0` |
| `--repeat-penalty` | Repetition penalty | `1.1` |

Full reference: `llamaedge_api_server_helper.txt`

## Docker Image Details

All images are built from a single parameterized `Dockerfile` and include:

- **Ubuntu 22.04** base (minimal install)
- **WasmEdge Runtime** for secure, efficient execution
- **LlamaEdge API Server** with OpenAI-compatible REST API
- **Pre-downloaded GGUF model**
- Non-root user, health check, and graceful shutdown signal

Build arguments:

| Arg | Description |
|-----|-------------|
| `MODEL_URL` | HuggingFace URL for the GGUF model |
| `PROMPT_FORMAT` | Chat template (e.g., `llama-3-chat`, `gemma-3`) |
| `CONTEXT_SIZE` | Max context window |
| `LLAMAEDGE_VERSION` | LlamaEdge release version |
| `WASMEDGE_VERSION` | WasmEdge runtime version |
| `TEMPERATURE` | Default sampling temperature |

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
| GPU | - | Optional |

## Advanced Usage

### Building Custom Images

```bash
docker build \
  --build-arg MODEL_URL='https://huggingface.co/your/model.gguf' \
  --build-arg PROMPT_FORMAT='your-template' \
  --build-arg CONTEXT_SIZE=4096 \
  -t my-llamaedge:custom .
```

### Running Multiple Models

```bash
docker compose --profile all up -d

# Query different models
curl http://localhost:8082/v1/chat/completions ...  # Qwen
curl http://localhost:8079/v1/chat/completions ...  # Llama
curl http://localhost:8081/v1/chat/completions ...  # Gemma 1B
curl http://localhost:8083/v1/chat/completions ...  # Gemma 270M
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Container won't start | Check Docker: `docker ps`, view logs: `docker logs <name>` |
| Port conflict | Check port: `lsof -i :<port>`, change port in compose or run script |
| Model loading slowly | First startup downloads the model. Watch: `docker logs -f <name>` |
| API timeout | Increase client timeout, reduce `max_tokens`, check: `docker stats` |
| Out of memory | Use a smaller model or increase Docker memory limit |

## Resources

- [LlamaEdge](https://github.com/LlamaEdge/LlamaEdge) - Upstream project
- [WasmEdge](https://github.com/WasmEdge/WasmEdge) - WebAssembly runtime
- [Models](https://huggingface.co/second-state/) - HuggingFace model repository
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference) - Compatible API spec

## License

MIT License - see [LICENSE](LICENSE) for details.
