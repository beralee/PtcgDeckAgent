extends Control

const CARD_IMAGE_DOWNLOADER := preload("res://scripts/network/CardImageDownloader.gd")
const DeckSuggestionClientScript := preload("res://scripts/network/DeckSuggestionClient.gd")
const DeckRecommendationStoreScript := preload("res://scripts/engine/DeckRecommendationStore.gd")
const DeckViewDialogScript := preload("res://scripts/ui/decks/DeckViewDialog.gd")
const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")

const CARD_TILE_WIDTH := 100
const CARD_TILE_HEIGHT := 140
const VIEW_GRID_COLUMNS := 6
const RENAME_DIALOG_SIZE := Vector2i(460, 230)
const COMMUNITY_DATA_PATH := "res://community/data/community-data.json"
const HUD_ACCENT := Color(0.28, 0.92, 1.0, 1.0)
const HUD_ACCENT_WARM := Color(1.0, 0.55, 0.24, 1.0)
const HUD_DANGER := Color(1.0, 0.28, 0.22, 1.0)
const HUD_TEXT := Color(0.92, 0.98, 1.0, 1.0)
const HUD_TEXT_MUTED := Color(0.64, 0.76, 0.86, 1.0)
const HUD_FRAME_BORDER := Color(0.76, 0.90, 1.0, 0.96)
const HUD_CARD_BORDER := Color(0.48, 0.72, 1.0, 0.78)
const HUD_RECOMMENDATION_BORDER := Color(1.0, 0.76, 0.30, 0.96)
const HUD_SECONDARY := Color(0.50, 0.80, 1.0, 1.0)
const HUD_RENAME := Color(0.72, 0.64, 1.0, 1.0)
const IMPORT_RESULT_AUTO_CLOSE_SECONDS := 1.4
const REMOTE_RECOMMENDATION_PREFETCH_STEPS := 6
const DECK_CENTER_SCROLLBAR_RIGHT_CLEARANCE := 40
const RECOMMENDATION_DETAIL_SCROLLBAR_RIGHT_CLEARANCE := 34

const ENERGY_TYPE_LABELS: Dictionary = {
	"R": "火", "W": "水", "G": "草", "L": "雷",
	"P": "超", "F": "斗", "D": "恶", "M": "钢", "N": "龙", "C": "无色",
}

var _importer: DeckImporter = null
var _image_syncer = null
var _current_operation: String = ""
var _panel_mode: String = "import"
var _pending_import_deck: DeckData = null
var _pending_import_errors: PackedStringArray = PackedStringArray()
var _pending_import_deck_name_override := ""
var _rename_dialog: AcceptDialog = null
var _rename_input: LineEdit = null
var _rename_error_label: Label = null
var _rename_confirm_button: Button = null
var _rename_target_deck: DeckData = null
var _rename_ignore_deck_id: int = -1
var _rename_context: String = ""
var _rename_forced: bool = false
var _texture_cache: Dictionary = {}
var _failed_texture_paths: Dictionary = {}
var _deck_view_dialog: RefCounted = DeckViewDialogScript.new()
var _recommendation_client: Node = null
var _recommendation_fetch_in_progress := false
var _recommendation_fetch_reason := ""
var _recommendation_prefetch_remaining := 0
var _recommendation_prefetch_seen_ids: Dictionary = {}
var _recommendation_store: RefCounted = null
var _recommendation_articles: Array[Dictionary] = []
var _embedded_recommendations: Array[Dictionary] = []
var _current_recommendation: Dictionary = {}
var _recommendation_section: VBoxContainer = null
var _recommendation_feed: VBoxContainer = null
var _recommendation_status_label: Label = null
var _recommendation_next_button: Button = null
var _recommendation_detail_overlay: Control = null
var _import_result_close_timer: Timer = null


func _ready() -> void:
	_apply_hud_theme()
	_setup_deck_recommendations()
	%BtnImport.pressed.connect(_on_import_pressed)
	%BtnSyncImages.pressed.connect(_on_sync_images_pressed)
	%BtnBack.pressed.connect(_on_back_pressed)
	%BtnDoImport.pressed.connect(_on_do_import)
	%BtnCloseImport.pressed.connect(_on_close_import)

	CardDatabase.decks_changed.connect(_refresh_deck_list)
	_refresh_deck_list()

	_importer = DeckImporter.new()
	add_child(_importer)
	_importer.import_progress.connect(_on_import_progress)
	_importer.import_completed.connect(_on_import_completed)
	_importer.import_failed.connect(_on_import_failed)

	_image_syncer = CARD_IMAGE_DOWNLOADER.new()
	add_child(_image_syncer)
	_image_syncer.progress.connect(_on_image_sync_progress)
	_image_syncer.completed.connect(_on_image_sync_completed)
	_image_syncer.failed.connect(_on_image_sync_failed)


func _apply_hud_theme() -> void:
	var shade := get_node_or_null("BackgroundShade") as ColorRect
	if shade != null:
		shade.color = Color(0.01, 0.025, 0.045, 0.18)
	_ensure_hud_frame()
	_style_hud_labels_recursive(self)
	for button_name: String in ["BtnImport", "BtnSyncImages", "BtnBack", "BtnDoImport", "BtnCloseImport"]:
		var button := get_node_or_null("%" + button_name) as Button
		if button != null:
			var accent := HUD_ACCENT
			if button_name in ["BtnImport", "BtnDoImport"]:
				accent = HUD_ACCENT_WARM
			elif button_name in ["BtnSyncImages", "BtnCloseImport"]:
				accent = HUD_SECONDARY
			_style_hud_button(button, accent)
	var import_box := find_child("ImportBox", true, false) as PanelContainer
	if import_box != null:
		import_box.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.025, 0.055, 0.085, 0.92), HUD_FRAME_BORDER, 20))
	var import_bg := find_child("ImportBg", true, false) as ColorRect
	if import_bg != null:
		import_bg.color = Color(0.0, 0.0, 0.0, 0.42)
	var url_input := get_node_or_null("%UrlInput") as LineEdit
	if url_input != null:
		_style_hud_line_edit(url_input)
	var empty_label := get_node_or_null("%EmptyLabel") as Label
	if empty_label != null:
		empty_label.add_theme_color_override("font_color", HUD_TEXT_MUTED)
	HudThemeScript.apply_scrollbars_recursive(self)
	_apply_deck_center_scroll_clearance()


func _apply_deck_center_scroll_clearance() -> void:
	var deck_scroll := find_child("DeckScroll", true, false) as ScrollContainer
	if deck_scroll != null:
		deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var deck_scroll_margin := find_child("DeckScrollMargin", true, false) as MarginContainer
	if deck_scroll_margin != null:
		deck_scroll_margin.add_theme_constant_override("margin_right", DECK_CENTER_SCROLLBAR_RIGHT_CLEARANCE)


func _ensure_hud_frame() -> void:
	if get_node_or_null("HudFrame") != null:
		return
	var margin := get_node_or_null("MarginContainer") as MarginContainer
	if margin == null:
		return
	var frame := PanelContainer.new()
	frame.name = "HudFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.layout_mode = margin.layout_mode
	frame.anchors_preset = margin.anchors_preset
	frame.anchor_left = margin.anchor_left
	frame.anchor_top = margin.anchor_top
	frame.anchor_right = margin.anchor_right
	frame.anchor_bottom = margin.anchor_bottom
	frame.offset_left = margin.offset_left + 8
	frame.offset_top = margin.offset_top + 8
	frame.offset_right = margin.offset_right - 8
	frame.offset_bottom = margin.offset_bottom - 8
	frame.grow_horizontal = margin.grow_horizontal
	frame.grow_vertical = margin.grow_vertical
	frame.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.025, 0.055, 0.085, 0.72), HUD_FRAME_BORDER, 24))
	add_child(frame)
	move_child(frame, margin.get_index())


