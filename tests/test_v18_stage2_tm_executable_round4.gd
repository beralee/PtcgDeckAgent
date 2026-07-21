class_name TestV18Stage2TMExecutableRound4
extends TestBase


const AIOPPONENT_SCRIPT = preload("res://scripts/ai/AIOpponent.gd")
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800017047


class FixedLegalActionBuilder extends RefCounted:
	var _deck_strategy = null
	var _deck_strategy_detected: bool = false
	var actions: Array[Dictionary] = []

	func build_actions(_gsm: GameStateMachine, _player_index: int) -> Array[Dictionary]:
		return actions.duplicate(true)


func test_first_player_t1_rejects_tm_evolution_in_production_picker() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800017047 should resolve through the production V18 registry")
	var state := _tm_route_state(1, 0, false, true)
	var player: PlayerState = state.players[0]
	var tm: CardInstance = player.hand[0]
	var energy: CardInstance = player.hand[1]

	var attach_result := _production_pick(strategy, state, [
		{"kind": "attach_tool", "card": tm, "target_slot": player.active_pokemon},
		{"kind": "end_turn"},
	])
	_fund_and_attach_tm(player, tm, energy)
	var attack_result := _production_pick(strategy, state, [
		_tm_attack(player.active_pokemon),
		{"kind": "end_turn"},
	])

	return run_checks([
		_tm_rejected_check(attach_result, "attach_tool", "First-player T1 TM attachment"),
		_tm_rejected_check(attack_result, "granted_attack", "First-player T1 TM Evolution"),
	])


func test_active_seed_does_not_count_as_tm_evolution_target() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800017047 should resolve through the production V18 registry")
	var state := _tm_route_state(2, 1, true, false)
	var player: PlayerState = state.players[0]
	var tm: CardInstance = player.hand[0]
	var energy: CardInstance = player.hand[1]

	var attach_result := _production_pick(strategy, state, [
		{"kind": "attach_tool", "card": tm, "target_slot": player.active_pokemon},
		{"kind": "end_turn"},
	])
	_fund_and_attach_tm(player, tm, energy)
	var attack_result := _production_pick(strategy, state, [
		_tm_attack(player.active_pokemon),
		{"kind": "end_turn"},
	])

	return run_checks([
		_tm_rejected_check(attach_result, "attach_tool", "TM attachment with only an Active evolution seed"),
		_tm_rejected_check(attack_result, "granted_attack", "TM Evolution with only an Active evolution seed"),
	])


func test_unfunded_active_after_manual_attachment_rejects_tm_evolution() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800017047 should resolve through the production V18 registry")
	var state := _tm_route_state(2, 1, false, true)
	state.energy_attached_this_turn = true
	var player: PlayerState = state.players[0]
	var tm: CardInstance = player.hand[0]

	var attach_result := _production_pick(strategy, state, [
		{"kind": "attach_tool", "card": tm, "target_slot": player.active_pokemon},
		{"kind": "end_turn"},
	])
	player.active_pokemon.attached_tool = tm
	player.hand.erase(tm)
	var attack_result := _production_pick(strategy, state, [
		_tm_attack(player.active_pokemon),
		{"kind": "end_turn"},
	])

	return run_checks([
		_tm_rejected_check(attach_result, "attach_tool", "Unfunded TM attachment after the manual attachment is spent"),
		_tm_rejected_check(attack_result, "granted_attack", "Unfunded TM Evolution after the manual attachment is spent"),
	])


func test_executable_tm_routes_remain_above_end_turn_in_production_picker() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800017047 should resolve through the production V18 registry")
	var state := _tm_route_state(2, 1, false, true)
	var player: PlayerState = state.players[0]
	var tm: CardInstance = player.hand[0]
	var energy: CardInstance = player.hand[1]

	var hand_funded_result := _production_pick(strategy, state, [
		{"kind": "attach_tool", "card": tm, "target_slot": player.active_pokemon},
		{"kind": "end_turn"},
	])
	_fund_and_attach_tm(player, tm, energy)
	state.energy_attached_this_turn = true
	var attack_result := _production_pick(strategy, state, [
		_tm_attack(player.active_pokemon),
		{"kind": "end_turn"},
	])

	var prepaid_state := _tm_route_state(2, 1, false, true)
	var prepaid_player: PlayerState = prepaid_state.players[0]
	prepaid_state.energy_attached_this_turn = true
	prepaid_player.active_pokemon.attached_energy.append(prepaid_player.hand[1])
	prepaid_player.hand.erase(prepaid_player.hand[1])
	var prepaid_result := _production_pick(strategy, prepaid_state, [
		{"kind": "attach_tool", "card": prepaid_player.hand[0], "target_slot": prepaid_player.active_pokemon},
		{"kind": "end_turn"},
	])

	return run_checks([
		_tm_live_check(hand_funded_result, "attach_tool", "TM attachment funded from hand"),
		_tm_live_check(attack_result, "granted_attack", "Funded TM Evolution"),
		_tm_live_check(prepaid_result, "attach_tool", "TM attachment with Colorless already paid"),
	])


