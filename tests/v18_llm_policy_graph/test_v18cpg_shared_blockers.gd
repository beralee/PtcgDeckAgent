extends SceneTree

const AuditScript = preload("res://scripts/ai/v18_cpg/audit/V18CPGDecisionAudit.gd")
const OptimizationVerifierScript = preload("res://scripts/tools/v18cpg/verify_21_deck_10_round_optimization.gd")
const EnergySymbolsScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGEnergySymbols.gd")
const EnergyBurstScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGEnergyBurst.gd")
const StrategicShapeScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGStrategicShapeModule.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")
const PolicyValidatorScript = preload("res://scripts/ai/v18_cpg/policy/V18CPGPolicyValidator.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_all_energy_symbols_share_one_alphabet()
	_test_profiled_typed_attachment_certificate()
	_test_knockout_outcome_uses_public_prize_count()
	_test_deterministic_attack_upgrade_preserves_pre_attack_actions()
	_test_direct_verified_selection_is_idempotent()
	_test_audit_payload_capture_is_explicit()
	_test_model_action_result_ownership_controls_reference_gate()
	_test_typed_route_redundant_id_is_canonicalized()
	_test_model_frontier_compaction_preserves_decision_evidence()
	_test_baseline_can_ignore_profile_override_without_file_mutation()
	_test_wait_budget_fallback_preserves_rejection_ownership()
	_test_energy_burst_uses_profiled_damage_resource_zone()
	_test_autonomous_typed_completion_requires_rule_end_and_active()
	if _failures.is_empty():
		print("V18CPG shared blocker suite: PASS (13 groups)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_all_energy_symbols_share_one_alphabet() -> void:
	var expected := {
		"Grass Energy": "G",
		"Fire Energy": "R",
		"Water Energy": "W",
		"Lightning Energy": "L",
		"Psychic Energy": "P",
		"Fighting Energy": "F",
		"Darkness Energy": "D",
		"Metal Energy": "M",
		"Colorless Energy": "C",
		"Dragon Energy": "N",
	}
	for raw_name: Variant in expected.keys():
		var name := str(raw_name)
		_check(
			EnergySymbolsScript.canonical(name) == str(expected[name]),
			"energy symbol normalizer lost %s" % name
		)
	var module := EnergyBurstScript.new()
	var snapshot := module.visible_energy_snapshot({
		"own": {
			"active": {
				"slot_id": "slot:dragapult",
				"pokemon": {"uid": "DRAGAPULT"},
				"energy": [
					{"energy_type": "R", "semantic_roles": ["basic_energy"]},
					{"energy_type": "P", "semantic_roles": ["basic_energy"]},
				],
			},
			"bench": [],
		},
	}, {"module_parameters": {"energy_burst": {"primary_attack_required_types": ["R", "P"]}}})
	_check(bool(snapshot.get("primary_cost_ready", false)), "EnergyBurst must recognize Fire+Psychic typed costs")
	_check(int(snapshot.get("by_type", {}).get("R", 0)) == 1, "Fire energy must not collapse to other")
	_check(int(snapshot.get("by_type", {}).get("P", 0)) == 1, "Psychic energy must not collapse to other")


func _test_profiled_typed_attachment_certificate() -> void:
	var module := StrategicShapeScript.new()
	module.configure("stage2_chain")
	var profile := {
		"module_parameters": {
			"stage2_chain": {
				"attack_cost_by_uid": {"DRAGAPULT": ["R", "P"]},
			},
		},
	}
	var observation := {
		"turn": {"deterministic_attack_window_open": true},
		"own": {
			"active": {
				"slot_id": "slot:dragapult",
				"pokemon": {"uid": "DRAGAPULT"},
				"energy": [{"energy_type": "R"}],
			},
			"bench": [{
				"slot_id": "slot:dusknoir",
				"pokemon": {"uid": "DUSKNOIR"},
				"energy": [],
			}],
		},
		"opponent": {"active": {}, "bench": []},
	}
	var frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:rule_search",
		"route_id": "route:information",
		"action_kind": "play_trainer",
		"action_ref": {"card": {"uid": "PUBLIC_SEARCH"}},
		"base_score": 100.0,
	}, {
		"candidate_id": "candidate:dragapult",
		"route_id": "route:energy_commit",
		"action_kind": "attach_energy",
		"action_ref": {"target": "slot:dragapult", "card": {"energy_type": "P"}},
		"base_score": 90.0,
	}]
	var annotated := module.annotate_frontier_v2(frontier, observation, {}, profile, {})
	var certificate := module.verify_route_advantage(annotated[1], annotated[0], {}, profile)
	_check(bool(certificate.get("verified", false)), "typed attachment must certify completing a profiled attack cost")
	_check(
		bool(annotated[1].get("module_annotations", {}).get("stage2_chain", {}).get("typed_attachment", {}).get("target_is_active", false)),
		"typed attachment evidence must identify the current Active slot"
	)
	_check(
		str(certificate.get("certificate_kind", "")) == "public_typed_attack_cost_completion",
		"typed attachment certificate kind must remain explicit"
	)


