class_name DeckViewDialog
extends RefCounted

const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
const DECK_IMAGE_ACCENT := Color(0.72, 0.64, 1.0, 1.0)
const CardImageOrProxyViewScript := preload("res://scripts/ui/cards/CardImageOrProxyView.gd")
const CARD_TILE_WIDTH := 96
const CARD_TILE_HEIGHT := 134
const VIEW_GRID_COLUMNS := 8
const PORTRAIT_VIEW_GRID_COLUMNS := 4
const PORTRAIT_COMPACT_WIDTH := 600.0
const CARD_LIST_DRAG_SCROLL_THRESHOLD := 10.0
const CARD_LIST_DRAG_CLICK_SUPPRESS_MSEC := 180
const CARD_LIST_DRAG_SCROLL_SENSITIVITY := 1.0

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


func show_deck(host: Node, deck: DeckData, image_cache_service: Object = null) -> void:
	if host == null or deck == null:
		return
	var view_entries := _unique_deck_view_entries(deck.cards)
	var layout := _deck_view_layout_profile(host, view_entries.size())
	var portrait := bool(layout.get("portrait", false))
	var dialog := AcceptDialog.new()
	dialog.name = "DeckViewDialog"
	dialog.title = deck.deck_name
	dialog.size = layout.get("dialog_size", Vector2i(800, 700))
	dialog.min_size = dialog.size
	_apply_deck_view_dialog_hud(dialog)
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
	info_label.add_theme_color_override("font_color", HudThemeScript.TEXT_MUTED)
	info_label.add_theme_font_size_override("font_size", int(layout.get("info_font_size", 14)))
	outer.add_child(info_label)

	var scroll := ScrollContainer.new()
	scroll.name = "DeckViewCardScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	HudThemeScript.style_scroll_container(scroll, "compact")
	NonBattleTouchBridgeScript.configure_hidden_vertical_drag_scroll(scroll)
	outer.add_child(scroll)

	var grid := GridContainer.new()
	grid.name = "DeckViewCardGrid"
	grid.columns = int(layout.get("columns", VIEW_GRID_COLUMNS))
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.custom_minimum_size.x = float(layout.get("grid_min_width", 0.0))
	grid.add_theme_constant_override("h_separation", int(layout.get("gap", 6)))
	grid.add_theme_constant_override("v_separation", int(layout.get("gap", 6)))
	scroll.add_child(grid)
	_configure_card_list_drag_scroll(scroll, grid, true)

	var tile_width := int(layout.get("tile_width", CARD_TILE_WIDTH))
	var tile_height := int(layout.get("tile_height", CARD_TILE_HEIGHT))
	var label_font_size := int(layout.get("card_label_font_size", HudThemeScript.scaled_font_size(11)))
	for entry: Dictionary in view_entries:
		var card_name: String = entry.get("name", "?")
		var set_code: String = entry.get("set_code", "")
		var card_index: String = entry.get("card_index", "")
		var count: int = entry.get("count", 0)
		var tile := _create_view_tile_with_cache(card_name, set_code, card_index, tile_width, tile_height, label_font_size, count, image_cache_service, portrait)
		tile.gui_input.connect(_on_view_tile_input.bind(host, scroll, set_code, card_index))
		grid.add_child(tile)

	var share_button := Button.new()
	share_button.name = "DeckViewSharePosterButton"
	share_button.text = "保存卡组图"
	share_button.custom_minimum_size = Vector2(0.0, float(layout.get("ok_button_height", 96.0 if portrait else 42.0)))
	share_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	share_button.add_theme_font_size_override("font_size", int(layout.get("button_font_size", 15)))
	share_button.add_theme_stylebox_override("normal", HudThemeScript.button_style(DECK_IMAGE_ACCENT, false, false))
	share_button.add_theme_stylebox_override("hover", HudThemeScript.button_style(DECK_IMAGE_ACCENT, true, false))
	share_button.add_theme_stylebox_override("pressed", HudThemeScript.button_style(DECK_IMAGE_ACCENT, true, true))
	share_button.pressed.connect(_on_share_poster_pressed.bind(host, dialog, deck))
	NonBattleTouchBridgeScript.bind_button_touch(share_button)
	outer.add_child(share_button)

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


