class_name StrategicTraceV2ContractCore
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const PublicObservationFirewallScript = preload(
	"res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd"
)
const StrategicContextScript = preload(
	"res://scripts/ai/ptcgdap/public/StrategicContextV18.gd"
)

const DEFAULT_ROOT := "res://contracts/ptcgdap"
const PROFILE_ID := "ptcgdap-strategic-trace-v2-p4-wp2-v1"
const IR_PROFILE_ID := "ptcgdap-restricted-base-graph-ir-p4-wp2-v1"
const EXPECTED_BUNDLE_SHA256 := "ADDD4CB48BD10FA0478854124D8E63AEE42B898C0EB81692BA35F8D7F90414C4"
const EXPECTED_PARENT_BUNDLE_SHA256 := "AACFA7E2E7F914180A2B7A5C4D92D6514ACC5F4622FC95B57DC225673893F98F"
const EXPECTED_SOURCE_LOCK_SHA256 := "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
const EXPECTED_ARTIFACTS := {
	"schema": {
		"path": "contracts/ptcgdap/strategic_trace_v2.schema.json",
		"canonical_sha256": "9E455A3D90121265046BE7A48DD182E15B197D0D0930AE7FC1254D98637870F5",
	},
	"profile": {
		"path": "contracts/ptcgdap/strategic_trace_v2_profile.json",
		"canonical_sha256": "5F98592945C60DE94896960C240F5D19002154F2FBEC6A82F553D4ED9EF1A00E",
	},
	"vectors": {
		"path": "contracts/ptcgdap/strategic_trace_v2_conformance_vectors.json",
		"canonical_sha256": "5270260C817BE20A749A0404A2413CDB90F5C7AF871BD1DFCC64ECF85DA4E7B1",
	},
}
const IR_PREFIX_UTF8_HEX := "5054434744415000524553545249435445445F424153455F47524150485F49525F563100"
const TRACE_PREFIX_UTF8_HEX := "50544347444150005354524154454749435F54524143455F563200"
const MAX_CONTRACT_BYTES := 2 * 1024 * 1024
const MAX_VALUE_BYTES := 1024 * 1024
const MAX_SAFE_INTEGER := 9007199254740991
const BASE_OPERATORS := [
	"legality_guard",
	"mandatory_terminal_guard",
	"hard_tier_filter",
	"base_veto",
	"deterministic_fallback",
	"emit_decision",
]
const ADAPTER_OPERATORS := ["goal_proposal", "macro_proposal", "tiebreak_score"]
const CAPABILITIES := [
	"public_context",
	"current_window",
	"deterministic_fallback",
	"strategic_trace_v2",
]
const ADAPTER_REASONS := {
	"goal_proposal": "public_goal_proposal",
	"macro_proposal": "public_macro_proposal",
	"tiebreak_score": "public_tiebreak_proposal",
}
const DOCUMENT_KEYS := [
	"schema_version",
	"profile_id",
	"graph_id",
	"entry_node_id",
	"required_capabilities",
	"nodes",
]
const NODE_KEYS := ["node_id", "operator", "owner", "config", "next_node_ids"]
const AUDIT_KEYS := [
	"legal_indexes",
	"strategic_indexes",
	"mandatory_indexes",
	"terminal_indexes",
	"base_hard_tiers",
	"base_vetoed_indexes",
	"adapter_proposals",
	"fallback_reason",
]

static var _IR_TOKEN: RefCounted = RefCounted.new()
static var _TRACE_TOKEN: RefCounted = RefCounted.new()
static var _IR_REGISTRY: Dictionary = {}
static var _TRACE_REGISTRY: Dictionary = {}
static var _DEFAULT_CONTRACT_CACHE: Dictionary = {}


class BuildResult extends RefCounted:
	var accepted := false
	var error_code := "contract_error"
	var ir: Variant = null
	var trace: Variant = null

	func _init(
		accepted_value: bool,
		error_value: String,
		ir_value: Variant = null,
		trace_value: Variant = null,
	) -> void:
		accepted = accepted_value
		error_code = error_value
		ir = ir_value
		trace = trace_value


