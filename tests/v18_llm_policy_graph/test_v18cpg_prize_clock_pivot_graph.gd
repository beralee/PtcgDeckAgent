extends SceneTree

const CapabilityRegistryScript = preload(
	"res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd"
)
const PrizeClockSolverScript = preload(
	"res://scripts/ai/v18_cpg/planning/V18CPGPrizeClockSolver.gd"
)
const StrategyScript = preload(
	"res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd"
)
const HardGuardScript = preload(
	"res://scripts/ai/v18_cpg/planning/V18CPGHardGuard.gd"
)
const ProfilePolicyScript = preload(
	"res://scripts/ai/v18_cpg/policy/V18CPGProfilePolicy.gd"
)

const RAGING_BOLT_EX_UID := "CSV7C_154"
const RAGING_BOLT_UID := "CSV8C_161"
const SLITHER_WING_UID := "CSV6C_082"
const TEAL_MASK_OGERPON_EX_UID := "CSV8C_028"
const LATIAS_EX_UID := "CSV9C_078"
const BLOODMOON_EX_UID := "CSV8C_172"
const AREA_ZERO_UID := "CSV9C_207"
const NOCTOWL_UID := "CSV9C_155"

var _failures: Array[String] = []
var _planning_p95_usec := 0


func _initialize() -> void:
	_test_attack_window_race_uses_alternating_ticks()
	_test_profile_keeps_prize_clock_priorities()
	_test_gustable_two_prizer_can_end_the_game_next_window()
	_test_gust_guard_binds_the_exact_public_lethal_target()
	_test_rule_veto_requires_an_exact_verified_certificate()
	_test_intrinsic_veto_reopens_a_stale_terminal_guard()
	_test_non_ko_pressure_does_not_claim_a_current_window_prize()
	_test_global_base_module_preserves_rule_scores()
	_test_credible_gust_keeps_retreat_as_non_certified_denial()
	_test_public_gust_exhaustion_can_certify_one_prize_bridge()
	_test_raging_bolt_extension_operators_and_clock_effects()
	_test_terminal_win_remains_lexicographically_first()
	_test_bloodmoon_and_single_prize_routes_are_explained()
	_test_dynamic_bloodmoon_pivot_ko_prevents_rule_end_turn()
	_test_raging_initial_typed_completion_cannot_reorder_supporter_before_rule()
	_test_supporter_acceleration_cannot_cross_exact_rule_attachment()
	_test_completion_prefix_cannot_cross_information_checkpoint()
	_test_raging_route_suffix_survives_model_compaction()
	_test_local_prize_clock_planning_stays_within_budget()

	if _failures.is_empty():
		print(
			"V18CPG prize-clock pivot graph: PASS (local p95 %.3fms)"
				% (float(_planning_p95_usec) / 1000.0)
		)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG prize-clock pivot graph: FAIL (%d)" % _failures.size())
	quit(1)


func _test_attack_window_race_uses_alternating_ticks() -> void:
	var observation := _observation()
	observation["own"]["prizes_remaining"] = 3
	observation["opponent"]["prizes_remaining"] = 4
	observation["own"]["active"]["prize_count"] = 2
	observation["opponent"]["active"]["prize_count"] = 1
	var snapshot: Dictionary = PrizeClockSolverScript.new().solve(
		observation,
		_facts(true, true, 120),
		_profile()
	)
	_check(
		snapshot.get("own", {}).get("robust", {}).get("prize_sequence", []) == [1, 1, 1],
		"Base clock must model the public one-prize lane as three own attack windows"
	)
	_check(
		int(snapshot.get("own", {}).get("robust", {}).get("finish_tick", -1)) == 4,
		"own attack windows must be ticks 0, 2, and 4"
	)
	_check(
		snapshot.get("opponent", {}).get("robust", {}).get("prize_sequence", []) == [2, 2],
		"opponent prize clock must expose the current two-prize Active liability"
	)
	_check(
		int(snapshot.get("opponent", {}).get("robust", {}).get("finish_tick", -1)) == 3,
		"opponent attack windows must be ticks 1 and 3"
	)
	_check(
		int(snapshot.get("race_margin", 0)) == -1,
		"race margin must compare alternating attack windows instead of raw turn counts"
	)


