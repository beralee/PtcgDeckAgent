class_name ReviewedAuthorStrategyDevelopmentPolicy
extends "res://scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd"

## Exact-hash, development-only executor for the reviewed Forge packages.
## It reuses the sealed public-frame validation and Base adjudication path,
## while binding package/graph/deck/rule counts from the development gate.
const DevelopmentGateScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd"
)
const ServerCompetitionGateScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/AuthorStrategyServerCompetitionGate.gd"
)


static func create(
	handle: Variant,
	match_id: Variant,
	authority_mode: String = ExecutionGateScript.DEVELOPMENT_MODE
) -> Dictionary:
	if handle == null or not handle.has_method("validate_integrity") or not handle.validate_integrity():
		return _error("package_integrity_invalid")
	if not _identifier(match_id) or str(match_id).length() > 64:
		return _error("invalid_match_identity")
	var pins: Dictionary = handle.to_public_dict()
	var pin_error := _pin_error(pins, authority_mode)
	if not pin_error.is_empty():
		return _error(pin_error)
	var candidate: Dictionary = _candidate_for_pins(pins, authority_mode)
	if candidate.get("runtime_kind") not in ["reviewed_restricted_ir_v1", "reviewed_competitive_policy_v2"]:
		return _error("development_candidate_not_authorized")
	var local_deck: Array = handle.local_deck_snapshot()
	var allowed_uids := {}
	var card_count := 0
	for row_value: Variant in local_deck:
		if not row_value is Dictionary:
			return _error("package_deck_unmapped")
		var row: Dictionary = row_value
		var uid: Variant = row.get("local_card_uid")
		var count: Variant = row.get("count")
		if not _local_uid(uid) or typeof(count) != TYPE_INT or count <= 0 or allowed_uids.has(uid):
			return _error("package_deck_unmapped")
		allowed_uids[uid] = true
		card_count += count
	if card_count != 60 or allowed_uids.size() != int(candidate.get("unique_printing_count", -1)):
		return _error("package_deck_unmapped")
	var documents_result: Dictionary = handle.policy_documents()
	if not bool(documents_result.get("ok", false)):
		return _error(str(documents_result.get("error_code", "package_policy_unsupported")))
	var documents: Dictionary = documents_result.get("documents", {})
	var ir_outcome: Variant = StrategicTraceScript.compile_ir(documents.get("policy/policy_ir.json"))
	var raw_adapter: Variant = documents.get("policy/adapter.json")
	var competitive_policy: Variant = null
	var adapter_outcome: Variant
	if raw_adapter is Dictionary and raw_adapter.get("schema_version") == 2:
		adapter_outcome = CompetitivePolicyV2Script.compile_local_uid(raw_adapter, allowed_uids.keys())
		competitive_policy = adapter_outcome.get("policy") if adapter_outcome is Dictionary else null
	else:
		adapter_outcome = PublicDeckAdapterScript.compile_local_uid(
			raw_adapter, allowed_uids.keys(), pins.get("deck_manifest_sha256")
		)
	if (
		ir_outcome == null
		or not bool(ir_outcome.get("accepted"))
		or ir_outcome.get("ir") == null
		or adapter_outcome == null
		or not bool(adapter_outcome.get("accepted"))
		or (competitive_policy == null and adapter_outcome.get("adapter") == null)
	):
		return _error("package_policy_unsupported")
	var ir_document: Dictionary = StrategicTraceScript.ir_public_dict(ir_outcome.get("ir"))
	var adapter_document: Dictionary = CompetitivePolicyV2Script.policy_public_dict(competitive_policy) \
		if competitive_policy != null else PublicDeckAdapterScript.adapter_public_dict(adapter_outcome.get("adapter"))
	var config_document: Variant = documents.get("policy/config.json")
	var expanded_config := _expand_conditioned_value_config(handle, config_document, pins)
	if not bool(expanded_config.get("ok", false)):
		return _error(str(expanded_config.get("error_code", "package_policy_unsupported")))
	config_document = expanded_config.get("config")
	if (
		not _reviewed_supported_ir(ir_document, candidate)
		or not _reviewed_supported_adapter(adapter_document, candidate)
		or (competitive_policy == null and not _macro_ids_match(ir_document, adapter_document))
		or not _reviewed_supported_config(config_document, pins, candidate)
	):
		return _error("package_policy_unsupported")
	var claim: Dictionary = handle.claim_for_match(str(match_id))
	if not bool(claim.get("ok", false)):
		return _error(str(claim.get("error_code", "package_handle_already_claimed")))
	var policy_profile := {
		"package_id": "%s.%s" % [
			pins.get("package_id"),
			"competitive-policy-v2" if competitive_policy != null else "restricted-inline-v1",
		],
		"package_version": pins.get("package_version"),
		"manifest_canonical_sha256": pins.get("manifest_canonical_sha256"),
		"execution_location": "device_local",
		"learned_model": (
			ConditionedValueScript.PROFILE_ID
			if config_document.get("values", {}).has("turn_program_conditioned_value_model")
			else "none"
		),
		"source": "sealed_author_archive_documents",
	}
	var script: GDScript = load(
		"res://scripts/ai/ptcgdap/runtime/local/ReviewedAuthorStrategyDevelopmentPolicy.gd"
	)
	var policy: Variant = script.new(
		pins,
		ir_document,
		adapter_document,
		config_document,
		allowed_uids,
		str(match_id),
		authority_mode,
		policy_profile,
		_FACTORY_TOKEN,
		competitive_policy
	)
	if policy == null or not policy._is_valid_owner():
		return _error("development_policy_invalid")
	return {"ok": true, "error_code": "", "policy": policy}


