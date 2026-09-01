param(
    [string]$GodotPath = "D:\ai\godot\Godot_v4.6.1-stable_win64.exe",
    [string]$DataRoot = "",
    [int]$Port = 8875
)

$ErrorActionPreference = "Stop"

function New-SessionBearer {
    $bytes = New-Object byte[] 48
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
    } finally {
        $generator.Dispose()
    }
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+','-').Replace('/','_')
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if (-not $DataRoot) {
    $DataRoot = Join-Path $env:LOCALAPPDATA "PtcgDAP\platform-development"
}
$DataRoot = [System.IO.Path]::GetFullPath($DataRoot)
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}
if ($Port -lt 1024 -or $Port -gt 65535) {
    throw "Port must be between 1024 and 65535."
}
if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) {
    throw "Port $Port is already in use. Choose another port with -Port."
}

$logRoot = Join-Path $DataRoot "logs"
New-Item -ItemType Directory -Force -Path $DataRoot,$logRoot | Out-Null
$replayToken = New-SessionBearer
$platformToken = New-SessionBearer

$previousReplayToken = $env:PTCGDAP_REPLAY_UPLOAD_TOKEN
$previousPlatformToken = $env:PTCGDAP_PLATFORM_WRITE_TOKEN
$previousReplayBaseUrl = $env:PTCGDAP_REPLAY_BASE_URL
$previousPlatformBaseUrl = $env:PTCGDAP_PLATFORM_BASE_URL
$service = $null
try {
    $env:PTCGDAP_REPLAY_UPLOAD_TOKEN = $replayToken
    $env:PTCGDAP_PLATFORM_WRITE_TOKEN = $platformToken
    $env:PTCGDAP_REPLAY_BASE_URL = "http://127.0.0.1:$Port"
    $env:PTCGDAP_PLATFORM_BASE_URL = "http://127.0.0.1:$Port"
    $service = Start-Process -FilePath "python" -ArgumentList @(
        "-m", "services.ptcgdap_replay",
        "--data-root", $DataRoot,
        "--host", "127.0.0.1",
        "--port", "$Port",
        "--seed-development-catalog"
    ) -WorkingDirectory $repoRoot -WindowStyle Hidden -PassThru `
      -RedirectStandardOutput (Join-Path $logRoot "service.stdout.log") `
      -RedirectStandardError (Join-Path $logRoot "service.stderr.log")

    $deadline = (Get-Date).AddSeconds(12)
    do {
        Start-Sleep -Milliseconds 100
        if ($service.HasExited) {
            $errorText = Get-Content -LiteralPath (Join-Path $logRoot "service.stderr.log") -Raw -ErrorAction SilentlyContinue
            throw "Local platform service failed to start. $errorText"
        }
        $listener = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    } until ($listener -or (Get-Date) -gt $deadline)
    if (-not $listener) {
        throw "Local platform service did not become ready within 12 seconds."
    }
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/healthz" -Method Get
    if ($health.status -ne "ok") {
        throw "Local platform service health check failed."
    }

    Write-Host "Local replay service is ready. Completed public replays will be saved and uploaded locally."
    $game = Start-Process -FilePath $GodotPath -ArgumentList @("--path", $repoRoot) -PassThru
    $game.WaitForExit()
} finally {
    $env:PTCGDAP_REPLAY_UPLOAD_TOKEN = $previousReplayToken
    $env:PTCGDAP_PLATFORM_WRITE_TOKEN = $previousPlatformToken
    $env:PTCGDAP_REPLAY_BASE_URL = $previousReplayBaseUrl
    $env:PTCGDAP_PLATFORM_BASE_URL = $previousPlatformBaseUrl
    if ($null -ne $service -and -not $service.HasExited) {
        Stop-Process -Id $service.Id
        $service.WaitForExit(3000) | Out-Null
    }
}
