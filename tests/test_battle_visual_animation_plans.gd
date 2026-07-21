class_name TestBattleVisualAnimationPlans
extends TestBase

const ZoneAnimatorScript := preload("res://scripts/ui/battle/visuals/BattleZoneTransferAnimator.gd")
const FeedbackAnimatorScript := preload("res://scripts/ui/battle/visuals/BattleStateFeedbackAnimator.gd")


class VisualAnchorScene extends Control:
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
	var _field_active_card_size := Vector2.ZERO
	var _player_card_back_texture: Texture2D = null
	var _opponent_card_back_texture: Texture2D = null


func test_zone_animator_builds_distinct_plans_for_all_card_lifecycle_semantics() -> String:
	var animator: RefCounted = ZoneAnimatorScript.new()
	var semantics := [
		"draw", "trainer_play", "evolve", "rare_candy", "attach_energy",
		"move_energy", "discard_energy", "knockout", "take_prize", "search",
		"mill", "lost_zone", "hand_reset", "redraw", "play_pokemon", "attach_tool",
	]
	var missing: Array[String] = []
	for semantic: String in semantics:
		var kind := "stack_change" if semantic in ["evolve", "rare_candy"] else "zone_transfer"
		var plan: Dictionary = animator.call("build_motion_plan", {
			"kind": kind,
			"semantic": semantic,
			"count": 8,
			"visibility": "back" if semantic == "hand_reset" else "face",
		}, Vector2(1600, 900), false)
		if str(plan.get("semantic", "")) != semantic or (plan.get("phases", []) as Array).is_empty():
			missing.append(semantic)
	return run_checks([
		assert_true(missing.is_empty(), "Every card lifecycle semantic needs a concrete motion plan: %s" % ", ".join(missing)),
		assert_eq(int((animator.call("build_motion_plan", {"kind": "zone_transfer", "semantic": "search", "count": 20}, Vector2(1600, 900), false) as Dictionary).get("visible_card_count", 0)), 5, "Large batches should cap full card views at five"),
		assert_true(bool((animator.call("build_motion_plan", {"kind": "zone_transfer", "semantic": "draw", "count": 3}, Vector2(900, 1600), true) as Dictionary).get("portrait", false)), "Portrait plans should be explicit"),
	])


func test_feedback_animator_covers_numeric_status_trigger_phase_and_result_events() -> String:
	var animator: RefCounted = FeedbackAnimatorScript.new()
	var cases := {
		"damage_delta": "damage",
		"heal_delta": "heal",
		"status_delta": "status",
		"trigger_pulse": "trigger",
		"shuffle": "shuffle",
		"phase_banner": "phase",
		"match_result": "result",
	}
	var missing: Array[String] = []
	for kind: String in cases:
		var plan: Dictionary = animator.call("build_feedback_plan", {
			"kind": kind,
			"amount": 30,
			"status": "poisoned",
			"semantic": "ability",
			"winner_index": 0,
			"reason": "all_prizes_taken",
		})
		if str(plan.get("style", "")) != str(cases[kind]) or float(plan.get("duration", 0.0)) <= 0.0:
			missing.append(kind)
	return assert_true(missing.is_empty(), "Every feedback event needs a non-zero concrete plan: %s" % ", ".join(missing))


func test_animation_plans_have_hard_time_bounds_and_do_not_offer_speed_tiers() -> String:
	var zone: RefCounted = ZoneAnimatorScript.new()
	var feedback: RefCounted = FeedbackAnimatorScript.new()
	var zone_plan: Dictionary = zone.call("build_motion_plan", {"kind": "zone_transfer", "semantic": "search", "count": 60}, Vector2(1600, 900), false)
	var result_plan: Dictionary = feedback.call("build_feedback_plan", {"kind": "match_result", "winner_index": 0})
	return run_checks([
		assert_true(float(zone_plan.get("total_duration", 99.0)) <= 1.5, "A card-transfer event must respect the hard event timeout"),
		assert_true(float(result_plan.get("duration", 99.0)) <= 1.5, "A feedback event must respect the hard event timeout"),
		assert_false(zone_plan.has("speed") or zone_plan.has("speed_tier"), "No animation speed tier belongs in the motion contract"),
		assert_false(result_plan.has("speed") or result_plan.has("speed_tier"), "No animation speed tier belongs in the feedback contract"),
	])


func test_evolution_anchor_prefers_exact_target_slot_over_stale_zone() -> String:
	var animator: RefCounted = ZoneAnimatorScript.new()
	var anchors: Dictionary = animator.call("resolve_anchor_keys", {
		"kind": "stack_change",
		"semantic": "evolve",
		"source_zone": "p0.hand",
		"target_zone": "p1.deck",
		"target_slot_key": "p0.bench.2",
	})
	return run_checks([
		assert_eq(str(anchors.get("source", "")), "p0.hand", "Evolution should still originate from the acting player's hand"),
		assert_eq(str(anchors.get("target", "")), "p0.bench.2", "Evolution must land on its exact Pokemon slot even if a stale generic zone is present"),
	])


