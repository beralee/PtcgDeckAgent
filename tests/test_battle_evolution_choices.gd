class_name TestBattleEvolutionChoices
extends "res://tests/helpers/BattleUIFeaturesShared.gd"


class EvolutionScenario extends "res://scenes/battle/BattleScene.gd":
	func _start_battle() -> void:
		pass


func _fixture(reverse_hand: bool = false, prepared_scene: Control = null, open_picker: bool = true) -> Dictionary:
	var scene := prepared_scene if prepared_scene != null else _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 3
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	var player: PlayerState = gsm.game_state.players[0]
	for i: int in 3:
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(CardInstance.create(CardDatabase.get_card("CSV2C", "028"), 0))
		slot.turn_played = 1
		slot.damage_counters = i * 10
		if i == 0:
			player.active_pokemon = slot
		else:
			player.bench.append(slot)
	var fighting := CardInstance.create(CardDatabase.get_card("CSV7C", "123"), 0)
	var water := CardInstance.create(CardDatabase.get_card("30thC", "015"), 0)
	var candy := CardInstance.create(CardDatabase.get_card("CSVH1C", "045"), 0)
	player.hand.assign([water, fighting, candy] if reverse_hand else [fighting, water, candy])
	var opponent := PokemonSlot.new()
	opponent.pokemon_stack.append(CardInstance.create(CardDatabase.get_card("CSV2C", "028"), 1))
	gsm.game_state.players[1].active_pokemon = opponent
	if prepared_scene != null:
		scene.call("_refresh_ui")
	if open_picker:
		scene.call("_try_play_trainer_with_interaction", 0, candy)
	return {"scene": scene, "gsm": gsm, "player": player, "fighting": fighting, "water": water, "candy": candy}


func _source(scene: Object, index: int) -> BattleCardView:
	var row: HBoxContainer = scene.get("_field_interaction_row")
	return row.get_child(index) as BattleCardView if row != null and index < row.get_child_count() else null


func _select(scene: Object, source_index: int, target_index: int) -> void:
	var view := _source(scene, source_index)
	if view == null:
		return
	view.left_clicked.emit(view.card_instance, view.card_data)
	scene.call("_handle_field_assignment_target_index", target_index)


func test_candy_uses_energy_switch_picker_with_each_hand_card_once() -> String:
	var f := _fixture()
	var scene: Control = f.scene
	var steps: Array = scene.get("_pending_effect_steps")
	var checks: Array[String] = [
		assert_eq(str(scene.get("_field_interaction_mode")), "assignment", "Candy must use the Energy Switch field picker"),
		assert_eq(steps.size(), 1, "UI projection must keep a single authoritative EVOLVE step"),
		assert_eq((steps[0].items as Array).size(), 6, "All six legal card/target pairs remain in the canonical frontier"),
	]
	if _source(scene, 0) == null:
		return run_checks(checks)
	checks.append_array([
		assert_eq((scene.get("_field_interaction_row") as HBoxContainer).get_child_count(), 2, "Render two actual cards, not six duplicated combinations"),
		assert_true(_source(scene, 0).card_instance == f.fighting, "Fighting artwork uses the exact hand instance"),
		assert_true(_source(scene, 1).card_instance == f.water, "Water artwork uses the exact hand instance"),
		assert_eq((_source(scene, 0).get("_selection_badge") as Label).text, "斗系", "Attribute comes from the Pokemon, not its Water attack cost"),
		assert_eq((_source(scene, 1).get("_selection_badge") as Label).text, "水系", "Short attribute badge distinguishes Water"),
		assert_false((scene.get("_dialog_overlay") as Control).visible, "No verbose combination dialog"),
	])
	return run_checks(checks)


