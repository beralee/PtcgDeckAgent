class_name TestDeckDiscussionDialog
extends TestBase

const DialogScene := preload("res://scenes/deck_editor/DeckDiscussionDialog.tscn")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")


func test_dialog_instantiates_and_accepts_deck_context() -> String:
	var dialog := DialogScene.instantiate()
	var deck := DeckData.new()
	deck.id = 900001
	deck.deck_name = "讨论测试卡组"
	deck.total_cards = 60
	deck.cards = [
		{"set_code": "SV1", "card_index": "001", "count": 8, "card_type": "Pokemon", "name": "基础宝可梦"},
		{"set_code": "SV1", "card_index": "050", "count": 12, "card_type": "Basic Energy", "name": "能量"},
	]

	dialog.call("setup_for_deck", deck)
	var deck_name_label := dialog.get_node_or_null("%DeckNameLabel")
	var summary_label := dialog.get_node_or_null("%SummaryLabel")
	var question_input := dialog.get_node_or_null("%QuestionInput")
	var input_panel := dialog.get_node_or_null("%InputPanel")
	var transcript_list := dialog.get_node_or_null("%TranscriptList")
	var transcript_scroll := dialog.get_node_or_null("%TranscriptScroll")
	var suggestions_panel := dialog.get_node_or_null("%SuggestionsPanel")
	var header_panel := dialog.get_node_or_null("%HeaderPanel")
	var deck_art_panel := dialog.get_node_or_null("%DeckArtPanel")
	var title_label := dialog.get_node_or_null("%TitleLabel")
	var clamped_position: Vector2i = dialog.call("_clamp_dialog_position", Vector2i(-1000, -1000))
	var first_bubble_width := 0.0
	var first_has_ai_avatar := false
	var input_panel_height := 0.0
	var header_height := 0.0
	var header_bottom := 0.0
	var transcript_top := 0.0
	var transcript_bottom_with_suggestions := 0.0
	var suggestions_visible := false
	if transcript_list != null and transcript_list.get_child_count() > 0:
		var row := transcript_list.get_child(0)
		first_has_ai_avatar = row.get_child_count() > 0 and row.get_child(0) is PanelContainer
		for child: Node in row.get_children():
			if not (child is PanelContainer):
				continue
			var panel := child as PanelContainer
			if panel.get_child_count() > 0 and panel.get_child(0) is VBoxContainer:
				first_bubble_width = panel.custom_minimum_size.x
				break
	if input_panel != null:
		input_panel_height = (input_panel as Control).custom_minimum_size.y
	if header_panel != null:
		header_height = (header_panel as Control).offset_bottom - (header_panel as Control).offset_top
		header_bottom = (header_panel as Control).offset_bottom
	if transcript_scroll != null:
		transcript_top = (transcript_scroll as Control).offset_top
	var suggestions: Array[String] = ["洗翠沉重球有多大必要性？", "这张牌能换掉吗？"]
	dialog.call("_refresh_suggestion_buttons", suggestions)
	var empty_suggestions: Array[String] = []
	dialog.call("_refresh_suggestion_buttons", empty_suggestions, true)
	if transcript_scroll != null:
		transcript_bottom_with_suggestions = (transcript_scroll as Control).offset_bottom
	if suggestions_panel != null:
		suggestions_visible = (suggestions_panel as Control).visible
	dialog.queue_free()

	return run_checks([
		assert_not_null(deck_name_label, "对话框应包含卡组名标签"),
		assert_not_null(summary_label, "对话框应包含摘要标签"),
		assert_not_null(question_input, "对话框应包含固定底部输入框"),
		assert_true((title_label as Label).text.contains("探讨"), "标题应显示当前模型探讨文案"),
		assert_eq(clamped_position, Vector2i.ZERO, "对话框拖动位置应被限制在可见窗口内"),
		assert_eq((deck_name_label as Label).text, "讨论测试卡组", "应显示当前卡组名"),
		assert_true((summary_label as Label).text.contains("60张"), "摘要应包含基础统计"),
		assert_false((summary_label as Label).visible, "卡组编辑页的 AI 探讨应隐藏摘要，和对战时保持一致的紧凑 UI"),
		assert_true(header_height <= 76.0, "顶部卡组信息区域应使用对战式紧凑高度"),
		assert_true(transcript_top >= header_bottom + 12.0, "聊天滚动区不能和顶部卡组信息区域重叠"),
		assert_false((deck_art_panel as Control).visible, "顶部不应显示大 AI 头像方框"),
		assert_true(first_has_ai_avatar, "AI 头像应显示在 AI 气泡左侧"),
		assert_true(first_bubble_width >= 300.0, "消息气泡应有稳定横向宽度，避免每个字竖排换行"),
		assert_true(input_panel_height >= 130.0, "输入面板应保留足够高度，不能被聊天记录挤出屏幕"),
		assert_true(suggestions_visible, "生成结束时若没有新追问，应保留上一组三个追问按钮"),
		assert_true(transcript_bottom_with_suggestions <= -200.0, "聊天滚动区应为单行追问按钮预留底部空间"),
	])


