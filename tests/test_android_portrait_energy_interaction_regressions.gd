class_name TestAndroidPortraitEnergyInteractionRegressions
extends "res://tests/helpers/BattleUIFeaturesShared.gd"

const PointerGesturePolicyScript := preload("res://scripts/ui/input/PointerGesturePolicy.gd")
const UiRuntimeProfileScript := preload("res://scripts/ui/runtime/UiRuntimeProfile.gd")


func test_native_android_profile_owns_card_galleries_through_pointer_surfaces() -> String:
	var battle_scene := _make_battle_scene_stub()
	var android_profile := UiRuntimeProfileScript.new({
		"host_kind": UiRuntimeProfile.HOST_NATIVE,
		"native_os": UiRuntimeProfile.OS_ANDROID,
		"pointer_mode": UiRuntimeProfile.POINTER_TOUCH,
		"mobile_like": true,
		"viewport_size": Vector2(1600, 3556),
	})
	battle_scene.call("_configure_battle_pointer_runtime", android_profile)
	var controller: Variant = battle_scene.get("_battle_pointer_surface_controller")
	var result := run_checks([
		assert_true(
			controller != null and bool(controller.call("is_enabled")),
			"Native Android touch must use the same press/drag/release owner as browser touch galleries"
		),
	])
	battle_scene.free()
	return result


func test_android_canvas_items_stretch_dialog_hit_uses_viewport_coordinates() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var root_window := tree.root
	var previous_window_size := DisplayServer.window_get_size()
	var previous_root_size := root_window.size
	var previous_scale_size := root_window.content_scale_size
	var previous_scale_mode := root_window.content_scale_mode
	var previous_scale_aspect := root_window.content_scale_aspect
	DisplayServer.window_set_size(Vector2i(1080, 2400))
	root_window.size = Vector2i(1080, 2400)
	root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root_window.content_scale_size = Vector2i(1600, 900)

	var canvas_layer := CanvasLayer.new()
	canvas_layer.transform = Transform2D.IDENTITY.scaled(Vector2(1.65, 1.65))
	canvas_layer.transform.origin = Vector2(140, 90)
	root_window.add_child(canvas_layer)
	var battle_scene: Control = BattleScenePacked.instantiate()
	battle_scene.set("_battle_mode", "review")
	canvas_layer.add_child(battle_scene)
	await tree.process_frame

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(180, 520)
	scroll.size = Vector2(760, 340)
	scroll.custom_minimum_size = scroll.size
	var row := HBoxContainer.new()
	row.size = Vector2(760, 320)
	row.custom_minimum_size = row.size
	scroll.add_child(row)
	var card := BattleCardView.new()
	card.size = Vector2(180, 260)
	card.custom_minimum_size = card.size
	card.set_meta("dialog_choice_index", 0)
	row.add_child(card)
	battle_scene.add_child(scroll)
	battle_scene.set("_dialog_card_scroll", scroll)
	battle_scene.set("_dialog_card_row", row)
	await tree.process_frame
	var viewport_center := card.get_global_transform() * (card.size * 0.5)
	var canvas_center := card.get_global_transform_with_canvas() * (card.size * 0.5)
	var hit := battle_scene.call("_dialog_card_gallery_card_at_screen_position", viewport_center) as BattleCardView

	var result := run_checks([
		assert_true(viewport_center.distance_to(canvas_center) > 1.0, "Regression setup must contain a real canvas-items stretch transform"),
		assert_eq(hit, card, "Android ScreenTouch viewport coordinates must hit the visible dialog card under canvas-items stretch"),
	])
	canvas_layer.queue_free()
	await tree.process_frame
	root_window.content_scale_mode = previous_scale_mode
	root_window.content_scale_aspect = previous_scale_aspect
	root_window.content_scale_size = previous_scale_size
	root_window.size = previous_root_size
	DisplayServer.window_set_size(previous_window_size)
	return result


