<p align="center">
  <h1 align="center">🧠 Claude Code — Production Config</h1>
  <p align="center">
    <b>Auto model routing · OpenRouter fallback · Real-time status line · Memory system</b>
    <br/>
    <em>Drop-in configuration that turns Claude Code into a self-healing, cost-optimized AI orchestrator.</em>
  </p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/model-Haiku%20%7C%20Sonnet%20%7C%20Opus-blue" alt="Models"/>
  <img src="https://img.shields.io/badge/fallback-OpenRouter-green" alt="Fallback"/>
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey" alt="Platform"/>
  <img src="https://img.shields.io/badge/cost-%7E15x%20cheaper-orange" alt="Cost"/>
  <img src="https://img.shields.io/badge/license-MIT-yellow" alt="License"/>
</p>

---

## What This Does

**Problem:** Claude Code ships as a single-model CLI. Default to Opus? Expensive. Default to Haiku? Can't handle complex tasks. No fallback when quota exhausts. No visibility into usage.

**Solution:** This configuration adds **4 layers** on top of vanilla Claude Code:

```
┌─────────────────────────────────────────────────────────┐
│  1. AUTO MODEL ROUTER                                   │
│     Every prompt classified → Haiku / Sonnet / Opus     │
│     Main session stays cheap, only heavy tasks escalate │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  2. OPENROUTER FALLBACK                                 │
│     Claude quota hits 95% → seamless switch to          │
│     OpenRouter API. Zero downtime. Same models.          │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  3. GRADIENT STATUS LINE                                │
│     Real-time bars: model · context · 5h usage · git    │
│     Green → yellow → red gradient, adapts to width      │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  4. MEMORY SYSTEM                                       │
│     Global lessons auto-loaded every session            │
│     Cross-project corrections + project-level context   │
└─────────────────────────────────────────────────────────┘
```

## What You Get

| Before (Vanilla Claude) | After (This Config) |
|---|---|
| Single model for everything | 3-tier routing: Haiku → Sonnet → Opus |
| Quota exhausted → blocked | Auto-fallback to OpenRouter |
| No usage visibility | Gradient status bar with real-time metrics |
| Forgets lessons between sessions | Global lessons auto-loaded every session |
| Default: expensive Opus | Default: cheap Haiku (~15x cheaper) |
| 27 plugins enabled by default | 7 curated plugins, opt-in heavy features |

---

## How It Works — In 60 Seconds

```
You type: "implement a REST API with auth"
    │
    ▼ model-router.sh scans prompt
    "implement" + "api" + "auth" → SONNET tier
    │
    ▼ Claude spawns sub-agent
    Agent(model="sonnet") processes the task
    Main session stays on Haiku (cheap orchestrator)
    │
    ▼ quota-monitor.sh checks utilization
    45% → all good, keep going
    95%+ → flag set → OpenRouter proxy activated
    │
    ▼ statusline renders
    🧠 Sonnet 4 │ 📂 my-api │ ⎇ main │ context [████░░░░░░░░░░░░░░] 22% │ 5h [██████░░░░░░░░░░░░] 45% resets in 2h15m
```

---

## At a Glance

