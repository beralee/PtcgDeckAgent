[CmdletBinding(DefaultParameterSetName = "Evaluate")]
param(
	[Parameter(Mandatory = $true, ParameterSetName = "Evaluate")]
	[string]$ReportPath,
	[Parameter(Mandatory = $true, ParameterSetName = "Probe")]
	[string]$ExportManifestPath,
	[string]$PythonExe = "python",
	[string]$OutputPath = "",
	[Parameter(ParameterSetName = "Probe")]
	[ValidateRange(1000, 120000)]
	[int]$ProbeTimeoutMsec = 30000
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptRoot "..\..")).Path
$allowedProbeRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".tmp\ptcgdap_device_release"))

function Test-PathWithin {
	param([string]$Path, [string]$Root)
	$fullPath = [System.IO.Path]::GetFullPath($Path)
	$fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
	$rootPrefix = $fullRoot + [System.IO.Path]::DirectorySeparatorChar
	return $fullPath.Equals($fullRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $fullPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Invoke-FormalReportEvaluation {
	$resolvedReport = (Resolve-Path -LiteralPath $ReportPath).Path
	if ([string]::IsNullOrWhiteSpace($OutputPath)) {
		$script:OutputPath = [System.IO.Path]::ChangeExtension($resolvedReport, ".evaluation.json")
	}
	$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
	$program = @'
import json
from pathlib import Path
import sys
root = Path(sys.argv[1])
report_path = Path(sys.argv[2])
output_path = Path(sys.argv[3])
sys.path.insert(0, str(root))
from scripts.ai.ptcgdap.author_strategy_release import AuthorStrategyReleaseGate
from scripts.ai.ptcgdap.source_lock import load_json_strict
gate = AuthorStrategyReleaseGate(root)
result = gate.evaluate_device_report(load_json_strict(report_path))
output_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, ensure_ascii=False))
raise SystemExit(0 if result['accepted'] else 2)
'@
	& $PythonExe -c $program $projectRoot $resolvedReport $resolvedOutput
	$exitCode = $LASTEXITCODE
	if ($exitCode -eq 2) { throw "Device evidence was rejected; see $resolvedOutput" }
	if ($exitCode -ne 0) { throw "Device evidence evaluation failed with exit code $exitCode" }
	Write-Output $resolvedOutput
}

