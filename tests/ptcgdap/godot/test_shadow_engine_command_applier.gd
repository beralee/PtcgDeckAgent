class_name TestShadowEngineCommandApplier
extends TestBase

const ApplierScript = preload("res://scripts/engine/decision/ShadowEngineCommandApplier.gd")
const GateScript = preload("res://scripts/engine/decision/ShadowMatchOwnerGate.gd")
const BrokerScript = preload("res://scripts/engine/decision/ShadowPromptBroker.gd")
const BindingScript = preload("res://scripts/engine/decision/GodotOptionBinding.gd")
const ExecutorTestScript = preload("res://tests/ptcgdap/godot/test_godot_action_executor.gd")
const VECTOR_PATH := "res://contracts/ptcgdap/shadow_engine_command_applier_conformance_vectors.json"
const EXPECTED_BUNDLE := "7539A9D5120666AEBA1325DD6623F437831A024996BD612F3EC677F78C9F8F4C"
const SAFE_MAX := 9_007_199_254_740_991


class ReversibleCommand extends RefCounted:
	var command_name := ""
	var value := 0
	var capture_ok := true
	var apply_ok := true
	var restore_ok := true
	var order: Array = []
	var private_state := "PRIVATE_STATE_SENTINEL"

	func _init(name_value: String = "command") -> void: command_name = name_value
	func shadow_capture() -> Dictionary:
		return {"ok": capture_ok, "snapshot": {"value": value, "private": private_state}}
	func shadow_apply() -> bool:
		order.append(command_name)
		if not apply_ok: return false
		value += 1
		return true
	func shadow_restore(snapshot: Variant) -> bool:
		if not restore_ok: return false
		value = snapshot.get("value") if snapshot is Dictionary else value
		return true


class InvalidCommand extends RefCounted:
	pass


func _document() -> Dictionary:
	var file := FileAccess.open(VECTOR_PATH, FileAccess.READ)
	if file == null: return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return _restore_ints(value) if value is Dictionary else {}


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


func _committed_fixture(first: Variant = null, second: Variant = null, duplicate := false, invalid := false, commit := true) -> Dictionary:
	var ctx: Dictionary = ExecutorTestScript.new().call("_context")
	if ctx.has("error"): return ctx
	first = first if first != null else ReversibleCommand.new("first")
	second = second if second != null else ReversibleCommand.new("second")
	var commands := []
	for index: int in ctx.commands.size(): commands.append(ReversibleCommand.new("unused-%d" % index))
	commands[1] = first
	commands[0] = first if duplicate else InvalidCommand.new() if invalid else second
	var binding_owner: Variant = BindingScript.new()
	var bound: Variant = binding_owner.bind(ctx.port, ctx.snapshot, ctx.source, ctx.window, ctx.callback_hash, commands, ctx.private_refs)
	if not bound.accepted: return {"error": "bind:%s" % bound.error_code}
	ctx.binding_owner = binding_owner
	ctx.binding = bound.binding
	ctx.commands = commands
	var broker: Variant = BrokerScript.new(ctx.snapshot.match_generation, ctx.session_id)
	var opened: Variant = broker.open_prompt("W5", ctx.port, ctx.snapshot, ctx.binding_owner, ctx.binding, ctx.source, ctx.window, ctx.callback_hash)
	if not opened.accepted: return {"error": "open:%s" % opened.error_code}
	if not commit: return {"ctx":ctx,"broker":broker,"committed":opened,"selected":[first,second]}
	var prepared: Variant = broker.prepare_selection(opened.prompt, ctx.resolution)
	if not prepared.accepted: return {"error": "prepare:%s" % prepared.error_code}
	var committed: Variant = broker.commit_prompt(opened.prompt)
	if not committed.accepted: return {"error": "commit:%s" % committed.error_code}
	return {"ctx":ctx,"broker":broker,"committed":committed,"selected":[first,second]}


func _gate(ctx: Dictionary, broker: Variant) -> Variant:
	var gate: Variant = GateScript.new()
	var started: Variant = gate.begin_match(ctx.snapshot.match_generation, "aligned_shadow", broker)
	return gate if started.accepted else null


func test_contract_and_ordered_witness_are_private_free() -> String:
	var fixture := _committed_fixture()
	if fixture.has("error"): return str(fixture.error)
	var applier: Variant = ApplierScript.new(_gate(fixture.ctx, fixture.broker), fixture.broker)
	if applier.contract_hash != EXPECTED_BUNDLE or not applier.validate_integrity(): return "applier contract"
	var result: Variant = applier.apply(fixture.committed)
	if not result.accepted or not result.validate_integrity(applier): return "apply:%s" % result.error_code
	if fixture.selected[0].value != 1 or fixture.selected[1].value != 1: return "commands not applied"
	if result.witness.selected_indexes != [1,0] or result.witness.resolution_count != 2 or not result.witness.validate_integrity(applier): return "witness mismatch"
	var text := JSON.stringify(result.to_public_dict())
	for sentinel: Variant in _document().get("private_sentinels", []):
		if text.contains(str(sentinel)): return "private sentinel echoed"
	for forbidden: String in ["private_engine_command","private_object_refs","captured_state","session_id","callback_binding_hash","current_source"]:
		if text.contains(forbidden): return "private key echoed:%s" % forbidden
	return ""


