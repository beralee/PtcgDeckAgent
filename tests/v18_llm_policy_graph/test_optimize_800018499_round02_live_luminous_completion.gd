extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategicShapeScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGStrategicShapeModule.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018499
const DRAGAPULT_UID := "CSV8C_159"
const DREEPY_UID := "CSV8C_157"
const LUMINOUS_UID := "CSV1C_127"
const LUMINOUS_EFFECT_ID := "540ee48bb93584e4bfe3d7f5d0ee0efc"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	var stage2: Dictionary = (profile.get("module_parameters", {}) as Dictionary).get(
		"stage2_chain",
		{}
	)
	_check(
		LUMINOUS_UID in stage2.get("conditional_any_type_energy_uids", []),
		"production pure-Dragapult profile must explicitly opt Luminous Energy into conditional ANY typing"
	)

	var module = StrategicShapeScript.new()
	module.configure("stage2_chain")
	var facts := _facts()

	var live := module.annotate_frontier_v2(
		_frontier(),
		_observation([_basic_energy("P")], _luminous_energy(), true, DRAGAPULT_UID),
		facts,
		profile,
		{}
	)
	var live_attachment := _typed_attachment(live[1])
	var live_stage2 := _stage2_annotation(live[1])
	var live_certificate: Dictionary = module.verify_route_advantage(
		live[1],
		live[0],
		facts,
		profile
	)
	_check(
		str(live_attachment.get("energy_symbol", "")) == "ANY"
			and live_attachment.get("missing_before", []) == ["R"]
			and (live_attachment.get("missing_after", []) as Array).is_empty()
			and bool(live_attachment.get("completes_required_types", false))
			and bool(live_attachment.get("upgrades_public_ko", false)),
		"a lone public Luminous Energy beside basic Psychic must upgrade Jet Head into a public 200-damage KO"
	)
	_check(
		bool(live_stage2.get("verified_advantage", false))
			and str(live_stage2.get("verified_advantage_kind", ""))
				== "public_active_ko_cost_before_independent_bench_evolve"
			and "complete_public_ko_before_independent_development" \
				in live_stage2.get("decision_hints", []),
		"the model frontier must expose the exact typed-cost certificate instead of hiding it behind host validation"
	)
	_check(
		bool(live_certificate.get("verified", false))
			and str(live_certificate.get("certificate_kind", ""))
				== "public_active_ko_cost_before_independent_bench_evolve",
		"the reachable turn-7 attachment must prove a public KO while commuting ahead of the independent Bench evolve"
	)
	var strategy = StrategyScript.new()
	strategy.configure_profile(profile)
	var live_upgrade: Dictionary = strategy.call("_find_module_verified_upgrade", live, facts)
	_check(
		str(live_upgrade.get("candidate_id", "")) == "candidate:luminous-active",
		"the post-judgment safety layer must be allowed to apply the exact commuting attachment certificate"
	)
	strategy.set("_last_observation", {"observation_hash": "live-luminous-state"})
	strategy.call("_install_post_judgment_verified_upgrade", live_upgrade, live)
	_check(
		str(strategy.get("_current_action_owner")) == "module_verified_upgrade",
		"a model-reviewed module certificate must retain the existing verified-module action owner"
	)
	_check(
		bool(strategy.call(
			"_can_reuse_direct_verified_selection",
			live,
			"live-luminous-state"
		)),
		"the verified Luminous selection must survive the host's same-observation prepare pass"
	)

	var suppressed := module.annotate_frontier_v2(
		_frontier(),
		_observation(
			[_basic_energy("P"), _special_energy("OTHER_SPECIAL")],
			_luminous_energy(),
			true,
			DRAGAPULT_UID
		),
		facts,
		profile,
		{}
	)
	_check(
		not bool(_typed_attachment(suppressed[1]).get("completes_required_types", false))
			and not bool(module.verify_route_advantage(
				suppressed[1],
				suppressed[0],
				facts,
				profile
			).get("verified", false)),
		"Luminous Energy must downgrade to Colorless when another Special Energy is already attached"
	)

	var double_luminous := module.annotate_frontier_v2(
		_frontier(),
		_observation(
			[_basic_energy("P"), _luminous_energy()],
			_luminous_energy(),
			true,
			DRAGAPULT_UID
		),
		facts,
		profile,
		{}
	)
	_check(
		not bool(_typed_attachment(double_luminous[1]).get("completes_required_types", false)),
		"two Luminous Energy must suppress one another instead of fabricating the missing Fire cost"
	)

	var no_attack_window := module.annotate_frontier_v2(
		_frontier(),
		_observation([_basic_energy("P")], _luminous_energy(), false, DRAGAPULT_UID),
		facts,
		profile,
		{}
	)
	_check(
		not bool(module.verify_route_advantage(
			no_attack_window[1],
			no_attack_window[0],
			facts,
			profile
		).get("verified", false)),
		"typed completion cannot mint authority outside a deterministic attack window"
	)

	var too_large := module.annotate_frontier_v2(
		_frontier(),
		_observation(
			[_basic_energy("P")],
			_luminous_energy(),
			true,
			DRAGAPULT_UID,
			210
		),
		facts,
		profile,
		{}
	)
	_check(
		not bool(_typed_attachment(too_large[1]).get("upgrades_public_ko", false))
			and not bool(module.verify_route_advantage(
				too_large[1],
				too_large[0],
				facts,
				profile
			).get("verified", false)),
		"the certificate must fail closed when the public target exceeds Phantom Dive's fixed 200 damage"
	)

	var wrong_target := module.annotate_frontier_v2(
		_frontier(),
		_observation([_basic_energy("P")], _luminous_energy(), true, DREEPY_UID),
		facts,
		profile,
		{}
	)
	_check(
		not bool(_typed_attachment(wrong_target[1]).get("completes_required_types", false)),
		"Luminous completion must stay bound to the profiled Dragapult attacker"
	)

	if _failures.is_empty():
		print("optimization 800018499 round02 live Luminous completion: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print(
		"optimization 800018499 round02 live Luminous completion: FAIL (%d)"
		% _failures.size()
	)
	quit(1)


