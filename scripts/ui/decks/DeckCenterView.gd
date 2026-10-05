extends RefCounted
## Presentation and local navigation only. Import, persistence and sharing remain with DeckManager.
const UI := preload("res://scripts/ui/decks/DeckCenterTheme.gd")
const CardProxy := preload("res://scripts/ui/cards/CardImageOrProxyView.gd")
const Discovery := preload("res://scripts/ui/decks/DeckDiscoveryCarousel.gd")
const BACKDROP := preload("res://assets/ui/deck_center_backdrop.svg")
var _discovery: PanelContainer
var _discovery_profile := ""
var _slide_direction := 0
var _host_ref: WeakRef
var layout: Dictionary = {}
var selected_id := -1
var _top: HBoxContainer
var _body: HBoxContainer
var _library: VBoxContainer
var _preview: PanelContainer
var _count: Label
var _sort: OptionButton
var _timer: Timer
var _paused := false
var _hovered := false
var _elapsed := 0.0
var _detail: Control
var _detail_id := -1
var _detail_scroll := 0
var _layout_pending := false
var _last_profile := ""
var _page_content: VBoxContainer
var _touch_router := preload("res://scripts/ui/decks/DeckCenterGestureRouter.gd").new()

func host() -> Control:
	return _host_ref.get_ref() as Control if _host_ref != null else null

func setup(scene: Control) -> void:
	_host_ref = weakref(scene)
	layout = UI.for_control(scene)
	var outer := scene.get_node("MarginContainer/VBox") as VBoxContainer
	var header := scene.find_child("Header", true, false) as VBoxContainer
	_top = HBoxContainer.new()
	_top.name = "DeckCenterTopBar"
	header.add_child(_top)
	header.move_child(_top, 0)
	scene.get_node("%BtnBack").reparent(_top)
	scene.get_node("%BtnBack").text = "‹ 返回"
	scene.find_child("Title", true, false).reparent(_top)
	scene.find_child("Footer", true, false).hide()
	_body = HBoxContainer.new()
	_body.name = "DeckWorkspace"
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_body)
	# Reparenting this generated workspace must preserve its scene-owned
	# descendants and their %DeckList / %DeckSearchInput bindings.
	_body.owner = scene
	outer.move_child(_body, 1)
	_library = VBoxContainer.new()
	_library.name = "DeckLibrary"
	_library.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_library)
	var library_header := HBoxContainer.new()
	library_header.name = "DeckLibraryHeading"
	_library.add_child(library_header)
	_count = UI.label("我的卡组")
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_header.add_child(_count)
	_sort = OptionButton.new()
	_sort.name = "DeckSortButton"
	_sort.add_item("最近编辑")
	_sort.add_item("名称排序")
	_sort.item_selected.connect(_sort_changed)
	library_header.add_child(_sort)
	scene.find_child("DeckSearchRow", true, false).reparent(_library)
	scene.find_child("DeckScroll", true, false).reparent(_library)
	scene.get_node("%DeckSearchInput").placeholder_text = "搜索卡组或卡牌名称"
	_preview = PanelContainer.new()
	_preview.name = "DeckSelectionPreview"
	_body.add_child(_preview)
	_timer = Timer.new()
	_timer.name = "DiscoveryCarouselTimer"
	_timer.wait_time = 1.0
	_timer.timeout.connect(_carousel_tick)
	scene.add_child(_timer)
	_timer.start()
	scene.resized.connect(_queue_layout)
	apply_layout()

func _queue_layout() -> void:
	if _layout_pending:
		return
	cancel_discovery_input()
	_layout_pending = true
	call_deferred("_relayout")

func _relayout() -> void:
	_layout_pending = false
	var scene := host()
	if scene == null or not scene.is_inside_tree():
		return
	scene.call("_apply_non_battle_layout")

