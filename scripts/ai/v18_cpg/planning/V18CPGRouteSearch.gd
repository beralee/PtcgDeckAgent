class_name V18CPGRouteSearch
extends RefCounted

const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")
const ContractsScript = preload("res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd")
const InformationValueScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGInformationValueSolver.gd")
const NOCTOWL_SEARCH_SOURCE_UIDS: Array[String] = ["CSV9C_155", "LEN_SCR_115"]
const FAN_CALL_SOURCE_UIDS: Array[String] = ["CSV9C_161", "LEN_SCR_118"]

var _semantic_compiler = SemanticCompilerScript.new()
var _information_value = InformationValueScript.new()


func build_frontier(
	observation: Dictionary,
	base_scores: Dictionary,
	semantic_manifest: Dictionary,
	facts: Dictionary,
	max_routes: int = 8
) -> Array[Dictionary]:
	return prune_frontier(
		build_candidate_pool(observation, base_scores, semantic_manifest, facts),
		max_routes
	)


func build_candidate_pool(
	observation: Dictionary,
	base_scores: Dictionary,
	semantic_manifest: Dictionary,
	facts: Dictionary
) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var legal_actions: Array = observation.get("legal_actions", []) if observation.get("legal_actions", []) is Array else []
	for action_index: int in legal_actions.size():
		var raw_action: Variant = legal_actions[action_index]
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		var category := _category(action, semantic_manifest)
		var action_id := str(action.get("id", ""))
		# The full legal candidate pool is deliberately built before capability
		# annotation. Exact public certificates must be able to rescue a Rule-low
		# action from the model-visible cap without changing the Rule score itself.
		var base_score := float(base_scores.get(action_id, 0.0))
		pool.append(_candidate(category, action, base_score, facts, observation, semantic_manifest, action_index))
	pool.sort_custom(_sort_candidate)
	return pool


func prune_frontier(candidate_pool: Array[Dictionary], max_routes: int = 8) -> Array[Dictionary]:
	if candidate_pool.is_empty() or max_routes <= 0:
		return []
	var candidates_by_category: Dictionary = {}
	for candidate: Dictionary in candidate_pool:
		var category := str(candidate.get("route_id", "route:unknown"))
		if not candidates_by_category.has(category):
			candidates_by_category[category] = []
		(candidates_by_category[category] as Array).append(candidate)
	for category: Variant in candidates_by_category.keys():
		(candidates_by_category[category] as Array).sort_custom(_sort_candidate)
	var heads: Array[Dictionary] = []
	var exact_alternatives: Array[Dictionary] = []
	for category: Variant in candidates_by_category.keys():
		var group: Array = candidates_by_category[category]
		if group.is_empty():
			continue
		heads.append(group[0] as Dictionary)
		for index: int in range(1, group.size()):
			exact_alternatives.append(group[index] as Dictionary)
	heads.sort_custom(_sort_candidate)
	exact_alternatives.sort_custom(_sort_candidate)
	var frontier: Array[Dictionary] = []
	var selected_ids: Dictionary = {}
	_append_unique_candidate(frontier, selected_ids, candidate_pool[0])
	# A capability may certify at most two exact public-state actions before the
	# ordinary diversity budget. They retain their Rule score/order and still go
	# through the shared safety shield; this only prevents pre-annotation
	# starvation at the ten-candidate transport boundary.
	var verified_candidates: Array[Dictionary] = []
	for candidate: Dictionary in candidate_pool:
		if _has_verified_advantage(candidate):
			verified_candidates.append(candidate)
	verified_candidates.sort_custom(_sort_candidate)
	for candidate: Dictionary in verified_candidates:
		if frontier.size() >= mini(max_routes, 3):
			break
		_append_unique_candidate(frontier, selected_ids, candidate)
	# Reserve a small part of the model-visible frontier for same-category
	# alternatives.  This is what lets the model choose a different attachment,
	# evolution, gust, pivot, or bench target instead of only reordering macros.
	var alternative_budget := mini(3, maxi(1, max_routes / 4))
	for candidate: Dictionary in exact_alternatives:
		if frontier.size() >= 1 + alternative_budget:
			break
		_append_unique_candidate(frontier, selected_ids, candidate)
	for candidate: Dictionary in heads:
		if frontier.size() >= max_routes:
			break
		_append_unique_candidate(frontier, selected_ids, candidate)
	for candidate: Dictionary in exact_alternatives:
		if frontier.size() >= max_routes:
			break
		_append_unique_candidate(frontier, selected_ids, candidate)
	frontier.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _sort_candidate(a, b)
	)
	if frontier.size() > max_routes:
		frontier.resize(max_routes)
	return frontier


func _append_unique_candidate(
	frontier: Array[Dictionary],
	selected_ids: Dictionary,
	candidate: Dictionary
) -> void:
	var candidate_id := str(candidate.get("candidate_id", ""))
	if candidate_id == "" or selected_ids.has(candidate_id):
		return
	selected_ids[candidate_id] = true
	frontier.append(candidate)


