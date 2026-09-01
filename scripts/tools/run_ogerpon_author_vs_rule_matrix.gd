class_name OgerponAuthorVsRuleMatrix
extends Control

## Paired heterogeneous benchmark for the data-only Ogerpon/Crustle author
## package against the five Rule 18.0 built-in GDScript owners. The candidate
## alternates seats, seat 0 starts, and each random seed is reused for the
## swapped-seat game. A dirty game stops only its affected matchup.
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
const CompetitivePolicyV2Script = preload(
	"res://scripts/ai/ptcgdap/public/CompetitivePolicyV2.gd"
)
const CompetitiveContractsScript = preload(
	"res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd"
)
const PublicReplayEnvelopeScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/PublicReplayLiveEnvelope.gd"
)
const PublicReplayCaptureScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/PublicReplayCapture.gd"
)
const JsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")

const CANDIDATE_DECK_ID := 800052301
const CANDIDATE_PACKAGE_ID := "dev.beralee.v18.ogerpon-crustle-v523a"
const DEFAULT_PACKAGE_VERSION := "0.1.0"
const DEFAULT_GAMES_PER_MATCHUP := 20
const DEFAULT_SEED_BASE := 52300
const DEFAULT_MATCHUP_OFFSET := 1000
const DEFAULT_MAX_STEPS := 700
const REPORT_PREFIX := "OGERPON_AUTHOR_VS_RULE_MATRIX="
const COMPETITIVE_SEMANTIC_KEYS := [
	"max_count", "min_count", "select_context_raw", "select_type_raw",
]
const CASES := [
	{"name": "玛俐长毛巨魔", "opponent_deck_id": 800018501},
	{"name": "无碟沙奈朵", "opponent_deck_id": 800017097},
	{"name": "多龙巴鲁托", "opponent_deck_id": 800018499},
	{"name": "猛雷鼓厄诡椪", "opponent_deck_id": 800018509},
	{"name": "N 的索罗亚克", "opponent_deck_id": 800018502},
]


static func benchmark_cases(
	opponent_deck_id: int = -1,
	package_version: String = DEFAULT_PACKAGE_VERSION,
	candidate_deck_id: int = CANDIDATE_DECK_ID,
	candidate_package_id: String = CANDIDATE_PACKAGE_ID
) -> Array:
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		candidate_package_id, package_version
	)
	var selected: Array = []
	for case_value: Variant in CASES:
		var case: Dictionary = case_value.duplicate(true)
		if opponent_deck_id >= 0 and int(case.get("opponent_deck_id", -1)) != opponent_deck_id:
			continue
		case["candidate_deck_id"] = candidate_deck_id
		case["package_id"] = candidate_package_id
		case["package_version"] = package_version
		case["archive_sha256"] = candidate.get("archive_sha256", "")
		selected.append(case)
	return selected


static func seed_for_game(
	seed_base: int,
	matchup_offset: int,
	matchup_index: int,
	game_index: int
) -> int:
	return seed_base + matchup_index * matchup_offset + game_index / 2


static func candidate_seat_for_game(game_index: int) -> int:
	return game_index % 2


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


static func select_representatives(rows: Array[Dictionary]) -> Dictionary:
	var clean_wins: Array[Dictionary] = []
	var clean_losses: Array[Dictionary] = []
	for row: Dictionary in rows:
		if not bool(row.get("terminal", false)) or not str(row.get("failure", "")).is_empty():
			continue
		if row.get("candidate_outcome") == "win":
			clean_wins.append(row)
		elif row.get("candidate_outcome") == "loss":
			clean_losses.append(row)
	clean_wins.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("game", 0)) < int(right.get("game", 0))
	)
	clean_losses.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_steps := int(left.get("steps", 0))
		var right_steps := int(right.get("steps", 0))
		return left_steps < right_steps or (
			left_steps == right_steps and int(left.get("game", 0)) < int(right.get("game", 0))
		)
	)
	var selected := {
		"earliest_clean_win": clean_wins[0].duplicate(true) if not clean_wins.is_empty() else {},
		"median_length_clean_loss": {},
		"longest_clean_loss": clean_losses[-1].duplicate(true) if not clean_losses.is_empty() else {},
	}
	if not clean_losses.is_empty():
		selected["median_length_clean_loss"] = clean_losses[(clean_losses.size() - 1) / 2].duplicate(true)
	return selected


