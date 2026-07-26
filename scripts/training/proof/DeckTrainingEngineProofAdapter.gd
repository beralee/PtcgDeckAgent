class_name DeckTrainingEngineProofAdapter
extends RefCounted


const AILegalActionBuilderScript := preload("res://scripts/ai/AILegalActionBuilder.gd")
const AIOpponentScript := preload("res://scripts/ai/AIOpponent.gd")
const GameStateClonerScript := preload("res://scripts/ai/GameStateCloner.gd")
const HeadlessMatchBridgeScript := preload("res://scripts/ai/HeadlessMatchBridge.gd")
const MCTSPlannerScript := preload("res://scripts/ai/MCTSPlanner.gd")
const GoalEvaluatorScript := preload("res://scripts/training/DeckTrainingGoalEvaluator.gd")
const ProofCertificateScript := preload("res://scripts/training/proof/DeckTrainingProofCertificate.gd")
const ScenarioStateSnapshotScript := preload("res://scripts/engine/scenario/ScenarioStateSnapshot.gd")

const ROLE_PLAYER := "player"
const ROLE_OPPONENT := "opponent"
const ROLE_TERMINAL := "terminal"

var _scenario: Dictionary = {}
var _player_index := 0
var _opponent_index := 1
var _cloner := GameStateClonerScript.new()
var _action_codec := MCTSPlannerScript.new()


func configure(scenario: Dictionary, player_index: int = 0) -> void:
	_scenario = scenario.duplicate(true)
	_player_index = player_index
	_opponent_index = 1 - player_index


func provider_name() -> String:
	return "production_game_state_machine_v1"


func scenario_fingerprint() -> String:
	return ProofCertificateScript.scenario_fingerprint(_scenario)


func make_initial_state(gsm: GameStateMachine) -> Dictionary:
	if gsm == null or gsm.game_state == null:
		return {}
	var initial_prizes: Array[int] = []
	for player: PlayerState in gsm.game_state.players:
		initial_prizes.append(player.prizes.size())
	return {
		"gsm": _cloner.clone_gsm(gsm),
		"initial_prize_counts": initial_prizes,
		"player_turns_completed": 0,
		"target_instance_ids": _capture_target_instance_ids(gsm.game_state),
	}


func clone_state(state: Variant) -> Variant:
	if not (state is Dictionary):
		return {}
	var source: Dictionary = state
	var gsm: GameStateMachine = source.get("gsm", null)
	var cloned := source.duplicate(true)
	cloned["gsm"] = _cloner.clone_gsm(gsm) if gsm != null else null
	return cloned


func state_key(state: Variant) -> String:
	if not (state is Dictionary):
		return ""
	var data: Dictionary = state
	var gsm: GameStateMachine = data.get("gsm", null)
	if gsm == null or gsm.game_state == null:
		return ""
	var key_data := {
		"state": ScenarioStateSnapshotScript.capture(gsm.game_state),
		"player_turns_completed": int(data.get("player_turns_completed", 0)),
	}
	return JSON.stringify(ProofCertificateScript._canonicalize(key_data)).sha256_text()


func node_role(state: Variant) -> String:
	if not (state is Dictionary):
		return ROLE_TERMINAL
	var gsm: GameStateMachine = (state as Dictionary).get("gsm", null)
	if gsm == null or gsm.game_state == null or bool(terminal_result(state).get("terminal", false)):
		return ROLE_TERMINAL
	return ROLE_PLAYER if gsm.game_state.current_player_index == _player_index else ROLE_OPPONENT


func terminal_result(state: Variant) -> Dictionary:
	if not (state is Dictionary):
		return {"terminal": true, "success": false, "reason": "invalid_engine_state"}
	var data: Dictionary = state
	var gsm: GameStateMachine = data.get("gsm", null)
	if gsm == null or gsm.game_state == null:
		return {"terminal": true, "success": false, "reason": "missing_game_state_machine"}
	var context := {
		"initial_prize_counts": data.get("initial_prize_counts", []),
		"target_knockouts": _count_target_knockouts(gsm.game_state, data.get("target_instance_ids", [])),
	}
	var goal: Dictionary = _scenario.get("goal", {})
	if gsm.game_state.is_game_over() and gsm.game_state.winner_index != _player_index:
		return {
			"terminal": true,
			"success": false,
			"reason": "opponent_won_before_goal:%s" % gsm.game_state.win_reason,
			"score": GoalEvaluatorScript.progress(goal, gsm.game_state, context),
		}
	if GoalEvaluatorScript.is_satisfied(goal, gsm.game_state, context):
		return {
			"terminal": true,
			"success": true,
			"reason": "training_goal_satisfied",
			"score": GoalEvaluatorScript.progress(goal, gsm.game_state, context),
		}
	if gsm.game_state.is_game_over():
		return {
			"terminal": true,
			"success": false,
			"reason": "game_ended_before_goal:%s" % gsm.game_state.win_reason,
			"score": GoalEvaluatorScript.progress(goal, gsm.game_state, context),
		}
	if int(data.get("player_turns_completed", 0)) >= clampi(int(_scenario.get("turn_limit", 1)), 1, 2):
		return {
			"terminal": true,
			"success": false,
			"reason": "player_turn_limit_exhausted",
			"score": GoalEvaluatorScript.progress(goal, gsm.game_state, context),
		}
	return {"terminal": false}


