extends "res://tests/helpers/BattleUIFeaturesShared.gd"


func _scene_with_cards() -> Control:
	var previous_profile := GameManager.ui_runtime_profile
	var previous_mode := GameManager.current_mode
	GameManager.ui_runtime_profile = UiRuntimeProfile.new({
		"host_kind": UiRuntimeProfile.HOST_NATIVE,
		"native_os": UiRuntimeProfile.OS_ANDROID,
		"pointer_mode": UiRuntimeProfile.POINTER_TOUCH,
		"mobile_like": true,
	})
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var scene := _prepare_real_portrait_battle_scene()
	scene.set_meta("previous_profile", previous_profile)
	scene.set_meta("previous_mode", previous_mode)
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 4
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Active", 200, "C"), pi))
		player.active_pokemon = slot
		player.set_prizes(_make_named_deck_cards(pi, ["Prize A", "Prize B", "Prize C"]))
		gsm.game_state.players.append(player)
	scene.set("_gsm", gsm)
	scene.set("_hand_container", scene.find_child("HandContainer", true, false))
	scene.set("_discard_overlay", scene.find_child("DiscardOverlay", true, false))
	scene.set("_discard_title", scene.find_child("DiscardTitle", true, false))
	scene.set("_discard_list", scene.find_child("DiscardList", true, false))
	scene.set("_detail_overlay", scene.find_child("DetailOverlay", true, false))
	scene.call("_configure_battle_pointer_input_for_tests", true)
	return scene


func _free_scene(scene: Control) -> void:
	GameManager.ui_runtime_profile = scene.get_meta("previous_profile")
	GameManager.current_mode = scene.get_meta("previous_mode")
	scene.free()


func _touch(pressed: bool, position: Vector2 = Vector2(300, 400)) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = pressed
	event.position = position
	return event


func _mouse(pressed: bool, device: int = 0, position: Vector2 = Vector2(300, 400)) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.device = device
	event.position = position
	event.global_position = position
	return event


func _draw_action(card: CardInstance) -> GameAction:
	return GameAction.create(GameAction.ActionType.DRAW_CARD, card.owner_index,
		{"count": 1, "card_instance_ids": [card.instance_id], "card_names": [card.get_name()]}, 4)


func test_prize_commit_owns_android_echo_after_dialog_closes() -> String:
	var scene := _scene_with_cards()
	var gsm: GameStateMachine = scene.get("_gsm")
	gsm.set("_pending_prize_player_index", 0)
	gsm.set("_pending_prize_remaining", 1)
	scene.call("_start_prize_selection", 0, 1)
	var press := _touch(true)
	scene.call("_observe_battle_pointer_event", press)
	scene.call("_on_prize_slot_input", press, 0, "Prize", 0)
	var release := _touch(false)
	scene.call("_observe_battle_pointer_event", release)
	scene.call("_on_prize_slot_input", release, 0, "Prize", 0)
	var router: RefCounted = scene.get("_battle_pointer_input_router")
	var result := run_checks([
		assert_eq(gsm.game_state.players[0].hand.size(), 1, "Prize commits once"),
		assert_true(router.call("should_block", _mouse(true), "battle_board"), "Unlabelled Android echo must not open LOST after prize dialog closes"),
		assert_true(router.call("should_block", _mouse(false, InputEvent.DEVICE_ID_EMULATION), "battle_board"), "Prize gesture owns its mouse release"),
		assert_false(router.call("should_block", _touch(true), "battle_board"), "An independent next tap must work immediately"),
	])
	_free_scene(scene)
	return result


func test_cancelled_prize_touch_does_not_take_a_card() -> String:
	var scene := _scene_with_cards()
	var gsm: GameStateMachine = scene.get("_gsm")
	gsm.set("_pending_prize_player_index", 0)
	gsm.set("_pending_prize_remaining", 1)
	scene.call("_start_prize_selection", 0, 1)
	scene.call("_on_prize_slot_input", _touch(true), 0, "Prize", 0)
	var release := _touch(false)
	release.canceled = true
	scene.call("_on_prize_slot_input", release, 0, "Prize", 0)
	var result := assert_eq(gsm.game_state.players[0].hand.size(), 0, "Android touch cancellation is not prize confirmation")
	_free_scene(scene)
	return result


