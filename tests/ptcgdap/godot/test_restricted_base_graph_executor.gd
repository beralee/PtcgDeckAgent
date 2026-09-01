class_name TestRestrictedBaseGraphExecutor
extends TestBase

const RuntimeScript = preload("res://scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd")
const StrategicTraceScript = preload("res://scripts/ai/ptcgdap/public/StrategicTraceV2.gd")
const StrategicContextScript = preload("res://scripts/ai/ptcgdap/public/StrategicContextV18.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtObservationParserScript = preload("res://scripts/ai/ptcgdap/cabt/CabtObservationParser.gd")
const CabtSelectionWindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")

const VECTOR_PATH := "res://contracts/ptcgdap/restricted_base_graph_executor_conformance_vectors.json"
const IR_VECTOR_PATH := "res://contracts/ptcgdap/strategic_trace_v2_conformance_vectors.json"
const FIREWALL_VECTOR_PATH := "res://contracts/ptcgdap/cabt_public_firewall_conformance_vectors.json"
const PRIVATE_SENTINEL := "PRIVATE_GODOT_EXECUTOR_SENTINEL"


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


func _read_contract(path: String) -> Dictionary:
	var parsed: Dictionary = FirewallScript._parse_contract_json_bytes(_read_bytes(path))
	var value: Variant = parsed.get("value") if bool(parsed.get("ok", false)) else null
	return value if value is Dictionary else {}


func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


func _apply_path_mutation(root: Variant, mutation: Dictionary) -> void:
	var path: Array = mutation.get("path", [])
	var parent: Variant = root
	for index: int in range(path.size() - 1):
		parent = parent[path[index]]
	var key: Variant = path[-1]
	match str(mutation.get("op")):
		"set": parent[key] = _copy(mutation.get("value"))
		"delete": parent.erase(key)
		"append": parent[key].append(_copy(mutation.get("value")))


func _context() -> Variant:
	var vectors := _read_contract(FIREWALL_VECTOR_PATH)
	var spec: Dictionary = {}
	for value: Variant in vectors.get("cases", []):
		if value is Dictionary and value.get("id") == "regular-accepted":
			spec = value
			break
	var raw: Dictionary = vectors.get("base_observations", {}).get(spec.get("base"), {}).duplicate(true)
	for mutation: Variant in spec.get("mutations", []):
		_apply_path_mutation(raw, mutation)
	var parsed: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(raw, CabtContractSetScript.load_default())
	var firewall_result: Variant = FirewallScript.load_default().project(parsed)
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
	return StrategicContextScript.build_context(firewall_result, built.get("window")).get("context")


func _ir(case_id: String) -> Variant:
	var vectors := _read_contract(IR_VECTOR_PATH)
	for spec: Variant in vectors.get("ir_cases", []):
		if spec.get("id") == case_id:
			return StrategicTraceScript.compile_ir(spec.get("document").duplicate(true)).get("ir")
	return null


func test_all_shared_success_cases_match_exact_payload_and_hash() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	for spec: Variant in vectors.get("execution_cases", []):
		var context: Variant = _context()
		var ir: Variant = _ir(str(spec.get("ir_case_id")))
		var outcome: Variant = RuntimeScript.execute(context, ir, spec.get("input").duplicate(true))
		if not outcome.get("accepted"):
			return "%s rejected: %s" % [spec.get("id"), outcome.get("error_code")]
		var result: Variant = outcome.get("result")
		if not result.validate_integrity(context, ir):
			return "%s integrity failed" % spec.get("id")
		if result.to_public_dict() != spec.get("expected_result"):
			return "%s payload/hash mismatch" % spec.get("id")
	return ""


func test_all_shared_rejections_fail_closed() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var base: Dictionary = vectors.get("execution_cases", [])[0].get("input")
	for spec: Variant in vectors.get("execution_rejections", []):
		var context: Variant = _context()
		var ir: Variant = _ir("minimal-base")
		var value: Dictionary = base.duplicate(true)
		if spec.has("mutation"):
			var mutation: Dictionary = spec.get("mutation")
			value[mutation.get("field")] = _copy(mutation.get("value"))
			if mutation.has("also"):
				var also: Dictionary = mutation.get("also")
				value[also.get("field")] = _copy(also.get("value"))
		var source_context: Variant = RefCounted.new() if spec.get("fault") == "fake_context" else context
		var source_ir: Variant = RefCounted.new() if spec.get("fault") == "fake_ir" else ir
		var outcome: Variant = RuntimeScript.execute(source_context, source_ir, value)
		if outcome.get("accepted") or outcome.get("result") != null:
			return "%s unexpectedly accepted" % spec.get("id")
		if outcome.get("error_code") != spec.get("expected_error_code"):
			return "%s error mismatch: %s" % [spec.get("id"), outcome.get("error_code")]
	return ""


func test_direct_construction_copy_mutation_and_stale_binding_fail_closed() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var context: Variant = _context()
	var ir: Variant = _ir("minimal-base")
	var value: Dictionary = vectors.get("execution_cases", [])[0].get("input").duplicate(true)
	var outcome: Variant = RuntimeScript.execute(context, ir, value)
	if not outcome.get("accepted"):
		return "owner execution failed"
	var result: Variant = outcome.get("result")
	var runtime_script: GDScript = load(
		"res://scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd"
	)
	var constants := runtime_script.get_script_constant_map()
	var direct: Variant = constants.get("ExecutionValue").new({}, value, context, ir, null)
	if direct.validate_integrity(context, ir) or not direct.to_public_dict().is_empty():
		return "direct construction gained authority"
	var public: Dictionary = result.to_public_dict()
	public["selected_indexes"].append(999)
	if result.selected_indexes != [0]:
		return "copy mutation affected result"
	var other_context: Variant = _context()
	if result.validate_integrity(other_context, ir):
		return "result rebound across context owners"
	result.set("_snapshot", {"selected_indexes": [999], "private": PRIVATE_SENTINEL})
	if result.validate_integrity(context, ir) or not result.to_public_dict().is_empty() or not result.selected_indexes.is_empty():
		return "mutated result stayed valid or echoed"
	return ""


func test_variant_traps_and_private_values_fail_closed() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var context: Variant = _context()
	var ir: Variant = _ir("public-adapter-proposals")
	var value: Dictionary = vectors.get("execution_cases", [])[-1].get("input").duplicate(true)
	value["mandatory_indexes"] = PackedInt32Array([0])
	if RuntimeScript.execute(context, ir, value).get("accepted"):
		return "PackedInt32Array accepted"
	value = vectors.get("execution_cases", [])[-1].get("input").duplicate(true)
	value["execution_id"] = &"string_name"
	if RuntimeScript.execute(context, ir, value).get("accepted"):
		return "StringName accepted"
	value = vectors.get("execution_cases", [])[-1].get("input").duplicate(true)
	value["adapter_proposals"][0]["reason_code"] = PRIVATE_SENTINEL
	var outcome: Variant = RuntimeScript.execute(context, ir, value)
	if outcome.get("accepted") or outcome.get("error_code") != "invalid_execution_input" or str(outcome.get("error_code")).contains(PRIVATE_SENTINEL):
		return "private value accepted/echoed"
	return ""


func test_adapter_cannot_reorder_forced_terminal_or_mandatory_indexes() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var context: Variant = _context()
	var ir: Variant = _ir("public-adapter-proposals")
	var value: Dictionary = vectors.get("execution_cases", [])[-1].get("input").duplicate(true)
	value["mandatory_indexes"] = [0]
	value["adapter_proposals"] = [{"operator": "goal_proposal", "indexes": [1], "reason_code": "public_goal_proposal"}]
	var outcome: Variant = RuntimeScript.execute(context, ir, value)
	if not outcome.get("accepted") or outcome.get("result").selected_indexes != [0]:
		return "adapter reordered mandatory selection"
	value["mandatory_indexes"] = [0]
	value["terminal_indexes"] = [1]
	outcome = RuntimeScript.execute(context, ir, value)
	if not outcome.get("accepted") or outcome.get("result").selected_indexes != [1]:
		return "adapter reordered terminal selection"
	return ""


func test_contract_anchor_and_parent_owner_are_exact() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var outcome: Variant = RuntimeScript.execute(_context(), _ir("minimal-base"), vectors.get("execution_cases", [])[0].get("input").duplicate(true))
	if not outcome.get("accepted"):
		return "default fixed-anchor load failed: %s" % outcome.get("error_code")
	if RuntimeScript.EXPECTED_PARENT_BUNDLE_SHA256 != "ADDD4CB48BD10FA0478854124D8E63AEE42B898C0EB81692BA35F8D7F90414C4":
		return "parent anchor drift"
	return ""
