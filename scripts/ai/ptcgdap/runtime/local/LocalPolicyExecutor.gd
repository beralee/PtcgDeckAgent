class_name LocalPolicyExecutor
extends "res://scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd"

## Versioned device-local executor for the sealed Marnie author package.
##
## The inherited implementation is the immutable D051 GDScript restricted-IR
## chain whose Base leaf is public/RestrictedBaseGraphExecutor.gd.
## baseline.  This runtime owns the new match-time resource-closure check and
## is the object that executes select(frame); the D051 parent remains present
## byte-for-byte as the independently testable rollback implementation.

const LocalManifestScript = preload("res://scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutorManifest.gd")

const LOCAL_EXECUTOR_ID := "ptcgdap-local-policy-executor-v1"
const LOCAL_EXECUTOR_VERSION := "1.0.0"
const LOCAL_PROFILE_ID := "ptcgdap-windows-local-policy-executor-v1"

var _local_executor_pins: Dictionary = {}


static func create(
	handle: Variant,
	match_id: Variant,
	authority_mode: String = ExecutionGateScript.DEVELOPMENT_MODE
) -> Dictionary:
	if handle == null or not handle.has_method("validate_integrity") or not handle.validate_integrity():
		return _error("package_integrity_invalid")
	var local_manifest: Dictionary = LocalManifestScript.load_and_verify(handle)
	if not bool(local_manifest.get("accepted", false)):
		return _error(str(local_manifest.get("error_code", "local_policy_executor_integrity_invalid")))
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
	if card_count != 60 or allowed_uids.size() != 28:
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
	if not _supported_ir(ir_document) or not _supported_adapter(adapter_document):
		return _error("package_policy_unsupported")
	var config_document: Variant = documents.get("policy/config.json")
	if not _supported_config(config_document, pins):
		return _error("package_policy_unsupported")
	var claim: Dictionary = handle.claim_for_match(str(match_id))
	if not bool(claim.get("ok", false)):
		return _error(str(claim.get("error_code", "package_handle_already_claimed")))
	var script: GDScript = load("res://scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutor.gd")
	var executor: Variant = script.new(
		pins,
		ir_document,
		adapter_document,
		config_document,
		allowed_uids,
		str(match_id),
		authority_mode,
		local_manifest.get("parent_policy_package", {}),
		local_manifest,
		_FACTORY_TOKEN
	)
	if executor == null or not executor._is_valid_owner():
		return _error("local_policy_executor_integrity_invalid")
	return {"ok": true, "error_code": "", "policy": executor}


func _init(
	next_pins: Dictionary = {},
	next_ir: Dictionary = {},
	next_adapter: Dictionary = {},
	next_config: Dictionary = {},
	next_allowed_uids: Dictionary = {},
	next_match_id: String = "",
	next_authority_mode: String = ExecutionGateScript.DEVELOPMENT_MODE,
	next_policy_package_pins: Dictionary = {},
	next_local_executor_pins: Dictionary = {},
	token: Variant = null
) -> void:
	super(
		next_pins,
		next_ir,
		next_adapter,
		next_config,
		next_allowed_uids,
		next_match_id,
		next_authority_mode,
		next_policy_package_pins,
		token
	)
	if token == _FACTORY_TOKEN:
		_local_executor_pins = next_local_executor_pins.duplicate(true)


func _is_valid_owner() -> bool:
	return (
		super._is_valid_owner()
		and _local_executor_pins.get("executor_id") == LOCAL_EXECUTOR_ID
		and _local_executor_pins.get("executor_version") == LOCAL_EXECUTOR_VERSION
		and _local_executor_pins.get("execution_location") == "device_local"
		and _local_executor_pins.get("portable_baseline") == "gdscript"
		and _local_executor_pins.get("policy_output") == "current_window_indexes_only"
		and _local_executor_pins.get("learned_model") == "none"
		and _local_executor_pins.get("model_backend") == "none"
		and _is_sha(_local_executor_pins.get("manifest_canonical_sha256"))
	)


func audit_snapshot() -> Dictionary:
	var audit: Dictionary = super.audit_snapshot()
	audit["profile_id"] = LOCAL_PROFILE_ID
	audit["local_policy_executor_id"] = LOCAL_EXECUTOR_ID
	audit["local_policy_executor_version"] = LOCAL_EXECUTOR_VERSION
	audit["local_policy_executor_manifest_canonical_sha256"] = _local_executor_pins.get(
		"manifest_canonical_sha256"
	)
	audit["portable_baseline"] = _local_executor_pins.get("portable_baseline")
	audit["policy_output"] = _local_executor_pins.get("policy_output")
	audit["restricted_ir_executed"] = int(audit.get("successful_selections", 0)) > 0
	audit["deterministic_fallback_owner"] = "restricted_base_graph"
	audit["local_executor_runtime_authority"] = true
	audit["engine_commit_authority"] = false
	return audit
