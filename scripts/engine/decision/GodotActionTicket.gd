class_name GodotActionTicket
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const FallbackScript = preload("res://scripts/ai/ptcgdap/cabt/CabtDeterministicFallback.gd")
const BindingScript = preload("res://scripts/engine/decision/GodotOptionBinding.gd")
const PortScript = preload("res://scripts/engine/decision/EngineDecisionPort.gd")
const WindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")

const PROFILE_ID := "ptcgdap-godot-action-ticket-p3-wp3-v1"
const EXPECTED_BUNDLE_SHA256 := "41F3E84C6DC5C9BC6C162B848B097211E617B5558ECB59554757E82CE58817ED"
const EXPECTED_ARTIFACTS := {
	"schema": ["res://contracts/ptcgdap/godot_action_ticket.schema.json", "04ADF5B9B63A7AE935F14D81F24B0231AB0D97943EEF0EB910ADE488024578AC"],
	"profile": ["res://contracts/ptcgdap/godot_action_ticket_profile.json", "EECE547147155932FF4DCB0E73DF1FF026CF91966D413C39EF1AFA3062FC9ADA"],
	"vectors": ["res://contracts/ptcgdap/godot_action_ticket_conformance_vectors.json", "3AC3F5DC55B0B451662A1DDDFEE3CF39EC0B38341F9FD7FA8A7DE92BF171E440"],
}
const BUNDLE_PATH := "res://contracts/ptcgdap/godot_action_ticket_bundle.json"
const TICKET_PREFIX_HEX := "5054434744415000474F444F545F414354494F4E5F5449434B45545F563100"
const SAFE_MAX := 9_007_199_254_740_991
const FACTORY_TOKEN := "godot-action-ticket-owner-factory-v1"
const TICKET_AUDIT_KEYS := [
	"ticket_profile", "ticket_id", "ticket_generation", "binding_version", "snapshot_id",
	"window_id", "public_observation_hash", "selected_indexes", "selected_fingerprint_hashes",
	"authority", "authoritative",
]
const CLAIM_AUDIT_KEYS := [
	"ticket_profile", "ticket_id", "ticket_generation", "selected_indexes",
	"selected_fingerprint_hashes", "state", "authority", "authoritative",
]


class Ticket extends RefCounted:
	var _owner: Variant = null
	var _construction_seal: Variant = null
	var _ticket_id: Variant = ""
	var _ticket_generation: Variant = 0
	var _binding_version: Variant = 0
	var _snapshot_id: Variant = ""
	var _window_id: Variant = ""
	var _public_observation_hash: Variant = ""
	var _selected_indexes: Variant = []
	var _selected_fingerprint_hashes: Variant = []
	var _session_id: Variant = ""
	var _callback_binding_hash: Variant = ""
	var _binding_owner: Variant = null
	var _binding: Variant = null
	var _port: Variant = null
	var _snapshot: Variant = null
	var _window: Variant = null
	var _selection_resolution: Variant = null
	var _public_snapshot: Variant = {}

	var ticket_id: Variant:
		get: return _ticket_id
	var ticket_generation: Variant:
		get: return _ticket_generation
	var binding_version: Variant:
		get: return _binding_version
	var snapshot_id: Variant:
		get: return _snapshot_id
	var window_id: Variant:
		get: return _window_id
	var public_observation_hash: Variant:
		get: return _public_observation_hash
	var selected_indexes: Array:
		get: return _selected_indexes.duplicate(true) if _selected_indexes is Array else []
	var selected_fingerprint_hashes: Array:
		get: return _selected_fingerprint_hashes.duplicate(true) if _selected_fingerprint_hashes is Array else []

	func initialize(owner: Variant, values: Dictionary) -> Variant:
		_owner = weakref(owner)
		_construction_seal = FACTORY_TOKEN
		_ticket_id = values.get("ticket_id")
		_ticket_generation = values.get("ticket_generation")
		_binding_version = values.get("binding_version")
		_snapshot_id = values.get("snapshot_id")
		_window_id = values.get("window_id")
		_public_observation_hash = values.get("public_observation_hash")
		_selected_indexes = (values.get("selected_indexes") as Array).duplicate(true)
		_selected_fingerprint_hashes = (values.get("selected_fingerprint_hashes") as Array).duplicate(true)
		_session_id = values.get("session_id")
		_callback_binding_hash = values.get("callback_binding_hash")
		_binding_owner = values.get("binding_owner")
		_binding = values.get("binding")
		_port = values.get("port")
		_snapshot = values.get("snapshot")
		_window = values.get("window")
		_selection_resolution = values.get("selection_resolution")
		_public_snapshot = (values.get("public_snapshot") as Dictionary).duplicate(true)
		return self

	func validate_integrity(owner: Variant) -> bool:
		var actual_owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		return owner != null and owner == actual_owner and bool(owner.call("_ticket_fields_valid", self))

	func to_public_dict() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if owner == null or not bool(owner.call("_ticket_fields_valid", self)):
			return {}
		return _public_snapshot.duplicate(true) if _public_snapshot is Dictionary else {}

	func to_dict() -> Dictionary:
		return to_public_dict()


