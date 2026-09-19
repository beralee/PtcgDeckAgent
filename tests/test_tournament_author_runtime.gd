extends TestBase

const Pool = preload("res://scripts/tournament/TournamentAuthorStrategyPool.gd")
const Swiss = preload("res://scripts/tournament/SwissTournament.gd")
const Setup = preload("res://scenes/tournament/TournamentSetup.tscn")
const Overview = preload("res://scenes/tournament/TournamentOverview.tscn")
const Standings = preload("res://scenes/tournament/TournamentStandings.tscn")
const Factory = preload("res://scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd")
const Bridge = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const RulesAI = preload("res://scripts/ai/AIOpponent.gd")
const Registry = preload("res://scripts/ai/DeckStrategyRegistry.gd")

func _new_tournament() -> bool:
	GameManager.clear_tournament()
	GameManager.set_tournament_selected_player_deck_id(575720)
	return GameManager.start_swiss_tournament("测试选手", 16, "open", "author")

func test_local_packages_launch_exact_author_mode_then_builtin_without_selection_leaks() -> String:
	if not _new_tournament(): return "No admitted shipped package: " + GameManager.tournament_start_error
	var ready := GameManager.prepare_current_tournament_battle()
	var selection := GameManager.get_author_strategy_selection()
	var deck := GameManager.resolve_selected_battle_deck(1)
	var checks: Array[String] = [assert_true(ready), assert_eq(GameManager.current_mode, GameManager.GameMode.VS_AUTHOR_STRATEGY_AI), assert_false(selection.is_empty()), assert_not_null(deck), assert_eq(GameManager.first_player_choice, -1)]
	if deck != null: checks.append(assert_eq(deck.total_cards, 60))
	GameManager.finalize_current_tournament_battle(0, "测试完成")
	GameManager.start_swiss_tournament("测试选手", 16, "open", "builtin")
	checks.append(assert_true(GameManager.prepare_current_tournament_battle()))
	checks.append(assert_eq(GameManager.current_mode, GameManager.GameMode.VS_AI))
	checks.append(assert_true(GameManager.get_author_strategy_selection().is_empty()))
	GameManager.clear_tournament()
	return run_checks(checks)

func test_missing_exact_package_preserves_round_save_and_both_retry_screens() -> String:
	if not _new_tournament(): return GameManager.tournament_start_error
	var tournament = GameManager.current_tournament
	var pairing: Dictionary = tournament.prepare_next_round()
	var opponent_id := int(pairing.player_b_id) if int(pairing.player_a_id) == 0 else int(pairing.player_a_id)
	var original: Dictionary = tournament.participant_author_selection(opponent_id)
	tournament.participants[opponent_id].author_strategy_selection.archive_sha256 = "F".repeat(64)
	var before := JSON.stringify(tournament.serialize_state())
	GameManager.set_scene_navigation_suppressed_for_tests(true)
	GameManager.consume_last_requested_scene_path()
	var overview: Control = Overview.instantiate()
	overview.call("_on_start_round_pressed")
	var standings: Control = Standings.instantiate()
	standings.call("_on_primary_pressed")
	var checks: Array[String] = [assert_eq(GameManager.consume_last_requested_scene_path(), ""), assert_true(GameManager.has_active_tournament()), assert_false(GameManager.is_tournament_battle_active()), assert_eq(JSON.stringify(tournament.serialize_state()), before), assert_true(overview.get_node("%StartError").visible), assert_true(standings.get_node("%StartError").visible)]
	GameManager.reload_tournament_state_from_disk()
	checks.append(assert_eq(GameManager.current_tournament.current_round, 1))
	checks.append(assert_eq(int(GameManager.current_tournament.participants[0].losses), 0, "Failed preflight must not be a technical loss"))
	GameManager.current_tournament.participants[opponent_id].author_strategy_selection = original
	checks.append(assert_true(GameManager.prepare_current_tournament_battle(), "Restoring the exact package must allow retry"))
	checks.append(assert_eq(GameManager.current_tournament.current_round, 1))
	GameManager.forfeit_current_tournament_battle("技术负测试")
	checks.append(assert_eq(int(GameManager.current_tournament.participants[0].losses), 1))
	overview.free()
	standings.free()
	GameManager.set_scene_navigation_suppressed_for_tests(false)
	GameManager.clear_tournament()
	return run_checks(checks)

