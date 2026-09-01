class_name TestNativeReplayDiagnostics
extends TestBase

const RecorderPath := "res://scripts/engine/BattleRecorder.gd"
const LoaderPath := "res://scripts/engine/NativeReplayDiagnosticLoader.gd"
const RecordingControllerPath := "res://scripts/ui/battle/BattleRecordingController.gd"
const ContractPath := "res://contracts/ptcgdap/native_replay_diagnostic_contract.json"
const TEST_ROOT := "user://test_native_replay_diagnostics"


class TerminalRecorderSpy extends RefCounted:
	var result: Dictionary = {}

	func finalize_match(value: Dictionary) -> void:
		result = value.duplicate(true)

	func get_match_dir() -> String:
		return "user://terminal_spy"


class TerminalScene extends Node:
	var _battle_recording_started: bool = true
	var _battle_recording_context_captured: bool = true
	var _battle_recorder: RefCounted = TerminalRecorderSpy.new()
	var _battle_review_match_dir: String = ""


func _cleanup_root() -> void:
	var root := ProjectSettings.globalize_path(TEST_ROOT)
	if DirAccess.dir_exists_absolute(root):
		_remove_dir(root)
		DirAccess.remove_absolute(root)
	elif FileAccess.file_exists(root):
		DirAccess.remove_absolute(root)


func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry not in [".", ".."]:
			var child := path.path_join(entry)
			if dir.current_is_dir():
				_remove_dir(child)
				DirAccess.remove_absolute(child)
			else:
				DirAccess.remove_absolute(child)
		entry = dir.get_next()
	dir.list_dir_end()


func _load_script(path: String) -> Variant:
	return load(path) if ResourceLoader.exists(path) else null


func _new_recorder() -> Variant:
	var script: Variant = _load_script(RecorderPath)
	if script == null:
		return null
	var recorder: Variant = script.new()
	recorder.set_output_root(TEST_ROOT)
	return recorder


func _new_loader() -> Variant:
	var script: Variant = _load_script(LoaderPath)
	return script.new() if script != null else null


func _event(kind: String, turn: int = 1) -> Dictionary:
	return {
		"turn_number": turn,
		"phase": "main",
		"player_index": 0,
		"event_type": kind,
		"snapshot_reason": "turn_start" if kind == "state_snapshot" else "",
	}


func _record_completed(label: String) -> Dictionary:
	var recorder: Variant = _new_recorder()
	if recorder == null:
		return {"ok": false, "error": "BattleRecorder missing"}
	recorder.start_match({
		"mode": "ai",
		"player_labels": [label, "rules"],
		"first_player_index": 0,
		"policy_hash": "A".repeat(64),
		"card_catalog_sha256": "B".repeat(64),
	})
	recorder.record_event(_event("match_started"))
	recorder.record_event(_event("state_snapshot"))
	recorder.record_event(_event("action_selected"))
	recorder.finalize_match({
		"winner_index": 0,
		"reason": "prize_out",
		"turn_number": 1,
	})
	return {"ok": true, "match_dir": recorder.get_match_dir()}


func _read_lines(path: String) -> Array[String]:
	var result: Array[String] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	while not file.eof_reached():
		var line := file.get_line()
		if not line.is_empty():
			result.append(line)
	file.close()
	return result


func _write_lines(path: String, lines: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	for line: String in lines:
		file.store_line(line)
	file.close()


func _copy_flat_match_dir(source: String, target: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target))
	var dir := DirAccess.open(source)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry not in [".", ".."] and not dir.current_is_dir():
			DirAccess.copy_absolute(
				ProjectSettings.globalize_path(source.path_join(entry)),
				ProjectSettings.globalize_path(target.path_join(entry))
			)
		entry = dir.get_next()
	dir.list_dir_end()


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func test_contract_freezes_additive_files_privacy_and_legacy_behavior() -> String:
	var contract := _json(ContractPath)
	var privacy: Dictionary = contract.get("privacy", {})
	var compatibility: Dictionary = contract.get("compatibility", {})
	return run_checks([
		assert_eq(contract.get("contract_id"), "ptcgdap-native-replay-diagnostic-v2"),
		assert_true(bool(contract.get("legacy_playback_semantics_unchanged", false))),
		assert_false(bool(privacy.get("opponent_hidden_cards_allowed", true))),
		assert_true(bool(privacy.get("own_hand_allowed", false))),
		assert_eq(compatibility.get("missing_information"), "never_inferred_or_reconstructed"),
		assert_eq(compatibility.get("diagnostic_write_failure"), "must_not_interrupt_gameplay_or_legacy_recording"),
	])