func test_android_portrait_field_energy_source_accepts_density_scaled_finger_jitter() -> String:
	PointerGesturePolicyScript.set_touch_dpi_override_for_tests(420.0)
	var battle_scene := _make_battle_scene_stub()
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
	target.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Android target", 120, "C"), 0))
	gsm.game_state.players[0].active_pokemon = target
	var energy := CardInstance.create(_make_energy_cd("Android source Energy", "F"), 0)
	battle_scene.call("_show_field_assignment_interaction", {
		"title": "Attach Energy",
		"ui_mode": "card_assignment",
		"source_items": [energy],
		"source_labels": ["Android source Energy"],
		"target_items": [target],
		"target_labels": ["Android target"],
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	})

	var source_row := battle_scene.get("_field_interaction_row") as HBoxContainer
	var source_card := source_row.get_child(0) as BattleCardView
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = Vector2(240, 120)
	source_card.handle_bridged_pointer_input(press)
	var jitter := InputEventScreenDrag.new()
	jitter.index = 0
	jitter.position = Vector2(284, 124)
	jitter.relative = Vector2(44, 4)
	source_card.handle_bridged_pointer_input(jitter)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = Vector2(284, 124)
	source_card.handle_bridged_pointer_input(release)
	PointerGesturePolicyScript.set_touch_dpi_override_for_tests()

	var result := run_checks([
		assert_eq(
			int(battle_scene.get("_field_interaction_assignment_selected_source_index")),
			0,
			"A native Android portrait tap must survive ordinary density-scaled finger jitter"
		),
	])
	battle_scene.free()
	return result


func test_earthen_vessel_resolution_immediately_reconciles_searched_energy_into_hand_surface() -> String:
	var battle_scene := _make_battle_scene_stub()
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
		var player_state := PlayerState.new()
		player_state.player_index = player_index
		gsm.game_state.players.append(player_state)

	var player: PlayerState = gsm.game_state.players[0]
	var discard_cost := CardInstance.create(_make_trainer_cd("Discard Cost", "Item", ""), 0)
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item", ""), 0)
	vessel.card_data.effect_id = "e366f56ecd3f805a28294109a1a37453"
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand = [vessel, discard_cost]
	player.deck = [fighting, lightning]
	gsm.effect_processor.register_effect(
		vessel.card_data.effect_id,
		EffectSearchBasicEnergy.new(2, 1)
	)

	battle_scene.call("_refresh_hand")
	battle_scene.call("_try_play_trainer_with_interaction", 0, vessel)
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0, 1]))

	var rendered_ids: Dictionary = {}
	var hand_container := battle_scene.get("_hand_container") as HBoxContainer
	for child: Node in hand_container.get_children():
		var card_view := child as BattleCardView
		if card_view != null and card_view.card_instance != null:
			rendered_ids[card_view.card_instance.instance_id] = true

	var result := run_checks([
		assert_true(fighting in player.hand and lightning in player.hand, "Earthen Vessel must commit both selected Energy cards to GameState.hand"),
		assert_true(rendered_ids.has(fighting.instance_id), "The first searched Energy must appear on the hand surface in the same resolution"),
		assert_true(rendered_ids.has(lightning.instance_id), "The second searched Energy must appear on the hand surface in the same resolution"),
		assert_eq(hand_container.get_child_count(), player.hand.size(), "Rendered hand membership must match authoritative hand membership immediately"),
	])
	battle_scene.free()
	return result


