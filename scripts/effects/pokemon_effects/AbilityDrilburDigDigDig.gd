class_name AbilityDrilburDigDigDig
extends AbilityOnBenchEnter

const STEP_ID := "dig_dig_dig_energy"
const ENERGY_LIMIT := 3


func _init() -> void:
	effect_type = "dig_dig_dig"


func is_optional_bench_enter_ability() -> bool:
	return true


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or state == null:
		return false
	var top := pokemon.get_top_card()
	if top == null or top.owner_index < 0 or top.owner_index >= state.players.size():
		return false
	if state.current_player_index != top.owner_index:
		return false
	var player := state.players[top.owner_index]
	if pokemon not in player.bench:
		return false
	if pokemon.turn_played != state.turn_number:
		return false
	if not pokemon.entered_bench_from_hand_this_turn(state.turn_number):
		return false
	if pokemon.has_ability_used(state.turn_number):
		return false
	return not _basic_fighting_energy(player.deck).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return []
	var player := state.players[card.owner_index]
	var legal := _basic_fighting_energy(player.deck)
	if legal.is_empty():
		return []
	return [build_full_library_search_step(
		STEP_ID,
		"选择最多3张基本斗能量放入弃牌区",
		player.deck,
		legal,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		0,
		mini(ENERGY_LIMIT, legal.size()),
		{
			"allow_cancel": true,
			"force_confirm": true,
			"card_selectable_hint": "可放入弃牌区",
		}
	)]


func validate_ability_interaction(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> Dictionary:
	if not can_use_ability(pokemon, state):
		return interaction_validation_error("Dig Dig Dig is not available")
	var top := pokemon.get_top_card()
	var legal := _basic_fighting_energy(state.players[top.owner_index].deck)
	return validate_context_selection(
		get_interaction_context(targets),
		STEP_ID,
		legal,
		0,
		mini(ENERGY_LIMIT, legal.size()),
		true,
		true
	)


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	if pokemon == null or state == null:
		return
	var top := pokemon.get_top_card()
	if top == null or top.owner_index < 0 or top.owner_index >= state.players.size():
		return
	var player := state.players[top.owner_index]
	var legal := _basic_fighting_energy(player.deck)
	var selected: Array[CardInstance] = []
	var context := get_interaction_context(targets)
	for entry: Variant in context.get(STEP_ID, []):
		if selected.size() >= ENERGY_LIMIT:
			break
		if entry is CardInstance and entry in legal and entry not in selected:
			selected.append(entry)
	for energy: CardInstance in selected:
		player.deck.erase(energy)
		energy.face_up = true
		player.discard_pile.append(energy)
	player.shuffle_deck()
	pokemon.mark_ability_used(state.turn_number)


func _basic_fighting_energy(cards: Array[CardInstance]) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for card: CardInstance in cards:
		if card == null or card.card_data == null or card.card_data.card_type != "Basic Energy":
			continue
		var provides := card.card_data.energy_provides
		if provides == "":
			provides = card.card_data.energy_type
		if provides == "F":
			result.append(card)
	return result


func get_description() -> String:
	return "When played from hand to the Bench, search the deck for up to 3 Basic Fighting Energy, discard them, then shuffle."
