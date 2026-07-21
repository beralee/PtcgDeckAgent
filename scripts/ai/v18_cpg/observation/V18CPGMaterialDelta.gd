class_name V18CPGMaterialDelta
extends RefCounted

const ContractsScript = preload("res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd")


func compare(previous: Dictionary, current: Dictionary, previous_facts: Dictionary = {}, current_facts: Dictionary = {}) -> Dictionary:
	var changed_facts: Array[String] = []
	for path: String in ContractsScript.REGISTERED_FACT_PATHS:
		var before: Variant = _fact(previous_facts, path)
		var after: Variant = _fact(current_facts, path)
		if before != after:
			changed_facts.append(path)
	var previous_actions := _action_ids(previous)
	var current_actions := _action_ids(current)
	var legal_changed := previous_actions != current_actions
	var material := false
	for path: String in changed_facts:
		if path in [
			"attack.ready",
			"attack.ko_available",
			"attack.max_damage",
			"board.bench_full",
			"board.has_tera",
			"fan_call.available",
			"information.material_action_available",
			"resources.deck_low",
			"resources.bench_slots_free",
			"resources.energy_on_board",
			"resources.distinct_energy_symbols",
			"prize.current_swing",
			"prize.win_now",
			"route.current_valid",
		]:
			material = true
			break
	var result := {
		"base_observation_version": int(previous.get("observation_version", 0)),
		"observation_version": int(current.get("observation_version", 0)),
		"legal_actions_changed": legal_changed,
		"changed_facts": changed_facts,
		"material": material,
		"previous_hash": str(previous.get("observation_hash", "")),
		"current_hash": str(current.get("observation_hash", "")),
	}
	result["material_delta_hash"] = ContractsScript.stable_hash(result)
	return result


func _action_ids(envelope: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var actions: Variant = envelope.get("legal_actions", [])
	if actions is Array:
		for raw_action: Variant in actions as Array:
			if raw_action is Dictionary:
				result.append(str((raw_action as Dictionary).get("id", "")))
	result.sort()
	return result


func _fact(facts: Dictionary, path: String) -> Variant:
	var current: Variant = facts
	for segment: String in path.split("."):
		if not (current is Dictionary):
			return null
		current = (current as Dictionary).get(segment, null)
	return current
