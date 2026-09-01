class_name TestCabtTreeHash
extends TestBase

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const CabtTreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")
const VECTOR_PATH := "res://contracts/ptcgdap/cabt_tree_hash_conformance_vectors.json"


func _load_vectors() -> Dictionary:
	var file := FileAccess.open(VECTOR_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _float_from_ieee754_hex(hex_value: String) -> float:
	var bytes := hex_value.hex_decode()
	bytes.reverse()
	return bytes.decode_double(0)


func _vector_input(vector: Dictionary) -> Variant:
	if vector.has("ieee754_hex"):
		return _float_from_ieee754_hex(str(vector.get("ieee754_hex", "")))
	var input: Variant = vector.get("input")
	if input is Dictionary or input is Array:
		input = input.duplicate(true)
	for patch_value: Variant in vector.get("ieee754_patches", []):
		if patch_value is Dictionary:
			_apply_ieee754_patch(input, patch_value)
	return input


func _apply_ieee754_patch(root: Variant, patch: Dictionary) -> void:
	var pointer := str(patch.get("pointer", ""))
	if not pointer.begins_with("/"):
		return
	var segments := pointer.substr(1).split("/")
	var parent: Variant = root
	for segment_index in range(segments.size() - 1):
		var segment := str(segments[segment_index]).replace("~1", "/").replace("~0", "~")
		if parent is Dictionary:
			parent = parent.get(segment)
		elif parent is Array and segment.is_valid_int():
			parent = parent[int(segment)]
		else:
			return
	var final_segment := str(segments[-1]).replace("~1", "/").replace("~0", "~")
	var replacement := _float_from_ieee754_hex(str(patch.get("ieee754_hex", "")))
	if parent is Dictionary:
		parent[final_segment] = replacement
	elif parent is Array and final_segment.is_valid_int():
		parent[int(final_segment)] = replacement


func test_shared_rfc8785_canonicalization_vectors() -> String:
	var vectors := _load_vectors()
	if vectors.is_empty():
		return "shared conformance vector artifact is missing or invalid"
	var failures: Array[String] = []
	for vector_value: Variant in vectors.get("canonicalization_vectors", []):
		if not vector_value is Dictionary:
			failures.append("non-dictionary canonicalization vector")
			continue
		var vector: Dictionary = vector_value
		var input: Variant = _vector_input(vector)
		var result: Dictionary
		if vector.has("input_unicode_codepoints"):
			result = CabtJsonTreeScript.canonicalize_unicode_codepoints(
				vector.get("input_unicode_codepoints", [])
			)
		else:
			result = CabtJsonTreeScript.canonicalize(input)
		if vector.has("expected_error_code"):
			if bool(result.get("ok", false)):
				failures.append("%s unexpectedly accepted" % vector.get("id", ""))
			elif str(result.get("error_code", "")) != str(vector.get("expected_error_code", "")):
				failures.append("%s expected error %s got %s" % [
					vector.get("id", ""),
					vector.get("expected_error_code", ""),
					result.get("error_code", ""),
				])
			continue
		if not bool(result.get("ok", false)):
			failures.append("%s rejected: %s" % [vector.get("id", ""), result.get("error_code", "")])
			continue
		var expected := str(vector.get("expected_canonical_utf8", ""))
		if str(result.get("text", "")) != expected:
			failures.append("%s expected %s got %s" % [vector.get("id", ""), expected, result.get("text", "")])
	return "\n".join(failures)


func test_shared_domain_hash_vectors() -> String:
	var vectors := _load_vectors()
	if vectors.is_empty():
		return "shared conformance vector artifact is missing or invalid"
	var failures: Array[String] = []
	for vector_value: Variant in vectors.get("domain_hash_vectors", []):
		if not vector_value is Dictionary:
			failures.append("non-dictionary domain vector")
			continue
		var vector: Dictionary = vector_value
		var domain := str(vector.get("domain", ""))
		var input: Variant = vector.get("input")
		if domain == "token_free_callback":
			var normalized: Dictionary = CabtTreeHashScript.normalize_search_capability(input)
			if not bool(normalized.get("ok", false)):
				failures.append("%s normalization failed" % vector.get("id", ""))
				continue
			if normalized.get("value") != vector.get("expected_normalized_input"):
				failures.append("%s normalized tree mismatch" % vector.get("id", ""))
		var result: Dictionary = CabtTreeHashScript.hash_tree(input, domain)
		if not bool(result.get("ok", false)):
			failures.append("%s rejected: %s" % [vector.get("id", ""), result.get("error_code", "")])
			continue
		if str(result.get("canonical_text", "")) != str(vector.get("expected_canonical_utf8", "")):
			failures.append("%s canonical text mismatch" % vector.get("id", ""))
		if str(result.get("sha256", "")) != str(vector.get("expected_sha256", "")):
			failures.append("%s digest mismatch" % vector.get("id", ""))
	return "\n".join(failures)


func test_utf16_key_order_and_number_thresholds_are_not_godot_defaults() -> String:
	var tree := {
		"\r": 2,
		"1": 4,
		"\u0080": 6,
		"ö": 7,
		"numbers": [0.000001, 0.0000001, 1.0e20, 1.0e21, -0.0],
	}
	tree[String.chr(0x20AC)] = 1
	tree[String.chr(0xFB33)] = 3
	tree[String.chr(0x1F600)] = 5
	var result: Dictionary = CabtJsonTreeScript.canonicalize(tree)
	var expected := (
		"{\"\\r\":2,\"1\":4,\"numbers\":[0.000001,1e-7,100000000000000000000,1e+21,0],"
		+ "\"%s\":6,\"ö\":7,\"%s\":1,\"%s\":5,\"%s\":3}"
	) % [String.chr(0x80), String.chr(0x20AC), String.chr(0x1F600), String.chr(0xFB33)]
	return run_checks([
		assert_true(bool(result.get("ok", false)), "JCS canonicalization should succeed"),
		assert_eq(
			result.get("text"),
			expected,
			"JCS must use UTF-16 property order and ECMAScript number thresholds",
		),
	])


func test_contract_artifact_canonicalization_uses_codepoint_order_and_forbids_float() -> String:
	var source := "{\"\\ud83d\\ude00\":2,\"\\ufb33\":1}".to_utf8_buffer()
	var artifact: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(source)
	var artifact_tree: Dictionary = CabtJsonTreeScript.canonicalize_artifact({
		String.chr(0x1F600): 2,
		String.chr(0xFB33): 1,
	})
	var jcs: Dictionary = CabtJsonTreeScript.canonicalize_json_bytes(source)
	var expected := "{\"%s\":1,\"%s\":2}" % [String.chr(0xFB33), String.chr(0x1F600)]
	var forbidden_float: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		"{\"value\":1.0}".to_utf8_buffer()
	)
	var forbidden_tree_float: Dictionary = CabtJsonTreeScript.canonicalize_artifact({
		"value": 1.0,
	})
	var unsafe_integer_bytes: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		"{\"value\":9007199254740992}".to_utf8_buffer()
	)
	var unsafe_integer_tree: Dictionary = CabtJsonTreeScript.canonicalize_artifact({
		"value": 9_007_199_254_740_992,
	})
	var noncharacter_bytes: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		"{\"value\":\"\\ufdd0\"}".to_utf8_buffer()
	)
	var noncharacter_tree: Dictionary = CabtJsonTreeScript.canonicalize_artifact({
		"value": String.chr(0xFDD0),
	})
	return run_checks([
		assert_true(bool(artifact.get("ok", false))),
		assert_eq(artifact.get("text"), expected),
		assert_eq(artifact_tree.get("text"), expected),
		assert_eq(artifact_tree.get("bytes"), artifact.get("bytes")),
		assert_true(jcs.get("text") != artifact.get("text")),
		assert_eq(forbidden_float.get("error_code"), "artifact_float_forbidden"),
		assert_eq(forbidden_tree_float.get("error_code"), "unsupported_type"),
		assert_eq(unsafe_integer_bytes.get("error_code"), "unsafe_integer"),
		assert_eq(unsafe_integer_tree.get("error_code"), "unsafe_integer"),
		assert_eq(noncharacter_bytes.get("error_code"), "invalid_unicode"),
		assert_eq(noncharacter_tree.get("error_code"), "invalid_unicode"),
	])


