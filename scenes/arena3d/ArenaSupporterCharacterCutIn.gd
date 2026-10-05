extends Control
## Six bespoke character poses, framed with the same cinematic hierarchy as Giovanni.
const FONT := preload("res://assets/fonts/NotoSansSC-VF.ttf")
var spec: Dictionary
var profile: Dictionary
var character_id := ""
var mine := true
var hero: Sprite2D
var artwork: Texture2D
var echo: Sprite2D
var title: Label
var signature: Label
var nameplate: Polygon2D
var underline: Line2D
var age := 0.0
var strength := 0.0
var color: Color
var accent: Color

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	color = Color(spec.color)
	accent = Color(spec.accent)
	for shadow: bool in [true,false]:
		var sprite := Sprite2D.new()
		sprite.texture = artwork
		var feather := ShaderMaterial.new()
		feather.shader = preload("res://scenes/arena3d/supporter_character.gdshader")
		sprite.material = feather
		sprite.hframes = 3
		sprite.vframes = 2
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)
		if shadow: echo = sprite
		else: hero = sprite
	hero.set_meta("character_id",character_id)
	nameplate = Polygon2D.new()
	add_child(nameplate)
	underline = Line2D.new()
	underline.antialiased = true
	add_child(underline)
	title = _label(str(spec.name),Color("fff7ee"))
	signature = _label(str(profile.line),accent.lightened(.2))

func _label(value: String, ink: Color) -> Label:
	var node := Label.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.text = value
	node.add_theme_font_override("font",FONT)
	node.add_theme_color_override("font_color",ink)
	node.add_theme_color_override("font_outline_color",Color("080b1a"))
	node.add_theme_constant_override("outline_size",3)
	add_child(node)
	return node

func sample(time: float) -> void:
	age = time
	var hit: float = profile.hit
	var resolve: float = profile.resolve
	var duration: float = profile.duration
	var h := size.y
	var w := size.x
	var s := h/700.0
	var entrance := 1.0-pow(1.0-clampf((age-.06)/.32,0,1),3)
	var exit := smoothstep(resolve+.15,duration-.30,age)
	strength = smoothstep(.04,.23,age)*(1-exit)
	var impact := exp(-maxf(0,age-hit)*18) if age>=hit else 0.0
	var pose := 0
	if age>=.28:pose=1
	if age>=.56:pose=2
	if age>=hit:pose=3
	if age>=hit+.28:pose=4
	if age>=resolve:pose=5
	var aspect := w/maxf(1,h)
	var scale_factor := h*.90/(hero.texture.get_height()/2.0)*(1.0+.09*(1-entrance)+.035*impact)
	if aspect<1.1:scale_factor*=.72
	hero.frame = pose
	hero.scale = Vector2.ONE*scale_factor
	hero.position = Vector2(w*(.245 if aspect>=1.1 else .36)-w*.13*(1-entrance)-w*.08*exit,h*.46)
	hero.modulate = Color(1,1,1,strength)
	echo.frame = pose
	echo.position = hero.position+Vector2(-h*.018,h*.006)
	echo.scale = hero.scale*1.035
	echo.modulate = Color(color,strength*.28)
	var text_in := smoothstep(.23,.42,age)*strength
	var name_y := h*.83
	var title_width := minf(w*.49,h*.85)
	nameplate.polygon = PackedVector2Array([Vector2(0,name_y-h*.105),Vector2(title_width,name_y-h*.128),Vector2(title_width-h*.045,name_y+h*.033),Vector2(0,name_y+h*.052)])
	nameplate.color = Color(.017,.022,.05,text_in*.97)
	underline.points = PackedVector2Array([Vector2(w*.045,name_y+h*.027),Vector2(title_width-h*.04,name_y+h*.003)])
	underline.default_color = Color(color,text_in)
	underline.width = maxf(2,s*3)
	title.position = Vector2(w*.045,name_y-h*.085)
	var font_size := minf(50*s,(title_width-w*.06)/maxf(1,title.text.length()))
	title.add_theme_font_size_override("font_size",roundi(font_size))
	title.modulate.a = text_in
	signature.position = Vector2(w*.045,name_y+h*.038)
	signature.add_theme_font_size_override("font_size",roundi(18*s))
	signature.modulate.a = text_in
	queue_redraw()

