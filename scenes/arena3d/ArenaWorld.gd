extends Node3D
## Pure visual consumer: receives copied display data, never a GameState.

const COLORS := {"R": Color("ff633b"), "W": Color("36b9ff"), "G": Color("79e497"), "L": Color("ffe15a"), "P": Color("ce83ff"), "F": Color("ffa15c"), "D": Color("9462ec"), "M": Color("bedee7"), "N": Color("f5c66e"), "C": Color("e3f4ff")}
const ThemeScript := preload("res://scenes/arena3d/ArenaTheme.gd")
var theme_id := "grove"
var stage: Node3D
var environment: WorldEnvironment
var key: DirectionalLight3D
var camera: Camera3D
var cards: Dictionary = {}
var positions: Dictionary = {}
var texture_cache: Dictionary = {}
var fit_diagnostics: Array[Dictionary] = []
var hover_id := ""
var clock := 0.0
var effect_nodes: Array[Node3D] = []
var effect_tweens: Array[Tween] = []
var motion_enabled := true:
	set(value):
		motion_enabled = value
		if not value: clear_effects()
		if not value and stadium_surface != null: stadium_surface.finish_transition()
var cinematic := false
var camera_distance := 1.0
var impacts: Array[Dictionary] = []
var rings: Array[MeshInstance3D] = []
var sound_enabled := true
var sound_player: AudioStreamPlayer
var sound_cache: Dictionary = {}
var stage_meshes: Array[Dictionary] = []
var fitted_width := -1.0
var fitted_depth := -1.0
var side_x := 10.0
var card_poses: Dictionary = {}
var pose_tweens: Dictionary = {}
var motion_speed := 1.0
var dynamics: Node3D
var foliage_materials: Array[ShaderMaterial] = []
var stadium_surface: Node
var side_zones: Node3D
var screen_size := Vector2.ZERO
var screen_origin := Vector2.ZERO
var compact_board := false
var portrait_board := false
var low_quality := false
var hud_scale := 1.0
var signature_vfx: Node3D
var signature_focus := 0.0
var signature_camera_offset := Vector2.ZERO
var signature_roll := 0.0
var supporter_vfx: Node3D
var supporter_focus := 0.0
var supporter_camera_offset := Vector2.ZERO
var supporter_canvas: Control
var render_dirty := true
var render_revision := 0
var hardware_signature := ""
var bench_counts := {"my":5,"opp":5}
var portrait_layout_key: Array = []

func invalidate_render() -> void:
	render_dirty = true

func display_size() -> Vector2:
	return screen_size if screen_size.x > 0 and screen_size.y > 0 else Vector2(get_viewport().size)

func project(at: Vector3) -> Vector2:
	return screen_origin + camera.unproject_position(at) * display_size() / Vector2(get_viewport().size)

func ray_origin(at: Vector2) -> Vector3:
	return camera.project_ray_origin((at-screen_origin) * Vector2(get_viewport().size) / display_size())

func ray_normal(at: Vector2) -> Vector3:
	return camera.project_ray_normal((at-screen_origin) * Vector2(get_viewport().size) / display_size())

func configure_quality(low: bool) -> void:
	var changed := low_quality != low
	low_quality = low
	invalidate_render()
	if key != null: key.shadow_enabled = not low
	if environment != null:
		var forward := RenderingServer.get_current_rendering_method() == "forward_plus"
		environment.environment.ssao_enabled = not low and forward
		environment.environment.glow_enabled = not low and forward
	if dynamics != null:
		for lamp in dynamics.lamps: lamp.shadow_enabled = not low
	if changed and is_node_ready():
		_configure_sky(environment.environment)
		set_theme(theme_id)
		remove_child(dynamics)
		dynamics.queue_free()
		_make_dynamics()

func _configure_sky(env: Environment) -> void:
	if low_quality:
		env.background_color = Color("244c3b")
		env.background_energy_multiplier = 1.0
		env.sky = null
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("dce9df")
		env.ambient_light_energy = .7
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		return
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = load("res://assets/arena3d/product-v3/studio_small_09.hdr")
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = .20

func _make_dynamics() -> void:
	dynamics = preload("res://scenes/arena3d/ArenaStageDynamics.gd").new()
	dynamics.world = self
	add_child(dynamics)

