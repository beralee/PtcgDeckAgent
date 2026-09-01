class_name GodotLogCursor
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")

const SCHEMA_VERSION := 1
const PROFILE_ID := "cabt_public_log_cursor_profile_v1"
const DEFAULT_ROOT := "res://contracts/ptcgdap"
const MAX_CONTRACT_BYTES := 2 * 1024 * 1024
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const EXPECTED_CURSOR_BUNDLE_SHA256 := "ED246F029531AA8F21956A64D70F557F1BBC90450A6F9109C5286261E290319D"
const EXPECTED_PROFILE_SHA256 := "20B9B9744B152D74D53BBE5EA3005110B36D86D0D9B13FBF09A7C27AB24C21A5"
const EXPECTED_FIREWALL_BUNDLE_SHA256 := "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"
const EXPECTED_P1_CONTRACT_SHA256 := "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
const EXPECTED_BUNDLE_ID := "ptcgdap-public-log-cursor-p2-wp4-v1"
const WITNESS_PREFIX_UTF8_HEX := "5054434744415000434142545F5055424C49435F4C4F475F534C4943455F563100"
const EXPECTED_ARTIFACTS := {
	"cabt_public_log_cursor_schema_v1": "contracts/ptcgdap/cabt_public_log_cursor.schema.json",
	"cabt_public_log_cursor_profile_v1": "contracts/ptcgdap/cabt_public_log_cursor_profile.json",
	"cabt_public_log_cursor_conformance_v1": "contracts/ptcgdap/cabt_public_log_cursor_conformance_vectors.json",
}
const ERROR_CODES := {
	"invalid_firewall_result": true,
	"firewall_result_not_accepted": true,
	"cursor_contract_error": true,
	"pending_selection_uncommitted": true,
	"invalid_slice_result": true,
	"slice_not_pending": true,
	"slice_cursor_mismatch": true,
	"slice_generation_stale": true,
	"slice_integrity_invalid": true,
	"source_result_replayed": true,
	"public_log_limit": true,
	"witness_error": true,
}


class CursorResult:
	extends RefCounted

	var _owner: Variant = null
	var _source_result: Variant = null
	var _generation := 0
	var _status := "rejected"
	var _ordinal: Variant = null
	var _previous_witness: Variant = null
	var _source_public_observation_hash: Variant = null
	var _logs: Variant = null
	var _witness_hash: Variant = null
	var _issues: Variant = []
	var _snapshot: Variant = {}

	var status: String:
		get:
			return _status

	var ready: bool:
		get:
			return _status == "slice_ready"

	var ordinal: Variant:
		get:
			return _ordinal

	var previous_witness: Variant:
		get:
			return _previous_witness

	var source_public_observation_hash: Variant:
		get:
			return _source_public_observation_hash

	var logs: Array:
		get:
			return _logs.duplicate(true) if _logs is Array else []

	var witness_hash: Variant:
		get:
			return _witness_hash

	var issues: Array:
		get:
			return _issues.duplicate(true) if _issues is Array else []

	var slice: Variant:
		get:
			return _copy(_slice_unchecked())

	func _init(owner_value: Variant = null, source_value: Variant = null, generation_value: int = 0, evaluation: Variant = null) -> void:
		_owner = owner_value
		_source_result = source_value
		_generation = generation_value
		if evaluation is Dictionary:
			_status = str(evaluation.get("status", "rejected"))
			var slice_value: Variant = evaluation.get("slice")
			if slice_value is Dictionary:
				_ordinal = slice_value.get("ordinal")
				_previous_witness = slice_value.get("previous_witness")
				_source_public_observation_hash = slice_value.get("source_public_observation_hash")
				_logs = _copy(slice_value.get("logs"))
				_witness_hash = slice_value.get("witness_hash")
			_issues = _copy(evaluation.get("issues", []))
		_snapshot = _serialize_unchecked()

	func _slice_unchecked() -> Variant:
		if _status != "slice_ready":
			return null
		return {
			"schema_version": SCHEMA_VERSION,
			"profile_id": PROFILE_ID,
			"ordinal": _ordinal,
			"previous_witness": _previous_witness,
			"source_public_observation_hash": _source_public_observation_hash,
			"logs": _copy(_logs),
			"witness_hash": _witness_hash,
		}

	func _serialize_unchecked() -> Dictionary:
		return {"status": _status, "slice": _slice_unchecked(), "issues": _copy(_issues)}

	func validate_integrity(current_cursor: Variant) -> bool:
		return current_cursor != null and current_cursor is RefCounted and current_cursor.has_method("_validate_result") and bool(current_cursor._validate_result(self))

	func to_public_dict() -> Dictionary:
		return (_snapshot as Dictionary).duplicate(true) if validate_integrity(_owner) and _snapshot is Dictionary else {}

	static func _copy(value: Variant) -> Variant:
		return value.duplicate(true) if value is Dictionary or value is Array else value


