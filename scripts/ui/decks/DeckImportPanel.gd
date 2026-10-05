## 卡组中心导入面板：来源选择、临时输入、确认牌表与响应式布局。
## 网络请求和保存仍由 DeckManager / DeckImporter 持有。
extends RefCounted

const TouchBridge := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
const UI := preload("res://scripts/ui/decks/DeckCenterTheme.gd")
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
var preview_deck: DeckData = null
var preview_errors := PackedStringArray()
var _preview: VBoxContainer
var _preview_name: LineEdit


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
	preview_deck = null
	preview_errors.clear()
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


func show_preview(deck: DeckData, errors: PackedStringArray) -> void:
	var scene := _scene()
	if scene == null or deck == null:
		return
	preview_deck = DeckData.from_dict(deck.to_dict().duplicate(true))
	preview_errors = errors.duplicate()
	state = "preview"
	if is_instance_valid(_preview):
		_preview.get_parent().remove_child(_preview)
		_preview.queue_free()
	_preview = VBoxContainer.new()
	_preview.name = "ImportDeckPreview"
	var body := scene.get_node("ImportPanel/ImportBox/ImportScroll/VBox")
	body.add_child(_preview)
	body.move_child(_preview, body.get_node("BtnRow").get_index())
	_preview_name = LineEdit.new()
	_preview_name.name = "ImportPreviewName"
	_preview_name.text = deck.deck_name
	_preview_name.placeholder_text = "卡组名称"
	_preview_name.max_length = 64
	_preview.add_child(_preview_name)
	_preview.add_child(UI.label("%d 张 · %s" % [deck.total_cards, UI.summary(deck)], 16, UI.MUTED))
	if CardDatabase.has_deck(deck.id):
		var warning := UI.label("本机已有相同编号，确认后将更新这套卡组。", 15, Color("efbd7d"))
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_preview.add_child(warning)
	var scroll := ScrollContainer.new()
	scroll.name = "ImportPreviewCards"
	UI.scroll(scroll)
	_preview.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for entry: Dictionary in deck.cards:
		var row := UI.label("%d × %s  ·  %s/%s" % [int(entry.get("count", 0)), CardData.dictionary_display_name(entry), entry.get("set_code", ""), entry.get("card_index", "")], 15)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(row)
	scene.get_node("%ProgressLabel").text = "\n".join(errors)
	render()
	scene.call("_apply_non_battle_layout")


func confirm_preview() -> void:
	var scene := _scene()
	if scene == null or preview_deck == null or state != "preview":
		return
	var name := _preview_name.text.strip_edges()
	var error: String = scene.call("_validate_deck_name", name, preview_deck.id)
	if error != "":
		scene.get_node("%ProgressLabel").text = error
		return
	preview_deck.deck_name = name
	scene.call("_finalize_import_save", preview_deck, preview_errors)


