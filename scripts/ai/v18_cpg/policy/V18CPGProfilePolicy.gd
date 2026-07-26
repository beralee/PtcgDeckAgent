class_name V18CPGProfilePolicy
extends RefCounted

const ContractsScript = preload("res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd")

const GOALS: Array[String] = [
	"minimum_resource_ko",
	"post_attack_continuity",
	"prize_closeout",
	"next_attacker_continuity",
	"typed_energy_continuity",
	"information_before_commitment",
	"bench_space_preservation",
	"safe_pivot",
	"route_completion",
	"low_deck_safety",
]

const SAFETY_KEYS: Array[String] = [
	"max_switch_gap",
	"block_search_when_deck_low",
	"low_deck_threshold",
	"critical_deck_threshold",
	"stop_optional_draw_when_attack_ready",
	"require_payable_ko_before_gust",
	"preserve_bench_slots",
	"never_spend_reserved_attack_cost_for_non_terminal_damage",
	"reject_information_churn_after_ko_secured",
]


func sanitize(profile: Dictionary, registered_route_ids: Array[String]) -> Dictionary:
	return {
		"strategic_priorities": _sanitize_priorities(profile.get("strategic_priorities", []), registered_route_ids),
		"route_preferences": _sanitize_route_preferences(profile.get("route_preferences", {}), registered_route_ids),
		"safety": _sanitize_safety(profile.get("safety", {})),
	}


func _sanitize_priorities(raw_value: Variant, registered_route_ids: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (raw_value is Array):
		return result
	for raw_priority: Variant in raw_value as Array:
		if not (raw_priority is Dictionary):
			continue
		var priority: Dictionary = raw_priority
		var goal := str(priority.get("goal", ""))
		if goal not in GOALS:
			continue
		var item := {
			"priority": clampi(int(priority.get("priority", result.size() + 1)), 1, 100),
			"goal": goal,
			"when_all": _sanitize_guards(priority.get("when_all", [])),
			"prefer_routes": _sanitize_routes(priority.get("prefer_routes", []), registered_route_ids),
			"avoid_routes": _sanitize_routes(priority.get("avoid_routes", []), registered_route_ids),
			"preserve_roles": _sanitize_identifiers(priority.get("preserve_roles", [])),
		}
		result.append(item)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 100)) < int(b.get("priority", 100))
	)
	return result


func _sanitize_guards(raw_value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (raw_value is Array):
		return result
	for raw_guard: Variant in raw_value as Array:
		if not (raw_guard is Dictionary):
			continue
		var guard: Dictionary = raw_guard
		var fact := str(guard.get("fact", ""))
		var operator := str(guard.get("op", ""))
		if fact not in ContractsScript.REGISTERED_FACT_PATHS or operator not in ContractsScript.GUARD_OPERATORS:
			continue
		result.append({"fact": fact, "op": operator, "value": guard.get("value")})
	return result


func _sanitize_route_preferences(raw_value: Variant, registered_route_ids: Array[String]) -> Dictionary:
	if not (raw_value is Dictionary):
		return {}
	var raw: Dictionary = raw_value
	var result: Dictionary = {}
	if raw.has("model_consideration_margin"):
		result["model_consideration_margin"] = clampf(float(raw.get("model_consideration_margin", 0.0)), 0.0, 2000.0)
	for key: String in ["ready_ko_order", "attackless_order", "avoid_before_ready_attack", "avoid_after_ko_secured"]:
		if raw.has(key):
			result[key] = _sanitize_routes(raw.get(key), registered_route_ids)
	var biases: Dictionary = {}
	var raw_biases: Variant = raw.get("route_biases", {})
	if raw_biases is Dictionary:
		for raw_route_id: Variant in (raw_biases as Dictionary).keys():
			var route_id := _normalize_route_id(str(raw_route_id))
			if route_id in registered_route_ids:
				biases[route_id] = clampf(float((raw_biases as Dictionary).get(raw_route_id, 0.0)), -1000.0, 1000.0)
	if not biases.is_empty():
		result["route_biases"] = biases
	return result


func _sanitize_safety(raw_value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (raw_value is Dictionary):
		return result
	for key: String in SAFETY_KEYS:
		if (raw_value as Dictionary).has(key):
			var value: Variant = (raw_value as Dictionary).get(key)
			if value is bool:
				result[key] = value
			elif value is int or value is float:
				result[key] = clampf(float(value), 0.0, 2000.0)
	return result


func _sanitize_routes(raw_value: Variant, registered_route_ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	if not (raw_value is Array):
		return result
	for raw_route: Variant in raw_value as Array:
		var route_id := _normalize_route_id(str(raw_route))
		if route_id in registered_route_ids and not result.has(route_id):
			result.append(route_id)
	return result


func _sanitize_identifiers(raw_value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (raw_value is Array):
		return result
	for raw_identifier: Variant in raw_value as Array:
		var identifier := str(raw_identifier).strip_edges().to_lower()
		if identifier.is_valid_identifier() and not result.has(identifier):
			result.append(identifier)
	return result


func _normalize_route_id(value: String) -> String:
	return value if value.begins_with("route:") else "route:%s" % value
