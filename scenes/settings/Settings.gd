## AI 设置页面 - ZenMux 与 AI 性格配置
extends Control

const ZenMuxClientScript := preload("res://scripts/network/ZenMuxClient.gd")
const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const NonBattleLayoutControllerScript := preload("res://scripts/ui/non_battle/NonBattleLayoutController.gd")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
const HUD_ACCENT := Color(0.28, 0.92, 1.0, 1.0)
const HUD_ACCENT_WARM := Color(1.0, 0.55, 0.24, 1.0)
const HUD_TEXT := Color(0.92, 0.98, 1.0, 1.0)
const HUD_TEXT_MUTED := Color(0.64, 0.76, 0.86, 1.0)
const ZENMUX_HOME_URL := "https://zenmux.ai"
const ZENMUX_DEFAULT_ENDPOINT := "https://zenmux.ai/api/v1"
const ZENMUX_SETUP_GUIDE := "1. 在浏览器打开 zenmux.ai，注册或登录账号。\n2. 进入控制台/API Keys，新建一个 API Key。\n3. 回到这里，API 地址保持 https://zenmux.ai/api/v1。\n4. 把 API Key 粘贴到“API 密钥”，选择模型；不确定就用默认模型。\n5. 点“测试连接”。提示测试通过后，回到开始对战选择大模型 AI。"
const ZENMUX_TROUBLESHOOTING := "测试失败时先看这里：\n- 鉴权失败/401：API Key 复制错、少复制字符，或 Key 已失效。\n- model not found：当前 Key 不能用这个模型，换一个模型再测。\n- timeout/请求超时：网络慢，把超时改成 90 或 120 秒再试。"
const MODEL_PICKER_OVERLAY_NAME := "AISettingsModelPickerOverlay"
const API_KEY_SELECT_ALL_BOUND_META := "_ai_settings_api_key_select_all_bound"
const API_KEY_SELECTED_ALL_META := "_ai_settings_api_key_selected_all"

var _test_client = ZenMuxClientScript.new()
var _non_battle_layout_controller: RefCounted = NonBattleLayoutControllerScript.new()
var _portrait_action_footer_candidate: Button = null
var _current_non_battle_layout_context: Dictionary = {}
var _model_picker_overlay: Control = null
var _model_picker_scroll: ScrollContainer = null
var _model_picker_list: VBoxContainer = null


func _ready() -> void:
	_apply_settings_copy()
	_ensure_zenmux_setup_guide()
	_configure_settings_form_bounds()
	_apply_hud_theme()
	_connect_non_battle_layout_signal()
	_connect_settings_controls()
	_populate_model_options()
	_load_config()
	call_deferred("_apply_non_battle_layout")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_non_battle_layout()


func _input(event: InputEvent) -> void:
	if _handle_settings_model_picker_input(event):
		return
	if _handle_portrait_action_footer_input(event):
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
	var is_mobile := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	var context: Dictionary = _non_battle_layout_controller.call("build_context", size, mode, is_mobile)
	_current_non_battle_layout_context = context.duplicate(true)
	var portrait := bool(context.get("is_portrait", false))
	set_meta("non_battle_layout_mode", str(context.get("resolved_mode", mode)))
	if portrait:
		_apply_settings_portrait_layout(context)
	else:
		_apply_settings_landscape_layout(context)
	_apply_settings_mobile_metrics(self, context, portrait)
	_refresh_settings_model_picker_layout()
	_sync_hud_frame_to_form()


func _apply_settings_portrait_layout(context: Dictionary) -> void:
	var root := get_node_or_null("VBoxContainer") as VBoxContainer
	var columns := root.get_node_or_null("ContentColumns") as HBoxContainer if root != null else null
	var form_column := find_child("FormColumn", true, false) as Control
	var guide_column := find_child("ZenMuxGuideColumn", true, false) as Control
	if root == null or columns == null or form_column == null:
		return
	var viewport_size: Vector2 = context.get("viewport_size", Vector2(390, 844))
	var horizontal_margin := clampf(viewport_size.x * 0.026, 14.0, 30.0)
	var top_margin := clampf(viewport_size.y * 0.024, 26.0, 58.0)
	var bottom_margin := clampf(viewport_size.y * 0.026, 30.0, 66.0)
	var content_width := maxf(320.0, viewport_size.x - horizontal_margin * 2.0)
	var content_height := maxf(760.0, viewport_size.y - top_margin - bottom_margin)
	root.custom_minimum_size = Vector2(content_width, content_height)
	root.offset_left = -content_width * 0.5
	root.offset_right = content_width * 0.5
	root.offset_top = -viewport_size.y * 0.5 + top_margin
	root.offset_bottom = viewport_size.y * 0.5 - bottom_margin
	root.add_theme_constant_override("separation", int(context.get("section_gap", 14)))
	var scroll := root.get_node_or_null("PortraitSettingsScroll") as ScrollContainer
	if scroll == null:
		scroll = ScrollContainer.new()
		scroll.name = "PortraitSettingsScroll"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(scroll)
		root.move_child(scroll, columns.get_index() + 1)
		var stack := VBoxContainer.new()
		stack.name = "PortraitSettingsStack"
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		stack.add_theme_constant_override("separation", int(context.get("section_gap", 14)))
		scroll.add_child(stack)
	var stack := scroll.get_node_or_null("PortraitSettingsStack") as VBoxContainer
	if stack == null:
		return
	var footer_height := _settings_portrait_footer_height(context)
	HudThemeScript.style_scroll_container(scroll, "auto")
	NonBattleTouchBridgeScript.configure_hidden_vertical_drag_scroll(scroll)
	scroll.custom_minimum_size = Vector2(content_width, maxf(0.0, content_height - footer_height - float(context.get("section_gap", 18)) * 3.0))
	var stack_width := maxf(320.0, content_width - 18.0)
	stack.custom_minimum_size = Vector2(stack_width, 0)
	stack.add_theme_constant_override("separation", int(context.get("section_gap", 14)))
	columns.visible = false
	scroll.visible = true
	var spacer := find_child("Spacer", true, false) as Control
	if spacer != null:
		spacer.visible = false
	_layout_portrait_action_footer(context, content_width, content_height)
	var layout_columns: Array[Control] = [form_column]
	if guide_column != null:
		layout_columns.append(guide_column)
	for column: Control in layout_columns:
		if column.get_parent() != stack:
			if column.get_parent() != null:
				column.get_parent().remove_child(column)
			column.owner = null
			stack.add_child(column)
		column.custom_minimum_size = Vector2(stack_width, 0)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_set_runtime_owner(stack)