func _test_knockout_outcome_uses_public_prize_count() -> void:
	var route_search := RouteSearchScript.new()
	var observation := {
		"own": {"prizes_remaining": 2},
		"opponent": {"active": {"prize_count": 1}},
		"legal_actions": [{
			"id": "action:single_prize_ko",
			"kind": "attack",
			"projected_damage": 70,
			"projected_knockout": true,
		}],
	}
	var frontier: Array[Dictionary] = route_search.build_frontier(
		observation,
		{"action:single_prize_ko": 100.0},
		{},
		{"resources": {"prizes_remaining": 2}},
		8
	)
	var outcome: Dictionary = frontier[0].get("outcome", {})
	_check(int(outcome.get("prizes_now", 0)) == 1, "a single-prize KO must not be fabricated as two prizes")
	_check(not bool(outcome.get("win_now", true)), "a single-prize KO with two prizes left must not fabricate a win")
	observation["own"]["prizes_remaining"] = 1
	frontier = route_search.build_frontier(
		observation,
		{"action:single_prize_ko": 100.0},
		{},
		{"resources": {"prizes_remaining": 1}},
		8
	)
	_check(bool(frontier[0].get("outcome", {}).get("win_now", false)), "the same public KO must become terminal with one prize left")


func _test_deterministic_attack_upgrade_preserves_pre_attack_actions() -> void:
	var strategy := StrategyScript.new()
	var frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:rule",
		"route_id": "route:evolve",
		"action_kind": "evolve",
		"base_score": 100.0,
		"outcome": {"win_now": false, "prizes_now": 0},
	}, {
		"candidate_id": "candidate:claimed_win",
		"route_id": "route:attack_ko",
		"action_kind": "attack",
		"base_score": 90.0,
		"outcome": {"win_now": true, "prizes_now": 2},
	}]
	var upgrade := strategy._find_module_verified_upgrade(frontier, {"resources": {"prizes_remaining": 2}})
	_check(
		upgrade.is_empty(),
		"a deterministic KO must not autonomously skip an evolve that can precede the attack"
	)
	var model_safety := strategy._validate_model_route_safety(
		"route:attack_ko",
		frontier,
		{"resources": {"prizes_remaining": 2}},
		"candidate:claimed_win"
	)
	_check(
		bool(model_safety.get("valid", false)) and str(model_safety.get("reason", "")) == "deterministic_win_now",
		"the deterministic attack proof must remain available to the model validation path"
	)
	frontier[0] = {
		"candidate_id": "candidate:end",
		"route_id": "route:end_turn",
		"action_kind": "end_turn",
		"base_score": 100.0,
		"outcome": {"win_now": false, "prizes_now": 0},
	}
	upgrade = strategy._find_module_verified_upgrade(frontier, {"resources": {"prizes_remaining": 2}})
	_check(
		str(upgrade.get("candidate_id", "")) == "candidate:claimed_win",
		"a deterministic public win may autonomously replace end_turn"
	)
	frontier[0] = {
		"candidate_id": "candidate:weaker_attack",
		"route_id": "route:attack_pressure",
		"action_kind": "attack",
		"base_score": 100.0,
		"outcome": {"win_now": false, "prizes_now": 0},
	}
	upgrade = strategy._find_module_verified_upgrade(frontier, {"resources": {"prizes_remaining": 2}})
	_check(
		str(upgrade.get("candidate_id", "")) == "candidate:claimed_win",
		"a deterministic public win may autonomously replace a weaker attack"
	)