func apply_layout(override_size: Vector2 = Vector2.ZERO) -> void:
	var scene := host()
	if scene == null:
		return
	layout = UI.for_control(scene, override_size)
	# Windows and the browser preview use the full-width library. Other native
	# desktop platforms retain their existing layout for this scoped change.
	if OS.has_feature("windows") or OS.has_feature("web"):
		layout.sidebar = false
		if not layout.portrait and not layout.compact:
			layout.columns = clampi(int((float(layout.size.x) - 2 * float(layout.margin)) / float(layout.scale) / 300.0), 2, 5)
	var scale: float = layout.scale
	var portrait: bool = layout.portrait
	var compact: bool = layout.compact
	var margin := scene.get_node("MarginContainer") as MarginContainer
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, roundi(layout.margin if side in ["left", "right"] else 12 * scale))
	var background := scene.get_node("Background") as TextureRect
	background.texture = BACKDROP
	background.show()
	scene.get_node("BackgroundShade").color = Color(UI.BG, 0.12)
	var frame := scene.get_node_or_null("HudFrame") as Control
	if frame != null:
		frame.hide()
	var header := scene.find_child("Header", true, false) as VBoxContainer
	var actions := scene.find_child("HeaderActions", true, false) as GridContainer
	var destination: Node = header if portrait else _top
	if actions.get_parent() != destination:
		actions.reparent(destination)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", roundi(10 * scale))
	_top.add_theme_constant_override("separation", roundi(12 * scale))
	var title := scene.find_child("Title", true, false) as Label
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", roundi((22 if portrait else 25) * scale))
	title.add_theme_color_override("font_color", UI.TEXT)
	title.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_SHRINK_END
	actions.columns = 3
	actions.add_theme_constant_override("h_separation", roundi(8 * scale))
	for button_name: String in ["BtnNewDeck", "BtnImport", "BtnSyncImages", "BtnBack", "DeckSearchClearButton"]:
		var button := scene.get_node("%" + button_name) as Button
		UI.button(button, scale, button_name == "BtnNewDeck")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if button_name != "BtnBack" else Control.SIZE_FILL
	scene.get_node("%BtnNewDeck").text = "＋ 新建"
	scene.get_node("%BtnImport").text = "导入卡组"
	scene.get_node("%BtnSyncImages").text = "同步卡图"
	UI.input(scene.get_node("%DeckSearchInput"), scale)
	scene.get_node("%DeckSearchClearButton").custom_minimum_size.x = 48 * scale
	scene.get_node("%DeckSearchClearButton").size_flags_horizontal = Control.SIZE_FILL
	var search_row := scene.find_child("DeckSearchRow", true, false) as HBoxContainer
	var library_heading := scene.find_child("DeckLibraryHeading", true, false) as HBoxContainer
	var search_parent: Node = library_heading if compact else _library
	if search_row.get_parent() != search_parent:
		search_row.reparent(search_parent)
		search_parent.move_child(search_row, 1)
	_count.visible = not compact
	search_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.add_theme_font_size_override("font_size", roundi(20 * scale))
	UI.button(_sort, scale)
	_sort.add_theme_font_size_override("font_size", roundi(14 * scale))
	UI.popup(_sort.get_popup(), scale)
	_body.add_theme_constant_override("separation", roundi(20 * scale))
	_library.add_theme_constant_override("separation", roundi(10 * scale))
	_preview.visible = bool(layout.sidebar)
	_preview.custom_minimum_size.x = 308 * scale if _preview.visible else 0.0
	_preview.add_theme_stylebox_override("panel", UI.box(UI.SURFACE, UI.LINE, roundi(14 * scale), 16 * scale))
	var grid := scene.get_node("%DeckList") as GridContainer
	grid.columns = int(layout.columns)
	grid.add_theme_constant_override("h_separation", roundi(12 * scale))
	grid.add_theme_constant_override("v_separation", roundi(12 * scale))
	var scroll := scene.find_child("DeckScroll", true, false) as ScrollContainer
	scroll.custom_minimum_size.y = 0
	UI.scroll(scroll)
	scene.find_child("DeckScrollMargin", true, false).add_theme_constant_override("margin_right", roundi(6 * scale))
	_set_page_scroll_enabled(OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or (OS.has_feature("web") and DisplayServer.is_touchscreen_available()))
	var section := scene.get("_recommendation_section") as Control
	if section != null:
		var outer: Node = _page_content if is_instance_valid(_page_content) else scene.get_node("MarginContainer/VBox")
		if section.get_parent() != outer:
			section.reparent(outer)
		outer.move_child(section, 0 if is_instance_valid(_page_content) else 1)
	var key := "%s:%s:%s:%s" % [portrait, compact, layout.columns, snappedf(scale, 0.02)]
	if key != _last_profile:
		_last_profile = key
		# Rebuild only presentation at a breakpoint; the deck model and selection stay intact.
		if scene.is_node_ready():
			scene.call_deferred("_refresh_deck_list")
		if is_instance_valid(_detail):
			_detail_scroll = _detail.find_child("CenterDetailScroll", true, false).scroll_vertical
			show_detail(CardDatabase.get_deck(_detail_id))
	refresh_preview()

