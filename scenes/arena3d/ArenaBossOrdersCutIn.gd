extends Control
## Character-led cut-in. The six poses are the existing, authored 2D animation.
## Everything is display-only and scoped to the arena viewport.
const SHEET_PATH := "res://assets/arena3d/supporters/boss-command-hd.png"
var sheet: Texture2D
const SOURCE_SHEET := "res://assets/textures/vfx/trainer_boss_orders/sheet-transparent.png"
const FONT := preload("res://assets/fonts/NotoSansSC-VF.ttf")
var world: Node3D
var hero: Sprite2D
var echo: Sprite2D
var age := 0.0
var strength := 0.0
var target := Vector2.ZERO
var target_radius := 65.0
var target_name := ""
var mine := true
var nameplate: Polygon2D
var title: Label
var signature: Label
var underline: Line2D

func _ready() -> void:
	sheet = load(SHEET_PATH.replace("/arena3d/", "/arena3d/portable/") if world != null and world.low_quality else SHEET_PATH)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	for is_echo: bool in [true,false]:
		var sprite := Sprite2D.new()
		sprite.texture = sheet
		sprite.hframes = 3
		sprite.vframes = 2
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)
		if is_echo: echo = sprite
		else: hero = sprite
	hero.set_meta("source_artwork",SOURCE_SHEET)
	nameplate = Polygon2D.new()
	add_child(nameplate)
	underline = Line2D.new()
	underline.antialiased = true
	add_child(underline)
	title = _label("老大的指令",Color("fff0d7"))
	signature = _label("板 木",Color("d9a3ad"))

func _label(text: String, color: Color) -> Label:
	var node := Label.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.text = text
	node.add_theme_font_override("font",FONT)
	node.add_theme_color_override("font_color",color)
	node.add_theme_color_override("font_outline_color",Color("0b0314"))
	node.add_theme_constant_override("outline_size",3)
	add_child(node)
	return node

func sample(time: float, lock_position: Vector2, radius: float) -> void:
	age = time
	target = lock_position
	target_radius = radius
	strength = smoothstep(.06,.24,age) * (1.0-smoothstep(1.68,2.28,age))
	var h := size.y
	var w := size.x
	var entrance := 1.0-pow(1.0-clampf((age-.08)/.28,0,1),3)
	var command := exp(-maxf(0,age-1.02)*15.0) if age>=1.02 else 0.0
	# A deliberate hold on the raised palm, then a hard cut to the pointing pose.
	var pose := 0
	if age>=.30: pose=3
	if age>=.48: pose=1
	if age>=1.02: pose=2
	if age>=1.28: pose=4
	if age>=1.78: pose=5
	var aspect := w/maxf(1,h)
	var body_scale := h*1.10/(sheet.get_height()/2.0) * (1.0+.16*(1-entrance)+.055*command)
	if aspect<1.1: body_scale *= .72
	hero.frame = pose
	hero.scale = Vector2.ONE*body_scale
	hero.position = Vector2(w*(.23 if aspect>=1.1 else .36)-w*.12*(1-entrance),h*.43)
	# The HD remaster has a higher bottom-row crop. Keep the suit's baseline steady.
	hero.offset = Vector2(0,48.0*sheet.get_height()/1024.0 if pose>=3 else 0)
	hero.position.x -= w*.10*smoothstep(1.78,2.28,age)
	hero.modulate = Color(1,1,1,strength)
	echo.frame = pose
	echo.offset = hero.offset
	echo.position = hero.position+Vector2(-h*.025,h*.008)
	echo.scale = hero.scale*1.05
	echo.modulate = Color(.53,.16,.96,strength*.42)
	var text_in := smoothstep(.24,.42,age)*strength
	var name_y := h*.82
	var title_width := minf(w*.48,h*.78)
	nameplate.polygon = PackedVector2Array([Vector2(0,name_y-h*.10),Vector2(title_width,name_y-h*.135),Vector2(title_width-h*.04,name_y+h*.028),Vector2(0,name_y+h*.055)])
	nameplate.color = Color(.045,.008,.025,text_in*.97)
	underline.points = PackedVector2Array([Vector2(w*.045,name_y+h*.023),Vector2(title_width-h*.05,name_y-h*.006)])
	underline.default_color = Color(1,.28,.26,text_in)
	underline.width = maxf(1,h/700.0*3)
	title.position = Vector2(w*.045,name_y-h*.089)
	title.add_theme_font_size_override("font_size",roundi(minf(h/700.0*50,(title_width-w*.065)/maxi(1,title.text.length()))))
	title.modulate.a = text_in
	signature.position = Vector2(w*.045,name_y+h*.032)
	signature.add_theme_font_size_override("font_size",roundi(h/700.0*17))
	signature.modulate.a = text_in
	queue_redraw()

