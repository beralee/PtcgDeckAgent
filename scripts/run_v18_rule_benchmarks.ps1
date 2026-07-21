[CmdletBinding()]
param(
	[Alias("deck-ids")]
	[string[]]$DeckIds = @(
		"18000230",
		"18000625",
		"800015734",
		"800015934",
		"800016834",
		"800017047",
		"800017097",
		"800017407",
		"800017631",
		"800017643",
		"800018105",
		"800018359",
		"800018497",
		"800018498",
		"800018499",
		"800018500",
		"800018501",
		"800018502",
		"800018509",
		"800018539",
		"800018543",
		"800018880",
		"800019125",
		"800033475"
	),
	[ValidateRange(0, 10)]
	[int]$Iteration = 0,
	[Alias("seed-base")]
	[ValidateRange(0, [int]::MaxValue)]
	[int]$SeedBase = 15000,
	[Alias("output-dir")]
	[string]$OutputDir = "",
	[Alias("only-missing")]
	[switch]$OnlyMissing,
	[switch]$Force,
	[string]$GodotExe = "",
	[string]$PythonExe = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$anchorId = 575720
$games = 100
$maxSteps = 200
$modes = @("normal", "strong")

function ConvertTo-DeckIdList {
	param([string[]]$Values)

	$parsedIds = [System.Collections.Generic.List[int]]::new()
	$seen = @{}
	foreach ($rawValue in $Values) {
		foreach ($rawToken in ([string]$rawValue -split ",")) {
			$token = $rawToken.Trim()
			if ([string]::IsNullOrWhiteSpace($token)) {
				continue
			}

			$parsed = 0
			if (-not [int]::TryParse($token, [ref]$parsed) -or $parsed -le 0) {
				throw "Invalid deck id '$token'. DeckIds must contain positive integers."
			}
			if ($seen.ContainsKey($parsed)) {
				throw "Duplicate deck id '$parsed'."
			}
			$seen[$parsed] = $true
			$parsedIds.Add($parsed)
		}
	}

	if ($parsedIds.Count -eq 0) {
		throw "DeckIds must contain at least one deck id."
	}
	return @($parsedIds)
}

function Resolve-Executable {
	param(
		[string]$Value,
		[string]$Label
	)

	if (Test-Path -LiteralPath $Value -PathType Leaf) {
		return (Resolve-Path -LiteralPath $Value).Path
	}

	$command = Get-Command -Name $Value -ErrorAction SilentlyContinue | Select-Object -First 1
	if ($null -eq $command) {
		throw "$Label executable not found: $Value"
	}
	if (-not [string]::IsNullOrWhiteSpace($command.Source)) {
		return $command.Source
	}
	return $command.Definition
}

function ConvertTo-GodotPath {
	param([string]$Path)
	return $Path.Replace("\", "/")
}

function Write-RunEvent {
	param(
		[string]$Path,
		[hashtable]$Event
	)

	$Event["timestamp_utc"] = [DateTime]::UtcNow.ToString("o")
	$line = $Event | ConvertTo-Json -Compress -Depth 8
	Add-Content -LiteralPath $Path -Value $line -Encoding UTF8
}

if ($OnlyMissing -and $Force) {
	throw "OnlyMissing and Force cannot be used together."
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$acceptanceTool = Join-Path $projectRoot "tools\v18_rule_acceptance.py"
if (-not (Test-Path -LiteralPath $acceptanceTool -PathType Leaf)) {
	throw "Acceptance tool not found: $acceptanceTool"
}

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
	$GodotExe = if ([string]::IsNullOrWhiteSpace($env:GODOT_EXE)) {
		"D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe"
	} else {
		$env:GODOT_EXE
	}
}
if ([string]::IsNullOrWhiteSpace($PythonExe)) {
	$PythonExe = if ([string]::IsNullOrWhiteSpace($env:PYTHON_EXE)) {
		"python"
	} else {
		$env:PYTHON_EXE
	}
}

$resolvedGodotExe = Resolve-Executable -Value $GodotExe -Label "Godot"
$resolvedPythonExe = Resolve-Executable -Value $PythonExe -Label "Python"
$deckIdList = @(ConvertTo-DeckIdList -Values $DeckIds)
$roundLabel = "{0:D2}" -f $Iteration

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
	$OutputDir = Join-Path $projectRoot "tmp\v18_rule_benchmarks"
} elseif (-not [IO.Path]::IsPathRooted($OutputDir)) {
	$OutputDir = Join-Path $projectRoot $OutputDir
}
$OutputDir = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($OutputDir))
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$runStamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
$statusPath = Join-Path $OutputDir "v18_rule_benchmark_run_r${roundLabel}_s${SeedBase}_n${games}_${runStamp}_pid$PID.jsonl"
$plannedResults = [System.Collections.Generic.List[object]]::new()
foreach ($deckId in $deckIdList) {
	foreach ($mode in $modes) {
		$baseName = "v18_${deckId}_${mode}_r${roundLabel}_s${SeedBase}_n${games}"
		$plannedResults.Add([pscustomobject]@{
			deck_id = $deckId
			mode = $mode
			result_path = Join-Path $OutputDir "${baseName}.json"
			log_path = Join-Path $OutputDir "${baseName}.log"
		})
	}
}

