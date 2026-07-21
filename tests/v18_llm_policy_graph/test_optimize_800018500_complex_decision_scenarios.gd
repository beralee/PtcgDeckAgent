extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")
const EnergyBurstScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGEnergyBurst.gd")

const DECK_ID := 800018500
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800018500.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800018500/complex_decision_scenarios.json"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, \
		"the production Toedscruel Ogerpon profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, \
		"the generated Toedscruel Ogerpon semantic manifest must load")
	_check(_profile.get("modules", []) == ["grass_spread", "energy_burst", "cycle_pivot"], \
		"the scenarios must exercise the production capability composition")

	_scenario_1_search_dance_supporter_order()
	_scenario_2_evolve_colony_rush_breakpoint()
	_scenario_3_iron_leaves_energy_handoff_closeout()
	_scenario_4_boss_and_prime_catcher_closeout()
	_scenario_5_low_deck_recovery_before_draw()
	_write_report()

	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 800018500 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800018500 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_1_search_dance_supporter_order() -> void:
	var search := _play_trainer("item:bug-set", "CSV8C_182", true)
	var dance := _ability("ability:teal-dance", "slot:ogerpon", "CSV8C_028", true)
	var research := _play_trainer("supporter:research", "CSV1C_121", false)
	var before := _observation(
		[search, dance, research],
		_slot("slot:active", "CSVSC_005", []),
		[_slot("slot:ogerpon", "CSV8C_028", [])],
		24
	)
	before["observation_version"] = 1
	before["observation_hash"] = "toedscruel-opening-before-search"
	var facts_before := _facts(false, false, true, 5, false, false, 0)
	var frontier_before := _frontier(before, {
		"item:bug-set": 500.0,
		"ability:teal-dance": 260.0,
		"supporter:research": 80.0,
	}, facts_before, "item:bug-set")
	var search_candidate := _candidate(frontier_before, "item:bug-set")
	var dance_too_early := _candidate(frontier_before, "ability:teal-dance")
	var research_too_early := _candidate(frontier_before, "supporter:research")
	_check(str(search_candidate.get("route_id", "")) == "route:information" \
		and str(search_candidate.get("checkpoint_after", "")) == "information_result", \
		"scenario 1 Bug Catching Set must be an exact information checkpoint")
	_check(str(dance_too_early.get("candidate_id", "")) != str(search_candidate.get("candidate_id", "")) \
		and str(research_too_early.get("candidate_id", "")) != str(search_candidate.get("candidate_id", "")), \
		"scenario 1 same-route search, Dance, and supporter actions must retain exact candidate identities")
	var premature_research := _route_safety(research_too_early, frontier_before, facts_before)
	_check(not bool(premature_research.get("valid", true)) \
		and str(premature_research.get("reason", "")) == "same_route_switch_without_verified_advantage", \
		"scenario 1 must not replace the exact free search floor with premature Professor's Research")

	var after_search := _observation(
		[dance, research],
		_slot("slot:active", "CSVSC_005", []),
		[_slot("slot:ogerpon", "CSV8C_028", [])],
		23
	)
	after_search["observation_version"] = 2
	after_search["observation_hash"] = "toedscruel-opening-after-search"
	after_search["own"]["hand"] = [_card("CSV5C_010"), _energy(), {"uid": "VISIBLE_SEARCH_RESULT"}]
	var facts_after_search := _facts(false, false, true, 3, false, false, 0)
	var search_delta := MaterialDeltaScript.new().compare(
		before, after_search, facts_before, facts_after_search
	)
	var epoch_strategy = _epoch_strategy()
	var search_reopens: bool = epoch_strategy.call("_should_reopen_information_epoch", \
		"local_gate", {
			"owner": "local_gate",
			"success": true,
			"route_id": str(search_candidate.get("route_id", "")),
			"candidate_id": str(search_candidate.get("candidate_id", "")),
		}, search_delta, frontier_before)
	_check(search_reopens, \
		"scenario 1 the free opening search result must reopen the local information epoch")

	var frontier_after_search := _frontier(after_search, {
		"ability:teal-dance": 480.0,
		"supporter:research": 60.0,
	}, facts_after_search, "ability:teal-dance")
	var dance_candidate := _candidate(frontier_after_search, "ability:teal-dance")
	var research_before_dance := _candidate(frontier_after_search, "supporter:research")
	var dance_roles: Array = dance_candidate.get("action_semantic_roles", []) \
		if dance_candidate.get("action_semantic_roles", []) is Array else []
	_check("energy_accelerator" in dance_roles and "ability_engine" in dance_roles, \
		"scenario 1 Teal Dance must inherit the generated public acceleration semantics")
	_check(str(dance_candidate.get("checkpoint_after", "")) == "information_result", \
		"scenario 1 Teal Dance must stop after its public attach-and-draw result")
	var second_premature_research := _route_safety(
		research_before_dance, frontier_after_search, facts_after_search
	)
	_check(not bool(second_premature_research.get("valid", true)), \
		"scenario 1 must use Teal Dance before spending the supporter quota")

	var after_dance := _observation(
		[research],
		_slot("slot:active", "CSVSC_005", []),
		[_slot("slot:ogerpon", "CSV8C_028", [_energy()])],
		22
	)
	after_dance["observation_version"] = 3
	after_dance["observation_hash"] = "toedscruel-opening-after-dance"
	after_dance["own"]["hand"] = [_card("CSV5C_010"), {"uid": "VISIBLE_DANCE_DRAW"}]
	var facts_after_dance := _facts(false, false, false, 2, false, false, 0)
	var dance_delta := MaterialDeltaScript.new().compare(
		after_search, after_dance, facts_after_search, facts_after_dance
	)
	var dance_reopens: bool = epoch_strategy.call("_should_reopen_information_epoch", \
		"local_gate", {
			"owner": "local_gate",
			"success": true,
			"route_id": str(dance_candidate.get("route_id", "")),
			"candidate_id": str(dance_candidate.get("candidate_id", "")),
		}, dance_delta, frontier_after_search)
	var frontier_after_dance := _frontier(after_dance, {
		"supporter:research": 400.0,
	}, facts_after_dance, "supporter:research")
	var supporter_candidate := _candidate(frontier_after_dance, "supporter:research")
	_check(dance_reopens and "draw_engine" in (supporter_candidate.get("action_semantic_roles", []) as Array), \
		"scenario 1 only after Dance resolves may the draw supporter become the next exact decision")
	_rows.append(_row(
		"search_dance_supporter_order",
		"开局搜索/特性/支援者顺序",
		"先用捕虫套装获取公开搜索信息，再用碧草之舞手填草能并抽1；两次均重开信息纪元，最后才决定是否使用博士的研究。",
		"item:bug-set -> ability:teal-dance -> supporter:research",
		"two_information_epoch_reopens_with_exact_candidate_binding",
		search_reopens and dance_reopens
	))


