class_name BattlePointerInputRouter
extends RefCounted

const PointerSequenceScript := preload("res://scripts/ui/input/PointerSequence.gd")

const TOUCH_MOUSE_ECHO_MAX_DISTANCE := 18.0
const TOUCH_MOUSE_ECHO_MAX_AGE_MSEC := 700
const RECENT_TOUCH_LIMIT := 8
const EVENT_RECORD_MAX_AGE_MSEC := 1600
const EVENT_RECORD_LIMIT := 48

var _merge_touch_mouse_echo: bool = false
var _next_sequence_id: int = 1
var _active_touch_sequences: Dictionary = {}
var _active_mouse_sequence: PointerSequence = null
var _active_mouse_device: int = 0
var _mouse_first_touch_aliases: Dictionary = {}
var _recent_touch_sequences: Array[PointerSequence] = []
var _event_records: Dictionary = {}


func configure(merge_touch_mouse_echo: bool) -> void:
	_merge_touch_mouse_echo = merge_touch_mouse_echo


func observe(event: InputEvent, now_msec: int = -1) -> Dictionary:
	if event == null:
		return _result(false, false, "null_event", null)
	var event_id := event.get_instance_id()
	if _event_records.has(event_id):
		var existing: Dictionary = _event_records[event_id].get("result", {})
		return existing
	var now := _resolve_now(now_msec)
	_prune(now)
	var result: Dictionary
	if event is InputEventScreenTouch:
		result = _observe_touch(event as InputEventScreenTouch, now)
	elif event is InputEventScreenDrag:
		result = _observe_drag(event as InputEventScreenDrag, now)
	elif event is InputEventMouseButton:
		result = _observe_mouse_button(event as InputEventMouseButton, now)
	elif event is InputEventMouseMotion:
		result = _observe_mouse_motion(event as InputEventMouseMotion, now)
	else:
		result = _result(false, false, "unsupported", null)
	_remember_event(event_id, result, now)
	return result


func claim_event(
	event: InputEvent,
	intent: String,
	owner: String,
	now_msec: int = -1
) -> bool:
	var result := observe(event, now_msec)
	var sequence := result.get("sequence", null) as PointerSequence
	return _claim_sequence(sequence, intent, owner, _resolve_now(now_msec))


func claim_current(intent: String, owner: String, now_msec: int = -1) -> bool:
	var sequence := _latest_active_sequence()
	return _claim_sequence(sequence, intent, owner, _resolve_now(now_msec))


func should_block(
	event: InputEvent,
	requesting_owner: String,
	now_msec: int = -1
) -> bool:
	var result := observe(event, now_msec)
	var sequence := result.get("sequence", null) as PointerSequence
	if sequence == null or sequence.consumed_intent == "":
		return false
	return sequence.owner != requesting_owner


func cancel_all(reason: String = "platform_cancel", now_msec: int = -1) -> int:
	var cancelled := 0
	for value: Variant in _active_touch_sequences.values():
		var sequence := value as PointerSequence
		if sequence != null and sequence.cancel(reason, now_msec):
			cancelled += 1
	_active_touch_sequences.clear()
	if _active_mouse_sequence != null and _active_mouse_sequence.cancel(reason, now_msec):
		cancelled += 1
	_active_mouse_sequence = null
	_active_mouse_device = 0
	_mouse_first_touch_aliases.clear()
	_recent_touch_sequences.clear()
	_event_records.clear()
	return cancelled


func active_sequence_count() -> int:
	return _active_touch_sequences.size() + (
		1 if _active_mouse_sequence != null and _active_mouse_sequence.is_active() else 0
	)


func active_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for value: Variant in _active_touch_sequences.values():
		var sequence := value as PointerSequence
		if sequence != null and sequence.is_active():
			snapshots.append(sequence.snapshot())
	if _active_mouse_sequence != null and _active_mouse_sequence.is_active():
		snapshots.append(_active_mouse_sequence.snapshot())
	return snapshots


