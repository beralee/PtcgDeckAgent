class_name TestDeckCenterAndroidInteraction
extends TestBase

const ManagerScene := preload("res://scenes/deck_manager/DeckManager.tscn")
const UI := preload("res://scripts/ui/decks/DeckCenterTheme.gd")
var _viewport: SubViewport
var _scene: Control

func _open(screen := Vector2i(390, 844)) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	_viewport = SubViewport.new()
	_viewport.size = screen
	tree.root.add_child(_viewport)
	_scene = ManagerScene.instantiate()
	_viewport.add_child(_scene)
	GameManager.set_scene_navigation_suppressed_for_tests(true)
	for frame: int in 8:
		await tree.process_frame
	_scene.get("_center_ui")._paused = true

func _close() -> void:
	_viewport.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	GameManager.set_scene_navigation_suppressed_for_tests(false)

func _touch(point: Vector2, pressed: bool, finger := 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	event.index = finger
	_scene._input(event)

func _drag(point: Vector2, finger := 0) -> void:
	var event := InputEventScreenDrag.new()
	event.position = point
	event.index = finger
	_scene._input(event)

func test_phone_discovery_and_library_share_one_vertical_scroll() -> String:
	await _open()
	var view: RefCounted = _scene.get("_center_ui")
	if not view.has_method("_set_page_scroll_enabled"):
		await _close()
		return "Phone discovery and library need a common scrolling page"
	view._set_page_scroll_enabled(true)
	assert_not_null(_scene.get_node_or_null("%DeckList"), "Reparenting preserves the scene's unique deck list reference")
	assert_not_null(_scene.get_node_or_null("%DeckSearchInput"), "Search remains wired after enabling page scrolling")
	for frame: int in 6:
		await (Engine.get_main_loop() as SceneTree).process_frame
	var scroll := _scene.find_child("DeckScroll", true, false) as ScrollContainer
	var discovery := _scene.find_child("DiscoveryCarousel", true, false) as Control
	var library := _scene.find_child("DeckLibrary", true, false) as Control
	assert_true(scroll.is_ancestor_of(discovery) and scroll.is_ancestor_of(library), "Both sections belong to the same page scroll")
	var initial_y := discovery.global_position.y
	var poster := discovery.find_child("RecommendationPosterFrame", true, false) as Control
	var origin := poster.get_global_rect().get_center()
	_touch(origin, true)
	_drag(origin - Vector2(0, 120))
	_touch(origin - Vector2(0, 120), false)
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_gt(scroll.scroll_vertical, 80, "Vertical dragging on discovery scrolls the entire page")
	assert_true(discovery.global_position.y < initial_y - 80, "Discovery moves up with the cards")
	assert_true(_scene.get_node_or_null("DiscoveryPosterViewer") == null, "A vertical drag must not open the poster")
	await _close()
	return ""

func test_article_wraps_long_chinese_and_unbroken_text_inside_phone_width() -> String:
	await _open()
	var recommendation: Dictionary = _scene.get("_current_recommendation").duplicate(true)
	recommendation.style_summary = "完整的中文解读必须在手机宽度内显示并且可以一直滚动阅读。".repeat(10) + "ABCDEFGHIJK".repeat(35)
	_scene.call("_on_recommendation_read_pressed", recommendation)
	for frame: int in 8:
		await (Engine.get_main_loop() as SceneTree).process_frame
	var scroll := _scene.find_child("RecommendationDetailScroll", true, false) as ScrollContainer
	var content := _scene.find_child("RecommendationDetailContent", true, false) as Control
	assert_true(content.size.x <= scroll.size.x, "Long article text must not widen the scroll content beyond the screen")
	for label: Node in content.find_children("*", "Label", true, false):
		assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "Every paragraph supports character wrapping")
		assert_eq(label.max_lines_visible, -1, "The reader never truncates paragraph lines")
		if label.text == recommendation.style_summary:
			assert_gt(label.get_line_count(), 10, "Long text wraps into readable lines")
	assert_gt(scroll.get_v_scroll_bar().max_value, scroll.get_v_scroll_bar().page, "The complete article remains scrollable")
	await _close()
	return ""

func test_portrait_recommendations_use_portrait_posters_and_separate_orientation_cache() -> String:
	await _open()
	var recommendation: Dictionary = _scene.get("_current_recommendation").duplicate(true)
	var portrait_key: String = _scene.call("_recommendation_poster_key", recommendation)
	var captured_request := recommendation.duplicate(true)
	captured_request["_poster_variant"] = "mobile_share"
	assert_eq(_scene.call("_recommendation_poster_variant"), "mobile_share", "Portrait opens a real vertical deck poster")
	_scene.call("_apply_non_battle_layout_for_tests", Vector2(844, 390), "landscape")
	var landscape_key: String = _scene.call("_recommendation_poster_key", recommendation)
	assert_true(portrait_key != landscape_key, "Rotating cannot reuse a cached poster of the wrong aspect")
	assert_eq(_scene.call("_recommendation_poster_key", captured_request), portrait_key, "An in-flight portrait request retains its original cache identity after rotation")
	await _close()
	return ""

