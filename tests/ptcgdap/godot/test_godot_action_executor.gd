class_name TestGodotActionExecutor
extends TestBase

const ExecutorScript = preload("res://scripts/engine/decision/GodotActionExecutor.gd")
const TicketScript = preload("res://scripts/engine/decision/GodotActionTicket.gd")
const BindingScript = preload("res://scripts/engine/decision/GodotOptionBinding.gd")
const PortScript = preload("res://scripts/engine/decision/EngineDecisionPort.gd")
const WindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")
const ContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const SanitizerScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionSanitizer.gd")
const FallbackScript = preload("res://scripts/ai/ptcgdap/cabt/CabtDeterministicFallback.gd")
const CardInstanceScript = preload("res://scripts/data/CardInstance.gd")
const VECTOR_PATH := "res://contracts/ptcgdap/godot_action_executor_conformance_vectors.json"
const TICKET_VECTOR_PATH := "res://contracts/ptcgdap/godot_action_ticket_conformance_vectors.json"
const BINDING_VECTOR_PATH := "res://contracts/ptcgdap/godot_option_binding_conformance_vectors.json"
const EXPECTED_BUNDLE_HASH := "45952BE629AE98EB6070C77188FD6A2C2A644C4B6A36876193BB745B7CDA4E92"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991


class HostRef extends RefCounted:
	var calls := 0
	func invoke() -> void:
		calls += 1


func _restore_json_integer_tokens(value: Variant) -> Variant:
	if value is Dictionary:
		var restored := {}
		for key: Variant in value:
			restored[key] = _restore_json_integer_tokens(value[key])
		return restored
	if value is Array:
		var restored := []
		for child: Variant in value:
			restored.append(_restore_json_integer_tokens(child))
		return restored
	if typeof(value) == TYPE_FLOAT:
		var number := float(value)
		if is_finite(number) and number == floorf(number) and number >= -float(MAX_SAFE_INTEGER) and number <= float(MAX_SAFE_INTEGER):
			return int(number)
	return value


