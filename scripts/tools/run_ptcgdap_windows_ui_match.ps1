param(
    [string]$GodotPath = "D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe",
    [string]$ExecutablePath = "",
    [string]$ArtifactDirectory = "",
    [string]$UserDataRoot = "",
    [switch]$SkipExport,
    [switch]$ProductionDeviceCanary,
    [int]$MatchTimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if (-not $ArtifactDirectory) { $ArtifactDirectory = Join-Path $repoRoot ".tmp\ptcgdap_windows_ui_match" }
$allowedArtifactRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot ".tmp"))
$ArtifactDirectory = [System.IO.Path]::GetFullPath($ArtifactDirectory)
$allowedPrefix = $allowedArtifactRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
if (-not $ArtifactDirectory.StartsWith($allowedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "ArtifactDirectory must stay under $allowedArtifactRoot"
}
if (Test-Path -LiteralPath $ArtifactDirectory) { throw "Refusing to overwrite existing artifact directory: $ArtifactDirectory" }
if (-not $ExecutablePath) { $ExecutablePath = Join-Path $ArtifactDirectory "PtcgDeckAgent.exe" }
if (-not $UserDataRoot) { $UserDataRoot = Join-Path $ArtifactDirectory "fresh-user" }
New-Item -ItemType Directory -Path $ArtifactDirectory | Out-Null
New-Item -ItemType Directory -Path $UserDataRoot | Out-Null

if (-not $SkipExport) {
    & $GodotPath --headless --path $repoRoot --export-debug "Windows Desktop" $ExecutablePath
    if ($LASTEXITCODE -ne 0) { throw "Windows UI match export failed with exit code $LASTEXITCODE" }
}
if (-not (Test-Path -LiteralPath $ExecutablePath)) { throw "Windows executable not found: $ExecutablePath" }

Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class PtcgWindowsUiMatchInput {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hWnd, ref POINT point);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr insertAfter, int x, int y, int width, int height, uint flags);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT point);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
}
'@

function Read-SharedTextFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $reader = New-Object System.IO.StreamReader($stream)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose(); $stream.Dispose() }
}

function Get-ClientGeometry {
    param([IntPtr]$Handle)
    $rect = New-Object PtcgWindowsUiMatchInput+RECT
    if (-not [PtcgWindowsUiMatchInput]::GetClientRect($Handle, [ref]$rect)) { throw "GetClientRect failed" }
    $origin = New-Object PtcgWindowsUiMatchInput+POINT
    if (-not [PtcgWindowsUiMatchInput]::ClientToScreen($Handle, [ref]$origin)) { throw "ClientToScreen failed" }
    return [ordered]@{ x = $origin.X; y = $origin.Y; width = $rect.Right - $rect.Left; height = $rect.Bottom - $rect.Top }
}

