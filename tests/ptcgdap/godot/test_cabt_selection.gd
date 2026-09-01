class_name TestCabtSelection
extends TestBase

const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")

const PROFILE_PATH := "res://contracts/ptcgdap/cabt_selection_profile.json"
const VECTOR_PATH := "res://contracts/ptcgdap/cabt_selection_conformance_vectors.json"
const OPTION_SHAPES_PATH := "res://contracts/ptcgdap/cabt_option_sparse_shapes.json"
const WINDOW_SCRIPT_PATH := "res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd"
const FINGERPRINT_SCRIPT_PATH := "res://scripts/ai/ptcgdap/cabt/CabtOptionFingerprint.gd"
const SANITIZER_SCRIPT_PATH := "res://scripts/ai/ptcgdap/cabt/CabtSelectionSanitizer.gd"
const FALLBACK_SCRIPT_PATH := "res://scripts/ai/ptcgdap/cabt/CabtDeterministicFallback.gd"
const DECK_SCRIPT_PATH := "res://scripts/ai/ptcgdap/cabt/CabtDeckSelectionValidator.gd"
const HASH_A := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
const HASH_B := "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
const OFFICIAL_MARNIE_SOURCE_SHA256 := "48F1A03E8AB8162F6DC608E6743A4F3B32004CB702CA447050E62055B85DEFBF"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const WINDOW_PROFILE_TAG := "CABT_SELECTION_WINDOW_V1"
const OPTION_PROFILE_TAG := "CABT_OPTION_FINGERPRINT_V1"
const DECK_PROFILE_TAG := "CABT_INITIAL_DECK_V1"
const WINDOW_PREFIX_HEX := "5054434744415000434142545F53454C454354494F4E5F57494E444F575F563100"
const OPTION_PREFIX_HEX := "5054434744415000434142545F4F5054494F4E5F46494E4745525052494E545F563100"
const DECK_PREFIX_HEX := "5054434744415000434142545F494E495449414C5F4445434B5F563100"


class FakeContractSet extends RefCounted:
	var ok := true
	var source_contract_hash := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
	var selection_profile: Dictionary = {}
	var option_shapes: Dictionary = {}
	var enum_snapshot: Dictionary = {}

	func _init(real_contracts: Variant) -> void:
		selection_profile = real_contracts.get("selection_profile")
		option_shapes = real_contracts.get("option_shapes")
		enum_snapshot = real_contracts.get("enum_snapshot")


func _restore_json_integer_tokens(value: Variant) -> Variant:
	if value is Dictionary:
		var restored := {}
		for key: Variant in (value as Dictionary).keys():
			restored[key] = _restore_json_integer_tokens((value as Dictionary)[key])
		return restored
	if value is Array:
		var restored := []
		for child: Variant in value:
			restored.append(_restore_json_integer_tokens(child))
		return restored
	if typeof(value) == TYPE_FLOAT:
		var number := float(value)
		if (
			is_finite(number)
			and number == floorf(number)
			and number >= -float(MAX_SAFE_INTEGER)
			and number <= float(MAX_SAFE_INTEGER)
		):
			return int(number)
	return value


func _load_json_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var restored: Variant = _restore_json_integer_tokens(parsed)
	return restored if restored is Dictionary else {}


func _runtime_script(path: String) -> Variant:
	if not ResourceLoader.exists(path):
		return null
	return load(path)


func _missing_runtime_scripts() -> Array[String]:
	var missing: Array[String] = []
	for path: String in [
		WINDOW_SCRIPT_PATH,
		FINGERPRINT_SCRIPT_PATH,
		SANITIZER_SCRIPT_PATH,
		FALLBACK_SCRIPT_PATH,
		DECK_SCRIPT_PATH,
	]:
		if not ResourceLoader.exists(path):
			missing.append(path)
	return missing


func _runtime_ready_error() -> String:
	var missing := _missing_runtime_scripts()
	return "missing_runtime_scripts:%s" % ",".join(missing) if not missing.is_empty() else ""


func _contract_set() -> Variant:
	return CabtContractSetScript.load_default()


func _call_static(script_path: String, method_name: String, arguments: Array) -> Variant:
	var script_value: Variant = _runtime_script(script_path)
	if script_value == null:
		return null
	return script_value.callv(method_name, arguments)


func _object_dict(value: Variant, method_name: String = "to_dict") -> Dictionary:
	if value == null or typeof(value) != TYPE_OBJECT or not value.has_method(method_name):
		return {}
	var serialized: Variant = value.call(method_name)
	return serialized if serialized is Dictionary else {}


func _build_result(input_value: Dictionary) -> Variant:
	return _call_static(WINDOW_SCRIPT_PATH, "build", [input_value, _contract_set()])


func _build_dict(input_value: Dictionary) -> Dictionary:
	return _object_dict(_build_result(input_value))


func _build_with_contracts(input_value: Dictionary, contracts: Variant) -> Dictionary:
	return _object_dict(_call_static(WINDOW_SCRIPT_PATH, "build", [input_value, contracts]))


func _window_from_result(result: Variant) -> Variant:
	return result.get("window") if result != null and typeof(result) == TYPE_OBJECT else null


func _window_dict(window: Variant) -> Dictionary:
	return _object_dict(window, "to_public_dict")


func _resolution_dict(result: Variant) -> Dictionary:
	return _object_dict(result)


func _canonical_text(value: Variant) -> String:
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize(value)
	return str(canonical.get("text", "")) if bool(canonical.get("ok", false)) else ""


func _profile_prefix_bytes(profile_tag: String) -> PackedByteArray:
	# JSON.parse_string replaces an embedded U+0000 in a JSON string on Godot.
	# Construct the authority bytes explicitly instead of trusting profile["prefix"].
	var prefix := PackedByteArray()
	prefix.append_array("PTCGDAP".to_utf8_buffer())
	prefix.append(0)
	prefix.append_array(profile_tag.to_utf8_buffer())
	prefix.append(0)
	return prefix


func _sha256_profile_tree(profile_tag: String, payload: Variant) -> String:
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize(payload)
	if not bool(canonical.get("ok", false)):
		return ""
	var bytes: PackedByteArray = _profile_prefix_bytes(profile_tag)
	bytes.append_array(canonical.get("bytes", PackedByteArray()))
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


func _window_hash(input_value: Dictionary) -> String:
	return _sha256_profile_tree(WINDOW_PROFILE_TAG, {
		"chooser_player_index": input_value.get("chooser_player_index"),
		"public_observation_hash": input_value.get("public_observation_hash"),
		"select": (input_value.get("select", {}) as Dictionary).duplicate(true),
	})


func _option_hash(input_value: Dictionary, window_id: String, option_index: int) -> String:
	var select_value: Dictionary = input_value.get("select", {})
	var options: Array = select_value.get("option", [])
	return _sha256_profile_tree(OPTION_PROFILE_TAG, {
		"window_id": window_id,
		"public_observation_hash": input_value.get("public_observation_hash"),
		"option_index": option_index,
		"select_type_raw": select_value.get("type"),
		"select_context_raw": select_value.get("context"),
		"option": (options[option_index] as Dictionary).duplicate(true),
		"context_card": _deep_copy_json_value(select_value.get("contextCard")),
		"effect": _deep_copy_json_value(select_value.get("effect")),
	})


