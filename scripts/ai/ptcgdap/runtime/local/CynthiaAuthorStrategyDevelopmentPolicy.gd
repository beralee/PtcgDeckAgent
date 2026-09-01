class_name CynthiaAuthorStrategyDevelopmentPolicy
extends "res://scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd"

const CynthiaManifestScript = preload("res://scripts/ai/ptcgdap/runtime/local/CynthiaPolicyPackageManifest.gd")
const CYNTHIA_FRAME_PROFILE_ID := "ptcgdap-cynthia-garchomp-package-development-frame-v1"
const CYNTHIA_STRATEGY_ID := "ptcgdap.cynthia-garchomp.18.0.package-local-v1"
const CYNTHIA_PACKAGE_ID := "ptcgdap.cynthia-garchomp-800018543.windows-local"
const CYNTHIA_POLICY_PACKAGE_ID := "ptcgdap.cynthia-garchomp-800018543.windows-local.policy"
const CYNTHIA_SOURCE_DECK_ID := 800018543
const CYNTHIA_UNIQUE_PRINTING_COUNT := 26
const CYNTHIA_ADAPTER_RULE_COUNT := 12


static func create(
	handle: Variant,
	match_id: Variant,
	authority_mode: String = ExecutionGateScript.DEVELOPMENT_MODE
) -> Dictionary:
	if handle == null or not handle.has_method("validate_integrity") or not handle.validate_integrity():
		return _error("package_integrity_invalid")
	var policy_package: Dictionary = CynthiaManifestScript.load_and_verify(handle)
	if not bool(policy_package.get("accepted", false)):
		return _error(str(policy_package.get("error_code", "policy_package_integrity_invalid")))
	if not _identifier(match_id) or str(match_id).length() > 64:
		return _error("invalid_match_identity")
	var pins: Dictionary = handle.to_public_dict()
	var pin_error := _pin_error(pins, authority_mode)
	if not pin_error.is_empty():
		return _error(pin_error)
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
	if card_count != 60 or allowed_uids.size() != CYNTHIA_UNIQUE_PRINTING_COUNT:
		return _error("package_deck_unmapped")
	var documents_result: Dictionary = handle.policy_documents()
	if not bool(documents_result.get("ok", false)):
		return _error(str(documents_result.get("error_code", "package_policy_unsupported")))
	var documents: Dictionary = documents_result.get("documents", {})
	var ir_outcome: Variant = StrategicTraceScript.compile_ir(documents.get("policy/policy_ir.json"))
	var adapter_outcome: Variant = PublicDeckAdapterScript.compile_local_uid(
		documents.get("policy/adapter.json"), allowed_uids.keys(), pins.get("deck_manifest_sha256")
	)
	if (
		ir_outcome == null
		or not bool(ir_outcome.get("accepted"))
		or ir_outcome.get("ir") == null
		or adapter_outcome == null
		or not bool(adapter_outcome.get("accepted"))
		or adapter_outcome.get("adapter") == null
	):
		return _error("package_policy_unsupported")
	var ir_document: Dictionary = StrategicTraceScript.ir_public_dict(ir_outcome.get("ir"))
	var adapter_document: Dictionary = PublicDeckAdapterScript.adapter_public_dict(adapter_outcome.get("adapter"))
	if not _cynthia_supported_ir(ir_document) or not _cynthia_supported_adapter(adapter_document):
		return _error("package_policy_unsupported")
	var config_document: Variant = documents.get("policy/config.json")
	if not _cynthia_supported_config(config_document, pins):
		return _error("package_policy_unsupported")
	var claim: Dictionary = handle.claim_for_match(str(match_id))
	if not bool(claim.get("ok", false)):
		return _error(str(claim.get("error_code", "package_handle_already_claimed")))
	var script: GDScript = load(
		"res://scripts/ai/ptcgdap/runtime/local/CynthiaAuthorStrategyDevelopmentPolicy.gd"
	)
	var policy: Variant = script.new(
		pins,
		ir_document,
		adapter_document,
		config_document,
		allowed_uids,
		str(match_id),
		authority_mode,
		policy_package,
		_FACTORY_TOKEN
	)
	if policy == null or not policy._is_valid_owner():
		return _error("development_policy_invalid")
	return {"ok":true, "error_code":"", "policy":policy}


func _is_valid_owner() -> bool:
	return (
		_factory_token == _FACTORY_TOKEN
		and not _match_id.is_empty()
		and _pin_error(_pins, _authority_mode).is_empty()
		and _pins.get("package_id") == CYNTHIA_PACKAGE_ID
		and _policy_package_pins.get("package_id") == CYNTHIA_POLICY_PACKAGE_ID
		and _policy_package_pins.get("learned_model") == "none"
		and _policy_package_pins.get("execution_location") == "device_local"
		and _is_sha(_policy_package_pins.get("manifest_canonical_sha256"))
		and _cynthia_supported_ir(_ir_document)
		and _cynthia_supported_adapter(_adapter_document)
		and _allowed_uids.size() == CYNTHIA_UNIQUE_PRINTING_COUNT
	)


func _frame_error(value: Variant) -> String:
	if not value is Dictionary:
		return super._frame_error(value)
	if (
		value.get("profile_id") != CYNTHIA_FRAME_PROFILE_ID
		or value.get("strategy_id") != CYNTHIA_STRATEGY_ID
	):
		return "invalid_development_frame"
	var normalized: Dictionary = value.duplicate(true)
	normalized["profile_id"] = FRAME_PROFILE_ID
	normalized["strategy_id"] = STRATEGY_ID
	return super._frame_error(normalized)


static func _cynthia_supported_config(value: Variant, pins: Dictionary) -> bool:
	if not value is Dictionary or not _has_exact_keys(value, ["config_profile_id", "document_type", "schema_version", "values"]):
		return false
	var values: Variant = value.get("values")
	return (
		value.get("schema_version") == 1
		and value.get("config_profile_id") == "ptcgdap-author-policy-config-v1"
		and value.get("document_type") == "author_policy_config_v1"
		and values is Dictionary
		and _has_exact_keys(values, ["cabt_exportable", "card_id_domain", "deck_manifest_sha256", "platform_scope", "source_deck_id"])
		and values.get("cabt_exportable") == false
		and values.get("card_id_domain") == CARD_ID_DOMAIN
		and values.get("deck_manifest_sha256") == pins.get("deck_manifest_sha256")
		and values.get("platform_scope") == "windows"
		and values.get("source_deck_id") == CYNTHIA_SOURCE_DECK_ID
	)


static func _cynthia_supported_ir(value: Dictionary) -> bool:
	var nodes: Variant = value.get("nodes")
	if (
		value.get("schema_version") != 1
		or value.get("profile_id") != "ptcgdap-restricted-base-graph-ir-p4-wp2-v1"
		or value.get("graph_id") != CYNTHIA_PACKAGE_ID
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


static func _cynthia_supported_adapter(value: Dictionary) -> bool:
	return (
		value.get("schema_version") == 1
		and value.get("adapter_id") == CYNTHIA_PACKAGE_ID
		and value.get("adapter_version") == 1
		and value.get("card_id_domain") == CARD_ID_DOMAIN
		and value.get("rules") is Array
		and value.get("rules").size() == CYNTHIA_ADAPTER_RULE_COUNT
	)
