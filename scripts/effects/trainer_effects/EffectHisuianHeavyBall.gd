## Reveal prizes and swap Hisuian Heavy Ball itself into the prize cards.
class_name EffectHisuianHeavyBall
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not player.prizes.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var prize_items: Array = []
	var prize_labels: Array[String] = []
	var prize_card_items: Array = []
	var prize_card_indices: Array[int] = []
	var prize_card_labels: Array[String] = []
	for prize_index: int in player.prizes.size():
		var prize_card: CardInstance = player.prizes[prize_index]
		prize_card_items.append(prize_card)
		if prize_card.card_data != null and prize_card.card_data.is_basic_pokemon():
			prize_card_indices.append(prize_items.size())
			prize_items.append(prize_card)
			prize_labels.append("%s - 奖赏卡%d" % [prize_card.card_data.name, prize_index + 1])
			prize_card_labels.append("奖赏卡%d - 基础宝可梦，可选择" % (prize_index + 1))
		else:
			prize_card_indices.append(-1)
			prize_card_labels.append("奖赏卡%d - 不能选择，仅查看" % (prize_index + 1))
	var has_basic_prize := not prize_items.is_empty()
	return [{
		"id": "chosen_prize_basic",
		"title": "查看奖赏卡，选择1张基础宝可梦" if has_basic_prize else "查看奖赏卡，未找到基础宝可梦",
		"items": prize_items,
		"labels": prize_labels,
		"presentation": "cards",
		"card_items": prize_card_items,
		"card_indices": prize_card_indices,
		"choice_labels": prize_card_labels,
		"show_selectable_hints": true,
		"card_selectable_hint": "可选",
		"card_disabled_badge": "仅查看",
		"utility_actions": [] if has_basic_prize else [{"label": "完成", "index": -1}],
		"min_select": 1 if has_basic_prize else 0,
		"max_select": 1 if has_basic_prize else 0,
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("chosen_prize_basic", [])

	var selected_prize: CardInstance = null
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		var candidate: CardInstance = selected_raw[0]
		if candidate in player.prizes and candidate.card_data != null and candidate.card_data.is_basic_pokemon():
			selected_prize = candidate

	if selected_prize == null:
		for prize_card: CardInstance in player.prizes:
			if prize_card.card_data != null and prize_card.card_data.is_basic_pokemon():
				selected_prize = prize_card
				break
	if selected_prize == null:
		return

	selected_prize = player.take_prize_card(selected_prize)
	if selected_prize == null:
		return

	player.hand.erase(card)
	card.face_up = false
	player.prizes.append(card)
	_shuffle_cards(player.prizes)
	player.reset_prize_layout()


func _shuffle_cards(cards: Array[CardInstance]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(cards.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: CardInstance = cards[i]
		cards[i] = cards[j]
		cards[j] = temp


func get_description() -> String:
	return "查看自己的奖赏卡。若其中有基础宝可梦，则选择1张加入手牌，并将洗翠沉重球洗入奖赏卡。"
