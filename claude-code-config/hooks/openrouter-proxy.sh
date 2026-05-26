#!/usr/bin/env bash
# Open Router API proxy — translates Claude Code API requests to Open Router format.
# Used when Claude quota is exhausted and fallback is active.
#
# This script is called by Claude Code's MCP/proxy mechanism when the
# <model_routing_hint> indicates Open Router fallback.
#
# Usage: openrouter-proxy.sh <model> <api-key> <request-json>
# Outputs: Open Router API response in Claude-compatible format

_HOME="${USERPROFILE:-$HOME}"
CONFIG="$_HOME/.claude/openrouter-config.json"

# Load config
if [ ! -f "$CONFIG" ]; then
    echo '{"error": "Open Router config not found"}' >&2
    exit 1
fi

API_KEY=$(jq -r '.apiKey // empty' "$CONFIG" 2>/dev/null)
if [ -z "$API_KEY" ] || [ "$API_KEY" = "sk-or-v1-YOUR-KEY-HERE" ]; then
    echo '{"error": "Open Router API key not configured — edit ~/.claude/openrouter-config.json and add your key"}' >&2
    exit 1
fi

# Open Router API endpoint
OR_ENDPOINT="https://openrouter.ai/api/v1/chat/completions"

# Read request from stdin (JSON)
REQUEST=$(cat)

# Extract model from request and map to Open Router model if needed
REQUEST_MODEL=$(echo "$REQUEST" | jq -r '.model // empty' 2>/dev/null)

# Map Claude model names to Open Router slugs
case "$REQUEST_MODEL" in
    claude-haiku*|haiku|claude-3-haiku*|claude-3.5-haiku*)
        OR_MODEL=$(jq -r '.modelMapping.haiku // "anthropic/claude-3.5-haiku"' "$CONFIG" 2>/dev/null)
        ;;
    claude-sonnet*|sonnet|claude-3-sonnet*|claude-4-sonnet*)
        OR_MODEL=$(jq -r '.modelMapping.sonnet // "anthropic/claude-sonnet-4-20250514"' "$CONFIG" 2>/dev/null)
        ;;
    claude-opus*|opus|claude-4-opus*)
        OR_MODEL=$(jq -r '.modelMapping.opus // "anthropic/claude-opus-4-20250514"' "$CONFIG" 2>/dev/null)
        ;;
    anthropic/*)
        # Already in Open Router format
        OR_MODEL="$REQUEST_MODEL"
        ;;
    *)
        # Default to sonnet
        OR_MODEL=$(jq -r '.modelMapping.sonnet // "anthropic/claude-sonnet-4-20250514"' "$CONFIG" 2>/dev/null)
        ;;
esac

# Transform request to Open Router format
# Open Router uses the same chat completions format as OpenAI/Claude
# but with a different model name format
OR_REQUEST=$(echo "$REQUEST" | jq --arg model "$OR_MODEL" '.model = $model' 2>/dev/null)

# Make request to Open Router
HTTP_RESPONSE=$(curl -s -w '\n%{http_code}' \
    --connect-timeout 10 --max-time 120 \
    -X POST "$OR_ENDPOINT" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -H "HTTP-Referer: https://claude.ai" \
    -H "X-Title: Claude Code" \
    -d "$OR_REQUEST" 2>/dev/null)

# Extract HTTP status code (last line) and body
HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -1)
BODY=$(echo "$HTTP_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    echo "{\"error\": \"Open Router request failed (HTTP $HTTP_CODE)\", \"raw\": $(echo "$BODY" | jq -R . 2>/dev/null || echo "$BODY")}" >&2
    exit 1
fi

# Transform response back to Claude-compatible format
# Open Router returns OpenAI-compatible format, which is very similar to Claude
# Map the response fields if needed
echo "$BODY" | jq '
    # Keep the response as-is — Open Router returns compatible format
    # Add metadata to indicate this came from Open Router
    . + {
        "_provider": "openrouter",
        "_model_used": .model
    }
' 2>/dev/null || echo "$BODY"