func _on_share_poster_pressed(host: Node, dialog: AcceptDialog, deck: DeckData) -> void:
	if dialog != null and is_instance_valid(dialog):
		dialog.queue_free()
	if host != null and host.has_method("_on_share_deck_poster"):
		host.call("_on_share_deck_poster", deck)


func _apply_deck_view_dialog_hud(dialog: AcceptDialog) -> void:
	if dialog == null:
		return
	dialog.add_theme_stylebox_override("panel", _deck_view_dialog_style())
	dialog.add_theme_color_override("title_color", HudThemeScript.TEXT)


func _deck_view_dialog_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.036, 0.052, 0.94)
	style.border_color = Color(0.28, 0.92, 1.0, 0.88)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.62, 0.82, 0.24)
	style.shadow_size = 14
	style.set_content_margin_all(8)
	return style


func _unique_deck_view_entries(cards: Array[Dictionary]) -> Array[Dictionary]:
	var merged_by_key: Dictionary = {}
	var ordered_keys: PackedStringArray = PackedStringArray()
	for entry: Dictionary in cards:
		var count := maxi(0, int(entry.get("count", 0)))
		if count <= 0:
			continue
		var key := _deck_view_entry_key(entry)
		if key == "":
			continue
		if not merged_by_key.has(key):
			var merged := entry.duplicate(true)
			merged["count"] = count
			merged["_deck_view_key"] = key
			merged_by_key[key] = merged
			ordered_keys.append(key)
			continue
		var existing := merged_by_key[key] as Dictionary
		existing["count"] = int(existing.get("count", 0)) + count
		if str(existing.get("name", "")).strip_edges() == "" and str(entry.get("name", "")).strip_edges() != "":
			existing["name"] = str(entry.get("name", ""))
		if str(existing.get("card_type", "")).strip_edges() == "" and str(entry.get("card_type", "")).strip_edges() != "":
			existing["card_type"] = str(entry.get("card_type", ""))

	var result: Array[Dictionary] = []
	for key: String in ordered_keys:
		if merged_by_key.has(key):
			result.append(merged_by_key[key] as Dictionary)
	return _sort_entries_by_category(result)


func _deck_view_entry_key(entry: Dictionary) -> String:
	var set_code := str(entry.get("set_code", "")).strip_edges()
	var card_index := str(entry.get("card_index", "")).strip_edges()
	if set_code != "" or card_index != "":
		return "%s::%s" % [set_code, card_index]
	var name := str(entry.get("name", "")).strip_edges()
	if name == "":
		return ""
	return "name::%s::%s" % [name, str(entry.get("card_type", "")).strip_edges()]


