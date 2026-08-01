class_name TestBattleHandSurfaceReconciliation
extends TestBase

const SurfaceControllerScript := preload(
	"res://scripts/ui/battle/interactions/BattlePointerSurfaceController.gd"
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


func test_runtime_profile_enables_surface_only_for_web_touch_v2() -> String:
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
	scene.call("_configure_battle_pointer_runtime", web_touch)
	var surface_controller: RefCounted = scene.get(
		"_battle_pointer_surface_controller"
	) as RefCounted
	var touch_enabled := bool(surface_controller.call("is_enabled"))
	scene.call("_configure_battle_pointer_runtime", web_mouse)
	var mouse_enabled := bool(surface_controller.call("is_enabled"))
	WebUiFeatureGate.reset_for_tests()

	var result := run_checks([
		assert_true(touch_enabled, "Web touch with the v2 gate must enable the unified pointer surface"),
		assert_false(mouse_enabled, "Web mouse must keep the native Control input path"),
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


func test_web_hand_drag_uses_live_content_width_while_scrollbar_range_is_stale() -> String:
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
		assert_true(
			scroll_after_drag > 0,
			"A deliberate 16px hand swipe must start scrolling even while the scrollbar range is stale"
		),
		assert_eq(
			committed_taps,
			0,
			"Releasing after a deliberate hand swipe must never open the starting card"
		),
	])
	await _dispose_fixture(scene)
	return result


func test_web_gallery_drag_starts_on_first_deliberate_move_with_stale_scrollbar_range() -> String:
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

	var result := run_checks([
		assert_true(
			bool(scene.call("_card_gallery_pointer_has_overflow", scroll)),
			"Card-picking HUD overflow must fall back to its live row geometry"
		),
		assert_true(
			scroll_after_drag > 0,
			"A deliberate 16px gallery swipe must start scrolling before a held card can become a click"
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


func _frame() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	await tree.process_frame


func _dispose_fixture(scene: Node) -> void:
	scene.queue_free()
	await _frame()
