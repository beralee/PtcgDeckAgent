class_name TestAuthorStrategyPackageCatalog
extends TestBase

const Ed25519Script = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageEd25519.gd")
const ZipScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageZip.gd")
const LoaderScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd")
const CatalogScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")
const InstallerScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageInstaller.gd")

const LIMITS := {
	"max_archive_bytes": 12582912,
	"max_uncompressed_bytes": 16777216,
	"max_entry_count": 16,
	"max_path_bytes": 128,
	"max_single_file_bytes": 8388608,
	"max_compression_ratio": 20,
}

const INSTALLABLE_FIXTURE := "res://tests/ptcgdap/fixtures/author_strategy_packages/as_wp4/00-exact-mapped-shadow.ptcgai"
const UNMAPPED_FIXTURE := "res://artifacts/ptcgdap/as_wp1/fixtures/valid_minimal.ptcgai"
const INVALID_FIXTURE := "res://artifacts/ptcgdap/as_wp1/fixtures/invalid_payload_hash.ptcgai"


class SyntheticProductionLoader extends RefCounted:
	var _inner: RefCounted = null

	func _init() -> void:
		_inner = load("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd").new()

	func inspect_bytes(archive_bytes: PackedByteArray, expected_archive_sha256: String = "") -> Dictionary:
		return _promote(_inner.call("inspect_bytes", archive_bytes, expected_archive_sha256))

	func inspect_match_bytes(archive_bytes: PackedByteArray, expected_archive_sha256: String = "") -> Dictionary:
		return _promote(_inner.call("inspect_match_bytes", archive_bytes, expected_archive_sha256))

	func _promote(result: Dictionary) -> Dictionary:
		if not bool(result.get("ok", false)):
			return result
		var promoted := result.duplicate(true)
		var metadata: Dictionary = promoted.get("metadata", {})
		metadata["signature_status"] = "production_trusted"
		metadata["execution_trusted"] = true
		metadata["signature_key_id"] = "product.release.synthetic"
		metadata["signature_scope"] = "production_release"
		promoted["metadata"] = metadata
		return promoted


class SyntheticReadyReleaseGate extends RefCounted:
	func evaluate_installed_package(metadata: Variant) -> Dictionary:
		if metadata is Dictionary \
			and metadata.get("execution_trusted") == true \
			and metadata.get("signature_scope") == "production_release" \
			and metadata.get("signature_key_id") == "product.release.synthetic":
			return {
				"accepted": true,
				"error_code": "",
				"player_start_allowed": true,
				"authority_source": "synthetic_fixed_product_release_approval",
			}
		return {"accepted": false, "error_code": "release_package_not_approved", "player_start_allowed": false}


class CountingInstallLoader extends RefCounted:
	var inner: RefCounted = null
	var metadata_scan_calls := 0

	func _init() -> void:
		inner = load("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd").new()

	func inspect_match_bytes(
		archive_bytes: PackedByteArray,
		expected_archive_sha256: String = ""
	) -> Dictionary:
		return inner.call("inspect_match_bytes", archive_bytes, expected_archive_sha256)

	func inspect_bytes(
		_archive_bytes: PackedByteArray,
		_expected_archive_sha256: String = ""
	) -> Dictionary:
		metadata_scan_calls += 1
		return {"ok": false, "error_code": "counting_loader_metadata_scan_forbidden"}


class CountingMetadataLoader extends RefCounted:
	var inner: RefCounted = null
	var metadata_scan_calls := 0

	func _init() -> void:
		inner = load("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd").new()

	func contract_report() -> Dictionary:
		return inner.call("contract_report")

	func inspect_bytes(
		archive_bytes: PackedByteArray,
		expected_archive_sha256: String = ""
	) -> Dictionary:
		metadata_scan_calls += 1
		return inner.call("inspect_bytes", archive_bytes, expected_archive_sha256)


class FastInstallCatalog extends RefCounted:
	var metadata: Dictionary = {}
	var resolve_calls := 0
	var scan_calls := 0

	func resolve_install_identity(
		_package_id: String,
		_package_version: String,
		_archive_sha256: String
	) -> Dictionary:
		resolve_calls += 1
		return {
			"ok": true,
			"error_code": "",
			"conflict": false,
			"user_installed": false,
			"built_in_installed": false,
		}

	func set_built_in_package_removed(_reference: Dictionary, _removed: bool) -> Dictionary:
		return {"ok": true, "error_code": "", "changed": false, "cleanup_pending": false}

	func scan_startup() -> Dictionary:
		scan_calls += 1
		var record := metadata.duplicate(true)
		record["install_sources"] = ["user"]
		return {"metadata_records": [record], "ready_records": [], "diagnostics": []}


func test_sha512_matches_standard_vectors() -> String:
	var empty := Ed25519Script.sha512_for_test(PackedByteArray()).hex_encode()
	var abc := Ed25519Script.sha512_for_test("abc".to_utf8_buffer()).hex_encode()
	return run_checks([
		assert_eq(empty, "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"),
		assert_eq(abc, "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"),
	])


func test_ed25519_verifies_rfc8032_vector_and_rejects_tamper() -> String:
	var public_key := "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a".hex_decode()
	var signature := ("e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155" +
		"5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b").hex_decode()
	var tampered := signature.duplicate()
	tampered[0] ^= 1
	return run_checks([
		assert_true(Ed25519Script.verify(public_key, PackedByteArray(), signature)),
		assert_false(Ed25519Script.verify(public_key, PackedByteArray(), tampered)),
		assert_false(Ed25519Script.verify(public_key.slice(0, 31), PackedByteArray(), signature)),
	])


func test_raw_zip_reader_accepts_sealed_golden_archive() -> String:
	var file := FileAccess.open("res://artifacts/ptcgdap/as_wp1/fixtures/valid_minimal.ptcgai", FileAccess.READ)
	if file == null:
		return "sealed golden archive is missing"
	var result: Dictionary = ZipScript.read(file.get_buffer(file.get_length()), LIMITS)
	return run_checks([
		assert_true(bool(result.get("ok", false)), str(result.get("error_code", ""))),
		assert_eq(result.get("entry_count"), 10),
		assert_true(result.get("members", {}).has("strategy_package.json")),
	])


