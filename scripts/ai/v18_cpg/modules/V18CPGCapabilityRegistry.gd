class_name V18CPGCapabilityRegistry
extends RefCounted

## Shared, typed capability composition.  Modules receive only the filtered
## observation/facts/profile contract and may annotate routes; they never own
## engine execution or read raw game objects.

const MODULE_PATHS := {
	"energy_burst": "res://scripts/ai/v18_cpg/modules/V18CPGEnergyBurst.gd",
	"tera_noctowl_search": "res://scripts/ai/v18_cpg/modules/V18CPGTeraNoctowlSearch.gd",
	"cycle_pivot": "res://scripts/ai/v18_cpg/modules/V18CPGCyclePivot.gd",
	"stage2_chain": "res://scripts/ai/v18_cpg/modules/V18CPGStrategicShapeModule.gd",
	"dragapult_spread": "res://scripts/ai/v18_cpg/modules/V18CPGStrategicShapeModule.gd",
	"damage_counter_control": "res://scripts/ai/v18_cpg/modules/V18CPGStrategicShapeModule.gd",
	"gardevoir_embrace": "res://scripts/ai/v18_cpg/modules/V18CPGStrategicShapeModule.gd",
	"control_recycle": "res://scripts/ai/v18_cpg/modules/V18CPGStrategicShapeModule.gd",
	"copy_attack_toolbox": "res://scripts/ai/v18_cpg/modules/V18CPGCopyAttackToolbox.gd",
	"partner_chain": "res://scripts/ai/v18_cpg/modules/V18CPGStrategicShapeModule.gd",
	"grass_spread": "res://scripts/ai/v18_cpg/modules/V18CPGGrassSpread.gd",
	"fire_toolbox": "res://scripts/ai/v18_cpg/modules/V18CPGEthanHoOhFireToolbox.gd",
}

var _instances: Dictionary = {}


func annotate_frontier(
	frontier: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary,
	semantic_manifest: Dictionary = {}
) -> Array[Dictionary]:
	var result := frontier.duplicate(true)
	var enabled: Variant = profile.get("modules", [])
	if not (enabled is Array):
		return result
	for raw_module_id: Variant in enabled as Array:
		var module_id := str(raw_module_id)
		var module := _module(module_id)
		if module == null:
			continue
		var annotated: Variant = null
		if module.has_method("annotate_frontier_v2"):
			annotated = module.call(
				"annotate_frontier_v2",
				result,
				observation,
				facts,
				profile,
				semantic_manifest
			)
		elif module.has_method("annotate_frontier"):
			annotated = module.call("annotate_frontier", result, observation, facts, profile)
		if annotated is Array:
			result.clear()
			for raw_route: Variant in annotated as Array:
				if raw_route is Dictionary:
					result.append(raw_route as Dictionary)
	return result


func validate_route_switch(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var enabled: Variant = profile.get("modules", [])
	if not (enabled is Array):
		return {"valid": true}
	for raw_module_id: Variant in enabled as Array:
		var module_id := str(raw_module_id)
		var module := _module(module_id)
		if module == null or not module.has_method("validate_route_switch"):
			continue
		var validation: Variant = module.call("validate_route_switch", selected, local_top, facts, profile)
		if validation is Dictionary and not bool((validation as Dictionary).get("valid", false)):
			var rejected: Dictionary = (validation as Dictionary).duplicate(true)
			rejected["module"] = module_id
			return rejected
	return {"valid": true}


func verify_route_advantage(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var enabled: Variant = profile.get("modules", [])
	if not (enabled is Array):
		return {"verified": false}
	for raw_module_id: Variant in enabled as Array:
		var module_id := str(raw_module_id)
		var module := _module(module_id)
		if module == null or not module.has_method("verify_route_advantage"):
			continue
		var verification: Variant = module.call(
			"verify_route_advantage",
			selected,
			local_top,
			facts,
			profile
		)
		if verification is Dictionary and bool((verification as Dictionary).get("verified", false)):
			var accepted: Dictionary = (verification as Dictionary).duplicate(true)
			accepted["module"] = module_id
			return accepted
	return {"verified": false}


func pick_verified_interaction_override(
	items: Array,
	step: Dictionary,
	rule_selection: Array,
	context: Dictionary,
	profile: Dictionary,
	certificate_kind: String
) -> Dictionary:
	var enabled: Variant = profile.get("modules", [])
	if not (enabled is Array):
		return {"handled": false, "items": []}
	for raw_module_id: Variant in enabled as Array:
		var module_id := str(raw_module_id)
		var module := _module(module_id)
		if module == null or not module.has_method("pick_verified_interaction_override"):
			continue
		var override: Variant = module.call(
			"pick_verified_interaction_override",
			items,
			step,
			rule_selection,
			context,
			profile,
			certificate_kind
		)
		if override is Dictionary and bool((override as Dictionary).get("handled", false)):
			var accepted: Dictionary = (override as Dictionary).duplicate(true)
			accepted["module"] = module_id
			return accepted
	return {"handled": false, "items": []}


func verified_interaction_target_score(
	item: Variant,
	step: Dictionary,
	context: Dictionary,
	profile: Dictionary,
	certificate_kind: String
) -> Variant:
	var enabled: Variant = profile.get("modules", [])
	if not (enabled is Array):
		return null
	for raw_module_id: Variant in enabled as Array:
		var module_id := str(raw_module_id)
		var module := _module(module_id)
		if module == null or not module.has_method("verified_interaction_target_score"):
			continue
		var score: Variant = module.call(
			"verified_interaction_target_score",
			item,
			step,
			context,
			profile,
			certificate_kind
		)
		if score != null:
			return score
	return null


func _module(module_id: String) -> RefCounted:
	if _instances.has(module_id):
		return _instances.get(module_id) as RefCounted
	var path := str(MODULE_PATHS.get(module_id, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var script: Variant = load(path)
	if not (script is GDScript):
		return null
	var instance: RefCounted = (script as GDScript).new()
	if instance.has_method("configure"):
		instance.call("configure", module_id)
	_instances[module_id] = instance
	return instance
