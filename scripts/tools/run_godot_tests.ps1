param(
	[ValidateSet("functional", "ui", "ai", "all", "focused")]
	[string]$Runner = "functional",
	[string]$Suite = "",
	[string]$SuiteScript = "",
	[string]$GodotExe = "",
	[string]$UserDataRoot = "",
	[int]$TimeoutSeconds = 0,
	[string]$ReportDirectory = "",
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$ExtraUserArgs = @()
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptRoot "..\..")).Path

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
	if (-not [string]::IsNullOrWhiteSpace($env:GODOT_EXE)) {
		$GodotExe = $env:GODOT_EXE
	} else {
		$GodotExe = "D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe"
	}
}

if (-not (Test-Path -LiteralPath $GodotExe)) {
	throw "Godot executable not found: $GodotExe. Set GODOT_EXE or pass -GodotExe."
}

# Ordinary suites share one catalog, executor and evidence contract. Benchmark
# modes retain their existing command-line interface below.
$isBenchmark = $Runner -eq "ai" -and @($ExtraUserArgs | Where-Object {
	$_ -match '^--(?:mode=(?!suite(?:$|=))|matchup-sweep|matchup-anchor-deck=|anchor-deck-id=)'
}).Count -gt 0
if (-not $isBenchmark) {
	$matrixArgs = @((Join-Path $scriptRoot 'run_test_matrix.py'), '--godot', $GodotExe)
	if ($PSBoundParameters.ContainsKey('TimeoutSeconds')) {
		if ($TimeoutSeconds -le 0) { throw 'TimeoutSeconds must be positive' }
		$matrixArgs += @('--timeout', "$TimeoutSeconds")
	}
	if ($Runner -eq 'focused') {
		if ([string]::IsNullOrWhiteSpace($SuiteScript)) { throw 'Focused runner requires -SuiteScript' }
		$matrixArgs += @('--suite-script', $SuiteScript)
	} else {
		$matrixArgs += @('--group', $Runner)
	}
	if ($Suite) { $matrixArgs += @('--suite', $Suite) }
	if ($UserDataRoot) { $matrixArgs += @('--user-data-root', $UserDataRoot) }
	if ($ReportDirectory) { $matrixArgs += @('--output', $ReportDirectory) }
	$matrixArgs += $ExtraUserArgs
	& python @matrixArgs
	exit $LASTEXITCODE
}

if ([string]::IsNullOrWhiteSpace($UserDataRoot)) {
	$UserDataRoot = Join-Path $projectRoot ".godot_test_user\appdata"
}
$logRoot = Join-Path $projectRoot ".godot_test_user\logs"
New-Item -ItemType Directory -Force -Path $UserDataRoot | Out-Null
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$UserDataRoot = (Resolve-Path -LiteralPath $UserDataRoot).Path

$runnerScript = switch ($Runner) {
	"functional" { "res://tests/FunctionalTestRunner.gd" }
	"ai" { "res://tests/AITrainingTestRunner.gd" }
	"focused" { "res://tests/FocusedSuiteRunner.gd" }
}

$userArgs = @()
if (-not [string]::IsNullOrWhiteSpace($Suite)) {
	$userArgs += "--suite=$Suite"
}
if ($Runner -eq "focused") {
	if ([string]::IsNullOrWhiteSpace($SuiteScript)) {
		throw "Focused runner requires -SuiteScript, for example: -SuiteScript res://tests/test_battle_dialog_controller.gd"
	}
	$userArgs += "--suite-script=$SuiteScript"
}
$userArgs += $ExtraUserArgs

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $logRoot "$Runner-$timestamp.log"
$godotArgs = @(
	"--headless",
	"--log-file",
	$logFile,
	"--path",
	$projectRoot,
	"-s",
	$runnerScript
)
if ($userArgs.Count -gt 0) {
	$godotArgs += "--"
	$godotArgs += $userArgs
}

$previousAppData = $env:APPDATA
$exitCode = 0
try {
	$env:APPDATA = $UserDataRoot
	Write-Host "Godot user data root: $UserDataRoot"
	Write-Host "Godot log file: $logFile"
	& $GodotExe @godotArgs
	$exitCode = $LASTEXITCODE
} finally {
	$env:APPDATA = $previousAppData
}

exit $exitCode
