class_name TestGodotActionTicket
extends TestBase

const TicketScript = preload("res://scripts/engine/decision/GodotActionTicket.gd")
const BindingScript = preload("res://scripts/engine/decision/GodotOptionBinding.gd")
const PortScript = preload("res://scripts/engine/decision/EngineDecisionPort.gd")
const WindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")
const ContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const SanitizerScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionSanitizer.gd")
const FallbackScript = preload("res://scripts/ai/ptcgdap/cabt/CabtDeterministicFallback.gd")
const CardInstanceScript = preload("res://scripts/data/CardInstance.gd")
const VECTOR_PATH := "res://contracts/ptcgdap/godot_action_ticket_conformance_vectors.json"
const BINDING_VECTOR_PATH := "res://contracts/ptcgdap/godot_option_binding_conformance_vectors.json"
const EXPECTED_BUNDLE_HASH := "41F3E84C6DC5C9BC6C162B848B097211E617B5558ECB59554757E82CE58817ED"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991


class HostRef extends RefCounted:
	pass


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


func _vectors() -> Dictionary:
	return _document(VECTOR_PATH)


func _binding_vectors() -> Dictionary:
	return _document(BINDING_VECTOR_PATH)


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


func _context(selection_variant: String = "policy_ordered") -> Dictionary:
	var vectors := _vectors()
	var binding_fixture: Dictionary = (_binding_vectors().get("fixture", {}) as Dictionary).duplicate(true)
	var patch: Dictionary = vectors.get("fixture", {}).get("binding_fixture_patch", {})
	var refs := {}
	var source: Dictionary = _materialize(binding_fixture.get("source"), refs)
	var window_spec: Dictionary = (binding_fixture.get("window") as Dictionary).duplicate(true)
	window_spec.get("select").get("option")[0]["area"] = patch.get("window_option_0_area")
	var window: Variant = _build_window(window_spec)
	if window == null or window.get("decision_state") != "policy_allowed":
		return {"error": "window_build_failed"}
	var commands: Array = _materialize(binding_fixture.get("private_commands"), refs)
	var private_refs: Array = _materialize(binding_fixture.get("private_object_refs"), refs)
	var port: Variant = PortScript.open_match(binding_fixture.get("match_generation"))
	var published: Variant = port.publish(
		source,
		binding_fixture.get("decision_generation"),
		binding_fixture.get("chooser_player_index")
	)
	if not published.accepted:
		return {"error": "port_publish_failed:%s" % published.error_code}
	var binding_owner: Variant = BindingScript.new()
	var bound: Variant = binding_owner.bind(
		port, published.snapshot, source, window,
		binding_fixture.get("callback_binding_hash"), commands, private_refs
	)
	if not bound.accepted:
		return {"error": "binding_failed:%s" % bound.error_code}
	var variant: Dictionary = vectors.get("fixture", {}).get("selection_variants", {}).get(selection_variant, {})
	var attempt: Variant = (
		{"status": "returned", "output": (variant.get("attempt_indexes") as Array).duplicate(true)}
		if variant.get("attempt_kind") == "exact_indexes"
		else {"status": "returned", "output": "invalid-policy-output"}
	)
	var resolution: Variant = SanitizerScript.resolve_policy_attempt(window, attempt)
	if not FallbackScript.validate_resolution_integrity(resolution, window):
		return {"error": "selection_resolution_failed"}
	return {
		"fixture": binding_fixture,
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
		"session_id": vectors.get("fixture", {}).get("session_id"),
		"public_hash": vectors.get("fixture", {}).get("public_observation_hash"),
		"callback_hash": vectors.get("fixture", {}).get("callback_binding_hash"),
	}


func _issue(owner: Variant, ctx: Dictionary, overrides: Dictionary = {}) -> Variant:
	var values := {
		"session_id": ctx.get("session_id"),
		"public_observation_hash": ctx.get("public_hash"),
		"binding_owner": ctx.get("binding_owner"),
		"binding": ctx.get("binding"),
		"port": ctx.get("port"),
		"snapshot": ctx.get("snapshot"),
		"current_source": ctx.get("source"),
		"window": ctx.get("window"),
		"callback_binding_hash": ctx.get("callback_hash"),
		"selection_resolution": ctx.get("resolution"),
	}
	values.merge(overrides, true)
	return owner.issue(
		values.session_id, values.public_observation_hash, values.binding_owner, values.binding,
		values.port, values.snapshot, values.current_source, values.window,
		values.callback_binding_hash, values.selection_resolution
	)


