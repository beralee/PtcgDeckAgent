extends Control

const MODEL_DECK_ID := 800018501
const RULES_DECK_ID := 800018501
const PACKAGE_ID := "dev.codex.minimal-bc-rl-marnie"
const PACKAGE_VERSION := "0.1.1"
const PACKAGE_SHA256 := "D4A7BAD9A6C7ECD6837026E090F2FF7CC592D90F1E0DB578968311BAA27BCBA0"
const DEFAULT_SEED := 88630
const DEFAULT_MAX_STEPS := 700
const CatalogScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")
const GateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd")
const OwnerFactoryScript = preload("res://scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd")
const ExecutionGateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsExecutionGate.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func _ready() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	var report := _run(int(options.seed), int(options.max_steps))
	if not str(options.output).is_empty():
		_write_json(str(options.output), report)
	print("MINIMAL_BC_RL_MODEL_BATTLE_RESULT " + JSON.stringify(report))
	get_tree().quit(0 if bool(report.get("is_clean", false)) else 1)


func _run(seed: int, max_steps: int) -> Dictionary:
	var model_deck: DeckData = CardDatabase.get_deck(MODEL_DECK_ID)
	var rules_deck: DeckData = CardDatabase.get_deck(RULES_DECK_ID)
	if model_deck == null or rules_deck == null:
		return _failure("deck_load_failed")
	var catalog := CatalogScript.new()
	var catalog_report: Dictionary = catalog.scan_startup()
	var discovered := false
	for value: Variant in catalog_report.get("metadata_records", []):
		if value is Dictionary and (
			value.get("package_id") == PACKAGE_ID
			and value.get("package_version") == PACKAGE_VERSION
			and value.get("archive_sha256") == PACKAGE_SHA256
			and value.get("install_source") == "user"
		):
			discovered = true
			break
	if not discovered:
		catalog.free()
		return _failure("installed_model_package_missing")
	var requested: Dictionary = GateScript.request_match_handle(
		catalog,
		{
			"package_id": PACKAGE_ID,
			"package_version": PACKAGE_VERSION,
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "user",
		},
		"Windows"
	)
	if not bool(requested.get("ok", false)):
		catalog.free()
		return _failure(str(requested.get("error_code", "package_handle_failed")))
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(seed)
	var gsm := GameStateMachine.new()
	if gsm.coin_flipper != null:
		var rng: Variant = gsm.coin_flipper.get("_rng")
		if rng is RandomNumberGenerator:
			(rng as RandomNumberGenerator).seed = seed
	gsm.start_game(rules_deck, model_deck, 0)
	var built: Dictionary = OwnerFactoryScript.build_windows_author_owner(
		requested.get("handle"), gsm, 1,
		"minimal-bc-rl-model-%d" % seed,
		ExecutionGateScript.DEVELOPMENT_MODE
	)
	var owner: Variant = built.get("owner")
	if owner == null:
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
		catalog.free()
		return _failure(str(built.get("error_code", "owner_bind_failed")))
	owner.enable_developer_decision_trace(true)
	var rules_ai := _rules_ai(0, rules_deck)
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	bridge.set_ai_controllers(rules_ai, owner)
	bridge.bootstrap_pending_setup()
	var steps := 0
	var failure := ""
	while not gsm.game_state.is_game_over() and steps < max_steps:
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
	if steps >= max_steps and not gsm.game_state.is_game_over() and failure.is_empty():
		failure = "step_cap"
	var audit: Dictionary = owner.audit_snapshot()
	var trace_records: Array = owner.drain_developer_decision_records()
	var replay_identity: Dictionary = owner.public_replay_identity()
	var replay_snapshot: Dictionary = owner.public_replay_source_snapshot()
	var dirty_reasons: Array[String] = []
	if not gsm.game_state.is_game_over(): dirty_reasons.append("game_not_terminal")
	if not failure.is_empty(): dirty_reasons.append(failure)
	if int(gsm.game_state.winner_index) not in [0, 1]: dirty_reasons.append("missing_winner")
	if int(audit.get("policy_calls", 0)) <= 0 or audit.get("policy_calls") != audit.get("policy_successes"):
		dirty_reasons.append("policy_accounting")
	for zero_key: String in [
		"policy_errors", "invalid_outputs", "same_window_fallbacks",
		"classic_fallbacks", "engine_rejections", "model_fallbacks",
	]:
		if int(audit.get(zero_key, 0)) != 0:
			dirty_reasons.append("%s:%d" % [zero_key, int(audit.get(zero_key, 0))])
	if int(audit.get("engine_commits", 0)) <= 0: dirty_reasons.append("no_engine_commits")
	if audit.get("model_policy_mode") != "rules_with_model": dirty_reasons.append("model_mode_missing")
	if int(audit.get("model_inference_successes", 0)) <= 0: dirty_reasons.append("model_not_invoked")
	if int(audit.get("model_changed_selections", 0)) <= 0: dirty_reasons.append("model_did_not_change_selection")
	if audit.get("model_artifact_sha256") != "0BAF0E2C1E3F92CE65794928419AF321CD75A3BB8400FED11BB99E9C09DCF136":
		dirty_reasons.append("model_artifact_pin_mismatch")
	if not bool(replay_identity.get("ok", false)): dirty_reasons.append("replay_identity_missing")
	if not bool(replay_snapshot.get("ok", false)): dirty_reasons.append("replay_snapshot_missing")
	var report := {
		"document_type": "minimal_ptcgai_bc_rl_real_battle_evidence_v1",
		"schema_version": 1,
		"evidence_kind": "windows_godot_native_ort_real_rules_battle",
		"package": {
			"package_id": PACKAGE_ID,
			"package_version": PACKAGE_VERSION,
			"archive_sha256": PACKAGE_SHA256,
			"install_source": "user",
		},
		"model": {
			"training_method": "bc_rl",
			"rl_scope": "offline_contextual_bandit",
			"artifact_sha256": audit.get("model_artifact_sha256"),
			"manifest_sha256": audit.get("model_manifest_sha256"),
			"execution_provider": audit.get("model_execution_provider"),
			"decision_windows": audit.get("model_decision_windows"),
			"inference_successes": audit.get("model_inference_successes"),
			"fallbacks": audit.get("model_fallbacks"),
			"changed_selections": audit.get("model_changed_selections"),
			"elapsed_usec": audit.get("model_elapsed_usec", []).duplicate(),
			"diagnostic_counts": audit.get("model_diagnostic_counts", {}).duplicate(true),
			"cpu_only": true,
			"remote_inference": false,
		},
		"battle": {
			"seed": seed,
			"model_seat": 1,
			"rules_seat": 0,
			"steps": steps,
			"terminal": gsm.game_state.is_game_over(),
			"winner_index": int(gsm.game_state.winner_index),
			"win_reason": str(gsm.game_state.win_reason),
			"failure": failure,
		},
		"audit": audit,
		"decision_trace": {
			"record_count": trace_records.size(),
			"public_sha256": _sha_json(trace_records),
			"semantic_sha256": _sha_json(_semantic_trace(trace_records)),
			"first_record": trace_records[0].duplicate(true) if not trace_records.is_empty() else {},
		},
		"replay": {
			"identity": replay_identity,
			"public_snapshot_sha256": _sha_json(replay_snapshot),
		},
		"claims": {
			"development_only": true,
			"production_ready": false,
			"android_validated": false,
			"macos_validated": false,
			"external_process_dependency": false,
			"hidden_state_input": false,
		},
		"is_clean": dirty_reasons.is_empty(),
		"dirty_reasons": dirty_reasons,
	}
	owner.close_match()
	bridge.free()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	catalog.free()
	return report


