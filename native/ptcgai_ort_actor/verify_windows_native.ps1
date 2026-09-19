param([Parameter(Mandatory = $true)][string]$Directory)

$ErrorActionPreference = "Stop"
$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$lock = Get-Content -LiteralPath (Join-Path $sourceRoot "dependencies.lock.json") -Raw | ConvertFrom-Json
$root = (Resolve-Path -LiteralPath $Directory).Path
$records = @()
foreach ($name in @("ptcgai_ort.windows.template_release.x86_64.v3.dll", "onnxruntime.dll")) {
    $path = Join-Path $root $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing Windows native dependency: $name" }
    $bytes = [IO.File]::ReadAllBytes($path)
    if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) { throw "Invalid PE binary: $name" }
    $pe = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($pe -lt 64 -or $pe + 6 -gt $bytes.Length -or [BitConverter]::ToUInt32($bytes, $pe) -ne 0x4550 -or [BitConverter]::ToUInt16($bytes, $pe + 4) -ne 0x8664) {
        throw "Expected Windows x86_64 PE binary: $name"
    }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($name -eq 'onnxruntime.dll' -and $hash -ne $lock.windows_runtime_sha256) { throw "Exported ORT DLL does not match dependency lock" }
    $records += [ordered]@{ name = $name; sha256 = $hash }
}
[ordered]@{ schema_version = 1; platform = "windows.x86_64"; accepted = $true; native_files = $records; onnxruntime_source_commit = $lock.onnxruntime_source_commit; device_tested = $false } | ConvertTo-Json -Depth 5
