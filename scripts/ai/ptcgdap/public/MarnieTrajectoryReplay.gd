class_name MarnieTrajectoryReplay
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtObservationParserScript = preload("res://scripts/ai/ptcgdap/cabt/CabtObservationParser.gd")
const CabtSelectionWindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")
const MarnieVerticalSliceScript = preload("res://scripts/ai/ptcgdap/public/MarnieVerticalSlice.gd")
const PublicObservationFirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")

const DEFAULT_ROOT := "res://"
const MAX_JSON_BYTES := 2 * 1024 * 1024
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const EXPECTED_BUNDLE_CANONICAL_SHA256 := "E203A688BEC1AFFFABAAF06098361B3FAE04B84431F99AE75A19F891BFA9599F"
const EXPECTED_RUNTIME_INTEGRITY_SHA256 := "83913228EA51F82F57A39A9B4D01EF27AEF069D64B30BE073EB041F5B9E554FD"
const EXPECTED_PARENT_FIXTURE_SHA256 := "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425"
const EXPECTED_FIREWALL_SHA256 := "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"
const CHAIN_PREFIX_UTF8_HEX := "50544347444150004D41524E49455F5452414A4543544F52595F5245504C41595F563100"
const EXPECTED_ARTIFACTS := [
	["marnie_trajectory_replay.schema", "contracts/ptcgdap/marnie_trajectory_replay.schema.json", "schema"],
	["marnie_trajectory_replay_profile_v1", "contracts/ptcgdap/marnie_trajectory_replay_profile.json", "profile"],
	["marnie_trajectory_replay_conformance_v1", "contracts/ptcgdap/marnie_trajectory_replay_conformance_vectors.json", "vectors"],
	["w0_w7_firewall_replay_v1", "data/ptcgdap/marnie_vertical_slice/w0_w7_firewall_replay_v1.json", "replay"],
]
const FRAME_IDS := [
	"w0_initial", "w1_setup_active", "w2_setup_bench", "w3_main",
	"w4_spikemuth_deck", "w5_punk_up_sources", "w5_punk_up_target_1",
	"w5_punk_up_target_2", "w6_shadow_bullet_attack",
	"w6_shadow_bullet_target", "w7_take_prize", "w7_forced_send_out",
	"w7_terminal",
]


class ReplayResult extends RefCounted:
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
var _error_code := "replay_bundle_invalid"
var _bundle: Variant = {}
var _schema: Variant = {}
var _profile: Variant = {}
var _vectors: Variant = {}
var _replay: Variant = {}
var _parent_owner: Variant = null
var _firewall: Variant = null
var _contracts: Variant = null
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
	var script: GDScript = load("res://scripts/ai/ptcgdap/public/MarnieTrajectoryReplay.gd")
	var result: RefCounted = script.new()
	if typeof(root_path) != TYPE_STRING:
		result._load_attempted = true
		result._fail("replay_path_invalid")
		return result
	result._load(str(root_path))
	return result


func _load(root_path: String) -> void:
	if _load_attempted:
		return
	_load_attempted = true
	var root := root_path.trim_suffix("/") + "/"
	if root == "/" or not _root_is_supported(root):
		_fail("replay_path_invalid")
		return
	var bundle_result := _read_json("%scontracts/ptcgdap/marnie_trajectory_replay_bundle.json" % root)
	if not bool(bundle_result.get("ok", false)):
		_fail(str(bundle_result.get("error_code", "replay_bundle_invalid")))
		return
	var bundle: Variant = bundle_result.get("value")
	if not bundle is Dictionary or _canonical_sha256(bundle) != EXPECTED_BUNDLE_CANONICAL_SHA256:
		_fail("replay_bundle_trust_anchor_mismatch")
		return
	if (
		not _same_keys(bundle, ["schema_version","bundle_id","status","parent_fixture_bundle","base_firewall_bundle","artifacts","self_hash_policy"])
		or bundle.get("schema_version") != 1
		or bundle.get("bundle_id") != "ptcgdap-marnie-trajectory-replay-p5-wp2-v1"
		or bundle.get("status") != "offline_shadow_replay"
		or bundle.get("parent_fixture_bundle") != {"path":"contracts/ptcgdap/marnie_vertical_slice_bundle.json","canonical_sha256":EXPECTED_PARENT_FIXTURE_SHA256}
		or bundle.get("base_firewall_bundle") != {"path":"contracts/ptcgdap/cabt_public_firewall_bundle.json","canonical_sha256":EXPECTED_FIREWALL_SHA256}
		or bundle.get("self_hash_policy") != "bundle and bound artifacts do not contain the final bundle hash"
		or not bundle.get("artifacts") is Array
		or bundle.get("artifacts").size() != EXPECTED_ARTIFACTS.size()
	):
		_fail("replay_bundle_invalid")
		return
	var documents := {"bundle": bundle.duplicate(true)}
	var seen_paths := {}
	for index: int in EXPECTED_ARTIFACTS.size():
		var expected: Array = EXPECTED_ARTIFACTS[index]
		var entry_value: Variant = bundle.get("artifacts")[index]
		if not entry_value is Dictionary or not _same_keys(entry_value, ["id","path","canonical_sha256"]):
			_fail("replay_bundle_invalid")
			return
		var entry: Dictionary = entry_value
		if entry.get("id") != expected[0] or entry.get("path") != expected[1] or typeof(entry.get("canonical_sha256")) != TYPE_STRING or seen_paths.has(entry.get("path")):
			_fail("replay_bundle_invalid")
			return
		if not _is_safe_relative_path(str(entry.get("path"))):
			_fail("replay_path_invalid")
			return
		seen_paths[entry.get("path")] = true
		var artifact_result := _read_json("%s%s" % [root, entry.get("path")])
		if not bool(artifact_result.get("ok", false)):
			_fail(str(artifact_result.get("error_code", "replay_artifact_invalid")))
			return
		var artifact: Variant = artifact_result.get("value")
		if _canonical_sha256(artifact) != entry.get("canonical_sha256"):
			_fail("replay_artifact_hash_mismatch")
			return
		documents[expected[2]] = _copy(artifact)
	if documents.size() != 5 or _canonical_sha256(documents) != EXPECTED_RUNTIME_INTEGRITY_SHA256:
		_fail("replay_integrity_invalid")
		return

	var contract_root := "%scontracts/ptcgdap" % root
	var parent_owner: Variant = MarnieVerticalSliceScript.load_from_root(root)
	var firewall: Variant = PublicObservationFirewallScript.load_from_root(contract_root)
	var contracts: Variant = CabtContractSetScript.load_from_root(contract_root)
	if (
		parent_owner == null or not bool(parent_owner.get("ok"))
		or firewall == null or not bool(firewall.get("ok"))
		or contracts == null or not bool(contracts.get("ok")) or not contracts.validate_integrity()
	):
		_fail("parent_contract_invalid")
		return
	_bundle = documents["bundle"]
	_schema = documents["schema"]
	_profile = documents["profile"]
	_vectors = documents["vectors"]
	_replay = documents["replay"]
	_parent_owner = parent_owner
	_firewall = firewall
	_contracts = contracts
	_runtime_integrity_sha256 = EXPECTED_RUNTIME_INTEGRITY_SHA256
	var replayed := _replay_frames()
	if not bool(replayed.get("ok", false)):
		_fail(str(replayed.get("error_code", "replay_conformance_mismatch")))
		return
	if replayed.get("frames") != _replay.get("frames") or replayed.get("chain_head") != _replay.get("chain_head"):
		_fail("replay_conformance_mismatch")
		return
	_ok = true
	_error_code = ""


func _fail(code: String) -> void:
	_ok = false
	_error_code = code


func validate_integrity() -> bool:
	if (
		not _ok
		or _runtime_integrity_sha256 != EXPECTED_RUNTIME_INTEGRITY_SHA256
		or _parent_owner == null or not bool(_parent_owner.get("ok"))
		or _parent_owner.bundle_hash() != EXPECTED_PARENT_FIXTURE_SHA256
		or _firewall == null or not bool(_firewall.get("ok"))
		or _firewall.contract_hash != EXPECTED_FIREWALL_SHA256
		or _contracts == null or not bool(_contracts.get("ok")) or not _contracts.validate_integrity()
	):
		return false
	return _runtime_digest() == EXPECTED_RUNTIME_INTEGRITY_SHA256


func bundle_hash() -> String:
	return EXPECTED_BUNDLE_CANONICAL_SHA256 if validate_integrity() else ""


func replay_all() -> Variant:
	if not validate_integrity():
		return null
	return ReplayResult.new(self, "replay_all", null, _expected_snapshot("replay_all", null))


func replay_frame(frame_id: Variant) -> Variant:
	if not validate_integrity() or typeof(frame_id) != TYPE_STRING or _find_frame(str(frame_id)).is_empty():
		return null
	return ReplayResult.new(self, "replay_frame", str(frame_id), _expected_snapshot("replay_frame", str(frame_id)))