func _style_hud_labels_recursive(node: Node) -> void:
	if node is Label:
		var label := node as Label
		if label.name in ["Title", "TitleLabel"]:
			label.add_theme_font_size_override("font_size", 32)
			label.add_theme_color_override("font_color", HUD_TEXT)
			label.add_theme_color_override("font_shadow_color", Color(0.0, 0.82, 1.0, 0.72))
			label.add_theme_constant_override("shadow_offset_y", 2)
		else:
			label.add_theme_color_override("font_color", HUD_TEXT_MUTED)
	for child: Node in node.get_children():
		_style_hud_labels_recursive(child)


func _hud_panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(border.r, border.g, border.b, 0.34)
	style.shadow_size = 14
	style.set_content_margin_all(10)
	return style


func _hud_button_style(accent: Color, hover: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var base := Color(0.016, 0.046, 0.066, 0.94)
	var accent_fill := Color(accent.r, accent.g, accent.b, 0.94)
	style.bg_color = base.lerp(accent_fill, 0.20)
	if hover and not pressed:
		style.bg_color = base.lerp(accent_fill, 0.34)
	if pressed:
		style.bg_color = Color(accent.r, accent.g, accent.b, 0.86)
	style.border_color = Color(accent.r, accent.g, accent.b, 1.0 if hover or pressed else 0.88)
	style.set_border_width_all(3 if hover or pressed else 2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.36 if hover or pressed else 0.20)
	style.shadow_size = 12 if hover or pressed else 7
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style


func _style_hud_button(button: Button, accent: Color, compact: bool = false) -> void:
	var min_height := 38.0 if compact else 42.0
	button.custom_minimum_size = Vector2(button.custom_minimum_size.x, maxf(button.custom_minimum_size.y, min_height))
	button.add_theme_font_size_override("font_size", 14 if compact else 15)
	button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.08, 0.12, 0.16, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.44, 0.50, 0.56, 1.0))
	button.add_theme_stylebox_override("normal", _hud_button_style(accent, false, false))
	button.add_theme_stylebox_override("hover", _hud_button_style(accent, true, false))
	button.add_theme_stylebox_override("pressed", _hud_button_style(accent, true, true))
	button.add_theme_stylebox_override("disabled", _hud_button_style(Color(0.26, 0.31, 0.36, 1.0), false, false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style_hud_line_edit(input: LineEdit) -> void:
	input.add_theme_font_size_override("font_size", 15)
	input.add_theme_color_override("font_color", HUD_TEXT)
	input.add_theme_color_override("font_placeholder_color", Color(0.55, 0.66, 0.74, 0.78))
	input.add_theme_color_override("caret_color", HUD_ACCENT)
	input.add_theme_stylebox_override("normal", _hud_input_style(false))
	input.add_theme_stylebox_override("focus", _hud_input_style(true))


func _hud_input_style(hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.035, 0.055, 0.88)
	if hover:
		style.bg_color = Color(0.025, 0.075, 0.105, 0.94)
	style.border_color = Color(0.23, 0.78, 1.0, 0.70 if hover else 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _setup_deck_recommendations() -> void:
	_recommendation_store = DeckRecommendationStoreScript.new()
	_recommendation_store.call("load_cache")
	_recommendation_articles = _load_recommendation_articles()
	_embedded_recommendations = _normalize_recommendation_articles(_recommendation_articles)
	_current_recommendation = (_recommendation_store.call("get_current_or_fallback", _embedded_recommendations) as Dictionary)
	_ensure_recommendation_client()
	_ensure_recommendation_section()
	_request_latest_remote_recommendation_on_open()


func _ensure_recommendation_client() -> void:
	if _recommendation_client != null and is_instance_valid(_recommendation_client):
		return
	_recommendation_client = DeckSuggestionClientScript.new()
	_recommendation_client.name = "DeckSuggestionClient"
	_recommendation_client.fetch_succeeded.connect(_on_remote_recommendation_succeeded)
	_recommendation_client.fetch_failed.connect(_on_remote_recommendation_failed)
	add_child(_recommendation_client)


func _load_recommendation_articles() -> Array[Dictionary]:
	var articles: Array[Dictionary] = []
	if not FileAccess.file_exists(COMMUNITY_DATA_PATH):
		return articles

	var raw_text := FileAccess.get_file_as_string(COMMUNITY_DATA_PATH)
	var parsed: Variant = JSON.parse_string(raw_text)
	if parsed is not Dictionary:
		return articles

	var root := parsed as Dictionary
	var briefing_raw: Variant = root.get("environment_briefing", {})
	var briefing: Dictionary = briefing_raw if briefing_raw is Dictionary else {}
	var source_articles_raw: Variant = briefing.get("articles", [])
	var source_articles: Array = source_articles_raw if source_articles_raw is Array else []
	if source_articles.is_empty():
		var single_article: Variant = briefing.get("article", {})
		if single_article is Dictionary:
			source_articles.append(single_article)

	for article_raw: Variant in source_articles:
		if article_raw is not Dictionary:
			continue
		var article := article_raw as Dictionary
		if _extract_recommendation_import_url(article) == "":
			continue
		articles.append(article)

	articles.sort_custom(_compare_recommendation_articles)
	return articles


func _normalize_recommendation_articles(articles: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for article: Dictionary in articles:
		var normalized: Dictionary = DeckRecommendationStoreScript.normalize_embedded_article(article)
		if not normalized.is_empty():
			result.append(normalized)
	return result


func _compare_recommendation_articles(a: Dictionary, b: Dictionary) -> bool:
	var source_a := _as_dictionary(a.get("source", {}))
	var source_b := _as_dictionary(b.get("source", {}))
	var date_a := str(source_a.get("date", "")).replace(".", "")
	var date_b := str(source_b.get("date", "")).replace(".", "")
	if date_a != date_b:
		return date_a > date_b
	return int(source_a.get("players", 0)) > int(source_b.get("players", 0))


func _as_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _ensure_recommendation_section() -> void:
	var deck_list_container := get_node_or_null("%DeckList") as VBoxContainer
	if deck_list_container == null:
		return
	if _recommendation_section != null and is_instance_valid(_recommendation_section):
		return

	_recommendation_section = VBoxContainer.new()
	_recommendation_section.name = "RecommendationSection"
	_recommendation_section.add_theme_constant_override("separation", 10)
	deck_list_container.add_child(_recommendation_section)
	deck_list_container.move_child(_recommendation_section, 0)

	_recommendation_feed = VBoxContainer.new()
	_recommendation_feed.name = "RecommendationFeed"
	_recommendation_feed.add_theme_constant_override("separation", 8)
	_recommendation_feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recommendation_section.add_child(_recommendation_feed)

	_recommendation_status_label = Label.new()
	_recommendation_status_label.name = "RecommendationStatusLabel"
	_recommendation_status_label.text = ""
	_recommendation_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_recommendation_status_label.add_theme_font_size_override("font_size", 12)
	_recommendation_status_label.add_theme_color_override("font_color", HUD_TEXT_MUTED)
	_recommendation_section.add_child(_recommendation_status_label)


func _refresh_recommendation_cards() -> void:
	_ensure_recommendation_section()
	if _recommendation_section == null or _recommendation_feed == null:
		return

	for child: Node in _recommendation_feed.get_children():
		_recommendation_feed.remove_child(child)
		child.queue_free()
	_recommendation_next_button = null

	if _current_recommendation.is_empty() and _recommendation_store != null:
		_current_recommendation = (_recommendation_store.call("get_current_or_fallback", _embedded_recommendations) as Dictionary)

	_recommendation_section.visible = true
	if _current_recommendation.is_empty():
		_recommendation_feed.add_child(_create_recommendation_placeholder())
		if _recommendation_next_button != null:
			_recommendation_next_button.disabled = _recommendation_fetch_in_progress
		return

	_recommendation_feed.add_child(_create_recommendation_feed_card(_current_recommendation))
	if _recommendation_next_button != null:
		_recommendation_next_button.disabled = _recommendation_fetch_in_progress or _current_operation != ""
		_recommendation_next_button.text = "获取中..." if _recommendation_fetch_in_progress else "换一套"


func _create_recommendation_placeholder() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "RecommendationFeedCard"
	panel.custom_minimum_size = Vector2(0, 120)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.030, 0.070, 0.098, 0.92), HUD_RECOMMENDATION_BORDER, 16))
	var label := Label.new()
	label.text = "暂时没有可展示的推荐卡组。你仍然可以手动导入卡组。"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", HUD_TEXT_MUTED)
	panel.add_child(label)
	return panel


func _create_recommendation_feed_card(recommendation: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "RecommendationFeedCard"
	panel.custom_minimum_size = Vector2(0, 260)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.030, 0.070, 0.098, 0.94), HUD_RECOMMENDATION_BORDER, 18))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 9)
	panel.add_child(vbox)

	var deck_name := str(recommendation.get("deck_name", "推荐卡组"))
	var title_text := str(recommendation.get("title", deck_name))
	var style_summary := str(recommendation.get("style_summary", ""))
	var source_text := _recommendation_source_text(recommendation)
	var import_url := str(recommendation.get("import_url", ""))
	var deck_id := int(recommendation.get("deck_id", 0))

	var meta := Label.new()
	meta.text = source_text
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", HUD_ACCENT_WARM)
	vbox.add_child(meta)

	var deck_label := Label.new()
	deck_label.name = "RecommendationDeckName"
	deck_label.text = deck_name
	deck_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	deck_label.add_theme_font_size_override("font_size", 23)
	deck_label.add_theme_color_override("font_color", HUD_TEXT)
	vbox.add_child(deck_label)

	var title := Label.new()
	title.name = "RecommendationTitle"
	title.text = title_text
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1.0))
	vbox.add_child(title)

	if style_summary != "":
		var summary_label := Label.new()
		summary_label.text = style_summary
		summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		summary_label.add_theme_color_override("font_color", Color(0.78, 0.90, 0.96, 1.0))
		vbox.add_child(summary_label)

	var why_title := Label.new()
	why_title.name = "RecommendationWhyTitle"
	why_title.text = "为什么值得玩"
	why_title.add_theme_font_size_override("font_size", 15)
	why_title.add_theme_color_override("font_color", HUD_ACCENT_WARM)
	vbox.add_child(why_title)

	var why_items: Array = recommendation.get("why_play", [])
	for bullet_raw: Variant in why_items:
		var bullet := str(bullet_raw).strip_edges()
		if bullet == "":
			continue
		var bullet_label := Label.new()
		bullet_label.text = "• " + bullet
		bullet_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		bullet_label.add_theme_color_override("font_color", HUD_TEXT_MUTED)
		vbox.add_child(bullet_label)

	var best_for := str(recommendation.get("best_for", "")).strip_edges()
	if best_for != "":
		vbox.add_child(_create_recommendation_line("适合谁", best_for))

	var pilot_tip := str(recommendation.get("pilot_tip", "")).strip_edges()
	if pilot_tip != "":
		vbox.add_child(_create_recommendation_line("上手看点", pilot_tip))

	var button_row := HBoxContainer.new()
	button_row.name = "RecommendationActionRow"
	button_row.add_theme_constant_override("separation", 8)
	button_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(button_row)

	var button_spacer := Control.new()
	button_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_row.add_child(button_spacer)

	_recommendation_next_button = Button.new()
	_recommendation_next_button.name = "RecommendationNextButton"
	_recommendation_next_button.text = "获取中..." if _recommendation_fetch_in_progress else "换一套"
	_recommendation_next_button.custom_minimum_size = Vector2(112, 42)
	_recommendation_next_button.disabled = _recommendation_fetch_in_progress or _current_operation != ""
	_recommendation_next_button.pressed.connect(_on_recommendation_next_pressed)
	button_row.add_child(_recommendation_next_button)
	_style_hud_button(_recommendation_next_button, HUD_SECONDARY)

	var import_button := Button.new()
	import_button.name = "RecommendationImportButton"
	import_button.text = "更新本地" if deck_id > 0 and CardDatabase.has_deck(deck_id) else "导入这套"
	import_button.custom_minimum_size = Vector2(124, 42)
	import_button.disabled = import_url == "" or _current_operation != "" or _recommendation_fetch_in_progress
	import_button.pressed.connect(_on_recommendation_import_pressed.bind(recommendation))
	button_row.add_child(import_button)
	_style_hud_button(import_button, HUD_ACCENT_WARM)

	var read_button := Button.new()
	read_button.name = "RecommendationDetailButton"
	read_button.text = "查看完整解读"
	read_button.custom_minimum_size = Vector2(150, 42)
	read_button.pressed.connect(_on_recommendation_read_pressed.bind(recommendation))
	button_row.add_child(read_button)
	_style_hud_button(read_button, HUD_ACCENT)

	return panel


