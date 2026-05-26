#!/usr/bin/env bash
# Claude Code Config Installer — macOS / Linux
# Installs this config into ~/.claude/
# WARNING: Overwrites existing settings.json, CLAUDE.md, and hooks/
# Backs up existing config to ~/.claude/backup-YYYYMMDD/

set -e

_HOME="${USERPROFILE:-$HOME}"
CLAUDE_DIR="$_HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backup-$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "=== Claude Code Config Installer ==="
echo ""

# Check prerequisites
echo "→ Checking prerequisites..."

if ! command -v jq &>/dev/null; then
    echo "  ✗ jq not found — install it first:"
    echo "    macOS: brew install jq"
    echo "    Linux: sudo apt install jq  OR  sudo pacman -S jq"
    exit 1
fi
echo "  ✓ jq $(jq --version)"

if ! command -v bash &>/dev/null; then
    echo "  ✗ bash not found"
    exit 1
fi
echo "  ✓ bash $(bash --version | head -1)"

if ! command -v curl &>/dev/null; then
    echo "  ✗ curl not found"
    exit 1
fi
echo "  ✓ curl $(curl --version | head -1)"

# Check Claude Code
if command -v claude &>/dev/null; then
    echo "  ✓ claude $(claude --version 2>/dev/null || echo 'installed')"
else
    echo "  ⚠ claude command not found — install Claude Code first"
    echo "    https://github.com/anthropics/claude-code"
fi

echo ""

# Backup existing config
if [ -d "$CLAUDE_DIR" ]; then
    echo "→ Backing up existing config to $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    [ -f "$CLAUDE_DIR/settings.json" ] && cp "$CLAUDE_DIR/settings.json" "$BACKUP_DIR/" && echo "  ✓ settings.json"
    [ -f "$CLAUDE_DIR/CLAUDE.md" ] && cp "$CLAUDE_DIR/CLAUDE.md" "$BACKUP_DIR/" && echo "  ✓ CLAUDE.md"
    [ -f "$CLAUDE_DIR/lessons.md" ] && cp "$CLAUDE_DIR/lessons.md" "$BACKUP_DIR/" && echo "  ✓ lessons.md"
    [ -f "$CLAUDE_DIR/openrouter-config.json" ] && cp "$CLAUDE_DIR/openrouter-config.json" "$BACKUP_DIR/" && echo "  ✓ openrouter-config.json"
    [ -d "$CLAUDE_DIR/hooks" ] && cp -r "$CLAUDE_DIR/hooks" "$BACKUP_DIR/" && echo "  ✓ hooks/"
else
    echo "→ No existing config found — fresh install"
    mkdir -p "$CLAUDE_DIR"
fi

echo ""

# Install core files
echo "→ Installing configuration files..."

cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
echo "  ✓ settings.json"

cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
echo "  ✓ CLAUDE.md"

if [ ! -f "$CLAUDE_DIR/lessons.md" ]; then
    cp "$SCRIPT_DIR/lessons.md" "$CLAUDE_DIR/lessons.md"
    echo "  ✓ lessons.md (new)"
else
    echo "  - lessons.md (keeping existing)"
fi

echo ""
echo "→ Installing OpenRouter fallback config..."

if [ ! -f "$CLAUDE_DIR/openrouter-config.json" ]; then
    cp "$SCRIPT_DIR/templates/openrouter-config.example.json" "$CLAUDE_DIR/openrouter-config.json"
    echo "  ✓ openrouter-config.json (template — add your API key)"
else
    echo "  - openrouter-config.json (keeping existing)"
fi

# Install hooks
echo ""
echo "→ Installing hooks..."

mkdir -p "$CLAUDE_DIR/hooks"

for hook in model-router.sh quota-monitor.sh statusline.sh openrouter-proxy.sh; do
    if [ -f "$SCRIPT_DIR/hooks/$hook" ]; then
        cp "$SCRIPT_DIR/hooks/$hook" "$CLAUDE_DIR/hooks/$hook"
        chmod +x "$CLAUDE_DIR/hooks/$hook"
        echo "  ✓ hooks/$hook"
    fi
done

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit ~/.claude/openrouter-config.json and add your OpenRouter API key"
echo "     (or set \"enabled\": false to disable fallback)"
echo "  2. Run: claude"
echo "  3. Check the status line at the top — you should see gradient bars"
echo ""
echo "Docs: https://github.com/testerul/claude-code-config"
echo ""
