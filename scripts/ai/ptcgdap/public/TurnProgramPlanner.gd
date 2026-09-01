class_name TurnProgramPlanner
extends RefCounted

const TreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")
const ConditionedValueScript = preload(
	"res://scripts/ai/ptcgdap/public/StateConditionedTransactionValueV2.gd"
)

const MAX_SAFE_INTEGER := 9007199254740991
const PROFILE_ID := "ptcgdap-turn-program-shadow-v1"
const REQUEST_PROFILE_ID := "ptcgdap-turn-program-request-v1"
const VALUE_PROFILE_ID := "ptcgdap-turn-program-value-v1"
const FRAME_PROFILE_ID := "ptcgdap-competitive-public-frame-v2"
const FEATURES := [
	"final_prize_knockout",
	"prize_gain_milli",
	"board_development_milli",
	"attack_pressure_milli",
	"next_turn_continuity_milli",
	"hand_quality_milli",
	"disruption_milli",
	"resource_preservation_milli",
	"risk_milli",
	"unresolved_debt_milli",
]
const WEIGHT_FEATURES := [
	"prize_gain_milli",
	"board_development_milli",
	"attack_pressure_milli",
	"next_turn_continuity_milli",
	"hand_quality_milli",
	"disruption_milli",
	"resource_preservation_milli",
	"risk_milli",
	"unresolved_debt_milli",
]
const PRIVATE_KEYS := {
	"deck_order": true,
	"face_down_prizes": true,
	"private_state": true,
	"private_rng_state": true,
	"search_begin_input": true,
	"callback": true,
	"ticket": true,
	"command": true,
	"object_ref": true,
	"instance_id": true,
	"raw_private_hash": true,
	"training_oracle_identity": true,
}
const REQUEST_KEYS := [
	"schema_version", "profile_id", "source", "value_model", "programs", "base_proofs",
]
const PROGRAM_KEYS := [
	"program_id", "goal_id", "route_id", "deadline_turns", "semantic_steps",
	"public_outcome",
]
const CONDITIONED_PROGRAM_KEYS := [
	"program_id", "goal_id", "route_id", "deadline_turns", "semantic_steps",
	"public_outcome", "public_action_context",
]
const STEP_KEYS := [
	"step_id", "transaction_id", "method_id", "depends_on", "terminal_kind",
]
const PROOF_KEYS := [
	"program_id", "admissible", "current_step_id", "current_step_executable",
	"mandatory_preserved", "terminal_preserved", "base_vetoed",
]
const MODEL_KEYS := ["profile_id", "model_version", "feature_weights_milli"]