function Invoke-WindowsProvisionalProbe {
	$resolvedManifest = (Resolve-Path -LiteralPath $ExportManifestPath).Path
	if (-not (Test-PathWithin -Path $resolvedManifest -Root $allowedProbeRoot)) {
		throw "ExportManifestPath must stay under $allowedProbeRoot"
	}
	$manifest = Get-Content -Raw -LiteralPath $resolvedManifest | ConvertFrom-Json
	if ($manifest.document_type -ne "author_strategy_device_export_manifest_v1" -or $manifest.schema_version -ne 1) {
		throw "Unsupported export manifest contract"
	}
	$exportDirectory = [System.IO.Path]::GetFullPath([string]$manifest.output_directory)
	if (-not (Test-PathWithin -Path $exportDirectory -Root $allowedProbeRoot)) {
		throw "Export output_directory must stay under $allowedProbeRoot"
	}
	if (-not [System.IO.Path]::GetFullPath((Split-Path -Parent $resolvedManifest)).Equals($exportDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
		throw "Export manifest is not located in its declared output_directory"
	}
	if ([string]::IsNullOrWhiteSpace($OutputPath)) {
		$script:OutputPath = Join-Path $exportDirectory "windows-provisional-probe.json"
	}
	$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
	if (-not (Test-PathWithin -Path $resolvedOutput -Root $allowedProbeRoot)) {
		throw "OutputPath must stay under $allowedProbeRoot"
	}
	if (Test-Path -LiteralPath $resolvedOutput) { throw "Refusing to overwrite existing output: $resolvedOutput" }

	$verifiedOutputs = @()
	foreach ($entry in @($manifest.outputs)) {
		if ($entry.platform -ne "windows") { throw "Provisional probe accepts Windows export outputs only" }
		$entryPath = [System.IO.Path]::GetFullPath([string]$entry.path)
		if (-not (Test-PathWithin -Path $entryPath -Root $exportDirectory)) { throw "Export output escapes output_directory: $entryPath" }
		if (-not (Test-Path -LiteralPath $entryPath -PathType Leaf)) { throw "Export output is missing: $entryPath" }
		$item = Get-Item -LiteralPath $entryPath
		$actualHash = (Get-FileHash -LiteralPath $entryPath -Algorithm SHA256).Hash.ToUpperInvariant()
		if ([int64]$entry.bytes -ne $item.Length -or [string]$entry.sha256 -cne $actualHash) {
			throw "Export output no longer matches its manifest: $entryPath"
		}
		$verifiedOutputs += [pscustomobject][ordered]@{
			kind = [string]$entry.kind
			platform = "windows"
			path = $entryPath
			bytes = [int64]$item.Length
			sha256 = $actualHash
		}
	}
	$executables = @($verifiedOutputs | Where-Object { $_.kind -eq "executable" })
	if ($executables.Count -ne 1) { throw "Export manifest must contain exactly one Windows executable" }
	$executablePath = [string]$executables[0].path
	$executableItem = Get-Item -LiteralPath $executablePath

	$profilePath = Join-Path $projectRoot "data\ptcgdap\author_strategy_device_acceptance_profile.json"
	$profile = Get-Content -Raw -LiteralPath $profilePath | ConvertFrom-Json
	$canonicalProgram = @'
from pathlib import Path
import hashlib
import sys
root = Path(sys.argv[1])
sys.path.insert(0, str(root))
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
value = load_json_strict(Path(sys.argv[2]))
print(hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper())
'@
	$canonicalProfileHash = ((& $PythonExe -c $canonicalProgram $projectRoot $profilePath) -join "").Trim()
	if ($LASTEXITCODE -ne 0 -or $canonicalProfileHash -notmatch '^[0-9A-F]{64}$') {
		throw "Unable to compute the canonical device-profile hash"
	}

	$probeArtifacts = [System.IO.Path]::ChangeExtension($resolvedOutput, $null) + ".artifacts"
	if (Test-Path -LiteralPath $probeArtifacts) { throw "Refusing to overwrite existing probe artifacts: $probeArtifacts" }
	New-Item -ItemType Directory -Path $probeArtifacts | Out-Null
	$samples = @()
	for ($index = 1; $index -le 3; $index++) {
		$sampleRoot = Join-Path $probeArtifacts ("sample-{0:D2}" -f $index)
		$appData = Join-Path $sampleRoot "appdata"
		$localAppData = Join-Path $sampleRoot "localappdata"
		New-Item -ItemType Directory -Path $appData, $localAppData | Out-Null
		$stdoutPath = Join-Path $sampleRoot "stdout.log"
		$stderrPath = Join-Path $sampleRoot "stderr.log"
		$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
		$startInfo.FileName = $executablePath
		$startInfo.WorkingDirectory = $exportDirectory
		$startInfo.Arguments = "--headless --quit-after 1"
		$startInfo.UseShellExecute = $false
		$startInfo.CreateNoWindow = $true
		$startInfo.RedirectStandardOutput = $true
		$startInfo.RedirectStandardError = $true
		$startInfo.EnvironmentVariables["APPDATA"] = $appData
		$startInfo.EnvironmentVariables["LOCALAPPDATA"] = $localAppData
		$process = [System.Diagnostics.Process]::new()
		$process.StartInfo = $startInfo
		$clock = [System.Diagnostics.Stopwatch]::StartNew()
		if (-not $process.Start()) { throw "Unable to start exported executable" }
		$stdoutTask = $process.StandardOutput.ReadToEndAsync()
		$stderrTask = $process.StandardError.ReadToEndAsync()
		$peakWorkingSetBytes = [int64]0
		while (-not $process.WaitForExit(10)) {
			$process.Refresh()
			$peakWorkingSetBytes = [Math]::Max($peakWorkingSetBytes, [int64]$process.WorkingSet64)
			if ($clock.ElapsedMilliseconds -ge $ProbeTimeoutMsec) {
				$process.Kill()
				throw "Exported executable exceeded the provisional probe timeout"
			}
		}
		$process.WaitForExit()
		$clock.Stop()
		$stdout = $stdoutTask.Result
		$stderr = $stderrTask.Result
		[System.IO.File]::WriteAllText($stdoutPath, $stdout, [System.Text.UTF8Encoding]::new($false))
		[System.IO.File]::WriteAllText($stderrPath, $stderr, [System.Text.UTF8Encoding]::new($false))
		$exitCode = $process.ExitCode
		$peakWorkingSetMib = [int64][Math]::Ceiling($peakWorkingSetBytes / 1MB)
		$process.Dispose()
		if ($exitCode -ne 0) { throw "Exported executable exited with code $exitCode; see $sampleRoot" }
		$samples += [pscustomobject][ordered]@{
			index = $index
			elapsed_msec = [int64]$clock.ElapsedMilliseconds
			exit_code = $exitCode
			peak_working_set_mib = $peakWorkingSetMib
			stdout_sha256 = (Get-FileHash -LiteralPath $stdoutPath -Algorithm SHA256).Hash.ToUpperInvariant()
			stderr_sha256 = (Get-FileHash -LiteralPath $stderrPath -Algorithm SHA256).Hash.ToUpperInvariant()
		}
	}

	$operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem
	$processor = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
	$maxElapsed = [int64](($samples | Measure-Object -Property elapsed_msec -Maximum).Maximum)
	$packageMib = [int64][Math]::Ceiling($executableItem.Length / 1MB)
	$report = [ordered]@{
		document_type = "author_strategy_windows_provisional_probe_v1"
		schema_version = 1
		generated_at = (Get-Date).ToUniversalTime().ToString("o")
		formal_device_report = $false
		a5_claimed = $false
		profile = [ordered]@{
			path = "data/ptcgdap/author_strategy_device_acceptance_profile.json"
			profile_id = [string]$profile.profile_id
			approval_status = [string]$profile.approval_status
			formal_a5_eligible = [bool]$profile.formal_a5_eligible
			raw_sha256 = (Get-FileHash -LiteralPath $profilePath -Algorithm SHA256).Hash.ToUpperInvariant()
			canonical_sha256 = $canonicalProfileHash
		}
		export = [ordered]@{
			manifest_path = $resolvedManifest
			manifest_sha256 = (Get-FileHash -LiteralPath $resolvedManifest -Algorithm SHA256).Hash.ToUpperInvariant()
			output_directory = $exportDirectory
			verified_outputs = @($verifiedOutputs)
		}
		host = [ordered]@{
			os_caption = [string]$operatingSystem.Caption
			os_version = [string]$operatingSystem.Version
			os_build = [string]$operatingSystem.BuildNumber
			architecture = "x86_64"
			processor_name = ([string]$processor.Name).Trim()
			logical_processor_count = [int]$processor.NumberOfLogicalProcessors
			total_physical_memory_mib = [int64][Math]::Floor([int64]$operatingSystem.TotalVisibleMemorySize / 1024)
		}
		cold_start_probe = [ordered]@{
			method = "wall_clock_exported_executable_headless_quit_after_one_frame"
			required_samples = 3
			sample_count = @($samples).Count
			samples = @($samples)
			max_elapsed_msec = $maxElapsed
		}
		measured = [ordered]@{
			package_basis = "standalone_executable"
			package_mib = $packageMib
		}
		unmeasured_gates = @(
			"catalog_scan_msec",
			"match_load_msec",
			"decision_samples_minimum",
			"network_blocked",
			"runtime_process_isolation",
			"complete_match_finished",
			"rollback"
		)
		limitations = @(
			"Provisional Windows probe only; formal A5 is not claimed.",
			"Headless quit-after-one-frame wall time is not a full application-ready or full-match measurement.",
			"Network blocking, process isolation, decision latency, full-match completion, and rollback remain unmeasured."
		)
	}
	[System.IO.File]::WriteAllText($resolvedOutput, ($report | ConvertTo-Json -Depth 12), [System.Text.UTF8Encoding]::new($false))

	$validationProgram = @'
from pathlib import Path
import sys
from jsonschema import Draft202012Validator
root = Path(sys.argv[1])
sys.path.insert(0, str(root))
from scripts.ai.ptcgdap.source_lock import load_json_strict
schema = load_json_strict(root / 'contracts/ptcgdap/author_strategy_release.schema.json')
report = load_json_strict(Path(sys.argv[2]))
Draft202012Validator(schema).validate(report)
samples = report['cold_start_probe']['samples']
assert [sample['index'] for sample in samples] == [1, 2, 3]
assert report['cold_start_probe']['max_elapsed_msec'] == max(sample['elapsed_msec'] for sample in samples)
assert len([entry for entry in report['export']['verified_outputs'] if entry['kind'] == 'executable']) == 1
'@
	& $PythonExe -c $validationProgram $projectRoot $resolvedOutput
	if ($LASTEXITCODE -ne 0) { throw "Provisional probe report failed strict validation: $resolvedOutput" }
	Write-Output $resolvedOutput
}

if ($PSCmdlet.ParameterSetName -eq "Probe") {
	Invoke-WindowsProvisionalProbe
} else {
	Invoke-FormalReportEvaluation
}
