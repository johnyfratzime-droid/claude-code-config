# Configuration Reference

Complete reference for every configuration file, setting, and hook parameter.

---

## settings.json

The main Claude Code configuration file. Located at `~/.claude/settings.json`.

### Top-Level Fields

| Field | Type | Default | Description |
|---|---|---|---|
| `model` | string | `"haiku"` | Default model for the main session |
| `effortLevel` | string | `"medium"` | Thinking effort: `low`, `medium`, `high`, `xhigh` |
| `tui` | string | `"fullscreen"` | TUI mode: `default`, `fullscreen` |
| `skipAutoPermissionPrompt` | boolean | `true` | Skip permission confirmation prompts |

### env

Environment variables passed to Claude Code subprocesses.

| Variable | Value | Purpose |
|---|---|---|
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `"1"` | Enable agent teams feature |
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS` | `"200000"` | Max context window size (tokens) |

### permissions

Controls tool access and permission mode.

```json
"permissions": {
  "allow": ["Bash(*)", "Read(*)", "Write(*)", "Edit(*)", "Glob(*)", "Grep(*)", "WebFetch(*)", "WebSearch(*)", "NotebookEdit(*)", "Task(*)", "mcp__*", "Read(**/*)", "Edit(**/*)", "Write(**/*)"],
  "defaultMode": "auto"
}
```

**Permission patterns:**
- `Bash(*)` — allow any bash command
- `Read(*)` / `Write(*)` / `Edit(*)` — allow file operations
- `Glob(*)` / `Grep(*)` — allow file search
- `WebFetch(*)` / `WebSearch(*)` — allow web access
- `Task(*)` — allow sub-agent spawning
- `mcp__*` — allow all MCP server tools
- `Read(**/*)` — recursive read access
- `Edit(**/*)` / `Write(**/*)` — recursive write access

**defaultMode:** `"auto"` means Claude doesn't ask for permission before each action.

### hooks

Shell scripts that run at lifecycle events.

#### UserPromptSubmit

Fires every time the user submits a prompt.

```json
"UserPromptSubmit": [
  {
    "matcher": "*",
    "hooks": [
      {
        "type": "command",
        "command": "bash ${USERPROFILE:-$HOME}/.claude/hooks/model-router.sh",
        "timeout": 5
      },
      {
        "type": "command",
        "command": "bash ${USERPROFILE:-$HOME}/.claude/hooks/quota-monitor.sh",
        "timeout": 5
      }
    ]
  }
]
```

| Field | Purpose |
|---|---|
| `matcher` | Regex pattern to match against the prompt. `*` = all prompts |
| `hooks[].type` | Hook type: `"command"` (shell script) |
| `hooks[].command` | Shell command to execute |
| `hooks[].timeout` | Max execution time in seconds |

**`${USERPROFILE:-$HOME}`** — cross-platform home directory resolution. On Windows, `$USERPROFILE` is set; on macOS/Linux, `$HOME` is used.

#### SessionStart

Fires when a new session begins (and after context compaction).

```json
"SessionStart": [
  {
    "matcher": "startup",
    "hooks": [
      {
        "type": "command",
        "command": "LESSONS_FILE=\"${USERPROFILE:-$HOME}/.claude/lessons.md\"; if [ -f \"$LESSONS_FILE\" ]; then echo '=== Lessons Learned ==='; cat \"$LESSONS_FILE\"; echo '=== End of Lessons ==='; fi",
        "statusMessage": "Loading lessons..."
      }
    ]
  },
  {
    "matcher": "compact",
    "hooks": [
      {
        "type": "command",
        "command": "...same as above...",
        "statusMessage": "Reloading lessons after compaction..."
      }
    ]
  }
]
```

| Matcher | When it fires |
|---|---|
| `startup` | New session begins |
| `compact` | After context compaction (history truncation) |

### statusLine

Custom command that renders the status bar.

```json
"statusLine": {
  "type": "command",
  "command": "bash ${USERPROFILE:-$HOME}/.claude/hooks/statusline.sh"
}
```

Claude Code pipes its internal state as JSON to stdin of this command. The command outputs a formatted string that appears at the top of the TUI.

### enabledPlugins

Registry of enabled plugins.

```json
"enabledPlugins": {
  "superpowers@claude-plugins-official": true,
  "code-review@claude-plugins-official": true,
  "code-simplifier@claude-plugins-official": true,
  "commit-commands@claude-plugins-official": true,
  "feature-dev@claude-plugins-official": true,
  "context7@claude-plugins-official": true,
  "claude-mem@thedotmack": true,
  "github@claude-plugins-official": true
}
```

Format: `plugin-name@marketplace-id`

### extraKnownMarketplaces

Custom plugin marketplaces.

```json
"extraKnownMarketplaces": {
  "thedotmack": {
    "source": {
      "source": "git",
      "url": "https://github.com/thedotmack/claude-mem.git"
    }
  }
}
```

### Changing the Default Model

To change the default model:

```json
"model": "sonnet"   // or "opus"
```

**Trade-offs:**
- `haiku` — fastest, cheapest, best for orchestration
- `sonnet` — balanced, good for general development
- `opus` — most capable, slowest, most expensive

---

## openrouter-config.json

OpenRouter fallback configuration. Located at `~/.claude/openrouter-config.json`.

### Fields

| Field | Type | Description |
|---|---|---|
| `enabled` | boolean | Enable/disable OpenRouter fallback |
| `apiKey` | string | Your OpenRouter API key (starts with `sk-or-v1-`) |
| `modelMapping` | object | Maps short names to OpenRouter model slugs |
| `quotaResetTracking` | object | Internal tracking state (auto-updated) |

### modelMapping

Maps the short model names used in routing to OpenRouter's model slug format.

```json
"modelMapping": {
  "haiku": "anthropic/claude-3.5-haiku",
  "sonnet": "anthropic/claude-sonnet-4-20250514",
  "opus": "anthropic/claude-opus-4-20250514"
}
```

**Available OpenRouter models** (partial list):
- `anthropic/claude-3.5-haiku`
- `anthropic/claude-sonnet-4-20250514`
- `anthropic/claude-opus-4-20250514`
- `openai/gpt-4o`
- `google/gemini-2.0-flash`
- `meta-llama/llama-3.3-70b-instruct`

You can add any model supported by OpenRouter.

### quotaResetTracking

Auto-managed by `quota-monitor.sh`. Do not edit manually.

```json
"quotaResetTracking": {
  "lastQuotaExhausted": null,
  "fallbackActive": false
}
```

| Field | Description |
|---|---|
| `lastQuotaExhausted` | ISO timestamp of last quota exhaustion |
| `fallbackActive` | Whether OpenRouter fallback is currently active |

---

## CLAUDE.md

Global instructions for Claude Code. Located at `~/.claude/CLAUDE.md`.

This file is **auto-loaded** by Claude Code at the start of every session. It's a markdown file that tells Claude how to behave.

### Sections

#### Memory System Architecture

Defines the two-level memory system:
- Global: `~/.claude/lessons.md`
- Project: `~/.claude/projects/<name>/memory/MEMORY.md`

Storage decision rule:
> Would this apply in a different project? → Global. Only relevant to the current project? → Project.

#### Core Settings

```
- Extended thinking: ultrathink
- Language: respond in the user's preferred language
- Shell: Zsh on macOS/Linux; Bash (Git Bash) on Windows
```

#### Conda Environment

Instructions for activating conda before running Python:

```bash
source $HOME/anaconda3/etc/profile.d/conda.sh && conda activate <env_name>
# Or: $HOME/anaconda3/envs/<env_name>/bin/python script.py
```

#### Network & Proxy

Proxy via SSH reverse tunnel:
```bash
ssh -R <remote_port>:127.0.0.1:<local_port>
```

Rule: Do not modify `.bashrc`, `.profile`, or VSCode config unless explicitly asked.

#### Communication Preferences

- When user says a cause is **not** the problem → immediately pivot
- Prefer writing code over repeated questions
- Token efficiency: direct and concise, no filler

#### Workflow Rules

- **Web search:** Determine current date first (system command → web time API fallback)
- **Non-trivial tasks (3+ steps):** Enter Plan Mode
- **Subagent strategy:** One task per subagent, keep main context clean
- **Verify before marking done:** Run tests, check logs
- **Fix bugs directly:** Don't ask for repeated confirmation

#### Version Changelog

Format for tracking version-level changes:

```markdown
## [version] - YYYY-MM-DD
### Features
- What was changed
### Design Rationale
- Why it was done this way
### Notes & Caveats
- Edge cases, compatibility concerns
```

#### Code Review

Invokes `adversarial-review` skill **opt-in only** (not auto-triggered).

#### Deep Reasoning

Invokes `deep-reason` skill **opt-in only** (not auto-triggered, 3-10x token cost).

---

## lessons.md

Cross-project lessons learned. Located at `~/.claude/lessons.md`.

### Format

```markdown
## YYYY-MM-DD
**Context**: Where/when this happened
**Mistake**: What went wrong
**Rule**: Concrete instruction to prevent recurrence
```

### Example

```markdown
## 2026-05-24
**Context**: Token optimization audit — user wanted Claude to match Qwen's efficiency.
**Mistake**: Default model was Opus (most expensive), effortLevel was xhigh, adaptive thinking was disabled, 27 plugins enabled, deep-reason and adversarial-review auto-triggered on every task. Combined cost was ~15-25x what it needed to be for routine work.
**Rule**:
- Default model: Haiku. Escalate to Sonnet for multi-step work, Opus only for critical reasoning.
- effortLevel: medium. Let Claude scale depth to task complexity.
- Never set CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING — let Claude skip thinking on trivial tasks.
- deep-reason and adversarial-review are opt-in only, not auto-triggered.
- Keep plugins minimal — only enable what you actively use.
- Agents are opt-in, not automatic.
```

### Template

The file includes a commented-out template with examples. New installations ship with only the header and template — lessons accumulate during actual usage.

---

## .credentials.json

OAuth credentials for Claude API. Located at `~/.claude/.credentials.json`.

**⚠️ NEVER COMMIT THIS FILE TO GIT.**

### Structure

```json
{
  "claudeAiOauth": {
    "accessToken": "sk-ant-oat01-...",
    "refreshToken": "sk-ant-ort01-...",
    "expiresAt": 1779801909228,
    "scopes": ["user:file_upload", "user:inference", "user:mcp_servers", "user:profile", "user:sessions:claude_code"],
    "subscriptionType": "pro",
    "rateLimitTier": "default_claude_ai"
  }
}
```

### Managed By

This file is managed by `claude auth login` / `claude auth logout`. Do not edit manually.

### Used By

- `statusline.sh` — fetches 5-hour usage data from Claude API
- Fallback credential source if keychain/libsecret/credential manager fail

---

## Hook Files

### hooks/model-router.sh

**Input:** JSON from stdin (Claude Code prompt state)
**Output:** `<model_routing_hint>` XML tag to stdout

**Dependencies:** `node` (for inline regex classification), `jq`, `bash`

**Configurable patterns:** Edit the `opusPat` and `sonnetPat` arrays in the Node.js inline script.

### hooks/quota-monitor.sh

**Input:** None (reads cache files directly)
**Output:** None (side effects: creates/removes flag file, updates config)

**Dependencies:** `jq`, `awk`, `bash`

**Thresholds:**
- Utilization ≥ 95% → quota exhausted
- HTTP 429/403 → quota exhausted

**Files it touches:**
- `/tmp/claude-quota-exhausted.flag` — creates or removes
- `~/.claude/openrouter-config.json` — updates tracking fields

### hooks/statusline.sh

**Input:** JSON from stdin (Claude Code internal state)
**Output:** Formatted status line string to stdout

**Dependencies:** `jq`, `curl`, `git`, `stat`, `date`, `bash`

**Configurable:**
- `BAR_W=20` — default bar width in characters
- `CACHE_TTL=60` — cache refresh interval (seconds)
- `CACHE_MAX_AGE=600` — max age before display stops (seconds)
- `bar_colors` — array of ANSI color codes for gradient

### hooks/openrouter-proxy.sh

**Input:** API request JSON from stdin
**Output:** API response JSON to stdout

**Dependencies:** `jq`, `curl`, `bash`

**Endpoint:** `https://openrouter.ai/api/v1/chat/completions`

---

## Environment Variables

| Variable | Purpose | Default |
|---|---|---|
| `USERPROFILE` | Windows home directory | (Windows only) |
| `HOME` | Unix home directory | `/home/user` or `/Users/user` |
| `TMPDIR` / `TMP` | Temp directory for cache/flag files | `/tmp` |
| `CONDA_DEFAULT_ENV` | Active conda environment name | (when conda active) |
| `VIRTUAL_ENV` | Active Python venv path | (when venv active) |
| `WT_SESSION` | Windows Terminal session ID | (Windows Terminal only) |
| `MSYSTEM` | Git Bash system type | (Git Bash only) |
| `TERM_PROGRAM` | Terminal emulator | `vscode`, `iTerm.app`, etc. |
| `LANG` | Locale (UTF-8 detection) | `en_US.UTF-8`, etc. |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Enable agent teams | `"1"` |
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS` | Context window limit | `"200000"` |

---

## File Paths Summary

| File | Location | Editable? | Committed? |
|---|---|---|---|
| `settings.json` | `~/.claude/settings.json` | ✅ | ✅ (template) |
| `openrouter-config.json` | `~/.claude/openrouter-config.json` | ✅ | ✅ (template, no key) |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | ✅ | ✅ |
| `lessons.md` | `~/.claude/lessons.md` | ✅ | ✅ (template) |
| `.credentials.json` | `~/.claude/.credentials.json` | ❌ (managed by CLI) | ❌ **NEVER** |
| `hooks/model-router.sh` | `~/.claude/hooks/model-router.sh` | ✅ | ✅ |
| `hooks/quota-monitor.sh` | `~/.claude/hooks/quota-monitor.sh` | ✅ | ✅ |
| `hooks/statusline.sh` | `~/.claude/hooks/statusline.sh` | ✅ | ✅ |
| `hooks/openrouter-proxy.sh` | `~/.claude/hooks/openrouter-proxy.sh` | ✅ | ✅ |
| `claude-quota-exhausted.flag` | `/tmp/claude-quota-exhausted.flag` | ❌ (auto) | ❌ |
| `claude-usage-cache.json` | `/tmp/claude-usage-cache.json` | ❌ (auto) | ❌ |
