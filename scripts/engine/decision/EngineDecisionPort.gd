class_name EngineDecisionPort
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const CardInstanceScript = preload("res://scripts/data/CardInstance.gd")

const EXPECTED_BUNDLE_SHA256 := "CC0026D523F2B5435031AC4E5952DB4E2C8B2C39944B333E97B1A2E4F3374C81"
const EXPECTED_ARTIFACTS := {
	"schema": ["res://contracts/ptcgdap/engine_decision_port.schema.json", "8EF3CBA573647B49535AFA46A980991CBBE22C001F0CD5CCD765305A73214914"],
	"profile": ["res://contracts/ptcgdap/engine_decision_port_profile.json", "39ACEB7EA9E61FAACE04160364B4CA82B98D4991A34CAA701A3A2310FC55F238"],
	"vectors": ["res://contracts/ptcgdap/engine_decision_port_conformance_vectors.json", "27EF66FBE19D37A19A8AA95662BEF1E06BC29283DEBF6D87CB03569139294D8D"],
}
const BUNDLE_PATH := "res://contracts/ptcgdap/engine_decision_port_bundle.json"
const SOURCE_PREFIX := "5054434744415000454E47494E455F4445434953494F4E5F534F555243455F563100"
const SNAPSHOT_PREFIX := "5054434744415000454E47494E455F4445434953494F4E5F534E415053484F545F563100"
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const SOURCE_KEYS := ["select", "deck_cards", "context_card", "effect_card", "option_card_refs", "turn_action_count"]
const SELECT_KEYS := ["type", "context", "minCount", "maxCount", "remainDamageCounter", "remainEnergyCost", "option", "deck", "contextCard", "effect"]
const OPTION_SHAPES := {
	3: ["type"], 7: ["type", "index"], 13: ["type", "local_attack_index"],
	14: ["type"], 15: ["type"],
}
const P5_EXTENSION_PROFILE_ID := "ptcgdap-marnie-prompt-broker-p5-wp5-v1"
const P5_OPTION_SHAPES := {
	3: ["type"], 7: ["type", "index"],
	8: ["type", "area", "index", "inPlayArea", "inPlayIndex"],
	12: ["type"], 13: ["type", "local_attack_index", "official_attack_id"],
	14: ["type"], 15: ["type"],
}
const ERROR_CODES := {
	"": true, "decision_contract_error": true, "invalid_match_generation": true,
	"invalid_decision_generation": true, "invalid_chooser_player_index": true,
	"invalid_decision_source": true, "invalid_select": true, "invalid_option_source": true,
	"invalid_reference": true, "reference_released": true, "stale_decision_generation": true,
	"stale_match_generation": true, "source_mutated": true, "snapshot_not_current": true,
	"snapshot_owner_mismatch": true, "snapshot_integrity_invalid": true,
}


class DecisionSnapshot extends RefCounted:
	var _owner: Variant = null
	var _match_generation: Variant = 0
	var _decision_generation: Variant = 0
	var _chooser_player_index: Variant = -1
	var _snapshot_id: Variant = ""
	var _source_digest: Variant = ""
	var _audit: Variant = {}
	var _binding_id: Variant = 0

	var match_generation: Variant:
		get: return _match_generation
	var decision_generation: Variant:
		get: return _decision_generation
	var chooser_player_index: Variant:
		get: return _chooser_player_index
	var snapshot_id: Variant:
		get: return _snapshot_id
	var source_digest: Variant:
		get: return _source_digest

	func initialize(owner: Variant, match_value: int, decision_value: int, chooser_value: int, id_value: String, digest_value: String, audit_value: Dictionary, binding_value: int) -> Variant:
		_owner = weakref(owner)
		_match_generation = match_value
		_decision_generation = decision_value
		_chooser_player_index = chooser_value
		_snapshot_id = id_value
		_source_digest = digest_value
		_audit = audit_value.duplicate(true)
		_binding_id = binding_value
		return self

	func to_audit_dict() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if owner == null or not owner.call("_snapshot_fields_valid", self):
			return {}
		return _audit.duplicate(true) if _audit is Dictionary else {}

	func validate_integrity(port: Variant) -> bool:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		return port != null and port == owner and bool(port.call("_validate_snapshot", self).get("ok", false))


