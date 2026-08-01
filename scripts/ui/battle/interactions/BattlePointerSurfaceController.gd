class_name BattlePointerSurfaceController
extends RefCounted

const STATE_PENDING_TAP := "pending_tap"
const STATE_SCROLLING := "scrolling"
const STATE_CANCELLED := "cancelled"
const OWNER_PREFIX := "battle_pointer_surface:"

var _router: RefCounted = null
var _enabled: bool = false
var _surfaces: Dictionary = {}
var _surface_order: Array[String] = []
var _active_gestures: Dictionary = {}
var _trace: Array[Dictionary] = []
var _trace_limit: int = 64


func configure(router: RefCounted, enabled: bool) -> void:
	_router = router
	_enabled = enabled
	if not _enabled:
		cancel_all("disabled")


func is_enabled() -> bool:
	return _enabled


func reconcile_surface(
	surface_id: String,
	signature: String,
	config: Dictionary
) -> int:
	var normalized_id := surface_id.strip_edges()
	if normalized_id == "":
		return 0
	var existing: Dictionary = _surfaces.get(normalized_id, {})
	var generation := int(existing.get("generation", 0))
	var changed := existing.is_empty() or str(existing.get("signature", "")) != signature
	if changed:
		cancel_surface(normalized_id, "generation_changed")
		generation += 1
	var record := {
		"generation": generation,
		"signature": signature,
		"config": config.duplicate(false),
	}
	_surfaces[normalized_id] = record
	if not _surface_order.has(normalized_id):
		_surface_order.append(normalized_id)
	_trace_event("surface_reconciled", {
		"surface_id": normalized_id,
		"generation": generation,
		"changed": changed,
		"signature": signature,
	})
	return generation


func unregister_surface(surface_id: String, reason: String = "unregistered") -> void:
	cancel_surface(surface_id, reason)
	_surfaces.erase(surface_id)
	_surface_order.erase(surface_id)


func surface_generation(surface_id: String) -> int:
	var surface: Dictionary = _surfaces.get(surface_id, {})
	return int(surface.get("generation", 0))


func handle_event(event: InputEvent, observation: Dictionary) -> bool:
	if not _enabled or event == null:
		return false
	if not (
		event is InputEventScreenTouch
		or event is InputEventScreenDrag
		or event is InputEventMouseButton
		or event is InputEventMouseMotion
	):
		return false
	var sequence: PointerSequence = observation.get("sequence", null) as PointerSequence
	if sequence == null:
		return false
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			return _handle_pointer_pressed(
				event,
				touch.position,
				touch.index,
				sequence
			)
		return _handle_pointer_released(touch.position, touch.index, sequence)
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		return _handle_pointer_dragged(drag.position, drag.index, sequence)
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return false
		var mouse_position := _mouse_position(mouse_button)
		if mouse_button.pressed:
			return _handle_pointer_pressed(
				event,
				mouse_position,
				-1,
				sequence
			)
		return _handle_pointer_released(mouse_position, -1, sequence)
	var mouse_motion := event as InputEventMouseMotion
	return _handle_pointer_dragged(
		mouse_motion.global_position
			if mouse_motion.global_position != Vector2.ZERO
			else mouse_motion.position,
		-1,
		sequence
	)


func cancel_surface(surface_id: String, reason: String = "surface_cancel") -> int:
	var cancelled := 0
	for sequence_id: Variant in _active_gestures.keys():
		var gesture: Dictionary = _active_gestures[sequence_id]
		if str(gesture.get("surface_id", "")) != surface_id:
			continue
		gesture["state"] = STATE_CANCELLED
		gesture["cancel_reason"] = reason
		_active_gestures.erase(sequence_id)
		cancelled += 1
		_trace_event("gesture_cancelled", {
			"sequence_id": int(sequence_id),
			"surface_id": surface_id,
			"reason": reason,
		})
	return cancelled


