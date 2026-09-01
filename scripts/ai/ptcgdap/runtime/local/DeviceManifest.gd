class_name DeviceManifest
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const LocalExecutorManifestScript = preload("res://scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutorManifest.gd")

const MANIFEST_PATH := "res://data/ptcgdap/marnie_windows_device_manifest_v1.json"
const ACCEPTANCE_PROFILE_PATH := "res://data/ptcgdap/author_strategy_device_acceptance_profile.json"
const ROLLBACK_MANIFEST_PATH := "res://data/ptcgdap/marnie_windows_policy_package_v1.json"
const LOCAL_EXECUTOR_CANONICAL_SHA256 := "6961EEECEEB33459002A40A52AA76AB0243871439D3FDF10B9F1F4927AB6D6E0"
const ACCEPTANCE_PROFILE_CANONICAL_SHA256 := "A8971FDEC09DE2B22DC131FEC35146A32013E6D7928BFDD46847B567B2B95169"
const ROLLBACK_CANONICAL_SHA256 := "3243ABD7937B3F53D8E5D7A887FC90BFBDF9A4D94E4030A3A9BE194C82370FFC"
const AUTHOR_ARCHIVE_SHA256 := "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"


static func load_and_verify(handle: Variant) -> Dictionary:
	var loaded := _load_strict_artifact(MANIFEST_PATH)
	if not bool(loaded.get("ok", false)):
		return _result(false, "device_manifest_document_invalid")
	var profile_loaded := _load_strict_artifact(ACCEPTANCE_PROFILE_PATH)
	if not bool(profile_loaded.get("ok", false)):
		return _result(false, "device_manifest_profile_mismatch")
	return verify_document(
		loaded.get("document"),
		profile_loaded.get("document"),
		handle
	)


static func verify_document(
	document: Variant,
	acceptance_profile: Variant,
	handle: Variant
) -> Dictionary:
	if not document is Dictionary or not _has_exact_keys(document, [
		"document_type", "schema_version", "manifest_id", "manifest_version",
		"target_platforms", "deferred_targets", "local_policy_executor",
		"inference_backend", "model_artifacts", "execution",
		"device_acceptance_profile", "resource_profile", "package_integrity",
		"fallback", "release_status",
	]):
		return _result(false, "device_manifest_schema_invalid")
	if (
		document.get("document_type") != "device_manifest_v1"
		or document.get("schema_version") != 1
		or document.get("manifest_id") != "ptcgdap-marnie-windows-device-v1"
		or document.get("manifest_version") != "1.1.0"
	):
		return _result(false, "device_manifest_identity_mismatch")
	if document.get("target_platforms") != [{
		"os":"windows",
		"architecture":"x86_64",
		"abi":"windows-x86_64",
		"host":"godot",
		"minimum_runtime_version":"4.6.1",
		"runtime_build":"4.6.1.stable.official.14d19694e",
		"portable_baseline":"gdscript",
	}] or document.get("deferred_targets") != [{
		"os":"android",
		"architecture":"arm64-v8a",
		"declared":false,
		"reason":"independent_android_adapter_and_a5_required",
	}]:
		return _result(false, "device_manifest_target_mismatch")
	if not _current_runtime_is_compatible():
		return _result(false, "device_manifest_runtime_mismatch")
	var local_executor: Dictionary = LocalExecutorManifestScript.load_and_verify(handle)
	if not bool(local_executor.get("accepted", false)):
		return _result(false, str(local_executor.get("error_code", "device_manifest_executor_mismatch")))
	if (
		document.get("local_policy_executor") != {
			"path":"data/ptcgdap/marnie_windows_local_policy_executor_v1.json",
			"canonical_sha256":LOCAL_EXECUTOR_CANONICAL_SHA256,
			"executor_id":"ptcgdap-local-policy-executor-v1",
			"executor_version":"1.0.0",
		}
		or local_executor.get("manifest_canonical_sha256") != LOCAL_EXECUTOR_CANONICAL_SHA256
	):
		return _result(false, "device_manifest_executor_mismatch")
	if document.get("inference_backend") != {
		"kind":"none",
		"version":null,
		"implementation_path":null,
		"implementation_hash":null,
	} or document.get("model_artifacts") != []:
		return _result(false, "device_manifest_model_mismatch")
	if document.get("execution") != {
		"location":"device_local",
		"aligned_ai_network":"denied",
		"external_compute":"denied",
		"system_python":false,
		"sidecar":false,
		"dynamic_model_download":false,
	}:
		return _result(false, "device_manifest_execution_mismatch")
	if not _verify_acceptance_profile(document, acceptance_profile):
		return _result(false, "device_manifest_profile_mismatch")
	if document.get("package_integrity") != {
		"hash_algorithm":"sha256",
		"manifest_hash_algorithm":"canonical_json_v1_sha256",
		"author_archive_sha256":AUTHOR_ARCHIVE_SHA256,
		"production_signature_required":true,
		"production_signature_status":"unprovisioned",
		"signature_algorithm":"ed25519",
		"signing_key_id":null,
		"trust_root_id":null,
		"signed_scope":"production_release",
		"development_unsigned_allowed":true,
	}:
		return _result(false, "device_manifest_integrity_invalid")
	if _canonical_file_sha(ROLLBACK_MANIFEST_PATH) != ROLLBACK_CANONICAL_SHA256:
		return _result(false, "device_manifest_fallback_mismatch")
	if document.get("fallback") != {
		"kind":"deterministic_local",
		"owner":"restricted_base_graph",
		"remote":false,
		"classic_raw_state":false,
		"new_matches_only":true,
		"match_hot_swap":false,
		"rollback_manifest":{
			"document_type":"policy_package_v1",
			"path":"data/ptcgdap/marnie_windows_policy_package_v1.json",
			"canonical_sha256":ROLLBACK_CANONICAL_SHA256,
		},
	}:
		return _result(false, "device_manifest_fallback_mismatch")
	if document.get("release_status") != {
		"authority_scope":"development_and_device_canary_only",
		"p6_04_windows_manifest_complete":true,
		"device_profile_approved":true,
		"os_network_isolation_proven":false,
		"production_ready":false,
		"a2_claimed":false,
		"a5_claimed":false,
		"android_claimed":false,
	}:
		return _result(false, "device_manifest_release_status_invalid")
	return {
		"accepted":true,
		"error_code":"",
		"manifest_id":"ptcgdap-marnie-windows-device-v1",
		"manifest_version":"1.1.0",
		"manifest_canonical_sha256":_canonical_value_sha(document),
		"platform":"windows",
		"architecture":"x86_64",
		"abi":"windows-x86_64",
		"execution_location":"device_local",
		"learned_model":"none",
		"model_backend":"none",
		"device_profile_approved":true,
		"production_signature_status":"unprovisioned",
		"production_ready":false,
		"a5_claimed":false,
		"android_claimed":false,
		"local_policy_executor":local_executor.duplicate(true),
	}


