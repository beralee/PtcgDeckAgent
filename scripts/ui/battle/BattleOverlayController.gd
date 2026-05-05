class_name BattleOverlayController
extends RefCounted

const BattleCardViewScript := preload("res://scenes/battle/BattleCardView.gd")
const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")


func _bt(scene: Object, key: String, params: Dictionary = {}) -> String:
	return str(scene.call("_bt", key, params))


func start_prize_selection(scene: Object, player_index: int, count: int) -> void:
	scene.set("_pending_choice", "take_prize")
	scene.set("_pending_prize_player_index", player_index)
	scene.set("_pending_prize_remaining", count)
	scene.set("_pending_prize_animating", false)
	scene.call("_refresh_ui")
	focus_prize_panel(scene, player_index)
	scene.call("_log", _bt(scene, "battle.prize.prompt", {"count": count}))


func clear_prize_selection(scene: Object) -> void:
	if str(scene.get("_pending_choice")) == "take_prize":
		scene.set("_pending_choice", "")
	scene.set("_pending_prize_player_index", -1)
	scene.set("_pending_prize_remaining", 0)
	scene.set("_pending_prize_animating", false)
	refresh_prize_titles(scene)


func refresh_prize_titles(scene: Object) -> void:
	var view_player: int = int(scene.get("_view_player"))
	update_prize_title(scene, scene.get("_opp_prizes_title"), 1 - view_player, _bt(scene, "battle.prize.opponent"), false)
	update_prize_title(scene, scene.get("_my_prizes_title"), view_player, _bt(scene, "battle.prize.self"), false)
	update_prize_title(scene, scene.get("_opp_prize_hud_title"), 1 - view_player, _bt(scene, "battle.prize.opponent"), true)
	update_prize_title(scene, scene.get("_my_prize_hud_title"), view_player, _bt(scene, "battle.prize.self"), true)


func update_prize_title(scene: Object, label: Label, player_index: int, default_text: String, is_hud: bool) -> void:
	if label == null:
		return
	var is_pending := (
		str(scene.get("_pending_choice")) == "take_prize"
		and int(scene.get("_pending_prize_player_index")) == player_index
		and int(scene.get("_pending_prize_remaining")) > 0
	)
	label.text = _bt(scene, "battle.prize.pending_title", {
		"count": int(scene.get("_pending_prize_remaining")),
	}) if is_pending else default_text
	label.add_theme_font_size_override("font_size", 15 if is_hud else 11)
	var normal_color := Color(0.54, 0.9, 0.94, 0.9) if is_hud else Color(0.93, 0.97, 1.0, 0.9)
	var active_color := Color(1.0, 0.87, 0.34, 1.0)
	label.add_theme_color_override("font_color", active_color if is_pending else normal_color)
	_update_prize_panel_style(scene, player_index, is_pending, is_hud)


func _update_prize_panel_style(scene: Object, player_index: int, is_pending: bool, is_hud: bool) -> void:
	var view_player: int = int(scene.get("_view_player"))
	var is_self := player_index == view_player
	var panel: Control = null
	if is_hud:
		panel = scene.get("_my_hud_left") if is_self else scene.get("_opp_hud_left")
	else:
		panel = scene.get("_my_prizes_box") if is_self else scene.get("_opp_prizes_box")
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(16)
	style.set_border_width_all(4 if is_pending else 2)
	if is_pending:
		style.bg_color = Color(0.18, 0.13, 0.03, 0.90)
		style.border_color = Color(1.0, 0.84, 0.18, 1.0)
		style.shadow_color = Color(1.0, 0.68, 0.05, 0.34)
		style.shadow_size = 14
		style.shadow_offset = Vector2.ZERO
	else:
		style.bg_color = Color(0.03, 0.11, 0.15, 0.70) if is_self else Color(0.02, 0.10, 0.16, 0.70)
		style.border_color = Color(0.27, 0.86, 0.70, 0.92) if is_self else Color(0.22, 0.68, 0.84, 0.92)
	if panel is PanelContainer:
		(panel as PanelContainer).add_theme_stylebox_override("panel", style)
	elif panel is Panel:
		(panel as Panel).add_theme_stylebox_override("panel", style)


