class_name V18CPGRagingBoltTrainerPairSolver
extends RefCounted

const SemanticCompilerScript = preload(
	"res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd"
)
const ContractsScript = preload(
	"res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd"
)

var _semantic_compiler = SemanticCompilerScript.new()


func solve(
	items: Array,
	preferred_role_pairs: Array,
	required_roles: Array,
	semantic_manifest: Dictionary = {}
) -> Dictionary:
	var normalized := _normalized_items(items, semantic_manifest)
	var best: Array[Dictionary] = []
	var best_score := -INF
	for first_index: int in normalized.size():
		for second_index: int in range(first_index + 1, normalized.size()):
			var pair: Array[Dictionary] = [
				normalized[first_index],
				normalized[second_index],
			]
			var score := _pair_score(pair, preferred_role_pairs, required_roles)
			if score > best_score \
					or (
						is_equal_approx(score, best_score)
						and _pair_key(pair) < _pair_key(best)
					):
				best_score = score
				best = pair
	var selected_ids: Array[String] = []
	var covered_roles: Array[String] = []
	for item: Dictionary in best:
		selected_ids.append(str(item.get("stable_id", "")))
		for raw_role: Variant in item.get("semantic_roles", []):
			var role := str(raw_role)
			if role != "" and role not in covered_roles:
				covered_roles.append(role)
	selected_ids.sort()
	covered_roles.sort()
	var missing_roles: Array[String] = []
	for raw_role: Variant in required_roles:
		var role := str(raw_role)
		if role != "" and role not in covered_roles:
			missing_roles.append(role)
	var result := {
		"schema_version": 1,
		"selected_ids": selected_ids,
		"covered_roles": covered_roles,
		"missing_roles": missing_roles,
		"dependencies_closed": not best.is_empty() \
			and missing_roles.is_empty() \
			and _both_items_contribute(best, required_roles),
		"pair_score": best_score if not best.is_empty() else 0.0,
	}
	result["trainer_pair_id"] = "trainer_pair:%s" % ContractsScript.stable_hash({
		"selected_ids": selected_ids,
		"required_roles": required_roles,
	}).substr(0, 16)
	return result


func contract_for_profile(
	profile: Dictionary,
	required_roles: Array = []
) -> Dictionary:
	var pairs: Array = profile.get("noctowl_pair_roles", []) \
		if profile.get("noctowl_pair_roles", []) is Array else []
	var selected_required := required_roles.duplicate()
	if selected_required.is_empty() and not pairs.is_empty() and pairs[0] is Array:
		selected_required = (pairs[0] as Array).duplicate()
	return {
		"preferred_role_pairs": pairs.duplicate(true),
		"required_roles": selected_required,
		"dependencies_closed": false,
		"closure_owner": "interaction_result",
		"requires_same_pair_route_closure": true,
	}


func _normalized_items(
	items: Array,
	semantic_manifest: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in items.size():
		var raw: Variant = items[index]
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw
		var card: Dictionary = item.get("card", item) \
			if item.get("card", item) is Dictionary else item
		var roles: Array[String] = []
		var direct_roles: Variant = item.get(
			"semantic_roles",
			card.get("semantic_roles", [])
		)
		if direct_roles is Array:
			for raw_role: Variant in direct_roles:
				var role := str(raw_role)
				if role != "" and role not in roles:
					roles.append(role)
		if roles.is_empty():
			roles = _semantic_compiler.roles_for_card_ref(
				card,
				semantic_manifest
			)
		result.append({
			"stable_id": str(
				item.get(
					"stable_id",
					card.get("instance_id", card.get("uid", "item:%d" % index))
				)
			),
			"semantic_roles": roles,
		})
	return result


func _pair_score(
	pair: Array[Dictionary],
	preferred_role_pairs: Array,
	required_roles: Array
) -> float:
	var score := 0.0
	var roles := _covered_roles(pair)
	for raw_role: Variant in required_roles:
		if str(raw_role) in roles:
			score += 1000.0
	for preference_index: int in preferred_role_pairs.size():
		var raw_pair: Variant = preferred_role_pairs[preference_index]
		if not (raw_pair is Array) or (raw_pair as Array).size() != 2:
			continue
		var first_role := str((raw_pair as Array)[0])
		var second_role := str((raw_pair as Array)[1])
		if first_role in roles and second_role in roles \
				and _roles_distributed(pair, first_role, second_role):
			score += 500.0 - float(preference_index)
	score += float(roles.size())
	return score


func _covered_roles(pair: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for item: Dictionary in pair:
		for raw_role: Variant in item.get("semantic_roles", []):
			var role := str(raw_role)
			if role != "" and role not in result:
				result.append(role)
	return result


func _roles_distributed(
	pair: Array[Dictionary],
	first_role: String,
	second_role: String
) -> bool:
	if pair.size() != 2:
		return false
	var first_roles: Array = pair[0].get("semantic_roles", [])
	var second_roles: Array = pair[1].get("semantic_roles", [])
	return (
		first_role in first_roles and second_role in second_roles
	) or (
		second_role in first_roles and first_role in second_roles
	)


func _both_items_contribute(
	pair: Array[Dictionary],
	required_roles: Array
) -> bool:
	if pair.size() != 2:
		return false
	for item: Dictionary in pair:
		var contributes := false
		for raw_role: Variant in required_roles:
			if str(raw_role) in item.get("semantic_roles", []):
				contributes = true
				break
		if not contributes:
			return false
	return true


func _pair_key(pair: Array[Dictionary]) -> String:
	var ids: Array[String] = []
	for item: Dictionary in pair:
		ids.append(str(item.get("stable_id", "")))
	ids.sort()
	return "|".join(ids)
