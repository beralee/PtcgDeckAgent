extends Control

const AppVersionScript := preload("res://scripts/app/AppVersion.gd")
const FeedbackClientScript := preload("res://scripts/network/FeedbackClient.gd")
const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const NonBattleLayoutControllerScript := preload("res://scripts/ui/non_battle/NonBattleLayoutController.gd")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
const SwissTournamentScript := preload("res://scripts/tournament/SwissTournament.gd")
const DeckCenterMetaClientScript := preload("res://scripts/network/DeckCenterMetaClient.gd")
const UpdateCheckerScript := preload("res://scripts/network/UpdateChecker.gd")
const UserVisitClientScript := preload("res://scripts/network/UserVisitClient.gd")
const MENU_VERTICAL_SHIFT := 88.0
const MAIN_MENU_BUTTON_WIDTH := 312.0
const MAIN_MENU_BUTTON_HEIGHT := 52.0
const PORTRAIT_MENU_BUTTON_DOWN_SHIFT := 1.0
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
const FEEDBACK_QR_DESKTOP_SIZE := Vector2(202.0, 300.0)
const FEEDBACK_QR_CARD_ASPECT := 647.0 / 472.0
const GAME_HOME_URL := "https://ptcg.skillserver.cn/"
const TCG_MIK_URL := "https://tcg.mik.moe/"
const CORNER_ACTION_BUTTON_SIZE := 58.0
const CORNER_ACTION_BUTTON_SPACING := 14.0
const CORNER_ACTION_BUTTON_RIGHT_MARGIN := 18.0
const CORNER_ACTION_BUTTON_BOTTOM_MARGIN := 18.0
const CORNER_ACTION_COUNT := 5
const PORTRAIT_CORNER_ACTION_BUTTON_SCALE := 1.30
const CORNER_ACTION_LABEL_GAP := 8.0
const CORNER_ACTION_LABEL_MIN_WIDTH := 76.0
const FEEDBACK_ICON_PATH := "res://assets/ui/main_action_feedback.png"
const ABOUT_ICON_PATH := "res://assets/ui/main_action_about.png"
const UPDATE_ICON_PATH := "res://assets/ui/main_action_update.png"
const PORTRAIT_BACKGROUND_PATH := "res://assets/ui/title_portrait.png"
const BUDEW_MASCOT_SHEET_PATH := "res://assets/ui/budew_mascot/sheet-transparent.png"
const BUDEW_MASCOT_FRAME_SIZE := Vector2i(128, 128)
const BUDEW_MASCOT_FRAME_COUNT := 4
const BUDEW_MASCOT_FRAME_SECONDS := 0.14
const BUDEW_MASCOT_WALK_SPEED := 128.0
const BUDEW_MASCOT_LEFT_MARGIN := 34.0
const BUDEW_MASCOT_BOTTOM_MARGIN := 38.0
const BUDEW_MASCOT_PAUSE_SECONDS := 0.34
const BUDEW_MASCOT_BOB_AMPLITUDE := 5.0
const BUDEW_MASCOT_SOURCE_FACES_LEFT := true
const BUDEW_MASCOT_DODGE_DISTANCE := 156.0
const BUDEW_MASCOT_DODGE_HEIGHT := 48.0
const BUDEW_MASCOT_DODGE_SECONDS := 0.34
const BUDEW_MASCOT_DODGE_PAUSE_SECONDS := 0.20
const FEEDBACK_OVERLAY_NAME := "FeedbackOverlay"
const HUD_MODAL_OVERLAY_NAME := "HudModalOverlay"
const TEMP_FORCE_UPDATE_PREVIEW_ON_STARTUP := false
const TEMP_UPDATE_PREVIEW_ARG := "--preview-update-available"
const TEMP_UPDATE_PREVIEW_KEY := KEY_U

var _update_checker: Node = null
var _deck_center_meta_client: Node = null
var _feedback_client: Node = null
var _user_visit_client: Node = null
var _update_button: Button = null
var _update_button_flash_tween: Tween = null
var _deck_center_button_flash_tween: Tween = null
var _deck_center_new_badge: PanelContainer = null
var _feedback_button: Button = null
var _manual_update_button: Button = null
var _about_button: Button = null
var _non_battle_orientation_button: Button = null
var _share_button: Button = null
var _available_update: Dictionary = {}
var _manual_update_requested := false
var _pending_deck_center_meta: Dictionary = {}
var _temp_update_preview_active := false
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
var _budew_mascot_root: Control = null
var _budew_mascot_sprite: TextureRect = null
var _budew_mascot_shadow: PanelContainer = null
var _budew_mascot_frames: Array[Texture2D] = []
var _budew_mascot_frame_index := 0
var _budew_mascot_frame_elapsed := 0.0
var _budew_mascot_position := Vector2.ZERO
var _budew_mascot_route: Array[Vector2] = []
var _budew_mascot_route_index := 0
var _budew_mascot_pause_timer := 0.0
var _budew_mascot_bob_time := 0.0
var _budew_mascot_last_move_x := 1.0
var _budew_mascot_dodge_tween: Tween = null
var _budew_mascot_jump_offset := 0.0
var _main_menu_touch_button_candidate: Button = null
var _non_battle_layout_controller: RefCounted = NonBattleLayoutControllerScript.new()
var _main_menu_landscape_background_texture: Texture2D = null
var _main_menu_portrait_background_texture: Texture2D = null
var _portrait_home_title: Label = null
var _portrait_home_subtitle: Label = null


func _ready() -> void:
	_request_navigation_resource_prewarm()
	_apply_main_menu_hud()
	_ensure_budew_mascot()
	_setup_version_and_updates()
	_connect_non_battle_layout_signal()
	call_deferred("_apply_non_battle_layout")
	%BtnSettings.text = "AI 设置"
	%BtnStartBattle.pressed.connect(_on_start_battle)
	%BtnTournament.pressed.connect(_on_tournament)
	%BtnDeckManager.pressed.connect(_on_deck_manager)
	%BtnBattleReplay.pressed.connect(_on_battle_replay)
	%BtnSettings.pressed.connect(_on_settings)
	%BtnQuit.pressed.connect(_on_quit)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton:
		if bool(NonBattleTouchBridgeScript.handle_root_touch(self, event)):
			return
	if event is InputEventScreenTouch:
		_handle_main_menu_touch_gui_input(event)
		return
	if event is InputEventMouseButton:
		_handle_budew_mascot_unhandled_input(event)
		return


func _request_navigation_resource_prewarm() -> void:
	if not is_inside_tree():
		return
	if GameManager != null and GameManager.has_method("prewarm_navigation_resources"):
		GameManager.prewarm_navigation_resources()


func _gui_input(event: InputEvent) -> void:
	_handle_main_menu_touch_gui_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.ctrl_pressed and key_event.shift_pressed and key_event.keycode == KEY_C:
		get_viewport().set_input_as_handled()
		_open_champion_preview()
	if key_event.ctrl_pressed and key_event.shift_pressed and key_event.keycode == TEMP_UPDATE_PREVIEW_KEY:
		get_viewport().set_input_as_handled()
		_show_temp_update_available_preview()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_non_battle_layout()
		_resize_feedback_panel()
		_resize_hud_modal_panel()
		_position_deck_center_new_badge()
		_layout_budew_mascot()
		if _corner_action_hover_button != null:
			_position_corner_action_label(_corner_action_hover_button)
	elif what == NOTIFICATION_PREDELETE:
		_stop_update_button_flash(false)
		_stop_deck_center_button_flash(false)
		_stop_budew_mascot_dodge()


func _process(delta: float) -> void:
	_update_budew_mascot(delta)


func _apply_main_menu_hud() -> void:
	var background := get_node_or_null("Background") as Control
	if background != null:
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if background is TextureRect and _main_menu_landscape_background_texture == null:
			_main_menu_landscape_background_texture = (background as TextureRect).texture
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
		button.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(18))
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
		_enable_button_touch_activation(button)
		if is_featured:
			button.tooltip_text = "查看推荐卡组、管理本地卡组、导入新卡组"


	_ensure_deck_center_new_badge()
	_apply_non_battle_layout()


func _connect_non_battle_layout_signal() -> void:
	if GameManager == null or not GameManager.has_signal("non_battle_layout_mode_changed"):
		return
	var callback := Callable(self, "_on_non_battle_layout_mode_changed")
	if not GameManager.non_battle_layout_mode_changed.is_connected(callback):
		GameManager.non_battle_layout_mode_changed.connect(callback)


func _on_non_battle_layout_mode_changed(_mode: String) -> void:
	_apply_non_battle_layout()
	call_deferred("_apply_non_battle_layout")