func _create_recommendation_line(label_text: String, body_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var title := Label.new()
	title.text = label_text
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", HUD_ACCENT)
	box.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_color_override("font_color", HUD_TEXT_MUTED)
	box.add_child(body)
	return box


func _recommendation_available_count() -> int:
	var seen := {}
	for item: Dictionary in _embedded_recommendations:
		var item_id := str(item.get("id", "")).strip_edges()
		if item_id != "":
			seen[item_id] = true
	if _recommendation_store != null:
		var cached_items: Array = _recommendation_store.call("get_items")
		for cached_raw: Variant in cached_items:
			if cached_raw is not Dictionary:
				continue
			var cached := cached_raw as Dictionary
			var cached_id := str(cached.get("id", "")).strip_edges()
			if cached_id != "":
				seen[cached_id] = true
	var current_id := str(_current_recommendation.get("id", "")).strip_edges()
	if current_id != "":
		seen[current_id] = true
	return seen.size()


func _recommendation_exclude_ids(extra_id: String = "") -> PackedStringArray:
	var ids := PackedStringArray()
	var seen := {}
	_append_recommendation_id_value(ids, seen, extra_id)
	_append_recommendation_id(ids, seen, _current_recommendation)
	if _recommendation_store != null:
		var cached_items: Array = _recommendation_store.call("get_items")
		for cached_raw: Variant in cached_items:
			if cached_raw is Dictionary:
				_append_recommendation_id(ids, seen, cached_raw as Dictionary)
	for embedded: Dictionary in _embedded_recommendations:
		_append_recommendation_id(ids, seen, embedded)
	return ids


func _prefetch_recommendation_exclude_ids() -> PackedStringArray:
	var ids := _recommendation_exclude_ids()
	var seen := {}
	for item_id: String in ids:
		seen[item_id] = true
	for seen_id: Variant in _recommendation_prefetch_seen_ids.keys():
		_append_recommendation_id_value(ids, seen, str(seen_id))
	return ids


func _append_recommendation_id(ids: PackedStringArray, seen: Dictionary, recommendation: Dictionary) -> void:
	_append_recommendation_id_value(ids, seen, str(recommendation.get("id", "")))


func _append_recommendation_id_value(ids: PackedStringArray, seen: Dictionary, raw_id: String) -> void:
	var item_id := raw_id.strip_edges()
	if item_id == "" or seen.has(item_id):
		return
	seen[item_id] = true
	ids.append(item_id)


func _recommendation_source_text(recommendation: Dictionary) -> String:
	var source := _as_dictionary(recommendation.get("source", {}))
	var parts: PackedStringArray = []
	var label := str(source.get("label", "")).strip_edges()
	if label == "":
		label = "卡组推荐"
	parts.append(label)
	var date_text := str(source.get("date", "")).strip_edges()
	if date_text != "":
		parts.append(date_text)
	var players := int(source.get("players", 0))
	if players > 0:
		parts.append("%d人样本" % players)
	var generated_at := str(recommendation.get("generated_at", "")).strip_edges()
	if date_text == "" and generated_at != "":
		parts.append(generated_at)
	return " · ".join(parts)


func _normalize_recommendation_input(item: Dictionary) -> Dictionary:
	var normalized: Dictionary = DeckRecommendationStoreScript.normalize_recommendation(item)
	if normalized.is_empty():
		normalized = DeckRecommendationStoreScript.normalize_embedded_article(item)
	return normalized


func _set_recommendation_status(message: String) -> void:
	if _recommendation_status_label == null or not is_instance_valid(_recommendation_status_label):
		return
	_recommendation_status_label.text = message


func _on_recommendation_next_pressed() -> void:
	if _current_operation != "":
		_set_recommendation_status("当前正在导入或同步，完成后再切换推荐。")
		return
	if _recommendation_fetch_in_progress:
		return
	if is_inside_tree() and _request_remote_recommendation():
		return
	_switch_to_local_next_recommendation("已切换本地推荐。")


func _request_latest_remote_recommendation_on_open() -> void:
	if not is_inside_tree() or _recommendation_fetch_in_progress:
		return
	_start_remote_recommendation_request(
		"",
		"deck_manager_open_refresh",
		"正在检查服务器最新卡组推荐...",
		"open_refresh"
	)


func _start_remote_recommendation_request(
	current_id: String,
	source: String,
	status_message: String,
	reason: String,
	exclude_ids: PackedStringArray = PackedStringArray(),
	refresh_on_start: bool = true
) -> bool:
	_ensure_recommendation_client()
	if _recommendation_client == null:
		return false
	_recommendation_fetch_in_progress = true
	_recommendation_fetch_reason = reason
	if status_message != "":
		_set_recommendation_status(status_message)
	if refresh_on_start:
		_refresh_recommendation_cards()
	var request_exclude_ids := exclude_ids
	if request_exclude_ids.size() == 0 and reason != "open_refresh":
		request_exclude_ids = _recommendation_exclude_ids(current_id)
	var err: int = _recommendation_client.call("fetch_next_recommendation", current_id, request_exclude_ids, {
		"source": source,
	})
	if err != OK:
		_recommendation_fetch_in_progress = false
		_recommendation_fetch_reason = ""
		if refresh_on_start:
			_refresh_recommendation_cards()
		return false
	return true


func _request_remote_recommendation() -> bool:
	var current_id := str(_current_recommendation.get("id", "")).strip_edges()
	return _start_remote_recommendation_request(
		current_id,
		"deck_manager_recommendation",
		"正在从服务器获取新的卡组推荐...",
		"cycle"
	)


func _begin_remote_recommendation_prefetch() -> void:
	if not is_inside_tree() or _recommendation_fetch_in_progress:
		return
	if _recommendation_client == null:
		return
	_recommendation_prefetch_remaining = REMOTE_RECOMMENDATION_PREFETCH_STEPS
	_recommendation_prefetch_seen_ids = {}
	for known_id: String in _recommendation_exclude_ids():
		_recommendation_prefetch_seen_ids[known_id] = true
	_request_next_remote_recommendation_prefetch()


func _request_next_remote_recommendation_prefetch() -> void:
	if _recommendation_prefetch_remaining <= 0 or _recommendation_fetch_in_progress:
		return
	_recommendation_prefetch_remaining -= 1
	var started := _start_remote_recommendation_request(
		"",
		"deck_manager_prefetch",
		"正在同步更多服务器推荐...",
		"prefetch",
		_prefetch_recommendation_exclude_ids(),
		true
	)
	if not started:
		_recommendation_prefetch_remaining = 0
		_refresh_recommendation_cards()


func _switch_to_local_next_recommendation(status_message: String) -> void:
	if _recommendation_store == null:
		_recommendation_store = DeckRecommendationStoreScript.new()
		_recommendation_store.call("load_cache")

	var current_id := str(_current_recommendation.get("id", "")).strip_edges()
	var next_recommendation := _select_next_recommendation_from_pool(_combined_recommendation_pool(), current_id)
	if next_recommendation.is_empty() or str(next_recommendation.get("id", "")) == current_id and _recommendation_available_count() <= 1:
		_set_recommendation_status("暂时没有更多推荐，本地会保留当前这一套。")
		return

	var normalized := _normalize_recommendation_input(next_recommendation)
	if normalized.is_empty():
		_set_recommendation_status("下一套推荐数据不完整，已跳过。")
		return

	_current_recommendation = normalized
	_recommendation_store.call("upsert_item", normalized, true)
	_recommendation_store.call("save_cache")
	_set_recommendation_status(status_message)
	_refresh_recommendation_cards()


func _combined_recommendation_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var seen := {}
	var embedded_ids := {}
	for item: Dictionary in _embedded_recommendations:
		var item_id := str(item.get("id", "")).strip_edges()
		if item_id != "":
			embedded_ids[item_id] = true

	if not _embedded_recommendations.is_empty():
		_append_recommendation_to_pool(pool, seen, _embedded_recommendations[0])

	if _recommendation_store != null:
		var cached_items: Array = _recommendation_store.call("get_items")
		var cached_candidates: Array[Dictionary] = []
		for cached_raw: Variant in cached_items:
			if cached_raw is not Dictionary:
				continue
			var cached := cached_raw as Dictionary
			var cached_id := str(cached.get("id", "")).strip_edges()
			if cached_id == "" or embedded_ids.has(cached_id):
				continue
			var normalized_cached := _normalize_recommendation_input(cached)
			if not normalized_cached.is_empty():
				cached_candidates.append(normalized_cached)
		for cached: Dictionary in _sort_recommendations_for_pool(cached_candidates):
			_append_recommendation_to_pool(pool, seen, cached)

	for index: int in range(1, _embedded_recommendations.size()):
		_append_recommendation_to_pool(pool, seen, _embedded_recommendations[index])

	if pool.is_empty() and not _current_recommendation.is_empty():
		_append_recommendation_to_pool(pool, seen, _current_recommendation)
	return pool


func _sort_recommendations_for_pool(items: Array[Dictionary]) -> Array[Dictionary]:
	var source := items.duplicate(true)
	var result: Array[Dictionary] = []
	while not source.is_empty():
		var best_index := 0
		for index: int in range(1, source.size()):
			if _recommendation_pool_item_before(source[index], source[best_index]):
				best_index = index
		result.append(source[best_index])
		source.remove_at(best_index)
	return result


func _recommendation_pool_item_before(left: Dictionary, right: Dictionary) -> bool:
	var left_key := _recommendation_sort_key(left)
	var right_key := _recommendation_sort_key(right)
	if left_key != right_key:
		return left_key > right_key
	return str(left.get("id", "")) < str(right.get("id", ""))


func _recommendation_sort_key(recommendation: Dictionary) -> String:
	var generated_at := str(recommendation.get("generated_at", "")).strip_edges()
	if generated_at != "":
		var datetime_text := generated_at.trim_suffix("Z")
		var plus_index := datetime_text.find("+")
		if plus_index >= 0:
			datetime_text = datetime_text.substr(0, plus_index)
		return datetime_text.replace(" ", "T")
	var source := _as_dictionary(recommendation.get("source", {}))
	var source_date := str(source.get("date", "")).strip_edges()
	if source_date != "":
		return "%sT00:00:00" % source_date.replace(".", "-").replace("/", "-")
	return ""


func _append_recommendation_to_pool(pool: Array[Dictionary], seen: Dictionary, recommendation: Dictionary) -> void:
	var normalized := _normalize_recommendation_input(recommendation)
	if normalized.is_empty():
		return
	var item_id := str(normalized.get("id", "")).strip_edges()
	if item_id == "" or seen.has(item_id):
		return
	seen[item_id] = true
	pool.append(normalized)


func _select_next_recommendation_from_pool(pool: Array[Dictionary], current_id: String) -> Dictionary:
	if pool.is_empty():
		return {}
	if current_id == "":
		return pool[0].duplicate(true)
	for index: int in pool.size():
		if str(pool[index].get("id", "")) != current_id:
			continue
		for step: int in range(1, pool.size() + 1):
			var next_index := (index + step) % pool.size()
			var next_item := pool[next_index]
			if str(next_item.get("id", "")) != current_id:
				return next_item.duplicate(true)
		return {}
	return pool[0].duplicate(true)


func _on_remote_recommendation_succeeded(response: Dictionary) -> void:
	var fetch_reason := _recommendation_fetch_reason
	_recommendation_fetch_reason = ""
	_recommendation_fetch_in_progress = false
	var raw_recommendation: Dictionary = DeckSuggestionClientScript.extract_recommendation(response)
	var normalized := _normalize_recommendation_input(raw_recommendation)
	if normalized.is_empty():
		if fetch_reason == "prefetch":
			_recommendation_prefetch_remaining = 0
			_set_recommendation_status("已同步已可用的服务器推荐，可以继续换一套。")
			_refresh_recommendation_cards()
			return
		if fetch_reason == "open_refresh":
			_set_recommendation_status("服务器推荐数据不完整，已保留当前推荐。")
			_refresh_recommendation_cards()
			return
		_set_recommendation_status("服务器推荐数据不完整，已切回本地推荐。")
		_switch_to_local_next_recommendation("服务器推荐数据不完整，已切换本地推荐。")
		return

	if _recommendation_store == null:
		_recommendation_store = DeckRecommendationStoreScript.new()
		_recommendation_store.call("load_cache")

	if fetch_reason == "prefetch":
		var prefetched_id := str(normalized.get("id", "")).strip_edges()
		if prefetched_id != "":
			_recommendation_prefetch_seen_ids[prefetched_id] = true
		_recommendation_store.call("upsert_item", normalized, false)
		_recommendation_store.call("save_cache")
		if _recommendation_prefetch_remaining > 0:
			_request_next_remote_recommendation_prefetch()
		else:
			_set_recommendation_status("已同步更多服务器推荐，可以继续换一套。")
			_refresh_recommendation_cards()
		return

	if fetch_reason == "open_refresh":
		_current_recommendation = normalized
		_recommendation_store.call("upsert_item", normalized, true)
		_recommendation_store.call("save_cache")
		var latest_deck_name := str(normalized.get("deck_name", "最新卡组推荐"))
		_set_recommendation_status("已更新服务器推荐：%s。" % latest_deck_name)
		_refresh_recommendation_cards()
		_begin_remote_recommendation_prefetch()
		return

	_recommendation_store.call("upsert_item", normalized, false)
	var current_id := str(_current_recommendation.get("id", "")).strip_edges()
	var next_recommendation := _select_next_recommendation_from_pool(_combined_recommendation_pool(), current_id)
	if next_recommendation.is_empty():
		_set_recommendation_status("服务器推荐已保存，但暂时没有可切换的下一套。")
		_recommendation_store.call("save_cache")
		_refresh_recommendation_cards()
		return

	_current_recommendation = next_recommendation
	_recommendation_store.call("upsert_item", next_recommendation, true)
	_recommendation_store.call("save_cache")
	var deck_name := str(next_recommendation.get("deck_name", "新卡组推荐"))
	_set_recommendation_status("已切换推荐：%s。" % deck_name)
	_refresh_recommendation_cards()
	_begin_remote_recommendation_prefetch()


func _on_remote_recommendation_failed(message: String) -> void:
	var fetch_reason := _recommendation_fetch_reason
	_recommendation_fetch_reason = ""
	_recommendation_fetch_in_progress = false
	if fetch_reason == "prefetch":
		_recommendation_prefetch_remaining = 0
		_set_recommendation_status("已同步已可用的服务器推荐，可以继续换一套。")
		_refresh_recommendation_cards()
		return
	if fetch_reason == "open_refresh":
		_set_recommendation_status(message)
		_refresh_recommendation_cards()
		return
	_switch_to_local_next_recommendation(message)


func _extract_recommendation_bullets(article: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	var sections_raw: Variant = article.get("sections", [])
	var sections: Array = sections_raw if sections_raw is Array else []
	for section_raw: Variant in sections:
		if section_raw is not Dictionary:
			continue
		var section := section_raw as Dictionary
		var heading := str(section.get("heading", ""))
		var bullets_raw: Variant = section.get("bullets", [])
		var bullets: Array = bullets_raw if bullets_raw is Array else []
		if not heading.contains("今天怎么练") and result.size() > 0:
			continue
		for bullet_raw: Variant in bullets:
			var bullet := str(bullet_raw).strip_edges()
			if bullet == "":
				continue
			result.append(bullet)
			if result.size() >= 2:
				return result
	return result


func _extract_recommendation_import_url(article: Dictionary) -> String:
	var snapshot := _as_dictionary(article.get("deck_snapshot", {}))
	var import_url := str(snapshot.get("import_url", snapshot.get("source_url", ""))).strip_edges()
	if import_url != "":
		return import_url

	var links_raw: Variant = article.get("links", [])
	var links: Array = links_raw if links_raw is Array else []
	for link_raw: Variant in links:
		if link_raw is not Dictionary:
			continue
		var link := link_raw as Dictionary
		var url := str(link.get("url", "")).strip_edges()
		if url.contains("tcg.mik.moe/decks/list/"):
			return url
	return ""


func _extract_recommendation_deck_id(article: Dictionary) -> int:
	var snapshot := _as_dictionary(article.get("deck_snapshot", {}))
	var raw_id: Variant = snapshot.get("deck_id", 0)
	var deck_id := int(raw_id) if str(raw_id).is_valid_int() else 0
	if deck_id > 0:
		return deck_id
	return DeckImporter.parse_deck_id(_extract_recommendation_import_url(article))


func _show_recommendation_article_dialog(recommendation: Dictionary) -> void:
	var normalized := _normalize_recommendation_input(recommendation)
	if normalized.is_empty():
		return
	_close_recommendation_detail_overlay()

	var overlay := Control.new()
	overlay.name = "RecommendationDetailOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_recommendation_detail_overlay = overlay

	var shade := ColorRect.new()
	shade.name = "RecommendationDetailShade"
	shade.color = Color(0.0, 0.0, 0.0, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)

	var margin := MarginContainer.new()
	margin.name = "RecommendationDetailMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 24
	margin.offset_top = 24
	margin.offset_right = -24
	margin.offset_bottom = -24
	overlay.add_child(margin)

	var panel := PanelContainer.new()
	panel.name = "RecommendationDetailPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.025, 0.055, 0.085, 0.98), Color(HUD_RECOMMENDATION_BORDER.r, HUD_RECOMMENDATION_BORDER.g, HUD_RECOMMENDATION_BORDER.b, 0.92), 22))
	margin.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	outer.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var deck_name := Label.new()
	deck_name.text = str(normalized.get("deck_name", "推荐卡组"))
	deck_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	deck_name.add_theme_font_size_override("font_size", 24)
	deck_name.add_theme_color_override("font_color", HUD_TEXT)
	title_box.add_child(deck_name)

	var meta := Label.new()
	meta.text = _recommendation_source_text(normalized)
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD
	meta.add_theme_color_override("font_color", HUD_ACCENT_WARM)
	title_box.add_child(meta)

	var scroll := ScrollContainer.new()
	scroll.name = "RecommendationDetailScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HudThemeScript.style_scroll_container(scroll)
	outer.add_child(scroll)

	var content_margin := MarginContainer.new()
	content_margin.name = "RecommendationDetailScrollMargin"
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_right", RECOMMENDATION_DETAIL_SCROLLBAR_RIGHT_CLEARANCE)
	scroll.add_child(content_margin)

	var content := VBoxContainer.new()
	content.name = "RecommendationDetailContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	content_margin.add_child(content)

	var title := Label.new()
	title.text = str(normalized.get("title", normalized.get("deck_name", "推荐卡组")))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0, 1.0))
	content.add_child(title)

	var style_summary := str(normalized.get("style_summary", "")).strip_edges()
	if style_summary != "":
		content.add_child(_create_recommendation_detail_paragraph(style_summary, HUD_TEXT_MUTED))

	var why_items: Array = normalized.get("why_play", [])
	if not why_items.is_empty():
		content.add_child(_create_recommendation_detail_heading("为什么值得玩"))
		for bullet_raw: Variant in why_items:
			var bullet := str(bullet_raw).strip_edges()
			if bullet != "":
				content.add_child(_create_recommendation_detail_paragraph("• " + bullet, HUD_TEXT_MUTED))

	var best_for := str(normalized.get("best_for", "")).strip_edges()
	if best_for != "":
		content.add_child(_create_recommendation_detail_heading("适合谁"))
		content.add_child(_create_recommendation_detail_paragraph(best_for, HUD_TEXT_MUTED))

	var pilot_tip := str(normalized.get("pilot_tip", "")).strip_edges()
	if pilot_tip != "":
		content.add_child(_create_recommendation_detail_heading("上手看点"))
		content.add_child(_create_recommendation_detail_paragraph(pilot_tip, HUD_TEXT_MUTED))

	var detail := _as_dictionary(normalized.get("detail", {}))
	var sections_raw: Variant = detail.get("sections", [])
	var sections: Array = sections_raw if sections_raw is Array else []
	for section_raw: Variant in sections:
		if section_raw is not Dictionary:
			continue
		var section := section_raw as Dictionary
		var heading := str(section.get("heading", "")).strip_edges()
		var body := str(section.get("body", "")).strip_edges()
		var bullets_raw: Variant = section.get("bullets", [])
		var bullets: Array = bullets_raw if bullets_raw is Array else []
		if heading != "":
			content.add_child(_create_recommendation_detail_heading(heading))
		if body != "":
			content.add_child(_create_recommendation_detail_paragraph(body, HUD_TEXT_MUTED))
		for bullet_raw: Variant in bullets:
			var bullet := str(bullet_raw).strip_edges()
			if bullet != "":
				content.add_child(_create_recommendation_detail_paragraph("• " + bullet, HUD_TEXT_MUTED))

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	footer.alignment = BoxContainer.ALIGNMENT_END
	outer.add_child(footer)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)

	var import_button := Button.new()
	import_button.text = "导入这套"
	import_button.custom_minimum_size = Vector2(124, 42)
	import_button.disabled = str(normalized.get("import_url", "")).strip_edges() == "" or _current_operation != ""
	import_button.pressed.connect(_on_recommendation_detail_import_pressed.bind(normalized))
	footer.add_child(import_button)
	_style_hud_button(import_button, HUD_ACCENT_WARM)

	var open_button := Button.new()
	open_button.text = "打开原卡表"
	open_button.custom_minimum_size = Vector2(136, 42)
	open_button.disabled = str(normalized.get("import_url", "")).strip_edges() == ""
	open_button.pressed.connect(_on_recommendation_open_pressed.bind(normalized))
	footer.add_child(open_button)
	_style_hud_button(open_button, HUD_ACCENT)

	var close_footer_button := Button.new()
	close_footer_button.text = "关闭"
	close_footer_button.custom_minimum_size = Vector2(96, 42)
	close_footer_button.pressed.connect(_close_recommendation_detail_overlay)
	footer.add_child(close_footer_button)
	_style_hud_button(close_footer_button, HUD_SECONDARY)

	add_child(overlay)
	move_child(overlay, get_child_count() - 1)