func focus_prize_panel(scene: Object, player_index: int) -> void:
	var view_player: int = int(scene.get("_view_player"))
	var target_panel: Control = scene.get("_my_hud_left") if player_index == view_player else scene.get("_opp_hud_left")
	if target_panel == null or not (scene as Node).is_inside_tree():
		return
	target_panel.pivot_offset = target_panel.size * 0.5
	target_panel.scale = Vector2.ONE
	var tween := (scene as Node).create_tween()
	tween.tween_property(target_panel, "scale", Vector2(1.05, 1.05), 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(target_panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func show_opponent_hand_cards(scene: Object) -> void:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null:
		return
	var view_player: int = int(scene.get("_view_player"))
	var opponent_index: int = 1 - view_player
	if opponent_index < 0 or opponent_index >= gsm.game_state.players.size():
		return
	var player: PlayerState = gsm.game_state.players[opponent_index]
	var discard_title: Label = scene.get("_discard_title")
	var discard_list: ItemList = scene.get("_discard_list")
	var discard_card_scroll: ScrollContainer = scene.get("_discard_card_scroll")
	var discard_card_row: HBoxContainer = scene.get("_discard_card_row")
	var discard_utility_row: HBoxContainer = scene.get("_discard_utility_row")
	var discard_overlay: Panel = scene.get("_discard_overlay")
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	discard_title.text = _bt(scene, "battle.overlay.opponent_hand", {"count": player.hand.size()})
	discard_list.clear()
	scene.set("_discard_card_page", 0)
	scene.set("_discard_card_page_size", 0)
	if discard_card_scroll != null:
		discard_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		discard_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		HudThemeScript.style_scroll_container(discard_card_scroll)
	if discard_utility_row != null:
		scene.call("_clear_container_children", discard_utility_row)
		discard_utility_row.visible = false
	if discard_card_row != null:
		scene.call("_clear_container_children", discard_card_row)
		if player.hand.is_empty():
			var empty_label := Label.new()
			empty_label.text = _bt(scene, "battle.overlay.empty")
			discard_card_row.add_child(empty_label)
		else:
			for hand_card: CardInstance in player.hand:
				var card_view := BattleCardViewScript.new()
				card_view.custom_minimum_size = dialog_card_size
				card_view.set_clickable(true)
				card_view.setup_from_instance(hand_card, BattleCardView.MODE_PREVIEW)
				card_view.set_badges("", "")
				card_view.set_info("", "")
				card_view.left_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
					if cd != null:
						scene.call("_show_card_detail", cd)
				)
				card_view.right_clicked.connect(func(_ci: CardInstance, cd: CardData) -> void:
					if cd != null:
						scene.call("_show_card_detail", cd)
				)
				discard_card_row.add_child(card_view)
	else:
		if player.hand.is_empty():
			discard_list.add_item(_bt(scene, "battle.overlay.empty"))
		else:
			for hand_card: CardInstance in player.hand:
				var card_data: CardData = hand_card.card_data
				discard_list.add_item("%s [%s]" % [card_data.name, scene.call("_card_type_cn", card_data)])
	discard_overlay.visible = true
	scene.call("_runtime_log", "show_opponent_hand", "player=%d count=%d" % [opponent_index, player.hand.size()])


func show_handover_prompt(scene: Object, target_player: int, follow_up: Callable = Callable()) -> void:
	if follow_up.is_valid():
		scene.call("_set_pending_handover_action", follow_up, "show_prompt_follow_up")
	elif not (scene.get("_pending_handover_action") as Callable).is_valid():
		scene.call("_set_pending_handover_action", Callable(), "show_prompt_generic")
	else:
		scene.call(
			"_runtime_log",
			"handover_action_preserved",
			"reason=show_prompt_generic target=%d %s" % [target_player, scene.call("_state_snapshot")]
		)
	scene.call("_set_handover_panel_visible", true, "show_prompt_target_%d" % target_player)
	var handover_label: Label = scene.get("_handover_lbl")
	handover_label.text = _bt(scene, "battle.handover.prompt", {"player": target_player + 1})


func check_two_player_handover(scene: Object) -> void:
	var gsm: Variant = scene.get("_gsm")
	if GameManager.current_mode != GameManager.GameMode.TWO_PLAYER:
		scene.call("_set_pending_handover_action", Callable(), "handover_check_non_two_player")
		scene.call("_set_handover_panel_visible", false, "handover_check_non_two_player")
		return
	if gsm == null or gsm.game_state.phase == GameState.GamePhase.GAME_OVER:
		scene.call("_set_pending_handover_action", Callable(), "handover_check_game_over")
		scene.call("_set_handover_panel_visible", false, "handover_check_game_over")
		return
	if (scene.get("_pending_handover_action") as Callable).is_valid():
		scene.call("_runtime_log", "handover_check_deferred", scene.call("_state_snapshot"))
		return
	var current_player: int = gsm.game_state.current_player_index
	if current_player != int(scene.get("_view_player")):
		show_handover_prompt(scene, current_player)
		scene.call("_runtime_log", "handover_required", scene.call("_state_snapshot"))
		return
	scene.call("_set_pending_handover_action", Callable(), "handover_check_aligned")
	scene.call("_set_handover_panel_visible", false, "handover_check_aligned")


func on_handover_confirmed(scene: Object) -> void:
	var pending_handover_action: Callable = scene.get("_pending_handover_action")
	scene.call(
		"_runtime_log",
		"handover_confirm_requested",
		"follow_up_valid=%s %s" % [str(pending_handover_action.is_valid()), scene.call("_state_snapshot")]
	)
	scene.call("_set_handover_panel_visible", false, "handover_confirm")
	scene.call("_set_pending_handover_action", Callable(), "handover_confirm")
	if pending_handover_action.is_valid():
		pending_handover_action.call()
	else:
		var gsm: Variant = scene.get("_gsm")
		var current_player: int = gsm.game_state.current_player_index
		scene.set("_view_player", current_player)
		scene.call("_refresh_ui")
	var draw_reveal_controller: RefCounted = scene.get("_battle_draw_reveal_controller")
	if draw_reveal_controller != null and draw_reveal_controller.has_method("resume_if_ready"):
		draw_reveal_controller.call("resume_if_ready", scene)
	scene.call("_maybe_run_ai")
	scene.call("_runtime_log", "handover_confirmed", scene.call("_state_snapshot"))


func refresh_match_end_dialog_if_visible(scene: Object) -> void:
	var match_end_overlay: Panel = scene.get("_match_end_overlay")
	if str(scene.get("_pending_choice")) != "game_over" or match_end_overlay == null or not match_end_overlay.visible:
		return
	refresh_match_end_screen(scene)


func open_cached_battle_review(scene: Object) -> void:
	var review: Dictionary = scene.call("_load_cached_battle_review")
	if review.is_empty():
		review = (scene.get("_battle_review_last_review") as Dictionary).duplicate(true)
	if review.is_empty():
		return
	show_battle_review_overlay(scene, review)


func show_battle_review_overlay(scene: Object, review: Dictionary) -> void:
	scene.set("_review_overlay_mode", "battle_review")
	var review_title: Label = scene.get("_review_title")
	var review_content: RichTextLabel = scene.get("_review_content")
	var review_overlay: Panel = scene.get("_review_overlay")
	var regenerate_button: Button = scene.get("_review_regenerate_btn")
	review_title.text = _bt(scene, "battle.review.title")
	review_content.text = str(scene.call("_format_battle_review", review))
	review_overlay.visible = true
	regenerate_button.disabled = bool(scene.get("_battle_review_busy"))


func show_match_end_screen(scene: Object, winner_index: int, reason: String) -> void:
	_ensure_match_end_screen(scene)
	scene.set("_pending_choice", "game_over")
	var dialog_overlay: Panel = scene.get("_dialog_overlay")
	if dialog_overlay != null:
		dialog_overlay.visible = false
	var stats := build_match_end_stats(scene, winner_index, reason)
	scene.set("_match_end_stats", stats)
	var match_end_overlay: Panel = scene.get("_match_end_overlay")
	if match_end_overlay == null:
		return
	match_end_overlay.visible = true
	refresh_match_end_screen(scene)
	if bool(scene.call("_match_end_quick_review_configured")) and not bool(scene.get("_match_end_quick_review_requested")) and not bool(scene.get("_match_end_quick_review_busy")):
		(scene as Node).call_deferred("_begin_match_end_quick_review")
	elif (scene.get("_match_end_quick_review_result") as Dictionary).is_empty() and not bool(scene.get("_match_end_quick_review_busy")):
		scene.set("_match_end_quick_review_result", scene.call("_local_match_end_quick_review"))
		refresh_match_end_screen(scene)
	_play_match_end_reveal(scene)


func refresh_match_end_screen(scene: Object) -> void:
	var match_end_overlay: Panel = scene.get("_match_end_overlay")
	if match_end_overlay == null:
		return
	var stats: Dictionary = scene.get("_match_end_stats")
	if stats.is_empty():
		stats = build_match_end_stats(scene, int(scene.get("_battle_review_winner_index")), str(scene.get("_battle_review_reason")))
		scene.set("_match_end_stats", stats)

	var title: Label = scene.get("_match_end_title")
	var subtitle: Label = scene.get("_match_end_subtitle")
	var reason_label: Label = scene.get("_match_end_reason")
	if title != null:
		title.text = _match_end_title_text(stats)
		title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36) if bool(stats.get("is_view_player_winner", false)) else Color(0.70, 0.90, 1.0))
	if subtitle != null:
		subtitle.text = str(stats.get("subtitle", ""))
	if reason_label != null:
		reason_label.text = "结束原因：%s" % str(stats.get("reason_text", ""))

	var viewport_size := Vector2(1280, 720)
	if scene is Node and (scene as Node).is_inside_tree():
		viewport_size = (scene as Node).get_viewport().get_visible_rect().size
	var box: PanelContainer = match_end_overlay.get_node_or_null("MatchEndCenter/MatchEndBox") as PanelContainer
	if box != null:
		box.custom_minimum_size = Vector2(minf(maxf(viewport_size.x - 28.0, 320.0), 980.0), 0)

	_refresh_match_end_stat_cards(scene, stats, viewport_size)
	_refresh_match_end_summary_text(scene, stats)
	_refresh_match_end_ai_panel(scene)
	_refresh_match_end_buttons(scene)
	var buttons := match_end_overlay.get_node_or_null("MatchEndCenter/MatchEndBox/MarginContainer/MatchEndRoot/MatchEndButtons") as HBoxContainer
	if buttons != null:
		buttons.alignment = BoxContainer.ALIGNMENT_CENTER


