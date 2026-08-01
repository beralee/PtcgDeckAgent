## Phase 3 UI 功能测试 - 投币信号、弃牌区数据、卡牌详情文本

extends "res://tests/helpers/BattleUIFeaturesShared.gd"

const CSV9CAdvancedEffectsScript := preload("res://scripts/effects/pokemon_effects/CSV9CAdvancedEffects.gd")


func test_portrait_assignment_hud_uses_shared_drag_for_both_scrollable_card_lanes() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var source_items: Array = []
	var target_items: Array = []
	for index: int in 8:
		source_items.append(CardInstance.create(_make_energy_cd("Source Energy %d" % index, "P"), 0))
		target_items.append(CardInstance.create(_make_pokemon_cd("Target %d" % index, 70, "P"), 0))

	battle_scene.call("_show_assignment_dialog", {
		"source_items": source_items,
		"source_labels": [],
		"target_items": target_items,
		"target_labels": [],
		"min_select": 1,
		"max_select": 4,
	})

	var source_scroll := battle_scene.get("_dialog_assignment_source_scroll") as ScrollContainer
	var target_scroll := battle_scene.get("_dialog_assignment_target_scroll") as ScrollContainer
	var source_row := battle_scene.get("_dialog_assignment_source_row") as HBoxContainer
	var target_row := battle_scene.get("_dialog_assignment_target_row") as HBoxContainer
	var source_card := source_row.get_child(0) as BattleCardView if source_row.get_child_count() > 0 else null
	var target_card := target_row.get_child(0) as BattleCardView if target_row.get_child_count() > 0 else null
	battle_scene.set("_card_gallery_drag_suppress_click_until_msec", Time.get_ticks_msec() + 1000)
	battle_scene.call("_on_assignment_source_chosen", 0)
	var selected_source_after_suppressed_drag := int(battle_scene.get("_dialog_assignment_selected_source_index"))

	return run_checks([
		assert_true(
			bool(source_scroll.get_meta("card_gallery_drag_scroll_enabled", false)),
			"The upper assignment lane must use the same browser drag coordinator as ordinary card-choice HUDs"
		),
		assert_true(
			bool(target_scroll.get_meta("card_gallery_drag_scroll_enabled", false)),
			"The lower assignment lane must use the same browser drag coordinator as ordinary card-choice HUDs"
		),
		assert_true(
			bool(source_scroll.get_meta("card_gallery_drag_scroll_active", false))
			and bool(target_scroll.get_meta("card_gallery_drag_scroll_active", false)),
			"Both visible assignment lanes must be active while the assignment HUD is open"
		),
		assert_true(
			source_card != null and bool(source_card.get_meta("card_gallery_drag_input_enabled", false)),
			"Source cards must forward touch motion instead of turning a held swipe into a selection"
		),
		assert_true(
			target_card != null and bool(target_card.get_meta("card_gallery_drag_input_enabled", false)),
			"Target cards must forward touch motion instead of turning a held swipe into a selection"
		),
		assert_true(
			bool(source_scroll.get_meta("card_gallery_drag_keep_scrollbars_visible", false))
			and bool(target_scroll.get_meta("card_gallery_drag_keep_scrollbars_visible", false)),
			"Portrait assignment lanes must keep their bottom touch scrollbars visible"
		),
		assert_eq(
			selected_source_after_suppressed_drag,
			-1,
			"A card release immediately after dragging an assignment lane must not select a source"
		),
	])


func test_field_assignment_card_strip_uses_shared_drag_without_hiding_bottom_scrollbar() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		gsm.game_state.players.append(player)

	var target := PokemonSlot.new()
	target.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target", 120, "P"), 0))
	gsm.game_state.players[0].bench = [target]
	var source_items: Array = []
	for index: int in 8:
		source_items.append(CardInstance.create(_make_energy_cd("Energy %d" % index, "P"), 0))

	battle_scene.call("_show_field_assignment_interaction", {
		"title": "Assign Energy",
		"ui_mode": "card_assignment",
		"source_items": source_items,
		"source_labels": [],
		"target_items": [target],
		"target_labels": ["Target"],
		"min_select": 1,
		"max_select": 4,
		"allow_cancel": true,
	})

	var scroll := battle_scene.get("_field_interaction_scroll") as ScrollContainer
	var row := battle_scene.get("_field_interaction_row") as HBoxContainer
	var source_card := row.get_child(0) as BattleCardView if row != null and row.get_child_count() > 0 else null
	battle_scene.set("_card_gallery_drag_suppress_click_until_msec", Time.get_ticks_msec() + 1000)
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	var selected_source_after_suppressed_drag := int(battle_scene.get("_field_interaction_assignment_selected_source_index"))
	return run_checks([
		assert_true(
			scroll != null and bool(scroll.get_meta("card_gallery_drag_scroll_enabled", false)),
			"Field-assignment card strips must use the shared browser drag coordinator"
		),
		assert_true(
			scroll != null and bool(scroll.get_meta("card_gallery_drag_scroll_active", false)),
			"The field-assignment strip must accept upper-card-area swipes while visible"
		),
		assert_true(
			scroll != null and bool(scroll.get_meta("card_gallery_drag_keep_scrollbars_visible", false)),
			"The native bottom scrollbar must remain available independently of upper-area drag"
		),
		assert_true(
			source_card != null and bool(source_card.get_meta("card_gallery_drag_input_enabled", false)),
			"Field-assignment cards must forward touch motion instead of turning a held swipe into selection"
		),
		assert_eq(
			selected_source_after_suppressed_drag,
			-1,
			"A card release immediately after dragging the field strip must not select an energy"
		),
	])


func test_munkidori_ability_opens_and_completes_two_stage_field_interaction() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		gsm.game_state.players.append(player)

	var munkidori_data := _make_pokemon_cd("Munkidori", 110, "P")
	munkidori_data.effect_id = "munkidori_ui_regression"
	munkidori_data.abilities = [{"name": "Adrena-Brain", "text": "Move up to 3 damage counters."}]
	var munkidori := PokemonSlot.new()
	munkidori.pokemon_stack.append(CardInstance.create(munkidori_data, 0))
	munkidori.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness Energy", "D"), 0))
	var damaged_ally := PokemonSlot.new()
	damaged_ally.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Damaged Ally", 120, "P"), 0))
	damaged_ally.damage_counters = 20
	var opponent := PokemonSlot.new()
	opponent.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opponent", 120, "C"), 1))
	gsm.game_state.players[0].active_pokemon = munkidori
	gsm.game_state.players[0].bench = [damaged_ally]
	gsm.game_state.players[1].active_pokemon = opponent
	gsm.effect_processor.register_effect("munkidori_ui_regression", AbilityMoveDamageCountersToOpponentScript.new(3))

	battle_scene.call("_try_use_ability_with_interaction", 0, munkidori, 0)
	var opened_source_step := str(battle_scene.get("_field_interaction_mode"))
	battle_scene.call("_handle_field_slot_select_index", 0)
	var opened_counter_step := str(battle_scene.get("_field_interaction_mode"))
	battle_scene.call("_on_counter_distribution_amount_chosen", 2)
	battle_scene.call("_handle_counter_distribution_target", 0)

	return run_checks([
		assert_eq(opened_source_step, "slot_select", "Munkidori should always open the damaged-own-Pokemon selection when its conditions are met"),
		assert_eq(opened_counter_step, "counter_distribution", "Selecting the damage source should reliably open the opponent counter-placement step"),
		assert_eq(damaged_ally.damage_counters, 0, "Completing the HUD flow should remove the selected two counters from the ally"),
		assert_eq(opponent.damage_counters, 20, "Completing the HUD flow should place both counters on the opponent"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "A valid Munkidori interaction should finish without leaving a stuck modal"),
	])


func test_archaludon_alloy_build_auto_finishes_after_assigning_max_energy() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	var archaludon_data := _make_pokemon_cd("铝钢桥龙ex", 300, "M")
	archaludon_data.stage = "Stage 1"
	archaludon_data.evolves_from = "铝钢龙"
	archaludon_data.effect_id = "archaludon_alloy_build_ui_regression"
	archaludon_data.abilities = [{"name": "合金建设", "text": "附着最多2张基本钢能量。"}]
	var archaludon := PokemonSlot.new()
	archaludon.pokemon_stack.append(CardInstance.create(archaludon_data, 0))
	archaludon.turn_evolved = gsm.game_state.turn_number
	player.active_pokemon = archaludon
	var metal_a := CardInstance.create(_make_energy_cd("Metal Energy A", "M"), 0)
	var metal_b := CardInstance.create(_make_energy_cd("Metal Energy B", "M"), 0)
	player.discard_pile.append_array([metal_a, metal_b])
	gsm.effect_processor.register_effect(
		archaludon_data.effect_id,
		CSV9CAdvancedEffectsScript.ArchaludonExAlloyBuild.new()
	)

	battle_scene.call("_try_use_ability_with_interaction", 0, archaludon, 0)
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	battle_scene.call("_handle_field_assignment_target_index", 0)
	battle_scene.call("_on_field_assignment_source_chosen", 1)
	battle_scene.call("_handle_field_assignment_target_index", 0)

	return run_checks([
		assert_true(metal_a in archaludon.attached_energy and metal_b in archaludon.attached_energy, "Alloy Build should attach both selected Metal Energy cards after the second assignment"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "Reaching Alloy Build's maximum assignment count should finish instead of leaving Android on the Energy assignment page"),
		assert_false(bool((battle_scene.get("_field_interaction_overlay") as Control).visible), "Alloy Build should close the field assignment overlay after the maximum is assigned"),
	])


func test_portrait_crispin_cannot_skip_energy_steps_from_empty_or_stale_confirm() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	var crispin := CardInstance.create(_make_trainer_cd("Crispin", "Supporter", ""), 0)
	crispin.card_data.effect_id = "136fdb6578daa3b81aef369495de4c3d"
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var water := CardInstance.create(_make_energy_cd("Water Energy", "W"), 0)
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Crispin Target", 120, "C"), 0))
	player.active_pokemon = active
	player.hand = [crispin]
	player.deck = [fire, water]
	gsm.effect_processor.register_effect(crispin.card_data.effect_id, CSV9C196Crispin.new())

	battle_scene.call("_try_play_trainer_with_interaction", 0, crispin)
	battle_scene.call("_on_dialog_confirm")
	var first_step_after_empty_confirm := str(((battle_scene.get("_pending_effect_steps") as Array)[int(battle_scene.get("_pending_effect_step_index"))] as Dictionary).get("id", ""))

	var dialog_controller: RefCounted = battle_scene.get("_battle_dialog_controller")
	dialog_controller.call("on_library_search_candidate_pressed", battle_scene, 0)
	var confirm_press := InputEventMouseButton.new()
	confirm_press.button_index = MOUSE_BUTTON_LEFT
	confirm_press.pressed = true
	confirm_press.position = Vector2(420, 760)
	confirm_press.global_position = Vector2(420, 760)
	battle_scene.call("_on_dialog_confirm_input", confirm_press)
	battle_scene.call("_on_dialog_confirm_button_down")
	battle_scene.call("_on_dialog_confirm")

	var attachment_step_index := int(battle_scene.get("_pending_effect_step_index"))
	var attachment_step_id := str(((battle_scene.get("_pending_effect_steps") as Array)[attachment_step_index] as Dictionary).get("id", ""))
	battle_scene.call("_on_dialog_confirm")
	var stayed_on_attachment_after_echo := (
		str(battle_scene.get("_pending_choice")) == "effect_interaction"
		and int(battle_scene.get("_pending_effect_step_index")) == attachment_step_index
		and crispin in player.hand
	)

	battle_scene.call("_on_field_assignment_source_chosen", 0)
	battle_scene.call("_handle_field_assignment_target_index", 0)
	battle_scene.call("_on_field_interaction_confirm_pressed")

	return run_checks([
		assert_eq(first_step_after_empty_confirm, CSV9C196Crispin.HAND_STEP_ID, "Crispin must not skip its first Energy search on an empty confirm"),
		assert_eq(attachment_step_id, CSV9C196Crispin.ATTACH_STEP_ID, "Choosing the hand Energy should open Crispin's attachment step"),
		assert_true(stayed_on_attachment_after_echo, "The first dialog's delayed Android confirm must not immediately skip Crispin's attachment step"),
		assert_true(crispin in player.discard_pile, "Crispin should resolve after a fresh assignment confirmation"),
		assert_true(fire in player.hand, "The explicitly selected first Energy should enter the hand"),
		assert_true(water in active.attached_energy, "The different-type second Energy should attach to the selected Pokemon"),
	])

func test_battle_scene_two_player_terminal_draw_reveal_finishes_before_handover() -> String:
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

	var drawn_cards := _make_named_deck_cards(0, ["Rotom Draw 1", "Rotom Draw 2", "Rotom Draw 3"])
	gsm.game_state.players[0].hand = drawn_cards
	var card_names: Array[String] = []
	var card_ids: Array[int] = []
	for drawn_card: CardInstance in drawn_cards:
		card_names.append(drawn_card.card_data.name)
		card_ids.append(drawn_card.instance_id)

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		0,
		{"count": 3, "card_names": card_names, "card_instance_ids": card_ids},
		2,
		"Rotom V draws three"
	)
	battle_scene.call("_on_action_logged", action)
	var waiting_before_turn_pass: Variant = battle_scene.get("_draw_reveal_waiting_for_confirm")

	gsm.game_state.current_player_index = 1
	battle_scene.call("_check_two_player_handover")
	var handover_visible_during_reveal: bool = bool(battle_scene.get("_handover_panel").visible)
	var pending_handover_during_reveal: bool = (battle_scene.get("_pending_handover_action") as Callable).is_valid()
	var reveal_active_during_handover_check: Variant = battle_scene.get("_draw_reveal_active")

	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var has_confirm := controller != null and controller.has_method("confirm_current_reveal")
	if has_confirm:
		controller.call("confirm_current_reveal", battle_scene)
	var reveal_active_after_confirm: Variant = battle_scene.get("_draw_reveal_active")
	var handover_visible_after_confirm: bool = bool(battle_scene.get("_handover_panel").visible)
	var view_player_after_confirm: int = int(battle_scene.get("_view_player"))
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(waiting_before_turn_pass, true, "Terminal draw should first wait for the acting player to confirm their own reveal"),
		assert_eq(reveal_active_during_handover_check, true, "Terminal draw reveal should remain active when the turn has just passed"),
		assert_eq(handover_visible_during_reveal, false, "Handover prompt must not cover an unfinished private draw reveal"),
		assert_eq(pending_handover_during_reveal, false, "Handover action should not be armed until the private reveal finishes"),
		assert_eq(has_confirm, true, "Draw reveal controller should expose a confirm_current_reveal entrypoint"),
		assert_eq(reveal_active_after_confirm, false, "Confirming the terminal draw should finish the reveal"),
		assert_eq(handover_visible_after_confirm, true, "Handover prompt should appear only after the terminal draw reveal completes"),
		assert_eq(view_player_after_confirm, 0, "View should stay on the acting player until they pass the device"),
	])


func test_battle_scene_two_player_setup_view_alignment_skips_opening_turn_draw_reveal() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 1
	gsm.game_state.phase = GameState.GamePhase.DRAW
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 1)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var setup_hand: Array[CardInstance] = _make_named_deck_cards(0, [
		"Setup Hand 1",
		"Setup Hand 2",
		"Setup Hand 3",
		"Setup Hand 4",
		"Setup Hand 5",
		"Setup Hand 6",
	])
	var drawn_card := CardInstance.create(_make_pokemon_cd("First Turn Draw After Setup", 70, "C"), 0)
	setup_hand.append(drawn_card)
	gsm.game_state.players[0].hand = setup_hand

	var action := GameAction.create(
		GameAction.ActionType.DRAW_CARD,
		0,
		{"count": 1, "card_names": ["First Turn Draw After Setup"], "card_instance_ids": [drawn_card.instance_id]},
		1,
		"turn start draw after setup"
	)
	battle_scene.call("_on_action_logged", action)

	var reveal_active_before_alignment: Variant = battle_scene.get("_draw_reveal_active")
	var queue_size_before_alignment: int = (battle_scene.get("_draw_reveal_queue") as Array).size()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_view_player", 0)
	battle_scene.call("_refresh_hand")
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	var visible_count_before_resume := hand_container.get_child_count()

	battle_scene.call("_check_two_player_handover")
	var reveal_active_after_alignment: Variant = battle_scene.get("_draw_reveal_active")
	var auto_pending_after_alignment: Variant = battle_scene.get("_draw_reveal_auto_continue_pending")
	var visible_count_after_resume := hand_container.get_child_count()
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_eq(reveal_active_before_alignment, false, "Opening turn draw should not start a duplicate reveal while setup is aligning the view"),
		assert_eq(queue_size_before_alignment, 0, "Opening turn draw should not remain queued for a later duplicate reveal"),
		assert_eq(visible_count_before_resume, 7, "Realigned opening hand should immediately contain the already-drawn seventh card"),
		assert_eq(reveal_active_after_alignment, false, "Realigning to the current player should not revive the skipped opening draw reveal"),
		assert_eq(auto_pending_after_alignment, false, "Skipped opening draw should not leave an auto-continue callback pending"),
		assert_eq(visible_count_after_resume, 7, "Setup alignment should keep all seven hand cards visible"),
	])


func test_battle_scene_repeated_two_player_turn_start_draws_clear_reveal_state_between_turns() -> String:
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

	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var checks: Array[String] = []
	for turn_index: int in 4:
		var current_player: int = 1 if turn_index % 2 == 0 else 0
		gsm.game_state.current_player_index = current_player
		battle_scene.call("_check_two_player_handover")

		var drawn_card := CardInstance.create(_make_pokemon_cd("Loop Draw %d" % [turn_index + 1], 70, "C"), current_player)
		gsm.game_state.players[current_player].hand = [drawn_card]
		var action := GameAction.create(
			GameAction.ActionType.DRAW_CARD,
			current_player,
			{"count": 1, "card_names": [drawn_card.card_data.name], "card_instance_ids": [drawn_card.instance_id]},
			turn_index + 1,
			"loop draw"
		)
		battle_scene.call("_on_action_logged", action)
		checks.append(assert_eq(battle_scene.get("_draw_reveal_active"), false, "Deferred turn-start reveal should not start before handover confirmation on turn %d" % [turn_index + 1]))

		battle_scene.call("_on_handover_confirmed")
		checks.append(assert_eq(battle_scene.get("_draw_reveal_waiting_for_confirm"), true, "After handover confirmation, the reveal should enter click-to-continue state on turn %d" % [turn_index + 1]))
		checks.append(assert_not_null(battle_scene.get("_draw_reveal_current_action"), "After handover confirmation, the reveal should have a current action on turn %d" % [turn_index + 1]))
		var overlay_after_confirm: Control = battle_scene.get("_draw_reveal_overlay")
		var stage_after_confirm: Control = overlay_after_confirm.get_node_or_null("Stage") as Control if overlay_after_confirm != null else null
		checks.append(assert_not_null(stage_after_confirm, "Draw reveal overlay should keep its stage after handover confirmation on turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_card_views").size(), 1, "Each repeated turn-start draw should stage exactly one reveal card on turn %d" % [turn_index + 1]))

		controller.call("confirm_current_reveal", battle_scene)

		var overlay: Control = battle_scene.get("_draw_reveal_overlay")
		checks.append(assert_eq(battle_scene.get("_draw_reveal_active"), false, "Reveal active state should clear after confirmation on turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_waiting_for_confirm"), false, "Waiting-for-confirm should clear after confirmation on turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_queue").size(), 0, "Reveal queue should be empty after completion on turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_card_views").size(), 0, "Staged reveal cards should be cleared after completion on turn %d" % [turn_index + 1]))
		checks.append(assert_null(battle_scene.get("_draw_reveal_current_action"), "Current reveal action should clear after completion on turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_pending_hand_refresh"), false, "Deferred hand refresh should flush after completion on turn %d" % [turn_index + 1]))
		checks.append(assert_not_null(overlay, "Repeated reveal flow should provision an overlay by turn %d" % [turn_index + 1]))
		if overlay != null:
			checks.append(assert_eq(overlay.visible, false, "Reveal overlay should hide after completion on turn %d" % [turn_index + 1]))
			var hint: Label = overlay.get_node_or_null("Hint") as Label
			checks.append(assert_not_null(hint, "Reveal overlay should keep a hint label on turn %d" % [turn_index + 1]))
			if hint != null:
				checks.append(assert_eq(hint.text, "", "Reveal hint text should clear after completion on turn %d" % [turn_index + 1]))
				checks.append(assert_eq(hint.visible, false, "Reveal hint should hide after completion on turn %d" % [turn_index + 1]))

	GameManager.current_mode = previous_mode
	return run_checks(checks)


func test_battle_scene_repeated_vs_ai_draw_reveals_reset_after_human_and_ai_turns() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI

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

	var controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	var turn_players: Array[int] = [0, 1, 0, 1, 0]
	var checks: Array[String] = []
	for turn_index: int in turn_players.size():
		var current_player: int = turn_players[turn_index]
		gsm.game_state.current_player_index = current_player
		var drawn_card := CardInstance.create(_make_pokemon_cd("VS AI Draw %d" % [turn_index + 1], 70, "C"), current_player)
		gsm.game_state.players[current_player].hand = [drawn_card]
		var action := GameAction.create(
			GameAction.ActionType.DRAW_CARD,
			current_player,
			{"count": 1, "card_names": [drawn_card.card_data.name], "card_instance_ids": [drawn_card.instance_id]},
			turn_index + 1,
			"vs ai draw"
		)
		battle_scene.call("_on_action_logged", action)

		if current_player == 0:
			checks.append(assert_eq(battle_scene.get("_draw_reveal_waiting_for_confirm"), true, "Player draw should wait for click on turn %d" % [turn_index + 1]))
			controller.call("confirm_current_reveal", battle_scene)
		else:
			checks.append(assert_eq(battle_scene.get("_draw_reveal_auto_continue_pending"), true, "AI draw should arm auto-continue on turn %d" % [turn_index + 1]))
			controller.call("run_auto_continue", battle_scene)

		var overlay: Control = battle_scene.get("_draw_reveal_overlay")
		checks.append(assert_eq(battle_scene.get("_draw_reveal_active"), false, "Reveal active state should clear after turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_waiting_for_confirm"), false, "Waiting-for-confirm should be reset after turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_auto_continue_pending"), false, "Auto-continue flag should be reset after turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_card_views").size(), 0, "Staged reveal cards should clear after turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_queue").size(), 0, "Reveal queue should stay empty after turn %d" % [turn_index + 1]))
		checks.append(assert_null(battle_scene.get("_draw_reveal_current_action"), "Current reveal action should clear after turn %d" % [turn_index + 1]))
		checks.append(assert_eq(battle_scene.get("_draw_reveal_pending_hand_refresh"), false, "Deferred hand refresh should clear after turn %d" % [turn_index + 1]))
		checks.append(assert_not_null(overlay, "VS AI repeated reveal flow should provision an overlay by turn %d" % [turn_index + 1]))
		if overlay != null:
			checks.append(assert_eq(overlay.visible, false, "Reveal overlay should hide after turn %d" % [turn_index + 1]))

	GameManager.current_mode = previous_mode
	return run_checks(checks)


func test_battle_scene_replay_mode_blocks_live_hand_actions() -> String:
	var battle_scene := _make_battle_scene_stub()
	battle_scene.set("_battle_mode", "review_readonly")
	battle_scene.set("_selected_hand_card", CardInstance.create(_make_trainer_cd("Any", "Item", ""), 0))
	var can_act := bool(battle_scene.call("_can_accept_live_action"))

	return run_checks([
		assert_false(can_act, "Replay mode should block live actions"),
	])


func test_battle_scene_replay_next_turn_loads_adjacent_turn_start() -> String:
	var battle_scene := _make_battle_scene_stub()
	var replay_turn_numbers: Array[int] = [4, 6]
	battle_scene.set("_battle_mode", "review_readonly")
	battle_scene.set("_replay_match_dir", "res://tests/fixtures/match_review_fixture")
	battle_scene.set("_replay_turn_numbers", replay_turn_numbers)
	battle_scene.set("_replay_current_turn_index", 0)
	battle_scene.call("_on_replay_next_turn_pressed")

	return run_checks([
		assert_eq(int(battle_scene.get("_replay_current_turn_index")), 1, "Next Turn should advance the replay turn index"),
		assert_eq(int(battle_scene.get("_view_player")), 1, "Replay should follow the loaded turn's acting player"),
	])


func test_battle_scene_continue_from_here_switches_to_live_mode() -> String:
	var battle_scene := _make_battle_scene_stub()
	battle_scene.set("_gsm", GameStateMachine.new())
	battle_scene.set("_battle_mode", "review_readonly")
	battle_scene.set("_replay_loaded_raw_snapshot", _sample_raw_replay_snapshot())
	battle_scene.call("_on_replay_continue_pressed")

	var gsm := battle_scene.get("_gsm") as GameStateMachine
	return run_checks([
		assert_eq(str(battle_scene.get("_battle_mode")), "live", "Continue From Here should return the scene to live mode"),
		assert_true(battle_scene.call("_can_accept_live_action"), "Continue From Here should re-enable live actions"),
		assert_eq(gsm.game_state.turn_number, 6, "Continue From Here should load the replay turn into GameState"),
	])


func test_battle_scene_replay_mode_ignores_hand_card_clicks() -> String:
	var battle_scene := _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_battle_mode", "review_readonly")
	var hand_card := CardInstance.create(_make_pokemon_cd("Replay Test Basic", 70, "G"), 0)
	gsm.game_state.players[0].hand = [hand_card]
	battle_scene.call("_on_hand_card_clicked", hand_card, PanelContainer.new())

	return run_checks([
		assert_true(battle_scene.get("_selected_hand_card") == null, "Replay mode should ignore hand card clicks"),
	])


func test_battle_scene_opponent_hand_button_only_visible_in_vs_ai() -> String:
	var scene := _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 1
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene._gsm = gsm
	scene._view_player = 0
	var opponent_hand_button := scene.get("_btn_opponent_hand") as Button

	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	scene.call("_refresh_ui")
	var hidden_in_two_player := not opponent_hand_button.visible

	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.call("_refresh_ui")
	var visible_in_vs_ai := opponent_hand_button.visible
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_true(hidden_in_two_player, "对手手牌按钮在双人模式下应隐藏"),
		assert_true(visible_in_vs_ai, "对手手牌按钮在 VS_AI 模式下应显示"),
	])


func test_battle_scene_prize_hud_count_uses_two_line_mobile_text() -> String:
	var scene := _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 1
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	gsm.game_state.players[0].prizes = _make_named_deck_cards(0, ["My Prize 1", "My Prize 2", "My Prize 3", "My Prize 4"])
	gsm.game_state.players[1].prizes = _make_named_deck_cards(1, ["Opp Prize 1", "Opp Prize 2"])
	scene._gsm = gsm
	scene._view_player = 0

	scene.call("_refresh_ui")
	var my_prize_hud_count := scene.get("_my_prize_hud_count") as Label
	var opp_prize_hud_count := scene.get("_opp_prize_hud_count") as Label

	return run_checks([
		assert_eq(my_prize_hud_count.text if my_prize_hud_count != null else "", "奖赏卡\n剩余4张", "Self prize HUD should show title and remaining count on two lines"),
		assert_eq(opp_prize_hud_count.text if opp_prize_hud_count != null else "", "奖赏卡\n剩余2张", "Opponent prize HUD should show title and remaining count on two lines"),
	])


