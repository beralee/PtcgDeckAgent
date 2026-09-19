class_name TestStrategyHubImportLifecycle
extends TestBase

const HubScene = preload("res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn")
const ReadTaskScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageReadTask.gd")
const FIXTURE := "res://tests/ptcgdap/fixtures/author_strategy_packages/as_wp4/00-exact-mapped-shadow.ptcgai"


class FakeReadTask extends RefCounted:
	signal completed(result: Dictionary)
	var starts := 0
	var canceled := false

	func start(_source: String) -> Error:
		starts += 1
		return OK

	func cancel() -> void:
		canceled = true


class FakeLocalCatalog extends RefCounted:
	var imports: Array[PackedByteArray] = []

	func install_local_bytes(bytes: PackedByteArray) -> Dictionary:
		imports.append(bytes)
		return {"ok": false, "error_code": "package_archive_invalid"}


func _new_hub(task: RefCounted, catalog: RefCounted) -> Control:
	var hub := HubScene.instantiate() as Control
	hub.set("_skip_service_initialization_for_tests", true)
	hub.set("_package_install_catalog_override", catalog)
	hub.set("_local_package_read_task_override", task)
	(Engine.get_main_loop() as SceneTree).root.add_child(hub)
	await (Engine.get_main_loop() as SceneTree).process_frame
	hub.set("_local_package_picker_pending", true)
	return hub


func test_capture_completion_installs_exact_bytes_once_on_main_thread() -> String:
	var task := FakeReadTask.new()
	var catalog := FakeLocalCatalog.new()
	var hub := await _new_hub(task, catalog)
	hub.call("_on_local_package_file_selected", "content://provider/document/42")
	hub.call("_on_local_package_file_selected", "content://provider/document/duplicate")
	var bytes := PackedByteArray([1, 2, 3, 4])
	task.completed.emit({"ok": true, "archive_bytes": bytes})
	var checks: Array[String] = [
		assert_eq(task.starts, 1),
		assert_eq(catalog.imports.size(), 1),
		assert_eq(catalog.imports[0] if not catalog.imports.is_empty() else PackedByteArray(), bytes),
		assert_false(hub.get("_local_package_import_busy")),
	]
	hub.free()
	return run_checks(checks)


func test_cancel_discards_a_late_success_without_installing() -> String:
	var task := FakeReadTask.new()
	var catalog := FakeLocalCatalog.new()
	var hub := await _new_hub(task, catalog)
	hub.call("_on_local_package_file_selected", "content://provider/document/42")
	hub.call("_on_local_package_file_canceled")
	task.completed.emit({"ok": true, "archive_bytes": PackedByteArray([1])})
	var checks: Array[String] = [
		assert_true(task.canceled),
		assert_eq(catalog.imports.size(), 0),
		assert_false(hub.get("_local_package_import_busy")),
	]
	hub.free()
	return run_checks(checks)


func test_leaving_page_discards_a_late_success_without_installing() -> String:
	var task := FakeReadTask.new()
	var catalog := FakeLocalCatalog.new()
	var hub := await _new_hub(task, catalog)
	hub.call("_on_local_package_file_selected", "content://provider/document/42")
	hub.get_parent().remove_child(hub)
	task.completed.emit({"ok": true, "archive_bytes": PackedByteArray([1])})
	var checks: Array[String] = [assert_true(task.canceled), assert_eq(catalog.imports.size(), 0)]
	hub.free()
	return run_checks(checks)


func test_canceled_picker_ignores_a_late_selected_file() -> String:
	var task := FakeReadTask.new()
	var catalog := FakeLocalCatalog.new()
	var hub := await _new_hub(task, catalog)
	hub.call("_on_local_package_file_canceled")
	hub.call("_on_local_package_file_selected", "content://provider/document/42")
	var checks: Array[String] = [assert_eq(task.starts, 0), assert_eq(catalog.imports.size(), 0)]
	hub.free()
	return run_checks(checks)


func test_queued_page_close_discards_completion_before_tree_exit() -> String:
	var task := FakeReadTask.new()
	var catalog := FakeLocalCatalog.new()
	var hub := await _new_hub(task, catalog)
	hub.call("_on_local_package_file_selected", "content://provider/document/42")
	hub.queue_free()
	task.completed.emit({"ok": true, "archive_bytes": PackedByteArray([1])})
	await (Engine.get_main_loop() as SceneTree).process_frame
	return assert_eq(catalog.imports.size(), 0)


func test_read_failure_recovers_controls_and_never_calls_installer() -> String:
	var task := FakeReadTask.new()
	var catalog := FakeLocalCatalog.new()
	var hub := await _new_hub(task, catalog)
	hub.call("_on_local_package_file_selected", "content://provider/document/42")
	task.completed.emit({"ok": false, "error_code": "package_file_read_failed"})
	var checks: Array[String] = [
		assert_eq(catalog.imports.size(), 0),
		assert_false(hub.get("_local_package_import_busy")),
		assert_false((hub.get_node("%ImportLocalPackageButton") as Button).disabled),
	]
	hub.free()
	return run_checks(checks)


func test_unrelated_network_completion_does_not_unlock_pending_import() -> String:
	var task := FakeReadTask.new()
	var catalog := FakeLocalCatalog.new()
	var hub := await _new_hub(task, catalog)
	hub.call("_on_local_package_file_selected", "content://provider/document/42")
	hub.call("_set_busy", false)
	var checks: Array[String] = [
		assert_true((hub.get_node("%ImportLocalPackageButton") as Button).disabled),
		assert_true((hub.get_node("%OpenBattleSetupButton") as Button).disabled),
	]
	hub.call("_on_local_package_file_canceled")
	checks.append(assert_false((hub.get_node("%ImportLocalPackageButton") as Button).disabled))
	hub.free()
	return run_checks(checks)


func test_background_read_collects_bytes_and_cancellation_without_scene_owner() -> String:
	var task := ReadTaskScript.new()
	var start_error := task.start(FIXTURE)
	if start_error != OK:
		return "background capture could not start"
	var result: Dictionary = await task.completed
	var canceled := ReadTaskScript.new()
	canceled.cancel()
	canceled.start(FIXTURE)
	var canceled_result: Dictionary = await canceled.completed
	return run_checks([
		assert_true(result.get("ok", false)),
		assert_eq(result.get("archive_bytes"), FileAccess.get_file_as_bytes(FIXTURE)),
		assert_eq(canceled_result.get("error_code"), "package_import_canceled"),
		assert_false(canceled_result.has("archive_bytes")),
	])
