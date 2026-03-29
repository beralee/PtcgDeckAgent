$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'training_watchdog.ps1'
. $scriptPath

function Assert-Equal {
	param(
		$Actual,
		$Expected,
		[string]$Message
	)
	if ($Actual -ne $Expected) {
		throw "Assert-Equal failed: $Message. Expected=[$Expected] Actual=[$Actual]"
	}
}

function Assert-True {
	param(
		[bool]$Condition,
		[string]$Message
	)
	if (-not $Condition) {
		throw "Assert-True failed: $Message"
	}
}

$now = [datetime]'2026-03-29T02:00:00'

$healthyCpu = Get-JobHealthSummary -JobName 'overnight' -ProcessCount 2 -CpuDeltaSeconds 12.5 -LastActivityAt $null -LastHealthyAt ([datetime]'2026-03-29T01:55:00') -Now $now -InactivityThresholdMinutes 120 -RestartOnExit $true
Assert-Equal $healthyCpu.State 'running' 'CPU progress should keep job healthy'

$healthyFile = Get-JobHealthSummary -JobName 'overnight' -ProcessCount 1 -CpuDeltaSeconds 0.0 -LastActivityAt ([datetime]'2026-03-29T01:59:00') -LastHealthyAt ([datetime]'2026-03-29T01:00:00') -Now $now -InactivityThresholdMinutes 120 -RestartOnExit $true
Assert-Equal $healthyFile.State 'running' 'Recent file activity should keep job healthy'

$missing = Get-JobHealthSummary -JobName 'overnight' -ProcessCount 0 -CpuDeltaSeconds 0.0 -LastActivityAt $null -LastHealthyAt ([datetime]'2026-03-29T01:40:00') -Now $now -InactivityThresholdMinutes 120 -RestartOnExit $true
Assert-Equal $missing.State 'missing' 'Restartable job without process should be missing'

$completed = Get-JobHealthSummary -JobName 'smoke' -ProcessCount 0 -CpuDeltaSeconds 0.0 -LastActivityAt $null -LastHealthyAt ([datetime]'2026-03-29T01:40:00') -Now $now -InactivityThresholdMinutes 120 -RestartOnExit $false
Assert-Equal $completed.State 'completed' 'Non-restartable job without process should be completed'

$stalled = Get-JobHealthSummary -JobName 'overnight' -ProcessCount 1 -CpuDeltaSeconds 0.0 -LastActivityAt ([datetime]'2026-03-28T23:30:00') -LastHealthyAt ([datetime]'2026-03-28T23:30:00') -Now $now -InactivityThresholdMinutes 120 -RestartOnExit $true
Assert-Equal $stalled.State 'stalled' 'Running job without progress past threshold should be stalled'

$args = Build-TrainLoopArgumentList -GodotPath 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' -Iterations 6 -Generations 12 -Epochs 80 -ModelDir './models/overnight_20260329'
Assert-True ($args -contains '--iterations') 'Argument list should contain --iterations switch'
Assert-True ($args -contains '6') 'Argument list should include iteration value'
Assert-True ($args[-1] -eq './models/overnight_20260329') 'Model dir should be final argument'

Write-Output 'training_watchdog tests passed'