func _ink(text: String, at: Vector2, pixels: int, color: Color, outline: int = 5) -> void:
	draw_string_outline(FONT,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,outline,Color(.025,.008,.05,color.a))
	draw_string(FONT,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)

func _draw() -> void:
	if size.x<=0 or size.y<=0:return
	var w := size.x
	var h := size.y
	var s := h/700.0
	var fade := 1.0-smoothstep(2.28,2.80,age)
	var dark := smoothstep(0,.22,age)*fade
	# The right side retains a readable arena and a real, selected target.
	draw_polygon(PackedVector2Array([Vector2.ZERO,Vector2(w,0),Vector2(w,h),Vector2(0,h)]),PackedColorArray([Color(.019,.009,.034,.87*dark),Color(.019,.009,.034,.29*dark),Color(.019,.009,.034,.29*dark),Color(.019,.009,.034,.87*dark)]))
	var band := smoothstep(0,.18,age)*fade
	draw_rect(Rect2(0,0,w,h*.070*band),Color(.006,.004,.012,.92))
	draw_rect(Rect2(0,h-h*.105*band,w,h*.105*band),Color(.006,.004,.012,.96))
	# Wide, slanted crimson light behind the portrait, not a card border.
	var slash := PackedVector2Array([Vector2(-w*.1,h*.29),Vector2(w*.58,h*.14),Vector2(w*.53,h*.72),Vector2(-w*.1,h*.91)])
	draw_colored_polygon(slash,Color(.38,.015,.054,strength*.42))
	for i: int in 17:
		var y := h*(.16+fposmod(i*.056+age*.19,.68))
		var left := -w*.2+fposmod(i*.121+age*.4,.58)*w
		var length := w*(.09+.10*fposmod(i*.37,1))
		draw_line(Vector2(left,y),Vector2(left+length,y-h*.044),Color(.84,.14,.29,strength*(.09+.06*(i%3))),maxf(1,s*(1+i%2)),true)
	# One short impact, followed by a much quieter hold so the gesture reads.
	var hit := exp(-maxf(0,age-1.02)*24.0) if age>=1.02 else 0.0
	if hit>.002:draw_rect(Rect2(Vector2.ZERO,size),Color(.8,.38,.22,hit*.22))
	var text_in := smoothstep(.24,.42,age)*strength
	var x := w*.045-w*.035*(1-text_in)
	_ink("支援者  /  %s" % ("你的指令" if mine else "对手的指令"),Vector2(x,h*.108),roundi(17*s),Color(.95,.72,.60,text_in),2)
	var lock := smoothstep(1.02,1.24,age)*(1-smoothstep(2.23,2.72,age))
	if lock>0:
		var radius := target_radius*(1.0+.85*(1-smoothstep(1.02,1.22,age)))
		for i: int in 4:
			var a := PI*.25+i*PI*.5
			draw_arc(target,radius,a-.24,a+.24,10,Color(1,.29,.20,lock),maxf(2,3*s),true)
			var direction := Vector2(cos(a),sin(a))
			draw_line(target+direction*radius*.88,target+direction*radius*1.15,Color(1,.83,.58,lock),maxf(1,2*s),true)
		var notice := "目标锁定" if age<1.78 else "强制换位"
		var at := target+Vector2(radius+10*s,-8*s)
		at.x=clampf(at.x,w*.53,w*.84)
		at.y=clampf(at.y,h*.2,h*.67)
		_ink(notice,at,roundi(22*s),Color(1,.77,.52,lock),3)
		if target_name!="":_ink(target_name,at+Vector2(0,27*s),roundi(16*s),Color(.96,.9,.86,lock),2)
