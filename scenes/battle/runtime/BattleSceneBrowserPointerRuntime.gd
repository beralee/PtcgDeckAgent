## Browser pointer ownership, dynamic hand surfaces and card-gallery surfaces.
##
## This layer owns browser input compatibility and semantic surface lifecycles.
## The final BattleScene runtime keeps lifecycle/business wiring while this
## module keeps pointer state machines out of that already broad facade.
extends "res://scenes/battle/runtime/BattleSceneDialogInteractionReviewRuntime.gd"

const PointerGeometryScript := preload("res://scripts/ui/input/PointerGeometry.gd")
const PointerGesturePolicyScript := preload("res://scripts/ui/input/PointerGesturePolicy.gd")
const HAND_SURFACE_MAX_PROJECTION_REPAIRS := 2

var _ios_web_hand_touch_active_card: BattleCardView = null
var _ios_web_hand_touch_index: int = -1
var _hand_pointer_surface_signature: String = ""
var _hand_surface_layout_transaction: Dictionary = {}
var _hand_surface_integrity_serial: int = 0
var _hand_surface_integrity_repair_generation: int = -1
var _hand_surface_integrity_repair_attempts: int = 0


func _observe_battle_pointer_event(event: InputEvent) -> Dictionary:
	if _battle_pointer_input_router == null:
		return {}
	return _battle_pointer_input_router.observe(event)


func _configure_battle_pointer_input_for_tests(merge_touch_mouse_echo: bool) -> void:
	if _battle_pointer_input_router != null:
		_battle_pointer_input_router.configure(merge_touch_mouse_echo)


func _configure_battle_pointer_surface_for_tests(enabled: bool) -> void:
	_battle_pointer_surface_test_override = 1 if enabled else 0
	if _battle_pointer_surface_controller != null:
		_battle_pointer_surface_controller.configure(
			_battle_pointer_input_router,
			enabled
		)


func _configure_battle_pointer_runtime(
	runtime_profile: UiRuntimeProfile
) -> void:
	if _battle_pointer_input_router != null:
		_battle_pointer_input_router.configure(
			runtime_profile != null
			and (
				runtime_profile.mobile_like
				or runtime_profile.is_web()
			)
		)
	if _battle_pointer_surface_controller == null:
		return
	var enabled := false
	if runtime_profile != null and runtime_profile.prefers_touch():
		if runtime_profile.is_native() and runtime_profile.mobile_like:
			enabled = true
		elif (
			runtime_profile.is_web()
			and WebUiFeatureGateScript.web_input_adapter_v2_enabled(runtime_profile)
		):
			enabled = true
	if _battle_pointer_surface_test_override >= 0:
		enabled = _battle_pointer_surface_test_override == 1
	_battle_pointer_surface_controller.configure(
		_battle_pointer_input_router,
		enabled
	)


func _claim_modal_pointer_event(event: InputEvent, intent: String) -> bool:
	if _battle_pointer_input_router == null:
		return false
	return _battle_pointer_input_router.claim_event(event, intent, "battle_modal")


func _claim_current_modal_pointer_sequence(intent: String) -> bool:
	if _battle_pointer_input_router == null:
		return false
	return _battle_pointer_input_router.claim_current(intent, "battle_modal")


func _register_ios_web_hud_touch_root(root: Node) -> void:
	IosWebHudTouchAdapterScript.mark_hud_root(root)


func _register_ios_web_hud_touch_surface(root: Node) -> void:
	IosWebHudTouchAdapterScript.mark_hud_surface(root)


func _uses_ios_web_hand_touch_profile() -> bool:
	return (
		_ios_web_hud_touch_adapter != null
		and _ios_web_hud_touch_adapter.is_enabled()
	)


func _register_existing_ios_web_hud_button_surfaces() -> void:
	for node: Node in find_children("*", "", true, false):
		var button := node as BaseButton
		if button == null or _has_ios_web_hud_touch_root_ancestor(button):
			continue
		_register_ios_web_hud_touch_surface(button)


func _has_ios_web_hud_touch_root_ancestor(node: Node) -> bool:
	var cursor := node
	while cursor != null:
		if bool(cursor.get_meta(IosWebHudTouchAdapterScript.HUD_TOUCH_ROOT_META, false)):
			return true
		if cursor == self:
			break
		cursor = cursor.get_parent()
	return false


