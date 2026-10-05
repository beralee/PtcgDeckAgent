extends TestBase

const Presentation := preload("res://scripts/ui/battle/BattlePresentation.gd")

func test_portrait_prizes_overlap_in_one_stack_instead_of_six_cells() -> String:
	var world = preload("res://scenes/arena3d/ArenaWorld.gd").new()
	world.compact_board = true
	world.portrait_board = true
	world.screen_size = Vector2(1080,1992)
	var checks: Array[String] = []
	for mine in [false,true]:
		var first: Vector3 = world.prize_position(0,mine)
		var last: Vector3 = world.prize_position(5,mine)
		checks.append(assert_true(is_equal_approx(first.z,last.z),"Portrait prizes occupy a single overlapping row"))
		checks.append(assert_true(absf(first.x-last.x) < world.prize_width(),"All six prize backs overlap within the compact pile"))
	world.free()
	return run_checks(checks)

func test_3d_entry_supports_portable_targets_in_both_orientations() -> String:
	var old_profile := GameManager.ui_runtime_profile
	var old_enabled := GameManager.battle_3d_enabled
	var old_layout := GameManager.battle_layout_mode
	GameManager.battle_3d_enabled = true
	var checks: Array[String] = []
	for host in ["native", "web"]:
		for os_name in ["windows", "linux", "macos", "android", "ios", "unknown"]:
			for layout in [GameManager.BATTLE_LAYOUT_LANDSCAPE, GameManager.BATTLE_LAYOUT_PORTRAIT]:
				GameManager.ui_runtime_profile = UiRuntimeProfile.new({"host_kind":host,"native_os":os_name,"mobile_like":os_name in ["android","ios"],"pointer_mode":"touch"})
				GameManager.battle_layout_mode = layout
				checks.append(assert_eq(Presentation.requested_3d(), host == "web" or os_name in ["windows","android","macos"], "Supported 3D target: %s/%s/%s" % [host,os_name,layout]))
	GameManager.ui_runtime_profile = old_profile
	GameManager.battle_3d_enabled = old_enabled
	GameManager.battle_layout_mode = old_layout
	return run_checks(checks)

func test_other_platforms_keep_only_classic_fields_and_reject_saved_3d() -> String:
	var old_profile := GameManager.ui_runtime_profile
	var setup: Control = load("res://scenes/battle_setup/BattleSetup.tscn").instantiate()
	var checks: Array[String] = []
	for values: Dictionary in [
		{"host_kind":"native", "native_os":"ios", "mobile_like":true},
		{"host_kind":"native", "native_os":"linux"},
	]:
		GameManager.ui_runtime_profile = UiRuntimeProfile.new(values)
		var paths: Array = setup.call("_list_available_background_paths")
		checks.append(assert_eq(paths, ["res://assets/ui/background.png", "res://assets/ui/background1.png", "res://assets/ui/background2.png", "res://assets/ui/background3.png", "res://assets/ui/background4.png"], "Other platforms keep the original field order"))
		setup.set("_battle_backgrounds", paths)
		checks.append(assert_eq(setup.call("_available_background_or_default", "res://assets/arena3d/previews/grove.png"), "res://assets/ui/background.png", "An inherited Windows field falls back to a classic background"))
		checks.append(assert_false(setup.call("_select_background_path", "res://assets/arena3d/previews/league.png"), "An unavailable 3D field cannot be selected"))
	setup.free()
	GameManager.ui_runtime_profile = old_profile
	return run_checks(checks)

func test_portable_budget_cannot_inherit_desktop_high_quality() -> String:
	var platform := preload("res://scenes/arena3d/ArenaPlatform.gd")
	var checks: Array[String] = []
	for values: Dictionary in [{"native_os":"android"},{"native_os":"macos"},{"host_kind":"web","native_os":"windows"}]:
		var metrics: Dictionary = platform.metrics(Vector2(900,1947),UiRuntimeProfile.new(values))
		checks.append(assert_true(metrics.low,"Portable target always uses the bounded path"))
		checks.append(assert_true(metrics.max_render_edge <= 960,"Portable render edge <= 960, independently of UI resolution"))
	return run_checks(checks)

