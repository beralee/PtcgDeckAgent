class_name ReviewedAuthorVsClassicBenchmark
extends Control

## Paired exact-deck benchmark: reviewed .ptcgai owner versus the classic
## GDScript rules-only owner for the same 60-card deck. Every seed is played
## twice with the package on opposite seats; seat 0 always starts.
const GateScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd"
)
const CatalogScript = preload(
	"res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd"
)
const OwnerFactoryScript = preload(
	"res://scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd"
)
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")

const DEFAULT_GAMES_PER_DECK := 100
const DEFAULT_SEED_BASE := 86100
const DEFAULT_MAX_STEPS := 700
const REPORT_PREFIX := "REVIEWED_AUTHOR_VS_CLASSIC="
const CASES := [
	{
		"name": "玛俐长毛巨魔",
		"source_deck_id": 800018501,
		"package_id": "dev.beralee.v18.marnie-grimmsnarl",
		"package_version": "1.0.0",
		"archive_sha256": "60D0DBFED01230D524A3FFB173C152B0A1F4FDF2E6926614DBABB9ED57ED6316",
	},
	{
		"name": "无碟沙奈朵",
		"source_deck_id": 800017097,
		"package_id": "dev.beralee.v18.no-balloon-gardevoir",
		"package_version": "1.0.0",
		"archive_sha256": "FC2245D12044CE0ED92E877ACDA006A2DBD6F406FAE2573363D1C2EB7A69FB90",
	},
	{
		"name": "多龙巴鲁托",
		"source_deck_id": 800018499,
		"package_id": "dev.beralee.v18.pure-dragapult",
		"package_version": "1.0.0",
		"archive_sha256": "8CCA6A11C6F04D3267187112112244057ABCCB3073898BBE7027B264AE68D0D9",
	},
	{
		"name": "猛雷鼓厄诡椪",
		"source_deck_id": 800018509,
		"package_id": "dev.beralee.v18.raging-bolt-ogerpon",
		"package_version": "1.0.0",
		"archive_sha256": "EEB7A5CE507CCB0979EEADB336EEC916E488F2E13076387983C01F49B868F451",
	},
	{
		"name": "N 的索罗亚克",
		"source_deck_id": 800018502,
		"package_id": "dev.beralee.v18.ns-zoroark",
		"package_version": "1.0.0",
		"archive_sha256": "5ADE7B78A3F43E2537CE8E35FE73E1C63927C1EA0D15963EA5D98EC53664FBD0",
	},
]


static func benchmark_cases(source_deck_id: int = -1) -> Array:
	var selected: Array = []
	for case_value: Variant in CASES:
		var case: Dictionary = case_value.duplicate(true)
		if source_deck_id >= 0 and int(case.get("source_deck_id", -1)) != source_deck_id:
			continue
		var candidate: Dictionary = GateScript.candidate_for_package_identity(
			str(case.get("package_id", "")), str(case.get("package_version", ""))
		)
		if not candidate.is_empty():
			case["archive_sha256"] = candidate.get("archive_sha256")
		selected.append(case)
	return selected


static func wilson_95(wins: int, valid: int) -> Dictionary:
	if valid <= 0 or wins < 0 or wins > valid:
		return {"available": false, "lower": 0.0, "upper": 0.0}
	const Z := 1.959963984540054
	var n := float(valid)
	var estimate := float(wins) / n
	var denominator := 1.0 + Z * Z / n
	var center := (estimate + Z * Z / (2.0 * n)) / denominator
	var radius := Z * sqrt((estimate * (1.0 - estimate) + Z * Z / (4.0 * n)) / n) / denominator
	return {
		"available": true,
		"lower": maxf(0.0, center - radius),
		"upper": minf(1.0, center + radius),
	}


func _ready() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	var report := run_benchmark(options)
	var output_path := str(options.get(
		"output", "res://artifacts/deck_training/reviewed_author_vs_classic.json"
	))
	var write_error := _write_report(output_path, report)
	if not write_error.is_empty():
		(report["dirty_reasons"] as Array).append(write_error)
		report["is_clean"] = false
	report["output_path"] = output_path
	print(REPORT_PREFIX + JSON.stringify(report))
	get_tree().quit(0 if bool(report.get("is_clean", false)) else 1)


