[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string]$ExportManifestPath,
	[string]$OutputPath = "",
	[switch]$ProductionDeviceCanary,
	[ValidateRange(10000, 300000)]
	[int]$TimeoutMsec = 60000
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptRoot "..\..")).Path
$allowedRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".tmp\ptcgdap_device_release"))

function Test-PathWithin {
	param([string]$Path, [string]$Root)
	$fullPath = [System.IO.Path]::GetFullPath($Path)
	$fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd(
		[System.IO.Path]::DirectorySeparatorChar,
		[System.IO.Path]::AltDirectorySeparatorChar
	)
	$prefix = $fullRoot + [System.IO.Path]::DirectorySeparatorChar
	return $fullPath.Equals($fullRoot, [System.StringComparison]::OrdinalIgnoreCase) -or `
		$fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

$resolvedManifest = (Resolve-Path -LiteralPath $ExportManifestPath).Path
if (-not (Test-PathWithin -Path $resolvedManifest -Root $allowedRoot)) {
	throw "ExportManifestPath must stay under $allowedRoot"
}
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $resolvedManifest | ConvertFrom-Json
if ($manifest.document_type -ne "author_strategy_device_export_manifest_v1" -or $manifest.schema_version -ne 1) {
	throw "Unsupported export manifest contract"
}
$exportDirectory = [System.IO.Path]::GetFullPath([string]$manifest.output_directory)
if (-not (Test-PathWithin -Path $exportDirectory -Root $allowedRoot)) {
	throw "Export output_directory escapes the allowed root"
}
if (-not [System.IO.Path]::GetFullPath((Split-Path -Parent $resolvedManifest)).Equals(
	$exportDirectory,
	[System.StringComparison]::OrdinalIgnoreCase
)) {
	throw "Export manifest is not located in its declared output_directory"
}
$executables = @($manifest.outputs | Where-Object { $_.platform -eq "windows" -and $_.kind -eq "executable" })
if ($executables.Count -ne 1) { throw "Export manifest must contain exactly one Windows executable" }
$executablePath = [System.IO.Path]::GetFullPath([string]$executables[0].path)
if (-not (Test-PathWithin -Path $executablePath -Root $exportDirectory) -or -not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
	throw "Exported Windows executable is missing or escapes output_directory"
}
$executableItem = Get-Item -LiteralPath $executablePath
$executableHash = (Get-FileHash -LiteralPath $executablePath -Algorithm SHA256).Hash.ToUpperInvariant()
if ([int64]$executables[0].bytes -ne $executableItem.Length -or [string]$executables[0].sha256 -cne $executableHash) {
	throw "Exported executable no longer matches the export manifest"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
	$OutputPath = Join-Path $exportDirectory "author-strategy-rollback-drill.json"
}
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
if (-not (Test-PathWithin -Path $resolvedOutput -Root $exportDirectory)) {
	throw "OutputPath must stay under the export output_directory"
}
if (Test-Path -LiteralPath $resolvedOutput) { throw "Refusing to overwrite existing output: $resolvedOutput" }
$artifactRoot = Join-Path (Split-Path -Parent $resolvedOutput) (([System.IO.Path]::GetFileNameWithoutExtension($resolvedOutput)) + ".artifacts")
if (Test-Path -LiteralPath $artifactRoot) { throw "Refusing to overwrite existing artifact directory: $artifactRoot" }
New-Item -ItemType Directory -Path $artifactRoot | Out-Null
$appData = Join-Path $artifactRoot "appdata"
$localAppData = Join-Path $artifactRoot "localappdata"
New-Item -ItemType Directory -Path $appData, $localAppData | Out-Null
$stdoutPath = Join-Path $artifactRoot "stdout.log"
$stderrPath = Join-Path $artifactRoot "stderr.log"

$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $executablePath
$startInfo.WorkingDirectory = $exportDirectory
$canaryArg = if ($ProductionDeviceCanary) { " --ptcgdap-production-device-canary" } else { "" }
$startInfo.Arguments = "--headless -- --ptcgdap-development-export-match$canaryArg --ptcgdap-disable-author-strategy-mode --games=1 --seed-base=84690 --max-steps=700"
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.EnvironmentVariables["APPDATA"] = $appData
$startInfo.EnvironmentVariables["LOCALAPPDATA"] = $localAppData
$startInfo.EnvironmentVariables["HTTP_PROXY"] = "http://127.0.0.1:9"
$startInfo.EnvironmentVariables["HTTPS_PROXY"] = "http://127.0.0.1:9"
$startInfo.EnvironmentVariables["ALL_PROXY"] = "http://127.0.0.1:9"
$startInfo.EnvironmentVariables["NO_PROXY"] = ""

$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $startInfo
$clock = [System.Diagnostics.Stopwatch]::StartNew()
if (-not $process.Start()) { throw "Unable to start exported executable" }
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$timedOut = $false
while (-not $process.WaitForExit(25)) {
	if ($clock.ElapsedMilliseconds -ge $TimeoutMsec) {
		$process.Kill()
		$timedOut = $true
		break
	}
}
$process.WaitForExit()
$clock.Stop()
$stdout = $stdoutTask.Result
$stderr = $stderrTask.Result
[System.IO.File]::WriteAllText($stdoutPath, $stdout, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($stderrPath, $stderr, [System.Text.UTF8Encoding]::new($false))
$exitCode = $process.ExitCode
$process.Dispose()
if ($timedOut) { throw "Rollback drill timed out; see $stdoutPath and $stderrPath" }

$prefix = "PTCGDAP_WINDOWS_EXPORT_MATCH="
$reportLines = @($stdout -split "`r?`n" | Where-Object { $_.StartsWith($prefix, [System.StringComparison]::Ordinal) })
if ($reportLines.Count -ne 1) {
	throw "Rollback drill did not emit exactly one match report; see $stdoutPath"
}
$matchReport = $reportLines[0].Substring($prefix.Length) | ConvertFrom-Json
$failures = @($matchReport.per_game | ForEach-Object { [string]$_.failure })
$accepted = (
	$exitCode -eq 1 -and
	-not [bool]$matchReport.complete_match_finished -and
	-not [bool]$matchReport.is_clean -and
	$failures.Count -eq 1 -and
	$failures[0] -eq "author_strategy_feature_disabled" -and
	[int]$matchReport.totals.policy_calls -eq 0 -and
	[int]$matchReport.totals.policy_successes -eq 0 -and
	[int]$matchReport.totals.engine_commits -eq 0 -and
	[int]$matchReport.totals.external_process_attempts -eq 0
)
$report = [ordered]@{
	document_type = "author_strategy_windows_feature_rollback_execution_v1"
	schema_version = 1
	generated_at = (Get-Date).ToUniversalTime().ToString("o")
	accepted = $accepted
	failed_closed_before_execution = $accepted
	policy_calls = [int]$matchReport.totals.policy_calls
	engine_commits = [int]$matchReport.totals.engine_commits
	user_packages_deleted = $false
	device_canary_requested = [bool]$ProductionDeviceCanary
	development_only = (-not $ProductionDeviceCanary)
	production_rollback_claimed = [bool]$ProductionDeviceCanary
	network_isolation_proven = $false
	export = [ordered]@{
		manifest_path = $resolvedManifest
		manifest_sha256 = (Get-FileHash -LiteralPath $resolvedManifest -Algorithm SHA256).Hash.ToUpperInvariant()
		executable_path = $executablePath
		executable_bytes = [int64]$executableItem.Length
		executable_sha256 = $executableHash
	}
	process = [ordered]@{
		exit_code = $exitCode
		elapsed_msec = [int64]$clock.ElapsedMilliseconds
		stdout_sha256 = (Get-FileHash -LiteralPath $stdoutPath -Algorithm SHA256).Hash.ToUpperInvariant()
		stderr_sha256 = (Get-FileHash -LiteralPath $stderrPath -Algorithm SHA256).Hash.ToUpperInvariant()
	}
	match = $matchReport
	claims = [ordered]@{
		failed_closed_before_policy = $accepted
		user_package_deletion_attempted = $false
		active_match_hot_switch_tested_by_focused_lane = $true
		production_rollback = $false
	}
}
$json = $report | ConvertTo-Json -Depth 100
$stream = [System.IO.File]::Open($resolvedOutput, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
try {
	$bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($json + "`n")
	$stream.Write($bytes, 0, $bytes.Length)
} finally {
	$stream.Dispose()
}
if (-not $accepted) { throw "Rollback drill did not fail closed as required; see $resolvedOutput" }
Write-Output $resolvedOutput
