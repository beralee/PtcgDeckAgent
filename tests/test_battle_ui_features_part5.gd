## Phase 3 UI 功能测试 - 投币信号、弃牌区数据、卡牌详情文本

extends "res://tests/helpers/BattleUIFeaturesShared.gd"

func test_prize_touch_release_without_same_prompt_press_does_not_take_prize() -> String:
	var previous_mode: int = GameManager.current_mode
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_view_player", 0)
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 4
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("Release Echo Prize", 60, "C"), 0))
	gsm.set("_pending_prize_player_index", 0)
	gsm.set("_pending_prize_remaining", 1)

	var my_prize_slots: Array[BattleCardView] = []
	var opp_prize_slots: Array[BattleCardView] = []
	for _i: int in 6:
		my_prize_slots.append(BattleCardView.new())
		opp_prize_slots.append(BattleCardView.new())
	battle_scene.set("_my_prize_slots", my_prize_slots)
	battle_scene.set("_opp_prize_slots", opp_prize_slots)
	battle_scene.call("_setup_prize_viewer")
	battle_scene.set("_pending_choice", "take_prize")
	battle_scene.set("_pending_prize_player_index", 0)
	battle_scene.set("_pending_prize_remaining", 1)
	battle_scene.call("_update_prize_slots", my_prize_slots, gsm.game_state.players[0].get_prize_layout(), true)

	var prize_slot := my_prize_slots[0]
	var hand_before := gsm.game_state.players[0].hand.size()
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = Vector2(24, 24)
	if prize_slot != null:
		prize_slot.emit_signal("gui_input", release)
	var hand_after := gsm.game_state.players[0].hand.size()
	var pending_after := str(battle_scene.get("_pending_choice"))

	battle_scene.free()
	GameManager.current_mode = previous_mode
	GameManager.battle_layout_mode = previous_layout
	return run_checks([
		assert_eq(hand_after, hand_before, "A release inherited from the action that opened the Prize prompt must not auto-pick a Prize"),
		assert_eq(pending_after, "take_prize", "An unmatched release must leave the human Prize choice pending"),
	])


func test_prize_card_view_own_touch_input_takes_prize_on_android() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_view_player", 0)
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 4
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("Card View Prize", 60, "C"), 0))
	gsm.set("_pending_prize_player_index", 0)
	gsm.set("_pending_prize_remaining", 1)

	var my_prize_slots: Array[BattleCardView] = []
	var opp_prize_slots: Array[BattleCardView] = []
	for _i: int in 6:
		my_prize_slots.append(BattleCardView.new())
		opp_prize_slots.append(BattleCardView.new())
	battle_scene.set("_my_prize_slots", my_prize_slots)
	battle_scene.set("_opp_prize_slots", opp_prize_slots)
	battle_scene.call("_setup_prize_viewer")
	battle_scene.set("_pending_choice", "take_prize")
	battle_scene.set("_pending_prize_player_index", 0)
	battle_scene.set("_pending_prize_remaining", 1)
	battle_scene.call("_update_prize_slots", my_prize_slots, gsm.game_state.players[0].get_prize_layout(), true)

	var prize_slot := my_prize_slots[0]
	var connection_count := prize_slot.left_clicked.get_connections().size() if prize_slot != null else -1
	var hand_before := gsm.game_state.players[0].hand.size()
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = Vector2(24, 24)
	if prize_slot != null:
		prize_slot.call("_gui_input", press)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = Vector2(24, 24)
	if prize_slot != null:
		prize_slot.call("_gui_input", release)
	var hand_after := gsm.game_state.players[0].hand.size()

	battle_scene.free()
	return run_checks([
		assert_true(prize_slot != null, "The selectable Prize card should have a BattleCardView"),
		assert_gt(connection_count, 0, "Prize BattleCardView left-clicks should be bound to the Prize-taking path"),
		assert_eq(hand_after, hand_before + 1, "A real BattleCardView touch click should take the selected Prize instead of being swallowed by card preview input"),
	])