func _scenario_2_evolve_colony_rush_breakpoint() -> void:
	var evolve := {
		"id": "evolve:toedscruel-ex",
		"kind": "evolve",
		"card": _card("CSV5C_010"),
		"target": "slot:active",
	}
	var research := _play_trainer("supporter:research", "CSV1C_121", false)
	var before_evolve := _observation(
		[evolve, research],
		_slot("slot:active", "CSVSC_005", [_energy(), _energy()]),
		[
			_slot("slot:ogerpon-1", "CSV8C_028", [_energy()]),
			_slot("slot:ogerpon-2", "CSV8C_028", [_energy()]),
			_slot("slot:mew", "151C_151", [_energy()]),
		],
		18
	)
	var facts_before := _facts(false, false, false, 4, false, false, 0)
	var evolve_frontier := _frontier(before_evolve, {
		"evolve:toedscruel-ex": 520.0,
		"supporter:research": 80.0,
	}, facts_before, "evolve:toedscruel-ex")
	var evolve_candidate := _candidate(evolve_frontier, "evolve:toedscruel-ex")
	_check(str(evolve_candidate.get("route_id", "")) == "route:evolve" \
		and float((evolve_candidate.get("outcome", {}) as Dictionary).get("board_development", 0.0)) > 0.0, \
		"scenario 2 Toedscruel ex must be an exact evolution route before further draw")

	var three_unit_observation := _observation(
		[],
		_slot("slot:active", "CSV5C_010", [_energy(), _energy()]),
		[
			_slot("slot:ogerpon-1", "CSV8C_028", [_energy()]),
			_slot("slot:ogerpon-2", "CSV8C_028", [_energy()]),
			_slot("slot:mew", "151C_151", [_energy()]),
		],
		18
	)
	three_unit_observation["opponent"]["active"]["remaining_hp"] = 220
	var three_units := EnergyBurstScript.new().damage_resource_snapshot(
		three_unit_observation, _profile, {}, 220
	)
	_check(int(three_units.get("raw_units", -1)) == 3 \
		and int(three_units.get("projected_public_damage", -1)) == 200 \
		and int(three_units.get("required_units", -1)) == 4, \
		"scenario 2 three energized Bench Pokemon must remain below the 220-HP KO tier")

	var attack := _attack("attack:colony-rush", "slot:active", "CSV5C_010", 0, 240, true)
	var after_develop := _observation(
		[research, attack],
		_slot("slot:active", "CSV5C_010", [_energy(), _energy()]),
		[
			_slot("slot:ogerpon-1", "CSV8C_028", [_energy()]),
			_slot("slot:ogerpon-2", "CSV8C_028", [_energy()]),
			_slot("slot:mew", "151C_151", [_energy()]),
			_slot("slot:reserve-root", "CSVSC_005", [_energy()]),
		],
		18
	)
	after_develop["own"]["prizes_remaining"] = 2
	after_develop["opponent"]["active"] = {
		"slot_id": "slot:opponent-active",
		"pokemon": {"uid": "PUBLIC_TWO_PRIZE_TARGET"},
		"remaining_hp": 220,
		"prize_count": 2,
	}
	var facts_after := _facts(true, true, false, 4, false, false, 240)
	facts_after["resources"]["prizes_remaining"] = 2
	facts_after["prize"] = {"current_swing": 2, "win_now": true}
	var attack_frontier := _frontier(after_develop, {
		"supporter:research": 600.0,
		"attack:colony-rush": 10.0,
	}, facts_after, "supporter:research")
	var attack_candidate := _candidate(attack_frontier, "attack:colony-rush")
	var damage_annotation := _module_annotation(attack_candidate, "energy_burst")
	var attack_safety := _route_safety(attack_candidate, attack_frontier, facts_after)
	var attack_outcome: Dictionary = attack_candidate.get("outcome", {}) \
		if attack_candidate.get("outcome", {}) is Dictionary else {}
	_check(int(damage_annotation.get("damage_raw_units", -1)) == 4 \
		and int(damage_annotation.get("projected_public_damage", -1)) == 240 \
		and bool(damage_annotation.get("ko_payable_with_reserve", false)), \
		"scenario 2 the fourth energized Bench Pokemon must cross Colony Rush to 240")
	_check(bool(attack_outcome.get("win_now", false)) \
		and int(attack_outcome.get("prizes_now", 0)) == 2 \
		and str(attack_safety.get("reason", "")) == "deterministic_win_now", \
		"scenario 2 the evolved Colony Rush line must take the public final two prizes before draw")
	_rows.append(_row(
		"evolve_colony_rush_breakpoint",
		"进化/伤害档",
		"先把原野水母进化为陆地水母ex；3个带草能的备战位仅200伤，补成4个后聚落突进达到240并击倒220HP双奖目标。",
		"evolve:toedscruel-ex -> attack:colony-rush",
		str(attack_safety.get("reason", "")),
		bool(attack_safety.get("valid", false)) and bool(attack_outcome.get("win_now", false))
	))


