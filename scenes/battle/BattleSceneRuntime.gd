## BattleScene lifecycle and layout runtime.
extends "res://scenes/battle/runtime/BattleSceneBrowserPointerRuntime.gd"

var _dialog_card_touch_bridge_active_card: BattleCardView = null
var _dialog_card_touch_bridge_touch_index: int = -1


func _notification(what: int) -> void:
	if what not in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		return
	if not is_inside_tree() or not is_node_ready() or _gsm == null or _runtime_resume_recovery_scheduled:
		return
	_runtime_resume_recovery_scheduled = true
	call_deferred("_recover_battle_runtime_after_resume", str(what))


func _recover_battle_runtime_after_resume(reason: String = "resume") -> void:
	_runtime_resume_recovery_scheduled = false
	if not is_inside_tree() or _gsm == null or _battle_mode != "live":
		return
	_cancel_transient_platform_input("battle_runtime_resume")
	_runtime_log("battle_runtime_resume", "notification=%s %s" % [reason, _state_snapshot()])
	if _battle_visual_input_blocked:
		_ai_watchdog_force_finish_visual_sequence()
	if _pending_prize_animating:
		_ai_watchdog_force_finish_prize_animation()
	if _draw_reveal_active:
		_ai_watchdog_force_finish_draw_reveal()
	if _has_pending_coin_animation():
		_on_coin_animation_finished()
	if _is_ai_action_pause_active():
		_on_ai_action_pause_finished()
	if GameManager.current_mode in [GameManager.GameMode.VS_AI, GameManager.GameMode.VS_AUTHOR_STRATEGY_AI]:
		_ai_watchdog_reconcile_authoritative_decision()
	_refresh_ui()
	_notify_ai_watchdog_activity("runtime_resume")
	_maybe_run_ai()


