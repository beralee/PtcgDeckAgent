extends SceneTree

const OUTPUT_DIR_REL := "res://tmp/portrait_library_search_board_probe"

var _battle_scene_packed: PackedScene = null
var _game_manager: Node = null
var _card_database: Node = null
var _output_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game_manager = root.get_node_or_null("GameManager")
	if _game_manager == null:
		print("FAIL missing /root/GameManager autoload")
		quit(1)
		return
	_card_database = root.get_node_or_null("CardDatabase")
	_battle_scene_packed = load("res://scenes/battle/BattleScene.tscn") as PackedScene
	if _battle_scene_packed == null:
		print("FAIL unable to load BattleScene.tscn")
		quit(1)
		return

	_output_dir = ProjectSettings.globalize_path(OUTPUT_DIR_REL)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	var previous_mode: int = int(_game_manager.get("current_mode"))
	var previous_layout: String = str(_game_manager.get("battle_layout_mode"))
	_game_manager.set("current_mode", int(_game_manager.GameMode.TWO_PLAYER))
	_game_manager.set("battle_layout_mode", str(_game_manager.BATTLE_LAYOUT_PORTRAIT))

	var cases := [
		{"name": "android_touch", "size": Vector2(390, 844), "input": "touch"},
		{"name": "web_mouse", "size": Vector2(430, 932), "input": "mouse"},
	]
	var failure := ""
	for probe_case: Dictionary in cases:
		failure = await _run_probe_case(
			str(probe_case.get("name", "")),
			probe_case.get("size", Vector2(390, 844)) as Vector2,
			str(probe_case.get("input", "mouse"))
		)
		if failure != "":
			break

	_game_manager.set("current_mode", previous_mode)
	_game_manager.set("battle_layout_mode", previous_layout)
	if failure == "":
		print("PASS portrait library search board probe screenshots=%s" % _output_dir)
		quit(0)
	else:
		print("FAIL %s" % failure)
		quit(1)


