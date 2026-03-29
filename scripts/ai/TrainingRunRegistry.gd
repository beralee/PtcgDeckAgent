class_name TrainingRunRegistry
extends RefCounted

var base_dir: String = "user://training_runs"


func start_run(pipeline_name: String) -> Dictionary:
	var run_id := _make_run_id()
	return create_run(run_id, pipeline_name)


func create_run(run_id: String, pipeline_name: String, metadata: Dictionary = {}) -> Dictionary:
	if run_id.strip_edges().is_empty():
		return {}

	var record := get_run(run_id)
	if record.is_empty():
		record = {
			"run_id": run_id,
			"pipeline_name": pipeline_name,
			"status": "running",
			"created_at": Time.get_datetime_string_from_system(),
		}
	elif pipeline_name != "" and str(record.get("pipeline_name", "")).is_empty():
		record["pipeline_name"] = pipeline_name

	for key: Variant in metadata.keys():
		record[key] = metadata[key]

	if not _save_run_record(run_id, record):
		return {}
	return get_run(run_id)


func complete_run(run_id: String, patch: Dictionary) -> Dictionary:
	var record := get_run(run_id)
	if record.is_empty():
		return {}

	for key: Variant in patch.keys():
		record[key] = patch[key]

	record["completed_at"] = Time.get_datetime_string_from_system()
	if not _save_run_record(run_id, record):
		return {}
	return get_run(run_id)


func get_run(run_id: String) -> Dictionary:
	var path := _run_file_path(run_id)
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return {}

	var data: Variant = json.data
	if data is Dictionary:
		return (data as Dictionary).duplicate(true)

	return {}


func get_run_dir_path(run_id: String) -> String:
	return _run_dir_path(run_id)


func _save_run_record(run_id: String, record: Dictionary) -> bool:
	var path := _run_file_path(run_id)

	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var mkdir_error := DirAccess.make_dir_recursive_absolute(dir_path)
		if mkdir_error != OK:
			return false

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(record, "  "))
	file.close()
	return true


func _run_dir_path(run_id: String) -> String:
	return base_dir.path_join(run_id)


func _run_file_path(run_id: String) -> String:
	return ProjectSettings.globalize_path(_run_dir_path(run_id).path_join("run.json"))


func _make_run_id() -> String:
	var timestamp := Time.get_datetime_string_from_system()
	var microseconds := Time.get_ticks_usec() % 1000000
	return "run_%s_%06d" % [timestamp.replace(":", "").replace("-", "").replace("T", "_"), microseconds]
