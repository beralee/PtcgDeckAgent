class_name V18CPGPrizeClockPivot
extends RefCounted

const MODULE_ID := "prize_clock_pivot"
const PrizeClockSolverScript = preload(
	"res://scripts/ai/v18_cpg/planning/V18CPGPrizeClockSolver.gd"
)
const RagingBoltExtensionScript = preload(
	"res://scripts/ai/v18_cpg/planning/extensions/V18CPGRagingBoltPrizeClockExtension.gd"
)

var _clock = PrizeClockSolverScript.new()
var _raging_bolt = RagingBoltExtensionScript.new()


func annotate_frontier_post_completion(
	frontier: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary,
	_semantic_manifest: Dictionary = {}
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var baseline := _clock.solve(observation, facts, profile)
	var compact_baseline := _clock.compact_baseline(baseline)
	var mobility: Dictionary = facts.get("mobility", {}) \
		if facts.get("mobility", {}) is Dictionary else {}
	var zero_retreat_action_ids: Array = mobility.get(
		"zero_retreat_action_ids",
		[]
	) if mobility.get("zero_retreat_action_ids", []) is Array else []
	for raw_candidate: Dictionary in frontier:
		var candidate := raw_candidate.duplicate(true)
		var candidate_action_id := str(candidate.get(
			"safe_prefix_action_id",
			""
		))
		var exact_zero_retreat := str(
			candidate.get("action_kind", "")
		) == "retreat" \
			and candidate_action_id in zero_retreat_action_ids
		var extension: Dictionary = {}
		if _raging_bolt.supports(profile):
			extension = _raging_bolt.annotate_candidate(
				candidate,
				observation,
				facts,
				profile,
				baseline
			)
			var conditional_suffix: Variant = extension.get(
				"conditional_suffix",
				{}
			)
			if conditional_suffix is Dictionary \
					and not (conditional_suffix as Dictionary).is_empty():
				candidate["conditional_suffix"] = (
					conditional_suffix as Dictionary
				).duplicate(true)
		var candidate_clock := _clock.project_candidate(
			baseline,
			candidate,
			observation,
			facts,
			extension
		)
		var prize_denial: Dictionary = extension.get("prize_denial", {}) \
			if extension.get("prize_denial", {}) is Dictionary else {}
		var forced_denial := str(prize_denial.get("level", "")) == "forced" \
			and bool((extension.get("same_attack_window", {}) as Dictionary).get(
				"ko_ready",
				false
			)) if extension.get("same_attack_window", {}) is Dictionary else false
		var same_window: Dictionary = extension.get("same_attack_window", {}) \
			if extension.get("same_attack_window", {}) is Dictionary else {}
		var public_pivot_ko := str(
			same_window.get("proof_kind", "")
		) in [
			"public_dynamic_attack_cost_after_pivot",
			"public_profile_attack_cost_after_pivot",
		] \
			and bool(same_window.get("attack_ready", false)) \
			and bool(same_window.get("ko_ready", false)) \
			and bool(same_window.get("requires_reobservation", false))
		var annotation := {
			"module": MODULE_ID,
			"baseline_clock": compact_baseline,
			"candidate_clock": candidate_clock,
			"liability_map": baseline.get("liability_map", []),
			"same_attack_window": same_window,
			"prize_denial": prize_denial,
			"extension_kind": str(extension.get("extension_kind", "")),
			"extension_operators": extension.get("extension_operators", []),
			"latias_free_retreat_visible": bool(extension.get(
				"latias_free_retreat_visible",
				false
			)),
			"mobility_provider_scope": str(mobility.get(
				"provider_scope",
				""
			)),
			"route_warning": str(extension.get("route_warning", "")),
			"verified_advantage": forced_denial or public_pivot_ko,
			"verified_advantage_kind": "public_prize_denial_pivot" \
				if forced_denial \
				else "public_same_window_pivot_ko_loss_prevention" \
				if public_pivot_ko else "",
		}
		if exact_zero_retreat:
			annotation["zero_energy_retreat"] = true
			annotation["preserves_attached_energy"] = true
			annotation["retreat_payment_energy_count"] = 0
			annotation["mobility_proof_kind"] = \
				"engine_legal_empty_payment"
		var annotations: Dictionary = candidate.get("module_annotations", {}) \
			if candidate.get("module_annotations", {}) is Dictionary else {}
		annotations[MODULE_ID] = annotation
		candidate["module_annotations"] = annotations
		result.append(candidate)
	return result


func validate_route_switch(
	selected: Dictionary,
	local_top: Dictionary,
	_facts: Dictionary,
	_profile: Dictionary
) -> Dictionary:
	var selected_outcome: Dictionary = selected.get("outcome", {}) \
		if selected.get("outcome", {}) is Dictionary else {}
	var top_outcome: Dictionary = local_top.get("outcome", {}) \
		if local_top.get("outcome", {}) is Dictionary else {}
	if bool(top_outcome.get("win_now", false)) \
			and not bool(selected_outcome.get("win_now", false)):
		return {
			"valid": false,
			"reason": "prize_clock_win_now_is_invariant",
		}
	var selected_clock := _candidate_clock(selected)
	var top_clock := _candidate_clock(local_top)
	if bool(top_clock.get("prevents_next_window_loss", false)) \
			and not bool(selected_clock.get("prevents_next_window_loss", false)):
		return {
			"valid": false,
			"reason": "prize_clock_must_prevent_next_window_loss",
		}
	if bool(selected_clock.get("consumes_attack_window", false)) \
			and not bool(top_clock.get("consumes_attack_window", false)) \
			and int(selected_clock.get("first_window_prizes", 0)) \
				< int(top_clock.get("first_window_prizes", 0)):
		return {
			"valid": false,
			"reason": "prize_clock_avoidable_attack_window_loss",
		}
	return {"valid": true}


func verify_route_advantage(
	selected: Dictionary,
	local_top: Dictionary,
	_facts: Dictionary,
	_profile: Dictionary
) -> Dictionary:
	var selected_annotation := _annotation(selected)
	var top_outcome: Dictionary = local_top.get("outcome", {}) \
		if local_top.get("outcome", {}) is Dictionary else {}
	var selected_outcome: Dictionary = selected.get("outcome", {}) \
		if selected.get("outcome", {}) is Dictionary else {}
	var denial: Dictionary = selected_annotation.get("prize_denial", {}) \
		if selected_annotation.get("prize_denial", {}) is Dictionary else {}
	var same_window: Dictionary = selected_annotation.get(
		"same_attack_window",
		{}
	) if selected_annotation.get("same_attack_window", {}) is Dictionary else {}
	var selected_clock := _candidate_clock(selected)
	var top_clock := _candidate_clock(local_top)
	var baseline_clock: Dictionary = selected_annotation.get(
		"baseline_clock",
		{}
	) if selected_annotation.get("baseline_clock", {}) is Dictionary else {}
	var proof_kind := str(same_window.get("proof_kind", ""))
	if bool(local_top.get("engine_rule_floor_exact", false)) \
			and str(local_top.get("route_id", "")) == "route:end_turn" \
			and str(selected.get("action_kind", "")) == "retreat" \
			and bool(baseline_clock.get("opponent_wins_next_window", false)) \
			and proof_kind in [
				"public_dynamic_attack_cost_after_pivot",
				"public_profile_attack_cost_after_pivot",
			] \
			and bool(same_window.get("attack_ready", false)) \
			and bool(same_window.get("ko_ready", false)) \
			and bool(same_window.get("requires_reobservation", false)) \
			and bool(selected_clock.get("same_window_attack_preserved", false)) \
			and int(selected_clock.get("first_window_prizes", 0)) \
				> int(top_clock.get("first_window_prizes", 0)) \
			and not bool(top_outcome.get("win_now", false)):
		return {
			"verified": true,
			"reason": "public_same_window_pivot_ko_prevents_rule_forfeit",
			"certificate_kind": \
				"public_same_window_pivot_ko_loss_prevention",
			"interaction_owner": "not_required",
			"target_slot_id": str(same_window.get("target_slot_id", "")),
			"target_uid": str(same_window.get("target_uid", "")),
			"proof_kind": proof_kind,
			"projected_damage": int(same_window.get(
				"projected_damage",
				0
			)),
			"target_remaining_hp": int(same_window.get(
				"target_remaining_hp",
				0
			)),
			"projected_prizes": int(selected_clock.get(
				"first_window_prizes",
				0
			)),
			"requires_reobservation": true,
		}
	if bool(local_top.get("engine_rule_floor_exact", false)) \
			and str(selected.get("action_kind", "")) == "retreat" \
			and str(denial.get("level", "")) == "forced" \
			and bool(denial.get("public_gust_exhausted", false)) \
			and int(denial.get("exposed_prize_count", 0)) == 1 \
			and bool(same_window.get("ko_ready", false)) \
			and bool(selected_clock.get("same_window_attack_preserved", false)) \
			and int(selected_clock.get("first_window_prizes", 0)) \
				>= int(top_clock.get("first_window_prizes", 0)) \
			and not bool(top_outcome.get("win_now", false)):
		return {
			"verified": true,
			"reason": "public_gust_exhausted_one_prize_bridge_preserves_attack",
			"certificate_kind": "public_prize_denial_pivot",
			"interaction_owner": "not_required",
			"target_slot_id": str(denial.get("target_slot_id", "")),
			"target_uid": str(denial.get("target_uid", "")),
			"exposed_prize_count": 1,
			"projected_damage": int(same_window.get(
				"projected_damage",
				0
			)),
			"self_damage": int(same_window.get("self_damage", 0)),
			"opponent_finish_tick_delay": int(selected_clock.get(
				"opponent_finish_tick_delay",
				0
			)),
		}
	return {"verified": false}


func _annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	return annotations.get(MODULE_ID, {}) \
		if annotations.get(MODULE_ID, {}) is Dictionary else {}


func _candidate_clock(candidate: Dictionary) -> Dictionary:
	var annotation := _annotation(candidate)
	return annotation.get("candidate_clock", {}) \
		if annotation.get("candidate_clock", {}) is Dictionary else {}