func _run_probe_case(case_name: String, viewport_size: Vector2, input_kind: String) -> String:
	_resize_test_viewport(viewport_size)
	var scene: Control = _battle_scene_packed.instantiate()
	root.add_child(scene)
	await process_frame
	scene.size = viewport_size
	scene.call("_setup_dialog_gallery")
	scene.call("_apply_portrait_layout", viewport_size)
	await process_frame

	var source_card := CardInstance.create(_card_data("CSVH1C", "043", "Nest Ball", "Nest Ball", "Item"), 0)
	var cards: Array = [
		CardInstance.create(_card_data("151C", "004", "Charmander", "Charmander", "Pokemon"), 0),
		CardInstance.create(_card_data("CSV4C", "099", "Pidgey", "Pidgey", "Pokemon"), 0),
		CardInstance.create(_card_data("CSV8C", "157", "Dreepy", "Dreepy", "Pokemon"), 0),
		CardInstance.create(_card_data("CS6.5C", "023", "Rotom V", "Rotom V", "Pokemon"), 0),
		CardInstance.create(_card_data("CSV9.5C", "068", "Zoroark ex", "Zoroark ex", "Pokemon"), 0),
		CardInstance.create(_card_data("CSV9C", "066", "N's Zorua", "N's Zorua", "Pokemon"), 0),
		CardInstance.create(_card_data("CSV9C", "067", "N's Zoroark ex", "N's Zoroark ex", "Pokemon"), 0),
		CardInstance.create(_card_data("CSV7C", "047", "Fezandipiti ex", "Fezandipiti ex", "Pokemon"), 0),
	]
	var labels: Array = ["Charmander", "Pidgey", "Dreepy", "Rotom V", "Zoroark ex", "N's Zorua", "N's Zoroark ex", "Fezandipiti ex"]
	scene.call("_show_dialog", "Choose up to 2 Basic Pokemon from your deck", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0, 1, -1, 2, 3, 4, 5, 6],
		"source_card": source_card,
		"source_kind": "Item",
		"min_select": 0,
		"max_select": 2,
		"allow_cancel": true,
	})
	scene.call("_apply_portrait_layout", viewport_size)
	scene.call("_sync_portrait_modal_overlay_rects")
	await process_frame
	await process_frame

	var board := scene.find_child("LibrarySearchBoard", true, false) as Control
	if board == null or not board.visible:
		return await _finish_failed_case(scene, "%s library search board was not visible" % case_name)
	var legacy_scroll := scene.get("_dialog_card_scroll") as ScrollContainer
	if legacy_scroll != null and legacy_scroll.visible:
		return await _finish_failed_case(scene, "%s legacy dialog card scroll stayed visible" % case_name)
	var source_panel := scene.find_child("LibrarySearchSourcePanel", true, false) as Control
	if source_panel != null and source_panel.visible:
		return await _finish_failed_case(scene, "%s portrait source rail stayed visible" % case_name)
	var portrait_source_panel := scene.find_child("LibrarySearchPortraitSourcePanel", true, false) as Control
	if portrait_source_panel == null or not portrait_source_panel.visible:
		return await _finish_failed_case(scene, "%s portrait source strip was not visible" % case_name)
	var portrait_source_holder := scene.find_child("LibrarySearchPortraitSourceCardHolder", true, false) as Control
	if _battle_card_views_under(portrait_source_holder).size() != 1:
		return await _finish_failed_case(scene, "%s portrait source strip did not render the played card" % case_name)
	var button_slot := scene.find_child("LibrarySearchButtonSlot", true, false) as Control
	if button_slot != null and button_slot.visible:
		return await _finish_failed_case(scene, "%s landscape button slot stayed visible" % case_name)
	var confirm := scene.find_child("DialogConfirm", true, false) as Button
	var buttons_row := confirm.get_parent() as HBoxContainer if confirm != null else null
	var dialog_vbox := scene.get("_dialog_vbox") as VBoxContainer
	if buttons_row == null or buttons_row.get_parent() != dialog_vbox:
		return await _finish_failed_case(scene, "%s confirm/cancel row is not in the bottom dialog footer" % case_name)
	if confirm == null or confirm.disabled:
		return await _finish_failed_case(scene, "%s confirm button missing or disabled" % case_name)
	var board_rect := board.get_global_rect()
	var confirm_rect := confirm.get_global_rect()
	if not _portrait_footer_is_after_board(scene, board_rect, confirm_rect):
		return await _finish_failed_case(scene, "%s confirm button is not after the portrait board footer axis: board=%s confirm=%s" % [
			case_name,
			str(board_rect),
			str(confirm_rect),
		])

	var library_scroll := scene.find_child("LibrarySearchLibraryScroll", true, false) as ScrollContainer
	if library_scroll == null or library_scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_SHOW_NEVER:
		return await _finish_failed_case(scene, "%s candidate rail is not the touch-drag rail" % case_name)
	var selected_row := scene.find_child("LibrarySelectedSlotRow", true, false) as Control
	if _library_empty_slot_count(selected_row) != 2:
		return await _finish_failed_case(scene, "%s expected two optional lower slots before selection" % case_name)
	if _first_empty_slot_label_font_size(selected_row) < 32:
		return await _finish_failed_case(scene, "%s optional lower-slot text is too small" % case_name)
	var instruction_label := scene.find_child("LibrarySearchInstructionLabel", true, false) as Label
	if instruction_label == null or instruction_label.get_theme_font_size("font_size") < 26:
		return await _finish_failed_case(scene, "%s instruction text is too small for portrait" % case_name)
	var library_row := scene.find_child("LibraryCardRow", true, false) as Control
	var candidate_views := _battle_card_views_under(library_row)
	if candidate_views.size() < 2:
		return await _finish_failed_case(scene, "%s expected at least two candidate card views, got %d" % [case_name, candidate_views.size()])
	var target_view := _first_legal_card_view(candidate_views)
	if target_view == null:
		return await _finish_failed_case(scene, "%s expected a legal candidate card view" % case_name)
	var target_index := int(target_view.get_meta("dialog_choice_index", -1))
	var target_rect := target_view.get_global_rect()
	var target_slot := _candidate_slot_for_view(target_view)
	if target_slot == null:
		return await _finish_failed_case(scene, "%s expected candidate card view to be wrapped by an input slot" % case_name)
	if target_rect.size.x < 72.0 or target_rect.size.y < 72.0:
		return await _finish_failed_case(scene, "%s candidate target is too small for portrait touch: %s" % [case_name, str(target_rect)])

	var open_path := _output_dir.path_join("%s_01_open.png" % case_name)
	var open_error: Error = await _save_root_screenshot(open_path)
	if open_error != OK:
		return await _finish_failed_case(scene, "%s failed to save open screenshot: %s" % [case_name, error_string(open_error)])

	await _drag_release_through_scroll(scene, target_slot, library_scroll, target_rect.get_center(), Vector2(96, 0), input_kind)
	await process_frame
	var selected_indices: Array = scene.get("_dialog_card_selected_indices")
	if not selected_indices.is_empty():
		return await _finish_failed_case(scene, "%s rightward drag-release selected a card: selected=%s" % [case_name, str(selected_indices)])
	await create_timer(0.28).timeout

	await _tap_candidate_slot(scene, target_slot, target_rect.get_center(), input_kind)
	await process_frame
	selected_indices = scene.get("_dialog_card_selected_indices")
	if selected_indices != [target_index]:
		return await _finish_failed_case(scene, "%s candidate input did not select real index %d; selected=%s controls=%s" % [
			case_name,
			target_index,
			str(selected_indices),
			_controls_at_point_summary(root, target_rect.get_center()),
		])
	if _battle_card_views_under(selected_row).size() != 1 or _library_empty_slot_count(selected_row) != 1:
		return await _finish_failed_case(scene, "%s selected rail did not replace one optional slot after selection" % case_name)

	var selected_path := _output_dir.path_join("%s_02_selected.png" % case_name)
	var selected_error: Error = await _save_root_screenshot(selected_path)
	if selected_error != OK:
		return await _finish_failed_case(scene, "%s failed to save selected screenshot: %s" % [case_name, error_string(selected_error)])

	await _tap_confirm(scene, confirm, confirm_rect.get_center(), input_kind)
	await process_frame
	await process_frame
	var overlay := scene.find_child("DialogOverlay", true, false) as Control
	if overlay != null and overlay.visible:
		return await _finish_failed_case(scene, "%s confirm input did not close the dialog" % case_name)
	var confirmed_path := _output_dir.path_join("%s_03_confirmed.png" % case_name)
	var confirmed_error: Error = await _save_root_screenshot(confirmed_path)
	scene.queue_free()
	await process_frame
	if confirmed_error != OK:
		return "%s failed to save confirmed screenshot: %s" % [case_name, error_string(confirmed_error)]
	return ""


