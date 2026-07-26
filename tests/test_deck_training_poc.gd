class_name TestDeckTrainingPoc
extends TestBase


const CatalogScript := preload("res://scripts/training/DeckTrainingCatalog.gd")
const AdmissionVerifierScript := preload("res://scripts/training/DeckTrainingAdmissionVerifier.gd")
const StateFactoryScript := preload("res://scripts/training/DeckTrainingStateFactory.gd")
const SessionScript := preload("res://scripts/training/DeckTrainingSession.gd")
const ProgressStoreScript := preload("res://scripts/training/DeckTrainingProgressStore.gd")
const GoalEvaluatorScript := preload("res://scripts/training/DeckTrainingGoalEvaluator.gd")
const StrategyRegistryScript := preload("res://scripts/ai/DeckStrategyRegistry.gd")
const LegalActionBuilderScript := preload("res://scripts/ai/AILegalActionBuilder.gd")
const AIOpponentScript := preload("res://scripts/ai/AIOpponent.gd")
const ProofSolverScript := preload("res://scripts/training/proof/DeckTrainingProofSolver.gd")
const ProofCertificateScript := preload("res://scripts/training/proof/DeckTrainingProofCertificate.gd")
const EngineProofAdapterScript := preload("res://scripts/training/proof/DeckTrainingEngineProofAdapter.gd")
const WitnessProofAdapterScript := preload("res://scripts/training/proof/DeckTrainingWitnessProofAdapter.gd")


class ProofGraphProvider:
	extends RefCounted

	var graph: Dictionary = {}
	var fingerprint := ""

	func _init(next_graph: Dictionary, next_fingerprint: String = "") -> void:
		graph = next_graph.duplicate(true)
		fingerprint = next_fingerprint

	func provider_name() -> String:
		return "test_complete_graph"

	func scenario_fingerprint() -> String:
		return fingerprint

	func clone_state(state: Variant) -> Variant:
		return str(state)

	func state_key(state: Variant) -> String:
		return str(state)

	func node_role(state: Variant) -> String:
		return str((graph.get(str(state), {}) as Dictionary).get("role", ProofSolverScript.ROLE_TERMINAL))

	func terminal_result(state: Variant) -> Dictionary:
		var node: Dictionary = graph.get(str(state), {})
		if not node.has("success"):
			return {"terminal": false}
		return {
			"terminal": true,
			"success": bool(node.get("success", false)),
			"reason": str(node.get("reason", "graph_terminal")),
		}

	func legal_choices(state: Variant) -> Dictionary:
		var node: Dictionary = graph.get(str(state), {})
		return {
			"complete": bool(node.get("complete", true)),
			"reason": str(node.get("coverage_reason", "graph_incomplete")),
			"choices": (node.get("choices", []) as Array).duplicate(true),
		}

	func apply_choice(_state: Variant, choice: Dictionary) -> Dictionary:
		if not bool(choice.get("supported", true)):
			return {"ok": false, "complete": false, "reason": str(choice.get("unsupported_reason", "unsupported"))}
		return {
			"ok": true,
			"complete": true,
			"state": str(choice.get("next", "")),
		}


func test_catalog_contains_seven_v18_decks_and_seventy_scenarios() -> String:
	var catalog := CatalogScript.load_catalog()
	var scenarios := CatalogScript.list_scenarios()
	var checks: Array[String] = [
		assert_eq((catalog.get("errors", []) as Array).size(), 0, "Training catalog should pass schema validation"),
		assert_eq(CatalogScript.deck_options().size(), 7, "Browser should expose seven deck radio options"),
		assert_eq(scenarios.size(), 70, "Training catalog should contain 7 x 10 scenarios"),
	]
	for option: Dictionary in CatalogScript.deck_options():
		var key := str(option.get("key", ""))
		checks.append(assert_eq(CatalogScript.list_scenarios(CatalogScript.CATALOG_PATH, key).size(), 10, "%s should own ten scenarios" % key))
	return run_checks(checks)


func test_expert_authoring_contract_and_final_result_goals_are_admitted() -> String:
	var checks: Array[String] = []
	for scenario: Dictionary in CatalogScript.list_scenarios():
		checks.append(assert_true(int(scenario.get("turn_limit", 0)) in [1, 2], "%s should use an expert one- or two-turn deadline" % str(scenario.get("id", ""))))
		var goal: Dictionary = scenario.get("goal", {})
		checks.append(assert_true(str(goal.get("type", "")) in ["prizes", "target_knockouts", "compound"], "%s should use a high-payoff final result" % str(scenario.get("id", ""))))
		checks.append(assert_false(scenario.has("minimum_meaningful_actions"), "%s runtime schema must not contain an action minimum" % str(scenario.get("id", ""))))
		checks.append(assert_false(scenario.has("proof_graph"), "%s runtime schema must not prescribe an action path" % str(scenario.get("id", ""))))
	var admission := AdmissionVerifierScript.verify_all(CatalogScript.list_scenarios())
	checks.append(assert_true(bool(admission.get("ok", false)), "All puzzles should pass the expert payoff/decision/resource contract: %s" % JSON.stringify(admission.get("errors", []))))
	return run_checks(checks)


func test_proof_solver_finds_the_only_five_action_line_against_every_defense() -> String:
	var scenario := {
		"id": "proof_fixture",
		"turn_limit": 2,
		"goal": {"type": "prizes", "count": 4},
	}
	var fingerprint := ProofCertificateScript.scenario_fingerprint(scenario)
	var graph := {
		"root": {
			"role": ProofSolverScript.ROLE_PLAYER,
			"choices": [
				{"id": "bait", "label": "看似直接的攻击", "next": "bait_defense", "player_action_cost": 1},
				{"id": "exact", "label": "保留资源的精算路线", "next": "exact_defense", "player_action_cost": 1},
			],
		},
		"bait_defense": {
			"role": ProofSolverScript.ROLE_OPPONENT,
			"choices": [
				{"id": "best_block", "next": "loss"},
				{"id": "loose_reply", "next": "win"},
			],
		},
		"exact_defense": {
			"role": ProofSolverScript.ROLE_OPPONENT,
			"choices": [
				{"id": "hide_target", "next": "step_2"},
				{"id": "deny_energy", "next": "step_2"},
			],
		},
		"step_2": {"role": ProofSolverScript.ROLE_PLAYER, "choices": [{"id": "operation_2", "next": "step_3", "player_action_cost": 1}]},
		"step_3": {"role": ProofSolverScript.ROLE_PLAYER, "choices": [{"id": "operation_3", "next": "step_4", "player_action_cost": 1}]},
		"step_4": {"role": ProofSolverScript.ROLE_PLAYER, "choices": [{"id": "operation_4", "next": "step_5", "player_action_cost": 1}]},
		"step_5": {"role": ProofSolverScript.ROLE_PLAYER, "choices": [{"id": "operation_5", "next": "win", "player_action_cost": 1}]},
		"win": {"success": true, "reason": "four_prizes"},
		"loss": {"success": false, "reason": "best_defense_stops_route"},
	}
	var provider := ProofGraphProvider.new(graph, fingerprint)
	var certificate := ProofSolverScript.new().prove("root", provider, {
		"require_unique_root": true,
		"max_depth": 12,
		"max_nodes": 100,
	})
	var validation := ProofCertificateScript.validate(scenario, certificate, true, 5)
	return run_checks([
		assert_eq(str(certificate.get("status", "")), ProofSolverScript.STATUS_PROVEN, "The exact route should force the goal"),
		assert_true(bool(certificate.get("unique_root_solution", false)), "Only the exact root decision should survive best defense"),
		assert_true(bool(certificate.get("exhaustive_defense", false)), "Both replies at every opponent node must be covered"),
		assert_eq(int(certificate.get("shortest_player_actions", 0)), 5, "The certified shortest route should require five player operations"),
		assert_eq(str(((certificate.get("principal_variation", []) as Array)[0] as Dictionary).get("choice_id", "")), "exact", "The principal variation should reject the tempting bait"),
		assert_true(bool(validation.get("ok", false)), "A fresh exhaustive five-action certificate should pass promotion: %s" % JSON.stringify(validation.get("errors", []))),
	])


func test_proof_solver_fails_closed_when_an_alternative_could_hide_a_second_solution() -> String:
	var graph := {
		"root": {
			"role": ProofSolverScript.ROLE_PLAYER,
			"choices": [
				{"id": "known_win", "next": "win", "player_action_cost": 1},
				{
					"id": "unresolved_interaction",
					"next": "win",
					"supported": false,
					"unsupported_reason": "interaction_choice_enumeration_not_supported",
				},
			],
		},
		"win": {"success": true},
	}
	var certificate := ProofSolverScript.new().prove("root", ProofGraphProvider.new(graph), {
		"require_unique_root": true,
		"max_depth": 4,
	})
	var existence_only := ProofSolverScript.new().prove("root", ProofGraphProvider.new(graph), {
		"require_unique_root": false,
		"max_depth": 4,
	})
	return run_checks([
		assert_eq(str(certificate.get("status", "")), ProofSolverScript.STATUS_INCONCLUSIVE, "Unknown branches must never be promoted as a unique proof"),
		assert_false(bool(certificate.get("unique_root_solution", true)), "The unresolved interaction could still contain a second solution"),
		assert_true("root_uniqueness_not_proven" in (certificate.get("unsupported_reasons", []) as Array), "Certificate should explain why uniqueness is unproven"),
		assert_eq(str(existence_only.get("status", "")), ProofSolverScript.STATUS_PROVEN, "The known branch may still prove that at least one solution exists"),
		assert_false(bool(existence_only.get("unique_root_solution", true)), "Existence search must not label an unknown alternative as a unique solution"),
	])


