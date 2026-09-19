extends TestBase

const Loader = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd")
const DeckGate = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyDeckGate.gd")
const Handle = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageHandle.gd")
const Factory = preload("res://scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd")
const Gate = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsExecutionGate.gd")
const Bridge = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const RulesAI = preload("res://scripts/ai/AIOpponent.gd")
const Registry = preload("res://scripts/ai/DeckStrategyRegistry.gd")

var package_override := ""
var seed_override := -1
var execution_profile := "worker_v1"
var capture_trace := false
var last_report: Dictionary = {}


func test_current_rules_and_model_packages_complete_both_seats_without_unexpected_fallbacks() -> String:
	var errors: Array[String] = []
	for modeled: bool in [false, true]:
		for seat: int in [0,1]:
			var error := await _match(modeled, seat)
			if not error.is_empty(): errors.append(error)
	return "\n".join(errors)


func _match(modeled: bool, seat: int) -> String:
	last_report = {}
	var path := "res://tests/ai/ptcgdap/fixtures/platform_model.ptcgai" if modeled else "res://data/ptcgdap/author_strategy_package_backups/reviewed-raging-bolt-ogerpon-1.0.0-round30-20ED94DE.ptcgai"
	if not package_override.is_empty(): path = package_override
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty(): return "Fixture is missing or empty: " + path
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	var inspected: Dictionary = Loader.new().inspect_control_distributed_player_match_bytes(bytes, digest.finish().hex_encode().to_upper())
	if not inspected.get("ok", false): return "Fixture rejected: %s" % inspected
	var mapped := DeckGate.build(inspected.payloads)
	if not mapped.get("ok", false): return "Deck rejected: %s" % mapped
	var created := Handle.create(inspected.metadata, inspected.payloads, mapped.local_deck)
	if not created.get("ok", false): return "Handle rejected: %s" % created
	var materialized: Dictionary = GameManager.materialize_author_strategy_battle_deck(created.handle)
	if not materialized.get("ok", false): return "Deck materialization failed: %s" % materialized
	var author_deck: DeckData = materialized.deck
	var rules_deck: DeckData = CardDatabase.get_deck(575720)
	if rules_deck == null: return "Bundled opponent deck missing"
	var seeder := PlayerState.new()
	var match_seed := seed_override if seed_override >= 0 else 84590 + seat
	seed(match_seed)
	seeder.set_forced_shuffle_seed(match_seed)
	var gsm := GameStateMachine.new()
	gsm.random_event_port.configure_seed(match_seed)
	gsm.start_game(author_deck if seat == 0 else rules_deck, rules_deck if seat == 0 else author_deck, 0)
	var built := Factory.build_windows_author_owner(created.handle, gsm, seat, "platform-%s-%d" % [modeled,seat], Gate.CONTROL_DISTRIBUTED_MODE)
	if not built.get("ok", false):
		seeder.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
		return "Player owner rejected: %s" % built
	var owner: Variant = built.owner
	owner.configure_policy_execution_profile(execution_profile)
	owner.set("_developer_trace_enabled", capture_trace)
	var trace: Array = []
	var rules := RulesAI.new()
	rules.configure(1-seat, 1)
	Registry.new().apply_strategy_for_deck(rules, rules_deck)
	rules.use_mcts = false
	rules.decision_runtime_mode = RulesAI.DECISION_RUNTIME_RULES_ONLY
	var bridge := Bridge.new()
	bridge.bind(gsm)
	bridge.set_ai_controllers(owner if seat == 0 else rules, rules if seat == 0 else owner)
	bridge.bootstrap_pending_setup()
	var steps := 0
	var failure := ""
	var policy_error_counts := {}
	var previous_policy_errors := 0
	var started := Time.get_ticks_msec()
	var tree := Engine.get_main_loop() as SceneTree
	while not gsm.game_state.is_game_over() and steps < 1000:
		if Time.get_ticks_msec() - started > 240000:
			failure = "match timeout"
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
		if capture_trace: trace.append_array(owner.drain_developer_decision_records())
		if not progressed:
			if owner.has_pending_policy_decision():
				await tree.process_frame
				continue
			failure = "no progress step=%d prompt=%s" % [steps, bridge.get_pending_prompt_type()]
			break
		steps += 1
		var current_policy_errors := int(owner.get("_policy_errors"))
		if current_policy_errors > previous_policy_errors:
			var code := str(owner.get("_last_error_code"))
			policy_error_counts[code] = int(policy_error_counts.get(code, 0)) + current_policy_errors - previous_policy_errors
			previous_policy_errors = current_policy_errors
		if steps % 16 == 0: await tree.process_frame
	var audit: Dictionary = owner.audit_snapshot()
	var ended := gsm.game_state.is_game_over()
	var summary := {"platform":OS.get_name(), "modeled":modeled, "seat":seat, "steps":steps,
		"game_over":ended, "failure":failure, "model_successes":audit.get("model_inference_successes", 0),
		"last_error_code":audit.get("last_error_code"), "model_diagnostic_counts":audit.get("model_diagnostic_counts"),
		"policy_error_counts":policy_error_counts,
		"policy_errors":audit.get("policy_errors", 0), "engine_rejections":audit.get("engine_rejections", 0),
		"invalid_outputs":audit.get("invalid_outputs", 0), "worker_start_failures":audit.get("policy_worker_start_failures", 0),
		"worker_stale_results":audit.get("policy_worker_stale_results", 0), "policy_successes":audit.get("policy_successes", 0),
		"same_window_fallbacks":audit.get("same_window_fallbacks", 0)}
	print("PLATFORM_MATCH " + JSON.stringify(summary))
	last_report = {"summary":summary, "audit":audit, "trace":trace, "seed":match_seed,
		"winner":gsm.game_state.winner_index, "execution_profile":execution_profile,
		"package_sha256":FileAccess.get_sha256(path).to_upper(), "standalone_export":OS.has_feature("template")}
	owner.close_match()
	bridge.free()
	gsm.prepare_for_disposal()
	seeder.clear_forced_shuffle_seed()
	return run_checks([
		assert_eq(failure, "", str(summary)), assert_true(ended, str(summary)),
		assert_true(policy_error_counts.is_empty(), str(summary)),
		assert_eq(int(summary.same_window_fallbacks), 0, str(summary)),
		assert_eq(int(summary.worker_stale_results), 0, str(summary)),
		assert_eq(int(summary.engine_rejections), 0, str(summary)),
		assert_eq(int(summary.invalid_outputs), 0, str(summary)),
		assert_eq(int(summary.worker_start_failures), 0, str(summary)),
		assert_true(int(summary.policy_successes) > 0, str(summary)),
		assert_true(not modeled or int(summary.model_successes) > 0, str(summary)),
	])
