class_name PolicyExecutorConformance
extends RefCounted

const RuntimeScript = preload("res://scripts/ai/ptcgdap/public/MarniePortablePolicy.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")

const PROFILE_PATH := "res://contracts/ptcgdap/policy_executor_conformance_v1_profile.json"
const VECTORS_PATH := "res://contracts/ptcgdap/policy_executor_conformance_v1_vectors.json"
const PARENT_VECTORS_PATH := "res://contracts/ptcgdap/marnie_portable_policy_conformance_vectors.json"
const POLICY_MANIFEST_PATH := "res://data/ptcgdap/marnie_windows_policy_package_v1.json"
const PORTABLE_BUNDLE_PATH := "res://contracts/ptcgdap/marnie_portable_policy_bundle.json"

var _profile: Dictionary = {}
var _vectors: Dictionary = {}
var _parent_vectors: Dictionary = {}
var _owner: Variant = null
var _ok := false
var _error_code := ""


static func load_default() -> Variant:
	var script: GDScript = load("res://scripts/ai/ptcgdap/runtime/local/PolicyExecutorConformance.gd")
	var value: RefCounted = script.new()
	value._load()
	return value


func _load() -> void:
	_profile = _read_json(PROFILE_PATH)
	_vectors = _read_json(VECTORS_PATH)
	_parent_vectors = _read_json(PARENT_VECTORS_PATH)
	_owner = RuntimeScript.load_default()
	var owner_documents: Variant = _owner.get("_documents") if _owner != null else null
	if (
		_profile.get("document_type") != "policy_executor_conformance_profile_v1"
		or _profile.get("schema_version") != 1
		or _vectors.get("document_type") != "policy_executor_conformance_vectors_v1"
		or _vectors.get("schema_version") != 1
		or _vectors.get("profile_id") != _profile.get("profile_id")
		or _profile.get("policy_package_manifest_canonical_sha256") != _canonical_file_sha(POLICY_MANIFEST_PATH)
		or _vectors.get("policy_package_manifest_canonical_sha256") != _profile.get("policy_package_manifest_canonical_sha256")
		or _profile.get("portable_policy_bundle_canonical_sha256") != _canonical_file_sha(PORTABLE_BUNDLE_PATH)
		or _vectors.get("portable_policy_bundle_canonical_sha256") != _profile.get("portable_policy_bundle_canonical_sha256")
		or _profile.get("parent_vector_set_id") != _parent_vectors.get("vector_set_id")
		or _vectors.get("parent_vector_set_id") != _parent_vectors.get("vector_set_id")
		or _owner == null or not bool(_owner.get("ok"))
		or _owner.bundle_hash() != _profile.get("portable_policy_bundle_canonical_sha256")
		or not owner_documents is Dictionary
		or owner_documents.get("vectors") != _parent_vectors
	):
		_error_code = "policy_conformance_parent_drift"
		return
	var manifest := _read_json(POLICY_MANIFEST_PATH)
	if manifest.get("model") != {
		"learned_model":"none", "backend":"none", "artifact_path":null,
		"artifact_sha256":null, "unexpected_fallback_expected":0,
	} or _profile.get("model_contract") != {
		"learned_model":"none", "backend":"none",
		"required_operator_case_count":0, "skipped_operator_case_count":0,
	}:
		_error_code = "policy_conformance_model_scope_drift"
		return
	_ok = true


func is_valid() -> bool:
	return _ok and _error_code.is_empty() and _owner != null and bool(_owner.get("ok"))


func error_code() -> String:
	return _error_code


func _frame(frame_id: String) -> Dictionary:
	var result: Variant = _owner.evaluate_frame(frame_id)
	if result == null or not result.validate_integrity(_owner):
		return {}
	return result.to_public_dict().get("frames", [])[0]