func test_android_portrait_earthen_vessel_same_size_hand_replacement_survives_discard_reveal() -> String:
	var previous_battle_effects_enabled := GameManager.battle_effects_enabled
	var previous_layout := GameManager.battle_layout_mode
	GameManager.battle_effects_enabled = true
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var tree := Engine.get_main_loop() as SceneTree
	var previous_window_size := DisplayServer.window_get_size()
	var previous_root_size := tree.root.size
	var previous_content_scale_size := tree.root.content_scale_size
	DisplayServer.window_set_size(Vector2i(900, 1600))
	tree.root.size = Vector2i(900, 1600)
	tree.root.content_scale_size = Vector2i(900, 1600)
	var battle_scene: Control = BattleScenePacked.instantiate()
	tree.root.add_child(battle_scene)
	await tree.process_frame
	await tree.process_frame

	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = player_index
		state.players.append(player_state)
	gsm.game_state = state
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	battle_scene.set("_active_battle_layout_mode", "portrait")
	gsm.action_logged.connect(Callable(battle_scene, "_on_action_logged"))

	var player: PlayerState = state.players[0]
	var stable_card := CardInstance.create(_make_trainer_cd("Stable Card", "Item", ""), 0)
	var discard_cost := CardInstance.create(_make_trainer_cd("Discard Cost", "Item", ""), 0)
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item", ""), 0)
	vessel.card_data.effect_id = "e366f56ecd3f805a28294109a1a37453"
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand = [stable_card, vessel, discard_cost]
	player.deck = [fighting, lightning]
	gsm.effect_processor.register_effect(
		vessel.card_data.effect_id,
		EffectSearchBasicEnergy.new(2, 1)
	)

	battle_scene.call("_refresh_hand")
	await tree.process_frame
	battle_scene.call("_try_play_trainer_with_interaction", 0, vessel)
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([1]))
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0, 1]))
	var reveal_active_after_resolution := bool(battle_scene.get("_draw_reveal_active"))
	var current_reveal := battle_scene.get("_draw_reveal_current_action") as GameAction
	var current_reveal_type := current_reveal.action_type if current_reveal != null else -1
	var allow_hand_refresh_during_fly := bool(battle_scene.get("_draw_reveal_allow_hand_refresh_during_fly"))
	await tree.create_timer(0.5).timeout
	await tree.process_frame
	await tree.process_frame
	var reveal_finished := not bool(battle_scene.get("_draw_reveal_active"))

	var hand_container := battle_scene.get("_hand_container") as HBoxContainer
	var rendered_ids: Dictionary = {}
	var visible_ids: Dictionary = {}
	for child: Node in hand_container.get_children():
		var card_view := child as BattleCardView
		if card_view != null and card_view.card_instance != null:
			rendered_ids[card_view.card_instance.instance_id] = true
			if card_view.is_visible_in_tree() and card_view.get_global_rect().size != Vector2.ZERO:
				visible_ids[card_view.card_instance.instance_id] = true

	var result := run_checks([
		assert_true(reveal_active_after_resolution, "The regression must exercise Earthen Vessel while its discard presentation owns hand refresh"),
		assert_eq(current_reveal_type, GameAction.ActionType.DISCARD, "The active presentation must be Earthen Vessel's discard cost"),
		assert_true(allow_hand_refresh_during_fly, "Discard presentation must permit the authoritative hand replacement to render during its flight"),
		assert_true(reveal_finished, "Earthen Vessel's discard presentation must complete without waiting for a later draw"),
		assert_eq(player.hand.size(), 3, "Earthen Vessel should replace two spent hand cards with two searched Energy cards"),
		assert_true(rendered_ids.has(stable_card.instance_id), "The stable hand card must remain rendered across the same-size replacement"),
		assert_true(rendered_ids.has(fighting.instance_id), "The first searched Energy must render while the discard reveal is active"),
		assert_true(rendered_ids.has(lightning.instance_id), "The second searched Energy must render while the discard reveal is active"),
		assert_true(visible_ids.has(fighting.instance_id), "The first searched Energy must remain visibly laid out after the discard presentation finishes"),
		assert_true(visible_ids.has(lightning.instance_id), "The second searched Energy must remain visibly laid out after the discard presentation finishes"),
		assert_false(rendered_ids.has(vessel.instance_id), "The played Earthen Vessel must leave the rendered hand"),
		assert_false(rendered_ids.has(discard_cost.instance_id), "The discarded cost must leave the rendered hand"),
	])
	battle_scene.queue_free()
	await tree.process_frame
	GameManager.battle_effects_enabled = previous_battle_effects_enabled
	GameManager.battle_layout_mode = previous_layout
	DisplayServer.window_set_size(previous_window_size)
	tree.root.size = previous_root_size
	tree.root.content_scale_size = previous_content_scale_size
	return result


