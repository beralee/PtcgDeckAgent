## 卡组中心导入面板：来源选择、草稿、状态与响应式布局。
## 网络请求和保存仍由 DeckManager / DeckImporter 持有。
extends RefCounted

const TouchBridge := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
const SOURCES := ["website", "miniapp", "image"]
const LABELS := ["链接 / 编号", "官方小程序", "卡组图片"]
const GUIDES := {
	"website": "复制卡组页面链接，再粘贴到下方。\n支持 tcg.mik.moe、Limitless；数字编号如 574793。",
	"miniapp": "在官方小程序中复制卡组 ID，再粘贴到下方。\nID 共 18 位，区分大小写；也支持卡组导出工具链接。",
	"image": "选择本游戏生成的卡组分享图或总览图。\n图片需包含卡组数据，普通截图暂不支持。",
}

var source := "website"
var state := "input"
var completed_deck: DeckData = null
var _drafts := {"website": "", "miniapp": ""}
var _scene_ref: WeakRef
var _tabs: HBoxContainer
var _source_note: Label


func setup(scene: Control) -> void:
	_scene_ref = weakref(scene)
	if is_instance_valid(_tabs):
		return
	var vbox := scene.get_node("ImportPanel/ImportBox/ImportScroll/VBox") as VBoxContainer
	_tabs = HBoxContainer.new()
	_tabs.name = "ImportSourceTabs"
	_tabs.add_theme_constant_override("separation", 8)
	vbox.add_child(_tabs)
	vbox.move_child(_tabs, 1)
	for i: int in SOURCES.size():
		var button := Button.new()
		button.name = "ImportSource_" + SOURCES[i]
		button.text = LABELS[i]
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scene.call("_style_hud_button", button, scene.HUD_ACCENT, true)
		button.custom_minimum_size.x = 0
		button.pressed.connect(select_source.bind(SOURCES[i]))
		_tabs.add_child(button)
		TouchBridge.bind_button_touch(button)
	_source_note = Label.new()
	_source_note.name = "ImportSourceNote"
	_source_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_source_note.add_theme_color_override("font_color", scene.HUD_TEXT_MUTED)
	vbox.add_child(_source_note)
	vbox.move_child(_source_note, scene.get_node("%UrlInput").get_index() + 1)
	var input := scene.get_node("%UrlInput") as LineEdit
	input.text_changed.connect(_on_text_changed)
	input.text_submitted.connect(_on_text_submitted)


func reset() -> void:
	state = "input"
	completed_deck = null
	var scene := _scene()
	if scene == null:
		return
	scene.get_node("%ProgressLabel").text = ""
	scene.get_node("%ProgressLabel").add_theme_color_override("font_color", scene.HUD_TEXT_MUTED)
	scene.get_node("%UrlInput").text = str(_drafts.get(source, ""))
	render()


func select_source(next_source: String, preserve_input: bool = false) -> void:
	var scene := _scene()
	if scene == null or next_source not in SOURCES or scene._current_operation != "":
		return
	var input := scene.get_node("%UrlInput") as LineEdit
	if source != "image":
		_drafts[source] = input.text
	if source != next_source:
		if not preserve_input:
			TouchBridge.close_web_text_input("import_source_changed")
		source = next_source
		if not preserve_input:
			input.text = str(_drafts.get(source, ""))
	state = "input"
	completed_deck = null
	scene.get_node("%ProgressLabel").text = ""
	render()
	if scene.is_inside_tree():
		scene.call_deferred("_prepare_web_import_url_input")


func _on_text_changed(text: String) -> void:
	var scene := _scene()
	if scene == null or scene._current_operation != "" or state == "success":
		return
	var ref := DeckImporter.parse_provider_ref(text)
	if str(ref.get("provider", "")) == "miniapp" and source != "miniapp":
		select_source("miniapp", true)
	elif str(ref.get("provider", "")) in ["tcg_mik", "limitless"] and source == "miniapp":
		select_source("website", true)
	if source != "image":
		_drafts[source] = text
	if state == "error":
		state = "input"
		scene.get_node("%ProgressLabel").text = ""
		render()


func _on_text_submitted(_text: String) -> void:
	var scene := _scene()
	if scene != null and scene._current_operation == "" and state != "success":
		scene.call("_on_do_import")


func show_error(message: String) -> void:
	state = "error"
	completed_deck = null
	render()
	var scene := _scene()
	if scene != null:
		scene.get_node("%ProgressLabel").text = message
		scene.get_node("%ProgressLabel").add_theme_color_override("font_color", scene.HUD_ACCENT_WARM)


func show_success(deck: DeckData, message: String) -> void:
	state = "success"
	completed_deck = deck
	render()
	var scene := _scene()
	if scene != null:
		scene.get_node("%ProgressLabel").text = message
		scene.get_node("%ProgressLabel").add_theme_color_override("font_color", scene.HUD_TEXT)


