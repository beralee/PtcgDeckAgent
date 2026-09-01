extends Control

const MARNIE_DECK_ID := 800018501
const RULES_AI_DECK_ID := 575720
const PACKAGE_ID := "ptcgdap.marnie.windows-local"
const PACKAGE_VERSION := "0.1.0"
const PACKAGE_ARCHIVE_SHA256 := "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
const DEFAULT_GAMES := 10
const DEFAULT_SEED_BASE := 84400
const DEFAULT_MAX_STEPS := 700
const GateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd")
const OwnerScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")
const CatalogScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")

const PINNED_SOURCE_PATHS := [
	"res://data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai",
	"res://data/bundled_user/decks/800018501.json",
	"res://data/bundled_user/decks/575720.json",
	"res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd",
	"res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd",
	"res://scripts/ai/ptcgdap/host/godot/AuthorStrategyEngineActionExecutor.gd",
	"res://scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd",
	"res://scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd",
	"res://data/ptcgdap/marnie_windows_policy_package_v1.json",
	"res://contracts/ptcgdap/policy_package_v1.schema.json",
	"res://contracts/ptcgdap/policy_package_v1_profile.json",
	"res://contracts/ptcgdap/policy_package_v1_bundle.json",
	"res://scripts/ai/AILegalActionBuilder.gd",
	"res://scripts/ai/AIStepResolver.gd",
	"res://scripts/ai/HeadlessMatchBridge.gd",
	"res://scripts/autoload/GameManager.gd",
	"res://scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd",
	"res://scripts/ui/battle/ai/BattleAIWatchdog.gd",
	"res://scenes/battle/BattleSceneRuntime.gd",
	"res://scenes/battle/runtime/BattleSceneRuntimeFoundation.gd",
	"res://scenes/battle/runtime/BattleSceneSetupEffectAiRuntime.gd",
	"res://scenes/battle/runtime/BattleSceneSharedHudAiRuntime.gd",
	"res://scenes/battle/runtime/BattleSceneDialogInteractionReviewRuntime.gd",
	"res://scenes/battle/runtime/BattleSceneBoardActionRuntime.gd",
	"res://scenes/battle_setup/BattleSetup.gd",
	"res://scripts/ui/battle/BattleDialogController.gd",
	"res://scripts/ui/battle/BattleDrawRevealController.gd",
	"res://scripts/ui/battle/BattleEffectInteractionController.gd",
	"res://tests/ptcgdap/godot/test_author_strategy_windows_player_owner.gd",
	"res://tests/test_ai_watchdog.gd",
	"res://tests/ptcgdap/godot/run_author_strategy_windows_player_owner_e2e.gd",
	"res://tests/ptcgdap/godot/run_author_strategy_windows_player_owner_e2e.tscn",
]


func _ready() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	var report := _run_acceptance(options)
	var output_path := str(options.get("output", ""))
	if not output_path.is_empty():
		_write_json(output_path, report)
	print("AUTHOR_STRATEGY_WINDOWS_PLAYER_OWNER_E2E_RESULT " + JSON.stringify(report))
	get_tree().quit(0 if bool(report.get("is_clean", false)) else 1)


