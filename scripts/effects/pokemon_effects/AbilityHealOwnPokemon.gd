class_name AbilityHealOwnPokemon
extends BaseEffect

const USED_KEY := "ability_heal_own_pokemon_used"

var heal_amount: int = 20


func _init(amount: int = 20) -> void:
	heal_amount = max(0, amount)


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or state == null:
		return false
	var top := pokemon.get_top_card()
	if top == null:
		return false
	if state.current_player_index != top.owner_index:
		return false
	for eff: Dictionary in pokemon.effects:
		if str(eff.get("type", "")) == USED_KEY and int(eff.get("turn", -999)) == state.turn_number:
			return false
	return _has_damaged_own_pokemon(state.players[top.owner_index])


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	state: GameState
) -> void:
	if not can_use_ability(pokemon, state):
		return
	var top := pokemon.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null:
			slot.damage_counters = maxi(0, slot.damage_counters - heal_amount)
	pokemon.effects.append({
		"type": USED_KEY,
		"turn": state.turn_number,
	})


func _has_damaged_own_pokemon(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and slot.damage_counters > 0:
			return true
	return false


func get_description() -> String:
	return "Once during your turn, heal %d damage from each of your Pokemon." % heal_amount
