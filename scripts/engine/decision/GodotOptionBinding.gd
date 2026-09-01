class_name GodotOptionBinding
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const PortScript = preload("res://scripts/engine/decision/EngineDecisionPort.gd")
const WindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")

const PROFILE_ID := "ptcgdap-godot-option-binding-p3-wp2-v1"
const EXPECTED_BUNDLE_SHA256 := "4FFFEC48E4E1FE0774BB6E343D4D4B0384A9210057DEE06415C2A20F2899B1C1"
const EXPECTED_ARTIFACTS := {
	"schema": ["res://contracts/ptcgdap/godot_option_binding.schema.json", "FF4CE1D7F1655062E8BD25951E34030582408CBA4990A9E8C34351B68D98614F"],
	"profile": ["res://contracts/ptcgdap/godot_option_binding_profile.json", "2E42620EFF40CEC465FF46B4F252389AABF8D26708B1B93F392FB03D169E71C0"],
	"vectors": ["res://contracts/ptcgdap/godot_option_binding_conformance_vectors.json", "8B13EABF6039F20346D4F52326E4B20CDD6FE000E7F685B7527DB6163F06B40F"],
}
const BUNDLE_PATH := "res://contracts/ptcgdap/godot_option_binding_bundle.json"
const SAFE_MAX := 9_007_199_254_740_991
const MAX_OPTIONS := 256
const MAX_REFS_PER_OPTION := 16
const MAX_TOTAL_REFS := 4096
const SUPPORTED_OPTION_TYPES := {3: true, 7: true, 13: true, 14: true, 15: true}
const P5_EXTENSION_PROFILE_ID := "ptcgdap-marnie-prompt-broker-p5-wp5-v1"
const P5_SUPPORTED_OPTION_TYPES := {3: true, 7: true, 8: true, 12: true, 13: true, 14: true, 15: true}
const ERROR_CODES := {
	"": true,
	"binding_contract_error": true,
	"invalid_port": true,
	"snapshot_not_current": true,
	"snapshot_owner_mismatch": true,
	"snapshot_integrity_invalid": true,
	"source_mutated": true,
	"invalid_window": true,
	"window_mismatch": true,
	"invalid_callback_binding_hash": true,
	"invalid_private_commands": true,
	"invalid_private_object_refs": true,
	"reference_released": true,
	"binding_not_current": true,
	"option_index_invalid": true,
	"binding_integrity_invalid": true,
	"owner_mismatch": true,
}
const AUDIT_KEYS := [
	"binding_profile", "binding_version", "snapshot_id", "window_id",
	"public_observation_hash", "chooser_player_index", "option_count",
	"option_fingerprints", "authority", "authoritative",
]
const RESOLUTION_AUDIT_KEYS := [
	"binding_profile", "binding_version", "snapshot_id", "window_id",
	"option_index", "fingerprint_hash", "authority", "authoritative",
]


class BindingSet extends RefCounted:
	var _owner: Variant = null
	var _binding_version: Variant = 0
	var _snapshot_id: Variant = ""
	var _window_id: Variant = ""
	var _public_observation_hash: Variant = ""
	var _chooser_player_index: Variant = -1
	var _option_count: Variant = 0
	var _option_fingerprints: Variant = []
	var _audit: Variant = {}

	var binding_version: Variant:
		get: return _binding_version
	var snapshot_id: Variant:
		get: return _snapshot_id
	var window_id: Variant:
		get: return _window_id
	var public_observation_hash: Variant:
		get: return _public_observation_hash
	var chooser_player_index: Variant:
		get: return _chooser_player_index
	var option_count: Variant:
		get: return _option_count
	var option_fingerprints: Array:
		get: return _option_fingerprints.duplicate(true) if _option_fingerprints is Array else []

	func initialize(owner: Variant, version: int, snapshot_value: Variant, window: Variant, audit: Dictionary) -> Variant:
		_owner = weakref(owner)
		_binding_version = version
		_snapshot_id = snapshot_value.get("snapshot_id")
		_window_id = window.get("window_id")
		_public_observation_hash = window.get("public_observation_hash")
		_chooser_player_index = window.get("chooser_player_index")
		_option_count = window.get("option_count")
		_option_fingerprints = window.get("option_fingerprints").duplicate(true)
		_audit = audit.duplicate(true)
		return self

	func validate_integrity(owner: Variant) -> bool:
		var actual_owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		return owner != null and owner == actual_owner and bool(owner.call("_binding_fields_valid", self))

	func to_audit_dict() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if owner == null or not bool(owner.call("_binding_fields_valid", self)):
			return {}
		return _audit.duplicate(true) if _audit is Dictionary else {}

	func to_public_dict() -> Dictionary:
		return to_audit_dict()


