extends Control

const AppVersionScript := preload("res://scripts/app/AppVersion.gd")
const FeedbackClientScript := preload("res://scripts/network/FeedbackClient.gd")
const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const SwissTournamentScript := preload("res://scripts/tournament/SwissTournament.gd")
const UpdateCheckerScript := preload("res://scripts/network/UpdateChecker.gd")
const UserVisitClientScript := preload("res://scripts/network/UserVisitClient.gd")
const MENU_VERTICAL_SHIFT := 88.0
const MAIN_MENU_BUTTON_WIDTH := 312.0
const MAIN_MENU_BUTTON_HEIGHT := 52.0
const MAIN_MENU_FEATURED_ACCENT := Color(1.0, 0.70, 0.24, 1.0)
const MAIN_MENU_DANGER_ACCENT := Color(1.0, 0.38, 0.34, 1.0)
const CHAMPION_PREVIEW_PLAYER_NAME := "冠军玩家"
const CHAMPION_PREVIEW_DECK_ID := 575716
const CHAMPION_PREVIEW_PLAYER_COUNT := 16
const FEEDBACK_STATE_PATH := "user://feedback_submit_state.json"
const FEEDBACK_LIMIT := 3
const FEEDBACK_WINDOW_SECONDS := 24 * 60 * 60
const XHS_QR_PATH := "res://assets/ui/xiaohongshu_qr.png"
const XHS_DISPLAY_NAME := "波导的勇者"
const XHS_ID := "5417688847"
const XHS_PROFILE_URL := "https://www.xiaohongshu.com/search_result?keyword=5417688847"
const GAME_HOME_URL := "https://ptcg.skillserver.cn/"
const TCG_MIK_URL := "https://tcg.mik.moe/"
const CORNER_ACTION_BUTTON_SIZE := 58.0
const CORNER_ACTION_BUTTON_SPACING := 14.0
const CORNER_ACTION_BUTTON_RIGHT_MARGIN := 18.0
const CORNER_ACTION_BUTTON_BOTTOM_MARGIN := 18.0
const CORNER_ACTION_LABEL_GAP := 8.0
const CORNER_ACTION_LABEL_MIN_WIDTH := 76.0
const FEEDBACK_ICON_PATH := "res://assets/ui/main_action_feedback.png"
const ABOUT_ICON_PATH := "res://assets/ui/main_action_about.png"
const UPDATE_ICON_PATH := "res://assets/ui/main_action_update.png"
const FEEDBACK_OVERLAY_NAME := "FeedbackOverlay"
const HUD_MODAL_OVERLAY_NAME := "HudModalOverlay"

var _update_checker: Node = null
var _feedback_client: Node = null
var _user_visit_client: Node = null
var _update_button: Button = null
var _feedback_button: Button = null
var _manual_update_button: Button = null
var _about_button: Button = null
var _available_update: Dictionary = {}
var _manual_update_requested := false
var _feedback_submit_in_progress := false
var _pending_feedback_payload: Dictionary = {}
var _feedback_panel: PanelContainer = null
var _feedback_submit_button: Button = null
var _feedback_close_button: Button = null
var _feedback_name_input: LineEdit = null
var _feedback_text_edit: TextEdit = null
var _feedback_quota_label: Label = null
var _hud_modal_overlay: Control = null
var _hud_modal_panel: PanelContainer = null
var _corner_action_label: PanelContainer = null
var _corner_action_label_text: Label = null
var _corner_action_hover_button: Button = null


func _ready() -> void:
	_apply_main_menu_hud()
	_setup_version_and_updates()
	%BtnSettings.text = "AI 设置"
	%BtnStartBattle.pressed.connect(_on_start_battle)
	%BtnTournament.pressed.connect(_on_tournament)
	%BtnDeckManager.pressed.connect(_on_deck_manager)
	%BtnBattleReplay.pressed.connect(_on_battle_replay)
	%BtnSettings.pressed.connect(_on_settings)
	%BtnQuit.pressed.connect(_on_quit)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.ctrl_pressed and key_event.shift_pressed and key_event.keycode == KEY_C:
		get_viewport().set_input_as_handled()
		_open_champion_preview()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_resize_feedback_panel()
		_resize_hud_modal_panel()
		if _corner_action_hover_button != null:
			_position_corner_action_label(_corner_action_hover_button)


func _apply_main_menu_hud() -> void:
	var menu := get_node_or_null("VBoxContainer") as VBoxContainer
	if menu != null:
		menu.offset_left = -170.0
		menu.offset_top = -175.0 + MENU_VERTICAL_SHIFT
		menu.offset_right = 170.0
		menu.offset_bottom = 175.0 + MENU_VERTICAL_SHIFT
		menu.add_theme_constant_override("separation", 12)
		var deck_button := get_node_or_null("%BtnDeckManager") as Button
		if deck_button != null and deck_button.get_parent() == menu:
			menu.move_child(deck_button, 1)
	for button_name: String in ["BtnStartBattle", "BtnTournament", "BtnDeckManager", "BtnBattleReplay", "BtnSettings", "BtnQuit"]:
		var button := get_node_or_null("%" + button_name) as Button
		if button == null:
			continue
		var role := _main_menu_button_role(button_name)
		var is_primary := role == "primary"
		var is_featured := role == "featured"
		var accent := _main_menu_button_accent(role)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size = _main_menu_button_minimum_size(role)
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color(0.03, 0.07, 0.10, 1.0))
		button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.62 if is_featured else 0.34))
		button.add_theme_constant_override("outline_size", 2 if is_featured else 1)
		button.add_theme_stylebox_override("normal", _main_menu_button_style(accent, is_primary, false, false, is_featured))
		button.add_theme_stylebox_override("hover", _main_menu_button_style(accent, is_primary, true, false, is_featured))
		button.add_theme_stylebox_override("pressed", _main_menu_button_style(accent, is_primary, true, true, is_featured))
		button.add_theme_stylebox_override("disabled", _main_menu_button_style(Color(0.30, 0.34, 0.38, 1.0), false, false, false))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		if is_featured:
			button.tooltip_text = "查看推荐卡组、管理本地卡组、导入新卡组"


