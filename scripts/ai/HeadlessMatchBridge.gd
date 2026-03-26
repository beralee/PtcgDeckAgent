class_name HeadlessMatchBridge
extends Control

const AISetupPlannerScript = preload("res://scripts/ai/AISetupPlanner.gd")

var _gsm: GameStateMachine = null
var _pending_choice: String = ""
var _dialog_data: Dictionary = {}
var _setup_done: Array[bool] = [false, false]
var _setup_order: Array[int] = [0, 1]
var _setup_order_index: int = 0
var _setup_planner = AISetupPlannerScript.new()
var _planned_setup_bench_ids: Array[int] = []


func bind(next_gsm: GameStateMachine) -> void:
	if _gsm != null and _gsm.player_choice_required.is_connected(_on_player_choice_required):
		_gsm.player_choice_required.disconnect(_on_player_choice_required)
	_gsm = next_gsm
	if _gsm != null and not _gsm.player_choice_required.is_connected(_on_player_choice_required):
		_gsm.player_choice_required.connect(_on_player_choice_required)


func handles_bridge_owned_prompts() -> bool:
	return true


func supports_effect_interaction_execution() -> bool:
	return false


func bootstrap_pending_setup() -> void:
	if _gsm == null or _gsm.game_state == null:
		return
	if _gsm.game_state.phase != GameState.GamePhase.SETUP or _pending_choice != "":
		return
	if _bootstrap_pending_mulligan_prompt():
		return
	var resume_player_index: int = _get_setup_resume_player_index()
	if resume_player_index >= 0:
		_begin_setup_flow(resume_player_index)


func has_pending_prompt() -> bool:
	return _pending_choice != ""


func get_pending_prompt_type() -> String:
	return _pending_choice


func get_pending_prompt_owner() -> int:
	match _pending_choice:
		"mulligan_extra_draw":
			return int(_dialog_data.get("beneficiary", -1))
		"take_prize", "send_out":
			return int(_dialog_data.get("player", -1))
		_ when _pending_choice.begins_with("setup_active_") or _pending_choice.begins_with("setup_bench_"):
			return int(_dialog_data.get("player", -1))
		"effect_interaction":
			var chooser_owner: int = _get_effect_interaction_prompt_owner()
			if chooser_owner >= 0:
				return chooser_owner
			if _gsm != null and _gsm.game_state != null:
				return _gsm.game_state.current_player_index
			return -1
		_:
			return -1


func can_resolve_pending_prompt() -> bool:
	return _pending_choice == "mulligan_extra_draw" \
		or _pending_choice == "take_prize" \
		or _pending_choice == "send_out" \
		or _pending_choice.begins_with("setup_active_") \
		or _pending_choice.begins_with("setup_bench_")


func can_auto_resolve_pending_prompt() -> bool:
	return can_resolve_pending_prompt()


func resolve_pending_prompt() -> bool:
	if _gsm == null:
		return false
	var pending_choice := _pending_choice
	var dialog_data := _dialog_data.duplicate(true)
	_pending_choice = ""
	_dialog_data.clear()
	var resolved := false
	match pending_choice:
		"mulligan_extra_draw":
			resolved = _resolve_mulligan_extra_draw(dialog_data)
		"take_prize":
			resolved = _resolve_take_prize(dialog_data)
		"send_out":
			resolved = _resolve_send_out(dialog_data)
		_ when pending_choice.begins_with("setup_active_"):
			resolved = _resolve_setup_active(dialog_data)
		_ when pending_choice.begins_with("setup_bench_"):
			resolved = _resolve_setup_bench(dialog_data)
		_:
			resolved = false
	if not resolved:
		_pending_choice = pending_choice
		_dialog_data = dialog_data
	return resolved


func _on_player_choice_required(choice_type: String, data: Dictionary) -> void:
	match choice_type:
		"mulligan_extra_draw":
			_pending_choice = "mulligan_extra_draw"
			_dialog_data = data.duplicate(true)
		"setup_ready":
			_begin_setup_flow()
		"take_prize":
			_pending_choice = "take_prize"
			_dialog_data = {"player": int(data.get("player", -1))}
		"send_out_pokemon":
			_pending_choice = "send_out"
			_dialog_data = {"player": int(data.get("player", -1))}
		_:
			_pending_choice = choice_type
			_dialog_data = data.duplicate(true)


