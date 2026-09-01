class_name PtcgDAPPublicReplayStore
extends RefCounted

const PresentationScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayPresentation.gd")
const CaptureScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayCapture.gd")
const ROOT := "user://ptcgdap/public_replays"
const ARTIFACT_KEYS := ["match_envelope", "manifest", "frames"]
const INDEX_KEYS := [
	"storage_schema_version", "replay_id", "match_id", "manifest_canonical_sha256",
	"frame_count", "frame_chain_root_sha256",
]

var _contract_owner: Variant = null
var _root := ""
var _accepted_lane := "developer_local"


static func create(
	contract_owner: Variant,
	storage_namespace: String = "default",
	accepted_lane: String = "developer_local"
) -> Dictionary:
	if contract_owner == null or not contract_owner.has_method("validate_replay"):
		return _failure("contract_owner_invalid")
	if not _is_safe_segment(storage_namespace):
		return _failure("storage_namespace_invalid")
	if accepted_lane not in ["developer_local", "community_challenge"]:
		return _failure("storage_lane_invalid")
	var store := new()
	store._contract_owner = contract_owner
	store._root = "%s/%s" % [ROOT, storage_namespace]
	store._accepted_lane = accepted_lane
	var error := store._ensure_directories()
	if error != OK:
		return _failure("storage_unavailable")
	return {"accepted": true, "error_code": "", "store": store}


func save_completed(artifact: Variant) -> Dictionary:
	var validation := _validate_artifact(artifact)
	if not bool(validation.get("accepted", false)):
		return validation
	var value: Dictionary = (artifact as Dictionary).duplicate(true)
	var replay_id := str(value.manifest.replay_id)
	if not _is_safe_segment(replay_id):
		return _failure("replay_id_path_unsafe")
	var artifact_path := "%s/artifacts/%s.json" % [_root, replay_id]
	var index_path := "%s/index/%s.json" % [_root, replay_id]
	if FileAccess.file_exists(artifact_path) or FileAccess.file_exists(index_path):
		return _failure("replay_exists")
	var write_error := _write_new_json(artifact_path, value)
	if not write_error.is_empty():
		return _failure(write_error)
	var manifest_result: Dictionary = _contract_owner.validate_document(value.manifest)
	var index_entry := {
		"storage_schema_version": 1,
		"replay_id": replay_id,
		"match_id": value.manifest.match_id,
		"manifest_canonical_sha256": manifest_result.canonical_sha256,
		"frame_count": value.manifest.frame_count,
		"frame_chain_root_sha256": value.manifest.frame_chain_root_sha256,
	}
	write_error = _write_new_json(index_path, index_entry)
	if not write_error.is_empty():
		return _failure("index_write_failed_after_artifact")
	return {
		"accepted": true,
		"error_code": "",
		"replay_id": replay_id,
		"artifact_path": artifact_path,
		"manifest_canonical_sha256": manifest_result.canonical_sha256,
		"authoritative": false,
		"grants": [],
	}


func load_replay(replay_id: String) -> Dictionary:
	if not _is_safe_segment(replay_id):
		return _failure("replay_id_path_unsafe")
	var path := "%s/artifacts/%s.json" % [_root, replay_id]
	if not FileAccess.file_exists(path):
		return _failure("replay_not_found")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	parsed = _coerce_integral_numbers(parsed)
	var validation := _validate_artifact(parsed)
	if not bool(validation.get("accepted", false)):
		return validation
	return {
		"accepted": true,
		"error_code": "",
		"artifact": (parsed as Dictionary).duplicate(true),
		"authoritative": false,
		"grants": [],
	}


func list_index() -> Dictionary:
	var scanned := _scan_index()
	if not bool(scanned.get("accepted", false)):
		return scanned
	if int(scanned.get("rejected_count", 0)) > 0:
		return _failure("replay_index_invalid")
	return {
		"accepted": true,
		"error_code": "",
		"entries": scanned.get("entries", []),
		"authoritative": false,
		"grants": [],
	}


func list_available_index() -> Dictionary:
	var scanned := _discover_index()
	if not bool(scanned.get("accepted", false)):
		return scanned
	return {
		"accepted": true,
		"error_code": "",
		"entries": scanned.get("entries", []),
		"rejected_count": int(scanned.get("rejected_count", 0)),
		"authoritative": false,
		"grants": [],
	}


func _discover_index() -> Dictionary:
	var entries: Array = []
	var rejected_count := 0
	var directory := DirAccess.open("%s/index" % _root)
	if directory == null:
		return _failure("storage_unavailable")
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		if not directory.current_is_dir() and filename.ends_with(".json"):
			var replay_id := filename.trim_suffix(".json")
			var index_value: Variant = JSON.parse_string(
				FileAccess.get_file_as_string("%s/index/%s" % [_root, filename])
			)
			index_value = _coerce_integral_numbers(index_value)
			var artifact_path := "%s/artifacts/%s.json" % [_root, replay_id]
			if (
				_valid_index(index_value)
				and index_value.replay_id == replay_id
				and FileAccess.file_exists(artifact_path)
			):
				entries.append((index_value as Dictionary).duplicate(true))
			else:
				rejected_count += 1
		filename = directory.get_next()
	directory.list_dir_end()
	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.replay_id) < str(right.replay_id)
	)
	return {
		"accepted": true,
		"error_code": "",
		"entries": entries,
		"rejected_count": rejected_count,
		"authoritative": false,
		"grants": [],
	}


