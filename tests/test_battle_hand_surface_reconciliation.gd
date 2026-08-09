class_name TestBattleHandSurfaceReconciliation
extends TestBase

const SurfaceControllerScript := preload(
	"res://scripts/ui/battle/interactions/BattlePointerSurfaceController.gd"
)
const EffectSecretBoxScript := preload(
	"res://scripts/effects/trainer_effects/EffectSecretBox.gd"
)


func test_identical_refresh_reuses_hand_card_nodes_and_generation() -> String:
	var fixture: Dictionary = await _make_scene_fixture()
	var scene: Control = fixture["scene"]
	var state: GameState = fixture["state"]
	var first_inst: CardInstance = fixture["first_inst"]
	scene.call("_refresh_hand")
	await _frame()
	var hand_container := scene.get("_hand_container") as HBoxContainer
	var first_view := _card_view_for_instance(hand_container, first_inst.instance_id)
	var generation_before := int(scene.get("_hand_pointer_surface_generation"))

	scene.call("_refresh_hand")
	await _frame()
	var refreshed_view := _card_view_for_instance(
		hand_container,
		first_inst.instance_id
	)
	var generation_after := int(scene.get("_hand_pointer_surface_generation"))

	var result := run_checks([
		assert_true(first_view != null, "The fixture must render its first hand card"),
		assert_true(first_view == refreshed_view, "A visual-only refresh must reuse the existing BattleCardView"),
		assert_eq(generation_after, generation_before, "An unchanged semantic hand must keep its surface generation"),
		assert_eq(state.players[0].hand.size(), 1, "UI reconciliation must not mutate the game hand"),
	])
	await _dispose_fixture(scene)
	return result


func test_draw_and_play_only_add_or_remove_changed_card_nodes() -> String:
	var fixture: Dictionary = await _make_scene_fixture()
	var scene: Control = fixture["scene"]
	var state: GameState = fixture["state"]
	var first_inst: CardInstance = fixture["first_inst"]
	scene.call("_refresh_hand")
	await _frame()
	var hand_container := scene.get("_hand_container") as HBoxContainer
	var stable_first_view := _card_view_for_instance(
		hand_container,
		first_inst.instance_id
	)
	var generation_one := int(scene.get("_hand_pointer_surface_generation"))

	var second_inst := CardInstance.create(_make_item("Switch", "浜ゆ崲", "104"), 0)
	state.players[0].hand.append(second_inst)
	scene.call("_refresh_hand")
	await _frame()
	var first_after_draw := _card_view_for_instance(
		hand_container,
		first_inst.instance_id
	)
	var stable_second_view := _card_view_for_instance(
		hand_container,
		second_inst.instance_id
	)
	var generation_two := int(scene.get("_hand_pointer_surface_generation"))

	state.players[0].hand.erase(first_inst)
	scene.call("_refresh_hand")
	await _frame()
	var second_after_play := _card_view_for_instance(
		hand_container,
		second_inst.instance_id
	)
	var removed_first := _card_view_for_instance(
		hand_container,
		first_inst.instance_id
	)

	var result := run_checks([
		assert_true(stable_first_view == first_after_draw, "Drawing must not rebuild cards already in hand"),
		assert_true(stable_second_view != null, "Drawing must add the new card view"),
		assert_true(generation_two > generation_one, "Changing ordered hand membership must advance generation"),
		assert_true(stable_second_view == second_after_play, "Playing another card must preserve unaffected card views"),
		assert_true(removed_first == null, "A card that left the hand must be removed from the UI"),
		assert_eq(hand_container.get_child_count(), 1, "The hand row must contain exactly the current semantic hand"),
	])
	await _dispose_fixture(scene)
	return result


func test_android_same_size_search_replacement_keeps_new_cards_in_the_users_hand_viewport() -> String:
	var fixture: Dictionary = await _make_scene_fixture()
	var scene: Control = fixture["scene"]
	var state: GameState = fixture["state"]
	var android_touch := UiRuntimeProfile.new({
		"host_kind": UiRuntimeProfile.HOST_NATIVE,
		"native_os": UiRuntimeProfile.OS_ANDROID,
		"pointer_mode": UiRuntimeProfile.POINTER_TOUCH,
		"mobile_like": true,
	})
	scene.call("_configure_battle_pointer_runtime", android_touch)

	var original_hand: Array[CardInstance] = []
	for index: int in 8:
		original_hand.append(CardInstance.create(
			_make_item("Original %d" % index, "原手牌%d" % index, str(520 + index)),
			0
		))
	state.players[0].hand = original_hand.duplicate()
	var hand_scroll := scene.get("_hand_scroll") as ScrollContainer
	hand_scroll.reparent(scene)
	hand_scroll.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hand_scroll.position = Vector2(40, 40)
	hand_scroll.size = Vector2(420, 190)
	hand_scroll.custom_minimum_size = Vector2(420, 190)
	scene.call("_refresh_hand")
	await _frame()
	await _frame()
	var drag_coordinator := scene.get("_battle_drag_scroll_coordinator") as RefCounted
	var hand_container := scene.get("_hand_container") as HBoxContainer
	hand_container.size = Vector2(1600, 190)
	hand_container.custom_minimum_size.x = 1600
	var bar := hand_scroll.get_h_scroll_bar()
	bar.min_value = 0.0
	bar.max_value = 1600.0
	bar.page = 420.0
	hand_scroll.scroll_horizontal = 1000
	var scroll_before := hand_scroll.scroll_horizontal

	# Model Pokegear / Earthen Vessel / Secret Box membership replacement: the
	# source card leaves while the searched result is appended, so hand count is
	# unchanged and the user is already looking at the right edge where the card
	# was used.
	var searched := CardInstance.create(
		_make_trainer("Searched Supporter", "Supporter"),
		0
	)
	state.players[0].hand.erase(original_hand[6])
	state.players[0].hand.append(searched)
	scene.call("_refresh_hand")
	await _frame()
	await _frame()
	drag_coordinator.call("refresh_hand_drag_scroll_extents", hand_scroll)
	var scroll_after := hand_scroll.scroll_horizontal
	var searched_view := _card_view_for_instance(hand_container, searched.instance_id)
	var searched_visible := (
		searched_view != null
		and hand_scroll.get_global_rect().intersects(searched_view.get_global_rect())
	)

	var result := run_checks([
		assert_gt(scroll_before, 0, "The fixture must begin on an overflowing hand's right edge"),
		assert_gt(scroll_after, 0, "A semantic hand generation must not throw the Android viewport back to the first card"),
		assert_true(searched_visible, "The newly searched replacement card must remain visible where the user completed the search"),
	])
	await _dispose_fixture(scene)
	return result


