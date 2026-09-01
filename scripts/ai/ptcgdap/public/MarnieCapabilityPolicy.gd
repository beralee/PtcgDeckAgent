class_name MarnieCapabilityPolicy
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const MarnieVerticalSliceScript = preload("res://scripts/ai/ptcgdap/public/MarnieVerticalSlice.gd")
const MarnieTrajectoryReplayScript = preload("res://scripts/ai/ptcgdap/public/MarnieTrajectoryReplay.gd")

const DEFAULT_ROOT := "res://"
const MAX_JSON_BYTES := 2 * 1024 * 1024
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const EXPECTED_BUNDLE_CANONICAL_SHA256 := "F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C"
const EXPECTED_RUNTIME_INTEGRITY_SHA256 := "4CE8CE339F1C147C2E8A8CC44E70FB38B33551C2B1AF6C3E406C675F7BBEFACE"
const EXPECTED_FRAME_SET_SHA256 := "B9D6946F133C5AB9DD549B2A2B9B7D51AB7934E7AC4B9ECA2C479B78905C4E04"
const EXPECTED_PARENT_REPLAY_SHA256 := "E203A688BEC1AFFFABAAF06098361B3FAE04B84431F99AE75A19F891BFA9599F"
const EXPECTED_PARENT_FIXTURE_SHA256 := "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425"
const RESULT_PREFIX_UTF8_HEX := "50544347444150004D41524E49455F4341504142494C4954595F504F4C4943595F524553554C545F563100"
const EXPECTED_ARTIFACTS := [
	["marnie_capability_policy_schema_v1", "contracts/ptcgdap/marnie_capability_policy.schema.json", "schema"],
	["marnie_capability_policy_profile_v1", "contracts/ptcgdap/marnie_capability_policy_profile.json", "profile"],
	["marnie_capability_policy_rules_v1", "data/ptcgdap/marnie_vertical_slice/marnie_capability_policy_v1.json", "policy"],
	["marnie_capability_policy_vectors_v1", "contracts/ptcgdap/marnie_capability_policy_conformance_vectors.json", "vectors"],
]
const FRAME_IDS := [
	"w0_initial", "w1_setup_active", "w2_setup_bench", "w3_main",
	"w4_spikemuth_deck", "w5_punk_up_sources", "w5_punk_up_target_1",
	"w5_punk_up_target_2", "w6_shadow_bullet_attack", "w6_shadow_bullet_target",
	"w7_take_prize", "w7_forced_send_out", "w7_terminal",
]
const MUTATION_FIELDS := ["public_observation_hash", "window_id", "option_fingerprints", "options", "min_count"]


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
var _error_code := "policy_bundle_invalid"
var _bundle: Variant = {}
var _schema: Variant = {}
var _profile: Variant = {}
var _policy: Variant = {}
var _vectors: Variant = {}
var _parent_owner: Variant = null
var _replay_owner: Variant = null
var _expected_frames: Variant = []
var _runtime_integrity_sha256 := ""
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
	var script: GDScript = load("res://scripts/ai/ptcgdap/public/MarnieCapabilityPolicy.gd")
	var result: RefCounted = script.new()
	if typeof(root_path) != TYPE_STRING:
		result._load_attempted = true
		result._fail("policy_path_invalid")
		return result
	result._load(str(root_path))
	return result