func run_benchmark(options: Dictionary = {}) -> Dictionary:
	var requested_games := clampi(
		int(options.get("games_per_deck", DEFAULT_GAMES_PER_DECK)), 2, 200
	)
	var games_per_deck := requested_games if requested_games % 2 == 0 else requested_games + 1
	var seed_base := int(options.get("seed_base", DEFAULT_SEED_BASE))
	var max_steps := clampi(int(options.get("max_steps", DEFAULT_MAX_STEPS)), 100, 2000)
	var source_deck_id := int(options.get("source_deck_id", -1))
	var capture_developer_trace := bool(options.get("capture_developer_trace", false))
	var selected_cases: Array = benchmark_cases(source_deck_id)
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var started_msec := Time.get_ticks_msec()
	var results: Array[Dictionary] = []
	var dirty_reasons: Array[String] = []
	if selected_cases.is_empty():
		dirty_reasons.append("no_matching_benchmark_case:%d" % source_deck_id)
	for case_index: int in selected_cases.size():
		var case: Dictionary = selected_cases[case_index]
		# Use the built-in AI deck snapshot that the classic GDScript policy was
		# authored against. A player-owned deck with the same numeric ID may be an
		# older local edit and is deliberately not benchmark authority.
		var deck: DeckData = CardDatabase.get_ai_deck(int(case.get("source_deck_id")))
		if deck == null:
			dirty_reasons.append("deck_load_failed:%s" % case.get("source_deck_id"))
			continue
		var result := _run_case(
			catalog, deck, case, case_index, games_per_deck, seed_base, max_steps,
			capture_developer_trace
		)
		results.append(result)
		for reason: Variant in result.get("dirty_reasons", []):
			dirty_reasons.append("%s:%s" % [case.get("package_id"), reason])
		print("BENCHMARK_CASE=%s" % JSON.stringify({
			"name": case.get("name"),
			"games": result.get("games"),
			"package_wins": result.get("package_wins"),
			"classic_wins": result.get("classic_wins"),
			"draws": result.get("draws"),
			"package_win_rate": result.get("package_win_rate"),
			"is_clean": result.get("is_clean"),
		}))
	catalog.free()
	return {
		"document_type": "reviewed_author_vs_classic_mirror_benchmark_v1",
		"schema_version": 1,
		"benchmark_kind": "paired_exact_deck_author_package_vs_classic_gdscript",
		"runtime_platform": OS.get_name(),
		"development_only": true,
		"production_ready": false,
		"official_cabt_engine_parity": false,
		"seat_policy": "package alternates seats; seat 0 starts; each seed is used twice",
		"seed_policy": "paired seed, swapped package seat",
		"classic_policy": "DeckStrategyRegistry rules_only",
		"package_policy": "exact-hash reviewed data-only package owner",
		"draw_value_for_win_rate": 0,
		"requested_games_per_deck": requested_games,
		"games_per_deck": games_per_deck,
		"pairs_per_deck": games_per_deck / 2,
		"total_games": games_per_deck * results.size(),
		"seed_base": seed_base,
		"max_steps": max_steps,
		"source_deck_id_filter": source_deck_id,
		"developer_trace_capture": capture_developer_trace,
		"elapsed_msec": Time.get_ticks_msec() - started_msec,
		"results": results,
		"is_clean": dirty_reasons.is_empty() and results.size() == selected_cases.size(),
		"dirty_reasons": dirty_reasons,
		"limitations": [
			"This is a same-deck direct duel, not the previous five-deck round robin.",
			"Classic GDScript can express arbitrary engine-local conditions; author packages remain bounded by their declared public data-only profile.",
			"Confidence intervals describe sampling uncertainty only and do not grant production authority.",
		],
	}