func render() -> void:
	var scene := _scene()
	if scene == null:
		return
	var sync: bool = scene._panel_mode == "sync_images"
	var busy: bool = scene._current_operation != ""
	var success := state == "success" and not sync
	var preview := state == "preview" and not sync
	var image_mode := source == "image"
	var vbox := scene.get_node("ImportPanel/ImportBox/ImportScroll/VBox")
	var hint := vbox.get_node("HintLabel") as Label
	var input := scene.get_node("%UrlInput") as LineEdit
	var primary := scene.get_node("%BtnDoImport") as Button
	var paste: Button = scene.call("_ensure_import_paste_button")
	var image_button: Button = scene.call("_ensure_import_image_button")
	var provider: Button = scene.call("_ensure_import_provider_button")
	vbox.get_node("TitleLabel").text = "同步卡图" if sync else ("③ 卡组已保存" if success else ("② 确认卡组" if preview else "① 导入卡组"))
	_tabs.visible = not sync and not success and not preview
	if is_instance_valid(_preview):
		_preview.visible = preview
	for i: int in _tabs.get_child_count():
		var button := _tabs.get_child(i) as Button
		button.set_pressed_no_signal(source == SOURCES[i])
		button.disabled = busy
	hint.visible = not sync and not success and not preview
	hint.text = GUIDES[source]
	input.visible = not sync and not success and not image_mode and not preview
	input.editable = not busy and not success
	input.placeholder_text = "粘贴 18 位卡组 ID" if source == "miniapp" else "粘贴卡组链接或数字编号"
	scene.call("_configure_import_url_line_edit", input)
	if source == "miniapp":
		input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_source_note.visible = not sync and not success and not image_mode and not preview
	_source_note.text = "通过 tcg.mik.moe 读取卡组，无需登录小程序。" if source == "miniapp" else "导入后保存在本机，可在卡组中心查看和编辑。"
	provider.visible = not sync and not success and source == "website" and not busy and not preview
	primary.visible = not sync and not busy and (success or not image_mode)
	primary.disabled = busy
	primary.text = "查看卡组" if success else (("确认更新" if CardDatabase.has_deck(preview_deck.id) else "保存卡组") if preview else ("重新导入" if state == "error" else "读取卡组"))
	paste.visible = not sync and not busy and (success or not image_mode) and not preview
	paste.disabled = busy
	paste.text = "继续导入" if success else ("输入 / 粘贴" if scene.call("_is_deck_manager_web_runtime") else "粘贴")
	image_button.visible = not sync and not success and image_mode and not busy and not preview
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
	var profile := UI.for_control(scene, viewport_size)
	var scale: float = _context.get("portrait_scale", profile.scale)
	var panel := scene.get_node("%ImportPanel") as Control
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_as_relative = false
	panel.z_index = 2500
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := scene.find_child("ImportBg", true, false) as ColorRect
	bg.color = Color(0, 0, 0, 0.65)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := scene.find_child("ImportBox", true, false) as PanelContainer
	box.add_theme_stylebox_override("panel", UI.box(UI.SURFACE, UI.LINE, roundi(14 * scale), 16 * scale))
	var width := minf(680 * scale, viewport_size.x - 24 * scale)
	var height := minf(620 * scale, viewport_size.y - 24 * scale)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2.ZERO
	box.offset_left = -width / 2
	box.offset_right = width / 2
	box.offset_top = -height / 2
	box.offset_bottom = height / 2
	var vbox := box.get_node("ImportScroll/VBox") as VBoxContainer
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", roundi(12 * scale))
	UI.scroll(box.get_node("ImportScroll"))
	for label: Label in [vbox.get_node("HintLabel"), scene.get_node("%ProgressLabel"), _source_note]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2.ZERO
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_FILL
		label.add_theme_font_size_override("font_size", roundi((13 if label == _source_note else 16) * scale))
	vbox.get_node("TitleLabel").add_theme_font_size_override("font_size", roundi(24 * scale))
	vbox.get_node("TitleLabel").add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	UI.input(scene.get_node("%UrlInput"), scale, false)
	scene.get_node("%ProgressBar").custom_minimum_size.y = 12 * scale
	for button: Button in _tabs.get_children():
		UI.button(button, scale)
		button.add_theme_font_size_override("font_size", roundi((13 if portrait else 15) * scale))
	for button_name: String in ["BtnPasteImport", "BtnImageImport", "BtnDoImport", "BtnCloseImport", "BtnOpenTcgMik"]:
		var button := scene.find_child(button_name, true, false) as Button
		if button != null:
			UI.button(button, scale, button_name == "BtnDoImport")
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.get_node("BtnRow").add_theme_constant_override("separation", roundi(6 * scale))
	_tabs.add_theme_constant_override("separation", roundi(4 * scale))
	if is_instance_valid(_preview):
		_preview.add_theme_constant_override("separation", roundi(10 * scale))
		UI.input(_preview_name, scale)
		var scroll := _preview.get_node("ImportPreviewCards") as ScrollContainer
		scroll.custom_minimum_size.y = minf(210 * scale, height * 0.32)
		for child: Node in _preview.get_children():
			if child is Label:
				child.add_theme_font_size_override("font_size", roundi(14 * scale))
		for label: Label in scroll.get_child(0).get_children():
			label.add_theme_font_size_override("font_size", roundi(14 * scale))


func _scene() -> Control:
	return _scene_ref.get_ref() as Control if _scene_ref != null else null