class IssueResult extends RefCounted:
	var _owner: Variant = null
	var _construction_seal: Variant = null
	var _accepted := false
	var _error_code := ""
	var _ticket: Variant = null
	var _public_snapshot: Variant = {}

	var accepted: bool:
		get: return _accepted
	var error_code: String:
		get: return _error_code
	var ticket: Variant:
		get: return _ticket

	func initialize(owner: Variant, accepted_value: bool, code: String, ticket_value: Variant) -> Variant:
		_owner = weakref(owner)
		_construction_seal = FACTORY_TOKEN
		_accepted = accepted_value
		_error_code = code
		_ticket = ticket_value
		_public_snapshot = {
			"accepted": accepted_value,
			"error_code": code,
			"audit": null if ticket_value == null else ticket_value.to_public_dict(),
		}
		return self

	func validate_integrity(owner: Variant) -> bool:
		var actual_owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		return owner != null and owner == actual_owner and bool(owner.call("_issue_result_valid", self))

	func to_public_dict() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if owner == null or not bool(owner.call("_issue_result_valid", self)):
			return {}
		return _public_snapshot.duplicate(true) if _public_snapshot is Dictionary else {}


class ClaimResult extends RefCounted:
	var _owner: Variant = null
	var _construction_seal: Variant = null
	var _accepted := false
	var _error_code := ""
	var _binding_resolutions: Variant = []
	var _ticket: Variant = null
	var _public_snapshot: Variant = {}

	var accepted: bool:
		get: return _accepted
	var error_code: String:
		get: return _error_code
	var binding_resolutions: Array:
		get: return _binding_resolutions.duplicate() if _binding_resolutions is Array else []

	func initialize(owner: Variant, accepted_value: bool, code: String, ticket_value: Variant, resolutions: Array = []) -> Variant:
		_owner = weakref(owner)
		_construction_seal = FACTORY_TOKEN
		_accepted = accepted_value
		_error_code = code
		_binding_resolutions = resolutions.duplicate()
		_ticket = ticket_value
		_public_snapshot = {
			"accepted": accepted_value,
			"error_code": code,
			"audit": owner.call("_claim_audit", ticket_value) if accepted_value and ticket_value != null else null,
		}
		return self

	func validate_integrity(owner: Variant) -> bool:
		var actual_owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		return owner != null and owner == actual_owner and bool(owner.call("_claim_result_valid", self))

	func to_public_dict() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if owner == null or not bool(owner.call("_claim_result_valid", self)):
			return {}
		return _public_snapshot.duplicate(true) if _public_snapshot is Dictionary else {}


var _ok := false
var _error_code := "ticket_contract_error"
var _next_generation: Variant = 1
var _ticket: Variant = null
var _state: Variant = "none"
var _closed_bindings: Variant = []
var _profile: Variant = {}
var _error_codes: Variant = {}

var contract_hash: String:
	get: return EXPECTED_BUNDLE_SHA256 if _ok else ""
var error_code: String:
	get: return _error_code


func _init() -> void:
	var loaded := _load_contracts()
	_ok = bool(loaded.get("ok", false))
	_error_code = "" if _ok else "ticket_contract_error"
	_profile = loaded.get("profile", {})
	_error_codes = loaded.get("error_codes", {})


