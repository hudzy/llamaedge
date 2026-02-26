#!/bin/bash

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'

API_BASE_URL="${API_BASE_URL:-http://localhost:8082}"
MODEL="${MODEL:-qwen3-0.6b}"
TEMPERATURE="${TEMPERATURE:-0.7}"
MAX_TOKENS="${MAX_TOKENS:-1024}"
TIMEOUT="${TIMEOUT:-300}"

log()     { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[ok] $1${NC}"; }
error()   { echo -e "${RED}[error] $1${NC}" >&2; }

usage() {
    cat <<EOF
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

Environment variables: API_BASE_URL, MODEL, TEMPERATURE, MAX_TOKENS, TIMEOUT

Examples:
  $0 "What is the capital of France?"
  $0 -m llama3.2-1b -t 0.5 "Explain quantum computing"
  $0 --stream "Write a short poem about AI"
  $0 --generate -l 512 "Hello, how are you"

EOF
    exit 0
}

check_dependencies() {
    local missing=()
    for cmd in curl jq; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required commands: ${missing[*]}"
        exit 1
    fi
}

PROMPT=""
STREAM=false
ENDPOINT="chat/completions"

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--model)       MODEL="$2";       shift 2 ;;
        -t|--temperature) TEMPERATURE="$2"; shift 2 ;;
        -l|--max-tokens)  MAX_TOKENS="$2";  shift 2 ;;
        -s|--stream)      STREAM=true;      shift   ;;
        -c|--chat)        ENDPOINT="chat/completions"; shift ;;
        -g|--generate)    ENDPOINT="completions";      shift ;;
        -u|--url)         API_BASE_URL="$2"; shift 2 ;;
        -h|--help)        usage ;;
        -*)
            error "Unknown option: $1"
            usage
            ;;
        *)
            PROMPT="$1"
            shift
            ;;
    esac
done

if [[ -z "$PROMPT" ]]; then
    error "No prompt provided"
    echo ""
    usage
fi

check_dependencies

log "Checking API connectivity..."
if ! curl -sf --connect-timeout 5 "${API_BASE_URL}/v1/models" >/dev/null 2>&1; then
    if ! curl -sf --connect-timeout 5 "${API_BASE_URL}/echo" >/dev/null 2>&1; then
        error "Cannot connect to API at ${API_BASE_URL}"
        error "Make sure the container is running: docker ps | grep llamaedge"
        exit 1
    fi
fi
success "API is reachable"

if [[ "$ENDPOINT" == "chat/completions" ]]; then
    PAYLOAD=$(jq -n \
        --arg model "$MODEL" \
        --arg content "$PROMPT" \
        --argjson temperature "$TEMPERATURE" \
        --argjson max_tokens "$MAX_TOKENS" \
        --argjson stream "$STREAM" \
        '{
            model: $model,
            messages: [{ role: "user", content: $content }],
            temperature: $temperature,
            max_tokens: $max_tokens,
            stream: $stream
        }')
else
    PAYLOAD=$(jq -n \
        --arg model "$MODEL" \
        --arg prompt "$PROMPT" \
        --argjson temperature "$TEMPERATURE" \
        --argjson max_tokens "$MAX_TOKENS" \
        --argjson stream "$STREAM" \
        '{
            model: $model,
            prompt: $prompt,
            temperature: $temperature,
            max_tokens: $max_tokens,
            stream: $stream
        }')
fi

log "Sending request to ${CYAN}${API_BASE_URL}/v1/${ENDPOINT}${NC}"
log "Model: ${CYAN}${MODEL}${NC} | Temp: ${CYAN}${TEMPERATURE}${NC} | Tokens: ${CYAN}${MAX_TOKENS}${NC}"
log "Prompt: ${MAGENTA}${PROMPT:0:80}${NC}$([ ${#PROMPT} -gt 80 ] && echo '...')"
echo ""

if [[ "$STREAM" == true ]]; then
    echo -e "${CYAN}Response (streaming):${NC}"
    curl -sS --max-time "$TIMEOUT" \
        -X POST \
        -H "Content-Type: application/json" \
        "${API_BASE_URL}/v1/${ENDPOINT}" \
        -d "$PAYLOAD" | \
        while IFS= read -r line; do
            if [[ $line == data:\ * ]]; then
                json_str="${line#data: }"
                if [[ "$json_str" != "[DONE]" && -n "$json_str" ]]; then
                    if [[ "$ENDPOINT" == "chat/completions" ]]; then
                        echo "$json_str" | jq -rj '.choices[0].delta.content // empty' 2>/dev/null || true
                    else
                        echo "$json_str" | jq -rj '.choices[0].text // empty' 2>/dev/null || true
                    fi
                fi
            fi
        done
    echo ""
else
    RESPONSE=$(curl -sS --max-time "$TIMEOUT" \
        -w '\n%{http_code}' \
        -X POST \
        -H "Content-Type: application/json" \
        "${API_BASE_URL}/v1/${ENDPOINT}" \
        -d "$PAYLOAD")

    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [[ "$HTTP_CODE" -ge 400 ]]; then
        error "API returned HTTP $HTTP_CODE"
        echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
        exit 1
    fi

    if ! echo "$BODY" | jq empty 2>/dev/null; then
        error "Invalid JSON response from API"
        echo "$BODY"
        exit 1
    fi

    if [[ "$ENDPOINT" == "chat/completions" ]]; then
        CONTENT=$(echo "$BODY" | jq -r '.choices[0].message.content // .error.message // "No response"')
    else
        CONTENT=$(echo "$BODY" | jq -r '.choices[0].text // .error.message // "No response"')
    fi

    echo -e "${CYAN}Response:${NC}"
    echo "$CONTENT"

    USAGE=$(echo "$BODY" | jq '.usage // empty' 2>/dev/null)
    if [[ -n "$USAGE" ]]; then
        echo ""
        echo -e "${BLUE}Token Usage:${NC}"
        echo "$USAGE" | jq -r '"  Prompt: \(.prompt_tokens), Completion: \(.completion_tokens), Total: \(.total_tokens)"'
    fi
fi

echo ""
success "Query completed"
