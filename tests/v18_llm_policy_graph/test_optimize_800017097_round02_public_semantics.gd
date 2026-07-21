extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800017097)
	_check(int(profile.get("profile_version", 0)) >= 3, "round02 profile must be active")
	_check(int(profile.get("turn_visible_wait_budget_ms", 0)) == 6500, "round02 must not increase visible wait")
	_check(int(profile.get("initial_response_token_budget", 0)) == 400, "round02 must keep the compact initial budget")
	_check(int(profile.get("delta_response_token_budget", 0)) == 170, "round02 must keep the compact delta budget")
	_check(int(profile.get("max_policy_nodes", 0)) == 6, "round02 must not increase the graph bound")
	_test_exact_profile_parameters(profile)
	_test_drifloon_charm_closeout(profile)
	_test_munkidori_dark_closeout(profile)
	_test_non_attacker_and_bench_boundaries(profile)
	_test_no_paired_certificate_inheritance(profile)
	if _failures.is_empty():
		print("V18CPG 800017097 round02 public semantics: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_exact_profile_parameters(profile: Dictionary) -> void:
	var parameters: Dictionary = profile.get("module_parameters", {})
	var embrace: Dictionary = parameters.get("gardevoir_embrace", {})
	var counter: Dictionary = parameters.get("damage_counter_control", {})
	_check(embrace.get("embrace_engine_uids", []) == ["CSV2C_055"], "only Gardevoir ex may source the public Embrace sequence")
	_check(int(embrace.get("prize_scaler_tools", {}).get("CSV1C_118", {}).get("hp_bonus", 0)) == 50, "Bravery Charm must expose exact +50 HP")
	var drifloon: Dictionary = embrace.get("damage_scalers_by_uid", {}).get("CSV2C_060", {})
	_check(drifloon.get("attack_cost", []) == ["P", "P"], "Drifloon must retain its exact PP cost")
	_check(int(drifloon.get("damage_per_counter", 0)) == 30, "Drifloon must expose 30 damage per counter")
	_check(int(drifloon.get("embrace_damage_per_assignment", 0)) == 20, "each Embrace assignment must add exactly two counters")
	var scream: Dictionary = embrace.get("damage_scalers_by_uid", {}).get("CSV6C_065", {})
	_check(int(scream.get("damage_per_counter", 0)) == 20, "Scream Tail must expose 20 damage per counter")
	_check(str(counter.get("counter_mover_uid", "")) == "CSV8C_094", "Munkidori must be the exact counter mover")
	_check(str(counter.get("activation_symbol", "")) == "D", "Munkidori must reserve Darkness activation")
	_check(int(counter.get("move_points_per_use", 0)) == 30, "Munkidori must expose the exact 30-point move")
	_check(counter.get("damage_invariant_attackers", []) == ["CSV2C_055"], "Gardevoir damage must remain invariant while moving its counters")


func _test_drifloon_charm_closeout(profile: Dictionary) -> void:
	var frontier: Array[Dictionary] = [
		_candidate("rule:develop", "route:evolve", "evolve", 2000.0, {"kind": "evolve"}),
		_candidate("charm:drifloon", "route:develop", "attach_tool", -4000.0, {
			"kind": "attach_tool",
			"card": {"uid": "CSV1C_118", "type": "Tool"},
			"target": "slot:active",
		}),
	]
	var observation := {
		"own": {
			"prizes_remaining": 2,
			"deck_count": 20,
			"hand": [{"uid": "CSV1C_118", "type": "Tool"}],
			"discard": _psychic_discard(4),
			"active": _slot("slot:active", "CSV2C_060", 70, 0),
			"bench": [_slot("slot:engine", "CSV2C_055", 310, 0)],
		},
		"opponent": {
			"deck_count": 20,
			"active": _slot("slot:opponent", "CSV6C_051", 230, 0, 2),
			"bench": [],
		},
	}
	var facts := {"attack": {"ready": false, "ko_available": false}, "resources": {"prizes_remaining": 2, "deck_low": false}}
	var annotated := CapabilityRegistryScript.new().annotate_frontier(frontier, observation, facts, profile, {})
	var certificate: Dictionary = _module(annotated[1], "gardevoir_embrace").get("prize_scaler_tool", {})
	_check(int(certificate.get("required_assignments", 0)) == 4, "230 HP must require four public Embrace assignments for Drifloon")
	_check(int(certificate.get("projected_damage", 0)) == 240, "four assignments must project exactly 240 Drifloon damage")
	_check(not bool(certificate.get("safe_without_tool", true)), "untooled 70 HP Drifloon must not survive four assignments")
	_check(bool(certificate.get("safe_with_tool", false)), "Bravery Charm Drifloon must survive four assignments")
	_check(bool(certificate.get("wins_now_after_public_embrace_sequence", false)), "the exact public sequence must take the last two prizes")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var upgrade: Dictionary = strategy._find_module_verified_upgrade(annotated, facts)
	_check(str(upgrade.get("candidate_id", "")) == "charm:drifloon", "the deterministic Drifloon closeout must survive the Rule score gap")
	_check(str(upgrade.get("verified_advantage", {}).get("certificate_kind", "")) == "public_prize_scaler_tool_closeout", "the public damage arithmetic must expose the exact closeout certificate")
	_check(str(upgrade.get("verified_advantage", {}).get("evidence_kind", "")) != "paired_evaluation", "the deterministic public closeout must not be mislabeled as paired evidence")


func _test_munkidori_dark_closeout(profile: Dictionary) -> void:
	var frontier: Array[Dictionary] = [
		_candidate("rule:attack", "route:attack_pressure", "attack", 3000.0, {"kind": "attack"}),
		_candidate("dark:munkidori", "route:energy_commit", "attach_energy", -4000.0, {
			"kind": "attach_energy",
			"card": {"uid": "CSVE1C_DAR", "type": "Basic Energy", "energy_type": "D"},
			"target": "slot:mover",
		}),
	]
	var observation := {
		"own": {
			"prizes_remaining": 2,
			"deck_count": 20,
			"hand": [{"uid": "CSVE1C_DAR", "type": "Basic Energy", "energy_type": "D"}],
			"discard": [],
			"active": _slot("slot:active", "CSV2C_055", 280, 30, 2, ["P", "P", "D"]),
			"bench": [_slot("slot:mover", "CSV8C_094", 110, 0)],
		},
		"opponent": {"deck_count": 20, "active": _slot("slot:opponent", "CSV6C_051", 230, 0, 2), "bench": []},
	}
	var facts := {
		"attack": {"ready": true, "ko_available": false, "max_damage": 200},
		"resources": {"prizes_remaining": 2, "deck_low": false},
		"turn": {"energy_available": true, "supporter_available": true},
	}
	var annotated := CapabilityRegistryScript.new().annotate_frontier(frontier, observation, facts, profile, {})
	var certificate: Dictionary = _module(annotated[1], "damage_counter_control").get("counter_mover_closeout", {})
	_check(int(certificate.get("damage_gap", 0)) == 30, "the exact Gardevoir line must expose a 30-point damage gap")
	_check(bool(certificate.get("advances_final_prize_closeout", false)), "Darkness to Munkidori must advance the final-prize sequence")


func _test_non_attacker_and_bench_boundaries(profile: Dictionary) -> void:
	var observation := {
		"own": {
			"prizes_remaining": 6,
			"deck_count": 30,
			"hand": [{"uid": "CSVE1C_PSY", "type": "Basic Energy", "energy_type": "P"}],
			"discard": [],
			"active": _slot("slot:active", "CSV8C_135", 210, 0, 2),
			"bench": [_slot("slot:drifloon", "CSV2C_060", 70, 0)],
		},
		"opponent": {"active": _slot("slot:opponent", "CSV6C_051", 230, 0, 2), "bench": []},
	}
	var facts := {"attack": {"ready": false, "ko_available": false}, "resources": {"prizes_remaining": 6}, "turn": {"energy_available": true}}
	var fez_frontier: Array[Dictionary] = [
		_candidate("rule:end", "route:end_turn", "end_turn", -924.0, {}),
		_candidate("attach:fez", "route:energy_commit", "attach_energy", 1000.0, {
			"card": {"uid": "CSVE1C_PSY", "type": "Basic Energy", "energy_type": "P"}, "target": "slot:active",
		}),
	]
	var annotated_fez := CapabilityRegistryScript.new().annotate_frontier(fez_frontier, observation, facts, profile, {})
	var fez_typed: Dictionary = _module(annotated_fez[1], "gardevoir_embrace").get("typed_attachment", {})
	_check(not bool(fez_typed.get("target_is_profiled_attacker", false)), "Fezandipiti ex must not become a profiled attacker")
	_check(not bool(_module(annotated_fez[1], "gardevoir_embrace").get("verified_advantage", false)), "Fezandipiti attachment must not receive a deterministic certificate")

	var bench_frontier: Array[Dictionary] = [
		_candidate("rule:end", "route:end_turn", "end_turn", -924.0, {}),
		_candidate("attach:bench_drifloon", "route:energy_commit", "attach_energy", 500.0, {
			"card": {"uid": "CSVE1C_PSY", "type": "Basic Energy", "energy_type": "P"}, "target": "slot:drifloon",
		}),
	]
	var annotated_bench := CapabilityRegistryScript.new().annotate_frontier(bench_frontier, observation, facts, profile, {})
	var bench_typed: Dictionary = _module(annotated_bench[1], "gardevoir_embrace").get("typed_attachment", {})
	_check(bool(bench_typed.get("target_is_profiled_attacker", false)), "Drifloon must remain a typed attacker")
	_check(not bool(bench_typed.get("target_is_active", true)), "a Bench Drifloon attachment must remain non-Active")
	_check(not bool(_module(annotated_bench[1], "gardevoir_embrace").get("verified_advantage", false)), "Bench completion must not become an autonomous typed closeout")


func _test_no_paired_certificate_inheritance(profile: Dictionary) -> void:
	var embrace: Dictionary = profile.get("module_parameters", {}).get("gardevoir_embrace", {})
	var counter: Dictionary = profile.get("module_parameters", {}).get("damage_counter_control", {})
	_check(str(embrace.get("profiled_engine_search_uid", "")) == "", "no standard-Gardevoir engine-search evidence may be inherited")
	_check(str(embrace.get("profiled_retreat_bridge_active_uid", "")) == "", "no standard-Gardevoir retreat bridge may be inherited")
	_check(str(counter.get("profiled_activation_opening_required_bench_uid", "")) == "", "no standard-Gardevoir opening activation evidence may be inherited")
	_check(counter.get("setup_active_uids", []).is_empty(), "no academy low-pressure setup evidence may be inherited")
	_check(str(counter.get("midgame_reset_supporter_uid", "")) == "", "no academy paired reset evidence may be inherited")


func _candidate(candidate_id: String, route_id: String, action_kind: String, score: float, action_ref: Dictionary) -> Dictionary:
	return {
		"candidate_id": candidate_id,
		"route_id": route_id,
		"safe_prefix_action_id": "action:%s" % candidate_id,
		"action_kind": action_kind,
		"action_ref": action_ref,
		"base_score": score,
		"local_score": score,
		"outcome": {"win_now": false, "prizes_now": 0},
	}


func _module(candidate: Dictionary, module_id: String) -> Dictionary:
	return candidate.get("module_annotations", {}).get(module_id, {})


func _psychic_discard(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in count:
		result.append({"uid": "discard:p%d" % index, "type": "Basic Energy", "energy_type": "P"})
	return result


func _slot(
	slot_id: String,
	uid: String,
	remaining_hp: int,
	damage: int,
	prize_count: int = 1,
	energy_symbols: Array[String] = []
) -> Dictionary:
	var energy: Array[Dictionary] = []
	for index: int in energy_symbols.size():
		energy.append({"uid": "attached:%d" % index, "type": "Basic Energy", "energy_type": energy_symbols[index]})
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid},
		"tool": {},
		"energy": energy,
		"damage": damage,
		"remaining_hp": remaining_hp,
		"max_hp": remaining_hp + damage,
		"prize_count": prize_count,
		"ability_used": false,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
