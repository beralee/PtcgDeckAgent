class_name CardCatalogSearchRecord
extends RefCounted

## Fields that must be available without materializing a full catalog set.
## Keep search/index projection in one place so new Pokemon metadata cannot be
## silently dropped by one UI consumer while remaining present in CardData.
const INDEX_FIELDS := [
	"name",
	"name_en",
	"name_zh",
	"card_type",
	"mechanic",
	"label",
	"is_tags",
	"set_code",
	"card_index",
	"set_code_en",
	"card_index_en",
	"rarity",
	"regulation_mark",
	"effect_id",
	"source_provider",
	"source_set_code",
	"source_card_index",
	"source_prints",
	"energy_type",
	"stage",
	"hp",
	"image_url",
	"ancient_trait",
]


static func from_card(card: CardData) -> Dictionary:
	if card == null:
		return {}
	return from_dictionary(card.to_dict())


static func from_dictionary(source: Dictionary) -> Dictionary:
	var result := {}
	for field: String in INDEX_FIELDS:
		if source.has(field):
			result[field] = source[field]
	return result


static func to_minimal_card_dict(entry: Dictionary) -> Dictionary:
	var result := from_dictionary(entry)
	var set_code := str(result.get("set_code", "")).strip_edges()
	var card_index := str(result.get("card_index", "")).strip_edges()
	result["image_local_path"] = CardData.build_local_image_path(set_code, card_index)
	return result
