extends TestBase
const Signature := preload("res://scenes/arena3d/ArenaSignatureVfx.gd")
const Scenario := preload("res://scripts/tools/ArenaSignatureScenario.gd")

func test_expanded_roster_renders_and_cleans_up_committed_attacks() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var old := [GameManager.battle_3d_enabled,GameManager.current_mode,GameManager.battle_effects_enabled,GameManager.battle_layout_mode]
	var rig := Scenario.new()
	tree.root.add_child(rig)
	await rig.mount()
	var presenter := rig.battle.get_node("Arena3DPresenter")
	presenter.world.sound_enabled=false
	var signature = presenter.world.signature_vfx
	var catalog = preload("res://scenes/arena3d/ArenaPokemonCatalog.gd")
	var checks: Array[String] = []
	var targets: Array[String] = ["my_active"]
	var counters: Array[Dictionary] = []
	for id: String in catalog.ENTRIES:
		if id in ["munkidori","gardevoir"]:continue
		var card := {"empty":false,"concealed":false,"name":catalog.ENTRIES[id].aliases[0],"uid":"CSV9C_054" if id=="pikachu_tera" else id}
		checks.append(assert_true(signature.play_attack(card,"opp_active",targets,counters,1.8),"Committed public attack accepts "+id))
		if signature.sequences.is_empty():continue
		signature._process((float(signature.timing().hit)+.05)/1.8)
		checks.append(assert_eq(signature.sequences[0].actor.species,id,"The requested species owns the rendered action"))
		checks.append(assert_true(signature.sequences[0].stage_effect.vertex_count>0,id+" has a visible species effect at its own impact beat"))
		checks.append(assert_false(signature.sequences[0].actor.audio.playing,"Muted board keeps signature audio silent"))
		signature._process(4.0)
		for i: int in 2:await tree.process_frame
		checks.append(assert_eq(signature.get_child_count(),0,"No model, light or sound survives "+id))
	checks.append(assert_eq(presenter.world.signature_focus,0.0,"Collection restores the board camera"))
	await rig.close()
	rig.free()
	GameManager.battle_3d_enabled=old[0]
	GameManager.current_mode=old[1]
	GameManager.battle_effects_enabled=old[2]
	GameManager.battle_layout_mode=old[3]
	return run_checks(checks)

func test_signature_renderer_available_for_committed_3d_actions() -> String:
	return assert_true(ResourceLoader.exists("res://scenes/arena3d/ArenaSignatureVfx.gd"), "3D attacks need the shared Pokemon signature renderer")

func test_existing_motion_director_routes_ability_outcomes() -> String:
	var motion: Node = load("res://scenes/arena3d/ArenaMotionDirector.gd").new()
	var result := assert_true(motion.has_method("start_counter_transfer"), "Committed damage-counter transfers must use the 3D motion owner")
	motion.free()
	return result

func test_profiles_reuse_existing_special_animation_assets_and_hide_concealed_cards() -> String:
	var checks: Array[String] = []
	for name: String in ["多龙巴鲁托ex","喷火龙ex","愿增猿"]:
		var profile := Signature.profile({"empty":false,"concealed":false,"name":name})
		checks.append(assert_false(profile.is_empty(), "Existing special Pokemon is recognized: " + name))
		checks.append(assert_true(ResourceLoader.exists(profile.spec.path), "Reuse an imported 2D special-animation sheet"))
	checks.append(assert_true(Signature.profile({"empty":false,"concealed":true,"name":"多龙巴鲁托ex"}).is_empty(), "Never reveal a concealed Pokemon through VFX"))
	checks.append(assert_true(Signature.profile({"empty":false,"concealed":false,"name":"皮卡丘"}).is_empty(), "Unsupported Pokemon retains its shared attribute fallback"))
	return run_checks(checks)

func test_counter_projection_uses_committed_public_deltas_and_stable_identity() -> String:
	var card := {"empty":false,"concealed":false,"visual_id":"one","damage":0}
	var before := {"slots":{"opp_bench_0":card.duplicate(),"opp_bench_1":card.duplicate(),"opp_bench_2":card.duplicate(),"my_bench_0":card.duplicate()}}
	var after := before.duplicate(true)
	after.slots.opp_bench_0.damage = 30
	after.slots.opp_bench_1.damage = 20
	after.slots.opp_bench_1.visual_id = "replacement"
	after.slots.opp_bench_2.damage = 10
	after.slots.opp_bench_2.concealed = true
	after.slots.my_bench_0.damage = 30
	return run_checks([
		assert_eq(Signature.counter_landings(before,after,true),[{"slot":"opp_bench_0","count":3}], "Only committed opposing public counters on the same card fly"),
		assert_eq(Signature.slot_id({"player_index":1,"slot_kind":"bench","slot_index":2},0),"opp_bench_2", "Committed coordinates follow the viewer"),
		assert_eq(Signature.slot_id({"player_index":-1,"slot_kind":"active"},0),"", "Malformed targets fail closed"),
	])

