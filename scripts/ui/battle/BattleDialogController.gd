class_name BattleDialogController
extends RefCounted

const BattleCardViewScript := preload("res://scenes/battle/BattleCardView.gd")
const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")
const PointerGesturePolicyScript := preload("res://scripts/ui/input/PointerGesturePolicy.gd")
const BattleTurnActionPolicyScript := preload("res://scripts/ui/battle/BattleTurnActionPolicy.gd")
const ENERGY_ICON_TEXTURES := {
	"R": preload("res://assets/ui/e-huo.png"),
	"W": preload("res://assets/ui/e-shui.png"),
	"G": preload("res://assets/ui/e-cao.png"),
	"L": preload("res://assets/ui/e-lei.png"),
	"P": preload("res://assets/ui/e-chao.png"),
	"F": preload("res://assets/ui/e-dou.png"),
	"D": preload("res://assets/ui/e-e.png"),
	"M": preload("res://assets/ui/e-gang.png"),
	"N": preload("res://assets/ui/e-long.png"),
	"C": preload("res://assets/ui/e-wu.png"),
}
const TEXT_HUD_OPTION_SIZE := Vector2(760, 74)
const PORTRAIT_TEXT_HUD_OPTION_HEIGHT := 128.0
const PORTRAIT_TEXT_HUD_OPTION_HORIZONTAL_INSET := 48.0
const ACTION_HUD_ENERGY_SUMMARY_HEIGHT := 66.0
const ACTION_HUD_PREVIEW_CHROME_WIDTH := 14.0
const ACTION_HUD_PREVIEW_ROW_SEPARATION := 16.0
const PORTRAIT_ACTION_HUD_MIN_OPTION_WIDTH := 156.0
const PORTRAIT_ACTION_HUD_MIN_PREVIEW_WIDTH := 96.0
const PORTRAIT_ACTION_HUD_MAX_PREVIEW_WIDTH_RATIO := 0.40
const ACTION_HUD_TOUCH_CLICK_MOVE_TOLERANCE := 32.0
const DIALOG_BOX_VISIBLE_VERTICAL_MARGIN := 12.0
const DIALOG_SCROLL_MIN_VISIBLE_HEIGHT := 120.0
const DIALOG_MODAL_ECHO_POSITION_EPSILON := 24.0
const DIALOG_MODAL_ECHO_SUPPRESS_MSEC := 250
const LIBRARY_SEARCH_BOARD_MIN_WIDTH := 960.0
const LIBRARY_SEARCH_BOARD_WIDTH_RATIO := 0.88
const LIBRARY_SEARCH_BOARD_EXTRA_HEIGHT_RATIO := 0.05
const LIBRARY_SEARCH_BOARD_EXTRA_HEIGHT_MIN := 28.0
const LIBRARY_SEARCH_BOARD_EXTRA_HEIGHT_MAX := 56.0
const LIBRARY_SEARCH_COMMAND_BAR_HEIGHT := 72.0
const LIBRARY_SEARCH_PORTRAIT_COMMAND_BAR_HEIGHT := 92.0
const LIBRARY_SEARCH_PORTRAIT_SELECTED_SCALE := 1.0
const LIBRARY_SEARCH_PORTRAIT_SOURCE_CARD_SCALE := 0.58
const LIBRARY_SEARCH_PORTRAIT_SOURCE_BAR_MIN_HEIGHT := 118.0
const LIBRARY_SEARCH_PORTRAIT_EMPTY_SLOT_FONT_SIZE := 32
const LIBRARY_SEARCH_SOURCE_WIDTH_MIN := 196.0
const LIBRARY_SEARCH_SOURCE_WIDTH_MAX := 214.0
const LIBRARY_SEARCH_CANDIDATE_VERTICAL_CLICK_TOLERANCE := PointerGesturePolicyScript.TOUCH_VERTICAL_TAP_TOLERANCE

var _pending_dialog_center_locks: Dictionary = {}
var _pending_dialog_reveals: Dictionary = {}


func _bt(scene: Object, key: String, params: Dictionary = {}) -> String:
	return str(scene.call("_bt", key, params))


func mark_modal_input_consumed(scene: Object, reason: String = "dialog", slot_suppression_mode: String = "arm") -> void:
	if scene == null:
		return
	if scene.has_method("_finish_modal_input_interaction"):
		scene.call("_finish_modal_input_interaction", reason, slot_suppression_mode)
		return
	if slot_suppression_mode == "clear" and scene.has_method("_mark_modal_input_consumed_without_slot_suppression"):
		scene.call("_mark_modal_input_consumed_without_slot_suppression", reason)
	elif scene.has_method("_mark_modal_input_consumed"):
		scene.call("_mark_modal_input_consumed", reason)


func mark_modal_input_consumed_from_event(scene: Object, reason: String, event: InputEvent, slot_suppression_mode: String = "arm") -> void:
	mark_modal_input_consumed_at_position(scene, reason, _input_event_screen_position(event), slot_suppression_mode)


func mark_modal_input_consumed_at_position(scene: Object, reason: String, origin_position: Vector2, slot_suppression_mode: String = "arm") -> void:
	if scene == null:
		return
	if scene.has_method("_finish_modal_input_interaction"):
		scene.call("_finish_modal_input_interaction", reason, slot_suppression_mode, origin_position)
		return
	mark_modal_input_consumed(scene, reason, slot_suppression_mode)


func _dialog_slot_suppression_mode(scene: Object) -> String:
	if str(scene.get("_pending_choice")) == "pokemon_action":
		return "sequence"
	return "arm"


func _dialog_selection_slot_suppression_mode(scene: Object, sel_items: PackedInt32Array) -> String:
	if str(scene.get("_pending_choice")) != "pokemon_action":
		return _dialog_slot_suppression_mode(scene)
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var actions: Array = dialog_data.get("actions", [])
	for selected_index: int in sel_items:
		if selected_index < 0 or selected_index >= actions.size():
			continue
		var action: Variant = actions[selected_index]
		if action is Dictionary and str((action as Dictionary).get("type", "")) == "retreat":
			return "arm"
	return "clear"


