class_name TestCabtContractSet
extends TestBase

const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const SOURCE_ROOT := "res://contracts/ptcgdap"
const TEMP_BASE := "user://ptcgdap_contract_set_disk_trust"
const FINAL_BUNDLE_SHA256 := "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
const LOCKED_SELECTION_PROFILE_SHA256 := "8F2133706BC33FC0125109E47835D6A06A6CC21FD5E4B324AD284FAF1D03F460"
const CONTRACT_FILES := [
	"cabt_contract_bundle.json",
	"raw_cabt_envelope.schema.json",
	"cabt_tree_hash_profile.json",
	"cabt_enum_snapshot.json",
	"cabt_option_sparse_shapes.json",
	"cabt_typed_view_profile.json",
	"cabt_tree_hash_conformance_vectors.json",
	"cabt_selection_window.schema.json",
	"cabt_selection_profile.json",
	"cabt_selection_conformance_vectors.json",
]
const TEMP_ROOTS := [
	TEMP_BASE + "/missing-file",
	TEMP_BASE + "/unrehashed-drift",
	TEMP_BASE + "/self-consistent-rehash",
]


func _global(path: String) -> String:
	return ProjectSettings.globalize_path(path)


func _cleanup_temp_roots() -> void:
	for root: String in TEMP_ROOTS:
		for filename: String in CONTRACT_FILES:
			var file_path := "%s/%s" % [root, filename]
			if FileAccess.file_exists(file_path):
				DirAccess.remove_absolute(_global(file_path))
		if DirAccess.dir_exists_absolute(_global(root)):
			DirAccess.remove_absolute(_global(root))
	if DirAccess.dir_exists_absolute(_global(TEMP_BASE)):
		DirAccess.remove_absolute(_global(TEMP_BASE))


func _copy_contract_root(destination: String) -> String:
	var make_error := DirAccess.make_dir_recursive_absolute(_global(destination))
	if make_error != OK:
		return "failed to create %s: %s" % [destination, error_string(make_error)]
	for filename: String in CONTRACT_FILES:
		var source := FileAccess.open("%s/%s" % [SOURCE_ROOT, filename], FileAccess.READ)
		if source == null:
			return "failed to read source %s" % filename
		var destination_file := FileAccess.open(
			"%s/%s" % [destination, filename],
			FileAccess.WRITE
		)
		if destination_file == null:
			return "failed to write copied %s" % filename
		destination_file.store_buffer(source.get_buffer(source.get_length()))
	return ""


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(text.to_utf8_buffer())
	return true


func _canonical_sha256(bytes: PackedByteArray) -> String:
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(bytes)
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(canonical.get("bytes", PackedByteArray())) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


func _mutate_selection_profile(root: String) -> Dictionary:
	var path := "%s/cabt_selection_profile.json" % root
	var original := _read_text(path)
	var final_brace := original.rfind("}")
	if final_brace < 0:
		return {"ok": false, "sha256": ""}
	var mutated := (
		original.substr(0, final_brace)
		+ ",\n  \"forged_disk_authority\": true\n"
		+ original.substr(final_brace)
	)
	if not _write_text(path, mutated):
		return {"ok": false, "sha256": ""}
	var digest := _canonical_sha256(mutated.to_utf8_buffer())
	return {"ok": not digest.is_empty(), "sha256": digest}


func test_final_locked_default_bundle_loads_with_the_hardcoded_anchor() -> String:
	var contracts: Variant = CabtContractSetScript.load_default()
	return run_checks([
		assert_not_null(contracts),
		assert_true(contracts.ok),
		assert_eq(contracts.source_contract_hash, FINAL_BUNDLE_SHA256),
		assert_true(contracts.validate_integrity()),
	])


func test_missing_root_and_missing_artifact_fail_closed() -> String:
	_cleanup_temp_roots()
	var missing_root: Variant = CabtContractSetScript.load_from_root(
		TEMP_BASE + "/does-not-exist"
	)
	var copy_error := _copy_contract_root(TEMP_ROOTS[0])
	if not copy_error.is_empty():
		_cleanup_temp_roots()
		return copy_error
	DirAccess.remove_absolute(
		_global(TEMP_ROOTS[0] + "/cabt_selection_profile.json")
	)
	var missing_file: Variant = CabtContractSetScript.load_from_root(TEMP_ROOTS[0])
	var checks: Array[String] = [
		assert_false(missing_root.ok),
		assert_eq(missing_root.error_code, "contract_file_missing"),
		assert_false(missing_file.ok),
		assert_eq(missing_file.error_code, "contract_file_missing"),
	]
	_cleanup_temp_roots()
	return run_checks(checks)


func test_unrehashed_artifact_drift_fails_before_bundle_authority() -> String:
	_cleanup_temp_roots()
	var root: String = TEMP_ROOTS[1]
	var copy_error := _copy_contract_root(root)
	if not copy_error.is_empty():
		_cleanup_temp_roots()
		return copy_error
	var mutation := _mutate_selection_profile(root)
	if not bool(mutation.get("ok", false)):
		_cleanup_temp_roots()
		return "failed to create unrehashed selection-profile drift"
	var contracts: Variant = CabtContractSetScript.load_from_root(root)
	var checks: Array[String] = [
		assert_false(contracts.ok),
		assert_eq(contracts.error_code, "contract_artifact_hash_mismatch"),
	]
	_cleanup_temp_roots()
	return run_checks(checks)


func test_self_consistent_artifact_rehash_cannot_replace_the_bundle_anchor() -> String:
	_cleanup_temp_roots()
	var root: String = TEMP_ROOTS[2]
	var copy_error := _copy_contract_root(root)
	if not copy_error.is_empty():
		_cleanup_temp_roots()
		return copy_error
	var mutation := _mutate_selection_profile(root)
	if not bool(mutation.get("ok", false)):
		_cleanup_temp_roots()
		return "failed to create self-consistent selection-profile drift"
	var forged_profile_hash := str(mutation.get("sha256", ""))
	var bundle_path := "%s/cabt_contract_bundle.json" % root
	var bundle_text := _read_text(bundle_path)
	if bundle_text.count(LOCKED_SELECTION_PROFILE_SHA256) != 1:
		_cleanup_temp_roots()
		return "locked selection-profile digest was not unique in bundle"
	bundle_text = bundle_text.replace(
		LOCKED_SELECTION_PROFILE_SHA256,
		forged_profile_hash
	)
	if not _write_text(bundle_path, bundle_text):
		_cleanup_temp_roots()
		return "failed to write self-consistently rehashed bundle"
	var forged_bundle_hash := _canonical_sha256(bundle_text.to_utf8_buffer())
	var contracts: Variant = CabtContractSetScript.load_from_root(root)
	var checks: Array[String] = [
		assert_false(forged_profile_hash.is_empty()),
		assert_false(forged_bundle_hash.is_empty()),
		assert_eq(forged_bundle_hash == FINAL_BUNDLE_SHA256, false),
		assert_false(contracts.ok),
		assert_eq(contracts.error_code, "contract_bundle_trust_anchor_mismatch"),
		assert_eq(contracts.source_contract_hash, ""),
	]
	_cleanup_temp_roots()
	return run_checks(checks)
