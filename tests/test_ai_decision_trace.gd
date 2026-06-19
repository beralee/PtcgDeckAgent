class_name TestAIDecisionTrace
extends TestBase

const AIDecisionTraceScript = preload("res://scripts/ai/AIDecisionTrace.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")


class EndTurnStubBattleScene extends Control:
	var end_turn_calls: int = 0

	func _on_end_turn(_action_player_index: int = -1) -> void:
		end_turn_calls += 1


func _make_player_state(player_index: int) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = player_index
	return player


func _make_ai_manual_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 7
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	return gsm


func _make_basic_card_data(card_name: String, hp: int = 70) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	return card


func _make_energy_card_data(card_name: String = "Psychic Energy") -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.card_type = "Basic Energy"
	card.energy_provides = "P"
	return card


func _make_slot(card_name: String, hp: int = 70, owner_index: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(_make_basic_card_data(card_name, hp), owner_index))
	return slot


func test_ai_decision_trace_stores_structured_fields() -> String:
	var trace := AIDecisionTraceScript.new()
	trace.turn_number = 3
	trace.player_index = 1
	trace.legal_actions = [{"kind": "attach_energy"}]
	trace.scored_actions = [{"kind": "attach_energy", "score": 240.0}]
	trace.chosen_action = {"kind": "attach_energy", "score": 240.0, "reason_tags": ["active_attach"]}
	trace.reason_tags = ["active_attach"]
	var serialized = trace.to_dictionary()

	return run_checks([
		assert_eq(trace.turn_number, 3, "Trace should preserve the turn number"),
		assert_eq(trace.player_index, 1, "Trace should preserve the player index"),
		assert_eq(trace.legal_actions.size(), 1, "Trace should preserve legal actions"),
		assert_eq(trace.scored_actions.size(), 1, "Trace should preserve scored actions"),
		assert_eq(trace.chosen_action.get("kind", ""), "attach_energy", "Trace should preserve the chosen action"),
		assert_eq(trace.chosen_action.get("score", -1.0), 240.0, "Trace should preserve the chosen action score"),
		assert_eq(trace.reason_tags, ["active_attach"], "Trace should preserve reason tags"),
		assert_eq(serialized.get("turn_number", -1), 3, "Serialized trace should preserve the turn number"),
		assert_eq(serialized.get("player_index", -1), 1, "Serialized trace should preserve the player index"),
		assert_eq(serialized.get("legal_actions", []).size(), 1, "Serialized trace should preserve legal actions"),
		assert_eq(serialized.get("scored_actions", []).size(), 1, "Serialized trace should preserve scored actions"),
		assert_eq(serialized.get("chosen_action", {}).get("kind", ""), "attach_energy", "Serialized trace should preserve the chosen action"),
		assert_eq(serialized.get("chosen_action", {}).get("score", -1.0), 240.0, "Serialized trace should preserve the chosen action score"),
		assert_eq(serialized.get("reason_tags", []), ["active_attach"], "Serialized trace should preserve reason tags"),
	])


