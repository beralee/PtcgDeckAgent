class_name TestSwitchingTicketAnimation
extends TestBase

const BattleDrawRevealControllerScript := preload("res://scripts/ui/battle/BattleDrawRevealController.gd")


class PrizeExchangeScene extends Control:
	var _draw_reveal_queue: Array[GameAction] = []
	var _draw_reveal_active := false
	var _draw_reveal_waiting_for_confirm := false
	var _draw_reveal_auto_continue_pending := false
	var _draw_reveal_pending_hand_refresh := false
	var _draw_reveal_current_action: GameAction = null
	var _draw_reveal_card_views: Array[BattleCardView] = []
	var _draw_reveal_resume_timer: Variant = null
	var _draw_reveal_allow_hand_refresh_during_fly := false
	var _draw_reveal_visible_instance_ids: Array[int] = []
	var _draw_reveal_overlay: Control = null
	var _view_player := 0
	var _gsm: GameStateMachine = null
	var _my_deck_preview: BattleCardView = null
	var _opp_deck_preview: BattleCardView = null
	var _my_prize_slots: Array[BattleCardView] = []
	var _opp_prize_slots: Array[BattleCardView] = []
	var _my_prize_hud_count: Label = null
	var _opp_prize_hud_count: Label = null
	var _player_card_back_texture: Texture2D = null
	var _opponent_card_back_texture: Texture2D = null
	var _handover_panel: Control = null
	var _pending_handover_action := Callable()
	var _play_card_size := Vector2(100, 140)
	var refresh_ui_calls := 0
	var refresh_hand_calls := 0
	var maybe_run_ai_calls := 0
	var portrait_layout := false

	func _get_prize_slot_view(player_index: int, slot_index: int) -> BattleCardView:
		var slots := _my_prize_slots if player_index == _view_player else _opp_prize_slots
		return slots[slot_index] if slot_index >= 0 and slot_index < slots.size() else null

	func _draw_reveal_anchor_rect() -> Rect2:
		return Rect2(Vector2.ZERO, size)

	func _is_portrait_battle_layout_active() -> bool:
		return portrait_layout

	func _refresh_ui() -> void:
		refresh_ui_calls += 1

	func _refresh_hand() -> void:
		refresh_hand_calls += 1

	func _check_two_player_handover() -> void:
		pass

	func _maybe_run_ai() -> void:
		maybe_run_ai_calls += 1


