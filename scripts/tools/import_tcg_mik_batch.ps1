param(
	[Parameter(Mandatory = $false)]
	[string]$SetCode = "CSV10C",

	[Parameter(Mandatory = $true)]
	[int]$From,

	[Parameter(Mandatory = $true)]
	[int]$To,

	[Parameter(Mandatory = $false)]
	[string]$SourceCacheDir = ""
)

$ErrorActionPreference = "Stop"

if ($From -lt 1 -or $To -lt $From) {
	throw "Invalid card range: $From-$To"
}
if (($To - $From + 1) -gt 5) {
	throw "Card-audit batches are limited to at most five cards."
}

$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$cardsRoot = Join-Path $workspaceRoot "data\bundled_user\cards"
$imagesRoot = Join-Path $cardsRoot ("images\{0}" -f $SetCode)
$manifestPath = Join-Path $workspaceRoot "data\bundled_user\_manifest.txt"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$apiUrl = "https://tcg.mik.moe/api/v3/card/card-detail"
$headers = @{ "User-Agent" = "PTCGTrain/1.0" }

New-Item -ItemType Directory -Force -Path $cardsRoot | Out-Null
New-Item -ItemType Directory -Force -Path $imagesRoot | Out-Null
if ($SourceCacheDir -ne "") {
	New-Item -ItemType Directory -Force -Path $SourceCacheDir | Out-Null
}

function Convert-ToString([object]$Value) {
	if ($Value -is [string]) {
		return $Value
	}
	return ""
}

function Convert-ToTags([object]$Value) {
	$tags = New-Object System.Collections.Generic.List[string]
	if ($Value -is [System.Array]) {
		foreach ($entry in $Value) {
			$text = Convert-ToString $entry
			if ($text -ne "" -and -not $tags.Contains($text)) {
				$tags.Add($text)
			}
		}
	} else {
		$text = Convert-ToString $Value
		if ($text -ne "") {
			$tags.Add($text)
		}
	}
	return $tags.ToArray()
}

function Get-SourceCard([string]$CardIndex) {
	$cachePath = ""
	if ($SourceCacheDir -ne "") {
		$cachePath = Join-Path $SourceCacheDir ("{0}.json" -f $CardIndex)
		if (Test-Path -LiteralPath $cachePath) {
			return Get-Content -Raw -Encoding UTF8 -LiteralPath $cachePath | ConvertFrom-Json
		}
	}

	$body = @{ setCode = $SetCode; cardIndex = $CardIndex } | ConvertTo-Json -Compress
	$response = $null
	for ($attempt = 1; $attempt -le 3; $attempt++) {
		try {
			$response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -ContentType "application/json" -Body $body
			break
		} catch {
			if ($attempt -eq 3) {
				throw
			}
			Start-Sleep -Milliseconds (250 * $attempt)
		}
	}
	if ($response.code -ne 200 -or $null -eq $response.data) {
		throw "Card API failed for ${SetCode}_${CardIndex}"
	}
	if ($cachePath -ne "") {
		$sourceJson = $response.data | ConvertTo-Json -Depth 30
		[System.IO.File]::WriteAllText($cachePath, $sourceJson + "`n", $utf8NoBom)
	}
	return $response.data
}