func _main_menu_button_role(button_name: String) -> String:
	match button_name:
		"BtnStartBattle":
			return "primary"
		"BtnDeckManager":
			return "featured"
		"BtnQuit":
			return "danger"
		_:
			return "secondary"


func _main_menu_button_accent(role: String) -> Color:
	match role:
		"primary":
			return HudThemeScript.ACCENT
		"featured":
			return MAIN_MENU_FEATURED_ACCENT
		"danger":
			return MAIN_MENU_DANGER_ACCENT
		_:
			return HudThemeScript.ACCENT


func _main_menu_button_minimum_size(role: String) -> Vector2:
	return Vector2(MAIN_MENU_BUTTON_WIDTH, MAIN_MENU_BUTTON_HEIGHT)


func _main_menu_button_style(accent: Color, primary: bool, hover: bool, pressed: bool, featured: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var base := Color(0.010, 0.042, 0.060, 0.78)
	var accent_fill := Color(accent.r, accent.g, accent.b, 0.88)
	var fill_weight := 0.08
	if primary:
		fill_weight = 0.22
	if featured:
		fill_weight = 0.24
	style.bg_color = base.lerp(accent_fill, fill_weight)
	if hover:
		style.bg_color = base.lerp(accent_fill, minf(fill_weight + 0.12, 0.38))
	if pressed:
		style.bg_color = base.lerp(accent_fill, 0.42)
	var border_alpha := 0.54
	if primary:
		border_alpha = 0.92
	if featured:
		border_alpha = 0.96
	style.border_color = Color(accent.r, accent.g, accent.b, border_alpha)
	if hover:
		style.border_color = Color(accent.r, accent.g, accent.b, 1.0)
	style.set_border_width_all(2 if featured or primary or hover else 1)
	style.set_corner_radius_all(11)
	var shadow_alpha := 0.06
	if primary:
		shadow_alpha = 0.20
	if featured:
		shadow_alpha = 0.22
	style.shadow_color = Color(accent.r, accent.g, accent.b, shadow_alpha + (0.08 if hover else 0.0))
	style.shadow_size = 12 if featured else (8 if primary or hover else 3)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _main_menu_round_button_style(accent: Color, hover: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.050, 0.072, 0.68)
	if hover:
		style.bg_color = Color(0.035, 0.112, 0.145, 0.84)
	if pressed:
		style.bg_color = Color(accent.r, accent.g, accent.b, 0.26)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.66 if not hover else 0.98)
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(CORNER_ACTION_BUTTON_SIZE * 0.5))
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.26 if hover else 0.16)
	style.shadow_size = 12 if hover else 7
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _ensure_corner_action_buttons() -> void:
	if _feedback_button == null:
		_feedback_button = _create_corner_icon_button("FeedbackButton", FEEDBACK_ICON_PATH, "建议反馈", _corner_action_left_offset(3), HudThemeScript.ACCENT_WARM)
		_feedback_button.pressed.connect(_on_feedback_button_pressed)
		add_child(_feedback_button)
	if _about_button == null:
		_about_button = _create_corner_icon_button("AboutButton", ABOUT_ICON_PATH, "关于", _corner_action_left_offset(2), HudThemeScript.ACCENT)
		_about_button.pressed.connect(_on_about_button_pressed)
		add_child(_about_button)
	if _manual_update_button == null:
		_manual_update_button = _create_corner_icon_button("ManualUpdateButton", UPDATE_ICON_PATH, "检查更新", _corner_action_left_offset(1), HudThemeScript.ACCENT_WARM)
		_manual_update_button.pressed.connect(_on_manual_update_button_pressed)
		add_child(_manual_update_button)


func _corner_action_left_offset(index_from_right: int) -> float:
	return -CORNER_ACTION_BUTTON_RIGHT_MARGIN - (CORNER_ACTION_BUTTON_SIZE * float(index_from_right)) - (CORNER_ACTION_BUTTON_SPACING * float(max(index_from_right - 1, 0)))


func _create_corner_icon_button(button_name: String, icon_path: String, tip: String, left_offset: float, accent: Color) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = ""
	button.tooltip_text = ""
	button.set_meta("corner_action_label", tip)
	button.icon = load(icon_path) as Texture2D
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(CORNER_ACTION_BUTTON_SIZE, CORNER_ACTION_BUTTON_SIZE)
	button.layout_mode = 1
	button.anchor_left = 1.0
	button.anchor_top = 1.0
	button.anchor_right = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = left_offset
	button.offset_top = -CORNER_ACTION_BUTTON_BOTTOM_MARGIN - CORNER_ACTION_BUTTON_SIZE
	button.offset_right = left_offset + CORNER_ACTION_BUTTON_SIZE
	button.offset_bottom = -CORNER_ACTION_BUTTON_BOTTOM_MARGIN
	button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	button.add_theme_color_override("font_color", Color(0.94, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.03, 0.07, 0.10, 1.0))
	button.add_theme_constant_override("h_separation", 0)
	button.add_theme_constant_override("icon_max_width", int(CORNER_ACTION_BUTTON_SIZE))
	button.add_theme_stylebox_override("normal", _main_menu_round_button_style(accent, false, false))
	button.add_theme_stylebox_override("hover", _main_menu_round_button_style(accent, true, false))
	button.add_theme_stylebox_override("pressed", _main_menu_round_button_style(accent, true, true))
	button.add_theme_stylebox_override("disabled", _main_menu_round_button_style(Color(0.35, 0.40, 0.46, 1.0), false, false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.mouse_entered.connect(_show_corner_action_label.bind(button))
	button.mouse_exited.connect(_hide_corner_action_label.bind(button))
	return button


func _ensure_corner_action_label() -> void:
	if _corner_action_label != null:
		return
	_corner_action_label = PanelContainer.new()
	_corner_action_label.name = "CornerActionHoverLabel"
	_corner_action_label.visible = false
	_corner_action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corner_action_label.layout_mode = 1
	_corner_action_label.z_index = 80
	_corner_action_label.add_theme_stylebox_override("panel", _corner_action_label_style())
	add_child(_corner_action_label)

	_corner_action_label_text = Label.new()
	_corner_action_label_text.name = "CornerActionHoverText"
	_corner_action_label_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corner_action_label_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_corner_action_label_text.add_theme_font_size_override("font_size", 15)
	_corner_action_label_text.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	_corner_action_label_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.66))
	_corner_action_label_text.add_theme_constant_override("shadow_offset_y", 1)
	_corner_action_label.add_child(_corner_action_label_text)


