class_name TestGodotOptionBinding
extends TestBase

const BindingScript = preload("res://scripts/engine/decision/GodotOptionBinding.gd")
const PortScript = preload("res://scripts/engine/decision/EngineDecisionPort.gd")
const WindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")
const ContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CardInstanceScript = preload("res://scripts/data/CardInstance.gd")
const VECTOR_PATH := "res://contracts/ptcgdap/godot_option_binding_conformance_vectors.json"
const EXPECTED_BUNDLE_HASH := "4FFFEC48E4E1FE0774BB6E343D4D4B0384A9210057DEE06415C2A20F2899B1C1"
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


func _vectors() -> Dictionary:
	var file := FileAccess.open(VECTOR_PATH, FileAccess.READ)
	if file == null:
		return {}
	var restored: Variant = _restore_json_integer_tokens(JSON.parse_string(file.get_as_text()))
	return restored if restored is Dictionary else {}


func _materialize(value: Variant, refs: Dictionary) -> Variant:
	if typeof(value) == TYPE_STRING and str(value).begins_with("card:"):
		if not refs.has(value):
			refs[value] = CardInstanceScript.new()
		return refs[value]
	if typeof(value) == TYPE_STRING and (
		str(value).begins_with("command:") or str(value).begins_with("object:")
	):
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
	if result == null or typeof(result) != TYPE_OBJECT:
		return null
	if not WindowScript.validate_build_result_integrity(result):
		return null
	return result.get("window")


func _context() -> Dictionary:
	var fixture: Dictionary = (_vectors().get("fixture", {}) as Dictionary).duplicate(true)
	var refs := {}
	var source: Dictionary = _materialize(fixture.get("source"), refs)
	var window: Variant = _build_window(fixture.get("window"))
	if window == null:
		return {"error": "window_build_failed"}
	var commands: Array = _materialize(fixture.get("private_commands"), refs)
	var private_refs: Array = _materialize(fixture.get("private_object_refs"), refs)
	var port: Variant = PortScript.open_match(fixture.get("match_generation"))
	var published: Variant = port.publish(
		source,
		fixture.get("decision_generation"),
		fixture.get("chooser_player_index")
	)
	if not published.accepted:
		return {"error": "port_publish_failed:%s" % published.error_code}
	return {
		"fixture": fixture,
		"refs": refs,
		"source": source,
		"window": window,
		"commands": commands,
		"private_refs": private_refs,
		"port": port,
		"snapshot": published.snapshot,
	}


func _bind(owner: Variant, ctx: Dictionary) -> Variant:
	var fixture: Dictionary = ctx.get("fixture")
	return owner.bind(
		ctx.get("port"),
		ctx.get("snapshot"),
		ctx.get("source"),
		ctx.get("window"),
		fixture.get("callback_binding_hash"),
		ctx.get("commands"),
		ctx.get("private_refs")
	)


func _apply_bind_fault(fault: String, ctx: Dictionary) -> Dictionary:
	var fixture: Dictionary = ctx.get("fixture")
	var source: Variant = ctx.get("source")
	var window: Variant = ctx.get("window")
	var callback_hash: Variant = fixture.get("callback_binding_hash")
	var commands: Variant = (ctx.get("commands") as Array).duplicate()
	var private_refs: Variant = (ctx.get("private_refs") as Array).duplicate(true)
	if fault in ["window_option_reorder", "window_payload_change", "window_chooser_change"]:
		var spec: Dictionary = (fixture.get("window") as Dictionary).duplicate(true)
		if fault == "window_option_reorder":
			var options: Array = spec.get("select").get("option")
			var temporary: Variant = options[0]
			options[0] = options[1]
			options[1] = temporary
		elif fault == "window_payload_change":
			spec.get("select").get("option")[1]["index"] += 1
		else:
			spec["chooser_player_index"] = 1
		window = _build_window(spec)
	elif fault == "callback_lowercase":
		callback_hash = str(callback_hash).to_lower()
	elif fault == "command_count":
		commands.pop_back()
	elif fault == "command_primitive":
		commands[0] = 17
	elif fault == "reference_count":
		private_refs.pop_back()
	elif fault == "reference_primitive":
		private_refs[0] = [17]
	elif fault == "source_mutation":
		source = (source as Dictionary).duplicate(true)
		source["turn_action_count"] += 1
	elif fault == "null_window":
		window = null
	return {
		"source": source,
		"window": window,
		"callback_hash": callback_hash,
		"commands": commands,
		"private_refs": private_refs,
	}