func test_loader_accepts_golden_and_rejects_sealed_tamper_fixtures() -> String:
	var loader := LoaderScript.new()
	var valid := loader.inspect_path("res://artifacts/ptcgdap/as_wp1/fixtures/valid_minimal.ptcgai")
	if not bool(valid.get("ok", false)):
		var debug_file := FileAccess.open("res://artifacts/ptcgdap/as_wp1/fixtures/valid_minimal.ptcgai", FileAccess.READ)
		var debug_zip: Dictionary = ZipScript.read(debug_file.get_buffer(debug_file.get_length()), LIMITS)
		var debug_members: Dictionary = debug_zip.get("members", {})
		var debug_results := []
		for pair in [["strategy_package.json", "strategy_package"], ["files.sha256.json", "files_manifest"], ["signature.json", "signature"]]:
			debug_results.append([pair[1], loader._strict_document(debug_members[pair[0]], pair[1], "debug")])
		return "valid loader failed %s; documents=%s" % [valid, debug_results]
	var signature := loader.inspect_path("res://artifacts/ptcgdap/as_wp1/fixtures/invalid_signature_tampered.ptcgai")
	var payload := loader.inspect_path("res://artifacts/ptcgdap/as_wp1/fixtures/invalid_payload_hash.ptcgai")
	return run_checks([
		assert_true(bool(loader.contract_report().get("ok", false)), str(loader.contract_report())),
		assert_true(bool(valid.get("ok", false)), str(valid)),
		assert_eq(valid.get("metadata", {}).get("archive_sha256"), "C3251A725E933341D17A129AD065F3D4E836CF7EE886693F51528366A1A68392"),
		assert_eq(valid.get("metadata", {}).get("execution_trusted"), false),
		assert_eq(signature.get("error_code"), "package_signature_untrusted"),
		assert_eq(payload.get("error_code"), "package_file_hash_mismatch"),
	])


func test_loader_shape_guards_match_as_wp1_schema_edges() -> String:
	var loader := LoaderScript.new()
	var valid_ir := {
		"schema_version": 1,
		"profile_id": "ptcgdap-restricted-base-graph-ir-p4-wp2-v1",
		"graph_id": "test.graph",
		"entry_node_id": "a",
		"required_capabilities": ["a", "b", "c", "d"],
		"nodes": [],
	}
	for index in range(6):
		valid_ir["nodes"].append({"node_id": "n%s" % index, "operator": "op", "owner": "base", "config": {}, "next_node_ids": []})
	var duplicate_capabilities: Dictionary = valid_ir.duplicate(true)
	duplicate_capabilities["required_capabilities"] = ["a", "b", "c", "a"]
	var invalid_capability_type: Dictionary = valid_ir.duplicate(true)
	invalid_capability_type["required_capabilities"] = ["a", "b", "c", 4]
	var invalid_next: Dictionary = valid_ir.duplicate(true)
	invalid_next["nodes"][0]["next_node_ids"] = [""]
	var valid_config := {"document_type": "author_policy_config_v1", "schema_version": 1, "config_profile_id": "ptcgdap-author-policy-config-v1", "values": {"label": "local", "depth_2": 2, "enabled": true, "optional": null}}
	var nested_config: Dictionary = valid_config.duplicate(true)
	nested_config["values"]["nested"] = {}
	var invalid_config_key: Dictionary = valid_config.duplicate(true)
	invalid_config_key["values"]["Bad-Key"] = 1
	return run_checks([
		assert_true(loader._valid_semver("1.2.3")),
		assert_true(loader._valid_semver("1.2.3-rc.1-A")),
		assert_true(loader._valid_semver("12345678901234567890.0.1")),
		assert_false(loader._valid_semver("1.2.3-")),
		assert_false(loader._valid_semver("1.2.3+build")),
		assert_false(loader._valid_semver("01.2.3")),
		assert_true(loader._valid_manifest_path("policy/policy_ir.json")),
		assert_false(loader._valid_manifest_path("policy//policy_ir.json")),
		assert_false(loader._valid_manifest_path("policy/../secret")),
		assert_false(loader._valid_manifest_path("_policy/file.json")),
		assert_true(loader._valid_policy_ir_shape(valid_ir)),
		assert_false(loader._valid_policy_ir_shape(duplicate_capabilities)),
		assert_false(loader._valid_policy_ir_shape(invalid_capability_type)),
		assert_false(loader._valid_policy_ir_shape(invalid_next)),
		assert_true(loader._valid_config_shape(valid_config)),
		assert_false(loader._valid_config_shape(nested_config)),
		assert_false(loader._valid_config_shape(invalid_config_key)),
		assert_false(loader._valid_adapter_shape({"schema_version": 1, "adapter_id": "test.adapter", "adapter_version": 1, "rules": ["not-an-object"]})),
	])


func test_all_thirty_shared_archive_vectors_match_python_reference() -> String:
	var file := FileAccess.open("res://tests/ptcgdap/fixtures/author_strategy_packages/as_wp2/cases.json", FileAccess.READ)
	if file == null:
		return "shared AS-WP2 fixture manifest is missing"
	var fixtures: Variant = JSON.parse_string(file.get_as_text())
	if not fixtures is Dictionary or fixtures.get("case_count") != 30.0:
		return "shared AS-WP2 fixture manifest is invalid"
	var loader := LoaderScript.new()
	var failures: Array[String] = []
	for case_value in fixtures.get("cases", []):
		var case: Dictionary = case_value
		var actual: Dictionary = loader.inspect_path(str(case.get("archive_path", "")))
		if bool(actual.get("ok", false)) != bool(case.get("expected_accepted", false)):
			failures.append("%s acceptance differs: %s" % [case.get("case_id"), actual])
			continue
		if str(actual.get("error_code", "")) != str(case.get("expected_error_code") if case.get("expected_error_code") != null else ""):
			failures.append("%s diagnostic differs: %s" % [case.get("case_id"), actual])
			continue
		var expected_metadata: Variant = loader._coerce_integral_numbers(case.get("expected_metadata"))
		if bool(actual.get("ok", false)) and actual.get("metadata") != expected_metadata:
			failures.append("%s metadata differs actual=%s expected=%s" % [case.get("case_id"), actual.get("metadata"), expected_metadata])
	return "\n".join(failures)


func test_extended_loader_vectors_match_python_reference() -> String:
	var file := FileAccess.open("res://tests/ptcgdap/fixtures/author_strategy_packages/as_wp2/cases.json", FileAccess.READ)
	if file == null:
		return "shared AS-WP2 fixture manifest is missing"
	var fixtures: Variant = JSON.parse_string(file.get_as_text())
	if not fixtures is Dictionary or fixtures.get("loader_case_count") != 9.0:
		return "extended AS-WP2 loader fixture manifest is invalid"
	var loader := LoaderScript.new()
	var failures: Array[String] = []
	for case_value in fixtures.get("loader_cases", []):
		var case: Dictionary = case_value
		var actual: Dictionary = loader.inspect_path(str(case.get("archive_path", "")))
		if bool(actual.get("ok", false)) != bool(case.get("expected_accepted", false)):
			failures.append("%s acceptance differs: %s" % [case.get("case_id"), actual])
			continue
		if str(actual.get("error_code", "")) != str(case.get("expected_error_code") if case.get("expected_error_code") != null else ""):
			failures.append("%s diagnostic differs: %s" % [case.get("case_id"), actual])
			continue
		var expected_metadata: Variant = loader._coerce_integral_numbers(case.get("expected_metadata"))
		if bool(actual.get("ok", false)) and actual.get("metadata") != expected_metadata:
			failures.append("%s metadata differs actual=%s expected=%s" % [case.get("case_id"), actual.get("metadata"), expected_metadata])
	return "\n".join(failures)


func test_shared_catalog_vectors_match_python_reference() -> String:
	var file := FileAccess.open("res://tests/ptcgdap/fixtures/author_strategy_packages/as_wp2/cases.json", FileAccess.READ)
	if file == null:
		return "shared AS-WP2 fixture manifest is missing"
	var fixtures: Variant = JSON.parse_string(file.get_as_text())
	if not fixtures is Dictionary or fixtures.get("catalog_case_count") != 4.0:
		return "shared AS-WP2 catalog fixture manifest is invalid"
	var failures: Array[String] = []
	for case_value in fixtures.get("catalog_cases", []):
		var case: Dictionary = case_value
		var candidates: Array[Dictionary] = []
		for candidate_value in case.get("candidates", []):
			var candidate: Dictionary = candidate_value
			var archive := FileAccess.open(str(candidate.get("archive_path", "")), FileAccess.READ)
			if archive == null:
				failures.append("%s fixture archive is missing" % case.get("case_id"))
				continue
			candidates.append({
				"install_source": candidate.get("install_source"),
				"location_id": candidate.get("location_id"),
				"archive_bytes": archive.get_buffer(archive.get_length()),
			})
		var catalog := CatalogScript.new()
		var actual: Dictionary = catalog.rebuild_from_captured_for_test(candidates)
		actual.erase("scan_generation")
		if actual != _normalize_json_integers(case.get("expected")):
			failures.append("%s catalog projection differs: %s" % [case.get("case_id"), actual])
		catalog.free()
	return "\n".join(failures)


func test_catalog_is_metadata_only_copy_safe_and_conflicts_fail_closed() -> String:
	var valid_file := FileAccess.open("res://artifacts/ptcgdap/as_wp1/fixtures/valid_minimal.ptcgai", FileAccess.READ)
	var pretty_file := FileAccess.open("res://artifacts/ptcgdap/as_wp1/fixtures/valid_manifest_whitespace.ptcgai", FileAccess.READ)
	var invalid_file := FileAccess.open("res://artifacts/ptcgdap/as_wp1/fixtures/invalid_payload_hash.ptcgai", FileAccess.READ)
	var valid := valid_file.get_buffer(valid_file.get_length())
	var pretty := pretty_file.get_buffer(pretty_file.get_length())
	var invalid := invalid_file.get_buffer(invalid_file.get_length())
	var catalog := CatalogScript.new()
	var exact_duplicate := catalog.rebuild_from_captured_for_test([
		{"install_source": "built_in", "location_id": "a.ptcgai", "archive_bytes": valid},
		{"install_source": "user", "location_id": "b.ptcgai", "archive_bytes": valid},
		{"install_source": "user", "location_id": "bad.ptcgai", "archive_bytes": invalid},
	])
	var public_copy: Array[Dictionary] = catalog.list_metadata_records()
	public_copy[0]["author"]["display_name"] = "mutated"
	var second := catalog.rebuild_from_captured_for_test([
		{"install_source": "built_in", "location_id": "a.ptcgai", "archive_bytes": valid},
	])
	var conflict := catalog.rebuild_from_captured_for_test([
		{"install_source": "built_in", "location_id": "a.ptcgai", "archive_bytes": valid},
		{"install_source": "user", "location_id": "b.ptcgai", "archive_bytes": pretty},
	])
	var conflict_codes: Array = conflict.get("diagnostics", []).map(func(item: Dictionary) -> Variant: return item.get("error_code"))
	var final_audit: Dictionary = catalog.audit_snapshot()
	var final_ready: Array[Dictionary] = catalog.list_ready_records()
	var checks := run_checks([
		assert_eq(exact_duplicate.get("metadata_records", []).size(), 1),
		assert_eq(exact_duplicate.get("ready_records"), []),
		assert_eq(exact_duplicate.get("metadata_records", [])[0].get("install_sources"), ["built_in", "user"]),
		assert_eq(exact_duplicate.get("diagnostics", [])[0].get("error_code"), "package_file_hash_mismatch"),
		assert_eq(second.get("metadata_records", [])[0].get("author", {}).get("display_name"), "Fixture Author"),
		assert_true(int(final_audit.get("cache_hits", 0)) >= 1),
		assert_eq(conflict.get("metadata_records"), []),
		assert_true("package_identity_conflict" in conflict_codes),
		assert_eq(final_ready, []),
		assert_eq(final_audit.get("match_authority"), false),
	])
	catalog.free()
	return checks


