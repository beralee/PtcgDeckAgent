class_name ShadowEngineCommandApplier
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const GateScript = preload("res://scripts/engine/decision/ShadowMatchOwnerGate.gd")
const BrokerScript = preload("res://scripts/engine/decision/ShadowPromptBroker.gd")

const PROFILE_ID := "ptcgdap-shadow-engine-command-applier-p3-wp7-v1"
const EXPECTED_BUNDLE_SHA256 := "7539A9D5120666AEBA1325DD6623F437831A024996BD612F3EC677F78C9F8F4C"
const EXPECTED_ARTIFACTS := {
	"schema": ["res://contracts/ptcgdap/shadow_engine_command_applier.schema.json", "DA648A7B1EDBE9770B25294A4C67F66E3141504038B5C73A0639A43C42D9E9CC"],
	"profile": ["res://contracts/ptcgdap/shadow_engine_command_applier_profile.json", "4DDB4E2F367019AC191779CF9913936DFFAABFEF2CC57F358CA7C2CF517E0D1E"],
	"vectors": ["res://contracts/ptcgdap/shadow_engine_command_applier_conformance_vectors.json", "5D3C50D496FFB19EA2BF15ADD60C6A5964437575E85AA90FF9DCEC6B70132482"],
}
const BUNDLE_PATH := "res://contracts/ptcgdap/shadow_engine_command_applier_bundle.json"
const EXECUTION_PREFIX_HEX := "5054434744415000534841444F575F45584543555445445F5749544E4553535F563100"
const SAFE_MAX := 9_007_199_254_740_991
const MAX_RESOLUTION_COUNT := 256
const FACTORY_TOKEN := "shadow-engine-command-applier-owner-factory-v1"
const STATES := {"ready": true, "executed": true, "aborted": true, "poisoned": true}
const ERROR_CODES := {
	"invalid_applier": true, "invalid_gate": true, "owner_mode_not_aligned": true,
	"invalid_broker": true, "broker_not_current": true, "invalid_broker_result": true,
	"prompt_not_committed": true, "already_applied": true, "invalid_command": true,
	"duplicate_command": true, "capture_failed": true, "command_apply_failed": true,
	"rollback_failed": true,
}


class ExecutedWitness extends RefCounted:
	var _owner: Variant = null
	var _broker_result: Variant = null
	var _construction_seal: Variant = null
	var _public: Variant = {}
	var _sealed_public: Variant = {}

	var profile: Variant: get = _get_profile
	var execution_id: Variant: get = _get_execution_id
	var execution_generation: Variant: get = _get_execution_generation
	var match_generation: Variant: get = _get_match_generation
	var broker_generation: Variant: get = _get_broker_generation
	var decision_generation: Variant: get = _get_decision_generation
	var snapshot_id: Variant: get = _get_snapshot_id
	var window_id: Variant: get = _get_window_id
	var public_observation_hash: Variant: get = _get_public_hash
	var chooser_player_index: Variant: get = _get_chooser
	var selected_indexes: Array: get = _get_selected_indexes
	var selected_fingerprint_hashes: Array: get = _get_selected_fingerprints
	var resolution_count: Variant: get = _get_resolution_count
	var state: Variant: get = _get_state
	var authority: Variant: get = _get_authority
	var authoritative: Variant: get = _get_authoritative

	func _get_profile() -> Variant: return _public.get("profile") if _public is Dictionary else null
	func _get_execution_id() -> Variant: return _public.get("execution_id") if _public is Dictionary else null
	func _get_execution_generation() -> Variant: return _public.get("execution_generation") if _public is Dictionary else null
	func _get_match_generation() -> Variant: return _public.get("match_generation") if _public is Dictionary else null
	func _get_broker_generation() -> Variant: return _public.get("broker_generation") if _public is Dictionary else null
	func _get_decision_generation() -> Variant: return _public.get("decision_generation") if _public is Dictionary else null
	func _get_snapshot_id() -> Variant: return _public.get("snapshot_id") if _public is Dictionary else null
	func _get_window_id() -> Variant: return _public.get("window_id") if _public is Dictionary else null
	func _get_public_hash() -> Variant: return _public.get("public_observation_hash") if _public is Dictionary else null
	func _get_chooser() -> Variant: return _public.get("chooser_player_index") if _public is Dictionary else null
	func _get_selected_indexes() -> Array: return (_public.get("selected_indexes") as Array).duplicate(true) if _public is Dictionary and _public.get("selected_indexes") is Array else []
	func _get_selected_fingerprints() -> Array: return (_public.get("selected_fingerprint_hashes") as Array).duplicate(true) if _public is Dictionary and _public.get("selected_fingerprint_hashes") is Array else []
	func _get_resolution_count() -> Variant: return _public.get("resolution_count") if _public is Dictionary else null
	func _get_state() -> Variant: return _public.get("state") if _public is Dictionary else null
	func _get_authority() -> Variant: return _public.get("authority") if _public is Dictionary else null
	func _get_authoritative() -> Variant: return _public.get("authoritative") if _public is Dictionary else null

	func initialize(owner: Variant, broker_result: Variant, payload: Dictionary) -> Variant:
		_owner = weakref(owner)
		_broker_result = broker_result
		_construction_seal = FACTORY_TOKEN
		_public = payload.duplicate(true)
		_public["execution_id"] = owner.call("_execution_id", payload)
		_sealed_public = _public.duplicate(true)
		return self

	func validate_integrity(owner: Variant) -> bool:
		var actual: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		return owner != null and owner == actual and bool(owner.call("_witness_valid", self))

	func witness_snapshot() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		return _public.duplicate(true) if owner != null and bool(owner.call("_witness_valid", self)) else {}

	func to_public_dict() -> Dictionary: return witness_snapshot()
	func to_dict() -> Dictionary: return witness_snapshot()


class ApplyResult extends RefCounted:
	var _owner: Variant = null
	var _construction_seal: Variant = null
	var _accepted: Variant = false
	var _error_code: Variant = "invalid_applier"
	var _witness: Variant = null
	var _rolled_back: Variant = false
	var _poisoned: Variant = false
	var _sealed_public: Variant = {}

	var accepted: bool: get = _get_accepted
	var error_code: String: get = _get_error_code
	var witness: Variant: get = _get_witness
	var rolled_back: bool: get = _get_rolled_back
	var poisoned: bool: get = _get_poisoned
	func _get_accepted() -> bool: return _accepted if typeof(_accepted) == TYPE_BOOL else false
	func _get_error_code() -> String: return _error_code if typeof(_error_code) == TYPE_STRING else "invalid_applier"
	func _get_witness() -> Variant: return _witness
	func _get_rolled_back() -> bool: return _rolled_back if typeof(_rolled_back) == TYPE_BOOL else false
	func _get_poisoned() -> bool: return _poisoned if typeof(_poisoned) == TYPE_BOOL else false

	func initialize(owner: Variant, accepted_value: bool, code: String, witness_value: Variant, rolled: bool, poison: bool) -> Variant:
		_owner = weakref(owner)
		_construction_seal = FACTORY_TOKEN
		_accepted = accepted_value
		_error_code = code
		_witness = witness_value
		_rolled_back = rolled
		_poisoned = poison
		_sealed_public = owner.call("_result_public", self)
		return self

	func validate_integrity(owner: Variant) -> bool:
		var actual: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		return owner != null and owner == actual and bool(owner.call("_result_valid", self))

	func to_public_dict() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if owner == null or not bool(owner.call("_result_valid", self)):
			return {"accepted": false, "error_code": "invalid_applier", "witness": null, "rolled_back": false, "poisoned": false}
		return owner.call("_result_public", self)

	func to_dict() -> Dictionary: return to_public_dict()


