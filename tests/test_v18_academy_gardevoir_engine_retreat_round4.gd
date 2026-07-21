class_name TestV18AcademyGardevoirEngineRetreatRound4
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_PATH := "res://data/bundled_user/decks/800018498.json"


func test_first_embrace_pays_active_gardevoir_retreat_before_finishing_bench_attacker() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018498 should resolve through the production registry")
	var state := _state()
	var player: PlayerState = state.players[0]
	var gardevoir := _slot(_card("CSV2C_055"), 0)
	gardevoir.attached_energy.append(_energy())
	var scream_tail := _slot(_card("CSV6C_065"), 0)
	scream_tail.attached_energy.append(_energy())
	player.active_pokemon = gardevoir
	player.bench.append(scream_tail)
	player.discard_pile.assign([_energy(), _energy()])
	state.players[1].active_pokemon = _slot(_defender(), 1)

	var picked: Variant = strategy.call("pick_interaction_items", [gardevoir, scream_tail], {
		"id": "embrace_target",
		"min_select": 1,
		"max_select": 1,
	}, {"game_state": state, "player_index": 0})
	var picked_items: Array = picked if picked is Array else []
	return run_checks([
		assert_eq(picked_items.size(), 1, "Psychic Embrace should choose exactly one target"),
		assert_true(not picked_items.is_empty() and picked_items[0] == gardevoir,
			"The first Embrace must unlock active Gardevoir's last retreat payment before funding Scream Tail"),
	])


func _strategy() -> RefCounted:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	return REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", DeckData.from_dict(raw)) \
		if raw is Dictionary else null


func _state() -> GameState:
	var state := GameState.new()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.current_player_index = 0
	state.turn_number = 9
	state.phase = GameState.GamePhase.MAIN
	for index: int in 6:
		state.players[0].prizes.append(_filler("Own prize %d" % index, 0))
		state.players[1].prizes.append(_filler("Opponent prize %d" % index, 1))
	return state


func _card(ref: String) -> CardData:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/cards/%s.json" % ref
	))
	return CardData.from_dict(raw) if raw is Dictionary else null


func _energy() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Psychic Energy"
	card.card_type = "Basic Energy"
	card.energy_provides = "P"
	return CardInstance.create(card, 0)


func _defender() -> CardData:
	var card := CardData.new()
	card.name_en = "Retreat bridge defender"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 260
	return card


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	if card != null:
		slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot


func _filler(card_name: String, owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name_en = card_name
	card.card_type = "Item"
	return CardInstance.create(card, owner_index)