func _test_profile_keeps_prize_clock_priorities() -> void:
	var typed := ProfilePolicyScript.new().sanitize(
		{
			"strategic_priorities": [
				{
					"priority": 1,
					"goal": "immediate_public_win",
					"prefer_routes": ["route:attack_ko"],
				},
				{
					"priority": 2,
					"goal": "prevent_next_attack_window_loss",
					"prefer_routes": ["route:pivot"],
				},
				{
					"priority": 3,
					"goal": "repair_robust_prize_clock",
					"prefer_routes": ["route:develop"],
				},
			],
		},
		["route:attack_ko", "route:pivot", "route:develop"]
	)
	var goals: Array[String] = []
	for raw_priority: Variant in typed.get("strategic_priorities", []):
		if raw_priority is Dictionary:
			goals.append(str((raw_priority as Dictionary).get("goal", "")))
	_check(
		goals == [
			"immediate_public_win",
			"prevent_next_attack_window_loss",
			"repair_robust_prize_clock",
		],
		"the typed profile boundary must not silently discard the three prize-clock priorities"
	)


func _test_rule_veto_requires_an_exact_verified_certificate() -> void:
	var guard = HardGuardScript.new()
	var vetoed := _candidate(
		"candidate:generic_vetoed_bench",
		"route:develop",
		"play_basic_to_bench",
		"action:generic_vetoed_bench",
		-100000.0,
		false
	)
	vetoed["post_attack_continuity"] = {
		"progresses_debt": true,
		"planned_debt_types": ["next_attacker_root"],
	}
	var blocked: Dictionary = guard.filter_candidates(
		[vetoed],
		_observation(),
		_facts(true, true, 120),
		_profile()
	)
	_check(
		(blocked.get("candidates", []) as Array).is_empty()
			and (blocked.get("blocked_action_ids", {}) as Dictionary).has(
				"action:generic_vetoed_bench"
			),
		"a generic continuity hint must not turn a Rule veto sentinel into an executable fallback action"
	)

	var certified := vetoed.duplicate(true)
	certified["module_annotations"] = {
		"verified_test": {
			"verified_advantage": true,
			"verified_advantage_kind": "exact_public_counterexample",
		},
	}
	var certified_result: Dictionary = guard.filter_candidates(
		[certified],
		_observation(),
		_facts(true, true, 120),
		_profile()
	)
	_check(
		(certified_result.get("candidates", []) as Array).size() == 1,
		"an exact verified capability certificate must retain authority to cross a Rule sentinel"
	)


func _test_intrinsic_veto_reopens_a_stale_terminal_guard() -> void:
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile())
	var vetoed := _candidate(
		"candidate:stale_pseudo_prefix",
		"route:develop",
		"play_basic_to_bench",
		"action:stale_pseudo_prefix",
		-100000.0,
		false
	)
	var terminal := _candidate(
		"candidate:end",
		"route:end_turn",
		"end_turn",
		"action:end_turn",
		-144.0,
		true
	)
	var stale_facts := _facts(true, true, 120)
	stale_facts["continuity"] = {
		"review_before_terminal": true,
		"safe_prefix_available": true,
		"floor_met": false,
	}
	var guarded: Dictionary = strategy._apply_runtime_hard_guards(
		[vetoed, terminal],
		_observation(),
		stale_facts
	)
	var allowed: Array = guarded.get("candidates", []) \
		if guarded.get("candidates", []) is Array else []
	var blocked_ids: Dictionary = guarded.get("blocked_action_ids", {}) \
		if guarded.get("blocked_action_ids", {}) is Dictionary else {}
	_check(
		allowed.size() == 1
			and str((allowed[0] as Dictionary).get(
				"safe_prefix_action_id",
				""
			)) == "action:end_turn"
			and blocked_ids.has("action:stale_pseudo_prefix")
			and not blocked_ids.has("action:end_turn"),
		"after intrinsic guards remove the only pseudo-prefix, continuity facts must rebuild and reopen the terminal action"
	)


func _test_gustable_two_prizer_can_end_the_game_next_window() -> void:
	var observation := _observation()
	observation["opponent"]["prizes_remaining"] = 2
	observation["own"]["active"] = _slot(
		"own:active",
		SLITHER_WING_UID,
		1,
		140,
		0,
		[_energy("F"), _energy("F")]
	)
	observation["own"]["bench"] = [
		_slot(
			"own:bench:liability",
			RAGING_BOLT_EX_UID,
			2,
			240,
			210,
			[_energy("L"), _energy("F")]
		),
	]
	var snapshot: Dictionary = PrizeClockSolverScript.new().solve(
		observation,
		_facts(true, false, 0),
		_profile()
	)
	_check(
		bool(snapshot.get("opponent_wins_next_window", false)),
		"a credible gust onto a public 30HP two-prizer must count as an opponent next-window win even when our Active gives one Prize"
	)
	observation["public_response_evidence"] = {
		"gust_exhausted": true,
		"source": "public_supporter_quota",
	}
	var exhausted: Dictionary = PrizeClockSolverScript.new().solve(
		observation,
		_facts(true, false, 0),
		_profile()
	)
	_check(
		not bool(exhausted.get("opponent_wins_next_window", true)),
		"the same bench liability must stop being a forced next-window loss after public gust exhaustion"
	)


