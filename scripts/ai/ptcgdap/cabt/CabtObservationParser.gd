class_name CabtObservationParser
extends RefCounted

const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const CabtRawEnvelopeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtRawEnvelope.gd")
const CabtTreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")
const REQUIRED_CALLBACK_FIELDS := ["select", "logs", "current", "search_begin_input"]
const MAX_SAFE_INTEGER := 9_007_199_254_740_991


class EnvelopeParseResult:
	extends RefCounted

	var _envelope: Variant = null
	var _issues: Array = []

	var envelope: Variant:
		get:
			return _envelope

	var issues: Array:
		get:
			return _issues.duplicate(true)

	var policy_eligible: bool:
		get:
			if _envelope == null:
				return false
			for issue_value: Variant in _issues:
				if issue_value is Dictionary and (issue_value as Dictionary).get("severity") == "error":
					return false
			return true

	var ok: bool:
		get:
			return policy_eligible

	func _init(envelope_value: Variant, issue_values: Array) -> void:
		_envelope = envelope_value
		_issues = issue_values.duplicate(true)

	func safe_diagnostics() -> Array:
		return _issues.duplicate(true)


static func parse_raw_cabt_envelope(
	raw_payload: Variant,
	contract_set: Variant = null
) -> EnvelopeParseResult:
	var validation: Dictionary = CabtJsonTreeScript.canonicalize(raw_payload)
	if not bool(validation.get("ok", false)):
		return EnvelopeParseResult.new(
			null,
			[_issue(_normalize_json_error(str(validation.get("error_code", "invalid_json_tree"))), "")]
		)
	if not _is_exact_json_tree(raw_payload):
		return EnvelopeParseResult.new(null, [_issue("invalid_json_tree", "")])

	var structural_issues := _structural_root_issues(raw_payload)
	if not structural_issues.is_empty():
		return EnvelopeParseResult.new(null, structural_issues)

	var contracts: Variant = contract_set
	if contracts == null:
		contracts = CabtContractSetScript.load_default()
	if (
		contracts == null
		or not contracts is RefCounted
		or contracts.get_script() != CabtContractSetScript
		or not bool(contracts.get("ok"))
		or not contracts.has_method("validate_integrity")
		or contracts.validate_integrity() != true
	):
		return EnvelopeParseResult.new(null, [_issue("contract_runtime_error", "")])

	var state := _new_projector_state(contracts)
	if bool(state.get("runtime_error", false)):
		return EnvelopeParseResult.new(null, [_issue("contract_runtime_error", "")])
	var projection := _project_callback(raw_payload, state)
	if bool(state.get("runtime_error", false)) or not bool(projection.get("ok", false)):
		return EnvelopeParseResult.new(null, [_issue("contract_runtime_error", "")])

	var raw_hash_result: Dictionary = CabtTreeHashScript.raw_private_hash(raw_payload)
	var token_free_result: Dictionary = CabtTreeHashScript.token_free_callback_hash(raw_payload)
	if not bool(raw_hash_result.get("ok", false)) or not bool(token_free_result.get("ok", false)):
		return EnvelopeParseResult.new(null, [_issue("contract_runtime_error", "")])

	var issues: Array = state.get("issues", [])
	var envelope: Variant = CabtRawEnvelopeScript.new().initialize(
		raw_payload,
		projection.get("known_view", {}),
		state.get("presence", {}),
		state.get("unknown", []),
		projection.get("framework", {}),
		state.get("enums", []),
		issues,
		contracts.source_lock_id,
		contracts.source_contract_hash,
		str(raw_hash_result.get("sha256", "")),
		str(token_free_result.get("sha256", ""))
	)
	return EnvelopeParseResult.new(envelope, issues)