func test_ai_decision_trace_clone_freezes_card_and_slot_snapshots() -> String:
	CardInstance.reset_id_counter()
	var slot := _make_slot("Snapshot Ralts", 70, 0)
	var energy := CardInstance.create(_make_energy_card_data(), 0)
	var trace := AIDecisionTraceScript.new()
	trace.turn_number = 1
	trace.legal_actions = [{
		"kind": "attach_energy",
		"card": energy,
		"target_slot": slot,
	}]
	trace.scored_actions = [{
		"kind": "attach_energy",
		"card": energy,
		"target_slot": slot,
		"score": 240.0,
	}]
	trace.chosen_action = trace.scored_actions[0].duplicate(true)

	var frozen = trace.clone()
	slot.damage_counters = 70
	var payload: Dictionary = frozen.to_dictionary()
	var legal_action: Dictionary = (payload.get("legal_actions", []) as Array)[0]
	var scored_action: Dictionary = (payload.get("scored_actions", []) as Array)[0]
	var chosen_action: Dictionary = payload.get("chosen_action", {})
	var legal_target = legal_action.get("target_slot", null)
	var scored_target = scored_action.get("target_slot", null)
	var chosen_target = chosen_action.get("target_slot", null)
	var legal_card = legal_action.get("card", null)
	var legal_target_dict: Dictionary = legal_target if legal_target is Dictionary else {}
	var scored_target_dict: Dictionary = scored_target if scored_target is Dictionary else {}
	var chosen_target_dict: Dictionary = chosen_target if chosen_target is Dictionary else {}
	var legal_card_dict: Dictionary = legal_card if legal_card is Dictionary else {}
	var serialized := JSON.stringify(payload)

	return run_checks([
		assert_true(legal_target is Dictionary, "Trace clone should replace PokemonSlot refs with frozen dictionaries"),
		assert_true(scored_target is Dictionary, "Scored actions should freeze PokemonSlot refs"),
		assert_true(chosen_target is Dictionary, "Chosen action should freeze PokemonSlot refs"),
		assert_true(legal_card is Dictionary, "Trace clone should replace CardInstance refs with frozen dictionaries"),
		assert_eq(int(legal_target_dict.get("remaining_hp", -1)), 70, "Frozen target should keep the HP from decision time"),
		assert_eq(int(scored_target_dict.get("damage_counters", -1)), 0, "Frozen scored target should not reflect later damage"),
		assert_eq(int(chosen_target_dict.get("remaining_hp", -1)), 70, "Frozen chosen target should not drift after clone"),
		assert_eq(str(legal_card_dict.get("trace_ref_type", "")), "card", "Frozen CardInstance should keep a card trace ref type"),
		assert_eq(str(legal_card_dict.get("name_en", "")), "Psychic Energy", "Frozen card should preserve the card name"),
		assert_false(serialized.contains("HP=0/70"), "Serialized trace should not show later HP for an earlier decision"),
	])


func test_ai_opponent_records_last_decision_trace_for_one_step() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(0, 1)
	var gsm := _make_ai_manual_gsm()
	var battle_scene := EndTurnStubBattleScene.new()

	var handled := ai.run_single_step(battle_scene, gsm)
	var trace = ai.get_last_decision_trace()

	return run_checks([
		assert_true(handled, "AI should complete a simple decision step"),
		assert_not_null(trace, "AI should expose the last decision trace after a step"),
		assert_eq(trace.turn_number, 7, "Trace should capture the game turn number"),
		assert_eq(trace.player_index, 0, "Trace should capture the AI player index"),
		assert_eq(trace.legal_actions.size(), 1, "Trace should capture the legal action list"),
		assert_eq(trace.scored_actions.size(), 1, "Trace should capture the scored action list"),
		assert_eq(trace.chosen_action.get("kind", ""), "end_turn", "Trace should capture the chosen action"),
		assert_eq(trace.chosen_action.get("score", -1.0), 0.0, "Trace should capture the chosen action score"),
		assert_eq(trace.reason_tags, [], "Trace should default to an empty reason tag list"),
		assert_eq(battle_scene.end_turn_calls, 1, "AI should execute the end turn action through the battle scene"),
	])


func test_ai_opponent_returns_isolated_decision_trace_copy() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(0, 1)
	var gsm := _make_ai_manual_gsm()
	var battle_scene := EndTurnStubBattleScene.new()

	var handled := ai.run_single_step(battle_scene, gsm)
	var trace_a = ai.get_last_decision_trace()
	trace_a.turn_number = 99
	trace_a.reason_tags.append("mutated")
	trace_a.chosen_action["score"] = 999.0
	var trace_b = ai.get_last_decision_trace()

	return run_checks([
		assert_true(handled, "AI should complete a simple decision step"),
		assert_eq(trace_b.turn_number, 7, "Returned trace copies should not let callers mutate the AI-owned turn number"),
		assert_eq(trace_b.reason_tags, [], "Returned trace copies should not let callers mutate the AI-owned reason tags"),
		assert_eq(trace_b.chosen_action.get("score", -1.0), 0.0, "Returned trace copies should not let callers mutate the AI-owned chosen action"),
	])