func test_android_search_additions_are_revealed_from_the_left_edge() -> String:
	var fixture: Dictionary = await _make_scene_fixture()
	var scene: Control = fixture["scene"]
	var state: GameState = fixture["state"]
	var original_hand: Array[CardInstance] = []
	for index: int in 8:
		original_hand.append(CardInstance.create(
			_make_item("Left Edge %d" % index, "左侧手牌%d" % index, str(540 + index)),
			0
		))
	state.players[0].hand = original_hand.duplicate()
	var hand_scroll := scene.get("_hand_scroll") as ScrollContainer
	hand_scroll.reparent(scene)
	hand_scroll.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hand_scroll.position = Vector2(40, 40)
	hand_scroll.size = Vector2(420, 190)
	hand_scroll.custom_minimum_size = Vector2(420, 190)
	scene.call("_refresh_hand")
	await _frame()
	await _frame()
	var hand_container := scene.get("_hand_container") as HBoxContainer
	hand_container.size = Vector2(1600, 190)
	hand_container.custom_minimum_size.x = 1600
	var bar := hand_scroll.get_h_scroll_bar()
	bar.min_value = 0.0
	bar.max_value = 1600.0
	bar.page = 420.0
	hand_scroll.scroll_horizontal = 0

	var searched_a := CardInstance.create(_make_item("Search A", "检索牌A", "551"), 0)
	var searched_b := CardInstance.create(_make_item("Search B", "检索牌B", "552"), 0)
	state.players[0].hand.erase(original_hand[0])
	state.players[0].hand.erase(original_hand[1])
	state.players[0].hand.append(searched_a)
	state.players[0].hand.append(searched_b)
	scene.call("_refresh_hand")
	await _frame()
	await _frame()
	await _frame()

	var searched_a_view := _card_view_for_instance(hand_container, searched_a.instance_id)
	var searched_b_view := _card_view_for_instance(hand_container, searched_b.instance_id)
	var viewport_rect := hand_scroll.get_global_rect()
	var result := run_checks([
		assert_gt(hand_scroll.scroll_horizontal, 0, "Search-to-hand additions must move an overflowing Android hand away from a stale left edge"),
		assert_true(searched_a_view != null and viewport_rect.intersects(searched_a_view.get_global_rect()), "The first searched card must be brought into the visible hand viewport"),
		assert_true(searched_b_view != null and viewport_rect.intersects(searched_b_view.get_global_rect()), "The second searched card must be brought into the visible hand viewport"),
	])
	await _dispose_fixture(scene)
	return result


func test_hand_generation_fallback_reprojects_corrupted_membership_without_another_change() -> String:
	var fixture: Dictionary = await _make_scene_fixture()
	var scene: Control = fixture["scene"]
	var state: GameState = fixture["state"]
	var stable_card: CardInstance = fixture["first_inst"]
	scene.call("_refresh_hand")
	await _frame()
	scene.set("_responsive_layout_stabilization_frames_remaining", 0)
	scene.set_process(false)
	var searched := CardInstance.create(_make_item("Fallback Search", "兜底检索牌", "553"), 0)
	state.players[0].hand.append(searched)
	scene.call("_refresh_hand")
	var generation_after_change := int(scene.get("_hand_pointer_surface_generation"))
	var hand_container := scene.get("_hand_container") as HBoxContainer
	var searched_view := _card_view_for_instance(hand_container, searched.instance_id)
	if searched_view != null:
		hand_container.remove_child(searched_view)
		searched_view.queue_free()

	# No further state mutation or explicit refresh is allowed. The post-commit
	# integrity pass must notice that the semantic generation and rendered
	# membership diverged, then replay the idempotent projection once.
	await _frame()
	await _frame()
	await _frame()
	await _frame()
	var result := run_checks([
		assert_eq(_rendered_hand_instance_ids(hand_container), [stable_card.instance_id, searched.instance_id], "The fallback must restore exact ordered hand membership without waiting for another card action"),
		assert_eq(int(scene.get("_hand_pointer_surface_generation")), generation_after_change, "A visual fallback must not invent another semantic hand generation"),
	])
	await _dispose_fixture(scene)
	return result


