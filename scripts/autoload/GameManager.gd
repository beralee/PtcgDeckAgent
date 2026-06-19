## 全局游戏管理器 - 跨场景共享数据和场景切换
extends Node

const SwissTournamentScript := preload("res://scripts/tournament/SwissTournament.gd")
const NonBattleLayoutControllerScript := preload("res://scripts/ui/non_battle/NonBattleLayoutController.gd")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")

signal non_battle_layout_mode_changed(mode: String)

## 游戏模式
enum GameMode {
	TWO_PLAYER,  ## 双人操控
	VS_AI,       ## 对战AI
}

## 当前选择的游戏模式
var current_mode: GameMode = GameMode.TWO_PLAYER
## 选择的卡组（两个卡组ID）
var selected_deck_ids: Array[int] = [0, 0]
## AI 难度等级 (0=简单, 1=普通, 2=困难, 3=专家)
var ai_difficulty: int = 1
var ai_selection: Dictionary = {
	"source": "default",
	"version_id": "",
	"agent_config_path": "",
	"value_net_path": "",
	"action_scorer_path": "",
	"interaction_scorer_path": "",
	"display_name": "",
	"opening_mode": "default",
	"fixed_deck_order_path": "",
}
## AI 卡组策略 ("generic" | "gardevoir_greedy" | "gardevoir_mcts" | "miraidon_greedy" | "miraidon_mcts")
var ai_deck_strategy: String = "generic"
## 先攻选择 (-1=随机, 0=玩家1, 1=玩家2)
var first_player_choice: int = -1
## 对战背景资源路径
var selected_battle_background: String = "res://assets/ui/background.png"
var dynamic_stadium_background_enabled: bool = true
var selected_battle_music_id: String = "none"
var battle_bgm_volume_percent: int = 20
var battle_layout_mode: String = "auto"
var non_battle_layout_mode: String = "landscape"
var _non_battle_layout_controller: RefCounted = NonBattleLayoutControllerScript.new()

## 当前游戏状态（对战中有效）
var game_state: GameState = null

## 场景路径
const SCENE_MAIN_MENU := "res://scenes/main_menu/MainMenu.tscn"
const SCENE_DECK_MANAGER := "res://scenes/deck_manager/DeckManager.tscn"
const SCENE_BATTLE_SETUP := "res://scenes/battle_setup/BattleSetup.tscn"
const SCENE_BATTLE := "res://scenes/battle/BattleScene.tscn"
const SCENE_DECK_EDITOR := "res://scenes/deck_editor/DeckEditor.tscn"
const SCENE_REPLAY_BROWSER := "res://scenes/replay_browser/ReplayBrowser.tscn"
const SCENE_SETTINGS := "res://scenes/settings/Settings.tscn"
const SCENE_TOURNAMENT_DECK_SELECT := "res://scenes/tournament/TournamentDeckSelect.tscn"
const SCENE_TOURNAMENT_SETUP := "res://scenes/tournament/TournamentSetup.tscn"
const SCENE_TOURNAMENT_OVERVIEW := "res://scenes/tournament/TournamentOverview.tscn"
const SCENE_TOURNAMENT_STANDINGS := "res://scenes/tournament/TournamentStandings.tscn"
const NAVIGATION_PREWARM_SCENES: Array[String] = [
	SCENE_BATTLE_SETUP,
	SCENE_DECK_MANAGER,
]
const BATTLE_REVIEW_API_CONFIG_PATH := "user://battle_review_api.json"
const CANONICAL_BATTLE_REVIEW_USER_DIR_NAME := "PTCG Train"
const BATTLE_REVIEW_API_CONFIG_FILE_NAME := "battle_review_api.json"
const BATTLE_SETUP_SETTINGS_PATH := "user://battle_setup.json"
const NON_BATTLE_LAYOUT_SETTINGS_PATH := "user://non_battle_layout.json"
const TOURNAMENT_SAVE_PATH := "user://tournament_mode_save.json"
const DESKTOP_WINDOW_SCREEN_MARGIN := Vector2i(48, 48)
const DEFAULT_BATTLE_BGM_VOLUME_PERCENT := 20
const BATTLE_BGM_VOLUME_USER_SET_KEY := "battle_bgm_volume_user_set"
const BATTLE_LAYOUT_AUTO := "auto"
const BATTLE_LAYOUT_LANDSCAPE := "landscape"
const BATTLE_LAYOUT_PORTRAIT := "portrait"
const NON_BATTLE_LAYOUT_LANDSCAPE := "landscape"
const NON_BATTLE_LAYOUT_PORTRAIT := "portrait"
const BATTLE_LAYOUT_DESKTOP_MIN_LANDSCAPE := Vector2i(640, 360)
const BATTLE_LAYOUT_DESKTOP_MIN_PORTRAIT := Vector2i(360, 640)
const DEFAULT_BATTLE_REVIEW_MODEL := "deepseek-v4-flash"
const DEFAULT_AI_PERSONALITY := "是一个大逗比，臭牌篓子"
const SUPPORTED_BATTLE_REVIEW_MODELS: Array[Dictionary] = [
	{
		"id": "kimi-k2.6",
		"label": "Kimi K2.6",
	},
	{
		"id": "z-ai/glm-5.2",
		"label": "GLM 5.2",
	},
	{
		"id": "qwen/qwen3.7-plus",
		"label": "Qwen 3.7 Plus",
	},
	{
		"id": "qwen/qwen3.7-max",
		"label": "Qwen 3.7 Max",
	},
	{
		"id": "deepseek-v4-flash",
		"label": "DeepSeek V4 Flash",
	},
	{
		"id": "deepseek-v4-pro",
		"label": "DeepSeek V4 Pro",
	},
	{
		"id": "gpt-5.5",
		"label": "gpt-5.5",
	},
	{
		"id": "claude-sonnet-4-6",
		"label": "claude-sonnet-4-6",
	},
]

