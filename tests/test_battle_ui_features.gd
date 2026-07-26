## Phase 3 UI 功能测试 - 投币信号、弃牌区数据、卡牌详情文本

class_name TestBattleUIFeatures

extends "res://tests/helpers/BattleUIFeaturesShared.gd"

func test_hand_card_view_left_click_opens_detail_confirmation_without_executing() -> String:
	var display_controller := BattleDisplayControllerScript.new()
	var fake_scene := FakeHandCardScene.new()
	var card := CardInstance.create(_make_trainer_cd("Confirm Tool", "Tool", ""), 0)

	var card_view := display_controller.call("build_hand_card", fake_scene, card) as BattleCardView
	card_view.left_clicked.emit(card, card.card_data)
	card_view.right_clicked.emit(card, card.card_data)

	var result := run_checks([
		assert_eq(fake_scene.hand_detail_calls, 1, "Left-clicking a hand card should open the hand detail confirmation flow"),
		assert_eq(fake_scene.execute_calls, 0, "Left-clicking a hand card should not immediately execute the old hand action"),
		assert_eq(fake_scene.last_hand_detail_card, card, "The confirmation flow should keep the exact hand card instance"),
		assert_eq(fake_scene.detail_calls, 1, "Right-clicking should remain a readonly card detail action"),
		assert_eq(fake_scene.last_detail_card, card.card_data, "Readonly detail should receive the clicked card data"),
	])
	card_view.free()
	return result


func test_hand_card_detail_use_and_cancel_gate_original_execution() -> String:
	var scene := _prepare_detail_scene()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)

	var card := CardInstance.create(_make_trainer_cd("Confirm Tool", "Tool", ""), 0)
	gsm.game_state.players[0].hand = [card]

	scene.call("_show_hand_card_detail", card)
	var action_bar := scene.find_child("DetailActionBar", true, false) as Control
	var use_button := scene.find_child("DetailUseButton", true, false) as Button
	var cancel_button := scene.find_child("DetailCancelButton", true, false) as Button
	var opened_confirmation: bool = action_bar != null and action_bar.visible and use_button != null and use_button.visible and cancel_button != null and cancel_button.visible
	var no_selection_before_use: bool = scene.get("_selected_hand_card") == null

	scene.call("_on_detail_cancel_pressed")
	var no_selection_after_cancel: bool = scene.get("_selected_hand_card") == null

	scene.call("_show_hand_card_detail", card)
	scene.call("_on_detail_use_pressed")
	var selected_after_use: bool = scene.get("_selected_hand_card") == card

	var result := run_checks([
		assert_true(opened_confirmation, "Hand detail should show large Use/Cancel actions for an actionable hand card"),
		assert_true(no_selection_before_use, "Opening detail should not select or use the hand card"),
		assert_true(no_selection_after_cancel, "Cancel should leave the hand card unselected and unused"),
		assert_true(selected_after_use, "Use should call the original hand-card execution path"),
	])
	scene.free()
	return result


func test_effect_reset_clears_hand_drag_suppression_for_next_hand_item_tap() -> String:
	var scene := _prepare_detail_scene()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.set("_active_battle_layout_mode", "portrait")

	var card := CardInstance.create(_make_trainer_cd("Rare Candy", "Item", ""), 0)
	gsm.game_state.players[0].hand = [card]
	scene.set("_pending_choice", "effect_interaction")
	scene.set("_hand_drag_suppress_click_until_msec", Time.get_ticks_msec() + 10000)
	var suppressed_before := bool(scene.call("_is_hand_drag_click_suppressed"))

	scene.call("_reset_effect_interaction")
	var suppressed_after := bool(scene.call("_is_hand_drag_click_suppressed"))
	scene.call("_show_hand_card_detail", card)

	var action_bar := scene.find_child("DetailActionBar", true, false) as Control
	var use_button := scene.find_child("DetailUseButton", true, false) as Button
	var opened_confirmation: bool = action_bar != null and action_bar.visible and use_button != null and use_button.visible
	var result := run_checks([
		assert_true(suppressed_before, "The test should start with a stale hand drag click suppression window"),
		assert_false(suppressed_after, "Finishing an effect dialog should clear stale hand drag click suppression"),
		assert_true(opened_confirmation, "The next hand Item tap after an effect dialog should open its Use/Cancel confirmation immediately"),
	])
	scene.free()
	return result


func test_successful_action_refresh_clears_hand_drag_suppression_for_next_hand_item_tap() -> String:
	var scene := _prepare_detail_scene()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.set("_active_battle_layout_mode", "portrait")

	var card := CardInstance.create(_make_trainer_cd("Next Item", "Item", ""), 0)
	gsm.game_state.players[0].hand = [card]
	scene.set("_hand_drag_suppress_click_until_msec", Time.get_ticks_msec() + 10000)
	var suppressed_before := bool(scene.call("_is_hand_drag_click_suppressed"))

	scene.call("_refresh_ui_after_successful_action", false, 0)
	var suppressed_after := bool(scene.call("_is_hand_drag_click_suppressed"))
	scene.call("_show_hand_card_detail", card)

	var action_bar := scene.find_child("DetailActionBar", true, false) as Control
	var use_button := scene.find_child("DetailUseButton", true, false) as Button
	var opened_confirmation: bool = action_bar != null and action_bar.visible and use_button != null and use_button.visible
	var result := run_checks([
		assert_true(suppressed_before, "The test should start with a stale hand drag click suppression window"),
		assert_false(suppressed_after, "Successful action refresh should clear stale hand drag click suppression"),
		assert_true(opened_confirmation, "The next hand Item tap after a completed action should open its Use/Cancel confirmation immediately"),
	])
	scene.free()
	return result


func test_successful_action_refresh_clears_stale_modal_release_fallback_for_next_hand_item_tap() -> String:
	var scene := _prepare_detail_scene()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.set("_active_battle_layout_mode", "portrait")

	var card := CardInstance.create(_make_trainer_cd("Post Non Modal Item", "Item", ""), 0)
	gsm.game_state.players[0].hand = [card]
	scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec())
	scene.set("_dialog_modal_transition_depth", 0)
	var fallback_before := bool(scene.call("_should_arm_hand_primary_release_fallback"))

	scene.call("_refresh_ui_after_successful_action", false, 0)
	var fallback_after := bool(scene.call("_should_arm_hand_primary_release_fallback"))
	var hand_container := scene.get("_hand_container") as HBoxContainer
	var hand_view := _first_battle_card_view(hand_container)
	var hand_fallback_armed := hand_view != null and hand_view.is_primary_release_fallback_armed()
	scene.call("_show_hand_card_detail", card)

	var action_bar := scene.find_child("DetailActionBar", true, false) as Control
	var use_button := scene.find_child("DetailUseButton", true, false) as Button
	var opened_confirmation: bool = action_bar != null and action_bar.visible and use_button != null and use_button.visible
	var result := run_checks([
		assert_true(fallback_before, "The test should start inside a stale modal hand-release fallback window"),
		assert_false(fallback_after, "A non-modal successful action should clear stale modal hand-release fallback"),
		assert_false(hand_fallback_armed, "Rebuilt hand cards after a non-modal success must not inherit stale modal fallback"),
		assert_true(opened_confirmation, "The next hand Item tap after a non-modal success should open its Use/Cancel confirmation immediately"),
	])
	scene.free()
	return result


func test_modal_completion_clears_hand_drag_suppression_for_next_hand_item_tap() -> String:
	var scene := _prepare_detail_scene()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.set("_active_battle_layout_mode", "portrait")

	var card := CardInstance.create(_make_trainer_cd("Post Modal Item", "Item", ""), 0)
	gsm.game_state.players[0].hand = [card]
	scene.set("_hand_drag_suppress_click_until_msec", Time.get_ticks_msec() + 10000)
	var suppressed_before := bool(scene.call("_is_hand_drag_click_suppressed"))

	scene.call("_mark_modal_input_consumed", "test_dialog_confirm")
	var suppressed_after := bool(scene.call("_is_hand_drag_click_suppressed"))
	var modal_slot_suppression_armed := int(scene.get("_modal_input_slot_suppress_until_msec")) > Time.get_ticks_msec()
	scene.call("_show_hand_card_detail", card)

	var action_bar := scene.find_child("DetailActionBar", true, false) as Control
	var use_button := scene.find_child("DetailUseButton", true, false) as Button
	var opened_confirmation: bool = action_bar != null and action_bar.visible and use_button != null and use_button.visible
	var result := run_checks([
		assert_true(suppressed_before, "The test should start with a stale hand drag click suppression window"),
		assert_false(suppressed_after, "Completing a modal dialog should clear stale hand drag click suppression"),
		assert_true(modal_slot_suppression_armed, "Completing a modal dialog should still arm slot click-through suppression"),
		assert_true(opened_confirmation, "The next hand Item tap after a modal dialog should open its Use/Cancel confirmation immediately"),
	])
	scene.free()
	return result


func test_pokemon_and_energy_hand_cards_directly_enter_selected_state() -> String:
	var scene := _prepare_detail_scene()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)

	var basic := CardInstance.create(_make_pokemon_cd("Direct Basic", 70, "G"), 0)
	var energy := CardInstance.create(_make_energy_cd("Direct Grass Energy", "G"), 0)
	gsm.game_state.players[0].hand = [basic, energy]

	scene.call("_show_hand_card_detail", basic)
	var selected_basic: bool = scene.get("_selected_hand_card") == basic
	var detail_hidden_after_basic: bool = not ((scene.find_child("DetailOverlay", true, false) as Control).visible)

	scene.call("_show_hand_card_detail", energy)
	var selected_energy: bool = scene.get("_selected_hand_card") == energy
	var detail_hidden_after_energy: bool = not ((scene.find_child("DetailOverlay", true, false) as Control).visible)

	var result := run_checks([
		assert_true(selected_basic, "Pokemon hand cards should directly enter the old selected-card state"),
		assert_true(detail_hidden_after_basic, "Pokemon hand cards should not open the confirmation detail popup"),
		assert_true(selected_energy, "Energy hand cards should directly enter the old selected-card state"),
		assert_true(detail_hidden_after_energy, "Energy hand cards should not open the confirmation detail popup"),
	])
	scene.free()
	return result


func test_selected_pokemon_second_tap_detail_cancel_clears_and_place_keeps_selection() -> String:
	var scene := _prepare_detail_scene()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)

	var basic := CardInstance.create(_make_pokemon_cd("Confirm Basic", 70, "G"), 0)
	gsm.game_state.players[0].hand = [basic]

	scene.call("_show_hand_card_detail", basic)
	var selected_after_first_tap: bool = scene.get("_selected_hand_card") == basic
	scene.call("_show_hand_card_detail", basic)
	var overlay := scene.find_child("DetailOverlay", true, false) as Control
	var action_bar := scene.find_child("DetailActionBar", true, false) as Control
	var use_button := scene.find_child("DetailUseButton", true, false) as Button
	var cancel_button := scene.find_child("DetailCancelButton", true, false) as Button
	var opened_selected_detail: bool = overlay != null and overlay.visible and action_bar != null and action_bar.visible
	var place_label: bool = use_button != null and use_button.text == "放置"
	var cancel_label: bool = cancel_button != null and cancel_button.text == "取消"

	scene.call("_on_detail_cancel_pressed")
	var cleared_after_cancel: bool = scene.get("_selected_hand_card") == null
	var hidden_after_cancel: bool = overlay != null and not overlay.visible

	scene.set("_selected_hand_card", basic)
	scene.call("_show_hand_card_detail", basic)
	scene.call("_on_detail_use_pressed")
	var selected_after_place: bool = scene.get("_selected_hand_card") == basic
	var hidden_after_place: bool = overlay != null and not overlay.visible

	var result := run_checks([
		assert_true(selected_after_first_tap, "First tap should keep the old direct-select Pokemon behavior"),
		assert_true(opened_selected_detail, "Second tap on the selected Pokemon should open detail actions"),
		assert_true(place_label, "Selected Pokemon detail should label the primary action as Place"),
		assert_true(cancel_label, "Selected Pokemon detail should keep the secondary action as Cancel"),
		assert_true(cleared_after_cancel, "Cancel should clear the selected hand Pokemon"),
		assert_true(hidden_after_cancel, "Cancel should close the card detail overlay"),
		assert_true(selected_after_place, "Place should close detail while keeping the Pokemon selected"),
		assert_true(hidden_after_place, "Place should close the card detail overlay"),
	])
	scene.free()
	return result


func test_selected_hand_card_clears_when_another_hand_card_discards_it() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var battle_scene := _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	var tablet := CardInstance.create(_make_trainer_cd("Selection Tablet", "Tool", "Selected before Research"), 0)
	var professor_cd := _make_trainer_cd("Professor's Research", "Supporter", "Discard your hand and draw 7 cards.")
	professor_cd.effect_id = "aecd80ca2722885c3d062a2255346f3e"
	var professor := CardInstance.create(professor_cd, 0)
	gsm.game_state.players[0].hand = [tablet, professor]
	for draw_index: int in 7:
		gsm.game_state.players[0].deck.append(CardInstance.create(_make_pokemon_cd("Research Replacement %d" % [draw_index + 1], 70, "C"), 0))

	battle_scene.set("_selected_hand_card", tablet)
	battle_scene.call("_on_hand_card_clicked", professor, PanelContainer.new())
	var selected_after_research: Variant = battle_scene.get("_selected_hand_card")
	var old_tablet_in_hand := tablet in gsm.game_state.players[0].hand
	var old_tablet_in_discard := tablet in gsm.game_state.players[0].discard_pile
	battle_scene.call("_refresh_hand")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	var selected_view_count := 0
	for child: Node in hand_container.get_children():
		var card_view := child as BattleCardView
		if card_view != null and bool(card_view.get("_selected")):
			selected_view_count += 1
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_false(old_tablet_in_hand, "Precondition: Professor's Research should remove the previously selected card from hand"),
		assert_true(old_tablet_in_discard, "Precondition: Professor's Research should discard the previously selected hand card"),
		assert_null(selected_after_research, "Playing a different hand card must clear any selected card that left the hand"),
		assert_eq(selected_view_count, 0, "Hand rebuild should not keep a stale placement highlight after the selected card leaves hand"),
	])


func test_selected_hand_card_clears_when_playing_different_trainer_that_leaves_it_in_hand() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var battle_scene := _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.effect_processor.register_effect("draw_one_without_discard_probe", EffectDrawCards.new(1, false))
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	var tablet := CardInstance.create(_make_trainer_cd("Selection Tablet", "Tool", "Selected before another Trainer"), 0)
	var draw_item_cd := _make_trainer_cd("Draw Probe Item", "Item", "Draw 1 card.")
	draw_item_cd.effect_id = "draw_one_without_discard_probe"
	var draw_item := CardInstance.create(draw_item_cd, 0)
	var drawn := CardInstance.create(_make_pokemon_cd("Drawn Replacement", 70, "C"), 0)
	gsm.game_state.players[0].hand = [tablet, draw_item]
	gsm.game_state.players[0].deck = [drawn]

	battle_scene.set("_selected_hand_card", tablet)
	battle_scene.call("_on_hand_card_clicked", draw_item, PanelContainer.new())
	var selected_after_item: Variant = battle_scene.get("_selected_hand_card")
	var tablet_still_in_hand := tablet in gsm.game_state.players[0].hand
	var item_in_discard := draw_item in gsm.game_state.players[0].discard_pile
	battle_scene.call("_refresh_hand")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	var selected_view_count := 0
	for child: Node in hand_container.get_children():
		var card_view := child as BattleCardView
		if card_view != null and bool(card_view.get("_selected")):
			selected_view_count += 1
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_true(tablet_still_in_hand, "Precondition: the previously selected Tool should stay in hand for this generic Trainer path"),
		assert_true(item_in_discard, "Precondition: the clicked Trainer should resolve"),
		assert_null(selected_after_item, "Clicking a different playable hand card should cancel the old placement selection even if that card remains in hand"),
		assert_eq(selected_view_count, 0, "Hand rebuild should not keep a placement highlight after another Trainer is played"),
	])


func test_hand_card_left_click_waits_for_release_and_drag_suppresses_click() -> String:
	var display_controller := BattleDisplayControllerScript.new()
	var fake_scene := FakeHandCardScene.new()
	var card := CardInstance.create(_make_trainer_cd("Scrollable Tool", "Tool", ""), 0)
	var card_view := display_controller.call("build_hand_card", fake_scene, card) as BattleCardView

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(24, 24)
	press.global_position = Vector2(24, 24)
	card_view.call("_gui_input", press)
	var calls_after_press := fake_scene.hand_detail_calls

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(24, 24)
	release.global_position = Vector2(24, 24)
	card_view.call("_gui_input", release)
	var calls_after_release := fake_scene.hand_detail_calls

	press.global_position = Vector2(200, 24)
	press.position = Vector2(200, 24)
	card_view.call("_gui_input", press)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(40, 24)
	drag.global_position = Vector2(40, 24)
	card_view.call("_gui_input", drag)
	release.global_position = Vector2(40, 24)
	release.position = Vector2(40, 24)
	card_view.call("_gui_input", release)
	var calls_after_drag_release := fake_scene.hand_detail_calls

	var result := run_checks([
		assert_eq(calls_after_press, 0, "Hand cards should not open detail on mouse press so the row can start dragging"),
		assert_eq(calls_after_release, 1, "Hand cards should open detail on release when no drag happened"),
		assert_eq(calls_after_drag_release, 1, "Dragging a hand card should scroll instead of opening the card detail"),
	])
	card_view.free()
	return result


func test_battle_card_view_primary_release_fallback_handles_missing_press_once() -> String:
	var card_view := BattleCardViewScript.new()
	var card := CardInstance.create(_make_trainer_cd("Fallback Tool", "Tool", ""), 0)
	var counters := {"left": 0}
	card_view.setup_from_instance(card, BattleCardViewScript.MODE_HAND)
	card_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		counters["left"] = int(counters["left"]) + 1
	)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(24, 24)
	release.global_position = Vector2(24, 24)
	card_view.call("_gui_input", release)
	var count_without_fallback := int(counters["left"])
	card_view.call("arm_primary_release_fallback", "test_missing_press", 0, 1000)
	var armed_before_release := bool(card_view.call("is_primary_release_fallback_armed"))
	card_view.call("_gui_input", release)
	var count_after_fallback := int(counters["left"])
	card_view.call("_gui_input", release)
	var count_after_second_release := int(counters["left"])

	var result := run_checks([
		assert_eq(count_without_fallback, 0, "A release without a tracked press should normally do nothing"),
		assert_true(armed_before_release, "The fallback should be armed before the first release"),
		assert_eq(count_after_fallback, 1, "The fallback should convert one missing-press release into a click"),
		assert_eq(count_after_second_release, 1, "The fallback should be one-shot and not repeat on later releases"),
	])
	card_view.free()
	return result


func test_battle_card_view_input_catcher_forwards_touch_clicks() -> String:
	var card_view := BattleCardViewScript.new()
	var card := CardInstance.create(_make_pokemon_cd("Touch Catcher", 70, "C"), 0)
	var counters := {"left": 0}
	card_view.setup_from_instance(card, BattleCardViewScript.MODE_PREVIEW)
	card_view.set_clickable(true)
	card_view.set_meta("card_gallery_drag_input_enabled", true)
	card_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		counters["left"] = int(counters["left"]) + 1
	)

	var catcher := card_view.find_child("CardInputCatcher", true, false) as Control
	if catcher != null:
		var press := InputEventScreenTouch.new()
		press.pressed = true
		press.index = 0
		press.position = Vector2(32, 32)
		catcher.gui_input.emit(press)

		var release := InputEventScreenTouch.new()
		release.pressed = false
		release.index = 0
		release.position = Vector2(32, 32)
		catcher.gui_input.emit(release)

	card_view.set_clickable(false)
	var disabled_filter := catcher.mouse_filter if catcher != null else -1

	var result := run_checks([
		assert_true(catcher != null, "BattleCardView should create a transparent input catcher for mobile Web card taps"),
		assert_eq(counters["left"], 1, "Touch events received by the input catcher should forward to the existing card click signal"),
		assert_eq(disabled_filter, Control.MOUSE_FILTER_IGNORE, "Disabling card clicks should also disable the input catcher"),
	])
	card_view.free()
	return result


func test_battle_card_view_choice_mode_accepts_pure_screen_touch_without_mouse_echo() -> String:
	var card_view := BattleCardViewScript.new()
	var card := CardInstance.create(_make_pokemon_cd("Android Choice Touch", 70, "C"), 0)
	var counters := {"left": 0}
	card_view.setup_from_instance(card, BattleCardViewScript.MODE_CHOICE)
	card_view.set_clickable(true)
	card_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		counters["left"] = int(counters["left"]) + 1
	)

	var catcher := card_view.find_child("CardInputCatcher", true, false) as Control
	if catcher != null:
		var press := InputEventScreenTouch.new()
		press.pressed = true
		press.index = 0
		press.position = Vector2(36, 36)
		catcher.gui_input.emit(press)

		var release := InputEventScreenTouch.new()
		release.pressed = false
		release.index = 0
		release.position = Vector2(36, 36)
		catcher.gui_input.emit(release)

	var result := run_checks([
		assert_true(catcher != null, "Choice cards should create the transparent input catcher"),
		assert_eq(counters["left"], 1, "A pure Android ScreenTouch press/release should select a choice card even without an emulated MouseButton"),
	])
	card_view.free()
	return result


func test_battle_card_view_non_clickable_slot_card_does_not_capture_touch_children() -> String:
	var card_view := BattleCardViewScript.new()
	var card := CardInstance.create(_make_pokemon_cd("Android Field Slot", 70, "C"), 0)
	card_view.set_clickable(false)
	card_view.setup_from_instance(card, BattleCardViewScript.MODE_SLOT_ACTIVE)
	card_view.set_battle_status({
		"hp_current": 50,
		"hp_max": 70,
		"hp_ratio": 50.0 / 70.0,
		"status_icons": ["poisoned"],
		"energy_icons": ["R", "C"],
		"tool_name": "Test Tool",
		"ability_used_this_turn": true,
	})

	var catcher := card_view.find_child("CardInputCatcher", true, false) as Control
	var blocking_child_count := _count_pointer_blocking_children(card_view, catcher)

	var result := run_checks([
		assert_eq(card_view.mouse_filter, Control.MOUSE_FILTER_IGNORE, "A non-clickable field slot card root should pass touch events to the slot panel"),
		assert_true(catcher == null or catcher.mouse_filter == Control.MOUSE_FILTER_IGNORE, "A field slot card should not use the transparent card input catcher"),
		assert_eq(blocking_child_count, 0, "Non-clickable field slot card internals should not intercept Android Web touch events before the slot panel"),
	])
	card_view.free()
	return result