func validate_integrity() -> bool:
	if (
		not _ok
		or _error_code != ""
		or typeof(_next_generation) != TYPE_INT
		or _next_generation < 1
		or _next_generation > SAFE_MAX + 1
		or typeof(_state) != TYPE_STRING
		or _state not in ["none", "issued", "claimed", "revoked"]
		or not _closed_bindings is Array
		or not _error_codes is Dictionary
	):
		return false
	for reference: Variant in _closed_bindings:
		if not reference is WeakRef:
			return false
	if _ticket == null:
		return _state == "none"
	return _ticket_fields_valid(_ticket)


func current_ticket() -> Variant:
	return _ticket if _state == "issued" and _ticket_fields_valid(_ticket) else null


func issue(
	session_id: Variant,
	public_observation_hash: Variant,
	binding_owner: Variant,
	binding_value: Variant,
	port: Variant,
	snapshot: Variant,
	current_source: Variant,
	window: Variant,
	callback_binding_hash: Variant,
	selection_resolution: Variant
) -> Variant:
	if not validate_integrity():
		return _issue_reject("ticket_integrity_invalid")
	if not _session(session_id):
		return _issue_reject("invalid_session_id")
	if not _upper_sha(public_observation_hash):
		return _issue_reject("invalid_public_observation_hash")
	if not _exact_script(binding_owner, BindingScript):
		return _issue_reject("invalid_binding_owner")
	if binding_value == null or typeof(binding_value) != TYPE_OBJECT:
		return _issue_reject("invalid_binding")
	if not _exact_script(window, WindowScript):
		return _issue_reject("binding_not_current")
	var current: Variant = binding_owner.get("_current")
	if (
		binding_owner.current_binding() != binding_value
		or not current is Dictionary
		or current.get("binding") != binding_value
		or current.get("port") != port
		or current.get("snapshot") != snapshot
		or current.get("window") != window
		or current.get("callback_binding_hash") != callback_binding_hash
		or not _exact_script(port, PortScript)
		or port.current_snapshot() != snapshot
	):
		return _issue_reject("binding_not_current")
	if not bool(binding_owner.call("_binding_static_fields_valid", binding_value)):
		return _issue_reject("invalid_binding")
	if not FallbackScript.validate_resolution_integrity(selection_resolution, window):
		return _issue_reject("invalid_selection_resolution")
	if public_observation_hash != window.public_observation_hash:
		return _issue_reject("public_hash_mismatch")
	if not _upper_sha(callback_binding_hash):
		return _issue_reject("invalid_callback_binding_hash")
	var indexes: Array = selection_resolution.selected_indexes
	var context := _resolve_context(
		binding_owner, binding_value, port, snapshot, current_source, window,
		callback_binding_hash, indexes
	)
	var context_code := str(context.get("error_code", ""))
	if not context_code.is_empty():
		return _issue_reject(context_code)
	if _binding_closed(binding_value):
		return _issue_reject("binding_already_claimed")
	if _state == "issued" and _ticket != null:
		if _ticket.get("_binding") == binding_value:
			if (
				_ticket.get("_session_id") == session_id
				and _ticket.public_observation_hash == public_observation_hash
				and _ticket.get("_callback_binding_hash") == callback_binding_hash
				and _ticket.get("_port") == port
				and _ticket.get("_snapshot") == snapshot
				and _ticket.get("_window") == window
				and _ticket.get("_selection_resolution") == selection_resolution
				and _ticket.selected_indexes == indexes
			):
				return IssueResult.new().initialize(self, true, "", _ticket)
			return _issue_reject("active_ticket_exists")
		_close_binding(_ticket.get("_binding"))
		_state = "revoked"
	if _next_generation > SAFE_MAX:
		return _issue_reject("ticket_space_exhausted")
	var fingerprints := []
	for index: Variant in indexes:
		fingerprints.append(window.option_fingerprints[index])
	var values := {
		"ticket_generation": _next_generation,
		"session_id": session_id,
		"callback_binding_hash": callback_binding_hash,
		"binding_version": binding_value.binding_version,
		"snapshot_id": snapshot.get("snapshot_id"),
		"window_id": window.window_id,
		"public_observation_hash": window.public_observation_hash,
		"selected_indexes": indexes.duplicate(true),
		"selected_fingerprint_hashes": fingerprints.duplicate(true),
		"binding_owner": binding_owner,
		"binding": binding_value,
		"port": port,
		"snapshot": snapshot,
		"window": window,
		"selection_resolution": selection_resolution,
	}
	values["ticket_id"] = _ticket_hash(values)
	values["public_snapshot"] = _ticket_audit_from_values(values)
	var created: Variant = Ticket.new().initialize(self, values)
	_next_generation += 1
	_ticket = created
	_state = "issued"
	return IssueResult.new().initialize(self, true, "", created)