func _try_handle_ios_web_hud_touch_input(event: InputEvent) -> bool:
	if (
		_ios_web_hud_touch_adapter == null
		or not _ios_web_hud_touch_adapter.handle_event(self, event)
	):
		return false
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		var candidate := _ios_web_hud_touch_adapter.current_candidate_button()
		if candidate == _dialog_confirm:
			_battle_dialog_controller.call(
				"on_dialog_action_button_input",
				self,
				"confirm",
				event
			)
		elif candidate == _dialog_cancel:
			_battle_dialog_controller.call(
				"on_dialog_action_button_input",
				self,
				"cancel",
				event
			)
		else:
			_claim_modal_pointer_event(event, "ios_web_hud_button")
	return true


func _try_handle_ios_web_hand_card_touch_input(event: InputEvent) -> bool:
	if not _uses_ios_web_hand_touch_profile():
		_clear_ios_web_hand_touch_bridge()
		return false
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return false
	if _ios_web_hand_touch_bridge_blocked_by_overlay():
		_clear_ios_web_hand_touch_bridge()
		return false
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_clear_ios_web_hand_touch_bridge()
			var pressed_card := _battle_hand_card_at_screen_position(touch.position)
			if pressed_card == null:
				return false
			_ios_web_hand_touch_active_card = pressed_card
			_ios_web_hand_touch_index = touch.index
			_forward_ios_web_hand_card_touch_event(pressed_card, event)
			return true
		if (
			_ios_web_hand_touch_active_card == null
			or touch.index != _ios_web_hand_touch_index
		):
			return false
		var release_card := _ios_web_hand_touch_active_card
		_clear_ios_web_hand_touch_bridge()
		if release_card == null or not is_instance_valid(release_card):
			return true
		_forward_ios_web_hand_card_touch_event(release_card, event)
		return true
	var drag := event as InputEventScreenDrag
	if (
		_ios_web_hand_touch_active_card == null
		or drag.index != _ios_web_hand_touch_index
	):
		return false
	var active_card := _ios_web_hand_touch_active_card
	if not is_instance_valid(active_card):
		_clear_ios_web_hand_touch_bridge()
		return true
	_forward_ios_web_hand_card_touch_event(active_card, event)
	return true


func _ios_web_hand_touch_bridge_blocked_by_overlay() -> bool:
	if _is_board_modal_overlay_visible():
		return true
	if _draw_reveal_active or _portrait_prize_dialog_active:
		return true
	if _portrait_actions_popup != null and _portrait_actions_popup.visible:
		return true
	return _stadium_card_overlay != null and _stadium_card_overlay.visible


func _clear_ios_web_hand_touch_bridge() -> void:
	_ios_web_hand_touch_active_card = null
	_ios_web_hand_touch_index = -1


func _prepare_ios_web_hand_rebuild(reason: String = "hand_rebuild") -> void:
	if not _uses_ios_web_hand_touch_profile():
		return
	_clear_ios_web_hand_touch_bridge()
	if _battle_drag_scroll_coordinator != null:
		_battle_drag_scroll_coordinator.call(
			"clear_hand_drag_click_suppression",
			"ios_web_%s" % reason
		)
	if _battle_pointer_input_router != null:
		_battle_pointer_input_router.cancel_all("ios_web_%s" % reason)
	if _web_battle_input_adapter != null:
		_web_battle_input_adapter.cancel_all("ios_web_%s" % reason)