func _apply_non_battle_layout_for_tests(viewport_size: Vector2, mode: String) -> void:
	_apply_non_battle_layout(viewport_size, mode)


func _apply_non_battle_layout(viewport_size: Vector2 = Vector2.ZERO, forced_mode: String = "") -> void:
	var size := viewport_size
	if size.x <= 0.0 or size.y <= 0.0:
		size = get_viewport_rect().size if is_inside_tree() else Vector2(1600, 900)
	var mode := forced_mode
	if mode == "":
		mode = _current_non_battle_orientation_mode()
	var is_mobile := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	var context: Dictionary = _non_battle_layout_controller.call("build_context", size, mode, is_mobile)
	var portrait := bool(context.get("is_portrait", false))
	set_meta("non_battle_layout_mode", str(context.get("resolved_mode", mode)))
	set_meta("non_battle_layout_viewport_size", context.get("viewport_size", size))
	_apply_main_menu_background(context, portrait)
	_ensure_corner_action_buttons()
	_layout_corner_action_buttons(context, portrait)
	_apply_main_menu_frame_metrics(context, portrait)
	_position_deck_center_new_badge()
	_ensure_budew_mascot()
	_layout_budew_mascot()


func _apply_main_menu_frame_metrics(context: Dictionary, portrait: bool) -> void:
	var menu := get_node_or_null("VBoxContainer") as VBoxContainer
	if menu == null:
		return
	var content_width := float(context.get("content_width", MAIN_MENU_BUTTON_WIDTH))
	var button_height := float(context.get("primary_button_height", MAIN_MENU_BUTTON_HEIGHT))
	var button_font := int(context.get("button_font_size", 18))
	var button_width := content_width if portrait else MAIN_MENU_BUTTON_WIDTH
	var separation := int(context.get("section_gap", 12))
	menu.add_theme_constant_override("separation", separation)
	if portrait:
		var viewport_size: Vector2 = context.get("viewport_size", Vector2(1080, 2400))
		var button_count := 6.0
		var group_height := button_height * button_count + float(separation) * (button_count - 1.0)
		var menu_center_y := viewport_size.y * 0.595 + button_height * PORTRAIT_MENU_BUTTON_DOWN_SHIFT
		var viewport_center_y := viewport_size.y * 0.5
		menu.offset_left = -button_width * 0.5
		menu.offset_right = button_width * 0.5
		menu.offset_top = menu_center_y - group_height * 0.5 - viewport_center_y
		menu.offset_bottom = menu.offset_top + group_height
	else:
		menu.offset_left = -170.0
		menu.offset_right = 170.0
		menu.offset_top = -175.0 + MENU_VERTICAL_SHIFT
		menu.offset_bottom = 175.0 + MENU_VERTICAL_SHIFT
	for button_name: String in ["BtnStartBattle", "BtnTournament", "BtnDeckManager", "BtnBattleReplay", "BtnSettings", "BtnQuit"]:
		var button := get_node_or_null("%" + button_name) as Button
		if button == null:
			continue
		button.custom_minimum_size = Vector2(button_width, button_height)
		button.add_theme_font_size_override("font_size", button_font if portrait else HudThemeScript.scaled_font_size(button_font))
		NonBattleTouchBridgeScript.bind_button_touch(button)
	var version_label := get_node_or_null("VersionLabel") as Label
	if version_label != null:
		version_label.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(14 if portrait else 12))


func _apply_main_menu_background(context: Dictionary, portrait: bool) -> void:
	var background := get_node_or_null("Background") as TextureRect
	if background == null:
		return
	if _main_menu_landscape_background_texture == null:
		_main_menu_landscape_background_texture = background.texture
	if _main_menu_portrait_background_texture == null:
		_main_menu_portrait_background_texture = load(PORTRAIT_BACKGROUND_PATH) as Texture2D
	if portrait:
		if _main_menu_portrait_background_texture != null:
			background.texture = _main_menu_portrait_background_texture
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_hide_portrait_home_title()
		return
	background.texture = _main_menu_landscape_background_texture
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hide_portrait_home_title()


func _layout_portrait_home_title(context: Dictionary) -> void:
	_ensure_portrait_home_title()
	if _portrait_home_title == null or _portrait_home_subtitle == null:
		return
	var viewport_size: Vector2 = context.get("viewport_size", Vector2(1080, 2400))
	var content_width := minf(float(context.get("content_width", viewport_size.x - 64.0)), viewport_size.x - 72.0)
	var title_font := maxi(int(context.get("title_font_size", 40)) + 8, 46)
	var subtitle_font := maxi(int(context.get("section_font_size", 29)), 28)
	var top := maxf(viewport_size.y * 0.075, 54.0)
	var left := (viewport_size.x - content_width) * 0.5
	_portrait_home_title.visible = true
	_portrait_home_title.position = Vector2(left, top)
	_portrait_home_title.size = Vector2(content_width, title_font * 1.35)
	_portrait_home_title.add_theme_font_size_override("font_size", title_font)
	_portrait_home_subtitle.visible = true
	_portrait_home_subtitle.position = Vector2(left, top + title_font * 1.22)
	_portrait_home_subtitle.size = Vector2(content_width, subtitle_font * 1.55)
	_portrait_home_subtitle.add_theme_font_size_override("font_size", subtitle_font)


func _ensure_portrait_home_title() -> void:
	if _portrait_home_title != null and _portrait_home_subtitle != null:
		return
	if _portrait_home_title == null:
		_portrait_home_title = Label.new()
		_portrait_home_title.name = "PortraitHomeTitle"
		_portrait_home_title.text = "PTCG Deck"
		_portrait_home_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_portrait_home_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_portrait_home_title.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
		_portrait_home_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.8, 1.0, 0.72))
		_portrait_home_title.add_theme_constant_override("shadow_offset_y", 4)
		_portrait_home_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portrait_home_title.visible = false
		add_child(_portrait_home_title)
	if _portrait_home_subtitle == null:
		_portrait_home_subtitle = Label.new()
		_portrait_home_subtitle.name = "PortraitHomeSubtitle"
		_portrait_home_subtitle.text = "宝可梦卡牌智能练牌"
		_portrait_home_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_portrait_home_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_portrait_home_subtitle.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0, 0.96))
		_portrait_home_subtitle.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
		_portrait_home_subtitle.add_theme_constant_override("shadow_offset_y", 2)
		_portrait_home_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portrait_home_subtitle.visible = false
		add_child(_portrait_home_subtitle)


func _hide_portrait_home_title() -> void:
	if _portrait_home_title != null:
		_portrait_home_title.visible = false
	if _portrait_home_subtitle != null:
		_portrait_home_subtitle.visible = false


func _ensure_budew_mascot() -> void:
	if _budew_mascot_root != null:
		return
	_budew_mascot_frames = _load_budew_mascot_frames()
	if _budew_mascot_frames.is_empty():
		return

	_budew_mascot_root = Control.new()
	_budew_mascot_root.name = "BudewMascotLayer"
	_budew_mascot_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_budew_mascot_root.layout_mode = 1
	_budew_mascot_root.anchors_preset = PRESET_FULL_RECT
	_budew_mascot_root.anchor_right = 1.0
	_budew_mascot_root.anchor_bottom = 1.0
	_budew_mascot_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_budew_mascot_root.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_budew_mascot_root)
	move_child(_budew_mascot_root, 1)

	_budew_mascot_shadow = PanelContainer.new()
	_budew_mascot_shadow.name = "BudewMascotShadow"
	_budew_mascot_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_budew_mascot_shadow.add_theme_stylebox_override("panel", _budew_mascot_shadow_style())
	_budew_mascot_root.add_child(_budew_mascot_shadow)

	_budew_mascot_sprite = TextureRect.new()
	_budew_mascot_sprite.name = "BudewMascotSprite"
	_budew_mascot_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_budew_mascot_sprite.texture = _budew_mascot_frames[0]
	_budew_mascot_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_budew_mascot_root.add_child(_budew_mascot_sprite)

	set_process(true)
	_layout_budew_mascot()


func _load_budew_mascot_frames() -> Array[Texture2D]:
	var sheet := load(BUDEW_MASCOT_SHEET_PATH) as Texture2D
	if sheet == null:
		return []
	var frames: Array[Texture2D] = []
	for frame_index: int in BUDEW_MASCOT_FRAME_COUNT:
		var col := frame_index % 2
		var row := int(frame_index / 2)
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(
			Vector2(float(col * BUDEW_MASCOT_FRAME_SIZE.x), float(row * BUDEW_MASCOT_FRAME_SIZE.y)),
			Vector2(float(BUDEW_MASCOT_FRAME_SIZE.x), float(BUDEW_MASCOT_FRAME_SIZE.y))
		)
		frames.append(atlas)
	return frames


