class_name BattleAIWatchdog
extends RefCounted

const TICK_SECONDS := 0.5
const SOFT_STALL_MSEC := 3000
const BLOCKER_STALL_MSEC := 6000
const HARD_STALL_MSEC := 12000
const RECOVERY_COOLDOWN_MSEC := 1500

var _scene_ref: WeakRef = null
var _tick_armed: bool = false
var _tick_generation: int = 0
var _last_fingerprint: String = ""
var _last_progress_msec: int = 0
var _last_recovery_msec: int = 0
var _recovery_count: int = 0


func setup(scene: Object) -> void:
	_scene_ref = weakref(scene) if scene != null else null
	_reset_tracking()


func notify_activity(reason: String = "", now_msec: int = -1) -> void:
	var scene := _scene()
	if not _should_monitor(scene):
		_reset_tracking()
		return
	var was_inactive := _last_fingerprint == ""
	var now := _now_msec(now_msec)
	_observe_progress(scene, now)
	_arm_tick(scene)
	if was_inactive and reason != "":
		_log(scene, "ai_watchdog_armed", "reason=%s" % reason)


func tick(now_msec: int = -1) -> Dictionary:
	_tick_armed = false
	var scene := _scene()
	if not _should_monitor(scene):
		_reset_tracking()
		return {"action": "inactive"}

	var now := _now_msec(now_msec)
	var fingerprint := _fingerprint(scene)
	if _last_fingerprint == "" or fingerprint != _last_fingerprint:
		_last_fingerprint = fingerprint
		_last_progress_msec = now
		_last_recovery_msec = 0
		_recovery_count = 0
		_arm_tick(scene)
		return {"action": "progress"}

	var stalled_msec := maxi(0, now - _last_progress_msec)
	var result := _recover_if_needed(scene, now, stalled_msec)
	if _should_monitor(scene):
		_arm_tick(scene)
	return result


func _recover_if_needed(scene: Object, now: int, stalled_msec: int) -> Dictionary:
	if stalled_msec >= BLOCKER_STALL_MSEC:
		if bool(scene.call("_is_ai_action_pause_active")):
			_log_recovery(scene, "finish_action_pause", stalled_msec)
			scene.call("_on_ai_action_pause_finished")
			_mark_recovery(now)
			return {"action": "finish_action_pause", "stalled_msec": stalled_msec}
		if bool(scene.get("_coin_animating")) or not (scene.get("_coin_flip_queue") as Array).is_empty():
			_log_recovery(scene, "finish_coin_animation", stalled_msec)
			scene.call("_on_coin_animation_finished")
			_mark_recovery(now)
			return {"action": "finish_coin_animation", "stalled_msec": stalled_msec}
		if bool(scene.get("_draw_reveal_active")):
			_log_recovery(scene, "finish_draw_reveal", stalled_msec)
			scene.call("_ai_watchdog_force_finish_draw_reveal")
			_mark_recovery(now)
			return {"action": "finish_draw_reveal", "stalled_msec": stalled_msec}

	if stalled_msec >= HARD_STALL_MSEC:
		if bool(scene.get("_ai_llm_waiting")):
			_force_rules_after_llm_timeout(scene, stalled_msec)
			_mark_recovery(now)
			return {"action": "fallback_llm_rules", "stalled_msec": stalled_msec}
		var pending_choice := str(scene.get("_pending_choice"))
		if pending_choice == "effect_interaction" and _ai_owns_next_decision(scene):
			_log_recovery(scene, "abort_effect_and_end_turn", stalled_msec)
			scene.set("_ai_step_scheduled", false)
			scene.set("_ai_followup_requested", false)
			scene.call("_reset_effect_interaction")
			scene.call("_refresh_ui")
			if _can_force_end_main_phase(scene):
				scene.call("_on_end_turn", _ai_player_index(scene))
				_mark_recovery(now)
				return {"action": "abort_effect_and_end_turn", "stalled_msec": stalled_msec}
			scene.call("_maybe_run_ai")
			_mark_recovery(now)
			return {"action": "abort_effect", "stalled_msec": stalled_msec}
		if pending_choice == "" and _can_force_end_main_phase(scene):
			_log_recovery(scene, "force_end_turn", stalled_msec)
			scene.set("_ai_step_scheduled", false)
			scene.set("_ai_followup_requested", false)
			scene.call("_on_end_turn", _ai_player_index(scene))
			_mark_recovery(now)
			return {"action": "force_end_turn", "stalled_msec": stalled_msec}

	if stalled_msec < SOFT_STALL_MSEC:
		return {"action": "waiting", "stalled_msec": stalled_msec}
	if bool(scene.get("_ai_running")):
		return {"action": "waiting_for_running_step", "stalled_msec": stalled_msec}
	if _last_recovery_msec > 0 and now - _last_recovery_msec < RECOVERY_COOLDOWN_MSEC:
		return {"action": "recovery_cooldown", "stalled_msec": stalled_msec}

	var stale_scheduled := bool(scene.get("_ai_step_scheduled"))
	if stale_scheduled:
		scene.set("_ai_step_scheduled", false)
	_log_recovery(scene, "reschedule", stalled_msec, "stale_scheduled=%s" % str(stale_scheduled))
	scene.call("_maybe_run_ai")
	_mark_recovery(now)
	return {"action": "reschedule", "stalled_msec": stalled_msec}