func _reconcile_hand_pointer_surface(signature: String) -> int:
	if _battle_pointer_surface_controller == null:
		return 0
	var signature_changed := signature != _hand_pointer_surface_signature
	var scroll_snapshot: Dictionary = {}
	if (
		signature_changed
		and _battle_drag_scroll_coordinator != null
		and _hand_scroll != null
	):
		scroll_snapshot = _battle_drag_scroll_coordinator.call(
			"capture_hand_drag_scroll_anchor",
			_hand_scroll
		)
	var previous_signature := _hand_pointer_surface_signature
	var runtime_profile: UiRuntimeProfile = (
		GameManager.get_ui_runtime_profile()
		if GameManager != null
		and GameManager.has_method("get_ui_runtime_profile")
		else null
	)
	_configure_battle_pointer_runtime(runtime_profile)
	var previous_generation := _hand_pointer_surface_generation
	var generation: int = _battle_pointer_surface_controller.reconcile_surface(
		"hand",
		signature,
		{
			"contains": Callable(self, "_hand_pointer_surface_contains"),
			"target_at": Callable(self, "_hand_pointer_surface_target_at"),
			"activate": Callable(self, "_activate_hand_pointer_surface_target"),
			"has_horizontal_overflow": Callable(self, "_hand_pointer_surface_has_overflow"),
			"get_horizontal_scroll": Callable(self, "_hand_pointer_surface_scroll"),
			"set_horizontal_scroll": Callable(self, "_set_hand_pointer_surface_scroll"),
			"horizontal_tap_tolerance": PointerGesturePolicyScript.BROWSER_TOUCH_HORIZONTAL_TAP_TOLERANCE,
			"vertical_tap_tolerance": PointerGesturePolicyScript.BROWSER_TOUCH_VERTICAL_TAP_TOLERANCE,
			"horizontal_drag_threshold": PointerGesturePolicyScript.HORIZONTAL_DRAG_SLOP,
		}
	)
	_hand_pointer_surface_generation = generation
	if generation != previous_generation:
		var added_instance_ids := _hand_surface_added_instance_ids(
			previous_signature,
			signature
		)
		_hand_pointer_surface_signature = signature
		_hand_surface_layout_transaction = {
			"generation": generation,
			"signature": signature,
			"scroll_snapshot": scroll_snapshot,
			"focus_instance_ids": added_instance_ids,
		}
		_hand_surface_integrity_repair_generation = generation
		_hand_surface_integrity_repair_attempts = 0
		_clear_ios_web_hand_touch_bridge()
		if _battle_drag_scroll_coordinator != null:
			_battle_drag_scroll_coordinator.call(
				"clear_hand_drag_click_suppression",
				"hand_surface_generation_%d" % generation
			)
		var browser_hand_path_active := (
			(
				_battle_pointer_surface_controller != null
				and _battle_pointer_surface_controller.is_enabled()
			)
			or _uses_ios_web_hand_touch_profile()
		)
		if browser_hand_path_active and _battle_pointer_input_router != null:
			_battle_pointer_input_router.cancel_all(
				"hand_surface_generation_%d" % generation
			)
		if browser_hand_path_active and _web_battle_input_adapter != null:
			_web_battle_input_adapter.cancel_all(
				"hand_surface_generation_%d" % generation
			)
	else:
		_hand_pointer_surface_signature = signature
	return generation


func _commit_hand_pointer_surface_layout(generation: int) -> void:
	call_deferred("_deferred_commit_hand_pointer_surface_layout", generation)


func _deferred_commit_hand_pointer_surface_layout(generation: int) -> void:
	if not is_inside_tree() or generation != _hand_pointer_surface_generation:
		return
	if _hand_container != null:
		_hand_container.update_minimum_size()
	if _battle_drag_scroll_coordinator != null and _hand_scroll != null:
		var transaction := _hand_surface_layout_transaction
		if int(transaction.get("generation", -1)) != generation:
			transaction = {
				"generation": generation,
				"signature": _hand_pointer_surface_signature,
				"scroll_snapshot": _battle_drag_scroll_coordinator.call(
					"capture_hand_drag_scroll_anchor",
					_hand_scroll
				),
				"focus_instance_ids": [],
			}
			_hand_surface_layout_transaction = transaction
		_battle_drag_scroll_coordinator.call(
			"restore_hand_drag_scroll_anchor",
			_hand_scroll,
			transaction.get("scroll_snapshot", {}),
			transaction.get("focus_instance_ids", [])
		)
	_schedule_hand_surface_integrity_check(
		generation,
		str(_hand_surface_layout_transaction.get(
			"signature",
			_hand_pointer_surface_signature
		)),
		_hand_surface_layout_transaction.get("focus_instance_ids", [])
	)


func _schedule_hand_surface_integrity_check(
	generation: int,
	signature: String,
	focus_instance_ids: Array
) -> void:
	if not is_inside_tree():
		return
	_hand_surface_integrity_serial += 1
	_run_hand_surface_integrity_check(
		generation,
		signature,
		focus_instance_ids.duplicate(),
		_hand_surface_integrity_serial
	)


