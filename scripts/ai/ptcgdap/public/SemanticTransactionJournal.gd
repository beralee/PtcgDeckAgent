class_name SemanticTransactionJournal
extends RefCounted

const PlanningScript = preload("res://scripts/ai/ptcgdap/public/PublicDamagePlanning.gd")

var _match_id := ""
var _seat := -1
var _package_identity := ""
var _state: Dictionary = {}


func _init(match_id: String, seat: int, package_identity: String) -> void:
	_match_id = match_id
	_seat = seat
	_package_identity = package_identity


func snapshot() -> Dictionary:
	return _state.duplicate(true)


func clear() -> void:
	_state.clear()


func advance(frame: Variant, definitions: Variant, damage_result: Variant) -> Dictionary:
	return _advance(frame, definitions, damage_result, true)


func advance_compiled(
	frame: Variant,
	policy_hash: Variant,
	execution_plan_hash: Variant,
	damage_result: Variant,
) -> Dictionary:
	var compiled: Dictionary = PlanningScript.compiled_semantic_transactions(
		policy_hash, execution_plan_hash
	)
	if not bool(compiled.get("accepted", false)):
		var error_code := str(compiled.get("error_code", "semantic_transaction_unavailable"))
		return _result(false, error_code, "reject", error_code, _state)
	return _advance(frame, compiled.get("definitions", []), damage_result, false)


func _advance(
	frame: Variant,
	definitions: Variant,
	damage_result: Variant,
	validate_definitions: bool,
) -> Dictionary:
	if PlanningScript._contains_private(frame) \
		or PlanningScript._contains_private(definitions) \
		or PlanningScript._contains_private(damage_result):
		return _result(false, "private_transaction_input", "reject", "private_input", {})
	if not frame is Dictionary or frame.get("seat") != _seat \
		or _match_id.is_empty() or _package_identity.is_empty():
		return _result(false, "scope_mismatch", "reject", "scope_mismatch", _state)
	if validate_definitions:
		var error: String = PlanningScript.validate_semantic_transactions(definitions)
		if not error.is_empty():
			return _result(false, error, "reject", error, _state)
	if not damage_result is Dictionary or not bool(damage_result.get("accepted", false)):
		return _result(false, "damage_plan_unavailable", "reject", "damage_plan_unavailable", _state)
	var turn := int(frame.get("public_state", {}).get("turn_number", 0))
	if not _state.is_empty():
		var definition := _find_definition(definitions, str(_state.get("transaction_id", "")))
		if definition.is_empty():
			var missing_definition := _state.duplicate(true)
			clear()
			return _result(true, "", "abort", "definition_unavailable", missing_definition)
		var candidate := _candidate_by_serial(
			frame, damage_result, str(definition.get("target_role", "")),
			int(_state.get("target_entity_serial", 0))
		)
		if candidate.is_empty():
			var previous := _state.duplicate(true)
			clear()
			return _result(true, "", "abort", "target_unavailable", previous)
		if turn > int(_state.get("deadline_turn", 0)):
			var expired := _state.duplicate(true)
			clear()
			return _result(true, "", "abort", "deadline_expired", expired)
		var old_debt := int(_state.get("remaining_damage_debt", 0))
		var old_energy_debt := int(_state.get("remaining_energy_debt", 0))
		_state["remaining_damage_debt"] = int(candidate.get("remaining_damage_debt", old_debt))
		_state["remaining_energy_debt"] = int(candidate.get("remaining_energy_debt", old_energy_debt))
		if not definition.get("abort_when", []).is_empty() and _conditions_match(
			definition.get("abort_when", []), frame, damage_result, _state, candidate
		):
			var aborted := _state.duplicate(true)
			clear()
			return _result(true, "", "abort", "abort_condition", aborted)
		if not definition.get("success_when", []).is_empty() and _conditions_match(
			definition.get("success_when", []), frame, damage_result, _state, candidate
		):
			_state["phase"] = "complete"
			var completed := _state.duplicate(true)
			clear()
			return _result(true, "", "complete", "success_condition", completed)
		if not definition.get("continue_when", []).is_empty() and not _conditions_match(
			definition.get("continue_when", []), frame, damage_result, _state, candidate
		):
			var invalid := _state.duplicate(true)
			clear()
			return _result(true, "", "abort", "continuation_invalid", invalid)
		_state["phase"] = "active"
		var changed := int(_state.get("remaining_damage_debt", 0)) != old_debt \
			or int(_state.get("remaining_energy_debt", 0)) != old_energy_debt
		return _result(
			true, "", "replan" if changed else "continue",
			"fresh_public_observation" if frame.get("prompt_kind") in definition.get("step_prompt_kinds", []) else "prompt_not_actionable",
			_state
		)
	var eligible: Array = []
	for definition_value: Variant in definitions:
		var definition: Dictionary = definition_value
		if frame.get("prompt_kind") not in definition.get("step_prompt_kinds", []):
			continue
		for candidate_value: Variant in _candidates(
			frame, damage_result, str(definition.get("target_role", ""))
		):
			var candidate: Dictionary = candidate_value
			if _conditions_match(
				definition.get("start_when", []), frame, damage_result, {}, candidate
			):
				eligible.append({
					"priority": int(definition.get("priority", 0)),
					"serial": int(candidate.get("target_entity_serial", 0)),
					"transaction_id": str(definition.get("transaction_id", "")),
					"definition": definition,
					"candidate": candidate,
				})
	if eligible.is_empty():
		return _result(true, "", "idle", "no_eligible_transaction", {})
	eligible.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if left["priority"] != right["priority"]:
			return left["priority"] > right["priority"]
		if left["serial"] != right["serial"]:
			return left["serial"] < right["serial"]
		return left["transaction_id"] < right["transaction_id"]
	)
	var selected: Dictionary = eligible[0]
	var definition: Dictionary = selected["definition"]
	var candidate: Dictionary = selected["candidate"]
	_state = {
		"transaction_id": definition.get("transaction_id"),
		"goal_id": definition.get("goal_id"),
		"phase": "active",
		"target_entity_serial": int(candidate.get("target_entity_serial", 0)),
		"remaining_damage_debt": int(candidate.get("remaining_damage_debt", 0)),
		"remaining_energy_debt": int(candidate.get("remaining_energy_debt", 0)),
		"deadline_turn": turn + int(definition.get("max_own_turns", 1)) - 1,
	}
	if not PlanningScript._exact_keys(_state, PlanningScript.TRANSACTION_STATE_KEYS):
		clear()
		return _result(false, "invalid_transaction_state", "reject", "invalid_state", {})
	return _result(true, "", "start", "best_public_route", _state)


