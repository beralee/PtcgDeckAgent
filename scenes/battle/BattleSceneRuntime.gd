## BattleScene lifecycle and layout runtime.
extends "res://scenes/battle/runtime/BattleSceneDialogInteractionReviewRuntime.gd"

func _ready() -> void:
	set_process(false)
	_init_battle_runtime_log()
	_btn_end_turn.pressed.connect(_on_end_turn)
	_hud_end_turn_btn.pressed.connect(_on_end_turn)
	_btn_stadium_action.pressed.connect(_on_stadium_action_pressed)
	_btn_opponent_hand.pressed.connect(_on_opponent_hand_pressed)
	_btn_attack_vfx_preview.pressed.connect(_on_attack_vfx_preview_pressed)
	_btn_ai_advice.pressed.connect(_on_ai_advice_pressed)
	_btn_battle_discuss_ai.pressed.connect(_on_battle_discuss_ai_pressed)
	_btn_ai_advice.visible = false
	_btn_attack_vfx_preview.visible = false
	_btn_zeus_help.pressed.connect(_on_zeus_help_pressed)
	_btn_replay_prev_turn.pressed.connect(_on_replay_prev_turn_pressed)
	_btn_replay_next_turn.pressed.connect(_on_replay_next_turn_pressed)
	_btn_replay_continue.pressed.connect(_on_replay_continue_pressed)
	_btn_replay_back_to_list.pressed.connect(_on_replay_back_to_list_pressed)
	_setup_battle_scene_context()
	_btn_back.pressed.connect(_on_back_pressed)
	_btn_battle_layout.pressed.connect(_on_battle_layout_pressed)
	_btn_battle_more.pressed.connect(_on_battle_more_pressed)
	_dialog_confirm.pressed.connect(_on_dialog_confirm)
	_dialog_cancel.pressed.connect(_on_dialog_cancel)
	_handover_btn.pressed.connect(_on_handover_confirmed)
	_handover_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_handover_panel.z_index = HANDOVER_OVERLAY_Z_INDEX

	_dialog_overlay.visible = false
	_dialog_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog_overlay.z_index = DIALOG_OVERLAY_Z_INDEX
	_set_handover_panel_visible(false, "ready_init")
	_coin_overlay.visible = false
	_detail_overlay.visible = false
	_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_overlay.z_index = DETAIL_OVERLAY_Z_INDEX
	_discard_overlay.visible = false
	_discard_overlay.z_index = DISCARD_OVERLAY_Z_INDEX
	_review_overlay.visible = false
	_hand_title.visible = false
	_left_panel.visible = false
	_right_panel.visible = false
	_btn_opponent_hand.visible = false
	_btn_replay_prev_turn.visible = false
	_btn_replay_next_turn.visible = false
	_btn_replay_continue.visible = false
	_btn_replay_back_to_list.visible = false
	_opp_prize_hud_count.visible = false
	_my_prize_hud_count.visible = false
	for caption_path: String in [
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyVstar/EnemyVstarMargin/EnemyVstarVBox/EnemyVstarCaption",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyVstar/MyVstarMargin/MyVstarVBox/MyVstarCaption",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/EnemyInfoColumn/InfoEnemyLost/EnemyLostMargin/EnemyLostVBox/EnemyLostCaption",
		"MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/VstarSection/VstarMargin/VstarVBox/InfoColumns/MyInfoColumn/InfoMyLost/MyLostMargin/MyLostVBox/MyLostCaption"
	]:
		var caption := get_node_or_null(caption_path) as Label
		if caption != null:
			caption.visible = false
	_opp_hand_bar.visible = false
	($MainArea/CenterField/HandArea/HandVBox as VBoxContainer).add_theme_constant_override("separation", 0)
	_hand_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_setup_hand_drag_scroll()
	_setup_side_previews()
	_install_field_card_views()
	_setup_detail_preview()
	_setup_dialog_gallery()
	_setup_discard_gallery()
	_setup_prize_viewer()
	_refresh_prize_titles()
	_setup_field_interaction_panel()
	_connect_viewport_size_changed()
	_schedule_initial_battle_layout_orientation()
	_update_battle_layout_button()
	_ensure_battle_layout_coordinator()
	_setup_battle_layout()
	_schedule_responsive_layout_stabilization()
	_start_battle_music()

	# Coin flip overlay setup
	_coin_animator = CoinFlipAnimatorScript.new()
	_coin_animator.set_anchors_preset(PRESET_FULL_RECT)
	_coin_animator.z_index = 150
	_coin_animator.visible = false
	add_child(_coin_animator)
	_coin_animator.animation_finished.connect(_on_coin_animation_finished)

	# Popups
	_coin_ok_btn.pressed.connect(func() -> void:
		_coin_overlay.visible = false
	)
	var detail_close_callable := Callable(self, "_hide_card_detail")
	if not _detail_close_btn.pressed.is_connected(detail_close_callable):
		_detail_close_btn.pressed.connect(detail_close_callable)
	if not _detail_close_btn.button_down.is_connected(detail_close_callable):
		_detail_close_btn.button_down.connect(detail_close_callable)
	_discard_close_btn.pressed.connect(func() -> void:
		_discard_overlay.visible = false
	)
	if _discard_list != null and not _discard_list.item_clicked.is_connected(_on_discard_list_item_clicked):
		_discard_list.item_clicked.connect(_on_discard_list_item_clicked)
	_review_close_btn.pressed.connect(func() -> void:
		_review_overlay.visible = false
	)
	_review_regenerate_btn.pressed.connect(_on_review_regenerate_pressed)
	_setup_battle_advice_ui()
	var stadium_sections := $MainArea/CenterField/FieldArea/StadiumBar/StadiumSections as HBoxContainer
	if stadium_sections != null:
		stadium_sections.move_child(_stadium_center_section, 0)
		stadium_sections.move_child(_lost_zone_section, 1)
	_refresh_replay_controls()
	var replay_launch: Dictionary = GameManager.consume_battle_replay_launch()
	if not replay_launch.is_empty():
		_apply_replay_launch(replay_launch)

	# Discard pile interactions
	_bind_discard_hud_openers()
	_bind_lost_zone_hud_openers()
	if _opp_discard_preview != null:
		_opp_discard_preview.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
			_show_discard_pile(1 - _view_player, "对方弃牌区")
		)
		_opp_discard_preview.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
			if cd != null:
				_show_card_detail(cd)
		)
	if _my_discard_preview != null:
		_my_discard_preview.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
			_show_discard_pile(_view_player, "己方弃牌区")
		)
		_my_discard_preview.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
			if cd != null:
				_show_card_detail(cd)
		)
	_my_deck.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			var mbe := e as InputEventMouseButton
			if mbe.pressed and mbe.button_index == MOUSE_BUTTON_RIGHT:
				_show_deck_cards(_view_player, "己方牌库")
	)
	if _my_deck_preview != null:
		_my_deck_preview.right_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
			_show_deck_cards(_view_player, "己方牌库")
		)
	_stadium_center_section.gui_input.connect(_on_stadium_area_input)
	_btn_stadium_action.gui_input.connect(_on_stadium_area_input)

	# Pokemon slot interactions
	_bind_field_slot_input_handlers()

	if not _is_review_mode():
		_start_battle()



func _exit_tree() -> void:
	_responsive_layout_stabilization_frames_remaining = 0
	set_process(false)
	_stop_all_deck_shuffle_effects()
	BattleMusicManager.stop_battle_music()
	_release_game_state_machine()
	GameManager.apply_non_battle_orientation()



func _process(_delta: float) -> void:
	if _responsive_layout_stabilization_frames_remaining <= 0:
		set_process(false)
		return
	if not is_inside_tree():
		set_process(false)
		return
	_apply_responsive_layout()
	_responsive_layout_stabilization_frames_remaining -= 1
	if _responsive_layout_stabilization_frames_remaining <= 0:
		set_process(false)



func _input(event: InputEvent) -> void:
	if _card_gallery_drag_active and _handle_card_gallery_drag_scroll_input(event, _card_gallery_drag_active_scroll, "battle_scene_input"):
		var gallery_drag_viewport := get_viewport()
		if gallery_drag_viewport != null:
			gallery_drag_viewport.set_input_as_handled()
		return
	if _hand_drag_active:
		_debug_hand_drag_scroll_event("battle_scene_input", event, _hand_scroll if _hand_scroll != null else find_child("HandScroll", true, false) as ScrollContainer)
	if _hand_drag_active and _handle_hand_drag_scroll_input(event):
		var hand_drag_viewport := get_viewport()
		if hand_drag_viewport != null:
			hand_drag_viewport.set_input_as_handled()
		return
	if _try_handle_portrait_bench_play_input(event):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()



func _apply_initial_battle_layout_orientation_after_first_frame() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	GameManager.apply_battle_layout_orientation()
	_apply_responsive_layout()
	if _gsm != null:
		_refresh_ui()
	_schedule_responsive_layout_stabilization()



func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()
	if _gsm != null:
		_refresh_ui()
	_schedule_responsive_layout_stabilization(RESPONSIVE_LAYOUT_RESIZE_STABILIZATION_FRAMES)