func test_recording_controller_emits_explicit_done_status_and_rewards_at_game_over() -> String:
	var controller_script: Variant = _load_script(RecordingControllerPath)
	if controller_script == null:
		return "BattleRecordingController is missing"
	var scene := TerminalScene.new()
	controller_script.new().finalize_battle_recording(scene, {
		"winner_index": 1,
		"reason": "prize_out",
		"turn_number": 9,
	})
	var recorder := scene._battle_recorder as TerminalRecorderSpy
	var checks := run_checks([
		assert_eq(recorder.result.get("seat_statuses"), ["DONE", "DONE"]),
		assert_eq(recorder.result.get("rewards"), [-1, 1]),
		assert_eq(recorder.result.get("faults"), [null, null]),
		assert_eq(recorder.result.get("terminal_source"), "local_game_over_signal_v1"),
		assert_false(bool(scene._battle_recording_started)),
	])
	scene.free()
	return checks


func test_completed_native_replay_writes_verifiable_v2_chain_without_changing_detail_events() -> String:
	_cleanup_root()
	var fixture := _record_completed("integrity")
	if not bool(fixture.get("ok", false)):
		return str(fixture.get("error", "fixture failed"))
	var match_dir := str(fixture.get("match_dir", ""))
	var loader: Variant = _new_loader()
	if loader == null:
		_cleanup_root()
		return "NativeReplayDiagnosticLoader is missing"
	var report: Dictionary = loader.inspect_match_dir(match_dir)
	var manifest := _json(match_dir.path_join("native_replay_manifest.json"))
	var detail_lines := _read_lines(match_dir.path_join("detail.jsonl"))
	var first_event: Dictionary = JSON.parse_string(detail_lines[0]) if not detail_lines.is_empty() else {}
	var checks := run_checks([
		assert_eq(manifest.get("document_type"), "native_replay_manifest_v2"),
		assert_true(bool(manifest.get("complete", false))),
		assert_eq(int(manifest.get("record_count", -1)), 3),
		assert_true(FileAccess.file_exists(match_dir.path_join("detail.chain.jsonl"))),
		assert_true(bool(report.get("accepted", false)), str(report)),
		assert_eq(report.get("format"), "native_replay_v2"),
		assert_eq(report.get("integrity_status"), "verified"),
		assert_true(bool(report.get("complete", false))),
		assert_eq(int(report.get("last_valid_record_index", -1)), 2),
		assert_false(first_event.has("record_sha256"), "legacy detail event schema must remain unchanged"),
		assert_false(first_event.has("previous_record_sha256"), "integrity data belongs in the sidecar"),
		assert_eq((manifest.get("terminal", {}) as Dictionary).get("document_type"), "replay_terminal_v1"),
		assert_eq((manifest.get("terminal", {}) as Dictionary).get("winner_index"), 0),
	])
	_cleanup_root()
	return checks


func test_v2_loader_rejects_edit_delete_reorder_and_cross_match_substitution() -> String:
	_cleanup_root()
	var first := _record_completed("first")
	var second := _record_completed("second")
	var loader: Variant = _new_loader()
	if loader == null:
		_cleanup_root()
		return "NativeReplayDiagnosticLoader is missing"
	var first_dir := str(first.get("match_dir", ""))
	var second_dir := str(second.get("match_dir", ""))
	var detail_path := first_dir.path_join("detail.jsonl")
	var original := _read_lines(detail_path)
	var foreign := _read_lines(second_dir.path_join("detail.jsonl"))

	var edited := original.duplicate()
	var parsed: Dictionary = JSON.parse_string(edited[1])
	parsed["tampered"] = true
	edited[1] = JSON.stringify(parsed)
	_write_lines(detail_path, edited)
	var edit_report: Dictionary = loader.inspect_match_dir(first_dir)

	_write_lines(detail_path, original)
	var deleted := original.duplicate()
	deleted.remove_at(1)
	_write_lines(detail_path, deleted)
	var delete_report: Dictionary = loader.inspect_match_dir(first_dir)

	_write_lines(detail_path, original)
	var reordered := original.duplicate()
	var temp: String = reordered[0]
	reordered[0] = reordered[1]
	reordered[1] = temp
	_write_lines(detail_path, reordered)
	var reorder_report: Dictionary = loader.inspect_match_dir(first_dir)

	_write_lines(detail_path, original)
	var crossed := original.duplicate()
	crossed[1] = foreign[1]
	_write_lines(detail_path, crossed)
	var cross_report: Dictionary = loader.inspect_match_dir(first_dir)

	_write_lines(detail_path, original)
	var renamed_dir := TEST_ROOT.path_join("renamed_complete_match")
	_copy_flat_match_dir(first_dir, renamed_dir)
	var renamed_report: Dictionary = loader.inspect_match_dir(renamed_dir)

	var checks := run_checks([
		assert_false(bool(edit_report.get("accepted", true)), str(edit_report)),
		assert_false(bool(delete_report.get("accepted", true)), str(delete_report)),
		assert_false(bool(reorder_report.get("accepted", true)), str(reorder_report)),
		assert_false(bool(cross_report.get("accepted", true)), str(cross_report)),
		assert_false(bool(renamed_report.get("accepted", true)), str(renamed_report)),
		assert_true((edit_report.get("error_codes", []) as Array).has("detail_line_hash_mismatch")),
		assert_true((delete_report.get("error_codes", []) as Array).has("record_count_mismatch")),
		assert_true((reorder_report.get("error_codes", []) as Array).has("detail_line_hash_mismatch")),
		assert_true((cross_report.get("error_codes", []) as Array).has("detail_line_hash_mismatch")),
		assert_true((renamed_report.get("error_codes", []) as Array).has("native_match_directory_binding_invalid")),
	])
	_cleanup_root()
	return checks


