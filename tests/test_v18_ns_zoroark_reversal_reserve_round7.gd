class_name TestV18NsZoroarkReversalReserveRound7
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyNsZoroark.gd")
const REVERSAL_EFFECT := "cbadb3473273c14cf667d495d44d111b"


func test_reversal_energy_is_reserved_from_munkidori_for_live_darmanitan_route() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var state := _state()
	var player: PlayerState = state.players[0]
	var munkidori := _slot(_pokemon("Munkidori", "Basic", false))
	var darmanitan := _slot(_pokemon("N's Darmanitan", "Stage 1", false))
	player.active_pokemon = _slot(_pokemon("N's Zoroark ex", "Stage 1", true))
	player.bench.assign([munkidori, darmanitan])
	var reversal := _energy("Reversal Energy", "Special Energy", "C", REVERSAL_EFFECT)
	player.hand.append(reversal)
	var off_route := float(strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": reversal, "target_slot": munkidori,
	}, state, 0))
	var live_route := float(strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": reversal, "target_slot": darmanitan,
	}, state, 0))
	return run_checks([
		assert_true(off_route <= -3000.0, "Reversal Energy must not be parked on Munkidori (score=%f)" % off_route),
		assert_true(live_route >= off_route + 3500.0, "The behind-on-prizes Darmanitan completion must outrank the off-route attachment (live=%f off=%f)" % [live_route, off_route]),
	])


func _state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 12
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	for index: int in 5:
		state.players[0].prizes.append(_item("Own Prize %d" % index, 0))
	for index: int in 3:
		state.players[1].prizes.append(_item("Opponent Prize %d" % index, 1))
	state.players[1].active_pokemon = _slot(_pokemon("Opponent", "Basic", false), 1)
	return state


func _pokemon(name: String, stage: String, rule_box: bool) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.mechanic = "ex" if rule_box else ""
	card.hp = 280 if rule_box else 140
	card.attacks = [{"name": "Test", "cost": "RRC", "damage": "90"}]
	return card


func _energy(name: String, card_type: String, provides: String, effect_id: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = card_type
	card.energy_provides = provides
	card.effect_id = effect_id
	return CardInstance.create(card, 0)


func _item(name: String, owner: int) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.card_type = "Item"
	return CardInstance.create(card, owner)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
