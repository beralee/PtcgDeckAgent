class_name TestBattleZoneChangeContract
extends TestBase

const ZoneChange := preload("res://scripts/engine/BattleZoneChangeContract.gd")


func test_typed_zone_change_exposes_exact_membership_and_projection_timing() -> String:
	var data: Dictionary = {}
	ZoneChange.append_to_data(
		data,
		0,
		ZoneChange.ZONE_DECK,
		ZoneChange.ZONE_HAND,
		[101, 202],
		ZoneChange.PROJECTION_IMMEDIATE
	)
	var action := GameAction.create(
		GameAction.ActionType.PUBLIC_REVEAL,
		0,
		data,
		3,
		"search"
	)
	var changes: Array = ZoneChange.changes_for_action(action)
	var change: Dictionary = changes[0] if not changes.is_empty() else {}

	return run_checks([
		assert_eq(changes.size(), 1, "One rule move must publish one typed zone change"),
		assert_eq(change.get("source_zone", ""), ZoneChange.ZONE_DECK, "The source zone must be explicit"),
		assert_eq(change.get("destination_zone", ""), ZoneChange.ZONE_HAND, "The destination zone must be explicit"),
		assert_eq(change.get("card_instance_ids", []), [101, 202], "The projection contract must track membership, not only count"),
		assert_true(ZoneChange.should_reconcile_hand_immediately(action, 0), "An immediate hand projection must reconcile on the action"),
		assert_false(ZoneChange.should_reconcile_hand_immediately(action, 1), "A player must not project the opponent's hidden hand"),
	])


func test_deferred_draw_and_prize_changes_do_not_project_before_their_visual_boundary() -> String:
	var draw_data: Dictionary = {}
	ZoneChange.append_to_data(
		draw_data,
		0,
		ZoneChange.ZONE_DECK,
		ZoneChange.ZONE_HAND,
		[301],
		ZoneChange.PROJECTION_AFTER_REVEAL
	)
	var draw_action := GameAction.create(GameAction.ActionType.DRAW_CARD, 0, draw_data, 4, "draw")
	var prize_data: Dictionary = {}
	ZoneChange.append_to_data(
		prize_data,
		0,
		ZoneChange.ZONE_PRIZES,
		ZoneChange.ZONE_HAND,
		[401],
		ZoneChange.PROJECTION_AFTER_PRESENTATION
	)
	var prize_action := GameAction.create(GameAction.ActionType.TAKE_PRIZE, 0, prize_data, 4, "prize")

	return run_checks([
		assert_false(ZoneChange.should_reconcile_hand_immediately(draw_action, 0), "A draw must wait for its reveal boundary"),
		assert_false(ZoneChange.should_reconcile_hand_immediately(prize_action, 0), "A prize must wait for its flip boundary"),
		assert_true(ZoneChange.action_changes_zone(prize_action, 0, ZoneChange.ZONE_PRIZES, ZoneChange.ZONE_HAND), "Deferred changes must remain machine-readable"),
	])


func test_legacy_public_search_replays_keep_the_same_projection_semantics() -> String:
	var legacy_action := GameAction.create(
		GameAction.ActionType.PUBLIC_REVEAL,
		0,
		{
			"source_zone": "deck",
			"destination_zone": "hand",
			"public_result_kind": "search_to_hand",
		},
		1,
		"legacy search"
	)

	return run_checks([
		assert_true(ZoneChange.should_reconcile_hand_immediately(legacy_action, 0), "Saved search-to-hand actions must remain compatible"),
		assert_true(ZoneChange.action_changes_zone(legacy_action, 0, ZoneChange.ZONE_DECK, ZoneChange.ZONE_HAND), "Legacy source/destination metadata must remain queryable"),
	])
