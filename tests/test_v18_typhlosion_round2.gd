class_name TestV18TyphlosionRound2
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800018880


func test_tm_evolution_attaches_to_the_funded_active_carrier() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018880 should resolve to its production V18 wrapper")

	var state := _tm_route_state(2, 1)
	var player: PlayerState = state.players[0]
	var carrier := player.active_pokemon
	var cyndaquil := player.bench[0]
	var pidgey := player.bench[1]
	var tm := _tm_evolution()
	var active_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_tool",
		"card": tm,
		"target_slot": carrier,
	}, state, 0)
	var cyndaquil_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_tool",
		"card": tm,
		"target_slot": cyndaquil,
	}, state, 0)
	var pidgey_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_tool",
		"card": tm,
		"target_slot": pidgey,
	}, state, 0)
	carrier.attached_tool = tm
	carrier.attached_energy.clear()
	var fire := _basic_fire()
	var carrier_energy_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy",
		"card": fire,
		"target_slot": carrier,
	}, state, 0)
	var cyndaquil_energy_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy",
		"card": fire,
		"target_slot": cyndaquil,
	}, state, 0)

	return run_checks([
		assert_true(
			active_score >= cyndaquil_score + 2000.0,
			"TM Evolution must attach to the funded Active carrier instead of Cyndaquil (active=%f cyndaquil=%f)" % [active_score, cyndaquil_score]
		),
		assert_true(
			active_score >= pidgey_score + 2000.0,
			"TM Evolution must attach to the funded Active carrier instead of Pidgey (active=%f pidgey=%f)" % [active_score, pidgey_score]
		),
		assert_true(
			carrier_energy_score >= cyndaquil_energy_score + 2000.0,
			"An unfunded Active TM carrier must receive Energy before Cyndaquil (carrier=%f cyndaquil=%f)" % [carrier_energy_score, cyndaquil_energy_score]
		),
	])


func test_first_player_turn_one_makes_every_tm_attachment_negative() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018880 should resolve to its production V18 wrapper")

	var state := _tm_route_state(1, 0)
	var player: PlayerState = state.players[0]
	var tm := _tm_evolution()
	var checks: Array[String] = []
	for target: PokemonSlot in [player.active_pokemon, player.bench[0], player.bench[1]]:
		var score: float = strategy.call("score_action_absolute", {
			"kind": "attach_tool",
			"card": tm,
			"target_slot": target,
		}, state, 0)
		checks.append(assert_true(
			score < 0.0,
			"First-player turn one must keep TM Evolution in hand for every target (target=%s score=%f)" % [target.get_card_data().display_name(), score]
		))
	return run_checks(checks)


func test_tm_evolution_attack_outranks_chip_and_end_turn_when_attacks_are_legal() -> String:
	var strategy := _wrapper_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800018880 should resolve to its production V18 wrapper")

	var state := _tm_route_state(2, 1)
	var carrier := state.players[0].active_pokemon
	carrier.attached_tool = _tm_evolution()
	var tm_score: float = strategy.call("score_action_absolute", {
		"kind": "granted_attack",
		"source_slot": carrier,
		"granted_attack_data": {
			"id": "tm_evolution",
			"name": "Evolution",
			"cost": "C",
			"damage": "",
		},
	}, state, 0)
	var chip_score: float = strategy.call("score_action_absolute", {
		"kind": "attack",
		"source_slot": carrier,
		"attack_index": 0,
		"attack_name": "Chip",
		"projected_damage": 10,
		"projected_knockout": false,
	}, state, 0)
	var end_score: float = strategy.call("score_action_absolute", {"kind": "end_turn"}, state, 0)

	return run_checks([
		assert_true(
			tm_score >= chip_score + 3000.0,
			"TM Evolution must replace the carrier's chip attack while Cyndaquil and Pidgey can evolve (tm=%f chip=%f)" % [tm_score, chip_score]
		),
		assert_true(
			tm_score >= end_score + 3000.0,
			"TM Evolution must outrank ending the legal setup turn (tm=%f end=%f)" % [tm_score, end_score]
		),
	])


func _wrapper_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/decks/%d.json" % DECK_ID))
	if not parsed is Dictionary:
		return null
	var deck := DeckData.from_dict(parsed)
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", deck)


func _tm_route_state(turn_number: int, first_player_index: int) -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	opponent.active_pokemon = _slot(_pokemon("Opponent Active", "TEST", "002", "Basic", 200), 1)
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = first_player_index
	state.turn_number = turn_number
	state.phase = GameState.GamePhase.MAIN

	var carrier := _slot(_pokemon("Active Carrier", "TEST", "001", "Basic", 70), 0)
	carrier.get_card_data().attacks = [{"name": "Chip", "cost": "R", "damage": "10"}]
	carrier.attached_energy.append(_basic_fire())
	player.active_pokemon = carrier
	player.bench.assign([
		_slot(_pokemon("Ethan's Cyndaquil", "CSV10C", "028", "Basic", 70), 0),
		_slot(_pokemon("Pidgey", "151C", "016", "Basic", 60), 0),
	])
	var quilava := _pokemon("Ethan's Quilava", "CSV10C", "029", "Stage 1", 100)
	quilava.evolves_from = "Ethan's Cyndaquil"
	var pidgeotto := _pokemon("Pidgeotto", "151C", "017", "Stage 1", 100)
	pidgeotto.evolves_from = "Pidgey"
	player.deck.assign([
		CardInstance.create(quilava, 0),
		CardInstance.create(pidgeotto, 0),
	])
	return state


func _tm_evolution() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Technical Machine: Evolution"
	card.card_type = "Tool"
	return CardInstance.create(card, 0)


func _basic_fire() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Fire Energy"
	card.card_type = "Basic Energy"
	card.energy_type = "R"
	card.energy_provides = "R"
	return CardInstance.create(card, 0)


func _pokemon(card_name: String, set_code: String, card_index: String, stage: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name_en = card_name
	card.card_type = "Pokemon"
	card.set_code = set_code
	card.card_index = card_index
	card.stage = stage
	card.hp = hp
	return card


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot
