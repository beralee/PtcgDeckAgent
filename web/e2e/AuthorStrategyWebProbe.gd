extends RefCounted

## Test-export-only acceptance: use an installed, revalidated package through
## the real player owner and complete a seeded match on each seat.
const Gate = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsExecutionGate.gd")
const Setup = preload("res://scripts/ui/battle/author_strategy/AuthorStrategySetupModel.gd")
const Factory = preload("res://scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd")
const Bridge = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const Registry = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func run(tree: SceneTree, package_id: String, version: String) -> Dictionary:
	var catalog: Node = tree.root.get_node("AuthorStrategyPackageCatalog")
	var manager: Node = tree.root.get_node("GameManager")
	var database: Node = tree.root.get_node("CardDatabase")
	var record: Dictionary = {}
	for candidate: Dictionary in catalog.list_ready_records():
		if candidate.get("package_id") == package_id and candidate.get("package_version") == version:
			record = candidate
			break
	var selected := Setup.setup_selection_record(record)
	var reports: Array = []
	for seat: int in [0, 1]:
		# Handles carry one-match authority: reacquire and revalidate every game.
		var admitted := Gate.request_match_handle(catalog, selected)
		if not admitted.get("ok", false):
			return {"done":true, "error":admitted.get("error_code"), "matches":reports}
		var handle: Variant = admitted.handle
		var materialized: Dictionary = manager.materialize_author_strategy_battle_deck(handle)
		if not materialized.get("ok", false):
			return {"done":true, "error":materialized.get("error_code"), "matches":reports}
		var deck: DeckData = materialized.deck
		var opponent: DeckData = database.get_deck(575720)
		var match_seed := 84590 + seat
		var seeder := PlayerState.new()
		seed(match_seed)
		seeder.set_forced_shuffle_seed(match_seed)
		var gsm := GameStateMachine.new()
		gsm.random_event_port.configure_seed(match_seed)
		gsm.start_game(deck if seat == 0 else opponent, opponent if seat == 0 else deck, 0)
		var built := Factory.build_windows_author_owner(handle, gsm, seat, "web-probe-%d" % seat, str(admitted.authority_mode))
		if not built.get("ok", false):
			gsm.prepare_for_disposal()
			seeder.clear_forced_shuffle_seed()
			return {"done":true, "error":built.get("error_code"), "matches":reports}
		var owner: Variant = built.owner
		owner.configure_policy_execution_profile("worker_v1")
		var rules := AIOpponent.new()
		rules.configure(1 - seat, 1)
		Registry.new().apply_strategy_for_deck(rules, opponent)
		rules.use_mcts = false
		rules.decision_runtime_mode = AIOpponent.DECISION_RUNTIME_RULES_ONLY
		var bridge := Bridge.new()
		bridge.bind(gsm)
		bridge.set_ai_controllers(owner if seat == 0 else rules, rules if seat == 0 else owner)
		bridge.bootstrap_pending_setup()
		var steps := 0
		var failure := ""
		var started := Time.get_ticks_msec()
		while not gsm.game_state.is_game_over() and steps < 1000:
			if Time.get_ticks_msec() - started > 240000:
				failure = "match_timeout"
				break
			var progressed := false
			if bridge.has_pending_prompt():
				if bridge.get_pending_prompt_owner() == seat:
					progressed = bool(owner.run_single_step(bridge, gsm))
				elif bridge.can_resolve_pending_prompt():
					progressed = bridge.resolve_pending_prompt()
				else:
					progressed = rules.run_single_step(bridge, gsm)
			else:
				progressed = bool(owner.run_single_step(bridge, gsm)) if gsm.game_state.current_player_index == seat else rules.run_single_step(bridge, gsm)
			if not progressed and not owner.has_pending_policy_decision():
				failure = "no_progress:%s" % bridge.get_pending_prompt_type()
				break
			if progressed:
				steps += 1
			await tree.process_frame
		var audit: Dictionary = owner.audit_snapshot()
		var report := {"seat":seat, "seed":match_seed, "steps":steps, "game_over":gsm.game_state.is_game_over(), "error":failure}
		var timings: Array = audit.get("decision_elapsed_usec", [])
		report["decision_max_msec"] = float(timings.max()) / 1000.0 if not timings.is_empty() else 0.0
		for field: String in ["policy_execution_profile", "policy_successes", "policy_errors", "engine_rejections", "invalid_outputs", "same_window_fallbacks", "policy_worker_start_failures", "policy_worker_stale_results", "last_error_code"]:
			report[field] = audit.get(field)
		reports.append(report)
		owner.close_match()
		bridge.free()
		gsm.prepare_for_disposal()
		seeder.clear_forced_shuffle_seed()
	return {"done":true, "error":"", "platform":OS.get_name(), "matches":reports}
