param([string]$OutputRoot = '')
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $OutputRoot) { $OutputRoot = Join-Path $repo ('.tmp/app-updater-windows-' + [Guid]::NewGuid().ToString('N')) }
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if (-not $OutputRoot.StartsWith((Join-Path $repo '.tmp') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Tests must remain in the repository temporary directory.' }
New-Item -ItemType Directory -Path $OutputRoot | Out-Null
$compiler = Join-Path $env:SystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$oldSource = @'
using System;
using System.IO;
using System.Threading;
public class Game {
    public static void Main(string[] args) {
        foreach (var arg in args) if (arg.StartsWith("--ptcg-update-rollback=")) return;
        Thread.Sleep(180000);
    }
}
'@
$newSource = @'
using System;
using System.IO;
using System.Threading;
public class Game {
    public static void Main(string[] args) {
        foreach (var arg in args) if (arg.StartsWith("--ptcg-update-token=")) {
            File.WriteAllText(Path.Combine(Environment.GetEnvironmentVariable("PTCG_UPDATER_TEST_ROOT"), arg.Substring(20), "healthy"), "0.7.0");
        }
        Thread.Sleep(180000);
    }
}
'@
function Compile-Game([string]$Source, [string]$Destination) {
    $sourceFile = "$Destination.cs"
    [IO.File]::WriteAllText($sourceFile, $Source)
    & $compiler /nologo /target:winexe "/out:$Destination" $sourceFile
    if ($LASTEXITCODE -ne 0) { throw 'Fixture compilation failed.' }
}
Compile-Game $oldSource (Join-Path $OutputRoot 'old.exe')
Compile-Game $newSource (Join-Path $OutputRoot 'new.exe')
Compile-Game 'public class Game { public static void Main() { } }' (Join-Path $OutputRoot 'bad.exe')
$previousTestRoot = $env:PTCG_UPDATER_TEST_ROOT
$env:PTCG_UPDATER_TEST_ROOT = $OutputRoot
$results = @()
try {
    foreach ($scenario in @('success', 'startup_rollback', 'archive_traversal', 'corrupt_hash', 'cancelled_preparation', 'unexpected_exit')) {
        $token = [Guid]::NewGuid().ToString('N')
        $session = Join-Path $OutputRoot $token
        $install = Join-Path $OutputRoot ($scenario + '-install')
        New-Item -ItemType Directory -Path $session,$install | Out-Null
        $exe = Join-Path $install 'Game.exe'
        Copy-Item -LiteralPath (Join-Path $OutputRoot 'old.exe') -Destination $exe
        [IO.File]::WriteAllText((Join-Path $install 'my-deck.json'), 'player-data')
        $oldHash = (Get-FileHash -LiteralPath $exe).Hash
        $zip = Join-Path $session 'package.zip'
        $archive = [IO.Compression.ZipFile]::Open($zip, 'Create')
        $source = if ($scenario -eq 'startup_rollback') { 'bad.exe' } else { 'new.exe' }
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $OutputRoot $source), 'Game.exe') | Out-Null
        if ($scenario -eq 'archive_traversal') {
            $entry = $archive.CreateEntry('../outside.txt')
            $stream = $entry.Open(); $stream.WriteByte(42); $stream.Dispose()
        }
        $archive.Dispose()
        $old = Start-Process -FilePath $exe -WindowStyle Hidden -PassThru
        $helper = $null
        try {
            $hash = (Get-FileHash -LiteralPath $zip).Hash.ToLowerInvariant()
            if ($scenario -eq 'corrupt_hash') { $hash = '0' * 64 }
            $plan = @{schema=1;pid=$old.Id;token=$token;session=$session;package=$zip;sha256=$hash;size=(Get-Item -LiteralPath $zip).Length;entry='Game.exe';version='0.7.0';executable=$exe}
            $planPath = Join-Path $session 'plan.json'
            [IO.File]::WriteAllText($planPath, ($plan | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
            $shell = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
            $scriptPath = Join-Path $repo 'scripts/update/install_windows.ps1'
            $helper = Start-Process -FilePath $shell -ArgumentList @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',('"' + $scriptPath + '"'),'-PlanPath',('"' + $planPath + '"')) -WindowStyle Hidden -PassThru -RedirectStandardError (Join-Path $session 'stderr.txt')
            $deadline = [DateTime]::UtcNow.AddSeconds(30)
            while (-not $helper.HasExited -and -not (Test-Path -LiteralPath (Join-Path $session 'prepared'))) {
                if ([DateTime]::UtcNow -gt $deadline) { throw 'Fixture preparation timed out.' }
                Start-Sleep -Milliseconds 100; $helper.Refresh()
            }
            if ($scenario -in @('success','startup_rollback')) {
                if ($helper.HasExited) { throw (Get-Content -LiteralPath (Join-Path $session 'failed.txt') -Raw) }
                [IO.File]::WriteAllText((Join-Path $session 'proceed'), '')
                $old.Kill(); $old.WaitForExit()
                if (-not $helper.WaitForExit(30000)) { throw 'Fixture install timed out.' }
                $expected = if ($scenario -eq 'success') { 'success' } else { 'rolled_back' }
                if (-not (Test-Path -LiteralPath (Join-Path $session $expected))) { throw "Missing $expected receipt" }
                $expectedHash = if ($scenario -eq 'success') { (Get-FileHash -LiteralPath (Join-Path $OutputRoot 'new.exe')).Hash } else { $oldHash }
                if ((Get-FileHash -LiteralPath $exe).Hash -ne $expectedHash) { throw 'Installed/restored bytes mismatch.' }
            } else {
                if ($scenario -eq 'cancelled_preparation') { [IO.File]::WriteAllText((Join-Path $session 'cancelled'), '') }
                if ($scenario -eq 'unexpected_exit') { $old.Kill(); $old.WaitForExit() }
                if (-not $helper.WaitForExit(30000) -or $helper.ExitCode -eq 0) { throw 'Unsafe fixture was not rejected.' }
                if ((Get-FileHash -LiteralPath $exe).Hash -ne $oldHash -or ($old.HasExited -and $scenario -ne 'unexpected_exit')) { throw 'Rejection disturbed the original game.' }
            }
            if ([IO.File]::ReadAllText((Join-Path $install 'my-deck.json')) -ne 'player-data') { throw 'Player data changed.' }
            $results += @{scenario=$scenario;passed=$true;player_data_preserved=$true}
            Write-Output "PASS $scenario"
        } finally {
            if ($helper -and -not $helper.HasExited) { $helper.Kill() }
            # Only isolated fixture processes whose exact paths belong to this case.
            Get-Process -Name Game -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe } | Stop-Process -Force
        }
    }
} finally { $env:PTCG_UPDATER_TEST_ROOT = $previousTestRoot }
[IO.File]::WriteAllText((Join-Path $OutputRoot 'results.json'), (ConvertTo-Json -Depth 5 -InputObject $results))
Write-Output "Evidence: $OutputRoot"
