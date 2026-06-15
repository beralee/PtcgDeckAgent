class_name TestWebReleaseLayout
extends TestBase

const AppVersion := preload("res://scripts/app/AppVersion.gd")

const WEB_RELEASE_LAYOUT_PATH := "res://addons/web_release_post_export/web_release_layout.gd"
const BASE_NAME := "PtcgDeckAgent"


func test_flat_ide_export_is_moved_into_versioned_release_dir() -> String:
	var layout_script: GDScript = load(WEB_RELEASE_LAYOUT_PATH)
	if layout_script == null:
		return "Web release layout helper should exist: %s" % WEB_RELEASE_LAYOUT_PATH
	var root := _fresh_test_dir("flat")
	var export_path := root.path_join("%s.html" % BASE_NAME)
	_write_file(export_path, "html")
	_write_file(root.path_join("%s.js" % BASE_NAME), "js")
	_write_file(root.path_join("%s.pck" % BASE_NAME), "pck")
	_write_file(root.path_join("%s.wasm" % BASE_NAME), "wasm")
	_write_file(root.path_join("%s.service.worker.js" % BASE_NAME), "sw")
	_write_file(root.path_join("release-manifest.json"), "stale")
	_write_file(root.path_join("latest-web.json"), "latest")

	var result: Dictionary = layout_script.prepare_release_directory(export_path, AppVersion.VERSION)
	var expected_slug := _release_slug(AppVersion.VERSION)
	var release_dir := root.path_join("web").path_join(expected_slug)

	return run_checks([
		assert_true(bool(result.get("ok", false)), "Flat IDE export should be normalized successfully"),
		assert_eq(str(result.get("output_root", "")), root, "Output root should remain the selected IDE export directory"),
		assert_eq(str(result.get("release_slug", "")), expected_slug, "Release slug should avoid dots so CDN directory rules accept it"),
		assert_eq(str(result.get("release_dir", "")), release_dir, "Release files should move under web/<CDN-safe version slug>"),
		assert_eq(str(result.get("base_name", "")), BASE_NAME, "Base name should be preserved for manifest generation"),
		assert_true(bool(result.get("normalized", false)), "Flat export should report that files were moved"),
		assert_false(FileAccess.file_exists(export_path), "Entry HTML should no longer stay at the root"),
		assert_true(FileAccess.file_exists(release_dir.path_join("%s.html" % BASE_NAME)), "Entry HTML should exist in the versioned release dir"),
		assert_true(FileAccess.file_exists(release_dir.path_join("%s.service.worker.js" % BASE_NAME)), "PWA service worker should move with release files"),
		assert_false(FileAccess.file_exists(root.path_join("release-manifest.json")), "Stale root release manifest should be removed"),
		assert_true(FileAccess.file_exists(root.path_join("latest-web.json")), "Root latest pointer should stay at output root"),
	])


func test_versioned_export_path_is_left_in_place() -> String:
	var layout_script: GDScript = load(WEB_RELEASE_LAYOUT_PATH)
	if layout_script == null:
		return "Web release layout helper should exist: %s" % WEB_RELEASE_LAYOUT_PATH
	var root := _fresh_test_dir("versioned")
	var expected_slug := _release_slug(AppVersion.VERSION)
	var release_dir := root.path_join("web").path_join(expected_slug)
	var make_error := DirAccess.make_dir_recursive_absolute(release_dir)
	if make_error != OK:
		return "Unable to create test release dir: %s" % error_string(make_error)
	var export_path := release_dir.path_join("%s.html" % BASE_NAME)
	_write_file(export_path, "html")

	var result: Dictionary = layout_script.prepare_release_directory(export_path, AppVersion.VERSION)

	return run_checks([
		assert_true(bool(result.get("ok", false)), "Versioned export should be accepted"),
		assert_eq(str(result.get("output_root", "")), root, "Output root should be inferred above the release slug"),
		assert_eq(str(result.get("release_slug", "")), expected_slug, "Already-versioned export should expose the CDN-safe slug"),
		assert_eq(str(result.get("release_dir", "")), release_dir, "Release dir should remain unchanged"),
		assert_false(bool(result.get("normalized", true)), "Already-versioned export should not move files"),
		assert_true(FileAccess.file_exists(export_path), "Already-versioned entry HTML should stay in place"),
	])


func _release_slug(version: String) -> String:
	return "v%s" % version.replace(".", "_").replace("-", "_")


func _fresh_test_dir(label: String) -> String:
	var base := ProjectSettings.globalize_path("user://web_release_layout_%s" % label).replace("\\", "/")
	_remove_tree(base)
	var make_error := DirAccess.make_dir_recursive_absolute(base)
	if make_error != OK:
		push_error("Unable to create test dir %s: %s" % [base, error_string(make_error)])
	return base


func _write_file(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write test file: %s" % path)
		return
	file.store_string(content)
	file.close()


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var child := dir.get_next()
	while child != "":
		var child_path := path.path_join(child)
		if dir.current_is_dir():
			_remove_tree(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		child = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
