class_name TestBattleDragScrollCoordinator
extends TestBase

const BattleDragScrollCoordinatorScript := preload("res://scripts/ui/battle/interactions/BattleDragScrollCoordinator.gd")


class HandDragHost:
	extends Control

	var _hand_scroll: ScrollContainer = null
	var _hand_drag_active := false
	var _hand_dragging := false
	var _hand_drag_start_position := Vector2.ZERO
	var _hand_drag_start_scroll := 0
	var _hand_drag_suppress_click_until_msec := 0
	var _hand_drag_debug_motion_count := 0
	var _card_gallery_drag_active := false
	var _card_gallery_dragging := false
	var _card_gallery_drag_active_scroll: ScrollContainer = null
	var _card_gallery_drag_start_position := Vector2.ZERO
	var _card_gallery_drag_start_scroll := 0
	var _card_gallery_drag_suppress_click_until_msec := 0
	var _card_gallery_drag_touch_active := false

	func _screen_position_to_battle_local(screen_position: Vector2) -> Vector2:
		return screen_position

	func _on_hand_scroll_input(_event: InputEvent) -> void:
		pass

	func _on_card_gallery_scroll_input(_event: InputEvent, _scroll: ScrollContainer, _source: String = "card_gallery") -> void:
		pass


func test_hand_scroll_content_gaps_pass_input_to_scroll_container() -> String:
	var fixture := _build_hand_scroll_fixture()
	var host := fixture["host"] as HandDragHost
	var hand_scroll := fixture["scroll"] as ScrollContainer
	var hand_container := fixture["row"] as HBoxContainer
	var coordinator := BattleDragScrollCoordinatorScript.new()
	coordinator.setup(host)
	coordinator.setup_hand_drag_scroll()

	var result := run_checks([
		assert_eq(hand_container.mouse_filter, Control.MOUSE_FILTER_PASS, "Hand row gaps should pass touch drags up to HandScroll instead of swallowing them"),
		assert_true(bool(hand_scroll.get_meta("hand_drag_scroll_enabled", false)), "HandScroll should keep the drag-scroll contract"),
	])
	host.free()
	return result


func test_hand_scroll_drag_still_moves_after_content_passthrough() -> String:
	var fixture := _build_hand_scroll_fixture()
	var host := fixture["host"] as HandDragHost
	var hand_scroll := fixture["scroll"] as ScrollContainer
	var coordinator := BattleDragScrollCoordinatorScript.new()
	coordinator.setup(host)
	coordinator.setup_hand_drag_scroll()
	hand_scroll.scroll_horizontal = 240
	var start_scroll := hand_scroll.scroll_horizontal

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = Vector2(220, 24)
	var press_consumed := bool(coordinator.handle_hand_drag_scroll_input(press, "test_gap"))
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(120, 24)
	var drag_consumed := bool(coordinator.handle_hand_drag_scroll_input(drag, "test_gap"))
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = Vector2(120, 24)
	var release_consumed := bool(coordinator.handle_hand_drag_scroll_input(release, "test_gap"))
	var scroll_after_drag := hand_scroll.scroll_horizontal

	var result := run_checks([
		assert_true(press_consumed, "Touch press should start hand drag capture"),
		assert_true(drag_consumed, "Touch drag past threshold should be consumed"),
		assert_true(release_consumed, "Touch release after drag should be consumed"),
		assert_true(scroll_after_drag > start_scroll, "Dragging left should move toward later hand cards"),
		assert_false(host._hand_drag_active, "Hand drag capture should end on release"),
	])
	host.free()
	return result


