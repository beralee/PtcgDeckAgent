extends Control

const DRAGAPULT_DECK_ID := 800018499
const RULES_AI_DECK_ID := 575720
const DEFAULT_GAMES := 2
const DEFAULT_SEED_BASE := 83100
const DEFAULT_MAX_STEPS := 600
const EXPECTED_DRAGAPULT_UID_COUNT := 24
const EXPECTED_DRAGAPULT_CARD_COUNT := 60
const EXPECTED_BUNDLE_SHA256 := "ABB35B389AF4CC3FA5BB1415B82406400E7A14B77672614D48DCA32B2EFF5DA1"
const DragapultPythonAIScript = preload("res://tests/ptcgdap/godot/support/DragapultPythonAIOpponent.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")

const PINNED_SOURCE_PATHS := [
	"res://tests/ptcgdap/godot/run_dragapult_python_e2e.gd",
	"res://tests/ptcgdap/godot/run_dragapult_python_e2e.tscn",
	"res://tests/ptcgdap/godot/support/DragapultPythonAIOpponent.gd",
	"res://tests/test_dragapult_python_public_strategy_e2e.gd",
	"res://tests/ptcgdap/test_dragapult_public_strategy.py",
	"res://tools/ptcgdap/build_dragapult_python_strategy_contract.py",
	"res://tools/ptcgdap/run_dragapult_public_strategy.py",
	"res://scripts/ai/ptcgdap/dragapult_public_strategy.py",
	"res://contracts/ptcgdap/dragapult_python_strategy.schema.json",
	"res://contracts/ptcgdap/dragapult_python_strategy_profile.json",
	"res://contracts/ptcgdap/dragapult_python_strategy_conformance_vectors.json",
	"res://contracts/ptcgdap/dragapult_python_strategy_bundle.json",
	"res://data/ptcgdap/dragapult_python_strategy/deck_manifest_v1.json",
	"res://data/ptcgdap/dragapult_python_strategy/policy_v1.json",
	"res://data/ptcgdap/dragapult_python_strategy/rules_ai_opponent_v1.json",
	"res://data/bundled_user/decks/800018499.json",
	"res://data/bundled_user/decks/575720.json",
	"res://scripts/ai/AIOpponent.gd",
	"res://scripts/ai/AILegalActionBuilder.gd",
	"res://scripts/ai/AIStepResolver.gd",
	"res://scripts/ai/HeadlessMatchBridge.gd",
	"res://scripts/ai/AIBenchmarkRunner.gd",
	"res://scripts/ai/DeckStrategyRegistry.gd",
	"res://scripts/ai/DeckStrategyMiraidon.gd",
	"res://scripts/engine/GameStateMachine.gd",
]


func _ready() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	var report := _run_acceptance(options)
	var output_path := str(options.get("json_output", ""))
	if not output_path.is_empty():
		_write_json(output_path, report)
	print("DRAGAPULT_PYTHON_E2E_RESULT " + JSON.stringify(report))
	get_tree().quit(0 if bool(report.get("is_clean", false)) else 1)


