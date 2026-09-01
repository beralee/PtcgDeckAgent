class_name MarnieGiftBoxVsOgerpon
extends Control

const GateScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd"
)
const CatalogScript = preload(
	"res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd"
)
const OwnerFactoryScript = preload(
	"res://scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd"
)
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const MatrixHelpersScript = preload("res://scripts/tools/run_ogerpon_author_vs_rule_matrix.gd")

const CANDIDATE_DECK_ID := 646600
const CANDIDATE_PACKAGE_ID := "dev.bodao-yongzhe.marnies-gift-box"
const OPPONENT_DECK_ID := 800052301
const OPPONENT_PACKAGE_ID := "dev.beralee.v18.ogerpon-crustle-v523a"
const OPPONENT_PACKAGE_VERSION := "1.4.0"
const OPPONENT_ARCHIVE_SHA256 := "3B4E78A16EB2C238CD9CFB29CA29B8CF44E0D7D99822CA9C1ECD90A2651DFFB8"
const REPORT_PREFIX := "MARNIE_GIFT_BOX_VS_OGERPON="


func _ready() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	var report := run_benchmark(options)
	var output_path := str(options.get(
		"output", "res://artifacts/deck_training/marnie_gift_box_r0_vs_ogerpon.json"
	))
	var helper := MatrixHelpersScript.new()
	var write_error: String = helper._write_report(output_path, report)
	helper.free()
	if not write_error.is_empty():
		report["is_clean"] = false
		(report["dirty_reasons"] as Array).append(write_error)
	report["output_path"] = output_path
	print(REPORT_PREFIX + JSON.stringify(report))
	get_tree().quit(0 if bool(report.get("is_clean", false)) else 1)


func run_benchmark(options: Dictionary = {}) -> Dictionary:
	var explicit_seeds: Array[int] = []
	for seed_value: Variant in options.get("seed_list", []):
		explicit_seeds.append(int(seed_value))
	var requested_games := (
		explicit_seeds.size() * 2
		if not explicit_seeds.is_empty()
		else clampi(int(options.get("games", 20)), 2, 200)
	)
	var games := requested_games if requested_games % 2 == 0 else requested_games + 1
	var seed_base := int(options.get("seed_base", 646600))
	var max_steps := clampi(int(options.get("max_steps", 700)), 100, 2000)
	var package_version := str(options.get("package_version", "0.1.0"))
	var candidate_deck_id := int(options.get("candidate_deck_id", CANDIDATE_DECK_ID))
	var candidate_package_id := str(options.get(
		"candidate_package_id", CANDIDATE_PACKAGE_ID
	))
	var opponent_deck_id := int(options.get("opponent_deck_id", OPPONENT_DECK_ID))
	var opponent_package_id := str(options.get(
		"opponent_package_id", OPPONENT_PACKAGE_ID
	))
	var opponent_package_version := str(options.get(
		"opponent_package_version", OPPONENT_PACKAGE_VERSION
	))
	var opponent_archive_sha256 := str(options.get(
		"opponent_archive_sha256", OPPONENT_ARCHIVE_SHA256
	))
	var candidate := GateScript.candidate_for_package_identity(
		candidate_package_id, package_version
	)
	var opponent := GateScript.candidate_for_package_identity(
		opponent_package_id, opponent_package_version
	)
	var replay_root := str(options.get(
		"replay_output_root",
		"res://artifacts/deck_training/marnie_gift_box_r0_vs_ogerpon_replays"
	))
	var capture_replays := bool(options.get("capture_public_replays", true))
	var capture_developer_trace := bool(options.get("capture_developer_trace", false))
	var stop_on_dirty := bool(options.get("stop_on_dirty", true))
	var rows: Array[Dictionary] = []
	var dirty_reasons: Array[String] = []
	var candidate_deck: DeckData = CardDatabase.get_ai_deck(candidate_deck_id)
	var opponent_deck: DeckData = CardDatabase.get_ai_deck(opponent_deck_id)
	if candidate.is_empty():
		dirty_reasons.append("candidate_gate_missing:%s@%s" % [candidate_package_id, package_version])
	if opponent.is_empty() or opponent.get("archive_sha256") != opponent_archive_sha256:
		dirty_reasons.append("opponent_gate_or_hash_mismatch")
	if candidate_deck == null:
		dirty_reasons.append("candidate_deck_load_failed:%d" % candidate_deck_id)
	if opponent_deck == null:
		dirty_reasons.append("opponent_deck_load_failed:%d" % opponent_deck_id)
	var catalog := CatalogScript.new()
	var catalog_scan: Dictionary = _compact_catalog_scan(catalog.scan_startup())
	var catalog_evidence := _package_catalog_evidence(
		catalog, candidate_package_id, opponent_package_id, opponent_package_version
	)
	if dirty_reasons.is_empty():
		for game_index: int in games:
			var row := _run_game(
				catalog, candidate_deck, opponent_deck, candidate, opponent,
				game_index, (
					explicit_seeds[game_index / 2]
					if not explicit_seeds.is_empty() else seed_base + game_index / 2
				), max_steps, capture_developer_trace, capture_replays, replay_root,
				candidate_deck_id, opponent_deck_id, candidate_package_id,
				opponent_package_id, opponent_package_version, opponent_archive_sha256
			)
			rows.append(row)
			var row_reasons := _row_dirty_reasons(row)
			for reason: String in row_reasons:
				dirty_reasons.append("game_%d:%s" % [game_index + 1, reason])
			if stop_on_dirty and not row_reasons.is_empty():
				break
			if (game_index + 1) % 10 == 0 or game_index + 1 == games:
				print("MARNIE_GIFT_PROGRESS=%d/%d wins=%d" % [
					game_index + 1, games, _win_count(rows),
				])
	catalog.free()
	var wins := _win_count(rows)
	var valid := rows.size()
	return {
		"document_type": "marnie_gift_box_vs_ogerpon_author_benchmark_v1",
		"schema_version": 1,
		"development_only": true,
		"production_ready": false,
		"official_cabt_engine_parity": false,
		"candidate": {
			"deck_id": candidate_deck_id,
			"package_id": candidate_package_id,
			"package_version": package_version,
			"archive_sha256": candidate.get("archive_sha256", ""),
		},
		"opponent": {
			"deck_id": opponent_deck_id,
			"package_id": opponent_package_id,
			"package_version": opponent_package_version,
			"archive_sha256": opponent_archive_sha256,
		},
		"catalog_scan": catalog_scan,
		"catalog_evidence": catalog_evidence,
		"seat_policy": "paired seeds; candidate alternates seats; seat 0 starts",
		"seed_policy": (
			"explicit paired seed list"
			if not explicit_seeds.is_empty() else "seed_base + floor(game_index / 2)"
		),
		"seed_base": seed_base,
		"seed_list": explicit_seeds.duplicate(),
		"requested_games": requested_games,
		"games": valid,
		"candidate_wins": wins,
		"opponent_wins": valid - wins,
		"candidate_win_rate": float(wins) / float(valid) if valid > 0 else 0.0,
		"candidate_win_rate_percent": 100.0 * float(wins) / float(valid) if valid > 0 else 0.0,
		"wilson_95": MatrixHelpersScript.wilson_95(wins, valid),
		"seat_split": _seat_split(rows),
		"capture_public_replays": capture_replays,
		"capture_developer_trace": capture_developer_trace,
		"replay_output_root": replay_root if capture_replays else "",
		"clean_gate": {
			"terminal_and_winner": true,
			"both_package_policy_call_accounting": true,
			"invalid_error_fallback_rejection_zero": true,
			"replay_accepted": capture_replays,
		},
		"is_clean": dirty_reasons.is_empty() and valid == games,
		"dirty_reasons": dirty_reasons,
		"per_game": rows,
	}


func _run_game(
	catalog: Variant,
	candidate_deck: DeckData,
	opponent_deck: DeckData,
	candidate: Dictionary,
	opponent: Dictionary,
	game_index: int,
	seed: int,
	max_steps: int,
	capture_developer_trace: bool,
	capture_replay: bool,
	replay_root: String,
	candidate_deck_id: int,
	opponent_deck_id: int,
	candidate_package_id: String,
	opponent_package_id: String,
	opponent_package_version: String,
	opponent_archive_sha256: String
) -> Dictionary:
	var candidate_seat := game_index % 2
	var opponent_seat := 1 - candidate_seat
	var candidate_request := GateScript.request_match_handle(catalog, {
		"package_id": candidate.get("package_id"),
		"package_version": candidate.get("package_version"),
		"archive_sha256": candidate.get("archive_sha256"),
		"install_source": "built_in",
	}, "Windows")
	var opponent_request := GateScript.request_match_handle(catalog, {
		"package_id": opponent.get("package_id"),
		"package_version": opponent.get("package_version"),
		"archive_sha256": opponent.get("archive_sha256"),
		"install_source": "built_in",
	}, "Windows")
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
	var shared_match_id := "author-vs-author-%d-s%d" % [seed, candidate_seat]
	var candidate_built: Dictionary = OwnerFactoryScript.build_windows_development_author_owner(
		candidate_request.get("handle"), gsm, candidate_seat,
		shared_match_id
	) if bool(candidate_request.get("ok", false)) else candidate_request
	var opponent_built: Dictionary = OwnerFactoryScript.build_windows_development_author_owner(
		opponent_request.get("handle"), gsm, opponent_seat,
		shared_match_id
	) if bool(opponent_request.get("ok", false)) else opponent_request
	var candidate_owner: Variant = candidate_built.get("owner")
	var opponent_owner: Variant = opponent_built.get("owner")
	if capture_developer_trace:
		for owner: Variant in [candidate_owner, opponent_owner]:
			if owner != null and owner.has_method("enable_developer_decision_trace"):
				owner.enable_developer_decision_trace(true)
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	if candidate_owner != null and opponent_owner != null:
		bridge.set_ai_controllers(
			candidate_owner if candidate_seat == 0 else opponent_owner,
			opponent_owner if candidate_seat == 0 else candidate_owner
		)
	bridge.bootstrap_pending_setup()
	var helper := MatrixHelpersScript.new()
	var replay_capture: Variant = null
	var replay_error := ""
	if capture_replay and candidate_owner != null:
		var started: Dictionary = helper._start_public_replay_capture(
			candidate_owner, candidate_deck_id, opponent_deck_id,
			candidate_seat, seed, opponent_owner
		)
		if bool(started.get("accepted", false)):
			replay_capture = started.get("capture")
		else:
			replay_error = str(started.get("error_code", "public_replay_start_failed"))
	var failure := ""
	var steps := 0
	while candidate_owner != null and opponent_owner != null \
		and not gsm.game_state.is_game_over() and steps < max_steps:
		var acting_seat := bridge.get_pending_prompt_owner() \
			if bridge.has_pending_prompt() else int(gsm.game_state.current_player_index)
		var acting_owner: Variant = candidate_owner if acting_seat == candidate_seat else opponent_owner
		if not bool(acting_owner.run_single_step(bridge, gsm)):
			failure = "no_progress:%s:s%d" % [bridge.get_pending_prompt_type(), acting_seat]
			break
		steps += 1
		if replay_capture != null and replay_error.is_empty() and not gsm.game_state.is_game_over():
			var source: Dictionary = candidate_owner.public_replay_source_snapshot()
			var appended: Dictionary = replay_capture.append_public_source(
				source.get("source"), "state_progressed"
			) if bool(source.get("ok", false)) else source
			if not bool(appended.get("accepted", false)):
				replay_error = str(appended.get("error_code", "public_replay_progress_failed"))
	if candidate_owner == null and failure.is_empty():
		failure = str(candidate_built.get("error_code", "candidate_owner_bind_failed"))
	if opponent_owner == null and failure.is_empty():
		failure = str(opponent_built.get("error_code", "opponent_owner_bind_failed"))
	if steps >= max_steps and not gsm.game_state.is_game_over() and failure.is_empty():
		failure = "step_cap"
	var winner := int(gsm.game_state.winner_index)
	var candidate_decisions: Array = candidate_owner.drain_developer_decision_records() \
		if capture_developer_trace and candidate_owner != null \
		and candidate_owner.has_method("drain_developer_decision_records") else []
	var opponent_decisions: Array = opponent_owner.drain_developer_decision_records() \
		if capture_developer_trace and opponent_owner != null \
		and opponent_owner.has_method("drain_developer_decision_records") else []
	var row := {
		"game": game_index + 1,
		"pair": game_index / 2 + 1,
		"seed": seed,
		"candidate_seat": candidate_seat,
		"winner_index": winner,
		"candidate_outcome": "win" if winner == candidate_seat else "loss",
		"win_reason": str(gsm.game_state.win_reason),
		"steps": steps,
		"terminal": gsm.game_state.is_game_over(),
		"failure": failure,
		"candidate_request": {
			"ok": bool(candidate_request.get("ok", false)),
			"error_code": str(candidate_request.get("error_code", "")),
		},
		"opponent_request": {
			"ok": bool(opponent_request.get("ok", false)),
			"error_code": str(opponent_request.get("error_code", "")),
		},
		"candidate_audit": _compact_audit(
			candidate_owner.audit_snapshot() if candidate_owner != null else {}
		),
		"opponent_audit": _compact_audit(
			opponent_owner.audit_snapshot() if opponent_owner != null else {}
		),
		"candidate_archive_sha256": candidate.get("archive_sha256"),
		"opponent_archive_sha256": opponent.get("archive_sha256"),
	}
	if capture_developer_trace:
		row["candidate_developer_decisions"] = candidate_decisions
		row["opponent_developer_decisions"] = opponent_decisions
	if capture_replay:
		row["public_replay"] = helper._finish_public_replay_capture(
			replay_capture, candidate_owner, replay_error, replay_root,
			candidate_deck_id, opponent_deck_id, seed, candidate_seat,
			gsm.game_state.is_game_over()
		)
		var replay_identity_error := _replay_identity_error(
			row["public_replay"], candidate_package_id, opponent_package_id,
			opponent_package_version, opponent_archive_sha256
		)
		if not replay_identity_error.is_empty():
			row["public_replay"]["accepted"] = false
			row["public_replay"]["error_code"] = replay_identity_error
	if candidate_owner != null:
		candidate_owner.close_match()
	if opponent_owner != null:
		opponent_owner.close_match()
	helper.free()
	bridge.free()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return row


func _compact_audit(audit: Dictionary) -> Dictionary:
	var result := {}
	for key: String in [
		"policy_calls", "policy_successes", "policy_errors", "invalid_outputs",
		"same_window_fallbacks", "classic_fallbacks", "engine_commits", "engine_rejections",
	]:
		result[key] = int(audit.get(key, 0))
	return result


func _package_catalog_evidence(
	catalog: Variant,
	candidate_package_id: String = CANDIDATE_PACKAGE_ID,
	opponent_package_id: String = OPPONENT_PACKAGE_ID,
	opponent_package_version: String = OPPONENT_PACKAGE_VERSION
) -> Dictionary:
	var records: Array = catalog.list_metadata_records() if catalog != null else []
	var diagnostics: Array = catalog.list_diagnostics() if catalog != null else []
	var selected_records: Array[Dictionary] = []
	var selected_diagnostics: Array[Dictionary] = []
	for record: Dictionary in records:
		if (
			record.get("package_id") == candidate_package_id
			or (
				record.get("package_id") == opponent_package_id
				and record.get("package_version") == opponent_package_version
			)
		):
			selected_records.append(record.duplicate(true))
	for diagnostic: Dictionary in diagnostics:
		var label := JSON.stringify(diagnostic)
		if candidate_package_id in label or opponent_package_id in label \
			or "marnie" in label.to_lower() or "ogerpon" in label.to_lower():
			selected_diagnostics.append(diagnostic.duplicate(true))
	return {"records": selected_records, "diagnostics": selected_diagnostics}


func _compact_catalog_scan(scan: Dictionary) -> Dictionary:
	var diagnostic_codes: Array[String] = []
	for diagnostic: Dictionary in scan.get("diagnostics", []):
		diagnostic_codes.append(str(diagnostic.get("error_code", "unknown")))
	return {
		"schema_version": scan.get("schema_version"),
		"scan_generation": scan.get("scan_generation"),
		"metadata_record_count": scan.get("metadata_records", []).size(),
		"ready_record_count": scan.get("ready_records", []).size(),
		"diagnostic_codes": diagnostic_codes,
	}


func _replay_identity_error(
	replay: Dictionary,
	candidate_package_id: String = CANDIDATE_PACKAGE_ID,
	opponent_package_id: String = OPPONENT_PACKAGE_ID,
	opponent_package_version: String = OPPONENT_PACKAGE_VERSION,
	opponent_archive_sha256: String = OPPONENT_ARCHIVE_SHA256
) -> String:
	if not bool(replay.get("accepted", false)):
		return str(replay.get("error_code", "public_replay_invalid"))
	var participants: Array = replay.get("participants", [])
	if participants.size() != 2:
		return "public_replay_participants_invalid"
	var candidate_participant: Variant = participants[0]
	var opponent_participant: Variant = participants[1]
	if not candidate_participant is Dictionary or not opponent_participant is Dictionary:
		return "public_replay_participants_invalid"
	if (
		candidate_participant.get("package_id") != candidate_package_id
		or candidate_participant.get("archive_sha256") != GateScript.candidate_for_package_identity(
			candidate_package_id, str(candidate_participant.get("release_version", ""))
		).get("archive_sha256")
	):
		return "public_replay_candidate_identity_mismatch"
	if (
		opponent_participant.get("package_id") != opponent_package_id
		or opponent_participant.get("release_version") != opponent_package_version
		or opponent_participant.get("archive_sha256") != opponent_archive_sha256
	):
		return "public_replay_opponent_identity_mismatch"
	return ""


func _audit_dirty_reasons(prefix: String, audit: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	if int(audit.get("policy_calls", 0)) <= 0 \
		or int(audit.get("policy_calls", 0)) != int(audit.get("policy_successes", 0)):
		reasons.append("%s_policy_accounting" % prefix)
	for key: String in [
		"policy_errors", "invalid_outputs", "same_window_fallbacks",
		"classic_fallbacks", "engine_rejections",
	]:
		if int(audit.get(key, 0)) != 0:
			reasons.append("%s_%s:%d" % [prefix, key, int(audit.get(key, 0))])
	if int(audit.get("engine_commits", 0)) <= 0:
		reasons.append("%s_no_engine_commits" % prefix)
	return reasons


func _row_dirty_reasons(row: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	if not bool(row.get("terminal", false)):
		reasons.append("not_terminal")
	if int(row.get("winner_index", -1)) not in [0, 1]:
		reasons.append("missing_winner")
	if not str(row.get("failure", "")).is_empty():
		reasons.append(str(row.get("failure")))
	if row.has("public_replay") and not bool(row.get("public_replay", {}).get("accepted", false)):
		reasons.append("public_replay:%s" % row.get("public_replay", {}).get("error_code", "invalid"))
	reasons.append_array(_audit_dirty_reasons("candidate", row.get("candidate_audit", {})))
	reasons.append_array(_audit_dirty_reasons("opponent", row.get("opponent_audit", {})))
	return reasons


func _win_count(rows: Array[Dictionary]) -> int:
	return rows.reduce(func(total: int, row: Dictionary) -> int:
		return total + (1 if row.get("candidate_outcome") == "win" else 0)
	, 0)


func _seat_split(rows: Array[Dictionary]) -> Dictionary:
	var result := {
		"candidate_seat_0": {"games": 0, "wins": 0},
		"candidate_seat_1": {"games": 0, "wins": 0},
	}
	for row: Dictionary in rows:
		var key := "candidate_seat_%d" % int(row.get("candidate_seat", 0))
		result[key]["games"] += 1
		if row.get("candidate_outcome") == "win":
			result[key]["wins"] += 1
	return result


func _parse_args(args: PackedStringArray) -> Dictionary:
	var result := {}
	for arg: String in args:
		if arg.begins_with("--games="):
			result["games"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seed-base="):
			result["seed_base"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seed-list="):
			var seeds: Array[int] = []
			for seed_value: String in arg.get_slice("=", 1).split(",", false):
				if seed_value.strip_edges().is_valid_int():
					seeds.append(int(seed_value.strip_edges()))
			result["seed_list"] = seeds
		elif arg.begins_with("--max-steps="):
			result["max_steps"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--package-version="):
			result["package_version"] = arg.get_slice("=", 1)
		elif arg.begins_with("--candidate-deck-id="):
			result["candidate_deck_id"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--candidate-package-id="):
			result["candidate_package_id"] = arg.get_slice("=", 1)
		elif arg.begins_with("--opponent-deck-id="):
			result["opponent_deck_id"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--opponent-package-id="):
			result["opponent_package_id"] = arg.get_slice("=", 1)
		elif arg.begins_with("--opponent-package-version="):
			result["opponent_package_version"] = arg.get_slice("=", 1)
		elif arg.begins_with("--opponent-archive-sha256="):
			result["opponent_archive_sha256"] = arg.get_slice("=", 1)
		elif arg.begins_with("--output="):
			result["output"] = arg.get_slice("=", 1)
		elif arg.begins_with("--replay-output-root="):
			result["replay_output_root"] = arg.get_slice("=", 1)
		elif arg == "--no-public-replays":
			result["capture_public_replays"] = false
		elif arg == "--capture-developer-trace":
			result["capture_developer_trace"] = true
		elif arg == "--no-stop-on-dirty":
			result["stop_on_dirty"] = false
	return result
