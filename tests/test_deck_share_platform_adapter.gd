class_name TestDeckSharePlatformAdapter
extends TestBase

const DeckSharePlatformAdapterScript := preload("res://scripts/deck_share/DeckSharePlatformAdapter.gd")


func test_deck_share_platform_adapter_default_save_writes_png() -> String:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.1, 0.2, 0.3, 1.0))
	var result: Dictionary = DeckSharePlatformAdapterScript.save_png_to_default_path(image, "unsafe:name*deck")
	var path := str(result.get("path", ""))
	var loaded := Image.new()
	var load_err := loaded.load(path) if path != "" else ERR_FILE_NOT_FOUND
	return run_checks([
		assert_true(bool(result.get("ok", false)), "default save should succeed"),
		assert_str_contains(path, "unsafe_name_deck", "unsafe filename should be sanitized"),
		assert_eq(load_err, OK, "saved PNG should load"),
		assert_eq(loaded.get_size(), Vector2i(16, 16), "saved PNG size"),
	])


func test_deck_share_platform_adapter_web_download_script_uses_browser_blob() -> String:
	var script := DeckSharePlatformAdapterScript._build_web_download_script_for_tests("QUJD", "deck.png")
	return run_checks([
		assert_str_contains(script, "new Blob", "download should create a Blob"),
		assert_str_contains(script, "navigator.share", "mobile browsers should use the operating-system share sheet"),
		assert_str_contains(script, "navigator.canShare", "mobile browsers should verify file sharing support"),
		assert_str_contains(script, "showSaveFilePicker", "supported browsers should let the player choose a save location"),
		assert_str_contains(script, "anchor.download", "download should set filename"),
		assert_str_contains(script, "URL.createObjectURL", "download should use object URL"),
		assert_str_contains(script, "\"QUJD\"", "download should embed base64 safely"),
	])


func test_deck_share_platform_adapter_web_pick_script_uses_file_reader() -> String:
	var script := DeckSharePlatformAdapterScript._build_web_pick_image_script_for_tests("__testDeckShareCallback")
	return run_checks([
		assert_str_contains(script, "input.type = 'file'", "web import should create file input"),
		assert_str_contains(script, "image/png,image/jpeg,image/webp", "web import should restrict image types"),
		assert_str_contains(script, "new FileReader", "web import should use FileReader"),
		assert_str_contains(script, "__testDeckShareCallback", "web import should call configured callback"),
	])


func test_deck_share_platform_adapter_native_filter_includes_android_image_mime_types() -> String:
	var filters: PackedStringArray = DeckSharePlatformAdapterScript._native_image_filters_for_tests()
	var joined := "\n".join(filters)
	return run_checks([
		assert_str_contains(joined, "*.png", "native picker should include PNG extension"),
		assert_str_contains(joined, "image/png", "native picker should include PNG MIME"),
		assert_str_contains(joined, "image/jpeg", "native picker should include JPEG MIME"),
		assert_str_contains(joined, "image/webp", "native picker should include WebP MIME"),
	])


func test_deck_share_platform_adapter_native_save_filter_includes_png_mime_type() -> String:
	var filters: PackedStringArray = DeckSharePlatformAdapterScript._native_save_filters_for_tests()
	var joined := "\n".join(filters)
	return run_checks([
		assert_str_contains(joined, "*.png", "native save should include PNG extension"),
		assert_str_contains(joined, "image/png", "native save should include PNG MIME"),
	])


func test_deck_share_platform_adapter_uses_native_save_dialog_on_supported_native_platforms() -> String:
	return run_checks([
		assert_true(DeckSharePlatformAdapterScript._should_use_native_save_dialog_for_tests("Android", true), "Android native file dialogs should use save dialog"),
		assert_true(DeckSharePlatformAdapterScript._should_use_native_save_dialog_for_tests("ios", true), "iOS native file dialogs should use save dialog"),
		assert_true(DeckSharePlatformAdapterScript._should_use_native_save_dialog_for_tests("Windows", true), "Windows should use the system save dialog"),
		assert_true(DeckSharePlatformAdapterScript._should_use_native_save_dialog_for_tests("macOS", true), "macOS should use the system save dialog"),
		assert_true(DeckSharePlatformAdapterScript._should_use_native_save_dialog_for_tests("X11", true), "Linux X11 should use the system save dialog"),
		assert_true(DeckSharePlatformAdapterScript._should_use_native_save_dialog_for_tests("Wayland", true), "Linux Wayland should use the system save dialog"),
		assert_false(DeckSharePlatformAdapterScript._should_use_native_save_dialog_for_tests("Web", true), "Web should use its browser save flow"),
		assert_false(DeckSharePlatformAdapterScript._should_use_native_save_dialog_for_tests("headless", true), "Headless tests should not open a save dialog"),
		assert_false(DeckSharePlatformAdapterScript._should_use_native_save_dialog_for_tests("Android", false), "Android without native file dialog should fall back"),
	])


func test_deck_share_platform_adapter_native_save_callback_writes_png() -> String:
	var adapter := DeckSharePlatformAdapterScript.new()
	var image := Image.create(18, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.4, 0.5, 0.6, 1.0))
	var path := "user://deck_share_native_save_callback.png"
	adapter.set("_pending_native_save_bytes", image.save_png_to_buffer())
	var saved_paths: Array[String] = []
	var failures: Array[String] = []
	adapter.image_saved.connect(func(saved_path: String) -> void:
		saved_paths.append(saved_path)
	)
	adapter.image_save_failed.connect(func(message: String) -> void:
		failures.append(message)
	)
	adapter.call("_on_native_save_dialog_selected", true, PackedStringArray([path]), 0)
	var loaded := Image.new()
	var load_err := loaded.load(path)
	adapter.free()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return run_checks([
		assert_eq(failures.size(), 0, "native save callback should not emit failure"),
		assert_eq(saved_paths.size(), 1, "native save callback should emit one saved path"),
		assert_eq(saved_paths[0] if saved_paths.size() > 0 else "", path, "native save callback saved path"),
		assert_eq(load_err, OK, "native saved PNG should load"),
		assert_eq(loaded.get_size(), Vector2i(18, 12), "native saved PNG size"),
	])


func test_deck_share_platform_adapter_web_save_callback_reports_selected_path() -> String:
	var adapter := DeckSharePlatformAdapterScript.new()
	var saved_paths: Array[String] = []
	var failures: Array[String] = []
	adapter.image_saved.connect(func(path: String) -> void:
		saved_paths.append(path)
	)
	adapter.image_save_failed.connect(func(message: String) -> void:
		failures.append(message)
	)
	adapter.call("_on_web_image_save_event", [JSON.stringify({
		"ok": true,
		"path": "browser-save:deck.png",
		"method": "file-picker",
	})])
	adapter.free()
	return run_checks([
		assert_eq(failures.size(), 0, "successful browser save should not emit failure"),
		assert_eq(saved_paths.size(), 1, "successful browser save should emit one path"),
		assert_eq(saved_paths[0] if saved_paths.size() > 0 else "", "browser-save:deck.png", "browser save callback path"),
	])


func test_deck_share_platform_adapter_web_save_callback_reports_cancel() -> String:
	var adapter := DeckSharePlatformAdapterScript.new()
	var failures: Array[String] = []
	adapter.image_save_failed.connect(func(message: String) -> void:
		failures.append(message)
	)
	adapter.call("_on_web_image_save_event", [JSON.stringify({
		"ok": false,
		"canceled": true,
		"error": "已取消保存卡组图。",
	})])
	adapter.free()
	return run_checks([
		assert_eq(failures.size(), 1, "canceling the browser picker should emit one failure"),
		assert_str_contains(failures[0] if failures.size() > 0 else "", "取消", "browser cancel message should be clear"),
	])


func test_deck_share_platform_adapter_web_callback_decodes_base64() -> String:
	var adapter := DeckSharePlatformAdapterScript.new()
	var captured: Array = []
	adapter.image_picked.connect(func(bytes: PackedByteArray, source_name: String) -> void:
		captured.append({"bytes": bytes, "source_name": source_name})
	)
	var raw := PackedByteArray([1, 2, 3, 4])
	adapter.call("_on_web_image_pick_event", [JSON.stringify({
		"ok": true,
		"name": "share.png",
		"base64": Marshalls.raw_to_base64(raw),
	})])
	var picked: Dictionary = captured[0] if captured.size() > 0 else {}
	var bytes: PackedByteArray = picked.get("bytes", PackedByteArray())
	adapter.free()
	return run_checks([
		assert_eq(captured.size(), 1, "callback should emit one image"),
		assert_eq(str(picked.get("source_name", "")), "share.png", "callback source name"),
		assert_eq(bytes.size(), 4, "callback byte count"),
		assert_eq(int(bytes[2]) if bytes.size() > 2 else -1, 3, "callback byte content"),
	])
