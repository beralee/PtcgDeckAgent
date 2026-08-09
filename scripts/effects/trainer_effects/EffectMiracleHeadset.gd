class_name EffectMiracleHeadset
extends BaseEffect

const STEP_ID := "supporters_to_hand"


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not _supporters(card, state).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var legal := _supporters(card, state)
	var labels: Array[String] = []
	for supporter: CardInstance in legal:
		labels.append(supporter.card_data.name)
	return [{
		"id": STEP_ID,
		"title": "Choose up to 2 Supporter cards from your discard pile",
		"items": legal,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(2, legal.size()),
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player := state.players[card.owner_index]
	var legal := _supporters(card, state)
	var selected: Array[CardInstance] = []
	for entry: Variant in get_interaction_context(targets).get(STEP_ID, []):
		if entry is CardInstance and entry in legal and entry not in selected:
			selected.append(entry)
			if selected.size() >= 2:
				break
	for supporter: CardInstance in selected:
		player.discard_pile.erase(supporter)
		supporter.face_up = true
		player.hand.append(supporter)


func _supporters(card: CardInstance, state: GameState) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	if card == null or state == null:
		return result
	for entry: CardInstance in state.players[card.owner_index].discard_pile:
		if entry != null and entry.card_data != null and entry.card_data.card_type == "Supporter":
			result.append(entry)
	return result


func get_description() -> String:
	return "Put up to 2 Supporter cards from your discard pile into your hand."