func build_match_end_stats(scene: Object, winner_index: int, reason: String) -> Dictionary:
	var snapshot: Dictionary = scene.call("_build_battle_state_snapshot") if scene.has_method("_build_battle_state_snapshot") else {}
	var players: Array = snapshot.get("players", [])
	var view_player := int(scene.get("_view_player"))
	var opponent_index := 1 - view_player
	var action_stats := _match_end_action_stats(scene)
	var player_summaries: Array[Dictionary] = []
	for player_index: int in 2:
		var player_snapshot: Dictionary = players[player_index] if player_index < players.size() and players[player_index] is Dictionary else {}
		var action_summary: Dictionary = action_stats.get(player_index, _empty_match_end_action_stats())
		player_summaries.append(_match_end_player_summary(scene, player_index, player_snapshot, action_summary))
	var view_summary: Dictionary = player_summaries[view_player] if view_player >= 0 and view_player < player_summaries.size() else {}
	var opponent_summary: Dictionary = player_summaries[opponent_index] if opponent_index >= 0 and opponent_index < player_summaries.size() else {}
	var turn_number := int(snapshot.get("turn_number", 0))
	if turn_number <= 0:
		var gsm: Variant = scene.get("_gsm")
		if gsm != null and gsm.game_state != null:
			turn_number = gsm.game_state.turn_number
	var is_view_player_winner := winner_index == view_player
	return {
		"winner_index": winner_index,
		"winner_label": GameManager.resolve_battle_player_display_name(winner_index) if winner_index >= 0 else "无人获胜",
		"view_player_index": view_player,
		"opponent_index": opponent_index,
		"is_view_player_winner": is_view_player_winner,
		"result_label": "胜利" if is_view_player_winner else "再接再厉",
		"subtitle": _match_end_subtitle(scene, winner_index, view_player, turn_number),
		"reason": reason,
		"reason_text": _match_end_reason_text(reason),
		"turn_number": turn_number,
		"players": player_summaries,
		"view_player": view_summary,
		"opponent": opponent_summary,
	}


