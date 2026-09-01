class_name AuthorStrategyWindowsExportMatchAcceptance
extends RefCounted

const MARNIE_DECK_ID := 800018501
const RULES_AI_DECK_ID := 575720
const PACKAGE_ID := "ptcgdap.marnie.windows-local"
const PACKAGE_VERSION := "0.1.0"
const PACKAGE_ARCHIVE_SHA256 := "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
const DEFAULT_GAMES := 3
const DEFAULT_SEED_BASE := 84600
const DEFAULT_MAX_STEPS := 700
const GateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd")
const OwnerScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")
const CatalogScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func run(card_database: Node, options: Dictionary = {}) -> Dictionary:
	var games := clampi(int(options.get("games", DEFAULT_GAMES)), 1, 20)
	var seed_base := int(options.get("seed_base", DEFAULT_SEED_BASE))
	var max_steps := clampi(int(options.get("max_steps", DEFAULT_MAX_STEPS)), 1, 2000)
	var marnie: DeckData = card_database.call("get_deck", MARNIE_DECK_ID) if card_database != null else null
	var rules_deck: DeckData = card_database.call("get_deck", RULES_AI_DECK_ID) if card_database != null else null
	if marnie == null or rules_deck == null:
		return _failed_report(games, seed_base, max_steps, "deck_load_failed")

	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var totals := {
		"policy_calls": 0,
		"policy_successes": 0,
		"policy_errors": 0,
		"invalid_outputs": 0,
		"same_window_fallbacks": 0,
		"classic_fallbacks": 0,
		"external_process_attempts": 0,
		"engine_commits": 0,
		"engine_rejections": 0,
	}
	var decision_elapsed_usec: Array[int] = []
	var per_game: Array[Dictionary] = []
	var started_usec := Time.get_ticks_usec()
	for game_index: int in games:
		var row := _run_game(catalog, marnie, rules_deck, game_index, seed_base + game_index, max_steps)
		per_game.append(row)
		var audit: Dictionary = row.get("audit", {})
		for key: String in totals:
			totals[key] += int(audit.get(key, 0))
		decision_elapsed_usec.append_array(row.get("decision_elapsed_usec", []))
	catalog.free()

	var dirty_reasons := _dirty_reasons(per_game, totals)
	var sorted_samples := decision_elapsed_usec.duplicate()
	sorted_samples.sort()
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	return {
		"document_type": "author_strategy_windows_export_match_report_v1",
		"schema_version": 1,
		"evidence_kind": "windows_development_exported_executable_real_rules_e2e",
		"development_only": true,
		"development_player_authority": true,
		"production_ready": false,
		"a5_claimed": false,
		"execution_trusted": false,
		"cabt_exportable": false,
		"android_ready": false,
		"ui_driven": false,
		"headless_match_driver": true,
		"network_blocked": false,
		"airplane_mode_claimed": false,
		"remote_inference_attempts": 0,
		"dynamic_download_attempts": 0,
		"package_id": PACKAGE_ID,
		"package_version": PACKAGE_VERSION,
		"archive_sha256": PACKAGE_ARCHIVE_SHA256,
		"policy_package_id": "ptcgdap.marnie.windows-local.policy",
		"policy_package_version": "0.1.0",
		"policy_package_manifest_canonical_sha256": per_game[0].get("audit", {}).get("policy_package_manifest_canonical_sha256") if not per_game.is_empty() else null,
		"execution_location": "device_local",
		"learned_model": "none",
		"model_backend": "none",
		"learned_model_invoked": false,
		"card_id_domain": "godot_local_card_uid_v1",
		"marnie_deck_id": MARNIE_DECK_ID,
		"rules_ai_deck_id": RULES_AI_DECK_ID,
		"owner_seat": 1,
		"rules_ai_seat": 0,
		"games": games,
		"seed_base": seed_base,
		"max_steps": max_steps,
		"complete_match_finished": dirty_reasons.is_empty(),
		"totals": totals,
		"decision_timing": {
			"unit": "usec",
			"sample_count": sorted_samples.size(),
			"maximum": sorted_samples[-1] if not sorted_samples.is_empty() else 0,
			"p95": _percentile(sorted_samples, 0.95),
		},
		"elapsed_msec": int(ceili(float(elapsed_usec) / 1000.0)),
		"is_clean": dirty_reasons.is_empty(),
		"dirty_reasons": dirty_reasons,
		"per_game": per_game,
		"limitations": [
			"This development report proves an exported executable can run the exact built-in package against the existing rules AI to terminal state.",
			"The driver is headless and is not a UI-to-terminal acceptance run.",
			"No OS-level network block, production signature, approved device profile, rollback drill, or A5 claim is provided.",
		],
	}


func _run_game(
	catalog: Node,
	marnie: DeckData,
	rules_deck: DeckData,
	game_index: int,
	seed: int,
	max_steps: int
) -> Dictionary:
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
		requested.get("handle"), gsm, 1, "windows-export-match-%d" % seed
	) if bool(requested.get("ok", false)) else requested
	var owner: Variant = built.get("owner")
	var rules_ai := _rules_ai(0, rules_deck)
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	if owner != null:
		bridge.set_ai_controllers(rules_ai, owner)
	bridge.bootstrap_pending_setup()
	var decision_samples: Array[int] = []
	var steps := 0
	var failure := ""
	while owner != null and not gsm.game_state.is_game_over() and steps < max_steps:
		var owner_driven := false
		var step_started_usec := Time.get_ticks_usec()
		var progressed := false
		if bridge.has_pending_prompt():
			var prompt_owner := bridge.get_pending_prompt_owner()
			if prompt_owner == 1:
				owner_driven = true
				progressed = bool(owner.run_single_step(bridge, gsm))
			elif bridge.can_resolve_pending_prompt():
				progressed = bridge.resolve_pending_prompt()
			else:
				progressed = rules_ai.run_single_step(bridge, gsm)
		elif gsm.game_state.current_player_index == 1:
			owner_driven = true
			progressed = bool(owner.run_single_step(bridge, gsm))
		else:
			progressed = rules_ai.run_single_step(bridge, gsm)
		if owner_driven:
			decision_samples.append(maxi(0, Time.get_ticks_usec() - step_started_usec))
		if not progressed:
			failure = "no_progress:%s" % bridge.get_pending_prompt_type()
			break
		steps += 1
	if owner == null and failure.is_empty():
		failure = str(built.get("error_code", "owner_bind_failed"))
	if steps >= max_steps and not gsm.game_state.is_game_over() and failure.is_empty():
		failure = "step_cap"
	var audit: Dictionary = owner.audit_snapshot() if owner != null else {}
	var row := {
		"game": game_index + 1,
		"seed": seed,
		"steps": steps,
		"winner_index": int(gsm.game_state.winner_index),
		"win_reason": str(gsm.game_state.win_reason),
		"failure": failure,
		"terminal": gsm.game_state.is_game_over(),
		"decision_elapsed_usec": decision_samples,
		"audit": audit,
	}
	if owner != null:
		owner.close_match()
	bridge.free()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return row


func _dirty_reasons(per_game: Array[Dictionary], totals: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	for row: Dictionary in per_game:
		if not bool(row.get("terminal", false)):
			reasons.append("game_%d_not_terminal" % int(row.get("game", 0)))
		if not str(row.get("failure", "")).is_empty():
			reasons.append("game_%d_%s" % [int(row.get("game", 0)), row.get("failure")])
		if int(row.get("winner_index", -1)) not in [0, 1]:
			reasons.append("game_%d_missing_winner" % int(row.get("game", 0)))
		var audit: Dictionary = row.get("audit", {})
		if (
			audit.get("policy_package_id") != "ptcgdap.marnie.windows-local.policy"
			or audit.get("learned_model") != "none"
			or audit.get("model_backend") != "none"
			or audit.get("learned_model_invoked") != false
			or audit.get("execution_location") != "device_local"
			or str(audit.get("policy_package_manifest_canonical_sha256", "")).length() != 64
		):
			reasons.append("game_%d_policy_package_witness" % int(row.get("game", 0)))
	if int(totals.get("policy_calls", 0)) <= 0 or totals.get("policy_calls") != totals.get("policy_successes"):
		reasons.append("policy_accounting")
	for key: String in [
		"policy_errors", "invalid_outputs", "same_window_fallbacks", "classic_fallbacks",
		"external_process_attempts", "engine_rejections",
	]:
		if int(totals.get(key, 0)) != 0:
			reasons.append("%s:%d" % [key, int(totals.get(key, 0))])
	if int(totals.get("engine_commits", 0)) <= 0:
		reasons.append("no_engine_commits")
	return reasons


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


func _percentile(sorted_samples: Array[int], fraction: float) -> int:
	if sorted_samples.is_empty():
		return 0
	var index := clampi(int(ceili(float(sorted_samples.size()) * fraction)) - 1, 0, sorted_samples.size() - 1)
	return sorted_samples[index]


func _failed_report(games: int, seed_base: int, max_steps: int, code: String) -> Dictionary:
	return {
		"document_type": "author_strategy_windows_export_match_report_v1",
		"schema_version": 1,
		"evidence_kind": "windows_development_exported_executable_real_rules_e2e",
		"development_only": true,
		"production_ready": false,
		"a5_claimed": false,
		"ui_driven": false,
		"network_blocked": false,
		"games": games,
		"seed_base": seed_base,
		"max_steps": max_steps,
		"complete_match_finished": false,
		"is_clean": false,
		"dirty_reasons": [code],
		"per_game": [],
	}
