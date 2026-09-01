class_name ShadowPromptBroker
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const WindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")
const FallbackScript = preload("res://scripts/ai/ptcgdap/cabt/CabtDeterministicFallback.gd")
const PortScript = preload("res://scripts/engine/decision/EngineDecisionPort.gd")
const BindingScript = preload("res://scripts/engine/decision/GodotOptionBinding.gd")
const TicketScript = preload("res://scripts/engine/decision/GodotActionTicket.gd")
const ExecutorScript = preload("res://scripts/engine/decision/GodotActionExecutor.gd")

const PROFILE_ID := "ptcgdap-shadow-prompt-broker-p3-wp5-v1"
const EXPECTED_BUNDLE_SHA256 := "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E"
const EXPECTED_ARTIFACTS := {
	"schema": ["res://contracts/ptcgdap/shadow_prompt_broker.schema.json", "B580E5F4605F12D8C773C7D61CA75BFBB9D3524918CD16E74725FFD13205F956"],
	"profile": ["res://contracts/ptcgdap/shadow_prompt_broker_profile.json", "E77469206464EF3E38784EC031615B35DC56A1608A8205910E5400C3218E6735"],
	"vectors": ["res://contracts/ptcgdap/shadow_prompt_broker_conformance_vectors.json", "AB317B735EA57C19440275A263F9BFD4ABAFE78DD606AB461947DF5CAB08AA49"],
}
const BUNDLE_PATH := "res://contracts/ptcgdap/shadow_prompt_broker_bundle.json"
const SAFE_MAX := 9_007_199_254_740_991
const FACTORY_TOKEN := "shadow-prompt-broker-owner-factory-v1"


class PromptHandle extends RefCounted:
	var _owner: Variant = null
	var _construction_seal: Variant = null
	var _prompt_family: Variant = ""
	var _broker_generation: Variant = 0
	var _match_generation: Variant = 0
	var _decision_generation: Variant = 0
	var _snapshot_id: Variant = ""
	var _window_id: Variant = ""
	var _public_observation_hash: Variant = ""
	var _chooser_player_index: Variant = -1
	var _state: Variant = "open"
	var _port: Variant = null
	var _snapshot: Variant = null
	var _binding_owner: Variant = null
	var _binding: Variant = null
	var _window: Variant = null
	var _current_source: Variant = null
	var _callback_hash: Variant = ""
	var _ticket_owner: Variant = null
	var _claim_result: Variant = null
	var _executor: Variant = null
	var _preflight: Variant = null
	var _committed_resolutions: Variant = []

	var prompt_family: Variant: get = _get_prompt_family
	var broker_generation: Variant: get = _get_broker_generation
	var match_generation: Variant: get = _get_match_generation
	var decision_generation: Variant: get = _get_decision_generation
	var snapshot_id: Variant: get = _get_snapshot_id
	var window_id: Variant: get = _get_window_id
	var public_observation_hash: Variant: get = _get_public_hash
	var chooser_player_index: Variant: get = _get_chooser
	var state: Variant: get = _get_state

	func _get_prompt_family() -> Variant: return _prompt_family
	func _get_broker_generation() -> Variant: return _broker_generation
	func _get_match_generation() -> Variant: return _match_generation
	func _get_decision_generation() -> Variant: return _decision_generation
	func _get_snapshot_id() -> Variant: return _snapshot_id
	func _get_window_id() -> Variant: return _window_id
	func _get_public_hash() -> Variant: return _public_observation_hash
	func _get_chooser() -> Variant: return _chooser_player_index
	func _get_state() -> Variant: return _state

	func initialize(owner: Variant, family: String, generation: int, values: Dictionary) -> Variant:
		_owner = weakref(owner)
		_construction_seal = FACTORY_TOKEN
		_prompt_family = family
		_broker_generation = generation
		_port = values.port
		_snapshot = values.snapshot
		_binding_owner = values.binding_owner
		_binding = values.binding
		_window = values.window
		_current_source = values.current_source
		_callback_hash = values.callback_binding_hash
		_match_generation = _snapshot.match_generation
		_decision_generation = _snapshot.decision_generation
		_snapshot_id = _snapshot.snapshot_id
		_window_id = _window.window_id
		_public_observation_hash = _window.public_observation_hash
		_chooser_player_index = _window.chooser_player_index
		_state = "open"
		_committed_resolutions = []
		return self

	func validate_integrity(owner: Variant) -> bool:
		var actual: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		return owner != null and owner == actual and bool(owner.call("_prompt_fields_valid", self))

	func to_public_dict() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		return owner.call("_audit", self) if owner != null and bool(owner.call("_prompt_fields_valid", self)) else {}


