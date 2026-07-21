class_name TestV18NoBalloonGardevoirCharmReserveRound8
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_PATH := "res://data/bundled_user/decks/800017097.json"


func test_pre_shell_ralts_reserves_charm_for_a_real_damage_scaler() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_true(false, "Deck 800017097 should resolve through the production registry")
	var state := _state()
	var player: PlayerState = state.players[0]
	var ralts := _slot(_card("CSV2C_053"), 0)
	var scream_tail := _slot(_card("CSV6C_065"), 0)
	player.active_pokemon = ralts
	player.bench.append(scream_tail)
	var charm := CardInstance.create(_card("CSV1C_118"), 0)
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var ralts_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_tool",
		"card": charm,
		"target_slot": ralts,
	}, state, 0, plan))
	var scream_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_tool",
		"card": charm,
		"target_slot": scream_tail,
	}, state, 0, plan))
	return run_checks([
		assert_true(ralts_score <= -4500.0,
			"Pre-shell Ralts must not consume the no-balloon list's damage-scaler Charm (score=%f)" % ralts_score),
		assert_true(scream_score > ralts_score,
			"A real one-prize damage scaler must retain priority over Ralts (Scream=%f Ralts=%f)" % [scream_score, ralts_score]),
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
	state.turn_number = 1
	state.phase = GameState.GamePhase.MAIN
	state.players[1].active_pokemon = _slot(_defender(), 1)
	for index: int in 6:
		state.players[0].prizes.append(_filler("Own prize %d" % index, 0))
		state.players[1].prizes.append(_filler("Opponent prize %d" % index, 1))
	return state


func _card(ref: String) -> CardData:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/cards/%s.json" % ref
	))
	return CardData.from_dict(raw) if raw is Dictionary else null


func _defender() -> CardData:
	var card := CardData.new()
	card.name_en = "Charm reserve defender"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 220
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