func _set_page_scroll_enabled(enabled: bool) -> void:
	var scene := host()
	var outer := scene.get_node("MarginContainer/VBox")
	var scroll := scene.find_child("DeckScroll", true, false) as ScrollContainer
	var cards := scene.find_child("DeckScrollMargin", true, false) as Control
	var section := scene.get("_recommendation_section") as Control
	if enabled:
		if not is_instance_valid(_page_content):
			_reparent_page_node(cards, _library)
			_reparent_page_node(scroll, outer)
			_page_content = VBoxContainer.new()
			_page_content.name = "DeckPageContent"
			_page_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(_page_content)
			_reparent_page_node(_body, _page_content)
			_body.size_flags_vertical = Control.SIZE_FILL
		_page_content.add_theme_constant_override("separation", roundi(12 * float(layout.scale)))
		if section != null and section.get_parent() != _page_content:
			section.reparent(_page_content)
			_page_content.move_child(section, 0)
	elif is_instance_valid(_page_content):
		if section != null:
			section.reparent(outer)
		_reparent_page_node(_body, outer)
		_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.remove_child(_page_content)
		_page_content.queue_free()
		_page_content = null
		_reparent_page_node(cards, scroll)
		_reparent_page_node(scroll, _library)
		scroll.scroll_vertical = 0

func _reparent_page_node(node: Node, destination: Node) -> void:
	# Runtime containers have no scene owner. Preserve the packed scene's unique
	# references when moving an entire branch through those containers.
	var owned: Array[Node] = []
	for child: Node in [node] + node.find_children("*", "", true, false):
		if child.owner == host():
			owned.append(child)
	node.reparent(destination)
	for child: Node in owned:
		child.owner = host()

func input_scope() -> Control:
	var scene := host()
	var top: Control = scene
	for child: Node in scene.get_children():
		if not child is Control or not child.is_visible_in_tree() or child.is_queued_for_deletion():
			continue
		# Rotation may rebuild an overlay while its old namesake awaits deletion.
		# Godot renames the new node; modal ownership must survive that rename.
		if not bool(child.get_meta("deck_center_modal", false)) and not child.is_in_group("game_modal_dialogs") and child.name not in ["DeckCenterDetail", "DeckWorkspaceCardReader", "DiscoveryPosterViewer", "RecommendationDetailOverlay", "DeckActionHudOverlay", "ImportPanel"]:
			continue
		if top == scene or child.z_index >= top.z_index:
			top = child
	return top

func handle_input(event: InputEvent) -> bool:
	if _touch_router.handle_center(self, event):
		return true
	return event is InputEventMouse and input_scope() == host() and handle_discovery_input(event)