func _ready() -> void:
	set_process(false)
	# Consume and snapshot the launch before any live setup helper can clear
	# transient battle identity. Recorded labels are scene-local below.
	var replay_launch: Dictionary = GameManager.consume_battle_replay_launch()
	if not replay_launch.is_empty():
		_replay_previous_selected_deck_ids.clear()
		for deck_id_variant: Variant in replay_launch.get("_return_selected_deck_ids", []):
			_replay_previous_selected_deck_ids.append(int(deck_id_variant))
		_replay_previous_player_display_names.clear()
		for name_variant: Variant in replay_launch.get("_return_player_display_names", []):
			_replay_previous_player_display_names.append(str(name_variant))
		_replay_global_display_context_captured = true
	var runtime_profile: UiRuntimeProfile = (
		GameManager.get_ui_runtime_profile()
		if GameManager != null and GameManager.has_method("get_ui_runtime_profile")
		else null
	)
	_configure_battle_pointer_runtime(runtime_profile)
	if _ios_web_hud_touch_adapter != null:
		_ios_web_hud_touch_adapter.configure(runtime_profile)
	_ensure_modal_pointer_drain_shield()
	_init_battle_runtime_log()
	_setup_ui_interaction_watchdog()
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
	_btn_replay_play_pause.pressed.connect(_on_replay_play_pause_pressed)
	_opt_replay_speed.item_selected.connect(_on_replay_speed_selected)
	_configure_replay_player_controls()
	_setup_battle_scene_context()
	_btn_back.pressed.connect(_on_back_pressed)
	_btn_battle_layout.pressed.connect(_on_battle_layout_pressed)
	_btn_battle_more.pressed.connect(_on_battle_more_pressed)
	_dialog_confirm.gui_input.connect(_on_dialog_confirm_input)
	_dialog_cancel.gui_input.connect(_on_dialog_cancel_input)
	_dialog_confirm.button_down.connect(_on_dialog_confirm_button_down)
	_dialog_cancel.button_down.connect(_on_dialog_cancel_button_down)
	_dialog_confirm.pressed.connect(_on_dialog_confirm)
	_dialog_cancel.pressed.connect(_on_dialog_cancel)
	_handover_btn.pressed.connect(_on_handover_confirmed)
	_handover_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_handover_panel.z_index = HANDOVER_OVERLAY_Z_INDEX

	_dialog_overlay.visible = false
	_dialog_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog_overlay.z_index = DIALOG_OVERLAY_Z_INDEX
	_register_ios_web_hud_touch_root(_dialog_overlay)
	_register_ios_web_hud_touch_root(_handover_panel)
	_set_handover_panel_visible(false, "ready_init")
	_coin_overlay.visible = false
	_register_ios_web_hud_touch_root(_coin_overlay)
	_detail_overlay.visible = false
	_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_overlay.z_index = DETAIL_OVERLAY_Z_INDEX
	_register_ios_web_hud_touch_root(_detail_overlay)
	_discard_overlay.visible = false
	_discard_overlay.z_index = DISCARD_OVERLAY_Z_INDEX
	_register_ios_web_hud_touch_root(_discard_overlay)
	_review_overlay.visible = false
	_register_ios_web_hud_touch_root(_review_overlay)
	_hand_title.visible = false
	_left_panel.visible = false
	_right_panel.visible = false
	_btn_opponent_hand.visible = false
	_btn_replay_prev_turn.visible = false
	_btn_replay_next_turn.visible = false
	_btn_replay_continue.visible = false
	_btn_replay_back_to_list.visible = false
	_btn_replay_play_pause.visible = false
	_opt_replay_speed.visible = false
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
	_coin_animator.z_index = COIN_FLIP_OVERLAY_Z_INDEX
	_coin_animator.visible = false
	add_child(_coin_animator)
	_coin_animator.animation_finished.connect(_on_coin_animation_finished)

	# Popups
	_coin_ok_btn.pressed.connect(func() -> void:
		_coin_overlay.visible = false
	)
	var detail_close_pressed_callable := Callable(self, "_on_detail_close_pressed")
	if not _detail_close_btn.pressed.is_connected(detail_close_pressed_callable):
		_detail_close_btn.pressed.connect(detail_close_pressed_callable)
	var detail_close_down_callable := Callable(self, "_on_detail_close_button_down")
	if not _detail_close_btn.button_down.is_connected(detail_close_down_callable):
		_detail_close_btn.button_down.connect(detail_close_down_callable)
	var discard_close_pressed_callable := Callable(self, "_on_discard_close_pressed")
	if not _discard_close_btn.pressed.is_connected(discard_close_pressed_callable):
		_discard_close_btn.pressed.connect(discard_close_pressed_callable)
	# Android browsers and a few devices can lose the release event while the
	# card gallery is cancelling a drag. Closing on button_down gives the modal
	# a reliable touch exit. The pointer-drain shield keeps the remaining physical
	# sequence from reaching the board after the overlay disappears.
	var discard_close_down_callable := Callable(self, "_on_discard_close_button_down")
	if not _discard_close_btn.button_down.is_connected(discard_close_down_callable):
		_discard_close_btn.button_down.connect(discard_close_down_callable)
	var discard_overlay_input_callable := Callable(self, "_on_discard_overlay_gui_input")
	if not _discard_overlay.gui_input.is_connected(discard_overlay_input_callable):
		_discard_overlay.gui_input.connect(discard_overlay_input_callable)
	if _discard_list != null and not _discard_list.item_clicked.is_connected(_on_discard_list_item_clicked):
		_discard_list.item_clicked.connect(_on_discard_list_item_clicked)
	_review_close_btn.pressed.connect(func() -> void:
		_review_overlay.visible = false
	)
	_review_regenerate_btn.pressed.connect(_on_review_regenerate_pressed)
	_setup_battle_advice_ui()
	_register_existing_ios_web_hud_button_surfaces()
	var stadium_sections := $MainArea/CenterField/FieldArea/StadiumBar/StadiumSections as HBoxContainer
	if stadium_sections != null:
		stadium_sections.move_child(_stadium_center_section, 0)
		stadium_sections.move_child(_lost_zone_section, 1)
	_refresh_replay_controls()
	if not replay_launch.is_empty():
		_apply_replay_launch(replay_launch)

	# Discard pile interactions
	_bind_discard_hud_openers()
	_bind_discard_preview_open_control(_opp_discard_preview, "opponent", "对方弃牌区")
	_bind_discard_preview_open_control(_my_discard_preview, "my", "己方弃牌区")
	_bind_lost_zone_hud_openers()
	if _opp_discard_preview != null:
		_opp_discard_preview.right_clicked.connect(func(ci: CardInstance, cd: CardData) -> void:
			if ci != null:
				_show_card_detail_for_instance(ci)
				return
			if cd != null:
				_show_card_detail(cd)
		)
	if _my_discard_preview != null:
		_my_discard_preview.right_clicked.connect(func(ci: CardInstance, cd: CardData) -> void:
			if ci != null:
				_show_card_detail_for_instance(ci)
				return
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
	_cancel_transient_platform_input("scene_exit")
	if _ui_interaction_sessions != null:
		_ui_interaction_sessions.invalidate("scene_exit")
	if _ui_interaction_watchdog != null:
		_ui_interaction_watchdog.release()
	if _deck_training_controller != null:
		_deck_training_controller.release()
		_deck_training_controller = null
	_release_game_state_machine()
	_release_battle_runtime_resources()
	BattleMusicManager.stop_battle_music()
	GameManager.apply_non_battle_orientation()
	_restore_replay_global_display_context()


func _release_battle_runtime_resources() -> void:
	_responsive_layout_stabilization_frames_remaining = 0
	set_process(false)
	_cancel_runtime_http_requests()
	_stop_all_deck_shuffle_effects()
	_stop_battle_discussion_flash()
	_disconnect_llm_strategy_signals_from_current_ai()
	_disconnect_battle_async_service_signals()
	if _battle_visual_sequence_controller != null:
		_battle_visual_sequence_controller.call("clear", "scene_exit")
	if _battle_action_intent_controller != null:
		_battle_action_intent_controller.call("release")
	_release_runtime_timer_nodes()
	_release_runtime_tweens()
	_release_runtime_dynamic_nodes()
	_clear_runtime_card_views()
	_clear_runtime_state_payloads()
	_release_runtime_cache_heavy_refs()


func _cancel_runtime_http_requests() -> void:
	for child: Node in find_children("*", "HTTPRequest", true, false):
		var request := child as HTTPRequest
		if request == null:
			continue
		request.cancel_request()
		_queue_free_runtime_node(request)


func _disconnect_llm_strategy_signals_from_current_ai() -> void:
	if not (_ai_opponent is Object):
		return
	var strategy_variant: Variant = (_ai_opponent as Object).get("_deck_strategy")
	if not (strategy_variant is Object):
		return
	var strategy := strategy_variant as Object
	_disconnect_runtime_signal(strategy, "llm_thinking_started", Callable(self, "_on_llm_thinking_started"))
	_disconnect_runtime_signal(strategy, "llm_thinking_finished", Callable(self, "_on_llm_thinking_finished"))
	_disconnect_runtime_signal(strategy, "llm_thinking_failed", Callable(self, "_on_llm_thinking_failed"))


func _disconnect_battle_async_service_signals() -> void:
	_disconnect_runtime_signal(_battle_review_service, "status_changed", Callable(self, "_on_battle_review_status_changed"))
	_disconnect_runtime_signal(_battle_review_service, "review_completed", Callable(self, "_on_battle_review_completed"))
	_disconnect_runtime_signal(_battle_advice_service, "status_changed", Callable(self, "_on_battle_advice_status_changed"))
	_disconnect_runtime_signal(_battle_advice_service, "advice_completed", Callable(self, "_on_battle_advice_completed"))
	_disconnect_runtime_signal(_match_end_quick_review_service, "status_changed", Callable(self, "_on_match_end_quick_review_status_changed"))
	_disconnect_runtime_signal(_match_end_quick_review_service, "quick_review_completed", Callable(self, "_on_match_end_quick_review_completed"))
	_battle_review_service = null
	_battle_advice_service = null
	_match_end_quick_review_service = null


func _disconnect_runtime_signal(emitter: Object, signal_name: String, callback: Callable) -> void:
	if emitter == null or not is_instance_valid(emitter):
		return
	if not emitter.has_signal(signal_name):
		return
	if emitter.is_connected(signal_name, callback):
		emitter.disconnect(signal_name, callback)


func _release_runtime_timer_nodes() -> void:
	if _slot_touch_long_press_timer != null and is_instance_valid(_slot_touch_long_press_timer):
		_slot_touch_long_press_timer.stop()
		_queue_free_runtime_node(_slot_touch_long_press_timer)
	_slot_touch_long_press_timer = null
	_handover_attack_vfx_delay_token += 1
	_handover_attack_vfx_delay_active = false
	_handover_attack_vfx_delay_timer = null
	_draw_reveal_resume_timer = null
	_ai_action_pause_timer = null
	_ai_llm_waiting = false
	_ai_llm_turn_requested = -1
	_ai_llm_wait_anim_token += 1
	_author_policy_polling = false
	_author_policy_wait_generation += 1


func _release_runtime_tweens() -> void:
	_kill_runtime_tween(_detail_reveal_tween)
	_detail_reveal_tween = null
	_kill_runtime_tween(_my_deck_shuffle_tween)
	_my_deck_shuffle_tween = null
	_kill_runtime_tween(_opp_deck_shuffle_tween)
	_opp_deck_shuffle_tween = null


func _kill_runtime_tween(tween_variant: Variant) -> void:
	if not (tween_variant is Tween):
		return
	var tween := tween_variant as Tween
	if tween == null or not is_instance_valid(tween):
		return
	tween.kill()


func _release_runtime_dynamic_nodes() -> void:
	_queue_free_runtime_node(_battle_discussion_dialog)
	_battle_discussion_dialog = null
	_queue_free_runtime_node(_portrait_actions_popup)
	_portrait_actions_popup = null
	_queue_free_runtime_node(_draw_reveal_overlay)
	_draw_reveal_overlay = null
	_queue_free_runtime_node(_attack_vfx_overlay)
	_attack_vfx_overlay = null
	_queue_free_runtime_node(_modal_pointer_drain_shield)
	_modal_pointer_drain_shield = null
	_queue_free_runtime_node(_ready_vfx_overlay)
	_ready_vfx_overlay = null
	_queue_free_runtime_node(_field_interaction_overlay)
	_field_interaction_overlay = null
	_queue_free_runtime_node(_field_swap_overlay)
	_field_swap_overlay = null
	_queue_free_runtime_node(_stadium_card_overlay)
	_stadium_card_overlay = null
	_stadium_card_view = null
	_queue_free_runtime_node(_match_end_overlay)
	_match_end_overlay = null
	_queue_free_runtime_node(_battle_advice_panel)
	_battle_advice_panel = null
	_battle_advice_panel_title = null
	_battle_advice_panel_toggle_btn = null
	_battle_advice_panel_content = null
	_queue_free_runtime_node(_coin_animator)
	_coin_animator = null


func _queue_free_runtime_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.is_queued_for_deletion():
		return
	node.queue_free()


func _clear_runtime_card_views() -> void:
	for card_view: BattleCardView in _draw_reveal_card_views:
		_queue_free_runtime_node(card_view)
	_draw_reveal_card_views.clear()
	_slot_card_views.clear()
	_opp_prize_slots.clear()
	_my_prize_slots.clear()
	_detail_card_view = null
	_detail_hand_action_card = null
	_opp_deck_preview = null
	_my_deck_preview = null
	_opp_discard_preview = null
	_my_discard_preview = null


func _clear_runtime_state_payloads() -> void:
	_selected_hand_card = null
	_pending_choice = ""
	_pending_effect_card = null
	_pending_effect_steps.clear()
	_pending_effect_step_index = -1
	_pending_effect_context.clear()
	_pending_effect_kind = ""
	_pending_effect_player_index = -1
	_pending_effect_slot = null
	_pending_effect_attack_data.clear()
	_pending_effect_attack_effects.clear()
	_dialog_multi_selected_indices.clear()
	_dialog_data.clear()
	_dialog_items_data.clear()
	_dialog_card_selected_indices.clear()
	_dialog_assignment_assignments.clear()
	_discard_card_page = 0
	_discard_card_page_size = 0
	_field_interaction_data.clear()
	_field_interaction_slot_index_by_id.clear()
	_field_interaction_selected_indices.clear()
	_field_interaction_assignment_entries.clear()
	_pending_handover_action = Callable()
	_pending_attack_vfx_completion_action = Callable()
	_pending_attack_vfx_completion_reason = ""
	_draw_reveal_queue.clear()
	_draw_reveal_active = false
	_draw_reveal_waiting_for_confirm = false
	_draw_reveal_auto_continue_pending = false
	_draw_reveal_pending_hand_refresh = false
	_draw_reveal_current_action = null
	_draw_reveal_allow_hand_refresh_during_fly = false
	_draw_reveal_visible_instance_ids.clear()
	_ready_vfx_seen_keys.clear()
	_ready_vfx_trigger_source_player_index = -1
	_ready_vfx_trigger_action_kind = ""
	_pending_prize_player_index = -1
	_pending_prize_remaining = 0
	_pending_prize_animating = false
	_ai_opponent = null
	_close_author_public_replay("runtime_state_cleared")
	_close_author_developer_trace("runtime_state_cleared")
	_close_author_match_evidence("runtime_state_cleared")
	if _author_player_owner != null and _author_player_owner.has_method("close_match"):
		_author_player_owner.close_match()
	_author_player_owner = null
	_author_runtime_start_error_code = ""
	_author_strategy_author_name = ""
	_author_strategy_deck_label = ""
	_ai_running = false
	_ai_step_scheduled = false
	_ai_followup_requested = false
	_ai_turn_marker = ""
	_ai_actions_this_turn = 0
	_latest_opponent_action_text = ""
	_latest_opponent_action_turn_number = -1
	_coin_flip_queue.clear()
	_coin_flip_label_queue.clear()
	_coin_animating = false
	_coin_animation_advance_scheduled = false
	_coin_animation_resume_effect_step = false
	_opening_first_player_flip_pending = false
	_battle_recording_started = false
	_battle_recording_context_captured = false
	_turn_start_snapshot_recorded_keys.clear()
	_battle_review_last_review.clear()
	_battle_review_busy = false
	_battle_review_progress_text = ""
	_match_end_stats.clear()
	_match_end_quick_review_result.clear()
	_match_end_quick_review_busy = false
	_match_end_quick_review_progress_text = ""
	_match_end_quick_review_requested = false
	_match_end_tournament_return_pending = false
	_battle_advice_last_result.clear()
	_battle_advice_busy = false
	_battle_advice_progress_text = ""
	_battle_advice_initial_snapshot.clear()
	if _log_list != null and is_instance_valid(_log_list):
		_log_list.clear()


func _release_runtime_cache_heavy_refs() -> void:
	_player_card_back_texture = null
	_opponent_card_back_texture = null
	_vstar_hud_texture_indices_by_player.clear()
	_deck_shuffle_counts.clear()
	_deck_preview_base_positions.clear()
	_field_swap_last_snapshot.clear()
	_battle_recorder = null
	_battle_attack_vfx_controller = null
	_battle_ready_vfx_controller = null
	_battle_stadium_backdrop_coordinator = null



func _process(delta: float) -> void:
	var keep_processing := false
	if _is_review_mode() and _replay_is_playing:
		keep_processing = true
		_advance_replay_playback(delta)
	if not is_inside_tree():
		set_process(false)
		return
	if _responsive_layout_stabilization_frames_remaining > 0:
		keep_processing = true
		_apply_responsive_layout()
		_responsive_layout_stabilization_frames_remaining -= 1
	set_process(keep_processing or (_is_review_mode() and _replay_is_playing))



func _input(event: InputEvent) -> void:
	var pointer_observation := _observe_battle_pointer_event(event)
	if _update_modal_pointer_drain(event, pointer_observation):
		var drain_viewport := get_viewport()
		if drain_viewport != null:
			drain_viewport.set_input_as_handled()
		return
	var direct_hud_touch_route_active := (
		_ios_web_hud_touch_adapter != null
		and _ios_web_hud_touch_adapter.is_enabled()
	)
	if direct_hud_touch_route_active:
		# Normalize raw touch first so its later compatibility-mouse echo remains
		# part of the same sequence, then let the direct HUD adapter own the event.
		if _route_web_battle_pointer_event(event, pointer_observation):
			return
		if _try_handle_ios_web_hud_touch_input(event):
			var ios_hud_viewport := get_viewport()
			if ios_hud_viewport != null:
				ios_hud_viewport.set_input_as_handled()
			return
	if _try_close_card_detail_from_cancel(event):
		var detail_cancel_viewport := get_viewport()
		if detail_cancel_viewport != null:
			detail_cancel_viewport.set_input_as_handled()
		return
	# Card detail is the visual top layer. Leave pointer events unhandled here so
	# Godot can deliver them to its Close button, but never route them into the
	# full-library search or card gallery that remains visible underneath.
	if _detail_overlay != null and _detail_overlay.visible:
		return
	if _try_handle_battle_hud_touch_input(event):
		var hud_touch_viewport := get_viewport()
		if hud_touch_viewport != null:
			hud_touch_viewport.set_input_as_handled()
		return
	if not direct_hud_touch_route_active and _route_web_battle_pointer_event(event, pointer_observation):
		return
	if _try_close_discard_collection_from_cancel(event):
		var discard_cancel_viewport := get_viewport()
		if discard_cancel_viewport != null:
			discard_cancel_viewport.set_input_as_handled()
		return
	if _try_handle_library_search_board_touch_input(event):
		var library_touch_viewport := get_viewport()
		if library_touch_viewport != null:
			library_touch_viewport.set_input_as_handled()
		return
	if _try_handle_web_pointer_surface_input(event, pointer_observation):
		var pointer_surface_viewport := get_viewport()
		if pointer_surface_viewport != null:
			pointer_surface_viewport.set_input_as_handled()
		return
	if _try_handle_dialog_card_gallery_touch_input(event):
		var dialog_touch_viewport := get_viewport()
		if dialog_touch_viewport != null:
			dialog_touch_viewport.set_input_as_handled()
		return
	if _try_handle_ios_web_hand_card_touch_input(event):
		var hand_card_touch_viewport := get_viewport()
		if hand_card_touch_viewport != null:
			hand_card_touch_viewport.set_input_as_handled()
		return
	if _card_gallery_drag_active and _handle_card_gallery_drag_scroll_input(event, _card_gallery_drag_active_scroll, "battle_scene_input"):
		var gallery_drag_viewport := get_viewport()
		if gallery_drag_viewport != null:
			gallery_drag_viewport.set_input_as_handled()
		return
	var route_hand_drag_event := _should_route_hand_drag_input_event(event)
	if route_hand_drag_event:
		_debug_hand_drag_scroll_event("battle_scene_input", event, _hand_scroll if _hand_scroll != null else find_child("HandScroll", true, false) as ScrollContainer)
	if route_hand_drag_event and _handle_hand_drag_scroll_input(event, "battle_scene_input"):
		var hand_drag_viewport := get_viewport()
		if hand_drag_viewport != null:
			hand_drag_viewport.set_input_as_handled()
		return
	if _try_handle_portrait_bench_play_input(event):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


func _try_handle_battle_hud_touch_input(event: InputEvent) -> bool:
	var pointer_position := Vector2(-1.0, -1.0)
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return false
		pointer_position = touch.position
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if (
			not mouse_button.pressed
			or mouse_button.button_index != MOUSE_BUTTON_LEFT
		):
			return false
		pointer_position = (
			mouse_button.global_position
			if mouse_button.global_position != Vector2.ZERO
			else mouse_button.position
		)
	else:
		return false
	if _is_board_modal_overlay_visible():
		return false
	for descriptor: Dictionary in [
		{
			"control": find_child("OppDiscardHudPanel", true, false),
			"side": "opponent",
			"title": "对方弃牌区",
		},
		{
			"control": find_child("MyDiscardHudPanel", true, false),
			"side": "my",
			"title": "己方弃牌区",
		},
	]:
		var discard_control := descriptor.get("control", null) as Control
		if not _battle_hud_control_contains_touch(discard_control, pointer_position):
			continue
		_on_discard_open_control_input(
			event,
			str(descriptor.get("side", "my")),
			str(descriptor.get("title", "弃牌区"))
		)
		return _discard_overlay != null and _discard_overlay.visible
	for descriptor: Dictionary in [
		{
			"control": find_child("InfoEnemyLost", true, false),
			"enemy": true,
		},
		{
			"control": find_child("InfoMyLost", true, false),
			"enemy": false,
		},
	]:
		var lost_control := descriptor.get("control", null) as Control
		if not _battle_hud_control_contains_touch(lost_control, pointer_position):
			continue
		_on_lost_zone_open_control_input(event, bool(descriptor.get("enemy", false)))
		return _discard_overlay != null and _discard_overlay.visible
	return false


func _battle_hud_control_contains_touch(control: Control, screen_position: Vector2) -> bool:
	if not PointerGeometryScript.control_is_pointer_visible(control):
		return false
	# _input receives Godot's logical viewport coordinate. With canvas_items
	# stretch, get_global_transform_with_canvas() includes the physical-screen
	# scale and therefore belongs to a different coordinate space. Resolve the
	# HUD rectangle in battle-local logical coordinates, matching the established
	# portrait Bench hit-test path.
	var battle_rect := _control_rect_in_battle_local(control)
	if (
		battle_rect.size.x <= 0.0
		or battle_rect.size.y <= 0.0
	):
		return false
	if battle_rect.has_point(screen_position):
		return true
	# Some forced-orientation builds keep a landscape logical viewport and rotate
	# the battle root. Their touch position must be converted once; Android builds
	# that already report post-rotation logical coordinates are handled above.
	if _rotated_portrait_canvas_active:
		return battle_rect.has_point(_screen_position_to_battle_local(screen_position))
	return false


func _ensure_modal_pointer_drain_shield() -> void:
	if (
		_modal_pointer_drain_shield != null
		and is_instance_valid(_modal_pointer_drain_shield)
	):
		return
	var shield := Control.new()
	shield.name = "ModalPointerDrainShield"
	shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield.focus_mode = Control.FOCUS_NONE
	shield.z_as_relative = false
	shield.z_index = MODAL_POINTER_DRAIN_SHIELD_Z_INDEX
	shield.visible = false
	shield.gui_input.connect(_on_modal_pointer_drain_shield_input)
	add_child(shield)
	_modal_pointer_drain_shield = shield


func _begin_modal_pointer_drain(intent: String) -> bool:
	var resolved_intent := intent.strip_edges()
	if resolved_intent == "":
		resolved_intent = "modal_commit"
	if not _claim_current_modal_pointer_sequence(resolved_intent):
		return false
	return _show_modal_pointer_drain_shield(resolved_intent)


func _begin_modal_pointer_drain_for_event(
	event: InputEvent,
	intent: String
) -> bool:
	var resolved_intent := intent.strip_edges()
	if resolved_intent == "":
		resolved_intent = "modal_commit"
	if not _claim_modal_pointer_event(event, resolved_intent):
		return false
	return _show_modal_pointer_drain_shield(resolved_intent)


func _show_modal_pointer_drain_shield(resolved_intent: String) -> bool:
	_ensure_modal_pointer_drain_shield()
	if _modal_pointer_drain_shield == null:
		return false
	_modal_pointer_drain_release_pending = false
	_modal_pointer_drain_intent = resolved_intent
	_modal_pointer_drain_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_pointer_drain_shield.visible = true
	_modal_pointer_drain_shield.z_as_relative = false
	_modal_pointer_drain_shield.z_index = MODAL_POINTER_DRAIN_SHIELD_Z_INDEX
	if _modal_pointer_drain_shield.get_parent() == self:
		move_child(_modal_pointer_drain_shield, get_child_count() - 1)
	_runtime_log("modal_pointer_drain_started", "intent=%s" % resolved_intent)
	return true


func _end_modal_pointer_drain(reason: String = "complete") -> void:
	_modal_pointer_drain_release_pending = false
	if (
		_modal_pointer_drain_shield == null
		or not is_instance_valid(_modal_pointer_drain_shield)
	):
		_modal_pointer_drain_intent = ""
		return
	var finished_intent := _modal_pointer_drain_intent
	_modal_pointer_drain_shield.visible = false
	_modal_pointer_drain_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_pointer_drain_intent = ""
	_runtime_log(
		"modal_pointer_drain_finished",
		"intent=%s reason=%s" % [finished_intent, reason]
	)


func _update_modal_pointer_drain(
	event: InputEvent,
	observation: Dictionary
) -> bool:
	if (
		_modal_pointer_drain_shield == null
		or not is_instance_valid(_modal_pointer_drain_shield)
		or not _modal_pointer_drain_shield.visible
	):
		return false
	if not (
		event is InputEventScreenTouch
		or event is InputEventScreenDrag
		or event is InputEventMouseButton
		or event is InputEventMouseMotion
	):
		return false
	var sequence_variant: Variant = observation.get("sequence", null)
	var sequence := sequence_variant as Object if sequence_variant is Object else null
	var owned_by_modal := (
		sequence != null
		and str(sequence.get("owner")) == "battle_modal"
		and str(sequence.get("consumed_intent")) != ""
	)
	var is_press := false
	var is_release := false
	if event is InputEventScreenTouch:
		is_press = (event as InputEventScreenTouch).pressed
		is_release = not is_press
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return false
		is_press = mouse_button.pressed
		is_release = not is_press
	if is_press and not owned_by_modal:
		# A newly observed physical press is independent. Remove the drain shield
		# synchronously, before Godot performs GUI hit testing for this event.
		_end_modal_pointer_drain("new_pointer_sequence")
		return false
	if not owned_by_modal:
		# Keep swallowing orphan tails while the barrier is armed. They cannot be
		# proven to belong to a new gesture because no new press was observed.
		return true
	if is_release and event is InputEventMouseButton:
		var sequence_state := str(sequence.get("state"))
		if sequence_state != "active" and not _modal_pointer_drain_release_pending:
			# Defer removal so this release is still delivered to the shield, not
			# to a Control that never received its matching press.
			_modal_pointer_drain_release_pending = true
			call_deferred("_end_modal_pointer_drain", "compatibility_mouse_tail_complete")
	return true


func _on_modal_pointer_drain_shield_input(_event: InputEvent) -> void:
	if _modal_pointer_drain_shield == null or not _modal_pointer_drain_shield.visible:
		return
	_modal_pointer_drain_shield.accept_event()
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _route_web_battle_pointer_event(
	event: InputEvent,
	pointer_observation: Dictionary = {}
) -> bool:
	var runtime_profile: UiRuntimeProfile = GameManager.get_ui_runtime_profile() if GameManager != null and GameManager.has_method("get_ui_runtime_profile") else null
	if not WebUiFeatureGateScript.web_input_adapter_v2_enabled(runtime_profile):
		return false
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion):
		return false
	var normalized := pointer_observation
	if normalized.is_empty() and _battle_pointer_input_router != null:
		normalized = _battle_pointer_input_router.observe(event)
	var should_swallow := bool(normalized.get("synthetic_echo", false))
	# After blur/pointercancel, an orphan touch release belongs to the cancelled
	# sequence and must not reach a newly opened modal underneath it.
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and not bool(normalized.get("deliver", false)):
		should_swallow = true
	if should_swallow:
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
	return should_swallow


