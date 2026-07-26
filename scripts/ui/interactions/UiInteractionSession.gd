class_name UiInteractionSession
extends RefCounted

signal finished(session: UiInteractionSession)

const STATE_ACTIVE := "active"
const STATE_COMPLETED := "completed"
const STATE_CANCELLED := "cancelled"
const STATE_TIMED_OUT := "timed_out"

const POLICY_SAFE_COMPLETE_PRESENTATION := "safe_complete_presentation"
const POLICY_CANCEL_IF_LEGAL := "cancel_if_legal"
const POLICY_REBUILD_REQUIRED_HUMAN_PROMPT := "rebuild_required_human_prompt"
const POLICY_AI_FALLBACK := "ai_fallback"

var session_id: String = ""
var generation: int = 0
var owner: String = ""
var interaction_type: String = ""
var blocking_reason: String = ""
var completion_policy: String = POLICY_CANCEL_IF_LEGAL
var timeout_msec: int = 0
var opened_at_msec: int = 0
var last_progress_at_msec: int = 0
var finished_at_msec: int = 0
var state: String = STATE_ACTIVE
var finish_reason: String = ""
var metadata: Dictionary = {}


func _init(values: Dictionary = {}) -> void:
	session_id = str(values.get("session_id", session_id))
	generation = int(values.get("generation", generation))
	owner = str(values.get("owner", owner))
	interaction_type = str(values.get("interaction_type", interaction_type))
	blocking_reason = str(values.get("blocking_reason", blocking_reason))
	completion_policy = str(values.get("completion_policy", completion_policy))
	timeout_msec = maxi(0, int(values.get("timeout_msec", timeout_msec)))
	opened_at_msec = _resolve_now(int(values.get("opened_at_msec", -1)))
	last_progress_at_msec = opened_at_msec
	metadata = (values.get("metadata", {}) as Dictionary).duplicate(true)


func is_active() -> bool:
	return state == STATE_ACTIVE


func mark_progress(now_msec: int = -1, expected_generation: int = -1) -> bool:
	if not _can_mutate(expected_generation):
		return false
	last_progress_at_msec = _resolve_now(now_msec)
	return true


func is_stalled(now_msec: int = -1) -> bool:
	if not is_active() or timeout_msec <= 0:
		return false
	return _resolve_now(now_msec) - last_progress_at_msec >= timeout_msec


func complete(reason: String = "", expected_generation: int = -1, now_msec: int = -1) -> bool:
	return _finish(STATE_COMPLETED, reason, expected_generation, now_msec)


func cancel(reason: String = "", expected_generation: int = -1, now_msec: int = -1) -> bool:
	return _finish(STATE_CANCELLED, reason, expected_generation, now_msec)


func timeout(reason: String = "", expected_generation: int = -1, now_msec: int = -1) -> bool:
	return _finish(STATE_TIMED_OUT, reason, expected_generation, now_msec)


func snapshot() -> Dictionary:
	return {
		"session_id": session_id,
		"generation": generation,
		"owner": owner,
		"interaction_type": interaction_type,
		"blocking_reason": blocking_reason,
		"completion_policy": completion_policy,
		"timeout_msec": timeout_msec,
		"opened_at_msec": opened_at_msec,
		"last_progress_at_msec": last_progress_at_msec,
		"finished_at_msec": finished_at_msec,
		"state": state,
		"finish_reason": finish_reason,
		"metadata": metadata.duplicate(true),
	}


func _can_mutate(expected_generation: int) -> bool:
	return is_active() and (expected_generation < 0 or expected_generation == generation)


func _finish(target_state: String, reason: String, expected_generation: int, now_msec: int) -> bool:
	if not _can_mutate(expected_generation):
		return false
	state = target_state
	finish_reason = reason
	finished_at_msec = _resolve_now(now_msec)
	last_progress_at_msec = finished_at_msec
	finished.emit(self)
	return true


func _resolve_now(explicit_msec: int) -> int:
	return explicit_msec if explicit_msec >= 0 else Time.get_ticks_msec()
