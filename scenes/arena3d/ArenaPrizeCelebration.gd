extends Control
## Cel-style ball opening, energy burst and reward-card fan, using public counts only.
const TITLES := ["击倒！奖赏入手", "双重突破！", "三奖连击！", "四奖大爆发！", "五奖超绝连击！", "六奖！冠军时刻"]
const COLORS := ["83eacb","69cbff","bd9aff","ffa65e","ffda62","fff1a2"]
const ENERGY := preload("res://scenes/battle/BattleCardView.gd").ENERGY_ICON_TEXTURES
const TYPES := ["G","W","P","R","L","F"]
const BACKS := preload("res://scenes/arena3d/ArenaCardBacks.gd")
var count := 1
var batch := 1
var mine := true
var duration := 2.0
var age := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 40

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	queue_redraw()

func _caption(text: String, at: Vector2, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var point := at-Vector2(width*.5,0)
	draw_string_outline(font,point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,5,Color("14232c",color.a))
	draw_string(font,point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _half_ball(at: Vector2, radius: float, top: bool, opacity: float) -> void:
	var points := PackedVector2Array([at])
	var start := PI if top else 0.0
	for i in 33: points.append(at+Vector2.from_angle(start+PI*i/32.0)*radius)
	draw_colored_polygon(points,Color("f44b45" if top else "ecf8ff",opacity))
	draw_arc(at,radius,start,start+PI,32,Color("182531",opacity),radius*.08,true)
	draw_line(at-Vector2(radius,0),at+Vector2(radius,0),Color("182531",opacity),radius*.13,true)
	if top:
		draw_arc(at,radius*.76,PI*1.15,PI*1.64,16,Color(1,1,1,opacity*.75),radius*.10,true)

func _star(at: Vector2, radius: float, color: Color) -> void:
	# Clean strokes avoid degenerate tiny polygon triangulation.
	draw_line(at-Vector2(radius,0),at+Vector2(radius,0),color,maxf(1,radius*.22),true)
	draw_line(at-Vector2(0,radius),at+Vector2(0,radius),color,maxf(1,radius*.22),true)

func _draw() -> void:
	var t := clampf(age/maxf(.01,duration),0,1)
	if t <= .001 or t >= .999: return
	var tier := clampi(count,1,6)
	var opacity := minf(t/.07,(1-t)/.13)
	var u := minf(size.x/430.0,size.y/540.0)
	var center := size*Vector2(.5,.44)
	var tint := Color(COLORS[tier-1],opacity)
	var charge := smoothstep(0,.22,t)
	var burst := smoothstep(.22,.48,t)
	var depart := smoothstep(.81,1,t)
	# Keep the arena visible behind the effect instead of an opaque rectangle.
	for layer in range(5,0,-1):
		draw_circle(center,(58+layer*19)*u,Color(.02,.08,.10,.075*opacity))
	if tier >= 4:
		for i in tier*2:
			var angle := i*TAU/(tier*2)+t*.16
			var axis := Vector2.from_angle(angle)
			var ray := PackedVector2Array([center+axis*32*u,center+axis.rotated(-.025)*(180+t*55)*u,center+axis.rotated(.025)*(180+t*55)*u])
			var hue := Color.from_hsv(float(i)/(tier*2),.6,1,opacity*.22) if tier == 6 else Color(tint,opacity*.16)
			draw_colored_polygon(ray,hue)
	# Attribute icons charge the ball then spiral outward.
	for i in tier:
		var angle := float(i)*TAU/tier-t*3.4
		var at := center+Vector2.from_angle(angle)*(65+burst*66)*u
		var icon: Texture2D = ENERGY.get(TYPES[i],ENERGY.ANY)
		var d := (18+burst*5)*u
		draw_circle(at,d*.64,Color(tint,opacity*.26))
		draw_texture_rect(icon,Rect2(at-Vector2.ONE*d*.5,Vector2.ONE*d),false,Color(1,1,1,opacity))
	if burst > 0:
		for ring in (2 if tier < 4 else 3):
			var r := (55+burst*(90+ring*18))*u
			draw_arc(center,r,0,TAU,48,Color(tint,(1-burst)*opacity*.7),maxf(1,(3-ring*.7)*u),true)
		for i in 12+tier*5:
			var angle := float(i)*TAU/(12+tier*5)+sin(float(i)*2.0)*.13
			var axis := Vector2.from_angle(angle)
			var at := center+axis*(44+burst*(95+fmod(float(i)*17,65)))*u
			var tail := (7+tier*2)*(1-burst*.65)*u
			draw_line(at-axis*tail,at,Color(tint,opacity*(1-burst*.5)),maxf(1,2*u),true)
			if i % 3 == 0: _star(at,(3+tier*.45)*u,Color(1,1,.8,opacity))
	# The red top and white lower shell spring apart around the luminous core.
	var radius := (24+charge*17)*(1-depart*.25)*u
	var separation := burst*45*u
	var ball_alpha := opacity*(1-depart)
	_half_ball(center-Vector2(0,separation),radius,true,ball_alpha)
	_half_ball(center+Vector2(0,separation),radius,false,ball_alpha)
	if burst < .2:
		draw_circle(center,radius*.24,Color("172630",ball_alpha))
		draw_circle(center,radius*.16,Color("fbffff",ball_alpha))
	else:
		draw_circle(center,(12+burst*15)*u,Color(1,1,.87,ball_alpha*(1-burst)*.85))
	# Only backs are shown; no hidden reward face enters presentation data.
	for i in tier:
		var progress := smoothstep(.32+i*.025,.64+i*.018,t)
		if progress <= 0: continue
		var fan := (float(i)-(tier-1)*.5)
		var destination := center+Vector2(fan*42,-10+absf(fan)*7)*u
		var at := center.lerp(destination,progress)
		at = at.lerp(Vector2(size.x*.18,size.y*(.80 if mine else .20)),depart)
		var rotation := fan*.095*progress+depart*.35
		var scale_value := lerpf(.2,1,progress)*(1-depart*.68)
		var dims := Vector2(45,64)*u*scale_value
		draw_set_transform(at,rotation)
		draw_rect(Rect2(-dims*.5-Vector2.ONE*3*u,dims+Vector2.ONE*6*u),Color(tint,opacity*.7),false,2*u)
		draw_texture_rect(BACKS.for_side(mine),Rect2(-dims*.5,dims),false,Color(1,1,1,opacity))
		draw_set_transform(Vector2.ZERO)
		_star(at+Vector2(dims.x*.5,-dims.y*.5),5*u,Color(1,1,.8,opacity*progress))
	if t > .38:
		var title_alpha := opacity*smoothstep(.38,.49,t)
		_caption(TITLES[tier-1],center+Vector2(0,109*u),roundi((23 if tier < 6 else 26)*u),Color(tint,title_alpha))
		var caption := "%s领取 %d 张奖赏卡" % ["请" if mine else "对手",batch]
		if tier != batch: caption += " · 本次累计 %d 奖" % tier
		_caption(caption,center+Vector2(0,132*u),roundi(13*u),Color(1,1,1,title_alpha))
