extends Node
## Explicit local packaging acceptance; only created by --arena-battle-smoke.
## Clicks go through the root Viewport so scene-order input regressions are visible.
var battle: Control
var failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	get_tree().create_timer(90).timeout.connect(func(): _fail("timeout"))
	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.selected_deck_ids.assign([575720, 575720])
	GameManager.first_player_choice = 0
	GameManager.ai_deck_strategy = "generic"
	battle = load("res://scenes/battle/BattleScene.tscn").instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	await _settle(.8)
	if "--arena-ac-checks" in OS.get_cmdline_user_args():
		get_tree().root.size = Vector2i(1920,1080)
		await _settle(.2)
	var opponent = battle.get("_ai_opponent")
	if opponent != null: opponent.use_mcts = false
	var gsm = battle.get("_gsm")
	var gs: GameState = gsm.game_state
	# Resolve any naturally occurring initial mulligans through visible controls.
	for step in range(30):
		if battle.get("_pending_choice") == "setup_active_0": break
		if battle.get("_pending_choice") == "mulligan_extra_draw" and battle.get("_dialog_overlay").is_visible_in_tree():
			await _click_control(_choice(battle.get("_dialog_overlay"), "dialog_text_choice_index", 1), "natural_mulligan")
		await _settle(.2)
	if not _check(battle.get("_pending_choice") == "setup_active_0", "initial_active_prompt"): return
	# Deterministic fixture: grant the player's legal one-card mulligan choice.
	# Exercise the real resolver and assert the deck/hand delta, independent of shuffle.
	gsm.set("_pending_mulligan_beneficiary_index", 0)
	gsm.get("_mulligan_counts")[1] = 1
	var hand_count: int = gs.players[0].hand.size()
	var deck_count: int = gs.players[0].deck.size()
	gsm.player_choice_required.emit("mulligan_extra_draw", {"beneficiary": 0, "mulligan_count": 1})
	await _settle(.4)
	await _capture("arena-hud-mulligan.png")
	# Current main auto-resolves this engine window and shows a nonblocking notice.
	if not _check(battle.has_node("MulliganNotice"), "automatic_mulligan_notice"): return
	if not _check(gs.players[0].hand.size() == hand_count + 1 and gs.players[0].deck.size() == deck_count - 1, "mulligan_draw_exactly_one"): return
	if not _check(battle.get("_pending_choice") == "setup_active_0", "mulligan_advances_to_active"): return
	await _capture("arena-hud-active.png")
	await _click_control(_choice(battle.get("_dialog_overlay"), "dialog_choice_index", 0), "setup_active")
	if not _check(gs.players[0].active_pokemon != null, "active_selected"): return
	for step in range(50):
		if gs.phase == GameState.GamePhase.MAIN and gs.current_player_index == 0: break
		if battle.get("_pending_choice") == "setup_bench_0":
			await _click_control(_visible_button(battle.get("_dialog_utility_row")), "finish_bench")
		await _settle(.2)
	if not _check(gs.phase == GameState.GamePhase.MAIN and gs.current_player_index == 0, "setup_complete"): return
	var presenter = battle.get_node_or_null("Arena3DPresenter")
	if not _check(presenter != null, "presenter_exists"): return
	await _settle(.4)
	await _click_card(presenter, "my_active")
	if not _check(battle.get("_pending_choice") == "pokemon_action", "world_click_opens_actions"): return
	await _click_control(battle.get("_dialog_cancel"), "action_cancel")
	if not _check(not battle.get("_dialog_overlay").visible, "action_cancel_closes"): return
	await _click_card(presenter, "my_active", MOUSE_BUTTON_RIGHT)
	if not _check(battle.get("_detail_overlay").visible, "card_detail_opens"): return
	await _capture("detail.png")
	# A covered arena button must not fire through the detail modal.
	var turn: int = gs.turn_number
	await _click_point(presenter.end_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT, "modal_blocks_end_turn")
	if not _check(gs.turn_number == turn and battle.get("_detail_overlay").visible, "detail_blocks_board"): return
	await _click_control(battle.get("_detail_close_btn"), "detail_close")
	if not _check(not battle.get("_detail_overlay").visible, "detail_closed"): return
	# Exercise the existing multi-select popup's select and confirm controls.
	battle.set("_pending_choice", "arena_hud_fixture")
	battle.call("_show_dialog", "HUD 多选输入回归", ["选项一", "选项二"], {"min_select": 1, "max_select": 2})
	await _settle(.4)
	await _click_control(_choice(battle.get("_dialog_overlay"), "dialog_text_choice_index", 0), "multi_select")
	if not _check(not battle.get("_dialog_confirm").disabled, "confirm_enabled"): return
	await _click_control(battle.get("_dialog_confirm"), "multi_confirm")
	if not _check(not battle.get("_dialog_overlay").visible, "confirm_closes"): return
	# Field selection retains 3D picking while its floating buttons stay clickable.
	battle.set("_pending_choice", "arena_hud_fixture")
	battle.call("_show_field_slot_choice", "场上目标输入回归", [gs.players[0].active_pokemon], {"min_select": 1, "max_select": 2, "allow_cancel": true})
	await _settle(.4)
	if "--arena-ac-checks" in OS.get_cmdline_user_args():
		var local: Vector2 = presenter.world.camera.unproject_position(presenter.world.cards.my_active.node.position)
		var point: Vector2 = presenter.get_global_transform() * local
		var press := InputEventMouseButton.new()
		press.position = point
		press.global_position = point
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		get_tree().root.push_input(press, true)
		await get_tree().process_frame
		battle.call("_show_field_slot_choice", "替换后的同目标窗口", [gs.players[0].active_pokemon], {"min_select": 1, "max_select": 2, "allow_cancel": true})
		var release := press.duplicate()
		release.pressed = false
		get_tree().root.push_input(release, true)
		await _settle(.2)
		if not _check(battle.get("_field_interaction_selected_indices").is_empty(), "replaced_window_rejects_mouse_release"): return
	await _click_card(presenter, "my_active")
	if not _check(battle.get("_field_interaction_selected_indices").size() == 1, "field_target_selected"): return
	await _capture("target.png")
	if "--arena-ac-checks" in OS.get_cmdline_user_args():
		var before_settings := JSON.stringify(presenter.last_frame)
		var before_selection: Array = battle.get("_field_interaction_selected_indices").duplicate()
		await _click_control(presenter.settings_button, "settings_during_target")
		if not _check(presenter.theme_id == "grove" and JSON.stringify(presenter.last_frame) == before_settings and battle.get("_field_interaction_selected_indices") == before_selection, "settings_preserve_state_and_selection"): return
		await _click_control(presenter.settings_button, "close_settings")
	await _click_control(battle.get("_field_interaction_clear_btn"), "field_clear")
	if not _check(battle.get("_field_interaction_selected_indices").is_empty(), "field_target_cleared"): return
	await _click_card(presenter, "my_active")
	await _click_control(battle.get("_field_interaction_confirm_btn"), "field_confirm")
	if not _check(not battle.call("_is_field_interaction_active"), "field_confirm_closes"): return
	battle.set("_pending_choice", "arena_hud_fixture")
	battle.call("_show_field_slot_choice", "场上目标取消回归", [gs.players[0].active_pokemon], {"min_select": 1, "max_select": 2, "allow_cancel": true})
	await _settle(.4)
	await _click_control(battle.get("_field_interaction_cancel_btn"), "field_cancel")
	if not _check(not battle.call("_is_field_interaction_active"), "field_cancel_closes"): return
	if "--arena-product-checks" in OS.get_cmdline_user_args():
		battle.set("_pending_choice", "")
		await load("res://scripts/tools/ArenaProductInputChecks.gd").run(self,battle,presenter)
		if failed: return
	# Prize UI fixture: the first new button overlaps the invisible legacy
	# opponent-discard hit region. Assert the actual rule transaction occurs.
	gsm.set("_pending_prize_player_index", 0)
	gsm.set("_pending_prize_remaining", 1)
	gsm.set("_pending_prize_resume_mode", "resume_main")
	gsm.player_choice_required.emit("take_prize", {"player": 0, "count": 1})
	await _settle(.4)
	var before_prizes: int = gs.players[0].prizes.size()
	var before_hand: int = gs.players[0].hand.size()
	if presenter.board_hud.get("prize_ready") != null:
		if not _check(presenter.board_hud.prize_ready and presenter.world.dynamics.reward_ready,"prize_prompt_has_visual_focus"): return
		if not _check(presenter.prize_buttons[0].size.x >= 44,"reward_pointer_target_size"): return
	await _capture("arena-reward-focus.png")
	await _click_control(presenter.prize_buttons[0], "first_prize_over_old_discard")
	if not _check(not battle.get("_discard_overlay").visible, "prize_does_not_open_discard"): return
	if not _check(gs.players[0].prizes.size() == before_prizes - 1 and gs.players[0].hand.size() == before_hand + 1, "prize_enters_hand"): return
	var drain: Control = battle.get("_modal_pointer_drain_shield")
	if not _check(drain == null or not drain.visible, "prize_release_finishes_pointer_drain"): return
	await _settle(.5)
	for name: String in ["LblPhase", "LblTurn", "BtnOpponentHand", "BtnBack"]:
		var top_control := battle.find_child(name,true,false) as Control
		if not _check(top_control != null and top_control.get_global_rect().position.y >= 0 and top_control.get_global_rect().end.y <= 58,"top_bar_visible_"+name): return
	await _capture("arena-package-battle.png")
	print("ARENA_END_TURN_BEFORE ",JSON.stringify({"turn":gs.turn_number,"phase":gs.phase,"pending":battle.get("_pending_choice"),"disabled":presenter.end_button.disabled,"ready":battle.call("_can_view_player_start_turn_action"),"busy":presenter.motion.is_busy()}))
	await _click_control(presenter.end_button, "end_turn")
	await _settle(1)
	if gs.turn_number <= turn:
		print("ARENA_END_TURN_AFTER ",JSON.stringify({"turn":gs.turn_number,"phase":gs.phase,"pending":battle.get("_pending_choice"),"disabled":presenter.end_button.disabled,"ready":battle.call("_can_view_player_start_turn_action"),"busy":presenter.motion.is_busy(),"field":battle.call("_is_field_interaction_active")}))
		await _capture("arena-end-turn-failed.png")
	if not _check(gs.turn_number > turn, "turn_advanced"): return
	print("ARENA_PACKAGE_SMOKE_PASS: viewport mouse input; mulligan +1, Active, setup, 3D pick, cancel, detail, modal blocking, multi-select confirm, field clear/confirm/cancel, prize into hand, next turn; template=", OS.has_feature("template"))
	battle.call("_release_battle_runtime_resources")
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _choice(node: Node, key: String, index: int) -> Control:
	if node is Control and not node.is_visible_in_tree(): return null
	if node is Control and int(node.get_meta(key, -1)) == index: return node
	for child in node.get_children():
		var target := _choice(child, key, index)
		if target != null: return target
	return null