func test_portrait_transfer_cards_and_feedback_use_phone_scale() -> String:
	var scene := VisualAnchorScene.new()
	scene.size = Vector2(900, 1600)
	scene._field_active_card_size = Vector2(210, 294)
	var zone: RefCounted = ZoneAnimatorScript.new()
	var feedback: RefCounted = FeedbackAnimatorScript.new()
	var portrait_card_size: Vector2 = zone.call(
		"resolve_motion_card_size",
		scene,
		Rect2(Vector2.ZERO, Vector2(90, 126)),
		Rect2(Vector2.ZERO, Vector2(900, 240)),
		true
	)
	var landscape_card_size: Vector2 = zone.call(
		"resolve_motion_card_size",
		scene,
		Rect2(Vector2.ZERO, Vector2(90, 126)),
		Rect2(Vector2.ZERO, Vector2(900, 240)),
		false
	)
	return run_checks([
		assert_eq(portrait_card_size, Vector2(210, 294), "Portrait card motion should match the field Active Pokemon size"),
		assert_eq(roundi(landscape_card_size.y), 126, "Landscape card motion should preserve the existing source-anchor scale"),
		assert_eq(float(feedback.call("visual_metric_scale", scene)), 2.0, "Portrait feedback text and pulses should use the phone readability scale"),
	])


func test_live_visual_animators_anchor_to_final_screen_positions_under_scene_transforms() -> String:
	var scene := VisualAnchorScene.new()
	scene.size = Vector2(1000, 700)
	scene.position = Vector2(145, 72)
	scene.rotation = 0.12
	scene.scale = Vector2(1.18, 0.84)
	var field_parent := Control.new()
	field_parent.position = Vector2(90, 80)
	field_parent.rotation = -0.08
	scene.add_child(field_parent)
	var deck := BattleCardView.new()
	deck.position = Vector2(720, 420)
	deck.size = Vector2(90, 126)
	field_parent.add_child(deck)
	scene._my_deck_preview = deck
	var hand := HBoxContainer.new()
	hand.position = Vector2(180, 560)
	hand.size = Vector2(560, 120)
	scene.add_child(hand)
	scene._hand_container = hand
	var active := BattleCardView.new()
	active.position = Vector2(420, 220)
	active.size = Vector2(128, 178)
	field_parent.add_child(active)
	scene._slot_card_views = {"my_active": active}
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame

	var card_data := CardData.new()
	card_data.name = "坐标测试卡"
	card_data.card_type = "Item"
	var card := CardInstance.create(card_data, 0)
	var zone: RefCounted = ZoneAnimatorScript.new()
	zone.call("play_event", scene, {
		"kind": "zone_transfer",
		"semantic": "draw",
		"source_zone": "p0.deck",
		"target_zone": "p0.hand",
		"cards": [card],
		"count": 1,
	}, Callable())
	var transfer_overlay := scene.get_node_or_null("BattleVisualTransferOverlay") as Control
	var moving_card := transfer_overlay.get_child(0) as Control if transfer_overlay != null and transfer_overlay.get_child_count() > 0 else null
	var deck_screen_center := deck.get_screen_transform() * (deck.size * 0.5)
	var moving_screen_center := moving_card.get_screen_transform() * (moving_card.size * 0.5) if moving_card != null else Vector2(-9999, -9999)

	var feedback: RefCounted = FeedbackAnimatorScript.new()
	feedback.call("play_event", scene, {
		"kind": "trigger_pulse",
		"source_slot_key": "p0.active",
		"semantic": "ability",
	}, Callable())
	var pulse: Control = null
	for child: Node in scene.get_children():
		var control := child as Control
		if control != null and control.z_index == 280:
			pulse = control
			break
	var active_screen_center := active.get_screen_transform() * (active.size * 0.5)
	var pulse_screen_center := pulse.get_screen_transform() * (pulse.size * 0.5) if pulse != null else Vector2(-9999, -9999)
	var result := run_checks([
		assert_true(moving_screen_center.distance_to(deck_screen_center) < 0.5, "Card transfer must begin at the source card's final screen center: moving=%s source=%s overlay=%s/%s card=%s/%s" % [moving_screen_center, deck_screen_center, transfer_overlay.position if transfer_overlay != null else Vector2.ZERO, transfer_overlay.size if transfer_overlay != null else Vector2.ZERO, moving_card.position if moving_card != null else Vector2.ZERO, moving_card.size if moving_card != null else Vector2.ZERO]),
		assert_true(pulse_screen_center.distance_to(active_screen_center) < 0.5, "State feedback must center on the Pokemon's final screen position: pulse=%s active=%s" % [pulse_screen_center, active_screen_center]),
	])
	zone.call("cancel_all")
	feedback.call("cancel_all")
	scene.queue_free()
	await tree.process_frame
	return result
