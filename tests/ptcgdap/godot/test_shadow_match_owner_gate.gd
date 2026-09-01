class_name TestShadowMatchOwnerGate
extends TestBase

const GateScript = preload("res://scripts/engine/decision/ShadowMatchOwnerGate.gd")
const BrokerScript = preload("res://scripts/engine/decision/ShadowPromptBroker.gd")
const VECTOR_PATH := "res://contracts/ptcgdap/shadow_match_owner_gate_conformance_vectors.json"
const EXPECTED_BUNDLE := "9B8202E67756E388AFB0A13EA1FD20227ADF0718DF8454420A2B1FC7A5D31B8C"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991


func _restore_json_integer_tokens(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[key] = _restore_json_integer_tokens(value[key])
		return result
	if value is Array:
		var result := []
		for item: Variant in value: result.append(_restore_json_integer_tokens(item))
		return result
	if typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= float(MAX_SAFE_INTEGER):
		return int(value)
	return value


func _vectors() -> Dictionary:
	var file := FileAccess.open(VECTOR_PATH, FileAccess.READ)
	if file == null: return {}
	var value: Variant = _restore_json_integer_tokens(JSON.parse_string(file.get_as_text()))
	return value if value is Dictionary else {}


func _broker(generation: int) -> Variant:
	return BrokerScript.new(generation, "session:g%s" % generation)


func test_contract_vectors_and_initial_audit() -> String:
	var vectors := _vectors()
	if vectors.is_empty() or vectors.profile_id != "ptcgdap-shadow-match-owner-gate-p3-wp6-v1": return "vectors missing"
	var ids := {}
	for item: Variant in vectors.cases:
		if not item is Dictionary or ids.has(item.case_id): return "bad vector case"
		ids[item.case_id] = true
	for required: String in ["begin-legacy","begin-aligned","active-owner-switch-rejected","request-next-legacy","next-aligned-request-forced-legacy","audit-copy-nonauthority"]:
		if not ids.has(required): return "missing:%s" % required
	var gate: Variant = GateScript.new()
	if gate.contract_hash != EXPECTED_BUNDLE or not gate.validate_integrity(): return "gate contract"
	var audit: Dictionary = gate.audit_snapshot()
	return "" if audit == {"profile":"ptcgdap-shadow-match-owner-gate-p3-wp6-v1","gate_generation":0,"state":"idle","match_generation":null,"active_mode":null,"rollback_pending":false,"next_forced_mode":null,"rollback_applied":false,"authority":"shadow_match_owner_gate_audit","authoritative":false} else "initial audit"


func test_legacy_and_aligned_owner_lock() -> String:
	var legacy: Variant = GateScript.new()
	var started: Variant = legacy.begin_match(1, "legacy")
	if not started.accepted or not started.validate_integrity(legacy): return "legacy start"
	var switched: Variant = legacy.begin_match(2, "aligned_shadow", _broker(2))
	if switched.accepted or switched.error_code != "active_match_exists" or legacy.audit_snapshot().active_mode != "legacy": return "owner switched"
	var aligned: Variant = GateScript.new()
	if aligned.begin_match(1, "aligned_shadow").error_code != "broker_required": return "missing broker"
	if aligned.begin_match(1, "aligned_shadow", _broker(2)).error_code != "broker_match_generation_mismatch": return "cross generation broker"
	if aligned.begin_match(1, "legacy", _broker(1)).error_code != "broker_forbidden": return "legacy broker"
	var good: Variant = aligned.begin_match(1, "aligned_shadow", _broker(1))
	return "" if good.accepted and good.audit_snapshot().active_mode == "aligned_shadow" else "aligned start"


func test_rollback_is_next_match_only_and_once() -> String:
	var gate: Variant = GateScript.new()
	if not gate.begin_match(4, "aligned_shadow", _broker(4)).accepted: return "start"
	var requested: Variant = gate.request_legacy_next_match(4)
	if not requested.accepted or requested.audit_snapshot().active_mode != "aligned_shadow" or not requested.audit_snapshot().rollback_pending: return "request"
	if gate.request_legacy_next_match(4).error_code != "rollback_already_pending": return "duplicate"
	if not gate.end_match(4).accepted: return "end"
	var forced: Variant = gate.begin_match(5, "aligned_shadow", _broker(5))
	if not forced.accepted or forced.audit_snapshot().active_mode != "legacy" or not forced.audit_snapshot().rollback_applied: return "not forced"
	if forced.audit_snapshot().rollback_pending or forced.audit_snapshot().next_forced_mode != null: return "not consumed"
	return ""


func test_strict_types_stale_generation_and_copy_only_audit() -> String:
	for bad: Variant in [null, true, false, 0, -1, MAX_SAFE_INTEGER + 1, 1.0, "1", &"one"]:
		if GateScript.new().begin_match(bad, "legacy").error_code != "invalid_match_generation": return "bad generation:%s" % [bad]
	var gate: Variant = GateScript.new()
	if not gate.begin_match(2, "legacy").accepted or not gate.end_match(2).accepted: return "setup"
	if gate.begin_match(2, "legacy").error_code != "stale_match_generation": return "stale"
	if not gate.begin_match(3, "legacy").accepted: return "newer"
	var result: Variant = gate.current_owner()
	var audit: Dictionary = result.audit_snapshot()
	audit.active_mode = "aligned_shadow"
	audit.PRIVATE_BROKER_SENTINEL = "PRIVATE_PROMPT_SENTINEL"
	if gate.audit_snapshot().active_mode != "legacy" or "PRIVATE_" in JSON.stringify(gate.audit_snapshot()): return "audit leaked"
	result.set("_error_code", "PRIVATE_PROMPT_SENTINEL")
	return "" if not result.validate_integrity(gate) and result.to_public_dict() == {"accepted":false,"error_code":"invalid_gate","audit":null} else "result mutation"


func test_gate_state_mutation_fails_closed() -> String:
	var gate: Variant = GateScript.new()
	if not gate.begin_match(1, "aligned_shadow", _broker(1)).accepted: return "setup"
	gate.set("_active_mode", "PRIVATE_BROKER_SENTINEL")
	if gate.validate_integrity(): return "mutation accepted"
	var result: Variant = gate.current_owner()
	return "" if not result.accepted and result.error_code == "invalid_gate" and result.to_public_dict().audit == null else "mutation echoed"


func test_every_shared_vector_executes_with_exact_result() -> String:
	var vectors := _vectors()
	for case: Variant in vectors.get("cases", []):
		var actual := _run_vector(str(case.scenario))
		if actual.has("harness_error"): return "%s:%s" % [case.case_id, actual.harness_error]
		if actual.accepted != case.expected_accepted or actual.error != case.expected_error: return "result:%s:%s" % [case.case_id, actual]
		var audit: Dictionary = actual.audit
		if audit.state != case.expected_state or audit.active_mode != case.expected_mode or audit.rollback_pending != case.expected_rollback_pending:
			return "audit:%s:%s" % [case.case_id, audit]
		if audit.rollback_applied != bool(case.get("expected_rollback_applied", false)): return "applied:%s" % case.case_id
	return ""


func _run_vector(scenario: String) -> Dictionary:
	var gate: Variant = GateScript.new()
	var result: Variant = null
	match scenario:
		"begin_legacy": result = gate.begin_match(1, "legacy")
		"begin_aligned": result = gate.begin_match(1, "aligned_shadow", _broker(1))
		"active_owner_switch":
			gate.begin_match(1, "legacy")
			result = gate.begin_match(2, "aligned_shadow", _broker(2))
		"request_next_legacy", "current_owner_after_request", "duplicate_rollback_request", "end_with_pending":
			gate.begin_match(1, "aligned_shadow", _broker(1))
			var first: Variant = gate.request_legacy_next_match(1)
			if scenario == "request_next_legacy": result = first
			elif scenario == "current_owner_after_request": result = gate.current_owner()
			elif scenario == "duplicate_rollback_request": result = gate.request_legacy_next_match(1)
			else: result = gate.end_match(1)
		"next_forced_legacy":
			gate.begin_match(1, "aligned_shadow", _broker(1))
			gate.request_legacy_next_match(1)
			gate.end_match(1)
			result = gate.begin_match(2, "aligned_shadow", _broker(2))
		"stale_generation":
			gate.begin_match(2, "legacy")
			gate.end_match(2)
			result = gate.begin_match(2, "legacy")
		"aligned_without_broker": result = gate.begin_match(1, "aligned_shadow")
		"aligned_cross_generation_broker": result = gate.begin_match(1, "aligned_shadow", _broker(2))
		"legacy_with_broker": result = gate.begin_match(1, "legacy", _broker(1))
		"strictly_newer_match":
			gate.begin_match(1, "legacy")
			gate.end_match(1)
			result = gate.begin_match(2, "legacy")
		"audit_copy_nonauthority":
			result = gate.begin_match(1, "legacy")
			var copied: Dictionary = result.audit_snapshot()
			copied.active_mode = "aligned_shadow"
			result.set("_error_code", "PRIVATE_PROMPT_SENTINEL")
			var safe: Dictionary = result.to_public_dict()
			return {"accepted":safe.accepted,"error":safe.error_code,"audit":gate.audit_snapshot()}
		_:
			return {"harness_error":"unknown scenario:%s" % scenario}
	return {"accepted":result.accepted,"error":result.error_code,"audit":gate.audit_snapshot()}
