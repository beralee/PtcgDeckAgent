extends VBoxContainer
const Preferences := preload("res://scripts/commentary/CommentaryPreferences.gd")
const Presentation := preload("res://scripts/ui/battle/BattlePresentation.gd")
var toggle: CheckButton
var note: Label
var opted_in := false

func _init() -> void:
	name = "CommentarySetupOption"
	toggle = CheckButton.new()
	toggle.name = "TextCommentaryToggle"
	toggle.text = "AI 对手互动 · 仅 3D"
	toggle.custom_minimum_size.y = 44
	opted_in = Preferences.enabled()
	toggle.button_pressed = opted_in
	# The shared touch bridge emits pressed without synthesizing a native toggle.
	# Own one state transition on pressed for mouse, keyboard and bridged touch.
	toggle.pressed.connect(func():
		opted_in = not opted_in
		toggle.set_pressed_no_signal(opted_in)
		if Preferences.save_enabled(opted_in) != OK:
			opted_in = not opted_in
			toggle.set_pressed_no_signal(opted_in)
			note.text = "偏好保存失败，请检查存储空间。"
	)
	add_child(toggle)
	note = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color("91b7cc"))
	add_child(note)

func update_field(path: String) -> void:
	var available := Presentation.fields_3d_available() and Presentation.field_theme(path) != ""
	toggle.disabled = not available
	note.text = "沿用设置中的 AI 性格，陪练时开口互动。DeepSeek 每局最多 3 次准备请求；未配置时使用本地台词，可随时静音。" if available else "选择 3D 场地后可开启；2D 不运行对手互动，不消耗 token。"
	toggle.tooltip_text = note.text

func set_compact(compact: bool) -> void:
	note.visible = not compact
	toggle.text = "对手互动·3D·耗 token" if compact else "AI 对手互动 · 仅 3D"
	toggle.add_theme_font_size_override("font_size", 13 if compact else 16)
	toggle.custom_minimum_size.y = 44