class RestrictedIrValue extends RefCounted:
	var _document: Variant = {}
	var _snapshot: Variant = {}
	var _factory_token: Variant = null

	var ir_hash: String:
		get:
			return str(_snapshot.get("ir_hash", "")) if _snapshot is Dictionary else ""

	var graph_id: String:
		get:
			return str(_snapshot.get("graph_id", "")) if _snapshot is Dictionary else ""

	func _init(
		document_value: Dictionary = {},
		snapshot_value: Dictionary = {},
		token_value: Variant = null,
	) -> void:
		_document = document_value.duplicate(true)
		_snapshot = snapshot_value.duplicate(true)
		_factory_token = token_value

	func validate_integrity() -> bool:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/public/StrategicTraceV2.gd")
		return bool(owner.call("validate_ir", self))

	func to_public_dict() -> Dictionary:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/public/StrategicTraceV2.gd")
		return owner.call("ir_public_dict", self)


class StrategicTraceValue extends RefCounted:
	var _snapshot: Variant = {}
	var _audit: Variant = {}
	var _factory_token: Variant = null
	var _context_binding: Variant = null
	var _decision_binding: Variant = null
	var _ir_binding: Variant = null

	var trace_hash: String:
		get:
			return str(_snapshot.get("trace_hash", "")) if _snapshot is Dictionary else ""

	func _init(
		snapshot_value: Dictionary = {},
		audit_value: Dictionary = {},
		context_value: Variant = null,
		decision_value: Variant = null,
		ir_value: Variant = null,
		token_value: Variant = null,
	) -> void:
		_snapshot = snapshot_value.duplicate(true)
		_audit = audit_value.duplicate(true)
		_context_binding = context_value
		_decision_binding = decision_value
		_ir_binding = ir_value
		_factory_token = token_value

	func validate_integrity(context_value: Variant, decision_value: Variant, ir_value: Variant) -> bool:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/public/StrategicTraceV2.gd")
		return bool(owner.call("validate_trace", self, context_value, decision_value, ir_value))

	func to_public_dict() -> Dictionary:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/public/StrategicTraceV2.gd")
		return owner.call("trace_public_dict", self)


static func compile_ir(
	document: Variant,
	contract_root: Variant = DEFAULT_ROOT,
) -> BuildResult:
	if typeof(contract_root) != TYPE_STRING or not _load_contracts(str(contract_root)).get("ok", false):
		return BuildResult.new(false, "contract_error")
	var error := _document_error(document)
	if not error.is_empty():
		return BuildResult.new(false, error)
	var snapshot := _compiled_payload(document)
	if snapshot.is_empty():
		return BuildResult.new(false, "ir_integrity_invalid")
	var value := RestrictedIrValue.new(document, snapshot, _IR_TOKEN)
	_register_ir(value, document, snapshot)
	if not validate_ir(value):
		return BuildResult.new(false, "ir_integrity_invalid")
	return BuildResult.new(true, "", value)


static func build_trace(
	context: Variant,
	decision: Variant,
	ir: Variant,
	trace_id: Variant,
	audit: Variant,
	contract_root: Variant = DEFAULT_ROOT,
) -> BuildResult:
	if typeof(contract_root) != TYPE_STRING or not _load_contracts(str(contract_root)).get("ok", false):
		return BuildResult.new(false, "contract_error")
	if not StrategicContextScript.validate_context(context):
		return BuildResult.new(false, "invalid_context")
	if not _decision_bound_to_context(context, decision):
		return BuildResult.new(false, "invalid_decision")
	if not validate_ir(ir):
		return BuildResult.new(false, "ir_integrity_invalid")
	if not _identifier(trace_id):
		return BuildResult.new(false, "invalid_trace_identity")
	if not _trace_audit_valid(context, decision, ir, audit):
		return BuildResult.new(false, "invalid_trace_audit")
	var payload := _trace_payload(context, decision, ir, str(trace_id), audit)
	if payload.is_empty():
		return BuildResult.new(false, "trace_integrity_invalid")
	var value := StrategicTraceValue.new(payload, audit, context, decision, ir, _TRACE_TOKEN)
	_register_trace(value, payload, audit, context, decision, ir)
	if not validate_trace(value, context, decision, ir):
		return BuildResult.new(false, "trace_integrity_invalid")
	return BuildResult.new(true, "", null, value)


