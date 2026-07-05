class_name AttackOpponentDiscardBasicEnergyCountDamage
extends BaseEffect

var damage_per_energy: int = 30
var attack_index_to_match: int = -1
var replaces_printed_multiplier_base: bool = true


func _init(per_energy: int = 30, match_attack_index: int = -1, replace_printed_base: bool = true) -> void:
	damage_per_energy = per_energy
	attack_index_to_match = match_attack_index
	replaces_printed_multiplier_base = replace_printed_base


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or state == null or attacker.get_top_card() == null:
		return 0
	var owner_index := attacker.get_top_card().owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return 0
	var opponent_index := 1 - owner_index
	var basic_energy_count := 0
	for card: CardInstance in state.players[opponent_index].discard_pile:
		if card != null and card.card_data != null and card.card_data.card_type == "Basic Energy":
			basic_energy_count += 1
	var damage := basic_energy_count * damage_per_energy
	if replaces_printed_multiplier_base:
		damage -= damage_per_energy
	return damage


func get_description() -> String:
	return "This attack does damage for each Basic Energy in your opponent's discard pile."