func test_proof_certificate_rejects_a_stale_scenario_fingerprint() -> String:
	var original := {"id": "fingerprint", "turn_limit": 2, "goal": {"type": "prizes", "count": 4}}
	var changed := original.duplicate(true)
	(changed.get("goal", {}) as Dictionary)["count"] = 3
	var certificate := {
		"format_version": 1,
		"solver_version": ProofSolverScript.SOLVER_VERSION,
		"status": ProofSolverScript.STATUS_PROVEN,
		"scenario_fingerprint": ProofCertificateScript.scenario_fingerprint(original),
		"exhaustive_defense": true,
		"unique_root_solution": true,
		"shortest_player_actions": 5,
		"unsupported_reasons": [],
		"metrics": {"nodes_visited": 10, "budget_reason": ""},
	}
	var validation := ProofCertificateScript.validate(changed, certificate)
	return run_checks([
		assert_false(bool(validation.get("ok", true)), "Changing the board or goal must invalidate its old proof"),
		assert_true("certificate is stale for the current scenario" in (validation.get("errors", []) as Array), "Fingerprint mismatch should be explicit"),
	])


func test_engine_proof_adapter_uses_real_legal_actions_and_turn_transition() -> String:
	var scenario := CatalogScript.get_scenario("gholdengo_06")
	var built := StateFactoryScript.build(scenario)
	var gsm: GameStateMachine = built.get("gsm", null)
	if gsm == null:
		return "gholdengo_06 failed to build: %s" % JSON.stringify(built.get("errors", []))
	var adapter := EngineProofAdapterScript.new()
	adapter.configure(scenario)
	var proof_state: Dictionary = adapter.make_initial_state(gsm)
	var choice_contract: Dictionary = adapter.legal_choices(proof_state)
	var end_choice: Dictionary = {}
	var ids: Dictionary = {}
	for choice_variant: Variant in choice_contract.get("choices", []):
		var choice: Dictionary = choice_variant
		ids[str(choice.get("id", ""))] = true
		if str(choice.get("label", "")) == "end_turn":
			end_choice = choice
	var transition := adapter.apply_choice(proof_state, end_choice)
	var next_state: Dictionary = transition.get("state", {}) if transition.get("state", {}) is Dictionary else {}
	var checks := run_checks([
		assert_true(bool(choice_contract.get("complete", false)), "Production legal-action enumeration should declare its coverage"),
		assert_eq(ids.size(), (choice_contract.get("choices", []) as Array).size(), "Every production action needs a stable unique proof id"),
		assert_false(end_choice.is_empty(), "Production end-turn action should be present"),
		assert_true(bool(transition.get("ok", false)), "End turn should execute through the production GameStateMachine"),
		assert_eq(adapter.node_role(next_state), ProofSolverScript.ROLE_OPPONENT, "The cloned proof state should hand control to the defender"),
		assert_eq(int(next_state.get("player_turns_completed", 0)), 1, "The proof deadline should count the completed player turn"),
	])
	gsm.prepare_for_disposal()
	var cloned_gsm: GameStateMachine = next_state.get("gsm", null)
	if cloned_gsm != null:
		cloned_gsm.prepare_for_disposal()
	return checks


func test_all_seven_decks_are_real_sixty_card_lists_with_rules_strategies() -> String:
	var checks: Array[String] = []
	for option: Dictionary in CatalogScript.deck_options():
		var deck_id := int(option.get("id", 0))
		var deck := _read_json("res://data/bundled_user/decks/%d.json" % deck_id)
		checks.append(assert_eq(_deck_total(deck), 60, "Deck %d should contain exactly 60 cards" % deck_id))
		checks.append(assert_true(StrategyRegistryScript.strategy_id_for_deck_id(deck_id) != "", "Deck %d should resolve a production rules strategy" % deck_id))
	return run_checks(checks)


func test_gardevoir_curriculum_uses_academy_deck_and_graph_engineering_mix() -> String:
	var scenarios := CatalogScript.list_scenarios(CatalogScript.CATALOG_PATH, "gardevoir")
	var profiles := {"precision": 0, "deployment": 0, "composite": 0}
	var fingerprints: Dictionary = {}
	var encoded_all := ""
	var checks: Array[String] = [
		assert_eq(int((CatalogScript.DECKS.get("gardevoir", {}) as Dictionary).get("id", 0)), 800018498, "Gardevoir training must use the Academy list with Drifloon, Shaymin and Budew"),
		assert_eq(scenarios.size(), 10, "The upgraded Gardevoir curriculum should still contain ten puzzles"),
	]
	for scenario: Dictionary in scenarios:
		var scenario_id := str(scenario.get("id", ""))
		var goal: Dictionary = scenario.get("goal", {})
		var graph_contract: Dictionary = scenario.get("graph_contract", {})
		var profile := str(graph_contract.get("profile", ""))
		profiles[profile] = int(profiles.get(profile, 0)) + 1
		var graph_path := str(graph_contract.get("graph_artifact", ""))
		fingerprints[JSON.stringify({
			"player": scenario.get("player", {}),
			"opponent": scenario.get("opponent", {}),
			"goal": goal,
		})] = true
		encoded_all += JSON.stringify(scenario)
		checks.append(assert_eq(int(scenario.get("player_deck_id", 0)), 800018498, "%s should use the frozen Academy Gardevoir deck" % scenario_id))
		checks.append(assert_eq(int(scenario.get("revision", 0)), 3, "%s should invalidate the old preassembled-puzzle grade" % scenario_id))
		checks.append(assert_eq(str(goal.get("type", "")), "compound", "%s should require progress plus board-state invariants" % scenario_id))
		checks.append(assert_true((goal.get("invariants", []) as Array).size() >= 3, "%s should verify survival, engine protection and handoff" % scenario_id))
		checks.append(assert_true((scenario.get("player", {}) as Dictionary).get("bench", []).size() < 5, "%s should expose a consequential Bench decision instead of starting full" % scenario_id))
		checks.append(assert_true(profile in profiles, "%s should declare a supported graph profile" % scenario_id))
		checks.append(assert_true(graph_path != "" and FileAccess.file_exists(graph_path), "%s should retain its reviewable graph artifact" % scenario_id))
		checks.append(assert_true((graph_contract.get("public_threats", []) as Array).size() >= 1, "%s should expose a fair opponent threat" % scenario_id))
		if profile in ["deployment", "composite"]:
			checks.append(assert_true((graph_contract.get("initial_options", []) as Array).size() >= 3, "%s should begin with at least three plausible route choices" % scenario_id))
			checks.append(assert_eq(str(graph_contract.get("opponent_operator", "")), "AND", "%s should require all credible opponent replies" % scenario_id))
	checks.append(assert_eq(int(profiles.get("precision", 0)), 2, "Curriculum mix should contain exactly two precision puzzles"))
	checks.append(assert_eq(int(profiles.get("deployment", 0)), 5, "Curriculum mix should contain exactly five deployment puzzles"))
	checks.append(assert_eq(int(profiles.get("composite", 0)), 3, "Curriculum mix should contain exactly three composite puzzles"))
	checks.append(assert_eq(fingerprints.size(), 10, "All ten upgraded Gardevoir boards should be materially distinct"))
	for defining_uid: String in ["CSV2C_060", "CSV10C_007", "CSV6C_065", "CSV8C_094"]:
		checks.append(assert_true(encoded_all.contains(defining_uid), "Academy curriculum should expose defining card %s in its states or route contract" % defining_uid))
	checks.append(assert_false(encoded_all.contains("CSV2C_054"), "Academy curriculum must not retain the old SVI/85 Kirlia"))
	checks.append(assert_true(encoded_all.contains("CS6.5C_030"), "Academy curriculum should use the Refinement Kirlia"))
	var malformed := scenarios[0].duplicate(true)
	(malformed.get("graph_contract", {}) as Dictionary)["opponent_operator"] = "OR"
	var rejected := AdmissionVerifierScript.verify_scenario(malformed)
	checks.append(assert_false(bool(rejected.get("ok", true)), "The admission gate must reject a deployment graph that ignores credible opponent replies"))
	return run_checks(checks)


func test_self_destruct_charizard_theme_uses_the_briar_deck() -> String:
	var option: Dictionary = CatalogScript.DECKS.get("charizard_dragapult", {})
	var deck_id := int(option.get("id", 0))
	var deck := _read_json("res://data/bundled_user/decks/%d.json" % deck_id)
	var names: Array[String] = []
	for entry: Variant in deck.get("cards", []):
		if entry is Dictionary:
			names.append(str((entry as Dictionary).get("name", "")))
	return run_checks([
		assert_eq(deck_id, 800025404, "The evil-Charizard curriculum must use the self-destruct Charizard deck, not Dragapult Charizard"),
		assert_true("白蕾雅" in names, "The selected Charizard deck must contain Briar"),
		assert_true("反击捕捉器" in names, "The selected Charizard deck must contain Counter Catcher"),
		assert_true("黑夜魔灵" in names, "The selected Charizard deck must contain the self-KO line"),
	])


func test_all_seventy_snapshots_restore_with_card_conservation() -> String:
	var checks: Array[String] = []
	for scenario: Dictionary in CatalogScript.list_scenarios():
		var scenario_id := str(scenario.get("id", ""))
		var built := StateFactoryScript.build(scenario)
		var errors: Array = built.get("errors", [])
		checks.append(assert_eq(errors.size(), 0, "%s should build: %s" % [scenario_id, JSON.stringify(errors)]))
		var gsm: GameStateMachine = built.get("gsm", null)
		checks.append(assert_not_null(gsm, "%s should restore a GameStateMachine" % scenario_id))
		if gsm != null:
			checks.append(assert_eq(gsm.count_player_total_cards(0), 60, "%s player zones should conserve 60 cards" % scenario_id))
			checks.append(assert_eq(gsm.count_player_total_cards(1), 60, "%s opponent zones should conserve 60 cards" % scenario_id))
			checks.append(assert_eq(int(gsm.game_state.phase), int(GameState.GamePhase.MAIN), "%s should start in Main phase" % scenario_id))
			gsm.prepare_for_disposal()
	return run_checks(checks)


func test_each_generic_puzzle_starts_from_a_production_legal_deck_engine_action() -> String:
	var checks: Array[String] = []
	for scenario: Dictionary in CatalogScript.list_scenarios():
		var deck_key := str(scenario.get("deck_key", ""))
		if deck_key == "dragapult":
			continue
		var opening := _execute_first_authored_step(scenario)
		checks.append(assert_true(
			bool(opening.get("ok", false)),
			"%s first authored action must execute through production rules: %s" % [
				str(scenario.get("id", "")),
				str(opening.get("reason", "")),
			]
		))
	return run_checks(checks)


func test_dragapult_ten_puzzles_keep_real_production_opening_actions() -> String:
	var checks: Array[String] = []
	for scenario: Dictionary in CatalogScript.list_scenarios(CatalogScript.CATALOG_PATH, "dragapult"):
		var scenario_id := str(scenario.get("id", ""))
		var opening := _execute_first_authored_step(scenario)
		checks.append(assert_true(
			bool(opening.get("ok", false)),
			"%s opening author action must remain production-legal: %s" % [
				scenario_id,
				str(opening.get("reason", "")),
			]
		))
	return run_checks(checks)


func test_three_proven_dragapult_puzzles_replay_through_production_rules() -> String:
	var checks: Array[String] = []
	for scenario_id: String in [
		"dragapult_gardevoir_01",
		"dragapult_gardevoir_02",
		"dragapult_gardevoir_03",
	]:
		var scenario := CatalogScript.get_scenario(scenario_id)
		var certificate := _prove_authored_scenario(scenario)
		var promotion := AdmissionVerifierScript.verify_for_solver_promotion(scenario, certificate)
		var witness: Dictionary = (scenario.get("design_contract", {}) as Dictionary).get("witness", {})
		var minimum_actions := int(witness.get("minimum_meaningful_actions", 5))
		checks.append(assert_eq(str(certificate.get("status", "")), ProofSolverScript.STATUS_PROVEN, "%s witness should reach its exact knockout goal: %s" % [scenario_id, str(certificate.get("reason", ""))]))
		var proven_actions := int(certificate.get("shortest_player_actions", 0))
		checks.append(assert_true(proven_actions >= 5, "%s must keep the five-player-action difficulty floor" % scenario_id))
		checks.append(assert_true(proven_actions <= minimum_actions, "%s certificate actions should fit inside the broader authored operation count" % scenario_id))
		checks.append(assert_true(bool(certificate.get("exhaustive_defense", false)), "%s fixed rules-AI reply should be fully replayed" % scenario_id))
		checks.append(assert_true(bool(promotion.get("ok", false)), "%s should pass strict proof promotion: %s" % [scenario_id, JSON.stringify(promotion.get("errors", []))]))
	return run_checks(checks)


func test_data_driven_witness_steps_replay_generic_targets_through_production_rules() -> String:
	var scenario := CatalogScript.get_scenario("dragapult_gardevoir_03")
	var adapter := WitnessProofAdapterScript.new()
	adapter.configure(scenario)
	var certificate := _prove_authored_scenario(scenario)
	var witness: Dictionary = (scenario.get("design_contract", {}) as Dictionary).get("witness", {})
	return run_checks([
		assert_eq(adapter.provider_name(), "production_rules_ai_witness_v2", "Data-driven witnesses should use the v2 provider"),
		assert_true((scenario.get("proof_steps", []) as Array).size() >= 5, "The current scenario must carry its full data-driven witness"),
		assert_eq(str(certificate.get("status", "")), ProofSolverScript.STATUS_PROVEN, "Current generic selectors should reach the exact authored goal: %s" % str(certificate.get("reason", ""))),
		assert_eq(int(certificate.get("shortest_player_actions", 0)), int(witness.get("minimum_meaningful_actions", 5)), "Every authored production decision should execute"),
	])


func test_three_generic_deck_routes_reach_a_real_fifth_attack_action() -> String:
	var checks: Array[String] = []
	for scenario_id: String in ["gardevoir_01", "n_zoroark_01", "raging_bolt_02"]:
		var scenario := CatalogScript.get_scenario(scenario_id)
		var certificate := _prove_authored_scenario(scenario)
		var witness: Dictionary = (scenario.get("design_contract", {}) as Dictionary).get("witness", {})
		var action_count := int(certificate.get("shortest_player_actions", 0))
		checks.append(assert_eq(str(certificate.get("status", "")), ProofSolverScript.STATUS_PROVEN, "%s should replay to its real attack payoff: %s" % [scenario_id, str(certificate.get("reason", ""))]))
		checks.append(assert_true(action_count >= 5, "%s should require at least five production decisions before completion" % scenario_id))
		checks.append(assert_true(action_count <= int(witness.get("minimum_meaningful_actions", action_count)), "%s certificate actions should fit inside the authored operation count" % scenario_id))
	return run_checks(checks)


func test_munkidori_focus_puzzles_expose_the_real_damage_transfer_action() -> String:
	var checks: Array[String] = []
	var focus_count := 0
	for scenario: Dictionary in CatalogScript.list_scenarios():
		var focus_text := "%s %s %s" % [
			str(scenario.get("focus", "")),
			str(scenario.get("objective", "")),
			JSON.stringify((scenario.get("design_contract", {}) as Dictionary).get("combo_contract", {})),
		]
		if not focus_text.contains("愿增猿") and not focus_text.contains("亢奋脑力"):
			continue
		focus_count += 1
		var has_transfer_step := false
		for step_variant: Variant in scenario.get("proof_steps", []):
			var step: Dictionary = step_variant
			if str(step.get("kind", "")) == "munkidori" or str(step.get("label", "")).contains("愿增猿") or str(step.get("label", "")).contains("亢奋脑力"):
				has_transfer_step = true
				break
		var certificate := _prove_authored_scenario(scenario)
		checks.append(assert_true(has_transfer_step, "%s should author the real Munkidori transfer at its correct route checkpoint" % str(scenario.get("id", ""))))
		checks.append(assert_eq(str(certificate.get("status", "")), ProofSolverScript.STATUS_PROVEN, "%s Munkidori route should replay through production rules" % str(scenario.get("id", ""))))
	checks.append(assert_true(focus_count >= 4, "The seven-deck curriculum should contain several explicit Munkidori exercises"))
	return run_checks(checks)


func test_two_turn_session_waits_through_the_rules_ai_middle_turn() -> String:
	# Keep this fixture focused on turn-boundary timing. Compound invariants have
	# their own test below and intentionally grade a prize-only shortcut as B.
	var scenario := CatalogScript.get_scenario("gardevoir_07").duplicate(true)
	scenario["goal"] = {"type": "prizes", "count": 4}
	var built := StateFactoryScript.build(scenario)
	var gsm: GameStateMachine = built.get("gsm", null)
	if gsm == null:
		return "gardevoir_07 failed to build: %s" % JSON.stringify(built.get("errors", []))
	var session := SessionScript.new()
	session.setup(scenario, built.get("snapshot", {}))
	var state := gsm.game_state
	state.current_player_index = 1
	var after_first := session.on_state_changed(state)
	state.current_player_index = 0
	var during_second := session.on_state_changed(state)
	for _index: int in 4:
		if not state.players[0].prizes.is_empty():
			state.players[0].prizes.pop_back()
	state.current_player_index = 1
	var after_deadline := session.on_state_changed(state)
	var checks := run_checks([
		assert_false(bool(after_first.get("terminal", false)), "First player turn should hand control to production AI without judging"),
		assert_false(bool(during_second.get("terminal", false)), "Returning from the AI middle turn should still be live"),
		assert_true(bool(after_deadline.get("terminal", false)), "Second player turn end should trigger the only judgement"),
		assert_eq(str(after_deadline.get("grade", "")), "A", "Meeting the exact prize target should grade A"),
	])
	gsm.prepare_for_disposal()
	return checks


func test_compound_goal_requires_progress_survival_engine_and_handoff() -> String:
	var scenario := CatalogScript.get_scenario("gardevoir_07")
	var built := StateFactoryScript.build(scenario)
	var gsm: GameStateMachine = built.get("gsm", null)
	if gsm == null:
		return "gardevoir_07 compound fixture failed to build: %s" % JSON.stringify(built.get("errors", []))
	var state := gsm.game_state
	var goal := {
		"type": "compound",
		"progress_goal": {"type": "prizes", "count": 4},
		"invariants": [
			{"type": "not_lost", "player": 0},
			{"type": "preserve_any", "player": 0, "card_uids": ["CSV2C_055"], "count": 1},
			{"type": "handoff_attacker", "player": 0, "card_uids": ["CSV6C_065"], "min_energy": 1},
		],
	}
	var initial_prizes := state.players[0].prizes.size()
	for _index: int in 4:
		state.players[0].prizes.pop_back()
	var context := {"initial_prize_counts": [initial_prizes, state.players[1].prizes.size()]}
	var progress_only := GoalEvaluatorScript.progress(goal, state, context)
	var without_handoff := GoalEvaluatorScript.is_satisfied(goal, state, context)
	var scream_tail: PokemonSlot = null
	for slot: PokemonSlot in state.players[0].get_all_pokemon():
		if slot.get_top_card() != null and slot.get_top_card().card_data.get_uid() == "CSV6C_065":
			scream_tail = slot
			break
	var psychic: CardInstance = null
	for card: CardInstance in state.players[0].deck:
		if card.card_data != null and card.card_data.get_uid() == "CSVE1C_PSY":
			psychic = card
			break
	if scream_tail != null and psychic != null:
		state.players[0].deck.erase(psychic)
		scream_tail.attached_energy.append(psychic)
	var with_handoff := GoalEvaluatorScript.is_satisfied(goal, state, context)
	state.set_game_over(1, "opponent_reply")
	var after_loss := GoalEvaluatorScript.is_satisfied(goal, state, context)
	var checks := run_checks([
		assert_eq(progress_only, 4, "Compound goals should preserve ordinary prize progress reporting"),
		assert_false(without_handoff, "Taking the prizes alone must not pass without a prepared next attacker"),
		assert_true(with_handoff, "The same board should pass after the protected handoff attacker is prepared"),
		assert_false(after_loss, "A compound goal must fail after the opponent wins"),
	])
	gsm.prepare_for_disposal()
	return checks