static func validate_ir(value: Variant) -> bool:
	var entry := _registry_entry(_IR_REGISTRY, value)
	if (
		not value is RestrictedIrValue
		or entry.is_empty()
		or value.get("_factory_token") != _IR_TOKEN
		or not value.get("_document") is Dictionary
		or not value.get("_snapshot") is Dictionary
		or value.get("_document") != entry.get("document")
		or value.get("_snapshot") != entry.get("snapshot")
		or not _document_error(value.get("_document")).is_empty()
	):
		return false
	return value.get("_snapshot") == _compiled_payload(value.get("_document"))


static func ir_public_dict(value: Variant) -> Dictionary:
	return value.get("_snapshot").duplicate(true) if validate_ir(value) else {}


static func validate_trace(
	value: Variant,
	context: Variant,
	decision: Variant,
	ir: Variant,
) -> bool:
	var entry := _registry_entry(_TRACE_REGISTRY, value)
	if (
		not value is StrategicTraceValue
		or entry.is_empty()
		or value.get("_factory_token") != _TRACE_TOKEN
		or context != entry.get("context")
		or decision != entry.get("decision")
		or ir != entry.get("ir")
		or value.get("_context_binding") != context
		or value.get("_decision_binding") != decision
		or value.get("_ir_binding") != ir
		or not value.get("_snapshot") is Dictionary
		or not value.get("_audit") is Dictionary
		or value.get("_snapshot") != entry.get("snapshot")
		or value.get("_audit") != entry.get("audit")
		or not _decision_bound_to_context(context, decision)
		or not validate_ir(ir)
		or not _trace_audit_valid(context, decision, ir, value.get("_audit"))
	):
		return false
	var trace_id: Variant = value.get("_snapshot").get("trace_id")
	return _identifier(trace_id) and value.get("_snapshot") == _trace_payload(
		context,
		decision,
		ir,
		str(trace_id),
		value.get("_audit"),
	)


static func trace_public_dict(value: Variant) -> Dictionary:
	if not value is StrategicTraceValue:
		return {}
	return (
		value.get("_snapshot").duplicate(true)
		if validate_trace(
			value,
			value.get("_context_binding"),
			value.get("_decision_binding"),
			value.get("_ir_binding"),
		)
		else {}
	)


