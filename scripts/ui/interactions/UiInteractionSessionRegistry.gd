class_name UiInteractionSessionRegistry
extends RefCounted

signal session_opened(session: UiInteractionSession)
signal session_finished(session: UiInteractionSession)

const UiInteractionSessionScript := preload("res://scripts/ui/interactions/UiInteractionSession.gd")

var _generation: int = 0
var _current: UiInteractionSession = null


func open_session(
	owner: String,
	interaction_type: String,
	blocking_reason: String,
	completion_policy: String,
	timeout_msec: int = 0,
	metadata: Dictionary = {},
	now_msec: int = -1,
	replace_active: bool = false
) -> UiInteractionSession:
	if _current != null and _current.is_active():
		if not replace_active:
			return null
		_current.cancel("replaced", _current.generation, now_msec)
	_generation += 1
	var session := UiInteractionSessionScript.new({
		"session_id": "%d:%s:%s" % [_generation, owner, interaction_type],
		"generation": _generation,
		"owner": owner,
		"interaction_type": interaction_type,
		"blocking_reason": blocking_reason,
		"completion_policy": completion_policy,
		"timeout_msec": timeout_msec,
		"opened_at_msec": now_msec,
		"metadata": metadata,
	})
	_current = session
	session.finished.connect(_on_session_finished.bind(session.generation), CONNECT_ONE_SHOT)
	session_opened.emit(session)
	return session


func current_session() -> UiInteractionSession:
	return _current


func current_snapshot() -> Dictionary:
	return _current.snapshot() if _current != null else {}


func finish_current(session_id: String, generation: int, reason: String = "", now_msec: int = -1) -> bool:
	if not _matches_current(session_id, generation):
		return false
	return _current.complete(reason, generation, now_msec)


func cancel_current(session_id: String, generation: int, reason: String = "", now_msec: int = -1) -> bool:
	if not _matches_current(session_id, generation):
		return false
	return _current.cancel(reason, generation, now_msec)


func timeout_current(session_id: String, generation: int, reason: String = "", now_msec: int = -1) -> bool:
	if not _matches_current(session_id, generation):
		return false
	return _current.timeout(reason, generation, now_msec)


func timeout_if_stalled(now_msec: int = -1, reason: String = "stalled") -> UiInteractionSession:
	var session := _current
	if session == null or not session.is_stalled(now_msec):
		return null
	session.timeout(reason, session.generation, now_msec)
	return session


func invalidate(reason: String = "registry_invalidated", now_msec: int = -1) -> void:
	_generation += 1
	if _current != null and _current.is_active():
		_current.cancel(reason, _current.generation, now_msec)
	_current = null


func generation() -> int:
	return _generation


func _matches_current(session_id: String, generation: int) -> bool:
	return (
		_current != null
		and _current.is_active()
		and _current.session_id == session_id
		and _current.generation == generation
	)


func _on_session_finished(session: UiInteractionSession, callback_generation: int) -> void:
	if session == null:
		return
	session_finished.emit(session)
	if _current == session and _current.generation == callback_generation:
		_current = null