func _run_acceptance(options: Dictionary) -> Dictionary:
	var games := int(options.get("games", DEFAULT_GAMES))
	var seed_base := int(options.get("seed_base", DEFAULT_SEED_BASE))
	var max_steps := int(options.get("max_steps", DEFAULT_MAX_STEPS))
	var marnie: DeckData = CardDatabase.get_deck(MARNIE_DECK_ID)
	var rules_deck: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	var source_at_start := _source_snapshot()
	if marnie == null or rules_deck == null:
		return _failed_report(games, "deck_load_failed", source_at_start)
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var totals := {
		"policy_calls": 0,
		"policy_successes": 0,
		"policy_errors": 0,
		"invalid_outputs": 0,
		"same_window_fallbacks": 0,
		"classic_fallbacks": 0,
		"engine_commits": 0,
		"engine_rejections": 0,
	}
	var per_game: Array = []
	var started := Time.get_ticks_msec()
	for game_index: int in games:
		var seed := seed_base + game_index
		var requested: Dictionary = GateScript.request_match_handle(catalog, _exact_selection(), "Windows")
		var seed_owner := PlayerState.new()
		seed_owner.set_forced_shuffle_seed(seed)
		var gsm := GameStateMachine.new()
		if gsm.coin_flipper != null:
			var rng: Variant = gsm.coin_flipper.get("_rng")
			if rng is RandomNumberGenerator:
				(rng as RandomNumberGenerator).seed = seed
		gsm.start_game(rules_deck, marnie, 0)
		var built: Dictionary = OwnerScript.create(
			requested.get("handle"), gsm, 1, "windows-player-owner-%d" % seed
		) if bool(requested.get("ok", false)) else requested
		var owner: Variant = built.get("owner")
		var rules_ai := _rules_ai(0, rules_deck)
		var bridge := HeadlessMatchBridgeScript.new()
		bridge.bind(gsm)
		if owner != null:
			bridge.set_ai_controllers(rules_ai, owner)
		bridge.bootstrap_pending_setup()
		var steps := 0
		var failure := ""
		while owner != null and not gsm.game_state.is_game_over() and steps < max_steps:
			var progressed := false
			if bridge.has_pending_prompt():
				var prompt_owner := bridge.get_pending_prompt_owner()
				if prompt_owner == 1:
					progressed = bool(owner.run_single_step(bridge, gsm))
				elif bridge.can_resolve_pending_prompt():
					progressed = bridge.resolve_pending_prompt()
				else:
					progressed = rules_ai.run_single_step(bridge, gsm)
			else:
				progressed = bool(owner.run_single_step(bridge, gsm)) \
					if gsm.game_state.current_player_index == 1 \
					else rules_ai.run_single_step(bridge, gsm)
			if not progressed:
				failure = "no_progress:%s" % bridge.get_pending_prompt_type()
				break
			steps += 1
		if owner == null and failure.is_empty():
			failure = str(built.get("error_code", "owner_bind_failed"))
		if steps >= max_steps and not gsm.game_state.is_game_over() and failure.is_empty():
			failure = "step_cap"
		var audit: Dictionary = owner.audit_snapshot() if owner != null else {}
		for key: String in totals:
			totals[key] += int(audit.get(key, 0))
		per_game.append({
			"game": game_index + 1,
			"seed": seed,
			"owner_seat": 1,
			"rules_ai_seat": 0,
			"steps": steps,
			"winner_index": int(gsm.game_state.winner_index),
			"win_reason": str(gsm.game_state.win_reason),
			"failure": failure,
			"terminal": gsm.game_state.is_game_over(),
			"audit": audit,
		})
		if owner != null:
			owner.close_match()
		bridge.free()
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
	catalog.free()
	var source_at_end := _source_snapshot()
	var dirty_reasons: Array[String] = []
	for row: Dictionary in per_game:
		if not bool(row.get("terminal", false)):
			dirty_reasons.append("game_%d_not_terminal" % int(row.get("game", 0)))
		if not str(row.get("failure", "")).is_empty():
			dirty_reasons.append("game_%d_%s" % [int(row.get("game", 0)), row.get("failure")])
		if int(row.get("winner_index", -1)) not in [0, 1]:
			dirty_reasons.append("game_%d_missing_winner" % int(row.get("game", 0)))
	if totals.policy_calls <= 0 or totals.policy_calls != totals.policy_successes:
		dirty_reasons.append("policy_accounting")
	for zero_key: String in [
		"policy_errors", "invalid_outputs", "same_window_fallbacks",
		"classic_fallbacks", "engine_rejections",
	]:
		if int(totals.get(zero_key, 0)) != 0:
			dirty_reasons.append("%s:%d" % [zero_key, int(totals.get(zero_key, 0))])
	if totals.engine_commits <= 0:
		dirty_reasons.append("no_engine_commits")
	if source_at_start != source_at_end:
		dirty_reasons.append("source_changed_during_run")
	return {
		"schema_version": 1,
		"evidence_kind": "windows_development_player_owner_real_rules_e2e",
		"development_player_authority": true,
		"battle_scene_product_start_covered_by_focused_suite": true,
		"production_ready": false,
		"execution_trusted": false,
		"cabt_exportable": false,
		"android_ready": false,
		"exported_exe_airplane_mode": false,
		"package_id": PACKAGE_ID,
		"package_version": PACKAGE_VERSION,
		"archive_sha256": PACKAGE_ARCHIVE_SHA256,
		"card_id_domain": "godot_local_card_uid_v1",
		"marnie_deck_id": MARNIE_DECK_ID,
		"rules_ai_deck_id": RULES_AI_DECK_ID,
		"owner_seat": 1,
		"rules_ai_seat": 0,
		"games": games,
		"seed_base": seed_base,
		"max_steps": max_steps,
		"totals": totals,
		"source_at_start": source_at_start,
		"source_at_end": source_at_end,
		"source_changed_during_run": source_at_start != source_at_end,
		"elapsed_msec": Time.get_ticks_msec() - started,
		"is_clean": dirty_reasons.is_empty(),
		"dirty_reasons": dirty_reasons,
		"per_game": per_game,
	}


func _exact_selection() -> Dictionary:
	return {
		"package_id": PACKAGE_ID,
		"package_version": PACKAGE_VERSION,
		"archive_sha256": PACKAGE_ARCHIVE_SHA256,
		"install_source": "built_in",
	}


func _rules_ai(seat: int, deck: DeckData) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(seat, 1)
	DeckStrategyRegistryScript.new().apply_strategy_for_deck(ai, deck)
	ai.use_mcts = false
	ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	return ai


func _source_snapshot() -> Dictionary:
	var rows: Array = []
	for path: String in PINNED_SOURCE_PATHS:
		rows.append({"path": path.trim_prefix("res://"), "raw_sha256": _sha256_file(path)})
	return {"files": rows}


func _sha256_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length():
		context.update(file.get_buffer(mini(1_048_576, file.get_length() - file.get_position())))
	file.close()
	return context.finish().hex_encode().to_upper()


func _failed_report(games: int, code: String, source: Dictionary) -> Dictionary:
	return {
		"schema_version": 1,
		"evidence_kind": "windows_development_player_owner_real_rules_e2e",
		"games": games,
		"is_clean": false,
		"dirty_reasons": [code],
		"source_at_start": source,
		"per_game": [],
	}


func _write_json(path: String, report: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write Windows player-owner E2E report: %s" % path)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()


func _parse_args(args: PackedStringArray) -> Dictionary:
	var parsed := {
		"games": DEFAULT_GAMES,
		"seed_base": DEFAULT_SEED_BASE,
		"max_steps": DEFAULT_MAX_STEPS,
		"output": "",
	}
	for arg: String in args:
		if arg.begins_with("--games="):
			parsed["games"] = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--seed-base="):
			parsed["seed_base"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--max-steps="):
			parsed["max_steps"] = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--output="):
			parsed["output"] = arg.trim_prefix("--output=")
	return parsed