func _finish_failed_case(scene: Control, message: String) -> String:
	if scene != null:
		var fail_path := _output_dir.path_join("%s_failure.png" % message.sha256_text().substr(0, 8))
		await _save_root_screenshot(fail_path)
		scene.queue_free()
		await process_frame
	return message


func _portrait_footer_is_after_board(scene: Control, board_rect: Rect2, confirm_rect: Rect2) -> bool:
	if bool(scene.get("_rotated_portrait_canvas_active")):
		return confirm_rect.end.x <= board_rect.position.x + 8.0
	return confirm_rect.position.y >= board_rect.end.y - 8.0


func _card_data(set_code: String, card_index: String, fallback_name: String, fallback_name_en: String, fallback_type: String) -> CardData:
	var loaded_variant: Variant = _card_database.call("get_card", set_code, card_index) if _card_database != null else null
	if loaded_variant is CardData:
		return loaded_variant as CardData
	var card := CardData.new()
	card.name = fallback_name
	card.name_en = fallback_name_en
	card.card_type = fallback_type
	card.stage = "Basic" if fallback_type == "Pokemon" else ""
	card.hp = 70 if fallback_type == "Pokemon" else 0
	card.energy_type = "C"
	return card


func _resize_test_viewport(viewport_size: Vector2) -> void:
	var size_i := Vector2i(int(viewport_size.x), int(viewport_size.y))
	DisplayServer.window_set_size(size_i)
	root.size = size_i
	root.content_scale_size = size_i


func _tap(scene: Control, position: Vector2, input_kind: String) -> void:
	if input_kind == "touch":
		_push_touch(scene, position, true)
		await process_frame
		_push_touch(scene, position, false)
	else:
		_push_mouse(scene, position, true)
		await process_frame
		_push_mouse(scene, position, false)
	await process_frame


func _tap_candidate_slot(scene: Control, slot: Control, position: Vector2, input_kind: String) -> void:
	if input_kind == "touch":
		_push_slot_touch(slot, position, true)
		await process_frame
		_push_slot_touch(slot, position, false)
		await process_frame
		return
	_push_slot_mouse(slot, position, true)
	await process_frame
	_push_slot_mouse(slot, position, false)
	await process_frame


func _drag_release_through_scroll(scene: Control, slot: Control, scroll: ScrollContainer, start_position: Vector2, delta: Vector2, input_kind: String) -> void:
	if input_kind == "touch":
		_push_slot_touch(slot, start_position, true)
		await process_frame
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = start_position + delta
		drag.relative = delta
		scene.call("_on_card_gallery_scroll_input", drag, scroll, "library_search_candidates")
		await process_frame
		_push_slot_touch(slot, start_position + delta, false)
		await process_frame
		return
	_push_slot_mouse(slot, start_position, true)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = start_position + delta
	motion.global_position = start_position + delta
	motion.relative = delta
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	scene.call("_on_card_gallery_scroll_input", motion, scroll, "library_search_candidates")
	await process_frame
	_push_slot_mouse(slot, start_position + delta, false)
	await process_frame