func test_source_collapses_then_board_target_waits_for_confirm() -> String:
	var f := _fixture()
	var scene: Control = f.scene
	if _source(scene, 1) == null:
		return "Missing evolution field picker"
	var scroll: ScrollContainer = scene.get("_field_interaction_scroll")
	var checks: Array[String] = [assert_true(scroll.visible, "Start with card art")]
	_source(scene, 1).left_clicked.emit(f.water, f.water.card_data)
	checks.append_array([
		assert_false(scroll.visible, "Collapse source cards to reveal board targets"),
		assert_true((scene.get("_field_interaction_confirm_btn") as Button).disabled, "A source alone cannot confirm"),
		assert_true((scene.get("_field_interaction_slot_index_by_id") as Dictionary).has("my_bench_0"), "Legal Bench is clickable"),
	])
	scene.call("_handle_field_assignment_target_index", 1)
	checks.append_array([
		assert_true(f.candy in f.player.hand, "Target click must not consume Candy"),
		assert_eq(f.player.bench[0].pokemon_stack.size(), 1, "Evolution waits for confirmation"),
		assert_eq(scene.call("_field_interaction_selected_slot_ids"), ["my_bench_0"], "Chosen field position is highlighted"),
		assert_str_contains((scene.get("_field_interaction_status_lbl") as Label).text, "水", "Compact confirmation retains the selected attribute"),
	])
	(scene.get("_field_interaction_confirm_btn") as Button).button_down.emit()
	checks.append_array([
		assert_true(f.player.bench[0].get_top_card() == f.water, "Confirm executes the exact Water/Bench pair"),
		assert_true(f.fighting in f.player.hand and f.candy in f.player.discard_pile, "Only the selected evolution and Candy leave hand"),
		assert_eq(f.player.active_pokemon.pokemon_stack.size(), 1, "Active remains unchanged"),
		assert_eq(f.player.bench[1].pokemon_stack.size(), 1, "Other identical Basic remains unchanged"),
		assert_eq(str(scene.get("_pending_choice")), "", "One canonical choice completes the effect"),
	])
	return run_checks(checks)


func test_reselect_and_reordered_hand_bind_exact_instances() -> String:
	var f := _fixture(true)
	var scene: Control = f.scene
	if _source(scene, 0) == null:
		return "Missing evolution field picker"
	_select(scene, 1, 0)
	(scene.get("_field_interaction_clear_btn") as Button).button_down.emit()
	var checks: Array[String] = [
		assert_true((scene.get("_field_interaction_scroll") as ScrollContainer).visible, "Reselect restores card picker"),
		assert_true(f.candy in f.player.hand, "Reselect does not spend Candy"),
	]
	_select(scene, 0, 2)
	(scene.get("_field_interaction_confirm_btn") as Button).button_down.emit()
	checks.append(assert_true(f.player.bench[1].get_top_card() == f.water, "Reordered source maps to Water on second Bench"))
	return run_checks(checks)


func test_cancel_at_each_phase_keeps_hand_and_board() -> String:
	var checks: Array[String] = []
	for phase: int in 3:
		var f := _fixture()
		var scene: Control = f.scene
		if _source(scene, 0) == null:
			return "Missing evolution field picker"
		if phase >= 1:
			_source(scene, 0).left_clicked.emit(f.fighting, f.fighting.card_data)
		if phase == 2:
			scene.call("_handle_field_assignment_target_index", 1)
		(scene.get("_field_interaction_cancel_btn") as Button).button_down.emit()
		checks.append_array([
			assert_true(f.candy in f.player.hand and f.water in f.player.hand and f.fighting in f.player.hand, "Cancel preserves hand at phase %d" % phase),
			assert_eq(f.player.bench[0].pokemon_stack.size(), 1, "Cancel preserves board"),
			assert_eq(str(scene.get("_pending_choice")), "", "Cancel closes interaction"),
		])
	return run_checks(checks)


func test_same_attribute_missing_art_preserves_printing_and_details() -> String:
	var f := _fixture()
	var scene: Control = f.scene
	var alternate := CardDatabase.get_card("30thC", "125").duplicate() as CardData
	alternate.set_code = "ui_missing_image"
	alternate.card_index = "000"
	alternate.image_local_path = ""
	alternate.image_url = ""
	(f.fighting as CardInstance).card_data = alternate
	scene.call("_show_next_effect_interaction_step")
	var view := _source(scene, 0)
	if view == null:
		return "Missing evolution field picker"
	var checks: Array[String] = [
		assert_true((view.get("_missing_art_panel") as Control).visible, "Exercise actual missing art"),
		assert_str_contains((view.get("_subtitle_label") as Label).text, "125", "Short printing caption survives missing art"),
		assert_str_contains((_source(scene, 1).get("_subtitle_label") as Label).text, "015", "Same-attribute printings stay distinct"),
	]
	_select(scene, 0, 0)
	(scene.get("_field_interaction_confirm_btn") as Button).button_down.emit()
	checks.append(assert_true(f.player.active_pokemon.get_top_card() == f.fighting, "Missing art still submits exact instance"))
	return run_checks(checks)


