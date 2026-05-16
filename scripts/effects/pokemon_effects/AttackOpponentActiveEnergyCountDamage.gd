class_name AttackOpponentActiveEnergyCountDamage
extends BaseEffect

var damage_per_energy: int = 30
var attack_index_to_match: int = -1


func _init(per_energy: int = 30, match_attack_index: int = -1) -> void:
	damage_per_energy = per_energy
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return 0
	var opponent: PlayerState = state.players[1 - top.owner_index]
	if opponent.active_pokemon == null:
		return 0
	return opponent.active_pokemon.attached_energy.size() * damage_per_energy


func get_description() -> String:
	return "Adds damage for each Energy attached to the opponent's Active Pokemon."
