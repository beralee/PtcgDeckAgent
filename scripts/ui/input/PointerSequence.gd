class_name PointerSequence
extends RefCounted

const STATE_ACTIVE := "active"
const STATE_COMPLETED := "completed"
const STATE_CANCELLED := "cancelled"

const SOURCE_MOUSE := "mouse"
const SOURCE_TOUCH := "touch"
const SOURCE_SYNTHETIC_MOUSE := "synthetic_mouse"

var sequence_id: int = 0
var pointer_id: int = 0
var source_kind: String = SOURCE_MOUSE
var press_position: Vector2 = Vector2.ZERO
var latest_position: Vector2 = Vector2.ZERO
var owner: String = ""
var started_at_msec: int = 0
var last_progress_at_msec: int = 0
var finished_at_msec: int = 0
var consumed_intent: String = ""
var cancel_reason: String = ""
var state: String = STATE_ACTIVE
var metadata: Dictionary = {}


func _init(
	id: int = 0,
	pointer: int = 0,
	source: String = SOURCE_MOUSE,
	position: Vector2 = Vector2.ZERO,
	now_msec: int = -1
) -> void:
	sequence_id = id
	pointer_id = pointer
	source_kind = source
	press_position = position
	latest_position = position
	started_at_msec = _resolve_now(now_msec)
	last_progress_at_msec = started_at_msec


func is_active() -> bool:
	return state == STATE_ACTIVE


func claim(requested_owner: String) -> bool:
	if not is_active() or requested_owner.strip_edges() == "":
		return false
	if owner == "":
		owner = requested_owner
		return true
	return owner == requested_owner


func update_position(position: Vector2, now_msec: int = -1) -> bool:
	if not is_active():
		return false
	latest_position = position
	last_progress_at_msec = _resolve_now(now_msec)
	return true


func consume(intent: String, requested_owner: String, now_msec: int = -1) -> bool:
	if intent.strip_edges() == "" or consumed_intent != "":
		return false
	if not claim(requested_owner):
		return false
	consumed_intent = intent
	last_progress_at_msec = _resolve_now(now_msec)
	return true


func complete(now_msec: int = -1) -> bool:
	if not is_active():
		return false
	state = STATE_COMPLETED
	finished_at_msec = _resolve_now(now_msec)
	last_progress_at_msec = finished_at_msec
	return true


func cancel(reason: String, now_msec: int = -1) -> bool:
	if not is_active():
		return false
	state = STATE_CANCELLED
	cancel_reason = reason
	finished_at_msec = _resolve_now(now_msec)
	last_progress_at_msec = finished_at_msec
	return true


func distance_from_press() -> float:
	return press_position.distance_to(latest_position)


func is_possible_synthetic_echo(position: Vector2, now_msec: int, max_distance: float = 12.0, max_age_msec: int = 700) -> bool:
	if source_kind != SOURCE_TOUCH:
		return false
	var age := _resolve_now(now_msec) - started_at_msec
	return age >= 0 and age <= max_age_msec and latest_position.distance_to(position) <= max_distance


func snapshot() -> Dictionary:
	return {
		"sequence_id": sequence_id,
		"pointer_id": pointer_id,
		"source_kind": source_kind,
		"press_position": press_position,
		"latest_position": latest_position,
		"owner": owner,
		"started_at_msec": started_at_msec,
		"last_progress_at_msec": last_progress_at_msec,
		"finished_at_msec": finished_at_msec,
		"consumed_intent": consumed_intent,
		"cancel_reason": cancel_reason,
		"state": state,
		"metadata": metadata.duplicate(true),
	}


func _resolve_now(explicit_msec: int) -> int:
	return explicit_msec if explicit_msec >= 0 else Time.get_ticks_msec()