func _force_rules_after_llm_timeout(scene: Object, stalled_msec: int) -> void:
	_log_recovery(scene, "fallback_llm_rules", stalled_msec)
	var ai_opponent: Variant = scene.get("_ai_opponent")
	var strategy: Variant = ai_opponent.get("_deck_strategy") if ai_opponent != null else null
	var gsm: Variant = scene.get("_gsm")
	var turn := int(gsm.game_state.turn_number) if gsm != null and gsm.game_state != null else -1
	if strategy != null and strategy.has_method("force_rules_for_turn"):
		strategy.call("force_rules_for_turn", turn, "battle watchdog hard timeout")
	scene.set("_ai_llm_waiting", false)
	if scene.has_method("_stop_llm_wait_hud"):
		scene.call("_stop_llm_wait_hud")
	scene.call("_maybe_run_ai")


func _should_monitor(scene: Object) -> bool:
	if scene == null or not is_instance_valid(scene):
		return false
	if GameManager.current_mode != GameManager.GameMode.VS_AI:
		return false
	if str(scene.get("_battle_mode")) != "live":
		return false
	if scene.has_method("_is_review_mode") and bool(scene.call("_is_review_mode")):
		return false
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null:
		return false
	if str(scene.get("_pending_choice")) == "game_over":
		return false
	# Ending an AI turn advances current_player_index before the short action
	# pause completes. Keep watching that AI-owned blocker even though the next
	# actual decision belongs to the human player.
	if bool(scene.call("_is_ai_action_pause_active")):
		return true
	if scene.has_method("_ensure_ai_opponent"):
		scene.call("_ensure_ai_opponent")
	return _ai_owns_next_decision(scene)


func _ai_owns_next_decision(scene: Object) -> bool:
	var ai_index := _ai_player_index(scene)
	if ai_index < 0:
		return false
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null:
		return false
	var pending_choice := str(scene.get("_pending_choice"))
	if pending_choice == "":
		return (
			gsm.game_state.current_player_index == ai_index
			and gsm.game_state.phase != GameState.GamePhase.SETUP
			and gsm.game_state.phase != GameState.GamePhase.GAME_OVER
		)
	if pending_choice == "mulligan_extra_draw":
		return int((scene.get("_dialog_data") as Dictionary).get("beneficiary", -1)) == ai_index
	if pending_choice.begins_with("setup_active_") or pending_choice.begins_with("setup_bench_"):
		return int(pending_choice.split("_")[-1]) == ai_index
	if pending_choice == "take_prize":
		return int(scene.get("_pending_prize_player_index")) == ai_index and int(scene.get("_pending_prize_remaining")) > 0
	if pending_choice in ["send_out", "heavy_baton_target", "exp_share_target"]:
		return int((scene.get("_dialog_data") as Dictionary).get("player", -1)) == ai_index
	if pending_choice == "effect_interaction":
		return int(scene.call("_get_effect_interaction_prompt_player_index")) == ai_index
	return false


