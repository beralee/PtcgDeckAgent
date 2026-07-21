extends SceneTree

const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const MOVER_UID := "CSV8C_094"
const DARK_UID := "CSVE1C_DAR"
const ACTIVE_UID := "CSV2C_055"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(800018498)
	_check(int(profile.get("profile_version", 0)) >= 7, "round07 profile must be active")
	_test_full_pool_annotation_before_pruning(profile)
	_test_three_stage_zero_model_closeout(profile)
	_test_negative_boundaries(profile)
	if _failures.is_empty():
		print("V18CPG 800018498 round07 counter-mover closeout: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG 800018498 round07 counter-mover closeout: FAIL (%d)" % _failures.size())
	quit(1)


func _test_full_pool_annotation_before_pruning(profile: Dictionary) -> void:
	var observation := _play_stage_observation()
	var scores := _scores_for(observation.get("legal_actions", []))
	var facts := _facts(false, true)
	var search := RouteSearchScript.new()
	var old_order_frontier := search.build_frontier(observation, scores, {}, facts, 10)
	_check(
		_find_action(old_order_frontier, "action:bench_second_mover").is_empty(),
		"pre-annotation ten-candidate pruning must reproduce the second-Munkidori starvation"
	)
	var pool := search.build_candidate_pool(observation, scores, {}, facts)
	_check(not _find_action(pool, "action:bench_second_mover").is_empty(), "the full legal pool must retain the Rule-low second Munkidori")
	var annotated := CapabilityRegistryScript.new().annotate_frontier(pool, observation, facts, profile, {})
	var pruned := search.prune_frontier(annotated, 10)
	var mover := _find_action(pruned, "action:bench_second_mover")
	_check(pruned.size() <= 10, "certificate-aware pruning must preserve the transport cap")
	_check(str(pruned[0].get("safe_prefix_action_id", "")) == "action:attack", "certificate retention must not change the exact Rule root")
	_check(not mover.is_empty(), "the verified second Munkidori must survive the ten-candidate cap")
	var certificate := _certificate(mover)
	_check(str(certificate.get("closeout_stage", "")) == "bench_second_counter_mover", "the retained candidate must own the exact bench stage")
	_check(int(certificate.get("damage_gap", 0)) == 10, "the seed-502 public closeout gap must be ten damage")
	_check(int(certificate.get("projected_total_damage", 0)) == 220, "one counter move plus the 190 attack must exceed the visible 200 HP")
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	var upgrade := strategy._find_module_verified_upgrade(pruned, facts)
	_check(str(upgrade.get("safe_prefix_action_id", "")) == "action:bench_second_mover", "zero-model gate must select the retained second Munkidori")
	_check(
		str(upgrade.get("verified_advantage", {}).get("certificate_kind", "")) == "public_second_counter_mover_final_prize_closeout",
		"the bench stage must carry the exact public final-prize certificate"
	)
	strategy._select_route("route:develop", pruned, "module_verified_upgrade", str(upgrade.get("candidate_id", "")))
	_check(
		str(strategy.get("_active_module_certificate_kind")) == "public_second_counter_mover_final_prize_closeout",
		"the selected action must retain auditable certificate ownership"
	)


func _test_three_stage_zero_model_closeout(profile: Dictionary) -> void:
	var stages: Array[Dictionary] = [{
		"label": "bench",
		"observation": _play_stage_observation(),
		"expected_action": "action:bench_second_mover",
		"expected_stage": "bench_second_counter_mover",
		"facts": _facts(false, true),
	}, {
		"label": "attach",
		"observation": _attach_stage_observation(),
		"expected_action": "action:attach_dark_new_mover",
		"expected_stage": "activate_second_counter_mover",
		"facts": _facts(false, true),
	}, {
		"label": "move",
		"observation": _move_stage_observation(),
		"expected_action": "action:move_final_counters",
		"expected_stage": "move_final_counters",
		"facts": _facts(false, false),
	}]
	for stage: Dictionary in stages:
		var observation: Dictionary = stage.get("observation", {})
		var facts: Dictionary = stage.get("facts", {})
		var search := RouteSearchScript.new()
		var pool := search.build_candidate_pool(observation, _scores_for(observation.get("legal_actions", [])), {}, facts)
		var annotated := CapabilityRegistryScript.new().annotate_frontier(pool, observation, facts, profile, {})
		var frontier := search.prune_frontier(annotated, 10)
		var strategy := StrategyScript.new()
		strategy.configure_profile(profile)
		var upgrade := strategy._find_module_verified_upgrade(frontier, facts)
		_check(
			str(upgrade.get("safe_prefix_action_id", "")) == str(stage.get("expected_action", "")),
			"%s stage must advance locally without spending model budget" % str(stage.get("label", ""))
		)
		_check(
			str(_certificate(upgrade).get("closeout_stage", "")) == str(stage.get("expected_stage", "")),
			"%s stage must be proven by the matching public state" % str(stage.get("label", ""))
		)
	var ko_observation := _move_stage_observation()
	ko_observation["opponent"]["active"]["remaining_hp"] = 170
	ko_observation["legal_actions"] = [_attack_action(true, 190)]
	var ko_facts := _facts(true, false)
	var ko_search := RouteSearchScript.new()
	var ko_pool := ko_search.build_candidate_pool(ko_observation, _scores_for(ko_observation.get("legal_actions", [])), {}, ko_facts)
	var ko_frontier := CapabilityRegistryScript.new().annotate_frontier(ko_pool, ko_observation, ko_facts, profile, {})
	var ko_strategy := StrategyScript.new()
	ko_strategy.configure_profile(profile)
	_check(ko_strategy._find_module_verified_upgrade(ko_frontier, ko_facts).is_empty(), "once the 190 attack is a KO, the certificate must stop at the terminal Rule attack")


