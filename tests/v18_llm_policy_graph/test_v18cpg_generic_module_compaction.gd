extends SceneTree

const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const MODULE_IDS: Array[String] = [
	"energy_burst",
	"tera_noctowl_search",
	"cycle_pivot",
	"stage2_chain",
	"dragapult_spread",
	"damage_counter_control",
	"gardevoir_embrace",
	"control_recycle",
	"copy_attack_toolbox",
	"partner_chain",
	"grass_spread",
	"fire_toolbox",
]
const DUPLICATED_ENVELOPE_KEYS: Array[String] = [
	"module",
	"route_id",
	"category",
	"public_snapshot",
]

var _failures: Array[String] = []


func _initialize() -> void:
	var strategy := StrategyScript.new()
	var raw_by_candidate: Array[Dictionary] = [
		_raw_annotations("a", 1),
		_raw_annotations("b", 2),
	]
	var compact_by_candidate: Array[Dictionary] = []
	for candidate_index: int in raw_by_candidate.size():
		var raw: Dictionary = raw_by_candidate[candidate_index]
		var compact: Dictionary = strategy.call("_compact_module_annotations", raw)
		compact_by_candidate.append(compact)
		_check_compacted_candidate(candidate_index, raw, compact)
	_check_representative_non_defaults(compact_by_candidate)
	_check_common_hoist_round_trip(strategy, compact_by_candidate)
	if _failures.is_empty():
		print("V18CPG generic module compaction: PASS (12/12 modules, 2 candidates)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _raw_annotations(suffix: String, variant: int) -> Dictionary:
	var modules := {
		"energy_burst": {
			"target_pokemon": "target:%s" % suffix,
			"target_known": true,
			"ko_available": true,
			"deck_low": true,
			"optional_information_safe": true,
			"damage_resource": {
				"mode": "attached_discard",
				"enabled": true,
				"raw_units": 3 + variant,
				"consumptive": false,
			},
		},
		"tera_noctowl_search": {
			"visible_basic_followup_count": variant,
			"tera_ready": true,
			"fan_call_available": true,
			"typed_energy_priority_rank": -1,
			"warning": "noctowl:%s" % suffix,
		},
		"cycle_pivot": {
			"pivot": {
				"target_slot_id": "bench:%s" % suffix,
				"target_prize_count": 1 + variant,
				"would_escape_lock": true,
				"blocked": false,
			},
			"development_rank": 2 + variant,
			"has_live_attacker_root": true,
			"target_pokemon_uid": "ATTACKER_%s" % suffix.to_upper(),
		},
		"stage2_chain": {
			"typed_attachment": {
				"target_slot_id": "active:%s" % suffix,
				"target_uid": "STAGE2_%s" % suffix.to_upper(),
				"target_is_active": true,
				"required_symbols": ["R", "P"],
				"missing_before": ["P"],
				"missing_after": [],
				"completes_required_types": true,
			},
			"verified_advantage": true,
			"verified_advantage_kind": "public_typed_attack_cost_completion",
			"certificate_kind": "public_typed_attack_cost_completion",
		},
		"dragapult_spread": {
			"spread_target_count": 2 + variant,
			"decision_hints": ["solve_two_turn_prize_map", "avoid_wasted_spread"],
		},
		"damage_counter_control": {
			"movable_counter_budget": 4 + variant,
			"decision_hints": ["bind_counter_source_and_target"],
		},
		"gardevoir_embrace": {
			"psychic_energy_in_discard": 3 + variant,
			"decision_hints": ["respect_damage_budget"],
		},
		"control_recycle": {
			"non_damage_victory_live": true,
			"decision_hints": ["measure_both_deck_clocks", "preserve_recovery_loop"],
		},
		"copy_attack_toolbox": {
			"copy_source_count": 1 + variant,
			"decision_hints": ["bind_copy_source"],
		},
		"partner_chain": {
			"partner_piece_count": 1 + variant,
			"decision_hints": ["preserve_named_partner_chain"],
		},
		"grass_spread": {
			"grass_energy_on_board": 2 + variant,
			"decision_hints": ["spread_grass_energy_across_attackers"],
		},
		"fire_toolbox": {
			"fire_energy_on_board": 3 + variant,
			"decision_hints": ["bank_fire_energy", "select_attacker_before_moving_energy"],
		},
	}
	for module_id: String in MODULE_IDS:
		var annotation: Dictionary = modules[module_id]
		annotation["module"] = module_id
		annotation["route_id"] = "route:%s" % suffix
		annotation["category"] = "category:%s" % suffix
		annotation["public_snapshot"] = {"candidate": suffix, "visible": true}
		annotation["common_public_signal"] = "shared-public-context"
		annotation["wire_false"] = false
		annotation["wire_zero"] = 0
		annotation["wire_empty_string"] = ""
		annotation["wire_empty_array"] = []
		annotation["wire_empty_dictionary"] = {}
		annotation["nested_wire_defaults"] = {
			"false_value": false,
			"zero_value": 0,
			"empty_value": "",
		}
	return modules


func _check_compacted_candidate(candidate_index: int, raw: Dictionary, compact: Dictionary) -> void:
	_check(compact.size() == MODULE_IDS.size(), "candidate %d must retain all 12 module annotations" % candidate_index)
	for module_id: String in MODULE_IDS:
		var raw_module: Dictionary = raw.get(module_id, {})
		var actual: Dictionary = compact.get(module_id, {})
		var expected := _expected_module_semantics(raw_module)
		_check(actual == expected, "%s candidate %d lost or invented non-default semantics" % [module_id, candidate_index])
		for key: String in DUPLICATED_ENVELOPE_KEYS:
			_check(not actual.has(key), "%s candidate %d retained duplicated %s" % [module_id, candidate_index, key])
		for default_key: String in [
			"wire_false", "wire_zero", "wire_empty_string", "wire_empty_array",
			"wire_empty_dictionary", "nested_wire_defaults",
		]:
			_check(not actual.has(default_key), "%s candidate %d retained wire default %s" % [module_id, candidate_index, default_key])


func _check_representative_non_defaults(compacted: Array[Dictionary]) -> void:
	var first: Dictionary = compacted[0]
	var cycle: Dictionary = first.get("cycle_pivot", {})
	_check(
		str(cycle.get("pivot", {}).get("target_slot_id", "")) == "bench:a" \
			and int(cycle.get("development_rank", 0)) == 3 \
			and bool(cycle.get("has_live_attacker_root", false)),
		"cycle_pivot must preserve pivot, development rank, and live-root evidence"
	)
	var noctowl: Dictionary = first.get("tera_noctowl_search", {})
	_check(
		int(noctowl.get("visible_basic_followup_count", 0)) == 1 \
			and bool(noctowl.get("tera_ready", false)) \
			and bool(noctowl.get("fan_call_available", false)),
		"tera_noctowl_search must preserve follow-up, Tera, and Fan Call evidence"
	)
	var burst: Dictionary = first.get("energy_burst", {})
	_check(
		bool(burst.get("optional_information_safe", false)) \
			and bool(burst.get("target_known", false)) \
			and bool(burst.get("ko_available", false)) \
			and bool(burst.get("deck_low", false)) \
			and str(burst.get("target_pokemon", "")) == "target:a",
		"energy_burst must preserve optional-information, target, KO, and deck evidence"
	)
	var stage2: Dictionary = first.get("stage2_chain", {})
	_check(
		bool(stage2.get("typed_attachment", {}).get("completes_required_types", false)) \
			and str(stage2.get("verified_advantage_kind", "")) == "public_typed_attack_cost_completion" \
			and str(stage2.get("certificate_kind", "")) == "public_typed_attack_cost_completion",
		"stage2_chain must preserve typed-attachment and certificate evidence"
	)
	for expectation: Dictionary in [
		{"module": "dragapult_spread", "key": "spread_target_count", "value": 3},
		{"module": "damage_counter_control", "key": "movable_counter_budget", "value": 5},
		{"module": "gardevoir_embrace", "key": "psychic_energy_in_discard", "value": 4},
		{"module": "copy_attack_toolbox", "key": "copy_source_count", "value": 2},
		{"module": "partner_chain", "key": "partner_piece_count", "value": 2},
		{"module": "grass_spread", "key": "grass_energy_on_board", "value": 3},
		{"module": "fire_toolbox", "key": "fire_energy_on_board", "value": 4},
	]:
		var module_id := str(expectation.get("module", ""))
		var key := str(expectation.get("key", ""))
		_check(int(first.get(module_id, {}).get(key, 0)) == int(expectation.get("value", 0)), "%s must retain %s" % [module_id, key])
	_check(bool(first.get("control_recycle", {}).get("non_damage_victory_live", false)), "control_recycle must retain its non-damage victory flag")


func _check_common_hoist_round_trip(strategy: RefCounted, compacted: Array[Dictionary]) -> void:
	var frontier: Array[Dictionary] = []
	for candidate_index: int in compacted.size():
		frontier.append({
			"candidate_id": "candidate:%d" % candidate_index,
			"module_annotations": compacted[candidate_index].duplicate(true),
		})
	var factored: Dictionary = strategy.call("_factor_common_capability_context", frontier)
	var context: Dictionary = factored.get("capability_context", {})
	var overrides: Array = factored.get("frontier", []) if factored.get("frontier", []) is Array else []
	_check(context.size() == MODULE_IDS.size(), "common hoist must retain context for all 12 modules")
	_check(overrides.size() == compacted.size(), "common hoist must retain both exact candidates")
	for module_id: String in MODULE_IDS:
		_check(
			str(context.get(module_id, {}).get("common_public_signal", "")) == "shared-public-context",
			"%s common context was not hoisted" % module_id
		)
	for candidate_index: int in compacted.size():
		var candidate: Dictionary = overrides[candidate_index] if candidate_index < overrides.size() else {}
		var candidate_overrides: Dictionary = candidate.get("module_annotations", {}) \
			if candidate.get("module_annotations", {}) is Dictionary else {}
		for module_id: String in MODULE_IDS:
			var rebuilt: Dictionary = context.get(module_id, {}).duplicate(true) \
				if context.get(module_id, {}) is Dictionary else {}
			var module_override: Dictionary = candidate_overrides.get(module_id, {}) \
				if candidate_overrides.get(module_id, {}) is Dictionary else {}
			for raw_key: Variant in module_override.keys():
				rebuilt[str(raw_key)] = module_override.get(raw_key)
			_check(
				rebuilt == compacted[candidate_index].get(module_id, {}),
				"%s candidate %d cannot be reconstructed from context plus override" % [module_id, candidate_index]
			)


func _expected_module_semantics(raw: Dictionary) -> Dictionary:
	var expected: Dictionary = {}
	for raw_key: Variant in raw.keys():
		var key := str(raw_key)
		if key in DUPLICATED_ENVELOPE_KEYS:
			continue
		var compacted: Variant = _expected_sparse_value(raw.get(raw_key))
		if not _is_wire_default(compacted):
			expected[key] = compacted
	return expected


func _expected_sparse_value(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for raw_key: Variant in (value as Dictionary).keys():
			var compacted: Variant = _expected_sparse_value((value as Dictionary).get(raw_key))
			if not _is_wire_default(compacted):
				result[str(raw_key)] = compacted
		return result
	if value is Array:
		var result: Array = []
		for raw_item: Variant in value as Array:
			var compacted: Variant = _expected_sparse_value(raw_item)
			if raw_item is Dictionary or raw_item is Array:
				if not _is_wire_default(compacted):
					result.append(compacted)
			else:
				result.append(compacted)
		return result
	return value


func _is_wire_default(value: Variant) -> bool:
	if value == null:
		return true
	if value is bool:
		return not bool(value)
	if value is int or value is float:
		return is_zero_approx(float(value))
	if value is String:
		return str(value) == ""
	if value is Dictionary:
		return (value as Dictionary).is_empty()
	if value is Array:
		return (value as Array).is_empty()
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
