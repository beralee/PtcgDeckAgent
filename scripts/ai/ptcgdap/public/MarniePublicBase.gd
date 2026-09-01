class_name MarniePublicBase
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtObservationParserScript = preload("res://scripts/ai/ptcgdap/cabt/CabtObservationParser.gd")
const CabtSelectionWindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")
const MarnieVerticalSliceScript = preload("res://scripts/ai/ptcgdap/public/MarnieVerticalSlice.gd")
const PublicObservationFirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const StrategicContextScript = preload("res://scripts/ai/ptcgdap/public/StrategicContextV18.gd")
const PublicDeckAdapterScript = preload("res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")
const StrategicTraceScript = preload("res://scripts/ai/ptcgdap/public/StrategicTraceV2.gd")
const PublicBasePolicyScript = preload("res://scripts/ai/ptcgdap/public/PublicBasePolicy.gd")

const DEFAULT_ROOT := "res://"
const MAX_JSON_BYTES := 2 * 1024 * 1024
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const PROFILE_ID := "marnie_public_base_profile_v1"
const CONTRACT_ID := "ptcgdap-marnie-public-base-p5-wp6-v1"
const EXPECTED_BUNDLE_CANONICAL_SHA256 := "67EBA6348277001692942FD58E8D1B9D50C54F0FFC783D8802BA3CCB45691105"
const EXPECTED_DOCUMENT_INTEGRITY_SHA256 := "166906CEE9380EEF94A642CB9CCA9B2AF7A94AC546935CB91942FFD3B03B8C32"
const PROOF_PREFIX_UTF8_HEX := "50544347444150004D41524E49455F5055424C49435F4D4143524F5F50524F4F465F563100"
const RESULT_PREFIX_UTF8_HEX := "50544347444150004D41524E49455F5055424C49435F424153455F524553554C545F563100"
const RESULT_TOKEN := "ptcgdap.marnie_public_base.owner_result.v1"
const EXPECTED_ARTIFACTS := {
	"schema": ["contracts/ptcgdap/marnie_public_base.schema.json", "54F3B35CE104ECFCB4879CB37C2548EE3589C4E9CD7028D4DF6C270C99356AB0"],
	"profile": ["contracts/ptcgdap/marnie_public_base_profile.json", "4F6A0544443EFB04EAE09DDA54CECADC422F613B56F79D881AC2402473C121B9"],
	"vectors": ["contracts/ptcgdap/marnie_public_base_conformance_vectors.json", "18B9E5C3F744A086B8142BA63992BC1913C36840E4F2E848451D9012280E9552"],
	"audit": ["data/ptcgdap/marnie_vertical_slice/marnie_public_base_v1.json", "56D4E01370D0FDE971588A9A0E5ECF2556476560ABCC7A0FFD374470704B33F3"],
}
const PARENT_BUNDLES := {
	"marnie_prompt_broker": ["contracts/ptcgdap/marnie_prompt_broker_bundle.json", "E2EFDDE373EFBA0FDC929BE817595C8B3F0A5653956DB56418ADED57AFF960A1"],
	"marnie_trajectory_replay": ["contracts/ptcgdap/marnie_trajectory_replay_bundle.json", "E203A688BEC1AFFFABAAF06098361B3FAE04B84431F99AE75A19F891BFA9599F"],
	"public_base_policy": ["contracts/ptcgdap/public_base_policy_bundle.json", "18AAB663D9B429AC8657A75692F5DD8CF37C409CC057A328B57758C692FDB7F4"],
	"public_deck_adapter": ["contracts/ptcgdap/public_deck_adapter_bundle.json", "C80F4C4FDAEA5AC29BD3C5617BFAC72BE38709696F7EA1995D3D153113DD3CA1"],
	"restricted_base_graph": ["contracts/ptcgdap/restricted_base_graph_executor_bundle.json", "69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389"],
	"strategic_context": ["contracts/ptcgdap/strategic_context_v18_bundle.json", "AACFA7E2E7F914180A2B7A5C4D92D6514ACC5F4622FC95B57DC225673893F98F"],
	"strategic_trace": ["contracts/ptcgdap/strategic_trace_v2_bundle.json", "ADDD4CB48BD10FA0478854124D8E63AEE42B898C0EB81692BA35F8D7F90414C4"],
	"public_firewall": ["contracts/ptcgdap/cabt_public_firewall_bundle.json", "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"],
}
const FORBIDDEN_PUBLIC_KEYS := [
	"search_begin_input", "raw_private_hash", "token_free_callback_hash",
	"callback_binding_hash", "private_engine_command", "private_object_refs",
	"ticket", "command",
]
static var _RESULT_REGISTRY := {}


