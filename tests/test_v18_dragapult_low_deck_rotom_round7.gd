class_name TestV18DragapultLowDeckRotomRound7
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const ACTION_BUILDER_SCRIPT = preload("res://scripts/ai/AILegalActionBuilder.gd")
const CURSE_BLAST_DECK_ID := 800015734
const BLAZIKEN_DECK_ID := 800019125
const ROTOM_PATH := "res://data/bundled_user/cards/CS6.5C_023.json"
const FOREST_SEAL_PATH := "res://data/bundled_user/cards/CS6.5C_066.json"


func test_three_card_deck_prefers_end_turn_over_rotom_draw() -> String:
	var state := _fixture(3)
	var strategy := _strategy(CURSE_BLAST_DECK_ID)
	var rotom_action := _legal_ability_action(strategy, state, 0)
	var rotom_score := _score(strategy, rotom_action, state)
	var end_turn_score := _score(strategy, {"kind": "end_turn"}, state)
	return run_checks([
		assert_false(rotom_action.is_empty(), "The real Rotom card must expose Fast Charge as ability index 0"),
		assert_true(
			rotom_score < end_turn_score,
			"Rotom must not draw the final three cards instead of passing (Rotom=%f end=%f)" % [rotom_score, end_turn_score]
		),
	])


func test_forest_seal_granted_ability_is_not_suppressed_with_rotom_draw() -> String:
	var state := _fixture(3, true)
	var strategy := _strategy(CURSE_BLAST_DECK_ID)
	var rotom_action := _legal_ability_action(strategy, state, 0)
	var forest_seal_action := _legal_ability_action(strategy, state, 1)
	var rotom_score := _score(strategy, rotom_action, state)
	var forest_seal_score := _score(strategy, forest_seal_action, state)
	return run_checks([
		assert_false(rotom_action.is_empty(), "Fast Charge must remain a real legal action before scoring"),
		assert_false(forest_seal_action.is_empty(), "Forest Seal Stone must grant ability index 1 to Rotom V"),
		assert_eq(str(forest_seal_action.get("ability_source_name_en", "")), "Forest Seal Stone", "The granted action must identify Forest Seal Stone as its source"),
		assert_true(forest_seal_score > rotom_score + 1000.0, "Low-deck suppression must apply only to Fast Charge (Rotom=%f Forest=%f)" % [rotom_score, forest_seal_score]),
	])


func test_low_deck_rotom_guard_is_limited_to_curse_blast_variant() -> String:
	var state := _fixture(3)
	var curse_strategy := _strategy(CURSE_BLAST_DECK_ID)
	var sibling_strategy := _strategy(BLAZIKEN_DECK_ID)
	var rotom_action := _legal_ability_action(curse_strategy, state, 0)
	var curse_score := _score(curse_strategy, rotom_action, state)
	var sibling_score := _score(sibling_strategy, rotom_action, state)
	return assert_true(
		sibling_score > curse_score + 1000.0,
		"The emergency Rotom suppression must not leak into sibling Dragapult variants (curse=%f sibling=%f)" % [curse_score, sibling_score]
	)


func _strategy(deck_id: int) -> RefCounted:
	var deck := DeckData.new()
	deck.id = deck_id
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck)


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _legal_ability_action(strategy: RefCounted, state: GameState, ability_index: int) -> Dictionary:
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var builder := ACTION_BUILDER_SCRIPT.new()
	builder.set_deck_strategy(strategy)
	for action: Dictionary in builder.build_actions(gsm, 0):
		if str(action.get("kind", "")) == "use_ability" \
				and action.get("source_slot", null) == state.players[0].active_pokemon \
				and int(action.get("ability_index", -1)) == ability_index:
			return action
	return {}


func _fixture(deck_count: int, attach_forest_seal: bool = false) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 20
	state.phase = GameState.GamePhase.MAIN
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	player.active_pokemon = _slot(_load_card(ROTOM_PATH), 0)
	if attach_forest_seal:
		player.active_pokemon.attached_tool = CardInstance.create(_load_card(FOREST_SEAL_PATH), 0)
	var dragapult := _slot(_pokemon("Dragapult ex", 320, "ex"), 0)
	dragapult.attached_energy.append(CardInstance.create(_energy("Fire Energy", "R"), 0))
	dragapult.attached_energy.append(CardInstance.create(_energy("Psychic Energy", "P"), 0))
	player.bench.append(dragapult)
	opponent.active_pokemon = _slot(_pokemon("Target", 220, "ex"), 1)
	for index in deck_count:
		var filler := CardData.new()
		filler.name = "Deck card %d" % index
		filler.name_en = filler.name
		filler.card_type = "Item"
		player.deck.append(CardInstance.create(filler, 0))
	return state


func _load_card(path: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CardData.from_dict(parsed as Dictionary)


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
