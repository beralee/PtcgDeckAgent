extends RefCounted

const CardIdCatalogScript = preload("res://scripts/ai/ptcgdap/host/godot/CardIdCatalog.gd")
const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const MAX_SAFE_INTEGER := 9007199254740991
const WINDOWS_LOCAL_DECK_DOMAIN := "godot_local_card_uid_v1"


static func build(payloads: Variant) -> Dictionary:
	if not payloads is Dictionary or not payloads.has("deck/deck.csv") or not payloads.has("deck/deck_manifest.json"):
		return _error()
	var manifest_bytes: Variant = payloads.get("deck/deck_manifest.json")
	if not manifest_bytes is PackedByteArray:
		return _error()
	var manifest: Variant = JSON.parse_string((manifest_bytes as PackedByteArray).get_string_from_utf8())
	if not manifest is Dictionary:
		return _error()
	if manifest.get("card_id_domain") == WINDOWS_LOCAL_DECK_DOMAIN:
		return _build_windows_local(payloads.get("deck/deck.csv"), manifest)
	var rows_result := _parse_csv(payloads.get("deck/deck.csv"))
	if not bool(rows_result.get("ok", false)):
		return _error()
	var catalog: Variant = CardIdCatalogScript.load_default()
	if catalog == null or not bool(catalog.get("ok")):
		return _error()
	var mapped: Array[Dictionary] = []
	var total := 0
	var basic_pokemon := 0
	for row_value in rows_result.get("rows", []):
		var row: Dictionary = row_value
		var official_card_id := int(row.get("official_card_id", -1))
		var count := int(row.get("count", 0))
		var lookup: Dictionary = catalog.lookup_local_printing_for_official_card(official_card_id)
		if not bool(lookup.get("ok", false)):
			return _error()
		var value: Variant = lookup.get("value")
		if not value is Dictionary or not value.get("local_printing") is Dictionary:
			return _error()
		var printing: Dictionary = value.get("local_printing")
		var set_code := str(printing.get("set_code", ""))
		var card_index := str(printing.get("card_index", ""))
		var source_path := "res://data/bundled_user/cards/%s_%s.json" % [set_code, card_index]
		var source_file := FileAccess.open(source_path, FileAccess.READ)
		if source_file == null:
			return _error()
		var source_bytes := source_file.get_buffer(source_file.get_length())
		source_file = null
		if not bool(catalog.validate_local_source(set_code, card_index, source_bytes).get("ok", false)):
			return _error()
		var source_document: Variant = JSON.parse_string(source_bytes.get_string_from_utf8())
		if not source_document is Dictionary:
			return _error()
		var card: Variant = CardDatabase.get_card(set_code, card_index)
		if card == null or str(card.get("set_code")) != set_code or str(card.get("card_index")) != card_index:
			return _error()
		var source_card: CardData = CardData.from_dict(source_document)
		if source_card == null or not card.has_method("to_dict") or card.to_dict() != source_card.to_dict():
			return _error()
		var card_type := str(card.get("card_type"))
		var stage := str(card.get("stage"))
		if count > 4 and card_type != "Basic Energy":
			return _error()
		if card_type == "Pokemon" and stage == "Basic":
			basic_pokemon += count
		mapped.append({
			"official_card_id": official_card_id,
			"count": count,
			"set_code": set_code,
			"card_index": card_index,
			"source_canonical_json_v1_sha256": value.get("source_canonical_json_v1_sha256"),
			"card_type": card_type,
			"stage": stage,
		})
		total += count
	if total != 60 or basic_pokemon < 1:
		return _error()
	return {"ok": true, "error_code": "", "local_deck": mapped.duplicate(true)}