func _ensure_match_end_screen(scene: Object) -> void:
	if scene.get("_match_end_overlay") != null:
		return
	if not (scene is Node):
		return
	var root := scene as Node
	var overlay := Panel.new()
	overlay.name = "MatchEndOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 140
	overlay.visible = false
	overlay.add_theme_stylebox_override("panel", _match_end_overlay_style())
	root.add_child(overlay)
	scene.set("_match_end_overlay", overlay)

	var center := CenterContainer.new()
	center.name = "MatchEndCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var box := PanelContainer.new()
	box.name = "MatchEndBox"
	box.add_theme_stylebox_override("panel", _match_end_box_style(Color(1.0, 0.75, 0.22, 0.95)))
	center.add_child(box)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	box.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.name = "MatchEndRoot"
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	var title := Label.new()
	title.name = "MatchEndTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.035, 0.05, 1.0))
	title.add_theme_constant_override("outline_size", 3)
	root_vbox.add_child(title)
	scene.set("_match_end_title", title)

	var subtitle := Label.new()
	subtitle.name = "MatchEndSubtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0, 1.0))
	root_vbox.add_child(subtitle)
	scene.set("_match_end_subtitle", subtitle)

	var reason_label := Label.new()
	reason_label.name = "MatchEndReason"
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.add_theme_font_size_override("font_size", 15)
	reason_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.52, 1.0))
	root_vbox.add_child(reason_label)
	scene.set("_match_end_reason", reason_label)

	var stats_grid := GridContainer.new()
	stats_grid.name = "MatchEndStatsGrid"
	stats_grid.columns = 4
	stats_grid.add_theme_constant_override("h_separation", 10)
	stats_grid.add_theme_constant_override("v_separation", 10)
	stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(stats_grid)
	scene.set("_match_end_stats_grid", stats_grid)

	var summary_row := VBoxContainer.new()
	summary_row.name = "MatchEndSummaryRow"
	summary_row.add_theme_constant_override("separation", 12)
	summary_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(summary_row)

	var player_summary := _make_match_end_text_panel("MatchEndPlayerSummary")
	summary_row.add_child(player_summary.get("panel"))
	scene.set("_match_end_player_summary", player_summary.get("text"))

	var action_summary := _make_match_end_text_panel("MatchEndActionSummary")
	summary_row.add_child(action_summary.get("panel"))
	scene.set("_match_end_action_summary", action_summary.get("text"))

	var ai_panel := PanelContainer.new()
	ai_panel.name = "MatchEndAiPanel"
	ai_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai_panel.add_theme_stylebox_override("panel", _match_end_inner_panel_style(Color(0.16, 0.56, 0.72, 0.66)))
	root_vbox.add_child(ai_panel)

	var ai_margin := MarginContainer.new()
	ai_margin.add_theme_constant_override("margin_left", 14)
	ai_margin.add_theme_constant_override("margin_top", 12)
	ai_margin.add_theme_constant_override("margin_right", 14)
	ai_margin.add_theme_constant_override("margin_bottom", 12)
	ai_panel.add_child(ai_margin)
	var ai_vbox := VBoxContainer.new()
	ai_vbox.add_theme_constant_override("separation", 6)
	ai_margin.add_child(ai_vbox)
	var ai_title := Label.new()
	ai_title.name = "MatchEndAiTitle"
	ai_title.add_theme_font_size_override("font_size", 16)
	ai_title.add_theme_color_override("font_color", Color(0.78, 0.96, 1.0, 1.0))
	ai_vbox.add_child(ai_title)
	scene.set("_match_end_ai_title", ai_title)
	var ai_content := RichTextLabel.new()
	ai_content.name = "MatchEndAiContent"
	ai_content.bbcode_enabled = true
	ai_content.fit_content = true
	ai_content.scroll_active = false
	ai_content.add_theme_font_size_override("normal_font_size", 14)
	ai_content.add_theme_color_override("default_color", Color(0.88, 0.95, 1.0, 1.0))
	ai_vbox.add_child(ai_content)
	scene.set("_match_end_ai_content", ai_content)

	var buttons := HBoxContainer.new()
	buttons.name = "MatchEndButtons"
	buttons.add_theme_constant_override("separation", 10)
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(buttons)
	_add_match_end_button(scene, buttons, "_match_end_ai_button", "AI快评", "_on_match_end_quick_review_pressed", Color(0.18, 0.72, 0.92, 1.0))
	_add_match_end_button(scene, buttons, "_match_end_review_button", "生成AI复盘", "_on_match_end_review_pressed", Color(0.60, 0.82, 0.42, 1.0))
	_add_match_end_button(scene, buttons, "_match_end_learning_button", "加入学习池", "_on_match_end_learning_pressed", Color(0.92, 0.68, 0.30, 1.0))
	_add_match_end_button(scene, buttons, "_match_end_return_button", "返回对战准备", "_on_match_end_return_pressed", Color(0.64, 0.72, 0.84, 1.0))