static func diagnose_competitive_frame(frame: Dictionary) -> Dictionary:
	var semantics: Variant = frame.get("select_semantics")
	var actual_keys: Array[String] = []
	if semantics is Dictionary:
		for key: Variant in (semantics as Dictionary).keys():
			actual_keys.append(str(key))
	actual_keys.sort()
	var unexpected_keys: Array[String] = []
	var missing_keys: Array[String] = []
	for key: String in actual_keys:
		if key not in COMPETITIVE_SEMANTIC_KEYS:
			unexpected_keys.append(key)
	for key: String in COMPETITIVE_SEMANTIC_KEYS:
		if key not in actual_keys:
			missing_keys.append(key)
	var expected_option_keys: Array[String] = []
	for key: Variant in CompetitivePolicyV2Script.OPTION_KEYS:
		expected_option_keys.append(str(key))
	expected_option_keys.sort()
	var actual_option_keys: Array[String] = []
	for option_value: Variant in frame.get("options", []):
		if not option_value is Dictionary:
			continue
		for key: Variant in (option_value as Dictionary).keys():
			var text_key := str(key)
			if text_key not in actual_option_keys:
				actual_option_keys.append(text_key)
	actual_option_keys.sort()
	var unexpected_option_keys: Array[String] = []
	var missing_option_keys: Array[String] = []
	for key: String in actual_option_keys:
		if key not in expected_option_keys:
			unexpected_option_keys.append(key)
	for key: String in expected_option_keys:
		if key not in actual_option_keys:
			missing_option_keys.append(key)
	var error_code := str(CompetitivePolicyV2Script._frame_error(frame))
	var normalized_error_code := error_code
	if semantics is Dictionary and (
		not unexpected_keys.is_empty() or not unexpected_option_keys.is_empty()
	):
		var normalized: Dictionary = frame.duplicate(true)
		var normalized_semantics: Dictionary = normalized.get("select_semantics", {})
		for key: String in unexpected_keys:
			normalized_semantics.erase(key)
		for option_value: Variant in normalized.get("options", []):
			if option_value is Dictionary:
				for key: String in unexpected_option_keys:
					(option_value as Dictionary).erase(key)
		normalized_error_code = str(CompetitivePolicyV2Script._frame_error(normalized))
	return {
		"accepted": error_code.is_empty(),
		"error_code": error_code,
		"expected_semantic_keys": COMPETITIVE_SEMANTIC_KEYS.duplicate(),
		"actual_semantic_keys": actual_keys,
		"unexpected_semantic_keys": unexpected_keys,
		"missing_semantic_keys": missing_keys,
		"expected_option_keys": expected_option_keys,
		"actual_option_keys": actual_option_keys,
		"unexpected_option_keys": unexpected_option_keys,
		"missing_option_keys": missing_option_keys,
		"normalized_without_unexpected_error_code": normalized_error_code,
		"normalized_without_unexpected_accepted": normalized_error_code.is_empty(),
	}