func test_android_secret_box_reconciles_authoritative_hand_after_interaction() -> String:
	var fixture: Dictionary = await _make_scene_fixture()
	var scene: Control = fixture["scene"]
	var state: GameState = fixture["state"]
	var gsm := scene.get("_gsm") as GameStateMachine
	var previous_mode: int = GameManager.current_mode
	var previous_effects_enabled: bool = GameManager.battle_effects_enabled
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.battle_effects_enabled = true
	var android_touch := UiRuntimeProfile.new({
		"host_kind": UiRuntimeProfile.HOST_NATIVE,
		"native_os": "Android",
		"pointer_mode": UiRuntimeProfile.POINTER_TOUCH,
		"mobile_like": true,
	})
	scene.call("_configure_battle_pointer_runtime", android_touch)

	var secret_box_data := _make_item("Secret Box", "秘密箱", "176")
	secret_box_data.effect_id = "e92a86246f44351d023bd4fa271089aa"
	var secret_box := CardInstance.create(secret_box_data, 0)
	var discard_a := CardInstance.create(_make_item("Discard A", "弃牌A", "501"), 0)
	var discard_b := CardInstance.create(_make_item("Discard B", "弃牌B", "502"), 0)
	var discard_c := CardInstance.create(_make_item("Discard C", "弃牌C", "503"), 0)
	var searched_item := CardInstance.create(_make_item("Search Item", "检索物品", "504"), 0)
	var searched_tool := CardInstance.create(_make_trainer("Search Tool", "Tool"), 0)
	var searched_supporter := CardInstance.create(_make_trainer("Search Supporter", "Supporter"), 0)
	var searched_stadium := CardInstance.create(_make_trainer("Search Stadium", "Stadium"), 0)
	state.players[0].hand = [secret_box, discard_a, discard_b, discard_c]
	state.players[0].deck = [searched_item, searched_tool, searched_supporter, searched_stadium]
	var action_callback := Callable(scene, "_on_action_logged")
	if not gsm.action_logged.is_connected(action_callback):
		gsm.action_logged.connect(action_callback)
	scene.call("_refresh_hand")
	await _frame()
	var initial_generation := int(scene.get("_hand_pointer_surface_generation"))

	var steps: Array[Dictionary] = EffectSecretBoxScript.new().get_interaction_steps(secret_box, state)
	scene.call("_start_effect_interaction", "trainer", 0, steps, secret_box)
	scene.call("_handle_effect_interaction_choice", PackedInt32Array([0, 1, 2]))
	for _search_step: int in 4:
		scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))

	await (Engine.get_main_loop() as SceneTree).create_timer(0.35).timeout
	await _frame()
	await _frame()
	var hand_container := scene.get("_hand_container") as HBoxContainer
	var expected_hand := [searched_item, searched_tool, searched_supporter, searched_stadium]
	var rendered_ids: Array[int] = []
	for child: Node in hand_container.get_children():
		var card_view := child as BattleCardView
		if card_view != null and card_view.card_instance != null:
			rendered_ids.append(card_view.card_instance.instance_id)
	var expected_ids: Array[int] = []
	for card: CardInstance in expected_hand:
		expected_ids.append(card.instance_id)

	var result := run_checks([
		assert_eq(str(scene.get("_pending_choice")), "", "Secret Box should close its interaction after all four searches"),
		assert_eq(state.players[0].hand, expected_hand, "Secret Box should commit the four searched cards as the authoritative hand"),
		assert_true(secret_box in state.players[0].discard_pile, "Secret Box should leave the hand after use"),
		assert_true(discard_a in state.players[0].discard_pile and discard_b in state.players[0].discard_pile and discard_c in state.players[0].discard_pile, "Secret Box should discard its three-card cost"),
		assert_eq(rendered_ids, expected_ids, "Android hand controls must reconcile to the authoritative ordered hand after the modal and discard animation finish"),
		assert_true(int(scene.get("_hand_pointer_surface_generation")) > initial_generation, "Changed hand membership must advance the Android pointer-surface generation"),
	])
	GameManager.current_mode = previous_mode
	GameManager.battle_effects_enabled = previous_effects_enabled
	await _dispose_fixture(scene)
	return result


