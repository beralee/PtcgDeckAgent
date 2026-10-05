extends Node

func _ready() -> void:
	get_tree().root.set_meta("performance_bench_offline",true)
	call_deferred("_run")

func _run() -> void:
	GameManager.ui_runtime_profile = UiRuntimeProfile.new({"host_kind":"native","native_os":"android","mobile_like":true,"pointer_mode":"touch","performance_tier":"low"})
	preload("res://scripts/commentary/CommentaryPreferences.gd").save_enabled(false)
	var rig := preload("res://scripts/tools/ArenaSignatureScenario.gd").new()
	get_tree().root.add_child(rig)
	await rig.mount_combat("dragapult")
	GameManager.ui_runtime_profile = UiRuntimeProfile.new({"host_kind":"native","native_os":"android","mobile_like":true,"pointer_mode":"touch","performance_tier":"low"})
	var p: Control = rig.battle.get_node("Arena3DPresenter")
	var talk := preload("res://scripts/commentary/OpponentTalkController.gd").new()
	rig.battle.add_child(talk)
	talk.setup(rig.battle,p,{})
	talk.director.opened = true
	var failures := 0
	for dimensions: Vector2i in [Vector2i(1080,1920),Vector2i(1920,1080),Vector2i(390,844)]:
		get_tree().root.size = dimensions
		get_tree().root.content_scale_size = preload("res://scenes/arena3d/ArenaPlatform.gd").canvas_size(dimensions)
		await get_tree().create_timer(.8).timeout
		GameManager.ui_runtime_profile = UiRuntimeProfile.new({"host_kind":"native","native_os":"android","mobile_like":true,"pointer_mode":"touch","performance_tier":"low"})
		rig.battle.call("_apply_responsive_layout")
		await get_tree().create_timer(.5).timeout
		for text: String in ["这回合我认真了！","别急，我的多龙巴鲁托ex已经准备好了。就决定是你了，幻影潜袭！"]:
			talk.panel.present(text,{"mood_id":"confident"})
			await get_tree().create_timer(.4).timeout
			var rect: Rect2 = talk.panel.get_global_rect()
			var active: Rect2 = p.world.card_screen_rect("opp_active")
			active.position += p.global_position
			var valid: bool = talk.panel.visible and rect.end.y <= active.position.y and absf(rect.get_center().x-rig.battle.get_viewport_rect().get_center().x) < 12
			valid = valid and talk.panel.body.text == text and talk.panel.body.get_visible_line_count() == talk.panel.body.get_line_count() and rect.encloses(talk.panel.body.get_global_rect())
			print("MOBILE_SPEECH_CHECK ",dimensions," long=",text.length()>15," ",valid," rect=",rect," active=",active)
			await RenderingServer.frame_post_draw
			get_tree().root.get_texture().get_image().save_png("user://speech-%dx%d-%d.png" % [dimensions.x,dimensions.y,text.length()])
			if not valid: failures += 1
	talk.close()
	await rig.close()
	rig.queue_free()
	if failures == 0: print("ARENA_MOBILE_SPEECH_PASS")
	get_tree().quit(0 if failures == 0 else 1)
