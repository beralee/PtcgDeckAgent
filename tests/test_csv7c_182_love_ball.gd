class_name TestCSV7C182LoveBall
extends TestBase

const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const EffectLoveBallScript = preload("res://scripts/effects/trainer_effects/EffectLoveBall.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")

const LOVE_BALL_ID := "ee2e1cc534d39f1710b1c590bf585ae5"


func test_love_ball_searches_pokemon_matching_opponent_field_name() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var love_ball := CardInstance.create(_trainer("Love Ball", "Item", LOVE_BALL_ID), 0)
	var active_match := CardInstance.create(_pokemon("Active Match", "Active Match EN"), 0)
	var bench_match := CardInstance.create(_pokemon("Bench Match", "Bench Match EN"), 0)
	var non_match := CardInstance.create(_pokemon("No Match", "No Match EN"), 0)
	var matching_trainer := CardInstance.create(_trainer("Active Match", "Item"), 0)
	player.deck.append_array([non_match, active_match, matching_trainer, bench_match])
	opponent.active_pokemon = _slot(_pokemon("Active Match", "Active Match EN"), 1)
	opponent.bench.append(_slot(_pokemon("Bench Match", "Bench Match EN"), 1))

	EffectLoveBallScript.new().execute(love_ball, [{
		EffectLoveBallScript.STEP_ID: [bench_match],
	}], state)

	return run_checks([
		assert_true(bench_match in player.hand, "Love Ball should add the selected same-name Pokemon to hand"),
		assert_true(active_match in player.deck, "Love Ball should not auto-take a different legal Pokemon after explicit selection"),
		assert_true(non_match in player.deck, "Love Ball should leave non-matching Pokemon in deck"),
		assert_true(matching_trainer in player.deck, "Love Ball should not take a non-Pokemon card even if the name matches"),
	])


func test_love_ball_search_steps_show_full_deck_but_only_matching_pokemon_selectable() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var love_ball := CardInstance.create(_trainer("Love Ball", "Item", LOVE_BALL_ID), 0)
	var match := CardInstance.create(_pokemon("Shared Name", "Shared Name EN"), 0)
	var non_match := CardInstance.create(_pokemon("Different Name", "Different Name EN"), 0)
	var special_energy := CardInstance.create(_energy("Special Energy", "C", "Special Energy"), 0)
	player.deck.append_array([non_match, special_energy, match])
	opponent.active_pokemon = _slot(_pokemon("Shared Name", "Shared Name EN"), 1)

	var steps := EffectLoveBallScript.new().get_interaction_steps(love_ball, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var card_indices: Array = step.get("card_indices", [])

	return run_checks([
		assert_eq(steps.size(), 1, "Love Ball should create one deck-search step"),
		assert_eq(str(step.get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "Love Ball should show the full deck"),
		assert_eq(int(step.get("visible_count", -1)), 3, "Love Ball should keep every deck card visible"),
		assert_eq((step.get("items", []) as Array).size(), 1, "Love Ball should only make matching Pokemon selectable"),
		assert_eq(card_indices, [-1, -1, 0], "Love Ball should mark only the matching Pokemon selectable"),
	])


func test_love_ball_allows_hidden_search_whiff_without_fallback() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var love_ball := CardInstance.create(_trainer("Love Ball", "Item", LOVE_BALL_ID), 0)
	var non_match := CardInstance.create(_pokemon("Different Name", "Different Name EN"), 0)
	player.deck.append(non_match)
	opponent.active_pokemon = _slot(_pokemon("Shared Name", "Shared Name EN"), 1)

	var effect := EffectLoveBallScript.new()
	var steps := effect.get_interaction_steps(love_ball, state)
	effect.execute(love_ball, [{EffectLoveBallScript.STEP_ID: []}], state)

	return run_checks([
		assert_true(effect.can_execute(love_ball, state), "Love Ball should be playable with a non-empty deck and opponent Pokemon in play"),
		assert_true(effect.can_headless_execute(love_ball, state), "Headless playability should match hidden-search legality"),
		assert_eq(str((steps[0] as Dictionary).get("id", "")), "empty_search_resolution", "Love Ball should offer empty-search resolution when no target exists"),
		assert_true(non_match in player.deck, "Explicit empty hidden search should not fall back to an illegal target"),
	])


func test_love_ball_matches_english_name_when_localized_names_differ() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var love_ball := CardInstance.create(_trainer("Love Ball", "Item", LOVE_BALL_ID), 0)
	var english_match := CardInstance.create(_pokemon("本地名不同", "Shared English"), 0)
	player.deck.append(english_match)
	opponent.active_pokemon = _slot(_pokemon("另一个本地名", "Shared English"), 1)

	EffectLoveBallScript.new().execute(love_ball, [], state)

	return run_checks([
		assert_true(english_match in player.hand, "Love Ball should match name_en when localized card names differ"),
	])


func test_love_ball_headless_bridge_respects_item_lock_before_interaction() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var love_ball := CardInstance.create(_trainer("Love Ball", "Item", LOVE_BALL_ID), 0)
	var match := CardInstance.create(_pokemon("Shared Name", "Shared Name EN"), 0)
	player.hand.append(love_ball)
	player.deck.append(match)
	opponent.active_pokemon = _slot(_pokemon("Shared Name", "Shared Name EN"), 1)
	state.shared_turn_flags["item_lock_0"] = state.turn_number

	var rule_blocked := not gsm.rule_validator.can_play_item(state, 0, love_ball, gsm.effect_processor)
	var gsm_played := gsm.play_trainer(0, love_ball, [])
	var actions := AILegalActionBuilderScript.new().build_actions(gsm, 0)
	var ai_action := _find_action(actions, "play_trainer", func(candidate: Dictionary) -> bool:
		return candidate.get("card") == love_ball
	)
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	var bridge_started := bool(bridge.call("_try_play_trainer_with_interaction", 0, love_ball))
	var pending_prompt := str(bridge.get_pending_prompt_type())
	bridge.free()

	return run_checks([
		assert_true(rule_blocked, "RuleValidator should block Love Ball under Item lock"),
		assert_false(gsm_played, "GameStateMachine should not play Love Ball under Item lock"),
		assert_true(ai_action.is_empty(), "AI legal action builder should not enumerate Love Ball under Item lock"),
		assert_false(bridge_started, "Headless bridge should not start Love Ball interaction under Item lock"),
		assert_eq(pending_prompt, "", "Headless bridge should leave no pending interaction for a locked Item"),
	])


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)
	return state


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	return gsm


func _find_action(actions: Array[Dictionary], kind: String, predicate: Callable = Callable()) -> Dictionary:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) != kind:
			continue
		if predicate.is_null() or bool(predicate.call(action)):
			return action
	return {}


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _pokemon(name: String, name_en: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name_en
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.hp = 100
	cd.energy_type = "C"
	return cd


func _trainer(name: String, card_type: String = "Item", effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	return cd


func _energy(name: String, energy_type: String, card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	cd.energy_provides = energy_type
	return cd
