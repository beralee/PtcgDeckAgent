$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot)
$sourceRoot = Join-Path $repoRoot 'art/arena3d/product-v3/sources'
New-Item -ItemType Directory -Force $sourceRoot | Out-Null
Set-Content (Join-Path $sourceRoot '../.gdignore') ''
$manifest = [System.Collections.Generic.List[object]]::new()
function Get-AssetFile($assetId, $file, $relativePath) {
    $target = Join-Path $sourceRoot $relativePath
    New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
    if (!(Test-Path -LiteralPath $target)) {
        Invoke-WebRequest -Uri $file.url -OutFile $target
    }
    $hash = (Get-FileHash -LiteralPath $target -Algorithm MD5).Hash.ToLower()
    if ($hash -ne $file.md5) { throw "Asset checksum mismatch: $relativePath" }
    $manifest.Add([PSCustomObject]@{asset=$assetId; source="https://polyhaven.com/a/$assetId"; url=$file.url; license='CC0-1.0'; local=$relativePath; md5=$hash; bytes=(Get-Item $target).Length})
}
foreach ($assetId in @('fabric_pattern_07','black_walnut_veneer_02')) {
    $files = Invoke-RestMethod "https://api.polyhaven.com/files/$assetId"
    foreach ($map in @('nor_gl','Rough')) { Get-AssetFile $assetId $files.$map.'2k'.jpg "$assetId/$map.jpg" }
    if ($assetId -ne 'fabric_pattern_07') { Get-AssetFile $assetId $files.Diffuse.'2k'.jpg "$assetId/Diffuse.jpg" }
}
$assetId = 'fern_02'
$files = Invoke-RestMethod "https://api.polyhaven.com/files/$assetId"
$model = $files.gltf.'1k'.gltf
Get-AssetFile $assetId $model "$assetId/fern_02.gltf"
foreach ($entry in $model.include.PSObject.Properties) { Get-AssetFile $assetId $entry.Value "$assetId/$($entry.Name)" }
$assetId = 'studio_small_09'
$files = Invoke-RestMethod "https://api.polyhaven.com/files/$assetId"
Get-AssetFile $assetId $files.hdri.'1k'.hdr "$assetId.hdr"
$runtime = Join-Path $repoRoot 'assets/arena3d/product-v3'
New-Item -ItemType Directory -Force $runtime | Out-Null
Copy-Item (Join-Path $sourceRoot 'studio_small_09.hdr') (Join-Path $runtime 'studio_small_09.hdr')
$manifest | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $runtime 'asset-sources.json') -Encoding utf8
Write-Output "Verified $($manifest.Count) CC0 source files."