func _load(root_path: String) -> void:
	if _load_attempted:
		return
	_load_attempted = true
	var root := root_path.trim_suffix("/") + "/"
	if root == "/" or not _root_is_supported(root):
		_fail("policy_path_invalid")
		return
	var bundle_result := _read_json("%scontracts/ptcgdap/marnie_capability_policy_bundle.json" % root)
	if not bool(bundle_result.get("ok", false)):
		_fail(str(bundle_result.get("error_code", "policy_bundle_invalid")))
		return
	var bundle: Variant = bundle_result.get("value")
	if not bundle is Dictionary or _canonical_sha256(bundle) != EXPECTED_BUNDLE_CANONICAL_SHA256:
		_fail("policy_bundle_trust_anchor_mismatch")
		return
	if (
		not _same_keys(bundle, ["schema_version","artifact_kind","bundle_id","status","parent_replay_bundle","parent_fixture_bundle","artifacts","self_hash_policy"])
		or bundle.get("schema_version") != 1
		or bundle.get("artifact_kind") != "bundle"
		or bundle.get("bundle_id") != "ptcgdap-marnie-capability-policy-p5-wp3-v1"
		or bundle.get("status") != "offline_shadow_policy"
		or bundle.get("parent_replay_bundle") != {"path":"contracts/ptcgdap/marnie_trajectory_replay_bundle.json","canonical_sha256":EXPECTED_PARENT_REPLAY_SHA256}
		or bundle.get("parent_fixture_bundle") != {"path":"contracts/ptcgdap/marnie_vertical_slice_bundle.json","canonical_sha256":EXPECTED_PARENT_FIXTURE_SHA256}
		or bundle.get("self_hash_policy") != "bundle and bound artifacts do not contain the final bundle hash"
		or not bundle.get("artifacts") is Array
		or bundle.get("artifacts").size() != EXPECTED_ARTIFACTS.size()
	):
		_fail("policy_bundle_invalid")
		return
	var documents := {"bundle": bundle.duplicate(true)}
	var seen_paths := {}
	for index: int in range(EXPECTED_ARTIFACTS.size()):
		var expected: Array = EXPECTED_ARTIFACTS[index]
		var entry_value: Variant = bundle.get("artifacts")[index]
		if not entry_value is Dictionary or not _same_keys(entry_value, ["id","path","canonical_sha256"]):
			_fail("policy_bundle_invalid")
			return
		var entry: Dictionary = entry_value
		if entry.get("id") != expected[0] or entry.get("path") != expected[1] or typeof(entry.get("canonical_sha256")) != TYPE_STRING or seen_paths.has(entry.get("path")):
			_fail("policy_bundle_invalid")
			return
		if not _is_safe_relative_path(str(entry.get("path"))):
			_fail("policy_path_invalid")
			return
		seen_paths[entry.get("path")] = true
		var artifact_result := _read_json("%s%s" % [root, entry.get("path")])
		if not bool(artifact_result.get("ok", false)):
			_fail(str(artifact_result.get("error_code", "policy_artifact_invalid")))
			return
		var artifact: Variant = artifact_result.get("value")
		if _canonical_sha256(artifact) != entry.get("canonical_sha256"):
			_fail("policy_artifact_hash_mismatch")
			return
		documents[expected[2]] = _copy(artifact)
	if documents.size() != 5 or _canonical_sha256(documents) != EXPECTED_RUNTIME_INTEGRITY_SHA256:
		_fail("policy_integrity_invalid")
		return
	var parent_owner: Variant = MarnieVerticalSliceScript.load_from_root(root)
	var replay_owner: Variant = MarnieTrajectoryReplayScript.load_from_root(root)
	if (
		parent_owner == null or not bool(parent_owner.get("ok")) or parent_owner.bundle_hash() != EXPECTED_PARENT_FIXTURE_SHA256
		or replay_owner == null or not bool(replay_owner.get("ok")) or replay_owner.bundle_hash() != EXPECTED_PARENT_REPLAY_SHA256
	):
		_fail("policy_parent_mismatch")
		return
	_parent_owner = parent_owner
	_replay_owner = replay_owner
	var built := _build_frames(parent_owner, replay_owner, documents.get("policy"))
	if not bool(built.get("ok", false)):
		_fail(str(built.get("error_code", "policy_conformance_mismatch")))
		return
	var frames: Array = built.get("value", [])
	if _canonical_sha256(frames) != EXPECTED_FRAME_SET_SHA256:
		_fail("policy_conformance_mismatch")
		return
	var positive := {}
	for case_value: Variant in documents.get("vectors", {}).get("cases", []):
		if not case_value is Dictionary or case_value.get("operation") != "evaluate_frame":
			continue
		var frame_id: Variant = case_value.get("input", {}).get("frame_id")
		if typeof(frame_id) == TYPE_STRING and frame_id in FRAME_IDS:
			positive[frame_id] = case_value.get("expected", {}).get("value", {}).get("frames", [])[0]
	var by_id := {}
	for frame_value: Variant in frames:
		by_id[frame_value.get("frame_id")] = frame_value
	if positive != by_id:
		_fail("policy_conformance_mismatch")
		return
	_bundle = documents["bundle"]
	_schema = documents["schema"]
	_profile = documents["profile"]
	_policy = documents["policy"]
	_vectors = documents["vectors"]
	_expected_frames = frames.duplicate(true)
	_runtime_integrity_sha256 = EXPECTED_RUNTIME_INTEGRITY_SHA256
	_ok = true
	_error_code = ""


