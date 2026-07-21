class_name TestV18PureDragapultGustLiabilityRound2
extends TestBase


const STRATEGY_REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const FIXED_ORDER_REGISTRY_SCRIPT = preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")

const DECK_ID := 800018499
const RULES_PATH := "res://scripts/ai/DeckStrategyV18Rules.gd"
const DELEGATE_PATH := "res://scripts/ai/DeckStrategy175PureDragapult.gd"
const MARACTUS_UID := "CSV10C_008"
const MARACTUS_EFFECT_ID := "a5b32602f9c443a038fef288059aeb43"
const HAWLUCHA_UID := "CSV1C_079"
const HAWLUCHA_EFFECT_ID := "74b83ef8987d072950dfe3bde3364d87"


func test_preconversion_suppresses_real_gust_liabilities_below_pivot_and_terminal_actions() -> String:
	var strategy := _production_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018499 should resolve through the production Registry")
	var state := _pressure_state(false)
	var player: PlayerState = state.players[0]
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var plan_flags: Dictionary = plan.get("flags", {}) if plan.get("flags", {}) is Dictionary else {}
	var non_pressure := _pressure_state(false)
	non_pressure.players[1].active_pokemon = _slot(_real_card("CSV8C_157", 1))
	var pivot_score := _score(strategy, {
		"kind": "retreat",
		"bench_target": player.bench[0],
	}, state)
	var attack_score := _score(strategy, {
		"kind": "attack",
		"source_slot": player.active_pokemon,
		"attack_index": 0,
		"projected_damage": 10,
	}, state)
	var end_turn_score := _score(strategy, {"kind": "end_turn"}, state)
	var budew_score := _score(strategy, {
		"kind": "play_basic_to_bench",
		"card": _real_card("CSV9.5C_004", 0),
	}, state)
	var checks: Array[String] = [
		assert_eq(strategy.get_script().resource_path, RULES_PATH, "Round 2 must exercise the production V18 rules wrapper"),
		assert_eq(_delegate_path(strategy), DELEGATE_PATH, "Deck 800018499 must keep its Pure Dragapult delegate"),
		assert_true(bool(plan_flags.get("miraidon_pressure", false)), "Real Miraidon must activate the production pressure flag"),
		assert_true(_ready_dragapult(strategy, player) == null, "The preconversion fixture must not have a Phantom Dive-ready Dragapult"),
	]
	for identity: Dictionary in _liability_identities():
		var card := _real_card(str(identity.get("uid", "")), 0)
		var bench_score := _score(strategy, {"kind": "play_basic_to_bench", "card": card}, state)
		var non_pressure_score := _score(strategy, {"kind": "play_basic_to_bench", "card": card}, non_pressure)
		checks.append(assert_not_null(card, "%s must resolve through CardDatabase" % str(identity.get("uid", ""))))
		checks.append(assert_eq(
			str(card.card_data.effect_id) if card != null and card.card_data != null else "",
			str(identity.get("effect_id", "")),
			"%s must anchor the production effect ID" % str(identity.get("uid", ""))
		))
		checks.append(assert_true(
			bench_score < pivot_score,
			"%s must rank below the Budew-to-Dragapult pivot before Phantom Dive (bench=%f pivot=%f)" % [
				str(identity.get("uid", "")), bench_score, pivot_score,
			]
		))
		checks.append(assert_true(
			bench_score < attack_score and bench_score < end_turn_score,
			"%s must rank below terminal Budew attack/end-turn actions (bench=%f attack=%f end=%f)" % [
				str(identity.get("uid", "")), bench_score, attack_score, end_turn_score,
			]
		))
		checks.append(assert_true(
			bench_score < budew_score,
			"The liability guard must not suppress the existing Budew bench route"
		))
		checks.append(assert_true(
			non_pressure_score > bench_score,
			"%s must remain unsuppressed outside Miraidon pressure" % str(identity.get("uid", ""))
		))
	return run_checks(checks)


