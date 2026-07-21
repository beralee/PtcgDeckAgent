class_name TestV18AcademyGardevoirRecoveryRound2
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800018498


func test_psychic_fuel_only_does_not_raise_recovery_with_attacker_online() -> String:
	var strategy := _strategy()
	var state := _state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _ready_attacker("Scream Tail", "CSV6C", "065")
	player.bench.append(_slot(_pokemon("Gardevoir ex", "Stage 2", "CSV2C", "055")))
	player.discard_pile.append(_instance(_energy("Psychic Energy", "P")))
	var stretcher := _recovery_item("Night Stretcher", "CSV8C", "183")
	var rod := _recovery_item("Super Rod", "CSV1C", "109")
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var trainer_priorities: Array = (plan.get("priorities", {}) as Dictionary).get("trainer", [])
	var context := {"game_state": state, "player_index": 0}
	var search_step := {"id": "search_cards", "max_select": 1}
	var stretcher_search: float = strategy.call("score_interaction_target", stretcher, search_step, context)
	var rod_search: float = strategy.call("score_interaction_target", rod, search_step, context)
	var stretcher_play: float = strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": stretcher,
	}, state, 0)
	var rod_play: float = strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": rod,
	}, state, 0)
	return run_checks([
		assert_false(bool((plan.get("flags", {}) as Dictionary).get("recovery_route_live", true)), "Psychic Embrace fuel alone must not open the recovery route while an attacker is online"),
		assert_false(_has_recovery_priority(trainer_priorities), "A fuel-only plan must remove Night Stretcher and Super Rod from high trainer priorities"),
		assert_true(stretcher_search <= -4000.0 and rod_search <= -4000.0, "Search must reject fuel-only recovery (stretcher=%f rod=%f)" % [stretcher_search, rod_search]),
		assert_true(stretcher_play <= -4000.0 and rod_play <= -4000.0, "Play must reject fuel-only recovery (stretcher=%f rod=%f)" % [stretcher_play, rod_play]),
	])


func test_missing_key_attacker_opens_fast_recovery_ahead_of_super_rod() -> String:
	var strategy := _strategy()
	var state := _state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_pokemon("Gardevoir ex", "Stage 2", "CSV2C", "055"))
	player.discard_pile.append(_instance(_pokemon("Scream Tail", "Basic", "CSV6C", "065")))
	var stretcher := _recovery_item("Night Stretcher", "CSV8C", "183")
	var rod := _recovery_item("Super Rod", "CSV1C", "109")
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var trainer_priorities: Array = (plan.get("priorities", {}) as Dictionary).get("trainer", [])
	var context := {"game_state": state, "player_index": 0}
	var search_step := {"id": "search_cards", "max_select": 1}
	var stretcher_search: float = strategy.call("score_interaction_target", stretcher, search_step, context)
	var rod_search: float = strategy.call("score_interaction_target", rod, search_step, context)
	var stretcher_play: float = strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": stretcher,
	}, state, 0)
	var rod_play: float = strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": rod,
	}, state, 0)
	return run_checks([
		assert_true(bool((plan.get("flags", {}) as Dictionary).get("recovery_route_live", false)), "A discarded missing key attacker should open recovery"),
		assert_eq(_recovery_priority_names(trainer_priorities), ["Night Stretcher", "Super Rod"], "The plan must prefer immediate hand recovery over slow deck recovery"),
		assert_true(stretcher_search >= 5000.0 and stretcher_search >= rod_search + 500.0, "Search should rank Night Stretcher above Super Rod (stretcher=%f rod=%f)" % [stretcher_search, rod_search]),
		assert_true(stretcher_play >= 5000.0 and stretcher_play >= rod_play + 500.0, "Play should rank Night Stretcher above Super Rod (stretcher=%f rod=%f)" % [stretcher_play, rod_play]),
	])


func test_first_gardevoir_and_broken_evolution_line_open_recovery() -> String:
	var strategy := _strategy()
	var first_gardevoir := _state()
	first_gardevoir.players[0].active_pokemon = _slot(_pokemon("Ralts", "Basic", "CSV2C", "053"))
	first_gardevoir.players[0].discard_pile.append(_instance(_pokemon("Gardevoir ex", "Stage 2", "CSV2C", "055")))
	var first_plan: Dictionary = strategy.call("build_turn_plan", first_gardevoir, 0, {})

	var broken_line := _state()
	broken_line.players[0].active_pokemon = _ready_attacker("Drifloon", "CSV2C", "060")
	broken_line.players[0].hand.append(_instance(_pokemon("Gardevoir ex", "Stage 2", "CSV2C", "055")))
	broken_line.players[0].discard_pile.append(_instance(_pokemon("Kirlia", "Stage 1", "CS6.5C", "030")))
	var broken_plan: Dictionary = strategy.call("build_turn_plan", broken_line, 0, {})
	return run_checks([
		assert_true(bool((first_plan.get("flags", {}) as Dictionary).get("recovery_route_live", false)), "A discarded first Gardevoir ex should open recovery"),
		assert_true(bool((broken_plan.get("flags", {}) as Dictionary).get("recovery_route_live", false)), "A discarded missing Kirlia should expose a broken evolution line even with an attacker online"),
	])


func _strategy() -> RefCounted:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/decks/%d.json" % DECK_ID
	))
	return REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", DeckData.from_dict(payload))


func _state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	opponent.active_pokemon = _slot(_pokemon("Opponent Active", "Basic"), 1)
	for index: int in 12:
		player.deck.append(_instance(_trainer("Own deck filler %d" % index)))
	for index: int in 6:
		player.prizes.append(_instance(_trainer("Own Prize %d" % index)))
		opponent.prizes.append(_instance(_trainer("Opponent Prize %d" % index), 1))
	return state


func _ready_attacker(card_name: String, set_code: String, card_index: String) -> PokemonSlot:
	var slot := _slot(_pokemon(card_name, "Basic", set_code, card_index))
	slot.attached_energy.assign([
		_instance(_energy("Psychic Energy", "P")),
		_instance(_energy("Psychic Energy", "P")),
	])
	return slot


func _pokemon(card_name: String, stage: String, set_code: String = "", card_index: String = "") -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.name_zh = card_name
	card.card_type = "Pokemon"
	card.stage = stage
	card.set_code = set_code
	card.card_index = card_index
	card.hp = 310 if card_name == "Gardevoir ex" else 100
	card.attacks = [{"name": "Test Attack", "cost": "PP", "damage": "100", "text": ""}]
	return card


func _energy(card_name: String, symbol: String) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.name_zh = card_name
	card.card_type = "Basic Energy"
	card.energy_type = symbol
	card.energy_provides = symbol
	return card


func _trainer(card_name: String) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.name_zh = card_name
	card.card_type = "Item"
	return card


func _recovery_item(card_name: String, set_code: String, card_index: String) -> CardInstance:
	var card := _trainer(card_name)
	card.set_code = set_code
	card.card_index = card_index
	return _instance(card)


func _slot(card: CardData, owner_index: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot


func _instance(card: CardData, owner_index: int = 0) -> CardInstance:
	return CardInstance.create(card, owner_index)


func _has_recovery_priority(priorities: Array) -> bool:
	return not _recovery_priority_names(priorities).is_empty()


func _recovery_priority_names(priorities: Array) -> Array[String]:
	var names: Array[String] = []
	for priority: Variant in priorities:
		var name := str(priority)
		if name in ["Night Stretcher", "夜间担架"]:
			names.append("Night Stretcher")
		elif name in ["Super Rod", "厉害钓竿"]:
			names.append("Super Rod")
	return names
