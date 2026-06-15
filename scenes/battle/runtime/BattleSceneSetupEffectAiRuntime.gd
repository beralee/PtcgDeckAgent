## BattleScene setup, effect flow, replay, and AI turn runtime.
extends "res://scenes/battle/runtime/BattleSceneBoardActionRuntime.gd"

func _bind_field_slot_input_handlers() -> void:
	_bind_slot_input_handler(find_child("OppActive", true, false) as Control, "opp_active")
	_bind_slot_input_handler(find_child("MyActive", true, false) as Control, "my_active")
	for index: int in MAX_BENCH_SIZE:
		_bind_slot_input_handler(find_child("OppBench%d" % index, true, false) as Control, "opp_bench_%d" % index)
		_bind_slot_input_handler(find_child("MyBench%d" % index, true, false) as Control, "my_bench_%d" % index)



func _setup_battle_scene_context() -> void:
	if _battle_scene_refs == null:
		_battle_scene_refs = BattleSceneRefsScript.new()
	_battle_scene_refs.call("bind_from_scene", self)
	if _battle_scene_context == null:
		_battle_scene_context = BattleSceneContextScript.new()
	_battle_scene_context.call("configure", _battle_scene_refs, _battle_i18n, _gsm, _view_player, _battle_mode)
	_battle_scene_context.call("set_state", "layout", _battle_layout_state)
	_battle_scene_context.call("set_state", "dialog", _battle_dialog_state)
	_battle_scene_context.call("set_state", "interaction", _battle_interaction_state)
	_battle_scene_context.call("set_state", "replay", _battle_replay_state)
	_battle_scene_context.call("set_state", "overlay", _battle_overlay_state)
	_battle_scene_context.call("set_state", "ai", _battle_ai_state)
	_battle_scene_context.call("set_state", "advice", _battle_advice_state)
	_battle_scene_context.call("set_state", "recording", _battle_recording_state)
	_battle_scene_context.call("set_state", "effect", _battle_effect_state)
	if _battle_display_coordinator == null:
		_battle_display_coordinator = BattleDisplayCoordinatorScript.new()
	_battle_display_coordinator.call("setup", _battle_scene_context, _battle_display_controller, self)
	if _battle_surface_styler == null:
		_battle_surface_styler = BattleSurfaceStylerScript.new()
	_battle_surface_styler.call("setup", self)
	if _battle_stadium_hud_coordinator == null:
		_battle_stadium_hud_coordinator = BattleStadiumHudCoordinatorScript.new()
	_battle_stadium_hud_coordinator.call("setup", self)
	if _battle_stadium_backdrop_coordinator == null:
		_battle_stadium_backdrop_coordinator = BattleStadiumBackdropCoordinatorScript.new()
	_battle_stadium_backdrop_coordinator.call("setup", self)
	if _battle_deck_shuffle_animator == null:
		_battle_deck_shuffle_animator = BattleDeckShuffleAnimatorScript.new()
	_battle_deck_shuffle_animator.call("setup", self)
	if _battle_overlay_coordinator == null:
		_battle_overlay_coordinator = BattleOverlayCoordinatorScript.new()
	_battle_overlay_coordinator.call("setup", _battle_scene_context, _battle_overlay_controller, self)
	if _battle_interaction_coordinator == null:
		_battle_interaction_coordinator = BattleInteractionCoordinatorScript.new()
	_battle_interaction_coordinator.call("setup", _battle_scene_context, _battle_interaction_controller, self)
	if _battle_recording_coordinator == null:
		_battle_recording_coordinator = BattleRecordingCoordinatorScript.new()
	_battle_recording_coordinator.call("setup", _battle_scene_context, _battle_recording_controller, self)
	if _battle_advice_coordinator == null:
		_battle_advice_coordinator = BattleAdviceCoordinatorScript.new()
	_battle_advice_coordinator.call("setup", _battle_scene_context, _battle_advice_controller, self)
	if _battle_card_detail_coordinator == null:
		_battle_card_detail_coordinator = BattleCardDetailCoordinatorScript.new()
	_battle_card_detail_coordinator.call("setup", self)
	if _battle_invalid_action_hint_controller == null:
		_battle_invalid_action_hint_controller = BattleInvalidActionHintControllerScript.new()
	_battle_invalid_action_hint_controller.call("setup", self)
	if _battle_prompt_router == null:
		_battle_prompt_router = BattlePromptRouterScript.new()
	_battle_prompt_router.call("setup", _battle_scene_context)
	_sync_battle_scene_context_runtime()



func _start_battle() -> void:
	var deck1_data: DeckData = GameManager.resolve_selected_battle_deck(0)
	var deck2_data: DeckData = GameManager.resolve_selected_battle_deck(1)
	if deck1_data == null or deck2_data == null:
		_log("未找到已选择的卡组数据。")
		return
	_runtime_log(
		"start_battle",
		"deck1=%s deck2=%s first=%d" % [
			deck1_data.deck_name,
			deck2_data.deck_name,
			GameManager.first_player_choice
		]
	)

	_gsm = _build_game_state_machine()
	_sync_battle_scene_context_runtime()
	_apply_ai_fixed_deck_order_override(deck2_data)

	_setup_done = [false, false]
	# Reset visible player before starting a new match.
	_view_player = 0
	_sync_battle_scene_context_runtime()
	_battle_recording_started = false
	_battle_recording_context_captured = false
	_match_end_non_battle_orientation_restored = false
	_turn_start_snapshot_recorded_keys.clear()
	_ensure_battle_recording_started()
	_gsm.start_game(deck1_data, deck2_data, GameManager.first_player_choice)
	_capture_battle_recording_context_if_ready()
	# Setup flow continues through state change callbacks and mulligan prompts.
	# The visible player may be switched later by setup and handover logic.



func _setup_battle_layout() -> void:
	_install_battle_backdrop()
	_apply_battle_surface_styles()
	_apply_responsive_layout()



func _schedule_initial_battle_layout_orientation() -> void:
	if _should_defer_initial_battle_orientation_for_runtime(_is_mobile_runtime()):
		call_deferred("_apply_initial_battle_layout_orientation_after_first_frame")
		return
	GameManager.apply_battle_layout_orientation()



func _connect_viewport_size_changed() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var viewport_size_changed := Callable(self, "_on_viewport_size_changed")
	if not viewport.size_changed.is_connected(viewport_size_changed):
		viewport.size_changed.connect(viewport_size_changed)



func _start_battle_music() -> void:
	BattleMusicManager.set_battle_music_volume_percent(int(GameManager.battle_bgm_volume_percent))
	BattleMusicManager.play_battle_music(GameManager.selected_battle_music_id)



func _setup_hand_drag_scroll() -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("setup_hand_drag_scroll")



func _install_field_card_views() -> void:
	_slot_card_views.clear()
	_ensure_bench_panel_capacity(MAX_BENCH_SIZE)
	_install_slot_card_view("my_active", _my_active, BATTLE_CARD_VIEW.MODE_SLOT_ACTIVE)
	_install_slot_card_view("opp_active", _opp_active, BATTLE_CARD_VIEW.MODE_SLOT_ACTIVE)

	for i: int in MAX_BENCH_SIZE:
		var my_panel: PanelContainer = _my_bench.get_child(i) as PanelContainer
		var opp_panel: PanelContainer = _opp_bench.get_child(i) as PanelContainer
		_install_slot_card_view("my_bench_%d" % i, my_panel, BATTLE_CARD_VIEW.MODE_SLOT_BENCH)
		_install_slot_card_view("opp_bench_%d" % i, opp_panel, BATTLE_CARD_VIEW.MODE_SLOT_BENCH)
	_sync_bench_slot_visibility(BENCH_SIZE)



func _setup_detail_preview() -> void:
	_ensure_battle_card_detail_coordinator()
	_battle_card_detail_coordinator.call("setup_detail_preview", _detail_card_size)


func _setup_side_previews() -> void:
	_stop_all_deck_shuffle_effects()
	_opponent_card_back_texture = _load_card_back_texture(OPPONENT_CARD_BACK_RESOURCE, false)
	_player_card_back_texture = _load_card_back_texture(PLAYER_CARD_BACK_RESOURCE, true)
	_opp_prize_hud_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_my_prize_hud_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_opp_prize_hud_host.alignment = BoxContainer.ALIGNMENT_CENTER
	_my_prize_hud_host.alignment = BoxContainer.ALIGNMENT_CENTER
	_opp_prize_hud_host.add_theme_constant_override("separation", 0)
	_my_prize_hud_host.add_theme_constant_override("separation", 0)
	var opp_prize_panel_vbox := get_node_or_null("MainArea/CenterField/FieldArea/OppField/OppFieldShell/OppHudLeft/OppHudLeftMargin/OppHudLeftVBox") as VBoxContainer
	var my_prize_panel_vbox := get_node_or_null("MainArea/CenterField/FieldArea/MyField/MyFieldShell/MyHudLeft/MyHudLeftMargin/MyHudLeftVBox") as VBoxContainer
	if opp_prize_panel_vbox != null:
		opp_prize_panel_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		opp_prize_panel_vbox.add_theme_constant_override("separation", 0)
	if my_prize_panel_vbox != null:
		my_prize_panel_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		my_prize_panel_vbox.add_theme_constant_override("separation", 0)
	_opp_prize_slots = _build_prize_slots(_opp_prize_hud_host, _opponent_card_back_texture)
	_my_prize_slots = _build_prize_slots(_my_prize_hud_host, _player_card_back_texture)
	_opp_deck_preview = _insert_pile_preview(_opp_deck_hud_box, 1, false, _opponent_card_back_texture)
	_opp_discard_preview = _insert_pile_preview(_opp_discard_hud_box, 1, true)
	_my_deck_preview = _insert_pile_preview(_my_deck_hud_box, 1, false, _player_card_back_texture)
	_my_discard_preview = _insert_pile_preview(_my_discard_hud_box, 1, true)
	_deck_preview_base_positions[_view_player] = _my_deck_preview.position if _my_deck_preview != null else Vector2.ZERO
	_deck_preview_base_positions[1 - _view_player] = _opp_deck_preview.position if _opp_deck_preview != null else Vector2.ZERO



