## AI 设置页面 - ZenMux 与 AI 性格配置
extends Control

const ZenMuxClientScript := preload("res://scripts/network/ZenMuxClient.gd")
const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const HUD_ACCENT := Color(0.28, 0.92, 1.0, 1.0)
const HUD_ACCENT_WARM := Color(1.0, 0.55, 0.24, 1.0)
const HUD_TEXT := Color(0.92, 0.98, 1.0, 1.0)
const HUD_TEXT_MUTED := Color(0.64, 0.76, 0.86, 1.0)
const ZENMUX_HOME_URL := "https://zenmux.ai"
const ZENMUX_DEFAULT_ENDPOINT := "https://zenmux.ai/api/v1"
const ZENMUX_SETUP_GUIDE := "1. 在浏览器打开 zenmux.ai，注册或登录账号。\n2. 进入控制台/API Keys，新建一个 API Key。\n3. 回到这里，API 地址保持 https://zenmux.ai/api/v1。\n4. 把 API Key 粘贴到“API 密钥”，选择模型；不确定就用默认模型。\n5. 点“测试连接”。提示测试通过后，回到开始对战选择大模型 AI。"
const ZENMUX_TROUBLESHOOTING := "测试失败时先看这里：\n- 鉴权失败/401：API Key 复制错、少复制字符，或 Key 已失效。\n- model not found：当前 Key 不能用这个模型，换一个模型再测。\n- timeout/请求超时：网络慢，把超时改成 90 或 120 秒再试。"

var _test_client = ZenMuxClientScript.new()


func _ready() -> void:
	_apply_settings_copy()
	_ensure_zenmux_setup_guide()
	_configure_settings_form_bounds()
	_apply_hud_theme()
	_connect_settings_controls()
	_populate_model_options()
	_load_config()


func _apply_settings_copy() -> void:
	_set_label_text("Title", "AI 设置")
	_set_label_text("SectionLabel", "ZenMux 与 AI 性格")
	_set_label_text("EndpointLabel", "API 地址:")
	_set_label_text("ApiKeyLabel", "API 密钥:")
	_set_label_text("ModelLabel", "模型:")
	_set_label_text("TimeoutLabel", "请求超时 (秒):")
	_set_label_text("PersonalityLabel", "AI 性格:")
	%EndpointInput.placeholder_text = ZENMUX_DEFAULT_ENDPOINT
	%ApiKeyInput.placeholder_text = "粘贴 ZenMux 控制台里的 API Key"
	%PersonalityInput.placeholder_text = "可选，例如：稳健、简洁、会解释关键选择"
	%BtnSave.text = "保存"
	%BtnTest.text = "测试连接"
	%BtnBack.text = "返回"


func _set_label_text(node_name: String, text: String) -> void:
	var label := find_child(node_name, true, false) as Label
	if label != null:
		label.text = text


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
			form_column.add_child(_build_hint_label("ApiKeyHint", "API Key 只保存在本机配置文件里；复制时不要带前后空格。"))
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
	if not %BtnSave.pressed.is_connected(_on_save):
		%BtnSave.pressed.connect(_on_save)
	if not %BtnTest.pressed.is_connected(_on_test_connection):
		%BtnTest.pressed.connect(_on_test_connection)
	var default_endpoint_button := find_child("BtnUseZenMuxDefault", true, false) as Button
	if default_endpoint_button != null and not default_endpoint_button.pressed.is_connected(_on_use_zenmux_default_endpoint):
		default_endpoint_button.pressed.connect(_on_use_zenmux_default_endpoint)
	var open_zenmux_button := find_child("BtnOpenZenMux", true, false) as Button
	if open_zenmux_button != null and not open_zenmux_button.pressed.is_connected(_on_open_zenmux_pressed):
		open_zenmux_button.pressed.connect(_on_open_zenmux_pressed)
	if not %BtnBack.pressed.is_connected(_on_back):
		%BtnBack.pressed.connect(_on_back)


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
	frame.offset_left = vbox.offset_left - 30
	frame.offset_top = vbox.offset_top - 28
	frame.offset_right = vbox.offset_right + 30
	frame.offset_bottom = vbox.offset_bottom + 58


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
		label.add_theme_font_size_override("font_size", 34)
		label.add_theme_color_override("font_color", HUD_TEXT)
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.82, 1.0, 0.72))
		label.add_theme_constant_override("shadow_offset_y", 2)
		return
	if label.name == "SectionLabel":
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.50, 1.0))
		return
	if label.name in ["ZenMuxGuideTitle", "ZenMuxTroubleTitle"]:
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.50, 1.0))
		return
	if label.name in ["ZenMuxGuideBody", "ZenMuxTroubleBody"]:
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", HUD_TEXT)
		label.add_theme_constant_override("line_spacing", 3)
		return
	if label.name in ["EndpointHint", "ApiKeyHint", "ModelHint"]:
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", HUD_TEXT_MUTED)
		label.add_theme_constant_override("line_spacing", 2)
		return
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", HUD_TEXT_MUTED)


