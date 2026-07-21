extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const MOVER_UID := "CSV8C_094"
const BUDEW_UID := "CSV9.5C_004"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800018498)
	_check(int(profile.get("profile_version", 0)) >= 8, "round08 profile must be active")
	_test_turn_7_and_turn_13_setup(profile)
	_test_setup_stops_at_exact_boundaries(profile)
	_test_paired_evaluation_hand_reset(profile)
	if _failures.is_empty():
		print("V18CPG 800018498 round08 low-pressure setup: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG 800018498 round08 low-pressure setup: FAIL (%d)" % _failures.size())
	quit(1)


func _test_turn_7_and_turn_13_setup(profile: Dictionary) -> void:
	for mover_count: int in [0, 1]:
		var observation := _observation(mover_count, 3 - mover_count)
		var facts := _facts(10, false)
		var frontier := _frontier(observation, facts, profile)
		_check(str(frontier[0].get("safe_prefix_action_id", "")) == "action:budew_attack", "Rule root must remain the Budew attack")
		var mover := _find_action(frontier, "action:bench_mover")
		var setup := _setup_certificate(mover)
		_check(bool(setup.get("advances_profiled_setup", false)), "Munkidori copy %d must advance the exact two-copy engine" % (mover_count + 1))
		_check(int(setup.get("mover_count_before", -1)) == mover_count, "certificate must count only visible Munkidori in play")
		_check(int(setup.get("mover_count_after", -1)) == mover_count + 1, "certificate must stop at the configured target")
		var strategy := StrategyScript.new()
		strategy.configure_profile(profile)
		var upgrade := strategy._find_module_verified_upgrade(frontier, facts)
		_check(str(upgrade.get("safe_prefix_action_id", "")) == "action:bench_mover", "low-pressure setup must take zero-model local ownership")
		_check(
			str(upgrade.get("verified_advantage", {}).get("certificate_kind", "")) == "public_profiled_low_pressure_counter_engine_setup",
			"low-pressure setup must carry the exact profiled certificate"
		)


func _test_setup_stops_at_exact_boundaries(profile: Dictionary) -> void:
	var cases: Array[Dictionary] = []
	var wrong_active := _observation(0, 3)
	wrong_active["own"]["active"]["pokemon"]["uid"] = "pokemon:not_budew"
	cases.append({"label": "wrong Active", "observation": wrong_active, "facts": _facts(10, false)})
	cases.append({"label": "meaningful attack", "observation": _observation(0, 3), "facts": _facts(20, false)})
	cases.append({"label": "KO already available", "observation": _observation(0, 3), "facts": _facts(10, true)})
	var prizes_taken := _observation(0, 3)
	prizes_taken["own"]["prizes_remaining"] = 5
	cases.append({"label": "not the profiled opening prize tier", "observation": prizes_taken, "facts": _facts(10, false)})
	var one_prize_target := _observation(0, 3)
	one_prize_target["opponent"]["active"]["prize_count"] = 1
	cases.append({"label": "one-prize opposing Active", "observation": one_prize_target, "facts": _facts(10, false)})
	cases.append({"label": "last bench slot protected", "observation": _observation(1, 1), "facts": _facts(10, false)})
	cases.append({"label": "two movers already online", "observation": _observation(2, 1), "facts": _facts(10, false)})
	var wrong_card := _observation(0, 3)
	wrong_card["legal_actions"][1]["card"]["uid"] = "pokemon:not_munkidori"
	cases.append({"label": "wrong Bench candidate", "observation": wrong_card, "facts": _facts(10, false)})
	for invalid: Dictionary in cases:
		var observation: Dictionary = invalid.get("observation", {})
		var facts: Dictionary = invalid.get("facts", {})
		var frontier := _frontier(observation, facts, profile)
		var mover := _find_action(frontier, "action:bench_mover")
		_check(
			not bool(_setup_certificate(mover).get("advances_profiled_setup", false)),
			"%s must not mint the profiled setup certificate" % str(invalid.get("label", "invalid"))
		)


