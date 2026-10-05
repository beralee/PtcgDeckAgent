class_name BattlePointerInputRouter
extends RefCounted

const PointerSequenceScript := preload("res://scripts/ui/input/PointerSequence.gd")

const TOUCH_MOUSE_ECHO_MAX_DISTANCE := 18.0
const TOUCH_MOUSE_ECHO_MAX_AGE_MSEC := 700
# Device-zero mouse events on native Android are ambiguous: they can be either
# an immediate compatibility tail or the leading half of the player's next
# physical tap. Keep only a short post-release merge window for that weak
# signal. Explicit DEVICE_ID_EMULATION events retain the full long-press window.
const UNLABELLED_TOUCH_MOUSE_ECHO_MAX_AGE_MSEC := 96
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
var _last_pointer_event: InputEvent = null
var _last_pointer_result: Dictionary = {}
var _last_pointer_frame: int = -1


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
	_last_pointer_event = event
	_last_pointer_result = result
	_last_pointer_frame = Engine.get_process_frames()
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
	if _last_pointer_frame == Engine.get_process_frames():
		sequence = _last_pointer_result.get("sequence", sequence)
	return _claim_sequence(sequence, intent, owner, _resolve_now(now_msec))


func claim_gui_event(event: InputEvent, intent: String, owner: String) -> bool:
	return _claim_sequence(_gui_event_sequence(event), intent, owner, Time.get_ticks_msec())


func should_block_gui_event(event: InputEvent, requesting_owner: String) -> bool:
	var sequence := _gui_event_sequence(event)
	return sequence != null and sequence.consumed_intent != "" and sequence.owner != requesting_owner


func _gui_event_sequence(event: InputEvent) -> PointerSequence:
	# Godot transforms GUI event copies into control-local coordinates. They are
	# the same dispatch already observed by _input, not another physical press.
	var same_dispatch := false
	if event is InputEventScreenTouch and _last_pointer_event is InputEventScreenTouch:
		same_dispatch = event.index == _last_pointer_event.index and event.pressed == _last_pointer_event.pressed
	elif event is InputEventMouseButton and _last_pointer_event is InputEventMouseButton:
		same_dispatch = event.button_index == _last_pointer_event.button_index and event.pressed == _last_pointer_event.pressed and event.device == _last_pointer_event.device
	if same_dispatch and _last_pointer_frame == Engine.get_process_frames():
		return _last_pointer_result.get("sequence", null)
	return observe(event).get("sequence", null)


func finish_gui_dispatch() -> void:
	var sequence := _last_pointer_result.get("sequence", null) as PointerSequence
	if _last_pointer_frame == Engine.get_process_frames() and _preserve_sequence(sequence, "battle_modal"):
		# Synchronous engine/UI work can take longer than the Android echo window.
		# That time is part of this dispatch, not time available for a new tap.
		sequence.metadata["gui_completed_at_msec"] = Time.get_ticks_msec()


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


func cancel_all(reason: String = "platform_cancel", now_msec: int = -1, preserved_owner: String = "") -> int:
	var cancelled := 0
	for pointer_id: Variant in _active_touch_sequences.keys():
		var sequence := _active_touch_sequences[pointer_id] as PointerSequence
		if _preserve_sequence(sequence, preserved_owner):
			continue
		if sequence != null and sequence.cancel(reason, now_msec):
			cancelled += 1
		_active_touch_sequences.erase(pointer_id)
	if not _preserve_sequence(_active_mouse_sequence, preserved_owner):
		if _active_mouse_sequence != null and _active_mouse_sequence.cancel(reason, now_msec):
			cancelled += 1
		_active_mouse_sequence = null
		_active_mouse_device = 0
	for pointer_id: Variant in _mouse_first_touch_aliases.keys():
		if not _preserve_sequence(_mouse_first_touch_aliases[pointer_id], preserved_owner):
			_mouse_first_touch_aliases.erase(pointer_id)
	for index: int in range(_recent_touch_sequences.size() - 1, -1, -1):
		if not _preserve_sequence(_recent_touch_sequences[index], preserved_owner):
			_recent_touch_sequences.remove_at(index)
	for event_id: Variant in _event_records.keys():
		var result: Dictionary = _event_records[event_id].get("result", {})
		if not _preserve_sequence(result.get("sequence", null), preserved_owner):
			_event_records.erase(event_id)
	if not _preserve_sequence(_last_pointer_result.get("sequence", null), preserved_owner):
		_last_pointer_event = null
		_last_pointer_result = {}
	return cancelled


func _preserve_sequence(sequence: PointerSequence, owner: String) -> bool:
	return owner != "" and sequence != null and sequence.owner == owner and sequence.consumed_intent != ""


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
	if touch.canceled:
		var cancelled_sequence := _active_touch_sequences.get(pointer_id,
			_mouse_first_touch_aliases.get(pointer_id, null)) as PointerSequence
		_active_touch_sequences.erase(pointer_id)
		_mouse_first_touch_aliases.erase(pointer_id)
		if cancelled_sequence == null:
			return _result(false, false, "orphan_touch_cancel", null)
		cancelled_sequence.cancel("touch_cancelled", now)
		_remember_touch(cancelled_sequence)
		if _active_mouse_sequence == cancelled_sequence:
			_active_mouse_sequence = null
			_active_mouse_device = 0
		return _result(true, false, "touch_cancelled", cancelled_sequence)
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
		var age_since_touch_release := now - maxi(sequence.finished_at_msec, int(sequence.metadata.get("gui_completed_at_msec", 0)))
		var recent_echo_max_age := (
			TOUCH_MOUSE_ECHO_MAX_AGE_MSEC
			if mouse_button.device == InputEvent.DEVICE_ID_EMULATION
			else UNLABELLED_TOUCH_MOUSE_ECHO_MAX_AGE_MSEC
		)
		if (
			age_since_touch_release >= 0
			and age_since_touch_release <= recent_echo_max_age
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
	# _input observes a release before BaseButton/card GUI callbacks execute.
	# Only that exact current dispatch may claim its already-completed sequence.
	if (
		sequence.state == PointerSequenceScript.STATE_COMPLETED
		and sequence == _last_pointer_result.get("sequence", null)
		and _last_pointer_frame == Engine.get_process_frames()
		and intent.strip_edges() != "" and owner.strip_edges() != ""
		and (sequence.owner == "" or sequence.owner == owner)
	):
		sequence.owner = owner
		sequence.consumed_intent = intent
		sequence.last_progress_at_msec = now
		return true
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
		if now - maxi(sequence.finished_at_msec, int(sequence.metadata.get("gui_completed_at_msec", 0))) <= TOUCH_MOUSE_ECHO_MAX_AGE_MSEC:
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