func _begin_setup_flow(start_player_index: int = 0) -> void:
	_setup_done = [false, false]
	_setup_order = [start_player_index, 1 - start_player_index]
	_setup_order_index = 0
	_setup_player_active(_setup_order[_setup_order_index])


func _setup_player_active(pi: int) -> void:
	_show_setup_active_dialog(pi)


func _show_setup_active_dialog(pi: int) -> void:
	if _gsm == null or _gsm.game_state == null or pi < 0 or pi >= _gsm.game_state.players.size():
		return
	var player: PlayerState = _gsm.game_state.players[pi]
	_pending_choice = "setup_active_%d" % pi
	_dialog_data = {
		"player": pi,
		"basics": player.get_basic_pokemon_in_hand(),
	}


func _after_setup_active(pi: int) -> void:
	_show_setup_bench_dialog(pi)


func _show_setup_bench_dialog(pi: int) -> void:
	if _gsm == null or _gsm.game_state == null or pi < 0 or pi >= _gsm.game_state.players.size():
		return
	var player: PlayerState = _gsm.game_state.players[pi]
	if player.is_bench_full() or player.get_basic_pokemon_in_hand().is_empty():
		_after_setup_bench(pi)
		return
	_pending_choice = "setup_bench_%d" % pi
	_dialog_data = {
		"player": pi,
		"cards": player.get_basic_pokemon_in_hand(),
	}


func _after_setup_bench(pi: int) -> void:
	if pi < 0 or pi >= _setup_done.size():
		return
	_setup_done[pi] = true
	if _gsm != null and _gsm.game_state != null:
		while _setup_order_index + 1 < _setup_order.size():
			_setup_order_index += 1
			var next_player_index: int = _setup_order[_setup_order_index]
			if next_player_index < 0 or next_player_index >= _gsm.game_state.players.size():
				continue
			var next_player: PlayerState = _gsm.game_state.players[next_player_index]
			if next_player == null or next_player.active_pokemon == null:
				_setup_player_active(next_player_index)
				return
	if _gsm != null:
		_gsm.setup_complete(0)


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


func _bootstrap_pending_mulligan_prompt() -> bool:
	var last_mulligan_player := _get_last_mulligan_player_index()
	if last_mulligan_player < 0:
		return false
	_pending_choice = "mulligan_extra_draw"
	_dialog_data = {
		"beneficiary": 1 - last_mulligan_player,
		"mulligan_count": _count_mulligans_for_player(last_mulligan_player),
	}
	return true


func _get_last_mulligan_player_index() -> int:
	if _gsm == null:
		return -1
	var actions: Array = _gsm.get_action_log()
	for action_index: int in range(actions.size() - 1, -1, -1):
		var action_variant: Variant = actions[action_index]
		if action_variant is GameAction and action_variant.action_type == GameAction.ActionType.MULLIGAN:
			return int(action_variant.player_index)
	return -1


func _count_mulligans_for_player(player_index: int) -> int:
	if _gsm == null:
		return 0
	var count: int = 0
	for action_variant: Variant in _gsm.get_action_log():
		if action_variant is GameAction \
				and action_variant.action_type == GameAction.ActionType.MULLIGAN \
				and int(action_variant.player_index) == player_index:
			count += 1
	return count


func _resolve_mulligan_extra_draw(dialog_data: Dictionary) -> bool:
	if _gsm == null or _gsm.game_state == null:
		return false
	var beneficiary: int = int(dialog_data.get("beneficiary", -1))
	if beneficiary < 0 or beneficiary >= _gsm.game_state.players.size():
		return false
	_gsm.resolve_mulligan_choice(beneficiary, _setup_planner.choose_mulligan_bonus_draw())
	return true


func _resolve_setup_active(dialog_data: Dictionary) -> bool:
	if _gsm == null or _gsm.game_state == null:
		return false
	var pi: int = int(dialog_data.get("player", -1))
	if pi < 0 or pi >= _gsm.game_state.players.size():
		return false
	var player: PlayerState = _gsm.game_state.players[pi]
	var choice: Dictionary = _setup_planner.plan_opening_setup(player)
	var active_hand_index: int = int(choice.get("active_hand_index", -1))
	if active_hand_index < 0 or active_hand_index >= player.hand.size():
		return false
	_planned_setup_bench_ids.clear()
	for hand_index: int in choice.get("bench_hand_indices", []):
		if hand_index >= 0 and hand_index < player.hand.size():
			_planned_setup_bench_ids.append(player.hand[hand_index].instance_id)
	var active_card: CardInstance = player.hand[active_hand_index]
	if not _gsm.setup_place_active_pokemon(pi, active_card):
		return false
	_after_setup_active(pi)
	return true


