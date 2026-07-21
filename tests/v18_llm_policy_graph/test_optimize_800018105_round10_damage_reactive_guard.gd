extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")

const DECK_ID := 800018105
const REACTIVE_POKEMON_EFFECTS: Array[String] = [
	"0c65d1d9705ccf735d3780b072e3924d", # Team Rocket's Koffing
	"08e4abe39ce058b6724cf68c1e9828e4", # Zamazenta
]
const REACTIVE_TOOL_EFFECTS: Array[String] = [
	"76ed73e869ac742e97ea521f200a360e", # Lucky Helmet
	"1bc2bed91258ca0ecfb69e5ee8dc0c79", # Handheld Fan
]
const SPIKEMUTH_ENERGY_EFFECT := "f9db949f369ecead569fb8e3adc4eaee"
const BRAVERY_CHARM_EFFECT := "d1c2f018a644e662f2b6895fdfc29281"
const HEAVY_BATON_EFFECT := "770c741043025f241dbd81422cb8987d"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_check(int(profile.get("profile_version", 0)) >= 12, "round10 reactive guard requires profile version 12")
	_test_non_reactive_boundaries(profile)
	_test_reactive_sources_fail_closed(profile)
	_test_missing_effective_ko_proof_fails_closed(profile)
	if _failures.is_empty():
		print("V18CPG 800018105 round10 damage-reactive guard: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_non_reactive_boundaries(profile: Dictionary) -> void:
	_check(_has_certificate(profile, _observation()), "plain public Active must retain the exact 0-to-10 damage certificate")
	var charm := _observation()
	charm["opponent"]["active"]["tool"] = _card("CSV1C_118", BRAVERY_CHARM_EFFECT)
	_check(_has_certificate(profile, charm), "Bravery Charm may retain the certificate when effective-HP KO projection is explicitly false")
	var baton := _observation()
	baton["opponent"]["active"]["tool"] = _card("CSV7C_188", HEAVY_BATON_EFFECT)
	_check(_has_certificate(profile, baton), "Heavy Baton is KO-only and must not block an explicitly non-KO comparison")


func _test_reactive_sources_fail_closed(profile: Dictionary) -> void:
	for effect_id: String in REACTIVE_POKEMON_EFFECTS:
		var observation := _observation()
		observation["opponent"]["active"]["pokemon"] = _card("REACTIVE_POKEMON", effect_id)
		_check(not _has_certificate(profile, observation), "reactive Active Pokemon %s must block damage dominance" % effect_id)
	for effect_id: String in REACTIVE_TOOL_EFFECTS:
		var observation := _observation()
		observation["opponent"]["active"]["tool"] = _card("REACTIVE_TOOL", effect_id)
		_check(not _has_certificate(profile, observation), "reactive Tool %s must block damage dominance" % effect_id)
	var spikemuth := _observation()
	spikemuth["opponent"]["active"]["energy"] = [_card("CSV10C_221", SPIKEMUTH_ENERGY_EFFECT)]
	_check(not _has_certificate(profile, spikemuth), "Spikemuth Energy retaliation must block damage dominance")


func _test_missing_effective_ko_proof_fails_closed(profile: Dictionary) -> void:
	var frontier := _frontier()
	frontier[0]["action_ref"].erase("projected_knockout")
	_check(not _has_certificate_for_frontier(profile, _observation(), frontier), "preferred attack without projected_knockout must fail closed")
	frontier = _frontier()
	frontier[1]["action_ref"].erase("projected_knockout")
	_check(not _has_certificate_for_frontier(profile, _observation(), frontier), "Rule attack without projected_knockout must fail closed")


func _has_certificate(profile: Dictionary, observation: Dictionary) -> bool:
	return _has_certificate_for_frontier(profile, observation, _frontier())


func _has_certificate_for_frontier(profile: Dictionary, observation: Dictionary, frontier: Array) -> bool:
	var typed: Array[Dictionary] = []
	for raw_candidate: Variant in frontier:
		if raw_candidate is Dictionary:
			typed.append(raw_candidate as Dictionary)
	var annotated := CapabilityRegistryScript.new().annotate_frontier(typed, observation, _facts(), profile, {})
	if annotated.size() != 2:
		return false
	var certificate := CapabilityRegistryScript.new().verify_route_advantage(annotated[0], annotated[1], _facts(), profile)
	return str(certificate.get("certificate_kind", "")) == "public_same_attacker_damage_dominance"


func _frontier() -> Array:
	return [_attack_candidate(true, false), _attack_candidate(false, true)]


func _attack_candidate(preferred: bool, rule_floor: bool) -> Dictionary:
	return {
		"candidate_id": "candidate:ten" if preferred else "candidate:zero",
		"route_id": "route:attack_pressure",
		"action_kind": "attack",
		"action_ref": {
			"source": "slot:drifloon",
			"source_card": _card("CSV2C_060", ""),
			"attack_index": 0 if preferred else 1,
			"projected_damage": 10 if preferred else 0,
			"projected_knockout": false,
		},
		"checkpoint_after": "terminal",
		"engine_rule_floor_exact": rule_floor,
		"outcome": {"attack_ready": true, "estimated_damage": 10 if preferred else 0, "terminal": true},
	}


func _observation() -> Dictionary:
	return {
		"turn": {"number": 16, "current_player": 1, "viewer": 1, "deterministic_attack_window_open": true},
		"own": {
			"active": _slot("slot:drifloon", "CSV2C_060", "", [], {}),
			"bench": [],
			"prizes_remaining": 6,
			"deck_count": 20,
			"hand": [],
		},
		"opponent": {
			"active": _slot("slot:opponent", "CSV2C_105", "", [], {}),
			"bench": [],
			"prizes_remaining": 5,
		},
	}


func _slot(slot_id: String, uid: String, effect_id: String, energy: Array, tool: Dictionary) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": _card(uid, effect_id),
		"energy": energy.duplicate(true),
		"energy_count": energy.size(),
		"tool": tool.duplicate(true),
		"damage": 0,
		"remaining_hp": 160,
		"prize_count": 2,
		"ability_used": false,
	}


func _card(uid: String, effect_id: String) -> Dictionary:
	return {"uid": uid, "effect_id": effect_id}


func _facts() -> Dictionary:
	return {
		"attack": {"ready": true, "ko_available": false, "max_damage": 10},
		"prize": {"win_now": false, "current_swing": 0},
		"resources": {"prizes_remaining": 6},
		"turn": {"energy_available": true, "supporter_available": true},
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