func _fail(code: String) -> void:
	_ok = false
	_error_code = code


func validate_integrity() -> bool:
	if (
		not _ok
		or _runtime_integrity_sha256 != EXPECTED_RUNTIME_INTEGRITY_SHA256
		or _parent_owner == null or _parent_owner.get_script() != MarnieVerticalSliceScript
		or _replay_owner == null or _replay_owner.get_script() != MarnieTrajectoryReplayScript
		or _runtime_digest() != EXPECTED_RUNTIME_INTEGRITY_SHA256
		or not _expected_frames is Array
		or _canonical_sha256(_expected_frames) != EXPECTED_FRAME_SET_SHA256
	):
		return false
	return true


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
		selected = _expected_frames.duplicate(true)
	elif operation == "evaluate_frame" and typeof(argument) == TYPE_STRING:
		for frame_value: Variant in _expected_frames:
			if frame_value is Dictionary and frame_value.get("frame_id") == argument:
				selected.append(frame_value.duplicate(true))
				break
	else:
		return {}
	if selected.is_empty():
		return {}
	return {
		"accepted":true, "frame_count":selected.size(),
		"chain_head":selected[-1].get("decision_hash"), "frames":selected,
		"production_actions_used":false, "execution_authority":false,
	}


func probe_frame_mutation(frame_id: Variant, field: Variant, value: Variant) -> Dictionary:
	if not validate_integrity():
		return _result(null, "policy_integrity_invalid")
	if typeof(frame_id) != TYPE_STRING or typeof(field) != TYPE_STRING or field not in MUTATION_FIELDS:
		return _result(null, "input_type_invalid")
	var frame: Dictionary = _parent_owner.frame(frame_id)
	if frame.is_empty():
		return _result(null, "frame_unknown")
	var mutated := frame.duplicate(true)
	var window_value: Variant = mutated.get("window")
	if field == "public_observation_hash":
		mutated["public_observation_hash"] = _copy(value)
	elif not window_value is Dictionary:
		return _result(null, "frame_binding_mismatch")
	elif field == "options" and value == "reverse":
		window_value["options"].reverse()
	else:
		window_value[field] = _copy(value)
	return _result(null, "frame_binding_mismatch" if mutated != frame else "policy_integrity_invalid")


func run(operation: Variant, input_value: Variant) -> Dictionary:
	if not validate_integrity():
		return _result(null, "policy_integrity_invalid")
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
	if operation == "probe_frame_mutation":
		if not _same_keys(input_value, ["frame_id","field","value"]):
			return _result(null, "input_type_invalid")
		return probe_frame_mutation(input_value.get("frame_id"), input_value.get("field"), input_value.get("value"))
	return _result(null, "operation_unknown")


func audit_snapshot() -> Dictionary:
	if not validate_integrity():
		return {}
	return {
		"bundle_canonical_sha256":EXPECTED_BUNDLE_CANONICAL_SHA256,
		"runtime_integrity_sha256":EXPECTED_RUNTIME_INTEGRITY_SHA256,
		"frame_set_sha256":EXPECTED_FRAME_SET_SHA256,
		"artifact_count":EXPECTED_ARTIFACTS.size(), "frame_count":FRAME_IDS.size(),
		"vector_count":_vectors.get("cases", []).size(), "production_actions_used":false,
		"execution_authority":false, "live_consumer":false, "portable_ready":false,
	}


func _runtime_digest() -> String:
	if not (_bundle is Dictionary and _schema is Dictionary and _profile is Dictionary and _policy is Dictionary and _vectors is Dictionary):
		return ""
	return _canonical_sha256({"bundle":_copy(_bundle),"schema":_copy(_schema),"profile":_copy(_profile),"policy":_copy(_policy),"vectors":_copy(_vectors)})


static func _build_frames(parent_owner: Variant, replay_owner: Variant, policy_value: Variant) -> Dictionary:
	if not policy_value is Dictionary or not policy_value.get("rules") is Array or not policy_value.get("initial_deck_card_ids") is Array:
		return {"ok":false,"error_code":"policy_integrity_invalid","value":null}
	var rules := {}
	for rule_value: Variant in policy_value.get("rules"):
		if not rule_value is Dictionary or typeof(rule_value.get("frame_id")) != TYPE_STRING or rules.has(rule_value.get("frame_id")):
			return {"ok":false,"error_code":"policy_integrity_invalid","value":null}
		rules[rule_value.get("frame_id")] = rule_value
	if rules.keys().size() != FRAME_IDS.size():
		return {"ok":false,"error_code":"policy_integrity_invalid","value":null}
	var frames: Array = []
	var previous: Variant = null
	for ordinal: int in range(FRAME_IDS.size()):
		var frame_id: String = FRAME_IDS[ordinal]
		if not rules.has(frame_id):
			return {"ok":false,"error_code":"policy_integrity_invalid","value":null}
		var frame: Dictionary = parent_owner.frame(frame_id)
		var replay_result: Variant = replay_owner.replay_frame(frame_id)
		if frame.is_empty() or replay_result == null or not replay_result.validate_integrity(replay_owner):
			return {"ok":false,"error_code":"frame_binding_mismatch","value":null}
		var replay_frame: Dictionary = replay_result.to_public_dict().get("frames", [])[0]
		var window_value: Variant = frame.get("window")
		var window_id: Variant = null if window_value == null else window_value.get("window_id")
		var fingerprints: Array = [] if window_value == null else window_value.get("option_fingerprints", []).duplicate(true)
		if replay_frame.get("public_observation_hash") != frame.get("public_observation_hash") or replay_frame.get("window_id") != window_id or replay_frame.get("option_fingerprints") != fingerprints:
			return {"ok":false,"error_code":"frame_binding_mismatch","value":null}
		var selection := _select(rules[frame_id], frame, policy_value.get("initial_deck_card_ids"))
		if not bool(selection.get("ok", false)):
			return selection
		var selected: Dictionary = selection.get("value")
		var decision := {
			"ordinal":ordinal, "frame_id":frame_id, "capability_id":rules[frame_id].get("capability_id"),
			"capability_state":"source_locked_fixture_only", "status":selected.get("status"),
			"reason_code":selected.get("reason_code"), "rule_id":rules[frame_id].get("rule_id"),
			"selection_domain":selected.get("selection_domain"), "selected_indexes":_copy(selected.get("selected_indexes")),
			"selected_card_ids":_copy(selected.get("selected_card_ids")), "public_observation_hash":frame.get("public_observation_hash"),
			"window_id":window_id, "option_fingerprints":fingerprints, "previous_decision_hash":previous,
			"production_action_used":false, "execution_authority":false,
		}
		decision["decision_hash"] = _decision_hash(decision)
		if str(decision.get("decision_hash")).is_empty():
			return {"ok":false,"error_code":"policy_integrity_invalid","value":null}
		previous = decision.get("decision_hash")
		frames.append(decision)
	return {"ok":true,"error_code":"","value":frames}


