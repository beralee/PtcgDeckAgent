class_name TestV18CynthiaSecretBoxTMForecastRound3
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const ACTION_BUILDER_SCRIPT = preload("res://scripts/ai/AILegalActionBuilder.gd")
const SECRET_BOX_EFFECT_SCRIPT = preload("res://scripts/effects/trainer_effects/EffectSecretBox.gd")
const DECK_PATH := "res://data/bundled_user/decks/800018543.json"


func test_secret_box_pairs_pending_poffin_with_tm_evolution() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_true(false, "Cynthia's production strategy should resolve")
	var fixture := _fixture(2, 1)
	var state: GameState = fixture["state"]
	var tm: CardInstance = fixture["tm"]
	var weight: CardInstance = fixture["weight"]
	var context := {
		"game_state": state,
		"player_index": 0,
		"pending_effect_card": fixture["secret_box"],
		"search_item": [fixture["poffin"]],
	}
	var selected: Array = strategy.call(
		"pick_interaction_items",
		[weight, tm],
		{"id": "search_tool", "max_select": 1},
		context
	)
	var tm_score: float = strategy.call("score_interaction_target", tm, {"id": "search_tool"}, context)
	var weight_score: float = strategy.call("score_interaction_target", weight, {"id": "search_tool"}, context)
	return run_checks([
		assert_eq(selected, [tm], "Secret Box should pair its pending Poffin route with TM Evolution"),
		assert_true(tm_score >= 6200.0, "The forecast TM route should receive the explicit score floor"),
		assert_true(tm_score > weight_score, "The live TM route must outrank Cynthia's Power Weight"),
	])


func test_tm_forecast_requires_pending_poffin_but_allows_first_turn_prefetch() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_true(false, "Cynthia's production strategy should resolve")
	var second_player := _fixture(2, 1)
	var second_state: GameState = second_player["state"]
	var no_poffin_context := {
		"game_state": second_state,
		"player_index": 0,
		"pending_effect_card": second_player["secret_box"],
		"search_item": [],
	}
	var first_player := _fixture(1, 0)
	var first_state: GameState = first_player["state"]
	var locked_context := {
		"game_state": first_state,
		"player_index": 0,
		"pending_effect_card": first_player["secret_box"],
		"search_item": [first_player["poffin"]],
	}
	var no_poffin_score: float = strategy.call("score_interaction_target", second_player["tm"], {"id": "search_tool"}, no_poffin_context)
	var locked_score: float = strategy.call("score_interaction_target", first_player["tm"], {"id": "search_tool"}, locked_context)
	return run_checks([
		assert_true(no_poffin_score < 6200.0, "TM forecast must stay off without a pending Poffin selection"),
		assert_true(locked_score >= 6200.0, "The first player may prefetch TM Evolution for the pending Poffin route"),
	])


func test_first_turn_secret_box_builder_pairs_real_poffin_with_tm() -> String:
	var strategy := _strategy()
	if strategy == null:
		return assert_true(false, "Cynthia's production strategy should resolve")
	var fixture := _fixture(1, 0)
	var state: GameState = fixture["state"]
	var secret_box: CardInstance = fixture["secret_box"]
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var builder := ACTION_BUILDER_SCRIPT.new()
	builder.set_deck_strategy(strategy)
	var steps: Array[Dictionary] = SECRET_BOX_EFFECT_SCRIPT.new().get_interaction_steps(secret_box, state)
	var targets: Variant = builder._build_headless_targets_from_steps(gsm, 0, 0, steps, secret_box)
	var context: Dictionary = {} if not targets is Array or targets.is_empty() else targets[0]
	var selected_items: Array = context.get("search_item", [])
	var selected_tools: Array = context.get("search_tool", [])
	return run_checks([
		assert_eq(selected_items, [fixture["poffin"]], "The real Secret Box flow should select its only Item, Poffin"),
		assert_eq(selected_tools, [fixture["tm"]], "The production builder should carry Poffin into the turn-one TM forecast"),
	])


func _strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	if not parsed is Dictionary:
		return null
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(DeckData.from_dict(parsed))


func _fixture(turn_number: int, first_player_index: int) -> Dictionary:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = first_player_index
	state.turn_number = turn_number
	state.phase = GameState.GamePhase.MAIN
	player.active_pokemon = _slot(_pokemon("Setup Pivot"), 0)
	opponent.active_pokemon = _slot(_pokemon("Opponent"), 1)
	var tm := _real_card("CSV5C_119")
	var weight := _real_card("CSV10C_200")
	var secret_box := _real_card("CSV8C_176")
	var poffin := _real_card("CSV7C_177")
	player.hand.assign([
		secret_box,
		CardInstance.create(_pokemon("Discard One"), 0),
		CardInstance.create(_pokemon("Discard Two"), 0),
		CardInstance.create(_pokemon("Discard Three"), 0),
	])
	player.deck.assign([
		_real_card("CSV10C_111"),
		_real_card("CSV10C_004"),
		_real_card("CSV10C_112"),
		_real_card("CSV10C_005"),
		poffin,
		tm,
		weight,
	])
	return {
		"state": state,
		"tm": tm,
		"weight": weight,
		"secret_box": secret_box,
		"poffin": poffin,
	}


func _real_card(ref: String) -> CardInstance:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % ref))
	return CardInstance.create(CardData.from_dict(parsed), 0) if parsed is Dictionary else null


func _pokemon(name_en: String) -> CardData:
	var card := CardData.new()
	card.name = name_en
	card.name_en = name_en
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 100
	card.attacks = [{"name": "Chip", "cost": "C", "damage": "10"}]
	return card


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot
