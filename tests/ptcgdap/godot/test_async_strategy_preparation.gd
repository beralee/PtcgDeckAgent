extends TestBase

const Catalog = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")
const Preparation = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyArchivePreparation.gd")
const Loader = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd")
const FIXTURE := "res://tests/ptcgdap/fixtures/author_strategy_packages/as_wp4/00-exact-mapped-shadow.ptcgai"

class ThreadlessCatalog extends Catalog:
	func _supports_preparation_thread() -> bool:
		return false

var _threadless_result := {}

func _capture_threadless(catalog: Node, record: Dictionary) -> void:
	_threadless_result = await catalog.request_match_handle_async(record.package_id, record.package_version, record.archive_sha256)

func test_threadless_platform_prepares_exact_archive_without_starting_a_thread() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var catalog := ThreadlessCatalog.new()
	tree.root.add_child(catalog)
	await tree.process_frame
	await tree.process_frame
	var report: Dictionary = catalog.rebuild_from_paths_for_test([{"archive_path": FIXTURE, "install_source": "built_in", "location_id": "threadless.ptcgai"}])
	var record: Dictionary = report.metadata_records[0]
	_threadless_result = {}
	_capture_threadless(catalog, record)
	var used_thread: bool = catalog._preparation_thread != null
	var deadline := Time.get_ticks_msec() + 10000
	while _threadless_result.is_empty() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	var checks := run_checks([
		assert_false(used_thread, "Web exports without thread support must never start Thread"),
		assert_true(_threadless_result.get("ok", false), str(_threadless_result)),
	])
	if _threadless_result.get("ok", false):
		checks = run_checks([checks, assert_true(_threadless_result.handle.validate_integrity())])
	catalog.queue_free()
	return checks

func test_async_capture_preserves_match_pins_and_rejects_changed_archive() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var catalog := Catalog.new()
	tree.root.add_child(catalog)
	await tree.process_frame
	await tree.process_frame
	var path := "user://performance-capture-test.ptcgai"
	var bytes := FileAccess.get_file_as_bytes(FIXTURE)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var report: Dictionary = catalog.rebuild_from_paths_for_test([{"archive_path": path, "install_source": "user", "location_id": "capture.ptcgai"}])
	var records: Array = report.get("metadata_records", [])
	if records.is_empty():
		catalog.queue_free()
		return "Fixture catalog failed"
	var record: Dictionary = records[0]
	var id := str(record.package_id)
	var version := str(record.package_version)
	var sha := str(record.archive_sha256)
	var sync_result: Dictionary = catalog.request_match_handle(id, version, sha)
	var frame_before := Engine.get_process_frames()
	var result: Dictionary = await catalog.request_match_handle_async(id, version, sha)
	var checks: Array[String] = [assert_true(result.get("ok", false)), assert_true(sync_result.get("ok", false)),
		assert_true(Engine.get_process_frames() - frame_before >= 2, "Background preparation must allow frames to advance")]
	if result.get("ok", false) and sync_result.get("ok", false):
		checks.append(assert_eq(result.handle.to_public_dict(), sync_result.handle.to_public_dict()))
		result.handle._payloads["deck/deck.csv"] = "tampered".to_utf8_buffer()
		checks.append(assert_false(result.handle.validate_integrity(), "Preparation must not bypass later integrity checks"))
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("changed".to_utf8_buffer())
	file.close()
	var rejected: Dictionary = await catalog.request_match_handle_async(id, version, sha)
	checks.append(assert_false(rejected.get("ok", true), "Captured archive must still match exact selection"))
	catalog.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return run_checks(checks)

func test_removing_catalog_during_preparation_cancels_and_allows_reentry() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var checks: Array[String] = []
	for catalog: Node in [Catalog.new(), ThreadlessCatalog.new()]:
		tree.root.add_child(catalog)
		await tree.process_frame
		await tree.process_frame
		var report: Dictionary = catalog.rebuild_from_paths_for_test([{"archive_path": FIXTURE, "install_source": "built_in", "location_id": "cancel.ptcgai"}])
		var record: Dictionary = report.metadata_records[0]
		_threadless_result = {}
		_capture_threadless(catalog, record)
		tree.root.remove_child(catalog)
		await tree.process_frame
		await tree.process_frame
		checks.append(assert_eq(_threadless_result.get("error_code", ""), "package_preparation_unavailable", "Leaving the tree must finish the awaiting caller with cancellation"))
		tree.root.add_child(catalog)
		var retry: Dictionary = await catalog.request_match_handle_async(record.package_id, record.package_version, record.archive_sha256)
		checks.append(assert_true(retry.get("ok", false), "Cancellation must release the pending guard: %s" % retry))
		catalog.queue_free()
	return run_checks(checks)

func test_prepared_loader_preserves_all_archive_and_signature_rejections() -> String:
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/ptcgdap/fixtures/author_strategy_packages/as_wp2/cases.json"))
	var loader := Loader.new()
	var checks: Array[String] = []
	var vectors: Array = fixtures.cases + fixtures.loader_cases
	checks.append(assert_eq(vectors.size(), 39, "All independent conformance vectors must run"))
	for case: Dictionary in vectors:
		var bytes := FileAccess.get_file_as_bytes(str(case.archive_path))
		loader.prewarm_archive(bytes)
		var actual := loader.inspect_bytes(bytes)
		checks.append(assert_eq(bool(actual.get("ok", false)), bool(case.expected_accepted), str(case.case_id)))
		checks.append(assert_eq(str(actual.get("error_code", "")),
			str(case.expected_error_code) if case.expected_error_code != null else "", str(case.case_id)))
		if actual.get("ok", false):
			checks.append(assert_eq(actual.metadata, loader._coerce_integral_numbers(case.expected_metadata), str(case.case_id)))
		checks.append(assert_true(loader._prepared_documents.size() <= 16, "Preparation cache stays bounded"))
	return run_checks(checks)
