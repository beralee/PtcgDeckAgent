param(
    [string]$GodotExe = 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe',
    [string]$OutputRoot = '.godot_test_user/performance/exports',
    [ValidateSet('arm64','x86_64')][string]$AndroidArchitecture = 'x86_64',
    [string]$ReuseSourceSnapshot = '',
    [switch]$AndroidOnly,
    [switch]$KeepSourceSnapshot
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location -LiteralPath $projectRoot
$null = New-Item -ItemType Directory -Force -Path $OutputRoot
$outputDirectory = (Resolve-Path -LiteralPath $OutputRoot).Path
$snapshot = if ($ReuseSourceSnapshot) { (Resolve-Path -LiteralPath $ReuseSourceSnapshot).Path } else { Join-Path $outputDirectory ('snapshot-' + [Guid]::NewGuid().ToString('N')) }
$ownsSnapshot = -not [bool]$ReuseSourceSnapshot
if ($ownsSnapshot -and (Test-Path -LiteralPath $snapshot)) { throw 'Refusing to reuse an unowned snapshot directory.' }
try {
$snapshotArgs = @($snapshot)
if ($ReuseSourceSnapshot) { $snapshotArgs += '--refresh' }
& python (Join-Path $PSScriptRoot 'snapshot_strategy_parity.py') @snapshotArgs
if ($LASTEXITCODE -ne 0) { throw 'Source snapshot failed.' }
if ($ReuseSourceSnapshot) {
    $sourceManifest = (Resolve-Path -LiteralPath (Join-Path (Split-Path $snapshot -Parent) 'source-manifest.json')).Path
    $outputManifest = [IO.Path]::GetFullPath((Join-Path $outputDirectory 'source-manifest.json'))
    if (-not $sourceManifest.Equals($outputManifest, [StringComparison]::OrdinalIgnoreCase)) {
        Copy-Item -LiteralPath $sourceManifest -Destination $outputManifest
    }
}
$encoding = [Text.UTF8Encoding]::new($false)
$presetPath = Join-Path $snapshot 'export_presets.cfg'
$projectPath = Join-Path $snapshot 'project.godot'
$preset = [IO.File]::ReadAllText($presetPath).Replace('tests/**,', '')
$preset = [regex]::Replace($preset, '(?m)^include_filter="', 'include_filter="tests/**,')
$preset = [regex]::Replace($preset, '(?m)^package/unique_name=.*$', 'package/unique_name="com.example.ptcgdeckagent.performance"')
$preset = [regex]::Replace($preset, '(?m)^package/name=.*$', 'package/name="PTCG 性能诊断"')
$preset = $preset.Replace('command_line/extra_args=""', 'command_line/extra_args="--rendering-method gl_compatibility --rendering-driver opengl3 -- --ptcgdap-performance-trace --perf-repeat=2"')
foreach ($abi in @('armeabi-v7a','arm64-v8a','x86','x86_64')) {
    $enabled = if (($AndroidArchitecture -eq 'arm64' -and $abi -eq 'arm64-v8a') -or ($AndroidArchitecture -eq 'x86_64' -and $abi -eq 'x86_64')) { 'true' } else { 'false' }
    $preset = [regex]::Replace($preset, ('(?m)^architectures/' + [regex]::Escape($abi) + '=.*$'), "architectures/$abi=$enabled")
}
$project = [IO.File]::ReadAllText($projectPath)
$project = $project.Replace('config/name="PtcgDeckAgent"', 'config/name="PtcgDAP Performance Bench"')
$project = $project.Replace('[autoload]', "[autoload]`n`nPerformanceBenchRunner=`"*res://tests/performance/PerformanceBenchRunner.gd`"")
[IO.File]::WriteAllText($presetPath, $preset, $encoding)
[IO.File]::WriteAllText($projectPath, $project, $encoding)
if ($preset -match 'gradle_build/use_gradle_build=true') {
    $versionPath = Join-Path $projectRoot 'android/.build_version'
    $templateVersion = ([IO.File]::ReadAllText($versionPath)).Trim()
    $templateZip = Join-Path $env:APPDATA "Godot/export_templates/$templateVersion/android_source.zip"
    $androidBuild = Join-Path $snapshot 'android/build'
    if (-not (Test-Path -LiteralPath (Join-Path $androidBuild 'build.gradle'))) { Expand-Archive -LiteralPath $templateZip -DestinationPath $androidBuild }
    Copy-Item -LiteralPath $versionPath -Destination (Join-Path $snapshot 'android/.build_version')
    [IO.File]::WriteAllText((Join-Path $androidBuild '.gdignore'), '', $encoding)
    [IO.File]::AppendAllText((Join-Path $androidBuild 'gradle.properties'), "`norg.gradle.daemon=false`n", $encoding)
}
$builds = ,@('Android','PtcgDAP-performance.apk','android')
if (-not $AndroidOnly) { $builds += ,@('Windows Desktop','PtcgDAP-performance.exe','windows') }
foreach ($build in $builds) {
    $log = Join-Path $outputDirectory ($build[2] + '-export.private.log')
    & $GodotExe --headless --path $snapshot --export-release $build[0] (Join-Path $outputDirectory $build[1]) *> $log
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $outputDirectory $build[1]))) { throw "$($build[0]) diagnostic export failed; see local export log." }
    if (Select-String -LiteralPath $log -Pattern '^ERROR:|SCRIPT ERROR|Parse Error' -Quiet) { throw "$($build[0]) export has errors; see local export log." }
}
$manifest = @{
    diagnosticOnly = $true
    packageId = 'com.example.ptcgdeckagent.performance'
    androidArchitecture = $AndroidArchitecture
    sourceSnapshot = $snapshot
    sourceSnapshotRetained = [bool]($KeepSourceSnapshot -or -not $ownsSnapshot)
    sourceManifestSha256 = (Get-FileHash -LiteralPath (Join-Path $outputDirectory 'source-manifest.json')).Hash
    projectSha256 = (Get-FileHash -LiteralPath $projectPath).Hash
    presetsSha256 = (Get-FileHash -LiteralPath $presetPath).Hash
    godotSha256 = (Get-FileHash -LiteralPath $GodotExe).Hash
    apkSha256 = (Get-FileHash -LiteralPath (Join-Path $outputDirectory 'PtcgDAP-performance.apk')).Hash
}
if (-not $AndroidOnly) { $manifest.windowsSha256 = (Get-FileHash -LiteralPath (Join-Path $outputDirectory 'PtcgDAP-performance.exe')).Hash }
$manifest.exportedFiles = @{}
foreach ($artifact in Get-ChildItem -LiteralPath $outputDirectory -File) {
    if ($artifact.Extension -in @('.apk','.exe','.dll','.pck')) {
        $manifest.exportedFiles[$artifact.Name] = (Get-FileHash -LiteralPath $artifact.FullName).Hash
    }
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputDirectory 'build.json') -Encoding UTF8
Write-Output "Diagnostic exports: $outputDirectory"
} finally {
    if ($ownsSnapshot -and -not $KeepSourceSnapshot -and (Test-Path -LiteralPath $snapshot)) {
        # Delete only the fresh UUID directory created for this invocation.
        $target = [IO.Path]::GetFullPath($snapshot)
        if ((Split-Path -Parent $target) -ne $outputDirectory -or (Split-Path -Leaf $target) -notmatch '^snapshot-[0-9a-f]{32}$') { throw 'Snapshot cleanup escaped its output directory.' }
        $pending = [Collections.Generic.Stack[string]]::new()
        $pending.Push($target)
        while ($pending.Count -gt 0) {
            $current = $pending.Pop()
            if (((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Refusing to clean a snapshot containing a link or junction.' }
            foreach ($item in Get-ChildItem -LiteralPath $current -Force -ErrorAction Stop) {
                if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Refusing to clean a snapshot containing a link or junction.' }
                if ($item.PSIsContainer) { $pending.Push($item.FullName) }
            }
        }
        Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop
    }
}