func test_battle_scene_two_player_hides_old_ai_and_vfx_buttons() -> String:
	var scene := _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 1
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene._gsm = gsm
	scene._view_player = 0
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	scene.call("_refresh_ui")
	var ai_advice_hidden := not (scene.get("_btn_ai_advice") as Button).visible
	var attack_vfx_hidden := not (scene.get("_btn_attack_vfx_preview") as Button).visible
	var discuss_visible := (scene.get("_btn_battle_discuss_ai") as Button).visible
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.call("_refresh_ui")
	var attack_vfx_hidden_in_vs_ai := not (scene.get("_btn_attack_vfx_preview") as Button).visible
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_true(ai_advice_hidden, "Two-player battle should hide the old AI advice button"),
		assert_true(attack_vfx_hidden, "Two-player battle should hide the attack VFX preview button"),
		assert_true(discuss_visible, "Two-player battle should keep the AI discussion button visible"),
		assert_true(attack_vfx_hidden_in_vs_ai, "VS_AI battle should hide the attack VFX preview button"),
	])


func test_battle_scene_opponent_hand_viewer_shows_card_previews() -> String:
	var scene := _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene._gsm = gsm
	scene._view_player = 0
	var discard_title := Label.new()
	var discard_overlay := Panel.new()
	var discard_list := ItemList.new()
	var discard_card_scroll := ScrollContainer.new()
	var discard_card_row := HBoxContainer.new()
	var discard_utility_row := HBoxContainer.new()
	scene.set("_discard_title", discard_title)
	scene.set("_discard_overlay", discard_overlay)
	scene.set("_discard_list", discard_list)
	scene.set("_discard_card_scroll", discard_card_scroll)
	scene.set("_discard_card_row", discard_card_row)
	scene.set("_discard_utility_row", discard_utility_row)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var opp_hand_a := CardInstance.create(_make_pokemon_cd("AI 手牌A", 70, "L"), 1)
	var opp_hand_b := CardInstance.create(_make_trainer_cd("AI 手牌B", "Item", "debug"), 1)
	gsm.game_state.players[1].hand = [opp_hand_a, opp_hand_b]

	scene.call("_show_opponent_hand_cards")
	var discard_scroll := scene.get("_discard_card_scroll") as ScrollContainer
	var first_preview := discard_card_row.get_child(0) as BattleCardView
	var shared_drag_checks := run_checks([
		assert_true(
			discard_scroll != null and bool(discard_scroll.get_meta("card_gallery_drag_scroll_active", false)),
			"The opponent-hand collection must activate the same drag surface as discard and deck viewers"
		),
		assert_true(
			first_preview != null and bool(first_preview.get_meta("card_gallery_drag_input_enabled", false)),
			"Opponent-hand previews must forward touch motion so holding and swiping cannot open a card accidentally"
		),
	])
	if shared_drag_checks != "":
		return shared_drag_checks

	return run_checks([
		assert_true(discard_overlay.visible, "点击对手手牌后应打开只读预览层"),
		assert_eq(discard_title.text, "对手手牌（2 张）", "预览层标题应显示对手手牌数量"),
		assert_eq(discard_card_row.get_child_count(), 2, "预览层应按缩略卡图显示对手当前手牌"),
	])


func test_battle_scene_discard_viewer_uses_hud_scrollbar_full_list() -> String:
	var scene := _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	var discard_title := Label.new()
	var discard_overlay := Panel.new()
	var discard_list := ItemList.new()
	var discard_scroll := ScrollContainer.new()
	var discard_card_row := HBoxContainer.new()
	var discard_utility_row := HBoxContainer.new()
	scene.set("_discard_title", discard_title)
	scene.set("_discard_overlay", discard_overlay)
	scene.set("_discard_list", discard_list)
	scene.set("_discard_card_scroll", discard_scroll)
	scene.set("_discard_card_row", discard_card_row)
	scene.set("_discard_utility_row", discard_utility_row)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	for i: int in range(10):
		gsm.game_state.players[0].discard_pile.append(CardInstance.create(_make_pokemon_cd("己方弃牌%d" % i, 70, "C"), 0))
	for i: int in range(8):
		gsm.game_state.players[1].discard_pile.append(CardInstance.create(_make_pokemon_cd("对方弃牌%d" % i, 70, "C"), 1))

	scene.call("_show_discard_pile", 0, "己方弃牌区")
	var first_card := discard_card_row.get_child(0) as BattleCardView if discard_card_row.get_child_count() > 0 else null
	var tenth_card := discard_card_row.get_child(9) as BattleCardView if discard_card_row.get_child_count() > 9 else null
	var first_player_card_count := discard_card_row.get_child_count()
	var first_player_page_size := int(scene.get("_discard_card_page_size"))
	var first_player_utility_visible := discard_utility_row.visible
	var first_player_horizontal_mode := discard_scroll.horizontal_scroll_mode
	var first_player_scroll_styled := discard_scroll.has_meta("hud_scrollbar_styled")
	var first_player_wheel_present := discard_utility_row.find_child("DiscardCardWheel", true, false) != null
	var first_player_hbar := discard_scroll.get_h_scroll_bar()
	var first_player_scrollbar_hidden := first_player_hbar != null and bool(first_player_hbar.get_meta("card_gallery_hidden_scrollbar", false)) and not first_player_hbar.visible

	scene.call("_show_discard_pile", 1, "对方弃牌区")
	var opponent_first_card := discard_card_row.get_child(0) as BattleCardView if discard_card_row.get_child_count() > 0 else null
	var opponent_last_card := discard_card_row.get_child(7) as BattleCardView if discard_card_row.get_child_count() > 7 else null
	var opponent_card_count := discard_card_row.get_child_count()
	var opponent_wheel_present := discard_utility_row.find_child("DiscardCardWheel", true, false) != null
	var collection_checks: Array[String] = [
		assert_true(first_player_scrollbar_hidden, "Discard viewer should hide the visible horizontal scrollbar and rely on drag scrolling"),
	]

	collection_checks.append_array([
		assert_true(discard_overlay.visible, "打开弃牌区应显示预览层"),
		assert_eq(first_player_card_count, 10, "弃牌区应把完整牌堆交给 HUD 滚动容器"),
		assert_eq(first_player_page_size, 0, "弃牌区不应再启用7张窗口模式"),
		assert_false(first_player_wheel_present, "弃牌区不应再创建旧滑轮"),
		assert_false(first_player_utility_visible, "弃牌区不应为空滑轮保留底部工具行"),
		assert_eq(first_player_horizontal_mode, ScrollContainer.SCROLL_MODE_AUTO, "弃牌区应使用原生横向滚动"),
		assert_true(first_player_scroll_styled, "弃牌区应应用 HUD 滚动条样式"),
		assert_eq(first_card.card_data.name if first_card != null and first_card.card_data != null else "", "己方弃牌9", "弃牌区初始窗口应从最新弃牌开始"),
		assert_eq(tenth_card.card_data.name if tenth_card != null and tenth_card.card_data != null else "", "己方弃牌0", "弃牌区完整滚动列表应包含最早弃牌"),
		assert_eq(opponent_card_count, 8, "对方弃牌区也应完整渲染所有可见弃牌"),
		assert_false(opponent_wheel_present, "对方弃牌区也不应创建旧滑轮"),
		assert_eq(opponent_first_card.card_data.name if opponent_first_card != null and opponent_first_card.card_data != null else "", "对方弃牌7", "对方弃牌区应从最新弃牌开始"),
		assert_eq(opponent_last_card.card_data.name if opponent_last_card != null and opponent_last_card.card_data != null else "", "对方弃牌0", "对方弃牌区完整列表应包含最早弃牌"),
		assert_str_contains(discard_title.text, "对方弃牌区", "对方弃牌区标题应刷新为对方区域"),
	])


	return run_checks(collection_checks)


func test_battle_scene_lost_zone_click_reuses_discard_viewer() -> String:
	var scene := _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	var discard_title := Label.new()
	var discard_overlay := Panel.new()
	var discard_list := ItemList.new()
	var discard_scroll := ScrollContainer.new()
	var discard_card_row := HBoxContainer.new()
	var discard_utility_row := HBoxContainer.new()
	scene.set("_discard_title", discard_title)
	scene.set("_discard_overlay", discard_overlay)
	scene.set("_discard_list", discard_list)
	scene.set("_discard_card_scroll", discard_scroll)
	scene.set("_discard_card_row", discard_card_row)
	scene.set("_discard_utility_row", discard_utility_row)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	gsm.game_state.players[1].lost_zone.append(CardInstance.create(_make_pokemon_cd("Lost A", 70, "C"), 1))
	gsm.game_state.players[1].lost_zone.append(CardInstance.create(_make_pokemon_cd("Lost B", 70, "C"), 1))

	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	scene.call("_on_lost_zone_open_control_input", click, true)
	var first_card := discard_card_row.get_child(0) as BattleCardView if discard_card_row.get_child_count() > 0 else null
	var second_card := discard_card_row.get_child(1) as BattleCardView if discard_card_row.get_child_count() > 1 else null

	return run_checks([
		assert_true(discard_overlay.visible, "Clicking LOST should open the shared card collection viewer"),
		assert_str_contains(discard_title.text, "LOST", "LOST viewer title should identify the LOST zone"),
		assert_eq(discard_card_row.get_child_count(), 2, "LOST viewer should render every card in the zone"),
		assert_eq(first_card.card_data.name if first_card != null and first_card.card_data != null else "", "Lost B", "LOST viewer should show the most recent lost card first like discard"),
		assert_eq(second_card.card_data.name if second_card != null and second_card.card_data != null else "", "Lost A", "LOST viewer should include older lost cards"),
	])


func test_normal_battle_discard_hud_physical_click_opens_collection_popup() -> String:
	var previous_mode: int = GameManager.current_mode
	var previous_ids: Array[int] = GameManager.selected_deck_ids.duplicate()
	var previous_launch: Dictionary = GameManager.peek_deck_training_launch()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.selected_deck_ids = [800018497, 800018502]
	GameManager.clear_deck_training_launch()

	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = BattleScenePacked.instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame

	scene.call("_setup_ai_for_tests")
	var coin_animator := scene.get("_coin_animator") as Control
	if coin_animator != null:
		coin_animator.visible = false
	scene.set("_coin_animating", false)
	(scene.get("_coin_flip_queue") as Array).clear()
	var gsm: GameStateMachine = scene.get("_gsm")
	if gsm != null and gsm.game_state != null and not gsm.game_state.players.is_empty():
		gsm.game_state.players[0].discard_pile.append(
			CardInstance.create(_make_pokemon_cd("Normal Battle Discard", 70, "C"), 0)
		)
		scene.call("_refresh_ui")
	var discard_panel := scene.find_child("MyDiscardHudPanel", true, false) as Control
	var discard_caption := scene.find_child("MyDiscardHudCaption", true, false) as Control
	var discard_overlay := scene.get("_discard_overlay") as Control
	var click_position := discard_caption.get_global_rect().get_center() if discard_caption != null else (
		discard_panel.get_global_rect().get_center() if discard_panel != null else Vector2.ZERO
	)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = click_position
	press.global_position = click_position
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = click_position
	release.global_position = click_position
	scene.get_viewport().push_input(press, true)
	scene.get_viewport().push_input(release, true)
	await tree.process_frame
	var caption_popup_opened := discard_overlay != null and discard_overlay.visible
	if caption_popup_opened:
		scene.call("_close_discard_collection_viewer", "normal_battle_caption_test")

	var discard_preview := scene.get("_my_discard_preview") as Control
	var preview_hit_rect := discard_panel.get_global_rect().intersection(discard_preview.get_global_rect()) if (
		discard_panel != null and discard_preview != null
	) else Rect2()
	var preview_click_position := preview_hit_rect.get_center()
	var touch_press := InputEventScreenTouch.new()
	touch_press.index = 0
	touch_press.pressed = true
	touch_press.position = preview_click_position
	var touch_release := InputEventScreenTouch.new()
	touch_release.index = 0
	touch_release.pressed = false
	touch_release.position = preview_click_position
	scene.get_viewport().push_input(touch_press, true)
	scene.get_viewport().push_input(touch_release, true)
	await tree.process_frame
	var preview_popup_opened := discard_overlay != null and discard_overlay.visible
	if preview_popup_opened:
		scene.call("_close_discard_collection_viewer", "normal_battle_preview_test")

	var panel_touch_position := (
		discard_panel.get_global_transform_with_canvas()
		* (discard_panel.size * 0.5)
		if discard_panel != null
		else Vector2.ZERO
	)
	var native_touch_press := InputEventScreenTouch.new()
	native_touch_press.index = 0
	native_touch_press.pressed = true
	native_touch_press.position = panel_touch_position
	var native_touch_handled := bool(
		scene.call("_try_handle_battle_hud_touch_input", native_touch_press)
	)
	var native_touch_popup_opened := (
		discard_overlay != null
		and discard_overlay.visible
	)
	var click_inside_panel := discard_panel != null and discard_panel.get_global_rect().has_point(click_position)
	if native_touch_popup_opened:
		scene.call("_close_discard_collection_viewer", "normal_battle_native_touch_test")

	var logical_panel_rect: Rect2 = scene.call(
		"_control_rect_in_battle_local",
		discard_panel
	)
	var logical_native_press := InputEventScreenTouch.new()
	logical_native_press.index = 0
	logical_native_press.pressed = true
	logical_native_press.position = logical_panel_rect.get_center()
	var logical_touch_handled := bool(
		scene.call("_try_handle_battle_hud_touch_input", logical_native_press)
	)
	var logical_touch_popup_opened := (
		discard_overlay != null
		and discard_overlay.visible
	)
	if logical_touch_popup_opened:
		scene.call("_close_discard_collection_viewer", "logical_viewport_touch_test")

	# Native Android can emit compatibility MouseButton first and ScreenTouch
	# second for one physical finger press. Opening on the mouse half must claim
	# the whole sequence so the newly visible backdrop cannot interpret the
	# touch half as a second tap and immediately close itself.
	scene.call("_configure_battle_pointer_input_for_tests", true)
	scene.call("_cancel_transient_platform_input", "android_mouse_first_test_reset")
	var android_mouse_first := InputEventMouseButton.new()
	android_mouse_first.button_index = MOUSE_BUTTON_LEFT
	android_mouse_first.pressed = true
	android_mouse_first.device = 0
	android_mouse_first.position = logical_panel_rect.get_center()
	android_mouse_first.global_position = logical_panel_rect.get_center()
	var android_mouse_result: Dictionary = scene.call(
		"_observe_battle_pointer_event",
		android_mouse_first
	)
	var android_mouse_sequence := (
		android_mouse_result.get("sequence", null) as PointerSequence
	)
	var android_mouse_state_before_open := (
		android_mouse_sequence.state if android_mouse_sequence != null else "null"
	)
	scene.call(
		"_on_discard_open_control_input",
		android_mouse_first,
		"my",
		"己方弃牌区"
	)
	var android_mouse_state_after_open := (
		android_mouse_sequence.state if android_mouse_sequence != null else "null"
	)
	var android_touch_echo := InputEventScreenTouch.new()
	android_touch_echo.index = 0
	android_touch_echo.pressed = true
	android_touch_echo.position = logical_panel_rect.get_center()
	var android_touch_result: Dictionary = scene.call(
		"_observe_battle_pointer_event",
		android_touch_echo
	)
	var android_touch_was_merged := bool(
		android_touch_result.get("synthetic_echo", false)
	)
	var android_open_sequence_claimed := (
		android_mouse_sequence != null
		and android_mouse_sequence.owner == "battle_modal"
		and android_mouse_sequence.consumed_intent == "discard_hud_open"
	)
	scene.call("_on_discard_overlay_gui_input", android_touch_echo)
	var mouse_first_popup_stayed_open := (
		discard_overlay != null
		and discard_overlay.visible
	)
	if mouse_first_popup_stayed_open:
		scene.call("_close_discard_collection_viewer", "android_mouse_first_test")

	# Android forced portrait renders the battle through a rotated landscape
	# viewport. Reproduce that transform and feed the native viewport coordinate,
	# not the already-converted portrait coordinate.
	var rotated_physical_size := Vector2(1600, 900)
	var rotated_logical_size := Vector2(900, 1600)
	scene.call(
		"_apply_battle_canvas_transform",
		true,
		rotated_physical_size,
		rotated_logical_size
	)
	var panel_battle_rect: Rect2 = scene.call(
		"_control_rect_in_battle_local",
		discard_panel
	)
	var panel_battle_center := panel_battle_rect.get_center()
	var rotated_screen_position := Vector2(
		rotated_physical_size.x - panel_battle_center.y,
		panel_battle_center.x
	)
	var rotated_native_press := InputEventScreenTouch.new()
	rotated_native_press.index = 0
	rotated_native_press.pressed = true
	rotated_native_press.position = rotated_screen_position
	var rotated_touch_handled := bool(
		scene.call("_try_handle_battle_hud_touch_input", rotated_native_press)
	)
	var rotated_touch_popup_opened := (
		discard_overlay != null
		and discard_overlay.visible
	)
	if rotated_touch_popup_opened:
		scene.call("_close_discard_collection_viewer", "rotated_viewport_touch_test")

	# Godot Android can also deliver ScreenTouch after the OS has already rotated
	# it into portrait coordinates even though get_viewport_rect() is landscape.
	var post_rotation_native_press := InputEventScreenTouch.new()
	post_rotation_native_press.index = 0
	post_rotation_native_press.pressed = true
	post_rotation_native_press.position = panel_battle_center
	var post_rotation_touch_handled := bool(
		scene.call("_try_handle_battle_hud_touch_input", post_rotation_native_press)
	)
	var post_rotation_touch_popup_opened := (
		discard_overlay != null
		and discard_overlay.visible
	)
	var gsm_created := gsm != null
	var discard_panel_found := discard_panel != null
	var discard_caption_found := discard_caption != null
	var preview_hit_available := preview_hit_rect.has_area()

	scene.queue_free()
	await tree.process_frame
	GameManager.current_mode = previous_mode
	GameManager.selected_deck_ids = previous_ids
	GameManager.set("_deck_training_launch", previous_launch)
	return run_checks([
		assert_true(gsm_created, "Normal battle should create its production game state machine"),
		assert_true(discard_panel_found, "Normal battle should expose the visible discard HUD panel"),
		assert_true(discard_caption_found, "Normal battle should expose the visible discard HUD caption"),
		assert_true(click_inside_panel, "The regression click should land inside the visible discard HUD panel"),
		assert_true(caption_popup_opened, "A physical click on the normal battle discard caption must open the collection popup"),
		assert_true(preview_hit_available, "The discard card preview should occupy a visible part of the discard HUD"),
		assert_true(preview_popup_opened, "A physical click on the normal battle discard card preview must open the collection popup"),
		assert_true(native_touch_handled, "The scene-level native touch fallback must own a discard HUD press"),
		assert_true(native_touch_popup_opened, "A native Android touch on the discard HUD must open the collection popup"),
		assert_true(logical_touch_handled, "Canvas-stretched native touches must hit the HUD in Godot logical coordinates"),
		assert_true(logical_touch_popup_opened, "A logical viewport touch must open the discard popup without applying physical canvas scale"),
		assert_true(android_open_sequence_claimed, "Opening the discard popup must claim Android's leading compatibility-mouse sequence"),
		assert_true(
			android_touch_was_merged,
			"Android's following ScreenTouch press must merge into the leading compatibility-mouse sequence (phase=%s mouse_state_before_open=%s mouse_state_after_open=%s mouse_state=%s)"
			% [
				str(android_touch_result.get("phase", "")),
				android_mouse_state_before_open,
				android_mouse_state_after_open,
				android_mouse_sequence.state if android_mouse_sequence != null else "null",
			]
		),
		assert_true(mouse_first_popup_stayed_open, "Android's mouse-first touch echo must not immediately close the discard popup it just opened"),
		assert_true(rotated_touch_handled, "Forced portrait must convert the native landscape touch into battle-local HUD coordinates"),
		assert_true(rotated_touch_popup_opened, "A native Android touch must open the discard popup through the rotated portrait canvas"),
		assert_true(post_rotation_touch_handled, "Forced portrait must accept Android touch coordinates already rotated by the OS"),
		assert_true(post_rotation_touch_popup_opened, "Post-rotation native Android coordinates must open the discard popup"),
	])


func test_discard_hud_openers_follow_current_view_player_after_handover() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	scene.set("_discard_overlay", scene.find_child("DiscardOverlay", true, false))
	scene.set("_discard_title", scene.find_child("DiscardTitle", true, false))
	scene.set("_discard_list", scene.find_child("DiscardList", true, false))
	scene.set("_discard_close_btn", scene.find_child("DiscardCloseBtn", true, false))
	scene.call("_setup_discard_gallery")

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.discard_pile.append(
			CardInstance.create(_make_pokemon_cd("Player %d Discard" % player_index, 70, "C"), player_index)
		)
		gsm.game_state.players.append(player)
	scene.set("_gsm", gsm)

	# The HUD is wired while player 0 is visible, then a local handover changes
	# which game-state player is rendered on the "my" side of the board.
	scene.set("_view_player", 0)
	scene.call("_bind_discard_hud_openers")
	scene.set("_view_player", 1)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var my_panel := scene.find_child("MyDiscardHudPanel", true, false) as Control
	my_panel.emit_signal("gui_input", click)
	var my_opened_player_index := int(scene.get("_discard_collection_current_player_index"))
	var my_row := scene.get("_discard_card_row") as HBoxContainer
	var my_card := my_row.get_child(0) as BattleCardView if my_row != null and my_row.get_child_count() > 0 else null
	var my_card_name := my_card.card_data.name if my_card != null and my_card.card_data != null else ""

	scene.call("_close_discard_collection_viewer", "handover_regression")
	var opp_panel := scene.find_child("OppDiscardHudPanel", true, false) as Control
	var opponent_click := InputEventMouseButton.new()
	opponent_click.button_index = MOUSE_BUTTON_LEFT
	opponent_click.pressed = true
	opp_panel.emit_signal("gui_input", opponent_click)
	var opponent_opened_player_index := int(scene.get("_discard_collection_current_player_index"))
	var opponent_row := scene.get("_discard_card_row") as HBoxContainer
	var opponent_card := opponent_row.get_child(0) as BattleCardView if opponent_row != null and opponent_row.get_child_count() > 0 else null
	var opponent_card_name := opponent_card.card_data.name if opponent_card != null and opponent_card.card_data != null else ""

	var result := run_checks([
		assert_eq(my_opened_player_index, 1, "The visible self discard HUD must resolve to the current view player after handover"),
		assert_eq(my_card_name, "Player 1 Discard", "The self discard popup must show the cards rendered on the current self side"),
		assert_eq(opponent_opened_player_index, 0, "The visible opponent discard HUD must resolve opposite the current view player after handover"),
		assert_eq(opponent_card_name, "Player 0 Discard", "The opponent discard popup must show the cards rendered on the current opponent side"),
	])
	scene.queue_free()
	return result


func test_battle_scene_discard_viewer_uses_compact_hud_surface() -> String:
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
	for i: int in range(3):
		gsm.game_state.players[0].discard_pile.append(CardInstance.create(_make_pokemon_cd("紧凑弃牌%d" % i, 70, "C"), 0))
	scene.set("_gsm", gsm)
	var close_button := scene.find_child("DiscardCloseBtn", true, false) as Button
	close_button.visible = false
	close_button.disabled = true
	close_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	scene.call("_show_discard_pile", 0, "己方弃牌区")
	var discard_box := scene.find_child("DiscardBox", true, false) as PanelContainer
	var discard_title := scene.find_child("DiscardTitle", true, false) as Label
	var discard_scroll := scene.get("_discard_card_scroll") as ScrollContainer
	var dialog_card_size: Vector2 = scene.get("_dialog_card_size")
	var expected_scroll_height := float(scene.call("_card_gallery_scroll_height", dialog_card_size.y))
	var result := run_checks([
		assert_true(discard_box != null and discard_box.size_flags_vertical == Control.SIZE_SHRINK_CENTER, "Discard viewer should behave like the compact card-choice HUD instead of filling vertical space"),
		assert_true(discard_box != null and discard_box.custom_minimum_size.y <= 1.0, "Discard viewer box should not force the old tall minimum height"),
		assert_true(discard_scroll != null and discard_scroll.size_flags_vertical == Control.SIZE_SHRINK_BEGIN, "Discard viewer card row should shrink to one card lane"),
		assert_true(discard_scroll != null and absf(discard_scroll.custom_minimum_size.y - expected_scroll_height) <= 0.1, "Discard viewer should use a one-row card gallery height without a visible scrollbar lane"),
		assert_true(discard_title != null and discard_title.get_theme_font_size("font_size") >= 18, "Discard viewer title should use readable HUD text"),
		assert_true(close_button != null and close_button.custom_minimum_size.y >= 54.0, "Discard viewer close button should be a touch-sized HUD button"),
		assert_true(close_button != null and close_button.get_theme_font_size("font_size") >= 17, "Discard viewer close button text should be readable"),
		assert_true(close_button != null and close_button.visible and not close_button.disabled, "Opening the discard viewer should always restore an enabled close button"),
		assert_eq(close_button.mouse_filter if close_button != null else Control.MOUSE_FILTER_IGNORE, Control.MOUSE_FILTER_STOP, "Discard viewer close button should capture touch input"),
	])
	scene.queue_free()
	return result


func test_battle_scene_ai_turn_discard_viewer_is_paused_and_always_closable() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var scene := _make_battle_scene_stub()
	var discard_overlay := scene.get("_discard_overlay") as Panel
	var detail_overlay := scene.get("_detail_overlay") as Panel
	var dialog_overlay := scene.get("_dialog_overlay") as Panel
	var coin_overlay := scene.get("_coin_overlay") as Panel
	detail_overlay.visible = false
	dialog_overlay.visible = false
	coin_overlay.visible = false
	discard_overlay.visible = true
	scene.set("_discard_collection_current_kind", "discard")
	scene.set("_discard_collection_current_player_index", 1)
	scene.set("_discard_collection_current_title", "对方弃牌区")

	var ai_paused_while_open: bool = bool(scene.call("_is_ui_blocking_ai"))
	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	var cancel_consumed: bool = bool(scene.call("_try_close_discard_collection_from_cancel", cancel_event))
	var ai_unblocked_after_close: bool = not bool(scene.call("_is_ui_blocking_ai"))

	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(ai_paused_while_open, "Opening an opponent discard viewer during the AI turn must pause AI progression so another overlay cannot cover its exit"),
		assert_true(cancel_consumed, "Android Back/Escape should close the discard viewer"),
		assert_false(discard_overlay.visible, "Closing the discard viewer should hide the modal"),
		assert_eq(str(scene.get("_discard_collection_current_kind")), "", "Closing should clear the collection kind"),
		assert_eq(int(scene.get("_discard_collection_current_player_index")), -1, "Closing should clear the viewed player"),
		assert_eq(str(scene.get("_discard_collection_current_title")), "", "Closing should clear the collection title"),
		assert_true(ai_unblocked_after_close, "Closing the discard viewer should release the AI pause"),
	])


