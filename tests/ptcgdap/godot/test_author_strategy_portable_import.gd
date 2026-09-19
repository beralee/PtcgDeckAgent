class_name TestAuthorStrategyPortableImport
extends TestBase

const ReaderPath := "res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageSourceReader.gd"
const InstallerScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageInstaller.gd")
const CatalogScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")
const MAX_BYTES := 16 * 1024 * 1024
const FIXTURE := "res://tests/ptcgdap/fixtures/author_strategy_packages/as_wp4/00-exact-mapped-shadow.ptcgai"


class TestStream extends RefCounted:
	var declared_length := 0
	var actual_length := 0
	var position := 0
	var read_count := 0
	var bytes_requested := 0
	var failure := OK

	func get_length() -> int:
		return declared_length

	func get_buffer(length: int) -> PackedByteArray:
		read_count += 1
		bytes_requested += length
		var result := PackedByteArray()
		result.resize(mini(length, maxi(0, actual_length - position)))
		position += result.size()
		return result

	func get_error() -> Error:
		return failure as Error

	func eof_reached() -> bool:
		return position >= actual_length


class LaneLoader extends RefCounted:
	var local_calls := 0
	var download_calls := 0

	func inspect_match_bytes(_bytes: PackedByteArray, _sha: String) -> Dictionary:
		local_calls += 1
		return {"ok": false, "error_code": "local_lane_reached"}

	func inspect_control_distributed_player_match_bytes(_bytes: PackedByteArray, _sha: String) -> Dictionary:
		download_calls += 1
		return {"ok": false, "error_code": "download_lane_reached"}


class TestCatalog extends RefCounted:
	func scan_startup() -> Dictionary:
		return {}


func _reader() -> Variant:
	return load(ReaderPath) if ResourceLoader.exists(ReaderPath) else null


func test_android_document_uri_is_opaque_and_desktop_extension_check_remains() -> String:
	var reader: Variant = _reader()
	if reader == null:
		return "portable source reader is missing"
	return run_checks([
		assert_eq(reader.classify_source("content://provider/document/42", "Android").get("kind"), "document_uri"),
		assert_false(reader.classify_source("content://provider/document/42", "Windows").get("ok", true)),
		assert_false(reader.classify_source("C:/downloads/strategy.zip", "Windows").get("ok", true)),
		assert_true(reader.classify_source("C:/downloads/中文 策略.PTCGAI", "Windows").get("ok", false)),
	])


func test_known_oversize_source_rejected_without_reading_any_bytes() -> String:
	var reader: Variant = _reader()
	if reader == null:
		return "portable source reader is missing"
	var source := TestStream.new()
	source.declared_length = MAX_BYTES + 1
	var result: Dictionary = reader.read_stream(source)
	return run_checks([
		assert_eq(result.get("error_code"), "package_resource_limit_exceeded"),
		assert_eq(source.read_count, 0),
		assert_false(result.has("archive_bytes")),
	])


func test_unknown_length_source_is_bounded_with_one_byte_overflow_probe() -> String:
	var reader: Variant = _reader()
	if reader == null:
		return "portable source reader is missing"
	var source := TestStream.new()
	source.actual_length = MAX_BYTES + 100
	var result: Dictionary = reader.read_stream(source)
	return run_checks([
		assert_eq(result.get("error_code"), "package_resource_limit_exceeded"),
		assert_eq(source.bytes_requested, MAX_BYTES + 1),
		assert_false(result.has("archive_bytes")),
	])


func test_read_failure_and_truncated_source_never_return_partial_archive() -> String:
	var reader: Variant = _reader()
	if reader == null:
		return "portable source reader is missing"
	var failed := TestStream.new()
	failed.actual_length = 4
	failed.failure = ERR_FILE_CANT_READ
	var truncated := TestStream.new()
	truncated.actual_length = 4
	truncated.declared_length = 12
	var failed_result: Dictionary = reader.read_stream(failed)
	var truncated_result: Dictionary = reader.read_stream(truncated)
	return run_checks([
		assert_eq(failed_result.get("error_code"), "package_file_read_failed"),
		assert_eq(truncated_result.get("error_code"), "package_file_read_failed"),
		assert_false(failed_result.has("archive_bytes")),
		assert_false(truncated_result.has("archive_bytes")),
	])


func test_canceled_capture_reads_nothing_and_exact_limit_is_accepted() -> String:
	var reader: Variant = _reader()
	if reader == null:
		return "portable source reader is missing"
	var canceled := TestStream.new()
	canceled.actual_length = 5
	var canceled_result: Dictionary = reader.read_stream(canceled, func() -> bool: return true)
	var boundary := TestStream.new()
	boundary.actual_length = MAX_BYTES
	var boundary_result: Dictionary = reader.read_stream(boundary)
	return run_checks([
		assert_eq(canceled_result.get("error_code"), "package_import_canceled"),
		assert_eq(canceled.read_count, 0),
		assert_true(boundary_result.get("ok", false)),
		assert_eq(boundary_result.get("archive_bytes", PackedByteArray()).size(), MAX_BYTES),
	])


func test_file_capture_preserves_original_archive_bytes() -> String:
	var reader: Variant = _reader()
	if reader == null:
		return "portable source reader is missing"
	var result: Dictionary = reader.read_source(FIXTURE)
	return run_checks([
		assert_true(result.get("ok", false)),
		assert_eq(result.get("archive_bytes"), FileAccess.get_file_as_bytes(FIXTURE)),
	])


func test_local_bytes_never_receive_marketplace_distribution_authority() -> String:
	var installer := InstallerScript.new()
	var catalog := CatalogScript.new()
	var exposes_local_bytes := catalog.has_method("install_local_bytes")
	catalog.free()
	if not installer.has_method("install_local_bytes"):
		return "local bytes installation entry is missing"
	var loader := LaneLoader.new()
	var fake_catalog := TestCatalog.new()
	var result: Dictionary = installer.call("install_local_bytes", fake_catalog, loader, PackedByteArray([1, 2, 3]))
	var invalid_download := installer.install_bytes(fake_catalog, loader, PackedByteArray([1, 2, 3]), {})
	return run_checks([
		assert_true(exposes_local_bytes),
		assert_eq(result.get("error_code"), "local_lane_reached"),
		assert_eq(loader.local_calls, 1),
		assert_eq(loader.download_calls, 0),
		assert_eq(invalid_download.get("error_code"), "package_download_identity_invalid"),
	])


func test_oversized_existing_archive_is_rejected_by_catalog_before_parsing() -> String:
	var path := "user://portable-import-oversized-%d.ptcgai" % Time.get_ticks_usec()
	var stream := FileAccess.open(path, FileAccess.WRITE)
	if stream == null:
		return "could not create isolated oversized archive"
	stream.seek(MAX_BYTES)
	stream.store_8(0)
	stream.close()
	var catalog := CatalogScript.new()
	var captured: Dictionary = catalog.call("_capture_path", path, "user", path.get_file())
	var installer := InstallerScript.new()
	var inspected_bytes: PackedByteArray = installer.call("_read_owned_archive_bytes", path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	catalog.free()
	return run_checks([
		assert_eq(captured.get("archive_error"), "package_resource_limit_exceeded"),
		assert_false(captured.has("archive_bytes")),
		assert_true(inspected_bytes.is_empty()),
	])