func test_android_public_search_reconciles_after_the_rule_transaction_finishes() -> String:
	var fixture: Dictionary = await _make_scene_fixture()
	var scene: Control = fixture["scene"]
	var state: GameState = fixture["state"]
	var stable_card: CardInstance = fixture["first_inst"]
	var android_touch := UiRuntimeProfile.new({
		"host_kind": UiRuntimeProfile.HOST_NATIVE,
		"native_os": "Android",
		"pointer_mode": UiRuntimeProfile.POINTER_TOUCH,
		"mobile_like": true,
	})
	scene.call("_configure_battle_pointer_runtime", android_touch)
	scene.call("_refresh_hand")
	await _frame()
	# Remove startup layout repaints from the fixture. The assertion must be
	# satisfied by the zone-projection contract itself, not an unrelated resize.
	scene.set("_responsive_layout_stabilization_frames_remaining", 0)
	scene.set_process(false)

	# A public-search action is emitted from inside the effect transaction. The
	# rule engine may still remove costs/source cards before returning to the UI.
	var searched_a := CardInstance.create(_make_item("Searched A", "检索A", "511"), 0)
	var searched_b := CardInstance.create(_make_item("Searched B", "检索B", "512"), 0)
	state.players[0].hand.append(searched_a)
	var action_data: Dictionary = {}
	BattleZoneChangeContract.append_to_data(
		action_data,
		0,
		BattleZoneChangeContract.ZONE_DECK,
		BattleZoneChangeContract.ZONE_HAND,
		[searched_a.instance_id],
		BattleZoneChangeContract.PROJECTION_IMMEDIATE
	)
	var public_action := GameAction.create(
		GameAction.ActionType.PUBLIC_REVEAL,
		0,
		action_data,
		state.turn_number,
		"public search"
	)
	scene.call("_on_action_logged", public_action)
	# Finish the same synchronous rule transaction after observers have seen the
	# action. A synchronous repaint here captures the wrong intermediate hand.
	state.players[0].hand.erase(stable_card)
	state.players[0].hand.append(searched_b)
	await _frame()
	await _frame()

	var hand_container := scene.get("_hand_container") as HBoxContainer
	var rendered_ids: Array[int] = []
	for child: Node in hand_container.get_children():
		var card_view := child as BattleCardView
		if card_view != null and card_view.card_instance != null:
			rendered_ids.append(card_view.card_instance.instance_id)
	var expected_ids := [searched_a.instance_id, searched_b.instance_id]
	var result := run_checks([
		assert_eq(state.players[0].hand, [searched_a, searched_b], "The fixture must finish with the post-transaction authoritative hand"),
		assert_eq(rendered_ids, expected_ids, "Android projection must reconcile after the emitting rule transaction, not synchronously to its intermediate hand"),
	])
	await _dispose_fixture(scene)
	return result


func test_authoritative_hand_reconcile_waits_for_and_survives_visual_barrier() -> String:
	var fixture: Dictionary = await _make_scene_fixture()
	var scene: Control = fixture["scene"]
	var state: GameState = fixture["state"]
	var first_inst: CardInstance = fixture["first_inst"]
	scene.call("_refresh_hand")
	await _frame()
	scene.set("_responsive_layout_stabilization_frames_remaining", 0)
	scene.set_process(false)

	var searched := CardInstance.create(_make_item("Barrier Search", "展示屏障检索", "513"), 0)
	state.players[0].hand.append(searched)
	scene.set("_draw_reveal_active", true)
	scene.set("_draw_reveal_allow_hand_refresh_during_fly", false)
	scene.call("_request_authoritative_hand_reconciliation", "test_visual_barrier")
	await _frame()
	await _frame()
	var hand_container := scene.get("_hand_container") as HBoxContainer
	var rendered_while_blocked := _rendered_hand_instance_ids(hand_container)
	var pending_while_blocked := bool(scene.get("_authoritative_hand_reconcile_pending"))

	scene.set("_draw_reveal_active", false)
	scene.call("_request_authoritative_hand_reconciliation", "test_visual_barrier_complete")
	scene.call("_flush_authoritative_hand_reconciliation")
	var rendered_after_boundary := _rendered_hand_instance_ids(hand_container)
	var result := run_checks([
		assert_eq(rendered_while_blocked, [first_inst.instance_id], "A reveal barrier must keep unrevealed membership off the hand surface"),
		assert_true(pending_while_blocked, "A blocked reconciliation request must remain latched instead of being dropped"),
		assert_eq(rendered_after_boundary, [first_inst.instance_id, searched.instance_id], "The latched request must reconcile exact membership at the presentation boundary"),
		assert_false(bool(scene.get("_authoritative_hand_reconcile_pending")), "A successful boundary flush must consume the reconciliation request"),
	])
	await _dispose_fixture(scene)
	return result


func test_missing_release_across_hand_generation_does_not_poison_next_tap() -> String:
	var fixture: Dictionary = await _make_scene_fixture()
	var scene: Control = fixture["scene"]
	var state: GameState = fixture["state"]
	var first_inst: CardInstance = fixture["first_inst"]
	scene.call("_configure_battle_pointer_input_for_tests", true)
	scene.call("_configure_battle_pointer_surface_for_tests", true)
	scene.call("_refresh_hand")
	await _frame()
	var hand_container := scene.get("_hand_container") as HBoxContainer
	var first_view := _card_view_for_instance(
		hand_container,
		first_inst.instance_id
	)
	var first_center := first_view.get_global_transform() * (first_view.size * 0.5)

	# Start a real pointer session and intentionally omit its release.
	scene.call("_input", _touch(true, first_center))
	var surface_controller: RefCounted = scene.get(
		"_battle_pointer_surface_controller"
	) as RefCounted
	var active_before_rebuild: int = int(
		surface_controller.call("active_gesture_count")
	)

	var second_inst := CardInstance.create(_make_item("Switch", "浜ゆ崲", "104"), 0)
	state.players[0].hand.append(second_inst)
	scene.call("_refresh_hand")
	await _frame()
	var active_after_rebuild: int = int(
		surface_controller.call("active_gesture_count")
	)
	scene.call("_input", _touch(false, first_center))

	var first_after_draw := _card_view_for_instance(
		hand_container,
		first_inst.instance_id
	)
	var next_center := first_after_draw.get_global_transform() * (
		first_after_draw.size * 0.5
	)
	scene.call("_input", _touch(true, next_center))
	scene.call("_input", _touch(false, next_center))
	var detail_overlay := scene.get("_detail_overlay") as Control

	var result := run_checks([
		assert_eq(active_before_rebuild, 1, "The fixture must begin with an incomplete hand pointer"),
		assert_eq(active_after_rebuild, 0, "Hand generation change must synchronously cancel the old gesture"),
		assert_true(first_view == first_after_draw, "The unaffected semantic card should still reuse its node"),
		assert_true(detail_overlay.visible, "The first complete tap after the cancelled generation must work"),
		assert_eq(int(surface_controller.call("active_gesture_count")), 0, "The successful tap must release pointer ownership"),
	])
	await _dispose_fixture(scene)
	return result


