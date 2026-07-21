class_name TestV18RabscaGardevoirIdleGuardRound10
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_PATH := "res://data/bundled_user/decks/800018105.json"


func test_developed_attacker_does_not_evolve_idle_rabsca_without_bench_pressure() -> String:
	var strategy := _strategy()
	var state := _state()
	var player: PlayerState = state.players[0]
	var scream := _slot(_card("CSV6C_065"), 0)
	scream.attached_energy.assign([_energy("P"), _energy("P")])
	var rellor := _slot(_card("CSV7C_030"), 0)
	player.active_pokemon = scream
	player.bench.append(rellor)
	state.players[1].active_pokemon = _slot(_defender(), 1)
	var rabsca := CardInstance.create(_card("CSV7C_031"), 0)
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {"prompt_kind": "action_selection"})
	var evolve_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "evolve", "card": rabsca, "target_slot": rellor,
	}, state, 0, plan))
	var attack_score := float(strategy.call("score_action_absolute_with_plan", {
		"kind": "attack", "source_slot": scream, "projected_knockout": false,
	}, state, 0, plan))
	return run_checks([
		assert_true(evolve_score <= -3500.0,
			"An attacker-ready board must not spend tempo on idle Rabsca (score=%f)" % evolve_score),
		assert_true(attack_score > evolve_score,
			"The live one-prize attack must outrank an unnecessary guard evolution"),
	])


func _strategy() -> RefCounted:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	return REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", DeckData.from_dict(raw))


func _state() -> GameState:
	var state := GameState.new()
	for i: int in 2:
		var player := PlayerState.new()
		player.player_index = i
		state.players.append(player)
	state.current_player_index = 0
	state.turn_number = 15
	state.phase = GameState.GamePhase.MAIN
	for i: int in 6:
		state.players[0].prizes.append(_filler("Own prize %d" % i, 0))
		state.players[1].prizes.append(_filler("Opponent prize %d" % i, 1))
	return state


func _card(ref: String) -> CardData:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardData.from_dict(raw) if raw is Dictionary else null


func _energy(symbol: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = "Psychic Energy"
	card.card_type = "Basic Energy"
	card.energy_provides = symbol
	return CardInstance.create(card, 0)


func _defender() -> CardData:
	var card := CardData.new()
	card.name_en = "Active-only defender"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 260
	card.attacks = [{"name": "Strike", "cost": "C", "damage": "30", "text": ""}]
	return card


func _slot(card: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _filler(name: String, owner: int) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.card_type = "Item"
	return CardInstance.create(card, owner)
