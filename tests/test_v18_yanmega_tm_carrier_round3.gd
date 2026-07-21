class_name TestV18YanmegaTMCarrierRound3
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18Yanmega.gd")


func test_qualified_active_tm_carrier_evolves_before_tm_attack() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var fixture := _fixture()
	var state: GameState = fixture["state"]
	var player: PlayerState = state.players[0]
	var yanmega: CardInstance = fixture["yanmega"]
	var active_score := _evolve_score(strategy, state, yanmega, player.active_pokemon)
	var bench_score := _evolve_score(strategy, state, yanmega, player.bench[0])
	var tm_score: float = strategy.call("score_action_absolute", {
		"kind": "granted_attack",
		"source_slot": player.active_pokemon,
		"granted_attack_data": {
			"id": "tm_evolution",
			"name": "Evolution",
			"cost": "C",
		},
	}, state, 0)
	return run_checks([
		assert_true(
			bool(strategy.call("_should_harden_active_tm_carrier", player)),
			"The exact two-target Active Yanma TM route should enable carrier hardening"
		),
		assert_true(
			active_score >= tm_score + 500.0,
			"The qualified Active Yanma must evolve before using TM Evolution (active=%f tm=%f)" % [active_score, tm_score]
		),
		assert_true(
			active_score >= bench_score + 500.0,
			"Carrier hardening must outrank the normal Bench Yanma evolution preference (active=%f bench=%f)" % [active_score, bench_score]
		),
	])


func test_active_tm_carrier_guard_requires_every_route_fact() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var no_energy := _fixture()
	(no_energy["state"] as GameState).players[0].active_pokemon.attached_energy.clear()
	var no_hand_yanmega := _fixture()
	(no_hand_yanmega["state"] as GameState).players[0].hand.clear()
	var evolved_active := _fixture()
	var evolved_player: PlayerState = (evolved_active["state"] as GameState).players[0]
	evolved_player.active_pokemon = _slot(_yanmega())
	evolved_player.active_pokemon.attached_tool = _tm_evolution()
	evolved_player.active_pokemon.attached_energy.append(_grass_energy())
	var one_bench_yanma := _fixture()
	(one_bench_yanma["state"] as GameState).players[0].bench.pop_back()
	var one_tm_target := _fixture()
	(one_tm_target["state"] as GameState).players[0].deck.pop_back()
	return run_checks([
		assert_false(
			bool(strategy.call("_should_harden_active_tm_carrier", (no_energy["state"] as GameState).players[0])),
			"An unfunded Active Yanma must not trigger carrier hardening"
		),
		assert_false(
			bool(strategy.call("_should_harden_active_tm_carrier", (no_hand_yanmega["state"] as GameState).players[0])),
			"Carrier hardening requires Yanmega ex in hand"
		),
		assert_false(
			bool(strategy.call("_should_harden_active_tm_carrier", evolved_player)),
			"Carrier hardening applies only while the Active Pokemon is still Yanma"
		),
		assert_false(
			bool(strategy.call("_should_harden_active_tm_carrier", (one_bench_yanma["state"] as GameState).players[0])),
			"Carrier hardening requires at least two Bench Yanma"
		),
		assert_false(
			bool(strategy.call("_should_harden_active_tm_carrier", (one_tm_target["state"] as GameState).players[0])),
			"Carrier hardening requires exactly two executable TM Evolution targets"
		),
	])


func test_no_tm_mirror_keeps_bench_evolution_priority() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var fixture := _fixture()
	var state: GameState = fixture["state"]
	var player: PlayerState = state.players[0]
	var yanmega: CardInstance = fixture["yanmega"]
	player.active_pokemon.attached_tool = null
	var active_score := _evolve_score(strategy, state, yanmega, player.active_pokemon)
	var bench_score := _evolve_score(strategy, state, yanmega, player.bench[0])
	return run_checks([
		assert_false(
			bool(strategy.call("_should_harden_active_tm_carrier", player)),
			"The no-TM mirror must not harden the Active Yanma"
		),
		assert_true(
			bench_score >= active_score + 500.0,
			"Without TM, Yanmega ex must retain its Bench evolution preference (bench=%f active=%f)" % [bench_score, active_score]
		),
	])


func _fixture() -> Dictionary:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN
	player.active_pokemon = _slot(_yanma())
	player.active_pokemon.attached_tool = _tm_evolution()
	player.active_pokemon.attached_energy.append(_grass_energy())
	player.bench.assign([_slot(_yanma()), _slot(_yanma())])
	var yanmega := CardInstance.create(_yanmega(), 0)
	player.hand.append(yanmega)
	player.deck.assign([
		CardInstance.create(_yanmega(), 0),
		CardInstance.create(_yanmega(), 0),
	])
	return {"state": state, "yanmega": yanmega}


func _evolve_score(
	strategy: RefCounted,
	state: GameState,
	evolution: CardInstance,
	target: PokemonSlot
) -> float:
	return strategy.call("score_action_absolute", {
		"kind": "evolve",
		"card": evolution,
		"target_slot": target,
	}, state, 0)


func _yanma() -> CardData:
	var card := CardData.new()
	card.name_en = "Yanma"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 70
	return card


func _yanmega() -> CardData:
	var card := CardData.new()
	card.name_en = "Yanmega ex"
	card.card_type = "Pokemon"
	card.stage = "Stage 1"
	card.evolves_from = "Yanma"
	card.hp = 280
	card.mechanic = "ex"
	card.attacks = [{"name": "Jet Cyclone", "cost": "GGGC", "damage": "210"}]
	return card


func _tm_evolution() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Technical Machine: Evolution"
	card.card_type = "Pokemon Tool"
	return CardInstance.create(card, 0)


func _grass_energy() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Grass Energy"
	card.card_type = "Basic Energy"
	card.energy_type = "G"
	card.energy_provides = "G"
	return CardInstance.create(card, 0)


func _slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
