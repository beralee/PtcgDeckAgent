extends Control

const TOURNAMENT_SIZES := [16, 32, 64, 128]
const SwissTournamentScript := preload("res://scripts/tournament/SwissTournament.gd")
const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const NonBattleLayoutControllerScript := preload("res://scripts/ui/non_battle/NonBattleLayoutController.gd")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")

const SIZE_HUD_PICKER_OVERLAY_NAME := "TournamentSizeHudPickerOverlay"
const HUD_ACCENT := Color(0.28, 0.92, 1.0, 1.0)
const HUD_TEXT := Color(0.92, 0.98, 1.0, 1.0)
const HUD_SURFACE := Color(0.025, 0.055, 0.085, 0.97)
const DEFAULT_PLAYER_NAME_PREFIXES := ["星辉", "闪电", "深蓝", "炽焰", "月影", "疾风", "晨光", "极光"]
const DEFAULT_PLAYER_NAME_SUFFIXES := ["训练家", "挑战者", "牌手", "选手"]
const DEFAULT_PLAYER_NAME_MIN_NUMBER := 100
const DEFAULT_PLAYER_NAME_MAX_NUMBER := 999

var _round_probe: RefCounted = SwissTournamentScript.new()
var _non_battle_layout_controller: RefCounted = NonBattleLayoutControllerScript.new()
var _last_non_battle_layout_context: Dictionary = {}
var _size_hud_picker_overlay: Control = null
var _size_hud_picker_list: VBoxContainer = null
var _size_hud_picker_scroll: ScrollContainer = null
var _default_player_name_rng := RandomNumberGenerator.new()


func _ready() -> void:
	HudThemeScript.apply(self)
	_connect_non_battle_layout_signal()
	%TitleLabel.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(24))
	%BtnBack.text = "返回"
	%BtnStart.text = "查看比赛情况"
	%TitleLabel.text = "比赛设置"
	%NameLabel.text = "玩家名字"
	%SizeLabel.text = "比赛人数"
	%HintLabel.text = "下一步会进入赛前总览页面，先查看参赛名单、卡组分布和本次瑞士轮轮数，再正式开始第一轮。"
	%NameEdit.placeholder_text = "输入你的名字"
	_ensure_random_default_player_name()
	%BtnBack.pressed.connect(_on_back_pressed)
	%BtnStart.pressed.connect(_on_start_pressed)
	%NameEdit.text_changed.connect(_on_name_changed)
	_ensure_size_option_input_bindings()
	_setup_size_options()
	_refresh_selected_deck()
	_refresh_round_info()
	_clear_error()
	call_deferred("_apply_non_battle_layout")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_non_battle_layout()


func _input(event: InputEvent) -> void:
	if _handle_size_option_touch_event(event):
		return
	if _handle_tournament_size_hud_picker_input(event):
		return
	NonBattleTouchBridgeScript.handle_root_touch(self, event)


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
		mode = str(GameManager.get("non_battle_layout_mode")) if GameManager != null else "landscape"
	var context: Dictionary = _non_battle_layout_controller.call("build_context", size, mode, false)
	_last_non_battle_layout_context = context.duplicate(true)
	var portrait := bool(context.get("is_portrait", false))
	set_meta("non_battle_layout_mode", str(context.get("resolved_mode", mode)))
	var panel := find_child("Panel", true, false) as Control
	if panel != null:
		panel.custom_minimum_size.x = float(context.get("content_width", 660.0)) if portrait else 660.0
		panel.custom_minimum_size.y = maxf(640.0, size.y - float(context.get("page_margin", 24.0)) * 2.0) if portrait else 460.0
	_ensure_size_option_input_bindings()
	_apply_tournament_setup_mobile_metrics(self, context, portrait)
	_apply_tournament_setup_button_stack(portrait)
	_sync_size_option_touch_policy(portrait)
	if _size_hud_picker_overlay != null and is_instance_valid(_size_hud_picker_overlay):
		_refresh_tournament_size_hud_picker_layout()