func test_every_shared_vector_executes_without_skip() -> String:
	var cases: Array = _document().get("cases", [])
	if cases.size() != 11: return "vector count"
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		var actual := _run_scenario(case.scenario)
		if actual.has("error"): return "%s fixture:%s" % [case.case_id, actual.error]
		var result: Variant = actual.result
		var applier: Variant = actual.applier
		var public: Dictionary = result.to_public_dict()
		if public.accepted != case.expected_accepted or public.error_code != case.expected_error: return "%s result:%s" % [case.case_id, public]
		if applier.audit_snapshot().state != case.expected_state or public.rolled_back != case.expected_rolled_back or public.poisoned != case.expected_poisoned: return "%s state:%s" % [case.case_id, applier.audit_snapshot()]
		if [actual.selected[0].value, actual.selected[1].value] != case.expected_calls: return "%s calls" % case.case_id
		if not result.validate_integrity(applier): return "%s integrity" % case.case_id
	return ""


func test_ordinary_mutation_copy_and_rebaseline_fail_closed() -> String:
	var fixture := _committed_fixture()
	var applier: Variant = ApplierScript.new(_gate(fixture.ctx, fixture.broker), fixture.broker)
	var result: Variant = applier.apply(fixture.committed)
	var copied: Dictionary = result.to_public_dict().duplicate(true)
	copied.witness.selected_indexes = [999999]
	if result.witness.selected_indexes != [1,0]: return "copy mutated owner"
	result.witness.get("_public")["selected_indexes"] = [999999]
	if result.witness.validate_integrity(applier) or result.validate_integrity(applier): return "witness mutation accepted"
	var safe: Dictionary = result.to_public_dict()
	return "" if safe == {"accepted":false,"error_code":"invalid_applier","witness":null,"rolled_back":false,"poisoned":false} else "mutation echoed:%s" % safe


func test_failure_positions_restore_exact_state_and_poison_is_terminal() -> String:
	for fail_first: bool in [true, false]:
		var first := ReversibleCommand.new("first")
		var second := ReversibleCommand.new("second")
		first.value = 17; second.value = 29
		first.apply_ok = not fail_first; second.apply_ok = fail_first
		var fixture := _committed_fixture(first, second)
		var applier: Variant = ApplierScript.new(_gate(fixture.ctx, fixture.broker), fixture.broker)
		var result: Variant = applier.apply(fixture.committed)
		if result.error_code != "command_apply_failed" or not result.rolled_back or first.value != 17 or second.value != 29: return "restore position:%s" % fail_first
	var first := ReversibleCommand.new("first"); first.restore_ok = false
	var second := ReversibleCommand.new("second"); second.apply_ok = false
	var fixture := _committed_fixture(first, second)
	var applier: Variant = ApplierScript.new(_gate(fixture.ctx, fixture.broker), fixture.broker)
	var poisoned: Variant = applier.apply(fixture.committed)
	if poisoned.error_code != "rollback_failed" or not poisoned.poisoned or first.value != 1 or second.value != 0: return "poison state"
	var replay: Variant = applier.apply(fixture.committed)
	return "" if replay.error_code == "rollback_failed" and replay.poisoned and first.value == 1 and second.value == 0 else "poison retry"


func test_wrong_gate_broker_and_result_never_capture() -> String:
	var fixture := _committed_fixture()
	var legacy: Variant = GateScript.new()
	legacy.begin_match(fixture.ctx.snapshot.match_generation, "legacy")
	var legacy_result: Variant = ApplierScript.new(legacy, fixture.broker).apply(fixture.committed)
	if legacy_result.error_code != "owner_mode_not_aligned": return "legacy:%s" % legacy_result.error_code
	var other: Variant = BrokerScript.new(fixture.ctx.snapshot.match_generation, fixture.ctx.session_id)
	var wrong: Variant = ApplierScript.new(_gate(fixture.ctx, fixture.broker), other).apply(fixture.committed)
	if wrong.error_code != "broker_not_current": return "broker:%s" % wrong.error_code
	return "" if fixture.selected[0].value == 0 and fixture.selected[1].value == 0 else "command captured"


func test_executed_witness_remains_audit_after_broker_reobserve() -> String:
	var fixture := _committed_fixture()
	if fixture.has("error"): return str(fixture.error)
	var applier: Variant = ApplierScript.new(_gate(fixture.ctx, fixture.broker), fixture.broker)
	var result: Variant = applier.apply(fixture.committed)
	if not result.accepted: return "apply:%s" % result.error_code
	var before: Dictionary = result.to_public_dict()
	if not fixture.broker.reset_match(int(fixture.ctx.snapshot.match_generation) + 1, "session:next"): return "broker reset"
	if not applier.validate_integrity() or not result.validate_integrity(applier): return "audit invalidated"
	return "" if result.to_public_dict() == before and before.witness.authoritative == false else "audit changed"


func _run_scenario(scenario: String) -> Dictionary:
	var first := ReversibleCommand.new("first")
	var second := ReversibleCommand.new("second")
	if scenario == "capture_failure": first.capture_ok = false
	if scenario in ["apply_failure_restored","restore_failure"]:
		second.apply_ok = false
		first.restore_ok = scenario != "restore_failure"
	var fixture := _committed_fixture(first, second, scenario == "duplicate_command", scenario == "invalid_command", scenario != "uncommitted_result")
	if fixture.has("error"): return fixture
	var gate: Variant = _gate(fixture.ctx, fixture.broker)
	var pinned: Variant = fixture.broker
	if scenario == "legacy_gate":
		gate = GateScript.new(); gate.begin_match(fixture.ctx.snapshot.match_generation, "legacy")
	if scenario == "wrong_broker": pinned = BrokerScript.new(fixture.ctx.snapshot.match_generation, fixture.ctx.session_id)
	var applier: Variant = ApplierScript.new(gate, pinned)
	if scenario == "mutated_result": fixture.committed.set("_error_code", "PRIVATE_COMMAND_SENTINEL")
	var result: Variant = applier.apply(fixture.committed)
	if scenario == "replay":
		if not result.accepted: return {"error":"replay setup"}
		result = applier.apply(fixture.committed)
	return {"result":result,"applier":applier,"selected":fixture.selected}
