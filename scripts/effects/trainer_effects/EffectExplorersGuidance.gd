class_name EffectExplorersGuidance
extends BaseEffect

const STEP_ID := "explorers_guidance_cards"
const LOOK_COUNT := 6
const PICK_COUNT := 2


func can_execute(card: CardInstance, state: GameState) -> bool:
	return card != null and state != null and not state.players[card.owner_index].deck.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var looked: Array = []
	var labels: Array[String] = []
	for idx: int in range(mini(LOOK_COUNT, player.deck.size())):
		var deck_card: CardInstance = player.deck[idx]
		looked.append(deck_card)
		labels.append(deck_card.card_data.name if deck_card.card_data != null else "")
	var actual_pick: int = mini(PICK_COUNT, looked.size())
	return [{
		"id": STEP_ID,
		"title": "Choose %d card(s) to put into your hand" % actual_pick,
		"items": looked,
		"labels": labels,
		"min_select": actual_pick,
		"max_select": actual_pick,
		"allow_cancel": false,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	if player.deck.is_empty():
		return

	var looked: Array[CardInstance] = []
	for _i: int in range(mini(LOOK_COUNT, player.deck.size())):
		looked.append(player.deck.pop_front())

	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get(STEP_ID, [])
	var selected_ids: Dictionary = {}
	for entry: Variant in selected_raw:
		if entry is CardInstance:
			selected_ids[(entry as CardInstance).instance_id] = true

	var kept: Array[CardInstance] = []
	var discarded: Array[CardInstance] = []
	for deck_card: CardInstance in looked:
		deck_card.face_up = true
		if selected_ids.has(deck_card.instance_id) and kept.size() < PICK_COUNT:
			kept.append(deck_card)
		else:
			discarded.append(deck_card)

	if kept.size() < mini(PICK_COUNT, looked.size()):
		for deck_card: CardInstance in looked:
			if kept.size() >= mini(PICK_COUNT, looked.size()):
				break
			if deck_card in kept:
				continue
			if deck_card in discarded:
				discarded.erase(deck_card)
			kept.append(deck_card)

	for kept_card: CardInstance in kept:
		if kept_card in discarded:
			discarded.erase(kept_card)
		player.hand.append(kept_card)
	for discarded_card: CardInstance in discarded:
		player.discard_pile.append(discarded_card)


func get_description() -> String:
	return "Look at the top 6 cards of your deck, put 2 of them into your hand, and discard the rest."