func _run_acceptance(options: Dictionary) -> Dictionary:
	var games := int(options.get("games", DEFAULT_GAMES))
	var seed_base := int(options.get("seed_base", DEFAULT_SEED_BASE))
	var max_steps := int(options.get("max_steps", DEFAULT_MAX_STEPS))
	var python_executable := str(options.get("python_executable", "python"))
	var dragapult_deck: DeckData = CardDatabase.get_deck(DRAGAPULT_DECK_ID)
	var rules_deck: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	var deck_error := _validate_decks(dragapult_deck, rules_deck)
	var source_at_start := _source_snapshot()
	if not deck_error.is_empty():
		return _failed_report(options, deck_error, source_at_start)

	var runner := AIBenchmarkRunnerScript.new()
	var per_game: Array = []
	var wins := 0
	var losses := 0
	var draws := 0
	var invalid_outputs := 0
	var python_errors := 0
	var python_timeouts := 0
	var fallbacks := 0
	var python_calls := 0
	var python_successes := 0
	var setup_calls := 0
	var interaction_calls := 0
	var send_out_calls := 0
	var rule_baseline_comparisons := 0
	var rule_baseline_unavailable := 0
	var first_divergence: Dictionary = {}
	var failure_reasons: Dictionary = {}
	var started := Time.get_ticks_msec()

	for game_index: int in games:
		var seed := seed_base + game_index
		var tracked_seat := game_index % 2
		var gsm := GameStateMachine.new()
		if gsm.coin_flipper != null:
			var rng: Variant = gsm.coin_flipper.get("_rng")
			if rng is RandomNumberGenerator:
				(rng as RandomNumberGenerator).seed = seed
		var seed_owner := PlayerState.new()
		seed_owner.set_forced_shuffle_seed(seed)
		var deck_0: DeckData = dragapult_deck if tracked_seat == 0 else rules_deck
		var deck_1: DeckData = rules_deck if tracked_seat == 0 else dragapult_deck
		gsm.start_game(deck_0, deck_1, 0)

		var public_ai := DragapultPythonAIScript.new()
		public_ai.configure(tracked_seat, 1)
		public_ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
		public_ai.use_mcts = false
		var bind_result: Dictionary = public_ai.bind_public_match(gsm, python_executable)
		var rules_ai := _make_rules_ai(1 - tracked_seat, rules_deck)
		var result: Dictionary
		if bool(bind_result.get("ok", false)):
			result = runner.run_headless_duel(
				public_ai if tracked_seat == 0 else rules_ai,
				rules_ai if tracked_seat == 0 else public_ai,
				gsm,
				max_steps
			)
		else:
			result = {
				"winner_index": -1,
				"turn_count": int(gsm.game_state.turn_number),
				"steps": 0,
				"failure_reason": "public_strategy_bind_failed",
				"stalled": false,
				"terminated_by_cap": false,
			}
		var audit: Dictionary = public_ai.get_public_strategy_audit()
		var winner := int(result.get("winner_index", -1))
		var outcome := "draw"
		if winner == tracked_seat:
			wins += 1
			outcome = "win"
		elif winner in [0, 1]:
			losses += 1
			outcome = "loss"
		else:
			draws += 1
		var failure_reason := str(result.get("failure_reason", ""))
		if not failure_reason.is_empty():
			failure_reasons[failure_reason] = int(failure_reasons.get(failure_reason, 0)) + 1
		invalid_outputs += int(audit.get("invalid_outputs", 0))
		python_errors += int(audit.get("python_errors", 0))
		python_timeouts += int(audit.get("python_timeouts", 0))
		fallbacks += int(audit.get("fallbacks", 0))
		python_calls += int(audit.get("python_calls", 0))
		python_successes += int(audit.get("python_successes", 0))
		setup_calls += int(audit.get("setup_calls", 0))
		interaction_calls += int(audit.get("interaction_calls", 0))
		send_out_calls += int(audit.get("send_out_calls", 0))
		rule_baseline_comparisons += int(audit.get("rule_baseline_comparisons", 0))
		rule_baseline_unavailable += int(audit.get("rule_baseline_unavailable", 0))
		if first_divergence.is_empty() and not (audit.get("first_rule_divergence", {}) as Dictionary).is_empty():
			first_divergence = (audit.get("first_rule_divergence", {}) as Dictionary).duplicate(true)
			first_divergence["game"] = game_index + 1
			first_divergence["seed"] = seed
			first_divergence["tracked_seat"] = tracked_seat
		per_game.append({
			"game": game_index + 1,
			"seed": seed,
			"tracked_seat": tracked_seat,
			"forced_first_seat": 0,
			"outcome": outcome,
			"winner_index": winner,
			"turn_count": int(result.get("turn_count", 0)),
			"steps": int(result.get("steps", 0)),
			"failure_reason": failure_reason,
			"stalled": bool(result.get("stalled", false)),
			"terminated_by_cap": bool(result.get("terminated_by_cap", false)),
			"bind": bind_result,
			"public_strategy_audit": audit,
		})
		public_ai.close_public_match()
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()

	var source_at_end := _source_snapshot()
	var source_changed := JSON.stringify(source_at_start) != JSON.stringify(source_at_end)
	var dirty_reasons: Array = []
	for source_phase: Dictionary in [source_at_start, source_at_end]:
		for source_row: Dictionary in source_phase.get("files", []):
			if str(source_row.get("raw_sha256", "")).length() != 64:
				dirty_reasons.append("missing_source_hash:%s" % str(source_row.get("path", "")))
	for row: Dictionary in per_game:
		if int(row.get("winner_index", -1)) not in [0, 1]:
			dirty_reasons.append("game_%d_missing_winner" % int(row.get("game", 0)))
		if bool(row.get("stalled", false)):
			dirty_reasons.append("game_%d_stalled" % int(row.get("game", 0)))
		if bool(row.get("terminated_by_cap", false)):
			dirty_reasons.append("game_%d_action_cap" % int(row.get("game", 0)))
		if str(row.get("failure_reason", "")) not in ["normal_game_end", "deck_out"]:
			dirty_reasons.append("game_%d_%s" % [int(row.get("game", 0)), str(row.get("failure_reason", "missing_terminal_reason"))])
	if python_calls <= 0 or python_successes != python_calls:
		dirty_reasons.append("python_call_accounting")
	if setup_calls < games:
		dirty_reasons.append("setup_not_python_selected_for_every_game")
	if python_errors > 0:
		dirty_reasons.append("python_errors:%d" % python_errors)
	if python_timeouts > 0:
		dirty_reasons.append("python_timeouts:%d" % python_timeouts)
	if invalid_outputs > 0:
		dirty_reasons.append("invalid_outputs:%d" % invalid_outputs)
	if fallbacks > 0:
		dirty_reasons.append("fallbacks:%d" % fallbacks)
	if source_changed:
		dirty_reasons.append("source_changed_during_run")
	return {
		"schema_version": 1,
		"evidence_kind": "windows_development_python_strategy_real_engine_e2e",
		"alignment_level": "local_game_uid_public_strategy_development_acceptance",
		"interface_alignment": true,
		"cross_runtime_policy_conformance": false,
		"godot_python_host_interface_conformance": true,
		"python_gdscript_same_policy_conformance": false,
		"official_cabt_engine_parity": false,
		"player_live_allowed": false,
		"android_validated": false,
		"development_python_only": true,
		"player_runtime_python_dependency": false,
		"cabt_exportable": false,
		"deck_identity_merge_with_official_cabt": false,
		"card_id_domain": "godot_local_card_uid_v1",
		"strategy_bundle_sha256": EXPECTED_BUNDLE_SHA256,
		"dragapult_deck_id": DRAGAPULT_DECK_ID,
		"rules_ai_deck_id": RULES_AI_DECK_ID,
		"rules_ai_runtime_mode": "rules_only",
		"games": games,
		"seed_base": seed_base,
		"seeds": range(seed_base, seed_base + games),
		"tracked_seats": [0, 1] if games >= 2 else [0],
		"max_steps": max_steps,
		"wins": wins,
		"losses": losses,
		"draws": draws,
		"python_calls": python_calls,
		"python_successes": python_successes,
		"python_errors": python_errors,
		"python_timeouts": python_timeouts,
		"invalid_outputs": invalid_outputs,
		"fallbacks": fallbacks,
		"setup_calls": setup_calls,
		"interaction_calls": interaction_calls,
		"send_out_calls": send_out_calls,
		"rule_baseline_comparisons": rule_baseline_comparisons,
		"rule_baseline_unavailable": rule_baseline_unavailable,
		"failure_reasons": failure_reasons,
		"first_rule_divergence": first_divergence,
		"capabilities": {
			"setup_active": "python_selected_real_engine",
			"setup_bench": "python_selected_semantic_plan_real_engine_binding",
			"main": "python_selected_real_engine",
			"search_evolve_attach_effect_target": "python_selected_when_real_engine_requests_interaction",
			"attack": "python_selected_real_engine",
			"send_out": "python_selected_real_engine_when_reached",
			"take_prize": "contract_fixture_validated_bridge_owned_semantically_indistinguishable_slots",
			"terminal_and_fallback": "contract_fixture_validated_same_current_window",
		},
		"source_at_start": source_at_start,
		"source_at_end": source_at_end,
		"source_changed_during_run": source_changed,
		"elapsed_msec": Time.get_ticks_msec() - started,
		"is_clean": dirty_reasons.is_empty(),
		"dirty_reasons": dirty_reasons,
		"per_game": per_game,
	}