func _claim(owner: Variant, ticket: Variant, ctx: Dictionary, overrides: Dictionary = {}) -> Variant:
	var values := {
		"session_id": ctx.get("session_id"),
		"public_observation_hash": ctx.get("public_hash"),
		"binding_owner": ctx.get("binding_owner"),
		"binding": ctx.get("binding"),
		"port": ctx.get("port"),
		"snapshot": ctx.get("snapshot"),
		"current_source": ctx.get("source"),
		"window": ctx.get("window"),
		"callback_binding_hash": ctx.get("callback_hash"),
	}
	values.merge(overrides, true)
	return owner.claim(
		ticket, values.session_id, values.public_observation_hash, values.binding_owner, values.binding,
		values.port, values.snapshot, values.current_source, values.window, values.callback_binding_hash
	)


func _drop_ref(ctx: Dictionary, command: bool) -> void:
	var indexes: Array = ctx.get("resolution").selected_indexes
	var option_index: int = indexes[0] if command else 0
	var target: Variant
	if command:
		target = ctx.get("commands")[option_index]
		ctx.get("commands")[option_index] = null
	else:
		target = ctx.get("private_refs")[option_index][0]
		ctx.get("private_refs")[option_index][0] = null
	var refs: Dictionary = ctx.get("refs")
	for key: Variant in refs.keys():
		if refs[key] == target:
			refs.erase(key)
	target = null


func test_fixed_contract_loads() -> String:
	var owner: Variant = TicketScript.new()
	if not owner.validate_integrity():
		return "ticket contract failed to load"
	if owner.contract_hash != EXPECTED_BUNDLE_HASH:
		return "ticket bundle anchor differs"
	return ""


func test_shared_issue_vectors() -> String:
	var cases: Array = _vectors().get("issue_cases", [])
	if cases.size() != 13:
		return "issue vector count differs: %d" % cases.size()
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		var ctx := _context(case.get("selection_variant"))
		if ctx.has("error"):
			return "%s context failed: %s" % [case.get("id"), ctx.get("error")]
		var owner: Variant = TicketScript.new()
		var overrides := {}
		match case.get("fault"):
			"session_type": overrides["session_id"] = true
			"session_format": overrides["session_id"] = "bad session"
			"public_hash_type": overrides["public_observation_hash"] = true
			"public_hash_mismatch": overrides["public_observation_hash"] = "B".repeat(64)
			"binding_copy": overrides["binding"] = ctx.get("binding").to_public_dict()
			"stale_snapshot":
				var published: Variant = ctx.get("port").publish(
					ctx.get("source"), ctx.get("fixture").get("decision_generation") + 1,
					ctx.get("fixture").get("chooser_player_index")
				)
				if not published.accepted:
					return "%s stale publish failed" % case.get("id")
			"window_copy":
				var spec: Dictionary = (ctx.get("fixture").get("window") as Dictionary).duplicate(true)
				spec.get("select").get("option")[0]["area"] = _vectors().get("fixture").get("binding_fixture_patch").get("window_option_0_area")
				overrides["window"] = _build_window(spec)
			"resolution_copy": overrides["selection_resolution"] = ctx.get("resolution").to_public_dict()
			"callback_drift": overrides["callback_binding_hash"] = "B".repeat(64)
			"active_ticket_conflict":
				var first: Variant = _issue(owner, ctx)
				if not first.accepted:
					return "%s first issue failed" % case.get("id")
				overrides["selection_resolution"] = SanitizerScript.resolve_policy_attempt(ctx.get("window"), {"status": "returned", "output": "bad"})
			"claimed_binding_reissue":
				var issued: Variant = _issue(owner, ctx)
				if not issued.accepted or not _claim(owner, issued.ticket, ctx).accepted:
					return "%s setup claim failed" % case.get("id")
			"none": pass
			_: return "%s unknown fault" % case.get("id")
		var result: Variant = _issue(owner, ctx, overrides)
		var expected: Dictionary = case.get("expected")
		if result.accepted != expected.get("accepted") or result.error_code != expected.get("error_code"):
			return "%s issue differs: %s" % [case.get("id"), result.error_code]
		if result.to_public_dict() != expected or not result.validate_integrity(owner):
			return "%s issue public/integrity differs actual=%s expected=%s integrity=%s" % [case.get("id"), result.to_public_dict(), expected, result.validate_integrity(owner)]
		if result.accepted and (result.ticket != owner.current_ticket() or not result.ticket.validate_integrity(owner)):
			return "%s ticket integrity differs" % case.get("id")
	return ""


