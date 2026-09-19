param(
    [Parameter(Mandatory = $true, ParameterSetName = "Directory")][string]$Directory,
    [Parameter(Mandatory = $true, ParameterSetName = "Apk")][string]$ApkPath,
    [Parameter(Mandatory = $true)][string]$NdkRoot,
    [Parameter(ParameterSetName = "Apk", Mandatory = $true)][string]$ZipalignPath,
    [ValidateSet('arm64','x86_64')][string]$Architecture = 'arm64'
)

$ErrorActionPreference = "Stop"
$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$readelf = Join-Path (Resolve-Path -LiteralPath $NdkRoot).Path "toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-readelf.exe"
if (-not (Test-Path -LiteralPath $readelf -PathType Leaf)) { throw "NDK llvm-readelf is missing" }
$artifactKind = "native_directory"
$androidAbi = if ($Architecture -eq 'arm64') { 'arm64-v8a' } else { 'x86_64' }
$elfMachine = if ($Architecture -eq 'arm64') { 'AArch64' } else { 'Advanced Micro Devices X86-64' }
if ($PSCmdlet.ParameterSetName -eq "Apk") {
    $artifactKind = "apk"
    $apk = (Resolve-Path -LiteralPath $ApkPath).Path
    & $ZipalignPath -c -P 16 -v 4 $apk | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "APK ZIP alignment check failed" }
    $Directory = Join-Path $sourceRoot ("build/apk-verification/" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($apk)
    try {
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName -match "^lib/$androidAbi/[^/]+\.so$") {
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $Directory $entry.Name), $false)
            }
        }
    } finally { $archive.Dispose() }
}
$nativeRoot = (Resolve-Path -LiteralPath $Directory).Path
$required = @("libptcgai_ort.android.template_release.$Architecture.so", "libonnxruntime.so", "libc++_shared.so")
foreach ($name in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $nativeRoot $name) -PathType Leaf)) { throw "Missing Android dependency: $name" }
}
$systemLibraries = @("libc.so", "libm.so", "libdl.so", "liblog.so", "libandroid.so", "libz.so", "libEGL.so", "libGLESv2.so", "libGLESv3.so", "libOpenSLES.so", "libvulkan.so", "libaaudio.so", "libjnigraphics.so", "libmediandk.so", "libcamera2ndk.so")
$cppExports = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$cppSymbols = & $readelf --dyn-symbols --wide (Join-Path $nativeRoot "libc++_shared.so")
if ($LASTEXITCODE -ne 0) { throw "Cannot inspect the bundled C++ runtime" }
foreach ($line in $cppSymbols) {
    $fields = $line.Trim() -split '\s+'
    if ($fields.Length -ge 8 -and $fields[0] -match '^\d+:$' -and $fields[6] -ne 'UND') { [void]$cppExports.Add(($fields[7] -split '@', 2)[0]) }
}
$records = @()
foreach ($file in Get-ChildItem -LiteralPath $nativeRoot -File -Filter *.so | Sort-Object Name) {
    $header = (& $readelf --file-header $file.FullName) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $header -notmatch "Machine:\s+$elfMachine") { throw "Wrong ELF architecture: $($file.Name)" }
    $segments = (& $readelf --program-headers --wide $file.FullName) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect ELF segments: $($file.Name)" }
    $loads = [regex]::Matches($segments, '(?m)^\s*LOAD\s+.*?\s+(0x[0-9a-fA-F]+)\s*$')
    if ($loads.Count -eq 0) { throw "ELF has no loadable segments: $($file.Name)" }
    foreach ($load in $loads) {
        if ([Convert]::ToInt64($load.Groups[1].Value.Substring(2), 16) -lt 16384) { throw "ELF lacks 16 KB alignment: $($file.Name)" }
    }
    $dynamic = (& $readelf --dynamic $file.FullName) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect ELF dependencies: $($file.Name)" }
    $needed = @([regex]::Matches($dynamic, '\(NEEDED\).*?\[([^\]]+)\]') | ForEach-Object { $_.Groups[1].Value })
    if ($file.Name -eq $required[0] -and $needed -contains 'libonnxruntime.so') { throw "Extension must not strongly link ORT" }
    foreach ($dependency in $needed) {
        if ($dependency -notin $systemLibraries -and -not (Test-Path -LiteralPath (Join-Path $nativeRoot $dependency) -PathType Leaf)) {
            throw "Unbundled native dependency $dependency required by $($file.Name)"
        }
    }
    if ($file.Name -in @($required[0], 'libonnxruntime.so')) {
        $symbols = & $readelf --dyn-symbols --wide $file.FullName
        if ($LASTEXITCODE -ne 0) { throw "Cannot inspect native C++ imports" }
        foreach ($line in $symbols) {
            $fields = $line.Trim() -split '\s+'
            if ($fields.Length -lt 8 -or $fields[0] -notmatch '^\d+:$' -or $fields[6] -ne 'UND' -or $fields[4] -ne 'GLOBAL') { continue }
            $symbol = ($fields[7] -split '@', 2)[0]
            if (($symbol.StartsWith('_Z') -or $symbol -match '^__cxa_(allocate_exception|free_exception|throw|rethrow|begin_catch|end_catch|get_exception_ptr|pure_virtual)$') -and -not $cppExports.Contains($symbol)) {
                throw "Bundled C++ runtime lacks $symbol required by $($file.Name)"
            }
        }
    }
    $records += [ordered]@{ name = $file.Name; sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant(); needed = $needed; page_alignment = "at_least_16384" }
}
[ordered]@{ schema_version = 1; platform = "android.$Architecture"; artifact_kind = $artifactKind; accepted = $true; native_files = $records; cpp_symbol_compatibility = $true; device_tested = $false } | ConvertTo-Json -Depth 6