func test_catalog_persistent_cache_reuses_validated_metadata_without_granting_match_authority() -> String:
	var source := FileAccess.open("res://artifacts/ptcgdap/as_wp1/fixtures/valid_minimal.ptcgai", FileAccess.READ)
	if source == null:
		return "sealed golden archive is missing"
	var archive_bytes := source.get_buffer(source.get_length())
	var cache_path := "user://ptcgdap/tests/author_strategy_catalog_cache.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_path.get_base_dir()))
	if FileAccess.file_exists(cache_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_path))
	var first := CatalogScript.new()
	first.set_persistent_cache_path_for_tests(cache_path)
	var first_report: Dictionary = first.rebuild_from_captured_for_test([{
		"install_source": "built_in",
		"location_id": "cached.ptcgai",
		"archive_bytes": archive_bytes,
	}])
	var second := CatalogScript.new()
	second.set_persistent_cache_path_for_tests(cache_path)
	var second_report: Dictionary = second.rebuild_from_captured_for_test([{
		"install_source": "built_in",
		"location_id": "cached.ptcgai",
		"archive_bytes": archive_bytes,
	}])
	var second_audit: Dictionary = second.audit_snapshot()
	var checks := run_checks([
		assert_true(FileAccess.file_exists(cache_path), "Validated metadata should persist across process-style catalog instances"),
		assert_eq(first_report.get("metadata_records"), second_report.get("metadata_records"), "Persistent metadata must preserve the exact public catalog projection"),
		assert_true(int(second_audit.get("persistent_cache_hits", 0)) >= 1, "The second catalog should reuse the persistent cache"),
		assert_eq(second_report.get("ready_records"), [], "A persistent metadata cache must not invent player-ready authority"),
		assert_eq(second_audit.get("match_authority"), false),
	])
	first.free()
	second.free()
	if FileAccess.file_exists(cache_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_path))
	return checks


func test_startup_location_cache_skips_unchanged_archive_deep_inspection() -> String:
	var source_bytes := FileAccess.get_file_as_bytes(
		"res://artifacts/ptcgdap/as_wp1/fixtures/valid_minimal.ptcgai"
	)
	if source_bytes.is_empty():
		return "sealed golden archive is missing"
	var root := "user://ptcgdap/tests/d162-startup-location-cache"
	var cache_path := root.path_join("catalog-cache.json")
	var archive_path := root.path_join("cached-path.ptcgai")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	for path: String in [cache_path, archive_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var archive := FileAccess.open(archive_path, FileAccess.WRITE)
	if archive == null:
		return "could not create startup cache fixture"
	archive.store_buffer(source_bytes)
	archive.close()

	var first := CatalogScript.new()
	first.set_persistent_cache_path_for_tests(cache_path)
	if not first.has_method("rebuild_from_paths_for_test"):
		first.free()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(archive_path))
		return "catalog does not expose the D162 path-cache test seam"
	var source := [{
		"install_source": "user",
		"location_id": "cached-path.ptcgai",
		"archive_path": archive_path,
	}]
	var first_report: Dictionary = first.call("rebuild_from_paths_for_test", source)
	var first_audit: Dictionary = first.audit_snapshot()
	first.free()

	var second := CatalogScript.new()
	second.set_persistent_cache_path_for_tests(cache_path)
	var counting_loader := CountingMetadataLoader.new()
	second._loader = counting_loader
	var second_report: Dictionary = second.call("rebuild_from_paths_for_test", source)
	var second_audit: Dictionary = second.audit_snapshot()
	var checks := run_checks([
		assert_eq(first_report.get("metadata_records"), second_report.get("metadata_records")),
		assert_eq(counting_loader.metadata_scan_calls, 0, "An unchanged location hit must not reopen and deeply inspect the archive"),
		assert_eq(first_audit.get("startup_location_cache_hits", 0), 0),
		assert_eq(second_audit.get("startup_location_cache_hits", 0), 1),
		assert_eq(second_audit.get("startup_location_cache_misses", 0), 0),
		assert_eq(second_audit.get("match_authority"), false),
		assert_eq(second_audit.get("startup_cache_authority"), false),
		assert_true(second.startup_location_cache_enabled("cached_v2")),
		assert_false(second.startup_location_cache_enabled("deep_scan_v1")),
		assert_eq(second_audit.get("startup_profile_environment"), "PTCGDAP_AUTHOR_CATALOG_STARTUP_PROFILE"),
	])
	second.free()
	for path: String in [cache_path, archive_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return checks


func test_bundled_startup_cache_covers_all_built_in_archives_without_deep_inspection() -> String:
	var sources: Array = []
	var filenames := DirAccess.get_files_at("res://data/ptcgdap/author_strategy_packages")
	filenames.sort()
	for filename: String in filenames:
		if not filename.ends_with(".ptcgai"):
			continue
		sources.append({
			"install_source": "built_in",
			"location_id": filename,
			"archive_path": "res://data/ptcgdap/author_strategy_packages".path_join(filename),
		})
	var cache_path := "user://ptcgdap/tests/d162-empty-user-cache.json"
	if FileAccess.file_exists(cache_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_path))
	var catalog := CatalogScript.new()
	catalog.set_persistent_cache_path_for_tests(cache_path)
	var counting_loader := CountingMetadataLoader.new()
	catalog._loader = counting_loader
	var report: Dictionary = catalog.call("rebuild_from_paths_for_test", sources)
	var audit: Dictionary = catalog.audit_snapshot()
	var checks := run_checks([
		assert_true(not sources.is_empty(), "The built-in package directory should not be empty"),
		assert_eq(counting_loader.metadata_scan_calls, 0, "A clean install must use the generated built-in metadata cache"),
		assert_eq(audit.get("startup_location_cache_hits", 0), sources.size()),
		assert_eq(audit.get("startup_location_cache_misses", 0), 0),
		assert_eq(audit.get("bundled_location_cache_hits", 0), sources.size()),
		assert_true(not report.get("metadata_records", []).is_empty()),
		assert_eq(audit.get("startup_cache_authority"), false),
		assert_eq(audit.get("match_time_archive_revalidation"), true),
	])
	catalog.free()
	if FileAccess.file_exists(cache_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_path))
	return checks