func _test_direct_verified_selection_is_idempotent() -> void:
	var strategy := StrategyScript.new()
	strategy.set("_current_action_owner", "module_verified_upgrade")
	strategy.set("_preferred_candidate_id", "candidate:attack")
	strategy.set("_current_route_id", "route:attack_ko")
	strategy.set("_last_observation", {"observation_hash": "same"})
	var frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:attack",
		"route_id": "route:attack_ko",
		"safe_prefix_action_id": "action:attack",
		"base_score": 10.0,
	}]
	_check(
		bool(strategy.call("_can_reuse_direct_verified_selection", frontier, "same")),
		"a direct module-verified selection must survive the host's repeated prepare call"
	)


func _test_audit_payload_capture_is_explicit() -> void:
	var audit := AuditScript.new()
	audit.configure("shared_blocker_fixture", "no_files", false)
	audit.call("record_payload", {"event_type": "model_request", "request_envelope": {"frontier": [1]}})
	_check(audit.records().is_empty(), "full model payloads must stay disabled unless write-audit is explicit")
	audit.configure("shared_blocker_fixture", "with_files", true)
	audit.call("record_payload", {"event_type": "model_response_payload", "response": {"policy": {}}})
	var records := audit.records()
	_check(records.size() == 1, "write-audit must retain one exact model payload record")
	_check(records[0].get("response", {}) is Dictionary, "model response body must be reconstructable from audit")


func _test_model_action_result_ownership_controls_reference_gate() -> void:
	var audit := AuditScript.new()
	audit.configure("shared_blocker_fixture", "model_action_ownership", false)
	audit.record({
		"event_type": "policy_response",
		"accepted": true,
		"action_owner": "local_gate",
		"fallback_reason": "exact_rule_root_shadowed",
	})
	audit.record({
		"event_type": "action_result",
		"action_owner": "local_gate",
		"success": true,
	})
	var shadow_summary := audit.summary()
	_check(int(shadow_summary.get("model_accepted", 0)) == 1, "fixture must include one accepted shadow response")
	_check(
		int(shadow_summary.get("model_owned_action_results", -1)) == 0,
		"an accepted shadow response must not count a local-gate action as model-owned"
	)
	_check(
		AuditScript.should_compare_verified_local_reference(shadow_summary),
		"accepted shadow responses must still require verified-local decision-log equality"
	)
	audit.record({
		"event_type": "action_result",
		"action_owner": "policy_graph_branch",
		"success": false,
	})
	var owned_summary := audit.summary()
	_check(
		int(owned_summary.get("model_owned_action_results", 0)) == 1,
		"a failed model-owned action attempt must still count as model influence"
	)
	_check(
		not AuditScript.should_compare_verified_local_reference(owned_summary),
		"verified-local equality is not required after an actual model-owned action attempt"
	)
	_check(
		AuditScript.should_compare_verified_local_reference({"model_accepted": 0}) \
			and not AuditScript.should_compare_verified_local_reference({"model_accepted": 1}),
		"legacy audit summaries must retain the zero-acceptance fallback semantics"
	)
	_check(
		OptimizationVerifierScript._verified_reference_mismatches({
			"zero_model_action_reference_mismatches": 2,
			"zero_acceptance_reference_mismatches": 0,
		}) == 2,
		"new artifacts must be verified by model-action ownership even when the legacy gate passed"
	)
	_check(
		OptimizationVerifierScript._verified_reference_mismatches({
			"zero_acceptance_reference_mismatches": 0,
		}) == 0,
		"retained artifacts without model-action fields must remain readable through the legacy gate"
	)


func _test_typed_route_redundant_id_is_canonicalized() -> void:
	var response := {
		"policy": {
			"root_node_id": "node:root",
			"nodes": [{
				"node_id": "node:root",
				"kind": "route",
				"route_ref": {
					"mode": "propose_typed_route",
					"route_id": "route:invented_chain_name",
					"first_candidate_id": "candidate:evolve",
					"macro_actions": ["route:evolve", "route:energy_commit", "route:end_turn"],
				},
			}],
			"reservations": [],
			"interaction_policy_refs": {},
			"interaction_policies": [],
			"replan_if": [],
		},
	}
	var validation := PolicyValidatorScript.new().validate_response(
		response,
		["route:evolve", "route:energy_commit", "route:end_turn"],
		8,
		["candidate:evolve"],
		true
	)
	_check(bool(validation.get("valid", false)), "a redundant typed-route label must not discard an otherwise legal graph")
	var nodes: Array = validation.get("policy", {}).get("nodes", [])
	_check(
		nodes.size() == 1 \
			and str(nodes[0].get("route_ref", {}).get("route_id", "")) == "route:evolve",
		"typed route_id must canonicalize to its supplied first macro action"
	)


