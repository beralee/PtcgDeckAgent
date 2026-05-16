class_name AbilitySearchDeckCardType
extends BaseEffect

const STEP_ID := "search_cards"
const USED_KEY := "ability_search_deck_card_type_used"

var search_count: int = 1
var card_type_filter: String = ""
var active_only: bool = false
var once_per_turn: bool = true


func _init(count: int = 1, filter_type: String = "", require_active: bool = false, once: bool = true) -> void:
	search_count = count
	card_type_filter = filter_type
	active_only = require_active
	once_per_turn = once


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or pokemon.get_top_card() == null or state == null:
		return false
	var owner_index := pokemon.get_top_card().owner_index
	if state.current_player_index != owner_index:
		return false
	if active_only and state.players[owner_index].active_pokemon != pokemon:
		return false
	if once_per_turn and pokemon.has_ability_used(state.turn_number):
		return false
	return not state.players[owner_index].deck.is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player := state.players[card.owner_index]
	var matches := _matching_cards(player)
	if matches.is_empty():
		return [build_empty_search_resolution_step("No matching cards in deck.")]
	return [build_full_library_search_step(
		STEP_ID,
		"Choose up to %d matching cards from your deck" % search_count,
		player.deck,
		matches,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		0,
		mini(search_count, matches.size()),
		{"allow_cancel": true}
	)]


func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
	if not can_use_ability(pokemon, state):
		return
	var owner_index := pokemon.get_top_card().owner_index
	var player := state.players[owner_index]
	var ctx := get_interaction_context(targets)
	var has_explicit_selection := ctx.has(STEP_ID)
	var selected: Array[CardInstance] = []
	for entry: Variant in ctx.get(STEP_ID, []):
		if entry is CardInstance and entry in player.deck and _matches(entry) and entry not in selected:
			selected.append(entry)
			if selected.size() >= search_count:
				break
	if selected.is_empty() and not has_explicit_selection:
		for card: CardInstance in _matching_cards(player):
			selected.append(card)
			if selected.size() >= search_count:
				break
	_move_public_cards_to_hand_with_log(state, owner_index, selected, pokemon.get_top_card(), "ability", "search_to_hand", [_filter_label()])
	player.shuffle_deck()
	if once_per_turn:
		pokemon.mark_ability_used(state.turn_number)


func _matching_cards(player: PlayerState) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for card: CardInstance in player.deck:
		if _matches(card):
			result.append(card)
	return result


func _matches(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	if card_type_filter == "":
		return true
	return card.card_data.card_type == card_type_filter


func _filter_label() -> String:
	return "cards" if card_type_filter == "" else card_type_filter


func get_description() -> String:
	return "Search your deck for up to %d %s cards and put them into your hand." % [search_count, _filter_label()]