func _update_budew_mascot(delta: float) -> void:
	if _budew_mascot_sprite == null or _budew_mascot_frames.is_empty():
		return
	if _budew_mascot_route.size() < 2:
		_layout_budew_mascot()
	if _budew_mascot_route.size() < 2:
		return

	if _is_budew_mascot_dodging():
		_advance_budew_mascot_frame(delta)
		return

	if _budew_mascot_pause_timer > 0.0:
		_budew_mascot_pause_timer = maxf(0.0, _budew_mascot_pause_timer - delta)
		_position_budew_mascot()
		return

	_advance_budew_mascot_frame(delta)

	var target := _budew_mascot_route[_budew_mascot_route_index]
	var to_target := target - _budew_mascot_position
	var step_distance := BUDEW_MASCOT_WALK_SPEED * delta
	if to_target.length() <= step_distance:
		_budew_mascot_position = target
		_budew_mascot_route_index = (_budew_mascot_route_index + 1) % _budew_mascot_route.size()
		_budew_mascot_pause_timer = BUDEW_MASCOT_PAUSE_SECONDS
	else:
		var step := to_target.normalized() * step_distance
		_budew_mascot_position += step
		if absf(step.x) > 0.2:
			_budew_mascot_last_move_x = 1.0 if step.x > 0.0 else -1.0
	_budew_mascot_sprite.flip_h = (_budew_mascot_last_move_x > 0.0) == BUDEW_MASCOT_SOURCE_FACES_LEFT
	_position_budew_mascot()


func _advance_budew_mascot_frame(delta: float) -> void:
	if _budew_mascot_sprite == null or _budew_mascot_frames.is_empty():
		return
	_budew_mascot_frame_elapsed += delta
	while _budew_mascot_frame_elapsed >= BUDEW_MASCOT_FRAME_SECONDS:
		_budew_mascot_frame_elapsed -= BUDEW_MASCOT_FRAME_SECONDS
		_budew_mascot_frame_index = (_budew_mascot_frame_index + 1) % _budew_mascot_frames.size()
		_budew_mascot_sprite.texture = _budew_mascot_frames[_budew_mascot_frame_index]


func _handle_budew_mascot_unhandled_input(event: InputEvent) -> void:
	var pointer_position := Vector2(-1.0, -1.0)
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		pointer_position = mouse.global_position if mouse.global_position != Vector2.ZERO else mouse.position
	else:
		return
	if not _budew_mascot_hit_test(pointer_position):
		return
	if _main_menu_button_hit_test(pointer_position):
		return
	_make_budew_mascot_dodge_click(pointer_position)
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _handle_main_menu_touch_gui_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch):
		return
	if bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)):
		return
	var touch := event as InputEventScreenTouch
	var button := _main_menu_button_at_position(touch.position)
	if touch.pressed:
		_main_menu_touch_button_candidate = button
		if button != null:
			_accept_main_menu_touch()
			return
		if _budew_mascot_hit_test(touch.position):
			_make_budew_mascot_dodge_click(touch.position)
			_accept_main_menu_touch()
		return
	var candidate := _main_menu_touch_button_candidate
	_main_menu_touch_button_candidate = null
	if candidate != null and candidate == button:
		candidate.pressed.emit()
		_accept_main_menu_touch()


func _accept_main_menu_touch() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _enable_button_touch_activation(button: Button) -> void:
	if button == null:
		return
	var callback := Callable(self, "_on_touch_button_gui_input").bind(button)
	if not button.gui_input.is_connected(callback):
		button.gui_input.connect(callback)


func _on_touch_button_gui_input(event: InputEvent, button: Button) -> void:
	NonBattleTouchBridgeScript.handle_button_touch(button, event)


func _main_menu_button_hit_test(global_position: Vector2) -> bool:
	return _main_menu_button_at_position(global_position) != null


func _main_menu_button_at_position(global_position: Vector2) -> Button:
	return _button_at_position_recursive(self, global_position)


func _button_at_position_recursive(node: Node, global_position: Vector2) -> Button:
	for i: int in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		var child_button := _button_at_position_recursive(child, global_position)
		if child_button != null:
			return child_button
	if not (node is Button):
		return null
	var button := node as Button
	if button.disabled or not button.visible:
		return null
	if button.is_inside_tree() and not button.is_visible_in_tree():
		return null
	return button if button.get_global_rect().has_point(global_position) else null


func _budew_mascot_hit_test(global_position: Vector2) -> bool:
	if _budew_mascot_sprite == null or not _budew_mascot_sprite.visible:
		return false
	return _budew_mascot_sprite.get_global_rect().has_point(global_position)


func _make_budew_mascot_dodge_click(click_global_position: Vector2) -> void:
	if _budew_mascot_sprite == null:
		return
	_stop_budew_mascot_dodge()
	var start := _budew_mascot_position
	var target := _budew_mascot_dodge_target_for_click(click_global_position)
	if absf(target.x - start.x) > 0.2:
		_budew_mascot_last_move_x = 1.0 if target.x > start.x else -1.0
	_budew_mascot_sprite.flip_h = (_budew_mascot_last_move_x > 0.0) == BUDEW_MASCOT_SOURCE_FACES_LEFT
	_budew_mascot_pause_timer = 0.0
	_budew_mascot_dodge_tween = create_tween()
	_budew_mascot_dodge_tween.tween_method(
		Callable(self, "_apply_budew_mascot_dodge").bind(start, target),
		0.0,
		1.0,
		BUDEW_MASCOT_DODGE_SECONDS
	)
	_budew_mascot_dodge_tween.finished.connect(_on_budew_mascot_dodge_finished)


func _budew_mascot_dodge_target_for_click(click_global_position: Vector2) -> Vector2:
	var viewport_size := _main_menu_viewport_size()
	var sprite_size := _budew_mascot_display_size()
	var click_position := click_global_position
	if _budew_mascot_root != null:
		click_position -= _budew_mascot_root.global_position
	var current_center := _budew_mascot_position + sprite_size * 0.5
	var away := current_center - click_position
	if away.length() < 4.0:
		away = Vector2(-1.0 if current_center.x >= viewport_size.x * 0.5 else 1.0, -0.24)
	else:
		away = away.normalized()
		if absf(away.x) < 0.36:
			away.x = -1.0 if click_position.x >= current_center.x else 1.0
			away.y = minf(away.y, -0.18)
			away = away.normalized()
	var target := _budew_mascot_position + Vector2(
		away.x * BUDEW_MASCOT_DODGE_DISTANCE,
		clampf(away.y * BUDEW_MASCOT_DODGE_DISTANCE * 0.28, -32.0, 18.0)
	)
	return Vector2(
		clampf(target.x, 12.0, maxf(12.0, viewport_size.x - sprite_size.x - 12.0)),
		clampf(target.y, 72.0, maxf(72.0, viewport_size.y - sprite_size.y - 16.0))
	)


func _apply_budew_mascot_dodge(progress: float, start: Vector2, target: Vector2) -> void:
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	_budew_mascot_position = start.lerp(target, eased)
	_budew_mascot_jump_offset = sin(progress * PI) * BUDEW_MASCOT_DODGE_HEIGHT
	_position_budew_mascot()


func _on_budew_mascot_dodge_finished() -> void:
	_budew_mascot_jump_offset = 0.0
	_budew_mascot_dodge_tween = null
	if not _budew_mascot_route.is_empty():
		var nearest := _nearest_budew_route_point(_budew_mascot_position)
		var nearest_index := _budew_mascot_route.find(nearest)
		if nearest_index >= 0:
			_budew_mascot_route_index = (nearest_index + 1) % _budew_mascot_route.size()
	_budew_mascot_pause_timer = BUDEW_MASCOT_DODGE_PAUSE_SECONDS
	_position_budew_mascot()


func _is_budew_mascot_dodging() -> bool:
	return _budew_mascot_dodge_tween != null and is_instance_valid(_budew_mascot_dodge_tween) and _budew_mascot_dodge_tween.is_running()


func _stop_budew_mascot_dodge() -> void:
	if _budew_mascot_dodge_tween != null and is_instance_valid(_budew_mascot_dodge_tween):
		_budew_mascot_dodge_tween.kill()
	_budew_mascot_dodge_tween = null
	_budew_mascot_jump_offset = 0.0


