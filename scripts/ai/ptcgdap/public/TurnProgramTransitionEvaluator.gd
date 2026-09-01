class_name TurnProgramTransitionEvaluator
extends RefCounted

const TreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")

const PROFILE_ID := "ptcgdap-turn-program-transition-v1"
const OUTCOME_GATE_PROFILE_ID := "ptcgdap-turn-program-outcome-gate-v1"
const DELTA_BY_EFFECT := {
	"ability": {"board_development_milli": 100, "next_turn_continuity_milli": 140},
	"bench": {"board_development_milli": 220, "next_turn_continuity_milli": 260},
	"conversion": {"attack_pressure_milli": 220, "next_turn_continuity_milli": 120},
	"damage_transfer": {"attack_pressure_milli": 260, "next_turn_continuity_milli": 180},
	"disruption": {"disruption_milli": 620, "next_turn_continuity_milli": 120},
	"draw": {"hand_quality_milli": 520, "next_turn_continuity_milli": 100},
	"energy": {
		"board_development_milli": 180, "attack_pressure_milli": 120,
		"next_turn_continuity_milli": 280,
	},
	"evolution": {"board_development_milli": 320, "next_turn_continuity_milli": 300},
	"handoff": {"attack_pressure_milli": 160, "next_turn_continuity_milli": 160},
	"search": {
		"board_development_milli": 100, "hand_quality_milli": 260,
		"next_turn_continuity_milli": 180,
	},
	"tool": {"board_development_milli": 100, "next_turn_continuity_milli": 140},
}
const BASE_UNCERTAINTY := {
	"ability": 120, "attack": 100, "bench": 80, "conversion": 180,
	"damage_transfer": 100, "disruption": 100, "draw": 100,
	"end_turn": 0, "energy": 80, "evolution": 50, "handoff": 100,
	"search": 180, "tool": 120,
}


static func evaluate(
	frame: Variant,
	candidate: Variant,
	visible_debt_count: int,
	max_uncertainty_milli: int = 400,
) -> Dictionary:
	if not frame is Dictionary or not candidate is Dictionary \
			or visible_debt_count < 0 or max_uncertainty_milli < 0 \
			or max_uncertainty_milli > 1000 \
			or not candidate.get("semantic_steps") is Array \
			or candidate.get("semantic_steps", []).is_empty() \
			or not candidate.get("current_option_facts") is Array \
			or not frame.get("source") is Dictionary:
		return _error("invalid_transition_request")
	var steps: Array = candidate.get("semantic_steps")
	var seen := {}
	var claims := {}
	var step_audit: Array = []
	var delta := {
		"board_development_milli": 0,
		"attack_pressure_milli": 0,
		"next_turn_continuity_milli": 0,
		"hand_quality_milli": 0,
		"disruption_milli": 0,
	}
	var uncertainty := 0
	var dependency_debt := 0
	var resource_conflicts := 0
	var executed_prefix := 0
	var turn: Dictionary = frame.get("public_state", {}).get("self", {}).get("turn", {})
	var availability := {
		"supporter": bool(turn.get("supporter_available", true)),
		"manual_attachment": bool(turn.get("manual_attachment_available", true)),
		"retreat": bool(turn.get("retreat_available", true)),
	}
	var current_facts: Array = candidate.get("current_option_facts")
	for offset: int in steps.size():
		var step: Variant = steps[offset]
		if not step is Dictionary or typeof(step.get("step_id")) != TYPE_STRING:
			return _error("invalid_transition_step")
		var step_id := str(step.get("step_id"))
		var dependencies: Variant = step.get("depends_on", [])
		var dependency_ok := dependencies is Array
		if dependency_ok:
			for dependency: Variant in dependencies:
				if typeof(dependency) != TYPE_STRING or not seen.has(dependency):
					dependency_ok = false
					break
		if not dependency_ok:
			dependency_debt += 1
		var effect_kind := str(step.get("effect_kind", ""))
		var claim := _resource_claim(
			effect_kind, current_facts, offset, step.get("resource_claim")
		)
		var conflict := false
		if claim == "unknown":
			uncertainty += 600
		elif claim != "none":
			conflict = claims.has(claim) or not bool(availability.get(claim, false))
			if conflict:
				resource_conflicts += 1
			claims[claim] = true
			availability[claim] = false
		var step_uncertainty := int(BASE_UNCERTAINTY.get(effect_kind, 400))
		if offset > 0:
			step_uncertainty += 20
		uncertainty += step_uncertainty
		if dependency_ok:
			executed_prefix += 1
			var effect_delta: Dictionary = DELTA_BY_EFFECT.get(effect_kind, {})
			for feature: Variant in effect_delta:
				delta[feature] = mini(1000, int(delta.get(feature, 0)) + int(effect_delta[feature]))
		seen[step_id] = true
		step_audit.append({
			"step_id": step_id,
			"effect_kind": effect_kind,
			"dependency_satisfied": dependency_ok,
			"resource_claim": claim,
			"resource_conflict": conflict,
			"uncertainty_milli": mini(
				1000, step_uncertainty + (600 if claim == "unknown" else 0)
			),
		})
	var resolved_debt := 0
	for step_value: Variant in steps:
		if step_value.get("terminal_kind") == "none":
			resolved_debt += 1
	var unresolved_debt := maxi(0, visible_debt_count - resolved_debt)
	var terminal_reached: bool = steps[-1].get("terminal_kind") in ["attack", "end_turn"]
	uncertainty = mini(1000, uncertainty)
	var commit_safe := dependency_debt == 0 and resource_conflicts == 0 \
		and uncertainty <= max_uncertainty_milli
	var payload := {
		"accepted": true,
		"error_code": "",
		"profile_id": PROFILE_ID,
		"public_only": true,
		"authoritative": false,
		"source": frame.get("source", {}).duplicate(true),
		"program_id": candidate.get("program_id"),
		"executed_prefix_length": executed_prefix,
		"terminal_reached": terminal_reached,
		"unresolved_dependency_count": dependency_debt,
		"resource_conflict_count": resource_conflicts,
		"uncertainty_milli": uncertainty,
		"unresolved_debt_milli": mini(1000, unresolved_debt * 250),
		"commit_safe": commit_safe,
		"resource_ledger_after": availability,
		"predicted_public_delta": delta,
		"baseline_public_metrics": _public_metrics(frame),
		"step_audit": step_audit,
	}
	var result := payload.duplicate(true)
	result["audit_hash"] = _audit_hash(payload)
	return result


