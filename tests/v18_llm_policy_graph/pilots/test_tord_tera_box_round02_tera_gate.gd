extends SceneTree

const NoctowlSearchScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGTeraNoctowlSearch.gd")


func _initialize() -> void:
	var module := NoctowlSearchScript.new()
	var frontier: Array[Dictionary] = [{"route_id": "route:noctowl_search"}]
	var observation := {
		"own": {"deck_count": 30, "active": {}, "bench": []},
		"turn": {"quotas": {"supporter_available": true, "energy_available": true}},
	}
	var missing: Dictionary = module.annotate_frontier(frontier, observation, {
		"board": {"has_tera": false},
		"fan_call": {"available": true},
		"attack": {"ready": false, "ko_available": false},
	}, {})[0].get("module_annotations", {}).get("tera_noctowl_search", {})
	var ready: Dictionary = module.annotate_frontier(frontier, observation, {
		"board": {"has_tera": true},
		"fan_call": {"available": true},
		"attack": {"ready": false, "ko_available": false},
	}, {})[0].get("module_annotations", {}).get("tera_noctowl_search", {})
	var passed := not bool(missing.get("executable", true)) \
		and str(missing.get("warning", "")) == "tera_condition_missing" \
		and bool(ready.get("executable", false))
	print("tord_tera_box round02 tera gate: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
