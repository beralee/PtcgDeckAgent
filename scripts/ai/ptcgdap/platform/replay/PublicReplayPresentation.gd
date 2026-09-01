class_name PtcgDAPPublicReplayPresentation
extends RefCounted

var _manifest: Dictionary = {}
var _frames: Array = []
var _cursor := 0


static func create(contract_owner: Variant, manifest: Variant, frames: Variant) -> Dictionary:
	if contract_owner == null or not contract_owner.has_method("validate_replay"):
		return _failure("contract_owner_invalid")
	var validated: Dictionary = contract_owner.validate_replay(manifest, frames)
	if not bool(validated.get("accepted", false)):
		return validated
	var transition_error := _transition_error(frames)
	if not transition_error.is_empty():
		return _failure(transition_error)
	var presentation := new()
	presentation._manifest = (manifest as Dictionary).duplicate(true)
	presentation._frames = (frames as Array).duplicate(true)
	return {"accepted": true, "error_code": "", "presentation": presentation}


func first() -> Dictionary:
	_cursor = 0
	return current_view()


func previous() -> Dictionary:
	_cursor = maxi(0, _cursor - 1)
	return current_view()


func next() -> Dictionary:
	_cursor = mini(_frames.size() - 1, _cursor + 1)
	return current_view()


func last() -> Dictionary:
	_cursor = _frames.size() - 1
	return current_view()


func seek(ordinal: int) -> Dictionary:
	if ordinal < 0 or ordinal >= _frames.size():
		return _failure("replay_cursor_invalid")
	_cursor = ordinal
	return current_view()


func current_view() -> Dictionary:
	if _frames.is_empty() or _cursor < 0 or _cursor >= _frames.size():
		return _failure("replay_cursor_invalid")
	var frame: Dictionary = _frames[_cursor]
	var public_state: Dictionary = frame.get("public_state", {})
	return {
		"replay_id": _manifest.get("replay_id"),
		"match_id": frame.get("match_id"),
		"ordinal": _cursor,
		"frame_count": _frames.size(),
		"turn_number": frame.get("turn_number"),
		"phase": frame.get("phase"),
		"acting_seat": frame.get("acting_seat"),
		"event_kind": frame.get("event_kind"),
		"zone_counts": public_state.get("zone_counts", []).duplicate(true),
		"board": public_state.get("board", []).duplicate(true),
		"public_cards": public_state.get("public_cards", []).duplicate(true),
		"can_previous": _cursor > 0,
		"can_next": _cursor + 1 < _frames.size(),
		"execution_authority": false,
	}


func audit_snapshot() -> Dictionary:
	return {
		"document_type": "public_replay_presentation_audit_v1",
		"replay_id": _manifest.get("replay_id"),
		"match_id": _manifest.get("match_id"),
		"frame_count": _frames.size(),
		"authoritative": false,
		"engine_invocations": 0,
		"ticket_invocations": 0,
		"callback_invocations": 0,
		"grants": [],
	}


static func _transition_error(frames: Variant) -> String:
	if not frames is Array or frames.is_empty():
		return "replay_chain_invalid"
	if frames[0].get("event_kind") != "match_started" or frames[-1].get("event_kind") != "match_finished":
		return "replay_event_sequence_invalid"
	var previous_turn := -1
	for index: int in frames.size():
		var frame_value: Variant = frames[index]
		if not frame_value is Dictionary or typeof(frame_value.get("turn_number")) != TYPE_INT:
			return "replay_turn_transition_invalid"
		if not _visual_projection_error(frame_value).is_empty():
			return "replay_visual_projection_invalid"
		if index > 0 and frame_value.get("event_kind") == "match_started":
			return "replay_event_sequence_invalid"
		if index + 1 < frames.size() and frame_value.get("event_kind") == "match_finished":
			return "replay_event_sequence_invalid"
		var turn_number := int(frame_value.get("turn_number"))
		if previous_turn >= 0 and (turn_number < previous_turn or turn_number > previous_turn + 1):
			return "replay_turn_transition_invalid"
		previous_turn = turn_number
	return ""


static func _visual_projection_error(frame: Dictionary) -> String:
	var public_state: Variant = frame.get("public_state")
	if not public_state is Dictionary:
		return "replay_visual_projection_invalid"
	var board: Variant = public_state.get("board")
	if not board is Array:
		return "replay_visual_projection_invalid"
	var occupied: Dictionary = {}
	var stadium_count := 0
	for entry_variant: Variant in board:
		if not entry_variant is Dictionary:
			return "replay_visual_projection_invalid"
		var entry: Dictionary = entry_variant
		var seat := int(entry.get("seat", -1))
		var zone := str(entry.get("zone", ""))
		var slot := int(entry.get("slot", -1))
		if zone == "stadium":
			stadium_count += 1
			if stadium_count > 1 or slot != 0:
				return "replay_visual_projection_invalid"
		elif zone == "active":
			if slot != 0:
				return "replay_visual_projection_invalid"
		elif zone == "bench":
			if slot < 0 or slot >= 8:
				return "replay_visual_projection_invalid"
		else:
			return "replay_visual_projection_invalid"
		var identity := "stadium" if zone == "stadium" else "%d|%s|%d" % [seat, zone, slot]
		if occupied.has(identity):
			return "replay_visual_projection_invalid"
		occupied[identity] = true
	return ""


static func _failure(code: String) -> Dictionary:
	return {"accepted": false, "error_code": code, "authoritative": false, "grants": []}