func _run_hand_surface_integrity_check(
	generation: int,
	signature: String,
	focus_instance_ids: Array,
	serial: int
) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	# Validate twice on consecutive frames. The first sample covers the layout
	# commit; the second covers deferred portrait/modal teardown that used to
	# leave the hand stale until the next unrelated card action.
	for _sample: int in 2:
		await tree.process_frame
		if (
			not is_inside_tree()
			or serial != _hand_surface_integrity_serial
			or generation != _hand_pointer_surface_generation
		):
			return
		if not _hand_surface_projection_matches(signature, focus_instance_ids):
			_repair_hand_surface_projection(
				generation,
				signature,
				focus_instance_ids
			)
			return
	if int(_hand_surface_layout_transaction.get("generation", -1)) == generation:
		_hand_surface_layout_transaction.clear()


func _repair_hand_surface_projection(
	generation: int,
	signature: String,
	focus_instance_ids: Array
) -> void:
	if _hand_surface_integrity_repair_generation != generation:
		_hand_surface_integrity_repair_generation = generation
		_hand_surface_integrity_repair_attempts = 0
	if _hand_surface_integrity_repair_attempts >= HAND_SURFACE_MAX_PROJECTION_REPAIRS:
		push_warning(
			"Hand surface projection remained inconsistent after %d repairs: %s" % [
				HAND_SURFACE_MAX_PROJECTION_REPAIRS,
				signature,
			]
		)
		return
	_hand_surface_integrity_repair_attempts += 1
	_hand_surface_layout_transaction = {
		"generation": generation,
		"signature": signature,
		"scroll_snapshot": (
			_battle_drag_scroll_coordinator.call(
				"capture_hand_drag_scroll_anchor",
				_hand_scroll
			)
			if _battle_drag_scroll_coordinator != null and _hand_scroll != null
			else {}
		),
		"focus_instance_ids": focus_instance_ids.duplicate(),
	}
	_runtime_log(
		"hand_surface_projection_repair",
		"generation=%d attempt=%d signature=%s" % [
			generation,
			_hand_surface_integrity_repair_attempts,
			signature,
		]
	)
	# This is intentionally the same idempotent projection path used by normal
	# UI refreshes. It cannot mutate GameState or advance the semantic generation.
	_refresh_hand()


func _hand_surface_projection_matches(
	signature: String,
	focus_instance_ids: Array
) -> bool:
	if _hand_container == null or _hand_scroll == null:
		return false
	var parsed := _parse_hand_surface_signature(signature)
	var expected_ids: Array = parsed.get("instance_ids", [])
	var rendered_ids: Array[int] = []
	for child: Node in _hand_container.get_children():
		var card_view := child as BattleCardView
		if card_view != null and card_view.card_instance != null:
			rendered_ids.append(card_view.card_instance.instance_id)
	if rendered_ids != expected_ids:
		return false
	if _battle_drag_scroll_coordinator == null:
		return true
	return bool(_battle_drag_scroll_coordinator.call(
		"hand_drag_projection_layout_is_sane",
		_hand_scroll,
		focus_instance_ids
	))


func _hand_surface_added_instance_ids(
	previous_signature: String,
	current_signature: String
) -> Array[int]:
	var previous := _parse_hand_surface_signature(previous_signature)
	var current := _parse_hand_surface_signature(current_signature)
	if (
		str(previous.get("mode", "")) != "cards"
		or str(current.get("mode", "")) != "cards"
	):
		return []
	var previous_ids: Array = previous.get("instance_ids", [])
	var added_ids: Array[int] = []
	for raw_id: Variant in current.get("instance_ids", []):
		var instance_id := int(raw_id)
		if instance_id not in previous_ids:
			added_ids.append(instance_id)
	return added_ids


func _parse_hand_surface_signature(signature: String) -> Dictionary:
	var separator := signature.find("|")
	var mode := signature if separator < 0 else signature.substr(0, separator)
	var encoded_ids := "" if separator < 0 else signature.substr(separator + 1)
	var instance_ids: Array[int] = []
	if encoded_ids != "":
		for encoded_id: String in encoded_ids.split(",", false):
			instance_ids.append(int(encoded_id))
	return {
		"mode": mode,
		"instance_ids": instance_ids,
	}


func _try_handle_web_pointer_surface_input(
	event: InputEvent,
	pointer_observation: Dictionary
) -> bool:
	if (
		_battle_pointer_surface_controller == null
		or not _battle_pointer_surface_controller.is_enabled()
	):
		return false
	var debug_relevant := _hand_surface_debug_event_relevant(event)
	if debug_relevant:
		_debug_hand_surface_pointer_event(
			"before_surface",
			event,
			pointer_observation,
			false,
			false
		)
	var handled := bool(_battle_pointer_surface_controller.handle_event(
		event,
		pointer_observation
	))
	if handled:
		if debug_relevant:
			_debug_hand_surface_pointer_event(
				"after_surface",
				event,
				pointer_observation,
				true,
				false
			)
		return true
	var swallowed_echo := _should_swallow_hand_surface_companion_motion(
		event,
		pointer_observation
	)
	if debug_relevant or swallowed_echo:
		_debug_hand_surface_pointer_event(
			"after_surface",
			event,
			pointer_observation,
			false,
			swallowed_echo
		)
	return swallowed_echo