func _apply_settings_landscape_layout(_context: Dictionary) -> void:
	_configure_settings_form_bounds()
	var root := get_node_or_null("VBoxContainer") as VBoxContainer
	var columns := root.get_node_or_null("ContentColumns") as HBoxContainer if root != null else null
	var form_column := find_child("FormColumn", true, false) as Control
	var guide_column := find_child("ZenMuxGuideColumn", true, false) as Control
	var scroll := root.get_node_or_null("PortraitSettingsScroll") as ScrollContainer if root != null else null
	if scroll != null:
		scroll.visible = false
	var spacer := find_child("Spacer", true, false) as Control
	if spacer != null:
		spacer.visible = true
	if columns == null or form_column == null:
		return
	_restore_landscape_action_footer(root)
	var layout_columns: Array[Control] = [form_column]
	if guide_column != null:
		layout_columns.append(guide_column)
	for column: Control in layout_columns:
		if column.get_parent() != columns:
			if column.get_parent() != null:
				column.get_parent().remove_child(column)
			column.owner = null
			columns.add_child(column)
	columns.move_child(form_column, 0)
	if guide_column != null:
		columns.move_child(guide_column, 1)
	columns.visible = true
	form_column.custom_minimum_size = Vector2(760 if guide_column == null else 420, 0)
	if guide_column != null:
		guide_column.custom_minimum_size = Vector2(360, 0)
	form_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if guide_column != null:
		guide_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_set_runtime_owner(columns)


func _layout_portrait_action_footer(context: Dictionary, content_width: float, content_height: float) -> void:
	var root := get_node_or_null("VBoxContainer") as VBoxContainer
	var action_row := find_child("HBox", true, false) as HBoxContainer
	if action_row == null:
		return
	if action_row.get_parent() != self:
		if action_row.get_parent() != null:
			action_row.get_parent().remove_child(action_row)
		action_row.owner = null
		add_child(action_row)
	action_row.visible = true
	action_row.z_index = 40
	action_row.mouse_filter = Control.MOUSE_FILTER_PASS
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", int(context.get("section_gap", 14)))
	var footer_height := _settings_portrait_footer_height(context)
	var footer_gap := clampf(22.0 * float(context.get("portrait_scale", 1.0)), 22.0, 42.0)
	action_row.anchor_left = 0.5
	action_row.anchor_right = 0.5
	action_row.anchor_top = 0.5
	action_row.anchor_bottom = 0.5
	action_row.offset_left = -content_width * 0.5
	action_row.offset_right = content_width * 0.5
	action_row.offset_top = content_height * 0.5 - footer_height - footer_gap
	action_row.offset_bottom = content_height * 0.5 - footer_gap
	var viewport_size: Vector2 = context.get("viewport_size", Vector2(390, 844))
	action_row.position = Vector2(
		viewport_size.x * 0.5 + action_row.offset_left,
		viewport_size.y * 0.5 + action_row.offset_top
	)
	action_row.size = Vector2(content_width, footer_height)
	if root != null:
		move_child(action_row, get_child_count() - 1)
	var visible_buttons: Array[Button] = []
	for button_name: String in ["BtnSave", "BtnTest", "BtnBack"]:
		var button := find_child(button_name, true, false) as Button
		if button != null:
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			visible_buttons.append(button)
	if not visible_buttons.is_empty():
		var gap := float(context.get("section_gap", 18))
		var button_width := maxf(1.0, (content_width - gap * float(visible_buttons.size() - 1)) / float(visible_buttons.size()))
		var x := 0.0
		for button: Button in visible_buttons:
			button.position = Vector2(x, 0.0)
			button.size = Vector2(button_width, footer_height)
			x += button_width + gap


func _settings_portrait_footer_height(context: Dictionary) -> float:
	return float(context.get("secondary_button_height", 84.0)) * 1.12


func _handle_portrait_action_footer_input(event: InputEvent) -> bool:
	if str(get_meta("non_battle_layout_mode", "")) != "portrait":
		return false
	var pointer_position := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		pointer_position = touch.position
		pressed = touch.pressed
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return false
		if not _is_mobile_like_runtime():
			return false
		pointer_position = mouse_button.position
		pressed = mouse_button.pressed
	else:
		return false
	var button := _portrait_footer_button_at_position(pointer_position)
	if pressed:
		_portrait_action_footer_candidate = button
		if button != null:
			_accept_pointer_event()
			return true
		return false
	var candidate := _portrait_action_footer_candidate
	_portrait_action_footer_candidate = null
	if candidate == null:
		candidate = button
	if candidate == null or candidate != button:
		return false
	if candidate.disabled or not candidate.visible:
		return false
	candidate.pressed.emit()
	_accept_pointer_event()
	return true


func _portrait_footer_button_at_position(global_position: Vector2) -> Button:
	var action_row := find_child("HBox", true, false) as HBoxContainer
	if action_row == null or not action_row.visible:
		return null
	for button_name: String in ["BtnSave", "BtnTest", "BtnBack"]:
		var button := find_child(button_name, true, false) as Button
		if button != null and button.visible and button.get_global_rect().has_point(global_position):
			return button
	var row_rect := action_row.get_global_rect()
	if not row_rect.has_point(global_position):
		return null
	var buttons: Array[Button] = []
	for button_name: String in ["BtnSave", "BtnTest", "BtnBack"]:
		var button := find_child(button_name, true, false) as Button
		if button != null and button.visible:
			buttons.append(button)
	if buttons.is_empty():
		return null
	var segment_width := row_rect.size.x / float(buttons.size())
	var index := clampi(int(floor((global_position.x - row_rect.position.x) / maxf(segment_width, 1.0))), 0, buttons.size() - 1)
	return buttons[index]


func _is_mobile_like_runtime() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _accept_pointer_event() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _restore_landscape_action_footer(root: VBoxContainer) -> void:
	var action_row := find_child("HBox", true, false) as HBoxContainer
	if action_row == null or root == null:
		return
	if action_row.get_parent() != root:
		if action_row.get_parent() != null:
			action_row.get_parent().remove_child(action_row)
		action_row.owner = null
		root.add_child(action_row)
	action_row.z_index = 0
	action_row.anchor_left = 0.0
	action_row.anchor_right = 0.0
	action_row.anchor_top = 0.0
	action_row.anchor_bottom = 0.0
	action_row.offset_left = 0.0
	action_row.offset_right = 0.0
	action_row.offset_top = 0.0
	action_row.offset_bottom = 0.0


