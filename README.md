# LlamaEdge - Run LLMs at the Edge with Docker

LlamaEdge is a containerized solution for running lightweight Large Language Models (LLMs) efficiently using Docker and WebAssembly. It provides OpenAI-compatible API endpoints, making it easy to integrate with existing applications.

## 🎯 Overview

LlamaEdge enables you to:
- Run lightweight LLMs on resource-constrained devices
- Expose OpenAI-compatible REST APIs for your LLM models
- Choose from multiple pre-configured models
- Scale easily with Docker and Docker Compose
- Access a built-in web UI for chat interactions

## 📦 Available Models

This repository includes Docker configurations for several lightweight models:

| Model | Size | Context | Dockerfile |
|-------|------|---------|-----------|
| **Qwen 3** | 0.6B | 24,576 | `Dockerfile.qwen3-0.6b` |
| **Gemma 3** | 1B | 24,576 | `Dockerfile.gemma3-1b` |
| **Gemma 3** | 270M | 8,192 | `Dockerfile.gemma3-270m` |
| **Llama 3.2** | 1B | 24,576 | `Dockerfile.llama3.2-1b` |

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM and 4GB disk space per model
- Internet connection for downloading models on first run

### Using Docker Compose (Easiest)

1. **Clone or download this repository**

2. **Start a container:**
   ```bash
   docker-compose up -d llamaedge-llama32-1b
   ```

3. **Access the service:**
   - Web UI: http://localhost:8079
   - API: http://localhost:8079/v1/chat/completions

### Using Docker Run

Use the provided shell script for advanced configuration:

```bash
bash docker-run.sh
```

The script provides:
- Automatic health checks
- Container status monitoring
- Graceful startup and shutdown handling
- Resource limit configuration
- Pretty-printed output

Configuration options in `docker-run.sh`:
```bash
CONTAINER_NAME="qwen3-0.6b"
PORT=8082
CPUS="4.0"
MEMORY="6g"
```

## 📡 API Usage

### OpenAI-Compatible Chat API

```bash
curl -X POST http://localhost:8079/v1/chat/completions \
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

A comprehensive query script is included for easy API testing:

```bash
bash query-api.sh "What is machine learning?"
```

**Query script options:**
- `-m, --model MODEL` - Model name (default: qwen3-0.6b)
- `-t, --temperature TEMP` - Temperature 0-2 (default: 0.7)
- `-l, --max-tokens TOKENS` - Max tokens to generate (default: 1024)
- `-s, --stream` - Enable streaming mode
- `-c, --chat` - Use chat completions endpoint (default)
- `-g, --generate` - Use text generation endpoint

**Examples:**
```bash
# Simple query
bash query-api.sh "What is Python?"

# With custom temperature
bash query-api.sh -t 0.2 "Explain quantum computing"

# With streaming
bash query-api.sh -s "Tell me a story"

# Different model
API_BASE_URL=http://localhost:8081 bash query-api.sh "Hello"
```

## 🔧 Server Configuration

The LlamaEdge API Server supports extensive configuration options. Common parameters:

### Model Configuration
- `--model-name <NAME>` - Model identifier
- `--ctx-size <SIZE>` - Context window size (tokens)
- `--temp <TEMP>` - Sampling temperature (0.0-2.0)
- `--prompt-template <TEMPLATE>` - Prompt format for the model

### Performance Tuning
- `--batch-size <SIZE>` - Logical batch size (default: 512)
- `--ubatch-size <SIZE>` - Physical batch size (default: 512)
- `--threads <NUM>` - CPU threads (default: 2)
- `--n-gpu-layers <NUM>` - Layers to offload to GPU (default: 100)
- `--no-mmap true/false` - Disable memory mapping

### Sampling Parameters
- `--top-p <P>` - Nucleus sampling probability (default: 1.0)
- `--repeat-penalty <PENALTY>` - Penalize token repetition (default: 1.1)
- `--presence-penalty <PENALTY>` - Presence penalty (default: 0.0)
- `--frequency-penalty <PENALTY>` - Frequency penalty (default: 0.0)

### Server Settings
- `--socket-addr <ADDR>` - Listen address (e.g., 0.0.0.0:8080)
- `--web-ui <PATH>` - Web UI directory (default: chatbot-ui)

For complete options, see `llamaedge_api_server_helper.txt` or run:
```bash
wasmedge llama-api-server.wasm -h
```

## 🐳 Docker Image Details

All images are built from Ubuntu 22.04 and include:
- **WasmEdge Runtime** - For secure, efficient model execution
- **LlamaEdge API Server** - OpenAI-compatible REST API
- **GGML Plugin** - For efficient model inference
- **Pre-configured model** - Downloaded during image build

**Build arguments in Dockerfiles:**
- `LLAMAEDGE_VERSION` - Version of LlamaEdge to use (default: 0.28.1)
- `WASMEDGE_VERSION` - Version of WasmEdge runtime (default: 0.16.1)
- `MODEL_URL` - HuggingFace URL for the GGUF model
- `PROMPT_FORMAT` - Chat template format for the model
- `CONTEXT_SIZE` - Maximum context window (8192 for 270M model, 24576 for others)
- `TEMPERATURE` - Default sampling temperature (default: 0.8)

## 📊 Container Port Mappings

The `docker-compose.yaml` provides this configuration:

| Container | Port | Purpose |
|-----------|------|---------|
| llamaedge-llama32-1b | 8079 | Llama 3.2 1B API |

To run other models, use `docker run` or modify `docker-compose.yaml`. The docker-run.sh script provides a convenient way to run individual models.

## 🔌 Integration Examples

### Python Client

```python
import requests