func test_fixed_contract_loads() -> String:
	var owner: Variant = BindingScript.new()
	if not owner.validate_integrity():
		return "binding contract failed to load"
	if owner.contract_hash != EXPECTED_BUNDLE_HASH:
		return "binding bundle anchor differs"
	return ""


func test_shared_bind_vectors() -> String:
	var cases: Array = _vectors().get("bind_cases", [])
	if cases.size() != 11:
		return "bind vector count differs: %d" % cases.size()
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		var ctx := _context()
		if ctx.has("error"):
			return "%s context failed: %s" % [case.get("id"), ctx.get("error")]
		var fault := _apply_bind_fault(case.get("fault"), ctx)
		var owner: Variant = BindingScript.new()
		var result: Variant = owner.bind(
			ctx.get("port"),
			ctx.get("snapshot"),
			fault.get("source"),
			fault.get("window"),
			fault.get("callback_hash"),
			fault.get("commands"),
			fault.get("private_refs")
		)
		var expected: Dictionary = case.get("expected")
		if result.accepted != expected.get("accepted") or result.error_code != expected.get("error_code"):
			return "%s result differs: %s" % [case.get("id"), result.error_code]
		if result.to_public_dict() != expected:
			return "%s public result differs" % case.get("id")
		if not result.validate_integrity(owner):
			return "%s result integrity failed" % case.get("id")
		if result.accepted:
			if result.binding != owner.current_binding() or not result.binding.validate_integrity(owner):
				return "%s binding integrity failed" % case.get("id")
			var serialized := JSON.stringify(result.to_public_dict())
			for forbidden: String in [
				"callback_binding_hash", "private_engine_command", "private_object_refs",
				"command:", "object:", "card:", "_pending_choice", "_dialog_data",
			]:
				if serialized.contains(forbidden):
					return "%s leaked %s" % [case.get("id"), forbidden]
	return ""


func test_shared_resolve_vectors() -> String:
	var cases: Array = _vectors().get("resolve_cases", [])
	if cases.size() != 8:
		return "resolve vector count differs: %d" % cases.size()
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		var ctx := _context()
		var owner: Variant = BindingScript.new()
		var bound: Variant = _bind(owner, ctx)
		if not bound.accepted:
			return "%s valid bind failed: %s" % [case.get("id"), bound.error_code]
		var source: Variant = ctx.get("source")
		var window: Variant = ctx.get("window")
		var callback_hash: Variant = ctx.get("fixture").get("callback_binding_hash")
		var option_index: Variant = case.get("option_index")
		match case.get("fault"):
			"callback_change":
				callback_hash = "B".repeat(64)
			"source_mutation":
				source = (source as Dictionary).duplicate(true)
				source["turn_action_count"] += 1
			"equivalent_window_copy":
				window = _build_window(ctx.get("fixture").get("window"))
				if window == ctx.get("window") or window.to_public_dict() != ctx.get("window").to_public_dict():
					return "%s equivalent copy fixture invalid" % case.get("id")
			"bool_index":
				option_index = true
			"none", "negative_index", "out_of_range":
				pass
			_:
				return "%s unknown fault" % case.get("id")
		var result: Variant = owner.resolve(
			bound.binding,
			ctx.get("port"),
			ctx.get("snapshot"),
			source,
			window,
			callback_hash,
			option_index
		)
		var expected: Dictionary = case.get("expected")
		if result.accepted != expected.get("accepted") or result.error_code != expected.get("error_code"):
			return "%s resolution differs: %s" % [case.get("id"), result.error_code]
		if result.to_public_dict() != expected or not result.validate_integrity(owner):
			return "%s resolution audit/integrity differs" % case.get("id")
		if result.accepted:
			if result.private_engine_command != ctx.get("commands")[option_index]:
				return "%s command identity differs" % case.get("id")
			var actual_refs: Array = result.private_object_refs
			var expected_refs: Array = ctx.get("private_refs")[option_index]
			if actual_refs.size() != expected_refs.size():
				return "%s private ref count differs" % case.get("id")
			for index: int in range(actual_refs.size()):
				if actual_refs[index] != expected_refs[index]:
					return "%s private ref identity differs" % case.get("id")
	return ""


