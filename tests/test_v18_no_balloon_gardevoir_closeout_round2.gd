class_name TestV18NoBalloonGardevoirCloseoutRound2
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_PATH := "res://data/bundled_user/decks/800017097.json"
const RABSCA_DECK_PATH := "res://data/bundled_user/decks/800018105.json"
const DELEGATE_PATH := "res://scripts/ai/DeckStrategyV18GardevoirVariants.gd"


func test_registry_prediction_models_gardevoir_miracle_force_as_190_for_ppc() -> String:
	var strategy := _registry_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800017097 should resolve through DeckStrategyRegistry")

	var gardevoir := _slot(_real_card_data("CSV2C_055"))
	_attach_energy(gardevoir, "P")
	_attach_energy(gardevoir, "D")
	var before: Dictionary = strategy.call("predict_attacker_damage", gardevoir, 0)
	var after_one_embrace: Dictionary = strategy.call("predict_attacker_damage", gardevoir, 1)
	_attach_energy(gardevoir, "P")
	var ready: Dictionary = strategy.call("predict_attacker_damage", gardevoir, 0)

	return run_checks([
		assert_eq(int(before.get("damage", 0)), 190, "Miracle Force should predict 190 damage"),
		assert_false(bool(before.get("can_attack", false)), "One Psychic plus one Darkness does not satisfy PPC"),
		assert_true(bool(after_one_embrace.get("can_attack", false)), "One additional Psychic Embrace should satisfy PPC"),
		assert_true(bool(ready.get("can_attack", false)), "Two Psychic plus one other Energy should satisfy PPC"),
	])


func test_low_deck_embrace_closes_ppc_and_targets_active_gardevoir() -> String:
	var strategy := _registry_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800017097 should resolve through DeckStrategyRegistry")

	var state := _closeout_state(8)
	var player: PlayerState = state.players[0]
	var gardevoir := _slot(_real_card_data("CSV2C_055"))
	var kirlia := _slot(_real_card_data("CS6.5C_030"))
	_attach_energy(gardevoir, "P")
	_attach_energy(gardevoir, "D")
	player.active_pokemon = gardevoir
	player.bench.append(kirlia)
	player.discard_pile.append(_energy("P"))

	var plan: Dictionary = strategy.call("build_turn_plan", state, 0)
	var owner: Dictionary = plan.get("owner", {})
	var flags: Dictionary = plan.get("flags", {})
	var embrace_score: float = strategy.call("score_action_absolute", {
		"kind": "use_ability",
		"source_slot": gardevoir,
		"ability_index": 0,
		"ability_name": "Psychic Embrace",
	}, state, 0)
	var refinement_score: float = _refinement_score(strategy, state, kirlia)
	var active_target_score: float = strategy.call("score_interaction_target", gardevoir, {
		"id": "embrace_target",
	}, {"game_state": state, "player_index": 0})
	var bench_target_score: float = strategy.call("score_interaction_target", kirlia, {
		"id": "embrace_target",
	}, {"game_state": state, "player_index": 0})
	var picked: Array = strategy.call("pick_interaction_items", [kirlia, gardevoir], {
		"id": "embrace_target", "min_select": 1, "max_select": 1,
	}, {"game_state": state, "player_index": 0})

	return run_checks([
		assert_eq(str(strategy.get("_delegate").get_script().resource_path), DELEGATE_PATH, "Registry should keep the deck-owned delegate"),
		assert_true(bool(flags.get("no_balloon_gardevoir_closeout", false)), "The one-Embrace active-Gardevoir closeout should be live"),
		assert_eq(str(plan.get("phase", "")), "close", "The emergency route should use close phase"),
		assert_eq(str(plan.get("intent", "")), "embrace_gardevoir_closeout", "The incomplete PPC route should request Embrace"),
		assert_eq(str(owner.get("turn_owner_name", "")), gardevoir.get_pokemon_name(), "The active Gardevoir should own the closeout turn"),
		assert_true(embrace_score > refinement_score, "The PPC-completing Embrace should outrank Refinement"),
		assert_true(active_target_score > bench_target_score, "Emergency Embrace target scoring should prefer active Gardevoir"),
		assert_eq(picked, [gardevoir], "Emergency Embrace target picking should select active Gardevoir"),
	])


