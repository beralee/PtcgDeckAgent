extends TestBase
const Catalog := preload("res://scenes/arena3d/ArenaPokemonCatalog.gd")

class TransformProbe extends Node3D:
	var changes := 0
	func _ready() -> void:
		set_notify_transform(true)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSFORM_CHANGED: changes += 1

func test_stacked_prize_cradle_does_not_dirty_descendants_when_unchanged() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(390,844)
	tree.root.add_child(viewport)
	var world = preload("res://scenes/arena3d/ArenaWorld.gd").new()
	world.configure_quality(true)
	world.compact_board = true
	world.portrait_board = true
	viewport.add_child(world)
	world.set_process(false)
	world.motion_enabled = false
	world.dynamics.set_process(false)
	var probe := TransformProbe.new()
	world.dynamics.rewards[0].cradle.add_child(probe)
	world.dynamics._update_rewards(0)
	await tree.process_frame
	await tree.process_frame
	probe.changes = 0
	world.dynamics._update_rewards(0)
	await tree.process_frame
	await tree.process_frame
	var result := assert_eq(probe.changes,0,"A static stacked prize cradle must not enqueue child transform notifications")
	viewport.queue_free()
	await tree.process_frame
	return result

func test_portable_stage_vfx_keeps_effects_with_less_generated_geometry() -> String:
	var detailed = preload("res://scenes/arena3d/ArenaPokemonStageVfx.gd").new()
	var portable = preload("res://scenes/arena3d/ArenaPokemonStageVfx.gd").new()
	detailed.setup()
	portable.set("low_quality",true)
	portable.setup()
	var checks: Array[String] = []
	for id: String in ["dragapult","charizard","raging_bolt"]:
		var hit: float = preload("res://scenes/arena3d/ArenaPokemonDirection.gd").profile(id).hit
		for effect in [detailed,portable]: effect.sample_stage(id,hit+.05,Vector3.ZERO,Vector3(0,0,5),Vector3(0,1,0))
		checks.append(assert_true(portable.vertex_count > 0,id+" retains visible stage effects"))
		checks.append(assert_true(portable.vertex_count < detailed.vertex_count,id+" reduces tessellation without removing the effect"))
	detailed.free()
	portable.free()
	return run_checks(checks)

func test_portable_stage_reuses_mesh_within_sampling_tick() -> String:
	var effect = preload("res://scenes/arena3d/ArenaPokemonStageVfx.gd").new()
	effect.low_quality = true
	effect.setup()
	effect.sample_stage("dragapult",.901,Vector3.ZERO,Vector3(0,0,5),Vector3(0,1,0))
	var first: Mesh = effect.effect.mesh
	effect.sample_stage("dragapult",.905,Vector3.ZERO,Vector3(0,0,5),Vector3(0,1,0))
	var checks: Array[String] = [assert_eq(effect.effect.mesh,first,"Reuse procedural geometry within a portable sample tick")]
	effect.sample_stage("dragapult",.951,Vector3.ZERO,Vector3(0,0,5),Vector3(0,1,0))
	checks.append(assert_true(effect.effect.mesh != first,"Resample geometry as the shared choreography clock advances"))
	effect.free()
	return run_checks(checks)

func test_arena_refresh_keeps_legacy_anchor_identity_without_rebuilding_hidden_cards() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	scene.set_meta("arena3d_active",true)
	var anchor := BattleCardView.new()
	scene.get("_slot_card_views")["my_active"] = anchor
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(CardDatabase.get_card("CSV8C","159"),0))
	var display := preload("res://scripts/ui/battle/BattleDisplayController.gd").new()
	display.refresh_slot_card_view(scene,"my_active",slot,true)
	var checks: Array[String] = [assert_eq(anchor.card_instance,slot.get_top_card(),"Shared anchor retains the current public card"),
		assert_null(anchor.get("_texture_rect"),"An invisible legacy field card must not decode art or allocate UI")]
	display.refresh_slot_card_view(scene,"my_active",null,true)
	checks.append(assert_null(anchor.card_instance,"Cleared slots cannot retain stale identity"))
	anchor.free()
	scene.free()
	return run_checks(checks)

