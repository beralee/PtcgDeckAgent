class_name AbilityDrawToHandSizeActive
extends BaseEffect

const USED_KEY := "ability_draw_to_hand_size_active_used"

var draw_to_count: int = 4
var once_per_turn: bool = true


func _init(draw_to: int = 4, once: bool = true) -> void:
	draw_to_count = draw_to
	once_per_turn = once


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or state == null:
		return false
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var pi: int = top.owner_index
	if state.current_player_index != pi:
		return false
	if state.players[pi].active_pokemon != pokemon:
		return false
	if once_per_turn:
		for effect: Dictionary in pokemon.effects:
			if effect.get("type", "") == USED_KEY and int(effect.get("turn", -999)) == state.turn_number:
				return false
	return state.players[pi].hand.size() < draw_to_count


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
	var pi: int = top.owner_index
	var need := draw_to_count - state.players[pi].hand.size()
	if need <= 0:
		return
	_draw_cards_with_log(state, pi, need, top, "ability")
	if once_per_turn:
		pokemon.effects.append({
			"type": USED_KEY,
			"turn": state.turn_number,
		})


func get_description() -> String:
	return "If this Pokemon is Active, draw until you have %d cards in hand." % draw_to_count
