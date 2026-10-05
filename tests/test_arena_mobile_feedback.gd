extends "res://tests/test_arena_live_entry.gd"

func test_portrait_home_buttons_clear_footer_at_short_and_tall_ratios() -> String:
	var menu: Control = load("res://scenes/main_menu/MainMenu.tscn").instantiate()
	var checks: Array[String] = []
	for viewport: Vector2 in [Vector2(1080,1920),Vector2(1080,2400),Vector2(390,693)]:
		menu.call("_apply_non_battle_layout_for_tests",viewport,"portrait")
		var box: Control = menu.get_node("VBoxContainer")
		var footer: Button = menu.get("_share_button")
		checks.append(assert_true(viewport.y*.5+box.offset_bottom <= viewport.y+footer.offset_top-12,"All six home actions must end above the footer at %s" % viewport))
		checks.append(assert_true(viewport.y*.5+box.offset_top >= viewport.y*.35,"Home actions preserve the title area"))
	menu.free()
	return run_checks(checks)

func test_opponent_normal_tap_opens_public_slot_details() -> String:
	var scene := await _open(false)
	_install_position(scene,_position())
	scene.get_node("Arena3DPresenter").activate_touch_target({"kind":"slot","id":"opp_active"},false)
	var result := assert_true(scene.get("_detail_overlay").visible,"Normal opponent field tap must open details without a long press")
	await _close(scene)
	return result

func test_field_details_lead_with_energy_tool_hp_and_conditions() -> String:
	var scene := await _open(false)
	var gs := _position()
	gs.players[1].active_pokemon.set_status("poisoned",true)
	_install_position(scene,gs)
	scene.call("_show_slot_card_detail","opp_active")
	var detail: String = scene.get("_detail_content").text
	var checks: Array[String] = [assert_true("中毒" in detail,"Field details must explicitly describe the current condition"),assert_true("HP" in detail,"Current HP must be written in field details"),assert_true(detail.find("能量") < detail.find("喷射头击"),"Attached resources must appear before printed attacks")]
	await _close(scene)
	return run_checks(checks)

func test_prize_commit_waits_for_combat_presentation() -> String:
	var scene := await _open(false)
	var gs := _position()
	_install_position(scene,gs)
	var gsm: GameStateMachine = scene.get("_gsm")
	gsm.set("_pending_prize_player_index",0)
	gsm.set("_pending_prize_remaining",2)
	scene.call("_start_prize_selection",0,2)
	scene.call("_show_portrait_prize_dialog_if_needed")
	var legacy_hidden: bool = not scene.get("_portrait_prize_dialog_active")
	scene.get_node("Arena3DPresenter").motion.busy_time = 3.0
	scene.call("_try_take_prize_from_slot",0,0)
	var result := run_checks([assert_eq(gs.players[0].prizes.size(),6,"No prize owner entry point may commit before the attack finishes"),assert_true(legacy_hidden,"Legacy prize popup must not cover arena choreography")])
	await _close(scene)
	return result

func test_grove_has_no_visible_fern_meshes() -> String:
	var scene := await _open(false)
	var remaining := 0
	for node: Node in scene.get_node("Arena3DPresenter").world.stage.find_children("*","MeshInstance3D",true,false):
		for i in node.mesh.get_surface_count():
			var material: Material = node.mesh.surface_get_material(i)
			if material != null and "fern" in material.resource_name.to_lower() and node.visible: remaining += 1
	var result := assert_eq(remaining,0,"Decorative foliage must not cover the field")
	await _close(scene)
	return result

