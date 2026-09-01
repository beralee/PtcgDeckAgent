class_name TestMarniePortablePolicy
extends TestBase

const RuntimeScript = preload("res://scripts/ai/ptcgdap/public/MarniePortablePolicy.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const VECTOR_PATH := "res://contracts/ptcgdap/marnie_portable_policy_conformance_vectors.json"
const PRIVATE_SENTINEL := "PRIVATE_SENTINEL"

var _owner: Variant = null


func _runtime() -> Variant:
	if _owner == null:
		var started_at_msec := Time.get_ticks_msec()
		print("PORTABLE_RUNTIME_LOAD: start")
		_owner = RuntimeScript.load_default()
		print("PORTABLE_RUNTIME_LOAD: complete (%d ms)" % [
			Time.get_ticks_msec() - started_at_msec,
		])
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
	if vectors.get("cases", []).size() != 28:
		return "shared vector count drift"
	var cases: Array = vectors.get("cases", [])
	for case_index: int in cases.size():
		var case_value: Variant = cases[case_index]
		var case: Dictionary = case_value
		var started_at_msec := Time.get_ticks_msec()
		print("VECTOR_PROGRESS: %d/%d %s" % [
			case_index,
			cases.size(),
			case.get("case_id"),
		])
		var actual: Dictionary = owner.run(case.get("operation"), case.get("input", {}).duplicate(true))
		if actual != case.get("expected"):
			return "%s differs from shared vector" % case.get("case_id")
		print("VECTOR_PROGRESS: %d/%d complete (%d ms)" % [
			case_index + 1,
			cases.size(),
			Time.get_ticks_msec() - started_at_msec,
		])
	return ""


func test_complete_trajectory_is_copy_only_public_and_non_authoritative() -> String:
	var owner: Variant = _runtime()
	var result: Variant = owner.evaluate_all()
	if result == null or not result.validate_integrity(owner):
		return "owner result integrity failed"
	var public: Dictionary = result.to_public_dict()
	if public.get("frame_count") != 13 or public.get("authoritative") != false or public.get("execution_authority") != false:
		return "result authority/count drift"
	var copy_value: Dictionary = public.duplicate(true)
	copy_value.get("frames")[3]["action"] = [999999]
	if not result.validate_integrity(owner) or result.to_public_dict().get("frames")[3].get("action") != [2]:
		return "copy mutation altered result"
	result.set("_snapshot", {"PRIVATE": PRIVATE_SENTINEL})
	if result.validate_integrity(owner) or JSON.stringify(result.to_public_dict()).contains(PRIVATE_SENTINEL):
		return "mutated result remained valid or echoed private data"
	return ""


func test_reorder_stale_unknown_and_tie_break_probes_are_exact() -> String:
	var owner: Variant = _runtime()
	var frame_result: Variant = owner.evaluate_frame("w3_main")
	var frame: Dictionary = frame_result.to_public_dict().get("frames")[0]
	var exact := {
		"frame_id": frame.get("frame_id"),
		"public_observation_hash": frame.get("public_observation_hash"),
		"window_id": frame.get("window_id"),
		"option_fingerprints": frame.get("option_fingerprints").duplicate(true),
	}
	if not bool(owner.run("verify_binding", exact).get("ok")):
		return "exact binding rejected"
	var reordered: Dictionary = exact.duplicate(true)
	reordered.get("option_fingerprints").reverse()
	if owner.run("verify_binding", reordered).get("error_code") != "binding_mismatch":
		return "reordered binding accepted"
	var stale: Dictionary = exact.duplicate(true)
	stale["window_id"] = "0".repeat(64)
	if owner.run("verify_binding", stale).get("error_code") != "binding_mismatch":
		return "stale binding accepted"
	for pair: Array in [["w4_spikemuth_deck", [0, 1]], ["w5_punk_up_sources", [0, 1, 2, 3, 4]]]:
		var tie: Dictionary = owner.run("inspect_tie_break", {"frame_id": pair[0]})
		if not bool(tie.get("ok")) or tie.get("value", {}).get("adapter_hint_indexes") != pair[1] or tie.get("value", {}).get("base_final_action") != []:
			return "tie-break probe drift: %s" % pair[0]
	if owner.run("inspect_node", {"node_id": PRIVATE_SENTINEL}).get("error_code") != "unsupported_node":
		return "unknown node did not fail closed"
	return ""


func test_contract_anchors_and_scope_are_exact() -> String:
	var audit: Dictionary = _runtime().audit_snapshot()
	if audit.get("frame_count") != 13 or audit.get("base_owned_count") != 10 or audit.get("capability_owned_count") != 2:
		return "audit scope drift"
	if audit.get("execution_authority") != false or audit.get("live_consumer") != false or audit.get("portable_ready") != false:
		return "audit authority drift"
	return ""
