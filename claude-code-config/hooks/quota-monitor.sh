#!/usr/bin/env bash
# Quota monitor — detects Claude API quota exhaustion (429) and activates Open Router fallback.
# Runs as UserPromptSubmit hook (after model-router.sh).
# Checks recent API error logs and the usage cache to determine if quota is exhausted.

_HOME="${USERPROFILE:-$HOME}"
CONFIG="$_HOME/.claude/openrouter-config.json"
_TMPDIR="${TMPDIR:-${TMP:-/tmp}}"
USAGE_CACHE="$_TMPDIR/claude-usage-cache.json"
QUOTA_FLAG="$_TMPDIR/claude-quota-exhausted.flag"

# Exit if config doesn't exist or fallback is disabled
if [ ! -f "$CONFIG" ]; then
    exit 0
fi

ENABLED=$(jq -r '.enabled // false' "$CONFIG" 2>/dev/null)
if [ "$ENABLED" != "true" ]; then
    # Clean up stale flag if fallback was disabled
    rm -f "$QUOTA_FLAG"
    exit 0
fi

# Check if quota is exhausted by reading usage cache
QUOTA_EXHAUSTED=false
if [ -f "$USAGE_CACHE" ]; then
    # Check if utilization is at/near 100%
    utilization=$(jq -r '.five_hour.utilization // 0' "$USAGE_CACHE" 2>/dev/null)
    if [ -n "$utilization" ]; then
        # utilization is a decimal (0.0 to 1.0), check if >= 0.95
        is_exhausted=$(echo "$utilization" | awk '{if ($1 >= 0.95) print "yes"; else print "no"}')
        if [ "$is_exhausted" = "yes" ]; then
            QUOTA_EXHAUSTED=true
        fi
    fi
fi

# Also check for recent 429 error cache
ERROR_CACHE="$_TMPDIR/claude-usage-cache.err"
if [ -f "$ERROR_CACHE" ]; then
    http_code=$(cat "$ERROR_CACHE" 2>/dev/null)
    if [ "$http_code" = "429" ] || [ "$http_code" = "403" ]; then
        QUOTA_EXHAUSTED=true
    fi
fi

# Update fallback state in config
if $QUOTA_EXHAUSTED; then
    # Set quota exhausted flag
    echo "$(date +%s)" > "$QUOTA_FLAG"
    # Update config tracking
    jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '.quotaResetTracking.lastQuotaExhausted = $ts | .quotaResetTracking.fallbackActive = true' \
        "$CONFIG" > "${CONFIG}.tmp" 2>/dev/null && mv -f "${CONFIG}.tmp" "$CONFIG"
else
    # Clear flag if quota has reset
    rm -f "$QUOTA_FLAG"
    jq '.quotaResetTracking.fallbackActive = false' \
        "$CONFIG" > "${CONFIG}.tmp" 2>/dev/null && mv -f "${CONFIG}.tmp" "$CONFIG"
fi

exit 0