func _visible_button(node: Node) -> Button:
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree() and not child.disabled: return child
	return null

func _click_control(control: Control, label: String) -> void:
	if not _check(control != null and control.is_visible_in_tree(), label + "_visible"): return
	await _click_point(control.get_global_rect().get_center(), MOUSE_BUTTON_LEFT, label, control)

func _click_card(presenter: Control, slot_id: String, button: int = MOUSE_BUTTON_LEFT) -> void:
	var local: Vector2 = presenter.world.camera.unproject_position(presenter.world.cards[slot_id].node.position)
	if not _check(presenter.world.hit_slot(local) == slot_id, "perspective_pick_" + slot_id): return
	await _click_point(presenter.get_global_transform() * local, button, slot_id, presenter)

func _click_point(point: Vector2, button: int, label: String, expected: Control = null) -> void:
	var root := get_tree().root
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var hovered := root.gui_get_hovered_control()
	print("ARENA_GUI_CLICK ", label, " -> ", hovered.get_path() if hovered else "none")
	# The current pointer drain deliberately shields orphan motion/releases.
	# A new physical press releases it synchronously before normal GUI picking.
	var drain_pending := hovered != null and hovered.name == "ModalPointerDrainShield"
	if expected != null and not drain_pending and not _check(hovered != null and (hovered == expected or expected.is_ancestor_of(hovered)), label + "_input_owner"): return
	for pressed in [true, false]:
		# A native window can report its desktop cursor between frames. Restore
		# this test pointer before each edge so the release belongs to the same
		# actual Viewport target as the press, including while recording movies.
		root.push_input(motion, true)
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.button_mask = (MOUSE_BUTTON_MASK_RIGHT if button == MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_LEFT) if pressed else 0
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		motion.button_mask = event.button_mask
		if pressed and drain_pending and expected != null:
			root.push_input(motion, true)
			hovered = root.gui_get_hovered_control()
			if not _check(hovered != null and (hovered == expected or expected.is_ancestor_of(hovered)), label + "_input_owner_after_new_press"): return
		await get_tree().process_frame
	await _settle(.35)

func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var prefix := ""
	if "--arena-ac-checks" in OS.get_cmdline_user_args():
		prefix = "ac-" + str(battle.get_node("Arena3DPresenter").theme_id) + "-"
	get_viewport().get_texture().get_image().save_png("user://" + prefix + filename)

func _check(condition: bool, label: String) -> bool:
	if not condition: _fail(label)
	return condition and not failed

func _fail(reason: String) -> void:
	failed = true
	push_error("ARENA_PACKAGE_SMOKE_FAIL: " + reason)
	get_tree().quit(1)
