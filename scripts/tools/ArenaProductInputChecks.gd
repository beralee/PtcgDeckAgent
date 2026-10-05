extends RefCounted
## Deterministic fixture, actual Viewport mouse events, existing rule transactions.
static func run(checks: Node, battle: Control, presenter: Control) -> void:
	# Opponent prize windows belong to the AI, never to the local player's HUD.
	var previous_prompt: String = battle.get("_pending_choice")
	var previous_prize: int = battle.get("_pending_prize_player_index")
	battle.set("_pending_choice","take_prize")
	battle.set("_pending_prize_player_index",1-int(battle.get("_view_player")))
	presenter._refresh()
	var opponent_buttons_hidden := true
	for button in presenter.prize_buttons:
		opponent_buttons_hidden = opponent_buttons_hidden and not button.visible
	battle.set("_pending_choice",previous_prompt)
	battle.set("_pending_prize_player_index",previous_prize)
	presenter._refresh()
	if not checks._check(opponent_buttons_hidden,"opponent_prizes_not_human_controls"): return
	var gs: GameState = battle.get("_gsm").game_state
	var player: PlayerState = gs.players[0]
	var energy: CardInstance
	for card in player.hand + player.deck:
		if card.card_data.card_type == "Basic Energy":
			energy = card
			break
	if not checks._check(energy != null,"drag_fixture_energy_exists"): return
	if energy not in player.hand:
		player.deck.erase(energy)
		player.hand.append(energy)
	battle.call("_refresh_ui")
	await checks._settle(.3)
	var view: Control
	for card in battle.get("_hand_container").get_children():
		if card is BattleCardView and card.card_instance == energy: view = card
	if not checks._check(view != null,"drag_card_view_exists"): return
	battle.get("_hand_scroll").ensure_control_visible(view)
	await checks._settle(.4)
	var before_hand := player.hand.size()
	var before_energy := player.active_pokemon.attached_energy.size()
	var start := view.get_global_rect().get_center()
	var at: Vector2 = presenter.get_global_transform() * presenter.world.camera.unproject_position(presenter.world.cards.my_active.node.position)
	await drag(checks,start,Vector2(start.x,5))
	if not checks._check(player.hand.size() == before_hand and player.active_pokemon.attached_energy.size() == before_energy,"offboard_drag_cancels"): return
	var enemy: Vector2 = presenter.get_global_transform() * presenter.world.camera.unproject_position(presenter.world.cards.opp_active.node.position)
	await drag(checks,start,enemy)
	if not checks._check(player.hand.size() == before_hand and player.active_pokemon.attached_energy.size() == before_energy,"opponent_drop_cancels"): return
	await drag(checks,start,at,func():
		battle.set("_pending_choice","arena_drag_replacement")
		battle.call("_show_field_slot_choice","操作窗口已更新",[player.active_pokemon],{"min_select":1,"max_select":1,"allow_cancel":true})
	)
	if not checks._check(player.hand.size() == before_hand and player.active_pokemon.attached_energy.size() == before_energy,"stale_drag_rejected"): return
	await checks._click_control(battle.get("_field_interaction_cancel_btn"),"cancel_replaced_drag_window")
	battle.set("_pending_choice","")
	await checks._settle(.5)
	start = view.get_global_rect().get_center()
	await drag(checks,start,at)
	if not checks._check(player.hand.size() == before_hand-1 and player.active_pokemon.attached_energy.size() == before_energy+1,"drag_attaches_energy_once"): return
	print("ARENA_PRODUCT_DRAG_PASS: offboard/opponent cancel; replaced window rejection; hand-to-active energy through Viewport")
	# Explicit replacement fixture, separate from recorded natural matches.
	# Preserve the same Pokémon and attachments; simulate the empty Active slot
	# after knockout, then require a real bench click to invoke the legal owner.
	var replacement: PokemonSlot = player.active_pokemon
	player.active_pokemon = null
	player.bench.append(replacement)
	var gsm = battle.get("_gsm")
	gsm.set("_knockout_return_to_main",true)
	gsm.player_choice_required.emit("send_out_pokemon",{"player":0})
	battle.call("_refresh_ui")
	await checks._settle(.4)
	if not checks._check(str(battle.get("_pending_choice")) == "send_out","replacement_prompt_exists"): return
	var bench_index := player.bench.find(replacement)
	await checks._click_card(presenter,"my_bench_%d" % bench_index)
	if player.active_pokemon == null:
		await checks._click_control(battle.get("_field_interaction_confirm_btn"),"confirm_replacement")
	if not checks._check(player.active_pokemon == replacement and replacement not in player.bench,"replacement_through_viewport"): return
	print("ARENA_PRODUCT_REPLACEMENT_PASS: empty Active -> legal bench -> main through Viewport")
	# A search refresh must never put its pointer layer above an open detail.
	battle.set("_pending_choice","arena_detail_search_fixture")
	battle.call("_show_dialog","检索窗口详情遮挡回归",["选择一张牌"],{"min_select":1,"max_select":1,"allow_cancel":true})
	battle.call("_show_card_detail",replacement.get_top_card().card_data)
	battle.call("_raise_dialog_overlay_for_input")
	await checks._settle(.3)
	await checks._click_control(battle.get("_detail_close_btn"),"close_detail_over_refreshed_search")
	if checks.failed: return
	if not checks._check(not battle.get("_detail_overlay").visible and battle.get("_dialog_overlay").visible,"detail_closes_without_touching_search"): return
	await checks._click_control(battle.get("_dialog_cancel"),"cancel_underlying_search_fixture")
	battle.set("_pending_choice","")
	print("ARENA_PRODUCT_MODAL_STACK_PASS: detail close remains above refreshed search through Viewport")

static func drag(checks: Node, start: Vector2, finish: Vector2, interrupt: Callable = Callable()) -> void:
	var root: Window = checks.get_tree().root
	var motion := InputEventMouseMotion.new()
	motion.position = start
	motion.global_position = start
	root.push_input(motion,true)
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.button_mask = MOUSE_BUTTON_MASK_LEFT
	button.pressed = true
	button.position = start
	button.global_position = start
	root.push_input(button,true)
	await checks.get_tree().process_frame
	for t in [.2,.5,.8,1.0]:
		motion = InputEventMouseMotion.new()
		motion.position = start.lerp(finish,t)
		motion.global_position = motion.position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion,true)
		await checks.get_tree().process_frame
		if t == .5 and interrupt.is_valid():
			interrupt.call()
			await checks._settle(.1)
	button = button.duplicate()
	button.pressed = false
	button.button_mask = 0
	button.position = finish
	button.global_position = finish
	root.push_input(button,true)
	await checks._settle(.4)
