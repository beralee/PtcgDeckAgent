class_name TestV18PidgeotFluteInteractionRound4
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18PidgeotAcademy.gd")
const RULES_SCRIPT = preload("res://scripts/ai/DeckStrategyV18Rules.gd")
const PIDGEOT_DECK_ID := 800018359

const DANGEROUS_BASICS := [
	{"name": "Miraidon ex", "set_code": "CSV1C", "card_index": "050"},
	{"name": "Raikou V", "set_code": "CS4DaC", "card_index": "137"},
	{"name": "Raichu V", "set_code": "CS5aC", "card_index": "019"},
	{"name": "Iron Hands ex", "set_code": "CSV6C", "card_index": "051"},
	{"name": "Bloodmoon Ursaluna ex", "set_code": "CSV8C", "card_index": "172"},
	{"name": "Mew ex", "set_code": "151C", "card_index": "151"},
	{"name": "Radiant Greninja", "set_code": "CS6.5C", "card_index": "020"},
	{"name": "Fezandipiti ex", "set_code": "CSV8C", "card_index": "135"},
]


func test_all_dangerous_reveals_are_handled_with_an_explicit_empty_pick() -> String:
	var candidates: Array = []
	for spec: Dictionary in DANGEROUS_BASICS:
		candidates.append(_instance(_pokemon(
			str(spec.get("name", "")),
			str(spec.get("set_code", "")),
			str(spec.get("card_index", ""))
		), 1))
	var response: Variant = _strategy().call("pick_interaction_items", candidates, _flute_step(candidates.size()), {})
	if not response is Dictionary:
		return "Flute interaction should return a handled envelope, got %s" % str(response)
	var envelope := response as Dictionary
	var picked: Array = envelope.get("items", [])
	return run_checks([
		assert_true(bool(envelope.get("handled", false)), "An all-dangerous Flute reveal must be explicitly handled"),
		assert_true(picked.is_empty(), "Attackers and engine Basics must all be rejected from the opposing Bench"),
	])


func test_lumineon_and_iron_hands_reveal_selects_only_lumineon() -> String:
	var lumineon := _instance(_pokemon("Lumineon V", "CS5bC", "049"), 1)
	var iron_hands := _instance(_pokemon("Iron Hands ex", "CSV6C", "051"), 1)
	var response: Variant = _strategy().call(
		"pick_interaction_items",
		[lumineon, iron_hands],
		_flute_step(2),
		{}
	)
	if not response is Dictionary:
		return "Flute interaction should return a handled envelope, got %s" % str(response)
	var envelope := response as Dictionary
	var picked: Array = envelope.get("items", [])
	return run_checks([
		assert_true(bool(envelope.get("handled", false)), "The mixed Flute reveal must be explicitly handled"),
		assert_eq(picked.size(), 1, "Only one revealed Basic is a suitable control burden"),
		assert_true(not picked.is_empty() and picked[0] == lumineon, "Lumineon V should be selected while Iron Hands ex is rejected"),
	])


func test_handled_empty_flute_pick_does_not_fall_back_to_max_select() -> String:
	var deck := DeckData.new()
	deck.id = PIDGEOT_DECK_ID
	var rules: RefCounted = RULES_SCRIPT.new()
	rules.call("configure_from_deck", deck)
	var iron_hands := _instance(_pokemon("Iron Hands ex", "CSV6C", "051"), 1)
	var picked: Array = rules.call("pick_interaction_items", [iron_hands], _flute_step(1), {})
	return assert_true(picked.is_empty(), "A handled zero-selection must suppress the generic max_select fallback")


func test_non_flute_interaction_keeps_the_control_delegate_pick() -> String:
	var candidate := _instance(_trainer("Nest Ball"))
	var response: Variant = _strategy().call("pick_interaction_items", [candidate], {
		"id": "search_cards",
		"max_select": 1,
	}, {})
	return run_checks([
		assert_true(response is Array, "Non-Flute interactions should keep the legacy control delegate response"),
		assert_true(response is Array and (response as Array).size() == 1 and (response as Array)[0] == candidate, "The existing control search pick must not regress"),
	])


func test_public_attacker_does_not_prejudge_the_revealed_flute_candidates() -> String:
	var state := _state()
	state.players[1].active_pokemon = _slot(_pokemon("Miraidon ex", "CSV1C", "050"), 1)
	var flute := _instance(_trainer("Accompanying Flute", "CSV8C", "175"))
	var score: float = _strategy().call("score_action_absolute", {
		"kind": "play_trainer",
		"card": flute,
	}, state, 0)
	return assert_true(score >= 2800.0, "Public attackers must not replace the candidate-aware Flute decision (score=%f)" % score)


func _strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = PIDGEOT_DECK_ID
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	strategy.call("configure_from_deck", deck)
	return strategy


func _flute_step(max_select: int) -> Dictionary:
	return {
		"id": "bench_basic_pokemon",
		"min_select": 0,
		"max_select": max_select,
	}


func _state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 4
	state.phase = GameState.GamePhase.MAIN
	player.active_pokemon = _slot(_pokemon("Own Active"))
	opponent.active_pokemon = _slot(_pokemon("Opponent Active"), 1)
	opponent.deck.append(_instance(_trainer("Opponent Deck Card"), 1))
	return state


func _slot(data: CardData, owner_index: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_instance(data, owner_index))
	return slot


func _instance(data: CardData, owner_index: int = 0) -> CardInstance:
	return CardInstance.create(data, owner_index)


func _pokemon(name_en: String, set_code: String = "", card_index: String = "") -> CardData:
	var card := CardData.new()
	card.name = name_en
	card.name_en = name_en
	card.name_zh = name_en
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 200
	card.set_code = set_code
	card.card_index = card_index
	card.attacks = [{"name": "Test Attack", "cost": "C", "damage": "10", "text": ""}]
	return card


func _trainer(name_en: String, set_code: String = "", card_index: String = "") -> CardData:
	var card := CardData.new()
	card.name = name_en
	card.name_en = name_en
	card.name_zh = name_en
	card.card_type = "Item"
	card.set_code = set_code
	card.card_index = card_index
	return card
