class_name V18CPGProfileCatalog
extends RefCounted

const ContractsScript = preload("res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd")
const RuleProfileCatalogScript = preload("res://scripts/ai/DeckStrategyV18ProfileCatalog.gd")

const PILOT_DECK_IDS: Array[int] = [800018509, 800017643, 800015934]
const ALL_DECK_IDS: Array[int] = [
	18000230, 18000625, 800015734, 800015934, 800016834, 800017047,
	800017097, 800017407, 800017631, 800017643, 800018105, 800018359,
	800018497, 800018498, 800018499, 800018500, 800018501, 800018502,
	800018509, 800018539, 800018543, 800018880, 800019125, 800033475,
]
const DECK_MODULES := {
	18000230: ["stage2_chain", "dragapult_spread", "energy_burst"],
	18000625: ["damage_counter_control", "stage2_chain", "energy_burst"],
	800015734: ["dragapult_spread", "damage_counter_control", "stage2_chain"],
	800015934: ["tera_noctowl_search", "energy_burst", "cycle_pivot"],
	800016834: ["energy_burst", "cycle_pivot"],
	800017047: ["stage2_chain", "energy_burst", "cycle_pivot"],
	800017097: ["gardevoir_embrace", "damage_counter_control"],
	800017407: ["partner_chain", "energy_burst", "cycle_pivot"],
	800017631: ["damage_counter_control", "control_recycle"],
	800017643: ["tera_noctowl_search", "energy_burst", "cycle_pivot"],
	800018105: ["gardevoir_embrace", "damage_counter_control"],
	800018359: ["control_recycle", "stage2_chain", "cycle_pivot"],
	800018497: ["gardevoir_embrace", "damage_counter_control"],
	800018498: ["gardevoir_embrace", "damage_counter_control"],
	800018499: ["dragapult_spread", "stage2_chain", "damage_counter_control"],
	800018500: ["grass_spread", "energy_burst", "cycle_pivot"],
	800018501: ["stage2_chain", "energy_burst", "damage_counter_control"],
	800018502: ["copy_attack_toolbox", "partner_chain", "cycle_pivot"],
	800018509: ["energy_burst", "tera_noctowl_search", "cycle_pivot"],
	800018539: ["fire_toolbox", "partner_chain", "energy_burst"],
	800018543: ["partner_chain", "stage2_chain", "cycle_pivot", "damage_counter_control"],
	800018880: ["partner_chain", "stage2_chain", "cycle_pivot"],
	800019125: ["stage2_chain", "dragapult_spread", "energy_burst"],
	800033475: ["cycle_pivot", "grass_spread"],
}
const PROFILE_OVERRIDE_ROOT := "res://scripts/ai/v18_cpg/profiles"
const PROFILE_OVERRIDE_KEYS: Array[String] = [
	"profile_version",
	"semantic_version",
	"risk_posture",
	"switch_margin",
	"expected_regret_threshold",
	"initial_response_token_budget",
	"delta_response_token_budget",
	"turn_visible_wait_budget_ms",
	"cold_request_estimate_ms",
	"max_policy_nodes",
	"semantic_role_overrides",
	"public_flow",
	"protected_roles",
	"noctowl_pair_roles",
	"strategic_priorities",
	"route_preferences",
	"safety",
	"module_parameters",
	"local_action_certificate_parameters",
]

const _PILOTS := {
	800018509: {
		"slug": "raging_bolt_ogerpon",
		"display_name": "18.0 猛雷鼓厄诡椪",
		"primary_module": "energy_burst",
		"modules": ["energy_burst", "tera_noctowl_search"],
		"victory_mode": "prize_race",
		"risk_posture": "balanced",
		"switch_margin": 70.0,
		"expected_regret_threshold": 90.0,
		"protected_roles": ["next_attacker", "energy_access", "recovery"],
		"noctowl_pair_roles": [
			["supporter_acceleration", "energy_access"],
			["energy_access", "pokemon_search"],
			["gust", "energy_access"],
			["stadium", "pokemon_search"],
		],
	},
	800017643: {
		"slug": "flareon_noctowl",
		"display_name": "18.0 火伊布猫头夜鹰",
		"primary_module": "tera_noctowl_search",
		"modules": ["tera_noctowl_search", "cycle_pivot"],
		"victory_mode": "prize_race",
		"risk_posture": "balanced",
		"switch_margin": 60.0,
		"expected_regret_threshold": 75.0,
		"protected_roles": ["next_attacker", "typed_energy", "pivot"],
		"noctowl_pair_roles": [
			["supporter_acceleration", "energy_access"],
			["stadium", "energy_access"],
			["pokemon_search", "pivot"],
			["gust", "typed_energy_access"],
		],
	},
	800015934: {
		"slug": "tord_tera_box",
		"display_name": "18.0 Tord太晶盒",
		"primary_module": "tera_noctowl_search",
		"modules": ["tera_noctowl_search"],
		"victory_mode": "prize_race",
		"risk_posture": "safe",
		"switch_margin": 80.0,
		"expected_regret_threshold": 85.0,
		"protected_roles": ["toolbox_attacker", "typed_energy", "bench_space", "pivot"],
		"noctowl_pair_roles": [
			["supporter_acceleration", "energy_mover"],
			["energy_access", "energy_mover"],
			["stadium", "pokemon_search"],
			["pivot", "recovery"],
		],
	},
}


static func get_profile_for_deck(deck_id: int, include_override: bool = true) -> Dictionary:
	if deck_id not in ALL_DECK_IDS:
		return {}
	var rule_profile := RuleProfileCatalogScript.get_profile_for_deck(deck_id)
	if rule_profile.is_empty():
		return {}
	var profile: Dictionary = (_PILOTS[deck_id] as Dictionary).duplicate(true) if _PILOTS.has(deck_id) else _default_profile_delta(rule_profile)
	var modules: Array = DECK_MODULES.get(deck_id, []) if DECK_MODULES.get(deck_id, []) is Array else []
	profile["modules"] = modules.duplicate()
	profile["primary_module"] = str(modules[0]) if not modules.is_empty() else ""
	profile["deck_id"] = deck_id
	profile["strategy_id"] = ContractsScript.strategy_id(deck_id, str(profile.get("slug", "")))
	profile["base_strategy_id"] = RuleProfileCatalogScript.strategy_id_for_deck(deck_id)
	profile["runtime_kind"] = ContractsScript.RUNTIME_KIND
	profile["requires_model"] = true
	profile["experimental"] = true
	profile["profile_version"] = 1
	profile["semantic_version"] = 1
	profile["schema_version"] = ContractsScript.SCHEMA_VERSION
	profile["feature_flag"] = ContractsScript.FEATURE_FLAG
	profile["initial_response_token_budget"] = 450
	profile["delta_response_token_budget"] = 220
	profile["turn_visible_wait_budget_ms"] = 6500
	profile["cold_request_estimate_ms"] = 5000
	profile["max_policy_nodes"] = ContractsScript.DEFAULT_MAX_POLICY_NODES
	# A profile override may intentionally tune bounded response budgets and
	# schema node limits, but never identity, runtime kind, or rule ownership.
	if include_override:
		profile = _merge_profile_override(profile, deck_id)
	profile["rule_profile"] = rule_profile
	return profile


static func _default_profile_delta(rule_profile: Dictionary) -> Dictionary:
	var strategy_id := str(rule_profile.get("strategy_id", ""))
	var deck_id := int(rule_profile.get("deck_id", 0))
	var slug := strategy_id.trim_prefix("v18_%d_" % deck_id)
	var control_decks: Array[int] = [800017631, 800018359]
	return {
		"slug": slug,
		"display_name": str(rule_profile.get("deck_name", "18.0 %d" % deck_id)),
		"victory_mode": "control" if deck_id in control_decks else "prize_race",
		"risk_posture": "safe" if deck_id in control_decks else "balanced",
		"switch_margin": 70.0,
		"expected_regret_threshold": 100.0,
		"protected_roles": ["current_attacker", "next_attacker", "energy_access", "recovery", "bench_space"],
		"noctowl_pair_roles": [
			["supporter_acceleration", "energy_access"],
			["pokemon_search", "energy_access"],
			["gust", "energy_access"],
			["pivot", "recovery"],
		],
		"strategic_priorities": _default_priorities(),
		"route_preferences": {
			"model_consideration_margin": 180.0,
			"route_biases": {"route:attack_ko": 160.0, "route:attack_pressure": 60.0, "route:end_turn": -80.0},
		},
		"safety": {
			"max_switch_gap": 90.0,
			"block_search_when_deck_low": true,
			"low_deck_threshold": 8,
			"critical_deck_threshold": 5,
			"preserve_bench_slots": 1,
			"stop_optional_draw_when_attack_ready": true,
		},
		"module_parameters": {},
	}


static func _default_priorities() -> Array[Dictionary]:
	return [{
		"priority": 1,
		"goal": "minimum_resource_ko",
		"when_all": [{"fact": "attack.ko_available", "op": "==", "value": true}],
		"prefer_routes": ["route:attack_ko", "route:gust"],
		"avoid_routes": ["route:information", "route:develop", "route:end_turn"],
		"preserve_roles": ["next_attacker", "energy_access"],
	}, {
		"priority": 2,
		"goal": "next_attacker_continuity",
		"when_all": [{"fact": "attack.ready", "op": "==", "value": false}],
		"prefer_routes": ["route:evolve", "route:energy_commit", "route:accelerate", "route:pivot"],
		"avoid_routes": ["route:end_turn"],
		"preserve_roles": ["next_attacker", "recovery"],
	}, {
		"priority": 3,
		"goal": "low_deck_safety",
		"when_all": [{"fact": "resources.deck_low", "op": "==", "value": true}],
		"prefer_routes": ["route:attack_ko", "route:attack_pressure", "route:pivot"],
		"avoid_routes": ["route:information", "route:opening_search", "route:noctowl_search"],
		"preserve_roles": ["recovery", "next_attacker"],
	}]


static func _merge_profile_override(base: Dictionary, deck_id: int) -> Dictionary:
	var merged := base.duplicate(true)
	var path := "%s/%d.json" % [PROFILE_OVERRIDE_ROOT, deck_id]
	if not FileAccess.file_exists(path):
		return merged
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_warning("V18CPG ignored invalid profile override JSON: %s" % path)
		return merged
	for key: String in PROFILE_OVERRIDE_KEYS:
		if (parsed as Dictionary).has(key):
			merged[key] = (parsed as Dictionary).get(key)
	return merged


static func get_profile_for_strategy(strategy_id: String) -> Dictionary:
	for deck_id: int in ALL_DECK_IDS:
		var profile := get_profile_for_deck(deck_id)
		if str(profile.get("strategy_id", "")) == strategy_id:
			return profile
	return {}


static func list_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for deck_id: int in ALL_DECK_IDS:
		result.append(get_profile_for_deck(deck_id))
	return result


static func list_variant_metadata(feature_enabled: bool = false) -> Array[Dictionary]:
	if not feature_enabled:
		return []
	var result: Array[Dictionary] = []
	for profile: Dictionary in list_profiles():
		result.append({
			"id": str(profile.get("strategy_id", "")),
			"base_strategy_id": str(profile.get("base_strategy_id", "")),
			"runtime_kind": ContractsScript.RUNTIME_KIND,
			"requires_model": true,
			"experimental": true,
			"label": "18.0 条件策略大模型版 %s" % str(profile.get("display_name", "")).trim_prefix("18.0 "),
		})
	return result