| Feature | Description |
|---|---|
| **Auto Model Router** | Classifies every prompt into Haiku / Sonnet / Opus tiers automatically |
| **OpenRouter Fallback** | Seamlessly switches to OpenRouter API when Claude quota hits ≥ 95% |
| **Gradient Status Line** | Real-time model, context window, 5h usage bars with emoji/glyph support |
| **Quota Monitor** | Detects 429 errors, tracks utilization, manages fallback lifecycle |
| **Memory System** | Cross-project lessons + project-level preferences, auto-loaded via hooks |
| **Plugin Ecosystem** | Official + community plugins (code-review, mem, github, feature-dev) |
| **Cross-Platform** | Works on macOS, Linux, Windows (Git Bash / Windows Terminal) |
| **Token-Efficient** | Default Haiku + medium effort + opt-in deep-reason = ~15x cheaper default |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        CLAUDE CODE SESSION                       │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    ┌──────────────┐    ┌───────────────────┐   │
│  │ SessionStart│───▶│ Load lessons │    │ settings.json     │   │
│  │   hook      │    │ .md (global) │    │  • model: haiku   │   │
│  └─────────────┘    └──────────────┘    │  • permissions    │   │
│                                          │  • hooks          │   │
│  ┌─────────────┐    ┌──────────────┐    │  • plugins        │   │
│  │UserPrompt   │───▶│ model-router │───▶│  • statusLine     │   │
│  │  Submit     │    │   .sh        │    └───────────────────┘   │
│  └─────────────┘    └──────┬───────┘                            │
│                            │                                    │
│              ┌─────────────┼─────────────┐                      │
│              ▼             ▼             ▼                      │
│        ┌─────────┐  ┌──────────┐  ┌────────────┐               │
│        │ HAIKU   │  │ SONNET   │  │ OPUS       │               │
│        │ (cheap) │  │ (mid)    │  │ (critical) │               │
│        └────┬────┘  └────┬─────┘  └─────┬──────┘               │
│             │            │              │                       │
│             └────────────┼──────────────┘                       │
│                          ▼                                      │
│              ┌───────────────────────┐                          │
│              │  quota-monitor.sh     │                          │
│              │  • checks 5h usage    │                          │
│              │  • detects 429 errors │                          │
│              │  • sets fallback flag │                          │
│              └───────────┬───────────┘                          │
│                          │                                      │
│               quota ≥ 95%?                                      │
│              ┌──────┴──────┐                                    │
│              ▼             ▼                                    │
│         ┌────────┐   ┌────────────┐                             │
│         │ Claude │   │ OpenRouter │                             │
│         │  API   │   │  Proxy     │                             │
│         └────────┘   └────────────┘                             │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## How It Works

### 1. Model Routing (On Every Prompt)

Every time you submit a prompt, `model-router.sh` classifies it into one of three tiers:

| Tier | Trigger Patterns | Cost Level |
|---|---|---|
| **Haiku** | Everything else (default) | $ |
| **Sonnet** | `implement`, `build`, `refactor`, `debug`, `fix`, `code review`, `database`, `api`, `auth` | $$ |
| **Opus** | `architecture`, `security audit`, `critical fix`, `production incident`, `system design`, `compliance` | $$$$ |

The router injects a `<model_routing_hint>` tag that tells Claude which model tier to spawn for the task. **The main session stays on Haiku** as an orchestrator — only heavy sub-agents escalate.

### 2. Quota Monitoring

`quota-monitor.sh` runs after the router and:
- Reads `~/.claude/openrouter-config.json` to check if fallback is enabled
- Checks `~/.claude/usage-cache.json` for utilization ≥ 95%
- Checks for cached 429/403 HTTP errors
- Sets a flag file that activates the OpenRouter proxy

### 3. OpenRouter Fallback

When Claude quota exhausts:
- The status line shows `[OR]` (amber warning indicator)
- All subsequent requests route through `openrouter-proxy.sh`
- Model mapping is transparent: `haiku` → `anthropic/claude-3.5-haiku`, etc.
- When quota resets, fallback automatically deactivates

### 4. Status Line

A rich, gradient status bar showing:
- 🧠 Model name (🔀 OR when fallback active)
- 📂 Current directory
- 🐍 Conda/venv environment
- ⎇ Git branch
- Context window usage bar (green → red gradient)
- 5-hour API usage bar with countdown to reset

### 5. Memory System

- **Global lessons** (`~/.claude/lessons.md`): Cross-project corrections, loaded on session start
- **Project memory** (`projects/<name>/memory/MEMORY.md`): Per-project preferences
- **Storage decision**: Would this apply in a different project? → Global. Only relevant here? → Project.

---

## File Structure

```
~/.claude/
├── CLAUDE.md                    # Global instructions (auto-loaded)
├── settings.json                # Core settings: model, hooks, plugins
├── openrouter-config.json       # OpenRouter fallback config
├── lessons.md                   # Cross-project lessons learned
├── .credentials.json            # OAuth tokens (never commit!)
├── hooks/
│   ├── model-router.sh          # Auto-classify prompts → model tier
│   ├── quota-monitor.sh         # Detect quota exhaustion → activate fallback
│   ├── openrouter-proxy.sh      # Translate requests to OpenRouter API
│   └── statusline.sh            # Rich gradient status bar
├── plugins/
│   ├── installed_plugins.json
│   ├── known_marketplaces.json
│   └── [cache, data, marketplaces/]
└── projects/
    └── <project>/
        └── memory/
            └── MEMORY.md        # Project-level preferences
```

---

## Quick Start — One Command

