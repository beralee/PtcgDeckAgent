class_name CabtJsonTree
extends RefCounted

const MAX_DEPTH := 128
const MAX_NODES := 1_000_000
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_INPUT_BYTES := 67_108_864
const MAX_OUTPUT_BYTES := 67_108_864
const DEFAULT_LIMITS := {
	"max_input_bytes": MAX_INPUT_BYTES,
	"max_depth": MAX_DEPTH,
	"max_nodes": MAX_NODES,
	"max_output_bytes": MAX_OUTPUT_BYTES,
}


static func canonicalize(value: Variant, limit_overrides: Dictionary = {}) -> Dictionary:
	var resolved := _resolve_limits(limit_overrides)
	if not bool(resolved.get("ok", false)):
		return resolved
	var limits: Dictionary = resolved.get("limits", {})
	var validation := _validate_tree(value, limits)
	if not bool(validation.get("ok", false)):
		return validation
	var state := {"nodes": 0, "ancestors": [], "limits": limits}
	var result: Dictionary = _serialize(value, state, 0)
	if not bool(result.get("ok", false)):
		return result
	var canonical_text := str(result.get("text", ""))
	return {
		"ok": true,
		"error_code": "",
		"text": canonical_text,
		"bytes": canonical_text.to_utf8_buffer(),
	}


static func canonicalize_artifact(
	value: Variant,
	limit_overrides: Dictionary = {},
) -> Dictionary:
	var resolved := _resolve_limits(limit_overrides)
	if not bool(resolved.get("ok", false)):
		return resolved
	var limits: Dictionary = resolved.get("limits", {})
	var validation := _validate_tree(value, limits)
	if not bool(validation.get("ok", false)):
		return validation
	var state := {"nodes": 0, "ancestors": [], "limits": limits}
	var result: Dictionary = _serialize_artifact(value, state, 0)
	if not bool(result.get("ok", false)):
		return result
	var canonical_text := str(result.get("text", ""))
	var canonical_bytes := canonical_text.to_utf8_buffer()
	if canonical_bytes.size() > int(limits.get("max_output_bytes", MAX_OUTPUT_BYTES)):
		return _error("output_size_limit")
	return {
		"ok": true,
		"error_code": "",
		"text": canonical_text,
		"bytes": canonical_bytes,
	}


static func canonicalize_unicode_codepoints(
	codepoints: Array,
	limit_overrides: Dictionary = {},
) -> Dictionary:
	var resolved := _resolve_limits(limit_overrides)
	if not bool(resolved.get("ok", false)):
		return resolved
	var limits: Dictionary = resolved.get("limits", {})
	if int(limits.get("max_nodes", 0)) < 1:
		return _error("node_limit")
	var result := _serialize_codepoints(codepoints)
	if not bool(result.get("ok", false)):
		return result
	var canonical_text := str(result.get("text", ""))
	if canonical_text.to_utf8_buffer().size() > int(limits.get("max_output_bytes", 0)):
		return _error("output_size_limit")
	return {
		"ok": true,
		"error_code": "",
		"text": canonical_text,
		"bytes": canonical_text.to_utf8_buffer(),
	}


static func canonicalize_json_bytes(
	data: PackedByteArray,
	limit_overrides: Dictionary = {},
) -> Dictionary:
	var resolved := _resolve_limits(limit_overrides)
	if not bool(resolved.get("ok", false)):
		return resolved
	var limits: Dictionary = resolved.get("limits", {})
	if data.size() > int(limits.get("max_input_bytes", 0)):
		return _error("input_size_limit")
	var text := data.get_string_from_utf8()
	if text.to_utf8_buffer() != data:
		return _error("invalid_json")
	return _canonicalize_json_text(text, limits)


static func canonicalize_artifact_json_bytes(
	data: PackedByteArray,
	limit_overrides: Dictionary = {},
) -> Dictionary:
	var resolved := _resolve_limits(limit_overrides)
	if not bool(resolved.get("ok", false)):
		return resolved
	var limits: Dictionary = resolved.get("limits", {})
	if data.size() > int(limits.get("max_input_bytes", 0)):
		return _error("input_size_limit")
	var text := data.get_string_from_utf8()
	if text.to_utf8_buffer() != data:
		return _error("invalid_json")
	return _canonicalize_artifact_json_text(text, limits)


static func _serialize(value: Variant, state: Dictionary, depth: int) -> Dictionary:
	var limits: Dictionary = state.get("limits", DEFAULT_LIMITS)
	if depth > int(limits.get("max_depth", MAX_DEPTH)):
		return _error("depth_limit")
	state["nodes"] = int(state.get("nodes", 0)) + 1
	if int(state.get("nodes", 0)) > int(limits.get("max_nodes", MAX_NODES)):
		return _error("node_limit")

	match typeof(value):
		TYPE_NIL:
			return _success("null")
		TYPE_BOOL:
			return _success("true" if bool(value) else "false")
		TYPE_INT:
			var integer_value := int(value)
			if integer_value < -MAX_SAFE_INTEGER or integer_value > MAX_SAFE_INTEGER:
				return _error("unsafe_integer")
			return _success(str(integer_value))
		TYPE_FLOAT:
			var number := float(value)
			if not is_finite(number):
				return _error("non_finite_number")
			return _success(_serialize_float(number))
		TYPE_STRING:
			return _serialize_string(str(value))
		TYPE_ARRAY:
			return _serialize_array(value, state, depth)
		TYPE_DICTIONARY:
			return _serialize_dictionary(value, state, depth)
		_:
			return _error("unsupported_type")


static func _serialize_artifact(
	value: Variant,
	state: Dictionary,
	depth: int,
) -> Dictionary:
	var limits: Dictionary = state.get("limits", DEFAULT_LIMITS)
	if depth > int(limits.get("max_depth", MAX_DEPTH)):
		return _error("depth_limit")
	state["nodes"] = int(state.get("nodes", 0)) + 1
	if int(state.get("nodes", 0)) > int(limits.get("max_nodes", MAX_NODES)):
		return _error("node_limit")

	match typeof(value):
		TYPE_NIL:
			return _success("null")
		TYPE_BOOL:
			return _success("true" if bool(value) else "false")
		TYPE_INT:
			var integer_value := int(value)
			if integer_value < -MAX_SAFE_INTEGER or integer_value > MAX_SAFE_INTEGER:
				return _error("unsafe_integer")
			return _success(str(integer_value))
		TYPE_STRING:
			return _serialize_string(str(value))
		TYPE_ARRAY:
			return _serialize_artifact_array(value, state, depth)
		TYPE_DICTIONARY:
			return _serialize_artifact_dictionary(value, state, depth)
		_:
			return _error("unsupported_type")


static func _serialize_artifact_array(
	value: Array,
	state: Dictionary,
	depth: int,
) -> Dictionary:
	if _is_ancestor(value, state.get("ancestors", [])):
		return _error("cycle_detected")
	var ancestors: Array = state.get("ancestors", [])
	ancestors.append(value)
	var parts := PackedStringArray()
	for child: Variant in value:
		var result := _serialize_artifact(child, state, depth + 1)
		if not bool(result.get("ok", false)):
			ancestors.pop_back()
			return result
		parts.append(str(result.get("text", "")))
	ancestors.pop_back()
	return _success("[" + ",".join(parts) + "]")


static func _serialize_artifact_dictionary(
	value: Dictionary,
	state: Dictionary,
	depth: int,
) -> Dictionary:
	if _is_ancestor(value, state.get("ancestors", [])):
		return _error("cycle_detected")
	var entries: Array = []
	for key_value: Variant in value.keys():
		if typeof(key_value) != TYPE_STRING:
			return _error("non_string_key")
		var key := str(key_value)
		var codepoints: Array = []
		for index in key.length():
			codepoints.append(key.unicode_at(index))
		entries.append({"key": key, "key_codepoints": codepoints})
	entries.sort_custom(_artifact_json_entry_less)

	var ancestors: Array = state.get("ancestors", [])
	ancestors.append(value)
	var parts := PackedStringArray()
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		var key := str(entry.get("key", ""))
		var key_result := _serialize_string(key)
		if not bool(key_result.get("ok", false)):
			ancestors.pop_back()
			return key_result
		var child_result := _serialize_artifact(value[key], state, depth + 1)
		if not bool(child_result.get("ok", false)):
			ancestors.pop_back()
			return child_result
		parts.append(str(key_result.get("text", "")) + ":" + str(child_result.get("text", "")))
	ancestors.pop_back()
	return _success("{" + ",".join(parts) + "}")


static func _serialize_array(value: Array, state: Dictionary, depth: int) -> Dictionary:
	if _is_ancestor(value, state.get("ancestors", [])):
		return _error("cycle_detected")
	var ancestors: Array = state.get("ancestors", [])
	ancestors.append(value)
	var parts: PackedStringArray = PackedStringArray()
	for child: Variant in value:
		var result: Dictionary = _serialize(child, state, depth + 1)
		if not bool(result.get("ok", false)):
			ancestors.pop_back()
			return result
		parts.append(str(result.get("text", "")))
	ancestors.pop_back()
	return _success("[" + ",".join(parts) + "]")


static func _serialize_dictionary(value: Dictionary, state: Dictionary, depth: int) -> Dictionary:
	if _is_ancestor(value, state.get("ancestors", [])):
		return _error("cycle_detected")
	var keys: Array = value.keys()
	for key: Variant in keys:
		if typeof(key) != TYPE_STRING:
			return _error("non_string_key")
	keys.sort_custom(_utf16_less)

	var ancestors: Array = state.get("ancestors", [])
	ancestors.append(value)
	var parts: PackedStringArray = PackedStringArray()
	for key_value: Variant in keys:
		var key := str(key_value)
		var key_result: Dictionary = _serialize_string(key)
		if not bool(key_result.get("ok", false)):
			ancestors.pop_back()
			return key_result
		var child_result: Dictionary = _serialize(value[key_value], state, depth + 1)
		if not bool(child_result.get("ok", false)):
			ancestors.pop_back()
			return child_result
		parts.append(str(key_result.get("text", "")) + ":" + str(child_result.get("text", "")))
	ancestors.pop_back()
	return _success("{" + ",".join(parts) + "}")


static func _serialize_string(value: String) -> Dictionary:
	var codepoints: Array = []
	for index in value.length():
		codepoints.append(value.unicode_at(index))
	return _serialize_codepoints(codepoints)


static func _serialize_codepoints(codepoints: Array) -> Dictionary:
	var result := "\""
	for codepoint_value: Variant in codepoints:
		if typeof(codepoint_value) != TYPE_INT and typeof(codepoint_value) != TYPE_FLOAT:
			return _error("invalid_unicode")
		if typeof(codepoint_value) == TYPE_FLOAT and (
			not is_finite(float(codepoint_value))
			or float(codepoint_value) != floorf(float(codepoint_value))
		):
			return _error("invalid_unicode")
		var codepoint := int(codepoint_value)
		if _is_invalid_unicode_scalar(codepoint):
			return _error("invalid_unicode")
		match codepoint:
			0x08:
				result += "\\b"
			0x09:
				result += "\\t"
			0x0A:
				result += "\\n"
			0x0C:
				result += "\\f"
			0x0D:
				result += "\\r"
			0x22:
				result += "\\\""
			0x5C:
				result += "\\\\"
			_:
				if codepoint < 0x20:
					result += "\\u%04x" % codepoint
				else:
					result += String.chr(codepoint)
	result += "\""
	return _success(result)


static func _serialize_float(value: float) -> String:
	if value == 0.0:
		return "0"
	var negative := value < 0.0
	var absolute := absf(value)
	var compact_candidate := _normalize_decimal_text(JSON.stringify(absolute, "", false, false))
	var source := JSON.stringify(absolute, "", false, true).to_lower()
	var normalized_source := _decimal_components(source)
	var coefficient := int(normalized_source.get("coefficient", 0))
	var scale := int(normalized_source.get("scale", 0))
	var source_length := str(normalized_source.get("digits", "")).length()
	var selected := _render_decimal(coefficient, scale)
	if compact_candidate == selected and _decimal_round_trips(compact_candidate, absolute):
		return ("-" if negative else "") + selected
	for significant_digits in range(1, source_length + 1):
		var removed_digits := source_length - significant_digits
		var divisor := _pow10_int(removed_digits)
		var quotient := coefficient / divisor
		var remainder := coefficient % divisor
		if remainder * 2 > divisor or (remainder * 2 == divisor and quotient % 2 != 0):
			quotient += 1
		var candidate := _render_decimal(quotient, scale + removed_digits)
		if _decimal_round_trips(candidate, absolute):
			selected = candidate
			break
	return ("-" if negative else "") + selected


static func _normalize_decimal_text(source: String) -> String:
	var components := _decimal_components(source.to_lower())
	return _render_decimal(int(components.get("coefficient", 0)), int(components.get("scale", 0)))


static func _decimal_components(source: String) -> Dictionary:
	var exponent := 0
	var exponent_index := source.find("e")
	if exponent_index >= 0:
		exponent = source.substr(exponent_index + 1).to_int()
		source = source.substr(0, exponent_index)
	var fraction_length := 0
	var point_index := source.find(".")
	if point_index >= 0:
		fraction_length = source.length() - point_index - 1
		source = source.erase(point_index, 1)
	while source.length() > 1 and source.begins_with("0"):
		source = source.substr(1)
	var scale := exponent - fraction_length
	while source.length() > 1 and source.ends_with("0"):
		source = source.left(source.length() - 1)
		scale += 1
	return {"coefficient": source.to_int(), "scale": scale, "digits": source}