func _frontier() -> Array[Dictionary]:
	return [
		{
			"candidate_id": "candidate:rule-evolve",
			"route_id": "route:evolve",
			"action_kind": "evolve",
			"action_ref": {
				"card": {"uid": DRAGAPULT_UID, "type": "Pokemon"},
				"target": "slot:bench-root",
			},
			"base_score": 1347.0,
			"engine_rule_floor_exact": true,
			"outcome": {},
		},
		{
			"candidate_id": "candidate:luminous-active",
			"route_id": "route:energy_commit",
			"action_kind": "attach_energy",
			"action_ref": {
				"card": _luminous_energy(),
				"target": "slot:active",
			},
			"base_score": -87.0,
			"outcome": {},
		},
	]


func _observation(
	attached_energy: Array,
	hand_energy: Dictionary,
	attack_window_open: bool,
	active_uid: String,
	opponent_hp: int = 160
) -> Dictionary:
	return {
		"turn": {"deterministic_attack_window_open": attack_window_open},
		"own": {
			"active": {
				"slot_id": "slot:active",
				"pokemon": {"uid": active_uid, "type": "Pokemon"},
				"energy": attached_energy,
				"energy_count": attached_energy.size(),
				"remaining_hp": 200,
			},
			"bench": [{
				"slot_id": "slot:bench-root",
				"pokemon": {"uid": DREEPY_UID, "type": "Pokemon"},
				"energy": [],
				"energy_count": 0,
				"remaining_hp": 70,
			}],
			"hand": [hand_energy],
			"discard": [],
			"deck_count": 34,
			"prizes_remaining": 6,
		},
		"opponent": {
			"active": {
				"slot_id": "slot:opponent-active",
				"pokemon": {"uid": "CSV6C_051", "type": "Pokemon"},
				"energy": [],
				"energy_count": 0,
				"remaining_hp": opponent_hp,
				"prize_count": 2,
			},
			"bench": [],
			"prizes_remaining": 6,
		},
		"legal_actions": [],
	}


func _facts() -> Dictionary:
	return {
		"attack": {"ready": true, "ko_available": false, "max_damage": 70},
		"turn": {"energy_available": true, "supporter_available": true},
		"resources": {
			"deck_low": false,
			"bench_slots_free": 3,
			"hand_size": 5,
			"prizes_remaining": 6,
		},
		"board": {"bench_full": false, "has_tera": false},
		"information": {"material_action_available": false},
		"prize": {"current_swing": 0, "win_now": false},
		"route": {"current_valid": true},
	}


func _typed_attachment(candidate: Dictionary) -> Dictionary:
	var stage2 := _stage2_annotation(candidate)
	return stage2.get("typed_attachment", {}) \
		if stage2.get("typed_attachment", {}) is Dictionary else {}


func _stage2_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	return annotations.get("stage2_chain", {}) \
		if annotations.get("stage2_chain", {}) is Dictionary else {}


func _basic_energy(symbol: String) -> Dictionary:
	return {
		"uid": "BASIC_%s" % symbol,
		"type": "Basic Energy",
		"energy_type": symbol,
		"energy_provides": symbol,
	}


func _luminous_energy() -> Dictionary:
	return {
		"uid": LUMINOUS_UID,
		"effect_id": LUMINOUS_EFFECT_ID,
		"name": "Luminous Energy",
		"type": "Special Energy",
	}


func _special_energy(uid: String) -> Dictionary:
	return {
		"uid": uid,
		"type": "Special Energy",
		"energy_type": "C",
		"energy_provides": "C",
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
