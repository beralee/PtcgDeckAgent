class_name NativeReplayDiagnosticLoader
extends RefCounted

const HashScript = preload("res://scripts/engine/ReplayDiagnosticHash.gd")

const MANIFEST_FILE := "native_replay_manifest.json"
const DETAIL_FILE := "detail.jsonl"
const CHAIN_FILE := "detail.chain.jsonl"
const DEVELOPER_MANIFEST_FILE := "developer_decision_trace_manifest.json"
const WITNESS_DOMAIN := "ptcgdap_native_replay_witness_canonical_json_v2"


func inspect_match_dir(match_dir: String) -> Dictionary:
	var normalized := match_dir.strip_edges()
	var global_dir := ProjectSettings.globalize_path(normalized)
	if normalized.is_empty() or not DirAccess.dir_exists_absolute(global_dir):
		return _rejected("match_dir_missing")
	var manifest_path := normalized.path_join(MANIFEST_FILE)
	if not FileAccess.file_exists(manifest_path):
		return _inspect_legacy(normalized)
	return _inspect_v2(normalized, HashScript.read_json(manifest_path))


func _inspect_legacy(match_dir: String) -> Dictionary:
	var detail_path := match_dir.path_join(DETAIL_FILE)
	var lines := HashScript.read_non_empty_lines(detail_path)
	var parse_error := false
	for line: String in lines:
		if not JSON.parse_string(line) is Dictionary:
			parse_error = true
			break
	if parse_error:
		return _rejected("legacy_detail_invalid")
	var capabilities := {
		"legacy_playback": _capability("available", "legacy_detail_jsonl"),
		"native_event_integrity": _capability("unavailable", "v2_manifest_absent"),
		"replay_state_frames": _capability("partial", "legacy_events_not_integrity_bound"),
		"structured_battle_events": _capability("partial", "legacy_events_not_integrity_bound"),
		"decision_windows": _capability("unavailable", "legacy_recording_has_no_decision_trace"),
		"host_acceptance": _capability("unavailable", "legacy_recording_has_no_decision_trace"),
		"terminal_status": _capability("partial", "legacy_result_only"),
	}
	return {
		"accepted": true,
		"format": "legacy_v1",
		"complete": FileAccess.file_exists(match_dir.path_join("match.json")),
		"integrity_status": "unavailable",
		"error_codes": [],
		"record_count": lines.size(),
		"last_valid_record_index": -1,
		"chain_root_sha256": null,
		"capabilities": capabilities,
		"capability_gaps": [
			"native_event_integrity",
			"decision_windows",
			"host_acceptance",
			"exact_terminal_status_and_rewards",
		],
		"missing_fields_inferred": false,
		"execution_authority_granted": false,
	}


func _inspect_v2(match_dir: String, manifest: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if manifest.get("document_type") != "native_replay_manifest_v2" \
		or int(manifest.get("schema_version", 0)) != 2:
		errors.append("native_manifest_invalid")
	var match_id := str(manifest.get("match_id", ""))
	if match_id.is_empty():
		errors.append("native_manifest_invalid")
	var directory_match_id := match_dir.trim_suffix("/").trim_suffix("\\").get_file()
	if not match_id.is_empty() and match_id != directory_match_id:
		errors.append("native_match_directory_binding_invalid")
	var detail_lines := HashScript.read_non_empty_lines(match_dir.path_join(DETAIL_FILE))
	var witness_lines := HashScript.read_non_empty_lines(match_dir.path_join(CHAIN_FILE))
	var complete := bool(manifest.get("complete", false))
	var expected_count := int(manifest.get("record_count", -1))
	if complete and (detail_lines.size() != expected_count or witness_lines.size() != expected_count):
		errors.append("record_count_mismatch")
	var prefix_count := mini(detail_lines.size(), witness_lines.size())
	var previous: Variant = null
	var last_valid := -1
	for index: int in prefix_count:
		var event_value: Variant = JSON.parse_string(detail_lines[index])
		var witness_value: Variant = JSON.parse_string(witness_lines[index])
		if not event_value is Dictionary or not witness_value is Dictionary:
			errors.append("record_json_invalid")
			break
		var event: Dictionary = event_value
		var witness: Dictionary = witness_value
		if (
			witness.get("document_type") != "native_replay_record_witness_v2"
			or int(witness.get("schema_version", 0)) != 2
			or str(witness.get("match_id", "")) != match_id
			or int(witness.get("record_index", -1)) != index
			or witness.get("previous_record_sha256") != previous
		):
			errors.append("native_witness_binding_invalid")
			break
		if witness.get("detail_line_sha256") != HashScript.sha256_text(detail_lines[index]):
			errors.append("detail_line_hash_mismatch")
			break
		if int(witness.get("event_index", -1)) != int(event.get("event_index", -2)):
			errors.append("native_witness_binding_invalid")
			break
		if str(event.get("match_id", "")) != match_id:
			errors.append("cross_match_event")
			break
		var body := witness.duplicate(true)
		var stored_sha: Variant = body.get("record_sha256")
		body.erase("record_sha256")
		var computed := HashScript.canonical_record_hash(WITNESS_DOMAIN, body)
		if stored_sha != computed or str(computed).is_empty():
			errors.append("native_witness_hash_mismatch")
			break
		previous = stored_sha
		last_valid = index
	if complete:
		if previous != manifest.get("chain_root_sha256"):
			errors.append("chain_root_mismatch")
		var exact_file_sha := HashScript.file_sha256(match_dir.path_join(DETAIL_FILE))
		if exact_file_sha != str(manifest.get("detail_file_sha256", "")):
			errors.append("detail_file_hash_mismatch")
	var integrity_status := "verified" if complete else "partial"
	if not errors.is_empty():
		integrity_status = "invalid"
	var result_errors := errors.duplicate()
	if not complete and errors.is_empty():
		result_errors.append("recording_incomplete")
	var capabilities: Dictionary = manifest.get("capabilities", {}).duplicate(true)
	var developer_report := _inspect_developer_trace(match_dir, manifest)
	if not bool(developer_report.get("accepted", false)) and bool(developer_report.get("present", false)):
		result_errors.append("developer_decision_trace_invalid")
		capabilities["decision_windows"] = _capability("partial", "developer_decision_trace_invalid")
		capabilities["host_acceptance"] = _capability("partial", "developer_decision_trace_invalid")
	return {
		"accepted": errors.is_empty() and bool(developer_report.get("accepted", true)),
		"format": "native_replay_v2",
		"complete": complete and errors.is_empty() and bool(developer_report.get("accepted", true)),
		"integrity_status": integrity_status,
		"error_codes": result_errors,
		"record_count": detail_lines.size(),
		"witness_count": witness_lines.size(),
		"last_valid_record_index": last_valid,
		"chain_root_sha256": previous,
		"capabilities": capabilities,
		"capability_gaps": _capability_gaps(capabilities),
		"developer_decision_trace": developer_report,
		"terminal": manifest.get("terminal", {}).duplicate(true),
		"missing_fields_inferred": false,
		"execution_authority_granted": false,
	}


func _inspect_developer_trace(match_dir: String, native_manifest: Dictionary) -> Dictionary:
	var path := match_dir.path_join(DEVELOPER_MANIFEST_FILE)
	if not FileAccess.file_exists(path):
		return {"accepted": true, "present": false, "state": "unavailable"}
	var link: Dictionary = native_manifest.get("developer_decision_trace", {})
	if str(link.get("path", "")) != DEVELOPER_MANIFEST_FILE:
		return {"accepted": false, "present": true, "error_code": "developer_trace_link_invalid"}
	if str(link.get("sha256", "")) != HashScript.file_sha256(path):
		return {"accepted": false, "present": true, "error_code": "developer_trace_manifest_hash_mismatch"}
	var script_path := "res://scripts/ui/battle/author_strategy/AuthorStrategyDeveloperDecisionTrace.gd"
	if not ResourceLoader.exists(script_path):
		return {"accepted": false, "present": true, "error_code": "developer_trace_verifier_missing"}
	var script: Variant = load(script_path)
	var report: Dictionary = script.verify_trace_dir(match_dir)
	report["present"] = true
	return report


func _capability_gaps(capabilities: Dictionary) -> Array[String]:
	var gaps: Array[String] = []
	for key: Variant in capabilities.keys():
		var capability: Variant = capabilities.get(key)
		if capability is Dictionary and str(capability.get("state", "unavailable")) != "available":
			gaps.append(str(key))
	gaps.sort()
	return gaps


func _capability(state: String, reason: String) -> Dictionary:
	return {"state": state, "reason": reason}


func _rejected(code: String) -> Dictionary:
	return {
		"accepted": false,
		"format": "unknown",
		"complete": false,
		"integrity_status": "invalid",
		"error_codes": [code],
		"capabilities": {},
		"capability_gaps": [],
		"missing_fields_inferred": false,
		"execution_authority_granted": false,
	}
