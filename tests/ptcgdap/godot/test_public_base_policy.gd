class_name TestPublicBasePolicy
extends TestBase

const RuntimeScript = preload("res://scripts/ai/ptcgdap/public/PublicBasePolicy.gd")
const AdapterScript = preload("res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")
const StrategicTraceScript = preload("res://scripts/ai/ptcgdap/public/StrategicTraceV2.gd")
const StrategicContextScript = preload("res://scripts/ai/ptcgdap/public/StrategicContextV18.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtObservationParserScript = preload("res://scripts/ai/ptcgdap/cabt/CabtObservationParser.gd")
const CabtSelectionWindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")

const VECTOR_PATH := "res://contracts/ptcgdap/public_base_policy_conformance_vectors.json"
const IR_VECTOR_PATH := "res://contracts/ptcgdap/strategic_trace_v2_conformance_vectors.json"
const ADAPTER_VECTOR_PATH := "res://contracts/ptcgdap/public_deck_adapter_conformance_vectors.json"
const FIREWALL_VECTOR_PATH := "res://contracts/ptcgdap/cabt_public_firewall_conformance_vectors.json"


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


func _read_contract(path: String) -> Dictionary:
	var parsed: Dictionary = FirewallScript._parse_contract_json_bytes(_read_bytes(path))
	var value: Variant = parsed.get("value") if bool(parsed.get("ok", false)) else null
	return value if value is Dictionary else {}


func _apply_path_mutation(root: Variant, mutation: Dictionary) -> void:
	var path: Array = mutation.get("path", [])
	var parent: Variant = root
	for index: int in range(path.size() - 1):
		parent = parent[path[index]]
	var key: Variant = path[-1]
	match str(mutation.get("op")):
		"set": parent[key] = mutation.get("value").duplicate(true) if mutation.get("value") is Dictionary or mutation.get("value") is Array else mutation.get("value")
		"delete": parent.erase(key)
		"append": parent[key].append(mutation.get("value").duplicate(true) if mutation.get("value") is Dictionary or mutation.get("value") is Array else mutation.get("value"))


func _owners() -> Dictionary:
	var firewall_vectors := _read_contract(FIREWALL_VECTOR_PATH)
	var spec: Dictionary = {}
	for value: Variant in firewall_vectors.get("cases", []):
		if value is Dictionary and value.get("id") == "regular-accepted":
			spec = value
			break
	var raw: Dictionary = firewall_vectors.get("base_observations", {}).get(spec.get("base"), {}).duplicate(true)
	for mutation: Variant in spec.get("mutations", []):
		_apply_path_mutation(raw, mutation)
	var contracts: Variant = CabtContractSetScript.load_default()
	var parsed: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(raw, contracts)
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
		contracts,
	)
	var window: Variant = built.get("window")
	var context: Variant = StrategicContextScript.build_context(firewall_result, window).get("context")
	var vectors := _read_contract(VECTOR_PATH)
	var ir_document: Dictionary = {}
	for ir_case: Variant in _read_contract(IR_VECTOR_PATH).get("ir_cases", []):
		if ir_case.get("id") == vectors.get("fixture", {}).get("ir_case_id"):
			ir_document = ir_case.get("document").duplicate(true)
			break
	var adapter_document: Dictionary = {}
	for adapter_case: Variant in _read_contract(ADAPTER_VECTOR_PATH).get("adapter_documents", []):
		if adapter_case.get("id") == vectors.get("fixture", {}).get("adapter_case_id"):
			adapter_document = adapter_case.get("document").duplicate(true)
			break
	return {
		"context": context,
		"window": window,
		"ir": StrategicTraceScript.compile_ir(ir_document).get("ir"),
		"adapter": AdapterScript.compile(adapter_document).get("adapter"),
	}


func test_shared_orchestration_cases_issue_exact_decision_and_trace() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var owners := _owners()
	var cases: Array = vectors.get("orchestration_cases", [])
	for index: int in cases.size():
		var spec: Variant = cases[index]
		print("PUBLIC_BASE_POLICY_PROGRESS: %d/%d %s" % [index, cases.size(), spec.get("id")])
		var outcome: Variant = RuntimeScript.orchestrate(owners.context, owners.window, owners.ir, owners.adapter, spec.get("request").duplicate(true))
		if not bool(outcome.get("accepted")):
			return "%s rejected at %s: %s" % [spec.get("id"), outcome.get("failed_stage"), outcome.get("error_code")]
		var result: Variant = outcome.get("result")
		if not result.validate_integrity(owners.context, owners.window, owners.ir, owners.adapter):
			return "%s result integrity failed" % spec.get("id")
		if result.to_public_dict() != spec.get("expected_result"):
			return "%s result/hash mismatch" % spec.get("id")
		if result.decision.audit_id != spec.get("expected_decision_audit_id") or result.trace.trace_hash != spec.get("expected_trace_hash"):
			return "%s decision/trace hash mismatch" % spec.get("id")
		if result.agent_output() != spec.get("expected_selected_indexes"):
			return "%s output mismatch" % spec.get("id")
	print("PUBLIC_BASE_POLICY_PROGRESS: %d/%d complete" % [cases.size(), cases.size()])
	return ""


func test_shared_rejections_are_atomic_and_do_not_echo() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var base: Dictionary = vectors.get("orchestration_cases", [])[0].get("request").duplicate(true)
	for spec: Variant in vectors.get("orchestration_rejections", []):
		var owners := _owners()
		var request := base.duplicate(true)
		match str(spec.get("fault")):
			"fake_context": owners.context = RefCounted.new()
			"fake_window": owners.window = RefCounted.new()
			"fake_ir": owners.ir = RefCounted.new()
			"fake_adapter": owners.adapter = RefCounted.new()
			"private_identity": request.orchestration_id = "PRIVATE_SENTINEL"
			"lowercase_policy_hash": request.policy_hash = str(request.policy_hash).to_lower()
			"mandatory_bool": request.mandatory_indexes = [true]
			"forced_veto": request.mandatory_indexes = [0]; request.base_vetoed_indexes = [0]
			"cross_window": owners.window = _owners().window
			"mutated_adapter": owners.adapter.set("_snapshot", {"PRIVATE": true})
		var outcome: Variant = RuntimeScript.orchestrate(owners.context, owners.window, owners.ir, owners.adapter, request)
		if bool(outcome.get("accepted")) or outcome.get("result") != null:
			return "%s returned partial authority" % spec.get("id")
		if outcome.get("failed_stage") != spec.get("expected_failed_stage") or outcome.get("error_code") != spec.get("expected_error_code"):
			return "%s mismatch: %s/%s" % [spec.get("id"), outcome.get("failed_stage"), outcome.get("error_code")]
		if str(outcome.get("error_code")).contains("PRIVATE"):
			return "%s echoed private input" % spec.get("id")
	return ""


func test_variant_traps_stale_binding_and_mutation_fail_closed() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var base: Dictionary = vectors.get("orchestration_cases", [])[0].get("request").duplicate(true)
	for bad: Variant in [true, 0.0, &"zero", 9007199254740992]:
		var owners := _owners()
		var request := base.duplicate(true)
		request.base_hard_tiers[0].tier = [bad]
		if RuntimeScript.orchestrate(owners.context, owners.window, owners.ir, owners.adapter, request).get("accepted"):
			return "tier host type accepted: %s" % type_string(typeof(bad))
	var owners := _owners()
	var result: Variant = RuntimeScript.orchestrate(owners.context, owners.window, owners.ir, owners.adapter, base).get("result")
	var other := _owners()
	if result.validate_integrity(other.context, other.window, owners.ir, owners.adapter):
		return "stale result rebound"
	result.set("_snapshot", {"PRIVATE": "SENTINEL", "selected_indexes": [999]})
	if result.validate_integrity(owners.context, owners.window, owners.ir, owners.adapter) or not result.agent_output().is_empty() or not result.to_public_dict().is_empty():
		return "mutated result stayed valid or echoed"
	return ""


func test_contract_anchor_stage_order_and_scope_are_exact() -> String:
	if RuntimeScript.EXPECTED_BUNDLE_SHA256 != "18AAB663D9B429AC8657A75692F5DD8CF37C409CC057A328B57758C692FDB7F4":
		return "bundle anchor drift"
	if RuntimeScript.STAGES != [
		"validate_exact_owners",
		"propose_public_adapter_hints",
		"execute_restricted_base_graph",
		"sanitize_against_exact_current_window",
		"issue_policy_decision",
		"issue_strategic_trace",
		"seal_public_audit_result",
	]:
		return "stage order drift"
	return ""
