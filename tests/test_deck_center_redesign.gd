class_name TestDeckCenterRedesign
extends TestBase

const ManagerScene := preload("res://scenes/deck_manager/DeckManager.tscn")
const EditorScene := preload("res://scenes/deck_editor/DeckEditor.tscn")
const UI := preload("res://scripts/ui/decks/DeckCenterTheme.gd")
const CardReader := preload("res://scripts/ui/decks/DeckCardDetails.gd")

func test_page_scroll_reparent_preserves_named_deck_controls() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = ManagerScene.instantiate()
	tree.root.add_child(scene)
	for frame: int in 4:
		await tree.process_frame
	var names := ["DeckList", "DeckSearchInput", "DeckSearchClearButton", "EmptyLabel"]
	var controls: Array[Node] = []
	for control_name: String in names:
		controls.append(scene.get_node("%" + control_name))
	var view: RefCounted = scene.get("_center_ui")
	view._set_page_scroll_enabled(true)
	for index: int in names.size():
		assert_eq(scene.get_node_or_null("%" + names[index]), controls[index], "Page scrolling must retain %" + names[index] + " for rendering and search")
	for frame: int in 4:
		await tree.process_frame
	var page_scroll := scene.find_child("DeckScroll", true, false) as ScrollContainer
	page_scroll.scroll_vertical = 200
	var search_scroll := page_scroll.scroll_vertical
	assert_gt(search_scroll, 0, "The mobile fixture must scroll past the discovery section")
	scene.call("_on_local_deck_search_changed", "")
	assert_eq(page_scroll.scroll_vertical, search_scroll, "Editing or clearing search must not move its row out of view")
	view._set_page_scroll_enabled(false)
	for index: int in names.size():
		assert_eq(scene.get_node_or_null("%" + names[index]), controls[index], "Returning to the desktop layout must retain %" + names[index])
	scene.queue_free()
	await tree.process_frame
	return ""

func test_desktop_scrollbar_pages_and_drags_without_a_wheel() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	tree.root.add_child(viewport)
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(420, 300)
	viewport.add_child(scroll)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(300, 1800)
	scroll.add_child(content)
	UI.scroll(scroll)
	for frame: int in 4:
		await tree.process_frame
	var bar := scroll.get_v_scroll_bar()
	assert_true(bar.is_visible_in_tree(), "Desktop users need a visible scrollbar when content overflows")
	assert_gte(bar.size.x, 18.0, "The scrollbar must be wide enough to grab")
	assert_gte(bar.get_theme_stylebox("grabber").get_minimum_size().y, 48.0, "Large libraries must retain a usable thumb length")
	var track_point := bar.get_global_rect().position + Vector2(bar.size.x / 2, bar.size.y * 0.8)
	_mouse_button(viewport, track_point, true)
	_mouse_button(viewport, track_point, false)
	assert_gt(scroll.scroll_vertical, 0, "Clicking the track must page through content without a wheel")
	scroll.scroll_vertical = 0
	var thumb_point := bar.get_global_rect().position + Vector2(bar.size.x / 2, 25)
	_mouse_button(viewport, thumb_point, true)
	var motion := InputEventMouseMotion.new()
	motion.position = thumb_point + Vector2(0, 150)
	motion.global_position = motion.position
	motion.relative = Vector2(0, 150)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(motion, true)
	_mouse_button(viewport, motion.position, false)
	assert_gt(scroll.scroll_vertical, 300, "Dragging the thumb must reach content beyond the first page")
	viewport.queue_free()
	await tree.process_frame
	return ""

