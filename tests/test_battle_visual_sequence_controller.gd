class_name TestBattleVisualSequenceController
extends TestBase

const SnapshotScript := preload("res://scripts/ui/battle/visuals/BattleVisualSnapshot.gd")
const ControllerScript := preload("res://scripts/ui/battle/visuals/BattleVisualSequenceController.gd")


class FakeAnimator extends RefCounted:
	var started: Array[String] = []
	var callbacks: Array[Callable] = []
	var cancel_calls := 0

	func handles(_event: Dictionary) -> bool:
		return true

	func play_event(_scene: Object, event: Dictionary, completed: Callable) -> void:
		started.append(str(event.get("kind", "")))
		callbacks.append(completed)

	func finish_next() -> void:
		if callbacks.is_empty():
			return
		var callback: Callable = callbacks.pop_front()
		if callback.is_valid():
			callback.call()

	func cancel_all() -> void:
		cancel_calls += 1
		callbacks.clear()


class FakeScene extends Control:
	var _view_player := 0
	var visual_gate_changes: Array[bool] = []
	var field_resync_semantics: Array[String] = []
	var visual_sequence_idle_calls := 0

	func _set_battle_visual_input_blocked(blocked: bool) -> void:
		visual_gate_changes.append(blocked)

	func _on_battle_visual_sequence_idle() -> void:
		visual_sequence_idle_calls += 1

	func _refresh_field_after_visual_event(semantic: String) -> void:
		field_resync_semantics.append(semantic)


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	return state


