@tool
extends EditorExportPlugin

const AppVersion := preload("res://scripts/app/AppVersion.gd")
const WebReleaseLayout := preload("res://addons/web_release_post_export/web_release_layout.gd")

const PUBLIC_BASE_PATH := "/dist"
const LATEST_FILE_NAME := "latest-web.json"
const RELEASE_MANIFEST_FILE_NAME := "release-manifest.json"

var _pending_export_path := ""
var _should_generate_release_metadata := false


func _get_name() -> String:
	return "WebReleasePostExport"


func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	_pending_export_path = path
	_should_generate_release_metadata = (not is_debug) and _is_web_export(features, path)


func _export_end() -> void:
	if not _should_generate_release_metadata:
		_reset_pending_export()
		return

	var generated := _generate_release_metadata(_pending_export_path)
	_reset_pending_export()
	if not generated:
		print("Web release metadata was not generated after export.")


func _is_web_export(features: PackedStringArray, path: String) -> bool:
	if path.replace("\\", "/").get_extension().to_lower() == "html":
		return true
	for feature: String in features:
		if feature.to_lower() == "web":
			return true
	return false


func _generate_release_metadata(export_path: String) -> bool:
	var export_file_path := _to_absolute_path(export_path)
	var layout := WebReleaseLayout.prepare_release_directory(export_file_path, AppVersion.VERSION)
	if not bool(layout.get("ok", false)):
		push_warning(str(layout.get("error", "Unable to prepare Web release directory.")))
		return false

	var release_dir := str(layout.get("release_dir", ""))
	var output_root := str(layout.get("output_root", ""))
	var base_name := str(layout.get("base_name", ""))
	if release_dir == "" or output_root == "" or base_name == "":
		push_warning("Unable to infer Web release metadata paths from export path: %s" % export_path)
		return false

	var missing_files := _collect_missing_required_files(release_dir, base_name)
	if not missing_files.is_empty():
		print("Web release metadata skipped because required export files are missing: %s" % ", ".join(missing_files))
		return false

	var files := _collect_release_files(release_dir)
	if files.is_empty():
		push_warning("Web release metadata skipped because no release files were found in %s" % release_dir)
		return false

	var public_base := PUBLIC_BASE_PATH.trim_suffix("/")
	var release_path := _infer_release_path(release_dir, public_base)
	var entry_url := "%s/%s.html" % [release_path, base_name]
	var generated_at := "%sZ" % Time.get_datetime_string_from_system(true, false)

	var release_manifest := {
		"schema_version": 1,
		"version": AppVersion.VERSION,
		"display_version": AppVersion.DISPLAY_VERSION,
		"build_number": AppVersion.BUILD_NUMBER,
		"channel": AppVersion.CHANNEL,
		"public_base_path": public_base,
		"release_path": release_path,
		"entry": entry_url,
		"generated_at": generated_at,
		"files": files,
		"cache_policy": {
			"entry_html": "no-cache",
			"versioned_assets": "public, max-age=31536000, immutable",
		},
	}
	var latest := {
		"schema_version": 1,
		"version": AppVersion.VERSION,
		"display_version": AppVersion.DISPLAY_VERSION,
		"build_number": AppVersion.BUILD_NUMBER,
		"channel": AppVersion.CHANNEL,
		"release_path": release_path,
		"entry": entry_url,
		"manifest": "%s/%s" % [release_path, RELEASE_MANIFEST_FILE_NAME],
		"generated_at": generated_at,
	}

	var output_root_error := DirAccess.make_dir_recursive_absolute(output_root)
	if output_root_error != OK:
		push_warning("Unable to create Web release output root %s: %s" % [output_root, error_string(output_root_error)])
		return false

	var manifest_path := release_dir.path_join(RELEASE_MANIFEST_FILE_NAME)
	var latest_path := output_root.path_join(LATEST_FILE_NAME)
	if not _write_json_file(manifest_path, release_manifest):
		return false
	if not _write_json_file(latest_path, latest):
		return false

	print("Generated Web release metadata: %s and %s" % [manifest_path, latest_path])
	return true


func _to_absolute_path(path: String) -> String:
	var normalized := path.replace("\\", "/")
	if normalized.begins_with("res://") or normalized.begins_with("user://"):
		return ProjectSettings.globalize_path(normalized).replace("\\", "/").simplify_path()
	if normalized.is_absolute_path():
		return normalized.simplify_path()
	var project_root := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	return project_root.path_join(normalized).simplify_path()


func _infer_release_path(release_dir: String, public_base: String) -> String:
	var parent_dir := release_dir.get_base_dir().get_file()
	if parent_dir != "":
		return "%s/%s/%s" % [public_base, parent_dir, release_dir.get_file()]
	return "%s/%s" % [public_base, release_dir.get_file()]


func _collect_missing_required_files(release_dir: String, base_name: String) -> PackedStringArray:
	var missing := PackedStringArray()
	for extension: String in ["html", "js", "pck", "wasm"]:
		var file_path := release_dir.path_join("%s.%s" % [base_name, extension])
		if not FileAccess.file_exists(file_path):
			missing.append(file_path)
	return missing


func _collect_release_files(release_dir: String) -> Array[Dictionary]:
	var dir := DirAccess.open(release_dir)
	if dir == null:
		push_warning("Unable to open Web release directory: %s" % release_dir)
		return []

	var file_names: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name != RELEASE_MANIFEST_FILE_NAME:
			file_names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	file_names.sort()

	var result: Array[Dictionary] = []
	for release_file_name: String in file_names:
		var file_path := release_dir.path_join(release_file_name)
		var file := FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			push_warning("Unable to read release file for metadata: %s" % file_path)
			continue
		var file_size := file.get_length()
		file.close()
		result.append({
			"name": release_file_name,
			"size": file_size,
			"sha256": FileAccess.get_sha256(file_path),
		})
	return result


func _write_json_file(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to write Web release metadata file: %s" % path)
		return false
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	file.close()
	return true


func _reset_pending_export() -> void:
	_pending_export_path = ""
	_should_generate_release_metadata = false
