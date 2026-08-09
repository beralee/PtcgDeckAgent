extends SceneTree

const CardImplementationStatusScript := preload("res://scripts/engine/CardImplementationStatus.gd")
const CardCatalogSearchRecordScript := preload("res://scripts/card_catalog/CardCatalogSearchRecord.gd")

const SOURCE_CARD_DIRECTORIES := [
	{
		"path": "res://tools/card_catalog_sources/cards",
		"provider": "catalog_sources",
	},
	{
		"path": "res://data/bundled_user/cards",
		"provider": "bundled_user_cards",
	},
]
const OUTPUT_ROOT := "res://data/card_catalog"
const OUTPUT_SETS_DIR := "res://data/card_catalog/sets"
const CATALOG_SCHEMA_VERSION := 2
const SET_PAYLOAD_SCHEMA_VERSION := 1


func _initialize() -> void:
	var exit_code := _build()
	quit(exit_code)


func _build() -> int:
	var cards := _load_source_cards()
	if cards.is_empty():
		push_error("Card catalog builder: no source cards found")
		return 1

	_ensure_dir(OUTPUT_ROOT)
	_ensure_dir(OUTPUT_SETS_DIR)

	var grouped := {}
	for card: CardData in cards:
		var set_code := card.set_code.strip_edges()
		if set_code == "":
			continue
		if not grouped.has(set_code):
			grouped[set_code] = []
		(grouped[set_code] as Array).append(card)

	var set_codes := grouped.keys()
	set_codes.sort()

	var index_cards: Array[Dictionary] = []
	var manifest_sets: Array[Dictionary] = []
	var total_cards := 0
	for set_code_variant: Variant in set_codes:
		var set_code := str(set_code_variant)
		var set_cards: Array = grouped[set_code]
		set_cards.sort_custom(func(a: CardData, b: CardData) -> bool:
			return _card_sort_key(a) < _card_sort_key(b)
		)
		var set_payload_cards: Array[Dictionary] = []
		for raw_card: Variant in set_cards:
			var card := raw_card as CardData
			var card_dict := card.to_dict()
			set_payload_cards.append(card_dict)
			index_cards.append(_index_entry_for_card(card, "sets/%s.json" % set_code))
			total_cards += 1
		var set_payload := {
			"schema_version": SET_PAYLOAD_SCHEMA_VERSION,
			"set_code": set_code,
			"cards": set_payload_cards,
		}
		var set_text := JSON.stringify(set_payload, "\t")
		var set_path := OUTPUT_SETS_DIR.path_join("%s.json" % set_code)
		if _write_text(set_path, set_text) != OK:
			return 1
		manifest_sets.append({
			"set_code": set_code,
			"path": "sets/%s.json" % set_code,
			"card_count": set_payload_cards.size(),
			"sha256": set_text.sha256_text(),
		})

	index_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("uid", "")) < str(b.get("uid", ""))
	)
	var index_payload := {
		"schema_version": CATALOG_SCHEMA_VERSION,
		"catalog_version": _catalog_version(),
		"cards": index_cards,
	}
	var index_text := JSON.stringify(index_payload, "\t")
	if _write_text(OUTPUT_ROOT.path_join("index.json"), index_text) != OK:
		return 1

	var manifest := {
		"schema_version": CATALOG_SCHEMA_VERSION,
		"catalog_version": _catalog_version(),
		"generated_at": "2026-07-12T00:00:00+08:00",
		"card_count": total_cards,
		"index_file": {
			"path": "index.json",
			"sha256": index_text.sha256_text(),
		},
		"sets": manifest_sets,
		"sources": _manifest_sources(),
	}
	if _write_text(OUTPUT_ROOT.path_join("catalog_manifest.json"), JSON.stringify(manifest, "\t")) != OK:
		return 1
	print("Card catalog built: %d cards across %d sets" % [total_cards, set_codes.size()])
	return 0


func _load_source_cards() -> Array[CardData]:
	var cards_by_uid: Dictionary = {}
	for source: Dictionary in SOURCE_CARD_DIRECTORIES:
		var source_path := str(source.get("path", ""))
		for file_name: String in _source_card_file_names(source_path):
			var data := _load_json_dictionary(source_path.path_join(file_name))
			if data.is_empty():
				continue
			var card := CardData.from_dict(data)
			if card.set_code == "" or card.card_index == "":
				continue
			cards_by_uid[card.get_uid()] = card
	var cards: Array[CardData] = []
	for raw_card: Variant in cards_by_uid.values():
		cards.append(raw_card as CardData)
	cards.sort_custom(func(a: CardData, b: CardData) -> bool:
		return _card_sort_key(a) < _card_sort_key(b)
	)
	return cards


func _source_card_file_names(source_path: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(source_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json"):
			result.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


func _index_entry_for_card(card: CardData, set_file: String) -> Dictionary:
	var status := CardImplementationStatusScript.get_status(card)
	var implementation_status := "text_only" if bool(status.get("unimplemented", false)) else "implemented"
	var entry := CardCatalogSearchRecordScript.from_card(card)
	entry.merge({
		"uid": card.get_uid(),
		"implementation_status": implementation_status,
		"implementation_reason": str(status.get("reason", "")),
		"set_file": set_file,
		"image_key": "%s/%s" % [card.set_code, card.card_index],
	}, true)
	return entry


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _write_text(path: String, text: String) -> int:
	_ensure_dir(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		push_error("Card catalog builder: failed to write %s err=%d" % [path, err])
		return err
	file.store_string(text)
	file.close()
	return OK


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _catalog_version() -> String:
	return "2026.08.02.1"


func _manifest_sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source: Dictionary in SOURCE_CARD_DIRECTORIES:
		result.append({
			"provider": str(source.get("provider", "")),
			"snapshot": "local",
		})
	return result


func _card_sort_key(card: CardData) -> String:
	return "%s_%s" % [card.set_code, card.card_index]
