## 海岱（CSV8C 200）
## 选择2张其他手牌，以任意顺序放回牌库下方，然后抽取4张卡牌。
class_name EffectKofu
extends BaseEffect

const STEP_ID := "kofu_hand_to_bottom"
const RETURN_COUNT := 2
const DRAW_COUNT := 4


func can_execute(card: CardInstance, state: GameState) -> bool:
	return _other_hand_cards(card, state).size() >= RETURN_COUNT


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	return can_execute(card, state)


func get_unusable_reason(_card: CardInstance, _state: GameState) -> String:
	return "手牌中除海岱外至少需要有2张卡。"


func get_empty_interaction_message(card: CardInstance, state: GameState) -> String:
	return get_unusable_reason(card, state)


func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var hand_cards: Array[CardInstance] = _other_hand_cards(card, state)
	if hand_cards.size() < RETURN_COUNT:
		return []
	var labels: Array[String] = []
	for hand_card: CardInstance in hand_cards:
		labels.append(hand_card.card_data.name)
	return [{
		"id": STEP_ID,
		"title": "依次选择2张手牌（先选择的牌放在后选择的牌上方）",
		"items": hand_cards,
		"labels": labels,
		"presentation": "cards",
		"min_select": RETURN_COUNT,
		"max_select": RETURN_COUNT,
		"allow_cancel": true,
		"force_confirm": true,
		"selection_order_matters": true,
	}]


func validate_card_interaction(card: CardInstance, targets: Array, state: GameState) -> Dictionary:
	var hand_cards: Array[CardInstance] = _other_hand_cards(card, state)
	if hand_cards.size() < RETURN_COUNT:
		return interaction_validation_error("Kofu requires two other cards in hand")
	return validate_context_selection(
		get_interaction_context(targets),
		STEP_ID,
		hand_cards,
		RETURN_COUNT,
		RETURN_COUNT
	)


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return
	var player: PlayerState = state.players[card.owner_index]
	var selected_cards: Array[CardInstance] = []
	var selected_raw: Array = get_interaction_context(targets).get(STEP_ID, [])
	for entry: Variant in selected_raw:
		if (
			entry is CardInstance
			and entry != card
			and entry in player.hand
			and entry not in selected_cards
		):
			selected_cards.append(entry)
			if selected_cards.size() >= RETURN_COUNT:
				break
	if selected_cards.size() != RETURN_COUNT:
		return

	for selected_card: CardInstance in selected_cards:
		player.remove_from_hand(selected_card)
		selected_card.face_up = false
		player.deck.append(selected_card)
	_draw_cards_with_log(state, card.owner_index, DRAW_COUNT, card, "trainer")


func _other_hand_cards(card: CardInstance, state: GameState) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return result
	var player: PlayerState = state.players[card.owner_index]
	for hand_card: CardInstance in player.hand:
		if hand_card != card:
			result.append(hand_card)
	return result


func get_description() -> String:
	return "选择自己的2张手牌，以任意顺序重新排列，放回牌库下方。然后，从牌库上方抽取4张卡牌。（如果无法将自己的2张手牌放回牌库的话，则无法使用这张卡牌。）"