var _battle_replay_launch: Dictionary = {}
var _deck_editor_deck_id: int = -1
var _deck_editor_return_context: Dictionary = {}
var tournament_selected_player_deck_id: int = -1
var current_tournament: RefCounted = null
var battle_player_display_names: Array[String] = ["", ""]
var tournament_battle_in_progress: bool = false
var suppress_scene_navigation_for_tests: bool = false
var last_requested_scene_path: String = ""
var _touch_button_bridge_candidate: Button = null
var _navigation_prewarm_requested: Dictionary = {}
var _navigation_prewarm_resources: Dictionary = {}
var _pending_scene_change_path: String = ""
var _pending_scene_change_token: int = 0


func _ready() -> void:
	load_non_battle_layout_preferences()
	load_battle_setup_preferences()
	reload_tournament_state_from_disk()
	call_deferred("apply_non_battle_orientation")
	call_deferred("_ensure_desktop_window_size")


func _ensure_desktop_window_size() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _is_web_runtime():
		return
	var current_mode := DisplayServer.window_get_mode()
	if _should_preserve_user_desktop_window_mode(current_mode):
		return
	if _should_maximize_desktop_window(OS.get_name()):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		return

	var desired := _configured_desktop_window_size()
	if desired.x <= 0 or desired.y <= 0:
		return

	var screen_index := DisplayServer.window_get_current_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(screen_index)
	desired = _desktop_window_size_for_os(OS.get_name(), desired, usable_rect.size)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(desired)
	if usable_rect.size.x > 0 and usable_rect.size.y > 0:
		DisplayServer.window_set_position(_center_desktop_window_position(desired, usable_rect))


func apply_battle_layout_orientation(mode: String = "") -> void:
	set_touch_mouse_emulation_for_runtime(true)
	if DisplayServer.get_name() == "headless":
		return
	if _is_web_runtime():
		return
	var normalized := sanitize_battle_layout_mode(mode if mode != "" else battle_layout_mode)
	if _should_apply_native_screen_orientation():
		_apply_handheld_battle_orientation(normalized)
		return
	_apply_desktop_battle_window_shape(normalized)


func apply_non_battle_orientation() -> void:
	apply_non_battle_orientation_for_scene("")


func apply_non_battle_orientation_for_scene(path: String = "") -> void:
	set_touch_mouse_emulation_for_runtime(_non_battle_touch_mouse_emulation_enabled_for_runtime())
	if DisplayServer.get_name() == "headless":
		return
	if _is_web_runtime():
		return
	if _should_apply_native_screen_orientation():
		DisplayServer.screen_set_orientation(non_battle_handheld_orientation_for_scene(path))
		return
	_ensure_desktop_window_size()


func non_battle_handheld_orientation() -> int:
	return non_battle_handheld_orientation_for_scene("")


func non_battle_handheld_orientation_for_scene(path: String = "") -> int:
	if path == SCENE_DECK_EDITOR:
		return DisplayServer.SCREEN_SENSOR_LANDSCAPE
	match sanitize_non_battle_layout_mode(non_battle_layout_mode):
		NON_BATTLE_LAYOUT_PORTRAIT:
			return DisplayServer.SCREEN_SENSOR_PORTRAIT
		_:
			return DisplayServer.SCREEN_SENSOR_LANDSCAPE


func sanitize_non_battle_layout_mode(mode: String) -> String:
	match mode:
		NON_BATTLE_LAYOUT_PORTRAIT:
			return NON_BATTLE_LAYOUT_PORTRAIT
		_:
			return NON_BATTLE_LAYOUT_LANDSCAPE


func set_non_battle_layout_mode(mode: String, persist: bool = true, apply_now: bool = true) -> String:
	var previous := non_battle_layout_mode
	non_battle_layout_mode = sanitize_non_battle_layout_mode(mode)
	if persist:
		save_non_battle_layout_preferences()
	if apply_now:
		apply_non_battle_orientation()
	if previous != non_battle_layout_mode:
		non_battle_layout_mode_changed.emit(non_battle_layout_mode)
	return non_battle_layout_mode


func toggle_non_battle_layout_mode(persist: bool = true, apply_now: bool = true) -> String:
	var current := sanitize_non_battle_layout_mode(non_battle_layout_mode)
	var next := NON_BATTLE_LAYOUT_PORTRAIT if current == NON_BATTLE_LAYOUT_LANDSCAPE else NON_BATTLE_LAYOUT_LANDSCAPE
	return set_non_battle_layout_mode(next, persist, apply_now)


func battle_handheld_orientation_for_mode(mode: String) -> int:
	match sanitize_battle_layout_mode(mode):
		BATTLE_LAYOUT_PORTRAIT:
			return DisplayServer.SCREEN_SENSOR_PORTRAIT
		BATTLE_LAYOUT_LANDSCAPE:
			return DisplayServer.SCREEN_SENSOR_LANDSCAPE
		_:
			return DisplayServer.SCREEN_SENSOR


func battle_layout_desktop_window_size_for_mode(
	mode: String,
	configured_size: Vector2i,
	usable_size: Vector2i = Vector2i.ZERO
) -> Vector2i:
	var normalized := sanitize_battle_layout_mode(mode)
	var desired := configured_size
	var portrait := normalized == BATTLE_LAYOUT_PORTRAIT
	if normalized == BATTLE_LAYOUT_AUTO:
		return _fit_desktop_window_size(configured_size, usable_size)
	if portrait:
		desired = _oriented_window_size(configured_size, true)
	else:
		desired = _oriented_window_size(configured_size, false)
	return _fit_desktop_window_size_with_min(
		desired,
		usable_size,
		BATTLE_LAYOUT_DESKTOP_MIN_PORTRAIT if portrait else BATTLE_LAYOUT_DESKTOP_MIN_LANDSCAPE
	)


func _apply_handheld_battle_orientation(mode: String) -> void:
	DisplayServer.screen_set_orientation(battle_handheld_orientation_for_mode(mode))


