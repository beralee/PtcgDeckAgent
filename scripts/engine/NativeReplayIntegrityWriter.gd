class_name NativeReplayIntegrityWriter
extends RefCounted

const HashScript = preload("res://scripts/engine/ReplayDiagnosticHash.gd")

const MANIFEST_FILE := "native_replay_manifest.json"
const CHAIN_FILE := "detail.chain.jsonl"
const DETAIL_FILE := "detail.jsonl"
const DEVELOPER_MANIFEST_FILE := "developer_decision_trace_manifest.json"
const WITNESS_DOMAIN := "ptcgdap_native_replay_witness_canonical_json_v2"
const DECISION_BATCH_WRITE_PROFILE := "decision_batch_v1"

var _match_dir := ""
var _match_id := ""
var _meta: Dictionary = {}
var _record_count := 0
var _chain_root: Variant = null
var _event_type_counts: Dictionary = {}
var _active := false
var _failed := false
var _last_error_code := ""
var _write_profile := "immediate_v1"
var _pending_lines: Array[String] = []
var _pending_byte_count := 0
var _batch_write_count := 0


func set_write_profile(profile_id: String) -> void:
	if _active:
		return
	_write_profile = DECISION_BATCH_WRITE_PROFILE \
		if profile_id == DECISION_BATCH_WRITE_PROFILE else "immediate_v1"


func start(match_dir: String, match_id: String, meta: Dictionary) -> Dictionary:
	_reset()
	_match_dir = match_dir.strip_edges()
	_match_id = match_id.strip_edges()
	_meta = meta.duplicate(true)
	if _match_dir.is_empty() or _match_id.is_empty():
		return _fail("invalid_native_replay_identity")
	_active = true
	if not _write_manifest(false, {}, false):
		return _fail("native_manifest_write_failed")
	return {"ok": true, "error_code": ""}


func update_context(meta: Dictionary) -> void:
	if not _active:
		return
	if meta == _meta:
		return
	_meta = meta.duplicate(true)
	if _write_profile == DECISION_BATCH_WRITE_PROFILE:
		return
	if not _failed and not _write_manifest(false, {}, false):
		_fail("native_manifest_write_failed")


func record_detail_line(exact_line: String, event: Dictionary) -> bool:
	if not _active or _failed:
		return false
	var line_sha := HashScript.sha256_text(exact_line)
	if line_sha.is_empty():
		_fail("detail_line_hash_failed")
		return false
	var witness := {
		"document_type": "native_replay_record_witness_v2",
		"schema_version": 2,
		"match_id": _match_id,
		"record_index": _record_count,
		"event_index": int(event.get("event_index", _record_count)),
		"detail_line_sha256": line_sha,
		"previous_record_sha256": _chain_root,
	}
	var record_sha := HashScript.canonical_record_hash(WITNESS_DOMAIN, witness)
	if record_sha.is_empty():
		_fail("native_witness_hash_failed")
		return false
	witness["record_sha256"] = record_sha
	if _write_profile == DECISION_BATCH_WRITE_PROFILE:
		var line := JSON.stringify(witness)
		_pending_lines.append(line)
		_pending_byte_count += line.to_utf8_buffer().size() + 1
	elif not HashScript.append_json_line(_match_dir.path_join(CHAIN_FILE), witness):
		_fail("native_chain_write_failed")
		return false
	_record_count += 1
	_chain_root = record_sha
	var event_type := str(event.get("event_type", "unknown"))
	_event_type_counts[event_type] = int(_event_type_counts.get(event_type, 0)) + 1
	return true


func flush_pending() -> bool:
	if _pending_lines.is_empty():
		return not _failed
	if not HashScript.append_lines(_match_dir.path_join(CHAIN_FILE), _pending_lines):
		_fail("native_chain_write_failed")
		return false
	_pending_lines.clear()
	_pending_byte_count = 0
	_batch_write_count += 1
	if not _write_manifest(false, {}, false):
		_fail("native_manifest_write_failed")
		return false
	return true


func finalize(meta: Dictionary, result: Dictionary, legacy_complete: bool) -> Dictionary:
	if not _active:
		return audit_snapshot()
	_meta = meta.duplicate(true)
	flush_pending()
	var complete := legacy_complete and not _failed
	if not _write_manifest(complete, result, true):
		_fail("native_manifest_write_failed")
		complete = false
	_active = false
	var audit := audit_snapshot()
	audit["complete"] = complete and not _failed
	return audit


func audit_snapshot() -> Dictionary:
	return {
		"ok": not _failed,
		"error_code": _last_error_code,
		"match_id": _match_id,
		"match_dir": _match_dir,
		"record_count": _record_count,
		"chain_root_sha256": _chain_root,
		"active": _active,
		"failed": _failed,
		"write_profile": _write_profile,
		"pending_record_count": _pending_lines.size(),
		"pending_byte_count": _pending_byte_count,
		"batch_write_count": _batch_write_count,
	}


