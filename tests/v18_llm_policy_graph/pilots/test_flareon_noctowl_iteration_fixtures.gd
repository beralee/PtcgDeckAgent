extends SceneTree

const ModuleScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCyclePivot.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800017643)
	var module = ModuleScript.new()
	var requested_round := _requested_round()
	if requested_round >= 1: _round_1_optional_fez_gate(module, profile)
	if requested_round >= 2: _round_2_typed_energy_continuity(module, profile)
	if requested_round >= 3: _round_3_fan_call_order(module, profile)
	if requested_round >= 4: _round_4_jewel_pair_contract(module, profile)
	if requested_round >= 5: _round_5_ready_ko_terminal_discipline(module, profile)
	if requested_round >= 6: _round_6_lock_pivot(module)
	if requested_round >= 7: _round_7_bench_reservation(module, profile)
	if requested_round >= 8: _round_8_fallback_chip_guard(module, profile)
	if requested_round >= 9: _round_9_rebuild_protection(profile)
	if requested_round >= 10: _round_10_low_deck_churn_gate(module, profile)
	if _failures.is_empty():
		print("Flareon Noctowl V18CPG iteration fixtures: PASS (rounds 1-%d)" % requested_round)
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)


func _round_1_optional_fez_gate(module: RefCounted, profile: Dictionary) -> void:
	var result: Dictionary = module.call("validate_route_switch",
		_typed_route("route:develop", "CSV8C_135", ["optional_draw_engine"]),
		_route("route:energy_commit"),
		_facts(false, false, false, 5, true), profile)
	_check(not bool(result.get("valid", true)), "round 1 must reject stable UID CSV8C_135 before typed Energy continuity")
	var frontier: Array[Dictionary] = [
		{"route_id": "route:develop", "safe_prefix_action_id": "action:fez"},
	]
	var annotated: Array = module.call("annotate_frontier", frontier, {
		"own": {"bench": [], "deck_count": 30},
		"stadium": {},
		"legal_actions": [{"id": "action:fez", "kind": "play_basic_to_bench", "card": {"uid": "CSV8C_135", "semantic_roles": ["optional_draw_engine"]}}],
	}, _facts(false, false, false, 5, true), profile)
	var annotations: Dictionary = annotated[0].get("module_annotations", {}) if not annotated.is_empty() else {}
	var cycle: Dictionary = annotations.get("cycle_pivot", {}) if annotations.get("cycle_pivot", {}) is Dictionary else {}
	_check(bool(cycle.get("optional_draw_engine", false)), "round 1 frontier annotation must expose UID CSV8C_135 as optional")


func _round_2_typed_energy_continuity(module: RefCounted, profile: Dictionary) -> void:
	var lightning := float(module.call("typed_energy_priority", "L", ["R", "W"], profile))
	var psychic := float(module.call("typed_energy_priority", "P", ["R", "W"], profile))
	_check(lightning >= psychic + 1500.0, "round 2 must rank missing R-W-L Energy above off-color Energy")


func _round_3_fan_call_order(module: RefCounted, profile: Dictionary) -> void:
	var attacker_root := int(module.call("rank_fan_call_role", "attacker_evolution_root", profile))
	var noctowl_root := int(module.call("rank_fan_call_role", "noctowl_evolution_root", profile))
	var opening_engine := int(module.call("rank_fan_call_role", "opening_search_engine", profile))
	_check(attacker_root < noctowl_root and noctowl_root < opening_engine,
		"round 3 Fan Call order must build attacker and search lanes before optional opening engine")


func _round_4_jewel_pair_contract(module: RefCounted, profile: Dictionary) -> void:
	var pairs: Array = module.call("pair_roles", profile)
	_check(not pairs.is_empty() and pairs[0] == ["supporter_acceleration", "pokemon_search"],
		"round 4 Jewel Seeker must prefer Crispin plus a complementary Pokemon-search role")


func _round_5_ready_ko_terminal_discipline(module: RefCounted, profile: Dictionary) -> void:
	var result: Dictionary = module.call("validate_route_switch",
		_route("route:information"),
		_route("route:attack_ko"),
		_facts(true, true, false, 4, false), profile)
	_check(not bool(result.get("valid", true)) and str(result.get("reason", "")) == "flareon_ko_before_cycle",
		"round 5 must take a ready KO before information churn")


func _round_6_lock_pivot(module: RefCounted) -> void:
	_check(bool(module.call("should_pivot_from_locked_primary", true, false, 280, 0)),
		"round 6 locked primary attacker must pivot to a live 280-damage bench attacker")


func _round_7_bench_reservation(module: RefCounted, profile: Dictionary) -> void:
	_check(not bool(module.call("preserves_functional_bench_space", 4, 5, profile)),
		"round 7 one open slot must remain insufficient while two functional lanes are reserved")


func _round_8_fallback_chip_guard(module: RefCounted, profile: Dictionary) -> void:
	_check(not bool(module.call("can_use_fallback_chip", true, profile)) \
		and bool(module.call("can_use_fallback_chip", false, profile)),
		"round 8 fallback chip may consume typed Energy only without a live attacker root")


func _round_9_rebuild_protection(profile: Dictionary) -> void:
	var protected: Array = profile.get("protected_roles", [])
	_check("recovery" in protected and "next_attacker" in protected and "primary_rwl_energy" in protected,
		"round 9 rebuild must protect recovery, the next attacker, and R-W-L Energy")


func _round_10_low_deck_churn_gate(module: RefCounted, profile: Dictionary) -> void:
	var result: Dictionary = module.call("validate_route_switch",
		_typed_route("route:information", "151C_151", ["optional_draw_engine"]),
		_route("route:attack_pressure"),
		_facts(false, true, true, 3, false), profile)
	_check(not bool(result.get("valid", true)) and str(result.get("reason", "")) == "flareon_low_deck_blocks_cycle",
		"round 10 low deck must block optional draw/search churn")


func _route(route_id: String) -> Dictionary:
	return {"route_id": route_id}


func _typed_route(route_id: String, card_uid: String, roles: Array) -> Dictionary:
	return {
		"route_id": route_id,
		"action_card_uid": card_uid,
		"action_semantic_roles": roles.duplicate(),
		"optional_draw_engine": "optional_draw_engine" in roles,
	}


func _facts(ko_available: bool, attack_ready: bool, deck_low: bool, hand_size: int, energy_available: bool) -> Dictionary:
	return {
		"attack": {"ko_available": ko_available, "ready": attack_ready},
		"resources": {"deck_low": deck_low, "hand_size": hand_size},
		"board": {"bench_full": false},
		"turn": {"energy_available": energy_available},
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _requested_round() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--round="):
			return clampi(int(arg.get_slice("=", 1)), 1, 10)
	return 10