func test_match_discussion_uses_compact_battle_style_header() -> String:
	var dialog := DialogScene.instantiate()
	var player_deck := DeckData.new()
	player_deck.id = 900101
	player_deck.deck_name = "玩家测试牌"
	player_deck.total_cards = 60
	var opponent_deck := DeckData.new()
	opponent_deck.id = 900202
	opponent_deck.deck_name = "对手测试牌"
	opponent_deck.total_cards = 60

	dialog.call("setup_for_match", player_deck, opponent_deck, "AI 卡组", 900101202, true)
	var deck_name_label := dialog.get_node_or_null("%DeckNameLabel") as Label
	var summary_label := dialog.get_node_or_null("%SummaryLabel") as Label
	var header_panel := dialog.get_node_or_null("%HeaderPanel") as Control
	var transcript_scroll := dialog.get_node_or_null("%TranscriptScroll") as Control
	var header_bottom := header_panel.offset_bottom if header_panel != null else 0.0
	var transcript_top := transcript_scroll.offset_top if transcript_scroll != null else 0.0
	dialog.queue_free()

	return run_checks([
		assert_not_null(deck_name_label, "Match discussion should keep the matchup title label"),
		assert_true(deck_name_label.text.contains("玩家测试牌") and deck_name_label.text.contains("对手测试牌"), "Match discussion should show both decks in the title line"),
		assert_not_null(summary_label, "Match discussion should still keep the summary node for other modes"),
		assert_false(summary_label.visible, "Battle setup strategy discussion should hide deck summary stats to free vertical space"),
		assert_true(header_bottom <= 126.0, "Battle setup strategy discussion should use the compact battle header height"),
		assert_true(transcript_top <= 144.0, "Battle setup strategy discussion transcript should start immediately below the compact header"),
	])


func test_non_battle_portrait_discussion_hides_transcript_scrollbar() -> String:
	var dialog := DialogScene.instantiate()
	var player_deck := DeckData.new()
	player_deck.id = 900111
	player_deck.deck_name = "Non battle player"
	player_deck.total_cards = 60
	var opponent_deck := DeckData.new()
	opponent_deck.id = 900222
	opponent_deck.deck_name = "Non battle opponent"
	opponent_deck.total_cards = 60

	dialog.call("setup_for_match", player_deck, opponent_deck, "AI Deck", 900111222, true)
	dialog.call("prepare_for_portrait_popup", Rect2(Vector2.ZERO, Vector2(390, 844)))
	var transcript_scroll := dialog.get_node_or_null("%TranscriptScroll") as ScrollContainer
	var vbar := transcript_scroll.get_v_scroll_bar() if transcript_scroll != null else null
	var send_button := dialog.get_node_or_null("%SendButton") as Button
	var hidden_meta := transcript_scroll != null and bool(transcript_scroll.get_meta(NonBattleTouchBridgeScript.HIDDEN_VERTICAL_DRAG_SCROLL_META, false))
	var hidden_bar := vbar != null and not vbar.visible and vbar.mouse_filter == Control.MOUSE_FILTER_IGNORE
	var bridge_enabled := send_button != null and bool(NonBattleTouchBridgeScript.is_touch_bridge_enabled_for(send_button))
	dialog.queue_free()

	return run_checks([
		assert_true(hidden_meta, "Non-battle portrait deck discussion should use hidden drag scrolling"),
		assert_true(hidden_bar, "Non-battle portrait deck discussion should hide the transcript scrollbar"),
		assert_true(bridge_enabled, "Non-battle portrait deck discussion should keep the non-battle touch bridge enabled"),
	])


