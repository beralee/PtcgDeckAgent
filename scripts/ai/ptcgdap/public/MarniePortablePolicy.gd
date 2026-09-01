class_name MarniePortablePolicy
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const CapabilityPolicyScript = preload("res://scripts/ai/ptcgdap/public/MarnieCapabilityPolicy.gd")
const PublicBaseScript = preload("res://scripts/ai/ptcgdap/public/MarniePublicBase.gd")

const DEFAULT_ROOT := "res://"
const MAX_JSON_BYTES := 4 * 1024 * 1024
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const CONTRACT_ID := "ptcgdap-marnie-portable-policy-p5-wp7-v1"
const PROFILE_ID := "marnie_portable_policy_profile_v1"
const EXPECTED_BUNDLE_CANONICAL_SHA256 := "992B7F00DF412496BA414ABCC87C21C6136CB513C9C90799C897ADD18D15EDB2"
const EXPECTED_DOCUMENT_INTEGRITY_SHA256 := "6A2381855F98FB806B456F445AEE5A6F24A3C93A4ADE8259C8A106593AFC9210"
const EXPECTED_FRAME_SET_SHA256 := "5DFB7ED299D566B71130F8049A27338462E23E2331D41344E27E684EFBEC4740"
const TRACE_PREFIX_UTF8_HEX := "50544347444150004D41524E49455F504F525441424C455F54524143455F563100"
const FRAME_IDS := [
	"w0_initial", "w1_setup_active", "w2_setup_bench", "w3_main",
	"w4_spikemuth_deck", "w5_punk_up_sources", "w5_punk_up_target_1",
	"w5_punk_up_target_2", "w6_shadow_bullet_attack", "w6_shadow_bullet_target",
	"w7_take_prize", "w7_forced_send_out", "w7_terminal",
]
const PARENT_BUNDLES := {
	"marnie_capability_policy": ["contracts/ptcgdap/marnie_capability_policy_bundle.json", "F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C"],
	"marnie_public_base": ["contracts/ptcgdap/marnie_public_base_bundle.json", "67EBA6348277001692942FD58E8D1B9D50C54F0FFC783D8802BA3CCB45691105"],
	"marnie_trajectory_replay": ["contracts/ptcgdap/marnie_trajectory_replay_bundle.json", "E203A688BEC1AFFFABAAF06098361B3FAE04B84431F99AE75A19F891BFA9599F"],
}
const PARENT_ORDER := ["marnie_capability_policy", "marnie_public_base", "marnie_trajectory_replay"]
const EXPECTED_ARTIFACTS := {
	"schema": ["contracts/ptcgdap/marnie_portable_policy.schema.json", "31E041BC61625BB265C900A5E3E073A121FE92E4B5D954F7506472C2E4F2A398"],
	"profile": ["contracts/ptcgdap/marnie_portable_policy_profile.json", "963CDB706D6EAB7389ED6096DFBF61E69A2819A838D36837D9BC8FFE0E9A2626"],
	"vectors": ["contracts/ptcgdap/marnie_portable_policy_conformance_vectors.json", "5BA16562A20331D99673756C46183055B17CC0CD47FB3EF1F1A1D2B0A8EB41A8"],
	"audit": ["data/ptcgdap/marnie_vertical_slice/marnie_portable_policy_v1.json", "B981C14562590E4FCFCF297148B6D317BFCA7FB5A5D6DB801A6C26CBC9802D8D"],
}
const FORBIDDEN_KEYS := [
	"search_begin_input", "raw_private_hash", "token_free_callback_hash",
	"callback_binding_hash", "private_engine_command", "private_object_refs",
]


class PolicyResult extends RefCounted:
	var _owner: Variant = null
	var _operation := ""
	var _argument: Variant = null
	var _snapshot: Dictionary = {}

	func _init(owner_value: Variant = null, operation_value: String = "", argument_value: Variant = null, snapshot_value: Dictionary = {}) -> void:
		_owner = owner_value
		_operation = operation_value
		_argument = argument_value
		_snapshot = snapshot_value.duplicate(true)

	func validate_integrity(owner_value: Variant) -> bool:
		return (
			_owner != null
			and owner_value == _owner
			and _owner.has_method("_validate_result")
			and bool(_owner._validate_result(self))
		)

	func to_public_dict() -> Dictionary:
		return _snapshot.duplicate(true) if validate_integrity(_owner) else {}


var _ok := false
var _error_code := "contract_integrity_invalid"
var _documents: Dictionary = {}
var _frames: Array = []
var _capability_owner: Variant = null
var _base_owner: Variant = null
var _document_integrity_sha256 := ""
var _load_attempted := false

var ok: bool:
	get:
		return _ok and validate_integrity()

var error_code: String:
	get:
		return "" if ok else _error_code


static func load_default() -> Variant:
	return load_from_root(DEFAULT_ROOT)


static func load_from_root(root_path: Variant) -> Variant:
	var script: GDScript = load("res://scripts/ai/ptcgdap/public/MarniePortablePolicy.gd")
	var result: RefCounted = script.new()
	if typeof(root_path) != TYPE_STRING:
		result._load_attempted = true
		result._fail("contract_path_invalid")
		return result
	result._load(str(root_path))
	return result


func _load(root_path: String) -> void:
	if _load_attempted:
		return
	_load_attempted = true
	var root := root_path.trim_suffix("/") + "/"
	if root == "/" or not _root_is_supported(root):
		_fail("contract_path_invalid")
		return
	var bundle_result := _read_json("%scontracts/ptcgdap/marnie_portable_policy_bundle.json" % root)
	if not bool(bundle_result.get("ok", false)):
		_fail("contract_integrity_invalid")
		return
	var bundle: Variant = bundle_result.get("value")
	var expected_parents: Array = []
	for parent_id: String in PARENT_ORDER:
		var spec: Array = PARENT_BUNDLES[parent_id]
		expected_parents.append({"id": parent_id, "path": spec[0], "canonical_sha256": spec[1]})
	if (
		not bundle is Dictionary
		or _canonical_sha256(bundle) != EXPECTED_BUNDLE_CANONICAL_SHA256
		or not _same_keys(bundle, ["schema_version", "contract_id", "status", "parents", "artifacts", "runtime_authority"])
		or bundle.get("schema_version") != 1
		or bundle.get("contract_id") != CONTRACT_ID
		or bundle.get("status") != "offline_shadow"
		or bundle.get("parents") != expected_parents
		or bundle.get("runtime_authority") != "offline_public_differential_only"
		or not bundle.get("artifacts") is Array
		or bundle.get("artifacts").size() != 4
	):
		_fail("contract_integrity_invalid")
		return
	var documents := {"bundle": bundle.duplicate(true)}
	var seen := {}
	for entry_value: Variant in bundle.get("artifacts"):
		if not entry_value is Dictionary or not _same_keys(entry_value, ["id", "path", "canonical_sha256"]):
			_fail("contract_integrity_invalid")
			return
		var artifact_id: Variant = entry_value.get("id")
		if typeof(artifact_id) != TYPE_STRING or seen.has(artifact_id) or not EXPECTED_ARTIFACTS.has(artifact_id):
			_fail("contract_integrity_invalid")
			return
		var expected: Array = EXPECTED_ARTIFACTS[artifact_id]
		if entry_value != {"id": artifact_id, "path": expected[0], "canonical_sha256": expected[1]} or not _is_safe_relative_path(expected[0]):
			_fail("contract_integrity_invalid")
			return
		var artifact_result := _read_json("%s%s" % [root, expected[0]])
		if not bool(artifact_result.get("ok", false)) or _canonical_sha256(artifact_result.get("value")) != expected[1]:
			_fail("contract_integrity_invalid")
			return
		documents[artifact_id] = _copy(artifact_result.get("value"))
		seen[artifact_id] = true
	if seen.size() != EXPECTED_ARTIFACTS.size() or _canonical_sha256(documents) != EXPECTED_DOCUMENT_INTEGRITY_SHA256:
		_fail("contract_integrity_invalid")
		return
	var expected_parent_hashes := {}
	for parent_id: String in PARENT_ORDER:
		var spec: Array = PARENT_BUNDLES[parent_id]
		expected_parent_hashes[parent_id] = spec[1]
		var parent_result := _read_json("%s%s" % [root, spec[0]])
		if not bool(parent_result.get("ok", false)) or _canonical_sha256(parent_result.get("value")) != spec[1]:
			_fail("parent_contract_invalid")
			return
	var profile_value: Variant = documents.get("profile")
	if not profile_value is Dictionary or profile_value.get("profile_id") != PROFILE_ID or profile_value.get("parent_bundle_hashes") != expected_parent_hashes:
		_fail("contract_integrity_invalid")
		return
	var capability_owner: Variant = CapabilityPolicyScript.load_from_root(root)
	var base_owner: Variant = PublicBaseScript.load_from_root(root)
	if (
		capability_owner == null or not bool(capability_owner.get("ok")) or capability_owner.bundle_hash() != PARENT_BUNDLES["marnie_capability_policy"][1]
		or base_owner == null or not bool(base_owner.get("ok")) or base_owner.bundle_hash() != PARENT_BUNDLES["marnie_public_base"][1]
	):
		_fail("parent_contract_invalid")
		return
	var capability_result: Variant = capability_owner.evaluate_all()
	var base_result: Variant = base_owner.evaluate_all()
	if (
		capability_result == null or not capability_result.validate_integrity(capability_owner)
		or base_result == null or not base_result.validate_integrity(base_owner)
	):
		_fail("parent_conformance_invalid")
		return
	var capability_frames: Array = capability_result.to_public_dict().get("frames", [])
	var base_cases: Array = []
	for case_value: Variant in base_result.to_public_dict().get("cases", []):
		if case_value is Dictionary and case_value.get("offline_seeded_extension") == false:
			base_cases.append(case_value.duplicate(true))
	var composed := _compose_frames(profile_value, capability_frames, base_cases)
	if not bool(composed.get("ok", false)):
		_fail(str(composed.get("error_code", "parent_conformance_invalid")))
		return
	var frames: Array = composed.get("value", [])
	if _canonical_sha256(frames) != EXPECTED_FRAME_SET_SHA256 or frames != documents.get("audit", {}).get("frames"):
		_fail("parent_conformance_invalid")
		return
	_documents = documents.duplicate(true)
	_frames = frames.duplicate(true)
	_capability_owner = capability_owner
	_base_owner = base_owner
	_document_integrity_sha256 = EXPECTED_DOCUMENT_INTEGRITY_SHA256
	_ok = true
	_error_code = ""
	if not validate_integrity():
		_fail("contract_integrity_invalid")


func _fail(code: String) -> void:
	_ok = false
	_error_code = code


func validate_integrity() -> bool:
	return (
		_ok
		and _document_integrity_sha256 == EXPECTED_DOCUMENT_INTEGRITY_SHA256
		and _capability_owner != null
		and _base_owner != null
		and _capability_owner.get_script() == CapabilityPolicyScript
		and _base_owner.get_script() == PublicBaseScript
		and _capability_owner.bundle_hash() == PARENT_BUNDLES["marnie_capability_policy"][1]
		and _base_owner.bundle_hash() == PARENT_BUNDLES["marnie_public_base"][1]
		and _canonical_sha256(_documents) == EXPECTED_DOCUMENT_INTEGRITY_SHA256
		and _canonical_sha256(_frames) == EXPECTED_FRAME_SET_SHA256
		and _frames == _documents.get("audit", {}).get("frames")
		and not _contains_forbidden(_frames)
	)


func bundle_hash() -> String:
	return EXPECTED_BUNDLE_CANONICAL_SHA256 if validate_integrity() else ""


func evaluate_all() -> Variant:
	if not validate_integrity():
		return null
	return PolicyResult.new(self, "evaluate_all", null, _expected_snapshot("evaluate_all", null))


func evaluate_frame(frame_id: Variant) -> Variant:
	if not validate_integrity() or typeof(frame_id) != TYPE_STRING:
		return null
	var expected := _expected_snapshot("evaluate_frame", frame_id)
	return null if expected.is_empty() else PolicyResult.new(self, "evaluate_frame", frame_id, expected)


func _validate_result(result: Variant) -> bool:
	if not validate_integrity() or result == null or not result is PolicyResult or result.get("_owner") != self:
		return false
	var expected := _expected_snapshot(str(result.get("_operation")), result.get("_argument"))
	return not expected.is_empty() and result.get("_snapshot") == expected