func test_battle_scene_discard_card_right_click_opens_topmost_detail_overlay() -> String:
	var scene := _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)

	var discard_title := Label.new()
	var discard_overlay := Panel.new()
	var detail_overlay := Panel.new()
	detail_overlay.visible = false
	var discard_list := ItemList.new()
	var discard_scroll := ScrollContainer.new()
	var discard_card_row := HBoxContainer.new()
	var discard_utility_row := HBoxContainer.new()
	scene.add_child(discard_overlay)
	scene.add_child(detail_overlay)
	scene.set("_discard_title", discard_title)
	scene.set("_discard_overlay", discard_overlay)
	scene.set("_detail_overlay", detail_overlay)
	scene.set("_detail_title", Label.new())
	scene.set("_detail_content", RichTextLabel.new())
	scene.set("_discard_list", discard_list)
	scene.set("_discard_card_scroll", discard_scroll)
	scene.set("_discard_card_row", discard_card_row)
	scene.set("_discard_utility_row", discard_utility_row)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	gsm.game_state.players[0].discard_pile.append(CardInstance.create(_make_pokemon_cd("Discard Detail Target", 70, "C"), 0))

	scene.call("_show_discard_pile", 0, "己方弃牌区")
	var card_view := discard_card_row.get_child(0) as BattleCardView if discard_card_row.get_child_count() > 0 else null
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	if card_view != null:
		card_view.call("_gui_input", right_click)

	return run_checks([
		assert_not_null(card_view, "Discard viewer should render discard cards as clickable card previews"),
		assert_true(detail_overlay.visible, "Right-clicking a discard card should open card detail"),
		assert_true(detail_overlay.z_index > discard_overlay.z_index, "Card detail overlay should render above the discard viewer overlay"),
		assert_true(detail_overlay.get_index() > discard_overlay.get_index(), "Card detail overlay should be moved to the front among root overlays"),
	])


func test_battle_scene_discard_item_list_right_click_opens_card_detail() -> String:
	var scene := _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)

	var discard_overlay := Panel.new()
	var detail_overlay := Panel.new()
	detail_overlay.visible = false
	var discard_list := ItemList.new()
	scene.add_child(discard_overlay)
	scene.add_child(detail_overlay)
	scene.set("_discard_title", Label.new())
	scene.set("_discard_overlay", discard_overlay)
	scene.set("_detail_overlay", detail_overlay)
	scene.set("_detail_title", Label.new())
	scene.set("_detail_content", RichTextLabel.new())
	scene.set("_discard_list", discard_list)
	scene.set("_discard_card_scroll", null)
	scene.set("_discard_card_row", null)
	scene.set("_discard_utility_row", null)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	gsm.game_state.players[0].discard_pile.append(CardInstance.create(_make_pokemon_cd("Fallback Detail Target", 70, "C"), 0))

	scene.call("_show_discard_pile", 0, "己方弃牌区")
	scene.call("_on_discard_list_item_clicked", 0, Vector2.ZERO, MOUSE_BUTTON_RIGHT)

	return run_checks([
		assert_eq(discard_list.item_count, 1, "Fallback discard list should keep a visible card row"),
		assert_true(detail_overlay.visible, "Right-clicking a fallback discard list item should open card detail"),
		assert_true(detail_overlay.z_index > discard_overlay.z_index, "Fallback card detail should also render above the discard viewer"),
	])


func test_battle_scene_llm_wait_hud_uses_model_specific_copy() -> String:
	var scene := _make_battle_scene_stub()
	var deepseek_text := str(scene.call("_llm_wait_hud_text_for_model", "deepseek/deepseek-v4-pro", 6, 12, 3))
	var qwen_max_text := str(scene.call("_llm_wait_hud_text_for_model", "qwen/qwen3.7-max", 4, 8, 2))
	var qwen_text := str(scene.call("_llm_wait_hud_text_for_model", "qwen/qwen3.7-plus", 3, 5, 1))
	var gpt_text := str(scene.call("_llm_wait_hud_text_for_model", "gpt-5.5", 9, 1, 4))

	return run_checks([
		assert_str_contains(deepseek_text, "DeepSeek V4 Pro", "LLM wait HUD should show the concrete DeepSeek model"),
		assert_str_contains(deepseek_text, "正在思考中", "DeepSeek wait HUD should use the thinking copy"),
		assert_false(deepseek_text.contains("AI thinking"), "LLM wait HUD should no longer use the old English copy"),
		assert_str_contains(qwen_max_text, "Qwen 3.7 Max", "LLM wait HUD should show Qwen Max model names"),
		assert_str_contains(qwen_text, "Qwen 3.7 Plus", "LLM wait HUD should show Qwen Plus model names"),
		assert_str_contains(qwen_text, "正在排兵布阵", "Qwen wait HUD should use a strategy-flavored copy"),
		assert_str_contains(gpt_text, "GPT-5.5", "LLM wait HUD should show GPT model names"),
		assert_str_contains(gpt_text, "第 9 回合", "LLM wait HUD should keep turn context"),
		assert_false(gpt_text.contains("（") or gpt_text.contains("）"), "LLM wait HUD should avoid full-width parentheses for Android glyph compatibility"),
	])


func test_battle_scene_zeus_help_moves_selected_cards_without_consuming_vstar() -> String:
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.vstar_power_used = [false, false]
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		for di: int in 3:
			player.deck.append(CardInstance.create(_make_pokemon_cd("Deck %d-%d" % [pi, di], 60, "C"), pi))
		gsm.game_state.players.append(player)

	CardInstance.reset_id_counter()
	var deck_a := CardInstance.create(_make_trainer_cd("DeckA", "Item", ""), 0)
	var deck_b := CardInstance.create(_make_trainer_cd("DeckB", "Supporter", ""), 0)
	var deck_c := CardInstance.create(_make_pokemon_cd("DeckC", 70, "C"), 0)
	gsm.game_state.players[0].deck = [deck_a, deck_b, deck_c]
	var dialog_cards: Array = gsm.game_state.players[0].deck.duplicate()

	var chosen: Array[CardInstance] = scene._resolve_zeus_help_selected_cards(0, dialog_cards, PackedInt32Array([1, 2]))
	scene._apply_zeus_help(0, chosen)

	return run_checks([
		assert_eq(chosen.size(), 2, "宙斯帮我应解析出两张被选中的牌"),
		assert_true(deck_b in gsm.game_state.players[0].hand and deck_c in gsm.game_state.players[0].hand, "宙斯帮我应将选中的牌加入手牌"),
		assert_true(deck_a in gsm.game_state.players[0].deck, "未选中的牌应留在牌库"),
		assert_false(gsm.game_state.vstar_power_used[0], "宙斯帮我不应消耗 VSTAR 次数"),
	])


func test_battle_scene_send_out_uses_field_slot_choice() -> String:
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		for di: int in 3:
			player.deck.append(CardInstance.create(_make_pokemon_cd("Deck %d-%d" % [pi, di], 60, "C"), pi))
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 80, "C"), 0))
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	scene.call("_show_send_out_dialog", 0)

	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "send_out", "替换上场应保留 send_out pending choice"),
		assert_eq(str(scene.get("_field_interaction_mode")), "slot_select", "替换上场应进入场上 slot 选择模式"),
	])


func test_battle_scene_retreat_uses_field_slot_choice() -> String:
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		for di_amp: int in 3:
			player.deck.append(CardInstance.create(_make_pokemon_cd("Amp Deck %d-%d" % [pi, di_amp], 60, "C"), pi))
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Retreat 1", "C"), 0))
	gsm.game_state.players[0].active_pokemon = active

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 80, "C"), 0))
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	scene.call("_show_retreat_dialog", 0)

	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "retreat_bench", "Retreat should keep retreat_bench pending choice"),
		assert_eq(str(scene.get("_field_interaction_mode")), "slot_select", "Retreat should use field slot selection"),
	])


func test_battle_scene_retreat_with_extra_energy_requires_energy_choice() -> String:
	var scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Retreat 1", "C"), 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Retreat 2", "C"), 0))
	gsm.game_state.players[0].active_pokemon = active

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	gsm.game_state.players[0].bench = [bench_a]

	scene.call("_show_retreat_dialog", 0)

	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "retreat_energy", "Retreat with extra Energy should ask the player to choose the discard first"),
		assert_true((scene.get("_dialog_overlay") as Panel).visible, "Retreat Energy selection should use the dialog overlay"),
		assert_eq((scene.get("_dialog_items_data") as Array).size(), 2, "The retreat Energy prompt should include every attached Energy card"),
		assert_eq(str(scene.get("_field_interaction_mode")), "", "Bench slot selection should wait until Energy is chosen"),
	])


func test_battle_scene_retreat_uses_player_selected_energy_cards() -> String:
	var scene = _make_battle_scene_stub()
	var gsm := SpyRetreatGameStateMachine.new()
	gsm.game_state = GameState.new()
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	var energy_a := CardInstance.create(_make_energy_cd("Retreat A", "C"), 0)
	var energy_b := CardInstance.create(_make_energy_cd("Retreat B", "C"), 0)
	active.attached_energy.append(energy_a)
	active.attached_energy.append(energy_b)
	gsm.game_state.players[0].active_pokemon = active

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	gsm.game_state.players[0].bench = [bench_a]

	scene.call("_show_retreat_dialog", 0)
	scene.call("_handle_dialog_choice", PackedInt32Array([1]))
	scene.call("_handle_field_slot_select_index", 0)

	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "", "Retreat flow should resolve after the bench target is chosen"),
		assert_eq(gsm.retreat_calls, 1, "Retreat confirmation should call GameStateMachine.retreat exactly once"),
		assert_eq(gsm.last_energy_to_discard.size(), 1, "Retreat should discard exactly the selected Energy card"),
		assert_eq(gsm.last_energy_to_discard[0], energy_b, "Retreat should pass the player-selected Energy card into GameStateMachine.retreat"),
		assert_eq(gsm.last_bench_target, bench_a, "Retreat should keep using the selected bench target"),
	])


func test_battle_scene_retreat_real_bench_slot_click_uses_clicked_bench_and_clears_selection() -> String:
	var scene = _make_battle_scene_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active_cd := _make_pokemon_cd("Retreat Active", 70, "C")
	active_cd.retreat_cost = 0
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(active_cd, 0))
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 80, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 90, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	scene.call("_show_retreat_dialog", 0)
	var field_map_before: Dictionary = scene.get("_field_interaction_slot_index_by_id")
	_emit_slot_mouse_click(scene, "my_bench_1", Vector2(520, 520))
	var selected_after: Array = scene.get("_field_interaction_selected_indices")
	var field_map_after: Dictionary = scene.get("_field_interaction_slot_index_by_id")

	return run_checks([
		assert_eq(field_map_before.get("my_bench_0", -1), 0, "Retreat field selection should map the first Bench slot to target index 0"),
		assert_eq(field_map_before.get("my_bench_1", -1), 1, "Retreat field selection should map the clicked second Bench slot to target index 1"),
		assert_eq(gsm.game_state.players[0].active_pokemon, bench_b, "Clicking my_bench_1 during retreat should promote that exact Bench Pokemon"),
		assert_true(bench_a in gsm.game_state.players[0].bench, "The unclicked Bench Pokemon should stay on the Bench"),
		assert_true(active in gsm.game_state.players[0].bench, "The former Active should move to the Bench after retreat"),
		assert_false(bench_b in gsm.game_state.players[0].bench, "The promoted Bench Pokemon should no longer remain in the Bench list"),
		assert_eq(str(scene.get("_pending_choice")), "", "Successful retreat should clear the pending retreat choice"),
		assert_eq(str(scene.get("_field_interaction_mode")), "", "Successful retreat should close field slot selection"),
		assert_eq(selected_after.size(), 0, "Successful retreat should clear field selection highlights"),
		assert_eq(field_map_after.size(), 0, "Successful retreat should clear stale field slot index mapping"),
	])


func test_battle_scene_retreat_touch_bench_slot_mouse_echo_does_not_reopen_selection() -> String:
	var scene = _make_battle_scene_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active_cd := _make_pokemon_cd("Touch Retreat Active", 70, "C")
	active_cd.retreat_cost = 0
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(active_cd, 0))
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Touch Bench A", 80, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Touch Bench B", 90, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	scene.call("_show_retreat_dialog", 0)
	var touch_press := InputEventScreenTouch.new()
	touch_press.pressed = true
	touch_press.index = 0
	touch_press.position = Vector2(520, 520)
	scene.call("_on_slot_input", touch_press, "my_bench_1")
	var touch_release := InputEventScreenTouch.new()
	touch_release.pressed = false
	touch_release.index = 0
	touch_release.position = Vector2(520, 520)
	scene.call("_on_slot_input", touch_release, "my_bench_1")

	var mouse_echo_press := InputEventMouseButton.new()
	mouse_echo_press.button_index = MOUSE_BUTTON_LEFT
	mouse_echo_press.pressed = true
	mouse_echo_press.position = Vector2(20, 20)
	mouse_echo_press.global_position = Vector2(20, 20)
	scene.call("_on_slot_input", mouse_echo_press, "my_bench_1")
	var mouse_echo_release := InputEventMouseButton.new()
	mouse_echo_release.button_index = MOUSE_BUTTON_LEFT
	mouse_echo_release.pressed = false
	mouse_echo_release.position = Vector2(20, 20)
	mouse_echo_release.global_position = Vector2(20, 20)
	scene.call("_on_slot_input", mouse_echo_release, "my_bench_1")

	return run_checks([
		assert_eq(gsm.game_state.players[0].active_pokemon, bench_b, "Touch retreat should promote the touched Bench Pokemon"),
		assert_eq(str(scene.get("_pending_choice")), "", "A post-retreat Android mouse echo should not reopen an action HUD or a field choice"),
		assert_eq(str(scene.get("_field_interaction_mode")), "", "A post-retreat Android mouse echo should leave field selection closed"),
		assert_eq((scene.get("_field_interaction_selected_indices") as Array).size(), 0, "A post-retreat Android mouse echo should not leave target highlights selected"),
	])


func test_battle_scene_retreat_action_hud_same_position_bench_click_selects_underlying_bench() -> String:
	var scene = _make_battle_scene_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active_cd := _make_pokemon_cd("Hud Echo Retreat Active", 70, "C")
	active_cd.retreat_cost = 0
	active_cd.attacks = []
	active_cd.abilities = []
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(active_cd, 0))
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Hud Echo Bench A", 80, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Hud Echo Bench B", 90, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	scene.call("_show_pokemon_action_dialog", 0, active, true)
	var actions: Array = (scene.get("_dialog_data") as Dictionary).get("actions", [])
	var retreat_index := -1
	for i: int in actions.size():
		if actions[i] is Dictionary and str((actions[i] as Dictionary).get("type", "")) == "retreat":
			retreat_index = i
			break
	var retreat_option := _action_hud_option_at_index(scene, retreat_index)
	var action_position := Vector2(520, 520)
	_emit_action_hud_mouse_click(retreat_option, Vector2(20, 20), action_position)

	scene.set("_modal_input_slot_suppress_until_msec", Time.get_ticks_msec() - 1)
	scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec() - 350)
	_emit_slot_mouse_click(scene, "my_bench_0", action_position)

	return run_checks([
		assert_gte(retreat_index, 0, "Regression setup should expose retreat in the action HUD"),
		assert_true(retreat_option != null, "Regression setup should render the retreat action HUD option"),
		assert_eq(gsm.game_state.players[0].active_pokemon, bench_a, "The first same-position Bench click should promote the clicked Pokemon"),
		assert_eq(str(scene.get("_pending_choice")), "", "The Bench click should clear retreat selection"),
		assert_eq(str(scene.get("_field_interaction_mode")), "", "The Bench click should close field selection"),
	])


func test_battle_scene_one_energy_retreat_action_hud_first_bench_click_works() -> String:
	var scene = _make_battle_scene_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active_cd := _make_pokemon_cd("One Energy Retreat Active", 70, "C")
	active_cd.retreat_cost = 1
	active_cd.attacks = []
	active_cd.abilities = []
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(active_cd, 0))
	var retreat_energy := CardInstance.create(_make_energy_cd("Retreat Energy", "C"), 0)
	active.attached_energy.append(retreat_energy)
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("One Energy Bench A", 80, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("One Energy Bench B", 90, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	scene.call("_show_pokemon_action_dialog", 0, active, true)
	var actions: Array = (scene.get("_dialog_data") as Dictionary).get("actions", [])
	var retreat_index := -1
	for i: int in actions.size():
		if actions[i] is Dictionary and str((actions[i] as Dictionary).get("type", "")) == "retreat":
			retreat_index = i
			break
	var retreat_option := _action_hud_option_at_index(scene, retreat_index)
	_emit_action_hud_mouse_click(retreat_option, Vector2(20, 20), Vector2(520, 520))
	var pending_after_retreat_option := str(scene.get("_pending_choice"))
	var mode_after_retreat_option := str(scene.get("_field_interaction_mode"))
	var broad_guard_after_retreat_option := int(scene.get("_modal_input_slot_suppress_until_msec")) > Time.get_ticks_msec()

	scene.set("_modal_input_slot_suppress_until_msec", Time.get_ticks_msec() - 1)
	scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec() - 1000)
	_emit_slot_mouse_click(scene, "my_bench_1", Vector2(720, 520))

	return run_checks([
		assert_gte(retreat_index, 0, "Regression setup should expose retreat in the action HUD"),
		assert_true(retreat_option != null, "Regression setup should render the retreat action HUD option"),
		assert_eq(pending_after_retreat_option, "retreat_bench", "Choosing retreat with exactly one Energy should immediately ask for a Bench target"),
		assert_eq(mode_after_retreat_option, "slot_select", "Choosing retreat should open field slot selection"),
		assert_true(broad_guard_after_retreat_option, "Entering Bench target selection from the action HUD should keep a short slot guard for touch-tail suppression"),
		assert_eq(gsm.game_state.players[0].active_pokemon, bench_b, "The first real Bench click after choosing retreat should promote the clicked Bench Pokemon"),
		assert_false(retreat_energy in active.attached_energy, "The selected retreat Energy should be discarded during retreat"),
		assert_true(retreat_energy in gsm.game_state.players[0].discard_pile, "The selected retreat Energy should move to discard"),
		assert_eq(str(scene.get("_pending_choice")), "", "Successful retreat should clear the pending retreat choice"),
		assert_eq(str(scene.get("_field_interaction_mode")), "", "Successful retreat should close field selection"),
	])


func test_battle_scene_confused_pokemon_can_retreat_from_action_hud() -> String:
	var scene = _make_battle_scene_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active_cd := _make_pokemon_cd("Confused Retreat Active", 70, "C")
	active_cd.retreat_cost = 1
	active_cd.attacks = []
	active_cd.abilities = []
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(active_cd, 0))
	active.set_status("confused", true)
	var retreat_energy := CardInstance.create(_make_energy_cd("Retreat Energy", "C"), 0)
	active.attached_energy.append(retreat_energy)
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Confused Retreat Bench", 80, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	gsm.game_state.players[0].bench = [bench]

	scene.call("_show_pokemon_action_dialog", 0, active, true)
	var actions: Array = (scene.get("_dialog_data") as Dictionary).get("actions", [])
	var retreat_index := -1
	var retreat_enabled := false
	for i: int in actions.size():
		if actions[i] is Dictionary and str((actions[i] as Dictionary).get("type", "")) == "retreat":
			retreat_index = i
			retreat_enabled = bool((actions[i] as Dictionary).get("enabled", false))
			break
	var retreat_option := _action_hud_option_at_index(scene, retreat_index)
	_emit_action_hud_mouse_click(retreat_option, Vector2(20, 20), Vector2(520, 520))
	scene.set("_modal_input_slot_suppress_until_msec", Time.get_ticks_msec() - 1)
	scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec() - 1000)
	_emit_slot_mouse_click(scene, "my_bench_0", Vector2(720, 520))

	return run_checks([
		assert_true(retreat_enabled, "Confusion alone must not disable retreat in the Pokemon action HUD"),
		assert_eq(gsm.game_state.players[0].active_pokemon, bench, "A Confused Pokemon should retreat after paying its retreat cost"),
		assert_false(active.status_conditions.get("confused", false), "Retreating to the Bench should clear Confusion"),
		assert_true(retreat_energy in gsm.game_state.players[0].discard_pile, "Confused retreat should still pay the normal retreat cost"),
	])


func test_battle_scene_one_energy_retreat_action_hud_same_position_mouse_echo_is_blocked_then_click_works() -> String:
	var scene = _make_battle_scene_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active_cd := _make_pokemon_cd("Same Position One Energy Active", 70, "C")
	active_cd.retreat_cost = 1
	active_cd.attacks = []
	active_cd.abilities = []
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(active_cd, 0))
	var retreat_energy := CardInstance.create(_make_energy_cd("Same Position Retreat Energy", "C"), 0)
	active.attached_energy.append(retreat_energy)
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Same Position One Energy Bench A", 80, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Same Position One Energy Bench B", 90, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	scene.call("_show_pokemon_action_dialog", 0, active, true)
	var actions: Array = (scene.get("_dialog_data") as Dictionary).get("actions", [])
	var retreat_index := -1
	for i: int in actions.size():
		if actions[i] is Dictionary and str((actions[i] as Dictionary).get("type", "")) == "retreat":
			retreat_index = i
			break
	var retreat_option := _action_hud_option_at_index(scene, retreat_index)
	var shared_position := Vector2(520, 520)
	_emit_action_hud_mouse_click(retreat_option, Vector2(20, 20), shared_position)
	var pending_after_retreat_option := str(scene.get("_pending_choice"))
	var mode_after_retreat_option := str(scene.get("_field_interaction_mode"))

	_emit_slot_mouse_click(scene, "my_bench_1", shared_position)
	var active_after_echo: PokemonSlot = gsm.game_state.players[0].active_pokemon
	var pending_after_echo := str(scene.get("_pending_choice"))
	var mode_after_echo := str(scene.get("_field_interaction_mode"))
	var energy_discarded_after_echo := retreat_energy in gsm.game_state.players[0].discard_pile

	scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec() - 1000)
	scene.set("_modal_input_slot_suppress_until_msec", 0)
	_emit_slot_mouse_click(scene, "my_bench_1", shared_position)

	return run_checks([
		assert_gte(retreat_index, 0, "Regression setup should expose retreat in the action HUD"),
		assert_true(retreat_option != null, "Regression setup should render the retreat action HUD option"),
		assert_eq(pending_after_retreat_option, "retreat_bench", "Choosing retreat should ask for a Bench target"),
		assert_eq(mode_after_retreat_option, "slot_select", "Choosing retreat should open field slot selection"),
		assert_eq(active_after_echo, active, "The same-position MouseButton echo from the action HUD should not promote an underlying Bench Pokemon"),
		assert_eq(pending_after_echo, "retreat_bench", "Blocking the HUD echo should keep retreat target selection open"),
		assert_eq(mode_after_echo, "slot_select", "Blocking the HUD echo should keep field selection open"),
		assert_false(energy_discarded_after_echo, "Blocking the HUD echo should not discard retreat Energy"),
		assert_eq(gsm.game_state.players[0].active_pokemon, bench_b, "A real Bench click after the echo guard expires should promote the clicked Bench Pokemon"),
		assert_false(retreat_energy in active.attached_energy, "The selected retreat Energy should be discarded during retreat"),
		assert_true(retreat_energy in gsm.game_state.players[0].discard_pile, "The selected retreat Energy should move to discard"),
		assert_eq(str(scene.get("_pending_choice")), "", "Successful retreat should clear the pending retreat choice"),
		assert_eq(str(scene.get("_field_interaction_mode")), "", "Successful retreat should close field selection"),
	])


func test_battle_scene_retreat_same_position_mouse_echo_is_blocked_then_click_works() -> String:
	var scene = _make_battle_scene_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active_cd := _make_pokemon_cd("Same Position Retreat Active", 70, "C")
	active_cd.retreat_cost = 0
	active_cd.attacks = []
	active_cd.abilities = []
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(active_cd, 0))
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Same Position Bench A", 80, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Same Position Bench B", 90, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	scene.call("_show_pokemon_action_dialog", 0, active, true)
	var actions: Array = (scene.get("_dialog_data") as Dictionary).get("actions", [])
	var retreat_index := -1
	for i: int in actions.size():
		if actions[i] is Dictionary and str((actions[i] as Dictionary).get("type", "")) == "retreat":
			retreat_index = i
			break
	var retreat_option := _action_hud_option_at_index(scene, retreat_index)
	var action_position := Vector2(520, 520)
	_emit_action_hud_mouse_click(retreat_option, Vector2(20, 20), action_position)

	_emit_slot_mouse_click(scene, "my_bench_0", action_position)
	var active_after_echo: PokemonSlot = gsm.game_state.players[0].active_pokemon
	var pending_after_echo := str(scene.get("_pending_choice"))
	var mode_after_echo := str(scene.get("_field_interaction_mode"))

	scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec() - 1000)
	scene.set("_modal_input_slot_suppress_until_msec", 0)
	_emit_slot_mouse_click(scene, "my_bench_0", action_position)

	return run_checks([
		assert_gte(retreat_index, 0, "Regression setup should expose retreat in the action HUD"),
		assert_true(retreat_option != null, "Regression setup should render the retreat action HUD option"),
		assert_eq(active_after_echo, active, "The same-position MouseButton echo from the action HUD should not promote an underlying Bench Pokemon"),
		assert_eq(pending_after_echo, "retreat_bench", "Blocking the HUD echo should keep retreat target selection open"),
		assert_eq(mode_after_echo, "slot_select", "Blocking the HUD echo should keep field selection open"),
		assert_eq(gsm.game_state.players[0].active_pokemon, bench_a, "A real tap after the echo guard expires should promote that exact Pokemon"),
		assert_eq(str(scene.get("_pending_choice")), "", "Successful retreat should clear the pending retreat choice"),
		assert_eq(str(scene.get("_field_interaction_mode")), "", "Successful retreat should close field selection"),
	])


func test_battle_scene_one_energy_retreat_touch_same_position_echo_is_blocked_then_tap_works() -> String:
	var scene = _make_battle_scene_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active_cd := _make_pokemon_cd("Touch One Energy Retreat Active", 70, "C")
	active_cd.retreat_cost = 1
	active_cd.attacks = []
	active_cd.abilities = []
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(active_cd, 0))
	var retreat_energy := CardInstance.create(_make_energy_cd("Touch Retreat Energy", "C"), 0)
	active.attached_energy.append(retreat_energy)
	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Touch One Energy Bench A", 80, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Touch One Energy Bench B", 90, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	scene.call("_show_pokemon_action_dialog", 0, active, true)
	var actions: Array = (scene.get("_dialog_data") as Dictionary).get("actions", [])
	var retreat_index := -1
	for i: int in actions.size():
		if actions[i] is Dictionary and str((actions[i] as Dictionary).get("type", "")) == "retreat":
			retreat_index = i
			break
	var retreat_option := _action_hud_option_at_index(scene, retreat_index)
	var touch_position := Vector2(520, 520)
	_emit_action_hud_touch_tap(retreat_option, 0, touch_position)
	var pending_after_retreat_option := str(scene.get("_pending_choice"))
	var mode_after_retreat_option := str(scene.get("_field_interaction_mode"))

	_emit_slot_touch_tap(scene, "my_bench_1", 0, touch_position)
	var active_after_echo: PokemonSlot = gsm.game_state.players[0].active_pokemon
	var pending_after_echo := str(scene.get("_pending_choice"))
	var mode_after_echo := str(scene.get("_field_interaction_mode"))
	var energy_discarded_after_echo := retreat_energy in gsm.game_state.players[0].discard_pile

	scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec() - 1000)
	scene.set("_modal_input_slot_suppress_until_msec", 0)
	_emit_slot_touch_tap(scene, "my_bench_1", 0, touch_position)

	return run_checks([
		assert_gte(retreat_index, 0, "Regression setup should expose retreat in the action HUD"),
		assert_true(retreat_option != null, "Regression setup should render the retreat action HUD option"),
		assert_eq(pending_after_retreat_option, "retreat_bench", "Choosing retreat with exactly one Energy should immediately ask for a Bench target"),
		assert_eq(mode_after_retreat_option, "slot_select", "Choosing retreat should open field slot selection"),
		assert_eq(active_after_echo, active, "The same-position Android touch echo from the action HUD should not promote an underlying Bench Pokemon"),
		assert_eq(pending_after_echo, "retreat_bench", "Blocking the touch echo should keep retreat target selection open"),
		assert_eq(mode_after_echo, "slot_select", "Blocking the touch echo should keep field selection open"),
		assert_false(energy_discarded_after_echo, "Blocking the touch echo should not discard retreat Energy"),
		assert_eq(gsm.game_state.players[0].active_pokemon, bench_b, "A real Bench touch after the echo guard expires should promote the touched Bench Pokemon"),
		assert_true(retreat_energy in gsm.game_state.players[0].discard_pile, "The selected retreat Energy should move to discard"),
		assert_eq(str(scene.get("_pending_choice")), "", "Successful retreat should clear the pending retreat choice"),
		assert_eq(str(scene.get("_field_interaction_mode")), "", "Successful retreat should close field selection"),
	])