func _find_definition(definitions: Array, transaction_id: String) -> Dictionary:
	for value: Variant in definitions:
		if value is Dictionary and value.get("transaction_id") == transaction_id:
			return value
	return {}


func _candidates(frame: Dictionary, damage_result: Dictionary, target_role: String) -> Array:
	var result: Array = []
	if target_role == "opponent.pokemon":
		for raw: Variant in damage_result.get("targets", {}).values():
			if not raw is Dictionary or not PlanningScript._safe_int(raw.get("target_entity_serial")):
				continue
			var row: Dictionary = raw.duplicate(true)
			row["card_uid"] = _entity_card_uid(frame, "opponent", int(row["target_entity_serial"]))
			row["remaining_damage_debt"] = int(row.get("remaining_debt", 0))
			row["remaining_energy_debt"] = 0
			var serial := int(row.get("target_entity_serial", 0))
			var facts: Dictionary = damage_result.get("facts", {})
			row["is_damage_best"] = serial == facts.get("damage.best_target_entity_serial")
			row["is_transfer_best"] = serial == facts.get("damage.best_transfer_target_entity_serial")
			row["is_gust_best"] = serial == facts.get("damage.best_gust_target_entity_serial")
			result.append(row)
		result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_key := _damage_sort_key(left)
			var right_key := _damage_sort_key(right)
			return left_key < right_key
		)
		return result
	var own: Dictionary = frame.get("public_state", {}).get("self", {})
	for slot_value: Variant in PlanningScript._slots(own):
		var slot: Dictionary = slot_value
		result.append({
			"target_entity_serial": int(slot.get("entity_serial", 0)),
			"card_uid": str(slot.get("local_card_uid", "")),
			"remaining_damage_debt": 0,
			"remaining_energy_debt": maxi(0, int(slot.get("energy_debt", 0))),
			"prize_yield": int(slot.get("prize_value", 1)),
		})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["target_entity_serial"]) < int(right["target_entity_serial"])
	)
	return result