static func _new_projector_state(contracts: Variant) -> Dictionary:
	var profile: Dictionary = contracts.typed_profile
	var enum_snapshot: Dictionary = contracts.enum_snapshot
	var state := {
		"profile": profile,
		"presence": {},
		"unknown": [],
		"enums": [],
		"issues": [],
		"enum_names": {},
		"engine_only": {},
		"runtime_error": false,
	}
	var enum_map: Variant = enum_snapshot.get("enums")
	var engine_map: Variant = enum_snapshot.get("locked_engine_only_observations", {})
	if not enum_map is Dictionary or not engine_map is Dictionary:
		state["runtime_error"] = true
		return state

	var enum_names: Dictionary = state.get("enum_names")
	for enum_name_value: Variant in enum_map.keys():
		if typeof(enum_name_value) != TYPE_STRING:
			state["runtime_error"] = true
			return state
		var values_value: Variant = enum_map[enum_name_value]
		if not values_value is Dictionary:
			continue
		var reversed := {}
		for name_value: Variant in values_value.keys():
			var raw_value: Variant = (values_value as Dictionary)[name_value]
			var normalized_raw := _contract_integer_value(raw_value)
			if typeof(name_value) != TYPE_STRING or not bool(normalized_raw.get("valid", false)):
				state["runtime_error"] = true
				return state
			reversed[int(normalized_raw.get("value"))] = str(name_value)
		enum_names[str(enum_name_value)] = reversed

	var engine_only: Dictionary = state.get("engine_only")
	for enum_name_value: Variant in engine_map.keys():
		var values_value: Variant = engine_map[enum_name_value]
		if typeof(enum_name_value) != TYPE_STRING or not values_value is Dictionary:
			state["runtime_error"] = true
			return state
		var reversed := {}
		for raw_text_value: Variant in values_value.keys():
			var known_name_value: Variant = (values_value as Dictionary)[raw_text_value]
			if (
				typeof(raw_text_value) != TYPE_STRING
				or not str(raw_text_value).is_valid_int()
				or typeof(known_name_value) != TYPE_STRING
			):
				state["runtime_error"] = true
				return state
			reversed[str(raw_text_value).to_int()] = str(known_name_value)
		engine_only[str(enum_name_value)] = reversed
	return state


static func _project_callback(raw: Dictionary, state: Dictionary) -> Dictionary:
	var profile: Dictionary = state.get("profile", {})
	var callback_value: Variant = profile.get("callback_root")
	var framework_fields_value: Variant = profile.get("framework_fields")
	if not callback_value is Dictionary or not framework_fields_value is Array:
		state["runtime_error"] = true
		return {"ok": false}
	var callback: Dictionary = callback_value
	var callback_fields_value: Variant = callback.get("fields")
	var known_view_fields_value: Variant = callback.get("known_view_fields")
	if not callback_fields_value is Array or not known_view_fields_value is Array:
		state["runtime_error"] = true
		return {"ok": false}
	var callback_fields: Array = callback_fields_value
	var framework_fields: Array = framework_fields_value

	var known_root_names := {}
	for descriptor_value: Variant in callback_fields:
		if not descriptor_value is Dictionary or typeof((descriptor_value as Dictionary).get("name")) != TYPE_STRING:
			state["runtime_error"] = true
			return {"ok": false}
		known_root_names[str((descriptor_value as Dictionary).get("name"))] = true
	for descriptor_value: Variant in framework_fields:
		if not descriptor_value is Dictionary or typeof((descriptor_value as Dictionary).get("name")) != TYPE_STRING:
			state["runtime_error"] = true
			return {"ok": false}
		known_root_names[str((descriptor_value as Dictionary).get("name"))] = true
	for key: Variant in raw.keys():
		if not known_root_names.has(str(key)):
			_record_unknown(state, _join_pointer("", str(key)), raw[key])

	var known_field_names := {}
	for name_value: Variant in known_view_fields_value:
		if typeof(name_value) != TYPE_STRING:
			state["runtime_error"] = true
			return {"ok": false}
		known_field_names[str(name_value)] = true

	var known_view := {}
	for descriptor_value: Variant in callback_fields:
		var descriptor: Dictionary = descriptor_value
		var name := str(descriptor.get("name"))
		var pointer := _join_pointer("", name)
		if not raw.has(name):
			_set_presence(state, pointer, "missing")
			if bool(descriptor.get("required", false)) or name in REQUIRED_CALLBACK_FIELDS:
				_append_issue(state, "missing_required_field", pointer)
			continue
		var value: Variant = raw[name]
		_set_presence(state, pointer, "null" if value == null else "value")
		if not known_field_names.has(name):
			continue
		var projected := _project_descriptor(value, descriptor, pointer, state)
		known_view[name] = projected.get("value")

	var framework := {
		"step": null,
		"remaining_overage_time": null,
	}
	for descriptor_value: Variant in framework_fields:
		var descriptor: Dictionary = descriptor_value
		var name := str(descriptor.get("name"))
		var pointer := _join_pointer("", name)
		if not raw.has(name):
			_set_presence(state, pointer, "missing")
			continue
		var value: Variant = raw[name]
		_set_presence(state, pointer, "null" if value == null else "value")
		var projected := _project_descriptor(value, descriptor, pointer, state)
		if bool(projected.get("valid", false)):
			var output_name := "remaining_overage_time" if name == "remainingOverageTime" else name
			framework[output_name] = projected.get("value")
	return {
		"ok": not bool(state.get("runtime_error", false)),
		"known_view": known_view,
		"framework": framework,
	}


