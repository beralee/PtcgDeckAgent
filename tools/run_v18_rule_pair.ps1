[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$DeckId,

    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 10)]
    [int]$Round,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9_]+$')]
    [string]$Change,

    [ValidateSet(10, 20, 100)]
    [int]$Games = 10,

    [int]$SeedBase = 15300,
    [int]$MaxSteps = 200,
    [string]$Godot = 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe'
)

$ErrorActionPreference = 'Stop'
$roundToken = 'r{0:D2}' -f $Round
$artifactDirectory = Join-Path $PSScriptRoot '..\tmp\v18_rule_benchmarks'
$artifactDirectory = [System.IO.Path]::GetFullPath($artifactDirectory)
$allowedReasons = @('normal_game_end', 'deck_out')

function Invoke-Mode {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('normal', 'strong')]
        [string]$Mode
    )

    $fileName = "v18_${DeckId}_${Mode}_${roundToken}_${Change}_s${SeedBase}_n${Games}.json"
    $workspacePath = Join-Path $artifactDirectory $fileName
    $godotPath = "res://tmp/v18_rule_benchmarks/$fileName"
    $runnerArgs = @(
        '--headless',
        '--disable-crash-handler',
        '--path', '.',
        'res://scripts/training/run_deck_benchmark.tscn',
        '--',
        "--deck-id=$DeckId",
        '--anchor-id=575720',
        "--games=$Games",
        "--seed-base=$SeedBase",
        "--max-steps=$MaxSteps",
        '--deck-decision-mode=rules_only',
        '--anchor-decision-mode=rules_only',
        "--json-output=$godotPath"
    )
    if ($Mode -eq 'strong') {
        $runnerArgs += '--deck-strong-fixed-opening'
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $godotExitCode = 0
    try {
        $ErrorActionPreference = 'Continue'
        $godotOutput = @(
            & $Godot @runnerArgs 2>&1 | ForEach-Object {
                $line = [string]$_
                Write-Host $line
                $line
            }
        )
        $godotExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($godotExitCode -ne 0) {
        throw "Godot $Mode benchmark failed with exit code $godotExitCode"
    }
    $fatalRuntimeLines = @($godotOutput | Where-Object {
        $_ -match 'SCRIPT ERROR:' -or
        $_ -match 'ERROR: Failed to load script' -or
        $_ -match 'ERROR: Failed loading resource' -or
        $_ -match 'ERROR: Parse Error' -or
        $_ -match 'ERROR: Compile Error'
    })
    if ($fatalRuntimeLines.Count -gt 0) {
        throw "Godot $Mode benchmark emitted fatal script/load errors; artifact is invalid"
    }
    if (-not (Test-Path -LiteralPath $workspacePath)) {
        throw "Expected artifact was not written: $workspacePath"
    }

    $result = Get-Content -Raw -LiteralPath $workspacePath | ConvertFrom-Json
    $details = @($result.per_game)
    $badDetails = @($details | Where-Object {
        $_.failure_reason -notin $allowedReasons -or
        [bool]$_.stalled -or
        [bool]$_.terminated_by_cap
    })
    $expectedStrong = $Mode -eq 'strong'
    $clean = (
        [int]$result.games -eq $Games -and
        [int]$result.draws -eq 0 -and
        $details.Count -eq $Games -and
        $badDetails.Count -eq 0 -and
        [string]$result.deck_decision_mode -eq 'rules_only' -and
        [string]$result.anchor_decision_mode -eq 'rules_only' -and
        [int]$result.anchor_id -eq 575720 -and
        [bool]$result.deck_strong_fixed_opening -eq $expectedStrong -and
        -not [bool]$result.anchor_strong_fixed_opening
    )

    [pscustomobject]@{
        Deck = $DeckId
        Mode = $Mode
        Games = [int]$result.games
        Wins = [int]$result.wins
        Losses = [int]$result.losses
        Draws = [int]$result.draws
        Clean = $clean
        Gate = $clean -and [int]$result.games -eq 100 -and [int]$result.wins -ge 50
        Artifact = $fileName
    }
}

$rows = @(
    Invoke-Mode -Mode normal
    Invoke-Mode -Mode strong
)
$rows | Format-Table -AutoSize

if (@($rows | Where-Object { -not $_.Clean }).Count -gt 0) {
    exit 2
}
