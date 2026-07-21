class_name TestV18BlazikenSameIdentityUltraBallRound5
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800019125


func test_ultra_ball_does_not_discard_munkidori_to_search_munkidori() -> String:
	var strategy := _strategy()
	var state := _state()
	var ultra_ball := _item("Ultra Ball")
	var discarded_munkidori := _pokemon_instance("Munkidori", "Basic")
	var searched_munkidori := _pokemon_instance("Munkidori", "Basic")
	var poffin := _item("Buddy-Buddy Poffin")
	var same_identity := {
		"kind": "play_trainer",
		"card": ultra_ball,
		"productive": true,
		"targets": [{
			"discard_cards": [poffin, discarded_munkidori],
			"search_pokemon": [searched_munkidori],
		}],
	}
	var constructive := {
		"kind": "play_trainer",
		"card": ultra_ball,
		"productive": true,
		"targets": [{
			"discard_cards": [poffin, _supporter("Arven")],
			"search_pokemon": [_pokemon_instance("Fezandipiti ex", "Basic")],
		}],
	}
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var churn_score := float(strategy.call("score_action_absolute_with_plan", same_identity, state, 0, plan))
	var constructive_score := float(strategy.call("score_action_absolute_with_plan", constructive, state, 0, plan))
	return run_checks([
		assert_true(churn_score <= -4500.0, "Discarding Munkidori to fetch the same identity must lose to ending the turn (score=%f)" % churn_score),
		assert_true(constructive_score >= churn_score + 2500.0, "A non-replacement Ultra Ball line must retire the hard churn guard (constructive=%f churn=%f)" % [constructive_score, churn_score]),
	])


func _strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = DECK_ID
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)


func _state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 11
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	var dragapult := _slot(_pokemon("Dragapult ex", "Stage 2"))
	dragapult.attached_energy.assign([_energy("Fire Energy", "R"), _energy("Psychic Energy", "P")])
	state.players[0].active_pokemon = dragapult
	state.players[0].bench.append(_slot(_pokemon("Blaziken ex", "Stage 2")))
	state.players[1].active_pokemon = _slot(_pokemon("Opponent", "Basic"), 1)
	return state


func _pokemon(name: String, stage: String) -> CardData:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 320 if stage == "Stage 2" else 110
	card.attacks = [{"name": "Test", "cost": "RP", "damage": "200"}]
	return card


func _pokemon_instance(name: String, stage: String) -> CardInstance:
	return CardInstance.create(_pokemon(name, stage), 0)


func _energy(name: String, provides: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.card_type = "Basic Energy"
	card.energy_type = provides
	card.energy_provides = provides
	return CardInstance.create(card, 0)


func _item(name: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Item"
	return CardInstance.create(card, 0)


func _supporter(name: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = name
	card.name = name
	card.card_type = "Supporter"
	return CardInstance.create(card, 0)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