func claim(
	ticket_value: Variant,
	session_id: Variant,
	public_observation_hash: Variant,
	binding_owner: Variant,
	binding_value: Variant,
	port: Variant,
	snapshot: Variant,
	current_source: Variant,
	window: Variant,
	callback_binding_hash: Variant
) -> Variant:
	if not ticket_value is Ticket:
		return _claim_reject("invalid_ticket")
	var foreign: Variant = ticket_value.get("_owner")
	if not foreign is WeakRef or (foreign as WeakRef).get_ref() != self:
		return _claim_reject("owner_mismatch")
	if not _ticket_fields_valid(ticket_value):
		return _claim_reject("ticket_integrity_invalid")
	if ticket_value != _ticket:
		return _claim_reject("ticket_not_current")
	if _state == "claimed":
		return _claim_reject("ticket_already_claimed")
	if _state == "revoked":
		return _claim_reject("ticket_revoked")
	if _state != "issued":
		return _claim_reject("ticket_not_current")
	if typeof(session_id) != TYPE_STRING or session_id != ticket_value.get("_session_id"):
		return _claim_reject("session_mismatch")
	if typeof(callback_binding_hash) != TYPE_STRING or callback_binding_hash != ticket_value.get("_callback_binding_hash"):
		return _claim_reject("callback_mismatch")
	if typeof(public_observation_hash) != TYPE_STRING or public_observation_hash != ticket_value.public_observation_hash:
		return _claim_reject("public_hash_mismatch")
	if (
		binding_owner != ticket_value.get("_binding_owner")
		or binding_value != ticket_value.get("_binding")
		or port != ticket_value.get("_port")
		or snapshot != ticket_value.get("_snapshot")
		or window != ticket_value.get("_window")
	):
		_revoke(ticket_value)
		return _claim_reject("binding_not_current")
	if not FallbackScript.validate_resolution_integrity(ticket_value.get("_selection_resolution"), window):
		_revoke(ticket_value)
		return _claim_reject("selection_not_current")
	var context := _resolve_context(
		binding_owner, binding_value, port, snapshot, current_source, window,
		callback_binding_hash, ticket_value.selected_indexes
	)
	var code := str(context.get("error_code", ""))
	if not code.is_empty():
		_revoke(ticket_value)
		return _claim_reject(code)
	_state = "claimed"
	_close_binding(binding_value)
	return ClaimResult.new().initialize(self, true, "", ticket_value, context.get("resolutions", []))


func _resolve_context(
	binding_owner: Variant,
	binding_value: Variant,
	port: Variant,
	snapshot: Variant,
	current_source: Variant,
	window: Variant,
	callback_hash: Variant,
	indexes: Array
) -> Dictionary:
	var results := []
	for index: Variant in indexes:
		var result: Variant = binding_owner.resolve(
			binding_value, port, snapshot, current_source, window, callback_hash, index
		)
		if not result.accepted:
			var code := "private_reference_unavailable" if result.error_code == "reference_released" else "binding_not_current"
			return {"resolutions": [], "error_code": code}
		if not result.validate_integrity(binding_owner):
			return {"resolutions": [], "error_code": "binding_not_current"}
		results.append(result)
	return {"resolutions": results, "error_code": ""}


