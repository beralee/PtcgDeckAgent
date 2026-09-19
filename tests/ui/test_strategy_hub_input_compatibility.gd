extends TestBase
const Harness = preload("res://tests/ui/UiCompatibilityHarness.gd")
const Hub = preload("res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn")

func test_embedded_settings_drag_reaches_outer_scroll() -> String:
	var h := Harness.new()
	await h.mount(Hub, Harness.PROFILES[0])
	await h.select_workspace("settings")
	var scroll := h.scene.get_node("%AISettingsWorkspace") as ScrollContainer
	var origin := scroll.get_global_rect().position + Vector2(18, scroll.size.y * 0.7)
	await h.swipe(origin, origin - Vector2(0, 350))
	var result := assert_true(scroll.scroll_vertical > 100, "ANDROID: dragging embedded settings must scroll its outer viewport")
	await h.dispose()
	return result

func test_matrix_real_mouse_and_touch_activate_tabs_once() -> String:
	var checks: Array[String] = []
	for profile: Dictionary in Harness.PROFILES:
		var h := Harness.new()
		await h.mount(Hub, profile)
		var tab := h.scene.get_node("%LocalStrategyTab") as Button
		var count := [0]
		tab.pressed.connect(func() -> void: count[0] += 1)
		var position := tab.get_global_rect().get_center()
		if profile.touch:
			h.touch(true, position)
			h.touch(false, position)
			h.mouse_click(position, -1)
		else:
			h.mouse_click(position)
		checks.append(assert_eq(count[0], 1, profile.id + ": exactly one activation"))
		checks.append(assert_true(tab.get_global_rect().end.x <= h.viewport.size.x + 1, profile.id + ": tab bounds"))
		var heading := h.scene.find_child("Title", true, false) as Label
		checks.append(assert_eq(heading.get_line_count(), 1, profile.id + ": heading stays on one line"))
		await h.dispose()
	return run_checks(checks)

func _fixture(h: RefCounted) -> Dictionary:
	for name: String in ["CatalogWorkspace", "LocalStrategyWorkspace", "AISettingsWorkspace"]:
		h.scene.get_node("%" + name).hide()
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 500)
	scroll.size = Vector2(800, 700)
	h.scene.add_child(scroll)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(750, 1800)
	scroll.add_child(content)
	var button := Button.new()
	button.text = "测试操作"
	button.custom_minimum_size.y = 100
	content.add_child(button)
	var field := LineEdit.new()
	field.custom_minimum_size.y = 100
	field.text = "保留输入"
	field.set_meta("_non_battle_native_text_input", true)
	content.add_child(field)
	var slider := HSlider.new()
	slider.custom_minimum_size.y = 100
	slider.value = 50
	content.add_child(slider)
	return {"scroll": scroll, "button": button, "field": field, "slider": slider}

func test_drag_from_button_input_and_slider_scrolls_without_side_effects() -> String:
	var checks: Array[String] = []
	for source: String in ["button", "field", "slider"]:
		var h := Harness.new()
		await h.mount(Hub, Harness.PROFILES[0])
		var f := _fixture(h)
		await h.settle()
		var count := [0]
		f.button.pressed.connect(func() -> void: count[0] += 1)
		var origin: Vector2 = f[source].get_global_rect().get_center()
		await h.swipe(origin, origin - Vector2(0, 280))
		checks.append(assert_true(f.scroll.scroll_vertical > 100, source + ": vertical drag scrolls"))
		checks.append(assert_eq(count[0], 0, source + ": drag never clicks"))
		checks.append(assert_eq(f.slider.value, 50.0, source + ": vertical drag never adjusts a horizontal slider"))
		checks.append(assert_false(f.field.has_focus(), source + ": scrolling never opens keyboard"))
		await h.dispose()
	return run_checks(checks)

func test_cancel_multitouch_and_release_without_press_do_not_activate() -> String:
	var h := Harness.new()
	await h.mount(Hub, Harness.PROFILES[0])
	var f := _fixture(h)
	await h.settle()
	var count := [0]
	f.button.pressed.connect(func() -> void: count[0] += 1)
	var p: Vector2 = f.button.get_global_rect().get_center()
	h.touch(false, p)
	h.touch(true, p, 0)
	h.touch(true, p, 1)
	h.touch(false, p, 1)
	h.touch(false, p, 0, true)
	h.touch(false, p, 0)
	var result := assert_eq(count[0], 0, "Cancelled, foreign and orphan releases must not click")
	await h.dispose()
	return result

