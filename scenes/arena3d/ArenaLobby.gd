extends Control
const WorldScript := preload("res://scenes/arena3d/ArenaWorld.gd")
const ThemeScript := preload("res://scenes/arena3d/ArenaTheme.gd")
var world: Node3D
var sub: SubViewport
var menu: VBoxContainer

func _ready() -> void:
	if "--arena-combat-showcase" in OS.get_cmdline_user_args():
		set_process(false)
		get_tree().root.set_meta("performance_bench_offline",true)
		get_tree().root.add_child.call_deferred(load("res://scripts/tools/ArenaCombatShowcase.gd").new())
		queue_free()
		return
	if "--arena-signature-showcase" in OS.get_cmdline_user_args():
		set_process(false)
		get_tree().root.add_child.call_deferred(load("res://scripts/tools/ArenaSignatureShowcase.gd").new())
		queue_free()
		return
	if "--arena-platform-checks" in OS.get_cmdline_user_args():
		set_process(false)
		get_tree().root.add_child.call_deferred(load("res://scripts/tools/ArenaPlatformAcceptance.gd").new())
		queue_free()
		return
	if "--arena-ui-regression" in OS.get_cmdline_user_args():
		set_process(false)
		get_tree().root.add_child.call_deferred(load("res://scripts/tools/ArenaUiRegression.gd").new())
		queue_free()
		return
	if "--arena-knockout-checks" in OS.get_cmdline_user_args():
		set_process(false)
		get_tree().root.add_child.call_deferred(load("res://scripts/tools/ArenaKnockoutAcceptance.gd").new())
		queue_free()
		return
	if "--arena-search-checks" in OS.get_cmdline_user_args():
		set_process(false)
		get_tree().root.add_child.call_deferred(load("res://scripts/tools/ArenaSearchAcceptance.gd").new())
		queue_free()
		return
	if "--arena-card-back-checks" in OS.get_cmdline_user_args():
		set_process(false)
		get_tree().root.add_child.call_deferred(load("res://scripts/tools/ArenaCardBackAcceptance.gd").new())
		queue_free()
		return
	if "--arena-readability-checks" in OS.get_cmdline_user_args():
		set_process(false)
		get_tree().root.add_child.call_deferred(load("res://scripts/tools/ArenaReadabilityAcceptance.gd").new())
		queue_free()
		return
	if "--arena-stadium-checks" in OS.get_cmdline_user_args():
		set_process(false)
		get_tree().root.add_child.call_deferred(load("res://scripts/tools/ArenaStadiumAcceptance.gd").new())
		queue_free()
		return
	if "--arena-living-checks" in OS.get_cmdline_user_args():
		set_process(false)
		var checks = load("res://scripts/tools/ArenaLivingAcceptance.gd").new()
		get_tree().root.add_child.call_deferred(checks)
		queue_free()
		return
	if "--arena-motion-checks" in OS.get_cmdline_user_args():
		set_process(false)
		var checks = load("res://scripts/tools/ArenaMotionAcceptance.gd").new()
		get_tree().root.add_child.call_deferred(checks)
		queue_free()
		return
	if "--arena-battle-smoke" in OS.get_cmdline_user_args():
		set_process(false)
		var smoke = load("res://scripts/tools/Arena3DSmoke.gd").new()
		get_tree().root.add_child.call_deferred(smoke)
		queue_free()
		return
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	sub = SubViewport.new()
	sub.own_world_3d = true
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.msaa_3d = Viewport.MSAA_4X
	add_child(sub)
	world = WorldScript.new()
	sub.add_child(world)
	world.cinematic = true
	background.texture = sub.get_texture()
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){COLOR=vec4(0.015,0.03,0.055,0.94*(1.0-smoothstep(0.08,0.67,UV.x)));}"
	var material := ShaderMaterial.new()
	material.shader = shader
	shade.material = material
	add_child(shade)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation",16)
	add_child(menu)
	_label("P O K É M O N   T C G",18,Color("d4dba0"))
	_label("林间道馆",54,Color("edf6ff"))
	_label("GROVE  /  ARENA",24,Color("92aabd"))
	_label("熟悉的对战布局。更有质感的牌桌。",17,Color("bdc2bc"))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	menu.add_child(spacer)
	_button("进入对战    →",func(): GameManager.goto_battle_setup(),true)
	_button("卡组管理",func(): GameManager.goto_scene(GameManager.SCENE_DECK_MANAGER))
	_button("对战录像",func(): GameManager.goto_scene(GameManager.SCENE_REPLAY_BROWSER))
	_button("设置",func(): GameManager.goto_scene(GameManager.SCENE_SETTINGS))
	_button("退出游戏",func(): get_tree().quit())
	var footer := Label.new()
	footer.text = "WINDOWS  /  3D EDITION     ·     本地卡牌对战"
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(58,size.y-42)
	footer.add_theme_font_size_override("font_size",13)
	footer.modulate = Color("7892a7")
	add_child(footer)
	resized.connect(func(): footer.position = Vector2(58,size.y-42))
	_populate_showcase()
	if "--arena-capture" in OS.get_cmdline_user_args():
		_capture()

func _populate_showcase() -> void:
	var slots := {}
	var samples: Array[CardData] = []
	for deck_id in [575720,800018501]:
		var deck: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/decks/%d.json" % deck_id))
		for row: Dictionary in deck.get("cards",[]):
			if row.get("card_type","") == "Pokemon":
				var data: CardData = CardDatabase.get_card(row.set_code,row.card_index)
				if data != null: samples.append(data)
	var i := 0
	for id: String in world.cards:
		if samples.is_empty(): break
		var cd: CardData = samples[i%samples.size()]
		slots[id] = {"empty": false,"concealed": false,"uid": cd.get_uid(),"name": cd.display_name(),"hp": cd.hp,"max_hp": cd.hp,"type": cd.energy_type,"energy": ["L","L"],"status": [],"tool": false,"evolution": 1,"image": CardData.resolve_existing_image_path(CardData.get_image_candidate_paths(cd.set_code,cd.card_index,cd.image_local_path))}
		i += 1
	world.display({"slots": slots})
	for card: Dictionary in world.cards.values():
		card.label.visible = false
		card.hp.visible = false

func _label(text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.modulate = color
	menu.add_child(label)

func _button(text: String, action: Callable, primary: bool = false) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(330,52)
	button.add_theme_font_size_override("font_size",19)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("aadfeb") if primary else Color(.03,.065,.10,.8)
	style.border_color = Color("365567")
	style.set_border_width_all(0 if primary else 1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 22
	button.add_theme_stylebox_override("normal",style)
	button.add_theme_color_override("font_color",Color("102d43") if primary else Color("d5e6ef"))
	var hover := style.duplicate()
	hover.bg_color = Color("daf5ff") if primary else Color("215777")
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_color_override("font_hover_color",Color("102d43") if primary else Color.WHITE)
	button.pressed.connect(action)
	menu.add_child(button)

func _process(_delta: float) -> void:
	sub.size = Vector2i(size)
	menu.position = Vector2(maxf(40,size.x*.055),maxf(36,(size.y-menu.size.y)*.43))

func _capture() -> void:
	await get_tree().create_timer(3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://arena-lobby.png")
	print("ARENA_CAPTURE ",ProjectSettings.globalize_path("user://arena-lobby.png"))
	get_tree().quit()