static func _project_shape(
	value: Variant,
	shape_name: String,
	pointer: String,
	state: Dictionary
) -> Dictionary:
	if not value is Dictionary:
		_append_issue(state, "invalid_field_type", pointer)
		return {"valid": false, "value": null}
	var profile: Dictionary = state.get("profile", {})
	var shapes_value: Variant = profile.get("shapes")
	if not shapes_value is Dictionary:
		state["runtime_error"] = true
		return {"valid": false, "value": null}
	var shape_value: Variant = (shapes_value as Dictionary).get(shape_name)
	if not shape_value is Dictionary:
		_append_issue(state, "unknown_shape", pointer)
		return {"valid": false, "value": null}
	var descriptors_value: Variant = (shape_value as Dictionary).get("fields")
	if not descriptors_value is Array:
		state["runtime_error"] = true
		return {"valid": false, "value": null}
	var descriptors: Array = descriptors_value
	var allowed_names := {}
	for descriptor_value: Variant in descriptors:
		if not descriptor_value is Dictionary or typeof((descriptor_value as Dictionary).get("name")) != TYPE_STRING:
			state["runtime_error"] = true
			return {"valid": false, "value": null}
		var field_name := str((descriptor_value as Dictionary).get("name"))
		allowed_names[field_name] = true

	if shape_name == "Option" or shape_name == "Log":
		allowed_names = {"type": true}
		var raw_type: Variant = (value as Dictionary).get("type")
		var normalized_type := _integer_value(raw_type)
		if bool(normalized_type.get("valid", false)):
			var sparse_name := "option_shapes" if shape_name == "Option" else "log_shapes"
			var sparse_root: Variant = profile.get(sparse_name)
			if not sparse_root is Dictionary:
				state["runtime_error"] = true
				return {"valid": false, "value": null}
			var sparse_value: Variant = (sparse_root as Dictionary).get(str(normalized_type.get("value")))
			if sparse_value is Array:
				allowed_names = {}
				for field_value: Variant in sparse_value:
					if typeof(field_value) != TYPE_STRING:
						state["runtime_error"] = true
						return {"valid": false, "value": null}
					allowed_names[str(field_value)] = true

	for descriptor_value: Variant in descriptors:
		var descriptor: Dictionary = descriptor_value
		var field_name := str(descriptor.get("name"))
		var field_pointer := _join_pointer(pointer, field_name)
		if not (value as Dictionary).has(field_name):
			_set_presence(state, field_pointer, "missing")
		else:
			var child: Variant = (value as Dictionary)[field_name]
			_set_presence(state, field_pointer, "null" if child == null else "value")

	for key: Variant in (value as Dictionary).keys():
		if not allowed_names.has(str(key)):
			_record_unknown(state, _join_pointer(pointer, str(key)), (value as Dictionary)[key])

	var result := {}
	var all_valid := true
	for descriptor_value: Variant in descriptors:
		var descriptor: Dictionary = descriptor_value
		var name := str(descriptor.get("name"))
		if not allowed_names.has(name):
			continue
		var field_pointer := _join_pointer(pointer, name)
		if not (value as Dictionary).has(name):
			if bool(descriptor.get("required", false)):
				_append_issue(state, "missing_required_field", field_pointer)
				all_valid = false
			continue
		var projected := _project_descriptor((value as Dictionary)[name], descriptor, field_pointer, state)
		if not bool(projected.get("valid", false)):
			all_valid = false
		else:
			result[name] = projected.get("value")
	return {"valid": all_valid, "value": result}


