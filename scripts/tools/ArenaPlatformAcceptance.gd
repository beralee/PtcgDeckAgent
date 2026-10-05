extends "res://scripts/tools/ArenaKnockoutAcceptance.gd"
## Viewport touch regression. Fixtures contain only synthetic/public cards.
var p: Control
var tested_window := Vector2i.ZERO

func _run() -> void:
	get_tree().create_timer(180).timeout.connect(func(): _fail("platform_timeout"))
	GameManager.battle_3d_enabled = true
	GameManager.battle_effects_enabled = false
	preload("res://scenes/arena3d/ArenaTheme.gd").save_option("motion",true)
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.selected_deck_ids.assign([575720,575720])
	GameManager.first_player_choice = 0
	battle = load("res://scenes/battle/BattleScene.tscn").instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	await _settle(1)
	var gsm = battle.get("_gsm")
	var gs := _public_fixture()
	gsm.game_state = gs
	battle.set("_pending_choice","")
	battle.get("_dialog_overlay").hide()
	var startup_notice := battle.get_node_or_null("MulliganNotice") as Control
	if startup_notice != null: startup_notice.hide()
	if battle.get("_handover_panel") != null: battle.get("_handover_panel").hide()
	battle.get("_arena_hand_observer").prime(gs,0)
	p = battle.get_node("Arena3DPresenter")
	if not _check(p.world.motion_enabled,"legacy_2d_off_does_not_disable_3d_models"): return
	p.motion.clear()
	p.world.motion_enabled = false
	p.quality_high = false
	p.world.configure_quality(true)
	battle.call("_refresh_ui")
	var test_sizes: Array = [get_tree().root.size] if OS.get_name() == "Android" else [Vector2i(720,1280),Vector2i(1280,720),Vector2i(390,844),Vector2i(768,1024)]
	for dimensions in test_sizes:
		await _resize(dimensions)
		tested_window = get_tree().root.size
		print("PLATFORM_GEOMETRY ", dimensions," battle=",battle.size," presenter=",p.size," board=",p.board_rect," render=",p.viewport.size)
		for path in ["MainArea","MainArea/CenterField","MainArea/CenterField/HandArea","MainArea/CenterField/HandArea/HandVBox","MainArea/CenterField/HandArea/HandVBox/HandScroll","MainArea/CenterField/FieldArea"]:
			var c: Control = battle.get_node(path)
			print("PLATFORM_CONTAINER ",path," rect=",c.get_rect()," min=",c.get_combined_minimum_size()," custom=",c.custom_minimum_size)
		await _capture("platform-%dx%d.png" % [dimensions.x,dimensions.y])
		if not _check_portrait_pile_clearance(): return
		if not _check(p.board_rect.size.y > 80 and p.size.x <= battle.size.x+1,"compact_board_fits"): return
		for button: Button in [p.menu_button,p.settings_button,p.log_button,p.end_button,p.stadium_button]+p.status_bar.buttons:
			if not button.visible: continue
			if not _check(Rect2(Vector2.ZERO,p.size).encloses(button.get_rect()),"button_inside_board_"+button.text): return
			if not _check(button.size.y >= 44,"touch_target_height"): return
		if p.platform_metrics.portrait:
			if not _check(p.board_rect.position.y >= p.status_bar.size.y and p.status_bar.visible and not p.menu_button.visible and not p.settings_button.visible and not p.log_button.visible and not p.stadium_button.visible,"portrait_has_five_entry_status_bar"): return
			var upper: Rect2 = p.world.side_zones.screen_rect("opp","discard")
			var lower: Rect2 = p.world.side_zones.screen_rect("my","discard")
			if not _check(p.end_button.get_rect().position.y > upper.end.y and p.end_button.get_rect().end.y < lower.position.y,"turn_button_between_side_piles"): return
			await _settle(.3)
			var draws := [0]
			var observe_draw := func(): draws[0] += 1
			p.board_hud.draw.connect(observe_draw)
			p.world.invalidate_render()
			await _settle(.1)
			p.board_hud.draw.disconnect(observe_draw)
			if not _check(draws[0] == 0,"unchanged_pile_labels_reuse_canvas_during_3d_redraw"): return
		for id: String in p.last_frame.slots:
			var point: Vector2 = p.world.project(p.world.cards[id].node.position)
			if not _check(p.world.hit_slot(point) == id,"scaled_ray_"+id): return
		if not _check(maxi(p.viewport.size.x,p.viewport.size.y) <= 1280 and not p.world.key.shadow_enabled,"low_quality_budget"): return
		var at := _card_point("my_active")
		await _touch(at,true)
		await _touch(at,false,true)
		if not _check(battle.get("_pending_choice") == "","cancel_does_not_open_action"): return
		await _touch(at,true)
		battle.set("_arena_input_generation",int(battle.get("_arena_input_generation"))+1)
		await _touch(at,false)
		if not _check(battle.get("_pending_choice") == "","stale_touch_does_not_open_action"): return
		await _touch(at,true)
		await _touch(at,false)
		if not _check(battle.get("_pending_choice") == "pokemon_action","touch_opens_existing_actions"): return
		if not _check(Rect2(Vector2.ZERO,battle.size).encloses(battle.get("_dialog_box").get_global_rect()),"rotated_action_dialog_inside_viewport"): return
		await _capture("platform-actions-%dx%d.png" % [dimensions.x,dimensions.y])
		# Modal controls continue through the inherited touch route.
		await _tap_control(battle.get("_dialog_cancel"))
		if not _check(not battle.get("_dialog_overlay").visible,"touch_cancel_closes_modal"): return
		await _settle(.3)
		_emulated_mouse(at,true)
		await _touch(at,true)
		await _settle(.65)
		_emulated_mouse(at,false)
		await _touch(at,false)
		if not _check(battle.get("_detail_overlay").visible and battle.get("_pending_choice") == "","long_press_inspects_without_action"): return
		await _tap_control(battle.get("_detail_close_btn"))
		if not _check(not battle.get("_detail_overlay").visible,"touch_detail_close"): return
		# Compact live controls have exactly the five requested entries.
		if not _check(p.status_bar.visible and p.status_bar.buttons.size() == 4,"five_entry_status_bar"): return
		for index in range(1,p.status_bar.buttons.size()):
			if not _check(not p.status_bar.buttons[index-1].get_global_rect().intersects(p.status_bar.buttons[index].get_global_rect()),"status_entries_do_not_overlap"): return
		p._open_compact_log()
		await _settle(.2)
		if not _check(p.compact_log.visible,"compact_log_opens"): return
		p.compact_log.hide()
		await _settle(.2)
		p.motion.busy_time = .3
		await _settle(.07)
		var layout_before: int = p.layout_revision
		p.motion.busy_time = 0
		await _settle(.10)
		if not _check(p.layout_revision == layout_before,"busy_end_does_not_relayout_unchanged_board"): return
	# A held animation must still reveal newly committed public damage on settle.
	p.motion.hold = .3
	var shown_hp: int = p.motion.shown.slots.my_active.hp
	gs.players[0].active_pokemon.damage_counters += 10
	battle.call("_refresh_ui")
	await _settle(.07)
	if not _check(int(p.motion.shown.slots.my_active.hp) == shown_hp,"held_public_frame_stays_until_settle"): return
	await _settle(.35)
	if not _check(int(p.motion.shown.slots.my_active.hp) == shown_hp-10,"settled_public_frame_reveals_committed_damage"): return
	await _resize(Vector2i(390,844))
	var coordinator = battle.get("_battle_drag_scroll_coordinator")
	var scroll: ScrollContainer = battle.get("_hand_scroll")
	print("PLATFORM_HAND_RANGE required=",coordinator._hand_drag_max_scroll(scroll)," actual=",scroll.get_h_scroll_bar().max_value-scroll.get_h_scroll_bar().page," content=",coordinator._hand_drag_content_width(battle.get("_hand_container"))," row=",battle.get("_hand_container").size)
	var hand_card: BattleCardView = battle.get("_hand_container").get_child(0)
	var hand_at: Vector2 = hand_card.get_global_transform()*(hand_card.size*.5)
	await _touch(hand_at,true)
	await _touch(hand_at,false)
	if not _check(battle.get("_selected_hand_card") != null,"touch_selects_hand_energy"): return
	var energies: int = gs.players[0].active_pokemon.attached_energy.size()
	await _touch(_card_point("my_active"),true)
	await _touch(_card_point("my_active"),false)
	if not _check(gs.players[0].active_pokemon.attached_energy.size() == energies+1,"touch_hand_target_attaches_once"): return
	await _settle(.5)
	# Cancellation and compatibility echoes around successive prize transactions.
	gsm.set("_pending_prize_player_index",0)
	gsm.set("_pending_prize_remaining",2)
	gsm.set("_pending_prize_resume_mode","resume_main")
	gsm.player_choice_required.emit("take_prize",{"player":0,"count":2})
	await _settle(.5)
	var before: int = gs.players[0].prizes.size()
	var prize_at: Vector2 = p.prize_buttons[0].get_global_rect().get_center()
	await _touch(prize_at,true)
	await _touch(prize_at,false,true)
	if not _check(gs.players[0].prizes.size() == before and battle.get("_prize_touch_press_contexts").is_empty(),"canceled_prize_is_cleared"): return
	for i in range(2):
		await _tap_control(p.prize_buttons[i])
		if not _check(gs.players[0].prizes.size() == before-i-1,"successive_touch_takes_one_prize"): return
		await _settle(.8)
	# The full-library window keeps its existing touch selection owner.
	battle.set("_pending_choice","arena_platform_search")
	var candidates: Array = gs.players[0].deck.slice(0,6)
	battle.call("_show_dialog","选择一张卡牌",candidates,{"presentation":"cards","visible_scope":"own_full_deck","card_items":candidates,"min_select":1,"max_select":1,"allow_cancel":true})
	await _settle(.5)
	if not _check(battle.get("_dialog_library_search_board_mode") and p.search_presentation.compact,"portrait_uses_touch_library_owner"): return
	var box: Control = battle.get("_dialog_box")
	await _capture("platform-search.png")
	if not _check(Rect2(Vector2.ZERO,battle.size).encloses(box.get_global_rect()),"search_fits_portrait"): return
	var row: Control = battle.get("_dialog_library_search_board").find_child("LibraryCardRow",true,false)
	await _tap_control(row.get_child(0))
	if not _check(battle.get("_dialog_card_selected_indices").size() == 1,"touch_search_selects_once"): return
	await _tap_control(battle.get("_dialog_cancel"))
	# Expanded public benches remain visible and independently pickable.
	gs.stadium_card = CardInstance.create(CardDatabase.get_card("CSV9C","207"),0)
	for pi in range(2):
		gs.players[pi].active_pokemon = _slot("CSV8C","135",pi)
		while gs.players[pi].bench.size() < 8: gs.players[pi].bench.append(_slot("CSV8C","135",pi))
	battle.call("_refresh_ui")
	await _settle(.6)
	var legacy_stadium: Control = battle.get("_stadium_card_view")
	if not _check(not is_instance_valid(legacy_stadium) or not legacy_stadium.is_visible_in_tree(),"legacy_stadium_cannot_overlay_arena"): return
	for pi in ["my","opp"]:
		for i in range(8):
			var id: String = pi+"_bench_%d"%i
			var local: Vector2 = p.world.project(p.world.cards[id].node.position)
			if not _check(p.board_rect.has_point(local) and p.world.hit_slot(local) == id,"expanded_portrait_bench_"+id): return
	await _capture("platform-eight-bench.png")
	if not _check_portrait_pile_clearance(): return
	if OS.get_name() != "Android":
		# Rotation with an unchanged public frame must still reflow all eight slots.
		for dimensions: Vector2i in [Vector2i(844,390),Vector2i(768,1024),Vector2i(390,844)]:
			await _resize(dimensions)
			if not _check_portrait_pile_clearance(): return
			for side: String in ["my","opp"]:
				for index in range(8):
					var id := side+"_bench_%d" % index
					var point: Vector2 = p.world.project(p.world.cards[id].node.position)
					if not _check(p.board_rect.has_point(point) and p.world.hit_slot(point) == id,"rotated_eight_bench_"+id): return
	if not await _check_committed_live_actions(): return
	print("ARENA_PLATFORM_ACCEPTANCE_PASS")
	battle.call("_release_battle_runtime_resources")
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _check_portrait_pile_clearance() -> bool:
	for side: String in ["my","opp"]:
		for kind: String in ["deck","discard"]:
			if not _check(not p.end_button.get_rect().intersects(p.board_hud.pile_counter_rect(side,kind)),"end_turn_clear_of_"+side+"_"+kind+"_count"): return false
	if not p.platform_metrics.portrait: return true
	# Include the printed cards and their status strip, not just their centers.
	for side: String in ["my","opp"]:
		var prize: Rect2 = p.board_hud.prize_rect(0,side == "my")
		prize = prize.merge(p.board_hud.prize_rect(5,side == "my"))
		var discard: Rect2 = p.world.side_zones.screen_rect(side,"discard")
		if not _check(p.zone_buttons[side+"_discard"].get_rect().has_point(discard.get_center()),"discard_touch_moves_with_eight_bench_"+side): return false
		prize = prize.merge(p.board_hud.prize_counter_rect(side == "my"))
		if p.world.cards.has("stadium"):
			var stadium: Rect2 = p.world.card_screen_rect("stadium")
			if not _check(not stadium.intersects(p.board_hud.prize_counter_rect(side == "my")),"prize_count_clear_of_stadium_"+side): return false
		for index in range(p.world.bench_counts[side]):
			var card: Rect2 = p.world.card_screen_rect(side+"_bench_%d" % index)
			if not _check(not card.intersects(prize),"prize_stack_and_count_clear_of_bench_"+side+str(index)): return false
			for kind: String in ["deck","discard"]:
				var pile: Rect2 = p.world.side_zones.screen_rect(side,kind).merge(p.board_hud.pile_counter_rect(side,kind))
				if not _check(not card.intersects(pile),kind+"_and_count_clear_of_bench_"+side+str(index)): return false
	return true

