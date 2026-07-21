extends SceneTree

const OUTPUT_DIR := "res://tmp/starter_deck_builder_probe"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame
	_print_selection_matrix()
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var cases := [
		{"name": "landscape", "size": Vector2i(1600, 900), "mode": "landscape"},
		{"name": "portrait", "size": Vector2i(390, 844), "mode": "portrait"},
	]
	for probe_case: Dictionary in cases:
		var error := await _capture_case(probe_case, output_dir)
		if error != "":
			print("FAIL %s" % error)
			quit(1)
			return
	print("PASS starter deck builder screenshots=%s" % output_dir)
	quit(0)


func _print_selection_matrix() -> void:
	var generator_script := load("res://scripts/deck_builder/StarterDeckGenerator.gd") as GDScript
	var card_database := root.get_node_or_null("CardDatabase")
	if generator_script == null or card_database == null:
		return
	var generator: RefCounted = generator_script.new()
	var catalog: Array[Dictionary] = generator.call("build_bundled_catalog", Callable(card_database, "get_card"))
	for energy_type: String in ["R", "W", "G", "L", "P", "F", "D", "M", "N", "C"]:
		var selected: Dictionary = generator.call("select_template", catalog, {
			"energy_type": energy_type,
			"axis": "auto",
			"pace": "balanced",
		})
		var deck := selected.get("deck") as DeckData
		var analysis: Dictionary = selected.get("analysis", {})
		var type_scores: Dictionary = analysis.get("type_scores", {})
		print("SELECTION %s -> %s type_score=%.1f core=%s" % [
			energy_type,
			deck.deck_name if deck != null else "none",
			float(type_scores.get(energy_type, 0.0)),
			str(analysis.get("core_name", "")),
		])


func _capture_case(probe_case: Dictionary, output_dir: String) -> String:
	var viewport_size: Vector2i = probe_case.get("size", Vector2i(1600, 900))
	var game_manager := root.get_node_or_null("GameManager")
	var previous_mode := str(game_manager.get("non_battle_layout_mode")) if game_manager != null else "landscape"
	if game_manager != null:
		game_manager.set("non_battle_layout_mode", str(probe_case.get("mode", "landscape")))
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var packed_scene := load("res://scenes/deck_manager/DeckManager.tscn") as PackedScene
	if packed_scene == null:
		viewport.queue_free()
		return "unable to load DeckManager scene"
	var scene := packed_scene.instantiate() as Control
	viewport.add_child(scene)
	await process_frame
	scene.position = Vector2.ZERO
	scene.size = Vector2(viewport_size)
	scene.call("_apply_non_battle_layout_for_tests", Vector2(viewport_size), str(probe_case.get("mode", "landscape")))
	scene.call("_refresh_deck_list")
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var header := scene.find_child("Header", true, false) as Control
	if header == null or not viewport_rect.encloses(header.get_global_rect()):
		var child_sizes := PackedStringArray()
		if header != null:
			for child: Node in header.get_children():
				if child is Control:
					child_sizes.append("%s=%s" % [child.name, str((child as Control).get_combined_minimum_size())])
		viewport.queue_free()
		if game_manager != null:
			game_manager.set("non_battle_layout_mode", previous_mode)
		return "deck center header is outside viewport: %s minimum=%s children=%s" % [
			str(header.get_global_rect() if header != null else Rect2()),
			str(header.get_combined_minimum_size() if header != null else Vector2.ZERO),
			str(child_sizes),
		]
	var center_path := output_dir.path_join("%s_center.png" % str(probe_case.get("name", "case")))
	var center_image := viewport.get_texture().get_image()
	if center_image == null or center_image.save_png(center_path) != OK:
		viewport.queue_free()
		if game_manager != null:
			game_manager.set("non_battle_layout_mode", previous_mode)
		return "unable to save deck center screenshot"
	var new_button := scene.get_node_or_null("%BtnNewDeck") as Button
	if new_button == null:
		viewport.queue_free()
		if game_manager != null:
			game_manager.set("non_battle_layout_mode", previous_mode)
		return "missing new-deck button"
	new_button.emit_signal("pressed")
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame

	var panel := scene.find_child("DeckActionHudPanel", true, false) as PanelContainer
	var cancel_button := scene.find_child("StarterDeckCancelButton", true, false) as Button
	var create_button := scene.find_child("StarterDeckCreateButton", true, false) as Button
	if panel == null or cancel_button == null or create_button == null:
		viewport.queue_free()
		if game_manager != null:
			game_manager.set("non_battle_layout_mode", previous_mode)
		return "starter deck builder controls missing"
	if not viewport_rect.encloses(panel.get_global_rect()):
		viewport.queue_free()
		if game_manager != null:
			game_manager.set("non_battle_layout_mode", previous_mode)
		return "builder panel is outside viewport: %s vs %s" % [str(panel.get_global_rect()), str(viewport_rect)]
	if cancel_button.get_global_rect().intersects(create_button.get_global_rect()):
		viewport.queue_free()
		if game_manager != null:
			game_manager.set("non_battle_layout_mode", previous_mode)
		return "builder footer buttons overlap"

	var image := viewport.get_texture().get_image()
	var output_path := output_dir.path_join("%s.png" % str(probe_case.get("name", "case")))
	var save_error := image.save_png(output_path) if image != null else ERR_CANT_CREATE
	viewport.queue_free()
	await process_frame
	if game_manager != null:
		game_manager.set("non_battle_layout_mode", previous_mode)
	if save_error != OK:
		return "unable to save screenshot: %s" % str(save_error)
	return ""
