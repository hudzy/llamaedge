.PHONY: help build run stop logs status query clean

MODELS := qwen3.5-0.8b llama3.2-1b gemma3-1b gemma3-270m
MODEL  ?= qwen3.5-0.8b

help: ## Show this help
	@grep -E '^[a-zA-Z_.-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

build: ## Build a model image (MODEL=qwen3.5-0.8b)
	docker compose build $(MODEL)

build-all: ## Build all model images
	docker compose build

run: ## Run a model container (MODEL=qwen3.5-0.8b)
	docker compose --profile $(MODEL) up -d
	@echo "\n  API: http://localhost:$$(docker compose port $(MODEL) 8080 2>/dev/null | cut -d: -f2 || echo '?')"

stop: ## Stop a model container (MODEL=qwen3.5-0.8b)
	docker compose --profile $(MODEL) down

stop-all: ## Stop all running containers
	docker compose --profile all down

logs: ## Tail logs for a model (MODEL=qwen3.5-0.8b)
	docker compose logs -f $(MODEL)

status: ## Show status of all containers
	@docker ps --filter "name=llamaedge" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

query: ## Quick test query (MODEL=qwen3.5-0.8b, PROMPT="Hello")
	@bash query-api.sh "$(or $(PROMPT),Hello, who are you?)"

clean: ## Remove all llamaedge containers and images
	docker compose --profile all down --rmi local -v 2>/dev/null || true
	@echo "Cleaned up llamaedge containers and local images"

list-models: ## List available models
	@for m in $(MODELS); do echo "  $$m"; done