func _apply_desktop_battle_window_shape(mode: String) -> void:
	if mode == BATTLE_LAYOUT_AUTO:
		return
	var current_mode := DisplayServer.window_get_mode()
	if _should_preserve_user_desktop_window_mode(current_mode):
		return
	if _should_maximize_desktop_window(OS.get_name()):
		return
	var configured := _configured_desktop_window_size()
	if configured.x <= 0 or configured.y <= 0:
		return
	var screen_index := DisplayServer.window_get_current_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(screen_index)
	var desired := _battle_desktop_window_size_for_os(OS.get_name(), mode, configured, usable_rect.size)
	if desired.x <= 0 or desired.y <= 0:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(desired)
	if usable_rect.size.x > 0 and usable_rect.size.y > 0:
		DisplayServer.window_set_position(_center_desktop_window_position(desired, usable_rect))


func _oriented_window_size(size: Vector2i, portrait: bool) -> Vector2i:
	if portrait and size.x > size.y:
		return Vector2i(size.y, size.x)
	if not portrait and size.y > size.x:
		return Vector2i(size.y, size.x)
	return size


func _configured_desktop_window_size() -> Vector2i:
	var desired_width := int(ProjectSettings.get_setting("display/window/size/window_width", ProjectSettings.get_setting("display/window/size/viewport_width", 1600)))
	var desired_height := int(ProjectSettings.get_setting("display/window/size/window_height", ProjectSettings.get_setting("display/window/size/viewport_height", 900)))
	return Vector2i(desired_width, desired_height)


func _fit_desktop_window_size(desired: Vector2i, usable_size: Vector2i) -> Vector2i:
	return _fit_desktop_window_size_with_min(desired, usable_size, BATTLE_LAYOUT_DESKTOP_MIN_LANDSCAPE)


func _desktop_window_size_for_os(os_name: String, desired: Vector2i, usable_size: Vector2i) -> Vector2i:
	if _should_use_large_windowed_desktop_launch(os_name):
		return _largest_windowed_size_with_aspect(
			desired,
			usable_size,
			DESKTOP_WINDOW_SCREEN_MARGIN,
			BATTLE_LAYOUT_DESKTOP_MIN_LANDSCAPE
		)
	return _fit_desktop_window_size(desired, usable_size)


func _battle_desktop_window_size_for_os(
	os_name: String,
	mode: String,
	configured_size: Vector2i,
	usable_size: Vector2i
) -> Vector2i:
	var normalized := sanitize_battle_layout_mode(mode)
	var desired := configured_size
	var min_size := BATTLE_LAYOUT_DESKTOP_MIN_LANDSCAPE
	if normalized == BATTLE_LAYOUT_PORTRAIT:
		desired = _oriented_window_size(configured_size, true)
		min_size = BATTLE_LAYOUT_DESKTOP_MIN_PORTRAIT
	elif normalized == BATTLE_LAYOUT_LANDSCAPE:
		desired = _oriented_window_size(configured_size, false)
	if _should_use_large_windowed_desktop_launch(os_name):
		return _largest_windowed_size_with_aspect(
			desired,
			usable_size,
			DESKTOP_WINDOW_SCREEN_MARGIN,
			min_size
		)
	return _fit_desktop_window_size_with_min(desired, usable_size, min_size)


func _fit_desktop_window_size_with_min(desired: Vector2i, usable_size: Vector2i, min_size: Vector2i) -> Vector2i:
	if desired.x <= 0 or desired.y <= 0:
		return desired
	if usable_size.x <= 0 or usable_size.y <= 0:
		return desired
	var max_size := Vector2i(
		maxi(min_size.x, usable_size.x - DESKTOP_WINDOW_SCREEN_MARGIN.x),
		maxi(min_size.y, usable_size.y - DESKTOP_WINDOW_SCREEN_MARGIN.y)
	)
	var scale := minf(1.0, minf(float(max_size.x) / float(desired.x), float(max_size.y) / float(desired.y)))
	return Vector2i(maxi(min_size.x, roundi(float(desired.x) * scale)), maxi(min_size.y, roundi(float(desired.y) * scale)))


func _largest_windowed_size_with_aspect(
	desired: Vector2i,
	usable_size: Vector2i,
	margin: Vector2i,
	min_size: Vector2i
) -> Vector2i:
	if desired.x <= 0 or desired.y <= 0:
		return desired
	if usable_size.x <= 0 or usable_size.y <= 0:
		return desired
	var aspect := float(desired.x) / maxf(float(desired.y), 1.0)
	var max_size := Vector2i(
		maxi(min_size.x, usable_size.x - margin.x),
		maxi(min_size.y, usable_size.y - margin.y)
	)
	var target_width := max_size.x
	var target_height := roundi(float(target_width) / aspect)
	if target_height > max_size.y:
		target_height = max_size.y
		target_width = roundi(float(target_height) * aspect)
	return Vector2i(maxi(min_size.x, target_width), maxi(min_size.y, target_height))


func _center_desktop_window_position(window_size: Vector2i, usable_rect: Rect2i) -> Vector2i:
	return usable_rect.position + Vector2i(
		maxi(0, int((usable_rect.size.x - window_size.x) * 0.5)),
		maxi(0, int((usable_rect.size.y - window_size.y) * 0.5))
	)


func _should_maximize_desktop_window(os_name: String) -> bool:
	# macOS maximized windows can report a different effective viewport than the
	# configured battle window, which breaks the landscape hand rail on 16:10
	# displays. Keep desktop launch windowed and let explicit fullscreen stay
	# user-controlled.
	return false


func _should_preserve_user_desktop_window_mode(mode: int) -> bool:
	return mode in [
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_MAXIMIZED,
	]


func _should_use_large_windowed_desktop_launch(os_name: String) -> bool:
	return os_name in ["macOS", "OSX"]


func _is_mobile_runtime() -> bool:
	return _is_mobile_runtime_for_context()


func _is_mobile_runtime_for_context(os_name: String = "", feature_flags: Dictionary = {}) -> bool:
	var resolved_os := os_name.strip_edges().to_lower()
	if resolved_os in ["android", "ios"]:
		return true
	var flags := feature_flags
	if flags.is_empty() and os_name == "":
		flags = _runtime_feature_flags()
	for feature: String in ["mobile", "android", "ios", "web_android", "web_ios"]:
		if bool(flags.get(feature, false)):
			return true
	return false