func create_deck_item(deck: DeckData) -> Control:
	var scale: float = layout.get("scale", 1.0)
	var portrait: bool = layout.get("portrait", false)
	var compact: bool = layout.get("compact", false)
	var panel := PanelContainer.new()
	panel.name = "DeckRowItem"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_meta("deck_id", deck.id)
	panel.set_meta("deck_name", deck.deck_name)
	var search := deck.deck_name
	for entry: Dictionary in deck.cards:
		search += " " + CardData.dictionary_display_name(entry)
	panel.set_meta("search_text", search)
	panel.add_theme_stylebox_override("panel", UI.card_surface(scale, deck.id == selected_id, compact))
	var root: BoxContainer = HBoxContainer.new() if portrait else VBoxContainer.new()
	root.add_theme_constant_override("separation", roundi(12 * scale))
	panel.add_child(root)
	if not compact:
		var art := thumbnail(deck, Vector2(78, 112) * scale if portrait else Vector2(0, 124) * scale)
		root.add_child(art)
		var open := UI.action("", _select.bind(deck.id), scale)
		open.name = "DeckRowViewButton"
		open.tooltip_text = "查看 " + deck.deck_name
		for state: String in ["normal", "hover", "pressed"]:
			open.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		art.add_child(open)
		open.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", roundi((5 if compact else 8) * scale))
	root.add_child(info)
	var info_surface := PanelContainer.new()
	info_surface.name = "DeckRowInfoArea"
	info_surface.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	info.add_child(info_surface)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", roundi((5 if compact else 8) * scale))
	info_surface.add_child(copy)
	var name_label := UI.label(deck.deck_name, 18 * scale)
	name_label.name = "DeckRowName"
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.tooltip_text = deck.deck_name
	copy.add_child(name_label)
	var count_text := "%d 张 · %s" % [deck.total_cards, "可用卡组" if deck.total_cards == 60 else "需要调整数量"]
	copy.add_child(UI.label(count_text, 13 * scale, UI.MUTED))
	if not portrait and not compact:
		copy.add_child(UI.label(UI.summary(deck), 12 * scale, UI.MUTED))
	var inspect := UI.action("", _select.bind(deck.id), scale)
	inspect.name = "DeckRowInfoButton"
	inspect.tooltip_text = "查看完整卡组：" + deck.deck_name
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		inspect.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	info_surface.add_child(inspect)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", roundi(8 * scale))
	info.add_child(buttons)
	if compact:
		var view := UI.action("查看", _select.bind(deck.id), scale)
		view.name = "DeckRowViewButton"
		buttons.add_child(view)
	var edit := UI.action("编辑卡组", _invoke.bind("_on_edit_deck", deck.id), scale)
	UI.tonal_button(edit, scale)
	edit.name = "DeckRowEditButton"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(edit)
	var more := UI.action("更多操作" if portrait else "更多", show_more.bind(deck.id), scale)
	more.name = "DeckRowMoreButton"
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A real labelled 48dp target in portrait, never an ellipsis hitbox.
	buttons.add_child(more)
	return panel

func thumbnail(deck: DeckData, minimum: Vector2) -> Control:
	var art := Control.new()
	art.custom_minimum_size = minimum
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL if minimum.x == 0 else Control.SIZE_FILL
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop := Panel.new()
	backdrop.add_theme_stylebox_override("panel", UI.box(UI.BG, UI.LINE, 10, 0))
	art.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var entries: Array[Dictionary] = []
	for entry: Dictionary in deck.cards:
		if str(entry.get("card_type", "")) == "Pokemon":
			entries.append(entry)
	if entries.is_empty():
		entries.assign(deck.cards)
	var count := mini(3, entries.size())
	for i: int in count:
		var entry: Dictionary = entries[i]
		var texture: Texture2D = host().call("_load_card_texture", str(entry.get("set_code", "")), str(entry.get("card_index", "")))
		if texture == null:
			continue
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(image)
		image.anchor_left = 0.02 + i * 0.22 if minimum.x == 0 else 0.02
		image.anchor_right = 0.54 + i * 0.22 if minimum.x == 0 else 0.98
		image.anchor_top = 0.12 if i != 1 else 0.02
		image.anchor_bottom = 1.12 if i != 1 else 1.02
		if minimum.x > 0:
			break
	if art.get_child_count() == 1:
		var fallback := UI.label("PTCG", 24 * float(layout.get("scale", 1.0)), UI.ACCENT)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		art.add_child(fallback)
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return art