func _cancel_transient_platform_input(reason: String = "platform_cancel") -> void:
	_end_modal_pointer_drain(reason)
	if _battle_pointer_input_router != null:
		_battle_pointer_input_router.cancel_all(reason)
	if _web_battle_input_adapter != null:
		_web_battle_input_adapter.cancel_all(reason)
	if _battle_pointer_surface_controller != null:
		_battle_pointer_surface_controller.cancel_all(reason)
	if _ios_web_hud_touch_adapter != null:
		_ios_web_hud_touch_adapter.cancel_all()
	_clear_dialog_card_touch_bridge()
	_clear_ios_web_hand_touch_bridge()
	_prize_touch_press_contexts.clear()
	if _slot_touch_long_press_timer != null:
		_slot_touch_long_press_timer.stop()
	_cancel_slot_touch_long_press(true)
	_cancel_slot_mouse_action_press(true)
	if _battle_drag_scroll_coordinator != null and _battle_drag_scroll_coordinator.has_method("clear_transient_input_capture"):
		_battle_drag_scroll_coordinator.call("clear_transient_input_capture", reason)


func _on_browser_viewport_changed(_payload: Dictionary = {}) -> void:
	_on_viewport_size_changed()


func _setup_ui_interaction_watchdog() -> void:
	if _ui_interaction_watchdog != null and is_instance_valid(_ui_interaction_watchdog):
		return
	_ui_interaction_watchdog = UiInteractionWatchdogScript.new()
	_ui_interaction_watchdog.name = "UiInteractionWatchdog"
	add_child(_ui_interaction_watchdog)
	_ui_interaction_watchdog.setup(_ui_interaction_sessions, Callable(self, "_on_ui_interaction_watchdog_recovery"))


