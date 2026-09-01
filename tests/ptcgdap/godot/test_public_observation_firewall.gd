class_name TestPublicObservationFirewall
extends TestBase

const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtObservationParserScript = preload("res://scripts/ai/ptcgdap/cabt/CabtObservationParser.gd")
const EXPECTED_FIREWALL_HASH := "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"
const VECTOR_PATH := "res://contracts/ptcgdap/cabt_public_firewall_conformance_vectors.json"
const FIXTURE_ROOT := "res://tests/ptcgdap/fixtures/public"
const TEMP_ROOT := "user://ptcgdap_public_firewall_trust"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const CONTRACT_FILES := [
	"raw_cabt_envelope.schema.json",
	"cabt_tree_hash_profile.json",
	"cabt_enum_snapshot.json",
	"cabt_option_sparse_shapes.json",
	"cabt_typed_view_profile.json",
	"cabt_tree_hash_conformance_vectors.json",
	"cabt_selection_window.schema.json",
	"cabt_selection_profile.json",
	"cabt_selection_conformance_vectors.json",
	"cabt_contract_bundle.json",
	"cabt_public_observation.schema.json",
	"cabt_public_firewall_profile.json",
	"cabt_public_firewall_conformance_vectors.json",
	"cabt_public_firewall_bundle.json",
]


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


func _read_contract(path: String) -> Variant:
	var parsed: Dictionary = FirewallScript._parse_contract_json_bytes(_read_bytes(path))
	return parsed.get("value") if bool(parsed.get("ok", false)) else null


