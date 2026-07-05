class_name TestBattleModalEndTurnInputIsolation
extends TestBase

const BattleScenePacked := preload("res://scenes/battle/BattleScene.tscn")


class SpyEndTurnGameStateMachine extends GameStateMachine:
	var end_turn_calls := 0
	var last_player_index := -1

	func end_turn(player_index: int) -> void:
		end_turn_calls += 1
		last_player_index = player_index


func _make_basic_pokemon_card(card_name: String) -> CardData:
	var card_data := CardData.new()
	card_data.name = card_name
	card_data.card_type = "Pokemon"
	card_data.stage = "Basic"
	card_data.hp = 70
	card_data.energy_type = "C"
	card_data.retreat_cost = 1
	return card_data


func _make_stadium_card(card_name: String = "Test Stadium") -> CardData:
	var card_data := CardData.new()
	card_data.name = card_name
	card_data.card_type = "Stadium"
	return card_data


func _make_spy_gsm() -> SpyEndTurnGameStateMachine:
	var gsm := SpyEndTurnGameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	gsm.game_state = state
	return gsm


func _prepare_dialog_scene(scene: Control, gsm: GameStateMachine) -> void:
	scene.set("_view_player", 0)
	scene.set("_gsm", gsm)
	scene.set("_dialog_overlay", scene.find_child("DialogOverlay", true, false))
	scene.set("_dialog_title", scene.find_child("DialogTitle", true, false))
	scene.set("_dialog_list", scene.find_child("DialogList", true, false))
	scene.set("_dialog_confirm", scene.find_child("DialogConfirm", true, false))
	scene.set("_dialog_cancel", scene.find_child("DialogCancel", true, false))
	scene.set("_dialog_box", scene.find_child("DialogBox", true, false))
	scene.set("_dialog_vbox", scene.find_child("DialogVBox", true, false))
	scene.set("_handover_panel", scene.find_child("HandoverPanel", true, false))
	scene.set("_detail_overlay", scene.find_child("DetailOverlay", true, false))
	scene.set("_discard_overlay", scene.find_child("DiscardOverlay", true, false))
	scene.set("_coin_overlay", scene.find_child("CoinFlipOverlay", true, false))
	scene.set("_review_overlay", scene.find_child("ReviewOverlay", true, false))
	scene.set("_hand_container", scene.find_child("HandContainer", true, false))
	scene.set("_hud_end_turn_btn", scene.find_child("HudEndTurnBtn", true, false))
	scene.set("_btn_end_turn", scene.find_child("BtnEndTurn", true, false))
	if scene.get("_dialog_card_scroll") == null:
		scene.call("_setup_dialog_gallery")


func _open_portrait_full_library_effect_dialog(scene: Control) -> void:
	scene.call("_apply_portrait_layout", Vector2(390, 844))
	var visible_cards: Array[CardInstance] = []
	var visible_labels: Array[String] = []
	for i: int in 12:
		var card_name := "Deck Pokemon %02d" % i
		visible_cards.append(CardInstance.create(_make_basic_pokemon_card(card_name), 0))
		visible_labels.append(card_name)
	var selectable_cards: Array[CardInstance] = [visible_cards[1], visible_cards[4], visible_cards[8]]
	var card_indices := [-1, 0, -1, -1, 1, -1, -1, -1, 2, -1, -1, -1]
	var source_card := CardInstance.create(_make_stadium_card("Zeus Help Search"), 0)
	var steps: Array[Dictionary] = [{
		"id": "search_pokemon",
		"title": "Choose a Pokemon",
		"items": selectable_cards,
		"labels": ["Deck Pokemon 01", "Deck Pokemon 04", "Deck Pokemon 08"],
		"presentation": "cards",
		"card_items": visible_cards,
		"card_indices": card_indices,
		"choice_labels": visible_labels,
		"visible_scope": "own_full_deck",
		"min_select": 0,
		"max_select": 1,
		"allow_cancel": true,
	}]
	scene.call("_start_effect_interaction", "zeus_help", 0, steps, source_card)