static func _build_windows_local(csv_value: Variant, manifest: Dictionary) -> Dictionary:
	if manifest.get("document_type") != "deck_manifest_windows_local_v1" or manifest.get("schema_version") != 1 or manifest.get("card_id_domain") != WINDOWS_LOCAL_DECK_DOMAIN or manifest.get("platform_scope") != ["windows"] or manifest.get("cabt_exportable") != false:
		return _error()
	var rows_result := _parse_windows_local_csv(csv_value)
	if not bool(rows_result.get("ok", false)):
		return _error()
	var cards: Variant = manifest.get("cards")
	var rows: Array = rows_result.get("rows", [])
	if not cards is Array or cards.size() != rows.size() or cards.size() != int(manifest.get("unique_card_count", 0)):
		return _error()
	var mapped: Array[Dictionary] = []
	var total := 0
	var basic_pokemon := 0
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var entry: Variant = cards[index]
		if not entry is Dictionary:
			return _error()
		var uid := str(row.get("local_card_uid", ""))
		var count := int(row.get("count", 0))
		if uid != entry.get("local_card_uid") or count != int(entry.get("count", 0)):
			return _error()
		var set_code := str(entry.get("set_code", ""))
		var card_index := str(entry.get("card_index", ""))
		if uid != "%s_%s" % [set_code, card_index]:
			return _error()
		var card_path := "res://data/bundled_user/cards/%s.json" % uid
		var card_file := FileAccess.open(card_path, FileAccess.READ)
		if card_file == null:
			return _error()
		var card_bytes := card_file.get_buffer(card_file.get_length())
		card_file = null
		if _sha(card_bytes) != entry.get("source_raw_sha256") or _canonical_sha(card_bytes) != entry.get("source_canonical_sha256"):
			return _error()
		var source_document: Variant = JSON.parse_string(card_bytes.get_string_from_utf8())
		if not source_document is Dictionary:
			return _error()
		var card: Variant = CardDatabase.get_card(set_code, card_index)
		var source_card: CardData = CardData.from_dict(source_document)
		if card == null or source_card == null or not card.has_method("to_dict") or card.to_dict() != source_card.to_dict():
			return _error()
		var card_type := str(card.get("card_type"))
		var stage := str(card.get("stage"))
		if card_type != entry.get("card_type") or stage != entry.get("stage") or card.get("effect_id") != entry.get("effect_id") or (count > 4 and card_type != "Basic Energy"):
			return _error()
		if card_type == "Pokemon" and stage == "Basic":
			basic_pokemon += count
		mapped.append({
			"local_card_uid": uid,
			"count": count,
			"set_code": set_code,
			"card_index": card_index,
			"source_raw_sha256": entry.get("source_raw_sha256"),
			"source_canonical_json_v1_sha256": entry.get("source_canonical_sha256"),
			"card_type": card_type,
			"stage": stage,
			"effect_id": entry.get("effect_id"),
		})
		total += count
	if total != 60 or int(manifest.get("card_count", 0)) != 60 or basic_pokemon < 1:
		return _error()
	return {"ok": true, "error_code": "", "local_deck": mapped.duplicate(true)}


static func _parse_csv(value: Variant) -> Dictionary:
	if not value is PackedByteArray:
		return _error()
	var bytes: PackedByteArray = value
	var text := bytes.get_string_from_ascii()
	if text.to_ascii_buffer() != bytes or not text.ends_with("\n") or text.contains("\r"):
		return _error()
	var lines := text.trim_suffix("\n").split("\n", false)
	if lines.size() < 2 or lines[0] != "card_id,count":
		return _error()
	var rows: Array[Dictionary] = []
	var previous := -1
	for index in range(1, lines.size()):
		var columns := str(lines[index]).split(",", true)
		if columns.size() != 2 or not _digits(str(columns[0])) or not _digits(str(columns[1])):
			return _error()
		if (str(columns[0]).length() > 1 and str(columns[0]).begins_with("0")) or (str(columns[1]).length() > 1 and str(columns[1]).begins_with("0")):
			return _error()
		var card_id := int(columns[0])
		var count := int(columns[1])
		if card_id < 0 or card_id > MAX_SAFE_INTEGER or card_id <= previous or count < 1 or count > 60:
			return _error()
		previous = card_id
		rows.append({"official_card_id": card_id, "count": count})
	return {"ok": true, "error_code": "", "rows": rows}


static func _parse_windows_local_csv(value: Variant) -> Dictionary:
	if not value is PackedByteArray:
		return _error()
	var bytes: PackedByteArray = value
	var text := bytes.get_string_from_ascii()
	if text.to_ascii_buffer() != bytes or not text.ends_with("\n") or text.contains("\r"):
		return _error()
	var lines := text.trim_suffix("\n").split("\n", false)
	if lines.size() < 2 or lines[0] != "local_card_uid,count":
		return _error()
	var rows: Array[Dictionary] = []
	var previous := ""
	for index in range(1, lines.size()):
		var columns := str(lines[index]).split(",", true)
		if columns.size() != 2 or not _valid_local_uid(str(columns[0])) or not _digits(str(columns[1])):
			return _error()
		if str(columns[1]).length() > 1 and str(columns[1]).begins_with("0"):
			return _error()
		var uid := str(columns[0])
		var count := int(columns[1])
		if (not previous.is_empty() and uid <= previous) or count < 1 or count > 60:
			return _error()
		rows.append({"local_card_uid": uid, "count": count})
		previous = uid
	return {"ok": true, "error_code": "", "rows": rows}


static func _digits(value: String) -> bool:
	if value.is_empty():
		return false
	for character in value:
		var code := character.unicode_at(0)
		if code < 48 or code > 57:
			return false
	return true


static func _valid_local_uid(value: String) -> bool:
	if value.count("_") != 1 or value.length() < 3 or value.length() > 64:
		return false
	var parts := value.split("_", true)
	if parts.size() != 2:
		return false
	for index in range(parts.size()):
		var part := str(parts[index])
		if part.is_empty() or part.length() > 32:
			return false
		for character in part:
			var code := character.unicode_at(0)
			if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (index == 0 and character == ".")):
				return false
	return true


static func _canonical_sha(value: PackedByteArray) -> String:
	var parsed: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(value)
	return _sha(parsed.get("bytes", PackedByteArray())) if bool(parsed.get("ok", false)) else ""


static func _sha(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value)
	return context.finish().hex_encode().to_upper()


static func _error() -> Dictionary:
	return {"ok": false, "error_code": "package_deck_unmapped", "local_deck": []}
