class_name MarniePromptBroker
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const ContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const WindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")
const SanitizerScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionSanitizer.gd")
const FallbackScript = preload("res://scripts/ai/ptcgdap/cabt/CabtDeterministicFallback.gd")
const PortScript = preload("res://scripts/engine/decision/EngineDecisionPort.gd")
const BindingScript = preload("res://scripts/engine/decision/GodotOptionBinding.gd")
const BrokerScript = preload("res://scripts/engine/decision/ShadowPromptBroker.gd")

const DEFAULT_ROOT := "res://"
const MAX_JSON_BYTES := 2 * 1024 * 1024
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const PROFILE_ID := "ptcgdap-marnie-prompt-broker-p5-wp5-v1"
const BUNDLE_ID := "ptcgdap-marnie-prompt-broker-bundle-p5-wp5-v1"
const EXPECTED_BUNDLE_CANONICAL_SHA256 := "E2EFDDE373EFBA0FDC929BE817595C8B3F0A5653956DB56418ADED57AFF960A1"
const EXPECTED_DOCUMENT_INTEGRITY_SHA256 := "24425ECEC54E9D1ED173ACC05639EA30DAE7F64035410A9C545F0213B15EDC25"
const LIFECYCLE_PREFIX := "50544347444150004D41524E49455F50524F4D50545F4C4946454359434C455F563100"
const EXPECTED_ARTIFACTS := {
	"schema": ["contracts/ptcgdap/marnie_prompt_broker.schema.json", "6D5942D4A319B78FFF9B49814A9661DD0CA99E4E3B531DF0B5A5E13FEBFF153A"],
	"profile": ["contracts/ptcgdap/marnie_prompt_broker_profile.json", "A136829945D95CC686FB7D5BBC705FF0ABB6387975CAA45191D0C3DA1B06E096"],
	"audit": ["data/ptcgdap/marnie_vertical_slice/marnie_prompt_broker_v1.json", "05A9AC6440B16EEC83C7FD42A360ADF481142C5EB313170CC407AF8A1CA6B393"],
	"vectors": ["contracts/ptcgdap/marnie_prompt_broker_conformance_vectors.json", "98CD8D6EB35469A74BD042DF00714AF5601E16F89E247FBAE2E9855830FB1391"],
}
const PARENT_BUNDLES := {
	"vertical_slice_bundle": ["contracts/ptcgdap/marnie_vertical_slice_bundle.json", "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425"],
	"capability_policy_bundle": ["contracts/ptcgdap/marnie_capability_policy_bundle.json", "F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C"],
	"identity_projection_bundle": ["contracts/ptcgdap/marnie_identity_projection_bundle.json", "1EB530AB7DFACBE6AB098A6C67D6AAE0BC1871FF3E2F48C9284E8539EE6ACDC4"],
	"shadow_prompt_broker_bundle": ["contracts/ptcgdap/shadow_prompt_broker_bundle.json", "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E"],
	"engine_decision_port_bundle": ["contracts/ptcgdap/engine_decision_port_bundle.json", "CC0026D523F2B5435031AC4E5952DB4E2C8B2C39944B333E97B1A2E4F3374C81"],
	"godot_option_binding_bundle": ["contracts/ptcgdap/godot_option_binding_bundle.json", "4FFFEC48E4E1FE0774BB6E343D4D4B0384A9210057DEE06415C2A20F2899B1C1"],
}
const FORBIDDEN_PUBLIC_KEYS := {
	"session_id": true, "callback_binding_hash": true, "current_source": true,
	"private_engine_command": true, "private_object_refs": true,
	"private_resolutions": true, "ticket": true, "preflight": true, "command": true,
}


class FixtureCapability extends RefCounted:
	var frame_id := ""
	var position := -1

	func initialize(frame_value: String, position_value: int) -> Variant:
		frame_id = frame_value
		position = position_value
		return self