func _select(deck_id: int) -> void:
	selected_id = deck_id
	refresh_preview()
	if not bool(layout.get("sidebar", false)):
		show_detail(CardDatabase.get_deck(deck_id))

func _invoke(method: String, deck_id: int) -> void:
	var deck := CardDatabase.get_deck(deck_id)
	if deck != null and host() != null:
		host().call(method, deck)

func show_more(deck_id: int) -> void:
	var deck := CardDatabase.get_deck(deck_id)
	if deck == null:
		return
	var scene := host()
	var shell: Dictionary = scene.call("_create_deck_action_hud_shell", "卡组操作", deck.deck_name, Vector2(520, 470), "deck_more")
	var content := shell.content as VBoxContainer
	var scale: float = layout.scale
	for spec: Array in [["查看完整卡组", "_on_view_deck", "DeckRowViewButton"], ["重命名", "_on_rename_deck", "DeckRowRenameButton"], ["分享卡组图", "_on_share_deck_poster", "DeckRowSharePosterButton"], ["删除卡组", "_on_delete_deck", "DeckRowDeleteButton"]]:
		var method := str(spec[1])
		var button := UI.action(str(spec[0]), func():
			scene.call("_close_deck_action_hud_dialog")
			scene.call_deferred(method, CardDatabase.get_deck(deck_id)), scale)
		button.name = str(spec[2])
		UI.button(button, scale, false, method == "_on_delete_deck")
		content.add_child(button)
	var close := UI.action("取消", Callable(scene, "_close_deck_action_hud_dialog"), scale)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(shell.footer as Control).add_child(close)

func update_count(matching: int, total: int) -> void:
	if _count == null:
		return
	_count.text = "我的卡组  %d" % total if matching == total else "我的卡组  %d / %d" % [matching, total]
	_sort_rows()
	refresh_preview()

func _sort_changed(_index: int) -> void:
	_sort_rows()

func _sort_rows() -> void:
	var grid := host().get_node("%DeckList")
	var rows: Array[Node] = []
	for node: Node in grid.get_children():
		if node.has_meta("deck_id"):
			rows.append(node)
	rows.sort_custom(func(a: Node, b: Node):
		if _sort.selected == 1:
			return str(a.get_meta("deck_name", "")).naturalnocasecmp_to(str(b.get_meta("deck_name", ""))) < 0
		var left := CardDatabase.get_deck(int(a.get_meta("deck_id")))
		var right := CardDatabase.get_deck(int(b.get_meta("deck_id")))
		return bool(host().call("_compare_decks_by_edit_time_desc", left, right)) if left != null and right != null else false)
	for i: int in rows.size():
		grid.move_child(rows[i], i)