func test_setup_offers_developer_and_mixed_rosters_with_hud_buttons() -> String:
	var scene: Control = Setup.instantiate()
	scene.call("_setup_opponent_options")
	var group: Node = scene.get_node("%OpponentSourceGroup")
	var checks: Array[String] = [assert_eq(group.get_child_count(), 3), assert_eq(scene.get("_opponent_source"), "mixed")]
	var button := group.get_node("OpponentSourceAuthor") as Button
	checks.append(assert_false(button.disabled))
	button.pressed.emit()
	checks.append(assert_eq(scene.get("_opponent_source"), "author"))
	scene.free()
	return run_checks(checks)

func test_developer_tournament_completes_four_real_engine_matches_and_reload() -> String:
	# FocusedSuiteRunner starts in SceneTree._initialize; let autoload _ready
	# finish its startup save recovery before creating a live tournament.
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	if not _new_tournament(): return GameManager.tournament_start_error
	var errors: Array[String] = []
	for round_index: int in 4:
		if not GameManager.prepare_current_tournament_battle():
			errors.append(GameManager.tournament_start_error)
			break
		var result := await _play_round(93200 + round_index)
		if not str(result.get("error", "")).is_empty():
			errors.append(result.error)
			break
		var summary := GameManager.finalize_current_tournament_battle(int(result.winner), "实战测试")
		if summary.is_empty(): errors.append("Missing tournament settlement")
		GameManager.reload_tournament_state_from_disk()
		if GameManager.current_tournament.current_round != round_index + 1: errors.append("Round number lost after reload")
	if not GameManager.current_tournament.finished: errors.append("Four rounds did not finish tournament")
	for participant: Dictionary in GameManager.current_tournament.participants:
		if int(participant.wins) + int(participant.losses) != 4: errors.append("Incomplete standings")
	GameManager.clear_tournament()
	return "\n".join(errors)

func _play_round(match_seed: int) -> Dictionary:
	var checked := Pool.resolve(AuthorStrategyPackageCatalog, GameManager.get_author_strategy_selection())
	if not checked.get("ok", false): return {"error": str(checked)}
	var player_deck := GameManager.resolve_selected_battle_deck(0)
	var seeder := PlayerState.new()
	seed(match_seed)
	seeder.set_forced_shuffle_seed(match_seed)
	var gsm := GameStateMachine.new()
	gsm.random_event_port.configure_seed(match_seed)
	gsm.start_game(player_deck, checked.deck, match_seed % 2)
	var built := Factory.build_windows_author_owner(checked.handle, gsm, 1, "tournament-%d" % match_seed, checked.authority_mode)
	if not built.get("ok", false):
		gsm.prepare_for_disposal()
		seeder.clear_forced_shuffle_seed()
		return {"error": str(built)}
	var owner: Variant = built.owner
	owner.configure_policy_execution_profile("worker_v1")
	owner.set("_developer_trace_enabled", false)
	var player := RulesAI.new()
	player.configure(0, 1)
	Registry.new().apply_strategy_for_deck(player, player_deck)
	player.use_mcts = false
	player.decision_runtime_mode = RulesAI.DECISION_RUNTIME_RULES_ONLY
	var bridge := Bridge.new()
	bridge.bind(gsm)
	bridge.set_ai_controllers(player, owner)
	bridge.bootstrap_pending_setup()
	var steps := 0
	var failure := ""
	var started := Time.get_ticks_msec()
	var tree := Engine.get_main_loop() as SceneTree
	while not gsm.game_state.is_game_over() and steps < 1200:
		if Time.get_ticks_msec() - started > 240000:
			failure = "Match timed out"
			break
		var progressed := false
		if bridge.has_pending_prompt():
			if bridge.get_pending_prompt_owner() == 1: progressed = bool(owner.run_single_step(bridge, gsm))
			elif bridge.can_resolve_pending_prompt(): progressed = bridge.resolve_pending_prompt()
			else: progressed = player.run_single_step(bridge, gsm)
		else:
			progressed = bool(owner.run_single_step(bridge, gsm)) if gsm.game_state.current_player_index == 1 else player.run_single_step(bridge, gsm)
		if not progressed:
			if owner.has_pending_policy_decision():
				await tree.process_frame
				continue
			failure = "No progress at step %d, prompt %s" % [steps, bridge.get_pending_prompt_type()]
			break
		steps += 1
		if steps % 16 == 0: await tree.process_frame
	var audit: Dictionary = owner.audit_snapshot()
	var report := {"seed": match_seed, "steps": steps, "winner": gsm.game_state.winner_index, "game_over": gsm.game_state.is_game_over(), "policy_successes": audit.get("policy_successes", 0), "policy_errors": audit.get("policy_errors", 0), "engine_rejections": audit.get("engine_rejections", 0), "invalid_outputs": audit.get("invalid_outputs", 0), "same_window_fallbacks": audit.get("same_window_fallbacks", 0), "error": failure}
	if not report.game_over: report.error += " Match unfinished"
	for key: String in ["policy_errors", "engine_rejections", "invalid_outputs", "same_window_fallbacks"]:
		if int(report[key]) != 0: report.error += " Unexpected " + key
	if int(report.policy_successes) <= 0: report.error += " No author decisions"
	print("TOURNAMENT_REAL_MATCH " + JSON.stringify(report))
	owner.close_match()
	bridge.free()
	gsm.prepare_for_disposal()
	seeder.clear_forced_shuffle_seed()
	return report


