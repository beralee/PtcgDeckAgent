class_name TestV18DragapultReadyAttackContinuityRound5
extends TestBase


const FAMILY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18DragapultFamily.gd")
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800015734


func test_ready_dragapult_can_phantom_dive_through_residual_setup_debt() -> String:
	var fixture := _fixture(true, 6)
	var strategy := _strategy()
	var state: GameState = fixture["state"]
	var contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
	var attack := _phantom_dive(fixture["dragapult"], false)
	var attack_score := _score(strategy, attack, state)
	var end_turn_score := _score(strategy, {"kind": "end_turn"}, state)
	return run_checks([
		assert_true(int(((contract.get("setup_debt", {}) as Dictionary).get("delegate", {}) as Dictionary).get("total", 0)) > 0, "The ready fixture must retain residual setup debt"),
		assert_false(bool(contract.get("safe_setup_before_attack", true)), "Ready deck 800015734 must not make residual debt suppress Phantom Dive"),
		assert_true(attack_score > end_turn_score, "A legal non-lethal Phantom Dive must outrank end_turn when Dragapult is ready (attack=%f end=%f)" % [attack_score, end_turn_score]),
	])


func test_unready_dragapult_keeps_setup_penalty_above_no_legal_attack() -> String:
	var fixture := _fixture(false, 6)
	var strategy := _strategy()
	var state: GameState = fixture["state"]
	var contract: Dictionary = strategy.call("build_continuity_contract", state, 0, {})
	var attack_score := _score(strategy, _phantom_dive(fixture["dragapult"], false), state)
	var end_turn_score := _score(strategy, {"kind": "end_turn"}, state)
	return run_checks([
		assert_true(bool(contract.get("safe_setup_before_attack", false)), "An unready Dragapult must retain the setup continuity contract"),
		assert_true(attack_score < end_turn_score, "Setup debt must still suppress a Phantom Dive when no Dragapult is ready (attack=%f end=%f)" % [attack_score, end_turn_score]),
	])


func test_ready_final_prize_phantom_dive_remains_preferred() -> String:
	var fixture := _fixture(true, 1)
	var strategy := _strategy()
	var state: GameState = fixture["state"]
	var attack_score := _score(strategy, _phantom_dive(fixture["dragapult"], true), state)
	var end_turn_score := _score(strategy, {"kind": "end_turn"}, state)
	return assert_true(
		attack_score > end_turn_score,
		"Final-prize Phantom Dive must remain preferred after the continuity adjustment (attack=%f end=%f)" % [attack_score, end_turn_score]
	)


func _strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = DECK_ID
	var strategy: RefCounted = REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)
	return strategy


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _phantom_dive(source: PokemonSlot, projected_knockout: bool) -> Dictionary:
	return {
		"kind": "attack",
		"source_slot": source,
		"attack_index": 1,
		"attack_name": "Phantom Dive",
		"projected_damage": 200,
		"projected_knockout": projected_knockout,
	}


func _fixture(ready: bool, prize_count: int) -> Dictionary:
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
	_set_prizes(player, prize_count)
	_set_prizes(opponent, 6)
	var dragapult := _slot(_pokemon("Dragapult ex", 320, "ex"), 0)
	dragapult.attached_energy.append(CardInstance.create(_energy("Fire Energy", "R"), 0))
	if ready:
		dragapult.attached_energy.append(CardInstance.create(_energy("Psychic Energy", "P"), 0))
	player.active_pokemon = dragapult
	if ready:
		player.bench.append(_slot(_pokemon("Dreepy", 70), 0))
	opponent.active_pokemon = _slot(_pokemon("Target", 220, "ex"), 1)
	return {"state": state, "dragapult": dragapult}


func _set_prizes(player: PlayerState, count: int) -> void:
	for index in count:
		var prize := CardData.new()
		prize.name = "Prize %d" % index
		prize.name_en = prize.name
		prize.card_type = "Item"
		player.prizes.append(CardInstance.create(prize, player.player_index))


func _pokemon(name: String, hp: int, mechanic: String = "") -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Stage 2" if name == "Dragapult ex" else "Basic"
	card.hp = hp
	card.mechanic = mechanic
	card.attacks = [
		{"name": "Test", "cost": "C", "damage": "10"},
		{"name": "Phantom Dive", "cost": "RP", "damage": "200"},
	]
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
