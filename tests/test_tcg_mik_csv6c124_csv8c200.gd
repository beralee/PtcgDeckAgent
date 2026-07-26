class_name TestTCGMikCSV6C124CSV8C200
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const DeckEditorScript := preload("res://scenes/deck_editor/DeckEditor.gd")
const AILegalActionBuilderScript := preload("res://scripts/ai/AILegalActionBuilder.gd")
const BattleEffectInteractionControllerScript := preload("res://scripts/ui/battle/BattleEffectInteractionController.gd")

const ROARK_EFFECT_ID := "2a5c07699e0820cfe5c46e053652023f"
const KOFU_EFFECT_ID := "2d43eb3b21ee954281030e8da5c7eb94"
const ROARK_STEP_ID := "roark_basic_energy"
const KOFU_STEP_ID := "kofu_hand_to_bottom"


func test_csv6c124_and_csv8c200_are_bundled_with_images_and_supporter_pool_visibility() -> String:
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	var specs := [
		{
			"uid": "CSV6C_124",
			"set_code": "CSV6C",
			"card_index": "124",
			"name": "瓢太",
			"name_en": "Roark",
			"effect_id": ROARK_EFFECT_ID,
		},
		{
			"uid": "CSV8C_200",
			"set_code": "CSV8C",
			"card_index": "200",
			"name": "海岱",
			"name_en": "Kofu",
			"effect_id": KOFU_EFFECT_ID,
		},
	]
	var db := CardDatabaseScript.new()
	var all_uids := {}
	for pooled_card: CardData in db.get_all_cards():
		all_uids[pooled_card.get_uid()] = true
	var checks: Array[String] = []
	for spec: Dictionary in specs:
		var uid := str(spec.get("uid", ""))
		var set_code := str(spec.get("set_code", ""))
		var card_index := str(spec.get("card_index", ""))
		var json_path := "res://data/bundled_user/cards/%s.json" % uid
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, card_index]
		var card: CardData = db.get_card(set_code, card_index)
		checks.append(assert_str_contains(manifest, json_path, "%s JSON should be in the bundled manifest" % uid))
		checks.append(assert_str_contains(manifest, image_path, "%s image should be in the bundled manifest" % uid))
		checks.append(assert_true(FileAccess.file_exists(json_path), "%s bundled JSON should exist" % uid))
		checks.append(assert_true(FileAccess.file_exists(image_path), "%s bundled image should exist" % uid))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s bundled image should be valid" % uid))
		checks.append(assert_not_null(card, "%s should load through CardDatabase" % uid))
		if card != null:
			checks.append(assert_eq(card.name, str(spec.get("name", "")), "%s should preserve its Chinese name" % uid))
			checks.append(assert_eq(card.name_en, str(spec.get("name_en", "")), "%s should preserve its English name" % uid))
			checks.append(assert_eq(card.card_type, "Supporter", "%s should remain a Supporter" % uid))
			checks.append(assert_eq(card.effect_id, str(spec.get("effect_id", "")), "%s should preserve its source effect id" % uid))
		checks.append(assert_true(all_uids.has(uid), "%s should be materialized for the selectable card pool" % uid))
	db.free()

	var editor := DeckEditorScript.new()
	editor.call("_build_pool")
	var supporter_uids := {}
	var categories: Array = editor.get("_pool_by_category")
	if categories.size() > 1:
		for pooled_card: CardData in categories[1]:
			supporter_uids[pooled_card.get_uid()] = true
	for uid: String in ["CSV6C_124", "CSV8C_200"]:
		checks.append(assert_true(supporter_uids.has(uid), "%s should appear in the DeckEditor Supporter tab" % uid))
	editor.free()
	return run_checks(checks)