func _corner_action_label_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.010, 0.045, 0.066, 0.92)
	style.border_color = Color(0.24, 0.86, 1.0, 0.88)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.68, 1.0, 0.22)
	style.shadow_size = 9
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _show_corner_action_label(button: Button) -> void:
	if button == null:
		return
	_ensure_corner_action_label()
	if _corner_action_label == null or _corner_action_label_text == null:
		return
	_corner_action_hover_button = button
	_corner_action_label_text.text = str(button.get_meta("corner_action_label", "")).strip_edges()
	if _corner_action_label_text.text == "":
		_corner_action_label_text.text = button.name
	_corner_action_label.visible = true
	_corner_action_label.move_to_front()
	_position_corner_action_label(button)


func _hide_corner_action_label(button: Button = null) -> void:
	if button != null and _corner_action_hover_button != button:
		return
	_corner_action_hover_button = null
	if _corner_action_label != null:
		_corner_action_label.visible = false


func _position_corner_action_label(button: Button) -> void:
	if button == null or _corner_action_label == null or _corner_action_label_text == null:
		return
	var text_min := _corner_action_label_text.get_combined_minimum_size()
	var desired := Vector2(maxf(CORNER_ACTION_LABEL_MIN_WIDTH, text_min.x + 28.0), 32.0)
	_corner_action_label.custom_minimum_size = desired
	_corner_action_label.size = desired
	var button_rect := button.get_global_rect()
	var target := Vector2(
		button_rect.position.x + (button_rect.size.x - desired.x) * 0.5,
		button_rect.position.y - desired.y - CORNER_ACTION_LABEL_GAP
	)
	var viewport_size := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	target.x = clampf(target.x, 8.0, maxf(8.0, viewport_size.x - desired.x - 8.0))
	target.y = maxf(8.0, target.y)
	_corner_action_label.global_position = target


func _setup_version_and_updates() -> void:
	var version_label := get_node_or_null("VersionLabel") as Label
	if version_label != null:
		version_label.text = AppVersionScript.DISPLAY_VERSION
		version_label.add_theme_font_size_override("font_size", 14)
		version_label.add_theme_color_override("font_color", Color(0.70, 0.82, 0.90, 0.92))

	_ensure_update_button()
	_ensure_corner_action_buttons()
	call_deferred("_start_update_check")
	call_deferred("_send_startup_visit_ping")


func _send_startup_visit_ping() -> void:
	if GameManager.has_meta("startup_visit_ping_sent"):
		return
	GameManager.set_meta("startup_visit_ping_sent", true)
	if _user_visit_client == null:
		_user_visit_client = UserVisitClientScript.new()
		_user_visit_client.visit_recorded.connect(_on_user_visit_recorded)
		_user_visit_client.visit_failed.connect(_on_user_visit_failed)
		add_child(_user_visit_client)
	var err: int = int(_user_visit_client.call("report_startup_visit", {
		"source": "main_menu_startup",
	}))
	if err != OK and err != ERR_BUSY:
		print_debug("[UserVisit] startup visit report did not start: %d" % err)


func _on_user_visit_recorded(_response: Dictionary) -> void:
	print_debug("[UserVisit] startup visit recorded")


func _on_user_visit_failed(message: String) -> void:
	print_debug("[UserVisit] %s" % message)


func _ensure_update_button() -> void:
	if _update_button != null:
		return
	_update_button = Button.new()
	_update_button.name = "UpdateButton"
	_update_button.visible = false
	_update_button.text = "发现新版本"
	_update_button.custom_minimum_size = Vector2(180, 38)
	_update_button.layout_mode = 1
	_update_button.anchor_left = 0.5
	_update_button.anchor_top = 1.0
	_update_button.anchor_right = 0.5
	_update_button.anchor_bottom = 1.0
	_update_button.offset_left = -90.0
	_update_button.offset_top = -76.0
	_update_button.offset_right = 90.0
	_update_button.offset_bottom = -38.0
	_update_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_update_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_update_button.add_theme_font_size_override("font_size", 14)
	_update_button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	_update_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_update_button.add_theme_color_override("font_pressed_color", Color(0.03, 0.07, 0.10, 1.0))
	_update_button.add_theme_stylebox_override("normal", _main_menu_button_style(HudThemeScript.ACCENT_WARM, false, false, false))
	_update_button.add_theme_stylebox_override("hover", _main_menu_button_style(HudThemeScript.ACCENT_WARM, false, true, false))
	_update_button.add_theme_stylebox_override("pressed", _main_menu_button_style(HudThemeScript.ACCENT_WARM, false, true, true))
	_update_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_update_button.pressed.connect(_on_update_button_pressed)
	add_child(_update_button)


func _start_update_check(force: bool = false) -> void:
	if _update_checker != null:
		var existing_err: int = int(_update_checker.call("check_for_updates", force))
		if existing_err != OK and existing_err != ERR_BUSY:
			_on_update_check_failed("更新检查启动失败：%d" % existing_err)
		return
	_update_checker = UpdateCheckerScript.new()
	_update_checker.update_available.connect(_on_update_available)
	_update_checker.no_update.connect(_on_no_update)
	_update_checker.check_failed.connect(_on_update_check_failed)
	add_child(_update_checker)
	var err: int = int(_update_checker.call("check_for_updates", force))
	if err != OK and err != ERR_BUSY:
		_on_update_check_failed("更新检查启动失败：%d" % err)