func test_bundled_startup_cache_hashes_bind_the_exact_built_in_archives() -> String:
	var cache_path := "res://data/ptcgdap/author_strategy_catalog_cache.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(cache_path))
	if not (parsed is Dictionary):
		return "bundled startup cache is missing or invalid"
	var cache := parsed as Dictionary
	var entries: Dictionary = cache.get("entries", {})
	var locations: Dictionary = cache.get("locations", {})
	var expected_locations := {}
	var failures: Array[String] = []
	var filenames := DirAccess.get_files_at("res://data/ptcgdap/author_strategy_packages")
	for filename: String in filenames:
		if not filename.ends_with(".ptcgai"):
			continue
		var location_key := "built_in\n%s" % filename
		expected_locations[location_key] = true
		var location: Dictionary = locations.get(location_key, {})
		var archive_path := "res://data/ptcgdap/author_strategy_packages".path_join(filename)
		var archive_bytes := FileAccess.get_file_as_bytes(archive_path)
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(archive_bytes)
		var actual_sha := context.finish().hex_encode().to_upper()
		if location.is_empty():
			failures.append("missing location %s" % filename)
			continue
		if int(location.get("archive_size", -1)) != archive_bytes.size():
			failures.append("size drift %s" % filename)
		if str(location.get("archive_sha256", "")) != actual_sha:
			failures.append("hash drift %s" % filename)
		if not entries.has(actual_sha):
			failures.append("metadata missing %s" % filename)
	for location_key: Variant in locations.keys():
		if str(location_key).begins_with("built_in\n") and not expected_locations.has(location_key):
			failures.append("stale location %s" % str(location_key))
	return run_checks([
		assert_eq(cache.get("document_type"), "author_strategy_catalog_metadata_cache_v2"),
		assert_eq(int(cache.get("schema_version", 0)), 2),
		assert_eq(failures, []),
	])


func test_user_writable_cache_cannot_override_bundled_metadata_for_identical_bytes() -> String:
	var bundled: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/ptcgdap/author_strategy_catalog_cache.json"
	))
	if not (bundled is Dictionary):
		return "bundled startup cache is missing or invalid"
	var tampered := (bundled as Dictionary).duplicate(true)
	var entry_hashes := (tampered.get("entries", {}) as Dictionary).keys()
	entry_hashes.sort()
	if entry_hashes.is_empty():
		return "bundled startup cache has no metadata entries"
	var archive_sha := str(entry_hashes[0])
	var original_metadata: Dictionary = (bundled as Dictionary).get("entries", {}).get(archive_sha, {})
	var tampered_metadata: Dictionary = tampered.get("entries", {}).get(archive_sha, {})
	tampered_metadata["author"]["display_name"] = "tampered-user-cache-author"
	var selected_location: Dictionary = {}
	for value: Variant in (tampered.get("locations", {}) as Dictionary).values():
		if value is Dictionary and str((value as Dictionary).get("archive_sha256", "")) == archive_sha:
			selected_location = (value as Dictionary).duplicate(true)
			break
	if selected_location.is_empty():
		return "bundled startup cache has no location for its first metadata entry"
	var cache_path := "user://ptcgdap/tests/d162-tampered-user-cache.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_path.get_base_dir()))
	var cache_file := FileAccess.open(cache_path, FileAccess.WRITE)
	if cache_file == null:
		return "could not write tampered user cache fixture"
	cache_file.store_string(JSON.stringify(tampered) + "\n")
	cache_file.close()
	var catalog := CatalogScript.new()
	catalog.set_persistent_cache_path_for_tests(cache_path)
	var report: Dictionary = catalog.call("rebuild_from_paths_for_test", [{
		"install_source": selected_location.get("install_source"),
		"location_id": selected_location.get("location_id"),
		"archive_path": selected_location.get("archive_path"),
	}])
	var records: Array = report.get("metadata_records", [])
	var actual_author := ""
	if not records.is_empty():
		actual_author = str(records[0].get("author", {}).get("display_name", ""))
	var checks := run_checks([
		assert_eq(records.size(), 1),
		assert_eq(actual_author, str(original_metadata.get("author", {}).get("display_name", ""))),
		assert_true(actual_author != "tampered-user-cache-author"),
		assert_eq(catalog.audit_snapshot().get("startup_cache_authority"), false),
	])
	catalog.free()
	if FileAccess.file_exists(cache_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_path))
	return checks


func _normalize_json_integers(value: Variant) -> Variant:
	if value is float and value == floor(value):
		return int(value)
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_normalize_json_integers(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = _normalize_json_integers(value[key])
		return result
	return value


func test_fixed_user_root_scan_discovers_metadata_without_ready_authority() -> String:
	var source := FileAccess.open("res://artifacts/ptcgdap/as_wp1/fixtures/valid_minimal.ptcgai", FileAccess.READ)
	if source == null:
		return "source fixture is missing"
	var user_root := "user://ptcgdap/author_strategy_packages"
	var user := DirAccess.open("user://")
	user.make_dir_recursive("ptcgdap/author_strategy_packages")
	var target_path := user_root.path_join("as-wp2-fixed-root-test.ptcgai")
	var target := FileAccess.open(target_path, FileAccess.WRITE)
	if target == null:
		return "could not create isolated user-root fixture"
	target.store_buffer(source.get_buffer(source.get_length()))
	target = null
	var catalog := CatalogScript.new()
	var report := catalog.scan_startup()
	var audit := catalog.audit_snapshot()
	DirAccess.remove_absolute(target_path)
	var user_records: Array = report.get("metadata_records", []).filter(func(record: Dictionary) -> bool: return record.get("install_source") == "user")
	var checks := run_checks([
		assert_eq(user_records.size(), 1),
		assert_eq(user_records[0].get("install_source"), "user"),
		assert_eq(user_records[0].get("status"), "metadata_only"),
		assert_eq(report.get("ready_records"), []),
		assert_eq(audit.get("ready_record_count"), 0),
		assert_true(typeof(audit.get("last_scan_elapsed_usec")) == TYPE_INT),
		assert_true(int(audit.get("last_scan_elapsed_usec", -1)) >= 0),
		assert_eq(audit.get("execution_authority"), false),
		assert_eq(audit.get("live_consumer"), false),
	])
	catalog.free()
	return checks


func test_local_package_install_validates_deck_writes_atomically_and_refreshes_catalog() -> String:
	var loader := LoaderScript.new()
	var inspected: Dictionary = loader.inspect_path(INSTALLABLE_FIXTURE)
	if not bool(inspected.get("ok", false)):
		return "installable fixture is invalid: %s" % inspected
	var archive_sha := str(inspected.get("metadata", {}).get("archive_sha256", ""))
	var destination := "user://ptcgdap/author_strategy_packages/package-%s.ptcgai" % archive_sha.to_lower()
	if FileAccess.file_exists(destination):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))
	var catalog := CatalogScript.new()
	if not catalog.has_method("install_from_local_path"):
		catalog.free()
		return "catalog does not expose install_from_local_path"
	var source_path := ProjectSettings.globalize_path(INSTALLABLE_FIXTURE)
	var first: Dictionary = catalog.call("install_from_local_path", source_path)
	var second: Dictionary = catalog.call("install_from_local_path", source_path)
	var installed_bytes := FileAccess.get_file_as_bytes(destination) if FileAccess.file_exists(destination) else PackedByteArray()
	var source_bytes := FileAccess.get_file_as_bytes(INSTALLABLE_FIXTURE)
	var records: Array = catalog.list_metadata_records().filter(func(record: Dictionary) -> bool:
		return record.get("package_id") == "test.fixture.mapped-shadow"
	)
	var temp_files: Array[String] = []
	var user_root := DirAccess.open("user://ptcgdap/author_strategy_packages")
	if user_root != null:
		for filename: String in user_root.get_files():
			if filename.begins_with(".ptcgdap-author-install-"):
				temp_files.append(filename)
	var checks := run_checks([
		assert_true(bool(first.get("ok", false)), str(first)),
		assert_false(bool(first.get("already_installed", true))),
		assert_eq(first.get("installed_path"), destination),
		assert_true(bool(second.get("ok", false)), str(second)),
		assert_true(bool(second.get("already_installed", false))),
		assert_eq(installed_bytes, source_bytes, "The original archive bytes must be copied exactly"),
		assert_eq(records.size(), 1, "A successful import must be visible without restarting the game"),
		assert_true("user" in records[0].get("install_sources", [])),
		assert_eq(temp_files, [], "Atomic install must not leave temporary files behind"),
	])
	if FileAccess.file_exists(destination):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))
	catalog.scan_startup()
	catalog.free()
	return checks


