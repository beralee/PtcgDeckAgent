extends SceneTree

const NoctowlSearchScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGTeraNoctowlSearch.gd")


func _initialize() -> void:
	var module := NoctowlSearchScript.new()
	var frontier: Array[Dictionary] = [{
		"route_id": "route:energy_commit",
		"safe_prefix_action_id": "attach_psychic",
	}]
	var observation := {
		"own": {
			"deck_count": 28,
			"active": {"energy": [{"energy_provides": "G"}]},
			"bench": [],
		},
		"turn": {"quotas": {"energy_available": true, "supporter_available": true}},
		"legal_actions": [{
			"id": "attach_psychic",
			"kind": "attach_energy",
			"card": {"energy_provides": "P", "type": "Basic Energy"},
		}],
	}
	var annotated: Dictionary = module.annotate_frontier(frontier, observation, {
		"board": {"has_tera": true},
		"fan_call": {"available": true},
		"attack": {"ready": false, "ko_available": false},
	}, {"module_parameters": {"tera_noctowl_search": {"typed_energy_priority": ["W", "P", "M", "L", "G"]}}})[0]
	var note: Dictionary = annotated.get("module_annotations", {}).get("tera_noctowl_search", {})
	var passed := int(note.get("distinct_energy_symbols", 0)) == 1 \
		and str(note.get("commit_energy_symbol", "")) == "P" \
		and bool(note.get("adds_distinct_energy_symbol", false)) \
		and int(note.get("typed_energy_priority_rank", -1)) == 1
	print("tord_tera_box round05 typed energy frontier: %s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