func _ready() -> void:
	motion_enabled = ThemeScript.option("motion")
	sound_enabled = ThemeScript.option("sound")
	environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0e1516")
	_configure_sky(env)
	if not low_quality: env.background_energy_multiplier = .45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = not low_quality and RenderingServer.get_current_rendering_method() == "forward_plus"
	env.ssao_radius = .9
	env.ssao_intensity = 2.1
	env.glow_enabled = env.ssao_enabled
	env.glow_intensity = .45
	env.glow_bloom = .05
	env.glow_hdr_threshold = 1.1
	environment.environment = env
	add_child(environment)
	key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-43, -32, 0)
	key.light_color = Color("fff4e3")
	key.light_energy = 1.15
	key.light_angular_distance = 4
	key.shadow_enabled = not low_quality
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-42, 135, 0)
	fill.light_color = Color("c8deef")
	fill.light_energy = .28
	add_child(fill)
	stadium_surface = preload("res://scenes/arena3d/ArenaStadiumSurface.gd").new()
	stadium_surface.world = self
	add_child(stadium_surface)
	set_theme(ThemeScript.current())
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.current = true
	_update_camera()
	sound_player = AudioStreamPlayer.new()
	sound_player.volume_db = -12
	sound_player.max_polyphony = 4
	add_child(sound_player)
	for prefix in ["my", "opp"]:
		for i in range(5):
			_make_card(prefix + "_bench_%d" % i, Vector3((i - 2) * 3.22, 0.44, 6.6 if prefix == "my" else -6.6))
		_make_card(prefix + "_active", Vector3(0, 0.44, 2.2 if prefix == "my" else -2.2))
	_make_dynamics()
	side_zones = preload("res://scenes/arena3d/ArenaSideZones.gd").new()
	side_zones.world = self
	add_child(side_zones)
	signature_vfx = preload("res://scenes/arena3d/ArenaSignatureVfx.gd").new()
	signature_vfx.world = self
	add_child(signature_vfx)
	supporter_vfx = preload("res://scenes/arena3d/ArenaSupporterVfx.gd").new()
	supporter_vfx.world = self
	add_child(supporter_vfx)
	if low_quality:
		add_child(preload("res://scenes/arena3d/ArenaPortableResources.gd").new())
		# The deterministic sound synthesis belongs to scene loading, never the
		# first committed attack frame. Keep the exact desktop waveforms.
		for sound: String in ["card","impact","evolve","charge"]: _prepare_sound(sound)

func set_theme(_id: String) -> void:
	invalidate_render()
	theme_id = ThemeScript.current()
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
	stage_meshes.clear()
	foliage_materials.clear()
	fitted_width = -1
	var scene: PackedScene = load("res://assets/arena3d/portable/grove_table.glb" if low_quality else "res://assets/arena3d/product-v6/grove_table.glb")
	if scene != null:
		stage = scene.instantiate()
		add_child(stage)
		_refine_materials(stage)
		_collect_table_meshes(stage)
		if stadium_surface != null: stadium_surface.bind(stage)
	if is_instance_valid(key): key.light_color = Color(ThemeScript.palette(theme_id).light)

func _refine_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var original: Material = node.get_active_material(i)
			# These meshes contain only the decorative fern fronds. Keep the
			# table, coins and balls, but remove foliage that overlaps live cards.
			if original != null and "fern" in original.resource_name.to_lower():
				node.hide()
				continue
			if original is StandardMaterial3D:
				var mat := original.duplicate() as StandardMaterial3D
				if "playing felt" in mat.resource_name:
					mat.albedo_color = Color("397552") if low_quality else Color("10251c")
					mat.roughness = .72
					mat.metallic = 0
					mat.normal_scale = .3
				elif "walnut" in mat.resource_name.to_lower():
					mat.albedo_color = Color("957457")
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				node.set_surface_override_material(i,mat)
				if "fern" in mat.resource_name.to_lower() and not low_quality:
					var leaf := ShaderMaterial.new()
					leaf.shader = preload("res://scenes/arena3d/FoliageWind.gdshader")
					leaf.set_shader_parameter("leaf_texture",mat.albedo_texture)
					leaf.set_shader_parameter("leaf_tint",Color("abc595"))
					node.set_surface_override_material(i,leaf)
					foliage_materials.append(leaf)
	for child in node.get_children(): _refine_materials(child)

func _collect_table_meshes(node: Node) -> void:
	if node is MeshInstance3D and node.visible: stage_meshes.append({"node":node,"source":node.mesh})
	for child in node.get_children(): _collect_table_meshes(child)