func _on_update_available(info: Dictionary) -> void:
	var was_manual := _manual_update_requested
	_manual_update_requested = false
	_set_manual_update_busy(false)
	_available_update = info.duplicate(true)
	if _update_button == null:
		_ensure_update_button()
	if _update_button != null:
		var display_version := str(info.get("display_version", "v%s" % str(info.get("latest_version", ""))))
		_update_button.text = "发现新版本 %s" % display_version
		_update_button.visible = true
	if was_manual:
		_show_update_dialog(_available_update)


func _on_no_update(info: Dictionary) -> void:
	var was_manual := _manual_update_requested
	_manual_update_requested = false
	_set_manual_update_busy(false)
	_available_update = {}
	if _update_button != null:
		_update_button.visible = false
	if was_manual:
		var display_version := str(info.get("display_version", AppVersionScript.DISPLAY_VERSION))
		_show_update_status_dialog("已是最新版本", "当前版本：%s\n服务器版本：%s" % [AppVersionScript.DISPLAY_VERSION, display_version])


func _on_update_check_failed(message: String) -> void:
	if _manual_update_requested:
		_manual_update_requested = false
		_set_manual_update_busy(false)
		_show_update_status_dialog("检查更新失败", "%s\n请稍后重试，或直接前往下载页查看。" % message)
		return
	print_debug("[UpdateChecker] %s" % message)


func _on_update_button_pressed() -> void:
	if _available_update.is_empty():
		return
	_show_update_dialog(_available_update)


func _on_manual_update_button_pressed() -> void:
	_hide_corner_action_label(_manual_update_button)
	_manual_update_requested = true
	_set_manual_update_busy(true)
	_start_update_check(true)


func _set_manual_update_busy(busy: bool) -> void:
	if _manual_update_button == null:
		return
	_manual_update_button.disabled = busy
	_manual_update_button.text = ""
	_manual_update_button.modulate = Color(0.72, 0.82, 0.90, 0.78) if busy else Color.WHITE
	_manual_update_button.set_meta("corner_action_label", "正在检查更新" if busy else "检查更新")
	if _corner_action_hover_button == _manual_update_button:
		_show_corner_action_label(_manual_update_button)


func _show_update_status_dialog(title: String, message: String) -> void:
	_show_hud_modal(title, message, [
		{
			"id": "close",
			"text": "确定",
			"accent": HudThemeScript.ACCENT_WARM,
			"primary": true,
		},
	], Vector2(460, 260))


func _on_about_button_pressed() -> void:
	_hide_corner_action_label(_about_button)
	_show_about_dialog()


func _show_about_dialog() -> void:
	_show_hud_modal("关于 PTCG Deck Agent", _format_about_text(), [
		{
			"id": "close",
			"text": "我知道了",
			"accent": HudThemeScript.ACCENT_WARM,
			"primary": true,
		},
	], Vector2(760, 520), true)


func _format_about_text() -> String:
	return "\n".join(PackedStringArray([
		"PTCG Deck Agent 是一个免费、开源、非商业的本地练牌与 AI 陪练工具，旨在帮助玩家进行宝可梦集换式卡牌游戏的练习、复盘与技术研究。",
		"",
		"开源协议",
		"本软件源代码以 Apache License 2.0 开源发布。完整条款以项目仓库随附的 LICENSE 文件为准。",
		"项目地址：https://github.com/beralee/PtcgDeckAgent",
		"游戏主页：[url=%s]%s[/url]" % [GAME_HOME_URL, GAME_HOME_URL],
		"",
		"数据来源与感谢",
		"本项目的卡组导入、卡牌资料补全、卡图链接以及卡组中心推荐文章中的赛事/卡表引用，依赖 Cryst's Cards Database 提供的简中 PTCG 数据与公开页面支持：[url=%s]%s[/url]" % [TCG_MIK_URL, TCG_MIK_URL],
		"感谢 tcg.mik.moe 长期整理和开放卡牌查询、卡组分析、赛事与环境统计等资料，让本工具能够把公开卡表转化为本地练牌、复盘和 AI 研究素材。",
		"PTCG Deck Agent 与 tcg.mik.moe 没有官方从属或合作关系；相关数据、页面和服务仍归其原维护者所有，请在使用本工具时尊重原站点和数据来源。",
		"",
		"版权与商标声明",
		"Pokemon、Pokemon、宝可梦、Pokemon Trading Card Game、PTCG 以及相关卡牌名称、图像、规则文本、商标和其他素材，版权与商标权归 Nintendo、Creatures Inc.、GAME FREAK inc.、The Pokemon Company 及其相关权利方所有。",
		"",
		"本项目并非官方产品，未获得上述权利方授权、赞助、认可或背书。本项目不销售卡牌素材，不提供商业发行内容，仅用于学习、练牌、个人研究和非商业交流。",
		"",
		"如果你是相关权利方并认为项目内容需要调整，请通过项目仓库联系维护者。"
	]))