$policy = if ($Force) { "force" } else { "only_missing" }
Write-RunEvent -Path $statusPath -Event ([ordered]@{
	event = "run_started"
	iteration = $Iteration
	seed_base = $SeedBase
	deck_ids = $deckIdList
	modes = $modes
	games = $games
	anchor_id = $anchorId
	max_steps = $maxSteps
	policy = $policy
	output_dir = $OutputDir
})

$completedCount = 0
$skippedCount = 0
$failedCount = 0

foreach ($result in $plannedResults) {
	$resultPath = [string]$result.result_path
	$logPath = [string]$result.log_path
	$exists = Test-Path -LiteralPath $resultPath -PathType Leaf
	if ($exists -and -not $Force) {
		$skippedCount += 1
		Write-Host "[skip] deck=$($result.deck_id) mode=$($result.mode) result=$resultPath"
		Write-RunEvent -Path $statusPath -Event ([ordered]@{
			event = "benchmark_result"
			deck_id = $result.deck_id
			mode = $result.mode
			status = "skipped_existing"
			exit_code = $null
			result_path = $resultPath
			log_path = $logPath
		})
		continue
	}

	if ($exists -and $Force) {
		Remove-Item -LiteralPath $resultPath -Force
	}

	$godotArgs = @(
		"--headless",
		"--disable-crash-handler",
		"--log-file",
		(ConvertTo-GodotPath -Path $logPath),
		"--path",
		(ConvertTo-GodotPath -Path $projectRoot),
		"res://scripts/training/run_deck_benchmark.tscn",
		"--",
		"--deck-id=$($result.deck_id)",
		"--anchor-id=$anchorId",
		"--games=$games",
		"--seed-base=$SeedBase",
		"--max-steps=$maxSteps",
		"--deck-decision-mode=rules_only",
		"--anchor-decision-mode=rules_only"
	)
	if ($result.mode -eq "strong") {
		$godotArgs += "--deck-strong-fixed-opening"
	}
	$godotArgs += "--json-output=$(ConvertTo-GodotPath -Path $resultPath)"

	Write-Host "[run] deck=$($result.deck_id) mode=$($result.mode) result=$resultPath"
	$processExitCode = -1
	$processError = ""
	try {
		& $resolvedGodotExe @godotArgs
		$processExitCode = [int]$LASTEXITCODE
	} catch {
		$processError = $_.Exception.Message
		if ($_.Exception.PSObject.Properties.Name -contains "ExitCode") {
			$processExitCode = [int]$_.Exception.ExitCode
		}
	}

	$outputExists = Test-Path -LiteralPath $resultPath -PathType Leaf
	$status = "completed"
	if ($processExitCode -ne 0) {
		$status = "failed_process"
	} elseif (-not $outputExists) {
		$status = "failed_missing_output"
	}

	if ($status -eq "completed") {
		$completedCount += 1
	} else {
		$failedCount += 1
		Write-Warning "Benchmark failed: deck=$($result.deck_id) mode=$($result.mode) status=$status exit_code=$processExitCode"
	}

	Write-RunEvent -Path $statusPath -Event ([ordered]@{
		event = "benchmark_result"
		deck_id = $result.deck_id
		mode = $result.mode
		status = $status
		exit_code = $processExitCode
		error = $processError
		output_exists = $outputExists
		result_path = $resultPath
		log_path = $logPath
	})
}

$acceptanceArgs = @($acceptanceTool)
foreach ($result in $plannedResults) {
	$modeFlag = if ($result.mode -eq "strong") { "--strong" } else { "--normal" }
	$acceptanceArgs += $modeFlag
	$acceptanceArgs += [string]$result.result_path
}
$acceptanceArgs += "--deck-ids"
$acceptanceArgs += ($deckIdList -join ",")
$acceptanceArgs += "--games"
$acceptanceArgs += [string]$games

Write-Host "[acceptance] completed=$completedCount skipped=$skippedCount failed=$failedCount"
$acceptanceExitCode = 2
$acceptanceError = ""
try {
	& $resolvedPythonExe @acceptanceArgs
	$acceptanceExitCode = [int]$LASTEXITCODE
} catch {
	$acceptanceError = $_.Exception.Message
	if ($_.Exception.PSObject.Properties.Name -contains "ExitCode") {
		$acceptanceExitCode = [int]$_.Exception.ExitCode
	}
}

Write-RunEvent -Path $statusPath -Event ([ordered]@{
	event = "acceptance_finished"
	exit_code = $acceptanceExitCode
	error = $acceptanceError
	completed = $completedCount
	skipped = $skippedCount
	failed = $failedCount
})

Write-Host "Run status: $statusPath"
Write-Host "Acceptance exit code: $acceptanceExitCode"
exit $acceptanceExitCode
