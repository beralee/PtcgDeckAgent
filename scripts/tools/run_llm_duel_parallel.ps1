param(
    [string]$GodotExe = "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe",
    [string]$WorkspaceRoot = "D:/ai/code/ptcgtrain",
    [string]$Mode = "miraidon",
    [int]$Games = 3,
    [int]$Concurrency = 3,
    [int]$Seed = 202605500,
    [int]$MaxSteps = 220,
    [double]$MaxGameSeconds = 360,
    [double]$LlmWaitTimeoutSeconds = 75,
    [int]$LlmMaxFailures = 1,
    [string]$OutputRoot = "res://tmp/llm_duels/parallel_vs_miraidon",
    [string]$JsonOutput = "res://tmp/llm_duels/parallel_vs_miraidon_summary.json",
    [int]$RuleDeckId = 0,
    [int]$LlmDeckId = 0,
    [string]$RuleStrategyId = "",
    [string]$LlmStrategyId = "",
    [switch]$StrongFixedOpening,
    [switch]$RuleStrongFixedOpening,
    [switch]$LlmStrongFixedOpening,
    [int]$ProcessTimeoutSeconds = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-ProjectPath {
    param([string]$PathValue)
    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return ""
    }
    if ($PathValue.StartsWith("res://")) {
        $relative = $PathValue.Substring("res://".Length).Replace("/", [System.IO.Path]::DirectorySeparatorChar)
        return Join-Path $WorkspaceRoot $relative
    }
    return $PathValue
}

function Read-Text-OrEmpty {
    param([string]$PathValue)
    if (Test-Path -LiteralPath $PathValue) {
        return Get-Content -LiteralPath $PathValue -Raw
    }
    return ""
}

function Extract-LastInt {
    param(
        [string]$Text,
        [string]$Pattern,
        [int]$DefaultValue = -1
    )
    $matches = [regex]::Matches($Text, $Pattern)
    if ($matches.Count -le 0) {
        return $DefaultValue
    }
    return [int]$matches[$matches.Count - 1].Groups[1].Value
}

function Extract-FirstInt {
    param(
        [string]$Text,
        [string]$Pattern,
        [int]$DefaultValue = -1
    )
    $match = [regex]::Match($Text, $Pattern)
    if (-not $match.Success) {
        return $DefaultValue
    }
    return [int]$match.Groups[1].Value
}

function Extract-LastString {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$DefaultValue = ""
    )
    $matches = [regex]::Matches($Text, $Pattern)
    if ($matches.Count -le 0) {
        return $DefaultValue
    }
    return [string]$matches[$matches.Count - 1].Groups[1].Value
}