static func _decimal_round_trips(candidate: String, expected: float) -> bool:
	var parsed: Variant = JSON.parse_string(candidate)
	if typeof(parsed) == TYPE_INT:
		return float(parsed) == expected
	return typeof(parsed) == TYPE_FLOAT and float(parsed) == expected


static func _render_decimal(coefficient: int, scale: int) -> String:
	if coefficient == 0:
		return "0"
	var digits := str(coefficient)
	while digits.length() > 1 and digits.ends_with("0"):
		digits = digits.left(digits.length() - 1)
		scale += 1
	var scientific_exponent := digits.length() - 1 + scale
	if scientific_exponent >= 21 or scientific_exponent <= -7:
		var mantissa := digits.left(1)
		if digits.length() > 1:
			mantissa += "." + digits.substr(1)
		var exponent_text := "+%d" % scientific_exponent if scientific_exponent >= 0 else str(scientific_exponent)
		return mantissa + "e" + exponent_text

	var point_position := digits.length() + scale
	if point_position <= 0:
		return "0." + "0".repeat(-point_position) + digits
	if point_position >= digits.length():
		return digits + "0".repeat(point_position - digits.length())
	return digits.left(point_position) + "." + digits.substr(point_position)


static func _pow10_int(exponent: int) -> int:
	var result := 1
	for _index in exponent:
		result *= 10
	return result


static func _utf16_less(left_value: Variant, right_value: Variant) -> bool:
	var left := _utf16_units(str(left_value))
	var right := _utf16_units(str(right_value))
	var shared_length := mini(left.size(), right.size())
	for index in shared_length:
		if left[index] != right[index]:
			return left[index] < right[index]
	return left.size() < right.size()


static func _utf16_units(value: String) -> PackedInt32Array:
	var result := PackedInt32Array()
	for index in value.length():
		var codepoint := value.unicode_at(index)
		if codepoint <= 0xFFFF:
			result.append(codepoint)
		else:
			var scalar := codepoint - 0x10000
			result.append(0xD800 + (scalar >> 10))
			result.append(0xDC00 + (scalar & 0x3FF))
	return result


static func _canonicalize_json_text(text: String, limits: Dictionary) -> Dictionary:
	var state := {"index": 0, "nodes": 0}
	_skip_json_whitespace(text, state)
	var result := _parse_canonical_json_value(text, state, limits, 0)
	if not bool(result.get("ok", false)):
		return result
	_skip_json_whitespace(text, state)
	if int(state.get("index", 0)) != text.length():
		return _error("invalid_json")
	var canonical_text := str(result.get("text", ""))
	var canonical_bytes := canonical_text.to_utf8_buffer()
	if canonical_bytes.size() > int(limits.get("max_output_bytes", MAX_OUTPUT_BYTES)):
		return _error("output_size_limit")
	return {
		"ok": true,
		"error_code": "",
		"text": canonical_text,
		"bytes": canonical_bytes,
	}


static func _canonicalize_artifact_json_text(text: String, limits: Dictionary) -> Dictionary:
	var state := {"index": 0, "nodes": 0}
	_skip_json_whitespace(text, state)
	var result := _parse_artifact_json_value(text, state, limits, 0)
	if not bool(result.get("ok", false)):
		return result
	_skip_json_whitespace(text, state)
	if int(state.get("index", 0)) != text.length():
		return _error("invalid_json")
	var canonical_text := str(result.get("text", ""))
	var canonical_bytes := canonical_text.to_utf8_buffer()
	if canonical_bytes.size() > int(limits.get("max_output_bytes", MAX_OUTPUT_BYTES)):
		return _error("output_size_limit")
	return {
		"ok": true,
		"error_code": "",
		"text": canonical_text,
		"bytes": canonical_bytes,
	}


static func _parse_artifact_json_value(
	text: String,
	state: Dictionary,
	limits: Dictionary,
	depth: int,
) -> Dictionary:
	if depth > int(limits.get("max_depth", MAX_DEPTH)):
		return _error("depth_limit")
	state["nodes"] = int(state.get("nodes", 0)) + 1
	if int(state.get("nodes", 0)) > int(limits.get("max_nodes", MAX_NODES)):
		return _error("node_limit")
	_skip_json_whitespace(text, state)
	var index := int(state.get("index", 0))
	if index >= text.length():
		return _error("invalid_json")
	var character := text.substr(index, 1)
	match character:
		"\"":
			return _parse_canonical_json_string(text, state, limits)
		"{":
			return _parse_artifact_json_object(text, state, limits, depth)
		"[":
			return _parse_artifact_json_array(text, state, limits, depth)
		"t":
			var true_result := _scan_json_literal(text, state, "true")
			return _canonical_fragment("true", limits) if bool(true_result.get("ok", false)) else true_result
		"f":
			var false_result := _scan_json_literal(text, state, "false")
			return _canonical_fragment("false", limits) if bool(false_result.get("ok", false)) else false_result
		"n":
			var null_result := _scan_json_literal(text, state, "null")
			return _canonical_fragment("null", limits) if bool(null_result.get("ok", false)) else null_result
		_:
			if character == "-" or _is_ascii_digit(character):
				return _parse_artifact_json_integer(text, state, limits)
	return _error("invalid_json")


static func _parse_artifact_json_object(
	text: String,
	state: Dictionary,
	limits: Dictionary,
	depth: int,
) -> Dictionary:
	state["index"] = int(state.get("index", 0)) + 1
	_skip_json_whitespace(text, state)
	if _consume_json_character(text, state, "}"):
		return _canonical_fragment("{}", limits)
	var seen: Dictionary = {}
	var entries: Array = []
	while true:
		var key_result := _parse_canonical_json_string(text, state, limits)
		if not bool(key_result.get("ok", false)):
			return key_result
		var signature := str(key_result.get("signature", ""))
		if seen.has(signature):
			return _error("duplicate_key")
		seen[signature] = true
		_skip_json_whitespace(text, state)
		if not _consume_json_character(text, state, ":"):
			return _error("invalid_json")
		var value_result := _parse_artifact_json_value(text, state, limits, depth + 1)
		if not bool(value_result.get("ok", false)):
			return value_result
		entries.append({
			"key_text": str(key_result.get("text", "")),
			"key_codepoints": key_result.get("codepoints", []),
			"value_text": str(value_result.get("text", "")),
		})
		_skip_json_whitespace(text, state)
		if _consume_json_character(text, state, "}"):
			break
		if not _consume_json_character(text, state, ","):
			return _error("invalid_json")
		_skip_json_whitespace(text, state)
	entries.sort_custom(_artifact_json_entry_less)
	var parts := PackedStringArray()
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		parts.append(str(entry.get("key_text", "")) + ":" + str(entry.get("value_text", "")))
	return _canonical_fragment("{" + ",".join(parts) + "}", limits)


