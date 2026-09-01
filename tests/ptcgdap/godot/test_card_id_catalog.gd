class_name TestCardIdCatalog
extends TestBase

const CardIdCatalogScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/CardIdCatalog.gd"
)
const TRUSTED_BUNDLE_SHA256 := "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4"
const TRUSTED_RUNTIME_INTEGRITY_SHA256 := "B812F98BF096033E1EE6908B9A198B2357E1EA8D16CC1A05573335058B7FACD0"
const VECTOR_PATH := "res://contracts/ptcgdap/card_id_catalog_conformance_vectors.json"
const TEMP_BASE := "user://ptcgdap_card_id_catalog_trust"
const PAYLOAD_FILES := [
	"contracts/ptcgdap/card_id_catalog_bundle.json",
	"contracts/ptcgdap/card_id_catalog.schema.json",
	"contracts/ptcgdap/card_id_catalog_source_manifest.json",
	"contracts/ptcgdap/card_id_catalog_conformance_vectors.json",
	"data/ptcgdap/card_id_catalog/official_card_attack_master_v1.json",
	"data/ptcgdap/card_id_catalog/marnie_exact_print_bridge_v1.json",
	"data/bundled_user/cards/CSVE1C_DAR.json",
	"data/bundled_user/cards/CSV7C_059.json",
	"data/bundled_user/cards/CSV8C_094.json",
	"data/bundled_user/cards/LEN_DRI_134.json",
	"data/bundled_user/cards/LEN_DRI_135.json",
	"data/bundled_user/cards/LEN_DRI_136.json",
	"data/bundled_user/cards/CSV8C_173.json",
	"data/bundled_user/cards/CSV8C_183.json",
	"data/bundled_user/cards/LEN_DRI_169.json",
]


func test_default_catalog_requires_the_fixed_compile_time_bundle_anchor() -> String:
	var catalog: Variant = CardIdCatalogScript.load_default()
	return run_checks([
		assert_not_null(catalog),
		assert_eq(catalog.error_code, ""),
		assert_true(catalog.ok),
		assert_eq(catalog.catalog_hash(), TRUSTED_BUNDLE_SHA256),
		assert_eq(catalog.get("_runtime_integrity_sha256"), TRUSTED_RUNTIME_INTEGRITY_SHA256),
		assert_true(catalog.validate_integrity()),
	])


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


func _read_json(path: String) -> Variant:
	var parsed: Dictionary = CardIdCatalogScript._parse_json_bytes(_read_bytes(path))
	return parsed.get("value") if bool(parsed.get("ok", false)) else null


func _materialize(value: Variant) -> Variant:
	if value is Dictionary:
		var object: Dictionary = value
		if object.has("host_type"):
			match str(object.get("host_type")):
				"bool":
					return bool(object.get("value"))
				"integer":
					return int(object.get("value"))
				"unsafe_integer":
					return int(str(object.get("decimal")))
		var result := {}
		for key: Variant in object:
			result[key] = _materialize(object[key])
		return result
	if value is Array:
		var result := []
		for child: Variant in value as Array:
			result.append(_materialize(child))
		return result
	return value


func _run_vector(catalog: Variant, vector: Dictionary) -> Dictionary:
	var operation := str(vector.get("operation"))
	var input_value: Variant = _materialize(vector.get("input", {}))
	if not input_value is Dictionary:
		return {"ok": false, "error_code": "input_type_invalid", "value": null}
	var input: Dictionary = input_value
	match operation:
		"lookup_official_card":
			return catalog.lookup_official_card(input.get("official_card_id"))
		"lookup_official_attack":
			return catalog.lookup_official_attack(input.get("official_attack_id"))
		"lookup_official_printing":
			return catalog.official_printing_for(input.get("official_card_id"))
		"lookup_local_printing":
			var printing: Variant = input.get("local_printing")
			if not printing is Dictionary:
				return catalog.lookup_local_printing(null, null)
			return catalog.lookup_local_printing(printing.get("set_code"), printing.get("card_index"))
		"lookup_local_printing_for_official_card":
			return catalog.lookup_local_printing_for_official_card(input.get("official_card_id"))
		"lookup_local_attack":
			var printing: Variant = input.get("local_printing")
			if not printing is Dictionary:
				return catalog.lookup_local_attack(null, null, input.get("local_attack_index"))
			return catalog.lookup_local_attack(printing.get("set_code"), printing.get("card_index"), input.get("local_attack_index"))
		"artifact_canonical_sha256":
			return catalog.artifact_canonical_sha256(input.get("artifact_id"))
		"validate_local_source":
			var printing: Variant = input.get("local_printing")
			if not printing is Dictionary:
				return catalog.validate_local_source(null, null, null)
			var source_path := "res://%s" % str(input.get("source_file"))
			var actual_source: Variant
			if input.get("materialization") == "bytes":
				actual_source = _read_bytes(source_path)
			else:
				actual_source = _read_json(source_path)
				if actual_source is Dictionary:
					var mutation: Variant = input.get("mutation")
					if mutation is Dictionary:
						(actual_source as Dictionary)[mutation.get("field")] = mutation.get("value")
			return catalog.validate_local_source(printing.get("set_code"), printing.get("card_index"), actual_source)
		_:
			return {"ok": false, "error_code": "catalog_integrity_invalid", "value": null}