func _create_recommendation_detail_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", HUD_ACCENT_WARM)
	return label


func _create_recommendation_detail_paragraph(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", color)
	return label


func _on_recommendation_detail_import_pressed(recommendation: Dictionary) -> void:
	_close_recommendation_detail_overlay()
	_on_recommendation_import_pressed(recommendation)


func _close_recommendation_detail_overlay() -> void:
	if _recommendation_detail_overlay != null and is_instance_valid(_recommendation_detail_overlay):
		_recommendation_detail_overlay.queue_free()
	_recommendation_detail_overlay = null


func _refresh_deck_list() -> void:
	var deck_list_container: VBoxContainer = %DeckList
	_refresh_recommendation_cards()
	for child: Node in deck_list_container.get_children():
		if child != %EmptyLabel and child != _recommendation_section:
			child.queue_free()

	var decks := CardDatabase.get_all_decks()
	%EmptyLabel.visible = decks.is_empty()

	for deck: DeckData in decks:
		deck_list_container.add_child(_create_deck_item(deck))


func _create_deck_item(deck: DeckData) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 76)
	panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.035, 0.075, 0.11, 0.88), HUD_CARD_BORDER, 16))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label := Label.new()
	name_label.text = deck.deck_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", HUD_TEXT)
	info_vbox.add_child(name_label)

	var detail_label := Label.new()
	detail_label.text = "%d 张卡牌 | 导入于 %s" % [deck.total_cards, deck.import_date.substr(0, 10)]
	detail_label.add_theme_color_override("font_color", HUD_TEXT_MUTED)
	info_vbox.add_child(detail_label)

	var btn_view := Button.new()
	btn_view.text = "查看"
	btn_view.custom_minimum_size = Vector2(78, 38)
	btn_view.pressed.connect(_on_view_deck.bind(deck))
	hbox.add_child(btn_view)

	var btn_edit := Button.new()
	btn_edit.text = "编辑"
	btn_edit.custom_minimum_size = Vector2(78, 38)
	btn_edit.pressed.connect(_on_edit_deck.bind(deck))
	hbox.add_child(btn_edit)

	var btn_rename := Button.new()
	btn_rename.text = "重命名"
	btn_rename.custom_minimum_size = Vector2(96, 38)
	btn_rename.pressed.connect(_on_rename_deck.bind(deck))
	hbox.add_child(btn_rename)

	var btn_delete := Button.new()
	btn_delete.text = "删除"
	btn_delete.custom_minimum_size = Vector2(78, 38)
	btn_delete.pressed.connect(_on_delete_deck.bind(deck))
	hbox.add_child(btn_delete)

	_style_hud_button(btn_view, HUD_SECONDARY, true)
	_style_hud_button(btn_edit, HUD_ACCENT, true)
	_style_hud_button(btn_rename, HUD_RENAME, true)
	_style_hud_button(btn_delete, HUD_DANGER, true)

	return panel