func test_card_search_dialog_does_not_arm_release_fallback_for_fresh_choices() -> String:
	var battle_scene = _make_battle_scene_stub()
	var card := CardInstance.create(_make_pokemon_cd("Search Target", 60, "C"), 0)
	battle_scene.set("_pending_choice", "effect_interaction")
	battle_scene.call("_show_dialog", "Search", [], {
		"presentation": "cards",
		"card_items": [card],
		"choice_labels": ["Search Target"],
		"min_select": 0,
		"max_select": 2,
		"allow_cancel": true,
	})

	var row := battle_scene.get("_dialog_card_row") as HBoxContainer
	var card_view := row.get_child(0) as BattleCardView if row != null and row.get_child_count() > 0 else null
	var armed_on_open := card_view != null and bool(card_view.call("is_primary_release_fallback_armed"))
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(24, 24)
	release.global_position = Vector2(24, 24)
	if card_view != null:
		card_view.call("_gui_input", release)
	var selected_without_fallback: Array = (battle_scene.get("_dialog_card_selected_indices") as Array).duplicate()
	if card_view != null:
		card_view.call("arm_primary_release_fallback", "test_dialog_missing_press", 0, 1000)
		card_view.call("_gui_input", release)
	var selected_after_manual_fallback: Array = (battle_scene.get("_dialog_card_selected_indices") as Array).duplicate()

	var result := run_checks([
		assert_true(card_view != null, "Card search dialog should render a card view"),
		assert_false(armed_on_open, "Fresh dialog cards should not arm a missing-press fallback from the previous modal touch"),
		assert_eq(selected_without_fallback, [], "A release-only event from the previous touch should not select a fresh dialog card"),
		assert_eq(selected_after_manual_fallback, [0], "BattleCardView fallback still works when deliberately armed for hand-card recovery paths"),
	])
	battle_scene.free()
	return result


func test_card_search_dialog_normal_press_release_selects_fresh_choice() -> String:
	var mouse_scene = _make_battle_scene_stub()
	var mouse_card := CardInstance.create(_make_pokemon_cd("Mouse Search Target", 60, "C"), 0)
	mouse_scene.set("_pending_choice", "effect_interaction")
	mouse_scene.call("_show_dialog", "Search", [], {
		"presentation": "cards",
		"card_items": [mouse_card],
		"choice_labels": ["Mouse Search Target"],
		"min_select": 0,
		"max_select": 2,
		"allow_cancel": true,
	})
	var mouse_row := mouse_scene.get("_dialog_card_row") as HBoxContainer
	var mouse_card_view := mouse_row.get_child(0) as BattleCardView if mouse_row != null and mouse_row.get_child_count() > 0 else null
	if mouse_card_view != null:
		var mouse_press := InputEventMouseButton.new()
		mouse_press.button_index = MOUSE_BUTTON_LEFT
		mouse_press.pressed = true
		mouse_press.position = Vector2(24, 24)
		mouse_press.global_position = Vector2(24, 24)
		var mouse_release := InputEventMouseButton.new()
		mouse_release.button_index = MOUSE_BUTTON_LEFT
		mouse_release.pressed = false
		mouse_release.position = Vector2(24, 24)
		mouse_release.global_position = Vector2(24, 24)
		mouse_card_view.call("_gui_input", mouse_press)
		mouse_card_view.call("_gui_input", mouse_release)
	var mouse_selected: Array = (mouse_scene.get("_dialog_card_selected_indices") as Array).duplicate()

	var touch_scene = _make_battle_scene_stub()
	var touch_card := CardInstance.create(_make_pokemon_cd("Touch Search Target", 60, "C"), 0)
	touch_scene.set("_pending_choice", "effect_interaction")
	touch_scene.call("_show_dialog", "Search", [], {
		"presentation": "cards",
		"card_items": [touch_card],
		"choice_labels": ["Touch Search Target"],
		"min_select": 0,
		"max_select": 2,
		"allow_cancel": true,
	})
	var touch_row := touch_scene.get("_dialog_card_row") as HBoxContainer
	var touch_card_view := touch_row.get_child(0) as BattleCardView if touch_row != null and touch_row.get_child_count() > 0 else null
	if touch_card_view != null:
		var touch_press := InputEventScreenTouch.new()
		touch_press.index = 0
		touch_press.pressed = true
		touch_press.position = Vector2(24, 24)
		var touch_release := InputEventScreenTouch.new()
		touch_release.index = 0
		touch_release.pressed = false
		touch_release.position = Vector2(24, 24)
		touch_card_view.call("_gui_input", touch_press)
		touch_card_view.call("_gui_input", touch_release)
	var touch_selected: Array = (touch_scene.get("_dialog_card_selected_indices") as Array).duplicate()

	var result := run_checks([
		assert_true(mouse_card_view != null, "Mouse card search dialog should render a clickable card view"),
		assert_eq(mouse_selected, [0], "Mouse press/release should select a fresh dialog card without fallback"),
		assert_true(touch_card_view != null, "Touch card search dialog should render a clickable card view"),
		assert_eq(touch_selected, [0], "ScreenTouch press/release should select a fresh dialog card without fallback"),
	])
	mouse_scene.free()
	touch_scene.free()
	return result


func test_setup_active_touch_with_horizontal_jitter_still_selects_basic() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 0
	gsm.game_state.phase = GameState.GamePhase.SETUP
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	battle_scene.set("_setup_done", [false, true])

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var lead_card := CardInstance.create(_make_pokemon_cd("Mobile Lead", 70, "C"), 0)
	gsm.game_state.players[0].hand.append(lead_card)

	battle_scene.call("_show_setup_active_dialog", 0)

	var row := battle_scene.get("_dialog_card_row") as HBoxContainer
	var card_view := row.get_child(0) as BattleCardView if row != null and row.get_child_count() > 0 else null
	if card_view != null:
		var press := InputEventScreenTouch.new()
		press.pressed = true
		press.index = 0
		press.position = Vector2(220, 24)
		card_view.call("_gui_input", press)

		var jitter := InputEventScreenDrag.new()
		jitter.index = 0
		jitter.position = Vector2(238, 30)
		card_view.call("_gui_input", jitter)

		var release := InputEventScreenTouch.new()
		release.pressed = false
		release.index = 0
		release.position = Vector2(238, 30)
		card_view.call("_gui_input", release)

	var active_slot := gsm.game_state.players[0].active_pokemon
	var active_card := active_slot.get_top_card() if active_slot != null else null
	var result := run_checks([
		assert_true(card_view != null, "Setup active dialog should render a card view for the basic Pokemon"),
		assert_eq(active_card, lead_card, "A mobile setup-card tap with minor horizontal jitter should still choose the active Pokemon"),
		assert_false(bool(battle_scene.call("_is_card_gallery_drag_click_suppressed")), "Minor touch jitter in setup should not arm gallery drag click suppression"),
	])
	battle_scene.free()
	return result


func test_modal_completion_arms_existing_hand_card_release_fallback() -> String:
	var battle_scene = _make_battle_scene_stub()
	var card := CardInstance.create(_make_trainer_cd("Post Modal Tool", "Tool", ""), 0)
	var hand_card := battle_scene.call("_build_hand_card", card) as BattleCardView
	var hand_container := battle_scene.get("_hand_container") as HBoxContainer
	if hand_container != null and hand_card != null:
		hand_container.add_child(hand_card)

	battle_scene.call("_mark_modal_input_consumed", "test_modal_hand_fallback")
	var armed_after_modal := hand_card != null and bool(hand_card.call("is_primary_release_fallback_armed"))

	var result := run_checks([
		assert_true(hand_card != null, "The test should create a hand card view"),
		assert_true(armed_after_modal, "Completing a modal should arm existing hand cards for a missing-press release fallback"),
	])
	battle_scene.free()
	return result


func test_battle_hand_scroll_uses_drag_scroller_without_native_bar() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	var hand_scroll := scene.find_child("HandScroll", true, false) as ScrollContainer
	scene.set("_hand_scroll", hand_scroll)
	scene.call("_setup_hand_drag_scroll")
	var hbar := hand_scroll.get_h_scroll_bar() if hand_scroll != null else null
	var vbar := hand_scroll.get_v_scroll_bar() if hand_scroll != null else null

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = Vector2(220, 24)
	var press_consumed := bool(scene.call("_handle_hand_drag_scroll_input", press))
	var drag := InputEventMouseMotion.new()
	drag.global_position = Vector2(80, 24)
	var drag_consumed := bool(scene.call("_handle_hand_drag_scroll_input", drag))
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.global_position = Vector2(80, 24)
	var release_consumed := bool(scene.call("_handle_hand_drag_scroll_input", release))

	var result := run_checks([
		assert_eq(hand_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO, "Hand row should keep ScrollContainer sizing semantics while hiding the native bar"),
		assert_eq(hand_scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "Hand row should disable vertical scrolling"),
		assert_true(bool(hand_scroll.get_meta("hand_drag_scroll_enabled", false)), "Hand row should mark the drag-scroll contract for layout tests"),
		assert_true(hbar != null and bool(hbar.get_meta("hand_hidden_scrollbar", false)) and hbar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Hand horizontal scrollbar should be hidden and non-interactive"),
		assert_true(vbar != null and bool(vbar.get_meta("hand_hidden_scrollbar", false)) and vbar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Hand vertical scrollbar should be hidden and non-interactive"),
		assert_true(press_consumed, "Hand drag should consume the initial press so native ScrollContainer drag does not fight the custom drag"),
		assert_true(drag_consumed, "Horizontal drag past the threshold should be consumed by the hand scroller"),
		assert_true(release_consumed, "Release after a drag should be consumed to suppress accidental card use"),
		assert_true(bool(scene.call("_is_hand_drag_click_suppressed")), "Release after a drag should suppress follow-up hand-card clicks briefly"),
	])
	scene.free()
	return result


func test_portrait_hand_drag_then_fresh_touch_tap_opens_item_detail() -> String:
	var scene := _prepare_detail_scene()
	scene.set("_active_battle_layout_mode", "portrait")
	var hand_scroll := scene.find_child("HandScroll", true, false) as ScrollContainer
	var hand_container := scene.find_child("HandContainer", true, false) as HBoxContainer
	scene.set("_hand_scroll", hand_scroll)
	scene.set("_hand_container", hand_container)
	scene.call("_setup_hand_drag_scroll")
	_prepare_overflowing_hand_scroll_for_drag_test(hand_scroll)
	if hand_container != null:
		scene.call("_clear_container_children", hand_container)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item", ""), 0)
	ultra_ball.card_data.effect_id = "a337ed34a45e63c6d21d98c3d8e0cb6e"
	gsm.game_state.players[0].hand.append(ultra_ball)
	var hand_card := scene.call("_build_hand_card", ultra_ball) as BattleCardView
	if hand_container != null and hand_card != null:
		hand_container.add_child(hand_card)

	if hand_card != null:
		var drag_press := InputEventScreenTouch.new()
		drag_press.pressed = true
		drag_press.index = 0
		drag_press.position = Vector2(220, 32)
		hand_card.call("_gui_input", drag_press)
		var drag_motion := InputEventScreenDrag.new()
		drag_motion.index = 0
		drag_motion.position = Vector2(80, 32)
		drag_motion.relative = Vector2(-140, 0)
		hand_card.call("_gui_input", drag_motion)
		var drag_release := InputEventScreenTouch.new()
		drag_release.pressed = false
		drag_release.index = 0
		drag_release.position = Vector2(80, 32)
		hand_card.call("_gui_input", drag_release)
	var detail_overlay := scene.find_child("DetailOverlay", true, false) as Control
	var suppressed_after_drag := bool(scene.call("_is_hand_drag_click_suppressed"))
	var detail_open_after_drag := detail_overlay != null and detail_overlay.visible

	if hand_card != null:
		var tap_press := InputEventScreenTouch.new()
		tap_press.pressed = true
		tap_press.index = 0
		tap_press.position = Vector2(132, 32)
		hand_card.call("_gui_input", tap_press)
		var suppressed_after_fresh_press := bool(scene.call("_is_hand_drag_click_suppressed"))
		var tap_release := InputEventScreenTouch.new()
		tap_release.pressed = false
		tap_release.index = 0
		tap_release.position = Vector2(132, 32)
		hand_card.call("_gui_input", tap_release)
		scene.set_meta("suppressed_after_fresh_press", suppressed_after_fresh_press)

	var detail_action_bar := scene.find_child("DetailActionBar", true, false) as Control
	var use_button := scene.find_child("DetailUseButton", true, false) as Button
	var result := run_checks([
		assert_true(hand_scroll != null and hand_container != null and hand_card != null, "The test should build a real portrait hand card inside HandScroll"),
		assert_true(suppressed_after_drag, "Dragging the hand row should arm the short click suppression window"),
		assert_false(detail_open_after_drag, "The drag release itself should not open the hand-card detail popup"),
		assert_false(bool(scene.get_meta("suppressed_after_fresh_press", true)), "A new ScreenTouch press should clear stale hand-drag suppression"),
		assert_true(detail_overlay != null and detail_overlay.visible, "A fresh touch tap immediately after hand scrolling should open the item detail popup"),
		assert_true(detail_action_bar != null and detail_action_bar.visible and use_button != null and use_button.visible, "The item detail popup should expose the Use action after the fresh tap"),
	])
	scene.free()
	return result


func test_portrait_touch_drag_mouse_echo_does_not_open_item_detail() -> String:
	var scene := _prepare_detail_scene()
	scene.set("_active_battle_layout_mode", "portrait")
	var hand_scroll := scene.find_child("HandScroll", true, false) as ScrollContainer
	var hand_container := scene.find_child("HandContainer", true, false) as HBoxContainer
	scene.set("_hand_scroll", hand_scroll)
	scene.set("_hand_container", hand_container)
	scene.call("_setup_hand_drag_scroll")
	_prepare_overflowing_hand_scroll_for_drag_test(hand_scroll)
	if hand_container != null:
		scene.call("_clear_container_children", hand_container)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item", ""), 0)
	ultra_ball.card_data.effect_id = "a337ed34a45e63c6d21d98c3d8e0cb6e"
	gsm.game_state.players[0].hand.append(ultra_ball)
	var hand_card := scene.call("_build_hand_card", ultra_ball) as BattleCardView
	if hand_container != null and hand_card != null:
		hand_container.add_child(hand_card)

	if hand_card != null:
		var drag_press := InputEventScreenTouch.new()
		drag_press.pressed = true
		drag_press.index = 0
		drag_press.position = Vector2(220, 32)
		hand_card.call("_gui_input", drag_press)
		var drag_motion := InputEventScreenDrag.new()
		drag_motion.index = 0
		drag_motion.position = Vector2(80, 32)
		drag_motion.relative = Vector2(-140, 0)
		hand_card.call("_gui_input", drag_motion)
		var drag_release := InputEventScreenTouch.new()
		drag_release.pressed = false
		drag_release.index = 0
		drag_release.position = Vector2(80, 32)
		hand_card.call("_gui_input", drag_release)

	if hand_card != null:
		var echo_press := InputEventMouseButton.new()
		echo_press.button_index = MOUSE_BUTTON_LEFT
		echo_press.pressed = true
		echo_press.position = Vector2(80, 32)
		echo_press.global_position = Vector2(80, 32)
		hand_card.call("_gui_input", echo_press)
		var echo_release := InputEventMouseButton.new()
		echo_release.button_index = MOUSE_BUTTON_LEFT
		echo_release.pressed = false
		echo_release.position = Vector2(80, 32)
		echo_release.global_position = Vector2(80, 32)
		hand_card.call("_gui_input", echo_release)

	var detail_overlay := scene.find_child("DetailOverlay", true, false) as Control
	var result := run_checks([
		assert_true(hand_scroll != null and hand_container != null and hand_card != null, "The test should build a real portrait hand card inside HandScroll"),
		assert_true(bool(scene.call("_is_hand_drag_click_suppressed")), "The touch-drag suppression window should remain active for the same-position mouse echo"),
		assert_false(detail_overlay != null and detail_overlay.visible, "The same-position synthetic mouse echo after a touch drag must not open the item detail popup"),
	])
	scene.free()
	return result


func test_battle_hand_drag_tracks_pointer_direction_after_press() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	var hand_scroll := scene.find_child("HandScroll", true, false) as ScrollContainer
	scene.set("_hand_scroll", hand_scroll)
	scene.call("_setup_hand_drag_scroll")
	_prepare_overflowing_hand_scroll_for_drag_test(hand_scroll)
	hand_scroll.scroll_horizontal = 300
	var start_scroll := hand_scroll.scroll_horizontal

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = Vector2(200, 24)
	scene.call("_handle_hand_drag_scroll_input", press)

	var drag_left := InputEventMouseMotion.new()
	drag_left.global_position = Vector2(120, 24)
	scene.call("_input", drag_left)
	var scroll_after_left_drag := hand_scroll.scroll_horizontal

	var drag_right := InputEventMouseMotion.new()
	drag_right.global_position = Vector2(260, 24)
	scene.call("_input", drag_right)
	var scroll_after_right_drag := hand_scroll.scroll_horizontal

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.global_position = Vector2(260, 24)
	scene.call("_input", release)

	var result := run_checks([
		assert_true(scroll_after_left_drag > start_scroll, "Dragging the pointer left should move the hand rail toward later cards"),
		assert_true(scroll_after_right_drag < start_scroll, "Dragging the pointer right should move the hand rail back toward earlier cards"),
		assert_false(bool(scene.get("_hand_drag_active")), "Global hand drag capture should end on release"),
	])
	scene.free()
	return result


func test_battle_hand_drag_reaches_new_cards_when_scrollbar_range_is_stale() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	var hand_scroll := scene.find_child("HandScroll", true, false) as ScrollContainer
	scene.set("_hand_scroll", hand_scroll)
	scene.call("_setup_hand_drag_scroll")
	_prepare_overflowing_hand_scroll_for_drag_test(hand_scroll)
	var hand_content := hand_scroll.get_child(0) as Control if hand_scroll != null and hand_scroll.get_child_count() > 0 else null
	if hand_content != null:
		for child: Node in hand_content.get_children():
			hand_content.remove_child(child)
			child.queue_free()
		hand_content.size = Vector2(1400, 180)
		hand_content.custom_minimum_size = Vector2(0, 180)
		if hand_content is BoxContainer:
			(hand_content as BoxContainer).add_theme_constant_override("separation", 8)
		for card_index: int in 12:
			var card := Control.new()
			card.custom_minimum_size = Vector2(180, 180)
			hand_content.add_child(card)
	var hbar := hand_scroll.get_h_scroll_bar() if hand_scroll != null else null
	if hbar != null:
		hbar.min_value = 0.0
		hbar.max_value = 1000.0
		hbar.page = 400.0
	hand_scroll.scroll_horizontal = 300
	var start_scroll := hand_scroll.scroll_horizontal

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = Vector2(220, 24)
	scene.call("_handle_hand_drag_scroll_input", press)

	var drag_left := InputEventMouseMotion.new()
	drag_left.global_position = Vector2(-1200, 24)
	scene.call("_input", drag_left)
	var scroll_after_drag := hand_scroll.scroll_horizontal

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.global_position = Vector2(-1200, 24)
	scene.call("_input", release)

	var result := run_checks([
		assert_true(scroll_after_drag > 1000, "Hand drag should reach cards added after the previous scrollbar range"),
		assert_true(scroll_after_drag > start_scroll, "Dragging left should still advance the hand rail"),
		assert_false(bool(scene.get("_hand_drag_active")), "Global hand drag capture should end on release"),
	])
	scene.free()
	return result


func test_hand_drag_clears_stale_card_gallery_capture() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	var hand_scroll := scene.find_child("HandScroll", true, false) as ScrollContainer
	scene.set("_hand_scroll", hand_scroll)
	scene.call("_setup_hand_drag_scroll")
	_prepare_overflowing_hand_scroll_for_drag_test(hand_scroll)
	hand_scroll.scroll_horizontal = 300
	var start_scroll := hand_scroll.scroll_horizontal

	var stale_scroll := ScrollContainer.new()
	var stale_row := HBoxContainer.new()
	scene.add_child(stale_scroll)
	stale_scroll.add_child(stale_row)
	scene.call("_configure_card_gallery_drag_scroll", stale_scroll, stale_row, "stale_dialog")
	scene.call("_set_card_gallery_drag_scroll_active", stale_scroll, true)
	var stale_press := InputEventMouseButton.new()
	stale_press.button_index = MOUSE_BUTTON_LEFT
	stale_press.pressed = true
	stale_press.global_position = Vector2(220, 24)
	scene.call("_handle_card_gallery_drag_scroll_input", stale_press, stale_scroll, "stale_dialog")
	var stale_active_before_hand_press: bool = bool(scene.get("_card_gallery_drag_active"))

	var hand_press := InputEventMouseButton.new()
	hand_press.button_index = MOUSE_BUTTON_LEFT
	hand_press.pressed = true
	hand_press.global_position = Vector2(200, 24)
	scene.call("_handle_hand_drag_scroll_input", hand_press, "hand_card_gui")
	var stale_active_after_hand_press: bool = bool(scene.get("_card_gallery_drag_active"))

	var drag_left := InputEventMouseMotion.new()
	drag_left.global_position = Vector2(120, 24)
	scene.call("_input", drag_left)
	var scroll_after_drag := hand_scroll.scroll_horizontal

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.global_position = Vector2(120, 24)
	scene.call("_input", release)

	var result := run_checks([
		assert_true(stale_active_before_hand_press, "The test must start with a stale dialog card-gallery drag capture"),
		assert_false(stale_active_after_hand_press, "Starting a hand drag should clear stale dialog card-gallery capture"),
		assert_true(scroll_after_drag > start_scroll, "Hand drag should scroll even after a previous card-search dialog missed its release event"),
		assert_false(bool(scene.get("_hand_drag_active")), "Hand drag should still end normally on release"),
	])
	scene.free()
	return result


func test_global_input_clears_hidden_stale_card_gallery_capture_before_hand_drag() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	var hand_scroll := scene.find_child("HandScroll", true, false) as ScrollContainer
	scene.set("_hand_scroll", hand_scroll)
	scene.call("_setup_hand_drag_scroll")
	_prepare_overflowing_hand_scroll_for_drag_test(hand_scroll)
	hand_scroll.scroll_horizontal = 300
	var start_scroll := hand_scroll.scroll_horizontal

	var stale_scroll := ScrollContainer.new()
	var stale_row := HBoxContainer.new()
	scene.add_child(stale_scroll)
	stale_scroll.add_child(stale_row)
	scene.call("_configure_card_gallery_drag_scroll", stale_scroll, stale_row, "hidden_stale_dialog")
	scene.call("_set_card_gallery_drag_scroll_active", stale_scroll, true)
	var stale_press := InputEventMouseButton.new()
	stale_press.button_index = MOUSE_BUTTON_LEFT
	stale_press.pressed = true
	stale_press.global_position = Vector2(220, 24)
	scene.call("_handle_card_gallery_drag_scroll_input", stale_press, stale_scroll, "hidden_stale_dialog")
	stale_scroll.visible = false
	var stale_active_before_hand_press: bool = bool(scene.get("_card_gallery_drag_active"))

	var hand_press := InputEventMouseButton.new()
	hand_press.button_index = MOUSE_BUTTON_LEFT
	hand_press.pressed = true
	hand_press.global_position = Vector2(200, 24)
	scene.call("_input", hand_press)
	var stale_active_after_global_input: bool = bool(scene.get("_card_gallery_drag_active"))
	if not stale_active_after_global_input:
		scene.call("_handle_hand_drag_scroll_input", hand_press, "hand_card_gui")
	var hand_active_after_press: bool = bool(scene.get("_hand_drag_active"))

	var drag_left := InputEventMouseMotion.new()
	drag_left.global_position = Vector2(120, 24)
	scene.call("_input", drag_left)
	var scroll_after_drag := hand_scroll.scroll_horizontal

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.global_position = Vector2(120, 24)
	scene.call("_input", release)

	var result := run_checks([
		assert_true(stale_active_before_hand_press, "The test must start with a hidden stale dialog card-gallery drag capture"),
		assert_false(stale_active_after_global_input, "Global battle input should drop hidden stale card-gallery capture instead of consuming the next hand press"),
		assert_true(hand_active_after_press, "Hand card GUI input should be able to start dragging after global input clears stale gallery capture"),
		assert_true(scroll_after_drag > start_scroll, "Hand drag should scroll after a hidden card-search dialog missed its release event"),
		assert_false(bool(scene.get("_hand_drag_active")), "Hand drag should still end normally on release"),
	])
	scene.free()
	return result


func test_card_gallery_drag_scroll_suppresses_card_click() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	var scroll := ScrollContainer.new()
	var row := HBoxContainer.new()
	scene.add_child(scroll)
	scroll.add_child(row)
	scene.call("_configure_card_gallery_drag_scroll", scroll, row, "test_gallery")
	scene.call("_set_card_gallery_drag_scroll_active", scroll, true)
	var hbar := scroll.get_h_scroll_bar()
	var scrollbar_hidden := hbar != null and bool(hbar.get_meta("card_gallery_hidden_scrollbar", false)) and not hbar.visible
	_prepare_overflowing_hand_scroll_for_drag_test(scroll)
	scroll.scroll_horizontal = 300
	var start_scroll := scroll.scroll_horizontal

	var clicked := {"count": 0}
	var card_view := BattleCardViewScript.new()
	card_view.setup_from_instance(CardInstance.create(_make_pokemon_cd("Gallery Card", 60, "C"), 0), BattleCardViewScript.MODE_PREVIEW)
	card_view.set_clickable(true)
	scene.call("_configure_card_gallery_card_view", card_view, scroll, "test_gallery")
	card_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		clicked["count"] += 1
	)
	row.add_child(card_view)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(220, 24)
	press.global_position = Vector2(220, 24)
	card_view.call("_gui_input", press)

	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(80, 24)
	drag.global_position = Vector2(80, 24)
	card_view.call("_gui_input", drag)
	var scroll_after_drag := scroll.scroll_horizontal

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(80, 24)
	release.global_position = Vector2(80, 24)
	card_view.call("_gui_input", release)

	var result := run_checks([
		assert_true(scrollbar_hidden, "Card-gallery scrolls should hide the visible horizontal scrollbar when drag scrolling is active"),
		assert_true(scroll_after_drag > start_scroll, "Dragging a card-gallery card left should scroll toward later cards"),
		assert_eq(clicked["count"], 0, "Dragging a card-gallery card should not trigger card selection/detail"),
		assert_true(bool(scene.call("_is_card_gallery_drag_click_suppressed")), "Gallery drag release should suppress follow-up card clicks briefly"),
	])
	scene.free()
	return result


func test_card_gallery_click_without_drag_still_clicks_card() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	var scroll := ScrollContainer.new()
	var row := HBoxContainer.new()
	scene.add_child(scroll)
	scroll.add_child(row)
	scene.call("_configure_card_gallery_drag_scroll", scroll, row, "test_gallery")
	scene.call("_set_card_gallery_drag_scroll_active", scroll, true)
	_prepare_overflowing_hand_scroll_for_drag_test(scroll)

	var clicked := {"count": 0}
	var card_view := BattleCardViewScript.new()
	card_view.setup_from_instance(CardInstance.create(_make_pokemon_cd("Gallery Card", 60, "C"), 0), BattleCardViewScript.MODE_PREVIEW)
	card_view.set_clickable(true)
	scene.call("_configure_card_gallery_card_view", card_view, scroll, "test_gallery")
	card_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		clicked["count"] += 1
	)
	row.add_child(card_view)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(220, 24)
	press.global_position = Vector2(220, 24)
	card_view.call("_gui_input", press)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(220, 24)
	release.global_position = Vector2(220, 24)
	card_view.call("_gui_input", release)

	var result := run_checks([
		assert_eq(clicked["count"], 1, "A card-gallery tap without drag should keep the original card click behavior"),
		assert_false(bool(scene.call("_is_card_gallery_drag_click_suppressed")), "A plain card-gallery tap should not suppress clicks"),
	])
	scene.free()
	return result