func _add_match_end_button(scene: Object, parent: Container, property_name: String, label: String, method_name: String, accent: Color) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(150, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _match_end_button_style(accent, false, false))
	button.add_theme_stylebox_override("hover", _match_end_button_style(accent, true, false))
	button.add_theme_stylebox_override("pressed", _match_end_button_style(accent, true, true))
	button.add_theme_stylebox_override("disabled", _match_end_button_disabled_style())
	button.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.52, 0.58, 0.64, 1.0))
	if scene.has_method(method_name):
		button.pressed.connect(Callable(scene, method_name))
	parent.add_child(button)
	scene.set(property_name, button)


func _make_match_end_text_panel(name: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "%sPanel" % name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _match_end_inner_panel_style(Color(0.20, 0.62, 0.78, 0.46)))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var text := RichTextLabel.new()
	text.name = name
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 14)
	text.add_theme_color_override("default_color", Color(0.88, 0.95, 1.0, 1.0))
	margin.add_child(text)
	return {"panel": panel, "text": text}


func _refresh_match_end_stat_cards(scene: Object, stats: Dictionary, viewport_size: Vector2) -> void:
	var grid: GridContainer = scene.get("_match_end_stats_grid")
	if grid == null:
		return
	grid.columns = 2 if viewport_size.x < 760.0 else 4
	_clear_children(grid)
	var view_stats: Dictionary = stats.get("view_player", {})
	var opponent_stats: Dictionary = stats.get("opponent", {})
	var prize_text := "%d-%d" % [int(view_stats.get("prizes_taken", 0)), int(opponent_stats.get("prizes_taken", 0))]
	var damage_text := "%d" % int(view_stats.get("max_damage", 0))
	var action_text := "%d" % int(view_stats.get("tempo_actions", 0))
	_add_match_end_stat_card(grid, "回合", str(stats.get("turn_number", 0)), "打完的总回合数", Color(0.34, 0.78, 1.0, 1.0))
	_add_match_end_stat_card(grid, "奖赏", prize_text, "己方-对方已拿奖赏", Color(1.0, 0.76, 0.24, 1.0))
	_add_match_end_stat_card(grid, "最大伤害", damage_text, "己方单次最高伤害", Color(1.0, 0.38, 0.28, 1.0))
	_add_match_end_stat_card(grid, "节奏行动", action_text, "训练家/特性/能量合计", Color(0.48, 0.92, 0.56, 1.0))