func test_real_ai_attack_and_transfer_spawn_3d_sequences_without_human_dialogs() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var old := [GameManager.battle_3d_enabled,GameManager.current_mode,GameManager.battle_effects_enabled,GameManager.battle_layout_mode]
	var rig := Scenario.new()
	tree.root.add_child(rig)
	await rig.mount()
	var presenter := rig.battle.get_node("Arena3DPresenter")
	rig.transfer()
	await tree.process_frame
	var outcome: Dictionary = presenter.world.signature_vfx.last_outcome
	var checks: Array[String] = [
		assert_not_null(presenter.world.signature_vfx.sequences[0].get("actor"),"Committed ability uses a volumetric actor"),
		assert_eq(outcome.get("kind"),"transfer", "Real ability event routes to the 3D renderer"),
		assert_eq(outcome.get("source"),"opp_active", "Transfer starts at the actual damaged Pokemon"),
		assert_eq(outcome.get("target"),"my_active", "Transfer ends at the committed target"),
		assert_eq(outcome.get("count"),3, "Three selected counters produce three paths"),
		assert_eq(rig.gsm.game_state.players[1].active_pokemon.damage_counters,30,"Rules remove three counters"),
		assert_eq(rig.gsm.game_state.players[0].active_pokemon.damage_counters,30,"Rules place three counters"),
		assert_false(rig.battle.get("_field_interaction_overlay").visible,"AI transfer never shows a human picker"),
	]
	presenter.motion.clear()
	presenter._refresh()
	rig.attack()
	for i: int in 2: await tree.process_frame
	outcome = presenter.world.signature_vfx.last_outcome
	checks.append_array([
		assert_eq(outcome.get("species"),"dragapult","Real attack uses the Dragapult special animation"),
		assert_eq(outcome.get("counters"),[{"slot":"my_bench_0","count":3},{"slot":"my_bench_1","count":2},{"slot":"my_bench_2","count":1}],"Six counters follow exact real distribution"),
		assert_true(presenter.motion.is_busy(),"Signature owns visual pacing until the outcome lands"),
		assert_false(presenter.motion.hand_transfer.active,"Next-turn draw waits behind the attack outcome"),
		assert_false(presenter.motion.hand_transfer.pending.is_empty(),"The queued draw is retained rather than lost"),
		assert_false(rig.battle.get("_field_interaction_overlay").visible,"AI attack never shows a human picker"),
	])
	presenter.world.motion_enabled = false
	for i: int in 3: await tree.process_frame
	checks.append(assert_eq(presenter.world.signature_vfx.get_child_count(),0,"Reduced motion clears sprites, paths and lights"))
	checks.append(assert_false(presenter.motion.is_busy(),"Reduced motion releases player input"))
	await rig.close()
	rig.free()
	GameManager.battle_3d_enabled = old[0]
	GameManager.current_mode = old[1]
	GameManager.battle_effects_enabled = old[2]
	GameManager.battle_layout_mode = old[3]
	return run_checks(checks)

func test_real_charizard_fast_mode_finishes_draw_and_resets_camera() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var old := [GameManager.battle_3d_enabled,GameManager.current_mode,GameManager.battle_effects_enabled,GameManager.battle_layout_mode]
	var rig := Scenario.new()
	tree.root.add_child(rig)
	await rig.mount("charizard",1)
	var presenter := rig.battle.get_node("Arena3DPresenter")
	presenter.motion.fast_enabled = true
	rig.attack()
	for i: int in 2: await tree.process_frame
	var checks: Array[String] = [
		assert_eq(presenter.world.signature_vfx.last_outcome.get("species"),"charizard","Burning Darkness uses the actual special Charizard art"),
		assert_eq(rig.gsm.game_state.players[0].active_pokemon.damage_counters,180,"The signature changes no attack damage"),
		assert_true(presenter.motion.busy_time <= preload("res://scenes/arena3d/ArenaPokemonDirection.gd").profile("charizard").duration/1.8,"Fast mode scales the complete species signature"),
	]
	var deadline := Time.get_ticks_msec()+3500
	while presenter.motion.is_busy() and Time.get_ticks_msec() < deadline: await tree.process_frame
	for i: int in 2: await tree.process_frame
	checks.append_array([
		assert_false(presenter.motion.is_busy(),"Fast signature and queued draw both finish"),
		assert_eq(presenter.world.signature_vfx.sequences.size(),0,"No retained sprite or light sequence"),
		assert_eq(presenter.world.signature_focus,0.0,"Playing camera returns exactly to its original pose"),
		assert_eq(presenter.motion.hand_transfer.history.size(),1,"The deferred draw is played exactly once"),
	])
	await rig.close()
	rig.free()
	GameManager.battle_3d_enabled = old[0]
	GameManager.current_mode = old[1]
	GameManager.battle_effects_enabled = old[2]
	GameManager.battle_layout_mode = old[3]
	return run_checks(checks)
