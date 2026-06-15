@tool
extends RefCounted

const LATEST_FILE_NAME := "latest-web.json"
const RELEASE_MANIFEST_FILE_NAME := "release-manifest.json"


static func prepare_release_directory(export_file_path: String, version: String) -> Dictionary:
	var normalized_export_path := export_file_path.replace("\\", "/").simplify_path()
	var source_dir := normalized_export_path.get_base_dir()
	var base_name := normalized_export_path.get_file().get_basename()
	var release_slug := get_release_slug(version)
	if source_dir == "" or base_name == "" or version == "":
		return {
			"ok": false,
			"error": "Unable to infer Web release layout from export path: %s" % export_file_path,
		}

	var version_parent := source_dir.get_base_dir()
	if source_dir.get_file() == release_slug and source_dir.get_base_dir().get_file() == "web":
		return {
			"ok": true,
			"base_name": base_name,
			"release_dir": source_dir,
			"release_slug": release_slug,
			"output_root": source_dir.get_base_dir().get_base_dir(),
			"normalized": false,
		}

	var output_root := source_dir
	if source_dir.get_file() == version and version_parent.get_file() == "releases":
		output_root = version_parent.get_base_dir()
	var release_dir := output_root.path_join("web").path_join(release_slug)
	var make_error := DirAccess.make_dir_recursive_absolute(release_dir)
	if make_error != OK:
		return {
			"ok": false,
			"error": "Unable to create Web release directory %s: %s" % [release_dir, error_string(make_error)],
		}

	var move_error := _move_flat_export_files(source_dir, release_dir, base_name)
	if move_error != "":
		return {
			"ok": false,
			"error": move_error,
		}
	_remove_stale_root_manifest(output_root)

	return {
		"ok": true,
		"base_name": base_name,
		"release_dir": release_dir,
		"release_slug": release_slug,
		"output_root": output_root,
		"normalized": true,
	}


static func get_release_slug(version: String) -> String:
	return "v%s" % version.replace(".", "_").replace("-", "_")


static func _move_flat_export_files(source_dir: String, release_dir: String, base_name: String) -> String:
	var dir := DirAccess.open(source_dir)
	if dir == null:
		return "Unable to open Web export directory: %s" % source_dir

	var prefix := "%s." % base_name
	var file_names: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with(prefix):
			file_names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	for export_file_name: String in file_names:
		var from_path := source_dir.path_join(export_file_name)
		var to_path := release_dir.path_join(export_file_name)
		if FileAccess.file_exists(to_path):
			var remove_error := DirAccess.remove_absolute(to_path)
			if remove_error != OK:
				return "Unable to replace existing Web release file %s: %s" % [to_path, error_string(remove_error)]
		var rename_error := DirAccess.rename_absolute(from_path, to_path)
		if rename_error != OK:
			return "Unable to move Web export file %s to %s: %s" % [from_path, to_path, error_string(rename_error)]
	return ""


static func _remove_stale_root_manifest(output_root: String) -> void:
	var stale_manifest_path := output_root.path_join(RELEASE_MANIFEST_FILE_NAME)
	if FileAccess.file_exists(stale_manifest_path):
		DirAccess.remove_absolute(stale_manifest_path)
