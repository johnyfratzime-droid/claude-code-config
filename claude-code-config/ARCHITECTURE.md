# Architecture Deep-Dive

## System Overview

This configuration transforms Claude Code from a single-model CLI into a **multi-tier, self-healing AI orchestration system**. The architecture has five layers:

```
Layer 1: Configuration (CLAUDE.md, settings.json)
    ↓
Layer 2: Hooks (model-router, quota-monitor, statusline)
    ↓
Layer 3: Routing (Haiku → Sonnet → Opus classification)
    ↓
Layer 4: Fallback (OpenRouter proxy when Claude quota exhausts)
    ↓
Layer 5: Memory (cross-project lessons + project-level context)
```

---

## Layer 1: Configuration

### CLAUDE.md

The **global instruction file**, auto-loaded by Claude Code on every session start. Contains:

- Memory system architecture and storage decision rules
- Core settings (model, language, shell)
- Conda environment activation patterns
- Network & proxy configuration
- Communication preferences
- Workflow rules (web search, subagent strategy, verification)
- Version changelog format
- Code review and deep reasoning trigger rules

**Key design decision:** `CLAUDE.md` is only modified by explicit user request. All runtime learning goes to `lessons.md`.

### settings.json

The **Claude Code settings file**. Key sections:

```json
{
  "model": "haiku",           // Default model (orchestrator)
  "effortLevel": "medium",    // Scale depth to complexity
  "permissions": { ... },     // Auto-allow all tools
  "hooks": { ... },           // Hook definitions (see Layer 2)
  "enabledPlugins": { ... },  // Plugin registry
  "statusLine": { ... },      // Custom status bar command
  "tui": "fullscreen",        // Full-screen TUI mode
  "skipAutoPermissionPrompt": true
}
```

**Rationale:** Haiku as default + medium effort + auto-permissions = fast, cheap, unblocked workflow. Complex tasks escalate via hooks.

---

## Layer 2: Hooks

Hooks are shell scripts that run at specific points in the Claude Code lifecycle.

### Hook Execution Flow

```
Session Start
    │
    ├─ SessionStart hook → Load lessons.md into context
    │
    ▼
User types prompt
    │
    ▼
UserPromptSubmit hook (fires before prompt reaches Claude)
    │
    ├─ model-router.sh    → Classify prompt, inject routing hint
    ├─ quota-monitor.sh   → Check quota, activate fallback if needed
    │
    ▼
Claude processes prompt (with routing hint + fallback active)
    │
    ▼
Status line renders (after every interaction)
    │
    └─ statusline.sh      → Show model, usage, context bars
```

### model-router.sh

**Fires on:** `UserPromptSubmit` (every prompt)

**What it does:**
1. Reads the incoming prompt from stdin (JSON format)
2. Extracts the prompt text and lowercases it
3. Runs regex pattern matching through a Node.js inline script:
   - **Opus patterns:** `architecture`, `security audit`, `critical fix`, `production incident`, `breaking change`, `deep analysis`, `distributed system`, `compliance`, `forensic`, `audit`, `system design`, `migration strategy`, `scalability`
   - **Sonnet patterns:** `implement`, `build`, `create feature/class/service/module`, `refactor`, `debug`, `fix bug/error/issue`, `code review`, `deploy`, `integrate`, `migrate`, `optimize`, `analyze`, `test suite`, `feature`, `database`, `api`, `auth`, `performance`, `write a function/class/test`, `what is wrong`, `how does X work`, `explain how`
   - **Default:** Haiku (everything else)
4. Checks if OpenRouter fallback is active (quota flag file exists + config enabled)
5. Outputs a `<model_routing_hint>` XML tag that Claude reads

**Output format:**
```xml
<model_routing_hint>AUTO-ROUTER: SONNET tier — implementation/debugging/analysis. Spawn Agent(model="sonnet") for the core work.</model_routing_hint>
```

**Fallback mode output:**
```xml
<model_routing_hint>AUTO-ROUTER: SONNET tier via Open Router (model="anthropic/claude-sonnet-4-20250514") — Claude quota exhausted, fallback active. Use Open Router API for this request.</model_routing_hint>
```

### quota-monitor.sh

**Fires on:** `UserPromptSubmit` (after model-router.sh)

**What it does:**
1. Reads `~/.claude/openrouter-config.json` — exits early if fallback is disabled
2. Checks `~/.claude/usage-cache.json` for 5-hour utilization:
   - Parses `.five_hour.utilization` (decimal 0.0 to 1.0)
   - If ≥ 0.95 (95%), marks quota as exhausted
3. Checks `~/.claude/usage-cache.err` for recent 429/403 HTTP errors
4. If quota is exhausted:
   - Writes timestamp to `/tmp/claude-quota-exhausted.flag`
   - Updates `openrouter-config.json` tracking: `lastQuotaExhausted` + `fallbackActive = true`
5. If quota has reset:
   - Removes the flag file
   - Sets `fallbackActive = false`

