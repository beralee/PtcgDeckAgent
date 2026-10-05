extends SceneTree
## Render real discussion controls with a caller-provided isolated APPDATA.
## No model request is made. --output=<absolute directory> is required.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if output.is_empty():
		push_error("Provide --output=<absolute directory>")
		quit(1)
		return
	root.get_node("GameManager").set_scene_navigation_suppressed_for_tests(true)
	DirAccess.make_dir_recursive_absolute(output)
	for dimensions: Vector2i in [Vector2i(1360, 860), Vector2i(390, 844), Vector2i(844, 390)]:
		for kind: String in ["deck", "match", "battle", "keyboard"]:
			var surface := SubViewportContainer.new()
			root.add_child(surface)
			var viewport := SubViewport.new()
			viewport.size = dimensions
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			surface.add_child(viewport)
			var host := Control.new()
			viewport.add_child(host)
			host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var probe = load("res://web/e2e/DeepSeekDiscussionProbe.gd").new()
			probe.open(host, kind)
			var dialog: Control = probe.dialog
			dialog._add_message_bubble("user", "这回合如何安排？", {})
			dialog._add_message_bubble("assistant", "# 当前计划\n先确认战斗场与备战区，再安排本回合能量。\n\n- 保留下一回合可用的支援者。\n- [b]这段方括号是原文[/b]。\n\n**可以继续追问具体卡牌。**", {})
			var suggestions: Array[String] = ["先手如何安排？", "下一回合如何规划？"]
			dialog._refresh_suggestion_buttons(suggestions, true)
			if kind == "keyboard" and dimensions.y > dimensions.x:
				dialog.set_process(false)
				dialog.apply_portrait_keyboard_inset(300)
				dialog.get_node("%StatusLabel").text = "网络请求失败，请稍后重试。问题已保留。"
			for frame in range(15):
				await process_frame
			await RenderingServer.frame_post_draw
			var result := viewport.get_texture().get_image().save_png(output.path_join("%s-%dx%d.png" % [kind, dimensions.x, dimensions.y]))
			if result != OK:
				quit(1)
				return
			surface.queue_free()
			await process_frame
	quit()