static func evaluate(frame: Variant, request: Variant) -> Dictionary:
	if _contains_private(frame) or _contains_private(request):
		return _error("private_turn_program_input")
	var frame_error := _frame_error(frame)
	if not frame_error.is_empty():
		return _error(frame_error)
	var request_error := _request_error(request)
	if not request_error.is_empty():
		return _error(request_error)
	if request.get("source") != frame.get("source"):
		return _error("turn_program_source_mismatch")

	var proof_by_id := {}
	for proof_value: Variant in request.get("base_proofs", []):
		var proof: Dictionary = proof_value
		proof_by_id[proof.get("program_id")] = proof
	var ranked: Array = []
	var candidate_audit: Array = []
	var programs: Array = request.get("programs", [])
	for order: int in programs.size():
		var program: Dictionary = programs[order]
		var proof: Dictionary = proof_by_id.get(program.get("program_id"), {})
		var status := "eligible"
		if bool(proof.get("base_vetoed", false)):
			status = "base_vetoed"
		elif not bool(proof.get("admissible", false)):
			status = "base_not_admissible"
		elif not bool(proof.get("mandatory_preserved", false)):
			status = "mandatory_not_preserved"
		elif not bool(proof.get("terminal_preserved", false)):
			status = "terminal_not_preserved"
		elif not bool(proof.get("current_step_executable", false)):
			status = "current_step_not_executable"
		var utility_result := _utility(frame, program, request.get("value_model", {}))
		if not bool(utility_result.get("accepted", false)):
			return _error(str(utility_result.get("error_code", "state_conditioned_value_failed")))
		var utility_milli := int(utility_result.get("utility", 0))
		var audit_row := {
			"program_id": program.get("program_id"),
			"status": status,
			"current_step_id": proof.get("current_step_id"),
			"utility_milli": utility_milli,
			"final_prize_knockout": int(program.get("public_outcome", {}).get(
				"final_prize_knockout", 0
			)),
			"unresolved_debt_milli": int(program.get("public_outcome", {}).get(
				"unresolved_debt_milli", 0
			)),
		}
		if utility_result.get("conditioned_value") is Dictionary:
			audit_row["conditioned_value"] = utility_result.get("conditioned_value").duplicate(true)
		candidate_audit.append(audit_row)
		if status != "eligible":
			continue
		var outcome: Dictionary = program.get("public_outcome", {})
		ranked.append({
			"rank": [
				-int(outcome.get("final_prize_knockout", 0)),
				-utility_milli,
				int(outcome.get("unresolved_debt_milli", 0)),
				program.get("semantic_steps", []).size(),
				str(program.get("program_id", "")),
				order,
			],
			"program": program,
		})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _rank_less(left.get("rank", []), right.get("rank", []))
	)
	var selected: Variant = ranked[0].get("program") if not ranked.is_empty() else null
	var selected_step: Variant = (
		selected.get("semantic_steps", [])[0]
		if selected is Dictionary and not selected.get("semantic_steps", []).is_empty()
		else null
	)
	var ranked_ids: Array = []
	for entry_value: Variant in ranked:
		ranked_ids.append(entry_value.get("program", {}).get("program_id"))
	var payload := {
		"accepted": true,
		"error_code": "",
		"schema_version": 1,
		"profile_id": PROFILE_ID,
		"mode": "shadow",
		"authoritative": false,
		"public_only": true,
		"source": frame.get("source", {}).duplicate(true),
		"selected_program_id": selected.get("program_id") if selected is Dictionary else null,
		"selected_goal_id": selected.get("goal_id") if selected is Dictionary else null,
		"selected_route_id": selected.get("route_id") if selected is Dictionary else null,
		"selected_current_step_id": selected_step.get("step_id") if selected_step is Dictionary else null,
		"ranked_program_ids": ranked_ids,
		"candidate_audit": candidate_audit,
		"reobserve_before_execution": true,
		"stale_plan_has_authority": false,
	}
	var result := payload.duplicate(true)
	result["audit_hash"] = _audit_hash(payload)
	return result


static func _frame_error(frame: Variant) -> String:
	if not frame is Dictionary \
			or frame.get("schema_version") != 2 \
			or frame.get("profile_id") != FRAME_PROFILE_ID \
			or not _source(frame.get("source")):
		return "invalid_turn_program_frame"
	if not _safe_int(frame.get("seat")) or int(frame.get("seat")) not in [0, 1]:
		return "invalid_turn_program_frame"
	if not _safe_int(frame.get("public_state", {}).get("turn_number")):
		return "invalid_turn_program_frame"
	if not frame.get("options") is Array:
		return "invalid_turn_program_frame"
	return ""


static func _request_error(request: Variant) -> String:
	if (
		not request is Dictionary
		or not _exact_keys(request, REQUEST_KEYS)
		or request.get("schema_version") != 1
		or request.get("profile_id") != REQUEST_PROFILE_ID
		or not _source(request.get("source"))
		or not request.get("programs") is Array
		or request.get("programs", []).is_empty()
		or request.get("programs", []).size() > 32
		or not request.get("base_proofs") is Array
	):
		return "invalid_turn_program_request"
	var model_error := _model_error(request.get("value_model"))
	if not model_error.is_empty():
		return model_error
	var programs := {}
	for program_value: Variant in request.get("programs", []):
		var error := _program_error(
			program_value,
			request.get("value_model", {}).get("profile_id") == ConditionedValueScript.PROFILE_ID
		)
		if not error.is_empty():
			return error
		var program: Dictionary = program_value
		var program_id := str(program.get("program_id", ""))
		if programs.has(program_id):
			return "invalid_turn_program"
		programs[program_id] = program
	if request.get("base_proofs", []).size() != programs.size():
		return "invalid_turn_program_base_proof"
	var proof_ids := {}
	for proof_value: Variant in request.get("base_proofs", []):
		var error := _proof_error(proof_value, programs)
		if not error.is_empty():
			return error
		var proof_id := str(proof_value.get("program_id", ""))
		if proof_ids.has(proof_id):
			return "invalid_turn_program_base_proof"
		proof_ids[proof_id] = true
	if proof_ids.size() != programs.size():
		return "invalid_turn_program_base_proof"
	return ""