func test_session_never_awards_completion_after_opponent_wins() -> String:
	var scenario := CatalogScript.get_scenario("gholdengo_02")
	var built := StateFactoryScript.build(scenario)
	var gsm: GameStateMachine = built.get("gsm", null)
	if gsm == null:
		return "opponent-win session fixture failed to build: %s" % JSON.stringify(built.get("errors", []))
	var session := SessionScript.new()
	session.setup(scenario, built.get("snapshot", {}))
	for _index: int in 4:
		gsm.game_state.players[0].prizes.pop_back()
	gsm.game_state.set_game_over(1, "opponent_takes_last_prize")
	var result := session.on_game_over(1, "opponent_takes_last_prize", gsm.game_state)
	var checks := run_checks([
		assert_true(bool(result.get("terminal", false)), "A reported game over should end the training session"),
		assert_false(bool(result.get("completed", true)), "Prize progress must not override an opponent victory"),
		assert_true(bool(result.get("failed", false)), "Opponent victory should explicitly fail the puzzle"),
		assert_eq(str(result.get("reason", "")), "对手已获胜", "The result should explain the survival failure"),
	])
	gsm.prepare_for_disposal()
	return checks


func test_four_prize_result_does_not_pass_after_only_the_first_player_turn() -> String:
	var scenario := CatalogScript.get_scenario("gholdengo_02")
	var built := StateFactoryScript.build(scenario)
	var gsm: GameStateMachine = built.get("gsm", null)
	if gsm == null:
		return "gholdengo_02 failed to build: %s" % JSON.stringify(built.get("errors", []))
	var session := SessionScript.new()
	session.setup(scenario, built.get("snapshot", {}))
	var state := gsm.game_state
	var knocked_active: PokemonSlot = state.players[1].active_pokemon
	for card: CardInstance in knocked_active.collect_all_cards():
		state.players[1].discard_pile.append(card)
	state.players[1].active_pokemon = null
	var knocked_bench: PokemonSlot = state.players[1].bench.pop_front()
	for card: CardInstance in knocked_bench.collect_all_cards():
		state.players[1].discard_pile.append(card)
	var before_deadline := session.on_state_changed(state)
	state.current_player_index = 1
	var after_first_turn := session.on_state_changed(state)
	state.current_player_index = 0
	session.on_state_changed(state)
	state.current_player_index = 1
	var at_deadline := session.on_state_changed(state)
	var checks := run_checks([
		assert_false(bool(before_deadline.get("terminal", false)), "Goal completion during the turn must not open a result"),
		assert_false(bool(after_first_turn.get("terminal", false)), "A four-prize result must not finish after only the first player turn"),
		assert_true(bool(at_deadline.get("terminal", false)), "The result should appear only after the allowed turn ends"),
		assert_eq(str(at_deadline.get("grade", "")), "A", "Exact completion should grade A"),
	])
	gsm.prepare_for_disposal()
	return checks


func test_target_knockout_tracks_the_opening_pokemon_instance() -> String:
	var scenario := CatalogScript.get_scenario("marnie_02")
	scenario["turn_limit"] = 1
	scenario["goal"] = {"type": "target_knockouts", "required": 1, "targets": [{"player": 1, "zone": "bench", "index": 0}]}
	var built := StateFactoryScript.build(scenario)
	var gsm: GameStateMachine = built.get("gsm", null)
	if gsm == null:
		return "marnie_02 failed to build: %s" % JSON.stringify(built.get("errors", []))
	var session := SessionScript.new()
	session.setup(scenario, built.get("snapshot", {}))
	var target_slot: PokemonSlot = gsm.game_state.players[1].bench.pop_front() as PokemonSlot
	for card: CardInstance in target_slot.collect_all_cards():
		gsm.game_state.players[1].discard_pile.append(card)
	session.on_state_changed(gsm.game_state)
	gsm.game_state.current_player_index = 1
	var result := session.on_state_changed(gsm.game_state)
	var checks := run_checks([
		assert_true(bool(result.get("completed", false)), "Discarding the exact opening target stack should satisfy target knockout"),
		assert_eq(str(result.get("grade", "")), "A", "One required target knockout should grade A"),
	])
	gsm.prepare_for_disposal()
	return checks


func test_marnie_evolution_opens_punk_up_and_attaches_energy() -> String:
	var scenario := CatalogScript.get_scenario("marnie_01")
	var player_setup: Dictionary = scenario.get("player", {})
	var bench_setup: Array = player_setup.get("bench", [])
	(bench_setup[0] as Dictionary)["stack"] = ["CSV10C_146", "CSV10C_147"]
	(player_setup.get("deck_top", []) as Array).erase("CSV10C_148")
	(player_setup.get("hand", []) as Array).append("CSV10C_148")
	var built := StateFactoryScript.build(scenario)
	var gsm: GameStateMachine = built.get("gsm", null)
	if gsm == null:
		return "marnie_01 failed to build: %s" % JSON.stringify(built.get("errors", []))
	var player: PlayerState = gsm.game_state.players[0]
	var attacker: PokemonSlot = player.bench[0]
	var evolution := _find_hand_card(player.hand, "玛俐的长毛巨魔ex")
	var evolved := evolution != null and gsm.evolve_pokemon(0, evolution, attacker)
	var effect: BaseEffect = gsm.effect_processor.get_effect(attacker.get_top_card().card_data.effect_id) if evolved else null
	var direct_usable := effect != null and effect.has_method("can_use_ability") and bool(effect.call("can_use_ability", attacker, gsm.game_state))
	var processor_usable := evolved and gsm.effect_processor.can_use_ability(attacker, gsm.game_state, 0)
	var steps: Array = gsm.get_evolve_ability_interaction_steps(attacker) if evolved else []
	var energies: Array[CardInstance] = []
	for card: CardInstance in player.deck:
		if card.card_data != null and card.card_data.name == "基本恶能量":
			energies.append(card)
			if energies.size() == 2:
				break
	var assignments: Array[Dictionary] = []
	for energy: CardInstance in energies:
		assignments.append({"source": energy, "target": attacker})
	var used := evolved and not steps.is_empty() and gsm.use_ability(0, attacker, 0, [{"marnies_punk_up_assignments": assignments}])
	var checks := run_checks([
		assert_true(evolved, "The training board should allow evolving Marnie's Grimmsnarl ex"),
		assert_not_null(effect, "Punk Up should be the registered primary ability effect"),
		assert_true(effect != null and effect.has_method("is_evolve_triggered_ability"), "Punk Up must declare itself as an evolve-triggered ability"),
		assert_true(direct_usable, "Punk Up's own legality should accept the freshly evolved training board"),
		assert_true(processor_usable, "The shared ability processor should accept Punk Up on the freshly evolved training board"),
		assert_false(steps.is_empty(), "Evolution must immediately expose the Punk Up assignment interaction (direct=%s processor=%s effect=%s)" % [direct_usable, processor_usable, str(effect)]),
		assert_true(used, "Punk Up should resolve through the production ability path"),
		assert_eq(attacker.attached_energy.size(), 2, "Punk Up should attach the two selected Darkness Energy"),
	])
	gsm.prepare_for_disposal()
	return checks


func test_marnie_rare_candy_evolution_also_opens_punk_up() -> String:
	var scenario := CatalogScript.get_scenario("marnie_01")
	var player_setup: Dictionary = scenario.get("player", {})
	var bench: Array = player_setup.get("bench", [])
	(bench[0] as Dictionary)["stack"] = ["CSV10C_146"]
	(player_setup.get("hand", []) as Array).append("CSVH1C_045")
	(player_setup.get("deck_top", []) as Array).erase("CSV10C_148")
	(player_setup.get("hand", []) as Array).append("CSV10C_148")
	var built := StateFactoryScript.build(scenario)
	var gsm: GameStateMachine = built.get("gsm", null)
	if gsm == null:
		return "Marnie Rare Candy fixture failed to build: %s" % JSON.stringify(built.get("errors", []))
	var player: PlayerState = gsm.game_state.players[0]
	var target: PokemonSlot = player.bench[0]
	var candy := _find_hand_card(player.hand, "神奇糖果")
	var grimmsnarl := _find_hand_card(player.hand, "玛俐的长毛巨魔ex")
	var evolved := candy != null and grimmsnarl != null and gsm.play_trainer(0, candy, [{
		"stage2_card": [grimmsnarl],
		"target_pokemon": [target],
	}])
	var steps: Array = gsm.get_evolve_ability_interaction_steps(target) if evolved else []
	var checks := run_checks([
		assert_true(evolved, "Rare Candy should evolve the old Marnie's Impidimp into Grimmsnarl ex"),
		assert_eq(target.get_pokemon_name(), "玛俐的长毛巨魔ex", "Rare Candy should install the correct Stage 2"),
		assert_false(steps.is_empty(), "The Rare Candy path must expose Punk Up just like normal evolution"),
	])
	gsm.prepare_for_disposal()
	return checks