class BrokerResult extends RefCounted:
	var _owner: Variant = null
	var _construction_seal: Variant = null
	var _accepted := false
	var _error_code := ""
	var _prompt: Variant = null
	var _private_resolutions: Variant = []

	var accepted: bool: get = _get_accepted
	var error_code: String: get = _get_error_code
	var prompt: Variant: get = _get_prompt
	var private_resolutions: Array: get = _get_private_resolutions
	func _get_accepted() -> bool: return _accepted
	func _get_error_code() -> String: return _error_code
	func _get_prompt() -> Variant: return _prompt
	func _get_private_resolutions() -> Array: return _private_resolutions.duplicate() if _private_resolutions is Array else []

	func initialize(owner: Variant, accepted_value: bool, code: String, prompt_value: Variant, resolutions: Array = []) -> Variant:
		_owner = weakref(owner)
		_construction_seal = FACTORY_TOKEN
		_accepted = accepted_value
		_error_code = code
		_prompt = prompt_value
		_private_resolutions = resolutions.duplicate()
		return self

	func validate_integrity(owner: Variant) -> bool:
		var actual: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		return owner != null and owner == actual and bool(owner.call("_result_fields_valid", self))

	func to_public_dict() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if owner == null or not bool(owner.call("_result_fields_valid", self)):
			return {"accepted": false, "error_code": "invalid_broker", "audit": null}
		return {"accepted": _accepted, "error_code": _error_code, "audit": null if _prompt == null else owner.call("_audit", _prompt)}

	func to_dict() -> Dictionary: return to_public_dict()


var _ok := false
var _error_code := "broker_contract_error"
var _families: Variant = {}
var _error_codes: Variant = {}
var _match_generation: Variant = 0
var _session_id: Variant = ""
var _next_generation: Variant = 1
var _last_decision_generation: Variant = 0
var _port_owner: Variant = null
var _current: Variant = null

var contract_hash: String: get = _get_contract_hash
var error_code: String: get = _get_error_code
func _get_contract_hash() -> String: return EXPECTED_BUNDLE_SHA256 if _ok else ""
func _get_error_code() -> String: return _error_code


func _init(match_generation: Variant = null, session_id: Variant = null) -> void:
	var loaded := _load_contracts()
	_ok = bool(loaded.get("ok", false))
	_error_code = "" if _ok else "broker_contract_error"
	_families = loaded.get("families", {})
	_error_codes = loaded.get("error_codes", {})
	_match_generation = match_generation
	_session_id = session_id


func validate_integrity() -> bool:
	if (
		not _ok or _error_code != "" or not _positive(_match_generation) or not _session(_session_id)
		or typeof(_next_generation) != TYPE_INT or _next_generation < 1 or _next_generation > SAFE_MAX + 1
		or typeof(_last_decision_generation) != TYPE_INT or _last_decision_generation < 0 or _last_decision_generation > SAFE_MAX
		or not _families is Dictionary or not _error_codes is Dictionary
		or (_port_owner != null and not _exact_script(_port_owner, PortScript))
	):
		return false
	return _current == null or _prompt_fields_valid(_current)


func current_prompt() -> Variant:
	return _current


func open_prompt(
	prompt_family: Variant,
	port: Variant,
	snapshot: Variant,
	binding_owner: Variant,
	binding_value: Variant,
	current_source: Variant,
	window: Variant,
	callback_binding_hash: Variant
) -> Variant:
	if not validate_integrity(): return _reject("invalid_broker")
	if typeof(prompt_family) != TYPE_STRING or not _families.has(prompt_family): return _reject("invalid_family")
	if _current is PromptHandle and _current.state in ["open", "prepared"]: return _reject("active_prompt_exists", _current)
	var values := {"port":port,"snapshot":snapshot,"binding_owner":binding_owner,"binding":binding_value,"current_source":current_source,"window":window,"callback_binding_hash":callback_binding_hash}
	var code := _context_error(values)
	if not code.is_empty(): return _reject(code, _current)
	if _port_owner != null and port != _port_owner: return _reject("cross_owner", _current)
	if snapshot.match_generation != _match_generation: return _reject("match_generation_mismatch", _current)
	if snapshot.decision_generation <= _last_decision_generation: return _reject("stale_decision_generation", _current)
	if _current is PromptHandle and (snapshot.snapshot_id == _current.snapshot_id or window.window_id == _current.window_id or binding_value == _current.get("_binding")):
		return _reject("same_window_reused", _current)
	if _next_generation > SAFE_MAX: return _reject("generation_exhausted", _current)
	if _current is PromptHandle: _current.set("_state", "superseded")
	var prompt: Variant = PromptHandle.new().initialize(self, prompt_family, _next_generation, values)
	_next_generation += 1
	_last_decision_generation = snapshot.decision_generation
	if _port_owner == null: _port_owner = port
	_current = prompt
	return BrokerResult.new().initialize(self, true, "", prompt)