func _apply_settings_mobile_metrics(node: Node, context: Dictionary, portrait: bool) -> void:
	if node is Button:
		var button := node as Button
		if portrait:
			var button_height := _settings_portrait_footer_height(context) if button.name in ["BtnSave", "BtnTest", "BtnBack"] else float(context.get("secondary_button_height", 84.0))
			button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, button_height)
		elif button.name in ["BtnSave", "BtnTest", "BtnBack"]:
			button.custom_minimum_size.y = 40.0
		if portrait and button.name in ["BtnSave", "BtnTest", "BtnBack", "BtnUseZenMuxDefault", "BtnPasteApiKey", "BtnOpenZenMux"]:
			button.custom_minimum_size.x = 0.0
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif not portrait and button.name in ["BtnSave", "BtnTest", "BtnBack"]:
			button.custom_minimum_size.x = 140.0
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", int(context.get("button_font_size", 15)) if portrait else HudThemeScript.scaled_font_size(15))
		NonBattleTouchBridgeScript.bind_button_touch(button)
	elif node is LineEdit:
		var input := node as LineEdit
		input.custom_minimum_size.y = maxf(input.custom_minimum_size.y, float(context.get("input_height", 80.0))) if portrait else 35.0
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL if portrait else input.size_flags_horizontal
		input.add_theme_font_size_override("font_size", int(context.get("input_font_size", 15)) if portrait else HudThemeScript.scaled_font_size(15))
		_configure_settings_feedback_line_edit(input)
	elif node is SpinBox:
		var spin := node as SpinBox
		spin.custom_minimum_size.y = maxf(spin.custom_minimum_size.y, float(context.get("input_height", 80.0))) if portrait else 35.0
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL if portrait else spin.size_flags_horizontal
		spin.add_theme_font_size_override("font_size", int(context.get("input_font_size", 15)) if portrait else HudThemeScript.scaled_font_size(15))
	elif node is OptionButton:
		var option := node as OptionButton
		option.custom_minimum_size.y = maxf(option.custom_minimum_size.y, float(context.get("input_height", 80.0))) if portrait else 35.0
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL if portrait else option.size_flags_horizontal
		option.add_theme_font_size_override("font_size", int(context.get("input_font_size", 15)) if portrait else HudThemeScript.scaled_font_size(15))
	elif node is HBoxContainer:
		var row := node as HBoxContainer
		if portrait and row.name == "HBox":
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", int(context.get("section_gap", 14)))
	elif node is Label:
		var label := node as Label
		if label.name == "StatusLabel":
			_configure_status_label(label, context, portrait)
		elif label.name == "Title":
			label.add_theme_font_size_override("font_size", int(context.get("title_font_size", 34)) if portrait else HudThemeScript.scaled_font_size(34))
		elif portrait and label.name in ["SectionLabel", "ZenMuxGuideTitle", "ZenMuxTroubleTitle"]:
			label.add_theme_font_size_override("font_size", int(context.get("section_font_size", 29)))
			label.add_theme_constant_override("line_spacing", int(float(context.get("portrait_scale", 1.0)) * 5.0))
		elif portrait and label.name in ["EndpointHint", "ApiKeyHint", "ModelHint"]:
			label.add_theme_font_size_override("font_size", int(context.get("meta_font_size", 19)))
			label.add_theme_constant_override("line_spacing", int(float(context.get("portrait_scale", 1.0)) * 5.0))
		elif portrait and label.name in ["ZenMuxGuideBody", "ZenMuxTroubleBody"]:
			label.add_theme_font_size_override("font_size", int(context.get("body_font_size", 23)))
			label.add_theme_constant_override("line_spacing", int(float(context.get("portrait_scale", 1.0)) * 8.0))
		elif portrait:
			label.add_theme_font_size_override("font_size", int(context.get("body_font_size", 18)))
	for child: Node in node.get_children():
		_apply_settings_mobile_metrics(child, context, portrait)


func _apply_settings_copy() -> void:
	_set_label_text("Title", "AI 设置")
	_set_label_text("SectionLabel", "ZenMux 与 AI 性格")
	_set_label_text("EndpointLabel", "API 地址:")
	_set_label_text("ApiKeyLabel", "API 密钥:")
	_set_label_text("ModelLabel", "模型:")
	_set_label_text("TimeoutLabel", "请求超时 (秒):")
	_set_label_text("PersonalityLabel", "AI 性格:")
	var endpoint_input := _endpoint_input()
	if endpoint_input != null:
		endpoint_input.placeholder_text = ZENMUX_DEFAULT_ENDPOINT
	var api_key_input := _api_key_input()
	if api_key_input != null:
		api_key_input.placeholder_text = "粘贴 ZenMux 控制台里的 API Key"
	var paste_api_key_button := find_child("BtnPasteApiKey", true, false) as Button
	if paste_api_key_button != null:
		paste_api_key_button.text = "粘贴密钥"
	var personality_input := _personality_input()
	if personality_input != null:
		personality_input.placeholder_text = "可选，例如：稳健、简洁、会解释关键选择"
	var save_button := _settings_button("BtnSave")
	if save_button != null:
		save_button.text = "保存"
	var test_button := _settings_button("BtnTest")
	if test_button != null:
		test_button.text = "测试连接"
	var back_button := _settings_button("BtnBack")
	if back_button != null:
		back_button.text = "返回"


func _set_label_text(node_name: String, text: String) -> void:
	var label := find_child(node_name, true, false) as Label
	if label != null:
		label.text = text


func _endpoint_input() -> LineEdit:
	return get_node_or_null("%EndpointInput") as LineEdit


func _api_key_input() -> LineEdit:
	return get_node_or_null("%ApiKeyInput") as LineEdit


func _personality_input() -> LineEdit:
	return get_node_or_null("%PersonalityInput") as LineEdit


func _model_option() -> OptionButton:
	return get_node_or_null("%ModelOption") as OptionButton


func _timeout_input() -> SpinBox:
	return get_node_or_null("%TimeoutInput") as SpinBox


func _status_label() -> Label:
	return get_node_or_null("%StatusLabel") as Label


func _configure_status_label(label: Label, context: Dictionary = {}, portrait: bool = false) -> void:
	if label == null:
		return
	var has_message := label.text.strip_edges() != ""
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if has_message and portrait:
		label.custom_minimum_size = Vector2(0.0, maxf(88.0, float(context.get("secondary_button_height", 84.0)) * 0.72))
	elif has_message:
		label.custom_minimum_size = Vector2(0.0, 38.0)
	else:
		label.custom_minimum_size = Vector2.ZERO
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.max_lines_visible = 3 if portrait else 2
	label.add_theme_font_size_override("font_size", int(context.get("body_font_size", 18)) if portrait else HudThemeScript.scaled_font_size(15))
	label.add_theme_constant_override("line_spacing", int(float(context.get("portrait_scale", 1.0)) * 5.0) if portrait else 2)