class BindResult extends RefCounted:
	var _owner: Variant = null
	var _accepted := false
	var _error_code := ""
	var _binding: Variant = null

	var accepted: bool:
		get: return _accepted
	var error_code: String:
		get: return _error_code
	var binding: Variant:
		get: return _binding

	func initialize(owner: Variant, accepted_value: bool, code: String, binding_value: Variant) -> Variant:
		_owner = weakref(owner)
		_accepted = accepted_value
		_error_code = code
		_binding = binding_value
		return self

	func validate_integrity(owner: Variant) -> bool:
		var actual_owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if owner == null or owner != actual_owner:
			return false
		if _accepted:
			return _error_code == "" and _binding is BindingSet and bool(owner.call("_binding_fields_valid", _binding))
		return _binding == null and not _error_code.is_empty() and ERROR_CODES.has(_error_code)

	func to_public_dict() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if owner == null or not validate_integrity(owner):
			return {"accepted": false, "error_code": "binding_integrity_invalid", "audit": null}
		return {
			"accepted": _accepted,
			"error_code": _error_code,
			"audit": null if _binding == null else _binding.to_audit_dict(),
		}


class Resolution extends RefCounted:
	var _owner: Variant = null
	var _accepted := false
	var _error_code := ""
	var _option_index: Variant = null
	var _private_engine_command: Variant = null
	var _private_object_refs: Variant = []
	var _binding: Variant = null
	var _audit: Variant = null

	var accepted: bool:
		get: return _accepted
	var error_code: String:
		get: return _error_code
	var option_index: Variant:
		get: return _option_index
	var private_engine_command: Variant:
		get: return _private_engine_command
	var private_object_refs: Array:
		get: return _private_object_refs.duplicate() if _private_object_refs is Array else []

	func initialize(
		owner: Variant,
		accepted_value: bool,
		code: String,
		index_value: Variant,
		command: Variant,
		refs: Array,
		binding_value: Variant,
		audit: Variant
	) -> Variant:
		_owner = weakref(owner)
		_accepted = accepted_value
		_error_code = code
		_option_index = index_value
		_private_engine_command = command
		_private_object_refs = refs.duplicate()
		_binding = binding_value
		_audit = audit.duplicate(true) if audit is Dictionary else null
		return self

	func validate_integrity(owner: Variant) -> bool:
		var actual_owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if owner == null or owner != actual_owner:
			return false
		if _accepted:
			return bool(owner.call("_resolution_fields_valid", self))
		return (
			not _error_code.is_empty()
			and ERROR_CODES.has(_error_code)
			and _option_index == null
			and _private_engine_command == null
			and _private_object_refs is Array
			and _private_object_refs.is_empty()
			and _binding == null
			and _audit == null
		)

	func to_public_dict() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if owner == null or not validate_integrity(owner):
			return {"accepted": false, "error_code": "binding_integrity_invalid", "audit": null}
		return {
			"accepted": _accepted,
			"error_code": _error_code,
			"audit": null if _audit == null else (_audit as Dictionary).duplicate(true),
		}


var _ok := false
var _error_code := "binding_contract_error"
var _current: Variant = null
var _last_binding_version := 0

var contract_hash: String:
	get: return EXPECTED_BUNDLE_SHA256 if _ok else ""
var error_code: String:
	get: return _error_code


func _init() -> void:
	var loaded := _load_contracts()
	_ok = bool(loaded.get("ok", false))
	_error_code = "" if _ok else "binding_contract_error"


func validate_integrity() -> bool:
	return (
		_ok
		and _error_code == ""
		and typeof(_last_binding_version) == TYPE_INT
		and _last_binding_version >= 0
		and _last_binding_version <= SAFE_MAX
		and (_current == null or _binding_fields_valid(_current.get("binding")))
	)


func current_binding() -> Variant:
	return null if _current == null else _current.get("binding")


func bind(
	port: Variant,
	snapshot: Variant,
	current_source: Variant,
	window: Variant,
	callback_binding_hash: Variant,
	private_commands: Variant,
	private_object_refs: Variant
) -> Variant:
	return _bind(
		port, snapshot, current_source, window, callback_binding_hash,
		private_commands, private_object_refs, PROFILE_ID
	)


func bind_p5_extended(
	port: Variant,
	snapshot: Variant,
	current_source: Variant,
	window: Variant,
	callback_binding_hash: Variant,
	private_commands: Variant,
	private_object_refs: Variant,
	extension_profile_id: Variant
) -> Variant:
	if typeof(extension_profile_id) != TYPE_STRING or extension_profile_id != P5_EXTENSION_PROFILE_ID:
		return _rejected_bind("window_mismatch")
	return _bind(
		port, snapshot, current_source, window, callback_binding_hash,
		private_commands, private_object_refs, extension_profile_id
	)


func _bind(
	port: Variant,
	snapshot: Variant,
	current_source: Variant,
	window: Variant,
	callback_binding_hash: Variant,
	private_commands: Variant,
	private_object_refs: Variant,
	binding_profile: String
) -> Variant:
	if not _ok:
		return _rejected_bind("binding_contract_error")
	if not _exact_script(port, PortScript):
		return _rejected_bind("invalid_port")
	if snapshot == null or typeof(snapshot) != TYPE_OBJECT:
		return _rejected_bind("snapshot_integrity_invalid")
	var rebound: Dictionary = port.rebind(snapshot, current_source)
	if not bool(rebound.get("ok", false)):
		return _rejected_bind(_map_snapshot_error(rebound.get("error_code")))
	if not _exact_script(window, WindowScript) or not window.validate_integrity():
		return _rejected_bind("invalid_window")
	var source_matches := (
		_source_window_match_p5(rebound.get("value"), window, snapshot)
		if binding_profile == P5_EXTENSION_PROFILE_ID
		else _source_window_match(rebound.get("value"), window, snapshot)
	)
	if not source_matches:
		return _rejected_bind("window_mismatch")
	if not _upper_sha(callback_binding_hash):
		return _rejected_bind("invalid_callback_binding_hash")
	var command_refs: Variant = _command_refs(private_commands, window.option_count)
	if command_refs == null:
		return _rejected_bind("invalid_private_commands")
	var refs: Variant = _private_refs(private_object_refs, window.option_count)
	if refs == null:
		return _rejected_bind("invalid_private_object_refs")
	if _last_binding_version >= SAFE_MAX:
		return _rejected_bind("binding_integrity_invalid")
	var version := _last_binding_version + 1
	var audit := _binding_audit(version, snapshot, window, binding_profile)
	var binding_value: Variant = BindingSet.new().initialize(self, version, snapshot, window, audit)
	var state := {
		"binding": binding_value,
		"binding_version": version,
		"port": port,
		"snapshot": snapshot,
		"window": window,
		"callback_binding_hash": callback_binding_hash,
		"command_refs": command_refs,
		"private_refs": refs,
		"audit": audit.duplicate(true),
		"binding_profile": binding_profile,
	}
	_last_binding_version = version
	_current = state
	return BindResult.new().initialize(self, true, "", binding_value)


func resolve(
	binding_value: Variant,
	port: Variant,
	snapshot: Variant,
	current_source: Variant,
	window: Variant,
	callback_binding_hash: Variant,
	option_index: Variant
) -> Variant:
	if not binding_value is BindingSet:
		return _rejected_resolution("binding_integrity_invalid")
	var owner_ref: Variant = binding_value.get("_owner")
	if not owner_ref is WeakRef or (owner_ref as WeakRef).get_ref() != self:
		return _rejected_resolution("owner_mismatch")
	if _current == null or _current.get("binding") != binding_value:
		return _rejected_resolution("binding_not_current")
	if not _binding_static_fields_valid(binding_value):
		return _rejected_resolution("binding_integrity_invalid")
	if not _exact_script(port, PortScript) or port != _current.get("port"):
		return _rejected_resolution("invalid_port")
	if snapshot == null or snapshot != _current.get("snapshot"):
		return _rejected_resolution("snapshot_not_current")
	var rebound: Dictionary = port.rebind(snapshot, current_source)
	if not bool(rebound.get("ok", false)):
		return _rejected_resolution(_map_snapshot_error(rebound.get("error_code")))
	if not _exact_script(window, WindowScript):
		return _rejected_resolution("invalid_window")
	if window != _current.get("window"):
		return _rejected_resolution("window_mismatch")
	if not window.validate_integrity():
		return _rejected_resolution("invalid_window")
	var source_matches := (
		_source_window_match_p5(rebound.get("value"), window, snapshot)
		if _current.get("binding_profile") == P5_EXTENSION_PROFILE_ID
		else _source_window_match(rebound.get("value"), window, snapshot)
	)
	if not source_matches:
		return _rejected_resolution("window_mismatch")
	if not _upper_sha(callback_binding_hash) or callback_binding_hash != _current.get("callback_binding_hash"):
		return _rejected_resolution("binding_not_current")
	if typeof(option_index) != TYPE_INT or option_index < 0 or option_index >= binding_value.option_count:
		return _rejected_resolution("option_index_invalid")
	var command_ref: Variant = (_current.get("command_refs") as Array)[option_index]
	var command: Variant = (command_ref as WeakRef).get_ref() if command_ref is WeakRef else null
	if command == null:
		return _rejected_resolution("reference_released")
	var objects := []
	for reference: Variant in (_current.get("private_refs") as Array)[option_index]:
		var value: Variant = (reference as WeakRef).get_ref() if reference is WeakRef else null
		if value == null:
			return _rejected_resolution("reference_released")
		objects.append(value)
	var audit := {
		"binding_profile": _current.get("binding_profile"),
		"binding_version": _current.get("binding_version"),
		"snapshot_id": snapshot.get("snapshot_id"),
		"window_id": window.get("window_id"),
		"option_index": option_index,
		"fingerprint_hash": window.get("option_fingerprints")[option_index],
		"authority": "godot_option_resolution_shadow",
		"authoritative": false,
	}
	return Resolution.new().initialize(self, true, "", option_index, command, objects, binding_value, audit)


