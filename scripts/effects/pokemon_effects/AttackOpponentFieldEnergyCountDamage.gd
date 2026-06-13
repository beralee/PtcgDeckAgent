class_name AttackOpponentFieldEnergyCountDamage
extends BaseEffect

var damage_per_energy: int = 60
var attack_index_to_match: int = -1


func _init(per_energy: int = 60, match_attack_index: int = -1) -> void:
	damage_per_energy = per_energy
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	var top: CardInstance = attacker.get_top_card() if attacker != null else null
	if top == null or state == null:
		return 0
	var opponent_index := 1 - top.owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return 0
	var total_energy := 0
	for slot: PokemonSlot in state.players[opponent_index].get_all_pokemon():
		if slot == null:
			continue
		total_energy += slot.get_total_energy_count()
	return total_energy * damage_per_energy - damage_per_energy


func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	pass


func get_description() -> String:
	return "This attack does damage for each Energy attached to all of your opponent's Pokemon."
