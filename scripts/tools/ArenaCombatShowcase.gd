extends "res://scripts/tools/ArenaSignatureShowcase.gd"
## Recording-only edit: real battle scenes, no model turntables or direct VFX calls.
const ROSTER := ["garchomp","zoroark","raging_bolt","gardevoir","dragapult","charizard","munkidori","ceruledge","terapagos","grimmsnarl","archaludon","ho_oh","budew","pikachu_tera"]

func _run() -> void:
	get_tree().root.size=Vector2i(1600,900)
	_build_overlay()
	var brand: Label=overlay.get_child(0).get_child(0)
	brand.text="PTCG DOJO  /  战斗场演出"
	brand.add_theme_font_size_override("font_size",19)
	title.position=Vector2(380,12)
	title.add_theme_font_size_override("font_size",23)
	subtitle.position=Vector2(900,19)
	subtitle.add_theme_font_size_override("font_size",17)
	var success:=true
	var roster: Array[String]=[]
	roster.assign(ROSTER)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--combat-select="):
			roster.clear()
			for selected: String in argument.trim_prefix("--combat-select=").split(","):
				if selected in ROSTER:roster.append(selected)
	for id: String in roster:
		var start_frame:=Engine.get_frames_drawn()
		await _fade(1.0)
		if is_instance_valid(rig):
			await rig.close()
			rig.free()
		rig=preload("res://scripts/tools/ArenaSignatureScenario.gd").new()
		add_child(rig)
		await rig.mount_combat(id)
		chapter+=1
		var catalog: Dictionary=preload("res://scenes/arena3d/ArenaPokemonCatalog.gd").ENTRIES
		title.text="%02d / %02d  %s" % [chapter,roster.size(),catalog[id].name]
		subtitle.text=rig.combat_move_name()
		var defender: PokemonSlot=rig.combat_recipient()
		var before:=defender.damage_counters
		await _fade(0.0)
		await _wait(.85)
		var attack_frame:=Engine.get_frames_drawn()
		var submitted: bool=rig.perform_combat()
		var beat: float=preload("res://scenes/arena3d/ArenaPokemonDirection.gd").profile(id).hit
		if OS.get_cmdline_user_args().has("--combat-review-samples"):
			await _wait(beat*.42)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("user://combat-%s-anticipation.png" % id)
			await _wait(beat*.34)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("user://combat-%s-travel.png" % id)
			await _wait(beat*.24+.08)
		else:await _wait(beat+.08)
		if OS.get_cmdline_user_args().has("--combat-screenshots"):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("user://combat-%s.png" % id)
		await _wait(4.20-beat-.08)
		var presenter: Node=rig.battle.get_node("Arena3DPresenter")
		var extra_wait:=0.0
		while presenter.motion.is_busy() and extra_wait<2.5:
			await get_tree().process_frame
			extra_wait+=get_process_delta_time()
		var outcome: Dictionary=presenter.world.signature_vfx.last_outcome.duplicate(true)
		var damage:=defender.damage_counters-before
		var entry: Dictionary={"species":id,"move":rig.combat_move_name(),"submitted":submitted,"damage":damage,"outcome":outcome,"finished":not presenter.motion.is_busy(),"human_picker":rig.battle.get("_field_interaction_overlay").visible}
		evidence.append(entry)
		success=success and submitted and damage>0 and outcome.get("species","")==id and entry.finished and not entry.human_picker
		subtitle.text="已结算 · 超能量 +1 / 伤害指示物 +2" if id=="gardevoir" else "已结算 · %d 点伤害%s" % [damage," · 转移完成" if id=="munkidori" else ""]
		await _wait(.75)
		entry["start_frame"]=start_frame
		entry["attack_frame"]=attack_frame
		entry["end_frame"]=Engine.get_frames_drawn()
		print("COMBAT_CHAPTER ",JSON.stringify(entry))
	await _fade(1.0)
	var report:=FileAccess.open("user://arena-combat-showcase.json",FileAccess.WRITE)
	if report!=null:report.store_string(JSON.stringify({"success":success,"chapters":evidence,"gallery_seconds":0,"playback_speed":1.0,"movie_capture":OS.has_feature("movie")},"\t"))
	await rig.close()
	rig.free()
	get_tree().quit(0 if success else 1)
