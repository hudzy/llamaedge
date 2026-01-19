#!/bin/bash

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
API_BASE_URL="${API_BASE_URL:-http://localhost:8082}"
MODEL="${MODEL:-qwen3-0.6b}"
TEMPERATURE="${TEMPERATURE:-0.7}"
MAX_TOKENS="${MAX_TOKENS:-1024}"
TIMEOUT=300

# Helper functions
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

error() {
    echo -e "${RED}✗ Error: $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

usage() {
    cat << EOF
${CYAN}LlamaEdge OpenAI API Query Tool${NC}

Usage: $0 [OPTIONS] "<prompt>"

Options:
  -m, --model MODEL           Model to use (default: $MODEL)
  -t, --temperature TEMP      Temperature 0-2 (default: $TEMPERATURE)
  -l, --max-tokens TOKENS     Max tokens to generate (default: $MAX_TOKENS)
  -s, --stream                Enable streaming mode
  -c, --chat                  Use chat completions endpoint (default)
  -g, --generate              Use text generation endpoint
  -u, --url URL               API base URL (default: $API_BASE_URL)
  -h, --help                  Show this help message

Examples:
  $0 "What is the capital of France?"
  $0 -m llama3.2-1b -t 0.5 "Explain quantum computing"
  $0 --stream "Write a short poem about AI"
  $0 --generate -l 512 "Hello, how are you"

EOF
    exit 0
}

# Parse arguments
PROMPT=""
STREAM=false
ENDPOINT="chat/completions"

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        -t|--temperature)
            TEMPERATURE="$2"
            shift 2
            ;;
        -l|--max-tokens)
            MAX_TOKENS="$2"
            shift 2
            ;;
        -s|--stream)
            STREAM=true
            shift
            ;;
        -c|--chat)
            ENDPOINT="chat/completions"
            shift
            ;;
        -g|--generate)
            ENDPOINT="completions"
            shift
            ;;
        -u|--url)
            API_BASE_URL="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            PROMPT="$1"
            shift
            ;;
    esac
done

# Validate prompt
if [ -z "$PROMPT" ]; then
    error "No prompt provided"
    echo ""
    usage
fi

# Check API connectivity
log "Checking API connectivity..."
if ! curl -s --connect-timeout 5 "${API_BASE_URL}/health" > /dev/null 2>&1; then
    if ! curl -s --connect-timeout 5 "${API_BASE_URL}/models" > /dev/null 2>&1; then
        error "Cannot connect to API at ${API_BASE_URL}"
        error "Make sure the container is running: docker ps | grep llama"
        exit 1
    fi
fi
success "API is reachable"

# Build request payload
if [ "$ENDPOINT" = "chat/completions" ]; then
    PAYLOAD=$(cat <<EOF
{
  "model": "$MODEL",
  "messages": [
    {
      "role": "user",
      "content": "$PROMPT"
    }
  ],
  "temperature": $TEMPERATURE,
  "max_tokens": $MAX_TOKENS,
  "stream": $STREAM
}
EOF
)
else
    PAYLOAD=$(cat <<EOF
{
  "model": "$MODEL",
  "prompt": "$PROMPT",
  "temperature": $TEMPERATURE,
  "max_tokens": $MAX_TOKENS,
  "stream": $STREAM
}
EOF
)
fi

# Display request info
log "Sending request to ${CYAN}${API_BASE_URL}/v1/${ENDPOINT}${NC}"
log "Model: ${CYAN}${MODEL}${NC} | Temp: ${CYAN}${TEMPERATURE}${NC} | Tokens: ${CYAN}${MAX_TOKENS}${NC}"
log "Prompt: ${MAGENTA}${PROMPT:0:80}${NC}$([ ${#PROMPT} -gt 80 ] && echo "...")"
echo ""

# Send request and process response
if [ "$STREAM" = true ]; then
    # Streaming mode
    echo -e "${CYAN}Response (streaming):${NC}"
    curl -s --max-time $TIMEOUT \
        -X POST \
        -H "Content-Type: application/json" \
        "${API_BASE_URL}/v1/${ENDPOINT}" \
        -d "$PAYLOAD" | \
        while IFS= read -r line; do
            if [[ $line == data:\ * ]]; then
                # Extract JSON from SSE format
                json_str="${line#data: }"
                if [ "$json_str" != "[DONE]" ] && [ -n "$json_str" ]; then
                    # Extract content based on endpoint
                    if [ "$ENDPOINT" = "chat/completions" ]; then
                        echo "$json_str" | jq -r '.choices[0].delta.content // empty' 2>/dev/null || true
                    else
                        echo "$json_str" | jq -r '.choices[0].text // empty' 2>/dev/null || true
                    fi
                fi
            fi
        done
else
    # Non-streaming mode
    RESPONSE=$(curl -s --max-time $TIMEOUT \
        -X POST \
        -H "Content-Type: application/json" \
        "${API_BASE_URL}/v1/${ENDPOINT}" \
        -d "$PAYLOAD")
    
    # Check if response is valid JSON
    if ! echo "$RESPONSE" | jq empty 2>/dev/null; then
        error "Invalid JSON response from API"
        echo "$RESPONSE"
        exit 1
    fi
    
    # Extract and display response
    if [ "$ENDPOINT" = "chat/completions" ]; then
        CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // .error.message // "No response"')
    else
        CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].text // .error.message // "No response"')
    fi
    
    echo -e "${CYAN}Response:${NC}"
    echo "$CONTENT"
    
    # Show token usage if available
    USAGE=$(echo "$RESPONSE" | jq '.usage // empty' 2>/dev/null)
    if [ -n "$USAGE" ]; then
        echo ""
        echo -e "${BLUE}Token Usage:${NC}"
        echo "$USAGE" | jq -r '"  Prompt: \(.prompt_tokens), Completion: \(.completion_tokens), Total: \(.total_tokens)"'
    fi
fi

echo ""
success "Query completed"
