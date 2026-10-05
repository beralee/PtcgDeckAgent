extends "res://scripts/tools/ArenaMotionAcceptance.gd"
## Private replay input stays local; only public progress/counts are reported.
func _run() -> void:
	get_tree().create_timer(60).timeout.connect(func(): _fail("knockout_timeout"))
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.selected_deck_ids.assign([575720,575720])
	GameManager.first_player_choice = 0
	GameManager.ai_deck_strategy = "generic"
	battle = load("res://scenes/battle/BattleScene.tscn").instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	get_tree().root.size = Vector2i(1600,900)
	await _settle(1)
	var gsm = battle.get("_gsm")
	var gs: GameState = _public_fixture()
	var record_path := OS.get_environment("ARENA_REPRO_RECORD")
	if not record_path.is_empty():
		var raw: Dictionary = {}
		var record := FileAccess.open(record_path,FileAccess.READ)
		if not _check(record != null,"local_replay_available"): return
		while not record.eof_reached():
			var parsed: Variant = JSON.parse_string(record.get_line())
			if parsed is Dictionary and int(parsed.get("event_index",-1)) == 215:
				raw = parsed
				break
		if not _check(not raw.is_empty(),"pre_attack_snapshot_available"): return
		gs = BattleReplayStateRestorer.new().restore(raw)
	gsm.game_state = gs
	var expected_prizes := 1
	if "--ko-two-prize" in OS.get_cmdline_user_args():
		gs.players[1].active_pokemon = _slot("CSV8C","135",1,180)
		expected_prizes = 2
	if record_path.is_empty():
		for pi in range(2):
			while gsm.count_player_total_cards(pi) < 60:
				gs.players[pi].deck.append(CardInstance.create(CardDatabase.get_card("CSVE1C","DAR"),pi))
	for pi in range(2):
		if not _check(gsm.count_player_total_cards(pi) == 60,"fixture_has_sixty_cards"): return
	battle.set("_pending_choice","")
	battle.get("_dialog_overlay").hide()
	if battle.get("_handover_panel") != null: battle.get("_handover_panel").hide()
	var ai = battle.get("_ai_opponent")
	if ai != null: ai.use_mcts = false
	battle.get("_arena_hand_observer").prime(gs,0)
	var presenter = battle.get_node("Arena3DPresenter")
	presenter.motion.clear()
	if "--ko-reduced-motion" in OS.get_cmdline_user_args(): presenter.world.motion_enabled = false
	if "--ko-fast" in OS.get_cmdline_user_args(): presenter.motion.fast_enabled = true
	battle.call("_refresh_ui")
	await _settle(.8)
	await _click_card(presenter,"my_active")
	var attack: Control = _find_attack(battle.get("_dialog_overlay"))
	if not _check(attack != null,"replay_legal_attack_visible"): return
	await _click_control(attack,"blaziken_attack")
	await _settle(2)
	print("KO_DIAGNOSTIC ",JSON.stringify({"phase":gs.phase,"engine_prize_owner":gsm.get("_pending_prize_player_index"),"engine_prizes":gsm.get("_pending_prize_remaining"),"ui_choice":battle.get("_pending_choice"),"ui_prize_owner":battle.get("_pending_prize_player_index"),"ui_prizes":battle.get("_pending_prize_remaining"),"animating":battle.get("_pending_prize_animating"),"blocked":battle.get("_battle_visual_input_blocked"),"busy":presenter.motion.is_busy(),"prize_ready":presenter.board_hud.prize_ready,"dialog":battle.get("_dialog_overlay").visible}))
	await _capture("knockout-prize.png")
	if not _check(gs.players[1].active_pokemon == null,"budew_knocked_out"): return
	if not _check(battle.get("_pending_choice") == "take_prize" and presenter.board_hud.prize_ready,"knockout_has_clickable_prize_prompt"): return
	if not _check(presenter.prize_notice.visible,"knockout_notice_visible_in_center"): return
	if "--ko-cancel-exit" in OS.get_cmdline_user_args():
		await _click_control(battle.get("_btn_back"),"exit_during_prize")
		if not _check(not presenter.prize_notice.visible,"notice_does_not_cover_modal"): return
		await _click_control(_choice(battle.get("_dialog_overlay"),"dialog_text_choice_index",1),"cancel_exit_during_prize")
		await _settle(.3)
		print("KO_CANCEL_EXIT_DIAGNOSTIC engine_prizes=",gsm.get("_pending_prize_remaining")," ui_choice=",battle.get("_pending_choice")," ready=",presenter.board_hud.prize_ready)
		if not _check(battle.get("_pending_choice") == "take_prize" and presenter.board_hud.prize_ready,"cancel_exit_preserves_prize_prompt"): return
		if not _check(presenter.prize_notice.visible,"cancel_exit_restores_notice"): return
	var prizes: int = gs.players[0].prizes.size()
	for picked in range(expected_prizes):
		for button in presenter.prize_buttons:
			if button.visible and not button.disabled:
				await _click_control(button,"knockout_prize")
				break
		if not _check(gs.players[0].prizes.size() == prizes-picked-1,"each_click_takes_exactly_one_prize"): return
		await _settle(1.3)
		if picked < expected_prizes-1:
			if not _check(presenter.prize_notice.visible and gs.players[1].active_pokemon == null,"multi_prize_waits_for_remaining_selection"): return
	for step in range(80):
		if gs.players[1].active_pokemon != null and gs.turn_number > 9: break
		await _settle(.1)
	if not _check(gs.players[1].active_pokemon != null and gs.turn_number > 9,"opponent_promotes_and_next_turn_starts"): return
	await _capture("knockout-continued.png")
	if not _check(not presenter.prize_notice.visible,"notice_clears_after_prize"): return
	print("ARENA_KNOCKOUT_ACCEPTANCE_PASS")
	battle.call("_release_battle_runtime_resources")
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _slot(set_code: String, index: String, owner: int, damage: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	var card := CardInstance.create(CardDatabase.get_card(set_code,index),owner)
	card.face_up = true
	slot.pokemon_stack.append(card)
	slot.damage_counters = damage
	return slot

func _public_fixture() -> GameState:
	# Revealed board only, with synthetic hidden zones; never export a user's replay.
	var gs := GameState.new()
	gs.phase = GameState.GamePhase.MAIN
	gs.turn_number = 9
	gs.current_player_index = 0
	gs.first_player_index = 0
	for pi in range(2):
		var player := PlayerState.new()
		player.player_index = pi
		var prizes: Array[CardInstance] = []
		for i in range(6 if pi == 0 else 5): prizes.append(CardInstance.create(CardDatabase.get_card("CSVE1C","DAR"),pi))
		player.set_prizes(prizes)
		for i in range(30): player.deck.append(CardInstance.create(CardDatabase.get_card("CSVE1C","DAR"),pi))
		for i in range(5): player.hand.append(CardInstance.create(CardDatabase.get_card("CSVE1C","DAR"),pi))
		gs.players.append(player)
	gs.players[0].active_pokemon = _slot("CSV7C","038",0,30)
	for energy in ["FIR","PSY"]: gs.players[0].active_pokemon.attached_energy.append(CardInstance.create(CardDatabase.get_card("CSVE1C",energy),0))
	gs.players[0].bench.append(_slot("CSV9C","127",0,30))
	gs.players[0].bench.append(_slot("151C","017",0))
	gs.players[0].bench.append(_slot("CSV8C","135",0,30))
	gs.players[0].bench.append(_slot("CSV7C","036",0,10))
	gs.players[1].active_pokemon = _slot("CSV9.5C","004",1)
	gs.players[1].active_pokemon.attached_energy.append(CardInstance.create(CardDatabase.get_card("CSVE1C","DAR"),1))
	gs.players[1].bench.append(_slot("CSV7C","059",1))
	gs.players[1].bench.append(_slot("CSV9.5C","043",1))
	gs.players[1].bench.append(_slot("CSV9.5C","004",1))
	gs.players[1].bench.append(_slot("CSV8C","094",1,20))
	gs.players[1].bench.append(_slot("CSV8C","094",1,30))
	gs.stadium_card = CardInstance.create(CardDatabase.get_card("CSV2C","127"),0)
	gs.stadium_owner_index = 0
	return gs
