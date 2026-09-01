class_name TestPublicPolicyBudget
extends TestBase

const RuntimeScript = preload("res://scripts/ai/ptcgdap/public/PublicPolicyBudget.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtObservationParserScript = preload("res://scripts/ai/ptcgdap/cabt/CabtObservationParser.gd")
const CabtSelectionWindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")

const VECTOR_PATH := "res://contracts/ptcgdap/public_policy_budget_conformance_vectors.json"
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


func _window() -> Variant:
	var vectors := _read_contract(FIREWALL_VECTOR_PATH)
	var spec: Dictionary = {}
	for value: Variant in vectors.get("cases", []):
		if value is Dictionary and value.get("id") == "regular-accepted":
			spec = value
			break
	var raw: Dictionary = vectors.get("base_observations", {}).get(spec.get("base"), {}).duplicate(true)
	for mutation: Variant in spec.get("mutations", []):
		_apply_path_mutation(raw, mutation)
	var contracts: Variant = CabtContractSetScript.load_default()
	var parsed: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(raw, contracts)
	var firewall: Variant = FirewallScript.load_default().project(parsed)
	var public: Dictionary = firewall.get("public_observation")
	return CabtSelectionWindowScript.build({
		"public_observation_hash": firewall.get("public_observation_hash"),
		"public_hash_authority": "firewall_accepted",
		"chooser_player_index": public.get("current", {}).get("yourIndex"),
		"select": public.get("select", {}).duplicate(true),
	}, contracts).get("window")


func test_shared_start_and_step_cases_match_exactly() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var started: Variant = RuntimeScript.start_ledger(vectors.fixture.ledger_id)
	if started == null or not started.validate_integrity() or started.to_public_dict() != vectors.fixture.initial_ledger:
		return "initial ledger mismatch"
	for spec: Variant in vectors.get("step_cases", []):
		var ledger: Variant = RuntimeScript.start_ledger(vectors.fixture.ledger_id)
		var window: Variant = _window()
		var outcome: Variant = RuntimeScript.step(ledger, window, spec.get("elapsed_ms"), spec.get("capabilities").duplicate(true))
		if not bool(outcome.get("accepted")) or outcome.get("result") == null:
			return "%s rejected: %s" % [spec.get("id"), outcome.get("error_code")]
		var result: Variant = outcome.get("result")
		if not result.validate_integrity(ledger, window):
			return "%s integrity failed" % spec.get("id")
		if result.to_public_dict() != spec.get("expected_result"):
			return "%s result/hash mismatch" % spec.get("id")
	return ""


func test_shared_rejections_are_atomic_and_do_not_echo() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	for spec: Variant in vectors.get("rejections", []):
		var ledger: Variant = RuntimeScript.start_ledger(vectors.fixture.ledger_id)
		var window: Variant = _window()
		var elapsed: Variant = 1
		var capabilities: Variant = vectors.fixture.all_available_capabilities.duplicate(true)
		match str(spec.get("fault")):
			"fake_ledger": ledger = RefCounted.new()
			"fake_window": window = RefCounted.new()
			"elapsed_bool": elapsed = true
			"elapsed_negative": elapsed = -1
			"elapsed_unsafe": elapsed = 9007199254740992
			"capabilities_not_object": capabilities = []
			"capability_state_not_string": capabilities.search_v1 = true
			"capability_state_unknown": capabilities.search_v1 = "PRIVATE_SENTINEL"
		var outcome: Variant = RuntimeScript.step(ledger, window, elapsed, capabilities)
		if bool(outcome.get("accepted")) or outcome.get("result") != null:
			return "%s returned partial authority" % spec.get("id")
		if outcome.get("error_code") != spec.get("expected_error_code"):
			return "%s mismatch: %s" % [spec.get("id"), outcome.get("error_code")]
		if str(outcome.get("error_code")).contains("PRIVATE"):
			return "%s echoed private input" % spec.get("id")
	return ""


func test_thresholds_chaining_and_same_window_fallback_are_exact() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var expected_modes := ["full", "full", "base_only", "base_only", "deterministic_fallback", "deterministic_fallback", "deterministic_fallback"]
	var elapsed_values := [0, 569999, 570000, 594999, 595000, 600000, 600001]
	for index: int in elapsed_values.size():
		var ledger: Variant = RuntimeScript.start_ledger(vectors.fixture.ledger_id)
		var window: Variant = _window()
		var result: Variant = RuntimeScript.step(ledger, window, elapsed_values[index], vectors.fixture.all_available_capabilities).get("result")
		if result == null or result.mode != expected_modes[index]:
			return "threshold mismatch at %s" % elapsed_values[index]
		if result.mode == "deterministic_fallback" and result.selected_indexes != [0]:
			return "fallback indexes were not same-window legal"
	var ledger: Variant = RuntimeScript.start_ledger(vectors.fixture.ledger_id)
	var first_window: Variant = _window()
	var first: Variant = RuntimeScript.step(ledger, first_window, 100, vectors.fixture.all_available_capabilities).get("result")
	var next: Variant = first.next_ledger
	var second_window: Variant = _window()
	var second: Variant = RuntimeScript.step(next, second_window, 200, vectors.fixture.all_available_capabilities).get("result")
	if second == null or second.to_public_dict().remaining_after_ms != 599700 or second.to_public_dict().decision_ordinal != 2:
		return "ledger chaining mismatch"
	return ""


func test_variant_stale_binding_and_mutation_fail_closed() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	for bad: Variant in [true, 0.0, &"zero", 9007199254740992]:
		if RuntimeScript.step(RuntimeScript.start_ledger(vectors.fixture.ledger_id), _window(), bad, vectors.fixture.all_available_capabilities).get("accepted"):
			return "elapsed host type accepted: %s" % type_string(typeof(bad))
	var ledger: Variant = RuntimeScript.start_ledger(vectors.fixture.ledger_id)
	var window: Variant = _window()
	var result: Variant = RuntimeScript.step(ledger, window, 1, vectors.fixture.all_available_capabilities).get("result")
	if result.validate_integrity(ledger, _window()):
		return "result rebound to a different window"
	result.set("_snapshot", {"PRIVATE": "SENTINEL", "selected_indexes": [999]})
	if result.validate_integrity(ledger, window) or not result.selected_indexes.is_empty() or not result.to_public_dict().is_empty():
		return "mutated result remained valid or echoed"
	ledger.set("_snapshot", {"PRIVATE": "SENTINEL"})
	if ledger.validate_integrity() or not ledger.to_public_dict().is_empty():
		return "mutated ledger remained valid or echoed"
	return ""


func test_contract_anchor_and_non_authority_are_exact() -> String:
	if RuntimeScript.EXPECTED_BUNDLE_SHA256 != "0D82BDE31BD0FA0C44527880D9D6451C2733702913708532C512F3BFF81D8BF9":
		return "bundle anchor drift"
	var vectors := _read_contract(VECTOR_PATH)
	for spec: Variant in vectors.get("step_cases", []):
		var serialized := JSON.stringify(spec.get("expected_result"))
		if serialized.contains("vendor.future_capability") or serialized.contains("PRIVATE") or spec.get("expected_result", {}).get("authoritative") != false:
			return "%s leaked capability/private authority" % spec.get("id")
	return ""