func test_battle_scene_android_portrait_area_zero_retreat_hud_touch_does_not_select_underlying_bench() -> String:
	var scene = _make_battle_scene_stub()
	scene._setup_ai_for_tests()
	scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active_cd := _make_pokemon_cd("Area Zero Touch Active Rotom", 70, "L")
	active_cd.retreat_cost = 1
	active_cd.attacks = []
	active_cd.abilities = [{"name": "Instant Charge", "text": "Draw until you have 6 cards in your hand."}]
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(active_cd, 0))
	var retreat_energy := CardInstance.create(_make_energy_cd("Area Zero Retreat Energy", "C"), 0)
	active.attached_energy.append(retreat_energy)
	gsm.game_state.players[0].active_pokemon = active

	var bench_slots: Array[PokemonSlot] = []
	for bench_index: int in 8:
		var bench_cd := _make_pokemon_cd("Area Zero Touch Bench %d" % bench_index, 90, "C")
		bench_cd.attacks = []
		bench_cd.abilities = []
		if bench_index == 0:
			bench_cd.mechanic = "ex"
			bench_cd.is_tags = PackedStringArray(["Tera"])
		var bench_slot := PokemonSlot.new()
		bench_slot.pokemon_stack.append(CardInstance.create(bench_cd, 0))
		bench_slots.append(bench_slot)
		gsm.game_state.players[0].bench.append(bench_slot)
	var selected_bench: PokemonSlot = bench_slots[2]

	var zero_cd := _make_trainer_cd("Area Zero Underdepths", "Stadium", "")
	zero_cd.effect_id = EffectAreaZeroUnderdepthsScript.EFFECT_ID
	gsm.game_state.stadium_card = CardInstance.create(zero_cd, 0)
	gsm.game_state.stadium_owner_index = 0

	scene.call("_show_pokemon_action_dialog", 0, active, true)
	var actions: Array = (scene.get("_dialog_data") as Dictionary).get("actions", [])
	var retreat_index := -1
	for i: int in actions.size():
		if actions[i] is Dictionary and str((actions[i] as Dictionary).get("type", "")) == "retreat":
			retreat_index = i
			break
	var retreat_option := _action_hud_option_at_index(scene, retreat_index)
	var shared_position := Vector2(520, 520)
	_emit_action_hud_touch_tap(retreat_option, 0, shared_position)
	var pending_after_retreat_option := str(scene.get("_pending_choice"))
	var mode_after_retreat_option := str(scene.get("_field_interaction_mode"))

	_emit_slot_touch_tap(scene, "my_bench_2", 0, shared_position)
	var active_after_echo: PokemonSlot = gsm.game_state.players[0].active_pokemon
	var pending_after_echo := str(scene.get("_pending_choice"))
	var mode_after_echo := str(scene.get("_field_interaction_mode"))
	var energy_discarded_after_echo := retreat_energy in gsm.game_state.players[0].discard_pile

	scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec() - 1000)
	scene.set("_modal_input_slot_suppress_until_msec", 0)
	_emit_slot_touch_tap(scene, "my_bench_2", 0, Vector2(720, 520))

	return run_checks([
		assert_gte(retreat_index, 0, "Regression setup should expose retreat in the action HUD"),
		assert_true(retreat_option != null, "Regression setup should render the retreat action HUD option"),
		assert_eq(pending_after_retreat_option, "retreat_bench", "Android portrait Area Zero should enter Bench target selection after the HUD retreat action"),
		assert_eq(mode_after_retreat_option, "slot_select", "Android portrait Area Zero should keep field selection open after the HUD retreat action"),
		assert_eq(active_after_echo, active, "The same-position HUD touch echo should not select an underlying Area Zero Bench Pokemon"),
		assert_eq(pending_after_echo, "retreat_bench", "Blocking the Area Zero HUD echo should keep retreat target selection open"),
		assert_eq(mode_after_echo, "slot_select", "Blocking the Area Zero HUD echo should keep field selection open"),
		assert_false(energy_discarded_after_echo, "Blocking the Area Zero HUD echo should not discard retreat Energy"),
		assert_eq(gsm.game_state.players[0].active_pokemon, selected_bench, "A later real Area Zero Bench touch should still complete retreat"),
		assert_true(retreat_energy in gsm.game_state.players[0].discard_pile, "The later real Area Zero Bench touch should discard retreat Energy"),
		assert_eq(str(scene.get("_pending_choice")), "", "Successful Area Zero retreat should clear the pending retreat choice"),
		assert_eq(str(scene.get("_field_interaction_mode")), "", "Successful Area Zero retreat should close field selection"),
	])


func test_battle_scene_retreat_rejects_overpaying_energy_selection() -> String:
	var scene = _make_battle_scene_stub()
	var gsm := SpyRetreatGameStateMachine.new()
	gsm.game_state = GameState.new()
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 120, "C"), 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Retreat A", "C"), 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Retreat B", "C"), 0))
	gsm.game_state.players[0].active_pokemon = active

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	gsm.game_state.players[0].bench = [bench_a]

	scene.call("_show_retreat_dialog", 0)
	scene.call("_handle_dialog_choice", PackedInt32Array([0, 1]))

	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "retreat_energy", "Overpaying retreat Energy should keep the flow on the Energy selection step"),
		assert_eq(str(scene.get("_field_interaction_mode")), "", "Overpaying retreat Energy should not advance to bench selection"),
		assert_eq(gsm.retreat_calls, 0, "Overpaying retreat Energy should not call GameStateMachine.retreat"),
	])


func test_battle_scene_pokemon_action_dialog_uses_hud_cards_with_full_text() -> String:
	var scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene._gsm = gsm
	scene._view_player = 0

	var card_data := _make_pokemon_cd("HUD测试宝可梦", 120, "R")
	card_data.effect_id = "hud_action_test_ability"
	card_data.abilities = [{"name": "热血补给", "text": "自己的回合时可使用。查看自己的牌库，选择 1 张基本能量加入手牌，然后重洗牌库。"}]
	card_data.attacks = [{
		"name": "烈焰冲击",
		"cost": "RC",
		"damage": "80",
		"text": "将这只宝可梦身上的 1 个能量丢弃。若对手的战斗宝可梦为宝可梦ex，追加 80 点伤害。",
		"is_vstar_power": false,
	}]
	gsm.effect_processor.register_effect(card_data.effect_id, AbilityRunAwayDrawScript.new())
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(card_data, 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Fire", "R"), 0))
	active.attached_energy.append(CardInstance.create(_make_energy_cd("Colorless", "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench", 70, "C"), 0))
	gsm.game_state.players[0].bench = [bench]
	gsm.game_state.players[0].deck.append(CardInstance.create(_make_energy_cd("Deck Fire", "R"), 0))
	gsm.game_state.players[1].active_pokemon = PokemonSlot.new()
	gsm.game_state.players[1].active_pokemon.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target", 100, "C"), 1))

	scene.call("_show_pokemon_action_dialog", 0, active, true)
	var data: Dictionary = scene.get("_dialog_data")
	var action_items: Array = data.get("action_items", [])
	var first_action: Dictionary = action_items[0] if action_items.size() > 0 and action_items[0] is Dictionary else {}
	var second_action: Dictionary = action_items[1] if action_items.size() > 1 and action_items[1] is Dictionary else {}
	var scroll: ScrollContainer = scene.get("_dialog_card_scroll")
	var list: ItemList = scene.get("_dialog_list")
	var confirm: Button = scene.get("_dialog_confirm")
	var row: HBoxContainer = scene.get("_dialog_card_row")
	var preview_panel: PanelContainer = row.get_child(0) as PanelContainer if row.get_child_count() > 0 else null
	var preview_card: BattleCardView = preview_panel.find_child("PokemonActionCardView", true, false) as BattleCardView if preview_panel != null else null
	var expected_detail_size: Vector2 = scene.get("_detail_card_size")
	var stack: VBoxContainer = row.get_child(1) as VBoxContainer if row.get_child_count() > 1 else null
	var first_panel: PanelContainer = stack.get_child(0) as PanelContainer if stack != null and stack.get_child_count() > 0 else null
	var first_margin: MarginContainer = first_panel.get_child(0) as MarginContainer if first_panel != null and first_panel.get_child_count() > 0 else null
	var second_panel: PanelContainer = stack.get_child(1) as PanelContainer if stack != null and stack.get_child_count() > 1 else null
	var second_margin: MarginContainer = second_panel.get_child(0) as MarginContainer if second_panel != null and second_panel.get_child_count() > 0 else null
	var second_box: VBoxContainer = second_margin.get_child(0) as VBoxContainer if second_margin != null and second_margin.get_child_count() > 0 else null
	var second_header: HBoxContainer = second_box.get_child(0) as HBoxContainer if second_box != null and second_box.get_child_count() > 0 else null
	var attack_cost_icons: HBoxContainer = null
	if second_header != null:
		for child: Node in second_header.get_children():
			if child is HBoxContainer:
				attack_cost_icons = child
				break
	var three_action_height := scroll.custom_minimum_size.y
	scene.call("_show_pokemon_action_dialog", 0, active, false)
	var single_action_items: Array = (scene.get("_dialog_data") as Dictionary).get("action_items", [])
	var single_action_height := (scene.get("_dialog_card_scroll") as ScrollContainer).custom_minimum_size.y
	card_data.abilities = [
		{"name": "能力1", "text": "效果1"},
		{"name": "能力2", "text": "效果2"},
		{"name": "能力3", "text": "效果3"},
		{"name": "能力4", "text": "效果4"},
		{"name": "能力5", "text": "效果5"},
		{"name": "能力6", "text": "效果6"},
	]
	scene.call("_show_pokemon_action_dialog", 0, active, false)
	var six_action_height := (scene.get("_dialog_card_scroll") as ScrollContainer).custom_minimum_size.y
	var six_action_scroll_mode: int = (scene.get("_dialog_card_scroll") as ScrollContainer).vertical_scroll_mode
	var expected_six_action_height := maxf(474.0, (preview_panel.custom_minimum_size.y if preview_panel != null else 0.0) + 4.0)

	return run_checks([
		assert_eq(str(data.get("presentation", "")), "action_hud", "Pokemon action dialog should use the HUD-card presentation"),
		assert_true(scroll.visible, "Pokemon action HUD should use the card scroll area"),
		assert_false(list.visible, "Pokemon action HUD should hide the old ItemList"),
		assert_false(confirm.visible, "Pokemon action HUD should select by clicking the HUD option"),
		assert_true(preview_panel != null and preview_panel.name == "PokemonActionCardPreview", "Pokemon action HUD should show the Pokemon card on the left"),
		assert_true(preview_card != null, "Pokemon action HUD should render a card preview beside the action list"),
		assert_eq(preview_card.custom_minimum_size if preview_card != null else Vector2.ZERO, scene.get("_detail_card_size"), "Pokemon action card preview should match the card detail preview size"),
		assert_false(bool(preview_card.get("_clickable")) if preview_card != null else true, "Pokemon action card preview should not steal action clicks"),
		assert_eq(str(first_action.get("title", "")), "热血补给", "Ability HUD should show the ability name"),
		assert_true(str(first_action.get("body", "")).contains("选择 1 张基本能量加入手牌"), "Ability HUD should show the full ability text"),
		assert_eq(str(second_action.get("title", "")), "烈焰冲击", "Attack HUD should show the attack name"),
		assert_true(str(second_action.get("body", "")).contains("追加 80 点伤害"), "Attack HUD should show the full attack effect text"),
		assert_false(str(second_action.get("meta", "")).contains("RC"), "Attack HUD meta should not show raw Energy cost letters"),
		assert_eq(attack_cost_icons.get_child_count() if attack_cost_icons != null else 0, 2, "Attack HUD should render one Energy icon per cost symbol"),
		assert_true(attack_cost_icons.get_child(0) is TextureRect if attack_cost_icons != null and attack_cost_icons.get_child_count() > 0 else false, "Attack HUD should render Energy costs as texture icons"),
		assert_true(attack_cost_icons.get_child(1) is TextureRect if attack_cost_icons != null and attack_cost_icons.get_child_count() > 1 else false, "Attack HUD should render Colorless cost as a texture icon"),
		assert_true(three_action_height >= expected_detail_size.y, "Pokemon action HUD should reserve the full detail-card preview height"),
		assert_eq(single_action_items.size(), 1, "Ability-only Pokemon action HUD should contain one option"),
		assert_true(single_action_height >= (preview_panel.custom_minimum_size.y if preview_panel != null else 0.0), "Ability-only Pokemon action HUD should stay tall enough for the card preview"),
		assert_true(absf(six_action_height - expected_six_action_height) < 0.1, "Pokemon action HUD should cap visible action height while keeping the card preview readable"),
		assert_eq(six_action_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO, "Pokemon action HUD should only enable vertical scrolling above five options"),
		assert_eq(first_panel.mouse_filter if first_panel != null else -1, Control.MOUSE_FILTER_STOP, "Whole action HUD option should receive clicks"),
		assert_eq(first_margin.mouse_filter if first_margin != null else -1, Control.MOUSE_FILTER_IGNORE, "Action HUD contents should pass clicks through to the whole option"),
	])


func test_battle_scene_pokemon_action_dialog_shows_attached_energy_cards() -> String:
	var scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene._gsm = gsm
	scene._view_player = 0

	var active_cd := _make_pokemon_cd("Lugia VSTAR", 280, "C")
	active_cd.abilities = []
	active_cd.attacks = [{"name": "Tempest Dive", "cost": "CCCC", "damage": "220", "text": "", "is_vstar_power": false}]
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(active_cd, 0))
	var dte_cd := CardData.new()
	dte_cd.name = "Double Turbo Energy"
	dte_cd.card_type = "Special Energy"
	var vguard_cd := CardData.new()
	vguard_cd.name = "V Guard Energy"
	vguard_cd.card_type = "Special Energy"
	active.attached_energy.append(CardInstance.create(dte_cd, 0))
	active.attached_energy.append(CardInstance.create(vguard_cd, 0))
	active.attached_energy.append(CardInstance.create(vguard_cd, 0))
	gsm.game_state.players[0].active_pokemon = active
	gsm.game_state.players[1].active_pokemon = PokemonSlot.new()
	gsm.game_state.players[1].active_pokemon.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target", 100, "C"), 1))

	scene.call("_show_pokemon_action_dialog", 0, active, true)
	var row: HBoxContainer = scene.get("_dialog_card_row")
	var summary_panel := row.find_child("PokemonActionAttachedEnergySummary", true, false) as PanelContainer if row != null else null
	var summary_label := row.find_child("PokemonActionAttachedEnergyLabel", true, false) as Label if row != null else null
	var preview_panel := row.get_child(0) as PanelContainer if row != null and row.get_child_count() > 0 else null
	var scroll: ScrollContainer = scene.get("_dialog_card_scroll")

	return run_checks([
		assert_true(summary_panel != null and summary_panel.visible, "Pokemon action HUD should show attached Energy names inside the action popup"),
		assert_true(summary_label != null and summary_label.visible, "Attached Energy summary should use a readable text label in the action popup"),
		assert_str_contains(summary_label.text if summary_label != null else "", "Double Turbo Energy", "Attached Energy summary should name Double Turbo Energy"),
		assert_str_contains(summary_label.text if summary_label != null else "", "V Guard Energy x2", "Attached Energy summary should group repeated V Guard Energy cards"),
		assert_true(scroll.custom_minimum_size.y >= (preview_panel.custom_minimum_size.y if preview_panel != null else 0.0), "Action popup scroll area should stay tall enough for the card preview plus Energy summary"),
	])


func test_battle_scene_bench_pokemon_action_dialog_lists_attacks_as_disabled() -> String:
	var scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene._gsm = gsm
	scene._view_player = 0

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active Guard", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = active
	var bench_cd := _make_pokemon_cd("Bench Skill Viewer", 90, "R")
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(bench_cd, 0))
	gsm.game_state.players[0].bench = [bench]
	gsm.game_state.players[1].active_pokemon = PokemonSlot.new()
	gsm.game_state.players[1].active_pokemon.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target", 100, "C"), 1))

	scene.call("_show_pokemon_action_dialog", 0, bench, false)
	var data: Dictionary = scene.get("_dialog_data")
	var actions: Array = data.get("actions", [])
	var action_items: Array = data.get("action_items", [])
	var attack_count := 0
	var disabled_attack_count := 0
	var attack_item_count := 0
	var first_attack_reason := ""
	for action_variant: Variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		if str(action.get("type", "")) != "attack":
			continue
		attack_count += 1
		if not bool(action.get("enabled", true)):
			disabled_attack_count += 1
		if first_attack_reason == "":
			first_attack_reason = str(action.get("reason", ""))
	for item_variant: Variant in action_items:
		if not (item_variant is Dictionary):
			continue
		var item: Dictionary = item_variant
		if str(item.get("type", "")) == "attack":
			attack_item_count += 1

	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "pokemon_action", "Benched Pokemon click should still open the Pokemon action HUD"),
		assert_eq(attack_count, bench_cd.attacks.size(), "Benched Pokemon HUD should list all printed attacks for reading"),
		assert_eq(disabled_attack_count, bench_cd.attacks.size(), "Benched Pokemon attacks should be visible but disabled"),
		assert_eq(attack_item_count, bench_cd.attacks.size(), "Benched Pokemon action cards should include attack text rows"),
		assert_true(first_attack_reason.strip_edges() != "", "Disabled bench attacks should explain why they cannot be used"),
	])


func test_battle_scene_pokemon_action_dialog_shows_disabled_actions_when_none_are_executable() -> String:
	var scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene._gsm = gsm
	scene._view_player = 0

	var passive_cd := _make_pokemon_cd("被动特性宝可梦", 90, "C")
	passive_cd.effect_id = ""
	passive_cd.abilities = [{"name": "在场光环", "text": "只要这只宝可梦在场，某些效果持续生效。"}]
	passive_cd.attacks = []
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(passive_cd, 0))
	gsm.game_state.players[0].bench = [bench]

	scene.call("_show_pokemon_action_dialog", 0, bench, false)
	var data: Dictionary = scene.get("_dialog_data")
	var actions: Array = data.get("actions", [])
	var action_items: Array = data.get("action_items", [])
	var first_action: Dictionary = actions[0] if actions.size() > 0 and actions[0] is Dictionary else {}
	var first_item: Dictionary = action_items[0] if action_items.size() > 0 and action_items[0] is Dictionary else {}

	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "pokemon_action", "Pokemon with no executable action should still open the action dialog"),
		assert_eq(actions.size(), 1, "Passive-only Pokemon should still show its listed ability"),
		assert_eq(str(first_action.get("type", "")), "ability", "Passive-only Pokemon should render the ability as an action row"),
		assert_false(bool(first_action.get("enabled", true)), "Passive-only ability should be disabled instead of hidden"),
		assert_eq(str(first_item.get("title", "")), "在场光环", "Disabled ability row should keep the ability name"),
		assert_false(bool(first_item.get("enabled", true)), "Disabled ability HUD item should render grey"),
	])


func test_battle_scene_pokemon_action_dialog_shows_empty_disabled_row_for_no_text_actions() -> String:
	var scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene._gsm = gsm
	scene._view_player = 0

	var vanilla_cd := _make_pokemon_cd("空白备战宝可梦", 90, "C")
	vanilla_cd.abilities = []
	vanilla_cd.attacks = []
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(vanilla_cd, 0))
	gsm.game_state.players[0].bench = [bench]

	scene.call("_show_pokemon_action_dialog", 0, bench, false)
	var data: Dictionary = scene.get("_dialog_data")
	var actions: Array = data.get("actions", [])
	var action_items: Array = data.get("action_items", [])
	var first_action: Dictionary = actions[0] if actions.size() > 0 and actions[0] is Dictionary else {}

	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "pokemon_action", "Pokemon with no listed actions should still open the action dialog"),
		assert_eq(actions.size(), 1, "Pokemon with no listed actions should show one disabled placeholder"),
		assert_eq(str(first_action.get("type", "")), "noop", "No-action placeholder should be inert"),
		assert_false(bool(first_action.get("enabled", true)), "No-action placeholder should be disabled"),
		assert_eq(str((action_items[0] as Dictionary).get("title", "")) if action_items.size() > 0 and action_items[0] is Dictionary else "", "当前没有可执行行动", "No-action placeholder should explain why the dialog opened"),
	])


func test_battle_scene_disabled_pokemon_action_choice_does_not_open_invalid_overlay() -> String:
	var scene = _make_battle_scene_stub()
	scene.set("_pending_choice", "pokemon_action")
	scene.set("_dialog_data", {
		"player": 0,
		"actions": [{
			"type": "attack",
			"enabled": false,
			"reason": "能量不足，无法使用该招式",
		}],
	})
	scene.call("_handle_dialog_choice", PackedInt32Array([0]))

	var invalid_overlay := scene.get_node_or_null("InvalidActionOverlay")
	var log_text := (scene.get("_log_list") as RichTextLabel).get_parsed_text()

	return run_checks([
		assert_null(invalid_overlay, "Disabled Pokemon action choices should not open the full-screen invalid action overlay"),
		assert_str_contains(log_text, "能量不足", "The disabled action reason should still be recorded in the battle log"),
	])


func test_battle_scene_opponent_pokemon_clicks_open_card_detail() -> String:
	var scene = _make_battle_scene_stub()
	scene.set("_detail_title", Label.new())
	scene.set("_detail_content", RichTextLabel.new())
	scene.set("_detail_overlay", Panel.new())
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene._gsm = gsm
	scene._view_player = 0

	var active_cd := _make_pokemon_cd("对手战斗详情", 120, "L")
	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(active_cd, 1))
	gsm.game_state.players[1].active_pokemon = active
	var bench_cd := _make_pokemon_cd("对手备战详情", 90, "C")
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(bench_cd, 1))
	gsm.game_state.players[1].bench = [bench]

	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	left_click.pressed = true
	scene.call("_on_slot_input", left_click, "opp_active")
	var left_visible := (scene.get("_detail_overlay") as Panel).visible
	var left_title := (scene.get("_detail_title") as Label).text

	(scene.get("_detail_overlay") as Panel).visible = false
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	scene.call("_on_slot_input", right_click, "opp_bench_0")
	var right_visible := (scene.get("_detail_overlay") as Panel).visible
	var right_title := (scene.get("_detail_title") as Label).text

	(scene.get("_detail_overlay") as Panel).visible = false
	scene.set("_field_interaction_mode", "slot_select")
	var blocked_by_field_choice: bool = not bool(scene.call("_try_show_opponent_slot_detail_input", left_click, "opp_active"))

	return run_checks([
		assert_true(left_visible, "Left-clicking an opponent Pokemon should open the card detail overlay"),
		assert_eq(left_title, "对手战斗详情", "Opponent Active detail should show the clicked Pokemon"),
		assert_true(right_visible, "Right-clicking an opponent Pokemon should open the card detail overlay"),
		assert_eq(right_title, "对手备战详情", "Opponent Bench detail should show the clicked Pokemon"),
		assert_true(blocked_by_field_choice, "Opponent Pokemon detail must not steal clicks from field-target selection flows"),
	])


func test_battle_scene_dreepy_rescue_board_retreats_through_manual_click_flow() -> String:
	var scene = _make_battle_scene_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var dreepy_cd: CardData = CardDatabase.get_card("CSV8C", "157")
	var rescue_board_cd: CardData = CardDatabase.get_card("CSV7C", "185")
	var player_state: PlayerState = gsm.game_state.players[0]

	var active := PokemonSlot.new()
	if dreepy_cd != null:
		active.pokemon_stack.append(CardInstance.create(dreepy_cd, 0))
	player_state.active_pokemon = active

	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench", 90, "C"), 0))
	player_state.bench = [bench]

	var rescue_board: CardInstance = null
	if rescue_board_cd != null:
		rescue_board = CardInstance.create(rescue_board_cd, 0)
		player_state.hand.append(rescue_board)

	if rescue_board != null:
		scene.call("_on_hand_card_clicked", rescue_board, PanelContainer.new())
		_emit_slot_mouse_click(scene, "my_active", Vector2(360, 720))

	scene.call("_show_pokemon_action_dialog", 0, active, true)
	var actions: Array = (scene.get("_dialog_data") as Dictionary).get("actions", [])
	var retreat_index: int = -1
	for i: int in actions.size():
		var action: Dictionary = actions[i]
		if str(action.get("type", "")) == "retreat":
			retreat_index = i
			break

	scene.call("_handle_dialog_choice", PackedInt32Array([retreat_index]))
	var retreat_dialog_data: Dictionary = scene.get("_dialog_data")
	var preselect_discard: Array = retreat_dialog_data.get("energy_discard", [])
	scene.call("_handle_field_slot_select_index", 0)

	return run_checks([
		assert_not_null(dreepy_cd, "CSV8C_157 Dreepy should exist in the card database"),
		assert_not_null(rescue_board_cd, "CSV7C_185 Rescue Board should exist in the card database"),
		assert_eq(active.attached_tool, rescue_board, "The manual click flow should actually attach Rescue Board to Dreepy"),
		assert_gte(retreat_index, 0, "The active Pokemon action dialog should include a retreat action"),
		assert_eq(preselect_discard.size(), 0, "A zero-cost Rescue Board retreat should not preselect any Energy to discard"),
		assert_eq(player_state.active_pokemon, bench, "Selecting the Benched Pokemon should complete the retreat in the manual UI flow"),
		assert_true(active in player_state.bench, "The former Active Dreepy should return to the Bench after the retreat"),
		assert_eq(active.attached_tool, rescue_board, "Rescue Board should stay attached after the manual retreat resolves"),
	])


func test_battle_scene_heavy_baton_uses_field_slot_choice() -> String:
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	scene._gsm = gsm
	scene._view_player = 0

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "C"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 80, "C"), 0))
	var bench_targets: Array[PokemonSlot] = [bench_a, bench_b]

	scene.call("_show_heavy_baton_dialog", 0, bench_targets, 2, "Heavy Baton")

	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "heavy_baton_target", "Heavy Baton should keep heavy_baton_target pending choice"),
		assert_eq(str(scene.get("_field_interaction_mode")), "slot_select", "Heavy Baton should use field slot selection"),
	])