func cancel_all(reason: String = "cancel_all") -> int:
	var cancelled := _active_gestures.size()
	for sequence_id: Variant in _active_gestures.keys():
		var gesture: Dictionary = _active_gestures[sequence_id]
		_trace_event("gesture_cancelled", {
			"sequence_id": int(sequence_id),
			"surface_id": str(gesture.get("surface_id", "")),
			"reason": reason,
		})
	_active_gestures.clear()
	return cancelled


func active_gesture_count() -> int:
	return _active_gestures.size()


func active_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for gesture_variant: Variant in _active_gestures.values():
		var gesture: Dictionary = gesture_variant
		snapshots.append(gesture.duplicate(true))
	return snapshots


func trace_snapshot() -> Array[Dictionary]:
	return _trace.duplicate(true)


func _handle_pointer_pressed(
	event: InputEvent,
	position: Vector2,
	pointer_id: int,
	sequence: PointerSequence
) -> bool:
	var surface_id := _surface_at(position)
	if surface_id == "":
		return false
	var surface: Dictionary = _surfaces.get(surface_id, {})
	var config: Dictionary = surface.get("config", {})
	var target_key: Variant = _call_config(config, "target_at", [position], null)
	var owner := _owner_for_surface(surface_id)
	if _router == null or not bool(_router.call(
		"claim_event",
		event,
		"surface_gesture",
		owner
	)):
		return false
	var sequence_id := sequence.sequence_id
	_active_gestures[sequence_id] = {
		"sequence_id": sequence_id,
		"pointer_id": pointer_id,
		"surface_id": surface_id,
		"surface_generation": int(surface.get("generation", 0)),
		"target_key": target_key,
		"press_position": position,
		"latest_position": position,
		"start_scroll": int(_call_config(config, "get_horizontal_scroll", [], 0)),
		"state": STATE_PENDING_TAP,
		"cancel_reason": "",
	}
	_trace_event("gesture_pressed", _active_gestures[sequence_id])
	return true


func _handle_pointer_dragged(
	position: Vector2,
	pointer_id: int,
	sequence: PointerSequence
) -> bool:
	var gesture: Dictionary = _active_gestures.get(sequence.sequence_id, {})
	if gesture.is_empty():
		return _sequence_owned_by_surface(sequence)
	if int(gesture.get("pointer_id", -2)) != pointer_id:
		return true
	var surface_id := str(gesture.get("surface_id", ""))
	var surface: Dictionary = _surfaces.get(surface_id, {})
	if (
		surface.is_empty()
		or int(surface.get("generation", 0))
			!= int(gesture.get("surface_generation", -1))
	):
		cancel_surface(surface_id, "stale_generation_drag")
		return true
	var config: Dictionary = surface.get("config", {})
	var press_position: Vector2 = gesture.get("press_position", Vector2.ZERO)
	var delta := position - press_position
	gesture["latest_position"] = position
	var state := str(gesture.get("state", STATE_PENDING_TAP))
	if state == STATE_PENDING_TAP:
		var drag_threshold := float(config.get("horizontal_drag_threshold", 36.0))
		var horizontal_dominant := absf(delta.x) >= absf(delta.y)
		var has_overflow := bool(_call_config(
			config,
			"has_horizontal_overflow",
			[],
			false
		))
		if has_overflow and horizontal_dominant and absf(delta.x) >= drag_threshold:
			state = STATE_SCROLLING
			gesture["state"] = state
			_trace_event("gesture_scrolling", gesture)
		else:
			var horizontal_tolerance := float(
				config.get("horizontal_tap_tolerance", 36.0)
			)
			var vertical_tolerance := float(
				config.get("vertical_tap_tolerance", 48.0)
			)
			if (
				absf(delta.x) > horizontal_tolerance
				or absf(delta.y) > vertical_tolerance
			):
				gesture["state"] = STATE_CANCELLED
				gesture["cancel_reason"] = "tap_tolerance_exceeded"
				_trace_event("gesture_cancelled", gesture)
	if str(gesture.get("state", "")) == STATE_SCROLLING:
		var target_scroll := int(gesture.get("start_scroll", 0)) - roundi(delta.x)
		_call_config(config, "set_horizontal_scroll", [maxi(0, target_scroll)], null)
	_active_gestures[sequence.sequence_id] = gesture
	return true


