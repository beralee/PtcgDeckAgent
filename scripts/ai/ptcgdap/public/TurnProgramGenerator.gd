class_name TurnProgramGenerator
extends RefCounted

const TreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")
const TransitionEvaluatorScript = preload(
	"res://scripts/ai/ptcgdap/public/TurnProgramTransitionEvaluator.gd"
)
const ConditionedValueScript = preload(
	"res://scripts/ai/ptcgdap/public/StateConditionedTransactionValueV2.gd"
)

const PROFILE_ID := "ptcgdap-turn-program-generator-v1"
const FRAME_PROFILE_ID := "ptcgdap-competitive-public-frame-v2"
const REQUEST_PROFILE_ID := "ptcgdap-turn-program-request-v1"
const VALUE_PROFILE_ID := "ptcgdap-turn-program-value-v1"
const MAX_SAFE_INTEGER := 9007199254740991
const FEATURES := [
	"final_prize_knockout", "prize_gain_milli", "board_development_milli",
	"attack_pressure_milli", "next_turn_continuity_milli", "hand_quality_milli",
	"disruption_milli", "resource_preservation_milli", "risk_milli",
	"unresolved_debt_milli",
]
const WEIGHT_FEATURES := [
	"prize_gain_milli", "board_development_milli", "attack_pressure_milli",
	"next_turn_continuity_milli", "hand_quality_milli", "disruption_milli",
	"resource_preservation_milli", "risk_milli", "unresolved_debt_milli",
]
const DEFAULT_VALUE_MODEL := {
	"profile_id": VALUE_PROFILE_ID,
	"model_version": 1,
	"feature_weights_milli": {
		"prize_gain_milli": 4000,
		"board_development_milli": 900,
		"attack_pressure_milli": 1100,
		"next_turn_continuity_milli": 1300,
		"hand_quality_milli": 500,
		"disruption_milli": 700,
		"resource_preservation_milli": 800,
		"risk_milli": -2000,
		"unresolved_debt_milli": -1000,
	},
}
const CANDIDATE_KEYS := [
	"program_id", "goal_id", "route_id", "deadline_turns", "priority",
	"source_kind", "semantic_steps", "current_step_id", "current_option_facts",
	"terminal_option_facts", "base_proof",
]
const STEP_KEYS := [
	"step_id", "transaction_id", "method_id", "depends_on", "terminal_kind",
	"effect_kind",
]
const OPTIONAL_STEP_KEYS := ["resource_claim"]
const RESOURCE_CLAIMS := ["none", "supporter", "manual_attachment", "retreat", "unknown"]
const OUTPUT_STEP_KEYS := [
	"step_id", "transaction_id", "method_id", "depends_on", "terminal_kind",
]
const OPTION_FACT_KEYS := [
	"kind", "projected_damage", "projected_knockout", "target_remaining_hp",
	"target_prize_value",
]
const OPTION_FACT_CONTEXT_KEYS := ["card_uid", "source_uid", "target_uid", "tags"]
const PROOF_KEYS := [
	"admissible", "current_step_executable", "mandatory_preserved",
	"terminal_preserved", "base_vetoed",
]
const SOURCE_KINDS := [
	"turn_transaction", "turn_route", "base_action", "base_terminal",
]
const TERMINAL_KINDS := ["none", "attack", "end_turn"]
const EFFECT_KINDS := [
	"ability", "attack", "bench", "conversion", "damage_transfer",
	"disruption", "draw", "end_turn", "energy", "evolution", "handoff",
	"search", "tool",
]
const EFFECT_VALUES := {
	"ability": {"board_development_milli": 100, "next_turn_continuity_milli": 140},
	"bench": {"board_development_milli": 220, "next_turn_continuity_milli": 260},
	"conversion": {"attack_pressure_milli": 220, "next_turn_continuity_milli": 120},
	"damage_transfer": {"attack_pressure_milli": 260, "next_turn_continuity_milli": 180},
	"disruption": {"hand_quality_milli": 80, "disruption_milli": 620, "next_turn_continuity_milli": 120},
	"draw": {"hand_quality_milli": 520, "next_turn_continuity_milli": 100},
	"energy": {"board_development_milli": 180, "attack_pressure_milli": 120, "next_turn_continuity_milli": 280},
	"evolution": {"board_development_milli": 320, "next_turn_continuity_milli": 300},
	"handoff": {"attack_pressure_milli": 160, "next_turn_continuity_milli": 160},
	"search": {"board_development_milli": 100, "hand_quality_milli": 260, "next_turn_continuity_milli": 180},
	"tool": {"board_development_milli": 100, "next_turn_continuity_milli": 140},
}
const RESOURCE_COST := {
	"ability": 10, "attack": 0, "bench": 70, "conversion": 100,
	"damage_transfer": 10, "disruption": 120, "draw": 120, "end_turn": 0,
	"energy": 80, "evolution": 80, "handoff": 50, "search": 90, "tool": 90,
}