func test_card_gallery_touch_horizontal_drag_still_scrolls_and_suppresses_card_click() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	var scroll := ScrollContainer.new()
	var row := HBoxContainer.new()
	scene.add_child(scroll)
	scroll.add_child(row)
	scene.call("_configure_card_gallery_drag_scroll", scroll, row, "test_gallery")
	scene.call("_set_card_gallery_drag_scroll_active", scroll, true)
	_prepare_overflowing_hand_scroll_for_drag_test(scroll)
	scroll.scroll_horizontal = 300
	var start_scroll := scroll.scroll_horizontal

	var clicked := {"count": 0}
	var card_view := BattleCardViewScript.new()
	card_view.setup_from_instance(CardInstance.create(_make_pokemon_cd("Gallery Card", 60, "C"), 0), BattleCardViewScript.MODE_PREVIEW)
	card_view.set_clickable(true)
	scene.call("_configure_card_gallery_card_view", card_view, scroll, "test_gallery")
	card_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		clicked["count"] += 1
	)
	row.add_child(card_view)

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = Vector2(220, 24)
	card_view.call("_gui_input", press)

	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(120, 24)
	card_view.call("_gui_input", drag)
	var scroll_after_drag := scroll.scroll_horizontal

	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = Vector2(120, 24)
	card_view.call("_gui_input", release)

	var result := run_checks([
		assert_true(scroll_after_drag > start_scroll, "A real touch drag on card-gallery cards should still scroll horizontally"),
		assert_eq(clicked["count"], 0, "A real touch drag on card-gallery cards should not choose the card"),
		assert_true(bool(scene.call("_is_card_gallery_drag_click_suppressed")), "A real touch drag release should still suppress follow-up card clicks briefly"),
	])
	scene.free()
	return result


func test_card_gallery_touch_release_moved_by_scroll_container_does_not_click_card() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	var scroll := ScrollContainer.new()
	var row := HBoxContainer.new()
	scene.add_child(scroll)
	scroll.add_child(row)
	scene.call("_configure_card_gallery_drag_scroll", scroll, row, "test_gallery")
	scene.call("_set_card_gallery_drag_scroll_active", scroll, true)
	_prepare_overflowing_hand_scroll_for_drag_test(scroll)
	scroll.scroll_horizontal = 300
	var start_scroll := scroll.scroll_horizontal

	var clicked := {"count": 0}
	var card_view := BattleCardViewScript.new()
	card_view.setup_from_instance(CardInstance.create(_make_pokemon_cd("Gallery Card", 60, "C"), 0), BattleCardViewScript.MODE_PREVIEW)
	card_view.set_clickable(true)
	scene.call("_configure_card_gallery_card_view", card_view, scroll, "test_gallery")
	card_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		clicked["count"] += 1
	)
	row.add_child(card_view)

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = Vector2(220, 24)
	card_view.call("_gui_input", press)

	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(320, 24)
	drag.relative = Vector2(100, 0)
	scene.call("_on_card_gallery_scroll_input", drag, scroll, "test_gallery")
	var scroll_after_drag := scroll.scroll_horizontal

	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = Vector2(320, 24)
	card_view.call("_gui_input", release)

	var result := run_checks([
		assert_true(scroll_after_drag < start_scroll, "A rightward scroll-container drag should move toward earlier cards when not at the edge"),
		assert_eq(clicked["count"], 0, "A card release far from its press point should not click even if the card missed the intermediate drag event"),
		assert_true(bool(scene.call("_is_card_gallery_drag_click_suppressed")), "The scroll-container drag release should still suppress follow-up card clicks briefly"),
	])
	scene.free()
	return result


func test_card_gallery_vertical_touch_jitter_still_clicks_card() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	var scroll := ScrollContainer.new()
	var row := HBoxContainer.new()
	scene.add_child(scroll)
	scroll.add_child(row)
	scene.call("_configure_card_gallery_drag_scroll", scroll, row, "test_gallery")
	scene.call("_set_card_gallery_drag_scroll_active", scroll, true)
	_prepare_overflowing_hand_scroll_for_drag_test(scroll)
	scroll.scroll_horizontal = 120
	var start_scroll := scroll.scroll_horizontal

	var clicked := {"count": 0}
	var card_view := BattleCardViewScript.new()
	card_view.setup_from_instance(CardInstance.create(_make_pokemon_cd("Gallery Card", 60, "C"), 0), BattleCardViewScript.MODE_PREVIEW)
	card_view.set_clickable(true)
	scene.call("_configure_card_gallery_card_view", card_view, scroll, "test_gallery")
	card_view.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		clicked["count"] += 1
	)
	row.add_child(card_view)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(220, 24)
	press.global_position = Vector2(220, 24)
	card_view.call("_gui_input", press)

	var jitter := InputEventMouseMotion.new()
	jitter.position = Vector2(224, 48)
	jitter.global_position = Vector2(224, 48)
	card_view.call("_gui_input", jitter)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(224, 48)
	release.global_position = Vector2(224, 48)
	card_view.call("_gui_input", release)

	var result := run_checks([
		assert_eq(clicked["count"], 1, "Vertical touch jitter in a horizontal card gallery should still count as a card tap"),
		assert_eq(scroll.scroll_horizontal, start_scroll, "Vertical jitter should not move the horizontal card gallery"),
		assert_false(bool(scene.call("_is_card_gallery_drag_click_suppressed")), "Vertical jitter should not leave gallery drag click suppression active"),
	])
	scene.free()
	return result


func test_card_gallery_inactive_scroll_does_not_capture_action_hud_drag() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	var scroll := ScrollContainer.new()
	var row := HBoxContainer.new()
	scene.add_child(scroll)
	scroll.add_child(row)
	scene.call("_configure_card_gallery_drag_scroll", scroll, row, "test_gallery")
	scene.call("_set_card_gallery_drag_scroll_active", scroll, false)
	_prepare_overflowing_hand_scroll_for_drag_test(scroll)
	scroll.scroll_horizontal = 300

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = Vector2(220, 24)
	var press_consumed := bool(scene.call("_handle_card_gallery_drag_scroll_input", press, scroll, "test_gallery"))

	var drag := InputEventMouseMotion.new()
	drag.global_position = Vector2(80, 24)
	var drag_consumed := bool(scene.call("_handle_card_gallery_drag_scroll_input", drag, scroll, "test_gallery"))

	var result := run_checks([
		assert_false(press_consumed, "Inactive card-gallery scrolls should not capture action HUD presses"),
		assert_false(drag_consumed, "Inactive card-gallery scrolls should not capture action HUD drags"),
		assert_eq(scroll.scroll_horizontal, 300, "Inactive card-gallery scrolls should not move"),
	])
	scene.free()
	return result


func test_discard_collection_viewer_uses_shared_card_gallery_drag_scroll() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	scene.set("_view_player", 0)
	scene.call("_setup_discard_gallery")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		gsm.game_state.players.append(player)
	for i: int in range(8):
		gsm.game_state.players[0].discard_pile.append(CardInstance.create(_make_pokemon_cd("Gallery Discard %d" % i, 70, "C"), 0))
	scene.set("_gsm", gsm)

	scene.call("_show_discard_pile", 0, "Discard")
	var scroll := scene.get("_discard_card_scroll") as ScrollContainer
	var row := scene.get("_discard_card_row") as HBoxContainer
	var first_card := row.get_child(0) as BattleCardView if row != null and row.get_child_count() > 0 else null
	var drag_enabled := scroll != null and bool(scroll.get_meta("card_gallery_drag_scroll_enabled", false))
	var drag_active := scroll != null and bool(scroll.get_meta("card_gallery_drag_scroll_active", false))
	var card_input_enabled := first_card != null and bool(first_card.get_meta("card_gallery_drag_input_enabled", false))
	var start_scroll := scroll.scroll_horizontal

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(220, 24)
	press.global_position = Vector2(220, 24)
	first_card.call("_gui_input", press)

	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(60, 24)
	drag.global_position = Vector2(60, 24)
	first_card.call("_gui_input", drag)
	var scroll_after_drag := scroll.scroll_horizontal

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(60, 24)
	release.global_position = Vector2(60, 24)
	first_card.call("_gui_input", release)

	var result := run_checks([
		assert_true(drag_enabled, "Discard collection scroll should opt into shared card-gallery drag scrolling"),
		assert_true(drag_active, "Discard collection scroll should be active while the viewer is open"),
		assert_true(card_input_enabled, "Discard collection card views should forward pointer input to shared drag scrolling"),
		assert_true(scroll_after_drag > start_scroll, "Dragging a discard collection card should scroll the collection row"),
		assert_true(bool(scene.call("_is_card_gallery_drag_click_suppressed")), "Dragging a discard collection card should suppress card detail clicks briefly"),
	])
	scene.queue_free()
	return result


func test_landscape_open_opponent_discard_viewer_refreshes_drag_after_opponent_hand_discard_lands() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI

	var scene: Control = BattleScenePacked.instantiate()
	scene.set("_view_player", 0)
	scene.set("_active_battle_layout_mode", "landscape")
	scene.call("_setup_discard_gallery")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 4
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		gsm.game_state.players.append(player)
	var opponent: PlayerState = gsm.game_state.players[1]
	opponent.discard_pile.append(CardInstance.create(_make_pokemon_cd("Opponent Old Discard", 70, "C"), 1))
	scene.set("_gsm", gsm)

	scene.call("_show_discard_pile", 1, "Opponent Discard")
	var scroll := scene.get("_discard_card_scroll") as ScrollContainer
	var row := scene.get("_discard_card_row") as HBoxContainer
	var count_before_action := row.get_child_count() if row != null else 0

	var landed_cards: Array[CardInstance] = []
	for i: int in range(9):
		var landed := CardInstance.create(_make_trainer_cd("Opponent Ultra Ball New Discard %d" % i, "Item", ""), 1)
		opponent.discard_pile.append(landed)
		landed_cards.append(landed)
	var landed_ids: Array[int] = []
	var landed_names: Array[String] = []
	for landed: CardInstance in landed_cards:
		landed_ids.append(landed.instance_id)
		landed_names.append(landed.card_data.name)
	var action := GameAction.create(
		GameAction.ActionType.DISCARD,
		1,
		{
			"count": landed_cards.size(),
			"source_zone": "hand",
			"source_kind": "trainer",
			"source_card_name": "Ultra Ball",
			"card_names": landed_names,
			"card_instance_ids": landed_ids,
		},
		4,
		"opponent discarded cards for Ultra Ball"
	)
	scene.call("_on_action_logged", action)
	var controller: RefCounted = scene.get("_battle_draw_reveal_controller")
	var reveal_views: Array = scene.get("_draw_reveal_card_views")
	for index: int in reveal_views.size():
		controller.call("_mark_discard_card_landed", scene, reveal_views[index], 1, index + 1)

	var count_after_landing := row.get_child_count() if row != null else 0
	var first_card := row.get_child(0) as BattleCardView if row != null and row.get_child_count() > 0 else null
	var card_input_enabled := first_card != null and bool(first_card.get_meta("card_gallery_drag_input_enabled", false))
	if scroll != null:
		scroll.size = Vector2(400, scroll.custom_minimum_size.y)
	var start_scroll := scroll.scroll_horizontal if scroll != null else 0

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(220, 24)
	press.global_position = Vector2(220, 24)
	first_card.call("_gui_input", press)

	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(60, 24)
	drag.global_position = Vector2(60, 24)
	first_card.call("_gui_input", drag)
	var scroll_after_drag := scroll.scroll_horizontal if scroll != null else start_scroll

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(60, 24)
	release.global_position = Vector2(60, 24)
	first_card.call("_gui_input", release)

	scene.call("_show_discard_pile", 1, "Opponent Discard")
	var count_after_reopen := row.get_child_count() if row != null else 0

	GameManager.current_mode = previous_mode
	var result := run_checks([
		assert_eq(count_before_action, 1, "Precondition: the open opponent discard viewer starts with the old discard pile"),
		assert_true(card_input_enabled, "Refreshed opponent discard cards should still forward pointer input to shared drag scrolling"),
		assert_true(scroll_after_drag > start_scroll, "Dragging the refreshed opponent discard cards should scroll instead of falling through to detail clicks"),
		assert_eq(count_after_landing, 10, "Open opponent discard viewer should refresh when an opponent hand-discard action lands new cards"),
		assert_eq(count_after_reopen, 10, "Closing and reopening currently rebuilds the full opponent discard pile"),
	])
	scene.queue_free()
	return result


func test_discard_viewer_raises_above_stadium_overlay_for_input() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	scene.set("_view_player", 0)
	scene.call("_setup_discard_gallery")
	var stadium_overlay := scene.call("_ensure_stadium_card_overlay") as Control
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		gsm.game_state.players.append(player)
	gsm.game_state.players[0].discard_pile.append(CardInstance.create(_make_pokemon_cd("Layered Discard", 70, "C"), 0))
	scene.set("_gsm", gsm)

	scene.call("_show_discard_pile", 0, "Discard")
	var discard_overlay := scene.get("_discard_overlay") as Control

	var result := run_checks([
		assert_true(discard_overlay != null and discard_overlay.visible, "Discard viewer should be visible after opening"),
		assert_gte(discard_overlay.z_index if discard_overlay != null else -1, 300, "Discard viewer should be promoted to the active modal input layer"),
		assert_eq(discard_overlay.mouse_filter if discard_overlay != null else -1, Control.MOUSE_FILTER_STOP, "Discard viewer overlay should stop pointer events"),
		assert_true(
			discard_overlay != null
			and stadium_overlay != null
			and discard_overlay.get_parent() == stadium_overlay.get_parent()
			and discard_overlay.get_index() > stadium_overlay.get_index(),
			"Discard viewer should be moved above the Stadium card overlay in root sibling order"
		),
	])
	scene.queue_free()
	return result


func test_discard_viewer_blocks_underlying_stadium_card_action() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	scene.set("_view_player", 0)
	scene.set("_dialog_overlay", scene.find_child("DialogOverlay", true, false))
	scene.set("_dialog_title", scene.find_child("DialogTitle", true, false))
	scene.set("_dialog_list", scene.find_child("DialogList", true, false))
	scene.set("_dialog_confirm", scene.find_child("DialogConfirm", true, false))
	scene.set("_dialog_cancel", scene.find_child("DialogCancel", true, false))
	scene.set("_dialog_box", scene.find_child("DialogBox", true, false))
	scene.set("_dialog_vbox", scene.find_child("DialogVBox", true, false))
	scene.call("_setup_dialog_gallery")
	scene.call("_setup_discard_gallery")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		gsm.game_state.players.append(player)
	var stadium_cd := _make_trainer_cd("Blocked Stadium", "Stadium", "")
	stadium_cd.effect_id = "missing_test_stadium_effect"
	var stadium := CardInstance.create(stadium_cd, 0)
	gsm.game_state.stadium_card = stadium
	gsm.game_state.stadium_owner_index = 0
	gsm.game_state.players[0].discard_pile.append(CardInstance.create(_make_pokemon_cd("Modal Discard", 70, "C"), 0))
	scene.set("_gsm", gsm)

	scene.call("_show_discard_pile", 0, "Discard")
	scene.set("_pending_choice", "")
	var dialog_overlay := scene.get("_dialog_overlay") as Control
	if dialog_overlay != null:
		dialog_overlay.visible = false
	scene.call("_on_stadium_card_left_clicked", stadium, stadium_cd)

	var result := run_checks([
		assert_eq(str(scene.get("_pending_choice")), "", "Stadium card clicks below the discard viewer should not open a Stadium action dialog"),
		assert_false(dialog_overlay != null and dialog_overlay.visible, "Discard viewer should block click-through into DialogOverlay"),
	])
	scene.queue_free()
	return result


