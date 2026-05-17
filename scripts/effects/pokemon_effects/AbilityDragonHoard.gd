class_name AbilityDragonHoard
extends BaseEffect

const USED_PREFIX := "ability_dragons_hoard_used_p"

var draw_to_count: int = 4


func _init(draw_to: int = 4) -> void:
	draw_to_count = draw_to


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or state == null:
		return false
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var player_index := top.owner_index
	if player_index < 0 or player_index >= state.players.size():
		return false
	if state.current_player_index != player_index:
		return false
	if state.players[player_index].active_pokemon != pokemon:
		return false
	if int(state.shared_turn_flags.get(_used_key(player_index), -999)) == state.turn_number:
		return false
	return state.players[player_index].hand.size() < draw_to_count


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	state: GameState
) -> void:
	if not can_use_ability(pokemon, state):
		return
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var player_index := top.owner_index
	var need := draw_to_count - state.players[player_index].hand.size()
	if need > 0:
		_draw_cards_with_log(state, player_index, need, top, "ability")
	state.shared_turn_flags[_used_key(player_index)] = state.turn_number


func get_ability_name() -> String:
	return "Dragon's Hoard"


func get_description() -> String:
	return "If this Pokemon is in the Active Spot, draw until you have %d cards in hand. You cannot use more than one Dragon's Hoard each turn." % draw_to_count


func _used_key(player_index: int) -> String:
	return "%s%d" % [USED_PREFIX, player_index]
