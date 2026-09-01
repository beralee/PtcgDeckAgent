class_name TestDeviceManifest
extends TestBase

const PACKAGE_ID := "ptcgdap.marnie.windows-local"
const PACKAGE_VERSION := "0.1.0"
const PACKAGE_ARCHIVE_SHA256 := "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
const DEVICE_MANIFEST_CANONICAL_SHA256 := "475E6908B99CF4383C7B90A8CD588915D6B18B2B37C2A4B6E9C3F0F8BA4C9ACF"

const GateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd")
const CatalogScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")
const DeviceManifestScript = preload("res://scripts/ai/ptcgdap/runtime/local/DeviceManifest.gd")


func _handle() -> Dictionary:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var result: Dictionary = GateScript.request_match_handle(catalog, {
		"package_id":PACKAGE_ID,
		"package_version":PACKAGE_VERSION,
		"archive_sha256":PACKAGE_ARCHIVE_SHA256,
		"install_source":"built_in",
	}, "Windows")
	catalog.free()
	return result


func test_windows_device_manifest_pins_runtime_executor_profile_and_claim_boundary() -> String:
	var requested := _handle()
	if not bool(requested.get("ok", false)):
		return "exact package handle failed: %s" % str(requested)
	var verified: Dictionary = DeviceManifestScript.load_and_verify(requested.get("handle"))
	if not bool(verified.get("accepted", false)):
		return "device manifest verification failed: %s" % str(verified)
	return run_checks([
		assert_true(bool(verified.get("accepted", false))),
		assert_eq(verified.get("error_code"), ""),
		assert_eq(verified.get("manifest_id"), "ptcgdap-marnie-windows-device-v1"),
		assert_eq(verified.get("manifest_canonical_sha256"), DEVICE_MANIFEST_CANONICAL_SHA256),
		assert_eq(verified.get("platform"), "windows"),
		assert_eq(verified.get("architecture"), "x86_64"),
		assert_eq(verified.get("abi"), "windows-x86_64"),
		assert_eq(verified.get("execution_location"), "device_local"),
		assert_eq(verified.get("learned_model"), "none"),
		assert_eq(verified.get("model_backend"), "none"),
		assert_true(bool(verified.get("device_profile_approved", false))),
		assert_eq(verified.get("production_signature_status"), "unprovisioned"),
		assert_false(bool(verified.get("production_ready", true))),
		assert_false(bool(verified.get("a5_claimed", true))),
		assert_false(bool(verified.get("android_claimed", true))),
		assert_true(bool(verified.get("local_policy_executor", {}).get("accepted", false))),
	])


func test_device_manifest_tampering_fails_closed_without_widening_authority() -> String:
	var requested := _handle()
	if not bool(requested.get("ok", false)):
		return "exact package handle failed: %s" % str(requested)
	var manifest_loaded: Dictionary = DeviceManifestScript._load_strict_artifact(
		"res://data/ptcgdap/marnie_windows_device_manifest_v1.json"
	)
	var profile_loaded: Dictionary = DeviceManifestScript._load_strict_artifact(
		"res://data/ptcgdap/author_strategy_device_acceptance_profile.json"
	)
	if not bool(manifest_loaded.get("ok", false)) or not bool(profile_loaded.get("ok", false)):
		return "strict manifest fixture load failed"
	var manifest: Dictionary = manifest_loaded.get("document")
	var profile: Dictionary = profile_loaded.get("document")
	var target_tamper := manifest.duplicate(true)
	target_tamper["target_platforms"].append({
		"os":"android", "architecture":"arm64-v8a", "abi":"android-arm64-v8a",
		"host":"godot", "minimum_runtime_version":"4.6.1",
		"runtime_build":"4.6.1.stable.official.14d19694e", "portable_baseline":"gdscript",
	})
	var execution_tamper := manifest.duplicate(true)
	execution_tamper["execution"]["aligned_ai_network"] = "allowed"
	var resource_tamper := manifest.duplicate(true)
	resource_tamper["resource_profile"]["limits"]["max_decision_p95_msec"] = 999999
	var signature_tamper := manifest.duplicate(true)
	signature_tamper["package_integrity"]["signing_key_id"] = "development-key"
	var rollback_tamper := manifest.duplicate(true)
	rollback_tamper["fallback"]["rollback_manifest"]["canonical_sha256"] = "A".repeat(64)
	var near_integral: Variant = DeviceManifestScript._coerce_integral_numbers(1.0000001)
	return run_checks([
		assert_eq(
			DeviceManifestScript.verify_document(target_tamper, profile, requested.get("handle")).get("error_code"),
			"device_manifest_target_mismatch"
		),
		assert_eq(
			DeviceManifestScript.verify_document(execution_tamper, profile, requested.get("handle")).get("error_code"),
			"device_manifest_execution_mismatch"
		),
		assert_eq(
			DeviceManifestScript.verify_document(resource_tamper, profile, requested.get("handle")).get("error_code"),
			"device_manifest_profile_mismatch"
		),
		assert_eq(
			DeviceManifestScript.verify_document(signature_tamper, profile, requested.get("handle")).get("error_code"),
			"device_manifest_integrity_invalid"
		),
		assert_eq(
			DeviceManifestScript.verify_document(rollback_tamper, profile, requested.get("handle")).get("error_code"),
			"device_manifest_fallback_mismatch"
		),
		assert_eq(typeof(near_integral), TYPE_FLOAT),
		assert_eq(near_integral, 1.0000001),
	])
