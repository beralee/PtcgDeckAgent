class_name DeckViewDialog
extends RefCounted

const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
const CARD_TILE_WIDTH := 100
const CARD_TILE_HEIGHT := 140
const VIEW_GRID_COLUMNS := 6
const PORTRAIT_VIEW_GRID_COLUMNS := 3
const CARD_LIST_DRAG_SCROLL_THRESHOLD := 10.0
const CARD_LIST_DRAG_CLICK_SUPPRESS_MSEC := 180
const CARD_LIST_DRAG_SCROLL_SENSITIVITY := 1.35

const ENERGY_TYPE_LABELS: Dictionary = {
	"R": "火", "W": "水", "G": "草", "L": "雷",
	"P": "超", "F": "斗", "D": "恶", "M": "钢", "N": "龙", "C": "无色",
}

const VIEW_CATEGORY_ORDER: Dictionary = {
	"Pokemon": 0,
	"Item": 1,
	"Tool": 2,
	"Supporter": 3,
	"Stadium": 4,
	"Basic Energy": 5,
	"Special Energy": 6,
}

var _texture_cache: Dictionary = {}
var _failed_texture_paths: Dictionary = {}


func show_deck(host: Node, deck: DeckData) -> void:
	if host == null or deck == null:
		return
	var layout := _deck_view_layout_profile(host, deck.total_cards)
	var portrait := bool(layout.get("portrait", false))
	var dialog := AcceptDialog.new()
	dialog.name = "DeckViewDialog"
	dialog.title = deck.deck_name
	dialog.size = layout.get("dialog_size", Vector2i(800, 700))
	dialog.min_size = dialog.size
	dialog.ok_button_text = "关闭"

	var margin := MarginContainer.new()
	margin.anchors_preset = Control.PRESET_FULL_RECT
	var margin_value := int(layout.get("margin", 8))
	margin.offset_left = margin_value
	margin.offset_top = margin_value
	margin.offset_right = -margin_value
	margin.offset_bottom = -margin_value
	margin.add_theme_constant_override("margin_left", margin_value)
	margin.add_theme_constant_override("margin_top", margin_value)
	margin.add_theme_constant_override("margin_right", margin_value)
	margin.add_theme_constant_override("margin_bottom", margin_value)
	dialog.add_child(margin)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", int(layout.get("gap", 8)))
	margin.add_child(outer)

	var info_label := Label.new()
	info_label.name = "DeckViewInfoLabel"
	info_label.text = "ID: %d | %d 张卡牌" % [deck.id, deck.total_cards]
	info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_label.add_theme_font_size_override("font_size", int(layout.get("info_font_size", 14)))
	outer.add_child(info_label)

	var scroll := ScrollContainer.new()
	scroll.name = "DeckViewCardScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	HudThemeScript.style_scroll_container(scroll, "auto")
	if portrait:
		NonBattleTouchBridgeScript.configure_hidden_vertical_drag_scroll(scroll)
	else:
		NonBattleTouchBridgeScript.configure_visible_vertical_scroll(scroll)
	outer.add_child(scroll)

	var grid := GridContainer.new()
	grid.name = "DeckViewCardGrid"
	grid.columns = int(layout.get("columns", VIEW_GRID_COLUMNS))
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.custom_minimum_size.x = float(layout.get("grid_min_width", 0.0))
	grid.add_theme_constant_override("h_separation", int(layout.get("gap", 6)))
	grid.add_theme_constant_override("v_separation", int(layout.get("gap", 6)))
	scroll.add_child(grid)
	_configure_card_list_drag_scroll(scroll, grid, portrait)

	var tile_width := int(layout.get("tile_width", CARD_TILE_WIDTH))
	var tile_height := int(layout.get("tile_height", CARD_TILE_HEIGHT))
	var label_font_size := int(layout.get("card_label_font_size", HudThemeScript.scaled_font_size(11)))
	for entry: Dictionary in _sort_entries_by_category(deck.cards):
		var card_name: String = entry.get("name", "?")
		var set_code: String = entry.get("set_code", "")
		var card_index: String = entry.get("card_index", "")
		var count: int = entry.get("count", 0)
		for _i: int in count:
			var tile := _create_view_tile(card_name, set_code, card_index, tile_width, tile_height, label_font_size)
			tile.gui_input.connect(_on_view_tile_input.bind(host, scroll, set_code, card_index))
			grid.add_child(tile)

	var content_close_button: Button = null
	if portrait:
		content_close_button = Button.new()
		content_close_button.name = "DeckViewCloseButton"
		content_close_button.text = "关闭"
		content_close_button.custom_minimum_size = Vector2(0.0, float(layout.get("ok_button_height", 96.0)))
		content_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_close_button.add_theme_font_size_override("font_size", int(layout.get("button_font_size", 32)))
		content_close_button.pressed.connect(dialog.queue_free)
		NonBattleTouchBridgeScript.bind_button_touch(content_close_button)
		outer.add_child(content_close_button)

	host.add_child(dialog)
	var ok_button := dialog.get_ok_button()
	if ok_button != null:
		if portrait:
			ok_button.visible = false
		else:
			ok_button.custom_minimum_size.y = float(layout.get("ok_button_height", 42.0))
			ok_button.add_theme_font_size_override("font_size", int(layout.get("button_font_size", 15)))
	if dialog.is_inside_tree():
		if portrait:
			dialog.popup(Rect2i(layout.get("dialog_position", Vector2i.ZERO), dialog.size))
		else:
			dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


