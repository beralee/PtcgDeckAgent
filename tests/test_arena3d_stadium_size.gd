extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var view := SubViewport.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size = Vector2i(1920,800)
	root.add_child(view)
	var world = load("res://scenes/arena3d/ArenaWorld.gd").new()
	view.add_child(world)
	await RenderingServer.frame_post_draw
	world.display({"slots":{},"stadium_card":{"empty":false,"concealed":false,"name":"场地","hp":0,"max_hp":0,"energy":[],"status":[],"tool":false}})
	var stadium_size: Vector3 = world.cards.stadium.face.mesh.get_aabb().size * world.cards.stadium.node.scale
	var active_size: Vector3 = world.cards.my_active.face.mesh.get_aabb().size * world.cards.my_active.node.scale
	var ok := stadium_size.is_equal_approx(active_size)
	print("ARENA_STADIUM_SIZE_", "PASS" if ok else "FAIL", " stadium=",stadium_size," active=",active_size)
	view.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	quit(0 if ok else 1)