func test_prize_card_view_touch_uses_current_view_player_after_handover() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_view_player", 0)
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 4
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("Player 0 Prize", 60, "C"), 0))
	gsm.game_state.players[1].prizes.append(CardInstance.create(_make_pokemon_cd("Player 1 Prize", 60, "C"), 1))
	gsm.set("_pending_prize_player_index", 1)
	gsm.set("_pending_prize_remaining", 1)

	var my_prize_slots: Array[BattleCardView] = []
	var opp_prize_slots: Array[BattleCardView] = []
	for _i: int in 6:
		my_prize_slots.append(BattleCardView.new())
		opp_prize_slots.append(BattleCardView.new())
	battle_scene.set("_my_prize_slots", my_prize_slots)
	battle_scene.set("_opp_prize_slots", opp_prize_slots)
	battle_scene.call("_setup_prize_viewer")

	battle_scene.set("_view_player", 1)
	battle_scene.set("_pending_choice", "take_prize")
	battle_scene.set("_pending_prize_player_index", 1)
	battle_scene.set("_pending_prize_remaining", 1)
	battle_scene.call("_update_prize_slots", my_prize_slots, gsm.game_state.players[1].get_prize_layout(), true)

	var prize_slot := my_prize_slots[0]
	var player_zero_hand_before := gsm.game_state.players[0].hand.size()
	var player_one_hand_before := gsm.game_state.players[1].hand.size()
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = Vector2(24, 24)
	if prize_slot != null:
		prize_slot.call("_gui_input", press)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = Vector2(24, 24)
	if prize_slot != null:
		prize_slot.call("_gui_input", release)
	var player_zero_hand_after := gsm.game_state.players[0].hand.size()
	var player_one_hand_after := gsm.game_state.players[1].hand.size()
	var pending_after := str(battle_scene.get("_pending_choice"))

	battle_scene.free()
	return run_checks([
		assert_true(prize_slot != null, "The visible player's Prize slot should exist after handover"),
		assert_eq(player_zero_hand_after, player_zero_hand_before, "A stale Prize-slot binding should not take the previous view player's Prize"),
		assert_eq(player_one_hand_after, player_one_hand_before + 1, "Prize-slot card clicks should resolve against the current visible player after handover"),
		assert_false(pending_after == "take_prize", "Taking the current visible player's Prize should clear the prompt"),
	])


func test_prize_slot_resolve_failure_preserves_ui_prize_prompt() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 4
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("Unsynced Prize", 60, "C"), 0))

	var my_prize_slots: Array[BattleCardView] = []
	var opp_prize_slots: Array[BattleCardView] = []
	for _i: int in 6:
		my_prize_slots.append(BattleCardView.new())
		opp_prize_slots.append(BattleCardView.new())
	battle_scene.set("_my_prize_slots", my_prize_slots)
	battle_scene.set("_opp_prize_slots", opp_prize_slots)
	battle_scene.set("_pending_choice", "take_prize")
	battle_scene.set("_pending_prize_player_index", 0)
	battle_scene.set("_pending_prize_remaining", 1)

	var hand_before := gsm.game_state.players[0].hand.size()
	battle_scene.call("_try_take_prize_from_slot", 0, 0)
	var hand_after := gsm.game_state.players[0].hand.size()
	var pending_after := str(battle_scene.get("_pending_choice"))
	var pending_player_after := int(battle_scene.get("_pending_prize_player_index"))
	var pending_remaining_after := int(battle_scene.get("_pending_prize_remaining"))

	battle_scene.free()
	return run_checks([
		assert_eq(hand_after, hand_before, "If the engine rejects a prize resolve, no card should move to hand"),
		assert_eq(pending_after, "take_prize", "A failed engine prize resolve should keep the UI in prize selection instead of clearing into a dead state"),
		assert_eq(pending_player_after, 0, "The restored prize prompt should keep the same player"),
		assert_eq(pending_remaining_after, 1, "The restored prize prompt should keep the remaining count"),
	])