func legal_choices(state: Variant) -> Dictionary:
	if not (state is Dictionary):
		return {"complete": false, "reason": "invalid_engine_state", "choices": []}
	var gsm: GameStateMachine = (state as Dictionary).get("gsm", null)
	if gsm == null or gsm.game_state == null:
		return {"complete": false, "reason": "missing_game_state_machine", "choices": []}
	if gsm.game_state.phase != GameState.GamePhase.MAIN:
		return {
			"complete": false,
			"reason": "phase_enumeration_not_supported:%d" % int(gsm.game_state.phase),
			"choices": [],
		}
	var actor := int(gsm.game_state.current_player_index)
	var actions: Array[Dictionary] = AILegalActionBuilderScript.new().build_actions(gsm, actor, false)
	var choices: Array[Dictionary] = []
	for action: Dictionary in actions:
		var serialized: Dictionary = _action_codec.call("_serialize_action", action)
		var stable_json := JSON.stringify(ProofCertificateScript._canonicalize(serialized))
		var kind := str(action.get("kind", ""))
		var supported := not bool(action.get("requires_interaction", false))
		choices.append({
			"id": "%s:%s" % [kind, stable_json.sha256_text().substr(0, 16)],
			"label": _action_label(action),
			"action": serialized,
			"supported": supported,
			"unsupported_reason": "interaction_choice_enumeration_not_supported:%s" % kind if not supported else "",
			"player_action_cost": 1 if actor == _player_index and kind != "end_turn" else 0,
		})
	return {"complete": true, "choices": choices}


func apply_choice(state: Variant, choice: Dictionary) -> Dictionary:
	if not (state is Dictionary):
		return {"ok": false, "complete": false, "reason": "invalid_engine_state"}
	var data: Dictionary = state
	var gsm: GameStateMachine = data.get("gsm", null)
	if gsm == null or gsm.game_state == null:
		return {"ok": false, "complete": false, "reason": "missing_game_state_machine"}
	var action_variant: Variant = choice.get("action", null)
	if not (action_variant is Dictionary):
		return {"ok": false, "complete": false, "reason": "choice_missing_serialized_action"}
	var actor_before := int(gsm.game_state.current_player_index)
	var resolved: Dictionary = _action_codec.call("_resolve_action_for_gsm", action_variant, gsm, actor_before)
	if resolved.is_empty():
		return {"ok": false, "complete": true, "reason": "action_reference_resolution_failed"}

	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	var executor := AIOpponentScript.new()
	executor.configure(actor_before, 3)
	var executed: bool = bool(executor.call("_execute_action", bridge, gsm, resolved))
	if not executed:
		bridge.bind(null)
		bridge.free()
		return {"ok": false, "complete": true, "reason": "production_action_rejected"}
	if bridge.has_pending_prompt():
		var pending_type := bridge.get_pending_prompt_type()
		bridge.bind(null)
		bridge.free()
		return {
			"ok": false,
			"complete": false,
			"reason": "prompt_choice_enumeration_not_supported:%s" % pending_type,
		}
	bridge.bind(null)
	bridge.free()

	var actor_after := int(gsm.game_state.current_player_index)
	if actor_before == _player_index and actor_after == _opponent_index:
		data["player_turns_completed"] = int(data.get("player_turns_completed", 0)) + 1
	return {"ok": true, "complete": true, "state": data}


func _action_label(action: Dictionary) -> String:
	var kind := str(action.get("kind", ""))
	var card: CardInstance = action.get("card", null)
	if card != null and card.card_data != null:
		return "%s %s" % [kind, card.card_data.name]
	var slot: PokemonSlot = action.get("source_slot", action.get("target_slot", null))
	if slot != null and slot.get_top_card() != null:
		return "%s %s" % [kind, slot.get_pokemon_name()]
	return kind


func _capture_target_instance_ids(state: GameState) -> Array[int]:
	var result: Array[int] = []
	var goal: Dictionary = GoalEvaluatorScript.base_goal(_scenario.get("goal", {}))
	if str(goal.get("type", "")) != GoalEvaluatorScript.GOAL_TARGET_KNOCKOUTS:
		return result
	for target_variant: Variant in goal.get("targets", []):
		if not (target_variant is Dictionary):
			continue
		var target: Dictionary = target_variant
		var player_index := int(target.get("player", _opponent_index))
		if player_index < 0 or player_index >= state.players.size():
			continue
		var player: PlayerState = state.players[player_index]
		var slot: PokemonSlot = player.active_pokemon
		if str(target.get("zone", "active")) == "bench":
			var bench_index := int(target.get("index", -1))
			slot = player.bench[bench_index] if bench_index >= 0 and bench_index < player.bench.size() else null
		if slot != null and slot.get_top_card() != null:
			result.append(slot.get_top_card().instance_id)
	return result


func _count_target_knockouts(state: GameState, ids_variant: Variant) -> int:
	if not (ids_variant is Array):
		return 0
	var ids: Array = ids_variant
	var found: Dictionary = {}
	for player: PlayerState in state.players:
		for card: CardInstance in player.discard_pile:
			if card != null and card.instance_id in ids:
				found[card.instance_id] = true
	return found.size()