func _apply_tournament_setup_mobile_metrics(node: Node, context: Dictionary, portrait: bool) -> void:
	if node is Button:
		var button := node as Button
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, float(context.get("secondary_button_height", 44.0)) if portrait else button.custom_minimum_size.y)
		button.add_theme_font_size_override("font_size", int(context.get("button_font_size", 15)) if portrait else HudThemeScript.scaled_font_size(15))
		NonBattleTouchBridgeScript.bind_button_touch(button)
	elif node is OptionButton or node is LineEdit:
		var control := node as Control
		control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, float(context.get("input_height", 42.0)) if portrait else control.custom_minimum_size.y)
		if portrait:
			control.add_theme_font_size_override("font_size", maxi(int(context.get("input_font_size", 15)), int(context.get("button_font_size", 15))))
		if control is LineEdit:
			NonBattleTouchBridgeScript.bind_focus_control_touch(control)
		elif control is OptionButton:
			NonBattleTouchBridgeScript.bind_button_touch(control as Button)
	elif node is Label:
		var label := node as Label
		if label.name == "TitleLabel":
			label.add_theme_font_size_override("font_size", int(context.get("title_font_size", 24)) if portrait else HudThemeScript.scaled_font_size(24))
		elif portrait:
			label.add_theme_font_size_override("font_size", int(context.get("body_font_size", 15)))
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child: Node in node.get_children():
		_apply_tournament_setup_mobile_metrics(child, context, portrait)


func _apply_tournament_setup_button_stack(portrait: bool) -> void:
	var current := find_child("ButtonRow", true, false) as BoxContainer
	if current == null:
		return
	if portrait and current is HBoxContainer:
		_replace_button_row(current, VBoxContainer.new(), 10)
	elif not portrait and current is VBoxContainer:
		_replace_button_row(current, HBoxContainer.new(), 16)


func _replace_button_row(current: BoxContainer, replacement: BoxContainer, separation: int) -> void:
	var parent := current.get_parent()
	if parent == null:
		return
	replacement.name = "ButtonRow"
	replacement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replacement.add_theme_constant_override("separation", separation)
	var children := current.get_children()
	var index := current.get_index()
	var inherited_owner := current.owner
	parent.remove_child(current)
	parent.add_child(replacement)
	replacement.owner = inherited_owner
	parent.move_child(replacement, index)
	for child: Node in children:
		var child_owner := child.owner
		current.remove_child(child)
		child.owner = null
		replacement.add_child(child)
		child.owner = child_owner if child_owner != null else inherited_owner
	current.queue_free()


func _setup_size_options() -> void:
	%SizeOption.clear()
	for size: int in TOURNAMENT_SIZES:
		%SizeOption.add_item("%d 人" % size)
	%SizeOption.select(0)
	if not %SizeOption.item_selected.is_connected(_on_size_changed):
		%SizeOption.item_selected.connect(_on_size_changed)


func _refresh_selected_deck() -> void:
	var deck: DeckData = CardDatabase.get_deck(GameManager.tournament_selected_player_deck_id)
	%DeckLabel.text = "参赛卡组：%s" % (deck.deck_name if deck != null else "未选择")


func _selected_tournament_size() -> int:
	var size_index: int = maxi(0, %SizeOption.selected)
	return TOURNAMENT_SIZES[min(size_index, TOURNAMENT_SIZES.size() - 1)]


func _refresh_round_info() -> void:
	var tournament_size: int = _selected_tournament_size()
	var total_rounds: int = int(_round_probe.call("rounds_for_size", tournament_size))
	%RoundInfoLabel.text = "预计轮数：%d 轮（%d 人瑞士轮）" % [total_rounds, tournament_size]


func _clear_error() -> void:
	%ErrorLabel.visible = false
	%ErrorLabel.text = ""


func _show_error(message: String) -> void:
	%ErrorLabel.visible = true
	%ErrorLabel.text = message