func _ticket_fields_valid(ticket_value: Variant) -> bool:
	if not ticket_value is Ticket:
		return false
	var owner_ref: Variant = ticket_value.get("_owner")
	if (
		not owner_ref is WeakRef
		or (owner_ref as WeakRef).get_ref() != self
		or ticket_value.get("_construction_seal") != FACTORY_TOKEN
		or not _upper_sha(ticket_value.ticket_id)
		or typeof(ticket_value.ticket_generation) != TYPE_INT
		or ticket_value.ticket_generation < 1
		or ticket_value.ticket_generation > SAFE_MAX
		or typeof(ticket_value.binding_version) != TYPE_INT
		or not _exact_script(ticket_value.get("_binding_owner"), BindingScript)
		or not _exact_script(ticket_value.get("_port"), PortScript)
		or not _exact_script(ticket_value.get("_window"), WindowScript)
		or not FallbackScript.validate_resolution_integrity(ticket_value.get("_selection_resolution"), ticket_value.get("_window"))
		or not _session(ticket_value.get("_session_id"))
		or not _upper_sha(ticket_value.get("_callback_binding_hash"))
	):
		return false
	var binding_value: Variant = ticket_value.get("_binding")
	var snapshot: Variant = ticket_value.get("_snapshot")
	var window: Variant = ticket_value.get("_window")
	if (
		binding_value == null
		or typeof(binding_value) != TYPE_OBJECT
		or ticket_value.binding_version != binding_value.binding_version
		or snapshot == null
		or ticket_value.snapshot_id != snapshot.get("snapshot_id")
		or ticket_value.window_id != window.window_id
		or ticket_value.public_observation_hash != window.public_observation_hash
		or not ticket_value.get("_selected_indexes") is Array
		or not ticket_value.get("_selected_fingerprint_hashes") is Array
	):
		return false
	var indexes: Array = ticket_value.get("_selected_indexes")
	var fingerprints: Array = ticket_value.get("_selected_fingerprint_hashes")
	if indexes != ticket_value.get("_selection_resolution").selected_indexes or indexes.size() != fingerprints.size():
		return false
	var seen := {}
	var expected_fingerprints := []
	for index: Variant in indexes:
		if typeof(index) != TYPE_INT or index < 0 or index >= window.option_count or seen.has(index):
			return false
		seen[index] = true
		expected_fingerprints.append(window.option_fingerprints[index])
	if fingerprints != expected_fingerprints:
		return false
	var values := {
		"ticket_generation": ticket_value.ticket_generation,
		"session_id": ticket_value.get("_session_id"),
		"callback_binding_hash": ticket_value.get("_callback_binding_hash"),
		"binding_version": ticket_value.binding_version,
		"snapshot_id": ticket_value.snapshot_id,
		"window_id": ticket_value.window_id,
		"public_observation_hash": ticket_value.public_observation_hash,
		"selected_indexes": indexes,
		"selected_fingerprint_hashes": fingerprints,
	}
	if ticket_value.ticket_id != _ticket_hash(values):
		return false
	var public_snapshot: Variant = ticket_value.get("_public_snapshot")
	return public_snapshot is Dictionary and _exact_keys(public_snapshot, TICKET_AUDIT_KEYS) and public_snapshot == _ticket_audit(ticket_value)


func _issue_result_valid(result: Variant) -> bool:
	if not result is IssueResult:
		return false
	var owner_ref: Variant = result.get("_owner")
	if (
		not owner_ref is WeakRef
		or (owner_ref as WeakRef).get_ref() != self
		or result.get("_construction_seal") != FACTORY_TOKEN
		or not _error_codes.has(result.error_code)
		or not result.get("_public_snapshot") is Dictionary
	):
		return false
	if result.accepted:
		return (
			result.error_code == ""
			and result.ticket != null
			and _ticket_fields_valid(result.ticket)
			and result.get("_public_snapshot") == {"accepted": true, "error_code": "", "audit": result.ticket.to_public_dict()}
		)
	return (
		not result.error_code.is_empty()
		and result.ticket == null
		and result.get("_public_snapshot") == {"accepted": false, "error_code": result.error_code, "audit": null}
	)


