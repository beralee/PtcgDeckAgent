param(
    [string]$AdbPath = "C:\Users\24726\AppData\Local\Android\Sdk\platform-tools\adb.exe",
    [string]$PackageName = "com.example.ptcgdeckagent",
    [string]$ActivityName = "com.godot.game.GodotAppLauncher",
    [string]$ApkPath = "D:\ai\code\ptcgdojopage\downloads\ptcgdeckagent-android.apk",
    [string]$ArtifactDirectory = "",
    [switch]$SkipProvision,
    [double]$MinimumNavigationDifference = 0.08,
    [double]$MaximumRoundTripDifference = 0.12
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if (-not $ArtifactDirectory) {
    $ArtifactDirectory = Join-Path $repoRoot ".tmp\android_ui_e2e"
}
New-Item -ItemType Directory -Force -Path $ArtifactDirectory | Out-Null

$deviceReason = ""
if (-not (Test-Path -LiteralPath $AdbPath)) {
    $deviceReason = "Android platform tools are unavailable"
} else {
    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $deviceOutput = & $AdbPath get-state 2>&1
        $deviceExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorPreference
    }
    if ($deviceExit -ne 0 -or (($deviceOutput -join "").Trim()) -ne "device") {
        $deviceReason = "One ready Android device is required"
    }
}
if ($deviceReason) {
    $preflight = [ordered]@{ schema_version = 1; platform = "Android"; status = "not_verified"; reason = $deviceReason }
    $preflightJson = $preflight | ConvertTo-Json
    [IO.File]::WriteAllText((Join-Path $ArtifactDirectory "report.json"), $preflightJson, [Text.UTF8Encoding]::new($false))
    Write-Host $preflightJson
    exit 2
}

if (-not $SkipProvision) {
	if (-not $PSBoundParameters.ContainsKey('ApkPath')) {
		$exportScript = Join-Path $repoRoot "scripts\tools\export_ptcgdap_device_release.ps1"
		$releaseRoot = Join-Path $repoRoot ".tmp\ptcgdap_device_release\android-ui-e2e-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
		& powershell -ExecutionPolicy Bypass -File $exportScript -AndroidOnly -PlayerRelease -AndroidBuildMode Release -OutputDirectory $releaseRoot
		if ($LASTEXITCODE -ne 0) { throw "Android export failed with exit code $LASTEXITCODE" }
		$ApkPath = Join-Path $releaseRoot "PtcgDeckAgent.apk"
	}
	if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) { throw "APK not found: $ApkPath" }
	if (-not (Test-Path -LiteralPath $AdbPath)) { throw "adb.exe not found: $AdbPath" }
	$installOutput = & $AdbPath install -r $ApkPath 2>&1
	if ($LASTEXITCODE -ne 0) { throw "Android install failed with exit code $LASTEXITCODE`n$(($installOutput | Out-String).Trim())" }
}

if (-not (Test-Path -LiteralPath $AdbPath)) { throw "adb.exe not found: $AdbPath" }
$deviceState = ((& $AdbPath get-state 2>$null) -join "").Trim()
if ($deviceState -ne "device") { throw "A ready Android device is required; adb state was '$deviceState'" }

function Invoke-AdbChecked {
    param([string[]]$Arguments, [string]$Label)
    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & $AdbPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorPreference
    if ($exitCode -ne 0) {
        throw "$Label failed with exit code $exitCode`n$(($output | Out-String).Trim())"
    }
    return $output
}

function Save-DeviceScreenshot {
    param([string]$Name)
    $devicePath = "/sdcard/ptcg_ui_e2e_$Name.png"
    $localPath = Join-Path $ArtifactDirectory "$Name.png"
    Invoke-AdbChecked -Arguments @("shell", "screencap", "-p", $devicePath) -Label "Capture $Name screenshot" | Out-Null
    Invoke-AdbChecked -Arguments @("pull", $devicePath, $localPath) -Label "Pull $Name screenshot" | Out-Null
    return $localPath
}

function Invoke-NormalizedTap {
    param([double]$X, [double]$Y, [int]$Width, [int]$Height)
    $pixelX = [math]::Round($X * $Width)
    $pixelY = [math]::Round($Y * $Height)
    Invoke-AdbChecked -Arguments @("shell", "input", "tap", "$pixelX", "$pixelY") -Label "Tap ($pixelX,$pixelY)" | Out-Null
}

Add-Type -AssemblyName System.Drawing
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

$sizeText = ((Invoke-AdbChecked -Arguments @("shell", "wm", "size") -Label "Read display size") -join " ")
if ($sizeText -notmatch "(\d+)x(\d+)") { throw "Unable to parse Android display size: $sizeText" }
$width = [int]$Matches[1]
$height = [int]$Matches[2]
if ($height -le $width) { throw "Android UI E2E requires portrait orientation; found ${width}x${height}" }

Invoke-AdbChecked -Arguments @("shell", "am", "force-stop", $PackageName) -Label "Stop app" | Out-Null
Invoke-AdbChecked -Arguments @("logcat", "-c") -Label "Clear logcat" | Out-Null
Invoke-AdbChecked -Arguments @("shell", "am", "start", "-n", "$PackageName/$ActivityName") -Label "Launch app" | Out-Null

