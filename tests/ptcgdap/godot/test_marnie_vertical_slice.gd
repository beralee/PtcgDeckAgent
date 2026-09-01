class_name TestMarnieVerticalSlice
extends TestBase

const MarnieVerticalSliceScript = preload("res://scripts/ai/ptcgdap/public/MarnieVerticalSlice.gd")
const CabtTreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")
const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const LOCAL_DECK_PATH := "res://data/bundled_user/decks/800018501.json"
const VECTORS_PATH := "res://contracts/ptcgdap/marnie_vertical_slice_conformance_vectors.json"
const TRAJECTORY_PATH := "res://data/ptcgdap/marnie_vertical_slice/w0_w7_public_trajectory_v1.json"
const TEMP_FIXTURE_ROOT := "user://ptcgdap_marnie_vertical_slice_disk_trust"
const LOCKED_TRAJECTORY_SHA256 := "F2D3B37E20FFF20DA3A6AAB16AB5CA3160437093E66F1173C410A85B756CC67A"
const FIXTURE_FILES := [
	"contracts/ptcgdap/marnie_vertical_slice_bundle.json",
	"contracts/ptcgdap/marnie_vertical_slice.schema.json",
	"contracts/ptcgdap/marnie_vertical_slice_profile.json",
	"contracts/ptcgdap/marnie_vertical_slice_source_manifest.json",
	"contracts/ptcgdap/marnie_vertical_slice_conformance_vectors.json",
	"data/ptcgdap/marnie_vertical_slice/official_deck_manifest_v1.json",
	"data/ptcgdap/marnie_vertical_slice/local_deck_manifest_v1.json",
	"data/ptcgdap/marnie_vertical_slice/deck_identity_diff_v1.json",
	"data/ptcgdap/marnie_vertical_slice/capability_inventory_v1.json",
	"data/ptcgdap/marnie_vertical_slice/w0_w7_public_trajectory_v1.json",
]


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return _restore_integer_tokens(parser.data)


func _restore_integer_tokens(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number := float(value)
			return int(number) if is_finite(number) and number == floorf(number) else number
		TYPE_ARRAY:
			var result := []
			for child: Variant in value:
				result.append(_restore_integer_tokens(child))
			return result
		TYPE_DICTIONARY:
			var result := {}
			for key: Variant in value:
				result[key] = _restore_integer_tokens(value[key])
			return result
		_:
			return value


func _materialize_vector(value: Variant) -> Variant:
	if value is Dictionary:
		if value.keys().size() == 2 and value.get("host_type") == "string_name" and value.has("value"):
			return StringName(str(value.get("value")))
		var result := {}
		for key: Variant in value:
			result[key] = _materialize_vector(value[key])
		return result
	if value is Array:
		var result := []
		for child: Variant in value:
			result.append(_materialize_vector(child))
		return result
	return value


func _decode_public_node(node: Variant) -> Variant:
	if not node is Dictionary or typeof(node.get("kind")) != TYPE_STRING:
		return null
	match node.get("kind"):
		"null":
			return null
		"boolean", "integer", "string":
			return node.get("value")
		"binary64":
			var bytes: PackedByteArray = str(node.get("ieee754_hex", "")).hex_decode()
			if bytes.size() != 8:
				return null
			bytes.reverse()
			return bytes.decode_double(0)
		"array":
			var array := []
			for child: Variant in node.get("items", []):
				array.append(_decode_public_node(child))
			return array
		"object":
			var object := {}
			for entry_value: Variant in node.get("entries", []):
				if not entry_value is Dictionary:
					return null
				object[entry_value.get("key")] = _decode_public_node(entry_value.get("value"))
			return object
		_:
			return null


func _global(path: String) -> String:
	return ProjectSettings.globalize_path(path)


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var directory := path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(_global(directory)) != OK:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	return true


func _copy_fixture_root() -> String:
	_cleanup_fixture_root()
	for relative: String in FIXTURE_FILES:
		var source := "res://%s" % relative
		var target := "%s/%s" % [TEMP_FIXTURE_ROOT, relative]
		if not _write_bytes(target, _read_bytes(source)):
			return "failed to copy %s" % relative
	return ""


func _cleanup_fixture_root() -> void:
	for relative: String in FIXTURE_FILES:
		var path := "%s/%s" % [TEMP_FIXTURE_ROOT, relative]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(_global(path))
	for directory: String in [
		"data/ptcgdap/marnie_vertical_slice", "data/ptcgdap", "data",
		"contracts/ptcgdap", "contracts", "",
	]:
		var path := TEMP_FIXTURE_ROOT if directory.is_empty() else "%s/%s" % [TEMP_FIXTURE_ROOT, directory]
		if DirAccess.dir_exists_absolute(_global(path)):
			DirAccess.remove_absolute(_global(path))


func _canonical_bytes_sha256(bytes: PackedByteArray) -> String:
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		bytes,
		{"max_input_bytes": 2 * 1024 * 1024, "max_output_bytes": 2 * 1024 * 1024}
	)
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(canonical.get("bytes", PackedByteArray())) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