func _show_hud_modal(title: String, message: String, actions: Array, preferred_size: Vector2 = Vector2(520, 300), body_bbcode: bool = false) -> void:
	_hide_hud_modal()
	_hud_modal_overlay = Control.new()
	_hud_modal_overlay.name = HUD_MODAL_OVERLAY_NAME
	_hud_modal_overlay.layout_mode = 1
	_hud_modal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_hud_modal_overlay)

	var shade := ColorRect.new()
	shade.name = "HudModalShade"
	shade.layout_mode = 1
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.012, 0.024, 0.60)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud_modal_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.name = "HudModalCenter"
	center.layout_mode = 1
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_modal_overlay.add_child(center)

	_hud_modal_panel = PanelContainer.new()
	_hud_modal_panel.name = "HudModalPanel"
	_hud_modal_panel.set_meta("preferred_size", preferred_size)
	_hud_modal_panel.add_theme_stylebox_override("panel", _feedback_panel_style())
	center.add_child(_hud_modal_panel)
	_resize_hud_modal_panel()

	var root := VBoxContainer.new()
	root.name = "HudModalRoot"
	root.add_theme_constant_override("separation", 14)
	_hud_modal_panel.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.94, 0.99, 1.0, 1.0))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.74, 1.0, 0.58))
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	header.add_child(title_label)

	var close_button := _create_feedback_action_button("×", HudThemeScript.ACCENT, Vector2(42, 38))
	close_button.pressed.connect(_hide_hud_modal)
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.name = "HudModalScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, maxf(120.0, preferred_size.y - 170.0))
	root.add_child(scroll)

	if body_bbcode:
		var rich_body := RichTextLabel.new()
		rich_body.name = "HudModalBody"
		rich_body.bbcode_enabled = true
		rich_body.text = message
		rich_body.fit_content = true
		rich_body.scroll_active = false
		rich_body.selection_enabled = true
		rich_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rich_body.add_theme_font_size_override("normal_font_size", 16)
		rich_body.add_theme_color_override("default_color", Color(0.84, 0.93, 1.0, 1.0))
		rich_body.add_theme_color_override("font_selected_color", Color(0.03, 0.07, 0.10, 1.0))
		rich_body.add_theme_color_override("selection_color", Color(0.30, 0.86, 1.0, 0.72))
		rich_body.meta_clicked.connect(_on_hud_modal_meta_clicked)
		scroll.add_child(rich_body)
	else:
		var body := Label.new()
		body.name = "HudModalBody"
		body.text = message
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", 16)
		body.add_theme_color_override("font_color", Color(0.84, 0.93, 1.0, 1.0))
		body.add_theme_constant_override("line_spacing", 6)
		scroll.add_child(body)
	HudThemeScript.style_scroll_container(scroll)

	var footer := HBoxContainer.new()
	footer.name = "HudModalFooter"
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)

	for raw_action: Variant in actions:
		if not (raw_action is Dictionary):
			continue
		var action := raw_action as Dictionary
		var action_id := str(action.get("id", "close"))
		var accent: Color = action.get("accent", HudThemeScript.ACCENT) as Color
		var minimum_width := 132.0 if bool(action.get("primary", false)) else 118.0
		var button := _create_feedback_action_button(str(action.get("text", "确定")), accent, Vector2(minimum_width, 44))
		button.pressed.connect(_on_hud_modal_action_pressed.bind(action_id))
		footer.add_child(button)

	_hud_modal_overlay.move_to_front()


func _hide_hud_modal() -> void:
	var existing := get_node_or_null(HUD_MODAL_OVERLAY_NAME)
	if existing != null:
		if existing.get_parent() != null:
			existing.get_parent().remove_child(existing)
		existing.queue_free()
	_hud_modal_overlay = null
	_hud_modal_panel = null


func _resize_hud_modal_panel() -> void:
	if _hud_modal_panel == null:
		return
	var preferred: Vector2 = _hud_modal_panel.get_meta("preferred_size", Vector2(520, 300)) as Vector2
	var viewport_size := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	_hud_modal_panel.custom_minimum_size = Vector2(
		minf(preferred.x, maxf(320.0, viewport_size.x - 56.0)),
		minf(preferred.y, maxf(230.0, viewport_size.y - 56.0))
	)


func _on_hud_modal_action_pressed(action_id: String) -> void:
	match action_id:
		"download_update":
			_open_update_download_page()
			_hide_hud_modal()
		"ignore_update":
			_ignore_current_update_version()
			_hide_hud_modal()
		_:
			_hide_hud_modal()


func _on_hud_modal_meta_clicked(meta: Variant) -> void:
	var url := str(meta).strip_edges()
	if not (url.begins_with("https://") or url.begins_with("http://")):
		return
	var err := OS.shell_open(url)
	if err != OK:
		print_debug("[MainMenu] open link failed: %s err=%d" % [url, err])


func _on_feedback_button_pressed() -> void:
	_hide_corner_action_label(_feedback_button)
	_show_feedback_dialog()


func _show_feedback_dialog() -> void:
	var overlay := get_node_or_null(FEEDBACK_OVERLAY_NAME) as Control
	if overlay == null:
		overlay = _create_feedback_overlay()
		add_child(overlay)
	overlay.visible = true
	overlay.move_to_front()
	_resize_feedback_panel()
	_update_feedback_quota_label()
	_set_feedback_submit_busy(_feedback_submit_in_progress)
	if _feedback_text_edit != null:
		_feedback_text_edit.grab_focus()


func _hide_feedback_dialog() -> void:
	var overlay := get_node_or_null(FEEDBACK_OVERLAY_NAME) as Control
	if overlay != null:
		overlay.visible = false


