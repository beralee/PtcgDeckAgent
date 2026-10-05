extends "res://scripts/tools/ArenaPlatformAcceptance.gd"
var output := "/sdcard/Android/data/com.example.ptcgdeckagent.performance/files/performance/result.json"

func _run() -> void:
	await super._run()
	# Runtime release restores the app's preferred orientation before returning.
	# Report the window actually exercised, and validate it at every capture.
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"platform":OS.get_name(),"window":[tested_window.x,tested_window.y],"kind":"arena_viewport_touch_acceptance"}))

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	if not _check(get_tree().root.size == tested_window,"android_window_stable_"+filename): return
	var legacy: Control = battle.find_child("PortraitEdgeHudOverlay",true,false)
	if legacy != null and not _check(not legacy.is_visible_in_tree(),"legacy_2d_hud_hidden_"+filename): return
	get_viewport().get_texture().get_image().save_png(output.get_base_dir().path_join(filename))