var _ok := false
var _error_code := "applier_contract_error"
var _gate: Variant = null
var _broker: Variant = null
var _state: Variant = "ready"
var _execution_generation: Variant = 0
var _applied_result: Variant = null
var _witness: Variant = null
var _construction_seal: Variant = FACTORY_TOKEN

var contract_hash: String: get = _get_contract_hash
var error_code: String: get = _get_error_code
func _get_contract_hash() -> String: return EXPECTED_BUNDLE_SHA256 if _ok else ""
func _get_error_code() -> String: return _error_code


func _init(gate: Variant = null, broker: Variant = null) -> void:
	_ok = _load_contracts()
	_error_code = "" if _ok else "applier_contract_error"
	_gate = gate
	_broker = broker


func validate_integrity() -> bool:
	if not _structural_valid() or not _exact_script(_gate, GateScript) or not _exact_script(_broker, BrokerScript):
		return false
	return _witness_valid(_witness) if _state == "executed" else true


func audit_snapshot() -> Dictionary:
	if not _structural_valid(): return {}
	var match_generation: Variant = null
	if _exact_script(_gate, GateScript):
		var audit: Dictionary = _gate.audit_snapshot()
		match_generation = audit.get("match_generation")
	return {
		"profile": PROFILE_ID, "state": _state, "execution_generation": _execution_generation,
		"match_generation": match_generation, "executed": _state == "executed", "poisoned": _state == "poisoned",
		"authority": "shadow_engine_command_applier_audit", "authoritative": false,
	}


func apply(broker_result: Variant) -> Variant:
	if not _structural_valid(): return _result(false, "invalid_applier")
	if _state == "poisoned": return _result(false, "rollback_failed", null, false, true)
	if _state != "ready": return _result(false, "already_applied")
	var authority_code := _authority_error()
	if not authority_code.is_empty(): return _result(false, authority_code)
	if not _broker_result_base_valid(broker_result): return _result(false, "invalid_broker_result")
	var prompt: Variant = broker_result.prompt
	if prompt.state != "awaiting_reobserve": return _result(false, "prompt_not_committed")
	if not _committed_payload_valid(broker_result): return _result(false, "invalid_broker_result")
	var resolutions: Array = (broker_result.get("_private_resolutions") as Array).duplicate()
	if resolutions.size() > MAX_RESOLUTION_COUNT:
		_state = "aborted"
		return _result(false, "invalid_command")
	var commands := []
	for resolution: Variant in resolutions:
		commands.append(resolution.private_engine_command)
	for index: int in commands.size():
		for prior: int in index:
			if is_same(commands[index], commands[prior]):
				_state = "aborted"
				return _result(false, "duplicate_command")
	for command: Variant in commands:
		if not _command_protocol_valid(command):
			_state = "aborted"
			return _result(false, "invalid_command")
	var captured := []
	for command: Variant in commands:
		if not _command_protocol_valid(command):
			_state = "aborted"
			return _result(false, "invalid_command")
		var capture: Variant = command.call("shadow_capture")
		if not capture is Dictionary or capture.size() != 2 or not capture.has("ok") or not capture.has("snapshot") or typeof(capture.get("ok")) != TYPE_BOOL or not capture.get("ok"):
			_state = "aborted"
			return _result(false, "capture_failed")
		captured.append([command, capture.get("snapshot")])

	var apply_failed := false
	for item: Variant in captured:
		var command: Variant = item[0]
		if not _command_protocol_valid(command):
			apply_failed = true
			break
		var applied: Variant = command.call("shadow_apply")
		if typeof(applied) != TYPE_BOOL or not applied:
			apply_failed = true
			break
	if apply_failed:
		var restored := true
		for index: int in range(captured.size() - 1, -1, -1):
			var item: Variant = captured[index]
			var command: Variant = item[0]
			if not _command_protocol_valid(command):
				restored = false
				continue
			var restore_result: Variant = command.call("shadow_restore", item[1])
			if typeof(restore_result) != TYPE_BOOL or not restore_result: restored = false
		if restored:
			_state = "aborted"
			return _result(false, "command_apply_failed", null, true, false)
		_state = "poisoned"
		return _result(false, "rollback_failed", null, false, true)

	_execution_generation += 1
	_state = "executed"
	_applied_result = broker_result
	_witness = ExecutedWitness.new().initialize(self, broker_result, _witness_payload(broker_result))
	return _result(true, "", _witness)