func _test_paired_evaluation_hand_reset(profile: Dictionary) -> void:
	var observation := _reset_observation()
	var facts := _facts(10, false)
	var scores := {"action:budew_attack": 215.72, "action:research": 125.6, "action:end": -924.0}
	var search := RouteSearchScript.new()
	var pool := search.build_candidate_pool(observation, scores, {}, facts)
	var frontier := search.prune_frontier(
		CapabilityRegistryScript.new().annotate_frontier(pool, observation, facts, profile, {}),
		10
	)
	_check(str(frontier[0].get("safe_prefix_action_id", "")) == "action:budew_attack", "paired reset must not rewrite the frozen Rule root")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var upgrade := strategy._find_module_verified_upgrade(frontier, facts)
	_check(str(upgrade.get("safe_prefix_action_id", "")) == "action:research", "the exact double-engine stall fixture must select Professor's Research")
	_check(
		str(upgrade.get("verified_advantage", {}).get("certificate_kind", "")) == "profiled_double_counter_engine_hand_reset" \
			and str(upgrade.get("verified_advantage", {}).get("evidence_kind", "")) == "paired_evaluation",
		"the hand reset must be labeled as paired-evaluation evidence, not a deterministic hidden-draw proof"
	)
	var invalids: Array[Dictionary] = []
	var one_mover := _reset_observation()
	one_mover["own"]["bench"].remove_at(2)
	one_mover["own"]["bench"].append(_slot("slot:filler", "pokemon:filler"))
	invalids.append({"label": "only one mover", "observation": one_mover, "facts": facts})
	var one_root := _reset_observation()
	one_root["own"]["bench"].remove_at(4)
	one_root["own"]["bench"].append(_slot("slot:filler", "pokemon:filler"))
	invalids.append({"label": "only one Ralts", "observation": one_root, "facts": facts})
	var open_bench := _reset_observation()
	open_bench["own"]["bench"].remove_at(4)
	invalids.append({"label": "bench not full", "observation": open_bench, "facts": facts})
	var small_hand := _reset_observation()
	small_hand["own"]["hand"].resize(5)
	invalids.append({"label": "hand below profiled reset size", "observation": small_hand, "facts": facts})
	var supporter_used := _facts(10, false)
	supporter_used["turn"]["supporter_available"] = false
	invalids.append({"label": "supporter quota used", "observation": _reset_observation(), "facts": supporter_used})
	for invalid: Dictionary in invalids:
		var invalid_observation: Dictionary = invalid.get("observation", {})
		var invalid_facts: Dictionary = invalid.get("facts", {})
		var invalid_pool := search.build_candidate_pool(invalid_observation, scores, {}, invalid_facts)
		var invalid_frontier := CapabilityRegistryScript.new().annotate_frontier(
			invalid_pool, invalid_observation, invalid_facts, profile, {}
		)
		var research := _find_action(invalid_frontier, "action:research")
		var reset: Dictionary = research.get("module_annotations", {}).get("damage_counter_control", {}).get("profiled_hand_reset", {}) \
			if research.get("module_annotations", {}) is Dictionary else {}
		_check(
			not bool(reset.get("advances_profiled_reset", false)),
			"%s must not activate the paired-evaluation reset" % str(invalid.get("label", "invalid"))
		)


func _frontier(observation: Dictionary, facts: Dictionary, profile: Dictionary) -> Array[Dictionary]:
	var scores := {"action:budew_attack": 215.72, "action:bench_mover": 196.84, "action:end": -924.0}
	var search := RouteSearchScript.new()
	var pool := search.build_candidate_pool(observation, scores, {}, facts)
	var annotated := CapabilityRegistryScript.new().annotate_frontier(pool, observation, facts, profile, {})
	return search.prune_frontier(annotated, 10)


