class_name BattleDragScrollCoordinator
extends RefCounted

const HAND_DRAG_SCROLL_THRESHOLD := 12.0
const CARD_GALLERY_TOUCH_DRAG_SCROLL_THRESHOLD := 28.0
const HAND_DRAG_SCROLL_WHEEL_STEP := 96
const HAND_DRAG_CLICK_SUPPRESS_MSEC := 220
const HAND_DRAG_SCROLL_SENSITIVITY := 1.0
const DEBUG_HAND_DRAG_SCROLL := false
const DEBUG_HAND_DRAG_SCROLL_ENV := "PTCG_DEBUG_HAND_DRAG_SCROLL"
const DEBUG_HAND_DRAG_SCROLL_PROJECT_SETTING := "ptcg/debug/hand_drag_scroll"
const HAND_DRAG_DEBUG_LOG_PATH := "user://logs/hand_drag_debug.log"

var _scene: Node = null


func setup(scene: Node) -> void:
	_scene = scene


func setup_hand_drag_scroll() -> void:
	var hand_scroll := _hand_scroll()
	configure_hand_drag_scroll(hand_scroll)
	if hand_scroll == null:
		return
	var input_callable := Callable(_scene, "_on_hand_scroll_input")
	if not hand_scroll.gui_input.is_connected(input_callable):
		hand_scroll.gui_input.connect(input_callable)
	call_deferred("hide_hand_scrollbar")


func configure_hand_drag_scroll(hand_scroll: ScrollContainer) -> void:
	if hand_scroll == null:
		return
	hand_scroll.clip_contents = true
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	hand_scroll.set_meta("hand_drag_scroll_enabled", true)
	refresh_hand_drag_scroll_extents(hand_scroll)
	hide_hand_scrollbar_for(hand_scroll)


func hide_hand_scrollbar() -> void:
	hide_hand_scrollbar_for(_hand_scroll())


func hide_hand_scrollbar_for(hand_scroll: ScrollContainer) -> void:
	if hand_scroll == null:
		return
	for bar_value: Variant in [hand_scroll.get_h_scroll_bar(), hand_scroll.get_v_scroll_bar()]:
		var bar := bar_value as ScrollBar
		if bar == null:
			continue
		bar.visible = false
		bar.modulate.a = 0.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size = Vector2.ZERO
		bar.set_meta("hand_hidden_scrollbar", true)


func on_hand_scroll_input(event: InputEvent) -> void:
	debug_hand_drag_scroll_event("hand_scroll_gui", event, _hand_scroll())
	handle_hand_drag_scroll_input(event)


func handle_hand_drag_scroll_input(event: InputEvent, source: String = "external") -> bool:
	var hand_scroll := _hand_scroll()
	if hand_scroll == null:
		return false
	debug_hand_drag_scroll_event(source, event, hand_scroll)
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if _handle_hand_drag_wheel(mouse_button, hand_scroll):
			debug_hand_drag_scroll("wheel source=%s button=%d scroll=%d range=%s" % [source, mouse_button.button_index, hand_scroll.scroll_horizontal, hand_drag_scroll_range_text(hand_scroll)])
			_accept_event()
			return true
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mouse_button.pressed:
			_begin_hand_drag_scroll(hand_drag_event_position(event), hand_scroll, source)
			_accept_event()
			return true
		return _end_hand_drag_scroll(source)
	if event is InputEventMouseMotion and _as_bool(_get("_hand_drag_active"), false):
		return _update_hand_drag_scroll(hand_drag_event_position(event), hand_scroll, source)
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_hand_drag_scroll(touch.position, hand_scroll, source)
			_accept_event()
			return true
		return _end_hand_drag_scroll(source)
	if event is InputEventScreenDrag and _as_bool(_get("_hand_drag_active"), false):
		return _update_hand_drag_scroll((event as InputEventScreenDrag).position, hand_scroll, source)
	return false


func is_hand_drag_click_suppressed() -> bool:
	return Time.get_ticks_msec() < int(_get("_hand_drag_suppress_click_until_msec"))


func clear_hand_drag_click_suppression(source: String = "clear") -> void:
	_set_scene_var("_hand_drag_active", false)
	_set_scene_var("_hand_dragging", false)
	_set_scene_var("_hand_drag_suppress_click_until_msec", 0)
	debug_hand_drag_scroll("clear-suppression source=%s" % source)