func test_portrait_action_hud_option_touch_works_when_position_is_distinct() -> String:
	var battle_scene := _make_portrait_koraidon_action_hud_scene()
	var original_touch_position := Vector2(360, 720)

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = original_touch_position
	battle_scene.call("_on_slot_input", press, "my_active")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = original_touch_position
	battle_scene.call("_on_slot_input", release, "my_active")

	var option := _first_action_hud_option(battle_scene)
	var intentional_touch := InputEventScreenTouch.new()
	intentional_touch.pressed = true
	intentional_touch.index = 1
	intentional_touch.position = Vector2(360, 160)
	_emit_action_hud_touch_tap(option, intentional_touch.index, intentional_touch.position)

	var gsm: GameStateMachine = battle_scene.get("_gsm")
	var opponent_damage := gsm.game_state.players[1].active_pokemon.damage_counters

	var result := run_checks([
		assert_true(option != null, "Portrait Koraidon action HUD should render at least one option"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "A deliberate option touch away from the opening slot tap should activate immediately"),
		assert_gt(opponent_damage, 0, "The deliberate option touch should execute Koraidon's first attack instead of requiring a second tap"),
	])

	battle_scene.free()
	return result


func test_portrait_mouse_opened_action_hud_option_click_works_after_release_open() -> String:
	var battle_scene := _make_portrait_koraidon_action_hud_scene()
	var original_click_position := Vector2(360, 720)

	_emit_slot_mouse_click(battle_scene, "my_active", original_click_position)

	var option := _first_action_hud_option(battle_scene)
	var option_click := InputEventMouseButton.new()
	option_click.button_index = MOUSE_BUTTON_LEFT
	option_click.pressed = true
	option_click.position = Vector2(360, 160)
	option_click.global_position = Vector2(360, 160)
	_emit_action_hud_mouse_click(option, option_click.position, option_click.global_position)

	var gsm: GameStateMachine = battle_scene.get("_gsm")
	var opponent_damage := gsm.game_state.players[1].active_pokemon.damage_counters

	var result := run_checks([
		assert_true(option != null, "Portrait mouse-opened action HUD should render at least one option"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "A real mouse option click away from the opening slot click should activate"),
		assert_gt(opponent_damage, 0, "The first real mouse option click should execute Koraidon's first attack instead of requiring a second click"),
	])

	battle_scene.free()
	return result


func test_portrait_action_hud_option_click_works_after_touch_open() -> String:
	var battle_scene := _make_portrait_retreat_action_hud_scene()

	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = Vector2(24, 24)
	battle_scene.call("_on_slot_input", press, "my_active")
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = Vector2(24, 24)
	battle_scene.call("_on_slot_input", release, "my_active")

	var option := _first_action_hud_option(battle_scene)
	var intentional_click := InputEventMouseButton.new()
	intentional_click.button_index = MOUSE_BUTTON_LEFT
	intentional_click.pressed = true
	_emit_action_hud_mouse_click(option)

	var result := run_checks([
		assert_true(option != null, "Portrait Pokemon action HUD should render at least one option"),
		assert_eq(str(battle_scene.get("_pending_choice")), "retreat_bench", "Tapping the action HUD option should choose retreat"),
	])

	battle_scene.free()
	return result


func test_modal_choice_tap_suppresses_portrait_bench_grid_fallback() -> String:
	var battle_scene := _make_battle_scene_stub()
	battle_scene.call("_mark_modal_input_consumed", "test_modal_bench")

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(100, 100)
	var consumed := bool(battle_scene.call("_try_handle_portrait_bench_play_input", click))

	var result := run_checks([
		assert_true(consumed, "A follow-up touch event from a modal choice should be consumed before the portrait bench fallback can play a Basic Pokemon"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "Consuming the modal follow-up should not start another pending choice"),
	])

	battle_scene.free()
	return result


func test_modal_choice_tap_suppresses_followup_discard_hud_open() -> String:
	var battle_scene := _make_battle_scene_stub()
	var discard_overlay := battle_scene.get("_discard_overlay") as Panel
	discard_overlay.visible = false
	battle_scene.call("_mark_modal_input_consumed", "test_modal_discard")

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	battle_scene.call("_on_discard_open_control_input", click, 0, "Discard")

	var result := run_checks([
		assert_false(discard_overlay.visible, "A follow-up touch event from a modal card choice should not open the discard viewer"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "Consuming the modal follow-up should not start another pending choice"),
	])

	battle_scene.free()
	return result