class BrokerResult extends RefCounted:
	var _owner: Variant = null
	var _snapshot: Variant = {}
	var _snapshot_hash := ""

	func initialize(owner_value: Variant, snapshot_value: Dictionary) -> Variant:
		_owner = weakref(owner_value)
		_snapshot = snapshot_value.duplicate(true)
		_snapshot_hash = str(owner_value.call("_snapshot_digest", snapshot_value))
		return self

	func validate_integrity(owner_value: Variant) -> bool:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		return (
			owner != null and owner == owner_value
			and bool(owner.call("_validate_result", self))
		)

	func to_public_dict() -> Dictionary:
		var owner: Variant = (_owner as WeakRef).get_ref() if _owner is WeakRef else null
		if owner == null or not validate_integrity(owner):
			return {
				"accepted": false, "error_code": "contract_integrity_invalid",
				"frame_count": 0, "brokered_frame_count": 0,
				"initial_deck_frame_count": 0, "terminal_frame_count": 0,
				"serialized_private_resolution_count": 0,
				"extension_profile_id": PROFILE_ID, "lifecycle_chain_head": null,
				"frames": [], "production_actions_used": false, "execution_authority": false,
			}
		return (_snapshot as Dictionary).duplicate(true)


var _ok := false
var _error_code := "contract_integrity_invalid"
var _bundle: Variant = {}
var _schema: Variant = {}
var _profile: Variant = {}
var _audit: Variant = {}
var _vectors: Variant = {}
var _frames_by_id: Variant = {}
var _verified_frames: Variant = null
var _document_integrity := ""
var _load_attempted := false

var ok: bool:
	get: return _ok and validate_integrity()
var error_code: String:
	get: return "" if ok else _error_code


static func load_default() -> Variant:
	return load_from_root(DEFAULT_ROOT)


static func load_from_root(root_path: Variant) -> Variant:
	var script: GDScript = load("res://scripts/ai/ptcgdap/public/MarniePromptBroker.gd")
	var result: RefCounted = script.new()
	if typeof(root_path) != TYPE_STRING:
		result.set("_load_attempted", true)
		result.call("_fail", "contract_integrity_invalid")
		return result
	result.call("_load", str(root_path))
	return result


func _load(root_path: String) -> void:
	if _load_attempted:
		return
	_load_attempted = true
	var root := root_path.trim_suffix("/") + "/"
	if root == "/" or not _root_is_supported(root):
		_fail("contract_integrity_invalid")
		return
	var bundle_result := _read_json("%scontracts/ptcgdap/marnie_prompt_broker_bundle.json" % root)
	if not bool(bundle_result.get("ok", false)):
		_fail("contract_integrity_invalid")
		return
	var bundle: Variant = bundle_result.get("value")
	if (
		not bundle is Dictionary
		or _canonical_sha256(bundle) != EXPECTED_BUNDLE_CANONICAL_SHA256
		or bundle.get("bundle_id") != BUNDLE_ID
		or bundle.get("profile_id") != PROFILE_ID
		or not bundle.get("artifacts") is Array
		or bundle.get("artifacts").size() != 4
	):
		_fail("contract_integrity_invalid")
		return
	var parent_contracts: Variant = bundle.get("parent_contracts")
	if not parent_contracts is Dictionary or parent_contracts.size() != PARENT_BUNDLES.size():
		_fail("contract_integrity_invalid")
		return
	var documents := {}
	var seen := {}
	for entry_value: Variant in bundle.get("artifacts"):
		if not entry_value is Dictionary or not _same_keys(entry_value, ["id", "path", "canonical_sha256"]):
			_fail("contract_integrity_invalid")
			return
		var artifact_id: Variant = entry_value.get("id")
		if typeof(artifact_id) != TYPE_STRING or not EXPECTED_ARTIFACTS.has(artifact_id) or seen.has(artifact_id):
			_fail("contract_integrity_invalid")
			return
		var expected: Array = EXPECTED_ARTIFACTS[artifact_id]
		if entry_value != {"id": artifact_id, "path": expected[0], "canonical_sha256": expected[1]} or not _is_safe_relative_path(expected[0]):
			_fail("contract_integrity_invalid")
			return
		var document_result := _read_json("%s%s" % [root, expected[0]])
		if not bool(document_result.get("ok", false)) or _canonical_sha256(document_result.get("value")) != expected[1]:
			_fail("contract_integrity_invalid")
			return
		documents[artifact_id] = _copy(document_result.get("value"))
		seen[artifact_id] = true
	if seen.size() != 4:
		_fail("contract_integrity_invalid")
		return
	for parent_id: String in PARENT_BUNDLES:
		var parent_expected: Array = PARENT_BUNDLES[parent_id]
		if parent_contracts.get(parent_id) != parent_expected[1]:
			_fail("contract_integrity_invalid")
			return
		var parent_result := _read_json("%s%s" % [root, parent_expected[0]])
		if not bool(parent_result.get("ok", false)) or _canonical_sha256(parent_result.get("value")) != parent_expected[1]:
			_fail("contract_integrity_invalid")
			return
	if _canonical_sha256(documents) != EXPECTED_DOCUMENT_INTEGRITY_SHA256 or not _documents_valid(documents):
		_fail("contract_integrity_invalid")
		return
	var by_id := {}
	for frame_value: Variant in documents.get("audit", {}).get("frames", []):
		by_id[frame_value.get("frame_id")] = _copy(frame_value)
	_bundle = _copy(bundle)
	_schema = documents["schema"]
	_profile = documents["profile"]
	_audit = documents["audit"]
	_vectors = documents["vectors"]
	_frames_by_id = by_id
	_verified_frames = null
	_document_integrity = EXPECTED_DOCUMENT_INTEGRITY_SHA256
	_ok = true
	_error_code = ""


func _fail(code: String) -> void:
	_ok = false
	_error_code = code


func validate_integrity() -> bool:
	return (
		_ok and _error_code.is_empty()
		and _document_integrity == EXPECTED_DOCUMENT_INTEGRITY_SHA256
		and _bundle is Dictionary and _canonical_sha256(_bundle) == EXPECTED_BUNDLE_CANONICAL_SHA256
		and _runtime_digest() == EXPECTED_DOCUMENT_INTEGRITY_SHA256
		and _frames_match_audit()
		and (_verified_frames == null or (_verified_frames is Array and _verified_frames == _audit.get("expected_public_result", {}).get("frames")))
	)


func _frames_match_audit() -> bool:
	if not _frames_by_id is Dictionary or not _audit is Dictionary:
		return false
	var frames: Variant = _audit.get("frames")
	if not frames is Array or frames.size() != 13:
		return false
	var expected := {}
	for frame: Variant in frames:
		if not frame is Dictionary or typeof(frame.get("frame_id")) != TYPE_STRING or expected.has(frame.get("frame_id")):
			return false
		expected[frame.get("frame_id")] = frame
	return _frames_by_id == expected


func bundle_hash() -> String:
	return EXPECTED_BUNDLE_CANONICAL_SHA256 if validate_integrity() else ""


func evaluate_all() -> Variant:
	if not validate_integrity():
		return null
	var frames: Variant = _verified_full_frames()
	if not frames is Array or frames.size() != 13:
		return null
	var snapshot := {
		"accepted": true, "error_code": "", "frame_count": 13,
		"brokered_frame_count": 11, "initial_deck_frame_count": 1,
		"terminal_frame_count": 1, "serialized_private_resolution_count": 0,
		"extension_profile_id": PROFILE_ID, "lifecycle_chain_head": frames[-1].get("lifecycle_hash"),
		"frames": frames, "production_actions_used": false, "execution_authority": false,
	}
	if snapshot != _audit.get("expected_public_result"):
		return null
	return BrokerResult.new().initialize(self, snapshot)


