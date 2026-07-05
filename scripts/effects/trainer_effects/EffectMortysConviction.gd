class_name EffectMortysConviction
extends BaseEffect

const DISCARD_STEP_ID := "discard_card"


func can_execute(card: CardInstance, state: GameState) -> bool:
	if card == null or state == null:
		return false
	var player_index := card.owner_index
	if player_index < 0 or player_index >= state.players.size():
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return false
	var player: PlayerState = state.players[player_index]
	var opponent: PlayerState = state.players[opponent_index]
	return not _discard_candidates(player, card).is_empty() and not player.deck.is_empty() and not opponent.bench.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	return can_execute(card, state)


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if not can_execute(card, state):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var items := _discard_candidates(player, card)
	var labels: Array[String] = []
	for hand_card: CardInstance in items:
		labels.append(hand_card.card_data.name if hand_card.card_data != null else "")
	return [{
		"id": DISCARD_STEP_ID,
		"title": "选择1张手牌放于弃牌区",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	if card == null or state == null:
		return
	var player_index := card.owner_index
	if player_index < 0 or player_index >= state.players.size():
		return
	var player: PlayerState = state.players[player_index]
	var discard_card := _resolve_discard_card(player, card, get_interaction_context(targets))
	if discard_card == null:
		return
	_discard_cards_from_hand_with_log(state, player_index, [discard_card], card, "trainer")
	_draw_cards_with_log(state, player_index, _opponent_bench_count(card, state), card, "trainer")


func get_unusable_reason(card: CardInstance, state: GameState) -> String:
	if card == null or state == null:
		return "当前无法使用这张卡。"
	var player_index := card.owner_index
	if player_index < 0 or player_index >= state.players.size():
		return "当前玩家无效，不能使用这张卡。"
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return "当前无法找到对手。"
	var player: PlayerState = state.players[player_index]
	if _discard_candidates(player, card).is_empty():
		return "需要先有1张其他手牌可放入弃牌区。"
	if player.deck.is_empty():
		return "自己的牌库没有可抽取的卡牌。"
	if state.players[opponent_index].bench.is_empty():
		return "对手备战区没有宝可梦。"
	return ""


func get_description() -> String:
	return "Discard 1 other card from your hand. Draw cards equal to the number of opponent Benched Pokemon."


func _resolve_discard_card(player: PlayerState, card: CardInstance, ctx: Dictionary) -> CardInstance:
	var candidates := _discard_candidates(player, card)
	var selected_raw: Array = ctx.get(DISCARD_STEP_ID, [])
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in candidates:
			return entry
	return candidates[0] if not candidates.is_empty() else null


func _discard_candidates(player: PlayerState, card: CardInstance) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	if player == null:
		return result
	for hand_card: CardInstance in player.hand:
		if hand_card == null or hand_card == card:
			continue
		result.append(hand_card)
	return result


func _opponent_bench_count(card: CardInstance, state: GameState) -> int:
	if card == null or state == null:
		return 0
	var opponent_index := 1 - card.owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return 0
	return state.players[opponent_index].bench.size()
