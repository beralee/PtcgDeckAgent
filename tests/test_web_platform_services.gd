class_name TestWebPlatformServices
extends TestBase

const Services := preload("res://scripts/ui/web/WebPlatformServices.gd")


func test_secret_entry_script_is_native_isolated_and_paste_capable() -> String:
	var script := Services.build_secret_entry_script("__testSecretEntry", 17, "existing")
	return run_checks([
		assert_true(script.contains("ptcg-native-secret-entry"), "Web secret entry should have one stable native overlay id"),
		assert_true(script.contains("ptcg-native-secret-input"), "Web secret entry should expose one real browser input"),
		assert_true(script.contains("webkitTextSecurity"), "The native text input should mask the API key without using Safari's restrictive password editor"),
		assert_true(script.contains("webkitUserSelect") and script.contains("webkitTouchCallout"), "The native input must explicitly allow iOS selection and paste callouts"),
		assert_true(script.contains("touchAction") and script.contains("stopPropagation"), "The native overlay must isolate text gestures from the Godot canvas"),
		assert_true(script.contains("clipboardData") and script.contains("setRangeText"), "A real paste event must update the native input value"),
		assert_true(script.contains("ok: true") and script.contains("cancelled: true"), "Confirm and cancel must return distinct structured results"),
		assert_true(script.contains("__testSecretEntry") and script.contains("var requestId = 17"), "Secret entry callbacks must retain request identity"),
	])


func test_secret_entry_offers_one_tap_clipboard_read_with_native_fallback() -> String:
	var script := Services.build_secret_entry_script("__testSecretEntry", 18, "")
	return run_checks([
		assert_true(script.contains("ptcg-native-secret-read-clipboard"), "Web secret entry should expose a dedicated one-tap clipboard action"),
		assert_true(script.contains("navigator.clipboard") and script.contains("readText"), "The one-tap action should use the browser Clipboard API inside its user gesture"),
		assert_true(script.contains("无法直接读取") and script.contains("input.focus"), "Clipboard denial should keep the native editor open and focus the long-press fallback"),
		assert_true(script.contains("input.value = text"), "A successful clipboard read should fill the visible native input before confirmation"),
	])


func test_secret_entry_service_ignores_late_or_duplicate_results() -> String:
	var services: WebPlatformServices = Services.new()
	services.set_test_force_web(true)
	var received: Array[Dictionary] = []
	var first_requested := services.request_secret_text("old", func(payload: Dictionary) -> void:
		received.append(payload)
	)
	var first_request_id := services.latest_secret_entry_request_id_for_tests()
	var second_requested := services.request_secret_text("new", func(payload: Dictionary) -> void:
		received.append(payload)
	)
	var request_id := services.latest_secret_entry_request_id_for_tests()
	var stale := services.deliver_secret_entry_result_for_tests(
		first_request_id,
		{"ok": true, "text": "stale-secret"}
	)
	var delivered := services.deliver_secret_entry_result_for_tests(
		request_id,
		{"ok": true, "text": "new-secret"}
	)
	var duplicate := services.deliver_secret_entry_result_for_tests(
		request_id,
		{"ok": true, "text": "duplicate"}
	)
	services.shutdown()
	return run_checks([
		assert_true(first_requested and second_requested, "Test Web secret entry requests should be accepted"),
		assert_false(stale, "A replaced secret-entry request must not update the current Settings scene"),
		assert_true(delivered, "Current secret entry result should deliver once"),
		assert_false(duplicate, "Duplicate secret entry callback should be ignored"),
		assert_eq(received.size(), 1, "Secret entry callback should run exactly once"),
		assert_eq(str(received[0].get("text", "")), "new-secret", "Secret entry payload should be preserved"),
	])


func test_web_runtime_detection_keeps_native_android_separate() -> String:
	var services: WebPlatformServices = Services.new()
	return run_checks([
		assert_true(services.is_web_runtime("Web", {"web_ios": true}, "html5"), "Mobile Safari should use Web platform services"),
		assert_false(services.is_web_runtime("Android", {"android": true, "mobile": true}, ""), "Native Android must keep native clipboard services"),
	])


func test_settings_scene_no_longer_calls_javascript_bridge_directly() -> String:
	var source := FileAccess.get_file_as_string("res://scenes/settings/Settings.gd")
	return run_checks([
		assert_false(source.contains("JavaScriptBridge"), "Settings scene should call WebPlatformServices instead of owning browser callbacks"),
		assert_true(source.contains("WebPlatformServicesScript"), "Settings scene should depend on the isolated Web platform service"),
		assert_true(source.contains("_web_platform_services.shutdown()"), "Settings scene should release pending browser callbacks on exit"),
	])
