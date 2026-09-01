extends Control

const MARNIE_DECK_ID := 800018501
const RULES_AI_DECK_ID := 575720
const PACKAGE_ID := "ptcgdap.marnie.windows-local"
const PACKAGE_VERSION := "0.1.0"
const PACKAGE_ARCHIVE_SHA256 := "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
const DEFAULT_GAMES := 2
const DEFAULT_SEED_BASE := 84200
const DEFAULT_MAX_STEPS := 600
const PackageAIScript = preload("res://tests/ptcgdap/godot/support/MarniePackageDevelopmentAIOpponent.gd")
const CatalogScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")

const PINNED_SOURCE_PATHS := [
	"res://data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai",
	"res://data/bundled_user/decks/800018501.json",
	"res://data/bundled_user/decks/575720.json",
	"res://scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd",
	"res://scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd",
	"res://data/ptcgdap/marnie_windows_policy_package_v1.json",
	"res://contracts/ptcgdap/policy_package_v1.schema.json",
	"res://contracts/ptcgdap/policy_package_v1_profile.json",
	"res://contracts/ptcgdap/policy_package_v1_bundle.json",
	"res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd",
	"res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageHandle.gd",
	"res://scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd",
	"res://tests/ptcgdap/godot/support/DragapultPythonAIOpponent.gd",
	"res://tests/ptcgdap/godot/support/MarniePackageDevelopmentAIOpponent.gd",
	"res://tests/ptcgdap/godot/test_author_strategy_package_rules_e2e.gd",
	"res://tests/ptcgdap/godot/run_author_strategy_package_rules_e2e.gd",
	"res://tests/ptcgdap/godot/run_author_strategy_package_rules_e2e.tscn",
	"res://scripts/ai/AIOpponent.gd",
	"res://scripts/ai/AILegalActionBuilder.gd",
	"res://scripts/ai/HeadlessMatchBridge.gd",
	"res://scripts/ai/AIBenchmarkRunner.gd",
	"res://scripts/ai/DeckStrategyRegistry.gd",
	"res://scripts/engine/GameStateMachine.gd",
]


func _ready() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	var report := _run_acceptance(options)
	var output_path := str(options.get("output", ""))
	if not output_path.is_empty():
		_write_json(output_path, report)
	print("AUTHOR_STRATEGY_PACKAGE_RULES_E2E_RESULT " + JSON.stringify(report))
	get_tree().quit(0 if bool(report.get("is_clean", false)) else 1)