func _write_manifest(complete: bool, result: Dictionary, finalized: bool) -> bool:
	var developer_link := _developer_trace_link()
	var terminal := _terminal(result) if finalized else {}
	var has_snapshots := int(_event_type_counts.get("state_snapshot", 0)) > 0
	var has_events := _record_count > 0
	var decision_state := str(developer_link.get("capability_state", "unavailable"))
	var capabilities := {
		"legacy_playback": _capability("available", "detail_jsonl_v1"),
		"native_event_integrity": _capability(
			"available" if complete else "partial",
			"detail_chain_v2"
		),
		"replay_state_frames": _capability(
			"available" if has_snapshots else "unavailable",
			"state_snapshot_events" if has_snapshots else "no_snapshot_observed"
		),
		"structured_battle_events": _capability(
			"available" if has_events else "unavailable",
			"detail_event_stream_v1" if has_events else "no_event_observed"
		),
		"decision_windows": _capability(decision_state, str(developer_link.get("reason", ""))),
		"host_acceptance": _capability(decision_state, str(developer_link.get("reason", ""))),
		"terminal_status": _terminal_capability(terminal, finalized),
	}
	var manifest := {
		"document_type": "native_replay_manifest_v2",
		"schema_version": 2,
		"contract_id": "ptcgdap-native-replay-diagnostic-v2",
		"match_id": _match_id,
		"complete": complete,
		"legacy_playback_semantics_unchanged": true,
		"detail_path": DETAIL_FILE,
		"chain_path": CHAIN_FILE,
		"record_count": _record_count,
		"chain_root_sha256": _chain_root,
		"detail_file_sha256": HashScript.file_sha256(_match_dir.path_join(DETAIL_FILE)) if finalized else null,
		"event_type_counts": _event_type_counts.duplicate(true),
		"runtime_identity": _runtime_identity(_meta),
		"capabilities": capabilities,
		"developer_decision_trace": developer_link,
		"terminal": terminal,
		"diagnostic_error_code": _last_error_code,
	}
	return HashScript.write_json(_match_dir.path_join(MANIFEST_FILE), manifest)


func _developer_trace_link() -> Dictionary:
	var path := _match_dir.path_join(DEVELOPER_MANIFEST_FILE)
	if not FileAccess.file_exists(path):
		var compact_recording := str(_meta.get("author_recording_profile_id", "")) == "player_compact_v1"
		return {
			"capability_state": "unavailable",
			"reason": "disabled_by_recording_profile" if compact_recording \
				else "developer_decision_trace_not_recorded",
			"path": null,
			"sha256": null,
		}
	var manifest := HashScript.read_json(path)
	return {
		"capability_state": "available" if bool(manifest.get("complete", false)) else "partial",
		"reason": "developer_decision_trace_v1",
		"path": DEVELOPER_MANIFEST_FILE,
		"sha256": HashScript.file_sha256(path),
		"record_count": int(manifest.get("record_count", 0)),
		"decision_count": int(manifest.get("decision_count", 0)),
		"owner_step_count": int(manifest.get("owner_step_count", 0)),
	}


func _terminal(result: Dictionary) -> Dictionary:
	var statuses: Variant = result.get("seat_statuses", [null, null])
	var rewards: Variant = result.get("rewards", [null, null])
	var faults: Variant = result.get("faults", [null, null])
	return {
		"document_type": "replay_terminal_v1",
		"schema_version": 1,
		"winner_index": int(result.get("winner_index", -1)),
		"reason": str(result.get("reason", "")),
		"turn_number": int(result.get("turn_number", result.get("turn_count", 0))),
		"seat_statuses": statuses.duplicate(true) if statuses is Array else [null, null],
		"rewards": rewards.duplicate(true) if rewards is Array else [null, null],
		"faults": faults.duplicate(true) if faults is Array else [null, null],
		"terminal_source": str(result.get("terminal_source", "unavailable")),
		"missing_fields_inferred": false,
	}


func _terminal_capability(terminal: Dictionary, finalized: bool) -> Dictionary:
	if not finalized:
		return _capability("unavailable", "match_not_finalized")
	var statuses: Array = terminal.get("seat_statuses", [])
	var rewards: Array = terminal.get("rewards", [])
	var exact := statuses.size() == 2 and rewards.size() == 2 \
		and statuses.all(func(value: Variant) -> bool: return value != null) \
		and rewards.all(func(value: Variant) -> bool: return value != null)
	return _capability(
		"available" if exact else "partial",
		"explicit_status_reward_fault" if exact else "winner_reason_only_status_reward_unavailable"
	)


func _runtime_identity(meta: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in [
		"mode", "player_types", "first_player_index", "view_player_index",
		"selected_deck_ids", "player_labels",
		"ai_version", "agent_version", "policy_hash", "policy_sha256",
		"card_catalog_sha256", "package_id", "package_version", "archive_sha256",
		"live_pacing_profile_id", "author_recording_profile_id",
	]:
		if meta.has(key):
			var value: Variant = meta.get(key)
			result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result


func _capability(state: String, reason: String) -> Dictionary:
	return {"state": state, "reason": reason}


func _fail(code: String) -> Dictionary:
	_failed = true
	_last_error_code = code
	return {"ok": false, "error_code": code}


func _reset() -> void:
	_match_dir = ""
	_match_id = ""
	_meta.clear()
	_record_count = 0
	_chain_root = null
	_event_type_counts.clear()
	_active = false
	_failed = false
	_last_error_code = ""
	_pending_lines.clear()
	_pending_byte_count = 0
	_batch_write_count = 0
