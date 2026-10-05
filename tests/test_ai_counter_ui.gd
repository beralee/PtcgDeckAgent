extends "res://tests/helpers/BattleUIFeaturesShared.gd"


class CounterScenario extends "res://scenes/battle/BattleScene.gd":
	func _start_battle() -> void:
		pass

	func _maybe_run_ai() -> void:
		# Keep each intermediate window observable; tests advance the real resolver.
		pass


class AuthorOwner extends RefCounted:
	var player_index := 1

	func validate_integrity() -> bool:
		return true


func _counter_fixture(owner: int = 1, prepared: Control = null) -> Dictionary:
	var scene := prepared if prepared != null else _make_battle_scene_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	var gs := gsm.game_state
	gs.current_player_index = owner
	gs.first_player_index = 0
	gs.turn_number = 3
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gs.players.append(player)
		for n: int in 3:
			var slot := PokemonSlot.new()
			slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd("Target %d-%d" % [pi, n], 400, "C"), pi))
			if n == 0:
				player.active_pokemon = slot
			else:
				player.bench.append(slot)
		player.deck.append(CardInstance.create(_make_energy_cd("Draw", "D"), pi))
	var dragapult := CardDatabase.get_card("CSV8C", "159")
	var munkidori := CardDatabase.get_card("CSV8C", "094")
	gsm.effect_processor.register_pokemon_card(dragapult)
	gsm.effect_processor.register_pokemon_card(munkidori)
	var attacker := gs.players[owner].active_pokemon
	attacker.pokemon_stack.assign([CardInstance.create(dragapult, owner)])
	for energy: String in ["R", "P"]:
		attacker.attached_energy.append(CardInstance.create(_make_energy_cd(energy, energy), owner))
	var monkey := gs.players[owner].bench[0]
	monkey.pokemon_stack.assign([CardInstance.create(munkidori, owner)])
	monkey.attached_energy.append(CardInstance.create(_make_energy_cd("Darkness", "D"), owner))
	attacker.damage_counters = 30
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	scene.call("_setup_ai_for_tests")
	scene.set("_ai_opponent", ai)
	scene.call("_setup_field_interaction_panel")
	return {"scene": scene, "gsm": gsm, "attacker": attacker, "monkey": monkey, "opponent": gs.players[1 - owner]}


func _check_hidden(scene: Control, stage: String) -> Array[String]:
	return [
		assert_true(scene.call("_is_field_interaction_active"), stage + ": AI retains its decision state"),
		assert_false((scene.get("_field_interaction_overlay") as Control).visible, stage + ": no human field picker"),
		assert_false((scene.get("_dialog_overlay") as Control).visible, stage + ": no human dialog"),
	]


func test_ai_dragapult_refresh_and_consecutive_placements_stay_hidden() -> String:
	var previous_mode := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var f := _counter_fixture()
	var scene: Control = f.scene
	scene.call("_try_use_attack_with_interaction", 1, f.attacker, 1)
	var checks := _check_hidden(scene, "attack opened")
	for i: int in 6:
		scene.call("_on_counter_distribution_amount_chosen", 1)
		scene.call("_refresh_ui")
		checks.append_array(_check_hidden(scene, "amount %d" % i))
		scene.call("_handle_counter_distribution_target", i % 2)
		if i < 5:
			checks.append_array(_check_hidden(scene, "target %d" % i))
	checks.append_array([
		assert_eq(f.opponent.bench[0].damage_counters, 30, "Three counters resolve on first Bench"),
		assert_eq(f.opponent.bench[1].damage_counters, 30, "Three counters resolve on second Bench"),
		assert_eq(f.opponent.active_pokemon.damage_counters, 200, "Phantom Dive still deals its attack damage"),
		assert_eq(str(scene.get("_pending_choice")), "", "Attack finishes without a stuck prompt"),
	])
	GameManager.current_mode = previous_mode
	return run_checks(checks)