func test_runtime_profile_enables_surface_for_touch_hosts_only() -> String:
	var fixture: Dictionary = await _make_scene_fixture()
	var scene: Control = fixture["scene"]
	WebUiFeatureGate.set_test_mode(WebUiFeatureGate.MODE_V2)
	var web_touch := UiRuntimeProfile.new({
		"host_kind": UiRuntimeProfile.HOST_WEB,
		"pointer_mode": UiRuntimeProfile.POINTER_TOUCH,
		"mobile_like": true,
	})
	var web_mouse := UiRuntimeProfile.new({
		"host_kind": UiRuntimeProfile.HOST_WEB,
		"pointer_mode": UiRuntimeProfile.POINTER_MOUSE,
		"mobile_like": false,
	})
	var android_touch := UiRuntimeProfile.new({
		"host_kind": UiRuntimeProfile.HOST_NATIVE,
		"native_os": "Android",
		"pointer_mode": UiRuntimeProfile.POINTER_TOUCH,
		"mobile_like": true,
	})
	var native_mouse := UiRuntimeProfile.new({
		"host_kind": UiRuntimeProfile.HOST_NATIVE,
		"native_os": "Windows",
		"pointer_mode": UiRuntimeProfile.POINTER_MOUSE,
		"mobile_like": false,
	})
	scene.call("_configure_battle_pointer_runtime", web_touch)
	var surface_controller: RefCounted = scene.get(
		"_battle_pointer_surface_controller"
	) as RefCounted
	var web_touch_enabled := bool(surface_controller.call("is_enabled"))
	scene.call("_configure_battle_pointer_runtime", web_mouse)
	var web_mouse_enabled := bool(surface_controller.call("is_enabled"))
	scene.call("_configure_battle_pointer_runtime", android_touch)
	var android_touch_enabled := bool(surface_controller.call("is_enabled"))
	scene.call("_configure_battle_pointer_runtime", native_mouse)
	var native_mouse_enabled := bool(surface_controller.call("is_enabled"))
	WebUiFeatureGate.reset_for_tests()

	var result := run_checks([
		assert_true(web_touch_enabled, "Web touch with the v2 gate must enable the unified pointer surface"),
		assert_false(web_mouse_enabled, "Web mouse must keep the native Control input path"),
		assert_true(android_touch_enabled, "Native Android touch must share the unified pointer surface"),
		assert_false(native_mouse_enabled, "Native desktop mouse must keep the Control input path"),
	])
	await _dispose_fixture(scene)
	return result


func test_card_gallery_uses_surface_generation_and_semantic_activation() -> String:
	var fixture: Dictionary = await _make_scene_fixture()
	var scene: Control = fixture["scene"]
	scene.call("_configure_battle_pointer_input_for_tests", true)
	scene.call("_configure_battle_pointer_surface_for_tests", true)
	var scroll := ScrollContainer.new()
	var row := HBoxContainer.new()
	scene.add_child(scroll)
	scroll.add_child(row)
	var card_view := BattleCardView.new()
	card_view.setup_from_instance(
		CardInstance.create(_make_item("Switch", "娴溿倖宕?", "104"), 0),
		BattleCardView.MODE_PREVIEW
	)
	card_view.set_clickable(true)
	row.add_child(card_view)
	var clicked := {"count": 0}
	card_view.left_clicked.connect(
		func(_inst: CardInstance, _data: CardData) -> void:
			clicked["count"] = int(clicked["count"]) + 1
	)
	scene.call(
		"_configure_card_gallery_drag_scroll",
		scroll,
		row,
		"test_gallery"
	)
	scene.call("_configure_card_gallery_card_view", card_view, scroll, "test_gallery")
	scene.call("_set_card_gallery_drag_scroll_active", scroll, true)
	var surface_controller: RefCounted = scene.get(
		"_battle_pointer_surface_controller"
	) as RefCounted
	var surface_id := "gallery:%d" % scroll.get_instance_id()
	var generation := int(
		surface_controller.call("surface_generation", surface_id)
	)
	scene.call(
		"_activate_card_gallery_pointer_target",
		card_view.get_instance_id(),
		generation,
		row
	)
	scene.call("_set_card_gallery_drag_scroll_active", scroll, false)
	var generation_after_close := int(
		surface_controller.call("surface_generation", surface_id)
	)

	var result := run_checks([
		assert_true(generation > 0, "An active card gallery must register a surface generation"),
		assert_eq(int(clicked["count"]), 1, "Semantic gallery activation must preserve the existing left-click callback"),
		assert_eq(generation_after_close, 0, "Closing a gallery must unregister its pointer surface"),
	])
	await _dispose_fixture(scene)
	return result