func _style_hud_button(button: Button, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", 15)
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
	option.add_theme_font_size_override("font_size", 15)
	option.add_theme_color_override("font_color", HUD_TEXT)
	option.add_theme_color_override("font_hover_color", Color.WHITE)
	option.add_theme_color_override("font_disabled_color", Color(0.44, 0.50, 0.56, 1.0))
	option.add_theme_stylebox_override("normal", _hud_input_style(false))
	option.add_theme_stylebox_override("hover", _hud_input_style(true))
	option.add_theme_stylebox_override("pressed", _hud_input_style(true))
	option.add_theme_stylebox_override("disabled", _hud_input_disabled_style())
	option.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style_hud_line_edit(input: LineEdit) -> void:
	input.add_theme_font_size_override("font_size", 15)
	input.add_theme_color_override("font_color", HUD_TEXT)
	input.add_theme_color_override("font_placeholder_color", Color(0.55, 0.66, 0.74, 0.78))
	input.add_theme_color_override("caret_color", HUD_ACCENT)
	input.add_theme_stylebox_override("normal", _hud_input_style(false))
	input.add_theme_stylebox_override("focus", _hud_input_style(true))
	input.add_theme_stylebox_override("read_only", _hud_input_disabled_style())


func _style_hud_spin_box(spin_box: SpinBox) -> void:
	spin_box.add_theme_font_size_override("font_size", 15)
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


func _populate_model_options() -> void:
	%ModelOption.clear()
	for model: Dictionary in GameManager.get_supported_battle_review_models():
		var index: int = %ModelOption.get_item_count()
		%ModelOption.add_item(str(model.get("label", model.get("id", ""))))
		%ModelOption.set_item_metadata(index, str(model.get("id", "")))


func _load_config() -> void:
	var config := GameManager.get_battle_review_api_config()
	var endpoint := str(config.get("endpoint", ZENMUX_DEFAULT_ENDPOINT)).strip_edges()
	%EndpointInput.text = ZENMUX_DEFAULT_ENDPOINT if endpoint == "" else endpoint
	%ApiKeyInput.text = str(config.get("api_key", ""))
	_select_model(str(config.get("model", "")))
	%TimeoutInput.value = float(config.get("timeout_seconds", 30.0))
	%PersonalityInput.text = str(config.get("ai_personality", ""))
	%StatusLabel.text = ""


func _select_model(model_id: String) -> void:
	var normalized := GameManager.normalize_battle_review_model(model_id)
	for index: int in %ModelOption.get_item_count():
		if str(%ModelOption.get_item_metadata(index)) == normalized:
			%ModelOption.select(index)
			return
	if %ModelOption.get_item_count() > 0:
		%ModelOption.select(0)


func _selected_model_id() -> String:
	var selected_index: int = %ModelOption.selected
	if selected_index < 0:
		return GameManager.normalize_battle_review_model("")
	return GameManager.normalize_battle_review_model(str(%ModelOption.get_item_metadata(selected_index)))


func _on_use_zenmux_default_endpoint() -> void:
	%EndpointInput.text = ZENMUX_DEFAULT_ENDPOINT
	%StatusLabel.text = "已填入 ZenMux 默认 API 地址，请继续粘贴 API Key 并测试连接。"
	%StatusLabel.add_theme_color_override("font_color", Color(0.3, 1, 0.3))


func _on_open_zenmux_pressed() -> void:
	var err := OS.shell_open(ZENMUX_HOME_URL)
	if err == OK:
		%StatusLabel.text = "已打开 zenmux.ai，请在浏览器注册或复制 API Key。"
		%StatusLabel.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
		return
	%StatusLabel.text = "无法自动打开浏览器，请手动访问 https://zenmux.ai。"
	%StatusLabel.add_theme_color_override("font_color", Color(1, 0.35, 0.25))


func _on_save() -> void:
	var data := _current_config_data()
	var existing := GameManager.get_battle_review_api_config()
	var signature := GameManager.battle_review_ai_config_signature(data)
	data["ai_test_passed"] = bool(existing.get("ai_test_passed", false)) and str(existing.get("ai_test_signature", "")) == signature
	data["ai_test_signature"] = signature if bool(data.get("ai_test_passed", false)) else ""
	_write_config_data(data, "已保存")


func _current_config_data() -> Dictionary:
	return {
		"endpoint": %EndpointInput.text.strip_edges(),
		"api_key": %ApiKeyInput.text.strip_edges(),
		"model": _selected_model_id(),
		"timeout_seconds": %TimeoutInput.value,
		"ai_personality": %PersonalityInput.text.strip_edges(),
	}


func _write_config_data(data: Dictionary, success_message: String) -> bool:
	var path := GameManager.get_battle_review_api_config_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		%StatusLabel.text = "保存失败：无法写入配置文件"
		%StatusLabel.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	%StatusLabel.text = success_message
	%StatusLabel.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	return true


func _on_test_connection() -> void:
	var endpoint: String = %EndpointInput.text.strip_edges()
	var api_key: String = %ApiKeyInput.text.strip_edges()
	if endpoint == "" or api_key == "":
		%StatusLabel.text = "测试失败：请先填写 API 地址和密钥"
		%StatusLabel.add_theme_color_override("font_color", Color(1, 0.35, 0.25))
		return

	%BtnTest.disabled = true
	%StatusLabel.text = "正在测试..."
	%StatusLabel.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	_test_client.set_timeout_seconds(float(%TimeoutInput.value))
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
		%BtnTest.disabled = false
		%StatusLabel.text = "测试失败：请求无法启动 (%d)" % error
		%StatusLabel.add_theme_color_override("font_color", Color(1, 0.35, 0.25))


func _on_test_connection_response(response: Dictionary) -> void:
	%BtnTest.disabled = false
	if str(response.get("status", "")) == "error":
		%StatusLabel.text = "测试失败：%s" % str(response.get("message", "未知错误")).left(120)
		%StatusLabel.add_theme_color_override("font_color", Color(1, 0.35, 0.25))
		return
	if bool(response.get("ok", false)):
		var data := _current_config_data()
		data["ai_test_passed"] = true
		data["ai_test_signature"] = GameManager.battle_review_ai_config_signature(data)
		_write_config_data(data, "测试通过：模型可用，已保存")
		return
	%StatusLabel.text = "测试失败：模型返回格式不符合预期"
	%StatusLabel.add_theme_color_override("font_color", Color(1, 0.35, 0.25))


func _on_back() -> void:
	GameManager.goto_main_menu()