static func _parse_artifact_json_array(
	text: String,
	state: Dictionary,
	limits: Dictionary,
	depth: int,
) -> Dictionary:
	state["index"] = int(state.get("index", 0)) + 1
	_skip_json_whitespace(text, state)
	if _consume_json_character(text, state, "]"):
		return _canonical_fragment("[]", limits)
	var parts := PackedStringArray()
	while true:
		var child_result := _parse_artifact_json_value(text, state, limits, depth + 1)
		if not bool(child_result.get("ok", false)):
			return child_result
		parts.append(str(child_result.get("text", "")))
		_skip_json_whitespace(text, state)
		if _consume_json_character(text, state, "]"):
			break
		if not _consume_json_character(text, state, ","):
			return _error("invalid_json")
		_skip_json_whitespace(text, state)
	return _canonical_fragment("[" + ",".join(parts) + "]", limits)


static func _parse_artifact_json_integer(
	text: String,
	state: Dictionary,
	limits: Dictionary,
) -> Dictionary:
	var start := int(state.get("index", 0))
	var index := start
	if index < text.length() and text.substr(index, 1) == "-":
		index += 1
	if index >= text.length():
		return _error("invalid_json")
	if text.substr(index, 1) == "0":
		index += 1
		if index < text.length() and _is_ascii_digit(text.substr(index, 1)):
			return _error("invalid_json")
	elif _is_nonzero_ascii_digit(text.substr(index, 1)):
		while index < text.length() and _is_ascii_digit(text.substr(index, 1)):
			index += 1
	else:
		return _error("invalid_json")
	if index < text.length() and text.substr(index, 1).to_lower() in [".", "e"]:
		return _error("artifact_float_forbidden")
	var token := text.substr(start, index - start)
	if not _integer_token_is_safe(token):
		return _error("unsafe_integer")
	state["index"] = index
	return _canonical_fragment("0" if token == "-0" else token, limits)


static func _parse_canonical_json_value(
	text: String,
	state: Dictionary,
	limits: Dictionary,
	depth: int,
) -> Dictionary:
	if depth > int(limits.get("max_depth", MAX_DEPTH)):
		return _error("depth_limit")
	state["nodes"] = int(state.get("nodes", 0)) + 1
	if int(state.get("nodes", 0)) > int(limits.get("max_nodes", MAX_NODES)):
		return _error("node_limit")
	_skip_json_whitespace(text, state)
	var index := int(state.get("index", 0))
	if index >= text.length():
		return _error("invalid_json")
	var character := text.substr(index, 1)
	match character:
		"\"":
			return _parse_canonical_json_string(text, state, limits)
		"{":
			return _parse_canonical_json_object(text, state, limits, depth)
		"[":
			return _parse_canonical_json_array(text, state, limits, depth)
		"t":
			var true_result := _scan_json_literal(text, state, "true")
			return _canonical_fragment("true", limits) if bool(true_result.get("ok", false)) else true_result
		"f":
			var false_result := _scan_json_literal(text, state, "false")
			return _canonical_fragment("false", limits) if bool(false_result.get("ok", false)) else false_result
		"n":
			var null_result := _scan_json_literal(text, state, "null")
			return _canonical_fragment("null", limits) if bool(null_result.get("ok", false)) else null_result
		_:
			if character == "-" or _is_ascii_digit(character):
				return _parse_canonical_json_number(text, state, limits)
	return _error("invalid_json")


static func _parse_canonical_json_object(
	text: String,
	state: Dictionary,
	limits: Dictionary,
	depth: int,
) -> Dictionary:
	state["index"] = int(state.get("index", 0)) + 1
	_skip_json_whitespace(text, state)
	if _consume_json_character(text, state, "}"):
		return _canonical_fragment("{}", limits)
	var seen: Dictionary = {}
	var entries: Array = []
	while true:
		var key_result := _parse_canonical_json_string(text, state, limits)
		if not bool(key_result.get("ok", false)):
			return key_result
		var signature := str(key_result.get("signature", ""))
		if seen.has(signature):
			return _error("duplicate_key")
		seen[signature] = true
		_skip_json_whitespace(text, state)
		if not _consume_json_character(text, state, ":"):
			return _error("invalid_json")
		var value_result := _parse_canonical_json_value(text, state, limits, depth + 1)
		if not bool(value_result.get("ok", false)):
			return value_result
		entries.append({
			"key_text": str(key_result.get("text", "")),
			"key_units": key_result.get("utf16_units", PackedInt32Array()),
			"value_text": str(value_result.get("text", "")),
		})
		_skip_json_whitespace(text, state)
		if _consume_json_character(text, state, "}"):
			break
		if not _consume_json_character(text, state, ","):
			return _error("invalid_json")
		_skip_json_whitespace(text, state)
	entries.sort_custom(_canonical_json_entry_less)
	var parts := PackedStringArray()
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		parts.append(str(entry.get("key_text", "")) + ":" + str(entry.get("value_text", "")))
	return _canonical_fragment("{" + ",".join(parts) + "}", limits)


static func _parse_canonical_json_array(
	text: String,
	state: Dictionary,
	limits: Dictionary,
	depth: int,
) -> Dictionary:
	state["index"] = int(state.get("index", 0)) + 1
	_skip_json_whitespace(text, state)
	if _consume_json_character(text, state, "]"):
		return _canonical_fragment("[]", limits)
	var parts := PackedStringArray()
	while true:
		var child_result := _parse_canonical_json_value(text, state, limits, depth + 1)
		if not bool(child_result.get("ok", false)):
			return child_result
		parts.append(str(child_result.get("text", "")))
		_skip_json_whitespace(text, state)
		if _consume_json_character(text, state, "]"):
			break
		if not _consume_json_character(text, state, ","):
			return _error("invalid_json")
		_skip_json_whitespace(text, state)
	return _canonical_fragment("[" + ",".join(parts) + "]", limits)


static func _parse_canonical_json_string(
	text: String,
	state: Dictionary,
	limits: Dictionary,
) -> Dictionary:
	var parsed := _parse_json_string_codepoints(text, state)
	if not bool(parsed.get("ok", false)):
		return parsed
	var codepoints: Array = parsed.get("codepoints", [])
	var serialized := _serialize_codepoints(codepoints)
	if not bool(serialized.get("ok", false)):
		return serialized
	var fragment := _canonical_fragment(str(serialized.get("text", "")), limits)
	if not bool(fragment.get("ok", false)):
		return fragment
	fragment["signature"] = str(parsed.get("signature", ""))
	fragment["utf16_units"] = _utf16_units_from_codepoints(codepoints)
	fragment["codepoints"] = codepoints
	return fragment