func _can_force_end_main_phase(scene: Object) -> bool:
	var gsm: Variant = scene.get("_gsm")
	return (
		gsm != null
		and gsm.game_state != null
		and gsm.game_state.phase == GameState.GamePhase.MAIN
		and gsm.game_state.current_player_index == _ai_player_index(scene)
	)


func _ai_player_index(scene: Object) -> int:
	var ai_opponent: Variant = scene.get("_ai_opponent")
	return int(ai_opponent.get("player_index")) if ai_opponent != null else -1


func _observe_progress(scene: Object, now: int) -> void:
	var fingerprint := _fingerprint(scene)
	if _last_fingerprint == "" or fingerprint != _last_fingerprint:
		_last_fingerprint = fingerprint
		_last_progress_msec = now
		_last_recovery_msec = 0
		_recovery_count = 0


func _fingerprint(scene: Object) -> String:
	var gsm: Variant = scene.get("_gsm")
	var state: GameState = gsm.game_state if gsm != null else null
	var player_zones: Array[Dictionary] = []
	if state != null:
		for player: PlayerState in state.players:
			player_zones.append({
				"hand": player.hand.size(),
				"deck": player.deck.size(),
				"discard": player.discard_pile.size(),
				"prizes": player.prizes.size(),
				"bench": player.bench.size(),
				"active": player.active_pokemon.get_top_card().instance_id if player.active_pokemon != null and player.active_pokemon.get_top_card() != null else -1,
			})
	return JSON.stringify({
		"turn": state.turn_number if state != null else -1,
		"current": state.current_player_index if state != null else -1,
		"phase": int(state.phase) if state != null else -1,
		"action_log": gsm.action_log.size() if gsm != null else -1,
		"pending": str(scene.get("_pending_choice")),
		"effect_step": int(scene.get("_pending_effect_step_index")),
		"prize_remaining": int(scene.get("_pending_prize_remaining")),
		"draw_active": bool(scene.get("_draw_reveal_active")),
		"draw_queue": (scene.get("_draw_reveal_queue") as Array).size(),
		"coin_active": bool(scene.get("_coin_animating")),
		"coin_queue": (scene.get("_coin_flip_queue") as Array).size(),
		"pause_active": bool(scene.call("_is_ai_action_pause_active")),
		"llm_waiting": bool(scene.get("_ai_llm_waiting")),
		"zones": player_zones,
	})


func _arm_tick(scene: Object) -> void:
	if _tick_armed or not (scene is Node) or not (scene as Node).is_inside_tree():
		return
	var tree := (scene as Node).get_tree()
	if tree == null:
		return
	_tick_armed = true
	var generation := _tick_generation
	var timer := tree.create_timer(TICK_SECONDS)
	timer.timeout.connect(func() -> void:
		if generation != _tick_generation:
			return
		_tick_armed = false
		tick()
	, CONNECT_ONE_SHOT)


func _scene() -> Object:
	if _scene_ref == null:
		return null
	var scene: Object = _scene_ref.get_ref()
	return scene if scene != null and is_instance_valid(scene) else null


func _now_msec(explicit_msec: int) -> int:
	return explicit_msec if explicit_msec >= 0 else Time.get_ticks_msec()


func _mark_recovery(now: int) -> void:
	_last_recovery_msec = now
	_recovery_count += 1


func _log_recovery(scene: Object, action: String, stalled_msec: int, extra: String = "") -> void:
	var detail := "action=%s stalled_msec=%d recovery=%d" % [action, stalled_msec, _recovery_count + 1]
	if extra != "":
		detail += " %s" % extra
	_log(scene, "ai_watchdog_recovery", detail)


func _log(scene: Object, event: String, detail: String) -> void:
	if scene != null and scene.has_method("_runtime_log"):
		scene.call("_runtime_log", event, detail)


func _reset_tracking() -> void:
	_tick_generation += 1
	_tick_armed = false
	_last_fingerprint = ""
	_last_progress_msec = 0
	_last_recovery_msec = 0
	_recovery_count = 0