func _observation(mover_count: int, bench_slots_free: int) -> Dictionary:
	var bench: Array[Dictionary] = []
	for index: int in mover_count:
		bench.append(_slot("slot:mover:%d" % index, MOVER_UID))
	var desired_bench_size := 5 - bench_slots_free
	while bench.size() < desired_bench_size:
		bench.append(_slot("slot:filler:%d" % bench.size(), "pokemon:filler"))
	return {
		"own": {
			"prizes_remaining": 6,
			"deck_count": 40,
			"hand": [{"uid": MOVER_UID, "type": "Pokemon"}],
			"discard": [],
			"active": _slot("slot:active", BUDEW_UID, 30, 0),
			"bench": bench,
		},
		"opponent": {
			"deck_count": 38,
			"active": _slot("slot:opponent", "CSV8C_135", 190, 20, 2),
			"bench": [],
		},
		"legal_actions": [{
			"id": "action:budew_attack",
			"kind": "attack",
			"projected_damage": 10,
			"projected_knockout": false,
			"source": "slot:active",
			"source_card": {"uid": BUDEW_UID},
		}, {
			"id": "action:bench_mover",
			"kind": "play_basic_to_bench",
			"card": {"uid": MOVER_UID, "type": "Pokemon"},
		}, {"id": "action:end", "kind": "end_turn"}],
	}


func _reset_observation() -> Dictionary:
	return {
		"own": {
			"prizes_remaining": 6,
			"deck_count": 33,
			"hand": [
				{"uid": "CSV6C_114", "type": "Item"},
				{"uid": "CSV2C_055", "type": "Pokemon"},
				{"uid": "CSV2C_055", "type": "Pokemon"},
				{"uid": "CSV5C_119", "type": "Tool"},
				{"uid": "CSV1C_121", "type": "Supporter"},
				{"uid": "CSV1C_118", "type": "Tool"},
			],
			"discard": [],
			"active": _slot("slot:active", BUDEW_UID, 30, 0),
			"bench": [
				_slot("slot:fez", "CSV8C_135"),
				_slot("slot:mover:1", MOVER_UID),
				_slot("slot:mover:2", MOVER_UID),
				_slot("slot:ralts:1", "CSV2C_053"),
				_slot("slot:ralts:2", "CSV2C_053"),
			],
		},
		"opponent": {
			"deck_count": 32,
			"active": _slot("slot:opponent", "CSV8C_135", 130, 80, 2),
			"bench": [],
		},
		"legal_actions": [{
			"id": "action:budew_attack",
			"kind": "attack",
			"projected_damage": 10,
			"projected_knockout": false,
			"source": "slot:active",
			"source_card": {"uid": BUDEW_UID},
		}, {
			"id": "action:research",
			"kind": "play_trainer",
			"card": {"uid": "CSV1C_121", "type": "Supporter"},
		}, {"id": "action:end", "kind": "end_turn"}],
	}


func _slot(slot_id: String, uid: String, remaining_hp: int = 100, damage: int = 0, prize_count: int = 1) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid},
		"tool": {},
		"energy": [],
		"damage": damage,
		"remaining_hp": remaining_hp,
		"max_hp": remaining_hp + damage,
		"prize_count": prize_count,
		"ability_used": false,
	}


func _facts(damage: int, ko: bool) -> Dictionary:
	return {
		"attack": {"ready": true, "ko_available": ko, "max_damage": damage},
		"resources": {"prizes_remaining": 6, "deck_low": false},
		"turn": {"energy_available": true, "supporter_available": true},
	}


func _find_action(candidates: Array[Dictionary], action_id: String) -> Dictionary:
	for candidate: Dictionary in candidates:
		if str(candidate.get("safe_prefix_action_id", "")) == action_id:
			return candidate
	return {}


func _setup_certificate(candidate: Dictionary) -> Dictionary:
	return candidate.get("module_annotations", {}).get("damage_counter_control", {}).get("counter_engine_setup", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
