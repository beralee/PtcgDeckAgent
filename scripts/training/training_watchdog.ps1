param(
	[string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
	[string]$GitBashPath = 'D:\Program Files\Git\bin\bash.exe',
	[string]$TrainLoopPath = 'scripts/training/train_loop.sh',
	[string]$GodotPath = 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe',
	[string]$SmokeModelDir = './models/smoke_20260329',
	[int]$SmokeIterations = 1,
	[int]$SmokeGenerations = 2,
	[int]$SmokeEpochs = 5,
	[string]$OvernightModelDir = './models/overnight_20260329',
	[int]$OvernightIterations = 6,
	[int]$OvernightGenerations = 12,
	[int]$OvernightEpochs = 80,
	[int]$CheckIntervalMinutes = 5,
	[int]$HourlySummaryMinutes = 60,
	[int]$InactivityThresholdMinutes = 120,
	[int]$RestartCooldownMinutes = 15,
	[string]$LogDir = '',
	[switch]$RunOnce
)

$ErrorActionPreference = 'Stop'

function Build-TrainLoopArgumentList {
	param(
		[string]$GodotPath,
		[int]$Iterations,
		[int]$Generations,
		[int]$Epochs,
		[string]$ModelDir
	)

	return @(
		$TrainLoopPath,
		'--godot', $GodotPath,
		'--iterations', "$Iterations",
		'--generations', "$Generations",
		'--epochs', "$Epochs",
		'--model-dir', $ModelDir
	)
}

function Get-JobHealthSummary {
	param(
		[string]$JobName,
		[int]$ProcessCount,
		[double]$CpuDeltaSeconds,
		$LastActivityAt,
		$LastHealthyAt,
		[datetime]$Now,
		[int]$InactivityThresholdMinutes,
		[bool]$RestartOnExit
	)

	if ($null -ne $LastActivityAt) {
		$LastActivityAt = [datetime]$LastActivityAt
	}
	if ($null -ne $LastHealthyAt) {
		$LastHealthyAt = [datetime]$LastHealthyAt
	}

	$effectiveHealthyAt = $LastHealthyAt
	if ($CpuDeltaSeconds -gt 0.1) {
		$effectiveHealthyAt = $Now
	} elseif ($null -ne $LastActivityAt -and $LastActivityAt -gt $Now.AddMinutes(-$InactivityThresholdMinutes)) {
		$effectiveHealthyAt = $Now
	}

	$status = 'running'
	$reason = 'active'
	if ($ProcessCount -le 0) {
		if ($RestartOnExit) {
			$status = 'missing'
			$reason = 'no matching process'
		} else {
			$status = 'completed'
			$reason = 'process exited and restart disabled'
		}
	} else {
		$reference = $effectiveHealthyAt
		if ($null -eq $reference -and $null -ne $LastActivityAt) {
			$reference = $LastActivityAt
		}
		if ($null -ne $reference) {
			$idleMinutes = ($Now - $reference).TotalMinutes
			if ($idleMinutes -ge $InactivityThresholdMinutes) {
				$status = 'stalled'
				$reason = "no progress for $([math]::Round($idleMinutes, 1)) minutes"
			} elseif ($CpuDeltaSeconds -le 0.1 -and $null -ne $LastActivityAt -and $LastActivityAt -le $Now.AddMinutes(-10)) {
				$status = 'running'
				$reason = 'process alive, waiting for next visible artifact'
			}
		}
	}

	return [pscustomobject]@{
		JobName = $JobName
		State = $status
		Reason = $reason
		EffectiveHealthyAt = $effectiveHealthyAt
	}
}

function Write-WatchdogLog {
	param(
		[string]$LogPath,
		[string]$Message,
		[hashtable]$Context = @{}
	)

	$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
	$line = "[${timestamp}] $Message"
	if ($Context.Count -gt 0) {
		$parts = @()
		foreach ($key in ($Context.Keys | Sort-Object)) {
			$parts += ('{0}={1}' -f $key, $Context[$key])
		}
		$line = "$line | " + ($parts -join ' ')
	}
	Add-Content -Path $LogPath -Value $line
	Write-Output $line
}

function Get-LatestWriteTimeUtc {
	param(
		[string[]]$Paths
	)

	$latest = $null
	foreach ($path in $Paths) {
		if (-not (Test-Path -LiteralPath $path)) {
			continue
		}
		$item = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
		if ($null -eq $item) {
			continue
		}
		if ($item.PSIsContainer) {
			$candidate = Get-ChildItem -LiteralPath $path -Recurse -File -ErrorAction SilentlyContinue |
				Sort-Object LastWriteTimeUtc -Descending |
				Select-Object -First 1
			if ($candidate -and (($null -eq $latest) -or ($candidate.LastWriteTimeUtc -gt $latest))) {
				$latest = $candidate.LastWriteTimeUtc
			}
		} elseif (($null -eq $latest) -or ($item.LastWriteTimeUtc -gt $latest)) {
			$latest = $item.LastWriteTimeUtc
		}
	}
	return $latest
}

function Get-TrainingProcesses {
	$all = Get-CimInstance Win32_Process | Where-Object {
		$_.CommandLine -and $_.CommandLine -like '*train_loop.sh*'
	}
	return @($all)
}

function Get-MatchingTrainingProcesses {
	param(
		[object[]]$Processes,
		[string]$ProcessMatch
	)

	return @($Processes | Where-Object {
		$_.CommandLine -and $_.CommandLine -like "*$ProcessMatch*"
	})
}

function Get-AggregateCpuSeconds {
	param(
		[object[]]$Processes
	)

	$total = 0.0
	foreach ($proc in $Processes) {
		try {
			$runtimeProc = Get-Process -Id $proc.ProcessId -ErrorAction Stop
			$total += [double]$runtimeProc.CPU
		} catch {
			continue
		}
	}
	return $total
}

function Stop-TrainingProcesses {
	param(
		[object[]]$Processes
	)

	foreach ($proc in $Processes) {
		try {
			Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
		} catch {
			continue
		}
	}
}

function Start-TrainingJob {
	param(
		[hashtable]$Job,
		[string]$JobLogDir,
		[string]$LogPath
	)

	$stdoutPath = Join-Path $JobLogDir ($Job.Name + '.stdout.log')
	$stderrPath = Join-Path $JobLogDir ($Job.Name + '.stderr.log')
	$args = Build-TrainLoopArgumentList -GodotPath $Job.GodotPath -Iterations $Job.Iterations -Generations $Job.Generations -Epochs $Job.Epochs -ModelDir $Job.ModelDir
	$argDisplay = ($args | ForEach-Object {
		if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
	}) -join ' '
	Write-WatchdogLog -LogPath $LogPath -Message 'restarting training job' -Context @{
		job = $Job.Name
		command = ('"{0}" {1}' -f $Job.GitBashPath, $argDisplay)
		stdout = $stdoutPath
		stderr = $stderrPath
	}

	$process = Start-Process -FilePath $Job.GitBashPath -ArgumentList $args -WorkingDirectory $WorkspaceRoot -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru -WindowStyle Hidden
	return $process
}

function Save-WatchdogState {
	param(
		[string]$StatePath,
		[hashtable]$State
	)

	$json = $State | ConvertTo-Json -Depth 8
	Set-Content -Path $StatePath -Value $json -Encoding UTF8
}

function Load-WatchdogState {
	param(
		[string]$StatePath
	)

	if (-not (Test-Path -LiteralPath $StatePath)) {
		return @{}
	}
	try {
		$raw = Get-Content -Path $StatePath -Raw
		if ([string]::IsNullOrWhiteSpace($raw)) {
			return @{}
		}
		$parsed = ConvertFrom-Json -InputObject $raw -Depth 8 -AsHashtable
		if ($parsed) {
			return $parsed
		}
	} catch {
		return @{}
	}
	return @{}
}

function Invoke-TrainingWatchdog {
	if ([string]::IsNullOrWhiteSpace($LogDir)) {
		$script:LogDir = Join-Path $WorkspaceRoot 'logs\training_watchdog'
	}
	New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

	$logPath = Join-Path $LogDir ('watchdog_' + (Get-Date -Format 'yyyyMMdd') + '.log')
	$statePath = Join-Path $LogDir 'watchdog_state.json'
	$runsRoot = Join-Path $env:APPDATA 'Godot\app_userdata\PTCG Train\training_data\runs'

	$jobs = @(
		@{
			Name = 'smoke'
			ProcessMatch = $SmokeModelDir
			ModelDir = $SmokeModelDir
			ModelDirFullPath = Join-Path $WorkspaceRoot ($SmokeModelDir.TrimStart('.','/').Replace('/','\'))
			Iterations = $SmokeIterations
			Generations = $SmokeGenerations
			Epochs = $SmokeEpochs
			RestartOnExit = $false
			InactivityThresholdMinutes = $InactivityThresholdMinutes
			WatchPaths = @()
			GitBashPath = $GitBashPath
			GodotPath = $GodotPath
		},
		@{
			Name = 'overnight'
			ProcessMatch = $OvernightModelDir
			ModelDir = $OvernightModelDir
			ModelDirFullPath = Join-Path $WorkspaceRoot ($OvernightModelDir.TrimStart('.','/').Replace('/','\'))
			Iterations = $OvernightIterations
			Generations = $OvernightGenerations
			Epochs = $OvernightEpochs
			RestartOnExit = $true
			InactivityThresholdMinutes = $InactivityThresholdMinutes
			WatchPaths = @()
			GitBashPath = $GitBashPath
			GodotPath = $GodotPath
		}
	)

	foreach ($job in $jobs) {
		$job.WatchPaths = @($job.ModelDirFullPath, $runsRoot)
	}

	$state = Load-WatchdogState -StatePath $statePath
	if (-not $state.ContainsKey('jobs')) {
		$state['jobs'] = @{}
	}
	if (-not $state.ContainsKey('last_hourly_summary_at')) {
		$state['last_hourly_summary_at'] = $null
	}

	Write-WatchdogLog -LogPath $logPath -Message 'training watchdog started' -Context @{
		workspace = $WorkspaceRoot
		check_minutes = $CheckIntervalMinutes
		hourly_summary_minutes = $HourlySummaryMinutes
		inactivity_minutes = $InactivityThresholdMinutes
	}

	while ($true) {
	$now = Get-Date
	$processes = Get-TrainingProcesses
	$hourlyDue = $false
	if ($state['last_hourly_summary_at']) {
		$lastHourly = [datetime]$state['last_hourly_summary_at']
		$hourlyDue = (($now - $lastHourly).TotalMinutes -ge $HourlySummaryMinutes)
	} else {
		$hourlyDue = $true
	}

	foreach ($job in $jobs) {
		$jobState = @{}
		if ($state['jobs'].ContainsKey($job.Name)) {
			$jobState = $state['jobs'][$job.Name]
		}

		$matched = Get-MatchingTrainingProcesses -Processes $processes -ProcessMatch $job.ProcessMatch
		$cpuTotal = Get-AggregateCpuSeconds -Processes $matched
		$lastCpuTotal = 0.0
		if ($jobState.ContainsKey('last_cpu_total')) {
			$lastCpuTotal = [double]$jobState['last_cpu_total']
		}
		$cpuDelta = [math]::Max(0.0, $cpuTotal - $lastCpuTotal)

		$lastActivityUtc = Get-LatestWriteTimeUtc -Paths $job.WatchPaths
		$lastActivityAt = $null
		if ($lastActivityUtc) {
			$lastActivityAt = [datetime]::SpecifyKind($lastActivityUtc, [System.DateTimeKind]::Utc).ToLocalTime()
		}

		$lastHealthyAt = $null
		if ($jobState.ContainsKey('last_healthy_at') -and $jobState['last_healthy_at']) {
			$lastHealthyAt = [datetime]$jobState['last_healthy_at']
		}

		$summary = Get-JobHealthSummary -JobName $job.Name -ProcessCount $matched.Count -CpuDeltaSeconds $cpuDelta -LastActivityAt $lastActivityAt -LastHealthyAt $lastHealthyAt -Now $now -InactivityThresholdMinutes $job.InactivityThresholdMinutes -RestartOnExit $job.RestartOnExit
		if ($summary.EffectiveHealthyAt) {
			$lastHealthyAt = $summary.EffectiveHealthyAt
		}

		$lastRestartAt = $null
		if ($jobState.ContainsKey('last_restart_at') -and $jobState['last_restart_at']) {
			$lastRestartAt = [datetime]$jobState['last_restart_at']
		}
		$restartCount = 0
		if ($jobState.ContainsKey('restart_count')) {
			$restartCount = [int]$jobState['restart_count']
		}

		$previousState = ''
		if ($jobState.ContainsKey('last_state')) {
			$previousState = [string]$jobState['last_state']
		}

		$minutesSinceHealthy = ''
		if ($lastHealthyAt) {
			$minutesSinceHealthy = [math]::Round(($now - $lastHealthyAt).TotalMinutes, 1)
		}

		$action = 'none'
		if (($summary.State -eq 'missing' -or $summary.State -eq 'stalled') -and $job.RestartOnExit) {
			$cooldownExpired = $true
			if ($lastRestartAt) {
				$cooldownExpired = (($now - $lastRestartAt).TotalMinutes -ge $RestartCooldownMinutes)
			}
			if ($cooldownExpired) {
				if ($matched.Count -gt 0) {
					Stop-TrainingProcesses -Processes $matched
					$action = 'killed_stalled_processes'
				}
				$jobLogDir = Join-Path $LogDir $job.Name
				New-Item -ItemType Directory -Force -Path $jobLogDir | Out-Null
				$startedProcess = Start-TrainingJob -Job $job -JobLogDir $jobLogDir -LogPath $logPath
				$restartCount += 1
				$lastRestartAt = $now
				$lastHealthyAt = $now
				$action = if ($action -eq 'killed_stalled_processes') { 'killed_and_restarted' } else { 'restarted' }
				$summary = [pscustomobject]@{
					JobName = $job.Name
					State = 'running'
					Reason = 'restart issued by watchdog'
					EffectiveHealthyAt = $now
				}
			}
		}

		$shouldLog = $hourlyDue -or ($summary.State -ne $previousState) -or ($action -ne 'none')
		if ($shouldLog) {
			Write-WatchdogLog -LogPath $logPath -Message 'training job status' -Context @{
				job = $job.Name
				state = $summary.State
				reason = $summary.Reason
				process_count = $matched.Count
				cpu_total = [math]::Round($cpuTotal, 2)
				cpu_delta = [math]::Round($cpuDelta, 2)
				last_activity = $(if ($lastActivityAt) { $lastActivityAt.ToString('yyyy-MM-dd HH:mm:ss') } else { 'none' })
				minutes_since_healthy = $(if ($minutesSinceHealthy -ne '') { $minutesSinceHealthy } else { 'n/a' })
				restarts = $restartCount
				action = $action
				model_dir = $job.ModelDir
			}
		}

		$state['jobs'][$job.Name] = @{
			last_state = $summary.State
			last_reason = $summary.Reason
			last_cpu_total = $cpuTotal
			last_activity_at = $(if ($lastActivityAt) { $lastActivityAt.ToString('o') } else { $null })
			last_healthy_at = $(if ($lastHealthyAt) { $lastHealthyAt.ToString('o') } else { $null })
			last_restart_at = $(if ($lastRestartAt) { $lastRestartAt.ToString('o') } else { $null })
			restart_count = $restartCount
		}
	}

	if ($hourlyDue) {
		$state['last_hourly_summary_at'] = $now.ToString('o')
	}
	Save-WatchdogState -StatePath $statePath -State $state

	if ($RunOnce) {
		break
	}
	Start-Sleep -Seconds ($CheckIntervalMinutes * 60)
}
}

if ($MyInvocation.InvocationName -ne '.') {
	Invoke-TrainingWatchdog
}