func _fit_table(width: float) -> void:
	var depth := 13.9 if cinematic else (portrait_field_depth() if compact_board and portrait_board else 19.8)
	if absf(width-fitted_width) < .05 and is_equal_approx(depth,fitted_depth): return
	fitted_width = width
	fitted_depth = depth
	var fit_started := Time.get_ticks_usec()
	var extension := (width-23.5)*.5
	for entry in stage_meshes:
		var mesh := ArrayMesh.new()
		var transform: Transform3D = entry.node.global_transform
		var inverse := transform.affine_inverse()
		var source: Mesh = entry.source
		for surface in range(source.get_surface_count()):
			var arrays := source.surface_get_arrays(surface).duplicate(true)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in range(vertices.size()):
				var point := transform * vertices[i]
				# Extend the straight rails and translate the side accessories;
				# preserve every rounded corner, coin and ball's physical shape.
				point.x += signf(point.x) * extension * smoothstep(0,6,absf(point.x))
				point.z += signf(point.z) * (depth-13.9)*.5 * smoothstep(0,5.5,absf(point.z))
				vertices[i] = inverse * point
			arrays[Mesh.ARRAY_VERTEX] = vertices
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			mesh.surface_set_material(surface,source.surface_get_material(surface))
		entry.node.mesh = mesh
	if get_tree().root.get_meta("performance_bench_offline",false):
		fit_diagnostics.append({"width":width,"depth":depth,"at_usec":fit_started,"ms":float(Time.get_ticks_usec()-fit_started)/1000.0})

func _update_camera() -> void:
	var visible_size := display_size()
	var aspect := visible_size.x / maxf(1,visible_size.y)
	var depth := 26.0 if compact_board and portrait_board else 18.0
	if compact_board and portrait_board and maxi(bench_counts.my,bench_counts.opp) > 5:
		# Four full card rows, both active cards and the side piles must also fit
		# on a short portrait tablet, not only on tall phones.
		depth = 34.0/1.04
	camera.size = maxf(18.5 if compact_board and portrait_board else 26.0, depth * aspect) * camera_distance
	if compact_board and portrait_board:
		var next_layout := [visible_size,camera.size,bench_counts.my,bench_counts.opp]
		if next_layout != portrait_layout_key:
			portrait_layout_key = next_layout
			for side: String in ["my","opp"]:
				var count: int = bench_counts[side]
				var columns := 4 if count > 5 else maxi(1,count)
				var rows := ceili(float(count)/columns)
				var outer := portrait_field_depth()*.5-4.0
				for i in range(count):
					var id := side+"_bench_%d" % i
					if positions.has(id): positions[id].z = (outer-(rows-1-floori(float(i)/columns))*4.6)*(1 if side == "my" else -1)
	side_x = clampf(camera.size*.36,11.9,16.0)
	if is_instance_valid(stage): _fit_table(23.5 if cinematic else camera.size+.25)
	camera.position = Vector3(0, 24, 11)
	if cinematic:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 44
		camera.position = Vector3(10 + sin(clock*.12)*.5,17,15)
		camera.look_at(Vector3(0,0,0))
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		var focus := maxf(signature_focus,supporter_focus)
		camera.position = camera.position.lerp(Vector3(0,16,22),focus)
		camera.look_at(Vector3(0,focus*1.0,0))
	camera.h_offset = supporter_camera_offset.x+signature_camera_offset.x
	camera.v_offset = supporter_camera_offset.y+signature_camera_offset.y
	camera.rotation.z+=signature_roll

func _card_outline(width: float, height: float, radius: float) -> Array[Vector3]:
	var outer: Array[Vector3] = []
	for corner in range(4):
		var angle := corner * PI * .5
		var center := Vector2((width*.5-radius) * (1 if corner in [0,3] else -1), (height*.5-radius) * (1 if corner in [0,1] else -1))
		var steps := 2 if low_quality else 8
		for step in range(steps+1):
			var a := angle + step * PI / (steps*2)
			outer.append(Vector3(center.x + cos(a)*radius,0,center.y + sin(a)*radius))
	return outer

func _rounded_mesh(width: float, height: float, radius: float, border: float = 0.0, uv_height: float = 1.0) -> ArrayMesh:
	var outer := _card_outline(width,height,radius)
	var inner := _card_outline(width-border*2,height-border*2,radius-border)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(outer.size()):
		var j := (i+1)%outer.size()
		var vertices := [Vector3.ZERO,outer[j],outer[i]] if border == 0 else [outer[i],inner[j],inner[i],outer[i],outer[j],inner[j]]
		for vertex: Vector3 in vertices:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(vertex.x/width+.5,(vertex.z/height+.5)*uv_height))
			surface.add_vertex(vertex)
	return surface.commit()