func prepare_selection(prompt: Variant, selection_resolution: Variant) -> Variant:
	var code := _prompt_error(prompt)
	if not code.is_empty(): return _reject(code, prompt if prompt is PromptHandle else null)
	if prompt.state == "awaiting_reobserve": return _reject("reobserve_required", prompt)
	if prompt.state != "open": return _reject("prompt_not_current", prompt)
	if not FallbackScript.validate_resolution_integrity(selection_resolution, prompt.get("_window")):
		return _abort(prompt, "selection_invalid")
	var ticket_owner: Variant = TicketScript.new()
	var issued: Variant = ticket_owner.issue(
		_session_id, prompt.public_observation_hash, prompt.get("_binding_owner"), prompt.get("_binding"),
		prompt.get("_port"), prompt.get("_snapshot"), prompt.get("_current_source"), prompt.get("_window"),
		prompt.get("_callback_hash"), selection_resolution
	)
	if not issued.accepted: return _abort(prompt, "ticket_issue_failed")
	var claimed: Variant = ticket_owner.claim(
		issued.ticket, _session_id, prompt.public_observation_hash, prompt.get("_binding_owner"), prompt.get("_binding"),
		prompt.get("_port"), prompt.get("_snapshot"), prompt.get("_current_source"), prompt.get("_window"), prompt.get("_callback_hash")
	)
	if not claimed.accepted: return _abort(prompt, "ticket_claim_failed")
	var executor: Variant = ExecutorScript.new()
	var prepared: Variant = executor.prepare(
		ticket_owner, claimed, prompt.get("_binding_owner"), prompt.get("_binding"), prompt.get("_port"),
		prompt.get("_snapshot"), prompt.get("_current_source"), prompt.get("_window"), prompt.get("_callback_hash")
	)
	if not prepared.accepted or prepared.preflight == null: return _abort(prompt, "preflight_failed")
	prompt.set("_ticket_owner", ticket_owner)
	prompt.set("_claim_result", claimed)
	prompt.set("_executor", executor)
	prompt.set("_preflight", prepared.preflight)
	prompt.set("_state", "prepared")
	return BrokerResult.new().initialize(self, true, "", prompt)


func commit_prompt(prompt: Variant) -> Variant:
	var code := _prompt_error(prompt)
	if not code.is_empty(): return _reject(code, prompt if prompt is PromptHandle else null)
	if prompt.state == "awaiting_reobserve": return _reject("reobserve_required", prompt)
	if prompt.state != "prepared" or prompt.get("_executor") == null or prompt.get("_preflight") == null:
		return _reject("prompt_not_current", prompt)
	var committed: Variant = prompt.get("_executor").commit(
		prompt.get("_preflight"), prompt.get("_ticket_owner"), prompt.get("_binding_owner"), prompt.get("_binding"),
		prompt.get("_port"), prompt.get("_snapshot"), prompt.get("_current_source"), prompt.get("_window"), prompt.get("_callback_hash")
	)
	if not committed.accepted: return _abort(prompt, "commit_failed")
	var resolutions: Array = committed.binding_resolutions
	prompt.set("_committed_resolutions", resolutions.duplicate())
	prompt.set("_state", "awaiting_reobserve")
	return BrokerResult.new().initialize(self, true, "", prompt, resolutions)


func abort_prompt(prompt: Variant) -> Variant:
	var code := _prompt_error(prompt)
	if not code.is_empty(): return _reject(code, prompt if prompt is PromptHandle else null)
	return _abort(prompt, "broker_aborted")