func test_all_shared_conformance_vectors_match_exactly() -> String:
	var document: Variant = _read_json(VECTOR_PATH)
	if not document is Dictionary:
		return "failed to load shared vectors"
	var vectors: Variant = document.get("vectors")
	if not vectors is Array or (vectors as Array).size() != 104:
		return "shared vector count differs"
	var catalog: Variant = CardIdCatalogScript.load_default()
	if catalog == null or not catalog.ok:
		return "catalog failed to load: %s" % str(catalog.error_code if catalog != null else "null")
	for vector_value: Variant in vectors as Array:
		if not vector_value is Dictionary:
			return "shared vector is not a dictionary"
		var vector: Dictionary = vector_value
		var actual: Dictionary = _run_vector(catalog, vector)
		var expected: Variant = vector.get("expected")
		if actual != expected:
			return "%s mismatch: expected=%s actual=%s" % [str(vector.get("id")), var_to_str(expected), var_to_str(actual)]
	return ""


func _global(path: String) -> String:
	return ProjectSettings.globalize_path(path)


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	return true


func _copy_payload(destination: String) -> String:
	for relative_path: String in PAYLOAD_FILES:
		var destination_path := "%s/%s" % [destination, relative_path]
		var directory := destination_path.get_base_dir()
		var make_error := DirAccess.make_dir_recursive_absolute(_global(directory))
		if make_error != OK:
			return "failed to create %s: %s" % [directory, error_string(make_error)]
		if not _write_bytes(destination_path, _read_bytes("res://%s" % relative_path)):
			return "failed to copy %s" % relative_path
	return ""


func _cleanup_payload(destination: String) -> void:
	for relative_path: String in PAYLOAD_FILES:
		var path := "%s/%s" % [destination, relative_path]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(_global(path))
	var directories := [
		"data/bundled_user/cards",
		"data/bundled_user",
		"data/ptcgdap/card_id_catalog",
		"data/ptcgdap",
		"data",
		"contracts/ptcgdap",
		"contracts",
		"",
	]
	for suffix: String in directories:
		var directory := destination if suffix.is_empty() else "%s/%s" % [destination, suffix]
		if DirAccess.dir_exists_absolute(_global(directory)):
			DirAccess.remove_absolute(_global(directory))


func _replace_once(path: String, before: String, after: String) -> bool:
	var text := _read_bytes(path).get_string_from_utf8()
	if text.count(before) != 1:
		return false
	return _write_bytes(path, text.replace(before, after).to_utf8_buffer())