func _should_swallow_hand_surface_companion_motion(
	event: InputEvent,
	pointer_observation: Dictionary
) -> bool:
	if not _hand_surface_has_active_gesture():
		return false
	if pointer_observation.get("sequence", null) != null:
		return false
	var phase := str(pointer_observation.get("phase", ""))
	# Native Android emits both MouseMotion and ScreenDrag for one physical
	# sample. Which half arrives first varies by device/driver. The router makes
	# the first half canonical; the companion can therefore appear either as a
	# button-held mouse_hover or as an orphan touch drag. Once the semantic hand
	# Surface owns the physical gesture, neither companion may escape to the
	# legacy hand dragger and become a second scroll writer.
	if event is InputEventMouseMotion and phase == "mouse_hover":
		var motion := event as InputEventMouseMotion
		return (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if event is InputEventScreenDrag:
		return phase in ["orphan_touch_drag", "inactive_touch_drag"]
	return false


func _hand_surface_debug_event_relevant(event: InputEvent) -> bool:
	if not _hand_surface_debug_enabled():
		return false
	if _hand_surface_has_active_gesture():
		return true
	return _hand_pointer_surface_contains(_hand_surface_event_position(event))


func _hand_surface_debug_enabled() -> bool:
	return (
		_battle_drag_scroll_coordinator != null
		and bool(_battle_drag_scroll_coordinator.call(
			"debug_hand_drag_scroll_enabled"
		))
	)


func _hand_surface_has_active_gesture() -> bool:
	if _battle_pointer_surface_controller == null:
		return false
	for snapshot_variant: Variant in _battle_pointer_surface_controller.active_snapshots():
		var snapshot: Dictionary = snapshot_variant
		if str(snapshot.get("surface_id", "")) == "hand":
			return true
	return false


func _debug_hand_surface_pointer_event(
	stage: String,
	event: InputEvent,
	pointer_observation: Dictionary,
	handled: bool,
	swallowed_echo: bool
) -> void:
	if not _hand_surface_debug_enabled():
		return
	var sequence_variant: Variant = pointer_observation.get("sequence", null)
	var sequence_text := "<none>"
	if sequence_variant is PointerSequence:
		sequence_text = str((sequence_variant as PointerSequence).snapshot())
	var hand_snapshots: Array[Dictionary] = []
	if _battle_pointer_surface_controller != null:
		for snapshot_variant: Variant in _battle_pointer_surface_controller.active_snapshots():
			var snapshot: Dictionary = snapshot_variant
			if str(snapshot.get("surface_id", "")) == "hand":
				hand_snapshots.append(snapshot)
	_battle_drag_scroll_coordinator.call(
		"debug_hand_drag_scroll",
		"surface-event stage=%s type=%s device=%d pos=%s relative=%s pressed=%s phase=%s deliver=%s synthetic=%s handled=%s swallowed_echo=%s sequence=%s gestures=%s %s" % [
			stage,
			event.get_class(),
			event.device,
			str(_hand_surface_event_position(event)),
			str(_hand_surface_event_relative(event)),
			str(_hand_surface_event_pressed(event)),
			str(pointer_observation.get("phase", "")),
			str(pointer_observation.get("deliver", true)),
			str(pointer_observation.get("synthetic", false)),
			str(handled),
			str(swallowed_echo),
			sequence_text,
			str(hand_snapshots),
			_hand_surface_geometry_debug_text(),
		]
	)


func _hand_surface_event_position(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		return button.global_position if button.global_position != Vector2.ZERO else button.position
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		return motion.global_position if motion.global_position != Vector2.ZERO else motion.position
	return Vector2.ZERO


func _hand_surface_event_relative(event: InputEvent) -> Vector2:
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).relative
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).relative
	return Vector2.ZERO


func _hand_surface_event_pressed(event: InputEvent) -> Variant:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	return "n/a"


