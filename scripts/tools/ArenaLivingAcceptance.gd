extends "res://scripts/tools/Arena3DSmoke.gd"
## Explicit real-card fixture; all stadium and bench transactions use Viewport input.
func _run() -> void:
	get_tree().create_timer(65).timeout.connect(func(): _fail("living_acceptance_timeout"))
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.selected_deck_ids.assign([575720,575720])
	GameManager.first_player_choice = 0
	battle = load("res://scenes/battle/BattleScene.tscn").instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	get_tree().root.size = Vector2i(1920,1080)
	await _settle(1)
	var gsm = battle.get("_gsm")
	var gs: GameState = gsm.game_state
	var tera: CardData
	var basic: CardData
	var energy: CardData
	for card: CardData in CardDatabase.get_all_cards():
		if tera == null and card.is_basic_pokemon() and card.is_tera_pokemon(): tera = card
		if card.display_name() == "雷公V": basic = card
		if card.card_type == "Basic Energy" and card.energy_provides == "L": energy = card
	var stadium: CardData = CardDatabase.get_card("CSV9C","207")
	if not _check(tera != null and basic != null and stadium != null,"real_cards_loaded"): return
	gs.phase = GameState.GamePhase.MAIN
	gs.turn_number = 3
	gs.current_player_index = 0
	gs.stadium_card = null
	battle.set("_pending_choice","")
	battle.get("_dialog_overlay").hide()
	if battle.get("_handover_panel") != null: battle.get("_handover_panel").hide()
	for pi in range(2):
		var player: PlayerState = gs.players[pi]
		player.deck.clear()
		player.hand.clear()
		player.bench.clear()
		player.discard_pile.clear()
		player.active_pokemon = _slot(tera if pi == 0 else basic,pi)
		for i in range(5): player.bench.append(_slot(basic,pi))
		var prizes: Array[CardInstance] = []
		for i in range(6): prizes.append(CardInstance.create(energy,pi))
		player.set_prizes(prizes)
		for i in range(48): player.deck.append(CardInstance.create(energy,pi))
	var played := CardInstance.create(stadium,0)
	gs.players[0].hand.append(played)
	for i in range(3): gs.players[0].hand.append(CardInstance.create(basic,0))
	for i in range(4): gs.players[0].hand.append(gs.players[0].deck.pop_back())
	for i in range(4): gs.players[0].deck.pop_back()
	battle.call("_refresh_ui")
	await _settle(1.2)
	var presenter = battle.get_node("Arena3DPresenter")
	var caption := Label.new()
	caption.text = "实卡交互验收 · 构造开场，零之大空洞和第 6–8 只备战通过鼠标打出"
	caption.position = Vector2(30,104)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.z_index = 250
	battle.add_child(caption)
	if not _check(not presenter.last_frame.slots.has("my_bench_5"),"five_before_stadium"): return
	await _hand_click(played)
	var use_button := _button_named(battle,"使用")
	if use_button != null: await _click_control(use_button,"confirm_stadium_use")
	await _settle(.8)
	await _capture("living-stadium-click.png")
	print("LIVING_STADIUM_STATE ready=",battle.call("_can_view_player_start_turn_action")," pending=",battle.get("_pending_choice")," view=",battle.get("_view_player")," selected=",battle.get("_selected_hand_card")," phase=",gs.phase," playable=",gsm.rule_validator.can_play_stadium(gs,0,played))
	if not _check(gs.stadium_card == played,"stadium_played_through_viewport"): return
	if not _check(presenter.last_frame.slots.has("my_bench_7") and not presenter.last_frame.slots.has("opp_bench_5"),"capacity_is_per_player"): return
	await _capture("living-eight-empty.png")
	for index in range(5,8):
		var ci: CardInstance = gs.players[0].hand[0]
		await _hand_click(ci)
		var at: Vector2 = presenter.get_global_transform()*presenter.world.camera.unproject_position(presenter.world.positions["my_bench_%d"%index])
		await _click_point(at,MOUSE_BUTTON_LEFT,"deploy_bench_%d"%index,presenter)
		if not _check(presenter.world.card_poses.has("my_bench_%d"%index),"bench_%d_has_travel_pose"%index): return
		await _capture("living-deploy-%d"%index)
		await _settle(.6)
		if not _check(gs.players[0].bench.size() == index+1,"bench_%d_committed"%index): return
	var scroll: Control = battle.get("_hand_scroll")
	var hand: BattleCardView = battle.get("_hand_container").get_child(1)
	var base_y := hand.position.y
	var move := InputEventMouseMotion.new()
	move.position = hand.get_global_transform()*Vector2(hand.size.x*.5,hand.size.y*.5)
	move.global_position = move.position
	get_tree().root.push_input(move,true)
	await _settle(.35)
	await _capture("living-hand-hover-diagnostic.png")
	print("LIVING_HAND_HOVER before=",base_y," after=",hand.position.y," pointer=",presenter.hand_fan.pointer," hovered=",presenter.hand_fan.hovered," target=",hand," event=",move.position)
	if not _check(hand.position.y < base_y-10,"hand_hover_lifts"): return
	await _capture("living-hand-hover.png")
	if not _check(battle.get_node("MainArea/CenterField/HandArea").size.y < 200,"compact_hand_height"): return
	for id: String in presenter.world.cards:
		var card: Dictionary = presenter.world.cards[id]
		if card.node.visible and not card.data.get("empty",true):
			if not _check(absf(card.node.position.z)+card.node.scale.x*.98 < 8.88,"cards_inside_playing_felt"): return
	var lamp_at: Vector3 = presenter.world.dynamics.lamps[0].position
	# The current field deliberately hides fern fronds that covered live cards.
	var hidden_ferns := 0
	for mesh: MeshInstance3D in presenter.world.stage.find_children("*", "MeshInstance3D", true, false):
		for surface: int in mesh.mesh.get_surface_count():
			if "fern" in mesh.get_active_material(surface).resource_name.to_lower():
				if not _check(not mesh.visible,"decorative_fern_does_not_cover_cards"): return
				hidden_ferns += 1
	if not _check(hidden_ferns > 0 and presenter.world.foliage_materials.is_empty(),"fern_is_intentionally_hidden"): return
	if not _check(presenter.world.stage_meshes.size() == 7,"complete_playing_table_remains_visible"): return
	await _capture("living-full-board.png")
	await _settle(1)
	if not _check(lamp_at.distance_to(presenter.world.dynamics.lamps[0].position) > .5,"lights_move_through_world"): return
	await _capture("living-light-and-wind.png")
	presenter.motion.zone_flight(true,false)
	await _settle(.22)
	var in_flight := false
	for node in presenter.world.effect_nodes:
		if is_instance_valid(node) and node.has_meta("card_flight"): in_flight = true
	if not _check(in_flight,"draw_has_physical_card_flight"): return
	await _capture("living-draw-flight.png")
	presenter.world.motion_enabled = false
	await _settle(.1)
	if not _check(presenter.world.effect_nodes.is_empty(),"reduced_motion_cleans_flights"): return
	print("ARENA_LIVING_ACCEPTANCE_PASS: real stadium, three legal bench placements, fan hover, table bounds, wind/lights, physical flights")
	battle.call("_release_battle_runtime_resources")
	battle.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _slot(card: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	var instance := CardInstance.create(card,owner)
	instance.face_up = true
	slot.pokemon_stack.append(instance)
	return slot

func _hand_click(instance: CardInstance) -> void:
	var view: BattleCardView
	for card in battle.get("_hand_container").get_children():
		if card is BattleCardView and card.card_instance == instance: view = card
	if not _check(view != null,"visible_hand_card_exists"): return
	battle.get("_hand_scroll").ensure_control_visible(view)
	await _settle(.2)
	view.get("_input_catcher").gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton: print("LIVING_CARD_INPUT pressed=",e.pressed," point=",e.global_position," active=",view.get("_hand_primary_press_active")," suppress=",view.get("_suppress_next_left_click"))
	)
	await _click_point(view.get_global_transform()*Vector2(view.size.x*.5,view.size.y*.5),MOUSE_BUTTON_LEFT,"play_visible_hand_card",view)

func _button_named(node: Node, text: String) -> Button:
	if node is Control and not node.is_visible_in_tree(): return null
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found := _button_named(child,text)
		if found != null: return found
	return null
