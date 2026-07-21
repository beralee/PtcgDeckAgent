class_name V18CPGExecutionCursor
extends RefCounted

## Persists one validated strategic route across the engine's one-action-at-a-time
## loop.  The cursor stores typed macro intent, never raw engine objects.

var _active: bool = false
var _selection: Dictionary = {}
var _macro_actions: Array[String] = []
var _step_index: int = 0
var _expected_observation_version: int = -1
var _bound_action_id: String = ""
var _lifecycle: Dictionary = {}
var _origin: String = "local_gate"
var _invalid_reason: String = ""


func install(
	selection: Dictionary,
	lifecycle: Dictionary,
	observation_version: int,
	origin: String
) -> void:
	clear()
	_selection = selection.duplicate(true)
	_lifecycle = lifecycle.duplicate(true)
	_expected_observation_version = observation_version
	_origin = origin
	var mode := str(_selection.get("mode", ""))
	if mode == "propose_typed_route":
		for raw_macro: Variant in _selection.get("macro_actions", []):
			var macro := str(raw_macro)
			if macro != "":
				_macro_actions.append(macro)
	else:
		var route_id := str(_selection.get("route_id", ""))
		if route_id != "":
			_macro_actions.append(route_id)
	_active = not _macro_actions.is_empty()


func clear() -> void:
	_active = false
	_selection.clear()
	_macro_actions.clear()
	_step_index = 0
	_expected_observation_version = -1
	_bound_action_id = ""
	_lifecycle.clear()
	_origin = "local_gate"
	_invalid_reason = ""


func is_active() -> bool:
	return _active and _step_index < _macro_actions.size()


func resolve(frontier: Array[Dictionary], observation_version: int) -> Dictionary:
	if not is_active():
		return {}
	if observation_version < _expected_observation_version:
		_invalid_reason = "stale_observation"
		return {}
	var route_id := _macro_actions[_step_index]
	var wanted_candidate := ""
	if _step_index == 0:
		wanted_candidate = str(_selection.get("candidate_id", _selection.get("first_candidate_id", "")))
	if wanted_candidate != "":
		for candidate: Dictionary in frontier:
			if str(candidate.get("candidate_id", "")) == wanted_candidate:
				return _bind(candidate, observation_version)
		_invalid_reason = "candidate_unavailable"
		return {}
	for candidate: Dictionary in frontier:
		if str(candidate.get("route_id", "")) == route_id:
			return _bind(candidate, observation_version)
	_invalid_reason = "route_step_unavailable"
	return {}


func on_action_result(action_id: String, success: bool) -> void:
	if not is_active():
		return
	if not success:
		_invalid_reason = "action_failed"
		_active = false
		return
	if _bound_action_id != "" and action_id != _bound_action_id:
		_invalid_reason = "action_identity_mismatch"
		_active = false
		return
	_step_index += 1
	_bound_action_id = ""
	if _step_index >= _macro_actions.size():
		_active = false


func current_route_id() -> String:
	if not is_active():
		return ""
	return _macro_actions[_step_index]


func origin() -> String:
	return _origin


func invalid_reason() -> String:
	return _invalid_reason


func snapshot() -> Dictionary:
	return {
		"active": is_active(),
		"selection": _selection.duplicate(true),
		"macro_actions": _macro_actions.duplicate(),
		"step_index": _step_index,
		"expected_observation_version": _expected_observation_version,
		"bound_action_id": _bound_action_id,
		"lifecycle": _lifecycle.duplicate(true),
		"origin": _origin,
		"invalid_reason": _invalid_reason,
	}


func _bind(candidate: Dictionary, observation_version: int) -> Dictionary:
	_bound_action_id = str(candidate.get("safe_prefix_action_id", ""))
	_expected_observation_version = observation_version
	return {
		"candidate_id": str(candidate.get("candidate_id", "")),
		"route_id": str(candidate.get("route_id", "")),
		"action_id": _bound_action_id,
		"step_index": _step_index,
		"origin": _origin,
	}