func _push_slot_touch(slot: Control, position: Vector2, pressed: bool) -> void:
	if slot == null:
		return
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = position
	slot.gui_input.emit(event)


func _push_slot_mouse(slot: Control, position: Vector2, pressed: bool) -> void:
	if slot == null:
		return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	slot.gui_input.emit(event)


func _candidate_slot_for_view(card_view: BattleCardView) -> Control:
	var parent := card_view.get_parent()
	while parent != null:
		if parent is Control and (bool((parent as Control).get_meta("library_search_candidate_slot", false)) or str(parent.name) == "LibrarySearchCandidateSlot"):
			return parent as Control
		parent = parent.get_parent()
	return null


func _tap_confirm(scene: Control, confirm: Button, position: Vector2, input_kind: String) -> void:
	if confirm != null:
		confirm.pressed.emit()
	await process_frame


func _push_touch(scene: Control, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = _portrait_touch_event_position(scene, position)
	var viewport := scene.get_viewport()
	if viewport != null:
		viewport.push_input(event, false)


func _portrait_touch_event_position(scene: Control, screen_position: Vector2) -> Vector2:
	if scene != null and bool(scene.get("_rotated_portrait_canvas_active")) and scene.has_method("_screen_position_to_battle_local"):
		var local_position: Variant = scene.call("_screen_position_to_battle_local", screen_position)
		if local_position is Vector2:
			return local_position as Vector2
	return screen_position


func _push_mouse(scene: Control, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	var event_position := _viewport_event_position(scene, position)
	event.position = event_position
	event.global_position = event_position
	var viewport := scene.get_viewport()
	if viewport != null:
		viewport.push_input(event, false)


func _viewport_event_position(scene: Control, logical_position: Vector2) -> Vector2:
	var texture := root.get_texture()
	if texture == null:
		return logical_position
	var texture_size := texture.get_size()
	var frame_rect_variant: Variant = scene.get("_portrait_layout_frame_rect") if scene != null else null
	if frame_rect_variant is Rect2:
		var frame_rect := frame_rect_variant as Rect2
		if frame_rect.size.x > texture_size.x + 1.0 or frame_rect.size.y > texture_size.y + 1.0:
			return Vector2(
				(logical_position.x - frame_rect.position.x) * texture_size.x / maxf(frame_rect.size.x, 1.0),
				(logical_position.y - frame_rect.position.y) * texture_size.y / maxf(frame_rect.size.y, 1.0)
			)
	return logical_position


func _save_root_screenshot(path: String) -> Error:
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		return ERR_CANT_CREATE
	return image.save_png(path)


func _first_legal_card_view(views: Array[BattleCardView]) -> BattleCardView:
	for view: BattleCardView in views:
		if int(view.get_meta("dialog_choice_index", -1)) >= 0:
			return view
	return null


func _battle_card_views_under(node: Node) -> Array[BattleCardView]:
	var result: Array[BattleCardView] = []
	_collect_battle_card_views(node, result)
	return result


func _collect_battle_card_views(node: Node, result: Array[BattleCardView]) -> void:
	if node == null:
		return
	if node is BattleCardView:
		result.append(node as BattleCardView)
	for child: Node in node.get_children():
		_collect_battle_card_views(child, result)


func _library_empty_slot_count(node: Node) -> int:
	if node == null:
		return 0
	var count := 0
	if bool(node.get_meta("library_search_empty_slot", false)):
		count += 1
	for child: Node in node.get_children():
		count += _library_empty_slot_count(child)
	return count


func _first_empty_slot_label_font_size(node: Node) -> int:
	if node == null:
		return 0
	if bool(node.get_meta("library_search_empty_slot", false)) and node.get_child_count() > 0 and node.get_child(0) is Label:
		return int((node.get_child(0) as Label).get_meta("library_search_empty_slot_font_size", 0))
	for child: Node in node.get_children():
		var size := _first_empty_slot_label_font_size(child)
		if size > 0:
			return size
	return 0


func _controls_at_point_summary(node: Node, point: Vector2) -> String:
	var entries: Array[String] = []
	_collect_controls_at_point(node, point, entries)
	var start_index: int = maxi(0, entries.size() - 12)
	return "[%s]" % ", ".join(entries.slice(start_index, entries.size()))


func _collect_controls_at_point(node: Node, point: Vector2, entries: Array[String]) -> void:
	var control := node as Control
	if control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(point):
		entries.append("%s:%s mf=%d rect=%s" % [
			str(control.get_path()),
			control.get_class(),
			control.mouse_filter,
			str(control.get_global_rect()),
		])
	for child: Node in node.get_children():
		_collect_controls_at_point(child, point, entries)
