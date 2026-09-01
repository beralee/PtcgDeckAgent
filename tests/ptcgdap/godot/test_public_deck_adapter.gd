class_name TestPublicDeckAdapter
extends TestBase

const RuntimeScript = preload("res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")
const ExecutorScript = preload("res://scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd")
const StrategicTraceScript = preload("res://scripts/ai/ptcgdap/public/StrategicTraceV2.gd")
const StrategicContextScript = preload("res://scripts/ai/ptcgdap/public/StrategicContextV18.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtObservationParserScript = preload("res://scripts/ai/ptcgdap/cabt/CabtObservationParser.gd")
const CabtSelectionWindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")

const VECTOR_PATH := "res://contracts/ptcgdap/public_deck_adapter_conformance_vectors.json"
const IR_VECTOR_PATH := "res://contracts/ptcgdap/strategic_trace_v2_conformance_vectors.json"
const FIREWALL_VECTOR_PATH := "res://contracts/ptcgdap/cabt_public_firewall_conformance_vectors.json"
const PRIVATE_SENTINEL := "PRIVATE_GODOT_ADAPTER_SENTINEL"


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


func _adapter_document(vectors: Dictionary, case_id: String) -> Dictionary:
	for spec: Variant in vectors.get("adapter_documents", []):
		if spec.get("id") == case_id:
			return spec.get("document").duplicate(true)
	return {}


func test_shared_adapter_and_proposal_vectors_match_exactly() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var adapters := {}
	for spec: Variant in vectors.get("adapter_documents", []):
		var outcome: Variant = RuntimeScript.compile(spec.get("document").duplicate(true))
		if not outcome.get("accepted"):
			return "%s compile rejected: %s" % [spec.get("id"), outcome.get("error_code")]
		var adapter: Variant = outcome.get("adapter")
		if not adapter.validate_integrity() or adapter.to_public_dict() != spec.get("expected_adapter"):
			return "%s adapter/hash mismatch" % spec.get("id")
		adapters[spec.get("id")] = adapter
	for spec: Variant in vectors.get("proposal_cases", []):
		var context: Variant = _context()
		var adapter: Variant = adapters.get(spec.get("adapter_case_id"))
		var outcome: Variant = RuntimeScript.propose(context, adapter, spec.get("proposal_id"))
		if not outcome.get("accepted"):
			return "%s proposal rejected: %s" % [spec.get("id"), outcome.get("error_code")]
		var result: Variant = outcome.get("result")
		if not result.validate_integrity(context, adapter):
			return "%s proposal integrity failed" % spec.get("id")
		if result.to_public_dict() != spec.get("expected_result"):
			return "%s proposal/hash mismatch" % spec.get("id")
	return ""


func test_shared_rejections_fail_closed_without_echo() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var base := _adapter_document(vectors, "complete")
	for spec: Variant in vectors.get("adapter_rejections", []):
		var value: Dictionary = base.duplicate(true)
		var mutation: Dictionary = spec.get("mutation")
		var target: Dictionary = value if mutation.get("target") == "document" else value.get("rules")[int(mutation.get("rule_index", 0))]
		target[mutation.get("field")] = _copy(mutation.get("value"))
		var outcome: Variant = RuntimeScript.compile(value)
		if outcome.get("accepted") or outcome.get("adapter") != null:
			return "%s unexpectedly accepted" % spec.get("id")
		if outcome.get("error_code") != spec.get("expected_error_code"):
			return "%s error mismatch: %s" % [spec.get("id"), outcome.get("error_code")]
		for sentinel: Variant in vectors.get("private_sentinels", []):
			if str(outcome.get("error_code")).contains(str(sentinel)):
				return "%s leaked private sentinel" % spec.get("id")
	return ""


func test_direct_construction_copy_mutation_and_stale_binding_fail_closed() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var compiled: Variant = RuntimeScript.compile(_adapter_document(vectors, "complete"))
	if not compiled.get("accepted"):
		return "owner compile failed"
	var adapter: Variant = compiled.get("adapter")
	var context: Variant = _context()
	var outcome: Variant = RuntimeScript.propose(context, adapter, "bound")
	if not outcome.get("accepted"):
		return "owner proposal failed"
	var result: Variant = outcome.get("result")
	var runtime_script: GDScript = load(
		"res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd"
	)
	var constants: Dictionary = runtime_script.get_script_constant_map()
	var direct_adapter: Variant = constants.get("AdapterValue").new({}, {})
	if direct_adapter.validate_integrity() or not direct_adapter.to_public_dict().is_empty():
		return "direct adapter construction gained authority"
	var direct_result: Variant = constants.get("ProposalValue").new({}, context, adapter, "bound", null)
	if direct_result.validate_integrity(context, adapter) or not direct_result.to_public_dict().is_empty():
		return "direct result construction gained authority"
	var original: Array = result.adapter_proposals
	var public: Dictionary = result.to_public_dict()
	public["adapter_proposals"].append({"operator": "goal_proposal", "indexes": [999], "reason_code": PRIVATE_SENTINEL})
	if result.adapter_proposals != original:
		return "copy mutation affected result"
	var other_context: Variant = _context()
	if result.validate_integrity(other_context, adapter):
		return "result rebound across context owners"
	result.set("_snapshot", {"adapter_proposals": [{"indexes": [999]}], "private": PRIVATE_SENTINEL})
	if result.validate_integrity(context, adapter) or not result.to_public_dict().is_empty() or not result.adapter_proposals.is_empty():
		return "mutated result stayed valid or echoed"
	adapter.set("_snapshot", {"private": PRIVATE_SENTINEL})
	if adapter.validate_integrity() or not adapter.to_public_dict().is_empty():
		return "mutated adapter stayed valid or echoed"
	if RuntimeScript.propose(context, adapter, "mutated").get("error_code") != "invalid_adapter":
		return "mutated adapter accepted"
	return ""


func test_variant_traps_and_private_values_fail_closed() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var base := _adapter_document(vectors, "complete")
	for bad: Variant in [true, 1.0, &"one", 9007199254740992]:
		var value: Dictionary = base.duplicate(true)
		value["rules"][0]["priority"] = bad
		var outcome: Variant = RuntimeScript.compile(value)
		if outcome.get("accepted") or outcome.get("error_code") != "invalid_adapter_document":
			return "priority host type accepted: %s" % type_string(typeof(bad))
	var context: Variant = _context()
	var adapter: Variant = RuntimeScript.compile(base).get("adapter")
	if RuntimeScript.propose(context, adapter, &"string_name").get("error_code") != "invalid_proposal_id":
		return "StringName proposal id accepted"
	return ""


func test_adapter_hints_cannot_override_terminal_mandatory_tier_or_veto() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var context: Variant = _context()
	var adapter: Variant = RuntimeScript.compile(_adapter_document(vectors, "complete")).get("adapter")
	var proposal: Variant = RuntimeScript.propose(context, adapter, "integration").get("result")
	var ir: Variant = _ir("public-adapter-proposals")
	var value := {
		"execution_id": "adapter-integration",
		"mandatory_indexes": [0],
		"terminal_indexes": [1],
		"base_hard_tiers": [{"index": 0, "tier": [9]}, {"index": 1, "tier": [0]}],
		"base_vetoed_indexes": [],
		"adapter_proposals": proposal.adapter_proposals,
	}
	var executed: Variant = ExecutorScript.execute(context, ir, value)
	if not executed.get("accepted") or executed.get("result").selected_indexes != [1]:
		return "adapter overrode terminal authority"
	value["terminal_indexes"] = []
	executed = ExecutorScript.execute(context, ir, value)
	if not executed.get("accepted") or executed.get("result").selected_indexes != [0]:
		return "adapter overrode mandatory authority"
	value["mandatory_indexes"] = []
	value["base_vetoed_indexes"] = [1]
	executed = ExecutorScript.execute(context, ir, value)
	if executed.get("accepted") or executed.get("error_code") != "insufficient_candidates":
		return "adapter restored a vetoed best-tier candidate"
	return ""


func test_contract_anchor_and_parent_owner_are_exact() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var compiled: Variant = RuntimeScript.compile(_adapter_document(vectors, "no-match"))
	if not compiled.get("accepted"):
		return "fixed-anchor load failed: %s" % compiled.get("error_code")
	if RuntimeScript.EXPECTED_BUNDLE_SHA256 != "C80F4C4FDAEA5AC29BD3C5617BFAC72BE38709696F7EA1995D3D153113DD3CA1":
		return "bundle anchor drift"
	if RuntimeScript.EXPECTED_PARENT_BUNDLE_SHA256 != "69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389":
		return "parent anchor drift"
	return ""
