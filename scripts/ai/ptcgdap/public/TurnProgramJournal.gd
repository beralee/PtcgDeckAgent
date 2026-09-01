class_name TurnProgramJournal
extends RefCounted

const PlannerScript = preload("res://scripts/ai/ptcgdap/public/TurnProgramPlanner.gd")
const TreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")

var _match_id := ""
var _seat := -1
var _package_identity := ""
var _state: Dictionary = {}


func _init(match_id: String, seat: int, package_identity: String) -> void:
	_match_id = match_id
	_seat = seat
	_package_identity = package_identity


func snapshot() -> Dictionary:
	return {
		"scope": {
			"match_id": _match_id,
			"seat": _seat,
			"package_identity": _package_identity,
		},
		"state": _state.duplicate(true),
	}


func clear() -> void:
	_state.clear()


func advance(frame: Variant, request: Variant) -> Dictionary:
	if (
		not frame is Dictionary or frame.get("seat") != _seat
		or not _scope_text(_match_id, false) or not _scope_text(_package_identity, true)
	):
		return _error("turn_program_scope_mismatch")
	var result: Dictionary = PlannerScript.evaluate(frame, request)
	if not bool(result.get("accepted", false)):
		return result
	var selected_id: Variant = result.get("selected_program_id")
	var previous_id: Variant = _state.get("program_id")
	var event := "idle"
	if selected_id == null:
		clear()
	else:
		var selected := {}
		for program_value: Variant in request.get("programs", []):
			if program_value is Dictionary and program_value.get("program_id") == selected_id:
				selected = program_value
				break
		if selected.is_empty():
			return _error("invalid_turn_program")
		event = (
			"started" if previous_id == null
			else "continued" if previous_id == selected_id
			else "replanned"
		)
		var turn_number := int(frame.get("public_state", {}).get("turn_number", 0))
		_state = {
			"program_id": selected.get("program_id"),
			"goal_id": selected.get("goal_id"),
			"route_id": selected.get("route_id"),
			"start_turn": turn_number,
			"deadline_turn": turn_number + int(selected.get("deadline_turns", 0)),
		}
	var payload := result.duplicate(true)
	payload.erase("audit_hash")
	payload["journal_event"] = event
	payload["state"] = _state.duplicate(true)
	var hashed := TreeHashScript.hash_tree(payload, "public_observation")
	payload["audit_hash"] = str(hashed.get("sha256", "")) if bool(hashed.get("ok", false)) else ""
	return payload


func _error(code: String) -> Dictionary:
	return {
		"accepted": false,
		"error_code": code,
		"mode": "shadow",
		"authoritative": false,
		"public_only": true,
		"selected_program_id": null,
		"selected_current_step_id": null,
		"ranked_program_ids": [],
		"candidate_audit": [],
		"reobserve_before_execution": true,
		"stale_plan_has_authority": false,
		"audit_hash": "",
	}


func _scope_text(value: String, package_identity: bool) -> bool:
	if value.is_empty() or value.length() > (256 if package_identity else 128):
		return false
	for offset: int in value.length():
		var code := value.unicode_at(offset)
		var allowed := (
			(code >= 65 and code <= 90) or (code >= 97 and code <= 122)
			or (code >= 48 and code <= 57) or code in [45, 46, 95]
		)
		if package_identity:
			allowed = allowed or code in [35, 43, 64]
		if not allowed:
			return false
	return true