func _input_event_screen_position(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		var mouse := event as InputEventMouse
		if mouse.global_position.x >= 0.0 and mouse.global_position.y >= 0.0:
			return mouse.global_position
		return mouse.position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	return Vector2(-1.0, -1.0)


func _valid_input_position(position: Vector2) -> bool:
	return position.x >= 0.0 and position.y >= 0.0


func _input_positions_match(a: Vector2, b: Vector2) -> bool:
	if not _valid_input_position(a) or not _valid_input_position(b):
		return false
	return a.distance_squared_to(b) <= DIALOG_MODAL_ECHO_POSITION_EPSILON * DIALOG_MODAL_ECHO_POSITION_EPSILON


func _dialog_modal_echo_window_active(scene: Object) -> bool:
	var finished_at := int(scene.get("_modal_input_finished_at_msec"))
	if finished_at <= 0:
		return true
	return Time.get_ticks_msec() <= finished_at + DIALOG_MODAL_ECHO_SUPPRESS_MSEC


func _begin_dialog_modal_transition(scene: Object) -> void:
	var depth := int(scene.get("_dialog_modal_transition_depth")) + 1
	scene.set("_dialog_modal_transition_depth", depth)
	scene.set("_dialog_modal_transition_generation", int(scene.get("_modal_input_generation")))
	scene.set("_dialog_modal_transition_origin_position", scene.get("_modal_input_origin_position"))
	scene.set("_dialog_modal_transition_origin_source", str(scene.get("_dialog_user_input_source")))


func _end_dialog_modal_transition(scene: Object) -> void:
	var depth := maxi(0, int(scene.get("_dialog_modal_transition_depth")) - 1)
	scene.set("_dialog_modal_transition_depth", depth)
	if depth == 0:
		scene.set("_dialog_modal_transition_generation", -1)


func _prepare_dialog_action_input_guard(scene: Object) -> void:
	var next_generation := int(scene.get("_dialog_generation")) + 1
	var modal_transition_depth := int(scene.get("_dialog_modal_transition_depth"))
	var modal_generation := int(scene.get("_modal_input_generation"))
	var transition_generation := int(scene.get("_dialog_modal_transition_generation"))
	scene.set("_dialog_generation", next_generation)
	scene.set("_dialog_user_input_generation", -1)
	scene.set("_dialog_user_input_position", Vector2(-1.0, -1.0))
	scene.set("_dialog_user_input_source", "")
	scene.set("_dialog_confirm_input_generation", -1)
	scene.set("_dialog_confirm_input_position", Vector2(-1.0, -1.0))
	scene.set("_dialog_cancel_input_generation", -1)
	scene.set("_dialog_cancel_input_position", Vector2(-1.0, -1.0))
	scene.set("_dialog_confirm_activated_on_button_down", false)
	scene.set("_dialog_cancel_activated_on_button_down", false)
	scene.set("_dialog_modal_echo_blocked", false)
	scene.set("_dialog_echo_action_pending", "")
	var requires_fresh_action := modal_transition_depth > 0 and transition_generation >= 0 and transition_generation == modal_generation
	scene.set("_dialog_requires_fresh_action_input", requires_fresh_action)
	scene.set(
		"_dialog_same_position_action_locked",
		requires_fresh_action and _valid_input_position(scene.get("_dialog_modal_transition_origin_position"))
	)
	if not requires_fresh_action:
		scene.set("_dialog_modal_transition_origin_position", Vector2(-1.0, -1.0))
		scene.set("_dialog_modal_transition_origin_source", "")


func _record_dialog_fresh_input(scene: Object, source: String = "dialog", position: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if scene.has_method("_mark_ui_interaction_progress"):
		scene.call("_mark_ui_interaction_progress", source)
	scene.set("_dialog_user_input_generation", int(scene.get("_dialog_generation")))
	scene.set("_dialog_user_input_position", position)
	scene.set("_dialog_user_input_source", source)
	scene.set("_dialog_echo_action_pending", "")
	if (
		not _valid_input_position(position)
		or not _input_positions_match(position, scene.get("_dialog_modal_transition_origin_position"))
	):
		scene.set("_dialog_same_position_action_locked", false)


func _is_modal_echo_action_position(scene: Object, position: Vector2) -> bool:
	if not bool(scene.get("_dialog_requires_fresh_action_input")):
		return false
	if not _dialog_modal_echo_window_active(scene):
		return false
	if not bool(scene.get("_dialog_same_position_action_locked")):
		return false
	return _input_positions_match(position, scene.get("_dialog_modal_transition_origin_position"))


func _is_dialog_action_press_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	return false


func on_dialog_action_button_input(scene: Object, action: String, event: InputEvent) -> void:
	if not _is_dialog_action_press_event(event):
		return
	if scene.has_method("_claim_modal_pointer_event"):
		scene.call("_claim_modal_pointer_event", event, "dialog_%s" % action)
	var generation := int(scene.get("_dialog_generation"))
	var position := _input_event_screen_position(event)
	if _is_modal_echo_action_position(scene, position):
		scene.set("_dialog_echo_action_pending", action)
		scene.call(
			"_runtime_log",
			"dialog_%s_same_position_echo_pending" % action,
			"generation=%d position=%s %s" % [generation, str(position), scene.call("_dialog_state_snapshot")]
		)
		return
	_record_dialog_fresh_input(scene, "dialog_%s_button" % action, position)
	if action == "confirm":
		scene.set("_dialog_confirm_input_generation", generation)
		scene.set("_dialog_confirm_input_position", position)
	elif action == "cancel":
		scene.set("_dialog_cancel_input_generation", generation)
		scene.set("_dialog_cancel_input_position", position)


func on_dialog_action_button_down(scene: Object, action: String) -> void:
	if scene.has_method("_claim_current_modal_pointer_sequence"):
		scene.call("_claim_current_modal_pointer_sequence", "dialog_%s" % action)
	if (
		bool(scene.get("_dialog_requires_fresh_action_input"))
		and bool(scene.get("_dialog_same_position_action_locked"))
		and _dialog_modal_echo_window_active(scene)
		and str(scene.get("_dialog_echo_action_pending")) == action
	):
		return
	if (
		bool(scene.get("_dialog_requires_fresh_action_input"))
		and bool(scene.get("_dialog_same_position_action_locked"))
		and _dialog_modal_echo_window_active(scene)
		and _valid_input_position(scene.get("_dialog_modal_transition_origin_position"))
		and int(scene.get("_dialog_user_input_generation")) != int(scene.get("_dialog_generation"))
	):
		scene.set("_dialog_echo_action_pending", action)
		return
	var generation := int(scene.get("_dialog_generation"))
	_record_dialog_fresh_input(scene, "dialog_%s_button_down" % action)
	if action == "confirm":
		scene.set("_dialog_confirm_input_generation", generation)
	elif action == "cancel":
		scene.set("_dialog_cancel_input_generation", generation)


func _has_fresh_dialog_action_input(scene: Object, action: String) -> bool:
	if not bool(scene.get("_dialog_requires_fresh_action_input")):
		return true
	var generation := int(scene.get("_dialog_generation"))
	if int(scene.get("_dialog_user_input_generation")) == generation:
		return true
	if action == "confirm" and int(scene.get("_dialog_confirm_input_generation")) == generation:
		return true
	if action == "cancel" and int(scene.get("_dialog_cancel_input_generation")) == generation:
		return true
	if str(scene.get("_dialog_echo_action_pending")) == action:
		return false
	if action == "cancel":
		return true
	if not bool(scene.get("_dialog_same_position_action_locked")):
		if str(scene.get("_dialog_modal_transition_origin_source")) == "dialog_confirm":
			return bool(scene.get("_dialog_modal_echo_blocked"))
		return true
	if bool(scene.get("_dialog_modal_echo_blocked")) and str(scene.get("_dialog_echo_action_pending")) == "":
		return true
	if bool(scene.get("_dialog_modal_echo_blocked")) and not _dialog_modal_echo_window_active(scene):
		return true
	return false


func _consume_dialog_action_if_stale(scene: Object, action: String) -> bool:
	if _has_fresh_dialog_action_input(scene, action):
		return false
	scene.set("_dialog_modal_echo_blocked", true)
	scene.set("_dialog_echo_action_pending", "")
	scene.call(
		"_runtime_log",
		"dialog_%s_stale_input_blocked" % action,
		"generation=%d modal_generation=%d %s" % [
			int(scene.get("_dialog_generation")),
			int(scene.get("_modal_input_generation")),
			scene.call("_dialog_state_snapshot"),
		]
	)
	return true


func _consume_direct_dialog_choice_if_stale(scene: Object, source: String, position: Vector2) -> bool:
	if not bool(scene.get("_dialog_requires_fresh_action_input")):
		return false
	if not _dialog_modal_echo_window_active(scene):
		return false
	if not bool(scene.get("_dialog_same_position_action_locked")):
		return false
	if not _input_positions_match(position, scene.get("_dialog_modal_transition_origin_position")):
		return false
	if bool(scene.get("_dialog_modal_echo_blocked")):
		scene.set("_dialog_same_position_action_locked", false)
		return false
	scene.set("_dialog_modal_echo_blocked", true)
	scene.set("_dialog_echo_action_pending", "")
	scene.call(
		"_runtime_log",
		"dialog_%s_stale_input_blocked" % source,
		"generation=%d modal_generation=%d position=%s %s" % [
			int(scene.get("_dialog_generation")),
			int(scene.get("_modal_input_generation")),
			str(position),
			scene.call("_dialog_state_snapshot"),
		]
	)
	return true


func _dialog_action_input_position(scene: Object, action: String) -> Vector2:
	if action == "confirm":
		return scene.get("_dialog_confirm_input_position")
	if action == "cancel":
		return scene.get("_dialog_cancel_input_position")
	return Vector2(-1.0, -1.0)


func _cancel_card_gallery_drag_capture(scene: Object, source: String) -> void:
	if scene == null or not scene.has_method("_cancel_card_gallery_drag_scroll"):
		return
	scene.call("_cancel_card_gallery_drag_scroll", source)


func _hide_dialog_overlay(scene: Object, source: String) -> void:
	_cancel_card_gallery_drag_capture(scene, source)
	_set_assignment_gallery_lanes_active(scene, false)
	var dialog_overlay := scene.get("_dialog_overlay") as Panel
	if dialog_overlay != null:
		dialog_overlay.visible = false
	restore_library_search_board(scene)
	if scene.has_method("_refresh_end_turn_hud_button_state"):
		scene.call("_refresh_end_turn_hud_button_state")


func _replace_int_array(scene: Object, property_name: String, values: Array) -> void:
	var snapshot := values.duplicate()
	var target: Array[int] = scene.get(property_name)
	target.clear()
	for value_variant: Variant in snapshot:
		target.append(int(value_variant))
	scene.set(property_name, target)


func _replace_dictionary_array(scene: Object, property_name: String, values: Array) -> void:
	var snapshot := values.duplicate(true)
	var target: Array[Dictionary] = scene.get(property_name)
	target.clear()
	for value_variant: Variant in snapshot:
		if value_variant is Dictionary:
			target.append((value_variant as Dictionary).duplicate(true))
	scene.set(property_name, target)


func setup_dialog_gallery(scene: Object) -> void:
	var dialog_box := scene.get("_dialog_box") as Control
	var dialog_confirm := scene.get("_dialog_confirm") as Button
	var dialog_vbox := scene.get("_dialog_vbox") as VBoxContainer
	if dialog_box == null or dialog_confirm == null or dialog_vbox == null:
		return
	dialog_box.custom_minimum_size = Vector2(860, 0)
	dialog_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dialog_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var buttons_row := dialog_confirm.get_parent() as Control
	if buttons_row == null:
		return
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")

	var dialog_card_scroll := ScrollContainer.new()
	dialog_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	dialog_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog_card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_card_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dialog_card_scroll.custom_minimum_size = Vector2(0, float(scene.call("_card_gallery_scroll_height", dialog_card_size.y)))
	dialog_card_scroll.visible = false
	HudThemeScript.style_scroll_container(dialog_card_scroll)
	dialog_vbox.add_child(dialog_card_scroll)
	dialog_vbox.move_child(dialog_card_scroll, buttons_row.get_index())
	scene.set("_dialog_card_scroll", dialog_card_scroll)

	var dialog_card_row := HBoxContainer.new()
	dialog_card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_card_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dialog_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dialog_card_row.add_theme_constant_override("separation", 10)
	dialog_card_scroll.add_child(dialog_card_row)
	scene.set("_dialog_card_row", dialog_card_row)
	scene.call("_configure_card_gallery_drag_scroll", dialog_card_scroll, dialog_card_row, "dialog_cards")

	var dialog_status_lbl := Label.new()
	dialog_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_status_lbl.visible = false
	dialog_vbox.add_child(dialog_status_lbl)
	dialog_vbox.move_child(dialog_status_lbl, buttons_row.get_index())
	scene.set("_dialog_status_lbl", dialog_status_lbl)

	var dialog_utility_row := HBoxContainer.new()
	dialog_utility_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dialog_utility_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_utility_row.add_theme_constant_override("separation", 12)
	dialog_utility_row.visible = false
	dialog_vbox.add_child(dialog_utility_row)
	dialog_vbox.move_child(dialog_utility_row, buttons_row.get_index())
	scene.set("_dialog_utility_row", dialog_utility_row)

	var dialog_assignment_panel := VBoxContainer.new()
	dialog_assignment_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_assignment_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog_assignment_panel.add_theme_constant_override("separation", 8)
	dialog_assignment_panel.visible = false
	dialog_vbox.add_child(dialog_assignment_panel)
	dialog_vbox.move_child(dialog_assignment_panel, buttons_row.get_index())
	scene.set("_dialog_assignment_panel", dialog_assignment_panel)

	var source_title := Label.new()
	source_title.text = "来源卡牌"
	source_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_assignment_panel.add_child(source_title)

	var dialog_assignment_source_scroll := ScrollContainer.new()
	dialog_assignment_source_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	dialog_assignment_source_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog_assignment_source_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_assignment_source_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dialog_assignment_source_scroll.custom_minimum_size = Vector2(0, float(scene.call("_dialog_card_scroll_height")))
	HudThemeScript.style_scroll_container(dialog_assignment_source_scroll)
	dialog_assignment_panel.add_child(dialog_assignment_source_scroll)
	scene.set("_dialog_assignment_source_scroll", dialog_assignment_source_scroll)

	var dialog_assignment_source_row := HBoxContainer.new()
	dialog_assignment_source_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_assignment_source_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dialog_assignment_source_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dialog_assignment_source_row.add_theme_constant_override("separation", 14)
	dialog_assignment_source_row.custom_minimum_size = Vector2(0, dialog_card_size.y)
	dialog_assignment_source_row.size = Vector2(0, dialog_card_size.y)
	dialog_assignment_source_scroll.add_child(dialog_assignment_source_row)
	scene.set("_dialog_assignment_source_row", dialog_assignment_source_row)
	scene.call(
		"_configure_card_gallery_drag_scroll",
		dialog_assignment_source_scroll,
		dialog_assignment_source_row,
		"assignment_source_cards"
	)

	var target_title := Label.new()
	target_title.text = "目标卡牌"
	target_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_assignment_panel.add_child(target_title)

	var dialog_assignment_target_scroll := ScrollContainer.new()
	dialog_assignment_target_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	dialog_assignment_target_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog_assignment_target_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_assignment_target_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dialog_assignment_target_scroll.custom_minimum_size = Vector2(0, float(scene.call("_dialog_card_scroll_height")))
	HudThemeScript.style_scroll_container(dialog_assignment_target_scroll)
	dialog_assignment_panel.add_child(dialog_assignment_target_scroll)
	scene.set("_dialog_assignment_target_scroll", dialog_assignment_target_scroll)

	var dialog_assignment_target_row := HBoxContainer.new()
	dialog_assignment_target_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_assignment_target_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dialog_assignment_target_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dialog_assignment_target_row.add_theme_constant_override("separation", 14)
	dialog_assignment_target_row.custom_minimum_size = Vector2(0, dialog_card_size.y)
	dialog_assignment_target_row.size = Vector2(0, dialog_card_size.y)
	dialog_assignment_target_scroll.add_child(dialog_assignment_target_row)
	scene.set("_dialog_assignment_target_row", dialog_assignment_target_row)
	scene.call(
		"_configure_card_gallery_drag_scroll",
		dialog_assignment_target_scroll,
		dialog_assignment_target_row,
		"assignment_target_cards"
	)

	var dialog_assignment_summary_lbl := Label.new()
	dialog_assignment_summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_assignment_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_assignment_panel.add_child(dialog_assignment_summary_lbl)
	scene.set("_dialog_assignment_summary_lbl", dialog_assignment_summary_lbl)


func setup_discard_gallery(scene: Object) -> void:
	var scene_node := scene as Node
	if scene_node == null:
		return
	if scene.get("_discard_overlay") == null:
		scene.set("_discard_overlay", scene_node.find_child("DiscardOverlay", true, false) as Panel)
	if scene.get("_discard_title") == null:
		scene.set("_discard_title", scene_node.find_child("DiscardTitle", true, false) as Label)
	if scene.get("_discard_list") == null:
		scene.set("_discard_list", scene_node.find_child("DiscardList", true, false) as ItemList)
	if scene.get("_discard_close_btn") == null:
		scene.set("_discard_close_btn", scene_node.find_child("DiscardCloseBtn", true, false) as Button)
	var discard_box := scene_node.get_node_or_null("DiscardOverlay/DiscardCenter/DiscardBox") as PanelContainer
	if discard_box == null:
		return
	discard_box.custom_minimum_size = Vector2(860, 0)
	discard_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	discard_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var discard_vbox := scene_node.get_node_or_null("DiscardOverlay/DiscardCenter/DiscardBox/DiscardVBox") as VBoxContainer
	if discard_vbox == null:
		return
	var close_btn := scene.get("_discard_close_btn") as Button
	discard_vbox.add_theme_constant_override("separation", 10)
	var discard_list := scene.get("_discard_list") as ItemList
	if discard_list != null:
		discard_list.visible = false
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")

	var discard_card_scroll := ScrollContainer.new()
	discard_card_scroll.name = "DiscardCardScroll"
	discard_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	discard_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	discard_card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard_card_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	discard_card_scroll.custom_minimum_size = Vector2(0, float(scene.call("_card_gallery_scroll_height", dialog_card_size.y)))
	HudThemeScript.style_scroll_container(discard_card_scroll)
	discard_vbox.add_child(discard_card_scroll)
	if close_btn != null:
		discard_vbox.move_child(discard_card_scroll, close_btn.get_index())
	scene.set("_discard_card_scroll", discard_card_scroll)

	var discard_card_row := HBoxContainer.new()
	discard_card_row.name = "DiscardCardRow"
	discard_card_row.custom_minimum_size = Vector2(0, dialog_card_size.y)
	discard_card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard_card_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	discard_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	discard_card_row.add_theme_constant_override("separation", 14)
	discard_card_scroll.add_child(discard_card_row)
	scene.set("_discard_card_row", discard_card_row)
	scene.call("_configure_card_gallery_drag_scroll", discard_card_scroll, discard_card_row, "discard_collection")

	var discard_utility_row := HBoxContainer.new()
	discard_utility_row.name = "DiscardUtilityRow"
	discard_utility_row.alignment = BoxContainer.ALIGNMENT_CENTER
	discard_utility_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard_utility_row.add_theme_constant_override("separation", 12)
	discard_utility_row.visible = false
	discard_vbox.add_child(discard_utility_row)
	if close_btn != null:
		discard_vbox.move_child(discard_utility_row, close_btn.get_index())
	scene.set("_discard_utility_row", discard_utility_row)
	scene.call("_style_discard_collection_overlay")
	scene.call("_apply_discard_collection_metrics")


func dialog_item_has_card_visual(item: Variant) -> bool:
	return item is CardInstance or item is CardData or item is PokemonSlot


func dialog_choice_subtitle(scene: Object, item: Variant, label: String) -> String:
	if item is PokemonSlot:
		var slot: PokemonSlot = item
		return "HP %d/%d" % [scene.call("_get_display_remaining_hp", slot), scene.call("_get_display_max_hp", slot)]
	if item is CardInstance:
		var card: CardInstance = item
		if label != "" and label != card.card_data.name and label != card.card_data.display_name():
			return label
		return str(scene.call("_hand_card_subtext", card.card_data))
	if item is CardData:
		var data: CardData = item
		if label != "" and label != data.name and label != data.display_name():
			return label
		return str(scene.call("_hand_card_subtext", data))
	return label


func selection_label_from_item(item: Variant, fallback: String = "") -> String:
	if fallback.strip_edges() != "":
		return fallback.strip_edges()
	if item is PokemonSlot:
		return _slot_display_name(item as PokemonSlot)
	if item is CardInstance:
		var card: CardInstance = item
		return card.card_data.display_name() if card.card_data != null else ""
	if item is CardData:
		return (item as CardData).display_name()
	if item is Dictionary:
		var entry: Dictionary = item
		for key: String in ["pokemon_name", "card_name", "name", "title"]:
			var text := str(entry.get(key, "")).strip_edges()
			if text != "":
				return text
	return str(item).strip_edges()


func _slot_display_name(slot: PokemonSlot) -> String:
	if slot == null:
		return ""
	var data := slot.get_card_data()
	if data != null:
		return data.display_name()
	return slot.get_pokemon_name()


func dialog_label_at(labels: Array, index: int) -> String:
	if index < 0 or index >= labels.size():
		return ""
	var label: Variant = labels[index]
	if label == null or dialog_item_has_card_visual(label):
		return ""
	return str(label)


func selected_dialog_labels(scene: Object, sel_items: PackedInt32Array) -> Array[String]:
	var labels: Array[String] = []
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var dialog_items_data: Array = scene.get("_dialog_items_data")
	var choice_labels: Array = dialog_data.get("choice_labels", dialog_items_data)
	for idx: int in sel_items:
		if idx < 0:
			continue
		var item: Variant = dialog_items_data[idx] if idx < dialog_items_data.size() else null
		var fallback := str(choice_labels[idx]) if idx < choice_labels.size() else ""
		labels.append(selection_label_from_item(item, fallback))
	return labels


func selected_assignment_labels(assignments: Array[Dictionary]) -> Array[String]:
	var labels: Array[String] = []
	for assignment: Dictionary in assignments:
		var source_label := selection_label_from_item(assignment.get("source"))
		var target_label := selection_label_from_item(assignment.get("target"))
		if source_label != "" and target_label != "":
			labels.append("%s -> %s" % [source_label, target_label])
		elif source_label != "":
			labels.append(source_label)
		elif target_label != "":
			labels.append(target_label)
	return labels


func setup_dialog_card_view(scene: Object, card_view: BattleCardView, item: Variant, label: String) -> void:
	if item is CardInstance:
		card_view.setup_from_instance(item, BattleCardView.MODE_CHOICE)
		card_view.set_info(item.card_data.display_name(), dialog_choice_subtitle(scene, item, label))
	elif item is CardData:
		card_view.setup_from_card_data(item, BattleCardView.MODE_CHOICE)
		card_view.set_info(item.display_name(), dialog_choice_subtitle(scene, item, label))
	elif item is PokemonSlot:
		var slot: PokemonSlot = item
		card_view.setup_from_card_data(slot.get_card_data(), scene.call("_battle_card_mode_for_slot", slot))
		var top_card := slot.get_top_card()
		if top_card != null and card_view.has_method("set_card_foil_owner_index"):
			card_view.call("set_card_foil_owner_index", top_card.owner_index)
		card_view.set_badges()
		card_view.set_battle_status(scene.call("_build_battle_status", slot))
	else:
		card_view.setup_from_instance(null, BattleCardView.MODE_CHOICE)
		card_view.set_info(str(label), "")
	if scene.has_method("_sync_card_foil_effect_for_view"):
		scene.call("_sync_card_foil_effect_for_view", card_view)


func dialog_should_use_card_mode(items: Array, extra_data: Dictionary) -> bool:
	var presentation := str(extra_data.get("presentation", "auto"))
	if presentation == "cards":
		return true
	if presentation in ["list", "action_hud"]:
		return false
	var card_items: Array = extra_data.get("card_items", items)
	for item: Variant in card_items:
		if not dialog_item_has_card_visual(item):
			return false
	return not card_items.is_empty()


func dialog_should_use_library_search_board(scene: Object, _items: Array, extra_data: Dictionary) -> bool:
	var layout_mode := _library_search_layout_mode(scene)
	return str(extra_data.get("visible_scope", "")) == "own_full_deck" \
		and str(extra_data.get("presentation", "auto")) == "cards" \
		and str(extra_data.get("ui_mode", "")) != "card_assignment" \
		and (layout_mode == "landscape" or layout_mode == "portrait")


func _library_search_layout_mode(scene: Object) -> String:
	var layout_mode := str(scene.get("_active_battle_layout_mode"))
	if layout_mode != "":
		return layout_mode
	if scene.has_method("_is_portrait_battle_layout_active") and bool(scene.call("_is_portrait_battle_layout_active")):
		return "portrait"
	return ""


func _library_search_is_portrait(scene: Object) -> bool:
	return _library_search_layout_mode(scene) == "portrait"


func _library_search_selectable_count(scene: Object) -> int:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	if dialog_data.has("selectable_count"):
		return maxi(0, int(dialog_data.get("selectable_count", 0)))
	var card_indices: Array = dialog_data.get("card_indices", [])
	if not card_indices.is_empty():
		var count := 0
		for index_variant: Variant in card_indices:
			if int(index_variant) >= 0:
				count += 1
		return count
	var card_items: Array = dialog_data.get("card_items", scene.get("_dialog_items_data"))
	return card_items.size()


func _library_search_requires_explicit_empty_selection(scene: Object) -> bool:
	if str(scene.get("_pending_choice")) != "effect_interaction":
		return false
	var dialog_data: Dictionary = scene.get("_dialog_data")
	if bool(dialog_data.get("requires_explicit_empty_selection", false)):
		return int(dialog_data.get("min_select", 1)) <= 0 \
			and int(dialog_data.get("max_select", 1)) > 0
	if scene.get("_dialog_library_search_board_mode") != true:
		return false
	return str(dialog_data.get("visible_scope", "")) == "own_full_deck" \
		and int(dialog_data.get("min_select", 1)) <= 0 \
		and int(dialog_data.get("max_select", 1)) > 0 \
		and _library_search_selectable_count(scene) > 0


func _portrait_library_search_uses_cancel_slot_for_empty_selection(scene: Object) -> bool:
	return scene.get("_dialog_library_search_board_mode") == true \
		and _library_search_is_portrait(scene) \
		and _library_search_requires_explicit_empty_selection(scene)


func restore_library_search_board(scene: Object) -> void:
	_restore_dialog_buttons_parent(scene)
	var board := scene.get("_dialog_library_search_board") as Control
	if board != null:
		board.visible = false
	scene.set("_dialog_library_search_board_mode", false)


func _dialog_buttons_row(scene: Object) -> HBoxContainer:
	var dialog_confirm := scene.get("_dialog_confirm") as Button
	if dialog_confirm == null:
		return null
	return dialog_confirm.get_parent() as HBoxContainer


func _restore_dialog_buttons_parent(scene: Object) -> void:
	var buttons_row := _dialog_buttons_row(scene)
	if buttons_row == null:
		return
	var original_parent := scene.get("_dialog_buttons_original_parent") as Node
	var original_index := int(scene.get("_dialog_buttons_original_index"))
	if original_parent != null and is_instance_valid(original_parent) and buttons_row.get_parent() != original_parent:
		var current_parent := buttons_row.get_parent()
		if current_parent != null:
			current_parent.remove_child(buttons_row)
		buttons_row.owner = null
		original_parent.add_child(buttons_row)
		original_parent.move_child(buttons_row, clampi(original_index, 0, original_parent.get_child_count() - 1))
		var original_owner: Variant = buttons_row.get_meta("_library_search_original_owner", null)
		if original_owner is Node and is_instance_valid(original_owner) and (original_owner as Node).is_ancestor_of(buttons_row):
			buttons_row.owner = original_owner
		if buttons_row.has_meta("_library_search_original_owner"):
			buttons_row.remove_meta("_library_search_original_owner")
	scene.set("_dialog_buttons_original_parent", null)
	scene.set("_dialog_buttons_original_index", -1)


func _move_dialog_buttons_to_instruction_bar(scene: Object, target: HBoxContainer) -> void:
	var buttons_row := _dialog_buttons_row(scene)
	if buttons_row == null or target == null or buttons_row.get_parent() == target:
		return
	if scene.get("_dialog_buttons_original_parent") == null:
		scene.set("_dialog_buttons_original_parent", buttons_row.get_parent())
		scene.set("_dialog_buttons_original_index", buttons_row.get_index())
		buttons_row.set_meta("_library_search_original_owner", buttons_row.owner)
	var current_parent := buttons_row.get_parent()
	if current_parent != null:
		current_parent.remove_child(buttons_row)
	buttons_row.owner = null
	target.add_child(buttons_row)
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	buttons_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func reset_dialog_assignment_state(scene: Object) -> void:
	scene.set("_dialog_assignment_mode", false)
	scene.set("_dialog_assignment_selected_source_index", -1)
	_replace_dictionary_array(scene, "_dialog_assignment_assignments", [])
	var assignment_panel: VBoxContainer = scene.get("_dialog_assignment_panel")
	if assignment_panel != null:
		assignment_panel.visible = false
	var summary_label: Label = scene.get("_dialog_assignment_summary_lbl")
	if summary_label != null:
		summary_label.text = ""


func show_dialog(scene: Object, title: String, items: Array, extra_data: Dictionary = {}) -> void:
	var dialog_title: Label = scene.get("_dialog_title")
	var dialog_list: ItemList = scene.get("_dialog_list")
	var dialog_overlay: Panel = scene.get("_dialog_overlay")
	var dialog_cancel: Button = scene.get("_dialog_cancel")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	_prepare_dialog_action_input_guard(scene)
	dialog_title.text = title
	dialog_list.clear()
	if dialog_confirm != null:
		dialog_confirm.button_pressed = false
	if dialog_cancel != null:
		dialog_cancel.button_pressed = false
	restore_library_search_board(scene)
	scene.set("_dialog_items_data", items)
	scene.set("_dialog_data", extra_data)
	_replace_int_array(scene, "_dialog_multi_selected_indices", [])
	_replace_int_array(scene, "_dialog_card_selected_indices", [])
	reset_dialog_assignment_state(scene)

	var presentation := str(extra_data.get("presentation", "auto"))
	var assignment_mode := str(extra_data.get("ui_mode", "")) == "card_assignment"
	var action_hud_mode := presentation == "action_hud"
	var library_search_board_mode := false if assignment_mode or action_hud_mode else dialog_should_use_library_search_board(scene, items, extra_data)
	scene.set("_dialog_assignment_mode", assignment_mode)
	scene.set("_dialog_library_search_board_mode", library_search_board_mode)
	dialog_title.visible = not library_search_board_mode
	var card_mode := true if library_search_board_mode else (false if assignment_mode or action_hud_mode else dialog_should_use_card_mode(items, extra_data))
	scene.set("_dialog_card_mode", card_mode)

	if assignment_mode:
		show_assignment_dialog(scene, extra_data)
	elif action_hud_mode:
		show_action_hud_dialog(scene, items, extra_data)
	elif library_search_board_mode:
		show_library_search_board_dialog(scene, items, extra_data)
	elif card_mode:
		show_card_dialog(scene, items, extra_data)
	else:
		show_text_dialog(scene, items, extra_data)

	apply_dialog_surface_style(scene, bool(extra_data.get("transparent_battlefield_dialog", false)) or not (extra_data.get("card_groups", []) as Array).is_empty())
	style_dialog_footer_buttons(scene)
	if scene.has_method("_sync_portrait_modal_overlay_rects"):
		scene.call("_sync_portrait_modal_overlay_rects")
	if scene.has_method("_apply_portrait_popup_text_metrics"):
		scene.call("_apply_portrait_popup_text_metrics")
	dialog_overlay.modulate = Color(1, 1, 1, 0)
	dialog_overlay.visible = true
	if scene.has_method("_raise_dialog_overlay_for_input"):
		scene.call("_raise_dialog_overlay_for_input")
	if scene.has_method("_refresh_end_turn_hud_button_state"):
		scene.call("_refresh_end_turn_hud_button_state")
	var portrait_empty_action := _portrait_library_search_uses_cancel_slot_for_empty_selection(scene)
	dialog_cancel.text = "不选择" if portrait_empty_action else "取消"
	dialog_cancel.visible = portrait_empty_action or bool(extra_data.get("allow_cancel", true))
	update_dialog_confirm_state(scene)
	compact_dialog_box_to_content(scene)
	reveal_dialog_after_layout(scene, dialog_overlay)
	scene.call(
		"_runtime_log",
		"show_dialog",
		"title=%s mode=%s items=%d %s" % [
			title,
			"assignment" if assignment_mode else ("action_hud" if action_hud_mode else ("library_search_board" if library_search_board_mode else ("cards" if card_mode else "list"))),
			items.size(),
			scene.call("_dialog_state_snapshot"),
		]
	)
	scene.call("_record_battle_state_snapshot", "before_choice_context", {
		"prompt_source": "dialog",
		"prompt_type": str(extra_data.get("prompt_type", scene.get("_pending_choice"))),
		"title": title,
	})
	scene.call("_record_battle_event", {
		"event_type": "choice_context",
		"prompt_source": "dialog",
		"prompt_type": str(extra_data.get("prompt_type", scene.get("_pending_choice"))),
		"title": title,
		"items": items.duplicate(true),
		"extra_data": extra_data.duplicate(true),
		"player_index": int(extra_data.get("player", _current_player_index(scene))),
		"turn_number": _turn_number(scene),
		"phase": scene.call("_recording_phase_name"),
	})
	if scene.has_method("_sync_card_foil_effects"):
		scene.call("_sync_card_foil_effects", dialog_overlay)
	if not assignment_mode and int(extra_data.get("max_select", 1)) > 1:
		scene.call("_log", "已启用多选：先选择卡牌，再点击确认。")


func apply_dialog_surface_style(scene: Object, transparent: bool) -> void:
	var dialog_overlay := scene.get("_dialog_overlay") as Panel
	var dialog_box := scene.get("_dialog_box") as PanelContainer
	if dialog_overlay != null:
		var overlay_style := StyleBoxFlat.new()
		overlay_style.bg_color = Color(0.0, 0.0, 0.0, 0.0 if transparent else 0.70)
		dialog_overlay.add_theme_stylebox_override("panel", overlay_style)
	if dialog_box != null:
		dialog_box.add_theme_stylebox_override("panel", transparent_dialog_box_style() if transparent else default_dialog_box_style())


func default_dialog_box_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.11, 0.98)
	style.border_color = Color(0.38, 0.55, 0.72, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	return style


func transparent_dialog_box_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.035, 0.050, 0.94)
	style.border_color = Color(0.30, 0.64, 0.76, 0.82)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	return style


func compact_dialog_box_to_content(scene: Object) -> void:
	var dialog_box := scene.get("_dialog_box") as Control
	if dialog_box == null:
		return
	dialog_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dialog_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var parent := dialog_box.get_parent()
	var parent_control := parent as Control
	_normalize_dialog_center_rect(parent_control)
	_apply_dialog_box_size_and_position(scene, dialog_box, parent_control)
	if parent_control != null:
		_queue_dialog_box_center_lock(scene, dialog_box, parent_control)
	if parent is Container:
		(parent as Container).queue_sort()


func _apply_dialog_box_size_and_position(scene: Object, dialog_box: Control, parent_control: Control) -> void:
	if dialog_box == null:
		return
	_normalize_dialog_center_rect(parent_control)
	compact_visible_dialog_scroll(scene, "_dialog_card_scroll")
	compact_visible_dialog_scroll(scene, "_dialog_assignment_source_scroll")
	compact_visible_dialog_scroll(scene, "_dialog_assignment_target_scroll")
	var target_height := stable_dialog_box_content_height(scene, dialog_box)
	target_height = _clamp_dialog_box_height_to_parent(scene, dialog_box, parent_control, target_height)
	var minimum_size := dialog_box.custom_minimum_size
	minimum_size.y = target_height
	dialog_box.custom_minimum_size = minimum_size
	dialog_box.update_minimum_size()
	dialog_box.size = Vector2(dialog_box.size.x, target_height)
	var dialog_vbox := dialog_vbox_from_scene(scene, dialog_box)
	if dialog_vbox != null:
		var panel_minimum_y := 0.0
		var panel_style := dialog_box.get_theme_stylebox("panel")
		if panel_style != null:
			panel_minimum_y = panel_style.get_minimum_size().y
		dialog_vbox.size = Vector2(dialog_vbox.size.x, maxf(0.0, target_height - panel_minimum_y))
	if parent_control != null:
		_recenter_dialog_box_in_parent(dialog_box, parent_control)


func _clamp_dialog_box_height_to_parent(scene: Object, dialog_box: Control, parent: Control, target_height: float) -> float:
	var max_height := _dialog_box_max_visible_height(parent)
	if max_height <= 0.0 or target_height <= max_height:
		return target_height
	var overflow := target_height - max_height
	for property_name: String in ["_dialog_card_scroll", "_dialog_assignment_source_scroll", "_dialog_assignment_target_scroll"]:
		overflow = _shrink_visible_dialog_scroll(scene, property_name, overflow)
		if overflow <= 0.1:
			break
	var adjusted_height := stable_dialog_box_content_height(scene, dialog_box)
	return minf(adjusted_height, max_height)


func _dialog_box_max_visible_height(parent: Control) -> float:
	if parent == null or parent.size.y <= 0.0:
		return 0.0
	return maxf(parent.size.y - DIALOG_BOX_VISIBLE_VERTICAL_MARGIN * 2.0, 1.0)


func _shrink_visible_dialog_scroll(scene: Object, property_name: String, overflow: float) -> float:
	if overflow <= 0.0:
		return 0.0
	var scroll := scene.get(property_name) as Control
	if scroll == null or not scroll.visible:
		return overflow
	var minimum_size := scroll.custom_minimum_size
	if minimum_size.y <= DIALOG_SCROLL_MIN_VISIBLE_HEIGHT:
		return overflow
	var reduction := minf(overflow, minimum_size.y - DIALOG_SCROLL_MIN_VISIBLE_HEIGHT)
	minimum_size.y -= reduction
	scroll.custom_minimum_size = minimum_size
	scroll.size = Vector2(scroll.size.x, minimum_size.y)
	scroll.update_minimum_size()
	return overflow - reduction


func _queue_dialog_box_center_lock(scene: Object, dialog_box: Control, parent: Control) -> void:
	if dialog_box == null or parent == null:
		return
	var lock_id := int(dialog_box.get_meta("dialog_center_lock_id", 0)) + 1
	dialog_box.set_meta("dialog_center_lock_id", lock_id)
	_pending_dialog_center_locks[dialog_box.get_instance_id()] = {
		"scene": scene,
		"dialog_box": dialog_box,
		"parent": parent,
		"lock_id": lock_id,
	}
	var lock_callable := Callable(self, "_flush_queued_dialog_box_center_locks")
	if parent.has_signal("sort_children") and not parent.is_connected("sort_children", lock_callable):
		parent.connect("sort_children", lock_callable, CONNECT_ONE_SHOT)
	if dialog_box.is_inside_tree():
		var tree := dialog_box.get_tree()
		if not tree.process_frame.is_connected(lock_callable):
			tree.process_frame.connect(lock_callable, CONNECT_ONE_SHOT)


func _flush_queued_dialog_box_center_locks() -> void:
	var pending: Array = _pending_dialog_center_locks.values()
	_pending_dialog_center_locks.clear()
	for request_raw: Variant in pending:
		if not (request_raw is Dictionary):
			continue
		var request: Dictionary = request_raw
		var scene: Object = request.get("scene")
		var dialog_box: Control = request.get("dialog_box") as Control
		var parent: Control = request.get("parent") as Control
		if not is_instance_valid(scene) or not is_instance_valid(dialog_box) or not is_instance_valid(parent):
			continue
		if int(dialog_box.get_meta("dialog_center_lock_id", -1)) != int(request.get("lock_id", -1)):
			continue
		_apply_dialog_box_size_and_position(scene, dialog_box, parent)


func _normalize_dialog_center_rect(parent: Control) -> void:
	if parent == null or str(parent.name) != "DialogCenter":
		return
	var overlay := parent.get_parent() as Control
	if overlay == null or overlay.size.x <= 0.0 or overlay.size.y <= 0.0:
		return
	parent.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	parent.position = Vector2.ZERO
	parent.size = overlay.size
	if parent is Container:
		(parent as Container).queue_sort()


func _recenter_dialog_box_in_parent(dialog_box: Control, parent: Control) -> void:
	if dialog_box == null or parent == null:
		return
	var box_size := dialog_box.size
	var minimum_size := dialog_box.custom_minimum_size
	if box_size.x <= 0.0:
		box_size.x = minimum_size.x
	if box_size.y <= 0.0:
		box_size.y = minimum_size.y
	if parent.size.x <= 0.0 or parent.size.y <= 0.0:
		return
	dialog_box.position = Vector2(
		maxf(roundf((parent.size.x - box_size.x) * 0.5), 0.0),
		maxf(roundf((parent.size.y - box_size.y) * 0.5), 0.0)
	)


func reveal_dialog_after_layout(scene: Object, dialog_overlay: Control) -> void:
	var reveal_id := int(dialog_overlay.get_meta("dialog_reveal_id", 0)) + 1
	dialog_overlay.set_meta("dialog_reveal_id", reveal_id)
	if scene is Node:
		var scene_node := scene as Node
		if scene_node.is_inside_tree():
			var tree := scene_node.get_tree()
			_pending_dialog_reveals[dialog_overlay.get_instance_id()] = {
				"scene": scene,
				"dialog_overlay": dialog_overlay,
				"reveal_id": reveal_id,
			}
			var reveal_callable := Callable(self, "_flush_pending_dialog_reveals")
			if not tree.process_frame.is_connected(reveal_callable):
				tree.process_frame.connect(reveal_callable, CONNECT_ONE_SHOT)
			return
	dialog_overlay.call_deferred("set", "modulate", Color.WHITE)


func _flush_pending_dialog_reveals() -> void:
	var pending: Array = _pending_dialog_reveals.values()
	_pending_dialog_reveals.clear()
	for request_raw: Variant in pending:
		if not (request_raw is Dictionary):
			continue
		var request: Dictionary = request_raw
		var scene: Object = request.get("scene")
		var dialog_overlay: Control = request.get("dialog_overlay") as Control
		if not is_instance_valid(scene) or not is_instance_valid(dialog_overlay):
			continue
		if int(dialog_overlay.get_meta("dialog_reveal_id", -1)) != int(request.get("reveal_id", -1)):
			continue
		if not dialog_overlay.visible:
			continue
		compact_dialog_box_to_content(scene)
		dialog_overlay.modulate = Color.WHITE


func stable_dialog_box_content_height(scene: Object, dialog_box: Control) -> float:
	var dialog_vbox := dialog_vbox_from_scene(scene, dialog_box)
	if dialog_vbox == null:
		return 0.0
	var visible_count := 0
	var height := 0.0
	for child: Node in dialog_vbox.get_children():
		if not (child is Control):
			continue
		var control := child as Control
		if not control.visible:
			continue
		height += stable_dialog_child_height(control)
		visible_count += 1
	if visible_count > 1:
		height += float(dialog_vbox.get_theme_constant("separation")) * float(visible_count - 1)
	var panel_style := dialog_box.get_theme_stylebox("panel")
	if panel_style != null:
		height += panel_style.get_minimum_size().y
	return ceilf(height)


func stable_dialog_child_height(control: Control) -> float:
	if control is ScrollContainer and control.custom_minimum_size.y > 0.0:
		return control.custom_minimum_size.y
	return maxf(control.get_minimum_size().y, control.custom_minimum_size.y)


func dialog_vbox_from_scene(scene: Object, dialog_box: Control) -> VBoxContainer:
	var dialog_vbox := scene.get("_dialog_vbox") as VBoxContainer
	if dialog_vbox == null and dialog_box.get_child_count() > 0 and dialog_box.get_child(0) is VBoxContainer:
		dialog_vbox = dialog_box.get_child(0) as VBoxContainer
	return dialog_vbox


func compact_visible_dialog_scroll(scene: Object, property_name: String) -> void:
	var scroll := scene.get(property_name) as Control
	if scroll == null or not scroll.visible:
		return
	var scroll_minimum := scroll.custom_minimum_size
	if scroll_minimum.y <= 0.0:
		return
	scroll.size = Vector2(scroll.size.x, scroll_minimum.y)
	scroll.update_minimum_size()


func _is_portrait_text_dialog(scene: Object) -> bool:
	return scene != null \
		and scene.has_method("_is_portrait_popup_text_profile_active") \
		and bool(scene.call("_is_portrait_popup_text_profile_active"))


func _text_hud_option_size(scene: Object) -> Vector2:
	if not _is_portrait_text_dialog(scene):
		return TEXT_HUD_OPTION_SIZE
	var option_width := _portrait_text_hud_option_width(scene)
	return Vector2(option_width, PORTRAIT_TEXT_HUD_OPTION_HEIGHT)


func _portrait_text_hud_option_width(scene: Object) -> float:
	var dialog_box := scene.get("_dialog_box") as Control
	var box_width := 0.0
	if dialog_box != null:
		box_width = dialog_box.custom_minimum_size.x
	if box_width <= 0.0 and scene.has_method("_portrait_popup_content_size"):
		var content_size_variant: Variant = scene.call("_portrait_popup_content_size")
		if content_size_variant is Vector2:
			var content_size: Vector2 = content_size_variant
			box_width = content_size.x
	if box_width <= 0.0:
		return 320.0
	return maxf(box_width - PORTRAIT_TEXT_HUD_OPTION_HORIZONTAL_INSET, 1.0)


func _text_hud_scroll_height(scene: Object, action_count: int) -> float:
	if not _is_portrait_text_dialog(scene):
		return _action_hud_scroll_height(action_count)
	var visible_count: int = clampi(action_count, 1, 5)
	return float(visible_count) * PORTRAIT_TEXT_HUD_OPTION_HEIGHT + float(maxi(visible_count - 1, 0)) * 8.0 + 2.0


func show_text_dialog(scene: Object, items: Array, extra_data: Dictionary) -> void:
	var dialog_card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var dialog_assignment_panel: VBoxContainer = scene.get("_dialog_assignment_panel")
	var dialog_card_row: HBoxContainer = scene.get("_dialog_card_row")
	var dialog_status_lbl: Label = scene.get("_dialog_status_lbl")
	var dialog_utility_row: HBoxContainer = scene.get("_dialog_utility_row")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var dialog_list: ItemList = scene.get("_dialog_list")
	dialog_card_scroll.visible = true
	dialog_assignment_panel.visible = false
	dialog_status_lbl.visible = false
	dialog_utility_row.visible = false
	dialog_confirm.visible = int(extra_data.get("max_select", 1)) > 1 or int(extra_data.get("min_select", 1)) > 1
	dialog_list.visible = false
	dialog_list.custom_minimum_size = Vector2.ZERO
	dialog_card_scroll.scroll_horizontal = 0
	dialog_card_scroll.scroll_vertical = 0
	dialog_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if items.size() > 5 else ScrollContainer.SCROLL_MODE_DISABLED
	if scene.has_method("_set_card_gallery_drag_scroll_active"):
		scene.call("_set_card_gallery_drag_scroll_active", dialog_card_scroll, false)
	dialog_card_scroll.custom_minimum_size = Vector2(0, _text_hud_scroll_height(scene, items.size()))
	HudThemeScript.style_scroll_container(dialog_card_scroll, _dialog_scroll_profile(scene))
	scene.call("_clear_container_children", dialog_card_row)
	scene.call("_clear_container_children", dialog_utility_row)
	for item: Variant in items:
		dialog_list.add_item(str(item))
	dialog_list.select_mode = ItemList.SELECT_TOGGLE if int(extra_data.get("max_select", 1)) > 1 else ItemList.SELECT_SINGLE
	if dialog_list.item_selected.is_connected(Callable(scene, "_on_dialog_item_selected")):
		dialog_list.item_selected.disconnect(Callable(scene, "_on_dialog_item_selected"))
	if dialog_list.multi_selected.is_connected(Callable(scene, "_on_dialog_item_multi_selected")):
		dialog_list.multi_selected.disconnect(Callable(scene, "_on_dialog_item_multi_selected"))
	if dialog_list.select_mode != ItemList.SELECT_SINGLE:
		dialog_list.multi_selected.connect(Callable(scene, "_on_dialog_item_multi_selected"))
	else:
		dialog_list.item_selected.connect(Callable(scene, "_on_dialog_item_selected"))
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	dialog_card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_card_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dialog_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dialog_card_row.custom_minimum_size = Vector2.ZERO
	dialog_card_row.add_child(stack)
	for i: int in items.size():
		stack.add_child(_build_text_hud_option(scene, str(items[i]), i))
	sync_text_hud_selection(scene)


func style_dialog_footer_buttons(scene: Object) -> void:
	var dialog_cancel := scene.get("_dialog_cancel") as Button
	var dialog_confirm := scene.get("_dialog_confirm") as Button
	var buttons_row := dialog_confirm.get_parent() as HBoxContainer if dialog_confirm != null else null
	if buttons_row != null:
		buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
		buttons_row.size_flags_horizontal = Control.SIZE_SHRINK_END if _dialog_buttons_are_in_instruction_bar(scene, buttons_row) else Control.SIZE_EXPAND_FILL
		buttons_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buttons_row.add_theme_constant_override("separation", 12)
	if dialog_cancel != null:
		style_dialog_button(dialog_cancel, "secondary")
	if dialog_confirm != null:
		style_dialog_button(dialog_confirm, "primary")


func _dialog_buttons_are_in_instruction_bar(scene: Object, buttons_row: HBoxContainer) -> bool:
	var dialog_vbox := scene.get("_dialog_vbox") as VBoxContainer
	if dialog_vbox != null and buttons_row.get_parent() == dialog_vbox:
		return false
	var parent := buttons_row.get_parent()
	return parent != null and parent.name == "LibrarySearchButtonSlot"


func style_dialog_button(button: Button, role: String = "primary") -> void:
	if button == null:
		return
	var accent := Color(1.0, 0.62, 0.28, 1.0) if role == "primary" else Color(0.36, 0.86, 1.0, 1.0)
	if role == "danger":
		accent = Color(1.0, 0.38, 0.30, 1.0)
	button.custom_minimum_size = Vector2(maxf(button.custom_minimum_size.x, 172.0), maxf(button.custom_minimum_size.y, 56.0))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.55, 0.60, 1.0))
	button.add_theme_stylebox_override("normal", _dialog_button_style(accent, false, false))
	button.add_theme_stylebox_override("hover", _dialog_button_style(accent, true, false))
	button.add_theme_stylebox_override("pressed", _dialog_button_style(accent, true, true))
	button.add_theme_stylebox_override("disabled", _dialog_button_style(Color(0.28, 0.34, 0.40, 1.0), false, false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _dialog_button_style(accent: Color, hover: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.28) if pressed else Color(0.025, 0.075, 0.105, 0.95)
	if hover and not pressed:
		style.bg_color = Color(0.045, 0.13, 0.17, 0.98)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.28 if hover else 0.16)
	style.shadow_size = 10 if hover else 5
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _build_text_hud_option(scene: Object, label_text: String, option_index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var option_size := _text_hud_option_size(scene)
	panel.custom_minimum_size = option_size
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.set_meta("dialog_text_choice_index", option_index)
	panel.gui_input.connect(func(event: InputEvent) -> void:
		var activated := false
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
				activated = true
		elif event is InputEventScreenTouch:
			var touch_event := event as InputEventScreenTouch
			if touch_event.pressed:
				activated = true
		if activated:
			var origin_position := _input_event_screen_position(event)
			if _consume_direct_dialog_choice_if_stale(scene, "text_hud_option", origin_position):
				panel.accept_event()
				return
			on_text_hud_option_pressed(scene, option_index, origin_position)
			panel.accept_event()
	)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14 if _is_portrait_text_dialog(scene) else 9)
	margin.add_theme_constant_override("margin_bottom", 14 if _is_portrait_text_dialog(scene) else 9)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14 if _is_portrait_text_dialog(scene) else 12)
	margin.add_child(row)

	var index_label := Label.new()
	index_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	index_label.custom_minimum_size = Vector2(62, 62) if _is_portrait_text_dialog(scene) else Vector2(44, 42)
	index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	index_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	index_label.text = str(option_index + 1)
	index_label.add_theme_font_size_override("font_size", 18)
	index_label.add_theme_color_override("font_color", Color(0.04, 0.06, 0.08, 1.0))
	index_label.add_theme_stylebox_override("normal", _action_hud_pill_style(Color(0.36, 0.86, 1.0, 1.0), true))
	row.add_child(index_label)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = label_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	row.add_child(title)

	style_text_hud_option(panel, false)
	return panel