func _has_verified_advantage(candidate: Dictionary) -> bool:
	var local_certificates: Variant = candidate.get("local_certificates", {})
	if local_certificates is Dictionary and not (local_certificates as Dictionary).is_empty():
		return true
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	for raw_annotation: Variant in annotations.values():
		if raw_annotation is Dictionary and bool((raw_annotation as Dictionary).get("verified_advantage", false)):
			return true
	return false


func find_route(frontier: Array[Dictionary], route_id: String) -> Dictionary:
	for route: Dictionary in frontier:
		if str(route.get("route_id", "")) == route_id:
			return route
	return {}


func find_candidate(frontier: Array[Dictionary], candidate_id: String) -> Dictionary:
	for candidate: Dictionary in frontier:
		if str(candidate.get("candidate_id", "")) == candidate_id:
			return candidate
	return {}


func _candidate(
	category: String,
	action: Dictionary,
	score: float,
	facts: Dictionary,
	observation: Dictionary,
	semantic_manifest: Dictionary,
	rule_order: int
) -> Dictionary:
	var damage := int(action.get("projected_damage", 0))
	var ko := bool(action.get("projected_knockout", false))
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) if observation.get("opponent", {}) is Dictionary else {}
	var opponent_active: Dictionary = opponent.get("active", {}) if opponent.get("active", {}) is Dictionary else {}
	var prizes_now := int(opponent_active.get("prize_count", 1)) if ko else 0
	var prizes_remaining := int(own.get("prizes_remaining", facts.get("resources", {}).get("prizes_remaining", 0)))
	var information := _information_value.evaluate_action(action, observation, facts, semantic_manifest)
	var action_id := str(action.get("id", ""))
	var action_semantic_roles := _action_semantic_roles(action, semantic_manifest)
	var candidate_id := "candidate:%s" % ContractsScript.stable_hash({
		"route_id": "route:%s" % category,
		"action_id": action_id,
	}).substr(0, 20)
	return {
		"schema_version": ContractsScript.ROUTE_SCHEMA_VERSION,
		"candidate_id": candidate_id,
		"route_id": "route:%s" % category,
		"macro_action": category,
		"safe_prefix_action_id": action_id,
		"action_kind": str(action.get("kind", "")),
		"action_summary": _action_summary(action),
		"action_ref": _typed_action_ref(action),
		"local_certificates": (action.get("local_certificates", {}) as Dictionary).duplicate(true) \
			if action.get("local_certificates", {}) is Dictionary else {},
		"action_semantic_roles": action_semantic_roles,
		"route_steps": [{
			"step_id": "step:0",
			"macro_action": "route:%s" % category,
			"action_id": action_id,
		}],
		"dependencies": [],
		"reservations": _reservations(category),
		"checkpoint_after": _checkpoint_after(category),
		"base_score": score,
		"local_score": score,
		"rule_order": rule_order,
		"outcome": {
			"win_now": prizes_now > 0 and prizes_now >= prizes_remaining,
			"prizes_now": prizes_now,
			"estimated_damage": damage,
			"attack_ready": category.begins_with("attack"),
			"information_gain": float(information.get("information_gain", 0.0)),
			"board_development": 1.0 if category in ["develop", "evolve", "stadium"] else 0.0,
			"future_flexibility": 0.8 if category in ["information", "noctowl_search", "tutor", "recover", "pivot"] else 0.3,
			"uncertainty": 0.7 if category in ["information", "noctowl_search", "opening_search", "tutor"] else 0.2,
			"resource_commitment": float(information.get("resource_commitment", 0.0)),
			"board_commitment": float(information.get("board_commitment", 0.0)),
			"terminal": bool(information.get("terminal", false)),
			"expected_route_improvement": float(information.get("expected_route_improvement", 0.0)),
		},
	}


func _sort_candidate(a: Dictionary, b: Dictionary) -> bool:
	var score_a := float(a.get("local_score", 0.0))
	var score_b := float(b.get("local_score", 0.0))
	if is_equal_approx(score_a, score_b):
		var order_a := int(a.get("rule_order", 2147483647))
		var order_b := int(b.get("rule_order", 2147483647))
		if order_a != order_b:
			return order_a < order_b
		return str(a.get("candidate_id", "")) < str(b.get("candidate_id", ""))
	return score_a > score_b