func _observe_touch(touch: InputEventScreenTouch, now: int) -> Dictionary:
	var pointer_id := touch.index
	if touch.pressed:
		if _active_touch_sequences.has(pointer_id):
			var stale := _active_touch_sequences[pointer_id] as PointerSequence
			if stale != null:
				stale.cancel("replaced_touch_down", now)
		_mouse_first_touch_aliases.erase(pointer_id)
		var mouse_echo := _matching_mouse_first_sequence(touch.position, now)
		if mouse_echo != null:
			_mouse_first_touch_aliases[pointer_id] = mouse_echo
			return _result(false, true, "mouse_touch_echo_pressed", mouse_echo)
		var sequence: PointerSequence = PointerSequenceScript.new(
			_next_id(),
			pointer_id,
			PointerSequenceScript.SOURCE_TOUCH,
			touch.position,
			now
		)
		_active_touch_sequences[pointer_id] = sequence
		return _result(true, false, "touch_pressed", sequence)
	if _mouse_first_touch_aliases.has(pointer_id):
		var mouse_echo := _mouse_first_touch_aliases[pointer_id] as PointerSequence
		_mouse_first_touch_aliases.erase(pointer_id)
		if mouse_echo != null and mouse_echo.is_active():
			mouse_echo.update_position(touch.position, now)
		return _result(false, true, "mouse_touch_echo_released", mouse_echo)
	if not _active_touch_sequences.has(pointer_id):
		return _result(false, false, "orphan_touch_release", null)
	var sequence := _active_touch_sequences[pointer_id] as PointerSequence
	_active_touch_sequences.erase(pointer_id)
	if sequence == null or not sequence.update_position(touch.position, now):
		return _result(false, false, "inactive_touch_release", sequence)
	sequence.complete(now)
	_remember_touch(sequence)
	return _result(true, false, "touch_released", sequence)


func _observe_drag(drag: InputEventScreenDrag, now: int) -> Dictionary:
	if not _active_touch_sequences.has(drag.index):
		return _result(false, false, "orphan_touch_drag", null)
	var sequence := _active_touch_sequences[drag.index] as PointerSequence
	if sequence == null or not sequence.update_position(drag.position, now):
		return _result(false, false, "inactive_touch_drag", sequence)
	return _result(true, false, "touch_moved", sequence)


func _observe_mouse_button(mouse_button: InputEventMouseButton, now: int) -> Dictionary:
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return _result(false, false, "non_primary_mouse", null)
	var position := _mouse_position(mouse_button)
	var touch_echo := _matching_touch_sequence(mouse_button, position, now)
	if touch_echo != null:
		return _result(false, true, "touch_mouse_echo", touch_echo)
	if mouse_button.pressed:
		if _active_mouse_sequence != null:
			_active_mouse_sequence.cancel("replaced_mouse_down", now)
		_active_mouse_sequence = PointerSequenceScript.new(
			_next_id(),
			-1,
			PointerSequenceScript.SOURCE_MOUSE,
			position,
			now
		)
		_active_mouse_device = mouse_button.device
		return _result(true, false, "mouse_pressed", _active_mouse_sequence)
	if _active_mouse_sequence == null:
		return _result(false, false, "orphan_mouse_release", null)
	var sequence := _active_mouse_sequence
	_active_mouse_sequence = null
	_active_mouse_device = 0
	sequence.update_position(position, now)
	sequence.complete(now)
	return _result(true, false, "mouse_released", sequence)


func _observe_mouse_motion(mouse_motion: InputEventMouseMotion, now: int) -> Dictionary:
	if _active_mouse_sequence == null:
		return _result(false, false, "mouse_hover", null)
	var position := mouse_motion.global_position \
		if mouse_motion.global_position != Vector2.ZERO else mouse_motion.position
	_active_mouse_sequence.update_position(position, now)
	return _result(true, false, "mouse_moved", _active_mouse_sequence)


func _matching_touch_sequence(
	mouse_button: InputEventMouseButton,
	position: Vector2,
	now: int
) -> PointerSequence:
	if not _merge_touch_mouse_echo:
		return null
	# Godot normally labels touch-generated compatibility mouse events with
	# DEVICE_ID_EMULATION. Native Android builds do not guarantee that marker:
	# some devices/drivers report the same compatibility tail as device 0.
	#
	# This fallback is enabled only by the native-mobile runtime profile. Desktop
	# and browser runtimes configure the router with merging disabled, while a
	# genuinely separate Android mouse keeps its non-zero physical device id.
	if (
		mouse_button.device != InputEvent.DEVICE_ID_EMULATION
		and mouse_button.device != 0
	):
		return null
	for value: Variant in _active_touch_sequences.values():
		var active := value as PointerSequence
		# While the touch is active, its duration is irrelevant: a long press still
		# owns the matching compatibility mouse press/release sequence.
		if (
			active != null
			and active.latest_position.distance_to(position) <= TOUCH_MOUSE_ECHO_MAX_DISTANCE
		):
			return active
	for sequence: PointerSequence in _recent_touch_sequences:
		var age_since_touch_release := now - sequence.finished_at_msec
		if (
			age_since_touch_release >= 0
			and age_since_touch_release <= TOUCH_MOUSE_ECHO_MAX_AGE_MSEC
			and sequence.latest_position.distance_to(position) <= TOUCH_MOUSE_ECHO_MAX_DISTANCE
		):
			return sequence
	return null