func test_modal_blocks_background_and_close_release_cannot_leak() -> String:
	var h := Harness.new()
	await h.mount(Hub, Harness.PROFILES[0])
	var count := [0]
	var tab := h.scene.get_node("%LocalStrategyTab") as Button
	tab.pressed.connect(func() -> void: count[0] += 1)
	h.scene.call("_open_strategy_detail")
	await h.settle()
	var p := tab.get_global_rect().get_center()
	h.touch(true, p)
	h.touch(false, p)
	h.mouse_click(p)
	h.touch(true, p)
	h.scene.call("_close_strategy_detail")
	h.touch(false, p)
	var result := assert_eq(count[0], 0, "Modal background and close-time release must be inert")
	await h.dispose()
	return result

func test_touch_toggle_and_horizontal_slider_keep_their_native_meaning() -> String:
	var h := Harness.new()
	await h.mount(Hub, Harness.PROFILES[0])
	var f := _fixture(h)
	f.button.toggle_mode = true
	await h.settle()
	var p: Vector2 = f.button.get_global_rect().get_center()
	h.touch(true, p)
	h.touch(false, p)
	var origin: Vector2 = f.slider.get_global_rect().get_center()
	await h.swipe(origin, origin + Vector2(180, 0))
	var result := run_checks([
		assert_true(f.button.button_pressed, "Touch toggles retain toggle state"),
		assert_true(f.slider.value > 50, "Horizontal slider motion changes its value"),
		assert_eq(f.scroll.scroll_vertical, 0, "Horizontal motion does not scroll the form"),
	])
	await h.dispose()
	return result

func test_strategy_hub_heading_is_centered() -> String:
	var h := Harness.new()
	await h.mount(Hub, Harness.PROFILES[0])
	var title := h.scene.find_child("Title", true, false) as Label
	var result := assert_eq(title.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	await h.dispose()
	return result

func test_focus_loss_cancels_touch_and_native_input_tap_still_focuses() -> String:
	var h := Harness.new()
	await h.mount(Hub, Harness.PROFILES[0])
	var f := _fixture(h)
	await h.settle()
	var count := [0]
	f.button.pressed.connect(func() -> void: count[0] += 1)
	var p: Vector2 = f.button.get_global_rect().get_center()
	h.touch(true, p)
	h.scene.notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	h.touch(false, p)
	var field_point: Vector2 = f.field.get_global_rect().get_center()
	h.touch(true, field_point)
	h.touch(false, field_point)
	var result := run_checks([
		assert_eq(count[0], 0, "Focus loss invalidates pending touch authority"),
		assert_true(f.field.has_focus(), "An input tap still focuses the native editor"),
		assert_eq(f.field.text, "保留输入", "Touch routing must never alter user text"),
	])
	await h.dispose()
	return result

func test_embedded_model_picker_blocks_header_and_outer_mouse_scroll() -> String:
	var h := Harness.new()
	await h.mount(Hub, Harness.PROFILES[0])
	await h.select_workspace("settings")
	var settings: Control = h.scene.get("_ai_settings_content")
	settings.call("_show_settings_model_picker")
	await h.settle()
	var picker: Control = settings.get("_model_picker_overlay")
	var tab := h.scene.get_node("%LocalStrategyTab") as Button
	var count := [0]
	tab.pressed.connect(func() -> void: count[0] += 1)
	var p := tab.get_global_rect().get_center()
	h.touch(true, p)
	h.touch(false, p)
	h.mouse_click(p)
	var scroll := h.scene.get_node("%AISettingsWorkspace") as ScrollContainer
	var before := scroll.scroll_vertical
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = picker.get_global_rect().get_center()
	h.viewport.push_input(wheel, true)
	var checks := run_checks([
		assert_true(picker.visible, "Model modal remains open"),
		assert_eq(count[0], 0, "A modal must block the header for mouse and touch"),
		assert_eq(scroll.scroll_vertical, before, "Wheel at inner scroll boundary must not move underlying settings"),
	])
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	h.viewport.push_input(escape, true)
	checks += assert_false(picker.visible, "Escape closes the modal without leaving the workspace")
	await h.dispose()
	return checks

func test_desktop_wheel_and_clipped_controls_keep_native_behavior() -> String:
	var h := Harness.new()
	await h.mount(Hub, Harness.PROFILES[3])
	var f := _fixture(h)
	await h.settle()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.position = f.scroll.get_global_rect().position + Vector2(100, 250)
	wheel.pressed = true
	h.viewport.push_input(wheel, true)
	await h.settle()
	var result := assert_true(f.scroll.scroll_vertical > 0, "Desktop wheel retains native scroll behavior")
	f.scroll.scroll_vertical = 650
	await h.settle()
	var count := [0]
	f.button.pressed.connect(func() -> void: count[0] += 1)
	var hidden_point: Vector2 = f.button.get_global_rect().get_center()
	h.touch(true, hidden_point)
	h.touch(false, hidden_point)
	result += assert_eq(count[0], 0, "Controls clipped outside a scroll viewport cannot receive touch")
	await h.dispose()
	return result
