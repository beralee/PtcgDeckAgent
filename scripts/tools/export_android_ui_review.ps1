param(
    [ValidateSet('arm64','x86_64')][string]$Architecture = 'arm64',
    [string]$GodotPath = 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe'
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$out = Join-Path $repo '.tmp/ui_compatibility'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$presetPath = Join-Path $repo 'export_presets.cfg'
$savedPresetBytes = [IO.File]::ReadAllBytes($presetPath)
$utf8 = [Text.UTF8Encoding]::new($false)
try {
    $reviewPresetText = $utf8.GetString($savedPresetBytes)
    if ($reviewPresetText -notmatch 'command_line/extra_args=""') { throw 'Android preset already has diagnostic arguments; do not run concurrent exports.' }
    $reviewPresetText = $reviewPresetText.Replace('command_line/extra_args=""', 'command_line/extra_args="--rendering-method gl_compatibility --rendering-driver opengl3 -- --ptcgdap-ui-input-probe"')
    if ($Architecture -eq 'x86_64') {
        $reviewPresetText = $reviewPresetText.Replace('architectures/arm64-v8a=true','architectures/arm64-v8a=false').Replace('architectures/x86_64=false','architectures/x86_64=true')
    } else {
        $reviewPresetText = $reviewPresetText.Replace('architectures/arm64-v8a=false','architectures/arm64-v8a=true').Replace('architectures/x86_64=true','architectures/x86_64=false')
    }
    [IO.File]::WriteAllText($presetPath, $reviewPresetText, $utf8)
    & $GodotPath --headless --path $repo --export-release Android (Join-Path $out "ui-review-$Architecture.apk") *> (Join-Path $out "export-$Architecture.private.log")
    if ($LASTEXITCODE -ne 0) { throw 'UI review export failed; inspect the local private export log.' }
} finally {
    [IO.File]::WriteAllBytes($presetPath, $savedPresetBytes)
}
# x86_64 is a UI-only emulator build: the shipped native model runtime is ARM64.
Write-Output (Join-Path $out "ui-review-$Architecture.apk")