func _on_import_pressed() -> void:
	if _current_operation != "":
		return
	_cancel_import_result_auto_close()
	_pending_import_deck_name_override = ""
	_panel_mode = "import"
	_configure_operation_panel()
	%UrlInput.text = ""
	%UrlInput.editable = true
	%ProgressLabel.text = ""
	%ProgressBar.visible = false
	%BtnDoImport.visible = true
	%BtnDoImport.disabled = false
	%ImportPanel.visible = true


func _on_recommendation_import_pressed(recommendation: Dictionary) -> void:
	var normalized := _normalize_recommendation_input(recommendation)
	var import_url := str(normalized.get("import_url", "")).strip_edges()
	if import_url == "":
		_set_recommendation_status("这套推荐缺少可导入的卡组链接。")
		return
	var recommended_deck_name := str(normalized.get("deck_name", "")).strip_edges()
	_start_import_from_url(import_url, "正在导入推荐卡组...", recommended_deck_name)


func _on_recommendation_open_pressed(recommendation: Dictionary) -> void:
	var normalized := _normalize_recommendation_input(recommendation)
	var import_url := str(normalized.get("import_url", "")).strip_edges()
	if import_url == "":
		return
	var err := OS.shell_open(import_url)
	if err != OK:
		push_warning("无法打开推荐卡表: %s" % import_url)