func _is_web_runtime(os_name: String = "", feature_flags: Dictionary = {}, display_server_name: String = "") -> bool:
	var resolved_os := os_name.strip_edges().to_lower()
	var resolved_display := display_server_name.strip_edges().to_lower()
	var flags := feature_flags
	if flags.is_empty() and os_name == "" and display_server_name == "":
		flags = _runtime_feature_flags()
		resolved_os = OS.get_name().strip_edges().to_lower()
		resolved_display = DisplayServer.get_name().strip_edges().to_lower()
	if resolved_os in ["web", "html5"] or resolved_display in ["web", "html5"]:
		return true
	for feature: String in ["web", "web_android", "web_ios"]:
		if bool(flags.get(feature, false)):
			return true
	return false


func _should_apply_native_screen_orientation(os_name: String = "", feature_flags: Dictionary = {}, display_server_name: String = "") -> bool:
	return _is_mobile_runtime_for_context(os_name, feature_flags) and not _is_web_runtime(os_name, feature_flags, display_server_name)


func set_touch_mouse_emulation_for_runtime(enabled: bool) -> void:
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", enabled)
	if Input.has_method("set_emulate_mouse_from_touch"):
		Input.call("set_emulate_mouse_from_touch", enabled)


func _touch_mouse_emulation_enabled_for_scene(path: String) -> bool:
	return true


func _non_battle_touch_mouse_emulation_enabled_for_runtime(os_name: String = "", feature_flags: Dictionary = {}) -> bool:
	var resolved_os := os_name if os_name != "" else OS.get_name()
	if resolved_os in ["Android", "iOS"]:
		return false
	var flags := feature_flags
	if flags.is_empty():
		flags = _runtime_feature_flags()
	for feature: String in ["mobile", "android", "ios", "web_android", "web_ios"]:
		if bool(flags.get(feature, false)):
			return false
	return true


func default_non_battle_layout_mode_for_first_run(
	os_name: String = "",
	feature_flags: Dictionary = {},
	display_server_name: String = "",
	viewport_size: Vector2 = Vector2.ZERO,
	user_agent: String = ""
) -> String:
	var size := viewport_size
	if size.x <= 0.0 or size.y <= 0.0:
		size = _current_non_battle_layout_viewport_size()
	var flags := feature_flags
	if flags.is_empty() and os_name == "" and display_server_name == "":
		flags = _runtime_feature_flags()
	var resolved_os := os_name if os_name != "" else OS.get_name()
	var resolved_display := display_server_name if display_server_name != "" else DisplayServer.get_name()
	return str(_non_battle_layout_controller.call("default_layout_mode_for_runtime", resolved_os, flags, resolved_display, size, user_agent))


func _runtime_feature_flags() -> Dictionary:
	return {
		"mobile": OS.has_feature("mobile"),
		"android": OS.has_feature("android"),
		"ios": OS.has_feature("ios"),
		"web": OS.has_feature("web"),
		"web_android": OS.has_feature("web_android"),
		"web_ios": OS.has_feature("web_ios"),
	}


func _current_non_battle_layout_viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport != null:
		var rect := viewport.get_visible_rect()
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			return rect.size
	if DisplayServer.get_name() != "headless":
		var window_size := DisplayServer.window_get_size()
		if window_size.x > 0 and window_size.y > 0:
			return Vector2(window_size)
	return Vector2.ZERO


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_handle_touch_button_bridge_at_position(touch.position, touch.pressed)
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if _should_bridge_mouse_button_touch_echo(mouse_button):
			_handle_touch_button_bridge_at_position(mouse_button.position, mouse_button.pressed)


func _should_bridge_mouse_button_touch_echo(mouse_button: InputEventMouseButton, os_name: String = "", feature_flags: Dictionary = {}) -> bool:
	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return false
	if os_name != "" or not feature_flags.is_empty():
		return not _non_battle_touch_mouse_emulation_enabled_for_runtime(os_name, feature_flags)
	return _is_mobile_runtime()


func _handle_touch_button_bridge_at_position(position: Vector2, pressed: bool) -> void:
	var button := _find_topmost_touch_button(position)
	if pressed:
		_touch_button_bridge_candidate = button
		if button != null:
			_mark_touch_button_bridge_handled()
		return
	var candidate := _touch_button_bridge_candidate
	_touch_button_bridge_candidate = null
	if candidate == null:
		candidate = button
	if candidate == null or candidate != button:
		return
	if not _button_can_bridge_touch(candidate):
		return
	NonBattleTouchBridgeScript.emit_button_pressed_once(candidate)
	_mark_touch_button_bridge_handled()


func _mark_touch_button_bridge_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _find_topmost_touch_button(global_position: Vector2) -> Button:
	var tree := _scene_tree_or_null()
	if tree == null or tree.root == null:
		return null
	for i: int in range(tree.root.get_child_count() - 1, -1, -1):
		var child := tree.root.get_child(i)
		if child == self:
			continue
		var button := _find_topmost_touch_button_recursive(child, global_position)
		if button != null:
			return button
	return null


func _find_topmost_touch_button_recursive(node: Node, global_position: Vector2) -> Button:
	for i: int in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		var button := _find_topmost_touch_button_recursive(child, global_position)
		if button != null:
			return button
	if not (node is Button):
		return null
	var button := node as Button
	if not _button_can_bridge_touch(button):
		return null
	return button if button.get_global_rect().has_point(global_position) else null


func _button_can_bridge_touch(button: Button) -> bool:
	if button == null or button.disabled or not button.visible:
		return false
	if button.is_inside_tree() and not button.is_visible_in_tree():
		return false
	return true


func _has_active_battle_scene() -> bool:
	var tree := _scene_tree_or_null()
	if tree == null or tree.root == null:
		return false
	if tree.current_scene != null and _node_is_battle_scene(tree.current_scene):
		return true
	for child: Node in tree.root.get_children():
		if child == self:
			continue
		if _node_is_battle_scene(child):
			return true
	return false


func _node_is_battle_scene(node: Node) -> bool:
	if node == null:
		return false
	if node.scene_file_path == SCENE_BATTLE or node.name == "BattleScene":
		return true
	var script: Variant = node.get_script()
	if script is Script and str(script.resource_path) == "res://scenes/battle/BattleScene.gd":
		return true
	return false


