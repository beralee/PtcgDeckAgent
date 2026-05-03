class_name TestBattleUIHandoverRegression
extends TestBase

const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")


class SlotDetailSpyBattleScene extends BattleSceneScript:
	var shown_detail_cards: Array[CardData] = []
	var action_dialog_calls: int = 0

	func _show_card_detail(cd: CardData) -> void:
		shown_detail_cards.append(cd)

	func _show_pokemon_action_dialog(_cp: int, _slot: PokemonSlot, _include_attacks: bool) -> void:
		action_dialog_calls += 1


func _make_touch_test_pokemon(name: String = "长按测试宝可梦") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.hp = 70
	cd.energy_type = "C"
	cd.retreat_cost = 1
	return cd


func test_handover_confirmation_executes_pending_follow_up() -> String:
	var scene: Control = BattleSceneScript.new()

	var dialog_overlay := Panel.new()
	var handover_panel := Panel.new()
	var handover_label := Label.new()
	dialog_overlay.visible = false
	handover_panel.visible = false
	scene.set("_dialog_overlay", dialog_overlay)
	scene.set("_handover_panel", handover_panel)
	scene.set("_handover_lbl", handover_label)
	scene.set("_coin_overlay", Panel.new())
	scene.set("_detail_overlay", Panel.new())
	scene.set("_discard_overlay", Panel.new())
	scene.set("_pending_choice", "send_out")
	scene.set("_view_player", 0)

	scene.call("_show_handover_prompt", 1, func() -> void:
		scene.set("_view_player", 1)
		dialog_overlay.visible = true
	)
	scene.call("_on_handover_confirmed")
	var remaining_action: Callable = scene.get("_pending_handover_action")

	return run_checks([
		assert_eq(scene.get("_view_player"), 1, "handover should switch to the defending player"),
		assert_eq(scene.get("_pending_choice"), "send_out", "replacement choice should stay active"),
		assert_true(dialog_overlay.visible, "replacement dialog should be visible after handover"),
		assert_false(handover_panel.visible, "handover overlay should close once the dialog is shown"),
		assert_false(remaining_action.is_valid(), "pending handover action should be cleared after confirmation"),
	])


func test_reset_effect_interaction_preserves_knockout_send_out_prompt() -> String:
	var scene: Control = BattleSceneScript.new()

	var dialog_overlay := Panel.new()
	dialog_overlay.visible = false
	scene.set("_dialog_overlay", dialog_overlay)
	var handover_panel := Panel.new()
	handover_panel.visible = false
	scene.set("_handover_panel", handover_panel)
	var coin_overlay := Panel.new()
	coin_overlay.visible = false
	scene.set("_coin_overlay", coin_overlay)
	var detail_overlay := Panel.new()
	detail_overlay.visible = false
	scene.set("_detail_overlay", detail_overlay)
	var discard_overlay := Panel.new()
	discard_overlay.visible = false
	scene.set("_discard_overlay", discard_overlay)
	scene.set("_dialog_data", {"player": 1})
	scene.set("_dialog_items_data", ["placeholder"])
	scene.set("_dialog_multi_selected_indices", [0])
	scene.set("_dialog_card_selected_indices", [0])
	scene.set("_pending_choice", "send_out")
	scene.set("_pending_effect_kind", "attack")
	scene.set("_pending_effect_player_index", 0)
	scene.set("_pending_effect_step_index", 0)
	scene.set("_pending_effect_context", {"discard_basic_energy": []})
	dialog_overlay.visible = true

	scene.call("_reset_effect_interaction")

	return run_checks([
		assert_eq(scene.get("_pending_choice"), "send_out", "reset should not clear the replacement prompt"),
		assert_true(dialog_overlay.visible, "reset should not hide a follow-up prompt opened during the attack"),
		assert_eq(scene.get("_dialog_data").get("player", -1), 1, "reset should preserve the follow-up dialog context"),
	])


func test_check_two_player_handover_preserves_special_follow_up() -> String:
	var scene: Control = BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]

	scene.set("_gsm", gsm)
	var dialog_overlay := Panel.new()
	dialog_overlay.visible = false
	scene.set("_dialog_overlay", dialog_overlay)
	var handover_panel := Panel.new()
	handover_panel.visible = false
	scene.set("_handover_panel", handover_panel)
	scene.set("_handover_lbl", Label.new())
	var coin_overlay := Panel.new()
	coin_overlay.visible = false
	scene.set("_coin_overlay", coin_overlay)
	var detail_overlay := Panel.new()
	detail_overlay.visible = false
	scene.set("_detail_overlay", detail_overlay)
	var discard_overlay := Panel.new()
	discard_overlay.visible = false
	scene.set("_discard_overlay", discard_overlay)
	scene.set("_pending_choice", "send_out")
	scene.set("_view_player", 1)

	var original_mode := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	scene.call("_show_handover_prompt", 0, func() -> void:
		scene.set("_view_player", 0)
	)
	scene.call("_check_two_player_handover")
	var remaining_action: Callable = scene.get("_pending_handover_action")
	GameManager.current_mode = original_mode

	return run_checks([
		assert_true(handover_panel.visible, "special handover prompt should remain visible until confirmed"),
		assert_true(remaining_action.is_valid(), "special follow-up should not be cleared by generic handover checks"),
		assert_eq(scene.get("_view_player"), 1, "view should not switch before the confirmation button is pressed"),
	])


