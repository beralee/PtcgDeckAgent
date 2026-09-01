class_name PublicBasePolicyCore
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const CabtSelectionSanitizerScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionSanitizer.gd")
const CabtDeterministicFallbackScript = preload("res://scripts/ai/ptcgdap/cabt/CabtDeterministicFallback.gd")
const PublicObservationFirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const PublicDeckAdapterScript = preload("res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")
const ExecutorScript = preload("res://scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd")
const StrategicContextScript = preload("res://scripts/ai/ptcgdap/public/StrategicContextV18.gd")
const StrategicTraceScript = preload("res://scripts/ai/ptcgdap/public/StrategicTraceV2.gd")

const DEFAULT_ROOT := "res://contracts/ptcgdap"
const PROFILE_ID := "ptcgdap-public-base-policy-p4-wp5-v1"
const EXPECTED_BUNDLE_SHA256 := "18AAB663D9B429AC8657A75692F5DD8CF37C409CC057A328B57758C692FDB7F4"
const EXPECTED_PARENT_BUNDLE_SHA256 := "C80F4C4FDAEA5AC29BD3C5617BFAC72BE38709696F7EA1995D3D153113DD3CA1"
const EXPECTED_SOURCE_LOCK_SHA256 := "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
const EXPECTED_ARTIFACT_NAMES := [
	"public_base_policy.schema.json",
	"public_base_policy_profile.json",
	"public_base_policy_conformance_vectors.json",
]
const EXPECTED_ARTIFACTS := {
	"public_base_policy.schema.json": "25041F0E72EEC217522B0606CA77C100D66DD76ECED39C7F3B233DFB4C0FB42D",
	"public_base_policy_profile.json": "AEA206038915757F1D32004CBF0E5662A244953A5D40C7952281E861D4E3313C",
	"public_base_policy_conformance_vectors.json": "377F5BB2B3DE594D1DD17B5FD548D6EAB26D5CA7D933DBEF6D8B24216CE65072",
}
const ORCHESTRATION_PREFIX_UTF8_HEX := "50544347444150005055424C49435F424153455F504F4C4943595F4F524348455354524154494F4E5F563100"
const MAX_CONTRACT_BYTES := 2 * 1024 * 1024
const MAX_VALUE_BYTES := 1024 * 1024
const MAX_SAFE_INTEGER := 9007199254740991
const STAGES := [
	"validate_exact_owners",
	"propose_public_adapter_hints",
	"execute_restricted_base_graph",
	"sanitize_against_exact_current_window",
	"issue_policy_decision",
	"issue_strategic_trace",
	"seal_public_audit_result",
]
const REQUEST_KEYS := [
	"orchestration_id",
	"proposal_id",
	"execution_id",
	"scene_id",
	"decision_id",
	"determinism_key",
	"trace_id",
	"policy_hash",
	"mandatory_indexes",
	"terminal_indexes",
	"base_hard_tiers",
	"base_vetoed_indexes",
]
const IDENTITY_KEYS := [
	"orchestration_id",
	"proposal_id",
	"execution_id",
	"scene_id",
	"decision_id",
	"determinism_key",
	"trace_id",
]
const PRIVATE_KEYS := {
	"raw_private_hash": true,
	"token_free_callback_hash": true,
	"search_begin_input": true,
	"session": true,
	"callback": true,
	"binding": true,
	"ticket": true,
	"command": true,
	"object_ref": true,
	"pokemon_entity_serial": true,
}

static var _RESULT_TOKEN: RefCounted = RefCounted.new()
static var _RESULT_REGISTRY: Array = []
static var _DEFAULT_CONTRACT_CACHE: Dictionary = {}


class OrchestrationOutcome extends RefCounted:
	var accepted := false
	var failed_stage := "contract"
	var error_code := "contract_error"
	var result: Variant = null

	func _init(accepted_value: bool, stage_value: String, error_value: String, result_value: Variant = null) -> void:
		accepted = accepted_value
		failed_stage = stage_value
		error_code = error_value
		result = result_value