func test_invalid_trees_fail_closed_with_stable_codes() -> String:
	var cycle: Dictionary = {}
	cycle["self"] = cycle
	var non_string_key := {1: "forbidden"}
	var checks: Array[String] = []
	checks.append(assert_eq(CabtJsonTreeScript.canonicalize(INF).get("error_code"), "non_finite_number"))
	checks.append(assert_eq(CabtJsonTreeScript.canonicalize(9007199254740992).get("error_code"), "unsafe_integer"))
	checks.append(assert_eq(CabtJsonTreeScript.canonicalize(non_string_key).get("error_code"), "non_string_key"))
	checks.append(assert_eq(CabtJsonTreeScript.canonicalize(cycle).get("error_code"), "cycle_detected"))
	return run_checks(checks)


func test_string_name_tree_nodes_and_bom_bytes_fail_closed() -> String:
	var string_name_key := {}
	string_name_key[StringName("forbidden-key")] = 1
	var bom_json := PackedByteArray([0xEF, 0xBB, 0xBF, 0x7B, 0x7D])
	return run_checks([
		assert_eq(
			CabtJsonTreeScript.canonicalize(StringName("forbidden-value")).get("error_code"),
			"unsupported_type",
		),
		assert_eq(
			CabtTreeHashScript.public_observation_hash(StringName("forbidden-value")).get("error_code"),
			"unsupported_type",
		),
		assert_eq(
			CabtJsonTreeScript.canonicalize(string_name_key).get("error_code"),
			"non_string_key",
		),
		assert_eq(
			CabtJsonTreeScript.canonicalize_json_bytes(bom_json).get("error_code"),
			"invalid_json",
		),
	])


