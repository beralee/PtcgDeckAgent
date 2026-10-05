extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if not ok: failures.append(description)
func run() -> void:
	var view := SubViewport.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.size = Vector2i(1920,800)
	root.add_child(view)
	var world = load("res://scenes/arena3d/ArenaWorld.gd").new()
	view.add_child(world)
	await process_frame
	await RenderingServer.frame_post_draw
	world.set_process(false)
	world.side_zones.set_process(false)
	world.dynamics.set_process(false)
	for count in [0,1,2,8,60]:
		for perspective in [0,1]:
			var frame := {"view":perspective,"players":[{"deck_count":count},{"deck_count":count}],"slots":{}}
			world.display(frame)
			var mine: Dictionary = world.side_zones.piles.my_deck
			var opponent: Dictionary = world.side_zones.piles.opp_deck
			check(mine.face.material_override.albedo_texture != opponent.face.material_override.albedo_texture,"distinct backs at count %d / view %d" % [count,perspective])
			check(mine.face.visible == (count>0),"empty deck has no phantom card")
			var base_bounds: AABB = mine.tray.mesh.get_aabb()
			var print_bounds: AABB = mine.face.mesh.get_aabb()
			check(is_equal_approx(base_bounds.size.x,print_bounds.size.x) and is_equal_approx(base_bounds.size.z,print_bounds.size.z),"no oversized plate around the card back")
			check(mine.tray.material_override.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,"moving lights cannot whiten the base")
			var solids: Array[MeshInstance3D] = []
			for child in mine.node.get_children():
				if child is MeshInstance3D and child != mine.face and child != mine.tray and child.visible: solids.append(child)
			if count == 0:
				check(solids.is_empty(),"empty deck has no remaining white layers")
				continue
			var top := -INF
			for body in solids:
				var bounds: AABB = body.transform * body.mesh.get_aabb()
				top = maxf(top,bounds.end.y)
				var face_bounds: AABB = mine.face.transform * mine.face.mesh.get_aabb()
				check(absf(bounds.size.x-face_bounds.size.x)<.001 and absf(bounds.size.z-face_bounds.size.z)<.001,"printed back exactly matches card footprint")
				check(not body.mesh is BoxMesh,"card edges are rounded, not exposed square white corners")
				var material: StandardMaterial3D = body.material_override
				if material != null: check(material.albedo_color.get_luminance()<.22,"no bright white deck underside")
			check(not solids.is_empty() and absf(mine.face.position.y-top)<.003,"card back is flush with physical deck, not floating")
			check(solids.size()==1,"continuous deck edge with no gaps between white slabs")
	for reward: Dictionary in world.dynamics.rewards:
		var body: AABB = reward.card.mesh.get_aabb()
		var face: AABB = reward.face.mesh.get_aabb()
		check(is_equal_approx(body.size.x,face.size.x) and is_equal_approx(body.size.z,face.size.z),"prize back fits physical card")
		check(absf(reward.face.position.y-body.end.y)<.003,"prize back flush with body")
	var distinct: Dictionary = {}
	for reward: Dictionary in world.dynamics.rewards: distinct[reward.face.material_override.albedo_texture] = true
	check(distinct.size()==2,"prizes identify both players")
	view.queue_free()
	await process_frame
	if failures.is_empty(): print("ARENA_CARD_BACKS_PASS: matching footprints, flush rounded solids, no white slabs, counts 0/1/2/8/60, both perspectives, two prize backs")
	else:
		for failure in failures: print("FAIL: ",failure)
	# Let local material/texture references leave the coroutine before shutdown.
	call_deferred("_finish", 0 if failures.is_empty() else 1)

func _finish(code: int) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	quit(code)