function Start-DuelProcess {
    param(
        [int]$GameIndex,
        [string]$RunRoot
    )
    $gameSeed = $Seed + $GameIndex
    $gameOutputRoot = "$OutputRoot/game_$GameIndex"
    $gameJson = "$OutputRoot/game_$GameIndex/summary.json"
    $stdoutPath = Join-Path $RunRoot ("game_{0}_stdout.log" -f $GameIndex)
    $stderrPath = Join-Path $RunRoot ("game_{0}_stderr.log" -f $GameIndex)
    $godotLogPath = Join-Path $RunRoot ("game_{0}_godot.log" -f $GameIndex)
    $args = @(
        "--headless",
        "--disable-crash-handler",
        "--log-file", $godotLogPath,
        "--path", $WorkspaceRoot,
        "-s", "res://scripts/tools/run_llm_raging_bolt_duel.gd",
        "--",
        "--mode=$Mode",
        "--games=1",
        "--seed=$gameSeed",
        "--max-steps=$MaxSteps",
        "--max-game-seconds=$MaxGameSeconds",
        "--llm-wait-timeout-seconds=$LlmWaitTimeoutSeconds",
        "--llm-max-failures=$LlmMaxFailures",
        "--output-root=$gameOutputRoot",
        "--json-output=$gameJson"
    )
    if ($RuleDeckId -gt 0) {
        $args += "--rule-deck-id=$RuleDeckId"
    }
    if ($LlmDeckId -gt 0) {
        $args += "--llm-deck-id=$LlmDeckId"
    }
    if (-not [string]::IsNullOrWhiteSpace($RuleStrategyId)) {
        $args += "--rule-strategy-id=$RuleStrategyId"
    }
    if (-not [string]::IsNullOrWhiteSpace($LlmStrategyId)) {
        $args += "--llm-strategy-id=$LlmStrategyId"
    }
    if ($StrongFixedOpening.IsPresent) {
        $args += "--strong-fixed-opening=true"
    }
    if ($RuleStrongFixedOpening.IsPresent) {
        $args += "--rule-strong-fixed-opening=true"
    }
    if ($LlmStrongFixedOpening.IsPresent) {
        $args += "--llm-strong-fixed-opening=true"
    }
    $process = Start-Process `
        -FilePath $GodotExe `
        -ArgumentList $args `
        -WorkingDirectory $WorkspaceRoot `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru `
        -WindowStyle Hidden
    return [pscustomobject]@{
        GameIndex = $GameIndex
        Seed = $gameSeed
        Process = $process
        StartedAt = Get-Date
        JsonPath = Resolve-ProjectPath $gameJson
        StdoutPath = $stdoutPath
        StderrPath = $stderrPath
        GodotLogPath = $godotLogPath
    }
}

function Collect-DuelResult {
    param($Job)
    $Job.Process.Refresh()
    $exitCode = if ($Job.Process.HasExited) { [int]$Job.Process.ExitCode } else { -999 }
    $jsonText = Read-Text-OrEmpty $Job.JsonPath
    $stdoutText = Read-Text-OrEmpty $Job.StdoutPath
    $sourceText = if (-not [string]::IsNullOrWhiteSpace($jsonText)) { $jsonText } else { $stdoutText }
    $winner = Extract-LastInt $sourceText '"winner_index"\s*:\s*(-?\d+)' -1
    $turn = Extract-LastInt $sourceText '"turn_number"\s*:\s*(\d+)' -1
    $steps = Extract-LastInt $sourceText '"steps"\s*:\s*(\d+)' -1
    $requests = Extract-LastInt $sourceText '"requests"\s*:\s*(\d+)' 0
    $successes = Extract-LastInt $sourceText '"successes"\s*:\s*(\d+)' 0
    $failures = Extract-LastInt $sourceText '"failures"\s*:\s*(\d+)' 0
    $skipped = Extract-LastInt $sourceText '"skipped_by_local_rules"\s*:\s*(\d+)' 0
    $ruleFixedPath = Extract-LastString $sourceText '"rule_fixed_order_path"\s*:\s*"([^"]*)"' ""
    $llmFixedPath = Extract-LastString $sourceText '"llm_fixed_order_path"\s*:\s*"([^"]*)"' ""
    $wallClock = [Math]::Round(((Get-Date) - $Job.StartedAt).TotalSeconds, 3)
    return [pscustomobject]@{
        game_index = $Job.GameIndex
        seed = $Job.Seed
        exit_code = $exitCode
        winner_index = $winner
        turn_number = $turn
        steps = $steps
        llm_requests = $requests
        llm_successes = $successes
        llm_failures = $failures
        skipped_by_local_rules = $skipped
        rule_fixed_order_path = $ruleFixedPath
        llm_fixed_order_path = $llmFixedPath
        wall_clock_seconds = $wallClock
        json_path = $Job.JsonPath
        stdout_path = $Job.StdoutPath
        stderr_path = $Job.StderrPath
        godot_log_path = $Job.GodotLogPath
    }
}

if ($Games -lt 1) {
    throw "Games must be >= 1"
}
if ($Concurrency -lt 1) {
    throw "Concurrency must be >= 1"
}
if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot executable not found: $GodotExe"
}
if (-not (Test-Path -LiteralPath $WorkspaceRoot)) {
    throw "Workspace root not found: $WorkspaceRoot"
}

$runRoot = Join-Path $WorkspaceRoot ("tmp/llm_duels/parallel_runner_{0}" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

$pending = [System.Collections.Queue]::new()
for ($i = 0; $i -lt $Games; $i++) {
    $pending.Enqueue($i)
}

$running = @()
$results = @()
while ($pending.Count -gt 0 -or $running.Count -gt 0) {
    while ($pending.Count -gt 0 -and $running.Count -lt $Concurrency) {
        $running += Start-DuelProcess -GameIndex ([int]$pending.Dequeue()) -RunRoot $runRoot
    }

    Start-Sleep -Milliseconds 500
    $stillRunning = @()
    foreach ($job in $running) {
        $proc = $job.Process
        if (-not $proc.HasExited) {
            if ($ProcessTimeoutSeconds -gt 0 -and ((Get-Date) - $job.StartedAt).TotalSeconds -ge $ProcessTimeoutSeconds) {
                Stop-Process -Id $proc.Id -Force
                $proc.WaitForExit()
            } else {
                $stillRunning += $job
                continue
            }
        }
        $results += Collect-DuelResult -Job $job
    }
    $running = $stillRunning
}

$ruleWins = @($results | Where-Object { $_.winner_index -eq 0 }).Count
$llmWins = @($results | Where-Object { $_.winner_index -eq 1 }).Count
$drawOrFailed = $Games - $ruleWins - $llmWins
$requestCount = ($results | Measure-Object -Property llm_requests -Sum).Sum
$successCount = ($results | Measure-Object -Property llm_successes -Sum).Sum
$failureCount = ($results | Measure-Object -Property llm_failures -Sum).Sum
$skipCount = ($results | Measure-Object -Property skipped_by_local_rules -Sum).Sum

$summary = [pscustomobject]@{
    games = $Games
    concurrency = $Concurrency
    mode = $Mode
    seed = $Seed
    strong_fixed_opening = [bool]$StrongFixedOpening.IsPresent
    rule_strong_fixed_opening = [bool]$RuleStrongFixedOpening.IsPresent
    llm_strong_fixed_opening = [bool]$LlmStrongFixedOpening.IsPresent
    wins = [pscustomobject]@{
        rule_ai = $ruleWins
        llm_ai = $llmWins
        draw_or_failed = $drawOrFailed
    }
    rule_win_rate = if ($Games -gt 0) { $ruleWins / [double]$Games } else { 0.0 }
    llm_win_rate = if ($Games -gt 0) { $llmWins / [double]$Games } else { 0.0 }
    llm_health = [pscustomobject]@{
        requests = [int]$requestCount
        successes = [int]$successCount
        failures = [int]$failureCount
        skipped_by_local_rules = [int]$skipCount
        takeover_rate = if ($requestCount -gt 0) { $successCount / [double]$requestCount } else { 0.0 }
    }
    run_root = $runRoot
    results = @($results | Sort-Object game_index)
}

$summaryJson = $summary | ConvertTo-Json -Depth 8
$jsonOutputPath = Resolve-ProjectPath $JsonOutput
if (-not [string]::IsNullOrWhiteSpace($jsonOutputPath)) {
    $jsonDir = Split-Path -Parent $jsonOutputPath
    if (-not [string]::IsNullOrWhiteSpace($jsonDir)) {
        New-Item -ItemType Directory -Force -Path $jsonDir | Out-Null
    }
    Set-Content -LiteralPath $jsonOutputPath -Value $summaryJson -Encoding UTF8
}
Write-Output $summaryJson