class ResultValue extends RefCounted:
	var _snapshot: Variant = {}
	var _request: Variant = {}
	var _factory_token: Variant = null
	var _context_binding: Variant = null
	var _window_binding: Variant = null
	var _ir_binding: Variant = null
	var _adapter_binding: Variant = null
	var _proposal_binding: Variant = null
	var _execution_binding: Variant = null
	var _resolution_binding: Variant = null
	var _decision_binding: Variant = null
	var _trace_binding: Variant = null

	var decision: Variant:
		get:
			var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicBasePolicy.gd")
			return _decision_binding if bool(owner.call("validate_result", self, _context_binding, _window_binding, _ir_binding, _adapter_binding)) else null

	var trace: Variant:
		get:
			var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicBasePolicy.gd")
			return _trace_binding if bool(owner.call("validate_result", self, _context_binding, _window_binding, _ir_binding, _adapter_binding)) else null

	func _init(
		snapshot_value: Dictionary = {},
		request_value: Dictionary = {},
		bindings: Dictionary = {},
		token_value: Variant = null,
	) -> void:
		_snapshot = snapshot_value.duplicate(true)
		_request = request_value.duplicate(true)
		_factory_token = token_value
		_context_binding = bindings.get("context")
		_window_binding = bindings.get("window")
		_ir_binding = bindings.get("ir")
		_adapter_binding = bindings.get("adapter")
		_proposal_binding = bindings.get("proposal")
		_execution_binding = bindings.get("execution")
		_resolution_binding = bindings.get("resolution")
		_decision_binding = bindings.get("decision")
		_trace_binding = bindings.get("trace")

	func validate_integrity(context_value: Variant, window_value: Variant, ir_value: Variant, adapter_value: Variant) -> bool:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicBasePolicy.gd")
		return bool(owner.call("validate_result", self, context_value, window_value, ir_value, adapter_value))

	func to_public_dict() -> Dictionary:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicBasePolicy.gd")
		return owner.call("result_public_dict", self)

	func agent_output() -> Array:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicBasePolicy.gd")
		return owner.call("result_agent_output", self)


static func orchestrate(
	context: Variant,
	window: Variant,
	ir: Variant,
	adapter: Variant,
	request: Variant,
	contract_root: Variant = DEFAULT_ROOT,
) -> OrchestrationOutcome:
	if typeof(contract_root) != TYPE_STRING or not _load_contracts(str(contract_root)).get("ok", false):
		return _failure("contract", "contract_error")
	var owner_error := _exact_owner_error(context, window, ir, adapter)
	if not owner_error.is_empty():
		return _failure("validate_exact_owners", owner_error)
	var request_error := _request_error(request, int(window.get("option_count")))
	if not request_error.is_empty():
		return _failure("validate_exact_owners", request_error)
	var request_value: Dictionary = request.duplicate(true)

	var proposal_outcome: Variant = PublicDeckAdapterScript.propose(context, adapter, request_value.proposal_id)
	if not bool(proposal_outcome.get("accepted")) or proposal_outcome.get("result") == null:
		return _failure("propose_public_adapter_hints", "adapter_proposal_failed")
	var proposal: Variant = proposal_outcome.get("result")
	var execution_input := {
		"execution_id": request_value.execution_id,
		"mandatory_indexes": request_value.mandatory_indexes.duplicate(true),
		"terminal_indexes": request_value.terminal_indexes.duplicate(true),
		"base_hard_tiers": request_value.base_hard_tiers.duplicate(true),
		"base_vetoed_indexes": request_value.base_vetoed_indexes.duplicate(true),
		"adapter_proposals": proposal.adapter_proposals,
	}
	var execution_outcome: Variant = ExecutorScript.execute(context, ir, execution_input)
	if not bool(execution_outcome.get("accepted")) or execution_outcome.get("result") == null:
		return _failure("execute_restricted_base_graph", "base_execution_failed")
	var execution: Variant = execution_outcome.get("result")
	var resolution: Variant = CabtSelectionSanitizerScript.resolve_policy_attempt(
		window,
		{"status": "returned", "output": execution.selected_indexes},
	)
	if (
		resolution == null
		or not CabtDeterministicFallbackScript.validate_resolution_integrity(resolution, window)
		or resolution.get("owner") != "policy"
		or resolution.get("selected_indexes") != execution.selected_indexes
	):
		return _failure("sanitize_against_exact_current_window", "selection_sanitization_failed")

	var decision_outcome: Variant = StrategicContextScript.build_policy_decision(
		context,
		window,
		resolution,
		request_value.policy_hash,
		request_value.scene_id,
		request_value.decision_id,
		request_value.determinism_key,
	)
	if not bool(decision_outcome.get("accepted")) or decision_outcome.get("decision") == null:
		return _failure("issue_policy_decision", "policy_decision_failed")
	var decision_value: Variant = decision_outcome.get("decision")
	var option_count := int(window.get("option_count"))
	var frontier := range(option_count)
	var trace_audit := {
		"legal_indexes": Array(frontier),
		"strategic_indexes": Array(frontier),
		"mandatory_indexes": request_value.mandatory_indexes.duplicate(true),
		"terminal_indexes": request_value.terminal_indexes.duplicate(true),
		"base_hard_tiers": request_value.base_hard_tiers.duplicate(true),
		"base_vetoed_indexes": request_value.base_vetoed_indexes.duplicate(true),
		"adapter_proposals": proposal.adapter_proposals,
		"fallback_reason": "",
	}
	var trace_outcome: Variant = StrategicTraceScript.build_trace(
		context,
		decision_value,
		ir,
		request_value.trace_id,
		trace_audit,
	)
	if not bool(trace_outcome.get("accepted")) or trace_outcome.get("trace") == null:
		return _failure("issue_strategic_trace", "strategic_trace_failed")
	var trace_value: Variant = trace_outcome.get("trace")
	var bindings := {
		"context": context,
		"window": window,
		"ir": ir,
		"adapter": adapter,
		"proposal": proposal,
		"execution": execution,
		"resolution": resolution,
		"decision": decision_value,
		"trace": trace_value,
	}
	var payload := _result_payload(bindings, request_value)
	if payload.is_empty():
		return _failure("seal_public_audit_result", "orchestration_integrity_invalid")
	var result := ResultValue.new(payload, request_value, bindings, _RESULT_TOKEN)
	_register_result(result, payload, request_value, bindings)
	if not validate_result(result, context, window, ir, adapter):
		return _failure("seal_public_audit_result", "orchestration_integrity_invalid")
	return OrchestrationOutcome.new(true, "", "", result)


