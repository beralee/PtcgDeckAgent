class_name TestDeckSharePayloadCodec
extends TestBase

const DeckSharePayloadCodecScript := preload("res://scripts/deck_share/DeckSharePayloadCodec.gd")


func _make_entry(set_code: String, card_index: String, count: int, card_type: String = "Item", name: String = "") -> Dictionary:
	return {
		"set_code": set_code,
		"card_index": card_index,
		"count": count,
		"card_type": card_type,
		"name": name if name != "" else "%s_%s" % [set_code, card_index],
	}


func _make_valid_deck() -> DeckData:
	var deck := DeckData.new()
	deck.id = 990001
	deck.deck_name = "Share Payload Test"
	deck.source_provider = "local"
	deck.source_id = "990001"
	deck.total_cards = 60
	for i: int in 15:
		deck.cards.append(_make_entry("UTEST", "%03d" % (i + 1), 4, "Pokemon", "Probe %02d" % i))
	return deck


func _first_error(result: Dictionary) -> String:
	var errors: PackedStringArray = result.get("errors", PackedStringArray())
	return errors[0] if not errors.is_empty() else ""


func test_deck_share_payload_roundtrip_preserves_deck_identity() -> String:
	var deck := _make_valid_deck()
	var built := DeckSharePayloadCodecScript.build_payload(deck, "Author", "Short note", "0.5.0", "test-db")
	var encoded := DeckSharePayloadCodecScript.encode_payload(built.get("payload", {}))
	var decoded := DeckSharePayloadCodecScript.decode_text(str(encoded.get("text", "")))
	var payload: Dictionary = decoded.get("payload", {})
	var deck_payload: Dictionary = payload.get("deck", {})
	var cards: Array = deck_payload.get("cards", [])
	return run_checks([
		assert_true(bool(built.get("ok", false)), "valid deck payload should build: %s" % _first_error(built)),
		assert_true(bool(encoded.get("ok", false)), "valid deck payload should encode: %s" % _first_error(encoded)),
		assert_true(bool(decoded.get("ok", false)), "encoded deck payload should decode: %s" % _first_error(decoded)),
		assert_eq(str(payload.get("magic", "")), DeckSharePayloadCodecScript.MAGIC, "payload magic"),
		assert_eq(int(payload.get("schema", 0)), DeckSharePayloadCodecScript.SCHEMA_VERSION, "payload schema"),
		assert_eq(str(deck_payload.get("name", "")), deck.deck_name, "deck name"),
		assert_eq(str(deck_payload.get("author", "")), "Author", "author"),
		assert_eq(str(deck_payload.get("note", "")), "Short note", "note"),
		assert_eq(cards.size(), 15, "card rows should remain unique"),
		assert_eq(int(cards[0][2]), 4, "copy count"),
	])


func test_deck_share_payload_sorts_and_merges_duplicate_rows() -> String:
	var deck := DeckData.new()
	deck.id = 990002
	deck.deck_name = "Merge Test"
	deck.total_cards = 60
	deck.cards.append(_make_entry("UTEST", "010", 2))
	deck.cards.append(_make_entry("UTEST", "001", 4))
	deck.cards.append(_make_entry("UTEST", "010", 2))
	for i: int in 13:
		deck.cards.append(_make_entry("UTEST", "%03d" % (20 + i), 4))
	var built := DeckSharePayloadCodecScript.build_payload(deck, "A", "", "0.5.0", "")
	var payload: Dictionary = built.get("payload", {})
	var cards: Array = (payload.get("deck", {}) as Dictionary).get("cards", [])
	return run_checks([
		assert_true(bool(built.get("ok", false)), "merge test payload should build: %s" % _first_error(built)),
		assert_eq(str(cards[0][0]), "UTEST", "first set code"),
		assert_eq(str(cards[0][1]), "001", "rows should sort by card index"),
		assert_eq(str(cards[1][1]), "010", "merged row should keep sorted position"),
		assert_eq(int(cards[1][2]), 4, "duplicate rows should merge copy counts"),
	])


func test_deck_share_payload_rejects_non_60_total() -> String:
	var deck := _make_valid_deck()
	deck.cards.pop_back()
	deck.total_cards = 56
	var built := DeckSharePayloadCodecScript.build_payload(deck, "A", "", "0.5.0", "")
	return run_checks([
		assert_false(bool(built.get("ok", true)), "non-60 deck should not build"),
		assert_str_contains(_first_error(built), "60", "error should mention expected deck total"),
	])


func test_deck_share_payload_rejects_corrupted_crc() -> String:
	var deck := _make_valid_deck()
	var built := DeckSharePayloadCodecScript.build_payload(deck, "A", "", "0.5.0", "")
	var encoded := DeckSharePayloadCodecScript.encode_payload(built.get("payload", {}))
	var text := str(encoded.get("text", ""))
	var last_char := text.substr(text.length() - 1, 1)
	var corrupted := text.substr(0, text.length() - 1) + ("0" if last_char != "0" else "1")
	var decoded := DeckSharePayloadCodecScript.decode_text(corrupted)
	return run_checks([
		assert_false(bool(decoded.get("ok", true)), "corrupted payload should not decode"),
		assert_str_contains(_first_error(decoded), "crc", "corruption should fail at crc"),
	])