func test_native_android_earthen_vessel_replacement_keeps_searched_energy_touchable() -> String:
	var previous_battle_effects_enabled := GameManager.battle_effects_enabled
	var previous_layout := GameManager.battle_layout_mode
	var previous_runtime_profile: UiRuntimeProfile = GameManager.ui_runtime_profile
	var previous_mode: int = GameManager.current_mode
	GameManager.battle_effects_enabled = true
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	var android_profile := UiRuntimeProfileScript.new({
		"host_kind": UiRuntimeProfile.HOST_NATIVE,
		"native_os": UiRuntimeProfile.OS_ANDROID,
		"pointer_mode": UiRuntimeProfile.POINTER_TOUCH,
		"mobile_like": true,
		"viewport_size": Vector2(900, 1600),
	})
	var tree := Engine.get_main_loop() as SceneTree
	var previous_window_size := DisplayServer.window_get_size()
	var previous_root_size := tree.root.size
	var previous_content_scale_size := tree.root.content_scale_size
	DisplayServer.window_set_size(Vector2i(900, 1600))
	tree.root.size = Vector2i(900, 1600)
	tree.root.content_scale_size = Vector2i(900, 1600)
	var battle_scene: Control = BattleScenePacked.instantiate()
	tree.root.add_child(battle_scene)
	await tree.process_frame
	await tree.process_frame
	# Window size_changed resolves the host profile again in headless runs. Install
	# the Android profile only after those callbacks, exactly where a real Android
	# process already has its final runtime profile.
	GameManager.ui_runtime_profile = android_profile

	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = player_index
		state.players.append(player_state)
	gsm.game_state = state
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	battle_scene.set("_active_battle_layout_mode", "portrait")
	battle_scene.call("_configure_battle_pointer_runtime", android_profile)
	var hud_touch_adapter: RefCounted = battle_scene.get("_ios_web_hud_touch_adapter") as RefCounted
	if hud_touch_adapter != null:
		hud_touch_adapter.call("configure", android_profile)
	gsm.action_logged.connect(Callable(battle_scene, "_on_action_logged"))

	var player: PlayerState = state.players[0]
	var stable_card := CardInstance.create(_make_trainer_cd("Stable Card", "Item", ""), 0)
	var discard_cost := CardInstance.create(_make_trainer_cd("Discard Cost", "Item", ""), 0)
	var vessel := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item", ""), 0)
	vessel.card_data.effect_id = "e366f56ecd3f805a28294109a1a37453"
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand = [stable_card, vessel, discard_cost]
	player.deck = [fighting, lightning]
	gsm.effect_processor.register_effect(
		vessel.card_data.effect_id,
		EffectSearchBasicEnergy.new(2, 1)
	)

	battle_scene.call("_refresh_hand")
	await tree.process_frame
	var initial_hand_container := battle_scene.get("_hand_container") as HBoxContainer
	var vessel_view := _find_card_view_for_instance(initial_hand_container, vessel)
	var vessel_view_found := vessel_view != null
	_tap_control_through_scene(battle_scene, vessel_view)
	await tree.process_frame
	var detail_use_button := battle_scene.get("_detail_use_btn") as Button
	_tap_control_through_scene(battle_scene, detail_use_button)
	await tree.process_frame
	await tree.process_frame
	var discard_row := battle_scene.get("_dialog_card_row") as Control
	var discard_view := _find_card_view_for_instance(discard_row, discard_cost)
	var discard_view_found := discard_view != null
	_tap_control_through_scene(battle_scene, discard_view)
	await tree.process_frame
	var dialog_confirm := battle_scene.get("_dialog_confirm") as Button
	_tap_control_through_scene(battle_scene, dialog_confirm)
	await tree.process_frame
	await tree.process_frame
	var search_board := battle_scene.get("_dialog_library_search_board") as Control
	var fighting_search_view := _find_card_view_for_instance(search_board, fighting)
	var lightning_search_view := _find_card_view_for_instance(search_board, lightning)
	var search_views_found := fighting_search_view != null and lightning_search_view != null
	_tap_control_through_scene(battle_scene, fighting_search_view)
	await tree.process_frame
	_tap_control_through_scene(battle_scene, lightning_search_view)
	await tree.process_frame
	_tap_control_through_scene(battle_scene, dialog_confirm)
	await tree.create_timer(0.5).timeout
	await tree.process_frame
	await tree.process_frame

	var hand_container := battle_scene.get("_hand_container") as HBoxContainer
	var fighting_view: BattleCardView = null
	for child: Node in hand_container.get_children():
		var card_view := child as BattleCardView
		if card_view != null and card_view.card_instance == fighting:
			fighting_view = card_view
			break
	var touch_position := Vector2(-1.0, -1.0)
	if fighting_view != null:
		touch_position = fighting_view.get_global_transform() * (fighting_view.size * 0.5)
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.pressed = true
		press.position = touch_position
		battle_scene.call("_input", press)
		var release := InputEventScreenTouch.new()
		release.index = 0
		release.pressed = false
		release.position = touch_position
		battle_scene.call("_input", release)

	var surface_controller: RefCounted = battle_scene.get("_battle_pointer_surface_controller") as RefCounted
	var result := run_checks([
		assert_true(surface_controller != null and bool(surface_controller.call("is_enabled")), "The regression must execute with the native Android hand Surface enabled"),
		assert_true(vessel_view_found, "The test must enter Earthen Vessel through the rendered Android hand control"),
		assert_true(discard_view_found, "The discard cost must be selected through the real Android card-gallery Surface"),
		assert_true(
			search_views_found,
			"Both searched Energy cards must be selected through the real full-library dialog (pending=%s step=%d dialog_mode=%s items=%d)" % [
				str(battle_scene.get("_pending_choice")),
				int(battle_scene.get("_pending_effect_step_index")),
				str((battle_scene.get("_dialog_data") as Dictionary).get("ui_mode", "")),
				((battle_scene.get("_dialog_data") as Dictionary).get("items", []) as Array).size(),
			]
		),
		assert_true(fighting_view != null and fighting_view.is_visible_in_tree(), "The searched Fighting Energy must have a live rendered hand control"),
		assert_true(touch_position.x >= 0.0 and touch_position.y >= 0.0, "The searched Energy must have usable touch geometry"),
		assert_eq(battle_scene.get("_selected_hand_card"), fighting, "A real Android touch must select the newly searched Energy after Earthen Vessel replaces the hand at the same size"),
	])
	battle_scene.queue_free()
	await tree.process_frame
	GameManager.battle_effects_enabled = previous_battle_effects_enabled
	GameManager.battle_layout_mode = previous_layout
	GameManager.ui_runtime_profile = previous_runtime_profile
	GameManager.current_mode = previous_mode as GameManager.GameMode
	DisplayServer.window_set_size(previous_window_size)
	tree.root.size = previous_root_size
	tree.root.content_scale_size = previous_content_scale_size
	return result