func _run_acceptance(options: Dictionary) -> Dictionary:
	var games := int(options.get("games", DEFAULT_GAMES))
	var seed_base := int(options.get("seed_base", DEFAULT_SEED_BASE))
	var max_steps := int(options.get("max_steps", DEFAULT_MAX_STEPS))
	var marnie: DeckData = CardDatabase.get_deck(MARNIE_DECK_ID)
	var rules_deck: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	var source_at_start := _source_snapshot()
	var deck_error := _deck_error(marnie, rules_deck)
	if not deck_error.is_empty():
		return _failed_report(options, deck_error, source_at_start)
	var catalog := CatalogScript.new()
	var catalog_report: Dictionary = catalog.scan_startup()
	if not _has_exact_builtin_record(catalog_report):
		catalog.free()
		return _failed_report(options, "exact_builtin_candidate_missing", source_at_start)
	var runner := AIBenchmarkRunnerScript.new()
	var per_game: Array = []
	var totals := {
		"wins": 0,
		"losses": 0,
		"draws": 0,
		"policy_calls": 0,
		"policy_successes": 0,
		"policy_errors": 0,
		"invalid_outputs": 0,
		"fallbacks": 0,
		"setup_calls": 0,
		"interaction_calls": 0,
		"send_out_calls": 0,
		"rule_baseline_comparisons": 0,
		"rule_baseline_unavailable": 0,
		"matched_rule_evaluations": 0,
		"macro_preferred_selections": 0,
	}
	var matched_rule_counts := {}
	var failure_reasons := {}
	var started := Time.get_ticks_msec()
	for game_index: int in games:
		var seed := seed_base + game_index
		var tracked_seat := game_index % 2
		var requested: Dictionary = catalog.request_match_handle(
			PACKAGE_ID, PACKAGE_VERSION, PACKAGE_ARCHIVE_SHA256
		)
		var gsm := GameStateMachine.new()
		if gsm.coin_flipper != null:
			var rng: Variant = gsm.coin_flipper.get("_rng")
			if rng is RandomNumberGenerator:
				(rng as RandomNumberGenerator).seed = seed
		var seed_owner := PlayerState.new()
		seed_owner.set_forced_shuffle_seed(seed)
		gsm.start_game(
			marnie if tracked_seat == 0 else rules_deck,
			rules_deck if tracked_seat == 0 else marnie,
			0
		)
		var package_ai := PackageAIScript.new()
		package_ai.configure(tracked_seat, 1)
		package_ai.use_mcts = false
		package_ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
		var bind: Dictionary = package_ai.bind_package_match(gsm, requested.get("handle")) \
			if bool(requested.get("ok", false)) else requested
		var rules_ai := _rules_ai(1 - tracked_seat, rules_deck)
		var result: Dictionary
		if bool(bind.get("ok", false)):
			result = runner.run_headless_duel(
				package_ai if tracked_seat == 0 else rules_ai,
				rules_ai if tracked_seat == 0 else package_ai,
				gsm,
				max_steps
			)
		else:
			result = {
				"winner_index": -1,
				"turn_count": int(gsm.game_state.turn_number),
				"steps": 0,
				"failure_reason": "package_bind_failed",
				"stalled": false,
				"terminated_by_cap": false,
			}
		var audit: Dictionary = package_ai.get_package_execution_audit()
		var winner := int(result.get("winner_index", -1))
		var outcome := "draw"
		if winner == tracked_seat:
			totals["wins"] += 1
			outcome = "win"
		elif winner in [0, 1]:
			totals["losses"] += 1
			outcome = "loss"
		else:
			totals["draws"] += 1
		var failure_reason := str(result.get("failure_reason", ""))
		failure_reasons[failure_reason] = int(failure_reasons.get(failure_reason, 0)) + 1
		for key: String in [
			"policy_calls", "policy_successes", "policy_errors", "invalid_outputs", "fallbacks",
			"setup_calls", "interaction_calls", "send_out_calls", "rule_baseline_comparisons",
			"rule_baseline_unavailable", "matched_rule_evaluations", "macro_preferred_selections",
		]:
			totals[key] += int(audit.get(key, 0))
		for rule_id: Variant in audit.get("matched_rule_counts", {}):
			matched_rule_counts[rule_id] = int(matched_rule_counts.get(rule_id, 0)) + int(audit.get("matched_rule_counts", {}).get(rule_id, 0))
		per_game.append({
			"game": game_index + 1,
			"seed": seed,
			"tracked_seat": tracked_seat,
			"outcome": outcome,
			"winner_index": winner,
			"turn_count": int(result.get("turn_count", 0)),
			"steps": int(result.get("steps", 0)),
			"failure_reason": failure_reason,
			"stalled": bool(result.get("stalled", false)),
			"terminated_by_cap": bool(result.get("terminated_by_cap", false)),
			"bind": bind,
			"package_execution_audit": audit,
		})
		package_ai.close_package_match()
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
	catalog.free()
	var source_at_end := _source_snapshot()
	var source_changed := source_at_start != source_at_end
	var dirty_reasons: Array = []
	for row: Dictionary in per_game:
		var policy_audit: Dictionary = row.get("package_execution_audit", {})
		if int(row.get("winner_index", -1)) not in [0, 1]:
			dirty_reasons.append("game_%d_missing_winner" % int(row.get("game", 0)))
		if bool(row.get("stalled", false)):
			dirty_reasons.append("game_%d_stalled" % int(row.get("game", 0)))
		if bool(row.get("terminated_by_cap", false)):
			dirty_reasons.append("game_%d_action_cap" % int(row.get("game", 0)))
		if str(row.get("failure_reason", "")) not in ["normal_game_end", "deck_out"]:
			dirty_reasons.append("game_%d_%s" % [int(row.get("game", 0)), str(row.get("failure_reason", "missing_terminal_reason"))])
		if (
			policy_audit.get("policy_package_id") != "ptcgdap.marnie.windows-local.policy"
			or policy_audit.get("learned_model") != "none"
			or policy_audit.get("model_backend") != "none"
			or policy_audit.get("learned_model_invoked") != false
			or policy_audit.get("execution_location") != "device_local"
			or str(policy_audit.get("policy_package_manifest_canonical_sha256", "")).length() != 64
		):
			dirty_reasons.append("game_%d_policy_package_witness" % int(row.get("game", 0)))
	if totals.policy_calls <= 0 or totals.policy_calls != totals.policy_successes:
		dirty_reasons.append("policy_call_accounting")
	if totals.policy_errors > 0:
		dirty_reasons.append("policy_errors:%d" % totals.policy_errors)
	if totals.invalid_outputs > 0:
		dirty_reasons.append("invalid_outputs:%d" % totals.invalid_outputs)
	if totals.fallbacks > 0:
		dirty_reasons.append("fallbacks:%d" % totals.fallbacks)
	if totals.setup_calls < games:
		dirty_reasons.append("setup_not_package_selected_for_every_game")
	if totals.matched_rule_evaluations <= 0 or totals.macro_preferred_selections <= 0:
		dirty_reasons.append("package_adapter_rules_not_exercised")
	if source_changed:
		dirty_reasons.append("source_changed_during_run")
	return {
		"schema_version": 1,
		"evidence_kind": "windows_development_author_package_real_engine_e2e",
		"alignment_level": "godot_local_uid_package_development_execution",
		"development_host_execution": true,
		"local_index_boundary": true,
		"official_cabt_interface_alignment": false,
		"cross_runtime_policy_conformance": false,
		"official_cabt_engine_parity": false,
		"player_live_allowed": false,
		"android_validated": false,
		"development_package_signature_required": false,
		"development_authority": "exact_builtin_archive_sha256",
		"production_signature_gate_unchanged": true,
		"production_signature_status": "unprovisioned",
		"exact_archive_sha_development_gate": true,
		"external_process_dependency": false,
		"cabt_exportable": false,
		"card_id_domain": "godot_local_card_uid_v1",
		"package_id": PACKAGE_ID,
		"package_version": PACKAGE_VERSION,
		"package_archive_sha256": PACKAGE_ARCHIVE_SHA256,
		"marnie_deck_id": MARNIE_DECK_ID,
		"rules_ai_deck_id": RULES_AI_DECK_ID,
		"rules_ai_runtime_mode": "rules_only",
		"games": games,
		"seed_base": seed_base,
		"seeds": range(seed_base, seed_base + games),
		"tracked_seats": [0, 1] if games >= 2 else [0],
		"max_steps": max_steps,
		"wins": totals.wins,
		"losses": totals.losses,
		"draws": totals.draws,
		"policy_calls": totals.policy_calls,
		"policy_successes": totals.policy_successes,
		"policy_errors": totals.policy_errors,
		"invalid_outputs": totals.invalid_outputs,
		"fallbacks": totals.fallbacks,
		"setup_calls": totals.setup_calls,
		"interaction_calls": totals.interaction_calls,
		"send_out_calls": totals.send_out_calls,
		"rule_baseline_comparisons": totals.rule_baseline_comparisons,
		"rule_baseline_unavailable": totals.rule_baseline_unavailable,
		"matched_rule_evaluations": totals.matched_rule_evaluations,
		"macro_preferred_selections": totals.macro_preferred_selections,
		"matched_rule_counts": matched_rule_counts,
		"failure_reasons": failure_reasons,
		"capabilities": {
			"setup_active": "package_selected_real_engine",
			"setup_bench": "package_selected_semantic_plan_real_engine_binding",
			"main": "package_selected_real_engine",
			"effect_prompts": "package_selected_when_real_engine_requests_interaction",
			"send_out": "package_selected_real_engine_when_reached",
			"take_prize": "headless_bridge_first_legal_slot_not_package_selected",
		},
		"weights_present": true,
		"policy_package_id": "ptcgdap.marnie.windows-local.policy",
		"policy_package_version": "0.1.0",
		"policy_package_manifest_canonical_sha256": per_game[0].get("package_execution_audit", {}).get("policy_package_manifest_canonical_sha256") if not per_game.is_empty() else null,
		"execution_location": "device_local",
		"learned_model": "none",
		"model_backend": "none",
		"learned_model_invoked": false,
		"source_at_start": source_at_start,
		"source_at_end": source_at_end,
		"source_changed_during_run": source_changed,
		"elapsed_msec": Time.get_ticks_msec() - started,
		"is_clean": dirty_reasons.is_empty(),
		"dirty_reasons": dirty_reasons,
		"per_game": per_game,
	}


