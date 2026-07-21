class_name TestV18BlazikenDragapultEnergyReserveRound2
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800019125
const SIBLING_DECK_ID := 800015734
const LUMINOUS_ENERGY_EFFECT_ID := "540ee48bb93584e4bfe3d7f5d0ee0efc"


func test_no_dragapult_lane_reserves_psychic_from_torchic_and_elgyem() -> String:
	var strategy := _strategy(DECK_ID)
	if strategy == null:
		return assert_true(false, "Deck 800019125 should resolve through the production registry")
	var state := _base_state()
	var player: PlayerState = state.players[0]
	var elgyem := _slot(_pokemon("Elgyem", "Basic"), 0)
	var torchic := _slot(_pokemon("Torchic", "Basic"), 0)
	var psychic := _energy("Psychic Energy", "P")
	player.active_pokemon = elgyem
	player.bench.append(torchic)
	var torchic_score := _attach_score(strategy, state, psychic, torchic)
	var elgyem_score := _attach_score(strategy, state, psychic, elgyem)
	var end_score := _score(strategy, state, {"kind": "end_turn"})
	return run_checks([
		assert_true(torchic_score <= -4000.0, "No-line Psychic must be reserved from Torchic (score=%f)" % torchic_score),
		assert_true(elgyem_score <= -4000.0, "No-line Psychic must be reserved from Elgyem (score=%f)" % elgyem_score),
		assert_true(torchic_score < end_score and elgyem_score < end_score, "Ending the turn must beat spending no-line Psychic off-route"),
	])


func test_dead_chi_yu_fire_is_suppressed_but_productive_acceleration_is_preserved() -> String:
	var strategy := _strategy(DECK_ID)
	if strategy == null:
		return assert_true(false, "Deck 800019125 should resolve through the production registry")
	var state := _base_state()
	var player: PlayerState = state.players[0]
	var chi_yu := _slot(_pokemon("Chi-Yu", "Basic"), 0)
	var blaziken := _slot(_pokemon("Blaziken ex", "Stage 2"), 0)
	var hand_fire := _energy("Hand Fire", "R")
	player.active_pokemon = chi_yu
	player.bench.append(blaziken)
	var dead_score := _attach_score(strategy, state, hand_fire, chi_yu)
	player.discard_pile.append(_energy("Discard Fire", "R"))
	var live_score := _attach_score(strategy, state, hand_fire, chi_yu)
	return run_checks([
		assert_true(dead_score <= -4000.0, "Chi-Yu without discard Fire must not consume the reserved hand Fire (score=%f)" % dead_score),
		assert_true(live_score >= 2000.0, "Active Chi-Yu may receive Fire when discard acceleration can productively fund Blaziken (score=%f)" % live_score),
		assert_true(live_score >= dead_score + 6000.0, "A genuinely productive Chi-Yu acceleration route must be distinguished from the dead route"),
	])


func test_dragapult_line_keeps_basic_fire_and_psychic_attachment_route() -> String:
	var strategy := _strategy(DECK_ID)
	if strategy == null:
		return assert_true(false, "Deck 800019125 should resolve through the production registry")
	var state := _base_state()
	var dreepy := _slot(_pokemon("Dreepy", "Basic"), 0)
	state.players[0].active_pokemon = dreepy
	var fire_score := _attach_score(strategy, state, _energy("Fire Energy", "R"), dreepy)
	var psychic_score := _attach_score(strategy, state, _energy("Psychic Energy", "P"), dreepy)
	return run_checks([
		assert_true(fire_score >= 3000.0, "Dreepy must retain the Fire setup route (score=%f)" % fire_score),
		assert_true(psychic_score >= 3000.0, "Dreepy must retain the Psychic setup route (score=%f)" % psychic_score),
	])