func test_shared_claim_vectors() -> String:
	var cases: Array = _vectors().get("claim_cases", [])
	if cases.size() != 12:
		return "claim vector count differs: %d" % cases.size()
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		var ctx := _context(case.get("selection_variant"))
		var owner: Variant = TicketScript.new()
		var issued: Variant = _issue(owner, ctx)
		if not issued.accepted:
			return "%s issue setup failed: %s" % [case.get("id"), issued.error_code]
		var ticket: Variant = issued.ticket
		var overrides := {}
		var replacement_commands := []
		match case.get("fault"):
			"session_drift": overrides["session_id"] = "session:other"
			"callback_drift": overrides["callback_binding_hash"] = "B".repeat(64)
			"public_hash_drift": overrides["public_observation_hash"] = "B".repeat(64)
			"ticket_copy": ticket = ticket.to_public_dict()
			"cross_owner": owner = TicketScript.new()
			"stale_binding":
				for _index: int in range(ctx.get("commands").size()):
					replacement_commands.append(HostRef.new())
				var replacement: Variant = ctx.get("binding_owner").bind(
					ctx.get("port"), ctx.get("snapshot"), ctx.get("source"), ctx.get("window"),
					ctx.get("callback_hash"), replacement_commands, ctx.get("private_refs")
				)
				if not replacement.accepted:
					return "%s replacement bind failed" % case.get("id")
			"dead_command": _drop_ref(ctx, true)
			"dead_private_ref": _drop_ref(ctx, false)
			"double_claim":
				if not _claim(owner, ticket, ctx).accepted:
					return "%s first claim failed" % case.get("id")
			"ticket_mutation": ticket.set("_ticket_id", "B".repeat(64))
			"none": pass
			_: return "%s unknown fault" % case.get("id")
		var result: Variant = _claim(owner, ticket, ctx, overrides)
		var expected: Dictionary = case.get("expected")
		if result.accepted != expected.get("accepted") or result.error_code != expected.get("error_code"):
			return "%s claim differs: %s" % [case.get("id"), result.error_code]
		if result.to_public_dict() != expected or not result.validate_integrity(owner):
			return "%s claim public/integrity differs actual=%s expected=%s integrity=%s" % [case.get("id"), result.to_public_dict(), expected, result.validate_integrity(owner)]
		if result.accepted:
			var resolutions: Array = result.binding_resolutions
			var indexes: Array = ctx.get("resolution").selected_indexes
			if resolutions.size() != indexes.size():
				return "%s resolution count differs" % case.get("id")
			for index: int in range(indexes.size()):
				if resolutions[index].private_engine_command != ctx.get("commands")[indexes[index]]:
					return "%s command identity differs" % case.get("id")
		elif case.get("fault") in ["session_drift", "callback_drift", "public_hash_drift"]:
			if not _claim(owner, issued.ticket, ctx).accepted:
				return "%s retry consumed ticket" % case.get("id")
	return ""


func test_shared_transition_vectors() -> String:
	var cases: Array = _vectors().get("transition_cases", [])
	if cases.size() != 5:
		return "transition vector count differs: %d" % cases.size()
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		var ctx := _context("policy_ordered")
		var owner: Variant = TicketScript.new()
		var first: Variant = _issue(owner, ctx)
		if not first.accepted:
			return "%s initial issue failed" % case.get("id")
		var actual := ""
		match case.get("scenario"):
			"idempotent_issue":
				var retry: Variant = _issue(owner, ctx)
				actual = retry.error_code
				if retry.ticket != first.ticket:
					return "%s allocated a second ticket" % case.get("id")
			"active_conflict":
				var fallback: Variant = SanitizerScript.resolve_policy_attempt(ctx.get("window"), {"status": "returned", "output": "bad"})
				actual = _issue(owner, ctx, {"selection_resolution": fallback}).error_code
				if owner.current_ticket() != first.ticket:
					return "%s consumed the active ticket" % case.get("id")
			"new_binding_revokes":
				var replacements := []
				for _index: int in range(ctx.get("commands").size()):
					replacements.append(HostRef.new())
				var rebound: Variant = ctx.get("binding_owner").bind(
					ctx.get("port"), ctx.get("snapshot"), ctx.get("source"), ctx.get("window"),
					ctx.get("callback_hash"), replacements, ctx.get("private_refs")
				)
				if not rebound.accepted or _claim(owner, first.ticket, ctx).error_code != "binding_not_current":
					return "%s did not detect replacement binding" % case.get("id")
				actual = _claim(owner, first.ticket, ctx).error_code
			"successful_claim_closes_binding":
				if not _claim(owner, first.ticket, ctx).accepted:
					return "%s initial claim failed" % case.get("id")
				actual = _issue(owner, ctx).error_code
			"failed_context_attempt_atomic":
				actual = _claim(owner, first.ticket, ctx, {"session_id": "session:other"}).error_code
				if not _claim(owner, first.ticket, ctx).accepted:
					return "%s consumed ticket on session mismatch" % case.get("id")
			_:
				return "%s unknown transition" % case.get("id")
		if actual != case.get("expected_error"):
			return "%s transition differs: %s" % [case.get("id"), actual]
	return ""