func _candidate_by_serial(
	frame: Dictionary, damage_result: Dictionary, target_role: String, entity_serial: int
) -> Dictionary:
	for candidate: Dictionary in _candidates(frame, damage_result, target_role):
		if int(candidate.get("target_entity_serial", 0)) == entity_serial:
			return candidate
	return {}


func _damage_sort_key(value: Dictionary) -> Array:
	return [
		int(value.get("attack_windows_to_ko", 3)),
		-int(value.get("prize_yield", 0)),
		int(value.get("remaining_debt", 0)),
		int(value.get("overkill", 0)),
		int(value.get("response_risk", 0)),
		int(value.get("target_entity_serial", 9007199254740991)),
	]


func _entity_card_uid(frame: Dictionary, owner: String, entity_serial: int) -> String:
	var state: Dictionary = frame.get("public_state", {}).get(owner, {})
	for slot: Dictionary in PlanningScript._slots(state):
		if int(slot.get("entity_serial", 0)) == entity_serial:
			return str(slot.get("local_card_uid", ""))
	return ""


func _conditions_match(
	conditions: Array, frame: Dictionary, damage_result: Dictionary,
	state: Dictionary, candidate: Dictionary
) -> bool:
	for raw: Variant in conditions:
		var condition: Dictionary = raw
		var actual: Variant = _condition_fact(
			str(condition.get("fact", "")), condition.get("card_uid"), frame,
			damage_result, state, candidate
		)
		if not _compare(actual, str(condition.get("op", "")), condition.get("value")):
			return false
	return true


func _condition_fact(
	fact: String, card_uid: Variant, frame: Dictionary, damage_result: Dictionary,
	state: Dictionary, candidate: Dictionary
) -> Variant:
	if fact.begins_with("damage."):
		return damage_result.get("facts", {}).get(fact)
	if fact.begins_with("transaction.candidate."):
		return candidate.get(fact.trim_prefix("transaction.candidate."))
	if fact.begins_with("transaction."):
		return state.get(fact.trim_prefix("transaction."))
	var public: Dictionary = frame.get("public_state", {})
	var own: Dictionary = public.get("self", {})
	var opponent: Dictionary = public.get("opponent", {})
	var scalars := {
		"prompt_kind": frame.get("prompt_kind"),
		"turn_number": public.get("turn_number"),
		"self.prizes_remaining": own.get("prizes_remaining"),
		"opponent.prizes_remaining": opponent.get("prizes_remaining"),
	}
	if scalars.has(fact):
		return scalars[fact]
	var parts := fact.split(".")
	if parts.size() == 3 and parts[2] == "count_uid" and parts[0] in ["self", "opponent"] \
		and parts[1] in ["hand", "discard", "board"] and card_uid is String:
		var owner_state: Dictionary = public.get(parts[0], {})
		var values: Array = PlanningScript._slots(owner_state) if parts[1] == "board" \
			else owner_state.get(parts[1], [])
		var count := 0
		for value: Variant in values:
			if value is Dictionary and value.get("local_card_uid") == card_uid:
				count += 1
		return count
	return null


func _compare(actual: Variant, op: String, expected: Variant) -> bool:
	match op:
		"eq": return actual == expected
		"ne": return actual != expected
		"lt": return (actual is int or actual is float) and (expected is int or expected is float) and actual < expected
		"lte": return (actual is int or actual is float) and (expected is int or expected is float) and actual <= expected
		"gt": return (actual is int or actual is float) and (expected is int or expected is float) and actual > expected
		"gte": return (actual is int or actual is float) and (expected is int or expected is float) and actual >= expected
		"contains": return (actual is Array or actual is String) and expected in actual
		"not_contains": return (actual is Array or actual is String) and expected not in actual
	return false


func _result(
	accepted: bool, error_code: String, event: String, reason: String, state: Dictionary
) -> Dictionary:
	var payload := {
		"schema_version": 1,
		"event": event,
		"reason": reason,
		"state": state.duplicate(true),
		"public_only": true,
	}
	return {
		"accepted": accepted,
		"error_code": error_code,
		"event": event,
		"reason": reason,
		"state": state.duplicate(true),
		"audit_hash": PlanningScript._tree_hash(payload),
	}