func _make_rules_ai(seat: int, deck: DeckData) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(seat, 1)
	var registry := DeckStrategyRegistryScript.new()
	registry.apply_strategy_for_deck(ai, deck)
	ai.use_mcts = false
	ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	return ai


func _validate_decks(dragapult: DeckData, rules_deck: DeckData) -> String:
	if dragapult == null or rules_deck == null:
		return "deck_load_failed"
	if int(dragapult.id) != DRAGAPULT_DECK_ID or int(rules_deck.id) != RULES_AI_DECK_ID:
		return "deck_identity_mismatch"
	var count := 0
	var uids: Dictionary = {}
	for entry: Dictionary in dragapult.cards:
		count += int(entry.get("count", 0))
		uids["%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))]] = true
	if count != EXPECTED_DRAGAPULT_CARD_COUNT or uids.size() != EXPECTED_DRAGAPULT_UID_COUNT:
		return "dragapult_deck_manifest_mismatch"
	return ""


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
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	while file.get_position() < file.get_length():
		if context.update(file.get_buffer(mini(1_048_576, file.get_length() - file.get_position()))) != OK:
			file.close()
			return ""
	file.close()
	return context.finish().hex_encode().to_upper()


func _failed_report(options: Dictionary, code: String, source: Dictionary) -> Dictionary:
	return {
		"schema_version": 1,
		"evidence_kind": "windows_development_python_strategy_real_engine_e2e",
		"games": int(options.get("games", DEFAULT_GAMES)),
		"is_clean": false,
		"dirty_reasons": [code],
		"source_at_start": source,
		"per_game": [],
	}


func _write_json(path: String, report: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write Dragapult Python E2E report: %s" % path)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()


func _parse_args(args: PackedStringArray) -> Dictionary:
	var parsed := {
		"games": DEFAULT_GAMES,
		"seed_base": DEFAULT_SEED_BASE,
		"max_steps": DEFAULT_MAX_STEPS,
		"python_executable": "python",
		"json_output": "",
	}
	for arg: String in args:
		if arg.begins_with("--games="):
			parsed["games"] = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--seed-base="):
			parsed["seed_base"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--max-steps="):
			parsed["max_steps"] = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--python-executable="):
			parsed["python_executable"] = arg.trim_prefix("--python-executable=")
		elif arg.begins_with("--json-output="):
			parsed["json_output"] = arg.trim_prefix("--json-output=")
	return parsed
