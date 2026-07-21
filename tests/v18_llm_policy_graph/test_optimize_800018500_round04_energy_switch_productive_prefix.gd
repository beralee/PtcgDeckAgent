extends SceneTree

## Round04 regression extracted from optimization21 seed 800018508 turn 10.
## Rule moves the fourth Grass from a Benched Ogerpon to an empty backup
## Toedscruel ex, then takes the already-secured knockout.  The transfer keeps
## Ogerpon's GGG reserve, creates one energized Bench lane, and raises the same
## Toedscruel ex attack from 200 to 240 without touching hidden information.

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018500
const TOEDSCRUEL_EX_UID := "CSV5C_010"
const OGERPON_UID := "CSV8C_028"
const IRON_HANDS_UID := "CSV6C_051"
const ENERGY_SWITCH_UID := "CSVH1aC_008"
const CERTIFICATE := "public_grass_redistribution_before_secured_ko"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_check(int(profile.get("profile_version", 0)) >= 5, "Round04 requires isolated profile version 5")
	_test_seed508_exact_productive_prefix(profile)
	_test_seed508_fail_closed_boundaries(profile)
	if _failures.is_empty():
		print("V18CPG 800018500 round04 Energy Switch productive prefix: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_seed508_exact_productive_prefix(profile: Dictionary) -> void:
	var built := _build_candidates(_seed508_observation(), _seed508_facts(), _seed508_actions(), profile)
	var prefix: Dictionary = built.get("prefix", {})
	var attack: Dictionary = built.get("attack", {})
	_check(not prefix.is_empty() and not attack.is_empty(), "seed508 fixture must expose exact Energy Switch and attack candidates")
	var advantage := CapabilityRegistryScript.new().verify_route_advantage(prefix, attack, _seed508_facts(), profile)
	_check(bool(advantage.get("verified", false)), "exact public Energy Switch must certify its productive same-turn KO prefix")
	_check(str(advantage.get("certificate_kind", "")) == CERTIFICATE, "prefix must expose the dedicated redistribution certificate")
	_check(int(advantage.get("prizes_floor", 0)) == 2, "Energy Switch must preserve the same two-prize KO floor")
	_check(str(advantage.get("energy_source_slot_id", "")) == "slot:ogerpon-bank", "certificate must bind the exact 4G Ogerpon donor")
	_check(str(advantage.get("energy_target_slot_id", "")) == "slot:backup-ex", "certificate must bind the exact empty backup Toedscruel ex")
	_check(int(advantage.get("projected_damage_after", 0)) == 240, "new energized Bench lane must raise public damage from 200 to 240")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var safety: Dictionary = strategy.call(
		"_validate_model_route_safety",
		str(attack.get("route_id", "")),
		built.get("pool", []),
		_seed508_facts(),
		str(attack.get("candidate_id", ""))
	)
	_check(not bool(safety.get("valid", true)), "terminal attack must not truncate the certified Energy Switch prefix")
	_check(str(safety.get("reason", "")) == "verified_rule_suffix_dominates_terminal_switch", "truncation must fail through the shared suffix safety reason")


func _test_seed508_fail_closed_boundaries(profile: Dictionary) -> void:
	var cases: Array[Dictionary] = []
	var donor_only_three := _seed508_observation()
	donor_only_three["own"]["bench"][0]["energy"].pop_back()
	donor_only_three["own"]["bench"][0]["energy_count"] = 3
	cases.append({"label": "donor has no fourth Grass", "observation": donor_only_three, "actions": _seed508_actions(), "rule_exact": true})
	var donor_special := _seed508_observation()
	donor_special["own"]["bench"][0]["energy"][3]["type"] = "Special Energy"
	cases.append({"label": "donor fourth Energy is not Basic Grass", "observation": donor_special, "actions": _seed508_actions(), "rule_exact": true})
	var backup_funded := _seed508_observation()
	backup_funded["own"]["bench"][1]["energy"] = [_grass_energy()]
	backup_funded["own"]["bench"][1]["energy_count"] = 1
	cases.append({"label": "backup lane is already energized", "observation": backup_funded, "actions": _seed508_actions(), "rule_exact": true})
	var active_short := _seed508_observation()
	active_short["own"]["active"]["energy"].pop_back()
	active_short["own"]["active"]["energy_count"] = 1
	cases.append({"label": "current attacker no longer has exact public cost", "observation": active_short, "actions": _seed508_actions(), "rule_exact": true})
	var duplicate_donor := _seed508_observation()
	duplicate_donor["own"]["bench"].append(_slot_ref("slot:other-bank", OGERPON_UID, 210, 2, 4))
	cases.append({"label": "donor interaction pair is ambiguous", "observation": duplicate_donor, "actions": _seed508_actions(), "rule_exact": true})
	var duplicate_backup := _seed508_observation()
	duplicate_backup["own"]["bench"].append(_slot_ref("slot:other-backup", TOEDSCRUEL_EX_UID, 270, 2, 0))
	cases.append({"label": "receiver interaction pair is ambiguous", "observation": duplicate_backup, "actions": _seed508_actions(), "rule_exact": true})
	var lost_ko := _seed508_actions()
	lost_ko[1]["projected_knockout"] = false
	lost_ko[1]["projected_damage"] = 0
	cases.append({"label": "original attack no longer knocks out", "observation": _seed508_observation(), "actions": lost_ko, "rule_exact": true})
	var wrong_source := _seed508_actions()
	wrong_source[1]["source"] = "slot:backup-ex"
	cases.append({"label": "attack source changes", "observation": _seed508_observation(), "actions": wrong_source, "rule_exact": true})
	var interactive_attack := _seed508_actions()
	interactive_attack[1]["requires_interaction"] = true
	cases.append({"label": "attack suffix has an unresolved interaction", "observation": _seed508_observation(), "actions": interactive_attack, "rule_exact": true})
	var wrong_target := _seed508_actions()
	wrong_target[1]["target"] = "slot:other-opponent"
	cases.append({"label": "attack target changes", "observation": _seed508_observation(), "actions": wrong_target, "rule_exact": true})
	cases.append({"label": "Energy Switch is not the exact Rule floor", "observation": _seed508_observation(), "actions": _seed508_actions(), "rule_exact": false})
	for invalid: Dictionary in cases:
		var built := _build_candidates(
			invalid.get("observation", {}),
			_seed508_facts(),
			invalid.get("actions", []),
			profile,
			bool(invalid.get("rule_exact", true))
		)
		var advantage := CapabilityRegistryScript.new().verify_route_advantage(
			built.get("prefix", {}),
			built.get("attack", {}),
			_seed508_facts(),
			profile
		)
		_check(not bool(advantage.get("verified", false)), "%s must fail closed" % str(invalid.get("label", "invalid prefix")))


func _build_candidates(
	observation: Dictionary,
	facts: Dictionary,
	actions: Array,
	profile: Dictionary,
	rule_exact: bool = true
) -> Dictionary:
	observation = observation.duplicate(true)
	observation["legal_actions"] = actions.duplicate(true)
	var scores := {"energy-switch": 5912.0, "secured-ko": 5830.4}
	var pool := RouteSearchScript.new().build_candidate_pool(observation, scores, {}, facts)
	for candidate: Dictionary in pool:
		candidate["engine_rule_floor_exact"] = rule_exact \
			and str(candidate.get("safe_prefix_action_id", "")) == "energy-switch"
	pool = CapabilityRegistryScript.new().annotate_frontier(pool, observation, facts, profile, {})
	var result := {"pool": pool, "prefix": {}, "attack": {}}
	for candidate: Dictionary in pool:
		if str(candidate.get("safe_prefix_action_id", "")) == "energy-switch":
			result["prefix"] = candidate
		elif str(candidate.get("safe_prefix_action_id", "")) == "secured-ko":
			result["attack"] = candidate
	return result


func _seed508_actions() -> Array:
	return [{
		"id": "energy-switch",
		"kind": "play_trainer",
		"card": {"uid": ENERGY_SWITCH_UID, "name": "Energy Switch", "type": "Item"},
		"requires_interaction": true,
	}, {
		"id": "secured-ko",
		"kind": "attack",
		"source": "slot:active-ex",
		"source_card": {"uid": TOEDSCRUEL_EX_UID, "name": "Toedscruel ex", "type": "Pokemon"},
		"target": "slot:opponent-active",
		"attack_index": 0,
		"projected_damage": 200,
		"projected_knockout": true,
		"requires_interaction": false,
	}]


func _seed508_observation() -> Dictionary:
	return {
		"turn": {"number": 10, "current_player": 1, "deterministic_attack_window_open": true, "quotas": {"energy_available": true}},
		"own": {
			"prizes_remaining": 4,
			"deck_count": 12,
			"hand_count": 1,
			"hand": [{"uid": ENERGY_SWITCH_UID, "name": "Energy Switch", "type": "Item"}],
			"active": _slot_ref("slot:active-ex", TOEDSCRUEL_EX_UID, 120, 2, 2),
			"bench": [
				_slot_ref("slot:ogerpon-bank", OGERPON_UID, 210, 2, 4),
				_slot_ref("slot:backup-ex", TOEDSCRUEL_EX_UID, 270, 2, 0),
				_slot_ref("slot:squawk", "CSV2C_105", 160, 2, 0),
				_slot_ref("slot:toedscruel", "CSV5C_009", 120, 1, 0),
				_slot_ref("slot:toedscool", "CSVSC_005", 60, 1, 0),
				_slot_ref("slot:ogerpon-one-a", OGERPON_UID, 210, 2, 1),
				_slot_ref("slot:ogerpon-one-b", OGERPON_UID, 210, 2, 1),
			],
		},
		"opponent": {
			"prizes_remaining": 6,
			"active": _slot_ref("slot:opponent-active", IRON_HANDS_UID, 30, 2, 3),
			"bench": [],
		},
		"legal_actions": _seed508_actions(),
		"visibility": {"deck_order_visible": false, "opponent_hand_contents": false, "own_prize_identities": false},
	}


func _seed508_facts() -> Dictionary:
	return {
		"attack": {"ready": true, "ko_available": true, "max_damage": 200},
		"board": {"opponent_active_remaining_hp": 30},
		"prize": {"current_swing": 2, "win_now": false},
		"resources": {"energy_on_board": 8, "prizes_remaining": 4, "hand_size": 1, "deck_low": false},
		"turn": {"energy_available": true},
	}


func _slot_ref(slot_id: String, uid: String, hp: int, prizes: int, grass_count: int) -> Dictionary:
	var energy: Array[Dictionary] = []
	for _index: int in grass_count:
		energy.append(_grass_energy())
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid, "type": "Pokemon"},
		"energy": energy,
		"energy_count": grass_count,
		"damage": 0,
		"remaining_hp": hp,
		"max_hp": hp,
		"prize_count": prizes,
		"ability_used": false,
	}


func _grass_energy() -> Dictionary:
	return {"uid": "CSVE1C_GRA", "name": "Grass Energy", "type": "Basic Energy", "energy_provides": "G", "energy_type": "G"}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