func test_ready_miracle_force_outranks_refinement_research_and_iono() -> String:
	var strategy := _registry_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800017097 should resolve through DeckStrategyRegistry")

	var state := _closeout_state(8)
	var player: PlayerState = state.players[0]
	var gardevoir := _slot(_real_card_data("CSV2C_055"))
	var kirlia := _slot(_real_card_data("CS6.5C_030"))
	_attach_energy(gardevoir, "P")
	_attach_energy(gardevoir, "P")
	_attach_energy(gardevoir, "D")
	player.active_pokemon = gardevoir
	player.bench.append(kirlia)
	var research := _real_card("CSV1C_121")
	var iono := _real_card("CSV3C_123")
	player.hand.assign([research, iono])

	var plan: Dictionary = strategy.call("build_turn_plan", state, 0)
	var attack_score: float = strategy.call("score_action_absolute", {
		"kind": "attack",
		"attack_index": 0,
		"attack_name": "Miracle Force",
		"source_slot": gardevoir,
		"projected_damage": 190,
		"projected_knockout": false,
	}, state, 0)
	var refinement_score: float = _refinement_score(strategy, state, kirlia)
	var research_score: float = strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": research,
	}, state, 0)
	var iono_score: float = strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": iono,
	}, state, 0)

	return run_checks([
		assert_eq(str(plan.get("phase", "")), "close", "The ready Miracle Force route should stay in close phase"),
		assert_eq(str(plan.get("intent", "")), "convert_gardevoir_closeout", "The ready PPC route should convert immediately"),
		assert_true(attack_score > refinement_score, "Miracle Force should outrank Refinement in the emergency closeout"),
		assert_true(attack_score > research_score, "Miracle Force should outrank Professor's Research in the emergency closeout"),
		assert_true(attack_score > iono_score, "Miracle Force should outrank Iono in the emergency closeout"),
		assert_true(refinement_score < 0.0 and research_score < 0.0 and iono_score < 0.0, "Low-deck closeout draw and filtering actions should be suppressed"),
	])


func test_fallback_requires_no_balloon_variant_and_one_legal_embrace_maximum() -> String:
	var strategy := _registry_strategy()
	var rabsca_strategy := _registry_strategy(RABSCA_DECK_PATH)
	if strategy == null or rabsca_strategy == null:
		return assert_true(false, "Both Gardevoir variants should resolve through DeckStrategyRegistry")

	var two_embrace_state := _closeout_state(8)
	var two_embrace_player: PlayerState = two_embrace_state.players[0]
	var two_embrace_gardevoir := _slot(_real_card_data("CSV2C_055"))
	_attach_energy(two_embrace_gardevoir, "P")
	two_embrace_player.active_pokemon = two_embrace_gardevoir
	two_embrace_player.discard_pile.append(_energy("P"))
	var two_embrace_flags: Dictionary = strategy.call("build_turn_plan", two_embrace_state, 0).get("flags", {})

	var no_discard_state := _closeout_state(8)
	var no_discard_player: PlayerState = no_discard_state.players[0]
	var no_discard_gardevoir := _slot(_real_card_data("CSV2C_055"))
	_attach_energy(no_discard_gardevoir, "P")
	_attach_energy(no_discard_gardevoir, "D")
	no_discard_player.active_pokemon = no_discard_gardevoir
	var no_discard_flags: Dictionary = strategy.call("build_turn_plan", no_discard_state, 0).get("flags", {})

	var rabsca_state := _closeout_state(8)
	var rabsca_player: PlayerState = rabsca_state.players[0]
	var rabsca_gardevoir := _slot(_real_card_data("CSV2C_055"))
	_attach_energy(rabsca_gardevoir, "P")
	_attach_energy(rabsca_gardevoir, "P")
	_attach_energy(rabsca_gardevoir, "D")
	rabsca_player.active_pokemon = rabsca_gardevoir
	var rabsca_flags: Dictionary = rabsca_strategy.call("build_turn_plan", rabsca_state, 0).get("flags", {})

	return run_checks([
		assert_false(bool(two_embrace_flags.get("no_balloon_gardevoir_closeout", false)), "A Gardevoir still two Energy short must not enter the fallback"),
		assert_false(bool(no_discard_flags.get("no_balloon_gardevoir_closeout", false)), "The single-Embrace route requires a discarded Psychic Energy"),
		assert_false(bool(rabsca_flags.get("no_balloon_gardevoir_closeout", false)), "The fallback must not activate for the Rabsca variant"),
	])