func test_shared_invalid_vectors_fail_closed_with_identical_codes() -> String:
	var vectors := _load_vectors()
	if vectors.is_empty():
		return "shared conformance vector artifact is missing or invalid"
	var failures: Array[String] = []
	for vector_value: Variant in vectors.get("invalid_vectors", []):
		if not vector_value is Dictionary:
			failures.append("non-dictionary invalid vector")
			continue
		var vector: Dictionary = vector_value
		var result := _run_invalid_vector(vector)
		var expected := str(vector.get("expected_error_code", ""))
		if bool(result.get("ok", false)):
			failures.append("%s unexpectedly accepted" % vector.get("id", ""))
		elif str(result.get("error_code", "")) != expected:
			failures.append("%s expected %s got %s" % [
				vector.get("id", ""),
				expected,
				result.get("error_code", ""),
			])
	return "\n".join(failures)


func test_shared_exact_boundary_vectors_are_accepted() -> String:
	var vectors := _load_vectors()
	if vectors.is_empty():
		return "shared conformance vector artifact is missing or invalid"
	var failures: Array[String] = []
	for vector_value: Variant in vectors.get("accepted_boundary_vectors", []):
		if not vector_value is Dictionary:
			failures.append("non-dictionary accepted boundary vector")
			continue
		var vector: Dictionary = vector_value
		var limits: Dictionary = vector.get("limits", {})
		var result: Dictionary
		if str(vector.get("operation", "")) == "parse_and_canonicalize":
			result = CabtJsonTreeScript.canonicalize_json_bytes(
				str(vector.get("input_json_utf8", "")).to_utf8_buffer(),
				limits,
			)
		else:
			result = CabtJsonTreeScript.canonicalize(
				_invalid_factory(str(vector.get("factory", ""))),
				limits,
			)
		if not bool(result.get("ok", false)):
			failures.append("%s rejected: %s" % [
				vector.get("id", ""),
				result.get("error_code", ""),
			])
		elif str(result.get("text", "")) != str(vector.get("expected_canonical_utf8", "")):
			failures.append("%s canonical bytes differ" % vector.get("id", ""))
	return "\n".join(failures)