func test_desktop_center_and_readers_expose_scrollbars_in_wide_and_narrow_windows() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	for screen: Vector2i in [Vector2i(1360, 860), Vector2i(900, 600), Vector2i(390, 844)]:
		var viewport := SubViewport.new()
		viewport.size = screen
		tree.root.add_child(viewport)
		var scene: Control = ManagerScene.instantiate()
		viewport.add_child(scene)
		for frame: int in 4:
			await tree.process_frame
		_check_desktop_scroll(scene.find_child("DeckScroll", true, false), str(screen) + " library")
		scene.call("_on_view_deck", CardDatabase.get_all_decks()[0])
		for frame: int in 4:
			await tree.process_frame
		_check_desktop_scroll(scene.find_child("CenterDetailScroll", true, false), str(screen) + " deck details")
		scene.get("_center_ui").close_detail()
		var entry: Dictionary = CardDatabase.get_all_decks()[0].cards[0]
		var card: CardData = CardDatabase.get_card(entry.set_code, entry.card_index).duplicate(true)
		card.description = "长卡牌规则，需要滚动后才能读完。\n".repeat(100)
		CardReader.show_card(scene, card)
		for frame: int in 4:
			await tree.process_frame
		_check_desktop_scroll(scene.find_child("CardReaderScroll", true, false), str(screen) + " card reader")
		scene.find_child("DeckWorkspaceCardReader", true, false).queue_free()
		await tree.process_frame
		scene.call("_on_import_pressed")
		scene.call("_on_import_completed", DeckData.from_dict(CardDatabase.get_all_decks()[0].to_dict().duplicate(true)), PackedStringArray())
		for frame: int in 4:
			await tree.process_frame
		_check_desktop_scroll(scene.find_child("ImportScroll", true, false), str(screen) + " import")
		_check_desktop_scroll(scene.find_child("ImportPreviewCards", true, false), str(screen) + " import preview")
		viewport.queue_free()
		await tree.process_frame
	return ""

func _check_desktop_scroll(scroll: ScrollContainer, context: String) -> void:
	assert_not_null(scroll, context)
	if scroll == null:
		return
	var bar := scroll.get_v_scroll_bar()
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_STOP, context + " scrollbar must receive mouse input")
	assert_false(bool(scroll.get_meta("_non_battle_hidden_vertical_drag_scroll", false)), context + " must not force touch-only scrolling")
	if bar.max_value > bar.page:
		assert_true(bar.is_visible_in_tree(), context + " overflowing content must have a visible scrollbar")