func test_hand_scroll_late_starts_from_screen_drag_when_press_was_swallowed() -> String:
	var fixture := _build_hand_scroll_fixture()
	var host := fixture["host"] as HandDragHost
	var hand_scroll := fixture["scroll"] as ScrollContainer
	var coordinator := BattleDragScrollCoordinatorScript.new()
	coordinator.setup(host)
	coordinator.setup_hand_drag_scroll()
	hand_scroll.scroll_horizontal = 240
	var start_scroll := hand_scroll.scroll_horizontal

	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(120, 24)
	drag.relative = Vector2(-100, 0)
	var drag_consumed := bool(coordinator.handle_hand_drag_scroll_input(drag, "late_screen_drag"))
	var scroll_after_drag := hand_scroll.scroll_horizontal
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = Vector2(120, 24)
	var release_consumed := bool(coordinator.handle_hand_drag_scroll_input(release, "late_screen_drag"))

	var result := run_checks([
		assert_true(drag_consumed, "A hand-area ScreenDrag should recover drag scrolling even when Android/GUI swallowed the initial press"),
		assert_true(scroll_after_drag > start_scroll, "Recovered drag should move toward later hand cards"),
		assert_true(release_consumed, "Recovered drag release should be consumed like a normal hand drag"),
		assert_false(host._hand_drag_active, "Recovered hand drag capture should end on release"),
	])
	host.free()
	return result


func test_card_gallery_late_starts_from_screen_drag_when_press_was_swallowed() -> String:
	var fixture := _build_hand_scroll_fixture()
	var host := fixture["host"] as HandDragHost
	var gallery_scroll := fixture["scroll"] as ScrollContainer
	var gallery_row := fixture["row"] as HBoxContainer
	var coordinator := BattleDragScrollCoordinatorScript.new()
	coordinator.setup(host)
	coordinator.configure_card_gallery_drag_scroll(gallery_scroll, gallery_row, "dialog_cards")
	coordinator.set_card_gallery_drag_scroll_active(gallery_scroll, true)
	_prepare_scroll_range(gallery_scroll)
	gallery_scroll.scroll_horizontal = 240
	var start_scroll := gallery_scroll.scroll_horizontal

	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(120, 24)
	drag.relative = Vector2(-100, 0)
	var drag_consumed := bool(coordinator.handle_card_gallery_drag_scroll_input(drag, gallery_scroll, "dialog_cards"))
	var scroll_after_drag := gallery_scroll.scroll_horizontal
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = Vector2(120, 24)
	var release_consumed := bool(coordinator.handle_card_gallery_drag_scroll_input(release, gallery_scroll, "dialog_cards"))

	var result := run_checks([
		assert_true(drag_consumed, "A card-gallery ScreenDrag should recover drag scrolling even when Android/GUI swallowed the initial press"),
		assert_true(scroll_after_drag > start_scroll, "Recovered card-gallery drag should move toward later cards"),
		assert_true(release_consumed, "Recovered card-gallery release should be consumed like a normal gallery drag"),
		assert_false(host._card_gallery_drag_active, "Recovered card-gallery drag capture should end on release"),
	])
	host.free()
	return result


func _build_hand_scroll_fixture() -> Dictionary:
	var host := HandDragHost.new()
	host.size = Vector2(480, 220)
	var hand_scroll := ScrollContainer.new()
	hand_scroll.name = "HandScroll"
	hand_scroll.size = Vector2(400, 180)
	hand_scroll.custom_minimum_size = Vector2(400, 180)
	var hand_container := HBoxContainer.new()
	hand_container.name = "HandContainer"
	hand_container.size = Vector2(1600, 180)
	hand_container.custom_minimum_size = Vector2(1600, 180)
	hand_container.add_theme_constant_override("separation", 18)
	for index: int in 12:
		var card_probe := Control.new()
		card_probe.name = "CardProbe%d" % index
		card_probe.custom_minimum_size = Vector2(116, 164)
		hand_container.add_child(card_probe)
	hand_scroll.add_child(hand_container)
	host.add_child(hand_scroll)
	host._hand_scroll = hand_scroll
	return {
		"host": host,
		"scroll": hand_scroll,
		"row": hand_container,
	}


func _prepare_scroll_range(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	var hbar := scroll.get_h_scroll_bar()
	if hbar == null:
		return
	hbar.min_value = 0.0
	hbar.max_value = 1600.0
	hbar.page = 400.0
