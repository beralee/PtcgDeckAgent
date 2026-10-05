## BattleScene
## Thin scene entry. The runtime implementation lives in BattleSceneRuntime.gd while the refactor keeps shrinking the scene shell.
extends "res://scenes/battle/BattleSceneRuntime.gd"
var _arena_input_generation := 0
var _arena_hand_drag: RefCounted
const Presentation := preload("res://scripts/ui/battle/BattlePresentation.gd")
var _arena_enabled := false
var _arena_hand_observer: RefCounted
var _arena_touch: RefCounted
var _arena_previous_canvas := Vector2i.ZERO

func _on_action_logged(action: GameAction) -> void:
	super._on_action_logged(action)
	# The battle owner binds every GSM, including asynchronous package startup
	# and replacement matches. Do not subscribe the presenter to a one-time GSM.
	var presenter := get_node_or_null("Arena3DPresenter")
	if presenter != null: presenter._on_action(action)

func _refresh_ui() -> void:
	super._refresh_ui()
	var presenter := get_node_or_null("Arena3DPresenter")
	if presenter != null: presenter.public_frame_dirty = true

func _notification(what: int) -> void:
	if _arena_enabled and is_node_ready() and what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		_cancel_transient_platform_input("arena_focus_lost")
	super._notification(what)

func _enqueue_battle_visual_action(action: GameAction) -> void:
	if action == null or _gsm == null or _gsm.game_state == null or _is_review_mode(): return
	var presenter := get_node_or_null("Arena3DPresenter")
	if presenter == null or _arena_hand_observer == null:
		super._enqueue_battle_visual_action(action)
		return
	# This executes at the original action-time boundary, before the old UI
	# refreshes the hand. Only anonymous public counts cross into presentation.
	var events: Array[Dictionary] = _arena_hand_observer.capture(action,_gsm.game_state,_view_player)
	presenter.motion.hand_transfer.enqueue(events)

func _battle_hand_card_at_screen_position(screen_position: Vector2) -> BattleCardView:
	var presenter := get_node_or_null("Arena3DPresenter")
	if presenter != null and presenter.hand_fan != null:
		return presenter.hand_fan.pick(screen_position)
	return super._battle_hand_card_at_screen_position(screen_position)

func _exit_tree() -> void:
	if _arena_hand_drag != null: _arena_hand_drag.cancel()
	_arena_hand_drag = null
	_arena_hand_observer = null
	if _arena_touch != null: _arena_touch.cancel()
	_arena_touch = null
	super._exit_tree()
	if _arena_previous_canvas != Vector2i.ZERO: get_tree().root.content_scale_size = _arena_previous_canvas
	if _arena_enabled: GameManager.call_deferred("apply_desktop_render_resolution_cap")

func _can_view_player_start_turn_action() -> bool:
	var presenter := get_node_or_null("Arena3DPresenter")
	if presenter != null and presenter.motion != null and presenter.motion.is_busy() and not presenter.motion.allows_live_actions_during_ability(): return false
	return super._can_view_player_start_turn_action()

func _has_active_attack_vfx() -> bool:
	var presenter := get_node_or_null("Arena3DPresenter")
	if presenter != null and presenter.motion != null and (presenter.motion.busy_time > 0 or not presenter.motion.reward_queue.is_empty()):
		return true
	return super._has_active_attack_vfx()

func _show_portrait_prize_dialog_if_needed() -> void:
	# The arena owns its prize picker. The legacy portrait popup would cover
	# the attack/reward choreography before the arena enables selection.
	if _arena_enabled:
		_close_portrait_prize_dialog()
		return
	super._show_portrait_prize_dialog_if_needed()

func _input(event: InputEvent) -> void:
	if preload("res://scripts/ui/GameModalDialog.gd").active_for(self) != null:
		return
	if _arena_enabled:
		if _arena_touch != null and _arena_touch.suppress_emulated_mouse(event):
			get_viewport().set_input_as_handled()
			return
		if _ios_web_hud_touch_adapter != null:
			_ios_web_hud_touch_adapter.configure(GameManager.get_ui_runtime_profile(),true)
		var observation := _observe_battle_pointer_event(event)
		if _update_modal_pointer_drain(event,observation) or bool(observation.get("synthetic_echo",false)):
			get_viewport().set_input_as_handled()
			return
		if _arena_touch != null and _arena_touch.handle(event):
			get_viewport().set_input_as_handled()
			return
		if _arena_hand_drag == null:
			_arena_hand_drag = preload("res://scenes/arena3d/ArenaHandDrag.gd").new()
			_arena_hand_drag.scene = self
		if _arena_hand_drag.handle(event):
			get_viewport().set_input_as_handled()
			return
	super._input(event)

func _apply_responsive_layout() -> void:
	super._apply_responsive_layout()
	if _arena_enabled:
		preload("res://scenes/arena3d/ArenaLayout.gd").apply(self,true)

func _current_resolved_battle_layout_mode(viewport_size: Vector2 = Vector2.ZERO) -> String:
	if not _arena_enabled: return super._current_resolved_battle_layout_mode(viewport_size)
	var available := viewport_size if viewport_size != Vector2.ZERO else get_viewport_rect().size
	return "portrait" if available.y > available.x else "landscape"