func _on_battle_layout_pressed() -> void:
	var current := GameManager.sanitize_battle_layout_mode(str(GameManager.get("battle_layout_mode")))
	match current:
		GameManager.BATTLE_LAYOUT_AUTO:
			GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
		GameManager.BATTLE_LAYOUT_PORTRAIT:
			GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_LANDSCAPE
		_:
			GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_AUTO
	GameManager.apply_battle_layout_orientation()
	_update_battle_layout_button()
	_apply_responsive_layout()
	if _gsm != null:
		_refresh_ui()
	_schedule_responsive_layout_stabilization()



func _on_battle_more_pressed() -> void:
	_show_portrait_actions_popup()



func _draw_reveal_anchor_rect() -> Rect2:
	if _active_battle_layout_mode == "landscape":
		return Rect2()
	var portrait_mode := _rotated_portrait_canvas_active or _current_resolved_battle_layout_mode() == "portrait"
	if not portrait_mode:
		return Rect2()
	var viewport_size := size
	if viewport_size == Vector2.ZERO and _rotated_portrait_canvas_active:
		viewport_size = _battle_layout_logical_viewport_size(_rotated_portrait_physical_viewport_size, "portrait")
	if viewport_size == Vector2.ZERO and is_inside_tree():
		viewport_size = _battle_layout_logical_viewport_size(get_viewport_rect().size, "portrait")
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(900, 1600)
	return Rect2(Vector2.ZERO, viewport_size)



func _apply_landscape_layout(viewport_size: Vector2) -> void:
	_active_battle_layout_mode = "landscape"
	_apply_battle_canvas_transform(false, viewport_size, viewport_size)
	_apply_landscape_layout_impl(viewport_size)



func _raise_dialog_overlay_for_input() -> void:
	_restore_landscape_overlay_z_order()
	var dialog_overlay := _dialog_overlay if _dialog_overlay != null else find_child("DialogOverlay", true, false) as Control
	if dialog_overlay != null:
		_raise_modal_overlay_for_input(dialog_overlay, ACTIVE_MODAL_OVERLAY_Z_INDEX)



func _raise_handover_overlay_for_input() -> void:
	_restore_landscape_overlay_z_order()
	var handover_panel := _handover_panel if _handover_panel != null else find_child("HandoverPanel", true, false) as Control
	if handover_panel != null:
		_raise_modal_overlay_for_input(handover_panel, ACTIVE_MODAL_OVERLAY_Z_INDEX)



func _set_portrait_layout_frame(frame_rect: Rect2, full_size: Vector2) -> void:
	_portrait_layout_frame_rect = frame_rect
	_portrait_layout_full_size = full_size
	_sync_battle_layout_state_from_scene()
	_trace_portrait_layout_stage("scene.set_portrait_layout_frame")



func _apply_portrait_layout(viewport_size: Vector2) -> void:
	_active_battle_layout_mode = "portrait"
	_apply_portrait_layout_impl(viewport_size)



func _apply_portrait_field_hud_metrics(viewport_size: Vector2, bench_card_size: Vector2, active_card_size: Vector2 = Vector2.ZERO) -> Dictionary:
	_ensure_battle_layout_coordinator()
	var metrics_variant: Variant = _battle_layout_coordinator.call("apply_portrait_field_hud_metrics", viewport_size, bench_card_size, active_card_size)
	return metrics_variant if metrics_variant is Dictionary else {}


func _deferred_finalize_portrait_layout_constraints() -> void:
	_trace_portrait_layout_stage("scene.deferred_finalize.before")
	_finalize_portrait_layout_constraints()
	_trace_portrait_layout_stage("scene.deferred_finalize.after")
	_request_portrait_layout_debug_overlay_refresh()



func _apply_portrait_axis_width_to_control(control: Control, width: float, expand: bool) -> void:
	if control == null:
		return
	control.clip_contents = true
	control.custom_minimum_size.x = width
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_SHRINK_CENTER
	if control.size.x > 0.0:
		control.size = Vector2(width, control.size.y)
	if control is Container:
		(control as Container).queue_sort()



func _apply_landscape_status_huds_beside_active(
	card_size: Vector2,
	stadium_height: float,
	row_gap: int
) -> void:
	_ensure_battle_layout_coordinator()
	_battle_layout_coordinator.call("apply_landscape_status_huds_beside_active", card_size, stadium_height, row_gap)

func _landscape_status_side_column_width(card_size: Vector2, panel_width: float) -> float:
	return maxf(roundf(card_size.x * 2.6), panel_width + roundf(card_size.x * 1.75))



func _move_landscape_status_stack_to_active_row(
	stack_name: String,
	left_spacer_name: String,
	right_slot_name: String,
	active_row: HBoxContainer,
	active_card: Control,
	vstar_panel: PanelContainer,
	lost_panel: PanelContainer,
	panel_width: float,
	panel_height: float,
	stack_height: float,
	side_column_width: float,
	gap: int
) -> void:
	_ensure_battle_layout_coordinator()
	_battle_layout_coordinator.call(
		"move_landscape_status_stack_to_active_row",
		stack_name,
		left_spacer_name,
		right_slot_name,
		active_row,
		active_card,
		vstar_panel,
		lost_panel,
		panel_width,
		panel_height,
		stack_height,
		side_column_width,
		gap
	)

func _ensure_landscape_status_spacer(spacer_name: String, active_row: Container) -> Control:
	var existing := find_child(spacer_name, true, false) as Control
	if existing != null:
		if active_row != null and existing.get_parent() != active_row:
			_move_control_to_container(existing, active_row, 0)
		return existing
	if active_row == null:
		return null
	var spacer := Control.new()
	spacer.name = spacer_name
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_row.add_child(spacer)
	return spacer



func _ensure_landscape_status_slot(slot_name: String, active_row: Container) -> CenterContainer:
	var existing := find_child(slot_name, true, false) as CenterContainer
	if existing != null:
		if active_row != null and existing.get_parent() != active_row:
			_move_control_to_container(existing, active_row, active_row.get_child_count())
		return existing
	if active_row == null:
		return null
	var slot := CenterContainer.new()
	slot.name = slot_name
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_row.add_child(slot)
	return slot



func _ensure_landscape_status_stack(stack_name: String, active_row: Container) -> VBoxContainer:
	var existing := find_child(stack_name, true, false) as VBoxContainer
	if existing != null:
		if active_row != null and existing.get_parent() != active_row:
			_move_control_to_container(existing, active_row, active_row.get_child_count())
		return existing
	if active_row == null:
		return null
	var stack := VBoxContainer.new()
	stack.name = stack_name
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	active_row.add_child(stack)
	return stack



func _apply_landscape_pile_hud_metrics(preview_card_size: Vector2) -> void:
	_ensure_battle_layout_coordinator()
	_battle_layout_coordinator.call("apply_landscape_pile_hud_metrics", preview_card_size)



func _landscape_pile_lost_panel_width(preview_card_size: Vector2) -> float:
	return _landscape_pile_panel_width(preview_card_size) * 2.0 + float(_landscape_pile_row_gap(preview_card_size))



func _move_lost_huds_to_pile_huds(lost_panel_height: float = 0.0, enemy_lost_above: bool = false) -> void:
	_move_lost_hud_to_pile(_find_panel_by_name("InfoEnemyLost"), lost_panel_height, enemy_lost_above)
	_move_lost_hud_to_pile(_find_panel_by_name("InfoMyLost"), lost_panel_height, enemy_lost_above)



func _apply_battle_axis_field_alignment() -> void:
	var opp_field_inner := get_node_or_null("MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppFieldInner") as VBoxContainer
	if opp_field_inner != null:
		opp_field_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
		opp_field_inner.alignment = BoxContainer.ALIGNMENT_END
	var my_field_inner := get_node_or_null("MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyFieldInner") as VBoxContainer
	if my_field_inner != null:
		my_field_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
		my_field_inner.alignment = BoxContainer.ALIGNMENT_BEGIN



func _apply_pile_hud_row_orientation(vertical: bool) -> void:
	for row_path: String in [
		"MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudRight/OppHudRightMargin/OppHudRightVBox/OppHudDataRow",
		"MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudRight/MyHudRightMargin/MyHudRightVBox/MyHudDataRow"
	]:
		_ensure_pile_hud_row_container(row_path, vertical)



func _portrait_hud_font_size(viewport_size: Vector2) -> int:
	var ui_scale := _portrait_layout_ui_scale(viewport_size)
	return clampi(roundi(viewport_size.x * 0.022), roundi(16.0 * ui_scale), roundi(24.0 * ui_scale))



func _apply_portrait_stadium_hud_metrics(viewport_size: Vector2, ui_scale: float) -> void:
	_ensure_battle_layout_coordinator()
	_battle_layout_coordinator.call("apply_portrait_stadium_hud_metrics", viewport_size, ui_scale)



func _portrait_stadium_hud_height(viewport_size: Vector2, ui_scale: float = 1.0) -> float:
	var stadium_bar := get_node_or_null("MainArea/CenterField/FieldArea/StadiumBar") as Control
	if stadium_bar != null and stadium_bar.custom_minimum_size.y > 0.0:
		return stadium_bar.custom_minimum_size.y
	return maxf(64.0 * ui_scale, 56.0)



func _apply_portrait_hud_font_metrics(font_size: int) -> void:
	for label_name: String in [
		"OppHudLeftTitle",
		"OppHudLeftValue",
		"MyHudLeftTitle",
		"MyHudLeftValue",
		"OppDeckHudCaption",
		"OppDeckHudValue",
		"OppDiscardHudCaption",
		"OppDiscardHudValue",
		"MyDeckHudCaption",
		"MyDeckHudValue",
		"MyDiscardHudCaption",
		"MyDiscardHudValue",
		"EnemyVstarCaption",
		"EnemyVstarValue",
		"MyVstarCaption",
		"MyVstarValue",
		"EnemyLostCaption",
		"EnemyLostValue",
		"MyLostCaption",
		"MyLostValue",
		"StadiumLbl",
		"LblPhase",
		"LblTurn",
		"OppHandLbl"
	]:
		var label := find_child(label_name, true, false) as Label
		if label == null:
			continue
		label.add_theme_font_size_override("font_size", font_size)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for button_name: String in ["HudEndTurnBtn", "BtnStadiumAction"]:
		var button := find_child(button_name, true, false) as Button
		if button != null:
			button.add_theme_font_size_override("font_size", font_size)



func _set_portrait_huds_on_field_edges(
	enabled: bool,
	status_width: float = 0.0,
	status_panel_height: float = 0.0,
	row_gap: float = 0.0,
	viewport_size: Vector2 = Vector2.ZERO
) -> void:
	_ensure_battle_layout_coordinator()
	_battle_layout_coordinator.call("set_portrait_huds_on_field_edges", enabled, status_width, status_panel_height, row_gap, viewport_size)

func _move_portrait_hud_pair_to_field_edges(
	left_group_name: String,
	status_stack_name: String,
	left_hud: PanelContainer,
	right_hud: PanelContainer,
	field_shell: HBoxContainer,
	field_inner: Control,
	active_row: HBoxContainer,
	active_card: Control,
	vstar_panel: PanelContainer,
	lost_panel: PanelContainer,
	status_width: float,
	status_panel_height: float,
	row_gap: float
) -> void:
	_ensure_battle_layout_coordinator()
	_battle_layout_coordinator.call(
		"move_portrait_hud_pair_to_field_edges",
		left_group_name,
		status_stack_name,
		left_hud,
		right_hud,
		field_shell,
		field_inner,
		active_row,
		active_card,
		vstar_panel,
		lost_panel,
		status_width,
		status_panel_height,
		row_gap
	)

func _ensure_portrait_edge_hud_overlay() -> Control:
	var existing := find_child("PortraitEdgeHudOverlay", true, false) as Control
	if existing != null:
		existing.visible = true
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		existing.z_index = 30
		return existing
	var overlay := Control.new()
	overlay.name = "PortraitEdgeHudOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	overlay.z_index = 30
	add_child(overlay)
	return overlay



func _ensure_portrait_edge_hud_group(group_name: String, overlay: Control, horizontal: bool) -> BoxContainer:
	var existing := find_child(group_name, true, false) as BoxContainer
	if existing != null:
		var type_matches := (horizontal and existing is HBoxContainer) or ((not horizontal) and existing is VBoxContainer)
		if not type_matches:
			var parent := existing.get_parent()
			var insert_index := existing.get_index()
			var replacement: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
			replacement.name = existing.name
			replacement.mouse_filter = existing.mouse_filter
			replacement.alignment = existing.alignment
			replacement.visible = existing.visible
			replacement.custom_minimum_size = existing.custom_minimum_size
			replacement.size_flags_horizontal = existing.size_flags_horizontal
			replacement.size_flags_vertical = existing.size_flags_vertical
			replacement.add_theme_constant_override("separation", existing.get_theme_constant("separation"))
			for child: Node in existing.get_children():
				child.owner = null
				existing.remove_child(child)
				replacement.add_child(child)
			if parent != null:
				parent.remove_child(existing)
				parent.add_child(replacement)
				parent.move_child(replacement, insert_index)
			existing.queue_free()
			existing = replacement
		if existing.get_parent() != overlay:
			_move_control_to_node(existing, overlay, overlay.get_child_count())
		return existing
	if overlay == null:
		return null
	var group: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
	group.name = group_name
	group.mouse_filter = Control.MOUSE_FILTER_PASS
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(group)
	return group



func _portrait_active_center_y(active_name: String, fallback_y: float) -> float:
	var active := _find_control_by_name(active_name)
	var rect := _control_rect_in_battle_local(active)
	if rect.size.y > 0.0:
		return rect.position.y + rect.size.y * 0.5
	return fallback_y



func _position_portrait_edge_hud_group(group_name: String, anchor: Vector2, from_left: bool) -> void:
	_ensure_battle_layout_coordinator()
	_battle_layout_coordinator.call("position_portrait_edge_hud_group", group_name, anchor, from_left)



func _hide_portrait_edge_hud_groups() -> void:
	for group_name: String in ["OppPortraitLeftHudGroup", "MyPortraitLeftHudGroup", "OppPortraitRightHudGroup", "MyPortraitRightHudGroup"]:
		var group := find_child(group_name, true, false) as BoxContainer
		if group == null:
			continue
		group.visible = false
		group.custom_minimum_size = Vector2.ZERO
	var overlay := find_child("PortraitEdgeHudOverlay", true, false) as Control
	if overlay != null:
		overlay.visible = false



func _ensure_portrait_status_stack(stack_name: String, active_row: Container) -> VBoxContainer:
	var existing := find_child(stack_name, true, false) as VBoxContainer
	if existing != null:
		if active_row != null and existing.get_parent() != active_row:
			_move_control_to_container(existing, active_row, active_row.get_child_count())
		return existing
	if active_row == null:
		return null
	var stack := VBoxContainer.new()
	stack.name = stack_name
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	active_row.add_child(stack)
	return stack



func _restore_portrait_status_huds_to_info_columns() -> void:
	var enemy_info_column := _find_vbox_by_name("EnemyInfoColumn")
	var my_info_column := _find_vbox_by_name("MyInfoColumn")
	if enemy_info_column != null:
		enemy_info_column.visible = true
	if my_info_column != null:
		my_info_column.visible = true
	_restore_portrait_status_stack(
		"OppPortraitStatusStack",
		enemy_info_column,
		_find_panel_by_name("InfoEnemyVstar"),
		_find_panel_by_name("InfoEnemyLost")
	)
	_restore_portrait_status_stack(
		"MyPortraitStatusStack",
		my_info_column,
		_find_panel_by_name("InfoMyVstar"),
		_find_panel_by_name("InfoMyLost")
	)
	_hide_landscape_status_layout("OppLandscapeStatusStack", "OppLandscapeStatusLeftSpacer", "OppLandscapeStatusSlot")
	_hide_landscape_status_layout("MyLandscapeStatusStack", "MyLandscapeStatusLeftSpacer", "MyLandscapeStatusSlot")



func _set_portrait_turn_action_in_stadium(enabled: bool, action_width: float = 0.0, row_gap: int = 4, action_height: float = 0.0) -> void:
	_ensure_battle_layout_coordinator()
	_battle_layout_coordinator.call("set_portrait_turn_action_in_stadium", enabled, action_width, row_gap, action_height)



func _ensure_portrait_stadium_spacer(stadium_sections: HBoxContainer) -> Control:
	var spacer := find_child("PortraitStadiumSpacer", true, false) as Control
	if spacer != null:
		if spacer.get_parent() != stadium_sections:
			_move_control_to_container(spacer, stadium_sections, stadium_sections.get_child_count())
		return spacer
	if stadium_sections == null:
		return null
	spacer = Control.new()
	spacer.name = "PortraitStadiumSpacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stadium_sections.add_child(spacer)
	return spacer



func _ensure_landscape_stadium_left_spacer(stadium_sections: HBoxContainer) -> Control:
	var spacer := find_child("LandscapeStadiumLeftSpacer", true, false) as Control
	if spacer != null:
		if stadium_sections != null and spacer.get_parent() != stadium_sections:
			_move_control_to_container(spacer, stadium_sections, 0)
		return spacer
	if stadium_sections == null:
		return null
	spacer = Control.new()
	spacer.name = "LandscapeStadiumLeftSpacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stadium_sections.add_child(spacer)
	return spacer



