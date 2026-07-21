class_name CardCatalogIndex
extends RefCounted

const BUNDLED_ROOT := "res://data/card_catalog"
const USER_ROOT := "user://card_catalog"
const BUNDLED_MANIFEST := "catalog_manifest.json"
const USER_MANIFEST := "remote_manifest.json"

var _bundled_root := BUNDLED_ROOT
var _user_root := USER_ROOT
var _active_root := ""
var _manifest: Dictionary = {}
var _entries_by_uid: Dictionary = {}
var _entry_order: PackedStringArray = PackedStringArray()
var _set_cache: Dictionary = {}


func _init(bundled_root: String = BUNDLED_ROOT, user_root: String = USER_ROOT) -> void:
	_bundled_root = bundled_root
	_user_root = user_root
	reload()


func reload() -> void:
	_manifest.clear()
	_entries_by_uid.clear()
	_entry_order.clear()
	_set_cache.clear()
	_active_root = ""

	var bundled_manifest := _load_manifest(_bundled_root.path_join(BUNDLED_MANIFEST))
	var user_manifest := _load_manifest(_user_root.path_join(USER_MANIFEST))
	var use_user := false
	if not user_manifest.is_empty() and _catalog_version_is_newer(
		str(user_manifest.get("catalog_version", "")),
		str(bundled_manifest.get("catalog_version", ""))
	):
		use_user = _load_index_for_manifest(_user_root, user_manifest)
	if not use_user and not bundled_manifest.is_empty():
		_load_index_for_manifest(_bundled_root, bundled_manifest)


func is_ready() -> bool:
	return not _manifest.is_empty() and not _entries_by_uid.is_empty()


func get_catalog_version() -> String:
	return str(_manifest.get("catalog_version", ""))


func get_active_root_for_tests() -> String:
	return _active_root


func materialized_set_count_for_tests() -> int:
	return _set_cache.size()


func card_count() -> int:
	return _entries_by_uid.size()


func has_card(set_code: String, card_index: String) -> bool:
	return _entries_by_uid.has(_uid(set_code, card_index))


func get_entry(set_code: String, card_index: String) -> Dictionary:
	var entry: Variant = _entries_by_uid.get(_uid(set_code, card_index), {})
	if entry is Dictionary:
		return (entry as Dictionary).duplicate(true)
	return {}


func get_card_data(set_code: String, card_index: String) -> CardData:
	var uid := _uid(set_code, card_index)
	var entry: Dictionary = _entries_by_uid.get(uid, {})
	if entry.is_empty():
		return null
	var card_dict := _load_card_dict_for_entry(entry)
	if card_dict.is_empty():
		card_dict = _minimal_card_dict_from_entry(entry)
	var card := CardData.from_dict(card_dict)
	if card.set_code == "":
		card.set_code = str(entry.get("set_code", set_code))
	if card.card_index == "":
		card.card_index = str(entry.get("card_index", card_index))
	card.ensure_image_metadata()
	return card


func search_cards(query: String, filters: Dictionary = {}, limit: int = 50, offset: int = 0) -> Array[Dictionary]:
	var normalized_query := query.strip_edges().to_lower()
	var start := maxi(0, offset)
	var max_count := limit if limit > 0 else _entry_order.size()
	var skipped := 0
	var results: Array[Dictionary] = []
	for uid: String in _entry_order:
		var entry: Dictionary = _entries_by_uid.get(uid, {})
		if entry.is_empty():
			continue
		if not _matches_query(entry, normalized_query):
			continue
		if not _matches_filters(entry, filters):
			continue
		if skipped < start:
			skipped += 1
			continue
		results.append(entry.duplicate(true))
		if results.size() >= max_count:
			break
	return results


func get_cards_by_uids(uids: PackedStringArray) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for uid: String in uids:
		var entry: Dictionary = _entries_by_uid.get(uid, {})
		if not entry.is_empty():
			results.append(entry.duplicate(true))
	return results