func _on_recommendation_read_pressed(recommendation: Dictionary) -> void:
	_show_recommendation_article_dialog(recommendation)


func _on_close_import() -> void:
	_cancel_import_result_auto_close()
	%ImportPanel.visible = false


func _on_do_import() -> void:
	if _panel_mode != "import":
		return

	var url: String = %UrlInput.text.strip_edges()
	if url.is_empty():
		%ProgressLabel.text = "请输入卡组链接或卡组 ID。"
		return

	_start_import_from_url(url, "正在导入卡组...")


func _start_import_from_url(url: String, progress_text: String, deck_name_override: String = "") -> void:
	if _current_operation != "":
		return

	_cancel_import_result_auto_close()
	_pending_import_deck_name_override = deck_name_override.strip_edges()
	_current_operation = "import"
	_panel_mode = "import"
	_configure_operation_panel()
	_set_operation_busy(true)
	%ImportPanel.visible = true
	%UrlInput.text = url
	%UrlInput.editable = false
	%BtnDoImport.visible = false
	%BtnDoImport.disabled = true
	%ProgressBar.visible = true
	%ProgressBar.value = 0
	%ProgressLabel.text = progress_text
	_importer.import_deck(url)


func _on_sync_images_pressed() -> void:
	if _current_operation != "":
		return

	_cancel_import_result_auto_close()
	_panel_mode = "sync_images"
	_configure_operation_panel()
	%ImportPanel.visible = true
	_current_operation = "sync_images"
	_set_operation_busy(true)
	%ProgressBar.visible = true
	%ProgressBar.value = 0
	%ProgressLabel.text = "正在同步卡图..."
	_image_syncer.sync_cached_cards()


