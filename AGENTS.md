# AGENTS.md — LlamaEdge

## Project Overview

Docker-based packaging and deployment of [LlamaEdge](https://github.com/LlamaEdge/LlamaEdge),
a WebAssembly LLM inference server. This is an infrastructure/DevOps repository — there is
no compiled application source code (no Rust, Python, JS, etc.). The codebase consists of a
parameterized Dockerfile, Docker Compose config, Bash scripts, a Makefile, and CI/CD workflows.

Supported models: Qwen3.5-0.8B, Llama3.2-1B, Gemma3-1B, Gemma3-270M (all GGUF-quantized).

## Repository Structure

```
.
├── Dockerfile              # Parameterized multi-model Docker image
├── docker-compose.yaml     # Service definitions for all models
├── docker-run.sh           # Standalone container runner with health checks
├── query-api.sh            # CLI tool for querying the OpenAI-compatible API
├── Makefile                # Developer workflow shortcuts
├── .editorconfig           # Formatting rules (indentation, line endings)
├── .github/workflows/
│   └── build.yaml          # CI: multi-arch Docker build + push to Docker Hub
├── llamaedge_api_server_helper.txt  # LlamaEdge server parameter reference
├── README.md               # User-facing documentation
└── AGENTS.md               # This file
```

## Build / Run / Test Commands

There is no compilation step. "Building" means creating Docker images.

### Build

```bash
make build                    # Build default model image (qwen3.5-0.8b)
make build MODEL=gemma3-1b   # Build a specific model image
make build-all                # Build all model images
```

Under the hood these run `docker compose build <model>`.

### Run

```bash
make run                      # Start default model (qwen3.5-0.8b)
make run MODEL=llama3.2-1b   # Start a specific model
make stop                     # Stop default model
make stop-all                 # Stop all containers
make status                   # Show running container status
make logs                     # Tail logs for default model
```

Or use the standalone script:

```bash
bash docker-run.sh                                          # Default: Qwen on port 8082
bash docker-run.sh -i hudzy/llamaedge:llama3.2-1b -p 8079  # Custom model
```

### Testing / Verification

There are no automated tests or test framework. Manual verification is done via:

```bash
make query                              # Quick test with default prompt
make query PROMPT="What is AI?"         # Custom prompt
bash query-api.sh "Hello, who are you?" # Direct script usage
bash query-api.sh -s "Stream test"      # Streaming mode
```

The healthcheck endpoint is `GET /v1/models` on port 8080 inside the container.

### CI/CD

The GitHub Actions workflow (`.github/workflows/build.yaml`) triggers on:
- Push to `master` when `Dockerfile` or the workflow file changes
- Manual `workflow_dispatch` (select a single model or all)

It builds multi-arch images (`linux/amd64`, `linux/arm64`) and pushes to Docker Hub
as `hudzy/llamaedge:<model-tag>`.

### Available Models and Ports

| Make MODEL value | Docker Compose port | Profile  |
|------------------|---------------------|----------|
| `qwen3.5-0.8b`  | 8082                | qwen     |
| `llama3.2-1b`   | 8079                | llama    |
| `gemma3-1b`     | 8081                | gemma    |
| `gemma3-270m`   | 8083                | gemma    |

List all models: `make list-models`

## Code Style Guidelines

### General Formatting (.editorconfig)

- **Line endings:** LF (`\n`) — never CRLF
- **Final newline:** Always insert a trailing newline at end of file
- **Trailing whitespace:** Always trim
- **Charset:** UTF-8

### File-Specific Indentation

| File type           | Indent style | Indent size |
|---------------------|-------------|-------------|
| YAML (`.yaml/.yml`) | spaces      | 2           |
| Shell (`.sh/.bash`) | spaces      | 4           |
| Dockerfile          | spaces      | 2           |
| Makefile            | tabs        | (tab)       |

### Bash Script Conventions

All Bash scripts in this repo follow these patterns:

1. **Shebang and strict mode:** Every script starts with `#!/bin/bash` + `set -euo pipefail`
2. **Color constants:** Defined as `readonly` at the top (RED, GREEN, YELLOW, BLUE, CYAN, NC)
3. **Logging functions:** `log()`, `success()`, `error()`, `warn()` — `error` writes to stderr
4. **Defaults via parameter expansion:** `PORT="${PORT:-8082}"`
5. **Argument parsing:** `while [[ $# -gt 0 ]]; do case $1 in ...` with short/long options
6. **Usage function:** Every script has `usage()` with a heredoc — called on `-h|--help`
7. **Dependency checks:** Verify commands with `command -v <cmd> >/dev/null 2>&1`
8. **Error handling:** Explicit exit codes. Use `trap` for cleanup on EXIT/INT/TERM
9. **Quoting:** Always double-quote variable expansions (`"$VAR"`, `"${VAR}"`)

### Dockerfile Conventions

- Single parameterized `Dockerfile` for all models (build args differentiate them)
- Use `ARG` for configurable values with sensible defaults
- Minimize layers: chain commands with `&&`, clean up in the same layer
- Run as non-root user (`llamaedge`) — create with `adduser --disabled-password`
- Include `HEALTHCHECK`, `EXPOSE`, `STOPSIGNAL SIGTERM`, and OCI labels
- Use `ENTRYPOINT ["/bin/bash"]` + `CMD ["/app/init.sh"]` pattern

### Docker Compose Conventions

- Each service uses `profiles` for selective startup
- Set resource limits (`cpus`, `mem_limit`) per service
- Use `restart: unless-stopped`
- Container names follow pattern: `llamaedge-<model-name>`

### Makefile Conventions

- Declare all targets as `.PHONY`
- Use `?=` for overridable variables (e.g., `MODEL ?= qwen3.5-0.8b`)
- Every target has a `## Comment` for the self-documenting `make help`
- Use `@` prefix for display-only commands to suppress echo

### Naming Conventions

- **Model identifiers:** lowercase with dots for versions: `qwen3.5-0.8b`, `llama3.2-1b`
- **Container names:** `llamaedge-<model-id>` (e.g., `llamaedge-qwen3.5-0.8b`)
- **Docker image tags:** `hudzy/llamaedge:<model-id>`
- **Bash variables:** UPPER_SNAKE_CASE for exported/config vars, lower_snake_case for locals
- **Makefile targets:** lowercase with hyphens (e.g., `build-all`, `stop-all`, `list-models`)

### Error Handling

- Bash: `set -euo pipefail` enforces fail-fast. Use `trap` for cleanup.
- Docker: Always check command success before proceeding (guard with `if ! ...`)
- API queries: Validate HTTP status codes, check JSON validity, print meaningful errors

### Security

- Never commit `.env` files or model weights (`.gguf`) — both are in `.gitignore`
- Docker images run as non-root user
- `DOCKERHUB_TOKEN` is stored as a GitHub Actions secret — never hardcoded
