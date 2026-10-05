param(
    [string]$Executable = '',
    [string]$ExpectedVersion = '0.6.0'
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $Executable) { $Executable = Join-Path $repo '.tmp/game-updater-20260919/update-windows.exe' }
$Executable = (Resolve-Path -LiteralPath $Executable).Path
$root = Join-Path $repo ('.tmp/app-update-health-' + [Guid]::NewGuid().ToString('N'))
$token = [Guid]::NewGuid().ToString('N')
$appdata = Join-Path $root 'appdata'
$session = Join-Path $appdata ('Godot/app_userdata/PtcgDeckAgent/app_updates/' + $token)
New-Item -ItemType Directory -Force -Path $session | Out-Null
[IO.File]::WriteAllText((Join-Path $session 'plan.json'), (@{version=$ExpectedVersion} | ConvertTo-Json))
$savedAppdata = $env:APPDATA
$game = $null
try {
    $env:APPDATA = $appdata
    $game = Start-Process -FilePath $Executable -ArgumentList @('--headless', '--', ('--ptcg-update-token=' + $token)) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $root 'stdout.txt') -RedirectStandardError (Join-Path $root 'stderr.txt')
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    while (-not (Test-Path -LiteralPath (Join-Path $session 'healthy'))) {
        if ($game.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw 'Exported game did not confirm home startup.' }
        Start-Sleep -Milliseconds 200
        $game.Refresh()
    }
    if ([IO.File]::ReadAllText((Join-Path $session 'healthy')) -ne $ExpectedVersion) { throw 'Wrong exported startup receipt.' }
    if ((Get-Item -LiteralPath (Join-Path $root 'stderr.txt')).Length -gt 0) { throw 'Inspect exported-game errors before accepting startup.' }
    Write-Output "WINDOWS_EXPORTED_HOME_HEALTH_PASS: $ExpectedVersion"
    Write-Output "Evidence: $root"
} finally {
    if ($game -and -not $game.HasExited) { $game.Kill(); $game.WaitForExit(5000) | Out-Null }
    $env:APPDATA = $savedAppdata
}
