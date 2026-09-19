param(
    [Parameter(Mandatory=$true)][string]$Package,
    [string]$Adb = 'C:/Users/24726/AppData/Local/Android/Sdk/platform-tools/adb.exe',
    [int]$AdbServerPort = 5039,
    [string]$Device = 'emulator-5554',
    [string]$ExportRoot = '.tmp/android_strategy_parity/exports',
    [string]$OutputRoot = '.tmp/android_strategy_parity/runs',
    [int]$TimeoutSeconds = 900,
    [switch]$Online
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location -LiteralPath $projectRoot
$packagePath = (Resolve-Path -LiteralPath $Package).Path
$exports = (Resolve-Path -LiteralPath $ExportRoot).Path
$buildManifest = Get-Content -LiteralPath (Join-Path $exports 'build.json') -Raw | ConvertFrom-Json
if ((Get-FileHash -LiteralPath (Join-Path $exports 'PtcgDeckAgent-parity.apk')).Hash -ne $buildManifest.apkSha256 -or (Get-FileHash -LiteralPath (Join-Path $exports 'PtcgDeckAgent-parity.exe')).Hash -ne $buildManifest.windowsSha256) { throw 'Export artifact hashes do not match build.json.' }
$runId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$runRoot = Join-Path $OutputRoot $runId
$null = New-Item -ItemType Directory -Force -Path $runRoot
$runRoot = (Resolve-Path -LiteralPath $runRoot).Path
Copy-Item -LiteralPath (Join-Path $exports 'build.json') -Destination (Join-Path $runRoot 'build.json')
$deviceRoot = '/sdcard/Android/data/com.example.ptcgdeckagent/files/strategy-parity'
$remoteRun = "$deviceRoot/$runId"
$packageSha = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash
function Invoke-Adb([string[]]$Arguments) {
    $result = & $Adb -P $AdbServerPort -s $Device @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "ADB failed: $($Arguments -join ' '): $result" }
    return ($result -join "`n")
}
& $Adb -P $AdbServerPort start-server | Out-Null
$deviceAbi = (Invoke-Adb @('shell','getprop','ro.product.cpu.abi')).Trim()
if (-not $buildManifest.androidAbi -or $buildManifest.androidAbi -ne $deviceAbi) {
    throw "Build a native $deviceAbi APK for this device. ARM translation is not accepted as a clean regression target."
}
$wifiWasOn = (Invoke-Adb @('shell','settings','get','global','wifi_on')).Trim()
$dataWasOn = (Invoke-Adb @('shell','settings','get','global','mobile_data')).Trim()
$pcProcess = $null
try {
    Invoke-Adb @('install','--no-incremental','-r',(Join-Path $exports 'PtcgDeckAgent-parity.apk')) | Out-Null
    Invoke-Adb @('shell','am','force-stop','com.example.ptcgdeckagent') | Out-Null
    if (-not $Online) {
        Invoke-Adb @('shell','svc','wifi','disable') | Out-Null
        Invoke-Adb @('shell','svc','data','disable') | Out-Null
    }
    # Let the app create its own scoped-storage directory. A directory made
    # by adb belongs to shell and may be unreadable after a fresh installation.
    & $Adb -P $AdbServerPort -s $Device shell test -d $deviceRoot 2>$null
    if ($LASTEXITCODE -eq 0) { Invoke-Adb @('shell','mv',$deviceRoot,"$deviceRoot-archive-$runId") | Out-Null }
    Invoke-Adb @('shell','am','start','-n','com.example.ptcgdeckagent/com.godot.game.GodotAppLauncher') | Out-Null
    $bootstrapDeadline = (Get-Date).AddSeconds(120)
    $storageReady = $false
    while ((Get-Date) -lt $bootstrapDeadline) {
        & $Adb -P $AdbServerPort -s $Device shell test -d $deviceRoot 2>$null
        if ($LASTEXITCODE -eq 0) { $storageReady=$true; break }
        Start-Sleep -Seconds 2
    }
    if (-not $storageReady) { throw 'App did not initialize its scoped-storage directory.' }
    Invoke-Adb @('shell','am','force-stop','com.example.ptcgdeckagent') | Out-Null
    Invoke-Adb @('push',$packagePath,"$deviceRoot/package-$runId.ptcgai") | Out-Null
    $request = @{package_path="$deviceRoot/package-$runId.ptcgai";output_dir=$remoteRun}
    $requestPath = Join-Path $runRoot 'request.json'
    [IO.File]::WriteAllText($requestPath,($request | ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
    Invoke-Adb @('push',$requestPath,"$deviceRoot/request.json") | Out-Null
    $previousAppData = $env:APPDATA
    $env:APPDATA = Join-Path $runRoot 'pc-user'
    $null = New-Item -ItemType Directory -Force -Path $env:APPDATA
    $pcOutput = Join-Path $runRoot 'pc'
    try {
        $pcArguments = @('--headless','--log-file',('"' + (Join-Path $runRoot 'pc.log') + '"'),'--',('--parity-package="' + $packagePath + '"'),('--parity-output="' + $pcOutput + '"'))
        $pcProcess = Start-Process -FilePath (Join-Path $exports 'PtcgDeckAgent-parity.exe') -WorkingDirectory $exports -ArgumentList $pcArguments -WindowStyle Hidden -PassThru
    } finally { $env:APPDATA = $previousAppData }
    Invoke-Adb @('logcat','-c') | Out-Null
    Invoke-Adb @('shell','am','start','-n','com.example.ptcgdeckagent/com.godot.game.GodotAppLauncher') | Out-Null
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $complete = $false
    while ((Get-Date) -lt $deadline) {
        $exists = & $Adb -P $AdbServerPort -s $Device shell test -f "$remoteRun/complete.json" 2>$null
        $androidDone = $LASTEXITCODE -eq 0
        $pcProcess.Refresh()
        $pcLogPath = Join-Path $runRoot 'pc.log'
        if ((Test-Path -LiteralPath $pcLogPath) -and (Select-String -LiteralPath $pcLogPath -Pattern 'SCRIPT ERROR|Failed to instantiate an autoload' -Quiet)) { throw 'PC startup/runtime error; see pc.log.' }
        if ($androidDone -and $pcProcess.HasExited) { $complete = $true; break }
        if ($pcProcess.HasExited -and -not (Test-Path -LiteralPath (Join-Path $pcOutput 'complete.json'))) { throw 'PC exited without a complete report.' }
        Start-Sleep -Seconds 2
    }
    if (-not $complete) { throw "Parity run exceeded $TimeoutSeconds seconds." }
    if ($pcProcess.ExitCode -ne 0) { throw "PC failed with exit code $($pcProcess.ExitCode)." }
    # Completion is written just before engine teardown. Give Android's crash
    # reporter time to flush so a shutdown abort cannot masquerade as success.
    Start-Sleep -Seconds 5
    Invoke-Adb @('pull',"$remoteRun/.",(Join-Path $runRoot 'android')) | Out-Null
    Invoke-Adb @('logcat','-d','-s','godot','libc:F','DEBUG:F') | Set-Content -LiteralPath (Join-Path $runRoot 'android.log') -Encoding UTF8
    $logs = (Get-Content -LiteralPath (Join-Path $runRoot 'android.log') -Raw) + (Get-Content -LiteralPath (Join-Path $runRoot 'pc.log') -Raw)
    if ($logs -match 'SCRIPT ERROR|Error calling from signal|Fatal signal|Scudo ERROR|resources still in use at exit') { throw 'Runtime error, leaked resources or native crash recorded; see run logs.' }
    & python (Join-Path $PSScriptRoot 'compare_android_strategy_parity.py') (Join-Path $runRoot 'android') $pcOutput --output (Join-Path $runRoot 'comparison.json')
    if ($LASTEXITCODE -ne 0) { throw 'Public decision parity failed; see comparison.json.' }
    @{runId=$runId;packageSha256=$packageSha;offline=(-not $Online);device=$Device;deviceAbi=$deviceAbi;complete=$true} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runRoot 'run.json') -Encoding UTF8
    Write-Output "PASS: $runRoot"
} catch {
    @{complete=$false;error=$_.Exception.Message;runId=$runId} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runRoot 'failure.json') -Encoding UTF8
    & $Adb -P $AdbServerPort -s $Device logcat -d -s godot 'libc:F' 'DEBUG:F' | Set-Content -LiteralPath (Join-Path $runRoot 'android.log') -Encoding UTF8
    & $Adb -P $AdbServerPort -s $Device pull "$remoteRun/." (Join-Path $runRoot 'android-partial') 2>$null | Out-Null
    throw
} finally {
    if ($pcProcess -and -not $pcProcess.HasExited) { Stop-Process -Id $pcProcess.Id }
    if (-not $complete) { & $Adb -P $AdbServerPort -s $Device shell am force-stop com.example.ptcgdeckagent | Out-Null }
    if (-not $Online) {
        if ($wifiWasOn -eq '1') { Invoke-Adb @('shell','svc','wifi','enable') | Out-Null }
        if ($dataWasOn -eq '1') { Invoke-Adb @('shell','svc','data','enable') | Out-Null }
    }
    # Retain all per-run evidence. Only remove this tool's activation pointer.
    & $Adb -P $AdbServerPort -s $Device shell rm -f "$deviceRoot/request.json" | Out-Null
}
