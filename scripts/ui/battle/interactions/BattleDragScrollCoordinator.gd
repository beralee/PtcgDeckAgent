class_name BattleDragScrollCoordinator
extends RefCounted

const PointerGesturePolicyScript := preload("res://scripts/ui/input/PointerGesturePolicy.gd")
const HAND_DRAG_SCROLL_THRESHOLD := 12.0
const IOS_WEB_HAND_DRAG_SCROLL_THRESHOLD := 36.0
const HAND_DRAG_SCROLL_WHEEL_STEP := 96
const HAND_DRAG_CLICK_SUPPRESS_MSEC := 220
const HAND_DRAG_TOUCH_MOUSE_ECHO_POSITION_EPSILON := 28.0
const HAND_DRAG_SCROLL_SENSITIVITY := 1.0
const DEBUG_HAND_DRAG_SCROLL := false
const DEBUG_HAND_DRAG_SCROLL_ENV := "PTCG_DEBUG_HAND_DRAG_SCROLL"
const DEBUG_HAND_DRAG_SCROLL_PROJECT_SETTING := "ptcg/debug/hand_drag_scroll"
const HAND_DRAG_DEBUG_LOG_PATH := "user://logs/hand_drag_debug.log"

var _scene: Node = null
var _active_hand_pointer_kind: String = ""
var _card_gallery_last_touch_release_msec: int = -1
var _card_gallery_last_touch_release_position := Vector2(-1.0, -1.0)
var _card_gallery_last_touch_release_scroll_id: int = -1


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
			_begin_hand_drag_scroll(hand_drag_event_position(event), hand_scroll, source, "mouse")
			_accept_event()
			return true
		return _end_hand_drag_scroll(source, hand_drag_event_position(event), "mouse")
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _as_bool(_get("_hand_drag_active"), false):
			return _update_hand_drag_scroll(hand_drag_event_position(event), hand_scroll, source)
		return _try_late_start_hand_drag_scroll_from_motion(
			motion.global_position,
			motion.relative,
			(motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0,
			hand_scroll,
			source
		)
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_hand_drag_scroll(_screen_position_to_drag_local(touch.position), hand_scroll, source, "touch")
			_accept_event()
			return true
		return _end_hand_drag_scroll(source, _screen_position_to_drag_local(touch.position), "touch")
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _as_bool(_get("_hand_drag_active"), false):
			return _update_hand_drag_scroll(_screen_position_to_drag_local(drag.position), hand_scroll, source)
		return _try_late_start_hand_drag_scroll_from_motion(drag.position, drag.relative, true, hand_scroll, source)
	return false


func is_hand_drag_click_suppressed() -> bool:
	return Time.get_ticks_msec() < int(_get("_hand_drag_suppress_click_until_msec"))


func clear_hand_drag_click_suppression(source: String = "clear") -> void:
	_active_hand_pointer_kind = ""
	_set_scene_var("_hand_drag_active", false)
	_set_scene_var("_hand_dragging", false)
	_set_scene_var("_hand_drag_suppress_click_until_msec", 0)
	_set_scene_var("_hand_drag_suppress_origin_position", Vector2(-1.0, -1.0))
	_set_scene_var("_hand_drag_suppress_pointer_kind", "")
	debug_hand_drag_scroll("clear-suppression source=%s" % source)


func clear_transient_input_capture(source: String = "clear") -> void:
	cancel_card_gallery_drag_scroll(source)
	clear_hand_drag_click_suppression(source)
	_set_scene_var("_card_gallery_drag_active", false)
	_set_scene_var("_card_gallery_dragging", false)
	_set_scene_var("_card_gallery_drag_active_scroll", null)
	_set_scene_var("_card_gallery_drag_touch_active", false)
	_clear_card_gallery_touch_mouse_echo()
	debug_hand_drag_scroll("clear-transient-input source=%s" % source)


func reset_hand_drag_scroll_layout(source: String = "hand_generation") -> void:
	var hand_scroll := _hand_scroll()
	var content := _hand_drag_content_control(hand_scroll)
	if content == null:
		return
	# Semantic generations cancel pointer ownership, but must not collapse the
	# live ScrollContainer range. Setting size.x to zero synchronously clamps the
	# user's scroll position before the replacement cards have been laid out.
	# Extents are recomputed from child geometry at the deferred commit instead.
	content.update_minimum_size()
	debug_hand_drag_scroll("invalidate-layout source=%s" % source)


func capture_hand_drag_scroll_anchor(hand_scroll: ScrollContainer) -> Dictionary:
	if hand_scroll == null:
		return {}
	var viewport_rect := hand_scroll.get_global_rect()
	var max_scroll := _hand_drag_max_scroll(hand_scroll)
	var current_scroll := clampi(hand_scroll.scroll_horizontal, 0, max_scroll)
	var snapshot := {
		"scroll": current_scroll,
		"max_scroll": max_scroll,
		"was_at_end": max_scroll > 0 and max_scroll - current_scroll <= 2,
		"anchor_instance_id": -1,
		"anchor_viewport_offset": 0.0,
	}
	var content := _hand_drag_content_control(hand_scroll)
	if content == null:
		return snapshot
	for child: Node in content.get_children():
		var card_view := child as BattleCardView
		if card_view == null or card_view.card_instance == null or not card_view.visible:
			continue
		var card_rect := card_view.get_global_rect()
		if not viewport_rect.intersects(card_rect):
			continue
		snapshot["anchor_instance_id"] = card_view.card_instance.instance_id
		snapshot["anchor_viewport_offset"] = card_rect.position.x - viewport_rect.position.x
		break
	return snapshot


func restore_hand_drag_scroll_anchor(
	hand_scroll: ScrollContainer,
	snapshot: Dictionary,
	focus_instance_ids: Array = []
) -> int:
	if hand_scroll == null:
		return 0
	refresh_hand_drag_scroll_extents(hand_scroll)
	var max_scroll := _hand_drag_max_scroll(hand_scroll)
	var target_scroll := clampi(int(snapshot.get("scroll", hand_scroll.scroll_horizontal)), 0, max_scroll)
	var focused_target := _hand_drag_focus_scroll_target(
		hand_scroll,
		focus_instance_ids,
		target_scroll,
		max_scroll
	)
	if focused_target >= 0:
		target_scroll = focused_target
	elif bool(snapshot.get("was_at_end", false)):
		target_scroll = max_scroll
	else:
		var anchor_id := int(snapshot.get("anchor_instance_id", -1))
		var anchor_view := _hand_drag_card_view_for_instance(hand_scroll, anchor_id)
		if anchor_view != null:
			var viewport_left := hand_scroll.get_global_rect().position.x
			var anchor_content_left := (
				anchor_view.get_global_rect().position.x
				- viewport_left
				+ hand_scroll.scroll_horizontal
			)
			target_scroll = clampi(
				roundi(anchor_content_left - float(snapshot.get("anchor_viewport_offset", 0.0))),
				0,
				max_scroll
			)
	hand_scroll.scroll_horizontal = target_scroll
	var bar := hand_scroll.get_h_scroll_bar()
	if bar != null:
		bar.value = target_scroll
	debug_hand_drag_scroll(
		"restore-anchor target=%d focus=%s snapshot=%s %s" % [
			target_scroll,
			str(focus_instance_ids),
			str(snapshot),
			hand_drag_scroll_range_text(hand_scroll),
		]
	)
	return target_scroll


func hand_drag_projection_layout_is_sane(
	hand_scroll: ScrollContainer,
	focus_instance_ids: Array = []
) -> bool:
	if hand_scroll == null:
		return false
	var content := _hand_drag_content_control(hand_scroll)
	if content == null:
		return false
	if str(content.get_meta("battle_hand_surface_mode", "cards")) == "waiting":
		return hand_scroll.scroll_horizontal == 0
	var required_max_scroll := _hand_drag_max_scroll(hand_scroll)
	var bar := hand_scroll.get_h_scroll_bar()
	if bar == null:
		return required_max_scroll == 0
	var actual_max_scroll := maxi(0, roundi(bar.max_value - bar.page))
	if absi(actual_max_scroll - required_max_scroll) > 2:
		return false
	if hand_scroll.scroll_horizontal < 0 or hand_scroll.scroll_horizontal > required_max_scroll + 2:
		return false
	return _hand_drag_focus_is_visible(hand_scroll, focus_instance_ids)


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
		scroll.set_meta("card_gallery_drag_row_control", row)
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
	card_view.set_meta(
		"card_gallery_primary_click_filter",
		Callable(self, "should_filter_card_gallery_primary_click").bind(scroll)
	)
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
			return false
		return _end_card_gallery_drag_scroll(source)
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _as_bool(_get("_card_gallery_drag_active"), false) and _get("_card_gallery_drag_active_scroll") == scroll:
			return _update_card_gallery_drag_scroll(card_gallery_drag_event_position(event), scroll)
		return _try_late_start_card_gallery_drag_scroll_from_motion(
			motion.global_position,
			motion.relative,
			(motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0,
			scroll,
			source,
			false
		)
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_card_gallery_drag_scroll(card_gallery_drag_event_position(event), scroll, true)
			return false
		_remember_card_gallery_touch_release(touch.position, scroll)
		return _end_card_gallery_drag_scroll(source)
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _as_bool(_get("_card_gallery_drag_active"), false) and _get("_card_gallery_drag_active_scroll") == scroll:
			return _update_card_gallery_drag_scroll(card_gallery_drag_event_position(event), scroll)
		return _try_late_start_card_gallery_drag_scroll_from_motion(drag.position, drag.relative, true, scroll, source, true)
	return false


func should_filter_card_gallery_primary_click(event: InputEvent, scroll: ScrollContainer) -> bool:
	if scroll == null or not is_instance_valid(scroll):
		return false
	if scroll.get_instance_id() != _card_gallery_last_touch_release_scroll_id:
		return false
	return PointerGesturePolicyScript.is_touch_mouse_echo(
		event,
		_card_gallery_last_touch_release_msec,
		_card_gallery_last_touch_release_position
	)


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
	return "pos=%s global=%s size=%s min=%s combined=%s children=%d" % [str(content.position), str(content.global_position), str(content.size), str(content.custom_minimum_size), str(content.get_combined_minimum_size()), content.get_child_count()]


func refresh_hand_drag_scroll_extents(hand_scroll: ScrollContainer) -> void:
	if hand_scroll == null:
		return
	var content := _hand_drag_content_control(hand_scroll)
	if content == null:
		return
	var viewport_width := _hand_drag_viewport_width(hand_scroll)
	if viewport_width <= 0.0:
		return
	if str(content.get_meta("battle_hand_surface_mode", "cards")) == "waiting":
		# The Control.size from the outgoing wide card row survives for one layout
		# frame. It is not authoritative once the semantic surface is AI waiting
		# text; carrying it into the scrollbar range places centered text far to the
		# right until another hand mutation happens.
		content.custom_minimum_size.x = viewport_width
		content.size.x = viewport_width
		var waiting_bar := hand_scroll.get_h_scroll_bar()
		if waiting_bar != null:
			waiting_bar.min_value = 0.0
			waiting_bar.max_value = viewport_width
			waiting_bar.page = viewport_width
		hand_scroll.scroll_horizontal = 0
		return
	var content_width := _hand_drag_content_width(content)
	if content_width > viewport_width:
		content.custom_minimum_size.x = content_width
		if content.size.x < content_width:
			content.size.x = content_width
	else:
		var centered_landscape_rail := (
			content is BoxContainer
			and (content as BoxContainer).alignment
				== BoxContainer.ALIGNMENT_CENTER
		)
		if centered_landscape_rail:
			# The landscape display controller has already made the hand row as
			# wide as its visible rail so a short hand can center its children.
			# A deferred pointer-surface extent refresh must preserve that
			# contract; clearing it here made an Energy leaving hand jump the row
			# to the left until the next UI action restored the rail.
			content.custom_minimum_size.x = viewport_width
			if content.size.x < viewport_width:
				content.size.x = viewport_width
		else:
			# Portrait card rows shrink to their cards. A previous wider hand
			# must not become the next layout's minimum or make the horizontal
			# range grow monotonically across draws, plays, and handovers.
			content.custom_minimum_size.x = 0.0
	var hbar := hand_scroll.get_h_scroll_bar()
	if hbar == null:
		return
	var range_width := maxf(viewport_width, content_width)
	hbar.min_value = 0.0
	hbar.max_value = range_width
	hbar.page = viewport_width
	var max_scroll := maxi(0, roundi(range_width - viewport_width))
	hand_scroll.scroll_horizontal = clampi(
		hand_scroll.scroll_horizontal,
		0,
		max_scroll
	)


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
	return _screen_position_to_drag_local(screen_position)


func card_gallery_drag_event_position(event: InputEvent) -> Vector2:
	var screen_position := Vector2.ZERO
	if event is InputEventMouse:
		screen_position = (event as InputEventMouse).global_position
	elif event is InputEventScreenTouch:
		screen_position = (event as InputEventScreenTouch).position
	elif event is InputEventScreenDrag:
		screen_position = (event as InputEventScreenDrag).position
	return _screen_position_to_drag_local(screen_position)


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


func _begin_hand_drag_scroll(position: Vector2, hand_scroll: ScrollContainer, source: String = "", pointer_kind: String = "") -> void:
	if _as_bool(_get("_card_gallery_drag_active"), false):
		cancel_card_gallery_drag_scroll("hand_drag_start")
	_clear_hand_drag_click_suppression_for_fresh_press(position, pointer_kind, source)
	_active_hand_pointer_kind = pointer_kind
	refresh_hand_drag_scroll_extents(hand_scroll)
	_set_scene_var("_hand_drag_active", true)
	_set_scene_var("_hand_dragging", false)
	_set_scene_var("_hand_drag_start_position", position)
	_set_scene_var("_hand_drag_start_scroll", hand_scroll.scroll_horizontal)
	_set_scene_var("_hand_drag_debug_motion_count", 0)
	debug_hand_drag_scroll("begin source=%s pos=%s scroll=%d range=%s scroll_size=%s content=%s" % [source, str(position), int(_get("_hand_drag_start_scroll")), hand_drag_scroll_range_text(hand_scroll), str(hand_scroll.size), hand_drag_content_size_text(hand_scroll)])


func _try_late_start_hand_drag_scroll_from_motion(
	screen_position: Vector2,
	screen_relative: Vector2,
	primary_button_active: bool,
	hand_scroll: ScrollContainer,
	source: String = ""
) -> bool:
	if not primary_button_active:
		return false
	if not _drag_motion_started_in_scroll(hand_scroll, screen_position, screen_relative):
		return false
	var start_screen_position := screen_position - screen_relative
	var start_position := _screen_position_to_drag_local(start_screen_position)
	var current_position := _screen_position_to_drag_local(screen_position)
	_begin_hand_drag_scroll(start_position, hand_scroll, "%s_late" % source)
	return _update_hand_drag_scroll(current_position, hand_scroll, source)


func _update_hand_drag_scroll(position: Vector2, hand_scroll: ScrollContainer, source: String = "") -> bool:
	refresh_hand_drag_scroll_extents(hand_scroll)
	var start_position := _as_vector2(_get("_hand_drag_start_position"), Vector2.ZERO)
	var delta := position - start_position
	var threshold := _active_hand_drag_scroll_threshold()
	if not _as_bool(_get("_hand_dragging"), false) and absf(delta.x) < threshold:
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


func _end_hand_drag_scroll(source: String = "", release_position: Vector2 = Vector2(-1.0, -1.0), pointer_kind: String = "") -> bool:
	var was_dragging := _as_bool(_get("_hand_dragging"), false)
	_active_hand_pointer_kind = ""
	_set_scene_var("_hand_drag_active", false)
	_set_scene_var("_hand_dragging", false)
	var hand_scroll := _hand_scroll()
	debug_hand_drag_scroll("end source=%s was_dragging=%s scroll=%d range=%s" % [source, str(was_dragging), hand_scroll.scroll_horizontal if hand_scroll != null else -1, hand_drag_scroll_range_text(hand_scroll)])
	if was_dragging:
		_set_scene_var("_hand_drag_suppress_click_until_msec", Time.get_ticks_msec() + HAND_DRAG_CLICK_SUPPRESS_MSEC)
		_set_scene_var("_hand_drag_suppress_origin_position", release_position)
		_set_scene_var("_hand_drag_suppress_pointer_kind", pointer_kind)
		_accept_event()
	return was_dragging


func _active_hand_drag_scroll_threshold() -> float:
	if (
		_active_hand_pointer_kind == "touch"
		and _scene != null
		and is_instance_valid(_scene)
		and _scene.has_method("_uses_ios_web_hand_touch_profile")
		and bool(_scene.call("_uses_ios_web_hand_touch_profile"))
	):
		return IOS_WEB_HAND_DRAG_SCROLL_THRESHOLD
	return HAND_DRAG_SCROLL_THRESHOLD


func _clear_hand_drag_click_suppression_for_fresh_press(position: Vector2, pointer_kind: String, source: String) -> void:
	if not is_hand_drag_click_suppressed():
		return
	if _is_touch_drag_mouse_echo(position, pointer_kind):
		debug_hand_drag_scroll("keep-suppression source=%s pointer=%s pos=%s" % [source, pointer_kind, str(position)])
		return
	clear_hand_drag_click_suppression("fresh_hand_press_%s" % source)


func _is_touch_drag_mouse_echo(position: Vector2, pointer_kind: String) -> bool:
	if pointer_kind != "mouse":
		return false
	if str(_get("_hand_drag_suppress_pointer_kind")) != "touch":
		return false
	var origin := _as_vector2(_get("_hand_drag_suppress_origin_position"), Vector2(-1.0, -1.0))
	if origin.x < 0.0 or origin.y < 0.0:
		return false
	return position.distance_squared_to(origin) <= HAND_DRAG_TOUCH_MOUSE_ECHO_POSITION_EPSILON * HAND_DRAG_TOUCH_MOUSE_ECHO_POSITION_EPSILON


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
	_set_scene_var("_card_gallery_drag_touch_active", false)
	debug_hand_drag_scroll("clear-invalid-card-gallery source=%s" % source)


func _begin_card_gallery_drag_scroll(position: Vector2, scroll: ScrollContainer, from_touch: bool = false) -> void:
	_set_scene_var("_card_gallery_drag_active_scroll", scroll)
	_set_scene_var("_card_gallery_drag_active", true)
	_set_scene_var("_card_gallery_dragging", false)
	_set_scene_var("_card_gallery_drag_start_position", position)
	_set_scene_var("_card_gallery_drag_start_scroll", scroll.scroll_horizontal)
	_set_scene_var("_card_gallery_drag_touch_active", from_touch)


func _try_late_start_card_gallery_drag_scroll_from_motion(
	screen_position: Vector2,
	screen_relative: Vector2,
	primary_button_active: bool,
	scroll: ScrollContainer,
	source: String = "",
	from_touch: bool = false
) -> bool:
	if not primary_button_active:
		return false
	if not _drag_motion_started_in_scroll(scroll, screen_position, screen_relative):
		return false
	var start_screen_position := screen_position - screen_relative
	var start_position := _screen_position_to_drag_local(start_screen_position)
	var current_position := _screen_position_to_drag_local(screen_position)
	_begin_card_gallery_drag_scroll(start_position, scroll, from_touch)
	debug_hand_drag_scroll("card-gallery-late-begin source=%s pos=%s scroll=%d" % [source, str(start_position), scroll.scroll_horizontal])
	return _update_card_gallery_drag_scroll(current_position, scroll)


func _update_card_gallery_drag_scroll(position: Vector2, scroll: ScrollContainer) -> bool:
	var delta := position - _as_vector2(_get("_card_gallery_drag_start_position"), Vector2.ZERO)
	var threshold := (
		PointerGesturePolicyScript.touch_horizontal_tap_tolerance()
		if _as_bool(_get("_card_gallery_drag_touch_active"), false)
		else HAND_DRAG_SCROLL_THRESHOLD
	)
	if (
		not _as_bool(_get("_card_gallery_dragging"), false)
		and (absf(delta.x) <= threshold or absf(delta.x) < absf(delta.y))
	):
		return false
	if not _card_gallery_has_horizontal_overflow(scroll):
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
		_accept_event()
	return was_dragging


func _remember_card_gallery_touch_release(position: Vector2, scroll: ScrollContainer) -> void:
	_card_gallery_last_touch_release_msec = Time.get_ticks_msec()
	_card_gallery_last_touch_release_position = position
	_card_gallery_last_touch_release_scroll_id = scroll.get_instance_id()


func _clear_card_gallery_touch_mouse_echo() -> void:
	_card_gallery_last_touch_release_msec = -1
	_card_gallery_last_touch_release_position = Vector2(-1.0, -1.0)
	_card_gallery_last_touch_release_scroll_id = -1


func _card_gallery_has_horizontal_overflow(scroll: ScrollContainer) -> bool:
	if scroll == null:
		return false
	var bar := scroll.get_h_scroll_bar()
	if bar != null and bar.page > 0.5 and bar.max_value > bar.page + 0.5:
		return true
	if not scroll.is_inside_tree():
		var row_variant: Variant = scroll.get_meta("card_gallery_drag_row_control", null)
		var row := row_variant as Control
		return row != null and _card_gallery_card_count(row) > 1
	if scroll.size.x <= 0.5:
		return false
	for child: Node in scroll.get_children():
		var content := child as Control
		if content == null or content == bar:
			continue
		if maxf(content.size.x, content.get_combined_minimum_size().x) > scroll.size.x + 0.5:
			return true
	return false


func _card_gallery_card_count(node: Node) -> int:
	if node == null:
		return 0
	var count := 0
	for child: Node in node.get_children():
		if child is BattleCardView:
			count += 1
		else:
			count += _card_gallery_card_count(child)
	return count


func _hand_scroll() -> ScrollContainer:
	var hand_scroll := _get("_hand_scroll") as ScrollContainer
	if hand_scroll != null:
		return hand_scroll
	return _find("HandScroll", true, false) as ScrollContainer


func _hand_drag_content_control(hand_scroll: ScrollContainer) -> Control:
	if hand_scroll == null or hand_scroll.get_child_count() <= 0:
		return null
	return hand_scroll.get_child(0) as Control


func _drag_motion_started_in_scroll(scroll: ScrollContainer, screen_position: Vector2, screen_relative: Vector2) -> bool:
	if scroll == null or not is_instance_valid(scroll):
		return false
	if scroll.is_inside_tree() and not scroll.is_visible_in_tree():
		return false
	var start_screen_position := screen_position - screen_relative
	var rect := scroll.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		rect = Rect2(scroll.global_position, scroll.size)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		rect = Rect2(Vector2.ZERO, scroll.custom_minimum_size)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	return rect.has_point(start_screen_position) or (screen_relative == Vector2.ZERO and rect.has_point(screen_position))


func _hand_drag_viewport_width(hand_scroll: ScrollContainer) -> float:
	if hand_scroll == null:
		return 0.0
	return maxf(hand_scroll.size.x, hand_scroll.custom_minimum_size.x)


func _screen_position_to_drag_local(screen_position: Vector2) -> Vector2:
	return _as_vector2(_call("_screen_position_to_battle_local", [screen_position]), screen_position)


func _hand_drag_content_width(content: Control) -> float:
	if content == null:
		return 0.0
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
	if visible_child_count > 0:
		# The HBox arranged width and custom minimum are projection outputs. Using
		# either as the next generation's input makes the hand rail grow forever or
		# forces callers to collapse it to zero. Visible children are the semantic
		# source of truth for a card surface.
		return child_width
	return maxf(content.size.x, content.get_combined_minimum_size().x)


func _hand_drag_max_scroll(hand_scroll: ScrollContainer) -> int:
	if hand_scroll == null:
		return 0
	var content := _hand_drag_content_control(hand_scroll)
	var viewport_width := _hand_drag_viewport_width(hand_scroll)
	if content == null or viewport_width <= 0.0:
		return 0
	return maxi(0, roundi(_hand_drag_content_width(content) - viewport_width))


func _hand_drag_card_view_for_instance(
	hand_scroll: ScrollContainer,
	instance_id: int
) -> BattleCardView:
	if instance_id < 0:
		return null
	var content := _hand_drag_content_control(hand_scroll)
	if content == null:
		return null
	for child: Node in content.get_children():
		var card_view := child as BattleCardView
		if (
			card_view != null
			and card_view.card_instance != null
			and card_view.card_instance.instance_id == instance_id
		):
			return card_view
	return null


func _hand_drag_focus_scroll_target(
	hand_scroll: ScrollContainer,
	focus_instance_ids: Array,
	fallback_scroll: int,
	max_scroll: int
) -> int:
	if focus_instance_ids.is_empty():
		return -1
	var viewport_width := _hand_drag_viewport_width(hand_scroll)
	if viewport_width <= 0.0:
		return -1
	var viewport_left := hand_scroll.get_global_rect().position.x
	var group_left := INF
	var group_right := -INF
	var found := 0
	for raw_id: Variant in focus_instance_ids:
		var card_view := _hand_drag_card_view_for_instance(hand_scroll, int(raw_id))
		if card_view == null or not card_view.visible:
			continue
		var rect := card_view.get_global_rect()
		var content_left := rect.position.x - viewport_left + hand_scroll.scroll_horizontal
		group_left = minf(group_left, content_left)
		group_right = maxf(group_right, content_left + rect.size.x)
		found += 1
	if found <= 0:
		return -1
	var target := float(clampi(fallback_scroll, 0, max_scroll))
	if group_right - group_left > viewport_width:
		target = group_left
	elif group_left < target:
		target = group_left
	elif group_right > target + viewport_width:
		target = group_right - viewport_width
	return clampi(roundi(target), 0, max_scroll)


func _hand_drag_focus_is_visible(
	hand_scroll: ScrollContainer,
	focus_instance_ids: Array
) -> bool:
	if focus_instance_ids.is_empty():
		return true
	var viewport_rect := hand_scroll.get_global_rect()
	var focus_views: Array[BattleCardView] = []
	var group_width := 0.0
	for raw_id: Variant in focus_instance_ids:
		var card_view := _hand_drag_card_view_for_instance(hand_scroll, int(raw_id))
		if card_view == null or not card_view.visible:
			return false
		focus_views.append(card_view)
		group_width += card_view.get_global_rect().size.x
	if focus_views.size() > 1:
		var content := _hand_drag_content_control(hand_scroll)
		group_width += float((content as BoxContainer).get_theme_constant("separation") if content is BoxContainer else 0) * float(focus_views.size() - 1)
	var visible_count := 0
	for card_view: BattleCardView in focus_views:
		if viewport_rect.intersects(card_view.get_global_rect()):
			visible_count += 1
	if group_width <= viewport_rect.size.x + 1.0:
		return visible_count == focus_views.size()
	return visible_count > 0


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