static func validate_result(value: Variant, context: Variant, window: Variant, ir: Variant, adapter: Variant) -> bool:
	var entry := _registry_entry(value)
	if (
		not value is ResultValue
		or entry.is_empty()
		or value.get("_factory_token") != _RESULT_TOKEN
		or context != value.get("_context_binding")
		or window != value.get("_window_binding")
		or ir != value.get("_ir_binding")
		or adapter != value.get("_adapter_binding")
		or context != entry.get("context")
		or window != entry.get("window")
		or ir != entry.get("ir")
		or adapter != entry.get("adapter")
		or not value.get("_snapshot") is Dictionary
		or not value.get("_request") is Dictionary
		or value.get("_snapshot") != entry.get("snapshot")
		or value.get("_request") != entry.get("request")
		or not _exact_owner_error(context, window, ir, adapter).is_empty()
		or not PublicDeckAdapterScript.validate_result(value.get("_proposal_binding"), context, adapter)
		or not ExecutorScript.validate_result(value.get("_execution_binding"), context, ir)
		or not CabtDeterministicFallbackScript.validate_resolution_integrity(value.get("_resolution_binding"), window)
		or not StrategicContextScript.validate_decision(value.get("_decision_binding"), context, window, value.get("_resolution_binding"))
		or not StrategicTraceScript.validate_trace(value.get("_trace_binding"), context, value.get("_decision_binding"), ir)
		or value.get("_execution_binding").selected_indexes != value.get("_resolution_binding").get("selected_indexes")
		or not _request_error(value.get("_request"), int(window.get("option_count"))).is_empty()
	):
		return false
	var bindings := {
		"context": context,
		"window": window,
		"ir": ir,
		"adapter": adapter,
		"proposal": value.get("_proposal_binding"),
		"execution": value.get("_execution_binding"),
		"resolution": value.get("_resolution_binding"),
		"decision": value.get("_decision_binding"),
		"trace": value.get("_trace_binding"),
	}
	var expected := _result_payload(bindings, value.get("_request"))
	return not expected.is_empty() and value.get("_snapshot") == expected