static func generate(
	frame: Variant,
	candidates: Variant,
	max_programs: int = 8,
	value_model: Variant = null,
) -> Dictionary:
	var model: Variant = DEFAULT_VALUE_MODEL.duplicate(true) \
		if value_model == null else value_model.duplicate(true) \
		if value_model is Dictionary else value_model
	if not _frame_error(frame).is_empty():
		return _error(_frame_error(frame))
	if not candidates is Array or candidates.is_empty() or candidates.size() > 64 \
			or max_programs < 1 or max_programs > 8 or not _model_valid(model):
		return _error("invalid_turn_program_generation_request")
	var normalized: Array = candidates.duplicate(true)
	var seen := {}
	for candidate_value: Variant in normalized:
		var candidate_error := _candidate_error(candidate_value)
		if not candidate_error.is_empty():
			return _error(candidate_error)
		var program_id := str(candidate_value.get("program_id", ""))
		if seen.has(program_id):
			return _error("duplicate_turn_program_candidate")
		seen[program_id] = true
	var visible_debt_count := 0
	for candidate_value: Variant in normalized:
		var candidate: Dictionary = candidate_value
		var proof: Dictionary = candidate.get("base_proof", {})
		if not bool(proof.get("admissible", false)) \
				or not bool(proof.get("current_step_executable", false)) \
				or bool(proof.get("base_vetoed", false)):
			continue
		var debt := 0
		for step_value: Variant in candidate.get("semantic_steps", []):
			if step_value.get("terminal_kind") == "none":
				debt += 1
		visible_debt_count = maxi(visible_debt_count, debt)
	var prizes_remaining: Variant = frame.get("public_state", {}).get("self", {}).get(
		"prizes_remaining", 0
	)
	if not _safe_int(prizes_remaining) or int(prizes_remaining) > 6:
		return _error("invalid_turn_program_generation_frame")

	var materialized: Array = []
	var audit_rows: Array = []
	for candidate_value: Variant in normalized:
		var candidate: Dictionary = candidate_value
		var transition: Dictionary = TransitionEvaluatorScript.evaluate(
			frame, candidate, visible_debt_count
		)
		if not bool(transition.get("accepted", false)):
			return _error(str(transition.get(
				"error_code", "turn_program_transition_failed"
			)))
		var outcome := _outcome(candidate, int(prizes_remaining), visible_debt_count)
		var proof: Dictionary = candidate.get("base_proof", {})
		var admitted := (
			bool(proof.get("admissible", false))
			and bool(proof.get("current_step_executable", false))
			and bool(proof.get("mandatory_preserved", false))
			and bool(proof.get("terminal_preserved", false))
			and not bool(proof.get("base_vetoed", false))
		)
		var semantic_steps: Array = []
		for step_value: Variant in candidate.get("semantic_steps", []):
			var step: Dictionary = step_value
			var output_step := {}
			for key: String in OUTPUT_STEP_KEYS:
				output_step[key] = step.get(key) if key != "depends_on" else step.get(key, []).duplicate()
			semantic_steps.append(output_step)
		var program := {
			"program_id": candidate.get("program_id"),
			"goal_id": candidate.get("goal_id"),
			"route_id": candidate.get("route_id"),
			"deadline_turns": candidate.get("deadline_turns"),
			"semantic_steps": semantic_steps,
			"public_outcome": outcome,
		}
		if model.get("profile_id") == ConditionedValueScript.PROFILE_ID:
			program["public_action_context"] = _public_action_context(candidate)
		var conditioned_value: Variant = null
		var utility := 0
		if model.get("profile_id") == ConditionedValueScript.PROFILE_ID:
			conditioned_value = ConditionedValueScript.score(frame, program, outcome, model)
			if not bool(conditioned_value.get("accepted", false)):
				return _error(str(conditioned_value.get(
					"error_code", "state_conditioned_value_failed"
				)))
			utility = int(conditioned_value.get("total_utility"))
		else:
			utility = _utility(outcome, model)
		var audit_row := {
			"program_id": candidate.get("program_id"),
			"source_kind": candidate.get("source_kind"),
			"priority": candidate.get("priority"),
			"admitted": admitted,
			"emitted": false,
			"utility": utility,
			"public_outcome": outcome.duplicate(true),
			"transition_evaluation": transition.duplicate(true),
		}
		if conditioned_value is Dictionary:
			audit_row["conditioned_value"] = conditioned_value.duplicate(true)
		audit_rows.append(audit_row)
		if not admitted:
			continue
		var base_proof := {
			"program_id": candidate.get("program_id"),
			"current_step_id": candidate.get("current_step_id"),
		}
		for key: String in PROOF_KEYS:
			base_proof[key] = proof.get(key)
		materialized.append({
			"rank": [
				-int(outcome.get("final_prize_knockout", 0)),
				-utility,
				-int(candidate.get("priority", 0)),
				str(candidate.get("program_id", "")),
			],
			"program": program,
			"proof": base_proof,
			"audit_index": audit_rows.size() - 1,
		})
	if materialized.is_empty():
		return _error("no_admissible_turn_program_candidates")
	materialized.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _rank_less(left.get("rank", []), right.get("rank", []))
	)
	var programs: Array = []
	var proofs: Array = []
	for offset: int in mini(max_programs, materialized.size()):
		var entry: Dictionary = materialized[offset]
		programs.append(entry.get("program", {}).duplicate(true))
		proofs.append(entry.get("proof", {}).duplicate(true))
		audit_rows[int(entry.get("audit_index", -1))]["emitted"] = true
	var request := {
		"schema_version": 1,
		"profile_id": REQUEST_PROFILE_ID,
		"source": frame.get("source", {}).duplicate(true),
		"value_model": model.duplicate(true),
		"programs": programs,
		"base_proofs": proofs,
	}
	var payload := {
		"accepted": true,
		"error_code": "",
		"profile_id": PROFILE_ID,
		"mode": "shadow",
		"authoritative": false,
		"public_only": true,
		"candidate_count": normalized.size(),
		"emitted_count": programs.size(),
		"request": request,
		"candidate_audit": audit_rows,
	}
	var result := payload.duplicate(true)
	result["audit_hash"] = _audit_hash(payload)
	return result


