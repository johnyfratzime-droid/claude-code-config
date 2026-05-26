# Claude Code Config Installer — Windows (PowerShell 7+)
# Installs this config into ~/.claude/
# WARNING: Overwrites existing settings.json, CLAUDE.md, and hooks/
# Backs up existing config to ~/.claude/backup-YYYYMMDD/

$ErrorActionPreference = "Stop"

$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$BackupDir = Join-Path $ClaudeDir "backup-$(Get-Date -Format 'yyyyMMddHHmmss')"
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent

Write-Host ""
Write-Host "=== Claude Code Config Installer ===" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    Write-Host "  ✗ PowerShell 7 (pwsh) not found — install it first:" -ForegroundColor Red
    Write-Host "    https://github.com/PowerShell/PowerShell"
    exit 1
}
Write-Host "  ✓ $(pwsh --version)" -ForegroundColor Green

if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
    # Check bundled jq
    $bundledJq = Join-Path $env:USERPROFILE ".claude\bin\jq.exe"
    if (Test-Path $bundledJq) {
        Write-Host "  ✓ jq (bundled)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ jq not found — install it:" -ForegroundColor Red
        Write-Host "    scoop install jq  OR  choco install jq" -ForegroundColor Red
        Write-Host "    Or place jq.exe at $bundledJq" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  ✓ jq $(jq --version)" -ForegroundColor Green
}

# Check Claude Code
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Host "  ✓ claude installed" -ForegroundColor Green
} else {
    Write-Host "  ⚠ claude command not found — install Claude Code first" -ForegroundColor Yellow
    Write-Host "    https://github.com/anthropics/claude-code"
}

Write-Host ""

# Backup existing config
if (Test-Path $ClaudeDir) {
    Write-Host "Backing up existing config to $BackupDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    if (Test-Path "$ClaudeDir\settings.json") { Copy-Item "$ClaudeDir\settings.json" "$BackupDir\"; Write-Host "  ✓ settings.json" }
    if (Test-Path "$ClaudeDir\CLAUDE.md") { Copy-Item "$ClaudeDir\CLAUDE.md" "$BackupDir\"; Write-Host "  ✓ CLAUDE.md" }
    if (Test-Path "$ClaudeDir\lessons.md") { Copy-Item "$ClaudeDir\lessons.md" "$BackupDir\"; Write-Host "  ✓ lessons.md" }
    if (Test-Path "$ClaudeDir\openrouter-config.json") { Copy-Item "$ClaudeDir\openrouter-config.json" "$BackupDir\"; Write-Host "  ✓ openrouter-config.json" }
    if (Test-Path "$ClaudeDir\hooks") { Copy-Item "$ClaudeDir\hooks" "$BackupDir\hooks" -Recurse; Write-Host "  ✓ hooks/" }
} else {
    Write-Host "No existing config found — fresh install" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
}

Write-Host ""

# Install core files
Write-Host "Installing configuration files..." -ForegroundColor Yellow

Copy-Item "$ScriptDir\settings.windows.json" "$ClaudeDir\settings.json" -Force
Write-Host "  ✓ settings.json (Windows/PowerShell hooks)" -ForegroundColor Green

Copy-Item "$ScriptDir\CLAUDE.md" "$ClaudeDir\CLAUDE.md" -Force
Write-Host "  ✓ CLAUDE.md" -ForegroundColor Green

if (-not (Test-Path "$ClaudeDir\lessons.md")) {
    Copy-Item "$ScriptDir\lessons.md" "$ClaudeDir\lessons.md" -Force
    Write-Host "  ✓ lessons.md (new)" -ForegroundColor Green
} else {
    Write-Host "  - lessons.md (keeping existing)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Installing OpenRouter fallback config..." -ForegroundColor Yellow

if (-not (Test-Path "$ClaudeDir\openrouter-config.json")) {
    Copy-Item "$ScriptDir\templates\openrouter-config.example.json" "$ClaudeDir\openrouter-config.json" -Force
    Write-Host "  ✓ openrouter-config.json (template — add your API key)" -ForegroundColor Green
} else {
    Write-Host "  - openrouter-config.json (keeping existing)" -ForegroundColor Gray
}

# Install hooks
Write-Host ""
Write-Host "Installing hooks..." -ForegroundColor Yellow

$HooksDir = Join-Path $ClaudeDir "hooks"
New-Item -ItemType Directory -Path $HooksDir -Force | Out-Null

$psHooks = @("model-router.ps1", "quota-monitor.ps1", "statusline.ps1", "openrouter-proxy.ps1")
foreach ($hook in $psHooks) {
    if (Test-Path "$ScriptDir\hooks\$hook") {
        Copy-Item "$ScriptDir\hooks\$hook" "$HooksDir\$hook" -Force
        Write-Host "  ✓ hooks/$hook" -ForegroundColor Green
    }
}

# Also copy bash hooks (for WSL / Git Bash users)
$shHooks = @("model-router.sh", "quota-monitor.sh", "statusline.sh", "openrouter-proxy.sh")
foreach ($hook in $shHooks) {
    if (Test-Path "$ScriptDir\hooks\$hook") {
        Copy-Item "$ScriptDir\hooks\$hook" "$HooksDir\$hook" -Force
        Write-Host "  ✓ hooks/$hook (bash, for WSL/Git Bash)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== Installation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Edit $ClaudeDir\openrouter-config.json and add your OpenRouter API key"
Write-Host "     (or set `"enabled`": false to disable fallback)"
Write-Host "  2. Run: claude"
Write-Host "  3. Check the status line at the top — you should see gradient bars"
Write-Host ""
Write-Host "Docs: https://github.com/testerul/claude-code-config"
Write-Host ""