func test_exp_share_assignment_keeps_follow_up_prize_prompt() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER

	var scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.POKEMON_CHECK
	scene.set("_gsm", gsm)
	scene.set("_view_player", 1)
	gsm.player_choice_required.connect(scene._on_player_choice_required)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Attacker", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = attacker
	for prize_index: int in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_pokemon_cd("Prize %d" % prize_index, 60, "C"), 0))

	var knocked_out := PokemonSlot.new()
	knocked_out.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Knocked Out Active", 60, "C"), 1))
	knocked_out.damage_counters = 60
	var energy_a := CardInstance.create(_make_energy_cd("Basic Energy A", "C"), 1)
	var energy_b := CardInstance.create(_make_energy_cd("Basic Energy B", "C"), 1)
	knocked_out.attached_energy.append(energy_a)
	knocked_out.attached_energy.append(energy_b)
	gsm.game_state.players[1].active_pokemon = knocked_out

	var exp_share_target := PokemonSlot.new()
	exp_share_target.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Exp Share Bench", 100, "C"), 1))
	var exp_share_card := CardInstance.create(_make_trainer_cd("Exp. Share", "Tool", ""), 1)
	exp_share_card.card_data.effect_id = "40d67cc66ad153ee1d54c6213c50b4a1"
	exp_share_target.attached_tool = exp_share_card
	gsm.game_state.players[1].bench = [exp_share_target]

	gsm.call("_handle_knockout", 1, knocked_out, true)
	var initial_pending: String = str(scene.get("_pending_choice"))
	var assignments: Array[Dictionary] = [{
		"source": energy_a,
		"target": exp_share_target,
	}]
	scene.call("_commit_exp_share_assignment", assignments)
	var pending_after_commit: String = str(scene.get("_pending_choice"))
	var active_after_commit: PokemonSlot = gsm.game_state.players[1].active_pokemon
	var transferred: bool = energy_a in exp_share_target.attached_energy

	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(initial_pending, "exp_share_target", "Exp. Share knockout should first wait for the energy-transfer prompt"),
		assert_true(transferred, "Exp. Share should move the selected Basic Energy to the target"),
		assert_eq(active_after_commit, null, "The knocked-out Active should be removed before the replacement prompt"),
		assert_eq(pending_after_commit, "take_prize", "Resolving Exp. Share must preserve the follow-up prize prompt instead of clearing all pending choices"),
	])


func test_battle_scene_effect_step_routes_pokemon_slot_choice_to_field_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var target_a := PokemonSlot.new()
	target_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target A", 90, "C"), 0))
	var target_b := PokemonSlot.new()
	target_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target B", 80, "C"), 0))
	gsm.game_state.players[0].bench = [target_a, target_b]

	var dummy_card := CardInstance.create(_make_trainer_cd("Switch Cart", "Item", ""), 0)
	var steps: Array[Dictionary] = [{
		"id": "switch_target",
		"title": "Choose a Benched Pokemon",
		"items": [target_a, target_b],
		"labels": ["A", "B"],
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, dummy_card)

	return run_checks([
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "PokemonSlot effect steps should stay in effect_interaction flow"),
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "PokemonSlot effect steps should route to field slot UI"),
	])


func test_battle_scene_field_assignment_builds_entries_without_dialog_targets() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var bench_a := PokemonSlot.new()
	bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench A", 90, "L"), 0))
	var bench_b := PokemonSlot.new()
	bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench B", 80, "L"), 0))
	gsm.game_state.players[0].bench = [bench_a, bench_b]

	var energy_a := CardInstance.create(_make_energy_cd("Lightning A", "L"), 0)
	var energy_b := CardInstance.create(_make_energy_cd("Lightning B", "L"), 0)
	var dummy_card := CardInstance.create(_make_trainer_cd("Electric Generator", "Item", ""), 0)
	var steps: Array[Dictionary] = [{
		"id": "energy_assignments",
		"title": "Assign Energy",
		"ui_mode": "card_assignment",
		"source_items": [energy_a, energy_b],
		"source_labels": ["Lightning A", "Lightning B"],
		"target_items": [bench_a, bench_b],
		"target_labels": ["Bench A", "Bench B"],
		"min_select": 1,
		"max_select": 2,
		"allow_cancel": true,
	}]

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, dummy_card)
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	battle_scene.call("_handle_field_assignment_target_index", 1)

	var assignments: Array = battle_scene.get("_field_interaction_assignment_entries")
	var first_assignment: Dictionary = assignments[0] if not assignments.is_empty() else {}

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "PokemonSlot assignment targets should route to field assignment UI"),
		assert_eq(assignments.size(), 1, "Choosing a source card and field target should create one assignment entry"),
		assert_eq(first_assignment.get("source"), energy_a, "Assignment should preserve the chosen source card"),
		assert_eq(first_assignment.get("target"), bench_b, "Assignment should preserve the clicked field target"),
	])


func test_field_assignment_source_echo_does_not_cancel_selected_energy() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Charizard ex", 330, "D"), 0))
	gsm.game_state.players[0].active_pokemon = active
	var fire_energy := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var dummy_card := CardInstance.create(_make_trainer_cd("Infernal Reign", "Ability", ""), 0)
	var steps: Array[Dictionary] = [{
		"id": "energy_assignments",
		"title": "Assign Fire Energy",
		"ui_mode": "card_assignment",
		"source_items": [fire_energy],
		"source_labels": ["Fire Energy"],
		"target_items": [active],
		"target_labels": ["Charizard ex"],
		"min_select": 0,
		"max_select": 3,
		"allow_cancel": true,
	}]

	battle_scene.call("_start_effect_interaction", "ability", 0, steps, dummy_card, active, 0)
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	var selected_after_first := int(battle_scene.get("_field_interaction_assignment_selected_source_index"))
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	var selected_after_echo := int(battle_scene.get("_field_interaction_assignment_selected_source_index"))
	var assignments_after_echo: Array = battle_scene.get("_field_interaction_assignment_entries")

	return run_checks([
		assert_eq(selected_after_first, 0, "Selecting a Fire Energy source should mark it as the pending assignment source"),
		assert_eq(selected_after_echo, 0, "A duplicate pointer echo on the same source card should not cancel the selected Fire Energy"),
		assert_eq(assignments_after_echo.size(), 0, "The duplicate source echo should not create or clear assignment paths"),
	])


func test_field_assignment_source_choice_allows_immediate_target_slot_click() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Charizard ex", 330, "D"), 0))
	gsm.game_state.players[0].active_pokemon = active
	var fire_energy := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var dummy_card := CardInstance.create(_make_trainer_cd("Infernal Reign", "Ability", ""), 0)
	var steps: Array[Dictionary] = [{
		"id": "energy_assignments",
		"title": "Assign Fire Energy",
		"ui_mode": "card_assignment",
		"source_items": [fire_energy],
		"source_labels": ["Fire Energy"],
		"target_items": [active],
		"target_labels": ["Charizard ex"],
		"min_select": 0,
		"max_select": 3,
		"allow_cancel": true,
	}]

	battle_scene.call("_start_effect_interaction", "ability", 0, steps, dummy_card, active, 0)
	battle_scene.call("_on_field_assignment_source_chosen", 0)
	var suppression_after_source_click := int(battle_scene.get("_modal_input_slot_suppress_until_msec"))

	var target_click := InputEventMouseButton.new()
	target_click.button_index = MOUSE_BUTTON_LEFT
	target_click.pressed = true
	target_click.position = Vector2(300, 300)
	target_click.global_position = Vector2(300, 300)
	var target_click_consumed := bool(battle_scene.call("_consume_modal_slot_input_if_needed", target_click, "my_active"))
	if not target_click_consumed:
		battle_scene.call("_handle_field_assignment_target_index", 0)

	var assignments_after_target: Array = battle_scene.get("_field_interaction_assignment_entries")
	var first_assignment: Dictionary = assignments_after_target[0] if not assignments_after_target.is_empty() else {}

	return run_checks([
		assert_eq(suppression_after_source_click, 0, "Choosing a Fire Energy source should not arm modal slot suppression for the intended target click"),
		assert_false(target_click_consumed, "The immediate Charizard target click after choosing Fire Energy should not be swallowed"),
		assert_eq(assignments_after_target.size(), 1, "The immediate Charizard target click after choosing Fire Energy should create the assignment"),
		assert_eq(first_assignment.get("target"), active, "The assignment should target the clicked Charizard slot"),
	])


func test_energy_switch_field_assignment_compacts_after_source_and_waits_for_confirm() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var active := PokemonSlot.new()
	active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Source Mon", 120, "G"), 0))
	var bench := PokemonSlot.new()
	bench.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target Mon", 90, "G"), 0))
	gsm.game_state.players[0].active_pokemon = active
	gsm.game_state.players[0].bench = [bench]

	var energy_a := CardInstance.create(_make_energy_cd("Grass Energy", "G"), 0)
	var energy_b := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	active.attached_energy = [energy_a, energy_b]
	var card := CardInstance.create(_make_trainer_cd("Energy Switch", "Item", ""), 0)
	var steps: Array[Dictionary] = [{
		"id": "energy_assignment",
		"title": "Energy Switch",
		"ui_mode": "card_assignment",
		"source_items": [energy_a, energy_b],
		"source_labels": ["Grass Energy", "Fire Energy"],
		"source_groups": [{"slot": active, "energy_indices": [0, 1]}],
		"target_items": [bench],
		"target_labels": ["Target Mon"],
		"min_select": 1,
		"max_select": 1,
		"compact_field_assignment_after_source": true,
		"field_assignment_require_confirm": true,
	}]

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)
	var panel := battle_scene.get("_field_interaction_panel") as PanelContainer
	var scroll := battle_scene.get("_field_interaction_scroll") as ScrollContainer
	var expanded_height := panel.custom_minimum_size.y if panel != null else 0.0
	var scroll_visible_before := scroll != null and scroll.visible

	battle_scene.call("_on_field_assignment_source_chosen", 0)
	var compact_height := panel.custom_minimum_size.y if panel != null else 0.0
	var scroll_visible_after_source := scroll != null and scroll.visible
	var clear_button := battle_scene.get("_field_interaction_clear_btn") as Button
	var confirm_button := battle_scene.get("_field_interaction_confirm_btn") as Button
	var confirm_disabled_after_source := confirm_button != null and confirm_button.disabled

	battle_scene.call("_handle_field_assignment_target_index", 0)
	var assignments: Array = battle_scene.get("_field_interaction_assignment_entries")
	var assignment_count_before_button_down := assignments.size()
	var pending_step_index := int(battle_scene.get("_pending_effect_step_index"))
	var mode_before_button_down := str(battle_scene.get("_field_interaction_mode"))
	if confirm_button != null:
		confirm_button.button_down.emit()
	var mode_after_button_down := str(battle_scene.get("_field_interaction_mode"))

	return run_checks([
		assert_true(scroll_visible_before, "Energy Switch source picker should start expanded"),
		assert_false(scroll_visible_after_source, "Energy Switch should hide the large source picker after a source Energy is selected"),
		assert_true(compact_height < expanded_height, "Energy Switch field assignment panel should shrink after source selection"),
		assert_true(clear_button != null and clear_button.visible, "Compact Energy Switch should allow clearing the selected source"),
		assert_true(confirm_disabled_after_source, "Energy Switch confirm should stay disabled until a target is chosen"),
		assert_eq(assignment_count_before_button_down, 1, "Clicking the target should create a pending path"),
		assert_eq(mode_before_button_down, "assignment", "Energy Switch should wait for explicit confirmation instead of resolving immediately"),
		assert_eq(pending_step_index, 0, "Energy Switch should not advance the effect step before confirm"),
		assert_false(confirm_button.disabled, "Energy Switch confirm should enable after source and target form a path"),
		assert_eq(mode_after_button_down, "", "Explicit field assignment confirmation must complete on button-down without waiting for pointer release"),
	])


func test_battle_scene_boss_orders_routes_real_effect_to_field_slots() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var opp_active := PokemonSlot.new()
	opp_active.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Active", 120, "C"), 1))
	gsm.game_state.players[1].active_pokemon = opp_active

	var opp_bench_a := PokemonSlot.new()
	opp_bench_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench A", 90, "C"), 1))
	var opp_bench_b := PokemonSlot.new()
	opp_bench_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Opp Bench B", 80, "C"), 1))
	gsm.game_state.players[1].bench = [opp_bench_a, opp_bench_b]

	var effect := EffectBossOrdersScript.new()
	var card := CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "slot_select", "Boss's Orders should route to field slot selection"),
		assert_eq(int((battle_scene.get("_field_interaction_data") as Dictionary).get("items", []).size()), 2, "Boss's Orders should expose opponent bench targets on the field"),
	])


func test_battle_scene_penny_active_target_advances_to_replacement_choice_and_resolves() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	var active := PokemonSlot.new()
	var active_card := CardInstance.create(_make_pokemon_cd("Penny Active", 120, "P"), 0)
	active.pokemon_stack.append(active_card)
	var energy := CardInstance.create(_make_energy_cd("Penny Energy", "P"), 0)
	var tool := CardInstance.create(_make_trainer_cd("Penny Tool", "Tool", ""), 0)
	active.attached_energy.append(energy)
	active.attached_tool = tool
	player.active_pokemon = active

	var replacement := PokemonSlot.new()
	replacement.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Penny Bench", 100, "P"), 0))
	player.bench = [replacement]

	var penny := CardInstance.create(_make_trainer_cd("Penny", "Supporter", ""), 0)
	penny.card_data.effect_id = "9fb5f53c9952d10b4fe26508ecbc644a"
	player.hand = [penny]

	battle_scene.call("_try_play_trainer_with_interaction", 0, penny)
	var first_pending: String = str(battle_scene.get("_pending_choice"))
	var first_mode: String = str(battle_scene.get("_field_interaction_mode"))
	battle_scene.call("_handle_field_slot_select_index", 0)
	var second_pending: String = str(battle_scene.get("_pending_choice"))
	var second_mode: String = str(battle_scene.get("_field_interaction_mode"))
	battle_scene.call("_handle_field_slot_select_index", 0)

	return run_checks([
		assert_eq(first_pending, "effect_interaction", "Penny should enter the effect interaction flow"),
		assert_eq(first_mode, "slot_select", "Penny should choose its target through the field slot selector"),
		assert_eq(second_pending, "effect_interaction", "Selecting the Active target should continue to the replacement step"),
		assert_eq(second_mode, "slot_select", "Penny replacement should also use the field slot selector"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "After choosing the replacement, Penny should finish cleanly"),
		assert_eq(player.active_pokemon, replacement, "Penny should promote the selected Benched Pokemon into the Active slot"),
		assert_true(active_card in player.hand and energy in player.hand and tool in player.hand, "Penny should return the chosen Active Pokemon and all attached cards to hand"),
		assert_true(penny in player.discard_pile, "Penny should be discarded after it resolves"),
	])


func test_battle_scene_scoop_up_cyclone_active_target_click_resolves_with_replacement() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	var active := PokemonSlot.new()
	var active_card := CardInstance.create(_make_pokemon_cd("Cyclone Active", 120, "C"), 0)
	active.pokemon_stack.append(active_card)
	var energy := CardInstance.create(_make_energy_cd("Cyclone Energy", "C"), 0)
	var tool := CardInstance.create(_make_trainer_cd("Cyclone Tool", "Tool", ""), 0)
	active.attached_energy.append(energy)
	active.attached_tool = tool
	player.active_pokemon = active

	var replacement := PokemonSlot.new()
	replacement.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Cyclone Bench", 100, "C"), 0))
	player.bench = [replacement]

	var cyclone := CardInstance.create(_make_trainer_cd("Scoop Up Cyclone", "Item", ""), 0)
	cyclone.card_data.effect_id = "c1acc32f6333793f261c9c132435fdfa"
	player.hand = [cyclone]

	var effect := EffectScoopUpCycloneScript.new()
	var steps: Array[Dictionary] = effect.get_interaction_steps(cyclone, gsm.game_state)
	var active_followup: Array[Dictionary] = effect.get_followup_interaction_steps(cyclone, gsm.game_state, {
		"scoop_up_cyclone_target": [active],
	})

	battle_scene.call("_try_play_trainer_with_interaction", 0, cyclone)
	var first_pending: String = str(battle_scene.get("_pending_choice"))
	var first_mode: String = str(battle_scene.get("_field_interaction_mode"))
	var first_map: Dictionary = battle_scene.get("_field_interaction_slot_index_by_id")
	battle_scene.call("_try_handle_field_interaction_slot_click", "my_active", active)
	var second_pending: String = str(battle_scene.get("_pending_choice"))
	var second_mode: String = str(battle_scene.get("_field_interaction_mode"))
	var second_map: Dictionary = battle_scene.get("_field_interaction_slot_index_by_id")
	battle_scene.call("_try_handle_field_interaction_slot_click", "my_bench_0", replacement)

	return run_checks([
		assert_eq(steps.size(), 1, "Scoop Up Cyclone should initially expose only the Pokemon-return target choice"),
		assert_eq(active_followup.size(), 1, "Scoop Up Cyclone should build the replacement choice after the Active target is selected"),
		assert_true(first_map.has("my_active"), "Scoop Up Cyclone should make the Active Pokemon selectable by field slot id"),
		assert_eq(first_pending, "effect_interaction", "Scoop Up Cyclone should enter the effect interaction flow"),
		assert_eq(first_mode, "slot_select", "Scoop Up Cyclone should choose its target through the field slot selector"),
		assert_eq(second_pending, "effect_interaction", "Clicking the Active target should continue to the replacement step"),
		assert_eq(second_mode, "slot_select", "Scoop Up Cyclone replacement should also use the field slot selector"),
		assert_true(second_map.has("my_bench_0"), "Scoop Up Cyclone should make the replacement Bench Pokemon selectable by field slot id"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "After choosing the replacement, Scoop Up Cyclone should finish cleanly"),
		assert_eq(player.active_pokemon, replacement, "Scoop Up Cyclone should promote the selected Benched Pokemon into the Active slot"),
		assert_false(replacement in player.bench, "Scoop Up Cyclone should remove the promoted Pokemon from Bench"),
		assert_true(active_card in player.hand and energy in player.hand and tool in player.hand, "Scoop Up Cyclone should return the chosen Active Pokemon and all attached cards to hand"),
		assert_true(cyclone in player.discard_pile, "Scoop Up Cyclone should be discarded after it resolves"),
	])


func test_battle_scene_electric_generator_routes_real_effect_to_assignment_ui() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var bench_lightning_a := PokemonSlot.new()
	bench_lightning_a.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench L A", 90, "L"), 0))
	var bench_lightning_b := PokemonSlot.new()
	bench_lightning_b.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Bench L B", 80, "L"), 0))
	gsm.game_state.players[0].bench = [bench_lightning_a, bench_lightning_b]

	gsm.game_state.players[0].deck = [
		CardInstance.create(_make_energy_cd("Lightning A", "L"), 0),
		CardInstance.create(_make_pokemon_cd("Reveal Pokemon", 70, "C"), 0),
		CardInstance.create(_make_energy_cd("Lightning B", "L"), 0),
		CardInstance.create(_make_trainer_cd("Reveal Item", "Item", ""), 0),
		CardInstance.create(_make_energy_cd("Grass", "G"), 0),
	]

	var effect := EffectElectricGeneratorScript.new()
	var card := CardInstance.create(_make_trainer_cd("Electric Generator", "Item", ""), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, gsm.game_state)

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, card)

	var data: Dictionary = battle_scene.get("_field_interaction_data")

	return run_checks([
		assert_eq(str(battle_scene.get("_field_interaction_mode")), "assignment", "Electric Generator should route to field assignment UI"),
		assert_eq(int(data.get("source_items", []).size()), 2, "Electric Generator should expose the revealed Lightning Energy cards as source items"),
		assert_eq(int(data.get("target_items", []).size()), 2, "Electric Generator should expose valid Lightning bench targets on the field"),
	])


func test_battle_scene_buddy_poffin_card_dialog_clicks_select_distinct_candidates() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	player.deck = [
		CardInstance.create(_make_pokemon_cd("Poffin A", 60, "G"), 0),
		CardInstance.create(_make_pokemon_cd("Poffin B", 70, "W"), 0),
	]

	var poffin_card := CardInstance.create(_make_trainer_cd("Buddy Poffin", "Item", ""), 0)
	var steps: Array[Dictionary] = [{
		"id": "buddy_poffin_pokemon",
		"title": "选择最多 2 张 HP 不高于 70 的基础宝可梦放入备战区",
		"items": player.deck.duplicate(),
		"labels": ["Poffin A (HP 60)", "Poffin B (HP 70)"],
		"min_select": 0,
		"max_select": 2,
		"allow_cancel": true,
	}]

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, poffin_card)

	var card_row: HBoxContainer = battle_scene.get("_dialog_card_row")
	var first_card := card_row.get_child(0) as BattleCardView
	var second_card := card_row.get_child(1) as BattleCardView
	var left_connections: Array = first_card.left_clicked.get_connections()
	var dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var manual_selected: Array = (battle_scene.get("_dialog_card_selected_indices") as Array).duplicate()
	manual_selected.append(0)
	var toggle_changed := bool(battle_scene.call("_toggle_dialog_card_choice", 0, 2))
	var toggled_selection: Array = (battle_scene.get("_dialog_card_selected_indices") as Array).duplicate()
	(battle_scene.get("_dialog_card_selected_indices") as Array).clear()
	battle_scene.set("_modal_input_slot_suppress_until_msec", 0)
	battle_scene.call("_on_dialog_card_chosen", 0)
	var direct_selection: Array = (battle_scene.get("_dialog_card_selected_indices") as Array).duplicate()
	var modal_suppression_after_first_multi_select := int(battle_scene.get("_modal_input_slot_suppress_until_msec"))
	battle_scene.call("_on_dialog_card_chosen", 1)
	var second_selection: Array = (battle_scene.get("_dialog_card_selected_indices") as Array).duplicate()
	var modal_suppression_after_second_multi_select := int(battle_scene.get("_modal_input_slot_suppress_until_msec"))

	return run_checks([
		assert_true(bool(battle_scene.get("_dialog_card_mode")), "Buddy Poffin should render eligible basics in card dialog mode"),
		assert_eq(card_row.get_child_count(), 2, "Buddy Poffin should show both eligible basics as clickable card choices"),
		assert_eq(left_connections.size(), 1, "Buddy Poffin card choices should wire exactly one left-click handler per card"),
		assert_eq(int(dialog_data.get("max_select", -1)), 2, "Buddy Poffin dialog should preserve max_select=2 in card mode"),
		assert_eq(manual_selected, [0], "BattleScene card selection storage should accept appending a chosen index"),
		assert_true(toggle_changed, "Buddy Poffin card toggle helper should report that selecting the first card succeeded"),
		assert_eq(toggled_selection, [0], "Buddy Poffin card toggle helper should persist the selected index"),
		assert_eq(direct_selection, [0], "Direct dialog choice handling should still select the first Buddy Poffin candidate"),
		assert_eq(second_selection, [0, 1], "Clicking a second Buddy Poffin candidate should add the distinct second entry"),
		assert_eq(modal_suppression_after_first_multi_select, 0, "Multi-select card dialogs should not arm modal slot suppression while the dialog remains open"),
		assert_eq(modal_suppression_after_second_multi_select, 0, "Consecutive multi-select card taps should not be swallowed by modal slot suppression"),
	])


func test_portrait_arven_second_search_ignores_first_confirm_echo_and_resolves() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	var arven := CardInstance.create(_make_trainer_cd("Arven", "Supporter", ""), 0)
	arven.card_data.effect_id = "5bdbc985f9aa2e6f248b53f6f35d1d37"
	var item := CardInstance.create(_make_trainer_cd("Arven Item", "Item", ""), 0)
	var pokemon := CardInstance.create(_make_pokemon_cd("Visible Pokemon", 90, "C"), 0)
	var tool := CardInstance.create(_make_trainer_cd("Arven Tool", "Tool", ""), 0)
	player.hand = [arven]
	player.deck = [item, pokemon, tool]

	battle_scene.call("_try_play_trainer_with_interaction", 0, arven)
	var dialog_controller: RefCounted = battle_scene.get("_battle_dialog_controller")
	var item_dialog_data: Dictionary = battle_scene.get("_dialog_data").duplicate(true)
	dialog_controller.call("on_library_search_candidate_pressed", battle_scene, 0)

	var confirm_pos := Vector2(420, 760)
	var confirm_press := InputEventMouseButton.new()
	confirm_press.button_index = MOUSE_BUTTON_LEFT
	confirm_press.pressed = true
	confirm_press.position = confirm_pos
	confirm_press.global_position = confirm_pos
	battle_scene.call("_on_dialog_confirm_input", confirm_press)
	battle_scene.call("_on_dialog_confirm_button_down")
	battle_scene.call("_on_dialog_confirm")

	var tool_step_index := int(battle_scene.get("_pending_effect_step_index"))
	var tool_step: Dictionary = (battle_scene.get("_pending_effect_steps") as Array)[tool_step_index]
	var tool_dialog_data: Dictionary = battle_scene.get("_dialog_data").duplicate(true)
	battle_scene.call("_on_dialog_confirm_input", confirm_press)
	battle_scene.call("_on_dialog_confirm_button_down")
	battle_scene.call("_on_dialog_confirm")
	var still_waiting_after_echo := (
		str(battle_scene.get("_pending_choice")) == "effect_interaction"
		and int(battle_scene.get("_pending_effect_step_index")) == tool_step_index
		and arven in player.hand
	)

	dialog_controller.call("on_library_search_candidate_pressed", battle_scene, 0)
	var fresh_confirm_press := InputEventMouseButton.new()
	fresh_confirm_press.button_index = MOUSE_BUTTON_LEFT
	fresh_confirm_press.pressed = true
	fresh_confirm_press.position = Vector2(520, 760)
	fresh_confirm_press.global_position = Vector2(520, 760)
	battle_scene.call("_on_dialog_confirm_input", fresh_confirm_press)
	battle_scene.call("_on_dialog_confirm_button_down")
	battle_scene.call("_on_dialog_confirm")

	return run_checks([
		assert_eq(item_dialog_data.get("card_indices", []), [0, -1, -1], "Arven Item search should show the full deck and only enable Item cards"),
		assert_eq(str(tool_step.get("id", "")), "search_tool", "Confirming Arven's Item should open the Tool search"),
		assert_eq(tool_dialog_data.get("card_indices", []), [-1, -1, 0], "Arven Tool search should keep the full deck visible and only enable Tool cards"),
		assert_true(still_waiting_after_echo, "The Android mouse echo from Arven's first confirm must not dismiss the Tool search"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "A fresh Tool choice should finish Arven's interaction"),
		assert_true(arven in player.discard_pile, "Arven should be consumed after both explicit searches finish"),
		assert_true(item in player.hand, "Arven should move the explicitly selected Item to hand"),
		assert_true(tool in player.hand, "Arven should move the explicitly selected Tool to hand"),
		assert_true(pokemon in player.deck, "Arven must leave visible-only Pokemon cards in the deck"),
	])


func test_portrait_ultra_ball_search_step_does_not_arm_candidate_release_fallback() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item", ""), 0)
	ultra_ball.card_data.effect_id = "a337ed34a45e63c6d21d98c3d8e0cb6e"
	var discard_a := CardInstance.create(_make_trainer_cd("Discard A", "Item", ""), 0)
	var discard_b := CardInstance.create(_make_trainer_cd("Discard B", "Item", ""), 0)
	player.hand = [ultra_ball, discard_a, discard_b]
	player.deck = [
		CardInstance.create(_make_pokemon_cd("Search Pokemon", 90, "C"), 0),
		CardInstance.create(_make_trainer_cd("Visible Item", "Item", ""), 0),
	]

	var steps: Array[Dictionary] = EffectUltraBall.new().get_interaction_steps(ultra_ball, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, ultra_ball)
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0, 1]))

	var current_step := (battle_scene.get("_pending_effect_steps") as Array)[int(battle_scene.get("_pending_effect_step_index"))] as Dictionary
	var card_row := battle_scene.get("_dialog_card_row") as HBoxContainer
	var first_card := card_row.get_child(0) as BattleCardView if card_row != null and card_row.get_child_count() > 0 else null
	var second_card := card_row.get_child(1) as BattleCardView if card_row != null and card_row.get_child_count() > 1 else null

	return run_checks([
		assert_eq(str(current_step.get("id", "")), "search_pokemon", "Ultra Ball should wait on the Pokemon search step after paying discard cost"),
		assert_true(bool(battle_scene.get("_dialog_overlay").visible), "Ultra Ball Pokemon search should leave a visible choice dialog open"),
		assert_true(bool(battle_scene.get("_dialog_card_mode")), "Ultra Ball Pokemon search should use the card dialog in portrait"),
		assert_false(first_card != null and first_card.is_primary_release_fallback_armed(), "Fresh Ultra Ball search candidates must not consume the previous touch release"),
		assert_false(second_card != null and second_card.is_primary_release_fallback_armed(), "Visible-only Ultra Ball deck cards must not consume the previous touch release either"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "Ultra Ball should still be waiting for the player's Pokemon search choice"),
		assert_false(ultra_ball in player.discard_pile, "Ultra Ball should not resolve before the search choice is made"),
	])


