class_name TestV18FlareonLockPivotRound1
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18TeraNoctowl.gd")
const DECK_PATH := "res://data/bundled_user/decks/800017643.json"


func test_current_carnelian_lock_excludes_flareon_from_ready_debt_and_owner() -> String:
	var strategy := _strategy()
	var flareon := _slot("CSV9.5C", "023")
	var sylveon := _slot("CSV9C", "090")
	if strategy == null or flareon == null or sylveon == null:
		return assert_true(false, "Flareon lock-pivot fixtures should load")
	_fund(flareon)
	_lock_from_turn(flareon, 3)
	var state := _state()
	state.players[0].active_pokemon = flareon
	state.players[0].bench = [sylveon]

	var ready_on_locked_turn: PokemonSlot = strategy.call("_best_ready_attacker", state.players[0], state)
	var locked_plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var locked_flags: Dictionary = locked_plan.get("flags", {})
	var locked_owner: Dictionary = locked_plan.get("owner", {})

	state.turn_number = 5
	state.current_player_index = 1
	var ready_on_opponent_turn: PokemonSlot = strategy.call("_best_ready_attacker", state.players[0], state)
	state.turn_number = 7
	state.current_player_index = 0
	var ready_after_expiry: PokemonSlot = strategy.call("_best_ready_attacker", state.players[0], state)

	return run_checks([
		assert_null(ready_on_locked_turn, "A fully funded Flareon under the current Carnelian lock must not be ready"),
		assert_true(bool(locked_flags.get("flareon_attack_debt", false)), "A locked Flareon must not clear attack debt"),
		assert_eq(str(locked_owner.get("turn_owner_name", "")), _slot_name(sylveon), "The locked Flareon must not own the turn route"),
		assert_eq(str(locked_owner.get("pivot_target_name", "")), _slot_name(sylveon), "The pivot owner should move to the unlocked route candidate"),
		assert_eq(ready_on_opponent_turn, flareon, "The lock marker must not be treated as next-own-turn lock during the opponent turn"),
		assert_eq(ready_after_expiry, flareon, "A historical Carnelian marker must not suppress Flareon after the exact locked turn"),
	])


func test_executable_lock_pivot_scores_above_pass_and_zero_damage_fan_rotom() -> String:
	var strategy := _strategy()
	var flareon := _slot("CSV9.5C", "023")
	var sylveon := _slot("CSV9C", "090")
	var fan_rotom := _slot("CSV9C", "161")
	var switch_card := _card("CSV1C", "113")
	var kieran := _card("CSV8C", "198")
	if strategy == null or flareon == null or sylveon == null or fan_rotom == null \
			or switch_card == null or kieran == null:
		return assert_true(false, "Flareon pivot action fixtures should load")
	_fund(flareon)
	_fund(sylveon)
	_lock_from_turn(flareon, 3)
	var state := _state()
	state.players[0].active_pokemon = flareon
	state.players[0].bench = [sylveon, fan_rotom]
	state.players[0].hand = [switch_card, kieran]
	var context := {"game_state": state, "player_index": 0}
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})

	var switch_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer", "card": switch_card, "productive": true,
	}, state, 0, plan)
	var kieran_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer", "card": kieran, "productive": true,
	}, state, 0, plan)
	var retreat_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "retreat",
		"bench_target": sylveon,
		"energy_to_discard": [flareon.attached_energy[0], flareon.attached_energy[1]],
	}, state, 0, plan)
	var pass_score: float = strategy.call("score_action_absolute_with_plan", {"kind": "end_turn"}, state, 0, plan)
	var zero_rotom_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": fan_rotom,
		"attack_index": 0,
		"projected_damage": 0,
		"projected_knockout": false,
	}, state, 0, plan)
	var switch_mode_score: float = strategy.call("score_interaction_target", "switch_active", {
		"id": "kieran_mode",
	}, context)
	var damage_mode_score: float = strategy.call("score_interaction_target", "boost_vs_active_rule_box", {
		"id": "kieran_mode",
	}, context)

	return run_checks([
		assert_true(switch_score >= 4000.0, "Switch should receive an executable Carnelian unlock score"),
		assert_true(kieran_score >= 4000.0, "Kieran should receive an executable Carnelian unlock score"),
		assert_true(retreat_score >= 4000.0, "Retreat should receive an executable Carnelian unlock score"),
		assert_true(minf(switch_score, minf(kieran_score, retreat_score)) >= pass_score + 4000.0, "Every executable pivot should outrank passing"),
		assert_true(minf(switch_score, minf(kieran_score, retreat_score)) >= zero_rotom_score + 5000.0, "Every executable pivot should outrank Fan Rotom's zero-damage attack"),
		assert_true(switch_mode_score >= damage_mode_score + 3000.0, "Kieran should choose its switch mode in the lock-pivot window"),
	])


