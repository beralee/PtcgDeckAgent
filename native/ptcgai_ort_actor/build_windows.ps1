param(
    [Parameter(Mandatory = $true)]
    [string]$GodotCppRoot,
    [Parameter(Mandatory = $true)]
    [string]$OnnxRuntimeRoot,
    [string]$CmakePath = "cmake",
    [string]$NinjaPath = "ninja",
    [string]$VsDevCmdPath = ""
)

$ErrorActionPreference = "Stop"
$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $sourceRoot "..\..")).Path
$buildRoot = Join-Path $sourceRoot "build\windows-x86_64"
$outputRoot = Join-Path $projectRoot "bin\ptcgai_ort"
$godotCpp = (Resolve-Path -LiteralPath $GodotCppRoot).Path
$onnxRuntime = (Resolve-Path -LiteralPath $OnnxRuntimeRoot).Path
$dependencyLock = Get-Content -LiteralPath (Join-Path $sourceRoot "dependencies.lock.json") -Raw | ConvertFrom-Json
$runtimeSource = Join-Path $onnxRuntime "lib\onnxruntime.dll"
if ((Get-FileHash -LiteralPath $runtimeSource -Algorithm SHA256).Hash.ToLowerInvariant() -ne $dependencyLock.windows_runtime_sha256) {
    throw "The Windows ORT runtime does not match dependencies.lock.json"
}

if (-not $env:INCLUDE) {
    if (-not $VsDevCmdPath) {
        throw "VsDevCmdPath is required when the MSVC environment is not initialized"
    }
    $vsDevCmd = (Resolve-Path -LiteralPath $VsDevCmdPath).Path
    $environmentLines = & $env:COMSPEC /s /c "`"$vsDevCmd`" -arch=x64 -host_arch=x64 >nul && set"
    if ($LASTEXITCODE -ne 0) {
        throw "Visual Studio developer environment initialization failed"
    }
    foreach ($line in $environmentLines) {
        $separator = $line.IndexOf("=")
        if ($separator -gt 0) {
            [Environment]::SetEnvironmentVariable(
                $line.Substring(0, $separator),
                $line.Substring($separator + 1),
                "Process"
            )
        }
    }
}
$env:CMAKE_BUILD_PARALLEL_LEVEL = "4"

$configureArgs = @(
    "-S", $sourceRoot,
    "-B", $buildRoot,
    "-G", "Ninja",
    "-DCMAKE_BUILD_TYPE=Release",
    "-DCMAKE_MAKE_PROGRAM=$NinjaPath",
    "-DGODOT_CPP_ROOT=$godotCpp",
    "-DONNXRUNTIME_ROOT=$onnxRuntime"
)
& $CmakePath @configureArgs
if ($LASTEXITCODE -ne 0) {
    throw "CMake configure failed with exit code $LASTEXITCODE"
}
& $CmakePath --build $buildRoot --config Release --parallel 4
if ($LASTEXITCODE -ne 0) {
    throw "CMake build failed with exit code $LASTEXITCODE"
}
& (Join-Path $buildRoot "ptcgai_inference_worker_test.exe")
if ($LASTEXITCODE -ne 0) { throw "Native inference worker regression failed" }

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$extensionName = "ptcgai_ort.windows.template_release.x86_64.v4.dll"
Copy-Item -LiteralPath (Join-Path $buildRoot $extensionName) -Destination $outputRoot -Force
$runtimeTarget = Join-Path $outputRoot "onnxruntime.dll"
if (-not (Test-Path -LiteralPath $runtimeTarget) -or (Get-FileHash -LiteralPath $runtimeTarget -Algorithm SHA256).Hash.ToLowerInvariant() -ne $dependencyLock.windows_runtime_sha256) {
    Copy-Item -LiteralPath $runtimeSource -Destination $runtimeTarget -Force
}
[ordered]@{
    schema_version = 1
    platform = "windows.x86_64"
    godot_version = $dependencyLock.godot_version
    godot_cpp_commit = $dependencyLock.godot_cpp_commit
    onnxruntime_source_commit = $dependencyLock.onnxruntime_source_commit
    extension_sha256 = (Get-FileHash -LiteralPath (Join-Path $outputRoot $extensionName) -Algorithm SHA256).Hash.ToLowerInvariant()
    runtime_sha256 = $dependencyLock.windows_runtime_sha256
    model_provider = "CPUExecutionProvider"
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $buildRoot "runtime-build.json") -Encoding utf8