func test_draw_overlay_blocks_both_direct_hud_entry_points() -> String:
	var scene := _scene_with_cards()
	var gsm: GameStateMachine = scene.get("_gsm")
	var card := CardInstance.create(_make_pokemon_cd("Drawn", 60, "C"), 0)
	gsm.game_state.players[0].hand.append(card)
	var controller: RefCounted = scene.get("_battle_draw_reveal_controller")
	controller.call("enqueue_reveal", scene, _draw_action(card))
	scene.call("_on_lost_zone_open_control_input", _touch(true), false)
	var lost_opened := (scene.get("_discard_overlay") as Control).visible
	(scene.get("_discard_overlay") as Control).hide()
	scene.call("_on_discard_open_control_input", _touch(true, Vector2(400, 400)), "my", "Discard")
	var result := run_checks([
		assert_false(lost_opened, "Draw confirmation must never open underlying LOST"),
		assert_false((scene.get("_discard_overlay") as Control).visible, "Draw confirmation must never open underlying discard"),
	])
	_free_scene(scene)
	return result


func test_draw_confirm_owns_tail_after_synchronous_completion() -> String:
	var scene := _scene_with_cards()
	var gsm: GameStateMachine = scene.get("_gsm")
	var card := CardInstance.create(_make_pokemon_cd("Confirmed", 60, "C"), 0)
	gsm.game_state.players[0].hand.append(card)
	var controller: RefCounted = scene.get("_battle_draw_reveal_controller")
	controller.call("enqueue_reveal", scene, _draw_action(card))
	var press := _touch(true)
	scene.call("_observe_battle_pointer_event", press)
	(scene.get("_draw_reveal_overlay") as Control).gui_input.emit(press)
	var router: RefCounted = scene.get("_battle_pointer_input_router")
	var result := run_checks([
		assert_false(scene.get("_draw_reveal_active"), "Confirmation completes in detached test scene"),
		assert_true(router.call("should_block", _mouse(true), "battle_board"), "Confirmation echo remains owned after overlay is hidden"),
	])
	_free_scene(scene)
	return result


func test_queued_draw_keeps_exact_cards_after_zone_changes() -> String:
	var scene := _scene_with_cards()
	var gsm: GameStateMachine = scene.get("_gsm")
	var cards := _make_named_deck_cards(0, ["First draw", "Second draw"])
	gsm.game_state.players[0].hand.assign(cards)
	var controller: RefCounted = scene.get("_battle_draw_reveal_controller")
	controller.call("enqueue_reveal", scene, _draw_action(cards[0]))
	var second_action := _draw_action(cards[1])
	controller.call("enqueue_reveal", scene, second_action)
	# Another effect may already have moved the card while the first animation waits.
	gsm.game_state.players[0].hand.erase(cards[1])
	gsm.game_state.players[0].discard_pile.append(cards[1])
	second_action.data["card_instance_ids"] = [cards[0].instance_id]
	controller.call("confirm_current_reveal", scene)
	var views: Array = scene.get("_draw_reveal_card_views")
	var shown: CardInstance = views[0].card_instance if not views.is_empty() else null
	var current: GameAction = scene.get("_draw_reveal_current_action")
	var result := run_checks([
		assert_eq(shown, cards[1], "Queued animation must preserve the exact second draw, not consult a later hand or changed log"),
		assert_eq(current.data.get("card_instance_ids", []) if current != null else [], [cards[1].instance_id], "Reveal identity is a presentation-local copy"),
	])
	_free_scene(scene)
	return result


func test_forced_draw_completion_clears_views_and_queued_work() -> String:
	var scene := _scene_with_cards()
	var gsm: GameStateMachine = scene.get("_gsm")
	var cards := _make_named_deck_cards(0, ["First", "Stale second"])
	gsm.game_state.players[0].hand.assign(cards)
	var controller: RefCounted = scene.get("_battle_draw_reveal_controller")
	controller.call("enqueue_reveal", scene, _draw_action(cards[0]))
	controller.call("enqueue_reveal", scene, _draw_action(cards[1]))
	controller.call("_finish_all_reveals", scene)
	controller.call("resume_if_ready", scene)
	var result := run_checks([
		assert_false(scene.get("_draw_reveal_active"), "Recovery cannot restart an obsolete queued draw"),
		assert_eq((scene.get("_draw_reveal_card_views") as Array).size(), 0, "Recovery must release stale card views"),
		assert_eq((scene.get("_draw_reveal_queue") as Array).size(), 0, "Recovery must clear the pending queue"),
	])
	_free_scene(scene)
	return result