func test_coin_flipper_emits_signal() -> String:
	var flipper := CoinFlipper.new()
	var received_results: Array[bool] = []
	flipper.coin_flipped.connect(func(r: bool) -> void: received_results.append(r))

	var result: bool = flipper.flip()
	return run_checks([
		assert_eq(received_results.size(), 1, "应收到1次信号"),
		assert_eq(received_results[0], result, "信号结果与返回值一致"),
	])


## 测试：CoinFlipper 多次投币信号全部发出
func test_coin_flipper_multiple_emits() -> String:
	var flipper := CoinFlipper.new()
	var emitted: Array[bool] = []
	flipper.coin_flipped.connect(func(_r: bool) -> void: emitted.append(true))

	var results: Array[bool] = flipper.flip_multiple(5)
	return run_checks([
		assert_eq(results.size(), 5, "投5次返回5个结果"),
		assert_eq(emitted.size(), 5, "信号发出5次"),
	])


## 测试：投币直到反面，信号计数正确
func test_coin_flipper_until_tails_emits() -> String:
	var flipper := CoinFlipper.new()
	var emitted: Array[bool] = []
	flipper.coin_flipped.connect(func(_r: bool) -> void: emitted.append(true))

	var heads: int = flipper.flip_until_tails()
	# 正面次数 + 最后一次反面 = 总投币次数
	return run_checks([
		assert_eq(emitted.size(), heads + 1, "信号次数 = 正面次数 + 1（反面）"),
	])


func test_coin_flip_animator_scales_coin_and_result_text_for_portrait() -> String:
	var animator: Control = CoinFlipAnimatorScript.new()
	animator.call("_ready")
	animator.call("apply_viewport_metrics", Vector2(900, 1600), true)
	var coin := animator.get("_coin_sprite") as TextureRect
	var label := animator.get("_result_label") as Label
	var vbox := animator.get("_coin_vbox") as VBoxContainer
	var portrait_coin_size := coin.custom_minimum_size if coin != null else Vector2.ZERO
	var portrait_font_size := label.get_theme_font_size("font_size") if label != null else 0
	var portrait_gap := vbox.get_theme_constant("separation") if vbox != null else 0

	animator.call("apply_viewport_metrics", Vector2(1600, 900), false)
	var landscape_coin_size := coin.custom_minimum_size if coin != null else Vector2.ZERO
	var landscape_font_size := label.get_theme_font_size("font_size") if label != null else 0
	animator.free()

	return run_checks([
		assert_gte(roundi(portrait_coin_size.x), 300, "Portrait coin should scale with the tall battle canvas instead of staying at the desktop size"),
		assert_gte(portrait_font_size, 44, "Portrait coin result text should be readable at battle phone scale"),
		assert_gte(portrait_gap, 20, "Portrait coin result should keep proportional spacing under the coin"),
		assert_eq(roundi(landscape_coin_size.x), 180, "Landscape coin should keep the existing compact size"),
		assert_eq(landscape_font_size, 24, "Landscape coin result text should keep the existing compact font"),
	])


func test_coin_flip_animator_coin_skin_registry_is_complete() -> String:
	var animator: Control = CoinFlipAnimatorScript.new()
	var skin_count := int(animator.call("get_coin_skin_count_for_tests"))
	var checks: Array[String] = [
		assert_gte(skin_count, 4, "Coin skin registry should include default plus generated variants"),
	]
	for index: int in skin_count:
		var skin: Dictionary = animator.call("get_coin_skin_textures_for_tests", index)
		var heads: Variant = skin.get("heads", null)
		var tails: Variant = skin.get("tails", null)
		checks.append(assert_true(heads is Texture2D, "Coin skin %d should have a heads texture" % index))
		checks.append(assert_true(tails is Texture2D, "Coin skin %d should have a tails texture" % index))
		if heads is Texture2D:
			var heads_size := (heads as Texture2D).get_size()
			checks.append(assert_true(heads_size.x > 0.0 and heads_size.y > 0.0, "Coin skin heads texture should have valid dimensions"))
		if tails is Texture2D:
			var tails_size := (tails as Texture2D).get_size()
			checks.append(assert_true(tails_size.x > 0.0 and tails_size.y > 0.0, "Coin skin tails texture should have valid dimensions"))
	animator.free()
	return run_checks(checks)


func test_coin_flip_animator_uses_stable_selected_coin_skin() -> String:
	var animator: Control = CoinFlipAnimatorScript.new()
	animator.call("set_coin_skin_index_for_tests", 1)
	animator.call("_ready")
	var first_skin: Dictionary = animator.call("get_coin_skin_textures_for_tests", 1)
	var coin := animator.get("_coin_sprite") as TextureRect
	var first_texture := coin.texture if coin != null else null
	var first_index := int(animator.call("get_coin_skin_index_for_tests"))

	animator.call("_select_coin_skin_once")
	var second_index := int(animator.call("get_coin_skin_index_for_tests"))
	var second_texture := coin.texture if coin != null else null

	animator.call("set_coin_skin_index_for_tests", 2)
	var changed_skin: Dictionary = animator.call("get_coin_skin_textures_for_tests", 2)
	var changed_texture := coin.texture if coin != null else null
	var changed_index := int(animator.call("get_coin_skin_index_for_tests"))
	animator.free()

	return run_checks([
		assert_eq(first_index, 1, "A preselected coin skin index should be honored during ready"),
		assert_eq(first_texture, first_skin.get("heads", null), "Coin sprite should show the selected skin heads texture"),
		assert_eq(second_index, first_index, "Selecting once again should keep the existing skin stable"),
		assert_eq(second_texture, first_texture, "Stable skin selection should not replace the visible texture"),
		assert_eq(changed_index, 2, "Test hook should allow changing the coin skin explicitly"),
		assert_eq(changed_texture, changed_skin.get("heads", null), "Changing skin should update the visible heads texture"),
		assert_true(changed_texture != first_texture, "Different generated coin skins should use different textures"),
	])


func test_battle_scene_coin_animation_raises_above_modal_overlays() -> String:
	var battle_scene = _make_battle_scene_stub()
	var dialog_overlay := battle_scene.get("_dialog_overlay") as Panel
	var detail_overlay := battle_scene.get("_detail_overlay") as Panel
	var coin_animator := FakeLayeredCoinAnimator.new()
	dialog_overlay.z_index = 300
	detail_overlay.z_index = 500
	coin_animator.z_index = 1
	battle_scene.add_child(dialog_overlay)
	battle_scene.add_child(detail_overlay)
	battle_scene.add_child(coin_animator)
	battle_scene.set("_coin_animator", coin_animator)
	var queue: Array[bool] = [true]
	battle_scene.set("_coin_flip_queue", queue)

	battle_scene.call("_play_next_coin_animation")

	var result := run_checks([
		assert_eq(coin_animator.played_results, [true], "Coin animation should still play the queued result"),
		assert_gt(coin_animator.z_index, detail_overlay.z_index, "Coin animation should render above the highest modal overlay"),
		assert_eq(coin_animator.get_index(), battle_scene.get_child_count() - 1, "Coin animation should be the last child so equal-z overlays cannot cover it"),
	])
	battle_scene.free()
	return result


func test_battle_scene_three_coin_animation_queue_advances_outside_tween_callback() -> String:
	var battle_scene = _make_battle_scene_stub()
	var coin_animator := FakeLayeredCoinAnimator.new()
	battle_scene.add_child(coin_animator)
	battle_scene.set("_coin_animator", coin_animator)
	var queued_results: Array[bool] = [true, false, true]
	battle_scene.set("_coin_flip_queue", queued_results)

	battle_scene.call("_play_next_coin_animation")
	battle_scene.call("_on_coin_animation_finished")
	var count_inside_finish_callback := coin_animator.played_results.size()
	await Engine.get_main_loop().process_frame
	var count_after_first_idle := coin_animator.played_results.size()
	battle_scene.call("_on_coin_animation_finished")
	await Engine.get_main_loop().process_frame
	var count_after_second_idle := coin_animator.played_results.size()
	battle_scene.call("_on_coin_animation_finished")
	await Engine.get_main_loop().process_frame

	var result := run_checks([
		assert_eq(count_inside_finish_callback, 1, "A completed toss must not start the next Tween re-entrantly from the old Tween callback"),
		assert_eq(count_after_first_idle, 2, "The second Hoothoot toss should start on the next idle turn"),
		assert_eq(count_after_second_idle, 3, "The third Hoothoot toss should also remain queued and visible"),
		assert_eq(coin_animator.played_results, [true, false, true], "Three queued coin results must be animated once each and in order"),
		assert_false(bool(battle_scene.get("_coin_animating")), "The coin animator should return to idle after all three tosses"),
		assert_eq((battle_scene.get("_coin_flip_queue") as Array).size(), 0, "The three-toss queue should be fully drained"),
	])
	battle_scene.free()
	return result


func test_battle_setup_scene_includes_first_player_option() -> String:
	var scene: Control = BattleSetupScene.instantiate()
	var first_player_label := scene.find_child("FirstPlayerLabel", true, false)
	var first_player_option := scene.find_child("FirstPlayerOption", true, false)

	return run_checks([
		assert_true(first_player_label is Label, "对战设置页应包含先后攻标签"),
		assert_true(first_player_option is OptionButton, "对战设置页应包含先后攻选项"),
	])


func test_battle_setup_first_player_choice_mapping() -> String:
	var setup := BattleSetupScript.new()

	return run_checks([
		assert_eq(setup._first_player_choice_from_option_index(0), -1, "第 0 项应映射为随机先后攻"),
		assert_eq(setup._first_player_choice_from_option_index(1), 0, "第 1 项应映射为玩家1先攻"),
		assert_eq(setup._first_player_choice_from_option_index(2), 1, "第 2 项应映射为玩家2先攻"),
		assert_eq(setup._first_player_option_index_from_choice(-1), 0, "随机先后攻应回填到第 0 项"),
		assert_eq(setup._first_player_option_index_from_choice(0), 1, "玩家1先攻应回填到第 1 项"),
		assert_eq(setup._first_player_option_index_from_choice(1), 2, "玩家2先攻应回填到第 2 项"),
	])


func test_battle_setup_scene_includes_background_gallery() -> String:
	var scene: Control = BattleSetupScene.instantiate()
	var background_label := scene.find_child("BackgroundLabel", true, false)
	var background_gallery := scene.find_child("BackgroundGallery", true, false)
	var background_gallery_row := scene.find_child("BackgroundGalleryRow", true, false)

	return run_checks([
		assert_true(background_label is Label, "对战设置页应包含场地选择标签"),
		assert_true(background_gallery is ScrollContainer, "对战设置页应包含横向场地滚动区"),
		assert_true(background_gallery_row is HBoxContainer, "对战设置页应包含场地缩略图行"),
	])


func test_battle_setup_replaces_dynamic_stadium_toggle_with_battle_effects_toggle() -> String:
	var scene: Control = BattleSetupScene.instantiate()
	var effects_label := scene.find_child("BattleEffectsLabel", true, false) as Label
	var effects_segment := scene.find_child("BattleEffectsSegment", true, false)
	var on_button := scene.find_child("BattleEffectsOnButton", true, false)
	var off_button := scene.find_child("BattleEffectsOffButton", true, false)

	return run_checks([
		assert_true(effects_label != null and effects_label.text == "对战动画特效", "Battle setup should use the existing setting slot for battle effects"),
		assert_true(effects_segment is HBoxContainer, "Battle setup should keep the existing two-button segment layout"),
		assert_true(on_button is Button, "Battle setup should include a battle effects on button"),
		assert_true(off_button is Button, "Battle setup should include a battle effects off button"),
		assert_null(scene.find_child("DynamicStadiumBackgroundSegment", true, false), "Dynamic Stadium backgrounds should no longer require a user setting"),
	])


func test_battle_setup_lists_background_assets() -> String:
	var setup := BattleSetupScript.new()
	var backgrounds: Array[String] = setup._list_available_background_paths()

	return run_checks([
		assert_contains(backgrounds, "res://assets/ui/background.png", "应包含默认背景图"),
		assert_contains(backgrounds, "res://assets/ui/background1.png", "应包含新导入的 background1"),
		assert_eq(backgrounds[0], "res://assets/ui/background.png", "未主动选择时默认背景应为 background.png"),
	])


func test_battle_scene_includes_zeus_help_button() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	var zeus_button := scene.find_child("BtnZeusHelp", true, false)
	var foil_button := scene.find_child("BtnCardFoil", true, false)
	var back_button := scene.find_child("BtnBack", true, false)

	return run_checks([
		assert_true(zeus_button is Button, "BattleScene 顶栏应包含宙斯帮我按钮"),
		assert_null(foil_button, "BattleScene should not expose a card foil toggle button"),
		assert_true(back_button is Button, "BattleScene 顶栏应保留退出游戏按钮"),
	])


func test_battle_card_view_card_foil_material_uses_soft_shine_and_can_disable() -> String:
	var card_view := BattleCardViewScript.new()
	card_view.setup_from_instance(null, BattleCardViewScript.MODE_PREVIEW)
	var texture_rect := card_view.get("_texture_rect") as TextureRect
	var image := Image.create(8, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.35, 0.42, 0.88, 1.0))
	if texture_rect != null:
		texture_rect.texture = ImageTexture.create_from_image(image)

	var enabled_after_setup := bool(card_view.call("get_card_foil_effect_enabled"))
	card_view.set_card_foil_effect_enabled(true)
	var material_after_enable := texture_rect.material if texture_rect != null else null
	var mode_after_enable := str(card_view.call("get_card_foil_effect_mode"))
	var intensity_after_enable := 0.0
	var shader_code_after_enable := ""
	if material_after_enable is ShaderMaterial:
		var shader_material := material_after_enable as ShaderMaterial
		intensity_after_enable = float(shader_material.get_shader_parameter("foil_intensity"))
		shader_code_after_enable = shader_material.shader.code if shader_material.shader != null else ""
	card_view.set_card_foil_effect_enabled(false, 0.0)
	var material_after_off := texture_rect.material if texture_rect != null else null
	var mode_after_off := str(card_view.call("get_card_foil_effect_mode"))

	return run_checks([
		assert_false(enabled_after_setup, "BattleCardView should wait for the battle scene to enable shine foil by owner"),
		assert_eq(mode_after_enable, "shine", "BattleCardView should expose only the shine foil mode when enabled"),
		assert_true(material_after_enable is ShaderMaterial, "BattleCardView should apply a shader material for enabled shine foil"),
		assert_true(is_equal_approx(intensity_after_enable, 1.2), "BattleCardView should use the requested clearly visible shine foil intensity"),
		assert_true(shader_code_after_enable.contains("smoothstep(0.40") and shader_code_after_enable.contains("sweep * 0.20") and shader_code_after_enable.contains("core * 0.08"), "BattleCardView shine foil should use a broad, visible soft sweep instead of a barely visible highlight"),
		assert_false(shader_code_after_enable.contains("texture(TEXTURE, UV) * vertex_color"), "BattleCardView shine foil should not multiply the card texture twice because that darkens every card"),
		assert_true(shader_code_after_enable.contains("vec4 base = COLOR"), "BattleCardView shine foil should use Godot's already-modulated card color as the unchanged base"),
		assert_false(shader_code_after_enable.contains("result = mix(result, foil_light"), "BattleCardView shine foil should not recolor the card art; it should only add light over the original image"),
		assert_true(shader_code_after_enable.contains("vec3 result = base.rgb + foil_light * highlight"), "BattleCardView shine foil should preserve the original card color and add only the light sweep"),
		assert_eq(mode_after_off, "off", "BattleCardView should store the disabled foil mode"),
		assert_null(material_after_off, "BattleCardView should remove the foil material when disabled"),
	])


func test_battle_card_view_disabled_cards_keep_dim_state_over_foil() -> String:
	var card_view := BattleCardViewScript.new()
	card_view.setup_from_instance(null, BattleCardViewScript.MODE_CHOICE)
	var texture_rect := card_view.get("_texture_rect") as TextureRect
	var image := Image.create(8, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.72, 0.18, 0.14, 1.0))
	if texture_rect != null:
		texture_rect.texture = ImageTexture.create_from_image(image)

	card_view.set_card_foil_effect_enabled(true)
	var material_before_disabled := texture_rect.material if texture_rect != null else null
	card_view.set_disabled(true)
	var material_while_disabled := texture_rect.material if texture_rect != null else null
	var texture_modulate_while_disabled := texture_rect.modulate if texture_rect != null else Color.WHITE
	card_view.set_disabled(false)
	var material_after_reenabled := texture_rect.material if texture_rect != null else null

	return run_checks([
		assert_true(material_before_disabled is ShaderMaterial, "Enabled current-player card should start with shine material"),
		assert_null(material_while_disabled, "Disabled choice cards should drop shine material so unavailable cards visibly dim"),
		assert_true(texture_modulate_while_disabled.r < 1.0 and texture_modulate_while_disabled.g < 1.0 and texture_modulate_while_disabled.b < 1.0, "Disabled choice cards should keep the dimmed card-art tint"),
		assert_true(material_after_reenabled is ShaderMaterial, "Re-enabled choice cards should restore shine material when the foil flag is still on"),
	])


func test_battle_card_view_empty_field_slots_use_soft_placeholder_effect() -> String:
	var empty_view := BattleCardViewScript.new()
	empty_view.setup_from_instance(null, BattleCardViewScript.MODE_SLOT_BENCH)
	var empty_effect := empty_view.get("_empty_slot_effect") as CanvasItem
	var art_frame := empty_view.get("_art_frame") as PanelContainer
	var art_style := art_frame.get_theme_stylebox("panel") as StyleBoxFlat if art_frame != null else null
	var empty_bg := art_style.bg_color if art_style != null else Color(0, 0, 0, 1)
	var effect_material := empty_effect.material if empty_effect != null else null
	var has_soft_empty_surface := empty_bg.a < 0.7 and maxf(empty_bg.r, maxf(empty_bg.g, empty_bg.b)) > 0.12

	var occupied_view := BattleCardViewScript.new()
	occupied_view.setup_from_instance(CardInstance.create(_make_pokemon_cd("Occupied Bench", 90, "C"), 0), BattleCardViewScript.MODE_SLOT_BENCH)
	var occupied_effect := occupied_view.get("_empty_slot_effect") as CanvasItem

	return run_checks([
		assert_true(has_soft_empty_surface, "Empty field slots should not render as black holes"),
		assert_true(empty_effect != null and empty_effect.visible, "Empty field slots should show a soft placeholder effect"),
		assert_true(effect_material is ShaderMaterial, "Empty field slot placeholder should use a lightweight shader effect"),
		assert_true(occupied_effect == null or not occupied_effect.visible, "Occupied field slots should hide the empty-slot placeholder effect"),
	])


func test_battle_scene_slot_card_detail_keeps_current_owner_foil() -> String:
	var battle_scene := _make_battle_scene_stub()
	var detail_overlay := battle_scene.get("_detail_overlay") as Panel
	var detail_card_view := BattleCardViewScript.new()
	if detail_overlay != null:
		detail_overlay.add_child(detail_card_view)
	battle_scene.set("_detail_card_view", detail_card_view)
	battle_scene.set("_detail_title", Label.new())
	battle_scene.set("_detail_content", RichTextLabel.new())
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var current_slot := PokemonSlot.new()
	current_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Detail Current Owner", 80, "C"), 0))
	gsm.game_state.players[0].active_pokemon = current_slot
	var waiting_slot := PokemonSlot.new()
	waiting_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Detail Waiting Owner", 80, "C"), 1))
	gsm.game_state.players[1].active_pokemon = waiting_slot

	var opened_current := bool(battle_scene.call("_show_slot_card_detail", "my_active"))
	var current_enabled := bool(detail_card_view.call("get_card_foil_effect_enabled"))
	battle_scene.call("_show_slot_card_detail", "opp_active")
	var waiting_enabled := bool(detail_card_view.call("get_card_foil_effect_enabled"))

	return run_checks([
		assert_true(opened_current, "Slot detail should open for the current player's Active Pokemon"),
		assert_true(current_enabled, "Slot detail should keep the concrete CardInstance owner and show foil for the current player"),
		assert_false(waiting_enabled, "Slot detail should turn foil off for the waiting player's Pokemon"),
	])


func test_battle_scene_slot_card_detail_shows_attached_tool_and_energy() -> String:
	var battle_scene := _make_battle_scene_stub()
	var detail_overlay := battle_scene.get("_detail_overlay") as Panel
	var detail_card_view := BattleCardViewScript.new()
	if detail_overlay != null:
		detail_overlay.add_child(detail_card_view)
	var detail_content := RichTextLabel.new()
	battle_scene.set("_detail_card_view", detail_card_view)
	battle_scene.set("_detail_title", Label.new())
	battle_scene.set("_detail_content", detail_content)
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Resource Detail Pokemon", 120, "R"), 0))
	active_slot.attached_tool = CardInstance.create(_make_trainer_cd("Bravery Charm", "Tool", ""), 0)
	active_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	active_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "C"), 0))
	active_slot.attached_energy.append(CardInstance.create(_make_energy_cd("Double Turbo Energy", "C"), 0))
	gsm.game_state.players[0].active_pokemon = active_slot

	var opened := bool(battle_scene.call("_show_slot_card_detail", "my_active"))
	var detail_text := detail_content.text

	return run_checks([
		assert_true(opened, "Slot detail should open for an occupied Active Pokemon"),
		assert_str_contains(detail_text, "Bravery Charm", "Slot detail should include the attached Tool name"),
		assert_str_contains(detail_text, "Fire Energy", "Slot detail should include attached Energy names"),
		assert_str_contains(detail_text, "Double Turbo Energy x2", "Slot detail should group duplicate attached Energy names"),
	])