func _on_import_progress(current: int, total: int, message: String) -> void:
	%ProgressLabel.text = message
	if total > 0:
		%ProgressBar.value = (float(current) / total) * 100.0


func _on_import_completed(deck: DeckData, errors: PackedStringArray) -> void:
	_apply_pending_import_deck_name_override(deck)
	if _has_duplicate_deck_name(deck.deck_name, deck.id):
		_pending_import_deck = deck
		_pending_import_errors = PackedStringArray(errors)
		_show_import_rename_dialog(deck.deck_name)
		return

	_finalize_import_save(deck, errors)


func _finalize_import_save(deck: DeckData, errors: PackedStringArray) -> void:
	CardDatabase.save_deck(deck)
	_current_operation = ""
	_pending_import_deck_name_override = ""
	_set_operation_busy(false)

	var result_message := ""
	if errors.is_empty():
		result_message = "导入成功：%s（%d 张卡）" % [deck.deck_name, deck.total_cards]
	else:
		result_message = "导入成功，包含 %d 条警告" % errors.size()
		for err: String in errors:
			push_warning("导入警告：%s" % err)
	_show_import_result(result_message)


func _has_duplicate_deck_name(deck_name: String, ignored_deck_id: int = -1) -> bool:
	var normalized_name: String = deck_name.strip_edges()
	if normalized_name == "":
		return false

	for deck: DeckData in CardDatabase.get_all_decks():
		if deck.id == ignored_deck_id:
			continue
		if deck.deck_name.strip_edges() == normalized_name:
			return true

	return false


func _validate_deck_name(deck_name: String, ignored_deck_id: int = -1) -> String:
	var normalized_name: String = deck_name.strip_edges()
	if normalized_name == "":
		return "请输入卡组名称。"
	if _has_duplicate_deck_name(normalized_name, ignored_deck_id):
		return "已有已保存卡组使用该名称。"
	return ""


func _validate_import_deck_name(deck_name: String) -> String:
	return _validate_deck_name(deck_name)


func _apply_pending_import_deck_name_override(deck: DeckData) -> void:
	var override_name := _pending_import_deck_name_override.strip_edges()
	_pending_import_deck_name_override = ""
	if deck == null or override_name == "":
		return
	deck.deck_name = override_name


func _on_rename_deck(deck: DeckData) -> void:
	_show_rename_dialog(
		deck.deck_name,
		"重命名卡组",
		"请输入新的卡组名称。",
		deck.id
	)
	_rename_target_deck = deck
	_rename_context = "existing"
	_rename_forced = false


func _show_import_rename_dialog(initial_name: String) -> void:
	_show_rename_dialog(
		initial_name,
		"卡组名称重复",
		"导入的卡组名称已存在，请输入一个不同的名称后再保存。",
		-1
	)
	_rename_target_deck = _pending_import_deck
	_rename_context = "import"
	_rename_forced = true


func _show_rename_dialog(initial_name: String, title: String, message_text: String, ignored_deck_id: int) -> void:
	_close_rename_dialog(false)

	_rename_ignore_deck_id = ignored_deck_id
	_rename_dialog = AcceptDialog.new()
	_rename_dialog.title = title
	_rename_dialog.ok_button_text = "\u786e\u8ba4"
	_rename_dialog.dialog_hide_on_ok = false
	_rename_dialog.min_size = RENAME_DIALOG_SIZE
	_rename_dialog.size = RENAME_DIALOG_SIZE
	_rename_dialog.close_requested.connect(_on_rename_close_requested)
	_rename_dialog.confirmed.connect(_on_confirm_rename)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(RENAME_DIALOG_SIZE.x - 40, 120)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	HudThemeScript.style_scroll_container(scroll)
	_rename_dialog.add_child(scroll)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(RENAME_DIALOG_SIZE.x - 60, 0)
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)

	var message := Label.new()
	message.text = message_text
	message.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(message)

	_rename_input = LineEdit.new()
	_rename_input.text = initial_name
	_rename_input.text_changed.connect(_on_rename_text_changed)
	content.add_child(_rename_input)

	_rename_error_label = Label.new()
	_rename_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_rename_error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	content.add_child(_rename_error_label)

	add_child(_rename_dialog)
	_rename_confirm_button = _rename_dialog.get_ok_button()
	_on_rename_text_changed(initial_name)

	if is_inside_tree():
		_rename_dialog.popup_centered(RENAME_DIALOG_SIZE)

func _on_rename_text_changed(new_text: String) -> void:
	var validation_error: String = _validate_deck_name(new_text, _rename_ignore_deck_id)
	if _rename_error_label != null:
		_rename_error_label.text = validation_error
	if _rename_confirm_button != null:
		_rename_confirm_button.disabled = validation_error != ""


