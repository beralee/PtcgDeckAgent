extends SceneTree
## Local visual review, with a caller-provided isolated APPDATA.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.get_node("GameManager").set_scene_navigation_suppressed_for_tests(true)
	var output := "res://.godot_test_user/modal_review"
	DirAccess.make_dir_recursive_absolute(output)
	for dimensions: Vector2i in [Vector2i(1360, 860), Vector2i(390, 844), Vector2i(844, 390)]:
		for kind: String in ["rename", "delete", "error", "discussion", "strategy", "ai_select", "ai_loading", "deck_view"]:
			var viewport := SubViewport.new()
			viewport.size = dimensions
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var scene: Control
			if kind in ["rename", "delete"]:
				scene = load("res://scenes/deck_manager/DeckManager.tscn").instantiate()
			elif kind in ["strategy", "ai_select", "ai_loading"]:
				scene = load("res://scenes/deck_editor/DeckEditor.tscn").instantiate()
			else:
				scene = Control.new()
			viewport.add_child(scene)
			scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for i: int in 6:
				await process_frame
			var deck := DeckData.new()
			deck.id = 9912345
			deck.deck_name = "玛俐与长毛巨魔 ex"
			if kind == "rename":
				scene.call("_on_rename_deck", deck)
			elif kind == "delete":
				scene.call("_on_delete_deck", deck)
			elif kind == "discussion":
				var dialog: Control = load("res://scenes/deck_editor/DeckDiscussionDialog.tscn").instantiate()
				scene.add_child(dialog)
				dialog.setup_for_deck(deck)
				dialog.popup_for_viewport(Rect2(Vector2.ZERO, dimensions), dimensions.y > dimensions.x)
			elif kind in ["strategy", "ai_select", "ai_loading"]:
				scene.set("_deck", deck)
				if kind == "strategy":
					scene.call("_on_strategy_pressed")
				elif kind == "ai_select":
					scene.call("_on_ai_pressed")
				else:
					scene.call("_show_ai_loading")
			elif kind == "deck_view":
				var helper = load("res://scripts/ui/decks/DeckViewDialog.gd").new()
				var decks: Array = root.get_node("CardDatabase").get_all_decks()
				helper.show_deck(scene, decks[0])
			else:
				var dialog := preload("res://scripts/ui/GameModalDialog.gd").new()
				dialog.title = "无法保存卡组"
				dialog.dialog_text = "请调整以下问题后再保存：\n\n卡组需要正好 60 张卡牌。\n请加入至少一张基础宝可梦。"
				dialog.ok_button_text = "继续编辑"
				scene.add_child(dialog)
				dialog.popup_centered()
			for i: int in 12:
				await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(output.path_join("%s-%dx%d.png" % [kind, dimensions.x, dimensions.y]))
			viewport.queue_free()
			await process_frame
	quit()