static func result_public_dict(value: Variant) -> Dictionary:
	return value.get("_snapshot").duplicate(true) if validate_result(value, value.get("_context_binding"), value.get("_window_binding"), value.get("_ir_binding"), value.get("_adapter_binding")) else {}


static func result_agent_output(value: Variant) -> Array:
	if not validate_result(value, value.get("_context_binding"), value.get("_window_binding"), value.get("_ir_binding"), value.get("_adapter_binding")):
		return []
	return value.get("_resolution_binding").get("selected_indexes").duplicate(true)


static func _result_payload(bindings: Dictionary, request: Dictionary) -> Dictionary:
	var context: Variant = bindings.context
	var window: Variant = bindings.window
	var ir: Variant = bindings.ir
	var adapter: Variant = bindings.adapter
	var proposal: Variant = bindings.proposal
	var execution: Variant = bindings.execution
	var decision_value: Variant = bindings.decision
	var trace_value: Variant = bindings.trace
	var context_public: Dictionary = StrategicContextScript.context_public_dict(context)
	var ir_public: Dictionary = StrategicTraceScript.ir_public_dict(ir)
	var adapter_public: Dictionary = PublicDeckAdapterScript.adapter_public_dict(adapter)
	var decision_public: Dictionary = StrategicContextScript.decision_public_dict(decision_value)
	if context_public.is_empty() or ir_public.is_empty() or adapter_public.is_empty() or decision_public.is_empty():
		return {}
	var payload := {
		"schema_version": 1,
		"profile_id": PROFILE_ID,
		"orchestration_id": request.orchestration_id,
		"source": {
			"context_hash": context_public.context_hash,
			"window_id": window.get("window_id"),
			"ir_hash": ir_public.ir_hash,
			"adapter_hash": adapter_public.adapter_hash,
			"proposal_hash": proposal.proposal_hash,
			"execution_hash": execution.execution_hash,
			"decision_audit_id": decision_value.audit_id,
			"trace_hash": trace_value.trace_hash,
			"policy_hash": request.policy_hash,
		},
		"selected_indexes": decision_public.selected_indexes.duplicate(true),
		"owner_layer": decision_public.owner_layer,
		"reason_code": decision_public.reason_code,
		"fallback_tier": decision_public.fallback_tier,
		"completed_stages": STAGES.duplicate(true),
		"public_only": true,
		"authority": "public_base_policy_orchestration_audit",
		"authoritative": false,
	}
	var orchestration_hash := _domain_hash(payload)
	if orchestration_hash.is_empty():
		return {}
	payload["orchestration_hash"] = orchestration_hash
	return payload


static func _exact_owner_error(context: Variant, window: Variant, ir: Variant, adapter: Variant) -> String:
	if not StrategicContextScript.validate_context(context):
		return "invalid_context"
	if typeof(window) != TYPE_OBJECT or window == null or not window.has_method("validate_integrity") or not bool(window.call("validate_integrity")):
		return "invalid_window"
	if context.get("_window_binding") != window or context.get("window_id") != window.get("window_id"):
		return "invalid_window"
	if not StrategicTraceScript.validate_ir(ir):
		return "invalid_ir"
	if not PublicDeckAdapterScript.validate_adapter(adapter):
		return "invalid_adapter"
	return ""


static func _request_error(value: Variant, option_count: int) -> String:
	if _contains_private(value):
		return "private_orchestration_input"
	if not value is Dictionary or not _has_exact_keys(value, REQUEST_KEYS):
		return "invalid_orchestration_input"
	for key: String in IDENTITY_KEYS:
		if not _identifier(value.get(key)):
			return "invalid_orchestration_input"
	if not _is_upper_sha256(value.get("policy_hash")):
		return "invalid_orchestration_input"
	for key: String in ["mandatory_indexes", "terminal_indexes", "base_vetoed_indexes"]:
		if not _index_list(value.get(key), option_count):
			return "invalid_orchestration_input"
	var tiers: Variant = value.get("base_hard_tiers")
	if not tiers is Array or tiers.size() != option_count:
		return "invalid_orchestration_input"
	var seen := {}
	for entry: Variant in tiers:
		if not entry is Dictionary or not _has_exact_keys(entry, ["index", "tier"]):
			return "invalid_orchestration_input"
		var index: Variant = entry.get("index")
		var tier: Variant = entry.get("tier")
		if typeof(index) != TYPE_INT or index < 0 or index >= option_count or seen.has(index) or not tier is Array or tier.is_empty() or tier.size() > 8:
			return "invalid_orchestration_input"
		for child: Variant in tier:
			if not _safe_int(child):
				return "invalid_orchestration_input"
		seen[index] = true
	return "" if seen.size() == option_count else "invalid_orchestration_input"