func find_entries_by_source_ref(source_set_code: String, source_card_index: String) -> Array[Dictionary]:
	var normalized_set := source_set_code.strip_edges().to_upper()
	var normalized_index := source_card_index.strip_edges().to_upper()
	if normalized_set == "" or normalized_index == "":
		return []
	var ref := "%s/%s" % [normalized_set, normalized_index]
	var results: Array[Dictionary] = []
	for uid: String in _entry_order:
		var entry: Dictionary = _entries_by_uid.get(uid, {})
		if entry.is_empty():
			continue
		if _entry_matches_source_ref(entry, normalized_set, normalized_index, ref):
			results.append(entry.duplicate(true))
	return results


func _load_manifest(path: String) -> Dictionary:
	var parsed := _load_json_dictionary(path)
	if parsed.is_empty():
		return {}
	if int(parsed.get("schema_version", 0)) <= 0:
		return {}
	return parsed


func _load_index_for_manifest(root_path: String, manifest: Dictionary) -> bool:
	var index_info: Dictionary = manifest.get("index_file", {}) if manifest.get("index_file", {}) is Dictionary else {}
	var index_path := str(index_info.get("path", "index.json")).strip_edges()
	if index_path == "":
		index_path = "index.json"
	var index_data := _load_json_dictionary(root_path.path_join(index_path))
	var raw_cards: Variant = index_data.get("cards", [])
	if not (raw_cards is Array):
		return false

	var entries_by_uid := {}
	var entry_order := PackedStringArray()
	for raw_card: Variant in raw_cards:
		if not (raw_card is Dictionary):
			continue
		var entry := (raw_card as Dictionary).duplicate(true)
		var set_code := str(entry.get("set_code", "")).strip_edges()
		var card_index := str(entry.get("card_index", "")).strip_edges()
		var uid := str(entry.get("uid", "")).strip_edges()
		if uid == "":
			uid = _uid(set_code, card_index)
			entry["uid"] = uid
		if set_code == "" or card_index == "" or uid == "_":
			continue
		entries_by_uid[uid] = entry
		entry_order.append(uid)
	if entries_by_uid.is_empty():
		return false

	_manifest = manifest.duplicate(true)
	_entries_by_uid = entries_by_uid
	_entry_order = entry_order
	_active_root = root_path
	return true


func _load_card_dict_for_entry(entry: Dictionary) -> Dictionary:
	var set_file := str(entry.get("set_file", "")).strip_edges()
	if set_file == "":
		var set_code := str(entry.get("set_code", "")).strip_edges()
		if set_code == "":
			return {}
		set_file = "sets/%s.json" % set_code
	var set_cards := _load_set_cards(set_file)
	var uid := str(entry.get("uid", "")).strip_edges()
	var card_dict: Variant = set_cards.get(uid, {})
	if card_dict is Dictionary:
		return (card_dict as Dictionary).duplicate(true)
	return {}


func _load_set_cards(set_file: String) -> Dictionary:
	if _set_cache.has(set_file):
		return _set_cache[set_file]
	var result := {}
	if _active_root == "":
		_set_cache[set_file] = result
		return result
	var set_data := _load_json_dictionary(_active_root.path_join(set_file))
	var raw_cards: Variant = set_data.get("cards", [])
	if raw_cards is Array:
		for raw_card: Variant in raw_cards:
			if not (raw_card is Dictionary):
				continue
			var card_dict := raw_card as Dictionary
			var uid := _uid(str(card_dict.get("set_code", "")), str(card_dict.get("card_index", "")))
			if uid != "_":
				result[uid] = card_dict.duplicate(true)
	_set_cache[set_file] = result
	return result


func _minimal_card_dict_from_entry(entry: Dictionary) -> Dictionary:
	var set_code := str(entry.get("set_code", ""))
	var card_index := str(entry.get("card_index", ""))
	return {
		"name": str(entry.get("name", "")),
		"name_en": str(entry.get("name_en", "")),
		"name_zh": str(entry.get("name_zh", "")),
		"card_type": str(entry.get("card_type", "")),
		"mechanic": str(entry.get("mechanic", "")),
		"label": str(entry.get("label", "")),
		"is_tags": entry.get("is_tags", []),
		"set_code": set_code,
		"card_index": card_index,
		"set_code_en": str(entry.get("set_code_en", "")),
		"card_index_en": str(entry.get("card_index_en", "")),
		"rarity": str(entry.get("rarity", "")),
		"regulation_mark": str(entry.get("regulation_mark", "")),
		"effect_id": str(entry.get("effect_id", "")),
		"source_provider": str(entry.get("source_provider", "")),
		"source_set_code": str(entry.get("source_set_code", "")),
		"source_card_index": str(entry.get("source_card_index", "")),
		"source_prints": entry.get("source_prints", []),
		"energy_type": str(entry.get("energy_type", "")),
		"stage": str(entry.get("stage", "")),
		"hp": int(entry.get("hp", 0)),
		"image_url": str(entry.get("image_url", "")),
		"image_local_path": CardData.build_local_image_path(set_code, card_index),
	}