func test_raging_bolt_training_crispin_can_search_restored_basic_energy() -> String:
	var scenario := CatalogScript.get_scenario("raging_bolt_02")
	var built := StateFactoryScript.build(scenario)
	var gsm: GameStateMachine = built.get("gsm", null)
	if gsm == null:
		return "raging_bolt_02 failed to build: %s" % JSON.stringify(built.get("errors", []))
	var player: PlayerState = gsm.game_state.players[0]
	var crispin: CardInstance = null
	for deck_card: CardInstance in player.deck:
		if deck_card.card_data != null and deck_card.card_data.name == "赤松":
			crispin = deck_card
			break
	if crispin != null:
		player.deck.erase(crispin)
		player.hand.append(crispin)
	var effect: BaseEffect = gsm.effect_processor.get_effect(crispin.card_data.effect_id) if crispin != null else null
	var energy_types: Dictionary = {}
	for deck_card: CardInstance in player.deck:
		if deck_card != null and deck_card.card_data != null and deck_card.card_data.card_type == "Basic Energy":
			var energy_type := deck_card.card_data.energy_provides
			if energy_type == "":
				energy_type = deck_card.card_data.energy_type
			energy_types[energy_type] = true
	var steps: Array = effect.get_interaction_steps(crispin, gsm.game_state) if effect != null else []
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var selectable_indices: Array = []
	for index_variant: Variant in step.get("card_indices", []):
		if int(index_variant) >= 0:
			selectable_indices.append(index_variant)
	var checks := run_checks([
		assert_not_null(crispin, "Raging Bolt training hand should contain the authored Crispin"),
		assert_not_null(effect, "Restored Crispin should resolve to its registered production effect"),
		assert_true(energy_types.size() >= 2, "Restored Raging Bolt deck should retain at least two searchable Basic Energy types"),
		assert_eq((step.get("card_items", []) as Array).size(), player.deck.size(), "Crispin search should expose the full restored deck"),
		assert_true(not selectable_indices.is_empty(), "Crispin search should enable Basic Energy in the restored deck"),
	])
	gsm.prepare_for_disposal()
	return checks