static func label_outcome(prediction: Variant, observed_frame: Variant) -> Dictionary:
	if not prediction is Dictionary or not observed_frame is Dictionary:
		return _label_error("invalid_transition_label")
	var old_source: Variant = prediction.get("source")
	var new_source: Variant = observed_frame.get("source")
	if not old_source is Dictionary or not new_source is Dictionary:
		return _label_error("invalid_transition_label")
	if old_source == new_source:
		return _label_error("stale_transition_observation")
	var before: Variant = prediction.get("baseline_public_metrics", {})
	if not before is Dictionary:
		before = {}
	var after := _public_metrics(observed_frame)
	var effect := str(prediction.get("effect_kind", ""))
	var prediction_steps: Variant = prediction.get("step_audit", [])
	if effect.is_empty() and prediction_steps is Array and not prediction_steps.is_empty():
		effect = str(prediction_steps[0].get("effect_kind", ""))
	var evidence := false
	var contradicted := false
	if effect in ["evolution", "bench"]:
		evidence = int(after.get("own_board_count")) > int(before.get("own_board_count", 0))
	elif effect == "energy":
		evidence = int(after.get("own_energy_count")) > int(before.get("own_energy_count", 0))
	elif effect in ["draw", "search"]:
		evidence = int(after.get("own_hand_count")) > int(before.get("own_hand_count", 0))
	elif effect == "disruption":
		evidence = int(after.get("opponent_hand_count")) < int(before.get(
			"opponent_hand_count", int(after.get("opponent_hand_count")) + 1
		))
	elif effect == "damage_transfer":
		evidence = int(after.get("opponent_damage_count")) > int(before.get("opponent_damage_count", 0))
	elif effect == "attack":
		evidence = int(after.get("own_prizes_remaining")) < int(before.get(
			"own_prizes_remaining", int(after.get("own_prizes_remaining")) + 1
		))
	else:
		contradicted = true
	var status := "confirmed" if evidence else "contradicted" if contradicted else "unresolved"
	var payload := {
		"accepted": true,
		"error_code": "",
		"profile_id": OUTCOME_GATE_PROFILE_ID,
		"public_only": true,
		"authoritative": false,
		"program_id": prediction.get("program_id"),
		"effect_kind": effect,
		"status": status,
		"confirmed": status == "confirmed",
		"contradicted": status == "contradicted",
		"promotion_eligible": false,
		"observed_source": new_source.duplicate(true),
	}
	var result := payload.duplicate(true)
	result["audit_hash"] = _audit_hash(payload)
	return result