func _resize(dimensions: Vector2i) -> void:
	if OS.get_name() != "Android":
		get_tree().root.size = dimensions
		get_tree().root.content_scale_size = preload("res://scenes/arena3d/ArenaPlatform.gd").canvas_size(dimensions)
	await _settle(.3)
	GameManager.ui_runtime_profile = UiRuntimeProfile.new({"host_kind":"native","native_os":"android","mobile_like":true,"pointer_mode":"touch","performance_tier":"low"})
	battle.call("_configure_battle_pointer_runtime",GameManager.ui_runtime_profile)
	battle.get("_ios_web_hud_touch_adapter").configure(GameManager.ui_runtime_profile)
	# An inherited 2D portrait preference must not rotate or offset 3D modals.
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	battle.call("_apply_responsive_layout")
	await _settle(.7)

func _card_point(id: String) -> Vector2:
	return p.get_global_transform()*p.world.project(p.world.cards[id].node.position)

func _touch(at: Vector2, pressed: bool, canceled: bool = false, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.pressed = pressed
	event.canceled = canceled
	event.index = index
	get_tree().root.push_input(event,true)
	await _settle(.08)

func _emulated_mouse(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_EMULATION
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	get_tree().root.push_input(event,true)

func _tap_control(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	await _touch(at,true)
	await _touch(at,false)
	await _settle(.2)

func _live_fixture() -> GameState:
	var gs := GameState.new()
	gs.phase = GameState.GamePhase.MAIN
	gs.turn_number = 8
	gs.current_player_index = 0
	gs.first_player_index = 1
	for pi in range(2):
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _slot("CSV8C","159",pi)
		player.active_pokemon.attached_energy.append(CardInstance.create(CardDatabase.get_card("CSVE1C","DAR"),pi))
		var prizes: Array[CardInstance] = []
		for i in range(6): prizes.append(CardInstance.create(CardDatabase.get_card("CSVE1C","DAR"),pi))
		player.set_prizes(prizes)
		for i in range(52): player.deck.append(CardInstance.create(CardDatabase.get_card("CSVE1C","DAR"),pi))
		gs.players.append(player)
	return gs

func _install_live_fixture(gs: GameState) -> void:
	p.motion.clear()
	battle.get("_gsm").game_state = gs
	battle.set("_view_player",0)
	battle.set("_pending_choice","")
	battle.get("_dialog_overlay").hide()
	battle.get("_handover_panel").hide()
	battle.get("_arena_hand_observer").prime(gs,0)
	battle.call("_refresh_ui")
	await _settle(.8)

func _check_committed_live_actions() -> bool:
	var gsm: GameStateMachine = battle.get("_gsm")
	p.world.motion_enabled = true
	var gs := _live_fixture()
	await _install_live_fixture(gs)
	# No board/card action after a transient owner gate is released.
	battle.set("_ai_llm_waiting",true)
	await _settle(.2)
	if not _check(p.end_button.disabled,"end_turn_blocks_pending_owner"): return false
	battle.set("_ai_llm_waiting",false)
	await _settle(.2)
	if not _check(not p.end_button.disabled,"idle_turn_control_recovers_without_card_action"): return false
	var previous_turn := gs.turn_number
	print("IDLE_TURN_BEFORE ",JSON.stringify({"can_start":battle.call("_can_view_player_start_turn_action"),"target":p.touch_target(p.end_button.get_global_rect().get_center()).get("kind",""),"pending":battle.get("_pending_choice"),"busy":p.motion.is_busy(),"turn":gs.turn_number,"player":gs.current_player_index}))
	await _tap_control(p.end_button)
	print("IDLE_TURN_AFTER ",JSON.stringify({"can_start":battle.call("_can_view_player_start_turn_action"),"pending":battle.get("_pending_choice"),"busy":p.motion.is_busy(),"turn":gs.turn_number,"player":gs.current_player_index,"phase":gs.phase}))
	await _capture("platform-empty-turn-after-touch.png")
	if not _check(gs.turn_number > previous_turn or gs.current_player_index != 0,"touch_ends_turn_without_playing_any_card"): return false
	await _capture("platform-empty-turn-ended.png")
	gs = _live_fixture()
	gs.players[0].deck.pop_back()
	var research := CardInstance.create(CardDatabase.get_card("CSV1C","121"),0)
	gs.players[0].hand.append(research)
	await _install_live_fixture(gs)
	var played: int = p.world.supporter_vfx.played
	if not _check(gsm.play_trainer(0,research,[]),"real_supporter_commit"): return false
	if not _check(p.world.supporter_vfx.played == played+1 and p.world.supporter_vfx.last_outcome.id == "research","committed_supporter_reaches_character_director"): return false
	await _settle(.8)
	if not _check(not p.world.supporter_vfx.active.is_empty() and p.world.supporter_vfx.active.hero.is_visible_in_tree(),"live_supporter_character_visible"): return false
	await _capture("platform-live-supporter.png")
	await _settle(6)
	gs = _live_fixture()
	await _install_live_fixture(gs)
	var attacks: int = p.world.signature_vfx.played
	await _touch(_card_point("my_active"),true)
	await _touch(_card_point("my_active"),false)
	var attack := _find_attack(battle.get("_dialog_overlay"))
	if not _check(attack != null,"real_attack_choice_available"): return false
	await _tap_control(attack)
	await _settle(.5)
	if not _check(p.world.signature_vfx.played == attacks+1 and p.world.signature_vfx.last_outcome.species == "dragapult","touch_attack_triggers_3d_pokemon"): return false
	if not _check(not p.world.signature_vfx.sequences.is_empty(),"live_pokemon_sequence_present"): return false
	if not _check(not battle.get("_handover_panel").visible,"handover_does_not_cover_live_pokemon"): return false
	for node in p.motion.transient_nodes:
		if is_instance_valid(node) and node is Label:
			if not _check(not node.get_rect().intersects(p.status_bar.get_rect()),"attack_banner_clear_of_status_bar"): return false
	await _capture("platform-live-pokemon.png")
	await _settle(6)
	return true
