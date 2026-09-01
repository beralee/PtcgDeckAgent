class_name TestShadowPromptBroker
extends TestBase

const BrokerScript = preload("res://scripts/engine/decision/ShadowPromptBroker.gd")
const BindingScript = preload("res://scripts/engine/decision/GodotOptionBinding.gd")
const PortScript = preload("res://scripts/engine/decision/EngineDecisionPort.gd")
const SanitizerScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionSanitizer.gd")
const FallbackScript = preload("res://scripts/ai/ptcgdap/cabt/CabtDeterministicFallback.gd")
const ExecutorTestScript = preload("res://tests/ptcgdap/godot/test_godot_action_executor.gd")
const VECTOR_PATH := "res://contracts/ptcgdap/shadow_prompt_broker_conformance_vectors.json"
const EXPECTED_BUNDLE := "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E"
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


func _context() -> Dictionary:
	return ExecutorTestScript.new().call("_context")


func _broker(ctx: Dictionary) -> Variant:
	return BrokerScript.new(ctx.snapshot.match_generation, ctx.session_id)


func _open(broker: Variant, ctx: Dictionary, family: String = "W3") -> Variant:
	return broker.open_prompt(family, ctx.port, ctx.snapshot, ctx.binding_owner, ctx.binding, ctx.source, ctx.window, ctx.callback_hash)


func _fresh_context_after(ctx: Dictionary, decision_generation: int, delta: int = 100, reuse_window: bool = false) -> Dictionary:
	var next: Dictionary = ctx.duplicate()
	var source: Dictionary = (ctx.source as Dictionary).duplicate(true)
	if not reuse_window: source.select.option[1].index = int(source.select.option[1].index) + delta
	source.turn_action_count = int(source.turn_action_count) + 1
	var port: Variant = ctx.port
	var published: Variant = port.publish(source, decision_generation, ctx.snapshot.chooser_player_index)
	if not published.accepted: return {"error": "publish:%s" % published.error_code}
	var window: Variant = ctx.window
	if not reuse_window:
		var window_spec: Dictionary = (ExecutorTestScript.new().call("_document", "res://contracts/ptcgdap/godot_option_binding_conformance_vectors.json").get("fixture", {}).get("window", {}) as Dictionary).duplicate(true)
		window_spec.select.option[0].area = 3
		window_spec.select.option[1].index = int(window_spec.select.option[1].index) + delta
		window = ExecutorTestScript.new().call("_build_window", window_spec)
	if window == null: return {"error": "window"}
	var owner: Variant = BindingScript.new()
	var bound: Variant = owner.bind(port, published.snapshot, source, window, ctx.callback_hash, ctx.commands, ctx.private_refs)
	if not bound.accepted: return {"error": "bind:%s" % bound.error_code}
	var resolution: Variant = SanitizerScript.resolve_policy_attempt(window, {"status":"returned","output":[0]})
	if not FallbackScript.validate_resolution_integrity(resolution, window): return {"error": "selection"}
	next.merge({"source":source,"port":port,"snapshot":published.snapshot,"window":window,"binding_owner":owner,"binding":bound.binding,"resolution":resolution}, true)
	return next


func test_contract_and_every_w1_w7_family_load() -> String:
	var vectors := _vectors()
	if vectors.is_empty(): return "vectors missing"
	var seen := []
	for case: Variant in vectors.get("family_cases", []):
		var ctx := _context()
		if ctx.has("error"): return str(ctx.error)
		var broker: Variant = _broker(ctx)
		if broker.contract_hash != EXPECTED_BUNDLE or not broker.validate_integrity(): return "broker contract failed"
		var result: Variant = _open(broker, ctx, str(case.family))
		if not result.accepted or not result.validate_integrity(broker) or result.prompt.state != case.expected_state:
			return "family failed:%s:%s" % [case.case_id, result.error_code]
		seen.append(case.family)
	return "" if seen == ["W1","W2","W3","W4","W5","W6","W7"] else "family coverage differs"


func test_prepare_commit_is_ordered_atomic_and_private_free() -> String:
	var ctx := _context()
	if ctx.has("error"): return str(ctx.error)
	var broker: Variant = _broker(ctx)
	var opened: Variant = _open(broker, ctx, "W5")
	var prepared: Variant = broker.prepare_selection(opened.prompt, ctx.resolution)
	if not prepared.accepted or prepared.prompt.state != "prepared": return "prepare:%s" % prepared.error_code
	var committed: Variant = broker.commit_prompt(opened.prompt)
	if not committed.accepted: return "commit:%s" % committed.error_code
	var indexes := []
	for item: Variant in committed.private_resolutions: indexes.append(item.option_index)
	if indexes != [1,0]: return "order:%s" % [indexes]
	var audit: Dictionary = committed.to_public_dict()
	var text := JSON.stringify(audit)
	for private_key: String in ["session_id","callback_binding_hash","current_source","private_engine_command","private_object_refs","private_resolutions","ticket","preflight"]:
		if private_key in text: return "private echo:%s" % private_key
	if audit.audit.state != "awaiting_reobserve" or audit.audit.resolution_count != 2 or not audit.audit.witness.committed: return "witness mismatch"
	var replay: Variant = broker.commit_prompt(opened.prompt)
	return "" if not replay.accepted and replay.error_code == "reobserve_required" and replay.private_resolutions.is_empty() else "replay accepted"