func _add_match_end_stat_card(parent: GridContainer, label: String, value: String, caption: String, accent: Color) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 82)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _match_end_stat_card_style(accent))
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)
	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 25)
	value_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78, 1.0))
	box.add_child(value_label)
	var name_label := Label.new()
	name_label.text = label
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0, 1.0))
	box.add_child(name_label)
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size", 11)
	caption_label.add_theme_color_override("font_color", Color(0.62, 0.74, 0.84, 1.0))
	box.add_child(caption_label)


func _refresh_match_end_summary_text(scene: Object, stats: Dictionary) -> void:
	var player_summary: RichTextLabel = scene.get("_match_end_player_summary")
	var action_summary: RichTextLabel = scene.get("_match_end_action_summary")
	var view_stats: Dictionary = stats.get("view_player", {})
	var opponent_stats: Dictionary = stats.get("opponent", {})
	if player_summary != null:
		player_summary.text = "[b]资源对比[/b]\n%s\n%s" % [
			_match_end_player_line(view_stats, "你"),
			_match_end_player_line(opponent_stats, "对手"),
		]
	if action_summary != null:
		action_summary.text = "[b]本局表现[/b]\n%s\n%s\n%s" % [
			"攻击 %d 次，击倒 %d 次，拿奖赏 %d 张" % [int(view_stats.get("attacks", 0)), int(view_stats.get("knockouts", 0)), int(view_stats.get("prizes_taken", 0))],
			"训练家 %d 次，特性 %d 次，贴能 %d 次" % [int(view_stats.get("trainers", 0)), int(view_stats.get("abilities", 0)), int(view_stats.get("energy_attaches", 0))],
			_match_end_takeaway(stats),
		]


func _refresh_match_end_ai_panel(scene: Object) -> void:
	var ai_title: Label = scene.get("_match_end_ai_title")
	var ai_content: RichTextLabel = scene.get("_match_end_ai_content")
	if ai_title == null or ai_content == null:
		return
	var configured := bool(scene.call("_match_end_quick_review_configured"))
	var model_label := str(scene.call("_match_end_quick_review_model_label"))
	var result: Dictionary = scene.get("_match_end_quick_review_result")
	if bool(scene.get("_match_end_quick_review_busy")):
		ai_title.text = "AI赛后快评"
		ai_content.text = "[color=#9feaff]%s[/color]" % str(scene.get("_match_end_quick_review_progress_text"))
		return
	if not result.is_empty():
		var result_status := str(result.get("status", ""))
		if result_status == "ai_failed_fallback":
			ai_title.text = "本地赛后简评（AI暂不可用）"
		else:
			ai_title.text = "AI赛后快评" if configured else "本地赛后简评"
		ai_content.text = _format_match_end_quick_review(result)
		return
	ai_title.text = "赛后快评"
	ai_content.text = "AI未配置。当前只显示本地统计；在AI设置里填好模型后，结算时会自动给出简短点评和评分。"


func _refresh_match_end_buttons(scene: Object) -> void:
	var ai_button: Button = scene.get("_match_end_ai_button")
	var review_button: Button = scene.get("_match_end_review_button")
	var learning_button: Button = scene.get("_match_end_learning_button")
	var return_button: Button = scene.get("_match_end_return_button")
	if ai_button != null:
		ai_button.visible = false
		ai_button.disabled = true
	if review_button != null:
		review_button.visible = false
		review_button.disabled = true
	if learning_button != null:
		learning_button.visible = false
		learning_button.disabled = true
	if return_button != null:
		return_button.visible = true
		return_button.text = "返回比赛积分" if GameManager.is_tournament_battle_active() else "返回对战准备"
		return_button.disabled = false