func test_web_hand_drag_past_slop_stays_scrolled_while_scrollbar_range_is_stale() -> String:
	var fixture: Dictionary = await _make_scene_fixture()
	var scene: Control = fixture["scene"]
	var state: GameState = fixture["state"]
	for index: int in 9:
		state.players[0].hand.append(
			CardInstance.create(
				_make_item("Hand Card %d" % index, "手牌%d" % index, "%03d" % (200 + index)),
				0
			)
		)
	scene.call("_configure_battle_pointer_input_for_tests", true)
	scene.call("_configure_battle_pointer_surface_for_tests", true)
	scene.call("_refresh_hand")
	await _frame()

	var hand_scroll := scene.get("_hand_scroll") as ScrollContainer
	var hand_container := scene.get("_hand_container") as HBoxContainer
	hand_scroll.size = Vector2(420, 190)
	hand_scroll.custom_minimum_size = Vector2(420, 190)
	hand_container.size = Vector2(1600, 190)
	hand_container.custom_minimum_size.x = 1600
	var bar := hand_scroll.get_h_scroll_bar()
	bar.max_value = 420.0
	bar.page = 420.0
	hand_scroll.scroll_horizontal = 0

	var start := hand_scroll.get_global_transform() * Vector2(300, 90)
	scene.call("_input", _touch(true, start))
	scene.call("_input", _drag(start + Vector2(-16, 2), Vector2(-16, 2)))
	var scroll_after_drag := hand_scroll.scroll_horizontal
	scene.call("_input", _touch(false, start + Vector2(-16, 2)))
	var scroll_after_release := hand_scroll.scroll_horizontal
	var surface_controller := scene.get(
		"_battle_pointer_surface_controller"
	) as RefCounted
	var committed_taps := 0
	for trace_entry_variant: Variant in surface_controller.call("trace_snapshot"):
		var trace_entry: Dictionary = trace_entry_variant
		if str(trace_entry.get("kind", "")) == "gesture_tap_committed":
			committed_taps += 1

	var result := run_checks([
		assert_true(
			bool(scene.call("_hand_pointer_surface_has_overflow")),
			"Hand overflow must use live card geometry while Godot's scrollbar range is one layout frame stale"
		),
		assert_eq(scroll_after_drag, 4, "The hand row should apply only the 4px beyond drag slop, without jumping by the full finger delta"),
		assert_eq(scroll_after_release, 4, "A committed hand drag must preserve its scroll position on release"),
		assert_eq(
			committed_taps,
			0,
			"A committed hand drag must not open the card where the gesture started"
		),
	])
	await _dispose_fixture(scene)
	return result


func test_android_hand_surface_ignores_compatibility_mouse_motion_between_touch_drags() -> String:
	var fixture: Dictionary = await _make_scene_fixture()
	var scene: Control = fixture["scene"]
	var state: GameState = fixture["state"]
	for index: int in 9:
		state.players[0].hand.append(
			CardInstance.create(
				_make_item("Android Hand %d" % index, "Android Hand %d" % index, "%03d" % (500 + index)),
				0
			)
		)
	scene.call("_configure_battle_pointer_input_for_tests", true)
	scene.call("_configure_battle_pointer_surface_for_tests", true)
	scene.call("_refresh_hand")
	await _frame()

	var hand_scroll := scene.get("_hand_scroll") as ScrollContainer
	var hand_container := scene.get("_hand_container") as HBoxContainer
	hand_scroll.size = Vector2(420, 190)
	hand_scroll.custom_minimum_size = Vector2(420, 190)
	hand_container.size = Vector2(1600, 190)
	hand_container.custom_minimum_size.x = 1600
	var bar := hand_scroll.get_h_scroll_bar()
	bar.min_value = 0.0
	bar.max_value = 1600.0
	bar.page = 420.0
	hand_scroll.scroll_horizontal = 200

	var start := hand_scroll.get_global_transform() * Vector2(300, 90)
	scene.call("_input", _touch(true, start))
	scene.call("_input", _drag(start + Vector2(-16, 2), Vector2(-16, 2)))
	var scroll_after_first_touch_drag := hand_scroll.scroll_horizontal
	scene.call(
		"_input",
		_mouse_motion(
			start + Vector2(-16, 2),
			Vector2(-16, 2),
			MOUSE_BUTTON_MASK_LEFT,
			InputEvent.DEVICE_ID_EMULATION
		)
	)
	var scroll_after_mouse_echo := hand_scroll.scroll_horizontal
	scene.call("_input", _drag(start + Vector2(-20, 2), Vector2(-4, 0)))
	var scroll_after_second_touch_drag := hand_scroll.scroll_horizontal
	scene.call("_input", _touch(false, start + Vector2(-20, 2)))

	hand_scroll.scroll_horizontal = 200
	var right_start := hand_scroll.get_global_transform() * Vector2(240, 90)
	scene.call("_input", _touch(true, right_start, 1))
	scene.call("_input", _drag(right_start + Vector2(16, 2), Vector2(16, 2), 1))
	var scroll_after_first_right_touch_drag := hand_scroll.scroll_horizontal
	scene.call(
		"_input",
		_mouse_motion(
			right_start + Vector2(16, 2),
			Vector2(16, 2),
			MOUSE_BUTTON_MASK_LEFT,
			InputEvent.DEVICE_ID_EMULATION
		)
	)
	var scroll_after_right_mouse_echo := hand_scroll.scroll_horizontal
	scene.call("_input", _drag(right_start + Vector2(20, 2), Vector2(4, 0), 1))
	var scroll_after_second_right_touch_drag := hand_scroll.scroll_horizontal
	scene.call("_input", _touch(false, right_start + Vector2(20, 2), 1))

	var result := run_checks([
		assert_eq(scroll_after_first_touch_drag, 204, "The first touch drag should apply only displacement beyond the 12px slop"),
		assert_eq(scroll_after_mouse_echo, scroll_after_first_touch_drag, "Android compatibility MouseMotion must not become a second hand-scroll owner"),
		assert_gt(scroll_after_second_touch_drag, scroll_after_first_touch_drag, "Continuing to drag left must move monotonically toward later cards without a rightward jump"),
		assert_eq(scroll_after_first_right_touch_drag, 196, "The first rightward touch drag should apply displacement beyond the same slop"),
		assert_eq(scroll_after_right_mouse_echo, scroll_after_first_right_touch_drag, "The symmetric rightward mouse echo must not rewrite hand scroll"),
		assert_true(scroll_after_second_right_touch_drag < scroll_after_first_right_touch_drag, "Continuing to drag right must move monotonically toward earlier cards without a leftward jump"),
		assert_false(bool(scene.get("_hand_drag_active")), "The ignored mouse echo must not leave the legacy hand dragger active after touch release"),
	])
	await _dispose_fixture(scene)
	return result


