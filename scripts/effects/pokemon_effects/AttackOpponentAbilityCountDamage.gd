class_name AttackOpponentAbilityCountDamage
extends BaseEffect

var damage_per_pokemon: int = 50
var attack_index_to_match: int = -1


func _init(per_pokemon: int = 50, match_attack_index: int = -1) -> void:
	damage_per_pokemon = per_pokemon
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return 0
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var count := 0
	for slot: PokemonSlot in opponent.get_all_pokemon():
		if slot == null or slot.get_card_data() == null:
			continue
		if slot.get_card_data().abilities.size() > 0:
			count += 1
	return count * damage_per_pokemon


func get_description() -> String:
	return "Adds damage for each opponent Pokemon that has an Ability."