class PublishResult extends RefCounted:
	var _owner: Variant = null
	var _accepted := false
	var _error_code := ""
	var _snapshot: Variant = null

	var accepted: bool:
		get: return _accepted
	var error_code: String:
		get: return _error_code
	var snapshot: Variant:
		get: return _snapshot

	func initialize(owner: Variant, accepted_value: bool, code_value: String, snapshot_value: Variant) -> Variant:
		_owner = weakref(owner)
		_accepted = accepted_value
		_error_code = code_value
		_snapshot = snapshot_value
		return self

	func validate_integrity(port: Variant) -> bool:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if port == null or port != owner:
			return false
		if _accepted:
			return _error_code == "" and _snapshot != null and bool(port.call("_validate_snapshot", _snapshot).get("ok", false))
		return _snapshot == null and _error_code != "" and ERROR_CODES.has(_error_code)

	func to_public_dict() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if not validate_integrity(owner):
			return {"accepted": false, "error_code": "snapshot_integrity_invalid", "audit": null}
		return {"accepted": _accepted, "error_code": _error_code, "audit": null if _snapshot == null else _snapshot.to_audit_dict()}


var _ok := false
var _error_code := "decision_contract_error"
var _match_generation: Variant = 0
var _last_generation := 0
var _current_snapshot: Variant = null
var _current_binding: Variant = null
var _binding_counter := 0

var ok: bool:
	get: return _ok
var error_code: String:
	get: return _error_code
var contract_hash: String:
	get: return EXPECTED_BUNDLE_SHA256 if _ok else ""


static func open_match(match_generation: Variant) -> Variant:
	var script: GDScript = load("res://scripts/engine/decision/EngineDecisionPort.gd")
	var port: Variant = script.new()
	port.call("_initialize", match_generation)
	return port


func _initialize(match_generation: Variant) -> void:
	_match_generation = match_generation
	var loaded := _load_contracts()
	_ok = bool(loaded.get("ok", false))
	_error_code = "" if _ok else "decision_contract_error"


func validate_integrity() -> bool:
	return _ok and _error_code == "" and EXPECTED_BUNDLE_SHA256.length() == 64


func publish(source: Variant, decision_generation: Variant, chooser_player_index: Variant) -> Variant:
	return _publish(source, decision_generation, chooser_player_index, "")


func publish_p5_extended(
	source: Variant,
	decision_generation: Variant,
	chooser_player_index: Variant,
	extension_profile_id: Variant
) -> Variant:
	if typeof(extension_profile_id) != TYPE_STRING or extension_profile_id != P5_EXTENSION_PROFILE_ID:
		return _rejected("invalid_decision_source")
	return _publish(source, decision_generation, chooser_player_index, extension_profile_id)


func _publish(source: Variant, decision_generation: Variant, chooser_player_index: Variant, extension_profile_id: String) -> Variant:
	if not validate_integrity():
		return _rejected("decision_contract_error")
	if not _positive(_match_generation):
		return _rejected("invalid_match_generation")
	if not _positive(decision_generation):
		return _rejected("invalid_decision_generation")
	if typeof(chooser_player_index) != TYPE_INT or chooser_player_index not in [0, 1]:
		return _rejected("invalid_chooser_player_index")
	if int(decision_generation) <= _last_generation:
		return _rejected("stale_decision_generation")
	var analysis := _analyze_source_p5(source) if extension_profile_id == P5_EXTENSION_PROFILE_ID else _analyze_source(source)
	if not bool(analysis.get("ok", false)):
		return _rejected(str(analysis.get("error_code", "invalid_decision_source")))
	var descriptor: Dictionary = analysis.get("descriptor")
	var source_canonical := CabtJsonTreeScript.canonicalize_artifact(descriptor)
	if not bool(source_canonical.get("ok", false)):
		return _rejected("invalid_decision_source")
	var source_digest := _sha(_hex_bytes(SOURCE_PREFIX) + (source_canonical.get("bytes") as PackedByteArray))
	var snapshot_payload := {
		"match_generation": _match_generation,
		"decision_generation": decision_generation,
		"chooser_player_index": chooser_player_index,
		"source_digest": source_digest,
	}
	var snapshot_canonical := CabtJsonTreeScript.canonicalize_artifact(snapshot_payload)
	if not bool(snapshot_canonical.get("ok", false)):
		return _rejected("invalid_decision_source")
	var snapshot_id := _sha(_hex_bytes(SNAPSHOT_PREFIX) + (snapshot_canonical.get("bytes") as PackedByteArray))
	_binding_counter += 1
	var references: Array = analysis.get("references")
	var audit := {
		"match_generation": _match_generation,
		"decision_generation": decision_generation,
		"chooser_player_index": chooser_player_index,
		"snapshot_id": snapshot_id,
		"source_digest": source_digest,
		"select": _copy(descriptor.get("select")),
		"turn_action_count": descriptor.get("turn_action_count"),
		"reference_count": references.size(),
		"authority": "engine_decision_port_shadow",
		"authoritative": false,
	}
	var snapshot: Variant = DecisionSnapshot.new().initialize(self, _match_generation, decision_generation, chooser_player_index, snapshot_id, source_digest, audit, _binding_counter)
	_current_snapshot = snapshot
	_current_binding = {
		"binding_id": _binding_counter,
		"descriptor": descriptor.duplicate(true),
		"references": references.duplicate(),
		"extension_profile_id": extension_profile_id,
	}
	_last_generation = int(decision_generation)
	return PublishResult.new().initialize(self, true, "", snapshot)