static func _document_error(document: Variant) -> String:
	if not document is Dictionary or not _has_exact_keys(document, DOCUMENT_KEYS):
		return "invalid_ir_document"
	if (
		typeof(document.get("schema_version")) != TYPE_INT
		or document.get("schema_version") != 1
		or document.get("profile_id") != IR_PROFILE_ID
		or not _identifier(document.get("graph_id"))
		or not _identifier(document.get("entry_node_id"))
	):
		return "invalid_ir_document"
	var capabilities: Variant = document.get("required_capabilities")
	if not capabilities is Array:
		return "invalid_ir_document"
	for capability: Variant in capabilities:
		if typeof(capability) != TYPE_STRING:
			return "invalid_ir_document"
	if capabilities != CAPABILITIES:
		return "unsupported_capability"
	var nodes: Variant = document.get("nodes")
	if not nodes is Array or nodes.size() > 64:
		return "invalid_ir_document"
	for node_value: Variant in nodes:
		if not node_value is Dictionary or not _has_exact_keys(node_value, NODE_KEYS):
			return "invalid_ir_document"
		if not _identifier(node_value.get("node_id")):
			return "invalid_ir_document"
		var next_ids: Variant = node_value.get("next_node_ids")
		if not next_ids is Array or next_ids.size() > 1:
			return "invalid_ir_document"
		for next_id: Variant in next_ids:
			if not _identifier(next_id):
				return "invalid_ir_document"
		var operator: Variant = node_value.get("operator")
		if typeof(operator) != TYPE_STRING:
			return "invalid_ir_document"
		if not operator in BASE_OPERATORS and not operator in ADAPTER_OPERATORS:
			return "unsupported_ir_operator"
		var expected_owner := "base" if operator in BASE_OPERATORS else "adapter"
		if typeof(node_value.get("owner")) != TYPE_STRING or node_value.get("owner") != expected_owner:
			return "invalid_ir_owner"
		if not _config_valid(str(operator), node_value.get("config")):
			return "invalid_ir_config"
	var base_sequence: Array = []
	for node_value: Variant in nodes:
		if node_value.get("operator") in BASE_OPERATORS:
			base_sequence.append(node_value.get("operator"))
	if base_sequence != BASE_OPERATORS:
		return "missing_base_authority"
	var identifiers: Array = []
	for node_value: Variant in nodes:
		if identifiers.has(node_value.get("node_id")):
			return "invalid_ir_topology"
		identifiers.append(node_value.get("node_id"))
	if identifiers.is_empty() or document.get("entry_node_id") != identifiers[0]:
		return "invalid_ir_topology"
	for index: int in nodes.size():
		var expected_next: Array = [] if index + 1 == nodes.size() else [identifiers[index + 1]]
		if nodes[index].get("next_node_ids") != expected_next:
			return "invalid_ir_topology"
	var mandatory_index := _operator_index(nodes, "mandatory_terminal_guard")
	var tier_index := _operator_index(nodes, "hard_tier_filter")
	var veto_index := _operator_index(nodes, "base_veto")
	for index: int in nodes.size():
		var operator: Variant = nodes[index].get("operator")
		if operator in ["goal_proposal", "macro_proposal"] and not (mandatory_index < index and index < tier_index):
			return "invalid_ir_topology"
		if operator == "tiebreak_score" and not (tier_index < index and index < veto_index):
			return "invalid_ir_topology"
	var canonical := CabtJsonTreeScript.canonicalize(document, {"max_output_bytes": MAX_VALUE_BYTES})
	return "" if bool(canonical.get("ok", false)) else "invalid_ir_document"


static func _config_valid(operator: String, config: Variant) -> bool:
	if not config is Dictionary:
		return false
	match operator:
		"legality_guard":
			return _has_exact_keys(config, ["frontier"]) and typeof(config.get("frontier")) == TYPE_STRING and config.get("frontier") == "current_window"
		"mandatory_terminal_guard":
			return _has_exact_keys(config, ["mandatory_precedence", "terminal_precedence"]) and typeof(config.get("mandatory_precedence")) == TYPE_BOOL and config.get("mandatory_precedence") == true and typeof(config.get("terminal_precedence")) == TYPE_BOOL and config.get("terminal_precedence") == true
		"hard_tier_filter":
			return _has_exact_keys(config, ["same_tier_only"]) and typeof(config.get("same_tier_only")) == TYPE_BOOL and config.get("same_tier_only") == true
		"base_veto":
			return _has_exact_keys(config, ["enabled"]) and typeof(config.get("enabled")) == TYPE_BOOL and config.get("enabled") == true
		"deterministic_fallback":
			return _has_exact_keys(config, ["strategy"]) and typeof(config.get("strategy")) == TYPE_STRING and config.get("strategy") == "same_window_first_min"
		"emit_decision":
			return config.is_empty()
		"goal_proposal":
			return _has_exact_keys(config, ["goal_ids"]) and _identifier_list(config.get("goal_ids"))
		"macro_proposal":
			return _has_exact_keys(config, ["macro_ids"]) and _identifier_list(config.get("macro_ids"))
		"tiebreak_score":
			return _has_exact_keys(config, ["feature_ids", "weight_scale"]) and _identifier_list(config.get("feature_ids")) and typeof(config.get("weight_scale")) == TYPE_INT and config.get("weight_scale") == 1000000
	return false