func _expected_snapshot(operation: String, argument: Variant) -> Dictionary:
	var selected: Array = []
	if operation == "evaluate_all" and argument == null:
		selected = _frames.duplicate(true)
	elif operation == "evaluate_frame" and typeof(argument) == TYPE_STRING:
		for frame_value: Variant in _frames:
			if frame_value is Dictionary and frame_value.get("frame_id") == argument:
				selected.append(frame_value.duplicate(true))
				break
	else:
		return {}
	if selected.is_empty():
		return {}
	return {
		"accepted": true,
		"frame_count": selected.size(),
		"chain_head": selected[-1].get("portable_trace_hash"),
		"frames": selected,
		"public_only": true,
		"authoritative": false,
		"execution_authority": false,
		"production_actions_used": false,
	}


func _frame(frame_id: String) -> Dictionary:
	var result: Variant = evaluate_frame(frame_id)
	if result == null or not result.validate_integrity(self):
		return {}
	return result.to_public_dict().get("frames", [])[0]


func verify_binding(input_value: Dictionary) -> Dictionary:
	if not validate_integrity() or not _same_keys(input_value, ["frame_id", "public_observation_hash", "window_id", "option_fingerprints"]):
		return _result(null, "input_type_invalid")
	for key: String in ["frame_id", "public_observation_hash", "window_id"]:
		if typeof(input_value.get(key)) != TYPE_STRING:
			return _result(null, "input_type_invalid")
	if not input_value.get("option_fingerprints") is Array:
		return _result(null, "input_type_invalid")
	for fingerprint: Variant in input_value.get("option_fingerprints"):
		if typeof(fingerprint) != TYPE_STRING:
			return _result(null, "input_type_invalid")
	var frame := _frame(input_value.get("frame_id"))
	if frame.is_empty():
		return _result(null, "frame_unknown")
	if frame.get("window_id") == null:
		return _result(null, "binding_not_applicable")
	for key: String in ["public_observation_hash", "window_id", "option_fingerprints"]:
		if input_value.get(key) != frame.get(key):
			return _result(null, "binding_mismatch")
	return _result({
		"binding_matches": true,
		"frame_id": frame.get("frame_id"),
		"portable_trace_hash": frame.get("portable_trace_hash"),
		"authoritative": false,
		"execution_authority": false,
	})


func inspect_tie_break(frame_id: String) -> Dictionary:
	if not validate_integrity():
		return _result(null, "contract_integrity_invalid")
	var frame := _frame(frame_id)
	if frame.is_empty():
		return _result(null, "frame_unknown")
	if frame.get("owner_route") != "base_final" or not frame.get("adapter_hint_indexes") is Array or frame.get("adapter_hint_indexes").size() < 2:
		return _result(null, "tie_break_not_applicable")
	return _result({
		"frame_id": frame.get("frame_id"),
		"node_id": frame.get("node_id"),
		"owner_route": frame.get("owner_route"),
		"option_fingerprints": _copy(frame.get("option_fingerprints")),
		"capability_proposal_indexes": _copy(frame.get("capability_proposal_indexes")),
		"adapter_hint_indexes": _copy(frame.get("adapter_hint_indexes")),
		"base_final_action": _copy(frame.get("action")),
		"parent_base_trace_hash": frame.get("parent_base_trace_hash"),
		"portable_trace_hash": frame.get("portable_trace_hash"),
		"authoritative": false,
		"execution_authority": false,
	})


func inspect_node(node_id: String) -> Dictionary:
	if not validate_integrity():
		return _result(null, "contract_integrity_invalid")
	for node_value: Variant in _documents.get("profile", {}).get("portable_nodes", []):
		if node_value is Dictionary and node_value.get("node_id") == node_id:
			var value: Dictionary = node_value.duplicate(true)
			value["authoritative"] = false
			value["execution_authority"] = false
			return _result(value)
	return _result(null, "unsupported_node")


func run(operation: Variant, input_value: Variant) -> Dictionary:
	if not validate_integrity():
		return _result(null, "contract_integrity_invalid")
	if typeof(operation) != TYPE_STRING or not input_value is Dictionary:
		return _result(null, "input_type_invalid")
	if operation == "evaluate_all":
		if not input_value.is_empty():
			return _result(null, "input_type_invalid")
		return _result(evaluate_all().to_public_dict())
	if operation == "evaluate_frame":
		if not _same_keys(input_value, ["frame_id"]) or typeof(input_value.get("frame_id")) != TYPE_STRING:
			return _result(null, "input_type_invalid")
		var evaluated: Variant = evaluate_frame(input_value.get("frame_id"))
		return _result(null, "frame_unknown") if evaluated == null else _result(evaluated.to_public_dict())
	if operation == "verify_binding":
		return verify_binding(input_value)
	if operation == "inspect_tie_break":
		if not _same_keys(input_value, ["frame_id"]) or typeof(input_value.get("frame_id")) != TYPE_STRING:
			return _result(null, "input_type_invalid")
		return inspect_tie_break(input_value.get("frame_id"))
	if operation == "inspect_node":
		if not _same_keys(input_value, ["node_id"]) or typeof(input_value.get("node_id")) != TYPE_STRING:
			return _result(null, "input_type_invalid")
		return inspect_node(input_value.get("node_id"))
	return _result(null, "operation_unknown")


func audit_snapshot() -> Dictionary:
	if not validate_integrity():
		return {}
	var summary: Dictionary = _documents.get("audit", {}).get("summary", {})
	return {
		"bundle_canonical_sha256": EXPECTED_BUNDLE_CANONICAL_SHA256,
		"document_integrity_sha256": EXPECTED_DOCUMENT_INTEGRITY_SHA256,
		"frame_set_sha256": EXPECTED_FRAME_SET_SHA256,
		"frame_count": summary.get("frame_count"),
		"base_owned_count": summary.get("base_owned_count"),
		"capability_owned_count": summary.get("capability_owned_count"),
		"terminal_lifecycle_count": summary.get("terminal_lifecycle_count"),
		"vector_count": _documents.get("vectors", {}).get("cases", []).size(),
		"execution_authority": false,
		"live_consumer": false,
		"portable_ready": false,
	}


