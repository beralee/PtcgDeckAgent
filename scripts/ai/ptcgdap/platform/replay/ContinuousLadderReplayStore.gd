class_name PtcgDAPContinuousLadderReplayStore
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const ContractScript = preload(
	"res://scripts/ai/ptcgdap/platform/service/StrategyPlatformServiceContract.gd"
)

const DEFAULT_ROOT := "user://ptcgdap/ladder_replays"
const MAX_REPLAY_BYTES := 4 * 1024 * 1024

var _root := DEFAULT_ROOT


static func create(root: String = DEFAULT_ROOT) -> Dictionary:
	var normalized := root.trim_suffix("/")
	if not _valid_root(normalized):
		return _failure("continuous_ladder_replay_root_invalid")
	var store := new()
	store._root = normalized
	return {
		"accepted": true,
		"error_code": "",
		"store": store,
		"authoritative": false,
		"grants": [],
	}


func store_replay(replay: Dictionary) -> Dictionary:
	if replay.get("document_type") != "godot_v18_public_series_replay_v1" \
			or replay.get("schema_version") != 1 \
			or not ContractScript.safe_identifier(replay.get("series_id")):
		return _failure("continuous_ladder_replay_invalid")
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact(
		replay,
		{"max_input_bytes": MAX_REPLAY_BYTES, "max_output_bytes": MAX_REPLAY_BYTES},
	)
	if not bool(canonical.get("ok", false)):
		return _failure("continuous_ladder_replay_invalid")
	var replay_bytes: PackedByteArray = canonical.get("bytes", PackedByteArray())
	if replay_bytes.is_empty() or replay_bytes.size() > MAX_REPLAY_BYTES:
		return _failure("continuous_ladder_replay_invalid")
	var absolute_root := ProjectSettings.globalize_path(_root)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_root)
	if mkdir_error != OK and not DirAccess.dir_exists_absolute(absolute_root):
		return _failure("continuous_ladder_replay_storage_unavailable")
	if _is_link(_root):
		return _failure("continuous_ladder_replay_storage_invalid")
	var series_id := str(replay.get("series_id"))
	var destination := _root.path_join("%s.ptcgladderreplay.json" % series_id)
	if _is_link(destination):
		return _failure("continuous_ladder_replay_destination_invalid")
	if FileAccess.file_exists(destination):
		if FileAccess.get_file_as_bytes(destination) == replay_bytes:
			return _stored_result(destination, replay_bytes, true)
		return _failure("continuous_ladder_replay_destination_conflict")
	var temporary := _root.path_join(
		".%s-%d.tmp" % [series_id, Time.get_ticks_usec()]
	)
	if FileAccess.file_exists(temporary) or _is_link(temporary):
		return _failure("continuous_ladder_replay_destination_conflict")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _failure("continuous_ladder_replay_write_failed")
	file.store_buffer(replay_bytes)
	file.close()
	if not FileAccess.file_exists(temporary) \
			or FileAccess.get_file_as_bytes(temporary) != replay_bytes:
		_remove_owned_file(temporary)
		return _failure("continuous_ladder_replay_write_failed")
	if DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary),
		ProjectSettings.globalize_path(destination),
	) != OK:
		_remove_owned_file(temporary)
		return _failure("continuous_ladder_replay_write_failed")
	return _stored_result(destination, replay_bytes, false)


func root_path() -> String:
	return _root


static func _stored_result(
	path: String,
	replay_bytes: PackedByteArray,
	already_downloaded: bool
) -> Dictionary:
	return {
		"ok": true,
		"error_code": "",
		"path": path,
		"absolute_path": ProjectSettings.globalize_path(path),
		"canonical_sha256": _sha256(replay_bytes),
		"byte_size": replay_bytes.size(),
		"already_downloaded": already_downloaded,
		"authoritative": false,
		"grants": [],
	}


static func _valid_root(value: String) -> bool:
	if not value.begins_with("user://") or value == "user://" \
			or value != value.strip_edges():
		return false
	for segment: String in value.trim_prefix("user://").split("/", false):
		if segment in ["", ".", ".."]:
			return false
	return true


static func _is_link(path: String) -> bool:
	var parent := DirAccess.open(path.get_base_dir())
	return parent != null and parent.is_link(path.get_file())


static func _remove_owned_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _sha256(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK \
			or context.update(value) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"accepted": false,
		"error_code": code,
		"authoritative": false,
		"grants": [],
	}