func evaluate_frame(frame_id: Variant) -> Variant:
	if not validate_integrity() or typeof(frame_id) != TYPE_STRING or not _frames_by_id.has(frame_id):
		return null
	var frame: Dictionary = _frames_by_id[frame_id]
	var all_frames: Variant = _verified_full_frames()
	var frames: Variant = all_frames.slice(0, int(frame.get("ordinal")) + 1) if all_frames is Array else null
	if not frames is Array or frames.is_empty():
		return null
	var chosen: Dictionary = frames[-1]
	var snapshot := {
		"accepted": true, "error_code": "", "frame_count": 1,
		"brokered_frame_count": 1 if chosen.get("status") == "committed_shadow" else 0,
		"initial_deck_frame_count": 1 if chosen.get("status") == "initial_deck_fixture" else 0,
		"terminal_frame_count": 1 if chosen.get("status") == "terminal_no_callback" else 0,
		"serialized_private_resolution_count": 0, "extension_profile_id": PROFILE_ID,
		"lifecycle_chain_head": chosen.get("lifecycle_hash"), "frames": [chosen],
		"production_actions_used": false, "execution_authority": false,
	}
	return BrokerResult.new().initialize(self, snapshot)


func revalidate_full_lifecycle() -> bool:
	if not validate_integrity():
		return false
	var frames: Variant = _execute(12)
	return frames is Array and frames == _audit.get("expected_public_result", {}).get("frames")


func _verified_full_frames() -> Variant:
	if _verified_frames is Array:
		return _verified_frames.duplicate(true)
	var frames: Variant = _execute(12)
	if not frames is Array or frames != _audit.get("expected_public_result", {}).get("frames"):
		return null
	_verified_frames = frames.duplicate(true)
	return frames.duplicate(true)