func _run_case(
	catalog: Variant,
	deck: DeckData,
	case: Dictionary,
	case_index: int,
	games: int,
	seed_base: int,
	max_steps: int,
	capture_developer_trace: bool = false
) -> Dictionary:
	var package_wins := 0
	var classic_wins := 0
	var draws := 0
	var package_wins_by_seat := {0: 0, 1: 0}
	var games_by_seat := {0: 0, 1: 0}
	var pair_results: Dictionary = {}
	var per_game: Array[Dictionary] = []
	var failure_counts: Dictionary = {}
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
	for game_index: int in games:
		var package_seat := game_index % 2
		var pair_index := game_index / 2
		var seed := seed_base + case_index * 10_000 + pair_index
		var row := _run_game(
			catalog, deck, case, game_index, package_seat, seed, max_steps,
			capture_developer_trace
		)
		per_game.append(row)
		games_by_seat[package_seat] = int(games_by_seat.get(package_seat, 0)) + 1
		var outcome := str(row.get("package_outcome", "draw"))
		if outcome == "win":
			package_wins += 1
			package_wins_by_seat[package_seat] = int(package_wins_by_seat.get(package_seat, 0)) + 1
		elif outcome == "loss":
			classic_wins += 1
		else:
			draws += 1
		var pair: Dictionary = pair_results.get(pair_index, {"wins": 0, "losses": 0, "draws": 0})
		pair["wins" if outcome == "win" else "losses" if outcome == "loss" else "draws"] += 1
		pair_results[pair_index] = pair
		var failure := str(row.get("failure", ""))
		if not failure.is_empty():
			failure_counts[failure] = int(failure_counts.get(failure, 0)) + 1
		var audit: Dictionary = row.get("package_audit", {})
		for key: String in totals:
			totals[key] += int(audit.get(key, 0))
		if (game_index + 1) % 10 == 0 or game_index + 1 == games:
			print("  %s %d/%d package=%d classic=%d draw=%d" % [
				case.get("name"), game_index + 1, games, package_wins, classic_wins, draws
			])
	var dirty_reasons := _case_dirty_reasons(per_game, totals)
	var pair_sweeps := 0
	var pair_splits := 0
	var pair_losses := 0
	var pair_other := 0
	for pair: Dictionary in pair_results.values():
		if int(pair.get("wins", 0)) == 2:
			pair_sweeps += 1
		elif int(pair.get("wins", 0)) == 1 and int(pair.get("losses", 0)) == 1:
			pair_splits += 1
		elif int(pair.get("losses", 0)) == 2:
			pair_losses += 1
		else:
			pair_other += 1
	var interval := wilson_95(package_wins, games)
	return {
		"name": case.get("name"),
		"source_deck_id": case.get("source_deck_id"),
		"package_id": case.get("package_id"),
		"package_version": case.get("package_version"),
		"archive_sha256": case.get("archive_sha256"),
		"classic_strategy_id": DeckStrategyRegistryScript.strategy_id_for_deck_id(
			int(case.get("source_deck_id"))
		),
		"games": games,
		"package_wins": package_wins,
		"classic_wins": classic_wins,
		"draws": draws,
		"package_win_rate": float(package_wins) / float(games),
		"package_win_rate_percent": 100.0 * float(package_wins) / float(games),
		"wilson_95": interval,
		"seat_split": {
			"package_seat_0": {"games": games_by_seat[0], "wins": package_wins_by_seat[0]},
			"package_seat_1": {"games": games_by_seat[1], "wins": package_wins_by_seat[1]},
		},
		"paired_results": {
			"package_sweeps": pair_sweeps,
			"seat_splits": pair_splits,
			"classic_sweeps": pair_losses,
			"other": pair_other,
		},
		"failure_counts": failure_counts,
		"package_audit_totals": totals,
		"is_clean": dirty_reasons.is_empty(),
		"dirty_reasons": dirty_reasons,
		"per_game": per_game,
	}