func test_real_draw_batch_reveal_and_hand_keep_the_same_instance_order() -> String:
	var scene := _scene_with_cards()
	var gsm: GameStateMachine = scene.get("_gsm")
	var player := gsm.game_state.players[0]
	var cards := _make_named_deck_cards(0, ["Same name", "Other card", "Same name"])
	player.deck.assign(cards)
	var controller: RefCounted = scene.get("_battle_draw_reveal_controller")
	gsm.action_logged.connect(func(action: GameAction) -> void:
		controller.call("enqueue_reveal", scene, action)
	)
	var drawn := gsm.draw_cards_for_effect(0, 3)
	var views: Array = scene.get("_draw_reveal_card_views")
	var shown: Array[CardInstance] = []
	for view: BattleCardView in views:
		shown.append(view.card_instance)
	controller.call("confirm_current_reveal", scene)
	var hand: Array[CardInstance] = []
	for view: Node in (scene.get("_hand_container") as Node).get_children():
		if view is BattleCardView:
			hand.append(view.card_instance)
	var result := run_checks([
		assert_eq(drawn.size(), 3, "The engine must draw all three cards"),
		assert_eq(shown, drawn, "Every revealed card is the exact instance drawn, including duplicate names"),
		assert_eq(hand, drawn, "Landing renders the same ordered instances into hand"),
		assert_false(gsm.action_log.back().has_meta(&"draw_reveal_cards"), "Presentation references cannot contaminate the engine log"),
	])
	_free_scene(scene)
	return result


func test_queued_draw_survives_the_card_leaving_hand_before_playback() -> String:
	var scene := _scene_with_cards()
	var gsm: GameStateMachine = scene.get("_gsm")
	var cards := _make_named_deck_cards(0, ["First", "Moved before reveal"])
	gsm.game_state.players[0].hand.assign(cards)
	var controller: RefCounted = scene.get("_battle_draw_reveal_controller")
	controller.call("enqueue_reveal", scene, _draw_action(cards[0]))
	controller.call("enqueue_reveal", scene, _draw_action(cards[1]))
	gsm.game_state.players[0].hand.erase(cards[1])
	gsm.game_state.players[0].discard_pile.append(cards[1])
	controller.call("confirm_current_reveal", scene)
	var views: Array = scene.get("_draw_reveal_card_views")
	var result := assert_eq(views[0].card_instance if not views.is_empty() else null,
		cards[1], "A later zone change must not erase the recorded draw animation")
	_free_scene(scene)
	return result


func test_cancelled_card_touch_never_activates_prize_hand_or_gallery() -> String:
	var clicks := [0]
	for mode: String in [BattleCardView.MODE_PREVIEW, BattleCardView.MODE_HAND]:
		var card := BattleCardView.new()
		card.setup_from_instance(CardInstance.create(_make_pokemon_cd("Cancelled", 60, "C"), 0), mode)
		card.left_clicked.connect(func(_instance: CardInstance, _data: CardData) -> void: clicks[0] += 1)
		card.call("_gui_input", _touch(true))
		var release := _touch(false)
		release.canceled = true
		card.call("_gui_input", release)
		card.free()
	return assert_eq(clicks[0], 0, "System-cancelled touches must not activate cards through their own GUI handler")


func test_cancelled_native_hud_touch_never_presses_button() -> String:
	var root := Control.new()
	root.size = Vector2(300, 200)
	var button := Button.new()
	button.size = Vector2(300, 200)
	root.add_child(button)
	var adapter := IosWebHudTouchAdapter.new()
	adapter.configure(UiRuntimeProfile.new({"host_kind": UiRuntimeProfile.HOST_NATIVE,
		"native_os": UiRuntimeProfile.OS_ANDROID, "pointer_mode": UiRuntimeProfile.POINTER_TOUCH, "mobile_like": true}))
	IosWebHudTouchAdapter.mark_hud_root(root)
	var clicks := [0]
	button.pressed.connect(func() -> void: clicks[0] += 1)
	adapter.handle_event(root, _touch(true, Vector2(30, 30)))
	var release := _touch(false, Vector2(30, 30))
	release.canceled = true
	adapter.handle_event(root, release)
	var result := assert_eq(clicks[0], 0, "Cancelled native HUD gestures cannot confirm or play another card")
	root.free()
	return result