**Design note:** Non-destructive — if anything fails, it exits silently. The fallback only activates on confirmed exhaustion.

### statusline.sh

**Fires on:** Every status line render (continuous)

**What it does:**
1. Reads Claude Code's internal state from stdin (JSON)
2. Extracts: model name, cwd, context window %, git branch
3. Fetches 5-hour API usage asynchronously (non-blocking):
   - Checks cache file first (instant)
   - If stale (>60s), spawns background curl to Claude API
   - Respects negative cache (5-min cooldown on failures)
   - Loads credentials from: macOS Keychain → Linux libsecret → Windows Credential Manager → `.credentials.json`
4. Checks for OpenRouter fallback flag → shows `[OR]` indicator
5. Builds gradient progress bars:
   - Context window: green → yellow → orange → red
   - 5h usage: same gradient
   - Bars adapt to terminal width
6. Wraps segments to multi-line if terminal is narrow

**Cross-platform emoji detection:**
- macOS: checks UTF-8 locale
- Windows: checks `WT_SESSION` (Windows Terminal), `MSYSTEM` (Git Bash), `TERM_PROGRAM=vscode`
- Falls back to text labels (`M:`, `D:`, `br:`) on dumb terminals

**Terminal width probing:**
- Tries `$COLUMNS` → walks `/proc/<pid>/fd/*` for real TTY → `tput cols` → fallback 120

### openrouter-proxy.sh

**Fires on:** When `<model_routing_hint>` indicates OpenRouter fallback

**What it does:**
1. Reads the API request JSON from stdin
2. Loads API key and model mapping from `openrouter-config.json`
3. Maps Claude model names to OpenRouter slugs:
   - `haiku` → `anthropic/claude-3.5-haiku`
   - `sonnet` → `anthropic/claude-sonnet-4-20250514`
   - `opus` → `anthropic/claude-opus-4-20250514`
4. Transforms the request (replaces `.model` field)
5. POSTs to `https://openrouter.ai/api/v1/chat/completions`
6. Transforms response back to Claude-compatible format
7. Adds metadata: `_provider: "openrouter"`, `_model_used`

---

## Layer 3: Model Routing Logic

### Classification Engine

The router uses a **priority-based pattern matching** system:

```
Priority 1: OPUS (highest)
    → If any opus pattern matches, escalate to Opus

Priority 2: SONNET
    → If any sonnet pattern matches (and no opus match), escalate to Sonnet

Priority 3: HAIKU (default)
    → Everything else stays on Haiku
```

### Why Haiku as Default?

Haiku is the **orchestrator model**. The main session runs on Haiku, and only the heavy sub-agents (spawned via `Agent(model="sonnet")` or `Agent(model="opus")`) escalate. This means:

- **Session overhead stays cheap** — the main context window is on the cheapest tier
- **Escalation is targeted** — only the specific task that needs power gets it
- **Cost scales linearly** with task complexity, not exponentially

### Pattern Coverage

| Category | OPUS | SONNET |
|---|---|---|
| Architecture | ✅ `architect`, `system design`, `scalab` | |
| Security | ✅ `security audit`, `compliance` | |
| Critical | ✅ `critical bug`, `production incident`, `breaking change` | |
| Analysis | ✅ `deep analys`, `forensic`, `distributed system` | ✅ `analyz`, `how does.* work` |
| Implementation | | ✅ `implement`, `build`, `create`, `write a` |
| Debugging | | ✅ `debug`, `fix`, `what is wrong` |
| Quality | | ✅ `code review`, `refactor`, `optimiz` |
| Infrastructure | | ✅ `deploy`, `database`, `api`, `auth` |
| Testing | | ✅ `test suite`, `write a test` |

---

## Layer 4: Fallback System

### Lifecycle

```
Normal Operation
    │
    ▼
[quota-monitor detects utilization ≥ 95% OR 429 error]
    │
    ▼
Flag file created: /tmp/claude-quota-exhausted.flag
    │
    ▼
[model-router checks flag → switches to OpenRouter routing]
    │
    ▼
[statusline shows [OR] indicator]
    │
    ▼
All requests route through openrouter-proxy.sh
    │
    ▼
[quota-monitor detects quota reset]
    │
    ▼
Flag file removed → fallback deactivated → back to Claude API
```

### Credential Loading (Status Line Usage Fetch)

The status line needs Claude API credentials to fetch usage data. It tries in order:

1. **macOS Keychain:** `security find-generic-password -s "Claude Code-credentials" -w`
2. **Linux libsecret:** `secret-tool lookup service "Claude Code-credentials"`
3. **Windows Credential Manager:** PowerShell `Get-StoredCredential`
4. **Fallback:** Read `~/.claude/.credentials.json` directly

### Async Fetch Strategy