func test_ready_phantom_dive_releases_real_gust_liabilities() -> String:
	var strategy := _production_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018499 should resolve through the production Registry")
	var preconversion := _pressure_state(false)
	var ready := _pressure_state(true)
	var ready_plan: Dictionary = strategy.call("build_turn_plan", ready, 0, {})
	var ready_flags: Dictionary = ready_plan.get("flags", {}) if ready_plan.get("flags", {}) is Dictionary else {}
	var ready_end_turn := _score(strategy, {"kind": "end_turn"}, ready)
	var checks: Array[String] = [
		assert_true(bool(ready_flags.get("miraidon_pressure", false)), "Miraidon pressure must remain active after conversion"),
		assert_not_null(_ready_dragapult(strategy, ready.players[0]), "The release fixture must have a Phantom Dive-ready Dragapult"),
	]
	for identity: Dictionary in _liability_identities():
		var uid := str(identity.get("uid", ""))
		var suppressed_score := _score(strategy, {
			"kind": "play_basic_to_bench",
			"card": _real_card(uid, 0),
		}, preconversion)
		var released_score := _score(strategy, {
			"kind": "play_basic_to_bench",
			"card": _real_card(uid, 0),
		}, ready)
		checks.append(assert_true(
			released_score > suppressed_score,
			"%s must release its preconversion suppression once Phantom Dive is ready (before=%f ready=%f)" % [
				uid, suppressed_score, released_score,
			]
		))
		checks.append(assert_true(
			released_score > ready_end_turn,
			"%s must return to an admissible production bench score after conversion (bench=%f end=%f)" % [
				uid, released_score, ready_end_turn,
			]
		))
	return run_checks(checks)


func test_round2_guard_preserves_budew_strong_fixed_opening() -> String:
	var strategy := _production_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018499 should resolve through the production Registry")
	var fixed_order: Array[Dictionary] = FIXED_ORDER_REGISTRY_SCRIPT.new().load_fixed_order(DECK_ID)
	var player := PlayerState.new()
	player.player_index = 0
	for entry: Dictionary in fixed_order.slice(0, 7):
		player.hand.append(_real_card(_entry_uid(entry), 0))
	var setup: Dictionary = strategy.call("plan_opening_setup", player)
	var active_index := int(setup.get("active_hand_index", -1))
	var bench_indices: Array = setup.get("bench_hand_indices", [])
	var active_uid := _card_uid(player.hand[active_index]) if active_index >= 0 and active_index < player.hand.size() else ""
	var bench_uids: Array[String] = []
	for raw_index: Variant in bench_indices:
		var index := int(raw_index)
		if index >= 0 and index < player.hand.size():
			bench_uids.append(_card_uid(player.hand[index]))
	return run_checks([
		assert_eq(active_uid, "CSV9.5C_004", "Strong fixed opening must keep Budew Active"),
		assert_true("CSV8C_157" in bench_uids, "Strong fixed opening must keep its Dreepy route"),
	])


func _production_strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = DECK_ID
	return STRATEGY_REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _pressure_state(phantom_ready: bool) -> GameState:
	var state := GameState.new()
	state.turn_number = 3
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
		_set_prizes(player, 6)
	state.players[0].active_pokemon = _slot(_real_card("CSV9.5C_004", 0))
	var dragapult := _slot(_real_card("CSV8C_159", 0))
	dragapult.attached_energy.append(_real_card("CSVE1C_FIR", 0))
	if phantom_ready:
		dragapult.attached_energy.append(_real_card("CSVE1C_PSY", 0))
	state.players[0].bench.append(dragapult)
	state.players[1].active_pokemon = _slot(_real_card("CSV1C_050", 1))
	return state


func _ready_dragapult(strategy: RefCounted, player: PlayerState) -> PokemonSlot:
	var delegate := _delegate(strategy)
	if delegate == null:
		return null
	var value: Variant = delegate.call("_best_ready_dragapult_slot", player)
	return value as PokemonSlot if value is PokemonSlot else null


func _delegate(strategy: RefCounted) -> RefCounted:
	if strategy == null:
		return null
	var value: Variant = strategy.get("_delegate")
	return value as RefCounted if value is RefCounted else null


func _delegate_path(strategy: RefCounted) -> String:
	var value := _delegate(strategy)
	return value.get_script().resource_path if value != null else ""


func _liability_identities() -> Array[Dictionary]:
	return [
		{"uid": MARACTUS_UID, "effect_id": MARACTUS_EFFECT_ID},
		{"uid": HAWLUCHA_UID, "effect_id": HAWLUCHA_EFFECT_ID},
	]


func _set_prizes(player: PlayerState, count: int) -> void:
	for index: int in count:
		var card_data := CardData.new()
		card_data.name = "Prize %d" % index
		card_data.name_en = card_data.name
		card_data.card_type = "Item"
		player.prizes.append(CardInstance.create(card_data, player.player_index))


func _real_card(uid: String, owner_index: int) -> CardInstance:
	var parts := uid.rsplit("_", true, 1)
	var card_data: CardData = CardDatabase.get_card(parts[0], parts[1]) if parts.size() == 2 else null
	return CardInstance.create(card_data, owner_index) if card_data != null else null


func _slot(card: CardInstance) -> PokemonSlot:
	var slot := PokemonSlot.new()
	if card != null:
		slot.pokemon_stack.append(card)
	return slot


func _card_uid(card: CardInstance) -> String:
	return card.card_data.get_uid() if card != null and card.card_data != null else ""


func _entry_uid(entry: Dictionary) -> String:
	return "%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))]