func _production_pick(strategy: RefCounted, state: GameState, actions: Array[Dictionary]) -> Dictionary:
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var ai = AIOPPONENT_SCRIPT.new()
	ai.player_index = 0
	ai.decision_runtime_mode = "rules_only"
	var builder := FixedLegalActionBuilder.new()
	builder.actions = actions
	ai._legal_action_builder = builder
	ai.call("set_deck_strategy", strategy)
	var chosen: Dictionary = ai._choose_greedy_strategy_action(gsm)
	var result := {"chosen_kind": str(chosen.get("kind", ""))}
	var trace = ai.get_last_decision_trace()
	if trace != null:
		for scored_action: Dictionary in trace.scored_actions:
			result[str(scored_action.get("kind", ""))] = float(scored_action.get("absolute_score", -INF))
	return result


func _tm_rejected_check(result: Dictionary, tm_kind: String, label: String) -> String:
	var tm_score := float(result.get(tm_kind, INF))
	var end_score := float(result.get("end_turn", -INF))
	return run_checks([
		assert_eq(str(result.get("chosen_kind", "")), "end_turn", "%s must lose to end_turn in the production picker" % label),
		assert_true(tm_score < end_score, "%s must score below end_turn (tm=%f end=%f)" % [label, tm_score, end_score]),
	])


func _tm_live_check(result: Dictionary, tm_kind: String, label: String) -> String:
	var tm_score := float(result.get(tm_kind, -INF))
	var end_score := float(result.get("end_turn", INF))
	return run_checks([
		assert_eq(str(result.get("chosen_kind", "")), tm_kind, "%s should remain the production pick" % label),
		assert_true(tm_score > end_score, "%s should remain above end_turn (tm=%f end=%f)" % [label, tm_score, end_score]),
	])


func _wrapper_strategy() -> RefCounted:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/decks/%d.json" % DECK_ID))
	if not payload is Dictionary:
		return null
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", DeckData.from_dict(payload))


func _tm_route_state(turn_number: int, first_player_index: int, active_is_seed: bool, add_bench_seed: bool) -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	opponent.active_pokemon = _slot(_pokemon("Opponent Active", 200), 1)
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = first_player_index
	state.turn_number = turn_number
	state.phase = GameState.GamePhase.MAIN

	player.active_pokemon = _slot(_real_card_data("CSV10C_102") if active_is_seed else _real_card_data("CSV8C_135"), 0)
	player.bench.append(_slot(_real_card_data("CSV8C_135") if active_is_seed else _pokemon("Bench filler", 100), 0))
	if add_bench_seed:
		player.bench.append(_slot(_real_card_data("CSV10C_102"), 0))
	player.hand.assign([
		_real_card("CSV5C_119"),
		_real_card("CSVE1C_FIG"),
	])
	player.deck.append(_real_card("CSV10C_103"))
	for index: int in 10:
		player.deck.append(CardInstance.create(_trainer("Deck filler %d" % index), 0))
	for index: int in 6:
		player.prizes.append(CardInstance.create(_trainer("Prize filler %d" % index), 0))
	return state


func _fund_and_attach_tm(player: PlayerState, tm: CardInstance, energy: CardInstance) -> void:
	player.active_pokemon.attached_tool = tm
	player.active_pokemon.attached_energy.append(energy)
	player.hand.erase(tm)
	player.hand.erase(energy)


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
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(payload) if payload is Dictionary else null


func _pokemon(card_name: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	card.attacks = [{"name": "Test", "cost": "C", "damage": "10"}]
	return card


func _trainer(card_name: String) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.card_type = "Item"
	return card


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot
