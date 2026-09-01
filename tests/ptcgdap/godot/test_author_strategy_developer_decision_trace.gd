class_name TestAuthorStrategyDeveloperDecisionTrace
extends TestBase

const TracePath := "res://scripts/ui/battle/author_strategy/AuthorStrategyDeveloperDecisionTrace.gd"
const OwnerScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")
const CatalogScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")
const GateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd")
const BattleSceneScene = preload("res://scenes/battle/BattleScene.tscn")
const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")

const MARNIE_DECK_ID := 800018501
const RULES_AI_DECK_ID := 575720
const PACKAGE_ID := "ptcgdap.marnie.windows-local"
const PACKAGE_VERSION := "0.1.0"
const PACKAGE_ARCHIVE_SHA256 := "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
const TEST_ROOT := "user://ptcgdap_tests/developer_decision_trace"


class FakeOwner extends RefCounted:
	var enabled := false
	var queued: Array = []

	func public_replay_identity() -> Dictionary:
		return {
			"ok": true,
			"match_id": "policy-match-fixture",
			"source_authority": "ptcgdap_author_public_owner_v1",
			"card_catalog_sha256": "B".repeat(64),
			"strategy_participant": {
				"strategy_id": "fixture.strategy",
				"release_version": "0.1.0",
				"package_id": "fixture.package",
				"archive_sha256": "A".repeat(64),
			},
		}

	func audit_snapshot() -> Dictionary:
		return {
			"policy_calls": 1,
			"policy_successes": 1,
			"engine_commits": 1,
			"engine_rejections": 0,
		}

	func enable_developer_decision_trace(value: bool = true) -> void:
		enabled = value

	func drain_developer_decision_records() -> Array:
		var result := queued.duplicate(true)
		queued.clear()
		return result


func _load_trace() -> Variant:
	return load(TracePath) if ResourceLoader.exists(TracePath) else null


func _remove_dir(path: String) -> void:
	var global := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(global):
		return
	var dir := DirAccess.open(global)
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry not in [".", ".."]:
			var child := global.path_join(entry)
			if dir.current_is_dir():
				_remove_dir(path.path_join(entry))
				DirAccess.remove_absolute(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(global)


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(_read(path))
	return parsed if parsed is Dictionary else {}


func _selection() -> Dictionary:
	return {
		"package_id": PACKAGE_ID,
		"package_version": PACKAGE_VERSION,
		"archive_sha256": PACKAGE_ARCHIVE_SHA256,
		"install_source": "built_in",
	}


func _request_handle() -> Dictionary:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var result: Dictionary = GateScript.request_match_handle(catalog, _selection(), "Windows")
	catalog.free()
	return result


func test_trace_writer_is_incremental_chained_public_safe_and_terminal() -> String:
	_remove_dir(TEST_ROOT)
	var script: Variant = _load_trace()
	if script == null:
		return "AuthorStrategyDeveloperDecisionTrace is missing"
	var match_dir := TEST_ROOT.path_join("match_trace_fixture")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(match_dir))
	var owner := FakeOwner.new()
	owner.queued.append({
		"document_type": "decision_window_record_v1",
		"schema_version": 1,
		"decision_id": "policy-match-fixture.window.1",
		"frame": {
			"source": {"public_observation_hash": "C".repeat(64), "window_id": "D".repeat(64)},
			"public_state": {"self": {"hand": [{"local_card_uid": "SVI_001"}]}, "opponent": {"hand_count": 7}},
			"options": [{"index": 0, "option_fingerprint": "E".repeat(64)}],
		},
		"policy": {"selected_indexes": [0], "reason_code": "deterministic_fallback"},
		"host": {"accepted_indexes": [0], "status": "accepted", "fallback_used": false},
	})
	var trace: Variant = script.new()
	var started: Dictionary = trace.start(owner, match_dir, 5)
	trace.record_owner_step(owner, "progressed", 7)
	var finished: Dictionary = trace.finish(owner, 1, "prize_out", 8)
	var verified: Dictionary = script.verify_trace_dir(match_dir)
	var manifest := _json(match_dir.path_join("developer_decision_trace_manifest.json"))
	var raw := _read(match_dir.path_join("developer_decisions.jsonl"))
	var trace_lines := raw.split("\n", false)
	var step_envelope: Dictionary = JSON.parse_string(trace_lines[1]) \
		if trace_lines.size() > 1 else {}
	var step_payload: Dictionary = step_envelope.get("payload", {})
	var checks := run_checks([
		assert_true(bool(started.get("ok", false)), str(started)),
		assert_true(owner.enabled, "trace start must explicitly enable owner capture"),
		assert_true(bool(finished.get("ok", false)), str(finished)),
		assert_true(bool(manifest.get("complete", false))),
		assert_eq(manifest.get("document_type"), "developer_decision_trace_manifest_v1"),
		assert_eq(int(manifest.get("decision_count", -1)), 1),
		assert_eq(int(manifest.get("owner_step_count", -1)), 1),
		assert_eq(int(step_payload.get("native_event_count_before_step", -1)), 5),
		assert_eq(int(step_payload.get("native_event_count_after_step", -1)), 7),
		assert_eq((manifest.get("terminal", {}) as Dictionary).get("winner_index"), 1),
		assert_true(bool(verified.get("accepted", false)), str(verified)),
		assert_true(raw.contains("SVI_001"), "acting policy own hand is allowed evidence"),
		assert_eq(raw.find("search_begin_input"), -1),
		assert_eq(raw.find("opponent_hidden_hand"), -1),
	])
	_remove_dir(TEST_ROOT)
	return checks