static func _parse_json_string_codepoints(text: String, state: Dictionary) -> Dictionary:
	var index := int(state.get("index", 0))
	if index >= text.length() or text.substr(index, 1) != "\"":
		return _error("invalid_json")
	index += 1
	var codepoints: Array = []
	var signature := ""
	while index < text.length():
		var codepoint := text.unicode_at(index)
		if codepoint == 0x22:
			state["index"] = index + 1
			return {
				"ok": true,
				"error_code": "",
				"codepoints": codepoints,
				"signature": signature,
			}
		if codepoint < 0x20:
			return _error("invalid_json")
		if codepoint != 0x5C:
			if _is_invalid_unicode_scalar(codepoint):
				return _error("invalid_unicode")
			codepoints.append(codepoint)
			signature += "%x;" % codepoint
			index += 1
			continue
		index += 1
		if index >= text.length():
			return _error("invalid_json")
		var escape := text.substr(index, 1)
		index += 1
		var escaped_codepoint := -1
		match escape:
			"\"", "\\", "/":
				escaped_codepoint = escape.unicode_at(0)
			"b":
				escaped_codepoint = 0x08
			"f":
				escaped_codepoint = 0x0C
			"n":
				escaped_codepoint = 0x0A
			"r":
				escaped_codepoint = 0x0D
			"t":
				escaped_codepoint = 0x09
			"u":
				var hex_result := _scan_hex_quad(text, index)
				if not bool(hex_result.get("ok", false)):
					return _error("invalid_json")
				escaped_codepoint = int(hex_result.get("value", -1))
				index += 4
				if escaped_codepoint >= 0xD800 and escaped_codepoint <= 0xDBFF:
					if index + 6 > text.length() or text.substr(index, 2) != "\\u":
						return _error("invalid_unicode")
					var low_result := _scan_hex_quad(text, index + 2)
					if not bool(low_result.get("ok", false)):
						return _error("invalid_unicode")
					var low := int(low_result.get("value", -1))
					if low < 0xDC00 or low > 0xDFFF:
						return _error("invalid_unicode")
					escaped_codepoint = 0x10000 + ((escaped_codepoint - 0xD800) << 10) + (low - 0xDC00)
					index += 6
				elif escaped_codepoint >= 0xDC00 and escaped_codepoint <= 0xDFFF:
					return _error("invalid_unicode")
			_:
				return _error("invalid_json")
		if _is_invalid_unicode_scalar(escaped_codepoint):
			return _error("invalid_unicode")
		codepoints.append(escaped_codepoint)
		signature += "%x;" % escaped_codepoint
	return _error("invalid_json")


static func _parse_canonical_json_number(
	text: String,
	state: Dictionary,
	limits: Dictionary,
) -> Dictionary:
	var scanned := _scan_json_number(text, state)
	if not bool(scanned.get("ok", false)):
		return scanned
	var token := str(scanned.get("token", ""))
	if not token.contains(".") and not token.to_lower().contains("e"):
		return _canonical_fragment(str(token.to_int()), limits)
	var converted := _decimal_token_to_binary64(token)
	if not bool(converted.get("ok", false)):
		return converted
	return _canonical_fragment(_serialize_float(float(converted.get("value", 0.0))), limits)


static func _decimal_token_to_binary64(token: String) -> Dictionary:
	var negative := token.begins_with("-")
	var unsigned := token.substr(1) if negative else token
	var exponent_value := 0
	var exponent_index := unsigned.to_lower().find("e")
	if exponent_index >= 0:
		var exponent_text := unsigned.substr(exponent_index + 1)
		unsigned = unsigned.substr(0, exponent_index)
		var exponent_negative := exponent_text.begins_with("-")
		if exponent_text.begins_with("+") or exponent_negative:
			exponent_text = exponent_text.substr(1)
		var trimmed_exponent := _strip_leading_zeroes(exponent_text)
		if trimmed_exponent.is_empty():
			trimmed_exponent = "0"
		if trimmed_exponent.length() > 6:
			exponent_value = -1_000_000 if exponent_negative else 1_000_000
		else:
			exponent_value = trimmed_exponent.to_int()
			if exponent_negative:
				exponent_value = -exponent_value
	var point_index := unsigned.find(".")
	var fraction_length := 0
	if point_index >= 0:
		fraction_length = unsigned.length() - point_index - 1
		unsigned = unsigned.erase(point_index, 1)
	var digits := _strip_leading_zeroes(unsigned)
	if digits.is_empty():
		return {"ok": true, "error_code": "", "value": -0.0 if negative else 0.0}
	if digits.length() > 4096:
		return _error("numeric_token_limit")
	var decimal_exponent := exponent_value - fraction_length
	var scientific_exponent := decimal_exponent + digits.length() - 1
	if scientific_exponent > 309:
		return _error("non_finite_number")
	if scientific_exponent < -400:
		return {"ok": true, "error_code": "", "value": -0.0 if negative else 0.0}
	var parsed: Variant = JSON.parse_string(token)
	if typeof(parsed) != TYPE_FLOAT and typeof(parsed) != TYPE_INT:
		return _error("invalid_json")
	var candidate := absf(float(parsed))
	if not is_finite(candidate):
		return _error("non_finite_number")
	var coefficient := _big_from_decimal_digits(digits)
	var bits := _positive_float_bits(candidate)
	for _step in 16:
		var lower_ok := true
		var upper_ok := true
		var even := (bits & 1) == 0
		if bits > 0:
			var lower := _midpoint_components(bits - 1, bits)
			var lower_comparison := _compare_decimal_to_binary(
				coefficient,
				decimal_exponent,
				int(lower.get("significand", 0)),
				int(lower.get("exponent", 0)),
			)
			lower_ok = lower_comparison > 0 or (lower_comparison == 0 and even)
		var upper := _midpoint_components(bits, bits + 1)
		var upper_comparison := _compare_decimal_to_binary(
			coefficient,
			decimal_exponent,
			int(upper.get("significand", 0)),
			int(upper.get("exponent", 0)),
		)
		upper_ok = upper_comparison < 0 or (upper_comparison == 0 and even)
		if lower_ok and upper_ok:
			var corrected := _positive_float_from_bits(bits)
			return {
				"ok": true,
				"error_code": "",
				"value": -corrected if negative else corrected,
			}
		if not lower_ok:
			if bits == 0:
				break
			bits -= 1
		else:
			bits += 1
			if (bits >> 52) >= 0x7FF:
				return _error("non_finite_number")
	return _error("decimal_conversion_failed")


static func _positive_float_bits(value: float) -> int:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.decode_u64(0)


static func _positive_float_from_bits(bits: int) -> float:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_u64(0, bits)
	return bytes.decode_double(0)


