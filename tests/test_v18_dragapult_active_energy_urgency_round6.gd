class_name TestV18DragapultActiveEnergyUrgencyRound6
extends TestBase


const STRATEGY_REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const AI_OPPONENT_SCRIPT = preload("res://scripts/ai/AIOpponent.gd")
const AI_LEGAL_ACTION_BUILDER_SCRIPT = preload("res://scripts/ai/AILegalActionBuilder.gd")
const DECK_ID := 800015734


func test_t13_active_attachment_completion_outranks_benched_line() -> String:
	var fixture := _fixture("P", true)
	var strategy: RefCounted = _strategy()
	var state: GameState = fixture["state"]
	var player: PlayerState = state.players[0]
	var fire: CardInstance = fixture["fire"]
	var active_score := _score(strategy, {
		"kind": "attach_energy",
		"card": fire,
		"target_slot": player.active_pokemon,
	}, state)
	var bench_score := _score(strategy, {
		"kind": "attach_energy",
		"card": fire,
		"target_slot": fixture["bench_dreepy"],
	}, state)
	return run_checks([
		assert_true(active_score > bench_score, "A single Fire attachment completing Active Phantom Dive must outrank bench-line attachment (active=%f bench=%f)" % [active_score, bench_score]),
		assert_true(active_score >= bench_score + 1000.0, "The Active completion urgency should be decisive (active=%f bench=%f)" % [active_score, bench_score]),
	])


func test_t13_urgency_requires_a_single_typed_completion() -> String:
	var strategy: RefCounted = _strategy()
	var ready_fixture := _fixture("ready", false)
	var ready_state: GameState = ready_fixture["state"]
	var ready_player: PlayerState = ready_state.players[0]
	var ready_score := _score(strategy, {"kind": "attach_energy", "card": ready_fixture["fire"], "target_slot": ready_player.active_pokemon}, ready_state)

	var wrong_fixture := _fixture("P", true)
	var wrong_state: GameState = wrong_fixture["state"]
	var wrong_player: PlayerState = wrong_state.players[0]
	var psychic: CardInstance = wrong_fixture["psychic"]
	var wrong_score := _score(strategy, {"kind": "attach_energy", "card": psychic, "target_slot": wrong_player.active_pokemon}, wrong_state)

	var unready_fixture := _fixture("unready", true)
	var unready_state: GameState = unready_fixture["state"]
	var unready_player: PlayerState = unready_state.players[0]
	var unready_score := _score(strategy, {"kind": "attach_energy", "card": unready_fixture["fire"], "target_slot": unready_player.active_pokemon}, unready_state)
	var unready_bench_score := _score(strategy, {"kind": "attach_energy", "card": unready_fixture["fire"], "target_slot": unready_fixture["bench_dreepy"]}, unready_state)

	return run_checks([
		assert_true(ready_score < ACTIVE_BASELINE(), "Already-ready Active must not receive urgency (score=%f)" % ready_score),
		assert_true(wrong_score < ACTIVE_BASELINE(), "Wrong-type attachment must not receive urgency (score=%f)" % wrong_score),
		assert_true(unready_score < unready_bench_score, "An unready Active must not be promoted over the bench line (active=%f bench=%f)" % [unready_score, unready_bench_score]),
	])


func test_replay_route_guard_selects_the_active_completion() -> String:
	var fixture := _fixture("P", true)
	var state: GameState = fixture["state"]
	var player: PlayerState = state.players[0]
	var strategy: RefCounted = _strategy()
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var builder := AI_LEGAL_ACTION_BUILDER_SCRIPT.new()
	builder.set_deck_strategy(strategy)
	var actions: Array[Dictionary] = builder.build_actions(gsm, 0)
	var ai = AI_OPPONENT_SCRIPT.new()
	ai.player_index = 0
	ai.decision_runtime_mode = "rules_only"
	ai.call("set_deck_strategy", strategy)
	var best: Dictionary = ai._pick_best_absolute(actions, gsm, ai._build_turn_contract(gsm, {"prompt_kind": "action_selection"}))
	var chosen: Dictionary = best.get("action", {}) if best.get("action", {}) is Dictionary else {}
	return run_checks([
		assert_eq(str(chosen.get("kind", "")), "attach_energy", "The replay route guard should choose an Energy attachment"),
		assert_true(chosen.get("target_slot", null) == player.active_pokemon, "The replay route guard should keep the Active as attachment target"),
		assert_eq(chosen.get("card", null), fixture["fire"], "The replay route guard should choose the completing Fire attachment"),
	])


func _strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = DECK_ID
	return STRATEGY_REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func ACTIVE_BASELINE() -> float:
	return 5000.0


func _fixture(active_missing: String, include_bench: bool) -> Dictionary:
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 8
	state.phase = GameState.GamePhase.MAIN
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	var active := _slot(_pokemon("Dragapult ex", 320, "ex"), 0)
	if active_missing == "ready":
		active.attached_energy.append(CardInstance.create(_energy("Fire Energy", "R"), 0))
		active.attached_energy.append(CardInstance.create(_energy("Psychic Energy", "P"), 0))
	else:
		active.attached_energy.append(CardInstance.create(
			_energy("Psychic Energy", "P") if active_missing == "P" else _energy("Fire Energy", "R"),
			0
		))
	player.active_pokemon = active
	var bench_dreepy := _slot(_pokemon("Dreepy", 70), 0)
	if include_bench:
		bench_dreepy.attached_energy.append(CardInstance.create(_energy("Psychic Energy", "P"), 0))
	player.bench.append(bench_dreepy)
	var fire := CardInstance.create(_energy("Fire Energy", "R"), 0)
	var psychic := CardInstance.create(_energy("Psychic Energy", "P"), 0)
	player.hand.assign([fire, psychic])
	opponent.active_pokemon = _slot(_pokemon("Target", 220, "ex"), 1)
	return {"state": state, "fire": fire, "psychic": psychic, "bench_dreepy": bench_dreepy}


func _pokemon(name: String, hp: int, mechanic: String = "") -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Stage 2" if name == "Dragapult ex" else "Basic"
	card.hp = hp
	card.mechanic = mechanic
	card.attacks = [{"name": "Phantom Dive", "cost": "RP", "damage": "200"}]
	return card


func _energy(name: String, provides: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Basic Energy"
	card.energy_provides = provides
	return card


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot
