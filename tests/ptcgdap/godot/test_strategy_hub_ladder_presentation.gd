extends TestBase

const HubScene = preload("res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn")
const Harness = preload("res://tests/ui/UiCompatibilityHarness.gd")


func test_ladder_tab_name_survives_desktop_phone_and_resize() -> String:
	var hub := HubScene.instantiate()
	var checks: Array[String] = []
	for layout: Dictionary in [{"size": Vector2(1600, 900), "mode": "landscape"},
		{"size": Vector2(390, 844), "mode": "portrait"},
		{"size": Vector2(1600, 900), "mode": "landscape"}]:
		hub.call("apply_non_battle_layout_for_test", layout.size, layout.mode)
		checks.append(assert_eq(hub.get_node("%CatalogTab").text, "AI天梯"))
	hub.free()
	return run_checks(checks)


func test_rank_honors_use_server_rank_not_row_position() -> String:
	var hub := HubScene.instantiate()
	hub.call("apply_continuous_ladder_leaderboard_for_test", _ranked_items(), "test")
	var cards := hub.get_node("%StrategyRankingList").get_children()
	var expected := ["#1 · 榜首", "#2 · 第二名", "#3 · 第三名", "#24", "未排名"]
	var colors: Array[Color] = []
	var checks: Array[String] = []
	for i: int in cards.size():
		var badge := cards[i].find_child("LadderRankLabel", true, false) as Label
		checks.append(assert_not_null(badge, "Every ranked card needs a visible rank"))
		if badge == null:
			continue
		checks.append(assert_eq(badge.text, expected[i]))
		checks.append(assert_eq(badge.mouse_filter, Control.MOUSE_FILTER_IGNORE))
		var style: StyleBoxFlat = cards[i].get_theme_stylebox("panel")
		checks.append(assert_eq(style.border_width_left, 3 if i < 3 else 1))
		if i < 3:
			colors.append(style.border_color)
	if colors.size() == 3:
		checks.append(assert_true(colors[0] != colors[1] and colors[1] != colors[2] and colors[0] != colors[2]))
	# Pagination and unknown ranks cannot manufacture a podium finish.
	hub.call("apply_continuous_ladder_leaderboard_for_test", [_ranked_items()[3]], "test")
	var page_badge := hub.get_node("%StrategyRankingList").find_child("LadderRankLabel", true, false) as Label
	if page_badge != null:
		checks.append(assert_eq(page_badge.text, "#24"))
	hub.free()
	return run_checks(checks)


func test_phone_keeps_author_score_and_provisional_status() -> String:
	var hub := HubScene.instantiate()
	hub.call("apply_non_battle_layout_for_test", Vector2(390, 844), "portrait")
	hub.call("apply_continuous_ladder_leaderboard_for_test", [_ranked_items()[0]], "test")
	var info := hub.find_child("ContinuousLadderReleaseButton", true, false) as Button
	var checks := run_checks([
		assert_str_contains(info.text, "开发者小明"),
		assert_str_contains(info.text, "1234.50"),
		assert_str_contains(info.text, "暂定"),
		assert_eq(info.get_meta("continuous_ladder_release").release_id, "rank.1"),
	])
	hub.free()
	return checks


func test_snapshot_rankings_have_honors_but_latest_has_no_fake_rank() -> String:
	var hub := HubScene.instantiate()
	var item: Dictionary = _ranked_items()[0]
	hub.call("apply_marketplace_strategy_rankings_for_test", [item], null, "snapshot")
	var checks: Array[String] = [assert_not_null(hub.get_node("%StrategyRankingList").find_child("LadderRankLabel", true, false))]
	hub.call("apply_marketplace_latest_for_test", [item], null)
	checks.append(assert_true(hub.get_node("%StrategyList").find_child("LadderRankLabel", true, false) == null))
	hub.free()
	return run_checks(checks)