func test_android_mouse_first_touch_echo_never_reaches_legacy_hand_dragger() -> String:
	var fixture: Dictionary = await _make_scene_fixture()
	var scene: Control = fixture["scene"]
	var state: GameState = fixture["state"]
	for index: int in 9:
		state.players[0].hand.append(
			CardInstance.create(
				_make_item("Mouse-first Hand %d" % index, "Mouse-first Hand %d" % index, "%03d" % (600 + index)),
				0
			)
		)
	scene.call("_configure_battle_pointer_input_for_tests", true)
	scene.call("_configure_battle_pointer_surface_for_tests", true)
	scene.call("_refresh_hand")
	await _frame()
	# Hand reconciliation refreshes the runtime profile, so re-enable Android's
	# touch/mouse merge after the fixture has committed its Surface generation.
	scene.call("_configure_battle_pointer_input_for_tests", true)

	var hand_scroll := scene.get("_hand_scroll") as ScrollContainer
	var hand_container := scene.get("_hand_container") as HBoxContainer
	hand_scroll.size = Vector2(420, 190)
	hand_scroll.custom_minimum_size = Vector2(420, 190)
	hand_container.size = Vector2(1600, 190)
	hand_container.custom_minimum_size.x = 1600
	var bar := hand_scroll.get_h_scroll_bar()
	bar.min_value = 0.0
	bar.max_value = 1600.0
	bar.page = 420.0
	hand_scroll.scroll_horizontal = 200

	# Native Android can deliver compatibility mouse first, followed by an
	# aliased ScreenTouch and an orphan ScreenDrag at the same physical sample.
	# The Surface owner must consume the whole pair. If ScreenDrag falls through,
	# the legacy dragger writes a second scroll value and remains active because
	# Surface consumes the matching release.
	var start := hand_scroll.get_global_transform() * Vector2(300, 90)
	scene.call("_input", _mouse_button(true, start, 0))
	scene.call("_input", _touch(true, start))
	scene.call(
		"_input",
		_mouse_motion(
			start + Vector2(-16, 2),
			Vector2(-16, 2),
			MOUSE_BUTTON_MASK_LEFT,
			InputEvent.DEVICE_ID_EMULATION
		)
	)
	var surface_scroll := hand_scroll.scroll_horizontal
	scene.call("_input", _drag(start + Vector2(-16, 2), Vector2(-16, 2)))
	var scroll_after_orphan_drag := hand_scroll.scroll_horizontal
	var legacy_active_after_orphan := bool(scene.get("_hand_drag_active"))
	scene.call("_input", _mouse_button(false, start + Vector2(-16, 2), 0))
	scene.call("_input", _touch(false, start + Vector2(-16, 2)))

	var result := run_checks([
		assert_eq(surface_scroll, 204, "The canonical mouse motion should apply only displacement beyond Surface slop"),
		assert_eq(scroll_after_orphan_drag, surface_scroll, "The paired orphan ScreenDrag must not become a second scroll writer"),
		assert_false(legacy_active_after_orphan, "The Android echo pair must never start the legacy hand dragger"),
		assert_false(bool(scene.get("_hand_drag_active")), "A completed Surface gesture must leave no stale legacy owner for the next swipe"),
	])
	await _dispose_fixture(scene)
	return result


