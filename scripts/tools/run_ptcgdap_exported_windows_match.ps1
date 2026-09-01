[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string]$ExportManifestPath,
	[string]$OutputPath = "",
	[ValidateRange(1, 20)]
	[int]$Games = 3,
	[int]$SeedBase = 84600,
	[ValidateRange(100, 2000)]
	[int]$MaxSteps = 700,
	[ValidateRange(10000, 1800000)]
	[int]$TimeoutMsec = 1800000
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptRoot "..\..")).Path
$allowedRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".tmp\ptcgdap_device_release"))

function Test-PathWithin {
	param([string]$Path, [string]$Root)
	$fullPath = [System.IO.Path]::GetFullPath($Path)
	$fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
	$prefix = $fullRoot + [System.IO.Path]::DirectorySeparatorChar
	return $fullPath.Equals($fullRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

$resolvedManifest = (Resolve-Path -LiteralPath $ExportManifestPath).Path
if (-not (Test-PathWithin -Path $resolvedManifest -Root $allowedRoot)) {
	throw "ExportManifestPath must stay under $allowedRoot"
}
$manifest = Get-Content -Raw -LiteralPath $resolvedManifest | ConvertFrom-Json
if ($manifest.document_type -ne "author_strategy_device_export_manifest_v1" -or $manifest.schema_version -ne 1) {
	throw "Unsupported export manifest contract"
}
$exportDirectory = [System.IO.Path]::GetFullPath([string]$manifest.output_directory)
if (-not (Test-PathWithin -Path $exportDirectory -Root $allowedRoot)) {
	throw "Export output_directory escapes the allowed root"
}
if (-not [System.IO.Path]::GetFullPath((Split-Path -Parent $resolvedManifest)).Equals($exportDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
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
	$OutputPath = Join-Path $exportDirectory "windows-export-match-development.json"
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
$startInfo.Arguments = "--headless -- --ptcgdap-development-export-match --games=$Games --seed-base=$SeedBase --max-steps=$MaxSteps"
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
$peakWorkingSetBytes = [int64]0
$observedChildProcessIds = [System.Collections.Generic.HashSet[int]]::new()
$observedNetworkEndpoints = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$nextAuditMsec = 0
$timedOut = $false
while (-not $process.WaitForExit(25)) {
	$process.Refresh()
	$peakWorkingSetBytes = [Math]::Max($peakWorkingSetBytes, [int64]$process.WorkingSet64)
	if ($clock.ElapsedMilliseconds -ge $nextAuditMsec) {
		$nextAuditMsec = $clock.ElapsedMilliseconds + 250
		Get-CimInstance Win32_Process -Filter ("ParentProcessId={0}" -f $process.Id) -ErrorAction SilentlyContinue | ForEach-Object {
			[void]$observedChildProcessIds.Add([int]$_.ProcessId)
		}
		if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
			Get-NetTCPConnection -OwningProcess $process.Id -ErrorAction SilentlyContinue | ForEach-Object {
				[void]$observedNetworkEndpoints.Add("$($_.State):$($_.RemoteAddress):$($_.RemotePort)")
			}
		}
	}
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
if ($timedOut) {
	throw "Exported executable exceeded the complete-match timeout; see $stdoutPath and $stderrPath"
}

$prefix = "PTCGDAP_WINDOWS_EXPORT_MATCH="
$reportLine = @($stdout -split "`r?`n" | Where-Object { $_.StartsWith($prefix, [System.StringComparison]::Ordinal) })
if ($reportLine.Count -ne 1) {
	throw "Exported executable did not emit exactly one complete-match report; see $stdoutPath"
}
$matchReport = $reportLine[0].Substring($prefix.Length) | ConvertFrom-Json
if ($exitCode -ne 0 -or -not [bool]$matchReport.is_clean -or -not [bool]$matchReport.complete_match_finished) {
	throw "Exported executable complete-match run failed with exit code $exitCode; see $stdoutPath and $stderrPath"
}
if (-not [bool]$matchReport.standalone_export -or [string]$matchReport.runtime_platform -ne "Windows") {
	throw "Complete-match report did not come from a standalone Windows export"
}
if ([bool]$matchReport.production_ready -or [bool]$matchReport.a5_claimed -or [bool]$matchReport.ui_driven -or [bool]$matchReport.network_blocked) {
	throw "Development complete-match report overstated its acceptance scope"
}
if ([int]$matchReport.totals.policy_calls -lt 1 -or [int]$matchReport.totals.policy_calls -ne [int]$matchReport.totals.policy_successes) {
	throw "Complete-match policy accounting is invalid"
}
foreach ($key in @("policy_errors", "invalid_outputs", "same_window_fallbacks", "classic_fallbacks", "external_process_attempts", "engine_rejections")) {
	if ([int]$matchReport.totals.$key -ne 0) { throw "Complete-match report contains non-zero $key" }
}
if ([int]$matchReport.totals.engine_commits -lt 1) { throw "Complete-match report has no engine commits" }

$childIds = @($observedChildProcessIds | Sort-Object)
$networkEndpoints = @($observedNetworkEndpoints | Sort-Object)
$wrapper = [ordered]@{
	document_type = "author_strategy_windows_export_match_execution_v1"
	schema_version = 1
	generated_at = (Get-Date).ToUniversalTime().ToString("o")
	development_only = $true
	production_ready = $false
	a5_claimed = $false
	ui_driven = $false
	network_blocked = $false
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
		peak_working_set_mib = [int64][Math]::Ceiling($peakWorkingSetBytes / 1MB)
		observed_child_process_ids = $childIds
		observed_network_endpoints = $networkEndpoints
		defensive_loopback_proxy_environment = $true
		stdout_sha256 = (Get-FileHash -LiteralPath $stdoutPath -Algorithm SHA256).Hash.ToUpperInvariant()
		stderr_sha256 = (Get-FileHash -LiteralPath $stderrPath -Algorithm SHA256).Hash.ToUpperInvariant()
	}
	match = $matchReport
	claims = [ordered]@{
		exported_executable_complete_rules_match = $true
		external_process_attempts_zero = ([int]$matchReport.totals.external_process_attempts -eq 0)
		observed_child_processes_zero = ($childIds.Count -eq 0)
		observed_network_connections_zero = ($networkEndpoints.Count -eq 0)
		exported_exe_airplane_ui_match = $false
		production_signature = $false
		approved_device_profile = $false
		formal_a5 = $false
	}
	limitations = @(
		"Development-only exported EXE headless match driver; the ordinary BattleSetup UI was not used.",
		"No OS-level network block was installed, so zero observed connections is not an airplane-mode proof.",
		"Production signing, approved device thresholds, rollback drill, and A5 remain closed."
	)
}
[System.IO.File]::WriteAllText($resolvedOutput, ($wrapper | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($false))
Write-Output $resolvedOutput
