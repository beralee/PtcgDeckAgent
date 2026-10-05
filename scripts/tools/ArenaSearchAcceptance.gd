extends "res://scripts/tools/ArenaLivingAcceptance.gd"
## Real cards with a controlled opening; all choices use Viewport mouse input.
func _run() -> void:
	get_tree().create_timer(130).timeout.connect(func(): _fail("search_choreography_timeout"))
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
	var nest: CardData
	var iono: CardData
	var energy: CardData
	for cd: CardData in CardDatabase.get_all_cards():
		if cd.display_name() == "雷公V": basic = cd
		if cd.display_name() == "巢穴球": nest = cd
		if cd.display_name() == "奇树": iono = cd
		if cd.card_type == "Basic Energy" and cd.energy_provides == "L": energy = cd
	if not _check(basic != null and nest != null and iono != null and energy != null,"real_nest_iono_loaded"): return
	gs.phase = GameState.GamePhase.MAIN
	gs.turn_number = 3
	gs.current_player_index = 0
	gs.supporter_used_this_turn = false
	gs.stadium_card = null
	battle.set("_pending_choice","")
	battle.get("_dialog_overlay").hide()
	if battle.get("_handover_panel") != null: battle.get("_handover_panel").hide()
	for pi in range(2):
		var player: PlayerState = gs.players[pi]
		player.hand.clear()
		player.deck.clear()
		player.discard_pile.clear()
		player.bench.clear()
		player.active_pokemon = _slot(basic,pi)
		player.bench.append(_slot(basic,pi))
		var prizes: Array[CardInstance] = []
		for i in range(6): prizes.append(CardInstance.create(energy,pi))
		player.set_prizes(prizes)
		for i in range(45): player.deck.append(CardInstance.create(basic if i%3==0 else energy,pi))
		for i in range(7): player.hand.append(CardInstance.create(energy,pi))
	var stadium := CardInstance.create(CardDatabase.get_card("CSV9C","207"),0)
	var ball := CardInstance.create(nest,0)
	var supporter := CardInstance.create(iono,0)
	gs.players[0].hand[0] = stadium
	gs.players[0].hand[1] = ball
	gs.players[0].hand[2] = supporter
	battle.call("_refresh_ui")
	battle.get("_arena_hand_observer").prime(gs,0)
	await _settle(.5)
	var presenter = battle.get_node("Arena3DPresenter")
	var label := Label.new()
	label.text = "实卡交互验收 · 构造开场 / 巢穴球搜牌与奇树换牌通过鼠标操作"
	label.position = Vector2(30,112)
	label.z_index = 250
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle.add_child(label)
	await _hand_click(stadium)
	var use := _button_named(battle,"使用")
	if use != null: await _click_control(use,"play_stadium")
	await _settle(.8)
	if not _check(gs.stadium_card == stadium and not presenter.stadium_button.visible,"real_stadium_hides_redundant_button"): return
	if not _check(presenter.world.cards.stadium.node.scale.is_equal_approx(presenter.world.cards.my_active.node.scale),"stadium_matches_active_size"): return
	await _capture("search-stadium.png")
	await _click_card(presenter,"stadium")
	# Stadium still routes to its original read/detail owner.
	if battle.get("_detail_overlay").visible: await _click_control(battle.get("_detail_close_btn"),"close_stadium_detail")
	elif battle.get("_dialog_overlay").visible: await _click_control(battle.get("_dialog_cancel"),"close_stadium_action")
	await _hand_click(ball)
	use = _button_named(battle,"使用")
	if use != null: await _click_control(use,"use_nest_ball")
	await _settle(.7)
	if not _check(battle.get("_dialog_library_search_board_mode") and battle.get("_dialog_overlay").visible,"real_nest_ball_opens_search"): return
	var search = presenter.search_presentation
	if not _check(search.right.art != null and search.right.size.y >= 390,"source_card_is_large_and_clear"): return
	await _capture("search-open.png")
	var board: Control = battle.get("_dialog_library_search_board")
	var row: HBoxContainer = board.find_child("LibraryCardRow",true,false)
	var choice: Control
	for slot: Control in row.get_children():
		if int(slot.get_meta("dialog_choice_index",-1)) >= 0:
			choice = slot
			break
	await _click_control(choice,"select_from_actual_library")
	if not _check(search.left_title.text.begins_with("已选") and search.left.art == choice.get_child(0).get("_texture_rect").texture,"large_selected_preview_matches_choice"): return
	await _capture("search-selected.png")
	var selected_row: HBoxContainer = board.find_child("LibrarySelectedSlotRow",true,false)
	await _click_control(selected_row.get_child(0),"remove_selected_candidate")
	print("SEARCH_DESELECT ",JSON.stringify({"indices":battle.get("_dialog_card_selected_indices"),"title":search.left_title.text,"detail_visible":battle.get("_detail_overlay").visible}))
	if not _check(battle.get("_dialog_card_selected_indices").is_empty() and search.left_title.text == "候选预览","deselect_updates_large_preview"): return
	await _click_control(choice,"reselect_candidate")
	await _click_control(search.left,"inspect_large_selected_card")
	if not _check(battle.get("_detail_overlay").visible,"selected_large_card_opens_detail"): return
	await _click_control(battle.get("_detail_close_btn"),"close_selected_detail")
	await _click_control(search.right,"inspect_source_card")
	if not _check(battle.get("_detail_overlay").visible,"source_large_card_opens_detail"): return
	await _click_control(battle.get("_detail_close_btn"),"close_source_detail")
	for resolution in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(2560,1440),Vector2i(1920,1080)]:
		get_tree().root.size = resolution
		await _settle(.5)
		var box: Control = battle.get("_dialog_box")
		# Production keeps a 900-unit logical short edge on small windows.
		# Compare like coordinates and verify the transformed physical bounds too.
		var physical_box: Rect2 = get_tree().root.get_stretch_transform() * box.get_global_rect()
		print("SEARCH_LAYOUT ",resolution," canvas=",battle.get_viewport_rect()," box=",box.get_global_rect()," physical_box=",physical_box," source=",search.right.get_global_rect()," selected=",search.left.get_global_rect())
		if not _check(get_tree().root.size == resolution,"search_uses_requested_window_size"): return
		if not _check(battle.get_viewport_rect().encloses(box.get_global_rect()),"search_window_inside_logical_canvas"): return
		if not _check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(physical_box),"search_window_inside_resolution"): return
		if not _check(not search.left.get_global_rect().intersects(search.right.get_global_rect()),"large_previews_do_not_overlap"): return
		await _capture("search-%dx%d.png"%[resolution.x,resolution.y])
	var library_scroll: ScrollContainer = board.find_child("LibrarySearchLibraryScroll",true,false)
	for i in range(100):
		var wheel := InputEventMouseButton.new()
		wheel.position = library_scroll.get_global_rect().get_center()
		wheel.global_position = wheel.position
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		get_tree().root.push_input(wheel,true)
		var wheel_release := wheel.duplicate()
		wheel_release.pressed = false
		get_tree().root.push_input(wheel_release,true)
		await get_tree().process_frame
	var disabled: Control = row.get_child(row.get_child_count()-1)
	if not _check(library_scroll.get_global_rect().intersects(disabled.get_global_rect()),"wheel_reaches_end_of_large_library"): return
	var hover := InputEventMouseMotion.new()
	hover.position = disabled.get_global_rect().get_center()
	hover.global_position = hover.position
	get_tree().root.push_input(hover,true)
	await _settle(.12)
	if not _check(search.current_card == disabled.get_child(0) and search.source_card.card_instance == ball,"disabled_candidate_can_preview_without_changing_source"): return
	await _click_control(disabled,"inspect_unselectable_candidate")
	if not _check(battle.get("_dialog_card_selected_indices").size() == 1,"disabled_candidate_does_not_change_selection"): return
	await _capture("search-scroll-preview.png")
	print("SEARCH_BEFORE_CONFIRM selected=",battle.get("_dialog_card_selected_indices")," disabled=",battle.get("_dialog_confirm").disabled," blocked=",battle.get("_battle_visual_input_blocked")," pending=",battle.get("_pending_choice"))
	await _click_control(battle.get("_dialog_confirm"),"confirm_nest_ball")
	await _settle(1.5)
	print("SEARCH_AFTER_CONFIRM bench=",gs.players[0].bench.size()," discarded=",ball in gs.players[0].discard_pile," dialog=",battle.get("_dialog_overlay").visible," pending=",battle.get("_pending_choice")," blocked=",battle.get("_battle_visual_input_blocked"))
	if not _check(gs.players[0].bench.size() == 2 and ball in gs.players[0].discard_pile,"nest_ball_committed_once"): return
	presenter.motion.hand_transfer.history.clear()
	await _hand_click(supporter)
	use = _button_named(battle,"使用")
	if use != null: await _click_control(use,"use_iono")
	var transfer = presenter.motion.hand_transfer
	if not _check(transfer.is_busy(),"iono_runs_physical_hand_sequence"): return
	await _capture("iono-collect.png")
	await _settle(.65)
	await _capture("iono-return.png")
	await _settle(.65)
	await _capture("iono-deal.png")
	# Supporter cut-ins and both physical batches share the presentation queue.
	# Wait for its actual completion; a fixed delay can inspect only the returns.
	var hand_deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < hand_deadline and presenter.motion.is_busy():
		await _settle(.05)
	if not _check(not presenter.motion.is_busy(),"iono_sequence_completes_within_deadline"): return
	print("HAND_BATCH_HISTORY ",JSON.stringify(transfer.history))
	var returns := 0
	var draws := 0
	for event: Dictionary in transfer.history:
		if event.direction == "return": returns += 1
		if event.direction == "draw": draws += 1
	if not _check(returns == 2 and draws == 2,"iono_animates_both_returns_and_both_deals"): return
	if not _check(gs.players[0].hand.size() == 6 and gs.players[1].hand.size() == 6 and supporter in gs.players[0].discard_pile,"iono_rule_result_preserved"): return
	if not _check(not transfer.is_busy() and battle.get("_hand_scroll").modulate.a == 1,"hand_reappears_and_input_unblocks"): return
	await _capture("iono-finished.png")
	# Drive the real engine draw boundary; existing hand cards must stay visible.
	battle.get("_gsm").draw_card(0,1)
	battle.call("_refresh_ui")
	await _settle(.25)
	var hand_cards: Control = battle.get("_hand_container")
	if not _check(transfer.is_busy() and hand_cards.get_child_count() == 7 and hand_cards.get_child(0).modulate.a == 1 and hand_cards.get_child(6).modulate.a == 0,"single_draw_masks_only_new_card"): return
	await _capture("single-draw.png")
	await _settle(1.3)
	if not _check(hand_cards.get_child(6).modulate.a == 1 and not transfer.is_busy(),"single_draw_reveals_card_and_restores_input"): return
	var synthetic_draw: Array[Dictionary] = [{"mine":true,"count":12,"direction":"draw"}]
	transfer.enqueue(synthetic_draw)
	await _settle(.2)
	presenter.world.motion_enabled = false
	await _settle(.15)
	if not _check(not transfer.is_busy() and transfer.moving.is_empty() and battle.get("_hand_scroll").modulate.a == 1,"reduced_motion_cleans_batch_and_restores_hand"): return
	presenter.world.motion_enabled = true
	var synthetic_return: Array[Dictionary] = [{"mine":true,"count":12,"direction":"return"}]
	transfer.enqueue(synthetic_return)
	await _settle(.2)
	get_tree().root.size = Vector2i(1440,900)
	await _settle(.2)
	if not _check(not transfer.is_busy() and battle.get("_hand_scroll").modulate.a == 1,"resize_cancels_transfers_safely"): return
	print("ARENA_SEARCH_CHOREOGRAPHY_PASS: real stadium, Nest Ball select/deselect/source/large details/scroll/disabled preview, four resolutions, Iono both players return/deal, correct resulting hands, single draw preserves existing hand, reduced-motion and resize cleanup")
	battle.call("_release_battle_runtime_resources")
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit()