class CommitResult:
	extends RefCounted

	var _owner: Variant = null
	var _status := "rejected"
	var _committed_ordinal: Variant = null
	var _witness_hash: Variant = null
	var _issues: Variant = []
	var _snapshot: Variant = {}

	var status: String:
		get:
			return _status

	var committed_ordinal: Variant:
		get:
			return _committed_ordinal

	var witness_hash: Variant:
		get:
			return _witness_hash

	var issues: Array:
		get:
			return _issues.duplicate(true) if _issues is Array else []

	func _init(owner_value: Variant = null, evaluation: Variant = null) -> void:
		_owner = owner_value
		if evaluation is Dictionary:
			_status = str(evaluation.get("status", "rejected"))
			_committed_ordinal = evaluation.get("committed_ordinal")
			_witness_hash = evaluation.get("witness_hash")
			_issues = (evaluation.get("issues", []) as Array).duplicate(true) if evaluation.get("issues") is Array else []
		_snapshot = _serialize_unchecked()

	func _serialize_unchecked() -> Dictionary:
		return {"status": _status, "committed_ordinal": _committed_ordinal, "witness_hash": _witness_hash, "issues": _issues.duplicate(true) if _issues is Array else []}

	func validate_integrity() -> bool:
		if _owner == null or not _owner is RefCounted or not _snapshot is Dictionary or _snapshot != _serialize_unchecked():
			return false
		if _status == "committed":
			return typeof(_committed_ordinal) == TYPE_INT and int(_committed_ordinal) >= 0 and _is_sha_value(_witness_hash) and _issues == []
		return _status == "rejected" and _committed_ordinal == null and _witness_hash == null and _issues is Array and _issues.size() == 1 and ERROR_CODES.has(_issues[0].get("code"))

	func to_public_dict() -> Dictionary:
		return (_snapshot as Dictionary).duplicate(true) if validate_integrity() else {}

	static func _is_sha_value(value: Variant) -> bool:
		if typeof(value) != TYPE_STRING or str(value).length() != 64:
			return false
		for character: String in str(value):
			if not "0123456789ABCDEF".contains(character):
				return false
		return true


var _ok := false
var _error_code := "cursor_contract_error"
var _profile := {}
var _contract_root := ""
var _firewall: Variant = null
var _load_attempted := false
var _generation := 0
var _ordinal := 0
var _previous_witness: Variant = null
var _pending: Variant = null
var _committed_sources := []
var _state_snapshot: Variant = {}

var ok: bool:
	get:
		return _ok

var error_code: String:
	get:
		return _error_code

var contract_hash: String:
	get:
		return EXPECTED_CURSOR_BUNDLE_SHA256 if _ok else ""

var ordinal: int:
	get:
		return _ordinal

var previous_witness: Variant:
	get:
		return _previous_witness


static func load_default() -> Variant:
	return load_from_root(DEFAULT_ROOT)


static func load_from_root(root_path: Variant) -> Variant:
	var script: GDScript = load("res://scripts/ai/ptcgdap/public/GodotLogCursor.gd")
	var result: RefCounted = script.new()
	if typeof(root_path) != TYPE_STRING:
		result._load_attempted = true
		result._fail("cursor_contract_error")
		return result
	result._load(str(root_path))
	return result


func _load(root_path: String) -> void:
	if _load_attempted:
		return
	_load_attempted = true
	var root := root_path.trim_suffix("/")
	if root.is_empty():
		_fail("cursor_contract_error")
		return
	var bundle_bytes := _load_bytes("%s/cabt_public_log_cursor_bundle.json" % root)
	if bundle_bytes.is_empty() or FirewallScript._canonical_artifact_sha256(bundle_bytes) != EXPECTED_CURSOR_BUNDLE_SHA256:
		_fail("cursor_contract_error")
		return
	var parsed: Dictionary = FirewallScript._parse_contract_json_bytes(bundle_bytes)
	var bundle_value: Variant = parsed.get("value") if bool(parsed.get("ok", false)) else null
	if not bundle_value is Dictionary:
		_fail("cursor_contract_error")
		return
	var bundle: Dictionary = bundle_value
	if bundle.get("bundle_id") != EXPECTED_BUNDLE_ID or bundle.get("p1_contract_canonical_sha256") != EXPECTED_P1_CONTRACT_SHA256:
		_fail("cursor_contract_error")
		return
	if bundle.get("parent_firewall_bundle") != {"id": "ptcgdap-public-firewall-p2-wp3-v1", "canonical_sha256": EXPECTED_FIREWALL_BUNDLE_SHA256}:
		_fail("cursor_contract_error")
		return
	var parent_bytes := _load_bytes("%s/cabt_public_firewall_bundle.json" % root)
	if parent_bytes.is_empty() or FirewallScript._canonical_artifact_sha256(parent_bytes) != EXPECTED_FIREWALL_BUNDLE_SHA256:
		_fail("cursor_contract_error")
		return
	var artifacts_value: Variant = bundle.get("artifacts")
	if not artifacts_value is Array or artifacts_value.size() != EXPECTED_ARTIFACTS.size():
		_fail("cursor_contract_error")
		return
	var loaded := {}
	var paths := {}
	for entry_value: Variant in artifacts_value:
		if not entry_value is Dictionary or entry_value.size() != 3:
			_fail("cursor_contract_error")
			return
		var entry: Dictionary = entry_value
		if not entry.has("id") or not entry.has("path") or not entry.has("canonical_sha256"):
			_fail("cursor_contract_error")
			return
		var artifact_id: Variant = entry.get("id")
		var relative_path: Variant = entry.get("path")
		if typeof(artifact_id) != TYPE_STRING or typeof(relative_path) != TYPE_STRING or EXPECTED_ARTIFACTS.get(artifact_id) != relative_path or paths.has(relative_path):
			_fail("cursor_contract_error")
			return
		paths[relative_path] = true
		var bytes := _load_bytes("%s/%s" % [root, str(relative_path).get_file()])
		if bytes.is_empty() or FirewallScript._canonical_artifact_sha256(bytes) != entry.get("canonical_sha256"):
			_fail("cursor_contract_error")
			return
		var document: Dictionary = FirewallScript._parse_contract_json_bytes(bytes)
		if not bool(document.get("ok", false)):
			_fail("cursor_contract_error")
			return
		loaded[artifact_id] = document.get("value")
	var profile_value: Variant = loaded.get(PROFILE_ID)
	if not profile_value is Dictionary or FirewallScript._canonical_value_sha256(profile_value) != EXPECTED_PROFILE_SHA256:
		_fail("cursor_contract_error")
		return
	var firewall: Variant = FirewallScript.load_from_root(root)
	if firewall == null or not firewall is RefCounted or firewall.get_script() != FirewallScript or not bool(firewall.get("ok")) or not firewall.validate_integrity() or firewall.contract_hash != EXPECTED_FIREWALL_BUNDLE_SHA256:
		_fail("cursor_contract_error")
		return
	_profile = (profile_value as Dictionary).duplicate(true)
	_contract_root = root
	_firewall = firewall
	_ok = true
	_error_code = ""
	_refresh_state_snapshot()


func _fail(code: String) -> void:
	_ok = false
	_error_code = code if ERROR_CODES.has(code) else "cursor_contract_error"
	_profile = {}
	_contract_root = ""
	_firewall = null


func _state_unchecked() -> Dictionary:
	return {"generation": _generation, "ordinal": _ordinal, "previous_witness": _previous_witness, "pending": _pending, "committed_sources": _committed_sources.duplicate()}


func _refresh_state_snapshot() -> void:
	_state_snapshot = _state_unchecked()


func validate_integrity() -> bool:
	if not _ok or _error_code != "" or _contract_root.is_empty() or not _profile is Dictionary:
		return false
	if FirewallScript._canonical_value_sha256(_profile) != EXPECTED_PROFILE_SHA256 or _profile.get("profile_id") != PROFILE_ID:
		return false
	if typeof(_generation) != TYPE_INT or _generation < 0 or _generation > MAX_SAFE_INTEGER or typeof(_ordinal) != TYPE_INT or _ordinal < 0 or _ordinal > MAX_SAFE_INTEGER:
		return false
	if _previous_witness != null and not _is_sha(_previous_witness):
		return false
	if _pending != null and not _pending is CursorResult:
		return false
	if not _committed_sources is Array or not _state_snapshot is Dictionary or _state_snapshot != _state_unchecked():
		return false
	return _firewall != null and _firewall is RefCounted and _firewall.get_script() == FirewallScript and bool(_firewall.get("ok")) and _firewall.validate_integrity() and _firewall.contract_hash == EXPECTED_FIREWALL_BUNDLE_SHA256


func _source_snapshot(source_result: Variant) -> Variant:
	if source_result == null or not source_result is RefCounted or not source_result.has_method("to_public_dict") or not source_result.has_method("validate_integrity"):
		return null
	var owner: Variant = source_result.get("_owner")
	var bound_input: Variant = source_result.get("_bound_input")
	if owner == null or not owner is RefCounted or owner.get_script() != FirewallScript or not bool(owner.get("ok")) or not owner.validate_integrity():
		return null
	if not bool(source_result.validate_integrity(bound_input)):
		return null
	var value: Variant = source_result.to_public_dict()
	return value if value is Dictionary and not (value as Dictionary).is_empty() else null


func peek(source_result: Variant) -> Variant:
	if not validate_integrity():
		return _rejected("cursor_contract_error")
	var source_snapshot: Variant = _source_snapshot(source_result)
	if source_snapshot == null:
		return _rejected("invalid_firewall_result")
	if source_snapshot.get("status") != "accepted":
		return _rejected("firewall_result_not_accepted")
	if _pending != null:
		if _pending.get("_source_result") == source_result and _pending.validate_integrity(self):
			return _pending
		return _rejected("pending_selection_uncommitted")
	for committed: Variant in _committed_sources:
		if committed == source_result:
			return _rejected("source_result_replayed")
	var public_observation: Variant = source_snapshot.get("public_observation")
	var source_hash: Variant = source_snapshot.get("public_observation_hash")
	if not public_observation is Dictionary or not _is_sha(source_hash):
		return _rejected("invalid_firewall_result")
	var logs_value: Variant = public_observation.get("logs")
	if not logs_value is Array:
		return _rejected("invalid_firewall_result")
	var limits: Dictionary = _profile.get("limits", {})
	if logs_value.size() > int(limits.get("max_logs_per_slice", 0)):
		return _rejected("public_log_limit")
	var canonical_logs: Dictionary = CabtJsonTreeScript.canonicalize(logs_value, {"max_depth": limits.get("max_log_tree_depth"), "max_nodes": limits.get("max_log_tree_nodes")})
	if not bool(canonical_logs.get("ok", false)):
		return _rejected("public_log_limit")
	var payload := {"ordinal": _ordinal, "previous_witness": _previous_witness, "source_public_observation_hash": source_hash, "logs": (logs_value as Array).duplicate(true)}
	var witness: Dictionary = public_log_slice_witness(payload)
	if not bool(witness.get("ok", false)):
		return _rejected("witness_error")
	var slice_value := {"schema_version": SCHEMA_VERSION, "profile_id": PROFILE_ID, "ordinal": _ordinal, "previous_witness": _previous_witness, "source_public_observation_hash": source_hash, "logs": (logs_value as Array).duplicate(true), "witness_hash": witness.get("witness_hash")}
	var result := CursorResult.new(self, source_result, _generation, {"status": "slice_ready", "slice": slice_value, "issues": []})
	_pending = result
	_refresh_state_snapshot()
	return result


