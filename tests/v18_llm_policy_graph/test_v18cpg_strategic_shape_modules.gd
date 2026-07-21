extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")

const EXPECTED := {
	"stage2_chain": {"field": "evolution_progress", "value": true, "hint": "resolve_stage2_dependency_order"},
	"dragapult_spread": {"field": "spread_target_count", "value": 2, "hint": "solve_two_turn_prize_map"},
	"damage_counter_control": {"field": "movable_counter_budget", "value": 5, "hint": "bind_counter_source_and_target"},
	"gardevoir_embrace": {"field": "psychic_energy_in_discard", "value": 2, "hint": "respect_damage_budget"},
	"control_recycle": {"field": "non_damage_victory_live", "value": true, "hint": "measure_both_deck_clocks"},
	"copy_attack_toolbox": {"field": "copy_source_count", "value": 1, "hint": "bind_copy_source"},
	"partner_chain": {"field": "partner_piece_count", "value": 1, "hint": "preserve_named_partner_chain"},
	"grass_spread": {"field": "grass_energy_on_board", "value": 2, "hint": "spread_grass_energy_across_attackers"},
	"fire_toolbox": {"field": "fire_energy_on_board", "value": 1, "hint": "bank_fire_energy"},
}

var _failures: Array[String] = []


func _initialize() -> void:
	var frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:evolve",
		"route_id": "route:evolve",
		"safe_prefix_action_id": "evolve:root",
		"action_kind": "evolve",
		"action_semantic_roles": ["evolution_piece"],
	}]
	var observation := {
		"own": {
			"deck_count": 5,
			"discard": [
				{"uid": "energy:psychic:1", "type": "Basic Energy", "energy_type": "P"},
				{"uid": "energy:psychic:2", "type": "Basic Energy", "energy_type": "Psychic"},
				{"uid": "pokemon:psychic:1", "type": "Pokemon", "energy_type": "P"},
			],
			"active": {
				"pokemon": {"uid": "pokemon:copy"},
				"energy": [{"energy_type": "G"}, {"energy_type": "Fire"}],
				"damage_counters": 3,
			},
			"bench": [{
				"pokemon": {"uid": "pokemon:partner"},
				"energy": [{"energy_type": "Grass"}],
				"damage": 20,
			}],
		},
		"opponent": {
			"deck_count": 4,
			"active": {"pokemon": {"uid": "opponent:active"}, "energy": []},
			"bench": [
				{"pokemon": {"uid": "opponent:bench:1"}, "energy": []},
				{"pokemon": {"uid": "opponent:bench:2"}, "energy": []},
			],
			# Sentinels prove the module copies only the public typed snapshot.
			"hand": [{"uid": "FORBIDDEN_SECRET_HAND_CARD"}],
			"deck_order": ["FORBIDDEN_SECRET_TOP_CARD"],
		},
	}
	var facts := {
		"attack": {"ready": false, "ko_available": false},
		"resources": {"deck_low": true, "deck_critical": false},
	}
	var manifest := {"cards": [
		{"uid": "pokemon:copy", "roles": ["copy_source"]},
		{"uid": "pokemon:partner", "roles": ["partner_piece"]},
	]}
	var rows: Array[Dictionary] = []
	for module_id: String in EXPECTED.keys():
		var profile := {"modules": [module_id]}
		var registry := CapabilityRegistryScript.new()
		var annotated := registry.annotate_frontier(frontier, observation, facts, profile, manifest)
		_check(annotated.size() == 1, "%s must preserve the exact candidate" % module_id)
		if annotated.is_empty():
			continue
		var annotations: Dictionary = annotated[0].get("module_annotations", {})
		var module_annotation: Dictionary = annotations.get(module_id, {}) if annotations.get(module_id, {}) is Dictionary else {}
		var expected: Dictionary = EXPECTED[module_id]
		var field := str(expected.get("field", ""))
		_check(module_annotation.get(field) == expected.get("value"), "%s must derive %s from public state" % [module_id, field])
		var hints: Array = module_annotation.get("decision_hints", []) if module_annotation.get("decision_hints", []) is Array else []
		_check(str(expected.get("hint", "")) in hints, "%s must expose its typed decision hint" % module_id)
		_check(str(module_annotation.get("route_id", "")) == "route:evolve", "%s must retain route identity" % module_id)
		var encoded := JSON.stringify(module_annotation)
		_check(not encoded.contains("FORBIDDEN_SECRET"), "%s must not copy hidden-zone sentinel data" % module_id)
		var validation := registry.validate_route_switch(annotated[0], frontier[0], facts, profile)
		_check(bool(validation.get("valid", false)), "%s public shape must pass typed validation" % module_id)
		_check(not bool(registry.verify_route_advantage(annotated[0], frontier[0], facts, profile).get("verified", true)), "%s must not mint an unproven dominance certificate" % module_id)
		rows.append({
			"module": module_id,
			"field": field,
			"value": module_annotation.get(field),
			"hint": str(expected.get("hint", "")),
			"hidden_sentinel_absent": not encoded.contains("FORBIDDEN_SECRET"),
			"certificate_minted": false,
		})
	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"module_count": rows.size(),
		"all_passed": _failures.is_empty() and rows.size() == EXPECTED.size(),
		"rows": rows,
		"failures": _failures.duplicate(),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/v18cpg"))
	var output := FileAccess.open("res://tmp/v18cpg/v18cpg_strategic_shape_module_fixtures.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	if bool(report.get("all_passed", false)):
		print("V18CPG strategic-shape modules: PASS (9/9 exact public-state fixtures)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG strategic-shape modules: FAIL (%d)" % _failures.size())
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