func test_exact_host_types_copy_only_results_and_internal_tamper_fail_closed() -> String:
	var catalog: Variant = CardIdCatalogScript.load_default()
	var invalid_root: Variant = CardIdCatalogScript.load_trusted_bundle(&"res://")
	var original: Dictionary = catalog.lookup_official_card(104)
	var returned_card: Dictionary = original.get("value")
	returned_card["official_card_id"] = 999999
	var audit: Dictionary = catalog.audit_snapshot()
	audit["official_card_count"] = 0
	var checks: Array[String] = [
		assert_false(invalid_root.ok),
		assert_eq(invalid_root.error_code, "catalog_not_loaded"),
		assert_eq(catalog.lookup_official_card(true), {"ok": false, "error_code": "input_type_invalid", "value": null}),
		assert_eq(catalog.lookup_official_card(104.0), {"ok": false, "error_code": "input_type_invalid", "value": null}),
		assert_eq(catalog.lookup_local_printing(&"CSV7C", "059"), {"ok": false, "error_code": "input_type_invalid", "value": null}),
		assert_eq(catalog.lookup_local_attack("CSV7C", "059", true), {"ok": false, "error_code": "input_type_invalid", "value": null}),
		assert_eq(catalog.validate_local_source("CSV7C", "059", "res://private"), {"ok": false, "error_code": "input_type_invalid", "value": null}),
		assert_eq(catalog.lookup_official_card(104).get("value").get("official_card_id"), 104),
		assert_eq(catalog.audit_snapshot().get("official_card_count"), 1267),
	]
	catalog.set("_runtime_integrity_sha256", "0".repeat(64))
	checks.append(assert_false(catalog.validate_integrity()))
	checks.append(assert_eq(catalog.lookup_official_card(104), {"ok": false, "error_code": "catalog_integrity_invalid", "value": null}))
	checks.append(assert_eq(catalog.catalog_hash(), ""))
	checks.append(assert_eq(catalog.audit_snapshot(), {}))
	var malformed: Variant = CardIdCatalogScript.load_default()
	malformed.set("_cards", {})
	checks.append(assert_false(malformed.validate_integrity()))
	checks.append(assert_eq(malformed.lookup_official_attack(131), {"ok": false, "error_code": "catalog_integrity_invalid", "value": null}))
	var shifted: Variant = CardIdCatalogScript.load_default()
	var original_cards: Dictionary = shifted.get("_cards")
	var shifted_cards := {}
	for card_id: int in range(1, 1268):
		shifted_cards[card_id + 2000] = original_cards[card_id]
	shifted.set("_cards", shifted_cards)
	checks.append(assert_false(shifted.validate_integrity()))
	checks.append(assert_eq(shifted.lookup_official_card(2001), {"ok": false, "error_code": "catalog_integrity_invalid", "value": null}))
	var rebased: Variant = CardIdCatalogScript.load_default()
	var forged_cards: Dictionary = (rebased.get("_cards") as Dictionary).duplicate(true)
	(forged_cards[104] as Dictionary)["exact_english_printing_or_null"] = {"expansion": "PRIVATE", "collection_no": "SENTINEL"}
	rebased.set("_cards", forged_cards)
	var attacker_digest: String = str(rebased.call("_runtime_digest"))
	rebased.set("_runtime_integrity_sha256", attacker_digest)
	checks.append(assert_false(attacker_digest == TRUSTED_RUNTIME_INTEGRITY_SHA256))
	checks.append(assert_false(rebased.validate_integrity()))
	checks.append(assert_eq(rebased.official_printing_for(104), {"ok": false, "error_code": "catalog_integrity_invalid", "value": null}))
	return run_checks(checks)


func test_disk_bundle_artifact_and_source_tamper_fail_closed() -> String:
	var cases := [
		{
			"name": "bundle",
			"path": "contracts/ptcgdap/card_id_catalog_bundle.json",
			"before": "\"schema_version\": 1",
			"after": "\"schema_version\": 2",
			"error": "catalog_bundle_trust_anchor_mismatch",
		},
		{
			"name": "artifact",
			"path": "data/ptcgdap/card_id_catalog/official_card_attack_master_v1.json",
			"before": "\"schema_version\": 1",
			"after": "\"schema_version\": 2",
			"error": "catalog_artifact_hash_mismatch",
		},
	]
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		var root := "%s/%s" % [TEMP_BASE, str(case.get("name"))]
		_cleanup_payload(root)
		var copy_error := _copy_payload(root)
		if not copy_error.is_empty():
			_cleanup_payload(root)
			return copy_error
		if not _replace_once("%s/%s" % [root, str(case.get("path"))], str(case.get("before")), str(case.get("after"))):
			_cleanup_payload(root)
			return "failed to mutate %s" % str(case.get("name"))
		var catalog: Variant = CardIdCatalogScript.load_trusted_bundle(root)
		var failure := run_checks([
			assert_false(catalog.ok),
			assert_eq(catalog.error_code, case.get("error")),
			assert_eq(catalog.source_contract_hash, ""),
		])
		_cleanup_payload(root)
		if not failure.is_empty():
			return "%s: %s" % [str(case.get("name")), failure]
	var source_root := "%s/source" % TEMP_BASE
	_cleanup_payload(source_root)
	var copy_error := _copy_payload(source_root)
	if not copy_error.is_empty():
		return copy_error
	var source_path := "%s/data/bundled_user/cards/CSV7C_059.json" % source_root
	var source_bytes := _read_bytes(source_path)
	source_bytes.append_array("\n ".to_utf8_buffer())
	if not _write_bytes(source_path, source_bytes):
		_cleanup_payload(source_root)
		return "failed to mutate source"
	var source_catalog: Variant = CardIdCatalogScript.load_trusted_bundle(source_root)
	var source_failure := run_checks([
		assert_false(source_catalog.ok),
		assert_eq(source_catalog.error_code, "source_hash_mismatch"),
	])
	_cleanup_payload(source_root)
	return source_failure


