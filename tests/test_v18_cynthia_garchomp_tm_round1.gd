class_name TestV18CynthiaGarchompTMRound1
extends TestBase


const PROFILE_CATALOG = preload("res://scripts/ai/DeckStrategyV18ProfileCatalog.gd")
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800018543
const DECK_PATH := "res://data/bundled_user/decks/800018543.json"
const FIXED_ORDER_PATH := "res://data/bundled_user/ai_fixed_deck_orders/800018543.json"
const DELEGATE_PATH := "res://scripts/ai/DeckStrategyV18MarnieCynthia.gd"

const EXPECTED_OPENING: Array[String] = [
	"CSV9.5C_004", "CSV10C_111", "CSV7C_177", "CSV5C_119",
	"CSVE1C_FIG", "CSVE1C_FIG", "CSV10C_004",
]
const EXPECTED_PRIZES: Array[String] = [
	"CSV3C_123", "CSV1C_123", "CSVH1aC_023",
	"CSV9C_196", "CSV10C_212", "CSVE1C_DAR",
]
const EXPECTED_BRIDGE: Array[String] = [
	"CSV10C_113", "CSV10C_112", "CSVE1C_FIG",
	"CSV10C_005", "CSV10C_200", "CSVE1C_FIG",
]


func test_strong_order_hints_and_fixed_order_keep_the_exact_legal_route() -> String:
	var profile: Dictionary = PROFILE_CATALOG.get_profile_for_deck(DECK_ID)
	var strong_order: Dictionary = profile.get("strong_order", {})
	var deck_payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var order_payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXED_ORDER_PATH))
	var checks: Array[String] = [
		assert_true(deck_payload is Dictionary, "Cynthia's production deck JSON should parse"),
		assert_true(order_payload is Dictionary, "Cynthia's fixed-order JSON should parse"),
		assert_eq(strong_order.get("opening_cards", []), EXPECTED_OPENING, "The catalog must pin the R1 opening seven"),
		assert_eq(strong_order.get("bridge_cards", []), EXPECTED_BRIDGE, "The catalog must pin the R1 bridge six"),
	]
	if not deck_payload is Dictionary or not order_payload is Dictionary:
		return run_checks(checks)

	var deck_counts := _deck_counts(deck_payload)
	var order_uids := _order_uids(order_payload)
	var order_counts := _uid_counts(order_uids)
	var expected_prefix: Array[String] = []
	expected_prefix.append_array(EXPECTED_OPENING)
	expected_prefix.append_array(EXPECTED_PRIZES)
	expected_prefix.append_array(EXPECTED_BRIDGE)
	checks.append(assert_eq(order_uids.size(), 60, "The strong fixed order must contain the complete 60-card deck"))
	checks.append(assert_eq(order_counts, deck_counts, "The strong fixed order must preserve every production deck multiplicity"))
	checks.append(assert_eq(order_uids.slice(0, 19), expected_prefix, "Cards 1-19 must preserve the setup, safe prizes, and bridge route"))
	checks.append(assert_true("CSV9.5C_004" in order_uids.slice(0, 7), "The opening seven must contain a Basic Pokemon"))

	var prize_uids: Array = order_uids.slice(7, 13)
	var distinct_prizes := _uid_counts(prize_uids)
	var prize_energy_count := 0
	for uid_variant: Variant in prize_uids:
		var uid := str(uid_variant)
		checks.append(assert_true(int(deck_counts.get(uid, 0)) > 1, "Controlled prize %s must leave another copy in the deck" % uid))
		if uid.begins_with("CSVE"):
			prize_energy_count += 1
	checks.append(assert_eq(distinct_prizes.size(), 6, "Controlled prizes must use six distinct identities"))
	checks.append(assert_true(prize_energy_count <= 2, "Controlled prizes must not strand more than two Energy"))
	return run_checks(checks)


func test_tm_and_fighting_energy_choose_the_attackable_active_carrier() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018543 should resolve through the production V18 registry wrapper")

	var delegate: RefCounted = strategy.get("_delegate")
	var state := _tm_route_state(2, 1)
	var player: PlayerState = state.players[0]
	var carrier := player.active_pokemon
	var gible := player.bench[0]
	var roselia := player.bench[1]
	var tm := _real_card("CSV5C_119")
	var active_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_tool", "card": tm, "target_slot": carrier,
	}, state, 0)
	var gible_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_tool", "card": tm, "target_slot": gible,
	}, state, 0)
	var roselia_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_tool", "card": tm, "target_slot": roselia,
	}, state, 0)

	carrier.attached_tool = tm
	carrier.attached_energy.clear()
	var fighting := _real_card("CSVE1C_FIG")
	var carrier_energy_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": fighting, "target_slot": carrier,
	}, state, 0)
	var gible_energy_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": fighting, "target_slot": gible,
	}, state, 0)
	var delegate_bench_score: float = delegate.call("score_action_absolute", {
		"kind": "attach_tool", "card": tm, "target_slot": gible,
	}, state, 0) if delegate != null else INF
	player.bench.clear()
	var no_target_score: float = delegate.call("score_action_absolute", {
		"kind": "attach_tool", "card": tm, "target_slot": carrier,
	}, state, 0) if delegate != null else INF

	return run_checks([
		assert_not_null(delegate, "The production wrapper must expose the Cynthia delegate"),
		assert_true(active_score >= 5400.0, "Two legal Bench targets must give the attackable Active TM carrier the 5400 floor"),
		assert_true(active_score >= gible_score + 8000.0, "TM Evolution must not attach to the Gible it intends to evolve"),
		assert_true(active_score >= roselia_score + 8000.0, "TM Evolution must not attach to the Roselia it intends to evolve"),
		assert_true(delegate_bench_score <= -4000.0, "A Benched TM attachment must be capped at -4000"),
		assert_true(no_target_score <= -1100.0, "An Active TM attachment with no legal evolution target must be capped at -1100"),
		assert_true(carrier_energy_score >= 5000.0, "Fighting Energy must fund the empty Active TM carrier at the 5000 floor"),
		assert_true(carrier_energy_score >= gible_energy_score + 7000.0, "A live TM route must cap Fighting Energy assigned away from its Active carrier"),
	])


