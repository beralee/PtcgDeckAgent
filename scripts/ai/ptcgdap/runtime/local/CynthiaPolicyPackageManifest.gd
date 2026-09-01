class_name CynthiaPolicyPackageManifest
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const ParentManifestScript = preload("res://scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd")
const MANIFEST_PATH := "res://data/ptcgdap/cynthia_garchomp_windows_policy_package_v1.json"
const PACKAGE_ID := "ptcgdap.cynthia-garchomp-800018543.windows-local"
const PACKAGE_VERSION := "0.1.0"
const ARCHIVE_SHA256 := "3059C308904B323AF5CA10B1956EF8BB35F77A1174CF0AD0258F1A70A128FF06"
const POLICY_PACKAGE_ID := "ptcgdap.cynthia-garchomp-800018543.windows-local.policy"
const POLICY_SHA256 := "5245F2DF721E476E00586332D93378B8476B8D596E6A4E16B01ED55BF4CF82EB"
const OWNER_SHA256 := "E929A438C1377C2FCD648321B580C1767DFC178BBA9B463C6A1D41F7A8FB86D2"
const BASE_EXECUTOR_SHA256 := "1962E0F77AB6DCCACCC9F3946119783B801262961E2C57715FC739904E42788F"
const ENGINE_ACTION_EXECUTOR_SHA256 := "FB109EF0DAD00FDC0AD3BA08D00122D827D7CB723750F6A404E60F85C98B7D50"


static func load_and_verify(handle: Variant) -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return _result(false, "policy_package_document_missing")
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_bytes(MANIFEST_PATH).get_string_from_utf8()
	)
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
	var author: Variant = document.get("author_package")
	if (
		document.get("document_type") != "policy_package_v1"
		or document.get("schema_version") != 1
		or document.get("package_id") != POLICY_PACKAGE_ID
		or document.get("package_version") != PACKAGE_VERSION
		or document.get("authority_scope") != "development_exact_fixture_only"
		or document.get("target") != {
			"host":"godot", "platform":"windows", "architecture":"x86_64",
			"execution_location":"device_local",
		}
		or not author is Dictionary
		or not _has_exact_keys(author, [
			"path", "package_id", "package_version", "archive_sha256", "manifest_sha256",
			"deck_manifest_sha256", "policy_ir_sha256", "adapter_sha256", "config_sha256", "weights",
		])
		or author.get("path") != "data/ptcgdap/author_strategy_packages/ptcgdap-cynthia-garchomp-development-candidate.ptcgai"
		or author.get("package_id") != PACKAGE_ID
		or author.get("package_version") != PACKAGE_VERSION
		or author.get("archive_sha256") != ARCHIVE_SHA256
	):
		return _result(false, "policy_package_identity_mismatch")
	if handle == null or not handle.has_method("validate_integrity") or not bool(handle.validate_integrity()):
		return _result(false, "policy_package_archive_mismatch")
	var pins: Dictionary = handle.to_public_dict()
	var weights: Variant = author.get("weights")
	if (
		pins.get("package_id") != PACKAGE_ID
		or pins.get("package_version") != PACKAGE_VERSION
		or pins.get("archive_sha256") != ARCHIVE_SHA256
		or pins.get("manifest_sha256") != author.get("manifest_sha256")
		or pins.get("deck_manifest_sha256") != author.get("deck_manifest_sha256")
		or pins.get("policy_ir_sha256") != author.get("policy_ir_sha256")
		or pins.get("adapter_sha256") != author.get("adapter_sha256")
		or pins.get("config_sha256") != author.get("config_sha256")
		or not weights is Dictionary
		or weights != {
			"path":"policy/weights.bin", "sha256":pins.get("weights_sha256"),
			"status":"unused_non_model_payload",
		}
	):
		return _result(false, "policy_package_member_mismatch")
	var contracts: Dictionary = ParentManifestScript._expected_contracts()
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
	if document.get("parents") != ParentManifestScript._expected_parents():
		return _result(false, "policy_package_parent_mismatch")
	if document.get("rollback") != ParentManifestScript._expected_rollback():
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
		"archive_sha256":ARCHIVE_SHA256,
		"learned_model":"none",
		"execution_location":"device_local",
		"manifest_canonical_sha256":_canonical_value_sha(document),
		"production_ready":false,
	}


static func _expected_executor() -> Dictionary:
	return {
		"kind":"gdscript_restricted_ir_v1",
		"portable_baseline":"gdscript",
		"host_adapter_path":"scripts/ai/ptcgdap/runtime/local/CynthiaAuthorStrategyDevelopmentPolicy.gd",
		"host_adapter_sha256":POLICY_SHA256,
		"base_executor_path":"scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd",
		"base_executor_sha256":BASE_EXECUTOR_SHA256,
		"match_owner_path":"scripts/ai/ptcgdap/host/godot/CynthiaAuthorStrategyDevelopmentBattleOwner.gd",
		"match_owner_sha256":OWNER_SHA256,
		"engine_action_executor_path":"scripts/ai/ptcgdap/host/godot/AuthorStrategyEngineActionExecutor.gd",
		"engine_action_executor_sha256":ENGINE_ACTION_EXECUTOR_SHA256,
		"policy_boundary":"agent(raw_observation)->list[int]",
	}


static func _canonical_value_sha(value: Variant) -> String:
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		JSON.stringify(value).to_utf8_buffer()
	)
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.get("bytes", PackedByteArray()))
	return context.finish().hex_encode().to_upper()


static func _has_exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _coerce_integral_numbers(value: Variant) -> Variant:
	if value is float:
		if not is_finite(value) or value != floor(value):
			return value
		return int(value)
	if value is Array:
		var array: Array = []
		for item: Variant in value:
			array.append(_coerce_integral_numbers(item))
		return array
	if value is Dictionary:
		var dictionary := {}
		for key: Variant in value:
			dictionary[key] = _coerce_integral_numbers(value[key])
		return dictionary
	return value


static func _result(accepted: bool, code: String) -> Dictionary:
	return {"accepted":accepted, "error_code":code}