func test_slot_input_is_blocked_while_handover_overlay_is_visible() -> String:
	var scene: Control = BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]

	scene.set("_gsm", gsm)
	var dialog_overlay := Panel.new()
	dialog_overlay.visible = false
	scene.set("_dialog_overlay", dialog_overlay)
	var handover_panel := Panel.new()
	handover_panel.visible = false
	scene.set("_handover_panel", handover_panel)
	scene.set("_handover_lbl", Label.new())
	var coin_overlay := Panel.new()
	coin_overlay.visible = false
	scene.set("_coin_overlay", coin_overlay)
	var detail_overlay := Panel.new()
	detail_overlay.visible = false
	scene.set("_detail_overlay", detail_overlay)
	var discard_overlay := Panel.new()
	discard_overlay.visible = false
	scene.set("_discard_overlay", discard_overlay)
	scene.set("_view_player", 1)
	handover_panel.visible = true

	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	scene.call("_on_slot_input", click, "my_active")

	return run_checks([
		assert_false(scene.get("_dialog_overlay").visible, "board clicks should not open dialogs while handover is active"),
		assert_true(handover_panel.visible, "handover overlay should stay visible after blocked board input"),
	])


func test_slot_touch_long_press_opens_card_detail_and_suppresses_click() -> String:
	var scene := SlotDetailSpyBattleScene.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.set("_pending_choice", "")
	var handover_panel := Panel.new()
	handover_panel.visible = false
	scene.set("_handover_panel", handover_panel)

	var active_slot := PokemonSlot.new()
	var cd := _make_touch_test_pokemon()
	active_slot.pokemon_stack.append(CardInstance.create(cd, 0))
	gsm.game_state.players[0].active_pokemon = active_slot

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = Vector2(10, 10)
	scene.call("_on_slot_input", press, "my_active")
	scene.call("_on_slot_touch_long_press_timeout")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = Vector2(10, 10)
	scene.call("_on_slot_input", release, "my_active")
	var consumed := bool(scene.call("_consume_suppressed_slot_left_click", "my_active"))
	var consumed_again := bool(scene.call("_consume_suppressed_slot_left_click", "my_active"))

	return run_checks([
		assert_eq(scene.shown_detail_cards.size(), 1, "Long pressing a battle slot should open card detail once"),
		assert_eq(scene.shown_detail_cards[0].name if not scene.shown_detail_cards.is_empty() else "", "长按测试宝可梦", "Long press detail should use the slot's Pokemon card"),
		assert_false(bool(scene.get("_slot_touch_long_press_active")), "Releasing after a consumed long press should clear the touch state"),
		assert_true(consumed, "Long press should suppress the synthetic follow-up left click"),
		assert_false(consumed_again, "Synthetic click suppression should be consumed only once"),
	])


func test_slot_touch_press_blocks_emulated_mouse_until_release() -> String:
	var scene := SlotDetailSpyBattleScene.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.set("_pending_choice", "")
	var handover_panel := Panel.new()
	handover_panel.visible = false
	scene.set("_handover_panel", handover_panel)

	var active_slot := PokemonSlot.new()
	var cd := _make_touch_test_pokemon("Ability touch Pokemon")
	cd.abilities = [{"name": "Test Ability", "text": "Test ability text."}]
	active_slot.pokemon_stack.append(CardInstance.create(cd, 0))
	gsm.game_state.players[0].active_pokemon = active_slot

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = Vector2(10, 10)
	scene.call("_on_slot_input", press, "my_active")

	var emulated_mouse_press := InputEventMouseButton.new()
	emulated_mouse_press.pressed = true
	emulated_mouse_press.button_index = MOUSE_BUTTON_LEFT
	scene.call("_on_slot_input", emulated_mouse_press, "my_active")

	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = Vector2(10, 10)
	scene.call("_on_slot_input", release, "my_active")
	var consumed := bool(scene.call("_consume_suppressed_slot_left_click", "my_active"))

	return run_checks([
		assert_eq(scene.action_dialog_calls, 1, "Touch press should not open the Pokemon action dialog before release"),
		assert_eq(scene.shown_detail_cards.size(), 0, "A short touch should not open card detail"),
		assert_true(consumed, "Short touch should suppress the synthetic follow-up left click"),
	])


func test_slot_touch_drag_cancel_prevents_card_detail() -> String:
	var scene := SlotDetailSpyBattleScene.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)

	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(_make_touch_test_pokemon("拖动取消测试"), 0))
	gsm.game_state.players[0].active_pokemon = active_slot

	scene.call("_start_slot_touch_long_press", "my_active", Vector2(10, 10), 0)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(80, 80)
	scene.call("_handle_slot_touch_detail_input", drag, "my_active")
	scene.call("_on_slot_touch_long_press_timeout")
	var consumed := bool(scene.call("_consume_suppressed_slot_left_click", "my_active"))

	return run_checks([
		assert_false(bool(scene.get("_slot_touch_long_press_active")), "Dragging a battle slot should cancel long press"),
		assert_eq(scene.shown_detail_cards.size(), 0, "Canceled battle slot long press should not open detail"),
		assert_true(consumed, "Dragging a battle slot should suppress the synthetic follow-up left click"),
	])