func on_text_hud_option_pressed(scene: Object, option_index: int, origin_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
	_record_dialog_fresh_input(scene, "text_hud_option", origin_position)
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var min_select := int(dialog_data.get("min_select", 1))
	var max_select := int(dialog_data.get("max_select", 1))
	var is_multi := max_select > 1 or min_select > 1
	if not is_multi:
		confirm_dialog_selection(scene, PackedInt32Array([option_index]), origin_position)
		return
	var selected_indices: Array = scene.get("_dialog_multi_selected_indices")
	if option_index in selected_indices:
		selected_indices.erase(option_index)
	elif max_select <= 0 or selected_indices.size() < max_select:
		selected_indices.append(option_index)
	_replace_int_array(scene, "_dialog_multi_selected_indices", selected_indices)
	sync_text_hud_selection(scene)
	update_dialog_confirm_state(scene)


func sync_text_hud_selection(scene: Object) -> void:
	var dialog_card_row := scene.get("_dialog_card_row") as HBoxContainer
	if dialog_card_row == null:
		return
	var selected_indices: Array = scene.get("_dialog_multi_selected_indices")
	for child: Node in dialog_card_row.get_children():
		_sync_text_hud_selection_recursive(child, selected_indices)


func _sync_text_hud_selection_recursive(node: Node, selected_indices: Array) -> void:
	if node is PanelContainer and node.has_meta("dialog_text_choice_index"):
		var panel := node as PanelContainer
		var idx := int(panel.get_meta("dialog_text_choice_index", -1))
		style_text_hud_option(panel, idx in selected_indices)
	for child: Node in node.get_children():
		_sync_text_hud_selection_recursive(child, selected_indices)


func style_text_hud_option(panel: PanelContainer, selected: bool) -> void:
	var accent := Color(1.0, 0.62, 0.28, 1.0) if selected else Color(0.36, 0.86, 1.0, 1.0)
	panel.add_theme_stylebox_override("panel", _action_hud_panel_style(accent, true))


func show_library_search_board_dialog(scene: Object, items: Array, extra_data: Dictionary) -> void:
	var dialog_list: ItemList = scene.get("_dialog_list")
	var dialog_card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var dialog_assignment_panel: VBoxContainer = scene.get("_dialog_assignment_panel")
	var dialog_utility_row: HBoxContainer = scene.get("_dialog_utility_row")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var dialog_status_lbl: Label = scene.get("_dialog_status_lbl")

	_cancel_card_gallery_drag_capture(scene, "show_library_search_board_dialog")
	if scene.has_method("_clear_hand_drag_click_suppression"):
		scene.call("_clear_hand_drag_click_suppression", "show_library_search_board_dialog")

	dialog_list.visible = false
	dialog_card_scroll.visible = false
	dialog_assignment_panel.visible = false
	dialog_utility_row.visible = false
	dialog_status_lbl.visible = false
	scene.call("_clear_container_children", dialog_utility_row)

	var board_nodes := ensure_library_search_board(scene)
	var board := board_nodes.get("board") as VBoxContainer
	var library_scroll := board_nodes.get("library_scroll") as ScrollContainer
	var library_row := board_nodes.get("library_row") as HBoxContainer
	var selected_scroll := board_nodes.get("selected_scroll") as ScrollContainer
	var selected_row := board_nodes.get("selected_row") as HBoxContainer
	var instruction_label := board_nodes.get("instruction_label") as Label
	var button_slot := board_nodes.get("button_slot") as HBoxContainer
	var portrait_source_panel := board_nodes.get("portrait_source_panel") as Control
	var portrait_source_holder := board_nodes.get("portrait_source_holder") as Control
	var portrait_source_caption := board_nodes.get("portrait_source_caption") as Label
	var source_panel := board_nodes.get("source_panel") as Control
	var source_holder := board_nodes.get("source_holder") as Control
	var source_caption := board_nodes.get("source_caption") as Label
	if board == null or library_scroll == null or library_row == null or selected_scroll == null or selected_row == null:
		show_card_dialog(scene, items, extra_data)
		return

	var portrait_layout := _library_search_is_portrait(scene)
	_apply_library_search_board_layout(scene, board_nodes)
	board.visible = true
	board.custom_minimum_size = Vector2(0, _library_search_board_height(scene))
	library_scroll.custom_minimum_size = Vector2(0, _library_search_library_scroll_height(scene))
	selected_scroll.custom_minimum_size = Vector2(0, _library_search_selected_scroll_height(scene))
	if portrait_source_panel != null:
		portrait_source_panel.custom_minimum_size = Vector2(0, _library_search_portrait_source_bar_height(scene))
	if source_panel != null and not portrait_layout:
		source_panel.custom_minimum_size = Vector2(_library_search_source_width(scene), 0)
	library_scroll.scroll_horizontal = 0
	library_scroll.scroll_vertical = 0
	selected_scroll.scroll_horizontal = 0
	selected_scroll.scroll_vertical = 0
	library_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	library_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	selected_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	selected_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HudThemeScript.style_scroll_container(library_scroll, _dialog_scroll_profile(scene))
	HudThemeScript.style_scroll_container(selected_scroll, _dialog_scroll_profile(scene))
	if scene.has_method("_set_card_gallery_drag_scroll_active"):
		scene.call("_set_card_gallery_drag_scroll_active", library_scroll, true)
		scene.call("_set_card_gallery_drag_scroll_active", selected_scroll, true)
	if scene.has_method("_configure_card_gallery_drag_scroll"):
		scene.call("_configure_card_gallery_drag_scroll", library_scroll, library_row, "library_search_candidates")
		scene.call("_configure_card_gallery_drag_scroll", selected_scroll, selected_row, "library_search_selected")
	_connect_library_search_scroll_tap_handler(scene, library_scroll, library_row)

	_populate_library_search_candidates(scene, library_scroll, library_row)
	_populate_library_search_source(scene, source_holder, source_caption)
	_populate_library_search_source(scene, portrait_source_holder, portrait_source_caption, _library_search_portrait_source_card_size(scene))
	if portrait_layout:
		_restore_dialog_buttons_parent(scene)
	else:
		_move_dialog_buttons_to_instruction_bar(scene, button_slot)
	_rebuild_library_search_empty_action_row(scene)
	dialog_confirm.visible = true
	if instruction_label != null:
		instruction_label.text = _library_search_instruction_text(scene)
	sync_library_search_board_selection(scene)
	update_dialog_confirm_state(scene)


func _apply_library_search_board_layout(scene: Object, board_nodes: Dictionary) -> void:
	var board := board_nodes.get("board") as VBoxContainer
	var source_panel := board_nodes.get("source_panel") as Control
	var button_slot := board_nodes.get("button_slot") as HBoxContainer
	var instruction_label := board_nodes.get("instruction_label") as Label
	var portrait_source_panel := board_nodes.get("portrait_source_panel") as Control
	var portrait_source_caption := board_nodes.get("portrait_source_caption") as Label
	var portrait_layout := _library_search_is_portrait(scene)
	var portrait_has_source := portrait_layout and _library_search_has_source(scene)
	if board == null:
		return
	board.set_meta("library_search_portrait_layout", portrait_layout)
	board.add_theme_constant_override("separation", 10 if portrait_layout else 8)

	var main_row := board.find_child("LibrarySearchMainRow", true, false) as HBoxContainer
	if main_row != null:
		main_row.add_theme_constant_override("separation", 0 if portrait_layout else 14)
	var left_column := board.find_child("LibrarySearchChoiceColumn", true, false) as VBoxContainer
	if left_column != null:
		left_column.add_theme_constant_override("separation", 10 if portrait_layout else 8)
	var library_row := board_nodes.get("library_row") as HBoxContainer
	if library_row != null:
		library_row.add_theme_constant_override("separation", 10 if portrait_layout else 12)
	var selected_row := board_nodes.get("selected_row") as HBoxContainer
	if selected_row != null:
		selected_row.add_theme_constant_override("separation", 10 if portrait_layout else 12)
	var instruction_panel := board.find_child("LibrarySearchInstructionBar", true, false) as Control
	if instruction_panel != null:
		instruction_panel.custom_minimum_size = Vector2(
			0,
			LIBRARY_SEARCH_PORTRAIT_COMMAND_BAR_HEIGHT if portrait_layout else LIBRARY_SEARCH_COMMAND_BAR_HEIGHT
		)
	var instruction_row := board.find_child("LibrarySearchInstructionContent", true, false) as HBoxContainer
	if instruction_row != null:
		instruction_row.add_theme_constant_override("separation", 0 if portrait_layout else 16)
	if instruction_label != null:
		instruction_label.add_theme_font_size_override("font_size", 27 if portrait_layout else 22)
		instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if portrait_source_panel != null:
		portrait_source_panel.visible = portrait_has_source
		portrait_source_panel.custom_minimum_size = Vector2(0, _library_search_portrait_source_bar_height(scene) if portrait_has_source else 0)
		portrait_source_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait_source_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if portrait_source_caption != null:
		portrait_source_caption.add_theme_font_size_override("font_size", 16)
	if button_slot != null:
		button_slot.visible = not portrait_layout
		button_slot.size_flags_horizontal = Control.SIZE_SHRINK_END
	if source_panel != null:
		source_panel.visible = not portrait_layout
		source_panel.custom_minimum_size = Vector2.ZERO if portrait_layout else Vector2(_library_search_source_width(scene), 0)
		source_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
		source_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if portrait_layout:
		_restore_dialog_buttons_parent(scene)
		var buttons_row := _dialog_buttons_row(scene)
		if buttons_row != null:
			buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
			buttons_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			buttons_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			buttons_row.add_theme_constant_override("separation", 12)


func ensure_library_search_board(scene: Object) -> Dictionary:
	var board := scene.get("_dialog_library_search_board") as VBoxContainer
	if board != null and is_instance_valid(board):
		return _library_search_board_nodes(board)
	var dialog_vbox := scene.get("_dialog_vbox") as VBoxContainer
	if dialog_vbox == null:
		return {}
	board = VBoxContainer.new()
	board.name = "LibrarySearchBoard"
	board.visible = false
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board.add_theme_constant_override("separation", 8)
	scene.set("_dialog_library_search_board", board)

	var main_row := HBoxContainer.new()
	main_row.name = "LibrarySearchMainRow"
	main_row.mouse_filter = Control.MOUSE_FILTER_STOP
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 14)
	board.add_child(main_row)

	var left_column := VBoxContainer.new()
	left_column.name = "LibrarySearchChoiceColumn"
	left_column.mouse_filter = Control.MOUSE_FILTER_STOP
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 8)
	main_row.add_child(left_column)

	var portrait_source_panel := PanelContainer.new()
	portrait_source_panel.name = "LibrarySearchPortraitSourcePanel"
	portrait_source_panel.visible = false
	portrait_source_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait_source_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_source_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_source_panel.custom_minimum_size = Vector2(0, LIBRARY_SEARCH_PORTRAIT_SOURCE_BAR_MIN_HEIGHT)
	portrait_source_panel.add_theme_stylebox_override("panel", _library_search_source_panel_style())
	left_column.add_child(portrait_source_panel)

	var portrait_source_margin := MarginContainer.new()
	portrait_source_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_source_margin.add_theme_constant_override("margin_left", 12)
	portrait_source_margin.add_theme_constant_override("margin_right", 12)
	portrait_source_margin.add_theme_constant_override("margin_top", 8)
	portrait_source_margin.add_theme_constant_override("margin_bottom", 8)
	portrait_source_panel.add_child(portrait_source_margin)

	var portrait_source_row := HBoxContainer.new()
	portrait_source_row.name = "LibrarySearchPortraitSourceContent"
	portrait_source_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_source_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_source_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_source_row.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait_source_row.add_theme_constant_override("separation", 14)
	portrait_source_margin.add_child(portrait_source_row)

	var portrait_source_holder := VBoxContainer.new()
	portrait_source_holder.name = "LibrarySearchPortraitSourceCardHolder"
	portrait_source_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait_source_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait_source_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_source_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait_source_row.add_child(portrait_source_holder)

	var portrait_source_text := VBoxContainer.new()
	portrait_source_text.name = "LibrarySearchPortraitSourceText"
	portrait_source_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_source_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_source_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_source_text.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait_source_text.add_theme_constant_override("separation", 4)
	portrait_source_row.add_child(portrait_source_text)

	var portrait_source_title := Label.new()
	portrait_source_title.name = "LibrarySearchPortraitSourceTitle"
	portrait_source_title.text = "当前使用"
	portrait_source_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	portrait_source_title.add_theme_font_size_override("font_size", 18)
	portrait_source_title.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0, 1.0))
	portrait_source_text.add_child(portrait_source_title)

	var portrait_source_caption := Label.new()
	portrait_source_caption.name = "LibrarySearchPortraitSourceCaption"
	portrait_source_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	portrait_source_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	portrait_source_caption.add_theme_font_size_override("font_size", 16)
	portrait_source_caption.add_theme_color_override("font_color", Color(0.72, 0.82, 0.90, 1.0))
	portrait_source_text.add_child(portrait_source_caption)

	var library_scroll := ScrollContainer.new()
	library_scroll.name = "LibrarySearchLibraryScroll"
	library_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	library_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	library_scroll.add_theme_stylebox_override("panel", _library_search_track_style())
	left_column.add_child(library_scroll)

	var library_row := HBoxContainer.new()
	library_row.name = "LibraryCardRow"
	library_row.mouse_filter = Control.MOUSE_FILTER_STOP
	library_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	library_row.alignment = BoxContainer.ALIGNMENT_CENTER
	library_row.add_theme_constant_override("separation", 12)
	library_scroll.add_child(library_row)

	var instruction_panel := PanelContainer.new()
	instruction_panel.name = "LibrarySearchInstructionBar"
	instruction_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	instruction_panel.custom_minimum_size = Vector2(0, LIBRARY_SEARCH_COMMAND_BAR_HEIGHT)
	instruction_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instruction_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	instruction_panel.add_theme_stylebox_override("panel", _library_search_instruction_style())
	left_column.add_child(instruction_panel)

	var instruction_margin := MarginContainer.new()
	instruction_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instruction_margin.add_theme_constant_override("margin_left", 18)
	instruction_margin.add_theme_constant_override("margin_right", 18)
	instruction_margin.add_theme_constant_override("margin_top", 8)
	instruction_margin.add_theme_constant_override("margin_bottom", 8)
	instruction_panel.add_child(instruction_margin)

	var instruction_row := HBoxContainer.new()
	instruction_row.name = "LibrarySearchInstructionContent"
	instruction_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instruction_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instruction_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	instruction_row.add_theme_constant_override("separation", 16)
	instruction_margin.add_child(instruction_row)

	var instruction_label := Label.new()
	instruction_label.name = "LibrarySearchInstructionLabel"
	instruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instruction_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instruction_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.add_theme_font_size_override("font_size", 22)
	instruction_label.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	instruction_row.add_child(instruction_label)

	var button_slot := HBoxContainer.new()
	button_slot.name = "LibrarySearchButtonSlot"
	button_slot.mouse_filter = Control.MOUSE_FILTER_STOP
	button_slot.size_flags_horizontal = Control.SIZE_SHRINK_END
	button_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	instruction_row.add_child(button_slot)

	var selected_scroll := ScrollContainer.new()
	selected_scroll.name = "LibrarySearchSelectedScroll"
	selected_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	selected_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	selected_scroll.add_theme_stylebox_override("panel", _library_search_track_style())
	left_column.add_child(selected_scroll)

	var selected_row := HBoxContainer.new()
	selected_row.name = "LibrarySelectedSlotRow"
	selected_row.mouse_filter = Control.MOUSE_FILTER_STOP
	selected_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	selected_row.alignment = BoxContainer.ALIGNMENT_CENTER
	selected_row.add_theme_constant_override("separation", 12)
	selected_scroll.add_child(selected_row)

	var source_panel := PanelContainer.new()
	source_panel.name = "LibrarySearchSourcePanel"
	source_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	source_panel.custom_minimum_size = Vector2(_library_search_source_width(scene), 0)
	source_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	source_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	source_panel.add_theme_stylebox_override("panel", _library_search_source_panel_style())
	main_row.add_child(source_panel)

	var source_margin := MarginContainer.new()
	source_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	source_margin.add_theme_constant_override("margin_left", 10)
	source_margin.add_theme_constant_override("margin_right", 10)
	source_margin.add_theme_constant_override("margin_top", 10)
	source_margin.add_theme_constant_override("margin_bottom", 10)
	source_panel.add_child(source_margin)

	var source_box := VBoxContainer.new()
	source_box.name = "LibrarySearchSourceBox"
	source_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	source_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	source_box.alignment = BoxContainer.ALIGNMENT_CENTER
	source_box.add_theme_constant_override("separation", 8)
	source_margin.add_child(source_box)

	var source_title := Label.new()
	source_title.name = "LibrarySearchSourceTitle"
	source_title.text = "当前使用"
	source_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	source_title.add_theme_font_size_override("font_size", 16)
	source_title.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0, 1.0))
	source_box.add_child(source_title)

	var source_holder := VBoxContainer.new()
	source_holder.name = "LibrarySearchSourceCardHolder"
	source_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	source_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	source_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	source_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	source_box.add_child(source_holder)

	var source_caption := Label.new()
	source_caption.name = "LibrarySearchSourceCaption"
	source_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	source_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_caption.add_theme_font_size_override("font_size", 14)
	source_caption.add_theme_color_override("font_color", Color(0.72, 0.82, 0.90, 1.0))
	source_box.add_child(source_caption)

	var insert_index := dialog_vbox.get_child_count()
	var dialog_card_scroll := scene.get("_dialog_card_scroll") as Control
	if dialog_card_scroll != null and dialog_card_scroll.get_parent() == dialog_vbox:
		insert_index = dialog_card_scroll.get_index()
	dialog_vbox.add_child(board)
	dialog_vbox.move_child(board, insert_index)
	return _library_search_board_nodes(board)


func _library_search_board_nodes(board: Node) -> Dictionary:
	return {
		"board": board,
		"library_scroll": board.find_child("LibrarySearchLibraryScroll", true, false),
		"library_row": board.find_child("LibraryCardRow", true, false),
		"selected_scroll": board.find_child("LibrarySearchSelectedScroll", true, false),
		"selected_row": board.find_child("LibrarySelectedSlotRow", true, false),
		"instruction_label": board.find_child("LibrarySearchInstructionLabel", true, false),
		"button_slot": board.find_child("LibrarySearchButtonSlot", true, false),
		"portrait_source_panel": board.find_child("LibrarySearchPortraitSourcePanel", true, false),
		"portrait_source_holder": board.find_child("LibrarySearchPortraitSourceCardHolder", true, false),
		"portrait_source_caption": board.find_child("LibrarySearchPortraitSourceCaption", true, false),
		"source_panel": board.find_child("LibrarySearchSourcePanel", true, false),
		"source_holder": board.find_child("LibrarySearchSourceCardHolder", true, false),
		"source_caption": board.find_child("LibrarySearchSourceCaption", true, false),
	}


func _populate_library_search_candidates(scene: Object, library_scroll: ScrollContainer, library_row: HBoxContainer) -> void:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var dialog_items_data: Array = scene.get("_dialog_items_data")
	var card_items: Array = dialog_data.get("card_items", dialog_items_data)
	var card_indices: Array = dialog_data.get("card_indices", [])
	var labels: Array = dialog_data.get("choice_labels", dialog_items_data)
	var card_click_selectable: bool = bool(dialog_data.get("card_click_selectable", true))
	var disabled_badge := str(dialog_data.get("card_disabled_badge", "不可选"))
	var card_size := _library_search_candidate_card_size(scene)
	scene.call("_clear_container_children", library_row)
	library_row.custom_minimum_size = Vector2(0, card_size.y)
	library_row.size = Vector2(library_row.size.x, card_size.y)
	for i: int in _visible_card_display_order(card_items, card_indices):
		var real_index := _library_search_real_index_for_display(i, card_indices)
		var disabled := real_index < 0
		var card_view := BattleCardViewScript.new()
		prepare_dialog_card_view(card_view, card_size)
		card_view.set_selected_badge_text("已选")
		card_view.set_clickable(card_click_selectable and not disabled)
		setup_dialog_card_view(scene, card_view, card_items[i], dialog_label_at(labels, i))
		if disabled:
			card_view.set_disabled(true)
			if disabled_badge != "":
				card_view.set_badges(disabled_badge, "")
		card_view.set_meta("dialog_choice_index", real_index)
		var slot := _build_library_search_candidate_slot(scene, library_scroll, card_view, real_index, card_click_selectable and not disabled)
		library_row.add_child(slot)


func _build_library_search_candidate_slot(
	scene: Object,
	library_scroll: ScrollContainer,
	card_view: BattleCardView,
	real_index: int,
	selectable: bool
) -> Control:
	var slot := Control.new()
	slot.name = "LibrarySearchCandidateSlot"
	slot.custom_minimum_size = card_view.custom_minimum_size
	slot.size = card_view.size
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.set_meta("library_search_candidate_slot", true)
	slot.set_meta("dialog_choice_index", real_index)
	slot.set_meta("library_search_press_active", false)
	slot.set_meta("library_search_press_cancelled", false)
	slot.set_meta("library_search_press_start", Vector2.ZERO)
	slot.set_meta("library_search_press_from_touch", false)

	card_view.set_clickable(false)
	card_view.position = Vector2.ZERO
	card_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_view.offset_left = 0.0
	card_view.offset_top = 0.0
	card_view.offset_right = 0.0
	card_view.offset_bottom = 0.0
	card_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.add_child(card_view)

	slot.gui_input.connect(func(event: InputEvent) -> void:
		_handle_library_search_candidate_slot_input(scene, library_scroll, slot, card_view, real_index, selectable, event)
	)
	return slot


func _connect_library_search_scroll_tap_handler(scene: Object, library_scroll: ScrollContainer, library_row: HBoxContainer) -> void:
	if library_scroll == null or library_row == null:
		return
	if bool(library_scroll.get_meta("library_search_scroll_tap_handler_connected", false)):
		return
	library_scroll.set_meta("library_search_scroll_tap_handler_connected", true)
	library_scroll.set_meta("library_search_press_active", false)
	library_scroll.set_meta("library_search_press_cancelled", false)
	library_scroll.set_meta("library_search_press_start", Vector2.ZERO)
	library_scroll.set_meta("library_search_press_candidate_index", -1)
	library_scroll.set_meta("library_search_press_from_touch", false)
	library_scroll.gui_input.connect(func(event: InputEvent) -> void:
		_handle_library_search_scroll_tap_input(scene, library_scroll, library_row, event)
	)


