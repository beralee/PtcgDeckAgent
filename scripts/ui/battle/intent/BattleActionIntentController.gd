class_name BattleActionIntentController
extends RefCounted

const IntentModel := preload("res://scripts/ui/battle/intent/BattleActionIntentModel.gd")
const IntentOverlay := preload("res://scripts/ui/battle/intent/BattleActionIntentOverlay.gd")
const VfxCatalog := preload("res://scripts/ui/battle/intent/BattleInteractionVfxCatalog.gd")
const OverlayGeometry := preload("res://scripts/ui/battle/BattleOverlayGeometry.gd")

var _scene: Control = null
var _overlay: Control = null
var _model: Dictionary = {}
var _last_phase: int = -1
var _last_turn: int = -1
var _last_view_player: int = -1
var _combo_level: int = 0
var _last_success_msec: int = -100000


func setup(scene: Control) -> void:
	_scene = scene
	if bool(GameManager.battle_effects_enabled):
		_ensure_overlay()


func sync() -> void:
	if _scene == null or not is_instance_valid(_scene):
		return
	var gsm: GameStateMachine = _scene.get("_gsm") as GameStateMachine
	if not bool(GameManager.battle_effects_enabled):
		_model = {}
		if _overlay != null and is_instance_valid(_overlay):
			_overlay.call("clear_visuals")
		_track_phase(gsm, int(_scene.get("_view_player")))
		return
	_ensure_overlay()
	if _overlay == null:
		return
	if _should_suppress():
		_model = {}
		_overlay.call("clear_intents")
		_track_phase(gsm, int(_scene.get("_view_player")))
		return
	var view_player := int(_scene.get("_view_player"))
	var selected := _scene.get("_selected_hand_card") as CardInstance
	_model = IntentModel.build(gsm, view_player, selected)
	_apply_model_to_overlay()
	_sync_low_hp_hazards(gsm, view_player)
	_maybe_play_phase_sweep(gsm, view_player)


func clear() -> void:
	_model = {}
	_last_phase = -1
	_last_turn = -1
	_last_view_player = -1
	_combo_level = 0
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.call("clear_visuals")


func release() -> void:
	clear()
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_scene = null


func visual_snapshot() -> Dictionary:
	if _overlay == null or not is_instance_valid(_overlay):
		return {"actionable_count": 0, "target_count": 0, "path_count": 0, "toast_visible": false}
	var snapshot: Dictionary = _overlay.call("visual_snapshot")
	snapshot["mode"] = str(_model.get("mode", "idle"))
	return snapshot


func current_model() -> Dictionary:
	return _model.duplicate(true)


func show_rejection(payload: Dictionary) -> void:
	if _scene == null or not is_instance_valid(_scene):
		return
	_ensure_overlay()
	if _overlay == null:
		return
	var anchor := _resolve_rejection_anchor(payload)
	_overlay.call(
		"show_rejection",
		anchor,
		str(payload.get("title", "当前无法执行")),
		str(payload.get("reason", "当前无法执行该操作。"))
	)


func play_success(success_kind: String, payload: Dictionary = {}) -> void:
	if not bool(GameManager.battle_effects_enabled) or not _prepare_overlay():
		return
	_overlay.call("dismiss_rejection")
	var source_rect := _resolve_source_rect(payload)
	var target_rect := _resolve_target_rect(payload)
	var color := _success_color(payload)
	var event_payload := payload.duplicate(true)
	event_payload["from_rect"] = source_rect
	event_payload["to_rect"] = target_rect
	event_payload["point"] = target_rect.get_center() if target_rect.has_area() else _overlay.size * 0.5
	event_payload["color"] = color
	_overlay.call("play_event", "success_converge", event_payload)
	match success_kind:
		"energy", "attach_energy":
			_overlay.call("play_event", "energy_orbit", event_payload)
		"tool", "attach_tool":
			_overlay.call("play_event", "tool_lock", event_payload)
		"ability", "use_ability":
			_overlay.call("play_event", "ability_ripple", event_payload)
		"retreat":
			_overlay.call("play_event", "retreat_swap", event_payload)
	_record_combo(event_payload)


func play_press(payload: Dictionary = {}) -> void:
	if not bool(GameManager.battle_effects_enabled) or not _prepare_overlay():
		return
	_overlay.call("dismiss_rejection")
	var anchor := _resolve_target_rect(payload)
	var point: Vector2 = payload.get("point", anchor.get_center() if anchor.has_area() else _overlay.size * 0.5)
	_overlay.call("play_event", "touch_ripple", {"point": point, "to_rect": anchor})


func play_phase_sweep() -> void:
	if bool(GameManager.battle_effects_enabled) and _prepare_overlay():
		_overlay.call("play_event", "phase_sweep", {})