func test_dragapult_active_and_bench_knockouts_award_all_three_prizes() -> String:
	var scene := await _open(false)
	var gs := _position()
	var attacker := gs.players[0].active_pokemon
	attacker.attached_energy.clear()
	for kind: String in ["FIR","PSY"]: attacker.attached_energy.append(CardInstance.create(CardDatabase.get_card("CSVE1C",kind),0))
	gs.players[1].active_pokemon.damage_counters = 120
	var victim := PokemonSlot.new()
	victim.pokemon_stack.append(CardInstance.create(CardDatabase.get_card("CSV9.5C","004"),1))
	gs.players[1].bench.append(victim)
	var survivor := PokemonSlot.new()
	survivor.pokemon_stack.append(CardInstance.create(CardDatabase.get_card("CSV8C","159"),1))
	gs.players[1].bench.append(survivor)
	_install_position(scene,gs)
	var gsm: GameStateMachine = scene.get("_gsm")
	for pi in 2:
		while gsm.count_player_total_cards(pi) > 60: gs.players[pi].deck.pop_back()
	scene.call("_try_use_attack_with_interaction",0,attacker,1)
	for i in 6:
		scene.call("_on_counter_distribution_amount_chosen",1)
		scene.call("_handle_counter_distribution_target",0)
	print("DRAGAPULT_PRIZE_PROBE ",JSON.stringify({"victim_damage":victim.damage_counters,"pending":gsm.get_pending_decision_snapshot(),"resume":gsm.get("_pending_prize_resume_mode")}))
	var counts: Array[int] = []
	var checks: Array[String] = []
	for i in 3:
		if i == 2 and int(gsm.get("_pending_prize_remaining")) == 0:
			checks.append(assert_true(gsm.send_out_pokemon(1,survivor),"Resolve the engine's intermediate replacement window before the bench prize"))
		counts.append(int(gsm.get("_pending_prize_remaining")))
		checks.append(assert_true(gsm.resolve_take_prize(0,i),"Each of three owed prizes must resolve against the current engine window"))
		print("DRAGAPULT_PRIZE_STEP ",i," ",JSON.stringify(gsm.get_pending_decision_snapshot()))
	checks.append(assert_eq(gs.players[0].prizes.size(),3,"Dragapult must award 2 active prizes plus 1 bench prize"))
	checks.append(assert_eq(counts,[2,1,1],"The existing engine settles the active knockout before the bench knockout"))
	await _close(scene)
	return run_checks(checks)

func test_reward_tiers_wait_for_attack_and_keep_selection_blocked() -> String:
	var scene := await _open(false)
	_install_position(scene,_position())
	var motion: Control = scene.get_node("Arena3DPresenter").motion
	var checks: Array[String] = []
	for count in range(1,7):
		motion.clear()
		motion.reward_chain = [0,0]
		var before: int = motion.reward_history.size()
		motion.busy_time = 1.0
		motion.queue_prize_reward(0,count,true)
		motion._process(.5)
		checks.append(assert_eq(motion.reward_history.size(),before,"Reward must wait for the complete attack"))
		motion._process(.6)
		checks.append(assert_eq(motion.reward_history.back(),count,"Each committed prize tier has its own celebration"))
		checks.append(assert_true(motion.is_busy(),"Reward celebration must finish before prize input becomes available"))
	await _close(scene)
	return run_checks(checks)

func test_clearing_a_queued_reward_releases_input() -> String:
	var scene := await _open(false)
	_install_position(scene,_position())
	var motion: Control = scene.get_node("Arena3DPresenter").motion
	motion.queue_prize_reward(0,3,true)
	var blocked: bool = scene.get("_battle_visual_input_blocked")
	motion.clear()
	var result := run_checks([assert_true(blocked,"Queued reward owns the presentation gate"),assert_false(scene.get("_battle_visual_input_blocked"),"Disabling motion or resizing must release a cancelled reward's input gate")])
	await _close(scene)
	return result

func test_repeated_psychic_embrace_keeps_first_model_without_repeated_wait() -> String:
	var scene := await _open(false)
	var gs := _position()
	gs.players[0].active_pokemon.pokemon_stack.assign([CardInstance.create(CardDatabase.get_card("CSV2C","055"),0)])
	_install_position(scene,gs)
	var presenter: Control = scene.get_node("Arena3DPresenter")
	var motion: Control = presenter.motion
	var card: Dictionary = preload("res://scenes/arena3d/ArenaFrame.gd").capture(gs,0).slots.my_active
	var cue := {"species":"gardevoir","public":true,"card":card,"turn":8,"caster":"my_active","target":"my_active","energy_count":1,"damage":20}
	var checks: Array[String] = [assert_true(motion.start_psychic_embrace(cue),"First embrace keeps its full Pokemon model")]
	var played: int = presenter.world.signature_vfx.played
	# Advance only presentation time; the real repeated ability is covered by
	# the rendered touch probe, including fresh choices and engine resource deltas.
	presenter.world.signature_vfx.clear()
	motion.busy_time = 0
	motion.hold = 0
	checks.append(assert_true(motion.start_psychic_embrace(cue),"Repeated embrace retains a target effect"))
	checks.append(assert_eq(presenter.world.signature_vfx.played,played,"Repeated attachment does not respawn the long cinematic"))
	checks.append(assert_false(motion.is_busy(),"Repeated embrace immediately permits the next legal input"))
	await _close(scene)
	return run_checks(checks)