func try_handle_library_search_board_touch_input(scene: Object, event: InputEvent) -> bool:
	if not (
		event is InputEventScreenTouch
		or event is InputEventScreenDrag
		or event is InputEventMouseButton
		or event is InputEventMouseMotion
	):
		return false
	if scene == null or not bool(scene.get("_dialog_library_search_board_mode")):
		return false
	var board := scene.get("_dialog_library_search_board") as Control
	if board == null or not board.visible:
		return false
	var nodes := _library_search_board_nodes(board)
	var library_scroll := nodes.get("library_scroll", null) as ScrollContainer
	var library_row := nodes.get("library_row", null) as HBoxContainer
	var selected_scroll := nodes.get("selected_scroll", null) as ScrollContainer
	var selected_row := nodes.get("selected_row", null) as HBoxContainer
	if library_scroll == null or library_row == null:
		return false
	var position := _input_event_screen_position(event)
	var library_press_active := bool(library_scroll.get_meta("library_search_press_active", false))
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mouse_button.pressed:
			if _library_search_control_contains_input_position(scene, library_scroll, position):
				_handle_library_search_scroll_tap_input(scene, library_scroll, library_row, event)
				return true
			if _begin_library_search_selected_touch_if_hit(scene, selected_scroll, selected_row, position, false):
				_forward_library_search_candidate_drag_input(scene, selected_scroll, event)
				return true
			return false
		if library_press_active:
			_handle_library_search_scroll_tap_input(scene, library_scroll, library_row, event)
			return true
		if _end_library_search_selected_touch(scene, selected_scroll, selected_row, position, event):
			_forward_library_search_candidate_drag_input(scene, selected_scroll, event)
			return true
		return false
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		var left_pressed := (mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		if (library_press_active or _library_search_control_contains_input_position(scene, library_scroll, position)) and left_pressed:
			_handle_library_search_scroll_tap_input(scene, library_scroll, library_row, event)
			return true
		if _update_library_search_selected_touch(selected_scroll, position):
			_forward_library_search_candidate_drag_input(scene, selected_scroll, event)
			return true
		return false
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _library_search_control_contains_input_position(scene, library_scroll, position):
				_handle_library_search_scroll_tap_input(scene, library_scroll, library_row, event)
				return true
			if _begin_library_search_selected_touch_if_hit(scene, selected_scroll, selected_row, position, true):
				_forward_library_search_candidate_drag_input(scene, selected_scroll, event)
				return true
			return false
		if library_press_active:
			_handle_library_search_scroll_tap_input(scene, library_scroll, library_row, event)
			return true
		if _end_library_search_selected_touch(scene, selected_scroll, selected_row, position, event):
			_forward_library_search_candidate_drag_input(scene, selected_scroll, event)
			return true
		return false
	if event is InputEventScreenDrag:
		if library_press_active or _library_search_control_contains_input_position(scene, library_scroll, position):
			_handle_library_search_scroll_tap_input(scene, library_scroll, library_row, event)
			return true
		if _update_library_search_selected_touch(selected_scroll, position):
			_forward_library_search_candidate_drag_input(scene, selected_scroll, event)
			return true
	return false


func _handle_library_search_scroll_tap_input(
	scene: Object,
	library_scroll: ScrollContainer,
	library_row: HBoxContainer,
	event: InputEvent
) -> void:
	var drag_handled := _forward_library_search_candidate_drag_input(scene, library_scroll, event)
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			if drag_handled:
				library_scroll.accept_event()
			return
		if mouse_event.pressed:
			_begin_library_search_scroll_press(scene, library_scroll, library_row, mouse_event.global_position, false)
			return
		if _end_library_search_scroll_press(scene, library_scroll, library_row, mouse_event.global_position, event):
			library_scroll.accept_event()
			return
		if drag_handled:
			library_scroll.accept_event()
		return

	if event is InputEventMouseMotion:
		if bool(library_scroll.get_meta("library_search_press_active", false)):
			_update_library_search_candidate_press(library_scroll, (event as InputEventMouseMotion).global_position)
		if drag_handled or bool(library_scroll.get_meta("library_search_press_cancelled", false)):
			library_scroll.accept_event()
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_library_search_scroll_press(scene, library_scroll, library_row, touch.position, true)
			return
		var release_position := _library_search_touch_release_position(library_scroll, touch.position)
		if _end_library_search_scroll_press(scene, library_scroll, library_row, release_position, event):
			library_scroll.accept_event()
			return
		if drag_handled:
			library_scroll.accept_event()
		return

	if event is InputEventScreenDrag:
		if bool(library_scroll.get_meta("library_search_press_active", false)):
			_update_library_search_candidate_press(library_scroll, (event as InputEventScreenDrag).position)
		if drag_handled or bool(library_scroll.get_meta("library_search_press_cancelled", false)):
			library_scroll.accept_event()


func _begin_library_search_scroll_press(scene: Object, library_scroll: ScrollContainer, library_row: HBoxContainer, position: Vector2, from_touch: bool) -> void:
	_begin_library_search_candidate_press(library_scroll, position, from_touch)
	library_scroll.set_meta("library_search_press_candidate_index", _library_search_candidate_index_at_input_position(scene, library_row, position))


func _end_library_search_scroll_press(scene: Object, library_scroll: ScrollContainer, library_row: HBoxContainer, position: Vector2, event: InputEvent) -> bool:
	if not bool(library_scroll.get_meta("library_search_press_active", false)):
		return false
	_update_library_search_candidate_press(library_scroll, position)
	var cancelled := bool(library_scroll.get_meta("library_search_press_cancelled", false))
	var press_index := int(library_scroll.get_meta("library_search_press_candidate_index", -1))
	library_scroll.set_meta("library_search_press_active", false)
	library_scroll.set_meta("library_search_press_cancelled", false)
	library_scroll.set_meta("library_search_press_from_touch", false)
	library_scroll.set_meta("library_search_press_candidate_index", -1)
	if cancelled or press_index < 0:
		return true
	var release_index := _library_search_candidate_index_at_input_position(scene, library_row, position)
	if release_index != press_index:
		return true
	if _should_filter_card_gallery_primary_click(scene, event, library_scroll):
		return true
	on_library_search_candidate_pressed(scene, press_index)
	return true


func _library_search_candidate_index_at_position(library_row: HBoxContainer, position: Vector2) -> int:
	if library_row == null:
		return -1
	for child: Node in library_row.get_children():
		var slot := child as Control
		if slot == null or not _is_library_search_candidate_slot(slot):
			continue
		if not slot.get_global_rect().has_point(position):
			continue
		return int(slot.get_meta("dialog_choice_index", -1))
	return -1


func _is_library_search_candidate_slot(slot: Control) -> bool:
	return slot != null and (bool(slot.get_meta("library_search_candidate_slot", false)) or str(slot.name) == "LibrarySearchCandidateSlot")


func _library_search_candidate_index_at_input_position(scene: Object, library_row: HBoxContainer, position: Vector2) -> int:
	var raw_index := _library_search_candidate_index_at_position(library_row, position)
	if raw_index >= 0:
		return raw_index
	var converted := _library_search_convert_input_position(scene, position)
	if converted == position:
		return -1
	return _library_search_candidate_index_at_position(library_row, converted)


func _library_search_convert_input_position(scene: Object, position: Vector2) -> Vector2:
	if scene == null or not scene.has_method("_screen_position_to_battle_local"):
		return position
	var converted_variant: Variant = scene.call("_screen_position_to_battle_local", position)
	if not (converted_variant is Vector2):
		return position
	return converted_variant as Vector2


func _library_search_control_contains_input_position(scene: Object, control: Control, position: Vector2) -> bool:
	if control == null or not control.visible:
		return false
	var raw_rect := control.get_global_rect()
	if raw_rect.size != Vector2.ZERO and raw_rect.has_point(position):
		return true
	var converted := _library_search_convert_input_position(scene, position)
	if converted == position:
		return false
	return raw_rect.size != Vector2.ZERO and raw_rect.has_point(converted)


func _begin_library_search_selected_touch_if_hit(
	scene: Object,
	selected_scroll: ScrollContainer,
	selected_row: HBoxContainer,
	position: Vector2,
	from_touch: bool
) -> bool:
	if selected_scroll == null or selected_row == null:
		return false
	if not _library_search_control_contains_input_position(scene, selected_scroll, position):
		return false
	var real_index := _library_search_selected_real_index_at_input_position(scene, selected_row, position)
	if real_index < 0:
		return false
	_begin_library_search_candidate_press(selected_scroll, position, from_touch)
	selected_scroll.set_meta("library_search_selected_press_real_index", real_index)
	return true


func _update_library_search_selected_touch(selected_scroll: ScrollContainer, position: Vector2) -> bool:
	if selected_scroll == null or not bool(selected_scroll.get_meta("library_search_press_active", false)):
		return false
	_update_library_search_candidate_press(selected_scroll, position)
	return true


func _end_library_search_selected_touch(
	scene: Object,
	selected_scroll: ScrollContainer,
	selected_row: HBoxContainer,
	position: Vector2,
	event: InputEvent
) -> bool:
	if selected_scroll == null or selected_row == null:
		return false
	if not bool(selected_scroll.get_meta("library_search_press_active", false)):
		return false
	_update_library_search_candidate_press(selected_scroll, position)
	var cancelled := bool(selected_scroll.get_meta("library_search_press_cancelled", false))
	var press_real_index := int(selected_scroll.get_meta("library_search_selected_press_real_index", -1))
	selected_scroll.set_meta("library_search_press_active", false)
	selected_scroll.set_meta("library_search_press_cancelled", false)
	selected_scroll.set_meta("library_search_press_from_touch", false)
	selected_scroll.set_meta("library_search_selected_press_real_index", -1)
	if cancelled or press_real_index < 0:
		return true
	var release_real_index := _library_search_selected_real_index_at_input_position(scene, selected_row, position)
	if release_real_index != press_real_index:
		return true
	if _should_filter_card_gallery_primary_click(scene, event, selected_scroll):
		return true
	on_library_selected_slot_pressed(scene, press_real_index)
	return true


func _library_search_selected_real_index_at_input_position(scene: Object, selected_row: HBoxContainer, position: Vector2) -> int:
	var raw_index := _library_search_selected_real_index_at_position(selected_row, position)
	if raw_index >= 0:
		return raw_index
	var converted := _library_search_convert_input_position(scene, position)
	if converted == position:
		return -1
	return _library_search_selected_real_index_at_position(selected_row, converted)


func _library_search_selected_real_index_at_position(selected_row: HBoxContainer, position: Vector2) -> int:
	if selected_row == null:
		return -1
	for child: Node in selected_row.get_children():
		var control := child as Control
		if control == null:
			continue
		if not control.get_global_rect().has_point(position):
			continue
		if control.has_meta("library_selected_real_index"):
			return int(control.get_meta("library_selected_real_index", -1))
		for nested: Node in control.get_children():
			var nested_control := nested as Control
			if nested_control != null and nested_control.has_meta("library_selected_real_index") and nested_control.get_global_rect().has_point(position):
				return int(nested_control.get_meta("library_selected_real_index", -1))
	return -1


func _handle_library_search_candidate_slot_input(
	scene: Object,
	library_scroll: ScrollContainer,
	slot: Control,
	card_view: BattleCardView,
	real_index: int,
	selectable: bool,
	event: InputEvent
) -> void:
	var drag_handled := _forward_library_search_candidate_drag_input(scene, library_scroll, event)
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			if scene.has_method("_on_dialog_card_right_signal"):
				scene.call("_on_dialog_card_right_signal", card_view.card_instance, card_view.card_data)
			slot.accept_event()
			return
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			if drag_handled:
				slot.accept_event()
			return
		if mouse_event.pressed:
			_begin_library_search_candidate_press(slot, mouse_event.global_position, false)
			slot.accept_event()
			return
		if _end_library_search_candidate_press(scene, slot, mouse_event.global_position, real_index, selectable, event, library_scroll):
			slot.accept_event()
			return
		if drag_handled:
			slot.accept_event()
		return

	if event is InputEventMouseMotion:
		if bool(slot.get_meta("library_search_press_active", false)):
			_update_library_search_candidate_press(slot, (event as InputEventMouseMotion).global_position)
		if drag_handled or bool(slot.get_meta("library_search_press_cancelled", false)):
			slot.accept_event()
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_library_search_candidate_press(slot, touch.position, true)
			slot.accept_event()
			return
		var release_position := _library_search_touch_release_position(slot, touch.position)
		if _end_library_search_candidate_press(scene, slot, release_position, real_index, selectable, event, library_scroll):
			slot.accept_event()
			return
		if drag_handled:
			slot.accept_event()
		return

	if event is InputEventScreenDrag:
		if bool(slot.get_meta("library_search_press_active", false)):
			_update_library_search_candidate_press(slot, (event as InputEventScreenDrag).position)
		if drag_handled or bool(slot.get_meta("library_search_press_cancelled", false)):
			slot.accept_event()


func _forward_library_search_candidate_drag_input(scene: Object, library_scroll: ScrollContainer, event: InputEvent) -> bool:
	if scene == null or library_scroll == null:
		return false
	if scene.has_method("_handle_card_gallery_drag_scroll_input"):
		return bool(scene.call("_handle_card_gallery_drag_scroll_input", event, library_scroll, "library_search_candidates"))
	if scene.has_method("_on_card_gallery_card_input"):
		scene.call("_on_card_gallery_card_input", event, library_scroll, "library_search_candidates")
	return false


func _begin_library_search_candidate_press(slot: Control, position: Vector2, from_touch: bool) -> void:
	slot.set_meta("library_search_press_active", true)
	slot.set_meta("library_search_press_cancelled", false)
	slot.set_meta("library_search_press_start", position)
	slot.set_meta("library_search_press_from_touch", from_touch)


func _update_library_search_candidate_press(slot: Control, position: Vector2) -> void:
	var start_variant: Variant = slot.get_meta("library_search_press_start", Vector2.ZERO)
	var start: Vector2 = start_variant if start_variant is Vector2 else Vector2.ZERO
	var delta: Vector2 = position - start
	var from_touch := bool(slot.get_meta("library_search_press_from_touch", false))
	var horizontal_tolerance := (
		PointerGesturePolicyScript.touch_horizontal_tap_tolerance()
		if from_touch
		else PointerGesturePolicyScript.MOUSE_HORIZONTAL_TAP_TOLERANCE
	)
	var vertical_tolerance := (
		PointerGesturePolicyScript.touch_vertical_tap_tolerance()
		if from_touch
		else LIBRARY_SEARCH_CANDIDATE_VERTICAL_CLICK_TOLERANCE
	)
	if absf(delta.x) > horizontal_tolerance or absf(delta.y) > vertical_tolerance:
		slot.set_meta("library_search_press_cancelled", true)


func _end_library_search_candidate_press(scene: Object, slot: Control, position: Vector2, real_index: int, selectable: bool, event: InputEvent, library_scroll: ScrollContainer) -> bool:
	if not bool(slot.get_meta("library_search_press_active", false)):
		return false
	_update_library_search_candidate_press(slot, position)
	var cancelled := bool(slot.get_meta("library_search_press_cancelled", false))
	slot.set_meta("library_search_press_active", false)
	slot.set_meta("library_search_press_cancelled", false)
	slot.set_meta("library_search_press_from_touch", false)
	if cancelled:
		return true
	if not selectable:
		return true
	if _should_filter_card_gallery_primary_click(scene, event, library_scroll):
		return true
	on_library_search_candidate_pressed(scene, real_index)
	return true


func _library_search_touch_release_position(slot: Control, position: Vector2) -> Vector2:
	if position != Vector2.ZERO:
		return position
	var start_variant: Variant = slot.get_meta("library_search_press_start", Vector2.ZERO)
	return start_variant if start_variant is Vector2 else Vector2.ZERO


func _populate_library_search_source(scene: Object, source_holder: Control, source_caption: Label, card_size: Vector2 = Vector2.ZERO) -> void:
	if source_holder == null:
		return
	scene.call("_clear_container_children", source_holder)
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var source: Variant = dialog_data.get("source_card", null)
	var source_kind := str(dialog_data.get("source_kind", "")).strip_edges()
	if source is CardInstance or source is CardData:
		var card_view := BattleCardViewScript.new()
		var source_card_size := card_size if card_size != Vector2.ZERO else _library_search_source_card_size(scene)
		prepare_dialog_card_view(card_view, source_card_size)
		card_view.set_clickable(true)
		setup_dialog_card_view(scene, card_view, source, "")
		card_view.left_clicked.connect(func(card_instance: CardInstance, card_data: CardData) -> void:
			scene.call("_on_dialog_card_right_signal", card_instance, card_data)
		)
		card_view.right_clicked.connect(Callable(scene, "_on_dialog_card_right_signal"))
		source_holder.add_child(card_view)
		if source_caption != null:
			source_caption.text = _library_search_source_caption(source, source_kind)
		return
	var placeholder := Label.new()
	placeholder.text = "本次效果"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.custom_minimum_size = Vector2(120, 160)
	placeholder.add_theme_font_size_override("font_size", 18)
	placeholder.add_theme_color_override("font_color", Color(0.64, 0.74, 0.82, 1.0))
	source_holder.add_child(placeholder)
	if source_caption != null:
		source_caption.text = "来源未显示"


func _should_filter_card_gallery_primary_click(scene: Object, event: InputEvent, scroll: ScrollContainer) -> bool:
	return (
		scene != null
		and scene.has_method("_should_filter_card_gallery_primary_click")
		and bool(scene.call("_should_filter_card_gallery_primary_click", event, scroll))
	)


func on_library_search_candidate_pressed(scene: Object, real_index: int) -> void:
	_record_dialog_fresh_input(scene, "library_search_candidate")
	if real_index < 0:
		return
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var max_select := int(dialog_data.get("max_select", 1))
	if max_select == 0:
		return
	var selected_indices: Array = scene.get("_dialog_card_selected_indices")
	if max_select == 1:
		if real_index in selected_indices:
			selected_indices.clear()
		else:
			selected_indices.clear()
			selected_indices.append(real_index)
	else:
		if real_index in selected_indices:
			selected_indices.erase(real_index)
		elif max_select < 0 or selected_indices.size() < max_select:
			selected_indices.append(real_index)
	_replace_int_array(scene, "_dialog_card_selected_indices", selected_indices)
	sync_library_search_board_selection(scene)
	update_dialog_confirm_state(scene)


func on_library_selected_slot_pressed(scene: Object, real_index: int) -> void:
	_record_dialog_fresh_input(scene, "library_search_selected_slot")
	var selected_indices: Array = scene.get("_dialog_card_selected_indices")
	selected_indices.erase(real_index)
	_replace_int_array(scene, "_dialog_card_selected_indices", selected_indices)
	sync_library_search_board_selection(scene)
	update_dialog_confirm_state(scene)


func sync_library_search_board_selection(scene: Object) -> void:
	var board := scene.get("_dialog_library_search_board") as Control
	if board == null or not board.visible:
		return
	var selected_indices: Array = scene.get("_dialog_card_selected_indices")
	var library_row := board.find_child("LibraryCardRow", true, false) as HBoxContainer
	if library_row != null:
		_sync_library_search_candidate_selection_recursive(library_row, selected_indices)
	var selected_row := board.find_child("LibrarySelectedSlotRow", true, false) as HBoxContainer
	if selected_row != null:
		_rebuild_library_search_selected_slots(scene, selected_row)
	var instruction_label := board.find_child("LibrarySearchInstructionLabel", true, false) as Label
	if instruction_label != null:
		instruction_label.text = _library_search_instruction_text(scene)


func _sync_library_search_candidate_selection_recursive(node: Node, selected_indices: Array) -> void:
	if node is BattleCardView:
		var card_view := node as BattleCardView
		var idx := int(card_view.get_meta("dialog_choice_index", -1))
		card_view.set_selected(idx >= 0 and idx in selected_indices)
	for child: Node in node.get_children():
		_sync_library_search_candidate_selection_recursive(child, selected_indices)


func _rebuild_library_search_selected_slots(scene: Object, selected_row: HBoxContainer) -> void:
	scene.call("_clear_container_children", selected_row)
	var selected_indices: Array = scene.get("_dialog_card_selected_indices")
	var card_size := _library_search_selected_card_size(scene)
	selected_row.custom_minimum_size = Vector2(0, card_size.y)
	selected_row.size = Vector2(selected_row.size.x, card_size.y)
	var slot_count := _library_search_selected_slot_count(scene, selected_indices.size())
	var rendered_count := 0
	for real_index: int in selected_indices:
		var item: Variant = _library_search_card_for_real_index(scene, real_index)
		if item == null:
			continue
		var bound_real_index := real_index
		var card_view := BattleCardViewScript.new()
		prepare_dialog_card_view(card_view, card_size)
		card_view.set_selected_badge_text("移除")
		card_view.set_selected(true)
		card_view.set_clickable(true)
		setup_dialog_card_view(scene, card_view, item, "")
		card_view.set_meta("library_selected_real_index", bound_real_index)
		card_view.left_clicked.connect(func(_card_instance: CardInstance, _card_data: CardData) -> void:
			on_library_selected_slot_pressed(scene, bound_real_index)
		)
		card_view.right_clicked.connect(Callable(scene, "_on_dialog_card_right_signal"))
		selected_row.add_child(card_view)
		rendered_count += 1
	while rendered_count < slot_count:
		selected_row.add_child(_build_library_search_empty_slot(scene, rendered_count))
		rendered_count += 1


func _library_search_selected_slot_count(scene: Object, selected_count: int) -> int:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var max_select := int(dialog_data.get("max_select", 1))
	if max_select > 0:
		return maxi(max_select, selected_count)
	if max_select < 0:
		return selected_count + 1
	return selected_count


func _build_library_search_empty_slot(scene: Object, slot_index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "LibrarySearchEmptySlot"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = _library_search_selected_card_size(scene)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.set_meta("library_search_empty_slot", true)
	panel.set_meta("library_search_slot_index", slot_index)
	panel.add_theme_stylebox_override("panel", _library_search_empty_slot_style())
	var label := Label.new()
	label.text = _library_search_empty_slot_text(scene, slot_index)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var font_size := _library_search_empty_slot_font_size(scene)
	label.add_theme_font_size_override("font_size", font_size)
	label.set_meta("library_search_empty_slot_font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.68, 0.78, 0.86, 1.0))
	panel.add_child(label)
	return panel


func _library_search_empty_slot_font_size(scene: Object) -> int:
	var board: Control = null
	if scene != null:
		board = scene.get("_dialog_library_search_board") as Control
	if board != null and bool(board.get_meta("library_search_portrait_layout", false)):
		return LIBRARY_SEARCH_PORTRAIT_EMPTY_SLOT_FONT_SIZE
	return LIBRARY_SEARCH_PORTRAIT_EMPTY_SLOT_FONT_SIZE if _library_search_is_portrait(scene) else 16


func _library_search_real_index_for_display(display_index: int, card_indices: Array) -> int:
	if display_index >= 0 and display_index < card_indices.size():
		return int(card_indices[display_index])
	return display_index


func _library_search_card_for_real_index(scene: Object, real_index: int) -> Variant:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var dialog_items_data: Array = scene.get("_dialog_items_data")
	var card_items: Array = dialog_data.get("card_items", dialog_items_data)
	var card_indices: Array = dialog_data.get("card_indices", [])
	for display_index: int in card_items.size():
		if _library_search_real_index_for_display(display_index, card_indices) == real_index:
			return card_items[display_index]
	if real_index >= 0 and real_index < card_items.size():
		return card_items[real_index]
	return null


func _library_search_instruction_text(scene: Object) -> String:
	var title := ""
	var dialog_title := scene.get("_dialog_title") as Label
	if dialog_title != null:
		title = dialog_title.text.strip_edges()
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var selected_count := int((scene.get("_dialog_card_selected_indices") as Array).size())
	var min_select := int(dialog_data.get("min_select", 1))
	var max_select := int(dialog_data.get("max_select", 1))
	var count_text := ""
	if max_select <= 0:
		count_text = "无需选择"
	elif min_select <= 0:
		count_text = "已选 %d/%d，可不选择" % [selected_count, max_select]
	elif max_select == 1:
		count_text = "已选 %d/1" % selected_count
	else:
		count_text = "已选 %d/%d，至少 %d" % [selected_count, max_select, min_select]
	if title == "":
		return count_text
	return "%s\n%s；点击下方已选卡可移除" % [title, count_text]


func _library_search_empty_slot_text(scene: Object, slot_index: int) -> String:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var min_select := int(dialog_data.get("min_select", 1))
	return "选择后显示" if slot_index < min_select else "可不选择"


func _library_search_source_caption(source: Variant, source_kind: String) -> String:
	if source_kind != "":
		return source_kind
	if source is CardInstance and (source as CardInstance).card_data != null:
		return str((source as CardInstance).card_data.card_type)
	if source is CardData:
		return str((source as CardData).card_type)
	return "当前使用"


func _library_search_board_height(scene: Object) -> float:
	var content_height := _library_search_board_content_height(scene)
	if _library_search_is_portrait(scene):
		return content_height
	if scene is Node and (scene as Node).is_inside_tree():
		var viewport_size := (scene as Node).get_viewport().get_visible_rect().size
		var extra_height := clampf(
			viewport_size.y * LIBRARY_SEARCH_BOARD_EXTRA_HEIGHT_RATIO,
			LIBRARY_SEARCH_BOARD_EXTRA_HEIGHT_MIN,
			LIBRARY_SEARCH_BOARD_EXTRA_HEIGHT_MAX
		)
		return minf(content_height + extra_height, maxf(viewport_size.y - 40.0, content_height))
	return content_height + LIBRARY_SEARCH_BOARD_EXTRA_HEIGHT_MIN


func _library_search_board_content_height(scene: Object) -> float:
	if _library_search_is_portrait(scene):
		var source_height := _library_search_portrait_source_bar_height(scene) if _library_search_has_source(scene) else 0.0
		var source_gap := 10.0 if source_height > 0.0 else 0.0
		return source_height \
			+ source_gap \
			+ _library_search_library_scroll_height(scene) \
			+ LIBRARY_SEARCH_PORTRAIT_COMMAND_BAR_HEIGHT \
			+ _library_search_selected_scroll_height(scene) \
			+ 20.0
	return _library_search_library_scroll_height(scene) \
		+ LIBRARY_SEARCH_COMMAND_BAR_HEIGHT \
		+ _library_search_selected_scroll_height(scene) \
		+ 16.0


func _library_search_library_scroll_height(scene: Object) -> float:
	return _library_search_candidate_card_size(scene).y + (20.0 if _library_search_is_portrait(scene) else 28.0)


func _library_search_selected_scroll_height(scene: Object) -> float:
	return _library_search_selected_card_size(scene).y + (18.0 if _library_search_is_portrait(scene) else 26.0)


func _library_search_candidate_card_size(scene: Object) -> Vector2:
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	if _library_search_is_portrait(scene):
		return dialog_card_size
	return Vector2(minf(dialog_card_size.x, 126.0), minf(dialog_card_size.y, 176.0))


func _library_search_selected_card_size(scene: Object) -> Vector2:
	var candidate := _library_search_candidate_card_size(scene)
	var scale := LIBRARY_SEARCH_PORTRAIT_SELECTED_SCALE if _library_search_is_portrait(scene) else 0.86
	return Vector2(roundf(candidate.x * scale), roundf(candidate.y * scale))


func _library_search_source_card_size(scene: Object) -> Vector2:
	var candidate := _library_search_candidate_card_size(scene)
	var source_width := _library_search_source_width(scene)
	var source_card_width := minf(candidate.x * 1.32, maxf(source_width - 44.0, candidate.x))
	var card_ratio := candidate.y / maxf(candidate.x, 1.0)
	return Vector2(roundf(source_card_width), roundf(source_card_width * card_ratio))


func _library_search_portrait_source_card_size(scene: Object) -> Vector2:
	var candidate := _library_search_candidate_card_size(scene)
	return Vector2(
		roundf(candidate.x * LIBRARY_SEARCH_PORTRAIT_SOURCE_CARD_SCALE),
		roundf(candidate.y * LIBRARY_SEARCH_PORTRAIT_SOURCE_CARD_SCALE)
	)


func _library_search_portrait_source_bar_height(scene: Object) -> float:
	return maxf(LIBRARY_SEARCH_PORTRAIT_SOURCE_BAR_MIN_HEIGHT, _library_search_portrait_source_card_size(scene).y + 18.0)


func _library_search_has_source(scene: Object) -> bool:
	if scene == null:
		return false
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var source: Variant = dialog_data.get("source_card", null)
	return source is CardInstance or source is CardData


func _library_search_source_width(scene: Object) -> float:
	if scene is Node and (scene as Node).is_inside_tree():
		var viewport_size := (scene as Node).get_viewport().get_visible_rect().size
		return clampf(viewport_size.x * 0.13, LIBRARY_SEARCH_SOURCE_WIDTH_MIN, LIBRARY_SEARCH_SOURCE_WIDTH_MAX)
	return LIBRARY_SEARCH_SOURCE_WIDTH_MIN


func _library_search_track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.035, 0.050, 0.74)
	style.border_color = Color(0.22, 0.38, 0.50, 0.70)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _library_search_instruction_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.42, 0.68, 0.96)
	style.border_color = Color(0.86, 0.70, 0.25, 1.0)
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _library_search_source_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.065, 0.92)
	style.border_color = Color(0.34, 0.48, 0.60, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	return style


func _library_search_empty_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.13, 0.62)
	style.border_color = Color(0.45, 0.55, 0.62, 0.75)
	style.set_border_width_all(2)
	style.border_blend = true
	style.set_corner_radius_all(10)
	return style