### macOS / Linux (bash)

```bash
git clone https://github.com/testerul/claude-code-config.git
cd claude-code-config
chmod +x setup.sh && ./setup.sh
# Then: edit ~/.claude/openrouter-config.json with your OpenRouter key
# Then: claude
```

### Windows (PowerShell 7+)

```powershell
git clone https://github.com/testerul/claude-code-config.git
cd claude-code-config
.\setup.ps1
# Then: edit $env:USERPROFILE\.claude\openrouter-config.json with your OpenRouter key
# Then: claude
```

### Windows (Git Bash / WSL)

```bash
git clone https://github.com/testerul/claude-code-config.git
cd claude-code-config
chmod +x setup.sh && ./setup.sh
# Same as macOS/Linux — bash hooks work in Git Bash and WSL
```

That's it. Insert your API key, open Claude Code, and you're running.

### Prerequisites

| Platform | Need |
|---|---|
| **macOS / Linux** | `jq` + `bash` |
| **Windows (PowerShell)** | PowerShell 7+ (`pwsh`) + `jq.exe` |
| **Windows (Git Bash / WSL)** | `jq` + `bash` |
| **All** | [Claude Code](https://github.com/anthropics/claude-code) installed |

> No `jq`? Get it: `brew install jq` / `sudo apt install jq` / `scoop install jq`

See [INSTALL.md](./INSTALL.md) for detailed instructions.

---

## Configuration Reference

| File | Purpose |
|---|---|
| [CLAUDE.md](./CLAUDE.md) | Global instructions: memory system, workflow, communication prefs |
| [settings.json](./settings.json) | Model, permissions, hooks, plugins, UI settings |
| [openrouter-config.json](./openrouter-config.json) | OpenRouter API key, model mapping, quota tracking |
| [lessons.md](./lessons.md) | Cross-project lessons template with examples |

See [CONFIGURATION.md](./CONFIGURATION.md) for a complete reference.

---

## Token Efficiency

This configuration is designed to minimize cost:

| Setting | Default | Why |
|---|---|---|
| Model | `haiku` | Cheapest tier, orchestrates sub-agents |
| effortLevel | `medium` | Scales depth to task complexity |
| adaptive thinking | **enabled** | Skips thinking on trivial tasks |
| deep-reason | opt-in only | 3-10x token cost, only when needed |
| adversarial-review | opt-in only | Code review on demand, not automatic |
| plugins | 7 minimal | Only what you actively use |

**Result**: ~15-25x cheaper for routine work vs. default Opus + xhigh configuration.

---

## Plugin Ecosystem

Enabled plugins (via `settings.json`):

| Plugin | Source | Purpose |
|---|---|---|
| `superpowers` | Official | Extended Claude capabilities |
| `code-review` | Official | Automated code review |
| `code-simplifier` | Official | Code simplification |
| `commit-commands` | Official | Git commit helpers |
| `feature-dev` | Official | Feature development workflows |
| `context7` | Official | Extended context management |
| `claude-mem` | Community | Persistent memory system |
| `github` | Official | GitHub integration |

---

## Cross-Platform Support

| Feature | macOS / Linux (bash) | Windows (pwsh) | Windows (Git Bash / WSL) |
|---|---|---|---|
| Model Router | ✅ model-router.sh | ✅ model-router.ps1 | ✅ model-router.sh |
| Quota Monitor | ✅ quota-monitor.sh | ✅ quota-monitor.ps1 | ✅ quota-monitor.sh |
| Status Line | ✅ statusline.sh | ✅ statusline.ps1 | ✅ statusline.sh |
| OpenRouter Proxy | ✅ openrouter-proxy.sh | ✅ openrouter-proxy.ps1 | ✅ openrouter-proxy.sh |
| Setup Script | ✅ setup.sh | ✅ setup.ps1 | ✅ setup.sh |
| Credential Loading | Keychain / libsecret | Win Cred Manager | Keychain / libsecret |

---

## Related Projects

| Repo | Description |
|---|---|
| [**qwen-code-config**](https://github.com/testerul/qwen-code-config) | Same philosophy for Qwen Code: multi-provider (DashScope + OpenRouter), 3-tier strategy, PowerShell + bash quota monitor |

---

## License

[MIT License](./LICENSE)

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md)

---

*Built by [@testerul](https://github.com/testerul) — real usage, real production, real fallbacks.*