func _scene_tree_or_null() -> SceneTree:
	if is_inside_tree():
		return get_tree()
	var loop := Engine.get_main_loop()
	return loop as SceneTree


## 切换到指定场景
func goto_scene(path: String) -> void:
	# 延迟调用以避免在信号处理中切换场景
	if suppress_scene_navigation_for_tests:
		last_requested_scene_path = path
		return
	if not _queue_scene_change(path):
		return
	var request_token := _pending_scene_change_token
	call_deferred("_deferred_goto_scene", path, request_token)


func _queue_scene_change(path: String) -> bool:
	if path == "":
		return false
	if _pending_scene_change_path == path:
		return false
	_pending_scene_change_token += 1
	_pending_scene_change_path = path
	return true


func set_scene_navigation_suppressed_for_tests(suppressed: bool) -> void:
	suppress_scene_navigation_for_tests = suppressed
	if not suppressed:
		last_requested_scene_path = ""


func consume_last_requested_scene_path() -> String:
	var path := last_requested_scene_path
	last_requested_scene_path = ""
	return path


func _deferred_goto_scene(path: String, request_token: int = 0) -> void:
	if not _is_current_scene_change_request(path, request_token):
		return
	set_touch_mouse_emulation_for_runtime(_touch_mouse_emulation_enabled_for_scene(path))
	if _should_apply_deck_editor_orientation_before_scene_change(path):
		apply_deck_editor_orientation()
	elif _should_apply_non_battle_orientation_before_scene_change(path):
		apply_non_battle_orientation_for_scene(path)
	var prewarmed_scene := _take_prewarmed_scene(path)
	if prewarmed_scene != null:
		var packed_err := get_tree().change_scene_to_packed(prewarmed_scene)
		if packed_err == OK:
			await get_tree().process_frame
			_clear_pending_scene_change(path, request_token)
		else:
			_clear_pending_scene_change(path, request_token)
			push_error("GameManager: failed to change scene to prewarmed %s: %s" % [path, packed_err])
		return
	if _should_await_requested_prewarm_for_path(path):
		prewarmed_scene = await _await_prewarmed_scene(path)
		if not _is_current_scene_change_request(path, request_token):
			return
		if prewarmed_scene != null:
			var awaited_err := get_tree().change_scene_to_packed(prewarmed_scene)
			if awaited_err == OK:
				await get_tree().process_frame
				_clear_pending_scene_change(path, request_token)
			else:
				_clear_pending_scene_change(path, request_token)
				push_error("GameManager: failed to change scene to awaited %s: %s" % [path, awaited_err])
			return
	var file_err := get_tree().change_scene_to_file(path)
	if file_err == OK:
		await get_tree().process_frame
		_clear_pending_scene_change(path, request_token)
	else:
		_clear_pending_scene_change(path, request_token)
		push_error("GameManager: failed to change scene to %s: %s" % [path, file_err])


func _is_current_scene_change_request(path: String, request_token: int) -> bool:
	return _pending_scene_change_path == path and _pending_scene_change_token == request_token


func _clear_pending_scene_change(path: String, request_token: int) -> void:
	if not _is_current_scene_change_request(path, request_token):
		return
	_pending_scene_change_path = ""


func prewarm_navigation_resources() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for path: String in navigation_prewarm_scene_paths():
		_request_navigation_resource_prewarm(path)


func navigation_prewarm_scene_paths() -> Array[String]:
	return NAVIGATION_PREWARM_SCENES.duplicate()


func battle_setup_prewarm_scene_path() -> String:
	return SCENE_BATTLE


func prewarm_battle_scene_resource() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_request_navigation_resource_prewarm(battle_setup_prewarm_scene_path())


func should_await_prewarm_status_for_scene_change(status: int) -> bool:
	return status == ResourceLoader.THREAD_LOAD_IN_PROGRESS


func _request_navigation_resource_prewarm(path: String) -> void:
	if path == "" or _navigation_prewarm_requested.has(path) or _navigation_prewarm_resources.has(path):
		return
	if ResourceLoader.has_cached(path):
		var cached := ResourceLoader.load(path)
		if cached is PackedScene:
			_navigation_prewarm_resources[path] = cached
		return
	var err := ResourceLoader.load_threaded_request(path)
	if err == OK:
		_navigation_prewarm_requested[path] = true


func _take_prewarmed_scene(path: String) -> PackedScene:
	var cached: Variant = _navigation_prewarm_resources.get(path, null)
	if cached is PackedScene:
		return cached
	if not _navigation_prewarm_requested.has(path):
		return null
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_navigation_prewarm_requested.erase(path)
		var resource := ResourceLoader.load_threaded_get(path)
		if resource is PackedScene:
			_navigation_prewarm_resources[path] = resource
			return resource
		return null
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_navigation_prewarm_requested.erase(path)
	return null


func _should_await_requested_prewarm_for_path(path: String) -> bool:
	if not _navigation_prewarm_requested.has(path):
		return false
	var status := ResourceLoader.load_threaded_get_status(path)
	return should_await_prewarm_status_for_scene_change(status)


func _await_prewarmed_scene(path: String) -> PackedScene:
	while _navigation_prewarm_requested.has(path):
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			return _take_prewarmed_scene(path)
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_navigation_prewarm_requested.erase(path)
			return null
		await get_tree().process_frame
	return _take_prewarmed_scene(path)


func _should_apply_non_battle_orientation_before_scene_change(path: String) -> bool:
	return path != SCENE_BATTLE and path != SCENE_DECK_EDITOR


func _should_apply_deck_editor_orientation_before_scene_change(path: String, os_name: String = "", feature_flags: Dictionary = {}, display_server_name: String = "") -> bool:
	return path == SCENE_DECK_EDITOR and not _is_web_runtime(os_name, feature_flags, display_server_name)


func apply_deck_editor_orientation() -> void:
	set_touch_mouse_emulation_for_runtime(true)
	if DisplayServer.get_name() == "headless":
		return
	if _is_web_runtime():
		return
	if _should_apply_native_screen_orientation():
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
		return
	_ensure_desktop_window_size()