function Convert-ToLocalCard([object]$Source) {
	$attributes = $Source.pokemonAttr
	$weakness = if ($null -ne $attributes) { $attributes.weakness } else { $null }
	$resistance = if ($null -ne $attributes) { $attributes.resistance } else { $null }
	$attacks = New-Object System.Collections.Generic.List[object]
	$abilities = New-Object System.Collections.Generic.List[object]

	if ($null -ne $attributes) {
		foreach ($attack in @($attributes.attack)) {
			if ($null -eq $attack) {
				continue
			}
			$cost = Convert-ToString $attack.cost
			if ($cost -eq "0") {
				$cost = ""
			}
			$attacks.Add([ordered]@{
				name = Convert-ToString $attack.name
				text = Convert-ToString $attack.text
				cost = $cost
				damage = Convert-ToString $attack.damage
				is_vstar_power = ($attack.isVStarPower -eq $true)
			})
		}
		foreach ($ability in @($attributes.ability)) {
			if ($null -eq $ability) {
				continue
			}
			$abilities.Add([ordered]@{
				name = Convert-ToString $ability.name
				text = Convert-ToString $ability.text
			})
		}
	}

	$tags = New-Object System.Collections.Generic.List[string]
	foreach ($tag in @(Convert-ToTags $Source.is)) {
		if (-not $tags.Contains($tag)) {
			$tags.Add($tag)
		}
	}
	foreach ($tag in @(Convert-ToTags $Source.label)) {
		if (-not $tags.Contains($tag)) {
			$tags.Add($tag)
		}
	}

	$label = ""
	if ($Source.label -is [System.Array]) {
		$label = (@($Source.label | ForEach-Object { Convert-ToString $_ } | Where-Object { $_ -ne "" }) -join ", ")
	} else {
		$label = Convert-ToString $Source.label
	}

	$standardLegal = $true
	$expandedLegal = $true
	if ($null -ne $Source.regulationLegal) {
		if ($null -ne $Source.regulationLegal.standard) {
			$standardLegal = [bool]$Source.regulationLegal.standard
		}
		if ($null -ne $Source.regulationLegal.expanded) {
			$expandedLegal = [bool]$Source.regulationLegal.expanded
		}
	}

	$cardIndex = Convert-ToString $Source.cardIndex
	return [ordered]@{
		name = Convert-ToString $Source.name
		card_type = Convert-ToString $Source.cardType
		mechanic = Convert-ToString $Source.mechanic
		label = $label
		description = Convert-ToString $Source.description
		yoren_code = Convert-ToString $Source.yorenCode
		set_code = Convert-ToString $Source.setCode
		card_index = $cardIndex
		set_code_en = Convert-ToString $Source.setCodeEn
		card_index_en = Convert-ToString $Source.cardIndexEn
		name_en = Convert-ToString $Source.nameEn
		name_zh = ""
		artist = Convert-ToString $Source.artist
		rarity = Convert-ToString $Source.rarity
		release_date = Convert-ToString $Source.releaseDate
		regulation_mark = Convert-ToString $Source.regulationMark
		effect_id = Convert-ToString $Source.effectId
		image_url = "https://tcg.mik.moe/static/img/$SetCode/$cardIndex.png"
		image_local_path = "user://cards/images/$SetCode/$cardIndex.png"
		source_provider = "tcg_mik"
		source_url = "https://tcg.mik.moe/cards/$SetCode/$cardIndex"
		source_set_code = $SetCode
		source_card_index = $cardIndex
		source_language = "zh-CN"
		source_prints = @()
		source_imported_at = 0
		source_parser_version = 1
		is_tags = $tags.ToArray()
		regulation_standard = $standardLegal
		regulation_expanded = $expandedLegal
		energy_type = if ($null -ne $attributes) { Convert-ToString $attributes.energyType } else { "" }
		stage = if ($null -ne $attributes) { Convert-ToString $attributes.stage } else { "" }
		hp = if ($null -ne $attributes) { [int]$attributes.hp } else { 0 }
		weakness_energy = if ($null -ne $weakness) { Convert-ToString $weakness.energy } else { "" }
		weakness_value = if ($null -ne $weakness) { Convert-ToString $weakness.value } else { "" }
		resistance_energy = if ($null -ne $resistance) { Convert-ToString $resistance.energy } else { "" }
		resistance_value = if ($null -ne $resistance) { Convert-ToString $resistance.value } else { "" }
		retreat_cost = if ($null -ne $attributes) { [int]$attributes.retreatCost } else { 0 }
		evolves_from = if ($null -ne $attributes) { Convert-ToString $attributes.evolvesFrom } else { "" }
		ancient_trait = if ($null -ne $attributes) { Convert-ToString $attributes.ancientTrait } else { "" }
		attacks = $attacks.ToArray()
		abilities = $abilities.ToArray()
		energy_provides = ""
	}
}

$manifestEntries = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::Ordinal)
if (Test-Path -LiteralPath $manifestPath) {
	foreach ($line in [System.IO.File]::ReadAllLines($manifestPath, [System.Text.Encoding]::UTF8)) {
		$trimmed = $line.Trim()
		if ($trimmed -ne "") {
			[void]$manifestEntries.Add($trimmed)
		}
	}
}

$imported = New-Object System.Collections.Generic.List[string]
for ($number = $From; $number -le $To; $number++) {
	$cardIndex = "{0:D3}" -f $number
	$source = Get-SourceCard $cardIndex
	if ((Convert-ToString $source.setCode) -ne $SetCode -or (Convert-ToString $source.cardIndex) -ne $cardIndex) {
		throw "API identity mismatch for ${SetCode}_${cardIndex}"
	}

	$localCard = Convert-ToLocalCard $source
	$cardPath = Join-Path $cardsRoot ("{0}_{1}.json" -f $SetCode, $cardIndex)
	$cardJson = $localCard | ConvertTo-Json -Depth 30
	[System.IO.File]::WriteAllText($cardPath, $cardJson + "`n", $utf8NoBom)

	$imagePath = Join-Path $imagesRoot ("{0}.png.bin" -f $cardIndex)
	$imageUrl = "https://tcg.mik.moe/static/img/$SetCode/$cardIndex.png"
	Invoke-WebRequest -Uri $imageUrl -Headers $headers -OutFile $imagePath -UseBasicParsing
	$imageBytes = [System.IO.File]::ReadAllBytes($imagePath)
	if ($imageBytes.Length -lt 8 -or $imageBytes[0] -ne 0x89 -or $imageBytes[1] -ne 0x50 -or $imageBytes[2] -ne 0x4E -or $imageBytes[3] -ne 0x47) {
		throw "Downloaded image is not PNG: $imageUrl"
	}

	[void]$manifestEntries.Add("res://data/bundled_user/cards/${SetCode}_${cardIndex}.json")
	[void]$manifestEntries.Add("res://data/bundled_user/cards/images/$SetCode/$cardIndex.png.bin")
	$imported.Add("${SetCode}_${cardIndex}")
}

$sortedManifest = @($manifestEntries) | Sort-Object
[System.IO.File]::WriteAllText($manifestPath, ($sortedManifest -join "`n") + "`n", $utf8NoBom)

Write-Output ("Imported {0}: {1}" -f $imported.Count, ($imported -join ", "))
