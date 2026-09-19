class_name PtcgDAPStrategyHub
extends Control

const CLIENT_SCRIPT_PATH := "res://scripts/ai/ptcgdap/platform/service/StrategyPlatformClient.gd"
const BINDER_SCRIPT_PATH := "res://scripts/ai/ptcgdap/platform/service/ExactReleaseChallengeBinder.gd"
const CONTRACTS_SCRIPT_PATH := "res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd"
const REPLAY_READER_SCRIPT_PATH := "res://scripts/ai/ptcgdap/platform/replay/PublicReplayRemoteReader.gd"
const LOCAL_REPLAY_LIBRARY_SCRIPT_PATH := "res://scripts/ai/ptcgdap/platform/replay/PublicReplayLocalLibrary.gd"
const CONTINUOUS_LADDER_REPLAY_STORE_SCRIPT := preload(
	"res://scripts/ai/ptcgdap/platform/replay/ContinuousLadderReplayStore.gd"
)
const MATCH_RECORD_INDEX_SCRIPT_PATH := "res://scripts/engine/MatchRecordIndex.gd"
const BATTLE_REPLAY_LOCATOR_SCRIPT_PATH := "res://scripts/engine/BattleReplayLocator.gd"
const LOCAL_REPLAY_REMOVAL_SCRIPT_PATH := "res://scripts/engine/LocalReplayRemovalService.gd"
const LOCAL_PACKAGE_READ_TASK_SCRIPT := preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageReadTask.gd")
const PUBLIC_REPLAY_VIEWER_SCENE_PATH := "res://scenes/ptcgdap_public_replay/PublicReplayViewer.tscn"
const AI_SETTINGS_SCENE_PATH := "res://scenes/settings/Settings.tscn"
const AUTHOR_SETUP_MODEL_SCRIPT := preload("res://scripts/ui/battle/author_strategy/AuthorStrategySetupModel.gd")
const DECK_VIEW_SCRIPT := preload("res://scripts/ui/decks/DeckViewDialog.gd")
const DECK_MATERIALIZER_SCRIPT := preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyDeckMaterializer.gd")
var _strategy_deck_view := DECK_VIEW_SCRIPT.new()
var _strategy_detail_deck: DeckData = null
var _strategy_detail_ref: Dictionary = {}
var _strategy_deck_grid_width := -1
var _package_preview_catalog_override: Variant = null
const AUTHOR_WINDOWS_GATE_SCRIPT := preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsExecutionGate.gd")
const HUD_THEME_SCRIPT := preload("res://scripts/ui/HudTheme.gd")
const NON_BATTLE_LAYOUT_CONTROLLER_SCRIPT := preload("res://scripts/ui/non_battle/NonBattleLayoutController.gd")
const NON_BATTLE_TOUCH_BRIDGE_SCRIPT := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
const GESTURE_ROUTER_SCRIPT := preload("res://scripts/ui/non_battle/NonBattleGestureRouter.gd")
var _gesture_router := GESTURE_ROUTER_SCRIPT.new()
const PERFORMANCE_TRACE_ARG := "--ptcgdap-performance-trace"
const WORKSPACE_LOCAL := "local"
const WORKSPACE_REPLAYS := "replays"
const WORKSPACE_CATALOG := "catalog"
const WORKSPACE_SETTINGS := "settings"
const DEVELOPER_PORTAL_URL := "https://ptcg.skillserver.cn/dist/developers.html"
var _developer_portal_opener_override: Callable
const MARKETPLACE_LATEST := "latest"
const MARKETPLACE_STRATEGY_RANKINGS := "strategy_rankings"
const MARKETPLACE_AUTHOR_RANKINGS := "author_rankings"
const PUBLIC_NATIVE_START_TOLERANCE_SECONDS := 5
const LOCAL_PACKAGE_ROOT := "user://ptcgdap/author_strategy_packages"
const NATIVE_REPLAY_ROOT := "user://match_records"
const PUBLIC_REPLAY_ROOT := "user://ptcgdap/public_replays/live-community"
const WORKSPACE_COLUMN_MIN_WIDTH := 420.0
const WORKSPACE_COLUMN_GAP := 14.0

var _client: Node = null
var _replay_reader: Node = null
var _replay_viewer: Node = null
var _contract_owner: Variant = null
var _local_replay_library: Variant = null
var _native_match_index: Variant = null
var _native_replay_locator: Variant = null
var _local_replay_removal_service: Variant = null
var _client_script: Script = null
var _contracts_script: Script = null
var _local_replay_library_script: Script = null
var _local_replay_ids := {}
var _local_replay_count := 0
var _base_url := ""
var _allow_insecure_loopback := false
var _selected_strategy_id := ""
var _selected_release_id := ""
var _skip_service_initialization_for_tests := false
var _startup_performance: Dictionary = {}
var _local_package_records: Array[Dictionary] = []
var _local_package_import_busy := false
var _local_package_picker_pending := false
var _local_package_import_generation := 0
var _local_package_read_task: RefCounted = null
var _local_package_read_task_override: RefCounted = null
var _pending_local_package_delete_ref: Dictionary = {}
var _package_delete_catalog_override: Variant = null
var _package_install_catalog_override: Variant = null
var _pending_local_replay_delete_ref: Dictionary = {}
var _replay_removal_service_override: Variant = null
var _clipboard_writer_override: Variant = null
var _local_replay_delete_busy := false
var _local_native_replay_rows: Array[Dictionary] = []
var _local_public_replay_rows: Array[Dictionary] = []
var _active_workspace := WORKSPACE_CATALOG
var _ai_settings_content: Control = null
var _active_marketplace_board := MARKETPLACE_STRATEGY_RANKINGS
var _detail_extra_sections: Dictionary = {}
var _quick_install_button: Button = null
var _quick_install_release_id := ""
var _marketplace_cursors := {
	MARKETPLACE_LATEST: null,
	MARKETPLACE_STRATEGY_RANKINGS: null,
	MARKETPLACE_AUTHOR_RANKINGS: null,
}
var _marketplace_ranking_profile_id := "ptcgdap.marketplace.default.v1"
var _marketplace_profile_discovery_pending := false
var _continuous_ladder_mode := false
var _marketplace_download_button: Button = null
var _marketplace_download_started_usec := 0
var _continuous_ladder_replay_download_button: Button = null
var _continuous_ladder_replay_store_override: Variant = null
var _non_battle_layout_controller: RefCounted = NON_BATTLE_LAYOUT_CONTROLLER_SCRIPT.new()
var _layout_device_rect := Rect2()
var _replays_enabled := true
var _portrait_context: Dictionary = {}
var _workspace_statuses := {
	WORKSPACE_LOCAL: {"text": "本地策略包只保存在这台设备上。", "error": false},
	WORKSPACE_REPLAYS: {"text": "完整录像会使用正式战斗场景播放。", "error": false},
	WORKSPACE_CATALOG: {"text": "正在连接策略广场…", "error": false},
	WORKSPACE_SETTINGS: {"text": "AI 模型与性格设置只保存在这台设备上。", "error": false},
}


func _ready() -> void:
	var ready_started := Time.get_ticks_usec()
	_startup_performance["ready_enter_msec"] = roundi(float(ready_started) / 1000.0)
	_apply_hud_theme()
	_configure_replay_platform()
	%CloseStrategyDetailButton.pressed.connect(_close_strategy_detail)
	_setup_workspace_navigation()
	_connect_non_battle_layout()
	_apply_non_battle_layout()
	%BackButton.pressed.connect(_on_back)
	%RefreshButton.pressed.connect(_refresh_all)
	%ImportLocalPackageButton.pressed.connect(_on_import_local_package_pressed)
	%QuickImportButton.pressed.connect(_on_quick_import_pressed)
	%DetailMoreButton.toggled.connect(_on_detail_more_toggled)
	%DeveloperPortalButton.pressed.connect(_on_developer_portal_pressed)
	%OpenBattleSetupButton.pressed.connect(_on_open_battle_setup_pressed)
	%LocalPackageFileDialog.file_selected.connect(_on_local_package_file_selected)
	%LocalPackageFileDialog.canceled.connect(_on_local_package_file_canceled)
	%LocalPackageDeleteConfirm.pressed.connect(_on_local_package_delete_confirmed)
	%LocalPackageDeleteCancel.pressed.connect(_on_local_package_delete_canceled)
	%LocalReplayDeleteDialog.confirmed.connect(_on_local_replay_delete_confirmed)
	%LocalReplayDeleteDialog.canceled.connect(_on_local_replay_delete_canceled)
	%CopyLocalPackageFolderButton.pressed.connect(
		_copy_storage_path.bind("strategy_packages")
	)
	%CopyNativeReplayFolderButton.pressed.connect(
		_copy_storage_path.bind("native_replays")
	)
	%CopyPublicReplayFolderButton.pressed.connect(
		_copy_storage_path.bind("public_replays")
	)
	%LatestBoardTab.pressed.connect(_select_marketplace_board.bind(MARKETPLACE_LATEST))
	%StrategyRankingBoardTab.pressed.connect(
		_select_marketplace_board.bind(MARKETPLACE_STRATEGY_RANKINGS)
	)
	%AuthorRankingBoardTab.pressed.connect(
		_select_marketplace_board.bind(MARKETPLACE_AUTHOR_RANKINGS)
	)
	%MarketplaceNextButton.pressed.connect(_on_marketplace_next_page)
	%SelectedDownloadButton.pressed.connect(
		_on_marketplace_download_pressed.bind(%SelectedDownloadButton)
	)
	_select_marketplace_board(MARKETPLACE_STRATEGY_RANKINGS, false)
	_configure_storage_paths()
	_bind_local_package_catalog()
	_refresh_local_packages(false)
	_replay_viewer = get_node_or_null("%ReplayViewer")
	if _skip_service_initialization_for_tests:
		_refresh_local_replays()
		_finish_startup_performance_trace(ready_started)
		return
	_set_workspace_status(WORKSPACE_CATALOG, "正在初始化策略广场…")
	call_deferred("_initialize_service_after_first_frame", ready_started)


func _setup_workspace_navigation() -> void:
	%CatalogTab.pressed.connect(_select_workspace.bind(WORKSPACE_CATALOG))
	%LocalStrategyTab.pressed.connect(_select_workspace.bind(WORKSPACE_LOCAL))
	%ReplayTab.pressed.connect(_select_workspace.bind(WORKSPACE_REPLAYS))
	%AISettingsTab.pressed.connect(_select_workspace.bind(WORKSPACE_SETTINGS))
	var initial_workspace := WORKSPACE_CATALOG
	if GameManager != null and GameManager.has_method("consume_strategy_hub_initial_workspace"):
		initial_workspace = str(GameManager.consume_strategy_hub_initial_workspace())
	_select_workspace(initial_workspace)


func _configure_storage_paths() -> void:
	var paths := storage_paths_snapshot()
	var managed_storage := OS.get_name() == "Android"
	_set_storage_path_label(
		%LocalPackageFolderLabel,
		"策略包文件夹",
		"由游戏管理，可通过“导入策略包”添加文件" if managed_storage else str(paths.get("strategy_packages", ""))
	)
	_set_storage_path_label(
		%NativeReplayFolderLabel,
		"完整录像文件夹",
		"由游戏管理，可在本页查看录像" if managed_storage else str(paths.get("native_replays", ""))
	)
	_set_storage_path_label(
		%PublicReplayFolderLabel,
		"公开记录文件夹",
		"由游戏管理，可在本页查看记录" if managed_storage else str(paths.get("public_replays", ""))
	)
	for button: Button in [
		%CopyLocalPackageFolderButton,
		%CopyNativeReplayFolderButton,
		%CopyPublicReplayFolderButton,
	]:
		button.visible = not managed_storage
		_style_action_button(button, Color(0.30, 0.76, 0.92))


func _set_storage_path_label(label: Label, title: String, path: String) -> void:
	label.text = "%s：%s" % [title, path]
	label.tooltip_text = path


func storage_paths_snapshot() -> Dictionary:
	return {
		"strategy_packages": ProjectSettings.globalize_path(LOCAL_PACKAGE_ROOT),
		"native_replays": ProjectSettings.globalize_path(NATIVE_REPLAY_ROOT),
		"public_replays": ProjectSettings.globalize_path(PUBLIC_REPLAY_ROOT),
	}


func _copy_storage_path(path_kind: String) -> void:
	var paths := storage_paths_snapshot()
	var path := str(paths.get(path_kind, ""))
	if path.is_empty():
		_set_workspace_status(
			WORKSPACE_LOCAL if path_kind == "strategy_packages" else WORKSPACE_REPLAYS,
			"文件夹路径不可用。",
			true
		)
		return
	if _clipboard_writer_override != null:
		_clipboard_writer_override.call("set_text", path)
	else:
		DisplayServer.clipboard_set(path)
	_set_workspace_status(
		WORKSPACE_LOCAL if path_kind == "strategy_packages" else WORKSPACE_REPLAYS,
		"已复制文件夹路径。"
	)


func _select_workspace(workspace_id: String) -> void:
	_gesture_router.cancel()
	var normalized := workspace_id if workspace_id in [WORKSPACE_CATALOG, WORKSPACE_LOCAL, WORKSPACE_REPLAYS, WORKSPACE_SETTINGS] else WORKSPACE_CATALOG
	_close_strategy_detail()
	_active_workspace = normalized
	%CatalogWorkspace.visible = normalized == WORKSPACE_CATALOG
	%LocalStrategyWorkspace.visible = normalized == WORKSPACE_LOCAL
	%ReplayWorkspace.visible = normalized == WORKSPACE_REPLAYS
	%AISettingsWorkspace.visible = normalized == WORKSPACE_SETTINGS
	for entry: Dictionary in [
		{"button": %CatalogTab, "workspace": WORKSPACE_CATALOG},
		{"button": %LocalStrategyTab, "workspace": WORKSPACE_LOCAL},
		{"button": %ReplayTab, "workspace": WORKSPACE_REPLAYS},
		{"button": %AISettingsTab, "workspace": WORKSPACE_SETTINGS},
	]:
		_style_workspace_tab(entry.button as Button, str(entry.workspace) == normalized)
	if normalized == WORKSPACE_SETTINGS:
		_ensure_ai_settings_content()
	_restore_workspace_status(normalized)
	_apply_mobile_presentation()
	_reset_active_workspace_scroll()
	if is_inside_tree():
		call_deferred("_reset_active_workspace_scroll")


func _reset_active_workspace_scroll() -> void:
	var active_scroll: ScrollContainer = null
	match _active_workspace:
		WORKSPACE_REPLAYS:
			active_scroll = %ReplayWorkspace
		WORKSPACE_CATALOG:
			active_scroll = %CatalogWorkspace
		WORKSPACE_LOCAL:
			active_scroll = %LocalStrategyWorkspace
		WORKSPACE_SETTINGS:
			active_scroll = %AISettingsWorkspace
	if active_scroll != null:
		active_scroll.scroll_horizontal = 0
		active_scroll.scroll_vertical = 0


func _ensure_ai_settings_content() -> void:
	if _ai_settings_content != null and is_instance_valid(_ai_settings_content):
		return
	var settings_resource := load(AI_SETTINGS_SCENE_PATH) as PackedScene
	if settings_resource == null:
		_set_workspace_status(WORKSPACE_SETTINGS, "AI 设置页面加载失败。", true)
		return
	var settings_content := settings_resource.instantiate() as Control
	if settings_content == null:
		_set_workspace_status(WORKSPACE_SETTINGS, "AI 设置页面创建失败。", true)
		return
	settings_content.name = "AISettingsContent"
	settings_content.custom_minimum_size = Vector2.ZERO
	settings_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if settings_content.has_method("configure_for_strategy_hub_workspace"):
		settings_content.call("configure_for_strategy_hub_workspace")
	%AISettingsWorkspace.add_child(settings_content)
	_ai_settings_content = settings_content