func test_battle_scene_shine_foil_follows_current_player_for_common_card_modes() -> String:
	var battle_scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	battle_scene.set("_gsm", gsm)
	var modes := [
		BattleCardViewScript.MODE_HAND,
		BattleCardViewScript.MODE_PREVIEW,
		BattleCardViewScript.MODE_CHOICE,
		BattleCardViewScript.MODE_SLOT_ACTIVE,
		BattleCardViewScript.MODE_SLOT_BENCH,
	]
	var checks: Array[String] = []
	for mode_variant: Variant in modes:
		var active_card_view := BattleCardViewScript.new()
		active_card_view.setup_from_instance(CardInstance.create(_make_pokemon_cd("Active Owner", 60, "C"), 0), str(mode_variant))
		var waiting_card_view := BattleCardViewScript.new()
		waiting_card_view.setup_from_instance(CardInstance.create(_make_pokemon_cd("Waiting Owner", 60, "C"), 1), str(mode_variant))
		battle_scene.add_child(active_card_view)
		battle_scene.add_child(waiting_card_view)
		battle_scene.call("_sync_card_foil_effects")
		checks.append(assert_true(bool(active_card_view.call("get_card_foil_effect_enabled")), "Current player's card should shine for %s" % str(mode_variant)))
		checks.append(assert_false(bool(waiting_card_view.call("get_card_foil_effect_enabled")), "Waiting player's card should not shine for %s" % str(mode_variant)))
		gsm.game_state.current_player_index = 1
		battle_scene.call("_sync_card_foil_effects")
		checks.append(assert_false(bool(active_card_view.call("get_card_foil_effect_enabled")), "Previous current player's card should stop shining for %s" % str(mode_variant)))
		checks.append(assert_true(bool(waiting_card_view.call("get_card_foil_effect_enabled")), "New current player's card should shine for %s" % str(mode_variant)))
		active_card_view.queue_free()
		waiting_card_view.queue_free()
		gsm.game_state.current_player_index = 0
	var result := run_checks(checks)
	battle_scene.queue_free()
	return result


func test_battle_scene_dialog_card_foil_follows_current_player_owner() -> String:
	var battle_scene := _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	battle_scene.set("_gsm", gsm)
	var current_card_view := BattleCardViewScript.new()
	var waiting_card_view := BattleCardViewScript.new()
	var current_card := CardInstance.create(_make_pokemon_cd("Current Dialog Card", 60, "C"), 0)
	var waiting_card := CardInstance.create(_make_pokemon_cd("Waiting Dialog Card", 60, "C"), 1)

	battle_scene.call("_setup_dialog_card_view", current_card_view, current_card, "")
	battle_scene.call("_setup_dialog_card_view", waiting_card_view, waiting_card, "")
	var current_enabled_initial := bool(current_card_view.call("get_card_foil_effect_enabled"))
	var waiting_enabled_initial := bool(waiting_card_view.call("get_card_foil_effect_enabled"))
	gsm.game_state.current_player_index = 1
	battle_scene.call("_sync_card_foil_effect_for_view", current_card_view)
	battle_scene.call("_sync_card_foil_effect_for_view", waiting_card_view)
	var current_enabled_after_switch := bool(current_card_view.call("get_card_foil_effect_enabled"))
	var waiting_enabled_after_switch := bool(waiting_card_view.call("get_card_foil_effect_enabled"))

	return run_checks([
		assert_true(current_enabled_initial, "Dialog card owned by current player should shine"),
		assert_false(waiting_enabled_initial, "Dialog card owned by waiting player should not shine"),
		assert_false(current_enabled_after_switch, "Dialog card should stop shining after owner is no longer current"),
		assert_true(waiting_enabled_after_switch, "Dialog card should shine after its owner becomes current"),
	])


func test_battle_scene_has_no_card_foil_toggle_button() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	var foil_button := scene.find_child("BtnCardFoil", true, false) as Button

	var result := run_checks([
		assert_null(foil_button, "BattleScene should remove the card foil toggle button"),
		assert_false(scene.has_method("_on_card_foil_pressed"), "BattleScene should not keep the card foil toggle handler"),
	])
	scene.queue_free()
	return result


func test_battle_scene_vstar_lost_huds_use_image_vstar_and_compact_lost_style() -> String:
	var scene: Control = BattleSceneScript.new()
	var vstar_label := Label.new()
	var vstar_panel := PanelContainer.new()
	vstar_panel.name = "InfoMyVstar"
	vstar_panel.add_child(vstar_label)
	vstar_panel.custom_minimum_size = Vector2(100, 30)
	var lost_label := Label.new()
	var lost_panel := PanelContainer.new()
	lost_panel.name = "InfoMyLost"
	lost_panel.add_child(lost_label)
	lost_panel.custom_minimum_size = Vector2(100, 30)

	scene.call("_set_vstar_hud_value", vstar_label, false)
	var ready_visible := vstar_label.visible
	var ready_image := vstar_panel.find_child("HudImageTexture", true, false) as TextureRect
	var ready_modulate := ready_image.modulate if ready_image != null else Color.TRANSPARENT
	scene.call("_set_vstar_hud_value", vstar_label, true)
	var used_visible := vstar_label.visible
	var used_image := vstar_panel.find_child("HudImageTexture", true, false) as TextureRect
	var used_modulate := used_image.modulate if used_image != null else Color.TRANSPARENT
	scene.call("_set_lost_zone_hud_value", lost_label, 7)
	var lost_text := lost_label.text
	scene.call("_apply_vstar_lost_hud_metrics", vstar_panel)
	var first_scaled_size := vstar_panel.custom_minimum_size
	scene.call("_apply_vstar_lost_hud_metrics", vstar_panel)
	var second_scaled_size := vstar_panel.custom_minimum_size
	var texture_size := ready_image.texture.get_size() if ready_image != null and ready_image.texture != null else Vector2.ZERO
	var expected_vstar_width := roundf(first_scaled_size.y * texture_size.x / texture_size.y) if texture_size.y > 0.0 else -1.0

	var result := run_checks([
		assert_false(ready_visible, "VSTAR HUD label should be hidden when the PNG is present"),
		assert_false(used_visible, "Used VSTAR HUD should still hide the text label"),
		assert_true(ready_image != null and ready_image.texture != null, "VSTAR HUD should create a PNG texture layer"),
		assert_true(used_modulate.r < ready_modulate.r and used_modulate.g < ready_modulate.g and used_modulate.b < ready_modulate.b, "Used VSTAR HUD image should be visibly dimmed"),
		assert_true(absf(used_modulate.r - used_modulate.g) <= 0.04 and absf(used_modulate.g - used_modulate.b) <= 0.04, "Used VSTAR HUD image should use a low-saturation gray tint"),
		assert_eq(lost_text, "LOST 区：7张", "Lost Zone HUD should show the localized LOST count"),
		assert_true(texture_size.y > 0.0 and absf(first_scaled_size.x - expected_vstar_width) <= 1.0, "VSTAR HUD metrics should preserve the PNG aspect ratio"),
		assert_eq(second_scaled_size, first_scaled_size, "Repeated styling should not keep resizing VSTAR/lost HUDs"),
	])

	vstar_panel.queue_free()
	lost_panel.queue_free()
	scene.queue_free()
	return result


func test_battle_scene_vstar_hud_uses_stable_texture_variants() -> String:
	var scene: Control = BattleSceneScript.new()
	var panel_a := PanelContainer.new()
	panel_a.name = "InfoMyVstar"
	panel_a.custom_minimum_size = Vector2(100, 30)
	panel_a.set_meta("_vstar_hud_texture_index", 1)
	var panel_b := PanelContainer.new()
	panel_b.name = "InfoEnemyVstar"
	panel_b.custom_minimum_size = Vector2(100, 30)
	panel_b.set_meta("_vstar_hud_texture_index", 2)

	var image_a := scene.call("_ensure_vstar_hud_image", panel_a) as TextureRect
	var first_texture := image_a.texture if image_a != null else null
	var image_a_again := scene.call("_ensure_vstar_hud_image", panel_a) as TextureRect
	var second_texture := image_a_again.texture if image_a_again != null else null
	var image_b := scene.call("_ensure_vstar_hud_image", panel_b) as TextureRect
	var enemy_texture := image_b.texture if image_b != null else null

	var result := run_checks([
		assert_true(first_texture != null, "VSTAR HUD should load a texture variant"),
		assert_eq(second_texture, first_texture, "VSTAR HUD should keep the same random variant for one panel"),
		assert_true(enemy_texture != null and enemy_texture != first_texture, "Different VSTAR HUD panels can use different variants"),
	])

	panel_a.queue_free()
	panel_b.queue_free()
	scene.queue_free()
	return result


func test_battle_scene_vstar_hud_texture_follows_player_view() -> String:
	var scene: Control = BattleSceneScript.new()
	var my_label := Label.new()
	var my_panel := PanelContainer.new()
	my_panel.name = "InfoMyVstar"
	my_panel.custom_minimum_size = Vector2(100, 30)
	my_panel.add_child(my_label)
	var enemy_label := Label.new()
	var enemy_panel := PanelContainer.new()
	enemy_panel.name = "InfoEnemyVstar"
	enemy_panel.custom_minimum_size = Vector2(100, 30)
	enemy_panel.add_child(enemy_label)
	var gsm := GameStateMachine.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.vstar_power_used = [false, false]
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	scene.set("_my_vstar_value", my_label)
	scene.set("_enemy_vstar_value", enemy_label)
	scene.set("_gsm", gsm)
	scene.call("_set_vstar_hud_texture_index_for_player", 0, 1)
	scene.call("_set_vstar_hud_texture_index_for_player", 1, 2)

	scene.set("_view_player", 0)
	scene.call("_refresh_vstar_lost_hud_values")
	var my_image_view0 := my_panel.find_child("HudImageTexture", true, false) as TextureRect
	var enemy_image_view0 := enemy_panel.find_child("HudImageTexture", true, false) as TextureRect
	var player0_texture := my_image_view0.texture if my_image_view0 != null else null
	var player1_texture := enemy_image_view0.texture if enemy_image_view0 != null else null

	scene.set("_view_player", 1)
	scene.call("_refresh_vstar_lost_hud_values")
	var my_image_view1 := my_panel.find_child("HudImageTexture", true, false) as TextureRect
	var enemy_image_view1 := enemy_panel.find_child("HudImageTexture", true, false) as TextureRect

	var result := run_checks([
		assert_true(player0_texture != null and player1_texture != null, "VSTAR HUD should bind textures for both players"),
		assert_true(player0_texture != player1_texture, "Fixture should use two distinct player VSTAR textures"),
		assert_eq(my_image_view1.texture if my_image_view1 != null else null, player1_texture, "My VSTAR HUD should switch to the current view player's texture"),
		assert_eq(enemy_image_view1.texture if enemy_image_view1 != null else null, player0_texture, "Enemy VSTAR HUD should keep the opponent player's texture"),
	])

	my_panel.queue_free()
	enemy_panel.queue_free()
	scene.queue_free()
	return result


func test_battle_scene_end_turn_button_uses_stadium_hud_style() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	scene.call("_style_end_turn_hud_buttons")
	var button := scene.find_child("HudEndTurnBtn", true, false) as Button
	var image := button.get_node_or_null("EndTurnImage") as TextureRect if button != null else null
	var normal_style := button.get_theme_stylebox("normal") if button != null else null
	var hover_style := button.get_theme_stylebox("hover") if button != null else null
	var disabled_style := button.get_theme_stylebox("disabled") if button != null else null

	var result := run_checks([
		assert_eq(button.text if button != null else "missing", "结束我的回合", "End-turn HUD button should return to the readable text label"),
		assert_null(image, "End-turn HUD button should not keep the image layer"),
		assert_true(normal_style is StyleBoxFlat, "End-turn HUD button should use a normal HUD stylebox"),
		assert_true(hover_style is StyleBoxFlat, "End-turn HUD button should use a hover HUD stylebox"),
		assert_true(disabled_style is StyleBoxFlat, "End-turn HUD button should use a disabled HUD stylebox"),
	])

	scene.queue_free()
	return result


func test_battle_scene_stadium_hud_uses_card_preview_and_used_badge() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	var gsm := GameStateMachine.new()
	var stadium_cd := _make_trainer_cd("Test Stadium", "Stadium", "fixture")
	stadium_cd.effect_id = "test_stadium_action"
	var stadium := CardInstance.create(stadium_cd, 0)
	var effect := FakeStadiumActionEffect.new()
	gsm.effect_processor.register_effect(stadium_cd.effect_id, effect)
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 3
	gsm.game_state.stadium_card = stadium
	gsm.game_state.stadium_owner_index = 0
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)

	scene.call("_refresh_stadium_card_hud", gsm.game_state, 0, true)
	var card_view := scene.get("_stadium_card_view") as BattleCardView
	var label := scene.find_child("StadiumLbl", true, false) as Label
	var button := scene.find_child("BtnStadiumAction", true, false) as Button
	var action_row := scene.find_child("StadiumActionRow", true, false) as HBoxContainer
	var overlay := scene.find_child("StadiumCardOverlay", true, false) as Control
	var top_left: Label = null
	var top_right: Label = null
	if card_view != null:
		top_left = card_view.get("_top_left_badge") as Label
		top_right = card_view.get("_top_right_badge") as Label
	var before_used_badge := top_left.text if top_left != null else "missing"
	var before_use_badge := top_right.text if top_right != null else "missing"

	gsm.game_state.stadium_effect_used_turn = gsm.game_state.turn_number
	gsm.game_state.stadium_effect_used_player = 0
	gsm.game_state.stadium_effect_used_effect_id = stadium_cd.effect_id
	scene.call("_refresh_stadium_card_hud", gsm.game_state, 0, true)
	var after_used_badge := top_left.text if top_left != null else "missing"
	gsm.game_state.turn_number += 1
	gsm.game_state.current_player_index = 1
	scene.call("_refresh_stadium_card_hud", gsm.game_state, 1, false)
	var next_turn_badge := top_left.text if top_left != null else "missing"
	var stadium_center := scene.find_child("StadiumCenterSection", true, false) as Control

	var result := run_checks([
		assert_not_null(card_view, "Stadium HUD should create a card preview view"),
		assert_true(card_view.visible, "Stadium card preview should be visible when a Stadium is in play"),
		assert_true(overlay != null and card_view.get_parent() == overlay, "Stadium card preview should live in the floating overlay"),
		assert_false(action_row != null and action_row.is_ancestor_of(card_view), "Stadium card preview should not expand the compact Stadium HUD row"),
		assert_eq(card_view.card_instance, stadium, "Stadium card preview should bind the live Stadium card"),
		assert_false(label.visible, "Legacy Stadium label should be hidden when the card preview is active"),
		assert_false(button.visible, "Legacy Stadium action button should be hidden when the card preview is active"),
		assert_true(stadium_center == null or stadium_center.self_modulate.a < 0.01, "Legacy Stadium HUD panel should not draw behind the live Stadium card"),
		assert_eq(before_used_badge, "", "Unused Stadium action should not show the USED badge"),
		assert_eq(before_use_badge, "USE", "Available Stadium action should expose a compact use hint"),
		assert_eq(after_used_badge, "USED", "Used Stadium action should mark the live card preview as USED"),
		assert_eq(next_turn_badge, "", "Stadium USED badge should clear once the next turn starts"),
	])

	scene.queue_free()
	return result


func test_battle_scene_empty_stadium_restores_compact_hud_without_card_overlay() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	var gsm := GameStateMachine.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.call("_refresh_stadium_card_hud", gsm.game_state, 0, true)

	var card_view := scene.get("_stadium_card_view") as BattleCardView
	var label := scene.find_child("StadiumLbl", true, false) as Label
	var button := scene.find_child("BtnStadiumAction", true, false) as Button
	var stadium_center := scene.find_child("StadiumCenterSection", true, false) as Control

	var result := run_checks([
		assert_true(card_view == null or not card_view.visible, "Live Stadium card preview should stay hidden before a Stadium is played"),
		assert_true(label.visible, "Compact Stadium label should return before a Stadium is played"),
		assert_true(label.text != "", "Compact Stadium label should keep readable HUD text"),
		assert_false(button.visible, "Legacy compact Stadium action button should stay hidden in the placeholder state"),
		assert_true(stadium_center == null or stadium_center.self_modulate.a > 0.99, "Compact Stadium HUD panel should return before a Stadium is played"),
	])

	scene.queue_free()
	return result


func test_battle_scene_landscape_empty_stadium_keeps_hidden_placeholder() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	var gsm := GameStateMachine.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.call("_apply_landscape_layout_impl", Vector2(1600, 900))
	scene.call("_refresh_stadium_card_hud", gsm.game_state, 0, true)

	var label := scene.find_child("StadiumLbl", true, false) as Label
	var stadium_center := scene.find_child("StadiumCenterSection", true, false) as Control
	var action_row := scene.find_child("StadiumActionRow", true, false) as Control

	var result := run_checks([
		assert_not_null(stadium_center, "Landscape empty Stadium placeholder node should still exist"),
		assert_true(action_row != null and action_row.visible, "Landscape empty Stadium placeholder should keep its row in layout"),
		assert_false(label.visible if label != null else true, "Landscape should hide the 'no Stadium' label"),
		assert_true(stadium_center != null and stadium_center.self_modulate.a < 0.01, "Landscape should hide the empty Stadium HUD surface without deleting it"),
	])
	scene.queue_free()
	return result


func test_battle_scene_handover_prompt_uses_large_hud_touch_targets() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	scene.call("_style_handover_overlay")
	var handover_box := scene.get_node("HandoverPanel/HandoverCenter/HandoverBox") as PanelContainer
	var handover_label := scene.find_child("HandoverLbl", true, false) as Label
	var handover_button := scene.find_child("HandoverBtn", true, false) as Button

	return run_checks([
		assert_true(handover_box.custom_minimum_size.x >= 520.0, "Handover prompt should use a wider HUD panel"),
		assert_true(handover_box.custom_minimum_size.y >= 220.0, "Handover prompt should use a taller HUD panel"),
		assert_true(handover_label.custom_minimum_size.y >= 72.0, "Handover prompt text should reserve readable vertical space"),
		assert_true(handover_label.get_theme_font_size("font_size") >= 24, "Handover prompt text should be large enough on mobile"),
		assert_true(handover_button.custom_minimum_size.y >= 68.0, "Handover confirmation should use a large touch target"),
		assert_true(handover_button.custom_minimum_size.x >= 360.0, "Handover confirmation should be wide enough for clear tapping"),
		assert_true(handover_button.has_theme_stylebox("normal"), "Handover confirmation should use the HUD button style"),
	])


func test_battle_scene_top_actions_match_end_turn_row_height() -> String:
	var battle_scene := _make_battle_scene_stub()
	var viewport_size := Vector2(1600, 900)
	var stadium_height := 32.0
	var stadium_inner_vpad := 2
	var legacy_action_height := stadium_height - float(stadium_inner_vpad * 2)
	var action_height: float = battle_scene.call("_resolve_hud_action_button_height", stadium_height, stadium_inner_vpad)
	var resolved_top_height: float = battle_scene.call("_resolve_top_bar_height", viewport_size, stadium_height, action_height, stadium_inner_vpad)

	battle_scene.call("_apply_top_action_button_metrics", legacy_action_height, viewport_size)

	var zeus_button := battle_scene.get("_btn_zeus_help") as Button
	var opponent_hand_button := battle_scene.get("_btn_opponent_hand") as Button
	var discuss_button := battle_scene.get("_btn_battle_discuss_ai") as Button
	var back_button := battle_scene.get("_btn_back") as Button
	var replay_button := battle_scene.get("_btn_replay_next_turn") as Button
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	scene.call("_apply_top_bar_space_metrics", viewport_size, back_button.custom_minimum_size.x, 4)
	var top_bar_left := scene.get_node("TopBar/TopBarRow/TopBarLeft") as Control
	var top_bar_center := scene.get_node("TopBar/TopBarRow/TopBarCenter") as Control
	var top_bar_right := scene.get_node("TopBar/TopBarRow/TopBarRight") as Control
	var top_bar_right_box := top_bar_right as BoxContainer
	var top_bar_actions := scene.get_node("TopBar/TopBarRow/TopBarRight/TopBarActions") as HBoxContainer
	var phase_label := scene.find_child("LblPhase", true, false) as Label
	var turn_label := scene.find_child("LblTurn", true, false) as Label

	return run_checks([
		assert_eq(action_height, 44.0, "HUD action buttons should use a mobile-friendly minimum touch height"),
		assert_eq(resolved_top_height, action_height + float(stadium_inner_vpad * 2), "Top bar should grow to contain the enlarged end-turn row height"),
		assert_eq(zeus_button.custom_minimum_size.y, action_height, "Zeus help should use the same touch height as the end-turn button"),
		assert_eq(back_button.custom_minimum_size.y, action_height, "Back button should use the same touch height as the end-turn button"),
		assert_eq(replay_button.custom_minimum_size.y, action_height, "Replay buttons should share the top action touch height"),
		assert_true(back_button.custom_minimum_size.x < 126.0, "Top action buttons should stay compact enough to leave room for match info"),
		assert_eq(opponent_hand_button.custom_minimum_size.x, back_button.custom_minimum_size.x, "Opponent hand should match the back button width"),
		assert_eq(discuss_button.custom_minimum_size.x, back_button.custom_minimum_size.x, "AI discussion should match the back button width"),
		assert_eq(zeus_button.custom_minimum_size.x, back_button.custom_minimum_size.x, "Zeus help should match the back button width"),
		assert_eq(top_bar_left.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "Top left match info column should keep the original equal-column layout"),
		assert_eq(top_bar_center.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "Top turn info column should keep the original equal-column layout"),
		assert_eq(top_bar_right.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "Top action column should keep the original equal-column layout"),
		assert_true(top_bar_right_box is HBoxContainer, "Top action column should support right-aligning its child buttons"),
		assert_eq(top_bar_right_box.alignment, BoxContainer.ALIGNMENT_END, "Top action column should place buttons at the right edge of its column"),
		assert_eq(top_bar_actions.size_flags_horizontal, Control.SIZE_SHRINK_END, "Top action buttons should not expand and cover match info"),
		assert_eq(top_bar_actions.alignment, BoxContainer.ALIGNMENT_END, "Top action buttons should align to the right edge"),
		assert_false(phase_label.clip_text, "Phase label should keep its original text-driven minimum width inside CenterContainer"),
		assert_false(turn_label.clip_text, "Turn label should keep its original text-driven minimum width inside CenterContainer"),
		assert_gt(phase_label.get_combined_minimum_size().x, 0.0, "Phase label should remain visible after top action layout"),
		assert_gt(turn_label.get_combined_minimum_size().x, 0.0, "Turn label should remain visible after top action layout"),
		assert_eq(zeus_button.get_theme_font_size("font_size"), 12, "Top action copy should match the HUD button font size"),
	])


