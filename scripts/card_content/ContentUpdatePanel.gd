extends Control
## A bounded card, independent of Window/AcceptDialog minimum-size propagation.
const Hud := preload("res://scripts/ui/HudTheme.gd")
var _updater: Node
var _panel: PanelContainer
var _status: Label
var _notes: Label
var _progress: ProgressBar
var _automatic: CheckButton
var _check: Button
var _download: Button
var _restart: Button

func configure(updater: Node) -> void:
	_updater = updater
	name = "CardContentUpdateOverlay"
	z_as_relative = false
	z_index = 3900
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.01, 0.025, 0.76)
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.name = "ContentUpdateCard"
	add_child(_panel)
	var style := Hud.panel_style(Color("102331"), Color("2b6578"), 18)
	style.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "卡牌更新"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	header.add_child(title)
	var close := _button(header, "×", queue_free)
	close.custom_minimum_size = Vector2(44, 44)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	_status = _label(body)
	_status.add_theme_color_override("font_color", Hud.ACCENT)
	_notes = _label(body)
	_progress = ProgressBar.new()
	body.add_child(_progress)
	_automatic = CheckButton.new()
	_automatic.text = "自动下载卡牌更新"
	_automatic.custom_minimum_size.y = 44
	_automatic.toggled.connect(func(enabled: bool): _updater.set_auto_download(enabled))
	body.add_child(_automatic)
	var hint := _label(body)
	hint.text = "可能使用移动数据。关闭自动下载后，仍可检查和手动更新。"
	hint.add_theme_color_override("font_color", Hud.TEXT_MUTED)
	hint.add_theme_font_size_override("font_size", 16)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 10)
	column.add_child(actions)
	_check = _button(actions, "检查更新", func(): _updater.check_for_updates(true))
	_download = _button(actions, "下载更新", func(): _updater.download_update())
	_restart = _button(actions, "重启后应用", _restart_game)
	_updater.state_changed.connect(_refresh)
	_refresh(_updater.snapshot())
	resized.connect(_layout)
	_layout()
	call_deferred("_layout")

func _label(parent: Control) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Hud.TEXT)
	parent.add_child(label)
	return label

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(116, 44)
	button.add_theme_stylebox_override("normal", Hud.button_style(Hud.ACCENT, false, false))
	button.add_theme_stylebox_override("hover", Hud.button_style(Hud.ACCENT, true, false))
	button.add_theme_stylebox_override("pressed", Hud.button_style(Hud.ACCENT, false, true))
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _layout() -> void:
	if _panel == null: return
	var available := size if size.x > 0 else get_viewport_rect().size
	var display_scale := maxf(1.0, available.x / maxf(1.0, float(get_window().size.x)))
	if OS.has_feature("android") or OS.has_feature("ios"):
		display_scale *= clampf(float(DisplayServer.screen_get_dpi()) / 160.0, 1.0, 3.0)
	_panel.scale = Vector2.ONE * display_scale
	var logical := available / display_scale
	_panel.size = Vector2(minf(560.0, maxf(280.0, logical.x - 32.0)), minf(450.0, maxf(250.0, logical.y - 48.0)))
	_panel.position = (available - _panel.size * display_scale) * 0.5

func _refresh(data: Dictionary) -> void:
	_status.text = "当前：%s\n%s" % [data.get("current_version", "内置版本"), data.get("message", "")]
	var total := int(data.get("total_bytes", 0))
	_notes.text = str(data.get("notes", ""))
	if total > 0: _notes.text += "\n本次需下载 %.2f MB" % (float(total) / 1048576.0)
	_progress.visible = data.get("state") == "downloading"
	_progress.value = 100.0 * float(data.get("completed_bytes", 0)) / maxf(1.0, float(total))
	_automatic.set_pressed_no_signal(bool(data.get("auto_download", true)))
	_check.disabled = bool(data.get("busy", false))
	_download.visible = data.get("state") in ["available", "failed"] and data.get("available_version", "") != ""
	_download.disabled = bool(data.get("busy", false))
	_restart.visible = bool(data.get("restart_available", data.get("state") == "ready"))
	_restart.disabled = bool(data.get("busy", false))
	_restart.text = "刷新后应用" if OS.has_feature("web") else "重启后应用"

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()

func _restart_game() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.reload()")
		return
	OS.set_restart_on_exit(true, OS.get_cmdline_args())
	get_tree().quit()