func test_gui_claim_preserves_viewport_coordinates_and_other_fingers() -> String:
	var router := BattlePointerInputRouter.new()
	router.configure(true)
	var viewport_point := Vector2(500, 800)
	var first := _touch(true, viewport_point)
	router.observe(first)
	var claimed := router.claim_gui_event(_touch(true, Vector2(20, 30)), "prize", "battle_modal")
	var other := _touch(true, Vector2(800, 300))
	other.index = 1
	router.observe(other)
	var release := _touch(false, viewport_point)
	router.observe(release)
	router.cancel_all("hand_changed", -1, "battle_modal")
	return run_checks([
		assert_true(claimed, "Localized GUI events must claim their existing viewport sequence"),
		assert_true(router.should_block(_mouse(true, InputEvent.DEVICE_ID_EMULATION, viewport_point), "board"), "Echo matching must retain the original viewport position after hand rebuild"),
		assert_eq(router.active_sequence_count(), 0, "An unrelated unfinished hand gesture must still be cancelled"),
	])


func test_release_callback_can_claim_only_its_current_dispatch() -> String:
	var router := BattlePointerInputRouter.new()
	router.observe(_touch(true))
	router.observe(_touch(false))
	var claimed := router.claim_current("prize", "battle_modal")
	var stale := BattlePointerInputRouter.new()
	stale.observe(_touch(true))
	stale.observe(_touch(false))
	await (Engine.get_main_loop() as SceneTree).process_frame
	return run_checks([
		assert_true(claimed, "The GUI callback follows _input release and must still own that dispatch"),
		assert_false(stale.claim_current("unrelated_action", "battle_modal"), "An older completed release cannot be claimed by later programmatic work"),
	])


func test_cancelled_surface_gesture_does_not_activate_or_remain_pending() -> String:
	var router := BattlePointerInputRouter.new()
	var controller := BattlePointerSurfaceController.new()
	controller.configure(router, true)
	var clicks := [0]
	controller.reconcile_surface("hand", "one_card", {
		"contains": func(_position: Vector2) -> bool: return true,
		"target_at": func(_position: Vector2) -> int: return 1,
		"activate": func(_key: Variant, _generation: int) -> void: clicks[0] += 1,
	})
	var press := _touch(true)
	controller.handle_event(press, router.observe(press))
	var cancel := _touch(false)
	cancel.canceled = true
	controller.handle_event(cancel, router.observe(cancel))
	return run_checks([
		assert_eq(clicks[0], 0, "Cancelling the semantic hand surface cannot choose a card"),
		assert_eq(controller.active_gesture_count(), 0, "The cancelled surface cannot retain a pending tap"),
		assert_eq(router.active_sequence_count(), 0, "The cancelled pointer is no longer active"),
	])


func _tree_scene_for_animation(fixture: Control) -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Control = BattleScenePacked.instantiate()
	scene.set("_battle_mode", "review_readonly")
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	scene.set("_battle_mode", "live")
	scene.set("_gsm", fixture.get("_gsm"))
	scene.set("_view_player", 0)
	scene.call("_refresh_ui")
	return scene


func test_old_draw_tween_cannot_change_the_next_reveal_after_recovery() -> String:
	var fixture := _scene_with_cards()
	var scene := await _tree_scene_for_animation(fixture)
	var gsm: GameStateMachine = scene.get("_gsm")
	var cards := _make_named_deck_cards(0, ["Interrupted draw", "Current draw"])
	gsm.game_state.players[0].hand.assign(cards)
	var controller: RefCounted = scene.get("_battle_draw_reveal_controller")
	controller.call("enqueue_reveal", scene, _draw_action(cards[0]))
	controller.call("_finish_all_reveals", scene)
	controller.call("enqueue_reveal", scene, _draw_action(cards[1]))
	await scene.get_tree().create_timer(0.5).timeout
	var views: Array = scene.get("_draw_reveal_card_views")
	var stage := (scene.get("_draw_reveal_overlay") as Control).get_node("Stage")
	var result := run_checks([
		assert_eq(stage.get_child_count(), 1, "Interrupted animation clones must leave the stage"),
		assert_eq(views[0].card_instance if not views.is_empty() else null, cards[1], "Old tween callbacks cannot replace the new draw"),
		assert_true(scene.get("_draw_reveal_waiting_for_confirm"), "Only the new reveal owns the confirmation state"),
	])
	scene.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	_free_scene(fixture)
	return result