def query_llamaedge(prompt, model="default", temperature=0.7):
    response = requests.post(
        "http://localhost:8080/v1/chat/completions",
        json={79
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": temperature,
        }
    )
    return response.json()

result = query_llamaedge("What is AI?")
print(result["choices"][0]["message"]["content"])
```

### JavaScript/Node.js

```javascript
const response = await fetch("http://localhost:8080/v1/chat/completions", {
  method: "POST",79
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    model: "default",
    messages: [{ role: "user", content: "Hello!" }],
    temperature: 0.7,
  }),
});

const data = await response.json();
console.log(data.choices[0].message.content);
```

## 📋 System Requirements

### Minimum
- **CPU:** 2 cores
- **RAM:** 4GB
- **Storage:** 8GB (for model + image)
- **Network:** For downloading models

### Recommended
- **CPU:** 4+ cores
- **RAM:** 8GB+
- **Storage:** 16GB SSD
- **GPU:** Optional, for acceleration

## 🛠️ Advanced Usage

### Building Custom Images

Modify a Dockerfile to use a different model:

```dockerfile
ARG MODEL_URL='https://huggingface.co/path/to/your/model.gguf'
ARG PROMPT_FORMAT='your-model-template'
ARG CONTEXT_SIZE=4096
```

Build the image:
```bash
docker build -f Dockerfile.qwen3-0.6b -t my-llamaedge:custom .
```

### Running Multiple Models

Start multiple containers on different ports:

```bash
# Terminal 1
docker run -d -p 8080:8080 hudzy/llamaedge:llama3.2-1b

# Terminal 2
docker run -d -p 8081:8080 hudzy/llamaedge:qwen3-0.6b

# Query different models
curl http://localhost:8080/v1/chat/completions ...
curl http://localhost:8081/v1/chat/completions ...
```

### Environment Variables

Pass custom configurations:

```bash
docker run -d \
  -p 8080:8080 \
  -e TEMPERATURE=0.5 \
  -e MAX_TOKENS=2048 \
  hudzy/llamaedge:llama3.2-1b
```

### Resource Limits

Limit container resources:

```bash
docker run -d \
  -p 8080:8080 \
  --cpus="4" \
  --memory="6g" \
  hudzy/llamaedge:qwen3-0.6b
```

## 🐛 Troubleshooting

### Container won't start
- Check Docker is running: `docker ps`
- View logs: `docker logs <container-name>`
- Ensure port is available: `lsof -i :<port>`

### Model downloading slowly
- Check internet connection
- Models are large (1-4GB), first startup may take time
- Logs show download progress

### API timeout
- Increase timeout in your client
- Reduce max_tokens for faster generation
- Check system resources: `docker stats`

### Memory issues
- Reduce context size: `--ctx-size 4096`
- Use smaller model variant
- Increase available Docker memory

### GPU acceleration not working
- Install Docker GPU support
- Adjust `--n-gpu-layers` parameter
- Check NVIDIA drivers: `nvidia-smi`

## 📚 Resources

- **LlamaEdge Project:** https://github.com/LlamaEdge/LlamaEdge
- **WasmEdge Runtime:** https://github.com/WasmEdge/WasmEdge
- **Model Sources:** https://huggingface.co/second-state/
- **OpenAI API Reference:** https://platform.openai.com/docs/api-reference

## 📝 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

Copyright (c) 2024 hudzy

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Report issues
- Suggest new models
- Improve documentation
- Optimize Dockerfiles

## 💡 Tips & Best Practices

1. **Start small:** Begin with the Qwen 3 0.6B model for testing
2. **Monitor resources:** Use `docker stats` to watch performance
3. **Adjust temperature:** Lower (0.0-0.5) for factual, higher (0.7-2.0) for creative responses
4. **Batch requests:** Process multiple queries together for efficiency
5. **Cache models:** Build images with models included to avoid re-downloading
6. **Use streaming:** Enable streaming for long responses
7. **Set context limits:** Adjust context size based on your needs

---

**Ready to get started?** Run `docker-compose up -d llamaedge-llama32-1b` and visit http://localhost:8079!
