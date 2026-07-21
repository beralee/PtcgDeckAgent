class_name TestDeckShareImporter
extends TestBase

const DeckShareImporterScript := preload("res://scripts/deck_share/DeckShareImporter.gd")
const DeckSharePayloadCodecScript := preload("res://scripts/deck_share/DeckSharePayloadCodec.gd")


class FakeCardDatabase:
	extends RefCounted

	var cards: Dictionary = {}
	var occupied_deck_ids: Dictionary = {}

	func add_card(card: CardData) -> void:
		cards["%s_%s" % [card.set_code, card.card_index]] = card

	func get_card(set_code: String, card_index: String) -> CardData:
		return cards.get("%s_%s" % [set_code, card_index], null)

	func get_all_cards() -> Array:
		return cards.values()

	func has_deck(deck_id: int) -> bool:
		return bool(occupied_deck_ids.get(deck_id, false))


func _make_card(set_code: String, card_index: String, card_type: String = "Basic Energy", name: String = "") -> CardData:
	var card := CardData.new()
	card.set_code = set_code
	card.card_index = card_index
	card.card_type = card_type
	card.name = name if name != "" else "%s_%s" % [set_code, card_index]
	card.name_zh = card.name
	return card


func _make_deck(entries: Array[Dictionary]) -> DeckData:
	var deck := DeckData.new()
	deck.id = 990101
	deck.deck_name = "Shared Import Test"
	deck.total_cards = 0
	for entry: Dictionary in entries:
		deck.cards.append(entry)
		deck.total_cards += int(entry.get("count", 0))
	return deck


func _entry(set_code: String, card_index: String, count: int, card_type: String = "Basic Energy") -> Dictionary:
	return {
		"set_code": set_code,
		"card_index": card_index,
		"count": count,
		"card_type": card_type,
		"name": "%s_%s" % [set_code, card_index],
	}


func _payload_for_deck(deck: DeckData) -> Dictionary:
	var built := DeckSharePayloadCodecScript.build_payload(deck, "Tester", "Import note", "0.5.0", "test-db")
	var encoded := DeckSharePayloadCodecScript.encode_payload(built.get("payload", {}))
	return encoded.get("payload", {})


func test_deck_share_importer_builds_deck_from_payload() -> String:
	var db := FakeCardDatabase.new()
	db.add_card(_make_card("UTEST", "001", "Basic Energy", "Energy One"))
	db.add_card(_make_card("UTEST", "002", "Basic Energy", "Energy Two"))
	var deck := _make_deck([
		_entry("UTEST", "001", 30),
		_entry("UTEST", "002", 30),
	])
	var result := DeckShareImporterScript.preview_payload(_payload_for_deck(deck), db)
	var imported: DeckData = result.get("deck", null)
	var metadata: Dictionary = result.get("metadata", {})
	return run_checks([
		assert_true(bool(result.get("ok", false)), "valid payload should import without blocking errors"),
		assert_not_null(imported, "imported deck should exist"),
		assert_eq(imported.total_cards if imported != null else 0, 60, "imported total"),
		assert_eq(str(imported.source_provider if imported != null else ""), DeckShareImporterScript.SOURCE_PROVIDER, "source provider"),
		assert_eq(str(imported.strategy if imported != null else ""), "Import note", "deck note should become strategy"),
		assert_eq(str(metadata.get("author", "")), "Tester", "preview metadata should keep author"),
		assert_eq((imported.cards if imported != null else []).size(), 2, "imported card rows"),
	])


func test_deck_share_importer_allocates_next_free_local_id() -> String:
	var db := FakeCardDatabase.new()
	db.add_card(_make_card("UTEST", "001"))
	var deck := _make_deck([_entry("UTEST", "001", 60)])
	var payload := _payload_for_deck(deck)
	var checksum := str(payload.get("checksum", ""))
	var first_id: int = DeckShareImporterScript.LOCAL_ID_BASE + int(abs(checksum.hash()) % DeckShareImporterScript.LOCAL_ID_RANGE)
	db.occupied_deck_ids[first_id] = true
	var result := DeckShareImporterScript.preview_payload(payload, db)
	var imported: DeckData = result.get("deck", null)
	return run_checks([
		assert_true(bool(result.get("ok", false)), "payload should still import when first generated id is occupied"),
		assert_true(imported != null and imported.id != first_id, "importer should skip occupied deck id"),
		assert_false(db.has_deck(imported.id if imported != null else first_id), "assigned id should be free"),
	])


func test_deck_share_importer_blocks_missing_card_data() -> String:
	var db := FakeCardDatabase.new()
	var deck := _make_deck([_entry("MISSING", "404", 60)])
	var result := DeckShareImporterScript.preview_payload(_payload_for_deck(deck), db)
	var missing_cards: Array = result.get("missing_cards", [])
	var errors: PackedStringArray = result.get("blocking_errors", PackedStringArray())
	return run_checks([
		assert_false(bool(result.get("ok", true)), "missing card data should block import"),
		assert_eq(missing_cards.size(), 1, "missing card should be reported"),
		assert_str_contains(errors[0] if not errors.is_empty() else "", "missing card", "blocking error should explain missing card"),
	])


func test_deck_share_importer_resolves_card_by_source_hint() -> String:
	var db := FakeCardDatabase.new()
	var hinted_card := _make_card("LOCAL", "999", "Pokemon", "Hinted Pokemon")
	hinted_card.source_provider = "limitless"
	hinted_card.source_set_code = "JTG"
	hinted_card.source_card_index = "182"
	hinted_card.source_language = "en"
	db.add_card(hinted_card)
	var deck := _make_deck([{
		"set_code": "LEN_JTG",
		"card_index": "182",
		"count": 60,
		"card_type": "Pokemon",
		"name": "Source Hinted",
		"source_provider": "limitless",
		"source_set_code": "JTG",
		"source_card_index": "182",
		"source_language": "en",
	}])
	var result := DeckShareImporterScript.preview_payload(_payload_for_deck(deck), db)
	var imported: DeckData = result.get("deck", null)
	var entry: Dictionary = imported.cards[0] if imported != null and imported.cards.size() > 0 else {}
	return run_checks([
		assert_true(bool(result.get("ok", false)), "source hint should resolve locally available generated card"),
		assert_eq(str(entry.get("set_code", "")), "LOCAL", "resolved set code"),
		assert_eq(str(entry.get("card_index", "")), "999", "resolved card index"),
		assert_eq(str(entry.get("resolved_via", "")), "source_hint", "resolved via marker"),
	])


func test_deck_share_importer_unimplemented_cards_warn_without_blocking() -> String:
	var db := FakeCardDatabase.new()
	var card := _make_card("UTEST", "777", "Item", "Unimplemented Item")
	card.description = "Search your deck for a card."
	card.effect_id = "missing_effect_for_share_import_test"
	db.add_card(card)
	var deck := _make_deck([_entry("UTEST", "777", 60, "Item")])
	var result := DeckShareImporterScript.preview_payload(_payload_for_deck(deck), db)
	var warnings: PackedStringArray = result.get("warnings", PackedStringArray())
	var unimplemented: Array = result.get("unimplemented_cards", [])
	return run_checks([
		assert_true(bool(result.get("ok", false)), "unimplemented effects should not block import"),
		assert_gt(warnings.size(), 0, "unimplemented card warning should be present"),
		assert_eq(unimplemented.size(), 1, "unimplemented card should be listed"),
	])