func _resolve_setup_bench(dialog_data: Dictionary) -> bool:
	if _gsm == null or _gsm.game_state == null:
		return false
	var pi: int = int(dialog_data.get("player", -1))
	if pi < 0 or pi >= _gsm.game_state.players.size():
		return false
	var player: PlayerState = _gsm.game_state.players[pi]
	var cards_raw: Array = dialog_data.get("cards", [])
	var available_cards: Array[CardInstance] = []
	for card_variant: Variant in cards_raw:
		if card_variant is CardInstance:
			available_cards.append(card_variant)
	var planned_card := _find_next_planned_bench_card(player, available_cards)
	if planned_card == null:
		_after_setup_bench(pi)
		return true
	if not _gsm.setup_place_bench_pokemon(pi, planned_card):
		return false
	_planned_setup_bench_ids.erase(planned_card.instance_id)
	_show_setup_bench_dialog(pi)
	return true


func _resolve_take_prize(dialog_data: Dictionary) -> bool:
	if _gsm == null or _gsm.game_state == null:
		return false
	var player_index: int = int(dialog_data.get("player", -1))
	if player_index < 0 or player_index >= _gsm.game_state.players.size():
		return false
	var layout: Array = _gsm.game_state.players[player_index].get_prize_layout()
	for slot_index: int in layout.size():
		if _gsm.resolve_take_prize(player_index, slot_index):
			return true
	return false


func _resolve_send_out(dialog_data: Dictionary) -> bool:
	if _gsm == null or _gsm.game_state == null:
		return false
	var send_out_player: int = int(dialog_data.get("player", -1))
	if send_out_player < 0 or send_out_player >= _gsm.game_state.players.size():
		return false
	for bench_slot: PokemonSlot in _gsm.game_state.players[send_out_player].bench:
		if _gsm.send_out_pokemon(send_out_player, bench_slot):
			return true
	return false


func _find_next_planned_bench_card(player: PlayerState, available_cards: Array[CardInstance]) -> CardInstance:
	if _planned_setup_bench_ids.is_empty():
		var fallback_choice: Dictionary = _setup_planner.plan_opening_setup(player)
		for hand_index: int in fallback_choice.get("bench_hand_indices", []):
			if hand_index >= 0 and hand_index < player.hand.size():
				_planned_setup_bench_ids.append(player.hand[hand_index].instance_id)
		if _planned_setup_bench_ids.is_empty() and not player.hand.is_empty():
			var active_hand_index: int = int(fallback_choice.get("active_hand_index", -1))
			if active_hand_index >= 0 and active_hand_index < player.hand.size():
				_planned_setup_bench_ids.append(player.hand[active_hand_index].instance_id)
	for planned_id: int in _planned_setup_bench_ids:
		for card: CardInstance in available_cards:
			if card.instance_id == planned_id:
				return card
	return null


func _get_setup_resume_player_index() -> int:
	if _gsm == null or _gsm.game_state == null:
		return -1
	for pi: int in _gsm.game_state.players.size():
		if _gsm.game_state.players[pi] != null and _gsm.game_state.players[pi].active_pokemon == null:
			return pi
	return -1


func _get_effect_interaction_prompt_owner() -> int:
	if _dialog_data.has("chooser_player_index"):
		var chooser_player_index: int = int(_dialog_data.get("chooser_player_index", -1))
		if chooser_player_index >= 0:
			return chooser_player_index
	if _dialog_data.has("player"):
		var player_index: int = int(_dialog_data.get("player", -1))
		if player_index >= 0:
			if bool(_dialog_data.get("opponent_chooses", false)):
				return 1 - player_index
			return player_index
	if bool(_dialog_data.get("opponent_chooses", false)) and _gsm != null and _gsm.game_state != null:
		var current_player_index: int = int(_gsm.game_state.current_player_index)
		if current_player_index >= 0:
			return 1 - current_player_index
	return -1