func test_downloaded_package_install_requires_exact_server_release_identity() -> String:
	var loader := LoaderScript.new()
	var archive_bytes := FileAccess.get_file_as_bytes(INSTALLABLE_FIXTURE)
	var inspected: Dictionary = loader.inspect_path(INSTALLABLE_FIXTURE)
	if not bool(inspected.get("ok", false)):
		return "installable fixture is invalid: %s" % inspected
	var metadata: Dictionary = inspected.get("metadata", {})
	var archive_sha := str(metadata.get("archive_sha256", ""))
	var expected := {
		"package_id": metadata.get("package_id"),
		"package_version": metadata.get("package_version"),
		"archive_sha256": archive_sha,
		"manifest_canonical_sha256": metadata.get("manifest_canonical_sha256"),
	}
	var destination := "user://ptcgdap/author_strategy_packages/package-%s.ptcgai" % archive_sha.to_lower()
	if FileAccess.file_exists(destination):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))
	var catalog := CatalogScript.new()
	if not catalog.has_method("install_from_bytes"):
		catalog.free()
		return "catalog does not expose install_from_bytes"
	var wrong := expected.duplicate(true)
	wrong["archive_sha256"] = "F".repeat(64)
	var rejected: Dictionary = catalog.call("install_from_bytes", archive_bytes, wrong)
	var first: Dictionary = catalog.call("install_from_bytes", archive_bytes, expected)
	var second: Dictionary = catalog.call("install_from_bytes", archive_bytes, expected)
	var installed_bytes := FileAccess.get_file_as_bytes(destination) if FileAccess.file_exists(destination) else PackedByteArray()
	var checks := run_checks([
		assert_false(bool(rejected.get("ok", true))),
		assert_eq(rejected.get("error_code"), "package_download_identity_mismatch"),
		assert_true(bool(first.get("ok", false)), str(first)),
		assert_false(bool(first.get("already_installed", true))),
		assert_true(bool(second.get("already_installed", false))),
		assert_eq(installed_bytes, archive_bytes),
	])
	if FileAccess.file_exists(destination):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))
	catalog.scan_startup()
	catalog.free()
	return checks


func test_downloaded_install_resolves_identity_from_catalog_without_reinspecting_every_archive() -> String:
	var archive_bytes := FileAccess.get_file_as_bytes(INSTALLABLE_FIXTURE)
	var real_loader := LoaderScript.new()
	var inspected: Dictionary = real_loader.inspect_match_bytes(archive_bytes)
	if not bool(inspected.get("ok", false)):
		return "installable fixture is invalid: %s" % inspected
	var metadata: Dictionary = inspected.get("metadata", {})
	var archive_sha := str(metadata.get("archive_sha256", ""))
	var destination := "user://ptcgdap/author_strategy_packages/package-%s.ptcgai" % archive_sha.to_lower()
	if FileAccess.file_exists(destination):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))
	var loader := CountingInstallLoader.new()
	var catalog := FastInstallCatalog.new()
	catalog.metadata = metadata.duplicate(true)
	var installer := InstallerScript.new()
	var result: Dictionary = installer.install_bytes(catalog, loader, archive_bytes, {
		"package_id": metadata.get("package_id"),
		"package_version": metadata.get("package_version"),
		"archive_sha256": archive_sha,
		"manifest_canonical_sha256": metadata.get("manifest_canonical_sha256"),
	})
	var checks := run_checks([
		assert_true(bool(result.get("ok", false)), str(result)),
		assert_eq(catalog.resolve_calls, 1, "Catalog metadata must own identity resolution"),
		assert_eq(loader.metadata_scan_calls, 0, "Import must not deep-inspect every installed archive"),
		assert_eq(catalog.scan_calls, 1, "Post-write catalog verification remains required"),
	])
	if FileAccess.file_exists(destination):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))
	return checks