func test_live_raging_bolt_training_crispin_opens_selectable_library_cards() -> String:
	var packed := load("res://scenes/battle/BattleScene.tscn") as PackedScene
	if packed == null:
		return "Battle scene must load before the Raging Bolt Crispin smoke test"
	var scenario := CatalogScript.get_scenario("raging_bolt_02")
	var previous_launch: Dictionary = GameManager.peek_deck_training_launch()
	var previous_mode: int = int(GameManager.current_mode)
	var previous_decks: Array[int] = GameManager.selected_deck_ids.duplicate()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.selected_deck_ids = [int(scenario.get("player_deck_id", 0)), int(scenario.get("opponent_deck_id", 0))]
	GameManager.set("_deck_training_launch", {"scenario_id": "raging_bolt_02"})
	var tree := Engine.get_main_loop() as SceneTree
	var scene := packed.instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var gsm: GameStateMachine = scene.get("_gsm")
	var controller: DeckTrainingBattleController = scene.get("_deck_training_controller") as DeckTrainingBattleController
	if gsm != null:
		var live_player: PlayerState = gsm.game_state.players[0]
		for deck_card: CardInstance in live_player.deck:
			if deck_card.card_data != null and deck_card.card_data.name == "赤松":
				live_player.deck.erase(deck_card)
				live_player.hand.append(deck_card)
				break
	var crispin := _find_hand_card(gsm.game_state.players[0].hand, "赤松") if gsm != null else null
	if controller != null:
		controller.call("_on_intro_confirmed")
	if crispin != null:
		scene.call("_try_play_trainer_with_interaction", 0, crispin)
	await tree.process_frame
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var selectable_indices: Array = []
	for index_variant: Variant in dialog_data.get("card_indices", []):
		if int(index_variant) >= 0:
			selectable_indices.append(index_variant)
	var board := scene.get("_dialog_library_search_board") as Control
	var library_row := board.find_child("LibraryCardRow", true, false) as HBoxContainer if board != null else null
	var candidate_count := library_row.get_child_count() if library_row != null else 0
	var checks := run_checks([
		assert_not_null(crispin, "Live Raging Bolt training should retain Crispin in hand"),
		assert_eq(str(scene.get("_pending_choice")), "effect_interaction", "Playing Crispin should open the production effect interaction"),
		assert_eq(str(dialog_data.get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "Crispin should enter the full-library search UI"),
		assert_true(not selectable_indices.is_empty(), "Live Crispin dialog should contain selectable Basic Energy indices"),
		assert_eq(candidate_count, (dialog_data.get("card_items", []) as Array).size(), "Library board should render every restored deck card"),
	])
	scene.queue_free()
	await tree.process_frame
	GameManager.current_mode = previous_mode
	GameManager.selected_deck_ids = previous_decks
	GameManager.set("_deck_training_launch", previous_launch)
	return checks


func test_training_browser_remembers_gholdengo_after_return() -> String:
	var previous_suppression := GameManager.suppress_scene_navigation_for_tests
	var previous_key := GameManager.get_deck_training_selected_deck_key()
	var previous_launch := GameManager.peek_deck_training_launch()
	GameManager.suppress_scene_navigation_for_tests = true
	GameManager.set_deck_training_selected_deck_key("gholdengo")
	var started := GameManager.start_deck_training("gholdengo_07")
	GameManager.clear_deck_training_launch()
	GameManager.goto_deck_training()
	var remembered := GameManager.get_deck_training_selected_deck_key()
	GameManager.suppress_scene_navigation_for_tests = previous_suppression
	GameManager.set_deck_training_selected_deck_key(previous_key)
	GameManager.set("_deck_training_launch", previous_launch)
	return run_checks([
		assert_true(started, "Gholdengo expert puzzle should launch"),
		assert_eq(remembered, "gholdengo", "Returning from battle must keep the Gholdengo deck filter"),
	])


func test_gholdengo_jamming_tower_board_changes_the_exact_energy_math() -> String:
	var scenario := CatalogScript.get_scenario("gholdengo_07")
	var built := StateFactoryScript.build(scenario)
	var gsm: GameStateMachine = built.get("gsm", null)
	if gsm == null:
		return "gholdengo_07 failed to build: %s" % JSON.stringify(built.get("errors", []))
	var initial_target: PokemonSlot = gsm.game_state.players[1].active_pokemon
	var hp_with_charm := gsm.effect_processor.get_effective_max_hp(initial_target, gsm.game_state)
	var adapter := WitnessProofAdapterScript.new()
	adapter.configure(scenario)
	var proof_state: Dictionary = adapter.make_initial_state(gsm)
	var choices: Array = adapter.legal_choices(proof_state).get("choices", [])
	var transition: Dictionary = adapter.apply_choice(proof_state, choices[0]) if not choices.is_empty() else {}
	var witness_gsm: GameStateMachine = (transition.get("state", {}) as Dictionary).get("gsm", null) if bool(transition.get("ok", false)) else null
	var player: PlayerState = witness_gsm.game_state.players[0] if witness_gsm != null else null
	var opponent: PlayerState = witness_gsm.game_state.players[1] if witness_gsm != null else null
	var first_target: PokemonSlot = opponent.active_pokemon if opponent != null else null
	var second_target: PokemonSlot = opponent.bench[1] if opponent != null and opponent.bench.size() > 1 else null
	var tower := _find_hand_card(player.hand, "阻碍之塔") if player != null else null
	var played := tower != null and witness_gsm.play_stadium(0, tower)
	var hp_with_tower := witness_gsm.effect_processor.get_effective_max_hp(first_target, witness_gsm.game_state) if witness_gsm != null and first_target != null else 0
	var challenge: Dictionary = scenario.get("challenge", {})
	var checks := run_checks([
		assert_eq(str((scenario.get("goal", {}) as Dictionary).get("type", "")), "prizes", "Gholdengo curriculum should require the full four-prize conversion"),
		assert_eq(hp_with_charm, 230, "Bravery Charm should initially put Mew ex above the four-Energy breakpoint"),
		assert_true(bool(transition.get("ok", false)), "Fezandipiti ex should reveal the hidden Stadium through production effects"),
		assert_true(played, "Jamming Tower should become production-legal only after the authored draw checkpoint"),
		assert_eq(hp_with_tower, 180, "Jamming Tower should suppress the Charm and save exactly one attack Energy"),
		assert_not_null(second_target, "The second exact target should remain on the opponent Bench"),
		assert_eq(second_target.get_remaining_hp() if second_target != null else -1, 200, "The second target should also sit at the four-Energy breakpoint"),
		assert_true((challenge.get("decision_points", []) as Array).size() >= 2, "The board should document two irreversible choices"),
	])
	gsm.prepare_for_disposal()
	if witness_gsm != null:
		witness_gsm.prepare_for_disposal()
	return checks


func test_ten_gholdengo_puzzles_have_distinct_boards_and_curriculum_mechanics() -> String:
	var scenarios := CatalogScript.list_scenarios(CatalogScript.CATALOG_PATH, "gholdengo")
	var fingerprints: Dictionary = {}
	var titles: Dictionary = {}
	var checks: Array[String] = [
		assert_eq(scenarios.size(), 10, "Gholdengo curriculum should still expose exactly ten puzzles"),
	]
	for scenario: Dictionary in scenarios:
		var board_fingerprint := JSON.stringify({
			"player": scenario.get("player", {}),
			"opponent": scenario.get("opponent", {}),
			"goal": scenario.get("goal", {}),
		})
		fingerprints[board_fingerprint] = true
		titles[str(scenario.get("title", ""))] = true
	checks.append(assert_eq(fingerprints.size(), 10, "All ten Gholdengo puzzles must use materially different authored states"))
	checks.append(assert_eq(titles.size(), 10, "All ten Gholdengo puzzles must teach a distinct named lesson"))
	var expected_refs := {
		"gholdengo_01": "CSV1C_123",
		"gholdengo_02": "CSV9C_176",
		"gholdengo_03": "CSV3C_115",
		"gholdengo_04": "CSV8C_094",
		"gholdengo_05": "CSV9C_142",
		"gholdengo_06": "CSV6C_042",
		"gholdengo_07": "CSV8C_203",
		"gholdengo_08": "CSV6C_114",
		"gholdengo_09": "CSV8C_135",
		"gholdengo_10": "CSV1C_109",
	}
	for scenario_id: String in expected_refs:
		var encoded := JSON.stringify(CatalogScript.get_scenario(scenario_id))
		checks.append(assert_true(encoded.contains(str(expected_refs[scenario_id])), "%s should contain its defining curriculum card" % scenario_id))
	return run_checks(checks)


func test_replaced_gholdengo_curriculum_invalidates_old_best_grades() -> String:
	var scenario := CatalogScript.get_scenario("gholdengo_01")
	var old_progress := {
		"scenarios": {
			"gholdengo_01": {"completed": true, "best_grade": "S", "attempts": 8},
		},
	}
	var current_progress := {
		"scenarios": {
			"gholdengo_01": {"completed": true, "best_grade": "A", "attempts": 1, "revision": 3},
		},
	}
	return run_checks([
		assert_eq(int(scenario.get("revision", 0)), 3, "Replacement curriculum should carry a new progress revision"),
		assert_true(ProgressStoreScript.scenario_progress(old_progress, scenario).is_empty(), "Grades from the repeated old puzzles must not appear on the replacements"),
		assert_eq(str(ProgressStoreScript.scenario_progress(current_progress, scenario).get("best_grade", "")), "A", "Grades earned on revision 3 should remain visible"),
	])


func test_each_gholdengo_puzzle_exposes_its_defining_production_action() -> String:
	var expected := {
		"gholdengo_01": ["use_ability", "赛富豪ex"],
		"gholdengo_02": ["use_ability", "愿增猿"],
		"gholdengo_03": ["use_ability", "赛富豪ex"],
		"gholdengo_04": ["use_ability", "愿增猿"],
		"gholdengo_05": ["use_ability", "吉雉鸡ex"],
		"gholdengo_06": ["use_ability", "铁包袱"],
		"gholdengo_07": ["use_ability", "吉雉鸡ex"],
		"gholdengo_08": ["use_ability", "吉雉鸡ex"],
		"gholdengo_09": ["use_ability", "吉雉鸡ex"],
		"gholdengo_10": ["attack", "赛富豪"],
	}
	var checks: Array[String] = []
	for scenario_id: String in expected:
		var built := StateFactoryScript.build(CatalogScript.get_scenario(scenario_id))
		var gsm: GameStateMachine = built.get("gsm", null)
		if gsm == null:
			checks.append("%s failed to build" % scenario_id)
			continue
		var wanted: Array = expected[scenario_id]
		var actions := LegalActionBuilderScript.new().build_actions(gsm, 0, false)
		checks.append(assert_true(
			_contains_action(actions, str(wanted[0]), str(wanted[1])),
			"%s should expose its defining production action: %s %s" % [scenario_id, wanted[0], wanted[1]]
		))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_gholdengo_energy_search_and_single_prize_bridge_use_real_breakpoints() -> String:
	var split_build := StateFactoryScript.build(CatalogScript.get_scenario("gholdengo_02"))
	var split_gsm: GameStateMachine = split_build.get("gsm", null)
	var bridge_build := StateFactoryScript.build(CatalogScript.get_scenario("gholdengo_05"))
	var bridge_gsm: GameStateMachine = bridge_build.get("gsm", null)
	if split_gsm == null or bridge_gsm == null:
		return "Gholdengo breakpoint fixtures failed to build"
	var split_adapter := WitnessProofAdapterScript.new()
	split_adapter.configure(CatalogScript.get_scenario("gholdengo_02"))
	var split_state: Dictionary = split_adapter.make_initial_state(split_gsm)
	for _step_index: int in 4:
		var choice_report: Dictionary = split_adapter.legal_choices(split_state)
		var choices: Array = choice_report.get("choices", [])
		if choices.is_empty():
			break
		var transition: Dictionary = split_adapter.apply_choice(split_state, choices[0])
		if not bool(transition.get("ok", false)):
			break
		split_state = transition.get("state", {})
	var split_witness_gsm: GameStateMachine = split_state.get("gsm", null)
	var search_card := _find_hand_card(split_witness_gsm.game_state.players[0].hand, "能量输送PRO") if split_witness_gsm != null else null
	var search_effect: BaseEffect = split_witness_gsm.effect_processor.get_effect(search_card.card_data.effect_id) if search_card != null and split_witness_gsm != null else null
	var search_steps: Array = search_effect.get_interaction_steps(search_card, split_witness_gsm.game_state) if search_effect != null else []
	var selectable_energy_count := 0
	if not search_steps.is_empty():
		for index_variant: Variant in search_steps[0].get("card_indices", []):
			if int(index_variant) >= 0:
				selectable_energy_count += 1
	var bridge_adapter := WitnessProofAdapterScript.new()
	bridge_adapter.configure(CatalogScript.get_scenario("gholdengo_05"))
	var bridge_state: Dictionary = bridge_adapter.make_initial_state(bridge_gsm)
	var bridge_choices: Array = bridge_adapter.legal_choices(bridge_state).get("choices", [])
	if not bridge_choices.is_empty():
		var bridge_transition: Dictionary = bridge_adapter.apply_choice(bridge_state, bridge_choices[0])
		if bool(bridge_transition.get("ok", false)):
			bridge_state = bridge_transition.get("state", {})
	var bridge_witness_gsm: GameStateMachine = bridge_state.get("gsm", null)
	var bridge_player: PlayerState = bridge_witness_gsm.game_state.players[0] if bridge_witness_gsm != null else null
	var regular_gholdengo := _find_hand_card(bridge_player.hand, "赛富豪")
	var evolved := regular_gholdengo != null and bridge_witness_gsm.evolve_pokemon(0, regular_gholdengo, bridge_player.active_pokemon)
	var bridge_attack_legal := _contains_action(
		LegalActionBuilderScript.new().build_actions(bridge_witness_gsm, 0, false),
		"attack",
		"赛富豪"
	)
	var checks := run_checks([
		assert_eq(selectable_energy_count, 8, "The PRO split puzzle must really expose all eight Basic Energy types"),
		assert_true(evolved, "The bridge puzzle must allow the Active Gimmighoul to evolve this turn"),
		assert_true(bridge_attack_legal, "Freshly evolved regular Gholdengo must have a production-legal Rich Strike"),
		assert_eq(bridge_witness_gsm.game_state.players[1].active_pokemon.get_remaining_hp(), 120, "The first target must match Rich Strike's exact 120 damage"),
	])
	split_gsm.prepare_for_disposal()
	if split_witness_gsm != null:
		split_witness_gsm.prepare_for_disposal()
	bridge_gsm.prepare_for_disposal()
	if bridge_witness_gsm != null:
		bridge_witness_gsm.prepare_for_disposal()
	return checks


func test_gholdengo_comeback_and_zero_deck_states_are_authored_in_engine_state() -> String:
	var comeback := CatalogScript.get_scenario("gholdengo_09")
	var comeback_build := StateFactoryScript.build(comeback)
	var comeback_gsm: GameStateMachine = comeback_build.get("gsm", null)
	var endgame := CatalogScript.get_scenario("gholdengo_10")
	var endgame_build := StateFactoryScript.build(endgame)
	var endgame_gsm: GameStateMachine = endgame_build.get("gsm", null)
	if comeback_gsm == null or endgame_gsm == null:
		return "special Gholdengo states failed to build: %s / %s" % [
			JSON.stringify(comeback_build.get("errors", [])),
			JSON.stringify(endgame_build.get("errors", [])),
		]
	var fez_usable := _contains_action(
		LegalActionBuilderScript.new().build_actions(comeback_gsm, 0, false),
		"use_ability",
		"吉雉鸡ex"
	)
	var rod_legal := _contains_action(
		[],
		"play_trainer",
		"厉害钓竿"
	)
	var endgame_adapter := WitnessProofAdapterScript.new()
	endgame_adapter.configure(endgame)
	var endgame_state: Dictionary = endgame_adapter.make_initial_state(endgame_gsm)
	for _step_index: int in 2:
		var choices: Array = endgame_adapter.legal_choices(endgame_state).get("choices", [])
		if choices.is_empty():
			break
		var transition: Dictionary = endgame_adapter.apply_choice(endgame_state, choices[0])
		if not bool(transition.get("ok", false)):
			break
		endgame_state = transition.get("state", {})
	var endgame_witness_gsm: GameStateMachine = endgame_state.get("gsm", null)
	if endgame_witness_gsm != null:
		rod_legal = _contains_action(
			LegalActionBuilderScript.new().build_actions(endgame_witness_gsm, 0, false),
			"play_trainer",
			"厉害钓竿"
		)
	var checks := run_checks([
		assert_eq(comeback_gsm.game_state.last_knockout_turn_against[0], 9, "Comeback puzzle must preserve the previous-turn knockout fact"),
		assert_true(fez_usable, "That fact must make Fezandipiti ex usable through production legal actions"),
		assert_eq(endgame_gsm.game_state.players[0].deck.size(), 1, "Endgame puzzle should begin with exactly one natural draw remaining"),
		assert_eq(endgame_witness_gsm.game_state.players[0].deck.size() if endgame_witness_gsm != null else -1, 0, "The first knockout and AI turn should consume that last draw"),
		assert_true(rod_legal, "Prize pickup should make Super Rod legal only after the deck reaches zero"),
	])
	comeback_gsm.prepare_for_disposal()
	endgame_gsm.prepare_for_disposal()
	if endgame_witness_gsm != null:
		endgame_witness_gsm.prepare_for_disposal()
	return checks


func test_charizard_expert_board_requires_the_concede_then_briar_window() -> String:
	var scenario := CatalogScript.get_scenario("charizard_dragapult_07")
	var built := StateFactoryScript.build(scenario)
	var gsm: GameStateMachine = built.get("gsm", null)
	if gsm == null:
		return "charizard_dragapult_07 failed to build: %s" % JSON.stringify(built.get("errors", []))
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var hand_uids: Array[String] = []
	for card: CardInstance in player.hand:
		if card.card_data != null:
			hand_uids.append(card.card_data.get_uid())
	var design_contract: Dictionary = scenario.get("design_contract", {})
	var key_cards: Array = design_contract.get("key_cards", [])
	var hidden_key_count := 0
	for key_uid_variant: Variant in key_cards:
		if str(key_uid_variant) not in hand_uids:
			hidden_key_count += 1
	var proof_step_ids: Array[String] = []
	for step_variant: Variant in scenario.get("proof_steps", []):
		proof_step_ids.append(str((step_variant as Dictionary).get("id", "")))
	var witness: Dictionary = design_contract.get("witness", {})
	var checks := run_checks([
		assert_eq(int(scenario.get("player_deck_id", 0)), 800025404, "The puzzle must use self-destruct Charizard"),
		assert_eq(hidden_key_count, key_cards.size(), "Every solution key must start outside the visible hand"),
		assert_eq(player.bench.size(), 5, "The expert board should fill the player's Bench with functional roles"),
		assert_eq(opponent.bench.size(), 5, "The expert board should fill the opponent's Bench with targets and decoys"),
		assert_eq(opponent.prizes.size(), 4, "The opponent must cross from four to two prizes through the forced reply plus self-KO"),
		assert_true("zoroark_reply" in proof_step_ids and "offer_prize" in proof_step_ids, "The witness must explicitly prove the reply-then-concede order"),
		assert_true("play_briar" in proof_step_ids and "burning_darkness" in proof_step_ids, "The hidden Briar line must end in the real Charizard attack"),
		assert_true(int(witness.get("minimum_meaningful_actions", 0)) >= 5, "The expert board must retain the five-action admission floor"),
		assert_true((design_contract.get("bait_lines", []) as Array).size() >= 2, "The board must preserve multiple plausible but losing draw routes"),
	])
	gsm.prepare_for_disposal()
	return checks


func test_training_ui_uses_intro_restart_and_grade_only_result() -> String:
	var controller_source := FileAccess.get_file_as_string("res://scripts/training/DeckTrainingBattleController.gd")
	var browser_scene := FileAccess.get_file_as_string("res://scenes/deck_training/DeckTrainingBrowser.tscn")
	var browser_script := FileAccess.get_file_as_string("res://scenes/deck_training/DeckTrainingBrowser.gd")
	return run_checks([
		assert_true(controller_source.contains("DeckTrainingIntroOverlay"), "Battle should show a centered intro overlay"),
		assert_false(controller_source.contains("DeckTrainingHud"), "Training should not keep a persistent battle HUD"),
		assert_true(controller_source.contains("button.text = \"重开\""), "Training should replace the AI button with restart"),
		assert_false(controller_source.contains("_full_information_reveal"), "Result must not reveal hidden cards"),
		assert_true(browser_scene.contains("DeckSelector"), "Training list should place deck radio options at the top"),
		assert_true(browser_script.contains("CheckBox.new()"), "Deck selection should use mutually exclusive radio controls"),
		assert_true(browser_script.contains("best_grade"), "Puzzle rows should display the persisted best grade"),
	])


func test_live_two_turn_training_launch_uses_intro_restart_and_rules_ai() -> String:
	var packed := load("res://scenes/battle/BattleScene.tscn") as PackedScene
	if packed == null:
		return "Battle scene must load before the training launch smoke test"
	var scenario := CatalogScript.get_scenario("gardevoir_07")
	var previous_launch: Dictionary = GameManager.peek_deck_training_launch()
	var previous_mode: int = int(GameManager.current_mode)
	var previous_decks: Array[int] = GameManager.selected_deck_ids.duplicate()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.selected_deck_ids = [int(scenario.get("player_deck_id", 0)), int(scenario.get("opponent_deck_id", 0))]
	GameManager.set("_deck_training_launch", {"scenario_id": "gardevoir_07"})
	var tree := Engine.get_main_loop() as SceneTree
	var scene := packed.instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var gsm: GameStateMachine = scene.get("_gsm")
	var controller: DeckTrainingBattleController = scene.get("_deck_training_controller") as DeckTrainingBattleController
	var ai: AIOpponent = scene.get("_ai_opponent") as AIOpponent
	var ai_button: Button = scene.get("_btn_battle_discuss_ai") as Button
	var checks := run_checks([
		assert_not_null(gsm, "Live training should install the restored state machine"),
		assert_not_null(controller, "Live training should install its modal controller"),
		assert_true(controller != null and controller.is_modal_open(), "Intro should be centered and block play until confirmed"),
		assert_eq(ai_button.text if ai_button != null else "", "重开", "The old AI action should become restart in training"),
		assert_not_null(ai, "Training should construct the real opponent AI"),
		assert_eq(ai.decision_runtime_mode if ai != null else "", AIOpponent.DECISION_RUNTIME_RULES_ONLY, "The middle turn should use production rules-only AI"),
	])
	if controller != null and gsm != null:
		scene.set("_ai_action_pause_seconds", 0.0)
		controller.call("_on_intro_confirmed")
		var discard_caption := scene.find_child("MyDiscardHudCaption", true, false) as Label
		var discard_overlay := scene.get("_discard_overlay") as Control
		var discard_click := InputEventMouseButton.new()
		discard_click.button_index = MOUSE_BUTTON_LEFT
		discard_click.pressed = true
		if discard_caption != null:
			discard_caption.emit_signal("gui_input", discard_click)
		var discard_popup_opened := discard_overlay != null and discard_overlay.visible
		if discard_popup_opened:
			scene.call("_close_discard_collection_viewer", "training_test")
		gsm.end_turn(0)
		var ai_action_observed := false
		for _frame: int in 120:
			await tree.process_frame
			for logged: GameAction in gsm.action_log:
				if logged.player_index == 1:
					ai_action_observed = true
					break
			if ai_action_observed or gsm.game_state.is_game_over():
				break
		if gsm.game_state.current_player_index == 1 and not gsm.game_state.is_game_over():
			gsm.end_turn(1)
		checks += run_checks([
			assert_not_null(discard_caption, "Training HUD should expose the clickable discard caption"),
			assert_true(discard_popup_opened, "Clicking the discard caption in deck training must open the collection popup"),
			assert_true(ai_action_observed, "Production rules AI should execute a real action during the mandatory middle turn"),
			assert_eq(gsm.game_state.current_player_index, 0, "After the rules AI middle turn, control should return to the player"),
			assert_false(controller.is_terminal(), "A two-turn puzzle must remain live after only the first player turn"),
		])
	scene.queue_free()
	await tree.process_frame
	GameManager.current_mode = previous_mode
	GameManager.selected_deck_ids = previous_decks
	GameManager.set("_deck_training_launch", previous_launch)
	return checks


func test_live_charizard_middle_turn_creates_the_briar_window() -> String:
	var scenario := CatalogScript.get_scenario("charizard_dragapult_07")
	var built := StateFactoryScript.build(scenario)
	var gsm: GameStateMachine = built.get("gsm", null)
	if gsm == null:
		return "charizard_dragapult_07 failed to build: %s" % JSON.stringify(built.get("errors", []))
	var adapter := WitnessProofAdapterScript.new()
	adapter.configure(scenario)
	var proof_state: Dictionary = adapter.make_initial_state(gsm)
	var reply_prizes := -1
	var reached_offer := false
	var replay_reason := ""
	for _step_index: int in (scenario.get("proof_steps", []) as Array).size():
		var choices: Array = adapter.legal_choices(proof_state).get("choices", [])
		if choices.is_empty():
			replay_reason = "authored choice missing"
			break
		var choice: Dictionary = choices[0]
		var step: Dictionary = choice.get("step", {})
		var transition: Dictionary = adapter.apply_choice(proof_state, choice)
		if not bool(transition.get("ok", false)):
			replay_reason = str(transition.get("reason", "transition rejected"))
			break
		proof_state = transition.get("state", {})
		var witness_gsm: GameStateMachine = proof_state.get("gsm", null)
		if str(step.get("id", "")) == "zoroark_reply" and witness_gsm != null:
			reply_prizes = witness_gsm.game_state.players[1].prizes.size()
		if str(step.get("id", "")) == "offer_prize":
			reached_offer = true
			break
	var live_gsm: GameStateMachine = proof_state.get("gsm", null)
	var briar_in_hand := live_gsm != null and _find_hand_card(live_gsm.game_state.players[0].hand, "白蕾雅") != null
	var briar_legal := live_gsm != null and _contains_action(
		LegalActionBuilderScript.new().build_actions(live_gsm, 0, false),
		"play_trainer",
		"白蕾雅"
	)
	var checks := run_checks([
		assert_true(reached_offer, "The production witness should reach the authored self-KO checkpoint: %s" % replay_reason),
		assert_eq(reply_prizes, 3, "N's Zoroark reply should take exactly one prize before the self-KO"),
		assert_eq(live_gsm.game_state.players[1].prizes.size() if live_gsm != null else -1, 2, "The later Dusknoir self-KO should open Briar's exact two-prize window"),
		assert_true(briar_in_hand, "Briar should have been acquired through the hidden Quick Search route"),
		assert_true(briar_legal, "Briar should become production-legal only at the proven comeback checkpoint"),
	])
	gsm.prepare_for_disposal()
	if live_gsm != null:
		live_gsm.prepare_for_disposal()
	return checks


func _execute_first_authored_step(scenario: Dictionary) -> Dictionary:
	var built := StateFactoryScript.build(scenario)
	var gsm: GameStateMachine = built.get("gsm", null)
	if gsm == null:
		return {
			"ok": false,
			"reason": "state build failed: %s" % JSON.stringify(built.get("errors", [])),
		}
	var adapter := WitnessProofAdapterScript.new()
	adapter.configure(scenario)
	var proof_state: Dictionary = adapter.make_initial_state(gsm)
	var choices: Array = adapter.legal_choices(proof_state).get("choices", [])
	var result := {"ok": false, "reason": "authored proof has no opening step"}
	if not choices.is_empty():
		var choice: Dictionary = choices[0]
		var transition: Dictionary = adapter.apply_choice(proof_state, choice)
		result = {
			"ok": bool(transition.get("ok", false)),
			"reason": str(transition.get("reason", "")),
			"step": choice.get("step", {}),
		}
	var witness_gsm: GameStateMachine = proof_state.get("gsm", null)
	gsm.prepare_for_disposal()
	if witness_gsm != null:
		witness_gsm.prepare_for_disposal()
	return result


func _prove_authored_scenario(scenario: Dictionary) -> Dictionary:
	var built := StateFactoryScript.build(scenario)
	var gsm: GameStateMachine = built.get("gsm", null)
	if gsm == null:
		return {
			"status": ProofSolverScript.STATUS_INCONCLUSIVE,
			"reason": "state build failed: %s" % JSON.stringify(built.get("errors", [])),
		}
	var adapter := WitnessProofAdapterScript.new()
	adapter.configure(scenario)
	var initial_state: Dictionary = adapter.make_initial_state(gsm)
	var certificate := ProofSolverScript.new().prove(
		initial_state,
		adapter,
		{
			"max_depth": maxi(8, (scenario.get("proof_steps", []) as Array).size() + 4),
			"max_nodes": 512,
			"max_milliseconds": 30000,
			"require_unique_root": true,
			"collect_all_player_branches": true,
		}
	)
	var witness_gsm: GameStateMachine = initial_state.get("gsm", null)
	gsm.prepare_for_disposal()
	if witness_gsm != null:
		witness_gsm.prepare_for_disposal()
	return certificate


func _contains_action(actions: Array[Dictionary], kind: String, subject_name: String) -> bool:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) != kind:
			continue
		var card: Variant = action.get("card", null)
		if card is CardInstance and (card as CardInstance).card_data != null and (card as CardInstance).card_data.name == subject_name:
			return true
		var slot: Variant = action.get("source_slot", null)
		if slot is PokemonSlot and (slot as PokemonSlot).get_pokemon_name() == subject_name:
			return true
	return false


