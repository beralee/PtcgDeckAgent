extends "res://scripts/tools/Arena3DSmoke.gd"
## Explicit fixture setup; attack, hover, prizes and replacement use Viewport input.
var frame_times: Array[int] = []

func _run() -> void:
	get_tree().create_timer(75).timeout.connect(func(): _fail("motion_acceptance_timeout"))
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.selected_deck_ids.assign([575720,575720])
	GameManager.first_player_choice = 0
	battle = load("res://scenes/battle/BattleScene.tscn").instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	get_tree().root.size = Vector2i(1920,1080)
	await _settle(1.0)
	var gsm = battle.get("_gsm")
	var gs: GameState = gsm.game_state
	var basics: Array[CardData] = []
	var attacker: CardData
	var energy: CardData
	for ci: CardInstance in gs.players[0].deck + gs.players[0].hand:
		if ci.card_data.is_basic_pokemon(): basics.append(ci.card_data)
		if ci.card_data.display_name() == "雷公V": attacker = ci.card_data
		if ci.card_data.card_type == "Basic Energy": energy = ci.card_data
	if not _check(attacker != null and energy != null,"motion_fixture_cards"): return
	gs.phase = GameState.GamePhase.MAIN
	gs.turn_number = 4
	gs.current_player_index = 0
	battle.set("_pending_choice","")
	battle.get("_dialog_overlay").hide()
	if battle.get("_handover_panel") != null: battle.get("_handover_panel").hide()
	for pi in range(2):
		gs.players[pi].bench.clear()
		for i in range(6):
			var slot := PokemonSlot.new()
			var ci := CardInstance.create(attacker if i == 0 else basics[i % basics.size()],pi)
			ci.face_up = true
			slot.pokemon_stack.append(ci)
			if i == 0: gs.players[pi].active_pokemon = slot
			else: gs.players[pi].bench.append(slot)
	for i in range(2): gs.players[0].active_pokemon.attached_energy.append(CardInstance.create(energy,0))
	# Explicit presentation fixture: varied public health, energy and equipment.
	var tool_data: CardData
	var water: CardData
	for candidate: CardData in CardDatabase.get_all_cards():
		if candidate.card_type == "Tool" and candidate.display_name() == "勇气护符": tool_data = candidate
		if candidate.card_type == "Basic Energy" and candidate.energy_provides == "W": water = candidate
	for pi in range(2):
		for j in range(3): gs.players[pi].bench[1].attached_energy.append(CardInstance.create(energy,pi))
		if water != null: gs.players[pi].bench[1].attached_energy.append(CardInstance.create(water,pi))
		if tool_data != null: gs.players[pi].bench[1].attached_tool = CardInstance.create(tool_data,pi)
		gs.players[pi].bench[1].damage_counters = 90
		gs.players[pi].bench[2].damage_counters = gs.players[pi].bench[2].get_max_hp()-30
	gs.players[0].active_pokemon.status_conditions.poisoned = true
	for pi in range(2):
		var prizes: Array[CardInstance] = []
		for i in range(6): prizes.append(gs.players[pi].deck.pop_back())
		gs.players[pi].set_prizes(prizes)
		while gsm.count_player_total_cards(pi) > 60: gs.players[pi].deck.pop_back()
	battle.call("_refresh_ui")
	await _settle(1)
	var presenter = battle.get_node("Arena3DPresenter")
	if tool_data != null and not _check(presenter.last_frame.slots.my_bench_1.get("tool_name","") == "勇气护符","equipped_tool_public_hud"): return
	presenter.world.motion_enabled = true
	var caption := Label.new()
	caption.text = "交互验收场景 · 开局场面为测试夹具，攻击通过真实鼠标操作"
	caption.position = Vector2(28,110)
	caption.add_theme_font_size_override("font_size",14)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.z_index = 240
	battle.add_child(caption)
	var hover := InputEventMouseMotion.new()
	hover.position = presenter.get_global_transform() * presenter.world.camera.unproject_position(presenter.world.cards.my_bench_0.node.position)
	hover.global_position = hover.position
	get_tree().root.push_input(hover,true)
	await _settle(.5)
	await _save("overview")
	print("ARENA_HOVER_DIAGNOSTIC ",hover.position," picked=",presenter.world.hit_slot(presenter.get_global_transform().affine_inverse()*hover.position)," hovered=",presenter.world.hover_id," gui=",get_tree().root.gui_get_hovered_control())
	if not _check(presenter.hover_preview.visible,"hover_preview_actual_input"): return
	await _save("hover-full-card")
	hover.position = Vector2(12,80)
	hover.global_position = hover.position
	get_tree().root.push_input(hover,true)
	await _settle(.3)
	await _click_card(presenter,"my_active")
	await _save("attack-menu")
	var attack_button: Control = _find_attack(battle.get("_dialog_overlay"))
	if not _check(attack_button != null,"legal_attack_choice_visible"): return
	var point := attack_button.get_global_rect().get_center()
	var click := InputEventMouseButton.new()
	click.position = point
	click.global_position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	get_tree().root.push_input(click,true)
	await get_tree().process_frame
	click = click.duplicate()
	click.pressed = false
	get_tree().root.push_input(click,true)
	var saw_sequence := false
	var old_time := Time.get_ticks_usec()
	for frame in range(90):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frame_times.append(now-old_time)
		old_time = now
		for child in presenter.motion.get_children():
			if child.has_meta("profile_id"):
				saw_sequence = true
				if not _check(str(child.get_meta("profile_id")).contains("lightning"),"attribute_profile_from_attacker"): return
		if frame in [2,8,14,22,38,65]: await _save("attack-%02d" % frame)
	if not _check(saw_sequence and presenter.motion.attack_count == 1,"real_attack_spawns_authored_vfx_once"): return
	if not _check(presenter.motion.hold == 0 and not presenter.motion.is_busy(),"attack_releases_visual_pacing"): return
	if not _check(gs.players[1].active_pokemon == null or gs.players[1].active_pokemon.get_remaining_hp() < attacker.hp,"real_attack_resolved_damage"): return
	print("ARENA_MOTION_ATTACK_PASS: Viewport legal attack, lightning profile, damage/KO, pacing released")
	# Verify the actual post-knockout reward prompt, not only a constructed one.
	if battle.get("_pending_choice") == "take_prize" and int(battle.get("_pending_prize_player_index")) == int(battle.get("_view_player")):
		var prize_count: int = gs.players[0].prizes.size()
		await _settle(.4)
		if not _check(presenter.board_hud.prize_ready,"real_knockout_highlights_rewards"): return
		await _save("reward-focus")
		for i in range(6):
			if presenter.prize_buttons[i].visible and not presenter.prize_buttons[i].disabled:
				await _click_control(presenter.prize_buttons[i],"real_knockout_reward")
				break
		if not _check(gs.players[0].prizes.size() == prize_count-1,"real_knockout_reward_into_hand"): return
		await _settle(.4)
		await _save("reward-taken")
		print("ARENA_REAL_KNOCKOUT_REWARD_PASS")
	# Exercise every shared attribute through the identical projected entry.
	caption.text = "属性表现检查 · 与实战共用同一播放入口"
	presenter.set_process(false)
	var preview_frame: Dictionary = presenter.last_frame.duplicate(true)
	preview_frame.slots.opp_active = preview_frame.slots.my_active.duplicate(true)
	presenter.motion.shown = {}
	presenter.motion.present(preview_frame)
	presenter.board_hud.frame = preview_frame
	presenter.board_hud.queue_redraw()
	presenter._update_slot_labels()
	var default_targets: Array[String] = []
	for attribute in ["R","W","G","L","P","F","D","M","N","C"]:
		presenter.motion.start_attack(true,attribute,"属性表现 · "+attribute,default_targets)
		await _settle(.4)
		await _save("attribute-"+attribute)
		await _settle(.9)
	presenter.motion.fast_enabled = true
	presenter.motion.start_attack(true,"W","快速模式",default_targets)
	await _settle(.6)
	if not _check(not presenter.motion.is_busy(),"fast_mode_releases_within_six_tenths"): return
	presenter.motion.fast_enabled = false
	presenter.motion.start_attack(true,"L","关闭动态效果检查",default_targets)
	presenter.world.motion_enabled = false
	await _settle(.15)
	if not _check(presenter.motion.get_child_count() == 0 and not presenter.motion.is_busy(),"reduced_motion_cancels_sequences_and_pacing"): return
	presenter.world.motion_enabled = true
	var report := FileAccess.open("user://motion-frame-times.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"fixture":true,"frame_us":frame_times,"theme":presenter.theme_id,"attacks":presenter.motion.attack_count},"  "))
	report.close()
	print("ARENA_MOTION_ACCEPTANCE_PASS")
	battle.call("_release_battle_runtime_resources")
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _find_attack(node: Node) -> Control:
	if node is Control and not node.is_visible_in_tree(): return null
	if node is Label and "伤害" in node.text and "不可用" not in node.text:
		var parent := node.get_parent()
		while parent != null:
			if parent is Control and not parent.gui_input.get_connections().is_empty(): return parent
			parent = parent.get_parent()
	for child in node.get_children():
		var found := _find_attack(child)
		if found != null: return found
	return null

func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://motion-%s.png" % label)