func rebind(snapshot: Variant, current_source: Variant) -> Dictionary:
	var validation := _validate_snapshot(snapshot)
	if not bool(validation.get("ok", false)):
		return {"ok": false, "error_code": validation.get("error_code"), "value": null}
	var analysis := (
		_analyze_source_p5(current_source)
		if _current_binding.get("extension_profile_id", "") == P5_EXTENSION_PROFILE_ID
		else _analyze_source(current_source)
	)
	if not bool(analysis.get("ok", false)):
		return {"ok": false, "error_code": "source_mutated", "value": null}
	if analysis.get("descriptor") != _current_binding.get("descriptor"):
		return {"ok": false, "error_code": "source_mutated", "value": null}
	var current_refs: Array = analysis.get("references")
	var expected_refs: Array = _current_binding.get("references")
	if current_refs.size() != expected_refs.size():
		return {"ok": false, "error_code": "source_mutated", "value": null}
	for index: int in range(current_refs.size()):
		var expected: Variant = (expected_refs[index] as WeakRef).get_ref()
		var current: Variant = (current_refs[index] as WeakRef).get_ref()
		if expected == null:
			return {"ok": false, "error_code": "reference_released", "value": null}
		if current != expected:
			return {"ok": false, "error_code": "source_mutated", "value": null}
	return {"ok": true, "error_code": "", "value": _copy_source(current_source)}


func current_snapshot() -> Variant:
	return _current_snapshot


func _rejected(code: String) -> Variant:
	return PublishResult.new().initialize(self, false, code, null)


func _snapshot_fields_valid(snapshot: Variant) -> bool:
	if not snapshot is DecisionSnapshot:
		return false
	var owner_ref: Variant = snapshot.get("_owner")
	if not owner_ref is WeakRef or (owner_ref as WeakRef).get_ref() != self:
		return false
	if snapshot != _current_snapshot or _current_binding == null or snapshot.get("_binding_id") != _current_binding.get("binding_id"):
		return false
	var descriptor: Dictionary = _current_binding.get("descriptor")
	var references: Array = _current_binding.get("references")
	var payload := {
		"match_generation": snapshot.get("_match_generation"),
		"decision_generation": snapshot.get("_decision_generation"),
		"chooser_player_index": snapshot.get("_chooser_player_index"),
		"source_digest": snapshot.get("_source_digest"),
	}
	var canonical := CabtJsonTreeScript.canonicalize_artifact(payload)
	if not bool(canonical.get("ok", false)):
		return false
	var expected_id := _sha(_hex_bytes(SNAPSHOT_PREFIX) + (canonical.get("bytes") as PackedByteArray))
	if snapshot.get("_snapshot_id") != expected_id:
		return false
	var audit: Variant = snapshot.get("_audit")
	if not audit is Dictionary:
		return false
	return audit == {
		"match_generation": payload["match_generation"],
		"decision_generation": payload["decision_generation"],
		"chooser_player_index": payload["chooser_player_index"],
		"snapshot_id": expected_id,
		"source_digest": payload["source_digest"],
		"select": _copy(descriptor.get("select")),
		"turn_action_count": descriptor.get("turn_action_count"),
		"reference_count": references.size(),
		"authority": "engine_decision_port_shadow",
		"authoritative": false,
	}