func _execute_generic_route_prefix(gsm: GameStateMachine, deck_key: String) -> Dictionary:
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	if deck_key == "raging_bolt":
		var raging: PokemonSlot = player.bench[0]
		var ogerpon: PokemonSlot = player.bench[1]
		var grasses := _find_hand_cards(player.hand, "基本草能量")
		var sada := _find_hand_card(player.hand, "奥琳博士的气魄")
		var prime := _find_hand_card(player.hand, "顶尖捕捉器")
		var fighting := _find_zone_card(player.discard_pile, "基本斗能量")
		if grasses.size() < 2 or sada == null or prime == null or fighting == null:
			return {"executed": 0, "reason": "missing raging bolt route resources"}
		var executed := 0
		executed += 1 if gsm.use_ability(0, ogerpon, 0, [{"basic_energy_from_hand": [grasses[0]]}]) else 0
		executed += 1 if gsm.play_trainer(0, sada, [{"sada_assignments": [{"source": fighting, "target": raging}]}]) else 0
		executed += 1 if gsm.attach_energy(0, grasses[1], ogerpon) else 0
		executed += 1 if gsm.play_trainer(0, prime, [{"opponent_bench_target": [opponent.bench[0]], "own_bench_target": [raging]}]) else 0
		return {"executed": executed}

	var attacker: PokemonSlot = player.bench[0]
	var evolution_names := {
		"gardevoir": "沙奈朵ex",
		"gholdengo": "赛富豪ex",
		"marnie": "玛俐的长毛巨魔ex",
		"n_zoroark": "N的索罗亚克ex",
		"charizard_dragapult": "多龙巴鲁托ex",
	}
	var energy_names := {
		"gardevoir": "基本超能量",
		"gholdengo": "基本钢能量",
		"marnie": "基本恶能量",
		"n_zoroark": "基本恶能量",
		"charizard_dragapult": "基本火能量",
	}
	var evolution := _find_hand_card(player.hand, str(evolution_names.get(deck_key, "")))
	var energy := _find_hand_card(player.hand, str(energy_names.get(deck_key, "")))
	var catcher := _find_hand_card(player.hand, "反击捕捉器")
	if evolution == null or energy == null or catcher == null:
		return {"executed": 0, "reason": "missing evolve/energy/catcher resources"}
	var count := 0
	count += 1 if gsm.evolve_pokemon(0, evolution, attacker) else 0
	count += 1 if gsm.attach_energy(0, energy, attacker) else 0
	count += 1 if gsm.play_trainer(0, catcher, [{"opponent_bench_target": [opponent.bench[0]]}]) else 0
	if deck_key == "gholdengo":
		var switch_card := _find_hand_card(player.hand, "宝可梦交替")
		count += 1 if switch_card != null and gsm.play_trainer(0, switch_card, [{"self_switch_target": [attacker]}]) else 0
	else:
		var retreat_action: Dictionary = {}
		for action: Dictionary in LegalActionBuilderScript.new().build_actions(gsm, 0, false):
			if str(action.get("kind", "")) == "retreat" and action.get("bench_target", null) == attacker:
				retreat_action = action
				break
		count += 1 if not retreat_action.is_empty() and gsm.retreat(0, retreat_action.get("energy_to_discard", []), attacker) else 0
	return {"executed": count}