func _layout_budew_mascot() -> void:
	if _budew_mascot_root == null or _budew_mascot_sprite == null:
		return
	_budew_mascot_root.offset_left = 0.0
	_budew_mascot_root.offset_top = 0.0
	_budew_mascot_root.offset_right = 0.0
	_budew_mascot_root.offset_bottom = 0.0

	var sprite_size := _budew_mascot_display_size()
	_budew_mascot_sprite.custom_minimum_size = sprite_size
	_budew_mascot_sprite.size = sprite_size
	var had_route := not _budew_mascot_route.is_empty()
	_budew_mascot_route = _build_budew_mascot_route()
	if _budew_mascot_route.is_empty():
		return
	if not had_route or _budew_mascot_position == Vector2.ZERO:
		_budew_mascot_position = _budew_mascot_route[0]
		_budew_mascot_route_index = 1 % _budew_mascot_route.size()
	else:
		_budew_mascot_position = _nearest_budew_route_point(_budew_mascot_position)
		_budew_mascot_route_index = (_budew_mascot_route.find(_budew_mascot_position) + 1) % _budew_mascot_route.size()

	_position_budew_mascot()


func _position_budew_mascot() -> void:
	if _budew_mascot_sprite == null:
		return
	var moving := _budew_mascot_pause_timer <= 0.0
	if moving:
		_budew_mascot_bob_time += get_process_delta_time()
	var bob := sin(_budew_mascot_bob_time * TAU * 2.0) * BUDEW_MASCOT_BOB_AMPLITUDE if moving else 0.0
	_budew_mascot_sprite.position = _budew_mascot_position + Vector2(0.0, bob - _budew_mascot_jump_offset)
	if _budew_mascot_shadow != null:
		var sprite_size := _budew_mascot_display_size()
		var jump_ratio := clampf(_budew_mascot_jump_offset / BUDEW_MASCOT_DODGE_HEIGHT, 0.0, 1.0)
		var shadow_size := Vector2(sprite_size.x * (0.56 - jump_ratio * 0.12), 10.0)
		_budew_mascot_shadow.size = shadow_size
		_budew_mascot_shadow.position = Vector2(
			_budew_mascot_position.x + (sprite_size.x - shadow_size.x) * 0.5,
			_budew_mascot_position.y + sprite_size.y - 14.0
		)
		_budew_mascot_shadow.modulate = Color(1.0, 1.0, 1.0, 0.84 - (absf(bob) / BUDEW_MASCOT_BOB_AMPLITUDE) * 0.18 - jump_ratio * 0.24)


func _budew_mascot_shadow_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.12, 0.04, 0.42)
	style.set_corner_radius_all(99)
	return style


func _budew_mascot_display_size() -> Vector2:
	var viewport_size := _main_menu_viewport_size()
	var side := 116.0
	if viewport_size.y > viewport_size.x:
		side = clampf(viewport_size.x * 0.17, 124.0, 188.0)
		return Vector2(side, side)
	if viewport_size.x < 820.0:
		side = 96.0
	if viewport_size.y < 620.0:
		side = minf(side, 84.0)
	return Vector2(side, side)


func _build_budew_mascot_route() -> Array[Vector2]:
	var viewport_size := _main_menu_viewport_size()
	var sprite_size := _budew_mascot_display_size()
	var left := BUDEW_MASCOT_LEFT_MARGIN
	var right := minf(viewport_size.x - sprite_size.x - 148.0, viewport_size.x * 0.72)
	if viewport_size.x < 900.0:
		right = viewport_size.x - sprite_size.x - BUDEW_MASCOT_LEFT_MARGIN
	right = maxf(left + sprite_size.x + 84.0, right)
	var center := clampf(viewport_size.x * 0.44, left + 92.0, right - 92.0)
	var sneak := clampf(viewport_size.x * 0.25, left + 64.0, right - 64.0)
	var base_y := maxf(96.0, viewport_size.y - sprite_size.y - BUDEW_MASCOT_BOTTOM_MARGIN)
	var high_y := maxf(112.0, base_y - minf(92.0, viewport_size.y * 0.12))
	var low_y := minf(viewport_size.y - sprite_size.y - 18.0, base_y + 12.0)
	return [
		Vector2(left, base_y),
		Vector2(sneak, high_y),
		Vector2(center, low_y),
		Vector2(right, base_y - 24.0),
		Vector2(center + minf(120.0, maxf(60.0, right - center) * 0.5), base_y + 4.0),
		Vector2(left + 76.0, low_y),
	]


func _nearest_budew_route_point(point: Vector2) -> Vector2:
	if _budew_mascot_route.is_empty():
		return point
	var nearest := _budew_mascot_route[0]
	var nearest_distance := point.distance_squared_to(nearest)
	for route_point: Vector2 in _budew_mascot_route:
		var distance := point.distance_squared_to(route_point)
		if distance < nearest_distance:
			nearest = route_point
			nearest_distance = distance
	return nearest


func _main_menu_viewport_size() -> Vector2:
	if has_meta("non_battle_layout_viewport_size"):
		var stored: Variant = get_meta("non_battle_layout_viewport_size")
		if stored is Vector2 and (stored as Vector2).x > 0.0 and (stored as Vector2).y > 0.0:
			return stored as Vector2
	if is_inside_tree():
		return get_viewport_rect().size
	if size.x > 0.0 and size.y > 0.0:
		return size
	return Vector2(1280, 720)


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
	style.set_corner_radius_all(999)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.26 if hover else 0.16)
	style.shadow_size = 12 if hover else 7
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _ensure_corner_action_buttons() -> void:
	if _non_battle_orientation_button == null:
		_non_battle_orientation_button = _create_corner_icon_button("NonBattleOrientationButton", "", _non_battle_orientation_hover_label(), _corner_action_left_offset(5), HudThemeScript.ACCENT)
		_non_battle_orientation_button.pressed.connect(_on_non_battle_orientation_button_pressed)
		add_child(_non_battle_orientation_button)
	if _feedback_button == null:
		_feedback_button = _create_corner_icon_button("FeedbackButton", FEEDBACK_ICON_PATH, "建议反馈", _corner_action_left_offset(4), HudThemeScript.ACCENT_WARM)
		_feedback_button.pressed.connect(_on_feedback_button_pressed)
		add_child(_feedback_button)
	if _about_button == null:
		_about_button = _create_corner_icon_button("AboutButton", ABOUT_ICON_PATH, "关于", _corner_action_left_offset(3), HudThemeScript.ACCENT)
		_about_button.pressed.connect(_on_about_button_pressed)
		add_child(_about_button)
	if _manual_update_button == null:
		_manual_update_button = _create_corner_icon_button("ManualUpdateButton", UPDATE_ICON_PATH, "检查更新", _corner_action_left_offset(2), HudThemeScript.ACCENT_WARM)
		_manual_update_button.pressed.connect(_on_manual_update_button_pressed)
		add_child(_manual_update_button)
	if _share_button == null:
		_share_button = _create_corner_icon_button("ShareButton", "", "分享给牌友", _corner_action_left_offset(1), MAIN_MENU_FEATURED_ACCENT)
		_share_button.text = "分享"
		_share_button.pressed.connect(_on_share_button_pressed)
		add_child(_share_button)
	_update_non_battle_orientation_button_state()


func _corner_action_button_size_for_context(context: Dictionary = {}, portrait: bool = false) -> float:
	if portrait:
		var viewport_size: Vector2 = context.get("viewport_size", get_viewport_rect().size if is_inside_tree() else Vector2(390, 844))
		var target_size := clampf(viewport_size.x * 0.105, 74.0, 118.0) * PORTRAIT_CORNER_ACTION_BUTTON_SCALE
		var fit_size := _portrait_corner_action_fit_size(viewport_size.x)
		return clampf(minf(target_size, fit_size), 58.0, 118.0 * PORTRAIT_CORNER_ACTION_BUTTON_SCALE)
	return CORNER_ACTION_BUTTON_SIZE


func _portrait_corner_action_fit_size(viewport_width: float) -> float:
	var low := CORNER_ACTION_BUTTON_SIZE
	var high := maxf(CORNER_ACTION_BUTTON_SIZE, viewport_width / float(CORNER_ACTION_COUNT))
	for _i: int in 18:
		var mid := (low + high) * 0.5
		var total_width := (
			mid * float(CORNER_ACTION_COUNT)
			+ _corner_action_spacing_for_size(mid, true) * float(CORNER_ACTION_COUNT - 1)
			+ _corner_action_right_margin_for_size(mid, true) * 2.0
		)
		if total_width <= viewport_width:
			low = mid
		else:
			high = mid
	return low