func test_portrait_ultra_ball_search_step_ignores_previous_dialog_confirm_echo() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item", ""), 0)
	ultra_ball.card_data.effect_id = "a337ed34a45e63c6d21d98c3d8e0cb6e"
	var discard_a := CardInstance.create(_make_trainer_cd("Discard A", "Item", ""), 0)
	var discard_b := CardInstance.create(_make_trainer_cd("Discard B", "Item", ""), 0)
	var search_pokemon := CardInstance.create(_make_pokemon_cd("Search Pokemon", 90, "C"), 0)
	player.hand = [ultra_ball, discard_a, discard_b]
	player.deck = [
		search_pokemon,
		CardInstance.create(_make_trainer_cd("Visible Item", "Item", ""), 0),
	]

	var steps: Array[Dictionary] = EffectUltraBall.new().get_interaction_steps(ultra_ball, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, ultra_ball)
	battle_scene.call("_on_dialog_card_chosen", 0)
	battle_scene.call("_on_dialog_card_chosen", 1)
	battle_scene.call("_on_dialog_confirm")

	battle_scene.call("_on_dialog_confirm")

	var pending_step_index := int(battle_scene.get("_pending_effect_step_index"))
	var current_step := {}
	if pending_step_index >= 0:
		current_step = (battle_scene.get("_pending_effect_steps") as Array)[pending_step_index] as Dictionary

	return run_checks([
		assert_eq(str(current_step.get("id", "")), "search_pokemon", "A stale confirm echo should not advance past Ultra Ball's Pokemon search"),
		assert_true(bool(battle_scene.get("_dialog_overlay").visible), "A stale confirm echo should leave the Pokemon search dialog open"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "Ultra Ball should still be waiting for an explicit Pokemon search choice"),
		assert_false(ultra_ball in player.discard_pile, "Ultra Ball should not resolve from a stale confirm echo"),
		assert_true(search_pokemon in player.deck, "The searched Pokemon should remain in deck until the player makes an explicit choice"),
	])


func test_portrait_ultra_ball_search_step_ignores_same_position_confirm_press_echo() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item", ""), 0)
	ultra_ball.card_data.effect_id = "a337ed34a45e63c6d21d98c3d8e0cb6e"
	var discard_a := CardInstance.create(_make_trainer_cd("Discard A", "Item", ""), 0)
	var discard_b := CardInstance.create(_make_trainer_cd("Discard B", "Item", ""), 0)
	var search_pokemon := CardInstance.create(_make_pokemon_cd("Search Pokemon", 90, "C"), 0)
	player.hand = [ultra_ball, discard_a, discard_b]
	player.deck = [
		search_pokemon,
		CardInstance.create(_make_trainer_cd("Visible Item", "Item", ""), 0),
	]

	var confirm_pos := Vector2(420, 760)
	var confirm_press := InputEventMouseButton.new()
	confirm_press.button_index = MOUSE_BUTTON_LEFT
	confirm_press.pressed = true
	confirm_press.position = confirm_pos
	confirm_press.global_position = confirm_pos

	var steps: Array[Dictionary] = EffectUltraBall.new().get_interaction_steps(ultra_ball, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, ultra_ball)
	battle_scene.call("_on_dialog_card_chosen", 0)
	battle_scene.call("_on_dialog_card_chosen", 1)
	battle_scene.call("_on_dialog_confirm_input", confirm_press)
	battle_scene.call("_on_dialog_confirm_button_down")
	battle_scene.call("_on_dialog_confirm")

	battle_scene.call("_on_dialog_confirm_input", confirm_press)
	battle_scene.call("_on_dialog_confirm_button_down")
	battle_scene.call("_on_dialog_confirm")

	var pending_step_index := int(battle_scene.get("_pending_effect_step_index"))
	var current_step := {}
	if pending_step_index >= 0:
		current_step = (battle_scene.get("_pending_effect_steps") as Array)[pending_step_index] as Dictionary

	return run_checks([
		assert_eq(str(current_step.get("id", "")), "search_pokemon", "A same-position Android mouse press echo should not advance past Ultra Ball's Pokemon search"),
		assert_true(bool(battle_scene.get("_dialog_overlay").visible), "The Pokemon search dialog should stay open after a same-position confirm press echo"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "Ultra Ball should still be waiting after a same-position confirm press echo"),
		assert_false(ultra_ball in player.discard_pile, "Ultra Ball should not resolve from a same-position confirm press echo"),
		assert_true(search_pokemon in player.deck, "The searched Pokemon should remain in deck after the echo is blocked"),
	])


func test_portrait_ultra_ball_search_step_ignores_repeated_same_position_confirm_echoes_then_allows_card_pick() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item", ""), 0)
	ultra_ball.card_data.effect_id = "a337ed34a45e63c6d21d98c3d8e0cb6e"
	var discard_a := CardInstance.create(_make_trainer_cd("Discard A", "Item", ""), 0)
	var discard_b := CardInstance.create(_make_trainer_cd("Discard B", "Item", ""), 0)
	var search_pokemon := CardInstance.create(_make_pokemon_cd("Search Pokemon", 90, "C"), 0)
	player.hand = [ultra_ball, discard_a, discard_b]
	player.deck = [
		search_pokemon,
		CardInstance.create(_make_trainer_cd("Visible Item", "Item", ""), 0),
	]

	var confirm_pos := Vector2(420, 760)
	var confirm_mouse_press := InputEventMouseButton.new()
	confirm_mouse_press.button_index = MOUSE_BUTTON_LEFT
	confirm_mouse_press.pressed = true
	confirm_mouse_press.position = confirm_pos
	confirm_mouse_press.global_position = confirm_pos
	var confirm_touch_press := InputEventScreenTouch.new()
	confirm_touch_press.pressed = true
	confirm_touch_press.position = confirm_pos

	var steps: Array[Dictionary] = EffectUltraBall.new().get_interaction_steps(ultra_ball, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, ultra_ball)
	battle_scene.call("_on_dialog_card_chosen", 0)
	battle_scene.call("_on_dialog_card_chosen", 1)
	battle_scene.call("_on_dialog_confirm_input", confirm_mouse_press)
	battle_scene.call("_on_dialog_confirm_button_down")
	battle_scene.call("_on_dialog_confirm")

	battle_scene.call("_on_dialog_confirm_input", confirm_touch_press)
	battle_scene.call("_on_dialog_confirm_button_down")
	battle_scene.call("_on_dialog_confirm")
	battle_scene.call("_on_dialog_confirm_input", confirm_mouse_press)
	battle_scene.call("_on_dialog_confirm_button_down")
	battle_scene.call("_on_dialog_confirm")

	var pending_step_index := int(battle_scene.get("_pending_effect_step_index"))
	var current_step := {}
	if pending_step_index >= 0:
		current_step = (battle_scene.get("_pending_effect_steps") as Array)[pending_step_index] as Dictionary
	var still_waiting_after_echoes := str(current_step.get("id", "")) == "search_pokemon" and search_pokemon in player.deck and not (ultra_ball in player.discard_pile)

	battle_scene.call("_on_dialog_card_chosen", 0)

	return run_checks([
		assert_true(still_waiting_after_echoes, "Touch plus mouse same-position confirm echoes should both be ignored before an explicit search choice"),
		assert_true(search_pokemon in player.hand, "After echoes are blocked, a real Pokemon card pick should still resolve Ultra Ball"),
		assert_true(ultra_ball in player.discard_pile, "Ultra Ball should discard itself only after the explicit Pokemon search choice"),
		assert_false(search_pokemon in player.deck, "The selected Pokemon should leave the deck after the explicit card pick"),
	])


func test_portrait_ultra_ball_search_step_ignores_delayed_confirm_pressed_without_guard_signal() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item", ""), 0)
	ultra_ball.card_data.effect_id = "a337ed34a45e63c6d21d98c3d8e0cb6e"
	var discard_a := CardInstance.create(_make_trainer_cd("Discard A", "Item", ""), 0)
	var discard_b := CardInstance.create(_make_trainer_cd("Discard B", "Item", ""), 0)
	var search_pokemon := CardInstance.create(_make_pokemon_cd("Search Pokemon", 90, "C"), 0)
	player.hand = [ultra_ball, discard_a, discard_b]
	player.deck = [
		search_pokemon,
		CardInstance.create(_make_trainer_cd("Visible Item", "Item", ""), 0),
	]

	var confirm_pos := Vector2(420, 760)
	var confirm_press := InputEventMouseButton.new()
	confirm_press.button_index = MOUSE_BUTTON_LEFT
	confirm_press.pressed = true
	confirm_press.position = confirm_pos
	confirm_press.global_position = confirm_pos

	var steps: Array[Dictionary] = EffectUltraBall.new().get_interaction_steps(ultra_ball, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, ultra_ball)
	battle_scene.call("_on_dialog_card_chosen", 0)
	battle_scene.call("_on_dialog_card_chosen", 1)
	battle_scene.call("_on_dialog_confirm_input", confirm_press)
	battle_scene.call("_on_dialog_confirm_button_down")
	battle_scene.call("_on_dialog_confirm")

	var search_step_id := ""
	var pending_step_index := int(battle_scene.get("_pending_effect_step_index"))
	if pending_step_index >= 0:
		var current_step := (battle_scene.get("_pending_effect_steps") as Array)[pending_step_index] as Dictionary
		search_step_id = str(current_step.get("id", ""))
	battle_scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec() - 1000)
	battle_scene.call("_on_dialog_confirm")

	return run_checks([
		assert_eq(search_step_id, "search_pokemon", "Precondition: Ultra Ball should be waiting on the Pokemon search step"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "A delayed stale confirm press without a guard signal should not skip the Pokemon search dialog"),
		assert_true(bool((battle_scene.get("_dialog_overlay") as Panel).visible), "The Pokemon search dialog should remain visible after a stale delayed confirm press"),
		assert_false(ultra_ball in player.discard_pile, "Ultra Ball should not resolve from a stale delayed confirm press"),
		assert_false(discard_a in player.discard_pile, "Ultra Ball should not pay the first discard cost before the search step resolves"),
		assert_false(discard_b in player.discard_pile, "Ultra Ball should not pay the second discard cost before the search step resolves"),
		assert_true(search_pokemon in player.deck, "The searched Pokemon should remain in deck until a real search choice"),
		assert_false(search_pokemon in player.hand, "A stale delayed confirm press should not move the searched Pokemon to hand"),
	])


func test_portrait_ultra_ball_search_step_accepts_delayed_confirm_button_down_without_position() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item", ""), 0)
	ultra_ball.card_data.effect_id = "a337ed34a45e63c6d21d98c3d8e0cb6e"
	var discard_a := CardInstance.create(_make_trainer_cd("Discard A", "Item", ""), 0)
	var discard_b := CardInstance.create(_make_trainer_cd("Discard B", "Item", ""), 0)
	var search_pokemon := CardInstance.create(_make_pokemon_cd("Search Pokemon", 90, "C"), 0)
	player.hand = [ultra_ball, discard_a, discard_b]
	player.deck = [
		search_pokemon,
		CardInstance.create(_make_trainer_cd("Visible Item", "Item", ""), 0),
	]

	var confirm_pos := Vector2(420, 760)
	var confirm_press := InputEventMouseButton.new()
	confirm_press.button_index = MOUSE_BUTTON_LEFT
	confirm_press.pressed = true
	confirm_press.position = confirm_pos
	confirm_press.global_position = confirm_pos

	var steps: Array[Dictionary] = EffectUltraBall.new().get_interaction_steps(ultra_ball, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, ultra_ball)
	battle_scene.call("_on_dialog_card_chosen", 0)
	battle_scene.call("_on_dialog_card_chosen", 1)
	battle_scene.call("_on_dialog_confirm_input", confirm_press)
	battle_scene.call("_on_dialog_confirm_button_down")
	battle_scene.call("_on_dialog_confirm")

	var search_step_id := ""
	var pending_step_index := int(battle_scene.get("_pending_effect_step_index"))
	if pending_step_index >= 0:
		var current_step := (battle_scene.get("_pending_effect_steps") as Array)[pending_step_index] as Dictionary
		search_step_id = str(current_step.get("id", ""))
	battle_scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec() - 1000)
	var empty_row := battle_scene.get("_dialog_utility_row") as HBoxContainer
	var empty_button := empty_row.find_child("LibrarySearchEmptySelectionButton", true, false) as Button if empty_row != null else null
	var no_selection_button := battle_scene.get("_dialog_cancel") as Button
	if no_selection_button != null:
		battle_scene.call("_on_dialog_cancel")

	return run_checks([
		assert_eq(search_step_id, "search_pokemon", "Precondition: Ultra Ball should be waiting on the Pokemon search step"),
		assert_null(empty_button, "Portrait Ultra Ball search should not stack a separate empty-selection action above the footer"),
		assert_true(no_selection_button != null and no_selection_button.visible and no_selection_button.text == "不选择", "Portrait Ultra Ball search should reuse the footer cancel slot for no-selection"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "Explicit empty-selection action should resolve the Pokemon search"),
		assert_true(ultra_ball in player.discard_pile, "Ultra Ball should resolve after choosing no Pokemon"),
		assert_true(discard_a in player.discard_pile, "Ultra Ball should still pay the first discard cost"),
		assert_true(discard_b in player.discard_pile, "Ultra Ball should still pay the second discard cost"),
		assert_true(search_pokemon in player.deck, "Choosing no Pokemon should leave the searched Pokemon in deck"),
		assert_false(search_pokemon in player.hand, "Choosing no Pokemon should not move the searched Pokemon to hand"),
	])


func test_portrait_ultra_ball_search_step_accepts_followup_confirm_pressed_after_stale_pressed_blocked() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item", ""), 0)
	ultra_ball.card_data.effect_id = "a337ed34a45e63c6d21d98c3d8e0cb6e"
	var discard_a := CardInstance.create(_make_trainer_cd("Discard A", "Item", ""), 0)
	var discard_b := CardInstance.create(_make_trainer_cd("Discard B", "Item", ""), 0)
	var search_pokemon := CardInstance.create(_make_pokemon_cd("Search Pokemon", 90, "C"), 0)
	player.hand = [ultra_ball, discard_a, discard_b]
	player.deck = [
		search_pokemon,
		CardInstance.create(_make_trainer_cd("Visible Item", "Item", ""), 0),
	]

	var confirm_pos := Vector2(420, 760)
	var confirm_press := InputEventMouseButton.new()
	confirm_press.button_index = MOUSE_BUTTON_LEFT
	confirm_press.pressed = true
	confirm_press.position = confirm_pos
	confirm_press.global_position = confirm_pos

	var steps: Array[Dictionary] = EffectUltraBall.new().get_interaction_steps(ultra_ball, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, ultra_ball)
	battle_scene.call("_on_dialog_card_chosen", 0)
	battle_scene.call("_on_dialog_card_chosen", 1)
	battle_scene.call("_on_dialog_confirm_input", confirm_press)
	battle_scene.call("_on_dialog_confirm_button_down")
	battle_scene.call("_on_dialog_confirm")

	battle_scene.call("_on_dialog_confirm")
	var still_waiting_after_stale := str(battle_scene.get("_pending_choice")) == "effect_interaction" and ultra_ball not in player.discard_pile
	var empty_row := battle_scene.get("_dialog_utility_row") as HBoxContainer
	var empty_button := empty_row.find_child("LibrarySearchEmptySelectionButton", true, false) as Button if empty_row != null else null
	var no_selection_button := battle_scene.get("_dialog_cancel") as Button
	if no_selection_button != null:
		battle_scene.call("_on_dialog_cancel")

	return run_checks([
		assert_true(still_waiting_after_stale, "The first stale confirm press should leave Ultra Ball on the Pokemon search dialog"),
		assert_null(empty_button, "Portrait Ultra Ball search should not recreate a separate empty-selection action after stale confirm suppression"),
		assert_true(no_selection_button != null and no_selection_button.visible and no_selection_button.text == "不选择", "Portrait Ultra Ball search should keep the footer no-selection action after stale confirm suppression"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "Explicit empty-selection action should resolve after stale confirm suppression"),
		assert_true(ultra_ball in player.discard_pile, "Ultra Ball should resolve from explicit empty-selection after the stale press is blocked"),
		assert_true(discard_a in player.discard_pile, "Ultra Ball should still pay the first discard cost"),
		assert_true(discard_b in player.discard_pile, "Ultra Ball should still pay the second discard cost"),
		assert_true(search_pokemon in player.deck, "Choosing no Pokemon should leave the searched Pokemon in deck"),
	])


func test_portrait_ultra_ball_search_step_accepts_no_selection_after_stale_confirm_pressed_blocked() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item", ""), 0)
	ultra_ball.card_data.effect_id = "a337ed34a45e63c6d21d98c3d8e0cb6e"
	var discard_a := CardInstance.create(_make_trainer_cd("Discard A", "Item", ""), 0)
	var discard_b := CardInstance.create(_make_trainer_cd("Discard B", "Item", ""), 0)
	var search_pokemon := CardInstance.create(_make_pokemon_cd("Search Pokemon", 90, "C"), 0)
	player.hand = [ultra_ball, discard_a, discard_b]
	player.deck = [search_pokemon]

	var confirm_pos := Vector2(420, 760)
	var confirm_press := InputEventMouseButton.new()
	confirm_press.button_index = MOUSE_BUTTON_LEFT
	confirm_press.pressed = true
	confirm_press.position = confirm_pos
	confirm_press.global_position = confirm_pos

	var steps: Array[Dictionary] = EffectUltraBall.new().get_interaction_steps(ultra_ball, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, ultra_ball)
	battle_scene.call("_on_dialog_card_chosen", 0)
	battle_scene.call("_on_dialog_card_chosen", 1)
	battle_scene.call("_on_dialog_confirm_input", confirm_press)
	battle_scene.call("_on_dialog_confirm_button_down")
	battle_scene.call("_on_dialog_confirm")

	battle_scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec() - 1000)
	battle_scene.call("_on_dialog_confirm")
	var still_waiting_after_stale := str(battle_scene.get("_pending_choice")) == "effect_interaction" and ultra_ball in player.hand
	var no_selection_button := battle_scene.get("_dialog_cancel") as Button
	battle_scene.call("_on_dialog_cancel")

	return run_checks([
		assert_true(still_waiting_after_stale, "The stale confirm press should not consume Ultra Ball before the no-selection action"),
		assert_true(no_selection_button != null and no_selection_button.text == "不选择", "The portrait footer should identify the action as no-selection instead of cancel"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "No-selection after stale confirm suppression should resolve the Pokemon search"),
		assert_true(ultra_ball in player.discard_pile, "No-selection should finish using Ultra Ball"),
		assert_true(discard_a in player.discard_pile, "No-selection should preserve the first paid discard cost"),
		assert_true(discard_b in player.discard_pile, "No-selection should preserve the second paid discard cost"),
		assert_true(search_pokemon in player.deck, "No-selection should leave the searched Pokemon in the deck"),
	])


func test_portrait_ultra_ball_search_step_accepts_delayed_no_selection_button_down_without_position() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item", ""), 0)
	ultra_ball.card_data.effect_id = "a337ed34a45e63c6d21d98c3d8e0cb6e"
	var discard_a := CardInstance.create(_make_trainer_cd("Discard A", "Item", ""), 0)
	var discard_b := CardInstance.create(_make_trainer_cd("Discard B", "Item", ""), 0)
	var search_pokemon := CardInstance.create(_make_pokemon_cd("Search Pokemon", 90, "C"), 0)
	player.hand = [ultra_ball, discard_a, discard_b]
	player.deck = [search_pokemon]

	var confirm_pos := Vector2(420, 760)
	var confirm_press := InputEventMouseButton.new()
	confirm_press.button_index = MOUSE_BUTTON_LEFT
	confirm_press.pressed = true
	confirm_press.position = confirm_pos
	confirm_press.global_position = confirm_pos

	var steps: Array[Dictionary] = EffectUltraBall.new().get_interaction_steps(ultra_ball, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, ultra_ball)
	battle_scene.call("_on_dialog_card_chosen", 0)
	battle_scene.call("_on_dialog_card_chosen", 1)
	battle_scene.call("_on_dialog_confirm_input", confirm_press)
	battle_scene.call("_on_dialog_confirm_button_down")
	battle_scene.call("_on_dialog_confirm")

	var search_step_id := ""
	var pending_step_index := int(battle_scene.get("_pending_effect_step_index"))
	if pending_step_index >= 0:
		var current_step := (battle_scene.get("_pending_effect_steps") as Array)[pending_step_index] as Dictionary
		search_step_id = str(current_step.get("id", ""))
	var no_selection_button := battle_scene.get("_dialog_cancel") as Button
	battle_scene.set("_modal_input_finished_at_msec", Time.get_ticks_msec() - 1000)
	battle_scene.call("_on_dialog_cancel_button_down")
	battle_scene.call("_on_dialog_cancel")

	return run_checks([
		assert_eq(search_step_id, "search_pokemon", "Precondition: Ultra Ball should be waiting on the Pokemon search step before no-selection"),
		assert_true(no_selection_button != null and no_selection_button.text == "不选择", "The delayed footer action should be labeled as no-selection"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "A delayed no-selection button_down should resolve the Pokemon search"),
		assert_true(ultra_ball in player.discard_pile, "No-selection on the second step should finish using Ultra Ball"),
		assert_true(discard_a in player.discard_pile, "No-selection should preserve the first paid discard cost"),
		assert_true(discard_b in player.discard_pile, "No-selection should preserve the second paid discard cost"),
		assert_true(search_pokemon in player.deck, "No-selection should leave the searched Pokemon in the deck"),
	])


func test_portrait_secret_box_item_step_does_not_arm_candidate_release_fallback() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	var secret_box := CardInstance.create(_make_trainer_cd("Secret Box", "Item", ""), 0)
	secret_box.card_data.effect_id = "e92a86246f44351d023bd4fa271089aa"
	var discard_a := CardInstance.create(_make_trainer_cd("Discard A", "Item", ""), 0)
	var discard_b := CardInstance.create(_make_trainer_cd("Discard B", "Item", ""), 0)
	var discard_c := CardInstance.create(_make_trainer_cd("Discard C", "Item", ""), 0)
	player.hand = [secret_box, discard_a, discard_b, discard_c]
	player.deck = [
		CardInstance.create(_make_trainer_cd("Secret Item", "Item", ""), 0),
		CardInstance.create(_make_pokemon_cd("Visible Pokemon", 90, "C"), 0),
		CardInstance.create(_make_trainer_cd("Secret Tool", "Tool", ""), 0),
		CardInstance.create(_make_trainer_cd("Secret Supporter", "Supporter", ""), 0),
		CardInstance.create(_make_trainer_cd("Secret Stadium", "Stadium", ""), 0),
	]

	var steps: Array[Dictionary] = EffectSecretBox.new().get_interaction_steps(secret_box, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, secret_box)
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0, 1, 2]))

	var current_step := (battle_scene.get("_pending_effect_steps") as Array)[int(battle_scene.get("_pending_effect_step_index"))] as Dictionary
	var card_row := battle_scene.get("_dialog_card_row") as HBoxContainer
	var first_card := card_row.get_child(0) as BattleCardView if card_row != null and card_row.get_child_count() > 0 else null
	var second_card := card_row.get_child(1) as BattleCardView if card_row != null and card_row.get_child_count() > 1 else null

	return run_checks([
		assert_eq(str(current_step.get("id", "")), "search_item", "Secret Box should ask for the Item search immediately after paying its discard cost"),
		assert_true(bool(battle_scene.get("_dialog_overlay").visible), "Secret Box Item search should leave a visible choice dialog open"),
		assert_true(bool(battle_scene.get("_dialog_card_mode")), "Secret Box Item search should use the card dialog in portrait"),
		assert_false(first_card != null and first_card.is_primary_release_fallback_armed(), "Fresh Secret Box Item candidates must not consume the previous touch release"),
		assert_false(second_card != null and second_card.is_primary_release_fallback_armed(), "Visible-only Secret Box deck cards must not consume the previous touch release either"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "Secret Box should still be waiting for the player's Item search choice"),
		assert_false(secret_box in player.discard_pile, "Secret Box should not resolve before the search choices are made"),
	])