func _load_fixture(name: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(_read_bytes("%s/%s.json" % [FIXTURE_ROOT, name]).get_string_from_utf8())
	return _restore_fixture_numbers(parsed) if parsed is Dictionary else {}


func _restore_fixture_numbers(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[key] = _restore_fixture_numbers(value[key])
		return result
	if value is Array:
		var result := []
		for child: Variant in value:
			result.append(_restore_fixture_numbers(child))
		return result
	if typeof(value) == TYPE_FLOAT:
		var number := float(value)
		if is_finite(number) and number == floorf(number) and number >= -float(MAX_SAFE_INTEGER) and number <= float(MAX_SAFE_INTEGER):
			return int(number)
	return value


func _materialize(value: Variant) -> Variant:
	if value is Dictionary:
		if value.get("host_type") == "string_name" and value.size() == 2:
			return StringName(str(value.get("value")))
		if value.get("host_type") == "unsafe_integer" and value.size() == 2:
			return int(str(value.get("decimal")))
		var result := {}
		for key: Variant in value:
			result[key] = _materialize(value[key])
		return result
	if value is Array:
		var result := []
		for child: Variant in value:
			result.append(_materialize(child))
		return result
	return value


func _apply_mutation(root: Variant, mutation: Dictionary) -> String:
	var path: Array = mutation.get("path", [])
	if path.is_empty():
		return "empty mutation path"
	var parent: Variant = root
	for index: int in range(path.size() - 1):
		parent = parent[path[index]]
	var key: Variant = path[-1]
	match str(mutation.get("op")):
		"set":
			parent[key] = _materialize((mutation.get("value") as Variant).duplicate(true) if mutation.get("value") is Dictionary or mutation.get("value") is Array else mutation.get("value"))
		"delete":
			parent.erase(key)
		"append":
			parent[key].append(_materialize((mutation.get("value") as Variant).duplicate(true) if mutation.get("value") is Dictionary or mutation.get("value") is Array else mutation.get("value")))
		_:
			return "unknown mutation"
	return ""


func _case_input(vectors: Dictionary, case: Dictionary) -> Dictionary:
	var bases: Dictionary = vectors.get("base_observations", {})
	var raw: Dictionary = _materialize((bases.get(case.get("base")) as Dictionary).duplicate(true))
	for mutation_value: Variant in case.get("mutations", []):
		if mutation_value is Dictionary:
			_apply_mutation(raw, mutation_value)
	return raw


func _parse(raw: Dictionary, contracts: Variant) -> Variant:
	return CabtObservationParserScript.parse_raw_cabt_envelope(raw, contracts)


func test_default_firewall_and_all_shared_vectors_match_exactly() -> String:
	var vectors_value: Variant = _read_contract(VECTOR_PATH)
	if not vectors_value is Dictionary:
		return "failed to load shared vectors"
	var vectors: Dictionary = vectors_value
	var cases: Variant = vectors.get("cases")
	if not cases is Array or cases.size() != 23:
		return "shared case count differs"
	var contracts: Variant = CabtContractSetScript.load_default()
	var firewall: Variant = FirewallScript.load_default()
	if contracts == null or not contracts.ok:
		return "P1 contracts failed to load"
	if firewall == null or not firewall.ok:
		return "firewall failed to load: %s" % ("null" if firewall == null else firewall.error_code)
	if firewall.contract_hash != EXPECTED_FIREWALL_HASH or not firewall.validate_integrity():
		return "firewall trust anchor mismatch"
	for case_value: Variant in cases:
		if not case_value is Dictionary:
			return "case is not a dictionary"
		var case: Dictionary = case_value
		var parsed: Variant = _parse(_case_input(vectors, case), contracts)
		var result: Variant = firewall.project(parsed)
		var expected_issue: Variant = case.get("expected_issue_code")
		var actual_issue: Variant = result.issues[0].get("code") if not result.issues.is_empty() else null
		if result.status != case.get("status"):
			return "%s status mismatch: %s" % [case.get("id"), result.status]
		if result.public_observation != case.get("expected_public_observation"):
			return "%s public tree mismatch" % case.get("id")
		if result.public_observation_hash != case.get("expected_public_observation_hash"):
			return "%s public hash mismatch" % case.get("id")
		if actual_issue != expected_issue:
			return "%s issue mismatch: %s" % [case.get("id"), actual_issue]
		if not result.validate_integrity(parsed):
			return "%s result integrity failed" % case.get("id")
		var serialized: Dictionary = result.to_public_dict()
		var text := JSON.stringify(serialized)
		for sentinel: Variant in vectors.get("sentinel_strings", []):
			if text.contains(str(sentinel)):
				return "%s echoed sentinel %s" % [case.get("id"), sentinel]
		if text.contains("search_begin_input") or text.contains("raw_private_hash") or text.contains("token_free_callback_hash"):
			return "%s serialized private authority" % case.get("id")
	return ""


func test_real_goldens_binary64_and_provenance_are_accepted() -> String:
	var contracts: Variant = CabtContractSetScript.load_default()
	var firewall: Variant = FirewallScript.load_default()
	for name: String in ["initial_callback", "normal_single_select", "optional_zero_deck_search", "normal_multi_select", "ordered_skill_multi_select", "engine_only_area_log"]:
		var parsed: Variant = _parse(_load_fixture(name), contracts)
		var result: Variant = firewall.project(parsed)
		if not result.accepted or not result.validate_integrity(parsed):
			return "%s rejected: %s" % [name, JSON.stringify(result.issues)]
		var pointers := {}
		for record_value: Variant in result.provenance:
			if not record_value is Dictionary:
				return "%s provenance record malformed" % name
			var record: Dictionary = record_value
			var pointer := str(record.get("output_pointer"))
			if pointers.has(pointer):
				return "%s duplicate provenance pointer %s" % [name, pointer]
			pointers[pointer] = true
			if record.get("source_pointer") != pointer or record.get("authority") != "official_cabt_wire":
				return "%s provenance authority mismatch" % name
	return ""


func test_copy_only_stale_binding_and_ordinary_result_mutation_fail_closed() -> String:
	var vectors: Dictionary = _read_contract(VECTOR_PATH)
	var regular: Dictionary
	for case_value: Variant in vectors.get("cases", []):
		if case_value is Dictionary and case_value.get("id") == "regular-accepted":
			regular = case_value
	var contracts: Variant = CabtContractSetScript.load_default()
	var firewall: Variant = FirewallScript.load_default()
	var raw := _case_input(vectors, regular)
	var parsed_a: Variant = _parse(raw, contracts)
	var parsed_equal: Variant = _parse(raw.duplicate(true), contracts)
	var result: Variant = firewall.project(parsed_a)
	var tree: Dictionary = result.public_observation
	tree["current"]["turn"] = 999999
	var provenance: Array = result.provenance
	provenance[0]["output_pointer"] = "/PRIVATE_SENTINEL"
	if result.public_observation.get("current").get("turn") == 999999:
		return "public getter aliases result state"
	if not result.validate_integrity(parsed_a) or result.validate_integrity(parsed_equal):
		return "exact input binding mismatch"
	var bound_parsed: Variant = _parse(raw.duplicate(true), contracts)
	var bound_result: Variant = firewall.project(bound_parsed)
	bound_parsed.envelope.set("_known_view", {"select": null, "logs": [], "current": null})
	if bound_result.validate_integrity(bound_parsed) or not bound_result.to_public_dict().is_empty():
		return "mutated bound envelope serialized stale authority"
	for field_name: String in ["_public_observation", "_public_observation_hash", "_provenance", "_issues", "_snapshot"]:
		var mutated: Variant = firewall.project(parsed_a)
		mutated.set(field_name, "PRIVATE_MUTATION_SENTINEL")
		if mutated.validate_integrity(parsed_a):
			return "%s mutation remained valid" % field_name
		if not mutated.to_public_dict().is_empty():
			return "%s mutation serialized" % field_name
	var limited: Variant = FirewallScript.load_default()
	var limited_profile: Dictionary = limited.get("_profile").duplicate(true)
	limited_profile["limits"]["max_public_tree_nodes"] = 2
	limited.set("_profile", limited_profile)
	var limit_result: Dictionary = limited.call(
		"_build_provenance",
		{"select": null, "logs": [], "current": null},
		null
	)
	if bool(limit_result.get("ok", false)) or limit_result.get("error_code") != "public_projection_limit":
		return "public tree node limit is not enforced"
	return ""


func test_seeded_unknown_private_fuzz_never_changes_public_hash() -> String:
	var vectors: Dictionary = _read_contract(VECTOR_PATH)
	var base: Dictionary = vectors.get("base_observations", {}).get("regular").duplicate(true)
	var contracts: Variant = CabtContractSetScript.load_default()
	var firewall: Variant = FirewallScript.load_default()
	var baseline: Variant = firewall.project(_parse(_materialize(base.duplicate(true)), contracts))
	var baseline_hash: String = baseline.public_observation_hash
	for index: int in 32:
		var raw: Dictionary = _materialize(base.duplicate(true))
		var sentinel := "PRIVATE_GODOT_FUZZ_%d" % index
		raw["unknown/%d~%s" % [index, sentinel]] = {"secret": sentinel, "deck": [index, index + 1]}
		raw["current"]["players"][0]["private_%d" % index] = sentinel
		var parsed: Variant = _parse(raw, contracts)
		var result: Variant = firewall.project(parsed)
		if not result.accepted or result.public_observation_hash != baseline_hash:
			return "fuzz %d changed acceptance/hash" % index
		var text := JSON.stringify(result.to_public_dict())
		if text.contains(sentinel) or text.contains("unknown/%d" % index):
			return "fuzz %d leaked sentinel" % index
	return ""


func _global(path: String) -> String:
	return ProjectSettings.globalize_path(path)


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	return true


func _copy_contracts(destination: String) -> String:
	var directory := "%s/contracts/ptcgdap" % destination
	if DirAccess.make_dir_recursive_absolute(_global(directory)) != OK:
		return "failed to create contract directory"
	for file_name: String in CONTRACT_FILES:
		if not _write_bytes("%s/%s" % [directory, file_name], _read_bytes("res://contracts/ptcgdap/%s" % file_name)):
			return "failed to copy %s" % file_name
	return ""


func _cleanup_contracts(destination: String) -> void:
	for file_name: String in CONTRACT_FILES:
		var path := "%s/contracts/ptcgdap/%s" % [destination, file_name]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(_global(path))
	for suffix: String in ["contracts/ptcgdap", "contracts", ""]:
		var directory := destination if suffix.is_empty() else "%s/%s" % [destination, suffix]
		if DirAccess.dir_exists_absolute(_global(directory)):
			DirAccess.remove_absolute(_global(directory))


func test_disk_missing_drift_and_self_consistent_rehash_reject() -> String:
	_cleanup_contracts(TEMP_ROOT)
	var copy_error := _copy_contracts(TEMP_ROOT)
	if not copy_error.is_empty():
		return copy_error
	var root := "%s/contracts/ptcgdap" % TEMP_ROOT
	var checks: Array[String] = []
	var profile_path := "%s/cabt_public_firewall_profile.json" % root
	var original_profile := _read_bytes(profile_path)
	_write_bytes(profile_path, original_profile.get_string_from_utf8().replace("acting player's hand", "forged hand").to_utf8_buffer())
	var drift: Variant = FirewallScript.load_from_root(root)
	checks.append(assert_false(drift.ok))
	checks.append(assert_eq(drift.error_code, "firewall_contract_error"))
	_write_bytes(profile_path, original_profile)

	var profile: Dictionary = _read_contract(profile_path)
	profile["visibility_rules"]["hand"] = "forged permissive authority"
	_write_bytes(profile_path, JSON.stringify(profile).to_utf8_buffer())
	var profile_hash: String = str(FirewallScript._canonical_artifact_sha256(_read_bytes(profile_path)))
	var bundle_path := "%s/cabt_public_firewall_bundle.json" % root
	var bundle: Dictionary = _read_contract(bundle_path)
	for entry_value: Variant in bundle.get("artifacts", []):
		if entry_value is Dictionary and str(entry_value.get("path")).ends_with("cabt_public_firewall_profile.json"):
			entry_value["canonical_sha256"] = profile_hash
	_write_bytes(bundle_path, JSON.stringify(bundle).to_utf8_buffer())
	var forged: Variant = FirewallScript.load_from_root(root)
	checks.append(assert_false(forged.ok))
	checks.append(assert_eq(forged.error_code, "firewall_contract_error"))
	DirAccess.remove_absolute(_global(profile_path))
	var missing: Variant = FirewallScript.load_from_root(root)
	checks.append(assert_false(missing.ok))
	checks.append(assert_eq(missing.error_code, "firewall_contract_error"))
	_cleanup_contracts(TEMP_ROOT)
	return run_checks(checks)
