class_name LocalPolicyExecutorManifest
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const ParentManifestScript = preload("res://scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd")

const MANIFEST_PATH := "res://data/ptcgdap/marnie_windows_local_policy_executor_v1.json"
const PARENT_MANIFEST_PATH := "res://data/ptcgdap/marnie_windows_policy_package_v1.json"
const PARENT_MANIFEST_CANONICAL_SHA256 := "3243ABD7937B3F53D8E5D7A887FC90BFBDF9A4D94E4030A3A9BE194C82370FFC"
const AUTHOR_ARCHIVE_SHA256 := "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"

const ENGINE_ACTION_EXECUTOR_SHA256 := "33AAD9E7A8E8666AB28F93F4217CC28BF5C45EE0C74ACB2705F2ADEDE260F2E2"
const INHERITED_POLICY_BASE_SHA256 := "EB6539627531A37E9B95153BCD04FFC29510C567974A05FE32115CEADAC72063"
const LOCAL_POLICY_EXECUTOR_SHA256 := "EC39D1F4E5B46766A3D1B5613D54A0825AB5BEAEFF209ACD2467C3604DBB7E92"
const MATCH_OWNER_SHA256 := "B2A56A7E3518C6C226966D9CBDC9910255E817376E2CCA1C5F0CD3FBFB305449"
const PUBLIC_DECK_ADAPTER_SHA256 := "BA7B029755DEF35DF996F203E448F38CDCC3E33926AAA92433439233E66D7164"
const RESTRICTED_BASE_EXECUTOR_SHA256 := "4267B20F94AB7D2828AC5AA5E24F98CB39EDF17592E021A207DB51CDCB59EC1F"
const STRATEGIC_TRACE_COMPILER_SHA256 := "61FA05956DC9C79342791C7E74BA34A0D596C7027E469462C2FADA8FDA18A50B"


static func load_and_verify(handle: Variant) -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return _result(false, "local_policy_executor_document_missing")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_bytes(MANIFEST_PATH).get_string_from_utf8())
	parsed = _coerce_integral_numbers(parsed)
	if not parsed is Dictionary:
		return _result(false, "local_policy_executor_schema_invalid")
	return verify_document(parsed, handle)


static func verify_document(document: Variant, handle: Variant) -> Dictionary:
	if not document is Dictionary or not _has_exact_keys(document, [
		"document_type", "schema_version", "executor_id", "executor_version", "authority_scope",
		"target", "parent_policy_package", "author_package", "resources", "implementation",
		"input_contract", "model", "fallback", "capabilities",
	]):
		return _result(false, "local_policy_executor_schema_invalid")
	if (
		document.get("document_type") != "local_policy_executor_v1"
		or document.get("schema_version") != 1
		or document.get("executor_id") != "ptcgdap-local-policy-executor-v1"
		or document.get("executor_version") != "1.0.0"
		or document.get("authority_scope") != "development_and_device_canary_only"
		or document.get("target") != {
			"host":"godot", "platform":"windows", "architecture":"x86_64",
			"execution_location":"device_local", "portable_baseline":"gdscript",
		}
	):
		return _result(false, "local_policy_executor_identity_mismatch")
	var parent: Dictionary = ParentManifestScript.load_and_verify(handle)
	if not bool(parent.get("accepted", false)):
		return _result(false, str(parent.get("error_code", "local_policy_executor_parent_mismatch")))
	if document.get("parent_policy_package") != {
		"path":PARENT_MANIFEST_PATH.trim_prefix("res://"),
		"canonical_sha256":PARENT_MANIFEST_CANONICAL_SHA256,
		"package_id":"ptcgdap.marnie.windows-local.policy",
		"package_version":"0.1.0",
	} or parent.get("manifest_canonical_sha256") != PARENT_MANIFEST_CANONICAL_SHA256:
		return _result(false, "local_policy_executor_parent_mismatch")
	if handle == null or not handle.has_method("validate_integrity") or not bool(handle.validate_integrity()):
		return _result(false, "local_policy_executor_author_package_mismatch")
	var pins: Dictionary = handle.to_public_dict()
	if document.get("author_package") != {
		"path":"data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai",
		"archive_sha256":AUTHOR_ARCHIVE_SHA256,
		"package_id":"ptcgdap.marnie.windows-local",
		"package_version":"0.1.0",
	} or pins.get("archive_sha256") != AUTHOR_ARCHIVE_SHA256:
		return _result(false, "local_policy_executor_author_package_mismatch")
	var expected_resources := _expected_resources(pins)
	if expected_resources.is_empty() or document.get("resources") != expected_resources:
		return _result(false, "local_policy_executor_resource_mismatch")
	var expected_implementation := _expected_implementation()
	if expected_implementation.is_empty() or document.get("implementation") != expected_implementation:
		return _result(false, "local_policy_executor_implementation_mismatch")
	if document.get("input_contract") != {
		"boundary":"agent(raw_observation)->list[int]",
		"card_id_domain":"godot_local_card_uid_v1",
		"policy_output":"current_window_indexes_only",
		"public_only":true,
		"same_window_required":true,
		"engine_reference_allowed":false,
	}:
		return _result(false, "local_policy_executor_integrity_invalid")
	if document.get("model") != {
		"learned_model":"none", "backend":"none", "artifact_path":null,
		"artifact_sha256":null, "weights_status":"unused_non_model_payload",
	}:
		return _result(false, "local_policy_executor_model_mismatch")
	if document.get("fallback") != {
		"owner":"restricted_base_graph", "mode":"deterministic_same_window",
		"remote":false, "classic_raw_state":false, "unexpected_fallback_expected":0,
	}:
		return _result(false, "local_policy_executor_fallback_mismatch")
	if document.get("capabilities") != {
		"cabt_search":"none", "seeded_offline":false,
		"network_ingress":false, "network_egress":false,
		"system_python":false, "external_process":false,
		"dynamic_model_download":false, "match_hot_swap":false,
	}:
		return _result(false, "local_policy_executor_integrity_invalid")
	return {
		"accepted":true,
		"error_code":"",
		"executor_id":document.get("executor_id"),
		"executor_version":document.get("executor_version"),
		"manifest_canonical_sha256":_canonical_value_sha(document),
		"execution_location":"device_local",
		"portable_baseline":"gdscript",
		"policy_output":"current_window_indexes_only",
		"learned_model":"none",
		"model_backend":"none",
		"parent_policy_package":parent.duplicate(true),
		"production_ready":false,
	}


static func _expected_resources(pins: Dictionary) -> Array:
	var result: Array = [
		_resource("product_bundle", "contracts/ptcgdap/cabt_contract_bundle.json", "canonical_json_v1", _canonical_file_sha("res://contracts/ptcgdap/cabt_contract_bundle.json")),
		_resource("product_bundle", "contracts/ptcgdap/card_id_catalog_bundle.json", "canonical_json_v1", _canonical_file_sha("res://contracts/ptcgdap/card_id_catalog_bundle.json")),
		_resource("product_bundle", "contracts/ptcgdap/public_deck_adapter_bundle.json", "canonical_json_v1", _canonical_file_sha("res://contracts/ptcgdap/public_deck_adapter_bundle.json")),
		_resource("product_bundle", "contracts/ptcgdap/restricted_base_graph_executor_bundle.json", "canonical_json_v1", _canonical_file_sha("res://contracts/ptcgdap/restricted_base_graph_executor_bundle.json")),
		_resource("product_bundle", "contracts/ptcgdap/strategic_trace_v2_bundle.json", "canonical_json_v1", _canonical_file_sha("res://contracts/ptcgdap/strategic_trace_v2_bundle.json")),
		_resource("author_archive", "policy/adapter.json", "raw_sha256", pins.get("adapter_sha256")),
		_resource("author_archive", "policy/config.json", "raw_sha256", pins.get("config_sha256")),
		_resource("author_archive", "policy/policy_ir.json", "raw_sha256", pins.get("policy_ir_sha256")),
		_resource("author_archive", "policy/weights.bin", "raw_sha256", pins.get("weights_sha256")),
	]
	for row: Variant in result:
		if not row is Dictionary or not _is_sha(row.get("sha256")):
			return []
	return result


static func _expected_implementation() -> Array:
	var rows: Array = [
		_implementation("engine_action_executor", "scripts/ai/ptcgdap/host/godot/AuthorStrategyEngineActionExecutor.gd", ENGINE_ACTION_EXECUTOR_SHA256),
		_implementation("match_owner", "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLocalExecutorBattleOwner.gd", MATCH_OWNER_SHA256),
		_implementation("public_deck_adapter", "scripts/ai/ptcgdap/public/PublicDeckAdapter.gd", PUBLIC_DECK_ADAPTER_SHA256),
		_implementation("restricted_base_executor", "scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd", RESTRICTED_BASE_EXECUTOR_SHA256),
		_implementation("strategic_trace_compiler", "scripts/ai/ptcgdap/public/StrategicTraceV2.gd", STRATEGIC_TRACE_COMPILER_SHA256),
		_implementation("inherited_policy_base", "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd", INHERITED_POLICY_BASE_SHA256),
		_implementation("local_policy_executor", "scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutor.gd", LOCAL_POLICY_EXECUTOR_SHA256),
	]
	for row: Variant in rows:
		if not row is Dictionary or not ResourceLoader.exists("res://" + str(row.get("path"))):
			return []
	return rows


static func _resource(location: String, path: String, hash_kind: String, digest: Variant) -> Dictionary:
	return {"location":location, "path":path, "hash_kind":hash_kind, "sha256":digest, "required":true}


static func _implementation(role: String, path: String, digest: String) -> Dictionary:
	return {"role":role, "path":path, "raw_sha256":digest}


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


static func _has_exact_keys(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _is_sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	for character: String in str(value):
		if character not in "0123456789ABCDEF":
			return false
	return true


static func _coerce_integral_numbers(value: Variant) -> Variant:
	if (
		typeof(value) == TYPE_FLOAT
		and is_finite(float(value))
		and float(value) == floor(float(value))
	):
		return int(value)
	if value is Array:
		var result: Array = []
		for child: Variant in value:
			result.append(_coerce_integral_numbers(child))
		return result
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[key] = _coerce_integral_numbers(value[key])
		return result
	return value


static func _result(accepted: bool, error_code: String) -> Dictionary:
	return {"accepted":accepted, "error_code":error_code, "production_ready":false}
