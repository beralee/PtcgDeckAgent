class_name ShadowWholeMatchHarness
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const GateScript = preload("res://scripts/engine/decision/ShadowMatchOwnerGate.gd")
const BrokerScript = preload("res://scripts/engine/decision/ShadowPromptBroker.gd")
const ApplierScript = preload("res://scripts/engine/decision/ShadowEngineCommandApplier.gd")

const PROFILE_ID := "ptcgdap-shadow-whole-match-harness-p3-wp8-v1"
const EXPECTED_BUNDLE_SHA256 := "0C5A8FDAB61A73F623EA6B0D364C38E6C4797087287B3DF3C88D0191261296B5"
const EXPECTED_ARTIFACTS := {
	"schema": ["res://contracts/ptcgdap/shadow_whole_match_harness.schema.json", "C0CF02191EED9556A282061526E99B6A0C1196B4024918AA9298A32838A93A1B"],
	"profile": ["res://contracts/ptcgdap/shadow_whole_match_harness_profile.json", "D47B6FA345B3F7A4E2955BF0812D63CC625A9A868F5D556108B581C55244BE81"],
	"vectors": ["res://contracts/ptcgdap/shadow_whole_match_harness_conformance_vectors.json", "4ABB41F847B0DA65DD9322F859D0F32B766E4A39E6ED6F3F5AB5CAA4EE7E3CF9"],
}
const BUNDLE_PATH := "res://contracts/ptcgdap/shadow_whole_match_harness_bundle.json"
const SAFE_MAX := 9_007_199_254_740_991
const MAX_PROMPT_COUNT := 64
const FACTORY_TOKEN := "shadow-whole-match-harness-owner-factory-v1"
const STATES := {"ready":true,"active":true,"completed":true,"faulted":true,"dirty":true,"rollback_verified":true}
const ERROR_CODES := {
	"invalid_harness":true,"invalid_gate":true,"owner_mode_not_aligned":true,"invalid_broker":true,
	"broker_not_current":true,"already_started":true,"not_started":true,"match_terminal":true,
	"invalid_broker_result":true,"stale_prompt_chain":true,"prompt_limit_exceeded":true,
	"prompt_apply_failed":true,"dirty_game_detected":true,"rollback_request_failed":true,
	"match_end_failed":true,"rollback_not_required":true,"invalid_match_generation":true,
	"next_match_rollback_failed":true,
}
const FAULT_CODES := {
	"":true,"capture_failed":true,"command_apply_failed":true,"rollback_failed":true,
	"invalid_broker_result":true,"stale_prompt_chain":true,"prompt_limit_exceeded":true,
}


class MatchResult extends RefCounted:
	var _owner: Variant = null
	var _construction_seal: Variant = null
	var _accepted: Variant = false
	var _error_code: Variant = "invalid_harness"
	var _report: Variant = {}
	var _sealed_public: Variant = {}

	var accepted: bool: get = _get_accepted
	var error_code: String: get = _get_error_code
	func _get_accepted() -> bool: return _accepted if typeof(_accepted) == TYPE_BOOL else false
	func _get_error_code() -> String: return _error_code if typeof(_error_code) == TYPE_STRING else "invalid_harness"

	func initialize(owner: Variant, accepted_value: bool, code: String, report: Dictionary) -> Variant:
		_owner = weakref(owner)
		_construction_seal = FACTORY_TOKEN
		_accepted = accepted_value
		_error_code = code
		_report = report.duplicate(true)
		_sealed_public = {"accepted":_accepted,"error_code":_error_code,"report":_report.duplicate(true)}
		return self

	func validate_integrity(owner: Variant) -> bool:
		var actual: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		return owner != null and owner == actual and bool(owner.call("_result_valid", self))

	func to_public_dict() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if owner == null or not bool(owner.call("_result_valid", self)):
			return {"accepted":false,"error_code":"invalid_harness","report":{}}
		return _sealed_public.duplicate(true)

	func to_dict() -> Dictionary: return to_public_dict()