static func _compose_frames(profile: Dictionary, capability_frames: Array, base_cases: Array) -> Dictionary:
	if capability_frames.size() != 13 or base_cases.size() != 13 or not profile.get("dispatch") is Array or profile.get("dispatch").size() != 13:
		return _result(null, "parent_conformance_invalid")
	var results: Array = []
	var previous: Variant = null
	for ordinal: int in range(13):
		var dispatch_value: Variant = profile.get("dispatch")[ordinal]
		var capability_value: Variant = capability_frames[ordinal]
		var base_value: Variant = base_cases[ordinal]
		if not dispatch_value is Dictionary or not capability_value is Dictionary or not base_value is Dictionary:
			return _result(null, "parent_conformance_invalid")
		var dispatch: Dictionary = dispatch_value
		var capability: Dictionary = capability_value
		var base: Dictionary = base_value
		var frame_id: Variant = dispatch.get("frame_id")
		if frame_id not in FRAME_IDS or capability.get("frame_id") != frame_id or base.get("source_frame_id") != frame_id or base.get("offline_seeded_extension") != false:
			return _result(null, "parent_conformance_invalid")
		var route: Variant = dispatch.get("owner_route")
		var action: Array = []
		var reason := ""
		var status := ""
		if route == "capability_initial_deck":
			if base.get("status") != "not_applicable" or base.get("reason_code") != "initial_no_window" or not capability.get("selected_card_ids") is Array:
				return _result(null, "parent_conformance_invalid")
			action = capability.get("selected_card_ids").duplicate(true)
			reason = "official_initial_deck_fixture"
			status = "action"
		elif route == "capability_optional_zero":
			if base.get("status") != "not_applicable" or base.get("reason_code") != "firewall_not_accepted" or capability.get("selected_indexes") != []:
				return _result(null, "parent_conformance_invalid")
			action = []
			reason = "deterministic_optional_zero"
			status = "action"
		elif route == "terminal_lifecycle":
			if capability.get("status") != "not_applicable_terminal" or base.get("reason_code") != "terminal_no_callback":
				return _result(null, "parent_conformance_invalid")
			action = []
			reason = "terminal_no_callback"
			status = "terminal_no_callback"
		elif route == "base_final":
			if base.get("status") != "orchestrated" or not base.get("selected_indexes") is Array:
				return _result(null, "parent_conformance_invalid")
			if capability.get("public_observation_hash") != base.get("public_observation_hash") or capability.get("window_id") != base.get("window_id"):
				return _result(null, "parent_conformance_invalid")
			action = base.get("selected_indexes").duplicate(true)
			reason = "base_final_decision"
			status = "action"
		else:
			return _result(null, "unsupported_node")
		var fingerprints_value: Variant = capability.get("option_fingerprints")
		if not fingerprints_value is Array:
			return _result(null, "parent_conformance_invalid")
		var fingerprints: Array = fingerprints_value.duplicate(true)
		var selected_fingerprints: Array = []
		for index_value: Variant in action:
			if typeof(index_value) != TYPE_INT or index_value < 0:
				return _result(null, "parent_conformance_invalid")
			if dispatch.get("output_domain") == "current_window_indexes":
				if index_value >= fingerprints.size():
					return _result(null, "parent_conformance_invalid")
				selected_fingerprints.append(fingerprints[index_value])
		var payload := {
			"ordinal": dispatch.get("ordinal"),
			"frame_id": frame_id,
			"capability_id": capability.get("capability_id"),
			"node_id": dispatch.get("node_id"),
			"owner_route": route,
			"output_domain": dispatch.get("output_domain"),
			"status": status,
			"reason_code": reason,
			"action": action,
			"public_observation_hash": capability.get("public_observation_hash"),
			"window_id": capability.get("window_id"),
			"option_fingerprints": fingerprints,
			"selected_option_fingerprints": selected_fingerprints,
			"capability_proposal_indexes": [] if capability.get("selected_indexes") == null else _copy(capability.get("selected_indexes")),
			"adapter_hint_indexes": _copy(base.get("adapter_indexes")),
			"parent_capability_decision_hash": capability.get("decision_hash"),
			"parent_base_result_hash": base.get("result_hash"),
			"parent_base_decision_audit_id": base.get("decision_audit_id") if route == "base_final" else null,
			"parent_base_trace_hash": base.get("trace_hash") if route == "base_final" else null,
			"previous_portable_trace_hash": previous,
			"public_only": true,
			"authoritative": false,
			"execution_authority": false,
		}
		var trace_hash := _domain_hash(payload)
		if trace_hash.is_empty():
			return _result(null, "parent_conformance_invalid")
		var frame: Dictionary = payload.duplicate(true)
		frame["portable_trace_hash"] = trace_hash
		if _contains_forbidden(frame):
			return _result(null, "parent_conformance_invalid")
		results.append(frame)
		previous = trace_hash
	return _result(results)


static func _domain_hash(payload: Dictionary) -> String:
	var canonical := CabtJsonTreeScript.canonicalize_artifact(payload, {"max_input_bytes": MAX_JSON_BYTES, "max_output_bytes": MAX_JSON_BYTES})
	if not bool(canonical.get("ok", false)):
		return ""
	var bytes: PackedByteArray = TRACE_PREFIX_UTF8_HEX.hex_decode()
	bytes.append_array(canonical.get("bytes", PackedByteArray()))
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _contains_forbidden(value: Variant) -> bool:
	if value is Dictionary:
		for key: Variant in value:
			if key in FORBIDDEN_KEYS or _contains_forbidden(value[key]):
				return true
	elif value is Array:
		for item: Variant in value:
			if _contains_forbidden(item):
				return true
	return false


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
		return _result(null, "contract_file_missing")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _result(null, "contract_file_missing")
	var length := file.get_length()
	if length < 1 or length > MAX_JSON_BYTES:
		return _result(null, "contract_file_too_large")
	var source_bytes := file.get_buffer(length)
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(source_bytes, {"max_input_bytes": MAX_JSON_BYTES, "max_output_bytes": MAX_JSON_BYTES})
	if not bool(canonical.get("ok", false)):
		return _result(null, "contract_json_invalid")
	var text := source_bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != source_bytes:
		return _result(null, "contract_json_invalid")
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _result(null, "contract_json_invalid")
	var state := {"ok": true}
	var restored: Variant = _restore_integer_tokens(parser.data, state)
	if not bool(state.get("ok", false)) or not restored is Dictionary:
		return _result(null, "contract_json_invalid")
	return _result(restored)


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