func _scenario_3_iron_leaves_energy_handoff_closeout() -> void:
	var iron_leaves := {
		"id": "bench:iron-leaves",
		"kind": "play_basic_to_bench",
		"card": _card("CSV7C_033"),
		"requires_interaction": true,
	}
	var before := _observation(
		[iron_leaves, _play_trainer("supporter:research", "CSV1C_121", false)],
		_slot("slot:active", "CSV8C_028", []),
		[
			_slot("slot:ogerpon-1", "CSV8C_028", [_energy()]),
			_slot("slot:ogerpon-2", "CSV8C_028", [_energy()]),
		],
		16
	)
	var facts_before := _facts(false, false, true, 4, false, false, 0)
	var before_frontier := _frontier(before, {
		"bench:iron-leaves": 460.0,
		"supporter:research": 120.0,
	}, facts_before, "bench:iron-leaves")
	var leaves_candidate := _candidate(before_frontier, "bench:iron-leaves")
	var leaves_roles: Array = leaves_candidate.get("action_semantic_roles", []) \
		if leaves_candidate.get("action_semantic_roles", []) is Array else []
	_check(str(leaves_candidate.get("route_id", "")) == "route:develop" \
		and "attacker" in leaves_roles and "energy_target" in leaves_roles, \
		"scenario 3 Iron Leaves ex must remain the exact public attacker-development action")
	var before_energy := EnergyBurstScript.new().visible_energy_snapshot(before, _profile)
	_check(int(before_energy.get("total_basic_attached", -1)) == 2, \
		"scenario 3 exactly two public Grass Energy must exist before Rapid Vernier")

	var attach := _attach("attach:iron-leaves", "slot:active")
	var after_handoff := _observation(
		[ _ability("ability:teal-dance", "slot:ogerpon-1", "CSV8C_028", true), attach],
		_slot("slot:active", "CSV7C_033", [_energy(), _energy()]),
		[
			_slot("slot:previous-active", "CSV8C_028", []),
			_slot("slot:ogerpon-1", "CSV8C_028", []),
			_slot("slot:ogerpon-2", "CSV8C_028", []),
		],
		16
	)
	after_handoff["turn"] = {"deterministic_attack_window_open": true}
	var facts_handoff := _facts(false, false, true, 3, false, false, 0)
	var handoff_energy := EnergyBurstScript.new().visible_energy_snapshot(after_handoff, _profile)
	_check(int(handoff_energy.get("total_basic_attached", -1)) == 2 \
		and int((handoff_energy.get("active_by_type", {}) as Dictionary).get("G", 0)) == 2, \
		"scenario 3 Rapid Vernier must move the two visible Grass Energy onto active Iron Leaves")
	var handoff_frontier := _frontier(after_handoff, {
		"ability:teal-dance": 520.0,
		"attach:iron-leaves": 20.0,
	}, facts_handoff, "ability:teal-dance")
	var attach_candidate := _candidate(handoff_frontier, "attach:iron-leaves")
	var attach_safety := _route_safety(attach_candidate, handoff_frontier, facts_handoff)
	var typed_attachment := _module_field(attach_candidate, "grass_spread", "typed_attachment")
	_check(bool(typed_attachment.get("completes_required_types", false)) \
		and typed_attachment.get("required_symbols", []) == ["G", "G", "C"], \
		"scenario 3 the hand attachment must exactly complete Iron Leaves GGC cost")
	_check(bool(attach_safety.get("valid", false)) \
		and str(attach_safety.get("reason", "")) == "module_verified_advantage" \
		and str((attach_safety.get("advantage", {}) as Dictionary).get("certificate_kind", "")) \
		== "public_typed_attack_cost_completion", \
		"scenario 3 the exact hand attachment must beat optional Dance only through the public cost certificate")

	var leaves_attack := _attack("attack:prism-edge", "slot:active", "CSV7C_033", 0, 180, true)
	var ready := _observation(
		[_play_trainer("supporter:research", "CSV1C_121", false), leaves_attack],
		_slot("slot:active", "CSV7C_033", [_energy(), _energy(), _energy()]),
		[
			_slot("slot:ogerpon-1", "CSV8C_028", []),
			_slot("slot:ogerpon-2", "CSV8C_028", []),
		],
		16
	)
	ready["own"]["prizes_remaining"] = 2
	ready["opponent"]["active"] = {
		"slot_id": "slot:opponent-active",
		"pokemon": {"uid": "PUBLIC_TWO_PRIZE_TARGET"},
		"remaining_hp": 180,
		"prize_count": 2,
	}
	var facts_ready := _facts(true, true, false, 3, false, false, 180)
	facts_ready["resources"]["prizes_remaining"] = 2
	facts_ready["prize"] = {"current_swing": 2, "win_now": true}
	var ready_frontier := _frontier(ready, {
		"supporter:research": 600.0,
		"attack:prism-edge": 5.0,
	}, facts_ready, "supporter:research")
	var attack_candidate := _candidate(ready_frontier, "attack:prism-edge")
	var attack_safety := _route_safety(attack_candidate, ready_frontier, facts_ready)
	_check(str(attack_safety.get("reason", "")) == "deterministic_win_now" \
		and int(((attack_candidate.get("outcome", {}) as Dictionary).get("prizes_now", 0))) == 2, \
		"scenario 3 Iron Leaves must take the public final two prizes after the 2+1 energy line")
	_rows.append(_row(
		"iron_leaves_energy_handoff_closeout",
		"搬能/手填/两奖",
		"打出铁斑叶ex触发快速游标，将场上2个草能搬到新的战斗位，再手填第3能补齐GGC，以棱镜利刃拿最后2奖。",
		"bench:iron-leaves -> attach:iron-leaves -> attack:prism-edge",
		str((attach_safety.get("advantage", {}) as Dictionary).get("certificate_kind", "")),
		bool(attach_safety.get("valid", false)) and bool(attack_safety.get("valid", false))
	))