func test_rank_header_and_card_drag_scroll_without_opening_strategy() -> String:
	var checks: Array[String] = []
	for profile: Dictionary in [Harness.PROFILES[0], Harness.PROFILES[1]]:
		var h := Harness.new()
		await h.mount(HubScene, profile)
		h.scene.call("apply_continuous_ladder_leaderboard_for_test", _ranked_items() + _ranked_items(), "test")
		await h.select_workspace("catalog")
		var scroll := h.scene.get_node("%CatalogWorkspace") as ScrollContainer
		var card := h.scene.get_node("%StrategyRankingList").get_child(1)
		var info := card.find_child("ContinuousLadderReleaseButton", true, false) as Button
		var badge := card.find_child("LadderRankLabel", true, false) as Label
		var clicks := [0]
		info.pressed.connect(func() -> void: clicks[0] += 1)
		for source: Control in [badge, info]:
			scroll.scroll_vertical = 0
			await h.settle()
			var origin := source.get_global_rect().get_center()
			await h.swipe(origin, origin - Vector2(0, 160))
			checks.append(assert_true(scroll.scroll_vertical > 60, profile.id + ": rank decoration must not capture scrolling"))
			checks.append(assert_eq(clicks[0], 0, "Dragging must not open a strategy"))
		scroll.scroll_vertical = 0
		await h.settle()
		var tap := info.get_global_rect().get_center()
		h.touch(true, tap)
		h.touch(false, tap)
		checks.append(assert_eq(clicks[0], 1, "A tap still opens the strategy exactly once"))
		await h.dispose()
	return run_checks(checks)


func test_ranked_cards_fit_phone_and_desktop_with_long_names() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var checks: Array[String] = []
	for viewport_size: Vector2i in [Vector2i(390, 844), Vector2i(1600, 900)]:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		tree.root.add_child(viewport)
		var hub := HubScene.instantiate()
		hub.set("_skip_service_initialization_for_tests", true)
		viewport.add_child(hub)
		for frame: int in 5:
			await tree.process_frame
		hub.call("apply_non_battle_layout_for_test", Vector2(viewport_size), "portrait" if viewport_size.x < 500 else "landscape")
		hub.call("apply_continuous_ladder_leaderboard_for_test", _ranked_items(), "test")
		hub.call("select_workspace_for_test", "catalog")
		for frame: int in 8:
			await tree.process_frame
		var tab := hub.get_node("%CatalogTab") as Button
		var tab_style := tab.get_theme_stylebox("normal")
		var text_width := tab.get_theme_font("font").get_string_size(tab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tab.get_theme_font_size("font_size")).x
		checks.append(assert_true(text_width <= tab.size.x - tab_style.get_minimum_size().x, "AI天梯 must fit on one line"))
		for card: Control in hub.get_node("%StrategyRankingList").get_children():
			checks.append(assert_true(card.get_global_rect().end.x <= viewport_size.x + 0.5, "Card exceeds viewport"))
			var badge := card.find_child("LadderRankLabel", true, false) as Label
			checks.append(assert_not_null(badge))
			if badge != null:
				checks.append(assert_true(badge.get_theme_font_size("font_size") >= 26, "Rank must be readable"))
				checks.append(assert_true(badge.get_global_rect().end.x <= card.get_global_rect().end.x))
		if "--capture-ui" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp/ai-ladder"))
			viewport.get_texture().get_image().save_png("res://.tmp/ai-ladder/ladder-%d.png" % viewport_size.x)
		viewport.queue_free()
		await tree.process_frame
	return run_checks(checks)


func _ranked_items() -> Array:
	var items: Array = []
	for rank: int in [1, 2, 3, 24, 0]:
		items.append({"rank": rank, "release_id": "rank.%d" % rank, "owner_kind": "developer",
			"display_name": "玛俐的长毛巨魔 · 精心打磨的天梯对战策略" if rank == 1 else "开发者策略 %d" % rank,
			"author_display_name": "开发者小明", "mu": 1234.5, "actual_game_count": 120,
			"provisional": rank == 1})
	return items