func _resolve_landscape_stadium_left_spacer_width(
	prize_slot_size: Vector2,
	opp_prize_hud: Control,
	my_prize_hud: Control,
	center_width: float,
	stadium_center_width: float,
	end_turn_hud_width: float,
	stadium_section_gap: float
) -> float:
	var prize_grid_width := roundf(maxf(prize_slot_size.x, 0.0) * 3.0)
	var measured_prize_width := 0.0
	for prize_hud: Control in [opp_prize_hud, my_prize_hud]:
		if prize_hud == null:
			continue
		measured_prize_width = maxf(measured_prize_width, prize_hud.size.x)
		measured_prize_width = maxf(measured_prize_width, prize_hud.get_combined_minimum_size().x)
	var desired_width := maxf(prize_grid_width, measured_prize_width)
	var max_width := maxf(
		center_width - stadium_center_width - end_turn_hud_width - stadium_section_gap * 4.0,
		0.0
	)
	if max_width <= 0.0:
		return maxf(desired_width, 0.0)
	return roundf(clampf(desired_width, 0.0, max_width))

func _restore_portrait_hud_pair_to_shell(
	left_hud: PanelContainer,
	right_hud: PanelContainer,
	field_shell: HBoxContainer,
	field_inner: Control
) -> void:
	if field_shell == null:
		return
	field_shell.alignment = BoxContainer.ALIGNMENT_BEGIN
	_move_control_to_container(left_hud, field_shell, 0)
	var right_index := field_shell.get_child_count()
	if field_inner != null:
		right_index = field_inner.get_index() + 1
	_move_control_to_container(right_hud, field_shell, right_index)

func _request_stadium_hud_debug_overlay_refresh() -> void:
	_ensure_battle_layout_debug_reporter()
	_battle_layout_debug_reporter.call("request_stadium_hud_debug_overlay_refresh")



func _refresh_stadium_hud_debug_overlay() -> void:
	_ensure_battle_layout_debug_reporter()
	_battle_layout_debug_reporter.call("refresh_stadium_hud_debug_overlay")



func _should_trace_portrait_layout() -> bool:
	_ensure_battle_layout_debug_reporter()
	return bool(_battle_layout_debug_reporter.call("should_trace_portrait_layout"))



func _is_portrait_layout_debug_paint_enabled() -> bool:
	_ensure_battle_layout_debug_reporter()
	return bool(_battle_layout_debug_reporter.call("is_portrait_layout_debug_paint_enabled"))



func _refresh_portrait_layout_debug_overlay() -> void:
	_ensure_battle_layout_debug_reporter()
	_battle_layout_debug_reporter.call("refresh_portrait_layout_debug_overlay")



func _hide_portrait_layout_debug_overlay() -> void:
	_ensure_battle_layout_debug_reporter()
	_battle_layout_debug_reporter.call("hide_portrait_layout_debug_overlay")



func _find_hbox_by_name(node_name: String) -> HBoxContainer:
	return find_child(node_name, true, false) as HBoxContainer



func _store_and_hide_portrait_top_action(button: Button) -> void:
	if not button.has_meta("_portrait_previous_top_action_visible"):
		button.set_meta("_portrait_previous_top_action_visible", button.visible)
	button.visible = false



func _restore_portrait_top_action(button: Button) -> void:
	if not button.has_meta("_portrait_previous_top_action_visible"):
		return
	button.visible = bool(button.get_meta("_portrait_previous_top_action_visible"))
	button.remove_meta("_portrait_previous_top_action_visible")



func _apply_portrait_top_action_compact_label(button: Button) -> void:
	if button == null:
		return
	if not button.has_meta("_portrait_previous_top_action_text"):
		button.set_meta("_portrait_previous_top_action_text", button.text)
	match String(button.name):
		"BtnOpponentHand":
			button.text = "对手"
		"BtnBattleDiscussAI":
			button.text = "AI"
		"BtnZeusHelp":
			button.text = "宙斯"
		"BtnReplayPrevTurn":
			button.text = "上回合"
		"BtnReplayNextTurn":
			button.text = "下回合"
		"BtnReplayContinue":
			button.text = "继续"
		"BtnReplayBackToList":
			button.text = "列表"
		"BtnBack":
			button.text = "退出"



func _restore_portrait_top_action_label(button: Button) -> void:
	if button == null or not button.has_meta("_portrait_previous_top_action_text"):
		return
	button.text = str(button.get_meta("_portrait_previous_top_action_text"))
	button.remove_meta("_portrait_previous_top_action_text")



func _press_top_action_button(source_button: Button) -> void:
	if source_button == null or source_button.disabled:
		return
	source_button.pressed.emit()



func _show_portrait_log_popup() -> void:
	var list := _ensure_portrait_actions_popup()
	if list == null:
		return
	_clear_container_children(list)
	var title := Label.new()
	title.text = "战斗日志"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	list.add_child(title)
	var log_copy := RichTextLabel.new()
	log_copy.bbcode_enabled = true
	log_copy.fit_content = false
	log_copy.custom_minimum_size = Vector2(0, 360)
	log_copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_copy.text = _log_list.text if _log_list != null else ""
	log_copy.add_theme_stylebox_override("normal", HudThemeScript.input_style(false))
	HudThemeScript.style_scrollable_control(log_copy, "touch")
	list.add_child(log_copy)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(0, PORTRAIT_ACTION_POPUP_BUTTON_HEIGHT)
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_hud_button(close_button)
	close_button.pressed.connect(func() -> void:
		if _portrait_actions_popup != null:
			_portrait_actions_popup.hide()
	)
	list.add_child(close_button)
	_apply_portrait_popup_text_metrics()
	_popup_portrait_panel()



func _update_portrait_overlay_metrics(viewport_size: Vector2) -> void:
	var dialog_box := get_node_or_null("DialogOverlay/DialogCenter/DialogBox") as PanelContainer
	if dialog_box != null:
		dialog_box.custom_minimum_size = Vector2(_portrait_dialog_width(viewport_size), 0)
	if _dialog_card_scroll != null:
		_dialog_card_scroll.custom_minimum_size = Vector2(0, _effective_dialog_card_scroll_height())
	if _dialog_assignment_source_scroll != null:
		_dialog_assignment_source_scroll.custom_minimum_size = Vector2(0, _dialog_card_scroll_height())
	if _dialog_assignment_target_scroll != null:
		_dialog_assignment_target_scroll.custom_minimum_size = Vector2(0, _dialog_card_scroll_height())
	_apply_portrait_overlay_box_metrics()
	_apply_portrait_popup_text_metrics()



func _portrait_popup_content_size() -> Vector2:
	return _portrait_dialog_viewport_size()



func _portrait_dialog_uses_card_selection() -> bool:
	if bool(get("_dialog_card_mode")) or bool(get("_dialog_assignment_mode")):
		return true
	if _dialog_card_scroll != null and _dialog_card_scroll.visible:
		return true
	if _dialog_assignment_panel != null and _dialog_assignment_panel.visible:
		return true
	return false



func _hide_hand_scrollbar() -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("hide_hand_scrollbar")



func _hide_hand_scrollbar_for(hand_scroll: ScrollContainer) -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("hide_hand_scrollbar_for", hand_scroll)



func _on_hand_scroll_input(event: InputEvent) -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("on_hand_scroll_input", event)



func _hand_drag_event_position(event: InputEvent) -> Vector2:
	_ensure_battle_drag_scroll_coordinator()
	var position_variant: Variant = _battle_drag_scroll_coordinator.call("hand_drag_event_position", event)
	return position_variant if position_variant is Vector2 else Vector2.ZERO



func _is_hand_drag_click_suppressed() -> bool:
	_ensure_battle_drag_scroll_coordinator()
	return bool(_battle_drag_scroll_coordinator.call("is_hand_drag_click_suppressed"))



func _configure_card_gallery_drag_scroll(scroll: ScrollContainer, row: Control = null, source: String = "card_gallery") -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("configure_card_gallery_drag_scroll", scroll, row, source)



func _set_card_gallery_drag_scroll_active(scroll: ScrollContainer, active: bool) -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("set_card_gallery_drag_scroll_active", scroll, active)



func _configure_card_gallery_card_view(card_view: BattleCardView, scroll: ScrollContainer, source: String = "card_gallery") -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("configure_card_gallery_card_view", card_view, scroll, source)



func _on_card_gallery_scroll_input(event: InputEvent, scroll: ScrollContainer, source: String = "card_gallery") -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("on_card_gallery_scroll_input", event, scroll, source)



func _on_card_gallery_card_input(event: InputEvent, scroll: ScrollContainer, source: String = "card_gallery") -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("on_card_gallery_card_input", event, scroll, source)



func _card_gallery_drag_event_position(event: InputEvent) -> Vector2:
	_ensure_battle_drag_scroll_coordinator()
	var position_variant: Variant = _battle_drag_scroll_coordinator.call("card_gallery_drag_event_position", event)
	return position_variant if position_variant is Vector2 else Vector2.ZERO



func _debug_hand_drag_scroll_enabled() -> bool:
	_ensure_battle_drag_scroll_coordinator()
	return bool(_battle_drag_scroll_coordinator.call("debug_hand_drag_scroll_enabled"))



func _debug_hand_drag_scroll(message: String, throttle_motion: bool = false) -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("debug_hand_drag_scroll", message, throttle_motion)



func _hand_drag_scroll_range_text(hand_scroll: ScrollContainer) -> String:
	_ensure_battle_drag_scroll_coordinator()
	return str(_battle_drag_scroll_coordinator.call("hand_drag_scroll_range_text", hand_scroll))



