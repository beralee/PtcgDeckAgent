extends Control

const Catalog := preload("res://scripts/training/expert/ExpertPlayCatalog.gd")
const Store := preload("res://scripts/training/expert/ExpertPlayStore.gd")
const TouchBridge := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
const ExportAdapter := preload("res://scripts/training/expert/ExpertPlayExportAdapter.gd")
const Layout := preload("res://scripts/ui/non_battle/NonBattleLayoutController.gd")
var _status: Label
var _cards: VBoxContainer
var _topic := ""
var _margin: MarginContainer
var _header: VBoxContainer
var _export_adapter: Node
var _export_count := 0
var _battle_ready := true
var _preparing_since := 0
var _feedback_controller: RefCounted


func _ready() -> void:
	_export_adapter = ExportAdapter.new()
	add_child(_export_adapter)
	_export_adapter.saved.connect(func(_path: String) -> void:
		_status.text = "已保存 %d 次示范。把刚保存的 .jsonl 文件传给我，就能复核你的打法。" % _export_count
	)
	_export_adapter.cancelled.connect(func() -> void: _status.text = "已取消导出，示范仍保存在本机。")
	_export_adapter.failed.connect(func(message: String) -> void: _status.text = message)
	var background := ColorRect.new()
	background.color = Color("091820")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_margin.add_child(content)
	_header = VBoxContainer.new()
	_header.add_theme_constant_override("separation", 8)
	content.add_child(_header)
	var top := HFlowContainer.new()
	_header.add_child(top)
	top.add_child(_button("← 卡组训练", func() -> void: GameManager.goto_deck_training()))
	var export_button := _button("保存标注文件", _export)
	export_button.name = "ExpertExport"
	top.add_child(export_button)
	_label(_header, "多龙 18.5 · 专家共创", 32)
	_label(_header, "你来掌舵，AI 来学。每次五题，直接在牌桌上打。", 19)
	var progress := Store.progress()
	var covered := 0
	for item: Dictionary in progress.values():
		if int(item.submitted) > 0:
			covered += 1
	_label(_header, "已贡献 %d / 36 个局面 · 12 类实战判断 · 随时停下" % covered, 18)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 12)
	_header.add_child(actions)
	var start := _button("来五题", _start_batch)
	start.name = "ExpertStartFive"
	actions.add_child(start)
	var pending := Store.pending_feedback()
	if not pending.is_empty():
		var recover := _button("补完上次评价（%d）" % pending.size(), func() -> void:
			_feedback_controller = preload("res://scripts/training/expert/ExpertPlayController.gd").new()
			if not _feedback_controller.setup_feedback_recovery(self, pending[0]):
				_status.text = "评价草稿暂时无法打开，原始记录仍保留在本机。"
		)
		recover.name = "ExpertRecoverFeedback"
		actions.add_child(recover)
	if not (Store.queue_state().remaining as Array).is_empty():
		var resume := _button("接着上一组", _continue_batch)
		resume.name = "ExpertContinue"
		actions.add_child(resume)
	var filter := OptionButton.new()
	filter.name = "ExpertTopicFilter"
	filter.custom_minimum_size = Vector2(210, 46)
	filter.add_item("全部主题")
	var topics: Array[String] = []
	for scenario: Dictionary in Catalog.load_catalog().get("scenarios", []):
		if str(scenario.topic) not in topics:
			topics.append(str(scenario.topic))
	for topic: String in topics:
		filter.add_item(topic)
	filter.item_selected.connect(func(index: int) -> void:
		_topic = "" if index == 0 else topics[index - 1]
		_fill_cards()
	)
	actions.add_child(filter)
	_status = _label(content, "没有标准答案。真实的思路、犹豫与失误，都可以留下。", 17)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_cards = VBoxContainer.new()
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 12)
	scroll.add_child(_cards)
	_fill_cards()
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	set_process(false)
	if DisplayServer.get_name() != "headless":
		GameManager.prewarm_battle_scene_resource()
		_preparing_since = Time.get_ticks_msec()
		_set_battle_ready(false)
		set_process(true)


func _process(_delta: float) -> void:
	var path := "res://scenes/battle/BattleScene.tscn"
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_LOADED or (status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE and ResourceLoader.has_cached(path)):
		_set_battle_ready(true)
		set_process(false)
	elif status == ResourceLoader.THREAD_LOAD_FAILED or Time.get_ticks_msec() - _preparing_since > 180000:
		_status.text = "牌桌准备未完成，请返回卡组训练后重新打开。已保存的示范仍在。"
		set_process(false)