static func _verify_acceptance_profile(document: Dictionary, profile: Variant) -> bool:
	if not profile is Dictionary or not _has_exact_keys(profile, [
		"document_type", "schema_version", "profile_id", "approval_status",
		"formal_a5_eligible", "platforms", "measurement_method",
	]):
		return false
	if (
		profile.get("document_type") != "author_strategy_device_acceptance_profile_v1"
		or profile.get("schema_version") != 1
		or profile.get("profile_id") != "ptcgdap-device-acceptance-candidate-v1"
		or profile.get("approval_status") != "approved"
		or typeof(profile.get("formal_a5_eligible")) != TYPE_BOOL
		or bool(profile.get("formal_a5_eligible"))
		or _canonical_value_sha(profile) != ACCEPTANCE_PROFILE_CANONICAL_SHA256
	):
		return false
	var limits := {
		"max_cold_start_msec":10000,
		"max_catalog_scan_msec":1000,
		"max_match_load_msec":6000,
		"max_decision_p95_msec":250,
		"max_peak_memory_mib":1024,
		"max_package_mib":750,
		"max_thermal_status":null,
		"max_battery_drain_percent_per_hour":null,
	}
	if profile.get("platforms") != {"windows":limits}:
		return false
	if profile.get("measurement_method") != {
		"full_match_required":true,
		"airplane_or_os_block_required":false,
		"cold_start_samples":3,
		"decision_samples_minimum":100,
		"rollback_required":true,
	}:
		return false
	if document.get("device_acceptance_profile") != {
		"path":"data/ptcgdap/author_strategy_device_acceptance_profile.json",
		"profile_id":"ptcgdap-device-acceptance-candidate-v1",
		"canonical_sha256":ACCEPTANCE_PROFILE_CANONICAL_SHA256,
		"approval_status":"approved",
		"formal_a5_eligible":false,
		"thresholds_authority":"referenced_profile_only",
	}:
		return false
	return document.get("resource_profile") == {
		"source_platform":"windows",
		"limits":limits,
		"candidate_override_allowed":false,
		"acceptance_claim":true,
	}


static func _current_runtime_is_compatible() -> bool:
	if OS.get_name() != "Windows" or not OS.has_feature("x86_64"):
		return false
	var version: Dictionary = Engine.get_version_info()
	var major := int(version.get("major", 0))
	var minor := int(version.get("minor", 0))
	var patch := int(version.get("patch", 0))
	return major > 4 or (major == 4 and (minor > 6 or (minor == 6 and patch >= 1)))


static func _load_strict_artifact(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok":false}
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		FileAccess.get_file_as_bytes(path)
	)
	if not bool(canonical.get("ok", false)):
		return {"ok":false}
	var parsed: Variant = JSON.parse_string(str(canonical.get("text", "")))
	parsed = _coerce_integral_numbers(parsed)
	if not parsed is Dictionary:
		return {"ok":false}
	return {"ok":true, "document":parsed}


static func _canonical_file_sha(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		FileAccess.get_file_as_bytes(path)
	)
	if not bool(canonical.get("ok", false)):
		return ""
	return _sha_bytes(canonical.get("bytes", PackedByteArray()))


static func _canonical_value_sha(value: Variant) -> String:
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact(value)
	if not bool(canonical.get("ok", false)):
		return ""
	return _sha_bytes(canonical.get("bytes", PackedByteArray()))


static func _sha_bytes(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value)
	return context.finish().hex_encode().to_upper()


static func _coerce_integral_numbers(value: Variant) -> Variant:
	if (
		typeof(value) == TYPE_FLOAT
		and is_finite(float(value))
		and float(value) == floor(float(value))
	):
		return int(value)
	if value is Array:
		var array_result: Array = []
		for child: Variant in value:
			array_result.append(_coerce_integral_numbers(child))
		return array_result
	if value is Dictionary:
		var dictionary_result := {}
		for key: Variant in value:
			dictionary_result[key] = _coerce_integral_numbers(value[key])
		return dictionary_result
	return value


static func _has_exact_keys(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _result(accepted: bool, error_code: String) -> Dictionary:
	return {
		"accepted":accepted,
		"error_code":error_code,
		"device_profile_approved":false,
		"production_ready":false,
		"a5_claimed":false,
		"android_claimed":false,
	}
