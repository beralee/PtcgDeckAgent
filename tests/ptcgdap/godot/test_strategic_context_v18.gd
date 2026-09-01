class_name TestStrategicContextV18
extends TestBase

const StrategicContextScript = preload(
	"res://scripts/ai/ptcgdap/public/StrategicContextV18.gd"
)
const FirewallScript = preload(
	"res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd"
)
const CabtContractSetScript = preload(
	"res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd"
)
const CabtObservationParserScript = preload(
	"res://scripts/ai/ptcgdap/cabt/CabtObservationParser.gd"
)
const CabtSelectionWindowScript = preload(
	"res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd"
)
const CabtSelectionSanitizerScript = preload(
	"res://scripts/ai/ptcgdap/cabt/CabtSelectionSanitizer.gd"
)
const CabtDeterministicFallbackScript = preload(
	"res://scripts/ai/ptcgdap/cabt/CabtDeterministicFallback.gd"
)

const FIREWALL_VECTOR_PATH := "res://contracts/ptcgdap/cabt_public_firewall_conformance_vectors.json"
const VECTOR_PATH := "res://contracts/ptcgdap/strategic_context_v18_conformance_vectors.json"
const CONTRACT_ROOT := "res://contracts/ptcgdap"
const TEMP_ROOT := "user://ptcgdap_strategic_context_v18_contract"
const POLICY_HASH := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
const PRIVATE_SENTINEL := "PRIVATE_GODOT_STRATEGIC_SENTINEL"
const CONTRACT_FILES := [
	"strategic_context_v18.schema.json",
	"strategic_context_v18_profile.json",
	"strategic_context_v18_conformance_vectors.json",
	"strategic_context_v18_bundle.json",
]


class FakeValue extends RefCounted:
	func validate_integrity(_value: Variant = null) -> bool:
		return true


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


func _apply_mutation(root: Variant, mutation: Dictionary) -> void:
	var path: Array = mutation.get("path", [])
	var parent: Variant = root
	for index: int in range(path.size() - 1):
		parent = parent[path[index]]
	var key: Variant = path[-1]
	match str(mutation.get("op")):
		"set":
			parent[key] = _copy_json(mutation.get("value"))
		"delete":
			parent.erase(key)
		"append":
			parent[key].append(_copy_json(mutation.get("value")))


func _case(vectors: Dictionary, case_id: String) -> Dictionary:
	for case_value: Variant in vectors.get("cases", []):
		if case_value is Dictionary and case_value.get("id") == case_id:
			return case_value
	return {}


func _case_input(vectors: Dictionary, case_id: String) -> Dictionary:
	var case := _case(vectors, case_id)
	var base: Dictionary = vectors.get("base_observations", {}).get(case.get("base"), {}).duplicate(true)
	for mutation_value: Variant in case.get("mutations", []):
		if mutation_value is Dictionary:
			_apply_mutation(base, mutation_value)
	return base


func _firewall_result(case_id: String) -> Variant:
	var vectors := _read_contract(FIREWALL_VECTOR_PATH)
	var contracts: Variant = CabtContractSetScript.load_default()
	var parsed: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(
		_case_input(vectors, case_id),
		contracts,
	)
	return FirewallScript.load_default().project(parsed)


func _window(
	result: Variant,
	public_hash: Variant = null,
	chooser: Variant = null,
	select_value: Variant = null,
) -> Variant:
	var public: Dictionary = result.get("public_observation")
	var current: Dictionary = public.get("current")
	var input := {
		"public_observation_hash": result.get("public_observation_hash") if public_hash == null else public_hash,
		"public_hash_authority": "firewall_accepted",
		"chooser_player_index": current.get("yourIndex") if chooser == null else chooser,
		"select": _copy_json(public.get("select")) if select_value == null else _copy_json(select_value),
	}
	var built: Variant = CabtSelectionWindowScript.build(input, CabtContractSetScript.load_default())
	return built.get("window") if built != null else null


