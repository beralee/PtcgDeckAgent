extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1920,800)
	root.add_child(view)
	var world = load("res://scenes/arena3d/ArenaWorld.gd").new()
	view.add_child(world)
	var motion = load("res://scenes/arena3d/ArenaMotionDirector.gd").new()
	motion.world = world
	root.add_child(motion)
	await process_frame
	world.texture_cache["public-fixture"] = load("res://assets/ui/card_back_player.svg")
	var first := {"empty":false,"name":"Public fixture","uid":"same-printing","visual_id":"visible-instance-a","hp":100,"max_hp":100,"energy":[],"tool":false,"status":[],"image":"public-fixture"}
	var second := first.duplicate(true)
	second.visual_id = "visible-instance-b"
	var slots := {"my_active":first,"my_bench_0":second}
	for i in range(1,8): slots["my_bench_%d"%i] = {"empty":true}
	motion.present({"slots":slots})
	motion.present({"slots":dict_swapped(slots,first,second)})
	assert(world.card_poses.has("my_active") and world.card_poses.has("my_bench_0"),"Two identical printings must both animate when their public instances swap")
	motion.clear()
	slots = {"my_active":second,"my_bench_0":first}
	for i in range(1,8): slots["my_bench_%d"%i] = first.duplicate(true) if i == 7 else {"empty":true}
	slots.my_bench_7.visual_id = "visible-instance-c"
	motion.present({"slots":slots})
	motion.clear()
	var reduced := slots.duplicate(true)
	for i in range(5,8): reduced.erase("my_bench_%d"%i)
	motion.present({"slots":reduced})
	assert(world.effect_nodes.size() == 1,"A public card removed with an expanded slot must fly out once")
	assert(world.effect_nodes[0].has_meta("card_flight"))
	motion.clear()
	motion.present({"slots":reduced,"stadium_card":first})
	assert(world.card_poses.has("stadium"),"Playing a public stadium must animate its actual table card")
	motion.clear()
	var with_tool := reduced.duplicate(true)
	with_tool.my_active.tool = true
	with_tool.my_active.tool_image = "public-tool"
	motion.present({"slots":with_tool,"stadium_card":first})
	assert(world.effect_nodes.size() == 1,"Attaching a public tool produces a physical arrival")
	world.motion_enabled = false
	await process_frame
	assert(world.effect_nodes.is_empty() and world.card_poses.is_empty())
	print("ARENA_CARD_FLIGHTS_PASS: same-printing swap, removed expanded slot, stadium, tool, reduced-motion cleanup")
	motion.clear()
	motion.queue_free()
	view.queue_free()
	await process_frame
	quit()

func dict_swapped(slots: Dictionary, first: Dictionary, second: Dictionary) -> Dictionary:
	var result := slots.duplicate(true)
	result.my_active = second
	result.my_bench_0 = first
	return result