func _test_gust_guard_binds_the_exact_public_lethal_target() -> void:
	var observation := _observation()
	observation["opponent"]["bench"] = [
		_slot("opponent:bench:lethal", "TARGET_SMALL", 1, 30, 0, []),
		_slot("opponent:bench:large", "TARGET_EX", 2, 220, 0, []),
	]
	var gust := _candidate(
		"candidate:gust",
		"route:gust",
		"play_trainer",
		"trainer:gust",
		100.0,
		true
	)
	var filtered := HardGuardScript.new().filter_candidates(
		[gust],
		observation,
		_facts(true, false, 60),
		{
			"safety": {
				"require_payable_ko_before_gust": true,
			},
		}
	)
	var allowed: Array = filtered.get("candidates", [])
	var constraint: Dictionary = allowed[0].get(
		"hard_guard_target_constraint",
		{}
	) if not allowed.is_empty() and allowed[0] is Dictionary else {}
	_check(
		allowed.size() == 1
			and constraint.get("eligible_slot_ids", [])
				== ["opponent:bench:lethal"]
			and int(constraint.get("max_damage", 0)) == 60,
		"a payable-gust proof must bind execution to the exact public lethal target instead of merely proving that some target exists"
	)


func _test_non_ko_pressure_does_not_claim_a_current_window_prize() -> void:
	var observation := _observation()
	observation["own"]["prizes_remaining"] = 1
	var snapshot: Dictionary = PrizeClockSolverScript.new().solve(
		observation,
		_facts(true, false, 70),
		_profile()
	)
	_check(
		int(snapshot.get("own", {}).get("robust", {}).get(
			"finish_tick",
			-1
		)) == 2,
		"a ready pressure attack without a public KO must not claim a prize at tick 0"
	)


func _test_global_base_module_preserves_rule_scores() -> void:
	var registry = CapabilityRegistryScript.new()
	var observation := _observation()
	var frontier: Array[Dictionary] = [
		_attack_candidate("attack:ko", 900.0, true, 120, true),
		_retreat_candidate("retreat:slither", "own:bench:0", -100000.0, false),
	]
	var annotated := registry.annotate_frontier_post_completion(
		frontier,
		observation,
		_facts(true, true, 120),
		_profile(),
		{}
	)
	_check(
		float(annotated[0].get("base_score", 0.0)) == 900.0
			and int(annotated[0].get("rule_order", -1)) == 0
			and float(annotated[1].get("base_score", 0.0)) == -100000.0
			and int(annotated[1].get("rule_order", -1)) == 1,
		"Base graph annotation must never rewrite exact Rule scores or order"
	)
	_check(
		_module_annotation(annotated[0]).has("baseline_clock")
			and _module_annotation(annotated[1]).has("candidate_clock"),
		"the prize-clock Base module must be inherited even when a profile declares no module"
	)


func _test_credible_gust_keeps_retreat_as_non_certified_denial() -> void:
	var registry = CapabilityRegistryScript.new()
	var observation := _observation()
	var local_top := _attack_candidate("attack:ko", 900.0, true, 120, true)
	var selected := _retreat_candidate(
		"retreat:slither",
		"own:bench:0",
		-100000.0,
		false
	)
	var annotated := registry.annotate_frontier_post_completion(
		[local_top, selected],
		observation,
		_facts(true, true, 120),
		_profile(),
		{}
	)
	var pivot := _module_annotation(annotated[1])
	var verification := registry.verify_route_advantage(
		annotated[1],
		annotated[0],
		_facts(true, true, 120),
		_profile()
	)
	_check(
		str(pivot.get("prize_denial", {}).get("level", "")) == "credible"
			and bool(pivot.get("prize_denial", {}).get(
				"retreated_liability_remains_gust_exposed",
				false
			)),
		"a damaged two-prizer moved to the Bench is only a credible denial while gust remains credible"
	)
	_check(
		not bool(verification.get("verified", false)),
		"credible gust uncertainty must block a deterministic prize-denial certificate"
	)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile(), {})
	_check(
		strategy._find_module_verified_upgrade(
			annotated,
			_facts(true, true, 120)
		).is_empty(),
		"credible denial may inform the model but must not seize local execution ownership"
	)