func _card(name: String, owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = "Item"
	return CardInstance.create(data, owner)


func test_queue_runs_one_event_at_a_time_and_releases_input_after_the_last_completion() -> String:
	var scene := FakeScene.new()
	var animator := FakeAnimator.new()
	var controller: RefCounted = ControllerScript.new()
	controller.call("setup", scene)
	controller.call("set_animators_for_tests", animator, animator)
	controller.call("enqueue_events", [
		{"kind": "zone_transfer", "sequence_group": "a"},
		{"kind": "damage_delta", "sequence_group": "a"},
	])
	var only_first_started := animator.started == ["zone_transfer"]
	animator.finish_next()
	var second_started_after_first := animator.started == ["zone_transfer", "damage_delta"]
	animator.finish_next()
	var result := run_checks([
		assert_true(only_first_started, "Queue must not overlap independent main events"),
		assert_true(second_started_after_first, "Second event should begin only after first completion"),
		assert_eq(int(controller.call("pending_count")), 0, "Queue should be empty after both callbacks"),
		assert_false(bool(controller.call("is_active")), "Controller should become idle"),
		assert_eq(scene.visual_gate_changes, [true, false], "Input gate should cover the whole sequence exactly once"),
		assert_eq(scene.visual_sequence_idle_calls, 1, "Normal queue drain should notify the battle runtime exactly once"),
	])
	scene.free()

	return result


func test_visual_sequence_does_not_report_idle_between_queued_actions() -> String:
	var scene := FakeScene.new()
	var animator := FakeAnimator.new()
	var controller: RefCounted = ControllerScript.new()
	controller.call("setup", scene)
	controller.call("set_animators_for_tests", animator, animator)
	controller.call("enqueue_events", [
		{"kind": "zone_transfer", "player_index": 1, "card_names": ["Opponent old card"]},
	])
	controller.call("enqueue_events", [
		{"kind": "stack_change", "semantic": "evolve", "player_index": 0, "card_names": ["Charizard ex"]},
	])

	animator.finish_next()
	var calls_between_events := scene.visual_sequence_idle_calls
	animator.finish_next()
	var result := run_checks([
		assert_eq(calls_between_events, 0, "A queued opponent visual must finish before a later Evolution can begin"),
		assert_eq(scene.visual_sequence_idle_calls, 1, "Only the fully drained sequence may resume gameplay"),
		assert_eq(animator.started, ["zone_transfer", "stack_change"], "Card events must retain their original action order"),
	])
	scene.free()
	return result


func test_knockout_completion_resyncs_field_after_transfer_overlay_is_removed() -> String:
	var scene := FakeScene.new()
	var animator := FakeAnimator.new()
	var controller: RefCounted = ControllerScript.new()
	controller.call("setup", scene)
	controller.call("set_animators_for_tests", animator, animator)
	controller.call("enqueue_events", [
		{
			"kind": "zone_transfer",
			"semantic": "knockout",
			"source_zone": "p1.bench.0.stack",
			"target_zone": "p1.discard",
		},
	])
	animator.finish_next()
	var result := run_checks([
		assert_eq(
			scene.field_resync_semantics,
			["knockout"],
			"A completed Bench KO animation must repaint the committed field so the defeated card cannot remain visible"
		),
		assert_eq(int(controller.call("pending_count")), 0, "KO visual sequence should still finish normally"),
		assert_false(bool(controller.call("is_active")), "KO field resync must not leave the visual controller active"),
	])
	scene.free()
	return result


func test_bench_damage_completion_resyncs_hp_after_floating_number_finishes() -> String:
	var scene := FakeScene.new()
	var animator := FakeAnimator.new()
	var controller: RefCounted = ControllerScript.new()
	controller.call("setup", scene)
	controller.call("set_animators_for_tests", animator, animator)
	controller.call("enqueue_events", [
		{
			"kind": "damage_delta",
			"player_index": 1,
			"slot_key": "p1.bench.0",
			"amount": 120,
			"before_damage": 0,
			"after_damage": 120,
		},
	])

	animator.finish_next()
	var result := run_checks([
		assert_eq(
			scene.field_resync_semantics,
			["damage_delta"],
			"Scream Tail and Grimmsnarl Bench damage must repaint HP after the floating damage number"
		),
		assert_eq(int(controller.call("pending_count")), 0, "Bench-damage feedback should still finish normally"),
		assert_false(bool(controller.call("is_active")), "Bench HP resync must not keep the visual queue active"),
	])
	scene.free()
	return result


func test_clear_invalidates_stale_callbacks_and_never_starts_removed_events() -> String:
	var scene := FakeScene.new()
	var animator := FakeAnimator.new()
	var controller: RefCounted = ControllerScript.new()
	controller.call("setup", scene)
	controller.call("set_animators_for_tests", animator, animator)
	controller.call("enqueue_events", [
		{"kind": "zone_transfer"},
		{"kind": "match_result"},
	])
	var stale_callback: Callable = animator.callbacks[0]
	controller.call("clear", "scene_exit")
	if stale_callback.is_valid():
		stale_callback.call()
	var result := run_checks([
		assert_eq(animator.started, ["zone_transfer"], "Cleared queued events must never start"),
		assert_eq(int(controller.call("pending_count")), 0, "Clear should remove the active and queued work"),
		assert_false(bool(controller.call("is_active")), "Clear should return to idle"),
		assert_eq(scene.visual_gate_changes, [true, false], "Clear should release input even if a Tween callback arrives late"),
		assert_eq(
			scene.visual_sequence_idle_calls,
			1,
			"Cancelling a busy visual sequence must wake the AI exactly like normal queue drain"
		),
	])
	scene.free()
	return result


func test_stalled_iono_hand_reset_times_out_then_finishes_redraw_and_shuffle() -> String:
	var scene := FakeScene.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	var animator := FakeAnimator.new()
	var controller: RefCounted = ControllerScript.new()
	controller.call("setup", scene)
	controller.call("set_animators_for_tests", animator, animator)
	controller.call("set_event_timeout_seconds_for_tests", 0.05)
	controller.call("enqueue_events", [
		{"kind": "zone_transfer", "semantic": "hand_reset", "player_index": 1},
		{"kind": "zone_transfer", "semantic": "redraw", "player_index": 1},
		{"kind": "shuffle", "player_index": 1, "zone": "p1.deck"},
	])

	await tree.create_timer(0.07).timeout
	var redraw_started_after_timeout := animator.started == ["zone_transfer", "zone_transfer"]
	animator.finish_next()
	var shuffle_started_after_redraw := animator.started == ["zone_transfer", "zone_transfer", "shuffle"]
	animator.finish_next()
	var result := run_checks([
		assert_eq(animator.cancel_calls, 1, "A stalled Iono hand-reset Tween must be cancelled and cleaned up"),
		assert_true(redraw_started_after_timeout, "Timeout recovery must continue with Iono's committed redraw animation"),
		assert_true(shuffle_started_after_redraw, "The shuffle feedback must still run after the recovered redraw"),
		assert_eq(int(controller.call("pending_count")), 0, "The recovered Iono visual sequence must fully drain"),
		assert_false(bool(controller.call("is_active")), "The visual queue must become idle after timeout recovery"),
		assert_eq(scene.visual_gate_changes, [true, false], "Timeout recovery must release the visual input gate"),
		assert_eq(scene.field_resync_semantics, ["visual_timeout"], "Timeout recovery must repaint the committed board state"),
		assert_eq(scene.visual_sequence_idle_calls, 1, "Timeout recovery must wake the waiting AI continuation"),
	])
	scene.queue_free()
	await tree.process_frame
	return result


func test_action_capture_and_refresh_fallback_deduplicate_the_same_state_transition() -> String:
	var state := _state()
	var card := _card("Drawn")
	state.players[0].deck = [card]
	var animator := FakeAnimator.new()
	var controller: RefCounted = ControllerScript.new()
	var scene := FakeScene.new()
	controller.call("setup", scene)
	controller.call("set_animators_for_tests", animator, animator)
	controller.call("prime_snapshot", state, 0)
	state.players[0].deck.clear()
	state.players[0].hand.append(card)
	var action := GameAction.create(GameAction.ActionType.DRAW_CARD, 0, {"count": 1}, 2, "draw")
	var action_events: Array = controller.call("capture_action", action, state, 0)
	var fallback_events: Array = controller.call("sync_after_refresh", state, 0)

	var result := run_checks([
		assert_eq(action_events.size(), 1, "Action transition should submit its visual event"),
		assert_true(fallback_events.is_empty(), "Refresh of the same committed snapshot must not submit a duplicate"),
		assert_eq(int(controller.call("submitted_event_count")), 1, "Only one event should be recorded for the transition"),
	])
	controller.call("clear", "test_end")
	scene.free()
	return result


func test_actionless_refresh_updates_baseline_without_guessing_card_flights() -> String:
	var state := _state()
	var unrelated := _card("Unlogged Opponent Card", 1)
	state.players[1].deck = [unrelated]
	var animator := FakeAnimator.new()
	var controller: RefCounted = ControllerScript.new()
	var scene := FakeScene.new()
	controller.call("setup", scene)
	controller.call("set_animators_for_tests", animator, animator)
	controller.call("prime_snapshot", state, 0)

	state.players[1].deck.clear()
	state.players[1].discard_pile.append(unrelated)
	var first_refresh_events: Array = controller.call("sync_after_refresh", state, 0)
	var second_refresh_events: Array = controller.call("sync_after_refresh", state, 0)
	var card_motion_kinds := ["zone_transfer", "stack_change", "field_move"]
	var guessed_card_events: Array = first_refresh_events.filter(func(event: Dictionary) -> bool:
		return str(event.get("kind", "")) in card_motion_kinds
	)
	var result := run_checks([
		assert_true(guessed_card_events.is_empty(), "A UI refresh without a GameAction must never guess which card should fly"),
		assert_true(second_refresh_events.is_empty(), "The silent refresh must still advance the visual baseline"),
		assert_true(animator.started.is_empty(), "No unlogged card may appear in a transfer overlay"),
	])
	controller.call("clear", "test_end")
	scene.free()
	return result


func test_visual_controller_never_mutates_game_state_or_action_log() -> String:
	var state := _state()
	var card := _card("Stable")
	state.players[0].hand = [card]
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var before: Dictionary = SnapshotScript.capture(state)
	var log_before := gsm.action_log.duplicate(true)
	var animator := FakeAnimator.new()
	var controller: RefCounted = ControllerScript.new()
	var scene := FakeScene.new()
	controller.call("setup", scene)
	controller.call("set_animators_for_tests", animator, animator)
	controller.call("prime_snapshot", state, 0)
	controller.call("enqueue_events", [
		{"kind": "trigger_pulse", "label": "Presentation only"},
		{"kind": "damage_delta", "amount": 90},
	])
	animator.finish_next()
	animator.finish_next()
	var after: Dictionary = SnapshotScript.capture(state)

	var result := run_checks([
		assert_eq(after, before, "Playing visual events must leave every captured rule field unchanged"),
		assert_eq(gsm.action_log, log_before, "Visual events must not append or rewrite rule actions"),
	])
	controller.call("clear", "test_end")
	scene.free()
	return result


func test_nested_draw_keeps_temporarily_missing_trainer_identity_for_final_play_animation() -> String:
	var state := _state()
	var trainer := _card("Professor")
	var drawn := _card("Drawn")
	state.players[0].hand = [trainer]
	state.players[0].deck = [drawn]
	var scene := FakeScene.new()
	var animator := FakeAnimator.new()
	var controller: RefCounted = ControllerScript.new()
	controller.call("setup", scene)
	controller.call("set_animators_for_tests", animator, animator)
	controller.call("prime_snapshot", state, 0)

	state.players[0].hand.clear()
	state.players[0].deck.clear()
	state.players[0].hand.append(drawn)
	controller.call(
		"capture_action",
		GameAction.create(GameAction.ActionType.DRAW_CARD, 0, {"count": 1}, 2, "nested draw"),
		state,
		0,
		["*"]
	)
	state.players[0].discard_pile.append(trainer)
	var final_events: Array = controller.call(
		"capture_action",
		GameAction.create(GameAction.ActionType.PLAY_TRAINER, 0, {"card_name": "Professor"}, 2, "trainer"),
		state,
		0
	)
	var trainer_events := _events_with_semantic(final_events, "trainer_play")
	var result := run_checks([
		assert_eq(trainer_events.size(), 1, "Final PLAY_TRAINER log should recover the card's original hand location"),
		assert_eq(trainer_events[0].get("card_instance_ids", []) if not trainer_events.is_empty() else [], [trainer.instance_id], "Recovered movement should use the exact Trainer instance"),
	])
	controller.call("clear", "test_end")
	scene.free()
	return result


func test_queue_compaction_preserves_exact_cards_names_visibility_owner_and_semantic() -> String:
	var controller: RefCounted = ControllerScript.new()
	var card_a := _card("A", 1)
	var card_b := _card("B", 1)
	var left := {
		"kind": "zone_transfer",
		"semantic": "search",
		"player_index": 1,
		"owner_index": 1,
		"view_player": 0,
		"source_zone": "p1.deck",
		"target_zone": "p1.hand",
		"visibility": "back",
		"count": 1,
		"card_instance_ids": [card_a.instance_id],
		"cards": [card_a],
		"card_names": ["A"],
	}
	var right := left.duplicate(true)
	right["count"] = 1
	right["card_instance_ids"] = [card_b.instance_id]
	right["cards"] = [card_b]
	right["card_names"] = ["B"]
	var merged: Dictionary = controller.call("_merge_compatible_events", left, right)
	var incompatible := right.duplicate(true)
	incompatible["semantic"] = "draw"
	return run_checks([
		assert_eq(int(merged.get("count", 0)), 2, "Compaction should preserve the total card count"),
		assert_eq(merged.get("card_instance_ids", []), [card_a.instance_id, card_b.instance_id], "Compaction should preserve exact instance order"),
		assert_eq((merged.get("cards", []) as Array).size(), 2, "Compaction should preserve all visible CardInstance references"),
		assert_eq(merged.get("card_names", []), ["A", "B"], "Compaction should preserve visible card names"),
		assert_true(bool(controller.call("_can_merge", left, right)), "Identical motion contracts should be mergeable"),
		assert_false(bool(controller.call("_can_merge", left, incompatible)), "Different semantics must never collapse into one misleading animation"),
	])


func test_view_change_clears_active_and_queued_visuals_before_the_new_side_is_rendered() -> String:
	var state := _state()
	var scene := FakeScene.new()
	var animator := FakeAnimator.new()
	var controller: RefCounted = ControllerScript.new()
	controller.call("setup", scene)
	controller.call("set_animators_for_tests", animator, animator)
	controller.call("prime_snapshot", state, 0)
	controller.call("enqueue_events", [
		{"kind": "zone_transfer", "view_player": 0},
		{"kind": "damage_delta", "view_player": 0},
	])
	scene._view_player = 1
	controller.call("sync_after_refresh", state, 1)
	var result := run_checks([
		assert_eq(int(controller.call("pending_count")), 0, "Perspective changes must invalidate old-side animations"),
		assert_false(bool(controller.call("is_active")), "No old-side Tween may survive a handover"),
		assert_eq(scene.visual_gate_changes.slice(scene.visual_gate_changes.size() - 2), [true, false], "Perspective invalidation must release only the animation input gate"),
	])
	scene.free()
	return result


func test_scene_resize_cancels_only_pending_visual_playback() -> String:
	var scene := FakeScene.new()
	scene.size = Vector2(900, 1600)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	var animator := FakeAnimator.new()
	var controller: RefCounted = ControllerScript.new()
	controller.call("setup", scene)
	controller.call("set_animators_for_tests", animator, animator)
	controller.call("enqueue_events", [
		{"kind": "zone_transfer", "view_player": 0},
		{"kind": "damage_delta", "view_player": 0},
	])
	scene.size = Vector2(1600, 900)
	await tree.process_frame
	var result := run_checks([
		assert_eq(int(controller.call("pending_count")), 0, "A viewport/layout resize must invalidate old geometry"),
		assert_false(bool(controller.call("is_active")), "No Tween using pre-resize coordinates may remain active"),
		assert_eq(scene.visual_gate_changes.slice(scene.visual_gate_changes.size() - 2), [true, false], "Resize cancellation must release only the visual input gate"),
	])
	scene.queue_free()
	await tree.process_frame
	return result


func _events_with_semantic(events: Array, semantic: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event_variant: Variant in events:
		if event_variant is Dictionary and str((event_variant as Dictionary).get("semantic", "")) == semantic:
			result.append(event_variant as Dictionary)
	return result