func _corner_action_spacing_for_size(button_size: float, portrait: bool = false) -> float:
	return clampf(button_size * (0.14 if portrait else 0.24), 10.0 if portrait else 12.0, 18.0)


func _corner_action_bottom_margin_for_size(button_size: float, portrait: bool = false) -> float:
	return clampf(button_size * (0.24 if portrait else 0.31), 18.0, 32.0)


func _corner_action_right_margin_for_size(button_size: float, portrait: bool = false) -> float:
	return clampf(button_size * (0.20 if portrait else 0.31), 18.0, 30.0)


func _corner_action_left_offset(
	index_from_right: int,
	button_size: float = CORNER_ACTION_BUTTON_SIZE,
	spacing: float = CORNER_ACTION_BUTTON_SPACING,
	right_margin: float = CORNER_ACTION_BUTTON_RIGHT_MARGIN
) -> float:
	return -right_margin - (button_size * float(index_from_right)) - (spacing * float(max(index_from_right - 1, 0)))


func _layout_corner_action_buttons(context: Dictionary, portrait: bool) -> void:
	var button_size := _corner_action_button_size_for_context(context, portrait)
	var spacing := _corner_action_spacing_for_size(button_size, portrait)
	var bottom_margin := _corner_action_bottom_margin_for_size(button_size, portrait)
	var right_margin := _corner_action_right_margin_for_size(button_size, portrait)
	var entries: Array[Dictionary] = [
		{"button": _non_battle_orientation_button, "index": 5, "accent": HudThemeScript.ACCENT},
		{"button": _feedback_button, "index": 4, "accent": HudThemeScript.ACCENT_WARM},
		{"button": _about_button, "index": 3, "accent": HudThemeScript.ACCENT},
		{"button": _manual_update_button, "index": 2, "accent": HudThemeScript.ACCENT_WARM},
		{"button": _share_button, "index": 1, "accent": MAIN_MENU_FEATURED_ACCENT},
	]
	for entry: Dictionary in entries:
		var button := entry.get("button", null) as Button
		if button == null:
			continue
		var accent: Color = entry.get("accent", HudThemeScript.ACCENT) as Color
		var left_offset := _corner_action_left_offset(int(entry.get("index", 1)), button_size, spacing, right_margin)
		button.custom_minimum_size = Vector2(button_size, button_size)
		button.size = Vector2(button_size, button_size)
		button.offset_left = left_offset
		button.offset_top = -bottom_margin - button_size
		button.offset_right = left_offset + button_size
		button.offset_bottom = -bottom_margin
		button.add_theme_constant_override("icon_max_width", int(button_size * 0.78))
		if button == _share_button:
			button.add_theme_font_size_override("font_size", roundi(button_size * (0.29 if portrait else 0.25)))
		button.add_theme_stylebox_override("normal", _main_menu_round_button_style(accent, false, false))
		button.add_theme_stylebox_override("hover", _main_menu_round_button_style(accent, true, false))
		button.add_theme_stylebox_override("pressed", _main_menu_round_button_style(accent, true, true))
		button.add_theme_stylebox_override("disabled", _main_menu_round_button_style(Color(0.35, 0.40, 0.46, 1.0), false, false))
	if _corner_action_label_text != null:
		_corner_action_label_text.add_theme_font_size_override("font_size", roundi(button_size * (0.34 if portrait else 0.26)))
	if _corner_action_hover_button != null:
		_position_corner_action_label(_corner_action_hover_button)


func _create_corner_icon_button(button_name: String, icon_path: String, tip: String, left_offset: float, accent: Color) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = ""
	button.tooltip_text = ""
	button.set_meta("corner_action_label", tip)
	if icon_path != "":
		button.icon = _load_main_menu_icon_texture(icon_path)
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
	_enable_button_touch_activation(button)
	button.mouse_entered.connect(_show_corner_action_label.bind(button))
	button.mouse_exited.connect(_hide_corner_action_label.bind(button))
	return button


func _load_main_menu_icon_texture(icon_path: String) -> Texture2D:
	if icon_path == "":
		return null
	if _main_menu_imported_texture_cache_exists(icon_path):
		var imported_texture := load(icon_path) as Texture2D
		if imported_texture != null:
			return imported_texture
	var bytes := FileAccess.get_file_as_bytes(icon_path)
	if bytes.is_empty():
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _main_menu_imported_texture_cache_exists(icon_path: String) -> bool:
	var import_file := FileAccess.open("%s.import" % icon_path, FileAccess.READ)
	if import_file == null:
		return false
	var text := import_file.get_as_text()
	import_file.close()
	for raw_line: String in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("path=\"") and line.ends_with("\""):
			var imported_path := line.substr(6, line.length() - 7)
			return FileAccess.file_exists(imported_path)
	return false


func _on_non_battle_orientation_button_pressed() -> void:
	_hide_corner_action_label(_non_battle_orientation_button)
	if GameManager != null and GameManager.has_method("toggle_non_battle_layout_mode"):
		GameManager.call("toggle_non_battle_layout_mode", true, true)
	_update_non_battle_orientation_button_state()


func _update_non_battle_orientation_button_state() -> void:
	if _non_battle_orientation_button == null:
		return
	var mode := _current_non_battle_orientation_mode()
	_non_battle_orientation_button.icon = _make_non_battle_orientation_icon(mode)
	_non_battle_orientation_button.set_meta("corner_action_label", _non_battle_orientation_hover_label(mode))
	_non_battle_orientation_button.set_meta("non_battle_orientation_mode", mode)
	if _corner_action_hover_button == _non_battle_orientation_button:
		_show_corner_action_label(_non_battle_orientation_button)


func _current_non_battle_orientation_mode() -> String:
	if GameManager != null and GameManager.has_method("sanitize_non_battle_layout_mode"):
		return str(GameManager.call("sanitize_non_battle_layout_mode", str(GameManager.get("non_battle_layout_mode"))))
	return "landscape"


func _non_battle_orientation_hover_label(mode: String = "") -> String:
	var normalized := mode if mode != "" else _current_non_battle_orientation_mode()
	if normalized == "portrait":
		return "非战斗界面：竖屏"
	return "非战斗界面：横屏"


func _make_non_battle_orientation_icon(mode: String) -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var portrait := mode == "portrait"
	var screen_rect := Rect2i(Vector2i(21, 8), Vector2i(22, 48)) if portrait else Rect2i(Vector2i(8, 20), Vector2i(48, 24))
	_fill_icon_rect(image, screen_rect, Color(0.05, 0.16, 0.20, 0.92))
	_draw_icon_rect_outline(image, screen_rect, 3, Color(0.80, 1.0, 1.0, 1.0))
	var inner_rect := Rect2i(screen_rect.position + Vector2i(5, 6), screen_rect.size - Vector2i(10, 12))
	_draw_icon_rect_outline(image, inner_rect, 1, Color(0.28, 0.92, 1.0, 0.78))
	if portrait:
		_fill_icon_rect(image, Rect2i(Vector2i(screen_rect.position.x + 8, screen_rect.position.y + screen_rect.size.y - 6), Vector2i(6, 2)), Color(0.92, 1.0, 1.0, 0.95))
	else:
		_fill_icon_rect(image, Rect2i(Vector2i(screen_rect.position.x + screen_rect.size.x - 7, screen_rect.position.y + 10), Vector2i(2, 5)), Color(0.92, 1.0, 1.0, 0.95))
	return ImageTexture.create_from_image(image)


func _fill_icon_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y: int in range(rect.position.y, rect.position.y + rect.size.y):
		for x: int in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, color)


