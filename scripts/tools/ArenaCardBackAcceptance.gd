extends "res://scripts/tools/ArenaReadabilityAcceptance.gd"
## Constructed public scene. Pointer checks use actual Viewport input.
func _run() -> void:
	get_tree().create_timer(95).timeout.connect(func(): _fail("card_back_timeout"))
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.selected_deck_ids.assign([575720,575720])
	GameManager.first_player_choice = 0
	battle = load("res://scenes/battle/BattleScene.tscn").instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	get_tree().root.size = Vector2i(1920,1080)
	await _settle(1)
	var gs: GameState = battle.get("_gsm").game_state
	var basic: CardData
	for cd: CardData in CardDatabase.get_all_cards():
		if cd.display_name() == "雷公V": basic = cd
	gs.phase = GameState.GamePhase.MAIN
	gs.turn_number = 3
	gs.current_player_index = 0
	battle.set("_pending_choice","")
	battle.get("_dialog_overlay").hide()
	if battle.get("_handover_panel") != null: battle.get("_handover_panel").hide()
	for pi in range(2):
		var player: PlayerState = gs.players[pi]
		player.active_pokemon = _slot(basic,pi)
		player.bench.clear()
		for i in range(5): player.bench.append(_slot(basic,pi))
		var prizes: Array[CardInstance] = []
		for i in range(6): prizes.append(CardInstance.create(basic,pi))
		player.set_prizes(prizes)
		player.discard_pile.clear()
		player.lost_zone.clear()
		for i in range(3): player.discard_card(CardInstance.create(basic,pi))
		player.discard_card(CardInstance.create(CardDatabase.get_card("CS5DC","152"),pi))
		player.lost_zone.append(CardInstance.create(CardDatabase.get_card("CSV7C","200"),pi))
		player.active_pokemon.damage_counters = 70 if pi == 0 else 140
	gs.players[0].hand.clear()
	for id in [["CSV9C","207"],["CS5DC","152"],["CSV7C","200"]]:
		gs.players[0].hand.append(CardInstance.create(CardDatabase.get_card(id[0],id[1]),0))
	for i in range(4): gs.players[0].hand.append(CardInstance.create(basic,0))
	gs.stadium_card = null
	battle.call("_refresh_ui")
	for view: Node in battle.get("_hand_container").get_children():
		if view is BattleCardView:
			if not _check(not view.get("_info_panel").visible,"new_hand_never_exposes_old_text_overlay"): return
	await _settle(1)
	var presenter = battle.get_node("Arena3DPresenter")
	const Backs = preload("res://scenes/arena3d/ArenaCardBacks.gd")
	var caption := Label.new()
	caption.text = "卡背验收 · 构造场面 / 自己蓝背 · 对手金背"
	caption.position = Vector2(30,111)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.z_index = 250
	battle.add_child(caption)
	for perspective in [0,1]:
		battle.set("_view_player",perspective)
		gs.current_player_index = perspective
		battle.call("_refresh_ui")
		await _settle(.45)
		for mine in [true,false]:
			var deck: Dictionary = presenter.world.side_zones.piles["my_deck" if mine else "opp_deck"]
			if not _check(deck.face.material_override.albedo_texture == Backs.for_side(mine),"deck_role_at_view_%d"%perspective): return
			var preview: BattleCardView = battle.get("_my_deck_preview" if mine else "_opp_deck_preview")
			if not _check(preview.get("_back_texture") == Backs.for_side(mine),"legacy_reveal_uses_same_role"): return
		for reward: Dictionary in presenter.world.dynamics.rewards:
			if not _check(reward.face.material_override.albedo_texture == Backs.for_side(reward.mine),"prize_uses_same_role"): return
		await _capture("backs-view-%d.png"%perspective)
		for count in [1,2,8,60,0]:
			for pi in range(2):
				gs.players[pi].deck.clear()
				for i in range(count): gs.players[pi].deck.append(CardInstance.create(basic,pi))
			battle.call("_refresh_ui")
			await _hold_pointer(Vector2(420,430),.4)
			for side in ["my","opp"]:
				var pile: Dictionary = presenter.world.side_zones.piles[side+"_deck"]
				if not _check(pile.face.visible == (count>0) and pile.body.visible == (count>0),"empty_or_occupied_matches_count"): return
			await _capture("backs-v%d-count-%d.png"%[perspective,count])
	# Concealed cards use only role. Identical hidden DTOs carry no card identity.
	gs.turn_number = 0
	gs.phase = GameState.GamePhase.SETUP_PLACE
	for player in gs.players: player.active_pokemon.get_top_card().face_up = false
	battle.call("_refresh_ui")
	await _settle(.5)
	for side in ["my","opp"]:
		var card: Dictionary = presenter.world.cards[side+"_active"]
		if not _check(card.data.get("concealed",false) and card.face.material_override.albedo_texture == Backs.for_side(side=="my"),"hidden_field_role_without_identity"): return
	await _capture("backs-concealed.png")
	# Restore public state, then exercise the actual read-only click handlers.
	gs.turn_number = 3
	gs.phase = GameState.GamePhase.MAIN
	battle.set("_view_player",0)
	gs.current_player_index = 0
	for pi in range(2):
		for i in range(40): gs.players[pi].deck.append(CardInstance.create(basic,pi))
	battle.call("_refresh_ui")
	await _settle(.5)
	for side in ["my","opp"]:
		await _click_control(presenter.zone_buttons[side+"_discard"],"inspect_visible_top_card")
		if not _check(battle.get("_discard_overlay").visible,"discard_mouse_hit_remains_valid"): return
		await _click_control(battle.get("_discard_close_btn"),"close_discard")
	await _click_card(presenter,"my_active",MOUSE_BUTTON_RIGHT)
	if not _check(battle.get("_detail_overlay").visible,"field_card_mouse_hit_remains_valid"): return
	await _click_control(battle.get("_detail_close_btn"),"close_detail")
	for mine in [true,false]:
		for prize in [false,true]:
			presenter.motion.zone_flight(mine,prize)
			await _settle(.16)
			var found := false
			for effect in presenter.world.get_children():
				if effect.has_meta("card_flight"):
					found = effect.get_child(0).material_override.albedo_texture == Backs.for_side(mine)
			if not _check(found,"draw_and_prize_flight_keep_owner"): return
			await _capture("backs-flight-%s-%s.png"%[mine,prize])
			await _settle(.6)
	for resolution in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(2560,1440),Vector2i(1920,1080)]:
		get_tree().root.size = resolution
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		get_tree().root.content_scale_size = resolution
		await _hold_pointer(Vector2(420,430),.4)
		for side in ["my","opp"]:
			var rect: Rect2 = presenter.world.side_zones.screen_rect(side,"deck")
			if not _check(Rect2(Vector2.ZERO,presenter.size).encloses(rect),"deck_stays_inside_table"): return
		await _capture("backs-%dx%d.png"%[resolution.x,resolution.y])
	await _hold_pointer(Vector2(420,430),.5)
	await _capture("backs-final-board.png")
	print("ARENA_CARD_BACK_ACCEPTANCE_PASS: both viewpoints, deck 0/1/2/8/60, matching prize and concealed backs, draw and prize flight ownership, actual popup/pile clicks, four resolutions")
	battle.call("_release_battle_runtime_resources")
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit()