func _context_pair() -> Dictionary:
	var firewall_result: Variant = _firewall_result("regular-accepted")
	var window: Variant = _window(firewall_result)
	var built: Variant = StrategicContextScript.build_context(firewall_result, window)
	return {"firewall": firewall_result, "window": window, "result": built, "context": built.get("context")}


func _resolution(window: Variant, owner: String, reason: String, indexes: Array) -> Variant:
	if owner == "policy":
		return CabtSelectionSanitizerScript.resolve_policy_attempt(
			window,
			{"status": "returned", "output": indexes.duplicate(true)},
		)
	if reason == "policy_timeout":
		return CabtSelectionSanitizerScript.resolve_policy_attempt(
			window,
			{"status": "timeout", "output": null},
		)
	return CabtSelectionSanitizerScript.resolve_policy_attempt(
		window,
		{"status": "returned", "output": [0, 1]},
	)


func test_default_contract_and_exact_context_match_shared_vector() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var pair := _context_pair()
	var context: Variant = pair.get("context")
	var window: Variant = pair.get("window")
	if context == null or window == null:
		return "context/window did not build"
	if not pair.get("result").get("accepted"):
		return "context rejected: %s" % pair.get("result").get("error_code")
	if not context.validate_integrity():
		return "context integrity failed"
	if context.to_public_dict() != vectors.get("fixture", {}).get("expected_context"):
		return "context differs from shared vector"
	if window.to_public_dict() != vectors.get("fixture", {}).get("expected_window"):
		return "window differs from shared vector"
	var serialized := JSON.stringify(context.to_public_dict())
	for sentinel: Variant in vectors.get("private_sentinels", []):
		if serialized.contains(str(sentinel)):
			return "context leaked %s" % sentinel
	for key: String in ["raw_private_hash", "token_free_callback_hash", "search_begin_input", "binding", "ticket"]:
		if serialized.contains(key):
			return "context serialized private key %s" % key
	return ""


func test_all_context_rejections_fail_closed() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var regular: Variant = _firewall_result("regular-accepted")
	var regular_window: Variant = _window(regular)
	var rejected_case := ""
	var firewall_vectors := _read_contract(FIREWALL_VECTOR_PATH)
	for case_value: Variant in firewall_vectors.get("cases", []):
		if case_value is Dictionary and case_value.get("status") == "rejected":
			rejected_case = str(case_value.get("id"))
			break
	var public: Dictionary = regular.get("public_observation")
	var reversed_select: Dictionary = public.get("select").duplicate(true)
	reversed_select["option"].reverse()
	var faults := {
		"rejected_firewall": [_firewall_result(rejected_case), regular_window],
		"window_hash_mismatch": [regular, _window(regular, "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB")],
		"chooser_mismatch": [regular, _window(regular, null, 1)],
		"select_mismatch": [regular, _window(regular, null, null, reversed_select)],
		"initial_select_null": [_firewall_result("initial-accepted"), null],
		"fake_firewall_result": [FakeValue.new(), regular_window],
		"fake_window": [regular, FakeValue.new()],
	}
	for spec_value: Variant in vectors.get("context_rejections", []):
		var spec: Dictionary = spec_value
		var arguments: Array = faults.get(spec.get("fault"), [])
		var result: Variant = StrategicContextScript.build_context(arguments[0], arguments[1])
		if result.get("accepted") or result.get("context") != null:
			return "%s unexpectedly accepted" % spec.get("id")
		if result.get("error_code") != spec.get("expected_error_code"):
			return "%s error mismatch: %s" % [spec.get("id"), result.get("error_code")]
	return ""


func test_all_policy_and_fallback_decisions_match_shared_vectors() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var pair := _context_pair()
	var context: Variant = pair.get("context")
	var window: Variant = pair.get("window")
	for case_value: Variant in vectors.get("decision_cases", []):
		var case: Dictionary = case_value
		var resolution: Variant = _resolution(
			window,
			str(case.get("resolution_owner")),
			str(case.get("resolution_reason_code")),
			case.get("selected_indexes", []),
		)
		if not CabtDeterministicFallbackScript.validate_resolution_integrity(resolution, window):
			return "%s resolution integrity failed" % case.get("id")
		var built: Variant = StrategicContextScript.build_policy_decision(
			context,
			window,
			resolution,
			case.get("policy_hash"),
			case.get("scene_id"),
			case.get("decision_id"),
			case.get("determinism_key"),
		)
		if not built.get("accepted"):
			return "%s rejected: %s" % [case.get("id"), built.get("error_code")]
		var decision: Variant = built.get("decision")
		if not decision.validate_integrity(context, window, resolution):
			return "%s decision integrity failed" % case.get("id")
		if decision.to_public_dict() != case.get("expected_decision"):
			return "%s decision differs from shared vector" % case.get("id")
		if decision.agent_output() != case.get("selected_indexes"):
			return "%s agent output differs" % case.get("id")
	return ""


func test_decision_rejections_and_stale_bindings_fail_closed() -> String:
	var vectors := _read_contract(VECTOR_PATH)
	var pair := _context_pair()
	var context: Variant = pair.get("context")
	var window: Variant = pair.get("window")
	var resolution: Variant = _resolution(window, "policy", "policy_selection_accepted", [0])
	var public: Dictionary = pair.get("firewall").get("public_observation")
	var reversed_select: Dictionary = public.get("select").duplicate(true)
	reversed_select["option"].reverse()
	var other_window: Variant = _window(pair.get("firewall"), null, null, reversed_select)
	var calls := {
		"different_window": [context, other_window, resolution, POLICY_HASH, "scene", "decision", "seed"],
		"fake_resolution": [context, window, FakeValue.new(), POLICY_HASH, "scene", "decision", "seed"],
		"lowercase_policy_hash": [context, window, resolution, POLICY_HASH.to_lower(), "scene", "decision", "seed"],
		"empty_scene_id": [context, window, resolution, POLICY_HASH, "", "decision", "seed"],
	}
	for spec_value: Variant in vectors.get("decision_rejections", []):
		var spec: Dictionary = spec_value
		var arguments: Array = calls.get(spec.get("fault"), [])
		var built: Variant = StrategicContextScript.build_policy_decision(
			arguments[0], arguments[1], arguments[2], arguments[3], arguments[4], arguments[5], arguments[6]
		)
		if built.get("accepted") or built.get("decision") != null:
			return "%s unexpectedly accepted" % spec.get("id")
		if built.get("error_code") != spec.get("expected_error_code"):
			return "%s error mismatch: %s" % [spec.get("id"), built.get("error_code")]
	return ""


func test_ordinary_mutation_direct_construction_and_protocol_lookalikes_fail_closed() -> String:
	var pair := _context_pair()
	var context: Variant = pair.get("context")
	var window: Variant = pair.get("window")
	var resolution: Variant = _resolution(window, "policy", "policy_selection_accepted", [0])
	var built: Variant = StrategicContextScript.build_policy_decision(
		context, window, resolution, POLICY_HASH, "scene", "decision", "seed"
	)
	var decision: Variant = built.get("decision")
	var runtime_script: GDScript = load(
		"res://scripts/ai/ptcgdap/public/StrategicContextV18.gd"
	)
	var constants := runtime_script.get_script_constant_map()
	var direct_context: Variant = constants.get("ContextValue").new(
		{"context_hash": POLICY_HASH}, pair.get("firewall"), window, null
	)
	var direct_decision: Variant = constants.get("PolicyDecisionValue").new(
		{"selected_indexes": [0]}, context, window, resolution, null
	)
	if StrategicContextScript.validate_context(direct_context) or not direct_context.to_public_dict().is_empty():
		return "direct context construction gained authority"
	if StrategicContextScript.validate_decision(direct_decision, context, window, resolution) or not direct_decision.to_public_dict().is_empty():
		return "direct decision construction gained authority"
	if StrategicContextScript.build_context(FakeValue.new(), window).get("accepted"):
		return "firewall protocol lookalike accepted"
	if StrategicContextScript.build_policy_decision(
		context, window, FakeValue.new(), POLICY_HASH, "scene", "decision", "seed"
	).get("accepted"):
		return "resolution protocol lookalike accepted"
	var rebound_pair := _context_pair()
	var rebound_context: Variant = rebound_pair.get("context")
	var forged_context: Dictionary = rebound_context.to_public_dict()
	forged_context["public_state"]["acting_player"]["hand"][0]["id"] = 999999
	var unsigned_context := forged_context.duplicate(true)
	unsigned_context.erase("context_hash")
	forged_context["context_hash"] = runtime_script.call(
		"_domain_hash",
		"50544347444150005354524154454749435F434F4E544558545F56313800",
		unsigned_context,
	)
	rebound_context.set("_snapshot", forged_context)
	if rebound_context.validate_integrity() or not rebound_context.to_public_dict().is_empty():
		return "self-consistent rehash replaced bound firewall authority"
	context.set("_snapshot", {"private": PRIVATE_SENTINEL})
	if context.validate_integrity() or not context.to_public_dict().is_empty():
		return "mutated context remained valid/serialized"
	if decision.validate_integrity(context, window, resolution):
		return "decision survived bound context mutation"
	if not decision.to_public_dict().is_empty() or not decision.agent_output().is_empty():
		return "mutated decision binding emitted output"
	return ""


func test_result_getters_are_copy_only_and_private_free() -> String:
	var pair := _context_pair()
	var context: Variant = pair.get("context")
	var window: Variant = pair.get("window")
	var resolution: Variant = _resolution(window, "policy", "policy_selection_accepted", [1])
	var decision: Variant = StrategicContextScript.build_policy_decision(
		context, window, resolution, POLICY_HASH, "scene", "decision", "seed"
	).get("decision")
	var context_copy: Dictionary = context.to_public_dict()
	context_copy["public_state"]["acting_player"]["hand"].append({"private": PRIVATE_SENTINEL})
	var decision_copy: Dictionary = decision.to_public_dict()
	decision_copy["selected_indexes"].append(999999)
	if not context.validate_integrity() or not decision.validate_integrity(context, window, resolution):
		return "copy mutation altered owner result"
	var serialized := JSON.stringify([context.to_public_dict(), decision.to_public_dict()])
	if serialized.contains(PRIVATE_SENTINEL) or serialized.contains("999999"):
		return "copy mutation leaked back into result"
	return ""


func test_contract_whitespace_is_allowed_but_semantic_drift_is_rejected() -> String:
	var absolute_root := ProjectSettings.globalize_path(TEMP_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute_root)
	for name: String in CONTRACT_FILES:
		if not _write_bytes("%s/%s" % [TEMP_ROOT, name], _read_bytes("%s/%s" % [CONTRACT_ROOT, name])):
			return "failed to copy %s" % name
	var profile_path := "%s/strategic_context_v18_profile.json" % TEMP_ROOT
	var profile_bytes := _read_bytes(profile_path)
	profile_bytes.append_array(" \n".to_utf8_buffer())
	if not _write_bytes(profile_path, profile_bytes):
		return "failed to append profile whitespace"
	var pair := _context_pair()
	var whitespace_result: Variant = StrategicContextScript.build_context(
		pair.get("firewall"), pair.get("window"), TEMP_ROOT
	)
	if not whitespace_result.get("accepted"):
		return "canonical whitespace changed authority"
	var profile := _read_contract(profile_path)
	profile["scope"] = "forged-private-owner"
	if not _write_bytes(profile_path, JSON.stringify(profile).to_utf8_buffer()):
		return "failed to write semantic drift"
	var drift_result: Variant = StrategicContextScript.build_context(
		pair.get("firewall"), pair.get("window"), TEMP_ROOT
	)
	for name: String in CONTRACT_FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [TEMP_ROOT, name]))
	DirAccess.remove_absolute(absolute_root)
	if drift_result.get("accepted") or drift_result.get("error_code") != "contract_error":
		return "semantic contract drift was not rejected"
	return ""


func _copy_json(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
