class_name TestShadowWholeMatchHarness
extends TestBase

const HarnessScript = preload("res://scripts/engine/decision/ShadowWholeMatchHarness.gd")
const GateScript = preload("res://scripts/engine/decision/ShadowMatchOwnerGate.gd")
const BrokerScript = preload("res://scripts/engine/decision/ShadowPromptBroker.gd")
const ApplierTestScript = preload("res://tests/ptcgdap/godot/test_shadow_engine_command_applier.gd")
const BrokerTestScript = preload("res://tests/ptcgdap/godot/test_shadow_prompt_broker.gd")
const VECTOR_PATH := "res://contracts/ptcgdap/shadow_whole_match_harness_conformance_vectors.json"
const EXPECTED_BUNDLE := "0C5A8FDAB61A73F623EA6B0D364C38E6C4797087287B3DF3C88D0191261296B5"
const SAFE_MAX := 9_007_199_254_740_991


class ReversibleCommand extends RefCounted:
	var command_name := ""
	var value := 0
	var capture_ok := true
	var apply_ok := true
	var restore_ok := true
	var private_state := "PRIVATE_STATE_SENTINEL"
	func _init(value: String = "command") -> void: command_name = value
	func shadow_capture() -> Dictionary: return {"ok":capture_ok,"snapshot":{"value":value,"private":private_state}}
	func shadow_apply() -> bool:
		if not apply_ok: return false
		value += 1
		return true
	func shadow_restore(snapshot: Variant) -> bool:
		if not restore_ok: return false
		if snapshot is Dictionary: value = snapshot.get("value", value)
		return true


class FakeBrokerResult extends RefCounted:
	var accepted := true
	var error_code := ""
	var prompt: Variant = null
	var _private_resolutions: Array = []
	var _public: Dictionary = {}
	func _init(real: Variant) -> void:
		prompt = real.prompt
		_private_resolutions = real.get("_private_resolutions").duplicate()
		_public = real.to_public_dict().duplicate(true)
	func validate_integrity(_owner: Variant) -> bool: return true
	func to_public_dict() -> Dictionary: return _public.duplicate(true)