func _draw_icon_rect_outline(image: Image, rect: Rect2i, thickness: int, color: Color) -> void:
	for i: int in thickness:
		_fill_icon_rect(image, Rect2i(rect.position + Vector2i(i, i), Vector2i(rect.size.x - i * 2, 1)), color)
		_fill_icon_rect(image, Rect2i(rect.position + Vector2i(i, rect.size.y - 1 - i), Vector2i(rect.size.x - i * 2, 1)), color)
		_fill_icon_rect(image, Rect2i(rect.position + Vector2i(i, i), Vector2i(1, rect.size.y - i * 2)), color)
		_fill_icon_rect(image, Rect2i(rect.position + Vector2i(rect.size.x - 1 - i, i), Vector2i(1, rect.size.y - i * 2)), color)


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
	_corner_action_label_text.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(15))
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
	var button_size := button.custom_minimum_size.x if button != null else CORNER_ACTION_BUTTON_SIZE
	var desired := Vector2(maxf(CORNER_ACTION_LABEL_MIN_WIDTH, text_min.x + button_size * 0.48), maxf(32.0, button_size * 0.48))
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
		version_label.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(14))
		version_label.add_theme_color_override("font_color", Color(0.70, 0.82, 0.90, 0.92))

	_ensure_update_button()
	_ensure_corner_action_buttons()
	call_deferred("_start_update_check")
	call_deferred("_start_deck_center_meta_check")
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
	_update_button.custom_minimum_size = Vector2(240, 44)
	_update_button.layout_mode = 1
	_update_button.anchor_left = 0.5
	_update_button.anchor_top = 1.0
	_update_button.anchor_right = 0.5
	_update_button.anchor_bottom = 1.0
	_update_button.offset_left = -120.0
	_update_button.offset_top = -84.0
	_update_button.offset_right = 120.0
	_update_button.offset_bottom = -40.0
	_update_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_update_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_update_button.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(16))
	_update_button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	_update_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_update_button.add_theme_color_override("font_pressed_color", Color(0.03, 0.07, 0.10, 1.0))
	_update_button.add_theme_stylebox_override("normal", _main_menu_button_style(HudThemeScript.ACCENT_WARM, false, false, false))
	_update_button.add_theme_stylebox_override("hover", _main_menu_button_style(HudThemeScript.ACCENT_WARM, false, true, false))
	_update_button.add_theme_stylebox_override("pressed", _main_menu_button_style(HudThemeScript.ACCENT_WARM, false, true, true))
	_update_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_enable_button_touch_activation(_update_button)
	_update_button.pressed.connect(_on_update_button_pressed)
	add_child(_update_button)


func _start_update_button_flash() -> void:
	if _update_button == null or not is_instance_valid(_update_button):
		return
	_stop_update_button_flash(false)
	_update_button.modulate = Color.WHITE
	_update_button_flash_tween = create_tween()
	_update_button_flash_tween.set_loops()
	_update_button_flash_tween.set_trans(Tween.TRANS_SINE)
	_update_button_flash_tween.set_ease(Tween.EASE_IN_OUT)
	_update_button_flash_tween.tween_property(_update_button, "modulate", Color(1.0, 0.78, 0.24, 0.42), 0.45)
	_update_button_flash_tween.tween_property(_update_button, "modulate", Color.WHITE, 0.45)


func _stop_update_button_flash(reset_modulate: bool = true) -> void:
	if _update_button_flash_tween != null:
		_update_button_flash_tween.kill()
		_update_button_flash_tween = null
	if reset_modulate and _update_button != null and is_instance_valid(_update_button):
		_update_button.modulate = Color.WHITE


func _start_deck_center_meta_check() -> void:
	if _deck_center_meta_client != null:
		var existing_err: int = int(_deck_center_meta_client.call("check_latest"))
		if existing_err != OK and existing_err != ERR_BUSY:
			_on_deck_center_meta_failed("卡组中心更新检查启动失败：%d" % existing_err)
		return
	_deck_center_meta_client = DeckCenterMetaClientScript.new()
	_deck_center_meta_client.new_revision_available.connect(_on_deck_center_new_revision_available)
	_deck_center_meta_client.no_new_revision.connect(_on_deck_center_no_new_revision)
	_deck_center_meta_client.check_failed.connect(_on_deck_center_meta_failed)
	add_child(_deck_center_meta_client)
	var err: int = int(_deck_center_meta_client.call("check_latest"))
	if err != OK and err != ERR_BUSY:
		_on_deck_center_meta_failed("卡组中心更新检查启动失败：%d" % err)


func _on_deck_center_new_revision_available(info: Dictionary) -> void:
	_pending_deck_center_meta = info.duplicate(true)
	_start_deck_center_button_flash()


func _on_deck_center_no_new_revision(_info: Dictionary) -> void:
	_pending_deck_center_meta = {}
	_stop_deck_center_button_flash()


func _on_deck_center_meta_failed(message: String) -> void:
	print_debug("[DeckCenterMeta] %s" % message)


func _deck_center_button() -> Button:
	var button := get_node_or_null("%BtnDeckManager") as Button
	if button != null:
		return button
	button = get_node_or_null("VBoxContainer/BtnDeckManager") as Button
	if button != null:
		return button
	return find_child("BtnDeckManager", true, false) as Button


func _ensure_deck_center_new_badge() -> void:
	var button := _deck_center_button()
	if button == null:
		return
	if _deck_center_new_badge != null and is_instance_valid(_deck_center_new_badge):
		if _deck_center_new_badge.get_parent() != self:
			if _deck_center_new_badge.get_parent() != null:
				_deck_center_new_badge.get_parent().remove_child(_deck_center_new_badge)
			add_child(_deck_center_new_badge)
		_position_deck_center_new_badge()
		return
	_deck_center_new_badge = PanelContainer.new()
	_deck_center_new_badge.name = "DeckCenterNewBadge"
	_deck_center_new_badge.visible = false
	_deck_center_new_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_center_new_badge.z_index = 20
	_deck_center_new_badge.layout_mode = 1
	_deck_center_new_badge.anchor_left = 0.0
	_deck_center_new_badge.anchor_top = 0.0
	_deck_center_new_badge.anchor_right = 0.0
	_deck_center_new_badge.anchor_bottom = 0.0
	_deck_center_new_badge.offset_left = 0.0
	_deck_center_new_badge.offset_top = 0.0
	_deck_center_new_badge.offset_right = 54.0
	_deck_center_new_badge.offset_bottom = 22.0
	_deck_center_new_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_deck_center_new_badge.add_theme_stylebox_override("panel", _deck_center_new_badge_style())
	add_child(_deck_center_new_badge)

	var label := Label.new()
	label.name = "DeckCenterNewBadgeText"
	label.text = "NEW"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(12))
	label.add_theme_color_override("font_color", Color(0.03, 0.05, 0.07, 1.0))
	label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 0.45))
	label.add_theme_constant_override("outline_size", 1)
	_deck_center_new_badge.add_child(label)
	_position_deck_center_new_badge()


func _position_deck_center_new_badge() -> void:
	if _deck_center_new_badge == null or not is_instance_valid(_deck_center_new_badge):
		return
	var button := _deck_center_button()
	if button == null or not is_instance_valid(button):
		return
	var rect := button.get_global_rect()
	_deck_center_new_badge.size = Vector2(54.0, 22.0)
	_deck_center_new_badge.global_position = Vector2(rect.position.x + rect.size.x - 64.0, rect.position.y + 4.0)