func _rules_ai(seat: int, deck: DeckData) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(seat, 1)
	DeckStrategyRegistryScript.new().apply_strategy_for_deck(ai, deck)
	ai.use_mcts = false
	ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	return ai


func _deck_error(marnie: DeckData, rules_deck: DeckData) -> String:
	if marnie == null or rules_deck == null:
		return "deck_load_failed"
	if int(marnie.id) != MARNIE_DECK_ID or int(rules_deck.id) != RULES_AI_DECK_ID:
		return "deck_identity_mismatch"
	var count := 0
	var uids := {}
	for entry: Dictionary in marnie.cards:
		count += int(entry.get("count", 0))
		uids["%s_%s" % [entry.get("set_code"), entry.get("card_index")]] = true
	return "" if count == 60 and uids.size() == 28 else "marnie_deck_manifest_mismatch"


func _has_exact_builtin_record(report: Dictionary) -> bool:
	for value: Variant in report.get("metadata_records", []):
		if (
			value is Dictionary
			and value.get("package_id") == PACKAGE_ID
			and value.get("package_version") == PACKAGE_VERSION
			and value.get("archive_sha256") == PACKAGE_ARCHIVE_SHA256
			and value.get("install_source") == "built_in"
		):
			return true
	return false


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


func _failed_report(options: Dictionary, code: String, source: Dictionary) -> Dictionary:
	return {
		"schema_version": 1,
		"evidence_kind": "windows_development_author_package_real_engine_e2e",
		"games": int(options.get("games", DEFAULT_GAMES)),
		"is_clean": false,
		"dirty_reasons": [code],
		"source_at_start": source,
		"per_game": [],
	}


func _write_json(path: String, report: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write author package E2E report: %s" % path)
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