static func summarize_labels(labels: Variant, minimum_confirmed: int = 8) -> Dictionary:
	var accepted: Array = []
	if labels is Array:
		for row: Variant in labels:
			if row is Dictionary and bool(row.get("accepted", false)):
				accepted.append(row)
	var confirmed := 0
	var contradicted := 0
	var unresolved := 0
	for row_value: Variant in accepted:
		match row_value.get("status"):
			"confirmed": confirmed += 1
			"contradicted": contradicted += 1
			"unresolved": unresolved += 1
	var eligible := confirmed >= minimum_confirmed and contradicted == 0 \
		and unresolved <= maxi(2, int(confirmed / 4))
	var payload := {
		"accepted": not accepted.is_empty(),
		"error_code": "" if not accepted.is_empty() else "no_transition_labels",
		"profile_id": OUTCOME_GATE_PROFILE_ID,
		"public_only": true,
		"authoritative": false,
		"label_count": accepted.size(),
		"confirmed_count": confirmed,
		"contradicted_count": contradicted,
		"unresolved_count": unresolved,
		"promotion_eligible": eligible,
	}
	var result := payload.duplicate(true)
	result["audit_hash"] = _audit_hash(payload)
	return result


static func _resource_claim(
	effect_kind: String, current_facts: Array, offset: int, declared_claim: Variant
) -> String:
	if declared_claim in ["none", "supporter", "manual_attachment", "retreat", "unknown"]:
		return str(declared_claim)
	var kinds := {}
	if offset == 0:
		for fact_value: Variant in current_facts:
			if fact_value is Dictionary:
				kinds[str(fact_value.get("kind", ""))] = true
	if effect_kind in ["draw", "disruption"]:
		return "supporter"
	if effect_kind == "energy" and kinds.has("attach_energy"):
		return "manual_attachment"
	if effect_kind == "handoff" and kinds.has("retreat"):
		return "retreat"
	if effect_kind == "search" and kinds.has("play_trainer"):
		return "unknown"
	return "none"


static func _public_metrics(frame: Dictionary) -> Dictionary:
	var state: Dictionary = frame.get("public_state", {})
	var own: Dictionary = state.get("self", {})
	var opponent: Dictionary = state.get("opponent", {})
	var own_board: Array = own.get("active", []).duplicate()
	own_board.append_array(own.get("bench", []))
	var opposing_board: Array = opponent.get("active", []).duplicate()
	opposing_board.append_array(opponent.get("bench", []))
	var energy_count := 0
	for card_value: Variant in own_board:
		energy_count += int(card_value.get("attached_energy_count", 0))
	var opponent_damage_count := 0
	for card_value: Variant in opposing_board:
		opponent_damage_count += maxi(0, int(card_value.get("damage", 0)) / 10)
	return {
		"own_board_count": own_board.size(),
		"own_energy_count": energy_count,
		"own_hand_count": own.get("hand", []).size(),
		"own_prizes_remaining": int(own.get("prizes_remaining", 0)),
		"opponent_hand_count": int(opponent.get("hand_count", 0)),
		"opponent_damage_count": opponent_damage_count,
	}


static func _error(code: String) -> Dictionary:
	return {
		"accepted": false, "error_code": code, "profile_id": PROFILE_ID,
		"public_only": true, "authoritative": false, "source": null,
		"program_id": null, "executed_prefix_length": 0,
		"terminal_reached": false, "unresolved_dependency_count": 0,
		"resource_conflict_count": 0, "uncertainty_milli": 1000,
		"unresolved_debt_milli": 1000, "commit_safe": false,
		"resource_ledger_after": {}, "predicted_public_delta": {},
		"baseline_public_metrics": {}, "step_audit": [], "audit_hash": "",
	}


static func _label_error(code: String) -> Dictionary:
	return {
		"accepted": false, "error_code": code,
		"profile_id": OUTCOME_GATE_PROFILE_ID, "public_only": true,
		"authoritative": false, "program_id": null, "effect_kind": "",
		"status": "rejected", "confirmed": false, "contradicted": false,
		"promotion_eligible": false, "observed_source": null, "audit_hash": "",
	}


static func _audit_hash(value: Variant) -> String:
	var result: Dictionary = TreeHashScript.hash_tree(value, "public_observation")
	return str(result.get("sha256", "")) if bool(result.get("ok", false)) else ""
