class_name TestBattleSceneLifecycle
extends TestBase

const BattleSceneScript := preload("res://scenes/battle/BattleScene.gd")
const BattleScenePacked := preload("res://scenes/battle/BattleScene.tscn")


class FakeBattleAsyncService extends RefCounted:
	signal status_changed(status: String, context: Dictionary)
	signal review_completed(review: Dictionary)
	signal advice_completed(result: Dictionary)
	signal quick_review_completed(result: Dictionary)


class FakeLlmStrategy extends RefCounted:
	signal llm_thinking_started(turn_number: int)
	signal llm_thinking_finished(turn_number: int, plan: Dictionary, reasoning: String)
	signal llm_thinking_failed(turn_number: int, reason: String)


class FakeAiOpponent extends RefCounted:
	var _deck_strategy: RefCounted = null

	func _init(strategy: RefCounted) -> void:
		_deck_strategy = strategy


func test_runtime_cleanup_releases_async_refs_and_dynamic_nodes() -> String:
	var scene := BattleSceneScript.new()
	var review_service := FakeBattleAsyncService.new()
	var advice_service := FakeBattleAsyncService.new()
	var match_end_service := FakeBattleAsyncService.new()
	var strategy := FakeLlmStrategy.new()
	var ai_opponent := FakeAiOpponent.new(strategy)
	var slot_timer := Timer.new()
	var draw_overlay := Control.new()
	var attack_overlay := Control.new()
	var ready_overlay := Control.new()
	var reveal_card := BattleCardView.new()

	scene.add_child(slot_timer)
	scene.add_child(draw_overlay)
	scene.add_child(attack_overlay)
	scene.add_child(ready_overlay)
	draw_overlay.add_child(reveal_card)

	review_service.status_changed.connect(Callable(scene, "_on_battle_review_status_changed"))
	review_service.review_completed.connect(Callable(scene, "_on_battle_review_completed"))
	advice_service.status_changed.connect(Callable(scene, "_on_battle_advice_status_changed"))
	advice_service.advice_completed.connect(Callable(scene, "_on_battle_advice_completed"))
	match_end_service.status_changed.connect(Callable(scene, "_on_match_end_quick_review_status_changed"))
	match_end_service.quick_review_completed.connect(Callable(scene, "_on_match_end_quick_review_completed"))
	strategy.llm_thinking_started.connect(Callable(scene, "_on_llm_thinking_started"))
	strategy.llm_thinking_finished.connect(Callable(scene, "_on_llm_thinking_finished"))
	strategy.llm_thinking_failed.connect(Callable(scene, "_on_llm_thinking_failed"))

	scene.set("_battle_review_service", review_service)
	scene.set("_battle_advice_service", advice_service)
	scene.set("_match_end_quick_review_service", match_end_service)
	scene.set("_ai_opponent", ai_opponent)
	scene.set("_slot_touch_long_press_timer", slot_timer)
	scene.set("_draw_reveal_overlay", draw_overlay)
	scene.set("_attack_vfx_overlay", attack_overlay)
	scene.set("_ready_vfx_overlay", ready_overlay)
	scene.set("_draw_reveal_card_views", [reveal_card])
	scene.set("_draw_reveal_queue", [GameAction.new()])
	scene.set("_pending_handover_action", Callable(scene, "_on_end_turn"))
	scene.set("_pending_attack_vfx_completion_action", Callable(scene, "_on_end_turn"))
	scene.set("_battle_review_last_review", {"large": ["payload"]})
	scene.set("_battle_advice_initial_snapshot", {"state": ["payload"]})

	scene.call("_release_battle_runtime_resources")

	var pending_handover: Callable = scene.get("_pending_handover_action")
	var pending_attack_vfx: Callable = scene.get("_pending_attack_vfx_completion_action")
	var reveal_views: Array = scene.get("_draw_reveal_card_views")
	var reveal_queue: Array = scene.get("_draw_reveal_queue")
	var review_payload: Dictionary = scene.get("_battle_review_last_review")
	var advice_snapshot: Dictionary = scene.get("_battle_advice_initial_snapshot")

	var checks: Array[String] = [
		assert_false(review_service.is_connected("status_changed", Callable(scene, "_on_battle_review_status_changed")), "Battle review status signal should disconnect during BattleScene cleanup"),
		assert_false(review_service.is_connected("review_completed", Callable(scene, "_on_battle_review_completed")), "Battle review completion signal should disconnect during BattleScene cleanup"),
		assert_false(advice_service.is_connected("status_changed", Callable(scene, "_on_battle_advice_status_changed")), "Battle advice status signal should disconnect during BattleScene cleanup"),
		assert_false(advice_service.is_connected("advice_completed", Callable(scene, "_on_battle_advice_completed")), "Battle advice completion signal should disconnect during BattleScene cleanup"),
		assert_false(match_end_service.is_connected("status_changed", Callable(scene, "_on_match_end_quick_review_status_changed")), "Match-end review status signal should disconnect during BattleScene cleanup"),
		assert_false(match_end_service.is_connected("quick_review_completed", Callable(scene, "_on_match_end_quick_review_completed")), "Match-end review completion signal should disconnect during BattleScene cleanup"),
		assert_false(strategy.is_connected("llm_thinking_started", Callable(scene, "_on_llm_thinking_started")), "LLM started signal should disconnect during BattleScene cleanup"),
		assert_false(strategy.is_connected("llm_thinking_finished", Callable(scene, "_on_llm_thinking_finished")), "LLM finished signal should disconnect during BattleScene cleanup"),
		assert_false(strategy.is_connected("llm_thinking_failed", Callable(scene, "_on_llm_thinking_failed")), "LLM failed signal should disconnect during BattleScene cleanup"),
		assert_null(scene.get("_battle_review_service"), "Battle review service ref should clear during cleanup"),
		assert_null(scene.get("_battle_advice_service"), "Battle advice service ref should clear during cleanup"),
		assert_null(scene.get("_match_end_quick_review_service"), "Match-end quick review service ref should clear during cleanup"),
		assert_null(scene.get("_ai_opponent"), "AI opponent ref should clear during cleanup"),
		assert_null(scene.get("_slot_touch_long_press_timer"), "Slot long-press timer ref should clear during cleanup"),
		assert_null(scene.get("_draw_reveal_overlay"), "Draw reveal overlay ref should clear during cleanup"),
		assert_null(scene.get("_attack_vfx_overlay"), "Attack VFX overlay ref should clear during cleanup"),
		assert_null(scene.get("_ready_vfx_overlay"), "Ready VFX overlay ref should clear during cleanup"),
		assert_true(slot_timer.is_queued_for_deletion(), "Slot long-press timer node should be queued for deletion"),
		assert_true(draw_overlay.is_queued_for_deletion(), "Draw reveal overlay should be queued for deletion"),
		assert_true(attack_overlay.is_queued_for_deletion(), "Attack VFX overlay should be queued for deletion"),
		assert_true(ready_overlay.is_queued_for_deletion(), "Ready VFX overlay should be queued for deletion"),
		assert_eq(reveal_views.size(), 0, "Draw reveal card refs should clear during cleanup"),
		assert_eq(reveal_queue.size(), 0, "Draw reveal queue should clear during cleanup"),
		assert_false(pending_handover.is_valid(), "Pending handover callable should be cleared"),
		assert_false(pending_attack_vfx.is_valid(), "Pending attack VFX completion callable should be cleared"),
		assert_eq(review_payload.size(), 0, "Cached battle review payload should clear during cleanup"),
		assert_eq(advice_snapshot.size(), 0, "Battle advice snapshot should clear during cleanup"),
	]
	var result := run_checks(checks)
	scene.free()
	return result


func test_battle_scene_review_instances_release_after_tree_lifecycle() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return "SceneTree is required for BattleScene lifecycle checks"
	var weak_refs: Array[WeakRef] = []
	for _i: int in 3:
		var scene: Control = BattleScenePacked.instantiate()
		scene.set("_battle_mode", "review_readonly")
		tree.root.add_child(scene)
		await tree.process_frame
		await tree.process_frame
		weak_refs.append(weakref(scene))
		scene.queue_free()
		await tree.process_frame
		await tree.process_frame

	var live_count := 0
	for ref: WeakRef in weak_refs:
		if ref.get_ref() != null:
			live_count += 1
	return assert_eq(live_count, 0, "BattleScene instances should release after queue_free and cleanup")