func _execute(target_ordinal: int) -> Variant:
	if not validate_integrity() or target_ordinal < 0 or target_ordinal >= 13:
		return null
	var contracts: Variant = ContractSetScript.load_default()
	if contracts == null or not bool(contracts.get("ok")) or not contracts.validate_integrity():
		return null
	var port: Variant = PortScript.open_match(1)
	var binding_owner: Variant = BindingScript.new()
	var broker: Variant = BrokerScript.new(1, "session:marnie-p5-wp5-offline")
	if port == null or binding_owner == null or broker == null or not port.validate_integrity() or not binding_owner.validate_integrity() or not broker.validate_integrity():
		return null
	var actual_frames := []
	var previous_hash: Variant = null
	var previous_snapshot: Variant = null
	var previous_window: Variant = null
	var previous_binding: Variant = null
	for ordinal: int in range(target_ordinal + 1):
		var frame: Dictionary = _audit.get("frames")[ordinal].duplicate(true)
		var expected: Dictionary = frame.get("expected_public_result")
		var window_document: Variant = frame.get("window")
		var actual: Dictionary = {}
		if window_document == null:
			actual = expected.duplicate(true)
			actual.erase("previous_lifecycle_hash")
			actual.erase("lifecycle_hash")
		else:
			var select_payload := {
				"type": window_document.get("select_type_raw"), "context": window_document.get("select_context_raw"),
				"minCount": window_document.get("min_count"), "maxCount": window_document.get("max_count"),
				"remainDamageCounter": window_document.get("remain_damage_counter"),
				"remainEnergyCost": window_document.get("remain_energy_cost"),
				"option": window_document.get("options"), "deck": window_document.get("public_deck_candidates"),
				"contextCard": window_document.get("context_card"), "effect": window_document.get("effect"),
			}
			var built: Variant = WindowScript.build({
				"select": select_payload,
				"public_observation_hash": window_document.get("public_observation_hash"),
				"public_hash_authority": window_document.get("public_hash_authority"),
				"chooser_player_index": window_document.get("chooser_player_index"),
			}, contracts)
			var window: Variant = built.get("window") if built != null else null
			if window == null or built.get("decision_state") != "policy_allowed" or window.to_dict() != window_document:
				return null
			var source: Dictionary = frame.get("source")
			var generation: int = expected.get("decision_generation")
			var published: Variant = port.publish_p5_extended(source, generation, window.chooser_player_index, PROFILE_ID)
			if published == null or not published.accepted or published.snapshot == null or not published.validate_integrity(port):
				return null
			var snapshot: Variant = published.snapshot
			if snapshot.snapshot_id == previous_snapshot or window.window_id == previous_window:
				return null
			var commands := []
			var private_refs := []
			for position: int in range(window.option_count):
				commands.append(FixtureCapability.new().initialize(frame.get("frame_id"), position))
				private_refs.append([])
			var bound: Variant = binding_owner.bind_p5_extended(
				port, snapshot, source, window, frame.get("callback_binding_hash"),
				commands, private_refs, PROFILE_ID
			)
			if bound == null or not bound.accepted or bound.binding == null or not bound.validate_integrity(binding_owner):
				return null
			if bound.binding.binding_version == previous_binding:
				return null
			var opened: Variant = broker.open_prompt(
				frame.get("window_family"), port, snapshot, binding_owner, bound.binding,
				source, window, frame.get("callback_binding_hash")
			)
			if opened == null or not opened.accepted or opened.prompt == null or not opened.validate_integrity(broker):
				return null
			var resolution: Variant = SanitizerScript.resolve_policy_attempt(
				window, {"status": "returned", "output": frame.get("policy_selected_indexes")}
			)
			if resolution == null or not FallbackScript.validate_resolution_integrity(resolution, window) or resolution.selected_indexes != frame.get("policy_selected_indexes"):
				return null
			var prepared: Variant = broker.prepare_selection(opened.prompt, resolution)
			if prepared == null or not prepared.accepted or not prepared.validate_integrity(broker):
				return null
			var committed: Variant = broker.commit_prompt(opened.prompt)
			if committed == null or not committed.accepted or not committed.validate_integrity(broker):
				return null
			var committed_public: Dictionary = committed.to_public_dict()
			var committed_audit: Variant = committed_public.get("audit")
			if not committed_audit is Dictionary or committed_audit.get("state") != "awaiting_reobserve":
				return null
			actual = {
				"ordinal": ordinal, "frame_id": frame.get("frame_id"), "window_family": frame.get("window_family"),
				"callback_role": frame.get("callback_role"), "status": "committed_shadow",
				"decision_generation": snapshot.decision_generation,
				"broker_generation": committed_audit.get("broker_generation"),
				"snapshot_id": snapshot.snapshot_id, "source_digest": snapshot.source_digest,
				"window_id": window.window_id, "binding_version": bound.binding.binding_version,
				"option_count": window.option_count,
				"option_types": _option_types(window.options),
				"selected_indexes": resolution.selected_indexes,
				"committed_resolution_count": committed_audit.get("resolution_count"),
				"serialized_private_resolution_count": 0, "broker_state": committed_audit.get("state"),
				"extension_profile_id": PROFILE_ID, "production_action_used": false, "execution_authority": false,
			}
			previous_snapshot = snapshot.snapshot_id
			previous_window = window.window_id
			previous_binding = bound.binding.binding_version
		var lifecycle_payload := actual.duplicate(true)
		lifecycle_payload["previous_lifecycle_hash"] = previous_hash
		var lifecycle_hash := _domain_hash(LIFECYCLE_PREFIX, lifecycle_payload)
		actual["previous_lifecycle_hash"] = previous_hash
		actual["lifecycle_hash"] = lifecycle_hash
		previous_hash = lifecycle_hash
		if actual != expected:
			return null
		actual_frames.append(actual)
	return actual_frames