func _card_solid_mesh(width: float, height: float, thickness: float, radius: float, layers: int = 1) -> ArrayMesh:
	if low_quality: layers = 1
	var outline := _card_outline(width,height,radius)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(outline.size()):
		var a: Vector3 = outline[i]
		var b: Vector3 = outline[(i+1)%outline.size()]
		for sign_y in [-1.0,1.0]:
			var offset := Vector3(0,sign_y*thickness*.5,0)
			var cap := [Vector3.ZERO,b,a] if sign_y > 0 else [Vector3.ZERO,a,b]
			for point: Vector3 in cap:
				surface.set_normal(Vector3.UP*sign_y)
				surface.set_color(Color.WHITE)
				surface.add_vertex(point+offset)
		# Closed, continuous side walls; thin dark seams suggest stacked sleeves.
		# Every section shares the printed face's exact rounded outline.
		for layer in range(layers):
			for band in range(2):
				var lower := (-.5+(layer+(0.0 if band == 0 else .22))/layers)*thickness
				var upper := (-.5+(layer+(.22 if band == 0 else 1.0))/layers)*thickness
				var vertices := [a+Vector3(0,lower,0),b+Vector3(0,lower,0),b+Vector3(0,upper,0),a+Vector3(0,lower,0),b+Vector3(0,upper,0),a+Vector3(0,upper,0)]
				for point: Vector3 in vertices:
					surface.set_normal(Vector3(b.z-a.z,0,a.x-b.x).normalized())
					surface.set_color(Color(.45,.45,.45) if band == 0 else Color.WHITE)
					surface.add_vertex(point)
	return surface.commit()

