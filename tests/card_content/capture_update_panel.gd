extends SceneTree

class PreviewUpdater extends Node:
	signal state_changed(data: Dictionary)
	func snapshot() -> Dictionary:
		return {"state": "available", "message": "发现卡牌更新 · 2026.09.30.2", "current_version": "2026.09.30.1", "available_version": "2026.09.30.2", "notes": "新增卡牌已就绪。\n修复部分招式和特性的效果判定。\n更新在下次启动时应用，当前对局规则保持不变。", "auto_download": true, "busy": false, "total_bytes": 1840000}
	func set_auto_download(_enabled: bool) -> void: pass
	func check_for_updates(_manual: bool) -> void: pass
	func download_update() -> void: pass

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	await create_timer(0.3).timeout
	root.size = Vector2i(600, 900)
	root.content_scale_size = Vector2i.ZERO
	root.gui_embed_subwindows = true
	await process_frame
	var background := ColorRect.new()
	background.color = Color("0b1824")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var updater := PreviewUpdater.new()
	root.add_child(updater)
	var panel := preload("res://scripts/card_content/ContentUpdatePanel.gd").new()
	root.add_child(panel)
	panel.configure(updater)
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	var output := "res://artifacts/card_content/update-panel-portrait.png"
	root.get_texture().get_image().save_png(output)
	print("CAPTURE_SAVED ", output)
	quit()
