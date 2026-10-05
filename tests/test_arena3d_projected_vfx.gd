extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Control.new()
	host.position = Vector2(37,83)
	host.size = Vector2(1200,700)
	root.add_child(host)
	var view := SubViewport.new()
	view.size = Vector2i(1200,700)
	host.add_child(view)
	var world = load("res://scenes/arena3d/ArenaWorld.gd").new()
	view.add_child(world)
	var motion = load("res://scenes/arena3d/ArenaMotionDirector.gd").new()
	motion.world = world
	host.add_child(motion)
	await process_frame
	var ids: Array[String] = ["opp_active","opp_bench_3"]
	motion.start_attack(true,"L","公开位置回归",ids)
	var sequence: Control
	for child in motion.get_children():
		if child.has_meta("profile_id"): sequence = child
	assert(sequence != null)
	for i in range(ids.size()):
		var impact: Control = sequence.get_node("AttackVfxImpact%d" % i)
		var expected: Vector2 = motion.get_global_transform() * world.camera.unproject_position(world.positions[ids[i]])
		assert(impact.global_position.distance_to(expected) < 1,"3D impact must land on the projected card, including nonzero HUD offset")
	var texture: TextureRect = sequence.get_node("AttackVfxImpact0/ImpactBloomTexture")
	var atlas: AtlasTexture = texture.texture
	await create_timer(.10).timeout
	assert(atlas.region.position == Vector2.ZERO,"Flipbook must retain ignition frame before impact becomes visible")
	await create_timer(.36).timeout
	assert(atlas.region.position != Vector2.ZERO,"Flipbook advances after the impact starts")
	var second: AtlasTexture = sequence.get_node("AttackVfxImpact1/ImpactBloomTexture").texture
	assert(second.region.position != Vector2.ZERO,"Each target owns an independently advancing flipbook")
	motion.clear()
	await process_frame
	assert(motion.get_child_count() == 0 and not motion.is_busy())
	await create_timer(.9).timeout
	assert(motion.get_child_count() == 0,"Cancelled flipbook callbacks must not resurrect effects")
	print("ARENA_PROJECTED_VFX_PASS: multi-target centers, delayed flipbook and cancellation")
	host.queue_free()
	await process_frame
	quit()