static func _failure(stage: String, code: String) -> OrchestrationOutcome:
	return OrchestrationOutcome.new(false, stage, code)


static func _register_result(value: Variant, snapshot: Dictionary, request: Dictionary, bindings: Dictionary) -> void:
	_prune_registry()
	_RESULT_REGISTRY.append({
		"weak": weakref(value),
		"snapshot": snapshot.duplicate(true),
		"request": request.duplicate(true),
		"context": bindings.context,
		"window": bindings.window,
		"ir": bindings.ir,
		"adapter": bindings.adapter,
	})


static func _registry_entry(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_OBJECT or value == null:
		return {}
	_prune_registry()
	for entry: Variant in _RESULT_REGISTRY:
		var weak_value: Variant = entry.get("weak") if entry is Dictionary else null
		if typeof(weak_value) == TYPE_OBJECT and weak_value != null and weak_value.get_ref() == value:
			return entry
	return {}


static func _prune_registry() -> void:
	for index: int in range(_RESULT_REGISTRY.size() - 1, -1, -1):
		var entry: Variant = _RESULT_REGISTRY[index]
		var weak_value: Variant = entry.get("weak") if entry is Dictionary else null
		if typeof(weak_value) != TYPE_OBJECT or weak_value == null or weak_value.get_ref() == null:
			_RESULT_REGISTRY.remove_at(index)


static func _load_contracts(root_path: String) -> Dictionary:
	var root := root_path.trim_suffix("/")
	if root.is_empty():
		return {"ok": false}
	if root == DEFAULT_ROOT and bool(_DEFAULT_CONTRACT_CACHE.get("ok", false)):
		return _DEFAULT_CONTRACT_CACHE.duplicate(true)
	var bundle_bytes := _load_bytes("%s/public_base_policy_bundle.json" % root)
	if bundle_bytes.is_empty() or _canonical_artifact_sha256(bundle_bytes) != EXPECTED_BUNDLE_SHA256:
		return {"ok": false}
	var parsed := PublicObservationFirewallScript._parse_contract_json_bytes(bundle_bytes)
	var bundle: Variant = parsed.get("value") if bool(parsed.get("ok", false)) else null
	if not bundle is Dictionary or not _has_exact_keys(bundle, ["schema_version", "bundle_id", "parent_bundle_canonical_sha256", "source_lock_canonical_sha256", "artifacts"]):
		return {"ok": false}
	if bundle.get("schema_version") != 1 or bundle.get("bundle_id") != PROFILE_ID or bundle.get("parent_bundle_canonical_sha256") != EXPECTED_PARENT_BUNDLE_SHA256 or bundle.get("source_lock_canonical_sha256") != EXPECTED_SOURCE_LOCK_SHA256:
		return {"ok": false}
	var artifacts: Variant = bundle.get("artifacts")
	if not artifacts is Array or artifacts.size() != EXPECTED_ARTIFACT_NAMES.size():
		return {"ok": false}
	var profile: Variant = null
	for index: int in EXPECTED_ARTIFACT_NAMES.size():
		var name: String = EXPECTED_ARTIFACT_NAMES[index]
		var entry: Variant = artifacts[index]
		if not entry is Dictionary or not _has_exact_keys(entry, ["id", "path", "canonical_sha256"]):
			return {"ok": false}
		if entry.get("id") != name.trim_suffix(".json") or entry.get("path") != "contracts/ptcgdap/%s" % name or entry.get("canonical_sha256") != EXPECTED_ARTIFACTS.get(name):
			return {"ok": false}
		var bytes := _load_bytes("%s/%s" % [root, name])
		if bytes.is_empty() or _canonical_artifact_sha256(bytes) != EXPECTED_ARTIFACTS.get(name):
			return {"ok": false}
		var document := PublicObservationFirewallScript._parse_contract_json_bytes(bytes)
		if not bool(document.get("ok", false)):
			return {"ok": false}
		if name == "public_base_policy_profile.json":
			profile = document.get("value")
	if not profile is Dictionary:
		return {"ok": false}
	var contract: Variant = profile.get("orchestration_contract")
	var result_contract: Variant = profile.get("result_contract")
	if (
		profile.get("profile_id") != PROFILE_ID
		or profile.get("parent_bundle_canonical_sha256") != EXPECTED_PARENT_BUNDLE_SHA256
		or not contract is Dictionary
		or contract.get("fixed_stage_order") != STAGES
		or contract.get("failure_atomicity") != "no_partial_proposal_execution_resolution_decision_or_trace"
		or contract.get("executor_output_revalidated_by_current_window_sanitizer") != true
		or contract.get("mandatory_terminal_precedes_hard_tier") != true
		or contract.get("adapter_authority") != "same_base_tier_ordering_hint_only"
		or not result_contract is Dictionary
		or result_contract.get("serialized_result_is_execution_authority") != false
		or result_contract.get("exact_owner_revalidation_required") != true
	):
		return {"ok": false}
	var result := {"ok": true}
	if root == DEFAULT_ROOT:
		_DEFAULT_CONTRACT_CACHE = result.duplicate(true)
	return result


static func _load_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var length := file.get_length()
	if length < 1 or length > MAX_CONTRACT_BYTES:
		return PackedByteArray()
	return file.get_buffer(length)


static func _canonical_artifact_sha256(source_bytes: PackedByteArray) -> String:
	var result := CabtJsonTreeScript.canonicalize_artifact_json_bytes(source_bytes, {"max_input_bytes": MAX_CONTRACT_BYTES, "max_output_bytes": MAX_CONTRACT_BYTES})
	return _raw_sha256(result.get("bytes", PackedByteArray())) if bool(result.get("ok", false)) else ""


static func _domain_hash(payload: Dictionary) -> String:
	var result := CabtJsonTreeScript.canonicalize(payload, {"max_output_bytes": MAX_VALUE_BYTES})
	if not bool(result.get("ok", false)):
		return ""
	var bytes: PackedByteArray = ORCHESTRATION_PREFIX_UTF8_HEX.hex_decode()
	bytes.append_array(result.get("bytes", PackedByteArray()))
	return _raw_sha256(bytes)


static func _raw_sha256(source_bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(source_bytes) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _contains_private(value: Variant) -> bool:
	if typeof(value) == TYPE_STRING:
		var text := str(value).to_lower()
		return PRIVATE_KEYS.has(text) or text.contains("private")
	if value is Dictionary:
		for key: Variant in value.keys():
			if typeof(key) != TYPE_STRING or _contains_private(str(key)) or _contains_private(value.get(key)):
				return true
	elif value is Array:
		for child: Variant in value:
			if _contains_private(child):
				return true
	return false


static func _identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).is_empty() or str(value).length() > 128 or str(value).to_lower().contains("private"):
		return false
	const ALLOWED := "abcdefghijklmnopqrstuvwxyz0123456789._-"
	for character: String in str(value):
		if not ALLOWED.contains(character):
			return false
	return str(value)[0] in "abcdefghijklmnopqrstuvwxyz0123456789"


static func _safe_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= -MAX_SAFE_INTEGER and value <= MAX_SAFE_INTEGER


static func _index_list(value: Variant, option_count: int) -> bool:
	if not value is Array or value.size() > 1024:
		return false
	var seen := {}
	for index: Variant in value:
		if typeof(index) != TYPE_INT or index < 0 or index >= option_count or seen.has(index):
			return false
		seen[index] = true
	return true


static func _is_upper_sha256(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	for character: String in str(value):
		if not "0123456789ABCDEF".contains(character):
			return false
	return true


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: Variant in value.keys():
		if typeof(key) != TYPE_STRING or not expected.has(key):
			return false
	return true
