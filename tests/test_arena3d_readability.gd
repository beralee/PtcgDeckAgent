extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1920, 800)
	root.add_child(view)
	var world = load("res://scenes/arena3d/ArenaWorld.gd").new()
	view.add_child(world)
	await process_frame
	var slots := {}
	for side in ["my", "opp"]:
		for i in range(8): slots[side + "_bench_%d" % i] = {"empty": true}
	world.display({"slots": slots})
	await create_timer(.3).timeout
	var mesh: Mesh = world.cards.my_bench_0.face.mesh
	var bounds: Vector3 = mesh.get_aabb().size * world.cards.my_bench_0.node.scale
	var pixels: Vector2 = Vector2(bounds.x, bounds.z) * (1920.0 / world.camera.size)
	print("BENCH_READABILITY_PIXELS ", pixels)
	assert(pixels.x >= 130, "A full HD bench must retain at least 130 px card width")
	assert(pixels.y / pixels.x > 1.35, "Bench must show complete portrait card, not a cropped thumbnail")
	for id: String in slots:
		var center: Vector2 = world.camera.unproject_position(world.cards[id].node.position)
		assert(world.hit_slot(center) == id, "Every expanded bench slot remains individually clickable")
	print("ARENA_READABILITY_PASS")
	quit()
