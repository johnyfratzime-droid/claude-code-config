#!/usr/bin/env bash
# Auto-classify incoming prompts and inject model routing hints.
# Fires on every UserPromptSubmit. Injects a <model_routing_hint> tag
# when the task warrants Sonnet or Opus — main session stays on Haiku
# as orchestrator, subagents do the heavy lifting at the right tier.
#
# Open Router fallback: when Claude quota is exhausted (429), routes to
# Open Router API with equivalent model mapping (defined in openrouter-config.json).

_HOME="${USERPROFILE:-$HOME}"
CONFIG="$_HOME/.claude/openrouter-config.json"
_TMPDIR="${TMPDIR:-${TMP:-/tmp}}"
QUOTA_FLAG="$_TMPDIR/claude-quota-exhausted.flag"

INPUT=$(cat)

TIER=$(printf '%s' "$INPUT" | node -e "
var chunks = [];
process.stdin.on('data', function(c) { chunks.push(c); });
process.stdin.on('end', function() {
  var tier = 'HAIKU';
  try {
    var prompt = (JSON.parse(chunks.join('')).prompt || '').toLowerCase();
    var opusPat = [
      /architect/, /security audit/, /critical (bug|issue|fix)/,
      /production incident/, /breaking change/, /deep analys/,
      /distributed system/, /compliance/, /forensic/, / audit /,
      /system design/, /migration strateg/, /scalab/
    ];
    var sonnetPat = [
      /implement/, /\bbuild\b/, /create (feature|class|service|module)/,
      /refactor/, /debug/, /fix (bug|error|issue)/, /code review/, /deploy/,
      /integrat/, /migrat/, /optimiz/, /analyz/, /test suite/,
      /\bfeature\b/, /database/, /\bapi\b/, /auth/, /performance/,
      /write a function/, /write a class/, /write a test/,
      /what is wrong/, /how does.* work/, /explain how/
    ];
    if (opusPat.some(function(p){ return p.test(prompt); })) {
      tier = 'OPUS';
    } else if (sonnetPat.some(function(p){ return p.test(prompt); })) {
      tier = 'SONNET';
    }
  } catch(e) {}
  process.stdout.write(tier);
});
" 2>/dev/null)

TIER="${TIER:-HAIKU}"

# Check if Open Router fallback is active
FALLBACK_ACTIVE=false
if [ -f "$QUOTA_FLAG" ] && [ -f "$CONFIG" ]; then
    ENABLED=$(jq -r '.enabled // false' "$CONFIG" 2>/dev/null)
    if [ "$ENABLED" = "true" ]; then
        FALLBACK_ACTIVE=true
    fi
fi

# Map tier to Open Router model if fallback is active
if $FALLBACK_ACTIVE && [ -f "$CONFIG" ]; then
    OR_MODEL=$(jq -r --arg tier "$(echo "$TIER" | tr '[:upper:]' '[:lower:]')" '.modelMapping[$tier] // empty' "$CONFIG" 2>/dev/null)
    if [ -n "$OR_MODEL" ]; then
        printf '<model_routing_hint>AUTO-ROUTER: %s tier via Open Router (model="%s") — Claude quota exhausted, fallback active. Use Open Router API for this request.</model_routing_hint>\n' "$TIER" "$OR_MODEL"
        exit 0
    fi
fi

# Normal Claude routing (fallback not active)
if [ "$TIER" = "OPUS" ]; then
  printf '<model_routing_hint>AUTO-ROUTER: OPUS tier — architecture/security/critical decision. Spawn Agent(model="opus") for the core work.</model_routing_hint>\n'
elif [ "$TIER" = "SONNET" ]; then
  printf '<model_routing_hint>AUTO-ROUTER: SONNET tier — implementation/debugging/analysis. Spawn Agent(model="sonnet") for the core work.</model_routing_hint>\n'
fi

exit 0
