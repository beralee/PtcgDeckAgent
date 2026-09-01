class_name TurnTransactionJournal
extends RefCounted

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


func advance(frame: Variant, definitions: Variant, matches: Callable) -> Dictionary:
	if (
		not frame is Dictionary or frame.get("seat") != _seat
		or _match_id.is_empty() or _package_identity.is_empty()
	):
		return _result(false, "turn_transaction_scope_mismatch", "rejected", "scope_mismatch")
	if not definitions is Array or not matches.is_valid():
		return _result(false, "invalid_turn_transaction_input", "rejected", "invalid_input")
	var turn_value: Variant = frame.get("public_state", {}).get("turn_number")
	if typeof(turn_value) != TYPE_INT or int(turn_value) < 0:
		return _result(false, "invalid_turn_transaction_frame", "rejected", "turn_unknown")
	var turn_number := int(turn_value)
	var definitions_by_id := {}
	for definition_value: Variant in definitions:
		if definition_value is Dictionary:
			definitions_by_id[definition_value.get("transaction_id")] = definition_value
	var event := "continued"
	var active: Variant = definitions_by_id.get(_state.get("transaction_id"))
	if active is Dictionary:
		var goal_id := str(active.get("goal_id", ""))
		if int(_state.get("deadline_turn", turn_number)) < turn_number:
			clear()
			active = null
			event = "expired"
		elif not active.get("abort_when", []).is_empty() and bool(matches.call(
			active.get("abort_when", []), null, goal_id
		)):
			clear()
			active = null
			event = "aborted"
		elif not active.get("success_when", []).is_empty() and bool(matches.call(
			active.get("success_when", []), null, goal_id
		)):
			clear()
			active = null
			event = "completed"
		if active is Dictionary:
			var continue_when: Array = active.get(
				"continue_when", active.get("when", [])
			)
			if not continue_when.is_empty() and not bool(matches.call(
				continue_when, null, goal_id
			)):
				# Semantic identity may persist, but current public state must prove
				# the continuation predicate before it owns another window.
				clear()
				active = null
				event = "continuation_invalidated"
	elif not _state.is_empty():
		clear()
		event = "definition_missing"

	if active == null:
		var eligible: Array = []
		for definition_value: Variant in definitions:
			var definition: Dictionary = definition_value
			var goal_id := str(definition.get("goal_id", ""))
			if not bool(matches.call(definition.get("when", []), null, goal_id)):
				continue
			if not definition.get("success_when", []).is_empty() and bool(matches.call(
				definition.get("success_when", []), null, goal_id
			)):
				continue
			if not definition.get("abort_when", []).is_empty() and bool(matches.call(
				definition.get("abort_when", []), null, goal_id
			)):
				continue
			eligible.append({"order": eligible.size(), "definition": definition})
		eligible.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_definition: Dictionary = left.get("definition", {})
			var right_definition: Dictionary = right.get("definition", {})
			if int(left_definition.get("priority", 0)) != int(right_definition.get("priority", 0)):
				return int(left_definition.get("priority", 0)) > int(right_definition.get("priority", 0))
			return int(left.get("order", 0)) < int(right.get("order", 0))
		)
		if not eligible.is_empty():
			active = eligible[0].get("definition")
			_state = {
				"transaction_id": active.get("transaction_id"),
				"method_id": "",
				"start_turn": turn_number,
				"deadline_turn": turn_number + int(active.get("deadline_turns", 0)),
			}
			event = "started"
	if active == null:
		return _result(true, "", "idle", event)

	var method := _method(active, matches)
	if method.is_empty():
		clear()
		return _result(true, "", "retired", "no_applicable_method")
	_state["method_id"] = method.get("method_id")
	var required_steps := _required_steps(method, matches)
	if required_steps.is_empty():
		clear()
		return _result(true, "", "retired", "method_complete")
	var step: Dictionary = {}
	var current_indexes: Array = []
	for candidate_step_value: Variant in required_steps:
		var candidate_step: Dictionary = candidate_step_value
		if frame.get("prompt_kind") not in candidate_step.get("prompt_kinds", []):
			continue
		var candidate_indexes: Array = []
		for option_value: Variant in frame.get("options", []):
			var option: Dictionary = option_value
			if bool(matches.call(
				candidate_step.get("option_when", []), option,
				str(candidate_step.get("goal_id", ""))
			)):
				candidate_indexes.append(int(option.get("index", -1)))
		var grouped_indexes: Variant = _selection_group_indexes(
			candidate_step, frame.get("options", []), candidate_indexes, matches
		)
		if grouped_indexes == null:
			continue
		candidate_indexes = grouped_indexes
		var selection_count: Variant = candidate_step.get("selection_count")
		var minimum := int(frame.get("select_semantics", {}).get("min_count", 0))
		var maximum := int(frame.get("select_semantics", {}).get("max_count", 0))
		if selection_count != null and (
			int(selection_count) < minimum or int(selection_count) > maximum
			or int(selection_count) > candidate_indexes.size()
		):
			continue
		if not candidate_indexes.is_empty():
			step = candidate_step
			current_indexes = candidate_indexes
			break
	if step.is_empty():
		return _result(
			true, "", "no_current_safe_step", "fresh_window_has_no_executable_binding",
			active, method, required_steps[0], [], false
		)
	var has_attack := false
	var has_turn_commit := false
	for option_value: Variant in frame.get("options", []):
		if not option_value is Dictionary:
			continue
		var option_kind: Variant = option_value.get("kind")
		if option_kind in ["attack", "granted_attack"]:
			has_attack = true
		if option_kind == "end_turn":
			has_turn_commit = true
	has_turn_commit = has_turn_commit or has_attack
	var attack_blocked := bool(step.get("required_before_attack", false)) and has_attack
	var turn_commit_blocked := (
		bool(step.get("required_before_attack", false)) and has_turn_commit
	)
	return _result(
		true, "", "step_bound", event, active, method, step,
		current_indexes, attack_blocked, turn_commit_blocked
	)


