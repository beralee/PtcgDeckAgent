extends "res://scripts/tools/Arena3DSmoke.gd"
## Constructed public scene. Pointer checks use actual Viewport input.
func _run() -> void:
	get_tree().create_timer(65).timeout.connect(func(): _fail("stadium_surface_timeout"))
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
	gs.players[0].hand.clear()
	for id in [["CSV9C","207"],["CS5DC","152"],["CSV7C","200"]]:
		gs.players[0].hand.append(CardInstance.create(CardDatabase.get_card(id[0],id[1]),0))
	for i in range(4): gs.players[0].hand.append(CardInstance.create(basic,0))
	gs.stadium_card = null
	battle.call("_refresh_ui")
	await _settle(1)
	var presenter = battle.get_node("Arena3DPresenter")
	var caption := Label.new()
	caption.text = "场地与阅读验收 · 构造场面 / 背景切换预览；悬停与点击使用真实鼠标输入"
	caption.position = Vector2(30,108)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.z_index = 250
	battle.add_child(caption)
	var hand: BattleCardView = battle.get("_hand_container").get_child(0)
	await _move_to(hand.get_global_transform()*(hand.size*.5))
	await _capture("stadium-hand-preview.png")
	if not _check(presenter.hover_preview.visible and presenter.hover_art.texture == hand.get("_texture_rect").texture,"hand_has_matching_large_preview"): return
	if not _check(presenter.hover_preview.position.x > presenter.size.x*.65,"hand_preview_is_on_right"): return
	hand.set_face_down(true)
	await _settle(.1)
	if not _check(not presenter.hover_preview.visible,"concealed_hand_never_previews_front"): return
	hand.set_face_down(false)
	await _click_point(hand.get_global_transform()*(hand.size*.5),MOUSE_BUTTON_RIGHT,"hand_details",hand)
	if not _check(not presenter.hover_preview.visible and battle.get("_detail_overlay").visible,"modal_hides_hover"): return
	await _click_control(battle.get("_detail_close_btn"),"close_hand_detail")
	await _move_to(Vector2(380,450))
	if not _check(not presenter.hover_preview.visible,"pointer_exit_hides_preview"): return
	await _capture("stadium-none.png")
	for id in [["CSV9C","207","zero"],["CS5DC","152","magma"],["CSV7C","200","jungle"]]:
		gs.stadium_card = CardInstance.create(CardDatabase.get_card(id[0],id[1]),0)
		battle.call("_refresh_ui")
		await _settle(.85)
		if not _check(not str(presenter.last_frame.get("stadium_background","")).is_empty(),"original_background_resolved_"+id[2]): return
		if not _check(presenter.world.stadium_surface.path == presenter.last_frame.stadium_background,"surface_tracks_public_frame"): return
		await _capture("stadium-"+id[2]+".png")
		await _move_to(hand.get_global_transform()*(hand.size*.5))
		if not _check(presenter.hover_preview.visible,"hand_preview_over_stadium"): return
		await _capture("stadium-"+id[2]+"-hand.png")
		await _move_to(Vector2(380,450))
		await _settle(.4)
	gs.stadium_card = null
	battle.call("_refresh_ui")
	await _settle(.85)
	if not _check(presenter.world.stadium_surface.presence == 0,"stadium_removal_restores_felt"): return
	await _capture("stadium-restored.png")
	gs.players[0].hand.clear()
	for i in range(30): gs.players[0].hand.append(CardInstance.create(basic,0))
	battle.call("_refresh_ui")
	await _settle(.6)
	var scroll: ScrollContainer = battle.get("_hand_scroll")
	for i in range(45):
		var wheel := InputEventMouseButton.new()
		wheel.position = scroll.get_global_rect().get_center()
		wheel.global_position = wheel.position
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		get_tree().root.push_input(wheel,true)
		await get_tree().process_frame
	if not _check(scroll.scroll_horizontal > 0,"large_hand_scrolled"): return
	var last: BattleCardView = battle.get("_hand_container").get_child(29)
	var at: Vector2 = last.get_global_transform()*(last.size*.5)
	await _move_to(at)
	if not _check(presenter.hover_preview.visible and presenter.hover_art.texture == last.get("_texture_rect").texture,"last_scrolled_card_preview"): return
	if not _check(presenter.hover_preview.position.x > presenter.size.x*.65,"rightmost_hand_still_previews_on_right"): return
	await _capture("stadium-large-hand.png")
	for resolution in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(2560,1440)]:
		get_tree().root.size = resolution
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		get_tree().root.content_scale_size = resolution
		await _settle(.35)
		last = battle.get("_hand_container").get_child(29)
		scroll.ensure_control_visible(last)
		await _settle(.15)
		await _move_to(last.get_global_transform()*(last.size*.5))
		if not _check(presenter.hover_preview.visible,"preview_at_"+str(resolution)): return
		if not _check(Rect2(Vector2.ZERO,presenter.size).encloses(presenter.hover_preview.get_rect()),"preview_inside_field_at_"+str(resolution)): return
		await _capture("stadium-preview-%dx%d.png"%[resolution.x,resolution.y])
	print("ARENA_STADIUM_ACCEPTANCE_PASS: hand preview, right placement, details, exit, original stadium art, transition, removal")
	battle.call("_release_battle_runtime_resources")
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _slot(data: CardData, player: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	var ci := CardInstance.create(data,player)
	ci.face_up = true
	slot.pokemon_stack.append(ci)
	return slot

func _move_to(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	get_tree().root.push_input(event,true)
	await _settle(.45)