func test_ai_munkidori_source_count_and_target_refresh_stay_hidden() -> String:
	var previous_mode := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var checks: Array[String] = []
	for count: int in [1, 2, 3]:
		var f := _counter_fixture()
		var scene: Control = f.scene
		scene.call("_try_use_ability_with_interaction", 1, f.monkey, 0)
		scene.call("_refresh_ui")
		checks.append_array(_check_hidden(scene, "damage source"))
		scene.call("_handle_field_slot_select_index", 0)
		scene.call("_on_counter_distribution_amount_chosen", count)
		scene.call("_refresh_ui")
		checks.append_array(_check_hidden(scene, "transfer count %d" % count))
		scene.call("_handle_counter_distribution_target", 0)
		checks.append_array([
			assert_eq(f.attacker.damage_counters, 30 - count * 10, "Remove exactly selected counters"),
			assert_eq(f.opponent.active_pokemon.damage_counters, count * 10, "Transfer exactly selected counters"),
			assert_eq(str(scene.get("_pending_choice")), "", "Transfer completes without waiting for human input"),
		])
	GameManager.current_mode = previous_mode
	return run_checks(checks)


func test_human_cannot_click_ai_counter_target_but_resolver_can_finish() -> String:
	var previous_mode := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var f := _counter_fixture()
	var scene: Control = f.scene
	scene.call("_try_use_attack_with_interaction", 1, f.attacker, 1)
	scene.call("_on_counter_distribution_amount_chosen", 1)
	scene.call("_try_handle_field_interaction_slot_click", "my_bench_0", f.opponent.bench[0])
	var checks: Array[String] = [assert_eq((scene.get("_field_interaction_assignment_entries") as Array).size(), 0, "Human click cannot submit an AI-owned target")]
	var resolver := AIStepResolver.new()
	for i: int in 8:
		if str(scene.get("_pending_choice")) != "effect_interaction":
			break
		resolver.resolve_pending_step(scene, f.gsm, 1)
	checks.append_array([
		assert_eq(str(scene.get("_pending_choice")), "", "Actual AI resolver completes the hidden window"),
		assert_eq(f.opponent.bench[0].damage_counters + f.opponent.bench[1].damage_counters, 60, "AI distributes all six counters"),
	])
	GameManager.current_mode = previous_mode
	return run_checks(checks)


func test_human_munkidori_keeps_visible_picker_and_clickable_target() -> String:
	var previous_mode := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var f := _counter_fixture(0)
	var scene: Control = f.scene
	scene.call("_try_use_ability_with_interaction", 0, f.monkey, 0)
	scene.call("_refresh_ui")
	var checks: Array[String] = [assert_true((scene.get("_field_interaction_overlay") as Control).visible, "Human sees damage-source picker")]
	scene.call("_try_handle_field_interaction_slot_click", "my_active", f.attacker)
	scene.call("_on_counter_distribution_amount_chosen", 2)
	scene.call("_refresh_ui")
	checks.append(assert_true((scene.get("_field_interaction_overlay") as Control).visible, "Human sees count and target picker"))
	scene.call("_try_handle_field_interaction_slot_click", "opp_active", f.opponent.active_pokemon)
	checks.append(assert_eq(f.opponent.active_pokemon.damage_counters, 20, "Human board click transfers two counters"))
	GameManager.current_mode = previous_mode
	return run_checks(checks)


func test_current_chooser_controls_visibility_even_on_other_players_turn() -> String:
	var previous_mode := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var checks: Array[String] = []
	for chooser: int in [0, 1]:
		var f := _counter_fixture(1 - chooser)
		var scene: Control = f.scene
		var steps: Array[Dictionary] = [{"id": "opponent_pick", "items": [f.attacker], "opponent_chooses": true, "min_select": 1, "max_select": 1}]
		scene.call("_start_effect_interaction", "ability", 1 - chooser, steps, f.attacker.get_top_card())
		scene.call("_refresh_ui")
		checks.append(assert_eq((scene.get("_field_interaction_overlay") as Control).visible, chooser == 0, "Visibility follows chooser, not turn or card owner"))
	GameManager.current_mode = previous_mode
	return run_checks(checks)


func test_author_ai_uses_same_hidden_counter_presentation() -> String:
	var previous_mode := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var f := _counter_fixture()
	var scene: Control = f.scene
	scene.call("_try_use_ability_with_interaction", 1, f.monkey, 0)
	scene.call("_handle_field_slot_select_index", 0)
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
	scene.set("_author_player_owner", AuthorOwner.new())
	scene.call("_on_counter_distribution_amount_chosen", 2)
	scene.call("_refresh_field_interaction_status")
	var checks := _check_hidden(scene, "author AI counter window")
	checks.append(assert_eq(int(scene.get("_field_interaction_assignment_selected_source_index")), 2, "Hidden UI preserves local author count decision"))
	scene.set("_author_player_owner", null)
	GameManager.current_mode = previous_mode
	return run_checks(checks)