func test_low_quality_world_avoids_heavy_stage_and_environment() -> String:
	var world = preload("res://scenes/arena3d/ArenaWorld.gd").new()
	world.configure_quality(true)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(390,844)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(viewport)
	viewport.add_child(world)
	await tree.process_frame
	var checks: Array[String] = [
		assert_eq(world.stage_meshes.size(),7,"Portable table retains the seven playable material groups without the decorative fern"),
		assert_true(world.environment.environment.sky == null,"No HDR sky allocation on portable path"),
		assert_false(world.key.shadow_enabled,"No shadow map on portable path"),
		assert_true(world.dynamics.particles == null,"No dormant GPU particles allocated on portable path"),
	]
	var expected_materials := ["Graphite powder coat.001", "Ivory ceramic.001", "Forest leather", "Oiled black walnut.001", "Pale brass inlay", "Satin antique brass", "Jade woven playing felt"]
	var visible_materials: Array[String] = []
	for entry: Dictionary in world.stage_meshes:
		for surface: int in entry.source.get_surface_count():
			# The live felt uses the stadium shader; check its authored identity
			# separately from the runtime material that displays stadium artwork.
			visible_materials.append(entry.source.surface_get_material(surface).resource_name)
			checks.append(assert_not_null(entry.node.get_active_material(surface),"Every visible table surface has a live material"))
	visible_materials.sort()
	expected_materials.sort()
	checks.append(assert_eq(visible_materials,expected_materials,"The table, balls, rails and felt remain complete"))
	var fern_count := 0
	for mesh: MeshInstance3D in world.stage.find_children("*", "MeshInstance3D", true, false):
		for surface: int in mesh.mesh.get_surface_count():
			if "fern" in mesh.get_active_material(surface).resource_name.to_lower():
				fern_count += 1
				checks.append(assert_false(mesh.visible,"Decorative foliage stays hidden so it cannot cover live cards"))
	checks.append(assert_eq(fern_count,1,"The excluded material group is the authored fern, not missing table geometry"))
	viewport.queue_free()
	await tree.process_frame
	return run_checks(checks)

func test_ios_native_has_direct_modal_touch_dispatch() -> String:
	var profile := UiRuntimeProfile.new({"host_kind":"native","native_os":"ios","mobile_like":true,"pointer_mode":"touch"})
	var adapter := IosWebHudTouchAdapter.new()
	adapter.configure(profile,true)
	return assert_true(adapter.is_enabled(),"3D native iOS dialogs must not depend on delayed compatibility mouse events")

func test_portable_static_viewport_sleeps_and_public_change_wakes_it() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(390,844)
	tree.root.add_child(viewport)
	var world = preload("res://scenes/arena3d/ArenaWorld.gd").new()
	world.configure_quality(true)
	viewport.add_child(world)
	await tree.process_frame
	world.set_process(false)
	world._process(.016)
	world._process(.016)
	var checks: Array[String] = [assert_eq(viewport.render_target_update_mode,SubViewport.UPDATE_DISABLED,"An unchanged portable board does not spend a 3D render pass")]
	world.invalidate_render()
	world._process(.016)
	checks.append(assert_eq(viewport.render_target_update_mode,SubViewport.UPDATE_ONCE,"Visual changes wake the viewport without lowering input update rate"))
	var finished := world.create_tween()
	finished.tween_interval(.01)
	world.pose_tweens["finished"] = finished
	await finished.finished
	await tree.process_frame # Tween validity changes after its finished callbacks.
	world._process(.016)
	checks.append(assert_true(world.pose_tweens.is_empty(),"Completed card tweens cannot keep the viewport awake forever"))
	checks.append(assert_eq(viewport.render_target_update_mode,SubViewport.UPDATE_DISABLED,"Static caching resumes after animation"))
	world.display({"players":[],"view":0})
	world._process(.016)
	world.display({"players":[],"view":1})
	checks.append(assert_true(world.render_dirty,"Public pile/view changes invalidate cached physical hardware"))
	viewport.queue_free()
	await tree.process_frame
	return run_checks(checks)

func test_render_budget_preserves_aspect_and_narrow_canvas_fits_existing_dialogs() -> String:
	var platform := preload("res://scenes/arena3d/ArenaPlatform.gd")
	return run_checks([
		assert_eq(platform.render_size(Vector2(3840,2160),1280),Vector2i(1280,720),"Cap 3D pixels without stretching projection"),
		assert_eq(platform.canvas_size(Vector2i(390,844)),Vector2i(900,1947),"Portrait uses the existing dialog design width"),
		assert_eq(platform.canvas_size(Vector2i(1920,1080)),Vector2i(1920,1080),"Wide desktop remains at native UI resolution"),
	])
