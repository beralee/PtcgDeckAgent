class_name DeckTrainingSession
extends RefCounted


const GoalEvaluatorScript := preload("res://scripts/training/DeckTrainingGoalEvaluator.gd")

var scenario: Dictionary = {}
var initial_snapshot: Dictionary = {}
var completed := false
var failed := false
var result_reason := ""
var initial_prize_counts: Array[int] = []
var player_turns_completed := 0
var _previous_current_player := 0
var _target_instance_ids: Array[int] = []
var _knocked_out_target_ids: Dictionary = {}
var _game_winner_index := -1
var _game_over_reason := ""


func setup(scenario_data: Dictionary, snapshot: Dictionary) -> void:
	scenario = scenario_data.duplicate(true)
	initial_snapshot = snapshot.duplicate(true)
	completed = false
	failed = false
	result_reason = ""
	player_turns_completed = 0
	_previous_current_player = int(snapshot.get("current_player_index", 0))
	_game_winner_index = -1
	_game_over_reason = ""
	initial_prize_counts.clear()
	for player_variant: Variant in snapshot.get("players", []):
		var player: Dictionary = player_variant if player_variant is Dictionary else {}
		initial_prize_counts.append((player.get("prizes", []) as Array).size() if player.get("prizes", []) is Array else 0)
	_target_instance_ids = _capture_target_instance_ids(snapshot, scenario.get("goal", {}))
	_knocked_out_target_ids.clear()


func on_action_logged(_action: GameAction, state: GameState) -> Dictionary:
	if state != null and not is_terminal():
		_refresh_target_knockouts(state)
	return status(state)


func on_state_changed(state: GameState) -> Dictionary:
	if state == null or is_terminal():
		return status(state)
	_refresh_target_knockouts(state)
	var current := int(state.current_player_index)
	if _previous_current_player == 0 and current == 1:
		player_turns_completed += 1
	_previous_current_player = current
	if player_turns_completed >= turn_limit():
		_finalize(state)
	return status(state)


func on_game_over(winner_index: int, reason: String, state: GameState) -> Dictionary:
	if not is_terminal():
		_game_winner_index = winner_index
		_game_over_reason = reason
		_refresh_target_knockouts(state)
		_finalize(state)
	return status(state)


func turn_limit() -> int:
	return clampi(int(scenario.get("turn_limit", 1)), 1, 2)


func is_terminal() -> bool:
	return completed or failed


func grade(state: GameState) -> String:
	return GoalEvaluatorScript.grade(scenario.get("goal", {}), state, _context())


func status(state: GameState) -> Dictionary:
	return {
		"completed": completed,
		"failed": failed,
		"terminal": is_terminal(),
		"reason": result_reason,
		"grade": grade(state) if is_terminal() else "",
		"player_turns_completed": player_turns_completed,
		"turn_limit": turn_limit(),
		"progress": GoalEvaluatorScript.progress(scenario.get("goal", {}), state, _context()),
		"required": GoalEvaluatorScript.required(scenario.get("goal", {})),
		"progress_text": GoalEvaluatorScript.progress_text(scenario.get("goal", {}), state, _context()),
	}


func _finalize(state: GameState) -> void:
	var winner_index := _game_winner_index
	if state != null and state.is_game_over():
		winner_index = state.winner_index
	if winner_index >= 0 and winner_index != 0:
		completed = false
		failed = true
		result_reason = "对手已获胜"
		return
	completed = GoalEvaluatorScript.is_satisfied(scenario.get("goal", {}), state, _context())
	failed = not completed
	if completed:
		result_reason = "目标达成"
		return
	var failures := GoalEvaluatorScript.failure_reasons(scenario.get("goal", {}), state, _context())
	result_reason = "局面条件未达成" if "progress_goal_not_met" not in failures and not failures.is_empty() else "回合用尽"


func _context() -> Dictionary:
	return {
		"initial_prize_counts": initial_prize_counts,
		"target_knockouts": _knocked_out_target_ids.size(),
		"winner_index": _game_winner_index,
		"game_over_reason": _game_over_reason,
	}


func _capture_target_instance_ids(snapshot: Dictionary, goal_variant: Variant) -> Array[int]:
	var result: Array[int] = []
	if not (goal_variant is Dictionary):
		return result
	var goal: Dictionary = GoalEvaluatorScript.base_goal(goal_variant)
	if str(goal.get("type", "")) != GoalEvaluatorScript.GOAL_TARGET_KNOCKOUTS:
		return result
	var players: Array = snapshot.get("players", [])
	for target_variant: Variant in goal.get("targets", []):
		if not (target_variant is Dictionary):
			continue
		var target: Dictionary = target_variant
		var player_index := int(target.get("player", 1))
		if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
			continue
		var player: Dictionary = players[player_index]
		var slot: Dictionary = {}
		if str(target.get("zone", "active")) == "bench":
			var bench: Array = player.get("bench", [])
			var bench_index := int(target.get("index", -1))
			if bench_index >= 0 and bench_index < bench.size() and bench[bench_index] is Dictionary:
				slot = bench[bench_index]
		else:
			slot = player.get("active", {}) if player.get("active", {}) is Dictionary else {}
		var stack: Array = slot.get("pokemon_stack", [])
		if not stack.is_empty() and stack[0] is Dictionary:
			var instance_id := int((stack[0] as Dictionary).get("instance_id", -1))
			if instance_id >= 0:
				result.append(instance_id)
	return result


func _refresh_target_knockouts(state: GameState) -> void:
	if state == null or state.players.size() < 2:
		return
	for card: CardInstance in state.players[1].discard_pile:
		if card != null and card.instance_id in _target_instance_ids:
			_knocked_out_target_ids[card.instance_id] = true
