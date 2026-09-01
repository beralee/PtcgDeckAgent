class_name GodotActionExecutor
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const TicketScript = preload("res://scripts/engine/decision/GodotActionTicket.gd")
const BindingScript = preload("res://scripts/engine/decision/GodotOptionBinding.gd")
const PortScript = preload("res://scripts/engine/decision/EngineDecisionPort.gd")
const WindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")

const PROFILE_ID := "ptcgdap-godot-action-executor-p3-wp4-v1"
const EXPECTED_BUNDLE_SHA256 := "45952BE629AE98EB6070C77188FD6A2C2A644C4B6A36876193BB745B7CDA4E92"
const EXPECTED_ARTIFACTS := {
	"schema": ["res://contracts/ptcgdap/godot_action_executor.schema.json", "4685296B16CBC3D5BAA21AC1C487BF7F603CB8858AA180A59CEF3B50EC62D240"],
	"profile": ["res://contracts/ptcgdap/godot_action_executor_profile.json", "4E39CDD0118EFA9DEF8C19781953F13CD56A09C65F198BF1AF4755359098872D"],
	"vectors": ["res://contracts/ptcgdap/godot_action_executor_conformance_vectors.json", "7551A365263C21BD0F77DF9047423436AA35E7D4C8A16B18B9F2CBDC2BED73D2"],
}
const BUNDLE_PATH := "res://contracts/ptcgdap/godot_action_executor_bundle.json"
const PREFLIGHT_PREFIX_HEX := "5054434744415000474F444F545F414354494F4E5F4558454355544F525F563100"
const SAFE_MAX := 9_007_199_254_740_991
const FACTORY_TOKEN := "godot-action-executor-owner-factory-v1"


class PreparedBatch extends RefCounted:
	var _owner: Variant = null
	var _construction_seal: Variant = null
	var _preflight_id: Variant = ""
	var _preflight_generation: Variant = 0
	var _state: Variant = "prepared"
	var _ticket_owner: Variant = null
	var _claim_result: Variant = null
	var _binding_owner: Variant = null
	var _binding: Variant = null
	var _port: Variant = null
	var _snapshot: Variant = null
	var _current_source: Variant = null
	var _window: Variant = null
	var _callback_hash: Variant = ""
	var _resolutions: Variant = []

	var preflight_id: Variant:
		get: return _preflight_id
	var preflight_generation: Variant:
		get: return _preflight_generation
	var state: Variant:
		get: return _state

	func initialize(owner: Variant, generation: int, values: Dictionary) -> Variant:
		_owner = weakref(owner)
		_construction_seal = FACTORY_TOKEN
		_preflight_generation = generation
		_state = "prepared"
		_ticket_owner = values.get("ticket_owner")
		_claim_result = values.get("claim_result")
		_binding_owner = values.get("binding_owner")
		_binding = values.get("binding")
		_port = values.get("port")
		_snapshot = values.get("snapshot")
		_current_source = values.get("current_source")
		_window = values.get("window")
		_callback_hash = values.get("callback_binding_hash")
		_resolutions = (_claim_result.binding_resolutions as Array).duplicate()
		_preflight_id = owner.call("_preflight_hash", self)
		return self

	func validate_integrity(owner: Variant) -> bool:
		var actual_owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		return owner != null and owner == actual_owner and bool(owner.call("_batch_fields_valid", self))

	func to_public_dict() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if owner == null or not bool(owner.call("_batch_fields_valid", self)):
			return {}
		return owner.call("_audit", self)

	func to_dict() -> Dictionary:
		return to_public_dict()


class PreflightResult extends RefCounted:
	var _owner: Variant = null
	var _construction_seal: Variant = null
	var _accepted := false
	var _error_code := ""
	var _preflight: Variant = null

	var accepted: bool:
		get: return _accepted
	var error_code: String:
		get: return _error_code
	var preflight: Variant:
		get: return _preflight

	func initialize(owner: Variant, accepted_value: bool, code: String, batch: Variant) -> Variant:
		_owner = weakref(owner)
		_construction_seal = FACTORY_TOKEN
		_accepted = accepted_value
		_error_code = code
		_preflight = batch
		return self

	func validate_integrity(owner: Variant) -> bool:
		var actual_owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		return owner != null and owner == actual_owner and bool(owner.call("_preflight_result_valid", self))

	func to_public_dict() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if owner == null or not bool(owner.call("_preflight_result_valid", self)):
			return {}
		return {
			"accepted": _accepted,
			"error_code": _error_code,
			"audit": null if _preflight == null else _preflight.to_public_dict(),
		}

	func to_dict() -> Dictionary:
		return to_public_dict()