func _validate_result(result: Variant) -> bool:
	if not validate_integrity() or not result is BrokerResult:
		return false
	var owner_ref: Variant = result.get("_owner")
	if not owner_ref is WeakRef or (owner_ref as WeakRef).get_ref() != self:
		return false
	var snapshot: Variant = result.get("_snapshot")
	if not snapshot is Dictionary or _contains_forbidden(snapshot) or result.get("_snapshot_hash") != _canonical_sha256(snapshot):
		return false
	if not _same_keys(snapshot, [
		"accepted", "error_code", "frame_count", "brokered_frame_count",
		"initial_deck_frame_count", "terminal_frame_count", "serialized_private_resolution_count",
		"extension_profile_id", "lifecycle_chain_head", "frames", "production_actions_used", "execution_authority",
	]):
		return false
	var frames: Variant = snapshot.get("frames")
	if not frames is Array or frames.size() not in [1, 13] or snapshot.get("frame_count") != frames.size():
		return false
	if snapshot.get("accepted") != true or snapshot.get("error_code") != "" or snapshot.get("serialized_private_resolution_count") != 0:
		return false
	if snapshot.get("extension_profile_id") != PROFILE_ID or snapshot.get("production_actions_used") != false or snapshot.get("execution_authority") != false:
		return false
	for frame_value: Variant in frames:
		if not frame_value is Dictionary or not _frames_by_id.has(frame_value.get("frame_id")) or frame_value != _frames_by_id[frame_value.get("frame_id")].get("expected_public_result"):
			return false
	return true


func _snapshot_digest(value: Variant) -> String:
	return _canonical_sha256(value)


func run(operation: Variant, input_value: Variant) -> Dictionary:
	if not validate_integrity():
		return _result(null, "contract_integrity_invalid")
	if typeof(operation) != TYPE_STRING:
		return _result(null, "input_type_invalid")
	if operation == "evaluate_frame":
		if typeof(input_value) != TYPE_STRING:
			return _result(null, "input_type_invalid")
		var frame_result: Variant = evaluate_frame(input_value)
		return _result(null, "frame_unknown") if frame_result == null else _result(frame_result.to_public_dict().get("frames")[0])
	if operation == "evaluate_all":
		if input_value != null:
			return _result(null, "input_type_invalid")
		var all_result: Variant = evaluate_all()
		return _result(null, "lifecycle_rejected") if all_result == null else _result(all_result.to_public_dict())
	if operation == "audit_snapshot":
		if input_value != null:
			return _result(null, "input_type_invalid")
		return _result(audit_snapshot())
	return _result(null, "operation_unknown")


func audit_snapshot() -> Dictionary:
	return _copy(_audit.get("summary")) if validate_integrity() else {}


func _runtime_digest() -> String:
	if not (_schema is Dictionary and _profile is Dictionary and _audit is Dictionary and _vectors is Dictionary):
		return ""
	return _canonical_sha256({"schema": _copy(_schema), "profile": _copy(_profile), "audit": _copy(_audit), "vectors": _copy(_vectors)})


static func _documents_valid(documents: Dictionary) -> bool:
	var profile: Variant = documents.get("profile")
	var audit: Variant = documents.get("audit")
	var vectors: Variant = documents.get("vectors")
	if not profile is Dictionary or profile.get("profile_id") != PROFILE_ID:
		return false
	if not audit is Dictionary or audit.get("profile_id") != PROFILE_ID or audit.get("audit_id") != "ptcgdap-marnie-prompt-broker-audit-p5-wp5-v1":
		return false
	var frames: Variant = audit.get("frames")
	if not frames is Array or frames.size() != 13 or profile.get("frame_order") != _frame_ids(frames):
		return false
	var brokered := 0
	for frame: Variant in frames:
		if frame.get("window") != null:
			brokered += 1
	if brokered != 11 or frames[0].get("window") != null or frames[-1].get("window") != null or frames[-1].get("terminal") != true:
		return false
	if frames[3].get("option_types") != [8, 8, 7, 14] or frames[8].get("option_types") != [7, 13, 12, 14]:
		return false
	return vectors is Dictionary and vectors.get("cases") is Array and vectors.get("cases").size() == 23