func test_live_battle_portrait_discussion_keeps_visible_touch_scrollbar() -> String:
	var dialog := DialogScene.instantiate()
	var deck := DeckData.new()
	deck.id = 900333
	deck.deck_name = "Live battle deck"
	deck.total_cards = 60
	var battle_context := {
		"perspective_label": "Player 1 / Live battle",
		"state": {"turn_number": 1, "phase": "MAIN", "current_player_index": 0},
		"public_counts": {},
	}

	dialog.call("setup_for_battle_context", deck, battle_context, 900333001, true)
	dialog.call("prepare_for_portrait_popup", Rect2(Vector2.ZERO, Vector2(390, 844)))
	var transcript_scroll := dialog.get_node_or_null("%TranscriptScroll") as ScrollContainer
	var vbar := transcript_scroll.get_v_scroll_bar() if transcript_scroll != null else null
	var send_button := dialog.get_node_or_null("%SendButton") as Button
	var hidden_meta := transcript_scroll != null and bool(transcript_scroll.get_meta(NonBattleTouchBridgeScript.HIDDEN_VERTICAL_DRAG_SCROLL_META, false))
	var profile := str(vbar.get_meta("hud_scrollbar_profile", "")) if vbar != null else ""
	var bridge_enabled := send_button != null and bool(NonBattleTouchBridgeScript.is_touch_bridge_enabled_for(send_button))
	dialog.queue_free()

	return run_checks([
		assert_false(hidden_meta, "Live battle portrait discussion should keep the battle scrollbar policy"),
		assert_eq(profile, "portrait_touch", "Live battle portrait discussion scrollbar should still use the large battle touch profile"),
		assert_false(bridge_enabled, "Live battle portrait discussion should disable the non-battle touch bridge"),
	])


func test_portrait_discussion_profile_fits_phone_touch_layout() -> String:
	var dialog := DialogScene.instantiate()
	var deck := DeckData.new()
	deck.id = 900301
	deck.deck_name = "竖屏对战测试牌"
	deck.total_cards = 60
	deck.cards = [
		{"set_code": "SV1", "card_index": "001", "count": 8, "card_type": "Pokemon", "name": "基础宝可梦"},
	]
	var battle_context := {
		"perspective_label": "玩家1 / 竖屏对战测试牌",
		"state": {"turn_number": 2, "phase": "MAIN", "current_player_index": 0, "acting_side_from_perspective": "me"},
		"public_counts": {"prize_remaining_score": "6-6", "prizes_taken_score": "0-0", "my_hand_count": 4, "my_deck_count": 42, "opponent_hand_count": 5, "opponent_deck_count": 41},
	}

	dialog.call("setup_for_battle_context", deck, battle_context, 900301001, true)
	var popup_rect: Rect2i = dialog.call("prepare_for_portrait_popup", Rect2(Vector2.ZERO, Vector2(390, 844)))
	var suggestions: Array[String] = ["这回合应该先进攻还是铺场？", "支援者要不要现在用？"]
	dialog.call("_refresh_suggestion_buttons", suggestions)
	dialog.call("_apply_visual_style")
	var transcript_list := dialog.get_node_or_null("%TranscriptList") as VBoxContainer
	var title_label := dialog.get_node_or_null("%TitleLabel") as Label
	var deck_name_label := dialog.get_node_or_null("%DeckNameLabel") as Label
	var question_input := dialog.get_node_or_null("%QuestionInput") as TextEdit
	var attach_button := dialog.get_node_or_null("%AttachButton") as Button
	var reset_button := dialog.get_node_or_null("%ResetButton") as Button
	var send_button := dialog.get_node_or_null("%SendButton") as Button
	var transcript_scroll := dialog.get_node_or_null("%TranscriptScroll") as Control
	var input_panel := dialog.get_node_or_null("%InputPanel") as Control
	var suggestions_panel := dialog.get_node_or_null("%SuggestionsPanel") as Control
	var stacked_actions := dialog.get_node_or_null("Root/InputPanel/InputVBox/Actions") as HBoxContainer
	var composer_actions := dialog.get_node_or_null("Root/InputPanel/InputVBox/ComposerRow/Actions") as HBoxContainer
	var dialog_size: Vector2i = dialog.size
	var dialog_min_size: Vector2i = dialog.min_size
	var action_total_width := 0.0
	if send_button != null and reset_button != null and composer_actions != null:
		action_total_width = send_button.custom_minimum_size.x + reset_button.custom_minimum_size.x + float(composer_actions.get_theme_constant("separation"))
	var first_bubble_width := 0.0
	var first_body_font := 0
	if transcript_list != null and transcript_list.get_child_count() > 0:
		var row := transcript_list.get_child(0) as HBoxContainer
		if row != null:
			for child: Node in row.get_children():
				var panel := child as PanelContainer
				if panel == null or panel.get_child_count() <= 0 or not (panel.get_child(0) is VBoxContainer):
					continue
				first_bubble_width = panel.custom_minimum_size.x
				var body := dialog.call("_find_message_body_in_row", row) as RichTextLabel
				first_body_font = body.get_theme_font_size("normal_font_size") if body != null else 0
				break
	dialog.queue_free()

	return run_checks([
		assert_true(popup_rect.size.x <= 390, "Portrait discussion popup should fit a phone-width frame"),
		assert_true(popup_rect.size.y <= 844, "Portrait discussion popup should fit a phone-height frame"),
		assert_true(popup_rect.size.y >= int(round(844.0 * 0.66)), "Portrait discussion popup should visibly apply the 10 percent taller mobile profile"),
		assert_true(popup_rect.size.y <= int(round(844.0 * 0.70)), "Portrait discussion popup should stay below a full-height mobile sheet after the increase"),
		assert_true(dialog_min_size.x <= dialog_size.x and dialog_min_size.y <= dialog_size.y, "Portrait discussion min size should not force desktop dimensions"),
		assert_true(title_label != null and title_label.get_theme_font_size("font_size") >= 34, "Portrait discussion title should match the mobile battle UI scale"),
		assert_true(deck_name_label != null and deck_name_label.get_theme_font_size("font_size") >= 28, "Portrait discussion deck label should be touch-readable"),
		assert_true(question_input != null and question_input.get_theme_font_size("font_size") >= 34, "Portrait discussion input should be touch-readable"),
		assert_true(question_input != null and question_input.custom_minimum_size.y >= 150.0, "Portrait discussion input should reserve enough height for readable mobile typing"),
		assert_true(send_button != null and send_button.custom_minimum_size.x >= 80.0 and send_button.custom_minimum_size.x <= 96.0, "Portrait discussion send button should use a readable right-side touch width"),
		assert_true(send_button != null and send_button.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Portrait discussion send button should fill its right-side action cell"),
		assert_true(send_button != null and send_button.custom_minimum_size.y >= 150.0, "Portrait discussion send button should match the input box height on the right side"),
		assert_true(send_button != null and send_button.get_theme_font_size("font_size") >= 36, "Portrait discussion send text should remain readable after visual styles are applied"),
		assert_true(send_button != null and send_button.alignment == HORIZONTAL_ALIGNMENT_CENTER and not send_button.clip_text, "Portrait discussion send text should stay centered and unclipped in the right-side button"),
		assert_true(reset_button != null and reset_button.custom_minimum_size.x >= 80.0 and reset_button.custom_minimum_size.x <= 96.0, "Portrait discussion reset button should use a readable right-side touch width"),
		assert_true(reset_button != null and reset_button.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Portrait discussion reset button should fill its right-side action cell"),
		assert_true(reset_button != null and reset_button.custom_minimum_size.y >= 150.0, "Portrait discussion reset button should match the input box height on the right side"),
		assert_true(reset_button != null and reset_button.get_theme_font_size("font_size") >= 34, "Portrait discussion reset text should remain readable after visual styles are applied"),
		assert_true(reset_button != null and reset_button.alignment == HORIZONTAL_ALIGNMENT_CENTER and not reset_button.clip_text, "Portrait discussion reset text should stay centered and unclipped in the right-side button"),
		assert_eq(reset_button.text if reset_button != null else "", "清空", "Portrait discussion reset button should use short text so the enlarged send button fits the phone width"),
		assert_null(stacked_actions, "Portrait discussion should not move action buttons below the input field"),
		assert_not_null(composer_actions, "Portrait discussion should keep action buttons on the right side of the input field"),
		assert_true(composer_actions != null and composer_actions.custom_minimum_size.x >= 170.0 and composer_actions.custom_minimum_size.x <= 184.0, "Portrait discussion right-side action area should reserve room for both buttons"),
		assert_true(composer_actions != null and action_total_width >= composer_actions.custom_minimum_size.x - 1.0 and action_total_width <= composer_actions.custom_minimum_size.x + 1.0, "Portrait discussion action buttons should fill the right-side action area"),
		assert_true(attach_button != null and not attach_button.visible, "Portrait discussion should hide the unused attach affordance to preserve input width"),
		assert_true(first_bubble_width >= 240.0 and first_bubble_width <= 310.0, "Portrait discussion bubbles should fit beside the avatar without vertical text wrapping"),
		assert_true(first_body_font >= 30, "Portrait discussion message body should use mobile-scaled text"),
		assert_true(transcript_scroll != null and input_panel != null and transcript_scroll.offset_bottom <= input_panel.offset_top - 8.0, "Portrait transcript should not overlap the composer"),
		assert_true(suggestions_panel != null and suggestions_panel.visible, "Portrait discussion should keep generated follow-up suggestions visible when the horizontal composer leaves enough space"),
	])


func test_portrait_discussion_profile_scales_for_android_logical_canvas() -> String:
	var dialog := DialogScene.instantiate()
	var deck := DeckData.new()
	deck.id = 900302
	deck.deck_name = "Android portrait test deck"
	deck.total_cards = 60
	deck.cards = [
		{"set_code": "SV1", "card_index": "001", "count": 8, "card_type": "Pokemon", "name": "Basic Pokemon"},
	]
	var battle_context := {
		"perspective_label": "Player 1 / Android portrait",
		"state": {"turn_number": 3, "phase": "MAIN", "current_player_index": 0, "acting_side_from_perspective": "me"},
		"public_counts": {"prize_remaining_score": "6-6", "prizes_taken_score": "0-0", "my_hand_count": 5, "my_deck_count": 40, "opponent_hand_count": 4, "opponent_deck_count": 42},
	}

	dialog.call("setup_for_battle_context", deck, battle_context, 900302001, true)
	var popup_rect: Rect2i = dialog.call("prepare_for_portrait_popup", Rect2(Vector2.ZERO, Vector2(1600, 2844)))
	var title_label := dialog.get_node_or_null("%TitleLabel") as Label
	var deck_name_label := dialog.get_node_or_null("%DeckNameLabel") as Label
	var question_input := dialog.get_node_or_null("%QuestionInput") as TextEdit
	var reset_button := dialog.get_node_or_null("%ResetButton") as Button
	var send_button := dialog.get_node_or_null("%SendButton") as Button
	var input_panel := dialog.get_node_or_null("%InputPanel") as Control
	var transcript_scroll := dialog.get_node_or_null("%TranscriptScroll") as Control
	var stacked_actions := dialog.get_node_or_null("Root/InputPanel/InputVBox/Actions") as HBoxContainer
	var composer_actions := dialog.get_node_or_null("Root/InputPanel/InputVBox/ComposerRow/Actions") as HBoxContainer
	var body: RichTextLabel = null
	var transcript_list := dialog.get_node_or_null("%TranscriptList") as VBoxContainer
	if transcript_list != null and transcript_list.get_child_count() > 0:
		var row := transcript_list.get_child(0) as HBoxContainer
		if row != null:
			body = dialog.call("_find_message_body_in_row", row) as RichTextLabel
	var body_font := body.get_theme_font_size("normal_font_size") if body != null else 0
	var dialog_min_size: Vector2i = dialog.min_size
	var dialog_size: Vector2i = dialog.size
	dialog.queue_free()

	return run_checks([
		assert_true(popup_rect.size.x <= 1600 and popup_rect.size.y <= 2844, "Android portrait discussion popup should stay inside the logical canvas"),
		assert_true(popup_rect.size.y >= int(round(2844.0 * 0.66)), "Android portrait discussion popup should apply the taller portrait profile"),
		assert_true(popup_rect.size.y <= int(round(2844.0 * 0.70)), "Android portrait discussion popup should remain a centered dialog after the height increase"),
		assert_true(dialog_min_size.x <= dialog_size.x and dialog_min_size.y <= dialog_size.y, "Android portrait discussion min size should not force desktop dimensions"),
		assert_true(title_label != null and title_label.get_theme_font_size("font_size") >= 60, "Android portrait discussion title should scale with battle top buttons"),
		assert_true(deck_name_label != null and deck_name_label.get_theme_font_size("font_size") >= 49, "Android portrait discussion deck label should scale with the phone canvas"),
		assert_true(body_font >= 53, "Android portrait discussion message body should scale beyond desktop text"),
		assert_true(question_input != null and question_input.get_theme_font_size("font_size") >= 53, "Android portrait discussion input should scale beyond desktop text"),
		assert_true(question_input != null and question_input.custom_minimum_size.y >= 270.0, "Android portrait discussion input box should keep a readable multiline touch target beside the enlarged action buttons"),
		assert_true(send_button != null and send_button.custom_minimum_size.y >= 270.0, "Android portrait discussion send button should match the scaled input height"),
		assert_true(send_button != null and send_button.custom_minimum_size.x >= 140.0 and send_button.custom_minimum_size.x <= 150.0, "Android portrait discussion send button should stay in the right-side action area"),
		assert_true(send_button != null and send_button.get_theme_font_size("font_size") >= 60, "Android portrait discussion send text should scale with the right-side button"),
		assert_true(reset_button != null and reset_button.custom_minimum_size.y >= 270.0, "Android portrait discussion reset button should match the scaled input height"),
		assert_null(stacked_actions, "Android portrait discussion should not stack action buttons below the input field"),
		assert_not_null(composer_actions, "Android portrait discussion should keep action buttons beside the text input"),
		assert_true(transcript_scroll != null and input_panel != null and transcript_scroll.offset_bottom <= input_panel.offset_top - 12.0, "Android portrait transcript should leave room for the scaled composer"),
	])


func test_portrait_discussion_buttons_survive_deferred_window_resize() -> String:
	var dialog := DialogScene.instantiate()
	var deck := DeckData.new()
	deck.id = 900303
	deck.deck_name = "Deferred portrait test deck"
	deck.total_cards = 60
	var battle_context := {
		"perspective_label": "Player 1 / deferred portrait",
		"state": {"turn_number": 1, "phase": "MAIN", "current_player_index": 0, "acting_side_from_perspective": "me"},
		"public_counts": {"prize_remaining_score": "6-6", "prizes_taken_score": "0-0", "my_hand_count": 5, "my_deck_count": 45, "opponent_hand_count": 5, "opponent_deck_count": 45},
	}

	dialog.call("setup_for_battle_context", deck, battle_context, 900303001, true)
	dialog.call("prepare_for_portrait_popup", Rect2(Vector2.ZERO, Vector2(390, 844)))
	dialog.call("_apply_fixed_window_size")
	var send_button := dialog.get_node_or_null("%SendButton") as Button
	var reset_button := dialog.get_node_or_null("%ResetButton") as Button
	var actions := dialog.get_node_or_null("Root/InputPanel/InputVBox/ComposerRow/Actions") as BoxContainer
	var total_action_width := 0.0
	if send_button != null and reset_button != null and actions != null:
		total_action_width = send_button.custom_minimum_size.x + reset_button.custom_minimum_size.x + float(actions.get_theme_constant("separation"))
	var root := dialog.get_node_or_null("Root") as Control
	var available_width := float(dialog.size.x) - (root.offset_left - root.offset_right if root != null else 0.0)
	dialog.queue_free()

	return run_checks([
		assert_true(send_button != null and send_button.custom_minimum_size.x >= 80.0 and send_button.custom_minimum_size.y == 154.0, "Deferred fixed-window pass should preserve the right-side portrait send button"),
		assert_true(send_button != null and send_button.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Deferred fixed-window pass should preserve action-cell expansion for send"),
		assert_true(reset_button != null and reset_button.custom_minimum_size.x >= 80.0 and reset_button.custom_minimum_size.y == 154.0, "Deferred fixed-window pass should preserve the right-side portrait reset button"),
		assert_true(reset_button != null and reset_button.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Deferred fixed-window pass should preserve action-cell expansion for reset"),
		assert_true(send_button != null and send_button.get_theme_font_size("font_size") >= 36, "Deferred fixed-window pass should preserve the readable portrait send font"),
		assert_true(reset_button != null and reset_button.text == "清空", "Deferred fixed-window pass should keep the short portrait reset label"),
		assert_true(total_action_width > 0.0 and total_action_width <= available_width, "Portrait action buttons should fit within the phone dialog width instead of being squeezed"),
	])


func test_portrait_discussion_question_input_uses_native_android_text_path() -> String:
	var dialog := DialogScene.instantiate()
	dialog.call("_ready")
	NonBattleTouchBridgeScript.bind_buttons_recursive(dialog)
	var question_input := dialog.get_node_or_null("%QuestionInput") as TextEdit
	var focus_bridge_bound := question_input != null and bool(question_input.get_meta(NonBattleTouchBridgeScript.FOCUS_TOUCH_BOUND_META, false))
	dialog.queue_free()

	return run_checks([
		assert_true(question_input != null and question_input.mouse_filter == Control.MOUSE_FILTER_STOP, "Portrait discussion question input should still own native TextEdit hit testing"),
		assert_false(focus_bridge_bound, "Portrait discussion question input should not install the non-battle focus touch bridge that can swallow Android text editing taps"),
	])


func test_portrait_discussion_keyboard_inset_keeps_action_buttons_touchable() -> String:
	var dialog := DialogScene.instantiate()
	var deck := DeckData.new()
	deck.id = 900304
	deck.deck_name = "Keyboard inset test deck"
	deck.total_cards = 60
	var battle_context := {
		"perspective_label": "Player 1 / keyboard inset",
		"state": {"turn_number": 1, "phase": "MAIN", "current_player_index": 0, "acting_side_from_perspective": "me"},
		"public_counts": {"prize_remaining_score": "6-6", "prizes_taken_score": "0-0", "my_hand_count": 5, "my_deck_count": 45, "opponent_hand_count": 5, "opponent_deck_count": 45},
	}

	dialog.call("setup_for_battle_context", deck, battle_context, 900304001, true)
	var full_frame := Rect2(Vector2.ZERO, Vector2(390, 844))
	dialog.call("prepare_for_portrait_popup", full_frame)
	if not dialog.has_method("apply_portrait_keyboard_inset"):
		dialog.queue_free()
		return "Portrait discussion dialog should expose a keyboard inset layout handler"
	var keyboard_height := 320.0
	var popup_rect: Rect2i = dialog.call("apply_portrait_keyboard_inset", keyboard_height)
	var keyboard_top := full_frame.size.y - keyboard_height
	var send_button := dialog.get_node_or_null("%SendButton") as Button
	var reset_button := dialog.get_node_or_null("%ResetButton") as Button
	var root := dialog.get_node_or_null("Root") as Control
	var root_bottom := float(popup_rect.position.y) + float(popup_rect.size.y) - (root.offset_bottom * -1.0 if root != null else 0.0)
	var send_bottom := float(popup_rect.position.y) + float(popup_rect.size.y)
	var reset_bottom := send_bottom
	if send_button != null:
		send_bottom = float(popup_rect.position.y) + float(popup_rect.size.y) + send_button.offset_bottom
	if reset_button != null:
		reset_bottom = float(popup_rect.position.y) + float(popup_rect.size.y) + reset_button.offset_bottom
	dialog.queue_free()

	return run_checks([
		assert_true(popup_rect.size.x <= 390 and popup_rect.end.y <= int(keyboard_top), "Portrait discussion popup should move above the Android soft keyboard"),
		assert_true(root_bottom <= keyboard_top, "Portrait discussion root should stay above the keyboard-covered area"),
		assert_true(send_button != null and send_bottom <= keyboard_top, "Portrait discussion send button should remain touchable above the keyboard"),
		assert_true(reset_button != null and reset_bottom <= keyboard_top, "Portrait discussion reset button should remain touchable above the keyboard"),
	])


func test_portrait_discussion_reset_recovers_busy_input_lock() -> String:
	var dialog := DialogScene.instantiate()
	var deck := DeckData.new()
	deck.id = 900305
	deck.deck_name = "Busy reset test deck"
	deck.total_cards = 60
	dialog.call("setup_for_deck", deck)
	var service = dialog.get("_service")
	var send_button := dialog.get_node_or_null("%SendButton") as Button
	var question_input := dialog.get_node_or_null("%QuestionInput") as TextEdit
	if service != null:
		service.set("_busy", true)
	if send_button != null:
		send_button.disabled = true
	if question_input != null:
		question_input.text = "stuck question"

	dialog.call("_on_reset_pressed")
	var busy_after_reset := bool(service.call("is_busy")) if service != null and service.has_method("is_busy") else true
	var input_text := question_input.text if question_input != null else ""
	dialog.queue_free()

	return run_checks([
		assert_false(busy_after_reset, "Discussion reset should cancel a stuck in-flight request so the dialog is usable again"),
		assert_true(send_button != null and not send_button.disabled, "Discussion reset should re-enable Send after a stuck request"),
		assert_eq(input_text, "", "Discussion reset should clear the current typed question"),
	])


func test_live_battle_portrait_discussion_does_not_auto_focus_android_input() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return "SceneTree root should be available for the battle portrait discussion focus test"
	var dialog := DialogScene.instantiate()
	tree.root.add_child(dialog)
	var deck := DeckData.new()
	deck.id = 900306
	deck.deck_name = "Battle portrait focus test deck"
	deck.total_cards = 60
	var battle_context := {
		"perspective_label": "Player 1 / Android focus",
		"state": {"turn_number": 1, "phase": "MAIN", "current_player_index": 0, "acting_side_from_perspective": "me"},
		"public_counts": {"prize_remaining_score": "6-6", "prizes_taken_score": "0-0", "my_hand_count": 5, "my_deck_count": 45, "opponent_hand_count": 5, "opponent_deck_count": 45},
	}
	dialog.call("setup_for_battle_context", deck, battle_context, 900306001, true)
	dialog.call("prepare_for_portrait_popup", Rect2(Vector2.ZERO, Vector2(390, 844)))
	dialog.call("_deferred_grab_question_focus")
	var question_input := dialog.get_node_or_null("%QuestionInput") as TextEdit
	var has_focus := question_input != null and question_input.has_focus()
	var exposes_policy := dialog.has_method("_should_auto_focus_question_input")
	var allows_auto_focus := bool(dialog.call("_should_auto_focus_question_input")) if exposes_policy else true
	dialog.queue_free()

	return run_checks([
		assert_true(exposes_policy, "Discussion dialog should expose a testable auto-focus policy for Android portrait regressions"),
		assert_false(allows_auto_focus, "Live battle portrait AI discussion should disable open-time TextEdit auto-focus"),
		assert_false(has_focus, "Live battle portrait AI discussion should not auto-focus TextEdit and open Android keyboard before the HUD is visible"),
	])


func test_live_battle_portrait_discussion_does_not_route_buttons_through_non_battle_touch_bridge() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return "SceneTree root should be available for the battle portrait discussion touch bridge test"
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var dialog := DialogScene.instantiate()
	tree.root.add_child(dialog)
	var deck := DeckData.new()
	deck.id = 900307
	deck.deck_name = "Battle portrait touch bridge test deck"
	deck.total_cards = 60
	var battle_context := {
		"perspective_label": "Player 1 / Android touch bridge",
		"state": {"turn_number": 1, "phase": "MAIN", "current_player_index": 0, "acting_side_from_perspective": "me"},
		"public_counts": {"prize_remaining_score": "6-6", "prizes_taken_score": "0-0", "my_hand_count": 5, "my_deck_count": 45, "opponent_hand_count": 5, "opponent_deck_count": 45},
	}
	dialog.call("setup_for_battle_context", deck, battle_context, 900307001, true)
	dialog.call("prepare_for_portrait_popup", Rect2(Vector2.ZERO, Vector2(390, 844)))
	NonBattleTouchBridgeScript.bind_buttons_recursive(dialog)
	var send_button := dialog.get_node_or_null("%SendButton") as Button
	var bridge_press_count := [0]
	if send_button != null:
		send_button.pressed.connect(func() -> void:
			bridge_press_count[0] = int(bridge_press_count[0]) + 1
		)
		var touch_press := InputEventScreenTouch.new()
		touch_press.pressed = true
		send_button.gui_input.emit(touch_press)
		var touch_release := InputEventScreenTouch.new()
		touch_release.pressed = false
		send_button.gui_input.emit(touch_release)
	var had_bound_bridge := send_button != null and bool(send_button.get_meta(NonBattleTouchBridgeScript.BUTTON_TOUCH_BOUND_META, false))
	dialog.queue_free()
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)

	return run_checks([
		assert_true(had_bound_bridge, "Discussion buttons should still be covered by the shared binding path so this test catches context policy regressions"),
		assert_eq(int(bridge_press_count[0]), 0, "Live battle portrait AI discussion must not let the non-battle touch bridge manually emit Button.pressed"),
	])