func test_csv6c124_roark_draws_two_then_recovers_the_selected_basic_energy() -> String:
	var card_data := _load_card("CSV6C", "124")
	if card_data == null:
		return assert_not_null(card_data, "CSV6C_124 should load")
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var roark := CardInstance.create(card_data, 0)
	var basic_energy := _card("Discard Basic Energy", "Basic Energy", 0, "F")
	var special_energy := _card("Discard Special Energy", "Special Energy", 0, "C")
	var draw_one := _card("Draw One", "Item", 0)
	var draw_two := _card("Draw Two", "Pokemon", 0)
	var deck_remainder := _card("Deck Remainder", "Item", 0)
	player.hand.append(roark)
	player.discard_pile.append_array([special_energy, basic_energy])
	player.deck.append_array([draw_one, draw_two, deck_remainder])

	var effect: BaseEffect = gsm.effect_processor.get_effect(ROARK_EFFECT_ID)
	var steps: Array = effect.get_interaction_steps(roark, gsm.game_state) if effect != null else []
	var items: Array = steps[0].get("items", []) if not steps.is_empty() else []
	var missing_valid := gsm.effect_processor.validate_card_effect_context(roark, [], gsm.game_state)
	var special_valid := gsm.effect_processor.validate_card_effect_context(
		roark,
		[{ROARK_STEP_ID: [special_energy]}],
		gsm.game_state,
	)
	var basic_valid := gsm.effect_processor.validate_card_effect_context(
		roark,
		[{ROARK_STEP_ID: [basic_energy]}],
		gsm.game_state,
	)
	var played := gsm.play_trainer(0, roark, [{ROARK_STEP_ID: [basic_energy]}])

	return run_checks([
		assert_not_null(effect, "Roark should be registered by source effect id"),
		assert_true(effect.can_execute(roark, gsm.game_state) if effect != null else false, "Roark should be usable when its draw or recovery can resolve"),
		assert_eq(steps.size(), 1, "Roark should expose one discard-pile Energy choice"),
		assert_eq(int(steps[0].get("min_select", 0)) if not steps.is_empty() else 0, 1, "Roark should require one Energy when a candidate exists"),
		assert_eq(int(steps[0].get("max_select", 0)) if not steps.is_empty() else 0, 1, "Roark should select exactly one Energy"),
		assert_eq(items, [basic_energy], "Roark should expose Basic Energy but not Special Energy"),
		assert_false(missing_valid, "Roark should reject a missing mandatory Energy selection"),
		assert_false(special_valid, "Roark should reject a Special Energy selection"),
		assert_true(basic_valid, "Roark should accept a legal Basic Energy selection"),
		assert_true(played, "Roark should resolve through GameStateMachine"),
		assert_eq(player.hand, [draw_one, draw_two, basic_energy], "Roark should draw the top two cards before recovering the chosen Energy"),
		assert_eq(player.deck, [deck_remainder], "Roark should remove exactly the top two cards from the deck"),
		assert_true(special_energy in player.discard_pile, "Unselected Special Energy should stay in the discard pile"),
		assert_false(basic_energy in player.discard_pile, "Selected Basic Energy should leave the discard pile"),
		assert_true(roark in player.discard_pile, "Roark should enter the discard pile after resolving"),
		assert_true(gsm.game_state.supporter_used_this_turn, "Roark should consume the Supporter use for the turn"),
		assert_false(CardImplementationStatus.is_unimplemented(card_data), "CSV6C_124 should be marked implemented"),
	])