func test_local_package_install_rejects_bad_format_and_unmapped_cards_without_residue() -> String:
	var catalog := CatalogScript.new()
	if not catalog.has_method("install_from_local_path"):
		catalog.free()
		return "catalog does not expose install_from_local_path"
	var before := _user_package_filenames()
	var invalid: Dictionary = catalog.call(
		"install_from_local_path", ProjectSettings.globalize_path(INVALID_FIXTURE)
	)
	var unmapped: Dictionary = catalog.call(
		"install_from_local_path", ProjectSettings.globalize_path(UNMAPPED_FIXTURE)
	)
	var after := _user_package_filenames()
	var checks := run_checks([
		assert_false(bool(invalid.get("ok", true))),
		assert_eq(invalid.get("error_code"), "package_file_hash_mismatch"),
		assert_false(bool(unmapped.get("ok", true))),
		assert_eq(unmapped.get("error_code"), "package_deck_unmapped"),
		assert_eq(after, before, "Rejected imports must not create package or temporary files"),
	])
	catalog.free()
	return checks


func test_local_package_remove_uses_exact_identity_and_removes_every_user_copy() -> String:
	var loader := LoaderScript.new()
	var inspected: Dictionary = loader.inspect_path(INSTALLABLE_FIXTURE)
	if not bool(inspected.get("ok", false)):
		return "installable fixture is invalid: %s" % inspected
	var metadata: Dictionary = inspected.get("metadata", {})
	var archive_sha := str(metadata.get("archive_sha256", ""))
	var destination := "user://ptcgdap/author_strategy_packages/package-%s.ptcgai" % archive_sha.to_lower()
	if FileAccess.file_exists(destination):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))
	var catalog := CatalogScript.new()
	if not catalog.has_method("remove_user_package"):
		catalog.free()
		return "catalog does not expose remove_user_package"
	var installed: Dictionary = catalog.install_from_local_path(
		ProjectSettings.globalize_path(INSTALLABLE_FIXTURE)
	)
	if not bool(installed.get("ok", false)):
		catalog.free()
		return "fixture install failed before remove: %s" % installed
	var duplicate_path := "user://ptcgdap/author_strategy_packages/removal-duplicate.ptcgai"
	var duplicate := FileAccess.open(duplicate_path, FileAccess.WRITE)
	if duplicate == null:
		catalog.free()
		return "could not create exact duplicate removal fixture"
	duplicate.store_buffer(FileAccess.get_file_as_bytes(INSTALLABLE_FIXTURE))
	duplicate.close()
	catalog.scan_startup()
	var wrong_ref: Dictionary = catalog.remove_user_package(
		str(metadata.get("package_id")), str(metadata.get("package_version")), "B".repeat(64)
	)
	var destination_preserved_after_wrong_ref := FileAccess.file_exists(destination)
	var duplicate_preserved_after_wrong_ref := FileAccess.file_exists(duplicate_path)
	var removed: Dictionary = catalog.remove_user_package(
		str(metadata.get("package_id")), str(metadata.get("package_version")), archive_sha
	)
	var remaining: Array = catalog.list_metadata_records().filter(func(record: Dictionary) -> bool:
		return record.get("package_id") == metadata.get("package_id")
	)
	var checks := run_checks([
		assert_false(bool(wrong_ref.get("ok", true)), "A wrong hash must not delete a package"),
		assert_eq(wrong_ref.get("error_code"), "package_remove_not_found"),
		assert_true(destination_preserved_after_wrong_ref),
		assert_true(duplicate_preserved_after_wrong_ref),
		assert_true(bool(removed.get("ok", false)), str(removed)),
		assert_eq(removed.get("removed_count"), 2, "Every exact duplicate in the user root must be removed"),
		assert_false(FileAccess.file_exists(destination)),
		assert_false(FileAccess.file_exists(duplicate_path)),
		assert_eq(remaining.size(), 0),
		assert_false(bool(removed.get("catalog_discoverable", true))),
		assert_false(bool(removed.get("remaining_built_in", true))),
	])
	catalog.free()
	return checks


