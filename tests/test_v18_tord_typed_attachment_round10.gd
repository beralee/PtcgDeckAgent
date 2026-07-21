class_name TestV18TordTypedAttachmentRound10
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/800015934.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_seed15304_duplicate_grass_does_not_fake_pikachu_progress() -> String:
	var strategy := _load_strategy()
	var terapagos: CardData = CardDatabase.get_card("CSV9C", "175")
	var pikachu: CardData = CardDatabase.get_card("CSV9C", "054")
	var grass: CardData = CardDatabase.get_card("CSVE1C", "GRA")
	var lightning: CardData = CardDatabase.get_card("CSVE1C", "LIG")
	var checks: Array[String] = [
		assert_not_null(strategy, "Deck 800015934 should resolve through the production registry"),
		assert_not_null(terapagos, "Terapagos ex should load"),
		assert_not_null(pikachu, "Pikachu ex should load"),
		assert_not_null(grass, "Grass Energy should load"),
		assert_not_null(lightning, "Lightning Energy should load"),
	]
	if strategy == null or terapagos == null or pikachu == null or grass == null or lightning == null:
		return run_checks(checks)

	var state := _make_state()
	var player: PlayerState = state.players[0]
	var active_terapagos := _make_slot(terapagos)
	active_terapagos.attached_energy.append_array([
		CardInstance.create(grass, 0),
		CardInstance.create(lightning, 0),
	])
	var backup_pikachu := _make_slot(pikachu)
	backup_pikachu.attached_energy.append(CardInstance.create(grass, 0))
	player.active_pokemon = active_terapagos
	player.bench = [backup_pikachu]
	var duplicate_score := _score(strategy, _attach(grass, backup_pikachu), state)
	var typed_score := _score(strategy, _attach(lightning, backup_pikachu), state)
	checks.append_array([
		assert_true(duplicate_score <= -1500.0, "A second Grass Energy must not pretend to advance Pikachu ex's GLM attack (score=%f)" % duplicate_score),
		assert_true(typed_score >= duplicate_score + 2500.0, "Lightning must deterministically beat the duplicate Grass attachment (Lightning=%f Grass=%f)" % [typed_score, duplicate_score]),
	])
	return run_checks(checks)


func test_ready_unified_beat_can_still_build_toward_crown_opal() -> String:
	var strategy := _load_strategy()
	var terapagos: CardData = CardDatabase.get_card("CSV9C", "175")
	var grass: CardData = CardDatabase.get_card("CSVE1C", "GRA")
	var lightning: CardData = CardDatabase.get_card("CSVE1C", "LIG")
	var water: CardData = CardDatabase.get_card("CSVE1C", "WAT")
	var psychic: CardData = CardDatabase.get_card("CSVE1C", "PSY")
	if strategy == null or terapagos == null or grass == null or lightning == null \
			or water == null or psychic == null:
		return assert_true(false, "The production strategy and Terapagos typed-cost fixtures should load")
	var state := _make_state()
	var attacker := _make_slot(terapagos)
	attacker.attached_energy.append_array([
		CardInstance.create(grass, 0),
		CardInstance.create(lightning, 0),
	])
	state.players[0].active_pokemon = attacker
	var water_score := _score(strategy, _attach(water, attacker), state)
	var psychic_score := _score(strategy, _attach(psychic, attacker), state)
	return run_checks([
		assert_true(water_score > 0.0, "Water must remain legal because it completes Terapagos ex's stronger GWL attack (score=%f)" % water_score),
		assert_true(psychic_score <= -1000.0, "Psychic advances neither Terapagos attack and must remain clearly negative after wrapper profile scoring (score=%f)" % psychic_score),
		assert_true(water_score >= psychic_score + 2500.0, "The stronger typed route must survive the duplicate/off-color guard"),
	])


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck) if deck != null else null


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _attach(energy: CardData, target: PokemonSlot) -> Dictionary:
	return {
		"kind": "attach_energy",
		"card": CardInstance.create(energy, 0),
		"target_slot": target,
	}


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 15
	state.phase = GameState.GamePhase.MAIN
	return state


func _make_slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
