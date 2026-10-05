extends Control
## A real 3D card in a transparent viewport; receives only a visible texture.
signal inspect
const Platform := preload("res://scenes/arena3d/ArenaPlatform.gd")
var world: Node3D
var motion_enabled := true
var viewport: SubViewport
var pivot: Node3D
var face: MeshInstance3D
var art: Texture2D
var pointer := Vector2.ZERO
var tilt := Vector2.ZERO
var entry := 0.0
var render_rect: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Platform.msaa(not world.low_quality)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var camera := Camera3D.new()
	camera.position.z = 5.8
	camera.fov = 20
	camera.current = true
	viewport.add_child(camera)
	pivot = Node3D.new()
	pivot.rotation.x = PI*.5
	viewport.add_child(pivot)
	var body: MeshInstance3D = world._card_body(1.33,1.88,.025,.065,Color("1a2b38"))
	pivot.add_child(body)
	face = MeshInstance3D.new()
	face.mesh = world._rounded_mesh(1.33,1.88,.065)
	face.position.y = .0135
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	face.material_override = material
	pivot.add_child(face)
	render_rect = TextureRect.new()
	render_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	render_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	render_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	render_rect.texture = viewport.get_texture()
	add_child(render_rect)
	resized.connect(_resize)
	mouse_exited.connect(func(): pointer = Vector2.ZERO)
	_resize()
	if art != null: set_art(art)

func _resize() -> void:
	# Supersample the printed text; no mip chain blurs the large preview.
	viewport.size = Platform.render_size(size*(1.0 if world.low_quality else 1.5),Platform.LOW_RENDER_EDGE if world.low_quality else 2560)

func set_art(texture: Texture2D) -> void:
	if art == texture and face != null and face.material_override.albedo_texture == texture: return
	art = texture
	if face == null: return
	face.material_override.albedo_texture = texture
	pivot.visible = texture != null
	entry = 1.0 if motion_enabled else 0.0
	tilt = Vector2(.10,-.15) if motion_enabled else Vector2.ZERO

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer = (event.position / size - Vector2(.5,.5))*2.0
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		inspect.emit()
		accept_event()

func _process(delta: float) -> void:
	if viewport == null: return
	viewport.msaa_3d = Platform.msaa(not world.low_quality)
	var active := is_visible_in_tree() and art != null
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if not active: return
	entry = maxf(0,entry-delta*3.6) if motion_enabled else 0.0
	var target := Vector2(-pointer.y,pointer.x)*.045 if motion_enabled else Vector2.ZERO
	tilt = tilt.lerp(target,1-exp(-delta*13)) if motion_enabled else Vector2.ZERO
	pivot.rotation = Vector3(PI*.5+tilt.x,tilt.y,0)
	pivot.position.z = .12*sin(entry*PI)
