param(
	[ValidateSet("functional", "ai", "focused")]
	[string]$Runner = "functional",
	[string]$Suite = "",
	[string]$SuiteScript = "",
	[string]$GodotExe = "",
	[string]$UserDataRoot = "",
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

if ([string]::IsNullOrWhiteSpace($UserDataRoot)) {
	$UserDataRoot = Join-Path $projectRoot ".godot_test_user\appdata"
}
$logRoot = Join-Path $projectRoot ".godot_test_user\logs"
New-Item -ItemType Directory -Force -Path $UserDataRoot | Out-Null
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null

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