func _validate_snapshot(snapshot: Variant) -> Dictionary:
	if not snapshot is DecisionSnapshot:
		return {"ok": false, "error_code": "snapshot_integrity_invalid"}
	var owner_ref: Variant = snapshot.get("_owner")
	if not owner_ref is WeakRef or (owner_ref as WeakRef).get_ref() != self:
		return {"ok": false, "error_code": "snapshot_owner_mismatch"}
	if snapshot.get("_match_generation") != _match_generation:
		return {"ok": false, "error_code": "stale_match_generation"}
	if snapshot != _current_snapshot or _current_binding == null or snapshot.get("_binding_id") != _current_binding.get("binding_id"):
		return {"ok": false, "error_code": "snapshot_not_current"}
	if not _snapshot_fields_valid(snapshot):
		return {"ok": false, "error_code": "snapshot_integrity_invalid"}
	return {"ok": true, "error_code": ""}


func _analyze_source(source: Variant) -> Dictionary:
	return _analyze_source_with_shapes(source, OPTION_SHAPES, false)


func _analyze_source_p5(source: Variant) -> Dictionary:
	return _analyze_source_with_shapes(source, P5_OPTION_SHAPES, true)


func _analyze_source_with_shapes(source: Variant, option_shapes: Dictionary, p5_extended: bool) -> Dictionary:
	if not source is Dictionary or not _exact_keys(source, SOURCE_KEYS):
		return _failure("invalid_decision_source")
	if not _nonnegative(source.get("turn_action_count")):
		return _failure("invalid_decision_source")
	var option_refs: Variant = source.get("option_card_refs")
	if not option_refs is Array:
		return _failure("invalid_decision_source")
	var select_value: Variant = source.get("select")
	if select_value == null:
		if not option_refs.is_empty() or source.get("deck_cards") != null or source.get("context_card") != null or source.get("effect_card") != null:
			return _failure("invalid_decision_source")
		return {"ok": true, "error_code": "", "descriptor": {"select": null, "turn_action_count": source.get("turn_action_count")}, "references": []}
	if not select_value is Dictionary or not _exact_keys(select_value, SELECT_KEYS):
		return _failure("invalid_select")
	for key: String in ["type", "context", "minCount", "maxCount", "remainDamageCounter", "remainEnergyCost"]:
		if not _nonnegative(select_value.get(key)):
			return _failure("invalid_select")
	if select_value.get("deck") != null or select_value.get("contextCard") != null or select_value.get("effect") != null:
		return _failure("invalid_select")
	var options: Variant = select_value.get("option")
	if not options is Array or options.size() > 256 or options.size() != option_refs.size():
		return _failure("invalid_select")
	if int(select_value.get("minCount")) > int(select_value.get("maxCount")) or int(select_value.get("maxCount")) > options.size():
		return _failure("invalid_select")
	var references := []
	var audit_options := []
	for position: int in range(options.size()):
		var option: Variant = options[position]
		var reference_value: Variant = option_refs[position]
		if not option is Dictionary or typeof(option.get("type")) != TYPE_INT or not option_shapes.has(option.get("type")):
			return _failure("invalid_option_source")
		var option_type: int = option.get("type")
		if not _exact_keys(option, option_shapes[option_type]):
			return _failure("invalid_option_source")
		if option_type == 7 and not _nonnegative(option.get("index")):
			return _failure("invalid_option_source")
		if option_type == 8 and (
			not p5_extended
			or not _nonnegative(option.get("area"))
			or not _nonnegative(option.get("index"))
			or not _nonnegative(option.get("inPlayArea"))
			or not _nonnegative(option.get("inPlayIndex"))
		):
			return _failure("invalid_option_source")
		if option_type == 13 and (
			not _nonnegative(option.get("local_attack_index"))
			or (p5_extended and not _nonnegative(option.get("official_attack_id")))
		):
			return _failure("invalid_option_source")
		if option_type == 12 and not p5_extended:
			return _failure("invalid_option_source")
		var reference_token: Variant = null
		if option_type == 15:
			if not _exact_card(reference_value):
				return _failure("invalid_reference")
			references.append(weakref(reference_value))
			reference_token = "card_reference"
		elif reference_value != null:
			return _failure("invalid_reference")
		audit_options.append({"position": position, "option": option.duplicate(true), "reference_token": reference_token})
	var deck_result := _reference_array(source.get("deck_cards"), references, 120)
	if not bool(deck_result.get("ok", false)):
		return deck_result
	var context_result := _single_reference(source.get("context_card"), references)
	if not bool(context_result.get("ok", false)):
		return context_result
	var effect_result := _single_reference(source.get("effect_card"), references)
	if not bool(effect_result.get("ok", false)):
		return effect_result
	if references.size() > 384:
		return _failure("invalid_reference")
	var descriptor_select := {
		"type": select_value.get("type"), "context": select_value.get("context"),
		"minCount": select_value.get("minCount"), "maxCount": select_value.get("maxCount"),
		"remainDamageCounter": select_value.get("remainDamageCounter"), "remainEnergyCost": select_value.get("remainEnergyCost"),
		"option": audit_options, "deck_tokens": deck_result.get("tokens"),
		"context_token": context_result.get("token"), "effect_token": effect_result.get("token"),
	}
	return {"ok": true, "error_code": "", "descriptor": {"select": descriptor_select, "turn_action_count": source.get("turn_action_count")}, "references": references}