func _test_public_gust_exhaustion_can_certify_one_prize_bridge() -> void:
	var registry = CapabilityRegistryScript.new()
	var observation := _observation()
	observation["public_response_evidence"] = {
		"gust_exhausted": true,
		"source": "configured_known_deck_all_gust_public",
	}
	var local_top := _attack_candidate("attack:ko", 900.0, true, 120, true)
	var selected := _retreat_candidate(
		"retreat:slither",
		"own:bench:0",
		-100000.0,
		false
	)
	var annotated := registry.annotate_frontier_post_completion(
		[local_top, selected],
		observation,
		_facts(true, true, 120),
		_profile(),
		{}
	)
	var pivot := _module_annotation(annotated[1])
	var verification := registry.verify_route_advantage(
		annotated[1],
		annotated[0],
		_facts(true, true, 120),
		_profile()
	)
	_check(
		str(pivot.get("prize_denial", {}).get("level", "")) == "forced"
			and bool(pivot.get("same_attack_window", {}).get("ko_ready", false)),
		"publicly exhausted gust plus a paid 120-damage Slither Wing must form a forced one-prize bridge"
	)
	_check(
		bool(verification.get("verified", false))
			and str(verification.get("certificate_kind", "")) == "public_prize_denial_pivot",
		"the forced bridge must mint the narrow public prize-denial certificate"
	)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile(), {})
	var production_upgrade: Dictionary = strategy._find_module_verified_upgrade(
		annotated,
		_facts(true, true, 120)
	)
	_check(
		str(production_upgrade.get("safe_prefix_action_id", "")) == "retreat:slither"
			and str(production_upgrade.get("verified_reason", ""))
				== "module_verified_advantage",
		"the production safety path must execute the exact certified retreat despite the Rule score gap"
	)


func _test_raging_bolt_extension_operators_and_clock_effects() -> void:
	var registry = CapabilityRegistryScript.new()
	var observation := _observation()
	var facts := _facts(true, true, 120)
	facts["continuity"] = {
		"enabled": true,
		"floor_met": false,
		"debt_count": 2,
		"review_before_terminal": true,
	}
	var noctowl := _candidate(
		"candidate:noctowl",
		"route:noctowl_search",
		"evolve",
		"evolve:noctowl",
		500.0,
		false
	)
	noctowl["action_ref"] = {
		"kind": "evolve",
		"card": {"uid": NOCTOWL_UID},
		"target": "own:bench:1",
	}
	noctowl["post_attack_continuity"] = {
		"reduces_debt": true,
		"debt_reduction_count": 2,
		"debt_types": ["search_engine_activation", "banked_damage_units"],
		"frontier_priority": true,
	}
	var area_zero := _candidate(
		"candidate:area-zero",
		"route:stadium",
		"play_stadium",
		"stadium:area-zero",
		450.0,
		false
	)
	area_zero["action_ref"] = {
		"kind": "play_stadium",
		"card": {"uid": AREA_ZERO_UID},
	}
	area_zero["post_attack_continuity"] = {
		"reduces_debt": false,
		"debt_reduction_count": 0,
	}
	var annotated := registry.annotate_frontier_post_completion(
		[noctowl, area_zero],
		observation,
		facts,
		_profile(),
		{}
	)
	var noctowl_graph := _module_annotation(annotated[0])
	var stadium_graph := _module_annotation(annotated[1])
	_check(
		"RB_BUILD_NOCTOWL_ENGINE" in noctowl_graph.get("extension_operators", [])
			and bool(noctowl_graph.get("candidate_clock", {}).get(
				"continuity_floor_met_after",
				false
			))
			and int(noctowl_graph.get("candidate_clock", {}).get(
				"own_robust_finish_tick",
				99
			)) < int(noctowl_graph.get("baseline_clock", {}).get(
				"own_robust_finish_tick",
				-1
			)),
		"Noctowl debt closure must be represented as a robust prize-clock improvement"
	)
	_check(
		"RB_EXPAND_AREA_ZERO_CAPACITY" in stadium_graph.get("extension_operators", [])
			and str(stadium_graph.get("route_warning", "")) == "capacity_without_immediate_engine_chain",
		"Area Zero without a public immediate engine chain must be explained as non-productive capacity"
	)


