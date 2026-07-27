param(
	[string]$CardImageRoot = "data/bundled_user/cards/images",
	[ValidateRange(1, 100)]
	[int]$Quality = 92,
	[ValidateRange(0, 6)]
	[int]$CompressionLevel = 6,
	[string]$FfmpegPath = "ffmpeg",
	[switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$resolvedImageRoot = (Resolve-Path (Join-Path $projectRoot $CardImageRoot)).Path
$expectedImageRoot = (Join-Path $projectRoot "data\bundled_user\cards\images")
if (-not $resolvedImageRoot.StartsWith($expectedImageRoot, [StringComparison]::OrdinalIgnoreCase)) {
	throw "Card image root must stay inside $expectedImageRoot"
}

$ffmpeg = Get-Command $FfmpegPath -ErrorAction Stop

function Get-WebPCodec {
	param([byte[]]$Bytes)
	if ($Bytes.Length -lt 20) {
		return ""
	}
	if (
		[Text.Encoding]::ASCII.GetString($Bytes, 0, 4) -ne "RIFF" -or
		[Text.Encoding]::ASCII.GetString($Bytes, 8, 4) -ne "WEBP"
	) {
		return ""
	}
	$offset = 12
	while ($offset + 8 -le $Bytes.Length) {
		$chunkName = [Text.Encoding]::ASCII.GetString($Bytes, $offset, 4)
		$chunkLength = [BitConverter]::ToUInt32($Bytes, $offset + 4)
		if ($chunkName -eq "VP8L" -or $chunkName -eq "VP8 ") {
			return $chunkName.Trim()
		}
		$offset += 8 + [int]$chunkLength + ([int]$chunkLength % 2)
	}
	return ""
}

function Test-PngSignature {
	param([byte[]]$Bytes)
	$signature = [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
	if ($Bytes.Length -lt $signature.Length) {
		return $false
	}
	for ($index = 0; $index -lt $signature.Length; $index++) {
		if ($Bytes[$index] -ne $signature[$index]) {
			return $false
		}
	}
	return $true
}

$candidates = @()
$beforeBytes = [int64]0
Get-ChildItem -LiteralPath $resolvedImageRoot -Recurse -File -Filter "*.png.bin" | ForEach-Object {
	$bytes = [IO.File]::ReadAllBytes($_.FullName)
	$isPng = Test-PngSignature $bytes
	$webpCodec = Get-WebPCodec $bytes
	if ($isPng -or $webpCodec -eq "VP8L") {
		$candidates += $_
		$beforeBytes += $_.Length
	}
}

Write-Host ("Eligible card images: {0}, before: {1:N2} MiB" -f $candidates.Count, ($beforeBytes / 1MB))
if ($WhatIf) {
	exit 0
}

$changed = 0
$afterBytes = [int64]0
foreach ($file in $candidates) {
	$resolvedTarget = [IO.Path]::GetFullPath($file.FullName)
	if (-not $resolvedTarget.StartsWith($resolvedImageRoot, [StringComparison]::OrdinalIgnoreCase)) {
		throw "Refusing to rewrite a file outside the card image root: $resolvedTarget"
	}
	$tempPath = "$resolvedTarget.optimized.webp"
	if (Test-Path -LiteralPath $tempPath) {
		Remove-Item -LiteralPath $tempPath -Force
	}
	& $ffmpeg.Source `
		-hide_banner `
		-loglevel error `
		-y `
		-i $resolvedTarget `
		-c:v libwebp `
		-quality $Quality `
		-compression_level $CompressionLevel `
		$tempPath
	if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tempPath)) {
		throw "ffmpeg failed to encode $resolvedTarget"
	}
	$optimized = Get-Item -LiteralPath $tempPath
	$optimizedBytes = [IO.File]::ReadAllBytes($optimized.FullName)
	if ((Get-WebPCodec $optimizedBytes) -eq "") {
		Remove-Item -LiteralPath $tempPath -Force
		throw "Optimized output is not a valid WebP file: $resolvedTarget"
	}
	if ($optimized.Length -ge $file.Length) {
		$afterBytes += $file.Length
		Remove-Item -LiteralPath $tempPath -Force
		continue
	}
	Move-Item -LiteralPath $tempPath -Destination $resolvedTarget -Force
	$afterBytes += $optimized.Length
	$changed += 1
}

$savedBytes = $beforeBytes - $afterBytes
Write-Host ("Re-encoded: {0}, after: {1:N2} MiB, saved: {2:N2} MiB ({3:N1}%)" -f @(
	$changed,
	($afterBytes / 1MB),
	($savedBytes / 1MB),
	(100.0 * $savedBytes / [Math]::Max($beforeBytes, 1))
))