func _scenario_4_boss_and_prime_catcher_closeout() -> void:
	var boss := _play_trainer("supporter:boss", "CSVH1aC_023", true)
	boss["target"] = "slot:opponent-bench-ex"
	var prime := _play_trainer("item:prime-catcher", "CSV7C_180", true)
	prime["target"] = "slot:opponent-bench-ex"
	var boss_observation := _observation(
		[prime, boss],
		_slot("slot:active", "CSV5C_010", [_energy(), _energy()]),
		[
			_slot("slot:ogerpon-1", "CSV8C_028", [_energy()]),
			_slot("slot:ogerpon-2", "CSV8C_028", [_energy()]),
			_slot("slot:reserve", "CSVSC_005", [_energy()]),
		],
		14
	)
	boss_observation["own"]["prizes_remaining"] = 2
	boss_observation["opponent"]["active"] = {
		"slot_id": "slot:opponent-active",
		"pokemon": {"uid": "PUBLIC_WALL"},
		"remaining_hp": 330,
		"prize_count": 2,
	}
	boss_observation["opponent"]["bench"] = [{
		"slot_id": "slot:opponent-bench-ex",
		"pokemon": {"uid": "PUBLIC_TWO_PRIZE_TARGET"},
		"remaining_hp": 200,
		"prize_count": 2,
	}]
	var boss_facts := _facts(true, false, false, 3, false, false, 200)
	boss_facts["resources"]["prizes_remaining"] = 2
	var boss_frontier := _frontier(boss_observation, {
		"item:prime-catcher": 500.0,
		"supporter:boss": 480.0,
	}, boss_facts, "item:prime-catcher")
	var boss_candidate := _candidate(boss_frontier, "supporter:boss")
	var prime_candidate := _candidate(boss_frontier, "item:prime-catcher")
	var boss_energy := _module_annotation(boss_candidate, "energy_burst")
	var boss_safety := _route_safety(boss_candidate, boss_frontier, boss_facts)
	_check(str(boss_candidate.get("route_id", "")) == "route:gust" \
		and bool(boss_energy.get("target_known", false)) \
		and bool(boss_energy.get("ko_payable_with_reserve", false)) \
		and str(boss_energy.get("decision_hint", "")) == "take_payable_prize_closeout", \
		"scenario 4 Boss must bind the public 200-HP Bench target and expose a payable Colony Rush closeout")
	_check(bool(boss_safety.get("valid", false)) \
		and str(boss_safety.get("reason", "")) == "validated_switch", \
		"scenario 4 Boss must remain an admissible exact gust choice inside the profile switch margin")
	var prime_safety := _route_safety(prime_candidate, boss_frontier, boss_facts)
	_check(bool(prime_safety.get("valid", false)) \
		and str(prime_safety.get("reason", "")) == "matches_rules_floor" \
		and bool((prime_candidate.get("action_ref", {}) as Dictionary).get("requires_interaction", false)), \
		"scenario 4 Prime Catcher must remain the exact Rule-floor ACE fallback with its interaction bound")

	var prime_after := _observation(
		[_attack("attack:prime-colony-closeout", "slot:active", "CSV5C_010", 0, 200, true)],
		_slot("slot:active", "CSV5C_010", [_energy(), _energy()]),
		[
			_slot("slot:ogerpon-1", "CSV8C_028", [_energy()]),
			_slot("slot:ogerpon-2", "CSV8C_028", [_energy()]),
			_slot("slot:reserve", "CSVSC_005", [_energy()]),
		],
		14
	)
	prime_after["observation_version"] = 2
	prime_after["observation_hash"] = "toedscruel-prime-after-gust"
	prime_after["own"]["prizes_remaining"] = 2
	prime_after["opponent"]["active"] = {
		"slot_id": "slot:opponent-bench-ex",
		"pokemon": {"uid": "PUBLIC_TWO_PRIZE_TARGET"},
		"remaining_hp": 200,
		"prize_count": 2,
	}
	var prime_facts := _facts(true, true, false, 3, false, false, 200)
	prime_facts["resources"]["prizes_remaining"] = 2
	prime_facts["prize"] = {"current_swing": 2, "win_now": true}
	var prime_delta := MaterialDeltaScript.new().compare(
		boss_observation, prime_after, boss_facts, prime_facts
	)
	var prime_reopens: bool = _epoch_strategy().call("_should_reopen_information_epoch", \
		"local_gate", {
			"owner": "local_gate",
			"success": true,
			"route_id": str(prime_candidate.get("route_id", "")),
			"candidate_id": str(prime_candidate.get("candidate_id", "")),
		}, prime_delta, boss_frontier)
	var prime_attack_frontier := _frontier(prime_after, {
		"attack:prime-colony-closeout": 100.0,
	}, prime_facts, "attack:prime-colony-closeout")
	var prime_attack := _candidate(prime_attack_frontier, "attack:prime-colony-closeout")
	_check(prime_reopens \
		and bool(((prime_attack.get("outcome", {}) as Dictionary).get("win_now", false))), \
		"scenario 4 Prime Catcher resolution must reopen on the new active target and finish for two prizes")
	_rows.append(_row(
		"boss_and_prime_catcher_closeout",
		"Boss/Prime Catcher终局",
		"陆地水母ex公开可打200时，Boss锁定备战双奖目标；若走顶尖捕捉器ACE线路，则在双方换位后重开信息纪元并立刻聚落突进终结。",
		"supporter:boss | item:prime-catcher -> attack:prime-colony-closeout",
		"public_gust_target_payable_and_prime_checkpoint_reopened",
		bool(boss_safety.get("valid", false)) and prime_reopens
	))