func _ensure_random_default_player_name() -> void:
	var name_edit := get_node_or_null("%NameEdit") as LineEdit
	if name_edit == null:
		return
	if name_edit.text.strip_edges() != "":
		return
	_default_player_name_rng.randomize()
	name_edit.text = _random_default_player_name()


func _random_default_player_name() -> String:
	var prefix: String = str(DEFAULT_PLAYER_NAME_PREFIXES[_default_player_name_rng.randi_range(0, DEFAULT_PLAYER_NAME_PREFIXES.size() - 1)])
	var suffix: String = str(DEFAULT_PLAYER_NAME_SUFFIXES[_default_player_name_rng.randi_range(0, DEFAULT_PLAYER_NAME_SUFFIXES.size() - 1)])
	var number := _default_player_name_rng.randi_range(DEFAULT_PLAYER_NAME_MIN_NUMBER, DEFAULT_PLAYER_NAME_MAX_NUMBER)
	return "%s%s%d" % [prefix, suffix, number]


func _on_size_changed(_index: int) -> void:
	_refresh_round_info()


func _ensure_size_option_input_bindings() -> void:
	var option := _size_option_or_null()
	if option == null:
		return
	var pressed_callback := Callable(self, "_on_size_option_pressed")
	if not option.pressed.is_connected(pressed_callback):
		option.pressed.connect(pressed_callback)
	var gui_callback := Callable(self, "_on_size_option_gui_input")
	if not option.gui_input.is_connected(gui_callback):
		option.gui_input.connect(gui_callback)


func _sync_size_option_touch_policy(portrait: bool) -> void:
	var option := _size_option_or_null()
	if option == null:
		return
	option.set_meta(NonBattleTouchBridgeScript.OPTION_PRESS_SIGNAL_ONLY_META, portrait)


func _size_option_or_null() -> OptionButton:
	var option := get_node_or_null("%SizeOption") as OptionButton
	if option != null:
		return option
	return find_child("SizeOption", true, false) as OptionButton


func _is_portrait_tournament_setup_layout() -> bool:
	if bool(_last_non_battle_layout_context.get("is_portrait", false)):
		return true
	if str(get_meta("non_battle_layout_mode", "")) == "portrait":
		return true
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size if is_inside_tree() else Vector2.ZERO
	return viewport_size.y > viewport_size.x


func _should_use_size_hud_picker(option: OptionButton = null) -> bool:
	if option == null:
		option = _size_option_or_null()
	if option == null:
		return false
	return _is_portrait_tournament_setup_layout() or bool(option.get_meta(NonBattleTouchBridgeScript.OPTION_PRESS_SIGNAL_ONLY_META, false))


func _on_size_option_pressed() -> void:
	var option := _size_option_or_null()
	if _should_use_size_hud_picker(option):
		_show_tournament_size_hud_picker()


func _on_size_option_gui_input(event: InputEvent) -> void:
	var option := _size_option_or_null()
	if not _should_use_size_hud_picker(option):
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		accept_event()
		if not touch.pressed:
			_show_tournament_size_hud_picker()
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if not mouse.pressed:
			_show_tournament_size_hud_picker()


func _handle_size_option_touch_event(event: InputEvent) -> bool:
	if not (event is InputEventScreenTouch):
		return false
	var option := _size_option_or_null()
	if option == null:
		return false
	if not _should_use_size_hud_picker(option):
		return false
	var touch := event as InputEventScreenTouch
	var hit_rect := option.get_global_rect()
	if hit_rect.size.x <= 1.0 or hit_rect.size.y <= 1.0:
		hit_rect = Rect2(option.position, Vector2(
			maxf(option.size.x, option.custom_minimum_size.x),
			maxf(option.size.y, option.custom_minimum_size.y)
		))
	if not hit_rect.has_point(touch.position):
		return false
	accept_event()
	if not touch.pressed:
		_show_tournament_size_hud_picker()
	return true


