class_name TestV18MunkidoriBlazikenTMRound2
extends TestBase


const AIOPPONENT_SCRIPT = preload("res://scripts/ai/AIOpponent.gd")
const AI_STEP_RESOLVER_SCRIPT = preload("res://scripts/ai/AIStepResolver.gd")
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 18000625


class FixedLegalActionBuilder extends RefCounted:
	var _deck_strategy = null
	var _deck_strategy_detected: bool = false
	var actions: Array[Dictionary] = []

	func build_actions(_gsm: GameStateMachine, _player_index: int) -> Array[Dictionary]:
		return actions.duplicate(true)


class ProductionInteractionScene extends Control:
	var _pending_choice: String = "effect_interaction"
	var _pending_effect_steps: Array[Dictionary] = []
	var _pending_effect_step_index: int = 0
	var _pending_effect_context: Dictionary = {}
	var _pending_effect_kind: String = "trainer"
	var _pending_effect_card: CardInstance = null
	var _pending_effect_slot: PokemonSlot = null
	var _pending_effect_ability_index: int = -1
	var picked_indices := PackedInt32Array()

	func _resolve_effect_step_chooser_player(_step: Dictionary) -> int:
		return 0

	func _effect_step_uses_counter_distribution_ui(_step: Dictionary) -> bool:
		return false

	func _effect_step_uses_field_assignment_ui(_step: Dictionary) -> bool:
		return false

	func _effect_step_uses_field_slot_ui(_step: Dictionary) -> bool:
		return false

	func _handle_effect_interaction_choice(indices: PackedInt32Array) -> void:
		picked_indices = indices


func test_inactive_tm_actions_rank_below_end_turn_in_production_picker() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 18000625 should resolve through the production V18 registry")
	var state := _tm_route_state(1, 0)
	var player: PlayerState = state.players[0]
	var pecharunt := player.active_pokemon
	var tm: CardInstance = player.hand[0]
	var fire: CardInstance = player.hand[1]
	player.hand.append(_real_card("CSV8C_094"))

	var attach_result := _production_pick(strategy, state, [
		{"kind": "attach_tool", "card": tm, "target_slot": pecharunt},
		{"kind": "end_turn"},
	])

	pecharunt.attached_tool = tm
	pecharunt.attached_energy.append(fire)
	player.hand.erase(tm)
	player.hand.erase(fire)
	var attack_result := _production_pick(strategy, state, [
		_tm_attack(pecharunt),
		{"kind": "end_turn"},
	])

	return run_checks([
		assert_eq(str(attach_result.get("chosen_kind", "")), "end_turn", "Inactive TM attachment must lose to end_turn in the production picker"),
		assert_true(
			float(attach_result.get("attach_tool", INF)) < float(attach_result.get("end_turn", -INF)),
			"Inactive TM attachment must score below end_turn after wrapper and continuity scoring (tm=%f end=%f)" % [attach_result.get("attach_tool", INF), attach_result.get("end_turn", -INF)]
		),
		assert_eq(str(attack_result.get("chosen_kind", "")), "end_turn", "Inactive TM Evolution must lose to end_turn in the production picker"),
		assert_true(
			float(attack_result.get("granted_attack", INF)) < float(attack_result.get("end_turn", -INF)),
			"Inactive TM Evolution must score below end_turn after wrapper and continuity scoring (tm=%f end=%f)" % [attack_result.get("granted_attack", INF), attack_result.get("end_turn", -INF)]
		),
	])