func test_android_portrait_secret_box_same_size_membership_reconciles_all_four_searches() -> String:
	var battle_scene := _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = player_index
		state.players.append(player_state)
	gsm.game_state = state
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.action_logged.connect(Callable(battle_scene, "_on_action_logged"))

	var player: PlayerState = state.players[0]
	var stable_card := CardInstance.create(_make_trainer_cd("Stable Card", "Item", ""), 0)
	var secret_box := CardInstance.create(_make_trainer_cd("Secret Box", "Item", ""), 0)
	secret_box.card_data.effect_id = "e92a86246f44351d023bd4fa271089aa"
	var discard_a := CardInstance.create(_make_trainer_cd("Discard A", "Item", ""), 0)
	var discard_b := CardInstance.create(_make_trainer_cd("Discard B", "Item", ""), 0)
	var discard_c := CardInstance.create(_make_trainer_cd("Discard C", "Item", ""), 0)
	var searched_item := CardInstance.create(_make_trainer_cd("Searched Item", "Item", ""), 0)
	var searched_tool := CardInstance.create(_make_trainer_cd("Searched Tool", "Tool", ""), 0)
	var searched_supporter := CardInstance.create(_make_trainer_cd("Searched Supporter", "Supporter", ""), 0)
	var searched_stadium := CardInstance.create(_make_trainer_cd("Searched Stadium", "Stadium", ""), 0)
	player.hand = [stable_card, secret_box, discard_a, discard_b, discard_c]
	player.deck = [searched_item, searched_tool, searched_supporter, searched_stadium]
	gsm.effect_processor.register_effect(secret_box.card_data.effect_id, EffectSecretBox.new())

	battle_scene.call("_refresh_hand")
	battle_scene.call("_try_play_trainer_with_interaction", 0, secret_box)
	battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([1, 2, 3]))
	for _search_step: int in 4:
		battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0]))

	var rendered_ids: Dictionary = {}
	var hand_container := battle_scene.get("_hand_container") as HBoxContainer
	for child: Node in hand_container.get_children():
		var card_view := child as BattleCardView
		if card_view != null and card_view.card_instance != null:
			rendered_ids[card_view.card_instance.instance_id] = true

	var result := run_checks([
		assert_eq(player.hand.size(), 5, "Secret Box must replace four spent cards with four searched cards without relying on a count change"),
		assert_true(stable_card in player.hand, "The untouched hand member must survive Secret Box"),
		assert_eq(str(battle_scene.get("_pending_choice")), "", "All Secret Box search steps must finish before projection is checked"),
		assert_true(searched_item in player.hand, "Secret Box must commit the selected Item to authoritative hand state"),
		assert_true(searched_tool in player.hand, "Secret Box must commit the selected Tool to authoritative hand state"),
		assert_true(searched_supporter in player.hand, "Secret Box must commit the selected Supporter to authoritative hand state"),
		assert_true(searched_stadium in player.hand, "Secret Box must commit the selected Stadium to authoritative hand state"),
		assert_true(rendered_ids.has(stable_card.instance_id), "The untouched hand member must remain rendered"),
		assert_true(rendered_ids.has(searched_item.instance_id), "The searched Item must render in the resolving frame"),
		assert_true(rendered_ids.has(searched_tool.instance_id), "The searched Tool must render in the resolving frame"),
		assert_true(rendered_ids.has(searched_supporter.instance_id), "The searched Supporter must render in the resolving frame"),
		assert_true(rendered_ids.has(searched_stadium.instance_id), "The searched Stadium must render in the resolving frame"),
		assert_false(rendered_ids.has(secret_box.instance_id), "The played Secret Box must leave the hand surface"),
		assert_false(rendered_ids.has(discard_a.instance_id), "Discarded cards must leave the hand surface"),
		assert_eq(hand_container.get_child_count(), player.hand.size(), "The hand projection must reconcile by instance membership, not by count"),
	])
	battle_scene.free()
	return result