func _create_feedback_overlay() -> Control:
	var overlay := Control.new()
	overlay.name = FEEDBACK_OVERLAY_NAME
	overlay.visible = false
	overlay.layout_mode = 1
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.name = "FeedbackShade"
	shade.layout_mode = 1
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.012, 0.024, 0.68)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)

	var center := CenterContainer.new()
	center.name = "FeedbackCenter"
	center.layout_mode = 1
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	_feedback_panel = PanelContainer.new()
	_feedback_panel.name = "FeedbackPanel"
	_feedback_panel.add_theme_stylebox_override("panel", _feedback_panel_style())
	center.add_child(_feedback_panel)

	var panel_root := VBoxContainer.new()
	panel_root.name = "FeedbackPanelRoot"
	panel_root.add_theme_constant_override("separation", 14)
	_feedback_panel.add_child(panel_root)

	var header := HBoxContainer.new()
	header.name = "FeedbackHeader"
	header.add_theme_constant_override("separation", 12)
	panel_root.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)

	var title := Label.new()
	title.text = "建议与 Bug 反馈"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.94, 0.99, 1.0, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.74, 1.0, 0.62))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "直接提交到服务器，也可以扫码小红书后续补充截图"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.64, 0.78, 0.88, 1.0))
	title_box.add_child(subtitle)

	_feedback_close_button = _create_feedback_action_button("关闭", HudThemeScript.ACCENT, Vector2(82, 40))
	_feedback_close_button.pressed.connect(_hide_feedback_dialog)
	header.add_child(_feedback_close_button)

	panel_root.add_child(_build_feedback_dialog_content())

	var footer := HBoxContainer.new()
	footer.name = "FeedbackFooter"
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 12)
	panel_root.add_child(footer)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)

	var secondary_close := _create_feedback_action_button("稍后再说", HudThemeScript.ACCENT, Vector2(112, 44))
	secondary_close.pressed.connect(_hide_feedback_dialog)
	footer.add_child(secondary_close)

	_feedback_submit_button = _create_feedback_action_button("提交反馈", HudThemeScript.ACCENT_WARM, Vector2(138, 44))
	_feedback_submit_button.pressed.connect(_on_feedback_dialog_confirmed)
	footer.add_child(_feedback_submit_button)

	return overlay


func _build_feedback_dialog_content() -> Control:
	var root := HBoxContainer.new()
	root.name = "FeedbackContent"
	root.custom_minimum_size = Vector2(740, 398)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 16)

	var contact_panel := PanelContainer.new()
	contact_panel.name = "FeedbackContactPanel"
	contact_panel.custom_minimum_size = Vector2(232, 398)
	contact_panel.add_theme_stylebox_override("panel", _feedback_side_panel_style(HudThemeScript.ACCENT))
	root.add_child(contact_panel)

	var contact_box := VBoxContainer.new()
	contact_box.add_theme_constant_override("separation", 8)
	contact_panel.add_child(contact_box)

	var qr_texture := _load_xhs_qr_texture()
	if qr_texture != null:
		var qr := TextureRect.new()
		qr.name = "XhsQrImage"
		qr.texture = qr_texture
		qr.custom_minimum_size = Vector2(202, 300)
		qr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		contact_box.add_child(qr)
	else:
		var qr_fallback := Label.new()
		qr_fallback.custom_minimum_size = Vector2(202, 300)
		qr_fallback.text = "二维码图片未找到\n请搜索小红书号"
		qr_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qr_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		contact_box.add_child(qr_fallback)

	var contact_name := Label.new()
	contact_name.text = XHS_DISPLAY_NAME
	contact_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contact_name.add_theme_font_size_override("font_size", 20)
	contact_name.add_theme_color_override("font_color", Color(1.0, 0.78, 0.50, 1.0))
	contact_box.add_child(contact_name)

	var contact_id := Label.new()
	contact_id.text = "小红书号：%s" % XHS_ID
	contact_id.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contact_id.add_theme_font_size_override("font_size", 13)
	contact_id.add_theme_color_override("font_color", Color(0.68, 0.80, 0.88, 1.0))
	contact_box.add_child(contact_id)

	var form := VBoxContainer.new()
	form.name = "FeedbackForm"
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 8)
	root.add_child(form)

	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "\n".join(PackedStringArray([
		"卡牌效果、AI 行为、安卓兼容、UI 操作或体验建议都可以直接写在这里。",
		"本地限制 24 小时内最多提交 3 条，只有服务器保存成功才会消耗次数。"
	]))
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_color", Color(0.70, 0.84, 0.93, 1.0))
	form.add_child(info)

	var name_label := Label.new()
	name_label.text = "你的称呼"
	form.add_child(name_label)

	_feedback_name_input = LineEdit.new()
	_feedback_name_input.name = "FeedbackName"
	_feedback_name_input.custom_minimum_size = Vector2(0, 42)
	_feedback_name_input.placeholder_text = "可填昵称；留空会按匿名玩家提交"
	_feedback_name_input.max_length = FeedbackClientScript.MAX_NAME_LENGTH
	form.add_child(_feedback_name_input)

	var content_label := Label.new()
	content_label.text = "反馈内容"
	form.add_child(content_label)

	_feedback_text_edit = TextEdit.new()
	_feedback_text_edit.name = "FeedbackText"
	_feedback_text_edit.custom_minimum_size = Vector2(0, 188)
	_feedback_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_feedback_text_edit.placeholder_text = "请写下建议或 bug：发生在哪个页面、做了什么操作、期望结果和实际结果。"
	form.add_child(_feedback_text_edit)

	_feedback_quota_label = Label.new()
	_feedback_quota_label.name = "FeedbackQuotaLabel"
	_feedback_quota_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.90, 1.0))
	form.add_child(_feedback_quota_label)

	HudThemeScript.apply(root)
	contact_panel.add_theme_stylebox_override("panel", _feedback_side_panel_style(HudThemeScript.ACCENT))
	_feedback_quota_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.90, 1.0))
	return root


func _create_feedback_action_button(text: String, accent: Color, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.03, 0.07, 0.10, 1.0))
	button.add_theme_stylebox_override("normal", _main_menu_button_style(accent, false, false, false))
	button.add_theme_stylebox_override("hover", _main_menu_button_style(accent, false, true, false))
	button.add_theme_stylebox_override("pressed", _main_menu_button_style(accent, false, true, true))
	button.add_theme_stylebox_override("disabled", _main_menu_button_style(Color(0.30, 0.34, 0.38, 1.0), false, false, false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _feedback_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.030, 0.050, 0.95)
	style.border_color = Color(0.24, 0.86, 1.0, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.0, 0.68, 1.0, 0.28)
	style.shadow_size = 18
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style


func _feedback_side_panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.055, 0.080, 0.84)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.54)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.10)
	style.shadow_size = 8
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _resize_feedback_panel() -> void:
	if _feedback_panel == null:
		return
	var viewport_size := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	_feedback_panel.custom_minimum_size = Vector2(
		minf(820.0, maxf(320.0, viewport_size.x - 56.0)),
		minf(560.0, maxf(420.0, viewport_size.y - 56.0))
	)


func _set_feedback_submit_busy(busy: bool) -> void:
	_feedback_submit_in_progress = busy
	if _feedback_submit_button == null:
		return
	_feedback_submit_button.text = "提交中..." if busy else "提交反馈"
	_feedback_submit_button.disabled = busy or _feedback_remaining_count() <= 0


func _load_xhs_qr_texture() -> Texture2D:
	if ResourceLoader.exists(XHS_QR_PATH):
		var texture := load(XHS_QR_PATH) as Texture2D
		if texture != null:
			return texture
	var image := Image.new()
	if image.load(XHS_QR_PATH) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _on_feedback_dialog_confirmed() -> void:
	if _feedback_text_edit == null:
		return
	if _feedback_submit_in_progress:
		_show_update_status_dialog("正在提交反馈", "上一条反馈还在提交中，请稍等。")
		return
	var player_name := _feedback_name_input.text.strip_edges() if _feedback_name_input != null else ""
	var feedback_text := _feedback_text_edit.text.strip_edges()
	var validation_message: String = FeedbackClientScript.validate_feedback(player_name, feedback_text)
	if validation_message != "":
		_show_update_status_dialog("反馈内容需要补充", validation_message)
		return
	if _feedback_remaining_count() <= 0:
		_show_update_status_dialog("反馈次数已用完", "24 小时内最多提交 %d 条建议或 bug。请稍后再试。" % FEEDBACK_LIMIT)
		return

	_ensure_feedback_client()
	if _feedback_client == null:
		_show_update_status_dialog("反馈提交失败", "无法创建反馈提交器。内容不会消耗本地提交次数。")
		return

	_pending_feedback_payload = FeedbackClientScript.build_payload(player_name, feedback_text, {
		"app_version": AppVersionScript.DISPLAY_VERSION,
		"platform": OS.get_name(),
	})
	_set_feedback_submit_busy(true)
	var err: int = int(_feedback_client.call("submit_feedback", player_name, feedback_text, {
		"app_version": AppVersionScript.DISPLAY_VERSION,
		"platform": OS.get_name(),
	}))
	if err == ERR_BUSY:
		_show_update_status_dialog("正在提交反馈", "上一条反馈还在提交中，请稍等。")
	elif err != OK:
		_set_feedback_submit_busy(false)


func _ensure_feedback_client() -> void:
	if _feedback_client != null:
		return
	_feedback_client = FeedbackClientScript.new()
	_feedback_client.submit_succeeded.connect(_on_feedback_submit_succeeded)
	_feedback_client.submit_failed.connect(_on_feedback_submit_failed)
	add_child(_feedback_client)


func _on_feedback_submit_succeeded(response: Dictionary) -> void:
	_set_feedback_submit_busy(false)
	var recorded := _record_feedback_submission()
	if _feedback_text_edit != null:
		_feedback_text_edit.text = ""
	if _feedback_name_input != null:
		_feedback_name_input.text = ""
	_update_feedback_quota_label()

	var feedback_id := str(response.get("feedback_id", response.get("_id", "")))
	var message := "反馈已保存到服务器。"
	if feedback_id != "":
		message += "\n反馈编号：%s" % feedback_id
	if not recorded:
		message += "\n本地次数记录已满，不过这次云端提交已经成功。"
	_hide_feedback_dialog()
	_show_update_status_dialog("反馈已提交", message)
	_pending_feedback_payload = {}


func _on_feedback_submit_failed(message: String) -> void:
	_set_feedback_submit_busy(false)
	_update_feedback_quota_label()
	if not _pending_feedback_payload.is_empty():
		DisplayServer.clipboard_set(_format_feedback_clipboard_payload(_pending_feedback_payload))
	_show_update_status_dialog(
		"反馈提交失败",
		"%s\n\n内容已复制到剪贴板，未消耗本地提交次数。你可以稍后重试，或扫码小红书联系我。" % message
	)


func _format_feedback_clipboard_payload(payload: Dictionary) -> String:
	return "\n".join(PackedStringArray([
		"PTCG Deck Agent 反馈",
		"称呼：%s" % str(payload.get("name", "匿名玩家")),
		"版本：%s" % str(payload.get("app_version", AppVersionScript.DISPLAY_VERSION)),
		"平台：%s" % str(payload.get("platform", OS.get_name())),
		"小红书：%s（%s）" % [XHS_DISPLAY_NAME, XHS_ID],
		"",
		str(payload.get("content", "")),
	]))


func _update_feedback_quota_label() -> void:
	if _feedback_quota_label == null:
		return
	var remaining := _feedback_remaining_count()
	_feedback_quota_label.text = "24 小时内还可以提交 %d / %d 条。" % [remaining, FEEDBACK_LIMIT]


func _feedback_remaining_count(now: int = -1) -> int:
	if now < 0:
		now = int(Time.get_unix_time_from_system())
	return _feedback_remaining_for_timestamps(_load_feedback_timestamps(), now)


func _feedback_remaining_for_timestamps(raw_timestamps: Array, now: int) -> int:
	var pruned := _feedback_timestamps_after_prune(raw_timestamps, now)
	return maxi(0, FEEDBACK_LIMIT - pruned.size())


func _record_feedback_submission(now: int = -1) -> bool:
	if now < 0:
		now = int(Time.get_unix_time_from_system())
	var timestamps := _feedback_timestamps_after_prune(_load_feedback_timestamps(), now)
	if timestamps.size() >= FEEDBACK_LIMIT:
		_save_feedback_timestamps(timestamps)
		return false
	timestamps.append(now)
	_save_feedback_timestamps(timestamps)
	return true


