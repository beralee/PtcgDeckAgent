[CmdletBinding()]
param(
	[string]$RunId = "",
	[string]$GodotExe = "D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe",
	[string]$PythonExe = "python",
	[ValidateRange(30, 900)]
	[int]$MatchTimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptRoot "..\..")).Path
$entryRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".tmp\ptcgdap_windows_offline_entry"))
$buildRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".tmp\ptcgdap_device_release"))
$exporter = Join-Path $scriptRoot "export_ptcgdap_device_release.ps1"
$uiRunner = Join-Path $scriptRoot "run_ptcgdap_windows_ui_match.ps1"

if ([string]::IsNullOrWhiteSpace($RunId)) {
	$RunId = "d055-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}
if ($RunId -notmatch '^[a-z0-9][a-z0-9_-]{0,63}$') {
	throw "RunId must match ^[a-z0-9][a-z0-9_-]{0,63}$"
}
if (-not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) { throw "Godot executable not found: $GodotExe" }
if (-not (Test-Path -LiteralPath $exporter -PathType Leaf)) { throw "Windows exporter not found: $exporter" }
if (-not (Test-Path -LiteralPath $uiRunner -PathType Leaf)) { throw "Windows UI runner not found: $uiRunner" }

function Test-PathWithin {
	param([string]$Path, [string]$Root)
	$fullPath = [System.IO.Path]::GetFullPath($Path)
	$fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd(
		[System.IO.Path]::DirectorySeparatorChar,
		[System.IO.Path]::AltDirectorySeparatorChar
	)
	$prefix = $fullRoot + [System.IO.Path]::DirectorySeparatorChar
	return $fullPath.Equals($fullRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
		$fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Write-NewJson {
	param([string]$Path, [object]$Value)
	if (Test-Path -LiteralPath $Path) { throw "Refusing to overwrite existing report: $Path" }
	$bytes = [System.Text.UTF8Encoding]::new($false).GetBytes(($Value | ConvertTo-Json -Depth 24))
	$stream = [System.IO.FileStream]::new(
		$Path,
		[System.IO.FileMode]::CreateNew,
		[System.IO.FileAccess]::Write,
		[System.IO.FileShare]::None
	)
	try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

function Get-CanonicalJsonSha256 {
	param([string]$Path)
	$program = @'
from pathlib import Path
import hashlib
import sys
root = Path(sys.argv[1])
sys.path.insert(0, str(root))
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
value = load_json_strict(Path(sys.argv[2]))
print(hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper())
'@
	$result = ((& $PythonExe -c $program $projectRoot $Path) -join "").Trim()
	if ($LASTEXITCODE -ne 0 -or $result -notmatch '^[0-9A-F]{64}$') {
		throw "Unable to compute canonical JSON hash: $Path"
	}
	return $result
}

$runRoot = [System.IO.Path]::GetFullPath((Join-Path $entryRoot $RunId))
$exportRoot = [System.IO.Path]::GetFullPath((Join-Path $buildRoot ($RunId + "-build")))
if (-not (Test-PathWithin -Path $runRoot -Root $entryRoot)) { throw "Run root escaped the allowed entry root" }
if (-not (Test-PathWithin -Path $exportRoot -Root $buildRoot)) { throw "Build root escaped the allowed export root" }
if (Test-Path -LiteralPath $runRoot) { throw "Refusing to overwrite existing run directory: $runRoot" }
if (Test-Path -LiteralPath $exportRoot) { throw "Refusing to overwrite existing build directory: $exportRoot" }
New-Item -ItemType Directory -Path $runRoot | Out-Null

# Build: the project-owned exporter produces one Windows-only standalone bundle.
& $exporter -GodotExe $GodotExe -PythonExe $PythonExe -OutputDirectory $exportRoot -WindowsOnly | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Windows build phase failed with exit code $LASTEXITCODE" }
$exportManifestPath = Join-Path $exportRoot "export-manifest.json"
$inventoryPath = Join-Path $exportRoot "windows-inventory.json"
if (-not (Test-Path -LiteralPath $exportManifestPath -PathType Leaf)) { throw "Build manifest missing: $exportManifestPath" }
if (-not (Test-Path -LiteralPath $inventoryPath -PathType Leaf)) { throw "Build inventory missing: $inventoryPath" }
$exportManifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $exportManifestPath | ConvertFrom-Json
$inventory = Get-Content -Raw -Encoding UTF8 -LiteralPath $inventoryPath | ConvertFrom-Json
if (
	$exportManifest.document_type -ne "author_strategy_device_export_manifest_v1" -or
	$exportManifest.schema_version -ne 1 -or
	@($exportManifest.release_target_platforms).Count -ne 1 -or
	[string]$exportManifest.release_target_platforms[0] -ne "windows" -or
	[bool]$exportManifest.player_start_allowed -or
	[bool]$exportManifest.production_ready
) {
	throw "Windows build manifest widened the declared release scope"
}
if (
	$inventory.document_type -ne "author_strategy_export_inventory_report_v1" -or
	$inventory.schema_version -ne 1 -or
	-not [bool]$inventory.accepted -or
	@($inventory.missing_paths).Count -ne 0
) {
	throw "Windows resource inventory was not accepted"
}

$requiredDevicePaths = @(
	"contracts/ptcgdap/device_manifest_v1.schema.json",
	"contracts/ptcgdap/device_manifest_v1_profile.json",
	"contracts/ptcgdap/device_manifest_v1_bundle.json",
	"data/ptcgdap/marnie_windows_device_manifest_v1.json",
	"scripts/ai/ptcgdap/runtime/local/DeviceManifest.gdc",
	"scripts/ai/ptcgdap/runtime/local/DeviceManifest.gd.remap"
)
$inventoryByPath = @{}
foreach ($member in @($inventory.members)) {
	$inventoryByPath[[string]$member.path] = $member
}
foreach ($relativePath in $requiredDevicePaths) {
	if (-not $inventoryByPath.ContainsKey($relativePath)) { throw "Device manifest export member missing: $relativePath" }
	$member = $inventoryByPath[$relativePath]
	if ([int64]$member.bytes -le 0 -or [string]$member.sha256 -notmatch '^[0-9A-F]{64}$') {
		throw "Device manifest export member invalid: $relativePath"
	}
	$sourcePath = Join-Path $projectRoot ($relativePath -replace '/', '\')
	if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
		$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToUpperInvariant()
		if ([string]$member.sha256 -cne $sourceHash) { throw "Export member hash drift: $relativePath" }
	}
}

# Install: make an independent standalone copy and verify it before launch.
$executables = @($exportManifest.outputs | Where-Object { $_.platform -eq "windows" -and $_.kind -eq "executable" })
if ($executables.Count -ne 1) { throw "Build manifest must contain exactly one Windows executable" }
$sourceExecutable = [System.IO.Path]::GetFullPath([string]$executables[0].path)
if (-not (Test-PathWithin -Path $sourceExecutable -Root $exportRoot)) { throw "Build executable escaped the export root" }
$sourceItem = Get-Item -LiteralPath $sourceExecutable
$sourceHash = (Get-FileHash -LiteralPath $sourceExecutable -Algorithm SHA256).Hash.ToUpperInvariant()
if ([int64]$executables[0].bytes -ne $sourceItem.Length -or [string]$executables[0].sha256 -cne $sourceHash) {
	throw "Build executable no longer matches its export manifest"
}
$installRoot = Join-Path $runRoot "install"
New-Item -ItemType Directory -Path $installRoot | Out-Null
$installedExecutable = Join-Path $installRoot "PtcgDeckAgent.exe"
Copy-Item -LiteralPath $sourceExecutable -Destination $installedExecutable
$installedItem = Get-Item -LiteralPath $installedExecutable
$installedHash = (Get-FileHash -LiteralPath $installedExecutable -Algorithm SHA256).Hash.ToUpperInvariant()
if ($installedItem.Length -ne $sourceItem.Length -or $installedHash -cne $sourceHash) {
	throw "Installed executable failed exact byte verification"
}
$deviceManifestPath = Join-Path $projectRoot "data\ptcgdap\marnie_windows_device_manifest_v1.json"
$deviceManifestCanonical = Get-CanonicalJsonSha256 -Path $deviceManifestPath
$installManifestPath = Join-Path $runRoot "install-manifest.json"
Write-NewJson -Path $installManifestPath -Value ([ordered]@{
	document_type = "author_strategy_windows_standalone_install_v1"
	schema_version = 1
	run_id = $RunId
	source_executable_sha256 = $sourceHash
	installed_executable = $installedExecutable
	installed_executable_bytes = [int64]$installedItem.Length
	installed_executable_sha256 = $installedHash
	device_manifest_canonical_sha256 = $deviceManifestCanonical
	fresh_install_directory = $true
})

# Launch: ordinary UI with a fresh user-data root and defensive dead proxies.
$launchRoot = Join-Path $runRoot "launch"
$freshUserRoot = Join-Path $launchRoot "fresh-user"
$previousHttpProxy = $env:HTTP_PROXY
$previousHttpsProxy = $env:HTTPS_PROXY
$previousAllProxy = $env:ALL_PROXY
$previousNoProxy = $env:NO_PROXY
$installLocationPushed = $false
try {
	$env:HTTP_PROXY = "http://127.0.0.1:9"
	$env:HTTPS_PROXY = "http://127.0.0.1:9"
	$env:ALL_PROXY = "http://127.0.0.1:9"
	$env:NO_PROXY = ""
	Push-Location -LiteralPath $installRoot
	$installLocationPushed = $true
	& $uiRunner -ExecutablePath $installedExecutable -ArtifactDirectory $launchRoot -UserDataRoot $freshUserRoot -SkipExport -MatchTimeoutSeconds $MatchTimeoutSeconds | Out-Null
} finally {
	if ($installLocationPushed) { Pop-Location }
	$env:HTTP_PROXY = $previousHttpProxy
	$env:HTTPS_PROXY = $previousHttpsProxy
	$env:ALL_PROXY = $previousAllProxy
	$env:NO_PROXY = $previousNoProxy
}
$uiReportPath = Join-Path $launchRoot "report.json"
if (-not (Test-Path -LiteralPath $uiReportPath -PathType Leaf)) { throw "Windows UI launch report missing" }
$uiReport = Get-Content -Raw -Encoding UTF8 -LiteralPath $uiReportPath | ConvertFrom-Json
$audit = $uiReport.engine_report.author_audit
$failureTotal = [int64]$audit.policy_errors + [int64]$audit.invalid_outputs +
	[int64]$audit.same_window_fallbacks + [int64]$audit.classic_fallbacks +
	[int64]$audit.engine_rejections + [int64]$audit.external_process_attempts
if (
	-not [bool]$uiReport.passed -or
	-not [bool]$uiReport.real_mouse_input_proven -or
	-not [bool]$uiReport.application_network_disabled -or
	[bool]$uiReport.network_isolation_proven -or
	-not [bool]$uiReport.engine_report.complete_match_finished -or
	-not [bool]$uiReport.engine_report.is_clean -or
	[int]$audit.policy_calls -le 0 -or
	[int]$audit.policy_calls -ne [int]$audit.policy_successes -or
	[int]$audit.engine_commits -le 0 -or
	$failureTotal -ne 0 -or
	[string]$audit.local_policy_executor_manifest_canonical_sha256 -cne "DCFA65A979F1525BD690D6919A80C0FE0858B819B7A4DA06795EB8B38AC824B5" -or
	[string]$audit.model_backend -ne "none" -or
	[bool]$audit.production_ready -or
	[bool]$uiReport.a5_claimed
) {
	throw "Installed Windows ordinary-UI launch failed the development offline entry contract"
}

$reportPath = Join-Path $runRoot "report.json"
$report = [ordered]@{
	document_type = "author_strategy_windows_offline_entry_report_v1"
	schema_version = 1
	generated_at = (Get-Date).ToUniversalTime().ToString("o")
	run_id = $RunId
	passed = $true
	phases = [ordered]@{
		build = [ordered]@{
			passed = $true
			export_manifest_path = $exportManifestPath
			export_manifest_sha256 = (Get-FileHash -LiteralPath $exportManifestPath -Algorithm SHA256).Hash.ToUpperInvariant()
			inventory_path = $inventoryPath
			inventory_sha256 = (Get-FileHash -LiteralPath $inventoryPath -Algorithm SHA256).Hash.ToUpperInvariant()
			required_device_member_count = $requiredDevicePaths.Count
		}
		install = [ordered]@{
			passed = $true
			fresh_install_directory = $true
			install_manifest_path = $installManifestPath
			executable_sha256 = $installedHash
			executable_bytes = [int64]$installedItem.Length
			device_manifest_canonical_sha256 = $deviceManifestCanonical
		}
		launch = [ordered]@{
			passed = $true
			ordinary_ui = $true
			real_mouse_input_proven = [bool]$uiReport.real_mouse_input_proven
			complete_match_finished = [bool]$uiReport.engine_report.complete_match_finished
			policy_calls = [int]$audit.policy_calls
			policy_successes = [int]$audit.policy_successes
			engine_commits = [int]$audit.engine_commits
			failure_counters_total = $failureTotal
			ui_report_path = $uiReportPath
			ui_report_sha256 = (Get-FileHash -LiteralPath $uiReportPath -Algorithm SHA256).Hash.ToUpperInvariant()
		}
	}
	claims = [ordered]@{
		project_owned_entry = $true
		windows_x86_64_only = $true
		development_only = $true
		application_network_disabled = $true
		defensive_dead_proxy_environment = $true
		player_runtime_system_python_required = $false
		os_network_isolation_proven = $false
		device_profile_approved = $false
		production_ready = $false
		a5_claimed = $false
		android_claimed = $false
	}
	limitations = @(
		"Development-only Windows build/install/ordinary-UI/offline entry; production player start remains closed.",
		"Application network disablement and dead proxies are not an administrator-audited OS network-isolation proof.",
		"The proposed device profile, production signing, formal device report, A2/A5, and Android remain open."
	)
}
Write-NewJson -Path $reportPath -Value $report
Write-Output $reportPath