func _validate_result(result: Variant) -> bool:
	if not validate_integrity() or result == null or not result is ReplayResult or result.get("_owner") != self:
		return false
	var expected := _expected_snapshot(str(result.get("_operation")), result.get("_argument"))
	return not expected.is_empty() and result.get("_snapshot") == expected


func _expected_snapshot(operation: String, argument: Variant) -> Dictionary:
	if operation == "replay_all" and argument == null:
		return {
			"accepted": true, "frame_count": 13, "chain_head": _replay.get("chain_head"),
			"frames": _copy(_replay.get("frames", [])), "execution_authority": false,
		}
	if operation == "replay_frame" and typeof(argument) == TYPE_STRING:
		var frame := _find_frame(str(argument))
		if not frame.is_empty():
			return {"accepted":true,"frame_count":1,"chain_head":frame.get("witness_hash"),"frames":[frame],"execution_authority":false}
	return {}


func _find_frame(frame_id: String) -> Dictionary:
	if not _replay is Dictionary:
		return {}
	for frame_value: Variant in _replay.get("frames", []):
		if frame_value is Dictionary and frame_value.get("frame_id") == frame_id:
			return frame_value.duplicate(true)
	return {}


func probe_w2_mutation(field: Variant, value: Variant) -> Dictionary:
	if not validate_integrity():
		return _result(null, "replay_integrity_invalid")
	var allowed_fields := [
		"select_type", "select_context", "turn", "own_active", "max_count", "result",
		"remain_damage_counter", "remain_energy_cost", "select_deck", "context_card", "effect",
		"opponent_active", "opponent_hand", "own_prize", "opponent_draw_log",
	]
	if typeof(field) != TYPE_STRING or field not in allowed_fields:
		return _result(null, "input_type_invalid")
	var parent: Dictionary = _parent_owner.frame("w2_setup_bench")
	var public_tree: Variant = _decode_public_node(parent.get("public_tree"))
	if not public_tree is Dictionary:
		return _result(null, "parent_frame_invalid")
	match str(field):
		"select_type": public_tree.get("select")["type"] = _copy(value)
		"select_context": public_tree.get("select")["context"] = _copy(value)
		"turn": public_tree.get("current")["turn"] = _copy(value)
		"own_active":
			var acting := int(public_tree.get("current").get("yourIndex"))
			public_tree.get("current").get("players")[acting]["active"] = _copy(value)
		"max_count": public_tree.get("select")["maxCount"] = _copy(value)
		"result": public_tree.get("current")["result"] = _copy(value)
		"remain_damage_counter": public_tree.get("select")["remainDamageCounter"] = _copy(value)
		"remain_energy_cost": public_tree.get("select")["remainEnergyCost"] = _copy(value)
		"select_deck": public_tree.get("select")["deck"] = _copy(value)
		"context_card": public_tree.get("select")["contextCard"] = _copy(value)
		"effect": public_tree.get("select")["effect"] = _copy(value)
		"opponent_active", "opponent_hand", "own_prize", "opponent_draw_log":
			var acting := int(public_tree.get("current").get("yourIndex"))
			var opponent := 1 - acting
			if field == "opponent_active":
				public_tree.get("current").get("players")[opponent]["active"] = _copy(value)
			elif field == "opponent_hand":
				public_tree.get("current").get("players")[opponent]["hand"] = _copy(value)
			elif field == "own_prize":
				public_tree.get("current").get("players")[acting].get("prize")[0] = _copy(value)
			else:
				public_tree.get("logs").append(_copy(value))
	public_tree["search_begin_input"] = null
	var parsed: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(public_tree, _contracts)
	var evaluation: Dictionary = _firewall._evaluate_setup_bench_concealment(parsed)
	if evaluation.get("status") == "accepted" and evaluation.get("compatibility_rule") == "setup_bench_concealment_v1":
		return _result({"accepted": true})
	return _result(null, "setup_concealment_scope_mismatch")


func run(operation: Variant, input_value: Variant) -> Dictionary:
	if not validate_integrity():
		return _result(null, "replay_integrity_invalid")
	if typeof(operation) != TYPE_STRING or not input_value is Dictionary:
		return _result(null, "input_type_invalid")
	if operation == "replay_all":
		if not input_value.is_empty():
			return _result(null, "input_type_invalid")
		return _result(replay_all().to_public_dict())
	if operation == "replay_frame":
		if not _same_keys(input_value, ["frame_id"]) or typeof(input_value.get("frame_id")) != TYPE_STRING:
			return _result(null, "input_type_invalid")
		var selected: Variant = replay_frame(input_value.get("frame_id"))
		return _result(null, "frame_unknown") if selected == null else _result(selected.to_public_dict())
	if operation == "probe_w2_mutation":
		if not _same_keys(input_value, ["field","value"]):
			return _result(null, "input_type_invalid")
		return probe_w2_mutation(input_value.get("field"), input_value.get("value"))
	return _result(null, "operation_unknown")


func audit_snapshot() -> Dictionary:
	if not validate_integrity():
		return {}
	return {
		"bundle_canonical_sha256": EXPECTED_BUNDLE_CANONICAL_SHA256,
		"runtime_integrity_sha256": EXPECTED_RUNTIME_INTEGRITY_SHA256,
		"frame_count": 13, "execution_authority": false, "live_consumer": false,
	}


func _runtime_digest() -> String:
	if not (_bundle is Dictionary and _schema is Dictionary and _profile is Dictionary and _vectors is Dictionary and _replay is Dictionary):
		return ""
	return _canonical_sha256({"bundle":_copy(_bundle),"schema":_copy(_schema),"profile":_copy(_profile),"vectors":_copy(_vectors),"replay":_copy(_replay)})


func _replay_frames() -> Dictionary:
	var frames: Array = []
	var previous: Variant = null
	for ordinal: int in FRAME_IDS.size():
		var frame_result := _frame_summary(FRAME_IDS[ordinal], ordinal, previous)
		if not bool(frame_result.get("ok", false)):
			return frame_result
		var frame: Dictionary = frame_result.get("value")
		frames.append(frame)
		previous = frame.get("witness_hash")
	return {"ok":true,"error_code":"","frames":frames,"chain_head":previous}


func _frame_summary(frame_id: String, ordinal: int, previous_witness: Variant) -> Dictionary:
	var parent: Dictionary = _parent_owner.frame(frame_id)
	if parent.is_empty():
		return {"ok":false,"error_code":"parent_frame_invalid"}
	if parent.get("public_tree") == null:
		var terminal_value: Variant = parent.get("terminal")
		var parent_window_value: Variant = parent.get("window")
		if terminal_value != {"new_callback_expected":false,"final_step":145,"both_seats_done":true}:
			return {"ok":false,"error_code":"parent_frame_invalid"}
		if parent_window_value != null:
			return {"ok":false,"error_code":"parent_frame_invalid"}
		var terminal := {
			"ordinal":ordinal,"frame_id":frame_id,"source_replay_id":parent.get("source_replay_id"),
			"source_step":parent.get("source_step"),"source_seat":parent.get("source_seat"),
			"firewall_status":"not_applicable_terminal","compatibility_rule":null,
			"public_observation_hash":null,"public_hash_authority":null,"window_id":null,
			"option_count":0,"option_fingerprints":[],"own_active":null,"terminal":true,
			"previous_witness":previous_witness,
		}
		terminal["witness_hash"] = _witness(terminal)
		return {"ok":true,"error_code":"","value":terminal}
	var public_tree: Variant = _decode_public_node(parent.get("public_tree"))
	if not public_tree is Dictionary:
		return {"ok":false,"error_code":"parent_frame_invalid"}
	var raw: Dictionary = public_tree.duplicate(true)
	raw["search_begin_input"] = null
	var parsed: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(raw, _contracts)
	if parsed == null or not bool(parsed.get("policy_eligible")):
		return {"ok":false,"error_code":"parent_frame_invalid"}
	var base: Variant = _firewall.project(parsed)
	var evaluation: Dictionary = _firewall._evaluate_setup_bench_concealment(parsed)
	if evaluation.get("status") != "accepted" or evaluation.get("public_observation") != public_tree or evaluation.get("public_observation_hash") != parent.get("public_observation_hash"):
		return {"ok":false,"error_code":"firewall_replay_mismatch"}
	var compatibility: Variant = "setup_bench_concealment_v1" if frame_id == "w2_setup_bench" else null
	if evaluation.get("compatibility_rule") != compatibility:
		return {"ok":false,"error_code":"base_firewall_compatibility_mismatch"}
	if compatibility != null:
		var issues: Array = base.get("issues")
		if base.get("status") != "rejected" or issues != [{"code":"own_active_concealed","pointer":"/current/players/0/active","severity":"error"}]:
			return {"ok":false,"error_code":"base_firewall_compatibility_mismatch"}
	elif base.get("status") != "accepted":
		return {"ok":false,"error_code":"base_firewall_compatibility_mismatch"}
	var window_id: Variant = null
	var option_count := 0
	var fingerprints: Array = []
	var authority: Variant = null
	var select_value: Variant = public_tree.get("select")
	if select_value != null:
		var built: Variant = CabtSelectionWindowScript.build({
			"select": select_value,
			"public_observation_hash": evaluation.get("public_observation_hash"),
			"public_hash_authority": "firewall_accepted",
			"chooser_player_index": public_tree.get("current").get("yourIndex"),
		}, _contracts)
		if built == null or not CabtSelectionWindowScript.validate_build_result_integrity(built):
			return {"ok":false,"error_code":"window_replay_mismatch"}
		var window: Variant = built.get("window")
		if window == null or not window.validate_integrity():
			return {"ok":false,"error_code":"window_replay_mismatch"}
		var window_dict: Dictionary = window.to_public_dict()
		var parent_window: Variant = parent.get("window")
		if not parent_window is Dictionary or window_dict.get("window_id") != parent_window.get("window_id") or window_dict.get("option_fingerprints") != parent_window.get("option_fingerprints"):
			return {"ok":false,"error_code":"window_replay_mismatch"}
		window_id = window_dict.get("window_id")
		option_count = window_dict.get("options", []).size()
		fingerprints = window_dict.get("option_fingerprints", []).duplicate(true)
		authority = "firewall_accepted"
	elif parent.get("window") != null:
		return {"ok":false,"error_code":"window_replay_mismatch"}
	var own_active: Variant = null
	if compatibility != null:
		var acting := int(public_tree.get("current").get("yourIndex"))
		own_active = _copy(public_tree.get("current").get("players")[acting].get("active"))
	var summary := {
		"ordinal":ordinal,"frame_id":frame_id,"source_replay_id":parent.get("source_replay_id"),
		"source_step":parent.get("source_step"),"source_seat":parent.get("source_seat"),
		"firewall_status":"accepted","compatibility_rule":compatibility,
		"public_observation_hash":evaluation.get("public_observation_hash"),"public_hash_authority":authority,
		"window_id":window_id,"option_count":option_count,"option_fingerprints":fingerprints,
		"own_active":own_active,"terminal":false,"previous_witness":previous_witness,
	}
	summary["witness_hash"] = _witness(summary)
	return {"ok":true,"error_code":"","value":summary}