func _deck_view_layout_profile(host: Node, display_cards: int) -> Dictionary:
	var viewport_size := _host_viewport_size(host)
	var portrait := viewport_size.y > viewport_size.x and viewport_size.x >= 360.0
	if portrait:
		var compact := viewport_size.x < PORTRAIT_COMPACT_WIDTH
		var page_margin := clampf(
			viewport_size.x * (0.035 if compact else 0.026),
			12.0 if compact else 24.0,
			34.0
		)
		var dialog_size := Vector2i(
			roundi(maxf(320.0, viewport_size.x - page_margin * 2.0)),
			roundi(maxf(620.0, viewport_size.y - page_margin * 2.0))
		)
		var content_margin := roundi(clampf(
			viewport_size.x * (0.026 if compact else 0.022),
			10.0 if compact else 22.0,
			18.0 if compact else 30.0
		))
		var preferred_gap := roundi(clampf(viewport_size.x * (0.014 if compact else 0.010), 4.0 if compact else 8.0, 14.0))
		var content_width := maxf(float(dialog_size.x) - float(content_margin * 2), 1.0)
		var columns := PORTRAIT_VIEW_GRID_COLUMNS
		var grid_metrics := _portrait_four_column_grid_metrics(content_width, preferred_gap)
		var gap := int(grid_metrics.get("gap", preferred_gap))
		var tile_width := int(grid_metrics.get("tile_width", 80))
		var grid_width := float(grid_metrics.get("grid_width", tile_width * columns + gap * (columns - 1)))
		var phone_scale := clampf(viewport_size.x / 390.0, 0.92, 1.08)
		var tablet_scale := clampf(viewport_size.x / 1080.0, 1.0, 1.18)
		return {
			"portrait": true,
			"columns": columns,
			"dialog_position": Vector2i(roundi(page_margin), roundi(page_margin)),
			"dialog_size": dialog_size,
			"margin": content_margin,
			"gap": gap,
			"tile_width": tile_width,
			"tile_height": roundi(float(tile_width) * 1.38),
			"grid_min_width": grid_width,
			"info_font_size": roundi((17.0 * phone_scale) if compact else (31.0 * tablet_scale)),
			"card_label_font_size": roundi((36.0 * phone_scale) if compact else (54.0 * tablet_scale)),
			"button_font_size": roundi((18.0 * phone_scale) if compact else (32.0 * tablet_scale)),
			"ok_button_height": clampf(viewport_size.y * (0.064 if compact else 0.052), 52.0 if compact else 96.0, 76.0 if compact else 128.0),
		}
	var dialog_max_width := mini(1180, maxi(720, roundi(viewport_size.x - 24.0)))
	var w := clampi(roundi(viewport_size.x * 0.82), 720, dialog_max_width)
	var margin := 12
	var gap := 6
	var content_width := maxf(float(w - margin * 2), 1.0)
	var cols := clampi(floori((content_width + float(gap)) / float(CARD_TILE_WIDTH + gap)), VIEW_GRID_COLUMNS, 10)
	var available_width := maxf(content_width - float(gap * (cols - 1)), 1.0)
	var tile_width := roundi(clampf(floor(available_width / float(cols)), 88.0, 116.0))
	var tile_height := roundi(float(tile_width) * 1.38)
	var label_font_size := HudThemeScript.scaled_font_size(11)
	var label_height := roundi(maxf(22.0, float(label_font_size + 14)))
	var rows := maxi(1, ceili(float(maxi(1, display_cards)) / float(cols)))
	var viewport_height_limit := mini(760, maxi(360, roundi(viewport_size.y * 0.90)))
	var desired_height := rows * (tile_height + label_height + gap) + 118
	var h := clampi(desired_height, 360, viewport_height_limit)
	return {
		"portrait": false,
		"columns": cols,
		"dialog_position": Vector2i.ZERO,
		"dialog_size": Vector2i(w, h),
		"margin": margin,
		"gap": gap,
		"tile_width": tile_width,
		"tile_height": tile_height,
		"info_font_size": HudThemeScript.scaled_font_size(14),
		"card_label_font_size": label_font_size,
		"button_font_size": 15,
		"ok_button_height": 42.0,
	}