var _ok := false
var _error_code := "harness_contract_error"
var _gate: Variant = null
var _broker: Variant = null
var _state: Variant = "ready"
var _match_generation: Variant = null
var _records: Variant = []
var _fault_code: Variant = ""
var _dirty: Variant = false
var _rollback_requested: Variant = false
var _match_ended: Variant = false
var _next_match_mode: Variant = null
var _construction_seal: Variant = FACTORY_TOKEN
var _state_digest: Variant = ""

var contract_hash: String: get = _get_contract_hash
var error_code: String: get = _get_error_code
func _get_contract_hash() -> String: return EXPECTED_BUNDLE_SHA256 if _ok else ""
func _get_error_code() -> String: return _error_code


func _init(gate: Variant = null, broker: Variant = null) -> void:
	_ok = _load_contracts()
	_error_code = "" if _ok else "harness_contract_error"
	_gate = gate
	_broker = broker
	_state_digest = _digest()


func start() -> Variant:
	if not validate_integrity(): return _result(false, "invalid_harness")
	if _state != "ready": return _result(false, "already_started")
	var code := _authority_error()
	if not code.is_empty(): return _result(false, code)
	_match_generation = _gate.audit_snapshot().get("match_generation")
	_state = "active"
	_reseal()
	return _result(true, "")


func apply_prompt(broker_result: Variant) -> Variant:
	if not validate_integrity(): return _result(false, "invalid_harness")
	if _state == "ready": return _result(false, "not_started")
	if _state != "active": return _result(false, "match_terminal")
	var code := _authority_error()
	if not code.is_empty(): return _terminal_fault("invalid_broker_result", code)
	if _records.size() >= MAX_PROMPT_COUNT: return _terminal_fault("prompt_limit_exceeded", "prompt_limit_exceeded")
	if not _broker_result_valid(broker_result): return _terminal_fault("invalid_broker_result", "invalid_broker_result")
	var prompt: Variant = broker_result.prompt
	if prompt.state != "awaiting_reobserve": return _terminal_fault("invalid_broker_result", "invalid_broker_result")
	var public: Variant = broker_result.to_public_dict()
	var audit: Variant = public.get("audit") if public is Dictionary else null
	if not audit is Dictionary: return _terminal_fault("invalid_broker_result", "invalid_broker_result")
	var candidate := {
		"broker_generation":audit.get("broker_generation"),"decision_generation":audit.get("decision_generation"),
		"snapshot_id":audit.get("snapshot_id"),"window_id":audit.get("window_id"),
	}
	if not _candidate_chain_valid(candidate): return _terminal_fault("stale_prompt_chain", "stale_prompt_chain")
	var applier: Variant = ApplierScript.new(_gate, _broker)
	var applied: Variant = applier.apply(broker_result)
	if not applied.accepted:
		var fault: String = applied.error_code if applied.error_code in ["capture_failed","command_apply_failed","rollback_failed"] else "invalid_broker_result"
		return _terminal_fault(fault, "dirty_game_detected" if applied.poisoned else "prompt_apply_failed", applied.poisoned)
	var witness: Variant = applied.witness
	if witness == null or not bool(witness.validate_integrity(applier)): return _terminal_fault("invalid_broker_result", "invalid_broker_result")
	var witness_public: Dictionary = witness.witness_snapshot()
	var record := candidate.duplicate(true)
	record["execution_id"] = witness_public.get("execution_id")
	if not _record_valid(record): return _terminal_fault("invalid_broker_result", "invalid_broker_result")
	_records.append(record.duplicate(true))
	_reseal()
	return _result(true, "")


func finish_match() -> Variant:
	if not validate_integrity(): return _result(false, "invalid_harness")
	if _state == "ready": return _result(false, "not_started")
	if _match_ended or _state in ["completed","rollback_verified"]: return _result(false, "match_terminal")
	var ended: Variant = _gate.end_match(_match_generation)
	if not ended.accepted or not bool(ended.validate_integrity(_gate)): return _result(false, "match_end_failed")
	_match_ended = true
	if _state == "active": _state = "completed"
	_reseal()
	return _result(true, "")


