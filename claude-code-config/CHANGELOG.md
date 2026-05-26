# Changelog

## [1.0.0] - 2026-05-26

### Features
- **Auto Model Router**: Classifies every prompt into Haiku / Sonnet / Opus tiers via regex pattern matching
- **OpenRouter Fallback**: Seamless failover when Claude quota exhausts (≥ 95% utilization or 429 errors)
- **Gradient Status Line**: Real-time display of model, directory, conda env, git branch, context window, and 5h usage bars
- **Quota Monitor**: Detects quota exhaustion, manages fallback lifecycle, auto-resets when quota replenishes
- **Memory System**: Two-level persistence — global lessons (`lessons.md`) + project-level `MEMORY.md`
- **Cross-Platform**: macOS, Linux, Windows (PowerShell 7+ / Git Bash / WSL) — full bash + PowerShell parity
- **Token Efficiency**: Default Haiku + medium effort + opt-in deep-reason = ~15x cheaper than default Opus config

### Components
| File | Purpose |
|---|---|
| `settings.json` | Unix/macOS config: bash hook paths |
| `settings.windows.json` | Windows config: PowerShell hook paths |
| `CLAUDE.md` | Global instructions: memory, workflow, communication prefs |
| `hooks/model-router.sh` / `.ps1` | Prompt classification → model tier (bash + PowerShell) |
| `hooks/quota-monitor.sh` / `.ps1` | Quota detection → fallback activation (bash + PowerShell) |
| `hooks/statusline.sh` / `.ps1` | Gradient status bar (bash + PowerShell) |
| `hooks/openrouter-proxy.sh` / `.ps1` | Request translation to OpenRouter (bash + PowerShell) |
| `setup.sh` | One-command installer for macOS/Linux/Git Bash |
| `setup.ps1` | One-command installer for Windows PowerShell 7+ |
| `templates/openrouter-config.example.json` | OpenRouter API key template |
| `lessons.md` | Cross-project lessons template |

### Design Rationale
- **Haiku as orchestrator**: Main session stays cheap, only sub-agents escalate
- **Regex over ML classification**: Fast, deterministic, editable by users
- **Async status line**: Never blocks on network — cache-first with background refresh
- **Opt-in heavy features**: deep-reason and adversarial-review cost 3-10x, only trigger when explicitly needed
- **Dual-language hooks**: bash for Unix/macOS/Git Bash, PowerShell for Windows native — same behavior, no platform lock-in

### Notes & Caveats
- Requires `jq` installed (not bundled) — `brew install jq` / `sudo apt install jq` / `scoop install jq`
- OpenRouter API key needed for fallback (get free key at openrouter.ai)
- `.credentials.json` is managed by `claude auth login` — never commit to git
- Windows PowerShell 7+ (`pwsh`) required for `.ps1` hooks — Windows PowerShell 5.1 is not supported
- Pattern matching in model-router is case-insensitive but requires exact word matches for some patterns