func _reference_array(value: Variant, references: Array, limit: int) -> Dictionary:
	if value == null:
		return {"ok": true, "tokens": null}
	if not value is Array or value.size() > limit:
		return _failure("invalid_reference")
	var tokens := []
	for item: Variant in value:
		if not _exact_card(item):
			return _failure("invalid_reference")
		references.append(weakref(item))
		tokens.append("card_reference")
	return {"ok": true, "tokens": tokens}


func _single_reference(value: Variant, references: Array) -> Dictionary:
	if value == null:
		return {"ok": true, "token": null}
	if not _exact_card(value):
		return _failure("invalid_reference")
	references.append(weakref(value))
	return {"ok": true, "token": "card_reference"}


func _copy_source(source: Dictionary) -> Dictionary:
	return {
		"select": null if source.get("select") == null else source.get("select").duplicate(true),
		"deck_cards": null if source.get("deck_cards") == null else source.get("deck_cards").duplicate(),
		"context_card": source.get("context_card"), "effect_card": source.get("effect_card"),
		"option_card_refs": source.get("option_card_refs").duplicate(),
		"turn_action_count": source.get("turn_action_count"),
	}


func _load_contracts() -> Dictionary:
	var bundle_bytes := _read_bytes(BUNDLE_PATH)
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(bundle_bytes)
	if not bool(canonical.get("ok", false)) or _sha(canonical.get("bytes")) != EXPECTED_BUNDLE_SHA256:
		return _failure("decision_contract_error")
	var parsed := JSON.new()
	if parsed.parse(bundle_bytes.get_string_from_utf8()) != OK or not parsed.data is Dictionary:
		return _failure("decision_contract_error")
	var artifacts: Variant = parsed.data.get("artifacts")
	if not artifacts is Array or artifacts.size() != 3:
		return _failure("decision_contract_error")
	for entry_value: Variant in artifacts:
		if not entry_value is Dictionary or not EXPECTED_ARTIFACTS.has(entry_value.get("id")):
			return _failure("decision_contract_error")
		var expected: Array = EXPECTED_ARTIFACTS[entry_value.get("id")]
		if entry_value.get("path") != str(expected[0]).trim_prefix("res://") or entry_value.get("canonical_sha256") != expected[1]:
			return _failure("decision_contract_error")
		var artifact_canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(_read_bytes(expected[0]))
		if not bool(artifact_canonical.get("ok", false)) or _sha(artifact_canonical.get("bytes")) != expected[1]:
			return _failure("decision_contract_error")
	return {"ok": true, "error_code": ""}


static func _read_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


static func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode().to_upper()


static func _hex_bytes(value: String) -> PackedByteArray:
	return value.hex_decode()


static func _exact_card(value: Variant) -> bool:
	return value != null and value is Object and value.get_script() == CardInstanceScript


static func _nonnegative(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= 0 and int(value) <= MAX_SAFE_INTEGER


static func _positive(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= 1 and int(value) <= MAX_SAFE_INTEGER


static func _exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "error_code": code}


static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