func _matching_mouse_first_sequence(
	position: Vector2,
	now: int
) -> PointerSequence:
	if (
		not _merge_touch_mouse_echo
		or _active_mouse_sequence == null
		or not _active_mouse_sequence.is_active()
		or (
			_active_mouse_device != InputEvent.DEVICE_ID_EMULATION
			and _active_mouse_device != 0
		)
	):
		return null
	var age := now - _active_mouse_sequence.started_at_msec
	if (
		age < 0
		or age > TOUCH_MOUSE_ECHO_MAX_AGE_MSEC
		or _active_mouse_sequence.latest_position.distance_to(position)
			> TOUCH_MOUSE_ECHO_MAX_DISTANCE
	):
		return null
	return _active_mouse_sequence


func _claim_sequence(
	sequence: PointerSequence,
	intent: String,
	owner: String,
	now: int
) -> bool:
	if sequence == null:
		return false
	if sequence.consumed_intent != "":
		return sequence.owner == owner and sequence.consumed_intent == intent
	return sequence.consume(intent, owner, now)


func _latest_active_sequence() -> PointerSequence:
	var latest: PointerSequence = _active_mouse_sequence \
		if _active_mouse_sequence != null and _active_mouse_sequence.is_active() else null
	for value: Variant in _active_touch_sequences.values():
		var sequence := value as PointerSequence
		if sequence == null or not sequence.is_active():
			continue
		if latest == null or sequence.last_progress_at_msec >= latest.last_progress_at_msec:
			latest = sequence
	return latest


func _remember_touch(sequence: PointerSequence) -> void:
	_recent_touch_sequences.append(sequence)
	while _recent_touch_sequences.size() > RECENT_TOUCH_LIMIT:
		_recent_touch_sequences.pop_front()


func _remember_event(event_id: int, result: Dictionary, now: int) -> void:
	_event_records[event_id] = {
		"result": result,
		"observed_at_msec": now,
	}
	if _event_records.size() <= EVENT_RECORD_LIMIT:
		return
	var ordered_ids: Array = _event_records.keys()
	ordered_ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(_event_records[a].get("observed_at_msec", 0)) \
			< int(_event_records[b].get("observed_at_msec", 0))
	)
	while _event_records.size() > EVENT_RECORD_LIMIT and not ordered_ids.is_empty():
		_event_records.erase(ordered_ids.pop_front())


func _prune(now: int) -> void:
	var kept_touch: Array[PointerSequence] = []
	for sequence: PointerSequence in _recent_touch_sequences:
		if now - sequence.finished_at_msec <= TOUCH_MOUSE_ECHO_MAX_AGE_MSEC:
			kept_touch.append(sequence)
	_recent_touch_sequences = kept_touch
	for event_id: Variant in _event_records.keys():
		var record: Dictionary = _event_records[event_id]
		if now - int(record.get("observed_at_msec", 0)) > EVENT_RECORD_MAX_AGE_MSEC:
			_event_records.erase(event_id)


func _mouse_position(mouse_button: InputEventMouseButton) -> Vector2:
	return mouse_button.global_position \
		if mouse_button.global_position != Vector2.ZERO else mouse_button.position


func _next_id() -> int:
	var result := _next_sequence_id
	_next_sequence_id += 1
	return result


func _resolve_now(explicit_msec: int) -> int:
	return explicit_msec if explicit_msec >= 0 else Time.get_ticks_msec()


func _result(
	deliver: bool,
	synthetic_echo: bool,
	phase: String,
	sequence: PointerSequence
) -> Dictionary:
	return {
		"deliver": deliver,
		"synthetic_echo": synthetic_echo,
		"phase": phase,
		"sequence": sequence,
	}
