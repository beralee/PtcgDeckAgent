param(
    [ValidateSet("all", "functional", "ai", "web", "windows", "android")]
    [string]$Scope = "all",
    [string]$ArtifactDirectory = "",
    [switch]$SkipBrowserInstall,
    [switch]$SkipWebExport,
    [switch]$SkipWindowsExport,
    [switch]$SkipAndroidProvision
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if (-not $ArtifactDirectory) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $ArtifactDirectory = Join-Path $repoRoot ".tmp\ui_platform_validation\$stamp"
}
New-Item -ItemType Directory -Force -Path $ArtifactDirectory | Out-Null

$results = [System.Collections.Generic.List[object]]::new()

function Invoke-ValidationGate {
    param(
        [string]$Name,
        [string]$ScriptPath,
        [string[]]$Arguments = @()
    )
    $logPath = Join-Path $ArtifactDirectory "$Name.log"
    $startedAt = (Get-Date).ToUniversalTime()
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $exitCode = 1
    $failure = ""
    try {
        # Godot, adb and Playwright legitimately write progress lines to stderr.
        # Capture both streams without letting PowerShell convert a non-fatal
        # stderr record into a terminating exception; the child exit code is the
        # authoritative gate result.
        $previousErrorPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1 |
                Tee-Object -FilePath $logPath
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorPreference
        }
        if ($exitCode -ne 0) {
            $failure = "$Name exited with code $exitCode"
        }
    }
    catch {
        $failure = $_.Exception.Message
        $failure | Out-File -LiteralPath $logPath -Append -Encoding utf8
        $exitCode = 1
    }
    finally {
        $stopwatch.Stop()
    }
    $results.Add([ordered]@{
        name = $Name
        status = $(if ($exitCode -eq 0) { "passed" } else { "failed" })
        exit_code = $exitCode
        started_at = $startedAt.ToString("o")
        duration_seconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
        artifact_path = $logPath
        failure = $failure
    })
}

$runAll = $Scope -eq "all"
$godotRunner = Join-Path $PSScriptRoot "run_godot_tests.ps1"
if ($runAll -or $Scope -eq "functional") {
    Invoke-ValidationGate -Name "functional" -ScriptPath $godotRunner -Arguments @("-Runner", "functional")
}
if ($runAll -or $Scope -eq "ai") {
    Invoke-ValidationGate -Name "ai" -ScriptPath $godotRunner -Arguments @("-Runner", "ai")
}
if ($runAll -or $Scope -eq "web") {
    $webArgs = @()
    if ($SkipBrowserInstall) { $webArgs += "-SkipBrowserInstall" }
    if ($SkipWebExport) { $webArgs += "-SkipExport" }
    Invoke-ValidationGate -Name "web" -ScriptPath (Join-Path $PSScriptRoot "run_web_ui_e2e.ps1") -Arguments $webArgs
}
if ($runAll -or $Scope -eq "windows") {
    $windowsArgs = @()
    if ($SkipWindowsExport) { $windowsArgs += "-SkipExport" }
    Invoke-ValidationGate -Name "windows" -ScriptPath (Join-Path $PSScriptRoot "run_windows_ui_e2e.ps1") -Arguments $windowsArgs
}
if ($runAll -or $Scope -eq "android") {
    $androidArgs = @()
    if ($SkipAndroidProvision) { $androidArgs += "-SkipProvision" }
    Invoke-ValidationGate -Name "android" -ScriptPath (Join-Path $PSScriptRoot "run_android_ui_e2e.ps1") -Arguments $androidArgs
}

$failed = @($results | Where-Object { $_.status -eq "failed" })
$summary = [ordered]@{
    schema_version = 1
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repository = $repoRoot
    scope = $Scope
    status = $(if ($failed.Count -eq 0) { "passed" } else { "failed" })
    passed = @($results | Where-Object { $_.status -eq "passed" }).Count
    failed = $failed.Count
    not_verified = 0
    artifact_path = $ArtifactDirectory
    gates = $results
}
$summaryPath = Join-Path $ArtifactDirectory "summary.json"
$latestRoot = Join-Path $repoRoot ".tmp\ui_platform_validation"
$latestPath = Join-Path $latestRoot "latest-summary.json"
$summaryJson = $summary | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($summaryPath, $summaryJson, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($latestPath, $summaryJson, [System.Text.UTF8Encoding]::new($false))
$summaryJson

if ($failed.Count -gt 0) { exit 1 }
