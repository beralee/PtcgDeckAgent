class_name AttackBonusIfDefenderEvolvedDiscardAllEnergyFromSelf
extends BaseEffect

var bonus_damage: int = 140
var attack_index_to_match: int = -1


func _init(bonus: int = 140, match_attack_index: int = -1) -> void:
	bonus_damage = bonus
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index == attack_index_to_match


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return 0
	var owner_index := attacker.get_top_card().owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return 0
	var opponent_index := 1 - owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return 0
	var defender: PokemonSlot = state.players[opponent_index].active_pokemon
	return bonus_damage if _is_evolution_defender(defender) else 0


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	if not _is_evolution_defender(defender):
		return
	var top := attacker.get_top_card()
	if top == null:
		return
	var owner_index := top.owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return
	var player := state.players[owner_index]
	var discarded := attacker.attached_energy.duplicate()
	attacker.attached_energy.clear()
	for energy: CardInstance in discarded:
		player.discard_pile.append(energy)


func _is_evolution_defender(defender: PokemonSlot) -> bool:
	return defender != null and defender.get_card_data() != null and defender.get_card_data().is_evolution_pokemon()


func get_description() -> String:
	return "Add damage against an evolved Active Pokemon, then discard all Energy from this Pokemon."