func _card_body(width: float, height: float, thickness: float, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _card_solid_mesh(width,height,thickness,radius)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	return node

func _make_card(id: String, at: Vector3) -> void:
	positions[id] = at
	var root := Node3D.new()
	root.name = id
	root.position = at
	root.scale = Vector3.ONE * 2.2
	add_child(root)
	var is_bench := "_bench_" in id
	var body := _card_body(1.33,1.88,.10,.065,Color("25364a"))
	root.add_child(body)
	var face := MeshInstance3D.new()
	face.mesh = _rounded_mesh(1.33,1.88,.065)
	face.position.y = .051
	root.add_child(face)
	var name_label := Label3D.new()
	name_label.font_size = 28
	name_label.pixel_size = .006
	name_label.outline_size = 7
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.position = Vector3(0, .15, -1.11)
	name_label.modulate = Color("d4ecf8")
	root.add_child(name_label)
	name_label.visible = false
	var hp := Label3D.new()
	hp.font_size = 28
	hp.pixel_size = .006
	hp.outline_size = 8
	hp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp.position = Vector3(0,.10,1.13)
	root.add_child(hp)
	hp.visible = false
	var glow := _box(Vector3(1.48,.015,2.04) * root.scale.x, Color("9ba58e"))
	glow.mesh = _rounded_mesh(1.49,2.05,.11,.035)
	glow.scale = root.scale
	glow.position = Vector3(at.x,.242,at.z)
	var glow_mat := glow.material_override as StandardMaterial3D
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(glow)
	rings.append(glow)
	cards[id] = {"node": root, "face": face, "body": body, "label": name_label, "hp": hp, "glow": glow, "fingerprint": "", "data": {}}

func display(frame: Dictionary) -> void:
	var next_hardware := JSON.stringify([frame.get("players",[]),frame.get("view",0)])
	if next_hardware != hardware_signature:
		hardware_signature = next_hardware
		invalidate_render()
	stadium_surface.show_path(str(frame.get("stadium_background","")))
	if is_instance_valid(side_zones): side_zones.display(frame)
	if is_instance_valid(dynamics): dynamics.frame = frame
	var slot_data: Dictionary = frame.get("slots", {}).duplicate(true)
	if not frame.get("stadium_card",{}).is_empty(): slot_data["stadium"] = frame.stadium_card
	# Expanded bench effects are represented without truncation.
	for id: String in slot_data:
		if not cards.has(id):
			_make_card(id, Vector3(-5.4,.44,0) if id == "stadium" else Vector3(0,.44,6.6 if id.begins_with("my") else -6.6))
			# Stadium size is independent of the enlarged five-bench Pokemon cards.
			if id == "stadium": cards[id].node.scale = Vector3.ONE*2.2
	for prefix in ["my", "opp"]:
		var count := 0
		for id: String in slot_data:
			if id.begins_with(prefix + "_bench_"): count += 1
		bench_counts[prefix] = count
	var roomy := compact_board and portrait_board and maxi(bench_counts.my,bench_counts.opp) <= 5
	for prefix in ["my", "opp"]:
		var count: int = bench_counts[prefix]
		cards[prefix+"_active"].node.scale = Vector3.ONE*(2.75 if roomy else 2.2)
		positions[prefix+"_active"].z = (2.85 if roomy else 2.2)*(1 if prefix == "my" else -1)
		portrait_layout_key.clear()
		for i in range(count):
			var id: String = prefix + "_bench_%d" % i
			var portrait := compact_board and portrait_board
			var columns := 4 if portrait and count > 5 else count
			positions[id].x = ((i%columns) - (columns-1)*.5) * (3.6 if roomy else 3.22)
			positions[id].z = ((7.0+floori(i/float(columns))*4.1) if portrait else 6.6) * (1 if prefix == "my" else -1)
			cards[id].node.scale = Vector3.ONE * (2.55 if roomy else 2.2)
	for id: String in cards:
		var item: Dictionary = cards[id]
		if item.node.visible != slot_data.has(id): invalidate_render()
		item.node.visible = slot_data.has(id)
		item.glow.visible = false
		var data: Dictionary = slot_data.get(id, {"empty": true})
		var fingerprint := JSON.stringify(data)
		if fingerprint == item.fingerprint: continue
		invalidate_render()
		var old: Dictionary = item.data
		item.fingerprint = fingerprint
		item.data = data.duplicate(true)
		var empty: bool = data.get("empty", true)
		var concealed: bool = data.get("concealed", false)
		item.face.visible = not empty
		item.body.visible = not empty
		item.label.text = ("战斗区" if id.ends_with("active") else "备战区") if empty else ("未公开" if concealed else data.get("name", ""))
		item.label.modulate.a = .35 if empty else 1.0
		item.hp.text = "" if empty or concealed else "%d HP  ·  E %d%s%s" % [data.hp, data.energy.size(), "  ◆" if data.tool else "", "  ●" if not data.status.is_empty() else ""]
		if id == "stadium": item.hp.text = "场地"
		item.hp.modulate = Color("ff987d") if data.get("hp",1) < data.get("max_hp",0)*.4 else Color("95e5c6")
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(.73,.73,.73)
		mat.roughness = .34
		mat.metallic = .12
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Match the hand's full-resolution linear sampling. Mip blending erased
		# printed strokes even though the source image was high resolution.
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		if concealed: mat.albedo_texture = preload("res://scenes/arena3d/ArenaCardBacks.gd").for_side(id.begins_with("my"))
		var path: String = data.get("image", "")
		if path != "" and not concealed:
			if not texture_cache.has(path):
				var img := Image.new()
				var bytes := FileAccess.get_file_as_bytes(path)
				var error := ERR_FILE_UNRECOGNIZED
				if CardData.has_png_signature(bytes): error = img.load_png_from_buffer(bytes)
				elif CardData.has_jpg_signature(bytes): error = img.load_jpg_from_buffer(bytes)
				elif CardData.has_webp_signature(bytes): error = img.load_webp_from_buffer(bytes)
				if error == OK:
					texture_cache[path] = ImageTexture.create_from_image(img)
			if texture_cache.has(path): mat.albedo_texture = texture_cache[path]
		if mat.albedo_texture != null:
			# Printed artwork stays legible under colored arena lighting.
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		else:
			mat.albedo_color = Color("193f73") if concealed else COLORS.get(data.get("type","C"),Color("193f73")).darkened(.6)
		item.face.material_override = mat
		# State transition choreography is owned by ArenaMotionDirector. Updating
		# a texture never adds a second competing attack/placement effect here.

func hit_slot(point: Vector2) -> String:
	var origin := ray_origin(point)
	var direction := ray_normal(point)
	var best := ""
	var best_distance := INF
	for id: String in cards:
		if not cards[id].node.visible: continue
		var at: Vector3 = cards[id].node.position
		var hit: Variant = Plane(Vector3.UP, at.y).intersects_ray(origin,direction)
		if hit == null: continue
		var delta: Vector3 = hit - at
		var scale_factor: float = cards[id].node.scale.x
		if absf(delta.x) < .74 * scale_factor and absf(delta.z) < 1.02 * scale_factor:
			var distance: float = origin.distance_to(hit)
			if distance < best_distance:
				best = id
				best_distance = distance
	return best

func play_attack(from_my: bool, type: String) -> void:
	if not motion_enabled: return
	var from: Vector3 = positions["my_active" if from_my else "opp_active"] + Vector3(0,.3,0)
	var to: Vector3 = positions["opp_active" if from_my else "my_active"] + Vector3(0,.3,0)
	var color: Color = COLORS.get(type, Color("75dfff"))
	_play_sound(type)
	pulse(from,color,false)
	if type == "L":
		for lane in range(3):
			var points: Array[Vector3] = []
			for step in range(9):
				var point := from.lerp(to,step/8.0)
				point.x += sin(step*2.1+lane)*.38
				point.y += lane*.14
				points.append(point)
			for step in range(8):
				var beam := _box(Vector3(.045,.045,points[step].distance_to(points[step+1])),color,3)
				_add_effect(beam)
				beam.position = (points[step]+points[step+1])*.5
				beam.look_at(points[step+1])
				var fade := _effect_tween()
				fade.tween_interval(.12+lane*.045)
				fade.tween_property(beam,"scale",Vector3.ZERO,.18)
				fade.tween_callback(beam.queue_free)
	elif type in ["P","D","N"]:
		for i in range(4):
			var halo := _ring(.6+i*.18,.025,color)
			_add_effect(halo)
			halo.position = from
			halo.rotation_degrees.x = 65
			var tween := _effect_tween()
			tween.tween_property(halo,"position",to,.4+i*.035)
			tween.tween_property(halo,"scale",Vector3.ZERO,.22)
			tween.tween_callback(halo.queue_free)
	for i in range(12):
		var spark := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = .08 if type == "L" else .12
		mesh.height = mesh.radius * 2
		if type == "G": mesh.height = .45
		spark.mesh = mesh
		spark.material_override = _material(color,2.5)
		_add_effect(spark)
		spark.position = from + Vector3(sin(i*2.4)*.28,i*.02,cos(i*2.4)*.2)
		var tween := _effect_tween()
		tween.tween_interval(i*.022)
		tween.tween_property(spark,"position",to+Vector3(sin(i)*.38,0,cos(i)*.3),.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(spark.queue_free)
	var impact := _effect_tween()
	impact.tween_interval(.42)
	impact.tween_callback(func(): pulse(to,color,true))

func _add_effect(node: Node3D) -> void:
	add_child(node)
	effect_nodes.append(node)

func _effect_tween() -> Tween:
	var tween := create_tween()
	effect_tweens.append(tween)
	return tween

func clear_effects() -> void:
	invalidate_render()
	if is_instance_valid(signature_vfx): signature_vfx.clear()
	if is_instance_valid(supporter_vfx): supporter_vfx.clear()
	if is_instance_valid(dynamics): dynamics.clear()
	for tween: Tween in pose_tweens.values():
		if tween != null and tween.is_valid(): tween.kill()
	pose_tweens.clear()
	card_poses.clear()
	for tween in effect_tweens:
		if tween != null and tween.is_valid(): tween.kill()
	effect_tweens.clear()
	for node in effect_nodes:
		if is_instance_valid(node): node.queue_free()
	effect_nodes.clear()
	impacts.clear()
	if is_instance_valid(sound_player): sound_player.stop()

func play_zone_transfer(mine: bool, prize: bool) -> void:
	if not motion_enabled: return
	var card := _box(Vector3(.68,.035,.95),Color(ThemeScript.palette(theme_id).accent))
	_add_effect(card)
	card.position = Vector3(-8 if mine else 8,.6,2.8 if mine else -2.8)
	if prize: card.position.x *= -.8
	var tween := _effect_tween()
	tween.tween_property(card,"position",Vector3(0,.8,6.8 if mine else -6.8),.2)
	tween.tween_callback(card.queue_free)

func _play_sound(type: String) -> void:
	if not sound_enabled: return
	_prepare_sound(type)
	sound_player.stream = sound_cache[type]
	sound_player.play()

func _prepare_sound(type: String) -> void:
	if not sound_cache.has(type):
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var bytes := PackedByteArray()
		var sample_count := 4400 if type == "card" else 13230
		bytes.resize(sample_count*2)
		var rng := RandomNumberGenerator.new()
		rng.seed = 9176
		var filtered := 0.0
		for i in range(sample_count):
			var t := float(i)/22050
			var progress := float(i)/sample_count
			var noise := rng.randf_range(-1,1)
			filtered = lerpf(filtered,noise,.12)
			var wave := 0.0
			if type == "card":
				wave = noise * exp(-t*38)*.32 + filtered*sin(PI*progress)*.7
			elif type == "impact":
				wave = sin(TAU*(85*t-48*t*t))*exp(-t*9)*.7 + filtered*exp(-t*15)*1.2 + noise*exp(-t*90)*.24
			elif type == "evolve":
				wave = (sin(TAU*523*t)+sin(TAU*784*t)*.5)*sin(PI*progress)*.22 + filtered*.15*sin(PI*progress)
			else:
				wave = filtered*sin(PI*progress)*.8 + sin(TAU*(80*t+130*t*t))*sin(PI*progress)*.22
			bytes.encode_s16(i*2,int(clampf(wave,-1,1)*22000))
		wav.data = bytes
		sound_cache[type] = wav

func mark_targets(active: bool, eligible: Dictionary, selected: Array) -> void:
	for id: String in cards:
		var item: Dictionary = cards[id]
		if id == "stadium": positions[id].x = -6.1 if compact_board and portrait_board else -5.4
		var was_visible: bool = item.glow.visible
		item.glow.visible = active and eligible.has(id) and item.node.visible
		if item.glow.visible != was_visible: invalidate_render()
		item.glow.scale = item.node.scale
		item.glow.transparency = 0
		var mat: StandardMaterial3D = item.glow.material_override
		var color: Color = Color(ThemeScript.palette(theme_id).accent) if id in selected else Color(ThemeScript.palette(theme_id).hp)
		if item.glow.visible and mat.albedo_color != color: invalidate_render()
		mat.emission = color
		mat.albedo_color = color

func pulse(at: Vector3, color: Color, burst: bool) -> void:
	if not motion_enabled: return
	var ring := _ring(.4,.025,color)
	ring.position = at
	_add_effect(ring)
	impacts.append({"node": ring, "age": 0.0, "life": .7})
	if burst:
		for i in range(16):
			var shard := _box(Vector3(.04,.04,.3),color,2.0)
			shard.position = at
			_add_effect(shard)
			var angle := i * TAU/16
			var tween := _effect_tween().set_parallel(true)
			tween.tween_property(shard,"position",at + Vector3(cos(angle)*1.5,.45+sin(i)*.3,sin(angle)*1.5),.45)
			tween.tween_property(shard,"scale",Vector3.ZERO,.5)
			tween.chain().tween_callback(shard.queue_free)

func _process(delta: float) -> void:
	clock += delta if motion_enabled else 0.0
	for leaf in foliage_materials:
		leaf.set_shader_parameter("wind_time",clock)
	var previous_effect_count := effect_nodes.size()
	effect_nodes = effect_nodes.filter(func(node): return is_instance_valid(node))
	if effect_nodes.size() != previous_effect_count: invalidate_render()
	effect_tweens = effect_tweens.filter(func(tween): return tween != null and tween.is_valid())
	for id: String in pose_tweens.keys():
		if pose_tweens[id] == null or not pose_tweens[id].is_valid() or not pose_tweens[id].is_running():
			pose_tweens.erase(id)
	var old_camera := camera.transform
	var old_size := camera.size
	_update_camera()
	if camera.transform != old_camera or camera.size != old_size: invalidate_render()
	for id: String in cards:
		var node: Node3D = cards[id].node
		var target: Vector3 = positions[id]
		var pose: Dictionary = card_poses.get(id, {})
		target += pose.get("offset",Vector3.ZERO)
		var tilt: Vector3 = pose.get("tilt",Vector3.ZERO)
		if not node.position.is_equal_approx(target) or not node.rotation.is_equal_approx(tilt): invalidate_render()
		node.position = target if not pose.is_empty() else node.position.lerp(target,1-exp(-delta*12))
		node.rotation = node.rotation.lerp(tilt,1-exp(-delta*20))
		cards[id].glow.position = Vector3(target.x,.242,target.z)
	for i in range(impacts.size()-1,-1,-1):
		var impact: Dictionary = impacts[i]
		impact.age += delta
		var t: float = impact.age/impact.life
		impact.node.scale = Vector3.ONE*(1+t*5)
		impact.node.transparency = clampf(t,0,1)
		if t >= 1:
			impact.node.queue_free()
			impacts.remove_at(i)
	# The tabletop is static between public changes. Keep input/HUD and animation
	# processing at the display rate, but do not redraw an unchanged 3D framebuffer.
	if low_quality and not cinematic:
		var changing: bool = render_dirty or not effect_nodes.is_empty() or not pose_tweens.is_empty() or stadium_surface.progress < 1.0 or not signature_vfx.sequences.is_empty() or not supporter_vfx.active.is_empty()
		if get_viewport() is SubViewport:
			get_viewport().render_target_update_mode = SubViewport.UPDATE_ONCE if changing else SubViewport.UPDATE_DISABLED
		if changing: render_revision += 1
	else:
		if get_viewport() is SubViewport: get_viewport().render_target_update_mode = SubViewport.UPDATE_ALWAYS
		render_revision += 1
	render_dirty = false

func animate_card(id: String, kind: String, origin: Vector3 = Vector3.ZERO) -> void:
	if not motion_enabled or not cards.has(id): return
	if pose_tweens.has(id) and pose_tweens[id].is_valid(): pose_tweens[id].kill()
	var direction := -1.0 if id.begins_with("my") else 1.0
	var offset := Vector3(0,.65,0)
	var tilt := Vector3(-.16,0,.06)
	if kind == "arrive":
		offset = origin - positions[id] if origin != Vector3.ZERO else Vector3(0,1.5,11.0 * -direction)-positions[id]
		tilt = Vector3(-.35,.1,.08)
	elif kind == "damage":
		offset = Vector3(.16,.35,-direction * .4)
		tilt = Vector3(direction*.16,0,.12)
	elif kind == "evolve":
		offset = Vector3(0,1.5,0)
		tilt = Vector3(0,0,.13)
	var tween := create_tween().set_speed_scale(motion_speed)
	pose_tweens[id] = tween
	if kind == "attack":
		tween.tween_method(func(t: float): card_poses[id] = {"offset":Vector3(0,.85,-direction*.38)*t,"tilt":Vector3(direction*.19,0,0)*t},0.0,1.0,.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_method(func(t: float): card_poses[id] = {"offset":Vector3(0,.85,-direction*.38).lerp(Vector3(0,.45,direction*.7),t),"tilt":Vector3(direction*.19,0,0).lerp(Vector3(-direction*.12,0,0),t)},0.0,1.0,.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		offset = Vector3(0,.45,direction*.7)
		tilt = Vector3(-direction*.12,0,0)
	else:
		card_poses[id] = {"offset":offset,"tilt":tilt}
		if kind == "arrive":
			cards[id].node.position = positions[id]+offset
			cards[id].node.rotation = tilt
	tween.tween_method(func(t: float): card_poses[id] = {"offset":offset*(1-t)+Vector3(0,sin(t*PI)*1.2 if kind == "arrive" else 0.0,0),"tilt":tilt*(1-t)},0.0,1.0,.60 if kind == "arrive" else .38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): card_poses.erase(id))

func fly_card(texture: Texture2D, start: Vector3, finish: Vector3, duration: float, shrink: bool) -> void:
	if not motion_enabled: return
	var card := _card_body(1.33,1.88,.04,.065,Color("25364a"))
	_add_effect(card)
	card.set_meta("card_flight",true)
	card.position = start
	card.scale = Vector3.ONE*1.6
	var face := MeshInstance3D.new()
	face.mesh = _rounded_mesh(1.33,1.88,.065)
	face.position.y = .021
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.albedo_color = Color(.73,.73,.73)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	face.material_override = mat
	card.add_child(face)
	var tween := _effect_tween().set_speed_scale(motion_speed)
	tween.tween_method(func(t: float):
		card.position = start.lerp(finish,t)+Vector3(sin(t*PI)*.5,sin(t*PI)*3.2,0)
		card.rotation = Vector3(sin(t*PI)*-.55,0,sin(t*PI)*.20)
		card.scale = Vector3.ONE*lerpf(1.6,.6 if shrink else 1.9,t)
	,0.0,1.0,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(card.queue_free)

func card_screen_rect(id: String) -> Rect2:
	if not cards.has(id): return Rect2()
	var node: Node3D = cards[id].node
	var half := Vector3(.69,0,.97) * node.scale.x
	var start := project(node.position-half)
	var end := project(node.position+half)
	return Rect2(start,end-start).abs()

func prize_width() -> float:
	if compact_board: return 1.4 if portrait_board else 1.18
	return maxf(1.18,48.0*camera.size/maxf(1,display_size().x))

func portrait_field_depth() -> float:
	var visible_size := display_size()
	var width: float = camera.size if is_instance_valid(camera) else 18.5
	return maxf(26.0,width*visible_size.y/maxf(1,visible_size.x)*1.04)

func portrait_pile_z() -> float:
	if maxi(bench_counts.my,bench_counts.opp) > 5: return 3.4
	# Larger five-bench cards need a clear lane below each pile counter.
	return 3.6

func prize_position(index: int, mine: bool) -> Vector3:
	if compact_board and portrait_board:
		return Vector3(-6.7+index*.18,.68+index*.025,portrait_pile_z()*(1 if mine else -1))
	var width := prize_width()
	return Vector3(-camera.size*.5+2.2+(index%3)*(width+.40),.68,(1.6+floori(index/3.0)*(width*1.43+.43))*(1 if mine else -1))

func _material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .32
	mat.metallic = .45
	if glow > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

func _box(dimensions: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.material_override = _material(color,glow)
	return node

func _ring(radius: float, thickness: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius-thickness
	mesh.outer_radius = radius+thickness
	mesh.rings = 48
	mesh.ring_segments = 8
	node.mesh = mesh
	node.material_override = _material(color,1.8)
	return node
