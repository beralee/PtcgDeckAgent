extends SceneTree

const Dialog := preload("res://scripts/update/AppUpdateDialog.gd")


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var info := {"latest_version": "0.7.0", "display_version": "v0.7.0", "title": "更顺畅的练牌体验", "summary": ["新增卡牌与策略支持", "优化对战表现与稳定性", "现在可以在游戏内完成更新，不用离开游戏寻找安装包。"], "artifact": {"size": 180000000}, "download_page_url": "https://ptcg.skillserver.cn/"}
	for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(390, 844)]:
		var surface := SubViewport.new()
		surface.size = viewport_size
		surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(surface)
		for state: String in ["available", "downloading", "ready", "failed"]:
			var dialog := Dialog.new()
			surface.add_child(dialog)
			dialog.configure(null, info)
			dialog.refresh({"state": state, "message": {"available": "下载完成后，由你决定何时安装。", "downloading": "正在下载，可以关闭此窗口继续游戏。", "ready": "更新已下载并校验。安装会关闭并重新打开游戏，本地牌组和录像会保留。", "failed": "网络连接已中断，请检查网络后重试。"}[state], "total": 180000000, "downloaded": 108000000, "speed": 2000000, "install_reason": ""})
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var screen := Rect2(Vector2.ZERO, Vector2(viewport_size))
			for node: Node in dialog.find_children("*", "Button", true, false):
				if node.is_visible_in_tree() and not screen.encloses(node.get_global_rect()):
					surface.get_texture().get_image().save_png("res://.tmp/game-updater-20260919/ui-clipped.png")
					push_error("Update button clipped: %s %s %s %s panel=%s" % [viewport_size, state, node.text, node.get_global_rect(), dialog._panel.get_global_rect()])
					quit(1)
					return
			surface.get_texture().get_image().save_png("res://.tmp/game-updater-20260919/ui-%s-%s.png" % [viewport_size.x, state])
			dialog.queue_free()
			await process_frame
		surface.queue_free()
		await process_frame
	print("UPDATE_UI_CAPTURE_PASS: 8 layouts; all visible buttons inside viewport")
	quit(0)