func _set_status_message(message: String, color: Color) -> void:
	var label := _status_label()
	if label == null:
		return
	label.text = message
	label.add_theme_color_override("font_color", color)
	var portrait := str(get_meta("non_battle_layout_mode", "")) == "portrait"
	_configure_status_label(label, _current_non_battle_layout_context, portrait)
	_reveal_status_message(label)


func _reveal_status_message(label: Label) -> void:
	if label == null or label.text.strip_edges() == "":
		return
	if str(get_meta("non_battle_layout_mode", "")) != "portrait":
		return
	var scroll := find_child("PortraitSettingsScroll", true, false) as ScrollContainer
	if scroll == null or not scroll.visible:
		return
	var parent := label.get_parent()
	var target_scroll := 0
	if parent != null:
		var separation := 0
		if parent is BoxContainer:
			separation = (parent as BoxContainer).get_theme_constant("separation")
		for child: Node in parent.get_children():
			if child == label:
				break
			if child is Control:
				var control := child as Control
				if not control.visible:
					continue
				var control_height := maxf(control.size.y, control.custom_minimum_size.y)
				control_height = maxf(control_height, control.get_combined_minimum_size().y)
				target_scroll += roundi(control_height)
				target_scroll += separation
	target_scroll = maxi(1, target_scroll - 48)
	scroll.scroll_vertical = target_scroll
	scroll.set_deferred("scroll_vertical", target_scroll)


func _settings_button(button_name: String) -> Button:
	return get_node_or_null("%" + button_name) as Button


func _configure_settings_form_bounds() -> void:
	var form := get_node_or_null("VBoxContainer") as Control
	if form == null:
		return
	form.custom_minimum_size = Vector2(860, 560)
	form.offset_left = -430
	form.offset_top = -300
	form.offset_right = 430
	form.offset_bottom = 300


func _ensure_zenmux_setup_guide() -> void:
	var root := get_node_or_null("VBoxContainer") as VBoxContainer
	if root == null or root.get_node_or_null("ContentColumns") != null:
		return

	var content_columns := HBoxContainer.new()
	content_columns.name = "ContentColumns"
	content_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_columns.add_theme_constant_override("separation", 26)
	root.add_child(content_columns)
	content_columns.owner = self
	var section_label := root.get_node_or_null("SectionLabel") as Control
	if section_label != null:
		root.move_child(content_columns, section_label.get_index() + 1)

	var form_column := VBoxContainer.new()
	form_column.name = "FormColumn"
	form_column.custom_minimum_size = Vector2(420, 0)
	form_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form_column.add_theme_constant_override("separation", 8)
	content_columns.add_child(form_column)
	form_column.owner = self

	var guide_column := VBoxContainer.new()
	guide_column.name = "ZenMuxGuideColumn"
	guide_column.custom_minimum_size = Vector2(360, 0)
	guide_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guide_column.add_theme_constant_override("separation", 8)
	content_columns.add_child(guide_column)
	guide_column.owner = self

	_reparent_form_controls(root, form_column)
	_add_zenmux_guide_controls(guide_column)
	_set_runtime_owner(content_columns)


func _set_runtime_owner(node: Node) -> void:
	if node == null:
		return
	node.owner = self
	for child: Node in node.get_children():
		_set_runtime_owner(child)


func _reparent_form_controls(root: VBoxContainer, form_column: VBoxContainer) -> void:
	var control_names := [
		"EndpointLabel",
		"EndpointInput",
		"ApiKeyLabel",
		"ApiKeyInput",
		"ModelLabel",
		"ModelOption",
		"TimeoutLabel",
		"TimeoutInput",
		"PersonalityLabel",
		"PersonalityInput",
		"StatusLabel",
	]
	for control_name: String in control_names:
		var node := root.get_node_or_null(control_name)
		if node == null:
			continue
		node.owner = null
		root.remove_child(node)
		form_column.add_child(node)
		if node is Control:
			(node as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if control_name == "EndpointInput":
			form_column.add_child(_build_default_endpoint_row())
		elif control_name == "ApiKeyInput":
			form_column.add_child(_build_api_key_help_row())
		elif control_name == "ModelOption":
			form_column.add_child(_build_hint_label("ModelHint", "不确定模型就先保留默认；测试通过后才会启用大模型对手。"))


func _build_default_endpoint_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "EndpointHelpRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var button := Button.new()
	button.name = "BtnUseZenMuxDefault"
	button.unique_name_in_owner = true
	button.text = "填入 ZenMux 默认地址"
	button.custom_minimum_size = Vector2(168, 34)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(button)

	var hint := _build_hint_label("EndpointHint", "ZenMux 用户通常保持这个地址即可。")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)
	return row


func _build_api_key_help_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ApiKeyHelpRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var button := Button.new()
	button.name = "BtnPasteApiKey"
	button.unique_name_in_owner = true
	button.text = "粘贴密钥"
	button.custom_minimum_size = Vector2(132, 34)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(button)

	var hint := _build_hint_label("ApiKeyHint", "API Key 只保存在本机配置文件里；复制时不要带前后空格。")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)
	return row


