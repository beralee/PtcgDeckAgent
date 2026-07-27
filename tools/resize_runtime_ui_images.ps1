param(
	[string]$FfmpegPath = "ffmpeg",
	[string]$FfprobePath = "ffprobe",
	[switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$uiRoot = (Resolve-Path (Join-Path $projectRoot "assets\ui")).Path
if (-not $uiRoot.StartsWith($projectRoot, [StringComparison]::OrdinalIgnoreCase)) {
	throw "UI asset root must stay inside the project"
}

$ffmpeg = Get-Command $FfmpegPath -ErrorAction Stop
$ffprobe = Get-Command $FfprobePath -ErrorAction Stop
$profiles = @()

foreach ($name in @("vstar.png", "vstar1.png", "vstar2.png")) {
	$profiles += [pscustomobject]@{
		Path = Join-Path $uiRoot $name
		Width = 768
		Height = 256
	}
}
foreach ($file in Get-ChildItem -LiteralPath $uiRoot -File -Filter "e-*.png") {
	$profiles += [pscustomobject]@{
		Path = $file.FullName
		Width = 256
		Height = 256
	}
}
foreach ($name in @("coin_heads.png", "coin_tails.png")) {
	$profiles += [pscustomobject]@{
		Path = Join-Path $uiRoot $name
		Width = 512
		Height = 512
	}
}

$beforeBytes = [int64]((
	$profiles |
		ForEach-Object { (Get-Item -LiteralPath $_.Path).Length } |
		Measure-Object -Sum
).Sum)
Write-Host ("Runtime UI images: {0}, before: {1:N2} MiB" -f $profiles.Count, ($beforeBytes / 1MB))
if ($WhatIf) {
	exit 0
}

foreach ($profile in $profiles) {
	$target = [IO.Path]::GetFullPath($profile.Path)
	if (-not $target.StartsWith($uiRoot, [StringComparison]::OrdinalIgnoreCase)) {
		throw "Refusing to resize a file outside the UI asset root: $target"
	}
	$tempPath = "$target.optimized.png"
	if (Test-Path -LiteralPath $tempPath) {
		Remove-Item -LiteralPath $tempPath -Force
	}
	& $ffmpeg.Source `
		-hide_banner `
		-loglevel error `
		-y `
		-i $target `
		-vf "scale=$($profile.Width):$($profile.Height):flags=lanczos" `
		-frames:v 1 `
		-compression_level 9 `
		-pred mixed `
		$tempPath
	if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tempPath)) {
		throw "ffmpeg failed to resize $target"
	}
	$dimensions = (
		& $ffprobe.Source `
			-v error `
			-select_streams v:0 `
			-show_entries stream=width,height `
			-of csv=p=0 `
			-- $tempPath
	).Trim()
	$expectedDimensions = "$($profile.Width),$($profile.Height)"
	if ($dimensions -ne $expectedDimensions) {
		Remove-Item -LiteralPath $tempPath -Force
		throw "Unexpected dimensions for $target`: $dimensions, expected $expectedDimensions"
	}
	Move-Item -LiteralPath $tempPath -Destination $target -Force
}

$afterBytes = [int64]((
	$profiles |
		ForEach-Object { (Get-Item -LiteralPath $_.Path).Length } |
		Measure-Object -Sum
).Sum)
$savedBytes = $beforeBytes - $afterBytes
Write-Host ("After: {0:N2} MiB, saved: {1:N2} MiB ({2:N1}%)" -f @(
	($afterBytes / 1MB),
	($savedBytes / 1MB),
	(100.0 * $savedBytes / [Math]::Max($beforeBytes, 1))
))
