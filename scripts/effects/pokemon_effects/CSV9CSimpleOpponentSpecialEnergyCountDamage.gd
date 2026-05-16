class_name CSV9CSimpleOpponentSpecialEnergyCountDamage
extends BaseEffect

var damage_per_special_energy: int = 40
var printed_base_damage: int = 40
var attack_index_to_match: int = -1


func _init(per_energy: int = 40, base_damage: int = 40, match_attack_index: int = -1) -> void:
	damage_per_special_energy = max(0, per_energy)
	printed_base_damage = max(0, base_damage)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or state == null or attacker.get_top_card() == null:
		return 0
	var owner_index := attacker.get_top_card().owner_index
	var opponent_index := 1 - owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return 0
	var special_count := 0
	for slot: PokemonSlot in state.players[opponent_index].get_all_pokemon():
		if slot == null:
			continue
		for energy: CardInstance in slot.attached_energy:
			if energy != null and energy.card_data != null and energy.card_data.card_type == "Special Energy":
				special_count += 1
	return special_count * damage_per_special_energy - printed_base_damage


func get_description() -> String:
	return "This attack does damage for each Special Energy attached to your opponent's Pokemon."