func verify_next_match_rollback(next_match_generation: Variant) -> Variant:
	if not validate_integrity(): return _result(false, "invalid_harness")
	if _state not in ["faulted","dirty"] or not _rollback_requested: return _result(false, "rollback_not_required")
	if not _match_ended: return _result(false, "match_end_failed")
	if not _positive(next_match_generation) or next_match_generation <= _match_generation: return _result(false, "invalid_match_generation")
	var begun: Variant = _gate.begin_match(next_match_generation, "aligned_shadow")
	var audit: Dictionary = _gate.audit_snapshot()
	if not begun.accepted or not bool(begun.validate_integrity(_gate)) or audit.get("active_mode") != "legacy" or audit.get("rollback_applied") != true:
		return _result(false, "next_match_rollback_failed")
	_state = "rollback_verified"
	_next_match_mode = "legacy"
	_reseal()
	return _result(true, "")


func validate_integrity() -> bool:
	return _structural_valid() and _upper_sha(_state_digest) and _digest() == _state_digest


func audit_snapshot() -> Dictionary:
	return _report() if validate_integrity() else _empty_report()


func _authority_error() -> String:
	if not _exact_script(_gate, GateScript) or not bool(_gate.validate_integrity()): return "invalid_gate"
	var audit: Dictionary = _gate.audit_snapshot()
	if audit.get("state") != "active" or audit.get("active_mode") != "aligned_shadow": return "owner_mode_not_aligned"
	if not _exact_script(_broker, BrokerScript) or not bool(_broker.validate_integrity()): return "invalid_broker"
	if _gate.get("_active_broker") != _broker or _broker.get("_match_generation") != audit.get("match_generation"): return "broker_not_current"
	if _match_generation != null and _match_generation != audit.get("match_generation"): return "invalid_gate"
	return ""


func _broker_result_valid(result: Variant) -> bool:
	if result == null or typeof(result) != TYPE_OBJECT or not result.has_method("validate_integrity"): return false
	if not bool(_broker.call("_result_fields_valid", result)): return false
	if not bool(result.validate_integrity(_broker)) or not result.accepted or result.error_code != "": return false
	var prompt: Variant = result.prompt
	return prompt != null and prompt == _broker.current_prompt() and bool(prompt.validate_integrity(_broker))


func _terminal_fault(fault: String, code: String, dirty := false) -> Variant:
	_fault_code = fault if FAULT_CODES.has(fault) and not fault.is_empty() else "invalid_broker_result"
	_dirty = dirty
	_state = "dirty" if dirty else "faulted"
	var requested: Variant = _gate.request_legacy_next_match(_match_generation)
	if not requested.accepted or not bool(requested.validate_integrity(_gate)):
		_dirty = true
		_state = "dirty"
		_fault_code = "rollback_failed"
		_rollback_requested = true
		_reseal()
		return _result(false, "rollback_request_failed")
	_rollback_requested = true
	_reseal()
	return _result(false, code)


func _candidate_chain_valid(candidate: Dictionary) -> bool:
	if not _positive(candidate.get("broker_generation")) or not _positive(candidate.get("decision_generation")): return false
	if not _upper_sha(candidate.get("snapshot_id")) or not _upper_sha(candidate.get("window_id")): return false
	if _records.is_empty(): return true
	var prior: Dictionary = _records[-1]
	if candidate.broker_generation <= prior.broker_generation or candidate.decision_generation <= prior.decision_generation: return false
	for record: Variant in _records:
		if candidate.snapshot_id == record.snapshot_id or candidate.window_id == record.window_id: return false
	return true