func show_card_dialog(scene: Object, items: Array, extra_data: Dictionary) -> void:
	var dialog_list: ItemList = scene.get("_dialog_list")
	var dialog_card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var dialog_assignment_panel: VBoxContainer = scene.get("_dialog_assignment_panel")
	var dialog_utility_row: HBoxContainer = scene.get("_dialog_utility_row")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var dialog_status_lbl: Label = scene.get("_dialog_status_lbl")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")

	_cancel_card_gallery_drag_capture(scene, "show_card_dialog")
	_set_assignment_gallery_lanes_active(scene, false)
	if scene.has_method("_clear_hand_drag_click_suppression"):
		scene.call("_clear_hand_drag_click_suppression", "show_card_dialog")

	dialog_list.visible = false
	dialog_card_scroll.visible = false
	dialog_assignment_panel.visible = false
	dialog_card_scroll.scroll_horizontal = 0
	scene.set("_dialog_card_page_size", 0)
	scene.set("_dialog_card_page", 0)
	dialog_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	dialog_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var show_visible_scrollbar := _card_dialog_uses_visible_scrollbar(scene)
	dialog_card_scroll.set_meta("card_gallery_drag_keep_scrollbars_visible", show_visible_scrollbar)
	if scene.has_method("_set_card_gallery_drag_scroll_active"):
		scene.call("_set_card_gallery_drag_scroll_active", dialog_card_scroll, true)
	dialog_card_scroll.custom_minimum_size = Vector2(0, _card_dialog_scroll_height(dialog_card_size, scene))
	HudThemeScript.style_scroll_container(dialog_card_scroll, _dialog_scroll_profile(scene))
	if show_visible_scrollbar:
		if scene.has_method("_restore_card_gallery_scrollbars_for"):
			scene.call("_restore_card_gallery_scrollbars_for", dialog_card_scroll)
	elif scene.has_method("_hide_card_gallery_scrollbars_for"):
		scene.call("_hide_card_gallery_scrollbars_for", dialog_card_scroll)
	var recreated_card_row := recreate_dialog_card_row(scene, dialog_card_scroll, dialog_card_size)
	if scene.has_method("_configure_card_gallery_drag_scroll"):
		scene.call("_configure_card_gallery_drag_scroll", dialog_card_scroll, recreated_card_row, "dialog_cards")
	if dialog_list.item_selected.is_connected(Callable(scene, "_on_dialog_item_selected")):
		dialog_list.item_selected.disconnect(Callable(scene, "_on_dialog_item_selected"))
	if dialog_list.multi_selected.is_connected(Callable(scene, "_on_dialog_item_multi_selected")):
		dialog_list.multi_selected.disconnect(Callable(scene, "_on_dialog_item_multi_selected"))
	scene.call("_clear_container_children", dialog_utility_row)

	_populate_card_dialog_cards(scene)
	if _library_search_requires_explicit_empty_selection(scene):
		_rebuild_library_search_empty_action_row(scene)
	else:
		_rebuild_card_dialog_utility_row(scene)
	dialog_card_scroll.visible = true

	var min_select := int(extra_data.get("min_select", 1))
	var max_select := int(extra_data.get("max_select", 1))
	var show_confirm := bool(extra_data.get("force_confirm", false)) or max_select > 1 or min_select > 1
	dialog_confirm.visible = show_confirm
	dialog_status_lbl.visible = show_confirm
	if show_confirm:
		update_dialog_status_text(scene)


func _populate_card_dialog_cards(scene: Object) -> void:
	var dialog_card_row: HBoxContainer = scene.get("_dialog_card_row")
	var dialog_card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var dialog_items_data: Array = scene.get("_dialog_items_data")
	var card_items: Array = dialog_data.get("card_items", dialog_items_data)
	var card_indices: Array = dialog_data.get("card_indices", [])
	var labels: Array = dialog_data.get("choice_labels", dialog_items_data)
	var card_groups: Array = dialog_data.get("card_groups", [])
	var card_click_selectable: bool = bool(dialog_data.get("card_click_selectable", true))
	var show_selectable_hints: bool = bool(dialog_data.get("show_selectable_hints", false))
	var selectable_hint: String = str(dialog_data.get("card_selectable_hint", "可选"))
	var disabled_badge: String = str(dialog_data.get("card_disabled_badge", ""))
	dialog_card_scroll.scroll_horizontal = 0
	scene.call("_clear_container_children", dialog_card_row)
	reset_dialog_card_row_metrics(dialog_card_scroll, dialog_card_row, dialog_card_size)
	if not card_groups.is_empty():
		var grouped_height := grouped_card_dialog_scroll_height(dialog_card_size, card_items, card_groups, scene)
		dialog_card_scroll.custom_minimum_size = Vector2(0, grouped_height)
		dialog_card_scroll.size = Vector2(dialog_card_scroll.size.x, grouped_height)
		dialog_card_row.custom_minimum_size = Vector2(0, grouped_height - grouped_card_dialog_scrollbar_clearance(scene))
		dialog_card_row.size = Vector2(dialog_card_row.size.x, dialog_card_row.custom_minimum_size.y)
		populate_grouped_card_dialog_items(scene, card_items, labels, card_groups, card_click_selectable)
		sync_dialog_card_selection(scene)
		return
	for i: int in _visible_card_display_order(card_items, card_indices):
		var real_index := i
		if i < card_indices.size():
			real_index = int(card_indices[i])
		var disabled := real_index < 0
		var card_view := BattleCardViewScript.new()
		prepare_dialog_card_view(card_view, dialog_card_size)
		card_view.set_clickable(card_click_selectable)
		setup_dialog_card_view(scene, card_view, card_items[i], dialog_label_at(labels, i))
		if disabled:
			card_view.set_disabled(true)
			if disabled_badge != "":
				card_view.set_badges(disabled_badge, "")
		elif show_selectable_hints:
			card_view.set_selectable_hint_text(selectable_hint)
			card_view.set_selectable_hint(true)
		if scene.has_method("_configure_card_gallery_card_view"):
			scene.call("_configure_card_gallery_card_view", card_view, dialog_card_scroll, "dialog_cards")
		if card_click_selectable and not disabled:
			card_view.left_clicked.connect(Callable(scene, "_on_dialog_card_left_signal").bind(real_index))
		card_view.right_clicked.connect(Callable(scene, "_on_dialog_card_right_signal"))
		card_view.set_meta("dialog_choice_index", real_index)
		dialog_card_row.add_child(card_view)
	reset_dialog_card_row_metrics(dialog_card_scroll, dialog_card_row, dialog_card_size)
	sync_dialog_card_selection(scene)


func populate_grouped_card_dialog_items(
	scene: Object,
	card_items: Array,
	labels: Array,
	card_groups: Array,
	card_click_selectable: bool
) -> void:
	var dialog_card_row: HBoxContainer = scene.get("_dialog_card_row")
	var dialog_card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	var energy_card_size := grouped_energy_card_size(dialog_card_size)
	var has_ungrouped := grouped_card_dialog_has_ungrouped(card_items, card_groups)
	var has_active := grouped_card_dialog_has_lane(scene, card_groups, "active")
	var has_bench := grouped_card_dialog_has_lane(scene, card_groups, "bench")
	var group_height := grouped_card_dialog_content_height(dialog_card_size, grouped_card_dialog_visible_lane_count(scene, card_groups, has_ungrouped))
	var board_panel := PanelContainer.new()
	board_panel.name = "EnergyDiscardBattlefield"
	board_panel.custom_minimum_size = Vector2(grouped_card_dialog_board_width(scene, card_groups, energy_card_size), group_height)
	board_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	board_panel.add_theme_stylebox_override("panel", grouped_card_dialog_battlefield_style())
	dialog_card_row.add_child(board_panel)

	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", 12)
	board_margin.add_theme_constant_override("margin_right", 12)
	board_margin.add_theme_constant_override("margin_top", 12)
	board_margin.add_theme_constant_override("margin_bottom", 12)
	board_panel.add_child(board_margin)

	var board_box := VBoxContainer.new()
	board_box.name = "EnergyDiscardBattlefieldRows"
	board_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_box.add_theme_constant_override("separation", 6)
	board_margin.add_child(board_box)

	var active_lane: HBoxContainer = null
	if has_active:
		board_box.add_child(create_grouped_card_dialog_lane_label("战斗宝可梦", "EnergyDiscardActiveLabel"))
		active_lane = HBoxContainer.new()
		active_lane.name = "EnergyDiscardActiveLane"
		active_lane.alignment = BoxContainer.ALIGNMENT_CENTER
		active_lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		active_lane.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		active_lane.add_theme_constant_override("separation", 14)
		board_box.add_child(active_lane)

	var bench_lane: HBoxContainer = null
	if has_bench:
		board_box.add_child(create_grouped_card_dialog_lane_label("备战区", "EnergyDiscardBenchLabel"))
		bench_lane = HBoxContainer.new()
		bench_lane.name = "EnergyDiscardBenchLane"
		bench_lane.alignment = BoxContainer.ALIGNMENT_CENTER
		bench_lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bench_lane.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		bench_lane.add_theme_constant_override("separation", 14)
		board_box.add_child(bench_lane)

	var sorted_groups := grouped_card_dialog_sorted_groups(scene, card_groups)
	for group_index: int in sorted_groups.size():
		var group: Dictionary = sorted_groups[group_index]
		var slot_variant: Variant = group.get("slot")
		var indices: Array = grouped_card_dialog_group_indices(group)
		if not (slot_variant is PokemonSlot) or indices.is_empty():
			continue
		var pokemon_slot: PokemonSlot = slot_variant as PokemonSlot
		var slot_panel := create_grouped_card_dialog_slot_panel(
			scene,
			card_items,
			pokemon_slot,
			indices,
			group_index,
			energy_card_size,
			card_click_selectable
		)
		if grouped_card_dialog_slot_lane(scene, pokemon_slot) == "bench" and bench_lane != null:
			bench_lane.add_child(slot_panel)
		elif active_lane != null:
			active_lane.add_child(slot_panel)

	if has_ungrouped:
		board_box.add_child(create_grouped_card_dialog_lane_label("其他", "EnergyDiscardOtherLabel"))
		var other_lane := HBoxContainer.new()
		other_lane.name = "EnergyDiscardOtherLane"
		other_lane.alignment = BoxContainer.ALIGNMENT_CENTER
		other_lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		other_lane.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		other_lane.add_theme_constant_override("separation", 14)
		board_box.add_child(other_lane)
		for item_index: int in grouped_card_dialog_ungrouped_indices(card_items, card_groups):
			var card_view := BattleCardViewScript.new()
			prepare_grouped_energy_card_view(card_view, energy_card_size)
			card_view.set_clickable(card_click_selectable)
			setup_dialog_card_view(scene, card_view, card_items[item_index], dialog_label_at(labels, item_index))
			if scene.has_method("_configure_card_gallery_card_view"):
				scene.call("_configure_card_gallery_card_view", card_view, dialog_card_scroll, "dialog_cards")
			if card_click_selectable:
				card_view.left_clicked.connect(Callable(scene, "_on_dialog_card_left_signal").bind(item_index))
			card_view.right_clicked.connect(Callable(scene, "_on_dialog_card_right_signal"))
			card_view.set_meta("dialog_choice_index", item_index)
			other_lane.add_child(card_view)


func grouped_card_dialog_scroll_height(card_size: Vector2, card_items: Array = [], card_groups: Array = [], scene: Object = null) -> float:
	return grouped_card_dialog_content_height(card_size, grouped_card_dialog_visible_lane_count(scene, card_groups, grouped_card_dialog_has_ungrouped(card_items, card_groups))) + grouped_card_dialog_scrollbar_clearance(scene)


func grouped_card_dialog_content_height(card_size: Vector2, visible_lane_count: int = 2) -> float:
	var energy_card_size := grouped_energy_card_size(card_size)
	var lane_count := float(maxi(1, visible_lane_count))
	return grouped_card_dialog_slot_height(energy_card_size) * lane_count + 30.0 * lane_count + 36.0


func grouped_card_dialog_slot_height(energy_card_size: Vector2) -> float:
	return energy_card_size.y + 20.0


func grouped_card_dialog_board_width(scene: Object, card_groups: Array, energy_card_size: Vector2) -> float:
	var active_width := 0.0
	var bench_width := 0.0
	var bench_count := 0
	for group_variant: Variant in card_groups:
		if not (group_variant is Dictionary):
			continue
		var group: Dictionary = group_variant
		var slot_variant: Variant = group.get("slot")
		if not (slot_variant is PokemonSlot):
			continue
		var indices: Array = grouped_card_dialog_group_indices(group)
		var width := grouped_card_dialog_group_width(energy_card_size, indices.size())
		if grouped_card_dialog_slot_lane(scene, slot_variant as PokemonSlot) == "bench":
			if bench_count > 0:
				bench_width += 14.0
			bench_width += width
			bench_count += 1
		else:
			active_width = maxf(active_width, width)
	return maxf(540.0, maxf(active_width, bench_width)) + 24.0


func grouped_card_dialog_group_width(energy_card_size: Vector2, energy_count: int) -> float:
	var card_count := energy_count + 1
	return maxf(212.0, energy_card_size.x * float(card_count) + 12.0 * float(maxi(0, card_count - 1)) + 22.0)


func grouped_energy_card_size(card_size: Vector2) -> Vector2:
	return Vector2(maxf(92.0, card_size.x * 0.68), maxf(128.0, card_size.y * 0.68))


func grouped_card_dialog_group_indices(group: Dictionary) -> Array:
	var indices: Array = group.get("card_indices", [])
	if indices.is_empty():
		indices = group.get("energy_indices", [])
	return indices


func grouped_card_dialog_grouped_index_set(card_groups: Array) -> Dictionary:
	var grouped: Dictionary = {}
	for group_variant: Variant in card_groups:
		if not (group_variant is Dictionary):
			continue
		for idx_variant: Variant in grouped_card_dialog_group_indices(group_variant as Dictionary):
			grouped[int(idx_variant)] = true
	return grouped


func grouped_card_dialog_ungrouped_indices(card_items: Array, card_groups: Array) -> Array[int]:
	var grouped := grouped_card_dialog_grouped_index_set(card_groups)
	var indices: Array[int] = []
	for i: int in card_items.size():
		if not grouped.has(i):
			indices.append(i)
	return indices


func grouped_card_dialog_has_ungrouped(card_items: Array, card_groups: Array) -> bool:
	return not grouped_card_dialog_ungrouped_indices(card_items, card_groups).is_empty()


func grouped_card_dialog_has_lane(scene: Object, card_groups: Array, lane: String) -> bool:
	for group_variant: Variant in card_groups:
		if not (group_variant is Dictionary):
			continue
		var group: Dictionary = group_variant
		if grouped_card_dialog_group_indices(group).is_empty():
			continue
		var slot_variant: Variant = group.get("slot")
		if not (slot_variant is PokemonSlot):
			continue
		var group_lane := grouped_card_dialog_slot_lane(scene, slot_variant as PokemonSlot)
		if lane == "bench" and group_lane == "bench":
			return true
		if lane == "active" and group_lane != "bench":
			return true
	return false


func grouped_card_dialog_visible_lane_count(scene: Object, card_groups: Array, has_ungrouped: bool = false) -> int:
	var count := 0
	if grouped_card_dialog_has_lane(scene, card_groups, "active"):
		count += 1
	if grouped_card_dialog_has_lane(scene, card_groups, "bench"):
		count += 1
	if has_ungrouped:
		count += 1
	return maxi(1, count)


func create_grouped_card_dialog_lane_label(text: String, node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.70, 0.86, 0.92, 0.92))
	return label


func prepare_grouped_energy_card_view(card_view: BattleCardView, energy_card_size: Vector2) -> void:
	card_view.custom_minimum_size = energy_card_size
	card_view.size = energy_card_size
	card_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func create_grouped_card_dialog_slot_panel(
	scene: Object,
	card_items: Array,
	pokemon_slot: PokemonSlot,
	indices: Array,
	group_index: int,
	energy_card_size: Vector2,
	card_click_selectable: bool
) -> PanelContainer:
	var slot_position := grouped_card_dialog_slot_position(scene, pokemon_slot)
	var group_panel := PanelContainer.new()
	group_panel.name = "EnergyDiscardGroup%d" % group_index
	group_panel.custom_minimum_size = Vector2(
		grouped_card_dialog_group_width(energy_card_size, indices.size()),
		grouped_card_dialog_slot_height(energy_card_size)
	)
	group_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	group_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	group_panel.add_theme_stylebox_override("panel", grouped_card_dialog_panel_style(group_index))
	group_panel.set_meta("energy_group_slot_position", slot_position)
	group_panel.set_meta("energy_group_pokemon_name", pokemon_slot.get_pokemon_name())
	group_panel.set_meta("energy_group_basic_energy_count", indices.size())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	group_panel.add_child(margin)

	var group_box := VBoxContainer.new()
	group_box.add_theme_constant_override("separation", 6)
	group_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(group_box)

	var card_line := HBoxContainer.new()
	card_line.name = "EnergyGroupCardLine"
	card_line.alignment = BoxContainer.ALIGNMENT_CENTER
	card_line.add_theme_constant_override("separation", 12)
	card_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_line.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	group_box.add_child(card_line)

	var header_view := BattleCardViewScript.new()
	prepare_grouped_energy_card_view(header_view, energy_card_size)
	header_view.set_clickable(false)
	header_view.setup_from_card_data(pokemon_slot.get_card_data(), scene.call("_battle_card_mode_for_slot", pokemon_slot))
	var header_top_card := pokemon_slot.get_top_card()
	if header_top_card != null and header_view.has_method("set_card_foil_owner_index"):
		header_view.call("set_card_foil_owner_index", header_top_card.owner_index)
	if scene.has_method("_sync_card_foil_effect_for_view"):
		scene.call("_sync_card_foil_effect_for_view", header_view)
	header_view.set_badges()
	header_view.set_battle_status(scene.call("_build_battle_status", pokemon_slot))
	header_view.set_meta("dialog_choice_index", -1)
	card_line.add_child(header_view)

	for energy_idx_variant: Variant in indices:
		var real_index := int(energy_idx_variant)
		if real_index < 0 or real_index >= card_items.size():
			continue
		var card_view := BattleCardViewScript.new()
		prepare_grouped_energy_card_view(card_view, energy_card_size)
		card_view.set_clickable(card_click_selectable)
		setup_dialog_card_view(scene, card_view, card_items[real_index], "")
		if scene.has_method("_configure_card_gallery_card_view"):
			scene.call("_configure_card_gallery_card_view", card_view, scene.get("_dialog_card_scroll"), "dialog_cards")
		if card_click_selectable:
			card_view.left_clicked.connect(Callable(scene, "_on_dialog_card_left_signal").bind(real_index))
		card_view.right_clicked.connect(Callable(scene, "_on_dialog_card_right_signal"))
		card_view.set_meta("dialog_choice_index", real_index)
		card_line.add_child(card_view)
	return group_panel


func grouped_card_dialog_sorted_groups(scene: Object, card_groups: Array) -> Array:
	var sorted := card_groups.duplicate()
	sorted.sort_custom(func(a: Variant, b: Variant) -> bool:
		return grouped_card_dialog_group_order(scene, a) < grouped_card_dialog_group_order(scene, b)
	)
	return sorted


func grouped_card_dialog_group_order(scene: Object, group_variant: Variant) -> int:
	if not (group_variant is Dictionary):
		return 9999
	var group: Dictionary = group_variant
	var slot_variant: Variant = group.get("slot")
	if not (slot_variant is PokemonSlot):
		return 9999
	var slot := slot_variant as PokemonSlot
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null:
		return 9999
	for player: PlayerState in gsm.game_state.players:
		if player.active_pokemon == slot:
			return 0
		var bench_index := player.bench.find(slot)
		if bench_index >= 0:
			return 100 + bench_index
	return 9999


func grouped_card_dialog_slot_lane(scene: Object, slot: PokemonSlot) -> String:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null:
		return "unknown"
	for player: PlayerState in gsm.game_state.players:
		if player.active_pokemon == slot:
			return "active"
		if player.bench.find(slot) >= 0:
			return "bench"
	return "unknown"


func grouped_card_dialog_slot_position(scene: Object, slot: PokemonSlot) -> String:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null:
		return "场上宝可梦"
	for player: PlayerState in gsm.game_state.players:
		if player.active_pokemon == slot:
			return "战斗场"
		var bench_index := player.bench.find(slot)
		if bench_index >= 0:
			return "备战区 %d" % (bench_index + 1)
	return "场上宝可梦"


func grouped_card_dialog_panel_style(group_index: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var tint := 0.02 * float(group_index % 2)
	style.bg_color = Color(0.020 + tint, 0.038 + tint, 0.052 + tint, 0.92)
	style.border_color = Color(0.32, 0.72, 0.84, 0.78)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = 8
	return style


func grouped_card_dialog_battlefield_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.015, 0.025, 0.90)
	style.border_color = Color(0.28, 0.62, 0.72, 0.0)
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 0
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	return style


func _card_dialog_scroll_height(card_size: Vector2, scene: Object = null) -> float:
	if _card_dialog_uses_visible_scrollbar(scene) and scene != null and scene.has_method("_dialog_card_scroll_height"):
		return float(scene.call("_dialog_card_scroll_height"))
	return card_size.y


func grouped_card_dialog_scrollbar_clearance(scene: Object = null) -> float:
	if _card_dialog_uses_visible_scrollbar(scene) and scene != null and scene.has_method("_card_scrollbar_clearance_height"):
		return float(scene.call("_card_scrollbar_clearance_height"))
	return 0.0


func _card_dialog_uses_visible_scrollbar(scene: Object = null) -> bool:
	return scene != null and scene.has_method("_is_portrait_popup_text_profile_active") and bool(scene.call("_is_portrait_popup_text_profile_active"))


func _dialog_scroll_profile(scene: Object = null) -> String:
	if scene != null and scene.has_method("_is_portrait_popup_text_profile_active") and bool(scene.call("_is_portrait_popup_text_profile_active")):
		return "portrait_touch"
	if scene is Node and (scene as Node).is_inside_tree():
		var viewport_size := (scene as Node).get_viewport().get_visible_rect().size
		if viewport_size.y > viewport_size.x:
			return "portrait_touch"
		return "touch" if HudThemeScript.should_use_touch_profile(viewport_size) else "auto"
	return "touch"


func recreate_dialog_card_row(scene: Object, dialog_card_scroll: ScrollContainer, dialog_card_size: Vector2) -> HBoxContainer:
	var old_row := scene.get("_dialog_card_row") as HBoxContainer
	if old_row != null and old_row.get_parent() == dialog_card_scroll:
		dialog_card_scroll.remove_child(old_row)
		old_row.queue_free()
	if dialog_card_scroll.custom_minimum_size.y > 0.0:
		dialog_card_scroll.size = Vector2(dialog_card_scroll.size.x, dialog_card_scroll.custom_minimum_size.y)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, dialog_card_size.y)
	row.size = Vector2(0, dialog_card_size.y)
	dialog_card_scroll.add_child(row)
	scene.set("_dialog_card_row", row)
	return row


func prepare_dialog_card_view(card_view: BattleCardView, dialog_card_size: Vector2) -> void:
	card_view.custom_minimum_size = dialog_card_size
	card_view.size = dialog_card_size
	card_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func reset_dialog_card_row_metrics(scroll: ScrollContainer, row: HBoxContainer, dialog_card_size: Vector2) -> void:
	row.custom_minimum_size = Vector2(0, dialog_card_size.y)
	row.size = Vector2(row.size.x, dialog_card_size.y)
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for child: Node in row.get_children():
		if child is BattleCardView:
			prepare_dialog_card_view(child as BattleCardView, dialog_card_size)
	if scroll != null and scroll.custom_minimum_size.y > 0.0:
		scroll.size = Vector2(scroll.size.x, scroll.custom_minimum_size.y)


func _rebuild_card_dialog_utility_row(scene: Object) -> void:
	var dialog_utility_row: HBoxContainer = scene.get("_dialog_utility_row")
	var dialog_data: Dictionary = scene.get("_dialog_data")
	scene.call("_clear_container_children", dialog_utility_row)
	var has_controls := false

	var utility_actions: Array = dialog_data.get("utility_actions", [])
	for action_variant: Variant in utility_actions:
		if not (action_variant is Dictionary):
			continue
		has_controls = true
		var action: Dictionary = action_variant
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = str(action.get("label", _bt(scene, "battle.dialog.action_label")))
		style_dialog_button(button, "primary")
		var selected_indices := _dialog_utility_action_selected_indices(action)
		var action_intent := _dialog_utility_action_intent(action)
		button.pressed.connect(func() -> void:
			_record_dialog_fresh_input(scene, "dialog_utility_action")
			mark_modal_input_consumed(scene, "dialog_utility_action")
			confirm_dialog_selection(scene, selected_indices, Vector2(-1.0, -1.0), action_intent)
		)
		dialog_utility_row.add_child(button)
	dialog_utility_row.visible = has_controls


func _dialog_utility_action_selected_indices(action: Dictionary) -> PackedInt32Array:
	var result := PackedInt32Array()
	if action.has("selected_indices"):
		var selected_raw: Variant = action.get("selected_indices", [])
		if selected_raw is PackedInt32Array:
			return (selected_raw as PackedInt32Array).duplicate()
		if selected_raw is Array:
			for index_variant: Variant in selected_raw:
				result.append(int(index_variant))
		return result
	var legacy_index := int(action.get("index", -1))
	if legacy_index >= 0:
		result.append(legacy_index)
	return result


func _dialog_utility_action_intent(action: Dictionary) -> String:
	if action.has("intent"):
		return str(action.get("intent", BaseEffect.INTERACTION_INTENT_SELECT))
	if action.has("index") and int(action.get("index", -1)) < 0:
		return BaseEffect.INTERACTION_INTENT_DECLINE
	return BaseEffect.INTERACTION_INTENT_SELECT


