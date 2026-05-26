# Claude Code status line — gradient progress bars
# Shows: model, dir, git branch, context window, 5h usage (from API)
#
# PowerShell version — cross-platform (Windows pwsh / PowerShell 7+)

$Config = Join-Path $env:USERPROFILE ".claude\openrouter-config.json"
$QuotaFlag = Join-Path $env:TEMP "claude-quota-exhausted.flag"
$Tmp = $env:TEMP

$InputText = [Console]::In.ReadToEnd()
try {
    $json = $InputText | ConvertFrom-Json
} catch {
    Write-Output "Claude (invalid input)"
    exit 0
}

# --- Extract fields ---
$model = $json.model.display_name
if (-not $model) { $model = "Claude" }

$cwd = $json.cwd
$dirName = Split-Path $cwd -Leaf

$ctxPct = [math]::Round(($json.context_window.used_percentage) * 100)
$ctxSize = $json.context_window.context_window_size

# --- Git branch ---
$gitBranch = ""
try {
    Set-Location $cwd -ErrorAction Stop
    $gitBranch = git symbolic-ref --short HEAD 2>$null
    if (-not $gitBranch) { $gitBranch = git rev-parse --short HEAD 2>$null }
} catch {}

# --- Check fallback ---
$fallbackActive = $false
if ((Test-Path $QuotaFlag) -and (Test-Path $Config)) {
    $cfg = Get-Content $Config -Raw | ConvertFrom-Json
    if ($cfg.enabled -eq $true) { $fallbackActive = $true }
}

# --- Usage cache (non-blocking read) ---
$UsageCache = Join-Path $Tmp "claude-usage-cache.json"
$usage5h = ""
$usageResets = ""
if (Test-Path $UsageCache) {
    $cacheAge = ((Get-Date) - (Get-Item $UsageCache).LastWriteTime).TotalSeconds
    if ($cacheAge -lt 600) {
        $cache = Get-Content $UsageCache -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($cache -and $cache.five_hour) {
            $usage5h = [math]::Round($cache.five_hour.utilization * 100)
            if ($cache.five_hour.resets_at) {
                $resetTime = [DateTimeOffset]::Parse($cache.five_hour.resets_at)
                $diff = $resetTime - (Get-Date).ToUniversalTime()
                if ($diff.TotalMinutes -gt 0) {
                    $h = [math]::Floor($diff.TotalHours)
                    $m = [math]::Floor($diff.Minutes)
                    if ($h -gt 0) { $usageResets = "${h}h${m}m" } else { $usageResets = "${m}m" }
                } else { $usageResets = "now" }
            }
        }
    }
}

# --- Format context size ---
function Format-CtxSize($s) {
    if ($s -ge 1000000) { return "$([math]::Floor($s/1000000)).$([math]::Floor(($s/100000)%10))M" }
    elseif ($s -ge 1000) { return "$([math]::Floor($s/1000))k" }
    else { return "$s" }
}

# --- Build bar ---
function Build-Bar($pct, $w = 20) {
    $colors = @(71,72,78,114,150,186,222,221,220,214,208,202,196,160,124,88)
    $filled = [math]::Min([math]::Floor($pct * $w / 100), $w)
    $empty = $w - $filled
    $bar = ""
    for ($i = 0; $i -lt $filled; $i++) {
        $ci = [math]::Min([math]::Floor($i * $colors.Length / $w), $colors.Length - 1)
        $bar += "`e[38;5;$($colors[$ci])m█"
    }
    for ($i = 0; $i -lt $empty; $i++) {
        $bar += "`e[38;5;238m░"
    }
    $pc = 72
    if ($pct -ge 40) { $pc = 222 }
    if ($pct -ge 65) { $pc = 208 }
    if ($pct -ge 85) { $pc = 196 }
    return "$bar `e[38;5;${pc}m${pct}%`e[0m"
}

# --- Assemble segments ---
$segments = @()

# Colors
$C_RESET = "`e[0m"

# Model
$segments += "🧠 `e[38;5;183m${model}${C_RESET}"

# Fallback indicator
if ($fallbackActive) {
    $segments += "`e[38;5;214m🔀 OR${C_RESET}"
}

# Directory
if ($dirName) {
    $segments += "📂 `e[38;5;117m${dirName}${C_RESET}"
}

# Git branch
if ($gitBranch) {
    $segments += "⎇ `e[38;5;116m${gitBranch}${C_RESET}"
}

# Conda/venv
$condaEnv = $env:CONDA_DEFAULT_ENV
$venv = $env:VIRTUAL_ENV
if ($condaEnv) {
    $condaName = Split-Path $condaEnv -Leaf
    $segments += "🐍 `e[38;5;113m${condaName}${C_RESET}"
} elseif ($venv) {
    $venvName = Split-Path $venv -Leaf
    $segments += "🐍 `e[38;5;113m${venvName}${C_RESET}"
}

# Context bar
$ctxFmt = Format-CtxSize $ctxSize
$ctxBar = Build-Bar $ctxPct
$segments += "`e[38;5;250mcontext${C_RESET} ${ctxBar} `e[38;5;250m${ctxFmt}${C_RESET}"

# 5h usage bar
if ($usage5h -ne "") {
    $usageBar = Build-Bar $usage5h
    $seg = "`e[38;5;250m5h${C_RESET} ${usageBar}"
    if ($usageResets) { $seg += " `e[38;5;250m${usageResets}${C_RESET}" }
    $segments += $seg
}

# Join with separator
Write-Output ($segments -join " `e[38;5;240m│${C_RESET} ")