static func _compiled_payload(document: Dictionary) -> Dictionary:
	var payload := document.duplicate(true)
	payload["authority"] = "restricted_base_graph_ir_audit"
	payload["authoritative"] = false
	var digest := _domain_hash(IR_PREFIX_UTF8_HEX, payload)
	if digest.is_empty():
		return {}
	payload["ir_hash"] = digest
	return payload


static func _trace_audit_valid(
	context: Variant,
	decision: Variant,
	ir: Variant,
	audit: Variant,
) -> bool:
	if not audit is Dictionary or not _has_exact_keys(audit, AUDIT_KEYS):
		return false
	var context_value := StrategicContextScript.context_public_dict(context)
	var decision_value := StrategicContextScript.decision_public_dict(decision)
	var ir_value := ir_public_dict(ir)
	if context_value.is_empty() or decision_value.is_empty() or ir_value.is_empty():
		return false
	for key: String in ["legal_indexes", "strategic_indexes", "mandatory_indexes", "terminal_indexes", "base_vetoed_indexes"]:
		if not _index_list(audit.get(key)):
			return false
	var legal: Array = audit.get("legal_indexes")
	var strategic: Array = audit.get("strategic_indexes")
	var mandatory: Array = audit.get("mandatory_indexes")
	var terminal: Array = audit.get("terminal_indexes")
	var vetoed: Array = audit.get("base_vetoed_indexes")
	var selected: Variant = decision_value.get("selected_indexes")
	if not selected is Array or legal != range(context_value.get("select_semantics", {}).get("options", []).size()):
		return false
	if not _subset(strategic, legal) or not _subset(selected, strategic):
		return false
	var forced: Array = terminal if not terminal.is_empty() else mandatory
	if not _subset(forced, selected):
		return false
	if not _subset(vetoed, strategic) or _intersects(selected, vetoed):
		return false
	var tiers: Variant = audit.get("base_hard_tiers")
	if not tiers is Array or tiers.size() != strategic.size():
		return false
	var tier_by_index := {}
	for position: int in tiers.size():
		var entry: Variant = tiers[position]
		if not entry is Dictionary or not _has_exact_keys(entry, ["index", "tier"]) or entry.get("index") != strategic[position]:
			return false
		var tier: Variant = entry.get("tier")
		if not tier is Array or tier.is_empty() or tier.size() > 8:
			return false
		for component: Variant in tier:
			if not _safe_int(component):
				return false
		tier_by_index[entry.get("index")] = tier.duplicate(true)
	if not selected.is_empty() and forced.is_empty():
		if tier_by_index.is_empty():
			return false
		var best: Array = tier_by_index.values()[0]
		for tier_value: Variant in tier_by_index.values():
			if _tier_less(tier_value, best):
				best = tier_value
		for selected_index: Variant in selected:
			if not tier_by_index.has(selected_index) or tier_by_index.get(selected_index) != best:
				return false
	var proposals: Variant = audit.get("adapter_proposals")
	if not proposals is Array or proposals.size() > 64:
		return false
	for proposal: Variant in proposals:
		if not proposal is Dictionary or not _has_exact_keys(proposal, ["operator", "indexes", "reason_code"]):
			return false
		var operator: Variant = proposal.get("operator")
		if typeof(operator) != TYPE_STRING or not ADAPTER_REASONS.has(operator) or proposal.get("reason_code") != ADAPTER_REASONS.get(operator):
			return false
		if not _index_list(proposal.get("indexes")) or not _subset(proposal.get("indexes"), strategic):
			return false
	var fallback_reason: Variant = audit.get("fallback_reason")
	if typeof(fallback_reason) != TYPE_STRING or str(fallback_reason).length() > 128:
		return false
	var expected_fallback := "" if decision_value.get("fallback_tier") == "none" else str(decision_value.get("reason_code"))
	if fallback_reason != expected_fallback or ir_value.get("required_capabilities") != CAPABILITIES:
		return false
	return bool(CabtJsonTreeScript.canonicalize(audit, {"max_output_bytes": MAX_VALUE_BYTES}).get("ok", false))


