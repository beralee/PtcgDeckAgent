[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExportManifestPath,
    [string]$EvidenceDirectory = "",
    [string]$PythonExe = "python",
    [int]$MatchTimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptRoot "..\..")).Path
$allowedExportRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".tmp\ptcgdap_device_release"))
$uiWrapper = Join-Path $scriptRoot "run_ptcgdap_windows_ui_match.ps1"
$rollbackWrapper = Join-Path $scriptRoot "run_ptcgdap_author_strategy_rollback_drill.ps1"
$reportBuilder = Join-Path $projectRoot "tools\ptcgdap\build_windows_profile_qualification.py"

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

$resolvedManifest = (Resolve-Path -LiteralPath $ExportManifestPath).Path
if (-not (Test-PathWithin -Path $resolvedManifest -Root $allowedExportRoot)) {
    throw "ExportManifestPath must stay under $allowedExportRoot"
}
$preflightText = (& $PythonExe $reportBuilder `
    --preflight `
    --project-root $projectRoot `
    --export-manifest $resolvedManifest) -join ""
if ($LASTEXITCODE -ne 0) {
    throw "Strict Windows profile-qualification preflight rejected the export manifest or fixed profile"
}
$preflight = $preflightText | ConvertFrom-Json
if (
    [string]$preflight.document_type -ne "author_strategy_windows_profile_qualification_preflight_v1" -or
    [int]$preflight.schema_version -ne 1 -or
    [string]$preflight.profile_approval_status -notin @("proposed", "approved")
) {
    throw "Strict profile-qualification preflight returned an unsupported result"
}
$manifestRawSha256 = (Get-FileHash -LiteralPath $resolvedManifest -Algorithm SHA256).Hash.ToUpperInvariant()
if ([string]$preflight.export_manifest_raw_sha256 -cne $manifestRawSha256) {
    throw "Export manifest changed after strict preflight"
}
$outputDirectory = [System.IO.Path]::GetFullPath([string]$preflight.output_directory)
if (
    -not (Test-PathWithin -Path $outputDirectory -Root $allowedExportRoot) -or
    -not ([System.IO.Path]::GetFullPath((Split-Path -Parent $resolvedManifest))).Equals(
        $outputDirectory,
        [System.StringComparison]::OrdinalIgnoreCase
    )
) {
    throw "Strict preflight output directory does not match the export manifest location"
}
$executablePath = [System.IO.Path]::GetFullPath([string]$preflight.executable_path)
if (-not (Test-PathWithin -Path $executablePath -Root $outputDirectory) -or -not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
    throw "Exported executable is outside the fixed output directory or missing"
}
$executableItem = Get-Item -LiteralPath $executablePath
if ($executableItem.LinkType) { throw "Exported executable must not be a link" }
$executableSha256 = (Get-FileHash -LiteralPath $executablePath -Algorithm SHA256).Hash.ToUpperInvariant()
if ([int64]$preflight.executable_bytes -ne $executableItem.Length -or [string]$preflight.executable_sha256 -cne $executableSha256) {
    throw "Exported executable changed after strict preflight"
}

if ([string]::IsNullOrWhiteSpace($EvidenceDirectory)) {
    $EvidenceDirectory = Join-Path $outputDirectory (
        "windows-profile-qualification-{0}-{1}" -f
        (Get-Date -Format "yyyyMMdd-HHmmss"),
        ([Guid]::NewGuid().ToString("N").Substring(0, 8))
    )
}
$evidenceDirectory = [System.IO.Path]::GetFullPath($EvidenceDirectory)
if (-not (Test-PathWithin -Path $evidenceDirectory -Root $outputDirectory)) {
    throw "EvidenceDirectory must stay under the fixed export output directory"
}
if (Test-Path -LiteralPath $evidenceDirectory) {
    throw "Refusing to overwrite existing evidence directory: $evidenceDirectory"
}
New-Item -ItemType Directory -Path $evidenceDirectory | Out-Null

$uiReports = @()
for ($index = 1; $index -le 3; $index += 1) {
    $uiDirectory = Join-Path $evidenceDirectory ("ui-run-{0:D2}" -f $index)
    & $uiWrapper `
        -ExecutablePath $executablePath `
        -ArtifactDirectory $uiDirectory `
        -SkipExport `
        -MatchTimeoutSeconds $MatchTimeoutSeconds | Out-Null
    $reportPath = Join-Path $uiDirectory "report.json"
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
        throw "UI qualification run $index did not write report.json"
    }
    $uiReports += $reportPath
}

$rollbackPath = Join-Path $evidenceDirectory "rollback.json"
& $rollbackWrapper -ExportManifestPath $resolvedManifest -OutputPath $rollbackPath | Out-Null
if (-not (Test-Path -LiteralPath $rollbackPath -PathType Leaf)) {
    throw "Profile qualification rollback drill did not write its report"
}

$reportPath = Join-Path $evidenceDirectory "profile-qualification.json"
& $PythonExe $reportBuilder `
    --project-root $projectRoot `
    --export-manifest $resolvedManifest `
    --evidence-root $evidenceDirectory `
    --ui-report $uiReports[0] `
    --ui-report $uiReports[1] `
    --ui-report $uiReports[2] `
    --rollback-report $rollbackPath `
    --output $reportPath
if ($LASTEXITCODE -ne 0) {
    throw "Windows profile qualification report builder rejected the captured evidence"
}
Write-Output $reportPath