func _portrait_four_column_grid_metrics(content_width: float, preferred_gap: int) -> Dictionary:
	var columns := PORTRAIT_VIEW_GRID_COLUMNS
	var content_width_int := maxi(1, roundi(content_width))
	var best_gap := clampi(preferred_gap, 4, 16)
	var best_tile_width := maxi(1, floori(float(content_width_int - best_gap * (columns - 1)) / float(columns)))
	var best_grid_width := best_tile_width * columns + best_gap * (columns - 1)
	var best_score := 999999
	for gap_candidate: int in range(4, 17):
		var remaining_width := content_width_int - gap_candidate * (columns - 1)
		if remaining_width <= columns:
			continue
		var tile_width := floori(float(remaining_width) / float(columns))
		var grid_width := tile_width * columns + gap_candidate * (columns - 1)
		var fill_error := absi(content_width_int - grid_width)
		var score := fill_error * 100 + absi(gap_candidate - preferred_gap)
		if score < best_score:
			best_score = score
			best_gap = gap_candidate
			best_tile_width = tile_width
			best_grid_width = grid_width
			if fill_error == 0 and gap_candidate == preferred_gap:
				break
	return {
		"gap": best_gap,
		"tile_width": best_tile_width,
		"grid_width": best_grid_width,
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


func _create_view_tile(card_name: String, set_code: String, card_index: String, tile_width: int = CARD_TILE_WIDTH, tile_height: int = CARD_TILE_HEIGHT, label_font_size: int = -1, copy_count: int = 1) -> PanelContainer:
	return _create_view_tile_with_cache(card_name, set_code, card_index, tile_width, tile_height, label_font_size, copy_count, null, false)


func _create_view_tile_with_cache(
	card_name: String,
	set_code: String,
	card_index: String,
	tile_width: int = CARD_TILE_WIDTH,
	tile_height: int = CARD_TILE_HEIGHT,
	label_font_size: int = -1,
	copy_count: int = 1,
	image_cache_service: Object = null,
	portrait: bool = false
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "DeckViewCardTile"
	var label_height := maxf(22.0, float(label_font_size + 14))
	panel.custom_minimum_size = Vector2(tile_width, float(tile_height) + label_height)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("deck_view_card_name", card_name)
	panel.set_meta("deck_view_set_code", set_code)
	panel.set_meta("deck_view_card_index", card_index)
	panel.set_meta("deck_view_count", copy_count)
	panel.add_theme_stylebox_override("panel", _deck_view_tile_style())

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var image_frame := Control.new()
	image_frame.name = "DeckViewCardImageFrame"
	image_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_frame.custom_minimum_size = Vector2(tile_width - 8, tile_height - 8)
	image_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(image_frame)

	var image_view := CardImageOrProxyViewScript.new()
	image_view.name = "DeckViewCardImage"
	image_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	var card := CardDatabase.get_card(set_code, card_index)
	if card != null:
		image_view.call("setup_from_card", card, image_cache_service, {
			"portrait": portrait,
			"show_download_button": true,
		})
	else:
		image_view.call("setup_from_entry", {
			"name": card_name,
			"set_code": set_code,
			"card_index": card_index,
		}, image_cache_service, {
			"portrait": portrait,
			"show_download_button": true,
		})
	image_frame.add_child(image_view)

	var badge := Label.new()
	badge.name = "DeckViewCardCountBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.text = "X%d" % copy_count
	badge.visible = copy_count > 1
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var badge_font_size := maxi(10, label_font_size)
	badge.add_theme_font_size_override("font_size", badge_font_size)
	badge.add_theme_color_override("font_color", Color(0.96, 1.0, 1.0, 1.0))
	badge.add_theme_stylebox_override("normal", _deck_view_count_badge_style())
	var badge_width := minf(maxf(34.0, float(badge_font_size) * 1.75), maxf(34.0, float(tile_width) - 12.0))
	var badge_height := minf(maxf(24.0, float(badge_font_size) * 1.35), maxf(24.0, float(tile_height) * 0.50))
	badge.custom_minimum_size = Vector2(badge_width, badge_height)
	badge.anchor_left = 1.0
	badge.anchor_top = 1.0
	badge.anchor_right = 1.0
	badge.anchor_bottom = 1.0
	badge.offset_left = -badge_width - 4.0
	badge.offset_top = -badge_height - 4.0
	badge.offset_right = -4.0
	badge.offset_bottom = -4.0
	image_frame.add_child(badge)

	var label := Label.new()
	label.name = "DeckViewCardNameLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = card_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", label_font_size if label_font_size > 0 else HudThemeScript.scaled_font_size(11))
	label.add_theme_color_override("font_color", HudThemeScript.TEXT)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.72, 0.95, 0.45))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(tile_width - 8, label_height)
	vbox.add_child(label)

	return panel


func _deck_view_tile_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.016, 0.052, 0.070, 0.86)
	style.border_color = Color(0.30, 0.90, 1.0, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.70, 0.95, 0.18)
	style.shadow_size = 8
	style.set_content_margin_all(4)
	return style


func _deck_view_count_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.16, 0.22, 0.94)
	style.border_color = Color(1.0, 0.62, 0.24, 0.96)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(1.0, 0.45, 0.12, 0.26)
	style.shadow_size = 6
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _on_view_tile_input(event: InputEvent, host: Node, scroll: ScrollContainer, set_code: String, card_index: String) -> void:
	if _handle_card_list_drag_scroll_input(event, scroll):
		return
	if _is_card_list_drag_click_suppressed(scroll):
		return
	var portrait := _host_uses_portrait_deck_view(host)
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			if portrait:
				_accept_scroll_event(scroll)
				return
			_open_view_tile_card_detail(host, set_code, card_index)
			return
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			if portrait:
				_accept_scroll_event(scroll)
				return
			_open_view_tile_card_detail(host, set_code, card_index)
			return
	if event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		if portrait:
			_accept_scroll_event(scroll)
			return
		_open_view_tile_card_detail(host, set_code, card_index)


func _open_view_tile_card_detail(host: Node, set_code: String, card_index: String) -> void:
	var card := CardDatabase.get_card(set_code, card_index)
	if card != null:
		_show_card_detail(host, card)


