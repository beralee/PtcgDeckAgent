extends "res://scripts/tools/ArenaStadiumAcceptance.gd"
## Constructed public scene. Pointer checks use actual Viewport input.
func _run() -> void:
	get_tree().create_timer(95).timeout.connect(func(): _fail("readability_timeout"))
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
	var caption := Label.new()
	caption.text = "画面与输入验收 · 构造场面；弹窗、牌堆、悬停、滚轮均使用实际鼠标输入"
	caption.position = Vector2(30,111)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.z_index = 250
	battle.add_child(caption)
	var initial: Vector2i = presenter.viewport.size
	var card: BattleCardView = battle.get("_hand_container").get_child(0)
	await _move_to(card.get_global_transform()*(card.size*.5))
	await _capture("before.png")
	var at: Vector2 = card.get_global_transform()*(card.size*.5)
	for pressed in [true,false]:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		get_tree().root.push_input(motion,true)
		var click := InputEventMouseButton.new()
		click.position = at
		click.global_position = at
		click.button_index = MOUSE_BUTTON_RIGHT
		click.pressed = pressed
		get_tree().root.push_input(click,true)
	var box: Control = battle.get_node("DetailOverlay/DetailCenter/DetailBox")
	var lowest := box.modulate.a
	var sizes := {}
	for i in range(18):
		await RenderingServer.frame_post_draw
		lowest = minf(lowest,box.modulate.a)
		sizes[str(presenter.viewport.size)] = true
		if i < 6: get_viewport().get_texture().get_image().save_png("user://popup-frame-%02d.png" % i)
		await get_tree().process_frame
	print("POPUP_TRACE alpha_min=",lowest," viewport_sizes=",sizes," before=",initial)
	if not _check(battle.get("_detail_overlay").visible and lowest >= .99,"popup_content_never_starts_transparent"): return
	if not _check(sizes.size() == 1 and sizes.has(str(initial)),"popup_does_not_resize_world"): return
	await _click_control(battle.get("_detail_close_btn"),"close_detail")
	await _move_to(Vector2(420,430))
	await _capture("readability-board.png")
	if not _check(presenter.world.side_zones.piles.size() == 4 and presenter.zone_buttons.size() == 2,"only_current_format_zones"): return
	for side in ["my","opp"]:
		var deck: Dictionary = presenter.world.side_zones.piles[side+"_deck"]
		if not _check(deck.face.visible and deck.face.material_override.albedo_texture == preload("res://scenes/arena3d/ArenaCardBacks.gd").for_side(side == "my"),"distinct_deck_back_"+side): return
		var pi: int = 0 if side == "my" else 1
		var top: Dictionary = presenter.last_frame.players[pi].discard_top
		var pile: Dictionary = presenter.world.side_zones.piles[side+"_discard"]
		if not _check(pile.path == top.image and pile.face.visible and pile.face.material_override.albedo_texture != null,"visible_latest_"+side+"discard"): return
		await _click_control(presenter.zone_buttons[side+"_discard"],"open_"+side+"discard")
		if not _check(battle.get("_discard_overlay").visible,"zone_opens_collection"): return
		var title: String = battle.get("_discard_title").text
		if not _check("弃牌" in title,"correct_zone_collection"): return
		await _capture("zone-"+side+"discard.png")
		await _click_control(battle.get("_discard_close_btn"),"close_collection")
	gs.players[0].discard_pile.pop_back()
	battle.call("_refresh_ui")
	await _settle(.25)
	if not _check(presenter.last_frame.players[0].discard_top.uid == basic.get_uid(),"top_updates_after_recovery"): return
	gs.players[0].discard_pile.clear()
	gs.players[0].deck.clear()
	battle.call("_refresh_ui")
	await _settle(.25)
	if not _check(not presenter.world.side_zones.piles.my_discard.face.visible and not presenter.world.side_zones.piles.my_deck.face.visible,"empty_zones_clear_face"): return
	await _capture("zones-empty.png")
	for i in range(40): gs.players[0].deck.append(CardInstance.create(basic,0))
	gs.players[0].discard_card(CardInstance.create(CardDatabase.get_card("CS5DC","152"),0))
	# Let the public frame observe the fixture mutation before dispatching input;
	# an input bound to the previous frame must (correctly) be rejected.
	battle.call("_refresh_ui")
	await _settle(.5)
	# Repeated field action/detail openings must not resize or restyle the board.
	for cycle in range(3):
		await _click_card(presenter,"my_active")
		print("POPUP_ACTION_STATE pending=",battle.get("_pending_choice")," ready=",battle.call("_can_view_player_start_turn_action")," accept=",battle.call("_can_accept_live_action")," busy=",presenter.motion.is_busy()," modal=",battle.call("_is_board_modal_overlay_visible"))
		await _capture("action-cycle-%d.png"%cycle)
		if not _check(battle.get("_pending_choice") == "pokemon_action","field_action_opens"): return
		if not _check(presenter.viewport.size == initial,"action_popup_keeps_world_size"): return
		await _click_control(battle.get("_dialog_cancel"),"close_action")
		await _click_card(presenter,"my_active",MOUSE_BUTTON_RIGHT)
		if not _check(box.modulate.a == 1 and box.scale == Vector2.ONE,"repeated_detail_stays_opaque"): return
		await _click_control(battle.get("_detail_close_btn"),"close_repeated_detail")
	await _move_to(Vector2(420,430))
	for id in [["CSV9C","207","zero"],["CS5DC","152","magma"],["CSV7C","200","jungle"]]:
		gs.stadium_card = CardInstance.create(CardDatabase.get_card(id[0],id[1]),0)
		battle.call("_refresh_ui")
		await _hold_pointer(Vector2(420,430),.9)
		await _capture("light-"+id[2]+"-a.png")
		var lamp: Vector3 = presenter.world.dynamics.lamps[0].position
		await _hold_pointer(Vector2(420,430),1.8)
		var mat: ShaderMaterial = presenter.world.stadium_surface.materials[0]
		if not _check(lamp.distance_to(presenter.world.dynamics.lamps[0].position) > .1,"illumination_moves_over_art"): return
		if not _check(Vector3(mat.get_shader_parameter("lamp_a")).is_equal_approx(presenter.world.dynamics.lamps[0].position),"surface_follows_real_light"): return
		await _capture("light-"+id[2]+"-b.png")
	var tera: CardData
	for cd: CardData in CardDatabase.get_all_cards():
		if cd.is_basic_pokemon() and cd.is_tera_pokemon():
			tera = cd
			break
	gs.stadium_card = CardInstance.create(CardDatabase.get_card("CSV9C","207"),0)
	for pi in range(2):
		gs.players[pi].active_pokemon = _slot(tera,pi)
		for i in range(3): gs.players[pi].bench.append(_slot(basic,pi))
	gs.players[0].hand.clear()
	for i in range(30): gs.players[0].hand.append(CardInstance.create(basic,0))
	battle.call("_refresh_ui")
	for resolution in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1440,900),Vector2i(2560,1440)]:
		get_tree().root.size = resolution
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		get_tree().root.content_scale_size = resolution
		await _settle(.4)
		var scroll: ScrollContainer = battle.get("_hand_scroll")
		var last: BattleCardView = battle.get("_hand_container").get_child(29)
		for i in range(50):
			var wheel := InputEventMouseButton.new()
			wheel.position = scroll.get_global_rect().get_center()
			wheel.global_position = wheel.position
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = true
			get_tree().root.push_input(wheel,true)
			await get_tree().process_frame
		await _move_to(last.get_global_transform()*(last.size*.5))
		if not _check(presenter.hover_preview.visible,"large_hand_last_preview_"+str(resolution)): return
		var hand_area: Control = battle.get_node("MainArea/CenterField/HandArea")
		var fill: float = last.size.y/hand_area.size.y
		print("HAND_FILL ",resolution," card=",last.size," tray=",hand_area.size," ratio=",fill)
		if not _check(fill >= .77,"hand_uses_tray_height"): return
		for side in ["my","opp"]:
			var previous := Rect2()
			for kind in ["deck","discard"]:
				var rect: Rect2 = presenter.world.side_zones.screen_rect(side,kind)
				if not _check(Rect2(Vector2.ZERO,presenter.size).encloses(rect) and rect.size.x >= 56,"pile_readable_inside_arena"): return
				if not _check(not previous.intersects(rect),"neighbor_piles_do_not_overlap"): return
				previous = rect
				for id: String in presenter.world.cards:
					if presenter.world.cards[id].node.visible:
						if not _check(not rect.intersects(presenter.world.card_screen_rect(id)),"piles_do_not_cover_eight_bench_"+id): return
		await _capture("large-hand-%dx%d.png"%[resolution.x,resolution.y])
	print("ARENA_READABILITY_PASS: stable popup, official backs, public top cards, zones click/empty/recovery, moving surface light, four resolutions, large hand")
	battle.call("_release_battle_runtime_resources")
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _hold_pointer(at: Vector2, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		var event := InputEventMouseMotion.new()
		event.position = at
		event.global_position = at
		get_tree().root.push_input(event,true)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
