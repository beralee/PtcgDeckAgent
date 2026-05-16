class_name CSV9CSimpleDiscardPileEnergyCountDamage
extends BaseEffect

var damage_per_energy: int = 20
var attack_index_to_match: int = -1


func _init(per_energy: int = 20, match_attack_index: int = -1) -> void:
	damage_per_energy = per_energy
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or state == null or attacker.get_top_card() == null:
		return 0
	var owner_index := attacker.get_top_card().owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return 0
	var energy_count := 0
	for card: CardInstance in state.players[owner_index].discard_pile:
		if card != null and card.card_data != null and card.card_data.is_energy():
			energy_count += 1
	return energy_count * damage_per_energy


func get_description() -> String:
	return "This attack does more damage for each Energy card in your discard pile."