func test_recovery_startup_failure_after_preflight_returns_to_tournament_without_forfeit() -> String:
	if not _new_tournament(): return GameManager.tournament_start_error
	GameManager.set_scene_navigation_suppressed_for_tests(true)
	var checks: Array[String] = []
	for round_index: int in 2:
		checks.append(assert_true(GameManager.prepare_current_tournament_battle()))
		var selection := GameManager.get_author_strategy_selection()
		selection.archive_sha256 = "F".repeat(64)
		GameManager.set_author_strategy_selection(selection)
		var battle: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
		battle.call("_start_battle")
		checks.append(assert_false(GameManager.is_tournament_battle_active()))
		checks.append(assert_eq(GameManager.consume_last_requested_scene_path(), GameManager.SCENE_TOURNAMENT_OVERVIEW if round_index == 0 else GameManager.SCENE_TOURNAMENT_STANDINGS))
		checks.append(assert_false(GameManager.tournament_start_error.is_empty()))
		checks.append(assert_eq(int(GameManager.current_tournament.participants[0].losses), 0))
		checks.append(assert_true(GameManager.prepare_current_tournament_battle()))
		GameManager.finalize_current_tournament_battle(0, "重试成功")
		battle.free()
	GameManager.set_scene_navigation_suppressed_for_tests(false)
	GameManager.clear_tournament()
	return run_checks(checks)


func test_recovery_disabled_developer_mode_excludes_pool_and_preserves_existing_tournament() -> String:
	GameManager.clear_tournament()
	GameManager.set_tournament_selected_player_deck_id(575720)
	GameManager.start_swiss_tournament("内置选手", 16, "open")
	var original = GameManager.current_tournament
	const SETTING := "ptcgdap/author_strategy/enabled"
	var old_value: Variant = ProjectSettings.get_setting(SETTING, true)
	ProjectSettings.set_setting(SETTING, false)
	var scene: Control = Setup.instantiate()
	scene.call("_setup_opponent_options")
	var checks: Array[String] = [assert_true(Pool.collect(AuthorStrategyPackageCatalog).is_empty()), assert_eq(scene.get("_opponent_source"), "builtin"), assert_true(scene.get_node("%OpponentSourceGroup/OpponentSourceAuthor").disabled), assert_false(GameManager.start_swiss_tournament("新选手", 16, "open", "author")), assert_eq(GameManager.current_tournament, original), assert_false(GameManager.tournament_start_error.is_empty())]
	ProjectSettings.set_setting(SETTING, old_value)
	scene.free()
	GameManager.clear_tournament()
	return run_checks(checks)