func _claim_result_valid(result: Variant) -> bool:
	if not result is ClaimResult:
		return false
	var owner_ref: Variant = result.get("_owner")
	if (
		not owner_ref is WeakRef
		or (owner_ref as WeakRef).get_ref() != self
		or result.get("_construction_seal") != FACTORY_TOKEN
		or not _error_codes.has(result.error_code)
		or not result.get("_binding_resolutions") is Array
		or not result.get("_public_snapshot") is Dictionary
	):
		return false
	if result.accepted:
		var ticket_value: Variant = result.get("_ticket")
		var resolutions: Array = result.get("_binding_resolutions")
		if (
			result.error_code != ""
			or ticket_value != _ticket
			or _state != "claimed"
			or not _ticket_fields_valid(ticket_value)
			or resolutions.size() != ticket_value.selected_indexes.size()
		):
			return false
		for index: int in range(resolutions.size()):
			var resolution: Variant = resolutions[index]
			if not resolution.validate_integrity(ticket_value.get("_binding_owner")) or resolution.option_index != ticket_value.selected_indexes[index]:
				return false
		return result.get("_public_snapshot") == {"accepted": true, "error_code": "", "audit": _claim_audit(ticket_value)}
	return (
		not result.error_code.is_empty()
		and (result.get("_binding_resolutions") as Array).is_empty()
		and result.get("_ticket") == null
		and result.get("_public_snapshot") == {"accepted": false, "error_code": result.error_code, "audit": null}
	)


func _ticket_audit(ticket_value: Variant) -> Dictionary:
	return {
		"ticket_profile": PROFILE_ID,
		"ticket_id": ticket_value.ticket_id,
		"ticket_generation": ticket_value.ticket_generation,
		"binding_version": ticket_value.binding_version,
		"snapshot_id": ticket_value.snapshot_id,
		"window_id": ticket_value.window_id,
		"public_observation_hash": ticket_value.public_observation_hash,
		"selected_indexes": ticket_value.selected_indexes,
		"selected_fingerprint_hashes": ticket_value.selected_fingerprint_hashes,
		"authority": "godot_action_ticket_shadow",
		"authoritative": false,
	}


func _ticket_audit_from_values(values: Dictionary) -> Dictionary:
	return {
		"ticket_profile": PROFILE_ID,
		"ticket_id": values.get("ticket_id"),
		"ticket_generation": values.get("ticket_generation"),
		"binding_version": values.get("binding_version"),
		"snapshot_id": values.get("snapshot_id"),
		"window_id": values.get("window_id"),
		"public_observation_hash": values.get("public_observation_hash"),
		"selected_indexes": (values.get("selected_indexes") as Array).duplicate(true),
		"selected_fingerprint_hashes": (values.get("selected_fingerprint_hashes") as Array).duplicate(true),
		"authority": "godot_action_ticket_shadow",
		"authoritative": false,
	}


func _claim_audit(ticket_value: Variant) -> Dictionary:
	return {
		"ticket_profile": PROFILE_ID,
		"ticket_id": ticket_value.ticket_id,
		"ticket_generation": ticket_value.ticket_generation,
		"selected_indexes": ticket_value.selected_indexes,
		"selected_fingerprint_hashes": ticket_value.selected_fingerprint_hashes,
		"state": "claimed",
		"authority": "godot_action_claim_shadow",
		"authoritative": false,
	}


func _binding_closed(binding_value: Variant) -> bool:
	var alive := []
	var found := false
	for reference: Variant in _closed_bindings:
		if reference is WeakRef:
			var value: Variant = (reference as WeakRef).get_ref()
			if value != null:
				alive.append(reference)
				found = found or value == binding_value
	_closed_bindings = alive
	return found


func _close_binding(binding_value: Variant) -> void:
	if binding_value != null and not _binding_closed(binding_value):
		_closed_bindings.append(weakref(binding_value))


func _revoke(ticket_value: Variant) -> void:
	_state = "revoked"
	_close_binding(ticket_value.get("_binding"))


func _issue_reject(code: String) -> Variant:
	var safe_code := code if _error_codes.has(code) and not code.is_empty() else "ticket_integrity_invalid"
	return IssueResult.new().initialize(self, false, safe_code, null)


func _claim_reject(code: String) -> Variant:
	var safe_code := code if _error_codes.has(code) and not code.is_empty() else "ticket_integrity_invalid"
	return ClaimResult.new().initialize(self, false, safe_code, null)