func test_csv6c124_roark_draw_only_branch_and_no_effect_gate() -> String:
	var card_data := _load_card("CSV6C", "124")
	if card_data == null:
		return assert_not_null(card_data, "CSV6C_124 should load")
	var draw_gsm := _make_gsm()
	var draw_player: PlayerState = draw_gsm.game_state.players[0]
	var draw_roark := CardInstance.create(card_data, 0)
	var only_draw := _card("Only Draw", "Item", 0)
	draw_player.hand.append(draw_roark)
	draw_player.deck.append(only_draw)
	var effect: BaseEffect = draw_gsm.effect_processor.get_effect(ROARK_EFFECT_ID)
	var draw_steps: Array = effect.get_interaction_steps(draw_roark, draw_gsm.game_state) if effect != null else []
	var draw_played := draw_gsm.play_trainer(0, draw_roark, [])

	var blocked_gsm := _make_gsm()
	var blocked_roark := CardInstance.create(card_data, 0)
	blocked_gsm.game_state.players[0].hand.append(blocked_roark)
	var blocked_effect: BaseEffect = blocked_gsm.effect_processor.get_effect(ROARK_EFFECT_ID)
	var blocked_can_execute := blocked_effect.can_execute(blocked_roark, blocked_gsm.game_state) if blocked_effect != null else true
	var blocked_actions := AILegalActionBuilderScript.new().build_actions(blocked_gsm, 0)
	var blocked_action := _find_trainer_action(blocked_actions, blocked_roark)

	return run_checks([
		assert_eq(draw_steps.size(), 0, "Roark should not ask for an Energy when discard has none"),
		assert_true(draw_played, "Roark should still be usable for its draw effect"),
		assert_eq(draw_player.hand, [only_draw], "Roark should draw as many of the requested two cards as possible"),
		assert_false(blocked_can_execute, "Roark should be unusable when neither draw nor recovery can change the state"),
		assert_true(blocked_action.is_empty(), "AI legal actions should omit a no-effect Roark"),
	])


func test_csv8c200_kofu_requires_two_other_hand_cards_and_preserves_selected_bottom_order() -> String:
	var card_data := _load_card("CSV8C", "200")
	if card_data == null:
		return assert_not_null(card_data, "CSV8C_200 should load")
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var kofu := CardInstance.create(card_data, 0)
	var hand_a := _card("Hand A", "Item", 0)
	var hand_b := _card("Hand B", "Pokemon", 0)
	var hand_c := _card("Hand C", "Supporter", 0)
	var draw_one := _card("Draw 1", "Item", 0)
	var draw_two := _card("Draw 2", "Item", 0)
	var draw_three := _card("Draw 3", "Item", 0)
	var draw_four := _card("Draw 4", "Item", 0)
	var deck_remainder := _card("Deck Remainder", "Item", 0)
	player.hand.append_array([kofu, hand_a, hand_b, hand_c])
	player.deck.append_array([draw_one, draw_two, draw_three, draw_four, deck_remainder])

	var effect: BaseEffect = gsm.effect_processor.get_effect(KOFU_EFFECT_ID)
	var steps: Array = effect.get_interaction_steps(kofu, gsm.game_state) if effect != null else []
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var controller := BattleEffectInteractionControllerScript.new()
	var ui_order_result: Dictionary = controller.validate_effect_step_choice(step, PackedInt32Array([1, 0]))
	var missing_valid := gsm.effect_processor.validate_card_effect_context(kofu, [], gsm.game_state)
	var own_card_valid := gsm.effect_processor.validate_card_effect_context(
		kofu,
		[{KOFU_STEP_ID: [kofu, hand_a]}],
		gsm.game_state,
	)
	var exact_valid := gsm.effect_processor.validate_card_effect_context(
		kofu,
		[{KOFU_STEP_ID: [hand_b, hand_a]}],
		gsm.game_state,
	)
	var actions := AILegalActionBuilderScript.new().build_actions(gsm, 0)
	var ai_action := _find_trainer_action(actions, kofu)
	var ai_targets: Array = ai_action.get("targets", [])
	var ai_context: Dictionary = ai_targets[0] if not ai_targets.is_empty() and ai_targets[0] is Dictionary else {}
	var played := gsm.play_trainer(0, kofu, [{KOFU_STEP_ID: [hand_b, hand_a]}])

	return run_checks([
		assert_not_null(effect, "Kofu should be registered by source effect id"),
		assert_true(effect.can_execute(kofu, gsm.game_state) if effect != null else false, "Kofu should be usable with at least two other hand cards"),
		assert_eq(steps.size(), 1, "Kofu should expose one ordered two-card hand choice"),
		assert_eq(int(step.get("min_select", 0)), 2, "Kofu should require exactly two cards"),
		assert_eq(int(step.get("max_select", 0)), 2, "Kofu should allow exactly two cards"),
		assert_true(bool(step.get("selection_order_matters", false)), "Kofu should declare that click order determines deck-bottom order"),
		assert_false(kofu in step.get("items", []), "Kofu must not be selectable as one of its own two hand cards"),
		assert_true(bool(ui_order_result.get("valid", false)), "Battle interaction validation should accept two ordered selections"),
		assert_eq(ui_order_result.get("selected_items", []), [hand_b, hand_a], "Battle UI should preserve the player's click order"),
		assert_false(missing_valid, "Kofu should reject a missing two-card selection"),
		assert_false(own_card_valid, "Kofu should reject selecting the Supporter card itself"),
		assert_true(exact_valid, "Kofu should accept two distinct other hand cards"),
		assert_false(ai_action.is_empty(), "AI legal actions should include usable Kofu"),
		assert_false(bool(ai_action.get("requires_interaction", true)), "Headless Kofu should construct its legal two-card choice"),
		assert_eq((ai_context.get(KOFU_STEP_ID, []) as Array).size(), 2, "Headless Kofu should supply exactly two hand cards"),
		assert_true(played, "Kofu should resolve through GameStateMachine"),
		assert_eq(player.hand, [hand_c, draw_one, draw_two, draw_three, draw_four], "Kofu should keep the unselected hand card and draw four"),
		assert_eq(player.deck, [deck_remainder, hand_b, hand_a], "Kofu should preserve the selected order at the bottom of the deck"),
		assert_true(kofu in player.discard_pile, "Kofu should enter the discard pile after resolving"),
		assert_true(gsm.game_state.supporter_used_this_turn, "Kofu should consume the Supporter use for the turn"),
		assert_false(CardImplementationStatus.is_unimplemented(card_data), "CSV8C_200 should be marked implemented"),
	])