func _format_match_end_quick_review(result: Dictionary) -> String:
	var status := str(result.get("status", ""))
	if status == "failed":
		var errors: Array = []
		var errors_variant: Variant = result.get("errors", [])
		if errors_variant is Array:
			errors = errors_variant
		var message := "请求失败"
		if not errors.is_empty() and errors[0] is Dictionary:
			message = str((errors[0] as Dictionary).get("message", message))
		return "[b]AI点评失败[/b]\n%s" % message
	var fallback_note := ""
	if status == "ai_failed_fallback":
		var ai_error := str(result.get("ai_error", "AI 快评暂不可用，已使用本地专业快评。")).strip_edges()
		if ai_error == "":
			ai_error = "AI 快评暂不可用，已使用本地专业快评。"
		fallback_note = "[color=#ffd36a]%s[/color]\n\n" % ai_error
	return fallback_note + "[b]评分 %d / 100  等级 %s[/b]\n%s\n\n[b]亮点[/b] %s\n[b]改进[/b] %s\n[b]下一盘目标[/b] %s" % [
		int(result.get("score", 0)),
		str(result.get("grade", "")),
		str(result.get("headline", "")),
		str(result.get("praise", "")),
		str(result.get("improvement", "")),
		str(result.get("next_goal", "")),
	]


func _match_end_action_stats(scene: Object) -> Dictionary:
	var stats := {
		0: _empty_match_end_action_stats(),
		1: _empty_match_end_action_stats(),
	}
	var gsm: Variant = scene.get("_gsm")
	if gsm == null:
		return stats
	var action_log: Array = []
	if gsm.has_method("get_action_log"):
		var action_log_variant: Variant = gsm.call("get_action_log")
		if action_log_variant is Array:
			action_log = action_log_variant
	else:
		var raw_action_log: Variant = gsm.get("action_log")
		if raw_action_log is Array:
			action_log = raw_action_log
	for action_variant: Variant in action_log:
		if not (action_variant is GameAction):
			continue
		var action := action_variant as GameAction
		var player_index := action.player_index
		if player_index < 0 or player_index > 1:
			continue
		var player_stats: Dictionary = stats[player_index]
		match action.action_type:
			GameAction.ActionType.ATTACK:
				player_stats["attacks"] = int(player_stats.get("attacks", 0)) + 1
				var attack_damage := int(action.data.get("damage", 0))
				player_stats["max_damage"] = maxi(int(player_stats.get("max_damage", 0)), attack_damage)
			GameAction.ActionType.DAMAGE_DEALT:
				var damage := int(action.data.get("damage", 0))
				player_stats["damage_total"] = int(player_stats.get("damage_total", 0)) + damage
				player_stats["max_damage"] = maxi(int(player_stats.get("max_damage", 0)), damage)
			GameAction.ActionType.USE_ABILITY:
				player_stats["abilities"] = int(player_stats.get("abilities", 0)) + 1
			GameAction.ActionType.PLAY_TRAINER, GameAction.ActionType.PLAY_TOOL, GameAction.ActionType.PLAY_STADIUM:
				player_stats["trainers"] = int(player_stats.get("trainers", 0)) + 1
			GameAction.ActionType.ATTACH_ENERGY:
				player_stats["energy_attaches"] = int(player_stats.get("energy_attaches", 0)) + 1
			GameAction.ActionType.RETREAT:
				player_stats["retreats"] = int(player_stats.get("retreats", 0)) + 1
			GameAction.ActionType.KNOCKOUT:
				var scorer := 1 - player_index
				if stats.has(scorer):
					var scorer_stats: Dictionary = stats[scorer]
					scorer_stats["knockouts"] = int(scorer_stats.get("knockouts", 0)) + 1
			GameAction.ActionType.TAKE_PRIZE:
				player_stats["prizes_taken_by_action"] = int(player_stats.get("prizes_taken_by_action", 0)) + maxi(1, int(action.data.get("count", action.data.get("prize_count", 1))))
	for player_index: int in [0, 1]:
		var player_stats: Dictionary = stats[player_index]
		player_stats["tempo_actions"] = int(player_stats.get("trainers", 0)) + int(player_stats.get("abilities", 0)) + int(player_stats.get("energy_attaches", 0))
	return stats


func _empty_match_end_action_stats() -> Dictionary:
	return {
		"attacks": 0,
		"damage_total": 0,
		"max_damage": 0,
		"abilities": 0,
		"trainers": 0,
		"energy_attaches": 0,
		"retreats": 0,
		"knockouts": 0,
		"prizes_taken_by_action": 0,
		"tempo_actions": 0,
	}