func _hand_surface_geometry_debug_text() -> String:
	if _hand_scroll == null:
		return "scroll=<null>"
	var bar := _hand_scroll.get_h_scroll_bar()
	var range_text := "bar=<null>"
	if bar != null:
		range_text = "bar(value=%.1f,min=%.1f,max=%.1f,page=%.1f)" % [
			bar.value,
			bar.min_value,
			bar.max_value,
			bar.page,
		]
	var content_text := "content=<null>"
	if _hand_container != null:
		content_text = "content(pos=%s,global=%s,size=%s,min=%s,combined=%s,children=%d)" % [
			str(_hand_container.position),
			str(_hand_container.global_position),
			str(_hand_container.size),
			str(_hand_container.custom_minimum_size),
			str(_hand_container.get_combined_minimum_size()),
			_hand_container.get_child_count(),
		]
	return "scroll=%d scroll_size=%s %s %s" % [
		_hand_scroll.scroll_horizontal,
		str(_hand_scroll.size),
		range_text,
		content_text,
	]


func _hand_pointer_surface_contains(screen_position: Vector2) -> bool:
	return (
		not _ios_web_hand_touch_bridge_blocked_by_overlay()
		and _hand_scroll != null
		and _hand_scroll.visible
		and PointerGeometryScript.control_visible_viewport_point(
			_hand_scroll,
			screen_position
		)
	)


func _hand_pointer_surface_target_at(screen_position: Vector2) -> Variant:
	var card_view := _battle_hand_card_at_screen_position(screen_position)
	if card_view == null or card_view.card_instance == null:
		return null
	return card_view.card_instance.instance_id


func _activate_hand_pointer_surface_target(
	target_key: Variant,
	generation: int
) -> void:
	if generation != _hand_pointer_surface_generation or _gsm == null:
		return
	var target_instance_id := int(target_key)
	var player_index := _view_player
	if (
		player_index < 0
		or player_index >= _gsm.game_state.players.size()
	):
		return
	for inst: CardInstance in _gsm.game_state.players[player_index].hand:
		if inst != null and inst.instance_id == target_instance_id:
			_show_hand_card_detail(inst)
			return


func _hand_pointer_surface_has_overflow() -> bool:
	if _hand_scroll == null:
		return false
	var bar := _hand_scroll.get_h_scroll_bar()
	if (
		bar != null
		and bar.page > 0.5
		and bar.max_value > bar.page + 0.5
	):
		return true
	return _pointer_surface_max_scroll(_hand_scroll, _hand_container) > 0


func _hand_pointer_surface_scroll() -> int:
	return _hand_scroll.scroll_horizontal if _hand_scroll != null else 0


func _set_hand_pointer_surface_scroll(value: int) -> void:
	if _hand_scroll == null:
		return
	var before_scroll := _hand_scroll.scroll_horizontal
	var bar := _hand_scroll.get_h_scroll_bar()
	var max_scroll := 0
	if bar != null:
		max_scroll = maxi(0, roundi(bar.max_value - bar.page))
	var geometry_max_scroll := _pointer_surface_max_scroll(
		_hand_scroll,
		_hand_container
	)
	max_scroll = maxi(max_scroll, geometry_max_scroll)
	_ensure_pointer_surface_scroll_range(
		_hand_scroll,
		bar,
		geometry_max_scroll
	)
	var clamped_value := clampi(value, 0, max_scroll)
	_hand_scroll.scroll_horizontal = clamped_value
	if _hand_surface_debug_enabled():
		_battle_drag_scroll_coordinator.call(
			"debug_hand_drag_scroll",
			"surface-write requested=%d clamped=%d before=%d after=%d bar_max=%d geometry_max=%d %s" % [
				value,
				clamped_value,
				before_scroll,
				_hand_scroll.scroll_horizontal,
				max_scroll,
				geometry_max_scroll,
				_hand_surface_geometry_debug_text(),
			]
		)


func _forward_ios_web_hand_card_touch_event(card_view: BattleCardView, event: InputEvent) -> void:
	if card_view == null or not is_instance_valid(card_view):
		return
	if not card_view.has_method("handle_bridged_pointer_input"):
		return
	card_view.call("handle_bridged_pointer_input", event)


func _battle_hand_card_at_screen_position(screen_position: Vector2) -> BattleCardView:
	if _hand_scroll == null or _hand_container == null:
		return null
	if not PointerGeometryScript.control_visible_viewport_point(_hand_scroll, screen_position):
		return null
	for child_index: int in range(_hand_container.get_child_count() - 1, -1, -1):
		var card_view := _hand_container.get_child(child_index) as BattleCardView
		if (
			card_view != null
			and PointerGeometryScript.control_visible_viewport_point(card_view, screen_position)
		):
			return card_view
	return null