func _test_model_frontier_compaction_preserves_decision_evidence() -> void:
	var strategy := StrategyScript.new()
	var verbose: Array[Dictionary] = [{
		"candidate_id": "candidate:attach",
		"route_id": "route:energy_commit",
		"macro_action": "energy_commit",
		"action_kind": "attach_energy",
		"action_summary": "redundant summary",
		"action_ref": {
			"id": "large-engine-action-id",
			"kind": "attach_energy",
			"requires_interaction": false,
			"target": "slot:attacker",
			"card": {"uid": "ENERGY_P", "name": "Psychic Energy", "energy_type": "P", "effect_id": "redundant"},
			"source_card": {"uid": "", "name": "", "effect_id": ""},
		},
		"action_semantic_roles": ["typed_energy"],
		"dependencies": [],
		"reservations": [],
		"checkpoint_after": "action_resolved",
		"base_score": 10.0,
		"rule_order": 4,
		"outcome": {
			"win_now": false, "prizes_now": 0, "estimated_damage": 0,
			"attack_ready": false, "information_gain": 0.0,
			"expected_route_improvement": 0.0, "resource_commitment": 0.7,
			"board_commitment": 0.0, "board_development": 0.0,
			"future_flexibility": 0.3, "uncertainty": 0.2, "terminal": false,
		},
		"module_annotations": {"stage2_chain": {
			"module": "stage2_chain",
			"typed_attachment": {"completes_required_types": true, "target_uid": "DRAGAPULT"},
		}},
	}]
	var compact: Array[Dictionary] = strategy.call("_compact_frontier_for_model", verbose)
	_check(compact.size() == 1, "frontier compaction must retain every exact candidate")
	_check(
		str(compact[0].get("action_ref", {}).get("target", "")) == "slot:attacker" \
			and str(compact[0].get("action_ref", {}).get("card", {}).get("uid", "")) == "ENERGY_P",
		"frontier compaction must retain exact target and card identity"
	)
	_check(
		bool(compact[0].get("module_annotations", {}).get("stage2_chain", {}).get("typed_attachment", {}).get("completes_required_types", false)),
		"frontier compaction must retain the public capability certificate"
	)
	_check(
		JSON.stringify(compact).length() < JSON.stringify(verbose).length(),
		"model frontier must remove redundant and empty fields"
	)


func _test_baseline_can_ignore_profile_override_without_file_mutation() -> void:
	var optimized := ProfileCatalogScript.get_profile_for_deck(800017407, true)
	var baseline := ProfileCatalogScript.get_profile_for_deck(800017407, false)
	_check(int(optimized.get("profile_version", 0)) >= 2, "fixture deck must expose its optimization override")
	_check(int(baseline.get("profile_version", 0)) == 1, "baseline mode must reconstruct the immutable default profile")
	_check(
		str(baseline.get("strategy_id", "")) == str(optimized.get("strategy_id", "")),
		"ignoring an override must never change V18 strategy identity"
	)


func _test_wait_budget_fallback_preserves_rejection_ownership() -> void:
	var strategy := StrategyScript.new()
	var frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:rule",
		"route_id": "route:information",
		"base_score": 100.0,
	}]
	strategy.call("_install_wait_budget_fallback", frontier)
	_check(
		str(strategy.get("_current_action_owner")) == "deadline_fallback",
		"a wait-budget block after a rejected request must retain deadline-fallback ownership"
	)
	_check(
		str(strategy.get("_policy_graph").call("origin")) == "deadline_fallback",
		"wait-budget fallback must remain observationally equivalent to the rejected-response reference"
	)


