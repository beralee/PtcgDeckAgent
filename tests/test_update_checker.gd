class_name TestUpdateChecker
extends TestBase

const UpdateCheckerPath := "res://scripts/network/UpdateChecker.gd"
const FeedbackClientPath := "res://scripts/network/FeedbackClient.gd"
const UserVisitClientPath := "res://scripts/network/UserVisitClient.gd"
const AppVersionPath := "res://scripts/app/AppVersion.gd"
const STATE_PATH := "user://update_check_state.json"


func _new_checker() -> Dictionary:
	var script := load(UpdateCheckerPath)
	if script == null or not script.can_instantiate():
		return {"ok": false, "error": "UpdateChecker should load and instantiate"}
	return {"ok": true, "value": script.new()}


func _remove_state_file() -> void:
	var absolute_path := ProjectSettings.globalize_path(STATE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func test_update_checker_and_app_version_scripts_load() -> String:
	var update_script := load(UpdateCheckerPath)
	var feedback_script := load(FeedbackClientPath)
	var user_visit_script := load(UserVisitClientPath)
	var app_version_script := load(AppVersionPath)
	var update_instance = update_script.new() if update_script != null and update_script.can_instantiate() else null
	var feedback_instance = feedback_script.new() if feedback_script != null and feedback_script.can_instantiate() else null
	var user_visit_instance = user_visit_script.new() if user_visit_script != null and user_visit_script.can_instantiate() else null
	var visit_payload: Dictionary = user_visit_script.build_payload({
		"visit_id": "visit-test",
		"client_id": "client-test",
		"source": "unit_test",
	}) if user_visit_script != null else {}
	var checks := run_checks([
		assert_not_null(update_script, "UpdateChecker.gd should load"),
		assert_not_null(feedback_script, "FeedbackClient.gd should load"),
		assert_not_null(user_visit_script, "UserVisitClient.gd should load"),
		assert_not_null(app_version_script, "AppVersion.gd should load"),
		assert_not_null(update_instance, "UpdateChecker.gd should instantiate"),
		assert_not_null(feedback_instance, "FeedbackClient.gd should instantiate"),
		assert_not_null(user_visit_instance, "UserVisitClient.gd should instantiate"),
		assert_eq(str(app_version_script.VERSION), "0.2.1", "AppVersion should expose the current version"),
		assert_eq(str(app_version_script.DISPLAY_VERSION), "v0.2.1", "AppVersion should expose display version"),
		assert_eq(str(feedback_script.ENDPOINT_URL), "http://fc.skillserver.cn/ptcg", "Feedback client should use the production cloud function endpoint"),
		assert_eq(str(user_visit_script.ENDPOINT_URL), "http://fc.skillserver.cn/userptcg", "User visit client should use the production cloud function endpoint"),
		assert_eq(str(visit_payload.get("client_id", "")), "client-test", "User visit payload should include a stable client id"),
		assert_eq(str(visit_payload.get("source", "")), "unit_test", "User visit payload should include source metadata"),
		assert_false(visit_payload.has("session_id"), "User visit payload should not include session id"),
		assert_false(visit_payload.has("is_debug_build"), "User visit payload should not include debug build marker"),
	])
	if update_instance != null:
		update_instance.free()
	if feedback_instance != null:
		feedback_instance.free()
	if user_visit_instance != null:
		user_visit_instance.free()
	return checks


func test_main_menu_scene_loads_with_update_ui_dependencies() -> String:
	var scene := load("res://scenes/main_menu/MainMenu.tscn")
	var instance = scene.instantiate() if scene != null and scene.can_instantiate() else null
	var instantiated := instance != null
	if instance != null:
		instance.free()
	return run_checks([
		assert_not_null(scene, "MainMenu scene should load with update checker dependencies"),
		assert_true(instantiated, "MainMenu scene should instantiate with update checker dependencies"),
	])


func test_main_menu_corner_actions_use_image_icons() -> String:
	var scene := load("res://scenes/main_menu/MainMenu.tscn")
	var instance = scene.instantiate() if scene != null and scene.can_instantiate() else null
	if instance == null:
		return "MainMenu scene should instantiate before corner icon buttons can be tested"
	instance.call("_ensure_corner_action_buttons")
	var feedback := instance.get_node_or_null("FeedbackButton") as Button
	var about := instance.get_node_or_null("AboutButton") as Button
	var update := instance.get_node_or_null("ManualUpdateButton") as Button
	instance.call("_show_corner_action_label", feedback)
	var hover_label := instance.get_node_or_null("CornerActionHoverLabel") as PanelContainer
	var hover_text := hover_label.find_child("CornerActionHoverText", true, false) as Label if hover_label != null else null
	var hover_visible := hover_label != null and hover_label.visible
	var hover_display := hover_text.text if hover_text != null else ""
	instance.call("_show_corner_action_label", about)
	var about_hover_display := hover_text.text if hover_text != null else ""
	instance.call("_show_corner_action_label", update)
	var update_hover_display := hover_text.text if hover_text != null else ""
	instance.call("_hide_corner_action_label", update)
	var hover_hidden := hover_label != null and not hover_label.visible
	var checks := run_checks([
		assert_not_null(feedback, "Feedback corner action should exist"),
		assert_not_null(about, "About corner action should exist"),
		assert_not_null(update, "Manual update corner action should exist"),
		assert_true(feedback != null and feedback.icon != null, "Feedback corner action should use a PNG icon"),
		assert_true(about != null and about.icon != null, "About corner action should use a PNG icon"),
		assert_true(update != null and update.icon != null, "Manual update corner action should use a PNG icon"),
		assert_eq(feedback.text if feedback != null else "missing", "", "Feedback corner action should not rely on text glyphs"),
		assert_eq(about.text if about != null else "missing", "", "About corner action should not rely on text glyphs"),
		assert_eq(update.text if update != null else "missing", "", "Manual update corner action should not rely on text glyphs"),
		assert_gte(feedback.custom_minimum_size.x if feedback != null else 0.0, 58.0, "Corner actions should be large enough to notice"),
		assert_true(hover_visible, "Corner action Chinese label should appear immediately on hover"),
		assert_eq(hover_display, "建议反馈", "Feedback hover label should show the Chinese action name"),
		assert_eq(about_hover_display, "关于", "About hover label should show the Chinese action name"),
		assert_eq(update_hover_display, "检查更新", "Manual update hover label should show the Chinese action name"),
		assert_true(hover_hidden, "Corner action Chinese label should hide after hover exits"),
	])
	instance.free()
	return checks


func test_main_menu_feedback_quota_prunes_24_hour_window() -> String:
	var scene := load("res://scenes/main_menu/MainMenu.tscn")
	var instance = scene.instantiate() if scene != null and scene.can_instantiate() else null
	if instance == null:
		return "MainMenu scene should instantiate before feedback quota can be tested"
	var now := 100000
	var day := 24 * 60 * 60
	var pruned: Array = instance.call("_feedback_timestamps_after_prune", [now - 10, now - 120, now - day - 1], now)
	var remaining: int = int(instance.call("_feedback_remaining_for_timestamps", [now - 10, now - 20], now))
	var checks := run_checks([
		assert_eq(pruned.size(), 2, "Feedback quota should ignore timestamps older than 24 hours"),
		assert_eq(remaining, 1, "Two recent submissions should leave one feedback slot"),
	])
	instance.free()
	return checks


func test_main_menu_feedback_dialog_has_name_and_content_fields() -> String:
	var scene := load("res://scenes/main_menu/MainMenu.tscn")
	var instance = scene.instantiate() if scene != null and scene.can_instantiate() else null
	if instance == null:
		return "MainMenu scene should instantiate before feedback dialog can be tested"
	var content := instance.call("_build_feedback_dialog_content") as Control
	var name_input := content.find_child("FeedbackName", true, false) if content != null else null
	var text_input := content.find_child("FeedbackText", true, false) if content != null else null
	var checks := run_checks([
		assert_not_null(name_input, "Feedback dialog should include player name input"),
		assert_not_null(text_input, "Feedback dialog should include feedback content input"),
	])
	if content != null:
		content.free()
	instance.free()
	return checks


func test_main_menu_status_and_about_use_hud_modal_overlay() -> String:
	var scene := load("res://scenes/main_menu/MainMenu.tscn")
	var instance = scene.instantiate() if scene != null and scene.can_instantiate() else null
	if instance == null:
		return "MainMenu scene should instantiate before modal overlay can be tested"
	instance.call("_show_update_status_dialog", "反馈已提交", "反馈已保存到服务器。")
	var status_overlay: Node = instance.get_node_or_null("HudModalOverlay")
	var legacy_status_dialog: Node = instance.get_node_or_null("UpdateStatusDialog")
	instance.call("_hide_hud_modal")
	instance.call("_show_about_dialog")
	var about_overlay: Node = instance.get_node_or_null("HudModalOverlay")
	var legacy_about_dialog: Node = instance.get_node_or_null("AboutDialog")
	var about_body := instance.find_child("HudModalBody", true, false) as RichTextLabel
	var checks := run_checks([
		assert_not_null(status_overlay, "Status messages should use the HUD modal overlay"),
		assert_null(legacy_status_dialog, "Status messages should not create default AcceptDialog"),
		assert_not_null(about_overlay, "About dialog should use the HUD modal overlay"),
		assert_null(legacy_about_dialog, "About dialog should not create default AcceptDialog"),
		assert_not_null(about_body, "About dialog body should use RichTextLabel for clickable links"),
		assert_true(about_body != null and about_body.bbcode_enabled, "About dialog should enable BBCode links"),
		assert_true(about_body != null and "https://ptcg.skillserver.cn/" in about_body.text, "About dialog should include the game homepage URL"),
	])
	instance.free()
	return checks


func test_feedback_client_payload_uses_name_content_and_metadata() -> String:
	var feedback_script := load(FeedbackClientPath)
	if feedback_script == null:
		return "FeedbackClient.gd should load before payload can be tested"
	var payload: Dictionary = feedback_script.build_payload(" 小智 ", " 这里有个 bug ", {
		"app_version": "v9.9.9",
		"platform": "Android",
		"submitted_at": 123,
	})
	return run_checks([
		assert_eq(str(payload.get("name", "")), "小智", "Payload should trim player name"),
		assert_eq(str(payload.get("content", "")), "这里有个 bug", "Payload should trim content"),
		assert_eq(str(payload.get("app_version", "")), "v9.9.9", "Payload should carry app version"),
		assert_eq(str(payload.get("platform", "")), "Android", "Payload should carry platform"),
		assert_eq(int(payload.get("submitted_at", 0)), 123, "Payload should carry submitted timestamp"),
	])


func test_feedback_client_validation_requires_content() -> String:
	var feedback_script := load(FeedbackClientPath)
	if feedback_script == null:
		return "FeedbackClient.gd should load before validation can be tested"
	return run_checks([
		assert_true(str(feedback_script.validate_feedback("玩家", "   ")) != "", "Empty feedback should be rejected"),
		assert_eq(str(feedback_script.validate_feedback("", "希望优化手机操作")), "", "Non-empty feedback should pass validation"),
	])


func test_version_compare_handles_v_prefix_and_patch_numbers() -> String:
	var checker_result: Dictionary = _new_checker()
	if not bool((checker_result as Dictionary).get("ok", false)):
		return str((checker_result as Dictionary).get("error", "checker setup failed"))
	var checker: Object = (checker_result as Dictionary).get("value") as Object
	var checks := run_checks([
		assert_eq(int(checker.call("compare_versions", "v0.2.2", "0.2.1")), 1, "0.2.2 should be newer than 0.2.1"),
		assert_eq(int(checker.call("compare_versions", "0.2.1", "v0.2.1")), 0, "v prefix should not affect equality"),
		assert_eq(int(checker.call("compare_versions", "0.2.10", "0.2.9")), 1, "Patch numbers should compare numerically"),
		assert_eq(int(checker.call("compare_versions", "0.1.9", "0.2.0")), -1, "Older minor version should compare lower"),
	])
	checker.free()
	return checks


func test_auto_check_uses_24_hour_interval() -> String:
	var checker_result: Dictionary = _new_checker()
	if not bool((checker_result as Dictionary).get("ok", false)):
		return str((checker_result as Dictionary).get("error", "checker setup failed"))
	var checker: Object = (checker_result as Dictionary).get("value") as Object
	var update_script := load(UpdateCheckerPath)
	var now: int = int(Time.get_unix_time_from_system())
	var interval: int = int(update_script.CHECK_INTERVAL_SECONDS)
	var checks := run_checks([
		assert_false(bool(checker.call("_should_check_now", {"last_checked_at": now})), "Automatic checks should be throttled within 24 hours"),
		assert_true(bool(checker.call("_should_check_now", {"last_checked_at": now - interval - 1})), "Automatic checks should run after 24 hours"),
		assert_true(bool(checker.call("_should_check_now", {})), "Missing state should allow automatic checks"),
	])
	checker.free()
	return checks


func test_manifest_normalization_keeps_download_page_and_summary() -> String:
	var checker_result: Dictionary = _new_checker()
	if not bool((checker_result as Dictionary).get("ok", false)):
		return str((checker_result as Dictionary).get("error", "checker setup failed"))
	var checker: Object = (checker_result as Dictionary).get("value") as Object
	var info: Dictionary = checker.call("normalize_manifest", {
		"schema_version": 1,
		"latest_version": "v0.2.2",
		"release_date": "2026-05-03",
		"title": "0.2.2 更新",
		"summary": ["修复问题", "优化体验"],
		"download_page_url": "https://ptcg.skillserver.cn/",
	})
	var checks := run_checks([
		assert_eq(str(info.get("latest_version", "")), "0.2.2", "Manifest version should be normalized"),
		assert_eq(str(info.get("display_version", "")), "v0.2.2", "Manifest display version should include v prefix"),
		assert_eq(str(info.get("download_page_url", "")), "https://ptcg.skillserver.cn/", "Download page should be preserved"),
		assert_eq((info.get("summary", []) as PackedStringArray).size(), 2, "Summary should keep update bullet count"),
	])
	checker.free()
	return checks


func test_update_available_uses_current_version() -> String:
	var checker_result: Dictionary = _new_checker()
	if not bool((checker_result as Dictionary).get("ok", false)):
		return str((checker_result as Dictionary).get("error", "checker setup failed"))
	var checker: Object = (checker_result as Dictionary).get("value") as Object
	var checks := run_checks([
		assert_true(bool(checker.call("is_update_available", {"latest_version": "0.2.2"})), "0.2.2 should be available over current 0.2.1"),
		assert_false(bool(checker.call("is_update_available", {"latest_version": "0.2.1"})), "Current version should not be treated as an update"),
	])
	checker.free()
	return checks


func test_ignore_version_persists_normalized_version() -> String:
	_remove_state_file()
	var checker_result: Dictionary = _new_checker()
	if not bool((checker_result as Dictionary).get("ok", false)):
		return str((checker_result as Dictionary).get("error", "checker setup failed"))
	var checker: Object = (checker_result as Dictionary).get("value") as Object
	checker.call("ignore_version", "v0.2.2")
	var state: Dictionary = checker.call("_load_state")
	var result: String = assert_eq(str(state.get("ignored_version", "")), "0.2.2", "Ignored version should be normalized before persisting")
	checker.free()
	_remove_state_file()
	return result