func _refresh_prize_titles() -> void:
	_ensure_battle_overlay_coordinator()
	_battle_overlay_coordinator.call("refresh_prize_titles")



func _setup_dialog_gallery() -> void:
	_battle_dialog_controller.call("setup_dialog_gallery", self)


func _setup_discard_gallery() -> void:
	_battle_dialog_controller.call("setup_discard_gallery", self)


func _setup_field_interaction_panel() -> void:
	_ensure_battle_interaction_coordinator()
	_battle_interaction_coordinator.call("setup_field_interaction_panel")
	_sync_battle_interaction_state_from_scene()



func _setup_prize_viewer() -> void:
	_bind_prize_card_clicks()
	for i: int in _opp_prize_slots.size():
		var prize_slot: BattleCardView = _opp_prize_slots[i]
		if prize_slot == null:
			continue
		prize_slot.mouse_filter = Control.MOUSE_FILTER_STOP
	for i: int in _my_prize_slots.size():
		var prize_slot: BattleCardView = _my_prize_slots[i]
		if prize_slot == null:
			continue
		prize_slot.mouse_filter = Control.MOUSE_FILTER_STOP



func _bind_prize_card_clicks() -> void:
	for i: int in _opp_prize_slots.size():
		var prize_slot: BattleCardView = _opp_prize_slots[i]
		if prize_slot == null:
			continue
		var opp_input_callback := Callable(self, "_on_dynamic_prize_slot_input").bind("opp", i)
		if not prize_slot.gui_input.is_connected(opp_input_callback):
			prize_slot.gui_input.connect(opp_input_callback)
		var opp_click_callback := Callable(self, "_on_prize_slot_card_left_clicked").bind("opp", i)
		if not prize_slot.left_clicked.is_connected(opp_click_callback):
			prize_slot.left_clicked.connect(opp_click_callback)
	for i: int in _my_prize_slots.size():
		var prize_slot: BattleCardView = _my_prize_slots[i]
		if prize_slot == null:
			continue
		var my_input_callback := Callable(self, "_on_dynamic_prize_slot_input").bind("my", i)
		if not prize_slot.gui_input.is_connected(my_input_callback):
			prize_slot.gui_input.connect(my_input_callback)
		var my_click_callback := Callable(self, "_on_prize_slot_card_left_clicked").bind("my", i)
		if not prize_slot.left_clicked.is_connected(my_click_callback):
			prize_slot.left_clicked.connect(my_click_callback)



func _setup_battle_advice_ui() -> void:
	_ensure_battle_advice_coordinator()
	_battle_advice_coordinator.call("setup_battle_advice_ui")
	_sync_battle_advice_state_from_scene()



func _apply_replay_launch(launch: Dictionary) -> void:
	_battle_mode = "review_readonly"
	var prepared_variant: Variant = _battle_replay_controller.call("prepare_launch", launch)
	if not (prepared_variant is Dictionary):
		return
	var prepared: Dictionary = prepared_variant
	_replay_match_dir = str(prepared.get("match_dir", ""))
	_replay_entry_source = str(prepared.get("entry_source", ""))
	_replay_turn_numbers.clear()
	for turn_variant: Variant in prepared.get("turn_numbers", []):
		_replay_turn_numbers.append(int(turn_variant))
	var entry_turn_number := int(prepared.get("entry_turn_number", 0))
	_replay_current_turn_index = int(prepared.get("current_turn_index", -1))
	_refresh_replay_controls()
	if _replay_match_dir.strip_edges() != "" and entry_turn_number > 0:
		_load_replay_turn(entry_turn_number)



func _bind_discard_hud_openers() -> void:
	_bind_discard_open_control(_opp_discard if _opp_discard != null else find_child("OppDiscard", true, false) as Control, 1 - _view_player, "对方弃牌区")
	_bind_discard_open_control(_my_discard if _my_discard != null else find_child("MyDiscard", true, false) as Control, _view_player, "己方弃牌区")
	_bind_discard_open_control(find_child("OppDiscardHudPanel", true, false) as Control, 1 - _view_player, "对方弃牌区")
	_bind_discard_open_control(find_child("MyDiscardHudPanel", true, false) as Control, _view_player, "己方弃牌区")



func _bind_lost_zone_hud_openers() -> void:
	_bind_lost_zone_open_control(find_child("InfoEnemyLost", true, false) as Control, true)
	_bind_lost_zone_open_control(find_child("InfoMyLost", true, false) as Control, false)



func _show_deck_cards(player_index: int, title: String) -> void:
	_battle_display_controller.call("show_deck_cards", self, player_index, title)



func _init_battle_runtime_log() -> void:
	_battle_runtime_log_controller.call("init_battle_runtime_log", self)



func _release_game_state_machine() -> void:
	if _gsm == null:
		return
	var state_changed := Callable(self, "_on_state_changed")
	var action_logged := Callable(self, "_on_action_logged")
	var player_choice_required := Callable(self, "_on_player_choice_required")
	var game_over := Callable(self, "_on_game_over")
	var coin_flipped := Callable(self, "_on_coin_flipped")
	if _gsm.state_changed.is_connected(state_changed):
		_gsm.state_changed.disconnect(state_changed)
	if _gsm.action_logged.is_connected(action_logged):
		_gsm.action_logged.disconnect(action_logged)
	if _gsm.player_choice_required.is_connected(player_choice_required):
		_gsm.player_choice_required.disconnect(player_choice_required)
	if _gsm.game_over.is_connected(game_over):
		_gsm.game_over.disconnect(game_over)
	if _gsm.coin_flipper != null and _gsm.coin_flipper.coin_flipped.is_connected(coin_flipped):
		_gsm.coin_flipper.coin_flipped.disconnect(coin_flipped)
	_gsm.prepare_for_disposal()
	_gsm = null
	_sync_battle_scene_context_runtime()



func _handle_hand_drag_scroll_input(event: InputEvent, source: String = "external") -> bool:
	_ensure_battle_drag_scroll_coordinator()
	return bool(_battle_drag_scroll_coordinator.call("handle_hand_drag_scroll_input", event, source))



func _handle_card_gallery_drag_scroll_input(event: InputEvent, scroll: ScrollContainer, source: String = "card_gallery") -> bool:
	_ensure_battle_drag_scroll_coordinator()
	return bool(_battle_drag_scroll_coordinator.call("handle_card_gallery_drag_scroll_input", event, scroll, source))



func _debug_hand_drag_scroll_event(source: String, event: InputEvent, hand_scroll: ScrollContainer) -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("debug_hand_drag_scroll_event", source, event, hand_scroll)



func _show_portrait_actions_popup() -> void:
	var list := _ensure_portrait_actions_popup()
	if list == null:
		return
	_clear_container_children(list)
	var title := Label.new()
	title.text = "更多操作"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0, 1.0))
	list.add_child(title)
	for descriptor: Dictionary in _portrait_action_descriptors():
		var button := Button.new()
		button.text = str(descriptor.get("text", "操作"))
		button.disabled = bool(descriptor.get("disabled", false))
		button.custom_minimum_size = Vector2(0, PORTRAIT_ACTION_POPUP_BUTTON_HEIGHT)
		button.add_theme_font_size_override("font_size", 18)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_hud_button(button)
		var callback: Callable = descriptor.get("callback", Callable()) as Callable
		button.pressed.connect(func() -> void:
			if _portrait_actions_popup != null:
				_portrait_actions_popup.hide()
			if callback.is_valid():
				callback.call()
		)
		list.add_child(button)
	_apply_portrait_popup_text_metrics()
	_popup_portrait_panel()



func _apply_battle_canvas_transform(rotate_canvas: bool, physical_size: Vector2, logical_size: Vector2) -> void:
	if rotate_canvas:
		_rotated_portrait_canvas_active = true
		_rotated_portrait_physical_viewport_size = physical_size
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		offset_left = 0.0
		offset_top = 0.0
		offset_right = logical_size.x
		offset_bottom = logical_size.y
		pivot_offset = Vector2.ZERO
		position = Vector2(physical_size.x, 0.0)
		rotation = PI * 0.5
		scale = Vector2.ONE
		return
	_rotated_portrait_canvas_active = false
	_rotated_portrait_physical_viewport_size = Vector2.ZERO
	rotation = 0.0
	position = Vector2.ZERO
	pivot_offset = Vector2.ZERO
	scale = Vector2.ONE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = logical_size.x
	offset_bottom = logical_size.y



func _apply_landscape_layout_impl(viewport_size: Vector2) -> void:
	_ensure_battle_layout_coordinator()
	_battle_layout_coordinator.call("apply_landscape_direct", viewport_size)
	_sync_battle_layout_state_from_scene()



func _restore_landscape_overlay_z_order() -> void:
	var dialog_overlay := _dialog_overlay if _dialog_overlay != null else find_child("DialogOverlay", true, false) as Control
	var handover_panel := _handover_panel if _handover_panel != null else find_child("HandoverPanel", true, false) as Control
	if dialog_overlay != null:
		dialog_overlay.z_index = DIALOG_OVERLAY_Z_INDEX
		dialog_overlay.z_as_relative = true
		dialog_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if handover_panel != null:
		handover_panel.z_index = HANDOVER_OVERLAY_Z_INDEX
		handover_panel.z_as_relative = true
		handover_panel.mouse_filter = Control.MOUSE_FILTER_STOP



