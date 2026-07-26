class_name TestBattleVisualRuntime
extends TestBase

const SnapshotScript := preload("res://scripts/ui/battle/visuals/BattleVisualSnapshot.gd")
const ControllerScript := preload("res://scripts/ui/battle/visuals/BattleVisualSequenceController.gd")
const AnchorResolverScript := preload("res://scripts/ui/battle/visuals/BattleVisualAnchorResolver.gd")
const ZoneAnimatorScript := preload("res://scripts/ui/battle/visuals/BattleZoneTransferAnimator.gd")
const DrawRevealScript := preload("res://scripts/ui/battle/BattleDrawRevealController.gd")


class VisualScene extends Control:
	var _view_player := 0
	var _my_deck_preview: BattleCardView = null
	var _opp_deck_preview: BattleCardView = null
	var _my_discard_preview: BattleCardView = null
	var _opp_discard_preview: BattleCardView = null
	var _hand_container: HBoxContainer = null
	var _opp_hand_bar: PanelContainer = null
	var _opp_hand_lbl: Label = null
	var _my_prize_hud_count: Label = null
	var _opp_prize_hud_count: Label = null
	var _hidden_prize_slot: BattleCardView = null
	var _my_lost_value: Label = null
	var _enemy_lost_value: Label = null
	var _stadium_card_view: BattleCardView = null
	var _slot_card_views: Dictionary = {}
	var _field_active_card_size := Vector2.ZERO
	var _player_card_back_texture: Texture2D = null
	var _opponent_card_back_texture: Texture2D = null
	var visual_gate_changes: Array[bool] = []
	var field_resync_semantics: Array[String] = []

	func _set_battle_visual_input_blocked(blocked: bool) -> void:
		visual_gate_changes.append(blocked)

	func _refresh_field_after_visual_event(semantic: String) -> void:
		field_resync_semantics.append(semantic)

	func _get_prize_slot_view(_player_index: int, _slot_index: int) -> BattleCardView:
		return _hidden_prize_slot


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
	opp_hand.visible = false
	var opp_hand_label := Label.new()
	opp_hand_label.position = Vector2(size.x * 0.42, 24)
	opp_hand_label.size = Vector2(size.x * 0.16, 48)
	scene.add_child(opp_hand_label)
	scene._opp_hand_lbl = opp_hand_label
	var my_prize_count := Label.new()
	my_prize_count.position = Vector2(24, size.y * 0.68)
	my_prize_count.size = Vector2(90, 54)
	scene.add_child(my_prize_count)
	scene._my_prize_hud_count = my_prize_count
	var opp_prize_count := Label.new()
	opp_prize_count.position = Vector2(24, size.y * 0.24)
	opp_prize_count.size = Vector2(90, 54)
	scene.add_child(opp_prize_count)
	scene._opp_prize_hud_count = opp_prize_count
	var hidden_prize := BattleCardView.new()
	hidden_prize.position = Vector2(size.x * 0.5, size.y * 0.5)
	hidden_prize.size = Vector2(82, 116)
	hidden_prize.visible = false
	scene.add_child(hidden_prize)
	scene._hidden_prize_slot = hidden_prize
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


func test_real_bench_knockout_removes_transfer_overlay_and_requests_committed_field_resync() -> String:
	var knocked_out_card := _card("Gholdengo ex")
	knocked_out_card.owner_index = 1
	var scene := _make_scene(Vector2(900, 1600))
	var opponent_bench_view := BattleCardView.new()
	opponent_bench_view.position = Vector2(300, 210)
	opponent_bench_view.size = Vector2(130, 182)
	opponent_bench_view.setup_from_instance(knocked_out_card, BattleCardView.MODE_SLOT_BENCH)
	scene.add_child(opponent_bench_view)
	scene._slot_card_views["opp_bench_0"] = opponent_bench_view
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	var controller: RefCounted = ControllerScript.new()
	controller.call("setup", scene)
	controller.call("enqueue_events", [
		{
			"kind": "zone_transfer",
			"semantic": "knockout",
			"player_index": 1,
			"owner_index": 1,
			"view_player": 0,
			"source_zone": "p1.bench.0.stack",
			"target_zone": "p1.discard",
			"visibility": "face",
			"cards": [knocked_out_card],
			"card_instance_ids": [knocked_out_card.instance_id],
			"count": 1,
		},
	])
	await tree.create_timer(1.8).timeout
	await tree.process_frame
	var transfer_overlay_count := 0
	for child: Node in scene.get_children():
		if child.name == "BattleVisualTransferOverlay":
			transfer_overlay_count += 1
	var result := run_checks([
		assert_eq(int(controller.call("pending_count")), 0, "Bench KO Tween should complete within the visual time bound"),
		assert_eq(transfer_overlay_count, 0, "Defeated Bench card clone must not remain above the committed field"),
		assert_eq(scene.field_resync_semantics, ["knockout"], "KO overlay completion must request one final committed field repaint"),
	])
	controller.call("clear", "test_end")
	scene.queue_free()
	await tree.process_frame
	return result


