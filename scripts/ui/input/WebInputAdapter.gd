class_name WebInputAdapter
extends RefCounted

const PointerSequenceScript := preload("res://scripts/ui/input/PointerSequence.gd")

const ECHO_MAX_DISTANCE := 14.0
const ECHO_MAX_AGE_MSEC := 700
const RECENT_SEQUENCE_LIMIT := 8

var _next_sequence_id: int = 1
var _active_touch_sequences: Dictionary = {}
var _active_mouse_sequence: PointerSequence = null
var _recent_touch_sequences: Array[PointerSequence] = []


func ingest(event: InputEvent, now_msec: int = -1) -> Dictionary:
	var now := now_msec if now_msec >= 0 else Time.get_ticks_msec()
	_prune_recent(now)
	if event is InputEventScreenTouch:
		return _ingest_touch(event as InputEventScreenTouch, now)
	if event is InputEventScreenDrag:
		return _ingest_drag(event as InputEventScreenDrag, now)
	if event is InputEventMouseButton:
		return _ingest_mouse_button(event as InputEventMouseButton, now)
	if event is InputEventMouseMotion:
		return _ingest_mouse_motion(event as InputEventMouseMotion, now)
	return _result(false, false, "unsupported", null)


func consume(sequence: PointerSequence, intent: String, owner: String, now_msec: int = -1) -> bool:
	return sequence != null and sequence.consume(intent, owner, now_msec)


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
	return cancelled


func active_sequence_count() -> int:
	return _active_touch_sequences.size() + (1 if _active_mouse_sequence != null and _active_mouse_sequence.is_active() else 0)


func active_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for value: Variant in _active_touch_sequences.values():
		var sequence := value as PointerSequence
		if sequence != null:
			snapshots.append(sequence.snapshot())
	if _active_mouse_sequence != null:
		snapshots.append(_active_mouse_sequence.snapshot())
	return snapshots


func _ingest_touch(touch: InputEventScreenTouch, now: int) -> Dictionary:
	var pointer_id := touch.index
	if touch.pressed:
		if _active_touch_sequences.has(pointer_id):
			var stale := _active_touch_sequences[pointer_id] as PointerSequence
			if stale != null:
				stale.cancel("replaced_touch_down", now)
		var sequence: PointerSequence = PointerSequenceScript.new(
			_next_id(), pointer_id, PointerSequenceScript.SOURCE_TOUCH, touch.position, now
		)
		_active_touch_sequences[pointer_id] = sequence
		return _result(true, false, "pressed", sequence)
	if not _active_touch_sequences.has(pointer_id):
		return _result(false, false, "orphan_release", null)
	var sequence := _active_touch_sequences[pointer_id] as PointerSequence
	_active_touch_sequences.erase(pointer_id)
	if sequence == null or not sequence.update_position(touch.position, now):
		return _result(false, false, "inactive_release", sequence)
	sequence.complete(now)
	_remember_touch(sequence)
	return _result(true, false, "released", sequence)


func _ingest_drag(drag: InputEventScreenDrag, now: int) -> Dictionary:
	if not _active_touch_sequences.has(drag.index):
		return _result(false, false, "orphan_drag", null)
	var sequence := _active_touch_sequences[drag.index] as PointerSequence
	if sequence == null or not sequence.update_position(drag.position, now):
		return _result(false, false, "inactive_drag", sequence)
	return _result(true, false, "moved", sequence)


func _ingest_mouse_button(mouse_button: InputEventMouseButton, now: int) -> Dictionary:
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return _result(false, false, "non_primary_mouse", null)
	var position := mouse_button.global_position if mouse_button.global_position != Vector2.ZERO else mouse_button.position
	if _matches_touch_echo(position, now):
		return _result(false, true, "synthetic_mouse_echo", null)
	if mouse_button.pressed:
		if _active_mouse_sequence != null:
			_active_mouse_sequence.cancel("replaced_mouse_down", now)
		_active_mouse_sequence = PointerSequenceScript.new(
			_next_id(), -1, PointerSequenceScript.SOURCE_MOUSE, position, now
		)
		return _result(true, false, "pressed", _active_mouse_sequence)
	if _active_mouse_sequence == null:
		return _result(false, false, "orphan_mouse_release", null)
	var sequence := _active_mouse_sequence
	_active_mouse_sequence = null
	sequence.update_position(position, now)
	sequence.complete(now)
	return _result(true, false, "released", sequence)


func _ingest_mouse_motion(mouse_motion: InputEventMouseMotion, now: int) -> Dictionary:
	if _active_mouse_sequence == null:
		return _result(false, false, "hover", null)
	var position := mouse_motion.global_position if mouse_motion.global_position != Vector2.ZERO else mouse_motion.position
	_active_mouse_sequence.update_position(position, now)
	return _result(true, false, "moved", _active_mouse_sequence)


func _matches_touch_echo(position: Vector2, now: int) -> bool:
	for value: Variant in _active_touch_sequences.values():
		var active := value as PointerSequence
		if active != null and active.is_possible_synthetic_echo(position, now, ECHO_MAX_DISTANCE, ECHO_MAX_AGE_MSEC):
			return true
	for sequence: PointerSequence in _recent_touch_sequences:
		if sequence.is_possible_synthetic_echo(position, now, ECHO_MAX_DISTANCE, ECHO_MAX_AGE_MSEC):
			return true
	return false


func _remember_touch(sequence: PointerSequence) -> void:
	_recent_touch_sequences.append(sequence)
	while _recent_touch_sequences.size() > RECENT_SEQUENCE_LIMIT:
		_recent_touch_sequences.pop_front()


func _prune_recent(now: int) -> void:
	var kept: Array[PointerSequence] = []
	for sequence: PointerSequence in _recent_touch_sequences:
		if now - sequence.finished_at_msec <= ECHO_MAX_AGE_MSEC:
			kept.append(sequence)
	_recent_touch_sequences = kept


func _next_id() -> int:
	var result := _next_sequence_id
	_next_sequence_id += 1
	return result


func _result(deliver: bool, suppressed: bool, phase: String, sequence: PointerSequence) -> Dictionary:
	return {
		"deliver": deliver,
		"suppressed": suppressed,
		"phase": phase,
		"sequence": sequence,
	}