func _mark_ui_interaction_progress(source: String = "") -> bool:
	if _ui_interaction_sessions == null:
		return false
	var session := _ui_interaction_sessions.current_session()
	if (
		session == null
		or not session.is_active()
		or session.owner != "effect_human"
		or session.interaction_type != "effect_step"
	):
		return false
	var marked := session.mark_progress(-1, session.generation)
	if marked:
		_runtime_log(
			"ui_interaction_progress",
			"source=%s session=%s generation=%d" % [
				source,
				session.session_id,
				session.generation,
			]
		)
	return marked


func _on_ui_interaction_watchdog_recovery(session: UiInteractionSession) -> void:
	if session == null:
		return
	_runtime_log("ui_interaction_watchdog", JSON.stringify(session.snapshot()))
	match session.completion_policy:
		UiInteractionSessionScript.POLICY_SAFE_COMPLETE_PRESENTATION:
			if session.interaction_type == "draw_reveal" and _battle_draw_reveal_controller != null:
				_battle_draw_reveal_controller.call("_finish_all_reveals", self)
		UiInteractionSessionScript.POLICY_REBUILD_REQUIRED_HUMAN_PROMPT:
			if session.interaction_type == "effect_step" and _battle_effect_interaction_controller != null:
				_battle_effect_interaction_controller.call("renew_effect_interaction_session", self)
				_battle_effect_interaction_controller.call("show_next_effect_interaction_step", self)
		UiInteractionSessionScript.POLICY_AI_FALLBACK:
			if session.interaction_type == "effect_step":
				_reset_effect_interaction()
				var reconciled_authoritative := _ai_watchdog_reconcile_authoritative_decision()
				_refresh_ui()
				if not reconciled_authoritative:
					_maybe_run_ai()


