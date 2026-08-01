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
	var ios_web_hand_touch_profile := false

	func _screen_position_to_battle_local(screen_position: Vector2) -> Vector2:
		return screen_position

	func _uses_ios_web_hand_touch_profile() -> bool:
		return ios_web_hand_touch_profile

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


func test_ios_web_hand_scroll_ignores_finger_jitter_but_keeps_intentional_drag() -> String:
	var fixture := _build_hand_scroll_fixture()
	var host := fixture["host"] as HandDragHost
	var hand_scroll := fixture["scroll"] as ScrollContainer
	var coordinator := BattleDragScrollCoordinatorScript.new()
	host.ios_web_hand_touch_profile = true
	coordinator.setup(host)
	coordinator.setup_hand_drag_scroll()
	_prepare_scroll_range(hand_scroll)
	hand_scroll.scroll_horizontal = 240
	var start_scroll := hand_scroll.scroll_horizontal

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = Vector2(220, 40)
	coordinator.handle_hand_drag_scroll_input(press, "ios_web_jitter")

	var jitter := InputEventScreenDrag.new()
	jitter.index = 0
	jitter.position = Vector2(196, 48)
	jitter.relative = Vector2(-24, 8)
	var jitter_consumed := bool(coordinator.handle_hand_drag_scroll_input(jitter, "ios_web_jitter"))
	var scroll_after_jitter := hand_scroll.scroll_horizontal

	var intentional_drag := InputEventScreenDrag.new()
	intentional_drag.index = 0
	intentional_drag.position = Vector2(150, 48)
	intentional_drag.relative = Vector2(-46, 0)
	var drag_consumed := bool(coordinator.handle_hand_drag_scroll_input(intentional_drag, "ios_web_jitter"))
	var scroll_after_drag := hand_scroll.scroll_horizontal

	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = Vector2(150, 48)
	var release_consumed := bool(coordinator.handle_hand_drag_scroll_input(release, "ios_web_jitter"))

	var result := run_checks([
		assert_false(jitter_consumed, "Small iPhone Web finger jitter should not start hand scrolling"),
		assert_eq(scroll_after_jitter, start_scroll, "Finger jitter should not move the hand row or suppress its card tap"),
		assert_true(drag_consumed, "A deliberate iPhone Web horizontal swipe should still scroll the hand row"),
		assert_true(scroll_after_drag > scroll_after_jitter, "The deliberate swipe should move toward later hand cards"),
		assert_true(release_consumed, "The release after a deliberate swipe should remain owned by the hand scroller"),
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


func test_windows_attach_energy_extent_refresh_keeps_short_hand_centered() -> String:
	var host := HandDragHost.new()
	host.size = Vector2(1280, 720)
	var hand_scroll := ScrollContainer.new()
	hand_scroll.name = "HandScroll"
	hand_scroll.size = Vector2(900, 182)
	hand_scroll.custom_minimum_size = Vector2(900, 182)
	var hand_container := HBoxContainer.new()
	hand_container.name = "HandContainer"
	hand_container.size = Vector2(900, 182)
	hand_container.custom_minimum_size = Vector2(900, 182)
	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_container.add_theme_constant_override("separation", 18)
	for index: int in 2:
		var card_probe := Control.new()
		card_probe.name = "RemainingCard%d" % index
		card_probe.custom_minimum_size = Vector2(130, 182)
		hand_container.add_child(card_probe)
	hand_scroll.add_child(hand_container)
	host.add_child(hand_scroll)
	host._hand_scroll = hand_scroll
	var coordinator := BattleDragScrollCoordinatorScript.new()
	coordinator.setup(host)

	# Attaching an Energy changes the semantic hand generation. Its deferred
	# pointer-surface commit recalculates the scroll range after the display
	# controller has already restored this explicit centered rail.
	coordinator.refresh_hand_drag_scroll_extents(hand_scroll)

	var result := run_checks([
		assert_eq(
			hand_container.custom_minimum_size.x,
			900.0,
			"The deferred extent refresh after an Energy leaves hand must preserve the Windows centered rail"
		),
		assert_eq(
			hand_container.alignment,
			BoxContainer.ALIGNMENT_CENTER,
			"Scroll-range maintenance must not change the landscape hand alignment contract"
		),
		assert_eq(
			hand_scroll.scroll_horizontal,
			0,
			"A short centered Windows hand must remain at the non-scrollable origin"
		),
	])
	host.free()
	return result


func test_portrait_short_hand_extent_refresh_remains_content_sized() -> String:
	var host := HandDragHost.new()
	var hand_scroll := ScrollContainer.new()
	hand_scroll.name = "HandScroll"
	hand_scroll.size = Vector2(390, 182)
	hand_scroll.custom_minimum_size = Vector2(390, 182)
	var hand_container := HBoxContainer.new()
	hand_container.name = "HandContainer"
	hand_container.size = Vector2(390, 182)
	hand_container.custom_minimum_size = Vector2(390, 182)
	hand_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	hand_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var card_probe := Control.new()
	card_probe.custom_minimum_size = Vector2(130, 182)
	hand_container.add_child(card_probe)
	hand_scroll.add_child(hand_container)
	host.add_child(hand_scroll)
	host._hand_scroll = hand_scroll
	var coordinator := BattleDragScrollCoordinatorScript.new()
	coordinator.setup(host)

	coordinator.refresh_hand_drag_scroll_extents(hand_scroll)

	var result := run_checks([
		assert_eq(
			hand_container.custom_minimum_size.x,
			0.0,
			"Portrait hand rows must still release the rail minimum so their cards remain horizontally scrollable"
		),
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


func test_card_gallery_touch_press_does_not_swallow_plain_card_tap() -> String:
	var fixture := _build_hand_scroll_fixture()
	var host := fixture["host"] as HandDragHost
	var gallery_scroll := fixture["scroll"] as ScrollContainer
	var gallery_row := fixture["row"] as HBoxContainer
	var coordinator := BattleDragScrollCoordinatorScript.new()
	coordinator.setup(host)
	coordinator.configure_card_gallery_drag_scroll(gallery_scroll, gallery_row, "dialog_cards")
	coordinator.set_card_gallery_drag_scroll_active(gallery_scroll, true)
	_prepare_scroll_range(gallery_scroll)

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = Vector2(220, 24)
	var press_consumed := bool(coordinator.handle_card_gallery_drag_scroll_input(press, gallery_scroll, "dialog_cards"))
	var active_after_press := host._card_gallery_drag_active
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = Vector2(220, 24)
	var release_consumed := bool(coordinator.handle_card_gallery_drag_scroll_input(release, gallery_scroll, "dialog_cards"))

	var result := run_checks([
		assert_false(press_consumed, "Card-gallery touch press should not swallow a plain card tap before drag threshold"),
		assert_true(active_after_press, "Touch press should still arm gallery drag recovery"),
		assert_false(release_consumed, "Plain touch release without drag should be left for the card tap handler"),
		assert_false(host._card_gallery_drag_active, "Plain touch release should clear the armed gallery drag state"),
		assert_false(host._card_gallery_dragging, "Plain touch tap should not become a gallery drag"),
		assert_eq(host._card_gallery_drag_suppress_click_until_msec, 0, "Plain touch tap should not suppress card clicks"),
	])
	host.free()
	return result


func test_card_gallery_touch_drag_starts_before_a_hold_can_become_a_click() -> String:
	var fixture := _build_hand_scroll_fixture()
	var host := fixture["host"] as HandDragHost
	var gallery_scroll := fixture["scroll"] as ScrollContainer
	var gallery_row := fixture["row"] as HBoxContainer
	var coordinator := BattleDragScrollCoordinatorScript.new()
	coordinator.setup(host)
	coordinator.configure_card_gallery_drag_scroll(gallery_scroll, gallery_row, "discard_collection")
	coordinator.set_card_gallery_drag_scroll_active(gallery_scroll, true)
	_prepare_scroll_range(gallery_scroll)
	gallery_scroll.scroll_horizontal = 240
	var start_scroll := gallery_scroll.scroll_horizontal

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = Vector2(220, 40)
	coordinator.handle_card_gallery_drag_scroll_input(press, gallery_scroll, "discard_collection")

	# A normal finger move in a browser is often delivered in several small
	# samples. Requiring a 28px jump makes the row feel stuck long enough for the
	# card's hold gesture to win.
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(204, 42)
	drag.relative = Vector2(-16, 2)
	var drag_consumed := bool(
		coordinator.handle_card_gallery_drag_scroll_input(
			drag,
			gallery_scroll,
			"discard_collection"
		)
	)
	var scroll_after_drag := gallery_scroll.scroll_horizontal

	var result := run_checks([
		assert_true(drag_consumed, "A deliberate 16px horizontal touch move should immediately own the gallery gesture"),
		assert_true(scroll_after_drag > start_scroll, "The first deliberate touch move should already move the card row"),
		assert_true(host._card_gallery_dragging, "The gallery must enter dragging state before a held card can fire"),
	])
	host.free()
	return result


func test_card_gallery_mouse_press_does_not_swallow_plain_card_click() -> String:
	var fixture := _build_hand_scroll_fixture()
	var host := fixture["host"] as HandDragHost
	var gallery_scroll := fixture["scroll"] as ScrollContainer
	var gallery_row := fixture["row"] as HBoxContainer
	var coordinator := BattleDragScrollCoordinatorScript.new()
	coordinator.setup(host)
	coordinator.configure_card_gallery_drag_scroll(gallery_scroll, gallery_row, "dialog_cards")
	coordinator.set_card_gallery_drag_scroll_active(gallery_scroll, true)
	_prepare_scroll_range(gallery_scroll)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(220, 24)
	press.global_position = Vector2(220, 24)
	var press_consumed := bool(coordinator.handle_card_gallery_drag_scroll_input(press, gallery_scroll, "dialog_cards"))
	var active_after_press := host._card_gallery_drag_active
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(220, 24)
	release.global_position = Vector2(220, 24)
	var release_consumed := bool(coordinator.handle_card_gallery_drag_scroll_input(release, gallery_scroll, "dialog_cards"))

	var result := run_checks([
		assert_false(press_consumed, "Card-gallery mouse press should not swallow a plain card click before drag threshold"),
		assert_true(active_after_press, "Mouse press should still arm gallery drag recovery"),
		assert_false(release_consumed, "Plain mouse release without drag should be left for the card click handler"),
		assert_false(host._card_gallery_drag_active, "Plain mouse release should clear the armed gallery drag state"),
		assert_false(host._card_gallery_dragging, "Plain mouse click should not become a gallery drag"),
		assert_eq(host._card_gallery_drag_suppress_click_until_msec, 0, "Plain mouse click should not suppress card clicks"),
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
