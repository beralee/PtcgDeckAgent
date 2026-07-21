extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800018497)
	_check(int(profile.get("profile_version", 0)) >= 3, "round02 profile must be active")
	_check(int(profile.get("turn_visible_wait_budget_ms", 0)) == 6500, "round02 must not increase visible wait")
	_check(int(profile.get("initial_response_token_budget", 0)) == 400, "round02 must keep the compact initial budget")
	_check(int(profile.get("delta_response_token_budget", 0)) == 170, "round02 must keep the compact delta budget")
	_test_exact_profile_parameters(profile)
	_test_scream_tail_charm_closeout(profile)
	_test_munkidori_dark_closeout(profile)
	_test_academy_only_certificates_are_absent(profile)
	if _failures.is_empty():
		print("V18CPG 800018497 round02 public semantics: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_exact_profile_parameters(profile: Dictionary) -> void:
	var parameters: Dictionary = profile.get("module_parameters", {})
	var embrace: Dictionary = parameters.get("gardevoir_embrace", {})
	var counter: Dictionary = parameters.get("damage_counter_control", {})
	_check(embrace.get("embrace_engine_uids", []) == ["CSV2C_055"], "only Gardevoir ex may source the profiled Embrace sequence")
	_check(int(embrace.get("prize_scaler_tools", {}).get("CSV1C_118", {}).get("hp_bonus", 0)) == 50, "Bravery Charm must expose its exact +50 HP public value")
	var scream_tail: Dictionary = embrace.get("damage_scalers_by_uid", {}).get("CSV6C_065", {})
	_check(scream_tail.get("attack_cost", []) == ["P", "C"], "Scream Tail must retain its exact attack cost")
	_check(int(scream_tail.get("damage_per_counter", 0)) == 20, "Scream Tail must expose 20 damage per counter")
	_check(str(counter.get("counter_mover_uid", "")) == "CSV8C_094", "Munkidori must be the exact counter mover")
	_check(str(counter.get("activation_symbol", "")) == "D", "Munkidori must reserve Darkness activation")
	_check(int(counter.get("move_points_per_use", 0)) == 30, "Munkidori must expose the exact 30-point move")


func _test_scream_tail_charm_closeout(profile: Dictionary) -> void:
	var frontier: Array[Dictionary] = [
		_candidate("rule:develop", "route:evolve", "evolve", 2000.0, {"kind": "evolve"}),
		_candidate("charm:scream_tail", "route:develop", "attach_tool", -4000.0, {
			"kind": "attach_tool",
			"card": {"uid": "CSV1C_118", "type": "Tool"},
			"target": "slot:active",
		}),
	]
	var discard: Array[Dictionary] = []
	for index: int in 6:
		discard.append({"uid": "energy:%d" % index, "type": "Basic Energy", "energy_type": "P"})
	var observation := {
		"own": {
			"prizes_remaining": 2,
			"deck_count": 20,
			"hand": [{"uid": "CSV1C_118", "type": "Tool"}],
			"discard": discard,
			"active": _slot("slot:active", "CSV6C_065", 90, 0),
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
	var certificate: Dictionary = annotated[1].get("module_annotations", {}).get("gardevoir_embrace", {}).get("prize_scaler_tool", {})
	_check(int(certificate.get("required_assignments", 0)) == 6, "230 HP must require six Embrace assignments for Scream Tail")
	_check(int(certificate.get("projected_damage", 0)) == 240, "six assignments must project 240 Scream Tail damage")
	_check(not bool(certificate.get("safe_without_tool", true)), "90 HP Scream Tail must not survive six assignments without Charm")
	_check(bool(certificate.get("safe_with_tool", false)), "140 HP Scream Tail must survive the exact six-assignment sequence")
	_check(bool(certificate.get("wins_now_after_public_embrace_sequence", false)), "the public Charm sequence must take the last two prizes")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var upgrade: Dictionary = strategy._find_module_verified_upgrade(annotated, facts)
	_check(str(upgrade.get("candidate_id", "")) == "charm:scream_tail", "the exact Scream Tail closeout must survive any Rule score gap")


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
		"opponent": {
			"deck_count": 20,
			"active": _slot("slot:opponent", "CSV6C_051", 230, 0, 2),
			"bench": [],
		},
	}
	var facts := {
		"attack": {"ready": true, "ko_available": false, "max_damage": 200},
		"resources": {"prizes_remaining": 2, "deck_low": false},
		"turn": {"energy_available": true, "supporter_available": true},
	}
	var annotated := CapabilityRegistryScript.new().annotate_frontier(frontier, observation, facts, profile, {})
	var certificate: Dictionary = annotated[1].get("module_annotations", {}).get("damage_counter_control", {}).get("counter_mover_closeout", {})
	_check(str(certificate.get("activation_symbol", "")) == "D", "the final counter mover must be activated by Darkness")
	_check(int(certificate.get("damage_gap", 0)) == 30, "the exact Gardevoir pressure line must expose a 30-point gap")
	_check(str(certificate.get("closeout_stage", "")) == "activate_second_counter_mover", "Darkness attachment must be the public next step")
	_check(bool(certificate.get("advances_final_prize_closeout", false)), "Darkness to Munkidori must advance the final-prize sequence")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var upgrade: Dictionary = strategy._find_module_verified_upgrade(annotated, facts)
	_check(str(upgrade.get("candidate_id", "")) == "dark:munkidori", "the exact Darkness activation must survive the Rule score gap")


func _test_academy_only_certificates_are_absent(profile: Dictionary) -> void:
	var embrace: Dictionary = profile.get("module_parameters", {}).get("gardevoir_embrace", {})
	var counter: Dictionary = profile.get("module_parameters", {}).get("damage_counter_control", {})
	_check(not embrace.get("damage_scalers_by_uid", {}).has("CSV2C_060"), "the standard deck must not inherit the academy Drifloon scaler")
	_check(counter.get("setup_active_uids", []).is_empty(), "the standard deck must not inherit the Budew setup trigger")
	_check(str(counter.get("midgame_reset_supporter_uid", "")) == "", "the standard deck must not inherit the academy paired-reset certificate")


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
