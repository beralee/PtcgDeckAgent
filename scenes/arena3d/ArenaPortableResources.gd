extends Node
## Retain small LOD resources for the battle lifetime. Background requests begin
## when the arena opens, before a player's first action; no hidden state is read.
var pending: Array[String] = []
var retained: Array[Resource] = []

func _ready() -> void:
	# Dummy rendering has no benefit from a GPU resource prefetch and its mesh
	# storage is not safe for these background uploads during rapid test teardown.
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	for id: String in preload("res://scenes/arena3d/ArenaPokemonCatalog.gd").ENTRIES:
		pending.append("res://assets/arena3d/portable/pokemon/%s.glb" % id)
		pending.append("res://assets/arena3d/portable/pokemon/audio/%s.ogg" % id)
	for path: String in pending:
		ResourceLoader.load_threaded_request(path)

func _process(_delta: float) -> void:
	for index in range(pending.size()-1,-1,-1):
		var status := ResourceLoader.load_threaded_get_status(pending[index])
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			retained.append(ResourceLoader.load_threaded_get(pending[index]))
			pending.remove_at(index)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_warning("Portable arena preload failed: " + pending[index])
			pending.remove_at(index)
	if pending.is_empty():
		set_process(false)
		_warm_render_variants()

func _warm_render_variants() -> void:
	# Resource IO alone doesn't create GLES pipelines. Render the actual palette,
	# alpha mesh, textured flame and billboard variants into an unshown 16px target
	# during entry, and retain their materials so later summons reuse those shaders.
	var warm := SubViewport.new()
	warm.name = "PortableShaderCache"
	warm.size = Vector2i(16,16)
	warm.own_world_3d = true
	warm.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(warm)
	var camera := Camera3D.new()
	warm.add_child(camera)
	camera.position = Vector3(0,4,12)
	camera.look_at(Vector3(0,1,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12
	camera.current = true
	var actors: Array[Node3D] = []
	for id: String in ["dragapult","charizard"]:
		var actor := preload("res://scenes/arena3d/ArenaPokemonActor.gd").new()
		actor.low_quality = true
		warm.add_child(actor)
		actor.build(id)
		actor.position.x = -2 if id == "dragapult" else 2
		actor.pose(.82)
		actors.append(actor)
	var stage := preload("res://scenes/arena3d/ArenaPokemonStageVfx.gd").new()
	stage.low_quality = true
	warm.add_child(stage)
	stage.setup()
	stage.sample_stage("dragapult",.9,Vector3.ZERO,Vector3(0,0,4),Vector3(0,1,0))
	var impact := Sprite3D.new()
	impact.texture = load("res://assets/textures/vfx/charizard_ex/mid_stream/impact_bloom_flipbook.png")
	impact.hframes = 4
	impact.pixel_size = .01
	impact.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	impact.shaded = false
	impact.render_priority = 4
	impact.position = Vector3(0,1,0)
	warm.add_child(impact)
	await RenderingServer.frame_post_draw
	if not is_inside_tree(): return
	for actor: Node3D in actors: actor.pose(.55)
	await RenderingServer.frame_post_draw
	if is_instance_valid(warm): warm.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _exit_tree() -> void:
	# Consume outstanding requests even when a player exits during scene loading.
	# Do not leave loader jobs retaining meshes after the world has been freed.
	for path: String in pending:
		if ResourceLoader.load_threaded_get_status(path) in [ResourceLoader.THREAD_LOAD_IN_PROGRESS,ResourceLoader.THREAD_LOAD_LOADED]:
			ResourceLoader.load_threaded_get(path)
	pending.clear()
