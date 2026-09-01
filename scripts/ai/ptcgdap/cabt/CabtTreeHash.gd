class_name CabtTreeHash
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const PROFILE_TAG := "CABT_TREE_HASH_V1"
const ALLOWED_DOMAINS := {
	"raw_private": true,
	"token_free_callback": true,
	"public_observation": true,
}
const REQUIRED_CALLBACK_FIELDS := ["select", "logs", "current", "search_begin_input"]
const SEARCH_PRESENCE_MARKER := "$ptcgdap_opaque_search_capability_present"


static func hash_tree(
	value: Variant,
	domain: String,
	limit_overrides: Dictionary = {},
) -> Dictionary:
	if not ALLOWED_DOMAINS.has(domain):
		return _error("unsupported_domain")
	var canonical_input: Variant = value
	var canonical: Dictionary = {}
	if domain == "raw_private":
		var callback_validation := _validate_callback(value, limit_overrides)
		if not bool(callback_validation.get("ok", false)):
			return callback_validation
	elif domain == "token_free_callback":
		var normalized := normalize_search_capability(value, limit_overrides)
		if not bool(normalized.get("ok", false)):
			return normalized
		canonical_input = normalized.get("value")
	else:
		canonical = CabtJsonTreeScript.canonicalize(value, limit_overrides)
		if not bool(canonical.get("ok", false)):
			return canonical
		if _contains_search_material(value):
			return _error("public_projection_forbidden_field")
	if canonical.is_empty():
		canonical = CabtJsonTreeScript.canonicalize(canonical_input, limit_overrides)
	if not bool(canonical.get("ok", false)):
		return canonical
	var prefix := PackedByteArray()
	prefix.append_array("PTCGDAP".to_utf8_buffer())
	prefix.append(0)
	prefix.append_array(PROFILE_TAG.to_utf8_buffer())
	prefix.append(0)
	prefix.append_array(domain.to_utf8_buffer())
	prefix.append(0)
	var digest_input := prefix.duplicate()
	digest_input.append_array(canonical.get("bytes", PackedByteArray()))
	var context := HashingContext.new()
	var start_error := context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return _error("sha256_unavailable")
	var update_error := context.update(digest_input)
	if update_error != OK:
		return _error("sha256_failed")
	var digest := context.finish().hex_encode().to_upper()
	return {
		"ok": true,
		"error_code": "",
		"sha256": digest,
		"canonical_text": canonical.get("text", ""),
		"canonical_bytes": canonical.get("bytes", PackedByteArray()),
	}


static func normalize_search_capability(
	raw_payload: Variant,
	limit_overrides: Dictionary = {},
) -> Dictionary:
	var validation := _validate_callback(raw_payload, limit_overrides)
	if not bool(validation.get("ok", false)):
		return validation
	var token: Variant = raw_payload.get("search_begin_input")
	var normalized: Dictionary = raw_payload.duplicate(true)
	normalized["search_begin_input"] = {
		SEARCH_PRESENCE_MARKER: token != null,
	}
	return {"ok": true, "error_code": "", "value": normalized}


static func raw_private_hash(
	raw_payload: Variant,
	limit_overrides: Dictionary = {},
) -> Dictionary:
	return hash_tree(raw_payload, "raw_private", limit_overrides)


static func token_free_callback_hash(
	raw_payload: Variant,
	limit_overrides: Dictionary = {},
) -> Dictionary:
	return hash_tree(raw_payload, "token_free_callback", limit_overrides)


static func public_observation_hash(
	public_tree: Variant,
	limit_overrides: Dictionary = {},
) -> Dictionary:
	return hash_tree(public_tree, "public_observation", limit_overrides)


static func _validate_callback(
	raw_payload: Variant,
	limit_overrides: Dictionary = {},
) -> Dictionary:
	if not raw_payload is Dictionary:
		return _error("invalid_callback")
	for field_name: String in REQUIRED_CALLBACK_FIELDS:
		if not raw_payload.has(field_name):
			return _error("invalid_callback")
	var token: Variant = raw_payload.get("search_begin_input")
	if token != null and typeof(token) != TYPE_STRING:
		return _error("invalid_callback")
	return CabtJsonTreeScript.canonicalize(raw_payload, limit_overrides)


static func _contains_search_material(value: Variant) -> bool:
	var stack: Array = [value]
	while not stack.is_empty():
		var current: Variant = stack.pop_back()
		if current is Dictionary:
			for key: Variant in current.keys():
				var key_text := str(key)
				if key_text == "search_begin_input" or key_text == SEARCH_PRESENCE_MARKER:
					return true
				stack.append(current[key])
		elif current is Array:
			for child: Variant in current:
				stack.append(child)
	return false


static func _error(code: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": code,
		"sha256": "",
		"canonical_text": "",
		"canonical_bytes": PackedByteArray(),
	}