func test_first_player_turn_one_locks_tm_attachment_and_granted_attack() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018543 should resolve through the production V18 registry wrapper")

	var state := _tm_route_state(1, 0)
	var player: PlayerState = state.players[0]
	var carrier := player.active_pokemon
	var tm := _real_card("CSV5C_119")
	var attach_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_tool", "card": tm, "target_slot": carrier,
	}, state, 0)
	carrier.attached_tool = tm
	var attack_score: float = strategy.call("score_action_absolute", _tm_attack(carrier), state, 0)
	return run_checks([
		assert_true(attach_score < 0.0, "The first player must keep TM Evolution in hand on turn one"),
		assert_true(attack_score < 0.0, "The first player cannot select TM Evolution's granted attack on turn one"),
	])


func test_two_target_tm_granted_attack_scores_9000_and_rejects_an_illegal_source() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018543 should resolve through the production V18 registry wrapper")

	var delegate: RefCounted = strategy.get("_delegate")
	var state := _tm_route_state(2, 1)
	var player: PlayerState = state.players[0]
	var carrier := player.active_pokemon
	carrier.attached_tool = _real_card("CSV5C_119")
	var wrapper_score: float = strategy.call("score_action_absolute", _tm_attack(carrier), state, 0)
	var delegate_score: float = delegate.call("score_action_absolute", _tm_attack(carrier), state, 0) if delegate != null else -INF
	var illegal_source_score: float = strategy.call("score_action_absolute", _tm_attack(player.bench[0]), state, 0)
	return run_checks([
		assert_not_null(delegate, "The production wrapper must load the MarnieCynthia delegate"),
		assert_eq(delegate.get_script().resource_path if delegate != null else "", DELEGATE_PATH, "Registry resolution must use the deck-owned delegate"),
		assert_eq(delegate_score, 9000.0, "Two legal TM targets must score exactly 7200 + 900 * 2 in the delegate"),
		assert_true(wrapper_score >= 9000.0, "The production wrapper must preserve the two-target TM setup priority"),
		assert_true(illegal_source_score < 0.0, "A Benched Pokemon cannot use the Active-only granted attack"),
	])


func _wrapper_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	if not parsed is Dictionary:
		return null
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", DeckData.from_dict(parsed))


func _tm_route_state(turn_number: int, first_player_index: int) -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	opponent.active_pokemon = _slot(_pokemon("Opponent Active", "Basic", "", 200), 1)
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = first_player_index
	state.turn_number = turn_number
	state.phase = GameState.GamePhase.MAIN

	var carrier := _slot(_pokemon("Active Carrier", "Basic", "", 70), 0)
	carrier.attached_energy.append(_real_card("CSVE1C_FIG"))
	player.active_pokemon = carrier
	player.bench.assign([
		_slot(_real_card_data("CSV10C_111"), 0),
		_slot(_real_card_data("CSV10C_004"), 0),
	])
	player.deck.assign([
		_real_card("CSV10C_112"),
		_real_card("CSV10C_005"),
	])
	return state


func _tm_attack(source: PokemonSlot) -> Dictionary:
	return {
		"kind": "granted_attack",
		"source_slot": source,
		"granted_attack_data": {
			"id": "tm_evolution",
			"name": "Evolution",
			"cost": "C",
			"damage": "",
		},
	}


func _real_card(ref: String) -> CardInstance:
	return CardInstance.create(_real_card_data(ref), 0)


func _real_card_data(ref: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon(card_name: String, stage: String, evolves_from: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name_en = card_name
	card.card_type = "Pokemon"
	card.stage = stage
	card.evolves_from = evolves_from
	card.hp = hp
	card.attacks = [{"name": "Chip", "cost": "C", "damage": "10"}]
	return card


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot


func _deck_counts(payload: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for raw_entry: Variant in payload.get("cards", []):
		var entry: Dictionary = raw_entry
		counts[_entry_uid(entry)] = int(entry.get("count", 0))
	return counts


func _order_uids(payload: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for raw_entry: Variant in payload.get("top_to_bottom", []):
		result.append(_entry_uid(raw_entry as Dictionary))
	return result


func _uid_counts(uids: Array) -> Dictionary:
	var counts: Dictionary = {}
	for raw_uid: Variant in uids:
		var uid := str(raw_uid)
		counts[uid] = int(counts.get(uid, 0)) + 1
	return counts


func _entry_uid(entry: Dictionary) -> String:
	return "%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))]
