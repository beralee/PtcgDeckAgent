class_name TestMarniePublicBase
extends TestBase

const RuntimeScript = preload("res://scripts/ai/ptcgdap/public/MarniePublicBase.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const VECTOR_PATH := "res://contracts/ptcgdap/marnie_public_base_conformance_vectors.json"
const PRIVATE_SENTINEL := "PRIVATE_SENTINEL"

var _owner: Variant = null


func _runtime() -> Variant:
	if _owner == null:
		_owner = RuntimeScript.load_default()
	return _owner


func _read_contract(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Dictionary = FirewallScript._parse_contract_json_bytes(file.get_buffer(file.get_length()))
	var value: Variant = parsed.get("value") if bool(parsed.get("ok", false)) else null
	return value if value is Dictionary else {}


func test_default_owner_and_all_shared_vectors_match_exactly() -> String:
	var owner: Variant = _runtime()
	if owner == null or not bool(owner.get("ok")):
		return "owner failed to load: %s" % (owner.get("error_code") if owner != null else "null")
	var vectors: Dictionary = _read_contract(VECTOR_PATH)
	if vectors.get("cases", []).size() != 20:
		return "shared vector count drift"
	for case_value: Variant in vectors.get("cases", []):
		var case: Dictionary = case_value
		var actual: Dictionary = owner.run(case.get("operation"), case.get("input", {}).duplicate(true))
		if actual != case.get("expected"):
			return "%s differs from shared vector" % case.get("case_id")
	return ""


func test_owner_result_is_copy_only_public_and_non_authoritative() -> String:
	var owner: Variant = _runtime()
	var result: Variant = owner.evaluate_all()
	if result == null or not result.validate_integrity(owner):
		return "owner result integrity failed"
	var public: Dictionary = result.to_public_dict()
	if public.get("case_count") != 16 or public.get("authoritative") != false or public.get("execution_authority") != false:
		return "result authority/count drift"
	var copy_value: Dictionary = public.duplicate(true)
	copy_value.get("cases")[0]["case_id"] = PRIVATE_SENTINEL
	if not result.validate_integrity(owner) or JSON.stringify(result.to_public_dict()).contains(PRIVATE_SENTINEL):
		return "copy mutation altered or leaked into result"
	var runtime_script: GDScript = load("res://scripts/ai/ptcgdap/public/MarniePublicBase.gd")
	var constants: Dictionary = runtime_script.get_script_constant_map()
	var direct: Variant = constants.get("ResultValue").new(owner, public, RuntimeScript.RESULT_TOKEN)
	if direct.validate_integrity(owner) or not direct.to_public_dict().get("cases", []).is_empty():
		return "direct result construction gained owner authority"
	result.set("_snapshot", {"PRIVATE": PRIVATE_SENTINEL})
	if result.validate_integrity(owner) or JSON.stringify(result.to_public_dict()).contains(PRIVATE_SENTINEL):
		return "mutated result remained valid or echoed private data"
	return ""


func test_input_faults_fail_closed_without_partial_authority() -> String:
	var owner: Variant = _runtime()
	var faults: Array = [
		[&"evaluate_all", {}, "input_type_invalid"],
		["evaluate_all", [], "input_type_invalid"],
		["evaluate_all", {"extra": true}, "input_type_invalid"],
		["evaluate_case", {}, "input_type_invalid"],
		["evaluate_case", {"case_id": &"source-w1-setup-active"}, "input_type_invalid"],
		["evaluate_case", {"case_id": "missing"}, "case_unknown"],
		["PRIVATE_SENTINEL", {}, "operation_unknown"],
	]
	for fault: Array in faults:
		var actual: Dictionary = owner.run(fault[0], fault[1])
		if actual.get("ok") or actual.get("error_code") != fault[2] or actual.get("value") != null:
			return "fault mismatch for %s: %s" % [fault[0], actual]
		if JSON.stringify(actual).contains(PRIVATE_SENTINEL):
			return "fault echoed private input"
	return ""


func test_contract_anchors_and_scope_are_exact() -> String:
	if RuntimeScript.EXPECTED_BUNDLE_CANONICAL_SHA256 != "67EBA6348277001692942FD58E8D1B9D50C54F0FFC783D8802BA3CCB45691105":
		return "bundle anchor drift"
	if RuntimeScript.EXPECTED_DOCUMENT_INTEGRITY_SHA256 != "166906CEE9380EEF94A642CB9CCA9B2AF7A94AC546935CB91942FFD3B03B8C32":
		return "document integrity anchor drift"
	var audit: Dictionary = _runtime().audit_snapshot()
	if audit.get("case_count") != 16 or audit.get("macro_count") != 6 or audit.get("execution_authority") != false or audit.get("live_consumer") != false:
		return "audit scope drift"
	return ""


func test_z_internal_state_mutation_fails_closed() -> String:
	var mutated: Variant = _runtime()
	var original_cases: Array = mutated.get("_cases").duplicate(true)
	var cases: Array = mutated.get("_cases").duplicate(true)
	cases[1]["selected_indexes"] = [999]
	mutated.set("_cases", cases)
	if mutated.validate_integrity():
		return "mutated cases retained integrity"
	mutated.set("_cases", original_cases)
	if not mutated.validate_integrity():
		return "restored cases did not restore integrity"
	var expected: Dictionary = mutated.get("_expected").duplicate(true)
	expected["execution_authority"] = true
	expected["PRIVATE_SENTINEL"] = 999
	mutated.set("_expected", expected)
	if mutated.validate_integrity():
		return "rebaselined expected audit retained integrity"
	var dto: Dictionary = mutated.run("evaluate_all", {})
	if dto != {"ok": false, "error_code": "contract_integrity_invalid", "value": null}:
		return "mutated owner did not fail closed: %s" % dto
	if not mutated.audit_snapshot().is_empty() or mutated.bundle_hash() != "":
		return "mutated owner retained audit/hash authority"
	if JSON.stringify(dto).contains(PRIVATE_SENTINEL):
		return "mutated expected audit leaked private input"
	return ""