func test_deck_share_payload_rejects_wrong_prefix() -> String:
	var decoded := DeckSharePayloadCodecScript.decode_text("NOTPTCGD1.12345678")
	return run_checks([
		assert_false(bool(decoded.get("ok", true)), "wrong prefix should fail"),
		assert_str_contains(_first_error(decoded), "prefix", "wrong prefix error"),
	])


func test_deck_share_payload_rejects_unsupported_schema() -> String:
	var deck := _make_valid_deck()
	var built := DeckSharePayloadCodecScript.build_payload(deck, "A", "", "0.5.0", "")
	var payload: Dictionary = built.get("payload", {})
	payload["schema"] = 999
	var errors := DeckSharePayloadCodecScript.validate_payload(payload)
	return run_checks([
		assert_gt(errors.size(), 0, "unsupported schema should produce validation errors"),
		assert_str_contains(errors[0], "schema", "schema error"),
	])


func test_deck_share_payload_preserves_basic_energy_quantities() -> String:
	var deck := DeckData.new()
	deck.id = 990003
	deck.deck_name = "Energy Test"
	deck.total_cards = 60
	deck.cards.append(_make_entry("SVE", "001", 30, "Basic Energy", "Fire Energy"))
	deck.cards.append(_make_entry("SVE", "002", 30, "Basic Energy", "Water Energy"))
	var built := DeckSharePayloadCodecScript.build_payload(deck, "", "", "0.5.0", "")
	var encoded := DeckSharePayloadCodecScript.encode_payload(built.get("payload", {}))
	var decoded := DeckSharePayloadCodecScript.decode_text(str(encoded.get("text", "")))
	var cards: Array = ((decoded.get("payload", {}) as Dictionary).get("deck", {}) as Dictionary).get("cards", [])
	return run_checks([
		assert_true(bool(decoded.get("ok", false)), "basic energy payload should decode: %s" % _first_error(decoded)),
		assert_eq(cards.size(), 2, "basic energy rows"),
		assert_eq(int(cards[0][2]) + int(cards[1][2]), 60, "basic energy counts should survive"),
	])


func test_deck_share_payload_preserves_limitless_source_hint() -> String:
	var deck := _make_valid_deck()
	var entry: Dictionary = deck.cards[0]
	entry["source_provider"] = "limitless"
	entry["source_set_code"] = "JTG"
	entry["source_card_index"] = "182"
	entry["source_language"] = "en"
	deck.cards[0] = entry
	var built := DeckSharePayloadCodecScript.build_payload(deck, "A", "", "0.5.0", "")
	var encoded := DeckSharePayloadCodecScript.encode_payload(built.get("payload", {}))
	var decoded := DeckSharePayloadCodecScript.decode_text(str(encoded.get("text", "")))
	var cards: Array = ((decoded.get("payload", {}) as Dictionary).get("deck", {}) as Dictionary).get("cards", [])
	var hint: Dictionary = cards[0][3] if cards.size() > 0 and (cards[0] as Array).size() >= 4 else {}
	return run_checks([
		assert_true(bool(decoded.get("ok", false)), "limitless hint payload should decode: %s" % _first_error(decoded)),
		assert_eq(str(hint.get("p", "")), "limitless", "source provider hint"),
		assert_eq(str(hint.get("s", "")), "JTG", "source set hint"),
		assert_eq(str(hint.get("n", "")), "182", "source number hint"),
		assert_eq(str(hint.get("l", "")), "en", "source language hint"),
	])


func test_bundled_decks_fit_encoded_payload_budget() -> String:
	var dir := DirAccess.open("res://data/bundled_user/decks")
	if dir == null:
		return "Bundled deck directory should be readable"
	var checks: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var text := FileAccess.get_file_as_string("res://data/bundled_user/decks/%s" % file_name)
			var json := JSON.new()
			var parse_err := json.parse(text)
			if parse_err != OK or json.data is not Dictionary:
				checks.append("%s should parse as a deck JSON" % file_name)
			else:
				var deck := DeckData.from_dict(json.data)
				var built := DeckSharePayloadCodecScript.build_payload(deck, "A", "", "0.5.0", "bundled")
				var encoded := DeckSharePayloadCodecScript.encode_payload(built.get("payload", {}))
				checks.append(assert_true(bool(built.get("ok", false)), "%s should build a share payload: %s" % [file_name, _first_error(built)]))
				checks.append(assert_true(bool(encoded.get("ok", false)), "%s should encode under budget: %s" % [file_name, _first_error(encoded)]))
				checks.append(assert_true(str(encoded.get("text", "")).length() <= DeckSharePayloadCodecScript.MAX_ENCODED_TEXT_CHARS, "%s encoded payload should fit the maximum text size" % file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	return run_checks(checks)