func _mouse_button(viewport: SubViewport, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	viewport.push_input(event, true)

func test_scroll_keyboard_navigation_preserves_text_editing_and_nested_scrolls() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	tree.root.add_child(viewport)
	var outer := ScrollContainer.new()
	outer.size = Vector2(500, 400)
	viewport.add_child(outer)
	UI.scroll(outer)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(420, 1800)
	outer.add_child(content)
	var input := LineEdit.new()
	input.text = "editing this name"
	content.add_child(input)
	var inner := ScrollContainer.new()
	inner.custom_minimum_size = Vector2(400, 200)
	content.add_child(inner)
	UI.scroll(inner)
	var inner_content := Control.new()
	inner_content.custom_minimum_size = Vector2(350, 1200)
	inner.add_child(inner_content)
	for frame: int in 4:
		await tree.process_frame
	inner.grab_focus()
	_key(viewport, KEY_PAGEDOWN)
	assert_gt(inner.scroll_vertical, 0, "Page Down scrolls the focused nested preview")
	assert_eq(outer.scroll_vertical, 0, "Nested paging must not also move the containing form")
	_key(viewport, KEY_END)
	assert_eq(inner.scroll_vertical, roundi(inner.get_v_scroll_bar().max_value - inner.get_v_scroll_bar().page), "End reaches the last content")
	_key(viewport, KEY_PAGEUP)
	assert_true(inner.scroll_vertical < roundi(inner.get_v_scroll_bar().max_value - inner.get_v_scroll_bar().page), "Page Up returns toward earlier content")
	_key(viewport, KEY_HOME)
	assert_eq(inner.scroll_vertical, 0, "Home reaches the start")
	outer.get_v_scroll_bar().grab_focus()
	_key(viewport, KEY_PAGEDOWN)
	assert_gt(outer.scroll_vertical, 0, "The scrollbar itself also supports keyboard paging")
	outer.scroll_vertical = 0
	input.grab_focus()
	input.caret_column = 5
	_key(viewport, KEY_END)
	assert_eq(input.caret_column, input.text.length(), "End keeps its normal text-editing meaning")
	assert_eq(outer.scroll_vertical, 0, "Editing navigation must not scroll the form")
	viewport.queue_free()
	await tree.process_frame
	return ""

func test_scroll_profile_restores_mouse_access_and_hides_unneeded_bars() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	tree.root.add_child(viewport)
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(420, 300)
	viewport.add_child(scroll)
	var content := Control.new()
	content.custom_minimum_size = Vector2(300, 1800)
	scroll.add_child(content)
	UI.scroll(scroll, "touch")
	for frame: int in 4:
		await tree.process_frame
	var bar := scroll.get_v_scroll_bar()
	assert_false(bar.visible, "Mobile relayout must not reveal the hidden scrollbar again")
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Touch-only surfaces retain the hidden bar policy")
	assert_true(bool(scroll.get_meta("_non_battle_hidden_vertical_drag_scroll", false)), "Mobile content remains marked for surface dragging")
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = Vector2(180, 240)
	UI.Touch.handle_root_touch(scroll, press)
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(180, 100)
	UI.Touch.handle_root_touch(scroll, drag)
	var release := InputEventScreenTouch.new()
	release.position = drag.position
	UI.Touch.handle_root_touch(scroll, release)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	assert_gt(scroll.scroll_vertical, 0, "Mobile users can still drag the content without mouse emulation")
	UI.scroll(scroll, "desktop")
	UI.scroll(scroll, "desktop")
	for frame: int in 4:
		await tree.process_frame
	_check_desktop_scroll(scroll, "Restored desktop profile")
	assert_eq(scroll.gui_input.get_connections().size(), 1, "Relayout must not duplicate keyboard input handlers")
	content.custom_minimum_size.y = 100
	for frame: int in 4:
		await tree.process_frame
	assert_false(bar.visible, "A short list must not show a useless scrollbar")
	assert_eq(scroll.scroll_vertical, 0, "Shrinking content clamps the old scroll offset")
	viewport.queue_free()
	await tree.process_frame
	return ""

func _key(viewport: SubViewport, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	viewport.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event, true)

func test_discovery_actions_stay_inside_visible_bounds_after_long_slide_transition() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var failures: Array[String] = []
	for screen: Vector2i in [Vector2i(1360, 860), Vector2i(900, 600), Vector2i(390, 844), Vector2i(844, 390)]:
		var viewport := SubViewport.new()
		viewport.size = screen
		tree.root.add_child(viewport)
		var scene: Control = ManagerScene.instantiate()
		viewport.add_child(scene)
		for frame: int in 6:
			await tree.process_frame
		var carousel := scene.find_child("DiscoveryCarousel", true, false)
		var recommendation: Dictionary = scene.get("_current_recommendation").duplicate(true)
		recommendation.id = "long-discovery-layout-probe"
		recommendation.deck_name = "超长推荐标题：古鼎鹿与轰鸣月的完整卡组与比赛对局解读"
		recommendation.style_summary = "包含完整卡组、关键卡牌、展开路线和不同对局的应对方法。".repeat(8)
		carousel.call("show_recommendation", recommendation, 1)
		await tree.create_timer(0.6).timeout
		for frame: int in 3:
			await tree.process_frame
		for button: Node in carousel.find_children("*", "BaseButton", true, false):
			if not button.is_visible_in_tree():
				continue
			var rect: Rect2 = button.get_global_rect()
			if not carousel.get_global_rect().grow(1).encloses(rect) or not Rect2(Vector2.ZERO, Vector2(screen)).grow(1).encloses(rect):
				failures.append("%s: %s must fit the discovery panel and screen: %s" % [screen, button.name, rect])
			var ancestor: Node = button.get_parent()
			while ancestor != viewport:
				if ancestor is Control and ancestor.clip_contents and not ancestor.get_global_rect().grow(1).encloses(rect):
					failures.append("%s: %s is clipped by %s: %s outside %s" % [screen, button.name, ancestor.name, rect, ancestor.get_global_rect()])
				ancestor = ancestor.get_parent()
		viewport.queue_free()
		await tree.process_frame
	return "\n".join(failures)

func test_windows_library_uses_full_width_and_opens_complete_deck_from_card() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1360, 860)
	tree.root.add_child(viewport)
	var scene: Control = ManagerScene.instantiate()
	viewport.add_child(scene)
	for i: int in 4:
		await tree.process_frame
	var preview := scene.find_child("DeckSelectionPreview", true, false) as Control
	var library := scene.find_child("DeckLibrary", true, false) as Control
	var info := scene.find_child("DeckRowInfoButton", true, false) as Button
	var view: RefCounted = scene.get("_center_ui")
	view._select(CardDatabase.get_all_decks()[0].id)
	var result := run_checks([
		assert_true(preview == null or not preview.visible, "Windows must remove the sidebar preview"),
		assert_true(library.size.x >= 1280, "The deck grid must reclaim the sidebar width"),
		assert_not_null(info, "The card information area is a direct full-deck action"),
		assert_not_null(scene.find_child("DeckCenterDetail", true, false), "Selecting a card opens the complete deck immediately"),
	])
	viewport.queue_free()
	await tree.process_frame
	return result

