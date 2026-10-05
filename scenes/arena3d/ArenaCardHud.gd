extends Control
## Screen-space readability anchored to each moving public card. No input ownership.
const ThemeScript := preload("res://scenes/arena3d/ArenaTheme.gd")
const Energy := preload("res://scenes/battle/BattleCardView.gd").ENERGY_ICON_TEXTURES
const Status := preload("res://scenes/battle/BattleCardView.gd").STATUS_ICON_TEXTURES
var world: Node3D
var theme_id := "grove"
var hp_trails: Dictionary = {}
var tool_textures: Dictionary = {}
var last_render_revision := -1
var last_projection: Array = []
var covered_cards: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if world == null: return
	var changed: bool = last_render_revision != world.render_revision
	last_render_revision = world.render_revision
	# A creature's moving mesh does not necessarily move any HUD. Keep the
	# existing canvas commands until camera/card geometry, coverage or state moves.
	if world.low_quality:
		var projection: Array = [world.camera.transform,world.camera.size,world.screen_size,world.screen_origin,world.compact_board,theme_id]
		covered_cards.clear()
		for id: String in world.cards:
			var entry: Dictionary = world.cards[id]
			var covered: bool = world.signature_vfx.covers_card(id) or world.supporter_vfx.covers_card(id)
			covered_cards[id] = covered
			projection.append([entry.node.transform,entry.node.visible,entry.data,covered])
		changed = projection != last_projection
		last_projection = projection
	for id: String in world.cards:
		var data: Dictionary = world.cards[id].data
		if data.get("empty",true) or data.get("concealed",false):
			hp_trails.erase(id)
			continue
		var key: String = str(data.get("uid",""))+str(data.get("max_hp",0))
		var ratio := clampf(float(data.get("hp",0))/maxf(1,float(data.get("max_hp",1))),0,1)
		if not hp_trails.has(id) or hp_trails[id].key != key: hp_trails[id] = {"key":key,"value":ratio}
		if absf(float(hp_trails[id].value)-ratio) > .001:
			changed = true
			hp_trails[id].value = lerpf(float(hp_trails[id].value),ratio,1-exp(-delta*5)) if world.motion_enabled else ratio
		else: hp_trails[id].value = ratio
	if changed or not world.low_quality: queue_redraw()

func _plate(rect: Rect2, color: Color, border: Color, radius: int = 3) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	draw_style_box(style,rect)

