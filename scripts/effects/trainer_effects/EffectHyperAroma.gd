## 高级香氛 - 从牌库搜索最多3张1阶进化宝可梦加入手牌
class_name EffectHyperAroma
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	for c: CardInstance in player.deck:
		if c.card_data.is_pokemon() and c.card_data.stage == "Stage 1":
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for c: CardInstance in player.deck:
		if c.card_data.is_pokemon() and c.card_data.stage == "Stage 1":
			items.append(c)
			labels.append(c.card_data.name)
	return [{
		"id": "search_cards",
		"title": "选择最多3张1阶进化宝可梦",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": mini(3, items.size()),
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)

	var found: Array[CardInstance] = []
	var selected_raw: Array = ctx.get("search_cards", [])
	for c: Variant in selected_raw:
		if c is CardInstance and c in player.deck and c.card_data.is_pokemon() and c.card_data.stage == "Stage 1":
			found.append(c)
			if found.size() >= 3:
				break

	if found.is_empty():
		for deck_card: CardInstance in player.deck:
			if deck_card.card_data.is_pokemon() and deck_card.card_data.stage == "Stage 1":
				found.append(deck_card)
				if found.size() >= 3:
					break

	for c: CardInstance in found:
		player.deck.erase(c)
	for c: CardInstance in found:
		c.face_up = true
		player.hand.append(c)

	player.shuffle_deck()


func get_description() -> String:
	return "从牌库检索最多3张1阶进化宝可梦加入手牌"