func _structural_valid() -> bool:
	if not _ok or _error_code != "" or _construction_seal != FACTORY_TOKEN or typeof(_state) != TYPE_STRING or not STATES.has(_state): return false
	if not _records is Array or _records.size() > MAX_PROMPT_COUNT: return false
	var brokers := []; var decisions := []; var snapshots := {}; var windows := {}; var executions := {}
	for value: Variant in _records:
		if not _record_valid(value): return false
		var record: Dictionary = value
		if snapshots.has(record.snapshot_id) or windows.has(record.window_id) or executions.has(record.execution_id): return false
		if not brokers.is_empty() and (record.broker_generation <= brokers[-1] or record.decision_generation <= decisions[-1]): return false
		brokers.append(record.broker_generation); decisions.append(record.decision_generation)
		snapshots[record.snapshot_id]=true; windows[record.window_id]=true; executions[record.execution_id]=true
	if typeof(_fault_code) != TYPE_STRING or not FAULT_CODES.has(_fault_code) or typeof(_dirty) != TYPE_BOOL or typeof(_rollback_requested) != TYPE_BOOL or typeof(_match_ended) != TYPE_BOOL: return false
	if _next_match_mode != null and _next_match_mode != "legacy": return false
	if _state == "ready": return _match_generation == null and _records.is_empty() and _fault_code == "" and not _dirty and not _rollback_requested and not _match_ended and _next_match_mode == null
	if not _positive(_match_generation): return false
	if _state == "active": return _fault_code == "" and not _dirty and not _rollback_requested and not _match_ended and _next_match_mode == null
	if _state == "completed": return _fault_code == "" and not _dirty and not _rollback_requested and _match_ended and _next_match_mode == null
	if _state == "faulted": return _fault_code not in ["","rollback_failed"] and not _dirty and _rollback_requested and _next_match_mode == null
	if _state == "dirty": return _fault_code == "rollback_failed" and _dirty and _rollback_requested and _next_match_mode == null
	return _state == "rollback_verified" and _fault_code != "" and _rollback_requested and _match_ended and _next_match_mode == "legacy"


func _state_payload() -> Dictionary:
	return {"state":_state,"match_generation":_match_generation,"records":_records.duplicate(true),"fault_code":_fault_code,"dirty":_dirty,"rollback_requested":_rollback_requested,"match_ended":_match_ended,"next_match_mode":_next_match_mode}


func _digest() -> String:
	var canonical := CabtJsonTreeScript.canonicalize_artifact(_state_payload())
	return _sha(canonical.get("bytes")) if bool(canonical.get("ok", false)) else ""


func _reseal() -> void: _state_digest = _digest()


func _report() -> Dictionary:
	var brokers := []; var decisions := []; var snapshots := []; var windows := []; var executions := []
	for value: Variant in _records:
		var record: Dictionary = value
		brokers.append(record.broker_generation); decisions.append(record.decision_generation)
		snapshots.append(record.snapshot_id); windows.append(record.window_id); executions.append(record.execution_id)
	return {
		"profile":PROFILE_ID,"state":_state,"match_generation":_match_generation,"prompt_count":_records.size(),
		"broker_generations":brokers,"decision_generations":decisions,"snapshot_ids":snapshots,"window_ids":windows,"execution_ids":executions,
		"fault_code":_fault_code,"dirty":_dirty,"rollback_requested":_rollback_requested,"match_ended":_match_ended,
		"next_match_mode":_next_match_mode,"authority":"shadow_whole_match_report_audit","authoritative":false,
	}


func _empty_report() -> Dictionary:
	return {"profile":PROFILE_ID,"state":"ready","match_generation":null,"prompt_count":0,"broker_generations":[],"decision_generations":[],"snapshot_ids":[],"window_ids":[],"execution_ids":[],"fault_code":"","dirty":false,"rollback_requested":false,"match_ended":false,"next_match_mode":null,"authority":"shadow_whole_match_report_audit","authoritative":false}