class ResultValue extends RefCounted:
	var _owner: Variant = null
	var _snapshot: Dictionary = {}
	var _snapshot_hash := ""
	var _factory_token := ""

	func _init(owner_value: Variant = null, snapshot_value: Dictionary = {}, token_value: String = "") -> void:
		_owner = owner_value
		_snapshot = snapshot_value.duplicate(true)
		var owner_script: GDScript = load("res://scripts/ai/ptcgdap/public/MarniePublicBase.gd")
		_snapshot_hash = str(owner_script.call("_canonical_sha256", _snapshot))
		_factory_token = token_value

	func validate_integrity(owner_value: Variant) -> bool:
		return (
			_owner != null
			and owner_value == _owner
			and _factory_token == RESULT_TOKEN
			and _owner.has_method("_validate_result")
			and bool(_owner._validate_result(self))
		)

	func to_public_dict() -> Dictionary:
		if not validate_integrity(_owner):
			return {
				"accepted": false, "case_count": 0, "chain_head": null, "cases": [],
				"public_only": true, "authoritative": false, "execution_authority": false,
			}
		return _snapshot.duplicate(true)


var _ok := false
var _error_code := "contract_integrity_invalid"
var _bundle: Variant = {}
var _documents: Variant = {}
var _cases: Variant = []
var _expected: Variant = {}
var _parent_owner: Variant = null
var _firewall: Variant = null
var _contracts: Variant = null
var _ir: Variant = null
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
	var script: GDScript = load("res://scripts/ai/ptcgdap/public/MarniePublicBase.gd")
	var result: RefCounted = script.new()
	if typeof(root_path) != TYPE_STRING:
		result._load_attempted = true
		result._fail("contract_integrity_invalid")
		return result
	result._load(str(root_path))
	return result


func _load(root_path: String) -> void:
	if _load_attempted:
		return
	_load_attempted = true
	var root := root_path.trim_suffix("/") + "/"
	if root == "/" or not _root_is_supported(root):
		_fail("contract_integrity_invalid")
		return
	var bundle_result := _read_json("%scontracts/ptcgdap/marnie_public_base_bundle.json" % root)
	if not bool(bundle_result.get("ok", false)):
		_fail("contract_integrity_invalid")
		return
	var bundle: Variant = bundle_result.get("value")
	if (
		not bundle is Dictionary
		or _canonical_sha256(bundle) != EXPECTED_BUNDLE_CANONICAL_SHA256
		or not _same_keys(bundle, ["schema_version", "contract_id", "status", "parent_contract", "artifacts", "runtime_authority"])
		or bundle.get("schema_version") != 1
		or bundle.get("contract_id") != CONTRACT_ID
		or bundle.get("status") != "offline_shadow"
		or bundle.get("parent_contract") != {
			"contract_id": "ptcgdap-marnie-prompt-broker-p5-wp5-v1",
			"canonical_sha256": PARENT_BUNDLES["marnie_prompt_broker"][1],
		}
		or bundle.get("runtime_authority") != "offline_public_audit_only"
		or not bundle.get("artifacts") is Array
		or bundle.get("artifacts").size() != EXPECTED_ARTIFACTS.size()
	):
		_fail("contract_integrity_invalid")
		return
	var documents := {}
	var seen := {}
	for entry_value: Variant in bundle.get("artifacts"):
		if not entry_value is Dictionary or not _same_keys(entry_value, ["id", "path", "canonical_sha256"]):
			_fail("contract_integrity_invalid")
			return
		var artifact_id: Variant = entry_value.get("id")
		if typeof(artifact_id) != TYPE_STRING or not EXPECTED_ARTIFACTS.has(artifact_id) or seen.has(artifact_id):
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
	if seen.size() != EXPECTED_ARTIFACTS.size():
		_fail("contract_integrity_invalid")
		return
	var profile_value: Variant = documents.get("profile")
	if not profile_value is Dictionary or profile_value.get("profile_id") != PROFILE_ID:
		_fail("contract_integrity_invalid")
		return
	var expected_parent_hashes := {}
	for parent_id: Variant in PARENT_BUNDLES:
		var parent_spec: Array = PARENT_BUNDLES[parent_id]
		expected_parent_hashes[parent_id] = parent_spec[1]
		var parent_result := _read_json("%s%s" % [root, parent_spec[0]])
		if not bool(parent_result.get("ok", false)) or _canonical_sha256(parent_result.get("value")) != parent_spec[1]:
			_fail("parent_contract_invalid")
			return
	if profile_value.get("parent_bundle_hashes") != expected_parent_hashes:
		_fail("parent_contract_invalid")
		return
	if _canonical_sha256(documents) != EXPECTED_DOCUMENT_INTEGRITY_SHA256:
		_fail("contract_integrity_invalid")
		return

	var contract_root := "%scontracts/ptcgdap" % root
	var parent_owner: Variant = MarnieVerticalSliceScript.load_from_root(root)
	var firewall: Variant = PublicObservationFirewallScript.load_from_root(contract_root)
	var contracts: Variant = CabtContractSetScript.load_from_root(contract_root)
	var ir_outcome: Variant = StrategicTraceScript.compile_ir(profile_value.get("restricted_ir_document"), contract_root)
	if (
		parent_owner == null or not bool(parent_owner.get("ok"))
		or firewall == null or not bool(firewall.get("ok"))
		or contracts == null or not bool(contracts.get("ok")) or not contracts.validate_integrity()
		or ir_outcome == null or not bool(ir_outcome.get("accepted")) or ir_outcome.get("ir") == null
	):
		_fail("parent_contract_invalid")
		return
	_bundle = _copy(bundle)
	_documents = _copy(documents)
	_parent_owner = parent_owner
	_firewall = firewall
	_contracts = contracts
	_ir = ir_outcome.get("ir")
	_document_integrity_sha256 = EXPECTED_DOCUMENT_INTEGRITY_SHA256
	# The expensive end-to-end reconstruction belongs to the contract builder
	# and cross-runtime conformance lane. At runtime the canonical document hash
	# already authenticates this audit projection, so loading it directly avoids
	# recompiling and replaying every historical case at each startup.
	var audit_value: Variant = documents.get("audit")
	if not audit_value is Dictionary or not audit_value.get("cases") is Array:
		_fail("runtime_conformance_mismatch")
		return
	var actual: Array = audit_value.get("cases", []).duplicate(true)
	if actual.is_empty():
		_fail("runtime_conformance_mismatch")
		return
	_cases = actual.duplicate(true)
	_expected = {
		"accepted": true,
		"case_count": actual.size(),
		"chain_head": actual[-1].get("result_hash"),
		"cases": actual.duplicate(true),
		"public_only": true,
		"authoritative": false,
		"execution_authority": false,
	}
	_ok = true
	_error_code = ""