func _test_terminal_win_remains_lexicographically_first() -> void:
	var registry = CapabilityRegistryScript.new()
	var observation := _observation()
	observation["own"]["prizes_remaining"] = 2
	observation["opponent"]["active"]["prize_count"] = 2
	var win_now := _attack_candidate("attack:terminal", 900.0, true, 210, true)
	win_now["outcome"]["prizes_now"] = 2
	win_now["outcome"]["win_now"] = true
	var develop := _candidate(
		"candidate:develop",
		"route:noctowl_search",
		"evolve",
		"evolve:noctowl",
		800.0,
		false
	)
	var annotated := registry.annotate_frontier_post_completion(
		[win_now, develop],
		observation,
		_facts(true, true, 210),
		_profile(),
		{}
	)
	var validation := registry.validate_route_switch(
		annotated[1],
		annotated[0],
		_facts(true, true, 210),
		_profile()
	)
	_check(
		not bool(validation.get("valid", true))
			and str(validation.get("reason", "")) == "prize_clock_win_now_is_invariant",
		"no development or pivot route may override an exact immediate win"
	)


func _test_bloodmoon_and_single_prize_routes_are_explained() -> void:
	var registry = CapabilityRegistryScript.new()
	var observation := _observation()
	observation["own"]["bench"].append(
		_slot("own:bench:3", BLOODMOON_EX_UID, 2, 240, 0, [_energy("C")])
	)
	var bloodmoon := _retreat_candidate(
		"retreat:bloodmoon",
		"own:bench:3",
		200.0,
		true
	)
	var single_bolt := _retreat_candidate(
		"retreat:single-bolt",
		"own:bench:2",
		190.0,
		false
	)
	var annotated := registry.annotate_frontier_post_completion(
		[bloodmoon, single_bolt],
		observation,
		_facts(false, false, 0),
		_profile(),
		{}
	)
	_check(
		"RB_BLOODMOON_DYNAMIC_CLOSEOUT" in _module_annotation(
			annotated[0]
		).get("extension_operators", []),
		"Bloodmoon pivot must be connected to the dynamic opponent-prize cost operator"
	)
	_check(
		"RB_SINGLE_PRIZE_RAGING_BOLT_ROUTE" in _module_annotation(
			annotated[1]
		).get("extension_operators", []),
		"single-prize Raging Bolt must be exposed as a distinct prize-clock route"
	)


func _test_dynamic_bloodmoon_pivot_ko_prevents_rule_end_turn() -> void:
	var observation := _observation()
	observation["own"]["prizes_remaining"] = 4
	observation["own"]["active"] = _slot(
		"own:active",
		TEAL_MASK_OGERPON_EX_UID,
		2,
		210,
		0,
		[_energy("G")]
	)
	observation["own"]["active"]["retreat_cost"] = 1
	observation["own"]["bench"].append(
		_slot(
			"own:bench:bloodmoon",
			BLOODMOON_EX_UID,
			2,
			260,
			0,
			[_energy("L")]
		)
	)
	observation["opponent"]["prizes_remaining"] = 2
	observation["opponent"]["active"] = _slot(
		"opponent:active",
		"CSV9C_129",
		2,
		230,
		0,
		[]
	)
	observation["legal_actions"] = [{
		"id": "retreat:to-bloodmoon",
		"kind": "retreat",
		"source": "own:active",
		"target": "own:bench:bloodmoon",
	}, {
		"id": "end:rule",
		"kind": "end_turn",
	}]
	var rule_end := _candidate(
		"candidate:rule-end",
		"route:end_turn",
		"end_turn",
		"end:rule",
		1000.0,
		true
	)
	rule_end["action_ref"] = observation["legal_actions"][1]
	var pivot := _retreat_candidate(
		"retreat:to-bloodmoon",
		"own:bench:bloodmoon",
		-100000.0,
		false
	)
	var facts := _facts(false, false, 0)
	var registry = CapabilityRegistryScript.new()
	var annotated := registry.annotate_frontier(
		[rule_end, pivot],
		observation,
		facts,
		_profile(),
		{}
	)
	annotated = registry.annotate_frontier_post_completion(
		annotated,
		observation,
		facts,
		_profile(),
		{}
	)
	var pivot_graph := _module_annotation(annotated[1])
	var same_window: Dictionary = pivot_graph.get("same_attack_window", {}) \
		if pivot_graph.get("same_attack_window", {}) is Dictionary else {}
	var verification := registry.verify_route_advantage(
		annotated[1],
		annotated[0],
		facts,
		_profile()
	)
	_check(
		bool(same_window.get("attack_ready", false))
			and bool(same_window.get("ko_ready", false))
			and str(same_window.get("proof_kind", ""))
				== "public_dynamic_attack_cost_after_pivot"
			and int(same_window.get("projected_damage", 0)) == 240
			and int(same_window.get("target_remaining_hp", 0)) == 230,
		"the Base graph must compose the paid dynamic cost with the exact retreat and 240-to-230 KO"
	)
	_check(
		bool(verification.get("verified", false))
			and str(verification.get("certificate_kind", ""))
				== "public_same_window_pivot_ko_loss_prevention",
		"a public same-window pivot KO must own execution over a Rule end turn when the opponent wins next window"
	)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile(), {})
	var production_upgrade: Dictionary = strategy._find_module_verified_upgrade(
		annotated,
		facts
	)
	_check(
		str(production_upgrade.get("safe_prefix_action_id", ""))
				== "retreat:to-bloodmoon"
			and strategy._can_apply_initial_module_upgrade(production_upgrade),
		"the production selector must execute the retreat on both initial and reobserved decision windows"
	)

	var short_observation := observation.duplicate(true)
	short_observation["opponent"]["prizes_remaining"] = 3
	var short_annotated := registry.annotate_frontier(
		[rule_end, pivot],
		short_observation,
		facts,
		_profile(),
		{}
	)
	short_annotated = registry.annotate_frontier_post_completion(
		short_annotated,
		short_observation,
		facts,
		_profile(),
		{}
	)
	var short_verification := registry.verify_route_advantage(
		short_annotated[1],
		short_annotated[0],
		facts,
		_profile()
	)
	_check(
		not bool(short_verification.get("verified", false)),
		"one Energy must not certify Bloodmoon while the opponent still has three Prizes"
	)

	var high_hp_observation := observation.duplicate(true)
	high_hp_observation["opponent"]["active"]["remaining_hp"] = 241
	high_hp_observation["opponent"]["active"]["max_hp"] = 241
	var high_hp_annotated := registry.annotate_frontier(
		[rule_end, pivot],
		high_hp_observation,
		facts,
		_profile(),
		{}
	)
	high_hp_annotated = registry.annotate_frontier_post_completion(
		high_hp_annotated,
		high_hp_observation,
		facts,
		_profile(),
		{}
	)
	var high_hp_verification := registry.verify_route_advantage(
		high_hp_annotated[1],
		high_hp_annotated[0],
		facts,
		_profile()
	)
	_check(
		not bool(high_hp_verification.get("verified", false)),
		"240 damage must not certify a pivot KO into a 241HP target"
	)