func test_portrait_full_library_dialog_blocks_leaked_end_turn_button_press() -> String:
	var previous_layout: String = GameManager.battle_layout_mode
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	var scene: Control = BattleScenePacked.instantiate()
	var gsm := _make_spy_gsm()
	_prepare_dialog_scene(scene, gsm)
	_open_portrait_full_library_effect_dialog(scene)

	var dialog_overlay := scene.get("_dialog_overlay") as Control
	var hud_end_turn := scene.get("_hud_end_turn_btn") as Button
	if hud_end_turn != null:
		hud_end_turn.disabled = false
		var end_turn_callable := Callable(scene, "_on_end_turn")
		if not hud_end_turn.pressed.is_connected(end_turn_callable):
			hud_end_turn.pressed.connect(end_turn_callable)
		hud_end_turn.pressed.emit()

	var result := run_checks([
		assert_eq(str(scene.get("_pending_choice")), "effect_interaction", "The regression setup should leave the full-library choice dialog active"),
		assert_true(dialog_overlay != null and dialog_overlay.visible, "The regression setup should show the shared dialog overlay"),
		assert_true(bool(scene.call("_is_board_modal_overlay_visible")), "Visible dialog overlays should be treated as board-modal blockers"),
		assert_eq(gsm.end_turn_calls, 0, "A leaked HudEndTurnBtn press during a visible full-library dialog must not end the turn"),
	])
	scene.queue_free()
	GameManager.battle_layout_mode = previous_layout
	return result


func test_zeus_help_dialog_blocks_leaked_end_turn_button_press() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	var gsm := _make_spy_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	player.deck = [
		CardInstance.create(_make_basic_pokemon_card("Zeus Deck A"), 0),
		CardInstance.create(_make_basic_pokemon_card("Zeus Deck B"), 0),
	]
	_prepare_dialog_scene(scene, gsm)
	scene.call("_on_zeus_help_pressed")

	var dialog_overlay := scene.get("_dialog_overlay") as Control
	var hud_end_turn := scene.get("_hud_end_turn_btn") as Button
	if hud_end_turn != null:
		hud_end_turn.disabled = false
		var end_turn_callable := Callable(scene, "_on_end_turn")
		if not hud_end_turn.pressed.is_connected(end_turn_callable):
			hud_end_turn.pressed.connect(end_turn_callable)
		hud_end_turn.pressed.emit()

	var result := run_checks([
		assert_eq(str(scene.get("_pending_choice")), "zeus_help", "The regression setup should leave the Zeus Help choice dialog active"),
		assert_true(dialog_overlay != null and dialog_overlay.visible, "Zeus Help should show the shared dialog overlay"),
		assert_eq(gsm.end_turn_calls, 0, "A leaked HudEndTurnBtn press during Zeus Help selection must not end the turn"),
	])
	scene.queue_free()
	return result


func test_live_action_gate_rejects_visible_effect_choice_dialog() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	var gsm := _make_spy_gsm()
	_prepare_dialog_scene(scene, gsm)
	_open_portrait_full_library_effect_dialog(scene)

	var can_accept_live_action := bool(scene.call("_can_accept_live_action"))
	scene.call("_on_end_turn")

	var result := run_checks([
		assert_false(can_accept_live_action, "Live actions should be blocked while an effect-interaction card dialog is active"),
		assert_eq(gsm.end_turn_calls, 0, "Calling the end-turn action while an effect dialog is active must be a no-op"),
	])
	scene.queue_free()
	return result


func test_portrait_dialog_card_over_end_turn_button_remains_mouse_clickable() -> String:
	return await _run_portrait_dialog_card_over_end_turn_button_remains_pointer_clickable(false)


func test_portrait_dialog_card_over_end_turn_button_remains_screen_touch_clickable() -> String:
	return await _run_portrait_dialog_card_over_end_turn_button_remains_pointer_clickable(true)