func refresh_preview() -> void:
	if _preview == null or not _preview.visible:
		return
	var scene := host()
	var deck := CardDatabase.get_deck(selected_id)
	if deck == null:
		for child: Node in scene.get_node("%DeckList").get_children():
			if child.has_meta("deck_id") and child.visible:
				selected_id = int(child.get_meta("deck_id"))
				deck = CardDatabase.get_deck(selected_id)
				break
	UI.clear(_preview)
	var scale: float = layout.scale
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", roundi(14 * scale))
	_preview.add_child(column)
	column.add_child(UI.label("卡组预览", 14 * scale, UI.MUTED))
	if deck == null:
		column.add_child(UI.label("选择一套卡组开始", 19 * scale))
		return
	column.add_child(thumbnail(deck, Vector2(0, 132) * scale))
	var title := UI.label(deck.deck_name, 22 * scale)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	column.add_child(UI.label("%d 张卡牌" % deck.total_cards, 15 * scale, UI.ACCENT))
	column.add_child(UI.label(UI.summary(deck), 13 * scale, UI.MUTED))
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(space)
	column.add_child(UI.action("查看完整卡组", show_detail.bind(deck), scale))
	column.add_child(UI.action("编辑卡组", _invoke.bind("_on_edit_deck", deck.id), scale, true))
	for node: Node in scene.get_node("%DeckList").get_children():
		if node is PanelContainer and node.has_meta("deck_id"):
			node.add_theme_stylebox_override("panel", UI.card_surface(scale, int(node.get_meta("deck_id")) == selected_id, bool(layout.compact)))

func recommendation_card(recommendation: Dictionary) -> PanelContainer:
	var carousel := Discovery.new()
	carousel.setup(self, layout, recommendation)
	return carousel

func refresh_discovery(recommendation: Dictionary, feed: VBoxContainer) -> void:
	var key := "%s:%s:%s:%s" % [layout.portrait, layout.compact, layout.scale, layout.size]
	if not is_instance_valid(_discovery) or key != _discovery_profile:
		UI.clear(feed)
		_discovery = recommendation_card(recommendation)
		feed.add_child(_discovery)
		_discovery_profile = key
	else:
		_discovery.show_recommendation(recommendation, _slide_direction)
	_slide_direction = 0
	if host().is_inside_tree() and DisplayServer.get_name() != "headless":
		host().call_deferred("_request_recommendation_poster", recommendation.duplicate(true))

func apply_discovery_poster(key: String) -> void:
	if is_instance_valid(_discovery):
		_discovery.apply_poster(key)

func handle_discovery_input(event: InputEvent) -> bool:
	var scene := host()
	if not is_instance_valid(_discovery) or is_instance_valid(_detail) or scene.call("_is_import_panel_visible") or scene.call("_is_deck_action_hud_dialog_visible") or is_instance_valid(scene.get("_recommendation_detail_overlay")) or scene.get_node_or_null("DiscoveryPosterViewer") != null:
		return false
	return _discovery.handle_input(event)

func cancel_discovery_input() -> void:
	_touch_router.cancel()
	if is_instance_valid(_discovery):
		_discovery.cancel_interaction()

func _toggle_pause() -> void:
	_paused = not _paused
	_elapsed = 0
	var focused := host().get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	host().call("_refresh_recommendation_cards")

func _advance(direction: int) -> void:
	var scene := host()
	if scene == null or str(scene.get("_current_operation")) != "" or (is_instance_valid(_discovery) and _discovery.is_transitioning()):
		return
	_elapsed = 0
	var pool: Array = scene.call("_combined_recommendation_pool")
	if pool.size() < 2:
		return
	var current: Dictionary = scene.get("_current_recommendation")
	var index := 0
	for i: int in pool.size():
		if str(pool[i].get("id", "")) == str(current.get("id", "")):
			index = i
	_slide_direction = direction
	scene.set("_current_recommendation", pool[posmod(index + direction, pool.size())].duplicate(true))
	scene.call("_refresh_recommendation_cards")

func _carousel_tick() -> void:
	var scene := host()
	if scene == null or not scene.is_visible_in_tree() or _paused or (is_instance_valid(_discovery) and (_discovery.is_interacting() or _discovery.is_transitioning())):
		return
	if is_instance_valid(_detail) or scene.call("_is_import_panel_visible") or scene.call("_is_deck_action_hud_dialog_visible") or is_instance_valid(scene.get("_recommendation_detail_overlay")) or str(scene.get("_current_operation")) != "" or scene.get_node_or_null("DiscoveryPosterViewer") != null:
		_elapsed = 0
		return
	var focused := scene.get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_elapsed = 0
		return
	_elapsed += 1.0
	if is_instance_valid(_discovery):
		_discovery.set_progress(_elapsed / 8.0)
	if _elapsed >= 8.0:
		_advance(1)