func _typed_action_ref(action: Dictionary) -> Dictionary:
	var result := {
		"id": str(action.get("id", "")),
		"kind": str(action.get("kind", "")),
		"requires_interaction": bool(action.get("requires_interaction", false)),
	}
	for key: String in [
		"attack_index", "ability_index", "projected_damage", "projected_knockout",
		"source", "target", "card_instance_id", "source_instance_id",
		"target_instance_id", "rule_selected_target_slot_id",
		"rule_selected_target_instance_id", "interaction_steps",
	]:
		if action.has(key):
			var value: Variant = action.get(key)
			if value is Array:
				result[key] = (value as Array).duplicate(true)
			elif value is Dictionary:
				result[key] = (value as Dictionary).duplicate(true)
			else:
				result[key] = value
	for key: String in ["card", "source_card"]:
		var raw_card: Variant = action.get(key, {})
		if not (raw_card is Dictionary):
			continue
		var card: Dictionary = raw_card
		result[key] = {
			"instance_id": int(card.get("instance_id", -1)),
			"uid": str(card.get("uid", "")),
			"effect_id": str(card.get("effect_id", "")),
			"name": str(card.get("name", "")),
			"type": str(card.get("type", "")),
			"energy_type": str(card.get("energy_type", "")),
			"energy_provides": str(card.get("energy_provides", "")),
		}
		if key == "card" and not result.has("card_instance_id"):
			result["card_instance_id"] = int(card.get("instance_id", -1))
	return result


func _action_semantic_roles(action: Dictionary, semantic_manifest: Dictionary) -> Array[String]:
	var roles: Array[String] = []
	for key: String in ["source_card", "card"]:
		var raw_card: Variant = action.get(key, {})
		if not (raw_card is Dictionary):
			continue
		for role: String in _semantic_compiler.roles_for_card_ref(raw_card as Dictionary, semantic_manifest):
			if role != "" and not roles.has(role):
				roles.append(role)
	return roles


func _category(action: Dictionary, semantic_manifest: Dictionary) -> String:
	var kind := str(action.get("kind", ""))
	if kind in ["attack", "granted_attack"]:
		return "attack_ko" if bool(action.get("projected_knockout", false)) else "attack_pressure"
	if kind == "end_turn":
		return "end_turn"
	if kind == "retreat":
		return "pivot"
	if kind == "attach_energy":
		return "energy_commit"
	if kind == "evolve":
		return "evolve"
	if kind in ["play_basic_to_bench", "attach_tool"]:
		return "develop"
	if kind == "play_stadium":
		return "stadium"
	if kind == "use_ability":
		var source: Dictionary = action.get("source_card", {}) if action.get("source_card", {}) is Dictionary else {}
		var source_uid := str(source.get("uid", "")).strip_edges().to_upper()
		if source_uid in NOCTOWL_SEARCH_SOURCE_UIDS:
			return "noctowl_search"
		if source_uid in FAN_CALL_SOURCE_UIDS:
			return "opening_search"
		return "information"
	if kind in ["play_trainer", "use_stadium_effect"]:
		var card_ref: Dictionary = action.get("card", {}) if action.get("card", {}) is Dictionary else {}
		var roles := _semantic_compiler.roles_for_card_ref(card_ref, semantic_manifest)
		# Energy Switch contains the English word "switch", but it is an energy
		# mover rather than a board pivot.  Exact effect roles take precedence
		# over the broad lexical pivot affordance.
		if roles.has("energy_mover") or roles.has("supporter_acceleration"):
			return "accelerate"
		if roles.has("pivot"):
			return "pivot"
		if roles.has("gust"):
			return "gust"
		# Public-discard recovery and hidden-deck tutoring have materially
		# different continuation semantics. Recovery can stay inside the current
		# policy graph; tutoring is an information checkpoint whose revealed result
		# may justify one compact delta replan.
		if roles.has("recovery"):
			return "recover"
		if roles.has("trainer_tutor"):
			return "tutor"
		return "information"
	return "develop"


func _action_summary(action: Dictionary) -> String:
	# This value is model-visible. Keep it typed and localization-independent;
	# semantic meaning is carried separately by route/category annotations.
	var parts: Array[String] = ["kind=%s" % str(action.get("kind", ""))]
	var card: Variant = action.get("card", {})
	if card is Dictionary and str((card as Dictionary).get("uid", "")) != "":
		parts.append("card_uid=%s" % str((card as Dictionary).get("uid", "")))
	var source: Variant = action.get("source_card", {})
	if source is Dictionary and str((source as Dictionary).get("uid", "")) != "":
		parts.append("source_uid=%s" % str((source as Dictionary).get("uid", "")))
	if str(action.get("target", "")) != "":
		parts.append("target=%s" % str(action.get("target", "")))
	if int(action.get("projected_damage", 0)) > 0:
		parts.append("damage=%d" % int(action.get("projected_damage", 0)))
	return ";".join(parts)


func _reservations(category: String) -> Array[Dictionary]:
	if category == "energy_commit":
		return [{"resource": "quota:energy_attachment", "count": 1, "available": 1, "until": "turn_end"}]
	if category == "pivot":
		return [{"resource": "quota:retreat_or_switch", "count": 1, "available": 1, "until": "action_resolved"}]
	return []


func _checkpoint_after(category: String) -> String:
	if category in ["information", "noctowl_search", "opening_search", "tutor"]:
		return "information_result"
	if category in ["attack_ko", "attack_pressure", "end_turn"]:
		return "terminal"
	return "action_resolved"