func test_fire_remains_valid_on_each_blaziken_line_target_without_dragapult() -> String:
	var strategy := _strategy(DECK_ID)
	if strategy == null:
		return assert_true(false, "Deck 800019125 should resolve through the production registry")
	var state := _base_state()
	var player: PlayerState = state.players[0]
	var torchic := _slot(_pokemon("Torchic", "Basic"), 0)
	var combusken := _slot(_pokemon("Combusken", "Stage 1"), 0)
	var blaziken := _slot(_pokemon("Blaziken ex", "Stage 2"), 0)
	player.active_pokemon = torchic
	player.bench.assign([combusken, blaziken])
	var fire := _energy("Fire Energy", "R")
	return run_checks([
		assert_true(_attach_score(strategy, state, fire, torchic) >= 1000.0, "Torchic should remain a valid Fire route target"),
		assert_true(_attach_score(strategy, state, fire, combusken) >= 1000.0, "Combusken should remain a valid Fire route target"),
		assert_true(_attach_score(strategy, state, fire, blaziken) >= 1000.0, "Blaziken ex should remain a valid Fire route target"),
	])


func test_darkness_munkidori_and_luminous_behavior_are_unchanged() -> String:
	var strategy := _strategy(DECK_ID)
	if strategy == null:
		return assert_true(false, "Deck 800019125 should resolve through the production registry")
	var state := _base_state()
	var player: PlayerState = state.players[0]
	var elgyem := _slot(_pokemon("Elgyem", "Basic"), 0)
	var munkidori := _slot(_pokemon("Munkidori", "Basic"), 0)
	elgyem.damage_counters = 20
	player.active_pokemon = elgyem
	player.bench.append(munkidori)
	var darkness_score := _attach_score(strategy, state, _energy("Darkness Energy", "D"), munkidori)
	var luminous_score := _attach_score(strategy, state, _special_energy("Luminous Energy", LUMINOUS_ENERGY_EFFECT_ID), elgyem)
	return run_checks([
		assert_true(darkness_score >= 2500.0, "Darkness must still switch on Munkidori when damage can move (score=%f)" % darkness_score),
		assert_true(luminous_score > -1000.0, "The basic-Energy reserve must not alter Luminous attachment scoring (score=%f)" % luminous_score),
	])


func test_energy_reserve_is_scoped_away_from_sibling_dragapult_decks() -> String:
	var target_strategy := _strategy(DECK_ID)
	var sibling_strategy := _strategy(SIBLING_DECK_ID)
	if target_strategy == null or sibling_strategy == null:
		return assert_true(false, "Both Dragapult family decks should resolve through the production registry")
	var state := _base_state()
	var elgyem := _slot(_pokemon("Elgyem", "Basic"), 0)
	state.players[0].active_pokemon = elgyem
	var psychic := _energy("Psychic Energy", "P")
	var target_score := _attach_score(target_strategy, state, psychic, elgyem)
	var sibling_score := _attach_score(sibling_strategy, state, psychic, elgyem)
	return run_checks([
		assert_true(target_score <= -4000.0, "Deck 800019125 should apply the no-line reserve"),
		assert_true(sibling_score > target_score + 3000.0, "Sibling deck 800015734 must keep its prior no-line attachment behavior"),
	])


func _strategy(deck_id: int) -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/decks/%d.json" % deck_id
	))
	if not parsed is Dictionary:
		return null
	return REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", DeckData.from_dict(parsed))


func _attach_score(strategy: RefCounted, state: GameState, energy: CardInstance, target: PokemonSlot) -> float:
	return _score(strategy, state, {
		"kind": "attach_energy",
		"card": energy,
		"target_slot": target,
	})


func _score(strategy: RefCounted, state: GameState, action: Dictionary) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _base_state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		for prize_index: int in 6:
			player.prizes.append(_item("Prize %d" % prize_index, player_index))
		state.players.append(player)
	state.players[1].active_pokemon = _slot(_pokemon("Opponent Active", "Basic"), 1)
	return state


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


func _special_energy(card_name: String, effect_id: String, owner_index: int = 0) -> CardInstance:
	var card := CardData.new()
	card.name = card_name
	card.name_en = card_name
	card.card_type = "Special Energy"
	card.effect_id = effect_id
	card.energy_provides = "ANY"
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