func clear_transient_input_capture(source: String = "clear") -> void:
	cancel_card_gallery_drag_scroll(source)
	clear_hand_drag_click_suppression(source)
	_set_scene_var("_card_gallery_drag_active", false)
	_set_scene_var("_card_gallery_dragging", false)
	_set_scene_var("_card_gallery_drag_active_scroll", null)
	_set_scene_var("_card_gallery_drag_suppress_click_until_msec", 0)
	_set_scene_var("_card_gallery_drag_touch_active", false)
	debug_hand_drag_scroll("clear-transient-input source=%s" % source)


func configure_card_gallery_drag_scroll(scroll: ScrollContainer, row: Control = null, source: String = "card_gallery") -> void:
	if scroll == null:
		return
	scroll.clip_contents = true
	scroll.set_meta("card_gallery_drag_scroll_enabled", true)
	if not scroll.has_meta("card_gallery_drag_scroll_active"):
		scroll.set_meta("card_gallery_drag_scroll_active", false)
	if not scroll.has_meta("card_gallery_drag_keep_scrollbars_visible"):
		scroll.set_meta("card_gallery_drag_keep_scrollbars_visible", false)
	scroll.set_meta("card_gallery_drag_source", source)
	if row != null:
		row.set_meta("card_gallery_drag_row", true)
	var input_callable := Callable(_scene, "_on_card_gallery_scroll_input").bind(scroll, source)
	if not scroll.gui_input.is_connected(input_callable):
		scroll.gui_input.connect(input_callable)
	if _as_bool(scroll.get_meta("card_gallery_drag_keep_scrollbars_visible", false), false):
		_disconnect_card_gallery_scrollbar_bridge(scroll, scroll.get_h_scroll_bar())
	else:
		_connect_card_gallery_scrollbar_bridge(scroll, scroll.get_h_scroll_bar(), source)


func set_card_gallery_drag_scroll_active(scroll: ScrollContainer, active: bool) -> void:
	if scroll == null:
		return
	scroll.set_meta("card_gallery_drag_scroll_active", active)
	var keep_scrollbars_visible := _as_bool(scroll.get_meta("card_gallery_drag_keep_scrollbars_visible", false), false)
	if active:
		if keep_scrollbars_visible:
			restore_card_gallery_scrollbars_for(scroll)
			_disconnect_card_gallery_scrollbar_bridge(scroll, scroll.get_h_scroll_bar())
		elif scroll.has_meta("card_gallery_drag_source"):
			_connect_card_gallery_scrollbar_bridge(scroll, scroll.get_h_scroll_bar(), str(scroll.get_meta("card_gallery_drag_source", "card_gallery")))
			hide_card_gallery_scrollbars_for(scroll)
			call_deferred("hide_card_gallery_scrollbars_for", scroll)
	else:
		if _get("_card_gallery_drag_active_scroll") == scroll:
			_end_card_gallery_drag_scroll("deactivate")
		restore_card_gallery_scrollbars_for(scroll)


func _connect_card_gallery_scrollbar_bridge(scroll: ScrollContainer, bar: ScrollBar, source: String) -> void:
	if scroll == null or bar == null or _scene == null:
		return
	if _as_bool(scroll.get_meta("card_gallery_drag_keep_scrollbars_visible", false), false):
		_disconnect_card_gallery_scrollbar_bridge(scroll, bar)
		return
	bar.set_meta("card_gallery_drag_scrollbar_bridge", true)
	bar.set_meta("card_gallery_drag_scrollbar_bridge_source", source)
	var input_callable := Callable(_scene, "_on_card_gallery_scroll_input").bind(scroll, source)
	if not bar.gui_input.is_connected(input_callable):
		bar.gui_input.connect(input_callable)


func _disconnect_card_gallery_scrollbar_bridge(scroll: ScrollContainer, bar: ScrollBar) -> void:
	if scroll == null or bar == null or _scene == null:
		return
	var sources := {
		str(bar.get_meta("card_gallery_drag_scrollbar_bridge_source", "card_gallery")): true,
		str(scroll.get_meta("card_gallery_drag_source", "card_gallery")): true,
		"card_gallery": true,
		"dialog_cards": true,
		"discard_collection": true,
	}
	for source: String in sources.keys():
		var input_callable := Callable(_scene, "_on_card_gallery_scroll_input").bind(scroll, source)
		if bar.gui_input.is_connected(input_callable):
			bar.gui_input.disconnect(input_callable)
	bar.set_meta("card_gallery_drag_scrollbar_bridge", false)
	bar.remove_meta("card_gallery_drag_scrollbar_bridge_source")