func test_atomic_replacement_and_new_snapshot_invalidate_old() -> String:
	var ctx := _context()
	var owner: Variant = BindingScript.new()
	var first: Variant = _bind(owner, ctx)
	if not first.accepted:
		return "first bind failed"
	var rejected: Variant = owner.bind(
		ctx.get("port"), ctx.get("snapshot"), ctx.get("source"), ctx.get("window"),
		"bad", ctx.get("commands"), ctx.get("private_refs")
	)
	if rejected.accepted:
		return "bad replacement accepted"
	var current: Variant = owner.resolve(
		first.binding, ctx.get("port"), ctx.get("snapshot"), ctx.get("source"), ctx.get("window"),
		ctx.get("fixture").get("callback_binding_hash"), 0
	)
	if not current.accepted:
		return "rejected replacement disturbed current binding"
	var replacement_commands := []
	for unused: Variant in ctx.get("commands"):
		replacement_commands.append(HostRef.new())
	var replacement: Variant = owner.bind(
		ctx.get("port"), ctx.get("snapshot"), ctx.get("source"), ctx.get("window"),
		ctx.get("fixture").get("callback_binding_hash"), replacement_commands, ctx.get("private_refs")
	)
	if not replacement.accepted:
		return "accepted replacement failed"
	if owner.resolve(
		first.binding, ctx.get("port"), ctx.get("snapshot"), ctx.get("source"), ctx.get("window"),
		ctx.get("fixture").get("callback_binding_hash"), 0
	).error_code != "binding_not_current":
		return "old binding remained current"
	var published: Variant = ctx.get("port").publish(
		ctx.get("source"),
		ctx.get("fixture").get("decision_generation") + 1,
		ctx.get("fixture").get("chooser_player_index")
	)
	if not published.accepted:
		return "new snapshot failed"
	if owner.resolve(
		replacement.binding, ctx.get("port"), ctx.get("snapshot"), ctx.get("source"), ctx.get("window"),
		ctx.get("fixture").get("callback_binding_hash"), 0
	).error_code != "snapshot_not_current":
		return "old snapshot binding remained current"
	return ""


func test_release_cross_owner_and_ordinary_mutation_fail_closed() -> String:
	var ctx := _context()
	var owner: Variant = BindingScript.new()
	var bound: Variant = _bind(owner, ctx)
	var other: Variant = BindingScript.new()
	if other.resolve(
		bound.binding, ctx.get("port"), ctx.get("snapshot"), ctx.get("source"), ctx.get("window"),
		ctx.get("fixture").get("callback_binding_hash"), 0
	).error_code != "owner_mismatch":
		return "cross-owner binding accepted"
	bound.binding.set("_audit", {"private_engine_command": "private-sentinel"})
	if bound.binding.validate_integrity(owner) or bound.binding.to_audit_dict() != {}:
		return "mutated binding retained integrity"
	if owner.resolve(
		bound.binding, ctx.get("port"), ctx.get("snapshot"), ctx.get("source"), ctx.get("window"),
		ctx.get("fixture").get("callback_binding_hash"), 0
	).error_code != "binding_integrity_invalid":
		return "mutated binding resolved"

	ctx = _context()
	owner = BindingScript.new()
	bound = _bind(owner, ctx)
	var commands: Array = ctx.get("commands")
	commands[0] = null
	ctx.get("refs").erase("command:0")
	if owner.resolve(
		bound.binding, ctx.get("port"), ctx.get("snapshot"), ctx.get("source"), ctx.get("window"),
		ctx.get("fixture").get("callback_binding_hash"), 0
	).error_code != "reference_released":
		return "released command resolved"

	ctx = _context()
	owner = BindingScript.new()
	bound = _bind(owner, ctx)
	var private_refs: Array = ctx.get("private_refs")
	private_refs[0][0] = null
	ctx.get("refs").erase("object:card-choice")
	if owner.resolve(
		bound.binding, ctx.get("port"), ctx.get("snapshot"), ctx.get("source"), ctx.get("window"),
		ctx.get("fixture").get("callback_binding_hash"), 0
	).error_code != "reference_released":
		return "released private object resolved"

	ctx = _context()
	owner = BindingScript.new()
	bound = _bind(owner, ctx)
	var owner_state: Dictionary = owner.get("_current")
	owner_state.get("audit")["private_engine_command"] = "private-sentinel"
	if bound.binding.validate_integrity(owner) or bound.binding.to_audit_dict() != {}:
		return "mutated owner state retained integrity"
	return ""