func test_battle_scene_includes_attack_vfx_preview_button_left_of_ai_advice() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	var preview_button := scene.find_child("BtnAttackVfxPreview", true, false)
	var ai_advice_button := scene.find_child("BtnAiAdvice", true, false)
	var discuss_button := scene.find_child("BtnBattleDiscussAI", true, false)
	var preview_index := preview_button.get_index() if preview_button is Button else -1
	var ai_index := ai_advice_button.get_index() if ai_advice_button is Button else -1
	var discuss_index := discuss_button.get_index() if discuss_button is Button else -1
	var preview_text: String = preview_button.text if preview_button is Button else ""

	return run_checks([
		assert_true(preview_button is Button, "BattleScene 顶栏应包含放烟花按钮"),
		assert_true(ai_advice_button is Button, "BattleScene 顶栏应保留 AI 建议按钮"),
		assert_true(discuss_button is Button, "BattleScene 顶栏应包含 AI 探讨按钮"),
		assert_eq((discuss_button as Button).text, "AI探讨", "AI 探讨按钮文案应为纯中文"),
		assert_eq(preview_text, "放烟花", "放烟花按钮文案应为纯中文"),
		assert_true(preview_index >= 0 and ai_index >= 0 and preview_index < ai_index, "放烟花按钮应位于 AI 建议左侧"),
		assert_true(ai_index >= 0 and discuss_index >= 0 and discuss_index > ai_index, "AI 探讨按钮应位于 AI 建议右侧"),
	])


func test_battle_scene_portrait_exposes_ai_discussion_entry() -> String:
	var scene := _make_battle_scene_stub()
	var discuss_button := scene.get("_btn_battle_discuss_ai") as Button
	var opponent_button := scene.get("_btn_opponent_hand") as Button
	var zeus_button := scene.get("_btn_zeus_help") as Button
	var back_button := scene.get("_btn_back") as Button
	var direct_buttons: Array = scene.call("_portrait_direct_top_action_buttons")
	var descriptors: Array = scene.call("_portrait_action_descriptors")
	var descriptor_texts: Array[String] = []
	for raw_descriptor: Variant in descriptors:
		if raw_descriptor is Dictionary:
			descriptor_texts.append(str((raw_descriptor as Dictionary).get("text", "")))

	var portrait_view := BattlePortraitLayoutViewScript.new()
	portrait_view.setup(scene, null)
	discuss_button.visible = true
	portrait_view.sync_top_action_visibility(true)

	return run_checks([
		assert_true(direct_buttons.has(opponent_button), "竖屏对战顶栏仍应直显对手手牌入口"),
		assert_true(direct_buttons.has(zeus_button), "竖屏对战顶栏仍应直显宙斯帮我入口"),
		assert_true(direct_buttons.has(back_button), "竖屏对战顶栏仍应直显退出入口"),
		assert_true(direct_buttons.has(discuss_button), "Portrait battle top bar should directly expose AI discussion"),
		assert_false(descriptor_texts.has("AI探讨"), "竖屏更多操作不应包含 AI 探讨入口"),
		assert_true(discuss_button.visible, "Portrait top action sync should keep AI discussion visible"),
	])


func test_battle_discussion_context_hides_opponent_private_zones() -> String:
	var original_ids: Array = GameManager.selected_deck_ids.duplicate()
	var original_mode: int = GameManager.current_mode
	var player_deck := DeckData.new()
	player_deck.id = 990101
	player_deck.deck_name = "对战探讨玩家牌"
	player_deck.total_cards = 60
	player_deck.cards = [{"set_code": "UTEST", "card_index": "001", "count": 4, "card_type": "Pokemon", "name": "己方基础"}]
	var opponent_deck := DeckData.new()
	opponent_deck.id = 990102
	opponent_deck.deck_name = "对战探讨对手牌"
	opponent_deck.total_cards = 60
	opponent_deck.cards = [{"set_code": "UTEST", "card_index": "002", "count": 4, "card_type": "Pokemon", "name": "对手基础"}]
	CardDatabase.save_deck(player_deck)
	CardDatabase.save_deck(opponent_deck)
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.selected_deck_ids = [player_deck.id, opponent_deck.id]

	var scene = BattleSceneScript.new()
	scene.set("_view_player", 0)
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 3
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	var my_card := _make_pokemon_cd("己方基础", 70, "P")
	my_card.set_code = "UTEST"
	my_card.card_index = "001"
	var opp_secret := _make_pokemon_cd("对手隐藏手牌", 70, "L")
	opp_secret.set_code = "UTEST"
	opp_secret.card_index = "999"
	var opp_active := _make_pokemon_cd("对手前场", 120, "L")
	opp_active.set_code = "UTEST"
	opp_active.card_index = "002"
	gsm.game_state.players[0].hand.append(CardInstance.create(my_card, 0))
	gsm.game_state.players[0].deck.append(CardInstance.create(my_card, 0))
	gsm.game_state.players[1].hand.append(CardInstance.create(opp_secret, 1))
	gsm.game_state.players[1].deck.append(CardInstance.create(opp_secret, 1))
	for _i: int in range(3):
		gsm.game_state.players[0].prizes.append(CardInstance.create(my_card, 0))
	for _i: int in range(4):
		gsm.game_state.players[1].prizes.append(CardInstance.create(opp_secret, 1))
	gsm.game_state.players[1].active_pokemon = PokemonSlot.new()
	gsm.game_state.players[1].active_pokemon.pokemon_stack.append(CardInstance.create(opp_active, 1))
	scene.set("_gsm", gsm)

	var context: Dictionary = scene.call("_build_battle_discussion_context")
	var opponent_public: Dictionary = context.get("opponent_public_state", {})
	var my_state: Dictionary = context.get("my_visible_state", {})
	var public_counts: Dictionary = context.get("public_counts", {})
	var context_text := JSON.stringify(context)

	GameManager.selected_deck_ids = original_ids
	GameManager.current_mode = original_mode
	CardDatabase.delete_deck(player_deck.id)
	CardDatabase.delete_deck(opponent_deck.id)

	return run_checks([
		assert_true((my_state.get("hand", []) as Array).size() == 1, "当前视角应包含己方手牌内容"),
		assert_eq(str(opponent_public.get("hand", "")), "[hidden: opponent hand contents are not visible]", "对手手牌内容必须隐藏"),
		assert_false(context_text.contains("对手隐藏手牌"), "对战探讨上下文不得泄露对手手牌或牌库具体卡名"),
		assert_true(context_text.contains("对手前场"), "对战探讨上下文应包含对手公开前场信息"),
		assert_eq(str(public_counts.get("prize_remaining_score", "")), "3-4", "Battle discussion should expose prize remaining score explicitly"),
		assert_eq(str(public_counts.get("prizes_taken_score", "")), "3-2", "Battle discussion should expose prizes taken score explicitly"),
	])


func test_battle_scene_includes_replay_navigation_buttons() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	var prev_button := scene.find_child("BtnReplayPrevTurn", true, false)
	var next_button := scene.find_child("BtnReplayNextTurn", true, false)

	return run_checks([
		assert_true(prev_button is Button, "BattleScene should expose BtnReplayPrevTurn"),
		assert_true(next_button is Button, "BattleScene should expose BtnReplayNextTurn"),
	])


func test_battle_scene_attack_vfx_preview_dialog_lists_profiles_and_plays_selected_effect() -> String:
	var battle_scene = _make_battle_scene_stub()
	var center_field := _attach_test_center_field(battle_scene, Vector2(80, 20), Vector2(1200, 760))
	var my_active := BattleCardViewScript.new()
	my_active.custom_minimum_size = Vector2(130, 182)
	my_active.position = Vector2(180, 440)
	center_field.add_child(my_active)
	var opp_active := BattleCardViewScript.new()
	opp_active.custom_minimum_size = Vector2(130, 182)
	opp_active.position = Vector2(780, 120)
	center_field.add_child(opp_active)
	battle_scene.set("_my_active", my_active)
	battle_scene.set("_opp_active", opp_active)
	battle_scene.set("_view_player", 0)

	battle_scene.call("_on_attack_vfx_preview_pressed")
	var pending_choice_before: String = str(battle_scene.get("_pending_choice"))
	var dialog_items: Array = battle_scene.get("_dialog_items_data")
	battle_scene.call("_handle_dialog_choice", PackedInt32Array([0]))
	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var burst: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null

	return run_checks([
		assert_eq(pending_choice_before, "attack_vfx_preview", "放烟花按钮应进入 attack_vfx_preview 对话流程"),
		assert_gte(dialog_items.size(), 1, "放烟花对话框应至少列出一个已实现特效"),
		assert_not_null(overlay, "选择预览特效后应创建攻击特效 overlay"),
		assert_not_null(burst, "选择预览特效后应立刻生成一个 burst 节点"),
		assert_eq(str(burst.get_meta("profile_id", "")), "hero_dragapult_ex", "第一个预览项应播放首个已实现英雄特效"),
	])


func test_battle_scene_attack_vfx_preview_uses_overlay_local_coordinates() -> String:
	var battle_scene = _make_battle_scene_stub()
	var main_area := Control.new()
	main_area.name = "MainArea"
	main_area.position = Vector2(48, 36)
	main_area.size = Vector2(1280, 720)
	battle_scene.add_child(main_area)

	var center_field := Control.new()
	center_field.name = "CenterField"
	center_field.position = Vector2(80, 20)
	center_field.size = Vector2(1200, 760)
	main_area.add_child(center_field)

	var my_active := BattleCardViewScript.new()
	my_active.custom_minimum_size = Vector2(130, 182)
	my_active.position = Vector2(180, 440)
	center_field.add_child(my_active)
	var opp_active := BattleCardViewScript.new()
	opp_active.custom_minimum_size = Vector2(130, 182)
	opp_active.position = Vector2(780, 120)
	center_field.add_child(opp_active)
	battle_scene.set("_my_active", my_active)
	battle_scene.set("_opp_active", opp_active)
	battle_scene.set("_view_player", 0)

	battle_scene.call("_on_attack_vfx_preview_pressed")
	battle_scene.call("_handle_dialog_choice", PackedInt32Array([0]))
	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var cast_node: Control = sequence.get_node_or_null("AttackVfxCast") as Control if sequence != null else null
	var expected_local := my_active.global_position + my_active.size * 0.5

	return run_checks([
		assert_not_null(overlay, "应创建攻击特效 overlay"),
		assert_eq(overlay.get_parent(), battle_scene, "Attack VFX overlay should attach to the scene root instead of MainArea"),
		assert_not_null(sequence, "应创建攻击特效序列节点"),
		assert_not_null(cast_node, "应创建攻击特效施法节点"),
		assert_eq(cast_node.position, expected_local, "攻击特效节点应落在 overlay 的正确局部坐标"),
	])


func test_vs_ai_ai_first_turn_returns_view_and_controls_to_human_after_setup() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene = _make_battle_scene_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 1
	scene._gsm = gsm
	scene._view_player = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var human: PlayerState = gsm.game_state.players[0]
	var ai_player: PlayerState = gsm.game_state.players[1]
	human.hand = [CardInstance.create(_make_pokemon_cd("Human Lead", 60, "C"), 0)]
	ai_player.hand = [CardInstance.create(_make_pokemon_cd("AI Lead", 60, "C"), 1)]
	for pi: int in 2:
		for deck_idx: int in 8:
			gsm.game_state.players[pi].deck.append(CardInstance.create(_make_pokemon_cd("Deck %d-%d" % [pi, deck_idx], 60, "C"), pi))
	gsm.state_changed.connect(scene._on_state_changed)
	gsm.action_logged.connect(scene._on_action_logged)
	gsm.player_choice_required.connect(scene._on_player_choice_required)
	gsm.game_over.connect(scene._on_game_over)
	gsm.coin_flipper.coin_flipped.connect(scene._on_coin_flipped)
	var ai := SetupThenEndTurnAIOpponent.new(1)
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_ai_opponent", ai)

	scene._begin_setup_flow()
	scene._handle_dialog_choice(PackedInt32Array([0]))
	var guard_steps: int = 0
	while bool(scene.get("_ai_step_scheduled")) and guard_steps < 6:
		scene._run_ai_step()
		guard_steps += 1

	var current_player_after_ai_turn: int = gsm.game_state.current_player_index
	var phase_after_ai_turn: int = gsm.game_state.phase
	var view_player_after_ai_turn: int = int(scene.get("_view_player"))
	var end_turn_disabled: bool = bool((scene.get("_btn_end_turn") as Button).disabled)
	var pending_choice_after_ai_turn: String = str(scene.get("_pending_choice"))
	var ai_setup_diagnostics := "run_count=%d scheduled=%s ready=%s blocking=%s draw=%s state=%s effect=%s" % [
		ai.run_count,
		str(scene.get("_ai_step_scheduled")),
		str(scene.call("_is_ai_turn_ready")),
		str(scene.call("_is_ui_blocking_ai")),
		str(scene.get("_draw_reveal_active")),
		str(scene.call("_state_snapshot")),
		str(scene.call("_effect_state_snapshot")),
	]
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(ai.run_count >= 2, "AI-first setup should run through setup resolution and the opening turn | %s" % ai_setup_diagnostics),
		assert_eq(ai.end_turn_calls, 1, "The AI test double should end exactly one opening turn"),
		assert_eq(current_player_after_ai_turn, 0, "After the AI opening turn ends, control should return to the human player"),
		assert_eq(phase_after_ai_turn, GameState.GamePhase.MAIN, "After the AI opening turn ends, the human should be in MAIN phase"),
		assert_eq(view_player_after_ai_turn, 0, "VS_AI should keep the visible side on the human player after the AI opening turn"),
		assert_false(end_turn_disabled, "The local player should regain an enabled end-turn button after the AI opening turn"),
		assert_eq(pending_choice_after_ai_turn, "", "No stale setup or AI prompt should remain after the AI opening turn"),
	])


func test_battle_scene_detects_reordered_deck_for_active_player_only() -> String:
	CardInstance.reset_id_counter()
	var scene := _make_battle_scene_stub()
	_seed_battle_scene_deck_previews(scene)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	gsm.game_state.players[0].deck = _make_named_deck_cards(0, ["A", "B", "C"])
	gsm.game_state.players[1].deck = _make_named_deck_cards(1, ["X", "Y", "Z"])
	scene._gsm = gsm
	scene._view_player = 0

	scene.call("_refresh_deck_shuffle_detection", gsm.game_state)
	# 模拟玩家0洗牌
	gsm.game_state.players[0].shuffle_deck()
	scene.call("_refresh_deck_shuffle_detection", gsm.game_state)

	var own_tween: Variant = scene.get("_my_deck_shuffle_tween")
	var opp_tween: Variant = scene.get("_opp_deck_shuffle_tween")
	scene.queue_free()
	return run_checks([
		assert_not_null(own_tween, "Reordering the viewed player's deck should start a shuffle effect"),
		assert_null(opp_tween, "Reordering one side should not start the other deck's shuffle effect"),
	])


func test_battle_scene_first_observed_shuffle_count_only_primes_missing_opponent_baseline() -> String:
	var scene := _make_battle_scene_stub()
	_seed_battle_scene_deck_previews(scene)
	var state := GameState.new()
	state.players = [PlayerState.new(), PlayerState.new()]
	for player_index: int in 2:
		state.players[player_index].player_index = player_index
		state.players[player_index].deck = _make_named_deck_cards(player_index, ["A", "B", "C"])
	state.players[0].shuffle_count = 2
	state.players[1].shuffle_count = 3
	scene.set("_view_player", 0)
	scene.set("_deck_shuffle_counts", {0: 2})

	scene.call("_refresh_deck_shuffle_detection", state)
	var false_opponent_tween: Variant = scene.get("_opp_deck_shuffle_tween")
	state.players[1].shuffle_count += 1
	scene.call("_refresh_deck_shuffle_detection", state)
	var real_opponent_tween: Variant = scene.get("_opp_deck_shuffle_tween")
	scene.queue_free()
	return run_checks([
		assert_null(false_opponent_tween, "An unrelated board refresh such as Evolution must not animate a player whose shuffle baseline was merely missing"),
		assert_not_null(real_opponent_tween, "A later real shuffle-count increment should still animate that player's deck"),
	])


func test_battle_scene_shuffle_effect_restart_replaces_running_tween() -> String:
	var scene := _make_battle_scene_stub()
	_seed_battle_scene_deck_previews(scene)

	scene.call("_play_deck_shuffle_effect", 0)
	var first_tween: Variant = scene.get("_my_deck_shuffle_tween")
	scene.call("_play_deck_shuffle_effect", 0)
	var second_tween: Variant = scene.get("_my_deck_shuffle_tween")

	scene.queue_free()
	return run_checks([
		assert_not_null(first_tween, "First shuffle should create a tween"),
		assert_not_null(second_tween, "Restarted shuffle should still have a tween"),
		assert_true(first_tween != second_tween, "Restarting the effect should replace the running tween"),
	])


func test_battle_scene_shuffle_effect_keeps_current_preview_base_when_no_tween_is_running() -> String:
	var scene := _make_battle_scene_stub()
	_seed_battle_scene_deck_previews(scene)
	scene.set("_view_player", 0)
	var my_preview: BattleCardView = scene.get("_my_deck_preview")
	my_preview.position = Vector2(18, 42)
	scene.set("_deck_preview_base_positions", {0: Vector2.ZERO, 1: Vector2.ZERO})

	scene.call("_play_deck_shuffle_effect", 0)
	var stored_base: Vector2 = (scene.get("_deck_preview_base_positions") as Dictionary).get(0, Vector2.ZERO)
	var preview_position: Vector2 = my_preview.position
	var tween_marker: Variant = scene.get("_my_deck_shuffle_tween")

	scene.queue_free()
	return run_checks([
		assert_eq(preview_position, Vector2(18, 42), "Starting a shuffle effect without an active tween should not snap the preview to a stale cached position"),
		assert_eq(stored_base, Vector2(18, 42), "Shuffle effect should capture the preview's current layout position as its base position"),
		assert_not_null(tween_marker, "Shuffle effect should still register an active tween marker"),
	])


func test_battle_scene_stop_deck_shuffle_effect_resets_visual_transform() -> String:
	var scene := _make_battle_scene_stub()
	_seed_battle_scene_deck_previews(scene)
	scene.set("_view_player", 0)
	var my_preview: BattleCardView = scene.get("_my_deck_preview")
	my_preview.rotation_degrees = 7.0
	my_preview.scale = Vector2(1.08, 1.08)
	scene.set("_my_deck_shuffle_tween", scene.create_tween())

	scene.call("_stop_deck_shuffle_effect", 0)
	var tween_marker: Variant = scene.get("_my_deck_shuffle_tween")
	var preview_rotation := my_preview.rotation_degrees
	var preview_scale := my_preview.scale

	scene.queue_free()
	return run_checks([
		assert_eq(preview_rotation, 0.0, "Stopping a shuffle effect should reset preview rotation"),
		assert_eq(preview_scale, Vector2.ONE, "Stopping a shuffle effect should reset preview scale"),
		assert_null(tween_marker, "Stopping a shuffle effect should clear the tween marker"),
	])


func test_battle_scene_turn_start_draw_starts_reveal_and_defers_hand_refresh() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_card := CardInstance.create(_make_pokemon_cd("Reveal Draw", 70, "C"), 0)
	gsm.game_state.players[0].hand = [drawn_card]

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		0,
		{"count": 1, "card_names": ["Reveal Draw"], "card_instance_ids": [drawn_card.instance_id]},
		1,
		"draw one"
	)
	battle_scene.call("_on_action_logged", action)
	battle_scene.call("_refresh_hand")

	var reveal_active: Variant = battle_scene.get("_draw_reveal_active")
	var pending_hand_refresh: Variant = battle_scene.get("_draw_reveal_pending_hand_refresh")
	var reveal_overlay: Variant = battle_scene.get("_draw_reveal_overlay")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")

	return run_checks([
		assert_eq(reveal_active, true, "DRAW_CARD actions should enter draw reveal state"),
		assert_eq(pending_hand_refresh, true, "Visible hand refresh should be deferred while draw reveal is active"),
		assert_not_null(reveal_overlay, "Draw reveal should provision its overlay when the first reveal starts"),
		assert_eq(hand_container.get_child_count(), 0, "Deferred hand refresh should not render the new hand cards yet"),
	])


func test_battle_scene_turn_start_snapshot_records_after_drawn_card_enters_hand() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 1
	gsm.game_state.phase = GameState.GamePhase.DRAW
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active_cd := _make_pokemon_cd("Opening Active", 70, "C")
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(active_cd, 0))
	gsm.game_state.players[0].active_pokemon = active_slot
	gsm.game_state.players[0].hand = _make_named_deck_cards(0, [
		"Hand 1",
		"Hand 2",
		"Hand 3",
		"Hand 4",
		"Hand 5",
		"Hand 6",
	])

	var drawn_card := CardInstance.create(_make_pokemon_cd("Turn Draw", 70, "C"), 0)
	gsm.game_state.players[0].hand.append(drawn_card)
	var recorder := FakeBattleRecorder.new()
	battle_scene.set("_battle_recorder", recorder)
	battle_scene.set("_battle_recording_started", true)
	battle_scene.set("_battle_recording_context_captured", true)

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		0,
		{"count": 1, "card_names": ["Turn Draw"], "card_instance_ids": [drawn_card.instance_id]},
		1,
		"draw one"
	)
	battle_scene.call("_on_action_logged", action)

	var turn_start_snapshot: Dictionary = {}
	for event: Dictionary in recorder.events:
		if str(event.get("event_type", "")) == "state_snapshot" and str(event.get("snapshot_reason", "")) == "turn_start":
			turn_start_snapshot = event
			break
	var players: Array = turn_start_snapshot.get("state", {}).get("players", [])
	var player_state: Dictionary = players[0] if players.size() > 0 and players[0] is Dictionary else {}
	var active_state: Dictionary = player_state.get("active", {})

	return run_checks([
		assert_false(turn_start_snapshot.is_empty(), "Turn-start snapshot should be recorded from the turn-start draw action"),
		assert_eq(int(player_state.get("hand_count", -1)), 7, "Turn-start snapshot should include the card drawn for turn"),
		assert_eq(str(active_state.get("pokemon_name", "")), "Opening Active", "Turn-start snapshot should still show the setup Active Pokemon"),
	])


