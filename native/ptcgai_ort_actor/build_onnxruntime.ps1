param(
    [Parameter(Mandatory = $true)][string]$SourceRoot,
    [Parameter(Mandatory = $true)][string]$BuildRoot,
    [Parameter(Mandatory = $true)][string]$OutputRoot,
    [Parameter(Mandatory = $true)][string]$AndroidSdkRoot,
    [Parameter(Mandatory = $true)][string]$NdkRoot,
    [string]$PythonPath = "python",
    [string]$CmakePath = "cmake",
    [string]$NinjaPath = "ninja",
    [ValidateSet('arm64','x86_64')][string]$Architecture = 'arm64'
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$lock = Get-Content -LiteralPath (Join-Path $scriptRoot "dependencies.lock.json") -Raw | ConvertFrom-Json
$source = (Resolve-Path -LiteralPath $SourceRoot).Path
$revision = (& git -C $source rev-parse HEAD) -join ""
if ($LASTEXITCODE -ne 0 -or $revision.Trim() -ne $lock.onnxruntime_source_commit) { throw "ORT source commit does not match dependency lock" }
if ((& git -C $source status --porcelain --untracked-files=no)) { throw "ORT source has tracked changes; use the clean pinned checkout" }
$ndk = (Resolve-Path -LiteralPath $NdkRoot).Path
$properties = Get-Content -LiteralPath (Join-Path $ndk "source.properties") -Raw
if ($properties -notmatch "Pkg.Revision\s*=\s*$([regex]::Escape($lock.android_ndk_version))\s") { throw "NDK version mismatch" }
$build = [IO.Path]::GetFullPath($BuildRoot)
$output = [IO.Path]::GetFullPath($OutputRoot)
$cmake = (Get-Command $CmakePath -ErrorAction Stop).Source
$ctest = Join-Path (Split-Path -Parent $cmake) "ctest.exe"
$androidAbi = if ($Architecture -eq 'arm64') { 'arm64-v8a' } else { 'x86_64' }
$argsForBuild = @(
    (Join-Path $source "tools/ci_build/build.py"), "--config", "Release", "--update", "--build",
    "--build_dir", $build, "--build_shared_lib", "--skip_tests", "--parallel", "4",
    "--android", "--android_sdk_path", (Resolve-Path -LiteralPath $AndroidSdkRoot).Path,
    "--android_ndk_path", $ndk, "--android_abi", $androidAbi, "--android_api", "$($lock.android_model_min_api)",
    "--android_cpp_shared", "--cmake_generator", "Ninja", "--cmake_path", $cmake, "--ctest_path", $ctest,
    "--cmake_extra_defines", "CMAKE_MAKE_PROGRAM=$NinjaPath", "onnxruntime_BUILD_UNIT_TESTS=OFF",
    "CMAKE_SHARED_LINKER_FLAGS=-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"
)
& $PythonPath @argsForBuild
if ($LASTEXITCODE -ne 0) { throw "Pinned ORT Android build failed" }
New-Item -ItemType Directory -Path (Join-Path $output "include"),(Join-Path $output "lib") -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $source "include/onnxruntime/core/session") -File -Filter *.h | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $output "include") -Force
}
Copy-Item -LiteralPath (Join-Path $build "Release/libonnxruntime.so") -Destination (Join-Path $output "lib/libonnxruntime.so") -Force
Copy-Item -LiteralPath (Join-Path $source "LICENSE") -Destination $output -Force
[ordered]@{
    schema_version = 1; platform = "android.$Architecture"; onnxruntime_source_commit = $revision.Trim()
    ndk_version = $lock.android_ndk_version; minimum_api = $lock.android_model_min_api
    runtime_sha256 = (Get-FileHash -LiteralPath (Join-Path $output "lib/libonnxruntime.so") -Algorithm SHA256).Hash.ToLowerInvariant()
    build_arguments = $argsForBuild[1..($argsForBuild.Length - 1)]; device_tested = $false
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output "runtime-build.json") -Encoding utf8
