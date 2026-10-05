extends SceneTree
## Developer-only render review. Uses an isolated user-data root supplied by the caller.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var output := "res://.tmp/deck-center-redesign/screens"
	var kind := "center"
	var dimensions := Vector2i(1360, 860)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		if arg.begins_with("--screen="):
			var parts := arg.trim_prefix("--screen=").split("x")
			dimensions = Vector2i(int(parts[0]), int(parts[1]))
		if arg.begins_with("--view="):
			kind = arg.trim_prefix("--view=")
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = dimensions
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var manager := root.get_node("GameManager")
	manager.set_scene_navigation_suppressed_for_tests(true)
	var database := root.get_node("CardDatabase")
	var decks: Array = database.get_all_decks()
	var deck: DeckData = decks[0]
	for item: DeckData in decks:
		if item.id == 675700:
			deck = item
	var scene: Control
	if kind.begins_with("editor"):
		manager.goto_deck_editor(deck.id)
		scene = load("res://scenes/deck_editor/DeckEditor.tscn").instantiate()
	else:
		scene = load("res://scenes/deck_manager/DeckManager.tscn").instantiate()
	viewport.add_child(scene)
	for i: int in 12:
		await process_frame
	if kind == "detail":
		scene.call("_on_view_deck", deck)
	elif kind == "more":
		scene.get("_center_ui").show_more(deck.id)
	elif kind == "import":
		scene.call("_on_import_pressed")
	elif kind == "preview":
		scene.call("_on_import_pressed")
		scene.call("_on_import_completed", DeckData.from_dict(deck.to_dict().duplicate(true)), PackedStringArray())
	elif kind == "card":
		var entry: Dictionary = deck.cards[0]
		scene.call("_show_card_detail", database.get_card(str(entry.set_code), str(entry.card_index)))
	elif kind == "article":
		scene.call("_on_recommendation_read_pressed", scene.get("_current_recommendation"))
	elif kind == "new":
		scene.call("_on_new_deck_pressed")
	elif kind == "share":
		scene.call("_on_share_deck_poster", deck)
		for i: int in 12:
			await create_timer(1).timeout
			if scene.get("_share_poster_prepared_image") != null:
				break
	elif kind == "center" or kind == "carousel":
		scene.get("_center_ui")._paused = true
		for i: int in 20:
			await create_timer(0.5).timeout
			var poster := scene.find_child("RecommendationPosterPreview", true, false) as TextureRect
			if poster != null and poster.texture != null:
				break
		if kind == "carousel":
			scene.get("_center_ui")._advance(1)
			await create_timer(0.12).timeout
	for i: int in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join("%s-%dx%d.png" % [kind, dimensions.x, dimensions.y])
	var image := viewport.get_texture().get_image()
	image.save_png(path)
	print("CAPTURED ", path)
	var report: Array[Dictionary] = []
	_collect_controls(scene, report)
	var file := FileAccess.open(path.replace(".png", ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	scene.queue_free()
	await process_frame
	quit()

func _collect_controls(node: Node, output: Array[Dictionary]) -> void:
	if node is Control and node.is_visible_in_tree():
		var control := node as Control
		if control is Button or control is LineEdit or control is ScrollContainer:
			output.append({"name": str(control.name), "position": [control.global_position.x, control.global_position.y], "size": [control.size.x, control.size.y], "text": control.text if control is Button or control is LineEdit else ""})
	for child: Node in node.get_children():
		_collect_controls(child, output)