func _deep_copy_json_value(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


func _card(card_id: int, serial: int, player_index: int = 0) -> Dictionary:
	return {"id": card_id, "serial": serial, "playerIndex": player_index}


func _base_select(options: Array, min_count: int = 0, max_count: int = -1) -> Dictionary:
	return {
		"type": 0,
		"context": 0,
		"minCount": min_count,
		"maxCount": options.size() if max_count < 0 else max_count,
		"remainDamageCounter": 0,
		"remainEnergyCost": 0,
		"option": options.duplicate(true),
		"deck": null,
		"contextCard": null,
		"effect": null,
	}


func _window_input(
	select_value: Dictionary,
	public_hash: Variant = HASH_A,
	authority: Variant = "conformance_fixture",
	chooser: Variant = 0
) -> Dictionary:
	return {
		"public_observation_hash": public_hash,
		"public_hash_authority": authority,
		"chooser_player_index": chooser,
		"select": select_value.duplicate(true),
	}


func _option_value(field_name: String, raw_type: int) -> Variant:
	match field_name:
		"type":
			return raw_type
		"area", "inPlayArea":
			return 1
		"playerIndex":
			return 0
		"specialConditionType":
			return 0
		"cardId":
			return 1000 + raw_type
		"serial":
			return 2000 + raw_type
		"attackId":
			return 3000 + raw_type
		_:
			return raw_type + 1


func _option_from_shape(raw_type: int, fields: Array) -> Dictionary:
	var option := {}
	for field_value: Variant in fields:
		var field_name := str(field_value)
		option[field_name] = _option_value(field_name, raw_type)
	return option


func _known_option(raw_type: int) -> Dictionary:
	var shape_contract := _load_json_object(OPTION_SHAPES_PATH)
	var shapes: Dictionary = shape_contract.get("shapes", {})
	var fields: Variant = shapes.get(str(raw_type))
	return _option_from_shape(raw_type, fields) if fields is Array else {"type": raw_type}


func _attempt(status: String, output: Variant = null) -> Dictionary:
	return {"status": status, "output": output}


func _resolve_attempt(window: Variant, status: String, output: Variant = null) -> Dictionary:
	return _resolution_dict(_resolve_attempt_result(window, status, output))


func _resolve_attempt_result(window: Variant, status: String, output: Variant = null) -> Variant:
	return _call_static(
		SANITIZER_SCRIPT_PATH,
		"resolve_policy_attempt",
		[window, _attempt(status, output)]
	)


func _fallback(window: Variant, trigger_code: String) -> Dictionary:
	return _resolution_dict(_fallback_result(window, trigger_code))


func _fallback_result(window: Variant, trigger_code: String) -> Variant:
	return _call_static(FALLBACK_SCRIPT_PATH, "resolve", [window, trigger_code])


func _issue_codes(build_dict: Dictionary) -> Array[String]:
	var codes: Array[String] = []
	var issues: Variant = build_dict.get("issues", [])
	if issues is Array:
		for issue_value: Variant in issues:
			if issue_value is Dictionary:
				codes.append(str((issue_value as Dictionary).get("code", "")))
	return codes


func _valid_window(options: Array, min_count: int, max_count: int) -> Variant:
	var result: Variant = _build_result(_window_input(_base_select(options, min_count, max_count)))
	return _window_from_result(result)


func _official_marnie_ids() -> Array:
	return [
		7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
		104, 104, 112, 112, 112, 112,
		646, 646, 646, 646, 647, 647, 647, 648, 648, 648,
		860, 860, 1079, 1079, 1079, 1080,
		1086, 1086, 1086, 1086, 1097, 1097, 1097, 1122, 1137,
		1152, 1152, 1152, 1152, 1182, 1182,
		1219, 1219, 1219, 1219,
		1227, 1227, 1227, 1227, 1231,
		1259, 1259, 1259, 1259,
	]


func _pinned_manifest(card_ids: Array) -> Dictionary:
	return {
		"profile": "cabt_initial_deck_v1",
		"card_ids": card_ids.duplicate(true),
		"deck_hash": _sha256_profile_tree(DECK_PROFILE_TAG, {"card_ids": card_ids}),
		"source_artifact_id": "candidate_official_marnie_deck",
		"source_sha256": OFFICIAL_MARNIE_SOURCE_SHA256,
		"authority_scope": "source_locked_conformance_fixture_only",
	}


func _build_pinned_deck(manifest: Dictionary, contracts: Variant = null) -> Variant:
	var selected_contracts: Variant = contracts if contracts != null else _contract_set()
	return _call_static(DECK_SCRIPT_PATH, "build_pinned_deck", [manifest, selected_contracts])


func _pinned_from_build(result: Variant) -> Variant:
	return result.get("pinned_deck") if result != null and typeof(result) == TYPE_OBJECT else null


func _resolve_deck(pinned: Variant, status: String, output: Variant) -> Dictionary:
	return _resolution_dict(_resolve_deck_result(pinned, status, output))


func _resolve_deck_result(pinned: Variant, status: String, output: Variant) -> Variant:
	return _call_static(
		DECK_SCRIPT_PATH,
		"resolve_initial_output",
		[pinned, _attempt(status, output)]
	)


func _shared_vectors() -> Dictionary:
	return _load_json_object(VECTOR_PATH)


func _find_case(cases: Variant, case_id: String) -> Dictionary:
	if cases is Array:
		for case_value: Variant in cases:
			if case_value is Dictionary and str((case_value as Dictionary).get("id", "")) == case_id:
				return (case_value as Dictionary).duplicate(true)
	return {}


func _option_matrix_input(vectors: Dictionary, case_value: Dictionary) -> Dictionary:
	var matrix: Dictionary = vectors.get("option_type_matrix", {})
	var common: Dictionary = matrix.get("common", {})
	var select_value: Dictionary = (common.get("select_without_option", {}) as Dictionary).duplicate(true)
	select_value["option"] = [(case_value.get("option", {}) as Dictionary).duplicate(true)]
	return {
		"public_observation_hash": common.get("public_observation_hash"),
		"public_hash_authority": common.get("public_hash_authority"),
		"chooser_player_index": common.get("chooser_player_index"),
		"select": select_value,
	}


func _window_case_input(case_value: Dictionary) -> Dictionary:
	return {
		"public_observation_hash": case_value.get("public_observation_hash"),
		"public_hash_authority": case_value.get("public_hash_authority"),
		"chooser_player_index": case_value.get("chooser_player_index"),
		"select": (case_value.get("select", {}) as Dictionary).duplicate(true),
	}


func _vector_case_input(
	vectors: Dictionary,
	case_id: String,
	section: String = "window_cases"
) -> Dictionary:
	if section == "option_type_matrix":
		var matrix: Dictionary = vectors.get("option_type_matrix", {})
		var option_case := _find_case(matrix.get("cases", []), case_id)
		return _option_matrix_input(vectors, option_case) if not option_case.is_empty() else {}
	var window_case := _find_case(vectors.get("window_cases", []), case_id)
	return _window_case_input(window_case) if not window_case.is_empty() else {}


func _expected_window(
	input_value: Dictionary,
	decision_state: String,
	fallback_reasons: Array,
	window_id: String,
	option_fingerprints: Array
) -> Dictionary:
	var select_value: Dictionary = input_value.get("select", {})
	return {
		"window_version": 1,
		"window_id": window_id,
		"hash_profile": "cabt_selection_window_v1",
		"option_fingerprint_profile": "cabt_option_fingerprint_v1",
		"public_observation_hash": input_value.get("public_observation_hash"),
		"public_hash_authority": input_value.get("public_hash_authority"),
		"chooser_player_index": input_value.get("chooser_player_index"),
		"decision_state": decision_state,
		"fallback_reasons": fallback_reasons.duplicate(true),
		"select_type_raw": select_value.get("type"),
		"select_context_raw": select_value.get("context"),
		"min_count": select_value.get("minCount"),
		"max_count": select_value.get("maxCount"),
		"remain_damage_counter": select_value.get("remainDamageCounter"),
		"remain_energy_cost": select_value.get("remainEnergyCost"),
		"context_card": _deep_copy_json_value(select_value.get("contextCard")),
		"effect": _deep_copy_json_value(select_value.get("effect")),
		"public_deck_candidates": _deep_copy_json_value(select_value.get("deck")),
		"options": (select_value.get("option", []) as Array).duplicate(true),
		"option_fingerprints": option_fingerprints.duplicate(true),
	}


func _value_at_pointer(root: Variant, pointer: String) -> Variant:
	if pointer.is_empty():
		return root
	var current: Variant = root
	for segment: String in pointer.trim_prefix("/").split("/"):
		if current is Dictionary:
			current = (current as Dictionary).get(segment)
		elif current is Array:
			current = (current as Array)[int(segment)]
		else:
			return null
	return current


func _replace_pointer(root: Dictionary, pointer: String, value: Variant) -> void:
	var split_at := pointer.rfind("/")
	var parent_pointer := pointer.substr(0, split_at)
	var leaf := pointer.substr(split_at + 1)
	var parent: Variant = _value_at_pointer(root, parent_pointer)
	if parent is Dictionary:
		(parent as Dictionary)[leaf] = _deep_copy_json_value(value)
	elif parent is Array:
		(parent as Array)[int(leaf)] = _deep_copy_json_value(value)


func _apply_build_mutation(input_value: Dictionary, mutation: Dictionary) -> Dictionary:
	var mutated := input_value.duplicate(true)
	var operation := str(mutation.get("operation", ""))
	if operation == "replace_input":
		mutated[str(mutation.get("field", ""))] = _deep_copy_json_value(mutation.get("value"))
	elif operation == "replace_pointer":
		_replace_pointer(mutated, str(mutation.get("pointer", "")), mutation.get("value"))
	elif operation == "add_key":
		var add_target: Variant = _value_at_pointer(mutated, str(mutation.get("pointer", "")))
		if add_target is Dictionary:
			(add_target as Dictionary)[str(mutation.get("key", ""))] = _deep_copy_json_value(
				mutation.get("value")
			)
	elif operation == "remove_key":
		var remove_target: Variant = _value_at_pointer(mutated, str(mutation.get("pointer", "")))
		if remove_target is Dictionary:
			(remove_target as Dictionary).erase(str(mutation.get("key", "")))
	return mutated


func _typed_proposal(descriptor: Dictionary) -> Variant:
	if str(descriptor.get("kind", "")) == "json":
		return _deep_copy_json_value(descriptor.get("value"))
	if str(descriptor.get("kind", "")) != "typed":
		return null
	if str(descriptor.get("type", "")) == "non_list_sequence":
		return PackedInt32Array(descriptor.get("items", []))
	if str(descriptor.get("type", "")) == "list":
		var values: Array = []
		for item: Variant in descriptor.get("items", []):
			if item is Dictionary and str((item as Dictionary).get("type", "")) == "float":
				values.append(float((item as Dictionary).get("decimal", "0")))
			else:
				values.append(_deep_copy_json_value(item))
		return values
	return null


func _typed_item(value: Variant) -> Variant:
	if value is Dictionary:
		var item_type := str((value as Dictionary).get("type", ""))
		if item_type == "float":
			return float((value as Dictionary).get("decimal", "0"))
		if item_type == "unsafe_integer":
			return int(str((value as Dictionary).get("decimal", "0")))
	return _deep_copy_json_value(value)


func _validate(window: Variant, proposal: Variant) -> Dictionary:
	return _object_dict(_call_static(SANITIZER_SCRIPT_PATH, "validate", [window, proposal]))


func _pinned_authority_from_vectors(vectors: Dictionary) -> Dictionary:
	var fixture: Dictionary = vectors.get("initial_deck_fixture", {})
	return {
		"profile": fixture.get("profile"),
		"card_ids": (fixture.get("card_ids", []) as Array).duplicate(true),
		"deck_hash": fixture.get("deck_hash"),
		"source_artifact_id": fixture.get("source_artifact_id"),
		"source_sha256": fixture.get("source_sha256"),
		"authority_scope": fixture.get("authority_scope"),
	}


func _deck_candidate(descriptor: Dictionary, card_ids: Array) -> Variant:
	var kind := str(descriptor.get("kind", ""))
	if kind == "pinned_copy":
		return card_ids.duplicate(true)
	if kind == "pinned_prefix":
		return card_ids.slice(0, int(descriptor.get("length", 0)))
	if kind == "pinned_plus":
		var longer := card_ids.duplicate(true)
		for item: Variant in descriptor.get("items", []):
			longer.append(_typed_item(item))
		return longer
	if kind == "pinned_replace":
		var replaced := card_ids.duplicate(true)
		replaced[int(descriptor.get("index", 0))] = _typed_item(descriptor.get("value"))
		return replaced
	if kind == "typed" and str(descriptor.get("type", "")) == "non_list_sequence":
		return PackedInt32Array(card_ids)
	return null


func _expected_deck_resolution(expected_value: Dictionary, card_ids: Array) -> Dictionary:
	var expected := expected_value.duplicate(true)
	if expected.has("selected_card_ids_ref"):
		expected.erase("selected_card_ids_ref")
		expected["selected_card_ids"] = card_ids.duplicate(true)
	return expected


func _mutate_pinned_authority(authority: Dictionary, mutation: Dictionary) -> Dictionary:
	var mutated := authority.duplicate(true)
	var operation := str(mutation.get("operation", ""))
	if operation == "truncate_card_ids":
		mutated["card_ids"] = (mutated.get("card_ids", []) as Array).slice(
			0,
			int(mutation.get("length", 0))
		)
	elif operation == "replace_card_id":
		var replaced: Array = (mutated.get("card_ids", []) as Array).duplicate(true)
		replaced[int(mutation.get("index", 0))] = _typed_item(mutation.get("value"))
		mutated["card_ids"] = replaced
	elif operation == "replace_field":
		mutated[str(mutation.get("field", ""))] = _deep_copy_json_value(mutation.get("value"))
	elif operation == "replace_card_id_and_hash":
		var changed: Array = (mutated.get("card_ids", []) as Array).duplicate(true)
		changed[int(mutation.get("index", 0))] = _typed_item(mutation.get("value"))
		mutated["card_ids"] = changed
		mutated["deck_hash"] = mutation.get("deck_hash")
	return mutated


func _profile_tag(profile_id: String) -> String:
	match profile_id:
		"cabt_selection_window_v1":
			return WINDOW_PROFILE_TAG
		"cabt_option_fingerprint_v1":
			return OPTION_PROFILE_TAG
		"cabt_initial_deck_v1":
			return DECK_PROFILE_TAG
		_:
			return ""


func _profile_conformance_authority(selection_profile: Dictionary) -> Dictionary:
	var initial_contract: Dictionary = selection_profile.get("initial_deck_contract", {})
	var authority: Dictionary = initial_contract.get("conformance_authority", {})
	if authority.is_empty():
		return {}
	return {
		"profile": "cabt_initial_deck_v1",
		"card_ids": (authority.get("card_ids", []) as Array).duplicate(true),
		"deck_hash": authority.get("deck_hash"),
		"source_artifact_id": authority.get("artifact_id"),
		"source_sha256": authority.get("source_sha256"),
		"authority_scope": authority.get("scope"),
	}


func _check_vector_window(input_value: Dictionary, case_value: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var case_id := str(case_value.get("id", "unnamed"))
	var expected_id := str(case_value.get("expected_window_id", ""))
	var expected_state := str(case_value.get("expected_decision_state", ""))
	var expected_reasons: Array = (case_value.get("expected_fallback_reasons", []) as Array).duplicate(true)
	var expected_fingerprints: Array
	if case_value.has("expected_option_fingerprints"):
		expected_fingerprints = (case_value.get("expected_option_fingerprints", []) as Array).duplicate(true)
	else:
		expected_fingerprints = [case_value.get("expected_fingerprint")]
	if _window_hash(input_value) != expected_id:
		failures.append("%s canonical window payload hash drifted" % case_id)
	var select_value: Dictionary = input_value.get("select", {})
	var options: Array = select_value.get("option", [])
	if options.size() != expected_fingerprints.size():
		failures.append("%s vector fingerprint count mismatch" % case_id)
	else:
		for option_index: int in options.size():
			if _option_hash(input_value, expected_id, option_index) != expected_fingerprints[option_index]:
				failures.append("%s option %d canonical fingerprint payload drifted" % [case_id, option_index])
	var result: Variant = _build_result(input_value)
	var build_dict := _object_dict(result)
	var window: Variant = _window_from_result(result)
	if _call_static(WINDOW_SCRIPT_PATH, "validate_build_result_integrity", [result]) != true:
		failures.append("%s BuildResult integrity failed" % case_id)
	if result != null and typeof(result) == TYPE_OBJECT:
		var issue_values: Variant = result.get("issues")
		if issue_values is Array:
			for issue_value: Variant in issue_values:
				if _call_static(WINDOW_SCRIPT_PATH, "validate_issue_integrity", [issue_value]) != true:
					failures.append("%s SelectionIssue integrity failed" % case_id)
	if window == null:
		failures.append("%s did not retain a window" % case_id)
		return failures
	var expected_public := _expected_window(
		input_value,
		expected_state,
		expected_reasons,
		expected_id,
		expected_fingerprints
	)
	var actual_public := _window_dict(window)
	if actual_public != expected_public:
		failures.append("%s serialized window does not exactly match shared vector" % case_id)
	if build_dict.get("window") != expected_public:
		failures.append("%s BuildResult window serialization drifted" % case_id)
	if build_dict.get("decision_state") != expected_state:
		failures.append("%s BuildResult decision_state drifted" % case_id)
	if _issue_codes(build_dict) != expected_reasons:
		failures.append("%s fallback issues/reasons drifted" % case_id)
	if build_dict.size() != 3 or not build_dict.has("issues"):
		failures.append("%s BuildResult public shape must be exact" % case_id)
	if case_value.has("expected_fallback"):
		var fallback_result: Variant = _fallback_result(window, "window_fallback_only")
		var resolution := _resolution_dict(fallback_result)
		if _call_static(
			FALLBACK_SCRIPT_PATH,
			"validate_resolution_integrity",
			[fallback_result, window]
		) != true:
			failures.append("%s fallback Resolution integrity failed" % case_id)
		if resolution.get("accepted") != true:
			failures.append("%s fallback must be accepted" % case_id)
		if resolution.get("window_id") != expected_id:
			failures.append("%s fallback window binding drifted" % case_id)
		if resolution.get("selected_indexes") != case_value.get("expected_fallback"):
			failures.append("%s fallback indexes drifted" % case_id)
		if resolution.get("owner") != "deterministic_fallback":
			failures.append("%s fallback owner drifted" % case_id)
		if resolution.get("reason_code") != "window_fallback_only":
			failures.append("%s fallback trigger code drifted" % case_id)
		if resolution.get("fallback_branch") != case_value.get("expected_fallback_branch"):
			failures.append("%s fallback branch drifted" % case_id)
	if case_value.has("accepted_ordered_proposal"):
		var ordered: Array = (case_value.get("accepted_ordered_proposal", []) as Array).duplicate(true)
		var validation_result: Variant = _call_static(
			SANITIZER_SCRIPT_PATH,
			"validate",
			[window, ordered]
		)
		var validation := _object_dict(validation_result)
		if _call_static(
			SANITIZER_SCRIPT_PATH,
			"validate_result_integrity",
			[validation_result, window]
		) != true:
			failures.append("%s ordered SelectionValidation integrity failed" % case_id)
		if validation.get("selected_indexes") != ordered:
			failures.append("%s ordered validation reordered indexes" % case_id)
		var accepted_result: Variant = _resolve_attempt_result(window, "returned", ordered)
		var accepted := _object_dict(accepted_result)
		if _call_static(
			FALLBACK_SCRIPT_PATH,
			"validate_resolution_integrity",
			[accepted_result, window]
		) != true:
			failures.append("%s ordered SelectionResolution integrity failed" % case_id)
		if accepted.get("owner") != "policy" or accepted.get("selected_indexes") != ordered:
			failures.append("%s ordered policy resolution reordered indexes" % case_id)
	return failures


func test_wp3_runtime_surface_and_shared_vectors_are_mandatory() -> String:
	if not FileAccess.file_exists(VECTOR_PATH):
		return "shared_vectors_missing"
	var vectors := _load_json_object(VECTOR_PATH)
	var selection_profile: Dictionary = _contract_set().get("selection_profile")
	var profile_contracts: Dictionary = selection_profile.get("hash_contract", {}).get("profiles", {})
	var profile_file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if profile_file == null:
		return "selection_profile_bytes_unreadable"
	var profile_tree_canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact(
		selection_profile
	)
	var profile_bytes_canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		profile_file.get_buffer(profile_file.get_length())
	)
	var checks: Array[String] = [
		assert_false(vectors.is_empty(), "shared selection vectors must parse"),
		assert_eq(vectors.get("vector_set_id"), "cabt_selection_conformance_v1"),
		assert_eq(vectors.get("profile_id"), "cabt_selection_profile_v1"),
		assert_eq(_profile_prefix_bytes(WINDOW_PROFILE_TAG).hex_encode().to_upper(), WINDOW_PREFIX_HEX),
		assert_eq(_profile_prefix_bytes(OPTION_PROFILE_TAG).hex_encode().to_upper(), OPTION_PREFIX_HEX),
		assert_eq(_profile_prefix_bytes(DECK_PROFILE_TAG).hex_encode().to_upper(), DECK_PREFIX_HEX),
		assert_eq(profile_contracts.get(WINDOW_PROFILE_TAG.to_lower()).get("prefix_utf8_hex"), WINDOW_PREFIX_HEX),
		assert_eq(profile_contracts.get(OPTION_PROFILE_TAG.to_lower()).get("prefix_utf8_hex"), OPTION_PREFIX_HEX),
		assert_eq(profile_contracts.get(DECK_PROFILE_TAG.to_lower()).get("prefix_utf8_hex"), DECK_PREFIX_HEX),
		assert_eq(profile_tree_canonical.get("ok"), true, "profile tree must canonicalize"),
		assert_eq(profile_bytes_canonical.get("ok"), true, "profile bytes must canonicalize"),
		assert_eq(
			profile_tree_canonical.get("bytes"),
			profile_bytes_canonical.get("bytes"),
			"canonical_json_v1 tree and exact-file bytes must agree"
		),
	]
	for case_value: Variant in vectors.get("hash_conformance_cases", []):
		if not case_value is Dictionary:
			checks.append("hash conformance case must be an object")
			continue
		var case: Dictionary = case_value
		var profile_id := str(case.get("profile", ""))
		checks.append(assert_false(_profile_tag(profile_id).is_empty(), str(case.get("id", ""))))
		checks.append(assert_eq(
			_canonical_text(case.get("payload")),
			case.get("expected_canonical_utf8"),
			"%s canonical payload" % case.get("id")
		))
		checks.append(assert_eq(
			_sha256_profile_tree(_profile_tag(profile_id), case.get("payload")),
			case.get("expected_digest"),
			"%s raw prefix bytes + payload digest" % case.get("id")
		))
	var missing := _missing_runtime_scripts()
	if not missing.is_empty():
		checks.append("missing_runtime_scripts:%s" % ",".join(missing))
	return run_checks(checks)


func test_shared_option_and_window_vectors_match_exact_public_serialization_and_hashes() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var vectors := _shared_vectors()
	if vectors.is_empty():
		return "shared_vectors_missing_or_invalid"
	var failures: Array[String] = []
	var matrix: Dictionary = vectors.get("option_type_matrix", {})
	var matrix_cases: Variant = matrix.get("cases", [])
	if not matrix_cases is Array or (matrix_cases as Array).size() != 17:
		failures.append("shared OptionType matrix must contain exactly 17 cases")
	else:
		for case_value: Variant in matrix_cases:
			if not case_value is Dictionary:
				failures.append("OptionType vector case must be an object")
				continue
			var case: Dictionary = case_value
			failures.append_array(_check_vector_window(_option_matrix_input(vectors, case), case))
	var window_cases: Variant = vectors.get("window_cases", [])
	if not window_cases is Array or (window_cases as Array).is_empty():
		failures.append("shared window cases missing")
	else:
		for case_value: Variant in window_cases:
			if not case_value is Dictionary:
				failures.append("window vector case must be an object")
				continue
			var case: Dictionary = case_value
			failures.append_array(_check_vector_window(_window_case_input(case), case))
	return "\n".join(failures)


func test_shared_build_reject_vectors_fail_closed_with_exact_non_echoing_issues() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var vectors := _shared_vectors()
	var failures: Array[String] = []
	for case_value: Variant in vectors.get("build_reject_cases", []):
		if not case_value is Dictionary:
			failures.append("build reject case must be an object")
			continue
		var case: Dictionary = case_value
		var section := str(case.get("base_section", "window_cases"))
		var base_input := _vector_case_input(
			vectors,
			str(case.get("base_window_case_id", "")),
			section
		)
		var input_value := _apply_build_mutation(base_input, case.get("mutation", {}))
		var result: Variant = _build_result(input_value)
		var result_dict := _object_dict(result)
		if _call_static(WINDOW_SCRIPT_PATH, "validate_build_result_integrity", [result]) != true:
			failures.append("%s reject BuildResult integrity failed" % case.get("id"))
		var issues_value: Variant = result.get("issues") if result != null else null
		if not issues_value is Array or (issues_value as Array).size() != 1:
			failures.append("%s reject SelectionIssue missing" % case.get("id"))
		elif _call_static(
			WINDOW_SCRIPT_PATH,
			"validate_issue_integrity",
			[(issues_value as Array)[0]]
		) != true:
			failures.append("%s reject SelectionIssue integrity failed" % case.get("id"))
		var expected_issue := {
			"code": case.get("expected_issue_code"),
			"pointer": case.get("expected_issue_pointer"),
			"severity": "error",
		}
		var expected_result := {
			"decision_state": "reject",
			"window": null,
			"issues": [expected_issue],
		}
		if result_dict != expected_result:
			failures.append("%s reject BuildResult drifted" % case.get("id"))
		var serialized := JSON.stringify(result_dict)
		var mutation: Dictionary = case.get("mutation", {})
		if str(mutation.get("operation", "")) == "add_key":
			if (
				serialized.contains(str(mutation.get("key", "")))
				or serialized.contains(str(mutation.get("value", "")))
			):
				failures.append("%s echoed quarantined key/value" % case.get("id"))
	return "\n".join(failures)


func test_shared_sanitizer_and_policy_fault_vectors_match_both_result_layers_exactly() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var vectors := _shared_vectors()
	var failures: Array[String] = []
	for case_value: Variant in vectors.get("sanitizer_cases", []):
		if not case_value is Dictionary:
			failures.append("sanitizer case must be an object")
			continue
		var case: Dictionary = case_value
		var input_value := _vector_case_input(vectors, str(case.get("window_case_id", "")))
		var window_build: Variant = _build_result(input_value)
		var window: Variant = _window_from_result(window_build)
		if window == null:
			failures.append("%s sanitizer window failed to build" % case.get("id"))
			continue
		if _call_static(WINDOW_SCRIPT_PATH, "validate_build_result_integrity", [window_build]) != true:
			failures.append("%s sanitizer BuildResult integrity failed" % case.get("id"))
		var proposal: Variant = _typed_proposal(case.get("proposal", {}))
		var validation_result: Variant = _call_static(
			SANITIZER_SCRIPT_PATH,
			"validate",
			[window, proposal]
		)
		var validation := _object_dict(validation_result)
		if _call_static(
			SANITIZER_SCRIPT_PATH,
			"validate_result_integrity",
			[validation_result, window]
		) != true:
			failures.append("%s SelectionValidation integrity failed" % case.get("id"))
		if validation != case.get("expected_validation"):
			failures.append("%s SelectionValidation drifted" % case.get("id"))
		var resolution_result: Variant = _resolve_attempt_result(window, "returned", proposal)
		var resolution := _object_dict(resolution_result)
		if _call_static(
			FALLBACK_SCRIPT_PATH,
			"validate_resolution_integrity",
			[resolution_result, window]
		) != true:
			failures.append("%s SelectionResolution integrity failed" % case.get("id"))
		var expected_resolution: Dictionary = (case.get("expected_resolution", {}) as Dictionary).duplicate(true)
		expected_resolution["window_id"] = _window_dict(window).get("window_id")
		if resolution != expected_resolution:
			failures.append("%s SelectionResolution drifted" % case.get("id"))
		if case.has("forbidden_partial_result") and resolution.get("selected_indexes") == case.get("forbidden_partial_result"):
			failures.append("%s retained a forbidden legal prefix" % case.get("id"))
	for case_value: Variant in vectors.get("policy_fault_cases", []):
		if not case_value is Dictionary:
			failures.append("policy fault case must be an object")
			continue
		var case: Dictionary = case_value
		var input_value := _vector_case_input(vectors, str(case.get("window_case_id", "")))
		var window_build: Variant = _build_result(input_value)
		var window: Variant = _window_from_result(window_build)
		if window == null:
			failures.append("%s policy fault window failed to build" % case.get("id"))
			continue
		if _call_static(WINDOW_SCRIPT_PATH, "validate_build_result_integrity", [window_build]) != true:
			failures.append("%s fault BuildResult integrity failed" % case.get("id"))
		var resolution_result: Variant = _resolve_attempt_result(
			window,
			str(case.get("policy_outcome", "")),
			_deep_copy_json_value(case.get("proposal"))
		)
		var resolution := _object_dict(resolution_result)
		if _call_static(
			FALLBACK_SCRIPT_PATH,
			"validate_resolution_integrity",
			[resolution_result, window]
		) != true:
			failures.append("%s fault SelectionResolution integrity failed" % case.get("id"))
		var expected_resolution: Dictionary = (case.get("expected_resolution", {}) as Dictionary).duplicate(true)
		expected_resolution["window_id"] = _window_dict(window).get("window_id")
		if resolution != expected_resolution:
			failures.append("%s policy fault resolution drifted" % case.get("id"))
	return "\n".join(failures)


func test_shared_initial_deck_vectors_use_only_the_normative_pinned_authority() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var vectors := _shared_vectors()
	var vector_authority := _pinned_authority_from_vectors(vectors)
	var contracts: Variant = _contract_set()
	var selection_profile_value: Variant = contracts.get("selection_profile") if contracts != null else null
	if not selection_profile_value is Dictionary:
		return "ContractSet.selection_profile_missing"
	var selection_profile: Dictionary = selection_profile_value
	var profile_authority := _profile_conformance_authority(selection_profile)
	var failures: Array[String] = []
	if profile_authority != vector_authority:
		failures.append("shared Marnie fixture must exactly mirror normative profile authority")
	var profile_claims: Dictionary = (
		selection_profile.get("initial_deck_contract", {}).get("conformance_authority", {})
		as Dictionary
	)
	var fixture: Dictionary = vectors.get("initial_deck_fixture", {})
	if profile_claims.get("local_mapping_claim") != fixture.get("local_mapping_claim"):
		failures.append("local mapping non-claim drifted")
	if profile_claims.get("cabt_exportable_claim") != fixture.get("cabt_exportable_claim"):
		failures.append("CABT exportability non-claim drifted")
	var build_result: Variant = _build_pinned_deck(vector_authority, contracts)
	var build_dict := _object_dict(build_result)
	var pinned: Variant = _pinned_from_build(build_result)
	var expected_build := {
		"accepted": true,
		"reason_code": "pinned_deck_accepted",
		"pinned_deck": vector_authority,
	}
	if _call_static(
		DECK_SCRIPT_PATH,
		"validate_build_result_integrity",
		[build_result, contracts]
	) != true:
		failures.append("normative DeckBuildResult integrity failed")
	if build_dict != expected_build or pinned == null:
		failures.append("unique normative pinned authority failed to build exactly")
		return "\n".join(failures)
	if _object_dict(pinned) != vector_authority:
		failures.append("PinnedDeckAuthority serialization drifted")
	var card_ids: Array = (vector_authority.get("card_ids", []) as Array).duplicate(true)
	var initial_cases: Variant = vectors.get("initial_deck_cases", [])
	if not initial_cases is Array or (initial_cases as Array).size() != 11:
		failures.append("shared initial deck cases must contain exactly 11 cases")
	for case_value: Variant in initial_cases:
		if not case_value is Dictionary:
			failures.append("initial deck case must be an object")
			continue
		var case: Dictionary = case_value
		var candidate: Variant = _deck_candidate(case.get("candidate", {}), card_ids)
		var resolution_result: Variant = _resolve_deck_result(
			pinned,
			str(case.get("policy_outcome", "")),
			candidate
		)
		var actual := _object_dict(resolution_result)
		if _call_static(
			DECK_SCRIPT_PATH,
			"validate_resolution_integrity",
			[resolution_result, pinned]
		) != true:
			failures.append("%s InitialDeckResolution integrity failed" % case.get("id"))
		var expected := _expected_deck_resolution(case.get("expected_resolution", {}), card_ids)
		if actual != expected:
			failures.append("%s InitialDeckResolution drifted" % case.get("id"))
		if actual.get("candidate_reason_code") != case.get("expected_candidate_reason"):
			failures.append("%s candidate reason was not consumed exactly" % case.get("id"))
	var invalid_cases: Variant = vectors.get("invalid_pinned_deck_cases", [])
	if not invalid_cases is Array or (invalid_cases as Array).size() != 8:
		failures.append("shared invalid pinned deck cases must contain exactly 8 cases")
	for case_value: Variant in invalid_cases:
		if not case_value is Dictionary:
			failures.append("invalid pinned deck case must be an object")
			continue
		var case: Dictionary = case_value
		var invalid_authority := _mutate_pinned_authority(
			vector_authority,
			case.get("authority_mutation", {})
		)
		var invalid_build_result: Variant = _build_pinned_deck(invalid_authority, contracts)
		var invalid_build := _object_dict(invalid_build_result)
		if _call_static(
			DECK_SCRIPT_PATH,
			"validate_build_result_integrity",
			[invalid_build_result, contracts]
		) != true:
			failures.append("%s invalid DeckBuildResult integrity failed" % case.get("id"))
		var expected_invalid_build := {
			"accepted": false,
			"reason_code": case.get("expected_resolution", {}).get("reason_code"),
			"pinned_deck": null,
		}
		if invalid_build != expected_invalid_build:
			failures.append("%s spoofed authority must reject" % case.get("id"))
		var invalid_resolution_result: Variant = _resolve_deck_result(
			invalid_authority,
			"returned",
			card_ids
		)
		if _call_static(
			DECK_SCRIPT_PATH,
			"validate_resolution_integrity",
			[invalid_resolution_result, invalid_authority]
		) != true:
			failures.append("%s invalid InitialDeckResolution integrity failed" % case.get("id"))
		if _object_dict(invalid_resolution_result) != case.get("expected_resolution"):
			failures.append("%s invalid authority resolution drifted" % case.get("id"))

	var exact_type_spoofs := []
	for replacement: Variant in [MAX_SAFE_INTEGER + 1, true, 7.0, StringName("7")]:
		var spoof := vector_authority.duplicate(true)
		var spoof_ids: Array = (spoof.get("card_ids", []) as Array).duplicate(true)
		spoof_ids[0] = replacement
		spoof["card_ids"] = spoof_ids
		exact_type_spoofs.append(spoof)
	var packed_spoof := vector_authority.duplicate(true)
	packed_spoof["card_ids"] = PackedInt32Array(card_ids)
	exact_type_spoofs.append(packed_spoof)
	var arbitrary_ids: Array = []
	for _index: int in 60:
		arbitrary_ids.append(7)
	var arbitrary_self_consistent := vector_authority.duplicate(true)
	arbitrary_self_consistent["card_ids"] = arbitrary_ids
	arbitrary_self_consistent["deck_hash"] = _sha256_profile_tree(
		DECK_PROFILE_TAG,
		{"card_ids": arbitrary_ids}
	)
	exact_type_spoofs.append(arbitrary_self_consistent)
	for spoof_value: Variant in exact_type_spoofs:
		var invalid_build := _object_dict(_build_pinned_deck(spoof_value))
		if (
			invalid_build.get("accepted") != false
			or invalid_build.get("reason_code") != "invalid_pinned_deck"
			or invalid_build.get("pinned_deck") != null
		):
			failures.append("unsafe or arbitrary self-consistent pinned authority was accepted")

	var caller_manifest := vector_authority.duplicate(true)
	var pinned_before := _object_dict(pinned)
	(caller_manifest.get("card_ids", []) as Array)[0] = 999999
	caller_manifest["source_artifact_id"] = "spoofed_after_build"
	var exposed := _object_dict(pinned)
	var exposed_ids: Variant = exposed.get("card_ids")
	if exposed_ids is Array and not (exposed_ids as Array).is_read_only():
		(exposed_ids as Array)[0] = 999999
	if _object_dict(pinned) != pinned_before:
		failures.append("PinnedDeckAuthority retained a nested caller/getter alias")
	var first_resolution := _resolve_deck(pinned, "returned", card_ids)
	var first_selected: Variant = first_resolution.get("selected_card_ids")
	if first_selected is Array and not (first_selected as Array).is_read_only():
		(first_selected as Array)[0] = 999999
	if _resolve_deck(pinned, "returned", card_ids).get("selected_card_ids") != card_ids:
		failures.append("InitialDeckResolution retained a mutable selected-card alias")
	return "\n".join(failures)


func test_untrusted_windows_and_contract_impostors_never_produce_indexes() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var real_contracts: Variant = _contract_set()
	var fake_contracts := FakeContractSet.new(real_contracts)
	var input_value := _window_input(_base_select([_known_option(1)], 1, 1))
	var fake_build: Variant = _call_static(WINDOW_SCRIPT_PATH, "build", [input_value, fake_contracts])
	var fake_build_dict := _object_dict(fake_build)
	var fake_deck_build := _object_dict(
		_call_static(
			DECK_SCRIPT_PATH,
			"build_pinned_deck",
			[_pinned_authority_from_vectors(_shared_vectors()), fake_contracts]
		)
	)
	var window_script: Variant = _runtime_script(WINDOW_SCRIPT_PATH)
	var forged_window: Variant = window_script.new({
		"window_id": HASH_A,
		"public_observation_hash": HASH_A,
		"public_hash_authority": "conformance_fixture",
		"chooser_player_index": 0,
		"decision_state": "policy_allowed",
		"fallback_reasons": [],
		"select_type_raw": 0,
		"select_context_raw": 0,
		"min_count": 2,
		"max_count": 2,
		"remain_damage_counter": 0,
		"remain_energy_cost": 0,
		"context_card": null,
		"effect": null,
		"public_deck_candidates": null,
		"options": [],
		"option_fingerprints": [],
		"select_payload": _base_select([], 2, 2),
	})
	var forged_fallback: Variant = _call_static(
		FALLBACK_SCRIPT_PATH,
		"resolve",
		[forged_window, "policy_unavailable"]
	)
	var forged_validation: Variant = _call_static(
		SANITIZER_SCRIPT_PATH,
		"validate",
		[forged_window, [0, 1]]
	)
	var forged_resolution: Variant = _call_static(
		SANITIZER_SCRIPT_PATH,
		"resolve_policy_attempt",
		[forged_window, _attempt("returned", [0, 1])]
	)
	var legitimate_window: Variant = _valid_window([_known_option(1)], 1, 1)
	if legitimate_window == null:
		return "legitimate integrity-control window failed to build"
	legitimate_window.set("_min_count", 2)
	var mutated_fallback: Variant = _call_static(
		FALLBACK_SCRIPT_PATH,
		"resolve",
		[legitimate_window, "policy_unavailable"]
	)
	var mutated_validation: Variant = _call_static(
		SANITIZER_SCRIPT_PATH,
		"validate",
		[legitimate_window, [0]]
	)
	return run_checks([
		assert_eq(fake_build_dict.get("decision_state"), "reject"),
		assert_eq(fake_build_dict.get("window"), null),
		assert_eq(fake_deck_build.get("accepted"), false),
		assert_eq(fake_deck_build.get("pinned_deck"), null),
		assert_eq(forged_fallback, null, "public Window.new forgery must not fall back"),
		assert_eq(forged_validation, null, "public Window.new forgery must not validate"),
		assert_eq(forged_resolution, null, "public Window.new forgery must not resolve"),
		assert_eq(mutated_fallback, null, "mutated window must not produce indexes"),
		assert_eq(mutated_validation, null, "mutated window must fail integrity validation"),
	])


func test_result_dtos_reject_ordinary_construction_mutation_and_stale_windows() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var failures: Array[String] = []
	var contracts: Variant = _contract_set()
	var window_script: GDScript = _runtime_script(WINDOW_SCRIPT_PATH)
	var sanitizer_script: GDScript = _runtime_script(SANITIZER_SCRIPT_PATH)
	var fallback_script: GDScript = _runtime_script(FALLBACK_SCRIPT_PATH)
	var deck_script: GDScript = _runtime_script(DECK_SCRIPT_PATH)
	var window_constants := window_script.get_script_constant_map()
	var sanitizer_constants := sanitizer_script.get_script_constant_map()
	var fallback_constants := fallback_script.get_script_constant_map()
	var deck_constants := deck_script.get_script_constant_map()
	var direct_issue: Variant = window_constants.get("SelectionIssue").new(
		"invalid_card",
		"/select/contextCard"
	)
	var direct_build: Variant = window_constants.get("BuildResult").new(
		"reject",
		null,
		[direct_issue],
		contracts
	)
	var direct_validation: Variant = sanitizer_constants.get("SelectionValidation").new(
		true,
		[0],
		"policy_selection_accepted"
	)
	var direct_resolution: Variant = fallback_constants.get("SelectionResolution").new(
		true,
		HASH_A,
		[0],
		"policy",
		"policy_selection_accepted",
		null
	)
	var direct_deck_build: Variant = deck_constants.get("DeckBuildResult").new(
		false,
		"invalid_pinned_deck",
		null,
		contracts
	)
	var direct_initial: Variant = deck_constants.get("InitialDeckResolution").new(
		false,
		[],
		"none",
		"invalid_pinned_deck",
		null,
		null,
		"invalid_pinned_deck"
	)
	for direct_value: Variant in [
		direct_issue,
		direct_build,
		direct_validation,
		direct_resolution,
		direct_deck_build,
		direct_initial,
	]:
		if not _object_dict(direct_value).is_empty():
			failures.append("ordinary result construction serialized as an owner DTO")
	if _call_static(WINDOW_SCRIPT_PATH, "validate_issue_integrity", [direct_issue]) == true:
		failures.append("ordinary SelectionIssue construction passed integrity")
	if _call_static(WINDOW_SCRIPT_PATH, "validate_build_result_integrity", [direct_build]) == true:
		failures.append("ordinary BuildResult construction passed integrity")

	var vectors := _shared_vectors()
	var ordered_case := _find_case(vectors.get("window_cases", []), "ordered_multi")
	var input_a := _window_case_input(ordered_case)
	var build_a: Variant = _build_result(input_a)
	var window_a: Variant = _window_from_result(build_a)
	var input_b := input_a.duplicate(true)
	var select_b: Dictionary = input_b.get("select", {})
	var options_b: Array = select_b.get("option", [])
	(options_b[0] as Dictionary)["serial"] = int((options_b[0] as Dictionary).get("serial")) + 1000
	var build_b: Variant = _build_result(input_b)
	var window_b: Variant = _window_from_result(build_b)
	if window_a == null or window_b == null:
		return "result integrity control windows failed to build"
	if _call_static(
		SANITIZER_SCRIPT_PATH,
		"validate_result_integrity",
		[direct_validation, window_a]
	) == true:
		failures.append("ordinary SelectionValidation construction passed integrity")
	if _call_static(
		FALLBACK_SCRIPT_PATH,
		"validate_resolution_integrity",
		[direct_resolution, window_a]
	) == true:
		failures.append("ordinary SelectionResolution construction passed integrity")
	if window_a.get("window_id") == window_b.get("window_id"):
		failures.append("stale-binding controls did not produce different windows")
	var ordered: Array = (ordered_case.get("accepted_ordered_proposal", []) as Array).duplicate(true)
	var validation: Variant = _call_static(
		SANITIZER_SCRIPT_PATH,
		"validate",
		[window_a, ordered]
	)
	var resolution: Variant = _resolve_attempt_result(window_a, "returned", ordered)
	if _call_static(
		SANITIZER_SCRIPT_PATH,
		"validate_result_integrity",
		[validation, window_b]
	) == true:
		failures.append("SelectionValidation rebound to a same-shape stale window")
	if _call_static(
		FALLBACK_SCRIPT_PATH,
		"validate_resolution_integrity",
		[resolution, window_b]
	) == true:
		failures.append("SelectionResolution rebound to a same-shape stale window")

	var reject_input := input_a.duplicate(true)
	reject_input["public_observation_hash"] = "a".repeat(64)
	var reject_build: Variant = _build_result(reject_input)
	var issue: Variant = (reject_build.get("issues") as Array)[0]
	var authority := _pinned_authority_from_vectors(vectors)
	var pinned_build: Variant = _build_pinned_deck(authority, contracts)
	var pinned: Variant = _pinned_from_build(pinned_build)
	var initial: Variant = _resolve_deck_result(
		pinned,
		"returned",
		(authority.get("card_ids", []) as Array).duplicate(true)
	)
	var second_pinned: Variant = _pinned_from_build(_build_pinned_deck(authority, contracts))
	if second_pinned == null or second_pinned == pinned:
		failures.append("exact pinned identity control did not create a second authority")
	elif _call_static(
		DECK_SCRIPT_PATH,
		"validate_resolution_integrity",
		[initial, second_pinned]
	) == true:
		failures.append("InitialDeckResolution rebound to an equal second pinned authority")
	if _call_static(
		DECK_SCRIPT_PATH,
		"validate_build_result_integrity",
		[direct_deck_build, contracts]
	) == true:
		failures.append("ordinary DeckBuildResult construction passed integrity")
	if _call_static(
		DECK_SCRIPT_PATH,
		"validate_resolution_integrity",
		[direct_initial, pinned]
	) == true:
		failures.append("ordinary InitialDeckResolution construction passed integrity")
	var genuine_values := [issue, build_a, validation, resolution, pinned_build, initial]
	var original_serialization: Array = []
	for genuine_value: Variant in genuine_values:
		original_serialization.append(_object_dict(genuine_value))
	var sentinel := "private-sentinel-must-not-be-echoed"
	issue.set("_code", sentinel)
	build_a.set("_decision_state", "reject")
	validation.set("_selected_indexes", [999999])
	resolution.set("_selected_indexes", [999999])
	pinned_build.set("_reason_code", sentinel)
	initial.set("_candidate_reason_code", sentinel)
	for genuine_value: Variant in genuine_values:
		genuine_value.set("_public_snapshot", {"reason_code": sentinel, "indexes": [999999]})
	for index: int in genuine_values.size():
		var serialized := _object_dict(genuine_values[index])
		if serialized != original_serialization[index] or JSON.stringify(serialized).contains(sentinel):
			failures.append("mutated result DTO leaked live or replacement snapshot data")
	if _call_static(WINDOW_SCRIPT_PATH, "validate_issue_integrity", [issue]) == true:
		failures.append("mutated SelectionIssue passed integrity")
	if _call_static(WINDOW_SCRIPT_PATH, "validate_build_result_integrity", [build_a]) == true:
		failures.append("mutated BuildResult passed integrity")
	if _call_static(SANITIZER_SCRIPT_PATH, "validate_result_integrity", [validation, window_a]) == true:
		failures.append("mutated SelectionValidation passed integrity")
	if _call_static(FALLBACK_SCRIPT_PATH, "validate_resolution_integrity", [resolution, window_a]) == true:
		failures.append("mutated SelectionResolution passed integrity")
	if _call_static(
		DECK_SCRIPT_PATH,
		"validate_build_result_integrity",
		[pinned_build, contracts]
	) == true:
		failures.append("mutated DeckBuildResult passed integrity")
	if _call_static(DECK_SCRIPT_PATH, "validate_resolution_integrity", [initial, pinned]) == true:
		failures.append("mutated InitialDeckResolution passed integrity")
	return "\n".join(failures)


func test_same_script_contract_mutation_invalidates_every_selection_owner() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var failures: Array[String] = []

	var profile_contracts: Variant = _contract_set()
	var mutated_profile: Dictionary = profile_contracts.get("selection_profile")
	var input_authority: Dictionary = mutated_profile.get("input_authority", {})
	(input_authority.get("accepted_public_hash_authorities", []) as Array).append("raw_private")
	profile_contracts.set("_selection_profile", mutated_profile)
	var private_input := _window_input(
		_base_select([_known_option(1)], 1, 1),
		HASH_A,
		"raw_private"
	)
	var private_build := _build_with_contracts(private_input, profile_contracts)
	if private_build.get("decision_state") != "reject" or private_build.get("window") != null:
		failures.append("same-script selection_profile mutation was trusted")

	var enum_contracts: Variant = _contract_set()
	var mutated_enums: Dictionary = enum_contracts.get("enum_snapshot")
	(mutated_enums.get("enums", {}).get("SelectType", {}) as Dictionary)["FORGED"] = 999
	enum_contracts.set("_enum_snapshot", mutated_enums)
	var unknown_select := _base_select([_known_option(1)], 1, 1)
	unknown_select["type"] = 999
	var enum_build := _build_with_contracts(_window_input(unknown_select), enum_contracts)
	if enum_build.get("decision_state") != "reject" or enum_build.get("window") != null:
		failures.append("same-script enum snapshot mutation was trusted")

	var shape_contracts: Variant = _contract_set()
	var mutated_shapes: Dictionary = shape_contracts.get("option_shapes")
	(mutated_shapes.get("shapes", {}) as Dictionary)["999"] = ["type"]
	shape_contracts.set("_option_shapes", mutated_shapes)
	var shape_build := _build_with_contracts(
		_window_input(_base_select([{"type": 999}], 1, 1)),
		shape_contracts
	)
	if shape_build.get("decision_state") != "reject" or shape_build.get("window") != null:
		failures.append("same-script option-shape mutation was trusted")

	var deck_contracts: Variant = _contract_set()
	var deck_profile: Dictionary = deck_contracts.get("selection_profile")
	var deck_authority: Dictionary = deck_profile.get("initial_deck_contract", {}).get(
		"conformance_authority",
		{}
	)
	var arbitrary_ids: Array = []
	for _index: int in 60:
		arbitrary_ids.append(7)
	deck_authority["card_ids"] = arbitrary_ids
	deck_authority["deck_hash"] = _sha256_profile_tree(
		DECK_PROFILE_TAG,
		{"card_ids": arbitrary_ids}
	)
	deck_contracts.set("_selection_profile", deck_profile)
	var arbitrary_manifest := {
		"profile": "cabt_initial_deck_v1",
		"card_ids": arbitrary_ids,
		"deck_hash": deck_authority.get("deck_hash"),
		"source_artifact_id": deck_authority.get("artifact_id"),
		"source_sha256": deck_authority.get("source_sha256"),
		"authority_scope": deck_authority.get("scope"),
	}
	var deck_build := _object_dict(
		_call_static(
			DECK_SCRIPT_PATH,
			"build_pinned_deck",
			[arbitrary_manifest, deck_contracts]
		)
	)
	if deck_build.get("accepted") != false or deck_build.get("pinned_deck") != null:
		failures.append("same-script pinned authority mutation was trusted")
	return "\n".join(failures)


func test_direct_policy_acceptance_cannot_bypass_the_sanitizer() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var window: Variant = _valid_window([_known_option(1), _known_option(2)], 2, 2)
	if window == null:
		return "direct acceptance control window failed to build"
	var invalid_proposals := [
		[-1, 999],
		[0],
		[0, 0],
		[true, 1],
		[0.0, 1],
		PackedInt32Array([0, 1]),
	]
	var failures: Array[String] = []
	for proposal: Variant in invalid_proposals:
		var bypass: Variant = _call_static(
			FALLBACK_SCRIPT_PATH,
			"accept_policy",
			[window, proposal]
		)
		if bypass != null:
			failures.append("direct accept_policy accepted %s" % str(proposal))
	var valid: Variant = _call_static(
		FALLBACK_SCRIPT_PATH,
		"accept_policy",
		[window, [1, 0]]
	)
	if _resolution_dict(valid).get("selected_indexes") != [1, 0]:
		failures.append("direct accept_policy rejected the exact valid ordered proposal")
	var fallback_only_window: Variant = _valid_window([{"type": 999}], 1, 1)
	if fallback_only_window == null:
		failures.append("direct acceptance fallback-only control window failed to build")
	else:
		var fallback_only_bypass: Variant = _call_static(
			FALLBACK_SCRIPT_PATH,
			"accept_policy",
			[fallback_only_window, [0]]
		)
		if fallback_only_bypass != null:
			failures.append("direct accept_policy accepted a fallback-only window")
	return "\n".join(failures)


func test_pinned_authority_is_factory_bound_and_revalidated_before_every_resolution() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var vectors := _shared_vectors()
	var authority := _pinned_authority_from_vectors(vectors)
	var build_result: Variant = _build_pinned_deck(authority)
	var pinned: Variant = _pinned_from_build(build_result)
	if pinned == null:
		return "pinned authority integrity control failed to build"
	var deck_script: Variant = _runtime_script(DECK_SCRIPT_PATH)
	var constants: Dictionary = (deck_script as GDScript).get_script_constant_map()
	var authority_class: Variant = constants.get("PinnedDeckAuthority")
	if authority_class == null or not authority_class.has_method("new"):
		return "PinnedDeckAuthority class must remain testable as an untrusted public constructor"
	var arbitrary_manifest := authority.duplicate(true)
	var arbitrary_ids: Array = []
	for _index: int in 60:
		arbitrary_ids.append(7)
	arbitrary_manifest["card_ids"] = arbitrary_ids
	arbitrary_manifest["deck_hash"] = _sha256_profile_tree(
		DECK_PROFILE_TAG,
		{"card_ids": arbitrary_ids}
	)
	var forged_pinned: Variant = authority_class.new(arbitrary_manifest)
	var expected_reject := {
		"accepted": false,
		"selected_card_ids": [],
		"owner": "none",
		"reason_code": "invalid_pinned_deck",
		"fallback_branch": null,
		"deck_hash": null,
		"candidate_reason_code": "invalid_pinned_deck",
	}
	var forged_resolution := _resolve_deck(forged_pinned, "returned", arbitrary_ids)
	var mutated_ids: Array = (authority.get("card_ids", []) as Array).duplicate(true)
	mutated_ids[59] = 1260
	pinned.set("_card_ids", mutated_ids)
	var mutated_ids_resolution := _resolve_deck(pinned, "unavailable", null)
	var fresh_pinned: Variant = _pinned_from_build(_build_pinned_deck(authority))
	fresh_pinned.set("_source_artifact_id", "spoofed_after_build")
	var mutated_source_resolution := _resolve_deck(fresh_pinned, "unavailable", null)
	return run_checks([
		assert_eq(forged_resolution, expected_reject),
		assert_eq(mutated_ids_resolution, expected_reject),
		assert_eq(mutated_source_resolution, expected_reject),
	])


func test_all_seventeen_locked_option_types_build_in_official_order() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var shape_contract := _load_json_object(OPTION_SHAPES_PATH)
	var option_types: Dictionary = shape_contract.get("option_types", {})
	var shapes: Dictionary = shape_contract.get("shapes", {})
	if option_types.size() != 17 or shapes.size() != 17:
		return "locked OptionType contract must contain exactly 17 shapes"
	var failures: Array[String] = []
	for raw_type: int in 17:
		var fields: Variant = shapes.get(str(raw_type))
		if not fields is Array:
			failures.append("missing sparse shape %d" % raw_type)
			continue
		var option := _option_from_shape(raw_type, fields)
		var result: Variant = _build_result(_window_input(_base_select([option], 0, 1)))
		var result_dict := _object_dict(result)
		var window: Variant = _window_from_result(result)
		var public_window := _window_dict(window)
		if result_dict.get("decision_state") != "policy_allowed":
			failures.append("OptionType %d did not build policy_allowed" % raw_type)
		elif public_window.get("options") != [option]:
			failures.append("OptionType %d raw option changed" % raw_type)
		elif (public_window.get("option_fingerprints", []) as Array).size() != 1:
			failures.append("OptionType %d did not receive one fingerprint" % raw_type)
	return "\n".join(failures)


func test_unknown_enums_and_sparse_drift_are_fallback_only_not_policy_calls() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var cases := [
		{"name": "unknown_select_type", "select": _base_select([_known_option(1)], 1, 1), "mutate": "type"},
		{"name": "unknown_select_context", "select": _base_select([_known_option(1)], 1, 1), "mutate": "context"},
		{"name": "unknown_option_type", "select": _base_select([{"type": 999}], 1, 1), "mutate": "none"},
		{"name": "missing_sparse_field", "select": _base_select([{"type": 3, "area": 1, "index": 0}], 1, 1), "mutate": "none"},
		{"name": "present_null", "select": _base_select([{"type": 3, "area": 1, "index": 0, "playerIndex": null}], 1, 1), "mutate": "none"},
	]
	var failures: Array[String] = []
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		var select_value: Dictionary = case.get("select", {})
		if case.get("mutate") == "type":
			select_value["type"] = 999
		elif case.get("mutate") == "context":
			select_value["context"] = 999
		var result: Variant = _build_result(_window_input(select_value))
		var result_dict := _object_dict(result)
		var window: Variant = _window_from_result(result)
		if result_dict.get("decision_state") != "fallback_only" or window == null:
			failures.append("%s must retain a fallback-only window" % case.get("name"))
			continue
		var resolution := _resolve_attempt(window, "returned", [0])
		if resolution.get("owner") != "deterministic_fallback":
			failures.append("%s must ignore policy output" % case.get("name"))
		elif resolution.get("reason_code") != "window_fallback_only":
			failures.append("%s fallback reason drifted" % case.get("name"))
	return "\n".join(failures)


func test_strict_cardinality_rejects_every_value_outside_zero_min_max_option_count_chain() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var options := [_known_option(1), _known_option(2)]
	var invalid_cases := [
		{"name": "negative_min", "min": -1, "max": 0, "count": 2},
		{"name": "min_above_max", "min": 2, "max": 1, "count": 2},
		{"name": "max_above_options", "min": 0, "max": 3, "count": 2},
		{"name": "min_above_options", "min": 3, "max": 3, "count": 2},
	]
	var failures: Array[String] = []
	for case_value: Variant in invalid_cases:
		var case: Dictionary = case_value
		var select_value := _base_select(options, int(case.get("min")), int(case.get("max")))
		var result_dict := _build_dict(_window_input(select_value))
		if result_dict.get("decision_state") != "reject":
			failures.append("%s must reject" % case.get("name"))
		elif result_dict.get("window") != null:
			failures.append("%s must not expose a window" % case.get("name"))
		elif "invalid_cardinality" not in _issue_codes(result_dict):
			failures.append("%s must report invalid_cardinality" % case.get("name"))
	var valid := _build_dict(_window_input(_base_select(options, 0, 2)))
	if valid.get("decision_state") != "policy_allowed":
		failures.append("0 <= min <= max <= n boundary should build")
	return "\n".join(failures)


func test_builder_rejects_non_exact_variant_types_and_never_echoes_unknown_keys() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var valid_select := _base_select([_known_option(1)], 0, 1)
	var cases := [
		{"name": "hash_string_name", "input": _window_input(valid_select, StringName(HASH_A))},
		{"name": "hash_lowercase", "input": _window_input(valid_select, HASH_A.to_lower())},
		{"name": "authority_string_name", "input": _window_input(valid_select, HASH_A, StringName("conformance_fixture"))},
		{"name": "chooser_bool", "input": _window_input(valid_select, HASH_A, "conformance_fixture", true)},
		{"name": "chooser_float", "input": _window_input(valid_select, HASH_A, "conformance_fixture", 0.0)},
	]
	var bool_select := valid_select.duplicate(true)
	bool_select["minCount"] = false
	cases.append({"name": "min_bool", "input": _window_input(bool_select)})
	var float_select := valid_select.duplicate(true)
	float_select["maxCount"] = 1.0
	cases.append({"name": "max_float", "input": _window_input(float_select)})
	var packed_select := valid_select.duplicate(true)
	packed_select["option"] = PackedInt32Array([1])
	cases.append({"name": "packed_option", "input": _window_input(packed_select)})
	var string_name_key_option := {}
	string_name_key_option[StringName("type")] = 1
	var string_name_select := valid_select.duplicate(true)
	string_name_select["option"] = [string_name_key_option]
	cases.append({"name": "option_string_name_key", "input": _window_input(string_name_select)})
	var failures: Array[String] = []
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		var result_dict := _build_dict(case.get("input", {}))
		if result_dict.get("decision_state") != "reject" or result_dict.get("window") != null:
			failures.append("%s must reject exact-type violation" % case.get("name"))

	var secret_select := valid_select.duplicate(true)
	(secret_select.get("option", [])[0] as Dictionary)["secretSentinelKey"] = "secretSentinelValue"
	var secret_result := _build_dict(_window_input(secret_select))
	var secret_text := JSON.stringify(secret_result)
	if secret_result.get("decision_state") != "reject":
		failures.append("unknown public option key must reject")
	if secret_text.contains("secretSentinelKey") or secret_text.contains("secretSentinelValue"):
		failures.append("unknown key/value leaked into diagnostics")
	if "unknown_public_key" not in _issue_codes(secret_result):
		failures.append("unknown public key reason missing")
	for forbidden_key: String in ["callback_binding_hash", "search_begin_input", "raw_private_hash"]:
		var private_input := _window_input(valid_select)
		private_input[forbidden_key] = "privateSentinelDoNotEcho"
		var private_result := _build_dict(private_input)
		var private_text := JSON.stringify(private_result)
		if private_result.get("decision_state") != "reject":
			failures.append("%s must never enter a public selection window" % forbidden_key)
		if private_text.contains(forbidden_key) or private_text.contains("privateSentinelDoNotEcho"):
			failures.append("%s leaked into public diagnostics" % forbidden_key)
	return "\n".join(failures)


func test_window_and_result_serialization_are_json_exact_and_deeply_immutable() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var select_value := _base_select([_known_option(3), _known_option(15)], 1, 2)
	select_value["deck"] = [_card(101, 501), _card(102, 502)]
	select_value["contextCard"] = _card(201, 601)
	select_value["effect"] = _card(301, 701)
	var input_value := _window_input(select_value)
	var result: Variant = _build_result(input_value)
	var result_dict := _object_dict(result)
	var window: Variant = _window_from_result(result)
	if window == null:
		return "immutable fixture failed to build"
	var before := _canonical_text(_window_dict(window))
	(input_value.get("select", {}).get("option", [])[0] as Dictionary)["type"] = 2
	(input_value.get("select", {}).get("deck", [])[0] as Dictionary)["serial"] = 999999
	(input_value.get("select", {}).get("contextCard", {}) as Dictionary)["serial"] = 999999
	var returned := _window_dict(window)
	var returned_options: Variant = returned.get("options")
	if returned_options is Array and not (returned_options as Array).is_read_only():
		var returned_option: Variant = (returned_options as Array)[0]
		if returned_option is Dictionary and not (returned_option as Dictionary).is_read_only():
			(returned_option as Dictionary)["type"] = 2
	var returned_deck: Variant = returned.get("public_deck_candidates")
	if returned_deck is Array and not (returned_deck as Array).is_read_only():
		var returned_card: Variant = (returned_deck as Array)[0]
		if returned_card is Dictionary and not (returned_card as Dictionary).is_read_only():
			(returned_card as Dictionary)["serial"] = 999999
	var returned_context: Variant = returned.get("context_card")
	if returned_context is Dictionary and not (returned_context as Dictionary).is_read_only():
		(returned_context as Dictionary)["serial"] = 999999
	var after := _canonical_text(_window_dict(window))
	var canonical_result: Dictionary = CabtJsonTreeScript.canonicalize(result_dict)
	return run_checks([
		assert_false(before.is_empty()),
		assert_eq(after, before, "window must retain no caller/getter nested aliases"),
		assert_true(bool(canonical_result.get("ok", false)), "BuildResult must serialize as an exact JSON tree"),
		assert_eq(_window_dict(window).get("options")[0].get("type"), 3),
		assert_eq(_window_dict(window).get("public_deck_candidates")[0].get("serial"), 501),
		assert_eq(_window_dict(window).get("context_card").get("serial"), 601),
	])


func test_fingerprint_raw_authority_distinguishes_presence_context_public_hash_and_reorder() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var missing_select := _base_select([{"type": 3, "area": 1, "index": 0}], 0, 1)
	var null_select := _base_select([{"type": 3, "area": 1, "index": 0, "playerIndex": null}], 0, 1)
	var base_select := _base_select([_known_option(1), _known_option(2)], 0, 1)
	base_select["contextCard"] = _card(100, 10)
	base_select["effect"] = _card(200, 20)
	var context_changed := base_select.duplicate(true)
	(context_changed.get("contextCard", {}) as Dictionary)["serial"] = 11
	var effect_changed := base_select.duplicate(true)
	(effect_changed.get("effect", {}) as Dictionary)["serial"] = 21
	var reordered := base_select.duplicate(true)
	reordered["option"] = [_known_option(2), _known_option(1)]
	var windows := []
	for input_value: Dictionary in [
		_window_input(missing_select),
		_window_input(null_select),
		_window_input(base_select),
		_window_input(context_changed),
		_window_input(effect_changed),
		_window_input(base_select, HASH_B),
		_window_input(reordered),
	]:
		var window: Variant = _window_from_result(_build_result(input_value))
		if window == null:
			return "fingerprint mutation fixture failed to retain a window"
		windows.append(_window_dict(window))
	var ids := []
	for window_value: Variant in windows:
		ids.append((window_value as Dictionary).get("window_id"))
	var unique_ids := {}
	for id_value: Variant in ids:
		unique_ids[id_value] = true
	return run_checks([
		assert_eq(unique_ids.size(), windows.size(), "every raw-authority mutation must change window_id"),
		assert_true(windows[0].get("options")[0].has("playerIndex") == false, "missing must stay missing"),
		assert_true(windows[1].get("options")[0].has("playerIndex"), "present null must stay present"),
		assert_eq(windows[1].get("options")[0].get("playerIndex"), null),
		assert_eq(windows[6].get("options")[0].get("type"), 2, "reordered official position must be preserved"),
		assert_true(windows[2].get("option_fingerprints") != windows[6].get("option_fingerprints")),
	])


func test_sanitizer_accepts_only_exact_array_of_unique_ints_and_preserves_order() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var window: Variant = _valid_window([_known_option(1), _known_option(2)], 2, 2)
	if window == null:
		return "sanitizer fixture failed to build"
	var accepted := _resolve_attempt(window, "returned", [1, 0])
	var invalid_cases := [
		{"name": "not_array", "value": "0,1"},
		{"name": "packed_array", "value": PackedInt32Array([0, 1])},
		{"name": "bool_index", "value": [true, 1]},
		{"name": "float_index", "value": [0.0, 1]},
		{"name": "string_name_index", "value": [StringName("0"), 1]},
		{"name": "too_few", "value": [0]},
		{"name": "too_many", "value": [0, 1, 0]},
		{"name": "negative", "value": [-1, 0]},
		{"name": "upper_bound", "value": [0, 2]},
		{"name": "duplicate", "value": [1, 1]},
	]
	var failures: Array[String] = []
	if accepted.get("owner") != "policy" or accepted.get("selected_indexes") != [1, 0]:
		failures.append("valid ordered proposal must remain [1, 0]")
	for case_value: Variant in invalid_cases:
		var case: Dictionary = case_value
		var resolution := _resolve_attempt(window, "returned", case.get("value"))
		if resolution.get("owner") != "deterministic_fallback":
			failures.append("%s must fall back atomically" % case.get("name"))
		elif resolution.get("reason_code") != "invalid_policy_output":
			failures.append("%s reason must be invalid_policy_output" % case.get("name"))
		elif resolution.get("selected_indexes") != [0, 1]:
			failures.append("%s must discard the whole proposal" % case.get("name"))
	return "\n".join(failures)


func test_deterministic_fallback_branches_and_policy_faults_use_only_current_window() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var optional_window: Variant = _valid_window([_known_option(1), _known_option(2)], 0, 1)
	var forced_window: Variant = _valid_window([_known_option(1), _known_option(2)], 2, 2)
	var first_window: Variant = _valid_window([_known_option(1), _known_option(2), _known_option(1)], 2, 3)
	if optional_window == null or forced_window == null or first_window == null:
		return "fallback fixture failed to build"
	var optional := _fallback(optional_window, "policy_timeout")
	var forced := _fallback(forced_window, "policy_timeout")
	var first := _fallback(first_window, "policy_timeout")
	var checks: Array[String] = [
		assert_eq(optional.get("selected_indexes"), []),
		assert_eq(optional.get("fallback_branch"), "optional_zero"),
		assert_eq(forced.get("selected_indexes"), [0, 1]),
		assert_eq(forced.get("fallback_branch"), "forced_all"),
		assert_eq(first.get("selected_indexes"), [0, 1]),
		assert_eq(first.get("fallback_branch"), "first_minimum"),
	]
	for status: String in ["exception", "timeout", "unavailable"]:
		var resolution := _resolve_attempt(first_window, status)
		checks.append(assert_eq(resolution.get("owner"), "deterministic_fallback"))
		checks.append(assert_eq(resolution.get("reason_code"), "policy_%s" % status))
		checks.append(assert_eq(resolution.get("selected_indexes"), [0, 1]))
	return run_checks(checks)


func test_new_window_recomputes_fallback_and_never_reuses_prior_indexes_or_fingerprints() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var first_result: Variant = _build_result(
		_window_input(_base_select([_known_option(1), _known_option(2)], 1, 1), HASH_A)
	)
	var second_result: Variant = _build_result(
		_window_input(_base_select([_known_option(2), _known_option(1)], 1, 1), HASH_B)
	)
	var first_window: Variant = _window_from_result(first_result)
	var second_window: Variant = _window_from_result(second_result)
	if first_window == null or second_window == null:
		return "reobserve fixture failed to build"
	var first_public := _window_dict(first_window)
	var second_public := _window_dict(second_window)
	var first_resolution := _fallback(first_window, "policy_timeout")
	var second_resolution := _fallback(second_window, "policy_timeout")
	return run_checks([
		assert_true(first_public.get("window_id") != second_public.get("window_id")),
		assert_true(first_public.get("option_fingerprints") != second_public.get("option_fingerprints")),
		assert_eq(first_resolution.get("selected_indexes"), [0]),
		assert_eq(second_resolution.get("selected_indexes"), [0]),
		assert_eq(first_public.get("options")[0].get("type"), 1),
		assert_eq(second_public.get("options")[0].get("type"), 2),
		assert_eq(second_resolution.get("window_id"), second_public.get("window_id")),
	])


func test_initial_deck_is_a_separate_exact_sixty_card_domain_with_local_fallback() -> String:
	var readiness := _runtime_ready_error()
	if not readiness.is_empty():
		return readiness
	var card_ids := _official_marnie_ids()
	if card_ids.size() != 60:
		return "official pinned conformance deck must contain exactly 60 IDs"
	var build_result: Variant = _build_pinned_deck(_pinned_manifest(card_ids))
	var build_dict := _object_dict(build_result)
	var pinned: Variant = _pinned_from_build(build_result)
	if pinned == null:
		return "valid source-locked pinned deck failed to build: %s" % JSON.stringify(build_dict)
	var valid := _resolve_deck(pinned, "returned", card_ids.duplicate(true))
	var short_deck := card_ids.slice(0, 59)
	var long_deck := card_ids.duplicate(true)
	long_deck.append(7)
	var bool_deck := card_ids.duplicate(true)
	bool_deck[0] = true
	var float_deck := card_ids.duplicate(true)
	float_deck[0] = 7.0
	var mismatch_deck := card_ids.duplicate(true)
	mismatch_deck[0] = 8
	var invalid_cases := [
		{"name": "59", "value": short_deck},
		{"name": "61", "value": long_deck},
		{"name": "bool", "value": bool_deck},
		{"name": "float", "value": float_deck},
		{"name": "mismatch", "value": mismatch_deck},
		{"name": "packed", "value": PackedInt32Array(card_ids)},
	]
	var failures: Array[String] = []
	if (
		valid.get("accepted") != true
		or valid.get("owner") != "initial_candidate"
		or valid.get("selected_card_ids") != card_ids
	):
		failures.append("exact pinned 60-card output must be accepted")
	for case_value: Variant in invalid_cases:
		var case: Dictionary = case_value
		var resolution := _resolve_deck(pinned, "returned", case.get("value"))
		if resolution.get("accepted") != true:
			failures.append("%s candidate must use verified local deck fallback" % case.get("name"))
		elif resolution.get("owner") != "pinned_deck_fallback":
			failures.append("%s candidate owner drifted" % case.get("name"))
		elif resolution.get("selected_card_ids") != card_ids:
			failures.append("%s candidate did not return a fresh pinned deck" % case.get("name"))
		elif resolution.get("fallback_branch") != "pinned_verified_deck":
			failures.append("%s candidate did not report pinned fallback" % case.get("name"))
	for status: String in ["exception", "timeout", "unavailable"]:
		var resolution := _resolve_deck(pinned, status, null)
		if resolution.get("owner") != "pinned_deck_fallback":
			failures.append("deck %s must remain local pinned fallback" % status)
	return "\n".join(failures)