static func _trace_payload(
	context: Variant,
	decision: Variant,
	ir: Variant,
	trace_id: String,
	audit: Dictionary,
) -> Dictionary:
	var context_value := StrategicContextScript.context_public_dict(context)
	var decision_value := StrategicContextScript.decision_public_dict(decision)
	var ir_value := ir_public_dict(ir)
	if context_value.is_empty() or decision_value.is_empty() or ir_value.is_empty():
		return {}
	var option_fingerprints: Array = []
	for option_value: Variant in context_value.get("select_semantics", {}).get("options", []):
		option_fingerprints.append(option_value.get("fingerprint"))
	var owner_audit: Array = []
	for node_value: Variant in ir_value.get("nodes", []):
		owner_audit.append({"node_id": node_value.get("node_id"), "operator": node_value.get("operator"), "owner": node_value.get("owner")})
	var payload := {
		"schema_version": 2,
		"profile_id": PROFILE_ID,
		"trace_id": trace_id,
		"identities": {"scene_id": decision_value.get("scene_id"), "decision_id": decision_value.get("decision_id"), "determinism_key": decision_value.get("determinism_key")},
		"source": {"context_hash": context_value.get("context_hash"), "decision_audit_id": decision_value.get("audit_id"), "policy_hash": decision_value.get("policy_hash"), "window_id": decision_value.get("window_id"), "public_observation_hash": decision_value.get("public_observation_hash")},
		"ir": {"graph_id": ir_value.get("graph_id"), "ir_hash": ir_value.get("ir_hash"), "required_capabilities": ir_value.get("required_capabilities").duplicate(true)},
		"frontier": {"option_fingerprints": option_fingerprints, "legal_indexes": audit.get("legal_indexes").duplicate(true), "strategic_indexes": audit.get("strategic_indexes").duplicate(true), "mandatory_indexes": audit.get("mandatory_indexes").duplicate(true), "terminal_indexes": audit.get("terminal_indexes").duplicate(true), "base_hard_tiers": audit.get("base_hard_tiers").duplicate(true), "base_vetoed_indexes": audit.get("base_vetoed_indexes").duplicate(true)},
		"adapter_proposals": audit.get("adapter_proposals").duplicate(true),
		"owner_audit": owner_audit,
		"decision": {"selected_indexes": decision_value.get("selected_indexes").duplicate(true), "owner_layer": decision_value.get("owner_layer"), "reason_code": decision_value.get("reason_code"), "fallback_tier": decision_value.get("fallback_tier")},
		"fallback_reason": audit.get("fallback_reason"),
		"public_only": true,
		"authority": "strategic_trace_v2_public_audit",
		"authoritative": false,
	}
	var digest := _domain_hash(TRACE_PREFIX_UTF8_HEX, payload)
	if digest.is_empty():
		return {}
	payload["trace_hash"] = digest
	return payload


static func _decision_bound_to_context(context: Variant, decision: Variant) -> bool:
	if not StrategicContextScript.validate_context(context) or typeof(decision) != TYPE_OBJECT or decision == null:
		return false
	var window: Variant = decision.get("_window_binding")
	var resolution: Variant = decision.get("_resolution_binding")
	return decision.get("_context_binding") == context and StrategicContextScript.validate_decision(decision, context, window, resolution)


static func _register_ir(value: RefCounted, document: Dictionary, snapshot: Dictionary) -> void:
	_prune_registry(_IR_REGISTRY)
	_IR_REGISTRY[value.get_instance_id()] = {"weak": weakref(value), "document": document.duplicate(true), "snapshot": snapshot.duplicate(true)}