static func default_value_model() -> Dictionary:
	return DEFAULT_VALUE_MODEL.duplicate(true)


static func _outcome(candidate: Dictionary, prizes_remaining: int, visible_debt_count: int) -> Dictionary:
	var outcome := {}
	for feature: String in FEATURES:
		outcome[feature] = 0
	var steps: Array = candidate.get("semantic_steps", [])
	var nonterminal_count := 0
	for step_value: Variant in steps:
		var step: Dictionary = step_value
		if step.get("terminal_kind") != "none":
			continue
		nonterminal_count += 1
		var values: Dictionary = EFFECT_VALUES.get(step.get("effect_kind"), {})
		for feature: Variant in values:
			outcome[feature] = mini(1000, int(outcome.get(feature, 0)) + int(values[feature]))
	var terminal: Variant = _best_terminal(candidate.get("terminal_option_facts", []))
	if terminal == null and steps[-1].get("terminal_kind") == "attack":
		terminal = _best_terminal(candidate.get("current_option_facts", []))
	if terminal is Dictionary:
		var damage: Variant = terminal.get("projected_damage")
		outcome["attack_pressure_milli"] = mini(1000, maxi(
			int(outcome.get("attack_pressure_milli", 0)),
			300 if damage == null else int(damage) * 4
		))
		var prize_yield := _fact_int(terminal.get("target_prize_value")) \
			if bool(terminal.get("projected_knockout", false)) else 0
		outcome["prize_gain_milli"] = mini(3000, prize_yield * 1000)
		var current_attack: Variant = _best_terminal(candidate.get("current_option_facts", []))
		outcome["final_prize_knockout"] = int(
			steps[0].get("terminal_kind") == "attack"
			and current_attack is Dictionary
			and bool(current_attack.get("projected_knockout", false))
			and _fact_int(current_attack.get("target_prize_value")) > 0
			and prizes_remaining <= _fact_int(current_attack.get("target_prize_value"))
		)
	outcome["next_turn_continuity_milli"] = mini(
		1000,
		int(outcome.get("next_turn_continuity_milli", 0))
			+ mini(260, int(int(candidate.get("priority", 0)) / 25))
	)
	var resource_cost := 0
	for step_value: Variant in steps:
		resource_cost += int(RESOURCE_COST.get(step_value.get("effect_kind"), 0))
	outcome["resource_preservation_milli"] = maxi(0, 720 - resource_cost)
	outcome["unresolved_debt_milli"] = mini(
		1000, maxi(0, visible_debt_count - nonterminal_count) * 250
	)
	var future_steps := maxi(0, steps.size() - 1)
	var no_terminal: bool = steps[-1].get("terminal_kind") == "none"
	var unknown_attack: bool = (
		steps[-1].get("terminal_kind") == "attack" and terminal == null
	)
	outcome["risk_milli"] = mini(
		1000, future_steps * 55 + (260 if no_terminal else 0) + (180 if unknown_attack else 0)
	)
	return outcome


