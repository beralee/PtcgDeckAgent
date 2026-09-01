class_name PolicyPackageManifest
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const MANIFEST_PATH := "res://data/ptcgdap/marnie_windows_policy_package_v1.json"
const SOURCE_LOCK_SHA256 := "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
const HOST_ADAPTER_SHA256 := "26582CA6B049A645BB0E615B64AA7977FDB0D00DDFF92D931F0C4971C3031038"
const BASE_EXECUTOR_SHA256 := "1962E0F77AB6DCCACCC9F3946119783B801262961E2C57715FC739904E42788F"
const MATCH_OWNER_SHA256 := "CFD6301610B30A1D0609AAF9F8B9A40EB0AE0D4C406E38E97A65A0F80751F601"
const ENGINE_ACTION_EXECUTOR_SHA256 := "FB109EF0DAD00FDC0AD3BA08D00122D827D7CB723750F6A404E60F85C98B7D50"
const SEALED_D051_RELEASE_BUNDLE_CANONICAL := "8C023680073C8CD0B7A423B07B840629812B2043305EA16411765A44F7F4D1EB"
const SEALED_D051_ROLLBACK_PROFILE_CANONICAL := "01FCA4ED2B6228732AE91B5934F1A93272F92A2EC0B144E2695616C55BE7BF07"


static func load_and_verify(handle: Variant) -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return _result(false, "policy_package_document_missing")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_bytes(MANIFEST_PATH).get_string_from_utf8())
	parsed = _coerce_integral_numbers(parsed)
	if not parsed is Dictionary:
		return _result(false, "policy_package_schema_invalid")
	return verify_document(parsed, handle)


static func verify_document(document: Variant, handle: Variant) -> Dictionary:
	if not document is Dictionary or not _has_exact_keys(document, [
		"document_type", "schema_version", "package_id", "package_version", "authority_scope",
		"target", "author_package", "contracts", "executor", "model", "trace", "capabilities",
		"fallback", "parents", "rollback",
	]):
		return _result(false, "policy_package_schema_invalid")
	var target: Variant = document.get("target")
	var author: Variant = document.get("author_package")
	if (
		document.get("document_type") != "policy_package_v1"
		or document.get("schema_version") != 1
		or document.get("package_id") != "ptcgdap.marnie.windows-local.policy"
		or document.get("package_version") != "0.1.0"
		or document.get("authority_scope") != "development_and_device_canary_only"
		or target != {"host":"godot", "platform":"windows", "architecture":"x86_64", "execution_location":"device_local"}
		or not author is Dictionary
		or not _has_exact_keys(author, [
			"path", "package_id", "package_version", "archive_sha256", "manifest_sha256",
			"deck_manifest_sha256", "policy_ir_sha256", "adapter_sha256", "config_sha256", "weights",
		])
		or author.get("path") != "data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai"
		or author.get("package_id") != "ptcgdap.marnie.windows-local"
		or author.get("package_version") != "0.1.0"
	):
		return _result(false, "policy_package_identity_mismatch")
	if handle == null or not handle.has_method("validate_integrity") or not bool(handle.validate_integrity()):
		return _result(false, "policy_package_archive_mismatch")
	var pins: Dictionary = handle.to_public_dict()
	if pins.get("archive_sha256") != author.get("archive_sha256"):
		return _result(false, "policy_package_archive_mismatch")
	var weights: Variant = author.get("weights")
	if (
		pins.get("package_id") != author.get("package_id")
		or pins.get("package_version") != author.get("package_version")
		or pins.get("manifest_sha256") != author.get("manifest_sha256")
		or pins.get("deck_manifest_sha256") != author.get("deck_manifest_sha256")
		or pins.get("policy_ir_sha256") != author.get("policy_ir_sha256")
		or pins.get("adapter_sha256") != author.get("adapter_sha256")
		or pins.get("config_sha256") != author.get("config_sha256")
		or not weights is Dictionary
		or weights != {"path":"policy/weights.bin", "sha256":pins.get("weights_sha256"), "status":"unused_non_model_payload"}
	):
		return _result(false, "policy_package_member_mismatch")
	var contracts := _expected_contracts()
	if contracts.is_empty() or document.get("contracts") != contracts or document.get("trace") != {
		"profile":"strategic_trace_v2",
		"bundle_canonical_sha256":contracts.get("strategic_trace_v2_bundle_canonical_sha256"),
	}:
		return _result(false, "policy_package_contract_mismatch")
	if document.get("executor") != _expected_executor():
		return _result(false, "policy_package_executor_mismatch")
	if document.get("model") != {
		"learned_model":"none", "backend":"none", "artifact_path":null,
		"artifact_sha256":null, "unexpected_fallback_expected":0,
	}:
		return _result(false, "policy_package_model_mismatch")
	if document.get("parents") != _expected_parents():
		return _result(false, "policy_package_parent_mismatch")
	if document.get("rollback") != _expected_rollback():
		return _result(false, "policy_package_rollback_mismatch")
	if document.get("capabilities") != {
		"cabt_search":"none", "seeded_offline":false, "card_id_domain":"godot_local_card_uid_v1",
		"cabt_exportable":false, "network_ingress":false, "network_egress":false,
		"system_python":false, "external_process":false, "dynamic_model_download":false,
		"policy_output":"current_window_indexes_only",
	} or document.get("fallback") != {
		"owner":"restricted_base_graph", "mode":"deterministic_same_window",
		"remote":false, "classic_raw_state":false,
	}:
		return _result(false, "policy_package_integrity_invalid")
	return {
		"accepted":true,
		"error_code":"",
		"package_id":document.get("package_id"),
		"package_version":document.get("package_version"),
		"archive_sha256":author.get("archive_sha256"),
		"learned_model":"none",
		"execution_location":"device_local",
		"manifest_canonical_sha256":_canonical_value_sha(document),
		"production_ready":false,
	}