func _is_valid_owner() -> bool:
	var candidate: Dictionary = _candidate_for_pins(_pins, _authority_mode)
	return (
		_factory_token == _FACTORY_TOKEN
		and not _match_id.is_empty()
		and _pin_error(_pins, _authority_mode).is_empty()
		and candidate.get("runtime_kind") in ["reviewed_restricted_ir_v1", "reviewed_competitive_policy_v2"]
		and _policy_package_pins.get("source") == "sealed_author_archive_documents"
		and _policy_package_pins.get("learned_model") == _expected_learned_model()
		and _policy_package_pins.get("execution_location") == "device_local"
		and _policy_package_pins.get("manifest_canonical_sha256") == _pins.get("manifest_canonical_sha256")
		and _reviewed_supported_ir(_ir_document, candidate)
		and _reviewed_supported_adapter(_adapter_document, candidate)
		and _reviewed_supported_config(_config_document, _pins, candidate)
		and (_adapter_document.get("schema_version") == 2 or _macro_ids_match(_ir_document, _adapter_document))
		and _allowed_uids.size() == int(candidate.get("unique_printing_count", -1))
	)


func _frame_error(value: Variant) -> String:
	if not value is Dictionary:
		return super._frame_error(value)
	var candidate: Dictionary = _candidate_for_pins(_pins, _authority_mode)
	if (
		candidate.is_empty()
		or value.get("profile_id") != candidate.get("frame_profile_id")
		or value.get("strategy_id") != candidate.get("strategy_id")
	):
		return "invalid_development_frame"
	var normalized: Dictionary = value.duplicate(true)
	normalized["profile_id"] = FRAME_PROFILE_ID
	normalized["strategy_id"] = STRATEGY_ID
	return super._frame_error(normalized)


func audit_snapshot() -> Dictionary:
	var audit: Dictionary = super.audit_snapshot()
	var candidate: Dictionary = _candidate_for_pins(_pins, _authority_mode)
	audit["frame_profile_id"] = candidate.get("frame_profile_id")
	audit["strategy_id"] = candidate.get("strategy_id")
	audit["policy_executor_kind"] = str(candidate.get("runtime_kind", "reviewed_restricted_ir_v1"))
	audit["policy_profile_source"] = "sealed_author_archive_documents"
	audit["production_ready"] = false
	return audit


static func _candidate_for_pins(pins: Dictionary, authority_mode: String) -> Dictionary:
	if authority_mode == ExecutionGateScript.SERVER_COMPETITION_MODE:
		return ServerCompetitionGateScript.candidate_for_pins(pins)
	return DevelopmentGateScript.candidate_for_pins(pins)


static func _reviewed_supported_config(
	value: Variant,
	pins: Dictionary,
	candidate: Dictionary
) -> bool:
	if not value is Dictionary or not _has_exact_keys(
		value, ["config_profile_id", "document_type", "schema_version", "values"]
	):
		return false
	var values: Variant = value.get("values")
	var required := [
		"cabt_exportable", "card_id_domain", "deck_manifest_sha256",
		"platform_scope", "source_deck_id",
	]
	if values is Dictionary and values.has("turn_program_profile_id"):
		required.append_array(TURN_PROGRAM_CONFIG_KEYS)
	if values is Dictionary and values.has("turn_program_semantics_profile_id"):
		required.append_array(TURN_PROGRAM_SEMANTIC_CONFIG_KEYS)
	if values is Dictionary and values.has("turn_program_semantic_guard_profile_id"):
		required.append_array(TURN_PROGRAM_GUARD_CONFIG_KEYS)
	if values is Dictionary and values.has("turn_program_conditioned_value_model"):
		required.append_array(TURN_PROGRAM_CONDITIONED_VALUE_CONFIG_KEYS)
	return (
		value.get("schema_version") == 1
		and value.get("config_profile_id") == "ptcgdap-author-policy-config-v1"
		and value.get("document_type") == "author_policy_config_v1"
		and values is Dictionary
		and _has_exact_keys(values, required)
		and values.get("cabt_exportable") == false
		and values.get("card_id_domain") == CARD_ID_DOMAIN
		and values.get("deck_manifest_sha256") == pins.get("deck_manifest_sha256")
		and values.get("platform_scope") == "windows"
		and values.get("source_deck_id") == candidate.get("source_deck_id")
		and (
			not values.has("turn_program_profile_id")
			or not _turn_program_config_from_values(values).is_empty()
		)
	)


static func _reviewed_supported_ir(value: Dictionary, candidate: Dictionary) -> bool:
	var nodes: Variant = value.get("nodes")
	if (
		value.get("schema_version") != 1
		or value.get("profile_id") != "ptcgdap-restricted-base-graph-ir-p4-wp2-v1"
		or value.get("graph_id") != candidate.get("package_id")
		or value.get("entry_node_id") != "n00"
		or not nodes is Array
		or nodes.size() != SUPPORTED_OPERATORS.size()
	):
		return false
	for index: int in nodes.size():
		var node: Variant = nodes[index]
		if not node is Dictionary:
			return false
		var expected_next: Array = [] if index == nodes.size() - 1 else [str(nodes[index + 1].get("node_id"))]
		if (
			node.get("operator") != SUPPORTED_OPERATORS[index]
			or node.get("owner") != SUPPORTED_OWNERS[index]
			or node.get("next_node_ids") != expected_next
		):
			return false
	return nodes[5].get("config", {}).get("strategy") == "same_window_first_min"


static func _reviewed_supported_adapter(value: Dictionary, candidate: Dictionary) -> bool:
	var rules: Variant = value.get("rules")
	if candidate.get("runtime_kind") == "reviewed_competitive_policy_v2":
		return (
			value.get("schema_version") == 2
			and value.get("adapter_id") == candidate.get("package_id")
			and typeof(value.get("adapter_version")) == TYPE_INT
			and int(value.get("adapter_version")) >= 2
			and value.get("goals") is Array
			and not value.get("goals").is_empty()
			and value.get("count_rules") is Array
			and rules is Array
			and rules.size() == int(candidate.get("adapter_rule_count", -1))
			and rules.size() >= 1
			and rules.size() <= 512
		)
	return (
		value.get("schema_version") == 1
		and value.get("adapter_id") == candidate.get("package_id")
		and value.get("adapter_version") == 1
		and value.get("card_id_domain") == CARD_ID_DOMAIN
		and rules is Array
		and rules.size() == int(candidate.get("adapter_rule_count", -1))
		and rules.size() >= 1
		and rules.size() <= 128
	)


static func _macro_ids_match(ir_document: Dictionary, adapter_document: Dictionary) -> bool:
	var nodes: Array = ir_document.get("nodes", [])
	var rules: Array = adapter_document.get("rules", [])
	if nodes.size() != 7:
		return false
	var expected: Array = []
	for rule_value: Variant in rules:
		if not rule_value is Dictionary or typeof(rule_value.get("rule_id")) != TYPE_STRING:
			return false
		expected.append(rule_value.get("rule_id"))
	return nodes[2].get("config", {}).get("macro_ids") == expected