func test_battle_scene_opening_turn_draw_does_not_reveal_card_already_in_hand() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 1
	gsm.game_state.phase = GameState.GamePhase.DRAW
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_card := CardInstance.create(_make_pokemon_cd("Opening Draw", 70, "C"), 0)
	gsm.game_state.players[0].hand = [drawn_card]
	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		0,
		{
			"count": 1,
			"card_names": ["Opening Draw"],
			"card_instance_ids": [drawn_card.instance_id],
			"turn_start": true,
			"draw_source": "turn_start",
		},
		1,
		"opening turn draw"
	)

	battle_scene.call("_on_action_logged", action)
	battle_scene.call("_refresh_hand")

	var reveal_active: Variant = battle_scene.get("_draw_reveal_active")
	var pending_hand_refresh: Variant = battle_scene.get("_draw_reveal_pending_hand_refresh")
	var reveal_overlay: Variant = battle_scene.get("_draw_reveal_overlay")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")

	return run_checks([
		assert_eq(reveal_active, false, "The opening turn draw should not replay a card that is already visible in hand"),
		assert_eq(pending_hand_refresh, false, "Skipping the opening draw reveal should not defer hand rendering"),
		assert_null(reveal_overlay, "Skipping the opening draw reveal should not create an overlay"),
		assert_eq(hand_container.get_child_count(), 1, "The opening draw card should remain directly visible in hand"),
	])


func test_battle_scene_turn_start_draw_waits_for_player_click_before_hand_refresh() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_card := CardInstance.create(_make_pokemon_cd("Player Reveal", 70, "C"), 0)
	gsm.game_state.players[0].hand = [drawn_card]

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		0,
		{"count": 1, "card_names": ["Player Reveal"], "card_instance_ids": [drawn_card.instance_id]},
		1,
		"draw one"
	)
	battle_scene.call("_on_action_logged", action)
	battle_scene.call("_refresh_hand")

	var waiting_before: Variant = battle_scene.get("_draw_reveal_waiting_for_confirm")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var has_confirm := controller != null and controller.has_method("confirm_current_reveal")
	if has_confirm:
		controller.call("confirm_current_reveal", battle_scene)

	var reveal_active_after: Variant = battle_scene.get("_draw_reveal_active")
	var pending_after: Variant = battle_scene.get("_draw_reveal_pending_hand_refresh")
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(waiting_before, true, "Human-controlled draw reveal should pause for click confirmation"),
		assert_eq(has_confirm, true, "Draw reveal controller should expose a confirm_current_reveal entrypoint"),
		assert_eq(reveal_active_after, false, "Reveal should finish after player confirmation"),
		assert_eq(pending_after, false, "Hand refresh deferral should clear after the reveal completes"),
		assert_eq(hand_container.get_child_count(), 1, "Confirmed draw reveal should finally render the drawn hand card"),
	])


func test_battle_scene_marked_later_turn_start_draw_auto_continues_for_human() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_card := CardInstance.create(_make_pokemon_cd("Turn Start Auto", 70, "C"), 0)
	gsm.game_state.players[0].hand = [drawn_card]

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		0,
		{
			"count": 1,
			"card_names": ["Turn Start Auto"],
			"card_instance_ids": [drawn_card.instance_id],
			"turn_start": true,
			"draw_source": "turn_start",
		},
		2,
		"turn start draw"
	)
	battle_scene.call("_on_action_logged", action)
	battle_scene.call("_refresh_hand")

	var waiting_before: Variant = battle_scene.get("_draw_reveal_waiting_for_confirm")
	var auto_pending_before: Variant = battle_scene.get("_draw_reveal_auto_continue_pending")
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var has_auto_continue := controller != null and controller.has_method("run_auto_continue")
	if has_auto_continue:
		controller.call("run_auto_continue", battle_scene)

	var reveal_active_after: Variant = battle_scene.get("_draw_reveal_active")
	var pending_after: Variant = battle_scene.get("_draw_reveal_pending_hand_refresh")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(waiting_before, false, "Human turn-start draw should not wait indefinitely for a click"),
		assert_eq(auto_pending_before, true, "Human turn-start draw should auto-continue after the reveal"),
		assert_eq(has_auto_continue, true, "Draw reveal controller should expose a run_auto_continue entrypoint"),
		assert_eq(reveal_active_after, false, "Auto-continued human turn-start draw should finish cleanly"),
		assert_eq(pending_after, false, "Turn-start auto-continue should flush the deferred hand refresh"),
		assert_eq(hand_container.get_child_count(), 1, "Auto-continued turn-start draw should render the drawn card into hand"),
	])


func test_battle_scene_turn_start_draw_auto_continues_for_ai_side() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 1)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_card := CardInstance.create(_make_pokemon_cd("AI Reveal", 70, "C"), 1)
	gsm.game_state.players[1].hand = [drawn_card]

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		1,
		{"count": 1, "card_names": ["AI Reveal"], "card_instance_ids": [drawn_card.instance_id]},
		1,
		"draw one"
	)
	battle_scene.call("_on_action_logged", action)
	battle_scene.call("_refresh_hand")

	var auto_pending_before: Variant = battle_scene.get("_draw_reveal_auto_continue_pending")
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var has_auto_continue := controller != null and controller.has_method("run_auto_continue")
	if has_auto_continue:
		controller.call("run_auto_continue", battle_scene)
	var reveal_active_after: Variant = battle_scene.get("_draw_reveal_active")
	var pending_after: Variant = battle_scene.get("_draw_reveal_pending_hand_refresh")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(auto_pending_before, true, "AI-controlled draw reveal should arm auto-continue instead of waiting for click"),
		assert_eq(has_auto_continue, true, "Draw reveal controller should expose a run_auto_continue entrypoint"),
		assert_eq(reveal_active_after, false, "Auto-continued AI reveal should finish cleanly"),
		assert_eq(pending_after, false, "AI auto-continue should flush the deferred hand refresh"),
		assert_eq(hand_container.get_child_count(), 1, "Auto-continued AI reveal should render the drawn hand card"),
	])


func test_battle_scene_professors_research_reveals_batch_until_single_confirm() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_cards: Array[CardInstance] = []
	var card_ids: Array[int] = []
	var card_names: Array[String] = []
	for card_index: int in 7:
		var drawn_card := CardInstance.create(_make_pokemon_cd("Research %d" % [card_index + 1], 70, "C"), 0)
		drawn_cards.append(drawn_card)
		card_ids.append(drawn_card.instance_id)
		card_names.append(drawn_card.card_data.name)
	gsm.game_state.players[0].hand = drawn_cards.duplicate()

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		0,
		{"count": 7, "card_names": card_names, "card_instance_ids": card_ids},
		1,
		"Professor's Research"
	)
	battle_scene.call("_on_action_logged", action)
	battle_scene.call("_refresh_hand")

	var waiting_before: Variant = battle_scene.get("_draw_reveal_waiting_for_confirm")
	var reveal_views_before: Array = battle_scene.get("_draw_reveal_card_views")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var has_confirm := controller != null and controller.has_method("confirm_current_reveal")
	if has_confirm:
		controller.call("confirm_current_reveal", battle_scene)

	var reveal_active_after: Variant = battle_scene.get("_draw_reveal_active")
	var pending_after: Variant = battle_scene.get("_draw_reveal_pending_hand_refresh")
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(waiting_before, true, "Professor's Research should pause once after revealing the full batch"),
		assert_eq(reveal_views_before.size(), 7, "Professor's Research should stage all seven revealed cards before confirmation"),
		assert_eq(hand_container.get_child_count(), 7, "The full batch should render into hand after the single confirmation"),
		assert_eq(has_confirm, true, "Batch reveal should use the same confirm entrypoint"),
		assert_eq(reveal_active_after, false, "Batch reveal should finish after the single confirmation"),
		assert_eq(pending_after, false, "Hand refresh deferral should clear after the batch reveal completes"),
	])


func test_battle_scene_professors_research_batch_auto_continues_for_ai_side() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 1)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_cards: Array[CardInstance] = []
	var card_ids: Array[int] = []
	var card_names: Array[String] = []
	for card_index: int in 7:
		var drawn_card := CardInstance.create(_make_pokemon_cd("AI Research %d" % [card_index + 1], 70, "C"), 1)
		drawn_cards.append(drawn_card)
		card_ids.append(drawn_card.instance_id)
		card_names.append(drawn_card.card_data.name)
	gsm.game_state.players[1].hand = drawn_cards.duplicate()

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		1,
		{"count": 7, "card_names": card_names, "card_instance_ids": card_ids},
		1,
		"Professor's Research"
	)
	battle_scene.call("_on_action_logged", action)
	battle_scene.call("_refresh_hand")

	var auto_pending_before: Variant = battle_scene.get("_draw_reveal_auto_continue_pending")
	var reveal_views_before: Array = battle_scene.get("_draw_reveal_card_views")
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var has_auto_continue := controller != null and controller.has_method("run_auto_continue")
	if has_auto_continue:
		controller.call("run_auto_continue", battle_scene)

	var reveal_active_after: Variant = battle_scene.get("_draw_reveal_active")
	var pending_after: Variant = battle_scene.get("_draw_reveal_pending_hand_refresh")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(auto_pending_before, true, "AI batch reveal should arm auto-continue after the final staged card"),
		assert_eq(reveal_views_before.size(), 7, "AI batch reveal should still stage all seven cards before continuing"),
		assert_eq(has_auto_continue, true, "Batch reveal should expose the auto-continue entrypoint"),
		assert_eq(reveal_active_after, false, "AI batch reveal should finish after auto-continue"),
		assert_eq(pending_after, false, "AI batch reveal should clear deferred hand refresh when complete"),
		assert_eq(hand_container.get_child_count(), 7, "AI batch reveal should render the full batch into hand once complete"),
	])


func test_battle_scene_professors_research_hides_drawn_cards_while_discard_reveal_is_running() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var professor_cd := CardData.new()
	professor_cd.name = "Professor's Research"
	professor_cd.card_type = "Supporter"
	professor_cd.effect_id = "aecd80ca2722885c3d062a2255346f3e"
	var professor := CardInstance.create(professor_cd, 0)
	var filler := CardInstance.create(_make_pokemon_cd("Discard Filler", 70, "C"), 0)
	gsm.game_state.players[0].hand = [professor, filler]
	for draw_index: int in 7:
		gsm.game_state.players[0].deck.append(CardInstance.create(_make_pokemon_cd("Research Draw %d" % [draw_index + 1], 70, "C"), 0))

	battle_scene.call("_refresh_hand")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	var before_play_count := hand_container.get_child_count()
	var played: bool = gsm.play_trainer(0, professor, [])
	var current_reveal: GameAction = battle_scene.get("_draw_reveal_current_action") as GameAction
	var queued_reveals: Array = battle_scene.get("_draw_reveal_queue")
	battle_scene.call("_refresh_hand")
	var during_discard_reveal_count := hand_container.get_child_count()
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(before_play_count, 2, "Precondition: the original hand should be visible before Professor's Research resolves"),
		assert_true(played, "Professor's Research should resolve successfully"),
		assert_not_null(current_reveal, "Professor's Research should start a reveal immediately"),
		assert_eq(current_reveal.action_type, GameAction.ActionType.DISCARD, "The first reveal should be the hand discard"),
		assert_true(queued_reveals.size() >= 1, "Professor's Research should queue the draw reveal behind the discard reveal"),
		assert_eq(during_discard_reveal_count, 0, "Freshly drawn cards should stay hidden while the discard reveal is still running"),
	])


func test_battle_scene_two_player_opponent_redraw_stays_face_down_and_targets_top_hand_area() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var layout := _attach_test_main_area_with_hand_area(
		battle_scene,
		Vector2.ZERO,
		Vector2(1600, 872),
		Vector2(72, 0),
		Vector2(1268, 872),
		Vector2(0, 762),
		Vector2(1268, 110),
		Vector2(1420, 0),
		Vector2(180, 872)
	)
	var center_field: Control = layout.get("center_field")
	var hand_area: Control = layout.get("hand_area")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_cards: Array[CardInstance] = []
	var card_ids: Array[int] = []
	var card_names: Array[String] = []
	for card_index: int in 2:
		var drawn_card := CardInstance.create(_make_pokemon_cd("Hidden Draw %d" % [card_index + 1], 70, "C"), 1)
		drawn_cards.append(drawn_card)
		card_ids.append(drawn_card.instance_id)
		card_names.append(drawn_card.card_data.name)
	gsm.game_state.players[1].hand = drawn_cards.duplicate()

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		1,
		{"count": 2, "card_names": card_names, "card_instance_ids": card_ids},
		3,
		"Judge redraw"
	)
	battle_scene.call("_on_action_logged", action)

	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var reveal_views: Array = battle_scene.get("_draw_reveal_card_views")
	var top_anchor: Variant = controller.call("_hand_target_anchor", battle_scene, 1)
	var bottom_anchor: Variant = controller.call("_hand_target_anchor", battle_scene, 0)
	var probe := BattleCardViewScript.new()
	probe.custom_minimum_size = Vector2(130, 182)
	var top_target: Vector2 = controller.call("_hand_target_position", battle_scene, probe, 1, 0, 1)
	var bottom_target: Vector2 = controller.call("_hand_target_position", battle_scene, probe, 0, 0, 1)
	var expected_top := Vector2(
		center_field.global_position.x + (center_field.size.x - 130.0) * 0.5,
		center_field.global_position.y + 16.0
	)
	var expected_bottom := Vector2(
		hand_area.global_position.x + (hand_area.size.x - 130.0) * 0.5,
		hand_area.global_position.y + (hand_area.size.y - 182.0) * 0.5
	)
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(battle_scene.get("_draw_reveal_auto_continue_pending"), true, "Hidden opponent redraw should auto-continue instead of waiting for local confirmation"),
		assert_eq(reveal_views.size(), 2, "Opponent redraw should still stage both cards"),
		assert_eq(top_anchor, center_field, "Opponent redraw should anchor to the center field instead of the hand strip"),
		assert_eq(bottom_anchor, hand_area, "Local redraw should anchor to the hand area"),
		assert_eq(top_target, expected_top, "Opponent redraw should fly to the upper middle of CenterField"),
		assert_eq(bottom_target, expected_bottom, "Local redraw should fly to the middle of HandArea"),
		assert_true(bool(reveal_views[0].get("_face_down")), "Opponent redraw should keep the first staged card face down"),
		assert_true(bool(reveal_views[1].get("_face_down")), "Opponent redraw should keep the second staged card face down"),
	])


func test_battle_scene_vs_ai_opponent_draw_targets_top_center_instead_of_my_hand() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI

	var battle_scene = _make_battle_scene_stub()
	var layout := _attach_test_main_area_with_hand_area(
		battle_scene,
		Vector2.ZERO,
		Vector2(1600, 900),
		Vector2(80, 20),
		Vector2(1200, 760),
		Vector2(0, 650),
		Vector2(1200, 110)
	)
	var center_field: Control = layout.get("center_field")
	var hand_area: Control = layout.get("hand_area")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_card := CardInstance.create(_make_pokemon_cd("AI Draw", 70, "C"), 1)
	gsm.game_state.players[1].hand = [drawn_card]
	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		1,
		{"count": 1, "card_names": [drawn_card.card_data.name], "card_instance_ids": [drawn_card.instance_id]},
		3,
		"AI draw"
	)
	battle_scene.call("_on_action_logged", action)

	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var probe := BattleCardViewScript.new()
	probe.custom_minimum_size = Vector2(130, 182)
	var anchor: Variant = controller.call("_hand_target_anchor", battle_scene, 1)
	var target: Vector2 = controller.call("_hand_target_position", battle_scene, probe, 1, 0, 1)
	var expected_top := Vector2(
		center_field.global_position.x + (center_field.size.x - 130.0) * 0.5,
		center_field.global_position.y + 16.0
	)
	var wrong_bottom := Vector2(
		hand_area.global_position.x + (hand_area.size.x - 130.0) * 0.5,
		hand_area.global_position.y + (hand_area.size.y - 182.0) * 0.5
	)
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(anchor, center_field, "VS AI opponent draw should anchor to CenterField rather than the local hand area"),
		assert_eq(target, expected_top, "VS AI opponent draw should target the upper middle of CenterField"),
		assert_true(target != wrong_bottom, "VS AI opponent draw must not target the local hand area"),
	])


func test_battle_scene_batch_draw_progressively_refreshes_visible_hand_cards() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_cards: Array[CardInstance] = []
	var card_ids: Array[int] = []
	var card_names: Array[String] = []
	for card_index: int in 3:
		var drawn_card := CardInstance.create(_make_pokemon_cd("Visible Draw %d" % [card_index + 1], 70, "C"), 0)
		drawn_cards.append(drawn_card)
		card_ids.append(drawn_card.instance_id)
		card_names.append(drawn_card.card_data.name)
	gsm.game_state.players[0].hand = drawn_cards.duplicate()

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		0,
		{"count": 3, "card_names": card_names, "card_instance_ids": card_ids},
		4,
		"Batch draw"
	)
	battle_scene.call("_on_action_logged", action)

	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")

	controller.call("_set_visible_reveal_count", battle_scene, 1)
	battle_scene.call("_refresh_hand")
	var count_after_first := hand_container.get_child_count()

	controller.call("_set_visible_reveal_count", battle_scene, 2)
	battle_scene.call("_refresh_hand")
	var count_after_second := hand_container.get_child_count()

	controller.call("_set_visible_reveal_count", battle_scene, 3)
	battle_scene.call("_refresh_hand")
	var count_after_third := hand_container.get_child_count()
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(count_after_first, 1, "The first landed card should immediately appear in hand"),
		assert_eq(count_after_second, 2, "The second landed card should increment the visible hand size"),
		assert_eq(count_after_third, 3, "The final landed card should complete the visible hand size"),
	])


func test_battle_scene_draw_reveal_hides_new_cards_before_the_first_fly_in() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var original_hand := CardInstance.create(_make_pokemon_cd("Existing Hand Card", 70, "C"), 0)
	var drawn_a := CardInstance.create(_make_pokemon_cd("Visible Draw 1", 70, "C"), 0)
	var drawn_b := CardInstance.create(_make_pokemon_cd("Visible Draw 2", 70, "C"), 0)
	gsm.game_state.players[0].hand = [original_hand, drawn_a, drawn_b]
	battle_scene.call("_refresh_hand")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	var before_action_count := hand_container.get_child_count()

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		0,
		{
			"count": 2,
			"card_names": [drawn_a.card_data.name, drawn_b.card_data.name],
			"card_instance_ids": [drawn_a.instance_id, drawn_b.instance_id],
		},
		4,
		"Batch draw"
	)
	battle_scene.call("_on_action_logged", action)
	var after_action_count := hand_container.get_child_count()
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(before_action_count, 3, "Precondition: the already-updated hand is visible before the draw reveal begins"),
		assert_eq(after_action_count, 1, "Draw reveal should hide the freshly drawn cards until they start flying into hand"),
	])


func test_battle_scene_hand_discard_action_starts_discard_reveal() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	_seed_battle_scene_discard_previews(battle_scene)
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var discarded_a := CardInstance.create(_make_pokemon_cd("Discard Reveal A", 70, "C"), 0)
	var discarded_b := CardInstance.create(_make_pokemon_cd("Discard Reveal B", 70, "C"), 0)
	gsm.game_state.players[0].discard_pile = [discarded_a, discarded_b]

	var action := GameAction.create(
		GameAction.ActionType.DISCARD,
		0,
		{
			"count": 2,
			"source_zone": "hand",
			"card_names": [discarded_a.card_data.name, discarded_b.card_data.name],
			"card_instance_ids": [discarded_a.instance_id, discarded_b.instance_id],
		},
		4,
		"discard two"
	)
	battle_scene.call("_on_action_logged", action)

	var reveal_active: Variant = battle_scene.get("_draw_reveal_active")
	var reveal_views: Array = battle_scene.get("_draw_reveal_card_views")
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(reveal_active, true, "Hand-origin DISCARD actions should reuse the reveal pipeline"),
		assert_eq(reveal_views.size(), 2, "Discard reveal should stage each discarded hand card"),
	])


func test_battle_scene_hand_discard_reveal_uses_slower_flight_duration_than_draw_reveal() -> String:
	var battle_scene = _make_battle_scene_stub()
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var discard_duration: Variant = controller.call("_discard_fly_duration_seconds")
	var draw_duration: Variant = controller.call("_draw_fly_duration_seconds")

	return run_checks([
		assert_eq(discard_duration, 0.14, "Hand discard reveal should use the tuned slower discard flight duration"),
		assert_eq(draw_duration, 0.08, "Draw reveal should keep its faster flight duration"),
		assert_true(float(discard_duration) > float(draw_duration), "Discard reveal should stay slower than draw reveal"),
	])


func test_battle_scene_hand_discard_reveal_removes_cards_from_hand_before_flying() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	_seed_battle_scene_discard_previews(battle_scene)
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var discarded_a := CardInstance.create(_make_pokemon_cd("Discard Reveal A", 70, "C"), 0)
	var discarded_b := CardInstance.create(_make_pokemon_cd("Discard Reveal B", 70, "C"), 0)
	var remaining := CardInstance.create(_make_pokemon_cd("Remaining Hand Card", 70, "C"), 0)
	gsm.game_state.players[0].hand = [discarded_a, discarded_b, remaining]
	battle_scene.call("_refresh_hand")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	var before_action_count := hand_container.get_child_count()

	gsm.game_state.players[0].hand = [remaining]
	gsm.game_state.players[0].discard_pile = [discarded_a, discarded_b]
	var action := GameAction.create(
		GameAction.ActionType.DISCARD,
		0,
		{
			"count": 2,
			"source_zone": "hand",
			"card_names": [discarded_a.card_data.name, discarded_b.card_data.name],
			"card_instance_ids": [discarded_a.instance_id, discarded_b.instance_id],
		},
		4,
		"discard two"
	)
	battle_scene.call("_on_action_logged", action)
	var after_action_count := hand_container.get_child_count()
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(before_action_count, 3, "Precondition: the original hand should still be visible before the discard action is logged"),
		assert_eq(after_action_count, 1, "Discard reveal should remove discarded cards from the hand immediately before the flight starts"),
	])


