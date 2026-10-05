extends TestBase

const Compatibility = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyRuntimeCompatibility.gd")
const Installer = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageInstaller.gd")
const Loader = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd")
const RealCatalog = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")

class RejectedLoader extends RefCounted:
	func inspect_match_bytes(_bytes: PackedByteArray, _sha: String) -> Dictionary:
		return Compatibility.inspect({"plan_comparison_profile": "resource-continuity-v2"}, {})

class Catalog extends RefCounted:
	func scan_startup() -> Dictionary:
		return {}

func test_old_package_keeps_no_new_requirement() -> String:
	var result := Compatibility.inspect({"schema_version": 1})
	assert_true(result.ok)
	return assert_eq(result.runtime_compatibility.minimum_client_version, "")

func test_profiles_require_exact_supported_capabilities() -> String:
	var result := Compatibility.inspect({"damage_forecast_profile": "reviewed-gust-v1", "plan_comparison_profile": "resource-continuity-v2"})
	assert_true(result.ok)
	assert_eq(result.runtime_compatibility.minimum_client_version, "0.6.3")
	assert_eq(result.runtime_compatibility.minimum_client_build, 63)
	return assert_eq(result.runtime_compatibility.required_profiles.size(), 2)

func test_high_version_alone_does_not_grant_missing_capability() -> String:
	var result := Compatibility.inspect({"plan_comparison_profile": "resource-continuity-v2"}, {})
	assert_false(result.ok)
	assert_eq(result.error_code, "package_runtime_upgrade_required")
	var text := Compatibility.error_text(result)
	assert_true(text.contains("0.6.3") and text.contains("63") and text.contains("重启"))
	return assert_eq(result.runtime_compatibility.missing_profiles.size(), 1)

func test_unknown_profile_does_not_invent_minimum_version() -> String:
	for value: Variant in ["future-v99", null, 2, {}, []]:
		var result := Compatibility.inspect({"plan_comparison_profile": value})
		assert_false(result.ok)
		assert_eq(result.error_code, "package_runtime_profile_unknown")
		assert_eq(result.runtime_compatibility.minimum_client_version, "")
	return ""

func test_profile_order_does_not_change_requirements() -> String:
	return assert_eq(Compatibility.inspect({"damage_forecast_profile": "reviewed-gust-v1", "plan_comparison_profile": "resource-continuity-v2"}), Compatibility.inspect({"plan_comparison_profile": "resource-continuity-v2", "damage_forecast_profile": "reviewed-gust-v1"}))

func test_installer_preserves_upgrade_details_before_writing() -> String:
	var result := Installer.new().install_local_bytes(Catalog.new(), RejectedLoader.new(), PackedByteArray([1, 2, 3]))
	assert_false(result.ok)
	assert_eq(result.error_code, "package_runtime_upgrade_required")
	return assert_eq(result.runtime_compatibility.minimum_client_version, "0.6.3")

func test_strict_loader_returns_unknown_profile_detail() -> String:
	var result: Dictionary = Loader.new()._strict_document('{"schema_version":2,"plan_comparison_profile":"future-v99"}'.to_utf8_buffer(), "adapter", "package_policy_unsupported")
	assert_eq(result.error_code, "package_runtime_profile_unknown")
	return assert_true(Compatibility.error_text(result).contains("无法确定最低支持版本"))

func test_exact_dragapult_package_installs_with_version_requirement() -> String:
	var bytes := FileAccess.get_file_as_bytes("res://tests/ptcgdap/fixtures/strategy_profiles/dragapult-0.29.0.ptcgai")
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bytes)
	assert_eq(hash_context.finish().hex_encode().to_upper(), "AD8396CA9C9D15058A9507D4D2CA450636E638CE4298B12902D232C515531629")
	var catalog := RealCatalog.new()
	var result := Installer.new().install_local_bytes(catalog, Loader.new(), bytes)
	assert_true(result.get("ok", false), str(result.get("error_code", "")))
	var metadata: Dictionary = result.get("metadata", {})
	assert_eq(metadata.get("runtime_compatibility", {}).get("minimum_client_version"), "0.6.3")
	assert_eq(metadata.get("execution_trusted"), false)
	catalog.free()
	return ""
