param(
    [string]$GodotExe = 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe',
    [string]$OutputRoot = '.tmp/android_strategy_parity/exports',
    [ValidateSet('arm64','x86_64')][string]$AndroidArchitecture = 'arm64',
    [switch]$KeepSourceSnapshot
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location -LiteralPath $projectRoot
$null = New-Item -ItemType Directory -Force -Path $OutputRoot
$outputDirectory = (Resolve-Path -LiteralPath $OutputRoot).Path
$snapshot = Join-Path $outputDirectory ('snapshot-' + [Guid]::NewGuid().ToString('N'))
if (Test-Path -LiteralPath $snapshot) { throw 'Refusing to reuse an unowned snapshot directory.' }
try {
& python (Join-Path $PSScriptRoot 'snapshot_strategy_parity.py') $snapshot
if ($LASTEXITCODE -ne 0) { throw 'Could not create an isolated source snapshot.' }
$presetPath = Join-Path $snapshot 'export_presets.cfg'
$projectPath = Join-Path $snapshot 'project.godot'
$encoding = [Text.UTF8Encoding]::new($false)
$preset = [IO.File]::ReadAllText($presetPath).Replace('exclude_filter="tests/**,', 'exclude_filter="')
# Include test data even when a platform adds another include before data/**.
$preset = [regex]::Replace($preset, '(?m)^include_filter="', 'include_filter="tests/**,')
$preset = $preset.Replace('command_line/extra_args=""', 'command_line/extra_args="--rendering-method gl_compatibility --rendering-driver opengl3"')
$preset = $preset.Replace('architectures/x86=true', 'architectures/x86=false').Replace('architectures/x86_64=true','architectures/x86_64=false').Replace('architectures/armeabi-v7a=true','architectures/armeabi-v7a=false').Replace('architectures/arm64-v8a=false','architectures/arm64-v8a=true')
$androidAbi = if ($AndroidArchitecture -eq 'arm64') { 'arm64-v8a' } else { 'x86_64' }
if ($AndroidArchitecture -eq 'x86_64') {
    $preset = $preset.Replace('architectures/arm64-v8a=true','architectures/arm64-v8a=false').Replace('architectures/x86_64=false','architectures/x86_64=true')
}
$project = [IO.File]::ReadAllText($projectPath).Replace('[autoload]', "[autoload]`n`nAndroidStrategyParityRunner=`"*res://tests/ai/ptcgdap/AndroidStrategyParityRunner.gd`"")
[IO.File]::WriteAllText($presetPath, $preset, $encoding)
[IO.File]::WriteAllText($projectPath, $project, $encoding)
if ($preset -match 'gradle_build/use_gradle_build=true') {
    # Gradle build sources are ignored by Git and are not in the public snapshot.
    # Install the matching local Godot template into this isolated build only.
    $versionPath = Join-Path $projectRoot 'android/.build_version'
    if (-not (Test-Path -LiteralPath $versionPath)) { throw 'Install the matching Android build template in the project first.' }
    $templateVersion = ([IO.File]::ReadAllText($versionPath)).Trim()
    $templateZip = Join-Path $env:APPDATA "Godot/export_templates/$templateVersion/android_source.zip"
    $androidBuild = Join-Path $snapshot 'android/build'
    Expand-Archive -LiteralPath $templateZip -DestinationPath $androidBuild
    Copy-Item -LiteralPath $versionPath -Destination (Join-Path $snapshot 'android/.build_version')
    # Generated APK assets include copies of scripts/extensions; never scan them.
    [IO.File]::WriteAllText((Join-Path $androidBuild '.gdignore'), '', $encoding)
    # A daemon can retain the console export's inherited output handles on Windows.
    [IO.File]::AppendAllText((Join-Path $androidBuild 'gradle.properties'), "`norg.gradle.daemon=false`n", $encoding)
}
foreach ($build in @(@('Android','PtcgDeckAgent-parity.apk','android'),@('Windows Desktop','PtcgDeckAgent-parity.exe','windows'))) {
    $logPath = Join-Path $outputDirectory ($build[2] + '-export.private.log')
    try {
        $ErrorActionPreference = 'Continue'
        & $GodotExe --headless --path $snapshot --export-release $build[0] (Join-Path $outputDirectory $build[1]) *> $logPath
    } finally { $ErrorActionPreference = 'Stop' }
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $outputDirectory $build[1]))) { throw "$($build[0]) export failed." }
    if (Select-String -LiteralPath $logPath -Pattern '^ERROR:|SCRIPT ERROR|Parse Error' -Quiet) { throw "$($build[0]) export reported errors. Inspect the ignored local log." }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$apkPath = Join-Path $outputDirectory 'PtcgDeckAgent-parity.apk'
$archive = [IO.Compression.ZipFile]::OpenRead($apkPath)
try {
    $names = @($archive.Entries | ForEach-Object FullName)
    foreach ($required in @("lib/$androidAbi/libgodot_android.so","lib/$androidAbi/libonnxruntime.so","lib/$androidAbi/libptcgai_ort.android.template_release.$AndroidArchitecture.so",'assets/tests/ai/ptcgdap/AndroidStrategyParityRunner.gdc','assets/tests/ai/ptcgdap/fixtures/platform_actor.ort','assets/tests/ai/ptcgdap/fixtures/platform_model.ptcgai')) {
        if ($required -notin $names) { throw "Diagnostic APK missing required artifact: $required" }
    }
    if ($names | Where-Object { $_ -match '^lib/([^/]+)/' -and $Matches[1] -ne $androidAbi }) { throw 'Diagnostic APK contains an unexpected ABI.' }
} finally { $archive.Dispose() }
$manifest = @{
    diagnosticOnly = $true
    androidAbi = $androidAbi
    sourceSnapshot = $snapshot
    sourceSnapshotRetained = [bool]$KeepSourceSnapshot
    sourceManifestSha256 = (Get-FileHash -LiteralPath (Join-Path $outputDirectory 'source-manifest.json')).Hash
    projectSha256 = (Get-FileHash -LiteralPath $projectPath).Hash
    presetsSha256 = (Get-FileHash -LiteralPath $presetPath).Hash
    godotSha256 = (Get-FileHash -LiteralPath $GodotExe -Algorithm SHA256).Hash
    apkSha256 = (Get-FileHash -LiteralPath (Join-Path $outputDirectory 'PtcgDeckAgent-parity.apk') -Algorithm SHA256).Hash
    windowsSha256 = (Get-FileHash -LiteralPath (Join-Path $outputDirectory 'PtcgDeckAgent-parity.exe') -Algorithm SHA256).Hash
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputDirectory 'build.json') -Encoding UTF8
Write-Output "Verified $androidAbi Android and Windows diagnostic exports: $outputDirectory. Live project settings were not changed."
} finally {
    if (-not $KeepSourceSnapshot -and (Test-Path -LiteralPath $snapshot)) {
        # Keep hashes, manifests, logs and binaries; release only this build's scratch tree.
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
