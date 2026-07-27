class_name V18CPGHardGuard
extends RefCounted

## Public-state hard guards run before any V18 action owner is selected.
##
## These are deliberately narrower than route preferences: a candidate is
## removed only when the profile declares a safety invariant and the current
## public state proves that the action cannot satisfy it. The returned action
## IDs are also enforced by the final scorer so local/deadline/schema fallbacks
## cannot recover a blocked Rule root.

const RULE_VETO_SENTINEL_CEILING := -99999.0


func filter_candidates(
	candidates: Array,
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	return _filter_candidates(
		candidates,
		observation,
		facts,
		profile,
		true
	)


func filter_intrinsic_candidates(
	candidates: Array,
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	return _filter_candidates(
		candidates,
		observation,
		facts,
		profile,
		false
	)


func _filter_candidates(
	candidates: Array,
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary,
	include_terminal_guard: bool
) -> Dictionary:
	var allowed: Array[Dictionary] = []
	var blocked: Array[Dictionary] = []
	var blocked_action_ids: Dictionary = {}
	for raw_candidate: Variant in candidates:
		if not (raw_candidate is Dictionary):
			continue
		var candidate: Dictionary = raw_candidate
		var result := candidate_admissibility(
			candidate,
			observation,
			facts,
			profile,
			include_terminal_guard
		)
		if bool(result.get("allowed", false)):
			var allowed_candidate := candidate.duplicate(true)
			var target_constraint: Variant = result.get(
				"target_constraint",
				{}
			)
			if target_constraint is Dictionary \
					and not (target_constraint as Dictionary).is_empty():
				allowed_candidate["hard_guard_target_constraint"] = (
					target_constraint as Dictionary
				).duplicate(true)
			allowed.append(allowed_candidate)
			continue
		var action_id := str(candidate.get("safe_prefix_action_id", ""))
		if action_id != "":
			blocked_action_ids[action_id] = str(
				result.get("reason", "hard_guard_blocked")
			)
		blocked.append({
			"candidate_id": str(candidate.get("candidate_id", "")),
			"route_id": str(candidate.get("route_id", "")),
			"action_id": action_id,
			"reason": str(result.get("reason", "hard_guard_blocked")),
		})
	return {
		"candidates": allowed,
		"blocked": blocked,
		"blocked_action_ids": blocked_action_ids,
	}


func candidate_admissibility(
	candidate: Dictionary,
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary,
	include_terminal_guard: bool = true
) -> Dictionary:
	var action_kind := str(candidate.get("action_kind", ""))
	var route_id := str(candidate.get("route_id", ""))
	if _is_uncertified_rule_veto(candidate):
		return {
			"allowed": false,
			"reason": "rule_veto_without_verified_certificate",
		}
	var turn: Dictionary = observation.get("turn", {}) \
		if observation.get("turn", {}) is Dictionary else {}
	var quotas: Dictionary = turn.get("quotas", {}) \
		if turn.get("quotas", {}) is Dictionary else {}
	if action_kind == "play_stadium" \
			and not bool(quotas.get("stadium_available", true)):
		return {
			"allowed": false,
			"reason": "stadium_quota_already_spent",
		}

	var prize: Dictionary = facts.get("prize", {}) \
		if facts.get("prize", {}) is Dictionary else {}
	var continuity: Dictionary = facts.get("continuity", {}) \
		if facts.get("continuity", {}) is Dictionary else {}
	var terminal := action_kind in [
		"attack",
		"granted_attack",
		"end_turn",
	] or route_id in [
		"route:attack_ko",
		"route:attack_pressure",
		"route:end_turn",
	]
	if include_terminal_guard \
			and terminal \
			and bool(continuity.get("review_before_terminal", false)) \
			and bool(continuity.get("safe_prefix_available", false)) \
			and not bool(continuity.get("floor_met", true)) \
			and not bool(prize.get("win_now", false)):
		return {
			"allowed": false,
			"reason": "post_attack_continuity_debt",
		}

	var safety: Dictionary = profile.get("safety", {}) \
		if profile.get("safety", {}) is Dictionary else {}
	if route_id == "route:gust" \
			and bool(safety.get("require_payable_ko_before_gust", false)):
		var payable_targets := _publicly_payable_gust_targets(
			candidate,
			observation,
			facts
		)
		if payable_targets.is_empty():
			return {
				"allowed": false,
				"reason": "gust_without_publicly_payable_ko",
			}
		var eligible_slot_ids: Array[String] = []
		var eligible_instance_ids: Array[int] = []
		for target: Dictionary in payable_targets:
			var slot_id := str(target.get("slot_id", ""))
			var instance_id := int(target.get("instance_id", -1))
			if slot_id != "" and slot_id not in eligible_slot_ids:
				eligible_slot_ids.append(slot_id)
			if instance_id >= 0 and instance_id not in eligible_instance_ids:
				eligible_instance_ids.append(instance_id)
		return {
			"allowed": true,
			"reason": "",
			"target_constraint": {
				"kind": "public_lethal_only",
				"eligible_slot_ids": eligible_slot_ids,
				"eligible_instance_ids": eligible_instance_ids,
				"max_damage": int(facts.get(
					"attack",
					{}
				).get("max_damage", 0)) \
					if facts.get("attack", {}) is Dictionary else 0,
				"targets": payable_targets,
			},
		}
	return {"allowed": true, "reason": ""}


func _is_uncertified_rule_veto(candidate: Dictionary) -> bool:
	var rule_score := float(candidate.get(
		"base_score",
		candidate.get("local_score", 0.0)
	))
	if rule_score > RULE_VETO_SENTINEL_CEILING:
		return false
	if bool(candidate.get("engine_rule_floor_exact", false)):
		return false
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	for raw_annotation: Variant in annotations.values():
		if raw_annotation is Dictionary \
				and bool((raw_annotation as Dictionary).get(
					"verified_advantage",
					false
				)):
			return false
	return true


func _publicly_payable_gust_targets(
	candidate: Dictionary,
	observation: Dictionary,
	facts: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var module_proves_payable_ko := false
	for raw_annotation: Variant in annotations.values():
		if raw_annotation is Dictionary \
				and bool((raw_annotation as Dictionary).get(
					"ko_payable_with_reserve",
					false
				)):
			module_proves_payable_ko = true
			break
	var attack: Dictionary = facts.get("attack", {}) \
		if facts.get("attack", {}) is Dictionary else {}
	if not bool(attack.get("ready", false)) and not module_proves_payable_ko:
		return result
	var max_damage := int(attack.get("max_damage", 0))
	if max_damage <= 0:
		return result
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var bench: Array = opponent.get("bench", []) \
		if opponent.get("bench", []) is Array else []
	for raw_slot: Variant in bench:
		if not (raw_slot is Dictionary):
			continue
		var remaining_hp := int(
			(raw_slot as Dictionary).get("remaining_hp", 0)
		)
		if remaining_hp > 0 and remaining_hp <= max_damage:
			var slot: Dictionary = raw_slot
			var pokemon: Dictionary = slot.get("pokemon", {}) \
				if slot.get("pokemon", {}) is Dictionary else {}
			result.append({
				"slot_id": str(slot.get("slot_id", "")),
				"instance_id": int(pokemon.get("instance_id", -1)),
				"remaining_hp": remaining_hp,
				"prize_count": maxi(1, int(slot.get("prize_count", 1))),
			})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_prizes := int(left.get("prize_count", 1))
		var right_prizes := int(right.get("prize_count", 1))
		if left_prizes != right_prizes:
			return left_prizes > right_prizes
		var left_hp := int(left.get("remaining_hp", 0))
		var right_hp := int(right.get("remaining_hp", 0))
		if left_hp != right_hp:
			return left_hp < right_hp
		return str(left.get("slot_id", "")) \
			< str(right.get("slot_id", ""))
	)
	return result