func test_portrait_card_search_dialog_restores_large_horizontal_scrollbar() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	for i: int in 8:
		player.deck.append(CardInstance.create(_make_pokemon_cd("Search Target %d" % i, 60, "C"), 0))

	var search_card := CardInstance.create(_make_trainer_cd("Nest Ball", "Item", ""), 0)
	var steps: Array[Dictionary] = [{
		"id": "basic_pokemon",
		"title": "Select a Basic Pokemon",
		"items": player.deck.duplicate(),
		"labels": [],
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, search_card)

	var scroll: ScrollContainer = battle_scene.get("_dialog_card_scroll")
	var row := battle_scene.get("_dialog_card_row") as HBoxContainer
	var first_card := row.get_child(0) as BattleCardView if row != null and row.get_child_count() > 0 else null
	var dialog_card_size: Vector2 = battle_scene.get("_dialog_card_size")
	var hbar := scroll.get_h_scroll_bar() if scroll != null else null
	var expected_height := float(battle_scene.call("_dialog_card_scroll_height"))
	var drag_active := scroll != null and bool(scroll.get_meta("card_gallery_drag_scroll_active", false))
	var keeps_scrollbar_visible := scroll != null and bool(scroll.get_meta("card_gallery_drag_keep_scrollbars_visible", false))
	var card_input_enabled := first_card != null and bool(first_card.get_meta("card_gallery_drag_input_enabled", false))
	var scrollbar_bridged := hbar != null and bool(hbar.get_meta("card_gallery_drag_scrollbar_bridge", false))
	if scroll != null:
		scroll.size = Vector2(400, scroll.custom_minimum_size.y)
	if row != null:
		row.size = Vector2(1400, row.size.y)
		row.custom_minimum_size = Vector2(1400, row.custom_minimum_size.y)
	if hbar != null:
		hbar.min_value = 0.0
		hbar.max_value = 1000.0
		hbar.page = 400.0
	scroll.scroll_horizontal = 120
	var start_scroll := scroll.scroll_horizontal

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(220, 24)
	press.global_position = Vector2(220, 24)
	var press_consumed := bool(battle_scene.call("_handle_card_gallery_drag_scroll_input", press, scroll, "dialog_cards"))

	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(60, 24)
	drag.global_position = Vector2(60, 24)
	var drag_consumed := bool(battle_scene.call("_handle_card_gallery_drag_scroll_input", drag, scroll, "dialog_cards"))
	var scroll_after_drag := scroll.scroll_horizontal if scroll != null else start_scroll

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(60, 24)
	release.global_position = Vector2(60, 24)
	battle_scene.call("_handle_card_gallery_drag_scroll_input", release, scroll, "dialog_cards")

	return run_checks([
		assert_true(bool(battle_scene.get("_dialog_card_mode")), "Portrait deck-search choices should still use the visual card dialog"),
		assert_eq(scroll.horizontal_scroll_mode if scroll != null else -1, ScrollContainer.SCROLL_MODE_AUTO, "Portrait card search should keep native horizontal scrolling available"),
		assert_true(drag_active, "Portrait card search should activate card-gallery drag scrolling"),
		assert_true(keeps_scrollbar_visible, "Portrait card search drag scrolling should keep the visible scrollbar available"),
		assert_true(card_input_enabled, "Portrait card-search card previews should forward pointer input to shared drag scrolling"),
		assert_false(scrollbar_bridged, "Portrait card search should leave the visible scrollbar to native input instead of card-gallery drag capture"),
		assert_false(bool(hbar.get_meta("card_gallery_hidden_scrollbar", false)) if hbar != null else true, "Portrait card search should restore the visible horizontal scrollbar"),
		assert_eq(str(hbar.get_meta("hud_scrollbar_profile", "")) if hbar != null else "", "portrait_touch", "Portrait card search scrollbar should use the large touch HUD profile"),
		assert_gte(hbar.custom_minimum_size.y if hbar != null else 0.0, float(HudThemeScript.SCROLLBAR_PORTRAIT_TOUCH_THICKNESS), "Portrait card search horizontal scrollbar should be large enough to grab on mobile"),
		assert_true(absf(scroll.custom_minimum_size.y - expected_height) <= 0.1 if scroll != null else false, "Portrait card search should reserve space below cards for the large scrollbar"),
		assert_gt(scroll.custom_minimum_size.y if scroll != null else 0.0, dialog_card_size.y, "Portrait card search row should be taller than a bare card lane because the scrollbar is visible"),
		assert_false(press_consumed, "Portrait card search drag handler should leave the initial press for card clicks until drag threshold"),
		assert_true(drag_consumed, "Portrait card search drag handler should consume horizontal drag while the scrollbar remains visible"),
		assert_true(scroll_after_drag > start_scroll, "Portrait card search should move horizontally when dragged while the scrollbar remains visible"),
	])


func test_portrait_perfect_mixer_uses_native_visible_scrollbar_not_card_drag_bridge() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	for i: int in 12:
		player.deck.append(CardInstance.create(_make_pokemon_cd("Mixer Target %d" % i, 60, "C"), 0))

	var mixer_card := CardInstance.create(_make_trainer_cd("完美搅拌器", "Item", ""), 0)
	var steps: Array[Dictionary] = EffectPerfectMixerScript.new().get_interaction_steps(mixer_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, mixer_card)

	var scroll: ScrollContainer = battle_scene.get("_dialog_card_scroll")
	var row := battle_scene.get("_dialog_card_row") as HBoxContainer
	var first_card := row.get_child(0) as BattleCardView if row != null and row.get_child_count() > 0 else null
	var hbar := scroll.get_h_scroll_bar() if scroll != null else null
	var drag_active := scroll != null and bool(scroll.get_meta("card_gallery_drag_scroll_active", false))
	var keeps_scrollbar_visible := scroll != null and bool(scroll.get_meta("card_gallery_drag_keep_scrollbars_visible", false))
	var card_input_enabled := first_card != null and bool(first_card.get_meta("card_gallery_drag_input_enabled", false))
	var scrollbar_bridged := hbar != null and bool(hbar.get_meta("card_gallery_drag_scrollbar_bridge", false))

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(220, 24)
	press.global_position = Vector2(220, 24)
	if hbar != null:
		hbar.gui_input.emit(press)
	var custom_drag_active_after_hbar_press := bool(battle_scene.get("_card_gallery_drag_active"))

	return run_checks([
		assert_true(bool(battle_scene.get("_dialog_card_mode")), "Perfect Mixer should render the full deck through the shared card dialog"),
		assert_eq((battle_scene.get("_dialog_items_data") as Array).size(), 12, "Perfect Mixer should expose the full deck as selectable cards"),
		assert_true(drag_active, "Perfect Mixer card dialog should keep card-area drag scrolling active"),
		assert_true(keeps_scrollbar_visible, "Perfect Mixer portrait dialog should keep a visible large scrollbar"),
		assert_true(card_input_enabled, "Perfect Mixer card previews should still forward card-area drag input"),
		assert_false(scrollbar_bridged, "Perfect Mixer visible scrollbar should not be captured by card-gallery dragging"),
		assert_false(custom_drag_active_after_hbar_press, "Pressing the Perfect Mixer scrollbar should not start custom card-gallery dragging"),
		assert_false(bool(hbar.get_meta("card_gallery_hidden_scrollbar", false)) if hbar != null else true, "Perfect Mixer scrollbar should stay visible in portrait"),
		assert_eq(str(hbar.get_meta("hud_scrollbar_profile", "")) if hbar != null else "", "portrait_touch", "Perfect Mixer scrollbar should use the large touch HUD profile"),
	])


func test_portrait_discard_viewer_restores_large_horizontal_scrollbar() -> String:
	var battle_scene: Control = BattleScenePacked.instantiate()
	battle_scene.set("_view_player", 0)
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.call("_setup_discard_gallery")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	for i: int in 10:
		gsm.game_state.players[0].discard_pile.append(CardInstance.create(_make_pokemon_cd("Portrait Discard %d" % i, 60, "C"), 0))
	battle_scene.set("_gsm", gsm)

	battle_scene.call("_show_discard_pile", 0, "Discard")
	var scroll: ScrollContainer = battle_scene.get("_discard_card_scroll")
	var row := battle_scene.get("_discard_card_row") as HBoxContainer
	var first_card := row.get_child(0) as BattleCardView if row != null and row.get_child_count() > 0 else null
	var dialog_card_size: Vector2 = battle_scene.get("_dialog_card_size")
	var hbar := scroll.get_h_scroll_bar() if scroll != null else null
	var expected_height := float(battle_scene.call("_dialog_card_scroll_height"))
	var drag_active := scroll != null and bool(scroll.get_meta("card_gallery_drag_scroll_active", false))
	var keeps_scrollbar_visible := scroll != null and bool(scroll.get_meta("card_gallery_drag_keep_scrollbars_visible", false))
	var card_input_enabled := first_card != null and bool(first_card.get_meta("card_gallery_drag_input_enabled", false))
	if scroll != null:
		scroll.size = Vector2(400, scroll.custom_minimum_size.y)
	if row != null:
		row.size = Vector2(1600, row.size.y)
		row.custom_minimum_size = Vector2(1600, row.custom_minimum_size.y)
	if hbar != null:
		hbar.min_value = 0.0
		hbar.max_value = 1200.0
		hbar.page = 400.0
	scroll.scroll_horizontal = 120
	var start_scroll := scroll.scroll_horizontal

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(220, 24)
	press.global_position = Vector2(220, 24)
	var press_consumed := bool(battle_scene.call("_handle_card_gallery_drag_scroll_input", press, scroll, "discard_collection"))

	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(60, 24)
	drag.global_position = Vector2(60, 24)
	var drag_consumed := bool(battle_scene.call("_handle_card_gallery_drag_scroll_input", drag, scroll, "discard_collection"))
	var scroll_after_drag := scroll.scroll_horizontal if scroll != null else start_scroll

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(60, 24)
	release.global_position = Vector2(60, 24)
	battle_scene.call("_handle_card_gallery_drag_scroll_input", release, scroll, "discard_collection")

	var result := run_checks([
		assert_eq(scroll.horizontal_scroll_mode if scroll != null else -1, ScrollContainer.SCROLL_MODE_AUTO, "Portrait discard viewer should keep native horizontal scrolling available"),
		assert_true(drag_active, "Portrait discard viewer should keep card-gallery drag scrolling active"),
		assert_true(keeps_scrollbar_visible, "Portrait discard viewer drag scrolling should keep the visible scrollbar available"),
		assert_true(card_input_enabled, "Portrait discard viewer cards should forward pointer input to shared drag scrolling"),
		assert_false(bool(hbar.get_meta("card_gallery_hidden_scrollbar", false)) if hbar != null else true, "Portrait discard viewer should restore the visible horizontal scrollbar"),
		assert_eq(str(hbar.get_meta("hud_scrollbar_profile", "")) if hbar != null else "", "portrait_touch", "Portrait discard viewer scrollbar should use the large touch HUD profile"),
		assert_gte(hbar.custom_minimum_size.y if hbar != null else 0.0, float(HudThemeScript.SCROLLBAR_PORTRAIT_TOUCH_THICKNESS), "Portrait discard viewer horizontal scrollbar should be large enough to grab on mobile"),
		assert_true(absf(scroll.custom_minimum_size.y - expected_height) <= 0.1 if scroll != null else false, "Portrait discard viewer should reserve space below cards for the large scrollbar"),
		assert_gt(scroll.custom_minimum_size.y if scroll != null else 0.0, dialog_card_size.y, "Portrait discard viewer row should be taller than a bare card lane because the scrollbar is visible"),
		assert_false(press_consumed, "Portrait discard viewer drag handler should leave the initial press for card clicks until drag threshold"),
		assert_true(drag_consumed, "Portrait discard viewer drag handler should consume horizontal drag while the scrollbar remains visible"),
		assert_true(scroll_after_drag > start_scroll, "Portrait discard viewer should move horizontally when dragged while the scrollbar remains visible"),
	])
	battle_scene.queue_free()
	return result


func test_portrait_discard_viewer_scrollbar_uses_native_input_not_card_drag_bridge() -> String:
	var battle_scene: Control = BattleScenePacked.instantiate()
	battle_scene.set("_view_player", 0)
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.call("_setup_discard_gallery")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	for i: int in 10:
		gsm.game_state.players[0].discard_pile.append(CardInstance.create(_make_pokemon_cd("Scrollbar Bridge %d" % i, 60, "C"), 0))
	battle_scene.set("_gsm", gsm)

	battle_scene.call("_show_discard_pile", 0, "Discard")
	var scroll: ScrollContainer = battle_scene.get("_discard_card_scroll")
	var row := battle_scene.get("_discard_card_row") as HBoxContainer
	var hbar := scroll.get_h_scroll_bar() if scroll != null else null
	if scroll != null:
		scroll.size = Vector2(400, scroll.custom_minimum_size.y)
	if row != null:
		row.size = Vector2(1600, row.size.y)
		row.custom_minimum_size = Vector2(1600, row.custom_minimum_size.y)
	if hbar != null:
		hbar.min_value = 0.0
		hbar.max_value = 1200.0
		hbar.page = 400.0
	scroll.scroll_horizontal = 120
	var start_scroll := scroll.scroll_horizontal

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(220, 24)
	press.global_position = Vector2(220, 24)
	if hbar != null:
		hbar.gui_input.emit(press)
	var custom_drag_active_after_hbar_press := bool(battle_scene.get("_card_gallery_drag_active"))

	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(60, 24)
	drag.global_position = Vector2(60, 24)
	if hbar != null:
		hbar.gui_input.emit(drag)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(60, 24)
	release.global_position = Vector2(60, 24)
	if hbar != null:
		hbar.gui_input.emit(release)

	var result := run_checks([
		assert_false(hbar != null and bool(hbar.get_meta("card_gallery_drag_scrollbar_bridge", false)), "Discard viewer visible scrollbar should stay on native input, not shared card-gallery dragging"),
		assert_false(custom_drag_active_after_hbar_press, "Pressing the visible discard viewer scrollbar should not start custom card-gallery dragging"),
		assert_eq(scroll.scroll_horizontal if scroll != null else -1, start_scroll, "Synthetic scrollbar gui_input should not be handled by card-gallery drag code"),
	])
	battle_scene.queue_free()
	return result


func test_battle_scene_superior_energy_retrieval_multi_select_keeps_second_tap_live() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	var superior_card := CardInstance.create(_make_trainer_cd("超级能量回收", "Item", ""), 0)
	superior_card.card_data.effect_id = "superior_energy_retrieval_ui_regression"
	var discard_energy := [
		CardInstance.create(_make_energy_cd("Water Energy", "W"), 0),
		CardInstance.create(_make_energy_cd("Lightning Energy", "L"), 0),
		CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0),
		CardInstance.create(_make_energy_cd("Metal Energy", "M"), 0),
	]
	player.hand = [
		superior_card,
		CardInstance.create(_make_pokemon_cd("Discard Cost A", 60, "C"), 0),
		CardInstance.create(_make_pokemon_cd("Discard Cost B", 70, "C"), 0),
	]
	player.discard_pile.append_array(discard_energy)

	var effect := preload("res://scripts/effects/trainer_effects/EffectRecoverBasicEnergy.gd").new(4, 2)
	gsm.effect_processor.register_effect(superior_card.card_data.effect_id, effect)
	var steps: Array[Dictionary] = effect.get_interaction_steps(superior_card, gsm.game_state)
	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, superior_card)

	battle_scene.set("_modal_input_slot_suppress_until_msec", 0)
	battle_scene.call("_on_dialog_card_chosen", 0)
	var discard_cost_first_selection: Array = (battle_scene.get("_dialog_card_selected_indices") as Array).duplicate()
	var discard_cost_suppression_after_first := int(battle_scene.get("_modal_input_slot_suppress_until_msec"))
	battle_scene.call("_on_dialog_card_chosen", 1)
	var discard_cost_second_selection: Array = (battle_scene.get("_dialog_card_selected_indices") as Array).duplicate()
	var discard_cost_suppression_after_second := int(battle_scene.get("_modal_input_slot_suppress_until_msec"))

	battle_scene.call("_on_dialog_confirm")
	var second_step_id := str(((battle_scene.get("_pending_effect_steps") as Array)[int(battle_scene.get("_pending_effect_step_index"))] as Dictionary).get("id", ""))
	battle_scene.set("_modal_input_slot_suppress_until_msec", 0)
	battle_scene.call("_on_dialog_card_chosen", 0)
	var recover_first_selection: Array = (battle_scene.get("_dialog_card_selected_indices") as Array).duplicate()
	var recover_suppression_after_first := int(battle_scene.get("_modal_input_slot_suppress_until_msec"))
	battle_scene.call("_on_dialog_card_chosen", 1)
	var recover_second_selection: Array = (battle_scene.get("_dialog_card_selected_indices") as Array).duplicate()
	var recover_suppression_after_second := int(battle_scene.get("_modal_input_slot_suppress_until_msec"))
	battle_scene.call("_on_dialog_card_chosen", 2)
	battle_scene.call("_on_dialog_card_chosen", 3)

	return run_checks([
		assert_eq(discard_cost_first_selection, [0], "Superior Energy Retrieval should select the first discard-cost card immediately"),
		assert_eq(discard_cost_second_selection, [0, 1], "Superior Energy Retrieval should select the second discard-cost card without requiring an extra tap"),
		assert_eq(discard_cost_suppression_after_first, 0, "Discard-cost multi-select should not arm modal slot suppression while the dialog remains open"),
		assert_eq(discard_cost_suppression_after_second, 0, "Discard-cost consecutive card taps should stay live"),
		assert_eq(second_step_id, "recover_energy", "Superior Energy Retrieval should advance to the discard-pile Energy recovery step"),
		assert_eq(recover_first_selection, [0], "Superior Energy Retrieval should select the first discard-pile Energy immediately"),
		assert_eq(recover_second_selection, [0, 1], "Superior Energy Retrieval should select the second discard-pile Energy without requiring an extra tap"),
		assert_eq(recover_suppression_after_first, 0, "Recovery multi-select should not arm modal slot suppression while the dialog remains open"),
		assert_eq(recover_suppression_after_second, 0, "Recovery consecutive card taps should stay live"),
		assert_true(discard_energy.all(func(energy: CardInstance) -> bool: return energy in player.hand), "Selecting the fourth discard-pile Energy should reliably commit all four cards to the hand"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "Superior Energy Retrieval should close as soon as its maximum four Energy cards are selected"),
	])


func test_battle_scene_trekking_shoes_shows_revealed_card_with_two_bottom_buttons() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var shoes_card := CardInstance.create(_make_trainer_cd("Trekking Shoes", "Item", ""), 0)
	var effect := preload("res://scripts/effects/trainer_effects/EffectTrekkingShoes.gd").new()
	var revealed := CardInstance.create(_make_pokemon_cd("Top Deck Pokemon", 70, "G"), 0)
	gsm.game_state.players[0].deck = [revealed]
	var steps: Array[Dictionary] = effect.get_interaction_steps(shoes_card, gsm.game_state)

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, shoes_card)

	var dialog_title := (battle_scene.get("_dialog_title") as Label).text
	var card_row: HBoxContainer = battle_scene.get("_dialog_card_row")
	var utility_row: HBoxContainer = battle_scene.get("_dialog_utility_row")
	var card_view := card_row.get_child(0) as BattleCardView if card_row.get_child_count() > 0 else null
	var button_texts: Array[String] = []
	for child: Node in utility_row.get_children():
		if child is Button:
			button_texts.append((child as Button).text)

	return run_checks([
		assert_true(bool(battle_scene.get("_dialog_card_mode")), "Trekking Shoes should switch the effect interaction into card mode"),
		assert_eq(card_row.get_child_count(), 1, "Trekking Shoes should reveal exactly one top-deck card"),
		assert_eq(card_view.card_instance.card_data.name if card_view != null and card_view.card_instance != null else "", "Top Deck Pokemon", "Trekking Shoes should present the exact top-deck card"),
		assert_eq(utility_row.get_child_count(), 2, "Trekking Shoes should put both outcomes on bottom buttons"),
		assert_eq(button_texts, ["加入手牌", "丢弃并再抽1张"], "Trekking Shoes should use direct action labels instead of a generic choice list"),
		assert_false((battle_scene.get("_dialog_confirm") as Button).visible, "Trekking Shoes should not require an extra confirm click"),
		assert_str_contains(dialog_title, "健行鞋", "Trekking Shoes dialog title should identify the card effect"),
	])


func test_battle_scene_trekking_shoes_discard_branch_draws_exactly_one_replacement_card_on_first_turn() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 1
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var shoes := CardInstance.create(_make_trainer_cd("Trekking Shoes", "Item", ""), 0)
	shoes.card_data.effect_id = "70d14b4a5a9c15581b8a0c8dfd325717"
	var top_discard := CardInstance.create(_make_pokemon_cd("Top Discard", 60, "C"), 0)
	var draw_one := CardInstance.create(_make_pokemon_cd("Draw One", 60, "C"), 0)
	var draw_two := CardInstance.create(_make_pokemon_cd("Draw Two", 60, "C"), 0)
	gsm.game_state.players[0].hand = [shoes]
	gsm.game_state.players[0].deck = [top_discard, draw_one, draw_two]

	battle_scene.call("_try_play_trainer_with_interaction", 0, shoes)
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([1]))

	var reveal_controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	if reveal_controller != null and bool(battle_scene.get("_draw_reveal_waiting_for_confirm")):
		reveal_controller.call("confirm_current_reveal", battle_scene)

	var hand_names: Array[String] = []
	for card: CardInstance in gsm.game_state.players[0].hand:
		hand_names.append(card.card_data.name)
	var discard_names: Array[String] = []
	for card: CardInstance in gsm.game_state.players[0].discard_pile:
		discard_names.append(card.card_data.name)
	var deck_names: Array[String] = []
	for card: CardInstance in gsm.game_state.players[0].deck:
		deck_names.append(card.card_data.name)

	return run_checks([
		assert_eq(hand_names, ["Draw One"], "Discarding with Trekking Shoes should leave exactly the first replacement draw in hand"),
		assert_eq(discard_names, ["Top Discard", "Trekking Shoes"], "Trekking Shoes should discard only the revealed top card and then itself"),
		assert_eq(deck_names, ["Draw Two"], "Trekking Shoes should not consume a second replacement card"),
		assert_eq((battle_scene.get("_draw_reveal_queue") as Array).size(), 0, "The replacement draw reveal queue should drain after confirmation"),
	])


func test_battle_scene_trekking_shoes_discard_button_path_keeps_first_replacement_visible_in_hand() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 1
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.action_logged.connect(battle_scene._on_action_logged)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var shoes := CardInstance.create(_make_trainer_cd("Trekking Shoes", "Item", ""), 0)
	shoes.card_data.effect_id = "70d14b4a5a9c15581b8a0c8dfd325717"
	var top_discard := CardInstance.create(_make_pokemon_cd("Top Discard", 60, "C"), 0)
	var draw_one := CardInstance.create(_make_pokemon_cd("Draw One", 60, "C"), 0)
	var draw_two := CardInstance.create(_make_pokemon_cd("Draw Two", 60, "C"), 0)
	gsm.game_state.players[0].hand = [shoes]
	gsm.game_state.players[0].deck = [top_discard, draw_one, draw_two]

	battle_scene.call("_try_play_trainer_with_interaction", 0, shoes)
	var utility_row: HBoxContainer = battle_scene.get("_dialog_utility_row")
	var discard_button := utility_row.get_child(1) as Button if utility_row.get_child_count() > 1 else null
	if discard_button != null:
		discard_button.pressed.emit()

	var reveal_controller: RefCounted = battle_scene.get("_battle_draw_reveal_controller")
	if reveal_controller != null and bool(battle_scene.get("_draw_reveal_waiting_for_confirm")):
		reveal_controller.call("confirm_current_reveal", battle_scene)

	var hand_names: Array[String] = []
	for card: CardInstance in gsm.game_state.players[0].hand:
		hand_names.append(card.card_data.name)
	var rendered_names: Array[String] = []
	var hand_container: HBoxContainer = battle_scene.get("_hand_container")
	for child: Node in hand_container.get_children():
		if child is BattleCardView and (child as BattleCardView).card_data != null:
			rendered_names.append((child as BattleCardView).card_data.name)

	return run_checks([
		assert_not_null(discard_button, "Trekking Shoes should render a discard button in the utility row"),
		assert_eq(hand_names, ["Draw One"], "Pressing the discard button should still draw only the first replacement card"),
		assert_eq(rendered_names, ["Draw One"], "After the reveal resolves, the visible hand should show the first replacement draw instead of skipping to the next card"),
	])


func test_battle_scene_nest_ball_without_target_can_preview_deck_then_consume() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.bench.clear()
	var no_basic_target := CardInstance.create(_make_pokemon_cd("No Basic Target", 90, "C"), 0)
	no_basic_target.card_data.stage = "Stage 1"
	player.deck.append_array([
		CardInstance.create(_make_trainer_cd("Deck Item", "Item", ""), 0),
		no_basic_target,
	])

	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball", "Item", ""), 0)
	nest_ball.card_data.effect_id = "1af63a7e2cb7a79215474ad8db8fd8fd"
	player.hand.append(nest_ball)

	battle_scene.call("_try_play_trainer_with_interaction", 0, nest_ball)
	var first_step_title := (battle_scene.get("_dialog_title") as Label).text
	var first_dialog_items: Array = battle_scene.get("_dialog_items_data")

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([1]))
	var preview_title := (battle_scene.get("_dialog_title") as Label).text
	var preview_dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var preview_items: Array = preview_dialog_data.get("card_items", [])
	var utility_row: HBoxContainer = battle_scene.get("_dialog_utility_row")

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array())

	return run_checks([
		assert_true(bool((battle_scene.get("_dialog_overlay") as Panel).visible) or nest_ball in player.discard_pile, "Nest Ball should open a resolution flow instead of being blocked outright"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "After closing the deck preview, the trainer interaction should finish cleanly"),
		assert_str_contains(first_step_title, "没有", "Nest Ball whiff dialog should explain that the deck has no valid Pokemon"),
		assert_eq(first_dialog_items.size(), 2, "Nest Ball whiff dialog should offer continue and preview options"),
		assert_str_contains(preview_title, "牌库", "Choosing preview should open a deck preview step"),
		assert_true(bool(battle_scene.get("_dialog_card_mode")) or preview_dialog_data.get("presentation", "") == "cards", "Deck preview should render in card mode"),
		assert_eq(preview_items.size(), 2, "Deck preview should show the remaining deck cards"),
		assert_eq(utility_row.get_child_count(), 1, "Deck preview should expose a single close-and-continue utility action"),
		assert_true(nest_ball in player.discard_pile, "Nest Ball should still be consumed after the deck preview closes"),
		assert_eq(player.bench.size(), 0, "Nest Ball whiff preview should not add any Pokemon to the bench"),
	])


func test_battle_scene_pokegear_whiff_shows_top_seven_and_real_close_button_consumes_card() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()
	var viewed_cards: Array[CardInstance] = []
	for i: int in 7:
		var viewed_card := CardInstance.create(_make_pokemon_cd("Viewed Pokemon %d" % i, 80, "C"), 0)
		viewed_cards.append(viewed_card)
		player.deck.append(viewed_card)
	var hidden_supporter := CardInstance.create(_make_trainer_cd("Hidden Supporter", "Supporter", ""), 0)
	player.deck.append(hidden_supporter)

	var pokegear := CardInstance.create(_make_trainer_cd("宝可装置3.0", "Item", ""), 0)
	pokegear.card_data.effect_id = "768b545a38fccd5e265093b5adce10af"
	player.hand.append(pokegear)

	battle_scene.call("_try_play_trainer_with_interaction", 0, pokegear)
	var step_index := int(battle_scene.get("_pending_effect_step_index"))
	var steps: Array = battle_scene.get("_pending_effect_steps")
	var step: Dictionary = steps[step_index] if step_index >= 0 and step_index < steps.size() else {}
	var dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var utility_row := battle_scene.get("_dialog_utility_row") as HBoxContainer
	var close_button := utility_row.get_child(0) as Button if utility_row != null and utility_row.get_child_count() == 1 else null
	if close_button != null:
		close_button.pressed.emit()

	return run_checks([
		assert_eq(str(step.get("id", "")), "look_top_cards", "Pokegear should open the direct top-seven selection step even when it misses"),
		assert_eq(dialog_data.get("card_items", []), viewed_cards, "Pokegear should show exactly the seven viewed cards in the first dialog"),
		assert_eq(dialog_data.get("card_indices", []), [-1, -1, -1, -1, -1, -1, -1], "Non-Supporters should be visible but disabled"),
		assert_true(close_button != null and close_button.text == "关闭并继续", "A missed Pokegear should expose one working close-and-continue action"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "The real utility button signal should finish the trainer interaction"),
		assert_true(pokegear in player.discard_pile, "Closing the direct top-seven view should consume Pokegear"),
		assert_true(hidden_supporter in player.deck, "Pokegear must not select or reveal a Supporter below the top seven"),
		assert_eq(player.deck.size(), 8, "A missed Pokegear should only shuffle the deck, not change its card count"),
	])


func test_battle_scene_tatsugiri_whiff_preview_close_button_finishes_ability() -> String:
	var battle_scene = _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	var tatsugiri_cd := _make_pokemon_cd("米立龙", 70, "N")
	tatsugiri_cd.effect_id = "1ceeba6dac51ccc19833c5a513fe3fc6"
	tatsugiri_cd.abilities = [{
		"name": "揽客",
		"text": "查看自己牌库上方6张卡牌，选择其中1张支援者加入手牌。",
	}]
	var tatsugiri := PokemonSlot.new()
	tatsugiri.pokemon_stack.append(CardInstance.create(tatsugiri_cd, 0))
	player.active_pokemon = tatsugiri
	var item := CardInstance.create(_make_trainer_cd("Top Item", "Item", ""), 0)
	var pokemon := CardInstance.create(_make_pokemon_cd("Top Pokemon", 80, "C"), 0)
	player.deck = [item, pokemon]
	gsm.effect_processor.register_pokemon_card(tatsugiri_cd)

	battle_scene.call("_try_use_ability_with_interaction", 0, tatsugiri, 0)
	var initial_step_index := int(battle_scene.get("_pending_effect_step_index"))
	var initial_steps: Array = battle_scene.get("_pending_effect_steps")
	var initial_step: Dictionary = initial_steps[initial_step_index] if initial_step_index >= 0 and initial_step_index < initial_steps.size() else {}
	battle_scene.call("_on_dialog_item_selected", 1)

	var preview_step_index := int(battle_scene.get("_pending_effect_step_index"))
	var preview_steps: Array = battle_scene.get("_pending_effect_steps")
	var preview_step: Dictionary = preview_steps[preview_step_index] if preview_step_index >= 0 and preview_step_index < preview_steps.size() else {}
	var preview_data: Dictionary = battle_scene.get("_dialog_data")
	var utility_row := battle_scene.get("_dialog_utility_row") as HBoxContainer
	var close_button := utility_row.get_child(0) as Button if utility_row != null and utility_row.get_child_count() == 1 else null
	var close_label := close_button.text if close_button != null else ""
	if close_button != null:
		close_button.pressed.emit()

	var ability_still_available := gsm.effect_processor.can_use_ability(tatsugiri, gsm.game_state, 0)
	return run_checks([
		assert_eq(str(initial_step.get("id", "")), "empty_search_resolution", "Tatsugiri whiff should first offer continue or view-card resolution"),
		assert_eq(str(preview_step.get("id", "")), "empty_search_view_deck", "Choosing view cards should open Tatsugiri's readonly top-card preview"),
		assert_eq(preview_data.get("card_items", []), [item, pokemon], "Tatsugiri may reveal only the looked-at top cards"),
		assert_eq(close_label, "关闭并继续", "Tatsugiri's whiff preview should expose a working close-and-continue button"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "Closing Tatsugiri's preview should finish the interaction instead of trapping the player"),
		assert_false(ability_still_available, "Closing the preview should consume Tatsugiri's once-per-turn Ability"),
		assert_true(item in player.deck and pokemon in player.deck, "Tatsugiri should return the looked-at cards before shuffling"),
		assert_true(player.hand.is_empty(), "A Tatsugiri whiff must not add a card to hand"),
	])


