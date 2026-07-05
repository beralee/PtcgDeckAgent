extends SceneTree

const OUTPUT_DIR_REL := "res://tmp/library_search_board_probe"

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
	_game_manager.set("battle_layout_mode", str(_game_manager.BATTLE_LAYOUT_LANDSCAPE))

	var result := await _run_probe_case()

	_game_manager.set("current_mode", previous_mode)
	_game_manager.set("battle_layout_mode", previous_layout)
	if result == "":
		print("PASS landscape library search board probe screenshots=%s" % _output_dir)
		quit(0)
	else:
		print("FAIL %s" % result)
		quit(1)


func _run_probe_case() -> String:
	var viewport_size := Vector2(1280, 720)
	_resize_test_viewport(viewport_size)
	var scene: Control = _battle_scene_packed.instantiate()
	root.add_child(scene)
	await process_frame
	scene.size = viewport_size
	scene.call("_setup_dialog_gallery")
	scene.call("_apply_landscape_layout", viewport_size)
	await process_frame

	var source_card := CardInstance.create(_card_data("CSVH1C", "043", "Nest Ball", "Nest Ball", "Item"), 0)
	var cards: Array = [
		CardInstance.create(_card_data("151C", "004", "Charmander", "Charmander", "Pokemon"), 0),
		CardInstance.create(_card_data("CSV4C", "099", "Pidgey", "Pidgey", "Pokemon"), 0),
		CardInstance.create(_card_data("CSV8C", "157", "Dreepy", "Dreepy", "Pokemon"), 0),
		CardInstance.create(_card_data("CS6.5C", "023", "Rotom V", "Rotom V", "Pokemon"), 0),
	]
	var labels: Array = ["Charmander", "Pidgey", "Dreepy", "Rotom V"]
	scene.call("_show_dialog", "Choose 1 Basic Pokemon from your deck", labels, {
		"presentation": "cards",
		"visible_scope": "own_full_deck",
		"card_items": cards,
		"choice_labels": labels,
		"card_indices": [0, 1, 2, 3],
		"source_card": source_card,
		"source_kind": "Item",
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	})
	scene.call("_apply_landscape_layout", viewport_size)
	await process_frame
	await process_frame
	var board := scene.find_child("LibrarySearchBoard", true, false) as Control
	if board == null or not board.visible:
		scene.queue_free()
		await process_frame
		return "library search board was not visible"
	var open_path := _output_dir.path_join("01_open.png")
	var open_error: Error = await _save_root_screenshot(open_path)
	if open_error != OK:
		scene.queue_free()
		await process_frame
		return "failed to save open screenshot: %s" % error_string(open_error)

	var library_row := scene.find_child("LibraryCardRow", true, false) as Control
	var candidate_views := _battle_card_views_under(library_row)
	if candidate_views.size() < 2:
		scene.queue_free()
		await process_frame
		return "expected at least two candidate card views, got %d" % candidate_views.size()
	var target_view := candidate_views[1]
	var target_rect := target_view.get_global_rect()
	var target_slot := _candidate_slot_for_view(target_view)
	var target_slot_rect := target_slot.get_global_rect() if target_slot != null else Rect2()
	var library_scroll := scene.find_child("LibrarySearchLibraryScroll", true, false) as Control
	var library_scroll_rect := library_scroll.get_global_rect() if library_scroll != null else Rect2()
	if target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		scene.queue_free()
		await process_frame
		return "candidate target has empty rect %s" % str(target_rect)
	await _click(scene, target_rect.get_center())
	await process_frame
	var selected_indices: Array = scene.get("_dialog_card_selected_indices")
	if selected_indices != [1]:
		var target_path := str(target_view.get_path())
		var target_parent_path := str(target_view.get_parent().get_path() if target_view.get_parent() != null else NodePath(""))
		var target_slot_path := str(target_slot.get_path() if target_slot != null else NodePath(""))
		var controls_summary := _controls_at_point_summary(root, target_rect.get_center())
		var failure := "candidate click did not select real index 1; selected=%s target_path=%s target_parent=%s slot_path=%s target_rect=%s slot_rect=%s scroll_rect=%s click=%s root_visible=%s root_size=%s root_scale=%s window=%s controls=%s" % [
			str(selected_indices),
			target_path,
			target_parent_path,
			target_slot_path,
			str(target_rect),
			str(target_slot_rect),
			str(library_scroll_rect),
			str(target_rect.get_center()),
			str(root.get_visible_rect()),
			str(root.size),
			str(root.content_scale_size),
			str(DisplayServer.window_get_size()),
			controls_summary,
		]
		scene.queue_free()
		await process_frame
		return failure
	var selected_path := _output_dir.path_join("02_selected.png")
	var selected_error: Error = await _save_root_screenshot(selected_path)
	if selected_error != OK:
		scene.queue_free()
		await process_frame
		return "failed to save selected screenshot: %s" % error_string(selected_error)

	var confirm := scene.find_child("DialogConfirm", true, false) as Button
	if confirm == null or confirm.disabled:
		scene.queue_free()
		await process_frame
		return "confirm button missing or disabled"
	var confirm_rect := confirm.get_global_rect()
	await _click(scene, confirm_rect.get_center())
	await process_frame
	await process_frame
	var overlay := scene.find_child("DialogOverlay", true, false) as Control
	if overlay != null and overlay.visible:
		scene.queue_free()
		await process_frame
		return "confirm click did not close the dialog"
	var confirmed_path := _output_dir.path_join("03_confirmed.png")
	var confirmed_error: Error = await _save_root_screenshot(confirmed_path)
	scene.queue_free()
	await process_frame
	if confirmed_error != OK:
		return "failed to save confirmed screenshot: %s" % error_string(confirmed_error)
	return ""


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


func _click(scene: Control, position: Vector2) -> void:
	_push_mouse(scene, position, true)
	await process_frame
	_push_mouse(scene, position, false)
	await process_frame


func _push_mouse(scene: Control, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	var viewport := scene.get_viewport()
	if viewport != null:
		viewport.push_input(event, false)


func _save_root_screenshot(path: String) -> Error:
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		return ERR_CANT_CREATE
	return image.save_png(path)


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


func _candidate_slot_for_view(card_view: BattleCardView) -> Control:
	if card_view == null:
		return null
	var parent := card_view.get_parent()
	while parent != null:
		if parent is Control and (bool((parent as Control).get_meta("library_search_candidate_slot", false)) or str(parent.name) == "LibrarySearchCandidateSlot"):
			return parent as Control
		parent = parent.get_parent()
	return null


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
