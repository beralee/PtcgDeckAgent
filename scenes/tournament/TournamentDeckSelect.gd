extends Control

const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")

const DECK_USAGE_STATS_PATH := "user://battle_deck_usage.json"
const DECK_PICKER_ALL := "all"
const DECK_PICKER_RECENT := "recent"
const DECK_PICKER_LIMIT := 80

const HUD_ACCENT := Color(0.28, 0.92, 1.0, 1.0)
const HUD_TEXT := Color(0.92, 0.98, 1.0, 1.0)
const HUD_TEXT_MUTED := Color(0.64, 0.76, 0.86, 1.0)

var _decks: Array[DeckData] = []
var _deck_usage_stats: Dictionary = {}
var _deck_picker_overlay: Control = null
var _deck_picker_panel: PanelContainer = null
var _deck_picker_category := DECK_PICKER_RECENT
var _deck_picker_search := ""
var _deck_picker_tabs: Dictionary = {}
var _deck_picker_grid: GridContainer = null
var _deck_picker_search_input: LineEdit = null
var _deck_picker_subtitle: Label = null


func _ready() -> void:
	HudThemeScript.apply(self)
	_apply_tournament_picker_theme()
	%BtnBack.pressed.connect(_on_back_pressed)
	%BtnNext.pressed.connect(_on_next_pressed)
	%DeckPickerButton.pressed.connect(_on_deck_picker_pressed)
	_load_deck_usage_stats()
	_load_decks()


func _apply_tournament_picker_theme() -> void:
	var picker_button := get_node_or_null("%DeckPickerButton") as Button
	if picker_button != null:
		_style_deck_picker_button(picker_button)
	var panel := find_child("Panel", true, false) as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override("panel", _hud_picker_panel_style())


func _load_decks() -> void:
	%TitleLabel.text = "比赛模式：选择玩家卡组"
	%HintLabel.text = "选择你要参加瑞士轮比赛的卡组。卡组多时可以用最近使用或搜索快速定位。"
	%BtnBack.text = "返回"
	%BtnNext.text = "下一步"
	_decks = CardDatabase.get_all_decks()
	%DeckOption.visible = false
	%DeckOption.clear()
	for deck: DeckData in _decks:
		%DeckOption.add_item(deck.deck_name)
		%DeckOption.set_item_metadata(%DeckOption.item_count - 1, deck.id)

	if %DeckOption.item_count > 0:
		var selected_id := GameManager.tournament_selected_player_deck_id
		if selected_id <= 0:
			selected_id = (_decks[0] as DeckData).id
		_select_deck_id(selected_id)
	else:
		%BtnNext.disabled = true
		_update_selected_deck_label()

	if not %DeckOption.item_selected.is_connected(_on_deck_selected):
		%DeckOption.item_selected.connect(_on_deck_selected)


func _on_deck_selected(_index: int) -> void:
	_update_selected_deck_label()


func _update_selected_deck_label() -> void:
	var deck: DeckData = _selected_deck()
	if deck == null:
		%SelectedDeckLabel.text = "当前没有可用卡组。"
		%DeckPickerButton.text = "选择卡组"
		%DeckPickerButton.disabled = true
		%BtnNext.disabled = true
		return

	%BtnNext.disabled = false
	%DeckPickerButton.disabled = false
	%SelectedDeckLabel.text = "已选择：%s" % deck.deck_name
	%DeckPickerButton.text = "%s\n点击更换参赛卡组" % deck.deck_name
	%DeckPickerButton.tooltip_text = _deck_picker_card_tooltip(deck)


func _selected_deck() -> DeckData:
	var index: int = %DeckOption.selected
	if index < 0 or index >= %DeckOption.item_count:
		return null
	var metadata: Variant = %DeckOption.get_item_metadata(index)
	if metadata is int:
		for deck: DeckData in _decks:
			if deck.id == int(metadata):
				return deck
	if index >= 0 and index < _decks.size():
		return _decks[index]
	return null


