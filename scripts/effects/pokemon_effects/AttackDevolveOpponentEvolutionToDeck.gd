class_name AttackDevolveOpponentEvolutionToDeck
extends BaseEffect

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top := attacker.get_top_card()
	if top == null:
		return
	var opponent_index := 1 - top.owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return
	var opponent: PlayerState = state.players[opponent_index]
	var removed_cards: Array[CardInstance] = []
	for slot: PokemonSlot in opponent.get_all_pokemon():
		if slot == null or slot.pokemon_stack.size() <= 1:
			continue
		var removed: CardInstance = slot.pokemon_stack.pop_back() as CardInstance
		if removed == null:
			continue
		slot.mark_top_card_changed()
		removed.face_up = false
		removed_cards.append(removed)
	for card: CardInstance in removed_cards:
		opponent.deck.append(card)
	if not removed_cards.is_empty():
		opponent.shuffle_deck()


func get_description() -> String:
	return "将对手每只已进化宝可梦退化，并将移除的进化卡洗入其牌库。"