func test_packed_scene_ai_picker_and_target_hints_stay_hidden_after_rotation() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_size := tree.root.size
	var previous_scale := tree.root.content_scale_size
	var previous_layout := GameManager.battle_layout_mode
	var previous_3d := GameManager.battle_3d_enabled
	var previous_mode := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.battle_3d_enabled = false
	var scene: Control = BattleScenePacked.instantiate()
	scene.set_script(CounterScenario)
	tree.root.add_child(scene)
	await tree.process_frame
	var f := _counter_fixture(1, scene)
	scene.call("_try_use_attack_with_interaction", 1, f.attacker, 1)
	scene.call("_on_counter_distribution_amount_chosen", 1)
	var checks: Array[String] = []
	for viewport_size: Vector2i in [Vector2i(1600, 900), Vector2i(900, 1600), Vector2i(390, 844), Vector2i(844, 390)]:
		tree.root.size = viewport_size
		tree.root.content_scale_size = viewport_size
		GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT if viewport_size.y > viewport_size.x else GameManager.BATTLE_LAYOUT_LANDSCAPE
		scene.call("_refresh_ui")
		for frame: int in 4:
			await tree.process_frame
		checks.append_array(_check_hidden(scene, str(viewport_size)))
		var views: Dictionary = scene.get("_slot_card_views")
		var target: BattleCardView = views.my_bench_0
		checks.append(assert_false(bool(target.get("_selectable_hint")), "AI targets must not invite human input after rotation"))
		checks.append(assert_false(bool(target.get("_selected")), "AI assignments do not show human selection borders"))
		checks.append(assert_eq((scene.get("_field_interaction_slot_index_by_id") as Dictionary).size(), 2, "Rotation retains both legal targets for AI"))
	tree.root.remove_child(scene)
	for frame: int in 3:
		await tree.process_frame
	scene.free()
	GameManager.current_mode = previous_mode
	GameManager.battle_layout_mode = previous_layout
	GameManager.battle_3d_enabled = previous_3d
	tree.root.size = previous_size
	tree.root.content_scale_size = previous_scale
	return run_checks(checks)


func test_3d_ai_targets_and_hint_stay_hidden_without_disabling_human_picker() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_3d := GameManager.battle_3d_enabled
	var previous_mode := GameManager.current_mode
	GameManager.battle_3d_enabled = true
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var scene: Control = BattleScenePacked.instantiate()
	scene.set_script(CounterScenario)
	tree.root.add_child(scene)
	var f := _counter_fixture(1, scene)
	scene.call("_refresh_ui")
	for frame: int in 20:
		await tree.process_frame
	scene.call("_try_use_attack_with_interaction", 1, f.attacker, 1)
	scene.call("_on_counter_distribution_amount_chosen", 1)
	for frame: int in 4:
		await tree.process_frame
	var presenter := scene.get_node_or_null("Arena3DPresenter")
	var checks: Array[String] = [assert_not_null(presenter, "Fixture mounts actual 3D presenter")]
	if presenter != null:
		var world: Node3D = presenter.get("world")
		var cards: Dictionary = world.get("cards")
		checks.append(assert_false((cards.my_bench_0.glow as Node3D).visible, "AI damage targets have no selectable glow in 3D"))
		checks.append(assert_false("请选择场上的目标" in (presenter.get("hint") as Label).text, "3D must not ask the human to choose AI targets"))
		var steps: Array[Dictionary] = scene.get("_pending_effect_steps")
		steps[0]["chooser_player_index"] = 0
		scene.call("_show_next_effect_interaction_step")
		for frame: int in 4:
			await tree.process_frame
		checks.append(assert_true((cards.my_bench_0.glow as Node3D).visible, "A human-owned current window still highlights 3D targets"))
		checks.append(assert_true((scene.get("_field_interaction_overlay") as Control).visible, "3D human picker remains available"))
	tree.root.remove_child(scene)
	for frame: int in 3:
		await tree.process_frame
	scene.free()
	GameManager.current_mode = previous_mode
	GameManager.battle_3d_enabled = previous_3d
	return run_checks(checks)
