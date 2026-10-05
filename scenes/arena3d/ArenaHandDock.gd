extends Control
## Decorative hand hardware sits behind the existing interactive cards.
var theme_id := "grove"
var count := 0
var motion_enabled := true
var clock := 0.0
var surface: ColorRect
var touch_mode := false
var ui_scale := 1.0
var last_style := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface = ColorRect.new()
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.show_behind_parent = true
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 base_color : source_color = vec4(.025,.06,.095,1);
uniform vec4 accent : source_color = vec4(.15,.58,.75,1);
uniform bool moving = true;
void fragment(){
  vec2 p=UV;
  float rib=step(.97,fract(p.x*100.0))*.03;
  float bevel=exp(-p.y*55.0)*.20+exp(-(1.0-p.y)*60.0)*.08;
  float inset=smoothstep(.03,.10,p.y)*(1.0-smoothstep(.88,.98,p.y));
  vec3 c=base_color.rgb*(.65+inset*.7)+vec3(bevel+rib);
  float edge=exp(-abs(p.y-.018)*250.0);
  float sweep=moving ? .5+.5*sin(p.x*9.0-TIME*.7) : .5;
  c+=accent.rgb*edge*(.4+.5*sweep);
  COLOR=vec4(c,1.0);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	surface.material = material
	add_child(surface)
	move_child(surface,0)

func _process(delta: float) -> void:
	position = Vector2.ZERO
	size = get_parent().size
	clock += delta
	var style_key := str([theme_id,count,motion_enabled,touch_mode,ui_scale,size])
	if last_style == style_key and not motion_enabled: return
	last_style = style_key
	var palette: Dictionary = preload("res://scenes/arena3d/ArenaTheme.gd").palette(theme_id)
	surface.material.set_shader_parameter("base_color",Color(palette.panel).darkened(.4))
	surface.material.set_shader_parameter("accent",Color(palette.accent))
	surface.material.set_shader_parameter("moving",motion_enabled)
	queue_redraw()

func _draw() -> void:
	var palette: Dictionary = preload("res://scenes/arena3d/ArenaTheme.gd").palette(theme_id)
	var accent := Color(palette.accent)
	var font := get_theme_default_font()
	if touch_mode:
		draw_string(font,Vector2(18,22)*ui_scale,"手牌 %d · 点选出牌 · 滑动浏览" % count,HORIZONTAL_ALIGNMENT_LEFT,size.x-36*ui_scale,roundi(12*ui_scale),Color(palette.ink))
		return
	draw_string(font,Vector2(24,22),"手牌  /  %02d" % count,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(palette.ink))
	draw_string(font,Vector2(size.x-275,22),"点击出牌   ·   拖至目标   ·   滚轮浏览",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(palette.muted))
	for x in [8.0,size.x-9]:
		draw_line(Vector2(x,35),Vector2(x,size.y-15),Color(accent,.45),2,true)
		for y in [37.0,size.y-18]:
			draw_circle(Vector2(x,y),3,Color("6b7f89"))
			draw_line(Vector2(x-1,y),Vector2(x+1,y),Color("111d26"),1)
