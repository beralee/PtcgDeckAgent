param(
    [Parameter(Mandatory = $true)]
    [string]$ExportDirectory,
    [double]$MaxPckMiB = 225.0,
    [double]$MaxWasmMiB = 40.0,
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$resolvedDirectory = (Resolve-Path $ExportDirectory).Path
$pck = Get-ChildItem -LiteralPath $resolvedDirectory -Filter "*.pck" | Sort-Object Length -Descending | Select-Object -First 1
$wasm = Get-ChildItem -LiteralPath $resolvedDirectory -Filter "*.wasm" | Sort-Object Length -Descending | Select-Object -First 1
if ($null -eq $pck) { throw "No Web PCK found in $resolvedDirectory" }
if ($null -eq $wasm) { throw "No Web WASM found in $resolvedDirectory" }

$result = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    export_directory = $resolvedDirectory
    pck = [ordered]@{ name = $pck.Name; bytes = $pck.Length; mib = [math]::Round($pck.Length / 1MB, 2); max_mib = $MaxPckMiB }
    wasm = [ordered]@{ name = $wasm.Name; bytes = $wasm.Length; mib = [math]::Round($wasm.Length / 1MB, 2); max_mib = $MaxWasmMiB }
    passed = (($pck.Length / 1MB) -le $MaxPckMiB -and ($wasm.Length / 1MB) -le $MaxWasmMiB)
}
$json = $result | ConvertTo-Json -Depth 5
if ($ReportPath -ne "") {
    $reportParent = Split-Path -Parent $ReportPath
    if ($reportParent -ne "") { New-Item -ItemType Directory -Force -Path $reportParent | Out-Null }
    [System.IO.File]::WriteAllText($ReportPath, $json, [System.Text.UTF8Encoding]::new($false))
}
Write-Output $json
if (-not $result.passed) { throw "Web export exceeded its resource budget" }
