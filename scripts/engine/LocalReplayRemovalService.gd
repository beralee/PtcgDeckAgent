class_name LocalReplayRemovalService
extends RefCounted

const NATIVE_ROOT := "user://match_records"
const PUBLIC_ROOT := "user://ptcgdap/public_replays/live-community"
const STAGING_PREFIX := ".ptcgdap-replay-remove-"
const TEST_ROOT_PREFIX := "user://ptcgdap/tests/"

var _native_root := NATIVE_ROOT
var _public_root := PUBLIC_ROOT


func set_roots_for_tests(native_root: String, public_root: String) -> bool:
	var normalized_native := native_root.strip_edges().simplify_path()
	var normalized_public := public_root.strip_edges().simplify_path()
	if (
		not normalized_native.begins_with(TEST_ROOT_PREFIX)
		or not normalized_public.begins_with(TEST_ROOT_PREFIX)
	):
		return false
	_native_root = normalized_native
	_public_root = normalized_public
	return true


func remove_native(
	match_id: String,
	match_dir: String,
	public_replay_ids: Array
) -> Dictionary:
	var normalized_match_id := match_id.strip_edges()
	if not _is_safe_segment(normalized_match_id):
		return _error("replay_remove_reference_invalid")
	var expected_match_dir := _native_root.path_join(normalized_match_id).simplify_path()
	if match_dir.strip_edges().simplify_path() != expected_match_dir:
		return _error("replay_remove_reference_invalid")
	if (
		not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(expected_match_dir))
		or _has_linked_ancestor(expected_match_dir)
		or not _is_native_replay_directory(expected_match_dir)
	):
		return _error("replay_remove_not_found")
	var normalized_public := _normalize_replay_ids(public_replay_ids)
	if normalized_public.size() != public_replay_ids.size():
		return _error("replay_remove_reference_invalid")
	var transaction_id := Time.get_ticks_usec()
	var targets: Array[Dictionary] = [{
		"original": expected_match_dir,
		"staging": _staging_path(expected_match_dir, transaction_id, 0, true),
		"directory": true,
	}]
	var ordinal := 1
	for replay_id: String in normalized_public:
		var public_targets := _public_targets(replay_id, transaction_id, ordinal)
		if public_targets.is_empty():
			return _error("replay_remove_public_incomplete")
		targets.append_array(public_targets)
		ordinal += public_targets.size()
	return _execute(targets, true, normalized_public.size())


func remove_public(replay_id: String) -> Dictionary:
	var normalized := replay_id.strip_edges()
	if not _is_safe_segment(normalized):
		return _error("replay_remove_reference_invalid")
	var targets := _public_targets(normalized, Time.get_ticks_usec(), 0)
	if targets.is_empty():
		return _error("replay_remove_not_found")
	return _execute(targets, false, 1)


func _public_targets(
	replay_id: String,
	transaction_id: int,
	ordinal: int
) -> Array[Dictionary]:
	if not _is_safe_segment(replay_id):
		return []
	var artifact := _public_root.path_join("artifacts/%s.json" % replay_id).simplify_path()
	var index := _public_root.path_join("index/%s.json" % replay_id).simplify_path()
	if (
		not FileAccess.file_exists(artifact)
		or not FileAccess.file_exists(index)
		or _has_linked_ancestor(artifact)
		or _has_linked_ancestor(index)
	):
		return []
	return [
		{
			"original": artifact,
			"staging": _staging_path(artifact, transaction_id, ordinal, false),
			"directory": false,
		},
		{
			"original": index,
			"staging": _staging_path(index, transaction_id, ordinal + 1, false),
			"directory": false,
		},
	]


