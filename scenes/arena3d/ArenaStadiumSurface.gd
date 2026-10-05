extends Node
## Public art path only. Applies the existing stadium illustration to the authored felt.
var world: Node3D
var materials: Array[ShaderMaterial] = []
var path := ""
var current_texture: Texture2D
var previous_texture: Texture2D
var current_present := 0.0
var previous_present := 0.0
var progress := 1.0
var presence := 0.0
var accent := Color.WHITE
var from_accent := Color.WHITE
var to_accent := Color.WHITE
var color_cache: Dictionary = {}
var synced_width := -1.0

func bind(stage: Node) -> void:
	materials.clear()
	_bind_node(stage)
	_sync()

func _bind_node(node: Node) -> void:
	if node is MeshInstance3D:
		for index in range(node.mesh.get_surface_count()):
			var original: Material = node.get_active_material(index)
			if original is StandardMaterial3D and "playing felt" in original.resource_name:
				var surface := ShaderMaterial.new()
				surface.shader = preload("res://scenes/arena3d/PortableStadiumSurface.gdshader") if world.low_quality else preload("res://scenes/arena3d/StadiumSurface.gdshader")
				surface.set_shader_parameter("fabric",original.albedo_texture)
				surface.set_shader_parameter("fabric_tint",original.albedo_color)
				node.set_surface_override_material(index,surface)
				materials.append(surface)
	for child in node.get_children(): _bind_node(child)

func show_path(value: String) -> void:
	if value == path: return
	world.invalidate_render()
	var texture: Texture2D = load(value) as Texture2D if value != "" and ResourceLoader.exists(value) else null
	path = value if texture != null else ""
	previous_texture = current_texture
	previous_present = current_present
	current_texture = texture
	current_present = 1.0 if texture != null else 0.0
	from_accent = accent
	to_accent = _color(path,texture) if texture != null else Color.WHITE
	progress = 0.0 if world.motion_enabled else 1.0
	_sync()

func _color(key: String, texture: Texture2D) -> Color:
	if color_cache.has(key): return color_cache[key]
	var img := texture.get_image()
	if img == null or img.is_empty(): return Color.WHITE
	if img.is_compressed(): img.decompress()
	img.resize(32,18,Image.INTERPOLATE_BILINEAR)
	var sum := Vector3.ZERO
	var total := 0.0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x,y)
			var weight := c.s*c.v+.01
			sum += Vector3(c.r,c.g,c.b)*weight
			total += weight
	sum /= maxf(total,.001)
	var result := Color(sum.x,sum.y,sum.z)
	result = Color.from_hsv(result.h,clampf(result.s,.25,.75),.95)
	color_cache[key] = result
	return result

func _process(delta: float) -> void:
	if world.low_quality and progress >= 1.0 and synced_width == world.fitted_width: return
	progress = minf(1.0,progress+delta/.7) if world.motion_enabled else 1.0
	_sync()

func finish_transition() -> void:
	progress = 1.0
	_sync()

func _sync() -> void:
	synced_width = world.fitted_width
	var blend := smoothstep(0,1,progress)
	presence = lerpf(previous_present,current_present,blend)
	accent = from_accent.lerp(to_accent,blend)
	for mat in materials:
		mat.set_shader_parameter("previous_art",previous_texture)
		mat.set_shader_parameter("current_art",current_texture)
		mat.set_shader_parameter("previous_present",previous_present)
		mat.set_shader_parameter("current_present",current_present)
		mat.set_shader_parameter("transition",blend)
		mat.set_shader_parameter("table_size",Vector2(world.fitted_width-2.26,world.fitted_depth-2.04))
		if not world.low_quality: mat.set_shader_parameter("atmosphere_time",world.clock)