func _rebuild_library_search_empty_action_row(scene: Object) -> void:
	var dialog_utility_row: HBoxContainer = scene.get("_dialog_utility_row")
	if dialog_utility_row == null:
		return
	scene.call("_clear_container_children", dialog_utility_row)
	if not _library_search_requires_explicit_empty_selection(scene):
		dialog_utility_row.visible = false
		return
	if _portrait_library_search_uses_cancel_slot_for_empty_selection(scene):
		dialog_utility_row.visible = false
		return

	var button := Button.new()
	button.name = "LibrarySearchEmptySelectionButton"
	button.custom_minimum_size = Vector2(240, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = "不选择"
	style_dialog_button(button, "secondary")
	button.pressed.connect(func() -> void:
		_record_dialog_fresh_input(scene, "library_search_empty_selection")
		mark_modal_input_consumed(scene, "library_search_empty_selection", _dialog_slot_suppression_mode(scene))
		_replace_int_array(scene, "_dialog_card_selected_indices", [])
		confirm_dialog_selection(scene, PackedInt32Array(), Vector2(-1.0, -1.0), BaseEffect.INTERACTION_INTENT_DECLINE)
	)
	dialog_utility_row.add_child(button)
	dialog_utility_row.visible = true


func show_action_hud_dialog(scene: Object, _items: Array, extra_data: Dictionary) -> void:
	var dialog_list: ItemList = scene.get("_dialog_list")
	var dialog_card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var dialog_assignment_panel: VBoxContainer = scene.get("_dialog_assignment_panel")
	var dialog_card_row: HBoxContainer = scene.get("_dialog_card_row")
	var dialog_utility_row: HBoxContainer = scene.get("_dialog_utility_row")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var dialog_status_lbl: Label = scene.get("_dialog_status_lbl")

	dialog_list.visible = false
	dialog_card_scroll.visible = true
	dialog_assignment_panel.visible = false
	dialog_utility_row.visible = false
	dialog_confirm.visible = false
	dialog_status_lbl.visible = false
	var action_items: Array = extra_data.get("action_items", [])
	var preview_item: Variant = extra_data.get("pokemon_card", extra_data.get("pokemon_card_data", null))
	var has_preview := preview_item is CardInstance or preview_item is CardData
	var preview_size := _action_hud_preview_card_size(scene)
	var attached_energy_summary := str(extra_data.get("attached_energy_summary", "")).strip_edges()
	dialog_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if action_items.size() > 5 else ScrollContainer.SCROLL_MODE_DISABLED
	if scene.has_method("_set_card_gallery_drag_scroll_active"):
		scene.call("_set_card_gallery_drag_scroll_active", dialog_card_scroll, false)
	var scroll_height := _action_hud_scroll_height(action_items.size())
	if has_preview:
		var preview_extra_height := ACTION_HUD_ENERGY_SUMMARY_HEIGHT if attached_energy_summary != "" else 0.0
		scroll_height = maxf(scroll_height, preview_size.y + preview_extra_height + 18.0)
	dialog_card_scroll.custom_minimum_size = Vector2(0, scroll_height)
	dialog_card_scroll.set_meta("dialog_presentation", "action_hud")
	dialog_card_scroll.set_meta("action_hud_scroll_height", scroll_height)
	if dialog_list.item_selected.is_connected(Callable(scene, "_on_dialog_item_selected")):
		dialog_list.item_selected.disconnect(Callable(scene, "_on_dialog_item_selected"))
	if dialog_list.multi_selected.is_connected(Callable(scene, "_on_dialog_item_multi_selected")):
		dialog_list.multi_selected.disconnect(Callable(scene, "_on_dialog_item_multi_selected"))
	scene.call("_clear_container_children", dialog_card_row)
	scene.call("_clear_container_children", dialog_utility_row)

	dialog_card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_card_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dialog_card_row.custom_minimum_size = Vector2.ZERO
	dialog_card_row.add_theme_constant_override("separation", ACTION_HUD_PREVIEW_ROW_SEPARATION if has_preview else 10)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	dialog_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	if has_preview:
		dialog_card_row.add_child(_build_action_hud_card_preview(preview_item, preview_size, attached_energy_summary))
	dialog_card_row.add_child(stack)

	var option_width := _action_hud_option_width(scene, preview_size, has_preview)
	for i: int in action_items.size():
		var action: Dictionary = action_items[i] if action_items[i] is Dictionary else {}
		stack.add_child(_build_action_hud_option(scene, action, i, option_width))


func refresh_action_hud_dialog(scene: Object) -> void:
	var dialog_data_variant: Variant = scene.get("_dialog_data")
	if not (dialog_data_variant is Dictionary):
		return
	var dialog_data: Dictionary = dialog_data_variant
	if str(dialog_data.get("presentation", "")) != "action_hud":
		return
	var dialog_items_variant: Variant = scene.get("_dialog_items_data")
	var dialog_items: Array = dialog_items_variant if dialog_items_variant is Array else []
	show_action_hud_dialog(scene, dialog_items, dialog_data)


func _action_hud_scroll_height(action_count: int) -> float:
	var visible_count: int = clampi(action_count, 1, 5)
	return float(visible_count * 88 + maxi(visible_count - 1, 0) * 8 + 2)


func _action_hud_preview_card_size(scene: Object) -> Vector2:
	var base_size := _action_hud_base_preview_card_size(scene)
	if not _is_portrait_text_dialog(scene):
		return base_size
	var dialog_width := _action_hud_dialog_width(scene)
	if dialog_width <= 0.0 or base_size.x <= 0.0 or base_size.y <= 0.0:
		return base_size
	var max_preview_for_width := dialog_width - ACTION_HUD_PREVIEW_CHROME_WIDTH - ACTION_HUD_PREVIEW_ROW_SEPARATION - PORTRAIT_ACTION_HUD_MIN_OPTION_WIDTH
	var ratio_preview_width := dialog_width * PORTRAIT_ACTION_HUD_MAX_PREVIEW_WIDTH_RATIO
	var target_width := minf(base_size.x, minf(ratio_preview_width, max_preview_for_width))
	target_width = maxf(PORTRAIT_ACTION_HUD_MIN_PREVIEW_WIDTH, target_width)
	target_width = minf(target_width, base_size.x)
	if target_width >= base_size.x:
		return base_size
	var scale := target_width / base_size.x
	return Vector2(target_width, base_size.y * scale)


func _action_hud_base_preview_card_size(scene: Object) -> Vector2:
	var detail_card_size_variant: Variant = scene.get("_detail_card_size")
	if detail_card_size_variant is Vector2:
		var detail_card_size: Vector2 = detail_card_size_variant
		if detail_card_size.x > 0.0 and detail_card_size.y > 0.0:
			return detail_card_size
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	return Vector2(maxf(188.0, dialog_card_size.x * 1.26), maxf(264.0, dialog_card_size.y * 1.26))


func _action_hud_option_width(scene: Object, preview_size: Vector2, has_preview: bool) -> float:
	if not has_preview:
		if _is_portrait_text_dialog(scene):
			return maxf(_action_hud_dialog_width(scene) - PORTRAIT_TEXT_HUD_OPTION_HORIZONTAL_INSET, 1.0)
		return 760.0
	var box_width := _action_hud_dialog_width(scene)
	if _is_portrait_text_dialog(scene):
		return maxf(box_width - (preview_size.x + ACTION_HUD_PREVIEW_CHROME_WIDTH) - ACTION_HUD_PREVIEW_ROW_SEPARATION, 1.0)
	return maxf(420.0, box_width - (preview_size.x + ACTION_HUD_PREVIEW_CHROME_WIDTH) - ACTION_HUD_PREVIEW_ROW_SEPARATION)


func _action_hud_dialog_width(scene: Object) -> float:
	if _is_portrait_text_dialog(scene) and scene.has_method("_portrait_popup_near_width"):
		var near_width := float(scene.call("_portrait_popup_near_width"))
		if near_width > 0.0:
			return near_width
	if _is_portrait_text_dialog(scene) and scene.has_method("_portrait_popup_content_size"):
		var content_size_variant: Variant = scene.call("_portrait_popup_content_size")
		if content_size_variant is Vector2:
			var content_size: Vector2 = content_size_variant
			if content_size.x > 0.0:
				return content_size.x
	var dialog_box := scene.get("_dialog_box") as Control
	var box_width := 860.0
	if dialog_box != null and dialog_box.custom_minimum_size.x > 0.0:
		box_width = dialog_box.custom_minimum_size.x
	return box_width


func _build_action_hud_card_preview(preview_item: Variant, preview_size: Vector2, attached_energy_summary: String = "") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "PokemonActionCardPreview"
	var summary_text := attached_energy_summary.strip_edges()
	var summary_height := ACTION_HUD_ENERGY_SUMMARY_HEIGHT if summary_text != "" else 0.0
	panel.custom_minimum_size = Vector2(preview_size.x + ACTION_HUD_PREVIEW_CHROME_WIDTH, preview_size.y + summary_height + 14.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _action_hud_card_preview_style())

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var card_view := BattleCardViewScript.new()
	card_view.name = "PokemonActionCardView"
	card_view.custom_minimum_size = preview_size
	card_view.size = preview_size
	card_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_view.set_clickable(false)
	card_view.set_compact_preview(true)
	if preview_item is CardInstance:
		card_view.setup_from_instance(preview_item as CardInstance, BattleCardViewScript.MODE_PREVIEW)
	elif preview_item is CardData:
		card_view.setup_from_card_data(preview_item as CardData, BattleCardViewScript.MODE_PREVIEW)
	box.add_child(card_view)
	if summary_text != "":
		box.add_child(_build_action_hud_attached_energy_summary(summary_text, preview_size.x))
	return panel


func _build_action_hud_attached_energy_summary(summary_text: String, width: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "PokemonActionAttachedEnergySummary"
	panel.custom_minimum_size = Vector2(width, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _action_hud_energy_summary_style())

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)

	var title := Label.new()
	title.name = "PokemonActionAttachedEnergyTitle"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = "附着能量"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.55, 0.86, 1.0, 1.0))
	box.add_child(title)

	var label := Label.new()
	label.name = "PokemonActionAttachedEnergyLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = summary_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	box.add_child(label)
	return panel


func _action_hud_card_preview_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.026, 0.036, 0.92)
	style.border_color = Color(0.36, 0.86, 1.0, 0.58)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.74, 1.0, 0.18)
	style.shadow_size = 10
	return style


func _action_hud_energy_summary_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.075, 0.090, 0.96)
	style.border_color = Color(0.35, 0.80, 0.95, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	return style


func _build_action_hud_option(scene: Object, action: Dictionary, action_index: int, option_width: float = 760.0) -> Control:
	var enabled := bool(action.get("enabled", true))
	var accent := _action_hud_accent(str(action.get("type", "")), enabled)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(option_width, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	panel.add_theme_stylebox_override("panel", _action_hud_panel_style(accent, enabled))
	panel.gui_input.connect(func(event: InputEvent) -> void:
		var activated := false
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
				if scene.has_method("_claim_modal_pointer_event"):
					scene.call("_claim_modal_pointer_event", event, "action_hud_option")
				activated = true
		elif event is InputEventScreenTouch:
			var touch_event := event as InputEventScreenTouch
			if touch_event.pressed:
				if scene.has_method("_claim_modal_pointer_event"):
					scene.call("_claim_modal_pointer_event", event, "action_hud_option")
				panel.set_meta("_action_hud_touch_active", true)
				panel.set_meta("_action_hud_touch_index", touch_event.index)
				panel.set_meta("_action_hud_touch_position", touch_event.position)
				panel.accept_event()
				return
			var has_touch_press := bool(panel.get_meta("_action_hud_touch_active", false))
			var touch_press_index := int(panel.get_meta("_action_hud_touch_index", touch_event.index))
			var touch_press_position := touch_event.position
			var stored_touch_position: Variant = panel.get_meta("_action_hud_touch_position", touch_event.position)
			if stored_touch_position is Vector2:
				touch_press_position = stored_touch_position
			panel.set_meta("_action_hud_touch_active", false)
			if not has_touch_press or touch_press_index != touch_event.index:
				panel.accept_event()
				return
			if touch_press_position.distance_to(touch_event.position) > ACTION_HUD_TOUCH_CLICK_MOVE_TOLERANCE:
				panel.accept_event()
				return
			activated = true
		if activated:
			if not enabled:
				panel.accept_event()
				return
			var origin_position := _input_event_screen_position(event)
			if _consume_direct_dialog_choice_if_stale(scene, "action_hud_option", origin_position):
				panel.accept_event()
				return
			_record_dialog_fresh_input(scene, "action_hud_option", origin_position)
			if scene.has_method("_begin_modal_pointer_drain_for_event"):
				scene.call(
					"_begin_modal_pointer_drain_for_event",
					event,
					"action_hud_option"
				)
			confirm_dialog_selection(scene, PackedInt32Array([action_index]), origin_position)
			panel.accept_event()
	)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	var kind := Label.new()
	kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kind.text = str(action.get("kind", "行动"))
	kind.custom_minimum_size = Vector2(58, 22)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kind.add_theme_font_size_override("font_size", 13)
	kind.add_theme_color_override("font_color", Color(0.04, 0.06, 0.08, 1.0))
	kind.add_theme_stylebox_override("normal", _action_hud_pill_style(accent, enabled))
	header.add_child(kind)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = str(action.get("title", ""))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0) if enabled else Color(0.62, 0.66, 0.70, 1.0))
	header.add_child(title)

	var cost_text := str(action.get("cost", "")).strip_edges()
	if cost_text != "":
		header.add_child(_build_energy_cost_icons(cost_text, enabled))

	var meta := Label.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.text = str(action.get("meta", ""))
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.add_theme_font_size_override("font_size", 14)
	meta.add_theme_color_override("font_color", Color(0.76, 0.86, 0.96, 1.0) if enabled else Color(0.50, 0.54, 0.58, 1.0))
	header.add_child(meta)

	var body := RichTextLabel.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.bbcode_enabled = false
	body.fit_content = true
	body.scroll_active = false
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = str(action.get("body", ""))
	body.add_theme_font_size_override("normal_font_size", 14)
	body.add_theme_color_override("default_color", Color(0.84, 0.89, 0.94, 1.0) if enabled else Color(0.55, 0.59, 0.63, 1.0))
	box.add_child(body)

	var reason := str(action.get("reason", "")).strip_edges()
	if not enabled and reason != "":
		var reason_label := Label.new()
		reason_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reason_label.text = "不可用：%s" % reason
		reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason_label.add_theme_font_size_override("font_size", 13)
		reason_label.add_theme_color_override("font_color", Color(1.0, 0.67, 0.50, 1.0))
		box.add_child(reason_label)

	return panel


func _build_energy_cost_icons(cost_text: String, enabled: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	for symbol: String in cost_text:
		row.add_child(_build_energy_cost_icon(symbol, enabled))
	return row


func _build_energy_cost_icon(symbol: String, enabled: bool) -> TextureRect:
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ENERGY_ICON_TEXTURES.get(symbol, ENERGY_ICON_TEXTURES.get("C"))
	icon.modulate = Color(1, 1, 1, 1) if enabled else Color(0.45, 0.45, 0.45, 0.82)
	return icon


func _action_hud_accent(action_type: String, enabled: bool) -> Color:
	if not enabled:
		return Color(0.34, 0.38, 0.42, 1.0)
	match action_type:
		"ability", "stadium_ability":
			return Color(0.35, 0.80, 0.95, 1.0)
		"attack", "granted_attack":
			return Color(1.0, 0.48, 0.24, 1.0)
		"retreat":
			return Color(0.62, 0.90, 0.42, 1.0)
		_:
			return Color(0.72, 0.78, 0.86, 1.0)


func _action_hud_panel_style(accent: Color, enabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.075, 0.96) if enabled else Color(0.028, 0.035, 0.043, 0.90)
	style.border_color = accent
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.22 if enabled else 0.08)
	style.shadow_size = 8 if enabled else 2
	return style


func _action_hud_pill_style(accent: Color, enabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent if enabled else Color(0.30, 0.33, 0.36, 1.0)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _configure_assignment_gallery_lane(
	scene: Object,
	scroll: ScrollContainer,
	row: Control,
	source: String
) -> void:
	if scroll == null:
		return
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var show_visible_scrollbar := _card_dialog_uses_visible_scrollbar(scene)
	scroll.set_meta("card_gallery_drag_keep_scrollbars_visible", show_visible_scrollbar)
	if scene.has_method("_configure_card_gallery_drag_scroll"):
		scene.call("_configure_card_gallery_drag_scroll", scroll, row, source)
	HudThemeScript.style_scroll_container(scroll, _dialog_scroll_profile(scene))
	if show_visible_scrollbar:
		if scene.has_method("_restore_card_gallery_scrollbars_for"):
			scene.call("_restore_card_gallery_scrollbars_for", scroll)
	elif scene.has_method("_hide_card_gallery_scrollbars_for"):
		scene.call("_hide_card_gallery_scrollbars_for", scroll)


func _set_assignment_gallery_lanes_active(scene: Object, active: bool) -> void:
	if scene == null or not scene.has_method("_set_card_gallery_drag_scroll_active"):
		return
	for property_name: String in [
		"_dialog_assignment_source_scroll",
		"_dialog_assignment_target_scroll",
	]:
		var scroll := scene.get(property_name) as ScrollContainer
		if scroll != null:
			scene.call("_set_card_gallery_drag_scroll_active", scroll, active)


func show_assignment_dialog(scene: Object, extra_data: Dictionary) -> void:
	var dialog_list: ItemList = scene.get("_dialog_list")
	var dialog_card_scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var dialog_assignment_panel: VBoxContainer = scene.get("_dialog_assignment_panel")
	var dialog_assignment_source_scroll: ScrollContainer = scene.get("_dialog_assignment_source_scroll")
	var dialog_assignment_target_scroll: ScrollContainer = scene.get("_dialog_assignment_target_scroll")
	var dialog_card_row: HBoxContainer = scene.get("_dialog_card_row")
	var dialog_utility_row: HBoxContainer = scene.get("_dialog_utility_row")
	var dialog_assignment_source_row: HBoxContainer = scene.get("_dialog_assignment_source_row")
	var dialog_assignment_target_row: HBoxContainer = scene.get("_dialog_assignment_target_row")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var dialog_status_lbl: Label = scene.get("_dialog_status_lbl")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	var source_items: Array = extra_data.get("source_items", [])
	var source_labels: Array = extra_data.get("source_labels", [])
	var source_groups: Array = extra_data.get("source_groups", [])
	var source_card_items: Array = extra_data.get("source_card_items", [])
	var source_card_indices: Array = extra_data.get("source_card_indices", [])
	var source_choice_labels: Array = extra_data.get("source_choice_labels", [])

	_cancel_card_gallery_drag_capture(scene, "show_assignment_dialog")
	if scene.has_method("_clear_hand_drag_click_suppression"):
		scene.call("_clear_hand_drag_click_suppression", "show_assignment_dialog")

	dialog_list.visible = false
	dialog_card_scroll.visible = false
	dialog_assignment_panel.visible = true
	if scene.has_method("_set_card_gallery_drag_scroll_active"):
		scene.call("_set_card_gallery_drag_scroll_active", dialog_card_scroll, false)
	_configure_assignment_gallery_lane(
		scene,
		dialog_assignment_source_scroll,
		dialog_assignment_source_row,
		"assignment_source_cards"
	)
	_configure_assignment_gallery_lane(
		scene,
		dialog_assignment_target_scroll,
		dialog_assignment_target_row,
		"assignment_target_cards"
	)
	_set_assignment_gallery_lanes_active(scene, true)
	dialog_assignment_source_scroll.scroll_horizontal = 0
	dialog_assignment_target_scroll.scroll_horizontal = 0
	scene.call("_clear_container_children", dialog_card_row)
	scene.call("_clear_container_children", dialog_utility_row)
	scene.call("_clear_container_children", dialog_assignment_source_row)
	scene.call("_clear_container_children", dialog_assignment_target_row)
	if not source_groups.is_empty():
		reset_grouped_assignment_source_metrics(dialog_assignment_source_scroll, dialog_assignment_source_row, dialog_card_size, source_items, source_groups, scene)
	else:
		reset_dialog_card_row_metrics(dialog_assignment_source_scroll, dialog_assignment_source_row, dialog_card_size)
	reset_dialog_card_row_metrics(dialog_assignment_target_scroll, dialog_assignment_target_row, dialog_card_size)
	reset_dialog_assignment_state(scene)
	scene.set("_dialog_assignment_mode", true)
	dialog_assignment_panel.visible = true

	var disabled_badge := str(extra_data.get("source_card_disabled_badge", extra_data.get("card_disabled_badge", "")))
	if not source_groups.is_empty():
		populate_grouped_source_items(scene, source_items, source_labels, source_groups)
	elif not source_card_items.is_empty():
		for i: int in _visible_card_display_order(source_card_items, source_card_indices):
			var real_index := i
			if i < source_card_indices.size():
				real_index = int(source_card_indices[i])
			var display_label := str(source_choice_labels[i]) if i < source_choice_labels.size() else ""
			add_assignment_source_card(
				scene,
				source_items,
				source_labels,
				real_index,
				source_card_items[i],
				display_label,
				real_index < 0,
				disabled_badge
			)
	else:
		for i: int in source_items.size():
			add_assignment_source_card(scene, source_items, source_labels, i)

	var target_items: Array = extra_data.get("target_items", [])
	var target_labels: Array = extra_data.get("target_labels", [])
	for i: int in target_items.size():
		var target_view := BattleCardViewScript.new()
		prepare_dialog_card_view(target_view, dialog_card_size)
		target_view.set_clickable(true)
		setup_dialog_card_view(scene, target_view, target_items[i], dialog_label_at(target_labels, i))
		if scene.has_method("_configure_card_gallery_card_view"):
			scene.call(
				"_configure_card_gallery_card_view",
				target_view,
				dialog_assignment_target_scroll,
				"assignment_target_cards"
			)
		target_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
			scene.call("_on_assignment_target_chosen", i)
		)
		target_view.right_clicked.connect(func(ci: CardInstance, cd: CardData) -> void:
			if ci != null and scene.has_method("_show_card_detail_for_instance"):
				scene.call("_show_card_detail_for_instance", ci)
				return
			if cd != null:
				scene.call("_show_card_detail", cd)
		)
		target_view.set_meta("assignment_target_index", i)
		dialog_assignment_target_row.add_child(target_view)
	if not source_groups.is_empty():
		reset_grouped_assignment_source_metrics(dialog_assignment_source_scroll, dialog_assignment_source_row, dialog_card_size, source_items, source_groups, scene)
	else:
		reset_dialog_card_row_metrics(dialog_assignment_source_scroll, dialog_assignment_source_row, dialog_card_size)
	reset_dialog_card_row_metrics(dialog_assignment_target_scroll, dialog_assignment_target_row, dialog_card_size)

	dialog_utility_row.visible = true
	var clear_button := Button.new()
	clear_button.custom_minimum_size = Vector2(140, 40)
	clear_button.text = _bt(scene, "battle.dialog.clear")
	style_dialog_button(clear_button, "secondary")
	clear_button.pressed.connect(func() -> void:
		_replace_dictionary_array(scene, "_dialog_assignment_assignments", [])
		scene.set("_dialog_assignment_selected_source_index", -1)
		refresh_assignment_dialog_views(scene)
	)
	dialog_utility_row.add_child(clear_button)

	dialog_confirm.visible = true
	dialog_status_lbl.visible = false
	refresh_assignment_dialog_views(scene)


func _visible_card_display_order(card_items: Array, card_indices: Array) -> Array[int]:
	var selectable: Array[int] = []
	var disabled: Array[int] = []
	for i: int in card_items.size():
		var real_index := i
		if i < card_indices.size():
			real_index = int(card_indices[i])
		if real_index >= 0:
			selectable.append(i)
		else:
			disabled.append(i)
	selectable.append_array(disabled)
	return selectable


func populate_grouped_source_items(scene: Object, source_items: Array, source_labels: Array, source_groups: Array) -> void:
	var dialog_assignment_source_row: HBoxContainer = scene.get("_dialog_assignment_source_row")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	var energy_card_size := grouped_energy_card_size(dialog_card_size)
	var has_active := grouped_card_dialog_has_lane(scene, source_groups, "active")
	var has_bench := grouped_card_dialog_has_lane(scene, source_groups, "bench")
	var board_panel := PanelContainer.new()
	board_panel.name = "EnergyAssignmentSourceBattlefield"
	board_panel.custom_minimum_size = Vector2(grouped_card_dialog_board_width(scene, source_groups, energy_card_size), grouped_card_dialog_content_height(dialog_card_size, grouped_card_dialog_visible_lane_count(scene, source_groups)))
	board_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	board_panel.add_theme_stylebox_override("panel", grouped_card_dialog_battlefield_style())
	dialog_assignment_source_row.add_child(board_panel)

	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", 12)
	board_margin.add_theme_constant_override("margin_right", 12)
	board_margin.add_theme_constant_override("margin_top", 12)
	board_margin.add_theme_constant_override("margin_bottom", 12)
	board_panel.add_child(board_margin)

	var board_box := VBoxContainer.new()
	board_box.name = "EnergyAssignmentSourceRows"
	board_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_box.add_theme_constant_override("separation", 6)
	board_margin.add_child(board_box)

	var active_lane: HBoxContainer = null
	if has_active:
		board_box.add_child(create_grouped_card_dialog_lane_label("战斗宝可梦", "EnergyAssignmentSourceActiveLabel"))
		active_lane = HBoxContainer.new()
		active_lane.name = "EnergyAssignmentSourceActiveLane"
		active_lane.alignment = BoxContainer.ALIGNMENT_CENTER
		active_lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		active_lane.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		active_lane.add_theme_constant_override("separation", 14)
		board_box.add_child(active_lane)

	var bench_lane: HBoxContainer = null
	if has_bench:
		board_box.add_child(create_grouped_card_dialog_lane_label("备战区", "EnergyAssignmentSourceBenchLabel"))
		bench_lane = HBoxContainer.new()
		bench_lane.name = "EnergyAssignmentSourceBenchLane"
		bench_lane.alignment = BoxContainer.ALIGNMENT_CENTER
		bench_lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bench_lane.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		bench_lane.add_theme_constant_override("separation", 14)
		board_box.add_child(bench_lane)

	var sorted_groups := grouped_card_dialog_sorted_groups(scene, source_groups)
	for group_index: int in sorted_groups.size():
		var group: Dictionary = sorted_groups[group_index]
		var slot_variant: Variant = group.get("slot")
		var indices: Array = grouped_card_dialog_group_indices(group)
		if not (slot_variant is PokemonSlot) or indices.is_empty():
			continue
		var pokemon_slot: PokemonSlot = slot_variant as PokemonSlot
		var slot_panel := create_grouped_assignment_source_slot_panel(
			scene,
			source_items,
			source_labels,
			pokemon_slot,
			indices,
			group_index,
			energy_card_size
		)
		if grouped_card_dialog_slot_lane(scene, pokemon_slot) == "bench" and bench_lane != null:
			bench_lane.add_child(slot_panel)
		elif active_lane != null:
			active_lane.add_child(slot_panel)


func reset_grouped_assignment_source_metrics(scroll: ScrollContainer, row: HBoxContainer, dialog_card_size: Vector2, source_items: Array, source_groups: Array, scene: Object = null) -> void:
	var grouped_height := grouped_card_dialog_scroll_height(dialog_card_size, source_items, source_groups, scene)
	scroll.custom_minimum_size = Vector2(0, grouped_height)
	scroll.size = Vector2(scroll.size.x, grouped_height)
	row.custom_minimum_size = Vector2(0, grouped_height - grouped_card_dialog_scrollbar_clearance(scene))
	row.size = Vector2(row.size.x, row.custom_minimum_size.y)


func create_grouped_assignment_source_slot_panel(
	scene: Object,
	source_items: Array,
	source_labels: Array,
	pokemon_slot: PokemonSlot,
	indices: Array,
	group_index: int,
	energy_card_size: Vector2
) -> PanelContainer:
	var group_panel := PanelContainer.new()
	group_panel.name = "EnergyAssignmentSourceGroup%d" % group_index
	group_panel.custom_minimum_size = Vector2(
		grouped_card_dialog_group_width(energy_card_size, indices.size()),
		grouped_card_dialog_slot_height(energy_card_size)
	)
	group_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	group_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	group_panel.add_theme_stylebox_override("panel", grouped_card_dialog_panel_style(group_index))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	group_panel.add_child(margin)

	var card_line := HBoxContainer.new()
	card_line.name = "EnergyAssignmentSourceCardLine"
	card_line.alignment = BoxContainer.ALIGNMENT_CENTER
	card_line.add_theme_constant_override("separation", 12)
	card_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_line.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_child(card_line)

	var header_view := BattleCardViewScript.new()
	prepare_grouped_energy_card_view(header_view, energy_card_size)
	header_view.set_clickable(false)
	header_view.setup_from_card_data(pokemon_slot.get_card_data(), scene.call("_battle_card_mode_for_slot", pokemon_slot))
	var header_top_card := pokemon_slot.get_top_card()
	if header_top_card != null and header_view.has_method("set_card_foil_owner_index"):
		header_view.call("set_card_foil_owner_index", header_top_card.owner_index)
	if scene.has_method("_sync_card_foil_effect_for_view"):
		scene.call("_sync_card_foil_effect_for_view", header_view)
	header_view.set_badges()
	header_view.set_battle_status(scene.call("_build_battle_status", pokemon_slot))
	card_line.add_child(header_view)

	for source_idx_variant: Variant in indices:
		var source_index := int(source_idx_variant)
		if source_index < 0 or source_index >= source_items.size():
			continue
		var source_view := BattleCardViewScript.new()
		prepare_grouped_energy_card_view(source_view, energy_card_size)
		source_view.set_clickable(true)
		setup_dialog_card_view(scene, source_view, source_items[source_index], dialog_label_at(source_labels, source_index))
		var source_scroll := scene.get("_dialog_assignment_source_scroll") as ScrollContainer
		if scene.has_method("_configure_card_gallery_card_view"):
			scene.call(
				"_configure_card_gallery_card_view",
				source_view,
				source_scroll,
				"assignment_source_cards"
			)
		source_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
			scene.call("_on_assignment_source_chosen", source_index)
		)
		source_view.right_clicked.connect(func(ci: CardInstance, cd: CardData) -> void:
			if ci != null and scene.has_method("_show_card_detail_for_instance"):
				scene.call("_show_card_detail_for_instance", ci)
				return
			if cd != null:
				scene.call("_show_card_detail", cd)
		)
		source_view.set_meta("assignment_source_index", source_index)
		source_view.set_meta("assignment_source_disabled", false)
		card_line.add_child(source_view)
	return group_panel


