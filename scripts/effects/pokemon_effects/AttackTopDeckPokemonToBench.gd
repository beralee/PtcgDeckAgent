class_name AttackTopDeckPokemonToBench
extends BaseEffect

const BenchLimit = preload("res://scripts/engine/BenchLimitHelper.gd")

const STEP_ID := "top_deck_pokemon_to_bench"

var look_count: int = 10


func _init(count: int = 10) -> void:
	look_count = count


func build_ucis_attack_interaction_steps_spec_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var visible_cards := _looked_cards(player)
	var bench_space := BenchLimit.get_available_bench_space(state, player)
	var items := _matching_pokemon(visible_cards)
	if visible_cards.is_empty() or bench_space <= 0 or items.is_empty():
		return []
	return [build_full_library_search_step(
		STEP_ID,
		"Choose any number of Pokemon from the top %d cards to put onto your Bench" % visible_cards.size(),
		visible_cards,
		items,
		"own_top_%d_cards" % visible_cards.size(),
		0,
		mini(bench_space, items.size()),
		{
			"allow_cancel": true,
			"force_confirm": true,
			"show_selectable_hints": true,
		}
	)]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top: CardInstance = attacker.get_top_card() if attacker != null else null
	if top == null or state == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var visible_cards := _looked_cards(player)
	var bench_space := BenchLimit.get_available_bench_space(state, player)
	var chosen: Array[CardInstance] = []
	var ctx := get_attack_interaction_context()
	var has_explicit_selection := ctx.has(STEP_ID)
	for entry: Variant in ctx.get(STEP_ID, []):
		if entry is CardInstance and entry in visible_cards and _is_pokemon(entry) and entry not in chosen:
			chosen.append(entry)
			if chosen.size() >= bench_space:
				break
	if chosen.is_empty() and not has_explicit_selection and bench_space > 0:
		for card: CardInstance in visible_cards:
			if _is_pokemon(card):
				chosen.append(card)
				if chosen.size() >= bench_space:
					break
	for pokemon_card: CardInstance in chosen:
		if BenchLimit.is_bench_full(state, player):
			break
		if pokemon_card not in player.deck or not _is_pokemon(pokemon_card):
			continue
		player.deck.erase(pokemon_card)
		pokemon_card.face_up = true
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(pokemon_card)
		slot.turn_played = state.turn_number
		player.bench.append(slot)
	player.shuffle_deck()


func _looked_cards(player: PlayerState) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	if player == null:
		return cards
	for i: int in mini(look_count, player.deck.size()):
		cards.append(player.deck[i])
	return cards


func _matching_pokemon(cards: Array[CardInstance]) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for card: CardInstance in cards:
		if _is_pokemon(card):
			result.append(card)
	return result


func _is_pokemon(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.is_pokemon()
