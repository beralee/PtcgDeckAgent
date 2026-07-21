class_name TestV18TyphlosionFixedOpeningRound5
extends TestBase


const PROFILE_CATALOG = preload("res://scripts/ai/DeckStrategyV18ProfileCatalog.gd")
const STRATEGY_REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const FIXED_ORDER_REGISTRY_SCRIPT = preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")

const DECK_ID := 800018880
const DECK_PATH := "res://data/bundled_user/decks/800018880.json"
const FIXED_ORDER_PATH := "res://data/bundled_user/ai_fixed_deck_orders/800018880.json"
const EXPECTED_OPENING: Array[String] = [
	"CSV10C_028",
	"CSV1C_123",
	"CSV7C_177",
	"CSV1C_112",
	"CSVE1C_FIR",
	"CSVE1C_FIR",
	"CSV9C_023",
]
const EXPECTED_PRIZES: Array[String] = [
	"CSV7C_201",
	"CSV1C_109",
	"CSVH1aC_023",
	"CSV1C_121",
	"CSV3C_123",
	"CSV5C_119",
]
const EXPECTED_BRIDGE: Array[String] = [
	"151C_016",
	"CSV10C_030",
	"CSVE1C_FIR",
	"CSV7C_177",
	"CSV10C_030",
	"CSVE1C_FIR",
]


func test_round5_changes_only_the_strong_bridge_prefix() -> String:
	var profile: Dictionary = PROFILE_CATALOG.get_profile_for_deck(DECK_ID)
	var strong_order: Dictionary = profile.get("strong_order", {})
	var order_uids := _order_uids(FIXED_ORDER_REGISTRY_SCRIPT.new().load_fixed_order(DECK_ID))
	var opening := order_uids.slice(0, 7)
	var prizes := order_uids.slice(7, 13)
	var bridge := order_uids.slice(13, 19)
	return run_checks([
		assert_eq(strong_order.get("opening_cards", []), EXPECTED_OPENING, "Round 5 must preserve the exact Round 3 opening hints"),
		assert_eq(strong_order.get("bridge_cards", []), EXPECTED_BRIDGE, "Round 5 should declare the exact Pidgey-first strong bridge"),
		assert_eq(opening, EXPECTED_OPENING, "Cards 1-7 must remain the Round 3 opening"),
		assert_eq(prizes, EXPECTED_PRIZES, "Cards 8-13 must remain the Round 3 controlled prizes"),
		assert_eq(bridge, EXPECTED_BRIDGE, "Cards 14-19 must be the exact Round 5 strong bridge"),
		assert_eq(bridge[0] if not bridge.is_empty() else "", "151C_016", "The first bridge draw must be Pidgey"),
		assert_eq(bridge.count("CSV10C_030"), 2, "The bridge should consume exactly two legal follow-up Typhlosion copies"),
	])


func test_round5_fixed_order_preserves_legal_deck_multiplicities() -> String:
	var deck := _load_deck()
	var fixed_order: Array[Dictionary] = FIXED_ORDER_REGISTRY_SCRIPT.new().load_fixed_order(DECK_ID)
	var order_counts := _uid_counts(_order_uids(fixed_order))
	var deck_counts := _deck_counts(deck)
	var checks: Array[String] = [
		assert_not_null(deck, "Ethan's Typhlosion production deck should parse"),
		assert_eq(_count_total(deck_counts), 60, "Ethan's Typhlosion production deck should remain a legal 60-card deck"),
	]
	for uid: String in order_counts:
		checks.append(assert_true(deck_counts.has(uid), "Fixed-order card %s should exist in the production deck" % uid))
		checks.append(assert_true(
			int(order_counts[uid]) <= int(deck_counts.get(uid, 0)),
			"Fixed order should not overuse %s" % uid
		))
	return run_checks(checks)


func test_production_registries_load_the_round5_fixed_order() -> String:
	var deck := _load_deck()
	var strategy := STRATEGY_REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck) if deck != null else null
	var fixed_registry: RefCounted = FIXED_ORDER_REGISTRY_SCRIPT.new()
	var loaded_order: Array[Dictionary] = fixed_registry.load_fixed_order(DECK_ID)
	return run_checks([
		assert_not_null(strategy, "Deck 800018880 should resolve through the production strategy registry"),
		assert_eq(
			str(strategy.call("get_strategy_id")) if strategy != null else "",
			"v18_800018880_ethans_typhlosion",
			"The production wrapper should retain the Ethan's Typhlosion profile identity"
		),
		assert_eq(fixed_registry.get_fixed_order_path(DECK_ID), FIXED_ORDER_PATH, "The production fixed-order registry should bind deck 800018880"),
		assert_eq(_order_uids(loaded_order).slice(13, 19), EXPECTED_BRIDGE, "The production fixed-order registry should read the Round 5 bridge"),
	])


func _load_deck() -> DeckData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	return DeckData.from_dict(parsed) if parsed is Dictionary else null


func _order_uids(order: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in order:
		result.append(_entry_uid(entry))
	return result


func _deck_counts(deck: DeckData) -> Dictionary:
	var counts: Dictionary = {}
	if deck == null:
		return counts
	for entry: Dictionary in deck.cards:
		counts[_entry_uid(entry)] = int(entry.get("count", 0))
	return counts


func _uid_counts(uids: Array[String]) -> Dictionary:
	var counts: Dictionary = {}
	for uid: String in uids:
		counts[uid] = int(counts.get(uid, 0)) + 1
	return counts


func _count_total(counts: Dictionary) -> int:
	var total := 0
	for count: Variant in counts.values():
		total += int(count)
	return total


func _entry_uid(entry: Dictionary) -> String:
	return "%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))]