static func _frame_ids(frames: Array) -> Array:
	var result := []
	for frame: Variant in frames:
		result.append(frame.get("frame_id") if frame is Dictionary else null)
	return result


static func _option_types(options: Array) -> Array:
	var result := []
	for option: Variant in options:
		result.append(option.get("type") if option is Dictionary else null)
	return result


static func _contains_forbidden(value: Variant) -> bool:
	if value is Dictionary:
		for key: Variant in value:
			if typeof(key) != TYPE_STRING or FORBIDDEN_PUBLIC_KEYS.has(key) or _contains_forbidden(value[key]):
				return true
	elif value is Array:
		for child: Variant in value:
			if _contains_forbidden(child):
				return true
	return false


static func _domain_hash(prefix_hex: String, value: Variant) -> String:
	var canonical := CabtJsonTreeScript.canonicalize_artifact(value, {"max_input_bytes": MAX_JSON_BYTES, "max_output_bytes": MAX_JSON_BYTES})
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(prefix_hex.hex_decode() + canonical.get("bytes", PackedByteArray())) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _result(value: Variant, error: String = "") -> Dictionary:
	return {"ok": error.is_empty(), "error_code": error, "value": _copy(value) if error.is_empty() else null}


static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


static func _same_keys(value: Variant, expected: Array) -> bool:
	if not value is Dictionary or value.size() != expected.size():
		return false
	for key: Variant in expected:
		if typeof(key) != TYPE_STRING or not value.has(key):
			return false
	return true


static func _root_is_supported(root: String) -> bool:
	return root.begins_with("res://") or root.begins_with("user://")


static func _is_safe_relative_path(path: String) -> bool:
	return not path.is_empty() and not path.begins_with("/") and not path.contains("\\") and not path.split("/").has("..") and not path.split("/").has(".")


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error_code": "file_missing", "value": null}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error_code": "file_missing", "value": null}
	var length := file.get_length()
	if length < 1 or length > MAX_JSON_BYTES:
		return {"ok": false, "error_code": "file_invalid", "value": null}
	var source_bytes := file.get_buffer(length)
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(source_bytes, {"max_input_bytes": MAX_JSON_BYTES, "max_output_bytes": MAX_JSON_BYTES})
	if not bool(canonical.get("ok", false)):
		return {"ok": false, "error_code": "file_invalid", "value": null}
	var text := source_bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != source_bytes:
		return {"ok": false, "error_code": "file_invalid", "value": null}
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"ok": false, "error_code": "file_invalid", "value": null}
	var state := {"ok": true}
	var restored: Variant = _restore_integer_tokens(parser.data, state)
	if not bool(state.get("ok", false)) or not restored is Dictionary:
		return {"ok": false, "error_code": "file_invalid", "value": null}
	return {"ok": true, "error_code": "", "value": restored}


static func _restore_integer_tokens(value: Variant, state: Dictionary) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number := float(value)
			if not is_finite(number) or number != floorf(number) or number < -float(MAX_SAFE_INTEGER) or number > float(MAX_SAFE_INTEGER):
				state["ok"] = false
				return null
			return int(number)
		TYPE_ARRAY:
			var array: Array = []
			for child: Variant in value:
				array.append(_restore_integer_tokens(child, state))
				if not bool(state.get("ok", false)):
					return null
			return array
		TYPE_DICTIONARY:
			var object: Dictionary = {}
			for key: Variant in value:
				if typeof(key) != TYPE_STRING:
					state["ok"] = false
					return null
				object[key] = _restore_integer_tokens(value[key], state)
				if not bool(state.get("ok", false)):
					return null
			return object
		_:
			return value


static func _canonical_sha256(value: Variant) -> String:
	var canonical := CabtJsonTreeScript.canonicalize_artifact(value, {"max_input_bytes": MAX_JSON_BYTES, "max_output_bytes": MAX_JSON_BYTES})
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(canonical.get("bytes", PackedByteArray())) != OK:
		return ""
	return context.finish().hex_encode().to_upper()
