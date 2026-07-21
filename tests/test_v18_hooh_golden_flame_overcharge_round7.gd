class_name TestV18HoOhGoldenFlameOverchargeRound7
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18EthanHoOh.gd")


func test_golden_flame_preserves_fire_after_every_benched_ho_oh_is_ready() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var saturated := _state(false)
	var ready_source: PokemonSlot = saturated.players[0].bench[0]
	var saturated_score := float(strategy.call("score_action_absolute", {
		"kind": "use_ability", "source_slot": ready_source,
	}, saturated, 0))
	var live := _state(true)
	var live_score := float(strategy.call("score_action_absolute", {
		"kind": "use_ability", "source_slot": live.players[0].bench[0],
	}, live, 0))
	var step := {
		"id": "attach_fire_to_benched_ethan",
		"max_select": 2,
		"source_items": [live.players[0].hand[0]],
	}
	var context := {"game_state": live, "player_index": 0}
	var ready_target_score := float(strategy.call("score_interaction_target", live.players[0].bench[0], step, context))
	var partial_target_score := float(strategy.call("score_interaction_target", live.players[0].bench[1], step, context))
	return run_checks([
		assert_true(saturated_score <= -2500.0, "Golden Flame must preserve Fire when every legal Ho-Oh target already has four Energy (score=%f)" % saturated_score),
		assert_true(live_score >= saturated_score + 5000.0, "The Ability must turn back on for a partial backup Ho-Oh (live=%f saturated=%f)" % [live_score, saturated_score]),
		assert_true(partial_target_score >= ready_target_score + 4000.0, "Golden Flame must attach to the incomplete Ho-Oh instead of overcharging the ready one (partial=%f ready=%f)" % [partial_target_score, ready_target_score]),
	])


func _state(with_partial_backup: bool) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 7
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[0].active_pokemon = _slot(_pokemon("Armarouge", "Stage 1", "RRC"))
	var ready := _slot(_pokemon("Ethan's Ho-Oh ex", "Basic", "RRRR"))
	for index: int in 4:
		ready.attached_energy.append(_fire())
	state.players[0].bench.append(ready)
	if with_partial_backup:
		var partial := _slot(_pokemon("Ethan's Ho-Oh ex", "Basic", "RRRR"))
		partial.attached_energy.append(_fire())
		partial.attached_energy.append(_fire())
		state.players[0].bench.append(partial)
	state.players[0].hand.append(_fire())
	state.players[1].active_pokemon = _slot(_pokemon("Opponent", "Basic", "C"), 1)
	return state


func _pokemon(name: String, stage: String, cost: String) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 230
	card.attacks = [{"name": "Test", "cost": cost, "damage": "160"}]
	return card


func _fire() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Fire Energy"
	card.name = "Fire Energy"
	card.card_type = "Basic Energy"
	card.energy_type = "R"
	card.energy_provides = "R"
	return CardInstance.create(card, 0)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