func _execute(
	targets: Array[Dictionary],
	native_removed: bool,
	public_removed_count: int
) -> Dictionary:
	var moved: Array[Dictionary] = []
	for target: Dictionary in targets:
		var original := str(target.get("original", ""))
		var staging := str(target.get("staging", ""))
		if original.is_empty() or staging.is_empty() or _path_exists(staging):
			return _rollback_failure(moved)
		var rename_error := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(original),
			ProjectSettings.globalize_path(staging)
		)
		if rename_error != OK:
			return _rollback_failure(moved)
		moved.append(target)
	var cleanup_pending := false
	for target: Dictionary in moved:
		var staging := str(target.get("staging", ""))
		var cleanup_error := (
			_remove_tree(staging)
			if bool(target.get("directory", false))
			else DirAccess.remove_absolute(ProjectSettings.globalize_path(staging))
		)
		if cleanup_error != OK:
			cleanup_pending = true
	return {
		"ok": true,
		"error_code": "",
		"native_removed": native_removed,
		"public_removed_count": public_removed_count,
		"cleanup_pending": cleanup_pending,
		"match_authority": false,
		"production_authority": false,
	}


func _rollback_failure(moved: Array[Dictionary]) -> Dictionary:
	var rollback_ok := true
	for index: int in range(moved.size() - 1, -1, -1):
		var target := moved[index]
		var staging := str(target.get("staging", ""))
		var original := str(target.get("original", ""))
		if _path_exists(staging) and DirAccess.rename_absolute(
			ProjectSettings.globalize_path(staging),
			ProjectSettings.globalize_path(original)
		) != OK:
			rollback_ok = false
	return _error(
		"replay_remove_failed" if rollback_ok else "replay_remove_rollback_failed"
	)


func _normalize_replay_ids(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		if typeof(value) != TYPE_STRING:
			return []
		var normalized := str(value).strip_edges()
		if not _is_safe_segment(normalized) or normalized in result:
			return []
		result.append(normalized)
	result.sort()
	return result


func _staging_path(
	original: String,
	transaction_id: int,
	ordinal: int,
	is_directory: bool
) -> String:
	var suffix := "%s%d-%d.tmp" % [STAGING_PREFIX, transaction_id, ordinal]
	return (
		original.get_base_dir().path_join(suffix)
		if is_directory
		else original + suffix
	)


func _remove_tree(path: String) -> Error:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return ERR_DOES_NOT_EXIST
	var directory := DirAccess.open(path)
	if directory == null:
		return ERR_CANT_OPEN
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		var error := OK
		if directory.current_is_dir() and not directory.is_link(entry):
			error = _remove_tree(child)
		else:
			error = DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		if error != OK:
			directory.list_dir_end()
			return error
		entry = directory.get_next()
	directory.list_dir_end()
	return DirAccess.remove_absolute(absolute)


func _is_native_replay_directory(path: String) -> bool:
	var match_path := path.path_join("match.json")
	if not FileAccess.file_exists(match_path) or _is_link(match_path):
		return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(match_path)) != OK:
		return false
	var payload: Variant = parser.data
	if not payload is Dictionary:
		return false
	var meta: Variant = (payload as Dictionary).get("meta", {})
	return (
		meta is Dictionary
		and str((meta as Dictionary).get("mode", "")) in [
			"two_player", "vs_ai", "vs_author_strategy_ai",
		]
	)


func _is_safe_segment(value: String) -> bool:
	if value.is_empty() or value in [".", ".."] or value.length() > 192:
		return false
	if value != value.get_file() or "/" in value or "\\" in value or ":" in value:
		return false
	for index: int in value.length():
		var code := value.unicode_at(index)
		if code < 32 or code == 127:
			return false
	return true


func _is_link(path: String) -> bool:
	var parent := DirAccess.open(path.get_base_dir())
	return parent != null and parent.is_link(path.get_file())


func _has_linked_ancestor(path: String) -> bool:
	var current := path.simplify_path()
	while current.begins_with("user://") and current != "user://":
		if _is_link(current):
			return true
		var parent := current.get_base_dir()
		if parent == current:
			break
		current = parent
	return false


func _path_exists(path: String) -> bool:
	return (
		FileAccess.file_exists(path)
		or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))
	)


func _error(code: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": code,
		"native_removed": false,
		"public_removed_count": 0,
		"cleanup_pending": false,
		"match_authority": false,
		"production_authority": false,
	}