func _deck_center_new_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.82, 0.22, 0.96)
	style.border_color = Color(1.0, 0.98, 0.68, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(1.0, 0.60, 0.0, 0.42)
	style.shadow_size = 8
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style


func _set_deck_center_new_badge_visible(visible: bool) -> void:
	_ensure_deck_center_new_badge()
	if _deck_center_new_badge != null and is_instance_valid(_deck_center_new_badge):
		_deck_center_new_badge.visible = visible


func _start_deck_center_button_flash() -> void:
	var button := _deck_center_button()
	if button == null or not is_instance_valid(button):
		return
	_stop_deck_center_button_flash(false)
	_set_deck_center_new_badge_visible(true)
	button.modulate = Color.WHITE
	_deck_center_button_flash_tween = create_tween()
	_deck_center_button_flash_tween.set_loops()
	_deck_center_button_flash_tween.set_trans(Tween.TRANS_SINE)
	_deck_center_button_flash_tween.set_ease(Tween.EASE_IN_OUT)
	_deck_center_button_flash_tween.tween_property(button, "modulate", Color(1.0, 0.82, 0.26, 0.48), 0.48)
	_deck_center_button_flash_tween.tween_property(button, "modulate", Color.WHITE, 0.48)


func _stop_deck_center_button_flash(reset_modulate: bool = true) -> void:
	if _deck_center_button_flash_tween != null:
		_deck_center_button_flash_tween.kill()
		_deck_center_button_flash_tween = null
	var button := _deck_center_button()
	if reset_modulate and button != null and is_instance_valid(button):
		button.modulate = Color.WHITE
	_set_deck_center_new_badge_visible(false)


func _mark_pending_deck_center_meta_seen() -> void:
	var revision := str(_pending_deck_center_meta.get("latest_revision", "")).strip_edges()
	if revision != "":
		if _deck_center_meta_client != null and is_instance_valid(_deck_center_meta_client):
			_deck_center_meta_client.call("mark_revision_seen", revision, _pending_deck_center_meta)
		else:
			var pending_client = DeckCenterMetaClientScript.new()
			pending_client.call("mark_revision_seen", revision, _pending_deck_center_meta)
			pending_client.free()
	else:
		if _deck_center_meta_client != null and is_instance_valid(_deck_center_meta_client):
			_deck_center_meta_client.call("mark_latest_known_revision_seen")
		else:
			var client = DeckCenterMetaClientScript.new()
			client.call("mark_latest_known_revision_seen")
			client.free()
	_pending_deck_center_meta = {}
	_stop_deck_center_button_flash()


func _start_update_check(force: bool = false) -> void:
	if not force and _should_show_temp_update_preview_on_startup():
		_show_temp_update_available_preview()
		return
	_temp_update_preview_active = false
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


func _should_show_temp_update_preview_on_startup() -> bool:
	if TEMP_FORCE_UPDATE_PREVIEW_ON_STARTUP:
		return true
	for arg: String in OS.get_cmdline_user_args():
		if arg == TEMP_UPDATE_PREVIEW_ARG:
			return true
	return false


func _show_temp_update_available_preview() -> void:
	_manual_update_requested = false
	_temp_update_preview_active = true
	_on_update_available(_build_temp_update_preview_info())


func _build_temp_update_preview_info() -> Dictionary:
	var latest_version := _next_patch_version(AppVersionScript.VERSION)
	return {
		"schema_version": 1,
		"latest_version": latest_version,
		"display_version": "v%s" % latest_version,
		"release_date": Time.get_date_string_from_system(),
		"title": "发现新版本 v%s" % latest_version,
		"summary": PackedStringArray([
			"临时预览：模拟自动检查发现新版本。",
			"用于检查首页更新提示、闪烁按钮和更新弹窗表现。",
			"不会访问服务器，也不会写入忽略版本或更新检查状态。",
		]),
		"download_page_url": UpdateCheckerScript.DEFAULT_DOWNLOAD_PAGE_URL,
		"manifest_url": "debug://preview-update-available",
	}


func _next_patch_version(version: String) -> String:
	var normalized := version.strip_edges()
	if normalized.begins_with("v") or normalized.begins_with("V"):
		normalized = normalized.substr(1)
	var parts := normalized.split(".")
	while parts.size() < 3:
		parts.append("0")
	var major := int(parts[0])
	var minor := int(parts[1])
	var patch := int(parts[2]) + 1
	return "%d.%d.%d" % [major, minor, patch]


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
		_start_update_button_flash()
	if was_manual:
		_show_update_dialog(_available_update)


func _on_no_update(info: Dictionary) -> void:
	var was_manual := _manual_update_requested
	_manual_update_requested = false
	_temp_update_preview_active = false
	_set_manual_update_busy(false)
	_available_update = {}
	if _update_button != null:
		_stop_update_button_flash()
		_update_button.visible = false
	if was_manual:
		var display_version := str(info.get("display_version", AppVersionScript.DISPLAY_VERSION))
		_show_update_status_dialog("已是最新版本", "当前版本：%s\n服务器版本：%s" % [AppVersionScript.DISPLAY_VERSION, display_version])


func _on_update_check_failed(message: String) -> void:
	_temp_update_preview_active = false
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
	_temp_update_preview_active = false
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


func _on_share_button_pressed() -> void:
	_hide_corner_action_label(_share_button)
	_show_share_dialog()


func _show_share_dialog() -> void:
	_show_hud_modal("把 PTCG Deck Agent 分享给牌友", _format_share_dialog_text(), [
		{
			"id": "close",
			"text": "先看看",
			"accent": HudThemeScript.ACCENT,
			"primary": false,
		},
		{
			"id": "copy_share_invite",
			"text": "复制分享文案",
			"accent": MAIN_MENU_FEATURED_ACCENT,
			"primary": true,
		},
	], Vector2(680, 430))


func _format_share_dialog_text() -> String:
	return "\n".join(PackedStringArray([
		"把链接发给牌友，就能免费一起测构筑、跑 AI 对局、复盘失误，也可以直接约几轮比赛模式。",
		"",
		"复制后可以发到群里或私聊：",
		"免费 PTCG 练牌工具，有 AI 陪练和比赛模拟。打开就能试卡组：%s" % GAME_HOME_URL,
		"",
		"网址：%s" % GAME_HOME_URL,
	]))


func _format_share_clipboard_text() -> String:
	return "\n".join(PackedStringArray([
		"免费 PTCG 练牌工具，带 AI 陪练/对战。",
		"打开就能试卡组：%s" % GAME_HOME_URL,
	]))


func _copy_share_invite_to_clipboard() -> String:
	var share_text := _format_share_clipboard_text()
	DisplayServer.clipboard_set(share_text)
	_show_update_status_dialog("分享文案已复制", "已经复制到剪贴板。把它发到群聊或私聊给牌友，对方打开链接就能一起练牌。\n\n%s" % GAME_HOME_URL)
	return share_text


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

	var portrait := _is_portrait_home_layout()
	var portrait_scale := _home_portrait_scale()
	var root := VBoxContainer.new()
	root.name = "HudModalRoot"
	root.add_theme_constant_override("separation", roundi(22.0 * portrait_scale) if portrait else 14)
	_hud_modal_panel.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", roundi(34.0 * portrait_scale) if portrait else HudThemeScript.scaled_font_size(22))
	title_label.add_theme_color_override("font_color", Color(0.94, 0.99, 1.0, 1.0))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.74, 1.0, 0.58))
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	header.add_child(title_label)

	var close_button_size := Vector2(92.0 * portrait_scale, 92.0 * portrait_scale) if portrait else Vector2(42, 38)
	var close_button := _create_feedback_action_button("×", HudThemeScript.ACCENT, close_button_size)
	close_button.pressed.connect(_hide_hud_modal)
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.name = "HudModalScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, maxf(360.0 * portrait_scale, preferred_size.y - 170.0) if portrait else maxf(120.0, preferred_size.y - 170.0))
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
		rich_body.add_theme_font_size_override("normal_font_size", roundi(27.0 * portrait_scale) if portrait else HudThemeScript.scaled_font_size(16))
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
		body.add_theme_font_size_override("font_size", roundi(27.0 * portrait_scale) if portrait else HudThemeScript.scaled_font_size(16))
		body.add_theme_color_override("font_color", Color(0.84, 0.93, 1.0, 1.0))
		body.add_theme_constant_override("line_spacing", 6)
		scroll.add_child(body)
	HudThemeScript.style_scroll_container(scroll)
	if portrait:
		NonBattleTouchBridgeScript.configure_hidden_vertical_drag_scroll(scroll)
	else:
		NonBattleTouchBridgeScript.configure_visible_vertical_scroll(scroll)

	var footer := HBoxContainer.new()
	footer.name = "HudModalFooter"
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", roundi(14.0 * portrait_scale) if portrait else 12)
	root.add_child(footer)

	for raw_action: Variant in actions:
		if not (raw_action is Dictionary):
			continue
		var action := raw_action as Dictionary
		var action_id := str(action.get("id", "close"))
		var accent: Color = action.get("accent", HudThemeScript.ACCENT) as Color
		var minimum_width := 132.0 if bool(action.get("primary", false)) else 118.0
		var button_size := Vector2(maxf(minimum_width * portrait_scale, 260.0), 92.0 * portrait_scale) if portrait else Vector2(minimum_width, 44)
		var button := _create_feedback_action_button(str(action.get("text", "确定")), accent, button_size)
		if portrait:
			button.add_theme_font_size_override("font_size", roundi(27.0 * portrait_scale))
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
	var viewport_size := get_viewport_rect().size if is_inside_tree() else size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280, 720)
	if _is_portrait_home_layout():
		var margin := clampf(viewport_size.x * 0.028, 24.0, 42.0)
		_hud_modal_panel.custom_minimum_size = Vector2(
			maxf(320.0, viewport_size.x - margin * 2.0),
			minf(viewport_size.y - margin * 2.0, maxf(viewport_size.y * 0.36, 720.0))
		)
		return
	_hud_modal_panel.custom_minimum_size = Vector2(
		minf(preferred.x, maxf(320.0, viewport_size.x - 56.0)),
		minf(preferred.y, maxf(230.0, viewport_size.y - 56.0))
	)