func _load_ticket() -> CardData:
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_193.json")
	)
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _card(name: String, owner_index: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = "Item"
	return CardInstance.create(data, owner_index)


func _basic(name: String, owner_index: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = 60
	return CardInstance.create(data, owner_index)


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 4
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner_index: int in 2:
		var player := PlayerState.new()
		player.player_index = owner_index
		state.players.append(player)
	return state


func test_switching_ticket_action_log_preserves_old_and_new_prize_instances_for_vfx() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _state()
	var ticket := CardInstance.create(_load_ticket(), 0)
	var old_prizes: Array[CardInstance] = [
		_card("Old Prize 1"),
		_card("Old Prize 2"),
		_card("Old Prize 3"),
	]
	var replacements: Array[CardInstance] = [
		_card("New Prize 1"),
		_card("New Prize 2"),
		_card("New Prize 3"),
	]
	gsm.game_state.players[0].hand = [ticket]
	gsm.game_state.players[0].set_prizes(old_prizes)
	gsm.game_state.players[0].deck.assign(replacements + [_card("Deck Tail")])

	var played := gsm.play_trainer(0, ticket, [])
	var action: GameAction = gsm.action_log.back() if not gsm.action_log.is_empty() else null
	var old_ids: Array = action.data.get("old_prize_instance_ids", []) if action != null else []
	var new_ids: Array = action.data.get("new_prize_instance_ids", []) if action != null else []

	return run_checks([
		assert_true(played, "Switching Ticket should resolve through the normal Trainer path"),
		assert_not_null(action, "Switching Ticket should append a PLAY_TRAINER action"),
		assert_eq(str(action.data.get("trainer_vfx", "")) if action != null else "", "switching_ticket", "Switching Ticket should request its dedicated animation"),
		assert_eq(old_ids, old_prizes.map(func(card: CardInstance) -> int: return card.instance_id), "VFX payload should preserve every former Prize instance in slot order"),
		assert_eq(new_ids, replacements.map(func(card: CardInstance) -> int: return card.instance_id), "VFX payload should preserve every replacement Prize instance in slot order"),
		assert_eq(int(action.data.get("prize_count", 0)) if action != null else 0, 3, "VFX payload should expose the visible card-back count"),
	])


func test_switching_ticket_animation_plan_has_four_ordered_face_down_phases() -> String:
	var action := GameAction.create(
		GameAction.ActionType.PLAY_TRAINER,
		0,
		{
			"trainer_vfx": "switching_ticket",
			"prize_count": 3,
			"old_prize_instance_ids": [11, 12, 13],
			"new_prize_instance_ids": [21, 22, 23],
		},
		4,
		"use Switching Ticket"
	)
	var controller := BattleDrawRevealControllerScript.new()
	var phases: Array = controller.call("build_prize_exchange_animation_plan", action)
	var phase_ids: Array[String] = []
	var routes: Array[String] = []
	var all_face_down := true
	var counts_match := true
	for phase_variant: Variant in phases:
		var phase: Dictionary = phase_variant if phase_variant is Dictionary else {}
		phase_ids.append(str(phase.get("id", "")))
		routes.append("%s->%s" % [phase.get("from_zone", ""), phase.get("to_zone", "")])
		all_face_down = all_face_down and bool(phase.get("face_down", false))
		counts_match = counts_match and int(phase.get("count", 0)) == 3

	return run_checks([
		assert_eq(phase_ids, ["prizes_to_display", "old_prizes_to_deck", "deck_to_display", "new_prizes_to_slots"], "Switching Ticket should use the requested four-stage visual sequence"),
		assert_eq(routes, ["prize->display", "display->deck", "deck->display", "display->prize"], "Each phase should fly between the requested board zones"),
		assert_true(all_face_down, "Old and replacement Prize cards must remain face down throughout the animation"),
		assert_true(counts_match, "Every phase should visibly carry the exact Prize count"),
	])


func test_switching_ticket_animation_plan_rejects_unrelated_trainer_actions() -> String:
	var action := GameAction.create(
		GameAction.ActionType.PLAY_TRAINER,
		0,
		{"trainer_vfx": "boss_orders"},
		4,
		"use another Trainer"
	)
	var controller := BattleDrawRevealControllerScript.new()
	var phases: Array = controller.call("build_prize_exchange_animation_plan", action)
	return assert_true(phases.is_empty(), "The Prize exchange animation should only consume Switching Ticket actions")


func test_opening_prize_actions_preserve_the_six_hidden_cards_for_animation() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _state()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	for player_index: int in 2:
		var active := PokemonSlot.new()
		active.pokemon_stack.append(_basic("Active %d" % player_index, player_index))
		gsm.game_state.players[player_index].active_pokemon = active
		for index: int in 12:
			gsm.game_state.players[player_index].deck.append(_card("P%d deck %d" % [player_index, index], player_index))
	var completed := gsm.setup_complete(0)
	var prize_actions: Array[GameAction] = []
	for action: GameAction in gsm.action_log:
		if action.action_type == GameAction.ActionType.SETUP_SET_PRIZES:
			prize_actions.append(action)
	var checks: Array[String] = [
		assert_true(completed, "Opening fixture should complete setup"),
		assert_eq(prize_actions.size(), 2, "Setup should emit one Prize placement action per player"),
	]
	for action: GameAction in prize_actions:
		var ids: Array = action.data.get("card_instance_ids", [])
		checks.append(assert_eq(ids.size(), 6, "Opening Prize animation should receive all six hidden card identities"))
		checks.append(assert_true(bool(action.data.get("opening_deal", false)), "Opening Prize placement should be marked for the dedicated deal animation"))
		checks.append(assert_eq(str(action.data.get("source_zone", "")), "deck", "Opening cards should visibly originate from the deck"))
		checks.append(assert_eq(str(action.data.get("target_zone", "")), "prize", "Opening cards should visibly land in the Prize destination"))
	return run_checks(checks)


func test_opening_prize_animation_plan_deals_once_from_deck_to_prize_destination() -> String:
	var action := GameAction.create(
		GameAction.ActionType.SETUP_SET_PRIZES,
		0,
		{
			"count": 6,
			"card_instance_ids": [1, 2, 3, 4, 5, 6],
			"source_zone": "deck",
			"target_zone": "prize",
			"opening_deal": true,
		},
		0,
		"place opening Prizes"
	)
	var phases: Array = BattleDrawRevealControllerScript.new().call("build_prize_exchange_animation_plan", action)
	var phase: Dictionary = phases[0] if phases.size() == 1 else {}
	return run_checks([
		assert_eq(phases.size(), 1, "Opening setup should use one concise deal phase"),
		assert_eq(str(phase.get("id", "")), "opening_deck_to_prize", "Opening phase should have a stable animation identity"),
		assert_eq(str(phase.get("from_zone", "")), "deck", "Opening Prize cards should originate at the player's deck HUD"),
		assert_eq(str(phase.get("to_zone", "")), "prize", "Opening Prize cards should land at the layout-specific Prize destination"),
		assert_true(bool(phase.get("face_down", false)), "Opening Prize identities must stay hidden throughout the animation"),
	])


func test_portrait_prize_flights_target_the_visible_count_hud_instead_of_hidden_slots() -> String:
	var scene := PrizeExchangeScene.new()
	scene.size = Vector2(430, 932)
	scene.portrait_layout = true
	var hidden_slot := BattleCardView.new()
	hidden_slot.size = Vector2(72, 100)
	hidden_slot.visible = false
	scene.add_child(hidden_slot)
	scene._my_prize_slots.append(hidden_slot)
	var visible_count := Label.new()
	visible_count.size = Vector2(86, 54)
	visible_count.position = Vector2(18, 710)
	scene.add_child(visible_count)
	scene._my_prize_hud_count = visible_count
	var controller := BattleDrawRevealControllerScript.new()
	var portrait_anchor := controller.call("_prize_exchange_zone_anchor", scene, 0, "prize", 0) as Control
	var portrait_uses_visible_hud := portrait_anchor == visible_count
	scene.portrait_layout = false
	var landscape_anchor := controller.call("_prize_exchange_zone_anchor", scene, 0, "prize", 0) as Control
	var landscape_uses_slot := landscape_anchor == hidden_slot
	scene.free()
	return run_checks([
		assert_true(portrait_uses_visible_hud, "Portrait Prize flight should converge on the visible remaining-Prize HUD"),
		assert_true(landscape_uses_slot, "Landscape Prize flight should keep targeting the physical Prize slot"),
	])


func test_portrait_prize_hud_flight_keeps_screen_center_under_rotated_canvas() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := PrizeExchangeScene.new()
	scene.size = Vector2(900, 1600)
	scene.position = Vector2(112, 46)
	scene.rotation_degrees = 90.0
	scene.scale = Vector2(0.48, 0.48)
	scene.portrait_layout = true
	var board := Control.new()
	board.size = scene.size
	board.position = Vector2(24, 18)
	board.scale = Vector2(0.96, 1.02)
	scene.add_child(board)
	var prize_hud := Label.new()
	prize_hud.position = Vector2(28, 1110)
	prize_hud.size = Vector2(132, 82)
	board.add_child(prize_hud)
	scene._my_prize_hud_count = prize_hud
	tree.root.add_child(scene)
	await tree.process_frame
	var controller := BattleDrawRevealControllerScript.new()
	var overlay := controller.call("_ensure_overlay", scene) as Control
	var card_view := controller.call("_create_reveal_card_view", scene, overlay, _card("Opening Prize"), 0) as BattleCardView
	await tree.process_frame
	var target_scale: Vector2 = controller.call("_prize_exchange_zone_scale", scene, card_view, 0, "prize", 0)
	card_view.scale = target_scale
	card_view.position = controller.call("_prize_exchange_zone_position", scene, card_view, 0, "prize", 0, 1, target_scale)
	var actual_screen := card_view.get_screen_transform() * (card_view.size * 0.5)
	var expected_screen := prize_hud.get_screen_transform() * (prize_hud.size * 0.5)
	var result := assert_true(actual_screen.distance_to(expected_screen) < 1.0, "Rotated Android portrait Prize flight should land on the visible count HUD")
	scene.queue_free()
	await tree.process_frame
	return result


func test_prize_exchange_flight_uses_final_screen_centers_under_nested_transforms() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := PrizeExchangeScene.new()
	scene.size = Vector2(980, 620)
	scene.position = Vector2(126, 70)
	scene.rotation_degrees = 6.0
	scene.scale = Vector2(0.87, 1.13)
	var board := Control.new()
	board.position = Vector2(64, 38)
	board.size = Vector2(850, 540)
	board.rotation_degrees = -4.0
	board.scale = Vector2(1.08, 0.92)
	scene.add_child(board)
	var deck_preview := BattleCardView.new()
	deck_preview.position = Vector2(690, 365)
	deck_preview.size = Vector2(82, 114)
	board.add_child(deck_preview)
	scene._my_deck_preview = deck_preview
	var prize_slot := BattleCardView.new()
	prize_slot.position = Vector2(118, 374)
	prize_slot.size = Vector2(76, 106)
	board.add_child(prize_slot)
	scene._my_prize_slots.append(prize_slot)
	tree.root.add_child(scene)
	await tree.process_frame

	var controller := BattleDrawRevealControllerScript.new()
	var overlay: Control = controller.call("_ensure_overlay", scene) as Control
	var card_view: BattleCardView = controller.call("_create_reveal_card_view", scene, overlay, _card("Flight card"), 0) as BattleCardView
	await tree.process_frame
	var scale: Vector2 = controller.call("_prize_exchange_zone_scale", scene, card_view, 0, "deck", 0)
	card_view.scale = scale
	card_view.position = controller.call("_prize_exchange_zone_position", scene, card_view, 0, "deck", 0, 1, scale)
	var actual_screen := card_view.get_screen_transform() * (card_view.size * 0.5)
	var expected_screen := deck_preview.get_screen_transform() * (deck_preview.size * 0.5)
	var result := assert_true(actual_screen.distance_to(expected_screen) < 1.0, "Prize/deck flight cards must stay centered on transformed board anchors")
	scene.queue_free()
	await tree.process_frame
	return result


func test_switching_ticket_runtime_keeps_card_backs_visible_until_four_phases_finish() -> String:
	var previous_mode: int = GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var scene := PrizeExchangeScene.new()
	scene.size = Vector2(1280, 720)
	var deck_preview := BattleCardView.new()
	deck_preview.position = Vector2(1060, 500)
	deck_preview.size = Vector2(80, 112)
	scene.add_child(deck_preview)
	scene._my_deck_preview = deck_preview
	for index: int in 3:
		var slot := BattleCardView.new()
		slot.position = Vector2(120 + index * 90, 510)
		slot.size = Vector2(72, 100)
		scene.add_child(slot)
		scene._my_prize_slots.append(slot)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame

	var gsm := GameStateMachine.new()
	gsm.game_state = _state()
	scene._gsm = gsm
	var old_prizes: Array[CardInstance] = [_card("Old 1"), _card("Old 2"), _card("Old 3")]
	var new_prizes: Array[CardInstance] = [_card("New 1"), _card("New 2"), _card("New 3")]
	gsm.game_state.players[0].deck.assign(old_prizes)
	gsm.game_state.players[0].set_prizes(new_prizes)
	var action := GameAction.create(
		GameAction.ActionType.PLAY_TRAINER,
		0,
		{
			"trainer_vfx": "switching_ticket",
			"prize_count": 3,
			"old_prize_instance_ids": old_prizes.map(func(card: CardInstance) -> int: return card.instance_id),
			"new_prize_instance_ids": new_prizes.map(func(card: CardInstance) -> int: return card.instance_id),
		},
		4,
		"use Switching Ticket"
	)
	var controller := BattleDrawRevealControllerScript.new()
	controller.call("enqueue_reveal", scene, action)
	await tree.create_timer(0.12).timeout
	var staged_views := scene._draw_reveal_card_views.duplicate()
	var all_face_down := staged_views.size() == 3
	for view_variant: Variant in staged_views:
		var view := view_variant as BattleCardView
		all_face_down = all_face_down and view != null and bool(view.get("_face_down"))
	var still_running_after_first_frame := scene._draw_reveal_active
	await tree.create_timer(2.8).timeout
	var finished := not scene._draw_reveal_active
	var refreshed_after_finish := scene.refresh_ui_calls >= 1
	var resumed_after_finish := scene.maybe_run_ai_calls >= 1
	scene.queue_free()
	await tree.process_frame
	GameManager.current_mode = previous_mode

	return run_checks([
		assert_true(still_running_after_first_frame, "Switching Ticket must not disappear in the same frame as its state update"),
		assert_true(all_face_down, "The runtime should visibly stage all three cards without revealing either hidden Prize set"),
		assert_true(finished, "All four Prize exchange phases should complete automatically"),
		assert_true(refreshed_after_finish, "The board should refresh to the replacement Prize layout after the animation"),
		assert_true(resumed_after_finish, "AI/input progression should resume only after the animation finishes"),
	])
