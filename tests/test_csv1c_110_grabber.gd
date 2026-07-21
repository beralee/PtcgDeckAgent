class_name TestCsv1c110Grabber
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")

const EFFECT_ID := "203a0c4b978c8638a081a5cf05125230"
const STEP_ID := "grabber_opponent_pokemon"
const PREVIEW_STEP_ID := "grabber_opponent_hand_preview"


func test_csv1c_110_registers_the_grabber_item_effect() -> String:
	var card := _load_grabber()
	var processor := EffectProcessor.new()
	var effect: BaseEffect = processor.get_effect(EFFECT_ID)
	return run_checks([
		assert_not_null(card, "CSV1C_110 Grabber should load"),
		assert_not_null(effect, "CSV1C_110 Grabber effect id should register"),
		assert_eq(
			str(effect.get_script().resource_path).get_file() if effect != null else "",
			"EffectGrabber.gd",
			"CSV1C_110 should map to the dedicated Grabber effect"
		),
		assert_false(CardImplementationStatus.is_unimplemented(card), "CSV1C_110 should not show the unimplemented badge"),
	])


func test_csv1c_110_reveals_the_full_hand_while_only_pokemon_are_selectable() -> String:
	var card_data := _load_grabber()
	if card_data == null:
		return assert_not_null(card_data, "CSV1C_110 should load before interaction checks")
	var state := _make_state()
	var grabber := CardInstance.create(card_data, 0)
	var opponent := state.players[1]
	var item := _trainer_instance("Opponent Item", "Item", 1)
	var basic := _pokemon_instance("Opponent Basic", "Basic", 1)
	var evolution := _pokemon_instance("Opponent Evolution", "Stage 1", 1)
	var supporter := _trainer_instance("Opponent Supporter", "Supporter", 1)
	opponent.hand.append_array([item, basic, evolution, supporter])
	var processor := EffectProcessor.new()
	var effect: BaseEffect = processor.get_effect(EFFECT_ID)
	if effect == null:
		return assert_not_null(effect, "Grabber should register before interaction checks")
	var steps: Array[Dictionary] = effect.get_interaction_steps(grabber, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	return run_checks([
		assert_true(effect.can_execute(grabber, state), "Grabber should be usable when the opponent has a hand"),
		assert_true(effect.can_headless_execute(grabber, state), "Headless legality should match Grabber's playable state"),
		assert_eq(steps.size(), 1, "Grabber should expose one complete reveal-and-select step"),
		assert_eq(str(step.get("id", "")), STEP_ID, "Grabber should use a stable interaction step id"),
		assert_eq(str(step.get("visible_scope", "")), "opponent_hand_revealed", "Grabber should intentionally reveal the full opponent hand"),
		assert_eq(step.get("card_items", []), [item, basic, evolution, supporter], "Grabber should visibly show every opponent hand card"),
		assert_eq(step.get("items", []), [basic, evolution], "Grabber should make every Pokemon, and only Pokemon, selectable"),
		assert_eq(step.get("card_indices", []), [-1, 0, 1, -1], "Grabber should visibly disable non-Pokemon cards"),
		assert_eq(int(step.get("min_select", -1)), 1, "Grabber must choose one Pokemon when one is available"),
		assert_eq(int(step.get("max_select", -1)), 1, "Grabber cannot choose more than one Pokemon"),
		assert_false(bool(step.get("allow_cancel", true)), "Grabber's Pokemon choice should not be cancellable"),
	])


func test_csv1c_110_moves_only_the_selected_pokemon_to_the_deck_bottom() -> String:
	var card_data := _load_grabber()
	if card_data == null:
		return assert_not_null(card_data, "CSV1C_110 should load before execution checks")
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var player := gsm.game_state.players[0]
	var opponent := gsm.game_state.players[1]
	var grabber := CardInstance.create(card_data, 0)
	var item := _trainer_instance("Keep Item", "Item", 1)
	var selected := _pokemon_instance("Selected Pokemon", "Basic", 1)
	var kept := _pokemon_instance("Kept Pokemon", "Stage 1", 1)
	var top := _trainer_instance("Deck Top", "Item", 1)
	var bottom := _trainer_instance("Deck Bottom", "Supporter", 1)
	selected.face_up = true
	player.hand.append(grabber)
	opponent.hand.append_array([item, selected, kept])
	opponent.deck.append_array([top, bottom])
	var played := gsm.play_trainer(0, grabber, [{STEP_ID: [selected]}])
	return run_checks([
		assert_true(played, "Grabber should resolve through the real trainer-card entry point"),
		assert_true(grabber in player.discard_pile, "Played Grabber should enter its owner's discard pile"),
		assert_eq(opponent.hand, [item, kept], "Grabber should remove only the selected Pokemon from the opponent's hand"),
		assert_eq(opponent.deck, [top, bottom, selected], "Grabber should append the selected Pokemon to the deck bottom without shuffling"),
		assert_false(selected.face_up, "The Pokemon moved into the deck should become face down"),
		assert_eq(opponent.shuffle_count, 0, "Grabber must not shuffle the opponent's deck"),
	])


func test_csv1c_110_rejects_missing_non_pokemon_and_stale_choices() -> String:
	var card_data := _load_grabber()
	if card_data == null:
		return assert_not_null(card_data, "CSV1C_110 should load before validation checks")
	var state := _make_state()
	var grabber := CardInstance.create(card_data, 0)
	var item := _trainer_instance("Illegal Item", "Item", 1)
	var legal := _pokemon_instance("Legal Pokemon", "Basic", 1)
	var stale := _pokemon_instance("Stale Pokemon", "Basic", 1)
	state.players[1].hand.append_array([item, legal])
	var processor := EffectProcessor.new()
	var missing_valid := processor.validate_card_effect_context(grabber, [], state)
	var missing_reason := processor.get_last_interaction_validation_error(state)
	var item_valid := processor.validate_card_effect_context(grabber, [{STEP_ID: [item]}], state)
	var item_reason := processor.get_last_interaction_validation_error(state)
	var stale_valid := processor.validate_card_effect_context(grabber, [{STEP_ID: [stale]}], state)
	var stale_reason := processor.get_last_interaction_validation_error(state)
	var legal_valid := processor.validate_card_effect_context(grabber, [{STEP_ID: [legal]}], state)
	return run_checks([
		assert_false(missing_valid, "Grabber should reject a missing mandatory Pokemon choice"),
		assert_str_contains(missing_reason, STEP_ID, "Missing-choice diagnostics should name the Grabber step"),
		assert_false(item_valid, "Grabber should reject a non-Pokemon hand card"),
		assert_str_contains(item_reason, "illegal", "Non-Pokemon diagnostics should identify an illegal selection"),
		assert_false(stale_valid, "Grabber should reject a Pokemon that is no longer in the opponent's hand"),
		assert_str_contains(stale_reason, "illegal", "Stale-choice diagnostics should identify an illegal selection"),
		assert_true(legal_valid, "Grabber should accept exactly one current opponent-hand Pokemon"),
		assert_eq(state.players[1].hand, [item, legal], "Validation must not mutate the opponent's hand"),
	])


func test_csv1c_110_handles_empty_and_no_pokemon_hands_without_leaking_scope() -> String:
	var card_data := _load_grabber()
	if card_data == null:
		return assert_not_null(card_data, "CSV1C_110 should load before empty-hand checks")
	var state := _make_state()
	var grabber := CardInstance.create(card_data, 0)
	var processor := EffectProcessor.new()
	var effect: BaseEffect = processor.get_effect(EFFECT_ID)
	if effect == null:
		return assert_not_null(effect, "Grabber should register before empty-hand checks")
	var empty_can_execute := effect.can_execute(grabber, state)
	var empty_steps: Array[Dictionary] = effect.get_interaction_steps(grabber, state)
	var item := _trainer_instance("Only Item", "Item", 1)
	var supporter := _trainer_instance("Only Supporter", "Supporter", 1)
	state.players[1].hand.append_array([item, supporter])
	var no_pokemon_steps: Array[Dictionary] = effect.get_interaction_steps(grabber, state)
	var preview: Dictionary = no_pokemon_steps[0] if not no_pokemon_steps.is_empty() else {}
	var resolved := processor.execute_card_effect(grabber, [{PREVIEW_STEP_ID: []}], state)
	return run_checks([
		assert_false(empty_can_execute, "Grabber should not be playable against an empty hand"),
		assert_true(empty_steps.is_empty(), "Grabber should not prompt for an empty opponent hand"),
		assert_true(effect.can_execute(grabber, state), "Grabber should still reveal a nonempty hand that contains no Pokemon"),
		assert_true(effect.can_headless_execute(grabber, state), "Headless legality should preserve the no-Pokemon reveal branch"),
		assert_eq(no_pokemon_steps.size(), 1, "A no-Pokemon hand should still receive a readonly reveal step"),
		assert_eq(str(preview.get("id", "")), PREVIEW_STEP_ID, "The readonly reveal should use a stable step id"),
		assert_eq(str(preview.get("visible_scope", "")), "opponent_hand_revealed", "The readonly branch should reveal only the opponent hand"),
		assert_eq(preview.get("items", []), [item, supporter], "The readonly reveal should show the full opponent hand"),
		assert_eq(int(preview.get("min_select", -1)), 0, "The no-Pokemon branch should require no selection"),
		assert_eq(int(preview.get("max_select", -1)), 0, "The no-Pokemon branch should allow no selection"),
		assert_true(resolved, "Grabber should finish successfully after revealing a hand with no Pokemon"),
		assert_eq(state.players[1].hand, [item, supporter], "The no-Pokemon branch should leave the opponent hand unchanged"),
		assert_true(state.players[1].deck.is_empty(), "The no-Pokemon branch should not move any card to the deck"),
	])


func _load_grabber() -> CardData:
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card("CSV1C", "110")
	db.free()
	return card


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 3
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	return state


func _trainer_instance(name: String, card_type: String, owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = card_type
	return CardInstance.create(card, owner_index)


func _pokemon_instance(name: String, stage: String, owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = 100
	return CardInstance.create(card, owner_index)
