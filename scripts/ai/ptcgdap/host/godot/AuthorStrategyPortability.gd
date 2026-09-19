class_name AuthorStrategyPortability
extends RefCounted

## Overlay for already verified/admitted data, never an authority or archive rewrite.
const PROFILE_ID := "ptcgdap-legacy-data-portability-v1"
const REVIEWED_KINDS := ["reviewed_restricted_ir_v1", "reviewed_competitive_policy_v2"]
const LEGACY_IDS := ["ptcgdap.marnie.windows-local", "ptcgdap.cynthia-garchomp-800018543.windows-local"]


static func evaluate(metadata: Dictionary, candidate: Dictionary, capabilities: Dictionary) -> Dictionary:
	if not bool(capabilities.get("rules_available", false)):
		return _error(str(capabilities.get("error_code", "author_strategy_platform_unsupported")))
	var version: Variant = metadata.get("package_schema_version", 2 if metadata.get("package_document_type") == "strategy_package_v2" else 1)
	var kind := str(candidate.get("runtime_kind", ""))
	var document_type := str(metadata.get("package_document_type", "strategy_package_v%d" % int(version)))
	if version not in [1, 2] or document_type != "strategy_package_v%d" % int(version) \
			or metadata.get("deck_card_id_domain") != "godot_local_card_uid_v1" \
			or metadata.get("deck_platform_scope") != ["windows"] \
			or (kind not in REVIEWED_KINDS and not (kind.is_empty() and candidate.get("package_id") in LEGACY_IDS)):
		return _error("author_strategy_package_not_portable")
	var mode := str(metadata.get("policy_mode", "rules_only"))
	if mode not in ["rules_only", "rules_with_model"] or (mode == "rules_with_model" and version != 2):
		return _error("author_strategy_package_not_portable")
	if mode == "rules_with_model" and not bool(capabilities.get("model_available", false)):
		return _error(str(capabilities.get("model_error_code", "model_runtime_unavailable")))
	return {"ok":true, "error_code":"", "profile_id":PROFILE_ID,
		"declared_platforms":["windows"], "effective_platform":capabilities.get("platform")}


static func _error(code: String) -> Dictionary:
	return {"ok":false, "error_code":code}