func _style_workspace_tab(button: Button, active: bool) -> void:
	if button == null:
		return
	button.set_meta("hud_segment_active", active)
	button.add_theme_color_override("font_color", Color(0.035, 0.10, 0.13) if active else HUD_THEME_SCRIPT.TEXT)
	button.add_theme_color_override("font_hover_color", Color(0.035, 0.10, 0.13) if active else Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.035, 0.10, 0.13))
	button.add_theme_stylebox_override("normal", _workspace_tab_style(active, false, false))
	button.add_theme_stylebox_override("hover", _workspace_tab_style(active, true, false))
	button.add_theme_stylebox_override("pressed", _workspace_tab_style(active, true, true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if not _portrait_context.is_empty() and button.get_parent() == %WorkspaceTabs:
		for state: String in ["normal", "hover", "pressed"]:
			var style := button.get_theme_stylebox(state) as StyleBoxFlat
			style.content_margin_left = 4
			style.content_margin_right = 4


func _workspace_tab_style(active: bool, hover: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if active:
		style.bg_color = Color(0.24, 0.84, 1.0, 0.94)
		style.border_color = Color(0.76, 1.0, 1.0, 1.0)
	elif pressed:
		style.bg_color = Color(0.18, 0.70, 0.90, 0.92)
		style.border_color = Color(0.54, 0.94, 1.0, 0.96)
	else:
		style.bg_color = Color(0.018, 0.052, 0.078, 0.92)
		style.border_color = Color(0.26, 0.82, 1.0, 0.72 if hover else 0.44)
		if hover:
			style.bg_color = Color(0.035, 0.10, 0.13, 0.96)
	style.set_border_width_all(2 if active or hover else 1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.62, 0.9, 0.18 if active or hover else 0.06)
	style.shadow_size = 8 if active or hover else 2
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _apply_hud_theme() -> void:
	HUD_THEME_SCRIPT.apply(self)
	%LocalPackageDeletePanel.add_theme_stylebox_override("panel", HUD_THEME_SCRIPT.panel_style(
		Color(0.018, 0.052, 0.078, 1.0), HUD_THEME_SCRIPT.ACCENT, 18
	))
	%LocalPackageDeleteMessage.add_theme_color_override("font_color", HUD_THEME_SCRIPT.TEXT)
	%LocalPackageDeleteTitle.add_theme_color_override("font_color", HUD_THEME_SCRIPT.TEXT)
	_style_action_button(%LocalPackageDeleteCancel, HUD_THEME_SCRIPT.ACCENT)
	_style_action_button(%LocalPackageDeleteConfirm, Color(0.94, 0.34, 0.32))
	%TopBarPanel.add_theme_stylebox_override("panel", HUD_THEME_SCRIPT.panel_style(
		Color(0.018, 0.052, 0.078, 0.96), Color(0.28, 0.90, 1.0, 0.78), 18
	))
	%StatusStrip.add_theme_stylebox_override("panel", HUD_THEME_SCRIPT.panel_style(
		Color(0.014, 0.038, 0.058, 0.94), Color(0.22, 0.68, 0.82, 0.42), 10
	))
	(find_child("DetailPanel", true, false) as PanelContainer).add_theme_stylebox_override("panel", HUD_THEME_SCRIPT.panel_style(
		Color(0.018, 0.052, 0.078, 1.0), Color(0.28, 0.90, 1.0, 0.78), 18
	))
	for label_name: String in [
		"HeaderSubtitle", "LibraryKicker", "ImportKicker", "BattleKicker",
		"CatalogKicker", "DetailKicker", "ValidationHint", "LocalSafetyNote",
	]:
		var label := find_child(label_name, true, false) as Label
		if label != null:
			label.add_theme_color_override("font_color", HUD_THEME_SCRIPT.TEXT_MUTED)
	for title_name: String in ["ImportTitle", "BattleTitle", "StrategyTitle"]:
		var title := find_child(title_name, true, false) as Label
		if title != null:
			title.add_theme_font_size_override("font_size", 23)
			title.add_theme_color_override("font_color", HUD_THEME_SCRIPT.TEXT)
	_style_action_button(%ImportLocalPackageButton, HUD_THEME_SCRIPT.ACCENT_WARM)
	_style_action_button(%OpenBattleSetupButton, HUD_THEME_SCRIPT.ACCENT)
	_style_action_button(%SelectedDownloadButton, HUD_THEME_SCRIPT.ACCENT)
	_style_primary_button(%SelectedDownloadButton)
	_style_primary_button(%QuickImportButton)
	_style_primary_button(%DeveloperPortalButton)
	_style_action_button(%MarketplaceNextButton, HUD_THEME_SCRIPT.ACCENT)
	for entry: Dictionary in [
		{"button": %LatestBoardTab, "board": MARKETPLACE_LATEST},
		{"button": %StrategyRankingBoardTab, "board": MARKETPLACE_STRATEGY_RANKINGS},
		{"button": %AuthorRankingBoardTab, "board": MARKETPLACE_AUTHOR_RANKINGS},
	]:
		_style_workspace_tab(
			entry.get("button") as Button,
			str(entry.get("board")) == _active_marketplace_board
		)
	for scroll_name: String in [
		"LocalStrategyWorkspace", "LocalPackageScroll", "ReplayWorkspace",
		"LocalReplayScroll", "CatalogWorkspace", "CatalogScroll", "StrategyRankingScroll",
		"AuthorRankingScroll", "DetailScroll",
	]:
		var scroll := find_child(scroll_name, true, false) as ScrollContainer
		if scroll != null:
			HUD_THEME_SCRIPT.style_scroll_container(scroll)


func _style_action_button(button: Button, accent: Color) -> void:
	if button == null:
		return
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 48.0)
	button.add_theme_stylebox_override("normal", HUD_THEME_SCRIPT.button_style(accent, false, false))
	button.add_theme_stylebox_override("hover", HUD_THEME_SCRIPT.button_style(accent, true, false))
	button.add_theme_stylebox_override("pressed", HUD_THEME_SCRIPT.button_style(accent, true, true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style_primary_button(button: Button) -> void:
	_style_action_button(button, HUD_THEME_SCRIPT.ACCENT_WARM)
	for state: String in ["normal", "hover", "pressed"]:
		var style := HUD_THEME_SCRIPT.button_style(HUD_THEME_SCRIPT.ACCENT_WARM, state == "hover", state == "pressed")
		style.bg_color = Color(1.0, 0.77, 0.36) if state == "hover" else Color(0.96, 0.65, 0.24)
		button.add_theme_stylebox_override(state, style)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, Color(0.035, 0.065, 0.075))
	button.add_theme_font_size_override("font_size", 20)
	button.custom_minimum_size.y = 56


func _connect_non_battle_layout() -> void:
	if not resized.is_connected(_on_viewport_size_changed):
		resized.connect(_on_viewport_size_changed)
	if is_inside_tree() and not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	if GameManager == null or not GameManager.has_signal("non_battle_layout_mode_changed"):
		return
	var callback := Callable(self, "_on_non_battle_layout_mode_changed")
	if not GameManager.non_battle_layout_mode_changed.is_connected(callback):
		GameManager.non_battle_layout_mode_changed.connect(callback)


func _on_viewport_size_changed() -> void:
	_gesture_router.cancel()
	_apply_non_battle_layout()


func _on_non_battle_layout_mode_changed(_mode: String) -> void:
	_apply_non_battle_layout()


func _apply_non_battle_layout(viewport_size: Vector2 = Vector2.ZERO, forced_mode: String = "") -> void:
	var available_size := viewport_size
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		available_size = size if size.x > 0.0 and size.y > 0.0 else Vector2(1600, 900)
	var mode := forced_mode
	if mode.is_empty():
		mode = str(GameManager.get("non_battle_layout_mode")) if GameManager != null else "landscape"
	var mobile_like := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	var context: Dictionary = _non_battle_layout_controller.build_context(available_size, mode, mobile_like)
	var portrait := bool(context.get("is_portrait", false))
	var safe_rect := Rect2(Vector2.ZERO, available_size)
	if viewport_size == Vector2.ZERO:
		safe_rect = _device_content_rect(available_size)
		_layout_device_rect = safe_rect
	var margin := roundi(clampf(available_size.x * 0.025, 16.0, 32.0))
	var content_width := maxf(0.0, safe_rect.size.x - margin * 2.0)
	var single_column := portrait or content_width < WORKSPACE_COLUMN_MIN_WIDTH * 2.0 + WORKSPACE_COLUMN_GAP
	var touch_layout := portrait or mobile_like
	var keyboard_open := mobile_like and _active_workspace == WORKSPACE_SETTINGS and DisplayServer.virtual_keyboard_get_height() > 0
	%TopBarPanel.visible = not keyboard_open
	(find_child("TabBarPanel", true, false) as Control).visible = not keyboard_open
	%StatusStrip.visible = not keyboard_open
	set_meta("non_battle_layout_mode", str(context.get("resolved_mode", mode)))
	set_meta("strategy_hub_single_column", single_column)
	%LocalStrategyColumns.columns = 1 if single_column else 2
	%CatalogColumns.columns = 1
	for nested_scroll_name: String in ["LocalPackageScroll", "LocalReplayScroll", "CatalogScroll", "StrategyRankingScroll", "AuthorRankingScroll"]:
		var nested_scroll := find_child(nested_scroll_name, true, false) as ScrollContainer
		if nested_scroll != null:
			nested_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if single_column else ScrollContainer.SCROLL_MODE_AUTO
	for panel_name: String in ["PackageLibraryPanel", "PackageActionPanel", "CatalogPanel", "ReplayPanel"]:
		var panel := find_child(panel_name, true, false) as Control
		if panel != null:
			panel.custom_minimum_size.y = 0.0 if single_column else (450.0 if panel_name.begins_with("Package") else 540.0)
			panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if single_column else Control.SIZE_EXPAND_FILL
	%SafeArea.add_theme_constant_override("margin_left", margin + ceili(safe_rect.position.x))
	%SafeArea.add_theme_constant_override("margin_top", margin + ceili(safe_rect.position.y))
	%SafeArea.add_theme_constant_override("margin_right", margin + ceili(available_size.x - safe_rect.end.x))
	%SafeArea.add_theme_constant_override("margin_bottom", margin + ceili(available_size.y - safe_rect.end.y))
	%WorkspaceTabs.columns = 2 if content_width - 16.0 < 504.0 else 4
	%WorkspaceTabs.custom_minimum_size.y = 64.0 if touch_layout else 52.0
	%BackButton.custom_minimum_size = Vector2(56.0 if single_column else 104.0, 56.0 if touch_layout else 48.0)
	%RefreshButton.custom_minimum_size = %BackButton.custom_minimum_size
	%HeaderSubtitle.visible = not single_column
	var title := find_child("Title", true, false) as Label
	if title != null:
		title.add_theme_font_size_override("font_size", 24 if single_column else 32)
	for tab: Button in [%CatalogTab, %LocalStrategyTab, %ReplayTab, %AISettingsTab]:
		tab.add_theme_font_size_override("font_size", 18 if touch_layout else 16)
		tab.custom_minimum_size.y = 56.0 if touch_layout else 44.0
	for action: Button in [%ImportLocalPackageButton, %OpenBattleSetupButton]:
		action.custom_minimum_size.y = 64.0 if touch_layout else 52.0
	HUD_THEME_SCRIPT.apply_scrollbars_recursive(self, "touch" if touch_layout else "default")
	_portrait_context = context if portrait else {}
	if portrait:
		# Android keeps a 1600-wide logical canvas even on a portrait phone.
		# Scale text with that canvas instead of treating logical pixels as screen pixels.
		var text_scale := maxf(1.0, available_size.x / 1100.0)
		for metric: String in ["body_font_size", "section_font_size", "button_font_size", "input_font_size"]:
			_portrait_context[metric] = roundi(float(context.get(metric, 44)) * text_scale)
		if available_size.x < 850.0:
			for metric: String in ["body_font_size", "section_font_size", "button_font_size", "input_font_size"]:
				_portrait_context[metric] = maxi(22 if metric == "section_font_size" else 18, roundi(float(context[metric]) * available_size.x / 850.0))
			_portrait_context["secondary_button_height"] = maxf(44.0, float(context.secondary_button_height) * available_size.x / 850.0)
	_apply_readable_typography(self)
	%StatusDot.custom_minimum_size.x = %StatusDot.get_theme_font_size("font_size") * 1.1
	if portrait:
		for button: Button in [%BackButton, %RefreshButton]:
			button.custom_minimum_size.x = button.get_theme_font_size("font_size") * 2.0 + 44.0
	var dialog_width := safe_rect.size.x - margin * 2.0 if portrait else minf(safe_rect.size.x - margin * 2.0, 1040.0)
	var dialog_side := maxf(margin, (safe_rect.size.x - dialog_width) * 0.5)
	%DetailBounds.add_theme_constant_override("margin_left", roundi(safe_rect.position.x + dialog_side))
	%DetailBounds.add_theme_constant_override("margin_right", roundi(available_size.x - safe_rect.end.x + dialog_side))
	%DetailBounds.add_theme_constant_override("margin_top", roundi(safe_rect.position.y + margin))
	%DetailBounds.add_theme_constant_override("margin_bottom", roundi(available_size.y - safe_rect.end.y + margin))
	if portrait:
		var sheet_height := minf(safe_rect.size.y * 0.82, float(_portrait_context.get("body_font_size", 44)) * 28.0)
		var sheet_margin := maxf(margin, (safe_rect.size.y - sheet_height) * 0.5)
		%DetailBounds.add_theme_constant_override("margin_top", roundi(safe_rect.position.y + sheet_margin))
		%DetailBounds.add_theme_constant_override("margin_bottom", roundi(available_size.y - safe_rect.end.y + sheet_margin))
	%DetailScroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_apply_mobile_presentation()
	_strategy_deck_grid_width = -1
	_render_strategy_deck_preview()
	_layout_package_delete_dialog(available_size, safe_rect)


func _layout_package_delete_dialog(available_size: Vector2, safe_rect: Rect2) -> void:
	var margin := maxf(16.0, safe_rect.size.x * 0.03)
	%LocalPackageDeleteBounds.add_theme_constant_override("margin_left", roundi(safe_rect.position.x + margin))
	%LocalPackageDeleteBounds.add_theme_constant_override("margin_right", roundi(available_size.x - safe_rect.end.x + margin))
	%LocalPackageDeleteBounds.add_theme_constant_override("margin_top", roundi(safe_rect.position.y + margin))
	%LocalPackageDeleteBounds.add_theme_constant_override("margin_bottom", roundi(available_size.y - safe_rect.end.y + margin))
	var portrait := not _portrait_context.is_empty()
	%LocalPackageDeletePanel.custom_minimum_size.x = maxf(240.0, minf(safe_rect.size.x - margin * 2.0, safe_rect.size.x if portrait else 720.0))
	var body_font := int(_portrait_context.get("body_font_size", 20))
	%LocalPackageDeleteTitle.add_theme_font_size_override("font_size", int(_portrait_context.get("section_font_size", 28)))
	%LocalPackageDeleteMessage.add_theme_font_size_override("font_size", body_font)
	for button: Button in [%LocalPackageDeleteCancel, %LocalPackageDeleteConfirm]:
		button.add_theme_font_size_override("font_size", body_font)
		button.custom_minimum_size.y = maxf(52.0, float(_portrait_context.get("secondary_button_height", 52)))


func _apply_mobile_presentation() -> void:
	var compact := not _portrait_context.is_empty()
	for node_name: String in ["CatalogKicker", "CatalogTitle", "CatalogHint", "MarketplaceBoardTabs",
		"LocalPackageHint", "ImportKicker", "ImportTitle", "ImportSummary", "ValidationHint",
		"LocalPackageFolderRow", "ActionDivider", "BattleKicker", "BattleTitle", "BattleSummary",
		"OpenBattleSetupButton", "ActionSpacer", "LocalSafetyNote", "DetailKicker"]:
		var control := find_child(node_name, true, false) as Control
		if control == null:
			continue
		if not control.has_meta("hub_expanded_visible"):
			control.set_meta("hub_expanded_visible", control.visible)
		control.visible = not compact and bool(control.get_meta("hub_expanded_visible"))
	%CatalogTab.text = "AI天梯"
	%LocalStrategyTab.text = "已下载" if compact else "本地策略"
	%AISettingsTab.text = "DeepSeek"
	for tab: Button in [%CatalogTab, %LocalStrategyTab, %ReplayTab, %AISettingsTab]:
		_style_workspace_tab(tab, bool(tab.get_meta("hud_segment_active", false)))
	%ImportLocalPackageButton.text = "导入策略文件" if compact else "导入本地策略包"
	if compact:
		%WorkspaceTabs.columns = 4
		for control: Control in [%MatchHistoryDivider, %MatchHistoryTitle, %MatchHistoryList,
			%AuthorWorksDivider, %AuthorWorksTitle, %AuthorWorksList, %OfficialStats, %CommunityStats]:
			control.hide()
		var snapshot: Dictionary = _workspace_statuses.get(_active_workspace, {})
		%StatusStrip.visible = bool(snapshot.get("error", false))
		%DetailStatusLabel.visible = bool(snapshot.get("error", false))
	_update_detail_primary_action()
	_apply_desktop_presentation()


func _apply_desktop_presentation() -> void:
	var desktop := _portrait_context.is_empty()
	find_child("ReplayPanel", true, false).custom_minimum_size.y = 0
	find_child("ReplayPanel", true, false).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	find_child("LocalReplayScroll", true, false).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	%QuickActions.visible = desktop and _active_workspace in [WORKSPACE_CATALOG, WORKSPACE_LOCAL]
	%QuickImportButton.visible = desktop
	%DiscoveryGuide.text = "天梯排名 · 见证开发者实力，下载即可挑战" if _active_workspace == WORKSPACE_CATALOG else "选择已下载的策略，开始对战"
	# Keep service internals and file paths out of the player's main route.
	for node_name: String in ["HeaderSubtitle", "CatalogKicker", "CatalogTitle", "CatalogHint",
		"LocalPackageTitle", "LocalPackageHint", "ImportKicker", "ImportTitle", "ImportSummary",
		"ValidationHint", "LocalPackageFolderRow", "ActionDivider", "BattleKicker", "BattleTitle",
		"BattleSummary", "OpenBattleSetupButton", "ActionSpacer", "LocalSafetyNote", "DetailKicker"]:
		find_child(node_name, true, false).hide()
	find_child("LibraryKicker", true, false).show()
	find_child("LibraryKicker", true, false).text = "已下载策略"
	find_child("PackageActionPanel", true, false).visible = not desktop
	if desktop:
		%LocalStrategyColumns.columns = 1
		find_child("PackageLibraryPanel", true, false).custom_minimum_size.y = 0
		find_child("PackageLibraryPanel", true, false).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		find_child("LocalPackageScroll", true, false).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		find_child("CatalogPanel", true, false).custom_minimum_size.y = 0
		find_child("CatalogPanel", true, false).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		for scroll_name: String in ["CatalogScroll", "StrategyRankingScroll", "AuthorRankingScroll"]:
			find_child(scroll_name, true, false).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	for scroll_name: String in ["CatalogScroll", "StrategyRankingScroll"]:
		var inset := StyleBoxEmpty.new()
		inset.content_margin_right = 28 if desktop else 0
		find_child(scroll_name, true, false).add_theme_stylebox_override("panel", inset)
	%CatalogTab.text = "AI天梯"
	%LocalStrategyTab.text = "已下载"
	%AISettingsTab.text = "DeepSeek"
	%StrategyRankingBoardTab.text = "策略排名"
	%LatestBoardTab.text = "最新上架"
	%AuthorRankingBoardTab.text = "作者榜"
	%MarketplaceBoardStateLabel.hide()
	var snapshot: Dictionary = _workspace_statuses.get(_active_workspace, {})
	%StatusStrip.visible = bool(snapshot.get("error", false))
	%DetailStatusLabel.visible = bool(snapshot.get("error", false))
	if not _detail_extra_sections.is_empty():
		for node_name: String in _detail_extra_sections:
			find_child(node_name, true, false).visible = desktop and %DetailMoreButton.button_pressed and bool(_detail_extra_sections[node_name])
		%DetailMoreButton.visible = desktop
	if desktop and is_inside_tree() and %StrategyDetailOverlay.visible:
		var bounds := _device_content_rect(size)
		var margin := 32.0
		if _strategy_detail_deck == null and not %DetailMoreButton.button_pressed:
			margin = maxf(margin, (bounds.size.y - 520.0) * 0.5)
		%DetailBounds.add_theme_constant_override("margin_top", roundi(bounds.position.y + margin))
		%DetailBounds.add_theme_constant_override("margin_bottom", roundi(size.y - bounds.end.y + margin))


func _collapse_detail_history() -> void:
	_detail_extra_sections.clear()
	for node_name: String in ["MatchHistoryDivider", "MatchHistoryTitle", "MatchHistoryList", "AuthorWorksDivider", "AuthorWorksTitle", "AuthorWorksList", "OfficialStats", "CommunityStats"]:
		_detail_extra_sections[node_name] = find_child(node_name, true, false).visible
	%DetailMoreButton.set_pressed_no_signal(false)
	%DetailRoot.move_child(%DetailMoreButton, %ShadowStats.get_index() + 1)
	_on_detail_more_toggled(false)


func _on_detail_more_toggled(expanded: bool) -> void:
	%DetailMoreButton.text = "收起详细战绩" if expanded else "查看战绩与积分历史"
	_apply_desktop_presentation()


func _update_detail_primary_action() -> void:
	if _marketplace_download_button != null:
		return
	_refresh_install_action(%SelectedDownloadButton)


func _refresh_install_action(button: Button) -> void:
	if button == _marketplace_download_button or button == _quick_install_button:
		return
	var release: Dictionary = button.get_meta("continuous_ladder_installable_release", {})
	if release.is_empty():
		release = button.get_meta("installable_release", {})
	button.set_meta("start_strategy_ref", {})
	var listing: Dictionary = button.get_meta("ladder_listing", {})
	if release.is_empty() and listing.is_empty():
		return
	var record := _local_package_record_for_listing(release) if not release.is_empty() else _local_package_record_for_listing(listing)
	if not record.is_empty():
		var admission := _local_package_admission(record)
		var available := bool(admission.get("ok", false))
		if available:
			button.set_meta("start_strategy_ref", record.get("stable_ref", {}).duplicate(true))
		button.text = ("对战" if _portrait_context.is_empty() else "开战") if available else "已安装 · 暂不可开战"
		button.tooltip_text = ("使用本机已安装的 v%s 策略对战" % str(record.get("package_version", ""))) if available else _local_package_unavailable_text(admission)
		button.disabled = not available
	elif bool(button.get_meta("download_allowed", not button.disabled)):
		button.tooltip_text = ""
		button.text = "一键下载安装" if _portrait_context.is_empty() else "下载策略"
		button.disabled = false
	else:
		button.text = "暂不可开战"
		button.disabled = true


func _on_quick_import_pressed() -> void:
	_select_workspace(WORKSPACE_LOCAL)
	_on_import_local_package_pressed()


func _on_local_strategy_start(reference: Dictionary) -> void:
	# Resolve again at the moment of use; a deleted/replaced package must not retain authority.
	var record := _local_package_record_for_ref(reference)
	if record.is_empty() or not _local_package_can_start(record):
		_set_status(_local_package_unavailable_text(_local_package_admission(record)), true)
		return
	if not GameManager.set_author_strategy_selection(AUTHOR_SETUP_MODEL_SCRIPT.setup_selection_record(record)):
		_set_status("策略选择失败，请重新选择。", true)
		return
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
	GameManager.goto_battle_setup(reference)


func _configure_replay_platform(platform: String = OS.get_name()) -> void:
	_replays_enabled = platform not in ["Android", "Web"]
	%ReplayTab.show()
	%ReplayTab.text = "开发者"
	%DeveloperPortalButton.tooltip_text = DEVELOPER_PORTAL_URL
	%DeveloperDeviceHint.visible = not _replays_enabled
	for node_name: String in ["ReplayHeaderRow", "LocalReplayHint", "ReplayFolderRows", "ReplayDivider", "LocalReplayScroll"]:
		find_child(node_name, true, false).visible = _replays_enabled
	_set_catalog_legacy_replay_visible(_replays_enabled)
	%HeaderSubtitle.text = "管理策略 · 发现公开版本" if not _replays_enabled else "管理策略 · 回看实战 · 发现公开版本"


func _on_developer_portal_pressed() -> void:
	var result: int = _developer_portal_opener_override.call(DEVELOPER_PORTAL_URL) if _developer_portal_opener_override.is_valid() else OS.shell_open(DEVELOPER_PORTAL_URL)
	if result != OK:
		_set_workspace_status(WORKSPACE_REPLAYS, "无法打开浏览器，请访问 " + DEVELOPER_PORTAL_URL, true)


func _apply_readable_typography(node: Node) -> void:
	# Settings owns its own responsive typography; preserve that independent layout.
	if node == _ai_settings_content or node is Window or node == %StrategyDeckGrid:
		return
	if node is Label or node is Button:
		var control := node as Control
		if not control.has_meta("hub_base_font"):
			control.set_meta("hub_base_font", control.get_theme_font_size("font_size"))
			control.set_meta("hub_base_height", control.custom_minimum_size.y)
		var base_font := int(control.get_meta("hub_base_font"))
		var font := base_font
		var height := float(control.get_meta("hub_base_height"))
		if not _portrait_context.is_empty():
			font = maxi(base_font, int(_portrait_context.get("body_font_size", 44)))
			if node is Button:
				height = maxf(height, float(_portrait_context.get("secondary_button_height", 104)))
				(node as Button).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				if node.get_parent() is GridContainer:
					control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if node.name in ["Title", "StrategyTitle"]:
				font = int(_portrait_context.get("section_font_size", 52))
			if node is Label and node.name not in ["StatusDot", "LocalPackageCountLabel", "LocalReplayCountLabel"] and not node.has_meta("hub_keep_single_line"):
				(node as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		control.add_theme_font_size_override("font_size", font)
		if node.name == "LocalPackageRecordLabel":
			height = maxf(height, font * 1.4)
		control.custom_minimum_size.y = height
	for child: Node in node.get_children():
		_apply_readable_typography(child)


func _open_strategy_detail() -> void:
	_gesture_router.cancel()
	_detail_extra_sections.clear()
	%DetailMoreButton.hide()
	%DetailMoreButton.set_pressed_no_signal(false)
	%SelectedDownloadButton.set_meta("start_strategy_ref", {})
	%SelectedDownloadButton.set_meta("download_allowed", false)
	_clear_strategy_deck_preview()
	for node_name: String in ["StatsDivider", "StatsTitle", "OfficialStats", "ShadowStats", "CommunityStats"]:
		find_child(node_name, true, false).show()
	%StrategyDetailOverlay.show()
	%DetailStatusLabel.text = ""
	%DetailScroll.scroll_vertical = 0
	_apply_readable_typography(%StrategyDetailOverlay)
	if is_inside_tree():
		%CloseStrategyDetailButton.grab_focus()


func _close_strategy_detail() -> void:
	_gesture_router.cancel()
	%StrategyDetailOverlay.hide()
	_clear_strategy_deck_preview()


func _clear_strategy_deck_preview() -> void:
	_strategy_detail_ref = {}
	_strategy_detail_deck = null
	_strategy_deck_grid_width = -1
	%StrategyDeckSection.hide()
	_clear_children(%StrategyDeckGrid)


func _update_strategy_deck_preview(reference: Dictionary) -> void:
	_clear_strategy_deck_preview()
	_strategy_detail_ref = reference.duplicate(true)
	var record := _local_package_record_for_ref(reference)
	if record.is_empty():
		return
	%StrategyDeckSection.show()
	%StrategyDeckTitle.text = "暂时无法读取此策略的卡组，请重新导入策略。"
	var catalog: Variant = _package_preview_catalog_override if _package_preview_catalog_override != null else AuthorStrategyPackageCatalog
	if catalog == null or not catalog.has_method("request_match_handle"):
		return
	# Read-only inspection uses the exact installed archive; it grants no battle authority.
	var requested: Dictionary = catalog.request_match_handle(
		str(reference.get("package_id", "")), str(reference.get("package_version", "")), str(reference.get("archive_sha256", ""))
	)
	if not bool(requested.get("ok", false)):
		return
	var materialized: Dictionary = DECK_MATERIALIZER_SCRIPT.build(requested.get("handle"))
	if not bool(materialized.get("ok", false)):
		return
	_strategy_detail_deck = materialized.deck
	%StrategyDeckTitle.text = "策略卡组 · %d 张" % _strategy_detail_deck.total_cards
	_render_strategy_deck_preview()
	if not %DetailScroll.resized.is_connected(_render_strategy_deck_preview):
		%DetailScroll.resized.connect(_render_strategy_deck_preview, CONNECT_DEFERRED)


func _render_strategy_deck_preview() -> void:
	if _strategy_detail_deck == null:
		return
	var scrollbar := %DetailScroll.get_v_scroll_bar() as VScrollBar
	var scrollbar_width := maxi(24, ceili(maxf(scrollbar.size.x, scrollbar.get_combined_minimum_size().x)) + 8)
	var width := floori(%DetailScroll.size.x) - scrollbar_width
	if width <= 0:
		width = 160
	if width == _strategy_deck_grid_width:
		return
	_strategy_deck_grid_width = width
	_strategy_deck_view.populate_preview_grid(%StrategyDeckGrid, _strategy_detail_deck, width, not _portrait_context.is_empty())


func _on_local_strategy_detail(reference: Dictionary) -> void:
	var record := _local_package_record_for_ref(reference)
	if record.is_empty():
		return
	_open_strategy_detail()
	%StrategyTitle.text = str(record.get("display_name", "策略"))
	%AuthorLabel.text = "作者：%s" % str(record.get("author_name", "未知"))
	%SummaryLabel.text = str(record.get("summary", ""))
	%ReleaseLabel.text = "已下载 · %s" % str(record.get("package_version_label", ""))
	_set_catalog_legacy_replay_visible(false)
	_hide_marketplace_author_works()
	for node_name: String in ["MatchHistoryDivider", "MatchHistoryTitle", "MatchHistoryList", "StatsDivider", "StatsTitle", "OfficialStats", "ShadowStats", "CommunityStats"]:
		find_child(node_name, true, false).hide()
	%SelectedDownloadButton.set_meta("continuous_ladder_installable_release", {})
	%SelectedDownloadButton.set_meta("installable_release", reference.duplicate(true))
	%SelectedDownloadButton.set_meta("start_strategy_ref", {})
	%SelectedDownloadButton.visible = true
	%SelectedDownloadButton.text = "开战" if _local_package_can_start(record) else "暂不可开战"
	%SelectedDownloadButton.disabled = not _local_package_can_start(record)
	_update_detail_primary_action()
	_update_strategy_deck_preview(reference)


func _process(_delta: float) -> void:
	if OS.has_feature("android") or OS.has_feature("ios"):
		if _device_content_rect(size) != _layout_device_rect:
			_apply_non_battle_layout()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or %ReplayOverlay.visible:
		return
	if %LocalPackageDeleteDialog.visible:
		if event.is_action_pressed("ui_cancel"):
			_on_local_package_delete_canceled()
			get_viewport().set_input_as_handled()
			return
		_gesture_router.handle(%LocalPackageDeleteDialog, event)
		return
	if _active_workspace == WORKSPACE_SETTINGS and is_instance_valid(_ai_settings_content):
		var picker := _ai_settings_content.get("_model_picker_overlay") as Control
		if is_instance_valid(picker) and picker.visible:
			if event.is_action_pressed("ui_cancel"):
				_ai_settings_content.call("_hide_settings_model_picker")
				_gesture_router.cancel()
				get_viewport().set_input_as_handled()
				return
			_gesture_router.handle(picker, event)
			if event is InputEventMouseButton and not picker.get_global_rect().has_point(event.position):
				get_viewport().set_input_as_handled()
			return
	if %StrategyDetailOverlay.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_strategy_detail()
			get_viewport().set_input_as_handled()
			return
		_gesture_router.handle(%StrategyDetailOverlay, event)
	else:
		_gesture_router.handle(self, event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready() and %LocalPackageDeleteDialog.visible:
		_on_local_package_delete_canceled()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_gesture_router.cancel()


func _device_content_rect(available_size: Vector2) -> Rect2:
	var bounds := Rect2(Vector2.ZERO, available_size)
	if not is_inside_tree() or not (OS.has_feature("android") or OS.has_feature("ios")):
		return bounds
	var safe_screen := Rect2(DisplayServer.get_display_safe_area())
	if not safe_screen.has_area():
		safe_screen = get_screen_transform() * bounds
	var keyboard_height := DisplayServer.virtual_keyboard_get_height()
	if keyboard_height > 0 and _active_workspace == WORKSPACE_SETTINGS:
		safe_screen.end.y = minf(safe_screen.end.y, DisplayServer.screen_get_size().y - keyboard_height)
	# CanvasItem.get_screen_transform() does not include viewport stretch on Android.
	var local_to_screen := get_viewport().get_stretch_transform() * get_screen_transform()
	return content_rect_from_screen_safe_area(bounds, safe_screen, local_to_screen)


static func content_rect_from_screen_safe_area(bounds: Rect2, safe_screen: Rect2, local_to_screen: Transform2D) -> Rect2:
	var clipped := bounds.intersection(local_to_screen.affine_inverse() * safe_screen)
	return clipped if clipped.has_area() else bounds


func _responsive_row() -> GridContainer:
	var row := GridContainer.new()
	row.columns = 1
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	row.resized.connect(_reflow_row.bind(row))
	row.child_entered_tree.connect(func(_child: Node) -> void: _reflow_row.call_deferred(row))
	return row


func _reflow_row(row: GridContainer) -> void:
	if not is_instance_valid(row):
		return
	if not _portrait_context.is_empty():
		row.columns = 2 if row.has_meta("hub_primary_actions") else 1
		return
	var width_needed := 0.0
	var child_count := 0
	for child: Node in row.get_children():
		if child is Control and (child as Control).visible:
			var control := child as Control
			width_needed += maxf(control.get_combined_minimum_size().x, 240.0 if control is Label or control is Button and (control as Button).autowrap_mode != TextServer.AUTOWRAP_OFF else 0.0)
			child_count += 1
	row.columns = maxi(1, child_count) if row.size.x >= width_needed + maxf(0, child_count - 1) * 8.0 else 1


func apply_non_battle_layout_for_test(viewport_size: Vector2, mode: String) -> void:
	_apply_non_battle_layout(viewport_size, mode)


func select_workspace_for_test(workspace_id: String) -> void:
	_select_workspace(workspace_id)


func _initialize_service_after_first_frame(ready_started_usec: int) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var phase_started := Time.get_ticks_usec()
	_contracts_script = load(CONTRACTS_SCRIPT_PATH) as Script
	_record_startup_phase("contracts_script_load_msec", phase_started)
	await get_tree().process_frame
	phase_started = Time.get_ticks_usec()
	_client_script = load(CLIENT_SCRIPT_PATH) as Script
	_record_startup_phase("client_script_load_msec", phase_started)
	await get_tree().process_frame
	phase_started = Time.get_ticks_usec()
	_local_replay_library_script = load(LOCAL_REPLAY_LIBRARY_SCRIPT_PATH) as Script
	_record_startup_phase("local_library_script_load_msec", phase_started)
	var match_index_script := load(MATCH_RECORD_INDEX_SCRIPT_PATH) as Script
	if match_index_script != null and match_index_script.can_instantiate():
		_native_match_index = match_index_script.new()
	_initialize_service()
	_finish_startup_performance_trace(ready_started_usec)


func _initialize_service() -> void:
	var phase_started := Time.get_ticks_usec()
	if _contracts_script == null or _client_script == null or _local_replay_library_script == null:
		_set_workspace_status(WORKSPACE_CATALOG, "策略广场组件不可用。", true)
		return
	var contracts: Dictionary = _contracts_script.load_default()
	_record_startup_phase("contracts_msec", phase_started)
	if bool(contracts.get("accepted", false)):
		_contract_owner = contracts.get("owner")
		phase_started = Time.get_ticks_usec()
		_initialize_local_replay_library()
		_record_startup_phase("local_replays_msec", phase_started)
	else:
		phase_started = Time.get_ticks_usec()
		_refresh_local_replays()
		_record_startup_phase("local_replays_msec", phase_started)
		_set_workspace_status(WORKSPACE_REPLAYS, "本机录像契约不可用。", true)
	_base_url = str(ProjectSettings.get_setting(
		"ptcgdap/strategy_platform/base_url", "https://api.ptcg.skillserver.cn"
	)).strip_edges().trim_suffix("/")
	var development_override := OS.get_environment("PTCGDAP_PLATFORM_BASE_URL").strip_edges()
	if OS.is_debug_build() and not development_override.is_empty():
		_base_url = development_override.trim_suffix("/")
	_allow_insecure_loopback = OS.is_debug_build() and (
		_base_url.begins_with("http://127.0.0.1") or _base_url.begins_with("http://localhost")
	)
	_marketplace_ranking_profile_id = str(ProjectSettings.get_setting(
		"ptcgdap/strategy_platform/ranking_profile_id",
		""
	)).strip_edges()
	var profile_override := OS.get_environment(
		"PTCGDAP_MARKETPLACE_PROFILE_ID"
	).strip_edges()
	if OS.is_debug_build() and not profile_override.is_empty():
		_marketplace_ranking_profile_id = profile_override
	_continuous_ladder_mode = _marketplace_ranking_profile_id == "godot_v18_ladder_v1"
	if _continuous_ladder_mode:
		%LatestBoardTab.visible = false
		%StrategyRankingBoardTab.text = "策略积分榜"
		%AuthorRankingBoardTab.text = "开发者榜"
		_select_marketplace_board(MARKETPLACE_STRATEGY_RANKINGS, false)
	phase_started = Time.get_ticks_usec()
	var created: Dictionary = _client_script.create(null, _base_url, _allow_insecure_loopback)
	_record_startup_phase("client_create_msec", phase_started)
	if not bool(created.get("accepted", false)):
		_set_workspace_status(WORKSPACE_CATALOG, _service_error_text(str(created.get("error_code", "unknown"))), true)
		return
	_client = created.get("client") as Node
	add_child(_client)
	_client.request_completed.connect(_on_platform_request_completed)
	phase_started = Time.get_ticks_usec()
	if _marketplace_ranking_profile_id.is_empty() and _allow_insecure_loopback:
		_marketplace_profile_discovery_pending = true
		_set_workspace_status(WORKSPACE_CATALOG, "正在发现本地比赛配置…")
		var started: Dictionary = _client.list_competition_profiles(100)
		if not bool(started.get("accepted", false)):
			_marketplace_profile_discovery_pending = false
			_set_workspace_status(
				WORKSPACE_CATALOG,
				"本地比赛配置发现失败：%s" % str(started.get("error_code", "unknown")),
				true
			)
	else:
		_refresh_catalog()
	_record_startup_phase("catalog_request_msec", phase_started)


func startup_performance_snapshot() -> Dictionary:
	return _startup_performance.duplicate(true)


func _record_startup_phase(name: String, started_usec: int) -> void:
	_startup_performance[name] = roundi(float(maxi(0, Time.get_ticks_usec() - started_usec)) / 1000.0)


func _finish_startup_performance_trace(ready_started_usec: int) -> void:
	_record_startup_phase("ready_total_msec", ready_started_usec)
	_startup_performance["layout"] = {
		"size": str(size), "safe_area": str(DisplayServer.get_display_safe_area()),
		"screen_transform": str(get_screen_transform()), "device_rect": str(_layout_device_rect),
		"window_size": str(DisplayServer.window_get_size()),
	}
	if PERFORMANCE_TRACE_ARG in OS.get_cmdline_user_args():
		print("PTCGDAP_STRATEGY_HUB_STARTUP=" + JSON.stringify(_startup_performance))


func _initialize_local_replay_library() -> void:
	if _contract_owner == null:
		_refresh_local_replays()
		return
	var created: Dictionary = _local_replay_library_script.create(_contract_owner)
	if not bool(created.get("accepted", false)):
		_local_replay_library = null
		_refresh_local_replays()
		return
	_local_replay_library = created.get("library")
	_refresh_local_replays()


func _refresh_all() -> void:
	_refresh_local_replays()
	_refresh_local_packages(true)
	_refresh_catalog()


func _bind_local_package_catalog() -> void:
	if AuthorStrategyPackageCatalog == null or not AuthorStrategyPackageCatalog.has_signal("catalog_changed"):
		return
	var callback := Callable(self, "_apply_local_package_catalog")
	if not AuthorStrategyPackageCatalog.catalog_changed.is_connected(callback):
		AuthorStrategyPackageCatalog.catalog_changed.connect(callback)


func _refresh_local_packages(rescan: bool) -> void:
	if AuthorStrategyPackageCatalog == null:
		_apply_local_package_catalog({"metadata_records": [], "diagnostics": []})
		return
	if rescan:
		_apply_local_package_catalog(AuthorStrategyPackageCatalog.scan_startup())
		return
	_apply_local_package_catalog({
		"metadata_records": AuthorStrategyPackageCatalog.list_metadata_records(),
		"ready_records": AuthorStrategyPackageCatalog.list_ready_records(),
		"diagnostics": AuthorStrategyPackageCatalog.list_diagnostics(),
	})


func _apply_local_package_catalog(report: Dictionary) -> void:
	var view: Dictionary = AUTHOR_SETUP_MODEL_SCRIPT.normalize_catalog_report(report)
	_local_package_records.clear()
	for value: Variant in view.get("records", []):
		if value is Dictionary:
			_local_package_records.append((value as Dictionary).duplicate(true))
	_render_local_packages(int(view.get("diagnostic_count", 0)))
	for button: Node in find_children("*", "Button", true, false):
		if button.has_meta("installable_release") or button.has_meta("continuous_ladder_installable_release") or button.has_meta("ladder_listing"):
			_refresh_install_action(button as Button)
	if not _strategy_detail_ref.is_empty() and %StrategyDetailOverlay.visible:
		_update_strategy_deck_preview(_strategy_detail_ref.duplicate(true))


func _render_local_packages(diagnostic_count: int) -> void:
	_clear_children(%LocalPackageList)
	%LocalPackageCountLabel.text = "%d 个" % _local_package_records.size()
	if _local_package_records.is_empty():
		%LocalPackageList.add_child(_empty_state_card(
			"还没有本地策略", "导入一个 .ptcgai 文件后，会在这里显示。"
		))
	else:
		for record: Dictionary in _local_package_records:
			var admission := _local_package_admission(record)
			var available := bool(admission.get("ok", false))
			var unavailable_reason := AUTHOR_WINDOWS_GATE_SCRIPT.PlatformCapabilitiesScript.error_text(str(admission.get("error_code", "")))
			var source_label := "内置 + 用户目录" if record.get("install_sources", []).size() > 1 else (
				"用户目录" if record.get("install_source") == "user" else "内置"
			)
			var card := PanelContainer.new()
			card.name = "LocalPackageCard"
			card.add_theme_stylebox_override("panel", _list_card_style(
				Color(0.40, 0.94, 0.68) if available else Color(0.32, 0.72, 0.88)
			))
			var content := VBoxContainer.new()
			content.add_theme_constant_override("separation", 5)
			card.add_child(content)
			var header := _responsive_row()
			header.add_theme_constant_override("separation", 10)
			content.add_child(header)
			var title := Label.new()
			title.name = "LocalPackageRecordLabel"
			title.text = str(record.get("display_label", record.get("display_name", "未命名策略")))
			title.text = str(record.get("short_display_name", record.get("display_name", "未命名策略")))
			title.tooltip_text = "完整名称：%s" % str(record.get("display_name", "未命名策略"))
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			title.add_theme_font_size_override("font_size", 18)
			title.add_theme_color_override("font_color", HUD_THEME_SCRIPT.TEXT)
			header.add_child(title)
			var badge := Label.new()
			badge.set_meta("hub_keep_single_line", true)
			badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			badge.text = "可对战" if available else "待就绪"
			badge.add_theme_color_override("font_color", Color(0.05, 0.12, 0.11) if available else HUD_THEME_SCRIPT.TEXT)
			badge.add_theme_stylebox_override("normal", _pill_style(
				Color(0.40, 0.94, 0.68) if available else Color(0.18, 0.42, 0.54), available
			))
			header.add_child(badge)
			var meta := Label.new()
			meta.text = "%s · %s" % [record.get("author_name", "未知作者"), record.get("deck_name", "未命名卡组")]
			meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			meta.add_theme_color_override("font_color", HUD_THEME_SCRIPT.TEXT_MUTED)
			content.add_child(meta)
			var readiness := Label.new()
			readiness.text = "已加载 · %s · %s" % [
				source_label,
				"可在 AI 对战中开战" if available else (
					unavailable_reason if not unavailable_reason.is_empty() else "可选择，暂不可开战"
				),
			]
			readiness.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			readiness.add_theme_color_override("font_color", Color(0.68, 0.98, 0.79) if available else Color(0.74, 0.86, 0.94))
			content.add_child(readiness)
			badge.hide()
			readiness.visible = not available
			if not _portrait_context.is_empty():
				badge.hide()
				meta.text = "%s · %s" % [record.get("author_name", "未知作者"), record.get("package_version_label", "")]
				readiness.visible = not available
			var actions := _responsive_row()
			actions.set_meta("hub_primary_actions", true)
			content.add_child(actions)
			var start_button := Button.new()
			start_button.name = "LocalPackageStartButton"
			start_button.text = ("对战" if _portrait_context.is_empty() else "开战") if available else "暂不可开战"
			start_button.disabled = not available
			start_button.pressed.connect(_on_local_strategy_start.bind(record.get("stable_ref", {}).duplicate(true)))
			_style_action_button(start_button, Color(0.40, 0.94, 0.68))
			_style_primary_button(start_button)
			actions.add_child(start_button)
			var detail_button := Button.new()
			detail_button.name = "LocalPackageDetailButton"
			detail_button.text = "查看详情"
			detail_button.pressed.connect(_on_local_strategy_detail.bind(record.get("stable_ref", {}).duplicate(true)))
			_style_action_button(detail_button, HUD_THEME_SCRIPT.ACCENT)
			actions.add_child(detail_button)
			var delete_button := Button.new()
			delete_button.name = "LocalPackageDeleteButton"
			delete_button.text = "删除策略"
			delete_button.tooltip_text = "从这台设备的游戏策略列表中删除；重新导入同一策略可以恢复。"
			delete_button.custom_minimum_size = Vector2(132, 40)
			delete_button.disabled = _local_package_import_busy
			delete_button.pressed.connect(
				_on_local_package_delete_requested.bind(
					record.get("stable_ref", {}).duplicate(true)
				)
			)
			_style_action_button(delete_button, Color(0.94, 0.34, 0.32))
			actions.add_child(delete_button)
			# Keep removal secondary and collapsed until explicitly requested.
			delete_button.hide()
			var more_button := Button.new()
			more_button.name = "LocalPackageMoreButton"
			more_button.text = "管理"
			more_button.toggle_mode = true
			more_button.toggled.connect(func(expanded: bool) -> void: delete_button.visible = expanded)
			actions.add_child(more_button)
			%LocalPackageList.add_child(card)
	if diagnostic_count > 0:
		%LocalPackageList.add_child(_notice_card(
			"已跳过 %d 个无效或冲突的策略包" % diagnostic_count,
			"现有策略与用户目录未被覆盖。", true
		))
	_set_workspace_status(
		WORKSPACE_LOCAL,
		"本机已加载 %d 个策略包%s。" % [
			_local_package_records.size(),
			"，并安全跳过 %d 个异常项" % diagnostic_count if diagnostic_count > 0 else "",
		]
	)


func _local_package_can_start(record: Dictionary) -> bool:
	return bool(_local_package_admission(record).get("ok", false))


func _local_package_unavailable_text(admission: Dictionary) -> String:
	var reason := AUTHOR_WINDOWS_GATE_SCRIPT.PlatformCapabilitiesScript.error_text(str(admission.get("error_code", "")))
	return reason if not reason.is_empty() else "该策略尚未通过本地运行校验，请选择其他策略。"


func _local_package_admission(record: Dictionary) -> Dictionary:
	if AuthorStrategyPackageCatalog == null:
		return {"ok":false, "error_code":"package_catalog_unavailable"}
	var selection := AUTHOR_SETUP_MODEL_SCRIPT.setup_selection_record(record)
	return AUTHOR_WINDOWS_GATE_SCRIPT.evaluate_selection(
		AuthorStrategyPackageCatalog, selection
	)


func _on_import_local_package_pressed() -> void:
	if _local_package_import_busy:
		return
	_local_package_import_generation += 1
	_local_package_picker_pending = true
	%LocalPackageFileDialog.popup_centered_ratio(0.82)


func _on_local_package_file_selected(path: String) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not _local_package_picker_pending or _local_package_import_busy:
		return
	_local_package_picker_pending = false
	var catalog_owner: Variant = _package_install_catalog_override if _package_install_catalog_override != null else AuthorStrategyPackageCatalog
	if catalog_owner == null or not catalog_owner.has_method("install_local_bytes"):
		_set_workspace_status(WORKSPACE_LOCAL, _local_package_error_text("package_catalog_unavailable"), true)
		return
	_local_package_import_busy = true
	_set_busy(true)
	_set_workspace_status(WORKSPACE_LOCAL, "正在读取所选策略包…")
	_local_package_read_task = _local_package_read_task_override if _local_package_read_task_override != null else LOCAL_PACKAGE_READ_TASK_SCRIPT.new()
	_local_package_read_task.connect("completed", _on_local_package_source_read.bind(_local_package_import_generation), CONNECT_ONE_SHOT)
	var start_error: Error = _local_package_read_task.call("start", path)
	if start_error != OK:
		_cancel_local_package_capture()
		_set_workspace_status(WORKSPACE_LOCAL, _local_package_error_text("package_file_read_failed"), true)


func _on_local_package_source_read(captured: Dictionary, generation: int) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or generation != _local_package_import_generation or _local_package_read_task == null:
		return
	_local_package_read_task = null
	var result := captured
	if bool(captured.get("ok", false)):
		var catalog_owner: Variant = _package_install_catalog_override if _package_install_catalog_override != null else AuthorStrategyPackageCatalog
		_set_workspace_status(WORKSPACE_LOCAL, "正在验证策略包格式、签名、兼容性和完整牌表…")
		# Installation, catalog validation and CardDatabase access stay on the
		# main thread. No await separates the current-request check and install.
		result = catalog_owner.install_local_bytes(captured.get("archive_bytes", PackedByteArray())) if catalog_owner != null else {"ok": false, "error_code": "package_catalog_unavailable"}
	_local_package_import_busy = false
	_set_busy(false)
	if not bool(result.get("ok", false)):
		_set_workspace_status(WORKSPACE_LOCAL, _local_package_error_text(str(result.get("error_code", "package_install_failed"))), true)
		return
	_apply_local_package_catalog(result.get("catalog_report", {}))
	var metadata: Dictionary = result.get("metadata", {})
	var strategy: Dictionary = metadata.get("strategy", {}) if metadata.get("strategy", {}) is Dictionary else {}
	var display_name := str(strategy.get("display_name", metadata.get("package_id", "策略包")))
	_set_workspace_status(WORKSPACE_LOCAL,
		"%s 已在用户目录中，无需重复复制；现在可在 AI 对战的“AI 卡组”中选择。" % display_name
		if bool(result.get("already_installed", false)) else
		"%s 已通过验证并加载；现在可在 AI 对战的“AI 卡组”中选择。" % display_name
	)


func _on_local_package_file_canceled() -> void:
	_cancel_local_package_capture()
	if is_inside_tree():
		_set_workspace_status(WORKSPACE_LOCAL, "已取消导入策略包。")


func _cancel_local_package_capture(update_controls: bool = true) -> void:
	_local_package_import_generation += 1
	_local_package_picker_pending = false
	if _local_package_read_task != null:
		_local_package_read_task.call("cancel")
		_local_package_read_task = null
	_local_package_import_busy = false
	if update_controls and is_inside_tree():
		_set_busy(false)


func _exit_tree() -> void:
	_cancel_local_package_capture(false)


func _on_local_package_delete_requested(reference: Dictionary) -> void:
	if _local_package_import_busy:
		return
	var record := _local_package_record_for_ref(reference)
	if record.is_empty():
		_set_workspace_status(WORKSPACE_LOCAL, "该策略已不在游戏目录中。", true)
		return
	_pending_local_package_delete_ref = AUTHOR_SETUP_MODEL_SCRIPT.stable_ref(record)
	_gesture_router.cancel()
	var display_name := str(record.get("short_display_name", record.get("display_name", "该策略")))
	%LocalPackageDeleteMessage.text = (
		"确认从游戏中删除“%s”吗？\n删除后它会从 AI 对手列表中消失；重新导入同一策略可以恢复。" % display_name
	)
	%LocalPackageDeleteDialog.show()
	move_child(%LocalPackageDeleteDialog, get_child_count() - 1)
	if is_inside_tree():
		%LocalPackageDeleteCancel.grab_focus()


func _on_local_package_delete_confirmed() -> void:
	if _pending_local_package_delete_ref.is_empty():
		return
	var reference := _pending_local_package_delete_ref.duplicate(true)
	_on_local_package_delete_canceled()
	var catalog_owner: Variant = (
		_package_delete_catalog_override
		if _package_delete_catalog_override != null else AuthorStrategyPackageCatalog
	)
	if _local_package_import_busy or catalog_owner == null:
		return
	var record := _local_package_record_for_ref(reference)
	if record.is_empty():
		_set_workspace_status(WORKSPACE_LOCAL, "策略已发生变化，请刷新后重试。", true)
		return
	_local_package_import_busy = true
	_set_busy(true)
	_set_workspace_status(WORKSPACE_LOCAL, "正在从游戏中删除策略…")
	var tree := get_tree() if is_inside_tree() else null
	if tree != null:
		await tree.process_frame
		if not is_inside_tree():
			return
	var result: Dictionary = catalog_owner.remove_package(
		str(reference.get("package_id", "")),
		str(reference.get("package_version", "")),
		str(reference.get("archive_sha256", ""))
	)
	_local_package_import_busy = false
	_set_busy(false)
	if not bool(result.get("ok", false)):
		_set_workspace_status(
			WORKSPACE_LOCAL,
			_local_package_error_text(str(result.get("error_code", "package_remove_failed"))),
			true
		)
		return
	_apply_local_package_catalog(result.get("catalog_report", {}))
	if (
		AUTHOR_SETUP_MODEL_SCRIPT.same_ref(GameManager.get_author_strategy_selection(), reference)
		and not bool(result.get("catalog_discoverable", false))
	):
		GameManager.reset_author_strategy_selection()
	var display_name := str(record.get("short_display_name", record.get("display_name", "策略")))
	var status_text := "%s 已从游戏中删除。" % display_name
	if bool(result.get("cleanup_pending", false)):
		status_text += " 策略已停止加载，但有一个临时清理文件尚未删除。"
	_set_workspace_status(WORKSPACE_LOCAL, status_text)


func _on_local_package_delete_canceled() -> void:
	_pending_local_package_delete_ref = {}
	%LocalPackageDeleteDialog.hide()
	_gesture_router.cancel()
	if is_inside_tree() and %LocalStrategyTab.is_visible_in_tree():
		%LocalStrategyTab.grab_focus()


func _local_package_record_for_listing(item: Dictionary) -> Dictionary:
	# Offer a local opponent, not proof of byte equality with a ranked release.
	# Prefer its listed version; a unique other local version is also playable.
	var package_id := str(item.get("package_id", ""))
	var version := str(item.get("package_version", ""))
	if package_id.is_empty() or version.is_empty():
		return {}
	var versions: Array[Dictionary] = []
	var matches: Array[Dictionary] = []
	for record: Dictionary in _local_package_records:
		if record.get("package_id") == package_id:
			versions.append(record)
			if record.get("package_version") == version:
				matches.append(record)
	if not matches.is_empty():
		if item.has("archive_sha256"):
			return _local_package_record_for_ref(item)
		return matches[0].duplicate(true) if matches.size() == 1 else {}
	return versions[0].duplicate(true) if versions.size() == 1 else {}


func _local_package_record_for_ref(reference: Dictionary) -> Dictionary:
	for record: Dictionary in _local_package_records:
		if AUTHOR_SETUP_MODEL_SCRIPT.same_ref(record.get("stable_ref", {}), reference):
			return record.duplicate(true)
	return {}


func _local_package_error_text(error_code: String) -> String:
	var messages := {
		"package_file_missing": "没有读取到所选文件，请重新选择。",
		"package_file_read_failed": "所选文件读取失败，请确认文件可用后重新选择。",
		"package_import_canceled": "已取消导入策略包。",
		"package_archive_invalid": "策略包不是有效的 .ptcgai 文件。",
		"package_manifest_invalid": "策略包清单格式不正确。",
		"package_integrity_invalid": "策略包完整性校验失败，未写入任何文件。",
		"package_signature_untrusted": "策略包签名无法验证。",
		"package_file_hash_mismatch": "策略包内容与清单哈希不一致。",
		"package_file_unlisted": "策略包包含清单未声明的额外文件。",
		"package_contract_incompatible": "策略包与当前游戏接口版本不兼容。",
		"package_catalog_incompatible": "策略包使用的卡牌目录版本与当前游戏不兼容。",
		"package_policy_unsupported": "策略包使用了当前游戏不支持的策略格式。",
		"package_resource_limit_exceeded": "策略包过大或超过安全资源限制。",
		"package_deck_invalid": "策略包牌表格式不正确或不是完整 60 张。",
		"package_deck_unmapped": "策略包牌表中存在当前游戏没有的卡牌，或牌表不完整。",
		"package_install_identity_conflict": "相同包 ID 和版本已经存在，但文件内容不同。请让作者提升版本号。",
		"package_install_destination_conflict": "用户目录中已有冲突文件，未覆盖任何内容。",
		"package_install_user_data_unavailable": "游戏用户目录不可用，未写入任何文件。",
		"package_install_catalog_refresh_failed": "文件写入后未能通过目录复验，已自动回滚。",
		"package_install_failed": "策略包写入失败，未修改现有文件。",
		"package_remove_reference_invalid": "删除请求中的策略身份无效，未删除任何文件。",
		"package_remove_not_found": "没有找到完全匹配的策略，未删除任何内容。",
		"package_removal_store_invalid": "内置策略移除记录损坏，未删除任何策略。",
		"package_removal_store_unavailable": "无法保存内置策略移除记录，未删除任何策略。",
		"package_removal_store_busy": "策略移除记录正在使用，请稍后重试。",
		"package_removal_store_write_failed": "无法写入策略移除记录，未删除任何策略。",
		"package_remove_verification_failed": "删除前复验策略包失败，未删除任何文件。",
		"package_remove_catalog_refresh_failed": "删除后的目录复验失败，策略包已自动恢复。",
		"package_remove_rollback_failed": "删除失败且自动恢复不完整，请刷新目录后检查。",
		"package_remove_failed": "策略包删除失败，原文件已保留。",
		"package_catalog_unavailable": "本地策略包目录暂时不可用。",
		"author_strategy_feature_disabled": "本地策略包功能当前已停用。",
	}
	return str(messages.get(error_code, "策略包加载失败（%s），未修改现有目录。" % error_code))


func _on_open_battle_setup_pressed() -> void:
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.goto_battle_setup()


func _refresh_local_replays() -> void:
	if not _replays_enabled:
		return
	var native_rows: Array = _native_match_index.list_rows() if _native_match_index != null else []
	var public_rows: Array = []
	var rejected_count := 0
	if _local_replay_library != null:
		var listed: Dictionary = _local_replay_library.list_replays()
		if bool(listed.get("accepted", false)):
			public_rows = listed.get("entries", [])
			rejected_count = int(listed.get("rejected_count", 0))
		else:
			_set_workspace_status(WORKSPACE_REPLAYS, "公开旁观记录读取失败：%s" % str(listed.get("error_code", "unknown")), true)
	_render_local_replays(native_rows, public_rows, rejected_count)


func _refresh_catalog() -> void:
	if _client == null:
		return
	_marketplace_cursors[_active_marketplace_board] = null
	_request_marketplace_board("")


func _request_marketplace_board(cursor: String) -> void:
	if _client == null:
		return
	_set_workspace_status(
		WORKSPACE_CATALOG,
		"正在读取 Godot 18.0 持续联赛…" if _continuous_ladder_mode else "正在读取策略广场…"
	)
	%MarketplaceBoardStateLabel.text = "正在加载…"
	_set_busy(true)
	var started: Dictionary
	if _continuous_ladder_mode:
		if _active_marketplace_board == MARKETPLACE_AUTHOR_RANKINGS:
			started = _client.list_continuous_ladder_authors()
		else:
			started = _client.list_continuous_ladder_leaderboard()
	elif _active_marketplace_board == MARKETPLACE_STRATEGY_RANKINGS:
		started = _client.list_marketplace_strategy_rankings(
			_marketplace_ranking_profile_id, 24, cursor
		)
	elif _active_marketplace_board == MARKETPLACE_AUTHOR_RANKINGS:
		started = _client.list_marketplace_author_rankings(
			_marketplace_ranking_profile_id, 24, cursor
		)
	else:
		started = _client.list_marketplace_latest(24, cursor)
	if not bool(started.get("accepted", false)):
		_set_busy(false)
		_set_workspace_status(WORKSPACE_CATALOG, "读取失败：%s" % str(started.get("error_code", "unknown")), true)
		%MarketplaceBoardStateLabel.text = "加载失败，可点击刷新重试"


func _on_marketplace_next_page() -> void:
	var cursor: Variant = _marketplace_cursors.get(_active_marketplace_board)
	if cursor is String and not str(cursor).is_empty():
		_request_marketplace_board(str(cursor))


func _on_platform_request_completed(result: Dictionary) -> void:
	_set_busy(false)
	var operation := str(_client.audit_snapshot().get("operation", "")) if _client != null else ""
	if not bool(result.get("accepted", false)):
		if operation in [
			"marketplace_package_download", "continuous_ladder_package_download"
		]:
			_finish_marketplace_download_button(false)
		if operation == "continuous_ladder_release_profile":
			_reset_quick_install("重试下载")
		if operation == "continuous_ladder_series_replay":
			_finish_continuous_ladder_replay_download_button(false)
		_set_workspace_status(WORKSPACE_CATALOG, _service_error_text(str(result.get("error_code", "unknown"))), true)
		%MarketplaceBoardStateLabel.text = "加载失败，可点击刷新重试"
		return
	match operation:
		"competition_profiles":
			_apply_competition_profiles(result.get("items", []))
		"continuous_ladder_leaderboard":
			_apply_continuous_ladder_leaderboard(
				result.get("items", []), str(result.get("profile_id", ""))
			)
		"continuous_ladder_authors":
			_apply_continuous_ladder_authors(
				result.get("items", []), str(result.get("profile_id", ""))
			)
		"continuous_ladder_release_profile":
			_apply_continuous_ladder_release_profile(result.get("profile", {}))
		"continuous_ladder_author_profile":
			_apply_continuous_ladder_author_profile(result.get("profile", {}))
		"continuous_ladder_series_replay":
			_apply_continuous_ladder_series_replay(result.get("replay", {}))
		"catalog":
			_apply_catalog(result.get("items", []))
		"detail":
			_apply_detail(result.get("detail", {}))
		"statistics":
			_apply_statistics(result.get("statistics", {}))
		"challenge":
			_apply_challenge_intent(result.get("intent", {}))
		"marketplace_latest":
			_apply_marketplace_latest(result.get("items", []), result.get("next_cursor"))
		"marketplace_strategy_rankings":
			_apply_marketplace_strategy_rankings(
				result.get("items", []), result.get("next_cursor"),
				str(result.get("ranking_snapshot_id", ""))
			)
		"marketplace_author_rankings":
			_apply_marketplace_author_rankings(
				result.get("items", []), result.get("next_cursor"),
				str(result.get("ranking_snapshot_id", ""))
			)
		"marketplace_author_strategies":
			_apply_marketplace_author_strategies(
				result.get("author", {}), result.get("items", [])
			)
		"marketplace_strategy_archive":
			_apply_marketplace_strategy_archive(
				result.get("strategy", {}), result.get("recent_matches", [])
			)
		"marketplace_author_top_strategies":
			_apply_marketplace_author_top_strategies(
				result.get("author", {}), result.get("items", [])
			)
		"marketplace_package_download":
			_apply_marketplace_package_download(result)
		"continuous_ladder_package_download":
			_apply_marketplace_package_download(result)


func _apply_competition_profiles(items: Array) -> void:
	_marketplace_profile_discovery_pending = false
	var active_profiles: Array[Dictionary] = []
	for item_value: Variant in items:
		if item_value is Dictionary and item_value.get("state") == "active":
			active_profiles.append((item_value as Dictionary).duplicate(true))
	if active_profiles.size() != 1:
		_set_workspace_status(
			WORKSPACE_CATALOG,
			"本地服务必须且只能有一个启用中的比赛配置；当前为 %d 个。" % active_profiles.size(),
			true
		)
		%MarketplaceBoardStateLabel.text = "比赛配置不可用"
		return
	_marketplace_ranking_profile_id = str(active_profiles[0].get("profile_id", ""))
	_refresh_catalog()


func _select_marketplace_board(board_id: String, request_if_empty: bool = true) -> void:
	var normalized := board_id if board_id in [
		MARKETPLACE_LATEST,
		MARKETPLACE_STRATEGY_RANKINGS,
		MARKETPLACE_AUTHOR_RANKINGS,
	] else MARKETPLACE_LATEST
	if _continuous_ladder_mode and normalized == MARKETPLACE_LATEST:
		normalized = MARKETPLACE_STRATEGY_RANKINGS
	_active_marketplace_board = normalized
	%CatalogScroll.visible = normalized == MARKETPLACE_LATEST
	%StrategyRankingScroll.visible = normalized == MARKETPLACE_STRATEGY_RANKINGS
	%AuthorRankingScroll.visible = normalized == MARKETPLACE_AUTHOR_RANKINGS
	if normalized != MARKETPLACE_AUTHOR_RANKINGS:
		_hide_marketplace_author_works()
	for entry: Dictionary in [
		{"button": %LatestBoardTab, "board": MARKETPLACE_LATEST},
		{"button": %StrategyRankingBoardTab, "board": MARKETPLACE_STRATEGY_RANKINGS},
		{"button": %AuthorRankingBoardTab, "board": MARKETPLACE_AUTHOR_RANKINGS},
	]:
		_style_workspace_tab(
			entry.get("button") as Button, str(entry.get("board")) == normalized
		)
	var cursor: Variant = _marketplace_cursors.get(normalized)
	%MarketplaceNextButton.visible = cursor is String and not str(cursor).is_empty()
	%MarketplaceBoardStateLabel.text = (
		{
			MARKETPLACE_STRATEGY_RANKINGS: "按服务端积分从高到低排列",
			MARKETPLACE_AUTHOR_RANKINGS: "每位开发者只取当前 active 版本中的最佳策略",
		}.get(normalized, "")
		if _continuous_ladder_mode else {
			MARKETPLACE_LATEST: "按首次发布时间倒序",
			MARKETPLACE_STRATEGY_RANKINGS: "按冻结的服务端比赛快照排序",
			MARKETPLACE_AUTHOR_RANKINGS: "贡献分 = 所选比赛配置下的平均比赛奖励",
		}.get(normalized, "")
	)
	if not request_if_empty or _client == null:
		return
	var list: VBoxContainer = {
		MARKETPLACE_LATEST: %StrategyList,
		MARKETPLACE_STRATEGY_RANKINGS: %StrategyRankingList,
		MARKETPLACE_AUTHOR_RANKINGS: %AuthorRankingList,
	}.get(normalized)
	if list != null and list.get_child_count() == 0:
		_request_marketplace_board("")


func _apply_marketplace_latest(items: Array, next_cursor: Variant) -> void:
	_clear_children(%StrategyList)
	if items.is_empty():
		%StrategyList.add_child(_empty_state_card(
			"暂无已发布策略", "服务端当前没有可展示的已发布设备策略。"
		))
	for item_value: Variant in items:
		if item_value is Dictionary:
			%StrategyList.add_child(_marketplace_strategy_row(item_value, ""))
	_set_marketplace_page_state(MARKETPLACE_LATEST, next_cursor, items.size())
	_set_workspace_status(
		WORKSPACE_CATALOG,
		"已加载 %d 个最新策略；下载后仍会在本机完整复验。" % items.size()
	)


func _apply_marketplace_strategy_rankings(
	items: Array,
	next_cursor: Variant,
	snapshot_id: String
) -> void:
	_clear_children(%StrategyRankingList)
	if items.is_empty():
		%StrategyRankingList.add_child(_empty_state_card(
			"暂无策略排行", "当前比赛配置还没有可发布的冻结排行快照。"
		))
	for item_value: Variant in items:
		if not item_value is Dictionary:
			continue
		var item := item_value as Dictionary
		var prefix := "Kaggle 分 %.3f · 胜率 %.1f%% · %d 场%s" % [
			float(item.get("kaggle_score_micros", 0)) / 1000000.0,
			float(item.get("win_rate_micros", 0)) / 10000.0,
			int(item.get("games", 0)),
			" · 暂定" if bool(item.get("provisional", false)) else "",
		]
		var card := _marketplace_strategy_row(item, prefix)
		_decorate_ladder_rank(card, item)
		%StrategyRankingList.add_child(card)
	_set_marketplace_page_state(MARKETPLACE_STRATEGY_RANKINGS, next_cursor, items.size())
	_set_workspace_status(
		WORKSPACE_CATALOG,
		"策略排行已锁定快照 %s；只有经过显式验证绑定的设备版才能下载。" % snapshot_id
	)


func _apply_continuous_ladder_leaderboard(items: Array, profile_id: String) -> void:
	_clear_children(%StrategyRankingList)
	if items.is_empty():
		%StrategyRankingList.add_child(_empty_state_card(
			"暂无联赛积分", "当前持续联赛还没有 active 策略。"
		))
	for item_value: Variant in items:
		if item_value is Dictionary:
			%StrategyRankingList.add_child(
				_continuous_ladder_release_card(item_value as Dictionary)
			)
	_set_marketplace_page_state(MARKETPLACE_STRATEGY_RANKINGS, null, items.size())
	_set_workspace_status(
		WORKSPACE_CATALOG,
		"已连接 %s：显示 %d 个 active 策略的联赛实时积分；试跑赛季当前已停赛。" % [
			profile_id, items.size()
		]
	)


func _apply_continuous_ladder_authors(items: Array, profile_id: String) -> void:
	_clear_children(%AuthorRankingList)
	if items.is_empty():
		%AuthorRankingList.add_child(_empty_state_card(
			"暂无开发者排名", "当前持续联赛还没有开发者策略积分。"
		))
	for item_value: Variant in items:
		if not item_value is Dictionary:
			continue
		var item := item_value as Dictionary
		var card := PanelContainer.new()
		card.name = "ContinuousLadderAuthorCard"
		card.add_theme_stylebox_override(
			"panel", _list_card_style(Color(0.72, 0.54, 0.98))
		)
		var button := Button.new()
		button.name = "ContinuousLadderAuthorButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "#%d  %s\n%s%s\n最佳版本：%s · 点击查看作者档案" % [
			int(item.get("rank", 0)),
			str(item.get("author_display_name", item.get("developer_id", "未知开发者"))),
			_format_ladder_score(float(item.get("mu", 0.0))),
			" · 暂定" if bool(item.get("provisional", false)) else "",
			str(item.get("display_name", item.get("release_id", "未知版本"))),
		]
		button.set_meta("continuous_ladder_author", item.duplicate(true))
		button.pressed.connect(_on_continuous_ladder_author_pressed.bind(button))
		_style_strategy_button(button, false)
		card.add_child(button)
		_decorate_ladder_rank(card, item)
		%AuthorRankingList.add_child(card)
	_set_marketplace_page_state(MARKETPLACE_AUTHOR_RANKINGS, null, items.size())
	_set_workspace_status(
		WORKSPACE_CATALOG,
		"已连接 %s：作者榜只统计开发者 active 版本，游戏内置 NPC 不进入作者榜。" % profile_id
	)


func _continuous_ladder_release_card(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "ContinuousLadderReleaseCard"
	var npc: bool = item.get("owner_kind") == "platform_npc"
	var accent := Color(0.95, 0.66, 0.28) if npc else Color(0.30, 0.78, 0.94)
	card.add_theme_stylebox_override("panel", _list_card_style(accent))
	var button := Button.new()
	button.name = "ContinuousLadderReleaseButton"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var title := str(item.get("display_name", "")).strip_edges()
	if title.is_empty():
		title = (
			"平台 NPC · %s" % str(item.get("owner_id", item.get("release_id", "未知")))
			if npc else str(item.get("release_id", "未知策略"))
		)
	var owner_label := "平台 NPC" if npc else "开发者策略"
	var author_label := (
		"归属游戏自身，不占开发者三槽位"
		if npc else "开发者：%s" % str(item.get(
			"author_display_name", item.get("developer_id", "未知")
		))
	)
	button.text = "#%d  %s\n%s · %d 组 / %d 局%s\n%s · %s · 点击查看策略档案" % [
		int(item.get("rank", 0)),
		title,
		_format_ladder_score(float(item.get("mu", 0.0))),
		int(item.get("rated_series_count", 0)),
		int(item.get("actual_game_count", 0)),
		" · 暂定" if bool(item.get("provisional", false)) else "",
		owner_label,
		author_label,
	]
	button.set_meta("continuous_ladder_release", item.duplicate(true))
	if not _portrait_context.is_empty():
		button.text = "%s\n%s · %d 局%s\n%s" % [title,
			_format_ladder_score(float(item.get("mu", 0.0))), int(item.get("actual_game_count", 0)),
			" · 暂定" if bool(item.get("provisional", false)) else "",
			"内置对手" if npc else "作者 · %s" % str(item.get("author_display_name", item.get("developer_id", "未知开发者")))]
	button.pressed.connect(_on_continuous_ladder_release_pressed.bind(button))
	_style_strategy_button(button, false)
	if _portrait_context.is_empty():
		button.text = "%s\n%s · %d 局%s\n%s" % [title,
			_format_ladder_score(float(item.get("mu", 0.0))), int(item.get("actual_game_count", 0)),
			" · 暂定" if bool(item.get("provisional", false)) else "",
			"内置对手" if npc else "作者 · %s" % str(item.get("author_display_name", item.get("developer_id", "未知开发者")))]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_font_size_override("font_size", 20)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		card.add_child(row)
		row.add_child(button)
		var actions := VBoxContainer.new()
		actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(actions)
		var primary := Button.new()
		primary.name = "LadderDownloadButton"
		if not npc:
			primary.set_meta("ladder_listing", item.duplicate(true))
			primary.set_meta("download_allowed", true)
		primary.custom_minimum_size.x = 210
		var installable: Variant = item.get("installable_release")
		var downloadable: bool = not npc and bool(item.get("download_available", false)) and installable is Dictionary and not installable.is_empty()
		if downloadable:
			primary.set_meta("continuous_ladder_installable_release", installable.duplicate(true))
			primary.set_meta("download_allowed", true)
			primary.pressed.connect(_on_marketplace_download_pressed.bind(primary))
			_refresh_install_action(primary)
		else:
			primary.text = "查看对手" if npc else "一键下载安装"
			if npc:
				primary.pressed.connect(_on_continuous_ladder_release_pressed.bind(button))
			else:
				primary.set_meta("ladder_quick_release_id", str(item.get("release_id", "")))
				primary.pressed.connect(_on_ladder_quick_install.bind(primary))
		_style_primary_button(primary)
		_refresh_install_action(primary)
		actions.add_child(primary)
		var detail := Button.new()
		detail.name = "LadderDetailButton"
		detail.text = "查看卡组与战绩"
		detail.pressed.connect(_on_continuous_ladder_release_pressed.bind(button))
		actions.add_child(detail)
	else:
		card.add_child(button)
	_decorate_ladder_rank(card, item)
	return card


func _decorate_ladder_rank(card: PanelContainer, item: Dictionary) -> void:
	# Honor the supplied rank, including ties and pagination; never infer it from row order.
	var rank := int(item.get("rank", 0))
	var podium := rank >= 1 and rank <= 3
	var accent: Color = {
		1: Color(1.0, 0.79, 0.33),
		2: Color(0.78, 0.87, 0.97),
		3: Color(0.91, 0.61, 0.40),
	}.get(rank, Color(0.43, 0.66, 0.76))
	var style := _list_card_style(accent)
	if podium:
		style.bg_color = Color(0.018, 0.052, 0.076).lerp(accent, 0.09)
		style.border_color = Color(accent, 0.78)
		style.border_width_left = 3
		style.shadow_color = Color(accent, 0.15)
	card.add_theme_stylebox_override("panel", style)
	var body := card.get_child(0)
	card.remove_child(body)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_theme_constant_override("separation", 8)
	card.add_child(content)
	var rank_label := Label.new()
	rank_label.name = "LadderRankLabel"
	rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_label.text = "#%d" % rank if rank > 0 else "未排名"
	if podium:
		rank_label.text += " · " + {1: "榜首", 2: "第二名", 3: "第三名"}[rank]
	rank_label.set_meta("hub_keep_single_line", true)
	rank_label.add_theme_font_size_override("font_size", 30 if podium else 26)
	rank_label.add_theme_color_override("font_color", accent)
	content.add_child(rank_label)
	content.add_child(body)
	_apply_readable_typography(content)


func _on_ladder_quick_install(button: Button) -> void:
	_refresh_install_action(button)
	if button.disabled or _marketplace_download_button != null or is_instance_valid(_quick_install_button):
		return
	var local_ref: Dictionary = button.get_meta("start_strategy_ref", {})
	if not local_ref.is_empty():
		_on_local_strategy_start(local_ref)
		return
	if button.has_meta("continuous_ladder_installable_release"):
		_on_marketplace_download_pressed(button)
		return
	if _client == null:
		return
	_quick_install_button = button
	_quick_install_release_id = str(button.get_meta("ladder_quick_release_id", ""))
	button.disabled = true
	button.text = "准备下载…"
	var started: Dictionary = _client.fetch_continuous_ladder_release_profile(_quick_install_release_id)
	if not bool(started.get("accepted", false)):
		_reset_quick_install("重试下载")
		_set_workspace_status(WORKSPACE_CATALOG, "下载准备失败，请重试。", true)


func _reset_quick_install(text: String) -> void:
	if is_instance_valid(_quick_install_button):
		_quick_install_button.disabled = false
		_quick_install_button.text = text
	_quick_install_button = null
	_quick_install_release_id = ""


func _complete_quick_install(profile: Dictionary) -> bool:
	if _quick_install_release_id.is_empty():
		return false
	var expected_id := _quick_install_release_id
	var button := _quick_install_button
	_reset_quick_install("一键下载安装")
	if not is_instance_valid(button) or button.is_queued_for_deletion():
		return true
	var release: Dictionary = profile.get("release", {})
	var installable: Variant = release.get("installable_release")
	if str(release.get("release_id", "")) != expected_id or release.get("owner_kind") != "developer":
		_set_workspace_status(WORKSPACE_CATALOG, "策略版本发生变化，请刷新后重试。", true)
		return true
	if not bool(release.get("download_available", false)) or not installable is Dictionary or installable.is_empty():
		button.text = "暂无设备版"
		button.disabled = true
		_set_workspace_status(WORKSPACE_CATALOG, "这个策略暂未提供可下载版本，可以先查看卡组与战绩。", true)
		return true
	button.set_meta("continuous_ladder_installable_release", installable.duplicate(true))
	button.set_meta("download_allowed", true)
	_on_marketplace_download_pressed(button)
	return true


func _on_continuous_ladder_release_pressed(button: Button) -> void:
	if button == null:
		return
	var item: Dictionary = button.get_meta("continuous_ladder_release", {})
	var release_id := str(item.get("release_id", ""))
	if release_id.is_empty():
		return
	_show_continuous_ladder_release_loading(item)
	if _client == null:
		return
	_set_busy(true)
	_set_workspace_status(WORKSPACE_CATALOG, "正在读取策略历史、对战和胜率…")
	var started: Dictionary = _client.fetch_continuous_ladder_release_profile(release_id)
	if not bool(started.get("accepted", false)):
		_set_busy(false)
		_set_workspace_status(WORKSPACE_CATALOG, "策略档案读取失败。", true)


func _on_continuous_ladder_author_pressed(button: Button) -> void:
	if button == null:
		return
	var item: Dictionary = button.get_meta("continuous_ladder_author", {})
	var developer_id := str(item.get("developer_id", ""))
	if developer_id.is_empty():
		return
	_open_strategy_detail()
	%StrategyTitle.text = "%s 的作者档案" % str(item.get(
		"author_display_name", developer_id
	))
	%AuthorLabel.text = "正在读取该作者的全部策略与积分…"
	%SummaryLabel.text = ""
	%SelectedDownloadButton.visible = false
	if _client == null:
		return
	_set_busy(true)
	_set_workspace_status(WORKSPACE_CATALOG, "正在读取作者全部策略与得分…")
	var started: Dictionary = _client.fetch_continuous_ladder_author_profile(
		developer_id
	)
	if not bool(started.get("accepted", false)):
		_set_busy(false)
		_set_workspace_status(WORKSPACE_CATALOG, "作者档案读取失败。", true)


func _show_continuous_ladder_release_loading(item: Dictionary) -> void:
	_open_strategy_detail()
	_hide_marketplace_author_works()
	%DetailKicker.text = "策略档案"
	_set_catalog_legacy_replay_visible(false)
	%StrategyTitle.text = str(item.get("display_name", item.get("release_id", "策略")))
	%AuthorLabel.text = "作者：%s" % str(item.get(
		"author_display_name", "游戏内置 NPC" if item.get("owner_kind") == "platform_npc" else "未知"
	))
	%SummaryLabel.text = "正在读取历史积分、对战记录与胜率…"
	%ReleaseLabel.text = "%s%s" % [
		_format_ladder_score(float(item.get("mu", 0.0))),
		" · 暂定" if bool(item.get("provisional", false)) else "",
	]
	%SelectedDownloadButton.visible = false
	%MatchHistoryDivider.visible = true
	%MatchHistoryTitle.visible = true
	%MatchHistoryList.visible = true
	%MatchHistoryTitle.text = "最近对战"
	_clear_children(%MatchHistoryList)
	%MatchHistoryList.add_child(_empty_state_card("正在读取", "正在加载最近的双局系列。"))


func _apply_continuous_ladder_release_profile(profile: Dictionary) -> void:
	if _complete_quick_install(profile):
		return
	var release: Dictionary = profile.get("release", {})
	var performance: Dictionary = profile.get("performance", {})
	var series: Dictionary = performance.get("series", {})
	var games: Dictionary = performance.get("individual_games", {})
	%DetailKicker.text = "策略档案"
	_set_catalog_legacy_replay_visible(false)
	%StrategyTitle.text = str(release.get("display_name", release.get("release_id", "策略")))
	%AuthorLabel.text = (
		"归属：游戏内置 NPC（无需下载，不占开发者三槽位）"
		if release.get("owner_kind") == "platform_npc" else
		"作者：%s" % str(release.get("author_display_name", release.get("developer_id", "未知")))
	)
	%SummaryLabel.text = str(release.get("summary", ""))
	%ReleaseLabel.text = "全榜 #%s · %s%s" % [
		str(release.get("rank", "—")),
		_format_ladder_score(float(release.get("mu", 0.0))),
		" · 暂定" if bool(release.get("provisional", false)) else "",
	]
	%OfficialStats.text = "双局系列：%d 胜 / %d 负 / %d 平 · 系列胜率 %.1f%%" % [
		int(series.get("wins", 0)), int(series.get("losses", 0)),
		int(series.get("draws", 0)), float(series.get("win_rate_micros", 0)) / 10000.0,
	]
	%ShadowStats.text = "实际单局：%d 胜 / %d 负 / %d 平 · 胜率 %.1f%%" % [
		int(games.get("wins", 0)), int(games.get("losses", 0)),
		int(games.get("draws", 0)), float(games.get("win_rate_micros", 0)) / 10000.0,
	]
	%CommunityStats.text = "计分系列 %d · 实际对局 %d · 当前评分为%s" % [
		int(release.get("rated_series_count", 0)), int(release.get("actual_game_count", 0)),
		"暂定" if bool(release.get("provisional", false)) else "正式",
	]
	if not _portrait_context.is_empty():
		%ReleaseLabel.text = "%s%s" % [_format_ladder_score(float(release.get("mu", 0.0))),
			" · 暂定评分" if bool(release.get("provisional", false)) else ""]
		var sample_games := int(games.get("wins", 0)) + int(games.get("losses", 0)) + int(games.get("draws", 0))
		%ShadowStats.text = "近期 %d 局 · 胜率 %.1f%%\n%d 胜 · %d 负 · %d 平" % [
			sample_games, float(games.get("win_rate_micros", 0)) / 10000.0,
			int(games.get("wins", 0)), int(games.get("losses", 0)), int(games.get("draws", 0))]
		if release.get("owner_kind") == "platform_npc":
			%AuthorLabel.text = "内置对手 · 可在对战准备中选择"
	var installable: Variant = release.get("installable_release")
	var download_available: bool = bool(release.get("download_available", false)) \
		and installable is Dictionary
	%SelectedDownloadButton.visible = release.get("owner_kind") == "developer"
	%SelectedDownloadButton.disabled = not download_available
	%SelectedDownloadButton.set_meta("download_allowed", download_available)
	%SelectedDownloadButton.text = (
		"一键下载并导入该策略" if download_available else "该版本暂无可下载策略包"
	)
	%SelectedDownloadButton.set_meta(
		"continuous_ladder_installable_release",
		installable.duplicate(true) if installable is Dictionary else {}
	)
	%SelectedDownloadButton.set_meta("installable_release", {})
	_update_strategy_deck_preview(installable if installable is Dictionary else {})
	var matches: Array = profile.get("recent_matches", [])
	%MatchHistoryDivider.visible = true
	%MatchHistoryTitle.visible = true
	%MatchHistoryList.visible = true
	%MatchHistoryTitle.text = "最近 %d 组对战记录" % matches.size()
	_clear_children(%MatchHistoryList)
	if matches.is_empty():
		%MatchHistoryList.add_child(_empty_state_card("暂无对战", "该策略尚无公开联赛对战。"))
	else:
		for match_value: Variant in matches:
			if match_value is Dictionary:
				%MatchHistoryList.add_child(_continuous_ladder_match_row(match_value))
	%AuthorWorksDivider.visible = true
	%AuthorWorksTitle.visible = true
	%AuthorWorksList.visible = true
	%AuthorWorksTitle.text = "积分变化历史"
	_clear_children(%AuthorWorksList)
	var history: Array = profile.get("rating_history", [])
	if history.is_empty():
		%AuthorWorksList.add_child(_empty_state_card("暂无积分变化", "尚未生成 rating event。"))
	else:
		for event_value: Variant in history:
			if event_value is Dictionary:
				%AuthorWorksList.add_child(_continuous_ladder_rating_event_row(event_value))
	_set_workspace_status(WORKSPACE_CATALOG, "策略档案已加载：历史、对战、胜率和下载状态均已更新。")
	_collapse_detail_history()


func _apply_continuous_ladder_author_profile(profile: Dictionary) -> void:
	var author: Dictionary = profile.get("author", {})
	var releases: Array = profile.get("releases", [])
	var display_name := str(author.get("display_name", author.get("developer_id", "作者")))
	%DetailKicker.text = "作者档案"
	_set_catalog_legacy_replay_visible(false)
	%StrategyTitle.text = "%s 的作者档案" % display_name
	%AuthorLabel.text = "作者榜 #%s · 最佳策略 %s%s" % [
		str(author.get("rank", "—")),
		_format_ladder_score(float(author.get("mu", 0.0))),
		" · 暂定" if bool(author.get("provisional", false)) else "",
	]
	%SummaryLabel.text = "全部 %d 个策略版本，其中 %d 个正在参赛。" % [
		int(author.get("release_count", releases.size())),
		int(author.get("active_release_count", 0)),
	]
	%ReleaseLabel.text = "最佳版本：%s" % str(author.get("best_release_id", "—"))
	%SelectedDownloadButton.visible = false
	%OfficialStats.text = "作者策略总数：%d" % releases.size()
	%ShadowStats.text = "每个版本独立显示联赛积分和胜率。"
	%CommunityStats.text = "点击策略可继续查看其积分历史与逐场记录。"
	%MatchHistoryDivider.visible = false
	%MatchHistoryTitle.visible = false
	%MatchHistoryList.visible = false
	%AuthorWorksDivider.visible = true
	%AuthorWorksTitle.visible = true
	%AuthorWorksList.visible = true
	%AuthorWorksTitle.text = "全部 %d 个策略版本" % releases.size()
	_clear_children(%AuthorWorksList)
	for item_value: Variant in releases:
		if item_value is Dictionary:
			%AuthorWorksList.add_child(_continuous_ladder_author_release_row(item_value))
	_set_workspace_status(WORKSPACE_CATALOG, "作者档案已加载：共 %d 个策略版本。" % releases.size())


func _continuous_ladder_match_row(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "ContinuousLadderMatchCard"
	var result := str(item.get("subject_result", "quarantined"))
	card.add_theme_stylebox_override("panel", _list_card_style({
		"win": Color(0.24, 0.82, 0.56), "loss": Color(0.95, 0.42, 0.44),
		"draw": HUD_THEME_SCRIPT.ACCENT_WARM,
	}.get(result, HUD_THEME_SCRIPT.TEXT_MUTED)))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	card.add_child(content)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "%s vs %s\n单局 %d 胜 / %d 负 / %d 平 · %s%s" % [
		str({"win": "系列胜利", "loss": "系列失败", "draw": "系列平局", "quarantined": "系列隔离"}.get(result, result)),
		str(item.get("opponent", {}).get("display_name", item.get("opponent", {}).get("release_id", "对手"))),
		int(item.get("wins", 0)), int(item.get("losses", 0)), int(item.get("draws", 0)),
		_format_ladder_epoch(int(item.get("completed_at_epoch", 0))),
		" · 录像可用" if _replays_enabled and bool(item.get("replay_available", false)) else "",
	]
	content.add_child(label)
	var series_id := str(item.get("series_id", ""))
	var replay_path := str(item.get("replay_path", ""))
	var expected_path := "/v1/ladder/matches/%s/replay" % series_id
	if _replays_enabled and bool(item.get("replay_available", false)) and replay_path == expected_path:
		var download := Button.new()
		download.name = "ContinuousLadderReplayDownloadButton"
		download.text = "下载录像"
		download.custom_minimum_size = Vector2(132, 42)
		download.set_meta("series_id", series_id)
		download.set_meta("replay_path", replay_path)
		download.pressed.connect(
			_on_continuous_ladder_replay_download_pressed.bind(download)
		)
		_style_action_button(download, Color(0.30, 0.78, 0.94))
		content.add_child(download)
	return card


func _on_continuous_ladder_replay_download_pressed(button: Button) -> void:
	if _client == null or button == null or button.disabled:
		return
	var series_id := str(button.get_meta("series_id", ""))
	if series_id.is_empty():
		return
	_continuous_ladder_replay_download_button = button
	button.disabled = true
	button.text = "下载中…"
	_set_busy(true)
	_set_workspace_status(WORKSPACE_CATALOG, "正在下载并校验公开联赛录像…")
	var started: Dictionary = _client.fetch_continuous_ladder_series_replay(series_id)
	if not bool(started.get("accepted", false)):
		_set_busy(false)
		_finish_continuous_ladder_replay_download_button(false)
		_set_workspace_status(WORKSPACE_CATALOG, "录像下载启动失败。", true)


func _apply_continuous_ladder_series_replay(replay: Dictionary) -> void:
	var store: Variant = _continuous_ladder_replay_store_override
	if store == null:
		var created: Dictionary = CONTINUOUS_LADDER_REPLAY_STORE_SCRIPT.create()
		if not bool(created.get("accepted", false)):
			_finish_continuous_ladder_replay_download_button(false)
			_set_workspace_status(WORKSPACE_CATALOG, "本机录像目录不可用。", true)
			return
		store = created.get("store")
	if store == null or not store.has_method("store_replay"):
		_finish_continuous_ladder_replay_download_button(false)
		_set_workspace_status(WORKSPACE_CATALOG, "本机录像存储组件不可用。", true)
		return
	var stored: Dictionary = store.call("store_replay", replay.duplicate(true))
	if not bool(stored.get("ok", false)):
		_finish_continuous_ladder_replay_download_button(false)
		_set_workspace_status(
			WORKSPACE_CATALOG,
			"录像已下载但保存失败：%s" % str(stored.get("error_code", "unknown")),
			true,
		)
		return
	_finish_continuous_ladder_replay_download_button(true)
	_set_workspace_status(
		WORKSPACE_CATALOG,
		"录像已保存到：%s" % str(stored.get("absolute_path", stored.get("path", ""))),
	)


func _finish_continuous_ladder_replay_download_button(success: bool) -> void:
	if _continuous_ladder_replay_download_button != null \
			and is_instance_valid(_continuous_ladder_replay_download_button):
		_continuous_ladder_replay_download_button.disabled = success
		_continuous_ladder_replay_download_button.text = (
			"已下载" if success else "重试下载录像"
		)
	_continuous_ladder_replay_download_button = null


func _continuous_ladder_rating_event_row(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "ContinuousLadderRatingHistoryCard"
	card.add_theme_stylebox_override("panel", _list_card_style(Color(0.72, 0.54, 0.98)))
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "序列 #%d · %s\n%.2f → %.2f 分 · %s" % [
		int(item.get("sequence_no", 0)),
		str({"win": "胜", "loss": "负", "draw": "平"}.get(str(item.get("subject_outcome", "draw")), "平")),
		float(item.get("prior_mu", 0.0)), float(item.get("after_mu", 0.0)),
		_format_ladder_epoch(int(item.get("created_at_epoch", 0))),
	]
	card.add_child(label)
	return card


func _continuous_ladder_author_release_row(item: Dictionary) -> PanelContainer:
	var release: Dictionary = item.get("release", {})
	var performance: Dictionary = item.get("performance", {}).get("series", {})
	var card := PanelContainer.new()
	card.name = "ContinuousLadderAuthorReleaseCard"
	card.add_theme_stylebox_override("panel", _list_card_style(Color(0.30, 0.78, 0.94)))
	var row := _responsive_row()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var info := Button.new()
	info.name = "ContinuousLadderAuthorReleaseButton"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "%s · %s\n%s · %d 组 · 系列胜率 %.1f%%%s" % [
		str(release.get("display_name", release.get("release_id", "策略"))),
		str(release.get("state", "")),
		_format_ladder_score(float(release.get("mu", 0.0))), int(performance.get("games", 0)),
		float(performance.get("win_rate_micros", 0)) / 10000.0,
		" · 暂定" if bool(release.get("provisional", false)) else "",
	]
	info.set_meta("continuous_ladder_release", release.duplicate(true))
	info.pressed.connect(_on_continuous_ladder_release_pressed.bind(info))
	_style_strategy_button(info, false)
	row.add_child(info)
	var download := Button.new()
	download.name = "ContinuousLadderDownloadButton"
	download.custom_minimum_size = Vector2(132, 48)
	var available: bool = bool(release.get("download_available", false)) \
		and release.get("installable_release") is Dictionary
	download.text = "一键下载导入" if available else "暂无下载"
	download.disabled = not available
	if available:
		download.set_meta(
			"continuous_ladder_installable_release",
			release.get("installable_release", {}).duplicate(true)
		)
		download.pressed.connect(_on_marketplace_download_pressed.bind(download))
	_style_action_button(download, HUD_THEME_SCRIPT.ACCENT_WARM if available else HUD_THEME_SCRIPT.TEXT_MUTED)
	row.add_child(download)
	return card


func _format_ladder_score(value: float) -> String:
	return "%.2f 分" % value


func _format_ladder_epoch(epoch: int) -> String:
	if epoch <= 0:
		return "时间未知"
	return Time.get_datetime_string_from_unix_time(epoch, true).replace("T", " ")


func _apply_marketplace_author_rankings(
	items: Array,
	next_cursor: Variant,
	snapshot_id: String
) -> void:
	_clear_children(%AuthorRankingList)
	if items.is_empty():
		%AuthorRankingList.add_child(_empty_state_card(
			"暂无作者排行", "当前比赛配置还没有达到发布条件的作者贡献数据。"
		))
	for item_value: Variant in items:
		if not item_value is Dictionary:
			continue
		var item := item_value as Dictionary
		var button := Button.new()
		button.name = "MarketplaceAuthorButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 76)
		button.text = "#%d  %s\nKaggle 分 %.3f · 胜率 %.1f%% · %d 场%s · 查看最高分 5 个策略" % [
			int(item.get("rank", 0)),
			str(item.get("author_display_name", item.get("author_id", "未知作者"))),
			float(item.get("kaggle_score_micros", 0)) / 1000000.0,
			float(item.get("win_rate_micros", 0)) / 10000.0,
			int(item.get("games", 0)),
			" · 暂定" if bool(item.get("provisional", false)) else "",
		]
		button.set_meta("author_id", str(item.get("author_id", "")))
		button.pressed.connect(_on_marketplace_author_pressed.bind(button))
		_style_strategy_button(button, false)
		%AuthorRankingList.add_child(button)
	_set_marketplace_page_state(MARKETPLACE_AUTHOR_RANKINGS, next_cursor, items.size())
	_set_workspace_status(
		WORKSPACE_CATALOG,
		"作者贡献榜已锁定快照 %s；点击作者查看当前赛道最高分 5 个策略。" % snapshot_id
	)


func _apply_marketplace_author_strategies(author: Dictionary, items: Array) -> void:
	%AuthorWorksDivider.visible = true
	%AuthorWorksTitle.visible = true
	%AuthorWorksList.visible = true
	%AuthorWorksTitle.text = "%s的策略作品" % str(
		author.get("display_name", author.get("author_id", "作者"))
	)
	_clear_children(%AuthorWorksList)
	if items.is_empty():
		%AuthorWorksList.add_child(_empty_state_card(
			"暂无可安装作品", "这位作者当前没有完成显式绑定且可在本机安装的 .ptcgai。"
		))
	else:
		for item_value: Variant in items:
			if item_value is Dictionary:
				%AuthorWorksList.add_child(_marketplace_strategy_row(item_value, "作者作品"))
	_set_workspace_status(WORKSPACE_CATALOG, "已加载作者作品 %d 个。" % items.size())


func _apply_marketplace_strategy_archive(strategy: Dictionary, matches: Array) -> void:
	_show_marketplace_strategy(strategy)
	%MatchHistoryDivider.visible = true
	%MatchHistoryTitle.visible = true
	%MatchHistoryList.visible = true
	%MatchHistoryTitle.text = "最近 %d 场对战（最多 20 场）" % matches.size()
	_clear_children(%MatchHistoryList)
	if matches.is_empty():
		%MatchHistoryList.add_child(_empty_state_card(
			"暂无完赛记录", "这个策略在当前比赛配置下还没有已完成的公开对战。"
		))
	else:
		for match_value: Variant in matches:
			if match_value is Dictionary:
				%MatchHistoryList.add_child(
					_marketplace_match_history_row(match_value as Dictionary)
				)
	_set_workspace_status(
		WORKSPACE_CATALOG,
		"策略档案已加载：最近 %d 场完赛记录。" % matches.size()
	)


func _apply_marketplace_author_top_strategies(
	author: Dictionary, items: Array
) -> void:
	%AuthorWorksDivider.visible = true
	%AuthorWorksTitle.visible = true
	%AuthorWorksList.visible = true
	%AuthorWorksTitle.text = "%s · 最高分 5 个策略" % str(
		author.get("display_name", author.get("author_id", "作者"))
	)
	_clear_children(%AuthorWorksList)
	if items.is_empty():
		%AuthorWorksList.add_child(_empty_state_card(
			"暂无计分策略", "这位作者在当前比赛配置下还没有可排名的策略。"
		))
	else:
		for item_value: Variant in items:
			if not item_value is Dictionary:
				continue
			var item := item_value as Dictionary
			var prefix := "作者第 %d · 全榜 #%d\nKaggle 分 %.3f · 胜率 %.1f%% · %d 场%s" % [
				int(item.get("author_strategy_rank", 0)),
				int(item.get("rank", 0)),
				float(item.get("kaggle_score_micros", 0)) / 1000000.0,
				float(item.get("win_rate_micros", 0)) / 10000.0,
				int(item.get("games", 0)),
				" · 暂定" if bool(item.get("provisional", false)) else "",
			]
			%AuthorWorksList.add_child(_marketplace_strategy_row(item, prefix))
	_set_workspace_status(
		WORKSPACE_CATALOG, "已加载作者最高分策略 %d 个。" % items.size()
	)


func _marketplace_match_history_row(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "MarketplaceMatchHistoryCard_%s" % str(item.get("match_id", "unknown"))
	var result := str(item.get("subject_result", "draw"))
	var accent := {
		"win": Color(0.24, 0.82, 0.56),
		"loss": Color(0.95, 0.42, 0.44),
	}.get(result, HUD_THEME_SCRIPT.ACCENT_WARM) as Color
	card.add_theme_stylebox_override("panel", _list_card_style(accent))
	var label := Label.new()
	label.name = "MarketplaceMatchHistoryLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var participants: Array = item.get("participants", [])
	var subject_seat := int(item.get("subject_seat", 0))
	var opponent_seat := 1 - subject_seat
	var subject: Dictionary = (
		participants[subject_seat] as Dictionary
		if participants.size() == 2 and participants[subject_seat] is Dictionary else {}
	)
	var opponent: Dictionary = (
		participants[opponent_seat] as Dictionary
		if participants.size() == 2 and participants[opponent_seat] is Dictionary else {}
	)
	var result_label: String = str({"win": "胜利", "loss": "失败", "draw": "平局"}.get(
		result, "平局"
	))
	var replay_label := "录像可用" if bool(item.get("replay_available", false)) else "无公开录像"
	label.text = "%s · %s vs %s\n%s · %s · %s" % [
		result_label,
		str(subject.get("display_name", subject.get("strategy_id", "本策略"))),
		str(opponent.get("display_name", opponent.get("strategy_id", "对手"))),
		str(item.get("completed_at_utc", "")).replace("T", " ").trim_suffix("Z"),
		"座位 %d" % (subject_seat + 1),
		replay_label,
	]
	card.add_child(label)
	return card


func _hide_marketplace_author_works() -> void:
	%AuthorWorksDivider.visible = false
	%AuthorWorksTitle.visible = false
	%AuthorWorksList.visible = false


func _set_marketplace_page_state(board_id: String, next_cursor: Variant, item_count: int) -> void:
	_marketplace_cursors[board_id] = next_cursor
	if board_id == _active_marketplace_board:
		%MarketplaceNextButton.visible = next_cursor is String and not str(next_cursor).is_empty()
		%MarketplaceBoardStateLabel.text = (
			"本页 %d 项 · 还有下一页" % item_count
			if %MarketplaceNextButton.visible else "本页 %d 项 · 已到底" % item_count
		)


func _marketplace_strategy_row(item: Dictionary, prefix: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "MarketplaceStrategyCard"
	card.add_theme_stylebox_override("panel", _list_card_style(Color(0.30, 0.78, 0.94)))
	var row := _responsive_row()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var info := Button.new()
	info.name = "MarketplaceInfoButton"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var author: Dictionary = item.get("author", {})
	var author_name := str(item.get(
		"author_display_name", author.get("display_name", "未知作者")
	))
	var title := str(item.get("display_name", item.get("strategy_id", "策略")))
	info.text = "%s%s\n%s · %s" % [
		prefix + "\n" if not prefix.is_empty() else "",
		title,
		author_name,
		str(item.get("published_at_utc", "")).replace("T", " ").trim_suffix("Z"),
	]
	if _portrait_context.is_empty():
		info.text = "%s\n%s%s" % [title, prefix + "\n" if not prefix.is_empty() else "", author_name]
	info.set_meta("marketplace_item", item.duplicate(true))
	info.pressed.connect(_on_marketplace_strategy_info_pressed.bind(info))
	_style_strategy_button(info, false)
	row.add_child(info)
	var download := Button.new()
	download.name = "MarketplaceDownloadButton"
	download.custom_minimum_size = Vector2(210 if _portrait_context.is_empty() else 118, 56)
	var available := bool(item.get("download_available", false)) \
		and item.get("installable_release") is Dictionary
	download.text = "下载到本机" if available else "暂无设备版"
	download.disabled = not available
	if available:
		download.set_meta("download_allowed", true)
		download.set_meta("installable_release", item.get("installable_release", {}).duplicate(true))
		download.pressed.connect(_on_marketplace_download_pressed.bind(download))
		_refresh_install_action(download)
	_style_primary_button(download)
	row.add_child(download)
	return card


func _on_marketplace_strategy_info_pressed(button: Button) -> void:
	if button == null:
		return
	var item_value: Variant = button.get_meta("marketplace_item", {})
	if not item_value is Dictionary:
		return
	var item := item_value as Dictionary
	_show_marketplace_strategy(item)
	if _client == null:
		return
	var competition_release_id := str(item.get("competition_release_id", ""))
	if competition_release_id.is_empty():
		return
	_set_busy(true)
	_set_workspace_status(WORKSPACE_CATALOG, "正在读取最近 20 场对战…")
	var started: Dictionary = _client.fetch_marketplace_strategy_archive(
		_marketplace_ranking_profile_id, competition_release_id, 20
	)
	if not bool(started.get("accepted", false)):
		_set_busy(false)
		_set_workspace_status(WORKSPACE_CATALOG, "策略档案读取失败。", true)


func _show_marketplace_strategy(item: Dictionary) -> void:
	_open_strategy_detail()
	_hide_marketplace_author_works()
	%DetailKicker.text = "策略档案"
	_set_catalog_legacy_replay_visible(true)
	%MatchHistoryDivider.visible = true
	%MatchHistoryTitle.visible = true
	%MatchHistoryList.visible = true
	%MatchHistoryTitle.text = "最近对战（最多 20 场）"
	_clear_children(%MatchHistoryList)
	%MatchHistoryList.add_child(_empty_state_card("正在读取", "正在加载该策略最近的完赛记录。"))
	var release_value: Variant = item.get("installable_release")
	var release: Dictionary = release_value if release_value is Dictionary else {}
	%StrategyTitle.text = str(item.get("display_name", item.get("strategy_id", "策略")))
	%AuthorLabel.text = "作者：%s" % str(item.get(
		"author_display_name", item.get("author", {}).get("display_name", "未知")
	))
	%SummaryLabel.text = str(item.get("summary", ""))
	%ReleaseLabel.text = (
		"设备版 v%s · 发布时间 %s" % [
			release.get("package_version", "?"), item.get("published_at_utc", "未知"),
		]
		if not release.is_empty() else "该比赛策略尚未绑定可安装设备版"
	)
	%SelectedDownloadButton.visible = true
	%SelectedDownloadButton.disabled = release.is_empty()
	%SelectedDownloadButton.set_meta("download_allowed", not release.is_empty())
	%SelectedDownloadButton.text = (
		"一键下载并安装到本机" if not release.is_empty() else "尚无可在本机运行的设备版"
	)
	%SelectedDownloadButton.set_meta("installable_release", release.duplicate(true))
	%SelectedDownloadButton.set_meta("continuous_ladder_installable_release", {})
	_update_strategy_deck_preview(release)
	_update_detail_primary_action()
	_collapse_detail_history()


func _on_marketplace_author_pressed(button: Button) -> void:
	if _client == null or button == null:
		return
	var author_id := str(button.get_meta("author_id", ""))
	if author_id.is_empty():
		return
	_open_strategy_detail()
	_set_busy(true)
	_set_workspace_status(WORKSPACE_CATALOG, "正在读取作者最高分 5 个策略…")
	var started: Dictionary = _client.list_marketplace_author_top_strategies(
		_marketplace_ranking_profile_id, author_id, 5
	)
	if not bool(started.get("accepted", false)):
		_set_busy(false)
		_set_workspace_status(WORKSPACE_CATALOG, "作者最高分策略读取失败。", true)


func _on_marketplace_download_pressed(button: Button) -> void:
	if button == null or _marketplace_download_button != null:
		return
	_refresh_install_action(button)
	var start_ref: Dictionary = button.get_meta("start_strategy_ref", {}) if button != null else {}
	if not start_ref.is_empty() and not button.disabled:
		_on_local_strategy_start(start_ref)
		return
	if _client == null or button == null or button.disabled:
		return
	var ladder_release: Dictionary = button.get_meta(
		"continuous_ladder_installable_release", {}
	)
	var release: Dictionary = (
		ladder_release if not ladder_release.is_empty()
		else button.get_meta("installable_release", {})
	)
	if release.is_empty():
		return
	_marketplace_download_button = button
	_marketplace_download_started_usec = Time.get_ticks_usec()
	button.disabled = true
	button.text = "下载中…"
	_set_workspace_status(WORKSPACE_CATALOG, "正在下载并核对精确策略包…")
	var started: Dictionary = (
		_client.download_continuous_ladder_release(release)
		if not ladder_release.is_empty()
		else _client.download_marketplace_release(release)
	)
	if not bool(started.get("accepted", false)):
		button.disabled = false
		button.text = "重试下载"
		_marketplace_download_button = null
		_set_workspace_status(WORKSPACE_CATALOG, "下载启动失败。", true)


func _apply_marketplace_package_download(result: Dictionary) -> void:
	var catalog_owner: Variant = (
		_package_install_catalog_override
		if _package_install_catalog_override != null else AuthorStrategyPackageCatalog
	)
	if not bool(result.get("accepted", false)) or catalog_owner == null \
			or not catalog_owner.has_method("install_from_bytes"):
		_finish_marketplace_download_button(false)
		_set_workspace_status(WORKSPACE_CATALOG, "策略包下载校验失败，未写入本机。", true)
		return
	var install_started_usec := Time.get_ticks_usec()
	var installed: Dictionary = catalog_owner.call(
		"install_from_bytes",
		result.get("package_bytes", PackedByteArray()),
		result.get("expected_release", {}).duplicate(true)
	)
	var install_elapsed_usec := maxi(0, Time.get_ticks_usec() - install_started_usec)
	_emit_strategy_import_timing(result, installed, install_elapsed_usec)
	if not bool(installed.get("ok", false)):
		_finish_marketplace_download_button(false)
		_set_workspace_status(
			WORKSPACE_CATALOG,
			"下载完成但安装校验失败：%s" % _local_package_error_text(
				str(installed.get("error_code", "package_install_failed"))
			),
			true
		)
		return
	if installed.get("catalog_report") is Dictionary:
		_apply_local_package_catalog(installed.get("catalog_report", {}))
	_finish_marketplace_download_button(true)
	var installed_record := _local_package_record_for_ref(result.get("expected_release", {}))
	var admission := _local_package_admission(installed_record)
	_set_workspace_status(
		WORKSPACE_CATALOG,
		"策略安装完成，点击“开始对战”即可挑战。" if bool(admission.get("ok", false)) else (
			"策略安装完成。" + _local_package_unavailable_text(admission)
		)
	)


func _finish_marketplace_download_button(success: bool) -> void:
	var finished_button := _marketplace_download_button
	if _marketplace_download_button != null and is_instance_valid(_marketplace_download_button):
		_marketplace_download_button.disabled = success
		_marketplace_download_button.text = "已安装" if success else "重试下载"
	_marketplace_download_button = null
	_marketplace_download_started_usec = 0
	if success and is_instance_valid(finished_button):
		_refresh_install_action(finished_button)
	_update_detail_primary_action()


func _emit_strategy_import_timing(
	download_result: Dictionary,
	installed: Dictionary,
	install_elapsed_usec: int
) -> void:
	var expected: Dictionary = download_result.get("expected_release", {})
	var total_elapsed_usec := (
		maxi(0, Time.get_ticks_usec() - _marketplace_download_started_usec)
		if _marketplace_download_started_usec > 0 else install_elapsed_usec
	)
	print("PTCGDAP_STRATEGY_IMPORT=" + JSON.stringify({
		"document_type": "ptcgdap_strategy_import_timing_v1",
		"schema_version": 1,
		"ok": bool(installed.get("ok", false)),
		"error_code": str(installed.get("error_code", "")),
		"release_id": str(download_result.get("release_id", "")),
		"package_id": str(expected.get("package_id", "")),
		"package_version": str(expected.get("package_version", "")),
		"archive_sha256": str(expected.get("archive_sha256", "")),
		"already_installed": bool(installed.get("already_installed", false)),
		"download_and_install_elapsed_usec": total_elapsed_usec,
		"install_elapsed_usec": install_elapsed_usec,
		"identity_resolution_usec": int(installed.get("identity_resolution_usec", 0)),
		"catalog_refresh_usec": int(installed.get("catalog_refresh_usec", 0)),
		"catalog_discoverable": bool(installed.get("catalog_discoverable", false)),
	}))


func _apply_catalog(items: Array) -> void:
	_clear_children(%StrategyList)
	if items.is_empty():
		_set_workspace_status(WORKSPACE_CATALOG, "暂时没有已策展的策略版本。")
		return
	for item: Variant in items:
		if not item is Dictionary:
			continue
		var button := Button.new()
		button.text = "%s\n%s" % [
			str(item.get("display_name", item.get("strategy_id", ""))),
			str(item.get("author_display_name", "未知作者")),
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 72)
		button.set_meta("strategy_id", str(item.get("strategy_id", "")))
		button.pressed.connect(_on_strategy_pressed.bind(button))
		_style_strategy_button(button, false)
		%StrategyList.add_child(button)
	_set_workspace_status(WORKSPACE_CATALOG, "已加载 %d 个策略。统计按官方、影子测试和社区录像分开显示。" % items.size())
	var first := %StrategyList.get_child(0) as Button if %StrategyList.get_child_count() > 0 else null
	if first != null:
		_on_strategy_pressed(first)


func _on_strategy_pressed(button: Button) -> void:
	if _client == null or button == null:
		return
	var strategy_id := str(button.get_meta("strategy_id", ""))
	if strategy_id.is_empty():
		return
	_open_strategy_detail()
	_selected_strategy_id = strategy_id
	for child: Node in %StrategyList.get_children():
		if child is Button:
			_style_strategy_button(child as Button, child == button)
	_set_busy(true)
	_set_workspace_status(WORKSPACE_CATALOG, "正在读取策略详情…")
	var started: Dictionary = _client.fetch_strategy(strategy_id)
	if not bool(started.get("accepted", false)):
		_set_busy(false)
		_set_workspace_status(WORKSPACE_CATALOG, "详情读取失败：%s" % str(started.get("error_code", "unknown")), true)


func _apply_detail(detail: Dictionary) -> void:
	_clear_strategy_deck_preview()
	%DetailKicker.text = "策略档案"
	_set_catalog_legacy_replay_visible(true)
	%StrategyTitle.text = str(detail.get("display_name", detail.get("strategy_id", "策略")))
	%SummaryLabel.text = str(detail.get("summary", ""))
	var author: Dictionary = detail.get("author", {})
	%AuthorLabel.text = "作者：%s" % str(author.get("display_name", author.get("author_id", "未知")))
	_selected_release_id = ""
	var releases: Array = detail.get("releases", [])
	if not releases.is_empty() and releases[0] is Dictionary:
		var release: Dictionary = releases[0]
		_selected_release_id = str(release.get("release_id", ""))
		_update_strategy_deck_preview(release.get("installable_release", release))
		%ReleaseLabel.text = "版本 %s · %s · 本机挑战%s" % [
			str(release.get("package_version", "?")),
			str(release.get("release_state", "unknown")),
			"可用" if bool(release.get("player_start_allowed", false)) else "不可用",
		]
	else:
		%ReleaseLabel.text = "无公开版本"
	_render_replays(detail.get("representative_replays", []))
	if _selected_release_id.is_empty():
		_set_workspace_status(WORKSPACE_CATALOG, "详情已加载，但没有可统计版本。")
		return
	if _client == null:
		_set_workspace_status(WORKSPACE_CATALOG, "详情已加载；当前测试宿主未连接统计服务。")
		return
	_set_busy(true)
	_set_workspace_status(WORKSPACE_CATALOG, "正在读取分泳道统计…")
	var started: Dictionary = _client.fetch_statistics(_selected_release_id)
	if not bool(started.get("accepted", false)):
		_set_busy(false)
		_set_workspace_status(WORKSPACE_CATALOG, "统计读取失败：%s" % str(started.get("error_code", "unknown")), true)


func _set_catalog_legacy_replay_visible(visible: bool) -> void:
	visible = visible and _replays_enabled
	%ReplayDivider.visible = visible
	%ReplayTitle.visible = visible
	%ReplayList.visible = visible


func _apply_statistics(statistics: Dictionary) -> void:
	var official: Dictionary = statistics.get("official", {})
	var shadow: Dictionary = statistics.get("shadow", {})
	var community: Dictionary = statistics.get("community", {})
	%OfficialStats.text = (
		"官方验证：%s" % _summary_text(official.get("summary", {}))
		if bool(official.get("available", false))
		else "官方验证：暂无数据"
	)
	%ShadowStats.text = (
		"影子测试（非官方）：%s" % _summary_text(shadow.get("summary", {}))
		if bool(shadow.get("available", false))
		else "影子测试（非官方）：暂无数据"
	)
	%CommunityStats.text = "社区公开录像：%d 场（不计入官方胜率）" % int(
		community.get("active_replay_count", 0)
	)
	_set_workspace_status(WORKSPACE_CATALOG, "策略详情已就绪。挑战时会在本机重新校验并绑定精确版本。")


func _summary_text(summary: Dictionary) -> String:
	var counts: Dictionary = summary.get("counts", {})
	var wins := int(counts.get("wins", counts.get("win", 0)))
	var valid := int(counts.get("valid", 0))
	if valid <= 0:
		return "有效 %d 场" % valid
	return "%d 胜 / %d 场（%.1f%%）" % [wins, valid, float(wins) * 100.0 / float(valid)]


func _render_local_replays(native_replays: Array, public_replays: Array, rejected_count: int) -> void:
	_clear_children(%LocalReplayList)
	_local_native_replay_rows.clear()
	for value: Variant in native_replays:
		if value is Dictionary:
			_local_native_replay_rows.append((value as Dictionary).duplicate(true))
	_local_public_replay_rows.clear()
	for value: Variant in public_replays:
		if value is Dictionary:
			_local_public_replay_rows.append((value as Dictionary).duplicate(true))
	_local_replay_ids.clear()
	for replay: Variant in public_replays:
		if replay is Dictionary:
			var replay_id := str((replay as Dictionary).get("replay_id", ""))
			if not replay_id.is_empty():
				_local_replay_ids[replay_id] = true
	var visible_public_replays := _public_replays_without_native_coverage(
		native_replays, public_replays
	)
	var merged_public_count := public_replays.size() - visible_public_replays.size()
	_local_replay_count = native_replays.size() + visible_public_replays.size()
	%LocalReplayCountLabel.text = "%d 场" % _local_replay_count
	if native_replays.is_empty() and public_replays.is_empty():
		%LocalReplayList.add_child(_empty_state_card(
			"还没有对战录像", "完成下一场 AI 对战后，会自动记录动作和本方手牌。"
		))
	if not native_replays.is_empty():
		var native_title := Label.new()
		native_title.text = "完整录像"
		native_title.add_theme_font_size_override("font_size", 18)
		native_title.add_theme_color_override("font_color", HUD_THEME_SCRIPT.TEXT)
		%LocalReplayList.add_child(native_title)
		for replay: Variant in native_replays:
			if not replay is Dictionary:
				continue
			var match_dir := str(replay.get("match_dir", ""))
			if match_dir.is_empty():
				continue
			var card := PanelContainer.new()
			card.name = "NativeReplayCard"
			card.add_theme_stylebox_override("panel", _list_card_style(Color(0.30, 0.88, 1.0)))
			var row := VBoxContainer.new()
			row.add_theme_constant_override("separation", 7)
			card.add_child(row)
			var label := Label.new()
			label.text = _native_replay_label(replay)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.tooltip_text = str(replay.get("match_id", ""))
			label.add_theme_color_override("font_color", HUD_THEME_SCRIPT.TEXT)
			row.add_child(label)
			var actions := _responsive_row()
			actions.add_theme_constant_override("separation", 8)
			row.add_child(actions)
			var watch := Button.new()
			watch.name = "NativeReplayWatchButton"
			watch.text = "进入正式场景回放"
			watch.custom_minimum_size.y = 48
			watch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_action_button(watch, HUD_THEME_SCRIPT.ACCENT)
			watch.pressed.connect(_on_watch_native_replay.bind(replay))
			actions.add_child(watch)
			var delete_button := Button.new()
			delete_button.name = "NativeReplayDeleteButton"
			delete_button.text = "删除录像"
			delete_button.custom_minimum_size = Vector2(124, 48)
			delete_button.disabled = _local_replay_delete_busy
			delete_button.pressed.connect(
				_on_local_replay_delete_requested.bind({
					"kind": "native",
					"match_id": str(replay.get("match_id", "")),
					"match_dir": match_dir,
				})
			)
			_style_action_button(delete_button, Color(0.94, 0.34, 0.32))
			actions.add_child(delete_button)
			%LocalReplayList.add_child(card)
	if not visible_public_replays.is_empty():
		var public_title := Label.new()
		public_title.text = "旧公开记录"
		public_title.add_theme_font_size_override("font_size", 16)
		public_title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
		%LocalReplayList.add_child(public_title)
		for replay: Variant in visible_public_replays:
			if not replay is Dictionary:
				continue
			var replay_id := str(replay.get("replay_id", ""))
			if replay_id.is_empty():
				continue
			var card := PanelContainer.new()
			card.name = "IncompleteReplayCard"
			card.add_theme_stylebox_override("panel", _list_card_style(Color(1.0, 0.58, 0.26)))
			var row := VBoxContainer.new()
			row.add_theme_constant_override("separation", 7)
			card.add_child(row)
			var label := Label.new()
			label.text = _local_replay_label(replay)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.add_theme_color_override("font_color", HUD_THEME_SCRIPT.TEXT)
			row.add_child(label)
			var limitation := Label.new()
			limitation.text = "仅含公开信息，无法还原真实手牌和正式动作。"
			limitation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			limitation.add_theme_color_override("font_color", Color(1.0, 0.78, 0.52))
			row.add_child(limitation)
			var actions := _responsive_row()
			actions.add_theme_constant_override("separation", 8)
			row.add_child(actions)
			var unavailable := Button.new()
			unavailable.name = "PublicReplayIncompleteButton"
			unavailable.text = "信息不完整，无法播放"
			unavailable.disabled = true
			unavailable.custom_minimum_size.y = 44
			unavailable.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			actions.add_child(unavailable)
			var delete_button := Button.new()
			delete_button.name = "PublicReplayDeleteButton"
			delete_button.text = "删除记录"
			delete_button.custom_minimum_size = Vector2(124, 44)
			delete_button.disabled = _local_replay_delete_busy
			delete_button.pressed.connect(
				_on_local_replay_delete_requested.bind({
					"kind": "public",
					"replay_id": replay_id,
				})
			)
			_style_action_button(delete_button, Color(0.94, 0.34, 0.32))
			actions.add_child(delete_button)
			%LocalReplayList.add_child(card)
	if rejected_count > 0:
		%LocalReplayList.add_child(_notice_card(
			"已跳过 %d 个损坏或不兼容的录像" % rejected_count,
			"其他录像仍可正常查看。", true
		))
	_set_workspace_status(
		WORKSPACE_REPLAYS,
		"本机共有 %d 场录像%s。" % [
			_local_replay_count,
			_build_replay_status_suffix(rejected_count, merged_public_count),
		]
	)


func _public_replays_without_native_coverage(
	native_replays: Array,
	public_replays: Array
) -> Array:
	var visible: Array = []
	for public_variant: Variant in public_replays:
		if not public_variant is Dictionary:
			visible.append(public_variant)
			continue
		var public_replay := public_variant as Dictionary
		var covered := false
		for native_variant: Variant in native_replays:
			if native_variant is Dictionary and _same_local_match(
				public_replay, native_variant as Dictionary
			):
				covered = true
				break
		if not covered:
			visible.append(public_replay)
	return visible


func _same_local_match(public_replay: Dictionary, native_replay: Dictionary) -> bool:
	var exact_native_id := str(public_replay.get("native_match_id", ""))
	if not exact_native_id.is_empty():
		return exact_native_id == str(native_replay.get("match_id", ""))
	if str(public_replay.get("source", "")) != "local":
		return false
	if str(native_replay.get("mode", "")) not in ["vs_ai", "vs_author_strategy_ai"]:
		return false
	var public_started := _utc_timestamp_to_unix(str(public_replay.get("started_at_utc", "")))
	var native_started := _utc_timestamp_to_unix(str(native_replay.get("started_at_utc", "")))
	return (
		public_started > 0
		and native_started > 0
		and absi(public_started - native_started) <= PUBLIC_NATIVE_START_TOLERANCE_SECONDS
	)


func _utc_timestamp_to_unix(timestamp: String) -> int:
	var normalized := timestamp.strip_edges().trim_suffix("Z")
	if normalized.is_empty():
		return 0
	return int(Time.get_unix_time_from_datetime_string(normalized))


func _build_replay_status_suffix(rejected_count: int, merged_public_count: int) -> String:
	var messages: Array[String] = []
	if merged_public_count > 0:
		messages.append("已合并 %d 个公开副本" % merged_public_count)
	if rejected_count > 0:
		messages.append("安全跳过 %d 个异常项" % rejected_count)
	return "，%s" % "，".join(messages) if not messages.is_empty() else ""


func _on_local_replay_delete_requested(reference: Dictionary) -> void:
	if _local_replay_delete_busy:
		return
	var kind := str(reference.get("kind", ""))
	if kind == "native":
		var match_id := str(reference.get("match_id", ""))
		var match_dir := str(reference.get("match_dir", ""))
		var native_record: Dictionary = {}
		for row: Dictionary in _local_native_replay_rows:
			if (
				str(row.get("match_id", "")) == match_id
				and str(row.get("match_dir", "")) == match_dir
			):
				native_record = row.duplicate(true)
				break
		if native_record.is_empty():
			_set_workspace_status(WORKSPACE_REPLAYS, "该录像已不在本机目录中。", true)
			return
		var public_replay_ids: Array[String] = []
		for public_replay: Dictionary in _local_public_replay_rows:
			if _same_local_match(public_replay, native_record):
				var replay_id := str(public_replay.get("replay_id", ""))
				if not replay_id.is_empty() and replay_id not in public_replay_ids:
					public_replay_ids.append(replay_id)
		public_replay_ids.sort()
		_pending_local_replay_delete_ref = {
			"kind": "native",
			"match_id": match_id,
			"match_dir": match_dir,
			"public_replay_ids": public_replay_ids,
		}
		%LocalReplayDeleteDialog.dialog_text = (
			"确认从这台设备删除这场完整录像吗？\n同场公开副本也会一并删除；删除后无法在游戏中恢复。"
			if not public_replay_ids.is_empty()
			else "确认从这台设备删除这场完整录像吗？\n删除后无法在游戏中恢复。"
		)
	elif kind == "public":
		var replay_id := str(reference.get("replay_id", ""))
		var exists := _local_public_replay_rows.any(func(row: Dictionary) -> bool:
			return str(row.get("replay_id", "")) == replay_id
		)
		if replay_id.is_empty() or not exists:
			_set_workspace_status(WORKSPACE_REPLAYS, "该公开记录已不在本机目录中。", true)
			return
		_pending_local_replay_delete_ref = {
			"kind": "public",
			"replay_id": replay_id,
		}
		%LocalReplayDeleteDialog.dialog_text = (
			"确认从这台设备删除这条旧公开记录吗？\n删除后无法在游戏中恢复。"
		)
	else:
		_set_workspace_status(WORKSPACE_REPLAYS, "录像删除请求无效。", true)
		return
	if is_inside_tree():
		%LocalReplayDeleteDialog.popup_centered()
	else:
		%LocalReplayDeleteDialog.visible = true


func _on_local_replay_delete_confirmed() -> void:
	if _local_replay_delete_busy:
		return
	var reference := _pending_local_replay_delete_ref.duplicate(true)
	_pending_local_replay_delete_ref = {}
	if reference.is_empty():
		return
	var service: Variant = _replay_removal_service_override
	if service == null:
		if _local_replay_removal_service == null:
			var service_script := load(LOCAL_REPLAY_REMOVAL_SCRIPT_PATH) as Script
			if service_script != null and service_script.can_instantiate():
				_local_replay_removal_service = service_script.new()
		service = _local_replay_removal_service
	if service == null:
		_set_workspace_status(WORKSPACE_REPLAYS, "本机录像删除组件不可用。", true)
		return
	_local_replay_delete_busy = true
	_set_busy(true)
	_set_workspace_status(WORKSPACE_REPLAYS, "正在从本机删除录像…")
	var tree := get_tree() if is_inside_tree() else null
	if tree != null:
		await tree.process_frame
	var result: Dictionary
	if str(reference.get("kind", "")) == "native":
		var public_replay_ids: Array[String] = []
		for value: Variant in reference.get("public_replay_ids", []):
			public_replay_ids.append(str(value))
		result = service.remove_native(
			str(reference.get("match_id", "")),
			str(reference.get("match_dir", "")),
			public_replay_ids
		)
	else:
		result = service.remove_public(str(reference.get("replay_id", "")))
	_local_replay_delete_busy = false
	_set_busy(false)
	if not bool(result.get("ok", false)):
		_refresh_local_replays()
		_set_workspace_status(
			WORKSPACE_REPLAYS,
			_local_replay_remove_error_text(str(result.get("error_code", "replay_remove_failed"))),
			true
		)
		return
	_refresh_local_replays()
	var status_text := "录像已删除。"
	if int(result.get("public_removed_count", 0)) > 0 and bool(result.get("native_removed", false)):
		status_text = "完整录像及同场公开副本已删除。"
	elif int(result.get("public_removed_count", 0)) > 0:
		status_text = "公开录像记录已删除。"
	if bool(result.get("cleanup_pending", false)):
		status_text += " 录像已停止显示，但有临时清理文件尚未删除。"
	_set_workspace_status(WORKSPACE_REPLAYS, status_text)


func _on_local_replay_delete_canceled() -> void:
	_pending_local_replay_delete_ref = {}


func _local_replay_remove_error_text(error_code: String) -> String:
	var messages := {
		"replay_remove_reference_invalid": "录像身份或路径无效，未删除任何内容。",
		"replay_remove_not_found": "没有找到完全匹配的本机录像，未删除任何内容。",
		"replay_remove_public_incomplete": "同场公开副本不完整，未删除任何录像。",
		"replay_remove_failed": "录像删除失败，原文件已自动保留。",
		"replay_remove_rollback_failed": "录像删除失败且自动恢复不完整，请刷新并检查录像文件夹。",
	}
	return str(messages.get(error_code, "录像删除失败（%s）。" % error_code))


func _native_replay_label(replay: Dictionary) -> String:
	var labels: Array = replay.get("player_labels", [])
	var left := str(labels[0]) if labels.size() > 0 else "玩家"
	var right := str(labels[1]) if labels.size() > 1 else "AI"
	var outcome := "胜者未知"
	var winner := int(replay.get("winner_index", -1))
	if winner in [0, 1]:
		outcome = "%s 获胜" % (left if winner == 0 else right)
	return "%s vs %s · %s · %d 回合\n%s" % [
		left, right, outcome, int(replay.get("turn_count", 0)), str(replay.get("recorded_at", "")),
	]


func _on_watch_native_replay(replay: Dictionary) -> void:
	var match_dir := str(replay.get("match_dir", ""))
	if _native_replay_locator == null:
		var locator_script := load(BATTLE_REPLAY_LOCATOR_SCRIPT_PATH) as Script
		if locator_script != null and locator_script.can_instantiate():
			_native_replay_locator = locator_script.new()
	if match_dir.is_empty() or _native_replay_locator == null:
		_set_status("完整录像路径不可用。", true)
		return
	var located: Dictionary = _native_replay_locator.locate(match_dir)
	var turn_numbers: Array = located.get("turn_numbers", [])
	var entry_turn := int(located.get("entry_turn_number", 0))
	if entry_turn <= 0 and not turn_numbers.is_empty():
		entry_turn = int(turn_numbers[0])
	var launched := GameManager.goto_battle_replay({
		"match_dir": match_dir,
		"entry_turn_number": entry_turn,
		"entry_source": str(located.get("entry_source", "match_start")),
		"turn_numbers": turn_numbers,
		"view_player_index": int(replay.get("view_player_index", 0)),
		"selected_deck_ids": (replay.get("selected_deck_ids", []) as Array).duplicate(),
		"player_labels": (replay.get("player_labels", []) as Array).duplicate(),
	})
	if not launched:
		_set_status("录像入口参数不完整，无法安全打开。", true)
		return
	_set_status("正在用正式战斗场景打开完整录像…")


func _local_replay_label(replay: Dictionary) -> String:
	var started_utc := str(replay.get("started_at_utc", ""))
	var started := ""
	if not started_utc.is_empty():
		var unix_time := int(Time.get_unix_time_from_datetime_string(started_utc))
		var timezone: Dictionary = Time.get_time_zone_from_system()
		var local_unix_time := unix_time + int(timezone.get("bias", 0)) * 60
		started = Time.get_datetime_string_from_unix_time(local_unix_time, true)
	if started.is_empty():
		started = "时间未知"
	var strategy_label := "AI 对战"
	var strategy_id := str(replay.get("strategy_id", "")).to_lower()
	if "cynthia" in strategy_id:
		strategy_label = "竹兰烈咬陆鲨"
	elif "marnie" in strategy_id:
		strategy_label = "玛俐长毛巨魔"
	return "%s · %d 帧\n本地时间 %s" % [
		strategy_label, int(replay.get("frame_count", 0)), started,
	]


func _render_replays(replays: Array) -> void:
	_clear_children(%ReplayList)
	if replays.is_empty():
		%ReplayList.add_child(_empty_state_card("暂无代表录像", "该策略还没有可公开播放的记录。"))
		return
	for replay: Variant in replays:
		if not replay is Dictionary:
			continue
		var card := PanelContainer.new()
		card.name = "RepresentativeReplayCard"
		card.add_theme_stylebox_override("panel", _list_card_style(Color(0.30, 0.88, 1.0)))
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 7)
		card.add_child(content)
		var label := Label.new()
		label.text = "%s · %d 帧" % [str(replay.get("replay_id", "")), int(replay.get("frame_count", 0))]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", HUD_THEME_SCRIPT.TEXT)
		content.add_child(label)
		var row := _responsive_row()
		row.add_theme_constant_override("separation", 7)
		content.add_child(row)
		var watch := Button.new()
		var replay_id := str(replay.get("replay_id", ""))
		watch.text = "观看本机录像" if _local_replay_ids.has(replay_id) else "观看录像"
		watch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(watch, HUD_THEME_SCRIPT.ACCENT)
		if _local_replay_ids.has(replay_id):
			watch.pressed.connect(_on_watch_local_replay.bind(replay_id))
		else:
			watch.pressed.connect(_on_watch_replay.bind(replay_id))
		row.add_child(watch)
		var challenge := Button.new()
		challenge.text = "挑战同版本"
		challenge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(challenge, HUD_THEME_SCRIPT.ACCENT_WARM)
		challenge.pressed.connect(_on_challenge.bind(
			str(replay.get("release_id", "")), str(replay.get("replay_id", ""))
		))
		row.add_child(challenge)
		var share := Button.new()
		share.text = "复制分享"
		share.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_action_button(share, Color(0.50, 0.72, 0.88))
		share.pressed.connect(_on_share.bind(str(replay.get("share_uri", ""))))
		row.add_child(share)
		%ReplayList.add_child(card)


func _on_watch_local_replay(replay_id: String) -> void:
	if _contract_owner == null or _local_replay_library == null:
		_set_status("本机录像库不可用。", true)
		return
	_set_busy(true)
	_set_status("正在校验本机录像…")
	await get_tree().process_frame
	var loaded: Dictionary = _local_replay_library.load_replay(replay_id)
	_set_busy(false)
	if not bool(loaded.get("accepted", false)):
		_set_status("本机录像校验失败：%s" % str(loaded.get("error_code", "unknown")), true)
		return
	_open_replay_artifact(loaded.get("artifact", {}), true)


func _on_watch_replay(replay_id: String) -> void:
	if _contract_owner == null:
		_set_status("本地录像契约不可用。", true)
		return
	if _replay_reader != null:
		_replay_reader.queue_free()
		_replay_reader = null
	var replay_reader_script := load(REPLAY_READER_SCRIPT_PATH) as Script
	if replay_reader_script == null:
		_set_status("录像读取器组件不可用。", true)
		return
	var created: Dictionary = replay_reader_script.create(
		_contract_owner, null, _base_url, _allow_insecure_loopback
	)
	if not bool(created.get("accepted", false)):
		_set_status("录像读取器不可用：%s" % str(created.get("error_code", "unknown")), true)
		return
	_replay_reader = created.get("reader") as Node
	add_child(_replay_reader)
	_replay_reader.read_completed.connect(_on_replay_read_completed)
	_set_busy(true)
	_set_status("正在下载并校验公开录像…")
	var started: Dictionary = _replay_reader.fetch(replay_id)
	if not bool(started.get("accepted", false)):
		_set_busy(false)
		_set_status("录像读取失败：%s" % str(started.get("error_code", "unknown")), true)


func _on_replay_read_completed(result: Dictionary) -> void:
	_set_busy(false)
	if not bool(result.get("accepted", false)):
		_set_status("录像校验失败：%s" % str(result.get("error_code", "unknown")), true)
		return
	_open_replay_artifact(result.get("artifact", {}), false)


func _open_replay_artifact(artifact: Dictionary, local_source: bool) -> void:
	_set_busy(true)
	_set_status("正在载入录像播放器…")
	var viewer := await _ensure_replay_viewer()
	_set_busy(false)
	if viewer == null:
		_set_status("录像播放器加载失败。", true)
		return
	var opened: Dictionary = viewer.load_public_replay(
		_contract_owner, artifact.get("manifest"), artifact.get("frames"),
		artifact.get("match_envelope", {})
	)
	if not bool(opened.get("accepted", false)):
		_set_status("录像展示失败：%s" % str(opened.get("error_code", "unknown")), true)
		return
	%ReplayOverlay.visible = true
	_set_status(
		"本机录像已打开；只能前后逐帧查看，不会接手对局。"
		if local_source else
		"公开录像已在 UI 中打开，不会恢复引擎状态或接手任一回合。"
	)


func _ensure_replay_viewer() -> Node:
	_startup_performance["viewer_load_stage"] = "enter"
	if _replay_viewer != null and _replay_viewer.has_method("load_public_replay"):
		_startup_performance["viewer_load_stage"] = "already_loaded"
		return _replay_viewer
	var placeholder := _replay_viewer
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null:
		_startup_performance["viewer_load_stage"] = "tree_unavailable"
		return null
	# The status label is rendered before parsing the large BattleScene-derived
	# viewer. Loading this scene through the threaded loader is unsafe because its
	# GDScript class dependency graph is main-thread owned.
	await tree.process_frame
	_startup_performance["viewer_load_stage"] = "loading_resource"
	var resource: Variant = load(PUBLIC_REPLAY_VIEWER_SCENE_PATH)
	if not (resource is PackedScene):
		_startup_performance["viewer_resource_type"] = type_string(typeof(resource))
		_startup_performance["viewer_load_stage"] = "resource_invalid"
		return null
	var viewer := (resource as PackedScene).instantiate()
	if placeholder != null and is_instance_valid(placeholder):
		var parent := placeholder.get_parent()
		if parent != null:
			parent.remove_child(placeholder)
			placeholder.queue_free()
			parent.add_child(viewer)
		else:
			%ReplayOverlay.add_child(viewer)
	else:
		%ReplayOverlay.add_child(viewer)
	viewer.name = "ReplayViewer"
	viewer.close_requested.connect(_close_replay)
	_replay_viewer = viewer
	_startup_performance["viewer_load_stage"] = "ready"
	return viewer


func _on_challenge(release_id: String, replay_id: String) -> void:
	if _client == null:
		return
	_set_busy(true)
	_set_status("正在解析录像绑定的精确策略版本…")
	var started: Dictionary = _client.resolve_challenge(release_id, replay_id)
	if not bool(started.get("accepted", false)):
		_set_busy(false)
		_set_status("挑战解析失败：%s" % str(started.get("error_code", "unknown")), true)


func _apply_challenge_intent(intent: Dictionary) -> void:
	var binder_script := load(BINDER_SCRIPT_PATH) as Script
	if binder_script == null:
		_set_status("本机版本绑定组件不可用。", true)
		return
	var bound: Dictionary = binder_script.bind(intent, AuthorStrategyPackageCatalog)
	if not bool(bound.get("accepted", false)):
		_set_status("本机无法绑定该版本：%s" % str(bound.get("error_code", "unknown")), true)
		return
	if not GameManager.set_author_strategy_selection(bound.get("selection", {})):
		_set_status("本机拒绝了策略选择。", true)
		return
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
	GameManager.goto_battle_setup()


func _on_share(uri: String) -> void:
	if uri.is_empty():
		_set_status("分享标识不可用。", true)
		return
	DisplayServer.clipboard_set(uri)
	_set_status("已复制录像分享标识。接收方仍会重新下载并校验。")


func _close_replay() -> void:
	%ReplayOverlay.visible = false


func _on_back() -> void:
	if %LocalPackageDeleteDialog.visible:
		_on_local_package_delete_canceled()
		return
	if %StrategyDetailOverlay.visible:
		_close_strategy_detail()
		return
	_cancel_local_package_capture(false)
	_reset_quick_install("一键下载安装")
	GameManager.goto_main_menu()


func _set_busy(busy: bool) -> void:
	# A statistics/download response must not unlock import controls while a
	# selected document is still being captured in the background.
	busy = busy or _local_package_import_busy
	%RefreshButton.disabled = busy
	%ImportLocalPackageButton.disabled = busy
	%QuickImportButton.disabled = busy
	%OpenBattleSetupButton.disabled = busy
	for node: Node in %LocalPackageList.find_children(
		"LocalPackageDeleteButton", "Button", true, false
	):
		(node as Button).disabled = busy
	for button_name: String in [
		"NativeReplayDeleteButton", "PublicReplayDeleteButton",
	]:
		for node: Node in %LocalReplayList.find_children(
			button_name, "Button", true, false
		):
			(node as Button).disabled = busy
	for node: Node in %MatchHistoryList.find_children(
		"ContinuousLadderReplayDownloadButton", "Button", true, false
	):
		(node as Button).disabled = busy


func _set_status(text: String, is_error: bool = false) -> void:
	_workspace_statuses[_active_workspace] = {"text": text, "error": is_error}
	_display_status(text, is_error)


func _set_workspace_status(workspace_id: String, text: String, is_error: bool = false) -> void:
	if is_inside_tree():
		call_deferred("_apply_readable_typography", self)
	else:
		_apply_readable_typography(self)
	_workspace_statuses[workspace_id] = {"text": text, "error": is_error}
	if workspace_id == _active_workspace:
		_display_status(text, is_error)
	_apply_mobile_presentation()


func _restore_workspace_status(workspace_id: String) -> void:
	var snapshot: Dictionary = _workspace_statuses.get(workspace_id, {})
	_display_status(str(snapshot.get("text", "策略中心已就绪。")), bool(snapshot.get("error", false)))


func _display_status(text: String, is_error: bool = false) -> void:
	%StatusStrip.visible = is_error
	%DetailStatusLabel.visible = is_error
	if %StrategyDetailOverlay.visible:
		%DetailStatusLabel.text = text
		%DetailStatusLabel.modulate = Color(1.0, 0.64, 0.64) if is_error else HUD_THEME_SCRIPT.TEXT_MUTED
	%StatusLabel.text = text
	%StatusLabel.tooltip_text = text
	var accent := Color(1.0, 0.42, 0.42) if is_error else Color(0.28, 0.92, 1.0)
	%StatusLabel.modulate = Color(1.0, 0.64, 0.64) if is_error else Color(0.75, 0.92, 1.0)
	%StatusDot.modulate = accent
	%StatusStrip.add_theme_stylebox_override("panel", HUD_THEME_SCRIPT.panel_style(
		Color(0.05, 0.022, 0.026, 0.94) if is_error else Color(0.014, 0.038, 0.058, 0.94),
		Color(accent.r, accent.g, accent.b, 0.58), 10
	))


func _service_error_text(error_code: String) -> String:
	if _local_replay_count > 0:
		return "平台服务暂时不可用（%s）；%d 个本机录像仍可直接观看。" % [
			error_code, _local_replay_count,
		]
	return "请求失败：%s" % error_code


func _empty_state_card(title: String, summary: String) -> PanelContainer:
	return _notice_card(title, summary, false)


func _notice_card(title: String, summary: String, warning: bool) -> PanelContainer:
	var accent := Color(1.0, 0.58, 0.28) if warning else Color(0.30, 0.78, 0.94)
	var card := PanelContainer.new()
	card.name = "NoticeCard" if not warning else "WarningCard"
	card.add_theme_stylebox_override("panel", _list_card_style(accent))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	card.add_child(content)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.52) if warning else HUD_THEME_SCRIPT.TEXT)
	content.add_child(title_label)
	var summary_label := Label.new()
	summary_label.text = summary
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_color_override("font_color", HUD_THEME_SCRIPT.TEXT_MUTED)
	content.add_child(summary_label)
	return card


func _list_card_style(accent: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = HUD_THEME_SCRIPT.panel_style(
		Color(0.018, 0.052, 0.076, 0.94), Color(accent.r, accent.g, accent.b, 0.52), 12
	)
	style.set_border_width_all(1)
	style.shadow_size = 4
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 11
	style.content_margin_bottom = 11
	return style


func _pill_style(accent: Color, filled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.92 if filled else 0.22)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _style_strategy_button(button: Button, selected: bool) -> void:
	if button == null:
		return
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.set_meta("hud_card_selected", selected)
	button.add_theme_color_override("font_color", Color(0.04, 0.10, 0.12) if selected else HUD_THEME_SCRIPT.TEXT)
	button.add_theme_color_override("font_hover_color", Color(0.04, 0.10, 0.12) if selected else Color.WHITE)
	button.add_theme_stylebox_override("normal", _strategy_button_style(selected, false, false))
	button.add_theme_stylebox_override("hover", _strategy_button_style(selected, true, false))
	button.add_theme_stylebox_override("pressed", _strategy_button_style(true, true, true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _strategy_button_style(selected: bool, hover: bool, pressed: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = HUD_THEME_SCRIPT.button_style(HUD_THEME_SCRIPT.ACCENT, hover, pressed)
	if selected and not pressed:
		style.bg_color = Color(0.24, 0.84, 1.0, 0.92)
		style.border_color = Color(0.76, 1.0, 1.0, 1.0)
		style.set_border_width_all(2)
	return style


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


func apply_catalog_for_test(items: Array) -> void:
	_apply_catalog(items)


func apply_detail_for_test(detail: Dictionary) -> void:
	_apply_detail(detail)


func apply_statistics_for_test(statistics: Dictionary) -> void:
	_apply_statistics(statistics)


func apply_local_package_catalog_for_test(report: Dictionary) -> void:
	_apply_local_package_catalog(report)


func configure_package_delete_catalog_for_test(catalog: Variant) -> void:
	_package_delete_catalog_override = catalog


func configure_marketplace_install_catalog_for_test(catalog: Variant) -> void:
	_package_install_catalog_override = catalog


func configure_continuous_ladder_replay_store_for_test(store: Variant) -> void:
	_continuous_ladder_replay_store_override = store


func configure_continuous_ladder_client_for_test(client: Node) -> void:
	_client = client


func apply_marketplace_latest_for_test(items: Array, next_cursor: Variant) -> void:
	_apply_marketplace_latest(items, next_cursor)


func apply_marketplace_strategy_rankings_for_test(
	items: Array,
	next_cursor: Variant,
	snapshot_id: String
) -> void:
	_apply_marketplace_strategy_rankings(items, next_cursor, snapshot_id)


func apply_marketplace_author_rankings_for_test(
	items: Array,
	next_cursor: Variant,
	snapshot_id: String
) -> void:
	_apply_marketplace_author_rankings(items, next_cursor, snapshot_id)


func apply_marketplace_author_strategies_for_test(author: Dictionary, items: Array) -> void:
	_apply_marketplace_author_strategies(author, items)


func apply_marketplace_strategy_archive_for_test(
	strategy: Dictionary, matches: Array
) -> void:
	_apply_marketplace_strategy_archive(strategy, matches)


func apply_marketplace_author_top_strategies_for_test(
	author: Dictionary, items: Array
) -> void:
	_apply_marketplace_author_top_strategies(author, items)


func apply_marketplace_package_download_for_test(result: Dictionary) -> void:
	_apply_marketplace_package_download(result)


func apply_continuous_ladder_leaderboard_for_test(items: Array, profile_id: String) -> void:
	_apply_continuous_ladder_leaderboard(items, profile_id)


func apply_continuous_ladder_authors_for_test(items: Array, profile_id: String) -> void:
	_apply_continuous_ladder_authors(items, profile_id)


func apply_continuous_ladder_release_profile_for_test(profile: Dictionary) -> void:
	_apply_continuous_ladder_release_profile(profile)


func apply_continuous_ladder_author_profile_for_test(profile: Dictionary) -> void:
	_apply_continuous_ladder_author_profile(profile)


func apply_continuous_ladder_series_replay_for_test(replay: Dictionary) -> void:
	_apply_continuous_ladder_series_replay(replay)


func show_marketplace_strategy_for_test(item: Dictionary) -> void:
	_show_marketplace_strategy(item)


func select_marketplace_board_for_test(board_id: String) -> void:
	_select_marketplace_board(board_id, false)


func workspace_status_snapshot() -> Dictionary:
	return _workspace_statuses.duplicate(true)


func configure_replay_removal_service_for_test(service: Variant) -> void:
	_replay_removal_service_override = service


func configure_clipboard_writer_for_test(writer: Variant) -> void:
	_clipboard_writer_override = writer


func configure_storage_paths_for_test() -> void:
	_configure_storage_paths()


func configure_local_replay_for_test(contract_owner: Variant, library: Variant) -> void:
	_contract_owner = contract_owner
	_local_replay_library = library
	_skip_service_initialization_for_tests = true


func configure_native_replay_for_test(match_index: Variant, replay_locator: Variant) -> void:
	_native_match_index = match_index
	_native_replay_locator = replay_locator