static func _best_terminal(facts: Array) -> Variant:
	var best: Variant = null
	var best_rank: Array = []
	for fact_value: Variant in facts:
		if not fact_value is Dictionary or fact_value.get("kind") not in ["attack", "granted_attack"]:
			continue
		var rank := [
			int(bool(fact_value.get("projected_knockout", false))),
			_fact_int(fact_value.get("target_prize_value")),
			_fact_int(fact_value.get("projected_damage")),
			-_fact_int(fact_value.get("target_remaining_hp")),
		]
		if best == null or _rank_less(best_rank, rank):
			best = fact_value
			best_rank = rank
	return best


static func _utility(outcome: Dictionary, value_model: Dictionary) -> int:
	var result := 0
	var weights: Dictionary = value_model.get("feature_weights_milli", {})
	for feature: String in WEIGHT_FEATURES:
		result += int(outcome.get(feature, 0)) * int(weights.get(feature, 0))
	return result


static func _public_action_context(candidate: Dictionary) -> Dictionary:
	var cards := {}
	var sources := {}
	var targets := {}
	var kinds := {}
	var tags := {}
	for fact_value: Variant in candidate.get("current_option_facts", []):
		if not fact_value is Dictionary:
			continue
		if fact_value.get("card_uid") != null:
			cards[str(fact_value.get("card_uid"))] = true
		if fact_value.get("source_uid") != null:
			sources[str(fact_value.get("source_uid"))] = true
		if fact_value.get("target_uid") != null:
			targets[str(fact_value.get("target_uid"))] = true
		kinds[str(fact_value.get("kind"))] = true
		for tag: Variant in fact_value.get("tags", []):
			tags[str(tag)] = true
	var result := {
		"card_uids": cards.keys(), "source_uids": sources.keys(),
		"target_uids": targets.keys(), "kinds": kinds.keys(), "tags": tags.keys(),
		"current_effect_kinds": [str(candidate.get("semantic_steps", [])[0].get("effect_kind"))],
		"current_resource_claims": [str(candidate.get("semantic_steps", [])[0].get(
			"resource_claim", "none"
		) if candidate.get("semantic_steps", [])[0].get("resource_claim") != null else "none")],
	}
	for key: Variant in result:
		result[key].sort()
	return result