func _binding_fields_valid(binding_value: Variant) -> bool:
	if not _binding_static_fields_valid(binding_value) or _current == null:
		return false
	var port: Variant = _current.get("port")
	var snapshot: Variant = _current.get("snapshot")
	return port.current_snapshot() == snapshot and snapshot.validate_integrity(port)


func _binding_static_fields_valid(binding_value: Variant) -> bool:
	if not binding_value is BindingSet or _current == null or _current.get("binding") != binding_value:
		return false
	var owner_ref: Variant = binding_value.get("_owner")
	if not owner_ref is WeakRef or (owner_ref as WeakRef).get_ref() != self:
		return false
	var window: Variant = _current.get("window")
	if not _exact_script(window, WindowScript) or not window.validate_integrity():
		return false
	var callback_hash: Variant = _current.get("callback_binding_hash")
	var command_refs: Variant = _current.get("command_refs")
	var private_refs: Variant = _current.get("private_refs")
	if not _upper_sha(callback_hash):
		return false
	if not command_refs is Array or command_refs.size() != window.option_count:
		return false
	for reference: Variant in command_refs:
		if not reference is WeakRef:
			return false
	if not private_refs is Array or private_refs.size() != window.option_count:
		return false
	for group: Variant in private_refs:
		if not group is Array or group.size() > MAX_REFS_PER_OPTION:
			return false
		for reference: Variant in group:
			if not reference is WeakRef:
				return false
	var binding_profile: Variant = _current.get("binding_profile")
	if typeof(binding_profile) != TYPE_STRING or binding_profile not in [PROFILE_ID, P5_EXTENSION_PROFILE_ID]:
		return false
	var expected: Dictionary = _binding_audit(_current.get("binding_version"), _current.get("snapshot"), window, binding_profile)
	var audit: Variant = binding_value.get("_audit")
	return (
		binding_value.binding_version == _current.get("binding_version")
		and binding_value.snapshot_id == _current.get("snapshot").get("snapshot_id")
		and binding_value.window_id == window.window_id
		and binding_value.public_observation_hash == window.public_observation_hash
		and binding_value.chooser_player_index == window.chooser_player_index
		and binding_value.option_count == window.option_count
		and binding_value.option_fingerprints == window.option_fingerprints
		and audit is Dictionary
		and _exact_keys(audit, AUDIT_KEYS)
		and audit == expected
		and _current.get("audit") == expected
	)


func _resolution_fields_valid(result: Variant) -> bool:
	if (
		_current == null
		or result.get("_binding") != _current.get("binding")
		or not _binding_fields_valid(result.get("_binding"))
		or typeof(result.option_index) != TYPE_INT
		or result.option_index < 0
		or result.option_index >= _current.get("binding").option_count
		or result.error_code != ""
	):
		return false
	var audit: Variant = result.get("_audit")
	if not audit is Dictionary or not _exact_keys(audit, RESOLUTION_AUDIT_KEYS):
		return false
	var command_ref: Variant = (_current.get("command_refs") as Array)[result.option_index]
	var command: Variant = (command_ref as WeakRef).get_ref() if command_ref is WeakRef else null
	if command == null or result.private_engine_command != command:
		return false
	var expected_objects := []
	for reference: Variant in (_current.get("private_refs") as Array)[result.option_index]:
		var value: Variant = (reference as WeakRef).get_ref() if reference is WeakRef else null
		if value == null:
			return false
		expected_objects.append(value)
	var window: Variant = _current.get("window")
	var expected_audit := {
		"binding_profile": _current.get("binding_profile"),
		"binding_version": _current.get("binding_version"),
		"snapshot_id": _current.get("snapshot").get("snapshot_id"),
		"window_id": window.window_id,
		"option_index": result.option_index,
		"fingerprint_hash": window.option_fingerprints[result.option_index],
		"authority": "godot_option_resolution_shadow",
		"authoritative": false,
	}
	return result.private_object_refs == expected_objects and audit == expected_audit


func _source_window_match(source: Variant, window: Variant, snapshot: Variant) -> bool:
	if not source is Dictionary or not _exact_script(window, WindowScript):
		return false
	if snapshot.get("chooser_player_index") != window.chooser_player_index:
		return false
	var select_value: Variant = source.get("select")
	if not select_value is Dictionary:
		return false
	var scalar_pairs := {
		"type": window.select_type_raw,
		"context": window.select_context_raw,
		"minCount": window.min_count,
		"maxCount": window.max_count,
		"remainDamageCounter": window.remain_damage_counter,
		"remainEnergyCost": window.remain_energy_cost,
	}
	for key: String in scalar_pairs:
		if select_value.get(key) != scalar_pairs[key]:
			return false
	var source_options: Variant = select_value.get("option")
	var window_options: Array = window.options
	if (
		not source_options is Array
		or source_options.size() != window_options.size()
		or source_options.size() > MAX_OPTIONS
		or window.option_fingerprints.size() != source_options.size()
	):
		return false
	for index: int in range(source_options.size()):
		var source_option: Variant = source_options[index]
		var window_option: Variant = window_options[index]
		if (
			not source_option is Dictionary
			or not window_option is Dictionary
			or typeof(source_option.get("type")) != TYPE_INT
			or not SUPPORTED_OPTION_TYPES.has(source_option.get("type"))
			or source_option.get("type") != window_option.get("type")
		):
			return false
		if source_option.get("type") == 7 and source_option.get("index") != window_option.get("index"):
			return false
	return true


func _source_window_match_p5(source: Variant, window: Variant, snapshot: Variant) -> bool:
	if not source is Dictionary or not _exact_script(window, WindowScript):
		return false
	if snapshot.get("chooser_player_index") != window.chooser_player_index:
		return false
	var select_value: Variant = source.get("select")
	if not select_value is Dictionary:
		return false
	var scalar_pairs := {
		"type": window.select_type_raw,
		"context": window.select_context_raw,
		"minCount": window.min_count,
		"maxCount": window.max_count,
		"remainDamageCounter": window.remain_damage_counter,
		"remainEnergyCost": window.remain_energy_cost,
	}
	for key: String in scalar_pairs:
		if typeof(select_value.get(key)) != TYPE_INT or select_value.get(key) != scalar_pairs[key]:
			return false
	var source_options: Variant = select_value.get("option")
	var window_options: Array = window.options
	if (
		not source_options is Array
		or source_options.size() != window_options.size()
		or source_options.size() > MAX_OPTIONS
		or window.option_fingerprints.size() != source_options.size()
	):
		return false
	for index: int in range(source_options.size()):
		var source_option: Variant = source_options[index]
		var window_option: Variant = window_options[index]
		if (
			not source_option is Dictionary
			or not window_option is Dictionary
			or typeof(source_option.get("type")) != TYPE_INT
			or not P5_SUPPORTED_OPTION_TYPES.has(source_option.get("type"))
			or source_option.get("type") != window_option.get("type")
		):
			return false
		var option_type: int = source_option.get("type")
		if option_type == 7 and source_option.get("index") != window_option.get("index"):
			return false
		if option_type == 8:
			for field_name: String in ["area", "index", "inPlayArea", "inPlayIndex"]:
				if source_option.get(field_name) != window_option.get(field_name):
					return false
		if option_type == 13 and source_option.get("official_attack_id") != window_option.get("attackId"):
			return false
	return true