func _build_hint_label(node_name: String, text: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _add_zenmux_guide_controls(guide_column: VBoxContainer) -> void:
	var guide_title := _build_hint_label("ZenMuxGuideTitle", "ZenMux 配置步骤")
	guide_column.add_child(guide_title)
	guide_column.add_child(_build_zenmux_link_button())
	var guide_body := _build_hint_label("ZenMuxGuideBody", ZENMUX_SETUP_GUIDE)
	guide_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guide_column.add_child(guide_body)
	var trouble_title := _build_hint_label("ZenMuxTroubleTitle", "常见问题")
	guide_column.add_child(trouble_title)
	var trouble_body := _build_hint_label("ZenMuxTroubleBody", ZENMUX_TROUBLESHOOTING)
	trouble_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guide_column.add_child(trouble_body)


func _build_zenmux_link_button() -> Button:
	var button := Button.new()
	button.name = "BtnOpenZenMux"
	button.unique_name_in_owner = true
	button.text = "打开 zenmux.ai"
	button.custom_minimum_size = Vector2(180, 38)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.set_meta("external_url", ZENMUX_HOME_URL)
	return button


func _apply_hud_theme() -> void:
	_apply_settings_copy()
	_ensure_zenmux_setup_guide()
	_configure_settings_form_bounds()
	var shade := get_node_or_null("BackgroundShade") as ColorRect
	if shade != null:
		shade.color = Color(0.01, 0.025, 0.045, 0.18)
	_ensure_hud_frame()
	_apply_hud_theme_recursive(self)
	_sync_hud_frame_to_form()
	_connect_settings_controls()


func _connect_settings_controls() -> void:
	var save_button := _settings_button("BtnSave")
	if save_button != null and not save_button.pressed.is_connected(_on_save):
		save_button.pressed.connect(_on_save)
	var test_button := _settings_button("BtnTest")
	if test_button != null and not test_button.pressed.is_connected(_on_test_connection):
		test_button.pressed.connect(_on_test_connection)
	var default_endpoint_button := find_child("BtnUseZenMuxDefault", true, false) as Button
	if default_endpoint_button != null and not default_endpoint_button.pressed.is_connected(_on_use_zenmux_default_endpoint):
		default_endpoint_button.pressed.connect(_on_use_zenmux_default_endpoint)
	var paste_api_key_button := find_child("BtnPasteApiKey", true, false) as Button
	if paste_api_key_button != null:
		if not paste_api_key_button.pressed.is_connected(_on_paste_api_key_pressed):
			paste_api_key_button.pressed.connect(_on_paste_api_key_pressed)
		NonBattleTouchBridgeScript.bind_button_touch(paste_api_key_button)
	var open_zenmux_button := find_child("BtnOpenZenMux", true, false) as Button
	if open_zenmux_button != null and not open_zenmux_button.pressed.is_connected(_on_open_zenmux_pressed):
		open_zenmux_button.pressed.connect(_on_open_zenmux_pressed)
	var back_button := _settings_button("BtnBack")
	if back_button != null and not back_button.pressed.is_connected(_on_back):
		back_button.pressed.connect(_on_back)
	var model_option := _model_option()
	if model_option != null:
		model_option.set_meta("_non_battle_option_press_signal_only", true)
		if not model_option.pressed.is_connected(_on_model_option_pressed):
			model_option.pressed.connect(_on_model_option_pressed)
		var model_input_callback := Callable(self, "_on_model_option_gui_input")
		if not model_option.gui_input.is_connected(model_input_callback):
			model_option.gui_input.connect(model_input_callback)


func _ensure_hud_frame() -> void:
	if get_node_or_null("HudFrame") != null:
		return
	var vbox := get_node_or_null("VBoxContainer") as Control
	if vbox == null:
		return
	var frame := PanelContainer.new()
	frame.name = "HudFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.layout_mode = vbox.layout_mode
	frame.anchors_preset = vbox.anchors_preset
	frame.anchor_left = vbox.anchor_left
	frame.anchor_top = vbox.anchor_top
	frame.anchor_right = vbox.anchor_right
	frame.anchor_bottom = vbox.anchor_bottom
	frame.offset_left = vbox.offset_left - 26
	frame.offset_top = vbox.offset_top - 24
	frame.offset_right = vbox.offset_right + 26
	frame.offset_bottom = vbox.offset_bottom + 24
	frame.grow_horizontal = vbox.grow_horizontal
	frame.grow_vertical = vbox.grow_vertical
	frame.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.025, 0.055, 0.085, 0.78), Color(0.30, 0.86, 1.0, 0.86), 24))
	add_child(frame)
	move_child(frame, vbox.get_index())


func _sync_hud_frame_to_form() -> void:
	var frame := get_node_or_null("HudFrame") as PanelContainer
	var vbox := get_node_or_null("VBoxContainer") as Control
	if frame == null or vbox == null:
		return
	var portrait := str(get_meta("non_battle_layout_mode", "")) == "portrait"
	var side_pad := 14.0 if portrait else 30.0
	var top_pad := 14.0 if portrait else 28.0
	var bottom_pad := 18.0 if portrait else 58.0
	frame.offset_left = vbox.offset_left - side_pad
	frame.offset_top = vbox.offset_top - top_pad
	frame.offset_right = vbox.offset_right + side_pad
	frame.offset_bottom = vbox.offset_bottom + bottom_pad


func _apply_hud_theme_recursive(node: Node) -> void:
	if node is ScrollContainer:
		HudThemeScript.style_scroll_container(node as ScrollContainer)
	elif node is Button:
		var accent := HUD_ACCENT_WARM if node.name == "BtnSave" else HUD_ACCENT
		_style_hud_button(node as Button, accent)
	elif node is OptionButton:
		_style_hud_option(node as OptionButton)
	elif node is LineEdit:
		_style_hud_line_edit(node as LineEdit)
	elif node is SpinBox:
		_style_hud_spin_box(node as SpinBox)
	elif node is Label:
		_style_hud_label(node as Label)
	elif node is Control:
		HudThemeScript.style_scrollable_control(node as Control)
	for child: Node in node.get_children():
		_apply_hud_theme_recursive(child)


func _style_hud_label(label: Label) -> void:
	if label.name == "Title":
		label.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(34))
		label.add_theme_color_override("font_color", HUD_TEXT)
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.82, 1.0, 0.72))
		label.add_theme_constant_override("shadow_offset_y", 2)
		return
	if label.name == "SectionLabel":
		label.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(18))
		label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.50, 1.0))
		return
	if label.name in ["ZenMuxGuideTitle", "ZenMuxTroubleTitle"]:
		label.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(17))
		label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.50, 1.0))
		return
	if label.name in ["ZenMuxGuideBody", "ZenMuxTroubleBody"]:
		label.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(14))
		label.add_theme_color_override("font_color", HUD_TEXT)
		label.add_theme_constant_override("line_spacing", 3)
		return
	if label.name in ["EndpointHint", "ApiKeyHint", "ModelHint"]:
		label.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(12))
		label.add_theme_color_override("font_color", HUD_TEXT_MUTED)
		label.add_theme_constant_override("line_spacing", 2)
		return
	label.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(14))
	label.add_theme_color_override("font_color", HUD_TEXT_MUTED)


func _style_hud_button(button: Button, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(15))
	button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.08, 0.12, 0.16, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.44, 0.50, 0.56, 1.0))
	button.add_theme_stylebox_override("normal", _hud_button_style(accent, false, false))
	button.add_theme_stylebox_override("hover", _hud_button_style(accent, true, false))
	button.add_theme_stylebox_override("pressed", _hud_button_style(accent, true, true))
	button.add_theme_stylebox_override("disabled", _hud_button_style(Color(0.26, 0.31, 0.36, 1.0), false, false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style_hud_option(option: OptionButton) -> void:
	option.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(15))
	option.add_theme_color_override("font_color", HUD_TEXT)
	option.add_theme_color_override("font_hover_color", Color.WHITE)
	option.add_theme_color_override("font_disabled_color", Color(0.44, 0.50, 0.56, 1.0))
	option.add_theme_stylebox_override("normal", _hud_input_style(false))
	option.add_theme_stylebox_override("hover", _hud_input_style(true))
	option.add_theme_stylebox_override("pressed", _hud_input_style(true))
	option.add_theme_stylebox_override("disabled", _hud_input_disabled_style())
	option.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style_hud_line_edit(input: LineEdit) -> void:
	_configure_settings_feedback_line_edit(input)
	input.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(15))
	input.add_theme_color_override("font_color", HUD_TEXT)
	input.add_theme_color_override("font_placeholder_color", Color(0.55, 0.66, 0.74, 0.78))
	input.add_theme_color_override("caret_color", HUD_ACCENT)
	input.add_theme_stylebox_override("normal", _hud_input_style(false))
	input.add_theme_stylebox_override("focus", _hud_input_style(true))
	input.add_theme_stylebox_override("read_only", _hud_input_disabled_style())