func _run_portrait_dialog_card_over_end_turn_button_remains_pointer_clickable(use_screen_touch: bool) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return "SceneTree is required for viewport touch dispatch"
	var previous_layout: String = GameManager.battle_layout_mode
	var previous_window_size := DisplayServer.window_get_size()
	var previous_root_size := tree.root.size
	var previous_content_scale_size := tree.root.content_scale_size
	var viewport_size := Vector2(390, 844)
	_resize_test_viewport(tree, viewport_size)
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT

	var scene: Control = BattleScenePacked.instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	scene.size = viewport_size
	scene.call("_apply_portrait_layout", viewport_size)
	await tree.process_frame

	var gsm := _make_spy_gsm()
	_prepare_dialog_scene(scene, gsm)
	_open_portrait_full_library_effect_dialog(scene)
	await tree.process_frame
	await tree.process_frame

	var hud_end_turn := scene.get("_hud_end_turn_btn") as Button
	var target_card := _first_selectable_dialog_card_view(scene)
	var target_input_control := _dialog_input_control_for_card(target_card)
	var target_choice_index := _dialog_choice_index_for_card(target_card)
	var clicked := [0]
	var card_gui_hits := [0]
	var target_release_hits := [0]
	var catcher_gui_hits := [0]
	var overlay_gui_hits := [0]
	var scroll_gui_hits := [0]
	var end_turn_gui_hits := [0]
	var dialog_overlay := scene.get("_dialog_overlay") as Control
	var dialog_scroll := _dialog_choice_scroll(scene) as Control
	if dialog_overlay != null:
		dialog_overlay.gui_input.connect(func(_event: InputEvent) -> void:
			overlay_gui_hits[0] += 1
		)
	if dialog_scroll != null:
		dialog_scroll.gui_input.connect(func(_event: InputEvent) -> void:
			scroll_gui_hits[0] += 1
		)
	if target_card != null:
		target_card.left_clicked.connect(func(_ci: CardInstance, _cd: CardData) -> void:
			clicked[0] += 1
		)
		target_card.gui_input.connect(func(_event: InputEvent) -> void:
			card_gui_hits[0] += 1
		)
		var catcher := target_card.find_child("CardInputCatcher", true, false) as Control
		if catcher != null:
			catcher.gui_input.connect(func(_event: InputEvent) -> void:
				catcher_gui_hits[0] += 1
			)
	if target_input_control != null:
		target_input_control.gui_input.connect(func(event: InputEvent) -> void:
			if _is_primary_pointer_release_event(event):
				target_release_hits[0] += 1
			)
	var target_rect := target_card.get_global_rect() if target_card != null else Rect2()
	var touch_rect := _visible_touch_rect_for_control(scene, target_card)
	var touch_position := touch_rect.get_center()
	var input_label := "screen touch" if use_screen_touch else "mouse pointer"
	if hud_end_turn != null and target_rect.size.x > 0.0 and target_rect.size.y > 0.0:
		hud_end_turn.gui_input.connect(func(_event: InputEvent) -> void:
			end_turn_gui_hits[0] += 1
		)
		_force_button_over_rect(hud_end_turn, target_rect)
		hud_end_turn.disabled = false
		hud_end_turn.mouse_filter = Control.MOUSE_FILTER_STOP
		scene.call("_refresh_end_turn_hud_button_state")

	var modal_filter := hud_end_turn.mouse_filter if hud_end_turn != null else -1
	if touch_rect.size.x > 0.0 and touch_rect.size.y > 0.0:
		if use_screen_touch and target_input_control != null:
			_emit_primary_pointer_to_control(target_input_control, touch_position, true, true)
			await tree.process_frame
			_emit_primary_pointer_to_control(target_input_control, touch_position, false, true)
			await tree.process_frame
			await tree.process_frame
		else:
			_push_primary_pointer(scene, touch_position, true, use_screen_touch)
			await tree.process_frame
			_push_primary_pointer(scene, touch_position, false, use_screen_touch)
			await tree.process_frame
			await tree.process_frame
		if use_screen_touch:
			_push_primary_pointer(scene, touch_position, true, false)
			await tree.process_frame
			_push_primary_pointer(scene, touch_position, false, false)
			await tree.process_frame
			await tree.process_frame
	var selected_after_input: Array = (scene.get("_dialog_card_selected_indices") as Array).duplicate()
	var target_selected_after_input := target_choice_index >= 0 and selected_after_input.has(target_choice_index)

	var result := run_checks([
		assert_not_null(hud_end_turn, "Regression setup should find the portrait HUD end-turn button"),
		assert_not_null(target_card, "Regression setup should find a selectable dialog card"),
		assert_true(target_rect.size.x > 0.0 and target_rect.size.y > 0.0, "Selectable dialog card should have a usable global rect"),
		assert_true(touch_rect.size.x > 0.0 and touch_rect.size.y > 0.0, "Selectable dialog card should expose a visible touch rect inside the viewport"),
		assert_eq(modal_filter, Control.MOUSE_FILTER_IGNORE, "Visible modal dialogs should remove the underlying end-turn button from hit testing"),
		assert_true(clicked[0] == 1 or target_release_hits[0] > 0 or target_selected_after_input, "A dialog card overlapping the end-turn button should still receive the %s click; clicked=%d target_release=%d selected=%s card_gui=%d catcher_gui=%d overlay_gui=%d scroll_gui=%d end_turn_gui=%d controls=%s" % [
			input_label,
			clicked[0],
			target_release_hits[0],
			str(selected_after_input),
			card_gui_hits[0],
			catcher_gui_hits[0],
			overlay_gui_hits[0],
			scroll_gui_hits[0],
			end_turn_gui_hits[0],
			_controls_at_point_summary(tree.root, touch_position),
		]),
		assert_eq(gsm.end_turn_calls, 0, "The overlapping card %s click and any follow-up mouse echo must not leak into end-turn" % input_label),
	])

	if hud_end_turn != null and hud_end_turn.has_method("set_as_top_level"):
		hud_end_turn.call("set_as_top_level", false)
	scene.queue_free()
	await tree.process_frame
	GameManager.battle_layout_mode = previous_layout
	DisplayServer.window_set_size(previous_window_size)
	tree.root.size = previous_root_size
	tree.root.content_scale_size = previous_content_scale_size
	return result