func _scenario_5_low_deck_recovery_before_draw() -> void:
	var rod := _play_trainer("item:super-rod", "CSV1C_109", true)
	var research := _play_trainer("supporter:research", "CSV1C_121", false)
	var dance := _ability("ability:teal-dance", "slot:ogerpon", "CSV8C_028", true)
	var before := _observation(
		[rod, research, dance],
		_slot("slot:active", "CSV5C_010", [_energy(), _energy()]),
		[_slot("slot:ogerpon", "CSV8C_028", [_energy()])],
		5
	)
	before["observation_version"] = 1
	before["observation_hash"] = "toedscruel-low-deck-before-recovery"
	before["own"]["discard"] = [_card("CSVSC_005"), _card("CSV5C_010"), _energy()]
	var facts_before := _facts(true, false, false, 4, true, true, 120)
	var frontier := _frontier(before, {
		"item:super-rod": 420.0,
		"supporter:research": 410.0,
		"ability:teal-dance": 400.0,
	}, facts_before, "item:super-rod")
	var recovery := _candidate(frontier, "item:super-rod")
	var draw_supporter := _candidate(frontier, "supporter:research")
	var draw_ability := _candidate(frontier, "ability:teal-dance")
	var supporter_safety := _route_safety(draw_supporter, frontier, facts_before)
	var dance_safety := _route_safety(draw_ability, frontier, facts_before)
	_check(str(recovery.get("route_id", "")) == "route:recover" \
		and "recovery" in (recovery.get("action_semantic_roles", []) as Array) \
		and str(recovery.get("checkpoint_after", "")) == "action_resolved", \
		"scenario 5 Super Rod must be a typed recovery route, not hidden-deck information churn")
	_check(not bool(supporter_safety.get("valid", true)) \
		and str(supporter_safety.get("reason", "")) == "flareon_low_deck_blocks_cycle" \
		and not bool(dance_safety.get("valid", true)) \
		and str(dance_safety.get("reason", "")) == "flareon_low_deck_blocks_cycle", \
		"scenario 5 both Research and optional Dance must be blocked while the public deck is critical")
	_check(not EnergyBurstScript.new().should_take_optional_information(facts_before, 5, _profile), \
		"scenario 5 the energy module must independently reject optional information at five cards")

	var after := before.duplicate(true)
	after["observation_version"] = 2
	after["observation_hash"] = "toedscruel-low-deck-after-recovery"
	after["own"]["deck_count"] = 8
	after["own"]["discard"] = []
	after["legal_actions"] = [_attack("attack:pressure", "slot:active", "CSV5C_010", 0, 120, false)]
	var facts_after := _facts(true, false, false, 4, true, false, 120)
	var delta := MaterialDeltaScript.new().compare(before, after, facts_before, facts_after)
	var recovery_reopens: bool = _epoch_strategy().call("_should_reopen_information_epoch", \
		"local_gate", {
			"owner": "local_gate",
			"success": true,
			"route_id": str(recovery.get("route_id", "")),
			"candidate_id": str(recovery.get("candidate_id", "")),
		}, delta, frontier)
	_check(not recovery_reopens, \
		"scenario 5 deterministic discard recovery must not create a redundant model information epoch")
	_rows.append(_row(
		"low_deck_recovery_before_draw",
		"低牌库回收/抽牌约束",
		"牌库仅5张且弃牌有进化线与草能时先用厉害钓竿回收；阻止博士与碧草之舞继续抽牌，回收结果留在本地策略图内。",
		"item:super-rod",
		str(supporter_safety.get("reason", "")),
		not bool(supporter_safety.get("valid", true)) \
			and not bool(dance_safety.get("valid", true)) and not recovery_reopens
	))


