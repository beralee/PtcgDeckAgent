class_name TestV18YanmegaArvenSwitchHandoffRound6
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18Yanmega.gd")


func test_arven_finds_switch_when_a_ready_yanmega_is_blocked_on_the_bench() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var state := _state()
	var switch := _item("Switch")
	var ultra_ball := _item("Ultra Ball")
	var context := {"game_state": state, "player_index": 0}
	var switch_search_score := float(strategy.call(
		"score_interaction_target", switch, {"id": "search_item"}, context
	))
	var ball_search_score := float(strategy.call(
		"score_interaction_target", ultra_ball, {"id": "search_item"}, context
	))
	var switch_play_score := float(strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": switch, "productive": true,
	}, state, 0))
	return run_checks([
		assert_true(switch_search_score >= ball_search_score + 3000.0, "Arven must find Switch instead of more search when a ready Yanmega is trapped on the Bench (switch=%f ball=%f)" % [switch_search_score, ball_search_score]),
		assert_true(switch_play_score >= 4500.0, "The searched Switch must be converted into the Yanmega handoff this turn (score=%f)" % switch_play_score),
	])


func _state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 10
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[0].active_pokemon = _slot(_pokemon("Dunsparce", "Basic", "C"))
	var yanmega := _slot(_pokemon("Yanmega ex", "Stage 1", "GGGC"))
	for index: int in 4:
		yanmega.attached_energy.append(_grass())
	state.players[0].bench.append(yanmega)
	state.players[1].active_pokemon = _slot(_pokemon("Opponent ex", "Basic", "C", true), 1)
	return state


func _pokemon(name: String, stage: String, cost: String, rule_box: bool = false) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.mechanic = "ex" if rule_box or name.ends_with(" ex") else ""
	card.hp = 280 if stage == "Stage 1" else 70
	card.attacks = [{"name": "Test", "cost": cost, "damage": "210"}]
	return card


func _grass() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Grass Energy"
	card.name = "Grass Energy"
	card.card_type = "Basic Energy"
	card.energy_type = "G"
	card.energy_provides = "G"
	return CardInstance.create(card, 0)


func _item(name: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Item"
	return CardInstance.create(card, 0)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