func reset_match(match_generation: Variant, session_id: Variant) -> bool:
	if not _positive(match_generation) or match_generation <= _match_generation or not _session(session_id): return false
	if _current is PromptHandle: _current.set("_state", "superseded")
	_match_generation = match_generation
	_session_id = session_id
	_next_generation = 1
	_last_decision_generation = 0
	_port_owner = null
	_current = null
	return true


func _context_error(values: Dictionary) -> String:
	var port: Variant = values.port
	var snapshot: Variant = values.snapshot
	var owner: Variant = values.binding_owner
	var binding_value: Variant = values.binding
	var window: Variant = values.window
	if not _exact_script(port, PortScript) or not _exact_script(owner, BindingScript) or not _exact_script(window, WindowScript): return "invalid_context"
	if snapshot == null or typeof(snapshot) != TYPE_OBJECT or not bool(snapshot.validate_integrity(port)) or port.current_snapshot() != snapshot: return "invalid_context"
	if binding_value == null or typeof(binding_value) != TYPE_OBJECT or owner.current_binding() != binding_value or not bool(binding_value.validate_integrity(owner)): return "invalid_context"
	var state: Variant = owner.get("_current")
	if not state is Dictionary or state.get("port") != port or state.get("snapshot") != snapshot or state.get("window") != window or state.get("binding") != binding_value or state.get("callback_binding_hash") != values.callback_binding_hash:
		return "invalid_context"
	if binding_value.snapshot_id != snapshot.snapshot_id or binding_value.window_id != window.window_id or binding_value.public_observation_hash != window.public_observation_hash or binding_value.chooser_player_index != window.chooser_player_index:
		return "invalid_context"
	var rebound: Dictionary = port.rebind(snapshot, values.current_source)
	return "" if bool(rebound.get("ok", false)) else "invalid_context"


func _prompt_error(prompt: Variant) -> String:
	if not prompt is PromptHandle: return "prompt_integrity_invalid"
	var owner: Variant = (prompt.get("_owner") as WeakRef).get_ref() if prompt.get("_owner") is WeakRef else null
	if owner != self: return "cross_owner"
	if prompt.match_generation != _match_generation: return "match_generation_mismatch"
	if prompt != _current: return "prompt_not_current"
	return "" if _prompt_fields_valid(prompt) else "prompt_integrity_invalid"


func _prompt_fields_valid(prompt: Variant) -> bool:
	if not prompt is PromptHandle or prompt.get("_construction_seal") != FACTORY_TOKEN: return false
	var owner: Variant = (prompt.get("_owner") as WeakRef).get_ref() if prompt.get("_owner") is WeakRef else null
	if owner != self or not _families.has(prompt.prompt_family) or not _positive(prompt.broker_generation) or prompt.match_generation != _match_generation or not _positive(prompt.decision_generation): return false
	if prompt.state not in ["open", "prepared", "awaiting_reobserve", "aborted", "superseded"]: return false
	if not _exact_script(prompt.get("_port"), PortScript) or prompt.get("_port") != _port_owner or not _exact_script(prompt.get("_binding_owner"), BindingScript) or not _exact_script(prompt.get("_window"), WindowScript): return false
	if prompt.get("_snapshot") == null or prompt.get("_binding") == null: return false
	if prompt.snapshot_id != prompt.get("_snapshot").snapshot_id or prompt.window_id != prompt.get("_window").window_id or prompt.public_observation_hash != prompt.get("_window").public_observation_hash: return false
	if prompt.state == "open": return prompt.get("_ticket_owner") == null and prompt.get("_executor") == null and prompt.get("_preflight") == null and (prompt.get("_committed_resolutions") as Array).is_empty()
	if prompt.state == "prepared": return _exact_script(prompt.get("_ticket_owner"), TicketScript) and _exact_script(prompt.get("_executor"), ExecutorScript) and prompt.get("_preflight") != null and bool(prompt.get("_preflight").validate_integrity(prompt.get("_executor"))) and (prompt.get("_committed_resolutions") as Array).is_empty()
	if prompt.state == "awaiting_reobserve": return _exact_script(prompt.get("_executor"), ExecutorScript) and prompt.get("_preflight") != null and prompt.get("_preflight").state == "committed" and prompt.get("_committed_resolutions") is Array
	return prompt.get("_committed_resolutions") is Array


