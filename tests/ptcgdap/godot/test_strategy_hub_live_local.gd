class_name TestStrategyHubLiveLocal
extends TestBase

const HubScene = preload("res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn")


func test_local_control_renders_uploaded_strategy_and_both_rankings() -> String:
	var endpoint := OS.get_environment("PTCGDAP_PLATFORM_BASE_URL").strip_edges()
	if endpoint.is_empty():
		return ""
	var hub := HubScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(hub)
	var latest := hub.get_node("%StrategyList") as VBoxContainer
	var strategies := hub.get_node("%StrategyRankingList") as VBoxContainer
	var authors := hub.get_node("%AuthorRankingList") as VBoxContainer
	var latest_ready := await _wait_until_settled(latest, tree)
	var archive_ready := false
	var history_cards := 0
	var selected_download_disabled := false
	var latest_infos := latest.find_children("MarketplaceInfoButton", "Button", true, false)
	if not latest_infos.is_empty():
		(latest_infos[0] as Button).pressed.emit()
		archive_ready = await _wait_until_text_contains(
			hub.get_node("%MatchHistoryTitle") as Label, "最近 2 场", tree
		)
		await _wait_until_named_child_count(
			hub.get_node("%MatchHistoryList"), "MarketplaceMatchHistoryCard", 2, tree
		)
		history_cards = hub.get_node("%MatchHistoryList").find_children(
			"MarketplaceMatchHistoryCard*", "PanelContainer", true, false
		).size()
		selected_download_disabled = (hub.get_node("%SelectedDownloadButton") as Button).disabled
	(hub.get_node("%StrategyRankingBoardTab") as Button).pressed.emit()
	var strategy_ready := await _wait_until_settled(strategies, tree)
	var strategy_state := (hub.get_node("%MarketplaceBoardStateLabel") as Label).text
	(hub.get_node("%AuthorRankingBoardTab") as Button).pressed.emit()
	var author_ready := await _wait_until_settled(authors, tree)
	var author_state := (hub.get_node("%MarketplaceBoardStateLabel") as Label).text
	var author_top_ready := false
	var author_top_cards := 0
	var author_buttons := authors.find_children("MarketplaceAuthorButton", "Button", true, false)
	if not author_buttons.is_empty():
		(author_buttons[0] as Button).pressed.emit()
		author_top_ready = await _wait_until_text_contains(
			hub.get_node("%AuthorWorksTitle") as Label, "最高分 5 个策略", tree
		)
		await _wait_until_named_child_count(
			hub.get_node("%AuthorWorksList"), "MarketplaceStrategyCard", 1, tree
		)
		author_top_cards = hub.get_node("%AuthorWorksList").find_children(
			"MarketplaceStrategyCard*", "PanelContainer", true, false
		).size()
	var latest_cards := latest.get_child_count()
	var strategy_cards := strategies.get_child_count()
	var author_cards := authors.get_child_count()
	var latest_snapshot: Array[String] = []
	for child: Node in latest.get_children():
		latest_snapshot.append("%s:%s" % [child.name, str(child.get("text"))])
	tree.root.remove_child(hub)
	hub.free()
	return run_checks([
		assert_true(latest_ready, "latest board should settle"),
		assert_true(strategy_ready, "strategy ranking should settle"),
		assert_true(author_ready, "author ranking should settle"),
		assert_true(archive_ready, "strategy archive should settle"),
		assert_eq(history_cards, 2, "latest two completed matches"),
		assert_true(selected_download_disabled, "unbound ptcgbot cannot masquerade as a device package"),
		assert_true(author_top_ready, "author top five should settle"),
		assert_eq(author_top_cards, 1, "current fixture has one ranked strategy per author"),
		assert_eq(
			latest_cards, 2,
			"uploaded competition strategies belong on latest: %s" % str(latest_snapshot)
		),
		assert_eq(strategy_cards, 2, "strategy ranking cards"),
		assert_eq(author_cards, 2, "author ranking cards"),
		assert_eq(strategy_state, "本页 2 项 · 已到底", "strategy board state"),
		assert_eq(author_state, "本页 2 项 · 已到底", "author board state"),
	])


func _wait_until_settled(list: VBoxContainer, tree: SceneTree) -> bool:
	var deadline := Time.get_ticks_msec() + 5_000
	while list.get_child_count() == 0 and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	return list.get_child_count() > 0


func _wait_until_text_contains(label: Label, expected: String, tree: SceneTree) -> bool:
	var deadline := Time.get_ticks_msec() + 5_000
	while expected not in label.text and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	return expected in label.text


func _wait_until_named_child_count(
	root: Node, pattern: String, expected: int, tree: SceneTree
) -> bool:
	var deadline := Time.get_ticks_msec() + 5_000
	while root.find_children(pattern + "*", "", true, false).size() < expected \
			and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	return root.find_children(pattern + "*", "", true, false).size() >= expected
