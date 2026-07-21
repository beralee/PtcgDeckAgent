class_name TestV18BlazikenDragapultRouteCoreRound1
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800019125
const OTHER_FAMILY_DECK_ID := 800015734
const RULES_PATH := "res://scripts/ai/DeckStrategyV18Rules.gd"
const DELEGATE_PATH := "res://scripts/ai/DeckStrategyV18DragapultFamily.gd"


func test_last_fire_and_psychic_are_protected_until_dragapult_can_attack() -> String:
	var strategy := _wrapper_strategy(DECK_ID)
	if strategy == null:
		return assert_true(false, "Deck 800019125 should resolve through the production V18 registry")
	var state := _base_state()
	var player: PlayerState = state.players[0]
	var dragapult := _slot(_pokemon("Dragapult ex", "Stage 2"), 0)
	var fire := _energy("Fire Energy", "R")
	var psychic := _energy("Psychic Energy", "P")
	var fodder := _item("Disposable Item")
	player.active_pokemon = dragapult
	player.hand.assign([fire, psychic, fodder])

	var fire_priority := int(strategy.call("get_discard_priority_contextual", fire, state, 0))
	var psychic_priority := int(strategy.call("get_discard_priority_contextual", psychic, state, 0))
	var fodder_priority := int(strategy.call("get_discard_priority_contextual", fodder, state, 0))
	dragapult.attached_energy.assign([fire, psychic])
	var ready_fire_priority := int(strategy.call("get_discard_priority_contextual", fire, state, 0))

	var other_strategy := _wrapper_strategy(OTHER_FAMILY_DECK_ID)
	var other_priority := int(other_strategy.call(
		"get_discard_priority_contextual", fire, state, 0
	)) if other_strategy != null else -9999
	var other_base_priority := int(other_strategy.call(
		"get_discard_priority", fire
	)) if other_strategy != null else -9998
	return run_checks([
		assert_eq(strategy.get_script().resource_path, RULES_PATH, "The registry must return the production V18 rules wrapper"),
		assert_eq(_delegate_path(strategy), DELEGATE_PATH, "Deck 800019125 must use DragapultFamily in production"),
		assert_true(fire_priority <= -1000 and fire_priority < fodder_priority, "The last Fire must be protected before Phantom Dive is online"),
		assert_true(psychic_priority <= -1000 and psychic_priority < fodder_priority, "The last Psychic must be protected before Phantom Dive is online"),
		assert_true(ready_fire_priority > fire_priority, "The last-Energy guard must clear after Dragapult becomes attack-ready"),
		assert_eq(other_priority, other_base_priority, "The new contextual guard must not change another Dragapult family deck"),
	])


func test_second_player_tm_route_searches_vessel_before_ultra_ball_without_energy() -> String:
	var strategy := _wrapper_strategy(DECK_ID)
	if strategy == null:
		return assert_true(false, "Deck 800019125 should resolve through the production V18 registry")
	var state := _base_state(2, 1)
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_pokemon("Budew", "Basic"), 0)
	player.bench.append(_slot(_pokemon("Dreepy", "Basic"), 0))
	player.deck.append(_pokemon_instance("Drakloak", "Stage 1"))
	var vessel := _item("Earthen Vessel")
	var ultra_ball := _item("Ultra Ball")
	var context := {"game_state": state, "player_index": 0}
	var step := {"id": "search_item", "max_select": 1}
	var vessel_score := float(strategy.call("score_interaction_target", vessel, step, context))
	var ultra_ball_score := float(strategy.call("score_interaction_target", ultra_ball, step, context))
	return run_checks([
		assert_eq(_delegate_path(strategy), DELEGATE_PATH, "The search decision must run through the production DragapultFamily delegate"),
		assert_true(vessel_score > ultra_ball_score, "A live second-player TM route without hand Energy must search Earthen Vessel before Ultra Ball (vessel=%f ultra=%f)" % [vessel_score, ultra_ball_score]),
	])


