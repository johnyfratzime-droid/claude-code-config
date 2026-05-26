# Auto-classify incoming prompts and inject model routing hints.
# Fires on every UserPromptSubmit. Injects a <model_routing_hint> tag
# when the task warrants Sonnet or Opus — main session stays on Haiku
# as orchestrator, subagents do the heavy lifting at the right tier.
#
# Open Router fallback: when Claude quota is exhausted (429), routes to
# Open Router API with equivalent model mapping (defined in openrouter-config.json).
#
# PowerShell version — cross-platform (Windows pwsh / PowerShell 7+)

$Config = Join-Path $env:USERPROFILE ".claude\openrouter-config.json"
$QuotaFlag = Join-Path $env:TEMP "claude-quota-exhausted.flag"

$InputText = [Console]::In.ReadToEnd()

# --- Extract prompt text and classify tier ---
try {
    $json = $InputText | ConvertFrom-Json
    $prompt = ($json.prompt).ToLower()
} catch {
    $prompt = ""
}

$tier = "HAIKU"

$opusPatterns = @(
    "architect", "security audit", "critical (bug|issue|fix)",
    "production incident", "breaking change", "deep analys",
    "distributed system", "compliance", "forensic", " audit ",
    "system design", "migration strateg", "scalab"
)

$sonnetPatterns = @(
    "implement", "\bbuild\b", "create (feature|class|service|module)",
    "refactor", "debug", "fix (bug|error|issue)", "code review", "deploy",
    "integrat", "migrat", "optimiz", "analyz", "test suite",
    "\bfeature\b", "database", "\bapi\b", "auth", "performance",
    "write a function", "write a class", "write a test",
    "what is wrong", "how does.* work", "explain how"
)

foreach ($p in $opusPatterns) {
    if ($prompt -match $p) { $tier = "OPUS"; break }
}
if ($tier -ne "OPUS") {
    foreach ($p in $sonnetPatterns) {
        if ($prompt -match $p) { $tier = "SONNET"; break }
    }
}

# --- Check if Open Router fallback is active ---
$fallbackActive = $false
if ((Test-Path $QuotaFlag) -and (Test-Path $Config)) {
    $cfg = Get-Content $Config -Raw | ConvertFrom-Json
    if ($cfg.enabled -eq $true) {
        $fallbackActive = $true
    }
}

# --- Output routing hint ---
if ($fallbackActive -and (Test-Path $Config)) {
    $cfg = Get-Content $Config -Raw | ConvertFrom-Json
    $orModel = $null
    switch ($tier.ToLower()) {
        "haiku"  { $orModel = $cfg.modelMapping.haiku }
        "sonnet" { $orModel = $cfg.modelMapping.sonnet }
        "opus"   { $orModel = $cfg.modelMapping.opus }
    }
    if ($orModel) {
        Write-Output "<model_routing_hint>AUTO-ROUTER: $tier tier via Open Router (model=`"$orModel`") — Claude quota exhausted, fallback active. Use Open Router API for this request.</model_routing_hint>"
    }
} else {
    if ($tier -eq "OPUS") {
        Write-Output "<model_routing_hint>AUTO-ROUTER: OPUS tier — architecture/security/critical decision. Spawn Agent(model=`"opus`") for the core work.</model_routing_hint>"
    } elseif ($tier -eq "SONNET") {
        Write-Output "<model_routing_hint>AUTO-ROUTER: SONNET tier — implementation/debugging/analysis. Spawn Agent(model=`"sonnet`") for the core work.</model_routing_hint>"
    }
}

exit 0