func test_strict_runtime_consumes_all_shared_vectors_and_is_copy_only() -> String:
	var runtime: Variant = MarnieVerticalSliceScript.load_default()
	var vectors: Variant = _read_json(VECTORS_PATH)
	var checks: Array[String] = [
		assert_true(runtime != null),
		assert_true(bool(runtime.get("ok"))),
		assert_true(vectors is Dictionary),
	]
	if runtime == null or not bool(runtime.get("ok")) or not vectors is Dictionary:
		return run_checks(checks)
	checks.append(assert_eq(runtime.bundle_hash(), "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425"))
	var cases: Array = vectors.get("cases", [])
	checks.append(assert_eq(cases.size(), 10))
	for case_value: Variant in cases:
		checks.append(assert_true(case_value is Dictionary))
		if not case_value is Dictionary:
			continue
		var case: Dictionary = case_value
		var result: Dictionary = runtime.run(
			case.get("operation"),
			_materialize_vector(case.get("input", {}).duplicate(true))
		)
		if case.has("expected_error"):
			checks.append(assert_false(bool(result.get("ok")), str(case.get("id"))))
			checks.append(assert_eq(result.get("error_code"), case.get("expected_error"), str(case.get("id"))))
			checks.append(assert_null(result.get("value"), str(case.get("id"))))
		else:
			checks.append(assert_true(bool(result.get("ok")), "%s: %s" % [case.get("id"), result]))
			checks.append(assert_eq(result.get("value"), case.get("expected"), str(case.get("id"))))
		var first_copy: Variant = result.get("value")
		if first_copy is Dictionary:
			first_copy["PRIVATE_MUTATION_SENTINEL"] = true
			var repeated: Dictionary = runtime.run(
				case.get("operation"),
				_materialize_vector(case.get("input", {}).duplicate(true))
			)
			checks.append(assert_false(JSON.stringify(repeated).contains("PRIVATE_MUTATION_SENTINEL")))
	return run_checks(checks)


