class_name TestV18RabscaGardevoirEngineHandoffRound5
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18GardevoirVariants.gd")
const DECK_PATH := "res://data/bundled_user/decks/800018105.json"


func test_seed15305_pays_active_gardevoir_before_overcharging_drifloon() -> String:
	var strategy := _strategy()
	var state := _state()
	var player: PlayerState = state.players[0]
	var active := _slot(_pokemon("Gardevoir ex", "Stage 2", "Kirlia", "PPC", 2, 310))
	var drifloon := _slot(_pokemon("Drifloon", "Basic", "", "PP", 1, 70))
	active.attached_energy.append(_psychic())
	drifloon.attached_energy.append(_psychic())
	player.active_pokemon = active
	player.bench.append(drifloon)
	var hand_energy := _psychic()
	player.hand.append(hand_energy)
	var active_attach := {"kind": "attach_energy", "card": hand_energy, "target_slot": active}
	var drifloon_attach := {"kind": "attach_energy", "card": hand_energy, "target_slot": drifloon}
	var active_score: float = strategy.call("score_action_absolute", active_attach, state, 0)
	var drifloon_score: float = strategy.call("score_action_absolute", drifloon_attach, state, 0)
	var handoff_score: float = strategy.call(
		"score_handoff_target",
		drifloon,
		{"id": "switch_target"},
		{"game_state": state, "player_index": 0}
	)
	return run_checks([
		assert_true(active_score >= 2600.0 and active_score > drifloon_score,
			"The last retreat payment should preserve Gardevoir ex before improving Drifloon"),
		assert_true(handoff_score >= 2700.0,
			"The paid engine should hand off into the one-prize pressure pivot"),
	])


func _strategy() -> RefCounted:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	strategy.call("configure_from_deck", DeckData.from_dict(raw))
	return strategy


func _state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 8
	state.phase = GameState.GamePhase.MAIN
	return state


func _pokemon(name_en: String, stage: String, evolves_from: String, cost: String, retreat: int, hp: int) -> CardData:
	var card := CardData.new()
	card.name = name_en
	card.name_en = name_en
	card.card_type = "Pokemon"
	card.stage = stage
	card.evolves_from = evolves_from
	card.energy_type = "P"
	card.retreat_cost = retreat
	card.hp = hp
	card.attacks = [{"name": "Test", "cost": cost, "damage": "30", "text": "damage counter"}]
	return card


func _psychic() -> CardInstance:
	var card := CardData.new()
	card.name = "Psychic Energy"
	card.name_en = "Psychic Energy"
	card.card_type = "Basic Energy"
	card.energy_provides = "P"
	return CardInstance.create(card, 0)


func _slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
