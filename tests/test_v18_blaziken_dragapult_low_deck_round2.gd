class_name TestV18BlazikenDragapultLowDeckRound2
extends TestBase

const StrategyScript = preload("res://scripts/ai/DeckStrategyV18DragapultFamily.gd")


func _make_game_state() -> GameState:
	var gs := GameState.new()
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	gs.turn_number = 27
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		gs.players.append(player)
	return gs


func _make_card_data(name: String, stage: String = "Basic") -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 100
	return card


func _make_energy(name: String, provides: String) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Basic Energy"
	card.energy_provides = provides
	return CardInstance.create(card, 0)


func _make_slot(card_data: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, 0))
	return slot


func _configure_strategy(deck_id: int):
	var strategy = StrategyScript.new()
	var deck := DeckData.new()
	deck.id = deck_id
	strategy.configure_from_deck(deck)
	return strategy


func _ready_dragapult_state() -> GameState:
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	var ready_dragapult := _make_slot(_make_card_data("Dragapult ex"))
	ready_dragapult.attached_energy.append(_make_energy("Fire Energy", "R"))
	ready_dragapult.attached_energy.append(_make_energy("Psychic Energy", "P"))
	player.active_pokemon = ready_dragapult
	player.bench.append(_make_slot(_make_card_data("Drakloak", "Stage 1")))
	for _i: int in 8:
		player.deck.append(_make_energy("Filler Energy", "C"))
	return gs


func test_blaziken_dragapult_low_deck_drakloak_ability_stays_below_end_turn() -> String:
	var gs := _ready_dragapult_state()
	var strategy = _configure_strategy(800019125)
	var player: PlayerState = gs.players[0]
	var ability_score: float = strategy.score_action_absolute({
		"kind": "use_ability",
		"source_slot": player.bench[0],
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(
		ability_score < end_score,
		"Blaziken/Dragapult must end instead of using Drakloak look_top_pick under low-deck pressure (ability=%f end=%f)" % [ability_score, end_score]
	)


func test_low_deck_drakloak_guard_does_not_touch_curse_blast_sibling() -> String:
	var gs := _ready_dragapult_state()
	var strategy = _configure_strategy(800015734)
	var player: PlayerState = gs.players[0]
	var ability_score: float = strategy.score_action_absolute({
		"kind": "use_ability",
		"source_slot": player.bench[0],
	}, gs, 0)
	return assert_eq(
		ability_score,
		200.0,
		"The low-deck Drakloak guard must remain isolated from 800015734 (ability=%f)" % ability_score
	)
