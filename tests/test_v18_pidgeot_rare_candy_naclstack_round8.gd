class_name TestV18PidgeotRareCandyNaclstackRound8
extends TestBase


const RARE_CANDY_SCRIPT = preload("res://scripts/effects/trainer_effects/EffectRareCandy.gd")


func test_exact_garganacl_rare_candy_identity_reaches_exact_nacli() -> String:
	var nacli_data: CardData = CardDatabase.get_card("SVP", "080")
	var garganacl_data: CardData = CardDatabase.get_card("CSV4C", "074")
	var candy_data: CardData = CardDatabase.get_card("CSVH1C", "045")
	if nacli_data == null or garganacl_data == null or candy_data == null:
		return "Exact Nacli, Garganacl, and Rare Candy cards must load"
	var state := _state()
	var player: PlayerState = state.players[0]
	var nacli := _slot(nacli_data)
	nacli.turn_played = 0
	player.active_pokemon = nacli
	var garganacl := CardInstance.create(garganacl_data, 0)
	var candy := CardInstance.create(candy_data, 0)
	player.hand.assign([garganacl, candy])
	var effect: RefCounted = RARE_CANDY_SCRIPT.new()
	var steps: Array[Dictionary] = effect.call("get_interaction_steps", candy, state)
	var stage2_items: Array = steps[0].get("items", []) if not steps.is_empty() else []
	var target_items: Array = steps[1].get("items", []) if steps.size() > 1 else []
	var can_execute := bool(effect.call("can_execute", candy, state))
	effect.call("execute", candy, [{
		"stage2_card": [garganacl],
		"target_pokemon": [nacli],
	}], state)
	return run_checks([
		assert_eq(str(garganacl_data.evolves_from), "盐石垒", "Exact Garganacl must retain its Naclstack identity"),
		assert_true(can_execute, "Rare Candy must recognize the legal Nacli-to-Garganacl identity chain"),
		assert_true(garganacl in stage2_items, "Exact Garganacl must appear in the Rare Candy Stage 2 choices"),
		assert_true(nacli in target_items, "Exact Nacli must appear as Garganacl's Rare Candy target"),
		assert_true(nacli.get_top_card() == garganacl, "Rare Candy must evolve exact Nacli directly into exact Garganacl"),
	])


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 5
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[1].active_pokemon = _slot(_opponent(), 1)
	return state


func _opponent() -> CardData:
	var card := CardData.new()
	card.name_en = "Opponent"
	card.name = "Opponent"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 220
	card.attacks = [{"name": "Test", "cost": "C", "damage": "10"}]
	return card


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot
