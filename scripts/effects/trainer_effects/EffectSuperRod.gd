## 厉害钓竿 - 从弃牌区选择宝可梦和基本能量合计最多3张放回牌库
class_name EffectSuperRod
extends BaseEffect


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var items: Array = _recoverable_discard_cards(card, state)
	var labels: Array[String] = []
	for c: CardInstance in items:
		labels.append(c.card_data.name)
	return [{
		"id": "cards_to_return",
		"title": "选择最多3张宝可梦或基本能量放回牌库",
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(3, items.size()),
		"allow_cancel": true,
		"force_confirm": true,
		"requires_explicit_empty_selection": true,
	}]


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not _recoverable_discard_cards(card, state).is_empty()


func validate_card_interaction(card: CardInstance, targets: Array, state: GameState) -> Dictionary:
	if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return interaction_validation_error("Super Rod source card is invalid")
	var legal_items: Array = _recoverable_discard_cards(card, state)
	return validate_context_selection(
		get_interaction_context(targets),
		"cards_to_return",
		legal_items,
		0,
		mini(3, legal_items.size()),
		true
	)


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	if not bool(validate_card_interaction(card, _targets, state).get("valid", false)):
		return
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(_targets)

	var to_return: Array[CardInstance] = []
	var selected_raw: Array = ctx.get("cards_to_return", [])
	for c: Variant in selected_raw:
		if c is CardInstance and c in player.discard_pile:
			if (c.card_data.is_pokemon() or c.card_data.card_type == "Basic Energy") and DiscardPileRestriction.can_move_to_hand_or_deck(c):
				to_return.append(c)
				if to_return.size() >= 3:
					break

	for c: CardInstance in to_return:
		player.discard_pile.erase(c)
		c.face_up = false
		player.deck.append(c)

	player.shuffle_deck()


func _recoverable_discard_cards(card: CardInstance, state: GameState) -> Array:
	var cards: Array = []
	if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return cards
	for discard_card: CardInstance in state.players[card.owner_index].discard_pile:
		if discard_card == null or discard_card.card_data == null:
			continue
		if not (discard_card.card_data.is_pokemon() or discard_card.card_data.card_type == "Basic Energy"):
			continue
		if DiscardPileRestriction.can_move_to_hand_or_deck(discard_card):
			cards.append(discard_card)
	return cards


func get_description() -> String:
	return "从弃牌区选择宝可梦和基本能量合计最多3张放回牌库"
