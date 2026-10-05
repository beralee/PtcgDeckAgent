extends Control
## Opt-in model inspection shot. Same model and joint animation as live battles.
const Actor := preload("res://scenes/arena3d/ArenaPokemonActor.gd")
const Catalog := preload("res://scenes/arena3d/ArenaPokemonCatalog.gd")
var species := "dragapult"
var actor: Node3D
var camera: Camera3D
var elapsed := 0.0
var accent := Color("73e5df")
var sound_started := false
var autoplay := true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var entry: Dictionary = Catalog.ENTRIES[species]
	accent = Color(entry.color)
	var bg := ColorRect.new()
	bg.color = Color("080d18")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.anchor_left = .28
	container.stretch = true
	add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1382,1080)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("080d18")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8dff5")
	env.ambient_light_energy = .65
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("26354c")
	sky_mat.sky_horizon_color = Color("748392")
	sky_mat.ground_bottom_color = Color("18212e")
	sky_mat.ground_horizon_color = Color("748392")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = .32
	env.background_energy_multiplier = .35
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.environment = env
	stage.add_child(environment)
	_directional(stage,Vector3(-35,-30,0),Color("fff0dc"),.72,true)
	_directional(stage,Vector3(-25,145,0),accent,.32,false)
	_directional(stage,Vector3(-15,40,0),Color("9abcf3"),.20,false)
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 3.1
	floor_mesh.bottom_radius = 3.25
	floor_mesh.height = .24
	floor_mesh.radial_segments = 96
	var podium := MeshInstance3D.new()
	podium.mesh = floor_mesh
	podium.position.y = -.18
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("263246")
	material.metallic = .12
	material.roughness = .6
	podium.material_override = material
	stage.add_child(podium)
	for radius: float in [2.82,3.07]:
		var ring := MeshInstance3D.new()
		var shape := TorusMesh.new()
		shape.inner_radius = radius
		shape.outer_radius = radius+.014
		shape.rings = 96
		shape.ring_segments = 6
		ring.mesh = shape
		ring.position.y = -.047
		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = accent
		ring_mat.emission_enabled = true
		ring_mat.emission = accent
		ring_mat.emission_energy_multiplier = .6
		ring.material_override = ring_mat
		stage.add_child(ring)
	actor = Actor.new()
	stage.add_child(actor)
	actor.build(species)
	actor.target_local=Vector3(0,.24,2.8)
	if species == "munkidori": actor.scale = Vector3.ONE*1.10
	if species == "budew": actor.scale = Vector3.ONE*1.22
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(4.6,4.4,10.7)
	camera.fov = 32
	camera.look_at(Vector3(0,1.85,0))
	camera.current = true
	_label("PTCG DOJO",Vector2(.044,.082),22,Color("e5e9f0"))
	_label("CHARACTER STUDY  /  2026",Vector2(.044,.135),15,accent)
	_label(str(entry.name),Vector2(.044,.37),31 if str(entry.name).length()>9 else 38,Color("f4f3ef"))
	_label(str(entry.en),Vector2(.044,.44),20,accent)
	_label("专属动作与光影演出",Vector2(.044,.54),23,Color("c6cbd7"))
	_label(str(entry.detail).replace(" · ","\n"),Vector2(.044,.605),19,Color("a2acc0"))
	_label("角色展示 · 动作慢放",Vector2(.044,.865),17,Color("b3bece"))
	_label("WINDOWS  /  v0.6.2",Vector2(.044,.912),15,accent)

func _label(text: String, at: Vector2, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.anchor_left = at.x
	label.anchor_top = at.y
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	add_child(label)

func _lamp(stage: Node3D, at: Vector3, color: Color, power: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = power
	light.omni_range = 20
	light.shadow_enabled = true
	light.light_size = 2.0
	stage.add_child(light)

func _directional(stage: Node3D, angle: Vector3, color: Color, power: float, shadows: bool) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = angle
	light.light_color = color
	light.light_energy = power
	light.shadow_enabled = shadows
	light.directional_shadow_max_distance = 30
	light.light_angular_distance = 3
	stage.add_child(light)

func _process(delta: float) -> void:
	elapsed += delta
	if actor == null: return
	# Show the front, one full side and the back, then return to the face.
	actor.rotation.y = lerpf(-.08+sin(minf(elapsed,4.0)*.77)*1.6,-.22,smoothstep(3.2,4.0,elapsed))
	actor.position.y = .12 + sin(elapsed*1.9)*.07 if species == "dragapult" else .04
	var playing := autoplay and elapsed>=4.0 and elapsed<7.4
	if playing and not sound_started:
		actor.play_sound(.60)
		sound_started = true
	actor.pose((elapsed-4.0)*.60 if playing else elapsed,playing)
