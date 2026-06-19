class_name TestGameManager
extends TestBase

const GameManagerPath := "res://scripts/autoload/GameManager.gd"
const CONFIG_PATH := "user://battle_review_api.json"
const BATTLE_SETUP_SETTINGS_PATH := "user://battle_setup.json"
const NON_BATTLE_LAYOUT_SETTINGS_PATH := "user://non_battle_layout.json"


func _load_game_manager_script() -> GDScript:
	return load(GameManagerPath)


func _remove_config_file() -> void:
	var absolute_path := ProjectSettings.globalize_path(CONFIG_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _read_config_text() -> String:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _write_config(payload: Dictionary) -> bool:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func _restore_config_text(original_text: String) -> void:
	if original_text == "":
		_remove_config_file()
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(original_text)
	file.close()


func _read_battle_setup_settings_text() -> String:
	var file := FileAccess.open(BATTLE_SETUP_SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _write_battle_setup_settings(payload: Dictionary) -> bool:
	var file := FileAccess.open(BATTLE_SETUP_SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func _remove_battle_setup_settings_file() -> void:
	var absolute_path := ProjectSettings.globalize_path(BATTLE_SETUP_SETTINGS_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _restore_battle_setup_settings_text(original_text: String) -> void:
	if original_text == "":
		_remove_battle_setup_settings_file()
		return
	var file := FileAccess.open(BATTLE_SETUP_SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(original_text)
	file.close()


func _read_non_battle_layout_settings_text() -> String:
	var file := FileAccess.open(NON_BATTLE_LAYOUT_SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _remove_non_battle_layout_settings_file() -> void:
	var absolute_path := ProjectSettings.globalize_path(NON_BATTLE_LAYOUT_SETTINGS_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _restore_non_battle_layout_settings_text(original_text: String) -> void:
	if original_text == "":
		_remove_non_battle_layout_settings_file()
		return
	var file := FileAccess.open(NON_BATTLE_LAYOUT_SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(original_text)
	file.close()


func test_battle_review_api_config_uses_defaults_when_file_is_missing() -> String:
	var original_config_text := _read_config_text()
	_remove_config_file()
	var manager: Node = _load_game_manager_script().new()
	var config: Dictionary = manager.call("get_battle_review_api_config")
	_restore_config_text(original_config_text)

	return run_checks([
		assert_eq(str(manager.call("get_battle_review_api_config_path")), CONFIG_PATH, "GameManager should expose the fixed user:// config path"),
		assert_eq(str(config.get("endpoint", "")), "https://zenmux.ai/api/v1", "missing config file should keep default endpoint"),
		assert_eq(str(config.get("api_key", "")), "", "missing config file should keep default api_key"),
		assert_eq(str(config.get("model", "")), "deepseek-v4-flash", "missing config file should keep default no-reasoning model"),
		assert_eq(float(config.get("timeout_seconds", 0.0)), 60.0, "missing config file should keep default timeout"),
		assert_eq(str(config.get("ai_personality", "")), "是一个大逗比，臭牌篓子", "missing config file should use default AI personality"),
	])


func test_supported_battle_review_models_match_current_no_reasoning_batch() -> String:
	var manager: Node = _load_game_manager_script().new()
	var models: Array = manager.call("get_supported_battle_review_models")
	var ids := PackedStringArray()
	var labels := {}
	for model_variant in models:
		var model: Dictionary = model_variant
		var model_id := str(model.get("id", ""))
		ids.append(model_id)
		labels[model_id] = str(model.get("label", ""))

	var expected_ids := PackedStringArray([
		"kimi-k2.6",
		"z-ai/glm-5.2",
		"qwen/qwen3.7-plus",
		"qwen/qwen3.7-max",
		"deepseek-v4-flash",
		"deepseek-v4-pro",
		"gpt-5.5",
		"claude-sonnet-4-6",
	])
	return run_checks([
		assert_eq(",".join(ids), ",".join(expected_ids), "Supported battle review models should match the current no-reasoning batch"),
		assert_eq(str(labels.get("z-ai/glm-5.2", "")), "GLM 5.2", "GLM display label should match the current model"),
		assert_eq(str(labels.get("qwen/qwen3.7-plus", "")), "Qwen 3.7 Plus", "Qwen Plus display label should match the current model"),
		assert_eq(str(labels.get("qwen/qwen3.7-max", "")), "Qwen 3.7 Max", "Qwen Max display label should match the current model"),
		assert_false(ids.has("deepseek/deepseek-chat"), "Legacy DeepSeek chat should not be selectable"),
		assert_false(ids.has("x-ai/grok-4.2-fast-non-reasoning"), "Removed Grok model should not be selectable"),
	])


func test_main_menu_navigation_prewarm_excludes_heavy_battle_scene() -> String:
	var manager: Node = _load_game_manager_script().new()
	var checks: Array[String] = [
		assert_true(manager.has_method("navigation_prewarm_scene_paths"), "GameManager should expose the main menu prewarm policy for regression coverage"),
		assert_true(manager.has_method("battle_setup_prewarm_scene_path"), "GameManager should expose the deferred BattleSetup prewarm target"),
	]
	if manager.has_method("navigation_prewarm_scene_paths"):
		var paths: Array = manager.call("navigation_prewarm_scene_paths")
		checks.append(assert_true(paths.has("res://scenes/battle_setup/BattleSetup.tscn"), "Main menu prewarm should still cover BattleSetup"))
		checks.append(assert_true(paths.has("res://scenes/deck_manager/DeckManager.tscn"), "Main menu prewarm should still cover DeckManager"))
		checks.append(assert_false(paths.has("res://scenes/battle/BattleScene.tscn"), "Main menu prewarm should not compete with navigation by loading the heavy BattleScene"))
	if manager.has_method("battle_setup_prewarm_scene_path"):
		checks.append(assert_eq(str(manager.call("battle_setup_prewarm_scene_path")), "res://scenes/battle/BattleScene.tscn", "BattleScene should be warmed only after BattleSetup is visible"))
	return run_checks(checks)


func test_scene_navigation_waits_for_in_progress_threaded_prewarm() -> String:
	var manager: Node = _load_game_manager_script().new()
	var checks: Array[String] = [
		assert_true(manager.has_method("should_await_prewarm_status_for_scene_change"), "GameManager should expose in-progress prewarm navigation policy for regression coverage"),
	]
	if manager.has_method("should_await_prewarm_status_for_scene_change"):
		checks.append(assert_true(bool(manager.call("should_await_prewarm_status_for_scene_change", ResourceLoader.THREAD_LOAD_IN_PROGRESS)), "In-progress threaded loads should be awaited instead of falling back to sync scene loading"))
		checks.append(assert_false(bool(manager.call("should_await_prewarm_status_for_scene_change", ResourceLoader.THREAD_LOAD_LOADED)), "Loaded threaded resources are consumed immediately, not awaited"))
		checks.append(assert_false(bool(manager.call("should_await_prewarm_status_for_scene_change", ResourceLoader.THREAD_LOAD_FAILED)), "Failed threaded loads should fall back to normal scene loading"))
		checks.append(assert_false(bool(manager.call("should_await_prewarm_status_for_scene_change", ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)), "Invalid threaded loads should fall back to normal scene loading"))
	return run_checks(checks)


func test_battle_review_api_config_loads_user_file() -> String:
	var original_config_text := _read_config_text()
	_remove_config_file()
	_write_config({
		"endpoint": "https://example.invalid/v1/chat/completions",
		"api_key": "zenmux-key",
		"model": "z-ai/glm-5.2",
		"timeout_seconds": 45,
		"ai_personality": "谨慎但幽默",
	})
	var manager: Node = _load_game_manager_script().new()
	var config: Dictionary = manager.call("get_battle_review_api_config")
	_restore_config_text(original_config_text)

	return run_checks([
		assert_eq(str(config.get("endpoint", "")), "https://example.invalid/v1/chat/completions", "GameManager should load endpoint from user config"),
		assert_eq(str(config.get("api_key", "")), "zenmux-key", "GameManager should load api_key from user config"),
		assert_eq(str(config.get("model", "")), "z-ai/glm-5.2", "GameManager should load supported no-reasoning model from user config"),
		assert_eq(float(config.get("timeout_seconds", 0.0)), 45.0, "GameManager should load timeout_seconds from user config"),
		assert_eq(str(config.get("ai_personality", "")), "谨慎但幽默", "GameManager should load AI personality from user config"),
	])


func test_battle_review_api_config_filters_null_instance_diagnostics() -> String:
	var original_config_text := _read_config_text()
	_remove_config_file()
	_write_config({
		"endpoint": "instance base is null",
		"api_key": "Instance Base Is Null",
		"model": "null instance",
		"timeout_seconds": 45,
		"ai_personality": "instance is null",
		"ai_test_signature": "Instance Base Is Null",
	})
	var manager: Node = _load_game_manager_script().new()
	var config: Dictionary = manager.call("get_battle_review_api_config")
	_restore_config_text(original_config_text)

	return run_checks([
		assert_eq(str(config.get("endpoint", "")), "https://zenmux.ai/api/v1", "Null-instance endpoint diagnostics should fall back to the default endpoint"),
		assert_eq(str(config.get("api_key", "")), "", "Null-instance API key diagnostics should not be shown as a saved key"),
		assert_eq(str(config.get("model", "")), "deepseek-v4-flash", "Null-instance model diagnostics should fall back to the default model"),
		assert_eq(str(config.get("ai_personality", "")), "是一个大逗比，臭牌篓子", "Null-instance personality diagnostics should fall back to the default AI personality"),
		assert_eq(str(config.get("ai_test_signature", "")), "", "Null-instance test signatures should be discarded"),
	])


func test_battle_review_api_config_migrates_missing_ai_personality() -> String:
	var original_config_text := _read_config_text()
	_remove_config_file()
	_write_config({
		"endpoint": "https://example.invalid/v1",
		"api_key": "old-key",
		"model": "qwen/qwen3.7-plus",
		"timeout_seconds": 30,
	})
	var manager: Node = _load_game_manager_script().new()
	var config: Dictionary = manager.call("get_battle_review_api_config")
	_restore_config_text(original_config_text)

	return run_checks([
		assert_true(config.has("ai_personality"), "Old config files should be upgraded in memory with ai_personality"),
		assert_eq(str(config.get("model", "")), "qwen/qwen3.7-plus", "Current Qwen Plus should remain selectable while migrating old config files"),
		assert_eq(str(config.get("ai_personality", "")), "是一个大逗比，臭牌篓子", "Old config files should use default AI personality when missing"),
	])


func test_battle_review_api_config_restricts_models_to_supported_allowlist() -> String:
	var original_config_text := _read_config_text()
	_remove_config_file()
	_write_config({
		"endpoint": "https://example.invalid/v1",
		"api_key": "old-key",
		"model": "openai/gpt-5.4",
		"timeout_seconds": 30,
	})
	var manager: Node = _load_game_manager_script().new()
	var unsupported_config: Dictionary = manager.call("get_battle_review_api_config")
	_write_config({
		"endpoint": "https://example.invalid/v1",
		"api_key": "old-key",
		"model": "deepseek-v4-flash",
		"timeout_seconds": 30,
	})
	var deepseek_config: Dictionary = manager.call("get_battle_review_api_config")
	_write_config({
		"endpoint": "https://example.invalid/v1",
		"api_key": "old-key",
		"model": "deepseek/deepseek-v4-pro",
		"timeout_seconds": 30,
	})
	var deepseek_pro_config: Dictionary = manager.call("get_battle_review_api_config")
	_write_config({
		"endpoint": "https://example.invalid/v1",
		"api_key": "old-key",
		"model": "z-ai/glm-5.1",
		"timeout_seconds": 30,
	})
	var legacy_glm_config: Dictionary = manager.call("get_battle_review_api_config")
	_write_config({
		"endpoint": "https://example.invalid/v1",
		"api_key": "old-key",
		"model": "qwen/qwen3.6-plus",
		"timeout_seconds": 30,
	})
	var legacy_qwen_config: Dictionary = manager.call("get_battle_review_api_config")
	_write_config({
		"endpoint": "https://example.invalid/v1",
		"api_key": "old-key",
		"model": "x-ai/grok-4.2-fast-non-reasoning",
		"timeout_seconds": 30,
	})
	var removed_grok_config: Dictionary = manager.call("get_battle_review_api_config")
	_restore_config_text(original_config_text)

	return run_checks([
		assert_eq(str(unsupported_config.get("model", "")), "deepseek-v4-flash", "Unsupported models should fall back to the default model"),
		assert_eq(str(deepseek_config.get("model", "")), "deepseek-v4-flash", "DeepSeek V4 Flash should remain selectable as its tested no-thinking slug"),
		assert_eq(str(deepseek_pro_config.get("model", "")), "deepseek-v4-pro", "Provider-prefixed DeepSeek V4 Pro should normalize to the tested no-thinking slug"),
		assert_eq(str(legacy_glm_config.get("model", "")), "z-ai/glm-5.2", "Legacy GLM 5.1 config should migrate to GLM 5.2"),
		assert_eq(str(legacy_qwen_config.get("model", "")), "qwen/qwen3.7-plus", "Legacy Qwen 3.6 Plus config should migrate to Qwen 3.7 Plus"),
		assert_eq(str(removed_grok_config.get("model", "")), "deepseek-v4-flash", "Removed Grok model should fall back to the default model"),
	])


func test_battle_replay_launch_request_is_one_shot() -> String:
	var manager: Node = _load_game_manager_script().new()
	if not manager.has_method("set_battle_replay_launch") or not manager.has_method("consume_battle_replay_launch"):
		return "GameManager should provide replay launch helpers"

	manager.call("set_battle_replay_launch", {
		"match_dir": "user://match_records/match_a",
		"entry_turn_number": 6,
	})
	var launch: Dictionary = manager.call("consume_battle_replay_launch")

	return run_checks([
		assert_eq(str(launch.get("match_dir", "")), "user://match_records/match_a", "Replay launch should preserve match_dir"),
		assert_eq(int(launch.get("entry_turn_number", 0)), 6, "Replay launch should preserve entry turn"),
		assert_true((manager.call("consume_battle_replay_launch") as Dictionary).is_empty(), "Replay launch should be one-shot"),
	])


func test_deck_editor_return_context_is_one_shot() -> String:
	var manager: Node = _load_game_manager_script().new()
	if not manager.has_method("set_deck_editor_return_context") or not manager.has_method("consume_deck_editor_return_context"):
		return "GameManager should provide deck editor return context helpers"

	manager.call("set_deck_editor_return_context", {
		"return_scene": "battle_setup",
		"deck1_id": 101,
		"deck2_id": 202,
	})
	var context: Dictionary = manager.call("consume_deck_editor_return_context")

	return run_checks([
		assert_eq(str(context.get("return_scene", "")), "battle_setup", "Deck editor return context should preserve return scene"),
		assert_eq(int(context.get("deck1_id", 0)), 101, "Deck editor return context should preserve deck1 id"),
		assert_eq(int(context.get("deck2_id", 0)), 202, "Deck editor return context should preserve deck2 id"),
		assert_true((manager.call("consume_deck_editor_return_context") as Dictionary).is_empty(), "Deck editor return context should be one-shot"),
	])


func test_duplicate_scene_navigation_requests_are_coalesced_before_deferred_change() -> String:
	var manager: Node = _load_game_manager_script().new()
	var first_queued := bool(manager.call("_queue_scene_change", GameManager.SCENE_DECK_EDITOR))
	var first_token := int(manager.get("_pending_scene_change_token"))
	var second_queued := bool(manager.call("_queue_scene_change", GameManager.SCENE_DECK_EDITOR))
	var second_token := int(manager.get("_pending_scene_change_token"))
	var pending_after_duplicate := str(manager.get("_pending_scene_change_path"))
	var replacement_queued := bool(manager.call("_queue_scene_change", GameManager.SCENE_MAIN_MENU))
	var replacement_token := int(manager.get("_pending_scene_change_token"))
	var pending_after_replacement := str(manager.get("_pending_scene_change_path"))

	return run_checks([
		assert_true(first_queued, "First DeckEditor navigation request should be queued"),
		assert_false(second_queued, "Duplicate same-frame DeckEditor navigation should not queue a second deferred scene change"),
		assert_eq(second_token, first_token, "Duplicate DeckEditor navigation should not advance the pending scene token"),
		assert_eq(pending_after_duplicate, GameManager.SCENE_DECK_EDITOR, "Duplicate navigation should keep the original pending DeckEditor path"),
		assert_true(replacement_queued, "A different scene request should replace the pending request"),
		assert_true(replacement_token > first_token, "Replacement scene request should advance the pending scene token"),
		assert_eq(pending_after_replacement, GameManager.SCENE_MAIN_MENU, "Replacement navigation should update the pending path"),
	])


func test_desktop_window_size_preserves_windows_target_and_fits_small_screens() -> String:
	var manager: Node = _load_game_manager_script().new()
	var normal_size: Vector2i = manager.call("_fit_desktop_window_size", Vector2i(1600, 900), Vector2i(1920, 1080))
	var small_size: Vector2i = manager.call("_fit_desktop_window_size", Vector2i(1600, 900), Vector2i(1366, 768))
	var centered: Vector2i = manager.call("_center_desktop_window_position", Vector2i(1600, 900), Rect2i(Vector2i(0, 0), Vector2i(1920, 1080)))

	return run_checks([
		assert_eq(normal_size, Vector2i(1600, 900), "Large screens should keep the Windows-sized 1600x900 window"),
		assert_eq(small_size, Vector2i(1280, 720), "Small desktop screens should get the largest fitting 16:9 window"),
		assert_eq(centered, Vector2i(160, 90), "Desktop window should be centered in the usable screen area"),
	])


func test_desktop_window_startup_uses_large_windowed_macos_size_without_maximize() -> String:
	var manager: Node = _load_game_manager_script().new()

	return run_checks([
		assert_false(bool(manager.call("_should_maximize_desktop_window", "macOS")), "macOS builds should stay windowed instead of entering maximized mode"),
		assert_false(bool(manager.call("_should_maximize_desktop_window", "OSX")), "Older macOS platform name should also stay windowed"),
		assert_true(bool(manager.call("_should_use_large_windowed_desktop_launch", "macOS")), "macOS builds should use a large windowed launch size"),
		assert_true(bool(manager.call("_should_use_large_windowed_desktop_launch", "OSX")), "Older macOS platform name should use a large windowed launch size"),
		assert_false(bool(manager.call("_should_maximize_desktop_window", "Windows")), "Windows should keep the configured 1600x900 startup size"),
		assert_false(bool(manager.call("_should_maximize_desktop_window", "Linux")), "Linux should keep the configured 1600x900 startup size"),
	])


func test_desktop_window_resize_preserves_user_expanded_modes() -> String:
	var manager: Node = _load_game_manager_script().new()

	return run_checks([
		assert_false(bool(manager.call("_should_preserve_user_desktop_window_mode", DisplayServer.WINDOW_MODE_WINDOWED)), "Configured desktop sizing should still apply to regular windowed mode"),
		assert_true(bool(manager.call("_should_preserve_user_desktop_window_mode", DisplayServer.WINDOW_MODE_MAXIMIZED)), "Windows title-bar maximize should survive non-battle page changes"),
		assert_true(bool(manager.call("_should_preserve_user_desktop_window_mode", DisplayServer.WINDOW_MODE_FULLSCREEN)), "Fullscreen should survive non-battle page changes"),
		assert_true(bool(manager.call("_should_preserve_user_desktop_window_mode", DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)), "Exclusive fullscreen should survive non-battle page changes"),
	])


func test_navigation_does_not_apply_battle_orientation_before_battle_scene_loads() -> String:
	var manager: Node = _load_game_manager_script().new()
	var left_mouse := InputEventMouseButton.new()
	left_mouse.button_index = MOUSE_BUTTON_LEFT
	var right_mouse := InputEventMouseButton.new()
	right_mouse.button_index = MOUSE_BUTTON_RIGHT

	return run_checks([
		assert_false(bool(manager.call("_should_apply_non_battle_orientation_before_scene_change", GameManager.SCENE_BATTLE)), "Entering battle should not rotate the current setup scene before the scene change"),
		assert_true(bool(manager.call("_should_apply_non_battle_orientation_before_scene_change", GameManager.SCENE_BATTLE_SETUP)), "Leaving battle should restore non-battle orientation before showing setup"),
		assert_false(bool(manager.call("_should_apply_non_battle_orientation_before_scene_change", GameManager.SCENE_DECK_EDITOR)), "Deck editor should keep its dedicated navigation orientation path instead of the generic non-battle policy"),
		assert_true(bool(manager.call("_touch_mouse_emulation_enabled_for_scene", GameManager.SCENE_BATTLE)), "Battle should keep Godot touch-to-mouse emulation enabled so existing battle gui_input controls receive Android taps"),
		assert_true(bool(manager.call("_touch_mouse_emulation_enabled_for_scene", GameManager.SCENE_BATTLE_SETUP)), "Scene navigation may allow non-battle mouse emulation before mobile orientation policy is applied"),
		assert_true(bool(manager.call("_touch_mouse_emulation_enabled_for_scene", GameManager.SCENE_DECK_EDITOR)), "Deck editor should keep scene-load touch compatibility until non-battle runtime policy is applied"),
		assert_false(bool(manager.call("_non_battle_touch_mouse_emulation_enabled_for_runtime", "Android", {})), "Android non-battle pages should use ScreenTouch button bridging instead of touch-to-mouse emulation"),
		assert_false(bool(manager.call("_non_battle_touch_mouse_emulation_enabled_for_runtime", "iOS", {})), "iPhone non-battle pages should use ScreenTouch button bridging instead of touch-to-mouse emulation"),
		assert_false(bool(manager.call("_non_battle_touch_mouse_emulation_enabled_for_runtime", "Web", {"web_android": true})), "Mobile browser non-battle pages should use ScreenTouch button bridging"),
		assert_true(bool(manager.call("_non_battle_touch_mouse_emulation_enabled_for_runtime", "Windows", {})), "Desktop non-battle pages should keep regular mouse behavior"),
		assert_true(bool(manager.call("_should_bridge_mouse_button_touch_echo", left_mouse, "Android", {})), "Android mouse-button tap echoes should still activate the global Button bridge"),
		assert_false(bool(manager.call("_should_bridge_mouse_button_touch_echo", left_mouse, "Windows", {})), "Desktop mouse clicks should stay on regular Button handling"),
		assert_false(bool(manager.call("_should_bridge_mouse_button_touch_echo", right_mouse, "Android", {})), "Only left-button touch echoes should be bridged on Android"),
	])


func test_deck_editor_mobile_navigation_uses_dedicated_landscape_path() -> String:
	var manager: Node = _load_game_manager_script().new()
	manager.set("non_battle_layout_mode", GameManager.NON_BATTLE_LAYOUT_PORTRAIT)

	return run_checks([
		assert_eq(int(manager.call("non_battle_handheld_orientation_for_scene", GameManager.SCENE_DECK_MANAGER)), DisplayServer.SCREEN_SENSOR_PORTRAIT, "Ordinary non-battle pages should still honor the saved portrait preference"),
		assert_eq(int(manager.call("non_battle_handheld_orientation_for_scene", GameManager.SCENE_DECK_EDITOR)), DisplayServer.SCREEN_SENSOR_LANDSCAPE, "DeckEditor should keep the original dedicated landscape editor path on phones"),
		assert_true(bool(manager.call("_should_apply_deck_editor_orientation_before_scene_change", GameManager.SCENE_DECK_EDITOR)), "DeckEditor orientation should be applied by GameManager before changing scenes, not during DeckEditor _ready"),
		assert_false(bool(manager.call("_should_apply_deck_editor_orientation_before_scene_change", GameManager.SCENE_DECK_MANAGER)), "Other non-battle pages should not use the DeckEditor orientation path"),
	])


func test_web_runtime_skips_native_orientation_calls() -> String:
	var manager: Node = _load_game_manager_script().new()

	return run_checks([
		assert_true(bool(manager.call("_is_web_runtime", "Web", {}, "web")), "Godot Web builds should be detected as browser runtimes"),
		assert_true(bool(manager.call("_is_web_runtime", "", {"web_android": true}, "")), "Android mobile browser feature flags should count as Web runtime"),
		assert_true(bool(manager.call("_is_web_runtime", "", {"web_ios": true}, "")), "iOS mobile browser feature flags should count as Web runtime"),
		assert_false(bool(manager.call("_is_web_runtime", "Android", {"android": true}, "")), "Native Android export should not be treated as Web"),
		assert_true(bool(manager.call("_should_apply_native_screen_orientation", "Android", {"android": true}, "")), "Native Android should still use DisplayServer orientation APIs"),
		assert_true(bool(manager.call("_should_apply_native_screen_orientation", "iOS", {"ios": true}, "")), "Native iOS should still use DisplayServer orientation APIs"),
		assert_false(bool(manager.call("_should_apply_native_screen_orientation", "Web", {"web_android": true}, "web")), "Android browser should not call native DisplayServer orientation APIs"),
		assert_false(bool(manager.call("_should_apply_native_screen_orientation", "Web", {"web_ios": true}, "web")), "iOS browser should not call native DisplayServer orientation APIs"),
		assert_false(bool(manager.call("_should_apply_deck_editor_orientation_before_scene_change", GameManager.SCENE_DECK_EDITOR, "Web", {"web_android": true}, "web")), "Web DeckEditor navigation should not pre-apply the native landscape orientation path"),
		assert_true(bool(manager.call("_should_apply_deck_editor_orientation_before_scene_change", GameManager.SCENE_DECK_EDITOR, "Android", {"android": true}, "")), "Native Android DeckEditor navigation should keep the dedicated landscape path"),
	])


func test_android_screen_touch_bridge_keeps_battle_buttons_clickable_without_mouse_emulation() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var manager: Node = _load_game_manager_script().new()
	manager.name = "GameManagerTouchBridgeProbe"
	var battle_root := Control.new()
	battle_root.name = "BattleScene"
	battle_root.size = Vector2(480, 860)
	var button := Button.new()
	button.name = "BattleTouchButton"
	button.position = Vector2(120, 240)
	button.size = Vector2(220, 90)
	battle_root.add_child(button)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		manager.queue_free()
		battle_root.queue_free()
		ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
		return "SceneTree root should be available for the battle button touch bridge test"
	tree.root.add_child(manager)
	tree.root.add_child(battle_root)
	var pressed := [false]
	button.pressed.connect(func() -> void:
		pressed[0] = true
	)
	var center := button.get_global_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = center
	manager.call("_input", press)
	var candidate_recorded: bool = manager.get("_touch_button_bridge_candidate") == button
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = center
	manager.call("_input", release)
	manager.queue_free()
	battle_root.queue_free()
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)

	return run_checks([
		assert_true(candidate_recorded, "Global touch bridge should remember a pressed battle Button when touch-to-mouse is disabled"),
		assert_true(bool(pressed[0]), "Battle Buttons should still activate from Android ScreenTouch without changing battle scene code"),
	])


func test_android_screen_touch_bridge_keeps_non_battle_buttons_clickable_with_mouse_emulation() -> String:
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", true)
	var manager: Node = _load_game_manager_script().new()
	manager.name = "GameManagerNonBattleTouchBridgeProbe"
	var page_root := Control.new()
	page_root.name = "Settings"
	page_root.size = Vector2(480, 860)
	var button := Button.new()
	button.name = "SettingsBackButton"
	button.position = Vector2(120, 640)
	button.size = Vector2(220, 90)
	page_root.add_child(button)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		manager.queue_free()
		page_root.queue_free()
		ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
		return "SceneTree root should be available for the non-battle button touch bridge test"
	tree.root.add_child(manager)
	tree.root.add_child(page_root)
	var pressed := [false]
	button.pressed.connect(func() -> void:
		pressed[0] = true
	)
	var center := button.get_global_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = center
	manager.call("_input", press)
	var candidate_recorded: bool = manager.get("_touch_button_bridge_candidate") == button
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = center
	manager.call("_input", release)
	manager.queue_free()
	page_root.queue_free()
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)

	return run_checks([
		assert_true(candidate_recorded, "Global touch bridge should remember a non-battle Button even when touch-to-mouse emulation is enabled"),
		assert_true(bool(pressed[0]), "Non-battle Buttons should activate from Android ScreenTouch instead of relying only on mouse emulation"),
	])


func test_global_touch_bridge_suppresses_button_already_handled_by_scene_bridge() -> String:
	var manager: Node = _load_game_manager_script().new()
	manager.name = "GameManagerDuplicateTouchBridgeProbe"
	var page_root := Control.new()
	page_root.name = "BattleSetup"
	page_root.size = Vector2(1080, 2400)
	var button := Button.new()
	button.name = "ModeAIButton"
	button.position = Vector2(120, 240)
	button.size = Vector2(520, 150)
	page_root.add_child(button)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		manager.queue_free()
		page_root.queue_free()
		return "SceneTree root should be available for duplicate touch bridge suppression test"
	tree.root.add_child(manager)
	tree.root.add_child(page_root)
	var pressed := [false]
	button.pressed.connect(func() -> void:
		pressed[0] = true
	)
	var center := button.get_global_rect().get_center()
	manager.call("_handle_touch_button_bridge_at_position", center, true)
	button.set_meta("_non_battle_last_bridge_press_msec", Time.get_ticks_msec())
	manager.call("_handle_touch_button_bridge_at_position", center, false)
	manager.queue_free()
	page_root.queue_free()

	return run_checks([
		assert_false(bool(pressed[0]), "Global touch bridge should not re-emit a Button already handled by the scene-level non-battle touch bridge"),
	])


func test_mobile_first_run_non_battle_layout_defaults_to_portrait() -> String:
	var manager: Node = _load_game_manager_script().new()
	var android_default := str(manager.call("default_non_battle_layout_mode_for_first_run", "Android", {}, "", Vector2(390, 844), ""))
	var iphone_default := str(manager.call("default_non_battle_layout_mode_for_first_run", "iOS", {}, "", Vector2(390, 844), ""))
	var mobile_web_default := str(manager.call("default_non_battle_layout_mode_for_first_run", "Web", {"web": true}, "web", Vector2(390, 844), "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Mobile/15E148"))
	var desktop_default := str(manager.call("default_non_battle_layout_mode_for_first_run", "Windows", {}, "windows", Vector2(1600, 900), ""))

	return run_checks([
		assert_eq(android_default, GameManager.NON_BATTLE_LAYOUT_PORTRAIT, "Android first-run non-battle pages should default to portrait"),
		assert_eq(iphone_default, GameManager.NON_BATTLE_LAYOUT_PORTRAIT, "iPhone first-run non-battle pages should default to portrait"),
		assert_eq(mobile_web_default, GameManager.NON_BATTLE_LAYOUT_PORTRAIT, "Mobile browser first-run non-battle pages should default to portrait"),
		assert_eq(desktop_default, GameManager.NON_BATTLE_LAYOUT_LANDSCAPE, "Desktop first-run non-battle pages should stay landscape"),
	])


func test_resolve_selected_battle_deck_prefers_ai_deck_for_vs_ai_slot() -> String:
	var test_deck_id := 990001
	var previous_ids := GameManager.selected_deck_ids.duplicate()
	var previous_mode := GameManager.current_mode

	var normal_deck := DeckData.new()
	normal_deck.id = test_deck_id
	normal_deck.deck_name = "Normal Deck"
	normal_deck.total_cards = 60

	var ai_deck := DeckData.new()
	ai_deck.id = test_deck_id
	ai_deck.deck_name = "AI Deck"
	ai_deck.total_cards = 60

	CardDatabase.save_deck(normal_deck)
	CardDatabase.save_ai_deck(ai_deck)
	GameManager.selected_deck_ids = [123, test_deck_id]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var resolved := GameManager.resolve_selected_battle_deck(1)
	GameManager.selected_deck_ids = previous_ids.duplicate()
	GameManager.current_mode = previous_mode
	CardDatabase.delete_deck(test_deck_id)
	CardDatabase.delete_ai_deck(test_deck_id)

	return run_checks([
		assert_not_null(resolved, "GameManager should resolve a deck for the AI slot"),
		assert_eq(str(resolved.deck_name if resolved != null else ""), "AI Deck", "VS_AI should resolve player 2 from the dedicated AI deck cache"),
	])


func test_battle_audio_preferences_default_to_20_when_settings_file_is_missing() -> String:
	var original_settings_text := _read_battle_setup_settings_text()
	_remove_battle_setup_settings_file()
	var manager: Node = _load_game_manager_script().new()
	manager.call("load_battle_setup_preferences")
	var selected_track := str(manager.get("selected_battle_music_id"))
	var volume := int(manager.get("battle_bgm_volume_percent"))
	_restore_battle_setup_settings_text(original_settings_text)

	return run_checks([
		assert_eq(selected_track, "none", "Missing battle setup settings should keep the default track"),
		assert_eq(volume, 20, "Missing battle setup settings should default battle BGM volume to 20"),
	])


func test_battle_audio_preferences_load_saved_bgm_settings() -> String:
	var original_settings_text := _read_battle_setup_settings_text()
	_remove_battle_setup_settings_file()
	_write_battle_setup_settings({
		"battle_music_id": "pokemon_sv_battle_gym_leader",
		"battle_bgm_volume_percent": 37,
	})
	var manager: Node = _load_game_manager_script().new()
	manager.call("load_battle_setup_preferences")
	var selected_track := str(manager.get("selected_battle_music_id"))
	var volume := int(manager.get("battle_bgm_volume_percent"))
	_restore_battle_setup_settings_text(original_settings_text)

	return run_checks([
		assert_eq(selected_track, "pokemon_sv_battle_gym_leader", "GameManager should load the saved battle music id on startup"),
		assert_eq(volume, 37, "GameManager should load the saved battle BGM volume on startup"),
	])


func test_battle_audio_preferences_migrate_legacy_default_100_to_20() -> String:
	var original_settings_text := _read_battle_setup_settings_text()
	_remove_battle_setup_settings_file()
	_write_battle_setup_settings({
		"battle_music_id": "pokemon_sv_battle_gym_leader",
		"battle_bgm_volume_percent": 100,
	})
	var manager: Node = _load_game_manager_script().new()
	manager.call("load_battle_setup_preferences")
	var volume := int(manager.get("battle_bgm_volume_percent"))
	_restore_battle_setup_settings_text(original_settings_text)

	return run_checks([
		assert_eq(volume, 20, "Legacy saved battle BGM volume 100 without an explicit user-set marker should migrate to the 20 default"),
	])


func test_battle_audio_preferences_keep_explicit_user_set_100() -> String:
	var original_settings_text := _read_battle_setup_settings_text()
	_remove_battle_setup_settings_file()
	_write_battle_setup_settings({
		"battle_music_id": "pokemon_sv_battle_gym_leader",
		"battle_bgm_volume_percent": 100,
		"battle_bgm_volume_user_set": true,
	})
	var manager: Node = _load_game_manager_script().new()
	manager.call("load_battle_setup_preferences")
	var volume := int(manager.get("battle_bgm_volume_percent"))
	_restore_battle_setup_settings_text(original_settings_text)

	return run_checks([
		assert_eq(volume, 100, "Explicitly user-set battle BGM volume 100 should remain available"),
	])


func test_non_battle_layout_preference_is_separate_from_battle_layout() -> String:
	var original_battle_settings_text := _read_battle_setup_settings_text()
	var original_non_battle_settings_text := _read_non_battle_layout_settings_text()
	_remove_battle_setup_settings_file()
	_remove_non_battle_layout_settings_file()
	_write_battle_setup_settings({
		"battle_layout_mode": GameManager.BATTLE_LAYOUT_PORTRAIT,
	})
	var manager: Node = _load_game_manager_script().new()
	manager.call("load_battle_setup_preferences")
	manager.call("load_non_battle_layout_preferences")
	var battle_layout_before := str(manager.get("battle_layout_mode"))
	var non_battle_before := str(manager.get("non_battle_layout_mode"))
	var non_battle_orientation_before := int(manager.call("non_battle_handheld_orientation"))
	manager.call("set_non_battle_layout_mode", GameManager.NON_BATTLE_LAYOUT_PORTRAIT, true, false)
	var battle_layout_after := str(manager.get("battle_layout_mode"))
	var non_battle_after := str(manager.get("non_battle_layout_mode"))
	var non_battle_orientation_after := int(manager.call("non_battle_handheld_orientation"))
	var saved_text := _read_non_battle_layout_settings_text()
	_restore_battle_setup_settings_text(original_battle_settings_text)
	_restore_non_battle_layout_settings_text(original_non_battle_settings_text)

	return run_checks([
		assert_eq(battle_layout_before, GameManager.BATTLE_LAYOUT_PORTRAIT, "Battle setup preference should still load the battle layout mode"),
		assert_eq(non_battle_before, GameManager.NON_BATTLE_LAYOUT_LANDSCAPE, "Missing non-battle layout preference should default to landscape"),
		assert_eq(non_battle_orientation_before, DisplayServer.SCREEN_SENSOR_LANDSCAPE, "Default non-battle mobile orientation should remain landscape"),
		assert_eq(battle_layout_after, GameManager.BATTLE_LAYOUT_PORTRAIT, "Changing non-battle layout should not mutate battle_layout_mode"),
		assert_eq(non_battle_after, GameManager.NON_BATTLE_LAYOUT_PORTRAIT, "Non-battle layout preference should switch to portrait independently"),
		assert_eq(non_battle_orientation_after, DisplayServer.SCREEN_SENSOR_PORTRAIT, "Portrait non-battle layout should request portrait mobile orientation"),
		assert_str_contains(saved_text, GameManager.NON_BATTLE_LAYOUT_PORTRAIT, "Non-battle layout preference should persist to its own file"),
	])


func test_non_battle_layout_toggle_cycles_only_landscape_and_portrait() -> String:
	var original_non_battle_settings_text := _read_non_battle_layout_settings_text()
	_remove_non_battle_layout_settings_file()
	var manager: Node = _load_game_manager_script().new()
	manager.call("set_non_battle_layout_mode", GameManager.NON_BATTLE_LAYOUT_LANDSCAPE, false, false)
	var first_toggle := str(manager.call("toggle_non_battle_layout_mode", false, false))
	var second_toggle := str(manager.call("toggle_non_battle_layout_mode", false, false))
	_restore_non_battle_layout_settings_text(original_non_battle_settings_text)

	return run_checks([
		assert_eq(first_toggle, GameManager.NON_BATTLE_LAYOUT_PORTRAIT, "Non-battle layout button should switch landscape to portrait"),
		assert_eq(second_toggle, GameManager.NON_BATTLE_LAYOUT_LANDSCAPE, "Non-battle layout button should switch portrait back to landscape"),
	])
