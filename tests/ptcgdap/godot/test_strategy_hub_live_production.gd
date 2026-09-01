class_name TestStrategyHubLiveProduction
extends TestBase

const PRODUCTION_BASE_URL := "https://api.ptcg.skillserver.cn"
const HubScene = preload("res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn")


func test_default_strategy_hub_loads_the_production_ladder() -> String:
	if OS.get_environment("PTCGDAP_RUN_LIVE_PRODUCTION_TESTS") != "1":
		return ""
	var hub := HubScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(hub)
	var strategies := hub.get_node("%StrategyRankingList") as VBoxContainer
	var settled := await _wait_until_settled(strategies, tree)
	var base_url := str(hub.get("_base_url"))
	var profile_id := str(hub.get("_marketplace_ranking_profile_id"))
	var card_count := strategies.get_child_count()
	var release_buttons := strategies.find_children(
		"ContinuousLadderReleaseButton*", "Button", true, false
	)
	if not release_buttons.is_empty():
		(release_buttons[0] as Button).pressed.emit()
	var profile_loaded := await _wait_until_catalog_status_contains(
		hub, "策略档案已加载", tree
	)
	var match_title := (hub.get_node("%MatchHistoryTitle") as Label).text
	tree.root.remove_child(hub)
	hub.free()
	return run_checks([
		assert_eq(
			ProjectSettings.get_setting("ptcgdap/strategy_platform/base_url"),
			PRODUCTION_BASE_URL,
			"project production endpoint",
		),
		assert_eq(base_url, PRODUCTION_BASE_URL, "resolved StrategyHub endpoint"),
		assert_eq(profile_id, "godot_v18_ladder_v1", "continuous ladder profile"),
		assert_true(settled, "production leaderboard should settle over HTTPS"),
		assert_true(card_count > 0, "production leaderboard should render entries"),
		assert_true(not release_buttons.is_empty(), "production release should be clickable"),
		assert_true(profile_loaded, "production release profile should pass validation"),
		assert_true(match_title.begins_with("最近 "), "release profile should render matches"),
	])


func _wait_until_settled(list: VBoxContainer, tree: SceneTree) -> bool:
	var deadline := Time.get_ticks_msec() + 15_000
	while list.get_child_count() == 0 and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	return list.get_child_count() > 0


func _wait_until_catalog_status_contains(
	hub: Node, expected: String, tree: SceneTree
) -> bool:
	var deadline := Time.get_ticks_msec() + 15_000
	while Time.get_ticks_msec() < deadline:
		var statuses: Dictionary = hub.get("_workspace_statuses")
		var catalog: Dictionary = statuses.get("catalog", {})
		if expected in str(catalog.get("text", "")):
			return true
		await tree.process_frame
	return false