static func _model_valid(value: Variant) -> bool:
	if value is Dictionary and value.get("profile_id") == ConditionedValueScript.PROFILE_ID:
		return ConditionedValueScript.is_model(value)
	if not value is Dictionary or not _exact_keys(value, [
		"profile_id", "model_version", "feature_weights_milli",
	]) or value.get("profile_id") != VALUE_PROFILE_ID \
			or not _safe_int(value.get("model_version")) \
			or int(value.get("model_version")) < 1 \
			or not value.get("feature_weights_milli") is Dictionary \
			or not _exact_keys(value.get("feature_weights_milli", {}), WEIGHT_FEATURES):
		return false
	for weight: Variant in value.get("feature_weights_milli", {}).values():
		if not _safe_signed_int(weight):
			return false
	return true


static func _fact_int(value: Variant) -> int:
	return 0 if value == null else int(value)


static func _candidate_error(candidate: Variant) -> String:
	if not candidate is Dictionary or not _exact_keys(candidate, CANDIDATE_KEYS) \
			or not _identifier(candidate.get("program_id")) \
			or not _identifier(candidate.get("goal_id")) \
			or not _identifier(candidate.get("route_id")) \
			or not _identifier(candidate.get("current_step_id")) \
			or not _safe_int(candidate.get("deadline_turns")) \
			or int(candidate.get("deadline_turns")) > 8 \
			or not _safe_int(candidate.get("priority")) \
			or candidate.get("source_kind") not in SOURCE_KINDS \
			or not candidate.get("semantic_steps") is Array \
			or candidate.get("semantic_steps", []).is_empty() \
			or candidate.get("semantic_steps", []).size() > 32 \
			or not candidate.get("current_option_facts") is Array \
			or candidate.get("current_option_facts", []).is_empty() \
			or candidate.get("current_option_facts", []).size() > 32 \
			or not candidate.get("terminal_option_facts") is Array \
			or candidate.get("terminal_option_facts", []).size() > 32 \
			or not candidate.get("base_proof") is Dictionary \
			or not _exact_keys(candidate.get("base_proof", {}), PROOF_KEYS):
		return "invalid_turn_program_candidate"
	for key: String in PROOF_KEYS:
		if typeof(candidate.get("base_proof", {}).get(key)) != TYPE_BOOL:
			return "invalid_turn_program_candidate"
	var seen := {}
	var terminal_count := 0
	var steps: Array = candidate.get("semantic_steps", [])
	for offset: int in steps.size():
		var step: Variant = steps[offset]
		if not step is Dictionary or not _required_optional_keys(
			step, STEP_KEYS, OPTIONAL_STEP_KEYS
		) \
				or not _identifier(step.get("step_id")) \
				or not _identifier(step.get("transaction_id")) \
				or not _identifier(step.get("method_id")) \
				or not step.get("depends_on") is Array \
				or step.get("depends_on", []).size() > 16 \
				or step.get("terminal_kind") not in TERMINAL_KINDS \
				or step.get("effect_kind") not in EFFECT_KINDS \
				or (step.has("resource_claim") and step.get("resource_claim") != null \
				and step.get("resource_claim") not in RESOURCE_CLAIMS):
			return "invalid_turn_program_candidate"
		var dependencies := {}
		for dependency: Variant in step.get("depends_on", []):
			if not _identifier(dependency) or dependencies.has(dependency) or not seen.has(dependency):
				return "invalid_turn_program_candidate"
			dependencies[dependency] = true
		var step_id := str(step.get("step_id", ""))
		if seen.has(step_id):
			return "invalid_turn_program_candidate"
		seen[step_id] = true
		if step.get("terminal_kind") != "none":
			terminal_count += 1
			if offset != steps.size() - 1:
				return "invalid_turn_program_candidate"
	if terminal_count > 1 or candidate.get("current_step_id") != steps[0].get("step_id"):
		return "invalid_turn_program_candidate"
	for fact_value: Variant in candidate.get("current_option_facts", []) + candidate.get("terminal_option_facts", []):
		if not fact_value is Dictionary or not _required_optional_keys(
			fact_value, OPTION_FACT_KEYS, OPTION_FACT_CONTEXT_KEYS
		) \
				or typeof(fact_value.get("kind")) != TYPE_STRING \
				or str(fact_value.get("kind", "")).is_empty() \
				or typeof(fact_value.get("projected_knockout")) != TYPE_BOOL:
			return "invalid_turn_program_candidate"
		for key: String in ["projected_damage", "target_remaining_hp", "target_prize_value"]:
			var value: Variant = fact_value.get(key)
			if value != null and not _safe_int(value):
				return "invalid_turn_program_candidate"
		if fact_value.get("target_prize_value") != null \
				and int(fact_value.get("target_prize_value")) > 3:
			return "invalid_turn_program_candidate"
		for key: String in ["card_uid", "source_uid", "target_uid"]:
			var uid: Variant = fact_value.get(key)
			if uid != null and (typeof(uid) != TYPE_STRING or str(uid).is_empty() \
					or str(uid).length() > 128):
				return "invalid_turn_program_candidate"
		var fact_tags: Variant = fact_value.get("tags", [])
		if not fact_tags is Array or fact_tags.size() > 32:
			return "invalid_turn_program_candidate"
		for tag: Variant in fact_tags:
			if typeof(tag) != TYPE_STRING or str(tag).length() > 64:
				return "invalid_turn_program_candidate"
	return ""