$startupDeadline = (Get-Date).AddSeconds(20)
$appPid = ""
$focus = ""
do {
    Start-Sleep -Seconds 1
    try {
        $appPid = ((Invoke-AdbChecked -Arguments @("shell", "pidof", $PackageName) -Label "Read app PID") -join "").Trim()
    } catch {
        $appPid = ""
    }
    if ($appPid) {
        $focus = ((Invoke-AdbChecked -Arguments @("shell", "dumpsys", "window") -Label "Read focused window") | Select-String -Pattern "mCurrentFocus|mFocusedApp" | Select-Object -First 5) -join "`n"
    }
} while ((-not $appPid -or $focus -notmatch [regex]::Escape($PackageName)) -and (Get-Date) -lt $startupDeadline)
if (-not $appPid) { throw "Android app process did not start within 20 seconds" }
if ($focus -notmatch [regex]::Escape($PackageName)) { throw "Android app did not gain focus within 20 seconds:`n$focus" }

$runtimeReadyDeadline = (Get-Date).AddSeconds(75)
$runtimeReady = $false
do {
    $startupLog = ((Invoke-AdbChecked -Arguments @("logcat", "-d", "-t", "1600") -Label "Read startup log") -join "`n")
    if (
        $startupLog.Contains("[UserVisit] startup visit recorded") -or
        $startupLog.Contains("OnGodotMainLoopStarted")
    ) {
        $runtimeReady = $true
        break
    }
    Start-Sleep -Milliseconds 500
} while ((Get-Date) -lt $runtimeReadyDeadline)
if (-not $runtimeReady) {
    throw "Android runtime did not reach the main loop before baseline capture."
}

$renderDeadline = (Get-Date).AddSeconds(45)
$minimumRenderedBytes = [math]::Round($width * $height * 0.05)
$mainPath = ""
do {
    Start-Sleep -Seconds 2
    $mainPath = Save-DeviceScreenshot -Name "main"
} while ((Get-Item -LiteralPath $mainPath).Length -lt $minimumRenderedBytes -and (Get-Date) -lt $renderDeadline)
if ((Get-Item -LiteralPath $mainPath).Length -lt $minimumRenderedBytes) {
    throw "Main menu did not finish rendering within 45 seconds"
}

# Open the AI strategy hub, then its embedded DeepSeek workspace.
Invoke-NormalizedTap -X 0.5 -Y 0.748 -Width $width -Height $height
$navigationDeadline = (Get-Date).AddSeconds(30)
$navigationDifference = 0.0
$settingsPath = ""
$workspaceActive = $false
do {
    Invoke-NormalizedTap -X 0.85 -Y 0.10 -Width $width -Height $height
    Start-Sleep -Seconds 1
    $settingsPath = Save-DeviceScreenshot -Name "settings"
    $navigationDifference = Get-NormalizedImageDifference -FirstPath $mainPath -SecondPath $settingsPath
    # The cyan active tab is rendered only after the hub replaces the loading
    # overlay. A whole-image difference alone accepts the dark loading screen.
    $bitmap = [Drawing.Bitmap]::FromFile($settingsPath)
    try {
        $pixel = $bitmap.GetPixel([int]($width * 0.85), [int]($height * 0.082))
        $workspaceActive = $pixel.R -lt 125 -and $pixel.G -gt 130 -and $pixel.B -gt 150
    } finally { $bitmap.Dispose() }
} while (-not $workspaceActive -and (Get-Date) -lt $navigationDeadline)
if (-not $workspaceActive) { throw "DeepSeek workspace did not become active within 30 seconds" }

# StrategyHub BackButton stays at the top-left in portrait mode.
Invoke-NormalizedTap -X 0.09 -Y 0.039 -Width $width -Height $height
$roundTripDeadline = (Get-Date).AddSeconds(20)
$roundTripDifference = 1.0
$returnPath = ""
do {
    Start-Sleep -Seconds 1
    $returnPath = Save-DeviceScreenshot -Name "main_return"
    $roundTripDifference = Get-NormalizedImageDifference -FirstPath $mainPath -SecondPath $returnPath
} while ($roundTripDifference -gt $MaximumRoundTripDifference -and (Get-Date) -lt $roundTripDeadline)
$logText = ((Invoke-AdbChecked -Arguments @("logcat", "-d", "-t", "1200") -Label "Read logcat") -join "`n")
$failureLines = ($logText -split "`r?`n" | Select-String -Pattern "FATAL EXCEPTION|Fatal signal|AndroidRuntime: FATAL|ANR in|SCRIPT ERROR") -join "`n"

$result = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    device_size = "${width}x${height}"
    pid = $appPid
    focus = $focus
    navigation_difference = [math]::Round($navigationDifference, 4)
    deepseek_workspace_active = $workspaceActive
    minimum_navigation_difference = $MinimumNavigationDifference
    round_trip_difference = [math]::Round($roundTripDifference, 4)
    maximum_round_trip_difference = $MaximumRoundTripDifference
    screenshots = [ordered]@{ main = $mainPath; settings = $settingsPath; main_return = $returnPath }
    crash_markers = $failureLines
    passed = ($navigationDifference -ge $MinimumNavigationDifference -and $roundTripDifference -le $MaximumRoundTripDifference -and -not $failureLines)
}
$reportPath = Join-Path $ArtifactDirectory "report.json"
$json = $result | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($reportPath, $json, [System.Text.UTF8Encoding]::new($false))
Write-Output $json
if (-not $result.passed) { throw "Android real-input UI E2E failed; see $reportPath" }