func test_csv8c200_kofu_is_unusable_with_fewer_than_two_other_hand_cards() -> String:
	var card_data := _load_card("CSV8C", "200")
	if card_data == null:
		return assert_not_null(card_data, "CSV8C_200 should load")
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var kofu := CardInstance.create(card_data, 0)
	var only_other_card := _card("Only Other Card", "Item", 0)
	player.hand.append_array([kofu, only_other_card])
	var effect: BaseEffect = gsm.effect_processor.get_effect(KOFU_EFFECT_ID)
	var actions := AILegalActionBuilderScript.new().build_actions(gsm, 0)
	var ai_action := _find_trainer_action(actions, kofu)
	var played := gsm.play_trainer(0, kofu, [])

	return run_checks([
		assert_not_null(effect, "Kofu should be registered"),
		assert_false(effect.can_execute(kofu, gsm.game_state) if effect != null else true, "Kofu should require two other hand cards"),
		assert_str_contains(
			effect.get_unusable_reason(kofu, gsm.game_state) if effect != null else "",
			"2",
			"Kofu unusable reason should explain the two-card requirement",
		),
		assert_true(ai_action.is_empty(), "AI legal actions should omit unusable Kofu"),
		assert_false(played, "GameStateMachine should reject Kofu when two cards cannot be returned"),
		assert_true(kofu in player.hand, "Rejected Kofu should remain in hand"),
	])


func _load_card(set_code: String, card_index: String) -> CardData:
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card(set_code, card_index)
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


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	return gsm


func _card(name: String, card_type: String, owner_index: int, energy_type: String = "") -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = card_type
	data.energy_type = energy_type
	data.energy_provides = energy_type
	return CardInstance.create(data, owner_index)


func _find_trainer_action(actions: Array[Dictionary], card: CardInstance) -> Dictionary:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == "play_trainer" and action.get("card") == card:
			return action
	return {}
