extends PanelContainer
const Mood := preload("res://scripts/commentary/OpponentMood.gd")
signal close_requested
signal history_requested
var body: Label
var identity: Label
var history_button: Button
var close_button: Button
var remaining := 0.0
var placement_available := true
var skin: StyleBoxFlat
var emote: TextureRect
var current_mood_id := "eager"
var expression_tween: Tween
var mobile_scale := 0.0
var mobile_wide := false
var row: HBoxContainer
var column: VBoxContainer
var header: HBoxContainer

func _init() -> void:
	name = "OpponentTalkBubble"
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 3
	skin = StyleBoxFlat.new()
	skin.bg_color = Color("122335", 0.96)
	skin.border_color = Color("5b9bac")
	skin.set_border_width_all(1)
	skin.border_width_left = 4
	skin.set_corner_radius_all(18)
	skin.corner_radius_bottom_left = 4
	skin.content_margin_left = 10
	skin.content_margin_right = 10
	skin.content_margin_top = 6
	skin.content_margin_bottom = 10
	add_theme_stylebox_override("panel", skin)
	row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	emote = TextureRect.new()
	emote.name = "MoodPortrait"
	emote.custom_minimum_size = Vector2(60, 60)
	emote.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	emote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emote.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emote.texture = Mood.portrait(current_mood_id)
	row.add_child(emote)
	row.add_child(column)
	header = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 4)
	column.add_child(header)
	identity = Label.new()
	identity.text = "跃跃欲试"
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_theme_font_size_override("font_size", 14)
	identity.add_theme_color_override("font_color", Color("d9c896"))
	header.add_child(identity)
	history_button = _button("回看", func(): history_requested.emit())
	close_button = _button("静音", func(): close_requested.emit())
	close_button.tooltip_text = "关闭本局对手互动"
	header.add_child(history_button)
	header.add_child(close_button)
	body = Label.new()
	body.text = "我准备好啦，开始吧。"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.y = 44
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color("ecf3f7"))
	column.add_child(body)

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(44, 44)
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(callback)
	preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd").bind_button_touch(button)
	return button

func present(text: String, cue: Dictionary) -> void:
	body.text = text
	body.modulate.a = 1.0
	var canonical := Mood.bind(cue)
	_set_emotion(str(canonical.mood_id))
	remaining = 4.0
	visible = placement_available

func set_placement_available(available: bool) -> void:
	placement_available = available
	visible = available and remaining > 0.0

func fit_width(width: float) -> Vector2:
	# Hidden Containers do not sort their children. Measure the wrapped label
	# at its actual text width before deciding whether a safe pocket exists.
	var inset := emote.custom_minimum_size.x + skin.content_margin_left + skin.content_margin_right + 8
	if mobile_wide: inset += header.get_combined_minimum_size().x + 8
	body.size.x = maxf(1,width-inset)
	var height := maxf(104.0, 60.0 + body.get_minimum_size().y) if mobile_scale == 0.0 else maxf((60 if mobile_wide else 84)*mobile_scale,(16 if mobile_wide else 60)*mobile_scale+body.get_minimum_size().y)
	size = Vector2(width, height)
	return size

func configure_mobile(scale: float, wide: bool = false) -> void:
	wide = wide and scale > 0
	if is_equal_approx(mobile_scale,scale) and mobile_wide == wide: return
	mobile_scale = scale
	mobile_wide = wide
	if header.get_parent() != (row if wide else column):
		header.reparent(row if wide else column)
		if not wide: column.move_child(header,0)
	header.size_flags_vertical = Control.SIZE_SHRINK_CENTER if wide else Control.SIZE_FILL
	identity.visible = not wide
	var factor := maxf(1,scale)
	body.add_theme_font_size_override("font_size",roundi(22*factor) if scale > 0 else 18)
	identity.add_theme_font_size_override("font_size",roundi(15*factor) if scale > 0 else 14)
	for button in [history_button,close_button]:
		button.custom_minimum_size = Vector2(44,44)*factor
		button.add_theme_font_size_override("font_size",roundi(14*factor) if scale > 0 else 12)
	# A landscape row shares its height with the controls and text. Retaining
	# the portrait-sized face can exceed the space above the active Pokemon.
	var portrait_size := 44 if wide else 68
	emote.custom_minimum_size = Vector2(portrait_size,portrait_size)*factor if scale > 0 else Vector2(60,60)
	skin.content_margin_left = 10*factor
	skin.content_margin_right = 10*factor
	skin.content_margin_top = 6*factor
	skin.content_margin_bottom = 10*factor

func _set_emotion(id: String) -> void:
	var entry := Mood.entry(id)
	current_mood_id = entry.id
	emote.texture = Mood.portrait(current_mood_id)
	emote.tooltip_text = "当前心态：" + str(entry.label)
	identity.text = str(entry.label)
	skin.border_color = Color(entry.color)
	identity.add_theme_color_override("font_color", Color(entry.color))
	if expression_tween != null: expression_tween.kill()
	emote.modulate.a = 1.0
	if is_inside_tree() and GameManager.battle_effects_enabled:
		emote.modulate.a = 0.55
		expression_tween = create_tween()
		expression_tween.tween_property(emote, "modulate:a", 1.0, 0.15)

func _process(delta: float) -> void:
	if remaining <= 0: return
	remaining -= delta
	if remaining <= 0:
		body.text = "……"
		body.modulate.a = 0.55
		_set_emotion("focused")
		hide()

func _exit_tree() -> void:
	if expression_tween != null: expression_tween.kill()