func test_battle_scene_hand_discard_reveal_updates_visible_discard_count_one_by_one() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	_seed_battle_scene_discard_previews(battle_scene)
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var existing := CardInstance.create(_make_pokemon_cd("Existing Discard", 70, "C"), 0)
	var discarded_a := CardInstance.create(_make_pokemon_cd("Discard Reveal A", 70, "C"), 0)
	var discarded_b := CardInstance.create(_make_pokemon_cd("Discard Reveal B", 70, "C"), 0)
	gsm.game_state.players[0].discard_pile = [existing, discarded_a, discarded_b]

	var action := GameAction.create(
		GameAction.ActionType.DISCARD,
		0,
		{
			"count": 2,
			"source_zone": "hand",
			"card_names": [discarded_a.card_data.name, discarded_b.card_data.name],
			"card_instance_ids": [discarded_a.instance_id, discarded_b.instance_id],
		},
		5,
		"discard two"
	)
	battle_scene.call("_on_action_logged", action)

	var display: RefCounted = battle_scene.get("_battle_display_controller")
	var before_visible: Array = display.call("_visible_discard_pile", battle_scene, 0, gsm.game_state.players[0].discard_pile)
	var reveal_views: Array = battle_scene.get("_draw_reveal_card_views")
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	controller.call("_mark_discard_card_landed", battle_scene, reveal_views[0], 0, 1)
	var after_first_visible: Array = display.call("_visible_discard_pile", battle_scene, 0, gsm.game_state.players[0].discard_pile)
	controller.call("_mark_discard_card_landed", battle_scene, reveal_views[1], 0, 2)
	var after_second_visible: Array = display.call("_visible_discard_pile", battle_scene, 0, gsm.game_state.players[0].discard_pile)
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(before_visible.size(), 1, "Before any discard card lands, only the pre-existing discard pile should be visible"),
		assert_eq(after_first_visible.size(), 2, "After the first discard lands, the visible discard pile should grow by one"),
		assert_eq(after_second_visible.size(), 3, "After the second discard lands, the visible discard pile should reach the full final size"),
	])


func test_battle_scene_attack_action_starts_fireworks_vfx_burst() -> String:
	var battle_scene = _make_battle_scene_stub()
	var center_field := _attach_test_center_field(battle_scene, Vector2(80, 20), Vector2(1200, 760))
	var my_active := BattleCardViewScript.new()
	my_active.custom_minimum_size = Vector2(130, 182)
	my_active.position = Vector2(180, 440)
	center_field.add_child(my_active)
	var opp_active := BattleCardViewScript.new()
	opp_active.custom_minimum_size = Vector2(130, 182)
	opp_active.position = Vector2(780, 120)
	center_field.add_child(opp_active)
	battle_scene.set("_my_active", my_active)
	battle_scene.set("_opp_active", opp_active)
	battle_scene.set("_view_player", 0)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Dragapult ex", 320, "P"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target", 220, "C"), 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Phantom Dive", "target_pokemon_name": "Target", "damage": 200},
		3,
		"attack"
	)
	battle_scene.call("_on_action_logged", action)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var overlay_child_count: int = overlay.get_child_count() if overlay != null else 0
	var burst: Control = overlay.get_child(0) as Control if overlay != null and overlay_child_count > 0 else null

	return run_checks([
		assert_not_null(overlay, "Attack action should lazily create the attack VFX overlay"),
		assert_eq(overlay_child_count, 1, "Attack action should spawn exactly one burst container"),
		assert_not_null(burst, "Attack burst container should exist"),
		assert_eq(str(burst.get_meta("profile_id", "")) if burst != null else "", "hero_dragapult_ex", "Hero attack should resolve its dedicated VFX profile"),
	])


func test_battle_scene_attack_vfx_targets_opponent_active_center() -> String:
	var battle_scene = _make_battle_scene_stub()
	var center_field := _attach_test_center_field(battle_scene, Vector2(80, 20), Vector2(1200, 760))
	var my_active := BattleCardViewScript.new()
	my_active.custom_minimum_size = Vector2(130, 182)
	my_active.position = Vector2(200, 440)
	center_field.add_child(my_active)
	var opp_active := BattleCardViewScript.new()
	opp_active.custom_minimum_size = Vector2(130, 182)
	opp_active.position = Vector2(760, 110)
	center_field.add_child(opp_active)
	battle_scene.set("_my_active", my_active)
	battle_scene.set("_opp_active", opp_active)
	battle_scene.set("_view_player", 0)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Charizard ex", 330, "R"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target", 220, "C"), 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Burning Darkness", "target_pokemon_name": "Target", "damage": 180},
		3,
		"attack"
	)
	var controller: RefCounted = battle_scene.get("_battle_attack_vfx_controller")
	var target: Vector2 = controller.call("resolve_impact_position", battle_scene, action) if controller != null else Vector2.ZERO
	var expected := opp_active.global_position + opp_active.size * 0.5

	return run_checks([
		assert_not_null(controller, "BattleScene should expose an attack VFX controller"),
		assert_eq(target, expected, "Attack VFX should target the opponent active center by default"),
	])


func test_battle_scene_attack_vfx_does_not_block_live_actions() -> String:
	var battle_scene = _make_battle_scene_stub()
	var center_field := _attach_test_center_field(battle_scene, Vector2(80, 20), Vector2(1200, 760))
	var my_active := BattleCardViewScript.new()
	my_active.custom_minimum_size = Vector2(130, 182)
	center_field.add_child(my_active)
	var opp_active := BattleCardViewScript.new()
	opp_active.custom_minimum_size = Vector2(130, 182)
	center_field.add_child(opp_active)
	battle_scene.set("_my_active", my_active)
	battle_scene.set("_opp_active", opp_active)
	battle_scene.set("_view_player", 0)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Raging Bolt ex", 240, "L"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target", 220, "C"), 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Burst Roar", "target_pokemon_name": "Target", "damage": 70},
		3,
		"attack"
	)
	battle_scene.call("_on_action_logged", action)

	return run_checks([
		assert_eq(battle_scene.call("_can_accept_live_action"), true, "Attack fireworks should not block the next live action gate"),
	])


func test_battle_scene_attack_vfx_overlay_does_not_shift_hand_area_layout() -> String:
	var battle_scene = _make_battle_scene_stub()
	var layout := _attach_test_main_area_with_hand_area(
		battle_scene,
		Vector2.ZERO,
		Vector2(1600, 872),
		Vector2(72, 0),
		Vector2(1268, 872),
		Vector2(0, 762),
		Vector2(1268, 110),
		Vector2(1420, 0),
		Vector2(180, 872)
	)
	var center_field: Control = layout.get("center_field")
	var hand_area: Control = layout.get("hand_area")
	var my_active := BattleCardViewScript.new()
	my_active.custom_minimum_size = Vector2(130, 182)
	my_active.position = Vector2(180, 440)
	center_field.add_child(my_active)
	var opp_active := BattleCardViewScript.new()
	opp_active.custom_minimum_size = Vector2(130, 182)
	opp_active.position = Vector2(780, 120)
	center_field.add_child(opp_active)
	battle_scene.set("_my_active", my_active)
	battle_scene.set("_opp_active", opp_active)
	battle_scene.set("_view_player", 0)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		for di: int in 3:
			player.deck.append(CardInstance.create(_make_pokemon_cd("Deck %d-%d" % [pi, di], 60, "C"), pi))
		gsm.game_state.players.append(player)
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Gouging Fire ex", 230, "R"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Charmander", 70, "R"), 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	var before_position := hand_area.global_position
	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Burning Charge", "target_pokemon_name": "Charmander", "damage": 260},
		3,
		"attack"
	)
	battle_scene.call("_on_action_logged", action)
	var after_position := hand_area.global_position

	return run_checks([
		assert_eq(after_position, before_position, "Attack VFX overlay should not perturb HandArea layout after an attack"),
	])


func test_battle_scene_fire_attack_spawns_real_impact_vfx_in_live_action() -> String:
	var battle_scene = _make_battle_scene_stub()
	var center_field := _attach_test_center_field(battle_scene, Vector2(80, 20), Vector2(1200, 760))
	var my_active := BattleCardViewScript.new()
	my_active.custom_minimum_size = Vector2(130, 182)
	my_active.position = Vector2(180, 440)
	center_field.add_child(my_active)
	var opp_active := BattleCardViewScript.new()
	opp_active.custom_minimum_size = Vector2(130, 182)
	opp_active.position = Vector2(780, 120)
	center_field.add_child(opp_active)
	battle_scene.set("_my_active", my_active)
	battle_scene.set("_opp_active", opp_active)
	battle_scene.set("_view_player", 0)

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var attacker_slot := PokemonSlot.new()
	attacker_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Gouging Fire ex", 230, "R"), 0))
	gsm.game_state.players[0].active_pokemon = attacker_slot
	var defender_slot := PokemonSlot.new()
	defender_slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Charmander", 70, "R"), 1))
	gsm.game_state.players[1].active_pokemon = defender_slot

	var action := GameAction.create(
		GameAction.ActionType.ATTACK,
		0,
		{"attack_name": "Burning Charge", "target_pokemon_name": "Charmander", "damage": 260},
		3,
		"attack"
	)
	battle_scene.call("_on_action_logged", action)

	var overlay: Control = battle_scene.get("_attack_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var impact_node: Node = sequence.get_node_or_null("AttackVfxImpact0") if sequence != null else null
	var residue_node: Node = sequence.get_node_or_null("AttackVfxResidue0") if sequence != null else null

	return run_checks([
		assert_not_null(overlay, "Fire live attack should create the attack VFX overlay"),
		assert_not_null(sequence, "Fire live attack should create a VFX sequence"),
		assert_eq(str(sequence.get_meta("profile_id", "")) if sequence != null else "", "fallback_fire", "Fire live attack should resolve the fire impact-only VFX profile"),
		assert_not_null(impact_node, "Fire live attack should create an impact node"),
		assert_not_null(residue_node, "Fire live attack should create a residue node"),
	])


func test_battle_scene_batch_draw_layout_wraps_after_four_cards() -> String:
	var battle_scene = _make_battle_scene_stub()
	var layout := _attach_test_main_area_with_hand_area(
		battle_scene,
		Vector2.ZERO,
		Vector2(1600, 872),
		Vector2(72, 0),
		Vector2(1268, 872),
		Vector2(0, 762),
		Vector2(1268, 110),
		Vector2(1420, 0),
		Vector2(180, 872)
	)
	var main_area: Control = layout.get("main_area")
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var positions: Array[Vector2] = []
	var scale_probe := BattleCardViewScript.new()
	scale_probe.custom_minimum_size = Vector2(130, 182)
	var scale: Vector2 = controller.call("_batch_reveal_scale", battle_scene, scale_probe, 7)
	var scaled_width: float = 130.0 * scale.x
	var scaled_height: float = 182.0 * scale.y
	for index: int in 7:
		var card_view := BattleCardViewScript.new()
		card_view.custom_minimum_size = Vector2(130, 182)
		positions.append(controller.call("_batch_stack_position", battle_scene, card_view, index, 7))

	var center_x: float = main_area.global_position.x + main_area.size.x * 0.5
	var first_row_y: float = positions[0].y
	var second_row_y: float = positions[4].y
	var first_row_center_x := (positions[0].x + positions[3].x + scaled_width) * 0.5
	var second_row_center_x := (positions[4].x + positions[6].x + scaled_width) * 0.5

	return run_checks([
		assert_eq(scale, Vector2(2.0, 2.0), "Professor's Research batch reveal should keep the same 2x scale as the single-card reveal"),
		assert_eq(positions[0].y, first_row_y, "First batch card should stay on the first row"),
		assert_eq(positions[1].y, first_row_y, "Second batch card should stay on the first row"),
		assert_eq(positions[2].y, first_row_y, "Third batch card should stay on the first row"),
		assert_eq(positions[3].y, first_row_y, "Fourth batch card should stay on the first row"),
		assert_eq(positions[4].y, second_row_y, "Fifth batch card should start the second row"),
		assert_eq(positions[5].y, second_row_y, "Sixth batch card should stay on the second row"),
		assert_eq(positions[6].y, second_row_y, "Seventh batch card should stay on the second row"),
		assert_true(absf(second_row_y - (first_row_y + scaled_height)) < 0.01, "Cards after the first four should move to a lower second row with no extra vertical gap"),
		assert_true(absf(positions[1].x - (positions[0].x + scaled_width)) < 0.01, "First-row cards should touch without extra horizontal gap"),
		assert_true(absf(positions[2].x - (positions[1].x + scaled_width)) < 0.01, "First-row cards should touch without extra horizontal gap"),
		assert_true(absf(positions[3].x - (positions[2].x + scaled_width)) < 0.01, "First-row cards should touch without extra horizontal gap"),
		assert_true(absf(positions[5].x - (positions[4].x + scaled_width)) < 0.01, "Second-row cards should touch without extra horizontal gap"),
		assert_true(absf(positions[6].x - (positions[5].x + scaled_width)) < 0.01, "Second-row cards should touch without extra horizontal gap"),
		assert_true(absf(first_row_center_x - center_x) < 0.01, "The first row should stay centered on the current screen instead of avoiding HUD strips"),
		assert_true(absf(second_row_center_x - center_x) < 0.01, "The second row should also stay centered on the current screen"),
	])


func test_battle_scene_batch_draw_layout_centers_short_second_row_independently() -> String:
	var battle_scene = _make_battle_scene_stub()
	var layout := _attach_test_main_area_with_hand_area(
		battle_scene,
		Vector2.ZERO,
		Vector2(1600, 872),
		Vector2(72, 0),
		Vector2(1268, 872),
		Vector2(0, 762),
		Vector2(1268, 110),
		Vector2(1420, 0),
		Vector2(180, 872)
	)
	var main_area: Control = layout.get("main_area")
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(130, 182)
	var scale: Vector2 = controller.call("_batch_reveal_scale", battle_scene, card_view, 7)
	var scaled_width: float = 130.0 * scale.x

	var first_row_left: Vector2 = controller.call("_batch_stack_position", battle_scene, card_view, 0, 7)
	var second_row_left: Vector2 = controller.call("_batch_stack_position", battle_scene, card_view, 4, 7)
	var first_row_right: Vector2 = controller.call("_batch_stack_position", battle_scene, card_view, 3, 7)
	var second_row_right: Vector2 = controller.call("_batch_stack_position", battle_scene, card_view, 6, 7)
	var center_x: float = main_area.global_position.x + main_area.size.x * 0.5
	var second_row_center_x := (second_row_left.x + second_row_right.x + scaled_width) * 0.5

	return run_checks([
		assert_true(second_row_left.x > first_row_left.x, "A three-card second row should not left-align with the four-card first row"),
		assert_true(second_row_right.x + scaled_width < first_row_right.x + scaled_width, "A three-card second row should end earlier than the four-card first row"),
		assert_true(absf(second_row_center_x - center_x) < 0.01, "A shorter second row should still be independently centered on the current screen"),
	])


func test_battle_scene_portrait_draw_reveal_uses_field_card_scale() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.size = Vector2(390, 844)
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.set("_field_active_card_size", Vector2(172.8, 240.0))
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(108, 150)

	var single_scale: Vector2 = controller.call("_reveal_scale", battle_scene, card_view)
	var batch_scale: Vector2 = controller.call("_batch_reveal_scale", battle_scene, card_view, 7)

	return run_checks([
		assert_eq(single_scale, Vector2(1.6, 1.6), "Portrait single-card draw reveal should match the field Active Pokemon size"),
		assert_gt(batch_scale.x, 1.0, "Portrait batch draw reveal should remain larger than the hand-card presentation"),
		assert_true(batch_scale.x <= single_scale.x, "Portrait batch reveal may shrink only as needed to keep every card visible"),
	])


func test_battle_scene_portrait_batch_draw_layout_fits_visible_screen() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.size = Vector2(390, 844)
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.set("_field_active_card_size", Vector2(172.8, 240.0))
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(108, 150)
	var scale: Vector2 = controller.call("_batch_reveal_scale", battle_scene, card_view, 7)
	var visual_size := card_view.custom_minimum_size * scale
	var anchor_rect: Rect2 = controller.call("_get_reveal_anchor_rect", battle_scene)
	var columns: int = controller.call("_batch_column_count", battle_scene, card_view, 7)
	var positions: Array[Vector2] = []
	var checks: Array[String] = [
		assert_gt(scale.x, 1.0, "Portrait batch reveal should enlarge cards beyond the hand-card size when the screen permits"),
	]
	for index: int in 7:
		var position: Vector2 = controller.call("_batch_stack_position", battle_scene, card_view, index, 7)
		positions.append(position)
		checks.append(assert_gte(position.x, anchor_rect.position.x, "Portrait reveal card %d should not overflow left" % [index + 1]))
		checks.append(assert_gte(position.y, anchor_rect.position.y, "Portrait reveal card %d should not overflow top" % [index + 1]))
		checks.append(assert_true(position.x + visual_size.x <= anchor_rect.position.x + anchor_rect.size.x + 0.01, "Portrait reveal card %d should not overflow right" % [index + 1]))
		checks.append(assert_true(position.y + visual_size.y <= anchor_rect.position.y + anchor_rect.size.y + 0.01, "Portrait reveal card %d should not overflow bottom" % [index + 1]))

	var center_x := anchor_rect.position.x + anchor_rect.size.x * 0.5
	var first_row_center := (positions[0].x + positions[columns - 1].x + visual_size.x) * 0.5
	checks.append(assert_gte(columns, 2, "Portrait batch reveal should keep at least two enlarged cards per row"))
	for index: int in range(1, columns):
		checks.append(assert_eq(positions[0].y, positions[index].y, "Portrait batch reveal should keep its first row aligned"))
	checks.append(assert_gt(positions[columns].y, positions[0].y, "Portrait batch reveal should wrap only after the enlarged first row is full"))
	checks.append(assert_true(absf(first_row_center - center_x) < 0.01, "Portrait batch reveal first row should stay centered"))

	return run_checks(checks)


func test_battle_scene_draw_reveal_blocks_live_actions() -> String:
	var battle_scene := _make_battle_scene_stub()
	battle_scene.set("_draw_reveal_active", true)
	var can_act: Variant = battle_scene.call("_can_accept_live_action")

	return run_checks([
		assert_eq(can_act, false, "Draw reveal should temporarily block live clicks until the reveal is resolved"),
	])


func test_battle_scene_draw_reveal_blocks_ai_progression() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var battle_scene := _make_battle_scene_stub()
	battle_scene.set("_draw_reveal_active", true)
	var ai_blocked: Variant = battle_scene.call("_is_ui_blocking_ai")
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(ai_blocked, true, "Active draw reveal should block AI progression until the reveal finishes"),
	])


func test_battle_scene_draw_reveal_shade_does_not_swallow_confirm_click() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_card := CardInstance.create(_make_pokemon_cd("Shade Click", 70, "C"), 0)
	gsm.game_state.players[0].hand = [drawn_card]

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		0,
		{"count": 1, "card_names": ["Shade Click"], "card_instance_ids": [drawn_card.instance_id]},
		1,
		"draw one"
	)
	battle_scene.call("_on_action_logged", action)
	var overlay: Control = battle_scene.get("_draw_reveal_overlay")
	var shade: ColorRect = overlay.get_child(0) as ColorRect

	return run_checks([
		assert_not_null(overlay, "Draw reveal should build an overlay for confirm state"),
		assert_not_null(shade, "Draw reveal overlay should include a dimming shade layer"),
		assert_eq(shade.mouse_filter, Control.MOUSE_FILTER_PASS, "The dimming shade must pass clicks through so the parent overlay can confirm the reveal"),
	])


func test_battle_scene_draw_reveal_centers_on_current_screen_instead_of_avoiding_hud_areas() -> String:
	var battle_scene = _make_battle_scene_stub()
	var layout := _attach_test_main_area_with_hand_area(
		battle_scene,
		Vector2.ZERO,
		Vector2(1600, 872),
		Vector2(72, 0),
		Vector2(1268, 872),
		Vector2(0, 762),
		Vector2(1268, 110),
		Vector2(1420, 0),
		Vector2(180, 872)
	)
	var main_area: Control = layout.get("main_area")
	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var card_view := BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(130, 182)

	var centered_position: Variant = controller.call("_center_position", battle_scene, card_view)
	var expected := Vector2(
		main_area.global_position.x + (main_area.size.x - 130.0) * 0.5,
		main_area.global_position.y + (main_area.size.y - 182.0) * 0.5
	)

	return run_checks([
		assert_eq(centered_position, expected, "Draw reveals should center on the current screen instead of avoiding hand/log HUD areas"),
	])


func test_battle_scene_two_player_turn_start_draw_waits_for_handover_before_reveal() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var drawn_card := CardInstance.create(_make_pokemon_cd("Deferred Draw", 70, "C"), 1)
	gsm.game_state.players[1].hand = [drawn_card]
	battle_scene.call("_check_two_player_handover")

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		1,
		{"count": 1, "card_names": ["Deferred Draw"], "card_instance_ids": [drawn_card.instance_id]},
		2,
		"draw one"
	)
	battle_scene.call("_on_action_logged", action)

	var handover_visible_before: bool = bool(battle_scene.get("_handover_panel").visible)
	var reveal_active_before: Variant = battle_scene.get("_draw_reveal_active")
	battle_scene.call("_on_handover_confirmed")
	var reveal_active_after: Variant = battle_scene.get("_draw_reveal_active")
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_true(handover_visible_before, "Two-player turn start should still be waiting on the handover confirmation"),
		assert_eq(reveal_active_before, false, "Turn-start draw reveal should stay deferred until the handover is confirmed"),
		assert_eq(reveal_active_after, true, "After the handover confirmation, the deferred draw reveal should begin"),
	])


