extends Control
## Public zone labels and actionable reward focus, above physical 3D hardware.
const ThemeScript := preload("res://scenes/arena3d/ArenaTheme.gd")
var world: Node3D
var frame: Dictionary = {}
var theme_id := "grove"
var prize_ready := false
var prize_remaining := 0
var clock := 0.0
var last_projection: Array = []

func point(at: Vector3) -> Vector2:
	return world.project(at)

func prize_rect(index: int, mine: bool) -> Rect2:
	var at: Vector3 = world.prize_position(index,mine)
	var width: float = world.prize_width()
	var a := point(at-Vector3(width*.5,0,width*.715))
	var b := point(at+Vector3(width*.5,0,width*.715))
	return Rect2(a,b-a).abs()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if world != null and world.motion_enabled: clock += delta
	if world != null and world.low_quality:
		# Character/VFX redraws do not change pile labels or empty-slot outlines.
		# Keep their canvas commands until their own public state/projection changes.
		var projection: Array = [frame,theme_id,prize_ready,prize_remaining,
			world.camera.transform,world.camera.size,world.screen_size,world.screen_origin,
			world.compact_board,world.portrait_board,world.hud_scale,
			world.bench_counts.my,world.bench_counts.opp]
		for id: String in world.cards:
			var entry: Dictionary = world.cards[id]
			if entry.data.get("empty",true) and entry.node.visible:
				var rect: Rect2 = world.card_screen_rect(id)
				# Residual interpolation below a quarter UI pixel is not a visible
				# outline change and must not rebuild the whole pile-label canvas.
				projection.append([id,rect.position.snapped(Vector2(.25,.25)),rect.size.snapped(Vector2(.25,.25))])
		if projection == last_projection and (not prize_ready or world.compact_board): return
		last_projection = projection
	queue_redraw()

func _panel(rect: Rect2, fill: Color, edge: Color, border := 1) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(border)
	style.set_corner_radius_all(4)
	draw_style_box(style,rect)

func _draw() -> void:
	if world == null or world.camera == null or frame.is_empty(): return
	var palette := ThemeScript.palette(theme_id)
	var ink := Color(palette.ink)
	var muted := Color(palette.muted)
	var accent := Color(palette.accent)
	var font := get_theme_default_font()
	if world.compact_board:
		_draw_compact_zones(font,ink,accent)
	for mine in [false,true]:
		if world.compact_board: break
		var player: Dictionary = frame.players[frame.view if mine else 1-frame.view]
		var bounds := prize_rect(0,mine)
		for i in range(1,6): bounds = bounds.merge(prize_rect(i,mine))
		var header := Rect2(bounds.position-Vector2(7,34),Vector2(bounds.size.x+14,27))
		_panel(header,Color(.025,.055,.075,.94),Color(palette.trim))
		text(font,header.position+Vector2(9,19),("你的奖赏" if mine else "对手奖赏")+"  %d / 6" % player.prizes,14,ink)
		if mine and prize_ready:
			var pulse := .70+.30*sin(clock*3)
			_panel(bounds.grow(9),Color(accent,.035),Color("f6d87e",pulse),2)
			var notice := Rect2(Vector2(bounds.position.x-8,bounds.end.y+14),Vector2(bounds.size.x+16,45))
			_panel(notice,Color("312a17"),Color("f3cf75"),2)
			text(font,notice.position+Vector2(10,19),"领取 %d 张奖赏" % prize_remaining,16,Color("ffe59c"))
			text(font,notice.position+Vector2(10,36),"点击上方发光卡牌 ↑",12,Color("e8d7ad"))
		for i in range(6):
			var occupied: bool = player.get("prize_slots",[])[i] if player.get("prize_slots",[]).size() == 6 else i < int(player.prizes)
			var rect := prize_rect(i,mine)
			if not occupied:
				_panel(rect,Color(0,0,0,.15),Color(muted,.13))
			elif mine and prize_ready:
				_panel(rect.grow(3),Color(accent,.04),Color("ffe09a"),2)
		var side := "my" if mine else "opp"
		for kind in ["deck","discard"]:
			var rect: Rect2 = world.side_zones.screen_rect(side,kind)
			var count := int(player.get(kind+"_count",0))
			var label := Rect2(Vector2(rect.position.x-2,rect.end.y+5),Vector2(rect.size.x+4,26))
			_panel(label,Color("101f2b"),accent.darkened(.4))
			var caption := "%s %d" % [{"deck":"牌库","discard":"弃牌"}[kind],count]
			var font_size := 14 if rect.size.x > 83 else 12
			var label_width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			text(font,label.position+Vector2((label.size.x-label_width)*.5,18),caption,font_size,ink)
			if kind == "discard":
				text(font,rect.position+Vector2((rect.size.x-56)*.5,-10),"你的区域" if mine else "对手区域",14,ink)
			if kind == "discard" and count == 0:
				text(font,rect.get_center()-Vector2(27,-4),"暂无弃牌",12,muted)
	for id: String in world.cards:
		var entry: Dictionary = world.cards[id]
		if entry.data.get("empty",true) and entry.node.visible:
			var rect: Rect2 = world.card_screen_rect(id)
			_panel(rect,Color(.01,.025,.04,.18),Color(accent,.15))
			var center := rect.get_center()
			text(font,center-Vector2(18,-4),"战斗位" if id.ends_with("active") else "备战",12,Color(muted,.48))
			for corner in [rect.position,rect.end]:
				var direction := 1 if corner == rect.position else -1
				draw_line(corner,corner+Vector2(14*direction,0),Color(accent,.4),2,true)
				draw_line(corner,corner+Vector2(0,14*direction),Color(accent,.4),2,true)

func text(font: Font, at: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string_outline(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color(0,0,0,.5))
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw_compact_zones(font: Font, ink: Color, accent: Color) -> void:
	var s: float = world.hud_scale
	var font_size := roundi(12*s)
	for mine in [false,true]:
		var player: Dictionary = frame.players[frame.view if mine else 1-frame.view]
		var prize_label := prize_counter_rect(mine)
		_panel(prize_label,Color("173e31"),accent.darkened(.4))
		text(font,prize_label.position+Vector2(8*s,15*s),str(player.prizes),font_size,ink)
		var side := "my" if mine else "opp"
		for kind: String in ["deck","discard"]:
			var rect: Rect2 = world.side_zones.screen_rect(side,kind)
			var count := int(player.get(kind+"_count",0))
			var caption := str(count)
			var label := pile_counter_rect(side,kind)
			_panel(label,Color("173e31"),accent.darkened(.4))
			var width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			text(font,label.position+Vector2((label.size.x-width)*.5,15*s),caption,font_size,ink)
			if kind == "discard" and count == 0:
				var title := "弃牌"
				var title_width := font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
				text(font,rect.get_center()+Vector2(-title_width*.5,5*s),title,font_size,ink)

func prize_counter_rect(mine: bool) -> Rect2:
	var s: float = world.hud_scale
	var bounds := prize_rect(0,mine).merge(prize_rect(5,mine))
	# Keep the badge inside the stack: the stadium occupies the gap between prizes.
	return Rect2(bounds.end-Vector2(25*s,20*s),Vector2(25*s,20*s))

func pile_counter_rect(side: String, kind: String) -> Rect2:
	var s: float = world.hud_scale
	var rect: Rect2 = world.side_zones.screen_rect(side,kind)
	return Rect2(Vector2(rect.get_center().x-14*s,rect.end.y+3*s),Vector2(28*s,20*s))