func add_assignment_source_card(
	scene: Object,
	source_items: Array,
	source_labels: Array,
	source_index: int,
	display_item: Variant = null,
	display_label: String = "",
	disabled: bool = false,
	disabled_badge: String = ""
) -> void:
	if (source_index < 0 or source_index >= source_items.size()) and display_item == null:
		return
	var dialog_assignment_source_row: HBoxContainer = scene.get("_dialog_assignment_source_row")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	var source_view := BattleCardViewScript.new()
	prepare_dialog_card_view(source_view, dialog_card_size)
	source_view.set_clickable(not disabled)
	var source_label: String = display_label
	if source_label == "" and source_index >= 0 and source_index < source_labels.size():
		source_label = str(source_labels[source_index])
	var source_item: Variant = display_item if display_item != null else source_items[source_index]
	setup_dialog_card_view(scene, source_view, source_item, source_label)
	var source_scroll := scene.get("_dialog_assignment_source_scroll") as ScrollContainer
	if scene.has_method("_configure_card_gallery_card_view"):
		scene.call(
			"_configure_card_gallery_card_view",
			source_view,
			source_scroll,
			"assignment_source_cards"
		)
	if disabled:
		source_view.set_disabled(true)
		if disabled_badge != "":
			source_view.set_badges(disabled_badge, "")
	else:
		source_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
			scene.call("_on_assignment_source_chosen", source_index)
		)
	source_view.right_clicked.connect(func(ci: CardInstance, cd: CardData) -> void:
		if ci != null and scene.has_method("_show_card_detail_for_instance"):
			scene.call("_show_card_detail_for_instance", ci)
			return
		if cd != null:
			scene.call("_show_card_detail", cd)
	)
	source_view.set_meta("assignment_source_index", source_index)
	source_view.set_meta("assignment_source_disabled", disabled)
	dialog_assignment_source_row.add_child(source_view)


func find_assignment_index_for_source(scene: Object, source_index: int) -> int:
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	for i: int in assignments.size():
		if int((assignments[i] as Dictionary).get("source_index", -1)) == source_index:
			return i
	return -1


func dialog_assignment_last_target_index(scene: Object) -> int:
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	if assignments.is_empty():
		return -1
	return int((assignments.back() as Dictionary).get("target_index", -1))


func on_assignment_source_chosen(scene: Object, source_index: int) -> void:
	_record_dialog_fresh_input(scene, "assignment_source")
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var source_items: Array = dialog_data.get("source_items", [])
	if source_index < 0 or source_index >= source_items.size():
		return
	var assigned_index := find_assignment_index_for_source(scene, source_index)
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	if assigned_index >= 0:
		assignments.remove_at(assigned_index)
		_replace_dictionary_array(scene, "_dialog_assignment_assignments", assignments)
		if int(scene.get("_dialog_assignment_selected_source_index")) == source_index:
			scene.set("_dialog_assignment_selected_source_index", -1)
		refresh_assignment_dialog_views(scene)
		return
	var max_assignments := int(dialog_data.get("max_select", source_items.size()))
	if max_assignments > 0 and assignments.size() >= max_assignments:
		scene.call("_log", _bt(scene, "battle.dialog.assign_limit_reached"))
		return
	if assignment_source_bucket_limit_reached(dialog_data, assignments, source_index):
		scene.call("_log", _bt(scene, "battle.dialog.assign_limit_reached"))
		return
	if int(scene.get("_dialog_assignment_selected_source_index")) == source_index:
		scene.set("_dialog_assignment_selected_source_index", -1)
	else:
		scene.set("_dialog_assignment_selected_source_index", source_index)
	refresh_assignment_dialog_views(scene)


func on_assignment_target_chosen(scene: Object, target_index: int) -> void:
	_record_dialog_fresh_input(scene, "assignment_target")
	var selected_source_index := int(scene.get("_dialog_assignment_selected_source_index"))
	if selected_source_index < 0:
		scene.call("_log", _bt(scene, "battle.dialog.choose_target"))
		return
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var source_items: Array = dialog_data.get("source_items", [])
	var target_items: Array = dialog_data.get("target_items", [])
	if selected_source_index >= source_items.size():
		return
	if target_index < 0 or target_index >= target_items.size():
		return
	var exclude_map: Dictionary = dialog_data.get("source_exclude_targets", {})
	var excluded: Array = exclude_map.get(selected_source_index, [])
	if target_index in excluded:
		scene.call("_log", _bt(scene, "battle.dialog.target_invalid"))
		return
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	if bool(dialog_data.get("single_target_only", false)):
		for assignment_variant: Variant in assignments:
			if assignment_variant is Dictionary and int((assignment_variant as Dictionary).get("target_index", -1)) != target_index:
				scene.call("_log", _bt(scene, "battle.dialog.target_invalid"))
				return
	var max_per_target: int = int(dialog_data.get("max_assignments_per_target", 0))
	if max_per_target > 0 and _count_assignments_for_target_index(assignments, target_index) >= max_per_target:
		scene.call("_log", _bt(scene, "battle.dialog.target_invalid"))
		return
	assignments.append({
		"source_index": selected_source_index,
		"source": source_items[selected_source_index],
		"target_index": target_index,
		"target": target_items[target_index],
	})
	_replace_dictionary_array(scene, "_dialog_assignment_assignments", assignments)
	scene.set("_dialog_assignment_selected_source_index", -1)
	refresh_assignment_dialog_views(scene)
	if should_auto_confirm_assignment(dialog_data, assignments.size()):
		confirm_assignment_dialog(scene)


func should_auto_confirm_assignment(dialog_data: Dictionary, assignment_count: int) -> bool:
	var max_assignments := int(dialog_data.get("max_select", 0))
	return (
		bool(dialog_data.get("auto_confirm_at_max", false))
		and
		not bool(dialog_data.get(
			"assignment_require_confirm",
			dialog_data.get("field_assignment_require_confirm", false)
		))
		and max_assignments > 0
		and assignment_count == max_assignments
	)


func refresh_assignment_dialog_views(scene: Object) -> void:
	var dialog_assignment_source_row: HBoxContainer = scene.get("_dialog_assignment_source_row")
	var dialog_assignment_target_row: HBoxContainer = scene.get("_dialog_assignment_target_row")
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	var selected_source_index := int(scene.get("_dialog_assignment_selected_source_index"))
	for child: Node in dialog_assignment_source_row.get_children():
		if not (child is BattleCardView):
			continue
		var card_view := child as BattleCardView
		if bool(card_view.get_meta("assignment_source_disabled", false)):
			card_view.set_selected(false)
			card_view.set_selectable_hint(false)
			card_view.set_disabled(true)
			continue
		var idx := int(card_view.get_meta("assignment_source_index", -1))
		var source_selected := idx == selected_source_index
		var source_assigned := find_assignment_index_for_source(scene, idx) >= 0
		var source_bucket_full := false if source_assigned else assignment_source_bucket_limit_reached(dialog_data, assignments, idx)
		card_view.set_selected(source_selected)
		card_view.set_selectable_hint(not source_selected and not source_assigned and not source_bucket_full)
		card_view.set_disabled(source_assigned or source_bucket_full)
	for child: Node in dialog_assignment_target_row.get_children():
		if not (child is BattleCardView):
			continue
		var target_view := child as BattleCardView
		var idx := int(target_view.get_meta("assignment_target_index", -1))
		var target_selected := idx == dialog_assignment_last_target_index(scene)
		target_view.set_selected(target_selected)
		target_view.set_selectable_hint(not target_selected)
		target_view.set_disabled(false)
	update_assignment_dialog_state(scene)


func update_assignment_dialog_state(scene: Object) -> void:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var summary_label: Label = scene.get("_dialog_assignment_summary_lbl")
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	var min_assignments := int(dialog_data.get("min_select", 0))
	var max_assignments := int(dialog_data.get("max_select", 0))
	dialog_confirm.disabled = assignments.size() < min_assignments

	var target_counts: Dictionary = {}
	for assignment_variant: Variant in assignments:
		if not (assignment_variant is Dictionary):
			continue
		var assignment := assignment_variant as Dictionary
		var target: Variant = assignment.get("target")
		if target == null:
			continue
		target_counts[target] = int(target_counts.get(target, 0)) + 1

	var summary_parts: Array[String] = []
	for target: Variant in target_counts.keys():
		if target is PokemonSlot:
			var slot: PokemonSlot = target as PokemonSlot
			summary_parts.append("%s×%d" % [_slot_display_name(slot), int(target_counts[target])])

	var summary := ""
	if max_assignments > 0:
		summary = _bt(scene, "battle.dialog.assignment_summary", {
			"assigned_count": assignments.size(),
			"max_assignments": max_assignments,
		})
	else:
		summary = _bt(scene, "battle.dialog.assignment_summary_unlimited", {
			"assigned_count": assignments.size(),
		})
	var selected_source_index := int(scene.get("_dialog_assignment_selected_source_index"))
	if selected_source_index >= 0:
		var source_items: Array = dialog_data.get("source_items", [])
		if selected_source_index < source_items.size():
			var selected_source: Variant = source_items[selected_source_index]
			if selected_source is CardInstance:
				summary += " " + _bt(scene, "battle.dialog.assignment_current_source", {
					"name": (selected_source as CardInstance).card_data.display_name(),
				})
	if not summary_parts.is_empty():
		summary += " 已分配到：" + ", ".join(summary_parts)
	summary_label.text = summary


func _count_assignments_for_target_index(assignments: Array, target_index: int) -> int:
	var count := 0
	for assignment_variant: Variant in assignments:
		if not (assignment_variant is Dictionary):
			continue
		if int((assignment_variant as Dictionary).get("target_index", -1)) == target_index:
			count += 1
	return count


func assignment_source_bucket_key(dialog_data: Dictionary, source_index: int) -> String:
	var bucket_keys: Array = dialog_data.get("source_bucket_keys", [])
	if source_index < 0 or source_index >= bucket_keys.size():
		return ""
	return str(bucket_keys[source_index])


func count_assignments_for_source_bucket(dialog_data: Dictionary, assignments: Array, bucket_key: String) -> int:
	if bucket_key == "":
		return 0
	var count := 0
	for assignment_variant: Variant in assignments:
		if not (assignment_variant is Dictionary):
			continue
		var assignment := assignment_variant as Dictionary
		var source_index := int(assignment.get("source_index", -1))
		if assignment_source_bucket_key(dialog_data, source_index) == bucket_key:
			count += 1
	return count


func assignment_source_bucket_limit_reached(dialog_data: Dictionary, assignments: Array, source_index: int) -> bool:
	var bucket_key := assignment_source_bucket_key(dialog_data, source_index)
	if bucket_key == "":
		return false
	var bucket_limits: Dictionary = dialog_data.get("max_assignments_per_source_bucket", {})
	if not bucket_limits.has(bucket_key):
		return false
	var limit := int(bucket_limits.get(bucket_key, 0))
	if limit <= 0:
		return false
	return count_assignments_for_source_bucket(dialog_data, assignments, bucket_key) >= limit


func on_dialog_card_chosen(scene: Object, real_index: int) -> void:
	_record_dialog_fresh_input(scene, "dialog_card")
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var min_select := int(dialog_data.get("min_select", 1))
	var max_select := int(dialog_data.get("max_select", 1))
	var is_multi := max_select > 1 or min_select > 1
	if not is_multi:
		if scene.has_method("_begin_modal_pointer_drain"):
			scene.call("_begin_modal_pointer_drain", "dialog_card")
		confirm_dialog_selection(scene, PackedInt32Array([real_index]))
		return
	if not bool(scene.call("_toggle_dialog_card_choice", real_index, max_select)):
		return
	sync_dialog_card_selection(scene)
	update_dialog_confirm_state(scene)
	var selected_indices: Array = scene.get("_dialog_card_selected_indices")
	if (
		bool(dialog_data.get("auto_confirm_at_max", false))
		and max_select > 0
		and selected_indices.size() == max_select
	):
		var selected := PackedInt32Array()
		for selected_index: int in selected_indices:
			selected.append(selected_index)
		confirm_dialog_selection(scene, selected)


func card_dialog_should_show_selectable_hint(_selected: bool) -> bool:
	return false


func sync_dialog_card_selection(scene: Object) -> void:
	var dialog_card_row: HBoxContainer = scene.get("_dialog_card_row")
	var selected_indices: Array = scene.get("_dialog_card_selected_indices")
	for child: Node in dialog_card_row.get_children():
		sync_dialog_card_selection_recursive(child, selected_indices)


func sync_dialog_card_selection_recursive(node: Node, selected_indices: Array) -> void:
	if node is BattleCardView:
		var card_view := node as BattleCardView
		var idx := int(card_view.get_meta("dialog_choice_index", -1))
		var selected := idx >= 0 and idx in selected_indices
		card_view.set_selected(selected)
		card_view.set_selectable_hint(idx >= 0 and card_dialog_should_show_selectable_hint(selected))
	for child: Node in node.get_children():
		sync_dialog_card_selection_recursive(child, selected_indices)


func update_dialog_confirm_state(scene: Object) -> void:
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	var dialog_list: ItemList = scene.get("_dialog_list")
	var min_select := int(dialog_data.get("min_select", 1))
	if bool(scene.get("_dialog_assignment_mode")):
		update_assignment_dialog_state(scene)
		return
	if bool(scene.get("_dialog_card_mode")):
		var selected_indices: Array = scene.get("_dialog_card_selected_indices")
		if selected_indices.is_empty() and _library_search_requires_explicit_empty_selection(scene):
			dialog_confirm.disabled = true
		else:
			dialog_confirm.disabled = selected_indices.size() < min_select
		update_dialog_status_text(scene)
		return
	if not dialog_list.visible:
		var hud_selected: Array = scene.get("_dialog_multi_selected_indices")
		dialog_confirm.disabled = hud_selected.size() < min_select
		return
	if dialog_list.select_mode == ItemList.SELECT_SINGLE:
		dialog_confirm.disabled = dialog_list.get_selected_items().size() < min_select
	else:
		var multi_selected: Array = scene.get("_dialog_multi_selected_indices")
		dialog_confirm.disabled = multi_selected.size() < min_select


func update_dialog_status_text(scene: Object) -> void:
	var dialog_status_lbl: Label = scene.get("_dialog_status_lbl")
	if dialog_status_lbl == null or not dialog_status_lbl.visible:
		return
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var selected_indices: Array = scene.get("_dialog_card_selected_indices")
	var min_select := int(dialog_data.get("min_select", 1))
	var max_select := int(dialog_data.get("max_select", 1))
	if max_select > 1:
		dialog_status_lbl.text = _bt(scene, "battle.dialog.card_status_with_max", {
			"selected_count": selected_indices.size(),
			"min_select": min_select,
			"max_select": max_select,
		})
	else:
		dialog_status_lbl.text = _bt(scene, "battle.dialog.card_status", {
			"selected_count": selected_indices.size(),
			"min_select": min_select,
		})


func _stage_effect_interaction_response(scene: Object, intent: String, source: String = "dialog") -> void:
	if str(scene.get("_pending_choice")) != "effect_interaction":
		return
	var dialog_data: Dictionary = scene.get("_dialog_data")
	scene.set_meta("effect_interaction_response", {
		"source": source,
		"intent": intent,
		"generation": int(dialog_data.get("interaction_generation", -1)),
		"step_index": int(dialog_data.get("interaction_step_index", -1)),
		"step_id": str(dialog_data.get("interaction_step_id", "")),
	})


func confirm_dialog_selection(
	scene: Object,
	sel_items: PackedInt32Array,
	origin_position: Vector2 = Vector2(-1.0, -1.0),
	choice_intent: String = BaseEffect.INTERACTION_INTENT_SELECT
) -> void:
	var slot_suppression_mode := _dialog_selection_slot_suppression_mode(scene, sel_items)
	if origin_position.x >= 0.0 and origin_position.y >= 0.0:
		mark_modal_input_consumed_at_position(scene, "dialog_confirm_selection", origin_position, slot_suppression_mode)
	else:
		mark_modal_input_consumed(scene, "dialog_confirm_selection", slot_suppression_mode)
	_begin_dialog_modal_transition(scene)
	scene.call(
		"_runtime_log",
		"confirm_dialog_selection",
		"choice=%s selected=%s %s" % [scene.get("_pending_choice"), JSON.stringify(sel_items), scene.call("_dialog_state_snapshot")]
	)
	_stage_effect_interaction_response(scene, choice_intent)
	_hide_dialog_overlay(scene, "dialog_confirm_selection")
	scene.call("_handle_dialog_choice", sel_items)
	_end_dialog_modal_transition(scene)


func on_dialog_item_selected(scene: Object, idx: int) -> void:
	_record_dialog_fresh_input(scene, "dialog_item")
	var dialog_list: ItemList = scene.get("_dialog_list")
	var dialog_confirm: Button = scene.get("_dialog_confirm")
	if dialog_list.select_mode != ItemList.SELECT_SINGLE:
		return
	dialog_confirm.disabled = false
	if not bool(scene.get("_dialog_card_mode")):
		if scene.has_method("_begin_modal_pointer_drain"):
			scene.call("_begin_modal_pointer_drain", "dialog_item")
		confirm_dialog_selection(scene, PackedInt32Array([idx]))


func on_dialog_item_multi_selected(scene: Object, idx: int, selected: bool) -> void:
	_record_dialog_fresh_input(scene, "dialog_item_multi")
	var dialog_list: ItemList = scene.get("_dialog_list")
	if dialog_list.select_mode == ItemList.SELECT_SINGLE:
		return
	var selected_indices: Array = scene.get("_dialog_multi_selected_indices")
	if selected:
		if idx not in selected_indices:
			selected_indices.append(idx)
	else:
		selected_indices.erase(idx)
	_replace_int_array(scene, "_dialog_multi_selected_indices", selected_indices)
	update_dialog_confirm_state(scene)


func on_dialog_confirm(scene: Object) -> void:
	if _consume_dialog_action_if_stale(scene, "confirm"):
		return
	scene.set("_dialog_user_input_source", "dialog_confirm")
	var confirm_origin := _dialog_action_input_position(scene, "confirm")
	var slot_suppression_mode := _dialog_slot_suppression_mode(scene)
	if _valid_input_position(confirm_origin):
		mark_modal_input_consumed_at_position(scene, "dialog_confirm", confirm_origin, slot_suppression_mode)
	else:
		mark_modal_input_consumed(scene, "dialog_confirm", slot_suppression_mode)
	if bool(scene.get("_dialog_assignment_mode")):
		confirm_assignment_dialog(scene)
		return
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var sel_items := PackedInt32Array()
	if bool(scene.get("_dialog_card_mode")):
		var selected_indices: Array = scene.get("_dialog_card_selected_indices")
		for selected_idx: int in selected_indices:
			sel_items.append(selected_idx)
	else:
		var dialog_list: ItemList = scene.get("_dialog_list")
		if dialog_list.visible:
			sel_items = dialog_list.get_selected_items()
		else:
			var hud_selected: Array = scene.get("_dialog_multi_selected_indices")
			for selected_idx: int in hud_selected:
				sel_items.append(selected_idx)
	var min_select := int(dialog_data.get("min_select", 1))
	var max_select := int(dialog_data.get("max_select", 1))
	if sel_items.is_empty() and _library_search_requires_explicit_empty_selection(scene):
		scene.call("_runtime_log", "dialog_empty_confirm_blocked", "choice=%s %s" % [scene.get("_pending_choice"), scene.call("_dialog_state_snapshot")])
		update_dialog_confirm_state(scene)
		return
	if sel_items.size() < min_select:
		scene.call("_log", _bt(scene, "battle.dialog.select_at_least", {"count": min_select}))
		return
	if max_select > 0 and sel_items.size() > max_select:
		scene.call("_log", _bt(scene, "battle.dialog.select_at_most", {"count": max_select}))
		return
	confirm_dialog_selection(scene, sel_items, confirm_origin)


func on_dialog_cancel(scene: Object) -> void:
	if _consume_dialog_action_if_stale(scene, "cancel"):
		return
	scene.set("_dialog_user_input_source", "dialog_cancel")
	var cancel_origin := _dialog_action_input_position(scene, "cancel")
	var slot_suppression_mode := _dialog_slot_suppression_mode(scene)
	if _valid_input_position(cancel_origin):
		mark_modal_input_consumed_at_position(scene, "dialog_cancel", cancel_origin, slot_suppression_mode)
	else:
		mark_modal_input_consumed(scene, "dialog_cancel", slot_suppression_mode)
	var dialog_data: Dictionary = scene.get("_dialog_data")
	if _portrait_library_search_uses_cancel_slot_for_empty_selection(scene):
		scene.call(
			"_runtime_log",
			"portrait_library_search_empty_selection",
			"choice=%s %s" % [scene.get("_pending_choice"), scene.call("_dialog_state_snapshot")]
		)
		_replace_int_array(scene, "_dialog_card_selected_indices", [])
		confirm_dialog_selection(
			scene,
			PackedInt32Array(),
			cancel_origin,
			BaseEffect.INTERACTION_INTENT_DECLINE
		)
		return
	if not bool(dialog_data.get("allow_cancel", true)):
		scene.call(
			"_runtime_log",
			"dialog_cancel_blocked",
			"choice=%s %s" % [scene.get("_pending_choice"), scene.call("_dialog_state_snapshot")]
		)
		return
	scene.call(
		"_runtime_log",
		"dialog_cancel",
		"choice=%s %s" % [scene.get("_pending_choice"), scene.call("_dialog_state_snapshot")]
	)
	if str(scene.get("_pending_choice")) == "effect_interaction" and bool(dialog_data.get("cancel_resolves_empty", false)):
		_hide_dialog_overlay(scene, "dialog_cancel_empty_selection")
		_replace_int_array(scene, "_dialog_card_selected_indices", [])
		reset_dialog_assignment_state(scene)
		_begin_dialog_modal_transition(scene)
		_stage_effect_interaction_response(scene, BaseEffect.INTERACTION_INTENT_DECLINE, "dialog_cancel")
		scene.call("_handle_effect_interaction_choice", PackedInt32Array())
		_end_dialog_modal_transition(scene)
		return
	_hide_dialog_overlay(scene, "dialog_cancel")
	_replace_int_array(scene, "_dialog_card_selected_indices", [])
	reset_dialog_assignment_state(scene)
	if str(scene.get("_pending_choice")) == "effect_interaction":
		scene.call("_reset_effect_interaction")
	scene.set("_pending_choice", "")
	if scene.has_method("_maybe_run_ai"):
		scene.call("_maybe_run_ai")


func dismiss_stale_turn_action_dialog(scene: Object) -> bool:
	if not BattleTurnActionPolicyScript.is_human_turn_only_prompt(str(scene.get("_pending_choice"))):
		return false
	_hide_dialog_overlay(scene, "stale_turn_action_prompt")
	_replace_int_array(scene, "_dialog_multi_selected_indices", [])
	_replace_int_array(scene, "_dialog_card_selected_indices", [])
	reset_dialog_assignment_state(scene)
	scene.set("_pending_choice", "")
	return true


func confirm_assignment_dialog(scene: Object) -> void:
	mark_modal_input_consumed(scene, "assignment_confirm")
	var dialog_data: Dictionary = scene.get("_dialog_data")
	var min_select := int(dialog_data.get("min_select", 0))
	var max_select := int(dialog_data.get("max_select", 0))
	var assignments: Array = scene.get("_dialog_assignment_assignments")
	var assignment_count := assignments.size()
	if assignment_count < min_select:
		scene.call("_log", _bt(scene, "battle.dialog.assign_at_least", {"count": min_select}))
		return
	if max_select > 0 and assignment_count > max_select:
		scene.call("_log", _bt(scene, "battle.dialog.assign_at_most", {"count": max_select}))
		return
	var stored_assignments: Array[Dictionary] = []
	for assignment_variant: Variant in assignments:
		if assignment_variant is Dictionary:
			stored_assignments.append((assignment_variant as Dictionary).duplicate())
	var pending_step_index := int(scene.get("_pending_effect_step_index"))
	var pending_steps: Array = scene.get("_pending_effect_steps")
	if pending_step_index < 0 or pending_step_index >= pending_steps.size():
		var pending_choice := str(scene.get("_pending_choice"))
		if pending_choice == "heavy_baton_target":
			_hide_dialog_overlay(scene, "heavy_baton_assignment_confirm")
			reset_dialog_assignment_state(scene)
			scene.call("_commit_heavy_baton_assignment", stored_assignments)
			return
		if pending_choice == "exp_share_target":
			_hide_dialog_overlay(scene, "exp_share_assignment_confirm")
			reset_dialog_assignment_state(scene)
			scene.call("_commit_exp_share_assignment", stored_assignments)
			return
		return
	_hide_dialog_overlay(scene, "effect_assignment_confirm")
	reset_dialog_assignment_state(scene)
	scene.call("_commit_effect_assignment_selection", stored_assignments)


func _current_player_index(scene: Object) -> int:
	var gsm: Variant = scene.get("_gsm")
	if gsm != null and gsm.game_state != null:
		return gsm.game_state.current_player_index
	return -1


func _turn_number(scene: Object) -> int:
	var gsm: Variant = scene.get("_gsm")
	if gsm != null and gsm.game_state != null:
		return gsm.game_state.turn_number
	return 0


func show_setup_active_dialog(scene: Object, pi: int) -> void:
	var gsm: Variant = scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[pi]
	var basics: Array[CardInstance] = player.get_basic_pokemon_in_hand()
	var items: Array[String] = []
	for card: CardInstance in basics:
		items.append("%s (HP %d)" % [card.card_data.display_name(), card.card_data.hp])
	scene.set("_pending_choice", "setup_active_%d" % pi)
	var dialog_data := {
		"basics": basics,
		"player": pi,
		"presentation": "cards",
		"card_items": basics,
		"choice_labels": items,
	}
	var is_author_prompt: bool = (
		scene.has_method("_is_author_setup_active_canary_prompt")
		and bool(scene.call("_is_author_setup_active_canary_prompt", pi))
	)
	if is_author_prompt:
		scene.set("_dialog_data", dialog_data)
		scene.set("_dialog_items_data", items)
		var author_dialog_overlay: Panel = scene.get("_dialog_overlay")
		var author_dialog_cancel: Button = scene.get("_dialog_cancel")
		if author_dialog_overlay != null:
			author_dialog_overlay.visible = false
		if author_dialog_cancel != null:
			author_dialog_cancel.visible = false
		scene.call_deferred("_maybe_run_author_setup_active_canary", pi)
		return
	var is_ai_prompt: bool = scene.has_method("_is_runtime_ai_player") \
		and bool(scene.call("_is_runtime_ai_player", pi))
	if is_ai_prompt:
		scene.set("_dialog_data", dialog_data)
		scene.set("_dialog_items_data", items)
		var dialog_overlay: Panel = scene.get("_dialog_overlay")
		var dialog_cancel: Button = scene.get("_dialog_cancel")
		if dialog_overlay != null:
			dialog_overlay.visible = false
		if dialog_cancel != null:
			dialog_cancel.visible = false
	else:
		show_dialog(scene, "玩家 %d：选择战斗宝可梦" % (pi + 1), items, dialog_data)
		var dialog_cancel: Button = scene.get("_dialog_cancel")
		if dialog_cancel != null:
			dialog_cancel.visible = false
	scene.call("_maybe_run_ai")


