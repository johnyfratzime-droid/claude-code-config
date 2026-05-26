# Installation Guide

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Install](#quick-install)
3. [Manual Setup](#manual-setup)
4. [Configure OpenRouter Fallback](#configure-openrouter-fallback)
5. [Verify Everything Works](#verify-everything-works)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required

| Tool | Minimum Version | How to Check |
|---|---|---|
| Claude Code | v2.0+ | `claude --version` |
| jq | v1.6+ | `jq --version` |
| Bash | v4.0+ (v3.2 OK on macOS) | `bash --version` |

### Platform-Specific

**macOS:**
```bash
brew install jq  # if not installed
```

**Linux (Debian/Ubuntu):**
```bash
sudo apt install jq curl
```

**Linux (Arch):**
```bash
sudo pacman -S jq curl
```

**Windows (PowerShell):**
- Install [PowerShell 7+](https://github.com/PowerShell/PowerShell) (`pwsh`)
- Install [jq](https://github.com/jqlang/jq/releases) via `scoop install jq` or `choco install jq`

**Windows (Git Bash):**
- Install [Git for Windows](https://git-scm.com/download/win) (includes Git Bash)
- Download [jq.exe](https://github.com/jqlang/jq/releases) and place in `~/.claude/bin/`
- Or use Windows Terminal + Git Bash for best emoji/Unicode support

### Claude Code Access

You need an active Claude Code subscription:
- **Claude Pro** — 5-hour quota, then fallback to OpenRouter
- **Claude Max** — higher quota, fallback still recommended for heavy usage
- **OpenRouter API key only** — works as primary provider (no Claude subscription needed)

---

## Quick Install

### macOS / Linux (bash)

```bash
# Clone the repository
git clone https://github.com/<your-username>/claude-code-config.git
cd claude-code-config

# Run the setup script
chmod +x setup.sh && ./setup.sh
```

### Windows (PowerShell 7+)

```powershell
# Clone the repository
git clone https://github.com/<your-username>/claude-code-config.git
cd claude-code-config

# Run the setup script
.\setup.ps1
```

### Windows (Git Bash)

```bash
# Same as macOS/Linux — Git Bash works with setup.sh
git clone https://github.com/<your-username>/claude-code-config.git
cd claude-code-config
chmod +x setup.sh && ./setup.sh
```

> **⚠️ Warning:** The setup script will **overwrite** your existing `~/.claude/settings.json`, `~/.claude/CLAUDE.md`, and `~/.claude/hooks/` directory. Back up first if you have existing configuration.

---

## Manual Setup

### Step 1: Back Up Existing Config

```bash
mkdir -p ~/.claude/backup-$(date +%Y%m%d)
cp ~/.claude/settings.json ~/.claude/backup-$(date +%Y%m%d)/ 2>/dev/null
cp ~/.claude/CLAUDE.md ~/.claude/backup-$(date +%Y%m%d)/ 2>/dev/null
cp -r ~/.claude/hooks/ ~/.claude/backup-$(date +%Y%m%d)/hooks/ 2>/dev/null
```

### Step 2: Copy Configuration Files

```bash
# Core settings
cp settings.json ~/.claude/settings.json

# Global instructions
cp CLAUDE.md ~/.claude/CLAUDE.md

# Lessons template (only if you don't have one)
[ -f ~/.claude/lessons.md ] || cp lessons.md ~/.claude/lessons.md

# OpenRouter config (template — edit with your key)
cp templates/openrouter-config.example.json ~/.claude/openrouter-config.json
```

### Step 3: Install Hooks

```bash
# Create hooks directory if it doesn't exist
mkdir -p ~/.claude/hooks

# Copy all hooks
cp hooks/model-router.sh ~/.claude/hooks/
cp hooks/quota-monitor.sh ~/.claude/hooks/
cp hooks/openrouter-proxy.sh ~/.claude/hooks/
cp hooks/statusline.sh ~/.claude/hooks/

# Make them executable
chmod +x ~/.claude/hooks/*.sh
```

### Step 4: Configure Hooks in settings.json

The `settings.json` already includes the hook definitions. Verify they point to the correct path:

```bash
cat ~/.claude/settings.json | jq '.hooks'
```

Expected output:
```json
{
  "UserPromptSubmit": [...],
  "SessionStart": [...]
}
```

### Step 5: Set Up Plugins

Plugins are configured in `settings.json` under `enabledPlugins`. To install community plugins:

```bash
# Example: claude-mem plugin
git clone https://github.com/thedotmack/claude-mem.git \
  ~/.claude/plugins/marketplaces/thedotmack/claude-mem
```

---

## Configure OpenRouter Fallback

### Get an OpenRouter API Key

1. Go to [openrouter.ai](https://openrouter.ai)
2. Sign up / log in
3. Navigate to **Keys** → **Create Key**
4. Copy the key (starts with `sk-or-v1-`)

### Edit the Config

```bash
nano ~/.claude/openrouter-config.json
```

Replace the placeholder:

```json
{
  "enabled": true,
  "apiKey": "sk-or-v1-YOUR-ACTUAL-KEY-HERE",
  "modelMapping": {
    "haiku": "anthropic/claude-3.5-haiku",
    "sonnet": "anthropic/claude-sonnet-4-20250514",
    "opus": "anthropic/claude-opus-4-20250514"
  },
  "quotaResetTracking": {
    "lastQuotaExhausted": null,
    "fallbackActive": false
  }
}
```

### Disable Fallback (Optional)

If you don't want OpenRouter fallback:

```json
{
  "enabled": false,
  ...
}
```

---

## Verify Everything Works

### 1. Check jq is Available

```bash
jq --version
# Expected: jq-1.6 or jq-1.7
```

### 2. Check Hooks are Executable

```bash
ls -la ~/.claude/hooks/*.sh
# Expected: -rwxr-xr-x for each file
```

### 3. Test Model Router

```bash
echo '{"prompt": "implement a REST API with authentication"}' | bash ~/.claude/hooks/model-router.sh
# Expected: <model_routing_hint>AUTO-ROUTER: SONNET tier ...
```

### 4. Test Quota Monitor

```bash
bash ~/.claude/hooks/quota-monitor.sh
# Expected: no output, exit 0 (unless quota is actually exhausted)
```

### 5. Test Status Line

```bash
echo '{"model": {"display_name": "Claude Sonnet 4"}, "cwd": "'$PWD'", "context_window": {"used_percentage": 35, "context_window_size": 200000}}' | bash ~/.claude/hooks/statusline.sh
# Expected: formatted status line with bars
```

### 6. Start Claude Code

```bash
claude
```

You should see the gradient status line at the top of the interface.

---

## Troubleshooting

### `jq: command not found`

**macOS:** `brew install jq`
**Linux:** `sudo apt install jq` or `sudo pacman -S jq`
**Windows:** Download `jq.exe` from [GitHub Releases](https://github.com/jqlang/jq/releases) and place in `~/.claude/bin/` or `%PATH%`

### Status line shows `Claude (jq not found - run installer or install jq)`

The hooks script tries to find `jq` in `~/.claude/bin/` on Windows. Make sure:
- `jq.exe` exists at `C:\Users\<you>\.claude\bin\jq.exe`
- OR `jq` is in your system PATH

### OpenRouter fallback not activating

1. Check `enabled` is `true` in `openrouter-config.json`
2. Check API key is correct (starts with `sk-or-v1-`)
3. Check quota monitoring: `cat /tmp/claude-usage-cache.json` (macOS/Linux) or `cat %TMP%\claude-usage-cache.json` (Windows)
4. Check for 429 errors: `cat /tmp/claude-usage-cache.err`

### Model router always returns HAIKU

The router uses regex pattern matching. If your prompt doesn't match SONNET or OPUS patterns, it defaults to HAIKU. This is **by design** — Haiku is the orchestrator. Only complex tasks trigger escalation.

### Status line is garbled / missing colors

- Ensure your terminal supports ANSI colors (Windows Terminal, iTerm2, GNOME Terminal all do)
- Disable emoji mode if your terminal doesn't support Unicode: the script auto-detects but you can force it by unsetting `WT_SESSION` and `MSYSTEM`

### Claude Code doesn't load lessons.md

Lessons are loaded via the `SessionStart` hook. Verify:
```bash
cat ~/.claude/settings.json | jq '.hooks.SessionStart'
```
Should show the `lessons.md` loading command.

### Permission denied on hooks

```bash
chmod +x ~/.claude/hooks/*.sh
```

---

## Next Steps

- Read [ARCHITECTURE.md](./ARCHITECTURE.md) for a deep-dive into how each component works
- Read [CONFIGURATION.md](./CONFIGURATION.md) for a complete reference of every setting
- Customize `CLAUDE.md` to add your own global instructions
- Add your own model routing patterns in `model-router.sh`