func _frontier(
	observation: Dictionary,
	scores: Dictionary,
	facts: Dictionary,
	rule_action_id: String
) -> Array[Dictionary]:
	var route_search = RouteSearchScript.new()
	var pool: Array[Dictionary] = route_search.build_candidate_pool(
		observation, scores, _manifest, facts
	)
	var annotated: Array[Dictionary] = CapabilityRegistryScript.new().annotate_frontier(
		pool, observation, facts, _profile, _manifest
	)
	for candidate: Dictionary in annotated:
		candidate["engine_rule_floor_exact"] = \
			str(candidate.get("safe_prefix_action_id", "")) == rule_action_id
	_check(not annotated.is_empty() \
		and str(annotated[0].get("safe_prefix_action_id", "")) == rule_action_id, \
		"fixture Rule floor %s must remain exact and first" % rule_action_id)
	_check(not JSON.stringify(annotated).contains("FORBIDDEN_SECRET"), \
		"scenario frontier must never copy hidden sentinels")
	return annotated


func _route_safety(selected: Dictionary, frontier: Array[Dictionary], facts: Dictionary) -> Dictionary:
	if selected.is_empty():
		return {"valid": false, "reason": "missing_selected_candidate"}
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	return strategy.call("_validate_model_route_safety", \
		str(selected.get("route_id", "")), frontier, facts, str(selected.get("candidate_id", "")))