static func _frame_error(frame: Variant) -> String:
	if not frame is Dictionary or frame.get("schema_version") != 2 \
			or frame.get("profile_id") != FRAME_PROFILE_ID \
			or not _source(frame.get("source")) \
			or not _safe_int(frame.get("seat")) or int(frame.get("seat")) not in [0, 1] \
			or not _safe_int(frame.get("public_state", {}).get("turn_number")) \
			or not frame.get("options") is Array:
		return "invalid_turn_program_generation_frame"
	return ""


static func _error(code: String) -> Dictionary:
	return {
		"accepted": false, "error_code": code, "profile_id": PROFILE_ID,
		"mode": "shadow", "authoritative": false, "public_only": true,
		"candidate_count": 0, "emitted_count": 0, "request": null,
		"candidate_audit": [], "audit_hash": "",
	}


static func _rank_less(left: Array, right: Array) -> bool:
	for offset: int in mini(left.size(), right.size()):
		if left[offset] == right[offset]:
			continue
		if typeof(left[offset]) == TYPE_STRING or typeof(right[offset]) == TYPE_STRING:
			return str(left[offset]) < str(right[offset])
		return int(left[offset]) < int(right[offset])
	return left.size() < right.size()


static func _audit_hash(value: Variant) -> String:
	var result: Dictionary = TreeHashScript.hash_tree(value, "public_observation")
	return str(result.get("sha256", "")) if bool(result.get("ok", false)) else ""


static func _source(value: Variant) -> bool:
	return value is Dictionary and _exact_keys(value, ["public_observation_hash", "window_id"]) \
		and _sha(value.get("public_observation_hash")) and _sha(value.get("window_id"))


static func _exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _required_optional_keys(
	value: Dictionary, required: Array, optional: Array
) -> bool:
	for key: Variant in required:
		if not value.has(key):
			return false
	for key: Variant in value:
		if key not in required and key not in optional:
			return false
	return true


static func _safe_int(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return is_finite(number) and floor(number) == number \
		and number >= 0.0 and number <= float(MAX_SAFE_INTEGER)


static func _safe_signed_int(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return is_finite(number) and floor(number) == number \
		and number >= -float(MAX_SAFE_INTEGER) and number <= float(MAX_SAFE_INTEGER)


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