static func _model_error(model: Variant) -> String:
	if model is Dictionary and model.get("profile_id") == ConditionedValueScript.PROFILE_ID:
		return ConditionedValueScript.model_error(model)
	if (
		not model is Dictionary
		or not _exact_keys(model, MODEL_KEYS)
		or model.get("profile_id") != VALUE_PROFILE_ID
		or not _safe_int(model.get("model_version"))
		or int(model.get("model_version")) < 1
		or not model.get("feature_weights_milli") is Dictionary
		or not _exact_keys(model.get("feature_weights_milli", {}), WEIGHT_FEATURES)
	):
		return "invalid_turn_program_value_model"
	for weight: Variant in model.get("feature_weights_milli", {}).values():
		if not _safe_int(weight, true):
			return "invalid_turn_program_value_model"
	return ""


static func _program_error(program: Variant, conditioned: bool = false) -> String:
	var expected_keys := CONDITIONED_PROGRAM_KEYS if conditioned else PROGRAM_KEYS
	if (
		not program is Dictionary
		or not _exact_keys(program, expected_keys)
		or not _identifier(program.get("program_id"))
		or not _identifier(program.get("goal_id"))
		or not _identifier(program.get("route_id"))
		or not _safe_int(program.get("deadline_turns"))
		or int(program.get("deadline_turns")) > 8
		or not program.get("semantic_steps") is Array
		or program.get("semantic_steps", []).is_empty()
		or program.get("semantic_steps", []).size() > 32
		or not _outcome_valid(program.get("public_outcome"))
	):
		return "invalid_turn_program"
	if conditioned:
		var context: Variant = program.get("public_action_context")
		if not context is Dictionary or not _exact_keys(context, [
			"card_uids", "source_uids", "target_uids", "kinds", "tags",
			"current_effect_kinds", "current_resource_claims",
		]):
			return "invalid_turn_program"
		for key: Variant in context:
			var values: Variant = context.get(key)
			if not values is Array:
				return "invalid_turn_program"
			var expected: Array = values.duplicate()
			expected.sort()
			var unique := {}
			for item: Variant in values:
				if typeof(item) != TYPE_STRING or str(item).length() > 128 or unique.has(item):
					return "invalid_turn_program"
				unique[item] = true
			if expected != values:
				return "invalid_turn_program"
	var seen := {}
	var terminal_count := 0
	var steps: Array = program.get("semantic_steps", [])
	for offset: int in steps.size():
		var step: Variant = steps[offset]
		if (
			not step is Dictionary
			or not _exact_keys(step, STEP_KEYS)
			or not _identifier(step.get("step_id"))
			or not _identifier(step.get("transaction_id"))
			or not _identifier(step.get("method_id"))
			or not step.get("depends_on") is Array
			or step.get("depends_on", []).size() > 16
			or step.get("terminal_kind") not in ["none", "attack", "end_turn"]
		):
			return "invalid_turn_program"
		var dependencies: Array = step.get("depends_on", [])
		var dependency_ids := {}
		for dependency: Variant in dependencies:
			if not _identifier(dependency) or dependency_ids.has(dependency) \
					or not seen.has(dependency):
				return "invalid_turn_program"
			dependency_ids[dependency] = true
		var step_id := str(step.get("step_id", ""))
		if seen.has(step_id):
			return "invalid_turn_program"
		seen[step_id] = true
		if step.get("terminal_kind") != "none":
			terminal_count += 1
			if offset != steps.size() - 1:
				return "invalid_turn_program"
	if terminal_count > 1:
		return "invalid_turn_program"
	return ""