func test_public_frames_reproduce_hashes_and_never_upgrade_w2_authority() -> String:
	var runtime: Variant = MarnieVerticalSliceScript.load_default()
	var trajectory: Variant = _read_json(TRAJECTORY_PATH)
	var checks: Array[String] = [assert_true(bool(runtime.get("ok"))), assert_true(trajectory is Dictionary)]
	if not bool(runtime.get("ok")) or not trajectory is Dictionary:
		return run_checks(checks)
	var frames: Array = trajectory.get("frames", [])
	checks.append(assert_eq(frames.size(), 13))
	for frame_value: Variant in frames:
		if not frame_value is Dictionary:
			checks.append(assert_true(false))
			continue
		var frame: Dictionary = frame_value
		var public_node: Variant = frame.get("public_tree")
		if public_node == null:
			checks.append(assert_null(frame.get("public_observation_hash")))
			continue
		var public_tree: Variant = _decode_public_node(public_node)
		var hash_result: Dictionary = CabtTreeHashScript.public_observation_hash(
			public_tree,
			{"max_input_bytes": 2 * 1024 * 1024, "max_output_bytes": 2 * 1024 * 1024, "max_nodes": 200000}
		)
		checks.append(assert_true(bool(hash_result.get("ok")), str(frame.get("frame_id"))))
		checks.append(assert_eq(hash_result.get("sha256"), frame.get("public_observation_hash"), str(frame.get("frame_id"))))
	var w2: Dictionary = runtime.frame("w2_setup_bench")
	checks.append(assert_eq(w2.get("current_firewall"), {"status": "rejected", "issue_code": "own_active_concealed"}))
	checks.append(assert_eq(w2.get("window", {}).get("decision_state"), "policy_allowed"))
	var serialized := JSON.stringify(trajectory)
	for forbidden: String in ["search_begin_input", "raw_private_hash", "token_free_callback_hash", "PRIVATE_MUTATION_SENTINEL"]:
		checks.append(assert_false(serialized.contains(forbidden)))
	return run_checks(checks)


func test_runtime_tamper_and_variant_substitutions_fail_closed() -> String:
	var runtime: Variant = MarnieVerticalSliceScript.load_default()
	var checks: Array[String] = [assert_true(bool(runtime.get("ok")))]
	checks.append(assert_false(bool(runtime.run(StringName("official_summary"), {}).get("ok"))))
	checks.append(assert_eq(runtime.run(StringName("official_summary"), {}).get("error_code"), "input_type_invalid"))
	var frame_copy: Dictionary = runtime.frame("w4_spikemuth_deck")
	frame_copy["window"]["options"][0]["index"] = 999999
	checks.append(assert_false(runtime.frame("w4_spikemuth_deck")["window"]["options"][0].get("index") == 999999))
	runtime.set("_trajectory", {"PRIVATE_MUTATION_SENTINEL": true})
	checks.append(assert_false(runtime.validate_integrity()))
	checks.append(assert_eq(runtime.run("official_summary", {}).get("error_code"), "fixture_integrity_invalid"))
	checks.append(assert_eq(runtime.frame("w3_main"), {}))
	return run_checks(checks)


func test_disk_anchor_rejects_missing_drift_and_self_consistent_resign() -> String:
	var copy_error := _copy_fixture_root()
	if not copy_error.is_empty():
		_cleanup_fixture_root()
		return copy_error
	var checks: Array[String] = []
	var clean: Variant = MarnieVerticalSliceScript.load_from_root(TEMP_FIXTURE_ROOT)
	checks.append(assert_true(bool(clean.get("ok"))))
	var trajectory_path := "%s/%s" % [TEMP_FIXTURE_ROOT, FIXTURE_FILES[-1]]
	var original_trajectory := _read_bytes(trajectory_path)
	var whitespace := original_trajectory.duplicate()
	whitespace.append_array("\n  \n".to_utf8_buffer())
	checks.append(assert_true(_write_bytes(trajectory_path, whitespace)))
	var whitespace_runtime: Variant = MarnieVerticalSliceScript.load_from_root(TEMP_FIXTURE_ROOT)
	checks.append(assert_true(bool(whitespace_runtime.get("ok"))))
	var mutated_text := original_trajectory.get_string_from_utf8()
	var old_role := "\"callback_role\": \"initial_deck\""
	var new_role := "\"callback_role\": \"PRIVATE_MUTATION_SENTINEL\""
	checks.append(assert_eq(mutated_text.count(old_role), 1))
	mutated_text = mutated_text.replace(old_role, new_role)
	var mutated_bytes := mutated_text.to_utf8_buffer()
	checks.append(assert_true(_write_bytes(trajectory_path, mutated_bytes)))
	var drift: Variant = MarnieVerticalSliceScript.load_from_root(TEMP_FIXTURE_ROOT)
	checks.append(assert_false(bool(drift.get("ok"))))
	checks.append(assert_eq(drift.get("error_code"), "fixture_artifact_hash_mismatch"))
	var forged_hash := _canonical_bytes_sha256(mutated_bytes)
	var bundle_path := "%s/%s" % [TEMP_FIXTURE_ROOT, FIXTURE_FILES[0]]
	var original_bundle := _read_bytes(bundle_path)
	var bundle_text := original_bundle.get_string_from_utf8()
	checks.append(assert_eq(bundle_text.count(LOCKED_TRAJECTORY_SHA256), 1))
	bundle_text = bundle_text.replace(LOCKED_TRAJECTORY_SHA256, forged_hash)
	checks.append(assert_true(_write_bytes(bundle_path, bundle_text.to_utf8_buffer())))
	var resigned: Variant = MarnieVerticalSliceScript.load_from_root(TEMP_FIXTURE_ROOT)
	checks.append(assert_false(bool(resigned.get("ok"))))
	checks.append(assert_eq(resigned.get("error_code"), "fixture_bundle_trust_anchor_mismatch"))
	checks.append(assert_true(_write_bytes(bundle_path, original_bundle)))
	DirAccess.remove_absolute(_global(trajectory_path))
	var missing: Variant = MarnieVerticalSliceScript.load_from_root(TEMP_FIXTURE_ROOT)
	checks.append(assert_false(bool(missing.get("ok"))))
	checks.append(assert_eq(missing.get("error_code"), "fixture_file_missing"))
	_cleanup_fixture_root()
	return run_checks(checks)