static func _binary64_components(bits: int) -> Dictionary:
	var exponent_bits := (bits >> 52) & 0x7FF
	var fraction := bits & 0x000FFFFFFFFFFFFF
	if exponent_bits == 0:
		return {"significand": fraction, "exponent": -1074}
	if exponent_bits == 0x7FF:
		return {"significand": 1 << 52, "exponent": 972}
	return {
		"significand": (1 << 52) + fraction,
		"exponent": exponent_bits - 1023 - 52,
	}


static func _midpoint_components(left_bits: int, right_bits: int) -> Dictionary:
	var left := _binary64_components(left_bits)
	var right := _binary64_components(right_bits)
	var common_exponent := mini(int(left.get("exponent", 0)), int(right.get("exponent", 0)))
	var left_significand := int(left.get("significand", 0)) << (
		int(left.get("exponent", 0)) - common_exponent
	)
	var right_significand := int(right.get("significand", 0)) << (
		int(right.get("exponent", 0)) - common_exponent
	)
	return {
		"significand": left_significand + right_significand,
		"exponent": common_exponent - 1,
	}


static func _compare_decimal_to_binary(
	decimal_coefficient: Array,
	decimal_exponent: int,
	binary_significand: int,
	binary_exponent: int,
) -> int:
	var left: Array = decimal_coefficient.duplicate()
	var right := _big_from_int(binary_significand)
	if decimal_exponent >= 0:
		for _index in decimal_exponent:
			_big_multiply_small(left, 10)
	else:
		for _index in -decimal_exponent:
			_big_multiply_small(right, 10)
	if binary_exponent >= 0:
		for _index in binary_exponent:
			_big_multiply_small(right, 2)
	else:
		for _index in -binary_exponent:
			_big_multiply_small(left, 2)
	return _big_compare(left, right)


static func _big_from_decimal_digits(digits: String) -> Array:
	var result: Array = [0]
	for index in digits.length():
		_big_multiply_small(result, 10)
		_big_add_small(result, digits.unicode_at(index) - 0x30)
	return result


static func _big_from_int(value: int) -> Array:
	const BASE := 1_000_000_000
	if value == 0:
		return [0]
	var result: Array = []
	var remaining := value
	while remaining > 0:
		result.append(remaining % BASE)
		remaining = int(remaining / BASE)
	return result


static func _big_multiply_small(value: Array, factor: int) -> void:
	const BASE := 1_000_000_000
	var carry := 0
	for index in value.size():
		var product := int(value[index]) * factor + carry
		value[index] = product % BASE
		carry = product / BASE
	while carry > 0:
		value.append(carry % BASE)
		carry = int(carry / BASE)


static func _big_add_small(value: Array, addend: int) -> void:
	const BASE := 1_000_000_000
	var carry := addend
	var index := 0
	while carry > 0:
		if index >= value.size():
			value.append(0)
		var total := int(value[index]) + carry
		value[index] = total % BASE
		carry = int(total / BASE)
		index += 1


static func _big_compare(left: Array, right: Array) -> int:
	while left.size() > 1 and int(left[-1]) == 0:
		left.pop_back()
	while right.size() > 1 and int(right[-1]) == 0:
		right.pop_back()
	if left.size() != right.size():
		return -1 if left.size() < right.size() else 1
	for offset in left.size():
		var index := left.size() - 1 - offset
		if int(left[index]) != int(right[index]):
			return -1 if int(left[index]) < int(right[index]) else 1
	return 0


static func _strip_leading_zeroes(value: String) -> String:
	var index := 0
	while index < value.length() and value.substr(index, 1) == "0":
		index += 1
	return value.substr(index)


static func _canonical_fragment(text: String, limits: Dictionary) -> Dictionary:
	if text.to_utf8_buffer().size() > int(limits.get("max_output_bytes", MAX_OUTPUT_BYTES)):
		return _error("output_size_limit")
	return {"ok": true, "error_code": "", "text": text}


