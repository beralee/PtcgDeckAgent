extends RefCounted


static func on_back_pressed(scene: Control) -> void:
	if scene._is_field_interaction_active():
		return
	if scene._deck_training_controller != null:
		GameManager.clear_deck_training_launch()
		GameManager.goto_deck_training()
		return
	scene._pending_choice = "confirm_exit"
	scene._show_dialog("确认退出对战？当前进度不会保存。", ["确认退出", "取消"], {})
	scene._dialog_cancel.visible = false


static func on_zeus_help_pressed(scene: Control) -> void:
	if scene._deck_training_controller != null:
		if scene._is_field_interaction_active():
			return
		scene._deck_training_controller.show_stage_goal()
		return
	if not scene._can_view_player_start_turn_action() or scene._gsm == null or scene._gsm.game_state == null or scene._is_field_interaction_active():
		return
	if scene._view_player < 0 or scene._view_player >= scene._gsm.game_state.players.size():
		return
	# 输出双方卡牌总数到日志，方便验证不变量
	for pi: int in 2:
		var total: int = scene._gsm.count_player_total_cards(pi)
		scene._log("玩家%d卡牌总计: %d 张 (牌库%d 手牌%d 奖赏%d 弃牌%d 放逐%d 场上%d)" % [
			pi + 1,
			total,
			scene._gsm.game_state.players[pi].deck.size(),
			scene._gsm.game_state.players[pi].hand.size(),
			scene._gsm.game_state.players[pi].prizes.size(),
			scene._gsm.game_state.players[pi].discard_pile.size(),
			scene._gsm.game_state.players[pi].lost_zone.size(),
			total - scene._gsm.game_state.players[pi].deck.size() - scene._gsm.game_state.players[pi].hand.size() - scene._gsm.game_state.players[pi].prizes.size() - scene._gsm.game_state.players[pi].discard_pile.size() - scene._gsm.game_state.players[pi].lost_zone.size(),
		])
	var player: PlayerState = scene._gsm.game_state.players[scene._view_player]
	var deck_cards: Array = player.deck.duplicate()
	if deck_cards.is_empty():
		scene._log("当前牌库为空。")
		return
	var labels: Array[String] = []
	for card: CardInstance in deck_cards:
		labels.append(card.card_data.name if card != null and card.card_data != null else "未知卡牌")
	scene._pending_choice = "zeus_help"
	scene._show_dialog("宙斯帮我：从牌库中选择任意张牌加入手牌", labels, {
		"player": scene._view_player,
		"min_select": 0,
		"max_select": deck_cards.size(),
		"allow_cancel": true,
		"presentation": "cards",
		"card_items": deck_cards,
		"deck_cards": deck_cards,
		"choice_labels": labels,
	})


static func on_opponent_hand_pressed(scene: Control) -> void:
	if scene._gsm == null or scene._gsm.game_state == null:
		return
	if GameManager.current_mode not in [
		GameManager.GameMode.VS_AI,
		GameManager.GameMode.VS_AUTHOR_STRATEGY_AI,
	]:
		return
	scene._show_opponent_hand_cards()