func _handle_pointer_released(
	position: Vector2,
	pointer_id: int,
	sequence: PointerSequence
) -> bool:
	var gesture: Dictionary = _active_gestures.get(sequence.sequence_id, {})
	if gesture.is_empty():
		return _sequence_owned_by_surface(sequence)
	_active_gestures.erase(sequence.sequence_id)
	if int(gesture.get("pointer_id", -2)) != pointer_id:
		return true
	var surface_id := str(gesture.get("surface_id", ""))
	var surface: Dictionary = _surfaces.get(surface_id, {})
	var same_generation := (
		not surface.is_empty()
		and int(surface.get("generation", 0))
			== int(gesture.get("surface_generation", -1))
	)
	if not same_generation:
		_trace_event("gesture_release_ignored", {
			"sequence_id": sequence.sequence_id,
			"surface_id": surface_id,
			"reason": "stale_generation",
		})
		return true
	if str(gesture.get("state", "")) != STATE_PENDING_TAP:
		_trace_event("gesture_release_ignored", {
			"sequence_id": sequence.sequence_id,
			"surface_id": surface_id,
			"reason": str(gesture.get("state", "")),
		})
		return true
	var config: Dictionary = surface.get("config", {})
	var press_position: Vector2 = gesture.get("press_position", Vector2.ZERO)
	var delta := position - press_position
	if (
		absf(delta.x) > float(config.get("horizontal_tap_tolerance", 36.0))
		or absf(delta.y) > float(config.get("vertical_tap_tolerance", 48.0))
	):
		return true
	if not bool(_call_config(config, "contains", [position], false)):
		return true
	var target_key: Variant = gesture.get("target_key", null)
	if target_key == null:
		return true
	var release_target: Variant = _call_config(
		config,
		"target_at",
		[position],
		null
	)
	if release_target != target_key:
		return true
	_call_config(
		config,
		"activate",
		[target_key, int(surface.get("generation", 0))],
		null
	)
	_trace_event("gesture_tap_committed", {
		"sequence_id": sequence.sequence_id,
		"surface_id": surface_id,
		"generation": int(surface.get("generation", 0)),
		"target_key": target_key,
	})
	return true


func _mouse_position(mouse_button: InputEventMouseButton) -> Vector2:
	return (
		mouse_button.global_position
		if mouse_button.global_position != Vector2.ZERO
		else mouse_button.position
	)


func _surface_at(position: Vector2) -> String:
	for index: int in range(_surface_order.size() - 1, -1, -1):
		var surface_id := _surface_order[index]
		var surface: Dictionary = _surfaces.get(surface_id, {})
		var config: Dictionary = surface.get("config", {})
		if bool(_call_config(config, "contains", [position], false)):
			return surface_id
	return ""


func _sequence_owned_by_surface(sequence: PointerSequence) -> bool:
	return sequence != null and sequence.owner.begins_with(OWNER_PREFIX)


func _owner_for_surface(surface_id: String) -> String:
	return "%s%s" % [OWNER_PREFIX, surface_id]


func _call_config(
	config: Dictionary,
	key: String,
	arguments: Array,
	fallback: Variant
) -> Variant:
	var callable_variant: Variant = config.get(key, Callable())
	if not (callable_variant is Callable):
		return fallback
	var callable := callable_variant as Callable
	if not callable.is_valid():
		return fallback
	return callable.callv(arguments)


func _trace_event(kind: String, payload: Dictionary) -> void:
	var entry := payload.duplicate(true)
	entry["kind"] = kind
	entry["at_msec"] = Time.get_ticks_msec()
	_trace.append(entry)
	while _trace.size() > _trace_limit:
		_trace.pop_front()