func _report_valid(report: Variant) -> bool:
	if not report is Dictionary or report.keys().size() != _empty_report().keys().size(): return false
	for key: Variant in _empty_report():
		if not report.has(key): return false
	if report.get("profile") != PROFILE_ID or not STATES.has(report.get("state")) or report.get("authority") != "shadow_whole_match_report_audit" or report.get("authoritative") != false: return false
	var count: Variant = report.get("prompt_count")
	if typeof(count) != TYPE_INT or count < 0 or count > MAX_PROMPT_COUNT: return false
	var arrays := []
	for key: String in ["broker_generations","decision_generations","snapshot_ids","window_ids","execution_ids"]:
		var array: Variant = report.get(key)
		if not array is Array or array.size() != count: return false
		var seen := {}
		for item: Variant in array:
			if seen.has(item): return false
			seen[item] = true
		arrays.append(array)
	for value: Variant in arrays[0] + arrays[1]:
		if not _positive(value): return false
	for value: Variant in arrays[2] + arrays[3] + arrays[4]:
		if not _upper_sha(value): return false
	return FAULT_CODES.has(report.get("fault_code")) and typeof(report.get("dirty")) == TYPE_BOOL and typeof(report.get("rollback_requested")) == TYPE_BOOL and typeof(report.get("match_ended")) == TYPE_BOOL and report.get("next_match_mode") in [null,"legacy"] and (report.get("match_generation") == null or _positive(report.get("match_generation")))


func _result(accepted: bool, code: String) -> Variant:
	var safe_code := code if code.is_empty() or ERROR_CODES.has(code) else "invalid_harness"
	return MatchResult.new().initialize(self, accepted, safe_code, _report() if _structural_valid() else _empty_report())


func _result_valid(result: Variant) -> bool:
	if not result is MatchResult or result.get("_construction_seal") != FACTORY_TOKEN: return false
	var owner: Variant = (result.get("_owner") as WeakRef).get_ref() if result.get("_owner") is WeakRef else null
	if owner != self or typeof(result.get("_accepted")) != TYPE_BOOL or typeof(result.get("_error_code")) != TYPE_STRING: return false
	var accepted: bool = result.get("_accepted")
	var code: String = result.get("_error_code")
	if accepted != code.is_empty() or (not accepted and not ERROR_CODES.has(code)): return false
	var report: Variant = result.get("_report")
	if not _report_valid(report): return false
	return result.get("_sealed_public") == {"accepted":accepted,"error_code":code,"report":report}


static func _record_valid(record: Variant) -> bool:
	if not record is Dictionary or record.keys().size() != 5: return false
	for key: String in ["broker_generation","decision_generation","snapshot_id","window_id","execution_id"]:
		if not record.has(key): return false
	return _positive(record.broker_generation) and _positive(record.decision_generation) and _upper_sha(record.snapshot_id) and _upper_sha(record.window_id) and _upper_sha(record.execution_id)


static func _positive(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 1 and value <= SAFE_MAX


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
	if bundle.get("parent_applier_bundle_canonical_sha256") != "7539A9D5120666AEBA1325DD6623F437831A024996BD612F3EC677F78C9F8F4C": return false
	if bundle.get("parent_owner_gate_bundle_canonical_sha256") != "9B8202E67756E388AFB0A13EA1FD20227ADF0718DF8454420A2B1FC7A5D31B8C": return false
	if bundle.get("parent_prompt_broker_bundle_canonical_sha256") != "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E": return false
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
	if profile.get("states") != ["ready","active","completed","faulted","dirty","rollback_verified"]: return false
	if profile.get("limits") != {"max_prompt_count":64.0}: return false
	return profile.get("parent_applier_bundle_canonical_sha256") == "7539A9D5120666AEBA1325DD6623F437831A024996BD612F3EC677F78C9F8F4C" and profile.get("parent_owner_gate_bundle_canonical_sha256") == "9B8202E67756E388AFB0A13EA1FD20227ADF0718DF8454420A2B1FC7A5D31B8C" and profile.get("parent_prompt_broker_bundle_canonical_sha256") == "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E"
