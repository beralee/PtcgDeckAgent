class_name TestLocalReplayRemovalService
extends TestBase

const SERVICE_PATH := "res://scripts/engine/LocalReplayRemovalService.gd"
const TEST_ROOT := "user://ptcgdap/tests/d125-replay-removal"
const NATIVE_ROOT := TEST_ROOT + "/native"
const PUBLIC_ROOT := TEST_ROOT + "/public"


func test_service_removes_native_replay_and_every_declared_public_copy_as_one_set() -> String:
	_clear_test_root()
	var script := load(SERVICE_PATH) as Script
	if script == null or not script.can_instantiate():
		return "LocalReplayRemovalService is missing"
	_write_file(NATIVE_ROOT + "/match-safe/match.json", JSON.stringify({
		"meta": {"mode": "vs_ai"},
	}))
	_write_file(NATIVE_ROOT + "/match-safe/detail.jsonl", "{}\n")
	_write_file(PUBLIC_ROOT + "/artifacts/public-safe.json", "{}")
	_write_file(PUBLIC_ROOT + "/index/public-safe.json", "{}")
	var service = script.new()
	if not service.has_method("set_roots_for_tests"):
		_clear_test_root()
		return "Replay removal service lacks isolated test roots"
	service.set_roots_for_tests(NATIVE_ROOT, PUBLIC_ROOT)
	var wrong: Dictionary = service.remove_native(
		"match-safe", NATIVE_ROOT + "/another-match", ["public-safe"]
	)
	var preserved_after_wrong := (
		DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(NATIVE_ROOT + "/match-safe"))
		and FileAccess.file_exists(PUBLIC_ROOT + "/artifacts/public-safe.json")
		and FileAccess.file_exists(PUBLIC_ROOT + "/index/public-safe.json")
	)
	var removed: Dictionary = service.remove_native(
		"match-safe", NATIVE_ROOT + "/match-safe", ["public-safe"]
	)
	var checks := run_checks([
		assert_false(bool(wrong.get("ok", true))),
		assert_eq(wrong.get("error_code"), "replay_remove_reference_invalid"),
		assert_true(preserved_after_wrong, "An invalid reference must not mutate any replay copy"),
		assert_true(bool(removed.get("ok", false)), str(removed)),
		assert_true(bool(removed.get("native_removed", false))),
		assert_eq(removed.get("public_removed_count"), 1),
		assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(NATIVE_ROOT + "/match-safe"))),
		assert_false(FileAccess.file_exists(PUBLIC_ROOT + "/artifacts/public-safe.json")),
		assert_false(FileAccess.file_exists(PUBLIC_ROOT + "/index/public-safe.json")),
	])
	_clear_test_root()
	return checks


func test_service_public_only_delete_is_exact_and_rejects_path_traversal() -> String:
	_clear_test_root()
	var script := load(SERVICE_PATH) as Script
	if script == null or not script.can_instantiate():
		return "LocalReplayRemovalService is missing"
	_write_file(PUBLIC_ROOT + "/artifacts/public-only.json", "{}")
	_write_file(PUBLIC_ROOT + "/index/public-only.json", "{}")
	var service = script.new()
	service.set_roots_for_tests(NATIVE_ROOT, PUBLIC_ROOT)
	var unsafe: Dictionary = service.remove_public("../public-only")
	var preserved_after_unsafe := FileAccess.file_exists(PUBLIC_ROOT + "/artifacts/public-only.json")
	var removed: Dictionary = service.remove_public("public-only")
	var checks := run_checks([
		assert_false(bool(unsafe.get("ok", true))),
		assert_eq(unsafe.get("error_code"), "replay_remove_reference_invalid"),
		assert_true(preserved_after_unsafe),
		assert_true(bool(removed.get("ok", false)), str(removed)),
		assert_false(bool(removed.get("native_removed", true))),
		assert_eq(removed.get("public_removed_count"), 1),
		assert_false(FileAccess.file_exists(PUBLIC_ROOT + "/artifacts/public-only.json")),
		assert_false(FileAccess.file_exists(PUBLIC_ROOT + "/index/public-only.json")),
	])
	_clear_test_root()
	return checks


func test_service_preflights_every_merged_copy_before_moving_native_replay() -> String:
	_clear_test_root()
	var script := load(SERVICE_PATH) as Script
	if script == null or not script.can_instantiate():
		return "LocalReplayRemovalService is missing"
	_write_file(NATIVE_ROOT + "/match-preflight/match.json", JSON.stringify({
		"meta": {"mode": "vs_author_strategy_ai"},
	}))
	_write_file(PUBLIC_ROOT + "/artifacts/public-incomplete.json", "{}")
	var service = script.new()
	service.set_roots_for_tests(NATIVE_ROOT, PUBLIC_ROOT)
	var removed: Dictionary = service.remove_native(
		"match-preflight",
		NATIVE_ROOT + "/match-preflight",
		["public-incomplete"]
	)
	var checks := run_checks([
		assert_false(bool(removed.get("ok", true))),
		assert_eq(removed.get("error_code"), "replay_remove_public_incomplete"),
		assert_true(DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(NATIVE_ROOT + "/match-preflight")
		), "Native replay must remain when any merged public copy fails preflight"),
		assert_true(FileAccess.file_exists(PUBLIC_ROOT + "/artifacts/public-incomplete.json")),
	])
	_clear_test_root()
	return checks


func _write_file(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _clear_test_root() -> void:
	_remove_tree(TEST_ROOT)


func _remove_tree(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir() and not directory.is_link(entry):
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)
