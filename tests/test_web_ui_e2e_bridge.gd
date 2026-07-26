class_name TestWebUiE2EBridge
extends TestBase

const BridgeScript := preload("res://web/e2e/WebUiE2EBridge.gd")
const FeatureGateScript := preload("res://scripts/ui/web/WebUiFeatureGate.gd")
const ProfileResolverScript := preload("res://scripts/ui/runtime/UiRuntimeProfileResolver.gd")


func test_e2e_bridge_uses_request_ids_and_has_bounded_read_only_commands() -> String:
	var install_script := BridgeScript.build_install_script()
	return run_checks([
		assert_true(install_script.contains("window.__PTCG_TEST__"), "Test builds should expose the semantic bridge"),
		assert_true(install_script.contains("request: function(command, payload)"), "Bridge calls should be request-scoped"),
		assert_true(install_script.contains("consume: function(id)"), "Completed command results should be removable"),
		assert_false(install_script.contains("eval(command)"), "The test bridge must not expose arbitrary JavaScript evaluation"),
	])


func test_web_input_feature_gate_is_web_only_and_has_legacy_kill_switch() -> String:
	var web_profile := ProfileResolverScript.resolve("Web", {"web": true}, "web", Vector2(1280, 720))
	var native_profile := ProfileResolverScript.resolve("Windows", {}, "windows", Vector2(1280, 720))
	FeatureGateScript.set_test_mode("v2")
	var web_v2 := FeatureGateScript.web_input_adapter_v2_enabled(web_profile)
	var native_v2 := FeatureGateScript.web_input_adapter_v2_enabled(native_profile)
	FeatureGateScript.set_test_mode("legacy")
	var legacy := FeatureGateScript.web_input_adapter_v2_enabled(web_profile)
	FeatureGateScript.reset_for_tests()
	return run_checks([
		assert_true(web_v2, "V2 should be available in Web runtime"),
		assert_false(native_v2, "Web feature overrides must never alter native input ownership"),
		assert_false(legacy, "The legacy query mode should be an immediate Web-only kill switch"),
	])