func _ink(value: String, at: Vector2, pixels: int, ink: Color) -> void:
	draw_string_outline(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,3,Color(.018,.025,.05,ink.a))
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,ink)

func _draw() -> void:
	if size.x<=0 or size.y<=0:return
	var w := size.x
	var h := size.y
	var s := h/700.0
	var fade := 1-smoothstep(float(profile.duration)-.6,float(profile.duration)-.12,age)
	var dark := smoothstep(0,.22,age)*fade
	draw_polygon(PackedVector2Array([Vector2.ZERO,Vector2(w,0),Vector2(w,h),Vector2(0,h)]),PackedColorArray([Color(.011,.018,.035,.88*dark),Color(.011,.018,.035,.27*dark),Color(.011,.018,.035,.27*dark),Color(.011,.018,.035,.88*dark)]))
	var band := smoothstep(0,.18,age)*fade
	draw_rect(Rect2(0,0,w,h*.07*band),Color(.004,.007,.015,.94))
	draw_rect(Rect2(0,h-h*.105*band,w,h*.105*band),Color(.004,.007,.015,.97))
	var polygon := PackedVector2Array([Vector2(-w*.1,h*.24),Vector2(w*.56,h*.12),Vector2(w*.50,h*.75),Vector2(-w*.1,h*.91)])
	draw_colored_polygon(polygon,Color(color.darkened(.48),strength*.46))
	_backdrop(w,h,s)
	var impact := exp(-maxf(0,age-float(profile.hit))*24) if age>=float(profile.hit) else 0.0
	if impact>.003:draw_rect(Rect2(Vector2.ZERO,size),Color(accent,impact*.17))
	var text_in := smoothstep(.23,.42,age)*strength
	_ink("支援者  /  %s" % ("你的回合" if mine else "对手的回合"),Vector2(w*.045,h*.108),roundi(17*s),Color(accent,text_in))

func _backdrop(w: float,h: float,s: float) -> void:
	var style: String = profile.style
	# Broad cinematic lighting stays behind the portrait; the artwork owns the action.
	if style in ["broadcast","flame","primal","impact","fan","strata"]:
		for i: int in 13:
			var y := h*(.16+fposmod(i*.057+age*.12,.65))
			var x := -w*.22+fposmod(i*.137+age*.32,.52)*w
			var length := w*(.12+.10*fposmod(i*.37,1))
			var tilt := -.11 if style in ["impact","fan"] else -.035
			draw_line(Vector2(x,y),Vector2(x+length,y+h*tilt),Color(color if i%2==0 else accent,strength*(.09+.04*(i%3))),maxf(1,s*(2+i%3)),true)
	elif style in ["data","code","pixel","search","whistle"]:
		for i: int in 14:
			var x := w*(.035+fposmod(i*.127+age*.04,.44))
			var y := h*(.16+fposmod(i*.183-age*.13,.6))
			var length := h*(.015+.022*(i%3))
			draw_line(Vector2(x,y),Vector2(x+length*2,y),Color(accent,strength*.17),maxf(1,s*2),true)
			if style in ["code","pixel"]:draw_rect(Rect2(x,y-h*.013,length*.4,h*.008),Color(color,strength*.26))
	else:
		for i: int in 9:
			var center := Vector2(w*(.10+fposmod(i*.117,.39)),h*(.18+fposmod(i*.137-age*.06,.59)))
			var r := h*(.004+.004*(i%3))*(1+.25*sin(age*3+i))
			if style in ["stars","crystal"]:
				draw_colored_polygon(PackedVector2Array([center+Vector2(0,-r*2),center+Vector2(r,0),center+Vector2(0,r*2),center-Vector2(r,0)]),Color(accent,strength*.35))
			else:
				draw_arc(center,h*(.1+i*.011),.1+age*.3,1.8+age*.3,22,Color(color,strength*.11),maxf(1,s*2),true)