func _scan_index() -> Dictionary:
	var entries: Array = []
	var invalid_entries := 0
	var directory := DirAccess.open("%s/index" % _root)
	if directory == null:
		return _failure("storage_unavailable")
	directory.list_dir_begin()
	var filename := directory.get_next()
	while not filename.is_empty():
		if not directory.current_is_dir() and filename.ends_with(".json"):
			var replay_id := filename.trim_suffix(".json")
			var index_value: Variant = JSON.parse_string(
				FileAccess.get_file_as_string("%s/index/%s" % [_root, filename])
			)
			index_value = _coerce_integral_numbers(index_value)
			var loaded := load_replay(replay_id)
			if _valid_index(index_value) and bool(loaded.get("accepted", false)):
				var artifact: Dictionary = loaded.artifact
				var manifest_result: Dictionary = _contract_owner.validate_document(artifact.manifest)
				if (
					index_value.replay_id == artifact.manifest.replay_id
					and index_value.match_id == artifact.manifest.match_id
					and index_value.manifest_canonical_sha256 == manifest_result.canonical_sha256
					and index_value.frame_count == artifact.manifest.frame_count
					and index_value.frame_chain_root_sha256 == artifact.manifest.frame_chain_root_sha256
				):
					entries.append((index_value as Dictionary).duplicate(true))
				else:
					invalid_entries += 1
			else:
				invalid_entries += 1
		filename = directory.get_next()
	directory.list_dir_end()
	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.replay_id) < str(right.replay_id)
	)
	return {
		"accepted": true,
		"error_code": "",
		"entries": entries,
		"rejected_count": invalid_entries,
		"authoritative": false,
		"grants": [],
	}


func _validate_artifact(artifact: Variant) -> Dictionary:
	if not artifact is Dictionary or not _has_exact_keys(artifact, ARTIFACT_KEYS):
		return _failure("replay_artifact_invalid")
	var envelope_result: Dictionary = _contract_owner.validate_document(artifact.match_envelope)
	if not bool(envelope_result.get("accepted", false)):
		return envelope_result
	var replay_result: Dictionary = _contract_owner.validate_replay(artifact.manifest, artifact.frames)
	if not bool(replay_result.get("accepted", false)):
		return replay_result
	if (
		artifact.match_envelope.match_id != artifact.manifest.match_id
		or envelope_result.canonical_sha256 != artifact.manifest.match_envelope_sha256
		or artifact.match_envelope.lane != _accepted_lane
	):
		return _failure("replay_envelope_binding_invalid")
	if not CaptureScript.is_supported_envelope(artifact.match_envelope):
		return _failure("capture_scope_unsupported")
	var presentation_result: Dictionary = PresentationScript.create(
		_contract_owner, artifact.manifest, artifact.frames
	)
	if not bool(presentation_result.get("accepted", false)):
		return presentation_result
	return {"accepted": true, "error_code": "", "authoritative": false, "grants": []}


func _ensure_directories() -> Error:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/artifacts" % _root))
	if error != OK and error != ERR_ALREADY_EXISTS:
		return error
	error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/index" % _root))
	return OK if error in [OK, ERR_ALREADY_EXISTS] else error


static func _write_new_json(path: String, value: Variant) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "storage_write_failed"
	file.store_string(JSON.stringify(value, "\t"))
	file.close()
	return ""


static func _valid_index(value: Variant) -> bool:
	return (
		value is Dictionary
		and _has_exact_keys(value, INDEX_KEYS)
		and value.storage_schema_version == 1
		and typeof(value.replay_id) == TYPE_STRING
		and typeof(value.match_id) == TYPE_STRING
		and typeof(value.manifest_canonical_sha256) == TYPE_STRING
		and typeof(value.frame_count) == TYPE_INT
		and typeof(value.frame_chain_root_sha256) == TYPE_STRING
	)


static func _has_exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _is_safe_segment(value: String) -> bool:
	if value.is_empty() or value.length() > 96 or value != value.strip_edges():
		return false
	for index: int in value.length():
		var code := value.unicode_at(index)
		var allowed := (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or code in [45, 46, 95]
		)
		if not allowed:
			return false
	return true


static func _coerce_integral_numbers(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value):
		return int(value)
	if value is Array:
		var output: Array = []
		for child: Variant in value:
			output.append(_coerce_integral_numbers(child))
		return output
	if value is Dictionary:
		var output := {}
		for key: Variant in value:
			output[key] = _coerce_integral_numbers(value[key])
		return output
	return value


static func _failure(code: String) -> Dictionary:
	return {"accepted": false, "error_code": code, "authoritative": false, "grants": []}