func test_only_current_legal_pairs_are_highlighted_and_accepted() -> String:
	var f := _fixture()
	var scene: Control = f.scene
	var steps: Array[Dictionary] = scene.get("_pending_effect_steps")
	# Two different evolution lines: the current frontier alone decides legality.
	steps[0].items = [steps[0].items[0], steps[0].items[4]]
	scene.call("_show_next_effect_interaction_step")
	if _source(scene, 1) == null:
		return "Missing evolution field picker"
	_source(scene, 1).left_clicked.emit(f.water, f.water.card_data)
	var targets: Dictionary = scene.get("_field_interaction_slot_index_by_id")
	var checks: Array[String] = [
		assert_false(targets.has("my_active"), "Other source's target must not glow"),
		assert_eq(targets.get("my_bench_0", -1), 1, "Legal target retains the original target index"),
	]
	scene.call("_handle_field_assignment_target_index", 0)
	checks.append(assert_eq((scene.get("_field_interaction_assignment_entries") as Array).size(), 0, "Cross-product pair outside frontier is rejected"))
	scene.call("_handle_field_assignment_target_index", 1)
	(scene.get("_field_interaction_confirm_btn") as Button).button_down.emit()
	checks.append(assert_true(f.player.bench[0].get_top_card() == f.water, "Allowed projected pair still resolves canonically"))
	return run_checks(checks)


func test_stale_evolution_selection_does_not_consume_new_window() -> String:
	var f := _fixture()
	var scene: Control = f.scene
	if _source(scene, 1) == null:
		return "Missing evolution field picker"
	_select(scene, 1, 1)
	var stale_data: Dictionary = (scene.get("_field_interaction_data") as Dictionary).duplicate()
	var stale_entries: Array = (scene.get("_field_interaction_assignment_entries") as Array).duplicate()
	scene.call("_reset_effect_interaction")
	scene.call("_try_play_trainer_with_interaction", 0, f.candy)
	scene.set("_field_interaction_data", stale_data)
	scene.set("_field_interaction_assignment_entries", stale_entries)
	scene.call("_finalize_field_assignment_selection")
	return run_checks([
		assert_true(f.candy in f.player.hand, "Old confirmation cannot spend Candy in a fresh window"),
		assert_eq(f.player.bench[0].pokemon_stack.size(), 1, "Old confirmation cannot evolve a target"),
		assert_eq(str(scene.get("_field_interaction_mode")), "assignment", "Rejected stale response rebuilds current picker"),
	])


func _capture(tree: SceneTree, label: String) -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evolution-capture="):
			var directory := arg.trim_prefix("--evolution-capture=")
			DirAccess.make_dir_recursive_absolute(directory)
			await RenderingServer.frame_post_draw
			tree.root.get_texture().get_image().save_png(directory.path_join(label + ".png"))