func _handle_tournament_size_hud_picker_input(event: InputEvent) -> bool:
	if _size_hud_picker_overlay == null or not is_instance_valid(_size_hud_picker_overlay) or not _size_hud_picker_overlay.visible:
		return false
	if NonBattleTouchBridgeScript.handle_root_touch(_size_hud_picker_overlay, event):
		return true
	return false


func _show_tournament_size_hud_picker() -> void:
	var option := _size_option_or_null()
	if option == null:
		return
	if option.get_item_count() <= 0:
		_setup_size_options()
	_ensure_tournament_size_hud_picker_overlay()
	_refresh_tournament_size_hud_picker_layout()
	_populate_tournament_size_hud_picker()
	var popup: PopupMenu = option.get_popup()
	if popup != null and popup.visible:
		popup.hide()
	_size_hud_picker_overlay.visible = true
	_size_hud_picker_overlay.move_to_front()


func _hide_tournament_size_hud_picker() -> void:
	if _size_hud_picker_overlay != null and is_instance_valid(_size_hud_picker_overlay):
		_size_hud_picker_overlay.visible = false


func _ensure_tournament_size_hud_picker_overlay() -> void:
	if _size_hud_picker_overlay != null and is_instance_valid(_size_hud_picker_overlay):
		return
	_size_hud_picker_overlay = Control.new()
	_size_hud_picker_overlay.name = SIZE_HUD_PICKER_OVERLAY_NAME
	_size_hud_picker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_size_hud_picker_overlay.visible = false
	_size_hud_picker_overlay.z_index = 2450
	_size_hud_picker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_size_hud_picker_overlay)

	var shade := ColorRect.new()
	shade.name = "TournamentSizeHudPickerShade"
	shade.color = Color(0.0, 0.0, 0.0, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_size_hud_picker_overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "TournamentSizeHudPickerPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _hud_panel_style(HUD_SURFACE, HUD_ACCENT, 22, 10))
	_size_hud_picker_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "TournamentSizeHudPickerMargin"
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.name = "TournamentSizeHudPickerRoot"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	var title := Label.new()
	title.name = "TournamentSizeHudPickerTitle"
	title.text = "选择比赛人数"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", HUD_TEXT)
	root.add_child(title)

	_size_hud_picker_scroll = ScrollContainer.new()
	_size_hud_picker_scroll.name = "TournamentSizeHudPickerScroll"
	_size_hud_picker_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_size_hud_picker_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_size_hud_picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_size_hud_picker_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	HudThemeScript.style_scroll_container(_size_hud_picker_scroll, "auto")
	NonBattleTouchBridgeScript.configure_hidden_vertical_drag_scroll(_size_hud_picker_scroll)
	root.add_child(_size_hud_picker_scroll)

	_size_hud_picker_list = VBoxContainer.new()
	_size_hud_picker_list.name = "TournamentSizeHudPickerList"
	_size_hud_picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_size_hud_picker_list.add_theme_constant_override("separation", 14)
	_size_hud_picker_scroll.add_child(_size_hud_picker_list)

	var close_button := Button.new()
	close_button.name = "TournamentSizeHudPickerCloseButton"
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(0.0, 150.0)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_hud_picker_button(close_button)
	close_button.add_theme_font_size_override("font_size", 48)
	close_button.pressed.connect(_hide_tournament_size_hud_picker)
	NonBattleTouchBridgeScript.bind_button_touch(close_button)
	root.add_child(close_button)


func _refresh_tournament_size_hud_picker_layout() -> void:
	if _size_hud_picker_overlay == null or not is_instance_valid(_size_hud_picker_overlay):
		return
	var viewport_size: Vector2 = _last_non_battle_layout_context.get("viewport_size", size if size.x > 0.0 and size.y > 0.0 else Vector2(1080, 2400))
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1080, 2400)
	var panel := _size_hud_picker_overlay.get_node_or_null("TournamentSizeHudPickerPanel") as PanelContainer
	if panel != null:
		var margin := roundi(clampf(viewport_size.x * 0.035, 28.0, 46.0))
		panel.offset_left = margin
		panel.offset_top = margin
		panel.offset_right = -margin
		panel.offset_bottom = -margin
		panel.custom_minimum_size = Vector2(maxf(320.0, viewport_size.x - margin * 2.0), maxf(560.0, viewport_size.y - margin * 2.0))
	if _size_hud_picker_scroll != null:
		_size_hud_picker_scroll.custom_minimum_size.y = maxf(560.0, viewport_size.y * 0.48)
		HudThemeScript.style_scroll_container(_size_hud_picker_scroll, "auto")
		NonBattleTouchBridgeScript.configure_hidden_vertical_drag_scroll(_size_hud_picker_scroll)


