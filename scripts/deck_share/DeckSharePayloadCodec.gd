class_name DeckSharePayloadCodec
extends RefCounted

const MAGIC := "PTCGTRAIN_DECK_SHARE"
const SCHEMA_VERSION := 1
const TEXT_PREFIX := "PTCGD1."
const DEFAULT_AUTHOR := "匿名玩家"
const MAX_ENCODED_TEXT_CHARS := 4096
const MAX_DECOMPRESSED_BYTES := 16384
const MAX_CARD_ROWS_BEFORE_MERGE := 120
const MAX_DECK_NAME_CHARS := 40
const MAX_AUTHOR_CHARS := 20
const MAX_NOTE_CHARS := 80
const BASE45_ALPHABET := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"
const COMPRESSION_MODE := FileAccess.COMPRESSION_DEFLATE


static func build_payload(deck: DeckData, author: String, note: String, app_version: String, card_db_version: String) -> Dictionary:
	var errors := PackedStringArray()
	if deck == null:
		errors.append("missing deck")
		return _result(false, {}, "", errors)

	var normalized := _normalize_cards(deck.cards)
	for err: String in normalized.get("errors", PackedStringArray()):
		errors.append(err)
	var cards: Array = normalized.get("cards", [])
	var total := int(normalized.get("total", 0))
	if total != 60:
		errors.append("deck total must be 60, got %d" % total)

	var deck_name := _trim_visible(str(deck.deck_name).strip_edges(), MAX_DECK_NAME_CHARS)
	if deck_name == "":
		errors.append("deck name is empty")

	var author_name := _trim_visible(author.strip_edges(), MAX_AUTHOR_CHARS)
	if author_name == "":
		author_name = DEFAULT_AUTHOR
	var short_note := _trim_visible(note.strip_edges(), MAX_NOTE_CHARS)

	var source := {
		"type": "local",
		"source_provider": str(deck.source_provider).strip_edges(),
		"source_id": str(deck.source_id).strip_edges(),
	}
	var payload := {
		"magic": MAGIC,
		"schema": SCHEMA_VERSION,
		"game_version": app_version.strip_edges(),
		"card_db_version": card_db_version.strip_edges(),
		"created_at": int(Time.get_unix_time_from_system()),
		"deck": {
			"name": deck_name,
			"author": author_name,
			"note": short_note,
			"source": source,
			"cards": cards,
		},
	}
	if not errors.is_empty():
		return _result(false, payload, "", errors)
	return _result(true, payload, "", validate_payload(payload))


static func encode_payload(payload: Dictionary) -> Dictionary:
	var errors := validate_payload(payload)
	if not errors.is_empty():
		return _result(false, payload, "", errors)

	var envelope := payload.duplicate(true)
	envelope.erase("checksum")
	envelope["checksum"] = _checksum_for_payload(envelope)

	var canonical := _canonical_json(envelope)
	var raw := canonical.to_utf8_buffer()
	if raw.size() > MAX_DECOMPRESSED_BYTES:
		errors.append("payload json is too large")
		return _result(false, envelope, "", errors)

	var compressed := raw.compress(COMPRESSION_MODE)
	if compressed.is_empty():
		errors.append("payload compression failed")
		return _result(false, envelope, "", errors)

	var encoded_payload := _base45_encode(compressed)
	var without_crc := "%s%s" % [TEXT_PREFIX, encoded_payload]
	var crc := _crc32_hex(without_crc.to_utf8_buffer())
	var text := "%s.%s" % [without_crc, crc]
	if text.length() > MAX_ENCODED_TEXT_CHARS:
		errors.append("encoded payload is too large")
		return _result(false, envelope, text, errors)
	return _result(true, envelope, text, PackedStringArray())


