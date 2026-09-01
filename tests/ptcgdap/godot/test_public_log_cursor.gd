class_name TestPublicLogCursor
extends TestBase

const CursorScript = preload("res://scripts/ai/ptcgdap/public/GodotLogCursor.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtObservationParserScript = preload("res://scripts/ai/ptcgdap/cabt/CabtObservationParser.gd")
const EXPECTED_CURSOR_HASH := "ED246F029531AA8F21956A64D70F557F1BBC90450A6F9109C5286261E290319D"
const CURSOR_VECTOR_PATH := "res://contracts/ptcgdap/cabt_public_log_cursor_conformance_vectors.json"
const FIREWALL_VECTOR_PATH := "res://contracts/ptcgdap/cabt_public_firewall_conformance_vectors.json"
const TEMP_ROOT := "user://ptcgdap_public_log_cursor_trust"
const CURSOR_FILES := [
	"cabt_public_log_cursor.schema.json",
	"cabt_public_log_cursor_profile.json",
	"cabt_public_log_cursor_conformance_vectors.json",
	"cabt_public_log_cursor_bundle.json",
]


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	return true


func _read_contract(path: String) -> Variant:
	var parsed: Dictionary = FirewallScript._parse_contract_json_bytes(_read_bytes(path))
	return parsed.get("value") if bool(parsed.get("ok", false)) else null


func _cursor_vectors() -> Dictionary:
	var value: Variant = _read_contract(CURSOR_VECTOR_PATH)
	return value if value is Dictionary else {}


func _firewall_vectors() -> Dictionary:
	var value: Variant = _read_contract(FIREWALL_VECTOR_PATH)
	return value if value is Dictionary else {}


func _source(source_id: String) -> Array:
	var cursor_vectors := _cursor_vectors()
	var firewall_vectors := _firewall_vectors()
	var source: Dictionary = cursor_vectors.get("sources", {}).get(source_id, {})
	var raw: Dictionary = (firewall_vectors.get("base_observations", {}).get(source.get("firewall_base"), {}) as Dictionary).duplicate(true)
	raw["logs"] = (source.get("logs_override", []) as Array).duplicate(true)
	var contracts: Variant = CabtContractSetScript.load_default()
	var parsed: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(raw, contracts)
	var result: Variant = FirewallScript.load_default().project(parsed)
	return [parsed, result]


func _rejected_source() -> Array:
	var vectors := _firewall_vectors()
	var target := {}
	for case_value: Variant in vectors.get("cases", []):
		if case_value is Dictionary and case_value.get("id") == "opponent-hand-exposed":
			target = case_value
			break
	var raw: Dictionary = (vectors.get("base_observations", {}).get(target.get("base"), {}) as Dictionary).duplicate(true)
	for mutation_value: Variant in target.get("mutations", []):
		var mutation: Dictionary = mutation_value
		var path: Array = mutation.get("path", [])
		var parent: Variant = raw
		for index: int in range(path.size() - 1):
			parent = parent[path[index]]
		match str(mutation.get("op")):
			"set":
				parent[path[-1]] = mutation.get("value")
			"delete":
				parent.erase(path[-1])
			"append":
				parent[path[-1]].append(mutation.get("value"))
	var contracts: Variant = CabtContractSetScript.load_default()
	var parsed: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(raw, contracts)
	return [parsed, FirewallScript.load_default().project(parsed)]


func _issue_code(result: Variant) -> Variant:
	var issues: Array = result.issues if result != null else []
	return issues[0].get("code") if not issues.is_empty() else null


func test_default_cursor_loads_fixed_contract() -> String:
	var cursor: Variant = CursorScript.load_default()
	if cursor == null or not cursor.ok:
		return "cursor failed to load: %s" % ("null" if cursor == null else cursor.error_code)
	if cursor.contract_hash != EXPECTED_CURSOR_HASH or not cursor.validate_integrity():
		return "cursor trust anchor mismatch"
	return ""


func test_shared_hash_vectors_match_exact_canonical_bytes_and_digest() -> String:
	var vectors := _cursor_vectors()
	var cases: Array = vectors.get("hash_vectors", [])
	if cases.size() != 4:
		return "shared hash-vector count differs"
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		var actual: Dictionary = CursorScript.public_log_slice_witness(case.get("payload"))
		if not bool(actual.get("ok", false)):
			return "%s witness rejected" % case.get("id")
		if actual.get("canonical_json_utf8") != case.get("canonical_json_utf8"):
			return "%s canonical bytes differ" % case.get("id")
		if actual.get("witness_hash") != case.get("witness_hash"):
			return "%s digest differs" % case.get("id")
	return ""


func test_ordered_logs_chain_and_copy_only_outputs_match_shared_vectors() -> String:
	var vectors := _cursor_vectors()
	var source_ids := ["initial_empty", "turn_draw_ordered", "regular_empty", "move_attack_ordered"]
	var cursor: Variant = CursorScript.load_default()
	var previous: Variant = null
	for ordinal: int in range(source_ids.size()):
		var pair := _source(source_ids[ordinal])
		var parsed: Variant = pair[0]
		var source_result: Variant = pair[1]
		if not source_result.validate_integrity(parsed):
			return "%s firewall source integrity failed" % source_ids[ordinal]
		var result: Variant = cursor.peek(source_result)
		if result.status != "slice_ready" or not result.validate_integrity(cursor):
			return "%s cursor result rejected: %s" % [source_ids[ordinal], JSON.stringify(result.issues)]
		if result.ordinal != ordinal or result.previous_witness != previous:
			return "%s cursor chain differs" % source_ids[ordinal]
		if result.logs != vectors.get("sources", {}).get(source_ids[ordinal], {}).get("logs"):
			return "%s ordered logs differ" % source_ids[ordinal]
		if result.source_public_observation_hash != source_result.public_observation_hash:
			return "%s source hash differs" % source_ids[ordinal]
		if result.witness_hash != vectors.get("hash_vectors", [])[ordinal].get("witness_hash"):
			return "%s witness differs" % source_ids[ordinal]
		var returned: Array = result.logs
		returned.append({"type": 0, "playerIndex": 1})
		if result.logs == returned:
			return "%s logs getter leaked mutable state" % source_ids[ordinal]
		var serialized := JSON.stringify(result.to_public_dict())
		for forbidden: String in ["session_id", "search_begin_input", "raw_private_hash", "token_free_callback_hash"]:
			if serialized.contains(forbidden):
				return "%s serialized %s" % [source_ids[ordinal], forbidden]
		var commit: Variant = cursor.commit(result)
		if commit.status != "committed" or not commit.validate_integrity() or commit.committed_ordinal != ordinal or commit.witness_hash != result.witness_hash:
			return "%s commit differs" % source_ids[ordinal]
		previous = result.witness_hash
		if result.validate_integrity(cursor):
			return "%s committed result retained authority" % source_ids[ordinal]
	return ""


func test_pending_commit_cross_cursor_replay_and_reset_paths_fail_closed() -> String:
	var cursor: Variant = CursorScript.load_default()
	var pair := _source("turn_draw_ordered")
	var source_result: Variant = pair[1]
	var result: Variant = cursor.peek(source_result)
	if cursor.peek(source_result) != result:
		return "same pending source was not idempotent"
	var different: Variant = _source("move_attack_ordered")[1]
	if _issue_code(cursor.peek(different)) != "pending_selection_uncommitted":
		return "different pending source did not fail closed"
	if _issue_code(cursor.commit(result.to_public_dict())) != "invalid_slice_result":
		return "copied DTO authorized commit"
	if _issue_code(CursorScript.load_default().commit(result)) != "slice_cursor_mismatch":
		return "cross-cursor commit did not fail closed"
	if cursor.commit(result).status != "committed":
		return "valid pending result did not commit"
	if _issue_code(cursor.commit(result)) != "slice_not_pending":
		return "duplicate commit did not fail closed"
	if _issue_code(cursor.peek(source_result)) != "source_result_replayed":
		return "source replay did not fail closed"
	var new_result: Variant = cursor.peek(_source("turn_draw_ordered")[1])
	if not cursor.reset():
		return "cursor reset failed"
	if _issue_code(cursor.commit(new_result)) != "slice_generation_stale":
		return "reset did not revoke old slice"
	if cursor.peek(_source("turn_draw_ordered")[1]).ordinal != 0:
		return "reset did not restore initial ordinal"
	cursor.reset()
	return ""


func test_rejected_mutated_and_copied_firewall_results_do_not_echo() -> String:
	var rejected_pair := _rejected_source()
	var rejected_source: Variant = rejected_pair[1]
	var cursor: Variant = CursorScript.load_default()
	var rejected: Variant = cursor.peek(rejected_source)
	if _issue_code(rejected) != "firewall_result_not_accepted":
		return "rejected firewall result did not fail closed"
	var rejected_text := JSON.stringify(rejected.to_public_dict())
	if rejected_text.contains("PRIVATE") or rejected_text.contains("search_begin_input"):
		return "rejected result echoed private state"
	if _issue_code(cursor.peek(rejected_source.to_public_dict())) != "invalid_firewall_result":
		return "copied firewall DTO authorized a slice"
	var accepted: Variant = _source("regular_empty")[1]
	accepted.set("_public_observation_hash", "0".repeat(64))
	if _issue_code(cursor.peek(accepted)) != "invalid_firewall_result":
		return "mutated firewall owner retained authority"
	return ""


func test_result_mutation_and_log_limit_fail_closed_without_pending_authority() -> String:
	var cursor: Variant = CursorScript.load_default()
	var source_result: Variant = _source("regular_empty")[1]
	var result: Variant = cursor.peek(source_result)
	result.set("_witness_hash", "F".repeat(64))
	if result.validate_integrity(cursor) or not result.to_public_dict().is_empty():
		return "mutated result serialized authority"
	if _issue_code(cursor.commit(result)) != "slice_integrity_invalid":
		return "mutated result did not fail closed"
	cursor.reset()

	var vectors := _firewall_vectors()
	var raw: Dictionary = (vectors.get("base_observations", {}).get("regular", {}) as Dictionary).duplicate(true)
	var logs := []
	for index: int in range(4097):
		logs.append({"type": 2, "playerIndex": index % 2})
	raw["logs"] = logs
	var contracts: Variant = CabtContractSetScript.load_default()
	var parsed: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(raw, contracts)
	var large_source: Variant = FirewallScript.load_default().project(parsed)
	var fresh: Variant = CursorScript.load_default()
	if not large_source.accepted or _issue_code(fresh.peek(large_source)) != "public_log_limit":
		return "oversized public log did not fail closed"
	if fresh.peek(_source("regular_empty")[1]).status != "slice_ready":
		return "rejected oversized log created pending authority"
	fresh.reset()
	return ""


func _cleanup_temp() -> void:
	for file_name: String in CURSOR_FILES:
		var path := "%s/%s" % [TEMP_ROOT, file_name]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TEMP_ROOT)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_ROOT))


func test_disk_missing_drift_and_self_consistent_rehash_reject() -> String:
	_cleanup_temp()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT)) != OK:
		return "failed to create temporary contract root"
	for file_name: String in CURSOR_FILES:
		if not _write_bytes("%s/%s" % [TEMP_ROOT, file_name], _read_bytes("res://contracts/ptcgdap/%s" % file_name)):
			_cleanup_temp()
			return "failed to copy %s" % file_name
	var profile_path := "%s/cabt_public_log_cursor_profile.json" % TEMP_ROOT
	var profile: Dictionary = _read_contract(profile_path)
	profile["cursor_lifecycle"]["replay"] = "forged replay authority"
	_write_bytes(profile_path, JSON.stringify(profile).to_utf8_buffer())
	var profile_hash: String = str(FirewallScript._canonical_artifact_sha256(_read_bytes(profile_path)))
	var bundle_path := "%s/cabt_public_log_cursor_bundle.json" % TEMP_ROOT
	var bundle: Dictionary = _read_contract(bundle_path)
	for entry_value: Variant in bundle.get("artifacts", []):
		if entry_value is Dictionary and entry_value.get("id") == "cabt_public_log_cursor_profile_v1":
			entry_value["canonical_sha256"] = profile_hash
	_write_bytes(bundle_path, JSON.stringify(bundle).to_utf8_buffer())
	var forged: Variant = CursorScript.load_from_root(TEMP_ROOT)
	if forged.ok or forged.error_code != "cursor_contract_error":
		_cleanup_temp()
		return "self-consistent forged bundle passed fixed anchor"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))
	var missing: Variant = CursorScript.load_from_root(TEMP_ROOT)
	_cleanup_temp()
	if missing.ok or missing.error_code != "cursor_contract_error":
		return "missing contract file did not fail closed"
	return ""
