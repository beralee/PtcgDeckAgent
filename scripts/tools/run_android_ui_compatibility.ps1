param(
    [Parameter(Mandatory=$true)][string]$Serial,
    [Parameter(Mandatory=$true)][string]$ApkPath,
    [string]$AdbPath = "$env:LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe",
    [int]$AdbServerPort = 5037
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$out = Join-Path $repo '.tmp/ui_compatibility/android'
New-Item -ItemType Directory -Force -Path $out | Out-Null
@{serial=$Serial;passed=$false;status='running'} | ConvertTo-Json | Set-Content (Join-Path $out 'report.json') -Encoding utf8
function Invoke-Adb([string[]]$Arguments) {
    $response = & $AdbPath -P $AdbServerPort -s $Serial @Arguments
    if ($LASTEXITCODE -ne 0) { throw "adb failed: $($Arguments[0]) on $Serial" }
    return $response
}
Invoke-Adb @('install','--no-incremental','-r',(Resolve-Path -LiteralPath $ApkPath).Path)
Invoke-Adb @('shell','am','force-stop','com.example.ptcgdeckagent')
# Only this explicitly selected test device: dismiss Android's first-use fullscreen coachmark.
Invoke-Adb @('shell','settings','put','secure','immersive_mode_confirmations','confirmed')
Invoke-Adb @('logcat','-c')
Invoke-Adb @('shell','am','start','-n','com.example.ptcgdeckagent/com.godot.game.GodotAppLauncher')
# These normalized coordinates are the shipped portrait menu/tab layout.
$sizeLine = (Invoke-Adb @('shell','wm','size')) -join ' '
if ($sizeLine -notmatch '(\d+)x(\d+)') { throw 'Unable to read screen dimensions' }
$screenWidth = [int]$Matches[1]; $screenHeight = [int]$Matches[2]
function Tap([double]$x, [double]$y) { Invoke-Adb @('shell','input','tap',[string][int]($screenWidth*$x),[string][int]($screenHeight*$y)) }
function Capture([string]$name) {
    Invoke-Adb @('shell','screencap','-p',"/sdcard/$name.png")
    Invoke-Adb @('pull',"/sdcard/$name.png",(Join-Path $out "$name.png"))
}
Start-Sleep -Seconds 15
if (-not (Invoke-Adb @('shell','pidof','com.example.ptcgdeckagent'))) { throw 'Application exited before navigation' }
Tap 0.5 0.742
Start-Sleep -Seconds 5
Tap 0.833 0.102
Start-Sleep -Seconds 3
Capture 'settings-before'
Invoke-Adb @('shell','input','swipe',[string][int]($screenWidth*0.5),[string][int]($screenHeight*0.77),[string][int]($screenWidth*0.5),[string][int]($screenHeight*0.28),'700')
Start-Sleep -Seconds 2
Capture 'settings-after'
$log = (Invoke-Adb @('logcat','-d','-s','godot')) -join "`n"
$log | Set-Content (Join-Path $out 'device.log') -Encoding utf8
$gestures = @([regex]::Matches($log, 'UI_COMPAT_GESTURE=(\{[^\r\n]+\})') | ForEach-Object { $_.Groups[1].Value | ConvertFrom-Json })
$settingsOpened = @($gestures | Where-Object { $_.button -eq 'AISettingsTab' }).Count -gt 0
$passed = $settingsOpened -and @($gestures | Where-Object { $_.dragged -and $_.scroll -eq 'AISettingsWorkspace' -and $_.scroll_delta -gt 100 }).Count -gt 0
@{serial=$Serial;passed=$passed;gestures=$gestures;apk_sha256=(Get-FileHash -LiteralPath $ApkPath).Hash} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $out 'report.json') -Encoding utf8
if (-not $passed) { throw 'Android drag did not move the settings viewport. Use a portrait review APK with --ptcgdap-ui-input-probe and inspect captured evidence.' }