func test_modal_choice_tap_suppresses_followup_lost_zone_hud_open() -> String:
	var battle_scene := _make_battle_scene_stub()
	var discard_overlay := battle_scene.get("_discard_overlay") as Panel
	discard_overlay.visible = false
	battle_scene.call("_mark_modal_input_consumed", "test_modal_lost_zone")

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	battle_scene.call("_on_lost_zone_open_control_input", click, false)

	var result := run_checks([
		assert_false(discard_overlay.visible, "A follow-up touch event from a modal card choice should not open the LOST viewer"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "Consuming the modal follow-up should not start another pending choice"),
	])

	battle_scene.free()
	return result


func test_recent_modal_completion_suppresses_delayed_lost_zone_hud_open() -> String:
	var battle_scene := _make_battle_scene_stub()
	var discard_overlay := battle_scene.get("_discard_overlay") as Panel
	discard_overlay.visible = false
	battle_scene.set("_modal_input_slot_suppress_until_msec", 0)
	battle_scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec())

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	battle_scene.call("_on_lost_zone_open_control_input", click, false)

	var result := run_checks([
		assert_false(discard_overlay.visible, "A delayed follow-up event after an action modal should not open the LOST viewer"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "Consuming the delayed LOST follow-up should not start another pending choice"),
	])

	battle_scene.free()
	return result


func test_battle_card_view_secondary_inspect_is_hand_only() -> String:
	var card_view := BattleCardViewScript.new()
	var card_data := _make_pokemon_cd("Field Inspect Blocked", 70, "R")
	card_view.setup_from_card_data(card_data, BattleCardViewScript.MODE_SLOT_ACTIVE)
	var right_count := 0
	card_view.right_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		right_count += 1
	)

	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	card_view.call("_gui_input", right_click)
	card_view.call("_start_touch_long_press", Vector2(8, 8), 0)
	card_view.call("_on_touch_long_press_timeout")

	return run_checks([
		assert_eq(right_count, 0, "Slot card views should not open card detail from right click or long press"),
		assert_false(bool(card_view.get("_touch_long_press_active")), "Slot card views should not start touch inspect state"),
	])


func test_battle_card_view_touch_drag_cancels_long_press_detail() -> String:
	var card_view := BattleCardViewScript.new()
	var card_data := _make_pokemon_cd("Touch Drag", 70, "R")
	card_view.setup_from_card_data(card_data, BattleCardViewScript.MODE_HAND)
	var detail_count := 0
	card_view.right_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
		detail_count += 1
	)

	card_view.call("_start_touch_long_press", Vector2(8, 8), 0)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(48, 8)
	card_view.call("_gui_input", drag)
	card_view.call("_on_touch_long_press_timeout")

	return run_checks([
		assert_eq(detail_count, 0, "Dragging should cancel touch inspect so scrolling a card row does not open detail"),
		assert_false(bool(card_view.get("_touch_long_press_active")), "Cancelled touch inspect should clear the active touch state"),
	])


func test_card_type_checks() -> String:
	var pokemon := _make_pokemon_cd("小火龙", 70, "R")
	var trainer := _make_trainer_cd("超级球", "Item", "搜索牌库")
	var energy := _make_energy_cd("火能量", "R")
	return run_checks([
		assert_true(pokemon.is_pokemon(), "宝可梦is_pokemon"),
		assert_true(pokemon.is_basic_pokemon(), "基础宝可梦is_basic_pokemon"),
		assert_false(pokemon.is_trainer(), "宝可梦非训练家"),
		assert_true(trainer.is_trainer(), "训练家is_trainer"),
		assert_false(trainer.is_pokemon(), "训练家非宝可梦"),
		assert_true(energy.is_energy(), "能量is_energy"),
	])