func test_public_search_to_hand_action_reconciles_hand_without_waiting_for_later_draw() -> String:
	var battle_scene := _make_battle_scene_stub()
	battle_scene.set("_active_battle_layout_mode", "portrait")
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player_state := PlayerState.new()
		player_state.player_index = player_index
		state.players.append(player_state)
	gsm.game_state = state
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	gsm.action_logged.connect(Callable(battle_scene, "_on_action_logged"))

	var player: PlayerState = state.players[0]
	var stable_card := CardInstance.create(_make_trainer_cd("Stable Card", "Item", ""), 0)
	var source_card := CardInstance.create(_make_trainer_cd("Earthen Vessel", "Item", ""), 0)
	var fighting := CardInstance.create(_make_energy_cd("Basic Fighting Energy", "F"), 0)
	var lightning := CardInstance.create(_make_energy_cd("Basic Lightning Energy", "L"), 0)
	player.hand = [stable_card]
	player.deck = [fighting, lightning]
	battle_scene.call("_refresh_hand")

	var moved := gsm.move_public_cards_to_hand_for_effect(
		0,
		[fighting, lightning],
		source_card,
		"trainer",
		"search_to_hand",
		["Basic Energy"]
	)
	var public_action: GameAction = gsm.action_log.back() if not gsm.action_log.is_empty() else null
	var zone_changes: Array = public_action.data.get("zone_changes", []) if public_action != null else []
	var zone_change: Dictionary = zone_changes[0] if not zone_changes.is_empty() else {}
	var rendered_ids: Dictionary = {}
	var hand_container := battle_scene.get("_hand_container") as HBoxContainer
	for child: Node in hand_container.get_children():
		var card_view := child as BattleCardView
		if card_view != null and card_view.card_instance != null:
			rendered_ids[card_view.card_instance.instance_id] = true

	var result := run_checks([
		assert_eq(moved.size(), 2, "The public search action must commit both Energy cards to the authoritative hand"),
		assert_true(rendered_ids.has(fighting.instance_id), "A PUBLIC_REVEAL search-to-hand action must independently reconcile the first Energy"),
		assert_true(rendered_ids.has(lightning.instance_id), "A PUBLIC_REVEAL search-to-hand action must independently reconcile the second Energy"),
		assert_eq(zone_changes.size(), 1, "Search-to-hand must publish one typed zone change"),
		assert_eq(zone_change.get("card_instance_ids", []), [fighting.instance_id, lightning.instance_id], "The projection event must carry exact card membership"),
		assert_eq(str(zone_change.get("projection_timing", "")), "immediate", "Public search results must reconcile during the resolving action"),
	])
	battle_scene.free()
	return result


func _find_card_view_for_instance(root: Node, card: CardInstance) -> BattleCardView:
	if root == null or card == null:
		return null
	if root is BattleCardView and (root as BattleCardView).card_instance == card:
		return root as BattleCardView
	for child: Node in root.get_children():
		var found := _find_card_view_for_instance(child, card)
		if found != null:
			return found
	return null


func _tap_control_through_scene(scene: Control, control: Control) -> void:
	if scene == null or control == null:
		return
	var position := control.get_global_transform() * (control.size * 0.5)
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = position
	scene.get_viewport().push_input(press, false)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = position
	scene.get_viewport().push_input(release, false)