class CommitResult extends RefCounted:
	var _owner: Variant = null
	var _construction_seal: Variant = null
	var _accepted := false
	var _error_code := ""
	var _binding_resolutions: Variant = []
	var _preflight: Variant = null

	var accepted: bool:
		get: return _accepted
	var error_code: String:
		get: return _error_code
	var binding_resolutions: Array:
		get: return _binding_resolutions.duplicate() if _binding_resolutions is Array else []

	func initialize(owner: Variant, accepted_value: bool, code: String, batch: Variant, resolutions: Array = []) -> Variant:
		_owner = weakref(owner)
		_construction_seal = FACTORY_TOKEN
		_accepted = accepted_value
		_error_code = code
		_preflight = batch
		_binding_resolutions = resolutions.duplicate()
		return self

	func validate_integrity(owner: Variant) -> bool:
		var actual_owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		return owner != null and owner == actual_owner and bool(owner.call("_commit_result_valid", self))

	func to_public_dict() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if owner == null or not bool(owner.call("_commit_result_valid", self)):
			return {}
		return {
			"accepted": _accepted,
			"error_code": _error_code,
			"audit": _preflight.to_public_dict() if _accepted and _preflight != null else null,
		}

	func to_dict() -> Dictionary:
		return to_public_dict()


var _ok := false
var _error_code := "executor_contract_error"
var _next_generation: Variant = 1
var _active: Variant = null
var _preflight_codes: Variant = {}
var _commit_codes: Variant = {}

var contract_hash: String:
	get: return EXPECTED_BUNDLE_SHA256 if _ok else ""
var error_code: String:
	get: return _error_code


func _init() -> void:
	var loaded := _load_contracts()
	_ok = bool(loaded.get("ok", false))
	_error_code = "" if _ok else "executor_contract_error"
	_preflight_codes = loaded.get("preflight_codes", {})
	_commit_codes = loaded.get("commit_codes", {})


func validate_integrity() -> bool:
	if (
		not _ok
		or _error_code != ""
		or typeof(_next_generation) != TYPE_INT
		or _next_generation < 1
		or _next_generation > SAFE_MAX + 1
		or not _preflight_codes is Dictionary
		or not _commit_codes is Dictionary
	):
		return false
	if _active == null:
		return true
	var owner_ref: Variant = _active.get("_owner") if typeof(_active) == TYPE_OBJECT else null
	return _active is PreparedBatch and owner_ref is WeakRef and (owner_ref as WeakRef).get_ref() == self


func current_preflight() -> Variant:
	return _active if _active is PreparedBatch and _active.state == "prepared" and _batch_fields_valid(_active) else null


func prepare(
	ticket_owner: Variant,
	claim_result: Variant,
	binding_owner: Variant,
	binding_value: Variant,
	port: Variant,
	snapshot: Variant,
	current_source: Variant,
	window: Variant,
	callback_binding_hash: Variant
) -> Variant:
	if not validate_integrity():
		return _preflight_reject("executor_integrity_invalid")
	if _active is PreparedBatch and _active.state == "prepared":
		return _preflight_reject("active_preflight_exists")
	if _next_generation > SAFE_MAX:
		return _preflight_reject("preflight_space_exhausted")
	var values := {
		"ticket_owner": ticket_owner,
		"claim_result": claim_result,
		"binding_owner": binding_owner,
		"binding": binding_value,
		"port": port,
		"snapshot": snapshot,
		"current_source": current_source,
		"window": window,
		"callback_binding_hash": callback_binding_hash,
	}
	var checked := _context_check(values)
	var code := str(checked.get("error_code", ""))
	if not code.is_empty():
		return _preflight_reject(code)
	var batch: Variant = PreparedBatch.new().initialize(self, _next_generation, values)
	_next_generation += 1
	_active = batch
	return PreflightResult.new().initialize(self, true, "", batch)