func test_discovery_keeps_poster_and_animates_two_slides_in_opposite_directions() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = ManagerScene.instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var carousel := scene.find_child("DiscoveryCarousel", true, false)
	if carousel == null or not carousel.has_method("is_transitioning"):
		scene.queue_free()
		return "Discovery must expose a persistent animated poster carousel"
	var view: RefCounted = scene.get("_center_ui")
	view._advance(1)
	await tree.process_frame
	var stage := carousel.find_child("DiscoverySlideStage", true, false) as Control
	var moving := bool(carousel.call("is_transitioning"))
	var count := stage.get_child_count()
	await tree.create_timer(0.65).timeout
	var recommendation: Dictionary = scene.get("_current_recommendation")
	var key: String = scene.call("_recommendation_poster_key", recommendation)
	var image := Image.create(16, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color.DARK_GREEN)
	var texture := ImageTexture.create_from_image(image)
	scene.call("_store_recommendation_poster_cache", key, null, image, texture, recommendation)
	scene.call("_apply_recommendation_poster_to_visible_card", key)
	var poster := carousel.find_child("RecommendationPosterPreview", true, false) as TextureRect
	var result := run_checks([
		assert_true(moving and count == 2, "Old and new slides coexist during a real transition"),
		assert_eq(stage.get_child_count(), 1, "The outgoing slide is disposed after the animation"),
		assert_true(stage.clip_contents, "Sliding content cannot cover adjacent UI"),
		assert_not_null(carousel.find_child("RecommendationPosterPreview", true, false), "Every slide retains the full deck poster"),
		assert_eq(poster.texture, texture, "The original poster cache updates the visible slide"),
	])
	scene.queue_free()
	await tree.process_frame
	return result

func test_editor_returns_to_original_grid_and_replace_actions() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	GameManager.set_scene_navigation_suppressed_for_tests(true)
	GameManager.goto_deck_editor(CardDatabase.get_all_decks()[0].id)
	var editor: Control = EditorScene.instantiate()
	tree.root.add_child(editor)
	await tree.process_frame
	var result := run_checks([
		assert_true(editor.get_node("%DeckGrid").is_visible_in_tree(), "The original deck grid is visible"),
		assert_true(editor.get_node("%BtnReplace").is_visible_in_tree(), "The original replacement action is retained"),
		assert_false(editor.has_method("_change_card_quantity"), "The new quantity editor is removed"),
	])
	editor.queue_free()
	await tree.process_frame
	GameManager.set_scene_navigation_suppressed_for_tests(false)
	return result

func test_card_reader_keeps_all_abilities_attack_costs_and_defensive_stats() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var host := Control.new()
	host.size = Vector2(390, 844)
	tree.root.add_child(host)
	var entry: Dictionary = CardDatabase.get_all_decks()[0].cards[0]
	var card: CardData = CardDatabase.get_card(entry.set_code, entry.card_index).duplicate(true)
	card.card_type = "Pokemon"
	card.abilities = [{"name": "第一特性", "text": "第一段规则"}, {"name": "第二特性", "text": "第二段规则"}]
	card.attacks = [{"name": "测试招式", "cost": "F C", "damage": "120", "text": "招式规则"}]
	card.weakness_energy = "W"
	card.weakness_value = "×2"
	card.retreat_cost = 2
	CardReader.show_card(host, card)
	await tree.process_frame
	var paragraphs := ""
	for label: Node in host.find_children("*", "Label", true, false):
		paragraphs += str(label.text) + "\n"
	var result := run_checks([
		assert_true(paragraphs.contains("第一段规则") and paragraphs.contains("第二段规则"), "Every ability must remain readable"),
		assert_true(paragraphs.contains("F C") and paragraphs.contains("120") and paragraphs.contains("招式规则"), "Attack cost, damage and rules must remain visible"),
		assert_true(paragraphs.contains("弱点") and paragraphs.contains("撤退 2"), "Defensive stats must remain available"),
	])
	host.queue_free()
	await tree.process_frame
	return result