static func _register_trace(value: RefCounted, snapshot: Dictionary, audit: Dictionary, context: Variant, decision: Variant, ir: Variant) -> void:
	_prune_registry(_TRACE_REGISTRY)
	_TRACE_REGISTRY[value.get_instance_id()] = {"weak": weakref(value), "snapshot": snapshot.duplicate(true), "audit": audit.duplicate(true), "context": context, "decision": decision, "ir": ir}


static func _registry_entry(registry: Dictionary, value: Variant) -> Dictionary:
	if typeof(value) != TYPE_OBJECT or value == null:
		return {}
	var instance_id: int = value.get_instance_id()
	var entry: Variant = registry.get(instance_id)
	if not entry is Dictionary:
		return {}
	var weak_value: Variant = entry.get("weak")
	if typeof(weak_value) != TYPE_OBJECT or weak_value == null or weak_value.get_ref() != value:
		registry.erase(instance_id)
		return {}
	return entry


static func _prune_registry(registry: Dictionary) -> void:
	for instance_id: Variant in registry.keys():
		var entry: Variant = registry.get(instance_id)
		var weak_value: Variant = entry.get("weak") if entry is Dictionary else null
		if typeof(weak_value) != TYPE_OBJECT or weak_value == null or weak_value.get_ref() == null:
			registry.erase(instance_id)


static func _load_contracts(root_path: String) -> Dictionary:
	var root := root_path.trim_suffix("/")
	if root.is_empty():
		return {"ok": false}
	if root == DEFAULT_ROOT and bool(_DEFAULT_CONTRACT_CACHE.get("ok", false)):
		return _DEFAULT_CONTRACT_CACHE.duplicate(true)
	var bundle_bytes := _load_bytes("%s/strategic_trace_v2_bundle.json" % root)
	if bundle_bytes.is_empty() or _canonical_artifact_sha256(bundle_bytes) != EXPECTED_BUNDLE_SHA256:
		return {"ok": false}
	var parsed := PublicObservationFirewallScript._parse_contract_json_bytes(bundle_bytes)
	var bundle: Variant = parsed.get("value") if bool(parsed.get("ok", false)) else null
	if not bundle is Dictionary or not _has_exact_keys(bundle, ["schema_version", "bundle_id", "profile_id", "ir_profile_id", "parent_strategic_context_bundle_canonical_sha256", "source_lock_canonical_sha256", "base_graph_v1_8_source_raw_sha256", "base_graph_v1_8_contract_raw_sha256", "artifacts"]):
		return {"ok": false}
	if bundle.get("schema_version") != 1 or bundle.get("bundle_id") != PROFILE_ID or bundle.get("profile_id") != PROFILE_ID or bundle.get("ir_profile_id") != IR_PROFILE_ID or bundle.get("parent_strategic_context_bundle_canonical_sha256") != EXPECTED_PARENT_BUNDLE_SHA256 or bundle.get("source_lock_canonical_sha256") != EXPECTED_SOURCE_LOCK_SHA256:
		return {"ok": false}
	var artifacts: Variant = bundle.get("artifacts")
	if not artifacts is Array or artifacts.size() != 3:
		return {"ok": false}
	var seen := {}
	var profile: Variant = null
	for entry: Variant in artifacts:
		if not entry is Dictionary or not _has_exact_keys(entry, ["id", "path", "canonical_sha256"]):
			return {"ok": false}
		var artifact_id: Variant = entry.get("id")
		if typeof(artifact_id) != TYPE_STRING or seen.has(artifact_id) or not EXPECTED_ARTIFACTS.has(artifact_id):
			return {"ok": false}
		var expected: Dictionary = EXPECTED_ARTIFACTS.get(artifact_id)
		if entry.get("path") != expected.get("path") or entry.get("canonical_sha256") != expected.get("canonical_sha256"):
			return {"ok": false}
		var bytes := _load_bytes("%s/%s" % [root, str(expected.get("path")).get_file()])
		if bytes.is_empty() or _canonical_artifact_sha256(bytes) != expected.get("canonical_sha256"):
			return {"ok": false}
		var document_result := PublicObservationFirewallScript._parse_contract_json_bytes(bytes)
		if not bool(document_result.get("ok", false)):
			return {"ok": false}
		if artifact_id == "profile":
			profile = document_result.get("value")
		seen[artifact_id] = true
	if seen.size() != 3 or not profile is Dictionary:
		return {"ok": false}
	if profile.get("profile_id") != PROFILE_ID or profile.get("ir_profile_id") != IR_PROFILE_ID or profile.get("ir_contract", {}).get("base_operators_in_required_order") != BASE_OPERATORS or profile.get("ir_contract", {}).get("adapter_operators") != ADAPTER_OPERATORS or profile.get("ir_contract", {}).get("required_capabilities") != CAPABILITIES or profile.get("ir_contract", {}).get("adapter_reason_codes") != ADAPTER_REASONS.values() or profile.get("ir_contract", {}).get("private_identifier_tokens_denied") != ["PRIVATE"] or profile.get("hash_contract", {}).get("ir_prefix_utf8_hex") != IR_PREFIX_UTF8_HEX or profile.get("hash_contract", {}).get("trace_prefix_utf8_hex") != TRACE_PREFIX_UTF8_HEX or profile.get("scope", {}).get("ir_executor") != false or profile.get("scope", {}).get("live_owner") != false:
		return {"ok": false}
	var result := {"ok": true, "profile": profile.duplicate(true)}
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
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(source_bytes, {"max_input_bytes": MAX_CONTRACT_BYTES, "max_output_bytes": MAX_CONTRACT_BYTES})
	return _raw_sha256(canonical.get("bytes", PackedByteArray())) if bool(canonical.get("ok", false)) else ""