func test_active_pecharunt_tm_route_still_beats_end_turn_in_production_picker() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 18000625 should resolve through the production V18 registry")
	var state := _tm_route_state(2, 1)
	var player: PlayerState = state.players[0]
	var pecharunt := player.active_pokemon
	var tm: CardInstance = player.hand[0]
	var fire: CardInstance = player.hand[1]
	player.hand.append(_real_card("CSV8C_094"))

	var attach_result := _production_pick(strategy, state, [
		{"kind": "attach_tool", "card": tm, "target_slot": pecharunt},
		{"kind": "end_turn"},
	])

	pecharunt.attached_tool = tm
	pecharunt.attached_energy.append(fire)
	player.hand.erase(tm)
	player.hand.erase(fire)
	var attack_result := _production_pick(strategy, state, [
		_tm_attack(pecharunt),
		{"kind": "end_turn"},
	])

	return run_checks([
		assert_eq(str(attach_result.get("chosen_kind", "")), "attach_tool", "Live attach_tm must keep active Pecharunt as the production pick"),
		assert_true(
			float(attach_result.get("attach_tool", -INF)) > float(attach_result.get("end_turn", INF)),
			"Live attach_tm must remain above end_turn (tm=%f end=%f)" % [attach_result.get("attach_tool", -INF), attach_result.get("end_turn", INF)]
		),
		assert_eq(str(attack_result.get("chosen_kind", "")), "granted_attack", "Live TM Evolution must remain the production pick once Fire is attached"),
		assert_true(
			float(attack_result.get("granted_attack", -INF)) > float(attack_result.get("end_turn", INF)),
			"Live TM Evolution must remain above end_turn (tm=%f end=%f)" % [attack_result.get("granted_attack", -INF), attack_result.get("end_turn", INF)]
		),
	])


func test_inactive_tm_ultra_ball_preserves_one_startup_fire_in_production_interaction_picker() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 18000625 should resolve through the production V18 registry")
	var state := _tm_route_state(1, 0)
	var player: PlayerState = state.players[0]
	var tm: CardInstance = player.hand[0]
	var fire_a: CardInstance = player.hand[1]
	var fire_b := _real_card("CSVE1C_FIR")
	var ultra_ball := _real_card("CSV1C_112")
	player.hand.append_array([fire_b, ultra_ball])
	var discard_items: Array = [fire_a, fire_b, tm]

	var scene := ProductionInteractionScene.new()
	scene._pending_effect_card = ultra_ball
	scene._pending_effect_steps = [{
		"id": "discard_cards",
		"items": discard_items,
		"min_select": 2,
		"max_select": 2,
		"allow_cancel": true,
	}]
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var resolver = AI_STEP_RESOLVER_SCRIPT.new()
	resolver.set_deck_strategy(strategy)
	var resolved: bool = resolver.resolve_pending_step(scene, gsm, 0)
	var picked: Array = []
	for index: int in scene.picked_indices:
		if index >= 0 and index < discard_items.size():
			picked.append(discard_items[index])
	var discarded_fire := 0
	for card: CardInstance in picked:
		if card.card_data != null and card.card_data.card_type == "Basic Energy" \
				and str(card.card_data.energy_provides) == "R":
			discarded_fire += 1
	scene.free()

	return run_checks([
		assert_true(resolved, "The production interaction resolver must resolve Ultra Ball's mandatory discard step"),
		assert_eq(picked.size(), 2, "Ultra Ball must still pay its exact two-card discard cost"),
		assert_eq(discarded_fire, 1, "Inactive TM setup must preserve one of the two Basic Fire cards for the unpowered Torchic line"),
		assert_true(tm in picked, "The inactive TM should replace the protected startup Fire in the discard pair"),
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


func _wrapper_strategy() -> RefCounted:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/decks/%d.json" % DECK_ID))
	if not payload is Dictionary:
		return null
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", DeckData.from_dict(payload))


func _tm_route_state(turn_number: int, first_player_index: int) -> GameState:
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

	player.active_pokemon = _slot(_real_card_data("CSV9C_127"), 0)
	player.bench.append(_slot(_real_card_data("CSV10C_036"), 0))
	player.hand.assign([
		_real_card("CSV5C_119"),
		_real_card("CSVE1C_FIR"),
	])
	player.deck.append(_real_card("CSV10C_037"))
	for index: int in 10:
		player.deck.append(CardInstance.create(_trainer("Deck filler %d" % index), 0))
	for index: int in 6:
		player.prizes.append(CardInstance.create(_trainer("Prize filler %d" % index), 0))
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