func show_detail(deck: DeckData) -> void:
	if deck == null:
		return
	var scene := host()
	if is_instance_valid(_detail):
		_detail.queue_free()
	_detail_id = deck.id
	_detail = PanelContainer.new()
	_detail.name = "DeckCenterDetail"
	_detail.set_meta("deck_center_modal", true)
	_detail.z_index = 2000
	_detail.add_theme_stylebox_override("panel", UI.box(UI.BG, UI.BG, 0, float(layout.margin)))
	scene.add_child(_detail)
	_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scale: float = layout.scale
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", roundi(12 * scale))
	_detail.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var back := UI.action("‹ 返回", close_detail, scale)
	back.name = "CenterDetailBackButton"
	top.add_child(back)
	var title := UI.label(deck.deck_name, 22 * scale)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	root.add_child(UI.label("%d 张  ·  %s" % [deck.total_cards, UI.summary(deck)], 14 * scale, UI.MUTED))
	var scroll := ScrollContainer.new()
	scroll.name = "CenterDetailScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI.scroll(scroll)
	root.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", roundi(16 * scale))
	scroll.add_child(column)
	for category: String in ["Pokemon", "Trainer", "Energy"]:
		var entries: Array[Dictionary] = []
		var count := 0
		for entry: Dictionary in deck.cards:
			var kind := str(entry.get("card_type", ""))
			var group := "Pokemon" if kind == "Pokemon" else ("Energy" if kind.contains("Energy") else "Trainer")
			if group == category:
				entries.append(entry)
				count += int(entry.get("count", 0))
		if entries.is_empty():
			continue
		column.add_child(UI.label("%s  %d" % [{"Pokemon": "宝可梦", "Trainer": "训练家", "Energy": "能量"}[category], count], 18 * scale))
		var grid := GridContainer.new()
		grid.columns = 3 if layout.portrait else (6 if layout.compact else 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", roundi(10 * scale))
		grid.add_theme_constant_override("v_separation", roundi(14 * scale))
		column.add_child(grid)
		var width := (float(layout.size.x) - 2 * float(layout.margin) - 10 * scale * grid.columns) / grid.columns
		for entry: Dictionary in entries:
			var tile := VBoxContainer.new()
			tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(tile)
			var card := CardProxy.new()
			card.custom_minimum_size = Vector2(0, width * 1.4)
			card.setup_from_entry(entry, scene.get("_image_syncer"), {"portrait": bool(layout.portrait)})
			tile.add_child(card)
			var inspect := UI.action("× %d  详情" % int(entry.get("count", 0)), _inspect_card.bind(str(entry.get("set_code", "")), str(entry.get("card_index", ""))), scale)
			tile.add_child(inspect)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", roundi(10 * scale))
	root.add_child(footer)
	var share := UI.action("分享卡组图", func(): close_detail(); _invoke("_on_share_deck_poster", deck.id), scale)
	share.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(share)
	var edit := UI.action("编辑卡组", func(): close_detail(); _invoke("_on_edit_deck", deck.id), scale, true)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(edit)
	scroll.set_deferred("scroll_vertical", _detail_scroll)

func close_detail() -> void:
	if is_instance_valid(_detail):
		_detail.hide()
		_detail.queue_free()
	_detail = null
	_detail_id = -1
	_detail_scroll = 0


func _inspect_card(set_code: String, card_index: String) -> void:
	var card := CardDatabase.get_card(set_code, card_index)
	if card != null:
		host().call("_show_card_detail", card)


