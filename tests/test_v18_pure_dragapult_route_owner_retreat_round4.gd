class_name TestV18PureDragapultRouteOwnerRetreatRound4
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategy175PureDragapult.gd")


func test_drakloak_keeps_the_only_attached_bridge_energy_until_hand_can_repay_both_colors() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var unsafe := _state()
	var unsafe_player: PlayerState = unsafe.players[0]
	unsafe_player.active_pokemon.attached_energy.append(_energy("Fire Energy", "Basic Energy", "R"))
	unsafe_player.hand.append(_energy("Luminous Energy", "Special Energy", "ANY", "540ee48bb93584e4bfe3d7f5d0ee0efc"))
	var unsafe_score := float(strategy.call("score_action_absolute", {"kind": "retreat"}, unsafe, 0))

	var safe := _state()
	var safe_player: PlayerState = safe.players[0]
	safe_player.active_pokemon.attached_energy.append(_energy("Fire Energy", "Basic Energy", "R"))
	safe_player.hand.append(_energy("Luminous Energy", "Special Energy", "ANY", "540ee48bb93584e4bfe3d7f5d0ee0efc"))
	safe_player.hand.append(_energy("Psychic Energy", "Basic Energy", "P"))
	var safe_score := float(strategy.call("score_action_absolute", {"kind": "retreat"}, safe, 0))
	return run_checks([
		assert_true(unsafe_score <= -2000.0, "Retreat must not discard the only Fire bridge when only one follow-up Energy exists (score=%f)" % unsafe_score),
		assert_true(safe_score >= unsafe_score + 1500.0, "A complete two-card hand repayment route should release the hard retreat reserve (safe=%f unsafe=%f)" % [safe_score, unsafe_score]),
	])


func _state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[0].active_pokemon = _slot(_pokemon("Drakloak", "Stage 1", 1))
	state.players[0].bench.append(_slot(_pokemon("Budew", "Basic", 0)))
	state.players[1].active_pokemon = _slot(_pokemon("Opponent", "Basic", 1), 1)
	return state


func _pokemon(name: String, stage: String, retreat: int) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 100
	card.retreat_cost = retreat
	card.attacks = [{"name": "Test", "cost": "C", "damage": "30"}]
	return card


func _energy(name: String, card_type: String, provides: String, effect_id: String = "") -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = card_type
	card.energy_type = provides
	card.energy_provides = provides
	card.effect_id = effect_id
	return CardInstance.create(card, 0)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