func _fail(code: String) -> void:
	_ok = false
	_error_code = code


func validate_integrity() -> bool:
	if not _cases is Array or _cases.is_empty() or not _expected is Dictionary:
		return false
	var expected := {
		"accepted": true,
		"case_count": _cases.size(),
		"chain_head": _cases[-1].get("result_hash"),
		"cases": _cases.duplicate(true),
		"public_only": true,
		"authoritative": false,
		"execution_authority": false,
	}
	if (
		not _ok
		or _document_integrity_sha256 != EXPECTED_DOCUMENT_INTEGRITY_SHA256
		or not _bundle is Dictionary
		or _canonical_sha256(_bundle) != EXPECTED_BUNDLE_CANONICAL_SHA256
		or not _documents is Dictionary
		or _canonical_sha256(_documents) != EXPECTED_DOCUMENT_INTEGRITY_SHA256
		or _cases != _documents.get("audit", {}).get("cases")
		or _expected != expected
		or _contains_forbidden(expected)
		or _parent_owner == null or not bool(_parent_owner.get("ok"))
		or _firewall == null or not bool(_firewall.get("ok"))
		or _contracts == null or not bool(_contracts.get("ok")) or not _contracts.validate_integrity()
		or _ir == null or not StrategicTraceScript.validate_ir(_ir)
	):
		return false
	return true


func bundle_hash() -> String:
	return EXPECTED_BUNDLE_CANONICAL_SHA256 if validate_integrity() else ""


func evaluate_all() -> Variant:
	if not validate_integrity():
		return null
	var result := ResultValue.new(self, _expected, RESULT_TOKEN)
	_register_result(result, _expected)
	return result


func evaluate_case(case_id: Variant) -> Dictionary:
	if not validate_integrity() or typeof(case_id) != TYPE_STRING:
		return {}
	for case_value: Variant in _cases:
		if case_value is Dictionary and case_value.get("case_id") == case_id:
			return case_value.duplicate(true)
	return {}


func _validate_result(value: Variant) -> bool:
	var entry := _result_registry_entry(value)
	return (
		validate_integrity()
		and value is ResultValue
		and not entry.is_empty()
		and entry.get("owner") == self
		and entry.get("snapshot") == _expected
		and value.get("_owner") == self
		and value.get("_factory_token") == RESULT_TOKEN
		and value.get("_snapshot") is Dictionary
		and value.get("_snapshot") == _expected
		and value.get("_snapshot_hash") == _canonical_sha256(_expected)
		and not _contains_forbidden(value.get("_snapshot"))
	)


func _register_result(value: Variant, snapshot: Dictionary) -> void:
	_RESULT_REGISTRY[value.get_instance_id()] = {
		"weak": weakref(value), "owner": self, "snapshot": snapshot.duplicate(true),
	}
	_prune_result_registry()


static func _result_registry_entry(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_OBJECT or value == null:
		return {}
	var entry_value: Variant = _RESULT_REGISTRY.get(value.get_instance_id())
	if not entry_value is Dictionary:
		return {}
	var reference: Variant = entry_value.get("weak")
	if typeof(reference) != TYPE_OBJECT or reference == null or reference.get_ref() != value:
		return {}
	return entry_value


static func _prune_result_registry() -> void:
	if _RESULT_REGISTRY.size() < 128:
		return
	for instance_id: Variant in _RESULT_REGISTRY.keys():
		var entry_value: Variant = _RESULT_REGISTRY.get(instance_id)
		var reference: Variant = entry_value.get("weak") if entry_value is Dictionary else null
		if typeof(reference) != TYPE_OBJECT or reference == null or reference.get_ref() == null:
			_RESULT_REGISTRY.erase(instance_id)


func run(operation: Variant, input_value: Variant) -> Dictionary:
	if not validate_integrity():
		return _result(null, "contract_integrity_invalid")
	if typeof(operation) != TYPE_STRING or not input_value is Dictionary:
		return _result(null, "input_type_invalid")
	if operation == "evaluate_all":
		if not input_value.is_empty():
			return _result(null, "input_type_invalid")
		return _result(evaluate_all().to_public_dict())
	if operation == "evaluate_case":
		if not _same_keys(input_value, ["case_id"]) or typeof(input_value.get("case_id")) != TYPE_STRING:
			return _result(null, "input_type_invalid")
		var case_value := evaluate_case(input_value.get("case_id"))
		return _result(null, "case_unknown") if case_value.is_empty() else _result(case_value)
	return _result(null, "operation_unknown")


func audit_snapshot() -> Dictionary:
	if not validate_integrity():
		return {}
	return {
		"bundle_canonical_sha256": EXPECTED_BUNDLE_CANONICAL_SHA256,
		"document_integrity_sha256": EXPECTED_DOCUMENT_INTEGRITY_SHA256,
		"case_count": _cases.size(),
		"macro_count": _documents.get("profile", {}).get("macro_catalog", []).size(),
		"execution_authority": false,
		"live_consumer": false,
	}


func _execute_cases(root: String, contract_root: String) -> Dictionary:
	var profile: Dictionary = _documents.get("profile")
	var results: Array = []
	var previous: Variant = null
	for ordinal: int in profile.get("case_catalog", []).size():
		var case: Dictionary = profile.get("case_catalog")[ordinal]
		var outcome := _execute_case(case, ordinal, previous, root, contract_root)
		if not bool(outcome.get("ok", false)):
			return outcome
		var result: Dictionary = outcome.get("value")
		results.append(result)
		previous = result.get("result_hash")
	return _result(results)


func _execute_case(case: Dictionary, ordinal: int, previous: Variant, root: String, contract_root: String) -> Dictionary:
	var frame: Dictionary = _parent_owner.frame(case.get("source_frame_id"))
	if frame.is_empty():
		return _result(null, "source_frame_invalid")
	if frame.get("public_tree") == null:
		return _result(_not_applicable(case, ordinal, "terminal_no_callback" if frame.get("terminal") else "initial_no_window", previous))
	var decoded: Variant = _decode_public_node(frame.get("public_tree"))
	if not decoded is Dictionary:
		return _result(null, "source_frame_invalid")
	var public: Variant = _apply_patches(decoded, case.get("patches", []))
	if not public is Dictionary:
		return _result(null, "source_frame_invalid")
	var raw: Dictionary = public.duplicate(true)
	raw["search_begin_input"] = null
	var parsed: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(raw, _contracts)
	var firewall_result: Variant = _firewall.project(parsed)
	if firewall_result == null or not bool(firewall_result.get("accepted")):
		return _result(_not_applicable(case, ordinal, "firewall_not_accepted", previous))
	var accepted_value: Variant = firewall_result.get("public_observation")
	if not accepted_value is Dictionary or accepted_value.get("current") == null or accepted_value.get("select") == null:
		return _result(_not_applicable(case, ordinal, "initial_no_window", previous))
	var accepted: Dictionary = accepted_value
	var current: Dictionary = accepted.get("current")
	var window_input := {
		"public_observation_hash": firewall_result.get("public_observation_hash"),
		"public_hash_authority": "firewall_accepted",
		"chooser_player_index": current.get("yourIndex"),
		"select": _copy(accepted.get("select")),
	}
	var window_outcome: Variant = CabtSelectionWindowScript.build(window_input, _contracts)
	if window_outcome == null or window_outcome.get("decision_state") != "policy_allowed" or window_outcome.get("window") == null:
		return _result(null, "runtime_conformance_mismatch")
	var window: Variant = window_outcome.get("window")
	var context_outcome: Variant = StrategicContextScript.build_context(firewall_result, window, contract_root)
	if context_outcome == null or not bool(context_outcome.get("accepted")) or context_outcome.get("context") == null:
		return _result(null, "runtime_conformance_mismatch")
	var context: Variant = context_outcome.get("context")
	var proof_outcome := _proof(case, accepted, window)
	if not bool(proof_outcome.get("ok", false)):
		return proof_outcome
	var proof: Variant = proof_outcome.get("value")
	var adapter_document := _adapter_document(case, proof, _documents.get("profile", {}).get("macro_catalog", []))
	if adapter_document.is_empty():
		return _result(null, "macro_proof_invalid")
	var adapter_outcome: Variant = PublicDeckAdapterScript.compile(adapter_document, contract_root)
	if adapter_outcome == null or not bool(adapter_outcome.get("accepted")) or adapter_outcome.get("adapter") == null:
		return _result(null, "runtime_conformance_mismatch")
	var adapter: Variant = adapter_outcome.get("adapter")
	var proposal_id := "%s.proposal" % case.get("case_id")
	var proposal_outcome: Variant = PublicDeckAdapterScript.propose(context, adapter, proposal_id, contract_root)
	if proposal_outcome == null or not bool(proposal_outcome.get("accepted")) or proposal_outcome.get("result") == null:
		return _result(null, "runtime_conformance_mismatch")
	var proposal: Dictionary = proposal_outcome.get("result").to_public_dict()
	var adapter_indexes: Array = []
	for proposal_value: Variant in proposal.get("adapter_proposals", []):
		if proposal_value is Dictionary and proposal_value.get("operator") == "macro_proposal":
			for index_value: Variant in proposal_value.get("indexes", []):
				if not adapter_indexes.has(index_value):
					adapter_indexes.append(index_value)
	if proof != null and adapter_indexes != proof.get("intent_indexes"):
		return _result(null, "runtime_conformance_mismatch")
	var hard_tiers: Array = []
	for option_index: int in int(window.get("option_count")):
		hard_tiers.append({"index": option_index, "tier": [0]})
	var request := {
		"orchestration_id": "%s.orchestration" % case.get("case_id"),
		"proposal_id": proposal_id,
		"execution_id": "%s.execution" % case.get("case_id"),
		"scene_id": "%s.scene" % case.get("case_id"),
		"decision_id": "%s.decision" % case.get("case_id"),
		"determinism_key": "%s.determinism" % case.get("case_id"),
		"trace_id": "%s.trace" % case.get("case_id"),
		"policy_hash": _documents.get("profile", {}).get("policy_hash"),
		"mandatory_indexes": [], "terminal_indexes": [],
		"base_hard_tiers": hard_tiers, "base_vetoed_indexes": [],
	}
	var orchestration: Variant = PublicBasePolicyScript.orchestrate(context, window, _ir, adapter, request, contract_root)
	if orchestration == null or not bool(orchestration.get("accepted")) or orchestration.get("result") == null:
		return _result(null, "runtime_conformance_mismatch")
	var base: Dictionary = orchestration.get("result").to_public_dict()
	var source: Dictionary = base.get("source", {})
	var payload := {
		"ordinal": ordinal, "case_id": case.get("case_id"), "source_frame_id": case.get("source_frame_id"),
		"evidence_class": case.get("evidence_class"), "offline_seeded_extension": case.get("offline_seeded_extension"),
		"status": "orchestrated", "reason_code": "base_orchestrated", "macro_id": case.get("macro_id"),
		"macro_phase": case.get("macro_phase"), "public_observation_hash": firewall_result.get("public_observation_hash"),
		"window_id": window.get("window_id"), "context_hash": context.get("context_hash"),
		"intent_indexes": [] if proof == null else proof.get("intent_indexes").duplicate(true),
		"adapter_indexes": adapter_indexes.duplicate(true), "selected_indexes": base.get("selected_indexes", []).duplicate(true),
		"macro_proof_hash": null if proof == null else proof.get("macro_proof_hash"),
		"adapter_hash": source.get("adapter_hash"), "proposal_hash": source.get("proposal_hash"),
		"ir_hash": source.get("ir_hash"), "execution_hash": source.get("execution_hash"),
		"decision_audit_id": source.get("decision_audit_id"), "trace_hash": source.get("trace_hash"),
		"orchestration_hash": base.get("orchestration_hash"), "previous_result_hash": previous,
		"public_only": true, "authoritative": false, "execution_authority": false,
	}
	payload["result_hash"] = _domain_hash(RESULT_PREFIX_UTF8_HEX, payload)
	return _result(payload) if not payload.get("result_hash", "").is_empty() else _result(null, "runtime_conformance_mismatch")


static func _not_applicable(case: Dictionary, ordinal: int, reason: String, previous: Variant) -> Dictionary:
	var payload := {
		"ordinal": ordinal, "case_id": case.get("case_id"), "source_frame_id": case.get("source_frame_id"),
		"evidence_class": case.get("evidence_class"), "offline_seeded_extension": case.get("offline_seeded_extension"),
		"status": "not_applicable", "reason_code": reason, "macro_id": case.get("macro_id"),
		"macro_phase": case.get("macro_phase"), "public_observation_hash": null, "window_id": null,
		"context_hash": null, "intent_indexes": [], "adapter_indexes": [], "selected_indexes": [],
		"macro_proof_hash": null, "adapter_hash": null, "proposal_hash": null, "ir_hash": null,
		"execution_hash": null, "decision_audit_id": null, "trace_hash": null, "orchestration_hash": null,
		"previous_result_hash": previous, "public_only": true, "authoritative": false, "execution_authority": false,
	}
	payload["result_hash"] = _domain_hash(RESULT_PREFIX_UTF8_HEX, payload)
	return payload


static func _proof(case: Dictionary, public: Dictionary, window: Variant) -> Dictionary:
	var macro_id: Variant = case.get("macro_id")
	var phase: Variant = case.get("macro_phase")
	if macro_id == null:
		return _result(null)
	var chooser := int(public.get("current", {}).get("yourIndex"))
	var players: Array = public.get("current", {}).get("players", [])
	if players.size() != 2:
		return _result(null, "macro_proof_invalid")
	var acting: Dictionary = players[chooser]
	var select_value: Dictionary = public.get("select")
	var options: Array = window.get("options")
	var intent: Array = []
	var constraints: Array = []
	if macro_id == "marnie.engine.poffin_primary":
		for index: int in options.size():
			var option: Dictionary = options[index]
			if option.get("type") == 7 and _hand_card(select_value, public, option).get("id") == 1086:
				intent.append(index)
		if acting.get("bench", []).size() >= int(acting.get("benchMax")):
			intent = []
		constraints = ["bench_space", "hand_card_1086", "current_play_option"]
	elif macro_id == "marnie.engine.spikemuth_tutor" and phase == "play_stadium":
		for index: int in options.size():
			var option: Dictionary = options[index]
			if option.get("type") == 7 and _hand_card(select_value, public, option).get("id") == 1259:
				intent.append(index)
		constraints = ["hand_card_1259", "current_play_option"]
	elif macro_id == "marnie.engine.spikemuth_tutor":
		for index: int in options.size():
			if [646, 647, 648].has(_option_card(select_value, public, options[index]).get("id")):
				intent.append(index)
		if not _card_ids(public.get("current", {}).get("stadium", [])).has(1259) or select_value.get("type") != 1 or select_value.get("context") != 7:
			intent = []
		constraints = ["stadium_card_1259", "authorized_deck_window", "marnie_evolution_line"]
	elif macro_id == "marnie.engine.evolve_grimmsnarl":
		for index: int in options.size():
			var option: Dictionary = options[index]
			if option.get("type") == 7 and _hand_card(select_value, public, option).get("id") == 648:
				intent.append(index)
		var in_play := _card_ids(acting.get("active", []))
		for card_id: Variant in _card_ids(acting.get("bench", [])):
			in_play[card_id] = true
		if not in_play.has(647):
			intent = []
		constraints = ["hand_card_648", "public_stage_647", "current_play_option"]
	elif macro_id == "marnie.energy.punk_up" and phase == "choose_energy_sources":
		for index: int in options.size():
			if _option_card(select_value, public, options[index]).get("id") == 7:
				intent.append(index)
		var in_play := _card_ids(acting.get("active", []))
		for card_id: Variant in _card_ids(acting.get("bench", [])):
			in_play[card_id] = true
		if not in_play.has(648) or select_value.get("context") != 22:
			intent = []
		constraints = ["public_grimmsnarl_648", "authorized_dark_energy_options", "no_duplicate_option_index"]
	elif macro_id == "marnie.energy.punk_up":
		for index: int in options.size():
			if [646, 647, 648].has(_option_card(select_value, public, options[index]).get("id")):
				intent.append(index)
		var in_play := _card_ids(acting.get("active", []))
		for card_id: Variant in _card_ids(acting.get("bench", [])):
			in_play[card_id] = true
		if not in_play.has(648) or select_value.get("context") != 21:
			intent = []
		constraints = ["public_grimmsnarl_648", "public_marnie_target", "current_target_window"]
	elif macro_id == "marnie.prize.shadow_bullet" and phase == "choose_attack":
		for index: int in options.size():
			var option: Dictionary = options[index]
			if option.get("type") == 13 and option.get("attackId") == 937:
				intent.append(index)
		if not _card_ids(acting.get("active", [])).has(648):
			intent = []
		constraints = ["public_attacker_648", "official_attack_937", "current_attack_window"]
	elif macro_id == "marnie.prize.shadow_bullet":
		for index: int in options.size():
			var option: Dictionary = options[index]
			if option.get("type") == 3 and option.get("area") == 5 and option.get("playerIndex") == 1 - chooser:
				intent.append(index)
		if not _card_ids(acting.get("active", [])).has(648) or select_value.get("context") != 15:
			intent = []
		constraints = ["public_attacker_648", "current_opponent_bench_options"]
	elif macro_id == "marnie.recover.night_stretcher":
		for index: int in options.size():
			var option: Dictionary = options[index]
			if option.get("type") == 7 and _hand_card(select_value, public, option).get("id") == 1097:
				intent.append(index)
		var discard_ids := _card_ids(acting.get("discard", []))
		if not (discard_ids.has(7) or discard_ids.has(646) or discard_ids.has(647) or discard_ids.has(648)):
			intent = []
		constraints = ["hand_card_1097", "public_discard_recovery_target", "current_play_option"]
	else:
		return _result(null, "macro_proof_invalid")
	if intent.is_empty():
		return _result(null, "macro_proof_invalid")
	var payload := {
		"case_id": case.get("case_id"), "macro_id": macro_id, "macro_phase": phase,
		"evidence_class": case.get("evidence_class"), "public_observation_hash": window.get("public_observation_hash"),
		"window_id": window.get("window_id"), "intent_indexes": intent,
		"constraints_satisfied": constraints, "authoritative": false,
	}
	var proof := payload.duplicate(true)
	proof["macro_proof_hash"] = _domain_hash(PROOF_PREFIX_UTF8_HEX, payload)
	return _result(proof) if not proof.get("macro_proof_hash", "").is_empty() else _result(null, "macro_proof_invalid")


static func _adapter_document(case: Dictionary, proof: Variant, macro_catalog: Array) -> Dictionary:
	var macro_id: Variant = case.get("macro_id")
	var phase: Variant = case.get("macro_phase")
	var rule: Dictionary
	if proof == null:
		rule = {"rule_id": "base.no-macro", "operator": "goal_proposal", "reason_code": "public_goal_proposal", "goal_stage": "maintain", "priority": 0, "predicate": _predicate({"select_type_raw": 2147483647})}
	else:
		var predicate: Dictionary
		if macro_id == "marnie.engine.poffin_primary": predicate = _predicate({"select_type_raw":0,"select_context_raw":0,"option_type_raw":7,"acting_hand_card_id":1086})
		elif macro_id == "marnie.engine.spikemuth_tutor" and phase == "play_stadium": predicate = _predicate({"select_type_raw":0,"select_context_raw":0,"option_type_raw":7,"acting_hand_card_id":1259})
		elif macro_id == "marnie.engine.spikemuth_tutor": predicate = _predicate({"select_type_raw":1,"select_context_raw":7,"option_type_raw":3})
		elif macro_id == "marnie.engine.evolve_grimmsnarl": predicate = _predicate({"select_type_raw":0,"select_context_raw":0,"option_type_raw":7,"acting_hand_card_id":648})
		elif macro_id == "marnie.energy.punk_up" and phase == "choose_energy_sources": predicate = _predicate({"select_type_raw":1,"select_context_raw":22,"option_type_raw":3,"acting_active_card_id":648})
		elif macro_id == "marnie.energy.punk_up": predicate = _predicate({"select_type_raw":1,"select_context_raw":21,"option_type_raw":3,"acting_active_card_id":648})
		elif macro_id == "marnie.prize.shadow_bullet" and phase == "choose_attack": predicate = _predicate({"select_type_raw":0,"select_context_raw":0,"option_type_raw":13,"acting_active_card_id":648})
		elif macro_id == "marnie.prize.shadow_bullet": predicate = _predicate({"select_type_raw":1,"select_context_raw":15,"option_type_raw":3,"option_player_index":1,"acting_active_card_id":648})
		elif macro_id == "marnie.recover.night_stretcher": predicate = _predicate({"select_type_raw":0,"select_context_raw":0,"option_type_raw":7,"acting_hand_card_id":1097})
		else: return {}
		var stage := ""
		for macro_value: Variant in macro_catalog:
			if macro_value is Dictionary and macro_value.get("macro_id") == macro_id:
				stage = str(macro_value.get("goal_stage"))
		if stage.is_empty(): return {}
		rule = {"rule_id": "%s.%s" % [macro_id, phase], "operator": "macro_proposal", "reason_code": "public_macro_proposal", "goal_stage": stage, "priority": 0, "predicate": predicate}
	return {"schema_version": 1, "adapter_id": "marnie.%s" % case.get("case_id"), "adapter_version": 1, "rules": [rule]}


static func _predicate(updates: Dictionary) -> Dictionary:
	var value := {"select_type_raw":null,"select_context_raw":null,"option_type_raw":null,"option_card_id":null,"option_player_index":null,"acting_hand_card_id":null,"acting_active_card_id":null}
	for key: Variant in updates:
		value[key] = updates[key]
	return value


static func _hand_card(select_value: Dictionary, public: Dictionary, option: Dictionary) -> Dictionary:
	return _option_card(select_value, public, {"area": 2, "index": option.get("index")})


static func _option_card(select_value: Dictionary, public: Dictionary, option: Dictionary) -> Dictionary:
	var index_value: Variant = option.get("index")
	if typeof(index_value) != TYPE_INT:
		return {}
	var index := int(index_value)
	var chooser := int(public.get("current", {}).get("yourIndex"))
	var players: Array = public.get("current", {}).get("players", [])
	if players.size() != 2:
		return {}
	var values: Variant = null
	match option.get("area"):
		1: values = select_value.get("deck")
		2: values = players[chooser].get("hand")
		3: values = players[chooser].get("discard")
		4: values = players[chooser].get("active")
		5:
			var owner: Variant = option.get("playerIndex", chooser)
			values = players[int(owner)].get("bench") if typeof(owner) == TYPE_INT and int(owner) in [0, 1] else null
		6: values = players[chooser].get("prize")
	if not values is Array or index < 0 or index >= values.size() or not values[index] is Dictionary:
		return {}
	return values[index]


static func _card_ids(value: Variant) -> Dictionary:
	var result := {}
	if value is Array:
		for card_value: Variant in value:
			if card_value is Dictionary and typeof(card_value.get("id")) == TYPE_INT:
				result[card_value.get("id")] = true
	return result


static func _apply_patches(value: Dictionary, patches: Variant) -> Variant:
	if not patches is Array:
		return null
	var result: Variant = value.duplicate(true)
	for patch_value: Variant in patches:
		if not patch_value is Dictionary or not patch_value.get("path") is Array:
			return null
		var path: Array = patch_value.get("path")
		if path.is_empty(): return null
		var parent: Variant = result
		var stop := path.size() - 1 if patch_value.get("op") == "set" else path.size()
		for part_index: int in stop:
			var part: Variant = path[part_index]
			if not (parent is Dictionary or parent is Array): return null
			parent = parent[part]
		if patch_value.get("op") == "set":
			parent[path[-1]] = _copy(patch_value.get("value"))
		elif patch_value.get("op") == "append" and parent is Array:
			parent.append(_copy(patch_value.get("value")))
		else:
			return null
	return result


static func _decode_public_node(node: Variant) -> Variant:
	if not node is Dictionary or typeof(node.get("kind")) != TYPE_STRING:
		return null
	match node.get("kind"):
		"null": return null
		"boolean", "integer", "string": return node.get("value")
		"binary64":
			var bytes: PackedByteArray = str(node.get("ieee754_hex", "")).hex_decode()
			if bytes.size() != 8: return null
			bytes.reverse()
			return bytes.decode_double(0)
		"array":
			if not node.get("items") is Array: return null
			var array: Array = []
			for child: Variant in node.get("items"): array.append(_decode_public_node(child))
			return array
		"object":
			if not node.get("entries") is Array: return null
			var object: Dictionary = {}
			for entry_value: Variant in node.get("entries"):
				if not entry_value is Dictionary or typeof(entry_value.get("key")) != TYPE_STRING or object.has(entry_value.get("key")): return null
				object[entry_value.get("key")] = _decode_public_node(entry_value.get("value"))
			return object
	return null


static func _contains_forbidden(value: Variant) -> bool:
	if value is Dictionary:
		for key: Variant in value:
			if typeof(key) != TYPE_STRING or FORBIDDEN_PUBLIC_KEYS.has(key) or _contains_forbidden(value[key]): return true
	elif value is Array:
		for item: Variant in value:
			if _contains_forbidden(item): return true
	return false


static func _result(value: Variant, error: String = "") -> Dictionary:
	return {"ok": error.is_empty(), "error_code": error, "value": _copy(value) if error.is_empty() else null}


static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


static func _same_keys(value: Variant, expected: Array) -> bool:
	if not value is Dictionary or value.size() != expected.size(): return false
	for key: Variant in expected:
		if typeof(key) != TYPE_STRING or not value.has(key): return false
	return true


static func _root_is_supported(root: String) -> bool:
	return root.begins_with("res://") or root.begins_with("user://")


static func _is_safe_relative_path(path: String) -> bool:
	return not path.is_empty() and not path.begins_with("/") and not path.contains("\\") and not path.split("/").has("..") and not path.split("/").has(".")


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return _result(null, "contract_integrity_invalid")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _result(null, "contract_integrity_invalid")
	var length := file.get_length()
	if length < 1 or length > MAX_JSON_BYTES: return _result(null, "contract_integrity_invalid")
	var source_bytes := file.get_buffer(length)
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(source_bytes, {"max_input_bytes": MAX_JSON_BYTES, "max_output_bytes": MAX_JSON_BYTES})
	if not bool(canonical.get("ok", false)): return _result(null, "contract_integrity_invalid")
	var text := source_bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != source_bytes: return _result(null, "contract_integrity_invalid")
	var parser := JSON.new()
	if parser.parse(text) != OK: return _result(null, "contract_integrity_invalid")
	var state := {"ok": true}
	var restored: Variant = _restore_integer_tokens(parser.data, state)
	if not bool(state.get("ok", false)) or not restored is Dictionary: return _result(null, "contract_integrity_invalid")
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
				if not bool(state.get("ok", false)): return null
			return array
		TYPE_DICTIONARY:
			var object: Dictionary = {}
			for key: Variant in value:
				if typeof(key) != TYPE_STRING:
					state["ok"] = false
					return null
				object[key] = _restore_integer_tokens(value[key], state)
				if not bool(state.get("ok", false)): return null
			return object
		_: return value


static func _canonical_sha256(value: Variant) -> String:
	var canonical := CabtJsonTreeScript.canonicalize_artifact(value, {"max_input_bytes": MAX_JSON_BYTES, "max_output_bytes": MAX_JSON_BYTES})
	if not bool(canonical.get("ok", false)): return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(canonical.get("bytes", PackedByteArray())) != OK: return ""
	return context.finish().hex_encode().to_upper()


static func _domain_hash(prefix_hex: String, value: Variant) -> String:
	var canonical := CabtJsonTreeScript.canonicalize_artifact(value, {"max_input_bytes": MAX_JSON_BYTES, "max_output_bytes": MAX_JSON_BYTES})
	if not bool(canonical.get("ok", false)): return ""
	var bytes: PackedByteArray = prefix_hex.hex_decode()
	bytes.append_array(canonical.get("bytes", PackedByteArray()))
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK: return ""
	return context.finish().hex_encode().to_upper()
