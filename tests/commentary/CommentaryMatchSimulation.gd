extends Node
## Development-only real match capture. Private replay stays local; commentary
## receives only the production positive-list projection.
const Projector = preload("res://scripts/commentary/CommentaryPublicProjector.gd")
const Snapshot = preload("res://scripts/engine/scenario/ScenarioStateSnapshot.gd")
const Pool = preload("res://scripts/tournament/TournamentAuthorStrategyPool.gd")
const Factory = preload("res://scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd")
var output_root := "res://.tmp/commentary_match_20260929"
var events: Array = []
var public_events: Array = []
var sequence := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	var match_seed := 20260929
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-root="): output_root = argument.trim_prefix("--output-root=")
		if argument.begins_with("--match-seed="): match_seed = int(argument.trim_prefix("--match-seed="))
	var catalog_report: Dictionary = AuthorStrategyPackageCatalog.scan_startup()
	print("USER_DIRECTORY ", OS.get_user_data_dir(), " CATALOG_DIAGNOSTICS ", JSON.stringify(catalog_report.get("diagnostics", [])))
	var selection := {"package_id":"dev.dragapult-dusknoir", "package_version":"0.9.1", "archive_sha256":"CF196388C350C2D1D81DE05682F03A09F60D5CB8DFA06C48E3C8EE6E56A4DDB4", "install_source":"user"}
	var checked := Pool.resolve(AuthorStrategyPackageCatalog, selection)
	if not checked.get("ok", false):
		push_error("Exact strategy unavailable: " + str(checked.get("error_code")))
		get_tree().quit(1)
		return
	var deck: DeckData = CardDatabase.get_deck(675700)
	seed(match_seed)
	var seeder := PlayerState.new()
	seeder.set_forced_shuffle_seed(match_seed)
	var gsm := GameStateMachine.new()
	gsm.random_event_port.configure_seed(match_seed)
	gsm.action_logged.connect(func(action: GameAction):
		sequence += 1
		public_events.append(Projector.event(action, sequence))
		events.append({"type":int(action.action_type), "player":action.player_index, "turn":action.turn_number, "data":action.data.duplicate(true), "description":action.description})
	)
	gsm.start_game(deck, checked.deck, 0)
	var built := Factory.build_windows_author_owner(checked.handle, gsm, 1, "commentary-demo-20260929", checked.authority_mode)
	if not built.get("ok", false):
		push_error("Owner unavailable: " + str(built.get("error_code")))
		get_tree().quit(1)
		return
	var owner: Variant = built.owner
	owner.configure_policy_execution_profile("worker_v1")
	owner.set("_developer_trace_enabled", false)
	var player := AIOpponent.new()
	player.configure(0, 1)
	preload("res://scripts/ai/DeckStrategyRegistry.gd").new().apply_strategy_for_deck(player, deck)
	player.use_mcts = false
	player.decision_runtime_mode = AIOpponent.DECISION_RUNTIME_RULES_ONLY
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	bridge.set_ai_controllers(player, owner)
	bridge.bootstrap_pending_setup()
	var frames: Array = []
	var public_frames: Array = []
	var steps := 0
	var failure := ""
	var started := Time.get_ticks_msec()
	while not gsm.game_state.is_game_over() and steps < 1800:
		if Time.get_ticks_msec()-started > 300000:
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
				await get_tree().process_frame
				continue
			failure = "No progress at %d, %s" % [steps, bridge.get_pending_prompt_type()]
			break
		steps += 1
		if not public_events.is_empty():
			var state := Projector.snapshot(gsm.game_state)
			public_frames.append({"step":steps,"state":state,"events":public_events.duplicate(true),"pending":bridge.has_pending_prompt()})
			frames.append({"step":steps,"state":Snapshot.capture(gsm.game_state),"events":events.duplicate(true),"public_hash":JSON.stringify(state).sha256_text()})
			events.clear()
			public_events.clear()
		if steps % 20 == 0:
			print("MATCH_PROGRESS step=%d turn=%d" % [steps, gsm.game_state.turn_number])
			await get_tree().process_frame
	var audit: Dictionary = owner.audit_snapshot()
	var report := {"seed":match_seed,"decks":[675700,675701],"selection":selection,"steps":steps,"turns":gsm.game_state.turn_number,"winner":gsm.game_state.winner_index,"reason":gsm.game_state.win_reason,"complete":gsm.game_state.is_game_over(),"error":failure,"policy_successes":audit.get("policy_successes",0),"policy_errors":audit.get("policy_errors",0),"engine_rejections":audit.get("engine_rejections",0),"same_window_fallbacks":audit.get("same_window_fallbacks",0),"paid_api_requests":0}
	DirAccess.make_dir_recursive_absolute(output_root)
	FileAccess.open(output_root+"/private_replay.json", FileAccess.WRITE).store_string(JSON.stringify({"report":report,"frames":frames}))
	FileAccess.open(output_root+"/public_match.json", FileAccess.WRITE).store_string(JSON.stringify({"report":report,"frames":public_frames}))
	FileAccess.open(output_root+"/report.json", FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MATCH_COMPLETE ",JSON.stringify(report))
	owner.close_match()
	bridge.free()
	gsm.prepare_for_disposal()
	seeder.clear_forced_shuffle_seed()
	get_tree().quit(0 if report.complete and failure.is_empty() else 1)
