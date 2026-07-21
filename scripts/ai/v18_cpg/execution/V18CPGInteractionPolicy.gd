class_name V18CPGInteractionPolicy
extends RefCounted

const EnergySymbolsScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGEnergySymbols.gd")

const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")

const RANK_KEYS: Array[String] = [
	"route_completion",
	"energy_fit",
	"prize_value",
	"knockout_efficiency",
	"attacker_readiness",
	"survival",
	"resource_preservation",
	"stable_id",
]

var _semantic_compiler = SemanticCompilerScript.new()


func pick_items(
	items: Array,
	step: Dictionary,
	context: Dictionary,
	policy: Dictionary,
	profile: Dictionary,
	semantic_manifest: Dictionary,
	route_id: String
) -> Array:
	if items.is_empty():
		return []
	var min_select := maxi(int(step.get("min_select", 0)), int(policy.get("min_select", 0)))
	var step_max := int(step.get("max_select", items.size()))
	if step_max <= 0:
		step_max = items.size()
	var policy_max := int(policy.get("max_select", step_max))
	if policy_max <= 0:
		policy_max = step_max
	var selected_count := clampi(maxi(min_select, 1), 1, mini(items.size(), mini(step_max, policy_max)))
	var scored: Array[Dictionary] = []
	for index: int in items.size():
		scored.append({
			"index": index,
			"item": items[index],
			"stable_id": _stable_id(items[index]),
			"score": score_target(items[index], step, context, policy, profile, semantic_manifest, route_id),
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := float(a.get("score", 0.0))
		var score_b := float(b.get("score", 0.0))
		if is_equal_approx(score_a, score_b):
			return str(a.get("stable_id", "")) < str(b.get("stable_id", ""))
		return score_a > score_b
	)
	if min_select == 0 \
			and bool(policy.get("allow_explicit_empty", false)) \
			and float(scored[0].get("score", 0.0)) < 0.0:
		return []
	var result: Array = []
	for index: int in mini(selected_count, scored.size()):
		result.append(scored[index].get("item"))
	return result


func score_target(
	item: Variant,
	_step: Dictionary,
	_context: Dictionary,
	policy: Dictionary,
	_profile: Dictionary,
	semantic_manifest: Dictionary,
	route_id: String
) -> float:
	var roles := _roles(item, semantic_manifest)
	var desired_roles: Array = policy.get("desired_roles", []) if policy.get("desired_roles", []) is Array else []
	var preserve_roles: Array = policy.get("must_preserve", []) if policy.get("must_preserve", []) is Array else []
	var score := 0.0
	for raw_role: Variant in desired_roles:
		if str(raw_role) in roles:
			score += 320.0
	for raw_role: Variant in preserve_roles:
		if str(raw_role) in roles:
			score -= 1200.0
	var rank_by: Array = policy.get("rank_by", []) if policy.get("rank_by", []) is Array else []
	if rank_by.is_empty():
		rank_by = _default_rank_by(route_id)
	for raw_rank: Variant in rank_by:
		var rank := str(raw_rank)
		if rank not in RANK_KEYS:
			continue
		match rank:
			"route_completion":
				score += _route_completion_score(roles, route_id)
			"energy_fit":
				score += _energy_fit_score(item, policy)
			"prize_value":
				if item is PokemonSlot:
					score += float((item as PokemonSlot).get_prize_count()) * 240.0
			"knockout_efficiency":
				if item is PokemonSlot:
					score += 360.0 - minf(350.0, float((item as PokemonSlot).get_remaining_hp()))
			"attacker_readiness":
				if item is PokemonSlot:
					score += float((item as PokemonSlot).attached_energy.size()) * 110.0
			"survival":
				if item is PokemonSlot:
					score += float((item as PokemonSlot).get_remaining_hp()) * 0.5 - float((item as PokemonSlot).get_prize_count()) * 80.0
			"resource_preservation":
				score += 80.0 if roles.has("recovery") or roles.has("next_attacker") else 0.0
			"stable_id":
				pass
	return score


func default_policy_for(route_id: String, profile: Dictionary) -> Dictionary:
	var result := {
		"rank_by": _default_rank_by(route_id),
		"must_preserve": (profile.get("protected_roles", []) as Array).duplicate(true) if profile.get("protected_roles", []) is Array else [],
		"allow_explicit_empty": false,
	}
	match route_id:
		"route:energy_commit", "route:accelerate":
			result["desired_roles"] = ["energy_source", "energy_access", "energy_accelerator"]
		"route:gust", "route:attack_ko":
			result["prize_goal"] = "shortest_safe_path"
		"route:pivot":
			result["desired_roles"] = ["attacker", "alternate_attacker", "pivot"]
	return result


func _default_rank_by(route_id: String) -> Array[String]:
	match route_id:
		"route:energy_commit", "route:accelerate":
			return ["energy_fit", "route_completion", "attacker_readiness", "stable_id"]
		"route:gust", "route:attack_ko":
			return ["prize_value", "knockout_efficiency", "stable_id"]
		"route:pivot":
			return ["attacker_readiness", "survival", "stable_id"]
	return ["route_completion", "resource_preservation", "stable_id"]


func _route_completion_score(roles: Array[String], route_id: String) -> float:
	var wanted: Array[String] = []
	match route_id:
		"route:energy_commit":
			wanted = ["energy_source", "energy_access", "attacker", "next_attacker"]
		"route:accelerate":
			wanted = ["energy_accelerator", "supporter_acceleration", "attacker"]
		"route:evolve":
			wanted = ["evolution_piece", "attacker", "draw_engine"]
		"route:develop":
			wanted = ["attacker", "draw_engine", "search_engine"]
		"route:pivot":
			wanted = ["attacker", "alternate_attacker", "pivot"]
	for role: String in wanted:
		if role in roles:
			return 260.0
	return 0.0


func _energy_fit_score(item: Variant, policy: Dictionary) -> float:
	var wanted: Array = policy.get("energy_symbols", []) if policy.get("energy_symbols", []) is Array else []
	if wanted.is_empty():
		return 0.0
	var symbol := _energy_symbol(item)
	return 520.0 if symbol in wanted else -620.0


func _roles(item: Variant, semantic_manifest: Dictionary) -> Array[String]:
	var data := _card_data(item)
	if data == null:
		return []
	return _semantic_compiler.roles_for_card_data(data, semantic_manifest)


func _card_data(item: Variant) -> CardData:
	if item is CardInstance:
		return (item as CardInstance).card_data
	if item is CardData:
		return item as CardData
	if item is PokemonSlot:
		return (item as PokemonSlot).get_card_data()
	if item is Dictionary:
		var card: Variant = (item as Dictionary).get("card", null)
		if card is CardInstance:
			return (card as CardInstance).card_data
		if card is CardData:
			return card as CardData
	return null


func _energy_symbol(item: Variant) -> String:
	var data := _card_data(item)
	if data == null:
		return ""
	return EnergySymbolsScript.canonical(
		data.energy_provides if str(data.energy_provides) != "" else data.energy_type
	)


func _stable_id(item: Variant) -> String:
	if item is CardInstance:
		var card := item as CardInstance
		return "%s:%d" % [card.card_data.get_uid() if card.card_data != null else "", card.instance_id]
	if item is PokemonSlot:
		var top := (item as PokemonSlot).get_top_card()
		return "slot:%d" % (top.instance_id if top != null else -1)
	var data := _card_data(item)
	return data.get_uid() if data != null else str(item)
