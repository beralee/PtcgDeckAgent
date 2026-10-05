class_name AttackBonusIfDefenderEnergyType
extends BaseEffect

var bonus_damage: int
var defender_energy_type: String
var attack_index_to_match: int


func _init(bonus: int = 30, target_type: String = "F", attack_index: int = 0) -> void:
	bonus_damage = bonus
	defender_energy_type = target_type
	attack_index_to_match = attack_index


func applies_to_attack_index(index: int) -> bool:
	return index == attack_index_to_match


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return 0
	var opponent := 1 - attacker.get_top_card().owner_index
	if opponent < 0 or opponent >= state.players.size():
		return 0
	var defender: PokemonSlot = state.players[opponent].active_pokemon
	if defender == null or defender.get_card_data() == null:
		return 0
	return bonus_damage if defender.get_energy_type() == defender_energy_type else 0