static func _proof_error(proof: Variant, programs: Dictionary) -> String:
	if (
		not proof is Dictionary
		or not _exact_keys(proof, PROOF_KEYS)
		or not _identifier(proof.get("program_id"))
		or not _identifier(proof.get("current_step_id"))
	):
		return "invalid_turn_program_base_proof"
	for key: String in [
		"admissible", "current_step_executable", "mandatory_preserved",
		"terminal_preserved", "base_vetoed",
	]:
		if typeof(proof.get(key)) != TYPE_BOOL:
			return "invalid_turn_program_base_proof"
	var program: Variant = programs.get(proof.get("program_id"))
	if not program is Dictionary or program.get("semantic_steps", []).is_empty():
		return "invalid_turn_program_base_proof"
	if proof.get("current_step_id") != program.get("semantic_steps", [])[0].get("step_id"):
		return "invalid_turn_program_base_proof"
	return ""


static func _outcome_valid(outcome: Variant) -> bool:
	if not outcome is Dictionary or not _exact_keys(outcome, FEATURES):
		return false
	for feature: String in FEATURES:
		var value: Variant = outcome.get(feature)
		if not _safe_int(value):
			return false
		var maximum := 1 if feature == "final_prize_knockout" else (
			3000 if feature == "prize_gain_milli" else 1000
		)
		if int(value) > maximum:
			return false
	return true


static func _utility(frame: Dictionary, program: Dictionary, model: Dictionary) -> Dictionary:
	if model.get("profile_id") == ConditionedValueScript.PROFILE_ID:
		var conditioned := ConditionedValueScript.score(
			frame, program, program.get("public_outcome", {}), model
		)
		if not bool(conditioned.get("accepted", false)):
			return {
				"accepted": false,
				"error_code": conditioned.get("error_code", "state_conditioned_value_failed"),
			}
		return {
			"accepted": true,
			"error_code": "",
			"utility": int(conditioned.get("total_utility", 0)),
			"conditioned_value": conditioned,
		}
	var outcome: Dictionary = program.get("public_outcome", {})
	var weights: Dictionary = model.get("feature_weights_milli", {})
	var result := 0
	for feature: String in WEIGHT_FEATURES:
		result += int(outcome.get(feature, 0)) * int(weights.get(feature, 0))
	return {"accepted": true, "error_code": "", "utility": result, "conditioned_value": null}


static func _rank_less(left: Array, right: Array) -> bool:
	for offset: int in mini(left.size(), right.size()):
		if left[offset] == right[offset]:
			continue
		if offset == 4:
			return str(left[offset]) < str(right[offset])
		return int(left[offset]) < int(right[offset])
	return left.size() < right.size()


static func _source(value: Variant) -> bool:
	return (
		value is Dictionary
		and _exact_keys(value, ["public_observation_hash", "window_id"])
		and _sha(value.get("public_observation_hash"))
		and _sha(value.get("window_id"))
	)


static func _contains_private(value: Variant) -> bool:
	var stack: Array = [value]
	while not stack.is_empty():
		var current: Variant = stack.pop_back()
		if current is Dictionary:
			for key: Variant in current:
				if typeof(key) != TYPE_STRING or PRIVATE_KEYS.has(str(key).to_lower()):
					return true
				stack.append(current[key])
		elif current is Array:
			stack.append_array(current)
	return false


static func _error(code: String) -> Dictionary:
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


static func _audit_hash(value: Variant) -> String:
	var result: Dictionary = TreeHashScript.hash_tree(value, "public_observation")
	return str(result.get("sha256", "")) if bool(result.get("ok", false)) else ""


static func _exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _safe_int(value: Variant, signed: bool = false) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	if not is_finite(number) or floor(number) != number:
		return false
	return (
		number >= -float(MAX_SAFE_INTEGER) and number <= float(MAX_SAFE_INTEGER)
		if signed
		else number >= 0.0 and number <= float(MAX_SAFE_INTEGER)
	)


static func _sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	for offset: int in 64:
		var code := str(value).unicode_at(offset)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 70)):
			return false
	return true


static func _identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text := str(value)
	if text.is_empty() or text.length() > 128:
		return false
	for offset: int in text.length():
		var code := text.unicode_at(offset)
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) \
				or code in [45, 46, 95]):
			return false
	return true