func _raise_modal_overlay_for_input(overlay: Control, z_index_value: int) -> void:
	if overlay == null:
		return
	overlay.z_index = z_index_value
	overlay.z_as_relative = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var parent := overlay.get_parent()
	if parent != null:
		parent.move_child(overlay, parent.get_child_count() - 1)


func _raise_coin_animator_to_front() -> void:
	if _coin_animator == null or not is_instance_valid(_coin_animator):
		return
	if _coin_animator is CanvasItem:
		var canvas_item := _coin_animator as CanvasItem
		canvas_item.z_index = COIN_FLIP_OVERLAY_Z_INDEX
		canvas_item.z_as_relative = true
	var parent := _coin_animator.get_parent()
	if parent != null:
		parent.move_child(_coin_animator, parent.get_child_count() - 1)



func _apply_portrait_layout_impl(viewport_size: Vector2) -> void:
	_active_battle_layout_mode = "portrait"
	_ensure_battle_layout_coordinator()
	_battle_layout_coordinator.call("apply_portrait_direct", viewport_size)



func _landscape_pile_row_gap(preview_card_size: Vector2) -> int:
	return clampi(int(preview_card_size.x * 0.10), 6, 10)



func _landscape_pile_panel_width(preview_card_size: Vector2) -> float:
	return maxf(preview_card_size.x + 8.0, 54.0)



func _move_lost_hud_to_pile(lost_panel: PanelContainer, lost_panel_height: float = 0.0, enemy_lost_above: bool = false) -> void:
	if lost_panel == null:
		return
	var enemy := str(lost_panel.name).contains("Enemy")
	var hud_vbox_name := "OppHudRightVBox" if enemy else "MyHudRightVBox"
	var row_name := "OppHudDataRow" if enemy else "MyHudDataRow"
	var hud_vbox := find_child(hud_vbox_name, true, false) as VBoxContainer
	var row := find_child(row_name, true, false) as BoxContainer
	if hud_vbox == null or row == null:
		return
	var row_index := row.get_index()
	var insert_index := row_index + 1
	if enemy and enemy_lost_above:
		var current_lost_index := lost_panel.get_index() if lost_panel.get_parent() == hud_vbox else row_index
		insert_index = mini(row_index, current_lost_index)
	_move_control_to_container(lost_panel, hud_vbox, insert_index)
	hud_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var row_width := row.custom_minimum_size.x
	if row_width <= 0.0:
		row_width = row.get_combined_minimum_size().x
	var row_height := row.custom_minimum_size.y
	if row_height <= 0.0:
		row_height = row.get_combined_minimum_size().y
	var resolved_height := lost_panel_height if lost_panel_height > 0.0 else _pile_lost_panel_height(row_height)
	lost_panel.visible = true
	lost_panel.clip_contents = true
	lost_panel.custom_minimum_size = Vector2(row_width, resolved_height)
	lost_panel.set_meta("_vstar_lost_exact_minimum_size", lost_panel.custom_minimum_size)
	lost_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lost_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bind_lost_zone_open_control(lost_panel, enemy)
	_style_vstar_lost_hud_panel(lost_panel, "lost", false)
	var value_label := lost_panel.find_child("EnemyLostValue" if enemy else "MyLostValue", true, false) as Label
	_apply_lost_hud_font_size(value_label)



func _ensure_pile_hud_row_container(row_path: String, vertical: bool) -> BoxContainer:
	var existing := get_node_or_null(row_path) as BoxContainer
	if existing == null:
		return null
	if (vertical and existing is VBoxContainer) or ((not vertical) and existing is HBoxContainer):
		existing.alignment = BoxContainer.ALIGNMENT_CENTER
		return existing
	var parent := existing.get_parent()
	if parent == null:
		return existing
	var replacement: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	replacement.name = existing.name
	replacement.unique_name_in_owner = existing.unique_name_in_owner
	replacement.visible = existing.visible
	replacement.mouse_filter = existing.mouse_filter
	replacement.custom_minimum_size = existing.custom_minimum_size
	replacement.size_flags_horizontal = existing.size_flags_horizontal
	replacement.size_flags_vertical = existing.size_flags_vertical
	replacement.size_flags_stretch_ratio = existing.size_flags_stretch_ratio
	replacement.alignment = BoxContainer.ALIGNMENT_CENTER
	replacement.add_theme_constant_override("separation", existing.get_theme_constant("separation"))
	var children := existing.get_children()
	for child: Node in children:
		child.owner = null
		existing.remove_child(child)
		replacement.add_child(child)
	var insert_index := existing.get_index()
	parent.remove_child(existing)
	parent.add_child(replacement)
	parent.move_child(replacement, insert_index)
	replacement.owner = null
	existing.queue_free()
	return replacement



func _find_control_by_name(node_name: String) -> Control:
	return find_child(node_name, true, false) as Control



func _restore_portrait_status_stack(
	stack_name: String,
	info_column: VBoxContainer,
	vstar_panel: PanelContainer,
	lost_panel: PanelContainer
) -> void:
	if info_column != null:
		_move_control_to_container(vstar_panel, info_column, 0)
	if vstar_panel != null:
		if vstar_panel.has_meta("_vstar_lost_exact_minimum_size"):
			vstar_panel.remove_meta("_vstar_lost_exact_minimum_size")
		vstar_panel.custom_minimum_size = Vector2.ZERO
		vstar_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vstar_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_sync_vstar_hud_image_metrics(vstar_panel)
	_move_lost_hud_to_pile(lost_panel)
	var stack := find_child(stack_name, true, false) as VBoxContainer
	if stack != null:
		stack.visible = false
		stack.custom_minimum_size = Vector2.ZERO

func _hide_landscape_status_layout(stack_name: String, left_spacer_name: String, right_slot_name: String) -> void:
	_hide_empty_status_stack(stack_name)
	for node_name: String in [left_spacer_name, right_slot_name]:
		var control := find_child(node_name, true, false) as Control
		if control == null:
			continue
		control.visible = false
		control.custom_minimum_size = Vector2.ZERO



func _find_panel_by_name(node_name: String) -> PanelContainer:
	return find_child(node_name, true, false) as PanelContainer



func _find_vbox_by_name(node_name: String) -> VBoxContainer:
	return find_child(node_name, true, false) as VBoxContainer



func _effective_dialog_card_scroll_height() -> float:
	if _dialog_card_scroll != null and bool(_dialog_card_scroll.get_meta("card_gallery_drag_scroll_active", false)) and bool(_dialog_card_scroll.get_meta("card_gallery_scrollbar_hidden", false)):
		return _card_gallery_scroll_height(_dialog_card_size.y)
	return _dialog_card_scroll_height()



func _ensure_portrait_bench_grid_rows(grid: Container, bench_rows: int) -> void:
	if grid == null or not (grid is VBoxContainer):
		return
	for row_index: int in bench_rows:
		var row_name := "Row%d" % row_index
		var row := grid.get_node_or_null(row_name) as HBoxContainer
		if row != null:
			continue
		row = HBoxContainer.new()
		row.name = row_name
		row.visible = true
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		grid.add_child(row)
		if grid.owner != null:
			row.owner = grid.owner



func _move_bench_children(source: Container, target: Container) -> void:
	if source == null or target == null or source == target:
		return
	var panels: Array[PanelContainer] = _bench_panel_children_recursive(source)
	if panels.is_empty():
		return
	var route_to_portrait_rows := target.get_node_or_null("Row0") is HBoxContainer and target.get_node_or_null("Row1") is HBoxContainer
	if route_to_portrait_rows:
		var row0 := target.get_node_or_null("Row0") as HBoxContainer
		var row1 := target.get_node_or_null("Row1") as HBoxContainer
		for index: int in panels.size():
			var row := row0 if index < 4 else row1
			_reparent_bench_panel(panels[index], row)
		return
	for panel: PanelContainer in panels:
		_reparent_bench_panel(panel, target)