func _should_rotate_battle_canvas(viewport_size: Vector2, resolved_mode: String) -> bool:
	return false if _arena_enabled else super._should_rotate_battle_canvas(viewport_size,resolved_mode)

func _apply_battle_canvas_transform(rotate_canvas: bool, physical_size: Vector2, logical_size: Vector2) -> void:
	if _arena_enabled:
		super._apply_battle_canvas_transform(false,physical_size,physical_size)
	else:
		super._apply_battle_canvas_transform(rotate_canvas,physical_size,logical_size)

func _finalize_portrait_layout_constraints() -> void:
	if _arena_enabled: return
	super._finalize_portrait_layout_constraints()

func _on_viewport_size_changed() -> void:
	if is_queued_for_deletion() or not is_inside_tree(): return
	if _arena_touch != null: _arena_touch.cancel()
	if _arena_hand_drag != null: _arena_hand_drag.cancel()
	_apply_arena_canvas_size()
	super._on_viewport_size_changed()

func _apply_arena_canvas_size() -> void:
	if not _arena_enabled or DisplayServer.get_name() == "headless": return
	var window := get_tree().root
	var desired := preload("res://scenes/arena3d/ArenaPlatform.gd").canvas_size(window.size)
	if window.content_scale_size != desired: window.content_scale_size = desired

func _cancel_transient_platform_input(reason: String = "platform_cancel") -> void:
	if _arena_touch != null: _arena_touch.cancel()
	if _arena_hand_drag != null: _arena_hand_drag.cancel()
	var presenter := get_node_or_null("Arena3DPresenter")
	if presenter != null:
		presenter.down_slot = ""
		presenter.hand_fan.pointer_down = false
		presenter.hover_preview.hide()
	super._cancel_transient_platform_input(reason)

func _show_field_slot_choice(title: String, items: Array, data: Dictionary = {}) -> void:
	_arena_input_generation += 1
	super._show_field_slot_choice(title, items, data)

func _show_field_assignment_interaction(step: Dictionary) -> void:
	_arena_input_generation += 1
	super._show_field_assignment_interaction(step)

func _show_field_counter_distribution(step: Dictionary) -> void:
	_arena_input_generation += 1
	super._show_field_counter_distribution(step)

func _hide_field_interaction() -> void:
	_arena_input_generation += 1
	super._hide_field_interaction()

func _ready() -> void:
	_arena_previous_canvas = get_tree().root.content_scale_size
	_arena_enabled = Presentation.requested_3d()
	set_meta("arena3d_active", _arena_enabled)
	super._ready()
	if _arena_enabled:
		call_deferred("_install_arena3d")

func _install_arena3d() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or has_node("Arena3DPresenter"): return
	var presenter = load("res://scenes/arena3d/ArenaBattlePresenter.gd").new()
	add_child(presenter)
	# GUI picking follows sibling order, independently of the visual z_index.
	# Cover the old board but leave every HUD/modal above the arena for input.
	move_child(presenter, get_node("MainArea").get_index() + 1)
	presenter.setup(self)
	_arena_touch = preload("res://scenes/arena3d/ArenaTouchInput.gd").new()
	_arena_touch.scene = self
	_apply_arena_canvas_size()
	# 3D owns its character choreography and saved arena motion preference.
	# A legacy 2D effect setting must not silently disable the selected 3D field.
	GameManager.apply_desktop_render_resolution_cap()
	_arena_hand_observer = preload("res://scripts/ui/battle/visuals/ArenaHandEventBridge.gd").new()
	if _gsm != null and _gsm.game_state != null: _arena_hand_observer.prime(_gsm.game_state,_view_player)
	var commentary_preferences := preload("res://scripts/commentary/CommentaryPreferences.gd")
	if GameManager.current_mode in [GameManager.GameMode.VS_AI, GameManager.GameMode.VS_AUTHOR_STRATEGY_AI] and commentary_preferences.eligible(commentary_preferences.enabled(), Presentation.is_3d_scene(self), _is_review_mode(), DisplayServer.get_name() == "headless"):
		var commentary := preload("res://scripts/commentary/OpponentTalkController.gd").new()
		commentary.name = "OpponentTalk"
		add_child(commentary)
		commentary.setup(self, presenter, GameManager.get_llm_opponent_battle_review_api_config())

func _battle_hud_control_contains_touch(control: Control, screen_position: Vector2) -> bool:
	# Legacy HUD hit testing runs in _input before GUI picking. The transparent
	# 2D board still occupies layout space, but its old hit regions are inactive.
	if has_node("Arena3DPresenter") and is_instance_valid(control):
		var old_field := get_node("MainArea/CenterField/FieldArea")
		if old_field.is_ancestor_of(control):
			return false
	return super._battle_hud_control_contains_touch(control, screen_position)

func _try_handle_portrait_bench_play_input(event: InputEvent) -> bool:
	# The arena owns board picking. The inherited 2D fallback consumes modal
	# guard events before checking its board bounds, swallowing fresh HUD clicks.
	if _arena_enabled:
		return false
	return super._try_handle_portrait_bench_play_input(event)