func _on_confirm_rename() -> void:
	if _rename_target_deck == null or _rename_input == null:
		return

	var new_name: String = _rename_input.text.strip_edges()
	var validation_error: String = _validate_deck_name(new_name, _rename_ignore_deck_id)
	if validation_error != "":
		_on_rename_text_changed(new_name)
		return

	var deck := _rename_target_deck
	var is_import_rename := _rename_context == "import"
	var errors := PackedStringArray(_pending_import_errors)
	deck.deck_name = new_name

	if is_import_rename:
		_pending_import_deck = null
		_pending_import_errors = PackedStringArray()
	else:
		CardDatabase.save_deck(deck)

	_close_rename_dialog()

	if is_import_rename:
		_finalize_import_save(deck, errors)


func _on_rename_close_requested() -> void:
	if _rename_forced:
		if _rename_dialog != null and is_instance_valid(_rename_dialog) and is_inside_tree():
			_rename_dialog.popup_centered(RENAME_DIALOG_SIZE)
		return

	_close_rename_dialog()


func _close_rename_dialog(clear_target: bool = true) -> void:
	if _rename_dialog != null and is_instance_valid(_rename_dialog):
		_rename_dialog.queue_free()

	_rename_dialog = null
	_rename_input = null
	_rename_error_label = null
	_rename_confirm_button = null
	_rename_ignore_deck_id = -1
	_rename_context = ""
	_rename_forced = false

	if clear_target:
		_rename_target_deck = null


func _on_import_rename_text_changed(new_text: String) -> void:
	_on_rename_text_changed(new_text)


func _on_confirm_import_rename() -> void:
	_on_confirm_rename()


func _on_import_rename_close_requested() -> void:
	_on_rename_close_requested()


func _close_import_rename_dialog() -> void:
	_close_rename_dialog()


func _on_import_failed(error_message: String) -> void:
	_current_operation = ""
	_set_operation_busy(false)
	_pending_import_deck = null
	_pending_import_errors = PackedStringArray()
	_pending_import_deck_name_override = ""
	_show_import_result("导入失败：%s" % error_message)


func _show_import_result(message: String) -> void:
	%ProgressBar.visible = false
	%UrlInput.editable = false
	%BtnDoImport.visible = false
	%BtnDoImport.disabled = true
	%ProgressLabel.text = message
	_schedule_import_result_auto_close()


func _schedule_import_result_auto_close() -> void:
	if not is_inside_tree():
		return
	_ensure_import_result_close_timer()
	_import_result_close_timer.start(IMPORT_RESULT_AUTO_CLOSE_SECONDS)


func _ensure_import_result_close_timer() -> void:
	if _import_result_close_timer != null and is_instance_valid(_import_result_close_timer):
		return
	_import_result_close_timer = Timer.new()
	_import_result_close_timer.name = "ImportResultCloseTimer"
	_import_result_close_timer.one_shot = true
	_import_result_close_timer.timeout.connect(_on_import_result_close_timeout)
	add_child(_import_result_close_timer)


func _cancel_import_result_auto_close() -> void:
	if _import_result_close_timer != null and is_instance_valid(_import_result_close_timer):
		_import_result_close_timer.stop()


func _on_import_result_close_timeout() -> void:
	if _current_operation == "":
		%ImportPanel.visible = false


func _on_image_sync_progress(current: int, total: int, message: String) -> void:
	%ProgressLabel.text = message
	if total > 0:
		%ProgressBar.value = (float(current) / total) * 100.0


func _on_image_sync_completed(stats: Dictionary, errors: PackedStringArray) -> void:
	%ProgressBar.visible = false
	_current_operation = ""
	_set_operation_busy(false)

	var total := int(stats.get("total", 0))
	var downloaded := int(stats.get("downloaded", 0))
	var updated := int(stats.get("updated", 0))
	var skipped := int(stats.get("skipped", 0))

	if errors.is_empty():
		%ProgressLabel.text = "同步完成：共 %d 张，下载 %d 张，跳过 %d 张，更新 %d 张" % [
			total, downloaded, skipped, updated
		]
	else:
		%ProgressLabel.text = "同步完成：共 %d 张，下载 %d 张，警告 %d 条" % [
			total, downloaded, errors.size()
		]
		for err: String in errors:
			push_warning("卡图同步警告：%s" % err)


func _on_image_sync_failed(error_message: String) -> void:
	%ProgressBar.visible = false
	_current_operation = ""
	_set_operation_busy(false)
	%ProgressLabel.text = "同步失败：%s" % error_message


func _on_edit_deck(deck: DeckData) -> void:
	GameManager.goto_deck_editor(deck.id)


func _on_view_deck(deck: DeckData) -> void:
	_deck_view_dialog.call("show_deck", self, deck)


const VIEW_CATEGORY_ORDER: Dictionary = {
	"Pokemon": 0,
	"Item": 1,
	"Tool": 2,
	"Supporter": 3,
	"Stadium": 4,
	"Basic Energy": 5,
	"Special Energy": 6,
}


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


func _create_view_tile(card_name: String, set_code: String, card_index: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_TILE_WIDTH, CARD_TILE_HEIGHT + 20)
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
	tex_rect.custom_minimum_size = Vector2(CARD_TILE_WIDTH - 8, CARD_TILE_HEIGHT - 8)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var texture := _load_card_texture(set_code, card_index)
	if texture != null:
		tex_rect.texture = texture
	else:
		var placeholder := PlaceholderTexture2D.new()
		placeholder.size = Vector2(CARD_TILE_WIDTH - 8, CARD_TILE_HEIGHT - 8)
		tex_rect.texture = placeholder
	vbox.add_child(tex_rect)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = card_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(CARD_TILE_WIDTH - 8, 0)
	vbox.add_child(label)

	return panel


func _on_view_tile_input(event: InputEvent, set_code: String, card_index: String) -> void:
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		return
	if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		var card := CardDatabase.get_card(set_code, card_index)
		if card != null:
			_show_card_detail(card)


func _show_card_detail(card: CardData) -> void:
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
	header.add_theme_font_size_override("font_size", 20)
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

	add_child(dialog)
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


func _on_delete_deck(deck: DeckData) -> void:
	var confirm := ConfirmationDialog.new()
	confirm.title = "确认删除"
	confirm.dialog_text = "确定要删除卡组“%s”吗？" % deck.deck_name
	confirm.ok_button_text = "删除"
	confirm.cancel_button_text = "取消"
	confirm.confirmed.connect(func() -> void:
		CardDatabase.delete_deck(deck.id)
		confirm.queue_free()
	)
	confirm.canceled.connect(confirm.queue_free)
	add_child(confirm)
	confirm.popup_centered()


func _on_back_pressed() -> void:
	GameManager.goto_main_menu()


func _configure_operation_panel() -> void:
	var title_label: Label = $ImportPanel/ImportBox/VBox/TitleLabel
	var hint_label: Label = $ImportPanel/ImportBox/VBox/HintLabel

	if _panel_mode == "sync_images":
		title_label.text = "同步卡图"
		hint_label.visible = false
		%UrlInput.visible = false
		%BtnDoImport.visible = false
	else:
		title_label.text = "导入卡组"
		hint_label.visible = true
		%UrlInput.visible = true
		%BtnDoImport.visible = true

	%BtnCloseImport.text = "关闭"


func _set_operation_busy(busy: bool) -> void:
	%BtnImport.disabled = busy
	%BtnSyncImages.disabled = busy
	%BtnBack.disabled = busy
	_refresh_recommendation_cards()