func test_trace_writer_drops_forbidden_private_record_without_breaking_owner() -> String:
	_remove_dir(TEST_ROOT)
	var script: Variant = _load_trace()
	if script == null:
		return "AuthorStrategyDeveloperDecisionTrace is missing"
	var match_dir := TEST_ROOT.path_join("match_private_fixture")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(match_dir))
	var owner := FakeOwner.new()
	owner.queued.append({
		"document_type": "decision_window_record_v1",
		"schema_version": 1,
		"decision_id": "policy-match-fixture.window.1",
		"opponent_hidden_hand": ["must-not-leak"],
	})
	var trace: Variant = script.new()
	var started: Dictionary = trace.start(owner, match_dir)
	trace.record_owner_step(owner, "progressed")
	var finished: Dictionary = trace.finish(owner, 0, "prize_out", 1)
	var raw := _read(match_dir.path_join("developer_decisions.jsonl"))
	var audit: Dictionary = trace.audit_snapshot()
	var checks := run_checks([
		assert_true(bool(started.get("ok", false))),
		assert_false(bool(finished.get("complete", true)), "privacy rejection must make the diagnostic trace explicitly incomplete"),
		assert_eq(int(audit.get("dropped_record_count", 0)), 1),
		assert_eq(raw.find("must-not-leak"), -1),
		assert_eq(raw.find("opponent_hidden_hand"), -1),
		assert_true(owner.enabled, "diagnostic rejection must not disable or mutate the game owner"),
	])
	_remove_dir(TEST_ROOT)
	return checks


