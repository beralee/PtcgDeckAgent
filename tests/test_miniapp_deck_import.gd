extends TestBase

const Source := preload("res://scripts/network/MiniappDeckSource.gd")
const FIXTURE := "res://tests/fixtures/deck_import/miniapp_raging_bolt.json"
const CODE := "dFJ1jZgeo_xEbSTvjj"

class CapturingImporter:
	extends DeckImporter
	var captured_deck: DeckData
	var captured_keys: Array[Dictionary] = []
	func _fetch_cards_sequentially(deck: DeckData, keys: Array[Dictionary], _index: int, _errors: PackedStringArray) -> void:
		captured_deck = deck
		captured_keys = keys


func test_real_miniapp_fixture_preserves_all_60_cards_and_printings() -> String:
	var decoded := Source.decode_response(FileAccess.get_file_as_bytes(FIXTURE), CODE)
	if not bool(decoded.get("ok")):
		return str(decoded.get("error"))
	var deck: DeckData = decoded.deck
	var entries := {}
	for entry: Dictionary in deck.cards:
		entries[entry.set_code + "_" + entry.card_index] = entry.count
	var restored := DeckData.from_dict(JSON.parse_string(JSON.stringify(deck.to_dict())))
	# JSON numbers are parsed as floats by Godot; compare their integral values.
	for entry: Dictionary in restored.cards:
		entry["count"] = int(entry["count"])
	return run_checks([
		assert_eq(deck.deck_name, "猛雷鼓 厄诡椪", "Real provider variant name"),
		assert_eq(deck.total_cards, 60, "All 60 cards imported"),
		assert_eq(deck.cards.size(), 31, "Every printing retained"),
		assert_eq(entries.get("CSV7C_154"), 3, "Three Raging Bolt ex"),
		assert_eq(entries.get("CSV8C_161"), 1, "Non-ex Raging Bolt stays separate"),
		assert_eq(entries.get("CSVH1aC_008"), 1, "Mixed-case set identity preserved"),
		assert_eq(entries.get("CSVE1C_GRA"), 5, "Alphabetic Energy printing retained"),
		assert_true(deck.validate().is_empty(), "Real deck validates"),
		assert_eq(restored.id, deck.id, "Large local ID survives JSON persistence"),
		assert_eq(restored.source_id, CODE, "Code survives JSON persistence"),
		assert_eq(JSON.stringify(restored.cards), JSON.stringify(deck.cards), "All printing rows survive persistence"),
	])


func test_miniapp_ids_are_case_sensitive_stable_and_collision_safe() -> String:
	var occupied := DeckData.new()
	occupied.id = Source.local_id(CODE)
	occupied.source_provider = "tcg_mik"
	occupied.source_id = "123"
	var first_id := Source.resolve_local_id(CODE, [occupied])
	var saved := DeckData.new()
	saved.id = first_id
	saved.source_provider = "miniapp"
	saved.source_id = CODE
	return run_checks([
		assert_true(Source.local_id(CODE) != Source.local_id(CODE.to_lower()), "Code case changes identity"),
		assert_true(first_id != occupied.id, "Never replace a foreign deck on hash collision"),
		assert_eq(Source.resolve_local_id(CODE, [saved, occupied]), first_id, "Repeated imports reuse the same source ID"),
		assert_true(first_id < 9007199254740991, "ID is exactly representable in browser JSON"),
	])


func test_miniapp_input_rejects_other_hosts_and_malformed_codes() -> String:
	for input: String in ["", "dFJ1jZgeo_xEbSTvj", "dFJ1jZgeo/xEbSTvjj", "https://evil.example/tools/miniapp?code=" + CODE, "https://tcg.mik.moe.evil.example/tools/miniapp?code=" + CODE, Source.PAGE_URL + "?code=" + CODE + "&code=" + CODE]:
		if Source.parse_code(input) != "":
			return "Unexpectedly accepted: " + input
	return assert_eq(Source.parse_code("  dFJ1jZgeo\\_xEbSTvjj  "), CODE, "Markdown escaped underscores are accepted from chat copy")