The status line **never blocks** on network requests:
- Cache TTL: 60 seconds (refreshes if stale)
- Cache max age: 600 seconds (doesn't display data older than 10 min)
- Lock file prevents concurrent fetches
- Negative cache: 300-second cooldown after failures
- Background process: `bg_fetch_usage &>/dev/null &`

---

## Layer 5: Memory System

### Two-Level Architecture

```
Global Level (~/.claude/lessons.md)
    ├── Cross-project lessons
    ├── Loaded on SessionStart via hook
    ├── Applies to ALL projects
    └── Storage decision: "Would this apply in a different project?"

Project Level (projects/<name>/memory/MEMORY.md)
    ├── Project-specific preferences
    ├── Auto-loaded by Claude Code (MEMORY.md convention)
    ├── Applies to current project only
    └── Storage decision: "Only relevant to the current project?"
```

### Lesson Format

```markdown
## YYYY-MM-DD
**Context**: Where/when this happened
**Mistake**: What went wrong
**Rule**: Concrete instruction to prevent recurrence
```

### Auto-Load Mechanism

The `SessionStart` hook in `settings.json` runs:

```bash
LESSONS_FILE="$HOME/.claude/lessons.md"
if [ -f "$LESSONS_FILE" ]; then
    echo '=== Lessons Learned (auto-loaded via SessionStart hook) ==='
    cat "$LESSONS_FILE"
    echo '=== End of Lessons ==='
    echo 'IMPORTANT: You MUST briefly confirm you have loaded these lessons at session start.'
fi
```

This injects all lessons into Claude's context before the first interaction.

### Compact Reload

After context compaction (when Claude Code truncates conversation history), the same hook fires again to re-inject lessons.

---

## Plugin System

### Official Plugins

Loaded from `@claude-plugins-official` marketplace:

| Plugin | What It Does |
|---|---|
| `superpowers` | Extended Claude capabilities |
| `code-review` | Adversarial code review |
| `code-simplifier` | Code simplification suggestions |
| `commit-commands` | Git commit workflows |
| `feature-dev` | Feature development lifecycle |
| `context7` | Extended context management |
| `github` | GitHub API integration |

### Community Plugins

Loaded from custom marketplaces (defined in `extraKnownMarketplaces`):

| Plugin | Source | What It Does |
|---|---|---|
| `claude-mem` | `github.com/thedotmack/claude-mem` | Persistent memory observer |

### Plugin Installation

Plugins install to `~/.claude/plugins/`:
- `cache/` — plugin cache data
- `data/` — plugin persistent data
- `marketplaces/` — marketplace source repos
- `installed_plugins.json` — registry of installed plugins
- `known_marketplaces.json` — marketplace definitions

---

## Token Flow Diagram

```
User types: "implement a REST API with auth"
    │
    ▼
UserPromptSubmit hook fires
    │
    ├─ model-router.sh reads stdin JSON
    │   → Node.js regex match: "implement" + "api" + "auth" = SONNET
    │   → Checks quota flag: not set
    │   → Outputs: <model_routing_hint>AUTO-ROUTER: SONNET tier...</model_routing_hint>
    │
    ├─ quota-monitor.sh reads stdin JSON
    │   → Checks usage cache: 45% utilization
    │   → No 429 errors
    │   → Exit 0 (no action)
    │
    ▼
Claude receives prompt + routing hint
    │
    ├─ Sees SONNET hint → spawns Agent(model="sonnet")
    │
    ▼
Sonnet sub-agent processes the task
    │
    ▼
Result returned to Haiku orchestrator
    │
    ▼
Haiku formats response → user sees output
    │
    ▼
Status line renders:
    M: Claude Sonnet 4 │ D: my-project │ br: main │ context [████░░░░░░░░░░░░░░] 22% 200k │ 5h [██████░░░░░░░░░░░░] 32% 2h15m
```

---

## File Dependencies

```
settings.json
    ├── references: hooks/model-router.sh
    ├── references: hooks/quota-monitor.sh
    ├── references: hooks/statusline.sh
    ├── references: plugins/*
    └── references: statusline.sh

hooks/model-router.sh
    ├── reads: openrouter-config.json
    ├── reads: /tmp/claude-quota-exhausted.flag
    └── depends: node (for regex classification)

hooks/quota-monitor.sh
    ├── reads: openrouter-config.json
    ├── reads: /tmp/claude-usage-cache.json
    ├── reads: /tmp/claude-usage-cache.err
    └── writes: /tmp/claude-quota-exhausted.flag
    └── writes: openrouter-config.json (tracking fields)

hooks/statusline.sh
    ├── reads: stdin (Claude Code state JSON)
    ├── reads: /tmp/claude-usage-cache.json
    ├── reads: /tmp/claude-usage-cache.err
    ├── reads: .credentials.json (or keychain/libsecret)
    ├── reads: openrouter-config.json
    ├── reads: /tmp/claude-quota-exhausted.flag
    └── depends: jq, curl, git, stat, date

hooks/openrouter-proxy.sh
    ├── reads: stdin (request JSON)
    ├── reads: openrouter-config.json
    └── depends: jq, curl
```
