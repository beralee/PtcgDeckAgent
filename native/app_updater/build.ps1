param(
    [string]$JavaHome = 'D:/ai/code/jdk-17.0.12_windows-x64_bin/jdk-17.0.12',
    [string]$AndroidSdk = "$env:LOCALAPPDATA/Android/Sdk",
    [string]$GodotSourceZip = "$env:APPDATA/Godot/export_templates/4.6.1.stable/android_source.zip"
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$work = Join-Path $root '.tmp/app-updater-android-build'
New-Item -ItemType Directory -Force -Path $work | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$source = [IO.Compression.ZipFile]::OpenRead($GodotSourceZip)
try { [IO.Compression.ZipFileExtensions]::ExtractToFile($source.GetEntry('libs/release/godot-lib.template_release.aar'), (Join-Path $work 'godot.aar'), $true) }
finally { $source.Dispose() }
$aar = [IO.Compression.ZipFile]::OpenRead((Join-Path $work 'godot.aar'))
try { [IO.Compression.ZipFileExtensions]::ExtractToFile($aar.GetEntry('classes.jar'), (Join-Path $work 'godot.jar'), $true) }
finally { $aar.Dispose() }
$classes = Join-Path $work 'classes'
$package = Join-Path $work 'aar'
New-Item -ItemType Directory -Force -Path $classes,$package | Out-Null
$sources = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'src/cn/skillserver/ptcg/updater') -Filter '*.java' | ForEach-Object FullName)
$classpath = (Join-Path $AndroidSdk 'platforms/android-35/android.jar') + ';' + (Join-Path $work 'godot.jar')
& (Join-Path $JavaHome 'bin/javac.exe') -encoding UTF-8 -source 8 -target 8 -classpath $classpath -d $classes @sources
if ($LASTEXITCODE -ne 0) { throw 'Android updater compilation failed.' }
& (Join-Path $JavaHome 'bin/jar.exe') cf (Join-Path $package 'classes.jar') -C $classes .
if ($LASTEXITCODE -ne 0) { throw 'Android updater JAR packaging failed.' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'AndroidManifest.xml') -Destination $package -Force
$destination = Join-Path $root 'addons/app_updater/PtcgAppUpdater.aar'
New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($destination)) | Out-Null
$temporary = Join-Path $work ('plugin-' + [Guid]::NewGuid().ToString('N') + '.aar')
[IO.Compression.ZipFile]::CreateFromDirectory($package, $temporary)
Move-Item -LiteralPath $temporary -Destination $destination -Force
Get-FileHash -LiteralPath $destination -Algorithm SHA256 | Select-Object Path,Hash