func test_open_starter_form_reflows_after_rotation_without_losing_input() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(390, 844)
	tree.root.add_child(viewport)
	var scene: Control = ManagerScene.instantiate()
	viewport.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	scene.call("_on_new_deck_pressed")
	var input := scene.find_child("StarterDeckNameInput", true, false) as LineEdit
	input.text = "旋转后保留的卡组名称"
	viewport.size = Vector2i(844, 390)
	for i: int in 8:
		await tree.process_frame
	var panel := scene.find_child("DeckActionHudPanel", true, false) as Control
	var generate := scene.find_child("StarterDeckCreateButton", true, false) as Button
	var result := run_checks([
		assert_eq(input.text, "旋转后保留的卡组名称", "An open form preserves its input after rotation"),
		assert_true(panel.size.y <= 390.0, "The rotated dialog must fit the available height"),
		assert_gte(generate.size.y, 48.0, "The rotated footer remains touch-sized"),
		assert_true(generate.get_global_rect().end.y <= 390.0, "The footer remains inside the rotated screen"),
	])
	viewport.queue_free()
	await tree.process_frame
	return result

func test_center_exposes_responsive_presentation_and_touch_actions() -> String:
	var scene := ManagerScene.instantiate()
	var supported := scene.has_method("_center_layout_profile")
	var result := assert_true(supported, "The deck center must own a responsive presentation profile")
	scene.free()
	return result

func test_scaled_phone_targets_and_short_landscape_profile() -> String:
	var phone := UI.profile(Vector2(900, 1947), Vector2(390, 844))
	var landscape := UI.profile(Vector2(1947, 900), Vector2(844, 390))
	return run_checks([
		assert_true(phone.portrait and phone.columns == 1, "Portrait uses one column"),
		assert_gte(float(phone.button) * 390.0 / 900.0, 47.99, "Portrait hit targets must remain 48 physical pixels after canvas scaling"),
		assert_true(landscape.compact and not landscape.sidebar, "Short landscape must keep the usable library area"),
	])

func test_actual_center_keeps_discovery_above_library_and_large_more_button() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = ManagerScene.instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	scene.call("_refresh_deck_list")
	await tree.process_frame
	var section := scene.find_child("RecommendationSection", true, false)
	var library := scene.find_child("DeckWorkspace", true, false)
	var more := scene.find_child("DeckRowMoreButton", true, false) as Button
	var result := run_checks([
		assert_true(section != null and section.get_parent() == library.get_parent() and section.get_index() < library.get_index(), "Discovery belongs above the library on the first screen"),
		assert_true(more != null and more.text == "更多操作" and more.custom_minimum_size.y >= 48, "Portrait has a labelled touch-sized More action"),
		assert_not_null(scene.find_child("DiscoveryPauseButton", true, false), "Automatic recommendations can be paused"),
	])
	scene.queue_free()
	await tree.process_frame
	return result

func test_import_preview_requires_confirmation_before_persistence() -> String:
	const ID := 919806
	CardDatabase.delete_deck(ID)
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = ManagerScene.instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	var imported := DeckData.from_dict(CardDatabase.get_all_decks()[0].to_dict().duplicate(true))
	imported.id = ID
	imported.deck_name = "Confirmed Import UI Probe"
	scene.call("_on_import_pressed")
	scene.call("_on_import_completed", imported, PackedStringArray())
	var absent_before := not CardDatabase.has_deck(ID)
	var preview: RefCounted = scene.get("_import_panel_ui")
	var preview_state: String = preview.state
	preview.confirm_preview()
	var result := run_checks([
		assert_true(absent_before, "Reading a deck must not persist it before the player reviews the list"),
		assert_eq(preview_state, "preview", "The reader shows the confirmation step"),
		assert_true(CardDatabase.has_deck(ID), "Confirming the review persists the deck"),
		assert_eq(preview.state, "success", "Successful persistence is reflected explicitly"),
	])
	scene.queue_free()
	await tree.process_frame
	CardDatabase.delete_deck(ID)
	return result

func test_carousel_uses_cached_articles_and_pauses_during_work() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = ManagerScene.instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	var view: RefCounted = scene.get("_center_ui")
	var before: String = scene.get("_current_recommendation").get("id", "")
	view._advance(1)
	var after: String = scene.get("_current_recommendation").get("id", "")
	var fetch_before: bool = scene.get("_recommendation_fetch_in_progress")
	scene.set("_current_operation", "import")
	view._advance(1)
	var result := run_checks([
		assert_true(before != after, "The cached recommendation can be changed without a server request"),
		assert_eq(scene.get("_current_recommendation").get("id", ""), after, "Busy import work pauses recommendation switching"),
		assert_eq(scene.get("_recommendation_fetch_in_progress"), fetch_before, "Local carousel navigation does not launch network work"),
	])
	scene.set("_current_operation", "")
	scene.queue_free()
	await tree.process_frame
	return result