func _test_raging_initial_typed_completion_cannot_reorder_supporter_before_rule() -> void:
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile(), {})
	var unsafe_upgrade := {
		"route_id": "route:accelerate",
		"action_kind": "play_trainer",
		"verified_advantage": {
			"certificate_kind": "public_typed_attack_cost_completion",
		},
	}
	var exact_attachment := {
		"route_id": "route:energy_commit",
		"action_kind": "attach_energy",
		"verified_advantage": {
			"certificate_kind": "public_typed_attack_cost_completion",
		},
	}
	_check(
		not strategy._can_apply_initial_module_upgrade(unsafe_upgrade),
		"Raging Bolt must not use an attack-cost certificate to reorder Crispin before the Rule attachment"
	)
	_check(
		strategy._can_apply_initial_module_upgrade(exact_attachment),
		"the narrow exact attachment completion must remain eligible"
	)


func _test_supporter_acceleration_cannot_cross_exact_rule_attachment() -> void:
	var profile := _profile()
	profile["post_attack_continuity"] = {
		"enabled": true,
		"review_during_main_phase": true,
		"minimum_banked_damage_units": 99,
	}
	var strategy = StrategyScript.new()
	strategy.configure_profile(profile, {})
	var exact_attachment := _candidate(
		"candidate:rule-attachment",
		"route:energy_commit",
		"attach_energy",
		"energy:manual-fighting",
		1000.0,
		true
	)
	var supporter_acceleration := _candidate(
		"candidate:crispin",
		"route:accelerate",
		"play_trainer",
		"trainer:crispin",
		900.0,
		false
	)
	supporter_acceleration["action_semantic_roles"] = [
		"supporter_acceleration",
		"energy_access",
	]
	var frontier: Array[Dictionary] = [
		exact_attachment,
		supporter_acceleration,
	]
	var completion: Dictionary = strategy._completion_override_for_rule_root(
		frontier,
		_facts(true, false, 70),
		_observation()
	)
	_check(
		not bool(completion.get("handled", false)),
		"a search/RNG-bearing Supporter acceleration must not cross the exact Rule manual attachment"
	)