func _epoch_strategy():
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	strategy.configure_verified_local_only_for_benchmark()
	return strategy


func _candidate(frontier: Array[Dictionary], action_id: String) -> Dictionary:
	for candidate: Dictionary in frontier:
		if str(candidate.get("safe_prefix_action_id", "")) == action_id:
			return candidate
	_check(false, "candidate for %s must exist" % action_id)
	return {}


func _module_annotation(candidate: Dictionary, module_id: String) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	return annotations.get(module_id, {}) if annotations.get(module_id, {}) is Dictionary else {}


func _module_field(candidate: Dictionary, module_id: String, field: String) -> Dictionary:
	var annotation := _module_annotation(candidate, module_id)
	return annotation.get(field, {}) if annotation.get(field, {}) is Dictionary else {}


func _observation(
	actions: Array,
	active: Dictionary,
	bench: Array,
	deck_count: int
) -> Dictionary:
	return {
		"observation_version": 1,
		"observation_hash": "toedscruel-scenario",
		"turn": {"deterministic_attack_window_open": true},
		"own": {
			"active": active,
			"bench": bench,
			"hand": [{"uid": "VISIBLE_OWN_HAND_CARD"}],
			"discard": [],
			"deck_count": deck_count,
			"prizes_remaining": 6,
		},
		"opponent": {
			"active": {
				"slot_id": "slot:opponent-active",
				"pokemon": {"uid": "PUBLIC_OPPONENT_ACTIVE"},
				"remaining_hp": 220,
				"prize_count": 2,
			},
			"bench": [],
			"hand": [{"uid": "FORBIDDEN_SECRET_HAND_CARD"}],
			"deck_order": ["FORBIDDEN_SECRET_TOP_CARD"],
		},
		"stadium": {},
		"legal_actions": actions,
	}