function Save-WindowScreenshot {
    param([IntPtr]$Handle, [string]$Name)
    $geometry = Get-ClientGeometry -Handle $Handle
    $path = Join-Path $ArtifactDirectory "$Name.png"
    $bitmap = New-Object System.Drawing.Bitmap($geometry.width, $geometry.height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($geometry.x, $geometry.y, 0, 0, $bitmap.Size)
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
    return $path
}

function Invoke-RealMouseClick {
    param([IntPtr]$Handle, [double]$X, [double]$Y)
    [PtcgWindowsUiMatchInput]::ShowWindow($Handle, 9) | Out-Null
    [PtcgWindowsUiMatchInput]::SetWindowPos($Handle, [IntPtr]::Zero, 80, 50, 0, 0, 0x0045) | Out-Null
    [PtcgWindowsUiMatchInput]::BringWindowToTop($Handle) | Out-Null
    [PtcgWindowsUiMatchInput]::SetForegroundWindow($Handle) | Out-Null
    Start-Sleep -Milliseconds 150
    $geometry = Get-ClientGeometry -Handle $Handle
    $screenX = [math]::Round($geometry.x + $geometry.width * $X)
    $screenY = [math]::Round($geometry.y + $geometry.height * $Y)
    [PtcgWindowsUiMatchInput]::SetCursorPos($screenX, $screenY) | Out-Null
    Start-Sleep -Milliseconds 80
    [PtcgWindowsUiMatchInput]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [PtcgWindowsUiMatchInput]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

function Wait-ForLogLine {
    param([string]$Prefix, [datetime]$Deadline)
    do {
        Start-Sleep -Milliseconds 200
        $text = Read-SharedTextFile -Path $stdoutPath
        $line = ($text -split "`r?`n" | Where-Object { $_.StartsWith($Prefix) } | Select-Object -Last 1)
        if ($line) { return $line.Substring($Prefix.Length) }
        if ($process.HasExited) { throw "Windows game exited before log marker $Prefix" }
    } while ((Get-Date) -lt $Deadline)
    throw "Timed out waiting for log marker $Prefix"
}

function Wait-ForTarget {
    param([string]$Name, [bool]$RequireEnabled, [string]$RequiredState = "", [datetime]$Deadline)
    do {
        Start-Sleep -Milliseconds 200
        $text = Read-SharedTextFile -Path $stdoutPath
        $lines = $text -split "`r?`n" | Where-Object { $_.StartsWith("PTCGDAP_WINDOWS_UI_TARGET=") }
        foreach ($line in ($lines | Select-Object -Last 20 | Sort-Object -Descending)) {
            $target = $line.Substring("PTCGDAP_WINDOWS_UI_TARGET=".Length) | ConvertFrom-Json
            $stateMatches = (-not $RequiredState -or $target.state -eq $RequiredState)
            if ($target.name -eq $Name -and (-not $RequireEnabled -or -not $target.disabled) -and $stateMatches) { return $target }
        }
        if ($process.HasExited) { throw "Windows game exited before UI target $Name" }
    } while ((Get-Date) -lt $Deadline)
    throw "Timed out waiting for UI target $Name"
}

$stdoutPath = Join-Path $ArtifactDirectory "stdout.log"
$stderrPath = Join-Path $ArtifactDirectory "stderr.log"
$previousWindow = [PtcgWindowsUiMatchInput]::GetForegroundWindow()
$previousCursor = New-Object PtcgWindowsUiMatchInput+POINT
[PtcgWindowsUiMatchInput]::GetCursorPos([ref]$previousCursor) | Out-Null
$previousAppData = $env:APPDATA
$process = $null
$screenshots = [ordered]@{}
$engineReport = $null
$realClickCount = 0
$authorModeClickAttempts = 0
$network_isolation_proven = $false
$processStartedUtc = $null
$processExitedUtc = $null
$processId = 0
$coldStartMsec = -1
$catalogScanMsec = -1
$matchLoadMsec = -1
$peakWorkingSetMib = -1
$decisionMsec = @()
try {
    $env:APPDATA = (Resolve-Path -LiteralPath $UserDataRoot).Path
    $startupClock = [System.Diagnostics.Stopwatch]::StartNew()
    $processStartedUtc = (Get-Date).ToUniversalTime()
    $activationArg = if ($ProductionDeviceCanary) { "--ptcgdap-production-device-canary" } else { "--ptcgdap-development-ui-match" }
    $process = Start-Process -FilePath $ExecutablePath -ArgumentList "--verbose -- $activationArg" -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $processId = [int]$process.Id
    $env:APPDATA = $previousAppData
    $windowDeadline = (Get-Date).AddSeconds(45)
    do { Start-Sleep -Milliseconds 250; $process.Refresh() } while ($process.MainWindowHandle -eq 0 -and -not $process.HasExited -and (Get-Date) -lt $windowDeadline)
    if ($process.HasExited -or $process.MainWindowHandle -eq 0) { throw "Windows game window did not open within 45 seconds" }
    $handle = $process.MainWindowHandle
    [PtcgWindowsUiMatchInput]::SetWindowPos($handle, [IntPtr]::Zero, 80, 50, 0, 0, 0x0045) | Out-Null

    $readyJson = Wait-ForLogLine -Prefix "PTCGDAP_WINDOWS_UI_READY=" -Deadline ((Get-Date).AddSeconds(60))
    $startupClock.Stop()
    $coldStartMsec = [int64]$startupClock.ElapsedMilliseconds
    $readyPayload = $readyJson | ConvertFrom-Json
    $catalogScanUsec = [int64]$readyPayload.catalog_scan_elapsed_usec
    if ($catalogScanUsec -lt 0) { throw "Catalog scan timing was not emitted by the exported executable" }
    $catalogScanMsec = [int64][Math]::Ceiling($catalogScanUsec / 1000.0)
    $startTarget = Wait-ForTarget -Name "BtnStartBattle" -RequireEnabled $true -RequiredState "" -Deadline ((Get-Date).AddSeconds(60))
    $screenshots.main_menu = Save-WindowScreenshot -Handle $handle -Name "01-main-menu"
    Invoke-RealMouseClick -Handle $handle -X $startTarget.x -Y $startTarget.y
    $realClickCount += 1

    Wait-ForLogLine -Prefix "PTCGDAP_WINDOWS_UI_SCENE=res://scenes/battle_setup/BattleSetup.tscn" -Deadline ((Get-Date).AddSeconds(60)) | Out-Null
    Start-Sleep -Seconds 1
    $authorTarget = Wait-ForTarget -Name "ModeAuthorStrategyButton" -RequireEnabled $true -RequiredState "" -Deadline ((Get-Date).AddSeconds(60))
    $screenshots.battle_setup = Save-WindowScreenshot -Handle $handle -Name "02-battle-setup"
    $authorSelected = $false
    for ($attempt = 1; $attempt -le 3 -and -not $authorSelected; $attempt += 1) {
        $authorTarget = Wait-ForTarget -Name "ModeAuthorStrategyButton" -RequireEnabled $true -RequiredState "" -Deadline ((Get-Date).AddSeconds(10))
        Invoke-RealMouseClick -Handle $handle -X $authorTarget.x -Y $authorTarget.y
        $realClickCount += 1
        $authorModeClickAttempts += 1
        try {
            Wait-ForTarget -Name "ModeAuthorStrategyButton" -RequireEnabled $true -RequiredState "author_selected" -Deadline ((Get-Date).AddSeconds(4)) | Out-Null
            $authorSelected = $true
        } catch {
            if ($attempt -eq 3) { throw }
        }
    }

    $startMatchTarget = Wait-ForTarget -Name "BtnStart" -RequireEnabled $true -RequiredState "author_ready" -Deadline ((Get-Date).AddSeconds(90))
    $screenshots.author_mode = Save-WindowScreenshot -Handle $handle -Name "03-author-mode-ready"
    $matchLoadClock = [System.Diagnostics.Stopwatch]::StartNew()
    Invoke-RealMouseClick -Handle $handle -X $startMatchTarget.x -Y $startMatchTarget.y
    $realClickCount += 1

    Wait-ForLogLine -Prefix "PTCGDAP_WINDOWS_UI_SCENE=res://scenes/battle/BattleScene.tscn" -Deadline ((Get-Date).AddSeconds(90)) | Out-Null
    $matchLoadClock.Stop()
    $matchLoadMsec = [int64]$matchLoadClock.ElapsedMilliseconds
    Start-Sleep -Seconds 1
    $screenshots.battle_started = Save-WindowScreenshot -Handle $handle -Name "04-battle-started"
    $reportJson = Wait-ForLogLine -Prefix "PTCGDAP_WINDOWS_UI_MATCH=" -Deadline ((Get-Date).AddSeconds($MatchTimeoutSeconds))
    $engineReport = $reportJson | ConvertFrom-Json
    $decisionMsec = @($engineReport.author_audit.decision_elapsed_usec | ForEach-Object {
        [int64][Math]::Ceiling(([int64]$_) / 1000.0)
    })
    if (-not $process.HasExited) { $screenshots.match_terminal = Save-WindowScreenshot -Handle $handle -Name "05-match-terminal" }
    $process.Refresh()
    $peakWorkingSetMib = [int64][Math]::Ceiling(([int64]$process.PeakWorkingSet64) / 1MB)
    if ($process.WaitForExit(10000)) {
        $process.Refresh()
        $processExitedUtc = (Get-Date).ToUniversalTime()
    }
} finally {
    $env:APPDATA = $previousAppData
    [PtcgWindowsUiMatchInput]::SetCursorPos($previousCursor.X, $previousCursor.Y) | Out-Null
    if ($previousWindow -ne [IntPtr]::Zero) { [PtcgWindowsUiMatchInput]::SetForegroundWindow($previousWindow) | Out-Null }
    if ($null -ne $process -and -not $process.HasExited) {
        if ($process.MainWindowHandle -ne 0) { [PtcgWindowsUiMatchInput]::SetWindowPos($process.MainWindowHandle, [IntPtr](-2), 0, 0, 0, 0, 0x0043) | Out-Null }
        $process.CloseMainWindow() | Out-Null
        if (-not $process.WaitForExit(3000)) { Stop-Process -Id $process.Id -Force }
    }
    if ($null -ne $process) {
        try {
            $process.Refresh()
            if ($peakWorkingSetMib -le 0) {
                $peakWorkingSetMib = [int64][Math]::Ceiling(([int64]$process.PeakWorkingSet64) / 1MB)
            }
            if ($null -eq $processExitedUtc -and $process.HasExited) {
                $processExitedUtc = (Get-Date).ToUniversalTime()
            }
        } catch {
            if ($null -eq $processExitedUtc) { $processExitedUtc = (Get-Date).ToUniversalTime() }
        }
    }
}

$logs = ""
foreach ($path in @($stdoutPath, $stderrPath)) { if (Test-Path -LiteralPath $path) { $logs += [System.IO.File]::ReadAllText($path) + "`n" } }
$failureLines = ($logs -split "`r?`n" | Select-String -Pattern "SCRIPT ERROR|FATAL|CRASH|Unhandled Exception") -join "`n"
$applicationNetworkDisabled = $logs.Contains("PTCGDAP_WINDOWS_UI_NETWORK=application_disabled")
$networkAttemptLines = ($logs -split "`r?`n" | Select-String -Pattern "\[UserVisit\]|Perform PSA-based ECDH|Switch to handshake keys|check_for_updates") -join "`n"
$processStartedText = if ($null -ne $processStartedUtc) { $processStartedUtc.ToString("o") } else { "" }
$processExitedText = if ($null -ne $processExitedUtc) { $processExitedUtc.ToString("o") } else { "" }
$passed = (
    $null -ne $engineReport -and $engineReport.is_clean -and $engineReport.complete_match_finished `
    -and $realClickCount -ge 3 -and $authorModeClickAttempts -ge 1 `
    -and $applicationNetworkDisabled -and -not $networkAttemptLines -and -not $failureLines `
    -and $processId -gt 0 -and $processStartedText -and $processExitedText `
    -and $coldStartMsec -ge 0 -and $catalogScanMsec -ge 0 -and $matchLoadMsec -ge 0 `
    -and $peakWorkingSetMib -gt 0 -and @($decisionMsec).Count -gt 0 `
    -and ([bool]$engineReport.device_canary -eq [bool]$ProductionDeviceCanary)
)
$result = [ordered]@{
    schema_version = 1
    document_type = "author_strategy_windows_real_input_ui_match_report_v1"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    executable = (Resolve-Path -LiteralPath $ExecutablePath).Path
    executable_sha256 = (Get-FileHash -LiteralPath $ExecutablePath -Algorithm SHA256).Hash.ToUpperInvariant()
    process = [ordered]@{
        process_id = $processId
        started_at_utc = $processStartedText
        exited_at_utc = $processExitedText
        peak_working_set_mib = $peakWorkingSetMib
    }
    measurements = [ordered]@{
        cold_start_msec = $coldStartMsec
        catalog_scan_msec = $catalogScanMsec
        match_load_msec = $matchLoadMsec
        decision_msec = @($decisionMsec)
    }
    acceptance_mode = $(if ($ProductionDeviceCanary) { "device_canary" } else { "development" })
    development_only = (-not $ProductionDeviceCanary)
    device_canary = [bool]$ProductionDeviceCanary
    production_ready = $false
    a5_claimed = $false
    real_mouse_input_proven = ($realClickCount -ge 3)
    real_mouse_click_count = $realClickCount
    author_mode_click_attempts = $authorModeClickAttempts
    network_isolation_proven = $network_isolation_proven
    application_network_disabled = $applicationNetworkDisabled
    application_network_attempt_markers = $networkAttemptLines
    engine_report = $engineReport
    screenshots = $screenshots
    runtime_failure_markers = $failureLines
    passed = $passed
}
$reportPath = Join-Path $ArtifactDirectory "report.json"
$json = $result | ConvertTo-Json -Depth 12
[System.IO.File]::WriteAllText($reportPath, $json, [System.Text.UTF8Encoding]::new($false))
Write-Output $json
if (-not $passed) { throw "Windows real-input author strategy UI match failed; see $reportPath" }
