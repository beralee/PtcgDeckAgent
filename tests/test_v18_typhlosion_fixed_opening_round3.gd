class_name TestV18TyphlosionFixedOpeningRound3
extends TestBase


const PROFILE_CATALOG_PATH := "res://scripts/ai/DeckStrategyV18ProfileCatalog.gd"
const FIXED_ORDER_PATH := "res://data/bundled_user/ai_fixed_deck_orders/800018880.json"
const DECK_PATH := "res://data/bundled_user/decks/800018880.json"
const DECK_ID := 800018880
const EXPECTED_OPENING := [
	"CSV10C_028",
	"CSV1C_123",
	"CSV7C_177",
	"CSV1C_112",
	"CSVE1C_FIR",
	"CSVE1C_FIR",
	"CSV9C_023",
]
const EXPECTED_PRIZES := [
	"CSV7C_201",
	"CSV1C_109",
	"CSVH1aC_023",
	"CSV1C_121",
	"CSV3C_123",
	"CSV5C_119",
]


func test_strong_opening_replaces_pidgey_with_arven_without_breaking_setup_resources() -> String:
	var catalog_script: GDScript = load(PROFILE_CATALOG_PATH)
	var profile: Dictionary = catalog_script.call("get_profile_for_deck", DECK_ID)
	var opening_hints: Array = (profile.get("strong_order", {}) as Dictionary).get("opening_cards", [])
	var fixed_order := _fixed_order_uids()
	var opening := fixed_order.slice(0, 7)
	var prizes := fixed_order.slice(7, 13)
	var deck_counts := _deck_counts()
	var setup_counts := _counts(opening + prizes)
	var accessible_cyndaquil := int(deck_counts.get("CSV10C_028", 0)) - int(setup_counts.get("CSV10C_028", 0))
	var accessible_pidgey := int(deck_counts.get("151C_016", 0)) - int(setup_counts.get("151C_016", 0))
	var accessible_tm_evolution := int(deck_counts.get("CSV5C_119", 0)) - int(_counts(prizes).get("CSV5C_119", 0))
	return run_checks([
		assert_eq(opening_hints, EXPECTED_OPENING, "Ethan Typhlosion should declare the exact generated strong opening"),
		assert_eq(opening, EXPECTED_OPENING, "Strong opening card 2 should be Arven while every other opening slot stays unchanged"),
		assert_eq(prizes, EXPECTED_PRIZES, "Replacing opening Pidgey with Arven must not change the controlled prize block"),
		assert_eq(opening.count("CSVE1C_FIR"), 2, "The strong opening should keep two basic Fire Energy"),
		assert_true("CSV9C_023" in opening, "The strong opening should keep Victini"),
		assert_true("CSV7C_177" in opening, "The strong opening should keep Buddy-Buddy Poffin"),
		assert_true(accessible_cyndaquil > 0, "Buddy-Buddy Poffin should still have an unprized Ethan's Cyndaquil target"),
		assert_true(accessible_pidgey > 0, "Buddy-Buddy Poffin should still have an unprized Pidgey target"),
		assert_true(accessible_tm_evolution > 0, "At least one TM Evolution must remain outside the prize block"),
	])


func _fixed_order_uids() -> Array[String]:
	var payload := _load_json(FIXED_ORDER_PATH)
	var result: Array[String] = []
	for raw_entry: Variant in payload.get("top_to_bottom", []):
		if raw_entry is Dictionary:
			result.append(_uid(raw_entry))
	return result


func _deck_counts() -> Dictionary:
	var payload := _load_json(DECK_PATH)
	var result: Dictionary = {}
	for raw_entry: Variant in payload.get("cards", []):
		if raw_entry is Dictionary:
			result[_uid(raw_entry)] = int(raw_entry.get("count", 0))
	return result


func _counts(uids: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_uid: Variant in uids:
		var uid := str(raw_uid)
		result[uid] = int(result.get(uid, 0)) + 1
	return result


func _uid(entry: Dictionary) -> String:
	return "%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))]


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}
