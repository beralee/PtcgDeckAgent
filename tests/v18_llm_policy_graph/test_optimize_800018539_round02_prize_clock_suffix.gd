extends SceneTree

const FireToolboxScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGEthanHoOhFireToolbox.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RuleValidatorScript = preload("res://scripts/engine/RuleValidator.gd")

const DECK_ID := 800018539
const HO_OH_UID := "CSV10C_035"
const HO_OH_EFFECT_ID := "23d228f7053a7314a2ee5f651f38a3cb"
const IRON_HANDS_UID := "CSV6C_051"
const IRON_HANDS_EFFECT_ID := "e9f0c124fc2e352af2408a7e61862b95"
const FIRE_UID := "CSVE1C_FIR"
const LUMINOUS_UID := "CSV1C_127"
const LEGACY_UID := "CSV8C_207"
const LIGHTNING_UID := "CSVE1C_LIG"

var _profile: Dictionary = {}
var _module: RefCounted
var _failures: Array[String] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_module = FireToolboxScript.new()
	_module.configure("fire_toolbox")
	_check(int(_profile.get("profile_version", 0)) >= 5, "round03 generalized profile must be active")
	_test_generalized_knockout_suffix()
	_test_generalized_pressure_suffix()
	_test_generalized_energy_providers()
	_test_captured_production_observations()
	_test_real_ho_oh_energy_legality()
	_test_negative_boundaries()
	_test_profile_isolation()
	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty():
		print("V18CPG 800018539 round03 generalized public retreat-attack suffix: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_generalized_knockout_suffix() -> void:
	var observation := _seed543_observation()
	observation["own"]["active"]["slot_id"] = "slot:active-general"
	observation["own"]["active"]["retreat_cost"] = 1
	observation["own"]["active"]["energy"] = [_energy(LIGHTNING_UID)]
	observation["own"]["prizes_remaining"] = 2
	observation["own"]["bench"][0]["slot_id"] = "slot:rule-91"
	observation["own"]["bench"][4]["slot_id"] = "slot:ho-oh-42"
	observation["own"]["bench"][4]["remaining_hp"] = 200
	observation["own"]["bench"][4]["damage"] = 30
	observation["own"]["bench"][4]["energy"] = [
		_energy(FIRE_UID), _energy(FIRE_UID), _energy(FIRE_UID), _energy(FIRE_UID),
	]
	observation["opponent"]["active"]["remaining_hp"] = 150
	observation["opponent"]["active"]["damage"] = 80
	observation["opponent"]["active"]["max_hp"] = 230
	var frontier := _annotate(_frontier("slot:rule-91", "slot:ho-oh-42"), observation)
	var rule_top: Dictionary = frontier[0]
	var selected: Dictionary = frontier[1]
	var certificate := _certificate(selected)
	var advantage: Dictionary = _module.verify_route_advantage(selected, rule_top, _facts(), _profile)
	_check(bool(certificate.get("verified", false)), "a live powered Ho-Oh in an arbitrary Bench slot must bind")
	_check(str(certificate.get("invariant_id", "")) == "ethan_ho_oh_public_retreat_attack_v1" \
		and not JSON.stringify(certificate).contains("seed543") \
		and not JSON.stringify(certificate).contains("slot:6"), \
		"the generalized certificate must not dispatch by replay or historical slot identity")
	_check(int(certificate.get("projected_damage", 0)) == 150 \
		and bool(certificate.get("projected_knockout", false)) \
		and int(certificate.get("prizes_now", 0)) == 2 \
		and bool(certificate.get("win_now", false)) \
		and int(certificate.get("target_damage", -1)) == 30 \
		and int(certificate.get("fire_units", 0)) == 4 \
		and int(certificate.get("retreat_cost", -1)) == 1 \
		and int(certificate.get("retreat_energy_count", -1)) == 1 \
		and bool(certificate.get("suffix_preserved", false)), \
		"the public invariant must recompute capped damage, two Prizes, target damage and attack suffix")
	_check(bool(advantage.get("verified", false)) \
		and str(advantage.get("certificate_kind", "")) == "public_fire_same_turn_retreat_attack_suffix" \
		and str(advantage.get("evidence_kind", "")) == "public_same_turn_bound_attack_suffix" \
		and bool(advantage.get("suffix_preserved", false)), \
		"the arbitrary-slot powered Ho-Oh must strictly beat the same-quota non-attacking Rule pivot")


func _test_generalized_pressure_suffix() -> void:
	var observation := _seed540_observation()
	observation["own"]["active"]["slot_id"] = "slot:active-pressure"
	observation["own"]["active"]["retreat_cost"] = 2
	observation["own"]["active"]["energy"] = [_energy(FIRE_UID), _energy(FIRE_UID)]
	observation["own"]["prizes_remaining"] = 4
	observation["opponent"]["prizes_remaining"] = 3
	observation["own"]["bench"][0]["slot_id"] = "slot:rule-33"
	observation["own"]["bench"][2]["slot_id"] = "slot:ho-oh-88"
	observation["own"]["bench"][2]["remaining_hp"] = 160
	observation["own"]["bench"][2]["damage"] = 70
	observation["own"]["bench"][2]["energy"] = [
		_energy(FIRE_UID), _energy(FIRE_UID), _energy(FIRE_UID),
		_energy(LEGACY_UID), _energy(LUMINOUS_UID),
	]
	observation["opponent"]["active"]["remaining_hp"] = 210
	observation["opponent"]["active"]["damage"] = 20
	observation["opponent"]["active"]["max_hp"] = 230
	observation["stadium"] = _card(
		"CSV8C_203", "4e16157bfa88a41e823d058a732df8e0", "Stadium"
	)
	var frontier := _annotate(_frontier("slot:rule-33", "slot:ho-oh-88"), observation)
	var certificate := _certificate(frontier[1])
	var advantage: Dictionary = _module.verify_route_advantage(frontier[1], frontier[0], _facts(), _profile)
	_check(bool(certificate.get("verified", false)) \
		and int(certificate.get("projected_damage", 0)) == 160 \
		and not bool(certificate.get("projected_knockout", true)) \
		and int(certificate.get("prizes_now", -1)) == 0 \
		and int(certificate.get("target_damage", -1)) == 70 \
		and int(certificate.get("fire_units", 0)) == 4 \
		and int(certificate.get("retreat_cost", -1)) == 2 \
		and int(certificate.get("retreat_energy_count", -1)) == 2, \
		"different damage, energy composition, Bench slots, prize clocks and opponent HP must retain a proven 160-damage pressure suffix")
	_check(bool(advantage.get("verified", false)), \
		"the generalized pressure suffix must beat a publicly non-attacking Armarouge Rule pivot")


func _test_generalized_energy_providers() -> void:
	var single_luminous := _seed543_observation()
	single_luminous["own"]["bench"][4]["energy"] = [
		_energy(FIRE_UID), _energy(FIRE_UID), _energy(FIRE_UID), _energy(LUMINOUS_UID),
	]
	var luminous_frontier := _annotate(
		_frontier("slot:squawk", "slot:powered-ho-oh"), single_luminous
	)
	_check(bool(_certificate(luminous_frontier[1]).get("verified", false)) \
		and int(_certificate(luminous_frontier[1]).get("fire_units", 0)) == 4, \
		"one Luminous Energy as the only Special Energy must generically pay the fourth Fire unit")

	var over_energy := _seed543_observation()
	over_energy["own"]["bench"][4]["energy"] = [
		_energy(FIRE_UID), _energy(FIRE_UID), _energy(FIRE_UID),
		_energy(FIRE_UID), _energy(FIRE_UID),
	]
	var over_frontier := _annotate(_frontier("slot:squawk", "slot:powered-ho-oh"), over_energy)
	_check(bool(_certificate(over_frontier[1]).get("verified", false)) \
		and int(_certificate(over_frontier[1]).get("fire_units", 0)) == 5, \
		"an over-energized live Ho-Oh must remain attack-ready without exact energy-count matching")


func _test_captured_production_observations() -> void:
	# Public state shapes captured from verified-local seed 800018540 turn 28 and
	# seed 800018543 turn 15. Identity is asserted through typed card/energy/
	# legality facts; runtime authority never reads seed, turn, slot, or hash.
	var durant_active := _seed540_observation()
	durant_active["own"]["active"]["retreat_cost"] = 2
	durant_active["own"]["active"]["energy"] = []
	var durant_frontier := _annotate(
		_frontier("slot:armarouge", "slot:powered-ho-oh"), durant_active
	)
	var durant_certificate := _certificate(durant_frontier[1])
	_check(bool(durant_certificate.get("verified", false)) \
		and str(durant_certificate.get("retreat_payment_proof", "")) \
			== "public_basic_plus_live_latias_skyline" \
		and bool(_module.verify_route_advantage(
			durant_frontier[1], durant_frontier[0], _facts(), _profile
		).get("verified", false)), \
		"captured production Durant Active must recognize live Latias Skyline as the effective zero-retreat proof")

	var latias_active := _seed543_observation()
	latias_active["own"]["active"]["retreat_cost"] = 1
	latias_active["own"]["active"]["energy"] = []
	var latias_frontier := _annotate(
		_frontier("slot:squawk", "slot:powered-ho-oh"), latias_active
	)
	var latias_certificate := _certificate(latias_frontier[1])
	_check(bool(latias_certificate.get("verified", false)) \
		and str(latias_certificate.get("retreat_payment_proof", "")) \
			== "public_basic_plus_live_latias_skyline" \
		and bool(_module.verify_route_advantage(
			latias_frontier[1], latias_frontier[0], _facts(), _profile
		).get("verified", false)), \
		"captured production Latias Active must prove its own Skyline free-retreat suffix")


func _test_real_ho_oh_energy_legality() -> void:
	var processor := EffectProcessor.new()
	var validator := RuleValidatorScript.new()
	var ho_oh_data := _real_card_data(HO_OH_UID)
	var state := _state()
	var three_fire_legacy := _slot_instance(ho_oh_data, 0)
	for uid: String in [FIRE_UID, FIRE_UID, FIRE_UID, LUMINOUS_UID, LUMINOUS_UID, LEGACY_UID]:
		three_fire_legacy.attached_energy.append(_real_card_instance(uid, 0))
	state.players[0].active_pokemon = three_fire_legacy
	state.players[1].active_pokemon = _slot_instance(_real_card_data(IRON_HANDS_UID), 1)
	_check(validator.can_use_attack(state, 0, 0, processor), \
		"real RuleValidator must prove three basic Fire plus Legacy pays Ho-Oh's RRRR cost")

	var only_three_fire := _slot_instance(ho_oh_data, 0)
	for uid: String in [FIRE_UID, FIRE_UID, FIRE_UID, LUMINOUS_UID, LUMINOUS_UID]:
		only_three_fire.attached_energy.append(_real_card_instance(uid, 0))
	state.players[0].active_pokemon = only_three_fire
	_check(not validator.can_use_attack(state, 0, 0, processor), \
		"two mutually suppressed Luminous Energy must not turn three basic Fire into RRRR")


func _test_negative_boundaries() -> void:
	var cases: Array[Dictionary] = []
	var short_fire := _seed543_observation()
	short_fire["own"]["bench"][4]["energy"] = [
		_energy(FIRE_UID), _energy(FIRE_UID), _energy(FIRE_UID),
		_energy(LUMINOUS_UID), _energy(LUMINOUS_UID),
	]
	cases.append({"label": "one typed Fire short", "observation": short_fire})
	var suppressed_luminous := _seed543_observation()
	suppressed_luminous["own"]["bench"][4]["energy"] = [
		_energy(FIRE_UID), _energy(FIRE_UID), _energy(FIRE_UID), _energy(LUMINOUS_UID),
		_card("OTHER_SPECIAL", "", "Special Energy"),
	]
	cases.append({"label": "Luminous suppressed by another Special Energy", "observation": suppressed_luminous})
	var unknown_target_energy := _seed543_observation()
	unknown_target_energy["own"]["bench"][4]["energy"] = [
		_energy(FIRE_UID), _energy(FIRE_UID), _energy(FIRE_UID), _energy(FIRE_UID),
		_card("UNKNOWN_SPECIAL", "unknown-target-effect", "Special Energy"),
	]
	cases.append({"label": "unknown Ho-Oh Energy semantics", "observation": unknown_target_energy})
	var forged_fire_effect := _seed543_observation()
	forged_fire_effect["own"]["bench"][4]["energy"] = [
		_energy(FIRE_UID), _energy(FIRE_UID), _energy(FIRE_UID),
		_card(FIRE_UID, "wrong-fire-effect", "Basic Energy").merged({"energy_provides": "R"}),
	]
	cases.append({"label": "mismatched Fire Energy effect identity", "observation": forged_fire_effect})
	var closed_window := _seed543_observation()
	closed_window["turn"]["deterministic_attack_window_open"] = false
	cases.append({"label": "attack window closed", "observation": closed_window})
	var spent_retreat := _seed543_observation()
	spent_retreat["turn"]["quotas"]["retreat_available"] = false
	cases.append({"label": "retreat quota unavailable", "observation": spent_retreat})
	var unpaid_retreat := _seed543_observation()
	unpaid_retreat["own"]["active"]["pokemon"] = _pokemon(
		"CSV1C_028", "4f4c17fe9f3429419f9e344fbecb140d", "Stage 1"
	)
	unpaid_retreat["own"]["active"]["retreat_cost"] = 2
	unpaid_retreat["own"]["active"]["energy"] = [_energy(LIGHTNING_UID)]
	cases.append({"label": "retreat cost not payable", "observation": unpaid_retreat})
	var dead_skyline := _seed540_observation()
	dead_skyline["own"]["active"]["retreat_cost"] = 2
	dead_skyline["own"]["active"]["energy"] = []
	dead_skyline["own"]["bench"][4]["remaining_hp"] = 0
	dead_skyline["own"]["bench"][4]["damage"] = 210
	cases.append({"label": "knocked-out Skyline provider", "observation": dead_skyline})
	var dead_target := _seed543_observation()
	dead_target["own"]["bench"][4]["remaining_hp"] = 0
	dead_target["own"]["bench"][4]["damage"] = 230
	cases.append({"label": "Ho-Oh target knocked out", "observation": dead_target})
	var inconsistent_target := _seed543_observation()
	inconsistent_target["own"]["bench"][4]["damage"] = 10
	cases.append({"label": "Ho-Oh public HP inconsistent", "observation": inconsistent_target})
	var tooled_target := _seed543_observation()
	tooled_target["own"]["bench"][4]["tool"] = _card("UNKNOWN_TOOL", "", "Tool")
	cases.append({"label": "unknown Ho-Oh tool mutation", "observation": tooled_target})
	var dead_opponent := _seed543_observation()
	dead_opponent["opponent"]["active"]["remaining_hp"] = 0
	cases.append({"label": "opponent Active already knocked out", "observation": dead_opponent})
	var reactive_tool := _seed543_observation()
	reactive_tool["opponent"]["active"]["tool"] = {
		"uid": "PUBLIC_LUCKY_HELMET",
		"effect_id": "76ed73e869ac742e97ea521f200a360e",
	}
	cases.append({"label": "public reaction tool", "observation": reactive_tool})
	var unknown_tool := _seed543_observation()
	unknown_tool["opponent"]["active"]["tool"] = _card("UNKNOWN_TOOL", "", "Tool")
	cases.append({"label": "unknown opponent Tool semantics", "observation": unknown_tool})
	var unknown_energy := _seed543_observation()
	unknown_energy["opponent"]["active"]["energy"].append(
		_card("UNKNOWN_SPECIAL", "unknown-effect", "Special Energy")
	)
	cases.append({"label": "unknown opponent Energy semantics", "observation": unknown_energy})
	var unknown_opponent := _seed543_observation()
	unknown_opponent["opponent"]["active"]["pokemon"] = _pokemon(
		"UNKNOWN_OPPONENT", "unknown-opponent-effect"
	)
	cases.append({"label": "unproven opponent damage semantics", "observation": unknown_opponent})
	var protected_opponent := _seed543_observation()
	protected_opponent["opponent"]["active"]["pokemon"]["effect_id"] = \
		"896c85e6588f5e35909fd0969201be21"
	cases.append({"label": "public protection effect", "observation": protected_opponent})
	var reactive_stadium := _seed543_observation()
	reactive_stadium["stadium"] = _card(
		"PUBLIC_REACTIVE_STADIUM", "0c65d1d9705ccf735d3780b072e3924d", "Stadium"
	)
	cases.append({"label": "public reactive Stadium", "observation": reactive_stadium})
	for invalid: Dictionary in cases:
		var frontier := _annotate(
			_frontier("slot:squawk", "slot:powered-ho-oh"),
			invalid.get("observation", {})
		)
		_check(not bool(_certificate(frontier[1]).get("verified", false)), \
			"%s must fail closed" % str(invalid.get("label", "invalid")))

	var observation := _seed543_observation()
	var candidate_cases: Array[Dictionary] = []
	var no_checkpoint := _frontier("slot:squawk", "slot:powered-ho-oh")
	no_checkpoint[1].erase("checkpoint_after")
	candidate_cases.append({"label": "missing action checkpoint", "frontier": no_checkpoint})
	var wrong_reservation := _frontier("slot:squawk", "slot:powered-ho-oh")
	wrong_reservation[1]["reservations"][0]["count"] = 2
	candidate_cases.append({"label": "non-exact retreat reservation", "frontier": wrong_reservation})
	var unbound_prefix := _frontier("slot:squawk", "slot:powered-ho-oh")
	unbound_prefix[1]["safe_prefix_action_id"] = "action:generic"
	candidate_cases.append({"label": "unbound retreat prefix", "frontier": unbound_prefix})
	for invalid: Dictionary in candidate_cases:
		var frontier := _annotate(invalid.get("frontier", []), observation)
		_check(not bool(_certificate(frontier[1]).get("verified", false)), \
			"%s must fail closed" % str(invalid.get("label", "invalid candidate")))

	var already_attacking := _facts()
	already_attacking["attack"]["ready"] = true
	var attack_ready_frontier := _annotate_with_facts(
		_frontier("slot:squawk", "slot:powered-ho-oh"), observation, already_attacking
	)
	_check(not bool(_certificate(attack_ready_frontier[1]).get("verified", false)), \
		"a current Active that already attacks must not mint pivot authority")

	var not_rule_frontier := _frontier("slot:squawk", "slot:powered-ho-oh")
	not_rule_frontier[0].erase("engine_rule_floor_exact")
	var annotated := _annotate(not_rule_frontier, observation)
	_check(not bool(_module.verify_route_advantage(
		annotated[1], annotated[0], _facts(), _profile
	).get("verified", false)), "an unbound competing pivot must not mint authority")

	var powered_rule_observation := _seed543_observation()
	powered_rule_observation["own"]["bench"][0]["energy"] = [_energy(LIGHTNING_UID)]
	var powered_rule := _annotate(
		_frontier("slot:squawk", "slot:powered-ho-oh"), powered_rule_observation
	)
	_check(not bool(_module.verify_route_advantage(
		powered_rule[1], powered_rule[0], _facts(), _profile
	).get("verified", false)), "a Rule target at its public printed energy floor must not be assumed unable to attack")

	var unknown_rule_observation := _seed543_observation()
	unknown_rule_observation["own"]["bench"][0]["pokemon"] = _pokemon("UNKNOWN_RULE_TARGET", "")
	var unknown_rule := _annotate(
		_frontier("slot:squawk", "slot:powered-ho-oh"), unknown_rule_observation
	)
	_check(not bool(_module.verify_route_advantage(
		unknown_rule[1], unknown_rule[0], _facts(), _profile
	).get("verified", false)), "an unknown Rule target printed cost must fail closed")

	var quota_mismatch := _annotate(
		_frontier("slot:squawk", "slot:powered-ho-oh"), observation
	)
	quota_mismatch[0]["reservations"][0]["count"] = 2
	_check(not bool(_module.verify_route_advantage(
		quota_mismatch[1], quota_mismatch[0], _facts(), _profile
	).get("verified", false)), "different retreat quota contracts must not be compared as same quota")

	var checkpoint_mismatch := _annotate(
		_frontier("slot:squawk", "slot:powered-ho-oh"), observation
	)
	checkpoint_mismatch[0]["checkpoint_after"] = "interaction_resolved"
	_check(not bool(_module.verify_route_advantage(
		checkpoint_mismatch[1], checkpoint_mismatch[0], _facts(), _profile
	).get("verified", false)), "different post-action checkpoints must fail closed")

	var two_powered_ho_oh := _seed543_observation()
	two_powered_ho_oh["own"]["bench"][0] = _slot(
		"slot:rule-ho-oh", HO_OH_UID, HO_OH_EFFECT_ID, 230, 0, 2
	)
	two_powered_ho_oh["own"]["bench"][0]["energy"] = [
		_energy(FIRE_UID), _energy(FIRE_UID), _energy(FIRE_UID), _energy(FIRE_UID),
	]
	var both_attack := _annotate(
		_frontier("slot:rule-ho-oh", "slot:powered-ho-oh"), two_powered_ho_oh
	)
	_check(bool(_certificate(both_attack[0]).get("verified", false)) \
		and not bool(_module.verify_route_advantage(
			both_attack[1], both_attack[0], _facts(), _profile
		).get("verified", false)), \
		"a Rule pivot with its own verified attack suffix must not be overridden")


func _test_profile_isolation() -> void:
	var parameters: Dictionary = _profile.get("module_parameters", {}).get("fire_toolbox", {})
	_check(parameters.has("same_turn_retreat_attack_invariant") \
		and not parameters.has("same_turn_retreat_attack_suffixes") \
		and not JSON.stringify(parameters).contains("seed543") \
		and not JSON.stringify(parameters).contains("seed540"), \
		"the profile must contain one generalized invariant and no replay snapshot table")
	var other_profile := ProfileCatalogScript.get_profile_for_deck(800018543)
	var frontier: Array[Dictionary] = _module.annotate_frontier_v2(
		_frontier("slot:squawk", "slot:powered-ho-oh"),
		_seed543_observation(),
		_facts(),
		other_profile,
		{}
	)
	_check(_certificate(frontier[1]).is_empty(), "another deck profile must not inherit Ho-Oh's generalized certificate")


func _frontier(rule_target: String, selected_target: String) -> Array[Dictionary]:
	return [
		{
			"candidate_id": "candidate:rule-pivot",
			"safe_prefix_action_id": "action:retreat:rule-pivot",
			"route_id": "route:pivot",
			"action_kind": "retreat",
			"action_ref": {"kind": "retreat", "target": rule_target},
			"checkpoint_after": "action_resolved",
			"reservations": [{
				"resource": "quota:retreat_or_switch", "count": 1,
				"available": 1, "until": "action_resolved",
			}],
			"base_score": 3238.4,
			"local_score": 3238.4,
			"engine_rule_floor_exact": true,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
		{
			"candidate_id": "candidate:ho-oh-pivot",
			"safe_prefix_action_id": "action:retreat:ho-oh-pivot",
			"route_id": "route:pivot",
			"action_kind": "retreat",
			"action_ref": {"kind": "retreat", "target": selected_target},
			"checkpoint_after": "action_resolved",
			"reservations": [{
				"resource": "quota:retreat_or_switch", "count": 1,
				"available": 1, "until": "action_resolved",
			}],
			"base_score": 3238.4,
			"local_score": 3238.4,
			"outcome": {"win_now": false, "prizes_now": 0},
		},
	]


func _annotate(frontier: Array[Dictionary], observation: Dictionary) -> Array[Dictionary]:
	return _annotate_with_facts(frontier, observation, _facts())


func _annotate_with_facts(
	frontier: Array[Dictionary], observation: Dictionary, facts: Dictionary
) -> Array[Dictionary]:
	return CapabilityRegistryScript.new().annotate_frontier(
		frontier, observation, facts, _profile, {}
	)


func _seed543_observation() -> Dictionary:
	var powered := _slot("slot:powered-ho-oh", HO_OH_UID, HO_OH_EFFECT_ID, 230, 0, 2)
	powered["energy"] = [
		_energy(FIRE_UID), _energy(LUMINOUS_UID), _energy(FIRE_UID),
		_energy(LUMINOUS_UID), _energy(FIRE_UID), _energy(LEGACY_UID),
	]
	var iron_hands := _opponent("slot:iron-hands", 70, 160, 2, [_energy(LIGHTNING_UID)])
	iron_hands["tool"] = _card("CSV7C_185", "0b4cc131a19862f92acf71494f29a0ed", "Tool")
	return {
		"turn": {
			"deterministic_attack_window_open": true,
			"quotas": {"retreat_available": true},
		},
		"own": {
			"active": _slot("slot:latias", "CSV9C_078", "f8c2715403e3f4ea9783c46be2de832b", 210, 0, 2),
			"bench": [
				_slot("slot:squawk", "CSV2C_105", "1b951205e53e179bde0905c4a194d9ee", 160, 0, 2),
				_slot("slot:armarouge-a", "CSV1C_028", "4f4c17fe9f3429419f9e344fbecb140d", 130, 0, 1),
				_slot("slot:armarouge-b", "CSV1C_028", "4f4c17fe9f3429419f9e344fbecb140d", 130, 0, 1),
				_slot("slot:empty-ho-oh", HO_OH_UID, HO_OH_EFFECT_ID, 230, 0, 2),
				powered,
			],
			"hand": [], "discard": [], "deck_count": 20, "prizes_remaining": 6,
		},
		"opponent": {
			"active": iron_hands,
			"bench": [], "prizes_remaining": 6,
		},
		"stadium": {},
	}


func _seed540_observation() -> Dictionary:
	var powered := _slot("slot:powered-ho-oh", HO_OH_UID, HO_OH_EFFECT_ID, 230, 0, 2)
	powered["energy"] = [
		_energy(LUMINOUS_UID), _energy(LUMINOUS_UID),
		_energy(FIRE_UID), _energy(FIRE_UID), _energy(FIRE_UID), _energy(FIRE_UID),
	]
	return {
		"turn": {
			"deterministic_attack_window_open": true,
			"quotas": {"retreat_available": true},
		},
		"own": {
			"active": _slot("slot:durant", "CSV9C_006", "3a842d03df3719f7c72c2c0b48d7fd7d", 20, 170, 2),
			"bench": [
				_slot("slot:armarouge", "CSV1C_028", "4f4c17fe9f3429419f9e344fbecb140d", 130, 0, 1),
				_slot("slot:clefairy", "CSV10C_082", "24f6629cb78fa8e4a940f49f67736afa", 190, 0, 2),
				powered,
				_slot("slot:charcadet", "CSV9C_033", "", 70, 0, 1),
				_slot("slot:latias", "CSV9C_078", "f8c2715403e3f4ea9783c46be2de832b", 40, 170, 2),
			],
			"hand": [], "discard": [], "deck_count": 12, "prizes_remaining": 6,
		},
		"opponent": {
			"active": _opponent("slot:iron-hands", 230, 0, 2, [
				_energy(LIGHTNING_UID), _energy(LIGHTNING_UID),
			]),
			"bench": [], "prizes_remaining": 1,
		},
		"stadium": _card("CSV8C_203", "4e16157bfa88a41e823d058a732df8e0", "Stadium"),
	}


func _facts() -> Dictionary:
	return {
		"attack": {"ready": false, "ko_available": false, "max_damage": 0},
		"turn": {"energy_available": false, "supporter_available": false},
		"resources": {"deck_low": false, "deck_critical": false},
		"prize": {"win_now": false},
	}


func _slot(
	slot_id: String,
	uid: String,
	effect_id: String,
	remaining_hp: int,
	damage: int,
	prize_count: int
) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": _pokemon(uid, effect_id),
		"energy": [],
		"tool": {},
		"remaining_hp": remaining_hp,
		"max_hp": remaining_hp + damage,
		"damage": damage,
		"prize_count": prize_count,
		"ability_used": false,
		"retreat_cost": 0,
	}


func _opponent(slot_id: String, hp: int, damage: int, prizes: int, energy: Array) -> Dictionary:
	var result := _slot(slot_id, IRON_HANDS_UID, IRON_HANDS_EFFECT_ID, hp, damage, prizes)
	result["energy"] = energy
	return result


func _pokemon(uid: String, effect_id: String, stage: String = "Basic") -> Dictionary:
	return {"uid": uid, "effect_id": effect_id, "type": "Pokemon", "stage": stage}


func _card(uid: String, effect_id: String, type_name: String) -> Dictionary:
	return {"uid": uid, "effect_id": effect_id, "type": type_name}


func _energy(uid: String) -> Dictionary:
	match uid:
		FIRE_UID:
			return _card(uid, "22db5405bf0cce61a00aa8082cdd1e65", "Basic Energy").merged({"energy_provides": "R"})
		LUMINOUS_UID:
			return _card(uid, "540ee48bb93584e4bfe3d7f5d0ee0efc", "Special Energy")
		LEGACY_UID:
			return _card(uid, "6f31b7241a181631016466e561f148f3", "Special Energy")
		LIGHTNING_UID:
			return _card(uid, "45550fd10011f6ade7eef16ba88788cf", "Basic Energy").merged({"energy_provides": "L"})
	return _card(uid, "", "Energy")


func _certificate(candidate: Dictionary) -> Dictionary:
	var annotation: Dictionary = candidate.get("module_annotations", {}).get("fire_toolbox", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	return annotation.get("same_turn_retreat_attack_suffix", {}) \
		if annotation.get("same_turn_retreat_attack_suffix", {}) is Dictionary else {}


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 15
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for index: int in 2:
		var player := PlayerState.new()
		player.player_index = index
		state.players.append(player)
	return state


func _real_card_data(uid: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/cards/%s.json" % uid
	))
	_check(parsed is Dictionary, "real card %s must load" % uid)
	return CardData.from_dict(parsed as Dictionary) if parsed is Dictionary else CardData.new()


func _real_card_instance(uid: String, owner: int) -> CardInstance:
	return CardInstance.create(_real_card_data(uid), owner)


func _slot_instance(data: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner))
	return slot


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