func _run_invalid_vector(vector: Dictionary) -> Dictionary:
	var limits: Dictionary = vector.get("limits", {})
	match str(vector.get("operation", "")):
		"parse_and_canonicalize":
			var input_bytes: PackedByteArray
			if vector.has("input_utf8_hex"):
				input_bytes = str(vector.get("input_utf8_hex", "")).hex_decode()
			else:
				input_bytes = str(vector.get("input_json_utf8", "")).to_utf8_buffer()
			return CabtJsonTreeScript.canonicalize_json_bytes(
				input_bytes,
				limits,
			)
		"canonicalize_tree":
			var factory := str(vector.get("factory", ""))
			if factory == "lone_high_surrogate_value" or factory == "lone_low_surrogate_key":
				return CabtJsonTreeScript.canonicalize_unicode_codepoints([0xD800], limits)
			return CabtJsonTreeScript.canonicalize(_invalid_factory(factory), limits)
		"hash_domain":
			return CabtTreeHashScript.hash_tree(
				vector.get("input"),
				str(vector.get("domain", "")),
				limits,
			)
	return {"ok": false, "error_code": "unsupported_test_operation"}


func _invalid_factory(factory: String) -> Variant:
	match factory:
		"nan":
			return NAN
		"positive_infinity":
			return INF
		"negative_infinity":
			return -INF
		"safe_integer_max_plus_one":
			return 9_007_199_254_740_992
		"safe_integer_min_minus_one":
			return -9_007_199_254_740_992
		"noncharacter_value_fdd0":
			return String.chr(0xFDD0)
		"noncharacter_key_plane_1":
			return {String.chr(0x1FFFE): 1}
		"list_cycle":
			var list_cycle: Array = []
			list_cycle.append(list_cycle)
			return list_cycle
		"object_cycle":
			var object_cycle: Dictionary = {}
			object_cycle["self"] = object_cycle
			return object_cycle
		"non_string_key":
			return {1: "not-json"}
		"tuple_value":
			return Vector2(1.0, 2.0)
		"nested_list_depth_3":
			return [[[0]]]
		"four_node_tree":
			return [0, 1, 2]
		"one_member_object":
			return {"a": 0}
		"six_output_bytes":
			return "abcd"
	return null


func test_search_normalization_is_copy_only_and_empty_string_is_present() -> String:
	var raw := {
		"select": null,
		"logs": [],
		"current": null,
		"search_begin_input": "",
		"future": {"keep": [1, null]},
	}
	var normalized: Dictionary = CabtTreeHashScript.normalize_search_capability(raw)
	var value: Dictionary = normalized.get("value", {})
	return run_checks([
		assert_true(bool(normalized.get("ok", false))),
		assert_eq(raw.get("search_begin_input"), "", "normalization must not mutate caller tree"),
		assert_eq(
			value.get("search_begin_input"),
			{"$ptcgdap_opaque_search_capability_present": true},
		),
		assert_eq(value.get("future"), raw.get("future"), "unknown fields must remain bound"),
	])


func test_search_capability_rejects_string_name_token() -> String:
	var raw := {
		"select": null,
		"logs": [],
		"current": null,
		"search_begin_input": StringName("forbidden-token"),
	}
	return run_checks([
		assert_eq(
			CabtTreeHashScript.normalize_search_capability(raw).get("error_code"),
			"invalid_callback",
		),
		assert_eq(
			CabtTreeHashScript.raw_private_hash(raw).get("error_code"),
			"invalid_callback",
		),
		assert_eq(
			CabtTreeHashScript.token_free_callback_hash(raw).get("error_code"),
			"invalid_callback",
		),
	])