func _result_fields_valid(result: Variant) -> bool:
	if not result is BrokerResult or result.get("_construction_seal") != FACTORY_TOKEN: return false
	var owner: Variant = (result.get("_owner") as WeakRef).get_ref() if result.get("_owner") is WeakRef else null
	if owner != self or not result.get("_private_resolutions") is Array: return false
	if result.accepted:
		return result.error_code == "" and result.prompt is PromptHandle and _prompt_fields_valid(result.prompt)
	return _error_codes.has(result.error_code) and not result.error_code.is_empty() and (result.get("_private_resolutions") as Array).is_empty() and (result.prompt == null or (result.prompt is PromptHandle and _prompt_fields_valid(result.prompt)))


func _audit(prompt: Variant) -> Dictionary:
	var prepared: bool = prompt.state in ["prepared", "awaiting_reobserve"]
	var committed: bool = prompt.state == "awaiting_reobserve"
	return {
		"profile": PROFILE_ID, "prompt_family": prompt.prompt_family, "broker_generation": prompt.broker_generation,
		"match_generation": prompt.match_generation, "decision_generation": prompt.decision_generation,
		"snapshot_id": prompt.snapshot_id, "window_id": prompt.window_id, "public_observation_hash": prompt.public_observation_hash,
		"chooser_player_index": prompt.chooser_player_index, "state": prompt.state,
		"witness": {"accepted": true, "bound": prepared, "committed": committed},
		"resolution_count": (prompt.get("_committed_resolutions") as Array).size() if committed else 0,
		"authority": "shadow_prompt_broker_audit", "authoritative": false,
	}


func _reject(code: String, prompt: Variant = null) -> Variant:
	var safe_code := code if _error_codes.has(code) else "invalid_broker"
	return BrokerResult.new().initialize(self, false, safe_code, prompt)


func _abort(prompt: Variant, code: String) -> Variant:
	if prompt.get("_executor") != null and prompt.get("_preflight") != null and prompt.get("_preflight").state == "prepared":
		prompt.get("_executor").abort(prompt.get("_preflight"))
	prompt.set("_committed_resolutions", [])
	prompt.set("_state", "aborted")
	return _reject(code, prompt)


static func _positive(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 1 and value <= SAFE_MAX


static func _session(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or not str(value).begins_with("session:"): return false
	var suffix := str(value).trim_prefix("session:")
	if suffix.is_empty() or suffix.length() > 64: return false
	for character: String in suffix:
		if not (character >= "a" and character <= "z") and not (character >= "0" and character <= "9") and character not in ["_", "-"]:
			return false
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


static func _load_contracts() -> Dictionary:
	var bundle_bytes := _read_bytes(BUNDLE_PATH)
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(bundle_bytes)
	if not bool(canonical.get("ok", false)) or _sha(canonical.get("bytes")) != EXPECTED_BUNDLE_SHA256: return {"ok": false}
	var bundle: Variant = JSON.parse_string(bundle_bytes.get_string_from_utf8())
	if not bundle is Dictionary or bundle.get("contract_id") != PROFILE_ID: return {"ok": false}
	var entries: Variant = bundle.get("artifacts")
	if not entries is Array or entries.size() != 3: return {"ok": false}
	var seen := {}
	for entry: Variant in entries:
		if not entry is Dictionary or not EXPECTED_ARTIFACTS.has(entry.get("id")) or seen.has(entry.get("id")): return {"ok": false}
		var expected: Array = EXPECTED_ARTIFACTS[entry.get("id")]
		if entry != {"id":entry.get("id"),"path":str(expected[0]).trim_prefix("res://"),"canonical_sha256":expected[1]}: return {"ok": false}
		var artifact := CabtJsonTreeScript.canonicalize_artifact_json_bytes(_read_bytes(expected[0]))
		if not bool(artifact.get("ok", false)) or _sha(artifact.get("bytes")) != expected[1]: return {"ok": false}
		seen[entry.get("id")] = true
	if seen.size() != 3: return {"ok": false}
	var profile: Variant = JSON.parse_string(_read_bytes(EXPECTED_ARTIFACTS.profile[0]).get_string_from_utf8())
	if not profile is Dictionary or profile.get("profile_id") != PROFILE_ID: return {"ok": false}
	if profile.get("prompt_families") != ["W1","W2","W3","W4","W5","W6","W7"]: return {"ok": false}
	var families := {}; var codes := {}
	for family: Variant in profile.get("prompt_families", []): families[family] = true
	for code: Variant in profile.get("error_codes", []):
		if typeof(code) != TYPE_STRING or codes.has(code): return {"ok": false}
		codes[code] = true
	return {"ok": true, "families": families, "error_codes": codes}