func _try_close_discard_collection_from_cancel(event: InputEvent) -> bool:
	if _discard_overlay == null or not _discard_overlay.visible:
		return false
	# A card detail opened from the collection owns the top layer. Do not close
	# the collection underneath it when the user presses Android Back/Escape.
	if _detail_overlay != null and _detail_overlay.visible:
		return false
	if not event.is_action_pressed("ui_cancel"):
		return false
	_close_discard_collection_viewer("ui_cancel")
	return true


func _try_close_card_detail_from_cancel(event: InputEvent) -> bool:
	if _detail_overlay == null or not _detail_overlay.visible:
		return false
	if not event.is_action_pressed("ui_cancel"):
		return false
	_hide_card_detail()
	return true


func _on_discard_overlay_gui_input(event: InputEvent) -> void:
	if _discard_overlay == null or not _discard_overlay.visible:
		return
	if _consume_modal_hud_input_if_needed(event, "discard_collection_backdrop"):
		return
	var pointer_position := Vector2.ZERO
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return
		pointer_position = touch.position
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if not mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		pointer_position = mouse_button.position
	else:
		return
	var discard_box := get_node_or_null("DiscardOverlay/DiscardCenter/DiscardBox") as Control
	if discard_box != null and discard_box.get_global_rect().has_point(pointer_position):
		return
	_begin_modal_pointer_drain("discard_backdrop_close")
	_close_discard_collection_viewer("backdrop")
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _close_discard_collection_viewer(reason: String = "close") -> void:
	if _discard_overlay == null or not _discard_overlay.visible:
		return
	_cancel_card_gallery_drag_scroll("discard_collection_%s" % reason)
	_discard_overlay.visible = false
	_discard_collection_current_kind = ""
	_discard_collection_current_player_index = -1
	_discard_collection_current_title = ""
	_refresh_end_turn_hud_button_state()
	# Opening the read-only collection now pauses the AI. Resume only after the
	# modal has fully left the input stack so the next AI animation cannot cover
	# or steal the close interaction.
	if is_inside_tree():
		call_deferred("_maybe_run_ai")


