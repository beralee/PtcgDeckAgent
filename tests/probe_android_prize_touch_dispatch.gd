extends SceneTree

var _battle_scene_packed: PackedScene = null
var _game_manager: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_game_manager = root.get_node_or_null("GameManager")
	if _game_manager == null:
		print("FAIL missing /root/GameManager autoload")
		quit(1)
		return
	_battle_scene_packed = load("res://scenes/battle/BattleScene.tscn") as PackedScene
	if _battle_scene_packed == null:
		print("FAIL unable to load BattleScene.tscn")
		quit(1)
		return
	var previous_mode: int = int(_game_manager.get("current_mode"))
	var previous_layout: String = str(_game_manager.get("battle_layout_mode"))
	_game_manager.set("current_mode", int(_game_manager.GameMode.VS_AI))

	var baseline_result := await _run_viewport_dispatch_baseline()
	if baseline_result != "":
		failures.append(baseline_result)

	var landscape_result := await _run_prize_touch_case("landscape", Vector2(1600, 900), false)
	if landscape_result != "":
		failures.append(landscape_result)

	var portrait_result := await _run_prize_touch_case("portrait", Vector2(900, 1600), true)
	if portrait_result != "":
		failures.append(portrait_result)

	_game_manager.set("current_mode", previous_mode)
	_game_manager.set("battle_layout_mode", previous_layout)

	if failures.is_empty():
		print("PASS android prize touch dispatch probe")
		quit(0)
	else:
		for failure: String in failures:
			print("FAIL %s" % failure)
		quit(1)


func _run_viewport_dispatch_baseline() -> String:
	_resize_test_viewport(Vector2(640, 480))
	var hit_count := [0]
	var probe := Control.new()
	probe.name = "ViewportDispatchBaseline"
	probe.position = Vector2(32, 32)
	probe.size = Vector2(160, 120)
	probe.mouse_filter = Control.MOUSE_FILTER_STOP
	probe.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
			hit_count[0] += 1
	)
	root.add_child(probe)
	await process_frame
	_push_touch(probe, Vector2(64, 64), true)
	await process_frame
	_push_touch(probe, Vector2(64, 64), false)
	await process_frame
	var hits := int(hit_count[0])
	probe.queue_free()
	await process_frame
	if hits != 1:
		return "baseline: Viewport.push_input did not dispatch ScreenTouch to a simple Control; hits=%d root_rect=%s" % [
			hits,
			str(root.get_visible_rect()),
		]
	return ""


func _run_prize_touch_case(layout_mode: String, viewport_size: Vector2, use_portrait_dialog: bool) -> String:
	_game_manager.set("battle_layout_mode", layout_mode)
	_resize_test_viewport(viewport_size)
	var scene: Control = _battle_scene_packed.instantiate()
	root.add_child(scene)
	await process_frame
	scene.size = viewport_size
	scene.set("_view_player", 0)
	scene.set("_active_battle_layout_mode", layout_mode)
	if layout_mode == "landscape":
		scene.call("_apply_landscape_layout_impl", viewport_size)
	else:
		scene.call("_setup_battle_layout")
	await process_frame
	await process_frame

	var gsm := _make_prize_ready_gsm()
	gsm.state_changed.connect(scene._on_state_changed)
	gsm.player_choice_required.connect(scene._on_player_choice_required)
	gsm.action_logged.connect(scene._on_action_logged)
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.set("_pending_choice", "take_prize")
	scene.set("_pending_prize_player_index", 0)
	scene.set("_pending_prize_remaining", 1)
	scene.set("_pending_prize_animating", false)
	scene.call("_refresh_ui")
	if use_portrait_dialog:
		scene.call("_show_portrait_prize_dialog_if_needed")
	await process_frame
	await process_frame

	var slots: Array[BattleCardView] = scene.get("_my_prize_slots")
	if slots.is_empty() or slots[0] == null:
		scene.queue_free()
		await process_frame
		return "%s: missing visible prize slot" % layout_mode
	var prize_slot := slots[0] as BattleCardView
	var slot_rect := prize_slot.get_global_rect()
	if slot_rect.size.x <= 0.0 or slot_rect.size.y <= 0.0:
		scene.queue_free()
		await process_frame
		return "%s: prize slot has empty global rect %s" % [layout_mode, str(slot_rect)]

	var hand_before := gsm.game_state.players[0].hand.size()
	var prize_before := gsm.game_state.players[0].prizes.size()
	var touch_position := slot_rect.get_center()
	var diagnostics := _describe_prize_input_path(scene, prize_slot, touch_position)
	_push_touch(scene, touch_position, true)
	await process_frame
	_push_touch(scene, touch_position, false)
	await process_frame
	var animating_after_release := bool(scene.get("_pending_prize_animating"))
	await create_timer(0.45).timeout
	await process_frame
	await process_frame

	var hand_after := gsm.game_state.players[0].hand.size()
	var prize_after := gsm.game_state.players[0].prizes.size()
	var pending_after := str(scene.get("_pending_choice"))
	scene.queue_free()
	await process_frame

	if not animating_after_release and hand_after == hand_before:
		return "%s: viewport touch did not enter prize taking path; root_rect=%s root_size=%s pos=%s rect=%s pending=%s %s" % [
			layout_mode,
			str(root.get_visible_rect()),
			str(root.size),
			str(touch_position),
			str(slot_rect),
			pending_after,
			diagnostics,
		]
	if hand_after != hand_before + 1:
		return "%s: prize touch reached UI but did not move prize to hand; hand %d->%d prizes %d->%d pending=%s animating_after_release=%s" % [
			layout_mode,
			hand_before,
			hand_after,
			prize_before,
			prize_after,
			pending_after,
			str(animating_after_release),
		]
	if prize_after != prize_before - 1:
		return "%s: hand gained a card but prize count did not decrease; prizes %d->%d" % [layout_mode, prize_before, prize_after]
	return ""


