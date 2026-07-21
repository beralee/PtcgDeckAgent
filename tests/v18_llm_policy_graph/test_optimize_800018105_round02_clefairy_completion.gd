extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018105
const PROVENANCE_SEED := 109
const PROVENANCE_TURN := 7
const PROVENANCE_OBSERVATION_HASH := "38afcedfdb3a305d5384ddceaeffd0926c10cdbd5c47f1be8564d0fd3c27d503"
const RULE_ID := "candidate:cf3736661b05655a5e67"
const COMPLETION_ID := "candidate:677e34f71a448e3d14f6"
const DUPLICATE_COMPLETION_ID := "candidate:98f4af8675b4602fff13"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_test_exact_seed109_takeover(profile)
	_test_negative_boundaries(profile)
	if _failures.is_empty():
		print("V18CPG 800018105 round02 Clefairy certificate boundary: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_exact_seed109_takeover(profile: Dictionary) -> void:
	var annotated := _annotated(profile, _observation(), _facts(), _frontier())
	var rule_attachment := _typed_attachment(annotated[0])
	var completion := _typed_attachment(annotated[1])
	_check(not bool(rule_attachment.get("completes_required_types", false)), "Rule D -> Kirlia must not complete a public attack cost")
	_check(str(completion.get("target_uid", "")) == "CSV10C_082", "completion must remain bound to Clefairy UID")
	_check(str(completion.get("target_slot_id", "")) == "slot:11", "completion must remain bound to the Active slot")
	_check(completion.get("required_symbols", []) == ["P", "C"], "Clefairy printed cost must remain [P,C]")
	_check(completion.get("missing_before", []) == ["C"], "one attached Psychic must leave only Colorless missing")
	_check(bool(completion.get("completes_required_types", false)), "Darkness must pay the missing Colorless unit")
	var registry := CapabilityRegistryScript.new()
	var certificate := registry.verify_route_advantage(annotated[1], annotated[0], _facts(), profile)
	_check(str(certificate.get("certificate_kind", "")) == "public_typed_attack_cost_completion", "exact public certificate changed")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var safety := strategy._validate_model_route_safety("route:energy_commit", annotated, _facts(), COMPLETION_ID)
	_check(str(safety.get("reason", "")) == "module_verified_advantage", "completion must pass the shared safety shield")
	_check(absf(float(safety.get("score_gap", 0.0)) - 178.584) < 0.001, "frozen Rule gap must remain 178.584")
	var upgrade := strategy._find_module_verified_upgrade(annotated, _facts())
	_check(upgrade.is_empty(), "full prize-exchange audit withdrew Clefairy's autonomous takeover")
	var opted_profile := profile.duplicate(true)
	for module_id: String in ["gardevoir_embrace", "damage_counter_control"]:
		opted_profile["module_parameters"][module_id]["autonomous_same_quota_completion_uids"] = ["CSV10C_082"]
	var opted_annotated := _annotated(opted_profile, _observation(), _facts(), _frontier())
	strategy.configure_profile(opted_profile)
	var opted_upgrade := strategy._find_module_verified_upgrade(opted_annotated, _facts())
	_check(str(opted_upgrade.get("candidate_id", "")) == COMPLETION_ID, "explicit opt-in must keep selecting the first exact Darkness instance")
	_check(str(opted_upgrade.get("candidate_id", "")) != DUPLICATE_COMPLETION_ID, "stable tie order must not drift to the duplicate Darkness instance")
	_check(str(opted_upgrade.get("verified_reason", "")) == "module_verified_advantage", "opted-in takeover reason changed")
	_check(str(opted_upgrade.get("verified_advantage", {}).get("certificate_kind", "")) == "public_typed_attack_cost_completion", "opted-in takeover must retain its certificate")
	_check(bool(strategy.call("_can_apply_initial_module_upgrade", opted_upgrade)), "the opted-in certificate must remain eligible before the first model request")


func _test_negative_boundaries(profile: Dictionary) -> void:
	var cases: Array[Dictionary] = []
	var bench_clefairy := _observation()
	bench_clefairy["own"]["active"] = _slot("slot:12", "CSV2C_053", [])
	bench_clefairy["own"]["bench"] = [
		_slot("slot:3", "CSV2C_054", []),
		_slot("slot:11", "CSV10C_082", [_energy("P")]),
	]
	cases.append({"label": "Clefairy is Benched", "observation": bench_clefairy, "facts": _facts(), "frontier": _frontier()})
	var wrong_uid := _observation()
	wrong_uid["own"]["active"]["pokemon"]["uid"] = "CSV2C_053"
	cases.append({"label": "Active UID changed", "observation": wrong_uid, "facts": _facts(), "frontier": _frontier()})
	var missing_slot := _frontier()
	missing_slot[1]["action_ref"]["target"] = "slot:missing"
	missing_slot[2]["action_ref"]["target"] = "slot:missing"
	cases.append({"label": "candidate slot is absent", "observation": _observation(), "facts": _facts(), "frontier": missing_slot})
	var missing_psychic := _observation()
	missing_psychic["own"]["active"]["energy"] = []
	cases.append({"label": "Psychic is still missing", "observation": missing_psychic, "facts": _facts(), "frontier": _frontier()})
	var locked := _observation()
	locked["turn"]["deterministic_attack_window_open"] = false
	cases.append({"label": "attack window is locked", "observation": locked, "facts": _facts(), "frontier": _frontier()})
	var mover_active := _observation()
	mover_active["own"]["active"]["pokemon"]["uid"] = "CSV8C_094"
	cases.append({"label": "Munkidori completion lacks explicit autonomous opt-in", "observation": mover_active, "facts": _facts(), "frontier": _frontier()})
	var ready_facts := _facts()
	ready_facts["attack"] = {"ready": true, "ko_available": true, "max_damage": 230}
	cases.append({"label": "safe KO already exists", "observation": _observation(), "facts": ready_facts, "frontier": _frontier()})
	var absent := _frontier()
	absent = [absent[0]]
	cases.append({"label": "exact completion candidate is absent", "observation": _observation(), "facts": _facts(), "frontier": absent})
	var rule_wins := _frontier()
	rule_wins[0]["outcome"] = {"win_now": true, "prizes_now": 2}
	cases.append({"label": "Rule already wins now", "observation": _observation(), "facts": _facts(), "frontier": rule_wins})
	for invalid: Dictionary in cases:
		var annotated := _annotated(
			profile,
			invalid.get("observation", {}),
			invalid.get("facts", {}),
			invalid.get("frontier", [])
		)
		var strategy := StrategyScript.new()
		strategy.configure_profile(profile)
		_check(
			strategy._find_module_verified_upgrade(annotated, invalid.get("facts", {})).is_empty(),
			"%s must block autonomous Clefairy completion" % str(invalid.get("label", "invalid"))
		)


func _annotated(
	profile: Dictionary,
	observation: Dictionary,
	facts: Dictionary,
	frontier: Array
) -> Array[Dictionary]:
	var typed_frontier: Array[Dictionary] = []
	for raw_candidate: Variant in frontier:
		if raw_candidate is Dictionary:
			typed_frontier.append(raw_candidate as Dictionary)
	return CapabilityRegistryScript.new().annotate_frontier(typed_frontier, observation, facts, profile, {})


func _frontier() -> Array[Dictionary]:
	return [
		_candidate(RULE_ID, "slot:3", 384.384, true),
		_candidate(COMPLETION_ID, "slot:11", 205.8, false),
		_candidate(DUPLICATE_COMPLETION_ID, "slot:11", 205.8, false),
	]


func _candidate(candidate_id: String, target: String, score: float, rule_floor: bool) -> Dictionary:
	return {
		"candidate_id": candidate_id,
		"route_id": "route:energy_commit",
		"action_kind": "attach_energy",
		"action_ref": {"target": target, "card": _energy("D")},
		"base_score": score,
		"local_score": score,
		"engine_rule_floor_exact": rule_floor,
		"outcome": {"future_flexibility": 0.3, "resource_commitment": 0.7},
	}


func _observation() -> Dictionary:
	return {
		"observation_hash": PROVENANCE_OBSERVATION_HASH,
		"turn": {
			"number": PROVENANCE_TURN,
			"current_player": 0,
			"viewer": 0,
			"first_player": 0,
			"deterministic_attack_window_open": true,
		},
		"own": {
			"active": _slot("slot:11", "CSV10C_082", [_energy("P")]),
			"bench": [_slot("slot:3", "CSV2C_054", []), _slot("slot:1", "CSV2C_053", [])],
			"prizes_remaining": 6,
			"deck_count": 27,
			"hand": [_energy("D"), _energy("D")],
		},
		"opponent": {
			"active": {"slot_id": "slot:57", "pokemon": {"uid": "CSV6C_051"}, "remaining_hp": 230, "prize_count": 2},
			"bench": [{}, {}, {}, {}, {}],
			"prizes_remaining": 4,
		},
	}


func _facts() -> Dictionary:
	return {
		"attack": {"ready": false, "ko_available": false, "max_damage": 0},
		"resources": {"prizes_remaining": 6},
		"turn": {"energy_available": true, "supporter_available": true},
	}


func _slot(slot_id: String, uid: String, energy: Array) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid},
		"energy": energy.duplicate(true),
		"energy_count": energy.size(),
		"remaining_hp": 190,
	}


func _energy(symbol: String) -> Dictionary:
	return {
		"uid": "CSVE1C_%s" % ("PSY" if symbol == "P" else "DAR"),
		"type": "Basic Energy",
		"energy_provides": symbol,
	}


func _typed_attachment(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {})
	for module_id: String in ["gardevoir_embrace", "damage_counter_control"]:
		var attachment: Variant = annotations.get(module_id, {}).get("typed_attachment", {})
		if attachment is Dictionary and not (attachment as Dictionary).is_empty():
			return attachment as Dictionary
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
