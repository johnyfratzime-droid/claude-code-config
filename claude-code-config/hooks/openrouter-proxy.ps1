# Open Router API proxy — translates Claude Code API requests to Open Router format.
# Used when Claude quota is exhausted and fallback is active.
#
# This script is called by Claude Code's MCP/proxy mechanism when the
# <model_routing_hint> indicates Open Router fallback.
#
# Usage: openrouter-proxy.ps1 -RequestJson <json>
# Outputs: Open Router API response in Claude-compatible format
#
# PowerShell version — cross-platform (Windows pwsh / PowerShell 7+)

$Config = Join-Path $env:USERPROFILE ".claude\openrouter-config.json"

# Load config
if (-not (Test-Path $Config)) {
    Write-Error "Open Router config not found at $Config"
    exit 1
}

$cfg = Get-Content $Config -Raw | ConvertFrom-Json

if (-not $cfg.apiKey -or $cfg.apiKey -eq "sk-or-v1-YOUR-KEY-HERE") {
    Write-Error "Open Router API key not configured — edit $Config and add your key"
    exit 1
}

# Read request JSON from stdin or argument
$requestJson = $null
if ($args.Count -gt 0) {
    $requestJson = $args[0]
} else {
    $requestJson = [Console]::In.ReadToEnd()
}

if (-not $requestJson) {
    Write-Error "No request JSON provided"
    exit 1
}

try {
    $request = $requestJson | ConvertFrom-Json
} catch {
    Write-Error "Invalid request JSON: $_"
    exit 1
}

# Map Claude model names to Open Router slugs
$requestModel = $request.model
$orModel = switch -Regex ($requestModel) {
    "claude-haiku|haiku|claude-3-haiku|claude-3\.5-haiku" { $cfg.modelMapping.haiku }
    "claude-sonnet|sonnet|claude-3-sonnet|claude-4-sonnet" { $cfg.modelMapping.sonnet }
    "claude-opus|opus|claude-4-opus" { $cfg.modelMapping.opus }
    "anthropic/.*" { $requestModel }
    default { $cfg.modelMapping.sonnet }
}

# Transform request to Open Router format
$request.model = $orModel
$requestBody = $request | ConvertTo-Json -Depth 10

# Make request to Open Router
try {
    $response = Invoke-RestMethod -Uri "https://openrouter.ai/api/v1/chat/completions" `
        -Method POST `
        -Headers @{
            "Authorization" = "Bearer $($cfg.apiKey)"
            "Content-Type" = "application/json"
            "HTTP-Referer" = "https://claude.ai"
            "X-Title" = "Claude Code"
        } `
        -Body $requestBody `
        -TimeoutSec 120

    # Transform response back to Claude-compatible format
    $response | Add-Member -NotePropertyName "_provider" -NotePropertyValue "openrouter" -Force
    $response | Add-Member -NotePropertyName "_model_used" -NotePropertyValue $orModel -Force
    $response | ConvertTo-Json -Depth 10
} catch {
    $httpCode = $_.Exception.Response.StatusCode.value__
    Write-Error "Open Router request failed (HTTP $httpCode): $_"
    exit 1
}
