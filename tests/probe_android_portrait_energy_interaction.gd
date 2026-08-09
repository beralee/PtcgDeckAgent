extends Node

const BattleScenePacked := preload("res://scenes/battle/BattleScene.tscn")

var _battle_scene: Control = null
var _field_tap_passed := false
var _pointer_trace_count := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	GameManager.battle_layout_mode = GameManager.BATTLE_LAYOUT_PORTRAIT
	GameManager.battle_effects_enabled = true

	_battle_scene = BattleScenePacked.instantiate()
	_battle_scene.set("_battle_mode", "review")
	add_child(_battle_scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var gsm := _make_empty_gsm()
	_battle_scene.set("_gsm", gsm)
	_battle_scene.set("_view_player", 0)
	_battle_scene.set("_active_battle_layout_mode", "portrait")
	_battle_scene.call("_setup_battle_layout")
	await get_tree().process_frame
	await get_tree().process_frame

	var target := PokemonSlot.new()
	target.pokemon_stack.append(CardInstance.create(_make_pokemon("Android Target"), 0))
	gsm.game_state.players[0].active_pokemon = target
	var grass := CardInstance.create(_make_energy("Basic Grass Energy", "G"), 0)
	var fire := CardInstance.create(_make_energy("Basic Fire Energy", "R"), 0)
	_battle_scene.call("_show_field_assignment_interaction", {
		"title": "Android portrait Energy touch probe",
		"ui_mode": "card_assignment",
		"source_items": [grass, fire],
		"source_labels": ["Basic Grass Energy", "Basic Fire Energy"],
		"target_items": [target],
		"target_labels": ["Android Target"],
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	})
	await get_tree().process_frame
	await get_tree().process_frame

	var source_card := _first_source_card()
	var pointer_controller: Variant = _battle_scene.get("_battle_pointer_surface_controller")
	_connect_source_diagnostics()
	if source_card == null:
		print("PTCG_ANDROID_ENERGY_PROBE_FAIL field_source_missing")
	else:
		var local_center := source_card.size * 0.5
		var logical_center := source_card.get_global_transform() * local_center
		var screen_size := Vector2(DisplayServer.screen_get_size())
		var viewport_size := get_viewport().get_visible_rect().size
		var physical_center := logical_center * (screen_size / viewport_size)
		print(
			"PTCG_ANDROID_ENERGY_PROBE_READY physical_x=%d physical_y=%d logical=%s physical=%s card_rect=%s viewport=%s surface_enabled=%s" % [
				roundi(physical_center.x),
				roundi(physical_center.y),
				str(logical_center),
				str(physical_center),
				str(source_card.get_global_rect()),
				str(get_viewport().get_visible_rect()),
				str(pointer_controller != null and bool(pointer_controller.call("is_enabled"))),
			]
		)
		var scroll := _battle_scene.get("_field_interaction_scroll") as ScrollContainer
		var surface_id := "gallery:%d" % scroll.get_instance_id() if scroll != null else ""
		print("PTCG_ANDROID_ENERGY_PROBE_SURFACE id=%s generation=%d contains=%s target=%s" % [
			surface_id,
			int(pointer_controller.call("surface_generation", surface_id)) if pointer_controller != null else -1,
			str(_battle_scene.call("_card_gallery_pointer_contains", logical_center, scroll)) if scroll != null else "false",
			str(_battle_scene.call("_card_gallery_pointer_target_at", logical_center, _battle_scene.get("_field_interaction_row"), scroll)) if scroll != null else "null",
		])
		_pointer_trace_count = (pointer_controller.call("trace_snapshot") as Array).size() if pointer_controller != null else 0

	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline:
		_log_new_pointer_trace(pointer_controller)
		var selected_source := int(_battle_scene.get("_field_interaction_assignment_selected_source_index"))
		if selected_source >= 0:
			_field_tap_passed = true
			print("PTCG_ANDROID_ENERGY_PROBE_FIELD_TAP_PASS selected_source=%d" % selected_source)
			break
		await get_tree().create_timer(0.05).timeout
	if not _field_tap_passed:
		print("PTCG_ANDROID_ENERGY_PROBE_FIELD_TAP_FAIL selected_source=%s" % str(
			_battle_scene.get("_field_interaction_assignment_selected_source_index")
		))

	var vessel_passed := await _run_earthen_vessel_probe()
	print("PTCG_ANDROID_ENERGY_PROBE_COMPLETE field=%s vessel=%s" % [
		"PASS" if _field_tap_passed else "FAIL",
		"PASS" if vessel_passed else "FAIL",
	])


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		print("PTCG_ANDROID_ENERGY_PROBE_RAW type=ScreenTouch pressed=%s index=%d position=%s" % [
			str(touch.pressed), touch.index, str(touch.position)
		])
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			print("PTCG_ANDROID_ENERGY_PROBE_RAW type=MouseButton pressed=%s device=%d position=%s global=%s" % [
				str(mouse.pressed), mouse.device, str(mouse.position), str(mouse.global_position)
			])


func _connect_source_diagnostics() -> void:
	var row := _battle_scene.get("_field_interaction_row") as HBoxContainer
	if row == null:
		return
	for child_index: int in row.get_child_count():
		var card := row.get_child(child_index) as BattleCardView
		if card == null:
			continue
		card.hand_drag_input.connect(func(event: InputEvent) -> void:
			print("PTCG_ANDROID_ENERGY_PROBE_CARD_INPUT card=%d type=%s detail=%s" % [
				child_index,
				event.get_class(),
				_event_detail(event),
			])
		)
		card.left_clicked.connect(func(_instance: CardInstance, _data: CardData) -> void:
			print("PTCG_ANDROID_ENERGY_PROBE_CARD_ACTIVATE card=%d selected_before=%s" % [
				child_index,
				str(_battle_scene.get("_field_interaction_assignment_selected_source_index")),
			])
		)


func _event_detail(event: InputEvent) -> String:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		return "pressed=%s index=%d position=%s" % [str(touch.pressed), touch.index, str(touch.position)]
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return "pressed=%s device=%d position=%s global=%s" % [
			str(mouse.pressed), mouse.device, str(mouse.position), str(mouse.global_position)
		]
	return ""


func _log_new_pointer_trace(pointer_controller: Variant) -> void:
	if pointer_controller == null:
		return
	var trace := pointer_controller.call("trace_snapshot") as Array
	if trace.size() <= _pointer_trace_count:
		return
	for trace_index: int in range(_pointer_trace_count, trace.size()):
		print("PTCG_ANDROID_ENERGY_PROBE_POINTER_TRACE %s" % JSON.stringify(trace[trace_index]))
	_pointer_trace_count = trace.size()


func _run_earthen_vessel_probe() -> bool:
	_battle_scene.call("_hide_field_interaction")
	_battle_scene.set("_battle_mode", "live")
	var gsm := _make_empty_gsm()
	_battle_scene.set("_gsm", gsm)
	_battle_scene.set("_view_player", 0)
	if not gsm.action_logged.is_connected(Callable(_battle_scene, "_on_action_logged")):
		gsm.action_logged.connect(Callable(_battle_scene, "_on_action_logged"))
	var player: PlayerState = gsm.game_state.players[0]
	var stable := CardInstance.create(_make_trainer("Stable Card"), 0)
	var vessel := CardInstance.create(_make_trainer("Earthen Vessel"), 0)
	vessel.card_data.effect_id = "e366f56ecd3f805a28294109a1a37453"
	var discard_cost := CardInstance.create(_make_trainer("Discard Cost"), 0)
	var fighting := CardInstance.create(_make_energy("Basic Fighting Energy", "F"), 0)
	var lightning := CardInstance.create(_make_energy("Basic Lightning Energy", "L"), 0)
	player.hand = [stable, vessel, discard_cost]
	player.deck = [fighting, lightning]
	gsm.effect_processor.register_effect(
		vessel.card_data.effect_id,
		EffectSearchBasicEnergy.new(2, 1)
	)

	_battle_scene.call("_refresh_hand")
	await get_tree().process_frame
	_battle_scene.call("_try_play_trainer_with_interaction", 0, vessel)
	_battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([1]))
	_battle_scene.call("_handle_effect_interaction_choice", PackedInt32Array([0, 1]))
	await get_tree().create_timer(0.65).timeout
	await get_tree().process_frame
	await get_tree().process_frame

	var hand_container := _battle_scene.get("_hand_container") as HBoxContainer
	var rendered_ids: Dictionary = {}
	var visible_ids: Dictionary = {}
	if hand_container != null:
		for child: Node in hand_container.get_children():
			var card_view := child as BattleCardView
			if card_view == null or card_view.card_instance == null:
				continue
			rendered_ids[card_view.card_instance.instance_id] = true
			if card_view.is_visible_in_tree() and card_view.get_global_rect().size != Vector2.ZERO:
				visible_ids[card_view.card_instance.instance_id] = true
	var authoritative := fighting in player.hand and lightning in player.hand
	var rendered := rendered_ids.has(fighting.instance_id) and rendered_ids.has(lightning.instance_id)
	var visible := visible_ids.has(fighting.instance_id) and visible_ids.has(lightning.instance_id)
	var count_matches := hand_container != null and hand_container.get_child_count() == player.hand.size()
	var passed := authoritative and rendered and visible and count_matches
	print(
		"PTCG_ANDROID_ENERGY_PROBE_VESSEL_%s authoritative=%s rendered=%s visible=%s count=%s hand_size=%d rendered_count=%d" % [
			"PASS" if passed else "FAIL",
			str(authoritative),
			str(rendered),
			str(visible),
			str(count_matches),
			player.hand.size(),
			hand_container.get_child_count() if hand_container != null else -1,
		]
	)
	return passed


func _first_source_card() -> BattleCardView:
	var row := _battle_scene.get("_field_interaction_row") as HBoxContainer
	if row == null:
		return null
	for child: Node in row.get_children():
		var card := child as BattleCardView
		if card != null:
			return card
	return null


func _make_empty_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	gsm.game_state = state
	return gsm


func _make_pokemon(card_name: String) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 120
	card.energy_type = "C"
	card.attacks = []
	card.abilities = []
	return card


func _make_energy(card_name: String, energy_type: String) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.card_type = "Basic Energy"
	card.energy_provides = energy_type
	return card


func _make_trainer(card_name: String) -> CardData:
	var card := CardData.new()
	card.name = card_name
	card.card_type = "Trainer"
	card.trainer_type = "Item"
	return card