static func decode_text(text: String) -> Dictionary:
	var errors := PackedStringArray()
	var raw_text := text.strip_edges()
	if raw_text.length() > MAX_ENCODED_TEXT_CHARS:
		errors.append("encoded payload is too large")
		return _result(false, {}, "", errors)
	if not raw_text.begins_with(TEXT_PREFIX):
		errors.append("invalid payload prefix")
		return _result(false, {}, "", errors)

	var body := raw_text.substr(TEXT_PREFIX.length())
	var separator := body.rfind(".")
	if separator <= 0 or separator >= body.length() - 1:
		errors.append("missing payload crc")
		return _result(false, {}, "", errors)
	var encoded_payload := body.substr(0, separator)
	var crc := body.substr(separator + 1).to_upper()
	if crc.length() != 8:
		errors.append("invalid payload crc")
		return _result(false, {}, "", errors)
	var without_crc := "%s%s" % [TEXT_PREFIX, encoded_payload]
	if _crc32_hex(without_crc.to_utf8_buffer()) != crc:
		errors.append("payload crc mismatch")
		return _result(false, {}, "", errors)

	var compressed := _base45_decode(encoded_payload)
	if compressed.is_empty():
		errors.append("payload base45 decode failed")
		return _result(false, {}, "", errors)
	var decompressed := compressed.decompress_dynamic(MAX_DECOMPRESSED_BYTES, COMPRESSION_MODE)
	if decompressed.is_empty():
		errors.append("payload decompression failed")
		return _result(false, {}, "", errors)
	if decompressed.size() > MAX_DECOMPRESSED_BYTES:
		errors.append("payload json is too large")
		return _result(false, {}, "", errors)

	var json := JSON.new()
	if json.parse(decompressed.get_string_from_utf8()) != OK:
		errors.append("payload json parse failed")
		return _result(false, {}, "", errors)
	if json.data is not Dictionary:
		errors.append("payload json must be an object")
		return _result(false, {}, "", errors)

	var payload: Dictionary = json.data
	var embedded_checksum := str(payload.get("checksum", "")).strip_edges()
	if embedded_checksum == "":
		errors.append("payload checksum is missing")
		return _result(false, payload, "", errors)
	var checksum_payload := payload.duplicate(true)
	checksum_payload.erase("checksum")
	if _checksum_for_payload(checksum_payload) != embedded_checksum:
		errors.append("payload checksum mismatch")
		return _result(false, payload, "", errors)

	errors = validate_payload(payload)
	return _result(errors.is_empty(), payload, raw_text, errors)