func _selection_group_indexes(
	step: Dictionary,
	options: Array,
	candidate_indexes: Array,
	matches: Callable,
) -> Variant:
	var groups: Array = step.get("selection_groups", [])
	if groups.is_empty():
		return candidate_indexes
	var allowed := {}
	for index: Variant in candidate_indexes:
		allowed[int(index)] = true
	var used := {}
	var selected: Array = []
	for group_value: Variant in groups:
		var group: Dictionary = group_value
		var group_indexes: Array = []
		for option_value: Variant in options:
			var option: Dictionary = option_value
			var index := int(option.get("index", -1))
			if not allowed.has(index) or used.has(index):
				continue
			if bool(matches.call(
				group.get("option_when", []), option, str(step.get("goal_id", ""))
			)):
				group_indexes.append(index)
		var count := int(group.get("selection_count", 0))
		if group_indexes.size() < count:
			return null
		for offset: int in count:
			var selected_index: int = group_indexes[offset]
			used[selected_index] = true
			selected.append(selected_index)
	return selected


func _method(active: Dictionary, matches: Callable) -> Dictionary:
	var applicable: Array = []
	for method_value: Variant in active.get("methods", []):
		var method: Dictionary = method_value
		if bool(matches.call(
			method.get("when", []), null, str(active.get("goal_id", ""))
		)):
			applicable.append({"order": applicable.size(), "method": method})
	if applicable.is_empty():
		return {}
	for entry_value: Variant in applicable:
		var candidate: Dictionary = entry_value.get("method", {})
		if candidate.get("method_id") == _state.get("method_id"):
			return candidate
	applicable.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_method: Dictionary = left.get("method", {})
		var right_method: Dictionary = right.get("method", {})
		if int(left_method.get("priority", 0)) != int(right_method.get("priority", 0)):
			return int(left_method.get("priority", 0)) > int(right_method.get("priority", 0))
		return int(left.get("order", 0)) < int(right.get("order", 0))
	)
	return applicable[0].get("method", {})


func _required_steps(method: Dictionary, matches: Callable) -> Array:
	var required: Array = []
	for step_value: Variant in method.get("steps", []):
		var step: Dictionary = step_value
		if not step.get("complete_when", []).is_empty() and bool(matches.call(
			step.get("complete_when", []), null, str(step.get("goal_id", ""))
		)):
			continue
		if not step.get("required_when", []).is_empty() and not bool(matches.call(
			step.get("required_when", []), null, str(step.get("goal_id", ""))
		)):
			continue
		required.append(step)
	return required


func _result(
	accepted: bool,
	error_code: String,
	event: String,
	reason: String,
	active: Variant = null,
	method: Variant = null,
	step: Variant = null,
	current_indexes: Array = [],
	attack_commit_blocked: bool = false,
	turn_commit_blocked: bool = false,
) -> Dictionary:
	var payload := {
		"accepted": accepted,
		"error_code": error_code,
		"event": event,
		"reason": reason,
		"transaction_id": active.get("transaction_id") if active is Dictionary else null,
		"method_id": method.get("method_id") if method is Dictionary else null,
		"step_id": step.get("step_id") if step is Dictionary else null,
		"goal_id": step.get("goal_id") if step is Dictionary else null,
		"current_indexes": current_indexes.duplicate(),
		"selection_count": step.get("selection_count") if step is Dictionary else null,
		"score_bonus": int(step.get("score_bonus", 0)) if step is Dictionary else 0,
		"terminal": bool(step.get("terminal", false)) if step is Dictionary else false,
		"checkpoint": bool(step.get("checkpoint", false)) if step is Dictionary else false,
		"sequence_barrier": bool(step.get("sequence_barrier", false)) if step is Dictionary else false,
		"required_before_attack": bool(step.get("required_before_attack", false)) if step is Dictionary else false,
		"attack_commit_blocked": attack_commit_blocked,
		"turn_commit_blocked": turn_commit_blocked,
		"state": _state.duplicate(true),
		"public_current_window_only": true,
		"reobserve_after_commit": true,
		"stale_index_authority": false,
	}
	var hashed: Dictionary = TreeHashScript.hash_tree(payload, "public_observation")
	payload["audit_hash"] = str(hashed.get("hash", "")) if bool(hashed.get("ok", false)) else ""
	return payload