func _find_hand_card(cards: Array[CardInstance], name: String) -> CardInstance:
	return _find_zone_card(cards, name)


func _find_zone_card(cards: Array[CardInstance], name: String) -> CardInstance:
	for card: CardInstance in cards:
		if card != null and card.card_data != null and card.card_data.name == name:
			return card
	return null


func _find_hand_cards(cards: Array[CardInstance], name: String) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for card: CardInstance in cards:
		if card != null and card.card_data != null and card.card_data.name == name:
			result.append(card)
	return result


func _prepare_attack_targets(action: Dictionary, gsm: GameStateMachine, deck_key: String) -> void:
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	match deck_key:
		"gholdengo":
			action["targets"] = [{"discard_basic_energy": _basic_energies_in_hand(player.hand)}]
		"raging_bolt":
			var attached: Array[CardInstance] = []
			for slot: PokemonSlot in player.get_all_pokemon():
				for energy: CardInstance in slot.attached_energy:
					if energy.card_data != null and energy.card_data.card_type == "Basic Energy":
						attached.append(energy)
			action["targets"] = [{"discard_basic_energy": attached}]
		"charizard_dragapult":
			if not opponent.bench.is_empty():
				action["targets"] = [{"bench_damage_counters": [{"target": opponent.bench[0], "amount": 60}]}]
		"marnie":
			if not opponent.bench.is_empty():
				action["targets"] = [{"opponent_bench_damage_targets": [opponent.bench[0]]}]
		"n_zoroark":
			var source_slot: PokemonSlot = null
			for slot: PokemonSlot in player.bench:
				if slot.get_pokemon_name() == "N的莱希拉姆":
					source_slot = slot
					break
			if source_slot != null:
				var source_card := source_slot.get_top_card()
				var copied_attack: Dictionary = source_slot.get_attacks()[1]
				action["targets"] = [{"copied_attack": [{
					"source_card": source_card,
					"source_effect_id": source_card.card_data.effect_id,
					"source_zone": "bench",
					"attack_index": 1,
					"attack": copied_attack,
					"source_slot": source_slot,
				}]}]


func _basic_energies_in_hand(cards: Array[CardInstance]) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for card: CardInstance in cards:
		if card != null and card.card_data != null and card.card_data.card_type == "Basic Energy":
			result.append(card)
	return result


func _resolve_player_prizes(gsm: GameStateMachine) -> void:
	var slot_index := 0
	while int(gsm.get("_pending_prize_remaining")) > 0 and slot_index < 6:
		if gsm.resolve_take_prize(0, slot_index):
			slot_index += 1
		else:
			slot_index += 1


func _read_json(path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		return {}
	return json.data as Dictionary


func _deck_total(deck: Dictionary) -> int:
	var total := 0
	for entry: Variant in deck.get("cards", []):
		if entry is Dictionary:
			total += int((entry as Dictionary).get("count", 0))
	return total