func _facts(
	attack_ready: bool,
	ko_available: bool,
	energy_available: bool,
	hand_size: int,
	deck_low: bool,
	deck_critical: bool,
	max_damage: int
) -> Dictionary:
	return {
		"attack": {
			"ready": attack_ready,
			"ko_available": ko_available,
			"max_damage": max_damage,
		},
		"turn": {
			"energy_available": energy_available,
			"supporter_available": true,
		},
		"resources": {
			"deck_low": deck_low,
			"deck_critical": deck_critical,
			"hand_size": hand_size,
			"bench_slots_free": 3,
			"prizes_remaining": 6,
		},
		"board": {"bench_full": false, "has_tera": true},
		"information": {"material_action_available": true},
		"prize": {"current_swing": 0, "win_now": false},
		"route": {"current_valid": true},
	}


func _slot(slot_id: String, uid: String, energy: Array) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": _card(uid),
		"energy": energy,
		"energy_count": energy.size(),
		"remaining_hp": 200,
		"max_hp": 200,
		"prize_count": 2 if uid in ["CSV5C_010", "CSV8C_028", "CSV7C_033", "151C_151"] else 1,
	}


func _play_trainer(action_id: String, uid: String, interaction: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "play_trainer",
		"card": _card(uid),
		"requires_interaction": interaction,
	}


func _ability(action_id: String, source: String, uid: String, interaction: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "use_ability",
		"source": source,
		"source_card": _card(uid),
		"ability_index": 0,
		"requires_interaction": interaction,
	}


func _attach(action_id: String, target: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "attach_energy",
		"card": _energy(),
		"target": target,
	}


func _attack(
	action_id: String,
	source: String,
	uid: String,
	attack_index: int,
	damage: int,
	knockout: bool
) -> Dictionary:
	return {
		"id": action_id,
		"kind": "attack",
		"source": source,
		"source_card": _card(uid),
		"attack_index": attack_index,
		"projected_damage": damage,
		"projected_knockout": knockout,
	}


func _energy() -> Dictionary:
	return {
		"uid": "CSVE1C_GRA",
		"name": "Grass Energy",
		"type": "Basic Energy",
		"energy_type": "G",
		"energy_provides": "G",
		"semantic_roles": ["energy_source", "typed_energy", "basic_energy"],
	}


func _card(uid: String) -> Dictionary:
	for raw_card: Variant in _manifest.get("cards", []):
		if not (raw_card is Dictionary) or str((raw_card as Dictionary).get("uid", "")) != uid:
			continue
		var source: Dictionary = raw_card
		return {
			"uid": uid,
			"effect_id": str(source.get("effect_id", "")),
			"name": str(source.get("name", "")),
			"type": str(source.get("type", "")),
			"semantic_roles": (source.get("roles", []) as Array).duplicate() \
				if source.get("roles", []) is Array else [],
		}
	_check(false, "manifest card %s must exist" % uid)
	return {"uid": uid}


func _row(
	id: String,
	category: String,
	description: String,
	expected_choice: String,
	proof_reason: String,
	passed: bool
) -> Dictionary:
	return {
		"id": id,
		"category": category,
		"description": description,
		"expected_choice": expected_choice,
		"proof_reason": proof_reason,
		"passed": passed,
	}


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"semantic_schema": "v18cpg-2",
		"transport_contract_version": 3,
		"deck_id": DECK_ID,
		"deck_name": "18.0 陆地水母厄诡椪",
		"strategy_id": str(_profile.get("strategy_id", "")),
		"profile_version": int(_profile.get("profile_version", 0)),
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"isolation": {
			"profile_modified": false,
			"shared_runtime_modified": false,
			"hidden_sentinel_absent_from_frontiers": true,
		},
		"scenarios": _rows.duplicate(true),
		"failures": _failures.duplicate(),
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	_check(file != null, "complex scenario report must be writable")
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()


func _load_json(path: String) -> Dictionary:
	_check(FileAccess.file_exists(path), "%s must exist" % path)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "%s must contain valid JSON" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