static func _utf16_units_from_codepoints(codepoints: Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	for codepoint_value: Variant in codepoints:
		var codepoint := int(codepoint_value)
		if codepoint <= 0xFFFF:
			result.append(codepoint)
		else:
			var scalar := codepoint - 0x10000
			result.append(0xD800 + (scalar >> 10))
			result.append(0xDC00 + (scalar & 0x3FF))
	return result


static func _canonical_json_entry_less(left_value: Variant, right_value: Variant) -> bool:
	var left: PackedInt32Array = left_value.get("key_units", PackedInt32Array())
	var right: PackedInt32Array = right_value.get("key_units", PackedInt32Array())
	var shared_length := mini(left.size(), right.size())
	for index in shared_length:
		if left[index] != right[index]:
			return left[index] < right[index]
	return left.size() < right.size()


static func _artifact_json_entry_less(left_value: Variant, right_value: Variant) -> bool:
	var left: Array = left_value.get("key_codepoints", [])
	var right: Array = right_value.get("key_codepoints", [])
	var shared_length := mini(left.size(), right.size())
	for index in shared_length:
		if int(left[index]) != int(right[index]):
			return int(left[index]) < int(right[index])
	return left.size() < right.size()


static func _strict_json_preflight(text: String, limits: Dictionary) -> Dictionary:
	var state := {"index": 0, "nodes": 0}
	_skip_json_whitespace(text, state)
	var result := _scan_json_value(text, state, limits, 0)
	if not bool(result.get("ok", false)):
		return result
	_skip_json_whitespace(text, state)
	if int(state.get("index", 0)) != text.length():
		return _error("invalid_json")
	return {"ok": true, "error_code": ""}


static func _scan_json_value(
	text: String,
	state: Dictionary,
	limits: Dictionary,
	depth: int,
) -> Dictionary:
	if depth > int(limits.get("max_depth", MAX_DEPTH)):
		return _error("depth_limit")
	state["nodes"] = int(state.get("nodes", 0)) + 1
	if int(state.get("nodes", 0)) > int(limits.get("max_nodes", MAX_NODES)):
		return _error("node_limit")
	_skip_json_whitespace(text, state)
	var index := int(state.get("index", 0))
	if index >= text.length():
		return _error("invalid_json")
	var character := text.substr(index, 1)
	match character:
		"\"":
			return _scan_json_string(text, state)
		"{":
			return _scan_json_object(text, state, limits, depth)
		"[":
			return _scan_json_array(text, state, limits, depth)
		"t":
			return _scan_json_literal(text, state, "true")
		"f":
			return _scan_json_literal(text, state, "false")
		"n":
			return _scan_json_literal(text, state, "null")
		_:
			if character == "-" or _is_ascii_digit(character):
				return _scan_json_number(text, state)
	return _error("invalid_json")


static func _scan_json_object(
	text: String,
	state: Dictionary,
	limits: Dictionary,
	depth: int,
) -> Dictionary:
	state["index"] = int(state.get("index", 0)) + 1
	_skip_json_whitespace(text, state)
	if _consume_json_character(text, state, "}"):
		return {"ok": true, "error_code": ""}
	var seen: Dictionary = {}
	while true:
		var index := int(state.get("index", 0))
		if index >= text.length() or text.substr(index, 1) != "\"":
			return _error("invalid_json")
		var key_result := _scan_json_string(text, state)
		if not bool(key_result.get("ok", false)):
			return key_result
		var signature := str(key_result.get("signature", ""))
		if seen.has(signature):
			return _error("duplicate_key")
		seen[signature] = true
		_skip_json_whitespace(text, state)
		if not _consume_json_character(text, state, ":"):
			return _error("invalid_json")
		var child_result := _scan_json_value(text, state, limits, depth + 1)
		if not bool(child_result.get("ok", false)):
			return child_result
		_skip_json_whitespace(text, state)
		if _consume_json_character(text, state, "}"):
			return {"ok": true, "error_code": ""}
		if not _consume_json_character(text, state, ","):
			return _error("invalid_json")
		_skip_json_whitespace(text, state)
	return _error("invalid_json")


static func _scan_json_array(
	text: String,
	state: Dictionary,
	limits: Dictionary,
	depth: int,
) -> Dictionary:
	state["index"] = int(state.get("index", 0)) + 1
	_skip_json_whitespace(text, state)
	if _consume_json_character(text, state, "]"):
		return {"ok": true, "error_code": ""}
	while true:
		var child_result := _scan_json_value(text, state, limits, depth + 1)
		if not bool(child_result.get("ok", false)):
			return child_result
		_skip_json_whitespace(text, state)
		if _consume_json_character(text, state, "]"):
			return {"ok": true, "error_code": ""}
		if not _consume_json_character(text, state, ","):
			return _error("invalid_json")
		_skip_json_whitespace(text, state)
	return _error("invalid_json")


static func _scan_json_string(text: String, state: Dictionary) -> Dictionary:
	var index := int(state.get("index", 0))
	if index >= text.length() or text.substr(index, 1) != "\"":
		return _error("invalid_json")
	index += 1
	var signature := ""
	while index < text.length():
		var codepoint := text.unicode_at(index)
		if codepoint == 0x22:
			state["index"] = index + 1
			return {"ok": true, "error_code": "", "signature": signature}
		if codepoint < 0x20:
			return _error("invalid_json")
		if codepoint != 0x5C:
			if _is_invalid_unicode_scalar(codepoint):
				return _error("invalid_unicode")
			signature += "%x;" % codepoint
			index += 1
			continue
		index += 1
		if index >= text.length():
			return _error("invalid_json")
		var escape := text.substr(index, 1)
		index += 1
		var escaped_codepoint := -1
		match escape:
			"\"", "\\", "/":
				escaped_codepoint = escape.unicode_at(0)
			"b":
				escaped_codepoint = 0x08
			"f":
				escaped_codepoint = 0x0C
			"n":
				escaped_codepoint = 0x0A
			"r":
				escaped_codepoint = 0x0D
			"t":
				escaped_codepoint = 0x09
			"u":
				var hex_result := _scan_hex_quad(text, index)
				if not bool(hex_result.get("ok", false)):
					return _error("invalid_json")
				escaped_codepoint = int(hex_result.get("value", -1))
				index += 4
				if escaped_codepoint >= 0xD800 and escaped_codepoint <= 0xDBFF:
					if index + 6 > text.length() or text.substr(index, 2) != "\\u":
						return _error("invalid_unicode")
					var low_result := _scan_hex_quad(text, index + 2)
					if not bool(low_result.get("ok", false)):
						return _error("invalid_unicode")
					var low := int(low_result.get("value", -1))
					if low < 0xDC00 or low > 0xDFFF:
						return _error("invalid_unicode")
					escaped_codepoint = 0x10000 + ((escaped_codepoint - 0xD800) << 10) + (low - 0xDC00)
					index += 6
				elif escaped_codepoint >= 0xDC00 and escaped_codepoint <= 0xDFFF:
					return _error("invalid_unicode")
			_:
				return _error("invalid_json")
		if escaped_codepoint == 0:
			return _error("unsupported_unicode_nul")
		if _is_invalid_unicode_scalar(escaped_codepoint):
			return _error("invalid_unicode")
		signature += "%x;" % escaped_codepoint
	return _error("invalid_json")


static func _scan_hex_quad(text: String, start: int) -> Dictionary:
	if start + 4 > text.length():
		return _error("invalid_json")
	var value := 0
	for offset in 4:
		var codepoint := text.unicode_at(start + offset)
		var digit := -1
		if codepoint >= 0x30 and codepoint <= 0x39:
			digit = codepoint - 0x30
		elif codepoint >= 0x41 and codepoint <= 0x46:
			digit = codepoint - 0x41 + 10
		elif codepoint >= 0x61 and codepoint <= 0x66:
			digit = codepoint - 0x61 + 10
		if digit < 0:
			return _error("invalid_json")
		value = value * 16 + digit
	return {"ok": true, "error_code": "", "value": value}


static func _scan_json_literal(text: String, state: Dictionary, literal: String) -> Dictionary:
	var index := int(state.get("index", 0))
	if text.substr(index, literal.length()) != literal:
		return _error("invalid_json")
	state["index"] = index + literal.length()
	return {"ok": true, "error_code": ""}


static func _scan_json_number(text: String, state: Dictionary) -> Dictionary:
	var start := int(state.get("index", 0))
	var index := start
	if index < text.length() and text.substr(index, 1) == "-":
		index += 1
	if index >= text.length():
		return _error("invalid_json")
	if text.substr(index, 1) == "0":
		index += 1
		if index < text.length() and _is_ascii_digit(text.substr(index, 1)):
			return _error("invalid_json")
	elif _is_nonzero_ascii_digit(text.substr(index, 1)):
		while index < text.length() and _is_ascii_digit(text.substr(index, 1)):
			index += 1
	else:
		return _error("invalid_json")
	var integer_only := true
	if index < text.length() and text.substr(index, 1) == ".":
		integer_only = false
		index += 1
		var fraction_start := index
		while index < text.length() and _is_ascii_digit(text.substr(index, 1)):
			index += 1
		if index == fraction_start:
			return _error("invalid_json")
	if index < text.length() and text.substr(index, 1).to_lower() == "e":
		integer_only = false
		index += 1
		if index < text.length() and text.substr(index, 1) in ["+", "-"]:
			index += 1
		var exponent_start := index
		while index < text.length() and _is_ascii_digit(text.substr(index, 1)):
			index += 1
		if index == exponent_start:
			return _error("invalid_json")
	var token := text.substr(start, index - start)
	if integer_only and not _integer_token_is_safe(token):
		return _error("unsafe_integer")
	state["index"] = index
	return {"ok": true, "error_code": "", "token": token}


static func _integer_token_is_safe(token: String) -> bool:
	var digits := token.substr(1) if token.begins_with("-") else token
	while digits.length() > 1 and digits.begins_with("0"):
		digits = digits.substr(1)
	var maximum := "9007199254740991"
	if digits.length() != maximum.length():
		return digits.length() < maximum.length()
	return digits <= maximum


static func _skip_json_whitespace(text: String, state: Dictionary) -> void:
	var index := int(state.get("index", 0))
	while index < text.length() and text.unicode_at(index) in [0x20, 0x09, 0x0A, 0x0D]:
		index += 1
	state["index"] = index


static func _consume_json_character(text: String, state: Dictionary, expected: String) -> bool:
	var index := int(state.get("index", 0))
	if index >= text.length() or text.substr(index, 1) != expected:
		return false
	state["index"] = index + 1
	return true


static func _is_ascii_digit(character: String) -> bool:
	return character.length() == 1 and character >= "0" and character <= "9"


static func _is_nonzero_ascii_digit(character: String) -> bool:
	return character.length() == 1 and character >= "1" and character <= "9"


static func _resolve_limits(overrides: Dictionary) -> Dictionary:
	var limits: Dictionary = DEFAULT_LIMITS.duplicate(true)
	for key_value: Variant in overrides.keys():
		var key := str(key_value)
		if not limits.has(key):
			return _error("invalid_limits")
		var raw_value: Variant = overrides[key_value]
		if typeof(raw_value) != TYPE_INT and typeof(raw_value) != TYPE_FLOAT:
			return _error("invalid_limits")
		if typeof(raw_value) == TYPE_FLOAT and (
			not is_finite(float(raw_value))
			or float(raw_value) != floorf(float(raw_value))
		):
			return _error("invalid_limits")
		limits[key] = int(raw_value)
	var maxima := {
		"max_input_bytes": MAX_INPUT_BYTES,
		"max_depth": MAX_DEPTH,
		"max_nodes": MAX_NODES,
		"max_output_bytes": MAX_OUTPUT_BYTES,
	}
	for key: String in maxima:
		var minimum := 0 if key == "max_depth" else 1
		var value := int(limits.get(key, -1))
		if value < minimum or value > int(maxima[key]):
			return _error("invalid_limits")
	return {"ok": true, "error_code": "", "limits": limits}


static func _validate_tree(root: Variant, limits: Dictionary) -> Dictionary:
	var frames: Array = [{"exiting": false, "value": root, "depth": 0}]
	var active: Array = []
	var nodes := 0
	var output_bytes := 0
	while not frames.is_empty():
		var frame: Dictionary = frames.pop_back()
		var current: Variant = frame.get("value")
		if bool(frame.get("exiting", false)):
			_remove_same(active, current)
			continue
		nodes += 1
		if nodes > int(limits.get("max_nodes", MAX_NODES)):
			return _error("node_limit")
		var depth := int(frame.get("depth", 0))
		if depth > int(limits.get("max_depth", MAX_DEPTH)):
			return _error("depth_limit")
		match typeof(current):
			TYPE_NIL:
				output_bytes += 4
			TYPE_BOOL:
				output_bytes += 4 if bool(current) else 5
			TYPE_INT:
				var integer_value := int(current)
				if integer_value < -MAX_SAFE_INTEGER or integer_value > MAX_SAFE_INTEGER:
					return _error("unsafe_integer")
				output_bytes += str(integer_value).length()
			TYPE_FLOAT:
				if not is_finite(float(current)):
					return _error("non_finite_number")
				output_bytes += _serialize_float(float(current)).length()
			TYPE_STRING:
				var string_size := _canonical_string_byte_length(str(current))
				if not bool(string_size.get("ok", false)):
					return string_size
				output_bytes += int(string_size.get("size", 0))
			TYPE_ARRAY:
				if _is_ancestor(current, active):
					return _error("cycle_detected")
				var array_value: Array = current
				output_bytes += 2 + maxi(0, array_value.size() - 1)
				active.append(current)
				frames.append({"exiting": true, "value": current, "depth": depth})
				for index in range(array_value.size() - 1, -1, -1):
					frames.append({"exiting": false, "value": array_value[index], "depth": depth + 1})
			TYPE_DICTIONARY:
				if _is_ancestor(current, active):
					return _error("cycle_detected")
				var dictionary_value: Dictionary = current
				output_bytes += 2 + maxi(0, dictionary_value.size() - 1)
				var keys := dictionary_value.keys()
				for key_value: Variant in keys:
					if typeof(key_value) != TYPE_STRING:
						return _error("non_string_key")
					var key_size := _canonical_string_byte_length(str(key_value))
					if not bool(key_size.get("ok", false)):
						return key_size
					output_bytes += int(key_size.get("size", 0)) + 1
				active.append(current)
				frames.append({"exiting": true, "value": current, "depth": depth})
				for index in range(keys.size() - 1, -1, -1):
					frames.append({
						"exiting": false,
						"value": dictionary_value[keys[index]],
						"depth": depth + 1,
					})
			_:
				return _error("unsupported_type")
		if output_bytes > int(limits.get("max_output_bytes", MAX_OUTPUT_BYTES)):
			return _error("output_size_limit")
	return {"ok": true, "error_code": ""}


static func _canonical_string_byte_length(value: String) -> Dictionary:
	var size := 2
	for index in value.length():
		var codepoint := value.unicode_at(index)
		if _is_invalid_unicode_scalar(codepoint):
			return _error("invalid_unicode")
		if codepoint == 0x22 or codepoint == 0x5C or codepoint in [0x08, 0x09, 0x0A, 0x0C, 0x0D]:
			size += 2
		elif codepoint < 0x20:
			size += 6
		elif codepoint <= 0x7F:
			size += 1
		elif codepoint <= 0x7FF:
			size += 2
		elif codepoint <= 0xFFFF:
			size += 3
		else:
			size += 4
	return {"ok": true, "error_code": "", "size": size}


static func _is_invalid_unicode_scalar(codepoint: int) -> bool:
	if codepoint < 0 or codepoint > 0x10FFFF:
		return true
	if codepoint >= 0xD800 and codepoint <= 0xDFFF:
		return true
	if codepoint >= 0xFDD0 and codepoint <= 0xFDEF:
		return true
	return (codepoint & 0xFFFF) == 0xFFFE or (codepoint & 0xFFFF) == 0xFFFF


static func _remove_same(values: Array, target: Variant) -> void:
	for index in values.size():
		if is_same(values[index], target):
			values.remove_at(index)
			return


static func _is_ancestor(value: Variant, ancestors: Array) -> bool:
	for ancestor: Variant in ancestors:
		if is_same(value, ancestor):
			return true
	return false


static func _success(text: String) -> Dictionary:
	return {"ok": true, "error_code": "", "text": text}


static func _error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code, "text": "", "bytes": PackedByteArray()}