func _validate_result(result: Variant) -> bool:
	if not validate_integrity() or result == null or not result is CursorResult or result.get("_owner") != self:
		return false
	var snapshot: Variant = result.get("_snapshot")
	if not snapshot is Dictionary or snapshot != result._serialize_unchecked():
		return false
	if result.status == "rejected":
		return result.slice == null and result.issues.size() == 1 and ERROR_CODES.has(result.issues[0].get("code"))
	if result.status != "slice_ready" or result.get("_generation") != _generation or _pending != result or result.ordinal != _ordinal or result.previous_witness != _previous_witness or not result.issues.is_empty():
		return false
	var source_snapshot: Variant = _source_snapshot(result.get("_source_result"))
	if source_snapshot == null or source_snapshot.get("status") != "accepted":
		return false
	var observation: Variant = source_snapshot.get("public_observation")
	if not observation is Dictionary or source_snapshot.get("public_observation_hash") != result.source_public_observation_hash or observation.get("logs") != result.logs:
		return false
	var witness: Dictionary = public_log_slice_witness({"ordinal": result.ordinal, "previous_witness": result.previous_witness, "source_public_observation_hash": result.source_public_observation_hash, "logs": result.logs})
	return bool(witness.get("ok", false)) and witness.get("witness_hash") == result.witness_hash and result.slice == snapshot.get("slice")


func commit(result: Variant) -> Variant:
	if not validate_integrity():
		return _commit_rejected("cursor_contract_error")
	if result == null or not result is CursorResult:
		return _commit_rejected("invalid_slice_result")
	if result.get("_owner") != self:
		return _commit_rejected("slice_cursor_mismatch")
	if result.get("_generation") != _generation:
		return _commit_rejected("slice_generation_stale")
	if _pending == null or _pending != result:
		return _commit_rejected("slice_not_pending")
	if not result.validate_integrity(self):
		return _commit_rejected("slice_integrity_invalid")
	if _ordinal >= MAX_SAFE_INTEGER:
		return _commit_rejected("cursor_contract_error")
	var committed_ordinal: int = result.ordinal
	var witness: String = result.witness_hash
	var source_result: Variant = result.get("_source_result")
	_pending = null
	_ordinal += 1
	_previous_witness = witness
	_committed_sources.append(source_result)
	_refresh_state_snapshot()
	return CommitResult.new(self, {"status": "committed", "committed_ordinal": committed_ordinal, "witness_hash": witness, "issues": []})


func reset() -> bool:
	if not validate_integrity() or _generation >= MAX_SAFE_INTEGER:
		return false
	_generation += 1
	_ordinal = 0
	_previous_witness = null
	_pending = null
	_committed_sources = []
	_refresh_state_snapshot()
	return true


func _rejected(code: String) -> Variant:
	return CursorResult.new(self, null, _generation, {"status": "rejected", "slice": null, "issues": [_issue(code)]})


func _commit_rejected(code: String) -> Variant:
	return CommitResult.new(self, {"status": "rejected", "committed_ordinal": null, "witness_hash": null, "issues": [_issue(code)]})


static func public_log_slice_witness(payload: Variant) -> Dictionary:
	if not payload is Dictionary or payload.keys().size() != 4 or not payload.has("ordinal") or not payload.has("previous_witness") or not payload.has("source_public_observation_hash") or not payload.has("logs"):
		return {"ok": false, "error_code": "witness_error"}
	var ordinal_value: Variant = payload.get("ordinal")
	if typeof(ordinal_value) != TYPE_INT or int(ordinal_value) < 0 or int(ordinal_value) > MAX_SAFE_INTEGER:
		return {"ok": false, "error_code": "witness_error"}
	if payload.get("previous_witness") != null and not _is_sha(payload.get("previous_witness")):
		return {"ok": false, "error_code": "witness_error"}
	if not _is_sha(payload.get("source_public_observation_hash")) or not payload.get("logs") is Array:
		return {"ok": false, "error_code": "witness_error"}
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize(payload)
	if not bool(canonical.get("ok", false)):
		return {"ok": false, "error_code": "witness_error"}
	var prefix: PackedByteArray = WITNESS_PREFIX_UTF8_HEX.hex_decode()
	var canonical_bytes: PackedByteArray = canonical.get("bytes", PackedByteArray())
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(prefix)
	context.update(canonical_bytes)
	return {"ok": true, "error_code": "", "canonical_bytes": canonical_bytes, "canonical_json_utf8": str(canonical.get("text", "")), "witness_hash": context.finish().hex_encode().to_upper()}


static func _issue(code: String) -> Dictionary:
	return {"code": code if ERROR_CODES.has(code) else "cursor_contract_error", "severity": "error"}


static func _is_sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	for character: String in str(value):
		if not "0123456789ABCDEF".contains(character):
			return false
	return true


static func _load_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 1 or file.get_length() > MAX_CONTRACT_BYTES:
		return PackedByteArray()
	return file.get_buffer(file.get_length())