func _click_viewport(tree: SceneTree, point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.position = point
		event.global_position = point
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
		Input.parse_input_event(event)
		await tree.process_frame
	for frame: int in 8:
		await tree.process_frame
	await tree.create_timer(0.15).timeout


func test_3d_evolution_uses_real_viewport_clicks_for_source_target_and_confirm() -> String:
	return await _exercise_3d_evolution(false)


func test_3d_evolution_releases_previous_hand_gesture() -> String:
	return await _exercise_3d_evolution(true)


func _exercise_3d_evolution(interrupted_hand_press: bool) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_size := tree.root.size
	var previous_scale := tree.root.content_scale_size
	var previous_3d := GameManager.battle_3d_enabled
	var previous_mode := GameManager.current_mode
	GameManager.battle_3d_enabled = true
	GameManager.current_mode = GameManager.GameMode.VS_AI
	tree.root.size = Vector2i(1600, 900)
	tree.root.content_scale_size = Vector2i(1600, 900)
	var scene: Control = BattleScenePacked.instantiate()
	scene.set_script(EvolutionScenario)
	tree.root.add_child(scene)
	var f := _fixture(false, scene, false)
	for frame: int in 20:
		await tree.process_frame
	var checks: Array[String] = []
	var hand_row: Control = scene.get("_hand_container")
	var candy_view: BattleCardView
	for candidate: Node in hand_row.get_children():
		if candidate is BattleCardView and candidate.card_instance == f.candy:
			candy_view = candidate
	checks.append(assert_true(candy_view != null, "Candy is displayed in the 3D hand"))
	if candy_view != null:
		if interrupted_hand_press:
			# A UI transition can replace the old pointer target before its release.
			# Start the real hand gesture and open the next window without its tail.
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.button_mask = MOUSE_BUTTON_MASK_LEFT
			press.pressed = true
			var hand_scroll: Control = scene.get("_hand_scroll")
			press.position = hand_scroll.get_global_rect().position + Vector2(10, hand_scroll.size.y * 0.5)
			press.global_position = press.position
			tree.root.push_input(press, true)
			checks.append(assert_true(bool(scene.get("_hand_drag_active")), "Fixture owns an unfinished hand press"))
			scene.call("_try_play_trainer_with_interaction", 0, f.candy)
		else:
			await _click_viewport(tree, candy_view.get_global_rect().get_center())
			var use_button: Button = scene.get("_detail_use_btn")
			checks.append(assert_true(use_button.is_visible_in_tree(), "Hand click opens the trainer's Use action"))
			await _click_viewport(tree, use_button.get_global_rect().get_center())
	for frame: int in 8:
		await tree.process_frame
	var presenter := scene.get_node_or_null("Arena3DPresenter")
	var source_index := 0 if interrupted_hand_press else 1
	var chosen: CardInstance = f.fighting if interrupted_hand_press else f.water
	var remaining: CardInstance = f.water if interrupted_hand_press else f.fighting
	var label := "evolution-3d-interrupted" if interrupted_hand_press else "evolution-3d"
	var view := _source(scene, source_index)
	checks.append(assert_true(presenter != null and view != null, "The installed 3D scene shows the evolution picker"))
	if presenter != null and view != null:
		await _capture(tree, label + "-cards")
		await _click_viewport(tree, view.get_global_rect().get_center())
		checks.append(assert_eq(int(scene.get("_field_interaction_assignment_selected_source_index")), source_index, "Fresh 3D mouse click selects the exact evolution card"))
		checks.append(assert_false((scene.get("_field_interaction_scroll") as Control).visible, "Source click collapses the picker"))
		if int(scene.get("_field_interaction_assignment_selected_source_index")) == source_index:
			await _capture(tree, label + "-targets")
			var world: Node3D = presenter.get("world")
			var target_node: Node3D = world.get("cards").my_bench_0.node
			var local: Vector2 = world.get("camera").unproject_position(target_node.position)
			await _click_viewport(tree, presenter.get_global_transform() * local)
			checks.append(assert_eq(scene.call("_field_interaction_selected_slot_ids"), ["my_bench_0"], "Real 3D picking selects the intended Bench"))
			checks.append(assert_true(f.candy in f.player.hand, "Target click waits for confirmation"))
			await _capture(tree, label + "-confirm")
			var confirm: Button = scene.get("_field_interaction_confirm_btn")
			# Keep the legacy board guard armed even on a slow rendering runner.
			# A fresh HUD click must not enter the hidden 2D bench input fallback.
			scene.set("_modal_input_slot_suppress_until_msec", Time.get_ticks_msec() + 2000)
			await _click_viewport(tree, confirm.get_global_rect().get_center())
			checks.append(assert_true(f.player.bench[0].get_top_card() == chosen, "Confirmation executes the exact printing/Bench pair"))
			checks.append(assert_true(f.candy in f.player.discard_pile and remaining in f.player.hand, "Confirmation consumes only Candy and the chosen printing"))
	scene.free()
	await tree.process_frame
	GameManager.battle_3d_enabled = previous_3d
	GameManager.current_mode = previous_mode
	tree.root.size = previous_size
	tree.root.content_scale_size = previous_scale
	return run_checks(checks)


func test_packed_scene_field_picker_details_and_targets_across_layouts() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_size := tree.root.size
	var previous_scale := tree.root.content_scale_size
	var previous_layout := GameManager.battle_layout_mode
	var previous_3d := GameManager.battle_3d_enabled
	GameManager.battle_3d_enabled = false
	var checks: Array[String] = []
	for viewport_size: Vector2i in [Vector2i(1600, 900), Vector2i(900, 1600), Vector2i(390, 844), Vector2i(844, 390)]:
		tree.root.size = viewport_size
		tree.root.content_scale_size = viewport_size
		GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT if viewport_size.y > viewport_size.x else GameManager.BATTLE_LAYOUT_LANDSCAPE
		var scene: Control = BattleScenePacked.instantiate()
		scene.set_script(EvolutionScenario)
		tree.root.add_child(scene)
		for frame: int in 4:
			await tree.process_frame
		var f := _fixture(false, scene)
		for frame: int in 8:
			await tree.process_frame
		var view := _source(scene, 1)
		if view == null:
			checks.append("Missing visual evolution picker")
			scene.free()
			continue
		var panel: Control = scene.get("_field_interaction_panel")
		var scroll: ScrollContainer = scene.get("_field_interaction_scroll")
		var label := "evolution-%dx%d" % [viewport_size.x, viewport_size.y]
		checks.append(assert_eq((scene.get("_field_interaction_row") as HBoxContainer).get_child_count(), 2, "Responsive picker never duplicates evolution cards"))
		checks.append(assert_true((view.get("_selection_badge") as Label).is_visible_in_tree(), "Attribute badge stays visible after ready and layout"))
		checks.append(assert_eq((view.get("_selection_badge") as Label).text, "水系", "Responsive layout preserves Water badge"))
		checks.append(assert_str_contains((view.get("_subtitle_label") as Label).text, "015", "Responsive layout preserves the printing caption"))
		var badge_rect := (view.get("_selection_badge") as Label).get_global_rect()
		checks.append(assert_true(view.get_global_rect().encloses(badge_rect), "Attribute badge must be inside visible card: %s / %s" % [badge_rect, view.get_global_rect()]))
		checks.append(assert_true((view.get("_selection_badge") as Label).get_theme_font_size("font_size") >= view.size.x * 0.12, "Attribute text remains readable on the scaled portrait canvas"))
		checks.append(assert_true(panel.get_global_rect().position.y >= 0.0 and panel.get_global_rect().end.y <= scene.size.y + 1.0, "Card picker fits vertically: %s / %s" % [panel.get_global_rect(), scene.size]))
		await _capture(tree, label + "-cards")
		view.right_clicked.emit(view.card_instance, view.card_data)
		var detail := scene.get("_detail_card_view") as BattleCardView
		checks.append(assert_true(detail != null and detail.card_data == f.water.card_data, "Detail gesture opens the exact printing"))
		checks.append(assert_true(f.candy in f.player.hand, "Viewing details never evolves"))
		(scene.get("_detail_overlay") as Control).hide()
		view.left_clicked.emit(view.card_instance, view.card_data)
		for frame: int in 4:
			await tree.process_frame
		checks.append(assert_false(scroll.visible, "Source cards collapse after selection"))
		var slots: Dictionary = scene.get("_slot_card_views")
		for slot_id: String in ["my_active", "my_bench_0", "my_bench_1"]:
			var target := slots.get(slot_id) as BattleCardView
			checks.append(assert_true(target != null and target.card_data == CardDatabase.get_card("CSV2C", "028"), "Actual battle displays the prepared target"))
			checks.append(assert_false(panel.get_global_rect().intersects(target.get_global_rect()), "Compact picker leaves legal target exposed: %s" % slot_id))
		await _capture(tree, label + "-targets")
		var target_click := InputEventMouseButton.new()
		target_click.button_index = MOUSE_BUTTON_LEFT
		target_click.position = (slots.my_bench_0 as Control).get_global_rect().get_center()
		target_click.global_position = target_click.position
		target_click.pressed = true
		scene.call("_on_slot_input", target_click, "my_bench_0")
		target_click.pressed = false
		scene.call("_on_slot_input", target_click, "my_bench_0")
		for frame: int in 4:
			await tree.process_frame
		checks.append(assert_true((scene.get("_field_interaction_confirm_btn") as Button).is_visible_in_tree(), "Evolution confirmation is reachable"))
		checks.append(assert_eq(scene.call("_field_interaction_selected_slot_ids"), ["my_bench_0"], "Only the selected target is marked"))
		await _capture(tree, label + "-confirm")
		scene.free()
		await tree.process_frame
	GameManager.battle_layout_mode = previous_layout
	GameManager.battle_3d_enabled = previous_3d
	tree.root.size = previous_size
	tree.root.content_scale_size = previous_scale
	return run_checks(checks)