func _deck_view_layout_profile(host: Node, total_cards: int) -> Dictionary:
	var viewport_size := _host_viewport_size(host)
	var portrait := viewport_size.y > viewport_size.x and viewport_size.x >= 360.0
	if portrait:
		var page_margin := clampf(viewport_size.x * 0.026, 24.0, 34.0)
		var dialog_size := Vector2i(
			roundi(maxf(320.0, viewport_size.x - page_margin * 2.0)),
			roundi(maxf(620.0, viewport_size.y - page_margin * 2.0))
		)
		var content_margin := roundi(clampf(viewport_size.x * 0.022, 22.0, 30.0))
		var gap := roundi(clampf(viewport_size.x * 0.012, 10.0, 16.0))
		var available_width := maxf(float(dialog_size.x) - float(content_margin * 2) - float(gap * (PORTRAIT_VIEW_GRID_COLUMNS - 1)), 1.0)
		var tile_width := roundi(clampf(floor(available_width / float(PORTRAIT_VIEW_GRID_COLUMNS)), 250.0, 310.0))
		var grid_width := float(tile_width * PORTRAIT_VIEW_GRID_COLUMNS + gap * (PORTRAIT_VIEW_GRID_COLUMNS - 1))
		return {
			"portrait": true,
			"columns": PORTRAIT_VIEW_GRID_COLUMNS,
			"dialog_position": Vector2i(roundi(page_margin), roundi(page_margin)),
			"dialog_size": dialog_size,
			"margin": content_margin,
			"gap": gap,
			"tile_width": tile_width,
			"tile_height": roundi(float(tile_width) * 1.40),
			"grid_min_width": grid_width,
			"info_font_size": roundi(clampf(viewport_size.x / 1080.0, 1.0, 1.18) * 31.0),
			"card_label_font_size": roundi(clampf(viewport_size.x / 1080.0, 1.0, 1.18) * 25.0),
			"button_font_size": roundi(clampf(viewport_size.x / 1080.0, 1.0, 1.18) * 32.0),
			"ok_button_height": clampf(viewport_size.y * 0.052, 96.0, 128.0),
		}
	var cols := VIEW_GRID_COLUMNS
	var rows := ceili(float(total_cards) / float(cols))
	var w := mini(cols * (CARD_TILE_WIDTH + 6) + 60, 800)
	var h := mini(rows * (CARD_TILE_HEIGHT + 26) + 100, 700)
	return {
		"portrait": false,
		"columns": cols,
		"dialog_position": Vector2i.ZERO,
		"dialog_size": Vector2i(w, h),
		"margin": 8,
		"gap": 6,
		"tile_width": CARD_TILE_WIDTH,
		"tile_height": CARD_TILE_HEIGHT,
		"info_font_size": HudThemeScript.scaled_font_size(14),
		"card_label_font_size": HudThemeScript.scaled_font_size(11),
		"button_font_size": 15,
		"ok_button_height": 42.0,
	}


func _host_viewport_size(host: Node) -> Vector2:
	if host is Control:
		var host_control := host as Control
		if host_control.size.x > 0.0 and host_control.size.y > 0.0:
			return host_control.size
	if host != null and host.is_inside_tree():
		var viewport := host.get_viewport()
		if viewport != null:
			var viewport_size := viewport.get_visible_rect().size
			if viewport_size.x > 0.0 and viewport_size.y > 0.0:
				return viewport_size
	return Vector2(1600, 900)


