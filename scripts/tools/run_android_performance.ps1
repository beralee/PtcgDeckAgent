param(
    [Parameter(Mandatory=$true)][string]$Device,
    [Parameter(Mandatory=$true)][string]$Apk,
    [Parameter(Mandatory=$true)][string]$OutputRoot,
    [ValidateSet('all','components','navigation','battle','author_start','matches')][string]$Group = 'all',
    [ValidateRange(1,30)][int]$Runs = 3,
    [ValidateRange(1,30)][int]$Repeat = 3,
    [ValidateRange(30,3600)][int]$TimeoutSeconds = 600,
    [string]$Adb = "$env:LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe",
    [string]$Aapt = "$env:LOCALAPPDATA/Android/Sdk/build-tools/36.1.0/aapt.exe"
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$package = 'com.example.ptcgdeckagent.performance'
$remote = "/sdcard/Android/data/$package/files/performance"
$apkPath = (Resolve-Path -LiteralPath $Apk).Path
$badging = & $Aapt dump badging $apkPath
if ($LASTEXITCODE -ne 0 -or -not ($badging -match ("^package: name='" + [regex]::Escape($package) + "' "))) {
    throw 'Refusing to install or clear data: APK is not the isolated performance package.'
}
if (Test-Path -LiteralPath $OutputRoot) { throw 'Output directory already exists; use a new evidence directory.' }
$null = New-Item -ItemType Directory -Path $OutputRoot
$outputDirectory = (Resolve-Path -LiteralPath $OutputRoot).Path
function Invoke-Adb([string[]]$Arguments) {
    $result = & $Adb -s $Device @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "ADB operation failed: $($Arguments[0]) $result" }
    return $result
}
Invoke-Adb @('get-state') | Out-Null
Invoke-Adb @('install','-r',$apkPath) | Out-Null
$encoding = [Text.UTF8Encoding]::new($false)
$reports = @()
@{
    device = $Device
    apkSha256 = (Get-FileHash -LiteralPath $apkPath).Hash
    packageId = $package
    group = $Group
    repeat = $Repeat
    runs = $Runs
    deviceProperties = @(& $Adb -s $Device shell getprop ro.product.model; & $Adb -s $Device shell getprop ro.build.version.release; & $Adb -s $Device shell getprop ro.product.cpu.abi; & $Adb -s $Device shell getprop ro.kernel.qemu)
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputDirectory 'device.json') -Encoding UTF8
for ($iteration = 1; $iteration -le $Runs; $iteration++) {
    $runDirectory = Join-Path $outputDirectory ('run-{0:D2}' -f $iteration)
    $null = New-Item -ItemType Directory -Path $runDirectory
    # Only the verified diagnostic package is cleared; never the installed game.
    Invoke-Adb @('shell','am','force-stop',$package) | Out-Null
    Invoke-Adb @('shell','pm','clear',$package) | Out-Null
    $request = Join-Path $runDirectory 'request.json'
    [IO.File]::WriteAllText($request, (@{group=$Group;repeat=$Repeat} | ConvertTo-Json -Compress), $encoding)
    Invoke-Adb @('shell','am','start','-W','-n',"$package/com.godot.game.GodotAppLauncher") | Out-Null
    $appProcess = (Invoke-Adb @('shell','pidof',$package) | Out-String).Trim()
    if ($appProcess -notmatch '^\d+$') { throw 'Diagnostic process did not start.' }
    Write-Output "Android performance run $iteration/$Runs on $Device (process $appProcess)"
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while ($timer.Elapsed.TotalSeconds -lt 60) {
        $probe = & $Adb -s $Device shell ls -d $remote 2>$null
        if ($LASTEXITCODE -eq 0) { break }
        Start-Sleep -Milliseconds 200
    }
    Invoke-Adb @('push',$request,"$remote/request.json") | Out-Null
    $complete = $false
    while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $probe = & $Adb -s $Device shell ls "$remote/result.json" 2>$null
        if ($LASTEXITCODE -eq 0) { $complete = $true; break }
        $alive = & $Adb -s $Device shell pidof $package 2>$null
        if ($LASTEXITCODE -ne 0) { break }
        Start-Sleep -Seconds 2
    }
    $log = & $Adb -s $Device logcat -d "--pid=$appProcess" -v brief
    [IO.File]::WriteAllText((Join-Path $runDirectory 'result.log'), ($log -join "`n"), $encoding)
    if (-not $complete) {
        Invoke-Adb @('shell','am','force-stop',$package) | Out-Null
        throw "Diagnostic timed out; its process log is in $runDirectory."
    }
    $report = Join-Path $runDirectory 'result.json'
    Invoke-Adb @('pull',"$remote/result.json",$report) | Out-Null
    $reports += $report
}
& python (Join-Path $PSScriptRoot 'run_performance_bench.py') --import-reports @reports --group $Group --repeat $Repeat --output (Join-Path $outputDirectory 'aggregate')
if ($LASTEXITCODE -ne 0) { throw 'Android reports failed validation; inspect aggregate/report.json.' }