func render() -> void:
	var scene := _scene()
	if scene == null:
		return
	var sync: bool = scene._panel_mode == "sync_images"
	var busy: bool = scene._current_operation != ""
	var success := state == "success" and not sync
	var image_mode := source == "image"
	var vbox := scene.get_node("ImportPanel/ImportBox/ImportScroll/VBox")
	var hint := vbox.get_node("HintLabel") as Label
	var input := scene.get_node("%UrlInput") as LineEdit
	var primary := scene.get_node("%BtnDoImport") as Button
	var paste: Button = scene.call("_ensure_import_paste_button")
	var image_button: Button = scene.call("_ensure_import_image_button")
	var provider: Button = scene.call("_ensure_import_provider_button")
	vbox.get_node("TitleLabel").text = "同步卡图" if sync else ("卡组已导入" if success else "导入卡组")
	_tabs.visible = not sync and not success
	for i: int in _tabs.get_child_count():
		var button := _tabs.get_child(i) as Button
		button.set_pressed_no_signal(source == SOURCES[i])
		button.disabled = busy
	hint.visible = not sync and not success
	hint.text = GUIDES[source]
	input.visible = not sync and not success and not image_mode
	input.editable = not busy and not success
	input.placeholder_text = "粘贴 18 位卡组 ID" if source == "miniapp" else "粘贴卡组链接或数字编号"
	scene.call("_configure_import_url_line_edit", input)
	if source == "miniapp":
		input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_source_note.visible = not sync and not success and not image_mode
	_source_note.text = "通过 tcg.mik.moe 读取卡组，无需登录小程序。" if source == "miniapp" else "导入后保存在本机，可在卡组中心查看和编辑。"
	provider.visible = not sync and not success and source == "website" and not busy
	primary.visible = not sync and not busy and (success or not image_mode)
	primary.disabled = busy
	primary.text = "查看卡组" if success else ("重新导入" if state == "error" else "导入卡组")
	paste.visible = not sync and not busy and (success or not image_mode)
	paste.disabled = busy
	paste.text = "继续导入" if success else ("输入 / 粘贴" if scene.call("_is_deck_manager_web_runtime") else "粘贴")
	image_button.visible = not sync and not success and image_mode and not busy
	image_button.disabled = busy
	image_button.text = "选择卡组图片"
	var close := scene.get_node("%BtnCloseImport") as Button
	close.disabled = busy
	close.text = "完成" if success else "关闭"
	if not busy:
		scene.get_node("%ProgressBar").visible = false
	if state != "error":
		scene.get_node("%ProgressLabel").add_theme_color_override("font_color", scene.HUD_TEXT_MUTED)


func apply_layout(_context: Dictionary, portrait: bool, viewport_size: Vector2) -> void:
	var scene := _scene()
	if scene == null:
		return
	var panel := scene.get_node("%ImportPanel") as Control
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_as_relative = false
	panel.z_index = 2500
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := scene.find_child("ImportBg", true, false) as Control
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := scene.find_child("ImportBox", true, false) as PanelContainer
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var vbox := box.get_node("ImportScroll/VBox") as VBoxContainer
	var narrow := viewport_size.x < 600
	var scroll := box.get_node("ImportScroll") as ScrollContainer
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var width := minf(780.0, viewport_size.x - 40.0)
	var height := minf(520.0, viewport_size.y - 32.0)
	if portrait:
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 16
		box.offset_right = -16
		box.offset_top = 16
		box.offset_bottom = -16
		box.custom_minimum_size = Vector2(maxf(0, viewport_size.x - 32), maxf(0, viewport_size.y - 32))
	else:
		box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		box.custom_minimum_size = Vector2(width, height)
		box.offset_left = -width / 2
		box.offset_right = width / 2
		box.offset_top = -height / 2
		box.offset_bottom = height / 2
	vbox.add_theme_constant_override("separation", 14 if not narrow else 12)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body_font := 20 if not narrow else 17
	for label: Label in [vbox.get_node("HintLabel"), scene.get_node("%ProgressLabel"), _source_note]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2.ZERO
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_FILL
		label.add_theme_font_size_override("font_size", body_font if label != _source_note else body_font - 3)
	var progress := scene.get_node("%ProgressLabel") as Label
	progress.size_flags_vertical = Control.SIZE_EXPAND_FILL
	progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.get_node("TitleLabel").add_theme_font_size_override("font_size", 30 if not narrow else 26)
	var input := scene.get_node("%UrlInput") as LineEdit
	input.custom_minimum_size = Vector2(0, 56 if not narrow else 60)
	input.add_theme_font_size_override("font_size", 22 if not narrow else 19)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene.get_node("%ProgressBar").custom_minimum_size.y = 18
	var buttons: Array[Button] = []
	for child: Node in _tabs.get_children():
		buttons.append(child as Button)
	for name: String in ["BtnPasteImport", "BtnImageImport", "BtnDoImport", "BtnCloseImport", "BtnOpenTcgMik"]:
		var button := scene.find_child(name, true, false) as Button
		if button != null:
			buttons.append(button)
	for button: Button in buttons:
		button.custom_minimum_size = Vector2(0, 52 if not narrow else 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 21 if not narrow else 16)
		TouchBridge.bind_button_touch(button)
	var row := vbox.get_node("BtnRow") as HBoxContainer
	row.add_theme_constant_override("separation", 10 if not narrow else 6)
	_tabs.add_theme_constant_override("separation", 8 if not narrow else 4)


func _scene() -> Control:
	return _scene_ref.get_ref() as Control if _scene_ref != null else null