func _set_battle_ready(ready: bool) -> void:
	_battle_ready = ready
	for button: Button in find_children("ExpertPlay_*", "Button", true, false):
		button.disabled = not ready
	for node_name: String in ["ExpertStartFive", "ExpertContinue"]:
		var button := find_child(node_name, true, false) as Button
		if button != null:
			button.disabled = not ready
	_status.text = "牌桌已就绪，选一组开始。真实的思路、犹豫与失误，都可以留下。" if ready else "首次准备牌桌中…可以先看看题目，准备好后即可开始。"


func _input(event: InputEvent) -> void:
	if _feedback_controller != null:
		var form := find_child("DeckTrainingResultOverlay", true, false) as Control
		if form != null and form.visible:
			# A native editor deliberately leaves its touch for Godot's GUI path.
			# Never let the browser reinterpret that event over the card list.
			TouchBridge.handle_root_touch(form, event)
			return
	TouchBridge.handle_root_touch(self, event)


func _apply_layout() -> void:
	var size := get_viewport_rect().size
	var portrait := size.y > size.x
	var context := Layout.new().build_context(size, "portrait" if portrait else "landscape", OS.has_feature("mobile"))
	var margin := int(context.page_margin)
	for side: String in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, margin if side in ["left", "right"] else 18)
	for button: Button in find_children("*", "Button", true, false):
		button.custom_minimum_size.y = float(context.secondary_button_height) if portrait else 52
		button.add_theme_font_size_override("font_size", int(context.button_font_size) if portrait else 20)
		if button is OptionButton:
			button.get_popup().add_theme_font_size_override("font_size", int(context.button_font_size) if portrait else 20)
	for label: Label in find_children("*", "Label", true, false):
		var base := int(label.get_meta("expert_base_font", 18))
		var font := int(context.title_font_size) if base >= 30 else (int(context.section_font_size) if base >= 24 else int(context.body_font_size))
		label.add_theme_font_size_override("font_size", font if portrait else base)


func _fill_cards() -> void:
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	var catalog := Catalog.load_catalog()
	if not (catalog.errors as Array).is_empty():
		_status.text = "题库暂时不可用：" + str(catalog.errors[0])
		return
	var progress := Store.progress()
	for scenario: Dictionary in catalog.scenarios:
		if _topic != "" and str(scenario.topic) != _topic:
			continue
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("102c38")
		style.border_color = Color("2b7482")
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 14
		style.content_margin_bottom = 14
		panel.add_theme_stylebox_override("panel", style)
		_cards.add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		panel.add_child(box)
		_label(box, "%02d  %s" % [int(scenario.order), str(scenario.title)], 24)
		var item: Dictionary = progress.get(str(scenario.id), {})
		var done := "已贡献 %d 次" % int(item.get("submitted", 0)) if int(item.get("submitted", 0)) > 0 else "等你来教"
		_label(box, "%s · %d 个我方回合 · %s" % [str(scenario.topic), int(scenario.turn_limit), done], 17)
		var id := str(scenario.id)
		var play := _button("就打这题", func() -> void:
			if not _battle_ready:
				return
			if Store.set_queue([id]):
				GameManager.start_deck_training(id)
			else:
				_status.text = "进度未能保存，请检查存储空间。"
		)
		play.name = "ExpertPlay_" + id
		play.disabled = not _battle_ready
		box.add_child(play)
	_apply_layout()


func _start_batch() -> void:
	if not _battle_ready:
		return
	var catalog := Catalog.load_catalog()
	if not (catalog.errors as Array).is_empty():
		_status.text = "题库校验失败，暂时无法开始。"
		return
	var ids := Store.choose_queue(catalog.scenarios, Store.progress(), 5, _topic)
	if not Store.set_queue(ids):
		_status.text = "进度未能保存，请检查存储空间。"
		return
	_continue_batch()


func _continue_batch() -> void:
	if not _battle_ready:
		return
	var remaining: Array = Store.queue_state().remaining
	if not remaining.is_empty() and not GameManager.start_deck_training(str(remaining[0])):
		_status.text = "这题已更新，请重新选一组。"


func _export() -> void:
	var result := Store.export_public()
	if not bool(result.ok):
		_status.text = "导出未成功，原始示范仍保存在本机。"
		return
	_export_count = int(result.count)
	if _export_count == 0:
		_status.text = "先完成并保存一道题，再来导出。"
		return
	_status.text = "请选择保存位置，例如“下载”。"
	var date := Time.get_date_string_from_system().replace("-", "")
	_export_adapter.save_file(str(result.path), "dragapult-expert-%s-%d.jsonl" % [date, _export_count])


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(170, 46)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	TouchBridge.bind_button_touch(button)
	return button


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.set_meta("expert_base_font", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("dcf4f4"))
	parent.add_child(label)
	return label
