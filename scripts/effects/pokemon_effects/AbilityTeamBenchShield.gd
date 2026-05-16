class_name AbilityTeamBenchShield
extends BaseEffect

const RABSCA_EFFECT_ID := "4e41398ab9262f85910de1d9b3a4f027"


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


static func protects_bench_target(target: PokemonSlot, attacker: PokemonSlot, state: GameState) -> bool:
	if target == null or attacker == null or state == null:
		return false
	var target_top: CardInstance = target.get_top_card()
	var attacker_top: CardInstance = attacker.get_top_card()
	if target_top == null or attacker_top == null:
		return false
	var target_owner := target_top.owner_index
	if target_owner == attacker_top.owner_index:
		return false
	if target not in state.players[target_owner].bench:
		return false
	for slot: PokemonSlot in state.players[target_owner].get_all_pokemon():
		if slot == null or slot.get_card_data() == null:
			continue
		if slot.get_card_data().effect_id == RABSCA_EFFECT_ID:
			return true
	return false


func get_description() -> String:
	return "Your Benched Pokemon are protected from damage and effects of opponent attacks."
