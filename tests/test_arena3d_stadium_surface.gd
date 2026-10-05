extends SceneTree

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1920,800)
	root.add_child(view)
	var world = load("res://scenes/arena3d/ArenaWorld.gd").new()
	view.add_child(world)
	await process_frame
	assert(world.theme_id == "grove","A fresh 3D board must use the retained grove field")
	var surface = world.stadium_surface
	assert(surface.materials.size() == 1,"Projection must use the authored playing felt")
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/stadium_backgrounds.json"))
	var paths := {}
	for path: String in map.by_card_id.values(): paths[path] = true
	world.motion_enabled = false
	for path: String in paths:
		world.display({"stadium_background":path})
		assert(surface.path == path and surface.presence == 1,"Every existing mapped illustration loads on the table")
		assert(surface.current_texture != null)
	world.motion_enabled = true
	world.display({"stadium_background":"res://assets/ui/stadium_backgrounds/area_zero_underdepths.webp"})
	await create_timer(.15).timeout
	assert(surface.progress > 0 and surface.progress < 1)
	world.set_theme("league")
	assert(world.theme_id == "grove" and surface.materials.size() == 1 and surface.current_texture != null,"A removed theme request falls back to grove and preserves the stadium")
	world.display({"stadium_background":"res://assets/ui/stadium_backgrounds/magma_basin.webp"})
	world.display({})
	world.motion_enabled = false
	await process_frame
	assert(surface.path == "" and surface.presence == 0 and surface.progress == 1,"Latest removal wins and disabling motion finishes the transition")
	world.display({"stadium_background":"res://assets/ui/stadium_backgrounds/missing.webp"})
	assert(surface.path == "" and surface.presence == 0,"Unknown art falls back to the original felt")
	print("ARENA_STADIUM_SURFACE_PASS: ",paths.size()," illustrations, shared felt, transition, retired-theme fallback, removal, reduced motion, missing art")
	view.queue_free()
	await process_frame
	quit()
