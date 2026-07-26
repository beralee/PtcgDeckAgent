class_name V18CPGTurnCompletionSolver
extends RefCounted

## Builds a compact, visibility-safe pre-terminal checklist from the already
## validated public frontier.  It does not execute actions or claim that every
## card in hand should be spent.  Only exact candidates that can complete an
## attack route, add public damage/energy, or open a profiled information
## checkpoint are reported.

const MAX_PRODUCTIVE_ACTIONS := 6
const PostAttackContinuitySolverScript = preload(
	"res://scripts/ai/v18_cpg/planning/V18CPGPostAttackContinuitySolver.gd"
)

var _post_attack_continuity = PostAttackContinuitySolverScript.new()


func annotate_frontier(
	frontier: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary = {}
) -> Array[Dictionary]:
	return _post_attack_continuity.annotate_frontier(
		frontier,
		observation,
		facts,
		profile
	)


func build(
	observation: Dictionary,
	facts: Dictionary,
	frontier: Array[Dictionary],
	_profile: Dictionary = {}
) -> Dictionary:
	var continuity_frontier := annotate_frontier(
		frontier,
		observation,
		facts,
		_profile
	)
	var continuity := _post_attack_continuity.build_from_annotated_frontier(
		observation,
		facts,
		continuity_frontier,
		_profile
	)
	var attack: Dictionary = facts.get("attack", {}) \
		if facts.get("attack", {}) is Dictionary else {}
	var attack_ready := bool(attack.get("ready", false))
	var ko_available := bool(attack.get("ko_available", false))
	var max_damage := int(attack.get("max_damage", 0))
	var target_hp := _opponent_active_hp(observation, facts)
	var minimum_lethal_units := 0
	var damage_per_unit := 0
	var damage_mode := ""
	for candidate: Dictionary in continuity_frontier:
		var burst := _annotation(candidate, "energy_burst")
		if burst.is_empty():
			continue
		var candidate_units := int(burst.get(
			"minimum_damage_units_for_active_ko",
			burst.get("minimum_discards_for_active_ko", 0)
		))
		if candidate_units <= 0:
			continue
		minimum_lethal_units = candidate_units
		damage_per_unit = int(burst.get(
			"damage_per_unit",
			burst.get("damage_per_discard", 0)
		))
		damage_mode = str(burst.get("damage_mode", ""))
		if str(candidate.get("action_kind", "")) in ["attack", "granted_attack"]:
			break

	var productive: Array[Dictionary] = []
	if not ko_available or bool(continuity.get("review_before_terminal", false)):
		for candidate: Dictionary in continuity_frontier:
			var continuity_effect: Dictionary = candidate.get(
				"post_attack_continuity",
				{}
			) if candidate.get("post_attack_continuity", {}) is Dictionary else {}
			var reason := _productive_reason(
				candidate,
				facts,
				continuity_effect
			)
			if reason == "":
				continue
			if ko_available \
					and not bool(continuity_effect.get(
						"force_before_terminal",
						false
					)):
				continue
			productive.append({
				"candidate_id": str(candidate.get("candidate_id", "")),
				"action_id": str(candidate.get("safe_prefix_action_id", "")),
				"route_id": str(candidate.get("route_id", "")),
				"action_kind": str(candidate.get("action_kind", "")),
				"reason": reason,
				"information_checkpoint": str(
					candidate.get("checkpoint_after", "")
				) == "information_result",
				"continuity_debt_types": continuity_effect.get(
					"debt_types",
					[]
				),
				"continuity_debt_reduction": int(
					continuity_effect.get("debt_reduction_count", 0)
				),
				"force_before_terminal": bool(
					continuity_effect.get("force_before_terminal", false)
				),
				"priority": int(continuity_effect.get("priority", 1000)) \
					if bool(continuity_effect.get("reduces_debt", false)) \
					else _productive_priority(reason),
			})
		productive.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_priority := int(left.get(
				"priority",
				_productive_priority(str(left.get("reason", "")))
			))
			var right_priority := int(right.get(
				"priority",
				_productive_priority(str(right.get("reason", "")))
			))
			if left_priority != right_priority:
				return left_priority < right_priority
			return str(left.get("candidate_id", "")) \
				< str(right.get("candidate_id", ""))
		)
		if productive.size() > MAX_PRODUCTIVE_ACTIONS:
			productive.resize(MAX_PRODUCTIVE_ACTIONS)
	var productive_action_ids: Array[String] = []
	var productive_candidate_ids: Array[String] = []
	for item: Dictionary in productive:
		var action_id := str(item.get("action_id", ""))
		var candidate_id := str(item.get("candidate_id", ""))
		if action_id != "":
			productive_action_ids.append(action_id)
		if candidate_id != "":
			productive_candidate_ids.append(candidate_id)
	var must_review := (
		not ko_available and not productive.is_empty()
	) or (
		ko_available \
		and bool(continuity.get("review_before_terminal", false)) \
		and not productive.is_empty()
	)
	var instruction := "complete_post_attack_continuity_then_reobserve" \
		if ko_available and must_review \
		else "commit_minimum_lethal_resource" if ko_available \
		else "complete_public_route_then_reobserve" if must_review \
		else "develop_or_end_without_speculative_spend"
	var recommended: Dictionary = productive[0] if not productive.is_empty() else {}
	return {
		"schema_version": 2,
		"instruction": instruction,
		"attack_ready": attack_ready,
		"ko_available": ko_available,
		"current_public_damage": max_damage,
		"opponent_active_hp": target_hp,
		"damage_deficit": maxi(0, target_hp - max_damage) if target_hp > 0 else 0,
		"damage_mode": damage_mode,
		"damage_per_unit": damage_per_unit,
		"minimum_lethal_units": minimum_lethal_units,
		"must_review_before_terminal": must_review,
		"productive_action_count": productive.size(),
		"productive_action_ids": productive_action_ids,
		"productive_candidate_ids": productive_candidate_ids,
		"productive_actions": productive,
		"recommended_action_id": str(recommended.get("action_id", "")),
		"recommended_candidate_id": str(recommended.get("candidate_id", "")),
		"recommended_route_id": str(recommended.get("route_id", "")),
		"recommended_reason": str(recommended.get("reason", "")),
		"post_attack_continuity": continuity,
	}