static func _expected_contracts() -> Dictionary:
	var values := {
		"cabt_contract_canonical_sha256":_canonical_file_sha("res://contracts/ptcgdap/cabt_contract_bundle.json"),
		"card_catalog_bundle_canonical_sha256":_canonical_file_sha("res://contracts/ptcgdap/card_id_catalog_bundle.json"),
		"base_executor_bundle_canonical_sha256":_canonical_file_sha("res://contracts/ptcgdap/restricted_base_graph_executor_bundle.json"),
		"public_deck_adapter_bundle_canonical_sha256":_canonical_file_sha("res://contracts/ptcgdap/public_deck_adapter_bundle.json"),
		"strategic_trace_v2_bundle_canonical_sha256":_canonical_file_sha("res://contracts/ptcgdap/strategic_trace_v2_bundle.json"),
		"source_lock_canonical_sha256":SOURCE_LOCK_SHA256,
	}
	for value in values.values():
		if value == "":
			return {}
	return values


static func _expected_executor() -> Dictionary:
	var host := "res://scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd"
	var base := "res://scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd"
	var owner := "res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd"
	var action := "res://scripts/ai/ptcgdap/host/godot/AuthorStrategyEngineActionExecutor.gd"
	return {
		"kind":"gdscript_restricted_ir_v1",
		"portable_baseline":"gdscript",
		"host_adapter_path":host.trim_prefix("res://"),
		"host_adapter_sha256":HOST_ADAPTER_SHA256,
		"base_executor_path":base.trim_prefix("res://"),
		"base_executor_sha256":BASE_EXECUTOR_SHA256,
		"match_owner_path":owner.trim_prefix("res://"),
		"match_owner_sha256":MATCH_OWNER_SHA256,
		"engine_action_executor_path":action.trim_prefix("res://"),
		"engine_action_executor_sha256":ENGINE_ACTION_EXECUTOR_SHA256,
		"policy_boundary":"agent(raw_observation)->list[int]",
	}


static func _expected_parents() -> Dictionary:
	return {
		"author_package_bundle_canonical_sha256":_canonical_file_sha("res://contracts/ptcgdap/author_strategy_package_bundle.json"),
		"author_match_host_bundle_canonical_sha256":_canonical_file_sha("res://contracts/ptcgdap/author_strategy_match_host_bundle.json"),
		"author_live_seam_bundle_canonical_sha256":_canonical_file_sha("res://contracts/ptcgdap/author_strategy_live_seam_bundle.json"),
		"author_release_bundle_canonical_sha256":SEALED_D051_RELEASE_BUNDLE_CANONICAL,
		"source_lock_canonical_sha256":SOURCE_LOCK_SHA256,
	}


static func _expected_rollback() -> Dictionary:
	var path := "res://contracts/ptcgdap/author_strategy_release_profile.json"
	return {
		"mode":"disable_author_strategy_for_new_matches",
		"target_kind":"author_strategy_disabled_release_profile",
		"target_path":path.trim_prefix("res://"),
		"target_canonical_sha256":SEALED_D051_ROLLBACK_PROFILE_CANONICAL,
		"current_match_hot_swap":false,
		"user_packages_preserved":true,
	}


static func _canonical_file_sha(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(FileAccess.get_file_as_bytes(path))
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.get("bytes", PackedByteArray()))
	return context.finish().hex_encode().to_upper()


static func _canonical_value_sha(value: Variant) -> String:
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(JSON.stringify(value).to_utf8_buffer())
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.get("bytes", PackedByteArray()))
	return context.finish().hex_encode().to_upper()


static func _has_exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true


static func _coerce_integral_numbers(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), floor(float(value))):
		return int(value)
	if value is Array:
		var result: Array = []
		for child in value:
			result.append(_coerce_integral_numbers(child))
		return result
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = _coerce_integral_numbers(value[key])
		return result
	return value


static func _result(accepted: bool, error_code: String) -> Dictionary:
	return {"accepted":accepted, "error_code":error_code, "production_ready":false}
