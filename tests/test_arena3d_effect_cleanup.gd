extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scenes/arena3d/ArenaWorld.gd").new()
	root.add_child(world)
	await process_frame
	world.play_attack(true,"L")
	assert(not world.effect_nodes.is_empty())
	world.motion_enabled = false
	await process_frame
	assert(world.effect_nodes.is_empty())
	assert(world.effect_tweens.is_empty())
	assert(world.impacts.is_empty())
	await create_timer(.8).timeout
	assert(world.effect_nodes.is_empty(), "Delayed impact must not reappear after reduced motion")
	world.motion_enabled = true
	world.play_zone_transfer(true,true)
	await create_timer(.4).timeout
	assert(world.effect_nodes.is_empty())
	print("ARENA_EFFECT_CLEANUP_PASS")
	world.queue_free()
	await process_frame
	quit()
