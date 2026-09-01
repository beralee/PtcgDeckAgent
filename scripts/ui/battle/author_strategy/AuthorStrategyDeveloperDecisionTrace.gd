class_name AuthorStrategyDeveloperDecisionTrace
extends RefCounted

const HashScript = preload("res://scripts/engine/ReplayDiagnosticHash.gd")

const TRACE_FILE := "developer_decisions.jsonl"
const MANIFEST_FILE := "developer_decision_trace_manifest.json"
const RECORD_DOMAIN := "ptcgdap_developer_decision_record_canonical_json_v1"
const FORBIDDEN_KEYS := {
	"deck_order": true,
	"opponent_hand": true,
	"opponent_hidden_hand": true,
	"opponent_deck": true,
	"opponent_prizes": true,
	"face_down_prizes": true,
	"private_rng": true,
	"rng_state": true,
	"search_begin_input": true,
	"object_ref": true,
	"callback": true,
	"binding": true,
	"ticket": true,
	"command": true,
}

var _match_dir := ""
var _native_match_id := ""
var _policy_match_id := ""
var _identity: Dictionary = {}
var _record_count := 0
var _decision_count := 0
var _owner_step_count := 0
var _chain_root: Variant = null
var _active := false
var _io_failed := false
var _incomplete := false
var _dropped_record_count := 0
var _last_error_code := ""
var _last_engine_commits := 0
var _last_engine_rejections := 0
var _last_native_event_count := -1
var _pending_lines: Array[String] = []
var _pending_byte_count := 0
var _batch_write_count := 0


func start(
	owner: Variant,
	match_dir: String,
	initial_native_event_count: int = -1,
) -> Dictionary:
	_reset()
	_match_dir = match_dir.strip_edges()
	_native_match_id = _match_dir.get_file()
	if (
		owner == null
		or _match_dir.is_empty()
		or _native_match_id.is_empty()
		or not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_match_dir))
		or not owner.has_method("public_replay_identity")
		or not owner.has_method("audit_snapshot")
		or not owner.has_method("drain_developer_decision_records")
		or not owner.has_method("enable_developer_decision_trace")
	):
		return _start_error("invalid_developer_trace_owner")
	var identity_value: Variant = owner.public_replay_identity()
	if not identity_value is Dictionary or not bool(identity_value.get("ok", false)):
		return _start_error("developer_trace_identity_unavailable")
	_identity = identity_value.duplicate(true)
	_policy_match_id = str(_identity.get("match_id", ""))
	_last_native_event_count = initial_native_event_count
	if _policy_match_id.is_empty() or not _is_public_safe(_identity):
		return _start_error("developer_trace_identity_invalid")
	var audit_value: Variant = owner.audit_snapshot()
	if audit_value is Dictionary:
		_last_engine_commits = int(audit_value.get("engine_commits", 0))
		_last_engine_rejections = int(audit_value.get("engine_rejections", 0))
	owner.enable_developer_decision_trace(true)
	_active = true
	if not _write_manifest(false, {}):
		_io_failed = true
		_last_error_code = "developer_trace_manifest_write_failed"
		return {"ok": false, "error_code": _last_error_code}
	return {
		"ok": true,
		"error_code": "",
		"path": _match_dir.path_join(TRACE_FILE),
		"manifest_path": _match_dir.path_join(MANIFEST_FILE),
	}


func record_owner_step(
	owner: Variant,
	status: String,
	native_event_count_after_step: int = -1,
) -> void:
	if not _active or _io_failed or owner == null:
		return
	var decision_ids: Array[String] = []
	var drained_value: Variant = owner.drain_developer_decision_records()
	if drained_value is Array:
		for record_value: Variant in drained_value:
			if not record_value is Dictionary:
				_drop("developer_record_invalid")
				continue
			var record: Dictionary = record_value
			if str(record.get("document_type", "")) != "decision_window_record_v1":
				_drop("developer_record_type_invalid")
				continue
			if _append_payload(record):
				_decision_count += 1
				decision_ids.append(str(record.get("decision_id", "")))
	var audit: Dictionary = {}
	var audit_value: Variant = owner.audit_snapshot()
	if audit_value is Dictionary:
		audit = audit_value
	var engine_commits := int(audit.get("engine_commits", _last_engine_commits))
	var engine_rejections := int(audit.get("engine_rejections", _last_engine_rejections))
	var step := {
		"document_type": "owner_step_witness_v1",
		"schema_version": 1,
		"policy_match_id": _policy_match_id,
		"step_index": _owner_step_count,
		"status": status,
		"decision_ids": decision_ids,
		"engine_commit_delta": maxi(0, engine_commits - _last_engine_commits),
		"engine_rejection_delta": maxi(0, engine_rejections - _last_engine_rejections),
		"native_event_count_before_step": _last_native_event_count,
		"native_event_count_after_step": native_event_count_after_step,
		"owner_counters": {
			"policy_calls": int(audit.get("policy_calls", 0)),
			"policy_successes": int(audit.get("policy_successes", 0)),
			"policy_errors": int(audit.get("policy_errors", 0)),
			"invalid_outputs": int(audit.get("invalid_outputs", 0)),
			"same_window_fallbacks": int(audit.get("same_window_fallbacks", 0)),
			"engine_commits": engine_commits,
			"engine_rejections": engine_rejections,
		},
	}
	if _append_payload(step):
		_owner_step_count += 1
	_last_engine_commits = engine_commits
	_last_engine_rejections = engine_rejections
	_last_native_event_count = native_event_count_after_step
	_flush_pending()


func finish(
	owner: Variant,
	winner_index: int,
	reason: String,
	turn_number: int,
) -> Dictionary:
	if not _active:
		return audit_snapshot()
	# Drain any decision emitted after the most recent scheduler witness without
	# inventing an engine commit for it.
	var remaining: Variant = owner.drain_developer_decision_records() if owner != null else []
	if remaining is Array:
		for record_value: Variant in remaining:
			if not record_value is Dictionary:
				_drop("developer_record_invalid")
				continue
			if _append_payload(record_value):
				_decision_count += 1
	var terminal := {
		"document_type": "replay_terminal_v1",
		"schema_version": 1,
		"winner_index": winner_index,
		"reason": reason,
		"turn_number": turn_number,
		"seat_statuses": [null, null],
		"rewards": [null, null],
		"faults": [null, null],
		"missing_fields_inferred": false,
	}
	_flush_pending()
	var complete := not _io_failed and not _incomplete
	if not _write_manifest(complete, terminal):
		_io_failed = true
		complete = false
		_last_error_code = "developer_trace_manifest_write_failed"
	_active = false
	var result := audit_snapshot()
	result["ok"] = not _io_failed
	result["complete"] = complete
	return result


func close_incomplete(reason: String) -> void:
	if not _active:
		return
	_incomplete = true
	_last_error_code = reason.strip_edges() if not reason.strip_edges().is_empty() else "developer_trace_closed_incomplete"
	_flush_pending()
	_write_manifest(false, {})
	_active = false


func audit_snapshot() -> Dictionary:
	return {
		"ok": not _io_failed,
		"complete": not _active and not _io_failed and not _incomplete,
		"error_code": _last_error_code,
		"native_match_id": _native_match_id,
		"policy_match_id": _policy_match_id,
		"path": _match_dir.path_join(TRACE_FILE) if not _match_dir.is_empty() else "",
		"manifest_path": _match_dir.path_join(MANIFEST_FILE) if not _match_dir.is_empty() else "",
		"record_count": _record_count,
		"decision_count": _decision_count,
		"owner_step_count": _owner_step_count,
		"chain_root_sha256": _chain_root,
		"dropped_record_count": _dropped_record_count,
		"pending_record_count": _pending_lines.size(),
		"pending_byte_count": _pending_byte_count,
		"batch_write_count": _batch_write_count,
		"write_mode": "owner_step_batch_v1",
		"private_replay_used": false,
		"visibility": "acting_policy_public_view_allow_list_v1",
		"execution_authority_granted": false,
	}


static func verify_trace_dir(match_dir: String) -> Dictionary:
	var manifest := HashScript.read_json(match_dir.path_join(MANIFEST_FILE))
	if (
		manifest.get("document_type") != "developer_decision_trace_manifest_v1"
		or int(manifest.get("schema_version", 0)) != 1
	):
		return _verify_error("developer_trace_manifest_invalid")
	var native_match_id := str(manifest.get("native_match_id", ""))
	if native_match_id.is_empty() or native_match_id != match_dir.get_file():
		return _verify_error("developer_trace_match_binding_invalid")
	var lines := HashScript.read_non_empty_lines(match_dir.path_join(TRACE_FILE))
	if lines.size() != int(manifest.get("record_count", -1)):
		return _verify_error("developer_trace_record_count_mismatch")
	var previous: Variant = null
	var decisions := 0
	var steps := 0
	for index: int in lines.size():
		var value: Variant = JSON.parse_string(lines[index])
		if not value is Dictionary:
			return _verify_error("developer_trace_record_invalid")
		var envelope: Dictionary = value
		if (
			envelope.get("document_type") != "developer_decision_trace_record_v1"
			or int(envelope.get("schema_version", 0)) != 1
			or str(envelope.get("native_match_id", "")) != native_match_id
			or int(envelope.get("record_index", -1)) != index
			or envelope.get("previous_record_sha256") != previous
			or not envelope.get("payload") is Dictionary
		):
			return _verify_error("developer_trace_record_binding_invalid")
		var payload: Dictionary = envelope.get("payload")
		if not _is_public_safe(payload):
			return _verify_error("developer_trace_privacy_invalid")
		var body := envelope.duplicate(true)
		var stored: Variant = body.get("record_sha256")
		body.erase("record_sha256")
		var computed := HashScript.canonical_record_hash(RECORD_DOMAIN, body)
		if stored != computed or str(computed).is_empty():
			return _verify_error("developer_trace_record_hash_mismatch")
		previous = stored
		match str(payload.get("document_type", "")):
			"decision_window_record_v1":
				decisions += 1
			"owner_step_witness_v1":
				steps += 1
			_:
				return _verify_error("developer_trace_payload_type_invalid")
	if previous != manifest.get("chain_root_sha256"):
		return _verify_error("developer_trace_chain_root_mismatch")
	if decisions != int(manifest.get("decision_count", -1)) \
		or steps != int(manifest.get("owner_step_count", -1)):
		return _verify_error("developer_trace_type_count_mismatch")
	return {
		"accepted": true,
		"complete": bool(manifest.get("complete", false)),
		"state": "available" if bool(manifest.get("complete", false)) else "partial",
		"error_code": "",
		"record_count": lines.size(),
		"decision_count": decisions,
		"owner_step_count": steps,
		"chain_root_sha256": previous,
		"execution_authority_granted": false,
	}