func _show_card_detail(host: Node, card: CardData) -> AcceptDialog:
	if _host_uses_portrait_deck_view(host):
		return null
	var dialog := AcceptDialog.new()
	dialog.name = "DeckViewCardDetailDialog"
	dialog.title = card.display_name()
	dialog.ok_button_text = "关闭"
	dialog.size = _card_detail_dialog_size(host)
	dialog.min_size = dialog.size
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
	_apply_deck_view_dialog_hud(dialog)

	var margin := MarginContainer.new()
	margin.anchors_preset = Control.PRESET_FULL_RECT
	var margin_value := 10
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
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)

	var scroll := ScrollContainer.new()
	scroll.name = "DeckViewCardDetailScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	HudThemeScript.style_scroll_container(scroll, "compact")
	NonBattleTouchBridgeScript.configure_hidden_vertical_drag_scroll(scroll)
	outer.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	var header := Label.new()
	header.text = card.display_name()
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
			ab_title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
			ab_title.text = "特性: %s" % CardData.dictionary_display_name(ab)
			content.add_child(ab_title)
			var ab_display_text := CardData.dictionary_display_text(ab)
			if ab_display_text != "":
				var ab_text := Label.new()
				ab_text.text = ab_display_text
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
			parts.append(CardData.dictionary_display_name(atk))
			if dmg_str != "":
				parts.append(dmg_str)
			atk_header.text = " ".join(parts)
			atk_header.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
			content.add_child(atk_header)
			var atk_display_text := CardData.dictionary_display_text(atk)
			if atk_display_text != "":
				var atk_text := Label.new()
				atk_text.text = atk_display_text
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

	outer.add_child(_create_card_detail_close_button(dialog))
	host.add_child(dialog)
	var ok_button := dialog.get_ok_button()
	if ok_button != null:
		ok_button.visible = false
	dialog.set_meta("deck_view_centered_position", _dialog_centered_position_for_host(host, dialog))
	if dialog.is_inside_tree():
		_popup_dialog_centered_for_host(host, dialog)
	dialog.confirmed.connect(dialog.queue_free)
	return dialog


func _host_uses_portrait_deck_view(host: Node) -> bool:
	var viewport_size := _host_viewport_size(host)
	return viewport_size.y > viewport_size.x and viewport_size.x >= 360.0


func _card_detail_dialog_size(host: Node) -> Vector2i:
	var viewport_size := _host_viewport_size(host)
	var portrait := viewport_size.y > viewport_size.x and viewport_size.x >= 320.0
	if portrait:
		var margin := clampf(viewport_size.x * 0.04, 16.0, 28.0)
		return Vector2i(
			roundi(clampf(viewport_size.x - margin * 2.0, 320.0, 560.0)),
			roundi(clampf(viewport_size.y * 0.66, 420.0, viewport_size.y - margin * 2.0))
		)
	return Vector2i(500, 480)


func _create_card_detail_close_button(dialog: AcceptDialog) -> Button:
	var button := Button.new()
	button.name = "DeckViewCardDetailCloseButton"
	button.text = dialog.ok_button_text
	button.custom_minimum_size = Vector2(0.0, 58.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", HudThemeScript.scaled_font_size(16))
	button.add_theme_stylebox_override("normal", HudThemeScript.button_style(HudThemeScript.ACCENT, false, false))
	button.add_theme_stylebox_override("hover", HudThemeScript.button_style(HudThemeScript.ACCENT, true, false))
	button.add_theme_stylebox_override("pressed", HudThemeScript.button_style(HudThemeScript.ACCENT, true, true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(dialog.queue_free)
	NonBattleTouchBridgeScript.set_touch_bridge_enabled(button, true)
	NonBattleTouchBridgeScript.set_button_window_visibility_fallback(button, true)
	NonBattleTouchBridgeScript.bind_button_touch(button)
	return button


func _popup_dialog_centered_for_host(host: Node, dialog: Window) -> void:
	if dialog == null:
		return
	var position := _dialog_centered_position_for_host(host, dialog)
	dialog.set_meta("deck_view_centered_position", position)
	dialog.position = position
	dialog.popup(Rect2i(position, dialog.size))
	dialog.position = position
	dialog.set_deferred("position", position)


func _dialog_centered_position_for_host(host: Node, dialog: Window) -> Vector2i:
	var viewport_size := _host_viewport_size(host)
	return Vector2i(
		roundi(maxf(0.0, (viewport_size.x - float(dialog.size.x)) * 0.5)),
		roundi(maxf(0.0, (viewport_size.y - float(dialog.size.y)) * 0.5))
	)


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