func test_end_turn_button_hit_testing_restores_after_dialog_closes() -> String:
	var scene: Control = BattleScenePacked.instantiate()
	var gsm := _make_spy_gsm()
	_prepare_dialog_scene(scene, gsm)
	_open_portrait_full_library_effect_dialog(scene)
	var hud_end_turn := scene.get("_hud_end_turn_btn") as Button
	scene.call("_refresh_end_turn_hud_button_state")
	var during_modal := hud_end_turn.mouse_filter if hud_end_turn != null else -1

	var dialog_overlay := scene.get("_dialog_overlay") as Control
	if dialog_overlay != null:
		dialog_overlay.visible = false
	scene.set("_pending_choice", "")
	var after_modal := hud_end_turn.mouse_filter if hud_end_turn != null else -1

	var result := run_checks([
		assert_eq(during_modal, Control.MOUSE_FILTER_IGNORE, "End-turn button should be ignored while a card dialog is visible"),
		assert_eq(after_modal, Control.MOUSE_FILTER_STOP, "End-turn button hit testing should restore automatically after the card dialog closes"),
	])
	scene.queue_free()
	return result


func _first_selectable_dialog_card_view(scene: Control) -> BattleCardView:
	var dialog_row := _dialog_choice_row(scene)
	if dialog_row == null:
		return null
	var dialog_scroll := _dialog_choice_scroll(scene)
	var visible_rect := dialog_scroll.get_global_rect() if dialog_scroll != null else Rect2()
	var fallback: BattleCardView = null
	for child: Node in dialog_row.get_children():
		var card_view := _first_battle_card_view(child)
		if card_view == null:
			continue
		var real_index := int(card_view.get_meta("dialog_choice_index", child.get_meta("dialog_choice_index", -1)))
		if real_index >= 0:
			if fallback == null:
				fallback = card_view
			var card_rect := card_view.get_global_rect()
			if visible_rect.size == Vector2.ZERO or visible_rect.has_point(card_rect.get_center()):
				return card_view
	return fallback


func _dialog_choice_row(scene: Control) -> HBoxContainer:
	if scene == null:
		return null
	if bool(scene.get("_dialog_library_search_board_mode")):
		var library_row := scene.find_child("LibraryCardRow", true, false) as HBoxContainer
		if library_row != null:
			return library_row
	return scene.get("_dialog_card_row") as HBoxContainer


func _dialog_choice_scroll(scene: Control) -> ScrollContainer:
	if scene == null:
		return null
	if bool(scene.get("_dialog_library_search_board_mode")):
		var library_scroll := scene.find_child("LibrarySearchLibraryScroll", true, false) as ScrollContainer
		if library_scroll != null:
			return library_scroll
	return scene.get("_dialog_card_scroll") as ScrollContainer