func _productive_reason(
	candidate: Dictionary,
	facts: Dictionary,
	continuity_effect: Dictionary = {}
) -> String:
	if bool(continuity_effect.get("reduces_debt", false)):
		return str(continuity_effect.get(
			"reason",
			"public_post_attack_continuity_gain"
		))
	var route_id := str(candidate.get("route_id", ""))
	if route_id in ["route:attack_ko", "route:attack_pressure", "route:end_turn"]:
		return ""
	var noctowl := _annotation(candidate, "tera_noctowl_search")
	if bool(noctowl.get("completion_opportunity", false)):
		return "profiled_noctowl_attack_completion"
	var burst := _annotation(candidate, "energy_burst")
	var attachment: Dictionary = burst.get("attachment", {}) \
		if burst.get("attachment", {}) is Dictionary else {}
	if bool(attachment.get("target_is_primary_attacker", false)) \
			and bool(attachment.get("completes_required_types", false)):
		return "typed_attack_cost_completion"
	var acceleration: Dictionary = burst.get("acceleration", {}) \
		if burst.get("acceleration", {}) is Dictionary else {}
	if bool(acceleration.get("sada_live", false)) \
			and "supporter_acceleration" in candidate.get("action_semantic_roles", []):
		return "public_energy_acceleration"
	var roles: Array = candidate.get("action_semantic_roles", []) \
		if candidate.get("action_semantic_roles", []) is Array else []
	if str(candidate.get("action_kind", "")) == "use_ability" \
			and "energy_accelerator" in roles \
			and str(candidate.get("checkpoint_after", "")) == "information_result":
		return "energy_acceleration_information_epoch"
	if route_id == "route:accelerate" \
			and ("energy_mover" in roles or "supporter_acceleration" in roles) \
			and not bool(facts.get("attack", {}).get("ko_available", false)):
		return "public_attack_route_acceleration"
	return ""


func _annotation(candidate: Dictionary, module_id: String) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	return annotations.get(module_id, {}) \
		if annotations.get(module_id, {}) is Dictionary else {}


func _productive_priority(reason: String) -> int:
	return {
		"profiled_noctowl_attack_completion": 0,
		"typed_attack_cost_completion": 10,
		"public_energy_acceleration": 20,
		"energy_acceleration_information_epoch": 30,
		"public_attack_route_acceleration": 40,
	}.get(reason, 100)


func _opponent_active_hp(observation: Dictionary, facts: Dictionary) -> int:
	var opponent: Dictionary = observation.get("opponent", {}) \
		if observation.get("opponent", {}) is Dictionary else {}
	var active: Dictionary = opponent.get("active", {}) \
		if opponent.get("active", {}) is Dictionary else {}
	return int(active.get(
		"remaining_hp",
		facts.get("board", {}).get("opponent_active_remaining_hp", 0)
	))
