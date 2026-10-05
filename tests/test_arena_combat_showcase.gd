extends TestBase

func test_all_character_scenes_commit_real_rules_and_emit_the_matching_signature() -> String:
	var scenario = load("res://scripts/tools/ArenaSignatureScenario.gd")
	var rig: Node = scenario.new()
	if not rig.has_method("mount_combat"):
		rig.free()
		return assert_true(false,"Every recorded species needs a real battle scenario, not a gallery or directly invoked VFX")
	var tree := Engine.get_main_loop() as SceneTree
	var saved := [GameManager.battle_3d_enabled,GameManager.current_mode,GameManager.battle_effects_enabled,GameManager.battle_layout_mode]
	var checks: Array[String] = []
	for id: String in load("res://scenes/arena3d/ArenaPokemonCatalog.gd").ENTRIES:
		tree.root.add_child(rig)
		await rig.mount_combat(id)
		var defender: PokemonSlot = rig.combat_recipient()
		var before := defender.damage_counters
		var energy_before:=defender.attached_energy.size()
		checks.append(assert_true(rig.perform_combat(),id+" can submit all real interaction choices"))
		for i: int in 2:await tree.process_frame
		var presenter: Node = rig.battle.get_node("Arena3DPresenter")
		var outcome: Dictionary = presenter.world.signature_vfx.last_outcome
		checks.append(assert_eq(outcome.get("species",""),id,id+" renders its own committed action"))
		checks.append(assert_true(defender.damage_counters>before,id+" actually changes the defender through the rules engine"))
		if id=="gardevoir":
			checks.append(assert_eq(defender.attached_energy.size(),energy_before+1,"Psychic Embrace actually attaches the discarded energy"))
			checks.append(assert_eq(defender.damage_counters-before,20,"Psychic Embrace shows its real damage cost"))
			checks.append(assert_eq(outcome.get("target"),"opp_bench_0","Ability follows the selected ally rather than the opposing active"))
			checks.append(assert_true(rig.perform_combat(),"Repeated embrace commits independently while the first animation is active"))
			checks.append(assert_eq(defender.attached_energy.size(),energy_before+2,"Both consecutive embraces attach their own discarded energy"))
			checks.append(assert_eq(defender.damage_counters-before,40,"Both consecutive embraces pay their real damage cost"))
			# Repeated embraces intentionally use the short target pulse introduced
			# for mobile play; replaying the full model would block every attachment.
			checks.append(assert_eq(presenter.world.signature_vfx.played,1,"Only the first embrace starts the full model cinematic"))
			checks.append(assert_eq(presenter.motion.embrace_repeats,1,"The second committed embrace must still emit its distinct target pulse"))
		checks.append(assert_false(rig.battle.get("_field_interaction_overlay").visible,id+" AI action has no human picker"))
		checks.append(assert_eq(rig.gsm.count_player_total_cards(1),60,id+" retains all 60 staged cards"))
		await rig.close()
		rig.free()
		rig=scenario.new()
	rig.free()
	GameManager.battle_3d_enabled=saved[0]
	GameManager.current_mode=saved[1]
	GameManager.battle_effects_enabled=saved[2]
	GameManager.battle_layout_mode=saved[3]
	return run_checks(checks)
