param(
	[string]$GodotExe = "D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe",
	[string]$PythonExe = "python",
	[string]$OutputDirectory = "",
	[ValidateSet("Debug", "Release")]
	[string]$AndroidBuildMode = "Debug",
	[switch]$WindowsOnly,
	[switch]$AndroidOnly
)

$ErrorActionPreference = "Stop"
if ($WindowsOnly -and $AndroidOnly) { throw "WindowsOnly and AndroidOnly are mutually exclusive" }

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptRoot "..\..")).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
	$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
	$OutputDirectory = Join-Path $projectRoot ".tmp\ptcgdap_device_release\$stamp"
}
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputDirectory)
$allowedOutputRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".tmp\ptcgdap_device_release"))
if (-not $resolvedOutput.StartsWith($allowedOutputRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
	throw "OutputDirectory must stay under $allowedOutputRoot"
}
if (Test-Path -LiteralPath $resolvedOutput) { throw "Refusing to overwrite existing output: $resolvedOutput" }
if (-not (Test-Path -LiteralPath $GodotExe)) { throw "Godot executable not found: $GodotExe" }

New-Item -ItemType Directory -Path $resolvedOutput | Out-Null
$inspector = Join-Path $projectRoot "tools\ptcgdap\inspect_author_strategy_export.py"
$canonicalizer = Join-Path $projectRoot "tools\ptcgdap\canonicalize_godot_export.py"
if (-not (Test-Path -LiteralPath $canonicalizer -PathType Leaf)) {
	throw "Godot export canonicalizer not found: $canonicalizer"
}
$outputs = @()
$exportLogIndex = 0
$canonicalizationLogIndex = 0

function Invoke-GodotExport {
	param([string]$Mode, [string]$Preset, [string]$Target)
	$script:exportLogIndex += 1
	$logPath = Join-Path $resolvedOutput ("godot-export-{0:D2}.log" -f $script:exportLogIndex)
	$previousErrorPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		& $GodotExe --headless --path $projectRoot $Mode $Preset $Target *> $logPath
		$exportExitCode = $LASTEXITCODE
	} finally {
		$ErrorActionPreference = $previousErrorPreference
	}
	if ($exportExitCode -ne 0) {
		$tail = (Get-Content -LiteralPath $logPath -Tail 80 | Out-String).Trim()
		throw "Godot $Mode failed for preset '$Preset' with exit code $exportExitCode`n$tail"
	}
	if (-not (Test-Path -LiteralPath $Target)) { throw "Godot did not create $Target" }
}

function Invoke-CanonicalizeGodotContainer {
	param(
		[ValidateSet("zip", "pck", "embedded-exe")]
		[string]$Kind,
		[string]$Path
	)
	$fullPath = [System.IO.Path]::GetFullPath($Path)
	$outputPrefix = $resolvedOutput.TrimEnd(
		[System.IO.Path]::DirectorySeparatorChar,
		[System.IO.Path]::AltDirectorySeparatorChar
	) + [System.IO.Path]::DirectorySeparatorChar
	if (-not $fullPath.StartsWith($outputPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
		throw "Canonicalization target must stay under $resolvedOutput"
	}
	if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
		throw "Canonicalization input not found: $fullPath"
	}
	$temporaryPath = "$fullPath.canonical"
	if (Test-Path -LiteralPath $temporaryPath) {
		throw "Refusing to overwrite canonicalization output: $temporaryPath"
	}
	$script:canonicalizationLogIndex += 1
	$logPath = Join-Path $resolvedOutput ("canonicalize-{0:D2}-{1}.log" -f $script:canonicalizationLogIndex, $Kind)
	$previousErrorPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		& $PythonExe $canonicalizer --kind $Kind --input $fullPath --output $temporaryPath *> $logPath
		$canonicalizationExitCode = $LASTEXITCODE
	} finally {
		$ErrorActionPreference = $previousErrorPreference
	}
	if ($canonicalizationExitCode -ne 0 -or -not (Test-Path -LiteralPath $temporaryPath -PathType Leaf)) {
		if (Test-Path -LiteralPath $temporaryPath) {
			Remove-Item -LiteralPath $temporaryPath -Force
		}
		$tail = if (Test-Path -LiteralPath $logPath) {
			(Get-Content -LiteralPath $logPath -Tail 80 | Out-String).Trim()
		} else {
			"canonicalizer did not create a log"
		}
		throw "Godot export canonicalization failed for '$Kind' with exit code $canonicalizationExitCode`n$tail"
	}
	Move-Item -LiteralPath $temporaryPath -Destination $fullPath -Force
	if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
		throw "Canonicalized export replacement failed: $fullPath"
	}
}

function Add-OutputRecord {
	param([string]$Kind, [string]$Platform, [string]$Path)
	$item = Get-Item -LiteralPath $Path
	$script:outputs += [ordered]@{
		kind = $Kind
		platform = $Platform
		path = $item.FullName
		bytes = $item.Length
		sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToUpperInvariant()
	}
}