func _command_refs(value: Variant, count: int) -> Variant:
	if not value is Array or value.size() != count or count > MAX_OPTIONS:
		return null
	var output := []
	for item: Variant in value:
		if item == null or typeof(item) != TYPE_OBJECT:
			return null
		output.append(weakref(item))
	return output


func _private_refs(value: Variant, count: int) -> Variant:
	if not value is Array or value.size() != count or count > MAX_OPTIONS:
		return null
	var output := []
	var total := 0
	for group: Variant in value:
		if not group is Array or group.size() > MAX_REFS_PER_OPTION:
			return null
		var converted := []
		for item: Variant in group:
			if item == null or typeof(item) != TYPE_OBJECT:
				return null
			converted.append(weakref(item))
		total += converted.size()
		if total > MAX_TOTAL_REFS:
			return null
		output.append(converted)
	return output


func _binding_audit(version: int, snapshot: Variant, window: Variant, binding_profile: String = PROFILE_ID) -> Dictionary:
	return {
		"binding_profile": binding_profile,
		"binding_version": version,
		"snapshot_id": snapshot.get("snapshot_id"),
		"window_id": window.window_id,
		"public_observation_hash": window.public_observation_hash,
		"chooser_player_index": window.chooser_player_index,
		"option_count": window.option_count,
		"option_fingerprints": window.option_fingerprints,
		"authority": "godot_option_binding_shadow",
		"authoritative": false,
	}


func _rejected_bind(code: String) -> Variant:
	var safe_code := code if ERROR_CODES.has(code) and not code.is_empty() else "binding_integrity_invalid"
	return BindResult.new().initialize(self, false, safe_code, null)


func _rejected_resolution(code: String) -> Variant:
	var safe_code := code if ERROR_CODES.has(code) and not code.is_empty() else "binding_integrity_invalid"
	return Resolution.new().initialize(self, false, safe_code, null, null, [], null, null)


static func _map_snapshot_error(code: Variant) -> String:
	if code in [
		"snapshot_not_current", "snapshot_owner_mismatch", "snapshot_integrity_invalid",
		"source_mutated", "reference_released",
	]:
		return code
	return "snapshot_integrity_invalid"


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


static func _load_contracts() -> Dictionary:
	var bundle_bytes := _read_bytes(BUNDLE_PATH)
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(bundle_bytes)
	if not bool(canonical.get("ok", false)) or _sha(canonical.get("bytes")) != EXPECTED_BUNDLE_SHA256:
		return {"ok": false, "error_code": "binding_contract_error"}
	var parsed := JSON.new()
	if parsed.parse(bundle_bytes.get_string_from_utf8()) != OK or not parsed.data is Dictionary:
		return {"ok": false, "error_code": "binding_contract_error"}
	var artifacts: Variant = parsed.data.get("artifacts")
	if not artifacts is Array or artifacts.size() != 3:
		return {"ok": false, "error_code": "binding_contract_error"}
	var seen := {}
	for entry_value: Variant in artifacts:
		if not entry_value is Dictionary:
			return {"ok": false, "error_code": "binding_contract_error"}
		var artifact_id: Variant = entry_value.get("id")
		if not EXPECTED_ARTIFACTS.has(artifact_id) or seen.has(artifact_id):
			return {"ok": false, "error_code": "binding_contract_error"}
		var expected: Array = EXPECTED_ARTIFACTS[artifact_id]
		if entry_value != {
			"id": artifact_id,
			"path": str(expected[0]).trim_prefix("res://"),
			"canonical_sha256": expected[1],
		}:
			return {"ok": false, "error_code": "binding_contract_error"}
		var artifact_canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(_read_bytes(expected[0]))
		if not bool(artifact_canonical.get("ok", false)) or _sha(artifact_canonical.get("bytes")) != expected[1]:
			return {"ok": false, "error_code": "binding_contract_error"}
		seen[artifact_id] = true
	if seen.size() != EXPECTED_ARTIFACTS.size():
		return {"ok": false, "error_code": "binding_contract_error"}
	var profile_file := FileAccess.open(EXPECTED_ARTIFACTS["profile"][0], FileAccess.READ)
	if profile_file == null:
		return {"ok": false, "error_code": "binding_contract_error"}
	var profile: Variant = JSON.parse_string(profile_file.get_as_text())
	if not profile is Dictionary or profile.get("profile_id") != PROFILE_ID:
		return {"ok": false, "error_code": "binding_contract_error"}
	return {"ok": true, "error_code": ""}