func test_web_gallery_drag_past_slop_stays_scrolled_with_stale_scrollbar_range() -> String:
	var fixture: Dictionary = await _make_scene_fixture()
	var scene: Control = fixture["scene"]
	scene.call("_configure_battle_pointer_input_for_tests", true)
	scene.call("_configure_battle_pointer_surface_for_tests", true)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 40)
	scroll.size = Vector2(400, 190)
	scroll.custom_minimum_size = Vector2(400, 190)
	var row := HBoxContainer.new()
	row.size = Vector2(1600, 180)
	row.custom_minimum_size = Vector2(1600, 180)
	scene.add_child(scroll)
	scroll.add_child(row)
	for index: int in 10:
		var card_view := BattleCardView.new()
		card_view.custom_minimum_size = Vector2(116, 164)
		card_view.setup_from_instance(
			CardInstance.create(
				_make_item("Gallery Card %d" % index, "候选牌%d" % index, "%03d" % (300 + index)),
				0
			),
			BattleCardView.MODE_PREVIEW
		)
		card_view.set_clickable(true)
		row.add_child(card_view)
	scene.call("_configure_card_gallery_drag_scroll", scroll, row, "test_gallery_stale_range")
	for child: Node in row.get_children():
		scene.call("_configure_card_gallery_card_view", child as BattleCardView, scroll, "test_gallery_stale_range")
	scene.call("_set_card_gallery_drag_scroll_active", scroll, true)
	await _frame()
	var bar := scroll.get_h_scroll_bar()
	bar.max_value = 400.0
	bar.page = 400.0
	scroll.scroll_horizontal = 0

	var start := scroll.get_global_transform() * Vector2(260, 80)
	scene.call("_input", _touch(true, start))
	scene.call("_input", _drag(start + Vector2(-16, 2), Vector2(-16, 2)))
	var scroll_after_drag := scroll.scroll_horizontal
	scene.call("_input", _touch(false, start + Vector2(-16, 2)))
	var scroll_after_release := scroll.scroll_horizontal
	var surface_controller := scene.get(
		"_battle_pointer_surface_controller"
	) as RefCounted
	var committed_taps := 0
	for trace_entry_variant: Variant in surface_controller.call("trace_snapshot"):
		var trace_entry: Dictionary = trace_entry_variant
		if str(trace_entry.get("kind", "")) == "gesture_tap_committed":
			committed_taps += 1

	var result := run_checks([
		assert_true(
			bool(scene.call("_card_gallery_pointer_has_overflow", scroll)),
			"Card-picking HUD overflow must fall back to its live row geometry"
		),
		assert_eq(scroll_after_drag, 4, "The card HUD should apply only movement beyond the 12px slop"),
		assert_eq(scroll_after_release, 4, "A committed gallery drag must preserve its scroll position on release"),
		assert_eq(
			committed_taps,
			0,
			"A committed gallery drag must not activate its starting card"
		),
	])
	scene.call("_set_card_gallery_drag_scroll_active", scroll, false)
	await _dispose_fixture(scene)
	return result


func test_ai_send_out_prompt_is_not_blocked_by_stale_choice_hud_visibility() -> String:
	var fixture: Dictionary = await _make_scene_fixture()
	var scene: Control = fixture["scene"]
	var state: GameState = fixture["state"]
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI
	state.current_player_index = 0
	state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	var replacement := PokemonSlot.new()
	replacement.pokemon_stack.append(
		CardInstance.create(_make_item("AI Replacement", "AI替补", "401"), 1)
	)
	state.players[1].active_pokemon = null
	state.players[1].bench = [replacement]
	var ai := AIOpponent.new()
	ai.configure(1, 1)
	scene.set("_ai_opponent", ai)
	scene.set("_pending_choice", "send_out")
	scene.set("_dialog_data", {"player": 1, "bench": [replacement]})
	var dialog_overlay := scene.get("_dialog_overlay") as Control
	dialog_overlay.visible = true
	var ready := bool(scene.call("_is_ai_turn_ready"))

	var result := run_checks([
		assert_true(
			ready,
			"An AI-owned mandatory send-out must ignore stale human choice HUD visibility"
		),
	])
	GameManager.current_mode = previous_mode
	await _dispose_fixture(scene)
	return result


func _make_scene_fixture() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := (
		load("res://scenes/battle/BattleScene.tscn") as PackedScene
	).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame

	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	var first_inst := CardInstance.create(
		_make_item("Ultra Ball", "楂樼骇鐞?", "112"),
		0
	)
	state.players[0].hand.append(first_inst)
	gsm.game_state = state
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	return {
		"scene": scene,
		"state": state,
		"first_inst": first_inst,
	}


func _make_item(name_en: String, name_zh: String, index: String) -> CardData:
	var item := CardData.new()
	item.name = name_en
	item.name_zh = name_zh
	item.card_type = "Item"
	item.set_code = "CSV1C"
	item.card_index = index
	return item


func _make_trainer(name_en: String, card_type: String) -> CardData:
	var trainer := CardData.new()
	trainer.name = name_en
	trainer.name_en = name_en
	trainer.card_type = card_type
	return trainer


func _card_view_for_instance(
	hand_container: HBoxContainer,
	instance_id: int
) -> BattleCardView:
	for child: Node in hand_container.get_children():
		var card_view := child as BattleCardView
		if (
			card_view != null
			and card_view.card_instance != null
			and card_view.card_instance.instance_id == instance_id
		):
			return card_view
	return null


func _rendered_hand_instance_ids(hand_container: HBoxContainer) -> Array[int]:
	var rendered_ids: Array[int] = []
	for child: Node in hand_container.get_children():
		var card_view := child as BattleCardView
		if card_view != null and card_view.card_instance != null:
			rendered_ids.append(card_view.card_instance.instance_id)
	return rendered_ids


func _touch(
	pressed: bool,
	position: Vector2,
	index: int = 0
) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = pressed
	event.position = position
	event.index = index
	return event


func _drag(
	position: Vector2,
	relative: Vector2,
	index: int = 0
) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.position = position
	event.relative = relative
	event.index = index
	return event


func _mouse_motion(
	position: Vector2,
	relative: Vector2,
	button_mask: int,
	device: int = 0
) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = button_mask
	event.device = device
	return event


func _mouse_button(
	pressed: bool,
	position: Vector2,
	device: int = 0
) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	event.device = device
	return event


func _frame() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	await tree.process_frame


func _dispose_fixture(scene: Node) -> void:
	scene.queue_free()
	await _frame()
