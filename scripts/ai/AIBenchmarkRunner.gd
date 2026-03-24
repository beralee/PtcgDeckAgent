class_name AIBenchmarkRunner
extends RefCounted


class HeadlessBattleBridge extends Control:
	var _gsm: GameStateMachine = null
	var _pending_choice: String = ""
	var _dialog_data: Dictionary = {}

	func bind(next_gsm: GameStateMachine) -> void:
		if _gsm != null and _gsm.player_choice_required.is_connected(_on_player_choice_required):
			_gsm.player_choice_required.disconnect(_on_player_choice_required)
		_gsm = next_gsm
		if _gsm != null and not _gsm.player_choice_required.is_connected(_on_player_choice_required):
			_gsm.player_choice_required.connect(_on_player_choice_required)

	func has_pending_prompt() -> bool:
		return _pending_choice != ""

	func get_pending_prompt_owner() -> int:
		match _pending_choice:
			"mulligan_extra_draw":
				return int(_dialog_data.get("beneficiary", -1))
			"take_prize", "send_out":
				return int(_dialog_data.get("player", -1))
			_:
				return -1

	func can_auto_resolve_pending_prompt() -> bool:
		return _pending_choice == "take_prize" or _pending_choice == "send_out"

	func resolve_pending_prompt() -> bool:
		if _gsm == null:
			return false
		var pending_choice := _pending_choice
		var dialog_data := _dialog_data.duplicate(true)
		_pending_choice = ""
		_dialog_data.clear()
		match pending_choice:
			"take_prize":
				var player_index: int = int(dialog_data.get("player", -1))
				if player_index < 0 or player_index >= _gsm.game_state.players.size():
					return false
				var layout: Array = _gsm.game_state.players[player_index].get_prize_layout()
				for slot_index: int in layout.size():
					if _gsm.resolve_take_prize(player_index, slot_index):
						return true
				return false
			"send_out":
				var send_out_player: int = int(dialog_data.get("player", -1))
				if send_out_player < 0 or send_out_player >= _gsm.game_state.players.size():
					return false
				for bench_slot: PokemonSlot in _gsm.game_state.players[send_out_player].bench:
					if _gsm.send_out_pokemon(send_out_player, bench_slot):
						return true
				return false
			_:
				_pending_choice = pending_choice
				_dialog_data = dialog_data
				return false

	func _on_player_choice_required(choice_type: String, data: Dictionary) -> void:
		match choice_type:
			"mulligan_extra_draw":
				_pending_choice = "mulligan_extra_draw"
				_dialog_data = data.duplicate(true)
			"take_prize":
				_pending_choice = "take_prize"
				_dialog_data = {"player": int(data.get("player", -1))}
			"send_out_pokemon":
				_pending_choice = "send_out"
				_dialog_data = {"player": int(data.get("player", -1))}

	func _refresh_ui_after_successful_action(_check_handover: bool = false) -> void:
		pass

	func _refresh_ui() -> void:
		pass

	func _maybe_run_ai() -> void:
		pass

	func _try_start_evolve_trigger_ability_interaction(_player_index: int, _slot: PokemonSlot) -> void:
		pass

	func _try_play_to_bench(player_index: int, basic_card: CardInstance, _source: String = "") -> bool:
		if _gsm == null:
			return false
		return _gsm.play_basic_to_bench(player_index, basic_card)

	func _on_end_turn() -> void:
		if _gsm == null or _gsm.game_state == null:
			return
		_gsm.end_turn(_gsm.game_state.current_player_index)


func run_fixed_match_set(agent: AIOpponent, matchups: Array[Dictionary]) -> Dictionary:
	var wins: int = 0
	for matchup: Dictionary in matchups:
		var result: Dictionary = _run_one_match(agent, matchup)
		if int(result.get("winner_index", -1)) == int(matchup.get("tracked_player_index", 1)):
			wins += 1
	return {
		"total_matches": matchups.size(),
		"wins": wins,
		"win_rate": 0.0 if matchups.is_empty() else float(wins) / float(matchups.size()),
	}


func run_smoke_match(
	agent: AIOpponent,
	step_runner: Callable,
	max_steps: int = 200,
	initial_state: Dictionary = {}
) -> Dictionary:
	var state: Dictionary = initial_state.duplicate(true)
	var steps: int = 0
	while steps < max_steps:
		steps += 1
		var raw_result: Variant = step_runner.call(agent, state)
		var result: Dictionary = raw_result if raw_result is Dictionary else {}
		if result.has("winner_index"):
			var completed := result.duplicate(true)
			completed["steps"] = steps
			completed["terminated_by_cap"] = false
			return completed
	return {
		"winner_index": -1,
		"steps": max_steps,
		"terminated_by_cap": true,
	}


func run_headless_duel(
	player_0_ai: AIOpponent,
	player_1_ai: AIOpponent,
	gsm: GameStateMachine,
	max_steps: int = 200
) -> Dictionary:
	if gsm == null or gsm.game_state == null:
		return {
			"winner_index": -1,
			"steps": 0,
			"terminated_by_cap": false,
			"stalled": true,
		}
	var bridge := HeadlessBattleBridge.new()
	bridge.bind(gsm)
	var steps: int = 0
	while steps < max_steps:
		if gsm.game_state.is_game_over():
			return {
				"winner_index": gsm.game_state.winner_index,
				"steps": steps,
				"terminated_by_cap": false,
				"stalled": false,
			}
		var progressed: bool = false
		if bridge.has_pending_prompt():
			if bridge.can_auto_resolve_pending_prompt():
				progressed = bridge.resolve_pending_prompt()
			else:
				var prompt_owner: int = bridge.get_pending_prompt_owner()
				var prompt_ai: AIOpponent = _get_ai_for_player(player_0_ai, player_1_ai, prompt_owner)
				if prompt_ai != null:
					progressed = prompt_ai.run_single_step(bridge, gsm)
		else:
			var current_ai: AIOpponent = _get_ai_for_player(player_0_ai, player_1_ai, gsm.game_state.current_player_index)
			if current_ai != null:
				progressed = current_ai.run_single_step(bridge, gsm)
		steps += 1
		if not progressed:
			return {
				"winner_index": gsm.game_state.winner_index if gsm.game_state.is_game_over() else -1,
				"steps": steps,
				"terminated_by_cap": false,
				"stalled": true,
			}
	return {
		"winner_index": gsm.game_state.winner_index if gsm.game_state.is_game_over() else -1,
		"steps": max_steps,
		"terminated_by_cap": not gsm.game_state.is_game_over(),
		"stalled": not gsm.game_state.is_game_over(),
	}


func _run_one_match(agent: AIOpponent, matchup: Dictionary) -> Dictionary:
	var step_runner: Variant = matchup.get("step_runner")
	if step_runner is Callable and (step_runner as Callable).is_valid():
		return run_smoke_match(
			agent,
			step_runner as Callable,
			int(matchup.get("max_steps", 200)),
			matchup.get("initial_state", {})
		)
	var runner: Variant = matchup.get("runner")
	if runner is Callable and (runner as Callable).is_valid():
		var called: Variant = (runner as Callable).call(agent, matchup)
		return called if called is Dictionary else {}
	var preset_result: Variant = matchup.get("result", {})
	return preset_result if preset_result is Dictionary else {}


func _get_ai_for_player(player_0_ai: AIOpponent, player_1_ai: AIOpponent, player_index: int) -> AIOpponent:
	if player_0_ai != null and player_0_ai.player_index == player_index:
		return player_0_ai
	if player_1_ai != null and player_1_ai.player_index == player_index:
		return player_1_ai
	return null