func _authority_error() -> String:
	if not _exact_script(_gate, GateScript) or not bool(_gate.validate_integrity()): return "invalid_gate"
	var gate_audit: Dictionary = _gate.audit_snapshot()
	if gate_audit.get("state") != "active" or gate_audit.get("active_mode") != "aligned_shadow": return "owner_mode_not_aligned"
	if not _exact_script(_broker, BrokerScript) or not bool(_broker.validate_integrity()): return "invalid_broker"
	if _gate.get("_active_broker") != _broker or _broker.get("_match_generation") != gate_audit.get("match_generation"): return "broker_not_current"
	return ""


func _broker_result_base_valid(result: Variant) -> bool:
	if result == null or typeof(result) != TYPE_OBJECT or not result.has_method("validate_integrity"): return false
	if not bool(result.validate_integrity(_broker)) or not result.accepted or result.error_code != "": return false
	var prompt: Variant = result.prompt
	return prompt != null and prompt == _broker.current_prompt() and bool(prompt.validate_integrity(_broker))


func _committed_payload_valid(result: Variant) -> bool:
	if not _broker_result_base_valid(result): return false
	var prompt: Variant = result.prompt
	if prompt.state != "awaiting_reobserve": return false
	var resolutions: Variant = result.get("_private_resolutions")
	var committed: Variant = prompt.get("_committed_resolutions")
	if not resolutions is Array or not committed is Array or resolutions.size() != committed.size(): return false
	for index: int in resolutions.size():
		if not is_same(resolutions[index], committed[index]): return false
	var ticket_owner: Variant = prompt.get("_ticket_owner")
	var claim: Variant = prompt.get("_claim_result")
	if ticket_owner == null or claim == null or not claim.has_method("validate_integrity") or not bool(claim.validate_integrity(ticket_owner)): return false
	var ticket: Variant = claim.get("_ticket")
	if ticket == null or not ticket.has_method("validate_integrity") or not bool(ticket.validate_integrity(ticket_owner)): return false
	var indexes: Array = ticket.selected_indexes
	var fingerprints: Array = ticket.selected_fingerprint_hashes
	if resolutions.size() != indexes.size() or indexes.size() != fingerprints.size(): return false
	var window: Variant = prompt.get("_window")
	var window_fingerprints: Variant = window.get("option_fingerprints")
	if not window_fingerprints is Array: return false
	for index: int in resolutions.size():
		var resolution: Variant = resolutions[index]
		if resolution == null or not resolution.has_method("validate_integrity") or not bool(resolution.validate_integrity(prompt.get("_binding_owner"))): return false
		if resolution.option_index != indexes[index]: return false
		if indexes[index] < 0 or indexes[index] >= window_fingerprints.size() or window_fingerprints[indexes[index]] != fingerprints[index]: return false
	return true


func _witness_payload(result: Variant) -> Dictionary:
	var prompt: Variant = result.prompt
	var ticket: Variant = prompt.get("_claim_result").get("_ticket")
	return {
		"profile": PROFILE_ID, "execution_generation": _execution_generation,
		"match_generation": prompt.match_generation, "broker_generation": prompt.broker_generation,
		"decision_generation": prompt.decision_generation, "snapshot_id": prompt.snapshot_id,
		"window_id": prompt.window_id, "public_observation_hash": prompt.public_observation_hash,
		"chooser_player_index": prompt.chooser_player_index, "selected_indexes": ticket.selected_indexes,
		"selected_fingerprint_hashes": ticket.selected_fingerprint_hashes,
		"resolution_count": (result.get("_private_resolutions") as Array).size(), "state": "executed",
		"authority": "shadow_executed_witness_audit", "authoritative": false,
	}