static func _ticket_hash(values: Dictionary) -> String:
	var payload := {
		"profile": PROFILE_ID,
		"ticket_generation": values.get("ticket_generation"),
		"session_id": values.get("session_id"),
		"callback_binding_hash": values.get("callback_binding_hash"),
		"binding_version": values.get("binding_version"),
		"snapshot_id": values.get("snapshot_id"),
		"window_id": values.get("window_id"),
		"public_observation_hash": values.get("public_observation_hash"),
		"selected_indexes": (values.get("selected_indexes") as Array).duplicate(true),
		"selected_fingerprint_hashes": (values.get("selected_fingerprint_hashes") as Array).duplicate(true),
	}
	var canonical := CabtJsonTreeScript.canonicalize_artifact(payload)
	if not bool(canonical.get("ok", false)):
		return ""
	return _sha(_hex_bytes(TICKET_PREFIX_HEX) + (canonical.get("bytes") as PackedByteArray))


static func _session(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or not str(value).begins_with("session:"):
		return false
	var suffix := str(value).trim_prefix("session:")
	if suffix.is_empty() or suffix.length() > 64:
		return false
	for character: String in suffix:
		if not (character >= "a" and character <= "z") and not (character >= "0" and character <= "9") and character not in ["_", "-"]:
			return false
	return true


static func _upper_sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	for character: String in str(value):
		if not (character >= "0" and character <= "9") and not (character >= "A" and character <= "F"):
			return false
	return true


static func _exact_script(value: Variant, expected: GDScript) -> bool:
	return value != null and typeof(value) == TYPE_OBJECT and value.get_script() == expected


static func _exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _read_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


static func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _hex_bytes(value: String) -> PackedByteArray:
	return value.hex_decode()


static func _load_contracts() -> Dictionary:
	var bundle_bytes := _read_bytes(BUNDLE_PATH)
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(bundle_bytes)
	if not bool(canonical.get("ok", false)) or _sha(canonical.get("bytes")) != EXPECTED_BUNDLE_SHA256:
		return {"ok": false}
	var parsed := JSON.new()
	if parsed.parse(bundle_bytes.get_string_from_utf8()) != OK or not parsed.data is Dictionary:
		return {"ok": false}
	if parsed.data.get("contract_id") != PROFILE_ID:
		return {"ok": false}
	var artifacts: Variant = parsed.data.get("artifacts")
	if not artifacts is Array or artifacts.size() != 3:
		return {"ok": false}
	var seen := {}
	for entry_value: Variant in artifacts:
		if not entry_value is Dictionary:
			return {"ok": false}
		var artifact_id: Variant = entry_value.get("id")
		if not EXPECTED_ARTIFACTS.has(artifact_id) or seen.has(artifact_id):
			return {"ok": false}
		var expected: Array = EXPECTED_ARTIFACTS[artifact_id]
		if entry_value != {
			"id": artifact_id,
			"path": str(expected[0]).trim_prefix("res://"),
			"canonical_sha256": expected[1],
		}:
			return {"ok": false}
		var artifact_canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(_read_bytes(expected[0]))
		if not bool(artifact_canonical.get("ok", false)) or _sha(artifact_canonical.get("bytes")) != expected[1]:
			return {"ok": false}
		seen[artifact_id] = true
	if seen.size() != EXPECTED_ARTIFACTS.size():
		return {"ok": false}
	var profile_file := FileAccess.open(EXPECTED_ARTIFACTS["profile"][0], FileAccess.READ)
	if profile_file == null:
		return {"ok": false}
	var profile: Variant = JSON.parse_string(profile_file.get_as_text())
	if not profile is Dictionary or profile.get("profile_id") != PROFILE_ID:
		return {"ok": false}
	var prefix: Variant = profile.get("hash_profile", {}).get("prefix_utf8_hex")
	if typeof(prefix) != TYPE_STRING or prefix != TICKET_PREFIX_HEX:
		return {"ok": false}
	var codes: Variant = profile.get("error_codes")
	if not codes is Array or codes.is_empty():
		return {"ok": false}
	var error_codes := {}
	for code: Variant in codes:
		if typeof(code) != TYPE_STRING or error_codes.has(code):
			return {"ok": false}
		error_codes[code] = true
	return {"ok": true, "profile": profile.duplicate(true), "error_codes": error_codes}
