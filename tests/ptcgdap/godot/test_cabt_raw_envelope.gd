class_name TestCabtRawEnvelope
extends TestBase

const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const CabtObservationParserScript = preload("res://scripts/ai/ptcgdap/cabt/CabtObservationParser.gd")
const FIXTURE_ROOT := "res://tests/ptcgdap/fixtures/public"
const SAFE_METADATA_GOLDEN := "res://tests/ptcgdap/fixtures/public/normal_single_select.safe_metadata.golden.json"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991


func _restore_fixture_integer_tokens(value: Variant) -> Variant:
	if value is Dictionary:
		var restored := {}
		for key: Variant in (value as Dictionary).keys():
			restored[key] = _restore_fixture_integer_tokens((value as Dictionary)[key])
		return restored
	if value is Array:
		var restored := []
		for child: Variant in value:
			restored.append(_restore_fixture_integer_tokens(child))
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


func _load_fixture(fixture_name: String) -> Dictionary:
	var file := FileAccess.open("%s/%s.json" % [FIXTURE_ROOT, fixture_name], FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return _restore_fixture_integer_tokens(parsed) if parsed is Dictionary else {}


func _load_json_object(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _file_sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(file.get_buffer(file.get_length())) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


func _canonical_json_text(value: Variant) -> String:
	var result: Dictionary = CabtJsonTreeScript.canonicalize(value)
	return str(result.get("text", "")) if bool(result.get("ok", false)) else ""


func _contract_set() -> Variant:
	return CabtContractSetScript.load_default()


func _forged_parser_contracts(real_contracts: Variant) -> Variant:
	var forged: Variant = CabtContractSetScript.new()
	forged.set("_ok", true)
	forged.set("_source_lock_id", real_contracts.get("source_lock_id"))
	forged.set("_source_contract_hash", real_contracts.get("source_contract_hash"))
	forged.set("_typed_profile", real_contracts.get("typed_profile"))
	forged.set("_enum_snapshot", real_contracts.get("enum_snapshot"))
	return forged


func _unknown_by_pointer(envelope: Variant) -> Dictionary:
	var result := {}
	for entry_value: Variant in envelope.unknown_fields:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			result[str(entry.get("pointer", ""))] = entry
	return result


func _enum_by_pointer(envelope: Variant) -> Dictionary:
	var result := {}
	for entry_value: Variant in envelope.enum_values:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			result[str(entry.get("pointer", ""))] = entry
	return result


func _issue_keys(issues: Array) -> Dictionary:
	var result := {}
	for issue_value: Variant in issues:
		if issue_value is Dictionary:
			var issue: Dictionary = issue_value
			result["%s|%s|%s" % [issue.get("code", ""), issue.get("pointer", ""), issue.get("severity", "")]] = true
	return result


func test_every_public_golden_round_trips_without_aliasing_or_field_loss() -> String:
	var contracts: Variant = _contract_set()
	if contracts == null or not contracts.ok:
		return "CABT contract set failed to load: %s" % ("null" if contracts == null else contracts.error_code)
	var fixture_names := [
		"initial_callback",
		"normal_single_select",
		"optional_zero_deck_search",
		"normal_multi_select",
		"ordered_skill_multi_select",
		"engine_only_area_log",
		"unknown_additive_and_enum",
	]
	var failures: Array[String] = []
	for fixture_name: String in fixture_names:
		var original := _load_fixture(fixture_name)
		if original.is_empty():
			failures.append("%s fixture failed to load" % fixture_name)
			continue
		var caller_tree: Dictionary = original.duplicate(true)
		var parse_result: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(caller_tree, contracts)
		if parse_result.envelope == null:
			failures.append("%s parse failed: %s" % [fixture_name, JSON.stringify(parse_result.safe_diagnostics())])
			continue
		var envelope: Variant = parse_result.envelope
		if envelope.raw_payload != original:
			failures.append("%s raw round-trip changed" % fixture_name)
		if envelope.source_contract_hash != contracts.source_contract_hash:
			failures.append("%s source contract hash mismatch" % fixture_name)
		if envelope.firewall_status != "pending" or envelope.public_observation_hash != null:
			failures.append("%s crossed the public firewall early" % fixture_name)
		var original_hash: String = envelope.raw_private_hash
		caller_tree["caller_mutation"] = ["must", "not", "alias"]
		var returned: Dictionary = envelope.raw_payload
		returned["getter_mutation"] = true
		if envelope.raw_payload.has("caller_mutation") or envelope.raw_payload.has("getter_mutation"):
			failures.append("%s retained a mutable raw alias" % fixture_name)
		if envelope.raw_private_hash != original_hash:
			failures.append("%s stored hash changed after caller mutation" % fixture_name)
	return "\n".join(failures)


func test_nested_unknowns_presence_and_enum_authority_match_python_contract() -> String:
	var contracts: Variant = _contract_set()
	if contracts == null or not contracts.ok:
		return "CABT contract set failed to load: %s" % ("null" if contracts == null else contracts.error_code)
	var unknown_result: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(
		_load_fixture("unknown_additive_and_enum"), contracts
	)
	var single_result: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(
		_load_fixture("normal_single_select"), contracts
	)
	var engine_result: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(
		_load_fixture("engine_only_area_log"), contracts
	)
	if unknown_result.envelope == null or single_result.envelope == null or engine_result.envelope == null:
		return "one or more CABT fixtures failed to parse"

	var unknown_envelope: Variant = unknown_result.envelope
	var known: Dictionary = unknown_envelope.known_view
	var unknown: Dictionary = _unknown_by_pointer(unknown_envelope)
	var unknown_enums: Dictionary = _enum_by_pointer(unknown_envelope)
	var single_envelope: Variant = single_result.envelope
	var single_enums: Dictionary = _enum_by_pointer(single_envelope)
	var engine_enums: Dictionary = _enum_by_pointer(engine_result.envelope)
	var issues: Dictionary = _issue_keys(unknown_result.issues)
	return run_checks([
		assert_eq(known.keys().size(), 3, "known view root must contain exactly three fields"),
		assert_false(known.has("futureHostField")),
		assert_false((known.get("select", {}) as Dictionary).has("futureSelectField")),
		assert_false(((known.get("select", {}) as Dictionary).get("option", [])[0] as Dictionary).has("futureOptionPayload")),
		assert_false((known.get("logs", [])[0] as Dictionary).has("futureLogPayload")),
		assert_eq(unknown.get("/futureHostField", {}).get("json_type"), "object"),
		assert_eq(unknown.get("/select/futureSelectField", {}).get("json_type"), "object"),
		assert_eq(unknown.get("/select/option/0/futureOptionPayload", {}).get("json_type"), "object"),
		assert_eq(unknown.get("/logs/0/futureLogPayload", {}).get("json_type"), "object"),
		assert_eq(single_envelope.field_presence.get("/select/deck"), "null"),
		assert_eq(single_envelope.field_presence.get("/select/option/0/type"), "value"),
		assert_eq(single_envelope.field_presence.get("/select/option/0/number"), "missing"),
		assert_eq(single_envelope.framework.get("step"), 1),
		assert_eq(single_envelope.framework.get("remaining_overage_time"), 599.685885),
		assert_eq(single_enums.get("/select/type", {}).get("known_name"), "YES_NO"),
		assert_eq(single_enums.get("/select/type", {}).get("authority"), "official_known"),
		assert_eq(engine_enums.get("/logs/1/toArea", {}).get("raw_int"), 14),
		assert_eq(engine_enums.get("/logs/1/toArea", {}).get("known_name"), "DECK_BOTTOM_INTERNAL"),
		assert_eq(engine_enums.get("/logs/1/toArea", {}).get("authority"), "locked_engine_only"),
		assert_eq(unknown_enums.get("/select/type", {}).get("raw_int"), 99),
		assert_eq(unknown_enums.get("/select/type", {}).get("known_name"), null),
		assert_eq(unknown_enums.get("/select/type", {}).get("authority"), "unknown_future"),
		assert_false(unknown_result.policy_eligible, "unknown enum must not be policy eligible"),
		assert_true(issues.has("unknown_enum_value|/select/type|error")),
		assert_true(issues.has("unknown_enum_value|/select/context|error")),
		assert_true(issues.has("unknown_enum_value|/select/option/0/type|error")),
		assert_true(issues.has("unknown_enum_value|/logs/0/type|error")),
	])


func test_search_is_opaque_and_safe_metadata_never_contains_token_or_private_hashes() -> String:
	var contracts: Variant = _contract_set()
	if contracts == null or not contracts.ok:
		return "CABT contract set failed to load: %s" % ("null" if contracts == null else contracts.error_code)
	var raw := _load_fixture("normal_single_select")
	raw["search_begin_input"] = "top-secret-token"
	raw["a/b~c"] = {"private-value": 42}
	raw["secret-key-name"] = null
	var result: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(raw, contracts)
	if result.envelope == null:
		return "token-bearing callback failed to parse"
	var envelope: Variant = result.envelope
	var safe: Dictionary = envelope.safe_metadata()
	var safe_text := JSON.stringify(safe)
	var unknown: Dictionary = _unknown_by_pointer(envelope)
	return run_checks([
		assert_true(result.policy_eligible),
		assert_true(envelope.opaque_search_capability_present),
		assert_false(envelope.known_view.has("search_begin_input")),
		assert_false(safe.has("raw_payload")),
		assert_false(safe.has("raw_private_hash")),
		assert_false(safe.has("token_free_callback_hash")),
		assert_false((safe.get("field_presence", {}) as Dictionary).has("/search_begin_input")),
		assert_true(safe_text.find("top-secret-token") == -1),
		assert_true(safe_text.find("private-value") == -1),
		assert_true(safe_text.find("search_begin_input") == -1),
		assert_true(safe_text.find("secret-key-name") == -1),
		assert_eq(unknown.get("/a~1b~0c", {}).get("json_type"), "object"),
		assert_true(unknown.has("/secret-key-name")),
	])


func test_safe_metadata_matches_python_generated_golden_exactly() -> String:
	var contracts: Variant = _contract_set()
	if contracts == null or not contracts.ok:
		return "CABT contract set failed to load: %s" % ("null" if contracts == null else contracts.error_code)
	var golden_document := _load_json_object(SAFE_METADATA_GOLDEN)
	var provenance: Dictionary = golden_document.get("provenance", {})
	var expected: Dictionary = golden_document.get("safe_metadata", {})
	if provenance.is_empty() or expected.is_empty():
		return "Python safe-metadata golden or provenance failed to load"
	var result: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(
		_load_fixture("normal_single_select"), contracts
	)
	if result.envelope == null:
		return "normal_single_select failed to parse"
	var golden_text := JSON.stringify(expected)
	return run_checks([
		assert_eq(
			provenance.get("generator"),
			"scripts.ai.ptcgdap.cabt_envelope.parse_raw_cabt_envelope"
		),
		assert_eq(provenance.get("projection"), "RawCabtEnvelope.safe_metadata"),
		assert_eq(provenance.get("visibility"), "safe_metadata_only"),
		assert_eq(
			_file_sha256("res://scripts/ai/ptcgdap/cabt_envelope.py"),
			provenance.get("generator_sha256")
		),
		assert_eq(
			_file_sha256("res://tests/ptcgdap/fixtures/public/normal_single_select.json"),
			provenance.get("source_fixture_sha256")
		),
		assert_eq(
			_file_sha256("res://contracts/ptcgdap/cabt_typed_view_profile.json"),
			provenance.get("typed_profile_sha256")
		),
		assert_eq(
			_file_sha256("res://contracts/ptcgdap/cabt_enum_snapshot.json"),
			provenance.get("enum_snapshot_sha256")
		),
		assert_true(golden_text.find("raw_payload") == -1),
		assert_true(golden_text.find("raw_private_hash") == -1),
		assert_true(golden_text.find("token_free_callback_hash") == -1),
		assert_eq(
			_canonical_json_text(result.envelope.safe_metadata()),
			_canonical_json_text(expected),
			"GDScript safe metadata must equal the Python golden as a JSON tree"
		),
	])


func test_structural_and_bounded_errors_fail_closed_without_echoing_values() -> String:
	var contracts: Variant = _contract_set()
	if contracts == null or not contracts.ok:
		return "CABT contract set failed to load: %s" % ("null" if contracts == null else contracts.error_code)
	var missing := _load_fixture("initial_callback")
	missing.erase("select")
	var missing_result: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(missing, contracts)

	var bool_enum := _load_fixture("normal_single_select")
	(bool_enum.get("select", {}) as Dictionary)["type"] = true
	var bool_result: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(bool_enum, contracts)
	var float_enum := _load_fixture("normal_single_select")
	(float_enum.get("select", {}) as Dictionary)["type"] = 9.0
	var float_result: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(float_enum, contracts)

	var bad_search := _load_fixture("initial_callback")
	bad_search["search_begin_input"] = {"token": "must-not-echo"}
	var search_result: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(bad_search, contracts)

	var nonfinite := _load_fixture("initial_callback")
	nonfinite["remainingOverageTime"] = INF
	var finite_result: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(nonfinite, contracts)
	var injected_contract_result: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(
		_load_fixture("initial_callback"),
		{"ok": true, "typed_profile": {}, "enum_snapshot": {}}
	)
	var returned_issues: Array = bool_result.issues
	returned_issues.clear()
	var partial_known_view: Dictionary = bool_result.envelope.known_view if bool_result.envelope != null else {}
	return run_checks([
		assert_eq(missing_result.envelope, null),
		assert_false(missing_result.policy_eligible),
		assert_true(_issue_keys(missing_result.issues).has("missing_required_field|/select|error")),
		assert_not_null(bool_result.envelope),
		assert_false(bool_result.policy_eligible, "returned issues must not alias eligibility state"),
		assert_true(_issue_keys(bool_result.issues).has("invalid_enum_type|/select/type|error")),
		assert_eq(partial_known_view.keys().size(), 3, "typed-view errors must retain schema roots"),
		assert_true(partial_known_view.has("select")),
		assert_false((partial_known_view.get("select", {}) as Dictionary).has("type")),
		assert_not_null(float_result.envelope),
		assert_false(float_result.policy_eligible, "integral floats cannot impersonate wire integers"),
		assert_true(_issue_keys(float_result.issues).has("invalid_enum_type|/select/type|error")),
		assert_eq(search_result.envelope, null),
		assert_true(JSON.stringify(search_result.safe_diagnostics()).find("must-not-echo") == -1),
		assert_eq(finite_result.envelope, null),
		assert_true(_issue_keys(finite_result.issues).has("invalid_json_tree||error")),
		assert_eq(injected_contract_result.envelope, null),
		assert_true(
			_issue_keys(injected_contract_result.issues).has("contract_runtime_error||error")
		),
	])


func test_direct_contract_forgery_and_loaded_contract_mutation_never_issue_an_envelope() -> String:
	var real_contracts: Variant = _contract_set()
	if real_contracts == null or not real_contracts.ok:
		return "CABT contract set failed to load"
	var raw := _load_fixture("normal_single_select")
	var forged_result: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(
		raw,
		_forged_parser_contracts(real_contracts)
	)

	var mutated_contracts: Variant = _contract_set()
	var mutated_profile: Dictionary = mutated_contracts.get("typed_profile")
	mutated_profile["forged_runtime_authority"] = true
	mutated_contracts.set("_typed_profile", mutated_profile)
	var mutated_result: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(
		raw,
		mutated_contracts
	)
	return run_checks([
		assert_eq(forged_result.envelope, null),
		assert_false(forged_result.policy_eligible),
		assert_true(
			_issue_keys(forged_result.issues).has("contract_runtime_error||error")
		),
		assert_eq(mutated_result.envelope, null),
		assert_false(mutated_result.policy_eligible),
		assert_true(
			_issue_keys(mutated_result.issues).has("contract_runtime_error||error")
		),
	])
