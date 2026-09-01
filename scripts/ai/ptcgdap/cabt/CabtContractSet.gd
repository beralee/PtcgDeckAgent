class_name CabtContractSet
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const DEFAULT_ROOT := "res://contracts/ptcgdap"
const MAX_CONTRACT_BYTES := 2 * 1024 * 1024
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const CONTRACT_PATH_PREFIX := "contracts/ptcgdap/"
const EXPECTED_CONTRACT_ID := "ptcgdap-cabt-contract-p1-wp3-v1"
const EXPECTED_CONTRACT_BUNDLE_SHA256 := "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
const REQUIRED_ARTIFACT_PATHS := {
	"raw_envelope_schema": "contracts/ptcgdap/raw_cabt_envelope.schema.json",
	"tree_hash_profile": "contracts/ptcgdap/cabt_tree_hash_profile.json",
	"enum_snapshot": "contracts/ptcgdap/cabt_enum_snapshot.json",
	"option_sparse_shapes": "contracts/ptcgdap/cabt_option_sparse_shapes.json",
	"typed_view_profile": "contracts/ptcgdap/cabt_typed_view_profile.json",
	"tree_hash_conformance_vectors": "contracts/ptcgdap/cabt_tree_hash_conformance_vectors.json",
	"selection_window_schema": "contracts/ptcgdap/cabt_selection_window.schema.json",
	"selection_profile": "contracts/ptcgdap/cabt_selection_profile.json",
	"selection_conformance_vectors": "contracts/ptcgdap/cabt_selection_conformance_vectors.json",
}
const PARSED_ARTIFACT_IDS := {
	"typed_view_profile": true,
	"enum_snapshot": true,
	"option_sparse_shapes": true,
	"selection_profile": true,
}
const EXPECTED_RUNTIME_DOCUMENT_SHA256 := {
	"typed_view_profile": "8BF305D68247111DB7C94908012AEF57636566E8246474FF0395EA25FDD89548",
	"enum_snapshot": "67C13F67B533C1E3F4AC91A65608487FC4A41DE291FD8F2CF0EFCD475E4628A0",
	"option_sparse_shapes": "F9D85B3D2E1EA0CFF7B023F0C366EFE1FB8DA00A2B85D40F26A6B7DFBF4B062D",
	"selection_profile": "8F2133706BC33FC0125109E47835D6A06A6CC21FD5E4B324AD284FAF1D03F460",
}
static var _TRUSTED_INSTANCE_REGISTRY: Dictionary = {}

var _ok := false
var _error_code := "contract_not_loaded"
var _source_lock_id := ""
var _source_contract_hash := ""
var _typed_profile := {}
var _enum_snapshot := {}
var _option_shapes := {}
var _selection_profile := {}
var _load_attempted := false

var ok: bool:
	get:
		return _ok

var error_code: String:
	get:
		return _error_code

var source_lock_id: String:
	get:
		return _source_lock_id

var source_contract_hash: String:
	get:
		return _source_contract_hash

var typed_profile: Dictionary:
	get:
		return _typed_profile.duplicate(true)

var enum_snapshot: Dictionary:
	get:
		return _enum_snapshot.duplicate(true)

var option_shapes: Dictionary:
	get:
		return _option_shapes.duplicate(true)

var selection_profile: Dictionary:
	get:
		return _selection_profile.duplicate(true)


static func load_default() -> Variant:
	return load_from_root(DEFAULT_ROOT)