func _deferred_sync_card_gallery_pointer_surface(
	scroll: ScrollContainer
) -> void:
	if (
		scroll == null
		or not is_instance_valid(scroll)
		or not bool(scroll.get_meta("card_gallery_drag_scroll_active", false))
	):
		return
	_sync_card_gallery_pointer_surface(scroll)


func _sync_card_gallery_pointer_surface(scroll: ScrollContainer) -> void:
	if scroll == null or _battle_pointer_surface_controller == null:
		return
	if not scroll.has_meta("card_gallery_drag_row_control"):
		return
	var row := scroll.get_meta(
		"card_gallery_drag_row_control",
		null
	) as Control
	if row == null or not is_instance_valid(row):
		return
	var surface_id := _card_gallery_pointer_surface_id(scroll)
	var signature := _card_gallery_pointer_signature(row)
	_battle_pointer_surface_controller.reconcile_surface(
		surface_id,
		signature,
		{
			"contains": Callable(
				self,
				"_card_gallery_pointer_contains"
			).bind(scroll),
			"target_at": Callable(
				self,
				"_card_gallery_pointer_target_at"
			).bind(row, scroll),
			"activate": Callable(
				self,
				"_activate_card_gallery_pointer_target"
			).bind(row),
			"has_horizontal_overflow": Callable(
				self,
				"_card_gallery_pointer_has_overflow"
			).bind(scroll),
			"get_horizontal_scroll": Callable(
				self,
				"_card_gallery_pointer_scroll"
			).bind(scroll),
			"set_horizontal_scroll": Callable(
				self,
				"_set_card_gallery_pointer_scroll"
			).bind(scroll),
			"horizontal_tap_tolerance": PointerGesturePolicyScript.BROWSER_TOUCH_HORIZONTAL_TAP_TOLERANCE,
			"vertical_tap_tolerance": PointerGesturePolicyScript.BROWSER_TOUCH_VERTICAL_TAP_TOLERANCE,
			"horizontal_drag_threshold": PointerGesturePolicyScript.HORIZONTAL_DRAG_SLOP,
		}
	)


func _card_gallery_pointer_surface_id(scroll: ScrollContainer) -> String:
	return "gallery:%d" % scroll.get_instance_id()


func _card_gallery_pointer_signature(row: Control) -> String:
	var card_ids: Array[String] = []
	_collect_card_gallery_pointer_ids(row, card_ids)
	return "cards|%s" % ",".join(card_ids)


func _collect_card_gallery_pointer_ids(
	node: Node,
	card_ids: Array[String]
) -> void:
	for child: Node in node.get_children():
		if child is BattleCardView:
			card_ids.append(str(child.get_instance_id()))
		else:
			_collect_card_gallery_pointer_ids(child, card_ids)


func _card_gallery_pointer_contains(
	screen_position: Vector2,
	scroll: ScrollContainer
) -> bool:
	if (
		scroll == null
		or not is_instance_valid(scroll)
		or not scroll.visible
		or not bool(scroll.get_meta("card_gallery_drag_scroll_active", false))
		or not PointerGeometryScript.control_visible_viewport_point(
			scroll,
			screen_position
		)
	):
		return false
	for scrollbar: ScrollBar in [
		scroll.get_h_scroll_bar(),
		scroll.get_v_scroll_bar(),
	]:
		if (
			scrollbar != null
			and scrollbar.visible
			and PointerGeometryScript.control_visible_viewport_point(
				scrollbar,
				screen_position
			)
		):
			return false
	return true


func _card_gallery_pointer_target_at(
	screen_position: Vector2,
	row: Control,
	scroll: ScrollContainer
) -> Variant:
	if not _card_gallery_pointer_contains(screen_position, scroll):
		return null
	var card_view := _card_gallery_pointer_card_at(
		row,
		screen_position,
		scroll
	)
	return card_view.get_instance_id() if card_view != null else null