func _on_detail_close_button_down() -> void:
	_begin_modal_pointer_drain("detail_close")
	_hide_card_detail()


func _on_detail_close_pressed() -> void:
	_hide_card_detail()


func _on_discard_close_button_down() -> void:
	_begin_modal_pointer_drain("discard_close")
	_close_discard_collection_viewer("close_button_down")


func _on_discard_close_pressed() -> void:
	_close_discard_collection_viewer("close_button")


func _try_handle_library_search_board_touch_input(event: InputEvent) -> bool:
	if _battle_dialog_controller == null:
		return false
	return bool(_battle_dialog_controller.call("try_handle_library_search_board_touch_input", self, event))


func _try_handle_dialog_card_gallery_touch_input(event: InputEvent) -> bool:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return false
	if not _is_dialog_card_gallery_touch_bridge_active():
		_clear_dialog_card_touch_bridge()
		return false
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var pressed_card := _dialog_card_gallery_card_at_screen_position(touch.position)
			if pressed_card == null:
				_clear_dialog_card_touch_bridge()
				return false
			_dialog_card_touch_bridge_active_card = pressed_card
			_dialog_card_touch_bridge_touch_index = touch.index
			_forward_dialog_card_touch_event(pressed_card, event)
			return true
		if _dialog_card_touch_bridge_active_card == null or touch.index != _dialog_card_touch_bridge_touch_index:
			return false
		var release_card := _dialog_card_touch_bridge_active_card
		_clear_dialog_card_touch_bridge()
		if release_card == null or not is_instance_valid(release_card):
			return true
		_forward_dialog_card_touch_event(release_card, event)
		return true
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		var active_card := _dialog_card_touch_bridge_active_card
		if active_card == null or drag.index != _dialog_card_touch_bridge_touch_index:
			return false
		if not is_instance_valid(active_card):
			_clear_dialog_card_touch_bridge()
			return true
		_forward_dialog_card_touch_event(active_card, event)
		return true
	return false


func _is_dialog_card_gallery_touch_bridge_active() -> bool:
	if _dialog_overlay == null or not _dialog_overlay.visible:
		return false
	if not bool(_dialog_card_mode) and not bool(_dialog_assignment_mode):
		return false
	return true


func _clear_dialog_card_touch_bridge() -> void:
	_dialog_card_touch_bridge_active_card = null
	_dialog_card_touch_bridge_touch_index = -1


func _forward_dialog_card_touch_event(card_view: BattleCardView, event: InputEvent) -> void:
	if card_view == null or not is_instance_valid(card_view):
		return
	if not card_view.has_method("handle_bridged_pointer_input"):
		return
	card_view.call("handle_bridged_pointer_input", event)


func _dialog_card_gallery_card_at_screen_position(screen_position: Vector2) -> BattleCardView:
	var card := _dialog_card_gallery_card_at_screen_position_in_gallery(_dialog_card_scroll, _dialog_card_row, screen_position)
	if card != null:
		return card
	card = _dialog_card_gallery_card_at_screen_position_in_gallery(_dialog_assignment_source_scroll, _dialog_assignment_source_row, screen_position)
	if card != null:
		return card
	return _dialog_card_gallery_card_at_screen_position_in_gallery(_dialog_assignment_target_scroll, _dialog_assignment_target_row, screen_position)


func _dialog_card_gallery_card_at_screen_position_in_gallery(scroll: ScrollContainer, row: Control, screen_position: Vector2) -> BattleCardView:
	if scroll == null or row == null:
		return null
	if not scroll.visible or not row.visible:
		return null
	if scroll.is_inside_tree() and not scroll.is_visible_in_tree():
		return null
	if not PointerGeometryScript.control_visible_viewport_point(scroll, screen_position):
		return null
	return _dialog_card_gallery_card_at_screen_position_in_node(row, screen_position, scroll)


func _dialog_card_gallery_card_at_screen_position_in_node(node: Node, screen_position: Vector2, clip_control: Control) -> BattleCardView:
	if node == null:
		return null
	for child_index: int in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(child_index)
		var nested_card := _dialog_card_gallery_card_at_screen_position_in_node(child, screen_position, clip_control)
		if nested_card != null:
			return nested_card
	var card_view := node as BattleCardView
	if card_view == null:
		return null
	if not _is_dialog_card_gallery_touch_selectable(card_view):
		return null
	if card_view.is_inside_tree() and not card_view.is_visible_in_tree():
		return null
	if clip_control == null or not PointerGeometryScript.control_visible_viewport_point(clip_control, screen_position):
		return null
	if not PointerGeometryScript.control_visible_viewport_point(card_view, screen_position):
		return null
	return card_view


func _is_dialog_card_gallery_touch_selectable(card_view: BattleCardView) -> bool:
	if card_view == null:
		return false
	if card_view.has_meta("dialog_choice_index"):
		return int(card_view.get_meta("dialog_choice_index", -1)) >= 0
	if card_view.has_meta("assignment_source_index"):
		return (
			int(card_view.get_meta("assignment_source_index", -1)) >= 0
			and not bool(card_view.get_meta("assignment_source_disabled", false))
		)
	if card_view.has_meta("assignment_target_index"):
		return int(card_view.get_meta("assignment_target_index", -1)) >= 0
	return false