func play_field_movement(movement: Dictionary) -> void:
	if not bool(GameManager.battle_effects_enabled) or not _prepare_overlay():
		return
	var played := false
	for move_variant: Variant in movement.get("moves", []):
		if not move_variant is Dictionary:
			continue
		var move: Dictionary = move_variant
		var from_view := _find_slot_view(str(move.get("from_slot_id", "")))
		var to_view := _find_slot_view(str(move.get("to_slot_id", "")))
		var from_rect := _control_rect(from_view) if from_view != null else Rect2()
		var to_rect := _control_rect(to_view) if to_view != null else Rect2()
		_overlay.call("play_event", "retreat_swap", {"from_rect": from_rect, "to_rect": to_rect})
		played = true
	if played:
		_record_combo({"to_rect": _resolve_target_rect({"anchor_key": "my_active"})})


func _prepare_overlay() -> bool:
	if _scene == null or not is_instance_valid(_scene):
		return false
	_ensure_overlay()
	return _overlay != null and is_instance_valid(_overlay)


func _record_combo(payload: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	_combo_level = mini(4, _combo_level + 1) if now - _last_success_msec <= 2400 else 1
	_last_success_msec = now
	var combo_payload := payload.duplicate(true)
	combo_payload["level"] = _combo_level
	_overlay.call("play_event", "combo_cadence", combo_payload)


func _should_suppress() -> bool:
	if _scene == null:
		return true
	for method_name: String in ["_is_review_mode", "_is_field_interaction_active", "_is_ai_action_pause_active"]:
		if _scene.has_method(method_name) and bool(_scene.call(method_name)):
			return true
	if bool(_scene.get("_draw_reveal_active")) or bool(_scene.get("_ai_llm_waiting")):
		return true
	if _scene.has_method("_can_accept_live_action") and not bool(_scene.call("_can_accept_live_action")):
		return true
	return false


func _ensure_overlay() -> void:
	if _scene == null or not is_instance_valid(_scene):
		return
	if _overlay != null and is_instance_valid(_overlay):
		return
	var existing := _scene.get_node_or_null("BattleActionIntentOverlay") as Control
	if existing != null:
		_overlay = existing
		return
	_overlay = IntentOverlay.new()
	_overlay.name = "BattleActionIntentOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_as_relative = false
	_overlay.z_index = 260
	_scene.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _apply_model_to_overlay() -> void:
	# Keep the board visually quiet until the player expresses an intent.
	# Idle legality remains in the model for rule feedback, but usable hand cards,
	# Stadiums, and Pokemon actions must not become persistent screen-wide hints.
	var actionables: Array[Dictionary] = []

	var source_rect := Rect2()
	var source_id := str(_model.get("source_card_instance_id", ""))
	if source_id != "":
		var source_view := _find_hand_view(source_id)
		if source_view != null:
			source_rect = _hand_card_rect(source_view)
	var targets: Array[Dictionary] = []
	var target_index := 0
	for slot_id: String in _model.get("target_slot_ids", []):
		var target_view := _find_slot_view(slot_id)
		if target_view != null:
			targets.append({"rect": _control_rect(target_view), "label": "", "index": target_index})
			target_index += 1
	var selected := _scene.get("_selected_hand_card") as CardInstance
	_overlay.call("set_visuals", actionables, source_rect, targets, {
		"intent_kind": _intent_kind_for_card(selected),
		"attribute_color": _attribute_color_for_card(selected),
	})


func _sync_low_hp_hazards(gsm: GameStateMachine, view_player: int) -> void:
	var hazards: Array[Dictionary] = []
	if gsm == null or gsm.game_state == null or view_player < 0 or view_player >= gsm.game_state.players.size():
		_overlay.call("set_low_hp_hazards", hazards)
		return
	var player: PlayerState = gsm.game_state.players[view_player]
	var entries: Array[Dictionary] = []
	if player.active_pokemon != null:
		entries.append({"slot_id": "my_active", "slot": player.active_pokemon})
	for bench_index: int in player.bench.size():
		entries.append({"slot_id": "my_bench_%d" % bench_index, "slot": player.bench[bench_index]})
	for entry: Dictionary in entries:
		var slot := entry.get("slot") as PokemonSlot
		if slot == null:
			continue
		var max_hp := slot.get_max_hp()
		var remaining := slot.get_remaining_hp()
		if max_hp <= 0 or remaining <= 0 or float(remaining) / float(max_hp) > 0.3:
			continue
		var view := _find_slot_view(str(entry.get("slot_id", "")))
		if view != null:
			hazards.append({"rect": _control_rect(view), "ratio": float(remaining) / float(max_hp)})
	_overlay.call("set_low_hp_hazards", hazards)


func _maybe_play_phase_sweep(gsm: GameStateMachine, view_player: int) -> void:
	if gsm == null or gsm.game_state == null:
		return
	var phase := int(gsm.game_state.phase)
	var turn := int(gsm.game_state.turn_number)
	if (
		_last_phase >= 0
		and phase == int(GameState.GamePhase.MAIN)
		and (_last_phase != phase or _last_turn != turn or _last_view_player != view_player)
	):
		play_phase_sweep()
	_last_phase = phase
	_last_turn = turn
	_last_view_player = view_player


func _track_phase(gsm: GameStateMachine, view_player: int) -> void:
	if gsm == null or gsm.game_state == null:
		return
	_last_phase = int(gsm.game_state.phase)
	_last_turn = int(gsm.game_state.turn_number)
	_last_view_player = view_player


func _attribute_color_for_card(card: CardInstance) -> Color:
	if card == null or card.card_data == null:
		return Color(0.21, 0.92, 0.82, 0.95)
	return VfxCatalog.attribute_color(card.card_data.energy_type)


func _intent_kind_for_card(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	var data: CardData = card.card_data
	if data.card_type in ["Basic Energy", "Special Energy"]:
		return "energy"
	if data.card_type == "Tool":
		return "tool"
	if data.is_pokemon() and data.stage != "Basic":
		return "evolution"
	if data.is_pokemon():
		return "bench"
	return data.card_type.to_lower()


func _success_color(payload: Dictionary) -> Color:
	var source_id := str(payload.get("source_card_instance_id", ""))
	var source_view := _find_hand_view(source_id) if source_id != "" else null
	if source_view is BattleCardView:
		return _attribute_color_for_card((source_view as BattleCardView).card_instance)
	var target_key := str(payload.get("target_slot_id", payload.get("anchor_key", "")))
	var target_view := _find_slot_view(target_key) if target_key != "" else null
	if target_view is BattleCardView:
		return _attribute_color_for_card((target_view as BattleCardView).card_instance)
	return Color(1.0, 0.8, 0.24, 0.95)


func _resolve_source_rect(payload: Dictionary) -> Rect2:
	var source_id := str(payload.get("source_card_instance_id", payload.get("card_instance_id", "")))
	var source_view := _find_hand_view(source_id) if source_id != "" else null
	return _hand_card_rect(source_view) if source_view != null else Rect2()


func _resolve_target_rect(payload: Dictionary) -> Rect2:
	var target_key := str(payload.get("target_slot_id", payload.get("anchor_key", "")))
	var target_view := _find_slot_view(target_key) if target_key != "" else null
	if target_view != null:
		return _control_rect(target_view)
	var source_rect := _resolve_source_rect(payload)
	if source_rect.has_area():
		return source_rect
	return Rect2()


func _find_hand_view(instance_id: String) -> Control:
	var container := _scene.get("_hand_container") as Control
	if container == null:
		return null
	for child: Node in container.get_children():
		var view := child as BattleCardView
		if view != null and view.card_instance != null and str(view.card_instance.instance_id) == instance_id:
			return view
	return null


func _find_slot_view(slot_id: String) -> Control:
	var views: Dictionary = _scene.get("_slot_card_views")
	return views.get(slot_id) as Control


func _resolve_rejection_anchor(payload: Dictionary) -> Rect2:
	var anchor_key := str(payload.get("anchor_key", ""))
	if anchor_key != "":
		var slot_view := _find_slot_view(anchor_key)
		if slot_view != null:
			return _control_rect(slot_view)
	var instance_id := str(payload.get("card_instance_id", ""))
	if instance_id != "":
		var hand_view := _find_hand_view(instance_id)
		if hand_view != null:
			return _hand_card_rect(hand_view)
	var selected := _scene.get("_selected_hand_card") as CardInstance
	if selected != null:
		var selected_view := _find_hand_view(str(selected.instance_id))
		if selected_view != null:
			return _hand_card_rect(selected_view)
	var active_view := _find_slot_view("my_active")
	if active_view != null:
		return _control_rect(active_view)
	return Rect2(_overlay.size * 0.5 - Vector2(1, 1), Vector2(2, 2))


func _control_rect(control: Control) -> Rect2:
	return OverlayGeometry.control_rect_in_overlay(_overlay, control)


func _hand_card_rect(control: Control) -> Rect2:
	if control == null:
		return Rect2()
	var visible_size := control.custom_minimum_size
	if visible_size.x <= 0.0 or visible_size.y <= 0.0:
		return _control_rect(control)
	return OverlayGeometry.local_rect_in_overlay(
		_overlay,
		control,
		Rect2(Vector2.ZERO, visible_size)
	)