func _on_hud_modal_action_pressed(action_id: String) -> void:
	match action_id:
		"copy_share_invite":
			_copy_share_invite_to_clipboard()
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
	if _feedback_text_edit != null and is_inside_tree():
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
	title.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(24))
	title.add_theme_color_override("font_color", Color(0.94, 0.99, 1.0, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.74, 1.0, 0.62))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "直接提交到服务器，也可以扫码小红书后续补充截图"
	subtitle.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(14))
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
	var root := GridContainer.new()
	root.name = "FeedbackContent"
	root.columns = 2
	root.custom_minimum_size = Vector2(740, 398)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("h_separation", 16)
	root.add_theme_constant_override("v_separation", 16)

	var contact_panel := PanelContainer.new()
	contact_panel.name = "FeedbackContactPanel"
	contact_panel.custom_minimum_size = Vector2(232, 398)
	contact_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contact_panel.add_theme_stylebox_override("panel", _feedback_side_panel_style(HudThemeScript.ACCENT))
	root.add_child(contact_panel)

	var contact_box := VBoxContainer.new()
	contact_box.name = "FeedbackContactBox"
	contact_box.alignment = BoxContainer.ALIGNMENT_CENTER
	contact_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contact_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contact_box.add_theme_constant_override("separation", 8)
	contact_panel.add_child(contact_box)

	var qr_texture := _load_xhs_qr_texture()
	if qr_texture != null:
		var qr := TextureRect.new()
		qr.name = "XhsQrImage"
		qr.texture = qr_texture
		qr.custom_minimum_size = FEEDBACK_QR_DESKTOP_SIZE
		qr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		qr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		contact_box.add_child(qr)
	else:
		var qr_fallback := Label.new()
		qr_fallback.name = "XhsQrFallback"
		qr_fallback.custom_minimum_size = FEEDBACK_QR_DESKTOP_SIZE
		qr_fallback.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		qr_fallback.text = "二维码图片未找到\n请搜索小红书号"
		qr_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qr_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		contact_box.add_child(qr_fallback)

	var contact_name := Label.new()
	contact_name.text = XHS_DISPLAY_NAME
	contact_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contact_name.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(20))
	contact_name.add_theme_color_override("font_color", Color(1.0, 0.78, 0.50, 1.0))
	contact_box.add_child(contact_name)

	var contact_id := Label.new()
	contact_id.text = "小红书号：%s" % XHS_ID
	contact_id.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contact_id.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(13))
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
	info.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(14))
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
	button.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(15))
	button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.03, 0.07, 0.10, 1.0))
	button.add_theme_stylebox_override("normal", _main_menu_button_style(accent, false, false, false))
	button.add_theme_stylebox_override("hover", _main_menu_button_style(accent, false, true, false))
	button.add_theme_stylebox_override("pressed", _main_menu_button_style(accent, false, true, true))
	button.add_theme_stylebox_override("disabled", _main_menu_button_style(Color(0.30, 0.34, 0.38, 1.0), false, false, false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_enable_button_touch_activation(button)
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
	var viewport_size := get_viewport_rect().size if is_inside_tree() else size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280, 720)
	if _is_portrait_home_layout():
		var margin := clampf(viewport_size.x * 0.026, 24.0, 42.0)
		_feedback_panel.custom_minimum_size = Vector2(
			maxf(320.0, viewport_size.x - margin * 2.0),
			maxf(320.0, viewport_size.y - margin * 2.0)
		)
		_apply_feedback_portrait_metrics()
		return
	_apply_feedback_landscape_metrics()
	_feedback_panel.custom_minimum_size = Vector2(
		minf(820.0, maxf(320.0, viewport_size.x - 56.0)),
		minf(560.0, maxf(420.0, viewport_size.y - 56.0))
	)


func _apply_feedback_portrait_metrics() -> void:
	if _feedback_panel == null:
		return
	var scale := _home_portrait_scale()
	var viewport_size := get_viewport_rect().size if is_inside_tree() else size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(390, 844)
	var content := _feedback_panel.find_child("FeedbackContent", true, false) as GridContainer
	if content != null:
		content.columns = 1
		content.custom_minimum_size.x = maxf(320.0, viewport_size.x - 96.0)
		content.add_theme_constant_override("h_separation", 0)
		content.add_theme_constant_override("v_separation", roundi(18.0 * scale))
	var qr_size := _feedback_portrait_qr_size(viewport_size)
	var contact_panel := _feedback_panel.find_child("FeedbackContactPanel", true, false) as PanelContainer
	if contact_panel != null:
		contact_panel.custom_minimum_size = Vector2(maxf(320.0, viewport_size.x - 96.0), qr_size.y + 142.0 * scale)
		contact_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		contact_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var qr := _feedback_panel.find_child("XhsQrImage", true, false) as TextureRect
	if qr != null:
		qr.custom_minimum_size = qr_size
		qr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var qr_fallback := _feedback_panel.find_child("XhsQrFallback", true, false) as Control
	if qr_fallback != null:
		qr_fallback.custom_minimum_size = qr_size
		qr_fallback.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_feedback_portrait_metrics_recursive(_feedback_panel, scale)
	if _feedback_name_input != null:
		_feedback_name_input.custom_minimum_size.y = maxf(_feedback_name_input.custom_minimum_size.y, 78.0 * scale)
		_feedback_name_input.add_theme_font_size_override("font_size", roundi(27.0 * scale))
	if _feedback_text_edit != null:
		_feedback_text_edit.custom_minimum_size.y = maxf(_feedback_text_edit.custom_minimum_size.y, 225.0 * scale)
		_feedback_text_edit.add_theme_font_size_override("font_size", roundi(24.0 * scale))
	if _feedback_submit_button != null:
		_feedback_submit_button.custom_minimum_size.y = maxf(_feedback_submit_button.custom_minimum_size.y, 92.0 * scale)
		_feedback_submit_button.add_theme_font_size_override("font_size", roundi(27.0 * scale))


func _apply_feedback_landscape_metrics() -> void:
	if _feedback_panel == null:
		return
	var content := _feedback_panel.find_child("FeedbackContent", true, false) as GridContainer
	if content != null:
		content.columns = 2
		content.custom_minimum_size = Vector2(740.0, 398.0)
		content.add_theme_constant_override("h_separation", 16)
		content.add_theme_constant_override("v_separation", 16)
	var contact_panel := _feedback_panel.find_child("FeedbackContactPanel", true, false) as PanelContainer
	if contact_panel != null:
		contact_panel.custom_minimum_size = Vector2(232.0, 398.0)
		contact_panel.size_flags_horizontal = Control.SIZE_FILL
		contact_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var qr := _feedback_panel.find_child("XhsQrImage", true, false) as TextureRect
	if qr != null:
		qr.custom_minimum_size = FEEDBACK_QR_DESKTOP_SIZE
		qr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var qr_fallback := _feedback_panel.find_child("XhsQrFallback", true, false) as Control
	if qr_fallback != null:
		qr_fallback.custom_minimum_size = FEEDBACK_QR_DESKTOP_SIZE
		qr_fallback.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _feedback_portrait_qr_size(viewport_size: Vector2) -> Vector2:
	var width := clampf(viewport_size.x * 0.56, 300.0, 620.0)
	return Vector2(width, width * FEEDBACK_QR_CARD_ASPECT)


func _apply_feedback_portrait_metrics_recursive(node: Node, scale: float) -> void:
	if node is Button:
		var button := node as Button
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 92.0 * scale)
		button.add_theme_font_size_override("font_size", roundi(27.0 * scale))
	elif node is Label:
		var label := node as Label
		var base := 28.0
		if label.name == "":
			base = 24.0
		label.add_theme_font_size_override("font_size", roundi(base * scale))
	elif node is TextEdit:
		(node as TextEdit).add_theme_font_size_override("font_size", roundi(24.0 * scale))
	elif node is LineEdit:
		(node as LineEdit).add_theme_font_size_override("font_size", roundi(27.0 * scale))
	for child: Node in node.get_children():
		_apply_feedback_portrait_metrics_recursive(child, scale)


func _is_portrait_home_layout() -> bool:
	if str(get_meta("non_battle_layout_mode", "")) == "portrait":
		return true
	var viewport_size := get_viewport_rect().size if is_inside_tree() else size
	return viewport_size.y > viewport_size.x


func _home_portrait_scale() -> float:
	var viewport_size := get_viewport_rect().size if is_inside_tree() else size
	if viewport_size.x <= 0.0:
		viewport_size = Vector2(390, 844)
	return clampf(viewport_size.x / 430.0, 1.0, 1.62)


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
	if _temp_update_preview_active:
		_temp_update_preview_active = false
		_available_update = {}
		if _update_button != null:
			_stop_update_button_flash()
			_update_button.visible = false
		return
	if _update_checker != null:
		_update_checker.ignore_version(str(_available_update.get("latest_version", "")))
	if _update_button != null:
		_stop_update_button_flash()
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
	_mark_pending_deck_center_meta_seen()
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
