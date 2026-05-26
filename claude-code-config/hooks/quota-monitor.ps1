# Quota monitor — detects Claude API quota exhaustion (429) and activates Open Router fallback.
# Runs as UserPromptSubmit hook (after model-router.ps1).
# Checks recent API error logs and the usage cache to determine if quota is exhausted.
#
# PowerShell version — cross-platform (Windows pwsh / PowerShell 7+)

$Config = Join-Path $env:USERPROFILE ".claude\openrouter-config.json"
$UsageCache = Join-Path $env:TEMP "claude-usage-cache.json"
$QuotaFlag = Join-Path $env:TEMP "claude-quota-exhausted.flag"

# Exit if config doesn't exist or fallback is disabled
if (-not (Test-Path $Config)) { exit 0 }

$cfg = Get-Content $Config -Raw | ConvertFrom-Json
if ($cfg.enabled -ne $true) {
    if (Test-Path $QuotaFlag) { Remove-Item $QuotaFlag -Force }
    exit 0
}

# Check if quota is exhausted by reading usage cache
$quotaExhausted = $false
if (Test-Path $UsageCache) {
    $cache = Get-Content $UsageCache -Raw | ConvertFrom-Json
    if ($cache.five_hour -and $cache.five_hour.utilization) {
        if ($cache.five_hour.utilization -ge 0.95) {
            $quotaExhausted = $true
        }
    }
}

# Also check for recent 429 error cache
$ErrorCache = Join-Path $env:TEMP "claude-usage-cache.err"
if (Test-Path $ErrorCache) {
    $httpCode = Get-Content $ErrorCache -Raw
    if ($httpCode -eq "429" -or $httpCode -eq "403") {
        $quotaExhausted = $true
    }
}

# Update fallback state in config
if ($quotaExhausted) {
    Set-Content -Path $QuotaFlag -Value (Get-Date -Format "o") -Encoding UTF8
    $cfg.quotaTracking.lastQuotaExhausted = (Get-Date -Format "o")
    $cfg.quotaTracking.fallbackActive = $true
    Write-Output "[quota-monitor] FALLBACK ACTIVATED — Open Router enabled"
} else {
    if (Test-Path $QuotaFlag) { Remove-Item $QuotaFlag -Force }
    $cfg.quotaTracking.fallbackActive = $false
}

# Write updated config back
$cfg | ConvertTo-Json -Depth 5 | Set-Content -Path $Config -Encoding UTF8

exit 0