func _card_gallery_pointer_card_at(
	node: Node,
	screen_position: Vector2,
	clip_control: Control
) -> BattleCardView:
	for child_index: int in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(child_index)
		var nested := _card_gallery_pointer_card_at(
			child,
			screen_position,
			clip_control
		)
		if nested != null:
			return nested
	var card_view := node as BattleCardView
	if card_view == null:
		return null
	if not PointerGeometryScript.control_visible_viewport_point(
		clip_control,
		screen_position
	):
		return null
	return (
		card_view
		if PointerGeometryScript.control_visible_viewport_point(
			card_view,
			screen_position
		)
		else null
	)


func _activate_card_gallery_pointer_target(
	target_key: Variant,
	_generation: int,
	row: Control
) -> void:
	if row == null or not is_instance_valid(row):
		return
	var card_view := _card_gallery_pointer_card_by_id(
		row,
		int(target_key)
	)
	if card_view != null:
		card_view.activate_primary_click()


func _card_gallery_pointer_card_by_id(
	node: Node,
	target_id: int
) -> BattleCardView:
	if node is BattleCardView and node.get_instance_id() == target_id:
		return node as BattleCardView
	for child: Node in node.get_children():
		var nested := _card_gallery_pointer_card_by_id(child, target_id)
		if nested != null:
			return nested
	return null


func _card_gallery_pointer_has_overflow(
	scroll: ScrollContainer
) -> bool:
	if scroll == null or not is_instance_valid(scroll):
		return false
	var bar := scroll.get_h_scroll_bar()
	if (
		bar != null
		and bar.page > 0.5
		and bar.max_value > bar.page + 0.5
	):
		return true
	var row := scroll.get_meta(
		"card_gallery_drag_row_control",
		null
	) as Control
	return _pointer_surface_max_scroll(scroll, row) > 0


func _pointer_surface_max_scroll(
	scroll: ScrollContainer,
	content: Control
) -> int:
	if scroll == null or content == null or not is_instance_valid(content):
		return 0
	var viewport_width := maxf(scroll.size.x, scroll.custom_minimum_size.x)
	if viewport_width <= 0.5:
		return 0
	var content_width := maxf(
		maxf(content.size.x, content.custom_minimum_size.x),
		content.get_combined_minimum_size().x
	)
	var measured_children_width := 0.0
	var visible_children := 0
	for child: Node in content.get_children():
		var child_control := child as Control
		if child_control == null or not child_control.visible:
			continue
		measured_children_width += maxf(
			maxf(child_control.size.x, child_control.custom_minimum_size.x),
			child_control.get_combined_minimum_size().x
		)
		visible_children += 1
	if visible_children > 1 and content is BoxContainer:
		measured_children_width += float(
			(content as BoxContainer).get_theme_constant("separation")
		) * float(visible_children - 1)
	content_width = maxf(content_width, measured_children_width)
	return maxi(0, ceili(content_width - viewport_width))


func _ensure_pointer_surface_scroll_range(
	scroll: ScrollContainer,
	bar: ScrollBar,
	geometry_max_scroll: int
) -> void:
	if scroll == null or bar == null or geometry_max_scroll <= 0:
		return
	var viewport_width := maxf(scroll.size.x, scroll.custom_minimum_size.x)
	if viewport_width <= 0.5:
		return
	if bar.max_value - bar.page >= float(geometry_max_scroll) - 0.5:
		return
	# ScrollContainer clamps scroll_horizontal through its internal bar. During
	# the layout frame after a hand rebuild or HUD opening, that bar can still
	# advertise the previous range. Prime it from live content geometry so the
	# first drag moves immediately; Godot may reconcile the same values later.
	bar.min_value = 0.0
	bar.max_value = viewport_width + float(geometry_max_scroll)
	bar.page = viewport_width


func _card_gallery_pointer_scroll(scroll: ScrollContainer) -> int:
	return (
		scroll.scroll_horizontal
		if scroll != null and is_instance_valid(scroll)
		else 0
	)


func _set_card_gallery_pointer_scroll(
	value: int,
	scroll: ScrollContainer
) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	var bar := scroll.get_h_scroll_bar()
	var max_scroll := (
		maxi(0, roundi(bar.max_value - bar.page))
		if bar != null
		else 0
	)
	var row := scroll.get_meta(
		"card_gallery_drag_row_control",
		null
	) as Control
	var geometry_max_scroll := _pointer_surface_max_scroll(scroll, row)
	max_scroll = maxi(max_scroll, geometry_max_scroll)
	_ensure_pointer_surface_scroll_range(scroll, bar, geometry_max_scroll)
	scroll.scroll_horizontal = clampi(value, 0, max_scroll)