func test_local_deck_effect_support_probe_is_exact_and_copy_only() -> String:
	var deck_value: Variant = _read_json(LOCAL_DECK_PATH)
	var checks: Array[String] = [assert_true(deck_value is Dictionary)]
	if not deck_value is Dictionary:
		return run_checks(checks)
	var cards_value: Variant = deck_value.get("cards")
	checks.append(assert_true(cards_value is Array))
	if not cards_value is Array:
		return run_checks(checks)
	var cards: Array = cards_value
	var total_count := 0
	var seen: Dictionary = {}
	var support_rows: Array[Dictionary] = []
	CardImplementationStatus.clear_cache()
	for row_value: Variant in cards:
		checks.append(assert_true(row_value is Dictionary))
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value
		var set_code: String = str(row.get("set_code"))
		var card_index: String = str(row.get("card_index"))
		var count_value: Variant = row.get("count")
		checks.append(assert_true(typeof(count_value) == TYPE_INT or (typeof(count_value) == TYPE_FLOAT and float(count_value) == floor(float(count_value)))))
		if typeof(count_value) != TYPE_INT and typeof(count_value) != TYPE_FLOAT:
			continue
		var count := int(count_value)
		total_count += count
		var key := "%s/%s" % [set_code, card_index]
		checks.append(assert_false(seen.has(key)))
		seen[key] = true
		var card: CardData = CardDatabase.get_card(set_code, card_index)
		checks.append(assert_not_null(card))
		if card == null:
			continue
		var status: Dictionary = CardImplementationStatus.get_status(card)
		support_rows.append({
			"local_printing": {"set_code": set_code, "card_index": card_index},
			"count": count,
			"effect_id": str(card.effect_id),
			"card_type": str(card.card_type),
			"engine_supported": not bool(status.get("unimplemented", false)),
			"support_reason": str(status.get("reason", "")),
		})
	checks.append(assert_eq(total_count, 60))
	checks.append(assert_eq(seen.size(), 28))
	checks.append(assert_eq(support_rows.size(), 28))
	print("MARNIE_EFFECT_SUPPORT=" + JSON.stringify(support_rows))
	if not support_rows.is_empty():
		var leaked: Array = support_rows.duplicate(true)
		leaked[0]["effect_id"] = "PRIVATE_MUTATION_SENTINEL"
		checks.append(assert_false(JSON.stringify(support_rows).contains("PRIVATE_MUTATION_SENTINEL")))
	EffectProcessor.cleanup_live_instances_for_tests()
	CardImplementationStatus.clear_cache()
	return run_checks(checks)