func _test_energy_burst_uses_profiled_damage_resource_zone() -> void:
	var module := EnergyBurstScript.new()
	var observation := {
		"own": {
			"hand": [
				{"uid": "EM1", "type": "Basic Energy", "energy_type": "M"},
				{"uid": "EM2", "type": "Basic Energy", "energy_type": "M"},
				{"uid": "ESP", "type": "Special Energy", "energy_type": "M"},
			],
			"active": {
				"slot_id": "active",
				"pokemon": {"uid": "GHOLDENGO"},
				"energy": [
					{"type": "Basic Energy", "energy_type": "M"},
					{"type": "Basic Energy", "energy_type": "M"},
					{"type": "Basic Energy", "energy_type": "M"},
				],
			},
			"bench": [
				{"slot_id": "b1", "pokemon": {"uid": "P1"}, "energy": [{"type": "Basic Energy", "energy_type": "G"}]},
				{"slot_id": "b2", "pokemon": {"uid": "P2"}, "energy": [{"type": "Basic Energy", "energy_type": "G"}]},
				{"slot_id": "b3", "pokemon": {"uid": "P3"}, "energy": [{"type": "Basic Energy", "energy_type": "G"}]},
			],
			"deck_count": 20,
		},
		"opponent": {"active": {"slot_id": "oa", "remaining_hp": 200}, "bench": []},
		"legal_actions": [],
	}
	var hand_profile := {"module_parameters": {"energy_burst": {
		"burst_damage_mode": "hand_discard",
		"damage_per_discard": 50,
		"reserve_hand_energy_next_turn": 0,
	}}}
	var hand_resource: Dictionary = module.damage_resource_snapshot(observation, hand_profile, {}, 100)
	_check(
		str(hand_resource.get("resource_zone", "")) == "own_hand_basic_energy" \
			and int(hand_resource.get("raw_units", -1)) == 2 \
			and int(hand_resource.get("required_units", -1)) == 2,
		"Gholdengo damage math must count basic Energy in hand, never attached board Energy"
	)
	var hand_annotation: Dictionary = module.route_annotation(
		{"route_id": "route:attack_ko", "macro_action": "attack_ko"},
		{}, observation, {"attack": {"ready": true, "ko_available": true}}, hand_profile
	)
	var compact_hand: Dictionary = StrategyScript.new().call(
		"_compact_module_annotations", {"energy_burst": hand_annotation}
	).get("energy_burst", {})
	_check(
		str(compact_hand.get("damage_mode", "")) == "hand_discard" \
			and str(compact_hand.get("damage_resource_zone", "")) == "own_hand_basic_energy" \
			and compact_hand.get("damage_resource", {}) is Dictionary,
		"the compact model frontier must retain the exact public damage resource semantics"
	)
	var bench_profile := {"module_parameters": {"energy_burst": {
		"burst_damage_mode": "energized_bench_count",
		"base_damage": 80,
		"damage_per_energized_bench": 40,
		"bench_energy_type": "G",
	}}}
	var bench_resource: Dictionary = module.damage_resource_snapshot(observation, bench_profile, {}, 200)
	_check(
		str(bench_resource.get("resource_zone", "")) == "own_bench_pokemon_with_G_energy" \
			and int(bench_resource.get("raw_units", -1)) == 3 \
			and int(bench_resource.get("projected_public_damage", -1)) == 200,
		"Toedscruel damage math must count energized Bench Pokemon rather than Energy cards"
	)
	var none_profile := {"module_parameters": {"energy_burst": {"burst_damage_mode": "none"}}}
	var none_annotation: Dictionary = module.route_annotation(
		{"route_id": "route:attack_ko", "macro_action": "attack_ko"},
		{},
		observation,
		{"attack": {"ready": true, "ko_available": true}},
		none_profile
	)
	_check(
		not bool(none_annotation.get("damage_math_enabled", true)) \
			and not bool(none_annotation.get("ko_payable_with_reserve", true)) \
			and str(none_annotation.get("route_warning", "x")) == "",
		"fixed-damage or healing decks must not receive fabricated burst-KO warnings"
	)