func _configure_settings_feedback_line_edit(input: LineEdit) -> void:
	if input == null:
		return
	var keyboard_type := LineEdit.KEYBOARD_TYPE_URL if input.name == "EndpointInput" else LineEdit.KEYBOARD_TYPE_DEFAULT
	input.focus_mode = Control.FOCUS_ALL
	input.mouse_filter = Control.MOUSE_FILTER_STOP
	input.context_menu_enabled = true
	input.virtual_keyboard_enabled = true
	input.virtual_keyboard_show_on_focus = true
	input.virtual_keyboard_type = keyboard_type
	input.set("shortcut_keys_enabled", true)
	input.set("middle_mouse_paste_enabled", true)
	if input.has_meta(NonBattleTouchBridgeScript.NATIVE_TEXT_INPUT_META):
		input.remove_meta(NonBattleTouchBridgeScript.NATIVE_TEXT_INPUT_META)
	NonBattleTouchBridgeScript.bind_focus_control_touch(input)
	if input.name == "ApiKeyInput":
		_bind_api_key_select_all(input)


func _bind_api_key_select_all(input: LineEdit) -> void:
	if input == null or bool(input.get_meta(API_KEY_SELECT_ALL_BOUND_META, false)):
		return
	input.set_meta(API_KEY_SELECT_ALL_BOUND_META, true)
	input.focus_entered.connect(func() -> void:
		_select_all_api_key_input(input)
	)
	input.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed:
				_select_all_api_key_input(input)
		elif event is InputEventMouseButton:
			var mouse_button := event as InputEventMouseButton
			if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
				_select_all_api_key_input(input)
	)


func _select_all_api_key_input(input: LineEdit) -> void:
	if input == null:
		return
	input.set_meta(API_KEY_SELECTED_ALL_META, true)
	if input.text.length() <= 0:
		return
	input.select_all()
	input.call_deferred("select_all")


func _style_hud_spin_box(spin_box: SpinBox) -> void:
	spin_box.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(15))
	spin_box.add_theme_color_override("font_color", HUD_TEXT)
	spin_box.add_theme_stylebox_override("normal", _hud_input_style(false))
	spin_box.add_theme_stylebox_override("focus", _hud_input_style(true))


func _hud_panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(border.r, border.g, border.b, 0.22)
	style.shadow_size = 12
	style.set_content_margin_all(12)
	return style


func _hud_button_style(accent: Color, hover: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.92) if pressed else Color(0.035, 0.075, 0.105, 0.92)
	if hover and not pressed:
		style.bg_color = Color(0.055, 0.13, 0.17, 0.96)
	style.border_color = accent
	style.set_border_width_all(2 if hover else 1)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.28 if hover else 0.12)
	style.shadow_size = 8 if hover else 3
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _hud_input_style(hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.035, 0.055, 0.88)
	if hover:
		style.bg_color = Color(0.025, 0.075, 0.105, 0.94)
	style.border_color = Color(0.23, 0.78, 1.0, 0.70 if hover else 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _hud_input_disabled_style() -> StyleBoxFlat:
	var style := _hud_input_style(false)
	style.bg_color = Color(0.02, 0.025, 0.03, 0.66)
	style.border_color = Color(0.18, 0.22, 0.26, 0.50)
	return style


func _should_use_settings_model_picker() -> bool:
	return str(get_meta("non_battle_layout_mode", "")) == "portrait" or _is_mobile_like_runtime()


func _on_model_option_pressed() -> void:
	if not _should_use_settings_model_picker():
		return
	_hide_model_option_native_popup()
	_show_settings_model_picker()


func _on_model_option_gui_input(event: InputEvent) -> void:
	if not _should_use_settings_model_picker():
		return
	var model_option := _model_option()
	if model_option == null:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		model_option.accept_event()
		_accept_pointer_event()
		_hide_model_option_native_popup()
		if not touch.pressed:
			_show_settings_model_picker()
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if not _is_mobile_like_runtime() and str(get_meta("non_battle_layout_mode", "")) != "portrait":
			return
		model_option.accept_event()
		_accept_pointer_event()
		_hide_model_option_native_popup()
		if not mouse_button.pressed:
			_show_settings_model_picker()


func _handle_settings_model_picker_input(event: InputEvent) -> bool:
	if _model_picker_overlay == null or not is_instance_valid(_model_picker_overlay) or not _model_picker_overlay.visible:
		return false
	if NonBattleTouchBridgeScript.handle_root_touch(_model_picker_overlay, event):
		return true
	if event is InputEventScreenTouch:
		_accept_pointer_event()
		return true
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_accept_pointer_event()
		return true
	return false


func _show_settings_model_picker() -> void:
	var model_option := _model_option()
	if model_option == null or model_option.disabled or model_option.get_item_count() <= 0:
		return
	_ensure_settings_model_picker_overlay()
	_refresh_settings_model_picker_layout()
	_populate_settings_model_picker()
	_model_picker_overlay.visible = true
	_model_picker_overlay.move_to_front()


func _hide_settings_model_picker() -> void:
	if _model_picker_overlay != null and is_instance_valid(_model_picker_overlay):
		_model_picker_overlay.visible = false


func _hide_model_option_native_popup() -> void:
	var model_option := _model_option()
	if model_option == null:
		return
	var popup := model_option.get_popup()
	if popup != null:
		popup.hide()


func _ensure_settings_model_picker_overlay() -> void:
	if _model_picker_overlay != null and is_instance_valid(_model_picker_overlay):
		return
	_model_picker_overlay = Control.new()
	_model_picker_overlay.name = MODEL_PICKER_OVERLAY_NAME
	_model_picker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_model_picker_overlay.visible = false
	_model_picker_overlay.z_index = 2450
	_model_picker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_model_picker_overlay)

	var shade := ColorRect.new()
	shade.name = "AISettingsModelPickerShade"
	shade.color = Color(0.0, 0.0, 0.0, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_model_picker_overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "AISettingsModelPickerPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.025, 0.055, 0.085, 0.96), HUD_ACCENT, 22))
	_model_picker_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "AISettingsModelPickerMargin"
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.name = "AISettingsModelPickerRoot"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	var title := Label.new()
	title.name = "AISettingsModelPickerTitle"
	title.text = "选择 AI 模型"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", HUD_TEXT)
	root.add_child(title)

	_model_picker_scroll = ScrollContainer.new()
	_model_picker_scroll.name = "AISettingsModelPickerScroll"
	_model_picker_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_model_picker_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_model_picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_model_picker_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	HudThemeScript.style_scroll_container(_model_picker_scroll, "auto")
	NonBattleTouchBridgeScript.configure_hidden_vertical_drag_scroll(_model_picker_scroll)
	root.add_child(_model_picker_scroll)

	_model_picker_list = VBoxContainer.new()
	_model_picker_list.name = "AISettingsModelPickerList"
	_model_picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_model_picker_list.add_theme_constant_override("separation", 14)
	_model_picker_scroll.add_child(_model_picker_list)

	var close_button := Button.new()
	close_button.name = "AISettingsModelPickerCloseButton"
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(0.0, 150.0)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_hud_button(close_button, HUD_ACCENT)
	close_button.add_theme_font_size_override("font_size", 48)
	close_button.pressed.connect(_hide_settings_model_picker)
	NonBattleTouchBridgeScript.bind_button_touch(close_button)
	root.add_child(close_button)
	_set_runtime_owner(_model_picker_overlay)


func _refresh_settings_model_picker_layout() -> void:
	if _model_picker_overlay == null or not is_instance_valid(_model_picker_overlay):
		return
	var viewport_size: Vector2 = _current_non_battle_layout_context.get("viewport_size", size if size.x > 0.0 and size.y > 0.0 else Vector2(1080, 2400))
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1080, 2400)
	var panel := _model_picker_overlay.get_node_or_null("AISettingsModelPickerPanel") as PanelContainer
	if panel != null:
		var margin := roundi(clampf(viewport_size.x * 0.035, 28.0, 46.0))
		panel.offset_left = margin
		panel.offset_top = margin
		panel.offset_right = -margin
		panel.offset_bottom = -margin
		panel.custom_minimum_size = Vector2(maxf(320.0, viewport_size.x - margin * 2.0), maxf(560.0, viewport_size.y - margin * 2.0))
	if _model_picker_scroll != null:
		_model_picker_scroll.custom_minimum_size.y = maxf(900.0, viewport_size.y * 0.58)
		HudThemeScript.style_scroll_container(_model_picker_scroll, "auto")
		NonBattleTouchBridgeScript.configure_hidden_vertical_drag_scroll(_model_picker_scroll)


