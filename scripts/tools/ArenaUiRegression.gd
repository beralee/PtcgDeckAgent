extends "res://scripts/tools/ArenaKnockoutAcceptance.gd"
## Synthetic fixtures only. Decisions are made through root Viewport input.
var case_id := "prize_overlays"
var checks: Array[String] = []
var started := 0
var report_written := false
var presenter: Control
var gsm: GameStateMachine
var gs: GameState

func _run() -> void:
	started = Time.get_ticks_msec()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ui-case="): case_id = arg.trim_prefix("--ui-case=")
	get_tree().create_timer(75).timeout.connect(func(): _fail("scenario_timeout"))
	seed(260926)
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER if case_id == "replacement" else GameManager.GameMode.VS_AI
	GameManager.selected_deck_ids.assign([575720,575720])
	GameManager.first_player_choice = 0
	GameManager.ai_deck_strategy = "generic"
	battle = load("res://scenes/battle/BattleScene.tscn").instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	get_tree().root.size = Vector2i(1600,900)
	await _settle(1)
	gsm = battle.get("_gsm")
	gs = gsm.game_state
	presenter = battle.get_node("Arena3DPresenter")
	presenter.world.motion_enabled = true
	presenter.motion.fast_enabled = false
	if case_id in ["setup","mulligan"]:
		await _opening()
	else:
		gs = _public_fixture()
		gsm.game_state = gs
		for pi in range(2):
			while gsm.count_player_total_cards(pi) < 60: gs.players[pi].deck.append(CardInstance.create(CardDatabase.get_card("CSVE1C","DAR"),pi))
		battle.set("_pending_choice","")
		battle.get("_dialog_overlay").hide()
		battle.get("_handover_panel").hide()
		battle.get("_arena_hand_observer").prime(gs,0)
		presenter.motion.clear()
		battle.call("_refresh_ui")
		await _settle(.5)
		match case_id:
			"prize_overlays", "replacement", "stadium_detail": await _knockout()
			"search": await _search()
			"hand_resume": await _hand_resume()
			_: _fail("unknown_case")
	if failed: return
	await _finish(true,"")

func _opening() -> void:
	for i in range(30):
		if battle.get("_pending_choice") == "setup_active_0": break
		if battle.get("_pending_choice") == "mulligan_extra_draw":
			await _click_control(_choice(battle.get("_dialog_overlay"),"dialog_text_choice_index",0),"natural_mulligan_zero")
		await _settle(.1)
	if not _check(battle.get("_pending_choice") == "setup_active_0","opening_reaches_required_active"): return
	if case_id == "mulligan":
		gsm.set("_pending_mulligan_beneficiary_index",0)
		gsm.get("_mulligan_counts")[1] = 1
		var hand_count := gs.players[0].hand.size()
		gsm.player_choice_required.emit("mulligan_extra_draw",{"beneficiary":0,"mulligan_count":1})
		await _settle(.2)
		await _exit_cancel_preserves_choice()
		if failed: return
		if not _check(battle.has_node("MulliganNotice"),"automatic_mulligan_notice"): return
		if not _check(gs.players[0].hand.size() == hand_count+1,"mulligan_resolves_once"): return
		gsm.player_choice_required.emit("mulligan_extra_draw",{"beneficiary":0,"mulligan_count":1})
		if not _check(gs.players[0].hand.size() == hand_count+1,"stale_mulligan_does_not_redraw"): return
	await _exit_cancel_preserves_choice()
	if failed: return
	await _click_control(_choice(battle.get("_dialog_overlay"),"dialog_choice_index",0),"choose_active")
	if not _check(gs.players[0].active_pokemon != null,"active_choice_commits"): return
	for i in range(50):
		if gs.phase == GameState.GamePhase.MAIN: break
		if battle.get("_pending_choice") == "setup_bench_0":
			await _exit_cancel_preserves_choice()
			if failed: return
			await _click_control(_visible_button(battle.get("_dialog_utility_row")),"finish_setup")
		await _settle(.1)
	_check(gs.phase == GameState.GamePhase.MAIN,"setup_reaches_main")

func _exit_cancel_preserves_choice() -> void:
	var before := str(battle.get("_pending_choice"))
	# Covered background controls are expected to be blocked by mandatory modals.
	await _click_point(battle.get("_btn_back").get_global_rect().get_center(),MOUSE_BUTTON_LEFT,"exit_during_"+before)
	if battle.get("_pending_choice") == "confirm_exit":
		await _click_control(_choice(battle.get("_dialog_overlay"),"dialog_text_choice_index",1),"cancel_exit")
	_check(battle.get("_pending_choice") == before,"exit_does_not_erase_"+before)