func test_canonical_artifact_whitespace_is_accepted_but_missing_source_is_not() -> String:
	var whitespace_root := "%s/whitespace" % TEMP_BASE
	_cleanup_payload(whitespace_root)
	var copy_error := _copy_payload(whitespace_root)
	if not copy_error.is_empty():
		return copy_error
	for relative_path: String in [
		"contracts/ptcgdap/card_id_catalog_bundle.json",
		"data/ptcgdap/card_id_catalog/official_card_attack_master_v1.json",
	]:
		var path := "%s/%s" % [whitespace_root, relative_path]
		var bytes := _read_bytes(path)
		bytes.append_array("\n \t".to_utf8_buffer())
		if not _write_bytes(path, bytes):
			_cleanup_payload(whitespace_root)
			return "failed to append canonical whitespace"
	var catalog: Variant = CardIdCatalogScript.load_trusted_bundle(whitespace_root)
	var checks: Array[String] = [
		assert_true(catalog.ok),
		assert_eq(catalog.catalog_hash(), TRUSTED_BUNDLE_SHA256),
	]
	_cleanup_payload(whitespace_root)
	var missing_root := "%s/missing" % TEMP_BASE
	_cleanup_payload(missing_root)
	copy_error = _copy_payload(missing_root)
	if not copy_error.is_empty():
		return copy_error
	DirAccess.remove_absolute(_global("%s/data/bundled_user/cards/CSV7C_059.json" % missing_root))
	var missing: Variant = CardIdCatalogScript.load_trusted_bundle(missing_root)
	checks.append(assert_false(missing.ok))
	checks.append(assert_eq(missing.error_code, "source_file_missing"))
	_cleanup_payload(missing_root)
	return run_checks(checks)


func test_self_consistent_artifact_rehash_cannot_replace_compile_time_bundle_anchor() -> String:
	var root := "%s/self-consistent" % TEMP_BASE
	_cleanup_payload(root)
	var copy_error := _copy_payload(root)
	if not copy_error.is_empty():
		return copy_error
	var artifact_path := "%s/data/ptcgdap/card_id_catalog/official_card_attack_master_v1.json" % root
	if not _replace_once(artifact_path, "\"schema_version\": 1", "\"schema_version\": 2"):
		_cleanup_payload(root)
		return "failed to mutate master"
	var forged_hash_result: Dictionary = CardIdCatalogScript._canonical_sha256(_read_bytes(artifact_path))
	var forged_hash := str(forged_hash_result.get("sha256", ""))
	var bundle_path := "%s/contracts/ptcgdap/card_id_catalog_bundle.json" % root
	if not _replace_once(
		bundle_path,
		"3ED86C598ECD0BB5367FB575E94113BFE488E0B98FC64D6FABC50A1B0EAA8ED3",
		forged_hash
	):
		_cleanup_payload(root)
		return "failed to rehash forged bundle"
	var catalog: Variant = CardIdCatalogScript.load_trusted_bundle(root)
	var checks := run_checks([
		assert_false(forged_hash.is_empty()),
		assert_false(catalog.ok),
		assert_eq(catalog.error_code, "catalog_bundle_trust_anchor_mismatch"),
		assert_eq(catalog.source_contract_hash, ""),
	])
	_cleanup_payload(root)
	return checks
