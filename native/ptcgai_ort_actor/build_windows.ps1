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
& $CmakePath --build $buildRoot --config Release
if ($LASTEXITCODE -ne 0) {
    throw "CMake build failed with exit code $LASTEXITCODE"
}

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $buildRoot "ptcgai_ort.windows.template_release.x86_64.dll") -Destination $outputRoot -Force
Copy-Item -LiteralPath (Join-Path $onnxRuntime "lib\onnxruntime.dll") -Destination $outputRoot -Force