## 切换到主菜单
func goto_main_menu() -> void:
	goto_scene(SCENE_MAIN_MENU)


## 切换到卡组中心
func goto_deck_manager() -> void:
	goto_scene(SCENE_DECK_MANAGER)


## 切换到对战设置
func goto_battle_setup() -> void:
	goto_scene(SCENE_BATTLE_SETUP)


## 切换到对战场景
func goto_battle() -> void:
	goto_scene(SCENE_BATTLE)


func resolve_selected_battle_deck(player_index: int) -> DeckData:
	if player_index < 0 or player_index >= selected_deck_ids.size():
		return null
	var deck_id := int(selected_deck_ids[player_index])
	if current_mode == GameMode.VS_AI and player_index == 1:
		var ai_deck: DeckData = CardDatabase.get_ai_deck(deck_id)
		if ai_deck != null:
			return ai_deck
	return CardDatabase.get_deck(deck_id)


func goto_deck_editor(deck_id: int, return_context: Dictionary = {}) -> void:
	_deck_editor_deck_id = deck_id
	_deck_editor_return_context = return_context.duplicate(true)
	goto_scene(SCENE_DECK_EDITOR)


func consume_deck_editor_id() -> int:
	var id := _deck_editor_deck_id
	_deck_editor_deck_id = -1
	return id


func set_deck_editor_return_context(context: Dictionary) -> void:
	_deck_editor_return_context = context.duplicate(true)


func consume_deck_editor_return_context() -> Dictionary:
	var context := _deck_editor_return_context.duplicate(true)
	_deck_editor_return_context = {}
	return context


func goto_replay_browser() -> void:
	goto_scene(SCENE_REPLAY_BROWSER)


func goto_settings() -> void:
	goto_scene(SCENE_SETTINGS)


func goto_tournament_deck_select() -> void:
	goto_scene(SCENE_TOURNAMENT_DECK_SELECT)


func goto_tournament_setup() -> void:
	goto_scene(SCENE_TOURNAMENT_SETUP)


func goto_tournament_overview() -> void:
	goto_scene(SCENE_TOURNAMENT_OVERVIEW)


func goto_tournament_standings() -> void:
	goto_scene(SCENE_TOURNAMENT_STANDINGS)


func load_battle_setup_preferences() -> void:
	selected_battle_music_id = "none"
	battle_bgm_volume_percent = DEFAULT_BATTLE_BGM_VOLUME_PERCENT
	battle_layout_mode = BATTLE_LAYOUT_AUTO
	dynamic_stadium_background_enabled = true
	if not FileAccess.file_exists(BATTLE_SETUP_SETTINGS_PATH):
		return
	var file := FileAccess.open(BATTLE_SETUP_SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Variant = json.data
	if not data is Dictionary:
		return
	selected_battle_music_id = str(data.get("battle_music_id", selected_battle_music_id))
	battle_bgm_volume_percent = resolve_battle_bgm_volume_percent_from_settings(data, battle_bgm_volume_percent)
	battle_layout_mode = sanitize_battle_layout_mode(str(data.get("battle_layout_mode", battle_layout_mode)))
	dynamic_stadium_background_enabled = bool(data.get("dynamic_stadium_background_enabled", dynamic_stadium_background_enabled))


func resolve_battle_bgm_volume_percent_from_settings(data: Dictionary, fallback: int = DEFAULT_BATTLE_BGM_VOLUME_PERCENT) -> int:
	var resolved := clampi(int(data.get("battle_bgm_volume_percent", fallback)), 0, 100)
	if data.has("battle_bgm_volume_percent") and resolved == 100 and not bool(data.get(BATTLE_BGM_VOLUME_USER_SET_KEY, false)):
		return DEFAULT_BATTLE_BGM_VOLUME_PERCENT
	return resolved


func sanitize_battle_layout_mode(mode: String) -> String:
	match mode:
		BATTLE_LAYOUT_LANDSCAPE, BATTLE_LAYOUT_PORTRAIT:
			return mode
		_:
			return BATTLE_LAYOUT_AUTO


func load_non_battle_layout_preferences() -> void:
	non_battle_layout_mode = default_non_battle_layout_mode_for_first_run()
	if not FileAccess.file_exists(NON_BATTLE_LAYOUT_SETTINGS_PATH):
		return
	var file := FileAccess.open(NON_BATTLE_LAYOUT_SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	if not json.data is Dictionary:
		return
	var data: Dictionary = json.data
	non_battle_layout_mode = sanitize_non_battle_layout_mode(str(data.get("non_battle_layout_mode", non_battle_layout_mode)))


func save_non_battle_layout_preferences() -> void:
	var file := FileAccess.open(NON_BATTLE_LAYOUT_SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"non_battle_layout_mode": sanitize_non_battle_layout_mode(non_battle_layout_mode),
	}, "\t"))
	file.close()


func set_battle_replay_launch(launch: Dictionary) -> void:
	_battle_replay_launch = launch.duplicate(true)


func consume_battle_replay_launch() -> Dictionary:
	var launch := _battle_replay_launch.duplicate(true)
	_battle_replay_launch = {}
	return launch


func get_battle_review_api_config_path() -> String:
	return BATTLE_REVIEW_API_CONFIG_PATH


func get_supported_battle_review_models() -> Array[Dictionary]:
	return SUPPORTED_BATTLE_REVIEW_MODELS.duplicate(true)


func get_battle_review_model_label(model_id: String) -> String:
	var normalized := normalize_battle_review_model(model_id)
	for model: Dictionary in SUPPORTED_BATTLE_REVIEW_MODELS:
		if str(model.get("id", "")) == normalized:
			return str(model.get("label", normalized))
	return normalized


func normalize_battle_review_model(model_id: String) -> String:
	var normalized := model_id.strip_edges()
	match normalized:
		"z-ai/glm-5.1":
			return "z-ai/glm-5.2"
		"qwen/qwen3.6-plus":
			return "qwen/qwen3.7-plus"
		"deepseek/deepseek-v4-flash":
			return "deepseek-v4-flash"
		"deepseek/deepseek-v4-pro":
			return "deepseek-v4-pro"
	for model: Dictionary in SUPPORTED_BATTLE_REVIEW_MODELS:
		if str(model.get("id", "")) == normalized:
			return normalized
	return DEFAULT_BATTLE_REVIEW_MODEL