func test_leaving_battle_during_draw_releases_animation_controller() -> String:
	var fixture := _scene_with_cards()
	var scene := await _tree_scene_for_animation(fixture)
	var gsm: GameStateMachine = scene.get("_gsm")
	var card := CardInstance.create(_make_pokemon_cd("Unfinished draw", 60, "C"), 0)
	gsm.game_state.players[0].hand.append(card)
	var controller: RefCounted = scene.get("_battle_draw_reveal_controller")
	var controller_ref: WeakRef = weakref(controller)
	controller.call("enqueue_reveal", scene, _draw_action(card))
	controller = null
	scene.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	var result := assert_null(controller_ref.get_ref(), "Leaving battle must release the animation owner and its callbacks")
	_free_scene(fixture)
	return result


func test_recovered_prize_animation_cannot_rebind_a_reused_slot() -> String:
	var fixture := _scene_with_cards()
	var scene := await _tree_scene_for_animation(fixture)
	var gsm: GameStateMachine = scene.get("_gsm")
	var prize_view: BattleCardView = scene.get("_my_prize_slots")[0]
	var old_card := gsm.game_state.players[0].get_prize_at_slot(0)
	var replacements := _make_named_deck_cards(0, ["Replacement prize", "Remaining prize"])
	scene.set("_pending_prize_animating", true)
	scene.set("_prize_animation_generation", 1)
	var completed := [0]
	scene.call("_animate_prize_flip", prize_view, old_card, func() -> void: completed[0] += 1)
	gsm.game_state.players[0].set_prizes(replacements)
	scene.call("_ai_watchdog_force_finish_prize_animation")
	await scene.get_tree().create_timer(0.45).timeout
	var result := run_checks([
		assert_eq(prize_view.card_instance, replacements[0], "A recovered prize flip cannot repaint a reused slot with an old card"),
		assert_eq(completed[0], 0, "Retired prize animation callbacks must not complete a later presentation"),
		assert_eq(prize_view.scale, Vector2.ONE, "Recovery restores the prize slot scale"),
	])
	scene.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	_free_scene(fixture)
	return result


func test_prize_animation_blocks_background_actions_until_completion() -> String:
	var fixture := _scene_with_cards()
	var scene := await _tree_scene_for_animation(fixture)
	var gsm: GameStateMachine = scene.get("_gsm")
	gsm.set("_pending_prize_player_index", 0)
	gsm.set("_pending_prize_remaining", 1)
	scene.call("_start_prize_selection", 0, 1)
	scene.call("_try_take_prize_from_slot", 0, 0)
	var animating := bool(scene.get("_pending_prize_animating"))
	var accepts_background_action := bool(scene.call("_can_accept_live_action"))
	await scene.get_tree().create_timer(0.45).timeout
	var result := run_checks([
		assert_true(animating, "Closing the last prize dialog must not clear the still-running presentation lock"),
		assert_false(accepts_background_action, "Background actions cannot execute during the prize flip"),
		assert_false(scene.get("_pending_prize_animating"), "Completion releases the presentation lock"),
		assert_eq(gsm.game_state.players[0].hand.size(), 1, "Presentation gating never repeats the prize transaction"),
	])
	scene.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	_free_scene(fixture)
	return result


func test_rotated_hud_hit_test_has_one_coordinate_space() -> String:
	var scene := _scene_with_cards()
	scene.set("_rotated_portrait_canvas_active", true)
	scene.set("_rotated_portrait_physical_viewport_size", Vector2(1600, 900))
	scene.position = Vector2(1600, 0)
	scene.rotation = PI / 2.0
	var hud := Control.new()
	hud.position = Vector2(100, 200)
	hud.size = Vector2(80, 60)
	scene.add_child(hud)
	var rendered_center := hud.get_global_transform() * (hud.size * 0.5)
	var result := run_checks([
		assert_true(scene.call("_battle_hud_control_contains_touch", hud, rendered_center), "Actual rotated HUD is clickable"),
		assert_false(scene.call("_battle_hud_control_contains_touch", hud, hud.position + hud.size * 0.5), "Unrotated ghost rectangle must not intercept prize taps"),
	])
	_free_scene(scene)
	return result


