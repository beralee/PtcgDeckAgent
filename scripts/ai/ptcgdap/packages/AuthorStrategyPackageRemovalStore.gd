class_name AuthorStrategyPackageRemovalStore
extends RefCounted

const SCHEMA_VERSION := 1
const DEFAULT_PATH := "user://ptcgdap/author_strategy_removed.json"

var _path := DEFAULT_PATH


func set_path_for_tests(path: String) -> void:
	_path = path


func path() -> String:
	return _path


func snapshot() -> Dictionary:
	if not FileAccess.file_exists(_path):
		return _snapshot([])
	if _is_link(_path):
		return _error("package_removal_store_invalid")
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(_path)) != OK:
		return _error("package_removal_store_invalid")
	var decoded: Variant = parser.data
	if not decoded is Dictionary or int(decoded.get("schema_version", -1)) != SCHEMA_VERSION:
		return _error("package_removal_store_invalid")
	var raw_refs: Variant = decoded.get("removed_packages", [])
	if not raw_refs is Array:
		return _error("package_removal_store_invalid")
	var refs: Array[Dictionary] = []
	var keys := {}
	for value: Variant in raw_refs:
		if not value is Dictionary:
			return _error("package_removal_store_invalid")
		var reference := _normalize_ref(value)
		if reference.is_empty():
			return _error("package_removal_store_invalid")
		var key := _key(reference)
		if keys.has(key):
			continue
		keys[key] = true
		refs.append(reference)
	refs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _key(a) < _key(b))
	return _snapshot(refs)


func set_removed(reference: Dictionary, removed: bool) -> Dictionary:
	var normalized := _normalize_ref(reference)
	if normalized.is_empty():
		return _error("package_remove_reference_invalid")
	var current := snapshot()
	if not bool(current.get("ok", false)):
		return current
	var refs: Array[Dictionary] = []
	for value: Variant in current.get("removed_packages", []):
		if value is Dictionary:
			refs.append((value as Dictionary).duplicate(true))
	var target_key := _key(normalized)
	var existing_index := -1
	for index: int in refs.size():
		if _key(refs[index]) == target_key:
			existing_index = index
			break
	if removed and existing_index >= 0:
		return {"ok": true, "error_code": "", "changed": false, "removed_packages": refs}
	if not removed and existing_index < 0:
		return {"ok": true, "error_code": "", "changed": false, "removed_packages": refs}
	if removed:
		refs.append(normalized)
	else:
		refs.remove_at(existing_index)
	refs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _key(a) < _key(b))
	var persisted := _persist(refs)
	if not bool(persisted.get("ok", false)):
		return persisted
	return {
		"ok": true,
		"error_code": "",
		"changed": true,
		"removed_packages": refs.duplicate(true),
		"cleanup_pending": bool(persisted.get("cleanup_pending", false)),
	}


func _persist(refs: Array[Dictionary]) -> Dictionary:
	var parent_absolute := ProjectSettings.globalize_path(_path.get_base_dir())
	var mkdir_error := DirAccess.make_dir_recursive_absolute(parent_absolute)
	if mkdir_error != OK and not DirAccess.dir_exists_absolute(parent_absolute):
		return _error("package_removal_store_unavailable")
	if _is_link(_path):
		return _error("package_removal_store_invalid")
	var temporary := _path + ".tmp"
	var backup := _path + ".bak"
	if FileAccess.file_exists(temporary) or FileAccess.file_exists(backup):
		return _error("package_removal_store_busy")
	var payload := {
		"schema_version": SCHEMA_VERSION,
		"removed_packages": refs,
	}
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _error("package_removal_store_unavailable")
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(temporary)) != OK:
		_remove_file(temporary)
		return _error("package_removal_store_write_failed")
	var decoded: Variant = parser.data
	if not decoded is Dictionary or decoded.get("removed_packages", []) != refs:
		_remove_file(temporary)
		return _error("package_removal_store_write_failed")
	var had_existing := FileAccess.file_exists(_path)
	if had_existing and DirAccess.rename_absolute(
		ProjectSettings.globalize_path(_path), ProjectSettings.globalize_path(backup)
	) != OK:
		_remove_file(temporary)
		return _error("package_removal_store_write_failed")
	if DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(_path)
	) != OK:
		if had_existing and FileAccess.file_exists(backup):
			DirAccess.rename_absolute(
				ProjectSettings.globalize_path(backup), ProjectSettings.globalize_path(_path)
			)
		_remove_file(temporary)
		return _error("package_removal_store_write_failed")
	var cleanup_pending := false
	if had_existing and FileAccess.file_exists(backup):
		cleanup_pending = DirAccess.remove_absolute(ProjectSettings.globalize_path(backup)) != OK
	return {"ok": true, "error_code": "", "cleanup_pending": cleanup_pending}


func _snapshot(refs: Array[Dictionary]) -> Dictionary:
	return {
		"ok": true,
		"error_code": "",
		"removed_packages": refs.duplicate(true),
		"path": _path,
	}


func _normalize_ref(value: Dictionary) -> Dictionary:
	var package_id := str(value.get("package_id", "")).strip_edges()
	var package_version := str(value.get("package_version", "")).strip_edges()
	var archive_sha := str(value.get("archive_sha256", "")).strip_edges().to_upper()
	if package_id.is_empty() or package_id.length() > 128 or _contains_control(package_id):
		return {}
	if package_version.is_empty() or package_version.length() > 64 or _contains_control(package_version):
		return {}
	if archive_sha.length() != 64:
		return {}
	for index: int in archive_sha.length():
		var code := archive_sha.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 65 and code <= 70):
			return {}
	return {
		"package_id": package_id,
		"package_version": package_version,
		"archive_sha256": archive_sha,
	}


func _key(reference: Dictionary) -> String:
	return "%s\n%s\n%s" % [
		reference.get("package_id", ""),
		reference.get("package_version", ""),
		reference.get("archive_sha256", ""),
	]


func _contains_control(value: String) -> bool:
	for index: int in value.length():
		var code := value.unicode_at(index)
		if code < 32 or code == 127:
			return true
	return false


func _is_link(value: String) -> bool:
	var parent := DirAccess.open(value.get_base_dir())
	return parent != null and parent.is_link(value.get_file())


func _remove_file(value: String) -> void:
	if FileAccess.file_exists(value):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(value))


func _error(code: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": code,
		"removed_packages": [],
		"path": _path,
	}