func test_godot_host_types_and_private_echo_are_closed() -> String:
	var ctx := _context()
	var owner: Variant = BindingScript.new()
	var typed_commands := PackedInt32Array([1, 2, 3, 4, 5])
	if owner.bind(
		ctx.get("port"), ctx.get("snapshot"), ctx.get("source"), ctx.get("window"),
		ctx.get("fixture").get("callback_binding_hash"), typed_commands, ctx.get("private_refs")
	).error_code != "invalid_private_commands":
		return "typed command array accepted"
	if owner.bind(
		ctx.get("port"), ctx.get("snapshot"), ctx.get("source"), ctx.get("window"),
		StringName(ctx.get("fixture").get("callback_binding_hash")), ctx.get("commands"), ctx.get("private_refs")
	).error_code != "invalid_callback_binding_hash":
		return "StringName callback hash accepted"
	var bound: Variant = _bind(owner, ctx)
	if not bound.accepted:
		return "valid bind failed"
	if owner.resolve(
		bound.binding, ctx.get("port"), ctx.get("snapshot"), ctx.get("source"), ctx.get("window"),
		ctx.get("fixture").get("callback_binding_hash"), true
	).error_code != "option_index_invalid":
		return "bool option index accepted"
	var serialized := JSON.stringify(bound.to_public_dict())
	for forbidden: String in ["callback_binding_hash", "private_engine_command", "private_object_refs", "command:", "object:", "card:"]:
		if serialized.contains(forbidden):
			return "public DTO leaked %s" % forbidden
	for forbidden_method: String in ["ticket", "consume", "commit", "execute", "dispatch"]:
		for method: Dictionary in owner.get_method_list():
			if str(method.get("name", "")).to_lower().contains(forbidden_method):
				return "forbidden owner method exposed: %s" % method.get("name")
	return ""


func test_position_permutations_preserve_fingerprints_and_commands() -> String:
	var orders := [
		[0, 1, 2, 3, 4],
		[4, 3, 2, 1, 0],
		[2, 0, 4, 1, 3],
		[1, 3, 0, 4, 2],
	]
	for order: Array in orders:
		var fixture: Dictionary = (_vectors().get("fixture") as Dictionary).duplicate(true)
		var source_spec: Dictionary = fixture.get("source")
		var window_spec: Dictionary = fixture.get("window")
		var source_options: Array = source_spec.get("select").get("option").duplicate(true)
		var source_refs: Array = source_spec.get("option_card_refs").duplicate(true)
		var window_options: Array = window_spec.get("select").get("option").duplicate(true)
		source_spec.get("select")["option"] = []
		source_spec["option_card_refs"] = []
		window_spec.get("select")["option"] = []
		for index: int in order:
			source_spec.get("select").get("option").append(source_options[index])
			source_spec.get("option_card_refs").append(source_refs[index])
			window_spec.get("select").get("option").append(window_options[index])
		var refs := {}
		var source: Dictionary = _materialize(source_spec, refs)
		var window: Variant = _build_window(window_spec)
		var commands := []
		var private_refs := []
		for index: int in order.size():
			commands.append(HostRef.new())
			private_refs.append([HostRef.new()] if index % 2 == 0 else [])
		var port: Variant = PortScript.open_match(fixture.get("match_generation"))
		var published: Variant = port.publish(source, fixture.get("decision_generation"), fixture.get("chooser_player_index"))
		var owner: Variant = BindingScript.new()
		var bound: Variant = owner.bind(
			port, published.snapshot, source, window, fixture.get("callback_binding_hash"), commands, private_refs
		)
		if not bound.accepted:
			return "order %s bind failed: %s" % [order, bound.error_code]
		if bound.binding.to_audit_dict().get("option_fingerprints") != window.option_fingerprints:
			return "order %s fingerprint order differs" % [order]
		for index: int in commands.size():
			var resolved: Variant = owner.resolve(
				bound.binding, port, published.snapshot, source, window,
				fixture.get("callback_binding_hash"), index
			)
			if not resolved.accepted or resolved.private_engine_command != commands[index]:
				return "order %s index %d resolution differs" % [order, index]
	return ""
