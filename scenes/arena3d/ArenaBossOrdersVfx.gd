extends Node3D
## Reuses the 2D Giovanni poses, directing them against the selected public slot.
## It never moves game entities: MotionDirector releases the committed frame at RESOLVE.
const DURATION := 3.05
const RESOLVE := 1.78
const CutIn := preload("res://scenes/arena3d/ArenaBossOrdersCutIn.gd")
var world: Node3D
var cue: Dictionary
var hero: Sprite2D
var target_slot := ""
var destination_slot := ""
var cut_in: Control
var geometry: ImmediateMesh
var material: StandardMaterial3D
var light: OmniLight3D
var vertex_count := 0

func _ready() -> void:
	target_slot = str(cue.get("source_slot",""))
	destination_slot = str(cue.get("target_slot",""))
	cut_in = CutIn.new()
	cut_in.world = world
	cut_in.mine = bool(cue.get("mine",true))
	if world.cards.has(target_slot):cut_in.target_name = str(world.cards[target_slot].data.get("name",""))
	if is_instance_valid(world.supporter_canvas):
		world.supporter_canvas.add_child(cut_in)
	else:
		var layer := CanvasLayer.new()
		layer.layer = 12
		add_child(layer)
		layer.add_child(cut_in)
	hero = cut_in.hero
	geometry = ImmediateMesh.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = geometry
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	light = OmniLight3D.new()
	light.light_color = Color("e64563")
	light.omni_range = 9
	light.light_size = 2.3
	light.visible = not world.low_quality
	add_child(light)

func sample(age: float) -> void:
	var envelope := smoothstep(.06,.38,age)*(1-smoothstep(2.18,DURATION,age))
	world.supporter_focus = envelope*.88 if not world.compact_board else 0.0
	var punch := exp(-maxf(0,age-1.02)*19) if age>=1.02 else 0.0
	world.supporter_camera_offset = Vector2.ZERO if world.compact_board else Vector2(-2.6*envelope,0)+Vector2(sin(age*89),cos(age*71))*.11*punch
	# Use the same easing as the real card-arrival presentation after frame release.
	var travel := 1.0-pow(1.0-clampf((age-RESOLVE)/.60,0,1),3)
	var source: Vector3 = world.positions.get(target_slot,Vector3.ZERO)
	var finish: Vector3 = world.positions.get(destination_slot,source)
	var at := source.lerp(finish,travel)+Vector3(0,sin(travel*PI)*1.2+.08,0)
	light.position = at+Vector3(0,1.8,0)
	light.light_energy = envelope*(.35+1.2*punch)
	cut_in.size = world.display_size()
	cut_in.position = world.screen_origin if is_instance_valid(world.supporter_canvas) else Vector2.ZERO
	var screen: Vector2 = world.project(at)-world.screen_origin
	var edge: Vector2 = world.project(at+world.camera.global_basis.x*1.65)-world.screen_origin
	cut_in.sample(age,screen,maxf(22,screen.distance_to(edge)))
	geometry.clear_surfaces()
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
	vertex_count = 0
	var lock := smoothstep(.88,1.18,age)*(1-smoothstep(2.30,2.85,age))
	# Broad, tapered ribbons curl up from the actual selected card; no floating glyph showcase.
	for strand: int in 3:
		for segment: int in 42:
			var u := segment/42.0
			var v := (segment+1)/42.0
			var a := age*3.8+strand*TAU/3+u*TAU*.85
			var b := age*3.8+strand*TAU/3+v*TAU*.85
			var radius := 1.7*(1-u*.35)
			var radius_b := 1.7*(1-v*.35)
			var p := at+Vector3(cos(a)*radius,u*2.35,sin(a)*radius)
			var q := at+Vector3(cos(b)*radius_b,v*2.35,sin(b)*radius_b)
			var width := sin(u*PI)*.20*lock
			var next_width := sin(v*PI)*.20*lock
			var color := Color("bb63ff" if strand%2==0 else "ff604f")
			color.a = lock*sin(u*PI)*.88
			_triangle(p-Vector3.UP*width,q-Vector3.UP*next_width,q+Vector3.UP*next_width,color)
			_triangle(p-Vector3.UP*width,q+Vector3.UP*next_width,p+Vector3.UP*width,color)
	geometry.surface_end()

func _triangle(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	for point: Vector3 in [a,b,c]:
		geometry.surface_set_color(color)
		geometry.surface_add_vertex(point)
	vertex_count += 3

func clear() -> void:
	world.supporter_camera_offset = Vector2.ZERO
	if is_instance_valid(cut_in):
		cut_in.hide()
		cut_in.queue_free()

func _exit_tree() -> void:
	if is_instance_valid(cut_in):cut_in.queue_free()
