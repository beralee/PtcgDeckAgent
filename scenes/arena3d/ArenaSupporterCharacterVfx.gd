extends Node3D
## Character direction plus restrained lighting attached to public board locations.
const Profiles := preload("res://scenes/arena3d/ArenaSupporterCharacterCatalog.gd")
const Catalog := preload("res://scenes/arena3d/ArenaSupporterCatalog.gd")
const CutIn := preload("res://scenes/arena3d/ArenaSupporterCharacterCutIn.gd")
var world: Node3D
var cue: Dictionary
var character_id := ""
var profile: Dictionary
var hero: Sprite2D
var artwork: Texture2D
var cut_in: Control
var geometry: ImmediateMesh
var material: StandardMaterial3D
var light: OmniLight3D
var vertex_count := 0
var anchors: Array[String] = []

func _ready() -> void:
	profile = Profiles.profile(character_id)
	cut_in = CutIn.new()
	cut_in.profile = profile
	cut_in.spec = Catalog.ENTRIES[character_id]
	cut_in.character_id = character_id
	cut_in.artwork = artwork
	cut_in.mine = bool(cue.get("mine",true))
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
	light.light_color = Color(Catalog.ENTRIES[character_id].color)
	light.omni_range = 8
	light.light_size = 2
	light.visible = not world.low_quality
	add_child(light)
	if profile.effect == "energy":
		for slot: String in cue.get("energy_slots",[]):
			if world.positions.has(slot): anchors.append(slot)
	elif profile.effect == "return":
		var source := str(cue.get("source_slot",""))
		if world.positions.has(source):anchors.append(source)
	elif profile.effect == "boost":
		anchors.append(("my" if cue.get("mine",true) else "opp")+"_active")

func sample(age: float) -> void:
	var hit: float = profile.hit
	var resolve: float = profile.resolve
	var duration: float = profile.duration
	var envelope := smoothstep(.04,.35,age)*(1-smoothstep(resolve+.35,duration,age))
	world.supporter_focus = envelope*.84 if not world.compact_board else 0.0
	var punch := exp(-maxf(0,age-hit)*20) if age>=hit else 0.0
	var soft := character_id in ["lana","lillie","cipher","penny"]
	world.supporter_camera_offset = Vector2.ZERO if world.compact_board else Vector2(-2.35*envelope,0)+Vector2(sin(age*83),cos(age*67))*punch*(.025 if soft else .075)
	cut_in.size = world.display_size()
	cut_in.position = world.screen_origin if is_instance_valid(world.supporter_canvas) else Vector2.ZERO
	cut_in.sample(age)
	var prefix := "my" if cue.get("mine",true) else "opp"
	var at: Vector3 = world.positions.get(prefix+"_active",Vector3.ZERO)
	if not anchors.is_empty():at=world.positions.get(anchors[0],at)
	light.position = at+Vector3(0,2,0)
	light.light_energy = envelope*(.30+.65*punch)
	geometry.clear_surfaces()
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
	vertex_count = 0
	var power := smoothstep(hit-.12,hit+.30,age)*(1-smoothstep(resolve+.40,duration-.12,age))
	for slot: String in anchors:
		var origin: Vector3 = world.positions[slot]+Vector3(0,.12,0)
		var rise := smoothstep(hit,resolve+.4,age)
		if profile.effect == "return":origin.y += rise*2.7
		_ribbons(origin,age,power,.9 if profile.effect=="energy" else 1.6,2.0 if profile.effect=="return" else 1.15)
	# A low, short board wash for hand/search effects carries the impact into 3D.
	# It never fabricates a chosen Pokemon or reveals a hidden card identity.
	if anchors.is_empty():
		var side := 1.0 if cue.get("mine",true) else -1.0
		for strand: int in 2:
			for i: int in 36:
				var u := i/36.0
				var v := (i+1)/36.0
				var y := .20+strand*.11
				var z := side*(6.3+strand*.35)
				var p := Vector3(-8+16*u,y,z-sin(u*PI)*.5)
				var q := Vector3(-8+16*v,y,z-sin(v*PI)*.5)
				var c := Color(Catalog.ENTRIES[character_id].color if strand==0 else Catalog.ENTRIES[character_id].accent)
				c.a = power*sin(u*PI)*.48
				_quad(p,q,Vector3.FORWARD*.045,c)
	geometry.surface_end()

func _ribbons(at: Vector3,age: float,power: float,radius: float,height: float) -> void:
	for strand: int in 2:
		for i: int in 36:
			var u := i/36.0
			var v := (i+1)/36.0
			var a := age*2.7+strand*PI+u*TAU*.85
			var b := age*2.7+strand*PI+v*TAU*.85
			var p := at+Vector3(cos(a)*radius,u*height,sin(a)*radius)
			var q := at+Vector3(cos(b)*radius,v*height,sin(b)*radius)
			var color := Color(Catalog.ENTRIES[character_id].color if strand==0 else Catalog.ENTRIES[character_id].accent)
			color.a = power*sin(u*PI)*.75
			_quad(p,q,Vector3.UP*sin(u*PI)*.11*power,color)

func _quad(p: Vector3,q: Vector3,width: Vector3,color: Color) -> void:
	for point: Vector3 in [p-width,q-width,q+width,p-width,q+width,p+width]:
		geometry.surface_set_color(color)
		geometry.surface_add_vertex(point)
	vertex_count += 6

func clear() -> void:
	world.supporter_camera_offset = Vector2.ZERO
	if is_instance_valid(cut_in):
		cut_in.hide()
		cut_in.queue_free()

func _exit_tree() -> void:
	if is_instance_valid(cut_in):cut_in.queue_free()
