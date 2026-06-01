.PHONY: help build build-all run stop stop-all logs status query clean list-models

MODELS := qwen3.5-0.8b llama3.2-1b gemma3-1b gemma3-270m
MODEL  ?= qwen3.5-0.8b
PROMPT ?= Hello, who are you?
COMPOSE ?= $(shell if docker compose version >/dev/null 2>&1; then echo "docker compose"; elif command -v docker-compose >/dev/null 2>&1; then echo "docker-compose"; else echo "docker compose"; fi)

help: ## Show this help
	@grep -E '^[a-zA-Z_.-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

build: ## Build a model image (MODEL=qwen3.5-0.8b)
	$(COMPOSE) build $(MODEL)

build-all: ## Build all model images
	$(COMPOSE) --profile all build

run: ## Run a model container (MODEL=qwen3.5-0.8b)
	$(COMPOSE) up -d $(MODEL)
	@echo "\n  API: http://localhost:$$($(COMPOSE) port $(MODEL) 8080 2>/dev/null | cut -d: -f2 || echo '?')"

stop: ## Stop a model container (MODEL=qwen3.5-0.8b)
	$(COMPOSE) stop $(MODEL)

stop-all: ## Stop all running containers
	$(COMPOSE) --profile all down

logs: ## Tail logs for a model (MODEL=qwen3.5-0.8b)
	$(COMPOSE) logs -f $(MODEL)

status: ## Show status of all containers
	@docker ps --filter "name=llamaedge" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

query: ## Quick test query (PROMPT="Hello, who are you?")
	@bash query-api.sh "$(PROMPT)"

clean: ## Remove all llamaedge containers and images
	$(COMPOSE) --profile all down --rmi local -v 2>/dev/null || true
	@echo "Cleaned up llamaedge containers and local images"

list-models: ## List available models
	@for m in $(MODELS); do echo "  $$m"; done