func test_miniapp_accepts_dotted_printings_and_preserves_user_rename_on_reimport() -> String:
	var response: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	response.data.cards[0].setCode = "CS6.5C"
	var existing := DeckData.new()
	existing.id = Source.local_id(CODE)
	existing.source_id = CODE
	existing.source_provider = "miniapp"
	existing.deck_name = "我的猛雷鼓"
	var decoded := Source.decode_response(JSON.stringify(response).to_utf8_buffer(), CODE, [existing])
	if not decoded.ok:
		return decoded.error
	return run_checks([
		assert_eq(decoded.deck.cards[0].set_code, "CS6.5C", "Actual dotted set codes are valid printing identities"),
		assert_eq(decoded.deck.deck_name, existing.deck_name, "Repeated imports retain the player's chosen name"),
	])


func test_miniapp_missing_card_details_fail_before_completion() -> String:
	var deck := DeckData.new()
	deck.source_provider = "miniapp"
	deck.cards = [{"set_code": "NOT_A_REAL_SET", "card_index": "999", "count": 60}]
	var importer := DeckImporter.new()
	var failures: Array[String] = []
	var completed: Array = []
	importer.import_failed.connect(func(message: String): failures.append(message))
	importer.import_completed.connect(func(value: DeckData, _errors: PackedStringArray): completed.append(value))
	importer._start_image_sync(deck, PackedStringArray())
	var result := run_checks([
		assert_eq(failures.size(), 1, "Missing exact cards yield retryable error"),
		assert_true(completed.is_empty(), "Never report an incomplete deck as imported"),
	])
	importer.free()
	return result


func test_miniapp_response_rejects_bad_shapes_counts_and_source_mismatch() -> String:
	for raw: String in ["null", "[]", "<html>service unavailable</html>", "{\"code\":404,\"msg\":\"not found\"}"]:
		if Source.decode_response(raw.to_utf8_buffer(), CODE).ok:
			return "Bad response accepted: " + raw
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var cases: Array = []
	for count: Variant in [null, true, "3", 0, -1, 0.5, 61]:
		var changed := original.duplicate(true)
		changed.data.cards[0].count = count
		cases.append(changed)
	for field: String in ["setCode", "cardIndex"]:
		var changed := original.duplicate(true)
		changed.data.cards[0][field] = "../outside"
		cases.append(changed)
	var mismatch := original.duplicate(true)
	mismatch.data.deckCode = CODE.to_lower()
	cases.append(mismatch)
	var empty := original.duplicate(true)
	empty.data.cards = []
	cases.append(empty)
	var scalar := original.duplicate(true)
	scalar.data.cards[0] = 9
	cases.append(scalar)
	for changed: Dictionary in cases:
		var decoded := Source.decode_response(JSON.stringify(changed).to_utf8_buffer(), CODE)
		if decoded.ok or str(decoded.error).is_empty():
			return "Malformed card data should fail with actionable error"
	return ""


func test_miniapp_callback_enters_shared_card_detail_pipeline() -> String:
	var importer := CapturingImporter.new()
	importer._on_miniapp_deck_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), FileAccess.get_file_as_bytes(FIXTURE), CODE)
	var result := run_checks([
		assert_not_null(importer.captured_deck, "Callback produces a real deck"),
		assert_eq(importer.captured_keys.size(), 31, "All exact printing keys pass into existing loading pipeline"),
		assert_eq(importer.captured_deck.source_provider if importer.captured_deck != null else "", "miniapp", "Source remains distinct"),
	])
	importer.free()
	return result


func test_miniapp_network_errors_never_produce_a_deck() -> String:
	var importer := CapturingImporter.new()
	var failures: Array[String] = []
	importer.import_failed.connect(func(message: String): failures.append(message))
	importer._on_miniapp_deck_response(HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray(), CODE)
	importer._on_miniapp_deck_response(HTTPRequest.RESULT_SUCCESS, 503, PackedStringArray(), PackedByteArray(), CODE)
	importer._on_miniapp_deck_response(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "[]".to_utf8_buffer(), CODE)
	var result := run_checks([
		assert_eq(failures.size(), 3, "Every failure reaches UI once"),
		assert_true(importer.captured_deck == null, "No partial deck on failure"),
	])
	importer.free()
	return result