func test_existing_scream_tail_disables_active_gardevoir_fallback() -> String:
	var strategy := _registry_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800017097 should resolve through DeckStrategyRegistry")

	var open_state := _closeout_state(8)
	var open_player: PlayerState = open_state.players[0]
	var open_gardevoir := _slot(_real_card_data("CSV2C_055"))
	_attach_energy(open_gardevoir, "P")
	_attach_energy(open_gardevoir, "D")
	open_player.active_pokemon = open_gardevoir
	open_player.discard_pile.append(_energy("P"))
	var open_score: float = _embrace_score(strategy, open_state, open_gardevoir)

	var blocked_state := _closeout_state(8)
	var blocked_player: PlayerState = blocked_state.players[0]
	var blocked_gardevoir := _slot(_real_card_data("CSV2C_055"))
	_attach_energy(blocked_gardevoir, "P")
	_attach_energy(blocked_gardevoir, "D")
	blocked_player.active_pokemon = blocked_gardevoir
	blocked_player.bench.append(_slot(_real_card_data("CSV6C_065")))
	blocked_player.discard_pile.append(_energy("P"))
	var blocked_plan: Dictionary = strategy.call("build_turn_plan", blocked_state, 0)
	var blocked_flags: Dictionary = blocked_plan.get("flags", {})
	var blocked_score: float = _embrace_score(strategy, blocked_state, blocked_gardevoir)

	return run_checks([
		assert_false(bool(blocked_flags.get("no_balloon_gardevoir_closeout", false)), "Any fielded Scream Tail should disable the Gardevoir fallback"),
		assert_true(str(blocked_plan.get("intent", "")) not in ["embrace_gardevoir_closeout", "convert_gardevoir_closeout"], "Scream Tail should keep the turn out of the emergency Gardevoir route"),
		assert_true(open_score > blocked_score, "Scream Tail presence should remove the emergency Embrace priority"),
	])


func test_deck_above_eight_disables_active_gardevoir_fallback() -> String:
	var strategy := _registry_strategy()
	if strategy == null:
		return assert_true(false, "Deck 800017097 should resolve through DeckStrategyRegistry")

	var open_state := _closeout_state(8)
	var open_player: PlayerState = open_state.players[0]
	var open_gardevoir := _slot(_real_card_data("CSV2C_055"))
	_attach_energy(open_gardevoir, "P")
	_attach_energy(open_gardevoir, "D")
	open_player.active_pokemon = open_gardevoir
	open_player.discard_pile.append(_energy("P"))
	var open_score: float = _embrace_score(strategy, open_state, open_gardevoir)

	var blocked_state := _closeout_state(9)
	var blocked_player: PlayerState = blocked_state.players[0]
	var blocked_gardevoir := _slot(_real_card_data("CSV2C_055"))
	_attach_energy(blocked_gardevoir, "P")
	_attach_energy(blocked_gardevoir, "D")
	blocked_player.active_pokemon = blocked_gardevoir
	blocked_player.discard_pile.append(_energy("P"))
	var blocked_plan: Dictionary = strategy.call("build_turn_plan", blocked_state, 0)
	var blocked_flags: Dictionary = blocked_plan.get("flags", {})
	var blocked_score: float = _embrace_score(strategy, blocked_state, blocked_gardevoir)

	return run_checks([
		assert_false(bool(blocked_flags.get("no_balloon_gardevoir_closeout", false)), "A nine-card deck should disable the Gardevoir fallback"),
		assert_true(str(blocked_plan.get("intent", "")) not in ["embrace_gardevoir_closeout", "convert_gardevoir_closeout"], "Deck size above eight should keep the turn out of the emergency route"),
		assert_true(open_score > blocked_score, "Deck size above eight should remove the emergency Embrace priority"),
	])


func _registry_strategy(deck_path: String = DECK_PATH) -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(deck_path))
	if not parsed is Dictionary:
		return null
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", DeckData.from_dict(parsed))


func _closeout_state(deck_size: int) -> GameState:
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
	for index: int in deck_size:
		player.deck.append(_filler_card("Deck filler %d" % index))
	for index: int in 6:
		player.prizes.append(_filler_card("Prize filler %d" % index))
	opponent.active_pokemon = _slot(_opponent_card())
	return state


func _embrace_score(strategy: RefCounted, state: GameState, gardevoir: PokemonSlot) -> float:
	return strategy.call("score_action_absolute", {
		"kind": "use_ability",
		"source_slot": gardevoir,
		"ability_index": 0,
		"ability_name": "Psychic Embrace",
	}, state, 0)


func _refinement_score(strategy: RefCounted, state: GameState, kirlia: PokemonSlot) -> float:
	return strategy.call("score_action_absolute", {
		"kind": "use_ability",
		"source_slot": kirlia,
		"ability_index": 0,
		"ability_name": "Refinement",
	}, state, 0)


func _real_card(ref: String) -> CardInstance:
	return CardInstance.create(_real_card_data(ref), 0)


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


func _attach_energy(slot: PokemonSlot, energy_type: String) -> void:
	slot.attached_energy.append(_energy(energy_type))


func _energy(energy_type: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = "Psychic Energy" if energy_type == "P" else "Darkness Energy"
	card.card_type = "Basic Energy"
	card.energy_provides = energy_type
	return CardInstance.create(card, 0)


func _opponent_card() -> CardData:
	var card := CardData.new()
	card.name_en = "Test Defender"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 220
	return card


func _filler_card(card_name: String) -> CardInstance:
	var card := CardData.new()
	card.name_en = card_name
	card.card_type = "Item"
	return CardInstance.create(card, 0)