func _populate_settings_model_picker() -> void:
	var model_option := _model_option()
	if _model_picker_list == null or model_option == null:
		return
	for child: Node in _model_picker_list.get_children():
		child.queue_free()
	var selected_index := model_option.selected
	for i: int in model_option.get_item_count():
		var button := Button.new()
		button.name = "AISettingsModelPickerItem%d" % i
		button.text = "%s%s" % ["[当前] " if i == selected_index else "", model_option.get_item_text(i)]
		button.custom_minimum_size = Vector2(0.0, 148.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		_style_hud_button(button, HUD_ACCENT)
		button.add_theme_font_size_override("font_size", 46)
		button.pressed.connect(_select_settings_model_from_picker.bind(i))
		NonBattleTouchBridgeScript.bind_button_touch(button)
		_model_picker_list.add_child(button)
	_set_runtime_owner(_model_picker_list)


func _select_settings_model_from_picker(index: int) -> void:
	var model_option := _model_option()
	if model_option == null or index < 0 or index >= model_option.get_item_count():
		_hide_settings_model_picker()
		return
	model_option.select(index)
	_hide_model_option_native_popup()
	_hide_settings_model_picker()


func _populate_model_options() -> void:
	var model_option := _model_option()
	if model_option == null:
		return
	model_option.clear()
	for model: Dictionary in GameManager.get_supported_battle_review_models():
		var index: int = model_option.get_item_count()
		model_option.add_item(str(model.get("label", model.get("id", ""))))
		model_option.set_item_metadata(index, str(model.get("id", "")))
	if _model_picker_overlay != null and is_instance_valid(_model_picker_overlay) and _model_picker_overlay.visible:
		_populate_settings_model_picker()


func _load_config() -> void:
	var config := GameManager.get_battle_review_api_config()
	var endpoint := _settings_config_text(config.get("endpoint", ZENMUX_DEFAULT_ENDPOINT), ZENMUX_DEFAULT_ENDPOINT)
	var endpoint_input := _endpoint_input()
	if endpoint_input != null:
		endpoint_input.text = endpoint
	var api_key_input := _api_key_input()
	if api_key_input != null:
		api_key_input.text = _settings_config_text(config.get("api_key", ""), "")
	_select_model(str(config.get("model", "")))
	var timeout_input := _timeout_input()
	if timeout_input != null:
		timeout_input.value = float(config.get("timeout_seconds", 30.0))
	var personality_input := _personality_input()
	if personality_input != null:
		personality_input.text = _settings_config_text(config.get("ai_personality", GameManager.DEFAULT_AI_PERSONALITY), GameManager.DEFAULT_AI_PERSONALITY)
	var status_label := _status_label()
	if status_label != null:
		status_label.text = ""


func _settings_config_text(value: Variant, fallback: String) -> String:
	if value == null:
		return fallback
	var text := str(value).strip_edges()
	if text == "" or _settings_text_has_null_instance_diagnostic(text):
		return fallback
	return text


func _settings_text_has_null_instance_diagnostic(text: String) -> bool:
	var lower := text.to_lower()
	return lower.contains("instance base is null") or lower.contains("instance is null") or lower.contains("null instance")


func _select_model(model_id: String) -> void:
	var model_option := _model_option()
	if model_option == null:
		return
	var normalized := GameManager.normalize_battle_review_model(model_id)
	for index: int in model_option.get_item_count():
		if str(model_option.get_item_metadata(index)) == normalized:
			model_option.select(index)
			return
	if model_option.get_item_count() > 0:
		model_option.select(0)


func _selected_model_id() -> String:
	var model_option := _model_option()
	if model_option == null:
		return GameManager.normalize_battle_review_model("")
	var selected_index: int = model_option.selected
	if selected_index < 0:
		return GameManager.normalize_battle_review_model("")
	return GameManager.normalize_battle_review_model(str(model_option.get_item_metadata(selected_index)))


func _on_use_zenmux_default_endpoint() -> void:
	var endpoint_input := _endpoint_input()
	if endpoint_input == null:
		_set_ai_settings_inputs_unavailable_status("填写默认地址")
		return
	endpoint_input.text = ZENMUX_DEFAULT_ENDPOINT
	_set_status_message("已填入 ZenMux 默认 API 地址，请继续粘贴 API Key 并测试连接。", Color(0.3, 1, 0.3))


func _on_paste_api_key_pressed() -> void:
	var clipboard_text := ""
	if DisplayServer.get_name() != "headless":
		clipboard_text = DisplayServer.clipboard_get()
	_apply_api_key_paste_text(clipboard_text)


func _apply_api_key_paste_text_for_tests(text: String) -> bool:
	return _apply_api_key_paste_text(text)


func _apply_api_key_paste_text(text: String) -> bool:
	var api_key_input := _api_key_input()
	if api_key_input == null:
		_set_ai_settings_inputs_unavailable_status("粘贴密钥")
		return false
	var api_key := text.strip_edges()
	if api_key == "":
		_set_status_message("剪贴板为空，请先复制 ZenMux API Key。", Color(1, 0.35, 0.25))
		return false
	api_key_input.text = api_key
	if api_key_input.is_inside_tree():
		api_key_input.focus_mode = Control.FOCUS_ALL
		api_key_input.grab_focus()
	_select_all_api_key_input(api_key_input)
	_set_status_message("已粘贴 API Key，请测试连接。", Color(0.3, 1, 0.3))
	return true


func _on_open_zenmux_pressed() -> void:
	var err := OS.shell_open(ZENMUX_HOME_URL)
	if err == OK:
		_set_status_message("已打开 zenmux.ai，请在浏览器注册或复制 API Key。", Color(0.3, 1, 0.3))
		return
	_set_status_message("无法自动打开浏览器，请手动访问 https://zenmux.ai。", Color(1, 0.35, 0.25))


func _on_save() -> void:
	if not _are_core_ai_settings_inputs_available():
		_set_ai_settings_inputs_unavailable_status("保存")
		return
	var data := _current_config_data()
	var existing := GameManager.get_battle_review_api_config()
	var signature := GameManager.battle_review_ai_config_signature(data)
	data["ai_test_passed"] = bool(existing.get("ai_test_passed", false)) and str(existing.get("ai_test_signature", "")) == signature
	data["ai_test_signature"] = signature if bool(data.get("ai_test_passed", false)) else ""
	_write_config_data(data, "已保存")


func _current_config_data() -> Dictionary:
	var existing := GameManager.get_battle_review_api_config()
	var endpoint_input := _endpoint_input()
	var api_key_input := _api_key_input()
	var timeout_input := _timeout_input()
	var personality_input := _personality_input()
	return {
		"endpoint": _settings_input_text(endpoint_input, str(existing.get("endpoint", ZENMUX_DEFAULT_ENDPOINT))),
		"api_key": _settings_input_text(api_key_input, str(existing.get("api_key", ""))),
		"model": _selected_model_id(),
		"timeout_seconds": timeout_input.value if timeout_input != null else float(existing.get("timeout_seconds", 60.0)),
		"ai_personality": _settings_input_text(personality_input, str(existing.get("ai_personality", GameManager.DEFAULT_AI_PERSONALITY))),
	}


func _settings_input_text(input: LineEdit, fallback: String) -> String:
	if input == null:
		return _settings_config_text(fallback, "")
	var text := input.text.strip_edges()
	if _settings_text_has_null_instance_diagnostic(text):
		return _settings_config_text(fallback, "")
	return text


func _are_core_ai_settings_inputs_available() -> bool:
	return _endpoint_input() != null and _api_key_input() != null


func _set_ai_settings_inputs_unavailable_status(action_name: String) -> void:
	_set_status_message("%s失败：AI 设置输入框还在初始化，请重新进入设置页。" % action_name, Color(1, 0.35, 0.25))


func _write_config_data(data: Dictionary, success_message: String) -> bool:
	var path := GameManager.get_battle_review_api_config_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_set_status_message("保存失败：无法写入配置文件", Color(1, 0.3, 0.3))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_set_status_message(success_message, Color(0.3, 1, 0.3))
	return true


func _on_test_connection() -> void:
	var test_button := _settings_button("BtnTest")
	var endpoint_input := _endpoint_input()
	var api_key_input := _api_key_input()
	var timeout_input := _timeout_input()
	if endpoint_input == null or api_key_input == null:
		_set_ai_settings_inputs_unavailable_status("测试")
		return
	var endpoint: String = endpoint_input.text.strip_edges()
	var api_key: String = api_key_input.text.strip_edges()
	if endpoint == "" or api_key == "":
		_set_status_message("测试失败：请先填写 API 地址和密钥", Color(1, 0.35, 0.25))
		return

	if test_button != null:
		test_button.disabled = true
	_set_status_message("正在测试...", Color(1, 0.85, 0.35))
	_test_client.set_timeout_seconds(float(timeout_input.value) if timeout_input != null else 60.0)
	var error := _test_client.request_json(
		self,
		endpoint,
		api_key,
		{
			"model": _selected_model_id(),
			"messages": [{
				"role": "system",
				"content": "Return exactly one JSON object and nothing else.",
			}, {
				"role": "user",
				"content": "Return exactly {\"ok\":true}.",
			}],
			"max_tokens": 80,
		},
		_on_test_connection_response
	)
	if error != OK:
		if test_button != null:
			test_button.disabled = false
		_set_status_message("测试失败：请求无法启动 (%d)" % error, Color(1, 0.35, 0.25))


func _on_test_connection_response(response: Dictionary) -> void:
	var test_button := _settings_button("BtnTest")
	if test_button != null:
		test_button.disabled = false
	if str(response.get("status", "")) == "error":
		_set_status_message("测试失败：%s" % str(response.get("message", "未知错误")).left(120), Color(1, 0.35, 0.25))
		return
	if bool(response.get("ok", false)):
		if not _are_core_ai_settings_inputs_available():
			_set_ai_settings_inputs_unavailable_status("保存测试结果")
			return
		var data := _current_config_data()
		data["ai_test_passed"] = true
		data["ai_test_signature"] = GameManager.battle_review_ai_config_signature(data)
		_write_config_data(data, "测试通过：模型可用，已保存")
		return
	_set_status_message("测试失败：模型返回格式不符合预期", Color(1, 0.35, 0.25))


func _on_back() -> void:
	GameManager.goto_main_menu()
