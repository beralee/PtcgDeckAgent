class_name AttackDiscardAllOpponentSpecialEnergy
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
	var to_discard: Array[CardInstance] = []
	for slot: PokemonSlot in opponent.get_all_pokemon():
		if slot == null:
			continue
		for energy: CardInstance in slot.attached_energy:
			if _is_special_energy(energy):
				to_discard.append(energy)
	for energy: CardInstance in to_discard:
		for slot: PokemonSlot in opponent.get_all_pokemon():
			if slot != null and energy in slot.attached_energy:
				slot.attached_energy.erase(energy)
				opponent.discard_card(energy)
				break


func _is_special_energy(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.card_type == "Special Energy"


func get_description() -> String:
	return "Discard all Special Energy attached to all of your opponent's Pokemon."
