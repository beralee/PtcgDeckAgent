param(
    [Parameter(Mandatory = $true)][string]$GodotCppRoot,
    [Parameter(Mandatory = $true)][string]$OnnxRuntimeRoot,
    [Parameter(Mandatory = $true)][string]$NdkRoot,
    [string]$CmakePath = "cmake",
    [string]$NinjaPath = "ninja",
    [ValidateSet('arm64','x86_64')][string]$Architecture = 'arm64'
)

$ErrorActionPreference = "Stop"
$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $sourceRoot "../..")).Path
$buildRoot = Join-Path $sourceRoot "build/android-$Architecture"
$outputRoot = Join-Path $projectRoot "bin/ptcgai_ort"
if ($Architecture -eq 'x86_64') { $outputRoot = Join-Path $outputRoot 'android-x86_64' }
$androidAbi = if ($Architecture -eq 'arm64') { 'arm64-v8a' } else { 'x86_64' }
$toolchainTriple = if ($Architecture -eq 'arm64') { 'aarch64-linux-android' } else { 'x86_64-linux-android' }
$godotCpp = (Resolve-Path -LiteralPath $GodotCppRoot).Path
$onnxRuntime = (Resolve-Path -LiteralPath $OnnxRuntimeRoot).Path
$ndk = (Resolve-Path -LiteralPath $NdkRoot).Path
$lock = Get-Content -LiteralPath (Join-Path $sourceRoot "dependencies.lock.json") -Raw | ConvertFrom-Json
$ndkProperties = Get-Content -LiteralPath (Join-Path $ndk "source.properties") -Raw
if ($ndkProperties -notmatch "Pkg.Revision\s*=\s*$([regex]::Escape($lock.android_ndk_version))\s") {
    throw "NDK revision must match dependencies.lock.json"
}
$runtimeBuild = Get-Content -LiteralPath (Join-Path $onnxRuntime "runtime-build.json") -Raw | ConvertFrom-Json
if ($runtimeBuild.onnxruntime_source_commit -ne $lock.onnxruntime_source_commit -or $runtimeBuild.platform -ne "android.$Architecture") {
    throw "Build ORT using build_onnxruntime.ps1 before building the Android extension"
}
if ((Get-FileHash -LiteralPath (Join-Path $onnxRuntime "lib/libonnxruntime.so") -Algorithm SHA256).Hash.ToLowerInvariant() -ne $runtimeBuild.runtime_sha256) {
    throw "The staged Android ORT library does not match its build provenance"
}
$configureArgs = @(
    "-S", $sourceRoot, "-B", $buildRoot, "-G", "Ninja",
    "-DCMAKE_BUILD_TYPE=Release", "-DCMAKE_MAKE_PROGRAM=$NinjaPath",
    "-DCMAKE_TOOLCHAIN_FILE=$ndk/build/cmake/android.toolchain.cmake",
    "-DANDROID_ABI=$androidAbi", "-DANDROID_PLATFORM=android-$($lock.android_extension_min_api)",
    "-DANDROID_STL=c++_shared", "-DGODOT_CPP_ROOT=$godotCpp", "-DONNXRUNTIME_ROOT=$onnxRuntime"
)
& $CmakePath @configureArgs
if ($LASTEXITCODE -ne 0) { throw "Android CMake configure failed" }
& $CmakePath --build $buildRoot --config Release --parallel 4
if ($LASTEXITCODE -ne 0) { throw "Android native build failed" }

$stageRoot = Join-Path $buildRoot "bundle"
New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $buildRoot "libptcgai_ort.android.template_release.$Architecture.so") -Destination $stageRoot -Force
Copy-Item -LiteralPath (Join-Path $onnxRuntime "lib/libonnxruntime.so") -Destination $stageRoot -Force
Copy-Item -LiteralPath (Join-Path $ndk "toolchains/llvm/prebuilt/windows-x86_64/sysroot/usr/lib/$toolchainTriple/libc++_shared.so") -Destination $stageRoot -Force
& (Join-Path $sourceRoot "verify_android_native.ps1") -Directory $stageRoot -NdkRoot $ndk -Architecture $Architecture |
    Set-Content -LiteralPath (Join-Path $buildRoot "runtime-build.json") -Encoding utf8
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
Get-ChildItem -LiteralPath $stageRoot -Filter *.so -File | Where-Object { $_.Name -ne "libc++_shared.so" } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $outputRoot -Force
}