func _select_deck_id(deck_id: int) -> void:
	if %DeckOption.item_count <= 0:
		return
	for index: int in %DeckOption.item_count:
		var metadata: Variant = %DeckOption.get_item_metadata(index)
		if metadata is int and int(metadata) == deck_id:
			%DeckOption.select(index)
			_update_selected_deck_label()
			_refresh_deck_picker()
			return
	%DeckOption.select(0)
	_update_selected_deck_label()
	_refresh_deck_picker()


func _on_deck_picker_pressed() -> void:
	_deck_picker_category = DECK_PICKER_RECENT
	_deck_picker_search = ""
	_ensure_deck_picker_overlay()
	if _deck_picker_search_input != null:
		_deck_picker_search_input.text = ""
	_refresh_deck_picker()
	_resize_deck_picker_panel()
	_deck_picker_overlay.visible = true
	_deck_picker_overlay.move_to_front()


func _ensure_deck_picker_overlay() -> void:
	if _deck_picker_overlay != null and is_instance_valid(_deck_picker_overlay):
		return
	_deck_picker_overlay = Control.new()
	_deck_picker_overlay.name = "DeckPickerOverlay"
	_deck_picker_overlay.visible = false
	_deck_picker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_deck_picker_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_deck_picker_overlay)

	var shade := ColorRect.new()
	shade.name = "DeckPickerShade"
	shade.color = Color(0.0, 0.012, 0.025, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_close_deck_picker()
	)
	_deck_picker_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.name = "DeckPickerCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_deck_picker_overlay.add_child(center)

	_deck_picker_panel = PanelContainer.new()
	_deck_picker_panel.name = "DeckPickerPanel"
	_deck_picker_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_picker_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_deck_picker_panel.add_theme_stylebox_override("panel", _hud_picker_panel_style())
	center.add_child(_deck_picker_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	_deck_picker_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	var title := Label.new()
	title.text = "选择参赛卡组"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", HUD_TEXT)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.82, 1.0, 0.60))
	title.add_theme_constant_override("shadow_offset_y", 1)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(44, 38)
	close_button.pressed.connect(_close_deck_picker)
	_style_hud_button(close_button)
	header.add_child(close_button)

	_deck_picker_subtitle = Label.new()
	_deck_picker_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_hud_label(_deck_picker_subtitle)
	root.add_child(_deck_picker_subtitle)

	_deck_picker_search_input = LineEdit.new()
	_deck_picker_search_input.placeholder_text = "搜索卡组名称、ID 或类型"
	_deck_picker_search_input.custom_minimum_size = Vector2(0, 42)
	_deck_picker_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_picker_search_input.text_changed.connect(_on_deck_picker_search_changed)
	_style_hud_line_edit(_deck_picker_search_input)
	root.add_child(_deck_picker_search_input)

	var tabs := HBoxContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	_deck_picker_tabs.clear()
	for tab: Dictionary in [
		{"id": DECK_PICKER_RECENT, "label": "最近使用"},
		{"id": DECK_PICKER_ALL, "label": "全部"},
	]:
		var button := Button.new()
		button.text = str(tab.get("label", ""))
		button.custom_minimum_size = Vector2(96, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_deck_picker_category_pressed.bind(str(tab.get("id", ""))))
		tabs.add_child(button)
		_deck_picker_tabs[str(tab.get("id", ""))] = button

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	HudThemeScript.style_scroll_container(scroll)
	root.add_child(scroll)

	_deck_picker_grid = GridContainer.new()
	_deck_picker_grid.name = "DeckPickerGrid"
	_deck_picker_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_picker_grid.add_theme_constant_override("h_separation", 10)
	_deck_picker_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_deck_picker_grid)


func _resize_deck_picker_panel() -> void:
	if _deck_picker_panel == null:
		return
	var viewport_size := _deck_picker_viewport_size()
	_deck_picker_panel.custom_minimum_size = Vector2(
		maxf(360.0, minf(940.0, viewport_size.x * 0.92)),
		maxf(420.0, minf(760.0, viewport_size.y * 0.88))
	)


