extends PanelContainer
signal close_requested
signal history_requested
var body: Label
var status: Label
var source: Label
var history_button: Button
var close_button: Button

func _init() -> void:
	name = "BattleCommentaryPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 3
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("101f26", 0.98)
	skin.border_color = Color("4e9e98", 0.8)
	skin.set_border_width_all(1)
	skin.border_width_left = 4
	skin.set_corner_radius_all(12)
	skin.content_margin_left = 18
	skin.content_margin_right = 12
	skin.content_margin_top = 8
	skin.content_margin_bottom = 10
	add_theme_stylebox_override("panel", skin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)
	add_child(column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	source = Label.new()
	source.text = "赛场解说 · 文字版"
	source.add_theme_font_size_override("font_size", 17)
	source.add_theme_color_override("font_color", Color("ddc894"))
	source.mouse_filter = Control.MOUSE_FILTER_IGNORE
	source.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(source)
	history_button = _button("回看", func(): history_requested.emit())
	close_button = _button("关闭解说", func(): close_requested.emit())
	close_button.tooltip_text = "停止本局解说与后续请求；已发出的请求可能已产生费用"
	header.add_child(history_button)
	header.add_child(close_button)
	body = Label.new()
	body.text = "卡组知识已就绪。双方公开开局后，将先分析打法，再解说关键行动。"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", Color("e3efef"))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", Color("94b4bd"))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(status)

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(72, 44)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(action)
	preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd").bind_button_touch(button)
	return button

func present(text: String, label: String) -> void:
	body.text = text
	source.text = "赛场解说 · " + label

static func reserved_height(safe_size: Vector2) -> float:
	return 186.0 if safe_size.x < 1000 else 150.0