func _test_completion_prefix_cannot_cross_information_checkpoint() -> void:
	var profile := _profile()
	profile["post_attack_continuity"] = {
		"enabled": true,
		"review_during_main_phase": true,
		"minimum_banked_damage_units": 99,
	}
	var strategy = StrategyScript.new()
	strategy.configure_profile(profile, {})
	var vessel := _candidate(
		"candidate:rule-vessel",
		"route:information",
		"play_trainer",
		"trainer:earthen-vessel",
		1000.0,
		true
	)
	vessel["checkpoint_after"] = "information_result"
	var supporter_acceleration := _candidate(
		"candidate:crispin-after-vessel",
		"route:accelerate",
		"play_trainer",
		"trainer:crispin",
		900.0,
		false
	)
	supporter_acceleration["action_semantic_roles"] = [
		"supporter_acceleration",
		"energy_access",
	]
	var frontier: Array[Dictionary] = [
		vessel,
		supporter_acceleration,
	]
	var completion: Dictionary = strategy._completion_override_for_rule_root(
		frontier,
		_facts(true, false, 70),
		_observation()
	)
	_check(
		not bool(completion.get("handled", false)),
		"a completion prefix must replan after the exact Rule information checkpoint instead of crossing it"
	)


func _test_raging_route_suffix_survives_model_compaction() -> void:
	var observation := _observation()
	var candidate := _candidate(
		"candidate:noctowl",
		"route:noctowl_search",
		"use_ability",
		"ability:noctowl",
		100.0,
		true
	)
	candidate["checkpoint_after"] = "information_result"
	candidate["action_ref"] = {
		"kind": "use_ability",
		"source": "own:bench:1",
		"source_card": {"uid": NOCTOWL_UID},
	}
	candidate["post_attack_continuity"] = {
		"progresses_debt": true,
		"planned_debt_types": [
			"search_engine_root",
			"banked_damage_units",
		],
		"requires_reobservation": true,
	}
	var annotated := CapabilityRegistryScript.new().annotate_frontier_post_completion(
		[candidate],
		observation,
		_facts(true, true, 100),
		_profile(),
		{}
	)
	var suffix: Dictionary = annotated[0].get("conditional_suffix", {}) \
		if not annotated.is_empty() else {}
	var strategy = StrategyScript.new()
	var compact: Array = strategy._compact_frontier_for_model(annotated)
	var transported: Dictionary = compact[0].get("conditional_suffix", {}) \
		if not compact.is_empty() else {}
	_check(
		str(suffix.get("kind", "")) == "raging_bolt_continuity_route"
			and bool(suffix.get("requires_reobservation", false))
			and transported == suffix,
		"Raging Bolt candidates must carry a typed cross-checkpoint suffix all the way to the model frontier"
	)


func _test_local_prize_clock_planning_stays_within_budget() -> void:
	var registry = CapabilityRegistryScript.new()
	var observation := _observation()
	var facts := _facts(true, true, 120)
	var frontier: Array[Dictionary] = [
		_attack_candidate("attack:ko", 900.0, true, 120, true),
		_retreat_candidate(
			"retreat:slither",
			"own:bench:0",
			-100000.0,
			false
		),
	]
	var samples: Array[int] = []
	for _iteration: int in 200:
		var started := Time.get_ticks_usec()
		registry.annotate_frontier_post_completion(
			frontier,
			observation,
			facts,
			_profile(),
			{}
		)
		samples.append(Time.get_ticks_usec() - started)
	samples.sort()
	var p95_usec := samples[ceili(float(samples.size()) * 0.95) - 1]
	_planning_p95_usec = p95_usec
	_check(
		p95_usec <= 15000,
		"shared prize-clock plus Raging extension p95 must stay within 15ms, got %dus"
			% p95_usec
	)


func _profile() -> Dictionary:
	return {
		"deck_id": 800018509,
		"modules": [],
		"prize_clock_extension": {
			"kind": "raging_bolt",
			"free_retreat_enabler_uids": [LATIAS_EX_UID],
			"area_zero_uid": AREA_ZERO_UID,
			"noctowl_uids": [NOCTOWL_UID],
			"raging_bolt_ex_uids": [RAGING_BOLT_EX_UID],
			"bloodmoon_uids": [BLOODMOON_EX_UID],
			"bloodmoon_damage": 240,
			"one_prize_attackers": {
				SLITHER_WING_UID: {
					"operator": "RB_ONE_PRIZE_SLITHER_WING_BRIDGE",
					"required_energy": ["F", "F"],
					"damage": 120,
					"self_damage": 90,
				},
				RAGING_BOLT_UID: {
					"operator": "RB_SINGLE_PRIZE_RAGING_BOLT_ROUTE",
					"required_energy": ["L", "F", "C"],
					"damage": 130,
				},
			},
		},
	}