func _resize_test_viewport(viewport_size: Vector2) -> void:
	var size_i := Vector2i(int(viewport_size.x), int(viewport_size.y))
	DisplayServer.window_set_size(size_i)
	root.size = size_i
	root.content_scale_size = size_i


func _describe_prize_input_path(scene: Control, prize_slot: BattleCardView, touch_position: Vector2) -> String:
	var input_catcher := prize_slot.find_child("CardInputCatcher", true, false) as Control
	var scene_methods := {
		"_on_prize_slot_input": scene.has_method("_on_prize_slot_input"),
		"_on_dynamic_prize_slot_input": scene.has_method("_on_dynamic_prize_slot_input"),
		"_on_prize_slot_card_left_clicked": scene.has_method("_on_prize_slot_card_left_clicked"),
		"_try_take_prize_from_slot": scene.has_method("_try_take_prize_from_slot"),
	}
	var slot_connections := {
		"gui_input": prize_slot.gui_input.get_connections().size(),
		"left_clicked": prize_slot.left_clicked.get_connections().size(),
	}
	var catcher_connections := 0
	var catcher_filter := -1
	if input_catcher != null:
		catcher_connections = input_catcher.gui_input.get_connections().size()
		catcher_filter = input_catcher.mouse_filter
	return "filters={stop:%d,pass:%d,ignore:%d} methods=%s slot_connections=%s slot_filter=%d catcher=%s catcher_filter=%d catcher_gui=%d mode=%s controls_at_point=%s" % [
		Control.MOUSE_FILTER_STOP,
		Control.MOUSE_FILTER_PASS,
		Control.MOUSE_FILTER_IGNORE,
		str(scene_methods),
		str(slot_connections),
		prize_slot.mouse_filter,
		str(input_catcher != null),
		catcher_filter,
		catcher_connections,
		str(prize_slot.display_mode),
		_controls_at_point_summary(root, touch_position),
	]


func _controls_at_point_summary(node: Node, point: Vector2) -> String:
	var entries: Array[String] = []
	_collect_controls_at_point(node, point, entries)
	var start_index: int = maxi(0, entries.size() - 14)
	var visible_entries := entries.slice(start_index, entries.size())
	return "[%s]" % ", ".join(visible_entries)


func _collect_controls_at_point(node: Node, point: Vector2, entries: Array[String]) -> void:
	var control := node as Control
	if control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(point):
		entries.append("%s:%s mf=%d z=%d rect=%s" % [
			str(control.get_path()),
			control.get_class(),
			control.mouse_filter,
			control.z_index,
			str(control.get_global_rect()),
		])
	for child: Node in node.get_children():
		_collect_controls_at_point(child, point, entries)


func _push_touch(scene: Control, position: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = pressed
	touch.position = position
	var viewport := scene.get_viewport()
	if viewport != null:
		viewport.push_input(touch, false)


func _make_prize_ready_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = 4
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)
	state.players[0].active_pokemon = _make_slot("Attacker", 220, 0)
	state.players[1].active_pokemon = _make_slot("Knocked Out Target", 10, 1)
	var prizes: Array[CardInstance] = []
	for i: int in 6:
		prizes.append(CardInstance.create(_make_pokemon_card("Prize %d" % i, 60), 0))
	state.players[0].set_prizes(prizes)
	gsm.game_state = state
	gsm.set("_pending_prize_player_index", 0)
	gsm.set("_pending_prize_remaining", 1)
	return gsm


func _make_slot(card_name: String, hp: int, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(_make_pokemon_card(card_name, hp), owner))
	return slot


func _make_pokemon_card(card_name: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	card.energy_type = "C"
	card.attacks = []
	card.abilities = []
	card.retreat_cost = 1
	return card