func test_hidden_opponent_hand_and_portrait_prize_use_visible_semantic_hud_anchors() -> String:
	var scene := _make_scene(Vector2(900, 1600))
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.add_child(overlay)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	var hand_rect: Rect2 = AnchorResolverScript.resolve_rect_in_overlay(scene, overlay, "p1.hand", 0)
	var expected_hand: Rect2 = BattleOverlayGeometry.control_rect_in_overlay(overlay, scene._opp_hand_lbl)
	var prize_rect: Rect2 = AnchorResolverScript.resolve_rect_in_overlay(scene, overlay, "p0.prize.0", 0)
	var expected_prize: Rect2 = BattleOverlayGeometry.control_rect_in_overlay(overlay, scene._my_prize_hud_count)
	var result := run_checks([
		assert_eq(hand_rect, expected_hand, "Hidden opponent hand should resolve to its visible hand-count HUD"),
		assert_eq(prize_rect, expected_prize, "Hidden portrait Prize slots should resolve to the visible Prize-count HUD"),
	])
	scene.queue_free()
	await tree.process_frame
	return result


func test_player_one_hidden_card_uses_absolute_owner_card_back_not_current_side_label() -> String:
	var scene := _make_scene(Vector2(900, 1600))
	scene._view_player = 1
	var player_image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	player_image.fill(Color.RED)
	var opponent_image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	opponent_image.fill(Color.BLUE)
	scene._player_card_back_texture = ImageTexture.create_from_image(player_image)
	scene._opponent_card_back_texture = ImageTexture.create_from_image(opponent_image)
	var animator: RefCounted = ZoneAnimatorScript.new()
	var view: BattleCardView = animator.call("_create_card_view", scene, {
		"visibility": "back",
		"player_index": 1,
		"owner_index": 1,
		"view_player": 1,
	}, null, Vector2(100, 140))
	return run_checks([
		assert_true(view.get("_back_texture") == scene._opponent_card_back_texture, "Player 1 always owns the opponent-back resource even when viewed as the local side"),
	])


func test_special_draw_reveal_uses_the_same_absolute_card_back_mapping() -> String:
	var scene := _make_scene(Vector2(900, 1600))
	scene._view_player = 1
	var player_image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	var opponent_image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	scene._player_card_back_texture = ImageTexture.create_from_image(player_image)
	scene._opponent_card_back_texture = ImageTexture.create_from_image(opponent_image)
	var controller: RefCounted = DrawRevealScript.new()
	return run_checks([
		assert_true(controller.call("_back_texture_for_player", scene, 0) == scene._player_card_back_texture, "Player 0 reveal should always use player-zero card back"),
		assert_true(controller.call("_back_texture_for_player", scene, 1) == scene._opponent_card_back_texture, "Player 1 reveal should always use player-one card back"),
	])


func test_portrait_motion_sizes_are_semantic_and_batch_safe() -> String:
	var scene := _make_scene(Vector2(900, 1600))
	scene._field_active_card_size = Vector2(210, 294)
	var animator: RefCounted = ZoneAnimatorScript.new()
	var energy_size: Vector2 = animator.call(
		"resolve_motion_card_size",
		scene,
		Rect2(Vector2.ZERO, Vector2(120, 168)),
		Rect2(Vector2(300, 500), Vector2(210, 294)),
		true,
		"attach_energy",
		1
	)
	var trainer_size: Vector2 = animator.call(
		"resolve_motion_card_size",
		scene,
		Rect2(Vector2.ZERO, Vector2(120, 168)),
		Rect2(Vector2(300, 500), Vector2(120, 168)),
		true,
		"trainer_play",
		1
	)
	var batch_size: Vector2 = animator.call(
		"resolve_motion_card_size",
		scene,
		Rect2(Vector2.ZERO, Vector2(120, 168)),
		Rect2(Vector2(300, 500), Vector2(120, 168)),
		true,
		"search",
		5
	)
	return run_checks([
		assert_true(energy_size.y < trainer_size.y, "Energy motion should not obscure the field at active-Pokemon size"),
		assert_true(batch_size.y < trainer_size.y, "Multi-card portrait batches should be smaller than one-card presentations"),
		assert_true(batch_size.y <= 180.0, "Five-card portrait motion should stay inside a compact safe size"),
	])


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