func _test_negative_boundaries(profile: Dictionary) -> void:
	var cases: Array[Dictionary] = []
	var bench_full := _play_stage_observation()
	bench_full["own"]["bench"].append(_slot("slot:fifth", "pokemon:filler:5", false, [], 0))
	cases.append({"label": "bench full", "observation": bench_full, "facts": _facts(false, true)})
	var no_dark := _play_stage_observation()
	no_dark["own"]["hand"] = [{"uid": MOVER_UID, "type": "Pokemon"}]
	cases.append({"label": "no Darkness Energy", "observation": no_dark, "facts": _facts(false, true)})
	cases.append({"label": "attachment quota used", "observation": _play_stage_observation(), "facts": _facts(false, false)})
	var low_damage := _play_stage_observation()
	low_damage["own"]["active"]["damage"] = 5
	cases.append({"label": "insufficient movable damage", "observation": low_damage, "facts": _facts(false, true)})
	var too_many_prizes := _play_stage_observation()
	too_many_prizes["own"]["prizes_remaining"] = 4
	cases.append({"label": "not final prize tier", "observation": too_many_prizes, "facts": _facts(false, true)})
	var one_prize_target := _play_stage_observation()
	one_prize_target["opponent"]["active"]["prize_count"] = 1
	cases.append({"label": "one-prize target", "observation": one_prize_target, "facts": _facts(false, true)})
	cases.append({"label": "attack already KOs", "observation": _play_stage_observation(), "facts": _facts(true, true)})
	var wrong_attacker := _play_stage_observation()
	wrong_attacker["own"]["active"]["pokemon"]["uid"] = "pokemon:wrong_attacker"
	cases.append({"label": "damage-sensitive attacker", "observation": wrong_attacker, "facts": _facts(false, true)})
	for invalid: Dictionary in cases:
		var observation: Dictionary = invalid.get("observation", {})
		var facts: Dictionary = invalid.get("facts", {})
		var search := RouteSearchScript.new()
		var pool := search.build_candidate_pool(observation, _scores_for(observation.get("legal_actions", [])), {}, facts)
		var annotated := CapabilityRegistryScript.new().annotate_frontier(pool, observation, facts, profile, {})
		var mover := _find_action(annotated, "action:bench_second_mover")
		_check(
			not bool(_certificate(mover).get("advances_final_prize_closeout", false)),
			"%s must not mint the second-counter-mover certificate" % str(invalid.get("label", "invalid"))
		)


func _play_stage_observation() -> Dictionary:
	var observation := _base_observation()
	observation["legal_actions"] = [
		_attack_action(false, 190),
		{"id": "action:kirlia", "kind": "use_ability", "source": "slot:kirlia", "source_card": {"uid": "pokemon:kirlia"}},
		{"id": "action:nest", "kind": "play_trainer", "card": {"uid": "trainer:nest"}},
		{"id": "action:ultra", "kind": "play_trainer", "card": {"uid": "trainer:ultra"}},
		{"id": "action:evolve", "kind": "evolve", "card": {"uid": "pokemon:evolve"}, "target": "slot:kirlia"},
		{"id": "action:charm", "kind": "attach_tool", "card": {"uid": "CSV1C_118"}, "target": "slot:active"},
		{"id": "action:attach_a", "kind": "attach_energy", "card": _dark_energy(), "target": "slot:kirlia"},
		{"id": "action:attach_b", "kind": "attach_energy", "card": _dark_energy(), "target": "slot:filler:1"},
		{"id": "action:attach_c", "kind": "attach_energy", "card": _dark_energy(), "target": "slot:filler:2"},
		{"id": "action:retreat", "kind": "retreat", "target": "slot:kirlia"},
		{"id": "action:end", "kind": "end_turn"},
		{"id": "action:bench_second_mover", "kind": "play_basic_to_bench", "card": {"uid": MOVER_UID, "type": "Pokemon"}},
	]
	return observation