func test_local_package_remove_hides_built_in_and_reimport_restores_exact_strategy() -> String:
	var catalog := CatalogScript.new()
	if not catalog.has_method("remove_package"):
		catalog.free()
		return "catalog does not expose product-level remove_package"
	if not catalog.has_method("set_removal_store_path_for_tests"):
		catalog.free()
		return "catalog does not expose an isolated removal-store seam"
	var removal_store_path := "user://ptcgdap/tests/d124-built-in-removals.json"
	for path: String in [removal_store_path, removal_store_path + ".tmp", removal_store_path + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	catalog.set_removal_store_path_for_tests(removal_store_path)
	var report: Dictionary = catalog.scan_startup()
	var built_in: Dictionary = {}
	for value: Variant in report.get("metadata_records", []):
		if value is Dictionary and value.get("package_id") == "ptcgdap.marnie.windows-local":
			built_in = value
			break
	if built_in.is_empty():
		catalog.free()
		return "built-in Marnie package missing"
	var removed_built_in: Dictionary = catalog.remove_package(
		str(built_in.get("package_id")),
		str(built_in.get("package_version")),
		str(built_in.get("archive_sha256"))
	)
	var hidden_records: Array = catalog.list_metadata_records().filter(func(record: Dictionary) -> bool:
		return record.get("package_id") == built_in.get("package_id")
	)
	catalog.free()
	var restarted_catalog := CatalogScript.new()
	restarted_catalog.set_removal_store_path_for_tests(removal_store_path)
	restarted_catalog.scan_startup()
	var hidden_after_restart: Array = restarted_catalog.list_metadata_records().filter(func(record: Dictionary) -> bool:
		return record.get("package_id") == built_in.get("package_id")
	)
	var source_path := ProjectSettings.globalize_path(
		"res://data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai"
	)
	var installed: Dictionary = restarted_catalog.install_from_local_path(source_path)
	if not bool(installed.get("ok", false)):
		restarted_catalog.free()
		return "could not restore removed built-in by exact reimport: %s" % installed
	var user_path := str(installed.get("installed_path", ""))
	var restored_records: Array = restarted_catalog.list_metadata_records().filter(func(record: Dictionary) -> bool:
		return record.get("package_id") == built_in.get("package_id")
	)
	var removed: Dictionary = restarted_catalog.remove_package(
		str(built_in.get("package_id")),
		str(built_in.get("package_version")),
		str(built_in.get("archive_sha256"))
	)
	var remaining: Array = restarted_catalog.list_metadata_records().filter(func(record: Dictionary) -> bool:
		return record.get("package_id") == built_in.get("package_id")
	)
	var checks := run_checks([
		assert_true(bool(removed_built_in.get("ok", false)), str(removed_built_in)),
		assert_true(bool(removed_built_in.get("built_in_hidden", false))),
		assert_false(bool(removed_built_in.get("catalog_discoverable", true))),
		assert_eq(hidden_records, [], "A removed built-in package must disappear from the game catalog"),
		assert_true(FileAccess.file_exists(removal_store_path), "Built-in removal must persist in user data"),
		assert_eq(hidden_after_restart, [], "Built-in removal must survive a new catalog instance"),
		assert_eq(restored_records.size(), 1, "Exact reimport must clear the built-in removal marker"),
		assert_eq(restored_records[0].get("install_sources"), ["built_in", "user"]),
		assert_true(bool(removed.get("ok", false)), str(removed)),
		assert_false(FileAccess.file_exists(user_path)),
		assert_true(bool(removed.get("built_in_hidden", false))),
		assert_false(bool(removed.get("catalog_discoverable", true))),
		assert_eq(remaining, []),
	])
	for path: String in [removal_store_path, removal_store_path + ".tmp", removal_store_path + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	restarted_catalog.free()
	return checks


func test_invalid_removal_store_fails_delete_without_hiding_or_mutating_built_in_package() -> String:
	var removal_store_path := "user://ptcgdap/tests/d124-invalid-removals.json"
	for path: String in [removal_store_path, removal_store_path + ".tmp", removal_store_path + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(removal_store_path.get_base_dir()))
	var invalid_store := FileAccess.open(removal_store_path, FileAccess.WRITE)
	if invalid_store == null:
		return "could not create invalid removal-store fixture"
	invalid_store.store_string("{not-json")
	invalid_store.close()
	var catalog := CatalogScript.new()
	catalog.set_removal_store_path_for_tests(removal_store_path)
	var report: Dictionary = catalog.scan_startup()
	var built_in: Dictionary = {}
	for value: Variant in report.get("metadata_records", []):
		if value is Dictionary and value.get("package_id") == "ptcgdap.marnie.windows-local":
			built_in = value
			break
	if built_in.is_empty():
		catalog.free()
		return "invalid removal store unexpectedly hid the built-in package"
	var removed: Dictionary = catalog.remove_package(
		str(built_in.get("package_id")),
		str(built_in.get("package_version")),
		str(built_in.get("archive_sha256"))
	)
	var still_visible: Array = catalog.list_metadata_records().filter(func(record: Dictionary) -> bool:
		return record.get("package_id") == built_in.get("package_id")
	)
	var error_codes: Array[String] = []
	for diagnostic: Dictionary in catalog.list_diagnostics():
		error_codes.append(str(diagnostic.get("error_code", "")))
	var checks := run_checks([
		assert_false(bool(removed.get("ok", true))),
		assert_eq(removed.get("error_code"), "package_removal_store_invalid"),
		assert_eq(still_visible.size(), 1, "A failed removal-store write must leave the package usable"),
		assert_true("package_removal_store_invalid" in error_codes),
	])
	catalog.free()
	for path: String in [removal_store_path, removal_store_path + ".tmp", removal_store_path + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return checks


func _user_package_filenames() -> Array[String]:
	var result: Array[String] = []
	var root := DirAccess.open("user://ptcgdap/author_strategy_packages")
	if root == null:
		return result
	for filename: String in root.get_files():
		if filename.ends_with(".ptcgai") or filename.begins_with(".ptcgdap-author-install-"):
			result.append(filename)
	result.sort()
	return result


func test_metadata_only_candidate_cannot_request_ready_match_handle() -> String:
	var catalog := CatalogScript.new()
	var report: Dictionary = catalog.scan_startup()
	var record: Dictionary = {}
	for value: Variant in report.get("metadata_records", []):
		if value is Dictionary and value.get("package_id") == "ptcgdap.marnie.windows-local":
			record = value
			break
	if record.is_empty():
		catalog.free()
		return "Marnie candidate metadata missing"
	var rejected: Dictionary = catalog.request_ready_match_handle(
		str(record.get("package_id")), str(record.get("package_version")), str(record.get("archive_sha256"))
	)
	catalog.free()
	return run_checks([
		assert_false(bool(rejected.get("ok", true))),
		assert_eq(rejected.get("error_code"), "package_release_not_approved"),
		assert_null(rejected.get("handle")),
	])


func test_ready_catalog_and_match_handle_require_the_same_fixed_release_decision() -> String:
	var path := "res://data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai"
	var source := FileAccess.open(path, FileAccess.READ)
	if source == null:
		return "Marnie candidate archive missing"
	var archive_bytes := source.get_buffer(source.get_length())
	var catalog := CatalogScript.new()
	catalog._loader = SyntheticProductionLoader.new()
	catalog._release_gate = SyntheticReadyReleaseGate.new()
	var report: Dictionary = catalog.rebuild_from_captured_for_test([{
		"install_source": "built_in",
		"location_id": "synthetic-production.ptcgai",
		"archive_path": path,
		"archive_bytes": archive_bytes,
	}])
	var ready: Array[Dictionary] = report.get("ready_records", [])
	if ready.size() != 1:
		catalog.free()
		return "synthetic production package did not become ready: %s" % report
	var record: Dictionary = ready[0]
	var requested: Dictionary = catalog.request_ready_match_handle(
		str(record.get("package_id")),
		str(record.get("package_version")),
		str(record.get("archive_sha256"))
	)
	var handle: Variant = requested.get("handle")
	var public_handle: Dictionary = handle.to_public_dict() if handle != null else {}
	var public_ready_copy: Array[Dictionary] = catalog.list_ready_records()
	public_ready_copy[0]["package_id"] = "mutated"
	var checks := run_checks([
		assert_eq(record.get("status"), "ready"),
		assert_true(bool(record.get("player_start_allowed", false))),
		assert_eq(catalog.audit_snapshot().get("ready_record_count"), 1),
		assert_true(bool(requested.get("ok", false)), str(requested)),
		assert_true(handle != null and handle.validate_integrity()),
		assert_eq(public_handle.get("signature_status"), "production_trusted"),
		assert_eq(public_handle.get("signature_scope"), "production_release"),
		assert_true(bool(public_handle.get("execution_trusted", false))),
		assert_eq(catalog.list_ready_records()[0].get("package_id"), record.get("package_id")),
	])
	catalog.free()
	return checks