func _observation() -> Dictionary:
	return {
		"own": {
			"prizes_remaining": 3,
			"active": _slot(
				"own:active",
				RAGING_BOLT_EX_UID,
				2,
				240,
				170,
				[_energy("L"), _energy("F")]
			),
			"bench": [
				_slot(
					"own:bench:0",
					SLITHER_WING_UID,
					1,
					140,
					0,
					[_energy("F"), _energy("F")]
				),
				_slot("own:bench:1", NOCTOWL_UID, 1, 100, 0, []),
				_slot(
					"own:bench:2",
					RAGING_BOLT_UID,
					1,
					130,
					0,
					[_energy("L"), _energy("F"), _energy("C")]
				),
				_slot("own:bench:latias", LATIAS_EX_UID, 2, 210, 0, []),
			],
			"hand": [],
			"deck_count": 20,
		},
		"opponent": {
			"prizes_remaining": 4,
			"active": _slot("opponent:active", "TARGET", 1, 100, 0, []),
			"bench": [
				_slot("opponent:bench:0", "TARGET_EX", 2, 220, 0, []),
			],
			"hand_count": 4,
			"deck_count": 20,
		},
		"stadium": {},
		"legal_actions": [],
	}


func _facts(attack_ready: bool, ko_available: bool, max_damage: int) -> Dictionary:
	return {
		"attack": {
			"ready": attack_ready,
			"ko_available": ko_available,
			"max_damage": max_damage,
		},
		"continuity": {
			"enabled": false,
			"floor_met": true,
			"debt_count": 0,
			"review_before_terminal": false,
		},
		"prize": {
			"current_swing": 1 if ko_available else 0,
			"win_now": false,
		},
	}


func _slot(
	slot_id: String,
	uid: String,
	prize_count: int,
	max_hp: int,
	damage: int,
	energy: Array
) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid},
		"prize_count": prize_count,
		"max_hp": max_hp,
		"remaining_hp": maxi(0, max_hp - damage),
		"damage": damage,
		"retreat_cost": 3,
		"energy": energy.duplicate(true),
		"energy_count": energy.size(),
	}


func _energy(symbol: String) -> Dictionary:
	return {
		"uid": "ENERGY_%s" % symbol,
		"type": "Basic Energy",
		"energy_type": symbol,
		"energy_provides": symbol,
	}


func _attack_candidate(
	action_id: String,
	score: float,
	knockout: bool,
	damage: int,
	rule_floor: bool
) -> Dictionary:
	var candidate := _candidate(
		"candidate:%s" % action_id,
		"route:attack_ko" if knockout else "route:attack_pressure",
		"attack",
		action_id,
		score,
		rule_floor
	)
	candidate["action_ref"] = {
		"kind": "attack",
		"source": "own:active",
		"target": "opponent:active",
		"source_card": {"uid": RAGING_BOLT_EX_UID},
		"projected_damage": damage,
		"projected_knockout": knockout,
		"attack_index": 1,
	}
	candidate["outcome"]["estimated_damage"] = damage
	candidate["outcome"]["prizes_now"] = 1 if knockout else 0
	return candidate


func _retreat_candidate(
	action_id: String,
	target: String,
	score: float,
	rule_floor: bool
) -> Dictionary:
	var candidate := _candidate(
		"candidate:%s" % action_id,
		"route:pivot",
		"retreat",
		action_id,
		score,
		rule_floor
	)
	candidate["action_ref"] = {
		"kind": "retreat",
		"source": "own:active",
		"target": target,
	}
	return candidate


func _candidate(
	candidate_id: String,
	route_id: String,
	action_kind: String,
	action_id: String,
	score: float,
	rule_floor: bool
) -> Dictionary:
	return {
		"candidate_id": candidate_id,
		"route_id": route_id,
		"action_kind": action_kind,
		"safe_prefix_action_id": action_id,
		"base_score": score,
		"local_score": score,
		"rule_order": 0 if rule_floor else 1,
		"engine_rule_floor_exact": rule_floor,
		"action_ref": {"kind": action_kind},
		"outcome": {
			"win_now": false,
			"prizes_now": 0,
			"estimated_damage": 0,
		},
		"module_annotations": {},
	}


func _module_annotation(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	return annotations.get("prize_clock_pivot", {}) \
		if annotations.get("prize_clock_pivot", {}) is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