func _knockout() -> void:
	if case_id == "stadium_detail":
		await _click_card(presenter,"stadium",MOUSE_BUTTON_RIGHT)
		if not _check(battle.get("_detail_overlay").visible and battle.get("_pending_choice") == "","stadium_right_click_is_read_only"): return
		await _click_control(battle.get("_detail_close_btn"),"close_stadium_detail")
	await _click_card(presenter,"my_active")
	await _click_control(_find_attack(battle.get("_dialog_overlay")),"attack")
	await _settle(1.4)
	if not _check(gs.players[1].active_pokemon == null and battle.get("_pending_choice") == "take_prize","actual_knockout_requests_prize"): return
	await _exit_cancel_preserves_choice()
	if failed: return
	# Knockout cues now have species-specific durations. Keep cancellation
	# coverage during the cue, then require the real prize input to become ready
	# within a bounded deadline instead of clicking through an active animation.
	var deadline := Time.get_ticks_msec() + 8000
	print("ARENA_PRIZE_WAIT ",JSON.stringify({"busy":presenter.motion.is_busy(),"remaining_seconds":presenter.motion.busy_time,"prize_visible":presenter.prize_buttons[0].is_visible_in_tree()}))
	while Time.get_ticks_msec() < deadline and (presenter.motion.is_busy() or not presenter.prize_buttons[0].is_visible_in_tree()):
		await _settle(.05)
	if not _check(not presenter.motion.is_busy() and presenter.prize_buttons[0].is_visible_in_tree() and battle.get("_pending_choice") == "take_prize","knockout_releases_prize_input_within_deadline"): return
	if case_id == "stadium_detail":
		await _click_card(presenter,"stadium")
		if not _check(battle.get("_detail_overlay").visible and battle.get("_pending_choice") == "take_prize","stadium_readable_while_waiting_for_prize"): return
		await _click_control(battle.get("_detail_close_btn"),"close_stadium_during_prize")
	if case_id == "prize_overlays":
		var prizes_before := gs.players[0].prizes.size()
		# The six-card picker now covers Active. A right click there belongs to
		# the picker; inspect an exposed bench card for the nested detail check.
		await _click_card(presenter,"my_active",MOUSE_BUTTON_RIGHT)
		if not _check(not battle.get("_detail_overlay").visible and gs.players[0].prizes.size() == prizes_before,"picker_blocks_covered_active_without_taking_prize"): return
		await _click_card(presenter,"my_bench_0",MOUSE_BUTTON_RIGHT)
		if not _check(battle.get("_detail_overlay").visible,"detail_during_prize"): return
		await _click_point(presenter.prize_buttons[0].get_global_rect().get_center(),MOUSE_BUTTON_LEFT,"blocked_prize_under_detail")
		if not _check(gs.players[0].prizes.size() == prizes_before,"detail_blocks_prize_clickthrough"): return
		await _click_control(battle.get("_detail_close_btn"),"close_detail")
		if not _check(battle.get("_pending_choice") == "take_prize","detail_preserves_prize_prompt"): return
		await _click_control(presenter.zone_buttons.opp_discard,"open_discard")
		if not _check(battle.get("_discard_overlay").visible,"discard_during_prize"): return
		await _click_control(battle.get("_discard_close_btn"),"close_discard")
		await _click_control(presenter.settings_button,"settings_during_prize")
		await _click_control(presenter.settings_button,"close_settings_during_prize")
		get_tree().root.size = Vector2i(1280,720)
		await _settle(.4)
		if not _check(presenter.board_hud.prize_ready,"resize_and_settings_preserve_prize"): return
	var count := gs.players[0].prizes.size()
	await _click_control(presenter.prize_buttons[0],"take_prize")
	if not _check(gs.players[0].prizes.size() == count-1,"one_prize_committed"): return
	if case_id == "replacement":
		await _settle(.6)
		if battle.get("_handover_panel").visible: await _click_control(battle.get("_handover_btn"),"handover_to_defender")
		await _settle(.4)
		if not _check(battle.get("_pending_choice") == "send_out","human_replacement_required"): return
		await _exit_cancel_preserves_choice()
		if failed: return
		await _click_card(presenter,"my_bench_0")
		if battle.get("_field_interaction_confirm_btn").is_visible_in_tree(): await _click_control(battle.get("_field_interaction_confirm_btn"),"confirm_replacement")
	for i in range(70):
		if gs.players[1].active_pokemon != null and gs.turn_number > 9: break
		await _settle(.1)
	_check(gs.players[1].active_pokemon != null and gs.turn_number > 9,"replacement_and_next_turn")