func _feedback_timestamps_after_prune(raw_timestamps: Array, now: int) -> Array[int]:
	var pruned: Array[int] = []
	for item: Variant in raw_timestamps:
		var timestamp := int(item)
		if timestamp <= 0:
			continue
		if now - timestamp < FEEDBACK_WINDOW_SECONDS:
			pruned.append(timestamp)
	pruned.sort()
	return pruned


func _load_feedback_timestamps() -> Array[int]:
	if not FileAccess.file_exists(FEEDBACK_STATE_PATH):
		return []
	var file := FileAccess.open(FEEDBACK_STATE_PATH, FileAccess.READ)
	if file == null:
		return []
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return []
	var raw: Variant = (json.data as Dictionary).get("submitted_at", [])
	if not (raw is Array):
		return []
	return _feedback_timestamps_after_prune(raw as Array, int(Time.get_unix_time_from_system()))


func _save_feedback_timestamps(timestamps: Array[int]) -> void:
	var raw: Array = []
	for timestamp: int in timestamps:
		raw.append(timestamp)
	var file := FileAccess.open(FEEDBACK_STATE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"submitted_at": raw}, "\t"))
	file.close()


func _show_update_dialog(info: Dictionary) -> void:
	_show_hud_modal(str(info.get("title", "发现新版本")), _format_update_dialog_text(info), [
		{
			"id": "ignore_update",
			"text": "不再提醒",
			"accent": HudThemeScript.ACCENT,
			"primary": false,
		},
		{
			"id": "close",
			"text": "稍后",
			"accent": HudThemeScript.ACCENT,
			"primary": false,
		},
		{
			"id": "download_update",
			"text": "前往下载页",
			"accent": HudThemeScript.ACCENT_WARM,
			"primary": true,
		},
	], Vector2(560, 390))


func _format_update_dialog_text(info: Dictionary) -> String:
	var display_version := str(info.get("display_version", "v%s" % str(info.get("latest_version", ""))))
	var lines := PackedStringArray([
		"当前版本：%s" % AppVersionScript.DISPLAY_VERSION,
		"最新版本：%s" % display_version,
	])
	var release_date := str(info.get("release_date", ""))
	if release_date != "":
		lines.append("发布日期：%s" % release_date)
	var summary: Variant = info.get("summary", [])
	if summary is Array or summary is PackedStringArray:
		lines.append("")
		lines.append("更新内容：")
		for item: Variant in summary:
			var line := str(item).strip_edges()
			if line != "":
				lines.append("- %s" % line)
	return "\n".join(lines)


func _on_update_dialog_confirmed() -> void:
	_open_update_download_page()


func _open_update_download_page() -> void:
	var url := str(_available_update.get("download_page_url", UpdateCheckerScript.DEFAULT_DOWNLOAD_PAGE_URL))
	if url == "":
		url = UpdateCheckerScript.DEFAULT_DOWNLOAD_PAGE_URL
	var err := OS.shell_open(url)
	if err != OK:
		print_debug("[UpdateChecker] open download page failed: %d" % err)


func _on_update_dialog_custom_action(action: StringName) -> void:
	if str(action) != "ignore_update":
		return
	_ignore_current_update_version()


func _ignore_current_update_version() -> void:
	if _update_checker != null:
		_update_checker.ignore_version(str(_available_update.get("latest_version", "")))
	if _update_button != null:
		_update_button.visible = false


func _on_start_battle() -> void:
	GameManager.goto_battle_setup()


func _on_tournament() -> void:
	if GameManager.has_resumable_tournament_overview():
		GameManager.goto_tournament_overview()
		return
	if GameManager.has_active_tournament():
		GameManager.goto_tournament_standings()
		return
	GameManager.goto_tournament_deck_select()


func _on_deck_manager() -> void:
	GameManager.goto_deck_manager()


func _on_battle_replay() -> void:
	GameManager.goto_replay_browser()


func _on_settings() -> void:
	GameManager.goto_settings()


func _on_quit() -> void:
	get_tree().quit()


func _open_champion_preview() -> void:
	var tournament = SwissTournamentScript.new()
	tournament.setup(CHAMPION_PREVIEW_PLAYER_NAME, CHAMPION_PREVIEW_DECK_ID, CHAMPION_PREVIEW_PLAYER_COUNT, 20260426)
	tournament.current_round = tournament.total_rounds
	tournament.finished = true
	tournament.last_round_summary = _build_champion_preview_summary(tournament)
	GameManager.current_tournament = tournament
	GameManager.tournament_selected_player_deck_id = CHAMPION_PREVIEW_DECK_ID
	GameManager.tournament_battle_in_progress = false
	GameManager.clear_battle_player_display_names()
	GameManager.goto_tournament_standings()


func _build_champion_preview_summary(tournament) -> Dictionary:
	var standings: Array[Dictionary] = [
		{
			"id": 0,
			"name": CHAMPION_PREVIEW_PLAYER_NAME,
			"wins": tournament.total_rounds,
			"losses": 0,
			"draws": 0,
			"points": tournament.total_rounds * 3,
			"rank": 1,
		},
		{
			"id": 1,
			"name": "决赛对手",
			"wins": max(0, tournament.total_rounds - 1),
			"losses": 1,
			"draws": 0,
			"points": max(0, tournament.total_rounds - 1) * 3,
			"rank": 2,
		},
		{
			"id": 2,
			"name": "稳定强敌",
			"wins": max(0, tournament.total_rounds - 1),
			"losses": 1,
			"draws": 0,
			"points": max(0, tournament.total_rounds - 1) * 3,
			"rank": 3,
		},
		{
			"id": 3,
			"name": "黑马选手",
			"wins": max(0, tournament.total_rounds - 2),
			"losses": 2,
			"draws": 0,
			"points": max(0, tournament.total_rounds - 2) * 3,
			"rank": 4,
		},
	]
	return {
		"round": tournament.total_rounds,
		"result": "win",
		"is_final_round": true,
		"reason": "隐藏冠军预览",
		"player": standings[0],
		"opponent": {
			"id": 1,
			"name": "决赛对手",
		},
		"standings": standings,
	}