func test_ultra_ball_discarding_the_last_rp_core_loses_to_attach_and_end() -> String:
	var strategy := _wrapper_strategy(DECK_ID)
	if strategy == null:
		return assert_true(false, "Deck 800019125 should resolve through the production V18 registry")
	var fixture := _ultra_ball_fixture(false)
	var state: GameState = fixture["state"]
	var player: PlayerState = state.players[0]
	var fire: CardInstance = fixture["fire"]
	var psychic: CardInstance = fixture["psychic"]
	var dreepy: PokemonSlot = fixture["dreepy"]
	var risky_score := _score(strategy, _ultra_ball_action(fixture["ultra_ball"], fire, psychic, fixture["drakloak"]), state)
	var attach_score := _score(strategy, {
		"kind": "attach_energy",
		"card": fire,
		"target_slot": dreepy,
	}, state)
	var end_score := _score(strategy, {"kind": "end_turn"}, state)
	return run_checks([
		assert_true(risky_score < attach_score, "Ultra Ball must lose to preserving and attaching the last RP core (ultra=%f attach=%f)" % [risky_score, attach_score]),
		assert_true(risky_score < end_score, "Ultra Ball must even lose to ending the turn when its resolved discards destroy both last colors (ultra=%f end=%f)" % [risky_score, end_score]),
	])


func test_ultra_ball_remains_live_when_redundant_rp_energy_survives() -> String:
	var strategy := _wrapper_strategy(DECK_ID)
	if strategy == null:
		return assert_true(false, "Deck 800019125 should resolve through the production V18 registry")
	var fixture := _ultra_ball_fixture(true)
	var state: GameState = fixture["state"]
	var safe_score := _score(strategy, _ultra_ball_action(
		fixture["ultra_ball"],
		fixture["fire"],
		fixture["psychic"],
		fixture["drakloak"]
	), state)
	var end_score := _score(strategy, {"kind": "end_turn"}, state)
	return run_checks([
		assert_true(safe_score > end_score, "Ultra Ball must remain playable when one Fire and one Psychic survive its resolved discards (ultra=%f end=%f)" % [safe_score, end_score]),
		assert_true(safe_score > 0.0, "A safe evolution-search Ultra Ball should retain a positive production score (score=%f)" % safe_score),
	])


func _wrapper_strategy(deck_id: int) -> RefCounted:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/decks/%d.json" % deck_id
	))
	if not payload is Dictionary:
		return null
	return REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", DeckData.from_dict(payload))


func _delegate_path(strategy: RefCounted) -> String:
	if strategy == null:
		return ""
	var delegate: Variant = strategy.get("_delegate")
	if not delegate is RefCounted:
		return ""
	var script: Variant = (delegate as RefCounted).get_script()
	return str(script.resource_path) if script is Script else ""


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _ultra_ball_fixture(with_redundancy: bool) -> Dictionary:
	var state := _base_state()
	var player: PlayerState = state.players[0]
	var dreepy := _slot(_pokemon("Dreepy", "Basic"), 0)
	var fire := _energy("Fire Energy A", "R")
	var psychic := _energy("Psychic Energy A", "P")
	var ultra_ball := _item("Ultra Ball")
	var drakloak := _pokemon_instance("Drakloak", "Stage 1")
	player.active_pokemon = dreepy
	player.hand.assign([ultra_ball, fire, psychic])
	player.deck.append(drakloak)
	if with_redundancy:
		player.hand.append(_energy("Fire Energy B", "R"))
		player.hand.append(_energy("Psychic Energy B", "P"))
	return {
		"state": state,
		"dreepy": dreepy,
		"fire": fire,
		"psychic": psychic,
		"ultra_ball": ultra_ball,
		"drakloak": drakloak,
	}


func _ultra_ball_action(
	ultra_ball: CardInstance,
	fire: CardInstance,
	psychic: CardInstance,
	drakloak: CardInstance
) -> Dictionary:
	return {
		"kind": "play_trainer",
		"card": ultra_ball,
		"productive": true,
		"targets": [{
			"discard_cards": [fire, psychic],
			"search_pokemon": [drakloak],
		}],
	}


func _base_state(turn_number: int = 3, first_player_index: int = 1) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = first_player_index
	state.turn_number = turn_number
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		for prize_index: int in 6:
			player.prizes.append(_item("Prize %d" % prize_index, player_index))
		state.players.append(player)
	state.players[1].active_pokemon = _slot(_pokemon("Opponent Active", "Basic"), 1)
	return state


func _pokemon_instance(card_name: String, stage: String, owner_index: int = 0) -> CardInstance:
	return CardInstance.create(_pokemon(card_name, stage), owner_index)


func _pokemon(card_name: String, stage: String) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 320 if stage == "Stage 2" else 100
	card.attacks = [{"name": "Test", "cost": "C", "damage": "10"}]
	return card


func _energy(card_name: String, provides: String, owner_index: int = 0) -> CardInstance:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.card_type = "Basic Energy"
	card.energy_provides = provides
	return CardInstance.create(card, owner_index)


func _item(card_name: String, owner_index: int = 0) -> CardInstance:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.card_type = "Item"
	return CardInstance.create(card, owner_index)


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	return slot