static func _domain_hash(prefix_hex: String, payload: Dictionary) -> String:
	var canonical := CabtJsonTreeScript.canonicalize(payload, {"max_output_bytes": MAX_VALUE_BYTES})
	if not bool(canonical.get("ok", false)):
		return ""
	var bytes: PackedByteArray = prefix_hex.hex_decode()
	bytes.append_array(canonical.get("bytes", PackedByteArray()))
	return _raw_sha256(bytes)


static func _raw_sha256(source_bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(source_bytes) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).is_empty() or str(value).length() > 128 or str(value).contains("PRIVATE"):
		return false
	const ALLOWED := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._:-"
	for character: String in str(value):
		if not ALLOWED.contains(character):
			return false
	return true


static func _identifier_list(value: Variant) -> bool:
	if not value is Array or value.is_empty() or value.size() > 64:
		return false
	var seen := {}
	for child: Variant in value:
		if not _identifier(child) or seen.has(child):
			return false
		seen[child] = true
	return true


static func _safe_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= -MAX_SAFE_INTEGER and value <= MAX_SAFE_INTEGER


static func _index_list(value: Variant) -> bool:
	if not value is Array or value.size() > 1024:
		return false
	var seen := {}
	for child: Variant in value:
		if not _safe_int(child) or child < 0 or seen.has(child):
			return false
		seen[child] = true
	return true


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: Variant in value.keys():
		if typeof(key) != TYPE_STRING or not expected.has(key):
			return false
	return true


static func _operator_index(nodes: Array, operator: String) -> int:
	for index: int in nodes.size():
		if nodes[index].get("operator") == operator:
			return index
	return -1


static func _subset(values: Array, parent: Array) -> bool:
	for value: Variant in values:
		if not parent.has(value):
			return false
	return true


static func _intersects(left: Array, right: Array) -> bool:
	for value: Variant in left:
		if right.has(value):
			return true
	return false


static func _tier_less(left: Array, right: Array) -> bool:
	var count := mini(left.size(), right.size())
	for index: int in count:
		if left[index] < right[index]:
			return true
		if left[index] > right[index]:
			return false
	return left.size() < right.size()