static func validate_payload(payload: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if str(payload.get("magic", "")) != MAGIC:
		errors.append("invalid payload magic")
	if int(payload.get("schema", -1)) != SCHEMA_VERSION:
		errors.append("unsupported payload schema")
	var deck_raw: Variant = payload.get("deck")
	if deck_raw is not Dictionary:
		errors.append("payload deck must be an object")
		return errors
	var deck: Dictionary = deck_raw
	var name := str(deck.get("name", "")).strip_edges()
	var author := str(deck.get("author", "")).strip_edges()
	var note := str(deck.get("note", "")).strip_edges()
	if name == "":
		errors.append("deck name is empty")
	if name.length() > MAX_DECK_NAME_CHARS:
		errors.append("deck name is too long")
	if author == "":
		errors.append("deck author is empty")
	if author.length() > MAX_AUTHOR_CHARS:
		errors.append("deck author is too long")
	if note.length() > MAX_NOTE_CHARS:
		errors.append("deck note is too long")

	var cards_raw: Variant = deck.get("cards")
	if cards_raw is not Array:
		errors.append("deck cards must be an array")
		return errors
	var cards: Array = cards_raw
	if cards.size() > MAX_CARD_ROWS_BEFORE_MERGE:
		errors.append("deck cards has too many rows")
	var total := 0
	for row_raw: Variant in cards:
		if row_raw is not Array:
			errors.append("card row must be an array")
			continue
		var row: Array = row_raw
		if row.size() < 3:
			errors.append("card row is incomplete")
			continue
		var set_code := str(row[0]).strip_edges()
		var card_index := str(row[1]).strip_edges()
		var count := int(row[2])
		if set_code == "" or card_index == "":
			errors.append("card identity is missing")
		if count <= 0:
			errors.append("card count must be positive")
		total += count
		if row.size() >= 4 and row[3] is not Dictionary:
			errors.append("card source hint must be an object")
	if total != 60:
		errors.append("deck total must be 60, got %d" % total)
	return errors


static func encoded_payload_length_for_deck(deck: DeckData, author: String = "A", note: String = "", app_version: String = "", card_db_version: String = "") -> int:
	var built := build_payload(deck, author, note, app_version, card_db_version)
	if not bool(built.get("ok", false)):
		return -1
	var encoded := encode_payload(built.get("payload", {}))
	return str(encoded.get("text", "")).length() if bool(encoded.get("ok", false)) else -1


static func _normalize_cards(entries: Array[Dictionary]) -> Dictionary:
	var errors := PackedStringArray()
	if entries.size() > MAX_CARD_ROWS_BEFORE_MERGE:
		errors.append("deck has too many card rows before merge")
	var by_key: Dictionary = {}
	var hints: Dictionary = {}
	var total := 0
	for entry: Dictionary in entries:
		var set_code := str(entry.get("set_code", "")).strip_edges()
		var card_index := str(entry.get("card_index", "")).strip_edges()
		var count := int(entry.get("count", 0))
		if set_code == "" or card_index == "":
			errors.append("card identity is missing")
			continue
		if count <= 0:
			errors.append("card count must be positive")
			continue
		var key := "%s\t%s" % [set_code, card_index]
		by_key[key] = int(by_key.get(key, 0)) + count
		total += count
		var hint := _source_hint_for_entry(entry)
		if not hint.is_empty() and not hints.has(key):
			hints[key] = hint

	var keys := PackedStringArray()
	for key: Variant in by_key.keys():
		keys.append(str(key))
	keys.sort()

	var rows: Array = []
	for key: String in keys:
		var parts := key.split("\t", false, 1)
		var row: Array = [parts[0], parts[1], int(by_key[key])]
		if hints.has(key):
			row.append(hints[key])
		rows.append(row)
	return {
		"cards": rows,
		"errors": errors,
		"total": total,
	}


static func _source_hint_for_entry(entry: Dictionary) -> Dictionary:
	var provider := str(entry.get("source_provider", "")).strip_edges()
	var source_set := str(entry.get("source_set_code", "")).strip_edges()
	var source_number := str(entry.get("source_card_index", "")).strip_edges()
	var source_language := str(entry.get("source_language", "")).strip_edges()
	if provider == "" and source_set == "" and source_number == "" and source_language == "":
		return {}
	var hint := {}
	if provider != "":
		hint["p"] = provider
	if source_set != "":
		hint["s"] = source_set
	if source_number != "":
		hint["n"] = source_number
	if source_language != "":
		hint["l"] = source_language
	return hint


static func _checksum_for_payload(payload_without_checksum: Dictionary) -> String:
	return _crc32_hex(_canonical_json(payload_without_checksum).to_utf8_buffer())


static func _canonical_json(value: Variant) -> String:
	if value is Dictionary:
		var keys := PackedStringArray()
		for key: Variant in (value as Dictionary).keys():
			keys.append(str(key))
		keys.sort()
		var parts: Array[String] = []
		for key: String in keys:
			parts.append("%s:%s" % [JSON.stringify(key), _canonical_json((value as Dictionary).get(key))])
		return "{%s}" % ",".join(parts)
	if value is Array:
		var parts: Array[String] = []
		for item: Variant in (value as Array):
			parts.append(_canonical_json(item))
		return "[%s]" % ",".join(parts)
	if typeof(value) == TYPE_INT:
		return str(int(value))
	if typeof(value) == TYPE_FLOAT:
		var float_value := float(value)
		var int_value := int(float_value)
		if float_value == float(int_value):
			return str(int_value)
	return JSON.stringify(value)


static func _base45_encode(bytes: PackedByteArray) -> String:
	var output := PackedStringArray()
	var i := 0
	while i < bytes.size():
		if i + 1 < bytes.size():
			var value := int(bytes[i]) * 256 + int(bytes[i + 1])
			output.append(BASE45_ALPHABET.substr(value % 45, 1))
			output.append(BASE45_ALPHABET.substr(int(value / 45) % 45, 1))
			output.append(BASE45_ALPHABET.substr(int(value / 2025), 1))
			i += 2
		else:
			var value := int(bytes[i])
			output.append(BASE45_ALPHABET.substr(value % 45, 1))
			output.append(BASE45_ALPHABET.substr(int(value / 45), 1))
			i += 1
	return "".join(output)


static func _base45_decode(text: String) -> PackedByteArray:
	var bytes := PackedByteArray()
	var i := 0
	while i < text.length():
		var remaining := text.length() - i
		if remaining == 1:
			return PackedByteArray()
		var c0 := BASE45_ALPHABET.find(text.substr(i, 1))
		var c1 := BASE45_ALPHABET.find(text.substr(i + 1, 1))
		if c0 < 0 or c1 < 0:
			return PackedByteArray()
		if remaining >= 3:
			var c2 := BASE45_ALPHABET.find(text.substr(i + 2, 1))
			if c2 < 0:
				return PackedByteArray()
			var value := c0 + c1 * 45 + c2 * 2025
			if value > 65535:
				return PackedByteArray()
			bytes.append(int(value / 256))
			bytes.append(value % 256)
			i += 3
		else:
			var value := c0 + c1 * 45
			if value > 255:
				return PackedByteArray()
			bytes.append(value)
			i += 2
	return bytes


static func _crc32_hex(bytes: PackedByteArray) -> String:
	var crc := 0xFFFFFFFF
	for byte: int in bytes:
		crc = crc ^ byte
		for _i: int in 8:
			if (crc & 1) != 0:
				crc = (crc >> 1) ^ 0xEDB88320
			else:
				crc = crc >> 1
			crc = crc & 0xFFFFFFFF
	crc = (~crc) & 0xFFFFFFFF
	return "%08X" % crc


static func _trim_visible(text: String, max_length: int) -> String:
	var trimmed := text.strip_edges()
	if trimmed.length() <= max_length:
		return trimmed
	return trimmed.substr(0, max_length)


static func _result(ok: bool, payload: Dictionary, text: String, errors: PackedStringArray) -> Dictionary:
	return {
		"ok": ok and errors.is_empty(),
		"payload": payload,
		"text": text,
		"errors": errors,
	}