func _configure_card_list_drag_scroll(scroll: ScrollContainer, grid: Control = null, hidden_scrollbar: bool = true) -> void:
	if scroll == null:
		return
	scroll.clip_contents = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	if hidden_scrollbar:
		NonBattleTouchBridgeScript.configure_hidden_vertical_drag_scroll(scroll)
	else:
		NonBattleTouchBridgeScript.configure_visible_vertical_scroll(scroll)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.set_meta("deck_card_list_drag_scroll_enabled", true)
	scroll.set_meta("deck_card_list_drag_active", false)
	scroll.set_meta("deck_card_list_dragging", false)
	scroll.set_meta("deck_card_list_drag_suppress_until_msec", 0)
	var input_callable := Callable(self, "_on_card_list_scroll_input").bind(scroll)
	if not scroll.gui_input.is_connected(input_callable):
		scroll.gui_input.connect(input_callable)
	if grid != null:
		grid.mouse_filter = Control.MOUSE_FILTER_STOP
		if not grid.gui_input.is_connected(input_callable):
			grid.gui_input.connect(input_callable)


func _on_card_list_scroll_input(event: InputEvent, scroll: ScrollContainer) -> void:
	_handle_card_list_drag_scroll_input(event, scroll)


func _handle_card_list_drag_scroll_input(event: InputEvent, scroll: ScrollContainer) -> bool:
	if scroll == null or not bool(scroll.get_meta("deck_card_list_drag_scroll_enabled", false)):
		return false
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if _handle_card_list_wheel(mouse_button, scroll):
			_accept_scroll_event(scroll)
			return true
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mouse_button.pressed:
			_begin_card_list_drag_scroll(_card_list_drag_event_position(event), scroll)
			_accept_scroll_event(scroll)
			return true
		return _end_card_list_drag_scroll(scroll)
	if event is InputEventMouseMotion and bool(scroll.get_meta("deck_card_list_drag_active", false)):
		return _update_card_list_drag_scroll(_card_list_drag_event_position(event), scroll)
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_card_list_drag_scroll(touch.position, scroll)
			_accept_scroll_event(scroll)
			return true
		return _end_card_list_drag_scroll(scroll)
	if event is InputEventScreenDrag and bool(scroll.get_meta("deck_card_list_drag_active", false)):
		return _update_card_list_drag_scroll((event as InputEventScreenDrag).position, scroll)
	return false


func _handle_card_list_wheel(mouse_button: InputEventMouseButton, scroll: ScrollContainer) -> bool:
	if not mouse_button.pressed:
		return false
	var direction := 0
	match mouse_button.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			direction = -1
		MOUSE_BUTTON_WHEEL_DOWN:
			direction = 1
		_:
			return false
	_set_card_list_scroll_vertical(scroll, scroll.scroll_vertical + direction * CARD_TILE_HEIGHT)
	return true


func _begin_card_list_drag_scroll(position: Vector2, scroll: ScrollContainer) -> void:
	scroll.set_meta("deck_card_list_drag_active", true)
	scroll.set_meta("deck_card_list_dragging", false)
	scroll.set_meta("deck_card_list_drag_start_position", position)
	scroll.set_meta("deck_card_list_drag_start_scroll", scroll.scroll_vertical)


func _update_card_list_drag_scroll(position: Vector2, scroll: ScrollContainer) -> bool:
	var start_position := _as_vector2(scroll.get_meta("deck_card_list_drag_start_position", Vector2.ZERO), Vector2.ZERO)
	var delta := position - start_position
	if not bool(scroll.get_meta("deck_card_list_dragging", false)) and absf(delta.y) < CARD_LIST_DRAG_SCROLL_THRESHOLD:
		return false
	scroll.set_meta("deck_card_list_dragging", true)
	var start_scroll := int(scroll.get_meta("deck_card_list_drag_start_scroll", 0))
	_set_card_list_scroll_vertical(scroll, start_scroll - roundi(delta.y * CARD_LIST_DRAG_SCROLL_SENSITIVITY))
	_accept_scroll_event(scroll)
	return true


func _end_card_list_drag_scroll(scroll: ScrollContainer) -> bool:
	var was_dragging := bool(scroll.get_meta("deck_card_list_dragging", false))
	scroll.set_meta("deck_card_list_drag_active", false)
	scroll.set_meta("deck_card_list_dragging", false)
	if was_dragging:
		scroll.set_meta("deck_card_list_drag_suppress_until_msec", Time.get_ticks_msec() + CARD_LIST_DRAG_CLICK_SUPPRESS_MSEC)
		_accept_scroll_event(scroll)
	return was_dragging


func _set_card_list_scroll_vertical(scroll: ScrollContainer, value: int) -> void:
	var target := maxi(0, value)
	var max_scroll := _card_list_max_vertical_scroll(scroll)
	if max_scroll > 0:
		target = mini(target, max_scroll)
	scroll.scroll_vertical = target


func _card_list_max_vertical_scroll(scroll: ScrollContainer) -> int:
	if scroll == null:
		return 0
	var bar := scroll.get_v_scroll_bar()
	if bar == null:
		return 0
	return maxi(0, roundi(bar.max_value - bar.page))


func _is_card_list_drag_click_suppressed(scroll: ScrollContainer) -> bool:
	if scroll == null:
		return false
	return Time.get_ticks_msec() < int(scroll.get_meta("deck_card_list_drag_suppress_until_msec", 0))


func _card_list_drag_event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return (event as InputEventMouse).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	return Vector2.ZERO


func _accept_scroll_event(scroll: ScrollContainer) -> void:
	if scroll != null:
		scroll.accept_event()


func _as_vector2(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _sort_entries_by_category(cards: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = cards.duplicate()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa: int = VIEW_CATEGORY_ORDER.get(a.get("card_type", ""), 99)
		var ob: int = VIEW_CATEGORY_ORDER.get(b.get("card_type", ""), 99)
		if oa != ob:
			return oa < ob
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return result


func _create_view_tile(card_name: String, set_code: String, card_index: String, tile_width: int = CARD_TILE_WIDTH, tile_height: int = CARD_TILE_HEIGHT, label_font_size: int = -1) -> PanelContainer:
	var panel := PanelContainer.new()
	var label_height := maxf(22.0, float(label_font_size + 14))
	panel.custom_minimum_size = Vector2(tile_width, float(tile_height) + label_height)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.22, 0.3, 1.0)
	sb.border_color = Color(0.3, 0.32, 0.4, 1.0)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var tex_rect := TextureRect.new()
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.custom_minimum_size = Vector2(tile_width - 8, tile_height - 8)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var texture := _load_card_texture(set_code, card_index)
	if texture != null:
		tex_rect.texture = texture
	else:
		var placeholder := PlaceholderTexture2D.new()
		placeholder.size = Vector2(tile_width - 8, tile_height - 8)
		tex_rect.texture = placeholder
	vbox.add_child(tex_rect)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = card_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", label_font_size if label_font_size > 0 else HudThemeScript.scaled_font_size(11))
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(tile_width - 8, label_height)
	vbox.add_child(label)

	return panel


func _on_view_tile_input(event: InputEvent, host: Node, scroll: ScrollContainer, set_code: String, card_index: String) -> void:
	if _handle_card_list_drag_scroll_input(event, scroll):
		return
	if _is_card_list_drag_click_suppressed(scroll):
		return
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		return
	if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		var card := CardDatabase.get_card(set_code, card_index)
		if card != null:
			_show_card_detail(host, card)


func _show_card_detail(host: Node, card: CardData) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = card.name
	dialog.ok_button_text = "关闭"
	dialog.size = Vector2i(500, 480)

	var scroll := ScrollContainer.new()
	scroll.anchors_preset = Control.PRESET_FULL_RECT
	scroll.offset_left = 8
	scroll.offset_top = 8
	scroll.offset_right = -8
	scroll.offset_bottom = -8
	HudThemeScript.style_scroll_container(scroll)
	dialog.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	var header := Label.new()
	header.text = card.name
	header.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(20))
	content.add_child(header)

	var meta_parts: PackedStringArray = []
	meta_parts.append(card.card_type)
	if card.mechanic != "":
		meta_parts.append(card.mechanic)
	if card.set_code != "":
		meta_parts.append("%s %s" % [card.set_code, card.card_index])
	if card.rarity != "":
		meta_parts.append(card.rarity)
	var meta_label := Label.new()
	meta_label.text = " | ".join(meta_parts)
	meta_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	content.add_child(meta_label)

	if card.is_pokemon():
		_add_detail_separator(content)
		var stat_parts: PackedStringArray = []
		stat_parts.append("HP %d" % card.hp)
		stat_parts.append("属性: %s" % _energy_display(card.energy_type))
		stat_parts.append("阶段: %s" % card.stage)
		stat_parts.append("撤退: %d" % card.retreat_cost)
		var stat_label := Label.new()
		stat_label.text = " | ".join(stat_parts)
		content.add_child(stat_label)

		if card.evolves_from != "":
			var evo_label := Label.new()
			evo_label.text = "从 %s 进化" % card.evolves_from
			content.add_child(evo_label)

		var weakness_text := ""
		if card.weakness_energy != "":
			weakness_text = "弱点: %s %s" % [_energy_display(card.weakness_energy), card.weakness_value]
		var resist_text := ""
		if card.resistance_energy != "":
			resist_text = "抗性: %s %s" % [_energy_display(card.resistance_energy), card.resistance_value]
		if weakness_text != "" or resist_text != "":
			var wr_label := Label.new()
			wr_label.text = "  ".join([weakness_text, resist_text]).strip_edges()
			content.add_child(wr_label)

		for ab: Dictionary in card.abilities:
			_add_detail_separator(content)
			var ab_title := Label.new()
			ab_title.text = "[特性] %s" % ab.get("name", "")
			ab_title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
			content.add_child(ab_title)
			if ab.get("text", "") != "":
				var ab_text := Label.new()
				ab_text.text = str(ab.get("text", ""))
				ab_text.autowrap_mode = TextServer.AUTOWRAP_WORD
				content.add_child(ab_text)

		for atk: Dictionary in card.attacks:
			_add_detail_separator(content)
			var cost_str: String = str(atk.get("cost", ""))
			var dmg_str: String = str(atk.get("damage", ""))
			var atk_header := Label.new()
			var parts: PackedStringArray = []
			if cost_str != "":
				parts.append("[%s]" % cost_str)
			parts.append(str(atk.get("name", "")))
			if dmg_str != "":
				parts.append(dmg_str)
			atk_header.text = " ".join(parts)
			atk_header.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
			content.add_child(atk_header)
			if atk.get("text", "") != "":
				var atk_text := Label.new()
				atk_text.text = str(atk.get("text", ""))
				atk_text.autowrap_mode = TextServer.AUTOWRAP_WORD
				content.add_child(atk_text)

	if card.description != "":
		_add_detail_separator(content)
		var desc := Label.new()
		desc.text = card.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		content.add_child(desc)

	if card.effect_id != "":
		_add_detail_separator(content)
		var eid := Label.new()
		eid.text = "效果ID: %s" % card.effect_id
		eid.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		content.add_child(eid)

	if card.name_en != "":
		var en_label := Label.new()
		en_label.text = "英文名: %s" % card.name_en
		en_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		content.add_child(en_label)

	host.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


