class_name TestV18NoBalloonGardevoirEmbraceRound3
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_PATH := "res://data/bundled_user/decks/800017097.json"


func test_embrace_conversion_owns_one_prize_attacker_when_one_energy_reduces_attack_tier() -> String:
	var strategy := _registry_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800017097 should resolve through DeckStrategyRegistry")

	var state := _conversion_state(180)
	var player: PlayerState = state.players[0]
	var drifloon := _slot(_real_card_data("CSV2C_060"))
	drifloon.damage_counters = 40
	_attach_psychic(drifloon)
	_attach_psychic(drifloon)
	var gardevoir := _slot(_real_card_data("CSV2C_055"))
	player.active_pokemon = drifloon
	player.bench.assign([gardevoir])

	var targets: Array = [gardevoir, drifloon]
	var step := {"id": "embrace_target", "max_select": 1}
	var context := {"game_state": state, "player_index": 0, "all_items": targets}
	var attacker_score: float = strategy.call("score_interaction_target", drifloon, step, context)
	var insurance_score: float = strategy.call("score_interaction_target", gardevoir, step, context)
	var picked: Array = strategy.call("pick_interaction_items", targets, step, context)

	return run_checks([
		assert_true(
			attacker_score >= insurance_score + 500.0,
			"A 120-to-180 damage Embrace should move the 180 HP defender from two attacks to one (attacker=%f insurance=%f)" % [attacker_score, insurance_score]
		),
		assert_eq(picked, [drifloon], "The shared conversion target should give the tier-changing Energy to Drifloon"),
	])


func test_embrace_conversion_keeps_bench_gardevoir_insurance_when_attack_tier_is_unchanged() -> String:
	var strategy := _registry_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800017097 should resolve through DeckStrategyRegistry")

	var state := _conversion_state(220)
	var player: PlayerState = state.players[0]
	var drifloon := _slot(_real_card_data("CSV2C_060"))
	drifloon.damage_counters = 40
	_attach_psychic(drifloon)
	_attach_psychic(drifloon)
	var gardevoir := _slot(_real_card_data("CSV2C_055"))
	player.active_pokemon = drifloon
	player.bench.assign([gardevoir])

	var targets: Array = [drifloon, gardevoir]
	var step := {"id": "embrace_target", "max_select": 1}
	var context := {"game_state": state, "player_index": 0, "all_items": targets}
	var attacker_score: float = strategy.call("score_interaction_target", drifloon, step, context)
	var insurance_score: float = strategy.call("score_interaction_target", gardevoir, step, context)
	var picked: Array = strategy.call("pick_interaction_items", targets, step, context)

	return run_checks([
		assert_true(
			insurance_score >= attacker_score + 500.0,
			"When 120-to-180 damage remains a two-attack route, the Energy should stay on bench Gardevoir insurance (attacker=%f insurance=%f)" % [attacker_score, insurance_score]
		),
		assert_eq(picked, [gardevoir], "The shared conversion target should preserve bench Gardevoir gust insurance"),
	])


func _registry_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	if not parsed is Dictionary:
		return null
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", DeckData.from_dict(parsed))


func _conversion_state(defender_hp: int) -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 9
	state.phase = GameState.GamePhase.MAIN
	for index: int in 20:
		player.deck.append(_filler_card("Deck filler %d" % index))
	player.discard_pile.append(_psychic_energy())
	opponent.active_pokemon = _slot(_defender_card(defender_hp))
	return state


func _real_card_data(ref: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/cards/%s.json" % ref
	))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	if card != null:
		slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot


func _attach_psychic(slot: PokemonSlot) -> void:
	slot.attached_energy.append(_psychic_energy())


func _psychic_energy() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Psychic Energy"
	card.card_type = "Basic Energy"
	card.energy_provides = "P"
	return CardInstance.create(card, 0)


func _defender_card(hp: int) -> CardData:
	var card := CardData.new()
	card.name_en = "Tier Defender"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	return card


func _filler_card(card_name: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = card_name
	card.card_type = "Item"
	return CardInstance.create(card, 0)