func get_battle_review_api_config() -> Dictionary:
	return _load_battle_review_api_config_from_path(BATTLE_REVIEW_API_CONFIG_PATH)


func get_llm_opponent_battle_review_api_config() -> Dictionary:
	var canonical_path := _canonical_battle_review_api_config_path()
	if canonical_path != "" and FileAccess.file_exists(canonical_path):
		var canonical_config := _load_battle_review_api_config_from_path(canonical_path)
		if str(canonical_config.get("api_key", "")).strip_edges() != "":
			canonical_config["config_source_path"] = canonical_path
			return canonical_config
	var config := get_battle_review_api_config()
	config["config_source_path"] = BATTLE_REVIEW_API_CONFIG_PATH
	return config


func _load_battle_review_api_config_from_path(path: String) -> Dictionary:
	var config := _default_battle_review_api_config()
	if path == "" or not FileAccess.file_exists(path):
		return config
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return config
	var raw_text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return config
	var parsed_dict: Dictionary = parsed
	for key: String in ["endpoint", "api_key", "ai_personality", "ai_test_signature"]:
		if parsed_dict.has(key):
			config[key] = _battle_review_config_text(parsed_dict[key], str(config.get(key, "")))
	if str(config.get("endpoint", "")).strip_edges() == "":
		config["endpoint"] = "https://zenmux.ai/api/v1"
	if str(config.get("ai_personality", "")).strip_edges() == "":
		config["ai_personality"] = DEFAULT_AI_PERSONALITY
	if parsed_dict.has("model") and parsed_dict["model"] != null:
		config["model"] = normalize_battle_review_model(_battle_review_config_text(parsed_dict["model"], str(config.get("model", DEFAULT_BATTLE_REVIEW_MODEL))))
	if parsed_dict.has("timeout_seconds"):
		var timeout_value: Variant = parsed_dict["timeout_seconds"]
		if timeout_value is int or timeout_value is float:
			config["timeout_seconds"] = float(timeout_value)
		elif timeout_value is String and str(timeout_value).strip_edges().is_valid_float():
			config["timeout_seconds"] = float(str(timeout_value).strip_edges())
	if parsed_dict.has("ai_test_passed"):
		config["ai_test_passed"] = bool(parsed_dict["ai_test_passed"])
	return config


func _battle_review_config_text(value: Variant, fallback: String = "") -> String:
	if value == null:
		return fallback
	var text := str(value).strip_edges()
	var lower := text.to_lower()
	if text == "" or lower.contains("instance base is null") or lower.contains("instance is null") or lower.contains("null instance"):
		return fallback
	return text


func _canonical_battle_review_api_config_path() -> String:
	var os_name := OS.get_name()
	var base_dir := ""
	match os_name:
		"Windows":
			base_dir = OS.get_environment("APPDATA")
			if base_dir == "":
				return ""
			return base_dir.path_join("Godot").path_join("app_userdata").path_join(CANONICAL_BATTLE_REVIEW_USER_DIR_NAME).path_join(BATTLE_REVIEW_API_CONFIG_FILE_NAME)
		"macOS":
			base_dir = OS.get_environment("HOME")
			if base_dir == "":
				return ""
			return base_dir.path_join("Library").path_join("Application Support").path_join("Godot").path_join("app_userdata").path_join(CANONICAL_BATTLE_REVIEW_USER_DIR_NAME).path_join(BATTLE_REVIEW_API_CONFIG_FILE_NAME)
		_:
			base_dir = OS.get_environment("XDG_DATA_HOME")
			if base_dir == "":
				var home_dir := OS.get_environment("HOME")
				if home_dir == "":
					return ""
				base_dir = home_dir.path_join(".local").path_join("share")
			return base_dir.path_join("godot").path_join("app_userdata").path_join(CANONICAL_BATTLE_REVIEW_USER_DIR_NAME).path_join(BATTLE_REVIEW_API_CONFIG_FILE_NAME)


func _default_battle_review_api_config() -> Dictionary:
	return {
		"endpoint": "https://zenmux.ai/api/v1",
		"api_key": "",
		"model": DEFAULT_BATTLE_REVIEW_MODEL,
		"timeout_seconds": 60.0,
		"ai_personality": DEFAULT_AI_PERSONALITY,
		"ai_test_passed": false,
		"ai_test_signature": "",
	}


func battle_review_ai_config_signature(config: Dictionary) -> String:
	return "%s|%s|%s" % [
		str(config.get("endpoint", "")).strip_edges(),
		str(config.get("api_key", "")).strip_edges(),
		normalize_battle_review_model(str(config.get("model", ""))),
	]


func is_battle_review_ai_ready_for_llm_opponents() -> bool:
	var config := get_battle_review_api_config()
	if str(config.get("endpoint", "")).strip_edges() == "":
		return false
	if str(config.get("api_key", "")).strip_edges() == "":
		return false
	if not bool(config.get("ai_test_passed", false)):
		return false
	return str(config.get("ai_test_signature", "")) == battle_review_ai_config_signature(config)


func reset_ai_selection() -> void:
	ai_selection = {
		"source": "default",
		"version_id": "",
		"agent_config_path": "",
		"value_net_path": "",
		"action_scorer_path": "",
		"interaction_scorer_path": "",
		"display_name": "",
		"opening_mode": "default",
		"fixed_deck_order_path": "",
	}


func set_battle_player_display_names(names: Array[String]) -> void:
	battle_player_display_names = ["", ""]
	for index: int in min(names.size(), 2):
		battle_player_display_names[index] = str(names[index]).strip_edges()


func clear_battle_player_display_names() -> void:
	battle_player_display_names = ["", ""]