static func _project_descriptor(
	value: Variant,
	descriptor: Dictionary,
	pointer: String,
	state: Dictionary
) -> Dictionary:
	if value == null:
		if bool(descriptor.get("nullable", false)):
			return {"valid": true, "value": null}
		_append_issue(state, "invalid_null", pointer)
		return {"valid": false, "value": null}
	var kind_value: Variant = descriptor.get("kind")
	if typeof(kind_value) != TYPE_STRING:
		state["runtime_error"] = true
		return {"valid": false, "value": null}
	var kind := str(kind_value)
	if kind == "shape":
		var shape_value: Variant = descriptor.get("shape")
		if typeof(shape_value) != TYPE_STRING:
			state["runtime_error"] = true
			return {"valid": false, "value": null}
		return _project_shape(value, str(shape_value), pointer, state)
	if kind == "array":
		if not value is Array:
			_append_issue(state, "invalid_field_type", pointer)
			return {"valid": false, "value": null}
		var items_value: Variant = descriptor.get("items")
		if not items_value is Dictionary:
			_append_issue(state, "invalid_contract_descriptor", pointer)
			return {"valid": false, "value": null}
		var projected_items := []
		var all_valid := true
		for index: int in (value as Array).size():
			var projected := _project_descriptor(
				(value as Array)[index],
				items_value,
				_join_pointer(pointer, str(index)),
				state
			)
			var valid := bool(projected.get("valid", false))
			all_valid = all_valid and valid
			projected_items.append(projected.get("value") if valid else null)
		return {"valid": all_valid, "value": projected_items}

	var valid_scalar := false
	var projected_scalar: Variant = value
	match kind:
		"integer":
			var normalized_integer := _integer_value(value)
			valid_scalar = bool(normalized_integer.get("valid", false))
			if valid_scalar:
				projected_scalar = int(normalized_integer.get("value"))
		"number":
			valid_scalar = typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
		"boolean":
			valid_scalar = typeof(value) == TYPE_BOOL
		"string":
			valid_scalar = typeof(value) == TYPE_STRING
		_:
			valid_scalar = false
	if not valid_scalar:
		_append_issue(state, "invalid_enum_type" if descriptor.has("enum") else "invalid_field_type", pointer)
		return {"valid": false, "value": null}
	var enum_value: Variant = descriptor.get("enum")
	if typeof(enum_value) == TYPE_STRING:
		_record_enum(state, str(enum_value), int(projected_scalar), pointer)
	return {"valid": true, "value": projected_scalar}


static func _record_enum(state: Dictionary, enum_name: String, raw_value: int, pointer: String) -> void:
	var enum_names: Dictionary = state.get("enum_names", {})
	var engine_only: Dictionary = state.get("engine_only", {})
	var known_name: Variant = null
	var authority := "official_known"
	var official_values: Variant = enum_names.get(enum_name)
	if official_values is Dictionary:
		known_name = (official_values as Dictionary).get(raw_value)
	if known_name == null:
		var engine_values: Variant = engine_only.get(enum_name)
		if engine_values is Dictionary:
			known_name = (engine_values as Dictionary).get(raw_value)
		authority = "locked_engine_only" if known_name != null else "unknown_future"
	var enums: Array = state.get("enums", [])
	enums.append({
		"pointer": pointer,
		"raw_int": raw_value,
		"known_name": known_name,
		"authority": authority,
	})
	if authority == "unknown_future":
		_append_issue(state, "unknown_enum_value", pointer)


static func _record_unknown(state: Dictionary, pointer: String, value: Variant) -> void:
	var unknown: Array = state.get("unknown", [])
	unknown.append({
		"pointer": pointer,
		"presence": "null" if value == null else "value",
		"json_type": _json_type_name(value),
	})