func _first_battle_card_view(node: Node) -> BattleCardView:
	if node == null:
		return null
	var direct := node as BattleCardView
	if direct != null:
		return direct
	for child: Node in node.get_children():
		var found := _first_battle_card_view(child)
		if found != null:
			return found
	return null


func _dialog_input_control_for_card(card_view: BattleCardView) -> Control:
	if card_view == null:
		return null
	var parent := card_view.get_parent()
	while parent != null:
		var parent_control := parent as Control
		if parent_control != null and bool(parent_control.get_meta("library_search_candidate_slot", false)):
			return parent_control
		parent = parent.get_parent()
	return card_view


func _dialog_choice_index_for_card(card_view: BattleCardView) -> int:
	if card_view == null:
		return -1
	if card_view.has_meta("dialog_choice_index"):
		return int(card_view.get_meta("dialog_choice_index", -1))
	var parent := card_view.get_parent()
	while parent != null:
		var parent_control := parent as Control
		if parent_control != null and parent_control.has_meta("dialog_choice_index"):
			return int(parent_control.get_meta("dialog_choice_index", -1))
		parent = parent.get_parent()
	return -1


func _is_primary_pointer_release_event(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return not (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed
	return false


func _emit_primary_pointer_to_control(control: Control, position: Vector2, pressed: bool, use_screen_touch: bool) -> void:
	if control == null:
		return
	var event: InputEvent = null
	if use_screen_touch:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = pressed
		touch.position = position
		event = touch
	else:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		mouse.position = position
		mouse.global_position = position
		event = mouse
	control.emit_signal("gui_input", event)


func _force_button_over_rect(button: Button, rect: Rect2) -> void:
	if button.has_method("set_as_top_level"):
		button.call("set_as_top_level", true)
	button.visible = true
	button.z_index = 1000
	button.z_as_relative = false
	button.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	button.global_position = rect.position
	button.size = rect.size
	button.custom_minimum_size = rect.size


func _visible_touch_rect_for_control(scene: Control, control: Control) -> Rect2:
	if control == null:
		return Rect2()
	var rect := control.get_global_rect()
	var dialog_scroll := _dialog_choice_scroll(scene)
	if dialog_scroll != null:
		rect = rect.intersection(dialog_scroll.get_global_rect())
	var visible_rect := scene.get_global_rect()
	if visible_rect.size == Vector2.ZERO:
		visible_rect = Rect2(Vector2.ZERO, scene.size)
	rect = rect.intersection(visible_rect)
	return rect


func _resize_test_viewport(tree: SceneTree, viewport_size: Vector2) -> void:
	var size_i := Vector2i(int(viewport_size.x), int(viewport_size.y))
	DisplayServer.window_set_size(size_i)
	tree.root.size = size_i
	tree.root.content_scale_size = size_i


func _push_primary_pointer(scene: Control, position: Vector2, pressed: bool, use_screen_touch: bool = false) -> void:
	var event: InputEvent = null
	if use_screen_touch:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = pressed
		touch.position = position
		event = touch
	else:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		mouse.position = position
		mouse.global_position = position
		event = mouse
	if use_screen_touch and scene.has_method("_try_handle_library_search_board_touch_input"):
		if bool(scene.call("_try_handle_library_search_board_touch_input", event)):
			return
	var viewport := scene.get_viewport()
	if viewport != null and event != null:
		viewport.push_input(event, true)


func _controls_at_point_summary(node: Node, point: Vector2) -> String:
	var entries: Array[String] = []
	_collect_controls_at_point(node, point, entries)
	var start_index := maxi(0, entries.size() - 14)
	return "[%s]" % ", ".join(entries.slice(start_index, entries.size()))


func _collect_controls_at_point(node: Node, point: Vector2, entries: Array[String]) -> void:
	var control := node as Control
	if control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(point):
		entries.append("%s:%s mf=%d z=%d rect=%s" % [
			str(control.get_path()),
			control.get_class(),
			control.mouse_filter,
			control.z_index,
			str(control.get_global_rect()),
		])
	for child: Node in node.get_children():
		_collect_controls_at_point(child, point, entries)
