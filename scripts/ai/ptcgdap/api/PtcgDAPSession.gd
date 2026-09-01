class_name PtcgDAPSession
extends RefCounted

const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtObservationParserScript = preload("res://scripts/ai/ptcgdap/cabt/CabtObservationParser.gd")


class SessionIngestResult:
	extends RefCounted

	var _envelope: Variant = null
	var _issues: Array = []
	var _reset := false

	var envelope: Variant:
		get:
			return _envelope

	var issues: Array:
		get:
			return _issues.duplicate(true)

	var reset: bool:
		get:
			return _reset

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

	func _init(envelope_value: Variant, issue_values: Array, reset_value: bool) -> void:
		_envelope = envelope_value
		_issues = issue_values.duplicate(true)
		_reset = reset_value

	func safe_diagnostics() -> Array:
		return _issues.duplicate(true)


var _session_id := ""
var _contract_set: Variant = null
var _valid := false
var _episode_generation := 0
var _callback_generation := 0
var _current_callback_binding_hash: Variant = null
var _opaque_search_capability_present := false
var _callback_local_state := {}

var session_id: String:
	get:
		return _session_id

var episode_generation: int:
	get:
		return _episode_generation

var callback_generation: int:
	get:
		return _callback_generation

var current_callback_binding_hash: Variant:
	get:
		return _current_callback_binding_hash

var opaque_search_capability_present: bool:
	get:
		return _opaque_search_capability_present

var callback_local_state: Dictionary:
	get:
		return _callback_local_state.duplicate(true)


func _init(session_id_value: Variant, contract_set: Variant = null) -> void:
	_session_id = str(session_id_value) if typeof(session_id_value) == TYPE_STRING else ""
	_contract_set = contract_set if contract_set != null else CabtContractSetScript.load_default()
	_valid = (
		not _session_id.is_empty()
		and _is_exact_contract_set(_contract_set)
	)


func remember_callback_local(key: Variant, value: Variant) -> bool:
	if not _valid or not _is_exact_contract_set(_contract_set):
		_revoke_contract_authority()
		return false
	if typeof(key) != TYPE_STRING or str(key).is_empty():
		return false
	_callback_local_state[str(key)] = _deep_copy(value)
	return true


func ingest(raw_payload: Variant) -> SessionIngestResult:
	if not _valid or not _is_exact_contract_set(_contract_set):
		_revoke_contract_authority()
		return SessionIngestResult.new(
			null,
			[{
				"code": "invalid_session",
				"pointer": "",
				"severity": "error",
			}],
			false
		)
	# Any ingest attempt revokes all authority tied to the prior callback,
	# including when the replacement callback later fails closed.
	_callback_local_state = {}
	_current_callback_binding_hash = null
	_opaque_search_capability_present = false
	var parse_result: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(
		raw_payload,
		_contract_set
	)
	var envelope: Variant = parse_result.envelope
	if envelope == null:
		return SessionIngestResult.new(null, parse_result.issues, false)

	var reset_value: bool = envelope.is_initial_callback
	if reset_value:
		_episode_generation += 1
		_callback_generation = 0
	else:
		_callback_generation += 1
	_current_callback_binding_hash = envelope.token_free_callback_hash
	_opaque_search_capability_present = envelope.opaque_search_capability_present
	return SessionIngestResult.new(envelope, parse_result.issues, reset_value)


func _revoke_contract_authority() -> void:
	_valid = false
	_callback_local_state = {}
	_current_callback_binding_hash = null
	_opaque_search_capability_present = false


static func _is_exact_contract_set(value: Variant) -> bool:
	return (
		value != null
		and value is RefCounted
		and value.get_script() == CabtContractSetScript
		and bool(value.get("ok"))
		and value.has_method("validate_integrity")
		and value.validate_integrity() == true
	)


static func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value