func _matches_query(entry: Dictionary, normalized_query: String) -> bool:
	if normalized_query == "":
		return true
	var searchable_parts := PackedStringArray()
	for key: String in ["name", "name_zh", "name_en", "set_code", "card_index", "uid", "card_type", "mechanic", "label"]:
		searchable_parts.append(str(entry.get(key, "")).to_lower())
	var haystack := " ".join(searchable_parts)
	for token: String in normalized_query.replace("\t", " ").split(" ", false):
		if haystack.find(token) < 0:
			return false
	return true


func _matches_filters(entry: Dictionary, filters: Dictionary) -> bool:
	for key: Variant in filters.keys():
		var filter_key := str(key)
		var expected: Variant = filters[key]
		if expected == null:
			continue
		if expected is String and str(expected).strip_edges() == "":
			continue
		match filter_key:
			"card_type", "set_code", "energy_type", "mechanic", "stage", "regulation_mark", "implementation_status", "label":
				if str(entry.get(filter_key, "")) != str(expected):
					return false
			"implemented_only":
				if bool(expected) and str(entry.get("implementation_status", "implemented")) not in ["implemented", "implemented_by_alias", "generic_supported"]:
					return false
			"statuses":
				var statuses: Array = expected if expected is Array else []
				if not statuses.is_empty() and str(entry.get("implementation_status", "")) not in statuses:
					return false
	return true


func _entry_matches_source_ref(entry: Dictionary, normalized_set: String, normalized_index: String, ref: String) -> bool:
	var direct_set := str(entry.get("source_set_code", "")).strip_edges().to_upper()
	var direct_index := str(entry.get("source_card_index", "")).strip_edges().to_upper()
	if direct_set == normalized_set and direct_index == normalized_index:
		return true
	var english_set := str(entry.get("set_code_en", "")).strip_edges().to_upper()
	var english_index := str(entry.get("card_index_en", "")).strip_edges().to_upper()
	if english_set == normalized_set and english_index == normalized_index:
		return true
	var source_prints: Variant = entry.get("source_prints", [])
	if source_prints is Array:
		for raw_ref: Variant in source_prints:
			if str(raw_ref).strip_edges().to_upper() == ref:
				return true
	elif source_prints is PackedStringArray:
		for raw_ref: String in source_prints:
			if raw_ref.strip_edges().to_upper() == ref:
				return true
	return false


func _load_json_dictionary(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
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


func _catalog_version_is_newer(candidate: String, baseline: String) -> bool:
	if baseline.strip_edges() == "":
		return candidate.strip_edges() != ""
	var candidate_parts := _version_parts(candidate)
	var baseline_parts := _version_parts(baseline)
	var count := maxi(candidate_parts.size(), baseline_parts.size())
	for i: int in range(count):
		var candidate_value := int(candidate_parts[i]) if i < candidate_parts.size() else 0
		var baseline_value := int(baseline_parts[i]) if i < baseline_parts.size() else 0
		if candidate_value != baseline_value:
			return candidate_value > baseline_value
	return candidate > baseline


func _version_parts(version: String) -> Array[int]:
	var parts: Array[int] = []
	for token: String in version.split(".", false):
		if token.is_valid_int():
			parts.append(int(token))
		else:
			var digits := ""
			for i: int in range(token.length()):
				var ch := token.substr(i, 1)
				if ch.is_valid_int():
					digits += ch
			parts.append(int(digits) if digits != "" else 0)
	return parts


func _uid(set_code: String, card_index: String) -> String:
	return "%s_%s" % [set_code.strip_edges(), card_index.strip_edges()]