func test_one_use_transitions_and_non_echo() -> String:
	var ctx := _context("policy_ordered")
	var owner: Variant = TicketScript.new()
	var first: Variant = _issue(owner, ctx)
	var retry: Variant = _issue(owner, ctx)
	if not first.accepted or not retry.accepted or first.ticket != retry.ticket:
		return "idempotent issue failed"
	var fallback: Variant = SanitizerScript.resolve_policy_attempt(ctx.get("window"), {"status": "returned", "output": "bad"})
	var conflict: Variant = _issue(owner, ctx, {"selection_resolution": fallback})
	if conflict.error_code != "active_ticket_exists" or owner.current_ticket() != first.ticket:
		return "active conflict was not atomic"
	var claimed: Variant = _claim(owner, first.ticket, ctx)
	if not claimed.accepted or _claim(owner, first.ticket, ctx).error_code != "ticket_already_claimed":
		return "one-use claim failed"
	if _issue(owner, ctx).error_code != "binding_already_claimed":
		return "claimed binding reissued"
	for value: Variant in [first.to_public_dict(), first.ticket.to_public_dict(), claimed.to_public_dict()]:
		var encoded := JSON.stringify(value)
		for forbidden: String in [
			"session:alpha", "callback_binding_hash", "private_engine_command", "private_object_refs",
			"command:", "object:", "card:", "binding_owner", "claim_resolutions",
		]:
			if encoded.contains(forbidden):
				return "serialized ticket leaked %s" % forbidden
	var public_copy: Dictionary = first.ticket.to_public_dict()
	public_copy.get("selected_indexes").append(999)
	if first.ticket.to_public_dict().get("selected_indexes").has(999):
		return "ticket public copy mutated owner"
	return ""


func test_ordered_properties_and_equivalent_context_revoke() -> String:
	for indexes: Array in [[0], [1], [1, 0], [0, 1]]:
		var ctx := _context("policy_ordered")
		ctx["resolution"] = SanitizerScript.resolve_policy_attempt(ctx.get("window"), {"status": "returned", "output": indexes})
		var owner: Variant = TicketScript.new()
		var issued: Variant = _issue(owner, ctx)
		if not issued.accepted or issued.ticket.selected_indexes != indexes:
			return "ordered issue differs: expected=%s accepted=%s code=%s actual=%s" % [indexes, issued.accepted, issued.error_code, issued.ticket.selected_indexes if issued.ticket != null else null]
		var claimed: Variant = _claim(owner, issued.ticket, ctx)
		if not claimed.accepted:
			return "ordered claim failed: %s" % [indexes]
		for index: int in range(indexes.size()):
			if claimed.binding_resolutions[index].option_index != indexes[index]:
				return "ordered resolution differs: %s" % [indexes]
	var first := _context("policy_ordered")
	var first_owner: Variant = TicketScript.new()
	var issued: Variant = _issue(first_owner, first)
	var equivalent := _context("policy_ordered")
	var foreign: Variant = _claim(first_owner, issued.ticket, equivalent, {
		"session_id": first.get("session_id"),
		"public_observation_hash": first.get("public_hash"),
		"callback_binding_hash": first.get("callback_hash"),
	})
	if foreign.error_code != "binding_not_current" or first_owner.current_ticket() != null:
		return "equivalent foreign context rebound ticket"
	if _claim(first_owner, issued.ticket, first).error_code != "ticket_revoked":
		return "revoked ticket was reusable"
	return ""


func test_ordinary_mutation_fails_closed() -> String:
	var ctx := _context("policy_ordered")
	var owner: Variant = TicketScript.new()
	var issued: Variant = _issue(owner, ctx)
	issued.ticket.set("_selected_indexes", [0])
	if issued.ticket.validate_integrity(owner) or not issued.ticket.to_public_dict().is_empty():
		return "mutated ticket remained valid or serialized valid=%s public=%s backing=%s" % [issued.ticket.validate_integrity(owner), issued.ticket.to_public_dict(), issued.ticket.get("_selected_indexes")]
	if _claim(owner, issued.ticket, ctx).error_code != "ticket_integrity_invalid":
		return "mutated ticket claim did not fail closed"
	var fresh := _context("policy_ordered")
	var fresh_owner: Variant = TicketScript.new()
	var good: Variant = _issue(fresh_owner, fresh)
	good.set("_public_snapshot", {"private_engine_command": "sentinel"})
	if good.validate_integrity(fresh_owner) or not good.to_public_dict().is_empty():
		return "mutated issue result leaked"
	return ""
