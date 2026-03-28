class_name AIVersionRegistry
extends RefCounted

var base_dir: String = "user://ai_versions"
const INDEX_FILE := "index.json"


func save_version(record: Dictionary) -> bool:
	var version_id := str(record.get("version_id", ""))
	if version_id.is_empty():
		return false

	_ensure_dir_exists()
	var index := _load_index()
	index[version_id] = record.duplicate(true)
	return _save_index(index)


func get_version(version_id: String) -> Dictionary:
	return (_load_index().get(version_id, {}) as Dictionary).duplicate(true)


func list_playable_versions() -> Array[Dictionary]:
	var versions: Array[Dictionary] = []
	for value: Variant in _load_index().values():
		if value is Dictionary and str((value as Dictionary).get("status", "")) == "playable":
			versions.append((value as Dictionary).duplicate(true))
	versions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("created_at", "")) < str(b.get("created_at", ""))
	)
	return versions


func get_latest_playable_version() -> Dictionary:
	var versions := list_playable_versions()
	return {} if versions.is_empty() else versions.back().duplicate(true)


func _load_index() -> Dictionary:
	var index_path := _index_path()
	if not FileAccess.file_exists(index_path):
		return {}
	var file := FileAccess.open(index_path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data: Variant = json.data
	return data if data is Dictionary else {}


func _save_index(index: Dictionary) -> bool:
	_ensure_dir_exists()
	var file := FileAccess.open(_index_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(index, "  "))
	file.close()
	return true


func _ensure_dir_exists() -> void:
	var global_dir := ProjectSettings.globalize_path(base_dir)
	if not DirAccess.dir_exists_absolute(global_dir):
		DirAccess.make_dir_recursive_absolute(global_dir)


func _index_path() -> String:
	return base_dir.path_join(INDEX_FILE)
