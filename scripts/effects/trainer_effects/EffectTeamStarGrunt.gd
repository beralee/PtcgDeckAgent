class_name EffectTeamStarGrunt
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var active := _opponent_active(card, state)
	return active != null and not active.attached_energy.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var active := _opponent_active(card, state)
	if active == null or active.attached_energy.is_empty():
		return []
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for energy: CardInstance in active.attached_energy:
		items.append(energy)
		labels.append(energy.card_data.name)
	return [{
		"id": "target_energy",
		"title": "选择对手战斗宝可梦身上的1个能量",
		"items": items,
		"labels": labels,
		"card_groups": build_attached_card_groups(opponent, items),
		"transparent_battlefield_dialog": true,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var active := _opponent_active(card, state)
	if active == null or active.attached_energy.is_empty():
		return
	var selected: CardInstance = null
	var raw: Array = get_interaction_context(targets).get("target_energy", [])
	if not raw.is_empty() and raw[0] is CardInstance and raw[0] in active.attached_energy:
		selected = raw[0] as CardInstance
	if selected == null:
		selected = active.attached_energy[0]
	active.attached_energy.erase(selected)
	selected.face_up = false
	state.players[1 - card.owner_index].deck.push_front(selected)


func _opponent_active(card: CardInstance, state: GameState) -> PokemonSlot:
	if card == null or state == null:
		return null
	var opponent_index := 1 - card.owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return null
	return state.players[opponent_index].active_pokemon


func get_description() -> String:
	return "Put an Energy attached to your opponent's Active Pokemon on top of their deck."
