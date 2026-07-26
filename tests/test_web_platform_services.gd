class_name TestWebPlatformServices
extends TestBase

const Services := preload("res://scripts/ui/web/WebPlatformServices.gd")


func test_clipboard_script_is_request_scoped_and_reports_failure() -> String:
	var script := Services.build_clipboard_read_script("__testClipboard", 42)
	return run_checks([
		assert_true(script.contains("navigator.clipboard.readText"), "Web clipboard should use the browser clipboard API"),
		assert_true(script.contains("var requestId = 42"), "Clipboard responses must retain request identity"),
		assert_true(script.contains("ok: false"), "Clipboard denial should return a structured failure"),
		assert_true(script.contains("__testClipboard"), "The generated script should use the isolated callback name"),
	])


func test_clipboard_service_ignores_late_or_duplicate_results() -> String:
	var services: WebPlatformServices = Services.new()
	services.set_test_force_web(true)
	var received: Array[Dictionary] = []
	var requested := services.request_clipboard_text(func(payload: Dictionary) -> void:
		received.append(payload)
	)
	var request_id := services.latest_clipboard_request_id_for_tests()
	var delivered := services.deliver_clipboard_result_for_tests(request_id, {"ok": true, "text": "secret"})
	var duplicate := services.deliver_clipboard_result_for_tests(request_id, {"ok": true, "text": "duplicate"})
	services.shutdown()
	return run_checks([
		assert_true(requested, "Test Web clipboard request should be accepted"),
		assert_true(delivered, "Current request should deliver once"),
		assert_false(duplicate, "Duplicate browser callback should be ignored"),
		assert_eq(received.size(), 1, "Clipboard callback should run exactly once"),
		assert_eq(str(received[0].get("text", "")), "secret", "Clipboard payload should be preserved"),
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
