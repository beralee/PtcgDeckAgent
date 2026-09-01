class_name AbilityPalafinZeroToHero
extends BaseEffect

const STEP_ID := "palafin_ex"
const PALAFIN_EX_EFFECT_ID := "1b97f4552b78e850d48100edf4d82c95"


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or pokemon.get_top_card() == null or state == null:
		return false
	var owner_index := pokemon.get_top_card().owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return false
	if state.current_player_index != owner_index or pokemon not in state.players[owner_index].bench:
		return false
	if pokemon.has_ability_used(state.turn_number) or not _moved_from_active_this_turn(pokemon, owner_index, state):
		return false
	return not _hero_candidates(state.players[owner_index]).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	var player := state.players[card.owner_index]
	var legal := _hero_candidates(player)
	if legal.is_empty():
		return []
	return [build_full_library_search_step(
		STEP_ID,
		"选择1张海豚侠ex进行全能变身",
		player.deck,
		legal,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		1,
		1,
		{"allow_cancel": true, "force_confirm": true}
	)]


func validate_ability_interaction(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> Dictionary:
	if not can_use_ability(pokemon, state):
		return interaction_validation_error("Zero to Hero is not currently available")
	var owner_index := pokemon.get_top_card().owner_index
	return validate_context_selection(
		get_interaction_context(targets),
		STEP_ID,
		_hero_candidates(state.players[owner_index]),
		0,
		1,
		true
	)


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	if not can_use_ability(pokemon, state):
		return
	var owner_index := pokemon.get_top_card().owner_index
	var player := state.players[owner_index]
	var legal := _hero_candidates(player)
	var selected: CardInstance = null
	for raw: Variant in get_interaction_context(targets).get(STEP_ID, []):
		if raw is CardInstance and raw in legal:
			selected = raw
			break
	if selected == null:
		player.shuffle_deck()
		pokemon.mark_ability_used(state.turn_number)
		return

	var original := pokemon.get_top_card()
	player.deck.erase(selected)
	pokemon.pokemon_stack.pop_back()
	selected.face_up = true
	pokemon.pokemon_stack.append(selected)
	pokemon.mark_top_card_changed()
	original.face_up = false
	player.deck.append(original)
	pokemon.mark_ability_used(state.turn_number)
	player.shuffle_deck()


func _moved_from_active_this_turn(pokemon: PokemonSlot, owner_index: int, state: GameState) -> bool:
	for raw: Variant in FieldTransition.get_transition_events(state):
		if not (raw is Dictionary):
			continue
		var event := raw as Dictionary
		if int(event.get("turn_number", -1)) != state.turn_number:
			continue
		if int(event.get("player_index", -1)) != owner_index:
			continue
		if int(event.get("outgoing_slot_id", -1)) != int(pokemon.get_instance_id()):
			continue
		if str(event.get("kind", "")) in ["switch", "replace_with_newcomer"]:
			return true
	return false


func _hero_candidates(player: PlayerState) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for card: CardInstance in player.deck:
		if card != null and card.card_data != null and card.card_data.effect_id == PALAFIN_EX_EFFECT_ID:
			result.append(card)
	return result


func get_description() -> String:
	return "When this Pokemon moves from the Active Spot to the Bench during your turn, switch this card with a Palafin ex from your deck."