static func _select(rule: Dictionary, frame: Dictionary, deck_ids: Array) -> Dictionary:
	var rule_id: Variant = rule.get("rule_id")
	var window_value: Variant = frame.get("window")
	if rule_id == "official_initial_deck":
		return {"ok":true,"error_code":"","value":{"status":"accepted","reason_code":"official_initial_deck_fixture","selection_domain":"initial_deck_card_ids","selected_indexes":null,"selected_card_ids":deck_ids.duplicate(true)}}
	if rule_id == "terminal_no_callback":
		return {"ok":true,"error_code":"","value":{"status":"not_applicable_terminal","reason_code":"terminal_no_callback","selection_domain":"none","selected_indexes":null,"selected_card_ids":null}}
	if not window_value is Dictionary:
		return {"ok":false,"error_code":"frame_binding_mismatch","value":null}
	var window: Dictionary = window_value
	var indexes: Array = []
	if rule_id == "optional_zero":
		indexes = []
	elif rule_id == "first_min":
		if typeof(window.get("min_count")) != TYPE_INT:
			return {"ok":false,"error_code":"frame_binding_mismatch","value":null}
		for index: int in range(int(window.get("min_count"))):
			indexes.append(index)
	elif rule_id == "public_deck_card_id" or rule_id == "all_public_deck_card_id":
		var candidates: Variant = window.get("public_deck_candidates")
		if not candidates is Array or not window.get("options") is Array:
			return {"ok":false,"error_code":"frame_binding_mismatch","value":null}
		var matches: Array = []
		for option_index: int in range(window.get("options").size()):
			var option_value: Variant = window.get("options")[option_index]
			if not option_value is Dictionary or typeof(option_value.get("index")) != TYPE_INT or option_value.get("index") < 0 or option_value.get("index") >= candidates.size():
				return {"ok":false,"error_code":"frame_binding_mismatch","value":null}
			var candidate: Variant = candidates[option_value.get("index")]
			if candidate is Dictionary and candidate.get("id") == rule.get("target_official_id"):
				matches.append(option_index)
		indexes = matches.slice(0, 1) if rule_id == "public_deck_card_id" else matches.slice(0, int(window.get("max_count", 0)))
	elif rule_id == "official_attack_id":
		if not window.get("options") is Array:
			return {"ok":false,"error_code":"frame_binding_mismatch","value":null}
		for option_index: int in range(window.get("options").size()):
			var option_value: Variant = window.get("options")[option_index]
			if option_value is Dictionary and option_value.get("attackId") == rule.get("target_official_id"):
				indexes.append(option_index)
				break
	else:
		return {"ok":false,"error_code":"policy_integrity_invalid","value":null}
	if typeof(window.get("min_count")) != TYPE_INT or typeof(window.get("max_count")) != TYPE_INT or not window.get("options") is Array:
		return {"ok":false,"error_code":"frame_binding_mismatch","value":null}
	if indexes.size() < window.get("min_count") or indexes.size() > window.get("max_count"):
		return {"ok":false,"error_code":"frame_binding_mismatch","value":null}
	var unique := {}
	for index_value: Variant in indexes:
		if typeof(index_value) != TYPE_INT or index_value < 0 or index_value >= window.get("options").size() or unique.has(index_value):
			return {"ok":false,"error_code":"frame_binding_mismatch","value":null}
		unique[index_value] = true
	return {"ok":true,"error_code":"","value":{"status":"accepted","reason_code":"deterministic_policy_selected","selection_domain":"current_window_indexes","selected_indexes":indexes,"selected_card_ids":null}}


static func _decision_hash(payload: Dictionary) -> String:
	var canonical := CabtJsonTreeScript.canonicalize_artifact(payload, {"max_input_bytes":MAX_JSON_BYTES,"max_output_bytes":MAX_JSON_BYTES})
	if not bool(canonical.get("ok", false)):
		return ""
	var bytes: PackedByteArray = RESULT_PREFIX_UTF8_HEX.hex_decode()
	bytes.append_array(canonical.get("bytes", PackedByteArray()))
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _result(value: Variant, error: String = "") -> Dictionary:
	return {"ok":error.is_empty(),"error_code":error,"value":_copy(value) if error.is_empty() else null}


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
		return {"ok":false,"error_code":"policy_file_missing","value":null}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok":false,"error_code":"policy_file_missing","value":null}
	var length := file.get_length()
	if length < 1 or length > MAX_JSON_BYTES:
		return {"ok":false,"error_code":"policy_file_too_large","value":null}
	var source_bytes := file.get_buffer(length)
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(source_bytes, {"max_input_bytes":MAX_JSON_BYTES,"max_output_bytes":MAX_JSON_BYTES})
	if not bool(canonical.get("ok", false)):
		return {"ok":false,"error_code":"policy_json_invalid","value":null}
	var text := source_bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != source_bytes:
		return {"ok":false,"error_code":"policy_json_invalid","value":null}
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"ok":false,"error_code":"policy_json_invalid","value":null}
	var state := {"ok":true}
	var restored: Variant = _restore_integer_tokens(parser.data, state)
	if not bool(state.get("ok", false)) or not restored is Dictionary:
		return {"ok":false,"error_code":"policy_json_invalid","value":null}
	return {"ok":true,"error_code":"","value":restored}


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
	var canonical := CabtJsonTreeScript.canonicalize_artifact(value, {"max_input_bytes":MAX_JSON_BYTES,"max_output_bytes":MAX_JSON_BYTES})
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(canonical.get("bytes", PackedByteArray())) != OK:
		return ""
	return context.finish().hex_encode().to_upper()
