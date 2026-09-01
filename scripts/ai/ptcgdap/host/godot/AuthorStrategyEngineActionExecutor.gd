class_name AuthorStrategyEngineActionExecutor
extends RefCounted

## Host-side command leaf. It may hold private engine references, but it never
## scores or selects an action. The author policy receives only the public
## frame; this executor commits one binding from that exact current window.


func execute(
	player_index: int,
	battle_scene: Control,
	gsm: GameStateMachine,
	action: Dictionary
) -> bool:
	if gsm == null or gsm.game_state == null or player_index not in [0, 1]:
		return false
	match str(action.get("kind", "")):
		"attach_energy":
			if gsm.attach_energy(player_index, action.get("card"), action.get("target_slot")):
				_after_success(battle_scene, player_index)
				return true
		"attach_tool":
			if gsm.attach_tool(player_index, action.get("card"), action.get("target_slot")):
				_after_success(battle_scene, player_index)
				return true
		"play_basic_to_bench":
			if battle_scene != null and battle_scene.has_method("_try_play_to_bench"):
				return _call_scene_with_progress(
					battle_scene, gsm, "_try_play_to_bench", [player_index, action.get("card"), ""]
				)
			if gsm.play_basic_to_bench(player_index, action.get("card")):
				_after_success(battle_scene, player_index)
				return true
		"evolve":
			var target: PokemonSlot = action.get("target_slot") as PokemonSlot
			if gsm.evolve_pokemon(player_index, action.get("card"), target):
				if battle_scene != null and battle_scene.has_method("_mark_ready_vfx_action_source"):
					battle_scene.call("_mark_ready_vfx_action_source", player_index, "evolve")
				if battle_scene != null and battle_scene.has_method("_refresh_ui"):
					battle_scene.call("_refresh_ui")
				if battle_scene != null and battle_scene.has_method("_try_start_evolve_trigger_ability_interaction"):
					battle_scene.call("_try_start_evolve_trigger_ability_interaction", player_index, target)
				if battle_scene != null and battle_scene.has_method("_maybe_run_ai"):
					battle_scene.call("_maybe_run_ai")
				return true
		"play_trainer":
			return _execute_card_action(
				battle_scene, gsm, player_index, action, "_try_play_trainer_with_interaction",
				func(targets: Array) -> bool: return gsm.play_trainer(player_index, action.get("card"), targets)
			)
		"play_stadium":
			return _execute_card_action(
				battle_scene, gsm, player_index, action, "_try_play_stadium_with_interaction",
				func(targets: Array) -> bool: return gsm.play_stadium(player_index, action.get("card"), targets)
			)
		"use_stadium_effect":
			var stadium_targets := _targets(action)
			if not stadium_targets.is_empty():
				if gsm.use_stadium_effect(player_index, stadium_targets):
					_after_success(battle_scene, player_index)
					return true
				return false
			if bool(action.get("requires_interaction", false)):
				return _call_scene_with_progress(
					battle_scene, gsm, "_try_use_stadium_with_interaction", [player_index]
				)
			if gsm.use_stadium_effect(player_index, stadium_targets):
				_after_success(battle_scene, player_index)
				return true
		"use_ability":
			var ability_targets := _targets(action)
			if not ability_targets.is_empty():
				if gsm.use_ability(player_index, action.get("source_slot"), int(action.get("ability_index", 0)), ability_targets):
					_after_success(battle_scene, player_index, true, "use_ability")
					return true
				return false
			if bool(action.get("requires_interaction", false)):
				return _call_scene_with_progress(battle_scene, gsm, "_try_use_ability_with_interaction", [
					player_index, action.get("source_slot"), int(action.get("ability_index", 0)),
				])
			if gsm.use_ability(player_index, action.get("source_slot"), int(action.get("ability_index", 0)), ability_targets):
				_after_success(battle_scene, player_index, true, "use_ability")
				return true
		"retreat":
			# RETREAT in MAIN is a declaration.  Payment and SWITCH are fresh
			# official-shaped windows owned by BattleScene/DecisionPort; never
			# consume the action builder's convenience bench target here.
			if battle_scene != null and battle_scene.has_method("_show_retreat_dialog"):
				return _call_scene_with_progress(
					battle_scene, gsm, "_show_retreat_dialog", [player_index]
				)
			if gsm.retreat(player_index, action.get("energy_to_discard", []), action.get("bench_target")):
				_after_success(battle_scene, player_index)
				return true
		"attack":
			return _execute_attack(battle_scene, gsm, player_index, action, false)
		"granted_attack":
			return _execute_attack(battle_scene, gsm, player_index, action, true)
		"end_turn":
			if battle_scene != null and battle_scene.has_method("_on_end_turn"):
				battle_scene.call("_on_end_turn", player_index)
				return true
			gsm.end_turn(player_index)
			return true
	return false