func _execution_id(payload: Dictionary) -> String:
	var canonical := CabtJsonTreeScript.canonicalize_artifact(payload)
	if not bool(canonical.get("ok", false)): return ""
	return _sha(EXECUTION_PREFIX_HEX.hex_decode() + (canonical.get("bytes") as PackedByteArray))


func _witness_valid(witness_value: Variant) -> bool:
	if witness_value == null or not witness_value is ExecutedWitness or witness_value.get("_construction_seal") != FACTORY_TOKEN: return false
	var owner: Variant = (witness_value.get("_owner") as WeakRef).get_ref() if witness_value.get("_owner") is WeakRef else null
	if owner != self or _state != "executed" or _witness != witness_value or _applied_result != witness_value.get("_broker_result"): return false
	var public: Variant = witness_value.get("_public")
	if not public is Dictionary or public != witness_value.get("_sealed_public"): return false
	if public.keys().size() != 16: return false
	var payload: Dictionary = public.duplicate(true)
	var execution_id_value: Variant = payload.get("execution_id")
	payload.erase("execution_id")
	if execution_id_value != _execution_id(payload) or not _upper_sha(execution_id_value): return false
	if public.get("profile") != PROFILE_ID or public.get("state") != "executed" or public.get("authority") != "shadow_executed_witness_audit" or public.get("authoritative") != false: return false
	for value: Variant in [public.get("execution_generation"), public.get("match_generation"), public.get("broker_generation"), public.get("decision_generation")]:
		if not _positive(value): return false
	if public.get("execution_generation") != _execution_generation: return false
	for value: Variant in [public.get("snapshot_id"), public.get("window_id"), public.get("public_observation_hash")]:
		if not _upper_sha(value): return false
	if typeof(public.get("chooser_player_index")) != TYPE_INT or public.get("chooser_player_index") not in [0, 1]: return false
	var indexes: Variant = public.get("selected_indexes")
	var fingerprints: Variant = public.get("selected_fingerprint_hashes")
	if not indexes is Array or not fingerprints is Array or indexes.size() != fingerprints.size() or indexes.size() != public.get("resolution_count") or indexes.size() > MAX_RESOLUTION_COUNT: return false
	var seen_indexes := {}; var seen_fingerprints := {}
	for index: Variant in indexes:
		if not _nonnegative(index) or seen_indexes.has(index): return false
		seen_indexes[index] = true
	for fingerprint: Variant in fingerprints:
		if not _upper_sha(fingerprint) or seen_fingerprints.has(fingerprint): return false
		seen_fingerprints[fingerprint] = true
	return true


func _structural_valid() -> bool:
	if not _ok or _error_code != "" or _construction_seal != FACTORY_TOKEN or not STATES.has(_state) or not _nonnegative(_execution_generation): return false
	if _state == "ready": return _execution_generation == 0 and _applied_result == null and _witness == null
	if _state == "executed": return _execution_generation > 0 and _applied_result != null and _witness is ExecutedWitness
	return _execution_generation == 0 and _applied_result == null and _witness == null


func _result(accepted: bool, code: String, witness_value: Variant = null, rolled: bool = false, poison: bool = false) -> Variant:
	var safe_code := code if code.is_empty() or ERROR_CODES.has(code) else "invalid_applier"
	return ApplyResult.new().initialize(self, accepted, safe_code, witness_value, rolled, poison)


func _result_public(result: Variant) -> Dictionary:
	return {
		"accepted": result.get("_accepted"), "error_code": result.get("_error_code"),
		"witness": result.get("_witness").witness_snapshot() if result.get("_witness") != null else null,
		"rolled_back": result.get("_rolled_back"), "poisoned": result.get("_poisoned"),
	}