func _populate_tournament_size_hud_picker() -> void:
	if _size_hud_picker_list == null:
		return
	var option := _size_option_or_null()
	if option == null:
		return
	for child: Node in _size_hud_picker_list.get_children():
		child.queue_free()
	var selected_index: int = option.selected
	for i: int in option.get_item_count():
		var size_value: int = TOURNAMENT_SIZES[min(i, TOURNAMENT_SIZES.size() - 1)]
		var round_count := int(_round_probe.call("rounds_for_size", size_value))
		var button := Button.new()
		button.name = "TournamentSizeHudPickerItem%d" % i
		button.text = "%s%d 人 · 预计 %d 轮" % ["[当前] " if i == selected_index else "", size_value, round_count]
		button.custom_minimum_size = Vector2(0.0, 148.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		_style_hud_picker_button(button)
		button.add_theme_font_size_override("font_size", 46)
		button.pressed.connect(_select_tournament_size_from_picker.bind(i))
		NonBattleTouchBridgeScript.bind_button_touch(button)
		_size_hud_picker_list.add_child(button)


func _select_tournament_size_from_picker(index: int) -> void:
	var option := _size_option_or_null()
	if option == null or index < 0 or index >= option.get_item_count():
		_hide_tournament_size_hud_picker()
		return
	option.select(index)
	_on_size_changed(index)
	_hide_tournament_size_hud_picker()


func _style_hud_picker_button(button: Button) -> void:
	if button == null:
		return
	button.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.05, 0.09, 0.12, 1.0))
	button.add_theme_stylebox_override("normal", _hud_panel_style(Color(0.04, 0.12, 0.16, 0.96), Color(0.16, 0.72, 0.86, 0.58), 14, 4))
	button.add_theme_stylebox_override("hover", _hud_panel_style(Color(0.06, 0.18, 0.23, 0.98), HUD_ACCENT, 14, 4))
	button.add_theme_stylebox_override("pressed", _hud_panel_style(Color(0.28, 0.92, 1.0, 0.92), Color(0.60, 1.0, 1.0, 0.9), 14, 4))
	button.add_theme_stylebox_override("disabled", _hud_panel_style(Color(0.04, 0.05, 0.07, 0.8), Color(0.20, 0.25, 0.30, 0.5), 14, 4))


func _hud_panel_style(bg: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _on_name_changed(_text: String) -> void:
	_clear_error()


func _on_back_pressed() -> void:
	GameManager.goto_tournament_deck_select()


func _on_start_pressed() -> void:
	var player_name: String = %NameEdit.text.strip_edges()
	if player_name == "":
		_show_error("请输入玩家名字后再继续。")
		if %NameEdit.is_inside_tree():
			%NameEdit.grab_focus()
		return
	if GameManager.tournament_selected_player_deck_id <= 0:
		_show_error("请先返回上一页选择参赛卡组。")
		return
	var tournament_size: int = _selected_tournament_size()
	GameManager.start_swiss_tournament(player_name, tournament_size)
	if not GameManager.has_active_tournament():
		_show_error("比赛初始化失败，请重新选择卡组后再试。")
		return
	if not is_inside_tree():
		return
	GameManager.goto_tournament_overview()