func _hand_drag_content_size_text(hand_scroll: ScrollContainer) -> String:
	_ensure_battle_drag_scroll_coordinator()
	return str(_battle_drag_scroll_coordinator.call("hand_drag_content_size_text", hand_scroll))



func _hand_drag_event_global_position(event: InputEvent) -> Vector2:
	_ensure_battle_drag_scroll_coordinator()
	var position_variant: Variant = _battle_drag_scroll_coordinator.call("hand_drag_event_global_position", event)
	return position_variant if position_variant is Vector2 else Vector2.ZERO



func _hand_drag_event_pressed_state(event: InputEvent) -> String:
	_ensure_battle_drag_scroll_coordinator()
	return str(_battle_drag_scroll_coordinator.call("hand_drag_event_pressed_state", event))



func _set_portrait_panel_collapsed(panel: Control, collapsed: bool) -> void:
	if panel == null:
		return
	var meta_prev_visible := "_portrait_previous_visible"
	if collapsed:
		if not panel.has_meta(meta_prev_visible):
			panel.set_meta(meta_prev_visible, panel.visible)
		panel.visible = false
		panel.custom_minimum_size = Vector2.ZERO
		return
	if panel.has_meta(meta_prev_visible):
		panel.visible = bool(panel.get_meta(meta_prev_visible))
		panel.remove_meta(meta_prev_visible)



func _set_portrait_bench_grid_enabled(
	enabled: bool,
	bench_card_size: Vector2,
	bench_gap: float,
	bench_capacity: int = BENCH_SIZE,
	bench_columns: int = BENCH_SIZE,
	bench_rows: int = 1,
	my_bench_capacity: int = -1,
	my_bench_columns: int = -1,
	my_bench_rows: int = -1,
	opp_bench_capacity: int = -1,
	opp_bench_columns: int = -1,
	opp_bench_rows: int = -1
) -> void:
	var resolved_my_capacity := bench_capacity if my_bench_capacity < 0 else my_bench_capacity
	var resolved_my_columns := bench_columns if my_bench_columns < 0 else my_bench_columns
	var resolved_my_rows := bench_rows if my_bench_rows < 0 else my_bench_rows
	var resolved_opp_capacity := bench_capacity if opp_bench_capacity < 0 else opp_bench_capacity
	var resolved_opp_columns := bench_columns if opp_bench_columns < 0 else opp_bench_columns
	var resolved_opp_rows := bench_rows if opp_bench_rows < 0 else opp_bench_rows
	var my_bench := get_node_or_null("%MyBench") as HBoxContainer
	var opp_bench := get_node_or_null("%OppBench") as HBoxContainer
	if enabled:
		_portrait_my_bench_grid = _ensure_portrait_bench_grid("PortraitMyBenchGrid", my_bench, resolved_my_rows)
		_portrait_opp_bench_grid = _ensure_portrait_bench_grid("PortraitOppBenchGrid", opp_bench, resolved_opp_rows)
		_move_bench_children(my_bench, _portrait_my_bench_grid)
		_move_bench_children(opp_bench, _portrait_opp_bench_grid)
		_apply_portrait_grid_metrics(_portrait_my_bench_grid, bench_card_size, bench_gap, resolved_my_capacity, resolved_my_columns, resolved_my_rows)
		_apply_portrait_grid_metrics(_portrait_opp_bench_grid, bench_card_size, bench_gap, resolved_opp_capacity, resolved_opp_columns, resolved_opp_rows)
		_bind_field_slot_input_handlers()
		if my_bench != null:
			my_bench.visible = false
		if opp_bench != null:
			opp_bench.visible = false
		return
	_move_bench_children(_portrait_my_bench_grid, my_bench)
	_move_bench_children(_portrait_opp_bench_grid, opp_bench)
	if _portrait_my_bench_grid != null:
		_portrait_my_bench_grid.visible = false
	if _portrait_opp_bench_grid != null:
		_portrait_opp_bench_grid.visible = false
	if my_bench != null:
		my_bench.visible = true
	if opp_bench != null:
		opp_bench.visible = true
	_bind_field_slot_input_handlers()