if (-not $AndroidOnly) {
	$windowsPack = Join-Path $resolvedOutput "ptcgdap-windows-resources.zip"
	$windowsPck = Join-Path $resolvedOutput "ptcgdap-windows-resources.pck"
	$windowsExe = Join-Path $resolvedOutput "PtcgDeckAgent.exe"
	Invoke-GodotExport -Mode "--export-pack" -Preset "Windows Desktop" -Target $windowsPack
	Invoke-CanonicalizeGodotContainer -Kind "zip" -Path $windowsPack
	$windowsInventory = Join-Path $resolvedOutput "windows-inventory.json"
	& $PythonExe $inspector $windowsPack --output $windowsInventory
	if ($LASTEXITCODE -ne 0) { throw "Windows export inventory verification failed" }
	Invoke-GodotExport -Mode "--export-pack" -Preset "Windows Desktop" -Target $windowsPck
	Invoke-CanonicalizeGodotContainer -Kind "pck" -Path $windowsPck
	$runtimeProbeLog = Join-Path $resolvedOutput "windows-pck-runtime-probe.log"
	$previousErrorPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		& $GodotExe --headless --main-pack $windowsPck --script res://scripts/tools/inspect_ptcgdap_export_inventory.gd *> $runtimeProbeLog
		$probeExitCode = $LASTEXITCODE
	} finally {
		$ErrorActionPreference = $previousErrorPreference
	}
	if ($probeExitCode -ne 0 -or -not (Select-String -LiteralPath $runtimeProbeLog -Pattern '^PTCGDAP_EXPORT_INVENTORY=.*"accepted":true' -Quiet)) {
		throw "Windows PCK runtime inventory probe failed; see $runtimeProbeLog"
	}
	Invoke-GodotExport -Mode "--export-release" -Preset "Windows Desktop" -Target $windowsExe
	Invoke-CanonicalizeGodotContainer -Kind "embedded-exe" -Path $windowsExe
	Add-OutputRecord -Kind "resource_zip" -Platform "windows" -Path $windowsPack
	Add-OutputRecord -Kind "pck" -Platform "windows" -Path $windowsPck
	Add-OutputRecord -Kind "pck_runtime_probe" -Platform "windows" -Path $runtimeProbeLog
	Add-OutputRecord -Kind "executable" -Platform "windows" -Path $windowsExe
	Add-OutputRecord -Kind "inventory" -Platform "windows" -Path $windowsInventory
}

if (-not $WindowsOnly) {
	$androidPack = Join-Path $resolvedOutput "ptcgdap-android-resources.zip"
	$androidApk = Join-Path $resolvedOutput "PtcgDeckAgent.apk"
	Invoke-GodotExport -Mode "--export-pack" -Preset "Android" -Target $androidPack
	$androidInventory = Join-Path $resolvedOutput "android-inventory.json"
	& $PythonExe $inspector $androidPack --output $androidInventory
	if ($LASTEXITCODE -ne 0) { throw "Android export inventory verification failed" }
	$androidMode = if ($AndroidBuildMode -eq "Release") { "--export-release" } else { "--export-debug" }
	Invoke-GodotExport -Mode $androidMode -Preset "Android" -Target $androidApk
	$androidApkInventory = Join-Path $resolvedOutput "android-apk-inventory.json"
	& $PythonExe $inspector $androidApk --prefix "assets/" --output $androidApkInventory
	if ($LASTEXITCODE -ne 0) { throw "Android APK inventory verification failed" }
	Add-OutputRecord -Kind "resource_zip" -Platform "android" -Path $androidPack
	Add-OutputRecord -Kind ("apk_{0}" -f $AndroidBuildMode.ToLowerInvariant()) -Platform "android" -Path $androidApk
	Add-OutputRecord -Kind "apk_inventory" -Platform "android" -Path $androidApkInventory
	Add-OutputRecord -Kind "inventory" -Platform "android" -Path $androidInventory
}

$exportedPlatforms = @($outputs | ForEach-Object { $_.platform } | Select-Object -Unique)
$scopeLimitation = if ($WindowsOnly) {
	"Formal Windows offline full-match and approved A5 evidence are not implied by export success; Android is deferred by D041."
} elseif ($AndroidOnly) {
	"Formal Android offline full-match and approved A5 evidence are not implied by export success."
} else {
	"Formal Windows/Android offline full-match and approved A5 evidence are not implied by export success."
}
$manifest = [ordered]@{
	document_type = "author_strategy_device_export_manifest_v1"
	schema_version = 1
	generated_at = (Get-Date).ToUniversalTime().ToString("o")
	project_root = $projectRoot
	godot_executable = (Resolve-Path -LiteralPath $GodotExe).Path
	godot_version = ((& $GodotExe --version) -join "").Trim()
	output_directory = $resolvedOutput
	outputs = $outputs
	release_target_platforms = $exportedPlatforms
	player_start_allowed = $false
	production_ready = $false
	limitations = @(
		"The built-in package is signed by the test-fixture key and execution_trusted=false.",
		$scopeLimitation
	)
}
if (-not $WindowsOnly) {
	$manifest.android_build_mode = $AndroidBuildMode.ToLowerInvariant()
}
$manifestPath = Join-Path $resolvedOutput "export-manifest.json"
[System.IO.File]::WriteAllText(
	$manifestPath,
	($manifest | ConvertTo-Json -Depth 8),
	[System.Text.UTF8Encoding]::new($false)
)
Write-Output $manifestPath