func _deck_picker_viewport_size() -> Vector2:
	if is_inside_tree():
		return get_viewport_rect().size
	return Vector2(1280, 720)


func _close_deck_picker() -> void:
	if _deck_picker_overlay != null and is_instance_valid(_deck_picker_overlay):
		_deck_picker_overlay.visible = false


func _on_deck_picker_search_changed(text: String) -> void:
	_deck_picker_search = text.strip_edges()
	_refresh_deck_picker()


func _on_deck_picker_category_pressed(category: String) -> void:
	_deck_picker_category = category
	_refresh_deck_picker()


func _refresh_deck_picker() -> void:
	if _deck_picker_grid == null:
		return
	_deck_picker_grid.columns = 1 if _deck_picker_viewport_size().x < 760.0 else 2
	for child: Node in _deck_picker_grid.get_children():
		child.queue_free()
	_refresh_deck_picker_tabs()

	var decks := _decks_for_picker(_deck_picker_category, _deck_picker_search)
	if _deck_picker_subtitle != null:
		_deck_picker_subtitle.text = _deck_picker_subtitle_text(_deck_picker_category, decks.size())
	if decks.is_empty():
		var empty := Label.new()
		empty.text = "没有找到符合条件的卡组"
		empty.custom_minimum_size = Vector2(0, 90)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_style_hud_label(empty)
		_deck_picker_grid.add_child(empty)
		return

	var selected_deck := _selected_deck()
	var selected_id := selected_deck.id if selected_deck != null else -1
	var count := 0
	for deck: DeckData in decks:
		if count >= DECK_PICKER_LIMIT:
			break
		var is_selected := deck.id == selected_id
		var button := Button.new()
		button.text = "%s\n%s" % [deck.deck_name, _deck_picker_card_meta(deck)]
		button.tooltip_text = _deck_picker_card_tooltip(deck)
		button.custom_minimum_size = Vector2(0, 76)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", HUD_TEXT)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _deck_picker_card_style(is_selected, false))
		button.add_theme_stylebox_override("hover", _deck_picker_card_style(is_selected, true))
		button.add_theme_stylebox_override("pressed", _deck_picker_card_pressed_style())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(_on_deck_picker_deck_selected.bind(deck.id))
		_deck_picker_grid.add_child(button)
		count += 1


func _refresh_deck_picker_tabs() -> void:
	for category_variant: Variant in _deck_picker_tabs.keys():
		var category := str(category_variant)
		var button := _deck_picker_tabs[category] as Button
		if button == null:
			continue
		var active := category == _deck_picker_category
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", Color(0.05, 0.10, 0.13, 1.0) if active else HUD_TEXT)
		button.add_theme_stylebox_override("normal", _deck_picker_tab_style(active, false))
		button.add_theme_stylebox_override("hover", _deck_picker_tab_style(active, true))
		button.add_theme_stylebox_override("pressed", _deck_picker_tab_style(true, true))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _on_deck_picker_deck_selected(deck_id: int) -> void:
	_select_deck_id(deck_id)
	_close_deck_picker()


func _decks_for_picker(category: String, search: String) -> Array[DeckData]:
	var decks: Array[DeckData] = []
	for deck: DeckData in _decks:
		if _deck_matches_search(deck, search):
			decks.append(deck)

	match category:
		DECK_PICKER_RECENT:
			decks = decks.filter(func(deck: DeckData) -> bool:
				return _deck_last_used(deck) != ""
			)
			decks.sort_custom(func(a: DeckData, b: DeckData) -> bool:
				var au := _deck_last_used(a)
				var bu := _deck_last_used(b)
				if au == bu:
					return _deck_import_key(a) > _deck_import_key(b)
				return au > bu
			)
			if decks.is_empty() and search == "":
				decks = _fallback_decks_for_picker()
		_:
			decks.sort_custom(func(a: DeckData, b: DeckData) -> bool:
				if _deck_import_key(a) == _deck_import_key(b):
					return a.deck_name < b.deck_name
				return _deck_import_key(a) > _deck_import_key(b)
			)
	return decks


