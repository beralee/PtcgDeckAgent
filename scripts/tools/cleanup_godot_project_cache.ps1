param(
	[switch]$Execute,
	[switch]$IncludeTestRuns,
	[switch]$KeepEditorCache,
	[switch]$AllowInteractiveEditor
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..\..")).Path
$tmpRoot = (Resolve-Path -LiteralPath (Join-Path $projectRoot "tmp")).Path
$godotMirrorRoot = (Resolve-Path -LiteralPath (Join-Path $projectRoot "Godot")).Path
$godotCacheRoot = (Resolve-Path -LiteralPath (Join-Path $projectRoot ".godot")).Path
$deckTrainingRoot = (Resolve-Path -LiteralPath (Join-Path $projectRoot "artifacts\deck_training")).Path

function Assert-ChildPath {
	param(
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][string]$AllowedRoot
	)
	$resolvedPath = (Resolve-Path -LiteralPath $Path).Path.TrimEnd("\")
	$resolvedRoot = (Resolve-Path -LiteralPath $AllowedRoot).Path.TrimEnd("\")
	if (-not $resolvedPath.StartsWith($resolvedRoot + "\", [StringComparison]::OrdinalIgnoreCase)) {
		throw "Cleanup target escaped its allowed root: $resolvedPath"
	}
	$item = Get-Item -LiteralPath $resolvedPath -Force
	if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
		throw "Cleanup target is a reparse point: $resolvedPath"
	}
	$nestedReparsePoint = Get-ChildItem -LiteralPath $resolvedPath -Recurse -Force -ErrorAction SilentlyContinue |
		Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 } |
		Select-Object -First 1
	if ($null -ne $nestedReparsePoint) {
		throw "Cleanup target contains a reparse point: $($nestedReparsePoint.FullName)"
	}
	return $resolvedPath
}

$directoryTargets = New-Object System.Collections.Generic.List[string]
$tmpCandidates = @(
	Get-ChildItem -LiteralPath $tmpRoot -Directory -Force |
		Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "Godot\app_userdata\PtcgDeckAgent") }
)
foreach ($candidate in $tmpCandidates) {
	$directoryTargets.Add((Assert-ChildPath -Path $candidate.FullName -AllowedRoot $tmpRoot))
}

$godotUserData = Join-Path $godotMirrorRoot "app_userdata"
if (Test-Path -LiteralPath $godotUserData) {
	$directoryTargets.Add((Assert-ChildPath -Path $godotUserData -AllowedRoot $godotMirrorRoot))
}

if ($IncludeTestRuns) {
	foreach ($relativeRoot in [string[]]@(
		".godot_test_user",
		".godot_benchmark_user",
		".godot_route_package_recheck",
		".tmp"
	)) {
		$testRoot = Join-Path $projectRoot $relativeRoot
		if (Test-Path -LiteralPath $testRoot) {
			$directoryTargets.Add((Assert-ChildPath -Path $testRoot -AllowedRoot $projectRoot))
		}
	}
}

if (-not $KeepEditorCache) {
	$importedCache = Join-Path $godotCacheRoot "imported"
	if (Test-Path -LiteralPath $importedCache) {
		$directoryTargets.Add((Assert-ChildPath -Path $importedCache -AllowedRoot $godotCacheRoot))
	}
}

$fileTargets = New-Object System.Collections.Generic.List[string]
if (-not $KeepEditorCache) {
	$filesystemCache = Join-Path $godotCacheRoot "editor\filesystem_cache10"
	if (Test-Path -LiteralPath $filesystemCache) {
		$fileTargets.Add((Assert-ChildPath -Path $filesystemCache -AllowedRoot $godotCacheRoot))
	}
}
foreach ($sidecar in Get-ChildItem -LiteralPath $deckTrainingRoot -Recurse -File -Filter "*.import" -Force) {
	$fileTargets.Add((Assert-ChildPath -Path $sidecar.FullName -AllowedRoot $deckTrainingRoot))
}

$deletedFileCount = 0
$deletedByteCount = [int64]0
foreach ($target in $directoryTargets) {
	$files = @(Get-ChildItem -LiteralPath $target -Recurse -File -Force)
	$deletedFileCount += $files.Count
	$sum = ($files | Measure-Object Length -Sum).Sum
	if ($null -ne $sum) {
		$deletedByteCount += [int64]$sum
	}
}
foreach ($target in $fileTargets) {
	$file = Get-Item -LiteralPath $target -Force
	$deletedFileCount += 1
	$deletedByteCount += [int64]$file.Length
}

if ($Execute) {
	$godotProcesses = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match "^Godot" })
	if ($godotProcesses.Count -ne 0) {
		$onlyInteractiveEditors = $true
		foreach ($process in $godotProcesses) {
			$commandLine = [string]$process.CommandLine
			if ($commandLine -notmatch "--editor" -or $commandLine -match "--headless") {
				$onlyInteractiveEditors = $false
				break
			}
		}
		if (-not ($AllowInteractiveEditor -and $KeepEditorCache -and $onlyInteractiveEditors)) {
			throw "Godot is running; refusing to clear caches used by a live process."
		}
	}
	foreach ($target in $directoryTargets) {
		Remove-Item -LiteralPath $target -Recurse -Force
	}
	foreach ($target in $fileTargets) {
		Remove-Item -LiteralPath $target -Force
	}
}

[pscustomobject]@{
	document_type = "ptcgdap_godot_project_cache_cleanup_v1"
	mode = $(if ($Execute) { "execute" } else { "dry_run" })
	project_root = $projectRoot
	include_test_runs = [bool]$IncludeTestRuns
	keep_editor_cache = [bool]$KeepEditorCache
	allow_interactive_editor = [bool]$AllowInteractiveEditor
	tmp_appdata_mirrors = $tmpCandidates.Count
	directory_targets = $directoryTargets.Count
	file_targets = $fileTargets.Count
	files = $deletedFileCount
	mebibytes = [math]::Round($deletedByteCount / 1MB, 1)
	targets = @($directoryTargets) + @($fileTargets)
} | ConvertTo-Json -Depth 4