func test_real_author_owner_exposes_exact_ordered_window_policy_audit_and_option_fingerprints() -> String:
	var requested := _request_handle()
	if not bool(requested.get("ok", false)):
		return "exact package handle failed: %s" % str(requested)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84312)
	var gsm := GameStateMachine.new()
	gsm.start_game(CardDatabase.get_deck(MARNIE_DECK_ID), CardDatabase.get_deck(RULES_AI_DECK_ID), 0)
	var built: Dictionary = OwnerScript.create(
		requested.get("handle"), gsm, 0, "developer-decision-window-fixture"
	)
	if not bool(built.get("ok", false)):
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
		return "author owner bind failed: %s" % str(built)
	var owner: Variant = built.get("owner")
	if not owner.has_method("enable_developer_decision_trace"):
		owner.close_match()
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
		return "author owner developer trace capture is missing"
	owner.enable_developer_decision_trace(true)
	var options: Array = owner.call("_options_for_items", [
		{"kind": "play_trainer"},
		{"kind": "end_turn"},
	], "")
	var selected: Array = owner.call("_select_items", "main", options, 1, 1)
	var records: Array = owner.drain_developer_decision_records()
	var record: Dictionary = records[0] if not records.is_empty() and records[0] is Dictionary else {}
	var frame: Dictionary = record.get("frame", {})
	var traced_options: Array = frame.get("options", [])
	var policy: Dictionary = record.get("policy", {})
	var base: Dictionary = policy.get("base_result", {})
	var host: Dictionary = record.get("host", {})
	var opponent: Dictionary = (frame.get("public_state", {}) as Dictionary).get("opponent", {})
	var checks := run_checks([
		assert_eq(record.get("document_type"), "decision_window_record_v1"),
		assert_eq(frame.get("prompt_kind"), "main"),
		assert_eq(traced_options.size(), 2),
		assert_eq(int((traced_options[0] as Dictionary).get("index", -1)), 0),
		assert_eq(int((traced_options[1] as Dictionary).get("index", -1)), 1),
		assert_true(str((traced_options[0] as Dictionary).get("option_fingerprint", "")).length() == 64),
		assert_true(str((traced_options[1] as Dictionary).get("option_fingerprint", "")).length() == 64),
		assert_true(str((frame.get("source", {}) as Dictionary).get("public_observation_hash", "")).length() == 64),
		assert_true(str((frame.get("source", {}) as Dictionary).get("window_id", "")).length() == 64),
		assert_eq(host.get("accepted_indexes"), selected),
		assert_eq(
			(host.get("accepted_option_fingerprints", []) as Array).size(),
			selected.size(),
			"accepted indexes must bind to the exact scoped option fingerprints"
		),
		assert_eq(host.get("status"), "accepted"),
		assert_true(base.get("node_audit") is Array and not (base.get("node_audit") as Array).is_empty()),
		assert_true(str(base.get("execution_hash", "")).length() == 64),
		assert_true(policy.get("matched_rule_ids") is Array),
		assert_true(opponent.has("hand_count")),
		assert_false(opponent.has("hand")),
	])
	owner.close_match()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return checks


func test_completed_native_manifest_binds_and_verifies_developer_decision_trace() -> String:
	_remove_dir(TEST_ROOT)
	var trace_script: Variant = _load_trace()
	if trace_script == null:
		return "AuthorStrategyDeveloperDecisionTrace is missing"
	var recorder_script: Variant = load("res://scripts/engine/BattleRecorder.gd")
	var loader_script: Variant = load("res://scripts/engine/NativeReplayDiagnosticLoader.gd")
	var recorder: Variant = recorder_script.new()
	recorder.set_output_root(TEST_ROOT)
	recorder.start_match({"mode": "ai", "player_labels": ["human", "author"]})
	var match_dir := str(recorder.get_match_dir())
	var owner := FakeOwner.new()
	owner.queued.append({
		"document_type": "decision_window_record_v1",
		"schema_version": 1,
		"decision_id": "policy-match-fixture.window.1",
		"frame": {
			"source": {"public_observation_hash": "C".repeat(64), "window_id": "D".repeat(64)},
			"public_state": {"opponent": {"hand_count": 7}},
			"options": [{"index": 0, "option_fingerprint": "E".repeat(64)}],
		},
		"policy": {"reported_indexes": [0]},
		"host": {"accepted_indexes": [0], "status": "accepted"},
	})
	var trace: Variant = trace_script.new()
	var started: Dictionary = trace.start(owner, match_dir)
	trace.record_owner_step(owner, "progressed")
	var trace_finished: Dictionary = trace.finish(owner, 0, "prize_out", 1)
	recorder.record_event({
		"event_type": "state_snapshot",
		"snapshot_reason": "match_end",
		"turn_number": 1,
		"phase": "game_over",
		"player_index": 0,
	})
	recorder.finalize_match({"winner_index": 0, "reason": "prize_out", "turn_number": 1})
	var report: Dictionary = loader_script.new().inspect_match_dir(match_dir)
	var native_manifest := _json(match_dir.path_join("native_replay_manifest.json"))
	var link: Dictionary = native_manifest.get("developer_decision_trace", {})
	var developer: Dictionary = report.get("developer_decision_trace", {})
	var checks := run_checks([
		assert_true(bool(started.get("ok", false))),
		assert_true(bool(trace_finished.get("complete", false))),
		assert_eq(link.get("capability_state"), "available"),
		assert_true(str(link.get("sha256", "")).length() == 64),
		assert_true(bool(report.get("accepted", false)), str(report)),
		assert_true(bool(developer.get("accepted", false)), str(developer)),
		assert_eq(int(developer.get("decision_count", -1)), 1),
		assert_eq(((report.get("capabilities", {}) as Dictionary).get("decision_windows", {}) as Dictionary).get("state"), "available"),
		assert_false(bool(report.get("execution_authority_granted", true))),
	])
	_remove_dir(TEST_ROOT)
	return checks