func _try_handle_portrait_bench_play_input(event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if _consume_modal_slot_input_if_needed(event, "portrait_bench_grid"):
		return true
	if not _can_accept_live_action():
		return false
	if _is_field_interaction_active():
		return false
	if _selected_hand_card == null or _selected_hand_card.card_data == null or not _selected_hand_card.card_data.is_basic_pokemon():
		return false
	var slot_id := _portrait_bench_grid_hit_slot_id_for_screen_position(mouse_event.position)
	if slot_id == "":
		return false
	_handle_slot_left_click(slot_id)
	return true



func _ensure_battle_stadium_hud_coordinator() -> void:
	if _battle_stadium_hud_coordinator == null:
		_battle_stadium_hud_coordinator = BattleStadiumHudCoordinatorScript.new()
	_battle_stadium_hud_coordinator.call("setup", self)



func _apply_top_bar_space_metrics(viewport_size: Vector2, action_width: float = -1.0, action_gap: int = -1) -> void:
	var top_bar_row := get_node_or_null("TopBar/TopBarRow") as HBoxContainer
	var top_bar_left := get_node_or_null("TopBar/TopBarRow/TopBarLeft") as Control
	var top_bar_center := get_node_or_null("TopBar/TopBarRow/TopBarCenter") as Control
	var top_bar_right := get_node_or_null("TopBar/TopBarRow/TopBarRight") as Control
	var top_bar_right_box := top_bar_right as BoxContainer
	var top_bar_actions := get_node_or_null("TopBar/TopBarRow/TopBarRight/TopBarActions") as HBoxContainer
	var resolved_action_width := action_width if action_width > 0.0 else _resolve_top_action_button_width(viewport_size)
	var resolved_action_gap := action_gap if action_gap >= 0 else _resolve_top_action_gap(viewport_size)

	if top_bar_row != null:
		top_bar_row.add_theme_constant_override("separation", _resolve_top_row_gap(viewport_size))
	if top_bar_actions != null:
		top_bar_actions.add_theme_constant_override("separation", resolved_action_gap)
		top_bar_actions.size_flags_horizontal = Control.SIZE_SHRINK_END
		top_bar_actions.alignment = BoxContainer.ALIGNMENT_END

	if top_bar_left != null:
		top_bar_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_bar_left.custom_minimum_size = Vector2.ZERO
	if top_bar_center != null:
		top_bar_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_bar_center.custom_minimum_size = Vector2.ZERO
	if top_bar_right != null:
		top_bar_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_bar_right.custom_minimum_size = Vector2.ZERO
	if top_bar_right_box != null:
		top_bar_right_box.alignment = BoxContainer.ALIGNMENT_END

	for label: Label in [_lbl_phase, _lbl_turn]:
		if label == null:
			continue
		label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		label.clip_text = false
		label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING



func _portrait_direct_top_action_buttons() -> Array[Button]:
	if _is_review_mode():
		return [
			_top_action_button_or_null(_btn_replay_prev_turn, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnReplayPrevTurn"),
			_top_action_button_or_null(_btn_replay_next_turn, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnReplayNextTurn"),
			_top_action_button_or_null(_btn_replay_continue, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnReplayContinue"),
			_top_action_button_or_null(_btn_replay_back_to_list, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnReplayBackToList"),
			_top_action_button_or_null(_btn_back, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnBack"),
		]
	return [
		_top_action_button_or_null(_btn_opponent_hand, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnOpponentHand"),
		_top_action_button_or_null(_btn_battle_discuss_ai, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnBattleDiscussAI"),
		_top_action_button_or_null(_btn_zeus_help, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnZeusHelp"),
		_top_action_button_or_null(_btn_back, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnBack"),
	]



func _resolve_portrait_top_direct_button_width(viewport_size: Vector2, button_count: int, action_gap: int = -1, ui_scale: float = 1.0) -> float:
	var resolved_count := maxi(button_count, 1)
	var resolved_gap := action_gap if action_gap >= 0 else _resolve_top_action_gap(viewport_size)
	var safe_width := maxf(viewport_size.x, 1.0)
	var minimum_status_width := minf(24.0 * ui_scale, safe_width * 0.06)
	var max_actions_width := maxf(safe_width - minimum_status_width - float(_resolve_top_row_gap(viewport_size)), 58.0 * ui_scale)
	var preferred_actions_width := minf(safe_width * 0.98, max_actions_width)
	var budget_width := (preferred_actions_width - float(resolved_gap * maxi(resolved_count - 1, 0))) / float(resolved_count)
	var min_width := minf(58.0 * ui_scale * PORTRAIT_DIRECT_TOP_BUTTON_WIDTH_SCALE, maxf(38.0 * ui_scale, budget_width))
	var base_preferred_width := clampf(safe_width * 0.17, 58.0 * ui_scale, 76.0 * ui_scale)
	var preferred_width := base_preferred_width * PORTRAIT_DIRECT_TOP_BUTTON_WIDTH_SCALE
	return clampf(minf(preferred_width, budget_width), min_width, 126.0 * ui_scale)



func _resolve_vstar_lost_hud_base_size(panel: Control) -> Vector2:
	var current := panel.custom_minimum_size
	if panel.has_meta("_vstar_lost_base_minimum_size") and panel.has_meta("_vstar_lost_scaled_minimum_size"):
		var previous_base_variant: Variant = panel.get_meta("_vstar_lost_base_minimum_size")
		var previous_scaled_variant: Variant = panel.get_meta("_vstar_lost_scaled_minimum_size")
		if previous_base_variant is Vector2 and previous_scaled_variant is Vector2:
			var previous_scaled := previous_scaled_variant as Vector2
			if _vstar_lost_hud_size_matches(current, previous_scaled):
				return previous_base_variant as Vector2

	var combined := panel.get_combined_minimum_size()
	var actual := panel.size
	if current.x <= 0.0:
		current.x = actual.x if actual.x > 1.0 else combined.x
	if current.y <= 0.0:
		current.y = actual.y if actual.y > 1.0 else combined.y
	if current.x <= 0.0:
		current.x = 96.0
	if current.y <= 0.0:
		current.y = 28.0
	return current



func _style_panel(panel: Control, bg_color: Color, border_color: Color, radius: int = 18) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	if panel is PanelContainer:
		(panel as PanelContainer).add_theme_stylebox_override("panel", style)
	elif panel is Panel:
		(panel as Panel).add_theme_stylebox_override("panel", style)



func _is_turn_start_draw_action(action: GameAction) -> bool:
	if action == null or action.action_type != GameAction.ActionType.DRAW_CARD:
		return false
	if _gsm == null or _gsm.game_state == null:
		return false
	var gs: GameState = _gsm.game_state
	return (
		gs.phase == GameState.GamePhase.DRAW
		and action.player_index == gs.current_player_index
		and action.turn_number == gs.turn_number
	)



func _record_turn_start_snapshot_after_draw(action: GameAction) -> void:
	var key := "%d:%d" % [action.player_index, action.turn_number]
	if bool(_turn_start_snapshot_recorded_keys.get(key, false)):
		return
	_turn_start_snapshot_recorded_keys[key] = true
	_record_battle_state_snapshot("turn_start", {
		"action_type": action.action_type,
		"description": _format_action_description_for_display(action.description),
		"resolved_player_index": action.player_index,
	})



func _start_prize_selection(player_index: int, count: int) -> void:
	_ensure_battle_overlay_coordinator()
	_battle_overlay_coordinator.call("start_prize_selection", player_index, count)
	_sync_battle_dialog_state_from_scene()
	_sync_battle_overlay_state_from_scene()
	_sync_portrait_prize_hud_visibility()
	_show_portrait_prize_dialog_if_needed()
	if GameManager.current_mode == GameManager.GameMode.TWO_PLAYER:
		_check_two_player_handover()



func _begin_setup_flow() -> void:
	_setup_done = [false, false]
	_refresh_ui()
	_maybe_run_ai()
	_setup_player_active(0)



func _prompt_send_out_dialog(pi: int) -> void:
	_pending_choice = "send_out"
	var player: PlayerState = _gsm.game_state.players[pi]
	var available_bench: Array[PokemonSlot] = []
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot != null and not _gsm.effect_processor.is_effectively_knocked_out(bench_slot, _gsm.game_state):
			available_bench.append(bench_slot)
	var dialog_data := {
		"player": pi,
		"bench": available_bench,
		"allow_cancel": false,
		"min_select": 1,
		"max_select": 1,
	}
	_ensure_ai_opponent()
	var is_ai_prompt: bool = GameManager.current_mode == GameManager.GameMode.VS_AI and _ai_opponent != null and pi == _ai_opponent.player_index
	if is_ai_prompt:
		_dialog_data = dialog_data
		_dialog_items_data = available_bench.duplicate()
		_hide_field_interaction()
		if _dialog_overlay != null:
			_dialog_overlay.visible = false
		if _dialog_cancel != null:
			_dialog_cancel.visible = false
		_refresh_ui()
		_maybe_run_ai()
		return
	if GameManager.current_mode == GameManager.GameMode.TWO_PLAYER:
		if _defer_two_player_handover_until_attack_vfx_finished("send_out", func() -> void:
			_prompt_send_out_dialog(pi)
		):
			return
	if GameManager.current_mode == GameManager.GameMode.TWO_PLAYER and pi != _view_player:
		_show_handover_prompt(pi, func() -> void:
			_set_handover_panel_visible(false, "send_out_follow_up")
			_view_player = _preferred_live_view_player(pi)
			_refresh_ui()
			_show_send_out_dialog(pi)
		)
		return

	_set_handover_panel_visible(false, "send_out_direct")
	_view_player = _preferred_live_view_player(pi)
	_refresh_ui()
	_show_send_out_dialog(pi)



func _prompt_heavy_baton_dialog(
	pi: int,
	bench_targets: Array[PokemonSlot],
	energy_count: int,
	source_name: String,
	source_slot: PokemonSlot = null,
	source_energy: Array[CardInstance] = []
) -> void:
	_pending_choice = "heavy_baton_target"
	var dialog_data := {
		"player": pi,
		"bench": bench_targets.duplicate(),
		"source_slot": source_slot,
		"source_energy": source_energy.duplicate(),
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}
	_ensure_ai_opponent()
	var is_ai_prompt: bool = GameManager.current_mode == GameManager.GameMode.VS_AI and _ai_opponent != null and pi == _ai_opponent.player_index
	if is_ai_prompt:
		_dialog_data = dialog_data
		_dialog_items_data = bench_targets.duplicate()
		_hide_field_interaction()
		if _dialog_overlay != null:
			_dialog_overlay.visible = false
		if _dialog_cancel != null:
			_dialog_cancel.visible = false
		_set_handover_panel_visible(false, "heavy_baton_ai_owned")
		_refresh_ui()
		_maybe_run_ai()
		return
	if GameManager.current_mode == GameManager.GameMode.TWO_PLAYER:
		if _defer_two_player_handover_until_attack_vfx_finished("heavy_baton", func() -> void:
			_prompt_heavy_baton_dialog(pi, bench_targets, energy_count, source_name, source_slot, source_energy)
		):
			return
	if GameManager.current_mode == GameManager.GameMode.TWO_PLAYER and pi != _view_player:
		_show_handover_prompt(pi, func() -> void:
			_set_handover_panel_visible(false, "heavy_baton_follow_up")
			_view_player = _preferred_live_view_player(pi)
			_refresh_ui()
			call("_show_heavy_baton_dialog", pi, bench_targets, energy_count, source_name, source_slot, source_energy)
		)
		return
	_view_player = _preferred_live_view_player(pi)
	_refresh_ui()
	call("_show_heavy_baton_dialog", pi, bench_targets, energy_count, source_name, source_slot, source_energy)

func _prompt_exp_share_dialog(
	pi: int,
	bench_targets: Array[PokemonSlot],
	source_slot: PokemonSlot,
	source_energy: Array[CardInstance]
) -> void:
	_pending_choice = "exp_share_target"
	var dialog_data := {
		"player": pi,
		"bench": bench_targets.duplicate(),
		"source_slot": source_slot,
		"source_energy": source_energy.duplicate(),
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}
	_ensure_ai_opponent()
	var is_ai_prompt: bool = GameManager.current_mode == GameManager.GameMode.VS_AI and _ai_opponent != null and pi == _ai_opponent.player_index
	if is_ai_prompt:
		_dialog_data = dialog_data
		_dialog_items_data = bench_targets.duplicate()
		_hide_field_interaction()
		if _dialog_overlay != null:
			_dialog_overlay.visible = false
		if _dialog_cancel != null:
			_dialog_cancel.visible = false
		_set_handover_panel_visible(false, "exp_share_ai_owned")
		_refresh_ui()
		_maybe_run_ai()
		return
	if GameManager.current_mode == GameManager.GameMode.TWO_PLAYER:
		if _defer_two_player_handover_until_attack_vfx_finished("exp_share", func() -> void:
			_prompt_exp_share_dialog(pi, bench_targets, source_slot, source_energy)
		):
			return
	if GameManager.current_mode == GameManager.GameMode.TWO_PLAYER and pi != _view_player:
		_show_handover_prompt(pi, func() -> void:
			_set_handover_panel_visible(false, "exp_share_follow_up")
			_view_player = _preferred_live_view_player(pi)
			_refresh_ui()
			call("_show_exp_share_dialog", pi, bench_targets, source_slot, source_energy)
		)
		return
	_view_player = _preferred_live_view_player(pi)
	_refresh_ui()
	call("_show_exp_share_dialog", pi, bench_targets, source_slot, source_energy)

func _record_battle_event(event_data: Dictionary) -> void:
	_ensure_battle_recording_coordinator()
	_battle_recording_coordinator.call("record_event", event_data)



func _finalize_battle_recording(result_data: Dictionary) -> void:
	_ensure_battle_recording_coordinator()
	_battle_recording_coordinator.call("finalize", result_data)
	_sync_battle_recording_state_from_scene()



func _recording_phase_name() -> String:
	return str(_battle_recording_controller.call("recording_phase_name", self))



func _show_stadium_action_dialog(cp: int) -> void:
	_battle_dialog_controller.call("show_stadium_action_dialog", self, cp)



func _show_opponent_hand_cards() -> void:
	_battle_overlay_controller.call("show_opponent_hand_cards", self)



func _try_show_opponent_slot_detail_input(event: InputEvent, slot_id: String) -> bool:
	if not slot_id.begins_with("opp_"):
		return false
	if _is_field_interaction_active() or _draw_reveal_active:
		return false
	if not (event is InputEventMouseButton):
		return false
	var mbe := event as InputEventMouseButton
	if not mbe.pressed or not (mbe.button_index == MOUSE_BUTTON_LEFT or mbe.button_index == MOUSE_BUTTON_RIGHT):
		return false
	if not _show_slot_card_detail(slot_id):
		return false
	_runtime_log("opponent_slot_card_detail", "slot=%s button=%d %s" % [slot_id, int(mbe.button_index), _state_snapshot()])
	var detail_viewport := get_viewport()
	if detail_viewport != null:
		detail_viewport.set_input_as_handled()
	return true



func _show_slot_pokemon_action_if_available(slot_id: String) -> bool:
	if not slot_id.begins_with("my_"):
		return false
	if _selected_hand_card != null or _is_field_interaction_active():
		return false
	var gs: GameState = _gsm.game_state if _gsm != null else null
	if gs == null:
		return false
	var target_slot: PokemonSlot = _slot_from_id(slot_id, gs)
	if target_slot == null:
		return false
	var cp: int = gs.current_player_index
	_show_pokemon_action_dialog(cp, target_slot, slot_id == "my_active")
	return true



func _slot_touch_release_can_open_action_hud(slot_id: String) -> bool:
	if not slot_id.begins_with("my_"):
		return false
	if _selected_hand_card != null or _is_field_interaction_active():
		return false
	var gs: GameState = _gsm.game_state if _gsm != null else null
	if gs == null:
		return false
	var target_slot: PokemonSlot = _slot_from_id(slot_id, gs)
	return target_slot != null



func _handle_slot_touch_detail_input(event: InputEvent, slot_id: String) -> bool:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_start_slot_touch_action_press(slot_id, touch.position, touch.index)
			var press_viewport := get_viewport()
			if press_viewport != null:
				press_viewport.set_input_as_handled()
			return true
		else:
			if _slot_touch_long_press_active and touch.index == _slot_touch_long_press_index:
				var consumed := _slot_touch_long_press_consumed
				_cancel_slot_touch_long_press(false)
				var release_viewport := get_viewport()
				if release_viewport != null:
					release_viewport.set_input_as_handled()
				if consumed:
					return true
				_suppress_next_slot_left_click_id = slot_id
				_handle_slot_left_click(slot_id)
				return true
		return false

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _slot_touch_long_press_active and drag.index == _slot_touch_long_press_index:
			var drag_viewport := get_viewport()
			if drag_viewport != null:
				drag_viewport.set_input_as_handled()
			if drag.position.distance_to(_slot_touch_long_press_start) > SLOT_TOUCH_LONG_PRESS_MOVE_TOLERANCE:
				_suppress_next_slot_left_click_id = slot_id
				_slot_touch_long_press_consumed = true
			return true
		return false

	return false



func _consume_suppressed_slot_left_click(slot_id: String) -> bool:
	if _suppress_next_slot_left_click_id == "":
		return false
	if _suppress_next_slot_left_click_id != slot_id:
		return false
	_suppress_next_slot_left_click_id = ""
	return true



func _consume_recent_slot_followup_click(event: InputEvent, slot_id: String) -> bool:
	if _suppress_slot_followup_click_id == "":
		return false
	if Time.get_ticks_msec() > _suppress_slot_followup_click_until_msec:
		_suppress_slot_followup_click_id = ""
		_suppress_slot_followup_click_until_msec = 0
		return false
	if _suppress_slot_followup_click_id != slot_id:
		return false
	if not _is_slot_followup_click_event(event):
		return false
	_suppress_slot_followup_click_id = ""
	_suppress_slot_followup_click_until_msec = 0
	_cancel_slot_touch_long_press(false)
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	_runtime_log("slot_followup_click_consumed", "slot=%s event=%s" % [slot_id, event.get_class()])
	return true



func _ensure_slot_touch_long_press_timer() -> void:
	if _slot_touch_long_press_timer != null:
		return
	_slot_touch_long_press_timer = Timer.new()
	_slot_touch_long_press_timer.name = "SlotTouchLongPressTimer"
	_slot_touch_long_press_timer.one_shot = true
	_slot_touch_long_press_timer.wait_time = SLOT_TOUCH_LONG_PRESS_SECONDS
	_slot_touch_long_press_timer.timeout.connect(Callable(self, "_on_slot_touch_long_press_timeout"))
	add_child(_slot_touch_long_press_timer)



func _cancel_field_interaction() -> void:
	_ensure_battle_interaction_coordinator()
	_battle_interaction_coordinator.call("cancel")
	_sync_battle_interaction_state_from_scene()



func _finalize_field_slot_selection() -> void:
	_ensure_battle_interaction_coordinator()
	_battle_interaction_coordinator.call("confirm_slot_selection")
	_sync_battle_interaction_state_from_scene()



func _finalize_field_assignment_selection() -> void:
	_ensure_battle_interaction_coordinator()
	_battle_interaction_coordinator.call("confirm_assignment_selection")
	_sync_battle_interaction_state_from_scene()



func _selection_label_from_item(item: Variant, fallback: String = "") -> String:
	return _battle_dialog_controller.call("selection_label_from_item", item, fallback)



func _on_dialog_card_chosen(real_index: int) -> void:
	_battle_dialog_controller.call("on_dialog_card_chosen", self, real_index)



func _is_card_gallery_drag_click_suppressed() -> bool:
	_ensure_battle_drag_scroll_coordinator()
	return bool(_battle_drag_scroll_coordinator.call("is_card_gallery_drag_click_suppressed"))



func _inject_followup_steps() -> void:
	_battle_effect_interaction_controller.call("inject_followup_steps", self)



func _ensure_battle_prompt_router() -> void:
	if _battle_prompt_router == null:
		_battle_prompt_router = BattlePromptRouterScript.new()
	_battle_prompt_router.call("setup", _battle_scene_context)



func _after_setup_active(pi: int) -> void:
	_view_player = _preferred_live_view_player(pi)
	_refresh_ui()
	_show_setup_bench_dialog(pi)
	_maybe_run_ai()



func _after_setup_bench(pi: int) -> void:
	_setup_done[pi] = true
	_view_player = _preferred_live_view_player(pi)
	_refresh_ui()
	if pi == 0 and not _setup_done[1]:
		_setup_player_active(1)
	else:
		if _gsm.setup_complete(0):
			_view_player = _preferred_live_view_player(_gsm.game_state.current_player_index)
			_refresh_ui()
			_check_two_player_handover()
	if _ai_running and GameManager.current_mode == GameManager.GameMode.VS_AI:
		_ensure_ai_opponent()
		if _ai_opponent != null and _gsm != null and _gsm.game_state != null:
			var next_setup_owner: int = _get_ai_prompt_player_index()
			if (_pending_choice != "" and next_setup_owner == _ai_opponent.player_index) \
				or _gsm.game_state.current_player_index == _ai_opponent.player_index:
				_ai_followup_requested = true
	_maybe_run_ai()



func _resolve_zeus_help_selected_cards(
	player_index: int,
	dialog_cards: Array,
	selected_indices: PackedInt32Array
) -> Array[CardInstance]:
	var selected_cards: Array[CardInstance] = []
	if _gsm == null or _gsm.game_state == null:
		return selected_cards
	if player_index < 0 or player_index >= _gsm.game_state.players.size():
		return selected_cards
	var player: PlayerState = _gsm.game_state.players[player_index]
	for selected_idx: int in selected_indices:
		if selected_idx < 0 or selected_idx >= dialog_cards.size():
			continue
		var candidate: Variant = dialog_cards[selected_idx]
		if candidate is CardInstance and candidate in player.deck and candidate not in selected_cards:
			selected_cards.append(candidate)
	return selected_cards

func _apply_zeus_help(player_index: int, selected_cards: Array[CardInstance]) -> void:
	if _gsm == null or _gsm.game_state == null:
		return
	if player_index < 0 or player_index >= _gsm.game_state.players.size():
		return
	var player: PlayerState = _gsm.game_state.players[player_index]
	var added_count: int = 0
	for card: CardInstance in selected_cards:
		if card in player.deck:
			player.deck.erase(card)
			card.face_up = true
			player.hand.append(card)
			added_count += 1
	player.shuffle_deck()
	if is_inside_tree():
		if added_count > 0:
			_log("宙斯帮我：加入了 %d 张牌到手牌。" % added_count)
		else:
			_log("宙斯帮我：未选择卡牌。")
		_refresh_ui()



func _try_use_attack_with_interaction(
	player_index: int,
	slot: PokemonSlot,
	attack_index: int,
	preselected_targets: Array = []
) -> void:
	if not _gsm.can_use_attack(player_index, attack_index):
		_log(_gsm.get_attack_unusable_reason(player_index, attack_index))
		return
	var card: CardInstance = slot.get_top_card()
	if card == null:
		return
	var attack: Dictionary = card.card_data.attacks[attack_index]
	var steps: Array[Dictionary] = []
	var effects: Array[BaseEffect] = _gsm.effect_processor.get_attack_effects_for_slot(slot, attack_index)
	for effect: BaseEffect in effects:
		steps.append_array(effect.get_attack_interaction_steps(card, attack, _gsm.game_state))
	var defender: PokemonSlot = null
	if _gsm != null and _gsm.game_state != null and player_index >= 0 and player_index < _gsm.game_state.players.size():
		defender = _gsm.game_state.players[1 - player_index].active_pokemon
	steps.append_array(_gsm.get_post_damage_defender_interaction_steps(slot, defender))
	if not preselected_targets.is_empty():
		if _gsm.use_attack(player_index, attack_index, preselected_targets):
			_refresh_ui_after_successful_action(true, player_index)
		else:
			_log(_gsm.get_attack_unusable_reason(player_index, attack_index))
		return
	if steps.is_empty():
		if _gsm.use_attack(player_index, attack_index):
			_refresh_ui_after_successful_action(true, player_index)
		else:
			_log(_gsm.get_attack_unusable_reason(player_index, attack_index))
		return
	_start_effect_interaction("attack", player_index, steps, card, slot, attack_index, {}, effects)
	_maybe_run_ai()

func _try_use_granted_attack_with_interaction(player_index: int, slot: PokemonSlot, granted_attack: Dictionary) -> void:
	if not _can_use_granted_attack(player_index, slot, granted_attack):
		_log(_get_granted_attack_unusable_reason(player_index, slot, granted_attack))
		return
	var card: CardInstance = slot.get_top_card()
	if card == null:
		return
	var steps: Array[Dictionary] = _gsm.effect_processor.get_granted_attack_interaction_steps(
		slot,
		granted_attack,
		_gsm.game_state
	)
	if steps.is_empty():
		if _gsm.use_granted_attack(player_index, slot, granted_attack):
			_refresh_ui_after_successful_action(true, player_index)
		else:
			_log(_get_granted_attack_unusable_reason(player_index, slot, granted_attack))
		return
	_start_effect_interaction("granted_attack", player_index, steps, card, slot, -1, granted_attack)
	_maybe_run_ai()



func _retreat_selection_is_valid(active: PokemonSlot, chosen_energy: Array[CardInstance], retreat_cost: int) -> bool:
	if active == null:
		return false
	if retreat_cost <= 0:
		return chosen_energy.is_empty()
	if chosen_energy.is_empty():
		return false
	if not _gsm.rule_validator.has_enough_energy_to_retreat(
		active,
		chosen_energy,
		retreat_cost,
		_gsm.effect_processor,
		_gsm.game_state
	):
		return false
	for remove_index: int in chosen_energy.size():
		var reduced_selection: Array[CardInstance] = chosen_energy.duplicate()
		reduced_selection.remove_at(remove_index)
		if _gsm.rule_validator.has_enough_energy_to_retreat(
			active,
			reduced_selection,
			retreat_cost,
			_gsm.effect_processor,
			_gsm.game_state
		):
			return false
	return true



func _resolve_retreat_energy_selection(selected_indices: PackedInt32Array, energy_options: Array[CardInstance]) -> Array[CardInstance]:
	var chosen_energy: Array[CardInstance] = []
	for selected_index: int in selected_indices:
		if selected_index < 0 or selected_index >= energy_options.size():
			continue
		chosen_energy.append(energy_options[selected_index])
	return chosen_energy



func _show_retreat_dialog(cp: int) -> void:
	if _gsm == null or _gsm.game_state == null:
		return
	if cp < 0 or cp >= _gsm.game_state.players.size():
		return
	var player: PlayerState = _gsm.game_state.players[cp]
	var active: PokemonSlot = player.active_pokemon
	if active == null:
		return
	var retreat_cost: int = _gsm.effect_processor.get_effective_retreat_cost(active, _gsm.game_state)
	if _retreat_requires_energy_choice(active, retreat_cost):
		_show_retreat_energy_dialog(cp, active, retreat_cost)
		return
	_show_retreat_bench_choice(cp, _default_retreat_energy_selection(active, retreat_cost))



func _on_match_end_return_pressed() -> void:
	if GameManager.is_tournament_battle_active():
		GameManager.finalize_current_tournament_battle(_battle_review_winner_index, _battle_review_reason)
		GameManager.goto_tournament_standings()
	else:
		GameManager.goto_battle_setup()



func _try_use_ability_with_interaction(player_index: int, slot: PokemonSlot, ability_index: int) -> void:
	_battle_action_controller.call("try_use_ability_with_interaction", self, player_index, slot, ability_index)



func _try_use_stadium_with_interaction(player_index: int) -> void:
	_battle_action_controller.call("try_use_stadium_with_interaction", self, player_index)



func _handle_effect_interaction_choice(selected_indices: PackedInt32Array) -> void:
	_battle_effect_interaction_controller.call("handle_effect_interaction_choice", self, selected_indices)



func _begin_match_end_quick_review(force: bool = false) -> void:
	if _match_end_quick_review_busy:
		return
	if _match_end_quick_review_requested and not force:
		return
	if not _match_end_quick_review_configured():
		_match_end_quick_review_result = _local_match_end_quick_review()
		_ensure_battle_overlay_coordinator()
		_battle_overlay_coordinator.call("refresh_match_end_screen")
		return
	if force:
		_match_end_quick_review_result = {}
	if _match_end_stats.is_empty():
		_match_end_stats = _build_match_end_stats(_battle_review_winner_index, _battle_review_reason)
	_ensure_match_end_quick_review_service()
	if _match_end_quick_review_service == null:
		_on_match_end_quick_review_completed({
			"status": "failed",
			"errors": [{
				"message": "赛后快评服务不可用",
				"error_type": "quick_review_service_unavailable",
			}],
		})
		return
	_match_end_quick_review_requested = true
	_match_end_quick_review_busy = true
	_match_end_quick_review_progress_text = "正在让 %s 快速点评..." % _match_end_quick_review_model_label()
	_ensure_battle_overlay_coordinator()
	_battle_overlay_coordinator.call("refresh_match_end_screen")
	_match_end_quick_review_service.call(
		"generate_quick_review",
		self,
		_build_match_end_quick_review_payload(),
		GameManager.get_battle_review_api_config()
	)



func _current_match_end_review_action() -> Dictionary:
	return _battle_dialog_controller.call("current_match_end_review_action", self)



func _begin_battle_review_generation() -> void:
	_ensure_battle_advice_coordinator()
	_battle_advice_coordinator.call("begin_battle_review_generation")
	_sync_battle_advice_state_from_scene()



func _open_cached_battle_review() -> void:
	_battle_overlay_controller.call("open_cached_battle_review", self)



func _current_match_end_learning_action() -> Dictionary:
	return _battle_dialog_controller.call("current_match_end_learning_action", self)



func _mark_current_match_for_learning() -> void:
	if _battle_review_match_dir.strip_edges() == "" or _battle_learning_store == null:
		_log("当前对局暂无可标记的录像")
		return
	if not _battle_learning_store.has_method("mark_match_for_learning"):
		_log("学习池功能不可用")
		return
	var ok := bool(_battle_learning_store.call("mark_match_for_learning", _battle_review_match_dir, {
		"winner_index": _battle_review_winner_index,
		"reason": _battle_review_reason,
	}))
	if ok:
		_log("已加入AI学习池")
		_show_match_end_dialog(_battle_review_winner_index, _battle_review_reason)
	else:
		_log("加入AI学习池失败")



func _popup_battle_discussion_dialog_for_current_layout() -> void:
	if _battle_discussion_dialog == null or not is_instance_valid(_battle_discussion_dialog):
		return
	if _is_portrait_popup_text_profile_active():
		var frame_rect := _battle_discussion_popup_frame_rect()
		_battle_discussion_dialog.call("popup_for_viewport", frame_rect, true)
		return
	if _battle_discussion_dialog.has_method("apply_desktop_profile"):
		_battle_discussion_dialog.call("apply_desktop_profile")
	if _battle_discussion_dialog.is_inside_tree():
		_battle_discussion_dialog.popup_centered(Vector2i(980, 760))
	_battle_discussion_dialog.size = Vector2i(980, 760)



func _battle_discussion_current_signature() -> String:
	return str(_battle_discussion_context_builder.call("current_signature", GameManager.selected_deck_ids, GameManager.current_mode, int(_view_player)))



func _battle_discussion_session_id() -> int:
	return int(_battle_discussion_context_builder.call("session_id", GameManager.selected_deck_ids, int(_view_player)))



func _battle_discussion_view_deck() -> DeckData:
	if GameManager.selected_deck_ids.size() <= _view_player:
		return null
	return GameManager.resolve_selected_battle_deck(_view_player)



func _build_battle_discussion_context() -> Dictionary:
	var snapshot := _build_battle_state_snapshot()
	var view_player := int(_view_player)
	var opponent_index := 1 - view_player
	var context_variant: Variant = _battle_discussion_context_builder.call(
		"build_context",
		snapshot,
		view_player,
		GameManager.resolve_selected_battle_deck(view_player),
		GameManager.resolve_selected_battle_deck(opponent_index)
	)
	return context_variant if context_variant is Dictionary else {}



func _start_battle_discussion_flash() -> void:
	if _btn_battle_discuss_ai == null or not is_instance_valid(_btn_battle_discuss_ai) or not _btn_battle_discuss_ai.visible:
		return
	_stop_battle_discussion_flash()
	_battle_discussion_flash_tween = create_tween()
	_battle_discussion_flash_tween.set_loops()
	_battle_discussion_flash_tween.tween_property(_btn_battle_discuss_ai, "self_modulate", Color(0.28, 1.0, 0.95, 1.0), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_battle_discussion_flash_tween.tween_property(_btn_battle_discuss_ai, "self_modulate", Color(1.0, 1.0, 1.0, 1.0), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)



func _on_end_turn(action_player_index: int = -1) -> void:
	if not _can_accept_live_action() or _gsm == null or _is_field_interaction_active():
		return
	_selected_hand_card = null
	_refresh_hand()
	_gsm.end_turn(_gsm.game_state.current_player_index)
	_check_two_player_handover()
	if _should_pause_after_ai_action(action_player_index):
		_start_ai_action_pause()



func _reset_ai_action_counter_if_needed() -> void:
	if _gsm == null or _gsm.game_state == null:
		_ai_turn_marker = ""
		_ai_actions_this_turn = 0
		return
	var marker := "%d:%d" % [_gsm.game_state.turn_number, _gsm.game_state.current_player_index]
	if marker != _ai_turn_marker:
		_ai_turn_marker = marker
		_ai_actions_this_turn = 0



func _should_wait_for_llm() -> bool:
	if _ai_opponent == null:
		return false
	var strategy: Variant = _ai_opponent.get("_deck_strategy")
	if strategy == null or not strategy.has_method("is_llm_pending"):
		return false
	if _gsm == null or _gsm.game_state == null:
		return false
	if _pending_choice.begins_with("setup_active_") or _pending_choice == "send_out":
		return false
	var turn: int = int(_gsm.game_state.turn_number)
	if strategy.has_method("is_llm_disabled_for_turn") and strategy.call("is_llm_disabled_for_turn", turn):
		return false
	if strategy.has_method("has_llm_plan_for_turn") and strategy.call("has_llm_plan_for_turn", turn):
		return false
	if strategy.has_method("ensure_llm_request_fired"):
		var legal_actions: Array[Dictionary] = _ai_opponent.get_legal_actions(_gsm)
		strategy.call("ensure_llm_request_fired", _gsm.game_state, _ai_opponent.player_index, legal_actions)
	if strategy.has_method("is_llm_soft_timed_out_for_turn") and strategy.call("is_llm_soft_timed_out_for_turn", turn):
		if strategy.has_method("force_rules_for_turn"):
			strategy.call("force_rules_for_turn", turn, "soft timeout")
		_ai_llm_waiting = false
		_stop_llm_wait_hud()
		_log("[LLM] turn %d: soft timeout, using rules" % turn)
		return false
	if strategy.call("is_llm_pending"):
		if not _ai_llm_waiting or _ai_llm_turn_requested != turn or _ai_llm_wait_started_msec <= 0:
			_ai_llm_waiting = true
			_ai_llm_turn_requested = turn
			_start_llm_wait_hud(turn)
		else:
			_ai_llm_waiting = true
		return true
	return false



func _register_effects_from_game_state(gs: GameState) -> void:
	if gs == null or _gsm == null:
		return
	for player: PlayerState in gs.players:
		var all_cards: Array[CardInstance] = []
		all_cards.append_array(player.hand)
		all_cards.append_array(player.deck)
		all_cards.append_array(player.prizes)
		all_cards.append_array(player.discard_pile)
		all_cards.append_array(player.lost_zone)
		if player.active_pokemon != null:
			all_cards.append_array(player.active_pokemon.pokemon_stack)
			all_cards.append_array(player.active_pokemon.attached_energy)
			if player.active_pokemon.attached_tool != null:
				all_cards.append(player.active_pokemon.attached_tool)
		for bench_slot: PokemonSlot in player.bench:
			if bench_slot == null:
				continue
			all_cards.append_array(bench_slot.pokemon_stack)
			all_cards.append_array(bench_slot.attached_energy)
			if bench_slot.attached_tool != null:
				all_cards.append(bench_slot.attached_tool)
		for card: CardInstance in all_cards:
			if card != null and card.card_data != null:
				_gsm.effect_processor.register_pokemon_card(card.card_data)



func _clear_replay_ui_state() -> void:
	var empty_state_variant: Variant = _battle_replay_controller.call("empty_state")
	if empty_state_variant is Dictionary:
		var empty_state: Dictionary = empty_state_variant
		_replay_match_dir = str(empty_state.get("match_dir", ""))
		_replay_turn_numbers.clear()
		for turn_variant: Variant in empty_state.get("turn_numbers", []):
			_replay_turn_numbers.append(int(turn_variant))
		_replay_current_turn_index = int(empty_state.get("current_turn_index", -1))
		_replay_entry_source = str(empty_state.get("entry_source", ""))
		_replay_loaded_raw_snapshot = (empty_state.get("loaded_raw_snapshot", {}) as Dictionary).duplicate(true)
		_replay_loaded_view_snapshot = (empty_state.get("loaded_view_snapshot", {}) as Dictionary).duplicate(true)
	_pending_choice = ""
	_set_pending_handover_action(Callable(), "replay_continue")
	_set_handover_panel_visible(false, "replay_continue")
	if _dialog_overlay != null:
		_dialog_overlay.visible = false
	if _review_overlay != null:
		_review_overlay.visible = false



func _effect_state_snapshot() -> String:
	return str(_battle_runtime_log_controller.call("effect_state_snapshot", self))



func _play_next_coin_animation() -> void:
	if _coin_flip_queue.is_empty():
		_coin_animating = false
		if _coin_animation_resume_effect_step:
			_coin_animation_resume_effect_step = false
			_show_next_effect_interaction_step()
		_maybe_run_ai()
		return
	if _coin_animator == null or not _coin_animator.has_method("play"):
		_coin_flip_queue.clear()
		_coin_animating = false
		if _coin_animation_resume_effect_step:
			_coin_animation_resume_effect_step = false
			_show_next_effect_interaction_step()
		_maybe_run_ai()
		return
	_coin_animating = true
	var result: bool = _coin_flip_queue.pop_front()
	if _coin_animator.has_method("apply_viewport_metrics"):
		var coin_viewport_size := _portrait_dialog_viewport_size() if _is_portrait_battle_layout_active() else (get_viewport_rect().size if is_inside_tree() else size)
		_coin_animator.call("apply_viewport_metrics", coin_viewport_size, _is_portrait_battle_layout_active())
	_raise_coin_animator_to_front()
	_coin_animator.play(result)



func _show_discard_pile(player_index: int, title: String) -> void:
	_ensure_battle_display_coordinator()
	_battle_display_coordinator.call("show_discard_pile", player_index, title)



func _show_lost_zone(player_index: int, title: String) -> void:
	_ensure_battle_display_coordinator()
	_battle_display_coordinator.call("show_lost_zone", player_index, title)



func _bind_slot_input_handler(control: Control, slot_id: String) -> void:
	if control == null:
		return
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	var callback := Callable(self, "_on_slot_input").bind(slot_id)
	if not control.gui_input.is_connected(callback):
		control.gui_input.connect(callback)



func _apply_ai_fixed_deck_order_override(ai_deck: DeckData) -> void:
	if _gsm == null or GameManager.current_mode != GameManager.GameMode.VS_AI:
		return
	var selection: Dictionary = GameManager.ai_selection
	if str(selection.get("opening_mode", "default")) != "fixed_order":
		return
	if _ai_fixed_deck_order_registry == null:
		return
	var fixed_order_path := str(selection.get("fixed_deck_order_path", ""))
	var fixed_order: Array[Dictionary] = _ai_fixed_deck_order_registry.call("load_fixed_order_from_path", fixed_order_path)
	if fixed_order.is_empty():
		_runtime_log("fixed_deck_order_missing", "deck=%d path=%s" % [ai_deck.id if ai_deck != null else -1, fixed_order_path])
		return
	_gsm.call("set_deck_order_override", 1, fixed_order)
	_runtime_log("fixed_deck_order_applied", "deck=%d cards=%d" % [ai_deck.id if ai_deck != null else -1, fixed_order.size()])


func _capture_battle_recording_context_if_ready() -> void:
	_ensure_battle_recording_coordinator()
	_battle_recording_coordinator.call("capture_context_if_ready")
	_sync_battle_recording_state_from_scene()



func _ensure_battle_recording_started() -> void:
	_ensure_battle_recording_coordinator()
	_battle_recording_coordinator.call("ensure_started")
	_sync_battle_recording_state_from_scene()



func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	_ensure_battle_layout_coordinator()
	var preferred_mode := str(GameManager.get("battle_layout_mode")) if GameManager != null else "auto"
	var is_mobile := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	_trace_portrait_layout_stage("scene.apply_responsive.before_coordinator")
	_battle_layout_coordinator.call("apply", viewport_size, preferred_mode, is_mobile)
	_trace_portrait_layout_stage("scene.apply_responsive.after_coordinator")
	_update_battle_layout_button()
	_trace_portrait_layout_stage("scene.apply_responsive.after_layout_button")
	_style_vstar_lost_huds()
	_trace_portrait_layout_stage("scene.apply_responsive.after_vstar_lost_style")
	_style_end_turn_hud_buttons()
	_trace_portrait_layout_stage("scene.apply_responsive.after_end_turn_style")
	_finalize_portrait_layout_constraints()
	_layout_llm_wait_label()
	_trace_portrait_layout_stage("scene.apply_responsive.after_finalize")
	call_deferred("_deferred_finalize_portrait_layout_constraints")
	_request_portrait_layout_debug_overlay_refresh()



func _install_battle_backdrop() -> void:
	if has_node("BattleBackdrop"):
		return

	var backdrop := TextureRect.new()
	backdrop.name = "BattleBackdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.texture = _load_battle_backdrop_texture()
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(backdrop)
	move_child(backdrop, 0)



func _apply_battle_surface_styles() -> void:
	_ensure_battle_surface_styler()
	_battle_surface_styler.call("apply_battle_surface_styles")


func _should_defer_initial_battle_orientation_for_runtime(is_mobile_runtime: bool) -> bool:
	# Android/iOS orientation changes are system-level and can redraw the previous
	# scene before the new battle scene has presented its first frame.
	return is_mobile_runtime



func _is_mobile_runtime() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")



func _sync_bench_slot_visibility(display_size: Variant = -1) -> void:
	var my_size := BENCH_SIZE
	var opp_size := BENCH_SIZE
	if display_size is Dictionary:
		my_size = int((display_size as Dictionary).get("my", BENCH_SIZE))
		opp_size = int((display_size as Dictionary).get("opp", BENCH_SIZE))
	else:
		var resolved_size := int(display_size)
		if resolved_size < 0:
			var display_sizes := _current_bench_display_sizes()
			my_size = int(display_sizes.get("my", BENCH_SIZE))
			opp_size = int(display_sizes.get("opp", BENCH_SIZE))
		else:
			my_size = resolved_size
			opp_size = resolved_size
	my_size = clampi(my_size, BENCH_SIZE, MAX_BENCH_SIZE)
	opp_size = clampi(opp_size, BENCH_SIZE, MAX_BENCH_SIZE)
	for index: int in MAX_BENCH_SIZE:
		_set_bench_panel_visible(find_child("MyBench%d" % index, true, false) as Control, index < my_size)
		_set_bench_panel_visible(find_child("OppBench%d" % index, true, false) as Control, index < opp_size)
	var snapshot := my_size * 100 + opp_size
	if snapshot != _bench_display_size_snapshot:
		_bench_display_size_snapshot = snapshot
		_schedule_responsive_layout_stabilization()



func _ensure_bench_panel_capacity(capacity: int) -> void:
	_ensure_bench_container_panel_capacity(_my_bench, "MyBench", "MyBenchLbl", capacity)
	_ensure_bench_container_panel_capacity(_opp_bench, "OppBench", "OppBenchLbl", capacity)



func _install_slot_card_view(slot_id: String, panel: PanelContainer, mode: String) -> void:
	if panel == null:
		return

	for child: Node in panel.get_children():
		if child is RichTextLabel:
			child.visible = false

	var card_view = BATTLE_CARD_VIEW.new()
	card_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_view.set_clickable(false)
	card_view.setup_from_instance(null, mode)
	if card_view.has_method("set_field_slot_layout_size"):
		card_view.call("set_field_slot_layout_size", panel.custom_minimum_size)
	panel.add_child(card_view)
	_slot_card_views[slot_id] = card_view



func _load_card_back_texture(resource_path: String, is_player_side: bool) -> Texture2D:
	return _battle_layout_controller.call("load_card_back_texture", resource_path, is_player_side)


func _build_prize_slots(box: VBoxContainer, back_texture: Texture2D) -> Array[BattleCardView]:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(center)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	center.add_child(grid)

	var slots: Array[BattleCardView] = []
	for _i: int in 6:
		var card_view := BATTLE_CARD_VIEW.new()
		card_view.name = "PrizeCardView"
		card_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card_view.set_clickable(false)
		card_view.set_compact_preview(true)
		card_view.set_back_texture(back_texture)
		card_view.setup_from_instance(null, BATTLE_CARD_VIEW.MODE_PREVIEW)
		card_view.set_face_down(true)
		grid.add_child(card_view)
		slots.append(card_view)
	return slots



func _insert_pile_preview(box: VBoxContainer, child_index: int, clickable: bool, back_texture: Texture2D = null) -> BattleCardView:
	var preview := BATTLE_CARD_VIEW.new()
	preview.set_clickable(clickable)
	preview.set_back_texture(back_texture)
	preview.setup_from_instance(null, BATTLE_CARD_VIEW.MODE_PREVIEW)
	preview.set_info("", "")
	box.add_child(preview)
	box.move_child(preview, child_index)
	return preview



func _stop_all_deck_shuffle_effects() -> void:
	_ensure_battle_deck_shuffle_animator()
	_battle_deck_shuffle_animator.call("stop_all_deck_shuffle_effects")



func _prize_player_index_for_visible_side(side: String) -> int:
	return _view_player if side == "my" else 1 - _view_player



func _on_dynamic_prize_slot_input(event: InputEvent, side: String, slot_index: int) -> void:
	var player_index := _prize_player_index_for_visible_side(side)
	_on_prize_slot_input(event, player_index, "Prize", slot_index)



func _on_prize_slot_card_left_clicked(_card_instance: CardInstance, _card_data: CardData, side: String, slot_index: int) -> void:
	var player_index := _prize_player_index_for_visible_side(side)
	_try_take_prize_from_slot(player_index, slot_index)



func _on_prize_slot_input(event: InputEvent, player_index: int, title: String, slot_index: int) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var touch_viewport := get_viewport()
		if touch_viewport != null:
			touch_viewport.set_input_as_handled()
		if not touch.pressed:
			_try_take_prize_from_slot(player_index, slot_index)
		return
	if not (event is InputEventMouseButton):
		return
	var mbe := event as InputEventMouseButton
	if not mbe.pressed:
		return
	if mbe.button_index == MOUSE_BUTTON_LEFT:
		_try_take_prize_from_slot(player_index, slot_index)
		return
	if mbe.button_index != MOUSE_BUTTON_RIGHT:
		return
	_show_prize_cards(player_index, title)



func _load_replay_turn(turn_number: int) -> void:
	var replay_variant: Variant = _battle_replay_controller.call(
		"load_turn",
		_battle_replay_snapshot_loader,
		_battle_replay_state_restorer,
		_replay_match_dir,
		turn_number,
		_view_player
	)
	if not (replay_variant is Dictionary):
		return
	var replay: Dictionary = replay_variant
	_replay_loaded_raw_snapshot = (replay.get("loaded_raw_snapshot", {}) as Dictionary).duplicate(true)
	_replay_loaded_view_snapshot = (replay.get("loaded_view_snapshot", {}) as Dictionary).duplicate(true)
	_view_player = int(replay.get("view_player_index", _view_player))
	var restored_game_state: Variant = replay.get("restored_game_state", null)
	if restored_game_state != null:
		_ensure_game_state_machine()
		_gsm.game_state = restored_game_state
	_refresh_replay_controls()
	_refresh_ui()



func _bind_discard_open_control(control: Control, player_index: int, title: String) -> void:
	if control == null:
		return
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	var callback := Callable(self, "_on_discard_open_control_input").bind(player_index, title)
	if not control.gui_input.is_connected(callback):
		control.gui_input.connect(callback)



func _portrait_action_descriptors() -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	_append_portrait_button_action(actions, _btn_opponent_hand, "查看对手手牌")
	_append_portrait_button_action(actions, _btn_attack_vfx_preview, "攻击特效预览")
	_append_portrait_button_action(actions, _btn_ai_advice, "AI建议")
	_append_portrait_button_action(actions, _btn_battle_discuss_ai, "AI探讨")
	_append_portrait_button_action(actions, _btn_zeus_help, "宙斯帮我")
	_append_portrait_button_action(actions, _btn_replay_prev_turn, "上一回合")
	_append_portrait_button_action(actions, _btn_replay_next_turn, "下一回合")
	_append_portrait_button_action(actions, _btn_replay_continue, "从此处继续")
	_append_portrait_button_action(actions, _btn_replay_back_to_list, "返回复盘列表")
	_append_portrait_button_action(actions, _btn_back, "退出游戏")
	return actions
