class_name CabtRawEnvelope
extends RefCounted

const ENVELOPE_VERSION := 1
const HASH_PROFILE := "cabt_tree_hash_v1"

var _raw_payload := {}
var _known_view := {}
var _field_presence := {}
var _unknown_fields := []
var _framework := {}
var _enum_values := []
var _parse_issues := []
var _source_lock_id := ""
var _source_contract_hash := ""
var _raw_private_hash := ""
var _token_free_callback_hash := ""
var _opaque_search_capability_present := false
var _initialized := false

var raw_payload: Dictionary:
	get:
		return _raw_payload.duplicate(true)

var known_view: Dictionary:
	get:
		return _known_view.duplicate(true)

var field_presence: Dictionary:
	get:
		return _field_presence.duplicate(true)

var unknown_fields: Array:
	get:
		return _unknown_fields.duplicate(true)

var framework: Dictionary:
	get:
		return _framework.duplicate(true)

var enum_values: Array:
	get:
		return _enum_values.duplicate(true)

var parse_issues: Array:
	get:
		return _parse_issues.duplicate(true)

var source_lock_id: String:
	get:
		return _source_lock_id

var source_contract_hash: String:
	get:
		return _source_contract_hash

var raw_private_hash: String:
	get:
		return _raw_private_hash

var token_free_callback_hash: String:
	get:
		return _token_free_callback_hash

var opaque_search_capability_present: bool:
	get:
		return _opaque_search_capability_present

var firewall_status: String:
	get:
		return "pending"

var public_observation_hash: Variant:
	get:
		return null

var is_initial_callback: bool:
	get:
		return _raw_payload.has("select") and _raw_payload.get("select") == null


func initialize(
	raw_value: Dictionary,
	known_value: Dictionary,
	presence_value: Dictionary,
	unknown_value: Array,
	framework_value: Dictionary,
	enum_value: Array,
	issues_value: Array,
	lock_id: String,
	contract_hash: String,
	raw_hash: String,
	token_free_hash: String
) -> Variant:
	if _initialized:
		return self
	_raw_payload = raw_value.duplicate(true)
	_known_view = known_value.duplicate(true)
	_field_presence = presence_value.duplicate(true)
	_unknown_fields = unknown_value.duplicate(true)
	_framework = framework_value.duplicate(true)
	_enum_values = enum_value.duplicate(true)
	_parse_issues = issues_value.duplicate(true)
	_source_lock_id = lock_id
	_source_contract_hash = contract_hash
	_raw_private_hash = raw_hash
	_token_free_callback_hash = token_free_hash
	_opaque_search_capability_present = raw_value.get("search_begin_input") != null
	_initialized = true
	return self


func to_host_dict() -> Dictionary:
	return {
		"envelope_version": ENVELOPE_VERSION,
		"source_lock_id": source_lock_id,
		"hash_profile": HASH_PROFILE,
		"raw_payload": raw_payload,
		"raw_private_hash": raw_private_hash,
		"token_free_callback_hash": token_free_callback_hash,
		"field_presence": field_presence,
		"known_view": known_view,
		"unknown_fields": unknown_fields,
		"framework": framework,
		"enum_values": enum_values,
		"parse_issues": parse_issues,
		"opaque_search_capability_present": opaque_search_capability_present,
		"firewall_status": firewall_status,
		"public_observation_hash": public_observation_hash,
		"source_contract_hash": source_contract_hash,
	}


func safe_metadata() -> Dictionary:
	var safe_presence: Dictionary = _field_presence.duplicate(true)
	safe_presence.erase("/search_begin_input")
	return {
		"envelope_version": ENVELOPE_VERSION,
		"source_lock_id": source_lock_id,
		"hash_profile": HASH_PROFILE,
		"source_contract_hash": source_contract_hash,
		"field_presence": safe_presence,
		"enum_values": enum_values,
		"parse_issues": parse_issues,
		"opaque_search_capability_present": opaque_search_capability_present,
		"firewall_status": firewall_status,
		"public_observation_hash": public_observation_hash,
	}