func _append_payload(payload: Dictionary) -> bool:
	if not _is_public_safe(payload):
		_drop("developer_trace_privacy_rejected")
		return false
	var envelope := {
		"document_type": "developer_decision_trace_record_v1",
		"schema_version": 1,
		"native_match_id": _native_match_id,
		"record_index": _record_count,
		"previous_record_sha256": _chain_root,
		"payload": payload.duplicate(true),
	}
	var digest := HashScript.canonical_record_hash(RECORD_DOMAIN, envelope)
	if digest.is_empty():
		_io_failed = true
		_last_error_code = "developer_trace_hash_failed"
		return false
	envelope["record_sha256"] = digest
	var line := JSON.stringify(envelope)
	_pending_lines.append(line)
	_pending_byte_count += line.to_utf8_buffer().size() + 1
	_record_count += 1
	_chain_root = digest
	return true


func _flush_pending() -> bool:
	if _pending_lines.is_empty():
		return not _io_failed
	if not HashScript.append_lines(_match_dir.path_join(TRACE_FILE), _pending_lines):
		_io_failed = true
		_last_error_code = "developer_trace_write_failed"
		return false
	_pending_lines.clear()
	_pending_byte_count = 0
	_batch_write_count += 1
	return true


func _write_manifest(complete: bool, terminal: Dictionary) -> bool:
	var manifest := {
		"document_type": "developer_decision_trace_manifest_v1",
		"schema_version": 1,
		"contract_id": "ptcgdap-native-replay-diagnostic-v2",
		"native_match_id": _native_match_id,
		"policy_match_id": _policy_match_id,
		"complete": complete,
		"trace_path": TRACE_FILE,
		"record_count": _record_count,
		"decision_count": _decision_count,
		"owner_step_count": _owner_step_count,
		"chain_root_sha256": _chain_root,
		"identity": _identity.duplicate(true),
		"visibility": "acting_policy_public_view_allow_list_v1",
		"private_replay_used": false,
		"execution_authority_granted": false,
		"dropped_record_count": _dropped_record_count,
		"batch_write_count": _batch_write_count,
		"write_mode": "owner_step_batch_v1",
		"diagnostic_error_code": _last_error_code,
		"terminal": terminal.duplicate(true),
	}
	return HashScript.write_json(_match_dir.path_join(MANIFEST_FILE), manifest)


static func _is_public_safe(value: Variant) -> bool:
	var stack: Array = [value]
	while not stack.is_empty():
		var current: Variant = stack.pop_back()
		if typeof(current) == TYPE_OBJECT or typeof(current) == TYPE_CALLABLE:
			return false
		if current is Dictionary:
			for key_value: Variant in current.keys():
				if typeof(key_value) != TYPE_STRING:
					return false
				var key := str(key_value).to_lower()
				if FORBIDDEN_KEYS.has(key) \
					or key.contains("opponent_hidden") \
					or key.contains("private_rng") \
					or key.contains("face_down_prize"):
					return false
				stack.append(current[key_value])
		elif current is Array:
			for child: Variant in current:
				stack.append(child)
	return true


func _drop(code: String) -> void:
	_dropped_record_count += 1
	_incomplete = true
	_last_error_code = code


func _start_error(code: String) -> Dictionary:
	_last_error_code = code
	return {"ok": false, "error_code": code}


static func _verify_error(code: String) -> Dictionary:
	return {
		"accepted": false,
		"complete": false,
		"state": "invalid",
		"error_code": code,
		"execution_authority_granted": false,
	}


func _reset() -> void:
	_match_dir = ""
	_native_match_id = ""
	_policy_match_id = ""
	_identity.clear()
	_record_count = 0
	_decision_count = 0
	_owner_step_count = 0
	_chain_root = null
	_active = false
	_io_failed = false
	_incomplete = false
	_dropped_record_count = 0
	_last_error_code = ""
	_last_engine_commits = 0
	_last_engine_rejections = 0
	_last_native_event_count = -1
	_pending_lines.clear()
	_pending_byte_count = 0
	_batch_write_count = 0