func _attach_stage_observation() -> Dictionary:
	var observation := _base_observation()
	observation["own"]["bench"].append(_slot("slot:new_mover", MOVER_UID, false, [], 0))
	observation["own"]["hand"] = [_dark_energy()]
	observation["legal_actions"] = [
		_attack_action(false, 190),
		{"id": "action:attach_dark_new_mover", "kind": "attach_energy", "card": _dark_energy(), "target": "slot:new_mover"},
		{"id": "action:end", "kind": "end_turn"},
	]
	return observation


func _move_stage_observation() -> Dictionary:
	var observation := _base_observation()
	observation["own"]["bench"].append(_slot("slot:new_mover", MOVER_UID, false, [_dark_energy()], 0))
	observation["own"]["hand"] = []
	observation["legal_actions"] = [
		_attack_action(false, 190),
		{
			"id": "action:move_final_counters",
			"kind": "use_ability",
			"source": "slot:new_mover",
			"source_card": {"uid": MOVER_UID, "type": "Pokemon"},
		},
		{"id": "action:end", "kind": "end_turn"},
	]
	return observation


func _base_observation() -> Dictionary:
	return {
		"own": {
			"prizes_remaining": 2,
			"deck_count": 16,
			"hand": [{"uid": MOVER_UID, "type": "Pokemon"}, _dark_energy()],
			"discard": [],
			"active": _slot("slot:active", ACTIVE_UID, false, [], 200, 110, 310),
			"bench": [
				_slot("slot:used_mover", MOVER_UID, true, [_dark_energy()], 0),
				_slot("slot:kirlia", "pokemon:kirlia", false, [], 0),
				_slot("slot:filler:1", "pokemon:filler:1", false, [], 0),
				_slot("slot:filler:2", "pokemon:filler:2", false, [], 0),
			],
		},
		"opponent": {
			"deck_count": 12,
			"active": _slot("slot:iron_hands", "CSV6C_051", false, [], 0, 200, 230, 2),
			"bench": [],
		},
	}


func _slot(
	slot_id: String,
	uid: String,
	ability_used: bool,
	energy: Array,
	damage: int,
	remaining_hp: int = 100,
	max_hp: int = 100,
	prize_count: int = 1
) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid},
		"tool": {},
		"energy": energy.duplicate(true),
		"damage": damage,
		"remaining_hp": remaining_hp,
		"max_hp": max_hp,
		"prize_count": prize_count,
		"ability_used": ability_used,
	}


func _attack_action(ko: bool, damage: int) -> Dictionary:
	return {"id": "action:attack", "kind": "attack", "projected_damage": damage, "projected_knockout": ko}


func _dark_energy() -> Dictionary:
	return {"uid": DARK_UID, "type": "Basic Energy", "energy_type": "D"}


func _facts(ko: bool, energy_available: bool) -> Dictionary:
	return {
		"attack": {"ready": true, "ko_available": ko, "max_damage": 190},
		"resources": {"prizes_remaining": 2, "deck_low": false},
		"turn": {"energy_available": energy_available},
	}


func _scores_for(actions: Array) -> Dictionary:
	var explicit := {
		"action:attack": 2473.0,
		"action:kirlia": 650.0,
		"action:nest": 600.0,
		"action:ultra": 590.0,
		"action:evolve": 550.0,
		"action:charm": 500.0,
		"action:attach_a": 450.0,
		"action:attach_b": 440.0,
		"action:attach_c": 430.0,
		"action:retreat": 100.0,
		"action:end": 0.0,
		"action:bench_second_mover": -100000.0,
		"action:attach_dark_new_mover": -100000.0,
		"action:move_final_counters": -100000.0,
	}
	var result: Dictionary = {}
	for raw_action: Variant in actions:
		if raw_action is Dictionary:
			var action_id := str((raw_action as Dictionary).get("id", ""))
			result[action_id] = float(explicit.get(action_id, 0.0))
	return result


func _find_action(candidates: Array[Dictionary], action_id: String) -> Dictionary:
	for candidate: Dictionary in candidates:
		if str(candidate.get("safe_prefix_action_id", "")) == action_id:
			return candidate
	return {}


func _certificate(candidate: Dictionary) -> Dictionary:
	return candidate.get("module_annotations", {}).get("damage_counter_control", {}).get("counter_mover_closeout", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
