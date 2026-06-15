param(
	[string]$GodotExe = "",
	[string]$ProjectRoot = "",
	[string]$OutputRoot = "",
	[string]$Preset = "Web",
	[string]$BaseName = "PtcgDeckAgent",
	[string]$PublicBasePath = "/dist",
	[switch]$SkipExport
)

$ErrorActionPreference = "Stop"

function Resolve-DefaultGodotExe {
	if (-not [string]::IsNullOrWhiteSpace($env:GODOT_EXE)) {
		return $env:GODOT_EXE
	}
	return "D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe"
}

function Resolve-ProjectRoot {
	param([string]$ScriptPath)
	if (-not [string]::IsNullOrWhiteSpace($ProjectRoot)) {
		return (Resolve-Path -LiteralPath $ProjectRoot).Path
	}
	return (Resolve-Path -LiteralPath (Join-Path $ScriptPath "..\..")).Path
}

function Read-AppVersion {
	param([string]$Root)
	$versionPath = Join-Path $Root "scripts\app\AppVersion.gd"
	if (-not (Test-Path -LiteralPath $versionPath)) {
		throw "AppVersion.gd not found: $versionPath"
	}
	$text = [System.IO.File]::ReadAllText($versionPath, [System.Text.Encoding]::UTF8)
	$versionMatch = [regex]::Match($text, 'const\s+VERSION\s*:=\s*"([^"]+)"')
	$displayMatch = [regex]::Match($text, 'const\s+DISPLAY_VERSION\s*:=\s*"([^"]+)"')
	$buildMatch = [regex]::Match($text, 'const\s+BUILD_NUMBER\s*:=\s*(\d+)')
	$channelMatch = [regex]::Match($text, 'const\s+CHANNEL\s*:=\s*"([^"]+)"')
	if (-not $versionMatch.Success) {
		throw "Unable to read VERSION from $versionPath"
	}
	return @{
		Version = $versionMatch.Groups[1].Value
		DisplayVersion = if ($displayMatch.Success) { $displayMatch.Groups[1].Value } else { "v$($versionMatch.Groups[1].Value)" }
		BuildNumber = if ($buildMatch.Success) { [int]$buildMatch.Groups[1].Value } else { 0 }
		Channel = if ($channelMatch.Success) { $channelMatch.Groups[1].Value } else { "stable" }
	}
}

function Get-ReleaseFiles {
	param([string]$ReleaseDir)
	$files = Get-ChildItem -LiteralPath $ReleaseDir -File |
		Where-Object { $_.Name -ne "release-manifest.json" } |
		Sort-Object Name
	$result = @()
	foreach ($file in $files) {
		$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName
		$result += [ordered]@{
			name = $file.Name
			size = $file.Length
			sha256 = $hash.Hash.ToLowerInvariant()
		}
	}
	return $result
}

function Get-ReleaseSlug {
	param([string]$Version)
	return "v$($Version.Replace('.', '_').Replace('-', '_'))"
}

function Assert-ExpectedFiles {
	param(
		[string]$ReleaseDir,
		[string]$Name
	)
	$required = @(
		"$Name.html",
		"$Name.js",
		"$Name.pck",
		"$Name.wasm"
	)
	foreach ($fileName in $required) {
		$path = Join-Path $ReleaseDir $fileName
		if (-not (Test-Path -LiteralPath $path)) {
			throw "Expected Web export file is missing: $path"
		}
	}
}

function Write-JsonFile {
	param(
		[string]$Path,
		[object]$Value
	)
	$json = $Value | ConvertTo-Json -Depth 8
	[System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$resolvedProjectRoot = Resolve-ProjectRoot -ScriptPath $scriptRoot
if ([string]::IsNullOrWhiteSpace($GodotExe)) {
	$GodotExe = Resolve-DefaultGodotExe
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
	$OutputRoot = Join-Path $resolvedProjectRoot "..\ptcgtranweb"
}
$resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)

$appVersion = Read-AppVersion -Root $resolvedProjectRoot
$version = $appVersion.Version
$releaseSlug = Get-ReleaseSlug -Version $version
$releaseDir = Join-Path (Join-Path $resolvedOutputRoot "web") $releaseSlug
$exportPath = Join-Path $releaseDir "$BaseName.html"

New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null

if (-not $SkipExport) {
	if (-not (Test-Path -LiteralPath $GodotExe)) {
		throw "Godot executable not found: $GodotExe. Set GODOT_EXE or pass -GodotExe."
	}
	$godotArgs = @(
		"--headless",
		"--path",
		$resolvedProjectRoot,
		"--export-release",
		$Preset,
		$exportPath
	)
	Write-Host "Exporting Web release $version to $exportPath"
	& $GodotExe @godotArgs
	if ($LASTEXITCODE -ne 0) {
		throw "Godot Web export failed with exit code $LASTEXITCODE"
	}
}

Assert-ExpectedFiles -ReleaseDir $releaseDir -Name $BaseName

$files = Get-ReleaseFiles -ReleaseDir $releaseDir
$publicBase = $PublicBasePath.TrimEnd("/")
$releasePath = "$publicBase/web/$releaseSlug"
$entryUrl = "$releasePath/$BaseName.html"
$generatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$releaseManifest = [ordered]@{
	schema_version = 1
	version = $version
	display_version = $appVersion.DisplayVersion
	build_number = $appVersion.BuildNumber
	channel = $appVersion.Channel
	public_base_path = $publicBase
	release_path = $releasePath
	entry = $entryUrl
	generated_at = $generatedAt
	files = $files
	cache_policy = [ordered]@{
		entry_html = "no-cache"
		versioned_assets = "public, max-age=31536000, immutable"
	}
}
$latest = [ordered]@{
	schema_version = 1
	version = $version
	display_version = $appVersion.DisplayVersion
	build_number = $appVersion.BuildNumber
	channel = $appVersion.Channel
	release_path = $releasePath
	entry = $entryUrl
	manifest = "$releasePath/release-manifest.json"
	generated_at = $generatedAt
}

Write-JsonFile -Path (Join-Path $releaseDir "release-manifest.json") -Value $releaseManifest
Write-JsonFile -Path (Join-Path $resolvedOutputRoot "latest-web.json") -Value $latest

$pck = $files | Where-Object { $_.name -eq "$BaseName.pck" } | Select-Object -First 1
$wasm = $files | Where-Object { $_.name -eq "$BaseName.wasm" } | Select-Object -First 1
Write-Host "Web release generated:"
Write-Host "  Version: $version"
Write-Host "  Entry:   $entryUrl"
if ($pck -ne $null) {
	Write-Host ("  PCK:     {0:N2} MB" -f ($pck.size / 1MB))
}
if ($wasm -ne $null) {
	Write-Host ("  WASM:    {0:N2} MB" -f ($wasm.size / 1MB))
}
Write-Host "  Latest:  $(Join-Path $resolvedOutputRoot "latest-web.json")"
