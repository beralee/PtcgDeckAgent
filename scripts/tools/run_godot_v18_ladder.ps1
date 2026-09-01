param(
    [string]$GodotExecutable = "D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe",
    [string]$LinuxTemplate = "",
    [switch]$RotateSecrets,
    [switch]$SkipExport
)

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$deploymentRoot = Join-Path $repositoryRoot "deploy\godot-v18-ladder"
$runtimeRoot = Join-Path $deploymentRoot "runtime"
$environmentPath = Join-Path $deploymentRoot ".env.local"
$pckPath = Join-Path $runtimeRoot "godot_v18_competition.pck"
$linuxBinaryPath = Join-Path $runtimeRoot "linux_release.x86_64"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker Desktop is required."
}
if ([string]::IsNullOrWhiteSpace($LinuxTemplate)) {
    $LinuxTemplate = Join-Path $env:APPDATA "Godot\export_templates\4.6.1.stable\linux_release.x86_64"
}
if (-not (Test-Path -LiteralPath $GodotExecutable -PathType Leaf)) {
    throw "Godot 4.6.1 console executable was not found: $GodotExecutable"
}
if (-not (Test-Path -LiteralPath $LinuxTemplate -PathType Leaf)) {
    throw "Godot 4.6.1 Linux x86_64 export template was not found: $LinuxTemplate"
}

New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
if (-not $SkipExport) {
    $activeGodot = @(Get-Process -Name "Godot*" -ErrorAction SilentlyContinue)
    if ($activeGodot.Count -gt 0) {
        throw "Close other Godot processes before exporting the competition Server PCK."
    }
    $operatingSystem = Get-CimInstance Win32_OperatingSystem
    $availableGiB = [double]$operatingSystem.FreePhysicalMemory / 1MB
    $commitPercent = (Get-Counter "\Memory\% Committed Bytes In Use").CounterSamples.CookedValue
    if ($availableGiB -lt 12 -or $commitPercent -ge 70) {
        throw "Resource safety gate refused export: require 12 GiB available RAM and commit below 70%."
    }
    Copy-Item -LiteralPath $LinuxTemplate -Destination $linuxBinaryPath -Force
    & $GodotExecutable --headless --path $repositoryRoot --export-pack "Godot V18 Competition Linux Server" $pckPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $pckPath -PathType Leaf)) {
        throw "Godot Server PCK export failed."
    }
}
if (-not (Test-Path -LiteralPath $linuxBinaryPath -PathType Leaf) -or -not (Test-Path -LiteralPath $pckPath -PathType Leaf)) {
    throw "Runtime artifacts are missing; rerun without -SkipExport."
}

if ($RotateSecrets -and (Test-Path -LiteralPath $environmentPath -PathType Leaf)) {
    Remove-Item -LiteralPath $environmentPath -Force
}
if (-not (Test-Path -LiteralPath $environmentPath -PathType Leaf)) {
    python -m services.ptcgdap_replay.local_ladder_bootstrap `
        --repository-root $repositoryRoot `
        --godot-binary $linuxBinaryPath `
        --pck $pckPath `
        --env-file $environmentPath
    if ($LASTEXITCODE -ne 0) {
        throw "Local ladder secret and runtime identity bootstrap failed."
    }
}

docker compose --env-file $environmentPath -f (Join-Path $deploymentRoot "compose.yaml") up --build -d
if ($LASTEXITCODE -ne 0) {
    throw "Local ladder Compose startup failed."
}
Write-Host "Control: http://127.0.0.1:8765/"
Write-Host "Private admin: http://127.0.0.1:8765/control-admin/"
Write-Host "Mailpit: http://127.0.0.1:8025/"