func test_viewport_prize_touch_and_mouse_echo_do_not_open_lost() -> String:
	return await _viewport_prize_echo_case(false)


func test_viewport_prize_mouse_first_echo_does_not_open_lost() -> String:
	return await _viewport_prize_echo_case(true)


func _viewport_prize_echo_case(mouse_first: bool) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_size := tree.root.size
	var previous_scale := tree.root.content_scale_size
	var previous_window := DisplayServer.window_get_size()
	var previous_layout := GameManager.battle_layout_mode
	var previous_effects := GameManager.battle_effects_enabled
	var fixture := _scene_with_cards()
	var gsm: GameStateMachine = fixture.get("_gsm")
	var profile := GameManager.ui_runtime_profile
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	GameManager.battle_effects_enabled = false
	DisplayServer.window_set_size(Vector2i(900, 1600))
	tree.root.size = Vector2i(900, 1600)
	tree.root.content_scale_size = Vector2i(900, 1600)
	var scene: Control = BattleScenePacked.instantiate()
	# Suppress match startup, then use the ordinary live UI with a fixed rules state.
	scene.set("_battle_mode", "review_readonly")
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	GameManager.ui_runtime_profile = profile
	scene.set("_battle_mode", "live")
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.call("_configure_battle_pointer_runtime", profile)
	scene.get("_ios_web_hud_touch_adapter").configure(profile)
	gsm.set("_pending_prize_player_index", 0)
	gsm.set("_pending_prize_remaining", 1)
	scene.call("_refresh_ui")
	scene.call("_start_prize_selection", 0, 1)
	await tree.process_frame
	await tree.process_frame
	var prize: BattleCardView = scene.get("_my_prize_slots")[0]
	var position := prize.get_global_transform() * (prize.size * 0.5)
	var viewport := scene.get_viewport()
	if mouse_first:
		viewport.push_input(_mouse(true, 0, position), true)
	viewport.push_input(_touch(true, position), true)
	viewport.push_input(_touch(false, position), true)
	if mouse_first:
		viewport.push_input(_mouse(false, 0, position), true)
	var hand_after_prize := gsm.game_state.players[0].hand.size()
	var router: RefCounted = scene.get("_battle_pointer_input_router")
	var touch_diagnostics: Array = []
	for sequence: PointerSequence in router.get("_recent_touch_sequences"):
		touch_diagnostics.append(sequence.snapshot())
	var diagnostics := "position=%s now=%s touches=%s active=%s" % [position, Time.get_ticks_msec(), touch_diagnostics, router.call("active_snapshots")]
	# Place a real background LOST control under the now-closed prize dialog.
	var lost := scene.find_child("InfoMyLost", true, false) as Control
	lost.reparent(scene)
	lost.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	lost.position = scene.get_global_transform().affine_inverse() * position - Vector2(60, 30)
	lost.size = Vector2(120, 60)
	lost.show()
	if not mouse_first:
		viewport.push_input(_mouse(true, 0, position), true)
		viewport.push_input(_mouse(false, 0, position), true)
	var echo_opened := (scene.get("_discard_overlay") as Control).visible
	# The next physical touch must still open LOST immediately.
	viewport.push_input(_touch(true, position), true)
	viewport.push_input(_touch(false, position), true)
	var next_touch_opened := (scene.get("_discard_overlay") as Control).visible
	var result := run_checks([
		assert_eq(hand_after_prize, 1, "Viewport prize gesture must move exactly one card to hand"),
		assert_false(echo_opened, "Compatibility events at the closed prize position cannot open LOST: " + diagnostics),
		assert_true(next_touch_opened, "The next independent physical tap must open LOST without a cooldown"),
	])
	scene.queue_free()
	await tree.process_frame
	DisplayServer.window_set_size(previous_window)
	tree.root.size = previous_size
	tree.root.content_scale_size = previous_scale
	GameManager.battle_layout_mode = previous_layout
	GameManager.battle_effects_enabled = previous_effects
	_free_scene(fixture)
	return result