func _text(value: String, rect: Rect2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var font := get_theme_default_font()
	var text := value
	while text.length() > 1 and font.get_string_size(text,align,-1,font_size).x > rect.size.x-4: text = text.left(text.length()-2)+"…"
	var at := rect.position+Vector2(2,(rect.size.y+font_size)*.5-3)
	draw_string_outline(font,at,text,align,rect.size.x-4,font_size,3,Color("061014"))
	draw_string(font,at,text,align,rect.size.x-4,font_size,color)

func _draw() -> void:
	if world == null or world.camera == null: return
	var palette: Dictionary = ThemeScript.palette(theme_id)
	var ink := Color(palette.ink)
	var trim := Color(palette.trim)
	for id: String in world.cards:
		var entry: Dictionary = world.cards[id]
		if world.low_quality:
			if covered_cards.get(id,false): continue
		else:
			if is_instance_valid(world.signature_vfx) and world.signature_vfx.covers_card(id): continue
			if is_instance_valid(world.supporter_vfx) and world.supporter_vfx.covers_card(id): continue
		var data: Dictionary = entry.data
		if not entry.node.visible or data.get("empty",true) or data.get("concealed",false) or id == "stadium": continue
		var r: Rect2 = world.card_screen_rect(id)
		if world.compact_board:
			_draw_compact_card(data,r)
			continue
		var font_size := clampi(roundi(r.size.x*.11),12,16)
		var h := clampf(r.size.x*.18,22,28)
		var ratio := clampf(float(data.hp)/maxi(1,data.max_hp),0,1)
		var health := Color("61e9aa") if ratio > .5 else (Color("f2c05b") if ratio > .25 else Color("ff6d5e"))
		# The card art owns identity. Only combat state is stacked from its foot upward.
		var bar := Rect2(Vector2(r.position.x+2,r.end.y-h-2),Vector2(r.size.x-4,h))
		_plate(bar,Color("08161b"),health.darkened(.2))
		var inner := bar.grow(-2)
		var trail := float(hp_trails.get(id,{}).get("value",ratio))
		draw_rect(Rect2(inner.position,Vector2(inner.size.x*maxf(trail,ratio),inner.size.y)),Color("edb461"))
		draw_rect(Rect2(inner.position,Vector2(inner.size.x*ratio,inner.size.y)),health.darkened(.53))
		draw_rect(Rect2(inner.position,Vector2(inner.size.x*ratio,inner.size.y*.38)),health.darkened(.35))
		draw_line(inner.position,inner.position+Vector2(inner.size.x*ratio,0),health.darkened(.10),2,true)
		_text("%d / %d" % [maxi(0,data.hp),data.max_hp],bar,font_size,Color.WHITE)
		var energies: Array = data.get("energy_icons",data.get("energy",[]))
		var stack_y := bar.position.y-2
		if not energies.is_empty():
			var counts := {}
			for kind in energies: counts[str(kind)] = int(counts.get(str(kind),0))+1
			var keys: Array = counts.keys()
			var shown_count := mini(4,keys.size())
			var extra_width := 22.0 if keys.size() > 4 else 0.0
			var w := minf(r.size.x-4,shown_count*39+8+extra_width)
			var rail := Rect2(Vector2(r.position.x+2,stack_y-26),Vector2(w,26))
			_plate(rail,Color("0b1c28"),Color(palette.accent).darkened(.25))
			for index in range(shown_count):
				var kind: String = keys[index]
				var icon: Texture2D = Energy.get(kind,Energy.get(kind.left(1),Energy.ANY))
				var cell_w := (w-6-extra_width)/shown_count
				var icon_size := minf(21,cell_w-12)
				var x: float = rail.position.x+3+index*cell_w
				draw_texture_rect(icon,Rect2(Vector2(x,rail.position.y+(26-icon_size)*.5),Vector2(icon_size,icon_size)),false)
				_text(str(counts[kind]),Rect2(Vector2(x+icon_size,rail.position.y),Vector2(cell_w-icon_size,26)),13,Color.WHITE)
			if keys.size() > 4: _text("+%d" % (keys.size()-4),Rect2(Vector2(rail.end.x-22,rail.position.y),Vector2(22,26)),11,ink)
			stack_y = rail.position.y-2
		if data.get("tool",false):
			var tool_rect := Rect2(Vector2(r.position.x+2,stack_y-29),Vector2(r.size.x-4,29))
			_plate(tool_rect,Color("312b1c"),Color("dfbd70"))
			var path: String = data.get("tool_image","")
			if not tool_textures.has(path): tool_textures[path] = _load_tool(path)
			var texture: Texture2D = tool_textures[path]
			if texture != null: draw_texture_rect(texture,Rect2(tool_rect.position+Vector2(4,3),Vector2(17,23)),false)
			_text(str(data.get("tool_name","道具")),Rect2(tool_rect.position+Vector2(25,0),tool_rect.size-Vector2(27,0)),clampi(font_size-1,12,15),Color("ffdfa0"))
		var states: Array = data.get("status",[])
		if data.get("ability_used",false):
			var used := Rect2(Vector2(r.end.x-55,r.position.y+29),Vector2(52,21))
			_plate(used,Color("253b47"),trim)
			_text("已用特性",used,10,Color("b7ccd5"))
		for i in range(states.size()):
			if Status.has(states[i]):
				var rect := Rect2(r.position+Vector2(4,4+i*25),Vector2(24,24))
				_plate(rect,Color("15212b"),Color("ffbd6d"))
				draw_texture_rect(Status[states[i]],rect.grow(-2),false)
		var damage: int = data.max_hp-data.hp
		if damage > 0:
			var badge := Rect2(Vector2(r.end.x-48,r.position.y+3),Vector2(45,23))
			_plate(badge,Color("632a2e"),Color("ed9c80"))
			_text("−%d" % damage,badge,12,Color("ffe6d5"))

func _draw_compact_card(data: Dictionary, r: Rect2) -> void:
	# A short 16:9 viewport can project cards narrower than the global touch
	# scale. Fit numeric rails to each card so icon/count cells never collide.
	var s: float = minf(world.hud_scale,maxf(.75,r.size.x/76.0))
	var h := 24.0*s
	var bar := Rect2(Vector2(r.position.x,r.end.y-h),Vector2(r.size.x,h))
	var ratio := clampf(float(data.hp)/maxi(1,data.max_hp),0,1)
	var health := Color("61e9aa") if ratio > .5 else (Color("f2c05b") if ratio > .25 else Color("ff6d5e"))
	_plate(bar,Color("08161b"),health.darkened(.2))
	var inner := bar.grow(-1)
	draw_rect(Rect2(inner.position,Vector2(inner.size.x*ratio,inner.size.y)),health.darkened(.6))
	_text("%d/%d" % [maxi(0,data.hp),data.max_hp],bar,roundi(15*s),Color.WHITE)
	# Compact layout keeps the same public information as desktop. Effective
	# energy units, actual status icons and the tool's identity must stay distinct.
	var energy: Array = data.get("energy_icons",data.get("energy",[]))
	var stack_y := bar.position.y
	if not energy.is_empty():
		var counts := {}
		for kind in energy: counts[str(kind)] = int(counts.get(str(kind),0))+1
		var columns := mini(maxi(1,floori(r.size.x/(34*s))),counts.size())
		var rows := ceili(float(counts.size())/columns)
		var rail := Rect2(Vector2(r.position.x,stack_y-22*s*rows),Vector2(r.size.x,22*s*rows))
		_plate(rail,Color("0b1c28"),Color("628ca0"))
		var keys: Array = counts.keys()
		for index in range(keys.size()):
			var kind: String = keys[index]
			var cell_w := r.size.x/columns
			var at := rail.position+Vector2((index%columns)*cell_w,floori(float(index)/columns)*22*s)
			var icon: Texture2D = Energy.get(kind,Energy.get(kind.left(1),Energy.ANY))
			draw_texture_rect(icon,Rect2(at+Vector2(1,1)*s,Vector2(18,18)*s),false)
			_text(str(counts[kind]),Rect2(at+Vector2(20*s,0),Vector2(cell_w-20*s,22*s)),roundi(13*s),Color.WHITE)
		stack_y = rail.position.y
	if data.get("tool",false):
		var tool_rect := Rect2(Vector2(r.position.x,stack_y-16*s),Vector2(r.size.x,16*s))
		_plate(tool_rect,Color("312b1c"),Color("dfbd70"))
		var path: String = data.get("tool_image","")
		if not tool_textures.has(path): tool_textures[path] = _load_tool(path)
		var texture: Texture2D = tool_textures[path]
		if texture != null: draw_texture_rect(texture,Rect2(tool_rect.position+Vector2(1,1)*s,Vector2(10,14)*s),false)
		_text(str(data.get("tool_name","道具")),Rect2(tool_rect.position+Vector2(12*s,0),tool_rect.size-Vector2(12*s,0)),roundi(9*s),Color("ffdfa0"))
	var states: Array = data.get("status",[])
	for index in range(states.size()):
		if Status.has(states[index]):
			var rect := Rect2(r.position+Vector2(1,1+index*19)*s,Vector2(18,18)*s)
			_plate(rect,Color("15212b"),Color("ffbd6d"))
			draw_texture_rect(Status[states[index]],rect.grow(-s),false)
	var damage: int = data.get("damage",data.max_hp-data.hp)
	if damage > 0:
		var badge := Rect2(Vector2(r.end.x-31*s,r.position.y),Vector2(31,14)*s)
		_plate(badge,Color("632a2e"),Color("ed9c80"))
		_text("−%d" % damage,badge,roundi(9*s),Color("ffe6d5"))
	if data.get("ability_used",false):
		var used := Rect2(Vector2(r.end.x-38*s,r.position.y+15*s),Vector2(38,14)*s)
		_plate(used,Color("253b47"),Color("8a9da7"))
		_text("已用特性",used,roundi(8*s),Color("b7ccd5"))

func _load_tool(path: String) -> Texture2D:
	if path == "" or not FileAccess.file_exists(path): return null
	var bytes := FileAccess.get_file_as_bytes(path)
	var picture := Image.new()
	var error := ERR_FILE_UNRECOGNIZED
	if CardData.has_png_signature(bytes): error = picture.load_png_from_buffer(bytes)
	elif CardData.has_jpg_signature(bytes): error = picture.load_jpg_from_buffer(bytes)
	elif CardData.has_webp_signature(bytes): error = picture.load_webp_from_buffer(bytes)
	return ImageTexture.create_from_image(picture) if error == OK else null