func _restore_ints(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[key] = _restore_ints(value[key])
		return result
	if value is Array:
		var result := []
		for item: Variant in value: result.append(_restore_ints(item))
		return result
	if typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= float(SAFE_MAX): return int(value)
	return value


func _vectors() -> Dictionary:
	var file := FileAccess.open(VECTOR_PATH, FileAccess.READ)
	if file == null: return {}
	var value: Variant = _restore_ints(JSON.parse_string(file.get_as_text()))
	return value if value is Dictionary else {}


func _contains_exact_key(value: Variant, target: String) -> bool:
	if value is Dictionary:
		for key: Variant in value:
			if typeof(key) == TYPE_STRING and key == target: return true
			if _contains_exact_key(value[key], target): return true
	if value is Array:
		for item: Variant in value:
			if _contains_exact_key(item, target): return true
	return false


func _fixture(first: Variant = null, second: Variant = null) -> Dictionary:
	first = first if first != null else ReversibleCommand.new("first")
	second = second if second != null else ReversibleCommand.new("second")
	return ApplierTestScript.new().call("_committed_fixture", first, second)


func _aligned_gate(ctx: Dictionary, broker: Variant) -> Variant:
	var gate: Variant = GateScript.new()
	var begun: Variant = gate.begin_match(ctx.snapshot.match_generation, "aligned_shadow", broker)
	return gate if begun.accepted else null


func _second_committed(ctx: Dictionary, broker: Variant) -> Dictionary:
	var next: Dictionary = BrokerTestScript.new().call("_fresh_context_after", ctx, int(ctx.snapshot.decision_generation) + 1)
	if next.has("error"): return next
	var opened: Variant = broker.open_prompt("W5", next.port, next.snapshot, next.binding_owner, next.binding, next.source, next.window, next.callback_hash)
	if not opened.accepted: return {"error":"open:%s" % opened.error_code}
	var prepared: Variant = broker.prepare_selection(opened.prompt, next.resolution)
	if not prepared.accepted: return {"error":"prepare:%s" % prepared.error_code}
	var committed: Variant = broker.commit_prompt(opened.prompt)
	if not committed.accepted: return {"error":"commit:%s" % committed.error_code}
	return {"ctx":next,"committed":committed}


func test_contract_two_prompt_chain_and_private_free_report() -> String:
	var fixture := _fixture()
	if fixture.has("error"): return str(fixture.error)
	var owner: Variant = HarnessScript.new(_aligned_gate(fixture.ctx, fixture.broker), fixture.broker)
	if owner.contract_hash != EXPECTED_BUNDLE or not owner.validate_integrity(): return "contract"
	if not owner.start().accepted or not owner.apply_prompt(fixture.committed).accepted: return "first"
	var second := _second_committed(fixture.ctx, fixture.broker)
	if second.has("error") or not owner.apply_prompt(second.committed).accepted: return "second:%s" % second.get("error", "apply")
	var finished: Variant = owner.finish_match()
	if not finished.accepted or not finished.validate_integrity(owner): return "finish:%s" % finished.error_code
	var report: Dictionary = owner.audit_snapshot()
	if report.state != "completed" or report.prompt_count != 2: return "report:%s" % report
	for key: String in ["broker_generations","decision_generations","snapshot_ids","window_ids","execution_ids"]:
		var values: Array = report[key]
		var seen := {}
		for value: Variant in values: seen[value] = true
		if values.size() != 2 or seen.size() != 2: return "chain:%s" % key
	var encoded := JSON.stringify(finished.to_public_dict())
	for sentinel: Variant in _vectors().get("private_sentinels", []):
		if encoded.contains(str(sentinel)): return "private sentinel"
	for forbidden: String in ["private_engine_command","private_object_refs","captured_state","session_id","callback_binding_hash","current_source","broker","gate","applier","prompt","binding","ticket","preflight"]:
		if _contains_exact_key(finished.to_public_dict(), forbidden): return "private key:%s" % forbidden
	return ""


func test_every_shared_vector_executes_without_skip() -> String:
	var cases: Array = _vectors().get("cases", [])
	if cases.size() != 9: return "vector count:%s" % cases.size()
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		var actual := _run_scenario(case.scenario)
		if actual.has("error"): return "%s fixture:%s" % [case.case_id,actual.error]
		var result: Variant = actual.result
		var owner: Variant = actual.owner
		var public: Dictionary = result.to_public_dict()
		var report: Dictionary = owner.audit_snapshot()
		if public.accepted != case.expected_accepted or public.error_code != case.expected_error: return "%s result:%s" % [case.case_id,public]
		if report.state != case.expected_state or report.prompt_count != case.expected_prompt_count or report.fault_code != case.expected_fault: return "%s report:%s" % [case.case_id,report]
		if report.dirty != case.expected_dirty or report.rollback_requested != case.expected_rollback or report.next_match_mode != case.expected_next_mode: return "%s flags:%s" % [case.case_id,report]
		if not result.validate_integrity(owner): return "%s integrity" % case.case_id
	return ""


func test_failure_positions_are_terminal_and_next_match_legacy() -> String:
	for fail_first: bool in [true,false]:
		var first := ReversibleCommand.new("first")
		var second := ReversibleCommand.new("second")
		first.apply_ok = not fail_first
		second.apply_ok = fail_first
		var fixture := _fixture(first, second)
		var owner: Variant = HarnessScript.new(_aligned_gate(fixture.ctx, fixture.broker), fixture.broker)
		if not owner.start().accepted: return "start"
		var failed: Variant = owner.apply_prompt(fixture.committed)
		if failed.accepted or failed.error_code != "prompt_apply_failed" or owner.audit_snapshot().state != "faulted": return "fault:%s" % failed.to_public_dict()
		if first.value != 0 or second.value != 0: return "not restored"
		if owner.apply_prompt(fixture.committed).error_code != "match_terminal": return "retry"
		if not owner.finish_match().accepted or not owner.verify_next_match_rollback(int(fixture.ctx.snapshot.match_generation) + 1).accepted: return "rollback"
		if owner.audit_snapshot().next_match_mode != "legacy": return "mode"
	return ""


func test_restore_failure_is_dirty_and_cannot_retry() -> String:
	var first := ReversibleCommand.new("first"); first.restore_ok = false
	var second := ReversibleCommand.new("second"); second.apply_ok = false
	var fixture := _fixture(first, second)
	var owner: Variant = HarnessScript.new(_aligned_gate(fixture.ctx, fixture.broker), fixture.broker)
	owner.start()
	var failed: Variant = owner.apply_prompt(fixture.committed)
	if failed.error_code != "dirty_game_detected" or owner.audit_snapshot().state != "dirty" or not owner.audit_snapshot().dirty: return "dirty:%s" % failed.to_public_dict()
	if owner.apply_prompt(fixture.committed).error_code != "match_terminal": return "dirty retry"
	return "" if owner.finish_match().accepted and owner.verify_next_match_rollback(int(fixture.ctx.snapshot.match_generation) + 1).accepted else "rollback"


func test_replay_invalid_result_legacy_and_wrong_broker_fail_closed() -> String:
	var fixture := _fixture()
	var owner: Variant = HarnessScript.new(_aligned_gate(fixture.ctx, fixture.broker), fixture.broker)
	owner.start(); owner.apply_prompt(fixture.committed)
	if owner.apply_prompt(fixture.committed).error_code != "stale_prompt_chain": return "replay"
	var invalid_fixture := _fixture()
	var invalid_owner: Variant = HarnessScript.new(_aligned_gate(invalid_fixture.ctx, invalid_fixture.broker), invalid_fixture.broker)
	invalid_owner.start(); invalid_fixture.committed.set("_error_code", "PRIVATE_COMMAND_SENTINEL")
	if invalid_owner.apply_prompt(invalid_fixture.committed).error_code != "invalid_broker_result": return "invalid"
	var legacy: Variant = GateScript.new(); legacy.begin_match(fixture.ctx.snapshot.match_generation, "legacy")
	if HarnessScript.new(legacy, fixture.broker).start().error_code != "owner_mode_not_aligned": return "legacy"
	var other: Variant = BrokerScript.new(fixture.ctx.snapshot.match_generation, fixture.ctx.session_id)
	if HarnessScript.new(_aligned_gate(fixture.ctx, fixture.broker), other).start().error_code != "broker_not_current": return "wrong broker"
	return ""


func test_result_and_owner_mutation_do_not_echo_or_reauthorize() -> String:
	var fixture := _fixture()
	var owner: Variant = HarnessScript.new(_aligned_gate(fixture.ctx, fixture.broker), fixture.broker)
	var result: Variant = owner.start()
	var copied: Dictionary = result.to_public_dict()
	copied.report.execution_ids = ["PRIVATE_STATE_SENTINEL"]
	if result.to_public_dict().report.execution_ids != []: return "copy mutated owner"
	result.get("_report")["execution_ids"] = ["PRIVATE_STATE_SENTINEL"]
	if result.validate_integrity(owner): return "result mutation accepted"
	if JSON.stringify(result.to_public_dict()).contains("PRIVATE_STATE_SENTINEL"): return "result mutation echoed"
	owner.set("_fault_code", "PRIVATE_COMMAND_SENTINEL")
	if owner.validate_integrity() or owner.audit_snapshot().fault_code != "": return "owner mutation accepted"
	return ""


func test_protocol_lookalike_cannot_replace_exact_broker_result() -> String:
	var fixture := _fixture()
	var owner: Variant = HarnessScript.new(_aligned_gate(fixture.ctx, fixture.broker), fixture.broker)
	if not owner.start().accepted: return "start"
	var result: Variant = owner.apply_prompt(FakeBrokerResult.new(fixture.committed))
	if result.error_code != "invalid_broker_result" or owner.audit_snapshot().state != "faulted": return "lookalike:%s" % result.to_public_dict()
	for command: Variant in fixture.selected:
		if command.value != 0: return "lookalike executed"
	return ""


func test_next_match_generation_is_strict_and_rollback_consumes_once() -> String:
	var first := ReversibleCommand.new("first"); first.capture_ok = false
	var fixture := _fixture(first)
	var owner: Variant = HarnessScript.new(_aligned_gate(fixture.ctx, fixture.broker), fixture.broker)
	owner.start(); owner.apply_prompt(fixture.committed); owner.finish_match()
	var current: int = fixture.ctx.snapshot.match_generation
	if owner.verify_next_match_rollback(current).error_code != "invalid_match_generation": return "same generation"
	if not owner.verify_next_match_rollback(current + 1).accepted: return "next"
	return "" if owner.verify_next_match_rollback(current + 2).error_code == "rollback_not_required" else "reuse"


func _run_scenario(scenario: String) -> Dictionary:
	var first := ReversibleCommand.new("first")
	var second := ReversibleCommand.new("second")
	if scenario == "capture_fault": first.capture_ok = false
	if scenario in ["apply_fault","restore_fault"]:
		second.apply_ok = false
		first.restore_ok = scenario != "restore_fault"
	var fixture := _fixture(first, second)
	if fixture.has("error"): return fixture
	var gate: Variant = _aligned_gate(fixture.ctx, fixture.broker)
	var pinned: Variant = fixture.broker
	if scenario == "legacy_start":
		gate = GateScript.new(); gate.begin_match(fixture.ctx.snapshot.match_generation, "legacy")
	if scenario == "wrong_broker": pinned = BrokerScript.new(fixture.ctx.snapshot.match_generation, fixture.ctx.session_id)
	var owner: Variant = HarnessScript.new(gate, pinned)
	var result: Variant = owner.start()
	if scenario in ["legacy_start","wrong_broker"]: return {"owner":owner,"result":result}
	if not result.accepted: return {"error":"start:%s" % result.error_code}
	if scenario == "invalid_result": fixture.committed.set("_error_code", "PRIVATE_COMMAND_SENTINEL")
	result = owner.apply_prompt(fixture.committed)
	if scenario == "two_prompt_success":
		if not result.accepted: return {"error":"first:%s" % result.error_code}
		var next := _second_committed(fixture.ctx, fixture.broker)
		if next.has("error"): return next
		result = owner.apply_prompt(next.committed)
	if scenario == "replay_chain" and result.accepted: result = owner.apply_prompt(fixture.committed)
	if scenario in ["two_prompt_success","finish_clean"]:
		result = owner.finish_match()
	elif scenario in ["capture_fault","apply_fault","restore_fault","replay_chain","invalid_result"]:
		var ended: Variant = owner.finish_match()
		if not ended.accepted: return {"error":"end:%s" % ended.error_code}
		result = owner.verify_next_match_rollback(int(fixture.ctx.snapshot.match_generation) + 1)
	return {"owner":owner,"result":result}