static func _witness(payload: Dictionary) -> String:
	var canonical := CabtJsonTreeScript.canonicalize_artifact(payload, {"max_input_bytes":MAX_JSON_BYTES,"max_output_bytes":MAX_JSON_BYTES})
	if not bool(canonical.get("ok", false)):
		return ""
	var bytes: PackedByteArray = CHAIN_PREFIX_UTF8_HEX.hex_decode()
	bytes.append_array(canonical.get("bytes", PackedByteArray()))
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _decode_public_node(node: Variant) -> Variant:
	if not node is Dictionary or typeof(node.get("kind")) != TYPE_STRING:
		return null
	match node.get("kind"):
		"null": return null
		"boolean", "integer", "string": return node.get("value")
		"binary64":
			var bytes: PackedByteArray = str(node.get("ieee754_hex", "")).hex_decode()
			if bytes.size() != 8:
				return null
			bytes.reverse()
			return bytes.decode_double(0)
		"array":
			if not node.get("items") is Array:
				return null
			var array: Array = []
			for child: Variant in node.get("items"):
				array.append(_decode_public_node(child))
			return array
		"object":
			if not node.get("entries") is Array:
				return null
			var object: Dictionary = {}
			for entry_value: Variant in node.get("entries"):
				if not entry_value is Dictionary or typeof(entry_value.get("key")) != TYPE_STRING or object.has(entry_value.get("key")):
					return null
				object[entry_value.get("key")] = _decode_public_node(entry_value.get("value"))
			return object
	return null


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
		return {"ok":false,"error_code":"replay_file_missing","value":null}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok":false,"error_code":"replay_file_missing","value":null}
	var length := file.get_length()
	if length < 1 or length > MAX_JSON_BYTES:
		return {"ok":false,"error_code":"replay_file_too_large","value":null}
	var source_bytes := file.get_buffer(length)
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(source_bytes, {"max_input_bytes":MAX_JSON_BYTES,"max_output_bytes":MAX_JSON_BYTES})
	if not bool(canonical.get("ok", false)):
		return {"ok":false,"error_code":"replay_json_invalid","value":null}
	var text := source_bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != source_bytes:
		return {"ok":false,"error_code":"replay_json_invalid","value":null}
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"ok":false,"error_code":"replay_json_invalid","value":null}
	var state := {"ok":true}
	var restored: Variant = _restore_integer_tokens(parser.data, state)
	if not bool(state.get("ok", false)) or not restored is Dictionary:
		return {"ok":false,"error_code":"replay_json_invalid","value":null}
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