func test_legacy_portrait_hud_cannot_reappear_over_arena_after_refresh() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	scene.set_meta("arena3d_active",true)
	var hud: Control = scene.call("_ensure_portrait_edge_hud_overlay")
	var checks: Array[String] = [assert_false(hud.visible,"Legacy 2D HUD is hidden when first created for a 3D battle")]
	hud.hide()
	scene.call("_ensure_portrait_edge_hud_overlay")
	checks.append(assert_false(hud.visible,"Public refresh cannot re-show legacy 2D HUD over 3D cards"))
	scene.free()
	return run_checks(checks)

func test_portable_assets_retain_every_desktop_character_and_table_component() -> String:
	var checks: Array[String] = []
	for id: String in Catalog.ENTRIES:
		checks.append(assert_true(ResourceLoader.exists("res://assets/arena3d/portable/pokemon/%s.glb" % id),"Portable model retains " + id))
	checks.append(assert_true(ResourceLoader.exists("res://assets/arena3d/portable/grove_table.glb"),"The authored table has a portable mesh, not a substitute box"))
	checks.append(assert_true(ResourceLoader.exists("res://assets/arena3d/portable/reward_cradle.glb"),"Physical prize cradles remain present"))
	return run_checks(checks)

func test_legacy_stadium_card_cannot_overlay_arena_controls() -> String:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	scene.set_meta("arena3d_active",true)
	var coordinator := BattleStadiumHudCoordinator.new()
	coordinator.setup(scene)
	var stale := BattleCardView.new()
	scene.add_child(stale)
	scene.set("_stadium_card_view",stale)
	stale.show()
	var gs := GameState.new()
	gs.stadium_card = CardInstance.create(CardDatabase.get_card("CSV9C","207"),0)
	coordinator.refresh_stadium_card_hud(gs,0,true)
	var checks: Array[String] = [assert_false(stale.visible,"Legacy stadium artwork cannot cover the 3D toolbar"),
		assert_null(stale.card_instance,"The arena owns stadium artwork without allocating a second legacy card")]
	scene.free()
	return run_checks(checks)

func test_every_portable_model_keeps_articulation_and_local_sound() -> String:
	var checks: Array[String] = []
	for id: String in Catalog.ENTRIES:
		var actor = preload("res://scenes/arena3d/ArenaPokemonActor.gd").new()
		actor.low_quality = true
		actor.build(id)
		for joint: String in Catalog.ENTRIES[id].joints:
			checks.append(assert_true(actor.joints.has(joint),id+" retains "+joint))
		actor.pose(.30)
		var original: Transform3D = actor.joints.Body.transform
		actor.pose(.82)
		checks.append(assert_false(actor.joints.Body.transform.is_equal_approx(original),id+" still animates"))
		actor.pose(.30)
		checks.append(assert_true(actor.joints.Body.transform.is_equal_approx(original),id+" resamples without drift"))
		checks.append(assert_not_null(actor.audio.stream,id+" retains sound"))
		actor.free()
	return run_checks(checks)

func test_portable_motion_routes_character_attacks_and_abilities() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var view := SubViewport.new()
	view.size = Vector2i(390,844)
	tree.root.add_child(view)
	var world = preload("res://scenes/arena3d/ArenaWorld.gd").new()
	world.configure_quality(true)
	view.add_child(world)
	world.motion_enabled = true
	world.sound_enabled = false
	var motion = preload("res://scenes/arena3d/ArenaMotionDirector.gd").new()
	motion.world = world
	view.add_child(motion)
	var source := {"empty":false,"concealed":false,"name":"多龙巴鲁托ex","type":"P"}
	motion.shown = {"slots":{"my_active":source}}
	var targets: Array[String] = ["opp_active"]
	motion.start_attack(true,"P","幻影潜袭",targets,200)
	var checks: Array[String] = [assert_eq(world.signature_vfx.last_outcome.get("species"),"dragapult","Portable attacks retain the same 3D actor and direction")]
	motion.clear()
	var card := {"empty":false,"concealed":false,"name":"愿增猿"}
	checks.append(assert_true(motion.start_counter_transfer(card,"my_bench_0","my_active","opp_active",3,"肾上腺素脑"),"Portable committed abilities retain counter transfer choreography"))
	motion.clear()
	view.queue_free()
	await tree.process_frame
	return run_checks(checks)