func _match_end_player_summary(scene: Object, player_index: int, player_snapshot: Dictionary, action_summary: Dictionary) -> Dictionary:
	var prize_remaining := int(player_snapshot.get("prize_count", 0))
	var summary := action_summary.duplicate(true)
	summary["player_index"] = player_index
	summary["label"] = GameManager.resolve_battle_player_display_name(player_index)
	summary["prize_remaining"] = prize_remaining
	summary["prizes_taken"] = clampi(6 - prize_remaining, 0, 6)
	summary["hand_count"] = int(player_snapshot.get("hand_count", 0))
	summary["deck_count"] = int(player_snapshot.get("deck_count", 0))
	summary["discard_count"] = int(player_snapshot.get("discard_count", 0))
	var lost_zone_variant: Variant = player_snapshot.get("lost_zone", [])
	var lost_zone: Array = lost_zone_variant if lost_zone_variant is Array else []
	summary["lost_count"] = lost_zone.size()
	var bench_variant: Variant = player_snapshot.get("bench", [])
	var bench: Array = bench_variant if bench_variant is Array else []
	summary["bench_count"] = bench.size()
	summary["active"] = _match_end_active_text(player_snapshot.get("active", {}))
	return summary


func _match_end_active_text(active_variant: Variant) -> String:
	if not (active_variant is Dictionary):
		return "无战斗宝可梦"
	var active: Dictionary = active_variant
	var name := str(active.get("pokemon_name", "")).strip_edges()
	if name == "":
		return "无战斗宝可梦"
	return "%s HP %d/%d" % [name, int(active.get("remaining_hp", 0)), int(active.get("max_hp", 0))]


func _match_end_player_line(stats: Dictionary, alias: String) -> String:
	return "%s：奖赏%d/6，手牌%d，牌库%d，弃牌%d，备战%d；战斗区 %s" % [
		alias,
		int(stats.get("prizes_taken", 0)),
		int(stats.get("hand_count", 0)),
		int(stats.get("deck_count", 0)),
		int(stats.get("discard_count", 0)),
		int(stats.get("bench_count", 0)),
		str(stats.get("active", "")),
	]


func _match_end_takeaway(stats: Dictionary) -> String:
	var view_stats: Dictionary = stats.get("view_player", {})
	var opponent_stats: Dictionary = stats.get("opponent", {})
	if bool(stats.get("is_view_player_winner", false)):
		if int(view_stats.get("prizes_taken", 0)) >= 6:
			return "亮点：奖赏路线完成，终结回合兑现得很好。"
		return "亮点：胜利条件处理干净，保持了场面压力。"
	var prize_gap := int(opponent_stats.get("prizes_taken", 0)) - int(view_stats.get("prizes_taken", 0))
	if prize_gap >= 2:
		return "复盘重点：奖赏节奏落后，下一盘要更早规划第一次击倒。"
	return "复盘重点：差距不大，重点检查关键回合的资源顺序。"


func _match_end_title_text(stats: Dictionary) -> String:
	if bool(stats.get("is_view_player_winner", false)):
		return "胜利"
	return "再接再厉"


func _match_end_subtitle(_scene: Object, winner_index: int, view_player: int, turn_number: int) -> String:
	var winner_label := GameManager.resolve_battle_player_display_name(winner_index) if winner_index >= 0 else "无人"
	if winner_index == view_player:
		return "你在第 %d 回合赢下了这盘。" % turn_number
	return "%s 在第 %d 回合获胜。" % [winner_label, turn_number]


func _match_end_reason_text(reason: String) -> String:
	match reason:
		"knockout":
			return "击倒获胜"
		"deck_out":
			return "对手牌库无法抽牌"
		"拿完奖赏卡":
			return "拿完全部奖赏卡"
		"对手无宝可梦", "对手无宝可梦可派出":
			return "对手无宝可梦可派出"
		_:
			return reason


func _play_match_end_reveal(scene: Object) -> void:
	if not (scene is Node) or not (scene as Node).is_inside_tree():
		return
	var overlay: Panel = scene.get("_match_end_overlay")
	if overlay == null:
		return
	var box := overlay.get_node_or_null("MatchEndCenter/MatchEndBox") as Control
	if box == null:
		return
	box.pivot_offset = box.size * 0.5
	box.modulate = Color(1, 1, 1, 0)
	box.scale = Vector2(0.96, 0.96)
	var tween := (scene as Node).create_tween()
	tween.set_parallel(true)
	tween.tween_property(box, "modulate", Color(1, 1, 1, 1), 0.16)
	tween.tween_property(box, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _clear_children(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _match_end_overlay_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.015, 0.028, 0.76)
	return style


func _match_end_box_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.045, 0.064, 0.98)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 30
	style.shadow_offset = Vector2(0, 12)
	return style


func _match_end_inner_panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.065, 0.085, 0.88)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style


func _match_end_stat_card_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.028, 0.075, 0.095, 0.94)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
	style.shadow_size = 8
	return style


func _match_end_button_style(accent: Color, hover: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.30 if not pressed else 0.48)
	if hover and not pressed:
		style.bg_color = Color(accent.r, accent.g, accent.b, 0.40)
	style.border_color = accent
	style.set_border_width_all(2 if hover else 1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _match_end_button_disabled_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.06, 0.72)
	style.border_color = Color(0.20, 0.24, 0.28, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style