func test_author_battle_scene_lifecycle_starts_developer_trace_in_native_match_directory() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
	var requested := _request_handle()
	if not bool(requested.get("ok", false)):
		GameManager.current_mode = previous_mode as GameManager.GameMode
		return "exact package handle failed: %s" % str(requested)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84313)
	var gsm := GameStateMachine.new()
	gsm.start_game(CardDatabase.get_deck(MARNIE_DECK_ID), CardDatabase.get_deck(RULES_AI_DECK_ID), 0)
	var built: Dictionary = OwnerScript.create(
		requested.get("handle"), gsm, 0, "battle-scene-developer-trace-fixture"
	)
	if not bool(built.get("ok", false)):
		GameManager.current_mode = previous_mode as GameManager.GameMode
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
		return "author owner bind failed: %s" % str(built)
	_remove_dir(TEST_ROOT)
	var match_dir := TEST_ROOT.path_join("match_scene_fixture")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(match_dir))
	var owner: Variant = built.get("owner")
	var scene := BattleSceneScript.new()
	scene.set("_gsm", gsm)
	scene.set("_author_player_owner", owner)
	scene.set("_battle_review_match_dir", match_dir)
	var has_start_method := scene.has_method("_start_author_developer_trace")
	if has_start_method:
		scene.call("_start_author_developer_trace", owner)
	var has_trace_field := false
	for property: Dictionary in scene.get_property_list():
		if str(property.get("name", "")) == "_author_developer_decision_trace":
			has_trace_field = true
			break
	var trace: Variant = scene.get("_author_developer_decision_trace") if has_trace_field else null
	var audit: Dictionary = trace.audit_snapshot() if trace != null else {}
	var checks := run_checks([
		assert_true(owner != null and owner.validate_integrity()),
		assert_true(has_start_method, "BattleScene must expose the developer decision trace lifecycle"),
		assert_true(has_trace_field, "BattleScene must own the independent developer decision trace lifecycle"),
		assert_true(trace != null, "author match must start developer diagnostics"),
		assert_eq(audit.get("native_match_id"), match_dir.get_file()),
		assert_true(FileAccess.file_exists(match_dir.path_join("developer_decision_trace_manifest.json"))),
		assert_false(bool(audit.get("execution_authority_granted", true))),
	])
	GameManager.current_mode = previous_mode as GameManager.GameMode
	if scene.has_method("_close_author_developer_trace"):
		scene.call("_close_author_developer_trace", "test_cleanup")
	scene.free()
	owner.close_match()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	_remove_dir(TEST_ROOT)
	return checks
