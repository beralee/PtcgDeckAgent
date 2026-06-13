class_name AttackHealOwnBenchPokemon
extends BaseEffect

var heal_amount: int = 100
var attack_index_to_match: int = -1


func _init(amount: int = 100, match_attack_index: int = -1) -> void:
	heal_amount = amount
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player_index := top.owner_index
	if player_index < 0 or player_index >= state.players.size():
		return
	for slot: PokemonSlot in state.players[player_index].bench:
		if slot == null:
			continue
		slot.damage_counters = maxi(0, slot.damage_counters - heal_amount)


func get_description() -> String:
	return "Heal damage from each of your Benched Pokemon."