func _run_game(
	catalog: Variant,
	deck: DeckData,
	case: Dictionary,
	game_index: int,
	package_seat: int,
	seed: int,
	max_steps: int,
	capture_developer_trace: bool = false
) -> Dictionary:
	var selection := {
		"package_id": case.get("package_id"),
		"package_version": case.get("package_version"),
		"archive_sha256": case.get("archive_sha256"),
		"install_source": "built_in",
	}
	var requested: Dictionary = GateScript.request_match_handle(catalog, selection, "Windows")
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(seed)
	var gsm := GameStateMachine.new()
	if gsm.coin_flipper != null:
		var rng: Variant = gsm.coin_flipper.get("_rng")
		if rng is RandomNumberGenerator:
			(rng as RandomNumberGenerator).seed = seed
	gsm.start_game(deck, deck, 0)
	var built: Dictionary = OwnerFactoryScript.build_windows_development_author_owner(
		requested.get("handle"), gsm, package_seat,
		"mirror-%d-%d-%d" % [case.get("source_deck_id"), seed, package_seat]
	) if bool(requested.get("ok", false)) else requested
	var package_owner: Variant = built.get("owner")
	if capture_developer_trace and package_owner != null \
		and package_owner.has_method("enable_developer_decision_trace"):
		package_owner.enable_developer_decision_trace(true)
	var classic_seat := 1 - package_seat
	var classic_owner := _classic_ai(classic_seat, deck)
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	if package_owner != null:
		bridge.set_ai_controllers(
			package_owner if package_seat == 0 else classic_owner,
			classic_owner if package_seat == 0 else package_owner
		)
	bridge.bootstrap_pending_setup()
	var steps := 0
	var failure := ""
	while package_owner != null and not gsm.game_state.is_game_over() and steps < max_steps:
		var progressed := false
		if bridge.has_pending_prompt():
			var prompt_owner := bridge.get_pending_prompt_owner()
			if prompt_owner == package_seat:
				progressed = bool(package_owner.run_single_step(bridge, gsm))
			elif bridge.can_resolve_pending_prompt():
				progressed = bridge.resolve_pending_prompt()
			else:
				progressed = classic_owner.run_single_step(bridge, gsm)
		elif gsm.game_state.current_player_index == package_seat:
			progressed = bool(package_owner.run_single_step(bridge, gsm))
		else:
			progressed = classic_owner.run_single_step(bridge, gsm)
		if not progressed:
			failure = "no_progress:%s" % bridge.get_pending_prompt_type()
			break
		steps += 1
	if package_owner == null and failure.is_empty():
		failure = str(built.get("error_code", "owner_bind_failed"))
	if steps >= max_steps and not gsm.game_state.is_game_over() and failure.is_empty():
		failure = "step_cap"
	var winner := int(gsm.game_state.winner_index)
	var outcome := "draw"
	if winner == package_seat:
		outcome = "win"
	elif winner == classic_seat:
		outcome = "loss"
	var audit: Dictionary = package_owner.audit_snapshot() if package_owner != null else {}
	var developer_decisions: Array = package_owner.drain_developer_decision_records() \
		if capture_developer_trace and package_owner != null \
		and package_owner.has_method("drain_developer_decision_records") else []
	var row := {
		"game": game_index + 1,
		"pair": game_index / 2 + 1,
		"seed": seed,
		"package_seat": package_seat,
		"starting_seat": 0,
		"winner_index": winner,
		"package_outcome": outcome,
		"win_reason": str(gsm.game_state.win_reason),
		"steps": steps,
		"terminal": gsm.game_state.is_game_over(),
		"failure": failure,
		"package_audit": _compact_audit(audit),
	}
	if capture_developer_trace:
		row["developer_decisions"] = developer_decisions
	if package_owner != null:
		package_owner.close_match()
	bridge.free()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return row


func _classic_ai(seat: int, deck: DeckData) -> AIOpponent:
	var ai: AIOpponent = AIOpponentScript.new()
	ai.configure(seat, 1)
	DeckStrategyRegistryScript.new().apply_strategy_for_deck(ai, deck)
	ai.use_mcts = false
	ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	return ai


func _compact_audit(audit: Dictionary) -> Dictionary:
	var result := {}
	for key: String in [
		"policy_calls", "policy_successes", "policy_errors", "invalid_outputs",
		"same_window_fallbacks", "classic_fallbacks", "engine_commits", "engine_rejections",
	]:
		result[key] = int(audit.get(key, 0))
	result["matched_rule_counts"] = audit.get("matched_rule_counts", {}).duplicate(true)
	return result


func _case_dirty_reasons(per_game: Array[Dictionary], totals: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	for row: Dictionary in per_game:
		if not bool(row.get("terminal", false)):
			reasons.append("game_%d_not_terminal" % int(row.get("game", 0)))
		if not str(row.get("failure", "")).is_empty():
			reasons.append("game_%d_%s" % [row.get("game"), row.get("failure")])
		if int(row.get("winner_index", -1)) not in [0, 1]:
			reasons.append("game_%d_missing_winner" % int(row.get("game", 0)))
	if int(totals.get("policy_calls", 0)) <= 0 \
		or totals.get("policy_calls") != totals.get("policy_successes"):
		reasons.append("policy_accounting")
	for key: String in [
		"policy_errors", "invalid_outputs", "same_window_fallbacks",
		"classic_fallbacks", "engine_rejections",
	]:
		if int(totals.get(key, 0)) != 0:
			reasons.append("%s:%d" % [key, int(totals.get(key, 0))])
	if int(totals.get("engine_commits", 0)) <= 0:
		reasons.append("no_engine_commits")
	return reasons


func _parse_args(args: PackedStringArray) -> Dictionary:
	var result := {}
	for arg: String in args:
		if arg.begins_with("--games-per-deck="):
			result["games_per_deck"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seed-base="):
			result["seed_base"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--max-steps="):
			result["max_steps"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--source-deck-id="):
			result["source_deck_id"] = int(arg.get_slice("=", 1))
		elif arg == "--capture-developer-trace":
			result["capture_developer_trace"] = true
		elif arg.begins_with("--output="):
			result["output"] = arg.get_slice("=", 1)
	return result


func _write_report(path: String, report: Dictionary) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "report_write_failed:%s" % FileAccess.get_open_error()
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file = null
	return ""