func _test_autonomous_typed_completion_requires_rule_end_and_active() -> void:
	var module := StrategicShapeScript.new()
	module.configure("stage2_chain")
	var profile := {"module_parameters": {"stage2_chain": {
		"attack_cost_by_uid": {"ATTACKER": ["R", "P", "C"]},
	}}}
	var observation := {
		"own": {
			"active": {"slot_id": "a", "pokemon": {"uid": "ATTACKER"}, "energy": []},
			"bench": [],
		},
		"opponent": {"active": {}, "bench": []},
	}
	var frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:rule",
		"route_id": "route:information",
		"action_kind": "play_trainer",
		"base_score": 100.0,
	}, {
		"candidate_id": "candidate:progress_only",
		"route_id": "route:energy_commit",
		"action_kind": "attach_energy",
		"action_ref": {"target": "a", "card": {"energy_type": "R"}},
		"base_score": 90.0,
	}]
	var progress := module.annotate_frontier_v2(frontier, observation, {}, profile, {})
	_check(
		not bool(module.verify_route_advantage(progress[1], progress[0], {}, profile).get("verified", false)),
		"adding one required type without completing the attack cost must not mint a dominance certificate"
	)
	var strategy := StrategyScript.new()
	var selected := {
		"candidate_id": "candidate:complete",
		"route_id": "route:energy_commit",
		"action_kind": "attach_energy",
		"module_annotations": {"stage2_chain": {"typed_attachment": {
			"completes_required_types": true,
			"target_is_active": true,
			"deterministic_attack_window_open": true,
			"autonomous_same_quota_completion": true,
		}}},
	}
	var top_attack := {"candidate_id": "candidate:attack", "route_id": "route:attack_pressure"}
	var top_search := {"candidate_id": "candidate:search", "route_id": "route:information"}
	var top_end := {"candidate_id": "candidate:end", "route_id": "route:end_turn"}
	var top_attachment := {
		"candidate_id": "candidate:rule_attachment",
		"route_id": "route:energy_commit",
		"action_kind": "attach_energy",
		"engine_rule_floor_exact": true,
	}
	var safety := {"advantage": {"certificate_kind": "public_typed_attack_cost_completion"}}
	_check(
		not bool(strategy.call(
			"_can_apply_autonomous_module_upgrade",
			selected, top_attack, {"attack": {"ready": true}}, safety
		)),
		"a non-terminal module certificate must never autonomously preempt the executable Rule attack"
	)
	_check(
		not bool(strategy.call(
			"_can_apply_autonomous_module_upgrade",
			selected, top_search, {"attack": {"ready": false}}, safety
		)),
		"an Active cost completion must remain model-owned when Rule top is public search"
	)
	var bench_selected: Dictionary = selected.duplicate(true)
	bench_selected["candidate_id"] = "candidate:bench_complete"
	bench_selected["module_annotations"]["stage2_chain"]["typed_attachment"]["target_is_active"] = false
	_check(
		not bool(strategy.call(
			"_can_apply_autonomous_module_upgrade",
			bench_selected, top_end, {"attack": {"ready": false}}, safety
		)),
		"completing a Benched attacker's cost must never autonomously rewrite Rule"
	)
	_check(
		bool(strategy.call(
			"_can_apply_autonomous_module_upgrade",
			selected, top_end, {"attack": {"ready": false}}, safety
		)),
		"Active immediate cost completion may act autonomously when Rule would end the turn"
	)
	strategy.configure_profile({"safety": {"max_switch_gap": 20.0}})
	var same_quota_safety := safety.duplicate(true)
	same_quota_safety["score_gap"] = 10.0
	_check(
		bool(strategy.call(
			"_can_apply_autonomous_module_upgrade",
			selected, top_attachment, {"attack": {"ready": false, "ko_available": false}}, same_quota_safety
		)),
		"Active exact cost completion may replace Rule only when both consume the same attachment quota"
	)
	var locked_selected := selected.duplicate(true)
	locked_selected["module_annotations"]["stage2_chain"]["typed_attachment"]["deterministic_attack_window_open"] = false
	_check(
		not bool(strategy.call(
			"_can_apply_autonomous_module_upgrade",
			locked_selected, top_attachment, {"attack": {"ready": false, "ko_available": false}}, same_quota_safety
		)),
		"a closed deterministic attack window must block autonomous cost completion"
	)
	var over_margin := same_quota_safety.duplicate(true)
	over_margin["score_gap"] = 20.01
	_check(
		not bool(strategy.call(
			"_can_apply_autonomous_module_upgrade",
			selected, top_attachment, {"attack": {"ready": false, "ko_available": false}}, over_margin
		)),
		"same-quota cost completion must remain inside the configured switch margin"
	)
	var certified_rule_attachment := top_attachment.duplicate(true)
	certified_rule_attachment["module_annotations"] = {
		"damage_counter_control": {
			"verified_advantage": true,
			"verified_advantage_kind": "profiled_counter_activation",
		},
	}
	_check(
		not bool(strategy.call(
			"_can_apply_autonomous_module_upgrade",
			selected, certified_rule_attachment,
			{"attack": {"ready": false, "ko_available": false}}, same_quota_safety
		)),
		"typed completion must not spend the unique Darkness over Rule's certified Munkidori activation"
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