func _fallback_decks_for_picker() -> Array[DeckData]:
	var result: Array[DeckData] = []
	var selected := _selected_deck()
	if selected != null:
		result.append(selected)
	var latest: Array[DeckData] = []
	for deck: DeckData in _decks:
		if selected != null and deck.id == selected.id:
			continue
		latest.append(deck)
	latest.sort_custom(func(a: DeckData, b: DeckData) -> bool:
		if _deck_import_key(a) == _deck_import_key(b):
			return a.deck_name < b.deck_name
		return _deck_import_key(a) > _deck_import_key(b)
	)
	for deck: DeckData in latest:
		if result.size() >= 8:
			break
		result.append(deck)
	return result


func _deck_matches_search(deck: DeckData, search: String) -> bool:
	if deck == null:
		return false
	var query := search.strip_edges().to_lower()
	if query == "":
		return true
	return (
		deck.deck_name.to_lower().contains(query)
		or deck.variant_name.to_lower().contains(query)
		or str(deck.id).contains(query)
	)


func _deck_picker_subtitle_text(category: String, count: int) -> String:
	var category_text := "全部卡组"
	match category:
		DECK_PICKER_RECENT:
			category_text = "最近使用"
	return "比赛模式卡组选择 · %s · %d 套" % [category_text, count]


func _deck_picker_card_meta(deck: DeckData) -> String:
	var parts: Array[String] = []
	var use_count := _deck_use_count(deck)
	if use_count > 0:
		parts.append("使用%d次" % use_count)
	var last_used := _deck_last_used(deck)
	if last_used != "":
		parts.append("最近使用")
	if deck.variant_name != "" and deck.variant_name != deck.deck_name:
		parts.append(deck.variant_name)
	if parts.is_empty():
		parts.append("点击选择")
	return " · ".join(parts)


func _deck_picker_card_tooltip(deck: DeckData) -> String:
	var lines := PackedStringArray([
		"ID: %d" % deck.id,
		"名称: %s" % deck.deck_name,
	])
	var last_used := _deck_last_used(deck)
	if last_used != "":
		lines.append("最近使用过")
	var use_count := _deck_use_count(deck)
	if use_count > 0:
		lines.append("使用次数: %d" % use_count)
	return "\n".join(lines)


func _load_deck_usage_stats() -> void:
	_deck_usage_stats.clear()
	if not FileAccess.file_exists(DECK_USAGE_STATS_PATH):
		return
	var file := FileAccess.open(DECK_USAGE_STATS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	var decks_raw: Variant = (parsed as Dictionary).get("decks", {})
	if decks_raw is Dictionary:
		_deck_usage_stats = decks_raw as Dictionary


func _save_deck_usage_stats() -> void:
	var file := FileAccess.open(DECK_USAGE_STATS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"decks": _deck_usage_stats}, "\t"))
	file.close()


func _record_tournament_deck_usage(deck: DeckData) -> void:
	if deck == null or deck.id <= 0:
		return
	var key := str(deck.id)
	var entry := _deck_usage_entry(deck.id).duplicate(true)
	entry["use_count"] = int(entry.get("use_count", 0)) + 1
	entry["last_used"] = Time.get_datetime_string_from_system(false, true)
	entry["deck_name"] = deck.deck_name
	_deck_usage_stats[key] = entry
	_save_deck_usage_stats()


func _deck_usage_entry(deck_id: int) -> Dictionary:
	var raw: Variant = _deck_usage_stats.get(str(deck_id), {})
	return raw if raw is Dictionary else {}


func _deck_use_count(deck: DeckData) -> int:
	if deck == null:
		return 0
	return int(_deck_usage_entry(deck.id).get("use_count", 0))


func _deck_last_used(deck: DeckData) -> String:
	if deck == null:
		return ""
	return str(_deck_usage_entry(deck.id).get("last_used", ""))


func _deck_import_key(deck: DeckData) -> String:
	if deck == null:
		return ""
	return str(deck.import_date)


func _on_back_pressed() -> void:
	GameManager.goto_main_menu()


func _on_next_pressed() -> void:
	var deck: DeckData = _selected_deck()
	if deck == null:
		return
	_record_tournament_deck_usage(deck)
	GameManager.set_tournament_selected_player_deck_id(deck.id)
	GameManager.goto_tournament_setup()


func _style_deck_picker_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", HUD_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _deck_picker_button_style(false, false))
	button.add_theme_stylebox_override("hover", _deck_picker_button_style(true, false))
	button.add_theme_stylebox_override("pressed", _deck_picker_button_style(true, true))
	button.add_theme_stylebox_override("disabled", HudThemeScript.button_style(Color(0.26, 0.31, 0.36, 1.0), false, false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style_hud_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.08, 0.12, 0.16, 1.0))
	button.add_theme_stylebox_override("normal", HudThemeScript.button_style(HUD_ACCENT, false, false))
	button.add_theme_stylebox_override("hover", HudThemeScript.button_style(HUD_ACCENT, true, false))
	button.add_theme_stylebox_override("pressed", HudThemeScript.button_style(HUD_ACCENT, true, true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style_hud_label(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", HUD_TEXT_MUTED)


func _style_hud_line_edit(line_edit: LineEdit) -> void:
	line_edit.add_theme_font_size_override("font_size", 15)
	line_edit.add_theme_color_override("font_color", HUD_TEXT)
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.62, 0.74, 0.82, 0.88))
	line_edit.add_theme_stylebox_override("normal", HudThemeScript.input_style(false))
	line_edit.add_theme_stylebox_override("focus", HudThemeScript.input_style(true))


func _hud_picker_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.045, 0.070, 0.86)
	style.border_color = Color(0.32, 0.90, 1.0, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.0, 0.62, 0.95, 0.30)
	style.shadow_size = 18
	style.set_content_margin_all(2)
	return style


func _deck_picker_button_style(hover: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.052, 0.078, 0.94)
	if hover:
		style.bg_color = Color(0.03, 0.10, 0.13, 0.98)
	if pressed:
		style.bg_color = Color(0.22, 0.78, 1.0, 0.92)
	style.border_color = Color(0.28, 0.90, 1.0, 0.86 if hover else 0.58)
	style.set_border_width_all(2 if hover else 1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.58, 0.9, 0.20 if hover else 0.10)
	style.shadow_size = 8 if hover else 3
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _deck_picker_tab_style(active: bool, hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.83, 1.0, 0.92) if active else Color(0.02, 0.055, 0.08, 0.90)
	if hover and not active:
		style.bg_color = Color(0.04, 0.12, 0.16, 0.96)
	style.border_color = Color(0.36, 0.92, 1.0, 0.86 if active or hover else 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _deck_picker_card_style(selected: bool, hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.065, 0.095, 0.92)
	if hover:
		style.bg_color = Color(0.04, 0.12, 0.16, 0.98)
	if selected:
		style.bg_color = Color(0.06, 0.15, 0.19, 0.98)
	style.border_color = Color(1.0, 0.62, 0.28, 1.0) if selected else Color(0.25, 0.82, 1.0, 0.55 if not hover else 0.92)
	style.set_border_width_all(2 if selected or hover else 1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.62, 0.9, 0.16 if hover else 0.08)
	style.shadow_size = 8 if hover else 3
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style


func _deck_picker_card_pressed_style() -> StyleBoxFlat:
	var style := _deck_picker_card_style(true, true)
	style.bg_color = Color(0.22, 0.82, 1.0, 0.94)
	return style