func _rules_ai(seat: int, deck: DeckData) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(seat, 1)
	DeckStrategyRegistryScript.new().apply_strategy_for_deck(ai, deck)
	ai.use_mcts = false
	ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	return ai


func _sha_json(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(value).to_utf8_buffer())
	return context.finish().hex_encode().to_upper()


func _semantic_trace(records: Array) -> Array:
	var result: Array = []
	for value: Variant in records:
		result.append(_without_timing(value))
	return result


func _without_timing(value: Variant) -> Variant:
	if value is Array:
		var array_result: Array = []
		for child: Variant in value:
			array_result.append(_without_timing(child))
		return array_result
	if value is Dictionary:
		var dictionary_result := {}
		for key: Variant in value:
			if str(key) in ["elapsed_us", "latency_usec"]:
				continue
			dictionary_result[key] = _without_timing(value[key])
		return dictionary_result
	return value


func _failure(code: String) -> Dictionary:
	return {
		"document_type": "minimal_ptcgai_bc_rl_real_battle_evidence_v1",
		"schema_version": 1,
		"is_clean": false,
		"dirty_reasons": [code],
	}


func _write_json(path: String, report: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write minimal BC/RL battle report: %s" % path)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()


func _parse_args(args: PackedStringArray) -> Dictionary:
	var result := {"seed": DEFAULT_SEED, "max_steps": DEFAULT_MAX_STEPS, "output": ""}
	for argument: String in args:
		if argument.begins_with("--seed="):
			result.seed = int(argument.get_slice("=", 1))
		elif argument.begins_with("--max-steps="):
			result.max_steps = maxi(1, int(argument.get_slice("=", 1)))
		elif argument.begins_with("--output="):
			result.output = argument.trim_prefix("--output=")
	return result
