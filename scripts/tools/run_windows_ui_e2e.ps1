param(
    [string]$GodotPath = "D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe",
    [string]$ExecutablePath = "",
    [string]$ArtifactDirectory = "",
    [switch]$SkipExport,
    [double]$MinimumNavigationDifference = 0.08,
    [double]$MaximumRoundTripDifference = 0.12
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if (-not $ArtifactDirectory) { $ArtifactDirectory = Join-Path $repoRoot ".tmp\windows_ui_e2e" }
if (-not $ExecutablePath) { $ExecutablePath = Join-Path $ArtifactDirectory "PtcgDeckAgent.exe" }
New-Item -ItemType Directory -Force -Path $ArtifactDirectory | Out-Null

if (-not $SkipExport) {
    & $GodotPath --headless --path $repoRoot --export-debug "Windows Desktop" $ExecutablePath
    if ($LASTEXITCODE -ne 0) { throw "Windows UI E2E export failed with exit code $LASTEXITCODE" }
}
if (-not (Test-Path -LiteralPath $ExecutablePath)) { throw "Windows executable not found: $ExecutablePath" }

Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class PtcgWindowsUiE2E {
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

function Get-ClientGeometry {
    param([IntPtr]$Handle)
    $rect = New-Object PtcgWindowsUiE2E+RECT
    if (-not [PtcgWindowsUiE2E]::GetClientRect($Handle, [ref]$rect)) { throw "GetClientRect failed" }
    $origin = New-Object PtcgWindowsUiE2E+POINT
    if (-not [PtcgWindowsUiE2E]::ClientToScreen($Handle, [ref]$origin)) { throw "ClientToScreen failed" }
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
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
    return $path
}

function Invoke-RealMouseClick {
    param([IntPtr]$Handle, [double]$X, [double]$Y)
    [PtcgWindowsUiE2E]::ShowWindow($Handle, 9) | Out-Null
    [PtcgWindowsUiE2E]::SetWindowPos($Handle, [IntPtr]::Zero, 80, 50, 0, 0, 0x0045) | Out-Null
    [PtcgWindowsUiE2E]::SetWindowPos($Handle, [IntPtr](-1), 0, 0, 0, 0, 0x0043) | Out-Null
    [PtcgWindowsUiE2E]::BringWindowToTop($Handle) | Out-Null
    [PtcgWindowsUiE2E]::SetForegroundWindow($Handle) | Out-Null
    Start-Sleep -Milliseconds 150
    $geometry = Get-ClientGeometry -Handle $Handle
    $screenX = [math]::Round($geometry.x + $geometry.width * $X)
    $screenY = [math]::Round($geometry.y + $geometry.height * $Y)
    [PtcgWindowsUiE2E]::SetCursorPos($screenX, $screenY) | Out-Null
    Start-Sleep -Milliseconds 80
    [PtcgWindowsUiE2E]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [PtcgWindowsUiE2E]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

function Get-NormalizedImageDifference {
    param([string]$FirstPath, [string]$SecondPath)
    $first = [System.Drawing.Bitmap]::FromFile($FirstPath)
    $second = [System.Drawing.Bitmap]::FromFile($SecondPath)
    try {
        if ($first.Width -ne $second.Width -or $first.Height -ne $second.Height) { return 1.0 }
        $stepX = [math]::Max(1, [math]::Floor($first.Width / 48))
        $stepY = [math]::Max(1, [math]::Floor($first.Height / 48))
        $sum = 0.0
        $samples = 0
        for ($y = 0; $y -lt $first.Height; $y += $stepY) {
            for ($x = 0; $x -lt $first.Width; $x += $stepX) {
                $a = $first.GetPixel($x, $y)
                $b = $second.GetPixel($x, $y)
                $sum += ([math]::Abs([int]$a.R - [int]$b.R) + [math]::Abs([int]$a.G - [int]$b.G) + [math]::Abs([int]$a.B - [int]$b.B)) / 765.0
                $samples += 1
            }
        }
        return $sum / [math]::Max(1, $samples)
    } finally {
        $first.Dispose()
        $second.Dispose()
    }
}

$stdoutPath = Join-Path $ArtifactDirectory "stdout.log"
$stderrPath = Join-Path $ArtifactDirectory "stderr.log"
$previousWindow = [PtcgWindowsUiE2E]::GetForegroundWindow()
$previousCursor = New-Object PtcgWindowsUiE2E+POINT
[PtcgWindowsUiE2E]::GetCursorPos([ref]$previousCursor) | Out-Null
$process = $null
$geometry = $null
$navigationDifference = 0.0
$roundTripDifference = 1.0
$mainPath = ""
$settingsPath = ""
$returnPath = ""
try {
    $process = Start-Process -FilePath $ExecutablePath -ArgumentList "--verbose" -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $windowDeadline = (Get-Date).AddSeconds(30)
    do {
        Start-Sleep -Milliseconds 500
        $process.Refresh()
    } while ($process.MainWindowHandle -eq 0 -and -not $process.HasExited -and (Get-Date) -lt $windowDeadline)
    if ($process.HasExited -or $process.MainWindowHandle -eq 0) { throw "Windows game window did not open within 30 seconds" }

    $handle = $process.MainWindowHandle
    [PtcgWindowsUiE2E]::ShowWindow($handle, 9) | Out-Null
    [PtcgWindowsUiE2E]::SetWindowPos($handle, [IntPtr]::Zero, 80, 50, 0, 0, 0x0045) | Out-Null
    [PtcgWindowsUiE2E]::SetWindowPos($handle, [IntPtr](-1), 0, 0, 0, 0, 0x0043) | Out-Null
    [PtcgWindowsUiE2E]::SetForegroundWindow($handle) | Out-Null
    $geometry = Get-ClientGeometry -Handle $handle
    $minimumRenderedBytes = [math]::Round($geometry.width * $geometry.height * 0.08)
    $renderDeadline = (Get-Date).AddSeconds(45)
    do {
        Start-Sleep -Seconds 1
        [PtcgWindowsUiE2E]::SetWindowPos($handle, [IntPtr]::Zero, 80, 50, 0, 0, 0x0045) | Out-Null
        $geometry = Get-ClientGeometry -Handle $handle
        $mainPath = Save-WindowScreenshot -Handle $handle -Name "main"
    } while (($geometry.width -lt 1400 -or $geometry.height -lt 800 -or (Get-Item -LiteralPath $mainPath).Length -lt $minimumRenderedBytes) -and (Get-Date) -lt $renderDeadline)
    if ($geometry.width -lt 1400 -or $geometry.height -lt 800 -or (Get-Item -LiteralPath $mainPath).Length -lt $minimumRenderedBytes) { throw "Windows main menu did not finish rendering within 45 seconds" }

    # MainMenu BtnSettings in the desktop landscape action stack.
    Invoke-RealMouseClick -Handle $handle -X 0.5 -Y 0.703
    $navigationDeadline = (Get-Date).AddSeconds(20)
    do {
        Start-Sleep -Milliseconds 500
        $settingsPath = Save-WindowScreenshot -Handle $handle -Name "settings"
        $navigationDifference = Get-NormalizedImageDifference -FirstPath $mainPath -SecondPath $settingsPath
    } while ($navigationDifference -lt $MinimumNavigationDifference -and (Get-Date) -lt $navigationDeadline)

    # Settings BtnBack is the rightmost action at the bottom of the landscape panel.
    Invoke-RealMouseClick -Handle $handle -X 0.6 -Y 0.856
    $roundTripDeadline = (Get-Date).AddSeconds(20)
    do {
        Start-Sleep -Milliseconds 500
        $returnPath = Save-WindowScreenshot -Handle $handle -Name "main_return"
        $roundTripDifference = Get-NormalizedImageDifference -FirstPath $mainPath -SecondPath $returnPath
    } while ($roundTripDifference -gt $MaximumRoundTripDifference -and (Get-Date) -lt $roundTripDeadline)
} finally {
    [PtcgWindowsUiE2E]::SetCursorPos($previousCursor.X, $previousCursor.Y) | Out-Null
    if ($previousWindow -ne [IntPtr]::Zero) { [PtcgWindowsUiE2E]::SetForegroundWindow($previousWindow) | Out-Null }
    if ($null -ne $process -and -not $process.HasExited) {
        if ($process.MainWindowHandle -ne 0) { [PtcgWindowsUiE2E]::SetWindowPos($process.MainWindowHandle, [IntPtr](-2), 0, 0, 0, 0, 0x0043) | Out-Null }
        $process.CloseMainWindow() | Out-Null
        if (-not $process.WaitForExit(3000)) { Stop-Process -Id $process.Id -Force }
    }
}

$logs = ""
foreach ($path in @($stdoutPath, $stderrPath)) {
    if (Test-Path -LiteralPath $path) { $logs += [System.IO.File]::ReadAllText($path) + "`n" }
}
$failureLines = ($logs -split "`r?`n" | Select-String -Pattern "SCRIPT ERROR|FATAL|CRASH|Unhandled Exception") -join "`n"
$result = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    executable = (Resolve-Path -LiteralPath $ExecutablePath).Path
    client_size = "$($geometry.width)x$($geometry.height)"
    navigation_difference = [math]::Round($navigationDifference, 4)
    minimum_navigation_difference = $MinimumNavigationDifference
    round_trip_difference = [math]::Round($roundTripDifference, 4)
    maximum_round_trip_difference = $MaximumRoundTripDifference
    screenshots = [ordered]@{ main = $mainPath; settings = $settingsPath; main_return = $returnPath }
    runtime_failure_markers = $failureLines
    passed = ($navigationDifference -ge $MinimumNavigationDifference -and $roundTripDifference -le $MaximumRoundTripDifference -and -not $failureLines)
}
$reportPath = Join-Path $ArtifactDirectory "report.json"
$json = $result | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($reportPath, $json, [System.Text.UTF8Encoding]::new($false))
Write-Output $json
if (-not $result.passed) { throw "Windows real-input UI E2E failed; see $reportPath" }