func _search() -> void:
	var nest: CardData
	for cd: CardData in CardDatabase.get_all_cards():
		if cd.display_name() == "巢穴球": nest = cd; break
	var ball := CardInstance.create(nest,0)
	gs.players[0].hand[0] = ball
	gs.players[0].deck[0] = CardInstance.create(CardDatabase.get_card("CSV9.5C","004"),0)
	battle.call("_refresh_ui")
	battle.get("_arena_hand_observer").prime(gs,0)
	await _settle(.3)
	for view in battle.get("_hand_container").get_children():
		if view is BattleCardView and view.card_instance == ball:
			await _click_control(view,"play_nest_ball")
			break
	var use := _named_button(battle,"使用")
	if use != null: await _click_control(use,"use_nest_ball")
	await _settle(.4)
	if not _check(battle.get("_dialog_library_search_board_mode"),"search_opened"): return
	var row: HBoxContainer = battle.get("_dialog_library_search_board").find_child("LibraryCardRow",true,false)
	var candidate: Control
	for child in row.get_children():
		if int(child.get_meta("dialog_choice_index",-1)) >= 0: candidate = child; break
	if not _check(candidate != null,"search_has_candidate"): return
	await _click_control(candidate,"select_search_candidate")
	await _exit_cancel_preserves_choice()
	if failed: return
	if not _check(battle.get("_dialog_card_selected_indices").size() == 1,"search_selection_preserved"): return
	var bench_count := gs.players[0].bench.size()
	await _click_control(battle.get("_dialog_confirm"),"confirm_search")
	await _settle(1.5)
	_check(gs.players[0].bench.size() == bench_count+1 and ball in gs.players[0].discard_pile and battle.get("_pending_choice") == "","search_commits_and_returns_control")

func _named_button(node: Node, value: String) -> Button:
	if node is Button and node.is_visible_in_tree() and node.text == value: return node
	for child in node.get_children():
		var found := _named_button(child,value)
		if found != null: return found
	return null

func _hand_resume() -> void:
	var iono: CardData
	for cd: CardData in CardDatabase.get_all_cards():
		if cd.display_name() == "奇树": iono = cd; break
	var card := CardInstance.create(iono,0)
	gs.players[0].hand[0] = card
	battle.call("_refresh_ui")
	battle.get("_arena_hand_observer").prime(gs,0)
	await _settle(.3)
	for view in battle.get("_hand_container").get_children():
		if view is BattleCardView and view.card_instance == card:
			await _click_control(view,"play_iono")
			break
	var use := _named_button(battle,"使用")
	if use != null: await _click_control(use,"use_iono")
	if not _check(presenter.motion.is_busy(),"real_iono_animation_started"): return
	# Change the logical layout during a live transfer. An equal-aspect physical
	# resize preserves the 900-unit canvas and legitimately keeps its animation.
	var size_before := get_tree().root.size
	var canvas_before := battle.size
	get_tree().root.size = Vector2i(1280,800)
	await _settle(.4)
	print("ARENA_HAND_RESIZE ", JSON.stringify({"before":str(size_before),"after":str(get_tree().root.size),"battle":str(battle.size),"motion":str(presenter.motion.size),"transfer":str(presenter.motion.hand_transfer.size),"busy":presenter.motion.is_busy(),"alpha":battle.get("_hand_scroll").modulate.a}))
	if not _check(battle.size != canvas_before,"resize_changes_logical_layout"): return
	if not _check(gs.players[0].hand.size() == 6 and gs.players[1].hand.size() == 5 and card in gs.players[0].discard_pile,"iono_rule_transaction_complete"): return
	if not _check(not presenter.motion.is_busy() and battle.get("_hand_scroll").modulate.a == 1,"resize_releases_motion_and_restores_hand"): return
	await _exit_cancel_preserves_choice()
	if failed: return
	await _click_control(presenter.end_button,"end_turn_after_resize")
	for i in range(35):
		if gs.turn_number > 9: break
		await _settle(.1)
	_check(gs.turn_number > 9,"hand_animation_interruption_does_not_stall_turn")

func _check(condition: bool, label: String) -> bool:
	if failed: return false
	checks.append(label)
	if not condition: _fail(label)
	return condition

func _fail(reason: String) -> void:
	if failed or report_written: return
	failed = true
	call_deferred("_finish",false,reason)

func _finish(passed: bool, reason: String) -> void:
	if report_written: return
	report_written = true
	var folder := OS.get_environment("ARENA_UI_ARTIFACT_DIR")
	if folder.is_empty(): folder = ProjectSettings.globalize_path("user://ui-regression")
	DirAccess.make_dir_recursive_absolute(folder)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder.path_join("result.png"))
	var report := {"case":case_id,"passed":passed,"reason":reason,"checks":checks,"elapsed_ms":Time.get_ticks_msec()-started,"fixture":true,"input":"Viewport mouse","phase":gs.phase if gs != null else -1,"turn":gs.turn_number if gs != null else -1,"pending":str(battle.get("_pending_choice")) if is_instance_valid(battle) else ""}
	if is_instance_valid(presenter):
		report["presentation"] = {"busy":presenter.motion.is_busy(),"remaining_seconds":presenter.motion.busy_time,"prize_visible":presenter.prize_buttons[0].is_visible_in_tree()}
	var file := FileAccess.open(folder.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("ARENA_UI_RESULT ",JSON.stringify(report))
	if is_instance_valid(battle):
		battle.call("_release_battle_runtime_resources")
		battle.queue_free()
		await get_tree().process_frame
	get_tree().quit(0 if passed else 1)