func test_article_rebuilt_during_rotation_keeps_modal_scope_and_close_target() -> String:
	await _open(Vector2i(844, 390))
	var view: RefCounted = _scene.get("_center_ui")
	_scene.call("_on_recommendation_read_pressed", _scene.get("_current_recommendation"))
	# Multiple size notifications can rebuild the overlay before queue_free runs.
	# Its identity must not depend on Godot retaining the original node name.
	_scene.call("_apply_non_battle_layout_for_tests", Vector2(390, 844), "portrait")
	_scene.call("_apply_non_battle_layout_for_tests", Vector2(844, 390), "landscape")
	for frame: int in 8:
		await (Engine.get_main_loop() as SceneTree).process_frame
	var overlay: Control = _scene.get("_recommendation_detail_overlay")
	assert_eq(view.input_scope(), overlay, "Rotation keeps input scoped to the newly built reader")
	var close_button := overlay.find_child("RecommendationDetailCloseButton", true, false) as Button
	var point := close_button.get_global_rect().get_center()
	_touch(point, true)
	_touch(point, false)
	assert_true(_scene.get("_recommendation_detail_overlay") == null, "The new reader closes on a deliberate touch")
	await _close()
	return ""

func test_article_touch_and_release_tail_never_activate_background_edit() -> String:
	await _open()
	var old_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var edit := _scene.find_child("DeckRowEditButton", true, false) as Button
	var count := [0]
	edit.pressed.connect(func(): count[0] += 1)
	var point := edit.get_global_rect().get_center()
	_scene.call("_on_recommendation_read_pressed", _scene.get("_current_recommendation"))
	for frame: int in 4:
		await (Engine.get_main_loop() as SceneTree).process_frame
	_touch(point, true)
	_touch(point, false)
	assert_eq(count[0], 0, "Tapping article text must not find a button behind the overlay")
	_scene.call("_close_recommendation_detail_overlay")
	await (Engine.get_main_loop() as SceneTree).process_frame
	_touch(point, false)
	var echo := InputEventMouseButton.new()
	echo.device = -1
	echo.button_index = MOUSE_BUTTON_LEFT
	echo.position = point
	echo.global_position = point
	_scene._input(echo)
	assert_eq(count[0], 0, "Orphan releases and touch-generated mouse echoes cannot become new taps")
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", old_emulation)
	await _close()
	return ""

func test_dragging_from_buttons_and_cancelled_or_second_fingers_never_click() -> String:
	await _open()
	var view: RefCounted = _scene.get("_center_ui")
	view._set_page_scroll_enabled(true)
	for frame: int in 5:
		await (Engine.get_main_loop() as SceneTree).process_frame
	var read := _scene.find_child("RecommendationDetailButton", true, false) as Button
	var origin := read.get_global_rect().get_center()
	_touch(origin, true)
	_drag(origin - Vector2(0, 110))
	_touch(origin, false)
	assert_true(_scene.get("_recommendation_detail_overlay") == null, "A drag that returns to its starting button must remain a drag")
	var scroll := _scene.find_child("DeckScroll", true, false) as ScrollContainer
	assert_gt(scroll.scroll_vertical, 0, "Button surfaces also allow page dragging")
	scroll.scroll_vertical = 0
	await (Engine.get_main_loop() as SceneTree).process_frame
	origin = read.get_global_rect().get_center()
	_touch(origin, true)
	_touch(origin, true, 1)
	_touch(origin, false, 1)
	var canceled := InputEventScreenTouch.new()
	canceled.position = origin
	canceled.canceled = true
	_scene._input(canceled)
	_touch(origin, false)
	assert_true(_scene.get("_recommendation_detail_overlay") == null, "Cancelled and unowned releases cannot open the article")
	_touch(origin, true)
	_touch(origin, false)
	assert_not_null(_scene.get("_recommendation_detail_overlay"), "A fresh deliberate tap still works")
	await _close()
	return ""

func test_poster_and_card_reader_block_background_and_poster_uses_full_width() -> String:
	await _open()
	var view: RefCounted = _scene.get("_center_ui")
	var edit := _scene.find_child("DeckRowEditButton", true, false) as Button
	var count := [0]
	edit.pressed.connect(func(): count[0] += 1)
	var point := edit.get_global_rect().get_center()
	var image := Image.create(108, 192, false, Image.FORMAT_RGBA8)
	image.fill(Color.DARK_GREEN)
	var poster := _scene.find_child("RecommendationPosterPreview", true, false) as TextureRect
	poster.texture = ImageTexture.create_from_image(image)
	view._discovery._show_poster()
	for frame: int in 5:
		await (Engine.get_main_loop() as SceneTree).process_frame
	_touch(point, true)
	_touch(point, false)
	assert_eq(count[0], 0, "The poster must absorb taps above the library")
	var rendered := _scene.find_child("DiscoveryPosterImage", true, false) as TextureRect
	assert_gt(rendered.size.x, 320, "Vertical posters fill the readable phone width")
	assert_true(rendered.size.y > rendered.size.x, "The viewer retains the portrait aspect")
	_scene.find_child("DiscoveryPosterCloseButton", true, false).pressed.emit()
	await (Engine.get_main_loop() as SceneTree).process_frame
	var card: Dictionary = CardDatabase.get_all_decks()[0].cards[0]
	_scene.call("_show_card_detail", CardDatabase.get_card(card.set_code, card.card_index))
	await (Engine.get_main_loop() as SceneTree).process_frame
	_touch(point, true)
	_touch(point, false)
	assert_eq(count[0], 0, "The card reader also owns all its touches")
	await _close()
	return ""