func test_incomplete_v2_reports_verified_prefix_and_legacy_reports_capability_gaps() -> String:
	_cleanup_root()
	var recorder: Variant = _new_recorder()
	if recorder == null:
		return "BattleRecorder is missing"
	recorder.start_match({"mode": "ai", "player_labels": ["partial", "rules"]})
	recorder.record_event(_event("match_started"))
	recorder.record_event(_event("state_snapshot"))
	var partial_dir := str(recorder.get_match_dir())
	var detail_path := partial_dir.path_join("detail.jsonl")
	var detail_file := FileAccess.open(detail_path, FileAccess.READ_WRITE)
	detail_file.seek_end()
	detail_file.store_line(JSON.stringify(_event("unwitnessed_event")))
	detail_file.close()

	var legacy_dir := TEST_ROOT.path_join("legacy_match")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(legacy_dir))
	_write_lines(legacy_dir.path_join("detail.jsonl"), [JSON.stringify(_event("state_snapshot"))])
	var legacy_match := FileAccess.open(legacy_dir.path_join("match.json"), FileAccess.WRITE)
	legacy_match.store_string(JSON.stringify({"event_count": 1, "result": {"winner_index": 1}}))
	legacy_match.close()

	var loader: Variant = _new_loader()
	if loader == null:
		_cleanup_root()
		return "NativeReplayDiagnosticLoader is missing"
	var partial: Dictionary = loader.inspect_match_dir(partial_dir)
	var legacy: Dictionary = loader.inspect_match_dir(legacy_dir)
	var legacy_caps: Dictionary = legacy.get("capabilities", {})
	var checks := run_checks([
		assert_true(bool(partial.get("accepted", false)), str(partial)),
		assert_false(bool(partial.get("complete", true))),
		assert_eq(partial.get("integrity_status"), "partial"),
		assert_eq(int(partial.get("last_valid_record_index", -1)), 1),
		assert_true((partial.get("error_codes", []) as Array).has("recording_incomplete")),
		assert_true(bool(legacy.get("accepted", false)), str(legacy)),
		assert_eq(legacy.get("format"), "legacy_v1"),
		assert_eq((legacy_caps.get("native_event_integrity", {}) as Dictionary).get("state"), "unavailable"),
		assert_eq((legacy_caps.get("decision_windows", {}) as Dictionary).get("state"), "unavailable"),
		assert_true(not (legacy.get("capability_gaps", []) as Array).is_empty()),
	])
	_cleanup_root()
	return checks


func test_diagnostic_sidecar_failure_never_breaks_legacy_recording_or_game_result_export() -> String:
	_cleanup_root()
	var recorder: Variant = _new_recorder()
	if recorder == null:
		return "BattleRecorder is missing"
	recorder.start_match({"mode": "ai", "player_labels": ["human", "ai"]})
	var match_dir := str(recorder.get_match_dir())
	var blocked_chain := ProjectSettings.globalize_path(match_dir.path_join("detail.chain.jsonl"))
	DirAccess.make_dir_recursive_absolute(blocked_chain)
	recorder.record_event(_event("state_snapshot"))
	recorder.finalize_match({"winner_index": 0, "reason": "prize_out", "turn_number": 1})
	var manifest := _json(match_dir.path_join("native_replay_manifest.json"))
	var checks := run_checks([
		assert_true(FileAccess.file_exists(match_dir.path_join("detail.jsonl")), "legacy detail must still be written"),
		assert_true(FileAccess.file_exists(match_dir.path_join("summary.log")), "legacy summary must still be written"),
		assert_true(FileAccess.file_exists(match_dir.path_join("match.json")), "legacy result export must still finish"),
		assert_false(bool(manifest.get("complete", true))),
		assert_eq(manifest.get("diagnostic_error_code"), "native_chain_write_failed"),
	])
	_cleanup_root()
	return checks