static func load_from_root(root_path: String) -> Variant:
	var script: GDScript = load("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
	var result: RefCounted = script.new()
	result._load(root_path)
	return result


func _load(root_path: String) -> void:
	if _load_attempted:
		return
	_load_attempted = true
	var normalized_root := root_path.trim_suffix("/")
	if normalized_root.is_empty():
		_fail("invalid_contract_root")
		return

	var bundle_result := _load_json("%s/cabt_contract_bundle.json" % normalized_root)
	if not bool(bundle_result.get("ok", false)):
		_fail(str(bundle_result.get("error_code", "contract_read_error")))
		return

	var bundle_value: Variant = bundle_result.get("value")
	if not bundle_value is Dictionary:
		_fail("invalid_contract_document")
		return
	var bundle: Dictionary = bundle_value
	if (
		bundle.get("schema_version") != 2
		or bundle.get("contract_id") != EXPECTED_CONTRACT_ID
		or bundle.get("digest_mode") != "canonical_json_v1"
		or bundle.get("artifact_set_policy") != "exact_ids_and_paths_no_duplicates"
	):
		_fail("unsupported_contract_bundle")
		return
	var lock_value: Variant = bundle.get("source_lock_id")
	if typeof(lock_value) != TYPE_STRING or str(lock_value).is_empty():
		_fail("missing_source_lock_id")
		return
	var lock_id := str(lock_value)

	var artifact_entries: Variant = bundle.get("artifacts")
	if not artifact_entries is Array or (artifact_entries as Array).size() != REQUIRED_ARTIFACT_PATHS.size():
		_fail("invalid_contract_artifacts")
		return
	var seen_ids := {}
	var seen_paths := {}
	var verified_documents := {}
	for entry_value: Variant in artifact_entries:
		if not entry_value is Dictionary:
			_fail("invalid_contract_artifact")
			return
		var entry: Dictionary = entry_value
		var id_value: Variant = entry.get("id")
		var relative_value: Variant = entry.get("path")
		var expected_value: Variant = entry.get("canonical_sha256")
		if (
			typeof(id_value) != TYPE_STRING
			or typeof(relative_value) != TYPE_STRING
			or typeof(expected_value) != TYPE_STRING
		):
			_fail("invalid_contract_artifact")
			return
		var artifact_id := str(id_value)
		var relative := str(relative_value)
		if (
			seen_ids.has(artifact_id)
			or seen_paths.has(relative)
			or REQUIRED_ARTIFACT_PATHS.get(artifact_id) != relative
			or not _is_safe_contract_path(relative)
			or not _is_upper_sha256(str(expected_value))
		):
			_fail("invalid_contract_artifact")
			return
		seen_ids[artifact_id] = true
		seen_paths[relative] = true
		var suffix := relative.substr(CONTRACT_PATH_PREFIX.length())
		var artifact_result := _load_bytes("%s/%s" % [normalized_root, suffix])
		if not bool(artifact_result.get("ok", false)):
			_fail(str(artifact_result.get("error_code", "contract_read_error")))
			return
		var digest_result := _canonical_json_bytes_sha256(
			artifact_result.get("bytes", PackedByteArray())
		)
		if not bool(digest_result.get("ok", false)):
			_fail(str(digest_result.get("error_code", "invalid_contract_artifact")))
			return
		if str(digest_result.get("sha256", "")) != str(expected_value):
			_fail("contract_artifact_hash_mismatch")
			return
		if PARSED_ARTIFACT_IDS.has(artifact_id):
			var parsed_result := _parse_json_bytes(
				artifact_result.get("bytes", PackedByteArray())
			)
			if not bool(parsed_result.get("ok", false)):
				_fail(str(parsed_result.get("error_code", "contract_json_invalid")))
				return
			var parsed_value: Variant = parsed_result.get("value")
			if not parsed_value is Dictionary:
				_fail("invalid_contract_document")
				return
			verified_documents[artifact_id] = (parsed_value as Dictionary).duplicate(true)
	if seen_ids.size() != REQUIRED_ARTIFACT_PATHS.size():
		_fail("invalid_contract_artifacts")
		return
	if verified_documents.size() != PARSED_ARTIFACT_IDS.size():
		_fail("invalid_contract_artifacts")
		return
	var profile: Dictionary = verified_documents.get("typed_view_profile", {})
	var enum_snapshot_value: Dictionary = verified_documents.get("enum_snapshot", {})
	var option_shapes: Dictionary = verified_documents.get("option_sparse_shapes", {})
	var selection_profile: Dictionary = verified_documents.get("selection_profile", {})
	if (
		profile.get("source_lock_id") != lock_id
		or enum_snapshot_value.get("source_lock_id") != lock_id
		or option_shapes.get("source_lock_id") != lock_id
		or selection_profile.get("source_lock_id") != lock_id
	):
		_fail("source_lock_mismatch")
		return

	var bundle_digest := _canonical_json_bytes_sha256(
		bundle_result.get("bytes", PackedByteArray())
	)
	if not bool(bundle_digest.get("ok", false)):
		_fail(str(bundle_digest.get("error_code", "invalid_contract_bundle")))
		return
	if str(bundle_digest.get("sha256", "")) != EXPECTED_CONTRACT_BUNDLE_SHA256:
		_fail("contract_bundle_trust_anchor_mismatch")
		return

	_source_lock_id = lock_id
	_source_contract_hash = str(bundle_digest.get("sha256", ""))
	_typed_profile = profile.duplicate(true)
	_enum_snapshot = enum_snapshot_value.duplicate(true)
	_option_shapes = option_shapes.duplicate(true)
	_selection_profile = selection_profile.duplicate(true)
	_error_code = ""
	_ok = true
	_register_trusted_instance(self)


func validate_integrity() -> bool:
	var entry := _trusted_instance_entry(self)
	if (
		not _ok
		or entry.is_empty()
		or entry.get("source_lock_id") != _source_lock_id
		or entry.get("source_contract_hash") != _source_contract_hash
		or _source_contract_hash != EXPECTED_CONTRACT_BUNDLE_SHA256
		or _source_lock_id != "ptcgdap-source-lock-2026-08-09-p1wp1"
		or entry.get("typed_view_profile") != _typed_profile
		or entry.get("enum_snapshot") != _enum_snapshot
		or entry.get("option_sparse_shapes") != _option_shapes
		or entry.get("selection_profile") != _selection_profile
	):
		return false
	return true


static func _register_trusted_instance(value: Variant) -> void:
	_TRUSTED_INSTANCE_REGISTRY[value.get_instance_id()] = {
		"weak": weakref(value),
		"source_lock_id": value.get("_source_lock_id"),
		"source_contract_hash": value.get("_source_contract_hash"),
		"typed_view_profile": value.get("_typed_profile").duplicate(true),
		"enum_snapshot": value.get("_enum_snapshot").duplicate(true),
		"option_sparse_shapes": value.get("_option_shapes").duplicate(true),
		"selection_profile": value.get("_selection_profile").duplicate(true),
	}
	if _TRUSTED_INSTANCE_REGISTRY.size() < 128:
		return
	for instance_id: Variant in _TRUSTED_INSTANCE_REGISTRY.keys():
		var entry_value: Variant = _TRUSTED_INSTANCE_REGISTRY.get(instance_id)
		var reference: Variant = entry_value.get("weak") if entry_value is Dictionary else null
		if typeof(reference) != TYPE_OBJECT or reference == null or reference.get_ref() == null:
			_TRUSTED_INSTANCE_REGISTRY.erase(instance_id)


static func _trusted_instance_entry(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_OBJECT or value == null:
		return {}
	var entry_value: Variant = _TRUSTED_INSTANCE_REGISTRY.get(value.get_instance_id())
	if not entry_value is Dictionary:
		return {}
	var reference: Variant = entry_value.get("weak")
	if typeof(reference) != TYPE_OBJECT or reference == null or reference.get_ref() != value:
		return {}
	return entry_value


func _fail(code: String) -> void:
	_ok = false
	_error_code = code
	_source_lock_id = ""
	_source_contract_hash = ""
	_typed_profile = {}
	_enum_snapshot = {}
	_option_shapes = {}
	_selection_profile = {}


static func _load_json(path: String) -> Dictionary:
	var bytes_result := _load_bytes(path)
	if not bool(bytes_result.get("ok", false)):
		return bytes_result
	var source_bytes: PackedByteArray = bytes_result.get("bytes", PackedByteArray())
	var parsed_result := _parse_json_bytes(source_bytes)
	if not bool(parsed_result.get("ok", false)):
		return parsed_result
	parsed_result["bytes"] = source_bytes
	return parsed_result


static func _parse_json_bytes(source_bytes: PackedByteArray) -> Dictionary:
	var strict_result: Dictionary = CabtJsonTreeScript.canonicalize_json_bytes(
		source_bytes,
		{
			"max_input_bytes": MAX_CONTRACT_BYTES,
			"max_output_bytes": MAX_CONTRACT_BYTES,
		}
	)
	if not bool(strict_result.get("ok", false)):
		return {"ok": false, "error_code": "contract_json_invalid"}
	var source_text := source_bytes.get_string_from_utf8()
	if source_text.to_utf8_buffer() != source_bytes:
		return {"ok": false, "error_code": "contract_json_invalid"}
	var parser := JSON.new()
	if parser.parse(source_text) != OK:
		return {"ok": false, "error_code": "contract_json_invalid"}
	var restore_state := {"ok": true}
	var restored: Variant = _restore_contract_integer_tokens(parser.data, restore_state)
	if not bool(restore_state.get("ok", false)):
		return {"ok": false, "error_code": "contract_json_invalid"}
	return {"ok": true, "error_code": "", "value": restored}


static func _restore_contract_integer_tokens(value: Variant, state: Dictionary) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number := float(value)
			if (
				not is_finite(number)
				or number != floorf(number)
				or number < -float(MAX_SAFE_INTEGER)
				or number > float(MAX_SAFE_INTEGER)
			):
				state["ok"] = false
				return null
			return int(number)
		TYPE_ARRAY:
			var restored_array := []
			for child: Variant in value as Array:
				restored_array.append(_restore_contract_integer_tokens(child, state))
				if not bool(state.get("ok", false)):
					return null
			return restored_array
		TYPE_DICTIONARY:
			var restored_object := {}
			for key: Variant in (value as Dictionary).keys():
				if typeof(key) != TYPE_STRING:
					state["ok"] = false
					return null
				restored_object[key] = _restore_contract_integer_tokens(
					(value as Dictionary)[key],
					state,
				)
				if not bool(state.get("ok", false)):
					return null
			return restored_object
		_:
			return value


static func _load_bytes(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error_code": "contract_file_missing"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error_code": "contract_read_error"}
	var length := file.get_length()
	if length < 1 or length > MAX_CONTRACT_BYTES:
		return {"ok": false, "error_code": "contract_size_invalid"}
	return {"ok": true, "error_code": "", "bytes": file.get_buffer(length)}


static func _is_safe_contract_path(relative: String) -> bool:
	if not relative.begins_with(CONTRACT_PATH_PREFIX):
		return false
	if relative.contains("\\") or relative.contains(":"):
		return false
	var suffix := relative.substr(CONTRACT_PATH_PREFIX.length())
	if suffix.is_empty() or suffix.begins_with("/"):
		return false
	for segment: String in suffix.split("/"):
		if segment.is_empty() or segment == "." or segment == "..":
			return false
	return true


static func _is_upper_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index: int in value.length():
		var character := value.substr(index, 1)
		if character not in "0123456789ABCDEF":
			return false
	return true


static func _canonical_json_bytes_sha256(source_bytes: PackedByteArray) -> Dictionary:
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		source_bytes,
		{
			"max_input_bytes": MAX_CONTRACT_BYTES,
			"max_output_bytes": MAX_CONTRACT_BYTES,
		}
	)
	if not bool(canonical.get("ok", false)):
		return {
			"ok": false,
			"error_code": str(canonical.get("error_code", "invalid_contract_artifact")),
		}
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return {"ok": false, "error_code": "sha256_unavailable"}
	if context.update(canonical.get("bytes", PackedByteArray())) != OK:
		return {"ok": false, "error_code": "sha256_failed"}
	return {
		"ok": true,
		"error_code": "",
		"sha256": context.finish().hex_encode().to_upper(),
	}


static func _canonical_json_value_sha256(value: Variant) -> Dictionary:
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact(
		value,
		{
			"max_input_bytes": MAX_CONTRACT_BYTES,
			"max_output_bytes": MAX_CONTRACT_BYTES,
		}
	)
	if not bool(canonical.get("ok", false)):
		return {
			"ok": false,
			"error_code": str(canonical.get("error_code", "invalid_contract_artifact")),
		}
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return {"ok": false, "error_code": "sha256_unavailable"}
	if context.update(canonical.get("bytes", PackedByteArray())) != OK:
		return {"ok": false, "error_code": "sha256_failed"}
	return {
		"ok": true,
		"error_code": "",
		"sha256": context.finish().hex_encode().to_upper(),
	}