func _result_valid(result: Variant) -> bool:
	if not result is ApplyResult or result.get("_construction_seal") != FACTORY_TOKEN: return false
	var owner: Variant = (result.get("_owner") as WeakRef).get_ref() if result.get("_owner") is WeakRef else null
	if owner != self or typeof(result.get("_accepted")) != TYPE_BOOL or typeof(result.get("_error_code")) != TYPE_STRING or typeof(result.get("_rolled_back")) != TYPE_BOOL or typeof(result.get("_poisoned")) != TYPE_BOOL: return false
	if result.get("_accepted"):
		if result.get("_error_code") != "" or result.get("_witness") != _witness or result.get("_rolled_back") or result.get("_poisoned") or not _witness_valid(result.get("_witness")): return false
	else:
		if not ERROR_CODES.has(result.get("_error_code")) or result.get("_witness") != null: return false
		if result.get("_poisoned") != (result.get("_error_code") == "rollback_failed"): return false
		if result.get("_rolled_back") and result.get("_error_code") != "command_apply_failed": return false
	return _result_public(result) == result.get("_sealed_public")


static func _command_protocol_valid(command: Variant) -> bool:
	return command != null and typeof(command) == TYPE_OBJECT and command.has_method("shadow_capture") and command.has_method("shadow_apply") and command.has_method("shadow_restore")


static func _positive(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 1 and value <= SAFE_MAX


static func _nonnegative(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value <= SAFE_MAX


static func _upper_sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64: return false
	for character: String in str(value):
		if not (character >= "0" and character <= "9") and not (character >= "A" and character <= "F"): return false
	return true


static func _exact_script(value: Variant, expected: GDScript) -> bool:
	return value != null and typeof(value) == TYPE_OBJECT and value.get_script() == expected


static func _read_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path): return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


static func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK: return ""
	return context.finish().hex_encode().to_upper()


static func _load_contracts() -> bool:
	var bundle_bytes := _read_bytes(BUNDLE_PATH)
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(bundle_bytes)
	if not bool(canonical.get("ok", false)) or _sha(canonical.get("bytes")) != EXPECTED_BUNDLE_SHA256: return false
	var bundle: Variant = JSON.parse_string(bundle_bytes.get_string_from_utf8())
	if not bundle is Dictionary or bundle.get("contract_id") != PROFILE_ID: return false
	var entries: Variant = bundle.get("artifacts")
	if not entries is Array or entries.size() != 3: return false
	var seen := {}
	for entry: Variant in entries:
		if not entry is Dictionary or not EXPECTED_ARTIFACTS.has(entry.get("id")) or seen.has(entry.get("id")): return false
		var expected: Array = EXPECTED_ARTIFACTS[entry.get("id")]
		if entry != {"id":entry.get("id"),"path":str(expected[0]).trim_prefix("res://"),"canonical_sha256":expected[1]}: return false
		var artifact := CabtJsonTreeScript.canonicalize_artifact_json_bytes(_read_bytes(expected[0]))
		if not bool(artifact.get("ok", false)) or _sha(artifact.get("bytes")) != expected[1]: return false
		seen[entry.get("id")] = true
	if seen.size() != 3: return false
	var profile: Variant = JSON.parse_string(_read_bytes(EXPECTED_ARTIFACTS.profile[0]).get_string_from_utf8())
	if not profile is Dictionary or profile.get("profile_id") != PROFILE_ID: return false
	if profile.get("states") != ["ready","executed","aborted","poisoned"] or profile.get("command_protocol") != ["shadow_capture","shadow_apply","shadow_restore"]: return false
	if profile.get("limits") != {"max_execution_generation_per_applier":1.0,"max_resolution_count":256.0}: return false
	return profile.get("command_protocol_results") == {
		"shadow_capture":{"argument_count":0.0,"result_exact_object_keys":["ok","snapshot"],"ok_exact_boolean":true},
		"shadow_apply":{"argument_count":0.0,"result_exact_boolean":true},
		"shadow_restore":{"argument_count":1.0,"result_exact_boolean":true},
	}