func show_setup_bench_dialog(scene: Object, pi: int) -> void:
	var gsm: Variant = scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[pi]
	if player.is_bench_full():
		scene.set("_pending_choice", "")
		scene.set("_dialog_data", {})
		scene.set("_dialog_items_data", [])
		scene.call("_after_setup_bench", pi)
		_schedule_followup_ai_step_if_ready(scene, gsm)
		return
	var basics: Array[CardInstance] = player.get_basic_pokemon_in_hand()
	if basics.is_empty():
		scene.set("_pending_choice", "")
		scene.set("_dialog_data", {})
		scene.set("_dialog_items_data", [])
		scene.call("_after_setup_bench", pi)
		_schedule_followup_ai_step_if_ready(scene, gsm)
		return
	var items: Array[String] = ["完成"]
	for card: CardInstance in basics:
		items.append("%s (HP %d)" % [card.card_data.display_name(), card.card_data.hp])
	var choice_indices: Array[int] = []
	for card_idx: int in basics.size():
		choice_indices.append(card_idx + 1)
	scene.set("_pending_choice", "setup_bench_%d" % pi)
	var dialog_data := {
		"cards": basics,
		"player": pi,
		"presentation": "cards",
		"card_items": basics,
		"card_indices": choice_indices,
		"choice_labels": items.slice(1),
		"utility_actions": [{"label": "完成", "index": 0}],
	}
	var is_ai_prompt: bool = scene.has_method("_is_runtime_ai_player") \
		and bool(scene.call("_is_runtime_ai_player", pi))
	if is_ai_prompt:
		scene.set("_dialog_data", dialog_data)
		scene.set("_dialog_items_data", items)
		var dialog_overlay: Panel = scene.get("_dialog_overlay")
		var dialog_cancel: Button = scene.get("_dialog_cancel")
		if dialog_overlay != null:
			dialog_overlay.visible = false
		if dialog_cancel != null:
			dialog_cancel.visible = false
	else:
		show_dialog(scene, "玩家 %d：选择备战宝可梦（可选，最多 5 只）" % (pi + 1), items, dialog_data)
		var dialog_cancel: Button = scene.get("_dialog_cancel")
		if dialog_cancel != null:
			dialog_cancel.visible = false
	scene.call("_maybe_run_ai")


func _schedule_followup_ai_step_if_ready(scene: Object, gsm: Variant) -> void:
	if scene == null or gsm == null or gsm.game_state == null:
		return
	var owner: Variant = scene.call("_runtime_ai_owner") if scene.has_method("_runtime_ai_owner") else null
	if owner == null:
		return
	if str(scene.get("_pending_choice")) != "":
		return
	if gsm.game_state.phase == GameState.GamePhase.SETUP:
		return
	if gsm.game_state.current_player_index != int(owner.player_index):
		return
	if bool(scene.get("_ai_running")):
		scene.set("_ai_followup_requested", true)
		return
	if bool(scene.get("_ai_step_scheduled")):
		return
	scene.set("_ai_step_scheduled", true)
	scene.call_deferred("_run_ai_step")


func show_send_out_dialog(scene: Object, pi: int) -> void:
	var gsm: Variant = scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[pi]
	var bench_choices: Array[PokemonSlot] = []
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot != null and not gsm.effect_processor.is_effectively_knocked_out(bench_slot, gsm.game_state):
			bench_choices.append(bench_slot)
	scene.set("_pending_choice", "send_out")
	scene.set("_dialog_data", {
		"player": pi,
		"bench": bench_choices,
		"allow_cancel": false,
		"min_select": 1,
		"max_select": 1,
	})
	scene.call("_show_field_slot_choice", "请选择玩家%d要派出的宝可梦" % (pi + 1), bench_choices, scene.get("_dialog_data"))

func show_heavy_baton_dialog(
	scene: Object,
	pi: int,
	bench_targets: Array[PokemonSlot],
	energy_count: int,
	source_name: String,
	source_slot: PokemonSlot = null,
	source_energy: Array[CardInstance] = []
) -> void:
	scene.set("_pending_choice", "heavy_baton_target")
	var dialog_data := {
		"player": pi,
		"bench": bench_targets.duplicate(),
		"source_slot": source_slot,
		"source_energy": source_energy.duplicate(),
		"min_select": 1,
		"max_select": maxi(1, mini(energy_count, source_energy.size())),
		"allow_cancel": false,
	}
	scene.set("_dialog_data", dialog_data)
	if source_slot != null and not source_energy.is_empty():
		var source_labels: Array[String] = []
		var source_indices: Array[int] = []
		for i: int in source_energy.size():
			var energy: CardInstance = source_energy[i]
			source_labels.append(energy.card_data.display_name() if energy != null and energy.card_data != null else "")
			source_indices.append(i)
		var target_labels: Array[String] = []
		for target: PokemonSlot in bench_targets:
			target_labels.append(_slot_display_name(target))
		var assignment_data := dialog_data.duplicate(true)
		assignment_data.merge({
			"ui_mode": "card_assignment",
			"source_items": source_energy.duplicate(),
			"source_labels": source_labels,
			"source_groups": [{"slot": source_slot, "card_indices": source_indices, "energy_indices": source_indices}],
			"target_items": bench_targets.duplicate(),
			"target_labels": target_labels,
			"single_target_only": true,
			"min_select": 1,
			"max_select": maxi(1, mini(energy_count, source_energy.size())),
			"allow_cancel": false,
		}, true)
		scene.call("_show_dialog", "%s：选择要转移的能量和接收宝可梦" % source_name, [], assignment_data)
		return
	scene.call(
		"_show_field_slot_choice",
		"%s：选择接收 %d 个能量的备战宝可梦" % [source_name, energy_count],
		bench_targets,
		scene.get("_dialog_data")
	)


func show_exp_share_dialog(
	scene: Object,
	pi: int,
	bench_targets: Array[PokemonSlot],
	source_slot: PokemonSlot,
	source_energy: Array[CardInstance]
) -> void:
	scene.set("_pending_choice", "exp_share_target")
	var dialog_data := {
		"player": pi,
		"bench": bench_targets.duplicate(),
		"source_slot": source_slot,
		"source_energy": source_energy.duplicate(),
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}
	scene.set("_dialog_data", dialog_data)
	var source_labels: Array[String] = []
	var source_indices: Array[int] = []
	for i: int in source_energy.size():
		var energy: CardInstance = source_energy[i]
		source_labels.append(energy.card_data.display_name() if energy != null and energy.card_data != null else "")
		source_indices.append(i)
	var target_labels: Array[String] = []
	for target: PokemonSlot in bench_targets:
		target_labels.append(_slot_display_name(target))
	var assignment_data := dialog_data.duplicate(true)
	assignment_data.merge({
		"ui_mode": "card_assignment",
		"source_items": source_energy.duplicate(),
		"source_labels": source_labels,
		"source_groups": [{"slot": source_slot, "card_indices": source_indices, "energy_indices": source_indices}],
		"target_items": bench_targets.duplicate(),
		"target_labels": target_labels,
		"single_target_only": true,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}, true)
	scene.call("_show_dialog", "学习装置：选择要转移的能量和接收宝可梦", [], assignment_data)


func show_pokemon_action_dialog(scene: Object, cp: int, slot: PokemonSlot, include_attacks: bool) -> void:
	var gsm: Variant = scene.get("_gsm")
	var card_data: CardData = slot.get_card_data()
	var items: Array[String] = []
	var actions: Array[Dictionary] = []
	var action_items: Array[Dictionary] = []
	gsm.effect_processor.register_pokemon_card(card_data)
	var effect: BaseEffect = gsm.effect_processor.get_effect(card_data.effect_id)
	var is_active_slot := false
	if gsm != null and gsm.game_state != null and cp >= 0 and cp < gsm.game_state.players.size():
		is_active_slot = slot == gsm.game_state.players[cp].active_pokemon
	var should_list_attacks := include_attacks or not is_active_slot
	for i: int in card_data.abilities.size():
		var ability: Dictionary = card_data.abilities[i]
		var ability_name := CardData.dictionary_display_name(ability)
		var ability_text := CardData.dictionary_display_text(ability)
		var is_passive := effect != null and not effect.has_method("can_use_ability")
		var can_use := false
		var ability_reason := "%s 当前无法使用特性" % card_data.display_name()
		if is_passive:
			ability_reason = (
				"被动特性，无需手动使用；从手牌打出进化宝可梦时会自动生效。"
				if effect.has_method("allows_early_evolution")
				else "被动特性，无需手动使用；满足卡面条件时会自动生效。"
			)
		elif effect != null and effect.has_method("can_use_ability"):
			can_use = gsm.effect_processor.can_use_ability(slot, gsm.game_state, i)
			ability_reason = "" if can_use else gsm.effect_processor.get_ability_unusable_reason(slot, gsm.game_state, i)
		items.append("%s[特性] %s" % ["[被动] " if is_passive else ("" if can_use else "[不可用] "), ability_name])
		actions.append({
			"type": "passive_ability" if is_passive else "ability",
			"slot": slot,
			"ability_index": i,
			"enabled": can_use,
			"reason": ability_reason,
		})
		action_items.append(_build_pokemon_action_item(
			"ability",
			"特性",
			ability_name,
			"被动生效" if is_passive else "",
			_action_body_from_text(ability_text),
			can_use,
			ability_reason
		))
	for granted: Dictionary in gsm.effect_processor.get_granted_abilities(slot, gsm.game_state):
		var can_use_granted: bool = bool(granted.get("enabled", false))
		var granted_name := str(granted.get("name", ""))
		var granted_index := int(granted.get("ability_index", card_data.abilities.size()))
		var granted_reason: String = "" if can_use_granted else gsm.effect_processor.get_ability_unusable_reason(slot, gsm.game_state, granted_index)
		items.append("%s[特性] %s" % ["" if can_use_granted else "[不可用] ", granted_name])
		actions.append({
			"type": "ability",
			"slot": slot,
			"ability_index": granted_index,
			"enabled": can_use_granted,
			"reason": granted_reason,
		})
		action_items.append(_build_pokemon_action_item(
			"ability",
			"特性",
			granted_name,
			"赋予",
			_action_body_from_text(str(granted.get("text", "由场上效果赋予的特性。"))),
			can_use_granted,
			granted_reason
		))
	if should_list_attacks:
		for i: int in card_data.attacks.size():
			var attack: Dictionary = card_data.attacks[i]
			var attack_name := CardData.dictionary_display_name(attack)
			var can_use_attack := false
			var attack_reason := "只有战斗区宝可梦可以使用招式"
			var preview_damage := 0
			if include_attacks and is_active_slot:
				can_use_attack = gsm.can_use_attack(cp, i)
				attack_reason = "" if can_use_attack else gsm.get_attack_unusable_reason(cp, i)
				preview_damage = gsm.get_attack_preview_damage(cp, i)
			items.append("%s[招式] %s [%s] %s" % [
				"" if can_use_attack else "[不可用] ",
				attack_name,
				str(attack.get("cost", "")),
				str(attack.get("damage", "")),
			])
			actions.append({
				"type": "attack",
				"slot": slot,
				"attack_index": i,
				"enabled": can_use_attack,
				"reason": attack_reason,
			})
			action_items.append(_build_pokemon_action_item(
				"attack",
				"招式",
				attack_name,
				_attack_damage_meta_text(attack, preview_damage),
				_attack_body_text(attack, preview_damage),
				can_use_attack,
				attack_reason,
				str(attack.get("cost", ""))
			))
		for granted_attack: Dictionary in gsm.effect_processor.get_granted_attacks(slot, gsm.game_state):
			var granted_can_use := false
			var granted_reason := "只有战斗区宝可梦可以使用招式"
			if include_attacks and is_active_slot:
				granted_can_use = bool(scene.call("_can_use_granted_attack", cp, slot, granted_attack))
				granted_reason = "" if granted_can_use else str(scene.call("_get_granted_attack_unusable_reason", cp, slot, granted_attack))
			items.append("%s[招式] %s [%s]" % [
				"" if granted_can_use else "[不可用] ",
				str(granted_attack.get("name", "")),
				str(granted_attack.get("cost", "")),
			])
			actions.append({
				"type": "granted_attack",
				"slot": slot,
				"granted_attack": granted_attack,
				"enabled": granted_can_use,
				"reason": granted_reason,
			})
			action_items.append(_build_pokemon_action_item(
				"granted_attack",
				"招式",
				str(granted_attack.get("name", "")),
				_attack_damage_meta_text(granted_attack, 0),
				_attack_body_text(granted_attack, 0),
				granted_can_use,
				granted_reason,
				str(granted_attack.get("cost", ""))
			))
		if include_attacks and is_active_slot:
			var can_retreat: bool = gsm.rule_validator.can_retreat(gsm.game_state, cp, gsm.effect_processor)
			var retreat_cost: int = gsm.effect_processor.get_effective_retreat_cost(slot, gsm.game_state)
			var retreat_reason: String = "" if can_retreat else gsm.rule_validator.get_retreat_unusable_reason(gsm.game_state, cp, gsm.effect_processor)
			items.append("%s[行动] 撤退" % ("" if can_retreat else "[不可用] "))
			actions.append({
				"type": "retreat",
				"enabled": can_retreat,
				"reason": retreat_reason,
			})
			action_items.append(_build_pokemon_action_item(
				"retreat",
				"行动",
				"撤退",
				"费用 %d" % retreat_cost,
				"支付撤退费用，选择 1 只备战宝可梦与战斗宝可梦交换。",
				can_retreat,
				retreat_reason
			))
	if actions.is_empty():
		var empty_reason := "%s 当前没有可执行的行动" % card_data.display_name()
		items.append("[不可用] 当前没有可执行行动")
		actions.append({
			"type": "noop",
			"enabled": false,
			"reason": empty_reason,
		})
		action_items.append(_build_pokemon_action_item(
			"noop",
			"行动",
			"当前没有可执行行动",
			"",
			"这只宝可梦当前没有可用的特性、招式或撤退操作。",
			false,
			empty_reason
		))
	scene.set("_pending_choice", "pokemon_action")
	show_dialog(scene, "选择行动：%s" % card_data.display_name(), items, {
		"player": cp,
		"actions": actions,
		"action_items": action_items,
		"pokemon_card": slot.get_top_card(),
		"pokemon_card_data": card_data,
		"attached_energy_summary": _pokemon_action_attached_energy_summary(slot),
		"presentation": "action_hud",
		"allow_cancel": true,
	})
	var dialog_cancel: Button = scene.get("_dialog_cancel")
	if dialog_cancel != null:
		dialog_cancel.visible = true


func _pokemon_action_attached_energy_summary(slot: PokemonSlot) -> String:
	var names := _pokemon_action_attached_energy_names(slot)
	if names.is_empty():
		return ""
	var order: Array[String] = []
	var counts := {}
	for name: String in names:
		if not counts.has(name):
			order.append(name)
			counts[name] = 0
		counts[name] = int(counts[name]) + 1
	var parts: Array[String] = []
	for name: String in order:
		var count := int(counts.get(name, 0))
		parts.append(name if count <= 1 else "%s x%d" % [name, count])
	return " · ".join(parts)


func _pokemon_action_attached_energy_names(slot: PokemonSlot) -> Array[String]:
	var names: Array[String] = []
	if slot == null:
		return names
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		var energy_name := energy.card_data.display_name()
		if energy_name != "":
			names.append(energy_name)
	return names


func show_stadium_action_dialog(scene: Object, cp: int) -> void:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null or gsm.game_state.stadium_card == null:
		return
	var state: GameState = gsm.game_state
	var stadium_card: CardInstance = state.stadium_card
	if stadium_card == null or stadium_card.card_data == null:
		return
	var card_data: CardData = stadium_card.card_data
	var effect: BaseEffect = gsm.effect_processor.get_effect(card_data.effect_id)
	var is_action := effect != null and effect.can_use_as_stadium_action(stadium_card, state)
	var can_use: bool = is_action and bool(gsm.can_use_stadium_effect(cp))
	var reason := "" if can_use else _stadium_action_unusable_reason(state, cp, is_action)
	var ability_title := _stadium_action_title(card_data)
	var ability_body := _stadium_action_body(card_data, effect)
	var prefix := "" if can_use else "[不可用] "
	var items: Array[String] = ["%s[特性] %s" % [prefix, ability_title]]
	var actions: Array[Dictionary] = [{
		"type": "stadium_ability",
		"enabled": can_use,
		"reason": reason,
	}]
	var action_items: Array[Dictionary] = [
		_build_pokemon_action_item(
			"stadium_ability",
			"特性",
			ability_title,
			"竞技场",
			ability_body,
			can_use,
			reason
		)
	]
	scene.set("_pending_choice", "pokemon_action")
	show_dialog(scene, "选择行动：%s" % card_data.display_name(), items, {
		"player": cp,
		"actions": actions,
		"action_items": action_items,
		"pokemon_card": stadium_card,
		"pokemon_card_data": card_data,
		"presentation": "action_hud",
		"allow_cancel": true,
	})
	var dialog_cancel: Button = scene.get("_dialog_cancel")
	if dialog_cancel != null:
		dialog_cancel.visible = true


func _build_pokemon_action_item(
	action_type: String,
	kind: String,
	title: String,
	meta: String,
	body: String,
	enabled: bool,
	reason: String,
	cost: String = ""
) -> Dictionary:
	return {
		"type": action_type,
		"kind": kind,
		"title": title if title.strip_edges() != "" else "未命名",
		"meta": meta,
		"body": body,
		"cost": cost,
		"enabled": enabled,
		"reason": reason,
	}


func _stadium_action_title(card_data: CardData) -> String:
	if card_data != null and not card_data.abilities.is_empty():
		var ability: Dictionary = card_data.abilities[0]
		var ability_name := str(ability.get("name", "")).strip_edges()
		if ability_name != "":
			return ability_name
	return "竞技场效果"


func _stadium_action_body(card_data: CardData, effect: BaseEffect) -> String:
	if card_data != null and not card_data.abilities.is_empty():
		var ability: Dictionary = card_data.abilities[0]
		var ability_text := str(ability.get("text", "")).strip_edges()
		if ability_text != "":
			return ability_text
	# The card database is the localized, player-facing source of truth. Effect
	# descriptions are implementation/debug fallbacks and may be written in English.
	if card_data != null and card_data.description.strip_edges() != "":
		return card_data.description.strip_edges()
	if effect != null:
		var effect_text := effect.get_description().strip_edges()
		if effect_text != "":
			return effect_text
	return "这张竞技场当前没有可主动使用的效果。"


func _stadium_action_unusable_reason(state: GameState, cp: int, is_action: bool) -> String:
	if not is_action:
		return "这张竞技场没有可主动使用的能力"
	if state == null:
		return "当前无法使用该竞技场能力"
	if state.current_player_index != cp:
		return "当前不是该玩家的回合"
	if state.phase != GameState.GamePhase.MAIN:
		return "只能在主要阶段使用"
	if (
		state.stadium_card != null
		and state.stadium_card.card_data != null
		and state.stadium_effect_used_turn == state.turn_number
		and state.stadium_effect_used_player == cp
		and state.stadium_effect_used_effect_id == state.stadium_card.card_data.effect_id
	):
		return "本回合已经使用过该竞技场能力"
	return "当前无法使用该竞技场能力"


func _attack_damage_meta_text(attack: Dictionary, preview_damage: int) -> String:
	var damage := str(attack.get("damage", "")).strip_edges()
	if damage != "":
		return "伤害 %s" % damage
	if preview_damage > 0:
		return "预览 %d" % preview_damage
	return ""


func _attack_meta_text(attack: Dictionary, preview_damage: int) -> String:
	var parts: Array[String] = []
	var cost := str(attack.get("cost", "")).strip_edges()
	var damage := str(attack.get("damage", "")).strip_edges()
	if cost != "":
		parts.append("费用 %s" % cost)
	if damage != "":
		parts.append("伤害 %s" % damage)
	elif preview_damage > 0:
		parts.append("预览 %d" % preview_damage)
	return " · ".join(parts)


func _attack_body_text(attack: Dictionary, preview_damage: int) -> String:
	var lines: Array[String] = []
	var damage := str(attack.get("damage", "")).strip_edges()
	if damage != "":
		lines.append("基础伤害：%s。" % damage)
	elif preview_damage > 0:
		lines.append("预览伤害：%d。" % preview_damage)
	var text := CardData.dictionary_display_text(attack)
	if text != "":
		lines.append(text)
	if lines.is_empty():
		lines.append("无额外效果。")
	return "\n".join(lines)


func _action_body_from_text(text: String) -> String:
	var body := text.strip_edges()
	return body if body != "" else "无额外效果。"


func _legacy_show_pokemon_action_dialog(scene: Object, cp: int, slot: PokemonSlot, include_attacks: bool) -> void:
	var gsm: Variant = scene.get("_gsm")
	var card_data: CardData = slot.get_card_data()
	var items: Array[String] = []
	var actions: Array[Dictionary] = []
	var effect: BaseEffect = gsm.effect_processor.get_effect(card_data.effect_id)
	if effect != null:
		for i: int in card_data.abilities.size():
			var ability: Dictionary = card_data.abilities[i]
			if not effect.has_method("can_use_ability"):
				continue
			var can_use: bool = gsm.effect_processor.can_use_ability(slot, gsm.game_state, i)
			var ability_reason: String = "" if can_use else gsm.effect_processor.get_ability_unusable_reason(slot, gsm.game_state, i)
			var prefix := "" if can_use else "[不可用] "
			items.append("%s[特性] %s" % [prefix, ability.get("name", "")])
			actions.append({
				"type": "ability",
				"slot": slot,
				"ability_index": i,
				"enabled": can_use,
				"reason": ability_reason,
			})
	for granted: Dictionary in gsm.effect_processor.get_granted_abilities(slot, gsm.game_state):
		var can_use_granted: bool = bool(granted.get("enabled", false))
		var granted_name := str(granted.get("name", ""))
		var granted_index := int(granted.get("ability_index", card_data.abilities.size()))
		var granted_reason: String = "" if can_use_granted else gsm.effect_processor.get_ability_unusable_reason(slot, gsm.game_state, granted_index)
		var granted_prefix := "" if can_use_granted else "[不可用] "
		items.append("%s[特性] %s" % [granted_prefix, granted_name])
		actions.append({
			"type": "ability",
			"slot": slot,
			"ability_index": granted_index,
			"enabled": can_use_granted,
			"reason": granted_reason,
		})
	if include_attacks:
		for i: int in card_data.attacks.size():
			var attack: Dictionary = card_data.attacks[i]
			var can_use_attack: bool = gsm.can_use_attack(cp, i)
			var attack_reason: String = "" if can_use_attack else gsm.get_attack_unusable_reason(cp, i)
			var prefix: String = "" if can_use_attack else "[不可用] "
			var preview_damage: int = gsm.get_attack_preview_damage(cp, i)
			var preview_text := ""
			if String(attack.get("damage", "")) != "" or preview_damage > 0:
				preview_text = " 预览伤害:%d" % preview_damage
			items.append("%s[招式] %s [%s] %s%s" % [prefix, CardData.dictionary_display_name(attack), attack.get("cost", ""), attack.get("damage", ""), preview_text])
			actions.append({
				"type": "attack",
				"slot": slot,
				"attack_index": i,
				"enabled": can_use_attack,
				"reason": attack_reason,
			})
		for granted_attack: Dictionary in gsm.effect_processor.get_granted_attacks(slot, gsm.game_state):
			var granted_can_use: bool = bool(scene.call("_can_use_granted_attack", cp, slot, granted_attack))
			var granted_prefix: String = "" if granted_can_use else "[不可用] "
			var granted_reason: String = "" if granted_can_use else str(scene.call("_get_granted_attack_unusable_reason", cp, slot, granted_attack))
			items.append("%s[招式] %s [%s]" % [granted_prefix, str(granted_attack.get("name", "")), str(granted_attack.get("cost", ""))])
			actions.append({
				"type": "granted_attack",
				"slot": slot,
				"granted_attack": granted_attack,
				"enabled": granted_can_use,
				"reason": granted_reason,
			})
		if slot == gsm.game_state.players[cp].active_pokemon:
			var can_retreat: bool = gsm.rule_validator.can_retreat(gsm.game_state, cp, gsm.effect_processor)
			var retreat_prefix: String = "" if can_retreat else "[不可用] "
			var retreat_reason: String = "" if can_retreat else gsm.rule_validator.get_retreat_unusable_reason(gsm.game_state, cp, gsm.effect_processor)
			items.append("%s[行动] 撤退" % retreat_prefix)
			actions.append({
				"type": "retreat",
				"enabled": can_retreat,
				"reason": retreat_reason,
			})
	if actions.is_empty():
		scene.call("_log", "%s 当前没有可执行的行动" % card_data.display_name())
		return
	scene.set("_pending_choice", "pokemon_action")
	show_dialog(scene, "选择行动：%s" % card_data.display_name(), items, {"player": cp, "actions": actions})
	var dialog_cancel: Button = scene.get("_dialog_cancel")
	if dialog_cancel != null:
		dialog_cancel.visible = true


func show_retreat_dialog(scene: Object, cp: int) -> void:
	var gsm: Variant = scene.get("_gsm")
	var player: PlayerState = gsm.game_state.players[cp]
	var active: PokemonSlot = player.active_pokemon
	var cost: int = gsm.effect_processor.get_effective_retreat_cost(active, gsm.game_state)
	var energy_discard: Array[CardInstance] = []
	var paid_units := 0
	for energy: CardInstance in active.attached_energy:
		if paid_units >= cost:
			break
		energy_discard.append(energy)
		paid_units += gsm.effect_processor.get_energy_colorless_count(energy, gsm.game_state)
	scene.set("_pending_choice", "retreat_bench")
	scene.set("_dialog_data", {
		"player": cp,
		"bench": player.bench,
		"energy_discard": energy_discard,
		"allow_cancel": true,
		"min_select": 1,
		"max_select": 1,
	})
	scene.call("_show_field_slot_choice", "选择接收 %d 个能量的备战宝可梦" % cost, player.bench, scene.get("_dialog_data"))


func show_match_end_dialog(scene: Object, winner_index: int, reason: String) -> void:
	var summary := match_end_summary_text(winner_index, reason)
	var items: Array[String] = [summary]
	var extra_data := {
		"winner": winner_index,
		"reason": reason,
		"action": "game_over",
	}
	var review_action := current_match_end_review_action(scene)
	if not review_action.is_empty():
		items.append(str(review_action.get("label", "生成AI复盘")))
		extra_data["review_action"] = str(review_action.get("kind", "generate"))
		extra_data["review_action_index"] = items.size() - 1
	var learning_action := current_match_end_learning_action(scene)
	if not learning_action.is_empty():
		items.append(str(learning_action.get("label", "让AI学习")))
		extra_data["learning_action"] = str(learning_action.get("kind", "mark"))
		extra_data["learning_action_index"] = items.size() - 1
	items.append("返回对战准备")
	extra_data["return_action_index"] = items.size() - 1
	scene.set("_pending_choice", "game_over")
	show_dialog(scene, "对战结束", items, extra_data)


func match_end_summary_text(winner_index: int, reason: String) -> String:
	return "玩家 %d 获胜\n原因：%s" % [winner_index + 1, reason]


func current_match_end_review_action(scene: Object) -> Dictionary:
	if not bool(scene.call("_should_offer_battle_review")):
		return {}
	if bool(scene.get("_battle_review_busy")):
		var progress_text := str(scene.get("_battle_review_progress_text"))
		return {
			"kind": "busy",
			"label": progress_text if progress_text != "" else "正在生成AI复盘...",
		}
	var cached_review: Dictionary = scene.call("_load_cached_battle_review")
	var cached_status := str(cached_review.get("status", ""))
	if cached_status in ["completed", "partial_success"]:
		scene.set("_battle_review_last_review", cached_review)
		return {"kind": "view", "label": "查看AI复盘"}
	if cached_status == "failed":
		scene.set("_battle_review_last_review", cached_review)
		return {"kind": "retry", "label": "生成失败，重试"}
	var last_review: Dictionary = scene.get("_battle_review_last_review")
	if str(last_review.get("status", "")) == "failed":
		return {"kind": "retry", "label": "生成失败，重试"}
	return {"kind": "generate", "label": "生成AI复盘"}


func current_match_end_learning_action(scene: Object) -> Dictionary:
	if not bool(scene.call("_should_offer_match_learning")):
		return {}
	if bool(scene.call("_is_current_match_marked_for_learning")):
		return {"kind": "marked", "label": "已加入学习池"}
	return {"kind": "mark", "label": "让AI学习"}
