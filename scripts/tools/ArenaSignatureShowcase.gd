extends Node
## Opt-in local Windows demonstration, using the real scene and rules runtime.
var rig: Node
var overlay: CanvasLayer
var cover: ColorRect
var title: Label
var subtitle: Label
var chapter := 0
var evidence: Array[Dictionary] = []
var visible_frame_us: Array[int] = []
var previous_tick := 0

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if previous_tick > 0 and is_instance_valid(cover) and cover.modulate.a < .01:
		visible_frame_us.append(now-previous_tick)
	previous_tick = now

func _ready() -> void:
	get_tree().root.set_meta("performance_bench_offline",true)
	call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("display/window/size/window_width",1920)
	ProjectSettings.set_setting("display/window/size/window_height",1080)
	get_tree().root.size = Vector2i(1920,1080)
	_build_overlay()
	await _gallery("dragapult")
	await _chapter("dragapult",1,"多龙巴鲁托 ex","幻影潜袭 · 6 个指示物，按真实落点分配")
	await _wait(2.2)
	rig.attack()
	await _wait(4.3)
	_record("dragapult")
	await _gallery("munkidori")
	await _chapter("dragapult",1,"愿增猿","亢奋脑力 · 伤害汇聚，再转移到对手")
	await _wait(1.6)
	rig.transfer()
	await _wait(4.0)
	_record("munkidori")
	await _gallery("charizard")
	await _chapter("charizard",1,"喷火龙 ex","燃烧黑暗 · 火光与冲击，落在对战桌上")
	await _wait(1.6)
	rig.attack()
	await _wait(4.3)
	_record("charizard")
	for id: String in ["ceruledge","terapagos","grimmsnarl","zoroark","archaludon","ho_oh","budew","garchomp","raging_bolt","pikachu_tera"]:
		await _gallery(id)
	await _chapter("charizard",0,"最后一张奖赏","击倒、领取奖赏，让对战回到你的手中")
	var player: PlayerState = rig.gsm.game_state.players[0]
	var previous: Array[CardInstance] = player.prizes.duplicate()
	var last: Array[CardInstance] = [previous.pop_front()]
	player.deck.append_array(previous)
	player.set_prizes(last)
	rig.gsm.game_state.players[1].active_pokemon.damage_counters = 210
	rig.battle.call("_refresh_ui")
	var presenter: Node = rig.battle.get_node("Arena3DPresenter")
	presenter.motion.clear()
	presenter.motion.shown = {}
	presenter._refresh()
	await _wait(1.8)
	rig.attack()
	await _wait(2.5)
	var clicked := false
	for button: Button in presenter.prize_buttons:
		if button.is_visible_in_tree() and not button.disabled:
			var event := InputEventMouseButton.new()
			event.position = button.get_global_rect().get_center()
			event.global_position = event.position
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = true
			get_tree().root.push_input(event,true)
			await get_tree().process_frame
			event = event.duplicate()
			event.pressed = false
			get_tree().root.push_input(event,true)
			clicked = true
			break
	await _wait(2.3)
	evidence.append({"chapter":"final_prize","clicked":clicked,"game_over":rig.gsm.game_state.is_game_over(),"prizes":player.prizes.size()})
	var success: bool = clicked and rig.gsm.game_state.is_game_over() and player.prizes.is_empty()
	print("ARENA_SIGNATURE_SHOWCASE ",JSON.stringify(evidence))
	visible_frame_us.sort()
	var timing: Dictionary = {}
	if not visible_frame_us.is_empty():
		timing = {"movie_capture":OS.has_feature("movie"),"frames":visible_frame_us.size(),"median_ms":visible_frame_us[visible_frame_us.size()/2]/1000.0,"p95_ms":visible_frame_us[int(visible_frame_us.size()*.95)]/1000.0}
		print("ARENA_SIGNATURE_TIMING ",JSON.stringify(timing))
	# Player exports suppress stdout; keep opt-in acceptance evidence in their isolated user data.
	var report := FileAccess.open("user://arena-signature-showcase.json",FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"success":success,"chapters":evidence,"timing":timing,"gallery_roster":preload("res://scenes/arena3d/ArenaPokemonCatalog.gd").ENTRIES.keys()},"\t"))
	if not success: push_error("Final prize did not complete through Viewport input")
	await _fade(1.0)
	await rig.close()
	rig.free()
	overlay.queue_free()
	get_tree().quit(0 if success else 1)

func _gallery(species: String) -> void:
	await _fade(1.0)
	if is_instance_valid(rig):
		await rig.close()
		rig.free()
		rig = null
	var gallery := preload("res://scripts/tools/ArenaPokemonGallery.gd").new()
	gallery.species = species
	overlay.add_child(gallery)
	overlay.move_child(cover,-1)
	await _fade(0.0)
	await _wait(9.4)
	await _fade(1.0)
	gallery.queue_free()
	await get_tree().process_frame

func _chapter(species: String, owner: int, heading: String, detail: String) -> void:
	await _fade(1.0)
	if is_instance_valid(rig):
		await rig.close()
		rig.free()
	rig = preload("res://scripts/tools/ArenaSignatureScenario.gd").new()
	add_child(rig)
	await rig.mount(species,owner)
	chapter += 1
	title.text = "%02d  /  %s" % [chapter,heading]
	subtitle.text = detail
	await _fade(0.0)

func _record(name: String) -> void:
	var presenter: Node = rig.battle.get_node("Arena3DPresenter")
	evidence.append({"chapter":name,"outcome":presenter.world.signature_vfx.last_outcome.duplicate(true),"human_picker":rig.battle.get("_field_interaction_overlay").visible,"finished":not presenter.motion.is_busy()})

func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 240
	add_child(overlay)
	var bar := ColorRect.new()
	bar.color = Color("0b1916")
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 58
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bar)
	var brand := Label.new()
	brand.text = "PTCG DOJO   /   3D CHARACTERS"
	brand.add_theme_font_size_override("font_size",20)
	brand.add_theme_color_override("font_color",Color("d9c88b"))
	brand.position = Vector2(28,15)
	bar.add_child(brand)
	title = Label.new()
	title.position = Vector2(475,10)
	title.add_theme_font_size_override("font_size",25)
	title.add_theme_color_override("font_color",Color("f4efdd"))
	bar.add_child(title)
	subtitle = Label.new()
	subtitle.position = Vector2(1050,18)
	subtitle.add_theme_font_size_override("font_size",17)
	subtitle.add_theme_color_override("font_color",Color("b9c9bf"))
	bar.add_child(subtitle)
	var note := Label.new()
	note.text = "Windows 实机录制  ·  实体 3D 模型 / 预设局面 / 真实招式与特性结算  ·  v0.6.2"
	note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	note.offset_top = -25
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size",14)
	note.add_theme_color_override("font_color",Color("aebfb3"))
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color("0b1916",.98)
	plate.content_margin_top = 3
	plate.content_margin_bottom = 3
	note.add_theme_stylebox_override("normal",plate)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(note)
	cover = ColorRect.new()
	cover.color = Color("08120f")
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cover)

func _fade(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(cover,"modulate:a",alpha,0.30)
	await tween.finished

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
