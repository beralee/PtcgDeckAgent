class_name TestStrategicTraceV2
extends TestBase

const RuntimeScript = preload("res://scripts/ai/ptcgdap/public/StrategicTraceV2.gd")
const StrategicContextScript = preload("res://scripts/ai/ptcgdap/public/StrategicContextV18.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtObservationParserScript = preload("res://scripts/ai/ptcgdap/cabt/CabtObservationParser.gd")
const CabtSelectionWindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")
const CabtSelectionSanitizerScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionSanitizer.gd")

const VECTOR_PATH := "res://contracts/ptcgdap/strategic_trace_v2_conformance_vectors.json"
const P4_VECTOR_PATH := "res://contracts/ptcgdap/strategic_context_v18_conformance_vectors.json"
const FIREWALL_VECTOR_PATH := "res://contracts/ptcgdap/cabt_public_firewall_conformance_vectors.json"
const CONTRACT_ROOT := "res://contracts/ptcgdap"
const TEMP_ROOT := "user://ptcgdap_strategic_trace_v2_contract"
const CONTRACT_FILES := [
	"strategic_trace_v2.schema.json",
	"strategic_trace_v2_profile.json",
	"strategic_trace_v2_conformance_vectors.json",
	"strategic_trace_v2_bundle.json",
]
const PRIVATE_SENTINEL := "PRIVATE_GODOT_TRACE_SENTINEL"


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	return true


func _read_contract(path: String) -> Dictionary:
	var parsed: Dictionary = FirewallScript._parse_contract_json_bytes(_read_bytes(path))
	var value: Variant = parsed.get("value") if bool(parsed.get("ok", false)) else null
	return value if value is Dictionary else {}


func _copy_json(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


func _apply_path_mutation(root: Variant, mutation: Dictionary) -> void:
	var path: Array = mutation.get("path", [])
	var parent: Variant = root
	for index: int in range(path.size() - 1):
		parent = parent[path[index]]
	var key: Variant = path[-1]
	match str(mutation.get("op")):
		"set": parent[key] = _copy_json(mutation.get("value"))
		"delete": parent.erase(key)
		"append": parent[key].append(_copy_json(mutation.get("value")))


func _firewall_result(case_id: String) -> Variant:
	var vectors := _read_contract(FIREWALL_VECTOR_PATH)
	var spec: Dictionary = {}
	for value: Variant in vectors.get("cases", []):
		if value is Dictionary and value.get("id") == case_id:
			spec = value
			break
	var raw: Dictionary = vectors.get("base_observations", {}).get(spec.get("base"), {}).duplicate(true)
	for mutation: Variant in spec.get("mutations", []):
		_apply_path_mutation(raw, mutation)
	var parsed: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(raw, CabtContractSetScript.load_default())
	return FirewallScript.load_default().project(parsed)


func _window(firewall_result: Variant) -> Variant:
	var public: Dictionary = firewall_result.get("public_observation")
	var current: Dictionary = public.get("current")
	var built: Variant = CabtSelectionWindowScript.build(
		{
			"public_observation_hash": firewall_result.get("public_observation_hash"),
			"public_hash_authority": "firewall_accepted",
			"chooser_player_index": current.get("yourIndex"),
			"select": public.get("select").duplicate(true),
		},
		CabtContractSetScript.load_default(),
	)
	return built.get("window")


func _owners() -> Dictionary:
	var firewall_result: Variant = _firewall_result("regular-accepted")
	var window: Variant = _window(firewall_result)
	var context_result: Variant = StrategicContextScript.build_context(firewall_result, window)
	var context: Variant = context_result.get("context")
	var p4_vectors := _read_contract(P4_VECTOR_PATH)
	var spec: Dictionary = p4_vectors.get("decision_cases", [])[0]
	var resolution: Variant = CabtSelectionSanitizerScript.resolve_policy_attempt(
		window,
		{"status": "returned", "output": spec.get("selected_indexes").duplicate(true)},
	)
	var decision_result: Variant = StrategicContextScript.build_policy_decision(
		context,
		window,
		resolution,
		spec.get("policy_hash"),
		spec.get("scene_id"),
		spec.get("decision_id"),
		spec.get("determinism_key"),
	)
	return {"context": context, "decision": decision_result.get("decision")}


func _mutate_ir(document: Dictionary, mutation: Dictionary) -> Dictionary:
	var value := document.duplicate(true)
	match str(mutation.get("kind")):
		"replace_operator": value["nodes"][mutation.get("node_index")]["operator"] = mutation.get("value")
		"replace_owner": value["nodes"][mutation.get("node_index")]["owner"] = mutation.get("value")
		"replace_config": value["nodes"][mutation.get("node_index")]["config"] = _copy_json(mutation.get("value"))
		"replace_next": value["nodes"][mutation.get("node_index")]["next_node_ids"] = _copy_json(mutation.get("value"))
		"remove_node": value["nodes"].remove_at(mutation.get("node_index"))
		"append_capability": value["required_capabilities"].append(mutation.get("value"))
		"replace_node_id": value["nodes"][mutation.get("node_index")]["node_id"] = mutation.get("value")
	return value


func _mutate_trace_input(spec: Dictionary, mutation: Dictionary) -> Dictionary:
	var trace_id: Variant = spec.get("trace_id")
	var audit: Dictionary = spec.get("audit").duplicate(true)
	match str(mutation.get("kind")):
		"replace_strategic": audit["strategic_indexes"] = _copy_json(mutation.get("value"))
		"replace_mandatory": audit["mandatory_indexes"] = _copy_json(mutation.get("value"))
		"replace_terminal": audit["terminal_indexes"] = _copy_json(mutation.get("value"))
		"swap_best_tier": audit["base_hard_tiers"] = [{"index": 0, "tier": [1]}, {"index": 1, "tier": [0]}]
		"replace_vetoed": audit["base_vetoed_indexes"] = _copy_json(mutation.get("value"))
		"replace_proposals": audit["adapter_proposals"] = _copy_json(mutation.get("value"))
		"replace_trace_id": trace_id = mutation.get("value")
	return {"trace_id": trace_id, "audit": audit}


func test_all_shared_ir_cases_compile_exactly() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	for spec: Variant in vectors.get("ir_cases", []):
		var built: Variant = RuntimeScript.compile_ir(spec.get("document").duplicate(true))
		if not built.get("accepted"):
			return "%s rejected: %s" % [spec.get("id"), built.get("error_code")]
		var ir: Variant = built.get("ir")
		if not ir.validate_integrity() or ir.to_public_dict() != spec.get("expected_ir"):
			return "%s IR mismatch/integrity" % spec.get("id")
	return ""


func test_all_shared_ir_rejections_fail_closed() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var base: Dictionary = vectors.get("ir_cases", [])[0].get("document")
	for spec: Variant in vectors.get("ir_rejections", []):
		var built: Variant = RuntimeScript.compile_ir(_mutate_ir(base, spec.get("mutation")))
		if built.get("accepted") or built.get("ir") != null:
			return "%s unexpectedly accepted" % spec.get("id")
		if built.get("error_code") != spec.get("expected_error_code"):
			return "%s error mismatch: %s" % [spec.get("id"), built.get("error_code")]
	return ""


func test_all_shared_trace_cases_build_exactly() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var owners := _owners()
	var ir_by_id := {}
	for spec: Variant in vectors.get("ir_cases", []):
		ir_by_id[spec.get("id")] = RuntimeScript.compile_ir(spec.get("document").duplicate(true)).get("ir")
	for spec: Variant in vectors.get("trace_cases", []):
		var ir: Variant = ir_by_id.get(spec.get("ir_case_id"))
		var built: Variant = RuntimeScript.build_trace(owners.get("context"), owners.get("decision"), ir, spec.get("trace_id"), spec.get("audit").duplicate(true))
		if not built.get("accepted"):
			return "%s rejected: %s" % [spec.get("id"), built.get("error_code")]
		var trace: Variant = built.get("trace")
		if not trace.validate_integrity(owners.get("context"), owners.get("decision"), ir):
			return "%s trace integrity failed" % spec.get("id")
		if trace.to_public_dict() != spec.get("expected_trace"):
			return "%s trace mismatch" % spec.get("id")
	return ""


func test_all_shared_trace_rejections_fail_closed() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var owners := _owners()
	var ir: Variant = RuntimeScript.compile_ir(vectors.get("ir_cases", [])[0].get("document").duplicate(true)).get("ir")
	var base: Dictionary = vectors.get("trace_cases", [])[0]
	for spec: Variant in vectors.get("trace_rejections", []):
		var values := _mutate_trace_input(base, spec.get("mutation"))
		var built: Variant = RuntimeScript.build_trace(owners.get("context"), owners.get("decision"), ir, values.get("trace_id"), values.get("audit"))
		if built.get("accepted") or built.get("trace") != null:
			return "%s unexpectedly accepted" % spec.get("id")
		if built.get("error_code") != spec.get("expected_error_code"):
			return "%s error mismatch: %s" % [spec.get("id"), built.get("error_code")]
	return ""


func test_ordinary_construction_mutation_copy_and_stale_binding_fail_closed() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var owners := _owners()
	var ir: Variant = RuntimeScript.compile_ir(vectors.get("ir_cases", [])[0].get("document").duplicate(true)).get("ir")
	var spec: Dictionary = vectors.get("trace_cases", [])[0]
	var trace: Variant = RuntimeScript.build_trace(owners.get("context"), owners.get("decision"), ir, spec.get("trace_id"), spec.get("audit").duplicate(true)).get("trace")
	var runtime_script: GDScript = load(
		"res://scripts/ai/ptcgdap/public/StrategicTraceV2.gd"
	)
	var constants := runtime_script.get_script_constant_map()
	var direct_ir: Variant = constants.get("RestrictedIrValue").new(spec, spec, null)
	var direct_trace: Variant = constants.get("StrategicTraceValue").new(spec, spec, owners.get("context"), owners.get("decision"), ir, null)
	if direct_ir.validate_integrity() or not direct_ir.to_public_dict().is_empty():
		return "direct IR construction gained authority"
	if direct_trace.validate_integrity(owners.get("context"), owners.get("decision"), ir) or not direct_trace.to_public_dict().is_empty():
		return "direct trace construction gained authority"
	var copy_value: Dictionary = trace.to_public_dict()
	copy_value["frontier"]["legal_indexes"].append(999999)
	if not trace.validate_integrity(owners.get("context"), owners.get("decision"), ir) or JSON.stringify(trace.to_public_dict()).contains("999999"):
		return "copy mutation affected trace"
	trace.set("_snapshot", {"private": PRIVATE_SENTINEL})
	if trace.validate_integrity(owners.get("context"), owners.get("decision"), ir) or not trace.to_public_dict().is_empty():
		return "mutated trace remained valid/serialized"
	var other := _owners()
	var fresh: Variant = RuntimeScript.build_trace(owners.get("context"), owners.get("decision"), ir, "fresh-trace", spec.get("audit").duplicate(true)).get("trace")
	if fresh.validate_integrity(other.get("context"), other.get("decision"), ir):
		return "trace rebound across contexts"
	ir.set("_snapshot", {"callable": PRIVATE_SENTINEL})
	if ir.validate_integrity() or not ir.to_public_dict().is_empty():
		return "mutated IR remained valid/serialized"
	return ""


func test_variant_traps_and_private_values_fail_closed() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var document: Dictionary = vectors.get("ir_cases", [])[0].get("document").duplicate(true)
	document["nodes"][0]["node_id"] = &"string_name"
	if RuntimeScript.compile_ir(document).get("accepted"):
		return "StringName node id accepted"
	document = vectors.get("ir_cases", [])[0].get("document").duplicate(true)
	document["nodes"][1]["config"]["mandatory_precedence"] = 1
	if RuntimeScript.compile_ir(document).get("accepted"):
		return "integer-as-bool config accepted"
	document = vectors.get("ir_cases", [])[0].get("document").duplicate(true)
	document["graph_id"] = PRIVATE_SENTINEL
	if RuntimeScript.compile_ir(document).get("accepted"):
		return "private identifier accepted"
	var owners := _owners()
	var ir: Variant = RuntimeScript.compile_ir(vectors.get("ir_cases", [])[0].get("document").duplicate(true)).get("ir")
	var audit: Dictionary = vectors.get("trace_cases", [])[0].get("audit").duplicate(true)
	audit["legal_indexes"] = PackedInt32Array([0, 1])
	if RuntimeScript.build_trace(owners.get("context"), owners.get("decision"), ir, "packed", audit).get("accepted"):
		return "PackedInt32Array indexes accepted"
	audit = vectors.get("trace_cases", [])[0].get("audit").duplicate(true)
	audit["adapter_proposals"] = [{"operator": "tiebreak_score", "indexes": [0], "reason_code": PRIVATE_SENTINEL}]
	if RuntimeScript.build_trace(owners.get("context"), owners.get("decision"), ir, "private", audit).get("accepted"):
		return "private/free-form reason accepted"
	return ""


func test_contract_whitespace_is_allowed_but_semantic_drift_is_rejected() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	for name: String in CONTRACT_FILES:
		if not _write_bytes("%s/%s" % [TEMP_ROOT, name], _read_bytes("%s/%s" % [CONTRACT_ROOT, name])):
			return "failed to copy %s" % name
	var profile_path := "%s/strategic_trace_v2_profile.json" % TEMP_ROOT
	var profile_bytes := _read_bytes(profile_path)
	profile_bytes.append_array(" \n".to_utf8_buffer())
	if not _write_bytes(profile_path, profile_bytes):
		return "failed to append whitespace"
	var vectors := _read_contract(VECTOR_PATH)
	if not RuntimeScript.compile_ir(vectors.get("ir_cases", [])[0].get("document").duplicate(true), TEMP_ROOT).get("accepted"):
		return "canonical whitespace changed authority"
	var profile := _read_contract(profile_path)
	profile["scope"]["live_owner"] = true
	if not _write_bytes(profile_path, JSON.stringify(profile).to_utf8_buffer()):
		return "failed to mutate profile"
	var rejected: Variant = RuntimeScript.compile_ir(vectors.get("ir_cases", [])[0].get("document").duplicate(true), TEMP_ROOT)
	if rejected.get("accepted") or rejected.get("error_code") != "contract_error":
		return "semantic contract drift accepted"
	var bundle_path := "%s/strategic_trace_v2_bundle.json" % TEMP_ROOT
	var bundle := _read_contract(bundle_path)
	var profile_hash: String = RuntimeScript._canonical_artifact_sha256(_read_bytes(profile_path))
	for entry: Variant in bundle.get("artifacts", []):
		if entry is Dictionary and entry.get("id") == "profile":
			entry["canonical_sha256"] = profile_hash
	if not _write_bytes(bundle_path, JSON.stringify(bundle).to_utf8_buffer()):
		return "failed to resign bundle"
	rejected = RuntimeScript.compile_ir(vectors.get("ir_cases", [])[0].get("document").duplicate(true), TEMP_ROOT)
	if rejected.get("accepted") or rejected.get("error_code") != "contract_error":
		return "self-consistent artifact+bundle resign replaced fixed trust anchor"
	rejected = RuntimeScript.compile_ir(vectors.get("ir_cases", [])[0].get("document").duplicate(true), "%s/missing" % TEMP_ROOT)
	if rejected.get("accepted") or rejected.get("error_code") != "contract_error":
		return "missing contract root accepted"
	return ""