func test_battle_scene_portrait_nest_ball_detail_use_opens_basic_search_dialog() -> String:
	var battle_scene := _prepare_detail_scene()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.set("_dialog_overlay", battle_scene.find_child("DialogOverlay", true, false))
	battle_scene.set("_dialog_title", battle_scene.find_child("DialogTitle", true, false))
	battle_scene.set("_dialog_list", battle_scene.find_child("DialogList", true, false))
	battle_scene.set("_dialog_confirm", battle_scene.find_child("DialogConfirm", true, false))
	battle_scene.set("_dialog_cancel", battle_scene.find_child("DialogCancel", true, false))
	battle_scene.set("_dialog_box", battle_scene.find_child("DialogBox", true, false))
	battle_scene.set("_dialog_vbox", battle_scene.find_child("DialogVBox", true, false))
	battle_scene.call("_setup_dialog_gallery")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.bench.clear()
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball", "Item", ""), 0)
	nest_ball.card_data.effect_id = "1af63a7e2cb7a79215474ad8db8fd8fd"
	var basic_target := CardInstance.create(_make_pokemon_cd("Nest Target Basic", 70, "C"), 0)
	var visible_non_target := CardInstance.create(_make_trainer_cd("Visible Non Target", "Item", ""), 0)
	player.hand.append(nest_ball)
	player.deck.append_array([basic_target, visible_non_target])

	battle_scene.call("_show_hand_card_detail", nest_ball)
	var detail_overlay := battle_scene.find_child("DetailOverlay", true, false) as Control
	var detail_action_bar := battle_scene.find_child("DetailActionBar", true, false) as Control
	var opened_confirmation: bool = (
		detail_overlay != null
		and detail_overlay.visible
		and detail_action_bar != null
		and detail_action_bar.visible
	)
	battle_scene.call("_on_detail_use_pressed")

	var dialog_overlay := battle_scene.get("_dialog_overlay") as Control
	var dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var card_items: Array = dialog_data.get("card_items", [])
	var items_data: Array = battle_scene.get("_dialog_items_data")
	var rendered_count := _dialog_rendered_choice_count(battle_scene)
	var first_card := _dialog_rendered_choice_card_view(battle_scene, 0)
	var second_card := _dialog_rendered_choice_card_view(battle_scene, 1)

	var result := run_checks([
		assert_true(opened_confirmation, "Portrait Nest Ball tap should first open the hand-card Use confirmation"),
		assert_true(dialog_overlay != null and dialog_overlay.visible, "Using Nest Ball from the portrait detail popup should open the Basic Pokemon search dialog"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "Nest Ball should remain in the effect-interaction choice flow while the search dialog is open"),
		assert_true(bool(battle_scene.get("_dialog_card_mode")), "Nest Ball Basic search should use the card dialog presentation"),
		assert_eq(str(dialog_data.get("visible_scope", "")), "own_full_deck", "Nest Ball search should expose the full own deck context"),
		assert_eq(items_data.size(), 1, "Nest Ball search dialog items should keep only legal selectable candidates for effect resolution"),
		assert_eq(card_items.size(), 2, "Nest Ball search card_items should include the visible non-target card"),
		assert_eq(rendered_count, 2, "Nest Ball search should render both the legal target and visible non-target"),
		assert_true(first_card != null and not bool(first_card.get("_disabled")), "The Basic Pokemon target should be selectable"),
		assert_true(second_card != null and bool(second_card.get("_disabled")), "The non-target visible deck card should be disabled"),
		assert_false(nest_ball in player.discard_pile, "Nest Ball should not resolve before a search choice or explicit empty confirmation"),
	])
	battle_scene.free()
	return result


func test_battle_scene_portrait_nest_ball_detail_use_button_pressed_opens_basic_search_dialog() -> String:
	var battle_scene := _prepare_detail_scene()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.set("_dialog_overlay", battle_scene.find_child("DialogOverlay", true, false))
	battle_scene.set("_dialog_title", battle_scene.find_child("DialogTitle", true, false))
	battle_scene.set("_dialog_list", battle_scene.find_child("DialogList", true, false))
	battle_scene.set("_dialog_confirm", battle_scene.find_child("DialogConfirm", true, false))
	battle_scene.set("_dialog_cancel", battle_scene.find_child("DialogCancel", true, false))
	battle_scene.set("_dialog_box", battle_scene.find_child("DialogBox", true, false))
	battle_scene.set("_dialog_vbox", battle_scene.find_child("DialogVBox", true, false))
	battle_scene.call("_setup_dialog_gallery")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.bench.clear()
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball", "Item", ""), 0)
	nest_ball.card_data.effect_id = "1af63a7e2cb7a79215474ad8db8fd8fd"
	var basic_target := CardInstance.create(_make_pokemon_cd("Nest Button Target Basic", 70, "C"), 0)
	player.hand.append(nest_ball)
	player.deck.append(basic_target)

	battle_scene.call("_apply_portrait_layout", Vector2(390, 844))
	battle_scene.call("_show_hand_card_detail", nest_ball)
	var use_button := battle_scene.find_child("DetailUseButton", true, false) as Button
	var detail_overlay := battle_scene.find_child("DetailOverlay", true, false) as Control
	var button_ready := (
		use_button != null
		and use_button.visible
		and not use_button.disabled
		and detail_overlay != null
		and detail_overlay.visible
	)
	if use_button != null:
		use_button.pressed.emit()

	var dialog_overlay := battle_scene.get("_dialog_overlay") as Control
	var dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var dialog_box := battle_scene.find_child("DialogBox", true, false) as Control
	var portrait_frame: Rect2 = battle_scene.get("_portrait_layout_frame_rect")
	var result := run_checks([
		assert_true(button_ready, "Portrait Nest Ball detail should expose an enabled Use button"),
		assert_true(dialog_overlay != null and dialog_overlay.visible, "The real DetailUseButton pressed signal should open the Nest Ball search dialog"),
		assert_false(detail_overlay != null and detail_overlay.visible, "The hand-card detail overlay should close before the search dialog is shown"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "Nest Ball button flow should enter the effect-interaction choice flow"),
		assert_eq(str(dialog_data.get("visible_scope", "")), "own_full_deck", "Nest Ball button flow should open the full-deck search dialog"),
		assert_eq(dialog_overlay.size if dialog_overlay != null else Vector2.ZERO, portrait_frame.size, "Nest Ball search overlay should keep the active portrait frame size"),
		assert_true(dialog_box != null and dialog_box.custom_minimum_size.x <= portrait_frame.size.x, "Nest Ball search dialog box should fit within the portrait frame width"),
	])
	battle_scene.free()
	return result


func test_battle_scene_portrait_nest_ball_detail_use_button_opens_empty_search_resolution_when_no_basic() -> String:
	var battle_scene := _prepare_detail_scene()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.set("_dialog_overlay", battle_scene.find_child("DialogOverlay", true, false))
	battle_scene.set("_dialog_title", battle_scene.find_child("DialogTitle", true, false))
	battle_scene.set("_dialog_list", battle_scene.find_child("DialogList", true, false))
	battle_scene.set("_dialog_confirm", battle_scene.find_child("DialogConfirm", true, false))
	battle_scene.set("_dialog_cancel", battle_scene.find_child("DialogCancel", true, false))
	battle_scene.set("_dialog_box", battle_scene.find_child("DialogBox", true, false))
	battle_scene.set("_dialog_vbox", battle_scene.find_child("DialogVBox", true, false))
	battle_scene.call("_setup_dialog_gallery")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.bench.clear()
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball", "Item", ""), 0)
	nest_ball.card_data.effect_id = "1af63a7e2cb7a79215474ad8db8fd8fd"
	player.hand.append(nest_ball)
	player.deck.append(CardInstance.create(_make_trainer_cd("Visible Item Only", "Item", ""), 0))

	battle_scene.call("_show_hand_card_detail", nest_ball)
	var use_button := battle_scene.find_child("DetailUseButton", true, false) as Button
	if use_button != null:
		use_button.pressed.emit()

	var dialog_overlay := battle_scene.get("_dialog_overlay") as Control
	var dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var dialog_items: Array = battle_scene.get("_dialog_items_data")
	var result := run_checks([
		assert_true(dialog_overlay != null and dialog_overlay.visible, "Nest Ball with no Basic targets should still open a visible empty-search resolution dialog from the Use button"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "Nest Ball empty-search resolution should remain an effect interaction"),
		assert_false(bool(battle_scene.get("_dialog_card_mode")), "Nest Ball empty-search resolution should use the text choice dialog instead of a card gallery"),
		assert_eq(dialog_items.size(), 2, "Nest Ball empty-search resolution should expose Continue and View Deck choices"),
		assert_eq(int(dialog_data.get("min_select", -1)), 1, "Nest Ball empty-search resolution should require one text choice"),
		assert_false(nest_ball in player.discard_pile, "Nest Ball should not resolve until the empty-search choice is selected"),
	])
	battle_scene.free()
	return result


func test_battle_scene_portrait_ultra_ball_detail_use_button_opens_discard_dialog() -> String:
	var battle_scene := _prepare_detail_scene()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.set("_dialog_overlay", battle_scene.find_child("DialogOverlay", true, false))
	battle_scene.set("_dialog_title", battle_scene.find_child("DialogTitle", true, false))
	battle_scene.set("_dialog_list", battle_scene.find_child("DialogList", true, false))
	battle_scene.set("_dialog_confirm", battle_scene.find_child("DialogConfirm", true, false))
	battle_scene.set("_dialog_cancel", battle_scene.find_child("DialogCancel", true, false))
	battle_scene.set("_dialog_box", battle_scene.find_child("DialogBox", true, false))
	battle_scene.set("_dialog_vbox", battle_scene.find_child("DialogVBox", true, false))
	battle_scene.call("_setup_dialog_gallery")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item", ""), 0)
	ultra_ball.card_data.effect_id = "a337ed34a45e63c6d21d98c3d8e0cb6e"
	var discard_a := CardInstance.create(_make_trainer_cd("Discard A", "Item", ""), 0)
	var discard_b := CardInstance.create(_make_trainer_cd("Discard B", "Item", ""), 0)
	var deck_target := CardInstance.create(_make_pokemon_cd("Ultra Target", 70, "C"), 0)
	player.hand.append_array([ultra_ball, discard_a, discard_b])
	player.deck.append(deck_target)

	battle_scene.call("_apply_portrait_layout", Vector2(390, 844))
	battle_scene.call("_show_hand_card_detail", ultra_ball)
	var use_button := battle_scene.find_child("DetailUseButton", true, false) as Button
	var detail_overlay := battle_scene.find_child("DetailOverlay", true, false) as Control
	var button_ready := (
		use_button != null
		and use_button.visible
		and not use_button.disabled
		and detail_overlay != null
		and detail_overlay.visible
	)
	if use_button != null:
		use_button.pressed.emit()

	var pending_steps: Array = battle_scene.get("_pending_effect_steps")
	var step_index := int(battle_scene.get("_pending_effect_step_index"))
	var current_step: Dictionary = pending_steps[step_index] if step_index >= 0 and step_index < pending_steps.size() else {}
	var dialog_overlay := battle_scene.get("_dialog_overlay") as Control
	var dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var dialog_items: Array = battle_scene.get("_dialog_items_data")
	var card_items: Array = dialog_data.get("card_items", [])
	var dialog_confirm := battle_scene.get("_dialog_confirm") as Button
	var result := run_checks([
		assert_true(button_ready, "Portrait Ultra Ball detail should expose an enabled Use button"),
		assert_true(dialog_overlay != null and dialog_overlay.visible, "Using Ultra Ball should open the discard-card dialog"),
		assert_false(detail_overlay != null and detail_overlay.visible, "The hand-card detail overlay should close before the discard dialog is shown"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "Ultra Ball should enter effect interaction from the detail Use button"),
		assert_eq(str(current_step.get("id", "")), "discard_cards", "Ultra Ball should start on its discard-cost step"),
		assert_true(bool(battle_scene.get("_dialog_card_mode")), "Ultra Ball discard choices should render as cards in portrait"),
		assert_eq(int(dialog_data.get("min_select", -1)), 2, "Ultra Ball discard dialog should require two cards"),
		assert_eq(int(dialog_data.get("max_select", -1)), 2, "Ultra Ball discard dialog should cap selection at two cards"),
		assert_eq(dialog_items.size(), 2, "Ultra Ball discard dialog should offer the two other hand cards"),
		assert_eq(card_items.size(), 2, "Ultra Ball card dialog should render the two other hand cards"),
		assert_true(dialog_confirm != null and dialog_confirm.visible and dialog_confirm.disabled, "Ultra Ball confirm should start disabled until two discards are selected"),
	])
	battle_scene.free()
	return result


func test_battle_scene_portrait_area_zero_then_ultra_ball_use_opens_discard_dialog() -> String:
	var battle_scene := _prepare_detail_scene()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.set("_dialog_overlay", battle_scene.find_child("DialogOverlay", true, false))
	battle_scene.set("_dialog_title", battle_scene.find_child("DialogTitle", true, false))
	battle_scene.set("_dialog_list", battle_scene.find_child("DialogList", true, false))
	battle_scene.set("_dialog_confirm", battle_scene.find_child("DialogConfirm", true, false))
	battle_scene.set("_dialog_cancel", battle_scene.find_child("DialogCancel", true, false))
	battle_scene.set("_dialog_box", battle_scene.find_child("DialogBox", true, false))
	battle_scene.set("_dialog_vbox", battle_scene.find_child("DialogVBox", true, false))
	battle_scene.call("_setup_dialog_gallery")

	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	var area_zero_cd := _make_trainer_cd("Area Zero Underdepths", "Stadium", "")
	area_zero_cd.effect_id = EffectAreaZeroUnderdepthsScript.EFFECT_ID
	var area_zero := CardInstance.create(area_zero_cd, 0)
	var ultra_ball := CardInstance.create(_make_trainer_cd("Ultra Ball", "Item", ""), 0)
	ultra_ball.card_data.effect_id = "a337ed34a45e63c6d21d98c3d8e0cb6e"
	var discard_a := CardInstance.create(_make_trainer_cd("Discard A", "Item", ""), 0)
	var discard_b := CardInstance.create(_make_trainer_cd("Discard B", "Item", ""), 0)
	var deck_target := CardInstance.create(_make_pokemon_cd("Ultra Target", 70, "C"), 0)
	player.hand.append_array([area_zero, ultra_ball, discard_a, discard_b])
	player.deck.append(deck_target)

	battle_scene.call("_apply_portrait_layout", Vector2(390, 844))
	battle_scene.call("_show_hand_card_detail", area_zero)
	battle_scene.call("_on_detail_use_pressed")

	var stadium_view := battle_scene.get("_stadium_card_view") as Control
	var detail_overlay := battle_scene.find_child("DetailOverlay", true, false) as Control
	var hand_container := battle_scene.get("_hand_container") as HBoxContainer
	var ultra_hand_view: BattleCardView = null
	if hand_container != null:
		for child: Node in hand_container.get_children():
			var card_view := child as BattleCardView
			if card_view != null and card_view.card_instance != null and card_view.card_instance.instance_id == ultra_ball.instance_id:
				ultra_hand_view = card_view
				break
	var fallback_armed_after_area_zero := ultra_hand_view != null and ultra_hand_view.is_primary_release_fallback_armed()

	battle_scene.call("_show_hand_card_detail", ultra_ball)

	var use_button := battle_scene.find_child("DetailUseButton", true, false) as Button
	var button_ready := (
		use_button != null
		and use_button.visible
		and not use_button.disabled
		and detail_overlay != null
		and detail_overlay.visible
	)
	if use_button != null:
		use_button.pressed.emit()

	var pending_steps: Array = battle_scene.get("_pending_effect_steps")
	var step_index := int(battle_scene.get("_pending_effect_step_index"))
	var current_step: Dictionary = pending_steps[step_index] if step_index >= 0 and step_index < pending_steps.size() else {}
	var dialog_overlay := battle_scene.get("_dialog_overlay") as Control
	var dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var dialog_items: Array = battle_scene.get("_dialog_items_data")
	var result := run_checks([
		assert_eq(gsm.game_state.stadium_card, area_zero, "Area Zero should be in play before using Ultra Ball"),
		assert_true(stadium_view != null and stadium_view.visible, "Area Zero should create the Stadium card HUD"),
		assert_true(ultra_hand_view != null, "Ultra Ball should still be rendered in the portrait hand after Area Zero is played"),
		assert_false(fallback_armed_after_area_zero, "Playing a non-modal Stadium must not arm missing-press fallback on the next hand cards"),
		assert_true(button_ready, "Ultra Ball should still open an enabled detail Use button after Area Zero is played"),
		assert_true(dialog_overlay != null and dialog_overlay.visible, "Using Ultra Ball after Area Zero should open the discard-card dialog"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "Ultra Ball should enter effect interaction after Area Zero"),
		assert_eq(str(current_step.get("id", "")), "discard_cards", "Ultra Ball should start on its discard-cost step after Area Zero"),
		assert_eq(int(dialog_data.get("min_select", -1)), 2, "Ultra Ball discard dialog should require two cards after Area Zero"),
		assert_eq(dialog_items.size(), 2, "Ultra Ball discard dialog should offer the two other hand cards after Area Zero"),
	])

	battle_scene.free()
	return result


func test_battle_scene_portrait_secret_box_detail_use_button_opens_discard_dialog() -> String:
	var battle_scene := _prepare_detail_scene()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.set("_dialog_overlay", battle_scene.find_child("DialogOverlay", true, false))
	battle_scene.set("_dialog_title", battle_scene.find_child("DialogTitle", true, false))
	battle_scene.set("_dialog_list", battle_scene.find_child("DialogList", true, false))
	battle_scene.set("_dialog_confirm", battle_scene.find_child("DialogConfirm", true, false))
	battle_scene.set("_dialog_cancel", battle_scene.find_child("DialogCancel", true, false))
	battle_scene.set("_dialog_box", battle_scene.find_child("DialogBox", true, false))
	battle_scene.set("_dialog_vbox", battle_scene.find_child("DialogVBox", true, false))
	battle_scene.call("_setup_dialog_gallery")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	var secret_box := CardInstance.create(_make_trainer_cd("Secret Box", "Item", ""), 0)
	secret_box.card_data.effect_id = "e92a86246f44351d023bd4fa271089aa"
	var discard_a := CardInstance.create(_make_trainer_cd("Discard A", "Item", ""), 0)
	var discard_b := CardInstance.create(_make_trainer_cd("Discard B", "Item", ""), 0)
	var discard_c := CardInstance.create(_make_trainer_cd("Discard C", "Item", ""), 0)
	player.hand.append_array([secret_box, discard_a, discard_b, discard_c])
	player.deck.append(CardInstance.create(_make_trainer_cd("Secret Item", "Item", ""), 0))

	battle_scene.call("_apply_portrait_layout", Vector2(390, 844))
	battle_scene.call("_show_hand_card_detail", secret_box)
	var use_button := battle_scene.find_child("DetailUseButton", true, false) as Button
	var detail_overlay := battle_scene.find_child("DetailOverlay", true, false) as Control
	var button_ready := (
		use_button != null
		and use_button.visible
		and not use_button.disabled
		and detail_overlay != null
		and detail_overlay.visible
	)
	if use_button != null:
		use_button.pressed.emit()

	var pending_steps: Array = battle_scene.get("_pending_effect_steps")
	var step_index := int(battle_scene.get("_pending_effect_step_index"))
	var current_step: Dictionary = pending_steps[step_index] if step_index >= 0 and step_index < pending_steps.size() else {}
	var dialog_overlay := battle_scene.get("_dialog_overlay") as Control
	var dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var dialog_items: Array = battle_scene.get("_dialog_items_data")
	var card_items: Array = dialog_data.get("card_items", [])
	var dialog_confirm := battle_scene.get("_dialog_confirm") as Button
	var result := run_checks([
		assert_true(button_ready, "Portrait Secret Box detail should expose an enabled Use button"),
		assert_true(dialog_overlay != null and dialog_overlay.visible, "Using Secret Box should open the discard-card dialog"),
		assert_false(detail_overlay != null and detail_overlay.visible, "The hand-card detail overlay should close before the discard dialog is shown"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "Secret Box should enter effect interaction from the detail Use button"),
		assert_eq(str(current_step.get("id", "")), "discard_cards", "Secret Box should start on its discard-cost step"),
		assert_true(bool(battle_scene.get("_dialog_card_mode")), "Secret Box discard choices should render as cards in portrait"),
		assert_eq(int(dialog_data.get("min_select", -1)), 3, "Secret Box discard dialog should require three cards"),
		assert_eq(int(dialog_data.get("max_select", -1)), 3, "Secret Box discard dialog should cap selection at three cards"),
		assert_eq(dialog_items.size(), 3, "Secret Box discard dialog should offer the three other hand cards"),
		assert_eq(card_items.size(), 3, "Secret Box card dialog should render the three other hand cards"),
		assert_true(dialog_confirm != null and dialog_confirm.visible and dialog_confirm.disabled, "Secret Box confirm should start disabled until three discards are selected"),
	])
	battle_scene.free()
	return result


func test_battle_scene_portrait_nest_ball_touch_tap_then_use_opens_basic_search_dialog() -> String:
	var battle_scene := _prepare_detail_scene()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.set("_dialog_overlay", battle_scene.find_child("DialogOverlay", true, false))
	battle_scene.set("_dialog_title", battle_scene.find_child("DialogTitle", true, false))
	battle_scene.set("_dialog_list", battle_scene.find_child("DialogList", true, false))
	battle_scene.set("_dialog_confirm", battle_scene.find_child("DialogConfirm", true, false))
	battle_scene.set("_dialog_cancel", battle_scene.find_child("DialogCancel", true, false))
	battle_scene.set("_dialog_box", battle_scene.find_child("DialogBox", true, false))
	battle_scene.set("_dialog_vbox", battle_scene.find_child("DialogVBox", true, false))
	battle_scene.call("_setup_dialog_gallery")
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = pi
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.bench.clear()
	var nest_ball := CardInstance.create(_make_trainer_cd("Nest Ball", "Item", ""), 0)
	nest_ball.card_data.effect_id = "1af63a7e2cb7a79215474ad8db8fd8fd"
	var basic_target := CardInstance.create(_make_pokemon_cd("Nest Touch Target Basic", 70, "C"), 0)
	var visible_non_target := CardInstance.create(_make_trainer_cd("Nest Touch Non Target", "Item", ""), 0)
	player.hand.append(nest_ball)
	player.deck.append_array([basic_target, visible_non_target])

	var display_controller := BattleDisplayControllerScript.new()
	var hand_card := display_controller.build_hand_card(battle_scene, nest_ball) as BattleCardView
	battle_scene.add_child(hand_card)
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.index = 0
	press.position = Vector2(32, 32)
	hand_card.call("_gui_input", press)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = Vector2(32, 32)
	hand_card.call("_gui_input", release)

	var detail_overlay := battle_scene.find_child("DetailOverlay", true, false) as Control
	var detail_action_bar := battle_scene.find_child("DetailActionBar", true, false) as Control
	var opened_confirmation: bool = (
		detail_overlay != null
		and detail_overlay.visible
		and detail_action_bar != null
		and detail_action_bar.visible
	)
	battle_scene.call("_on_detail_use_pressed")

	var dialog_overlay := battle_scene.get("_dialog_overlay") as Control
	var dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var rendered_count := _dialog_rendered_choice_count(battle_scene)

	var result := run_checks([
		assert_true(opened_confirmation, "A portrait ScreenTouch tap on Nest Ball should open the hand-card Use confirmation"),
		assert_true(dialog_overlay != null and dialog_overlay.visible, "Using Nest Ball after a portrait ScreenTouch tap should open the Basic Pokemon search dialog"),
		assert_eq(str(battle_scene.get("_pending_choice")), "effect_interaction", "Nest Ball touch flow should stay in effect interaction while the search dialog is open"),
		assert_eq(str(dialog_data.get("visible_scope", "")), "own_full_deck", "Nest Ball touch flow should open the full-deck search dialog"),
		assert_eq(rendered_count, 2, "Nest Ball touch flow should render the legal Basic and the disabled visible non-target"),
	])
	battle_scene.free()
	return result


func test_battle_scene_earthen_vessel_empty_search_preview_can_be_opened_and_consumes_card() -> String:
	var battle_scene = _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)

	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()
	player.bench.clear()
	player.deck.append_array([
		CardInstance.create(_make_trainer_cd("Deck Item", "Item", ""), 0),
		CardInstance.create(_make_pokemon_cd("Deck Pokemon", 90, "C"), 0),
	])

	var discard_cost := CardInstance.create(_make_trainer_cd("Discard Cost", "Item", ""), 0)
	var earthen_vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item", ""), 0)
	earthen_vessel.card_data.effect_id = "e366f56ecd3f805a28294109a1a37453"
	player.hand.append_array([earthen_vessel, discard_cost])

	battle_scene.call("_try_play_trainer_with_interaction", 0, earthen_vessel)
	var first_step_title := (battle_scene.get("_dialog_title") as Label).text

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))
	var resolution_title := (battle_scene.get("_dialog_title") as Label).text
	var resolution_items: Array = battle_scene.get("_dialog_items_data")

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([1]))
	var preview_title := (battle_scene.get("_dialog_title") as Label).text
	var preview_dialog_data: Dictionary = battle_scene.get("_dialog_data")
	var preview_items: Array = preview_dialog_data.get("card_items", [])

	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array())

	return run_checks([
		assert_true(first_step_title.findn("discard") >= 0 or first_step_title.find("弃") >= 0, "Earthen Vessel should still ask the player to pay its discard cost first"),
		assert_true(resolution_items.size() == 2, "After paying the discard cost, Earthen Vessel should enter the empty-search resolution step"),
		assert_eq(resolution_items.size(), 2, "Earthen Vessel whiffs should offer continue and preview options"),
		assert_true(preview_items.size() == 2, "Choosing preview after an Earthen Vessel whiff should open the deck preview"),
		assert_eq(preview_items.size(), 2, "Earthen Vessel whiff previews should show the remaining deck"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "After closing the empty-search preview, the trainer interaction should finish cleanly"),
		assert_true(discard_cost in player.discard_pile, "Earthen Vessel should still discard the paid cost card on a whiff"),
		assert_false(earthen_vessel in player.hand, "Earthen Vessel should not remain in hand after the empty-search flow finishes"),
		assert_true(earthen_vessel in player.discard_pile, "Earthen Vessel should still be consumed after closing the empty-search preview"),
	])


