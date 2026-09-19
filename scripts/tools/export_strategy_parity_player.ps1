param(
    [Parameter(Mandatory=$true)][string]$ExportRoot,
    [string]$GodotExe = 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe'
)
$ErrorActionPreference = 'Stop'
$exports = (Resolve-Path -LiteralPath $ExportRoot).Path
$build = Get-Content (Join-Path $exports 'build.json') -Raw | ConvertFrom-Json
$snapshot = $build.sourceSnapshot
$projectPath = Join-Path $snapshot 'project.godot'
$presetPath = Join-Path $snapshot 'export_presets.cfg'
$originalProject = [IO.File]::ReadAllBytes($projectPath)
$originalPreset = [IO.File]::ReadAllBytes($presetPath)
$encoding = [Text.UTF8Encoding]::new($false)
$apkPath = Join-Path $exports 'PtcgDeckAgent-fixed.apk'
$logPath = Join-Path $exports 'player-export.private.log'
try {
    $project = $encoding.GetString($originalProject).Replace('AndroidStrategyParityRunner="*res://tests/ai/ptcgdap/AndroidStrategyParityRunner.gd"','')
    $preset = $encoding.GetString($originalPreset).Replace('include_filter="tests/**,data/**,','include_filter="data/**,').Replace('exclude_filter="','exclude_filter="tests/**,')
    [IO.File]::WriteAllText($projectPath,$project,$encoding)
    [IO.File]::WriteAllText($presetPath,$preset,$encoding)
    $ErrorActionPreference = 'Continue'
    & $GodotExe --headless --path $snapshot --export-release Android $apkPath *> $logPath
    if ($LASTEXITCODE -ne 0) { throw 'Player APK export failed.' }
    if (Select-String -LiteralPath $logPath -Pattern '^ERROR:|SCRIPT ERROR|Parse Error' -Quiet) { throw 'Player export reported an error.' }
} finally {
    [IO.File]::WriteAllBytes($projectPath,$originalProject)
    [IO.File]::WriteAllBytes($presetPath,$originalPreset)
    $ErrorActionPreference = 'Stop'
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($apkPath)
try {
    $names = @($archive.Entries | ForEach-Object FullName)
    if ($names -match '^assets/tests/') { throw 'Player build contains the test harness.' }
    $abi = $build.androidAbi
    if (-not $abi -or "lib/$abi/libonnxruntime.so" -notin $names -or "lib/$abi/libgodot_android.so" -notin $names) { throw 'Missing player native runtime.' }
    if ($names | Where-Object { $_ -match '^lib/([^/]+)/' -and $Matches[1] -ne $abi }) { throw 'Unexpected player ABI.' }
} finally { $archive.Dispose() }
@{apkSha256=(Get-FileHash -LiteralPath $apkPath).Hash;androidAbi=$abi;diagnosticOnly=$false;sourceManifestSha256=$build.sourceManifestSha256} |
    ConvertTo-Json | Set-Content (Join-Path $exports 'player-build.json') -Encoding UTF8
Write-Output "Player APK without diagnostic harness: $apkPath"