func cancel_card_gallery_drag_scroll(source: String = "cancel") -> void:
	var active_scroll := _get("_card_gallery_drag_active_scroll") as ScrollContainer
	if active_scroll != null and is_instance_valid(active_scroll):
		set_card_gallery_drag_scroll_active(active_scroll, false)
		return
	_end_card_gallery_drag_scroll(source)


func hide_card_gallery_scrollbars_for(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	scroll.set_meta("card_gallery_scrollbar_hidden", true)
	for bar_value: Variant in [scroll.get_h_scroll_bar(), scroll.get_v_scroll_bar()]:
		var bar := bar_value as ScrollBar
		if bar == null:
			continue
		if not _as_bool(bar.get_meta("card_gallery_hidden_scrollbar", false), false):
			bar.set_meta("card_gallery_hidden_scrollbar_prev_visible", bar.visible)
			bar.set_meta("card_gallery_hidden_scrollbar_prev_modulate", bar.modulate)
			bar.set_meta("card_gallery_hidden_scrollbar_prev_mouse_filter", bar.mouse_filter)
			bar.set_meta("card_gallery_hidden_scrollbar_prev_minimum_size", bar.custom_minimum_size)
		bar.visible = false
		bar.modulate.a = 0.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size = Vector2.ZERO
		bar.set_meta("card_gallery_hidden_scrollbar", true)


func restore_card_gallery_scrollbars_for(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	scroll.set_meta("card_gallery_scrollbar_hidden", false)
	for bar_value: Variant in [scroll.get_h_scroll_bar(), scroll.get_v_scroll_bar()]:
		var bar := bar_value as ScrollBar
		if bar == null:
			continue
		_disconnect_card_gallery_scrollbar_bridge(scroll, bar)
		if not _as_bool(bar.get_meta("card_gallery_hidden_scrollbar", false), false):
			continue
		bar.visible = _as_bool(bar.get_meta("card_gallery_hidden_scrollbar_prev_visible", true), true)
		var previous_modulate: Variant = bar.get_meta("card_gallery_hidden_scrollbar_prev_modulate", Color.WHITE)
		if previous_modulate is Color:
			bar.modulate = previous_modulate
		bar.mouse_filter = int(bar.get_meta("card_gallery_hidden_scrollbar_prev_mouse_filter", Control.MOUSE_FILTER_STOP))
		var previous_minimum_size: Variant = bar.get_meta("card_gallery_hidden_scrollbar_prev_minimum_size", Vector2.ZERO)
		if previous_minimum_size is Vector2:
			bar.custom_minimum_size = previous_minimum_size
		bar.remove_meta("card_gallery_hidden_scrollbar")
		bar.remove_meta("card_gallery_hidden_scrollbar_prev_visible")
		bar.remove_meta("card_gallery_hidden_scrollbar_prev_modulate")
		bar.remove_meta("card_gallery_hidden_scrollbar_prev_mouse_filter")
		bar.remove_meta("card_gallery_hidden_scrollbar_prev_minimum_size")


func configure_card_gallery_card_view(card_view: BattleCardView, scroll: ScrollContainer, source: String = "card_gallery") -> void:
	if card_view == null or scroll == null:
		return
	card_view.set_meta("card_gallery_drag_input_enabled", true)
	var input_callable := Callable(_scene, "_on_card_gallery_card_input").bind(scroll, source)
	if not card_view.hand_drag_input.is_connected(input_callable):
		card_view.hand_drag_input.connect(input_callable)


func on_card_gallery_scroll_input(event: InputEvent, scroll: ScrollContainer, source: String = "card_gallery") -> void:
	handle_card_gallery_drag_scroll_input(event, scroll, source)


func on_card_gallery_card_input(event: InputEvent, scroll: ScrollContainer, source: String = "card_gallery") -> void:
	handle_card_gallery_drag_scroll_input(event, scroll, source)


func handle_card_gallery_drag_scroll_input(event: InputEvent, scroll: ScrollContainer, source: String = "card_gallery") -> bool:
	if scroll == null:
		_clear_invalid_card_gallery_drag_capture(source)
		return false
	if not is_instance_valid(scroll):
		_clear_invalid_card_gallery_drag_capture(source)
		return false
	if not _as_bool(scroll.get_meta("card_gallery_drag_scroll_enabled", false), false):
		if _get("_card_gallery_drag_active_scroll") == scroll:
			_clear_invalid_card_gallery_drag_capture(source, scroll)
		return false
	if not _as_bool(scroll.get_meta("card_gallery_drag_scroll_active", false), false) and _get("_card_gallery_drag_active_scroll") != scroll:
		return false
	if not _can_card_gallery_scroll_capture_input(scroll):
		_clear_invalid_card_gallery_drag_capture(source, scroll)
		return false
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if _handle_card_gallery_drag_wheel(mouse_button, scroll):
			_accept_event()
			return true
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mouse_button.pressed:
			_begin_card_gallery_drag_scroll(card_gallery_drag_event_position(event), scroll, false)
			_accept_event()
			return true
		return _end_card_gallery_drag_scroll(source)
	if event is InputEventMouseMotion and _as_bool(_get("_card_gallery_drag_active"), false) and _get("_card_gallery_drag_active_scroll") == scroll:
		return _update_card_gallery_drag_scroll(card_gallery_drag_event_position(event), scroll)
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_card_gallery_drag_scroll(card_gallery_drag_event_position(event), scroll, true)
			_accept_event()
			return true
		return _end_card_gallery_drag_scroll(source)
	if event is InputEventScreenDrag and _as_bool(_get("_card_gallery_drag_active"), false) and _get("_card_gallery_drag_active_scroll") == scroll:
		return _update_card_gallery_drag_scroll(card_gallery_drag_event_position(event), scroll)
	return false


func is_card_gallery_drag_click_suppressed() -> bool:
	return Time.get_ticks_msec() < int(_get("_card_gallery_drag_suppress_click_until_msec"))


func debug_hand_drag_scroll_event(source: String, event: InputEvent, hand_scroll: ScrollContainer) -> void:
	if not debug_hand_drag_scroll_enabled():
		return
	var should_log := false
	if event is InputEventMouseButton:
		should_log = true
	elif event is InputEventScreenTouch:
		should_log = true
	elif event is InputEventMouseMotion:
		should_log = _as_bool(_get("_hand_drag_active"), false)
	elif event is InputEventScreenDrag:
		should_log = _as_bool(_get("_hand_drag_active"), false)
	if not should_log:
		return
	debug_hand_drag_scroll("event source=%s type=%s pos=%s global=%s pressed=%s active=%s dragging=%s scroll=%d range=%s" % [
		source,
		event.get_class(),
		str(hand_drag_event_position(event)),
		str(hand_drag_event_global_position(event)),
		str(hand_drag_event_pressed_state(event)),
		str(_as_bool(_get("_hand_drag_active"), false)),
		str(_as_bool(_get("_hand_dragging"), false)),
		hand_scroll.scroll_horizontal if hand_scroll != null else -1,
		hand_drag_scroll_range_text(hand_scroll),
	], event is InputEventMouseMotion or event is InputEventScreenDrag)


func debug_hand_drag_scroll(message: String, throttle_motion: bool = false) -> void:
	if not debug_hand_drag_scroll_enabled():
		return
	var motion_count := int(_get("_hand_drag_debug_motion_count"))
	if throttle_motion and motion_count > 12 and motion_count % 6 != 0:
		return
	var line := "[hand_drag] %s" % message
	print(line)
	var file := FileAccess.open(HAND_DRAG_DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(HAND_DRAG_DEBUG_LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line("%s %s" % [Time.get_datetime_string_from_system(), line])
	file.close()


func debug_hand_drag_scroll_enabled() -> bool:
	if DEBUG_HAND_DRAG_SCROLL:
		return true
	var env_value := OS.get_environment(DEBUG_HAND_DRAG_SCROLL_ENV)
	if env_value != "" and env_value != "0" and env_value.to_lower() != "false":
		return true
	if ProjectSettings.has_setting(DEBUG_HAND_DRAG_SCROLL_PROJECT_SETTING):
		return _as_bool(ProjectSettings.get_setting(DEBUG_HAND_DRAG_SCROLL_PROJECT_SETTING), false)
	return false


func hand_drag_scroll_range_text(hand_scroll: ScrollContainer) -> String:
	if hand_scroll == null:
		return "<null>"
	var hbar := hand_scroll.get_h_scroll_bar()
	if hbar == null:
		return "<no-hbar>"
	return "value=%.1f min=%.1f max=%.1f page=%.1f" % [hbar.value, hbar.min_value, hbar.max_value, hbar.page]


func hand_drag_content_size_text(hand_scroll: ScrollContainer) -> String:
	if hand_scroll == null or hand_scroll.get_child_count() <= 0:
		return "<none>"
	var content := hand_scroll.get_child(0) as Control
	if content == null:
		return "<not-control>"
	return "size=%s min=%s combined=%s children=%d" % [str(content.size), str(content.custom_minimum_size), str(content.get_combined_minimum_size()), content.get_child_count()]


func refresh_hand_drag_scroll_extents(hand_scroll: ScrollContainer) -> void:
	if hand_scroll == null:
		return
	var content := _hand_drag_content_control(hand_scroll)
	if content == null:
		return
	var viewport_width := _hand_drag_viewport_width(hand_scroll)
	if viewport_width <= 0.0:
		return
	var content_width := _hand_drag_content_width(content)
	if content_width > viewport_width:
		content.custom_minimum_size.x = maxf(content.custom_minimum_size.x, content_width)
		if content.size.x < content_width:
			content.size.x = content_width
	var hbar := hand_scroll.get_h_scroll_bar()
	if hbar == null:
		return
	var range_width := maxf(maxf(viewport_width, content_width), maxf(content.custom_minimum_size.x, content.size.x))
	hbar.min_value = 0.0
	hbar.max_value = range_width
	hbar.page = viewport_width
	var max_scroll := maxi(0, roundi(range_width - viewport_width))
	if hand_scroll.scroll_horizontal > max_scroll:
		hand_scroll.scroll_horizontal = max_scroll


func hand_drag_event_global_position(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return (event as InputEventMouse).global_position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	return Vector2.ZERO


func hand_drag_event_pressed_state(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		return str((event as InputEventMouseButton).pressed)
	if event is InputEventScreenTouch:
		return str((event as InputEventScreenTouch).pressed)
	return "-"


func hand_drag_event_position(event: InputEvent) -> Vector2:
	var screen_position := Vector2.ZERO
	if event is InputEventMouse:
		screen_position = (event as InputEventMouse).global_position
	elif event is InputEventScreenTouch:
		screen_position = (event as InputEventScreenTouch).position
	elif event is InputEventScreenDrag:
		screen_position = (event as InputEventScreenDrag).position
	return _as_vector2(_call("_screen_position_to_battle_local", [screen_position]), screen_position)


func card_gallery_drag_event_position(event: InputEvent) -> Vector2:
	var screen_position := Vector2.ZERO
	if event is InputEventMouse:
		screen_position = (event as InputEventMouse).global_position
	elif event is InputEventScreenTouch:
		screen_position = (event as InputEventScreenTouch).position
	elif event is InputEventScreenDrag:
		screen_position = (event as InputEventScreenDrag).position
	return _as_vector2(_call("_screen_position_to_battle_local", [screen_position]), screen_position)


func _handle_hand_drag_wheel(mouse_button: InputEventMouseButton, hand_scroll: ScrollContainer) -> bool:
	if not mouse_button.pressed:
		return false
	var direction := 0
	match mouse_button.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
			direction = -1
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
			direction = 1
		_:
			return false
	refresh_hand_drag_scroll_extents(hand_scroll)
	hand_scroll.scroll_horizontal = maxi(0, hand_scroll.scroll_horizontal + direction * HAND_DRAG_SCROLL_WHEEL_STEP)
	return true


func _begin_hand_drag_scroll(position: Vector2, hand_scroll: ScrollContainer, source: String = "") -> void:
	if _as_bool(_get("_card_gallery_drag_active"), false):
		cancel_card_gallery_drag_scroll("hand_drag_start")
	refresh_hand_drag_scroll_extents(hand_scroll)
	_set_scene_var("_hand_drag_active", true)
	_set_scene_var("_hand_dragging", false)
	_set_scene_var("_hand_drag_start_position", position)
	_set_scene_var("_hand_drag_start_scroll", hand_scroll.scroll_horizontal)
	_set_scene_var("_hand_drag_debug_motion_count", 0)
	debug_hand_drag_scroll("begin source=%s pos=%s scroll=%d range=%s scroll_size=%s content=%s" % [source, str(position), int(_get("_hand_drag_start_scroll")), hand_drag_scroll_range_text(hand_scroll), str(hand_scroll.size), hand_drag_content_size_text(hand_scroll)])


func _update_hand_drag_scroll(position: Vector2, hand_scroll: ScrollContainer, source: String = "") -> bool:
	refresh_hand_drag_scroll_extents(hand_scroll)
	var start_position := _as_vector2(_get("_hand_drag_start_position"), Vector2.ZERO)
	var delta := position - start_position
	if not _as_bool(_get("_hand_dragging"), false) and absf(delta.x) < HAND_DRAG_SCROLL_THRESHOLD:
		debug_hand_drag_scroll("move-below-threshold source=%s pos=%s delta=%s scroll=%d range=%s" % [source, str(position), str(delta), hand_scroll.scroll_horizontal, hand_drag_scroll_range_text(hand_scroll)], true)
		return false
	_set_scene_var("_hand_dragging", true)
	var start_scroll := int(_get("_hand_drag_start_scroll"))
	var target_scroll := maxi(0, start_scroll - roundi(delta.x * HAND_DRAG_SCROLL_SENSITIVITY))
	var before_scroll := hand_scroll.scroll_horizontal
	hand_scroll.scroll_horizontal = target_scroll
	var motion_count := int(_get("_hand_drag_debug_motion_count")) + 1
	_set_scene_var("_hand_drag_debug_motion_count", motion_count)
	debug_hand_drag_scroll("move source=%s pos=%s delta=%s start=%d target=%d before=%d after=%d range=%s scroll_size=%s content=%s" % [source, str(position), str(delta), start_scroll, target_scroll, before_scroll, hand_scroll.scroll_horizontal, hand_drag_scroll_range_text(hand_scroll), str(hand_scroll.size), hand_drag_content_size_text(hand_scroll)], motion_count > 12 and motion_count % 6 != 0)
	_accept_event()
	return true


func _end_hand_drag_scroll(source: String = "") -> bool:
	var was_dragging := _as_bool(_get("_hand_dragging"), false)
	_set_scene_var("_hand_drag_active", false)
	_set_scene_var("_hand_dragging", false)
	var hand_scroll := _hand_scroll()
	debug_hand_drag_scroll("end source=%s was_dragging=%s scroll=%d range=%s" % [source, str(was_dragging), hand_scroll.scroll_horizontal if hand_scroll != null else -1, hand_drag_scroll_range_text(hand_scroll)])
	if was_dragging:
		_set_scene_var("_hand_drag_suppress_click_until_msec", Time.get_ticks_msec() + HAND_DRAG_CLICK_SUPPRESS_MSEC)
		_accept_event()
	return was_dragging


func _handle_card_gallery_drag_wheel(mouse_button: InputEventMouseButton, scroll: ScrollContainer) -> bool:
	if not mouse_button.pressed:
		return false
	var direction := 0
	match mouse_button.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
			direction = -1
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
			direction = 1
		_:
			return false
	scroll.scroll_horizontal = maxi(0, scroll.scroll_horizontal + direction * HAND_DRAG_SCROLL_WHEEL_STEP)
	return true


func _can_card_gallery_scroll_capture_input(scroll: ScrollContainer) -> bool:
	if scroll == null or not is_instance_valid(scroll) or not scroll.visible:
		return false
	if scroll.is_inside_tree() and not scroll.is_visible_in_tree():
		return false
	return true


func _clear_invalid_card_gallery_drag_capture(source: String = "invalid", scroll: ScrollContainer = null) -> void:
	var active_scroll := _get("_card_gallery_drag_active_scroll") as ScrollContainer
	var should_clear := _as_bool(_get("_card_gallery_drag_active"), false) or active_scroll != null
	if scroll != null and is_instance_valid(scroll):
		should_clear = should_clear or _as_bool(scroll.get_meta("card_gallery_drag_scroll_active", false), false)
		scroll.set_meta("card_gallery_drag_scroll_active", false)
		restore_card_gallery_scrollbars_for(scroll)
	if not should_clear:
		return
	_set_scene_var("_card_gallery_drag_active", false)
	_set_scene_var("_card_gallery_dragging", false)
	_set_scene_var("_card_gallery_drag_active_scroll", null)
	_set_scene_var("_card_gallery_drag_suppress_click_until_msec", 0)
	_set_scene_var("_card_gallery_drag_touch_active", false)
	debug_hand_drag_scroll("clear-invalid-card-gallery source=%s" % source)


func _begin_card_gallery_drag_scroll(position: Vector2, scroll: ScrollContainer, from_touch: bool = false) -> void:
	_set_scene_var("_card_gallery_drag_active_scroll", scroll)
	_set_scene_var("_card_gallery_drag_active", true)
	_set_scene_var("_card_gallery_dragging", false)
	_set_scene_var("_card_gallery_drag_start_position", position)
	_set_scene_var("_card_gallery_drag_start_scroll", scroll.scroll_horizontal)
	_set_scene_var("_card_gallery_drag_touch_active", from_touch)


func _update_card_gallery_drag_scroll(position: Vector2, scroll: ScrollContainer) -> bool:
	var delta := position - _as_vector2(_get("_card_gallery_drag_start_position"), Vector2.ZERO)
	var threshold := CARD_GALLERY_TOUCH_DRAG_SCROLL_THRESHOLD if _as_bool(_get("_card_gallery_drag_touch_active"), false) else HAND_DRAG_SCROLL_THRESHOLD
	if not _as_bool(_get("_card_gallery_dragging"), false) and absf(delta.x) < threshold:
		return false
	_set_scene_var("_card_gallery_dragging", true)
	scroll.scroll_horizontal = maxi(0, int(_get("_card_gallery_drag_start_scroll")) - roundi(delta.x * HAND_DRAG_SCROLL_SENSITIVITY))
	_accept_event()
	return true


func _end_card_gallery_drag_scroll(_source: String = "") -> bool:
	var was_dragging := _as_bool(_get("_card_gallery_dragging"), false)
	_set_scene_var("_card_gallery_drag_active", false)
	_set_scene_var("_card_gallery_dragging", false)
	_set_scene_var("_card_gallery_drag_active_scroll", null)
	_set_scene_var("_card_gallery_drag_touch_active", false)
	if was_dragging:
		_set_scene_var("_card_gallery_drag_suppress_click_until_msec", Time.get_ticks_msec() + HAND_DRAG_CLICK_SUPPRESS_MSEC)
		_accept_event()
	return was_dragging


func _hand_scroll() -> ScrollContainer:
	var hand_scroll := _get("_hand_scroll") as ScrollContainer
	if hand_scroll != null:
		return hand_scroll
	return _find("HandScroll", true, false) as ScrollContainer


func _hand_drag_content_control(hand_scroll: ScrollContainer) -> Control:
	if hand_scroll == null or hand_scroll.get_child_count() <= 0:
		return null
	return hand_scroll.get_child(0) as Control


func _hand_drag_viewport_width(hand_scroll: ScrollContainer) -> float:
	if hand_scroll == null:
		return 0.0
	return maxf(hand_scroll.size.x, hand_scroll.custom_minimum_size.x)


func _hand_drag_content_width(content: Control) -> float:
	if content == null:
		return 0.0
	var width := maxf(content.size.x, content.get_combined_minimum_size().x)
	var child_width := 0.0
	var visible_child_count := 0
	for child: Node in content.get_children():
		var child_control := child as Control
		if child_control == null or not child_control.visible:
			continue
		child_width += maxf(maxf(child_control.size.x, child_control.custom_minimum_size.x), child_control.get_combined_minimum_size().x)
		visible_child_count += 1
	if visible_child_count > 1:
		child_width += float((content as BoxContainer).get_theme_constant("separation") if content is BoxContainer else 0) * float(visible_child_count - 1)
	return maxf(width, child_width)


func _accept_event() -> void:
	var control := _scene as Control
	if control != null:
		control.accept_event()


func _find(pattern: String, recursive: bool, owned: bool) -> Node:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.find_child(pattern, recursive, owned)


func _get(property_name: StringName) -> Variant:
	if _scene == null or not is_instance_valid(_scene):
		return null
	return _scene.get(property_name)


func _set_scene_var(property_name: StringName, value: Variant) -> void:
	if _scene == null or not is_instance_valid(_scene):
		return
	_scene.set(property_name, value)


func _call(method_name: StringName, args: Array = []) -> Variant:
	if _scene == null or not is_instance_valid(_scene) or not _scene.has_method(method_name):
		return null
	return _scene.callv(method_name, args)


func _as_bool(value: Variant, fallback: bool = false) -> bool:
	if value == null:
		return fallback
	return bool(value)


func _as_vector2(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	return value if value is Vector2 else fallback