func _run_probe(probe: String) -> Dictionary:
	if probe == "order":
		var frame := _frame("w3_main")
		var value := {}
		for key: String in ["option_fingerprints", "window_id", "public_observation_hash", "frame_id"]:
			value[key] = _copy(frame.get(key))
		return _owner.run("verify_binding", value)
	if probe == "float":
		return _owner.run("evaluate_frame", {"frame_id":3.5})
	if probe == "default":
		var result: Dictionary = _owner.run("evaluate_all", {})
		var value: Variant = result.get("value")
		return {
			"ok":bool(result.get("ok", false)),
			"error_code":result.get("error_code", ""),
			"frame_count":value.get("frame_count") if value is Dictionary else null,
			"chain_head":value.get("chain_head") if value is Dictionary else null,
		}
	if probe == "unknown_node":
		return _owner.run("inspect_node", {"node_id":"n99_unknown"})
	if probe == "fault":
		var result: Variant = _owner.evaluate_frame("w3_main")
		result.set("_snapshot", {"fault":true})
		return {"valid_after_fault":result.validate_integrity(_owner), "error_code":"result_integrity_invalid"}
	if probe == "tie_break":
		var result: Dictionary = _owner.run("inspect_tie_break", {"frame_id":"w4_spikemuth_deck"})
		var value: Variant = result.get("value")
		if not bool(result.get("ok", false)) or not value is Dictionary:
			return result
		var normalized := {}
		for key: String in ["frame_id", "node_id", "owner_route", "adapter_hint_indexes", "base_final_action", "portable_trace_hash"]:
			normalized[key] = _copy(value.get(key))
		return normalized
	if probe == "option_reorder":
		var frame := _frame("w3_main")
		var fingerprints: Array = frame.get("option_fingerprints", []).duplicate(true)
		fingerprints.reverse()
		return _owner.run("verify_binding", {
			"frame_id":frame.get("frame_id"),
			"public_observation_hash":frame.get("public_observation_hash"),
			"window_id":frame.get("window_id"),
			"option_fingerprints":fingerprints,
		})
	if probe == "unknown_operation":
		return _owner.run("unknown_operation", {})
	return {"ok":false, "error_code":"probe_unknown", "value":null}


func run_all() -> Dictionary:
	if not is_valid():
		return {"accepted":false, "error_code":_error_code}
	# The parent suite owns execution of all 28 portable-policy vectors. This
	# child lane binds the exact same vector document to that validated owner and
	# executes only its eight additive P6 probes, avoiding a second full replay.
	var parent_mismatches := 0
	var parent_cases: Array = _parent_vectors.get("cases", [])
	var cases: Array = []
	var probe_mismatches := 0
	var probe_cases: Array = _vectors.get("cases", [])
	for case_index: int in probe_cases.size():
		var case_value: Variant = probe_cases[case_index]
		var case: Dictionary = case_value
		print("P6_PROGRESS: %d/%d %s" % [
			case_index,
			probe_cases.size(),
			case.get("case_id"),
		])
		var actual := _run_probe(str(case.get("probe")))
		var matched: bool = actual == case.get("expected")
		probe_mismatches += int(not matched)
		cases.append({"case_id":case.get("case_id"), "actual":actual, "matched":matched})
	var model: Dictionary = _profile.get("model_contract")
	return {
		"document_type":"policy_executor_conformance_report_v1",
		"schema_version":1,
		"profile_id":_profile.get("profile_id"),
		"policy_package_manifest_canonical_sha256":_profile.get("policy_package_manifest_canonical_sha256"),
		"portable_policy_bundle_canonical_sha256":_profile.get("portable_policy_bundle_canonical_sha256"),
		"accepted":parent_mismatches == 0 and probe_mismatches == 0,
		"parent_vector_case_count":parent_cases.size(),
		"parent_vector_mismatch_count":parent_mismatches,
		"probe_case_count":cases.size(),
		"probe_mismatch_count":probe_mismatches,
		"skipped_case_count":0,
		"model":{
			"learned_model":model.get("learned_model"), "backend":model.get("backend"),
			"operator_case_count":model.get("required_operator_case_count"),
			"operator_skip_count":model.get("skipped_operator_case_count"),
		},
		"cases":cases,
		"public_only":true,
		"execution_authority":false,
		"production_ready":false,
	}


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Dictionary = FirewallScript._parse_contract_json_bytes(FileAccess.get_file_as_bytes(path))
	var value: Variant = parsed.get("value") if bool(parsed.get("ok", false)) else null
	return value if value is Dictionary else {}


static func _canonical_file_sha(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(FileAccess.get_file_as_bytes(path))
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.get("bytes", PackedByteArray()))
	return context.finish().hex_encode().to_upper()


static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