func commit(
	preflight: Variant,
	ticket_owner: Variant,
	binding_owner: Variant,
	binding_value: Variant,
	port: Variant,
	snapshot: Variant,
	current_source: Variant,
	window: Variant,
	callback_binding_hash: Variant
) -> Variant:
	if not validate_integrity():
		return _commit_reject("executor_integrity_invalid")
	if not preflight is PreparedBatch:
		return _commit_reject("invalid_preflight")
	var owner_ref: Variant = preflight.get("_owner")
	if not owner_ref is WeakRef or (owner_ref as WeakRef).get_ref() != self:
		return _commit_reject("owner_mismatch")
	if not _batch_fields_valid(preflight):
		return _commit_reject("preflight_integrity_invalid")
	if preflight.state == "committed":
		return _commit_reject("already_committed", preflight)
	if preflight.state == "aborted":
		return _commit_reject("preflight_aborted", preflight)
	if preflight != _active:
		return _commit_reject("preflight_not_current")
	var values := {
		"ticket_owner": ticket_owner,
		"claim_result": preflight.get("_claim_result"),
		"binding_owner": binding_owner,
		"binding": binding_value,
		"port": port,
		"snapshot": snapshot,
		"current_source": current_source,
		"window": window,
		"callback_binding_hash": callback_binding_hash,
	}
	var checked := _context_check(values)
	var code := str(checked.get("error_code", ""))
	if not code.is_empty():
		preflight.set("_state", "aborted")
		var mapped := code if code in ["private_resolution_invalid", "private_reference_unavailable"] else "commit_context_changed"
		return _commit_reject(mapped, preflight)
	var current: Array = checked.get("resolutions", [])
	var expected: Variant = preflight.get("_resolutions")
	if not expected is Array or not _same_objects(expected, current):
		preflight.set("_state", "aborted")
		return _commit_reject("private_resolution_invalid", preflight)
	preflight.set("_state", "committed")
	return CommitResult.new().initialize(self, true, "", preflight, expected)


func abort(preflight: Variant) -> bool:
	if (
		not validate_integrity()
		or not preflight is PreparedBatch
		or preflight != _active
		or not _batch_fields_valid(preflight)
		or preflight.state != "prepared"
	):
		return false
	preflight.set("_state", "aborted")
	return true


func _context_check(values: Dictionary) -> Dictionary:
	var ticket_owner: Variant = values.get("ticket_owner")
	var claim_result: Variant = values.get("claim_result")
	if not _exact_script(ticket_owner, TicketScript):
		return {"error_code": "invalid_ticket_owner"}
	if claim_result == null or typeof(claim_result) != TYPE_OBJECT or not claim_result.has_method("validate_integrity"):
		return {"error_code": "invalid_claim_result"}
	if not bool(claim_result.get("accepted")):
		return {"error_code": "claim_not_accepted"}
	var claim_owner_ref: Variant = claim_result.get("_owner")
	var ticket: Variant = claim_result.get("_ticket")
	if not claim_owner_ref is WeakRef or (claim_owner_ref as WeakRef).get_ref() != ticket_owner or ticket == null:
		return {"error_code": "invalid_claim_result"}
	var resolutions: Variant = claim_result.get("binding_resolutions")
	if not resolutions is Array:
		return {"error_code": "invalid_claim_result"}
	var indexes := []
	for result: Variant in resolutions:
		indexes.append(result.get("option_index") if result != null and typeof(result) == TYPE_OBJECT else null)
	if indexes != ticket.selected_indexes:
		return {"error_code": "selection_mismatch"}
	var binding_owner: Variant = values.get("binding_owner")
	var binding_value: Variant = values.get("binding")
	if not _exact_script(binding_owner, BindingScript):
		return {"error_code": "invalid_binding_owner"}
	if binding_owner != ticket.get("_binding_owner") or binding_value != ticket.get("_binding") or binding_owner.current_binding() != binding_value:
		return {"error_code": "binding_not_current"}
	var port: Variant = values.get("port")
	var snapshot: Variant = values.get("snapshot")
	if port != ticket.get("_port") or snapshot != ticket.get("_snapshot") or not _exact_script(port, PortScript) or port.current_snapshot() != snapshot:
		return {"error_code": "snapshot_not_current"}
	var window: Variant = values.get("window")
	if window != ticket.get("_window") or not _exact_script(window, WindowScript):
		return {"error_code": "window_not_current"}
	var callback_hash: Variant = values.get("callback_binding_hash")
	if typeof(callback_hash) != TYPE_STRING or callback_hash != ticket.get("_callback_binding_hash"):
		return {"error_code": "callback_mismatch"}
	for result: Variant in resolutions:
		if result == null or typeof(result) != TYPE_OBJECT or not result.has_method("validate_integrity"):
			return {"error_code": "private_resolution_invalid"}
		if not bool(result.get("accepted")) or result.get("private_engine_command") == null:
			return {"error_code": "private_reference_unavailable"}
	var current := []
	for index: int in range(indexes.size()):
		var resolved: Variant = binding_owner.resolve(
			binding_value, port, snapshot, values.get("current_source"), window,
			callback_hash, indexes[index]
		)
		if not bool(resolved.get("accepted")):
			return {
				"error_code": "private_reference_unavailable" if resolved.get("error_code") == "reference_released" else "binding_not_current"
			}
		if not bool(resolved.validate_integrity(binding_owner)):
			return {"error_code": "private_resolution_invalid"}
		var expected: Variant = resolutions[index]
		if expected.option_index != resolved.option_index or expected.private_engine_command != resolved.private_engine_command:
			return {"error_code": "private_resolution_invalid"}
		if not _same_objects(expected.private_object_refs, resolved.private_object_refs):
			return {"error_code": "private_resolution_invalid"}
		current.append(expected)
	if not bool(claim_result.validate_integrity(ticket_owner)):
		return {"error_code": "private_resolution_invalid"}
	return {"error_code": "", "resolutions": current}


func _batch_fields_valid(batch: Variant) -> bool:
	if (
		not batch is PreparedBatch
		or batch.get("_construction_seal") != FACTORY_TOKEN
		or not batch.get("_owner") is WeakRef
		or (batch.get("_owner") as WeakRef).get_ref() != self
		or not _upper_sha(batch.preflight_id)
		or typeof(batch.preflight_generation) != TYPE_INT
		or batch.preflight_generation < 1
		or batch.preflight_generation > SAFE_MAX
		or batch.state not in ["prepared", "committed", "aborted"]
		or not _exact_script(batch.get("_ticket_owner"), TicketScript)
		or not _exact_script(batch.get("_binding_owner"), BindingScript)
		or not _exact_script(batch.get("_port"), PortScript)
		or not _exact_script(batch.get("_window"), WindowScript)
		or not _upper_sha(batch.get("_callback_hash"))
		or not batch.get("_resolutions") is Array
	):
		return false
	var claim: Variant = batch.get("_claim_result")
	if claim == null or typeof(claim) != TYPE_OBJECT or claim.get("_ticket") == null:
		return false
	return batch.preflight_id == _preflight_hash(batch) and _same_objects(batch.get("_resolutions"), claim.binding_resolutions)


func _preflight_hash(batch: Variant) -> String:
	var claim: Variant = batch.get("_claim_result")
	var ticket: Variant = claim.get("_ticket") if claim != null else null
	if ticket == null:
		return ""
	var payload := {
		"profile": PROFILE_ID,
		"preflight_generation": batch.preflight_generation,
		"ticket_id": ticket.ticket_id,
		"ticket_generation": ticket.ticket_generation,
		"binding_version": batch.get("_binding").binding_version,
		"snapshot_id": batch.get("_snapshot").get("snapshot_id"),
		"window_id": batch.get("_window").window_id,
		"public_observation_hash": batch.get("_window").public_observation_hash,
		"chooser_player_index": batch.get("_window").chooser_player_index,
		"selected_indexes": ticket.selected_indexes,
		"selected_fingerprint_hashes": ticket.selected_fingerprint_hashes,
		"resolution_count": (batch.get("_resolutions") as Array).size(),
	}
	var canonical := CabtJsonTreeScript.canonicalize_artifact(payload)
	if not bool(canonical.get("ok", false)):
		return ""
	return _sha(_hex_bytes(PREFLIGHT_PREFIX_HEX) + (canonical.get("bytes") as PackedByteArray))


func _audit(batch: Variant) -> Dictionary:
	var ticket: Variant = batch.get("_claim_result").get("_ticket")
	return {
		"executor_profile": PROFILE_ID,
		"preflight_id": batch.preflight_id,
		"preflight_generation": batch.preflight_generation,
		"ticket_id": ticket.ticket_id,
		"ticket_generation": ticket.ticket_generation,
		"binding_version": batch.get("_binding").binding_version,
		"snapshot_id": batch.get("_snapshot").get("snapshot_id"),
		"window_id": batch.get("_window").window_id,
		"public_observation_hash": batch.get("_window").public_observation_hash,
		"chooser_player_index": batch.get("_window").chooser_player_index,
		"selected_indexes": ticket.selected_indexes,
		"selected_fingerprint_hashes": ticket.selected_fingerprint_hashes,
		"resolution_count": (batch.get("_resolutions") as Array).size(),
		"state": batch.state,
		"authority": "godot_action_executor_shadow",
		"authoritative": false,
	}


func _preflight_result_valid(result: Variant) -> bool:
	if (
		not result is PreflightResult
		or result.get("_construction_seal") != FACTORY_TOKEN
		or not result.get("_owner") is WeakRef
		or (result.get("_owner") as WeakRef).get_ref() != self
	):
		return false
	if result.accepted:
		return result.error_code == "" and result.preflight == _active and _batch_fields_valid(result.preflight)
	return result.preflight == null and _preflight_codes.has(result.error_code)


func _commit_result_valid(result: Variant) -> bool:
	if (
		not result is CommitResult
		or result.get("_construction_seal") != FACTORY_TOKEN
		or not result.get("_owner") is WeakRef
		or (result.get("_owner") as WeakRef).get_ref() != self
		or not result.get("_binding_resolutions") is Array
	):
		return false
	if result.accepted:
		return (
			result.error_code == ""
			and result.get("_preflight") == _active
			and result.get("_preflight").state == "committed"
			and _same_objects(result.binding_resolutions, result.get("_preflight").get("_resolutions"))
			and _batch_fields_valid(result.get("_preflight"))
		)
	var batch: Variant = result.get("_preflight")
	return _commit_codes.has(result.error_code) and result.binding_resolutions.is_empty() and (batch == null or _batch_fields_valid(batch))


func _preflight_reject(code: String) -> Variant:
	var safe_code := code if _preflight_codes.has(code) else "executor_integrity_invalid"
	return PreflightResult.new().initialize(self, false, safe_code, null)


func _commit_reject(code: String, batch: Variant = null) -> Variant:
	var safe_code := code if _commit_codes.has(code) else "executor_integrity_invalid"
	return CommitResult.new().initialize(self, false, safe_code, batch)


static func _same_objects(left: Variant, right: Variant) -> bool:
	if not left is Array or not right is Array or left.size() != right.size():
		return false
	for index: int in range(left.size()):
		if left[index] != right[index]:
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
		if entry_value != {"id": artifact_id, "path": str(expected[0]).trim_prefix("res://"), "canonical_sha256": expected[1]}:
			return {"ok": false}
		var artifact := CabtJsonTreeScript.canonicalize_artifact_json_bytes(_read_bytes(expected[0]))
		if not bool(artifact.get("ok", false)) or _sha(artifact.get("bytes")) != expected[1]:
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
	if profile.get("hash_profile", {}).get("prefix_utf8_hex") != PREFLIGHT_PREFIX_HEX:
		return {"ok": false}
	var preflight: Variant = profile.get("preflight_error_codes")
	var commit_codes: Variant = profile.get("commit_error_codes")
	if not preflight is Array or preflight.is_empty() or not commit_codes is Array or commit_codes.is_empty():
		return {"ok": false}
	var preflight_map := {}
	var commit_map := {}
	for code: Variant in preflight:
		if typeof(code) != TYPE_STRING or preflight_map.has(code):
			return {"ok": false}
		preflight_map[code] = true
	for code: Variant in commit_codes:
		if typeof(code) != TYPE_STRING or commit_map.has(code):
			return {"ok": false}
		commit_map[code] = true
	return {"ok": true, "preflight_codes": preflight_map, "commit_codes": commit_map}