func _add_detail_separator(container: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	container.add_child(sep)


func _energy_display(energy_code: String) -> String:
	return ENERGY_TYPE_LABELS.get(energy_code, energy_code)


func _load_card_texture(set_code: String, card_index: String) -> Texture2D:
	var file_path := CardData.resolve_existing_image_path(
		CardData.get_image_candidate_paths(set_code, card_index)
	)
	if file_path == "":
		return null
	if _texture_cache.has(file_path):
		return _texture_cache[file_path]
	if _failed_texture_paths.has(file_path):
		return null
	var image_bytes := FileAccess.get_file_as_bytes(file_path)
	if image_bytes.is_empty():
		_failed_texture_paths[file_path] = true
		return null
	var image := Image.new()
	var err := _load_image_from_buffer(image, image_bytes)
	if err != OK:
		_failed_texture_paths[file_path] = true
		return null
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[file_path] = texture
	return texture


func _load_image_from_buffer(image: Image, image_bytes: PackedByteArray) -> int:
	if image_bytes.size() >= 12:
		if image_bytes[0] == 0x89 and image_bytes[1] == 0x50 and image_bytes[2] == 0x4E and image_bytes[3] == 0x47:
			return image.load_png_from_buffer(image_bytes)
		if image_bytes[0] == 0xFF and image_bytes[1] == 0xD8:
			return image.load_jpg_from_buffer(image_bytes)
		if image_bytes[0] == 0x52 and image_bytes[1] == 0x49 and image_bytes[2] == 0x46 and image_bytes[3] == 0x46:
			if image_bytes[8] == 0x57 and image_bytes[9] == 0x45 and image_bytes[10] == 0x42 and image_bytes[11] == 0x50:
				return image.load_webp_from_buffer(image_bytes)
	return ERR_FILE_UNRECOGNIZED