func _document(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var value: Variant = _restore_json_integer_tokens(JSON.parse_string(file.get_as_text()))
	return value if value is Dictionary else {}


func _materialize(value: Variant, refs: Dictionary) -> Variant:
	if typeof(value) == TYPE_STRING and str(value).begins_with("card:"):
		if not refs.has(value):
			refs[value] = CardInstanceScript.new()
		return refs[value]
	if typeof(value) == TYPE_STRING and (str(value).begins_with("command:") or str(value).begins_with("object:")):
		if not refs.has(value):
			refs[value] = HostRef.new()
		return refs[value]
	if value is Array:
		var output := []
		for item: Variant in value:
			output.append(_materialize(item, refs))
		return output
	if value is Dictionary:
		var output := {}
		for key: Variant in value:
			output[key] = _materialize(value[key], refs)
		return output
	return value


func _build_window(spec: Dictionary) -> Variant:
	var contracts: Variant = ContractSetScript.load_default()
	var result: Variant = WindowScript.build(spec.duplicate(true), contracts)
	if result == null or typeof(result) != TYPE_OBJECT or not WindowScript.validate_build_result_integrity(result):
		return null
	return result.get("window")


func _context() -> Dictionary:
	var ticket_vectors := _document(TICKET_VECTOR_PATH)
	var binding_fixture: Dictionary = (_document(BINDING_VECTOR_PATH).get("fixture", {}) as Dictionary).duplicate(true)
	var patch: Dictionary = ticket_vectors.get("fixture", {}).get("binding_fixture_patch", {})
	var refs := {}
	var source: Dictionary = _materialize(binding_fixture.get("source"), refs)
	var window_spec: Dictionary = (binding_fixture.get("window") as Dictionary).duplicate(true)
	window_spec.get("select").get("option")[0]["area"] = patch.get("window_option_0_area")
	var window: Variant = _build_window(window_spec)
	if window == null:
		return {"error": "window_build_failed"}
	var commands: Array = _materialize(binding_fixture.get("private_commands"), refs)
	var private_refs: Array = _materialize(binding_fixture.get("private_object_refs"), refs)
	var port: Variant = PortScript.open_match(binding_fixture.get("match_generation"))
	var published: Variant = port.publish(source, binding_fixture.get("decision_generation"), binding_fixture.get("chooser_player_index"))
	if not published.accepted:
		return {"error": "port_publish_failed"}
	var binding_owner: Variant = BindingScript.new()
	var bound: Variant = binding_owner.bind(port, published.snapshot, source, window, binding_fixture.get("callback_binding_hash"), commands, private_refs)
	if not bound.accepted:
		return {"error": "binding_failed:%s" % bound.error_code}
	var variant: Dictionary = ticket_vectors.get("fixture", {}).get("selection_variants", {}).get("policy_ordered", {})
	var resolution: Variant = SanitizerScript.resolve_policy_attempt(window, {"status": "returned", "output": variant.get("attempt_indexes")})
	if not FallbackScript.validate_resolution_integrity(resolution, window):
		return {"error": "selection_failed"}
	var ctx := {
		"refs": refs,
		"source": source,
		"window": window,
		"commands": commands,
		"private_refs": private_refs,
		"port": port,
		"snapshot": published.snapshot,
		"binding_owner": binding_owner,
		"binding": bound.binding,
		"resolution": resolution,
		"session_id": ticket_vectors.get("fixture", {}).get("session_id"),
		"public_hash": ticket_vectors.get("fixture", {}).get("public_observation_hash"),
		"callback_hash": ticket_vectors.get("fixture", {}).get("callback_binding_hash"),
	}
	var ticket_owner: Variant = TicketScript.new()
	var issued: Variant = ticket_owner.issue(
		ctx.session_id, ctx.public_hash, binding_owner, bound.binding, port,
		published.snapshot, source, window, ctx.callback_hash, resolution
	)
	if not issued.accepted:
		return {"error": "ticket_issue_failed:%s" % issued.error_code}
	var claimed: Variant = ticket_owner.claim(
		issued.ticket, ctx.session_id, ctx.public_hash, binding_owner, bound.binding,
		port, published.snapshot, source, window, ctx.callback_hash
	)
	if not claimed.accepted:
		return {"error": "ticket_claim_failed:%s" % claimed.error_code}
	ctx["ticket_owner"] = ticket_owner
	ctx["claim"] = claimed
	return ctx


func _prepare(executor: Variant, ctx: Dictionary, overrides: Dictionary = {}) -> Variant:
	var values := {
		"ticket_owner": ctx.get("ticket_owner"),
		"claim_result": ctx.get("claim"),
		"binding_owner": ctx.get("binding_owner"),
		"binding": ctx.get("binding"),
		"port": ctx.get("port"),
		"snapshot": ctx.get("snapshot"),
		"current_source": ctx.get("source"),
		"window": ctx.get("window"),
		"callback_binding_hash": ctx.get("callback_hash"),
	}
	values.merge(overrides, true)
	return executor.prepare(
		values.ticket_owner, values.claim_result, values.binding_owner, values.binding,
		values.port, values.snapshot, values.current_source, values.window, values.callback_binding_hash
	)


func _commit(executor: Variant, batch: Variant, ctx: Dictionary, overrides: Dictionary = {}) -> Variant:
	var values := {
		"ticket_owner": ctx.get("ticket_owner"),
		"binding_owner": ctx.get("binding_owner"),
		"binding": ctx.get("binding"),
		"port": ctx.get("port"),
		"snapshot": ctx.get("snapshot"),
		"current_source": ctx.get("source"),
		"window": ctx.get("window"),
		"callback_binding_hash": ctx.get("callback_hash"),
	}
	values.merge(overrides, true)
	return executor.commit(
		batch, values.ticket_owner, values.binding_owner, values.binding, values.port,
		values.snapshot, values.current_source, values.window, values.callback_binding_hash
	)


func test_fixed_contract_loads() -> String:
	var executor: Variant = ExecutorScript.new()
	if not executor.validate_integrity():
		return "executor contract failed to load: %s" % executor.error_code
	if executor.contract_hash != EXPECTED_BUNDLE_HASH:
		return "executor bundle anchor differs"
	return ""


func test_ordered_prepare_commit_and_private_non_echo() -> String:
	var ctx := _context()
	if ctx.has("error"):
		return ctx.error
	var executor: Variant = ExecutorScript.new()
	var prepared: Variant = _prepare(executor, ctx)
	if not prepared.accepted or not prepared.validate_integrity(executor):
		return "prepare failed: %s" % prepared.error_code
	var audit: Dictionary = prepared.to_public_dict().get("audit", {})
	if audit.get("selected_indexes") != [1, 0] or audit.get("state") != "prepared" or audit.get("resolution_count") != 2:
		return "prepared audit differs: %s" % audit
	var encoded := JSON.stringify(prepared.to_public_dict())
	for forbidden: String in _document(VECTOR_PATH).get("fixture", {}).keys():
		pass
	for forbidden: String in ["session_id", "callback_binding_hash", "current_source", "private_engine_command", "private_object_refs", "binding_resolutions"]:
		if encoded.contains(forbidden):
			return "private field echoed: %s" % forbidden
	var committed: Variant = _commit(executor, prepared.preflight, ctx)
	if not committed.accepted or not committed.validate_integrity(executor):
		return "commit failed: %s" % committed.error_code
	var resolutions: Array = committed.binding_resolutions
	if resolutions.size() != 2 or resolutions[0].option_index != 1 or resolutions[1].option_index != 0:
		return "commit order differs"
	if resolutions[0].private_engine_command != ctx.commands[1] or resolutions[1].private_engine_command != ctx.commands[0]:
		return "private command identity differs"
	if committed.to_public_dict().get("audit", {}).get("state") != "committed":
		return "committed state missing"
	for command: Variant in ctx.commands:
		if command.calls != 0:
			return "executor invoked command"
	return ""


func test_shared_preflight_codes() -> String:
	var cases: Array = _document(VECTOR_PATH).get("preflight_cases", [])
	if cases.size() != 13:
		return "preflight vector count differs"
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		var ctx := _context()
		if ctx.has("error"):
			return "%s context: %s" % [case.get("id"), ctx.error]
		var executor: Variant = ExecutorScript.new()
		var overrides := {}
		match case.get("id"):
			"preflight-invalid-owner": overrides["ticket_owner"] = HostRef.new()
			"preflight-invalid-claim": overrides["claim_result"] = {}
			"preflight-rejected-claim":
				var bad: Variant = ctx.ticket_owner.claim(ctx.claim.get("_ticket"), "session:wrong", ctx.public_hash, ctx.binding_owner, ctx.binding, ctx.port, ctx.snapshot, ctx.source, ctx.window, ctx.callback_hash)
				overrides["claim_result"] = bad
			"preflight-invalid-binding-owner": overrides["binding_owner"] = HostRef.new()
			"preflight-binding-stale": ctx.binding_owner.set("_current", null)
			"preflight-snapshot-stale": overrides["snapshot"] = _context().snapshot
			"preflight-window-stale": overrides["window"] = _context().window
			"preflight-callback-drift": overrides["callback_binding_hash"] = "B".repeat(64)
			"preflight-selection-reordered":
				var reversed: Array = ctx.claim.get("_binding_resolutions").duplicate()
				reversed.reverse()
				ctx.claim.set("_binding_resolutions", reversed)
			"preflight-resolution-mutated": ctx.claim.get("_binding_resolutions")[0].set("_private_engine_command", HostRef.new())
			"preflight-reference-released":
				var current: Dictionary = ctx.binding_owner.get("_current")
				var refs: Array = current.command_refs.duplicate()
				var temporary := HostRef.new()
				refs[ctx.claim.binding_resolutions[0].option_index] = weakref(temporary)
				temporary = null
				current.command_refs = refs
			"preflight-active-exists":
				if not _prepare(executor, ctx).accepted:
					return "active setup failed"
		var result: Variant = _prepare(executor, ctx, overrides)
		var expected: Dictionary = case.get("expected")
		if result.accepted != expected.get("accepted") or result.error_code != expected.get("error_code"):
			return "%s differs: %s" % [case.get("id"), result.to_public_dict()]
		if not result.validate_integrity(executor):
			return "%s result integrity failed" % case.get("id")
		if not result.accepted and result.to_public_dict().get("audit") != null:
			return "%s rejected audit not null" % case.get("id")
	return ""


func test_shared_commit_codes_and_atomic_abort() -> String:
	var cases: Array = _document(VECTOR_PATH).get("commit_cases", [])
	if cases.size() != 10:
		return "commit vector count differs"
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		var ctx := _context()
		if ctx.has("error"):
			return "%s context: %s" % [case.get("id"), ctx.error]
		var executor: Variant = ExecutorScript.new()
		var prepared: Variant = _prepare(executor, ctx)
		if not prepared.accepted:
			return "%s prepare failed" % case.get("id")
		var batch: Variant = prepared.preflight
		var result: Variant
		match case.get("id"):
			"commit-success": result = _commit(executor, batch, ctx)
			"commit-invalid-preflight": result = _commit(executor, {}, ctx)
			"commit-cross-owner": result = _commit(ExecutorScript.new(), batch, ctx)
			"commit-mutated-preflight":
				batch.set("_preflight_id", "0".repeat(64))
				result = _commit(executor, batch, ctx)
			"commit-stale-batch":
				executor.set("_active", null)
				result = _commit(executor, batch, ctx)
			"commit-replay":
				if not _commit(executor, batch, ctx).accepted:
					return "replay setup failed"
				result = _commit(executor, batch, ctx)
			"commit-aborted":
				if not executor.abort(batch):
					return "abort setup failed"
				result = _commit(executor, batch, ctx)
			"commit-context-drift":
				var changed: Dictionary = ctx.source.duplicate(true)
				changed.turn_action_count += 1
				result = _commit(executor, batch, ctx, {"current_source": changed})
			"commit-resolution-mutated":
				ctx.claim.get("_binding_resolutions")[0].set("_private_engine_command", HostRef.new())
				result = _commit(executor, batch, ctx)
			"commit-reference-released":
				var current: Dictionary = ctx.binding_owner.get("_current")
				var refs: Array = current.command_refs.duplicate()
				var temporary := HostRef.new()
				refs[ctx.claim.binding_resolutions[0].option_index] = weakref(temporary)
				temporary = null
				current.command_refs = refs
				result = _commit(executor, batch, ctx)
		var expected: Dictionary = case.get("expected")
		if result.accepted != expected.get("accepted") or result.error_code != expected.get("error_code"):
			return "%s differs: %s" % [case.get("id"), result.to_public_dict()]
		if not result.accepted and not result.binding_resolutions.is_empty():
			return "%s leaked partial resolutions" % case.get("id")
		if case.get("id") in ["commit-context-drift", "commit-resolution-mutated", "commit-reference-released"] and batch.state != "aborted":
			return "%s did not abort atomically" % case.get("id")
	return ""


func test_result_and_batch_mutation_fail_closed() -> String:
	var ctx := _context()
	if ctx.has("error"):
		return ctx.error
	var executor: Variant = ExecutorScript.new()
	var prepared: Variant = _prepare(executor, ctx)
	var batch: Variant = prepared.preflight
	prepared.set("_error_code", "private-sentinel")
	if prepared.validate_integrity(executor) or not prepared.to_public_dict().is_empty():
		return "mutated result remained valid"
	batch.set("_preflight_generation", 99)
	if batch.validate_integrity(executor) or not batch.to_public_dict().is_empty():
		return "mutated batch remained valid"
	return ""


func test_transition_vectors_and_generations() -> String:
	var cases: Array = _document(VECTOR_PATH).get("transition_cases", [])
	if cases.size() != 5:
		return "transition vector count differs"
	var ctx := _context()
	if ctx.has("error"):
		return ctx.error
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		var executor: Variant = ExecutorScript.new()
		var steps := []
		match case.get("id"):
			"prepare-commit-replay":
				var prepared: Variant = _prepare(executor, ctx)
				steps.append("prepare_accept" if prepared.accepted else "prepare_reject")
				var first: Variant = _commit(executor, prepared.preflight, ctx)
				steps.append("commit_accept" if first.accepted else "commit_reject")
				var replay: Variant = _commit(executor, prepared.preflight, ctx)
				steps.append("commit_already_committed" if replay.error_code == "already_committed" else "commit_other")
			"prepare-abort-commit":
				var prepared: Variant = _prepare(executor, ctx)
				steps.append("prepare_accept" if prepared.accepted else "prepare_reject")
				steps.append("abort_accept" if executor.abort(prepared.preflight) else "abort_reject")
				var result: Variant = _commit(executor, prepared.preflight, ctx)
				steps.append("commit_preflight_aborted" if result.error_code == "preflight_aborted" else "commit_other")
			"failed-prepare-is-atomic":
				var result: Variant = _prepare(executor, ctx, {"callback_binding_hash": "B".repeat(64)})
				steps.append("prepare_reject" if not result.accepted else "prepare_accept")
				steps.append("state_none" if executor.current_preflight() == null else "state_active")
			"failed-commit-aborts-without-output":
				var prepared: Variant = _prepare(executor, ctx)
				steps.append("prepare_accept" if prepared.accepted else "prepare_reject")
				var changed: Dictionary = ctx.source.duplicate(true)
				changed.turn_action_count += 1
				var result: Variant = _commit(executor, prepared.preflight, ctx, {"current_source": changed})
				steps.append("commit_reject" if not result.accepted and result.binding_resolutions.is_empty() else "commit_other")
				steps.append("state_aborted" if prepared.preflight.state == "aborted" else "state_other")
			"ordered-multi-preserved":
				var prepared: Variant = _prepare(executor, ctx)
				steps.append("prepare_indexes_1_0" if prepared.preflight.to_public_dict().get("selected_indexes") == [1, 0] else "prepare_order_other")
				var result: Variant = _commit(executor, prepared.preflight, ctx)
				var indexes := []
				for resolution: Variant in result.binding_resolutions:
					indexes.append(resolution.option_index)
				steps.append("commit_indexes_1_0" if indexes == [1, 0] else "commit_order_other")
			_:
				return "unknown transition case: %s" % case.get("id")
		if steps != case.get("steps"):
			return "%s steps differ: %s" % [case.get("id"), steps]
	var executor: Variant = ExecutorScript.new()
	var ids := {}
	for generation: int in range(1, 9):
		var prepared: Variant = _prepare(executor, ctx)
		if not prepared.accepted or prepared.preflight.preflight_generation != generation:
			return "generation %d failed" % generation
		if ids.has(prepared.preflight.preflight_id):
			return "preflight id reused"
		ids[prepared.preflight.preflight_id] = true
		if generation % 2 == 0:
			if not executor.abort(prepared.preflight):
				return "abort transition failed"
		else:
			if not _commit(executor, prepared.preflight, ctx).accepted:
				return "commit transition failed"
	return ""