func resolve_battle_player_display_name(player_index: int) -> String:
	if player_index < 0 or player_index >= 2:
		return "玩家%d" % (player_index + 1)
	var explicit_name: String = ""
	if player_index < battle_player_display_names.size():
		explicit_name = str(battle_player_display_names[player_index]).strip_edges()
	if explicit_name != "":
		return explicit_name
	if current_mode == GameMode.VS_AI and player_index == 1:
		var ai_name := str(ai_selection.get("display_name", "")).strip_edges()
		if ai_name != "":
			return ai_name
	return "玩家%d" % (player_index + 1)


func set_tournament_selected_player_deck_id(deck_id: int) -> void:
	tournament_selected_player_deck_id = deck_id


func start_swiss_tournament(player_name: String, tournament_size: int) -> void:
	if tournament_selected_player_deck_id <= 0:
		return
	var tournament := SwissTournamentScript.new()
	tournament.setup(
		player_name,
		tournament_selected_player_deck_id,
		tournament_size,
		0,
		is_battle_review_ai_ready_for_llm_opponents()
	)
	current_tournament = tournament
	tournament_battle_in_progress = false
	clear_battle_player_display_names()
	_persist_tournament_state()


func has_active_tournament() -> bool:
	return current_tournament != null


func is_tournament_battle_active() -> bool:
	return current_tournament != null and tournament_battle_in_progress


func mark_current_battle_as_non_tournament() -> void:
	tournament_battle_in_progress = false
	clear_battle_player_display_names()
	if current_tournament != null:
		_persist_tournament_state()


func clear_tournament() -> void:
	current_tournament = null
	tournament_selected_player_deck_id = -1
	tournament_battle_in_progress = false
	clear_battle_player_display_names()
	_persist_tournament_state()


func discard_tournament_keep_selected_deck() -> void:
	current_tournament = null
	tournament_battle_in_progress = false
	clear_battle_player_display_names()
	_persist_tournament_state()


func prepare_current_tournament_battle() -> bool:
	if current_tournament == null:
		return false
	var pairing: Dictionary = current_tournament.prepare_next_round()
	if pairing.is_empty():
		return false
	var player_id := int(current_tournament.player_participant_id)
	var opponent_id := int(pairing.get("player_b_id", -1))
	if int(pairing.get("player_a_id", -1)) != player_id:
		opponent_id = int(pairing.get("player_a_id", -1))
	selected_deck_ids = [
		int(current_tournament.player_deck_id),
		int(current_tournament.participant_deck_id(opponent_id)),
	]
	set_battle_player_display_names([
		str(current_tournament.player_name),
		str(current_tournament.participant_display_name(opponent_id)),
	])
	current_mode = GameMode.VS_AI
	first_player_choice = -1
	reset_ai_selection()
	# Tournament opponents should use their own deck-local rule strategy.
	# Do not inherit the manual AI strategy variant selected in BattleSetup
	# (for example the Raging Bolt LLM variant) across modes.
	ai_deck_strategy = "generic"
	ai_selection["display_name"] = str(current_tournament.participant_display_name(opponent_id))
	if str(current_tournament.participant_ai_mode(opponent_id)) == "llm" and is_battle_review_ai_ready_for_llm_opponents():
		var llm_strategy_id := ""
		if current_tournament.has_method("participant_llm_strategy_id"):
			llm_strategy_id = str(current_tournament.call("participant_llm_strategy_id", opponent_id))
		if llm_strategy_id != "":
			ai_deck_strategy = llm_strategy_id
			ai_selection["display_name"] = "%s（LLM）" % str(current_tournament.participant_display_name(opponent_id))
	var fixed_order_path := str(current_tournament.participant_fixed_order_path(opponent_id))
	if fixed_order_path != "":
		ai_selection["opening_mode"] = "fixed_order"
		ai_selection["fixed_deck_order_path"] = fixed_order_path
	tournament_battle_in_progress = true
	_persist_tournament_state()
	return true


func finalize_current_tournament_battle(winner_index: int, reason: String) -> Dictionary:
	if current_tournament == null:
		return {}
	var player_won := winner_index == 0
	var summary: Dictionary = current_tournament.record_player_match(player_won, reason)
	tournament_battle_in_progress = false
	clear_battle_player_display_names()
	_persist_tournament_state()
	return summary


func forfeit_current_tournament_battle(reason: String = "技术负（中途退出）") -> Dictionary:
	if current_tournament == null:
		return {}
	var summary: Dictionary = current_tournament.record_player_match(false, reason)
	tournament_battle_in_progress = false
	clear_battle_player_display_names()
	_persist_tournament_state()
	return summary


func reload_tournament_state_from_disk() -> void:
	current_tournament = null
	tournament_battle_in_progress = false
	clear_battle_player_display_names()
	if not FileAccess.file_exists(TOURNAMENT_SAVE_PATH):
		return
	var file := FileAccess.open(TOURNAMENT_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		_delete_tournament_state_file()
		return
	file.close()
	if not (json.data is Dictionary):
		_delete_tournament_state_file()
		return
	var data: Dictionary = json.data
	var tournament_data: Dictionary = data.get("tournament", {})
	if tournament_data.is_empty():
		_delete_tournament_state_file()
		return
	var tournament := SwissTournamentScript.new()
	tournament.restore_state(tournament_data)
	current_tournament = tournament
	tournament_selected_player_deck_id = int(tournament.player_deck_id)
	tournament_battle_in_progress = bool(data.get("battle_in_progress", false))
	if tournament_battle_in_progress and not current_tournament.finished:
		forfeit_current_tournament_battle("技术负（中途退出）")
	else:
		_persist_tournament_state()


func has_resumable_tournament_overview() -> bool:
	return has_active_tournament() and current_tournament.current_round <= 0 and current_tournament.last_round_summary.is_empty()


func _persist_tournament_state() -> void:
	if current_tournament == null:
		_delete_tournament_state_file()
		return
	var payload := {
		"battle_in_progress": tournament_battle_in_progress,
		"tournament": current_tournament.serialize_state(),
	}
	var file := FileAccess.open(TOURNAMENT_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.close()


func _delete_tournament_state_file() -> void:
	if FileAccess.file_exists(TOURNAMENT_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TOURNAMENT_SAVE_PATH))
