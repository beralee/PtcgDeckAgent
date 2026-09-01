class_name ShadowMatchOwnerGate
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const BrokerScript = preload("res://scripts/engine/decision/ShadowPromptBroker.gd")

const PROFILE_ID := "ptcgdap-shadow-match-owner-gate-p3-wp6-v1"
const EXPECTED_BUNDLE_SHA256 := "9B8202E67756E388AFB0A13EA1FD20227ADF0718DF8454420A2B1FC7A5D31B8C"
const EXPECTED_ARTIFACTS := {
	"schema": ["res://contracts/ptcgdap/shadow_match_owner_gate.schema.json", "868A042D5FF31C732F121A7783883A2A88A8412A84D8587C3812F6C8D3114B49"],
	"profile": ["res://contracts/ptcgdap/shadow_match_owner_gate_profile.json", "79FE87CC4FE0414CD1EC784293EC788B1D41DCA063A480D5C408FDAFBB643E7F"],
	"vectors": ["res://contracts/ptcgdap/shadow_match_owner_gate_conformance_vectors.json", "C45D001BDFDB73C3BD404A9FB33EF346B6D6253E6750DE5A81F12741BD830E4A"],
}
const BUNDLE_PATH := "res://contracts/ptcgdap/shadow_match_owner_gate_bundle.json"
const SAFE_MAX := 9_007_199_254_740_991
const FACTORY_TOKEN := "shadow-match-owner-gate-owner-factory-v1"
const OWNER_MODES := {"legacy": true, "aligned_shadow": true}
const ERROR_CODES := {
	"invalid_gate": true, "invalid_mode": true, "invalid_match_generation": true,
	"active_match_exists": true, "no_active_match": true, "stale_match_generation": true,
	"broker_required": true, "broker_forbidden": true, "broker_invalid": true,
	"broker_match_generation_mismatch": true, "rollback_already_pending": true,
	"generation_exhausted": true,
}


class GateResult extends RefCounted:
	var _owner: Variant = null
	var _construction_seal: Variant = null
	var _accepted: Variant = false
	var _error_code: Variant = "invalid_gate"
	var _audit: Variant = null
	var _sealed_audit: Variant = null

	var accepted: bool: get = _get_accepted
	var error_code: String: get = _get_error_code
	func _get_accepted() -> bool: return _accepted if typeof(_accepted) == TYPE_BOOL else false
	func _get_error_code() -> String: return _error_code if typeof(_error_code) == TYPE_STRING else "invalid_gate"

	func initialize(owner: Variant, accepted_value: bool, code: String, audit_value: Variant) -> Variant:
		_owner = weakref(owner)
		_construction_seal = FACTORY_TOKEN
		_accepted = accepted_value
		_error_code = code
		_audit = audit_value.duplicate(true) if audit_value is Dictionary else null
		_sealed_audit = _audit.duplicate(true) if _audit is Dictionary else null
		return self

	func validate_integrity(owner: Variant) -> bool:
		var actual: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		return owner != null and owner == actual and bool(owner.call("_result_fields_valid", self))

	func to_public_dict() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if owner == null or not bool(owner.call("_result_fields_valid", self)):
			return {"accepted": false, "error_code": "invalid_gate", "audit": null}
		return {"accepted": _accepted, "error_code": _error_code, "audit": _audit.duplicate(true) if _audit is Dictionary else null}

	func to_dict() -> Dictionary: return to_public_dict()
	func audit_snapshot() -> Dictionary:
		var value: Variant = to_public_dict().get("audit")
		return value if value is Dictionary else {}


var _ok := false
var _error_code := "gate_contract_error"
var _state: Variant = "idle"
var _match_generation: Variant = null
var _last_match_generation: Variant = 0
var _active_mode: Variant = null
var _active_broker: Variant = null
var _rollback_pending: Variant = false
var _rollback_applied: Variant = false
var _gate_generation: Variant = 0
var _construction_seal: Variant = FACTORY_TOKEN

var contract_hash: String: get = _get_contract_hash
var error_code: String: get = _get_error_code
func _get_contract_hash() -> String: return EXPECTED_BUNDLE_SHA256 if _ok else ""
func _get_error_code() -> String: return _error_code


func _init() -> void:
	_ok = _load_contracts()
	_error_code = "" if _ok else "gate_contract_error"


func validate_integrity() -> bool:
	if not _ok or _error_code != "" or _construction_seal != FACTORY_TOKEN:
		return false
	if typeof(_state) != TYPE_STRING or _state not in ["idle", "active", "between_matches"]:
		return false
	if not _nonnegative(_last_match_generation) or not _nonnegative(_gate_generation):
		return false
	if typeof(_rollback_pending) != TYPE_BOOL or typeof(_rollback_applied) != TYPE_BOOL:
		return false
	if _state == "idle":
		return _match_generation == null and _last_match_generation == 0 and _active_mode == null and _active_broker == null and not _rollback_pending and not _rollback_applied
	if _state == "between_matches":
		return _positive(_match_generation) and _match_generation == _last_match_generation and _active_mode == null and _active_broker == null and not _rollback_applied
	if not _positive(_match_generation) or _match_generation != _last_match_generation or typeof(_active_mode) != TYPE_STRING or not OWNER_MODES.has(_active_mode):
		return false
	if _active_mode == "legacy":
		return _active_broker == null
	return _exact_script(_active_broker, BrokerScript) and bool(_active_broker.call("validate_integrity")) and _active_broker.get("_match_generation") == _match_generation and not _rollback_applied


func audit_snapshot() -> Dictionary:
	return _audit().duplicate(true) if validate_integrity() else {}


func begin_match(match_generation: Variant, requested_mode: Variant, broker: Variant = null) -> Variant:
	if not validate_integrity(): return _result(false, "invalid_gate")
	if not _positive(match_generation): return _result(false, "invalid_match_generation")
	if typeof(requested_mode) != TYPE_STRING or not OWNER_MODES.has(requested_mode): return _result(false, "invalid_mode")
	if _state == "active": return _result(false, "active_match_exists")
	if match_generation <= _last_match_generation: return _result(false, "stale_match_generation")
	var forced: bool = _rollback_pending
	var effective_mode: String = "legacy" if forced else requested_mode
	var retained_broker: Variant = null
	if not forced:
		if effective_mode == "legacy":
			if broker != null: return _result(false, "broker_forbidden")
		else:
			if broker == null: return _result(false, "broker_required")
			if not _exact_script(broker, BrokerScript) or not bool(broker.call("validate_integrity")): return _result(false, "broker_invalid")
			if broker.get("_match_generation") != match_generation: return _result(false, "broker_match_generation_mismatch")
			retained_broker = broker
	if _gate_generation >= SAFE_MAX: return _result(false, "generation_exhausted")
	_gate_generation += 1
	_state = "active"
	_match_generation = match_generation
	_last_match_generation = match_generation
	_active_mode = effective_mode
	_active_broker = retained_broker
	_rollback_pending = false
	_rollback_applied = forced
	return _result(true, "")


func current_owner() -> Variant:
	if not validate_integrity(): return _result(false, "invalid_gate")
	if _state != "active": return _result(false, "no_active_match")
	return _result(true, "")


func request_legacy_next_match(match_generation: Variant) -> Variant:
	if not validate_integrity(): return _result(false, "invalid_gate")
	if not _positive(match_generation): return _result(false, "invalid_match_generation")
	if _state != "active": return _result(false, "no_active_match")
	if match_generation != _match_generation: return _result(false, "stale_match_generation")
	if _rollback_pending: return _result(false, "rollback_already_pending")
	if _gate_generation >= SAFE_MAX: return _result(false, "generation_exhausted")
	_gate_generation += 1
	_rollback_pending = true
	return _result(true, "")


func end_match(match_generation: Variant) -> Variant:
	if not validate_integrity(): return _result(false, "invalid_gate")
	if not _positive(match_generation): return _result(false, "invalid_match_generation")
	if _state != "active": return _result(false, "no_active_match")
	if match_generation != _match_generation: return _result(false, "stale_match_generation")
	if _gate_generation >= SAFE_MAX: return _result(false, "generation_exhausted")
	_gate_generation += 1
	_state = "between_matches"
	_active_mode = null
	_active_broker = null
	_rollback_applied = false
	return _result(true, "")


func _audit() -> Dictionary:
	return {
		"profile": PROFILE_ID, "gate_generation": _gate_generation, "state": _state,
		"match_generation": _match_generation, "active_mode": _active_mode,
		"rollback_pending": _rollback_pending, "next_forced_mode": "legacy" if _rollback_pending else null,
		"rollback_applied": _rollback_applied, "authority": "shadow_match_owner_gate_audit", "authoritative": false,
	}


func _result(accepted: bool, code: String) -> Variant:
	var audit: Variant = _audit() if validate_integrity() else null
	return GateResult.new().initialize(self, accepted, code, audit)


func _result_fields_valid(result: Variant) -> bool:
	if result == null or result.get("_construction_seal") != FACTORY_TOKEN: return false
	var owner: Variant = (result.get("_owner") as WeakRef).get_ref() if result.get("_owner") is WeakRef else null
	if owner != self or typeof(result.get("_accepted")) != TYPE_BOOL or typeof(result.get("_error_code")) != TYPE_STRING: return false
	var accepted: bool = result.get("_accepted")
	var code: String = result.get("_error_code")
	var audit: Variant = result.get("_audit")
	if accepted:
		if code != "" or not audit is Dictionary: return false
	elif not ERROR_CODES.has(code) or (audit != null and not audit is Dictionary):
		return false
	return audit == result.get("_sealed_audit")


static func _positive(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 1 and value <= SAFE_MAX


static func _nonnegative(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value <= SAFE_MAX


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
	return profile is Dictionary and profile.get("profile_id") == PROFILE_ID and profile.get("owner_modes") == ["legacy", "aligned_shadow"] and profile.get("states") == ["idle", "active", "between_matches"]