func _ensure_portrait_bench_grid(grid_name: String, source_bench: HBoxContainer, bench_rows: int = 1) -> Container:
	if source_bench == null:
		return null
	var parent := source_bench.get_parent()
	if parent == null:
		return null
	var existing_container := parent.get_node_or_null(grid_name) as Container
	var needs_rows := bench_rows > 1
	var existing_matches := (
		(existing_container is VBoxContainer and needs_rows)
		or (existing_container is HBoxContainer and not needs_rows)
	)
	if existing_container != null and not existing_matches:
		_move_bench_children(existing_container, source_bench)
		parent.remove_child(existing_container)
		existing_container.queue_free()
		existing_container = null
	var existing := existing_container as Container
	if existing != null:
		existing.visible = true
		existing.mouse_filter = Control.MOUSE_FILTER_PASS
		if existing is BoxContainer:
			(existing as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
		if grid_name == "PortraitMyBenchGrid":
			var existing_input := Callable(self, "_on_portrait_my_bench_grid_input")
			if not existing.gui_input.is_connected(existing_input):
				existing.gui_input.connect(existing_input)
		_ensure_portrait_bench_grid_rows(existing, bench_rows)
		return existing
	var grid: Container = VBoxContainer.new() if needs_rows else HBoxContainer.new()
	grid.name = grid_name
	grid.visible = true
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if grid is BoxContainer:
		(grid as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(grid)
	grid.owner = source_bench.owner
	parent.move_child(grid, source_bench.get_index())
	_ensure_portrait_bench_grid_rows(grid, bench_rows)
	if grid_name == "PortraitMyBenchGrid":
		var grid_input := Callable(self, "_on_portrait_my_bench_grid_input")
		if not grid.gui_input.is_connected(grid_input):
			grid.gui_input.connect(grid_input)
	return grid



func _on_portrait_my_bench_grid_input(event: InputEvent) -> void:
	if not _try_handle_portrait_bench_play_input(event):
		return
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()



func _apply_portrait_grid_metrics(
	grid: Container,
	bench_card_size: Vector2,
	bench_gap: float,
	bench_capacity: int = BENCH_SIZE,
	bench_columns: int = BENCH_SIZE,
	bench_rows: int = 1
) -> void:
	if grid == null:
		return
	grid.visible = true
	var columns := maxi(bench_columns, 1)
	var rows := maxi(bench_rows, 1)
	var visible_capacity := maxi(bench_capacity, 1)
	var row_width := bench_card_size.x * float(columns) + bench_gap * float(maxi(columns - 1, 0))
	var grid_height := bench_card_size.y * float(rows) + bench_gap * float(maxi(rows - 1, 0))
	if rows <= 1:
		row_width = bench_card_size.x * float(visible_capacity) + bench_gap * float(maxi(visible_capacity - 1, 0))
		grid_height = bench_card_size.y
	grid.custom_minimum_size = Vector2(row_width, grid_height)
	grid.add_theme_constant_override("h_separation", int(round(bench_gap)))
	grid.add_theme_constant_override("v_separation", int(round(bench_gap)))
	if grid is HBoxContainer:
		var row := grid as HBoxContainer
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", int(round(bench_gap)))
		return
	if grid is VBoxContainer:
		var stack := grid as VBoxContainer
		stack.add_theme_constant_override("separation", int(round(bench_gap)))
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		for row_index: int in rows:
			var row_name := "Row%d" % row_index
			var row := stack.get_node_or_null(row_name) as HBoxContainer
			if row == null:
				continue
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", int(round(bench_gap)))
			row.custom_minimum_size = Vector2(row_width, bench_card_size.y)

func _portrait_bench_panels(bench: HBoxContainer, grid: Container) -> Array[PanelContainer]:
	var panels: Array[PanelContainer] = []
	var host: Node = grid if grid != null and grid.visible else bench
	if host == null:
		return panels
	return _bench_panel_children_recursive(host)



func _resolve_hud_action_button_height(stadium_height: float, stadium_inner_vpad: int, compact: bool = false) -> float:
	var min_height := HUD_ACTION_TOUCH_MIN_HEIGHT
	if compact:
		min_height = roundf(HUD_ACTION_TOUCH_MIN_HEIGHT * LANDSCAPE_STADIUM_ACTION_HEIGHT_SCALE)
	return maxf(stadium_height - float(stadium_inner_vpad * 2), min_height)



func _apply_landscape_stadium_action_text_metrics(action_height: float) -> void:
	var font_size := maxi(16, roundi(12.0 * LANDSCAPE_STADIUM_ACTION_FONT_SCALE))
	var stadium_label := _stadium_lbl if _stadium_lbl != null else find_child("StadiumLbl", true, false) as Label
	if stadium_label != null:
		stadium_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stadium_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stadium_label.clip_text = true
		stadium_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stadium_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stadium_label.custom_minimum_size.y = action_height
		stadium_label.add_theme_font_size_override("font_size", font_size)
	var stadium_button := _btn_stadium_action if _btn_stadium_action != null else find_child("BtnStadiumAction", true, false) as Button
	if stadium_button != null:
		stadium_button.clip_text = true
		stadium_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stadium_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stadium_button.custom_minimum_size.y = action_height
		stadium_button.add_theme_font_size_override("font_size", font_size)



func _stadium_center_vbox_node() -> VBoxContainer:
	var node := get_node_or_null("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/StadiumCenterSection/StadiumCenterMargin/StadiumCenterVBox") as VBoxContainer
	if node != null:
		return node
	if _stadium_center_section != null:
		return _stadium_center_section.find_child("StadiumCenterVBox", true, false) as VBoxContainer
	return find_child("StadiumCenterVBox", true, false) as VBoxContainer



func _stadium_action_row_node() -> HBoxContainer:
	var node := get_node_or_null("MainArea/CenterField/FieldArea/StadiumBar/StadiumSections/StadiumCenterSection/StadiumCenterMargin/StadiumCenterVBox/StadiumActionRow") as HBoxContainer
	if node != null:
		return node
	if _stadium_center_section != null:
		return _stadium_center_section.find_child("StadiumActionRow", true, false) as HBoxContainer
	return find_child("StadiumActionRow", true, false) as HBoxContainer



func _ensure_stadium_card_overlay() -> Control:
	_ensure_battle_stadium_hud_coordinator()
	return _battle_stadium_hud_coordinator.call("ensure_stadium_card_overlay") as Control



func _ensure_stadium_card_view() -> BattleCardView:
	_ensure_battle_stadium_hud_coordinator()
	return _battle_stadium_hud_coordinator.call("ensure_stadium_card_view") as BattleCardView



func _apply_stadium_card_view_metrics(width: float, height: float) -> void:
	_ensure_battle_stadium_hud_coordinator()
	_battle_stadium_hud_coordinator.call("apply_stadium_card_view_metrics", width, height)



func _position_stadium_card_view() -> void:
	_ensure_battle_stadium_hud_coordinator()
	_battle_stadium_hud_coordinator.call("position_stadium_card_view")



func _stadium_card_anchor_rect() -> Rect2:
	_ensure_battle_stadium_hud_coordinator()
	var rect_variant: Variant = _battle_stadium_hud_coordinator.call("stadium_card_anchor_rect")
	return rect_variant if rect_variant is Rect2 else Rect2()



func _stadium_action_effect(gs: GameState) -> BaseEffect:
	_ensure_battle_stadium_hud_coordinator()
	return _battle_stadium_hud_coordinator.call("stadium_action_effect", gs) as BaseEffect



func _is_action_stadium(gs: GameState) -> bool:
	_ensure_battle_stadium_hud_coordinator()
	return bool(_battle_stadium_hud_coordinator.call("is_action_stadium", gs))



func _is_stadium_effect_used_this_turn(gs: GameState, player_index: int) -> bool:
	_ensure_battle_stadium_hud_coordinator()
	return bool(_battle_stadium_hud_coordinator.call("is_stadium_effect_used_this_turn", gs, player_index))



func _set_legacy_stadium_hud_visible(visible: bool) -> void:
	_ensure_battle_stadium_hud_coordinator()
	_battle_stadium_hud_coordinator.call("set_legacy_stadium_hud_visible", visible)



func _refresh_stadium_card_hud(gs: GameState, current_player: int, is_my_turn: bool) -> void:
	_ensure_battle_stadium_hud_coordinator()
	_battle_stadium_hud_coordinator.call("refresh_stadium_card_hud", gs, current_player, is_my_turn)



func _resolve_top_bar_height(viewport_size: Vector2, stadium_height: float, action_button_height: float, stadium_inner_vpad: int) -> float:
	var legacy_top_height := maxf(roundf(clampf(viewport_size.y * 0.042, 26.0, 38.0) * (2.0 / 3.0)), stadium_height)
	var action_top_height := action_button_height + float(stadium_inner_vpad * 2)
	return maxf(legacy_top_height, action_top_height)



func _apply_top_action_button_metrics(button_height: float, viewport_size: Vector2, ui_scale: float = 1.0, font_scale: float = 1.0) -> void:
	var resolved_height := maxf(button_height, HUD_ACTION_TOUCH_MIN_HEIGHT)
	var action_gap := _resolve_top_action_gap(viewport_size)
	var action_width := _resolve_top_action_button_width(viewport_size, action_gap, ui_scale)
	_apply_top_bar_space_metrics(viewport_size, action_width, action_gap)
	var font_size := clampi(roundi(12.0 * ui_scale * font_scale), 12, 44)
	var buttons := [
		_top_action_button_or_null(_btn_opponent_hand, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnOpponentHand"),
		_top_action_button_or_null(_btn_attack_vfx_preview, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnAttackVfxPreview"),
		_top_action_button_or_null(_btn_ai_advice, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnAiAdvice"),
		_top_action_button_or_null(_btn_battle_discuss_ai, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnBattleDiscussAI"),
		_top_action_button_or_null(_btn_zeus_help, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnZeusHelp"),
		_top_action_button_or_null(_btn_battle_layout, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnBattleLayout"),
		_top_action_button_or_null(_btn_battle_more, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnBattleMore"),
		_top_action_button_or_null(_btn_replay_prev_turn, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnReplayPrevTurn"),
		_top_action_button_or_null(_btn_replay_next_turn, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnReplayNextTurn"),
		_top_action_button_or_null(_btn_replay_continue, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnReplayContinue"),
		_top_action_button_or_null(_btn_replay_back_to_list, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnReplayBackToList"),
		_top_action_button_or_null(_btn_back, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnBack"),
	]
	for raw_button in buttons:
		var button := raw_button as Button
		if button == null:
			continue
		button.custom_minimum_size = Vector2(action_width, resolved_height)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", font_size)
	for label: Label in [
		_lbl_phase if _lbl_phase != null else find_child("LblPhase", true, false) as Label,
		_lbl_turn if _lbl_turn != null else find_child("LblTurn", true, false) as Label,
	]:
		if label != null:
			label.add_theme_font_size_override("font_size", font_size)



func _apply_portrait_top_action_pair_metrics(viewport_size: Vector2, ui_scale: float = 1.0) -> void:
	var direct_buttons: Array[Button] = []
	for button: Button in _portrait_direct_top_action_buttons():
		if button != null and button.visible:
			direct_buttons.append(button)
	var more_button := _top_action_button_or_null(_btn_battle_more, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnBattleMore")
	if more_button != null:
		more_button.visible = false
	var action_gap := _resolve_top_action_gap(viewport_size)
	var action_count := maxi(direct_buttons.size(), 1)
	var action_width := _resolve_portrait_top_direct_button_width(viewport_size, action_count, action_gap, ui_scale)
	var actions_width := action_width * float(action_count) + float(action_gap * maxi(action_count - 1, 0))
	for button: Button in direct_buttons:
		button.custom_minimum_size.x = action_width
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var top_bar_right := get_node_or_null("TopBar/TopBarRow/TopBarRight") as Control
	if top_bar_right != null:
		top_bar_right.custom_minimum_size.x = actions_width
		top_bar_right.size_flags_horizontal = Control.SIZE_SHRINK_END
	var top_bar_actions := get_node_or_null("TopBar/TopBarRow/TopBarRight/TopBarActions") as HBoxContainer
	if top_bar_actions != null:
		top_bar_actions.custom_minimum_size.x = actions_width
		top_bar_actions.add_theme_constant_override("separation", action_gap)
		top_bar_actions.size_flags_horizontal = Control.SIZE_SHRINK_END
		top_bar_actions.alignment = BoxContainer.ALIGNMENT_END



func _resolve_portrait_top_pair_button_width(viewport_size: Vector2, action_gap: int = -1, ui_scale: float = 1.0) -> float:
	var resolved_gap := action_gap if action_gap >= 0 else _resolve_top_action_gap(viewport_size)
	var safe_width := maxf(viewport_size.x, 1.0)
	var max_width := maxf((safe_width * 0.52 - float(resolved_gap)) / 2.0, 58.0 * ui_scale)
	var min_width := minf(88.0 * ui_scale, max_width)
	var preferred_width := clampf(safe_width * 0.225, 88.0 * ui_scale, 132.0 * ui_scale)
	return clampf(preferred_width, min_width, max_width)



func _resolve_top_status_width(viewport_size: Vector2) -> float:
	return clampf(viewport_size.x * 0.2, 140.0, 340.0)



func _resolve_top_turn_width(viewport_size: Vector2) -> float:
	return clampf(viewport_size.x * 0.16, 126.0, 280.0)



func _compute_play_card_height(viewport_size: Vector2, center_width: float, bench_spacing: float) -> float:
	return _battle_layout_controller.call(
		"compute_play_card_height",
		viewport_size,
		center_width,
		bench_spacing,
		_current_bench_display_size(),
		CARD_ASPECT
	)



func _resolve_battle_backdrop_path() -> String:
	return _battle_layout_controller.call(
		"resolve_backdrop_path",
		GameManager.selected_battle_background,
		BATTLE_BACKDROP_RESOURCE
	)



func _vstar_lost_hud_configs() -> Array[Dictionary]:
	_ensure_battle_surface_styler()
	var configs: Variant = _battle_surface_styler.call("_vstar_lost_hud_configs")
	return configs if configs is Array else []



func _style_vstar_lost_hud(config: Dictionary) -> void:
	_ensure_battle_surface_styler()
	_battle_surface_styler.call("_style_vstar_lost_hud", config)



func _set_vstar_hud_texture_index_for_player(player_index: int, texture_index: int) -> void:
	if player_index < 0:
		return
	var variant_count := VSTAR_HUD_TEXTURE_VARIANTS.size()
	if variant_count <= 0:
		return
	while _vstar_hud_texture_indices_by_player.size() <= player_index:
		_vstar_hud_texture_indices_by_player.append(0)
	_vstar_hud_texture_indices_by_player[player_index] = posmod(texture_index, variant_count)



func _find_panel_by_path_or_name(path: String, node_name: String) -> PanelContainer:
	var panel := get_node_or_null(path) as PanelContainer
	if panel != null:
		return panel
	if node_name == "":
		return null
	return find_child(node_name, true, false) as PanelContainer



func _find_label_by_path_or_name(path: String, node_name: String) -> Label:
	var label := get_node_or_null(path) as Label
	if label != null:
		return label
	if node_name == "":
		return null
	return find_child(node_name, true, false) as Label



func _apply_vstar_lost_hud_metrics(panel: Control) -> void:
	if panel == null:
		return
	if panel.has_meta("_vstar_lost_exact_minimum_size"):
		var exact_size_variant: Variant = panel.get_meta("_vstar_lost_exact_minimum_size")
		if exact_size_variant is Vector2:
			var exact_size := exact_size_variant as Vector2
			if _is_vstar_hud_panel(panel):
				exact_size.x = _vstar_hud_width_for_height(exact_size.y)
			panel.custom_minimum_size = exact_size
			panel.set_meta("_vstar_lost_base_minimum_size", exact_size)
			panel.set_meta("_vstar_lost_scaled_minimum_size", exact_size)
			_sync_vstar_hud_image_metrics(panel as PanelContainer)
			return
	var base_size := _resolve_vstar_lost_hud_base_size(panel)
	var scaled_height := roundf(base_size.y * VSTAR_LOST_HUD_HEIGHT_SCALE)
	var scaled_size := _vstar_hud_size_for_height(scaled_height) if _is_vstar_hud_panel(panel) else Vector2(
		roundf(scaled_height * VSTAR_LOST_HUD_WIDTH_RATIO),
		scaled_height
	)
	panel.custom_minimum_size = scaled_size
	panel.set_meta("_vstar_lost_base_minimum_size", base_size)
	panel.set_meta("_vstar_lost_scaled_minimum_size", scaled_size)
	_sync_vstar_hud_image_metrics(panel as PanelContainer)



func _style_card_detail_overlay() -> void:
	_ensure_battle_card_detail_coordinator()
	_battle_card_detail_coordinator.call("style_card_detail_overlay")


func _style_discard_collection_overlay() -> void:
	_ensure_battle_surface_styler()
	_battle_surface_styler.call("style_discard_collection_overlay")



func _style_detail_action_buttons() -> void:
	_ensure_battle_card_detail_coordinator()
	_battle_card_detail_coordinator.call("style_detail_action_buttons")


func _style_handover_overlay() -> void:
	var handover_panel := get_node_or_null("HandoverPanel") as Panel
	var handover_box := get_node_or_null("HandoverPanel/HandoverCenter/HandoverBox") as PanelContainer
	var handover_vbox := get_node_or_null("HandoverPanel/HandoverCenter/HandoverBox/HandoverVBox") as VBoxContainer
	var handover_label := get_node_or_null("HandoverPanel/HandoverCenter/HandoverBox/HandoverVBox/HandoverLbl") as Label
	var handover_button := get_node_or_null("HandoverPanel/HandoverCenter/HandoverBox/HandoverVBox/HandoverBtn") as Button
	if handover_label == null:
		handover_label = _handover_lbl
	if handover_button == null:
		handover_button = _handover_btn
	if handover_panel != null:
		handover_panel.self_modulate = Color(0.0, 0.015, 0.03, 0.76)
	if handover_box != null:
		handover_box.custom_minimum_size = Vector2(520, 220)
		handover_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		handover_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_style_panel(handover_box, Color(0.035, 0.065, 0.09, 0.98), Color(0.36, 0.86, 1.0, 0.92), 22)
	if handover_vbox != null:
		handover_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		handover_vbox.add_theme_constant_override("separation", 18)
	if handover_label != null:
		handover_label.custom_minimum_size = Vector2(460, 72)
		handover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		handover_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		handover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		handover_label.add_theme_font_size_override("font_size", 24)
		handover_label.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
		handover_label.add_theme_color_override("font_outline_color", Color(0.0, 0.08, 0.12, 0.9))
		handover_label.add_theme_constant_override("outline_size", 2)
	if handover_button != null:
		_style_hud_button(handover_button)
		handover_button.custom_minimum_size = Vector2(360, 68)
		handover_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		handover_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		handover_button.add_theme_font_size_override("font_size", 20)



func _set_field_card_portrait_status_metrics(enabled: bool) -> void:
	for card_view_variant: Variant in _slot_card_views.values():
		var card_view := card_view_variant as BattleCardView
		if card_view == null:
			continue
		card_view.set_portrait_status_metrics_enabled(enabled)


func _set_field_card_status_text_scale(scale: float) -> void:
	for card_view_variant: Variant in _slot_card_views.values():
		var card_view := card_view_variant as BattleCardView
		if card_view == null:
			continue
		card_view.set_status_text_scale(scale)



func _get_deck_preview_for_player(player_index: int) -> BattleCardView:
	if player_index == _view_player:
		return _my_deck_preview
	if player_index == 1 - _view_player:
		return _opp_deck_preview
	return null



func _get_deck_shuffle_tween_for_player(player_index: int) -> Variant:
	return _my_deck_shuffle_tween if player_index == _view_player else _opp_deck_shuffle_tween



func _set_deck_shuffle_tween_for_player(player_index: int, tween_value: Variant) -> void:
	if player_index == _view_player:
		_my_deck_shuffle_tween = tween_value
	elif player_index == 1 - _view_player:
		_opp_deck_shuffle_tween = tween_value



func _stop_deck_shuffle_effect(player_index: int) -> void:
	_ensure_battle_deck_shuffle_animator()
	_battle_deck_shuffle_animator.call("stop_deck_shuffle_effect", player_index)



func _play_deck_shuffle_effect(player_index: int) -> void:
	_ensure_battle_deck_shuffle_animator()
	_battle_deck_shuffle_animator.call("play_deck_shuffle_effect", player_index)



func _refresh_deck_shuffle_detection(gs: GameState) -> void:
	_ensure_battle_deck_shuffle_animator()
	_battle_deck_shuffle_animator.call("refresh_deck_shuffle_detection", gs)


func _on_state_changed(_new_phase: GameState.GamePhase) -> void:
	_capture_battle_recording_context_if_ready()
	_refresh_ui()
	_check_two_player_handover()
	_maybe_run_ai()
	_runtime_log("state_changed", _state_snapshot())



func _on_action_logged(action: GameAction) -> void:
	_capture_battle_recording_context_if_ready()
	if action.description != "":
		var display_description := _format_action_description_for_display(action.description)
		if action.player_index != _view_player:
			_latest_opponent_action_text = display_description
			_latest_opponent_action_turn_number = action.turn_number
		_log(display_description)
	if _is_turn_start_draw_action(action):
		action.data["turn_start"] = true
		action.data["draw_source"] = "turn_start"
		_record_turn_start_snapshot_after_draw(action)
	if (
		action != null
		and action.action_type == GameAction.ActionType.DRAW_CARD
		and _gsm != null
		and _gsm.game_state != null
		and _gsm.game_state.phase != GameState.GamePhase.SETUP
		and not _is_review_mode()
		and not (action.data.get("card_instance_ids", []) as Array).is_empty()
	):
		_battle_draw_reveal_controller.call("enqueue_reveal", self, action)
	elif (
		action != null
		and action.action_type == GameAction.ActionType.DISCARD
		and not _is_review_mode()
		and str(action.data.get("source_zone", "")) == "hand"
		and not (action.data.get("card_instance_ids", []) as Array).is_empty()
	):
		_battle_draw_reveal_controller.call("enqueue_reveal", self, action)
	elif (
		action != null
		and action.action_type == GameAction.ActionType.ATTACK
		and not _is_review_mode()
	):
		_battle_attack_vfx_controller.call("play_attack_vfx", self, action)
	elif (
		action != null
		and action.action_type == GameAction.ActionType.USE_ABILITY
		and not _is_review_mode()
		and str(action.data.get("ability_vfx", "")) == "counter_transfer"
	):
		_battle_attack_vfx_controller.call("play_counter_transfer_vfx", self, action.data)
	_record_battle_event({
		"event_type": "action_resolved",
		"action_type": action.action_type,
		"player_index": action.player_index,
		"turn_number": action.turn_number,
		"phase": _recording_phase_name(),
		"description": _format_action_description_for_display(action.description),
		"data": action.data.duplicate(true),
	})
	_record_battle_state_snapshot("after_action_resolved", {
		"action_type": action.action_type,
		"description": _format_action_description_for_display(action.description),
		"resolved_player_index": action.player_index,
	})



func _on_player_choice_required(choice_type: String, data: Dictionary) -> void:
	_capture_battle_recording_context_if_ready()
	_runtime_log("player_choice_required", "%s data=%s" % [choice_type, JSON.stringify(data)])
	match choice_type:
		"mulligan_extra_draw":
			var beneficiary: int = data.get("beneficiary", 0)
			var count: int = data.get("mulligan_count", 1)
			_pending_choice = "mulligan_extra_draw"
			_show_dialog(
				"对手第 %d 次重抽" % count,
				["让玩家 %d 多抽 1 张牌" % (beneficiary + 1)],
				{"beneficiary": beneficiary, "allow_cancel": false}
			)
		"setup_ready":
			_begin_setup_flow()
		"take_prize":
			_start_prize_selection(
				int(data.get("player", _view_player)),
				int(data.get("count", 1))
			)
		"send_out_pokemon":
			_clear_prize_selection()
			var pi: int = data.get("player", 0)
			_prompt_send_out_dialog(pi)
		"bench_limit_cleanup":
			var cleanup_steps: Array[Dictionary] = []
			for raw_step: Variant in data.get("steps", []):
				if raw_step is Dictionary:
					cleanup_steps.append(raw_step)
			if not cleanup_steps.is_empty():
				_start_effect_interaction(
					"bench_limit_cleanup",
					int(data.get("player", _view_player)),
					cleanup_steps,
					null
				)
		"heavy_baton_target":
			var pi_hb: int = data.get("player", 0)
			var bench_raw: Array = data.get("bench", [])
			var bench_targets: Array[PokemonSlot] = []
			for slot: Variant in bench_raw:
				if slot is PokemonSlot:
					bench_targets.append(slot)
			var source_energy_hb: Array[CardInstance] = []
			for energy_variant: Variant in data.get("source_energy", []):
				if energy_variant is CardInstance:
					source_energy_hb.append(energy_variant)
			_prompt_heavy_baton_dialog(
				pi_hb,
				bench_targets,
				int(data.get("count", 0)),
				str(data.get("source_name", "重负球棒")),
				data.get("source_slot", null) as PokemonSlot,
				source_energy_hb
			)
		"exp_share_target":
			var pi_exp: int = data.get("player", 0)
			var bench_raw_exp: Array = data.get("bench", [])
			var bench_targets_exp: Array[PokemonSlot] = []
			for slot_exp: Variant in bench_raw_exp:
				if slot_exp is PokemonSlot:
					bench_targets_exp.append(slot_exp)
			var source_energy_exp: Array[CardInstance] = []
			for energy_exp: Variant in data.get("source_energy", []):
				if energy_exp is CardInstance:
					source_energy_exp.append(energy_exp)
			_prompt_exp_share_dialog(
				pi_exp,
				bench_targets_exp,
				data.get("source_slot", null) as PokemonSlot,
				source_energy_exp
			)
	_maybe_run_ai()



func _update_prize_title(label: Label, player_index: int, default_text: String, is_hud: bool) -> void:
	_ensure_battle_overlay_coordinator()
	_battle_overlay_coordinator.call("update_prize_title", label, player_index, default_text, is_hud)



func _on_game_over(winner_index: int, reason: String) -> void:
	_runtime_log("game_over", "winner=%d reason=%s" % [winner_index, reason])
	_clear_prize_selection()
	_refresh_ui()
	_battle_review_winner_index = winner_index
	_battle_review_reason = reason
	_match_end_quick_review_result = {}
	_match_end_quick_review_busy = false
	_match_end_quick_review_progress_text = ""
	_match_end_quick_review_requested = false
	_record_battle_state_snapshot("match_end", {
		"winner_index": winner_index,
		"reason": reason,
	})
	_record_battle_event({
		"event_type": "match_ended",
		"player_index": winner_index,
		"turn_number": _gsm.game_state.turn_number if _gsm != null and _gsm.game_state != null else 0,
		"phase": _recording_phase_name(),
		"reason": reason,
		"winner_index": winner_index,
	})
	if _battle_recorder != null and _battle_recorder.has_method("get_match_dir"):
		_battle_review_match_dir = str(_battle_recorder.call("get_match_dir"))
	if GameManager.is_tournament_battle_active():
		_finalize_battle_recording({
			"winner_index": winner_index,
			"reason": reason,
			"turn_number": _gsm.game_state.turn_number if _gsm != null and _gsm.game_state != null else 0,
		})
		_show_match_end_dialog(winner_index, reason)
		return
	_show_match_end_dialog(winner_index, reason)
	_finalize_battle_recording({
		"winner_index": winner_index,
		"reason": reason,
		"turn_number": _gsm.game_state.turn_number if _gsm != null and _gsm.game_state != null else 0,
	})



func _on_stadium_action_pressed() -> void:
	if not _can_accept_live_action() or _gsm == null or _is_field_interaction_active():
		return
	_show_stadium_action_dialog(_gsm.game_state.current_player_index)



func _on_stadium_card_left_clicked(card_instance: CardInstance, card_data: CardData) -> void:
	var gs := _gsm.game_state if _gsm != null else null
	if gs != null and gs.stadium_card != null and _can_accept_live_action() and not _is_field_interaction_active():
		_show_stadium_action_dialog(gs.current_player_index)
		return
	var detail_data := card_data
	if detail_data == null and card_instance != null:
		detail_data = card_instance.card_data
	if detail_data != null:
		_show_card_detail(detail_data)



func _on_stadium_card_right_clicked(card_instance: CardInstance, card_data: CardData) -> void:
	var detail_data := card_data
	if detail_data == null and card_instance != null:
		detail_data = card_instance.card_data
	if detail_data != null:
		_show_card_detail(detail_data)



func _on_stadium_area_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mbe := event as InputEventMouseButton
	if not mbe.pressed:
		return
	if not _can_accept_live_action():
		return
	if _gsm == null or _gsm.game_state.stadium_card == null:
		return
	if mbe.button_index == MOUSE_BUTTON_LEFT:
		_show_stadium_action_dialog(_gsm.game_state.current_player_index)
		return
	if mbe.button_index != MOUSE_BUTTON_RIGHT:
		return
	_show_card_detail(_gsm.game_state.stadium_card.card_data)



func _on_back_pressed() -> void:
	if _is_field_interaction_active():
		return
	_pending_choice = "confirm_exit"
	_show_dialog("确认退出对战？当前进度不会保存。", ["确认退出", "取消"], {})
	_dialog_cancel.visible = false



func _on_zeus_help_pressed() -> void:
	if not _can_accept_live_action() or _gsm == null or _gsm.game_state == null or _is_field_interaction_active():
		return
	if _view_player < 0 or _view_player >= _gsm.game_state.players.size():
		return
	# 输出双方卡牌总数到日志，方便验证不变量
	for pi: int in 2:
		var total: int = _gsm.count_player_total_cards(pi)
		_log("玩家%d卡牌总计: %d 张 (牌库%d 手牌%d 奖赏%d 弃牌%d 放逐%d 场上%d)" % [
			pi + 1,
			total,
			_gsm.game_state.players[pi].deck.size(),
			_gsm.game_state.players[pi].hand.size(),
			_gsm.game_state.players[pi].prizes.size(),
			_gsm.game_state.players[pi].discard_pile.size(),
			_gsm.game_state.players[pi].lost_zone.size(),
			total - _gsm.game_state.players[pi].deck.size() - _gsm.game_state.players[pi].hand.size() - _gsm.game_state.players[pi].prizes.size() - _gsm.game_state.players[pi].discard_pile.size() - _gsm.game_state.players[pi].lost_zone.size(),
		])
	var player: PlayerState = _gsm.game_state.players[_view_player]
	var deck_cards: Array = player.deck.duplicate()
	if deck_cards.is_empty():
		_log("当前牌库为空。")
		return
	var labels: Array[String] = []
	for card: CardInstance in deck_cards:
		labels.append(card.card_data.name if card != null and card.card_data != null else "未知卡牌")
	_pending_choice = "zeus_help"
	_show_dialog("宙斯帮我：从牌库中选择任意张牌加入手牌", labels, {
		"player": _view_player,
		"min_select": 0,
		"max_select": deck_cards.size(),
		"allow_cancel": true,
		"presentation": "cards",
		"card_items": deck_cards,
		"deck_cards": deck_cards,
		"choice_labels": labels,
	})



func _on_opponent_hand_pressed() -> void:
	if _gsm == null or _gsm.game_state == null:
		return
	if GameManager.current_mode != GameManager.GameMode.VS_AI:
		return
	_show_opponent_hand_cards()