func _ready() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	var report := run_benchmark(options)
	var output_path := str(options.get(
		"output", "res://artifacts/deck_training/ogerpon_author_vs_rule_matrix.json"
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
		int(options.get("games_per_matchup", DEFAULT_GAMES_PER_MATCHUP)), 2, 200
	)
	var games_per_matchup := requested_games if requested_games % 2 == 0 else requested_games + 1
	var seed_base := int(options.get("seed_base", DEFAULT_SEED_BASE))
	var matchup_offset := maxi(1, int(options.get("matchup_offset", DEFAULT_MATCHUP_OFFSET)))
	var max_steps := clampi(int(options.get("max_steps", DEFAULT_MAX_STEPS)), 100, 2000)
	var opponent_deck_id := int(options.get("opponent_deck_id", -1))
	var package_version := str(options.get("package_version", DEFAULT_PACKAGE_VERSION))
	var candidate_deck_id := int(options.get("candidate_deck_id", CANDIDATE_DECK_ID))
	var candidate_package_id := str(options.get("candidate_package_id", CANDIDATE_PACKAGE_ID))
	var capture_developer_trace := bool(options.get("capture_developer_trace", false))
	var capture_public_replays := bool(options.get("capture_public_replays", false))
	var replay_output_root := str(options.get(
		"replay_output_root", "res://artifacts/deck_training/ogerpon_public_replays"
	))
	var stop_on_dirty := bool(options.get("stop_on_dirty", true))
	var selected_cases: Array = benchmark_cases(
		opponent_deck_id, package_version, candidate_deck_id, candidate_package_id
	)
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var candidate_deck: DeckData = CardDatabase.get_ai_deck(candidate_deck_id)
	var started_msec := Time.get_ticks_msec()
	var results: Array[Dictionary] = []
	var dirty_reasons: Array[String] = []
	if candidate_deck == null:
		dirty_reasons.append("candidate_deck_load_failed:%d" % candidate_deck_id)
	if selected_cases.is_empty():
		dirty_reasons.append("no_matching_benchmark_case:%d" % opponent_deck_id)
	for case_index: int in selected_cases.size():
		if candidate_deck == null:
			break
		var case: Dictionary = selected_cases[case_index]
		var opponent_deck: DeckData = CardDatabase.get_ai_deck(int(case.get("opponent_deck_id")))
		if opponent_deck == null:
			dirty_reasons.append("opponent_deck_load_failed:%s" % case.get("opponent_deck_id"))
			continue
		var preflight := _preflight_case(
			catalog, candidate_deck, opponent_deck, case,
			seed_for_game(seed_base, matchup_offset, case_index, 0)
		)
		var result := _run_case(
			catalog, candidate_deck, opponent_deck, case, case_index,
			games_per_matchup, seed_base, matchup_offset, max_steps,
			capture_developer_trace, capture_public_replays, replay_output_root,
			stop_on_dirty
		) if bool(preflight.get("accepted", false)) else _blocked_case_result(
			case, games_per_matchup, preflight
		)
		results.append(result)
		for reason: Variant in result.get("dirty_reasons", []):
			dirty_reasons.append("%s:%s" % [case.get("opponent_deck_id"), reason])
		print("OGERPON_MATRIX_CASE=%s" % JSON.stringify({
			"name": case.get("name"),
			"games": result.get("games"),
			"candidate_wins": result.get("candidate_wins"),
			"rule_wins": result.get("rule_wins"),
			"draws": result.get("draws"),
			"candidate_win_rate": result.get("candidate_win_rate"),
			"is_clean": result.get("is_clean"),
		}))
	catalog.free()
	return {
		"document_type": (
			"ogerpon_author_vs_rule_matrix_benchmark_v1"
			if candidate_deck_id == CANDIDATE_DECK_ID and candidate_package_id == CANDIDATE_PACKAGE_ID
			else "reviewed_author_vs_rule_matrix_benchmark_v1"
		),
		"schema_version": 1,
		"benchmark_kind": "paired_heterogeneous_author_package_vs_five_rule_18_0",
		"runtime_platform": OS.get_name(),
		"development_only": true,
		"production_ready": false,
		"official_cabt_engine_parity": false,
		"candidate_deck_id": candidate_deck_id,
		"candidate_package_id": candidate_package_id,
		"candidate_package_version": package_version,
		"candidate_archive_sha256": (
			selected_cases[0].get("archive_sha256", "") if not selected_cases.is_empty() else ""
		),
		"rule_mode": "rules_only",
		"seat_policy": "candidate alternates seats; seat 0 starts; each seed is used twice",
		"seed_policy": "seed_base + matchup_index * matchup_offset + floor(game_index / 2)",
		"requested_games_per_matchup": requested_games,
		"games_per_matchup": games_per_matchup,
		"pairs_per_matchup": games_per_matchup / 2,
		"seed_base": seed_base,
		"matchup_offset": matchup_offset,
		"max_steps": max_steps,
		"opponent_deck_id_filter": opponent_deck_id,
		"developer_trace_capture": capture_developer_trace,
		"public_replay_capture": capture_public_replays,
		"public_replay_output_root": replay_output_root if capture_public_replays else "",
		"host_frame_contract_preflight_required": true,
		"stop_affected_matchup_on_dirty": stop_on_dirty,
		"elapsed_msec": Time.get_ticks_msec() - started_msec,
		"results": results,
		"is_clean": dirty_reasons.is_empty() and results.size() == selected_cases.size(),
		"dirty_reasons": dirty_reasons,
		"public_replay_status": (
			"exact_heterogeneous_rule_identity_and_hash_chain_capture_enabled"
			if capture_public_replays else "available_on_exact_rerun"
		),
		"limitations": [
			"Twenty games per matchup are scouting evidence, not a statistical strength claim.",
			"Public replay capture is opt-in and binds the exact rules-only deck identity; benchmark rows never relabel a heterogeneous opponent as Miraidon.",
			"Representative rows are deterministic rerun candidates; developer decision traces remain public current-window evidence only.",
		],
	}


func _preflight_case(
	catalog: Variant,
	candidate_deck: DeckData,
	opponent_deck: DeckData,
	case: Dictionary,
	seed: int
) -> Dictionary:
	var selection := {
		"package_id": case.get("package_id"),
		"package_version": case.get("package_version"),
		"archive_sha256": case.get("archive_sha256"),
		"install_source": "built_in",
	}
	var requested: Dictionary = GateScript.request_match_handle(catalog, selection, "Windows")
	if not bool(requested.get("ok", false)):
		return {
			"accepted": false,
			"stage": "request_match_handle",
			"error_code": str(requested.get("error_code", "package_integrity_invalid")),
		}
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(seed)
	var gsm := GameStateMachine.new()
	if gsm.coin_flipper != null:
		var rng: Variant = gsm.coin_flipper.get("_rng")
		if rng is RandomNumberGenerator:
			(rng as RandomNumberGenerator).seed = seed
	gsm.start_game(candidate_deck, opponent_deck, 0)
	var built: Dictionary = OwnerFactoryScript.build_windows_development_author_owner(
		requested.get("handle"), gsm, 0,
		"ogerpon-contract-preflight-%d-%d" % [case.get("opponent_deck_id"), seed]
	)
	var owner: Variant = built.get("owner")
	var report: Dictionary
	if owner == null:
		report = {
			"accepted": false,
			"stage": "owner_bind",
			"error_code": str(built.get("error_code", "invalid_bind")),
		}
	else:
		var basics: Array[CardInstance] = gsm.game_state.players[0].get_basic_pokemon_in_hand()
		if basics.is_empty():
			report = {
				"accepted": false,
				"stage": "host_frame_build",
				"error_code": "setup_option_missing",
			}
		else:
			var frame: Dictionary = owner._build_frame(
				"setup_active", owner._options_for_items(basics, "setup_active"), 1, 1
			)
			report = diagnose_competitive_frame(frame)
			report["stage"] = "competitive_v2_frame_validation"
			report["prompt_kind"] = frame.get("prompt_kind")
			report["frame_schema_version"] = frame.get("schema_version")
		owner.close_match()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return report


static func _blocked_case_result(
	case: Dictionary,
	planned_games: int,
	preflight: Dictionary
) -> Dictionary:
	var error_code := str(preflight.get("error_code", "host_frame_contract_invalid"))
	return {
		"name": case.get("name"),
		"candidate_deck_id": case.get("candidate_deck_id"),
		"opponent_deck_id": case.get("opponent_deck_id"),
		"package_id": case.get("package_id"),
		"package_version": case.get("package_version"),
		"archive_sha256": case.get("archive_sha256"),
		"classic_strategy_id": DeckStrategyRegistryScript.strategy_id_for_deck_id(
			int(case.get("opponent_deck_id"))
		),
		"planned_games": planned_games,
		"games": 0,
		"candidate_wins": 0,
		"rule_wins": 0,
		"draws": 0,
		"candidate_win_rate": 0.0,
		"candidate_win_rate_percent": 0.0,
		"wilson_95": {"available": false, "lower": 0.0, "upper": 0.0},
		"seat_split": {
			"candidate_seat_0": {"games": 0, "wins": 0},
			"candidate_seat_1": {"games": 0, "wins": 0},
		},
		"average_steps": 0.0,
		"candidate_audit_totals": {
			"policy_calls": 0,
			"policy_successes": 0,
			"policy_errors": 0,
			"invalid_outputs": 0,
			"same_window_fallbacks": 0,
			"classic_fallbacks": 0,
			"engine_commits": 0,
			"engine_rejections": 0,
		},
		"representative_candidates": {
			"earliest_clean_win": {},
			"median_length_clean_loss": {},
			"longest_clean_loss": {},
		},
		"contract_preflight": preflight.duplicate(true),
		"is_clean": false,
		"dirty_reasons": ["host_frame_contract_preflight:%s" % error_code],
		"per_game": [],
	}


func _run_case(
	catalog: Variant,
	candidate_deck: DeckData,
	opponent_deck: DeckData,
	case: Dictionary,
	case_index: int,
	games: int,
	seed_base: int,
	matchup_offset: int,
	max_steps: int,
	capture_developer_trace: bool,
	capture_public_replays: bool,
	replay_output_root: String,
	stop_on_dirty: bool
) -> Dictionary:
	var candidate_wins := 0
	var rule_wins := 0
	var draws := 0
	var wins_by_seat := {0: 0, 1: 0}
	var games_by_seat := {0: 0, 1: 0}
	var per_game: Array[Dictionary] = []
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
		var candidate_seat := candidate_seat_for_game(game_index)
		var seed := seed_for_game(seed_base, matchup_offset, case_index, game_index)
		var row := _run_game(
			catalog, candidate_deck, opponent_deck, case, game_index,
			candidate_seat, seed, max_steps, capture_developer_trace,
			capture_public_replays, replay_output_root
		)
		per_game.append(row)
		games_by_seat[candidate_seat] = int(games_by_seat.get(candidate_seat, 0)) + 1
		var outcome := str(row.get("candidate_outcome", "draw"))
		if outcome == "win":
			candidate_wins += 1
			wins_by_seat[candidate_seat] = int(wins_by_seat.get(candidate_seat, 0)) + 1
		elif outcome == "loss":
			rule_wins += 1
		else:
			draws += 1
		var audit: Dictionary = row.get("candidate_audit", {})
		for key: String in totals:
			totals[key] += int(audit.get(key, 0))
		if stop_on_dirty and _row_is_dirty(row, audit):
			break
		if (game_index + 1) % 10 == 0 or game_index + 1 == games:
			print("  %s %d/%d candidate=%d rule=%d draw=%d" % [
				case.get("name"), game_index + 1, games, candidate_wins, rule_wins, draws
			])
	var dirty_reasons := _case_dirty_reasons(per_game, totals)
	var valid := per_game.size()
	var step_total := 0
	for row: Dictionary in per_game:
		step_total += int(row.get("steps", 0))
	return {
		"name": case.get("name"),
		"candidate_deck_id": case.get("candidate_deck_id"),
		"opponent_deck_id": case.get("opponent_deck_id"),
		"package_id": case.get("package_id"),
		"package_version": case.get("package_version"),
		"archive_sha256": case.get("archive_sha256"),
		"classic_strategy_id": DeckStrategyRegistryScript.strategy_id_for_deck_id(
			int(case.get("opponent_deck_id"))
		),
		"planned_games": games,
		"games": valid,
		"candidate_wins": candidate_wins,
		"rule_wins": rule_wins,
		"draws": draws,
		"candidate_win_rate": float(candidate_wins) / float(valid) if valid > 0 else 0.0,
		"candidate_win_rate_percent": 100.0 * float(candidate_wins) / float(valid) if valid > 0 else 0.0,
		"wilson_95": wilson_95(candidate_wins, valid),
		"seat_split": {
			"candidate_seat_0": {"games": games_by_seat[0], "wins": wins_by_seat[0]},
			"candidate_seat_1": {"games": games_by_seat[1], "wins": wins_by_seat[1]},
		},
		"average_steps": float(step_total) / float(valid) if valid > 0 else 0.0,
		"candidate_audit_totals": totals,
		"representative_candidates": select_representatives(per_game),
		"is_clean": dirty_reasons.is_empty() and valid == games,
		"dirty_reasons": dirty_reasons,
		"per_game": per_game,
	}


func _run_game(
	catalog: Variant,
	candidate_deck: DeckData,
	opponent_deck: DeckData,
	case: Dictionary,
	game_index: int,
	candidate_seat: int,
	seed: int,
	max_steps: int,
	capture_developer_trace: bool,
	capture_public_replay: bool,
	replay_output_root: String
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
	var deck_0 := candidate_deck if candidate_seat == 0 else opponent_deck
	var deck_1 := opponent_deck if candidate_seat == 0 else candidate_deck
	gsm.start_game(deck_0, deck_1, 0)
	var built: Dictionary = OwnerFactoryScript.build_windows_development_author_owner(
		requested.get("handle"), gsm, candidate_seat,
		"author-rule-%d-vs-%d-%d-%d" % [
			case.get("candidate_deck_id"), case.get("opponent_deck_id"), seed,
			candidate_seat,
		]
	) if bool(requested.get("ok", false)) else requested
	var candidate_owner: Variant = built.get("owner")
	if capture_developer_trace and candidate_owner != null \
		and candidate_owner.has_method("enable_developer_decision_trace"):
		candidate_owner.enable_developer_decision_trace(true)
	var classic_seat := 1 - candidate_seat
	var classic_owner := _classic_ai(classic_seat, opponent_deck)
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	if candidate_owner != null:
		bridge.set_ai_controllers(
			candidate_owner if candidate_seat == 0 else classic_owner,
			classic_owner if candidate_seat == 0 else candidate_owner
		)
	bridge.bootstrap_pending_setup()
	var replay_capture: Variant = null
	var replay_error := ""
	if capture_public_replay and candidate_owner != null:
		var replay_started := _start_public_replay_capture(
			candidate_owner, int(case.get("candidate_deck_id", -1)),
			int(case.get("opponent_deck_id", -1)), candidate_seat, seed
		)
		if bool(replay_started.get("accepted", false)):
			replay_capture = replay_started.get("capture")
		else:
			replay_error = str(replay_started.get("error_code", "public_replay_start_failed"))
	var steps := 0
	var failure := ""
	var progress_tail: Array[Dictionary] = []
	while candidate_owner != null and not gsm.game_state.is_game_over() and steps < max_steps:
		var progressed := false
		if bridge.has_pending_prompt():
			var prompt_owner := bridge.get_pending_prompt_owner()
			if prompt_owner == candidate_seat:
				progressed = bool(candidate_owner.run_single_step(bridge, gsm))
			elif bridge.can_resolve_pending_prompt():
				progressed = bridge.resolve_pending_prompt()
			else:
				progressed = classic_owner.run_single_step(bridge, gsm)
		elif gsm.game_state.current_player_index == candidate_seat:
			progressed = bool(candidate_owner.run_single_step(bridge, gsm))
		else:
			progressed = classic_owner.run_single_step(bridge, gsm)
		if not progressed:
			failure = "no_progress:%s" % bridge.get_pending_prompt_type()
			break
		steps += 1
		progress_tail.append(_progress_probe(bridge, gsm, classic_owner, steps))
		if progress_tail.size() > 24:
			progress_tail.pop_front()
		if replay_capture != null and replay_error.is_empty() \
			and not gsm.game_state.is_game_over():
			var progress_source: Dictionary = candidate_owner.public_replay_source_snapshot()
			var appended: Dictionary = replay_capture.append_public_source(
				progress_source.get("source"), "state_progressed"
			) if bool(progress_source.get("ok", false)) else progress_source
			if not bool(appended.get("accepted", false)):
				replay_error = str(appended.get("error_code", "public_replay_progress_failed"))
	if candidate_owner == null and failure.is_empty():
		failure = str(built.get("error_code", "owner_bind_failed"))
	if steps >= max_steps and not gsm.game_state.is_game_over() and failure.is_empty():
		failure = "step_cap"
	var winner := int(gsm.game_state.winner_index)
	var outcome := "draw"
	if winner == candidate_seat:
		outcome = "win"
	elif winner == classic_seat:
		outcome = "loss"
	var audit: Dictionary = candidate_owner.audit_snapshot() if candidate_owner != null else {}
	var developer_decisions: Array = candidate_owner.drain_developer_decision_records() \
		if capture_developer_trace and candidate_owner != null \
		and candidate_owner.has_method("drain_developer_decision_records") else []
	var row := {
		"game": game_index + 1,
		"pair": game_index / 2 + 1,
		"seed": seed,
		"candidate_seat": candidate_seat,
		"starting_seat": 0,
		"winner_index": winner,
		"candidate_outcome": outcome,
		"win_reason": str(gsm.game_state.win_reason),
		"steps": steps,
		"terminal": gsm.game_state.is_game_over(),
		"failure": failure,
		"candidate_audit": _compact_audit(audit),
		"archive_sha256": case.get("archive_sha256"),
	}
	if not failure.is_empty():
		row["failure_diagnostic"] = _failure_diagnostic(
			bridge, gsm, candidate_owner, classic_owner, candidate_seat, progress_tail
		)
	if capture_public_replay:
		row["public_replay"] = _finish_public_replay_capture(
			replay_capture,
			candidate_owner,
			replay_error,
			replay_output_root,
			int(case.get("candidate_deck_id", -1)),
			int(case.get("opponent_deck_id", -1)),
			seed,
			candidate_seat,
			gsm.game_state.is_game_over()
		)
	if capture_developer_trace:
		row["developer_decisions"] = developer_decisions
	if candidate_owner != null:
		candidate_owner.close_match()
	bridge.free()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return row


func _failure_diagnostic(
	bridge: Control,
	gsm: GameStateMachine,
	candidate_owner: Variant,
	classic_owner: Variant,
	candidate_seat: int,
	progress_tail: Array[Dictionary]
) -> Dictionary:
	var result := {
		"turn_number": int(gsm.game_state.turn_number),
		"phase": GameState.GamePhase.keys()[int(gsm.game_state.phase)],
		"current_player_index": int(gsm.game_state.current_player_index),
		"candidate_seat": candidate_seat,
		"pending_prompt": bridge.get_pending_prompt_type(),
		"pending_prompt_owner": bridge.get_pending_prompt_owner(),
		"pending_effect_kind": str(bridge.get("_pending_effect_kind")),
		"pending_effect_step_index": int(bridge.get("_pending_effect_step_index")),
		"pending_effect_step_id": "",
		"pending_effect_step_item_count": 0,
		"action_log_size": gsm.action_log.size(),
		"progress_tail": progress_tail.duplicate(true),
	}
	if bridge.has_meta("last_effect_commit_failure"):
		result["last_effect_commit_failure"] = (
			bridge.get_meta("last_effect_commit_failure") as Dictionary
		).duplicate(true)
	var pending_steps: Array[Dictionary] = bridge.get("_pending_effect_steps")
	var pending_index := int(result.pending_effect_step_index)
	if pending_index >= 0 and pending_index < pending_steps.size():
		result["pending_effect_step_id"] = str(pending_steps[pending_index].get("id", ""))
		result["pending_effect_step_item_count"] = (
			pending_steps[pending_index].get("items", []) as Array
		).size()
	if candidate_owner != null and candidate_owner.has_method("public_replay_source_snapshot"):
		var snapshot: Dictionary = candidate_owner.public_replay_source_snapshot()
		if bool(snapshot.get("ok", false)):
			result["final_public_source"] = snapshot.get("source", {})
	if classic_owner != null and classic_owner.has_method("get_last_decision_trace"):
		var trace: Variant = classic_owner.get_last_decision_trace()
		if trace != null and trace.has_method("to_dictionary"):
			var trace_data: Dictionary = trace.to_dictionary()
			var chosen: Dictionary = trace_data.get("chosen_action", {})
			var chosen_card: Dictionary = chosen.get("card", {})
			result["classic_last_choice"] = {
				"turn_number": int(trace_data.get("turn_number", -1)),
				"kind": str(chosen.get("kind", "")),
				"card_uid": "%s_%s" % [
					str(chosen_card.get("set_code", "")),
					str(chosen_card.get("card_index", "")),
				] if not chosen_card.is_empty() else "",
				"ability_index": int(chosen.get("ability_index", -1)),
				"attack_index": int(chosen.get("attack_index", -1)),
				"reason_tags": trace_data.get("reason_tags", []),
			}
	return result


func _progress_probe(
	bridge: Control,
	gsm: GameStateMachine,
	classic_owner: Variant,
	step_number: int
) -> Dictionary:
	var result := {
		"step": step_number,
		"turn_number": int(gsm.game_state.turn_number),
		"phase": GameState.GamePhase.keys()[int(gsm.game_state.phase)],
		"current_player_index": int(gsm.game_state.current_player_index),
		"pending_prompt": bridge.get_pending_prompt_type(),
		"pending_effect_kind": str(bridge.get("_pending_effect_kind")),
		"pending_effect_step_index": int(bridge.get("_pending_effect_step_index")),
		"action_log_size": gsm.action_log.size(),
		"effect_commit_failure": (
			(bridge.get_meta("last_effect_commit_failure") as Dictionary).duplicate(true)
			if bridge.has_meta("last_effect_commit_failure") else {}
		),
		"classic_choice_kind": "",
		"classic_choice_attack_index": -1,
		"classic_choice_ability_index": -1,
	}
	if classic_owner != null and classic_owner.has_method("get_last_decision_trace"):
		var trace: Variant = classic_owner.get_last_decision_trace()
		if trace != null and trace.has_method("to_dictionary"):
			var chosen: Dictionary = (trace.to_dictionary() as Dictionary).get("chosen_action", {})
			result["classic_choice_kind"] = str(chosen.get("kind", ""))
			result["classic_choice_attack_index"] = int(chosen.get("attack_index", -1))
			result["classic_choice_ability_index"] = int(chosen.get("ability_index", -1))
	return result


func _start_public_replay_capture(
	owner: Variant,
	candidate_deck_id: int,
	opponent_deck_id: int,
	strategy_seat: int,
	seed: int,
	opponent_owner: Variant = null
) -> Dictionary:
	var contracts: Dictionary = CompetitiveContractsScript.load_default()
	if not bool(contracts.get("accepted", false)):
		return contracts
	var contract_owner: Variant = contracts.get("owner")
	var identity: Dictionary = owner.public_replay_identity()
	if not bool(identity.get("ok", false)):
		return identity
	var envelope: Dictionary = PublicReplayEnvelopeScript.build(
		contract_owner,
		identity,
		str(identity.get("match_id", "")),
		opponent_deck_id,
		strategy_seat,
		(
			opponent_owner.public_replay_identity()
			if opponent_owner != null and opponent_owner.has_method("public_replay_identity")
			else null
		)
	)
	if not bool(envelope.get("accepted", false)):
		return envelope
	var replay_id := "author-%d-vs-%d-%d-s%d" % [
		candidate_deck_id, opponent_deck_id, seed, strategy_seat,
	]
	var created: Dictionary = PublicReplayCaptureScript.create(
		contract_owner,
		envelope.get("envelope"),
		replay_id,
		str(envelope.get("card_asset_catalog_sha256", "")),
		str(envelope.get("event_dictionary_sha256", ""))
	)
	if not bool(created.get("accepted", false)):
		return created
	var source: Dictionary = owner.public_replay_source_snapshot()
	var appended: Dictionary = created.get("capture").append_public_source(
		source.get("source"), "match_started"
	) if bool(source.get("ok", false)) else source
	if not bool(appended.get("accepted", false)):
		return appended
	return {
		"accepted": true,
		"error_code": "",
		"capture": created.get("capture"),
	}


func _finish_public_replay_capture(
	capture: Variant,
	owner: Variant,
	existing_error: String,
	output_root: String,
	candidate_deck_id: int,
	opponent_deck_id: int,
	seed: int,
	strategy_seat: int,
	terminal: bool
) -> Dictionary:
	if not existing_error.is_empty():
		return {"accepted": false, "error_code": existing_error}
	if capture == null or owner == null:
		return {"accepted": false, "error_code": "public_replay_not_started"}
	if not terminal:
		return {"accepted": false, "error_code": "public_replay_match_incomplete"}
	var source: Dictionary = owner.public_replay_source_snapshot()
	var completed: Dictionary = capture.finish(source.get("source")) \
		if bool(source.get("ok", false)) else source
	if not bool(completed.get("accepted", false)):
		return {
			"accepted": false,
			"error_code": str(completed.get("error_code", "public_replay_finish_failed")),
		}
	var artifact: Dictionary = completed.get("artifact", {})
	var path := "%s/author-%d-vs-%d-seed-%d-seat-%d.json" % [
		output_root.trim_suffix("/"), candidate_deck_id, opponent_deck_id, seed,
		strategy_seat,
	]
	var write_error := _write_canonical_json(path, artifact)
	if not write_error.is_empty():
		return {"accepted": false, "error_code": write_error}
	return {
		"accepted": true,
		"error_code": "",
		"path": path,
		"artifact_sha256": FileAccess.get_sha256(path).to_upper(),
		"match_envelope_sha256": artifact.get("manifest", {}).get("match_envelope_sha256"),
		"frame_chain_root_sha256": artifact.get("manifest", {}).get("frame_chain_root_sha256"),
		"frame_count": artifact.get("manifest", {}).get("frame_count", 0),
		"participants": artifact.get("match_envelope", {}).get(
			"participants", []
		).duplicate(true),
	}


static func _write_canonical_json(path: String, value: Variant) -> String:
	var canonical: Dictionary = JsonTreeScript.canonicalize_artifact(value)
	if not bool(canonical.get("ok", false)):
		return "public_replay_canonicalization_failed"
	var absolute_path := ProjectSettings.globalize_path(path)
	var make_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if make_error != OK:
		return "public_replay_directory_failed:%s" % error_string(make_error)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "public_replay_write_failed:%s" % error_string(FileAccess.get_open_error())
	file.store_buffer(canonical.get("bytes", PackedByteArray()))
	file = null
	return ""


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
	result["last_error_code"] = str(audit.get("last_error_code", ""))
	result["matched_rule_counts"] = audit.get("matched_rule_counts", {}).duplicate(true)
	return result


func _row_is_dirty(row: Dictionary, audit: Dictionary) -> bool:
	if not bool(row.get("terminal", false)) or not str(row.get("failure", "")).is_empty():
		return true
	if row.has("public_replay") and not bool(row.get("public_replay", {}).get("accepted", false)):
		return true
	if int(row.get("winner_index", -1)) not in [0, 1]:
		return true
	if int(audit.get("policy_calls", 0)) <= 0 \
		or int(audit.get("policy_calls", 0)) != int(audit.get("policy_successes", 0)):
		return true
	for key: String in [
		"policy_errors", "invalid_outputs", "same_window_fallbacks",
		"classic_fallbacks", "engine_rejections",
	]:
		if int(audit.get(key, 0)) != 0:
			return true
	return int(audit.get("engine_commits", 0)) <= 0


func _case_dirty_reasons(per_game: Array[Dictionary], totals: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	for row: Dictionary in per_game:
		if not bool(row.get("terminal", false)):
			reasons.append("game_%d_not_terminal" % int(row.get("game", 0)))
		if not str(row.get("failure", "")).is_empty():
			reasons.append("game_%d_%s" % [row.get("game"), row.get("failure")])
		if row.has("public_replay") and not bool(row.get("public_replay", {}).get("accepted", false)):
			reasons.append("game_%d_public_replay_%s" % [
				row.get("game"), row.get("public_replay", {}).get("error_code", "invalid"),
			])
		if int(row.get("winner_index", -1)) not in [0, 1]:
			reasons.append("game_%d_missing_winner" % int(row.get("game", 0)))
	if int(totals.get("policy_calls", 0)) <= 0 \
		or int(totals.get("policy_calls", 0)) != int(totals.get("policy_successes", 0)):
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
		if arg.begins_with("--games-per-matchup="):
			result["games_per_matchup"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seed-base="):
			result["seed_base"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--matchup-offset="):
			result["matchup_offset"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--max-steps="):
			result["max_steps"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--opponent-deck-id="):
			result["opponent_deck_id"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--candidate-deck-id="):
			result["candidate_deck_id"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--candidate-package-id="):
			result["candidate_package_id"] = arg.get_slice("=", 1)
		elif arg.begins_with("--package-version="):
			result["package_version"] = arg.get_slice("=", 1)
		elif arg == "--capture-developer-trace":
			result["capture_developer_trace"] = true
		elif arg == "--capture-public-replays":
			result["capture_public_replays"] = true
		elif arg.begins_with("--replay-output-root="):
			result["replay_output_root"] = arg.get_slice("=", 1)
		elif arg == "--continue-on-dirty":
			result["stop_on_dirty"] = false
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