func test_reobserve_requires_newer_distinct_context() -> String:
	var ctx := _context()
	var broker: Variant = _broker(ctx)
	var prompt: Variant = _open(broker, ctx, "W1").prompt
	var active: Variant = _open(broker, ctx, "W2")
	if active.error_code != "active_prompt_exists": return "active prompt replaced"
	if not broker.prepare_selection(prompt, ctx.resolution).accepted or not broker.commit_prompt(prompt).accepted: return "first commit failed"
	var stale: Variant = _open(broker, ctx, "W2")
	if stale.error_code != "stale_decision_generation": return "stale:%s" % stale.error_code
	var reused := _fresh_context_after(ctx, int(ctx.snapshot.decision_generation) + 1, 0, true)
	if reused.has("error"): return str(reused.error)
	var same: Variant = _open(broker, reused, "W2")
	if same.error_code != "same_window_reused": return "same window:%s" % same.error_code
	var next := _fresh_context_after(reused, int(reused.snapshot.decision_generation) + 1)
	if next.has("error"): return str(next.error)
	var opened: Variant = _open(broker, next, "W2")
	if not opened.accepted: return "next:%s" % opened.error_code
	if prompt.state != "superseded": return "old not superseded"
	var old: Variant = broker.prepare_selection(prompt, ctx.resolution)
	return "" if old.error_code == "prompt_not_current" else "old regained authority:%s" % old.error_code


func test_atomic_fault_cross_owner_and_reset() -> String:
	var ctx := _context()
	var broker: Variant = _broker(ctx)
	var prompt: Variant = _open(broker, ctx).prompt
	var other: Variant = _broker(ctx)
	if other.prepare_selection(prompt, ctx.resolution).error_code != "cross_owner": return "cross owner accepted"
	var wrong := _context()
	var rejected: Variant = broker.prepare_selection(prompt, wrong.resolution)
	if rejected.error_code != "selection_invalid" or not rejected.private_resolutions.is_empty() or prompt.state != "aborted": return "wrong selection not atomic"
	var issue_ctx := _context()
	var issue_broker: Variant = _broker(issue_ctx)
	var issue_prompt: Variant = _open(issue_broker, issue_ctx).prompt
	issue_ctx.source.turn_action_count = int(issue_ctx.source.turn_action_count) + 1
	var issue_failed: Variant = issue_broker.prepare_selection(issue_prompt, issue_ctx.resolution)
	if issue_failed.error_code != "ticket_issue_failed" or not issue_failed.private_resolutions.is_empty(): return "ticket issue fault not atomic"
	var ctx2 := _context()
	var broker2: Variant = _broker(ctx2)
	var prompt2: Variant = _open(broker2, ctx2).prompt
	if not broker2.prepare_selection(prompt2, ctx2.resolution).accepted: return "prepare2"
	ctx2.source.turn_action_count = int(ctx2.source.turn_action_count) + 1
	var failed: Variant = broker2.commit_prompt(prompt2)
	if failed.error_code != "commit_failed" or not failed.private_resolutions.is_empty() or prompt2.state != "aborted": return "commit fault not atomic"
	var ctx3 := _context()
	var broker3: Variant = _broker(ctx3)
	var prompt3: Variant = _open(broker3, ctx3).prompt
	if not broker3.reset_match(int(ctx3.snapshot.match_generation) + 1, "session:next"): return "reset rejected"
	return "" if broker3.prepare_selection(prompt3, ctx3.resolution).error_code == "match_generation_mismatch" else "old prompt survived reset"


func test_result_and_prompt_mutation_fail_closed() -> String:
	var ctx := _context()
	var broker: Variant = _broker(ctx)
	var result: Variant = _open(broker, ctx)
	var prompt: Variant = result.prompt
	prompt.set("_window_id", "0".repeat(64))
	if prompt.validate_integrity(broker) or not prompt.to_public_dict().is_empty(): return "prompt mutation accepted"
	if result.validate_integrity(broker): return "result retained mutated authority"
	var public: Dictionary = result.to_public_dict()
	return "" if not public.accepted and public.error_code == "invalid_broker" and not ("0".repeat(64) in JSON.stringify(public)) else "mutation echoed"


func test_shared_lifecycle_vector_domain_is_fully_accounted() -> String:
	var vectors := _vectors()
	var actual := []
	for case: Variant in vectors.get("lifecycle_cases", []): actual.append(case.scenario)
	var expected := [
		"open_first","prepare_success","resolve_success","ordered_multi_success","resolve_replay",
		"open_while_active","stale_next_snapshot","same_window_reused","new_prompt_after_reobserve",
		"selection_wrong_window","ticket_issue_failure","commit_failure","cross_broker_prompt","reset_invalidates_old",
	]
	return "" if actual == expected else "lifecycle vector domain differs:%s" % [actual]