func test_lock_pivot_hands_off_to_an_unlocked_ready_backup() -> String:
	var strategy := _strategy()
	var flareon := _slot("CSV9.5C", "023")
	var sylveon := _slot("CSV9C", "090")
	if strategy == null or flareon == null or sylveon == null:
		return assert_true(false, "Flareon handoff fixtures should load")
	_fund(flareon)
	_fund(sylveon)
	_lock_from_turn(flareon, 3)
	var state := _state()
	state.players[0].active_pokemon = flareon
	state.players[0].bench = [sylveon]
	var context := {"game_state": state, "player_index": 0}
	var locked_score: float = strategy.call("score_handoff_target", flareon, {"id": "self_switch_target"}, context)
	var backup_score: float = strategy.call("score_handoff_target", sylveon, {"id": "self_switch_target"}, context)
	var interaction_backup_score: float = strategy.call("score_interaction_target", sylveon, {
		"id": "kieran_switch_target",
	}, context)

	return run_checks([
		assert_true(backup_score >= locked_score + 5000.0, "Handoff must prefer the unlocked ready backup over locked Flareon"),
		assert_eq(interaction_backup_score, backup_score, "Kieran's follow-up target should use the same unlocked handoff policy"),
	])


func test_projected_carnelian_ko_remains_above_lock_pivots() -> String:
	var strategy := _strategy()
	var flareon := _slot("CSV9.5C", "023")
	var sylveon := _slot("CSV9C", "090")
	var switch_card := _card("CSV1C", "113")
	if strategy == null or flareon == null or sylveon == null or switch_card == null:
		return assert_true(false, "Flareon KO-priority fixtures should load")
	_fund(flareon)
	_fund(sylveon)
	_lock_from_turn(flareon, 3)
	var state := _state()
	state.players[0].active_pokemon = flareon
	state.players[0].bench = [sylveon]
	state.players[0].hand = [switch_card]
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var pivot_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "play_trainer", "card": switch_card, "productive": true,
	}, state, 0, plan)
	var knockout_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack",
		"source_slot": flareon,
		"attack_index": 1,
		"projected_damage": 280,
		"projected_knockout": true,
	}, state, 0, plan)
	return assert_true(knockout_score >= pivot_score + 2000.0, "A projected Carnelian KO must remain terminally preferred over pivot setup")


func _strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	if not parsed is Dictionary:
		return null
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	strategy.call("configure_from_deck", DeckData.from_dict(parsed))
	return strategy


func _state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	return state


func _slot(set_code: String, card_index: String) -> PokemonSlot:
	var data := CardDatabase.get_card(set_code, card_index)
	if data == null:
		return null
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, 0))
	return slot


func _card(set_code: String, card_index: String) -> CardInstance:
	var data := CardDatabase.get_card(set_code, card_index)
	return CardInstance.create(data, 0) if data != null else null


func _fund(slot: PokemonSlot) -> void:
	for _index: int in 5:
		slot.attached_energy.append(_energy())


func _energy() -> CardInstance:
	var data := CardData.new()
	data.name_en = "Rainbow test Energy"
	data.card_type = "Basic Energy"
	data.energy_provides = "ANY"
	return CardInstance.create(data, 0)


func _lock_from_turn(slot: PokemonSlot, turn_number: int) -> void:
	slot.effects.append({
		"type": "attack_lock_all",
		"source_attack_index": 1,
		"turn": turn_number,
	})


func _slot_name(slot: PokemonSlot) -> String:
	var data := slot.get_card_data()
	if data == null:
		return ""
	return str(data.name_en) if str(data.name_en) != "" else str(data.name)