func _should_route_hand_drag_input_event(event: InputEvent) -> bool:
	if _hand_drag_active:
		return true
	if _hand_drag_late_start_blocked_by_modal():
		return false
	if event is InputEventScreenDrag:
		return true
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		return (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	return false


func _hand_drag_late_start_blocked_by_modal() -> bool:
	if _is_board_modal_overlay_visible():
		return true
	if _is_field_interaction_active():
		return true
	if _draw_reveal_active:
		return true
	if _portrait_prize_dialog_active:
		return true
	if _portrait_actions_popup != null and _portrait_actions_popup.visible:
		return true
	if _stadium_card_overlay != null and _stadium_card_overlay.visible:
		return true
	return false



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


func _raise_discard_overlay_for_input() -> void:
	_restore_landscape_overlay_z_order()
	var discard_overlay := _discard_overlay if _discard_overlay != null else find_child("DiscardOverlay", true, false) as Control
	if discard_overlay != null:
		_raise_modal_overlay_for_input(discard_overlay, ACTIVE_MODAL_OVERLAY_Z_INDEX)



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
	_ensure_battle_display_coordinator()
	_battle_display_coordinator.call("stabilize_hand_surface_layout")
	if _has_human_portrait_prize_prompt_pending():
		_show_portrait_prize_dialog_if_needed()
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
	if button.has_meta("portrait_compact_text_override"):
		button.text = str(button.get_meta("portrait_compact_text_override"))
		return
	match String(button.name):
		"BtnOpponentHand":
			button.text = "对手"
		"BtnBattleDiscussAI":
			button.text = "AI"
		"BtnZeusHelp":
			button.text = "宙斯"
		"BtnReplayPrevTurn":
			button.text = "上步"
		"BtnReplayPlayPause":
			if _replay_is_playing:
				button.text = "暂停"
			elif _replay_timeline.size() > 1 and _replay_current_frame_index >= _replay_timeline.size() - 1:
				button.text = "重头播放"
			else:
				button.text = "播放"
		"BtnReplayNextTurn":
			button.text = "下步"
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


func _clear_hand_drag_click_suppression(source: String = "clear") -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("clear_hand_drag_click_suppression", source)



func _configure_card_gallery_drag_scroll(scroll: ScrollContainer, row: Control = null, source: String = "card_gallery") -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("configure_card_gallery_drag_scroll", scroll, row, source)
	if scroll != null and bool(scroll.get_meta("card_gallery_drag_scroll_active", false)):
		_sync_card_gallery_pointer_surface(scroll)



func _set_card_gallery_drag_scroll_active(scroll: ScrollContainer, active: bool) -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("set_card_gallery_drag_scroll_active", scroll, active)
	if scroll == null or _battle_pointer_surface_controller == null:
		return
	var surface_id := _card_gallery_pointer_surface_id(scroll)
	if active:
		_sync_card_gallery_pointer_surface(scroll)
	else:
		_battle_pointer_surface_controller.unregister_surface(
			surface_id,
			"gallery_deactivated"
		)


func _cancel_card_gallery_drag_scroll(source: String = "cancel") -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("cancel_card_gallery_drag_scroll", source)



func _configure_card_gallery_card_view(card_view: BattleCardView, scroll: ScrollContainer, source: String = "card_gallery") -> void:
	_ensure_battle_drag_scroll_coordinator()
	_battle_drag_scroll_coordinator.call("configure_card_gallery_card_view", card_view, scroll, source)
	_sync_card_foil_effect_for_view(card_view)
	if (
		scroll != null
		and bool(scroll.get_meta("card_gallery_drag_scroll_active", false))
	):
		call_deferred("_deferred_sync_card_gallery_pointer_surface", scroll)


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
		_top_action_button_or_null(_btn_replay_play_pause, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnReplayPlayPause"),
		_top_action_button_or_null(_btn_replay_next_turn, "TopBar/TopBarRow/TopBarRight/TopBarActions/BtnReplayNextTurn"),
		_top_action_button_or_null(_opt_replay_speed, "TopBar/TopBarRow/TopBarRight/TopBarActions/OptReplaySpeed"),
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
	if _battle_visual_sequence_controller != null and bool(_battle_visual_sequence_controller.call("is_active")):
		return
	_ensure_battle_deck_shuffle_animator()
	_battle_deck_shuffle_animator.call("refresh_deck_shuffle_detection", gs)


func _on_state_changed(_new_phase: GameState.GamePhase) -> void:
	_capture_battle_recording_context_if_ready()
	_refresh_ui()
	if _deck_training_controller != null:
		var training_status := _deck_training_controller.on_state_changed()
		if bool(training_status.get("completed", false)) or bool(training_status.get("failed", false)):
			_runtime_log("deck_training_terminal", JSON.stringify(training_status))
			return
	_check_two_player_handover()
	_maybe_run_ai()
	_runtime_log("state_changed", _state_snapshot())



func _enqueue_battle_visual_action(action: GameAction) -> void:
	if (
		action != null
		and _battle_visual_sequence_controller != null
		and _gsm != null
		and _gsm.game_state != null
		and not _is_review_mode()
		and (
			_gsm.game_state.phase not in [GameState.GamePhase.SETUP, GameState.GamePhase.MULLIGAN, GameState.GamePhase.SETUP_PLACE]
			or action.action_type == GameAction.ActionType.TURN_START
		)
	):
		var suppressed_visual_semantics: Array[String] = []
		if action.action_type == GameAction.ActionType.DRAW_CARD:
			suppressed_visual_semantics.append("*")
		elif action.action_type == GameAction.ActionType.DISCARD and str(action.data.get("source_zone", "")) == "hand":
			suppressed_visual_semantics.append("zone_transfer")
		elif action.action_type == GameAction.ActionType.PLAY_TRAINER and str(action.data.get("trainer_vfx", "")) == "switching_ticket":
			suppressed_visual_semantics.append("*")
		_battle_visual_sequence_controller.call(
			"capture_action",
			action,
			_gsm.game_state,
			_view_player,
			suppressed_visual_semantics
		)


func _on_action_logged(action: GameAction) -> void:
	# Preserve the action-time state for presentation before any diagnostics can
	# serialize a large public/native snapshot on the main thread.
	_enqueue_battle_visual_action(action)
	_record_author_public_action(action)
	if _author_public_replay_progress_mode() == "action":
		_record_author_public_replay_progress()
	_capture_battle_recording_context_if_ready()
	if action.description != "":
		var display_description := _format_action_description_for_display(action.description)
		if action.player_index != _view_player:
			_latest_opponent_action_text = display_description
			_latest_opponent_action_turn_number = action.turn_number
		_log(display_description, action)
	if _is_turn_start_draw_action(action):
		action.data["turn_start"] = true
		action.data["draw_source"] = "turn_start"
		_record_turn_start_snapshot_after_draw(action)
	if BattleZoneChangeContractScript.should_reconcile_hand_immediately(action, _view_player):
		# This signal is emitted from inside the rule transaction. Reconcile after
		# it returns so Android modal/layout teardown cannot preserve an
		# intermediate hand Surface.
		_request_authoritative_hand_reconciliation("zone_change_action")
	if (
		action != null
		and action.action_type == GameAction.ActionType.DRAW_CARD
		and _gsm != null
		and _gsm.game_state != null
		and _gsm.game_state.phase != GameState.GamePhase.SETUP
		and not _is_review_mode()
		and not _is_opening_turn_start_draw_action(action)
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
		and action.action_type == GameAction.ActionType.PLAY_TRAINER
		and not _is_review_mode()
		and str(action.data.get("trainer_vfx", "")) == "switching_ticket"
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
	elif (
		action != null
		and action.action_type == GameAction.ActionType.PLAY_TRAINER
		and not _is_review_mode()
		and str(action.data.get("trainer_vfx", "")) == "boss_orders"
	):
		_battle_attack_vfx_controller.call("play_boss_orders_vfx", self, action.data)
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
	if _deck_training_controller != null:
		_deck_training_controller.on_action_logged(action)


func _on_player_choice_required(choice_type: String, data: Dictionary) -> void:
	_capture_battle_recording_context_if_ready()
	_runtime_log("player_choice_required", "%s data=%s" % [choice_type, JSON.stringify(data)])
	match choice_type:
		"mulligan_extra_draw":
			var beneficiary: int = data.get("beneficiary", 0)
			var count: int = data.get("mulligan_count", 1)
			var choices: Array[String] = []
			for draw_count: int in count + 1:
				choices.append("让玩家 %d 多抽 %d 张牌" % [beneficiary + 1, draw_count])
			_pending_choice = "mulligan_extra_draw"
			_show_dialog(
				"对手第 %d 次重抽" % count,
				choices,
				{
					"beneficiary": beneficiary,
					"maximum_draw_count": count,
					"allow_cancel": false,
				}
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
		"powerglass_end_turn":
			var powerglass_steps: Array[Dictionary] = []
			for raw_powerglass_step: Variant in data.get("steps", []):
				if raw_powerglass_step is Dictionary:
					powerglass_steps.append(raw_powerglass_step)
			var powerglass_card: CardInstance = data.get("card", null) as CardInstance
			var powerglass_slot: PokemonSlot = data.get("slot", null) as PokemonSlot
			if not powerglass_steps.is_empty() and powerglass_card != null:
				_start_effect_interaction(
					"powerglass_end_turn",
					int(data.get("player", _view_player)),
					powerglass_steps,
					powerglass_card,
					powerglass_slot
				)
		"amulet_of_hope_knockout":
			var amulet_steps: Array[Dictionary] = []
			for raw_amulet_step: Variant in data.get("steps", []):
				if raw_amulet_step is Dictionary:
					amulet_steps.append(raw_amulet_step)
			var amulet_card: CardInstance = data.get("card", null) as CardInstance
			var amulet_slot: PokemonSlot = data.get("slot", null) as PokemonSlot
			if not amulet_steps.is_empty() and amulet_card != null and amulet_slot != null:
				_start_effect_interaction(
					"amulet_of_hope_knockout",
					int(data.get("player", _view_player)),
					amulet_steps,
					amulet_card,
					amulet_slot
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
	if _deck_training_controller != null:
		_clear_prize_selection()
		_refresh_ui()
		_deck_training_controller.on_game_over(winner_index, reason)
		return
	# Finalize the tournament result while its battle identity is still intact.
	# The result screen may remain open for a long time (or the app may resume),
	# so its return route must not depend on the mutable in-progress flag.
	var tournament_match := GameManager.is_tournament_battle_active() or _match_end_tournament_return_pending
	_match_end_tournament_return_pending = tournament_match
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
	_finish_author_developer_trace(winner_index, reason)
	_finish_author_match_evidence(winner_index, reason)
	_finish_author_public_replay(winner_index, reason)
	if _battle_recorder != null and _battle_recorder.has_method("get_match_dir"):
		_battle_review_match_dir = str(_battle_recorder.call("get_match_dir"))
	if tournament_match:
		_finalize_battle_recording({
			"winner_index": winner_index,
			"reason": reason,
			"turn_number": _gsm.game_state.turn_number if _gsm != null and _gsm.game_state != null else 0,
		})
		# Build the result screen before finalization clears the tournament player
		# display names, then persist the completed round immediately afterwards.
		_show_match_end_dialog(winner_index, reason)
		if GameManager.is_tournament_battle_active():
			GameManager.finalize_current_tournament_battle(winner_index, reason)
		return
	_show_match_end_dialog(winner_index, reason)
	_finalize_battle_recording({
		"winner_index": winner_index,
		"reason": reason,
		"turn_number": _gsm.game_state.turn_number if _gsm != null and _gsm.game_state != null else 0,
	})



func _on_stadium_action_pressed() -> void:
	if _is_board_modal_overlay_visible():
		return
	if not _can_view_player_start_turn_action() or _gsm == null or _is_field_interaction_active():
		return
	_show_stadium_action_dialog(_gsm.game_state.current_player_index)



func _on_stadium_card_left_clicked(card_instance: CardInstance, card_data: CardData) -> void:
	if _is_board_modal_overlay_visible():
		return
	var gs := _gsm.game_state if _gsm != null else null
	if gs != null and gs.stadium_card != null and _can_view_player_start_turn_action() and not _is_field_interaction_active():
		_show_stadium_action_dialog(gs.current_player_index)
		return
	if card_instance != null:
		_show_card_detail_for_instance(card_instance)
		return
	var detail_data := card_data
	if detail_data != null:
		_show_card_detail(detail_data)


func _on_stadium_card_right_clicked(card_instance: CardInstance, card_data: CardData) -> void:
	if _is_board_modal_overlay_visible():
		return
	if card_instance != null:
		_show_card_detail_for_instance(card_instance)
		return
	var detail_data := card_data
	if detail_data != null:
		_show_card_detail(detail_data)


func _on_stadium_area_input(event: InputEvent) -> void:
	if _is_board_modal_overlay_visible():
		return
	if not (event is InputEventMouseButton):
		return
	var mbe := event as InputEventMouseButton
	if not mbe.pressed:
		return
	if not _can_view_player_start_turn_action():
		return
	if _gsm == null or _gsm.game_state.stadium_card == null:
		return
	if mbe.button_index == MOUSE_BUTTON_LEFT:
		_show_stadium_action_dialog(_gsm.game_state.current_player_index)
		return
	if mbe.button_index != MOUSE_BUTTON_RIGHT:
		return
	_show_card_detail_for_instance(_gsm.game_state.stadium_card)


func _on_back_pressed() -> void:
	if _is_field_interaction_active():
		return
	if _deck_training_controller != null:
		GameManager.clear_deck_training_launch()
		GameManager.goto_deck_training()
		return
	_pending_choice = "confirm_exit"
	_show_dialog("确认退出对战？当前进度不会保存。", ["确认退出", "取消"], {})
	_dialog_cancel.visible = false


func _on_zeus_help_pressed() -> void:
	if _deck_training_controller != null:
		if _is_field_interaction_active():
			return
		_deck_training_controller.show_stage_goal()
		return
	if not _can_view_player_start_turn_action() or _gsm == null or _gsm.game_state == null or _is_field_interaction_active():
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
	if GameManager.current_mode not in [
		GameManager.GameMode.VS_AI,
		GameManager.GameMode.VS_AUTHOR_STRATEGY_AI,
	]:
		return
	_show_opponent_hand_cards()