static func _set_presence(state: Dictionary, pointer: String, presence: String) -> void:
	var values: Dictionary = state.get("presence", {})
	values[pointer] = presence


static func _append_issue(state: Dictionary, code: String, pointer: String) -> void:
	var issues: Array = state.get("issues", [])
	issues.append(_issue(code, pointer))


static func _issue(code: String, pointer: String, severity: String = "error") -> Dictionary:
	return {
		"code": code,
		"pointer": pointer,
		"severity": severity,
	}


static func _structural_root_issues(raw: Variant) -> Array:
	if not raw is Dictionary:
		return [_issue("callback_root_not_object", "")]
	var issues := []
	for field_name: String in REQUIRED_CALLBACK_FIELDS:
		if not (raw as Dictionary).has(field_name):
			issues.append(_issue("missing_required_field", "/%s" % field_name))
	if not issues.is_empty():
		return issues
	var select_value: Variant = (raw as Dictionary).get("select")
	var logs_value: Variant = (raw as Dictionary).get("logs")
	var current_value: Variant = (raw as Dictionary).get("current")
	var search_value: Variant = (raw as Dictionary).get("search_begin_input")
	if select_value != null and not select_value is Dictionary:
		issues.append(_issue("invalid_field_type", "/select"))
	if not logs_value is Array:
		issues.append(_issue("invalid_field_type", "/logs"))
	if current_value != null and not current_value is Dictionary:
		issues.append(_issue("invalid_field_type", "/current"))
	if search_value != null and typeof(search_value) != TYPE_STRING:
		issues.append(_issue("invalid_field_type", "/search_begin_input"))
	return issues


static func _normalize_json_error(code: String) -> String:
	match code:
		"non_finite_number", "non_json_value", "non_string_object_key", "unsupported_type", "non_string_key":
			return "invalid_json_tree"
		"lone_surrogate", "invalid_unicode":
			return "invalid_unicode"
		"unsafe_integer":
			return "integer_out_of_range"
		"cycle_detected":
			return "cyclic_json_tree"
		"depth_limit":
			return "json_tree_too_deep"
		"node_limit":
			return "json_tree_too_large"
		_:
			return code if not code.is_empty() else "invalid_json_tree"


static func _is_exact_json_tree(root: Variant) -> bool:
	var stack: Array = [root]
	while not stack.is_empty():
		var current: Variant = stack.pop_back()
		match typeof(current):
			TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
				pass
			TYPE_ARRAY:
				for child: Variant in current:
					stack.append(child)
			TYPE_DICTIONARY:
				for key: Variant in current.keys():
					if typeof(key) != TYPE_STRING:
						return false
					stack.append(current[key])
			_:
				return false
	return true


static func _join_pointer(parent: String, segment: String) -> String:
	return "%s/%s" % [parent, segment.replace("~", "~0").replace("/", "~1")]


static func _json_type_name(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "boolean"
		TYPE_INT:
			return "integer"
		TYPE_FLOAT:
			return "number"
		TYPE_STRING:
			return "string"
		TYPE_ARRAY:
			return "array"
		TYPE_DICTIONARY:
			return "object"
		_:
			return "invalid"


static func _integer_value(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_INT:
		return {"valid": false, "value": 0}
	var integer_value := int(value)
	if integer_value >= -MAX_SAFE_INTEGER and integer_value <= MAX_SAFE_INTEGER:
		return {"valid": true, "value": integer_value}
	return {"valid": false, "value": 0}


static func _contract_integer_value(value: Variant) -> Dictionary:
	var exact := _integer_value(value)
	if bool(exact.get("valid", false)):
		return exact
	# Godot's JSON contract loader materializes every JSON number as float.
	# This compatibility path is contract-only; raw callbacks remain exact-int.
	if typeof(value) == TYPE_FLOAT:
		var number := float(value)
		if (
			is_finite(number)
			and number == floorf(number)
			and number >= -float(MAX_SAFE_INTEGER)
			and number <= float(MAX_SAFE_INTEGER)
		):
			return {"valid": true, "value": int(number)}
	return {"valid": false, "value": 0}
