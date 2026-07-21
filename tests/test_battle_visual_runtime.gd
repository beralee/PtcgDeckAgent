class_name TestBattleVisualRuntime
extends TestBase

const SnapshotScript := preload("res://scripts/ui/battle/visuals/BattleVisualSnapshot.gd")
const ControllerScript := preload("res://scripts/ui/battle/visuals/BattleVisualSequenceController.gd")


class VisualScene extends Control:
	var _view_player := 0
	var _my_deck_preview: BattleCardView = null
	var _opp_deck_preview: BattleCardView = null
	var _my_discard_preview: BattleCardView = null
	var _opp_discard_preview: BattleCardView = null
	var _hand_container: HBoxContainer = null
	var _opp_hand_bar: PanelContainer = null
	var _my_lost_value: Label = null
	var _enemy_lost_value: Label = null
	var _stadium_card_view: BattleCardView = null
	var _slot_card_views: Dictionary = {}
	var _player_card_back_texture: Texture2D = null
	var _opponent_card_back_texture: Texture2D = null
	var visual_gate_changes: Array[bool] = []

	func _set_battle_visual_input_blocked(blocked: bool) -> void:
		visual_gate_changes.append(blocked)


func _card(name: String) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = "Item"
	return CardInstance.create(data, 0)


func _state(card: CardInstance) -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[0].hand = [card]
	return state


func _make_scene(size: Vector2) -> VisualScene:
	var scene := VisualScene.new()
	scene.size = size
	var deck := BattleCardView.new()
	deck.position = Vector2(size.x - 120.0, size.y - 180.0)
	deck.size = Vector2(82, 116)
	deck.set_face_down(true)
	scene.add_child(deck)
	scene._my_deck_preview = deck
	var opp_deck := BattleCardView.new()
	opp_deck.position = Vector2(38, 50)
	opp_deck.size = Vector2(82, 116)
	opp_deck.set_face_down(true)
	scene.add_child(opp_deck)
	scene._opp_deck_preview = opp_deck
	var discard := BattleCardView.new()
	discard.position = Vector2(size.x - 220.0, size.y - 180.0)
	discard.size = Vector2(82, 116)
	scene.add_child(discard)
	scene._my_discard_preview = discard
	var hand := HBoxContainer.new()
	hand.position = Vector2(70, size.y - 160.0)
	hand.size = Vector2(size.x - 220.0, 135.0)
	scene.add_child(hand)
	scene._hand_container = hand
	var opp_hand := PanelContainer.new()
	opp_hand.position = Vector2(size.x * 0.35, 16)
	opp_hand.size = Vector2(size.x * 0.30, 60)
	scene.add_child(opp_hand)
	scene._opp_hand_bar = opp_hand
	return scene


func test_real_tweens_finish_in_portrait_and_leave_rule_state_and_input_clean() -> String:
	var card := _card("Animated Card")
	var state := _state(card)
	var state_before: Dictionary = SnapshotScript.capture(state)
	var scene := _make_scene(Vector2(900, 1600))
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	var controller: RefCounted = ControllerScript.new()
	controller.call("setup", scene)
	controller.call("enqueue_events", [
		{
			"kind": "zone_transfer",
			"semantic": "draw",
			"player_index": 0,
			"source_zone": "p0.deck",
			"target_zone": "p0.hand",
			"visibility": "face",
			"cards": [card],
			"card_instance_ids": [card.instance_id],
			"count": 1,
		},
		{"kind": "damage_delta", "slot_key": "p0.active", "amount": 30},
		{"kind": "phase_banner", "semantic": "turn_start", "player_index": 0, "view_player": 0},
	])
	await tree.create_timer(2.4).timeout
	await tree.process_frame
	var state_after: Dictionary = SnapshotScript.capture(state)
	var leftover_visual_nodes := 0
	for child: Node in scene.get_children():
		var control := child as Control
		if control != null and control.z_index >= 275:
			leftover_visual_nodes += 1
	var result := run_checks([
		assert_eq(int(controller.call("pending_count")), 0, "Every real Tween should complete within the bounded sequence"),
		assert_false(bool(controller.call("is_active")), "Controller should be idle after real Tween completion"),
		assert_eq(scene.visual_gate_changes, [true, false], "Portrait runtime should release its input gate"),
		assert_eq(leftover_visual_nodes, 0, "No invisible transfer, label, or veil node may remain"),
		assert_eq(state_after, state_before, "Real visual nodes and Tweens must not mutate rule state"),
	])
	controller.call("clear", "test_end")
	scene.queue_free()
	await tree.process_frame
	return result


func test_real_trainer_tween_finishes_in_landscape_and_releases_runtime_gate() -> String:
	var card := _card("Landscape Trainer")
	var state := _state(card)
	var state_before: Dictionary = SnapshotScript.capture(state)
	var scene := _make_scene(Vector2(1600, 900))
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	var controller: RefCounted = ControllerScript.new()
	controller.call("setup", scene)
	controller.call("enqueue_events", [
		{
			"kind": "zone_transfer",
			"semantic": "trainer_play",
			"player_index": 0,
			"source_zone": "p0.hand",
			"target_zone": "p0.discard",
			"visibility": "face",
			"cards": [card],
			"card_instance_ids": [card.instance_id],
			"count": 1,
		},
	])
	await tree.create_timer(1.8).timeout
	await tree.process_frame
	var state_after: Dictionary = SnapshotScript.capture(state)
	var leftover_visual_nodes := 0
	for child: Node in scene.get_children():
		var control := child as Control
		if control != null and control.z_index >= 275:
			leftover_visual_nodes += 1
	var result := run_checks([
		assert_eq(int(controller.call("pending_count")), 0, "Landscape Trainer sequence should complete"),
		assert_false(bool(controller.call("is_active")), "Landscape controller should return to idle"),
		assert_eq(scene.visual_gate_changes, [true, false], "Landscape runtime should release its informational gate"),
		assert_eq(leftover_visual_nodes, 0, "Landscape animation should not leave transient nodes"),
		assert_eq(state_after, state_before, "Landscape animation must not mutate rule state"),
	])
	controller.call("clear", "test_end")
	scene.queue_free()
	await tree.process_frame
	return result