func _execute_card_action(
	battle_scene: Control,
	gsm: GameStateMachine,
	player_index: int,
	action: Dictionary,
	interaction_method: StringName,
	direct_call: Callable
) -> bool:
	var targets := _targets(action)
	if not targets.is_empty():
		if bool(direct_call.call(targets)):
			_after_success(battle_scene, player_index)
			return true
		return false
	if bool(action.get("requires_interaction", false)):
		return _call_scene_with_progress(
			battle_scene, gsm, interaction_method, [player_index, action.get("card")]
		)
	if bool(direct_call.call(targets)):
		_after_success(battle_scene, player_index)
		return true
	return false


func _execute_attack(
	battle_scene: Control,
	gsm: GameStateMachine,
	player_index: int,
	action: Dictionary,
	granted: bool
) -> bool:
	var targets := _targets(action)
	var attack_index := int(action.get("attack_index", -1))
	var source_slot: PokemonSlot = action.get("source_slot") as PokemonSlot
	if source_slot == null:
		source_slot = gsm.game_state.players[player_index].active_pokemon
	if not targets.is_empty():
		var ok := gsm.use_granted_attack(player_index, source_slot, action.get("granted_attack_data", {}), targets) \
			if granted else gsm.use_attack(player_index, attack_index, targets)
		if ok:
			_after_success(battle_scene, player_index, true)
		return ok
	if bool(action.get("requires_interaction", false)):
		return _call_scene_with_progress(
			battle_scene,
			gsm,
			"_try_use_granted_attack_with_interaction" if granted else "_try_use_attack_with_interaction",
			[player_index, source_slot, action.get("granted_attack_data", {})] if granted else [player_index, source_slot, attack_index]
		)
	var direct_ok := gsm.use_granted_attack(player_index, source_slot, action.get("granted_attack_data", {}), targets) \
		if granted else gsm.use_attack(player_index, attack_index, targets)
	if direct_ok:
		_after_success(battle_scene, player_index, true)
	return direct_ok


func _call_scene_with_progress(
	battle_scene: Control,
	gsm: GameStateMachine,
	method: StringName,
	args: Array
) -> bool:
	if battle_scene == null or not battle_scene.has_method(method):
		return false
	var pending_before := str(battle_scene.get("_pending_choice"))
	var log_before := gsm.action_log.size()
	var turn_before := int(gsm.game_state.turn_number)
	var player_before := int(gsm.game_state.current_player_index)
	var phase_before := int(gsm.game_state.phase)
	var result: Variant = battle_scene.callv(method, args)
	if typeof(result) == TYPE_BOOL:
		return bool(result)
	return (
		str(battle_scene.get("_pending_choice")) != pending_before
		or gsm.action_log.size() != log_before
		or int(gsm.game_state.turn_number) != turn_before
		or int(gsm.game_state.current_player_index) != player_before
		or int(gsm.game_state.phase) != phase_before
	)


func _after_success(
	battle_scene: Control,
	player_index: int,
	check_handover: bool = false,
	action_kind: String = ""
) -> void:
	if battle_scene != null and battle_scene.has_method("_refresh_ui_after_successful_action"):
		battle_scene.call("_refresh_ui_after_successful_action", check_handover, player_index, action_kind)


static func _targets(action: Dictionary) -> Array:
	var raw: Variant = action.get("targets", [])
	return raw if raw is Array else []
