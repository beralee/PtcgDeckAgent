class_name TestStrategyHubScene
extends TestBase

const HubScene = preload("res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn")
const MainMenuScene = preload("res://scenes/main_menu/MainMenu.tscn")
const ContractsScript = preload(
	"res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd"
)
const FixtureFactoryScript = preload(
	"res://tests/ptcgdap/godot/support/PublicReplayFixtureFactory.gd"
)


class FakeLocalLibrary extends RefCounted:
	var artifact: Dictionary
	var load_count := 0

	func _init(value: Dictionary) -> void:
		artifact = value

	func list_replays() -> Dictionary:
		return {
			"accepted": true,
			"error_code": "",
			"entries": [{
				"source": "local",
				"replay_id": artifact.manifest.replay_id,
				"match_id": artifact.manifest.match_id,
				"frame_count": artifact.manifest.frame_count,
				"started_at_utc": artifact.match_envelope.started_at_utc,
				"strategy_id": artifact.match_envelope.participants[0].strategy_id,
			}],
			"rejected_count": 0,
			"authoritative": false,
			"grants": [],
		}

	func load_replay(replay_id: String) -> Dictionary:
		load_count += 1
		if replay_id != artifact.manifest.replay_id:
			return {"accepted": false, "error_code": "replay_not_found"}
		return {
			"accepted": true,
			"error_code": "",
			"artifact": artifact.duplicate(true),
			"authoritative": false,
			"grants": [],
		}


class FakeNativeMatchIndex extends RefCounted:
	func list_rows() -> Array[Dictionary]:
		return [{
			"match_id": "native-ai-match",
			"match_dir": "user://match_records/native-ai-match",
			"mode": "vs_ai",
			"recorded_at": "2026-08-22T13:30:00",
			"turn_count": 8,
			"winner_index": 0,
			"player_labels": ["Player", "AI"],
			"view_player_index": 0,
		}]


class FakeReplayLocator extends RefCounted:
	func locate(_match_dir: String) -> Dictionary:
		return {
			"entry_turn_number": 1,
			"entry_source": "match_start",
			"turn_numbers": [1, 2, 3, 4, 5, 6, 7, 8],
		}


class FakePackageDeleteCatalog extends RefCounted:
	var calls: Array[Dictionary] = []
	var result: Dictionary

	func _init(value: Dictionary) -> void:
		result = value

	func remove_package(package_id: String, package_version: String, archive_sha256: String) -> Dictionary:
		calls.append({
			"package_id": package_id,
			"package_version": package_version,
			"archive_sha256": archive_sha256,
		})
		return result.duplicate(true)


class FakeMarketplaceInstallCatalog extends RefCounted:
	var calls: Array[Dictionary] = []

	func install_from_bytes(bytes: PackedByteArray, expected_release: Dictionary) -> Dictionary:
		calls.append({
			"bytes": bytes.duplicate(),
			"expected_release": expected_release.duplicate(true),
		})
		return {
			"ok": true,
			"error_code": "",
			"already_installed": false,
			"catalog_report": {"metadata_records": [], "ready_records": [], "diagnostics": []},
		}


class FakeContinuousLadderReplayStore extends RefCounted:
	var calls: Array[Dictionary] = []

	func store_replay(replay: Dictionary) -> Dictionary:
		calls.append(replay.duplicate(true))
		return {
			"ok": true,
			"error_code": "",
			"path": "user://ptcgdap/ladder_replays/series-unit.ptcgladderreplay.json",
			"absolute_path": "C:/test/series-unit.ptcgladderreplay.json",
		}


class FakeContinuousLadderClient extends Node:
	var requested_series_ids: Array[String] = []

	func fetch_continuous_ladder_series_replay(series_id: String) -> Dictionary:
		requested_series_ids.append(series_id)
		return {"accepted": true, "error_code": ""}


class FakeReplayRemovalService extends RefCounted:
	var calls: Array[Dictionary] = []
	var result := {
		"ok": true,
		"error_code": "",
		"native_removed": true,
		"public_removed_count": 0,
		"cleanup_pending": false,
	}

	func remove_native(
		match_id: String,
		match_dir: String,
		public_replay_ids: Array[String]
	) -> Dictionary:
		calls.append({
			"kind": "native",
			"match_id": match_id,
			"match_dir": match_dir,
			"public_replay_ids": public_replay_ids.duplicate(),
		})
		var response := result.duplicate(true)
		response["public_removed_count"] = public_replay_ids.size()
		return response

	func remove_public(replay_id: String) -> Dictionary:
		calls.append({"kind": "public", "replay_id": replay_id})
		var response := result.duplicate(true)
		response["native_removed"] = false
		response["public_removed_count"] = 1
		return response


class FakeClipboardWriter extends RefCounted:
	var values: Array[String] = []

	func set_text(value: String) -> void:
		values.append(value)


func test_strategy_hub_exposes_catalog_stats_replay_and_challenge_surfaces() -> String:
	var hub := HubScene.instantiate()
	var checks: Array[String] = [
		assert_not_null(hub.get_node_or_null("%TopBarPanel")),
		assert_not_null(hub.get_node_or_null("%WorkspaceTabs")),
		assert_not_null(hub.get_node_or_null("%LocalStrategyTab")),
		assert_not_null(hub.get_node_or_null("%ReplayTab")),
		assert_not_null(hub.get_node_or_null("%CatalogTab")),
		assert_not_null(hub.get_node_or_null("%AISettingsTab")),
		assert_not_null(hub.get_node_or_null("%AISettingsWorkspace")),
		assert_not_null(hub.get_node_or_null("%StatusStrip")),
		assert_not_null(hub.get_node_or_null("%StrategyList")),
		assert_not_null(hub.get_node_or_null("%LatestBoardTab")),
		assert_not_null(hub.get_node_or_null("%StrategyRankingBoardTab")),
		assert_not_null(hub.get_node_or_null("%AuthorRankingBoardTab")),
		assert_not_null(hub.get_node_or_null("%StrategyRankingList")),
		assert_not_null(hub.get_node_or_null("%AuthorRankingList")),
		assert_not_null(hub.get_node_or_null("%AuthorWorksList")),
		assert_not_null(hub.get_node_or_null("%MatchHistoryTitle")),
		assert_not_null(hub.get_node_or_null("%MatchHistoryList")),
		assert_not_null(hub.get_node_or_null("%MarketplaceNextButton")),
		assert_not_null(hub.get_node_or_null("%OfficialStats")),
		assert_not_null(hub.get_node_or_null("%ShadowStats")),
		assert_not_null(hub.get_node_or_null("%CommunityStats")),
		assert_not_null(hub.get_node_or_null("%LocalReplayList")),
		assert_not_null(hub.get_node_or_null("%ReplayList")),
		assert_not_null(hub.get_node_or_null("%ReplayViewer")),
		assert_not_null(hub.get_node_or_null("%ImportLocalPackageButton")),
		assert_not_null(hub.get_node_or_null("%LocalPackageList")),
		assert_not_null(hub.get_node_or_null("%LocalPackageFileDialog")),
		assert_not_null(hub.get_node_or_null("%LocalPackageDeleteDialog")),
		assert_not_null(hub.get_node_or_null("%LocalPackageFolderLabel")),
		assert_not_null(hub.get_node_or_null("%CopyLocalPackageFolderButton")),
		assert_not_null(hub.get_node_or_null("%NativeReplayFolderLabel")),
		assert_not_null(hub.get_node_or_null("%CopyNativeReplayFolderButton")),
		assert_not_null(hub.get_node_or_null("%PublicReplayFolderLabel")),
		assert_not_null(hub.get_node_or_null("%CopyPublicReplayFolderButton")),
		assert_not_null(hub.get_node_or_null("%LocalReplayDeleteDialog")),
		assert_eq(hub.call("_local_package_error_text", "package_contract_incompatible"), "策略包与当前游戏接口版本不兼容。"),
		assert_eq(hub.call("_local_package_error_text", "package_deck_invalid"), "策略包牌表格式不正确或不是完整 60 张。"),
		assert_false("package_" in str(hub.call("_local_package_error_text", "package_policy_unsupported"))),
	]
	hub.free()
	return run_checks(checks)


func test_strategy_marketplace_renders_three_boards_author_works_and_download_states() -> String:
	var hub := HubScene.instantiate()
	if not hub.has_method("apply_marketplace_latest_for_test"):
		hub.free()
		return "Strategy Hub does not expose marketplace board rendering"
	var release := {
		"release_id": "release-marketplace-unit",
		"strategy_id": "strategy.marketplace.unit",
		"package_id": "package.marketplace.unit",
		"package_version": "1.2.3",
		"archive_sha256": "A".repeat(64),
		"manifest_canonical_sha256": "B".repeat(64),
		"author": {"author_id": "device.author", "display_name": "设备作者"},
		"strategy_display_name": "测试策略",
		"download_available": true,
		"artifact_domain": "device_ptcgai",
	}
	var marketplace_item := {
		"strategy_id": "strategy.marketplace.unit",
		"display_name": "测试策略",
		"summary": "用于三板块 UI 测试",
		"author": {"author_id": "device.author", "display_name": "设备作者"},
		"published_at_utc": "2026-08-24T12:00:00Z",
		"installable_release": release,
		"download_available": true,
	}
	hub.call("apply_marketplace_latest_for_test", [marketplace_item], "latest-next")
	hub.call("apply_marketplace_strategy_rankings_for_test", [{
		"rank": 1,
		"display_name": "测试策略",
		"author_display_name": "设备作者",
		"kaggle_score_micros": 416667,
		"win_rate_micros": 666667,
		"games": 12,
		"provisional": false,
		"download_available": true,
		"installable_release": release,
	}], null, "snapshot.unit")
	hub.call("apply_marketplace_author_rankings_for_test", [{
		"rank": 1,
		"author_id": "competition.author",
		"author_display_name": "策略作者",
		"kaggle_score_micros": 416667,
		"win_rate_micros": 666667,
		"games": 12,
		"published_strategy_count": 1,
		"provisional": false,
	}], null, "snapshot.unit")
	hub.call("apply_marketplace_author_strategies_for_test", {
		"author_id": "competition.author",
		"display_name": "策略作者",
	}, [marketplace_item])
	if not hub.has_method("apply_marketplace_strategy_archive_for_test") \
			or not hub.has_method("apply_marketplace_author_top_strategies_for_test"):
		hub.free()
		return "Strategy Hub does not expose strategy archive and author Top 5 rendering"
	hub.call("apply_marketplace_strategy_archive_for_test", marketplace_item, [{
		"match_id": "match.marketplace.latest",
		"completed_at_utc": "2026-08-24T12:00:01Z",
		"subject_seat": 1,
		"subject_result": "win",
		"participants": [
			{
				"seat": 0, "release_id": "competition.release.other",
				"strategy_id": "strategy.other", "author_id": "author.other",
				"display_name": "对手策略", "deck_display_name": "对手牌组",
			},
			{
				"seat": 1, "release_id": "competition.release.unit",
				"strategy_id": "strategy.marketplace.unit", "author_id": "competition.author",
				"display_name": "测试策略", "deck_display_name": "测试牌组",
			},
		],
		"replay_available": true,
		"replay_path": "/v1/competition-matches/match.marketplace.latest/replay",
	}])
	hub.call("apply_marketplace_author_top_strategies_for_test", {
		"author_id": "competition.author", "display_name": "策略作者",
	}, [{
		"author_strategy_rank": 1,
		"rank": 2,
		"display_name": "测试策略",
		"author_display_name": "策略作者",
		"kaggle_score_micros": 416667,
		"win_rate_micros": 666667,
		"games": 12,
		"provisional": false,
		"download_available": true,
		"installable_release": release,
	}])
	var latest_text := _collect_label_and_button_text(hub.get_node("%StrategyList"))
	var ranking_text := _collect_label_and_button_text(hub.get_node("%StrategyRankingList"))
	var author_text := _collect_label_and_button_text(hub.get_node("%AuthorRankingList"))
	var works_text := _collect_label_and_button_text(hub.get_node("%AuthorWorksList"))
	var history_text := _collect_label_and_button_text(hub.get_node("%MatchHistoryList"))
	var download_buttons := hub.find_children("MarketplaceDownloadButton", "Button", true, false)
	var checks := run_checks([
		assert_str_contains(latest_text, "测试策略"),
		assert_str_contains(latest_text, "下载到本机"),
		assert_str_contains(ranking_text, "#1"),
		assert_str_contains(ranking_text, "Kaggle 分 0.417"),
		assert_str_contains(ranking_text, "胜率 66.7%"),
		assert_str_contains(author_text, "策略作者"),
		assert_str_contains(author_text, "Kaggle 分 0.417"),
		assert_str_contains(author_text, "胜率 66.7%"),
		assert_str_contains(author_text, "查看最高分 5 个策略"),
		assert_str_contains(works_text, "测试策略"),
		assert_str_contains(works_text, "作者第 1"),
		assert_str_contains(history_text, "测试策略 vs 对手策略"),
		assert_str_contains(history_text, "胜利"),
		assert_str_contains(history_text, "录像可用"),
		assert_eq((hub.get_node("%MatchHistoryTitle") as Label).text, "最近 1 场对战（最多 20 场）"),
		assert_str_contains((hub.get_node("%AuthorWorksTitle") as Label).text, "最高分 5 个策略"),
		assert_true(download_buttons.size() >= 3),
		assert_true((hub.get_node("%MarketplaceNextButton") as Button).visible),
	])
	hub.call("select_marketplace_board_for_test", "strategy_rankings")
	checks += run_checks([
		assert_false((hub.get_node("%CatalogScroll") as Control).visible),
		assert_true((hub.get_node("%StrategyRankingScroll") as Control).visible),
		assert_false((hub.get_node("%AuthorRankingScroll") as Control).visible),
	])
	hub.call("select_marketplace_board_for_test", "author_rankings")
	checks += run_checks([
		assert_false((hub.get_node("%StrategyRankingScroll") as Control).visible),
		assert_true((hub.get_node("%AuthorRankingScroll") as Control).visible),
	])
	if not hub.has_method("show_marketplace_strategy_for_test"):
		hub.free()
		return "Strategy Hub does not expose deterministic marketplace detail rendering"
	hub.call("show_marketplace_strategy_for_test", marketplace_item)
	checks += run_checks([
		assert_eq((hub.get_node("%StrategyTitle") as Label).text, "测试策略"),
		assert_false((hub.get_node("%AuthorWorksList") as Control).visible),
		assert_false((hub.get_node("%AuthorWorksTitle") as Control).visible),
	])
	hub.call("apply_marketplace_latest_for_test", [], null)
	hub.call("apply_marketplace_strategy_rankings_for_test", [], null, "snapshot.empty")
	hub.call("apply_marketplace_author_rankings_for_test", [], null, "snapshot.empty")
	checks += run_checks([
		assert_str_contains(_collect_label_and_button_text(hub.get_node("%StrategyList")), "暂无已发布策略"),
		assert_str_contains(_collect_label_and_button_text(hub.get_node("%StrategyRankingList")), "暂无策略排行"),
		assert_str_contains(_collect_label_and_button_text(hub.get_node("%AuthorRankingList")), "暂无作者排行"),
	])
	hub.free()
	return checks


func test_continuous_ladder_renders_single_score_and_npc_ownership() -> String:
	var hub := HubScene.instantiate()
	if not hub.has_method("apply_continuous_ladder_leaderboard_for_test") \
			or not hub.has_method("apply_continuous_ladder_authors_for_test"):
		hub.free()
		return "Strategy Hub does not expose continuous ladder rendering"
	hub.call("apply_continuous_ladder_leaderboard_for_test", [{
		"rank": 1,
		"release_id": "windows-trial-ogerpon-unit",
		"display_name": "开发者·厄诡椪/岩殿居蟹 1.4.0",
		"author_display_name": "Beralee",
		"developer_id": "beralee.ogerpon",
		"owner_kind": "developer",
		"release_source_kind": "developer_ptcgai",
		"mu": 710.111902,
		"sigma": 166.971162,
		"rated_series_count": 1,
		"actual_game_count": 2,
		"provisional": true,
	}, {
		"rank": 2,
		"release_id": "builtin-v18-800018501",
		"display_name": "平台NPC·18.0 玛俐的长毛巨魔",
		"developer_id": "platform-npc-system",
		"owner_kind": "platform_npc",
		"release_source_kind": "platform_builtin_v18_rule",
		"mu": 700.931356,
		"sigma": 172.675596,
		"rated_series_count": 1,
		"actual_game_count": 2,
		"provisional": true,
	}], "godot_v18_ladder_v1")
	hub.call("apply_continuous_ladder_authors_for_test", [{
		"rank": 1,
		"developer_id": "beralee.ogerpon",
		"release_id": "windows-trial-ogerpon-unit",
		"author_display_name": "Beralee",
		"display_name": "开发者·厄诡椪/岩殿居蟹 1.4.0",
		"mu": 710.111902,
		"sigma": 166.971162,
		"provisional": true,
	}], "godot_v18_ladder_v1")
	var ranking_text := _collect_label_and_button_text(hub.get_node("%StrategyRankingList"))
	var author_text := _collect_label_and_button_text(hub.get_node("%AuthorRankingList"))
	var checks := run_checks([
		assert_str_contains(ranking_text, "#1"),
		assert_str_contains(ranking_text, "厄诡椪"),
		assert_str_contains(ranking_text, "710.11 分"),
		assert_false(ranking_text.contains("μ")),
		assert_false(ranking_text.contains("σ")),
		assert_str_contains(ranking_text, "2 局"),
		assert_str_contains(ranking_text, "开发者策略"),
		assert_str_contains(ranking_text, "平台 NPC"),
		assert_str_contains(ranking_text, "暂定"),
		assert_str_contains(author_text, "Beralee"),
		assert_str_contains(author_text, "710.11 分"),
		assert_false(author_text.contains("μ")),
		assert_false(author_text.contains("σ")),
		assert_str_contains(
			str(hub.call("workspace_status_snapshot").get("catalog", {}).get("text", "")),
			"godot_v18_ladder_v1"
		),
	])
	hub.free()
	return checks


func test_continuous_ladder_rankings_drive_release_and_author_archives() -> String:
	var hub := HubScene.instantiate()
	for method_name: String in [
		"apply_continuous_ladder_release_profile_for_test",
		"apply_continuous_ladder_author_profile_for_test",
		"apply_continuous_ladder_series_replay_for_test",
		"configure_continuous_ladder_replay_store_for_test",
		"configure_continuous_ladder_client_for_test",
	]:
		if not hub.has_method(method_name):
			hub.free()
			return "Strategy Hub archive seam missing: %s" % method_name
	var installable := {
		"release_id": "windows-trial-ogerpon-unit",
		"package_id": "dev.beralee.ogerpon",
		"package_version": "1.4.0",
		"archive_sha256": "A".repeat(64),
		"manifest_canonical_sha256": "B".repeat(64),
		"archive_bytes": 7,
		"distribution": {"href": "/v1/ladder/releases/windows-trial-ogerpon-unit/package", "media_type": "application/vnd.ptcgdap.strategy-package", "etag": "A".repeat(64)},
	}
	var release := {
		"release_id": "windows-trial-ogerpon-unit", "developer_id": "beralee.ogerpon",
		"owner_kind": "developer", "display_name": "开发者·厄诡椪/岩殿居蟹 1.4.0",
		"author_display_name": "Beralee", "summary": "阶段化支援者策略",
		"state": "active", "rank": 1, "mu": 710.111902, "sigma": 166.971162,
		"rated_series_count": 1, "actual_game_count": 2, "provisional": true,
		"download_available": true, "installable_release": installable,
	}
	var performance := {
		"series": {"games": 1, "wins": 1, "losses": 0, "draws": 0, "win_rate_micros": 1000000},
		"individual_games": {"games": 2, "wins": 2, "losses": 0, "draws": 0, "win_rate_micros": 1000000},
	}
	var replay_store := FakeContinuousLadderReplayStore.new()
	var replay_client := FakeContinuousLadderClient.new()
	hub.add_child(replay_client)
	hub.call("configure_continuous_ladder_replay_store_for_test", replay_store)
	hub.call("configure_continuous_ladder_client_for_test", replay_client)
	hub.call("apply_continuous_ladder_release_profile_for_test", {
		"release": release, "performance": performance,
		"rating_history": [{"sequence_no": 14, "subject_outcome": "win", "prior_mu": 600.0, "prior_sigma": 200.0, "after_mu": 710.111902, "after_sigma": 166.971162, "created_at_epoch": 1787837919}],
		"recent_matches": [{"series_id": "series-unit", "state": "rated", "completed_at_epoch": 1787837919, "opponent": {"release_id": "builtin-v18-unit", "display_name": "平台NPC·测试", "owner_kind": "platform_npc"}, "subject_result": "win", "games": 2, "wins": 2, "losses": 0, "draws": 0, "replay_available": true, "replay_path": "/v1/ladder/matches/series-unit/replay"}],
	})
	var release_text := _collect_label_and_button_text(hub.get_node("%DetailRoot"))
	var replay_downloads := hub.find_children(
		"ContinuousLadderReplayDownloadButton", "Button", true, false
	)
	var replay_button_initial_text := (
		str((replay_downloads[0] as Button).text) if replay_downloads.size() == 1 else ""
	)
	if replay_downloads.size() == 1:
		(replay_downloads[0] as Button).pressed.emit()
	var replay_button_pending_text := (
		str((replay_downloads[0] as Button).text) if replay_downloads.size() == 1 else ""
	)
	var release_download: Button = hub.get_node("%SelectedDownloadButton")
	var release_download_visible := release_download.visible
	var release_download_text := release_download.text
	var release_kicker_text := (hub.get_node("%DetailKicker") as Label).text
	var release_legacy_replay_visible := (hub.get_node("%ReplayTitle") as Label).visible
	hub.call("apply_continuous_ladder_series_replay_for_test", {
		"document_type": "godot_v18_public_series_replay_v1",
		"schema_version": 1,
		"series_id": "series-unit",
	})
	var replay_button_final_text := (
		str((replay_downloads[0] as Button).text) if replay_downloads.size() == 1 else ""
	)
	hub.call("apply_continuous_ladder_author_profile_for_test", {
		"author": {"developer_id": "beralee.ogerpon", "display_name": "Beralee", "rank": 1, "release_count": 2, "active_release_count": 1, "best_release_id": "windows-trial-ogerpon-unit", "mu": 710.111902, "sigma": 166.971162, "provisional": true},
		"releases": [
			{"release": release, "performance": performance},
			{"release": release.merged({"release_id": "windows-trial-ogerpon-old", "display_name": "厄诡椪 1.3.0", "state": "historical", "mu": 640.0, "sigma": 120.0, "download_available": false, "installable_release": null}, true), "performance": {"series": {"games": 12, "wins": 7, "losses": 4, "draws": 1, "win_rate_micros": 583333}, "individual_games": {"games": 24, "wins": 14, "losses": 9, "draws": 1, "win_rate_micros": 583333}}},
		],
	})
	var author_text := _collect_label_and_button_text(hub.get_node("%DetailRoot"))
	var author_kicker_text := (hub.get_node("%DetailKicker") as Label).text
	var author_legacy_replay_visible := (hub.get_node("%ReplayTitle") as Label).visible
	var imports := hub.find_children("ContinuousLadderDownloadButton", "Button", true, false)
	var ranking_buttons := hub.find_children("ContinuousLadder*Button", "Button", true, false)
	if not release_text.contains("系列胜率 100.0%") \
			or not release_text.contains("实际单局") \
			or not release_text.contains("积分变化历史") \
			or not release_text.contains("600.00 → 710.11 分") \
			or not release_text.contains("平台NPC·测试") \
			or replay_downloads.size() != 1 \
			or replay_button_initial_text != "下载录像" \
			or replay_button_pending_text != "下载中…" \
			or replay_button_final_text != "已下载" \
			or replay_client.requested_series_ids != ["series-unit"] \
			or replay_store.calls.size() != 1 \
			or not release_download_visible \
			or not release_download_text.contains("一键下载") \
			or not author_text.contains("Beralee 的作者档案") \
			or not author_text.contains("全部 2 个策略版本") \
			or not author_text.contains("厄诡椪 1.3.0") \
			or not author_text.contains("640.00 分") \
			or author_text.contains("μ") or author_text.contains("σ") \
			or imports.is_empty() or ranking_buttons.is_empty():
		var diagnostic := "release_visible=%s replays=%d imports=%d buttons=%d\nrelease=%s\nauthor=%s" % [
			release_download_visible, replay_downloads.size(), imports.size(), ranking_buttons.size(),
			release_text, author_text,
		]
		hub.free()
		return diagnostic
	var checks := run_checks([
		assert_str_contains(release_text, "系列胜率 100.0%"),
		assert_str_contains(release_text, "实际单局"),
		assert_str_contains(release_text, "积分变化历史"),
		assert_str_contains(release_text, "600.00 → 710.11 分"),
		assert_false(release_text.contains("μ")),
		assert_false(release_text.contains("σ")),
		assert_str_contains(release_text, "平台NPC·测试"),
		assert_eq(replay_downloads.size(), 1),
		assert_eq(replay_button_initial_text, "下载录像"),
		assert_eq(replay_button_pending_text, "下载中…"),
		assert_eq(replay_button_final_text, "已下载"),
		assert_eq(replay_client.requested_series_ids, ["series-unit"]),
		assert_eq(replay_store.calls.size(), 1),
		assert_eq(replay_store.calls[0].get("series_id"), "series-unit"),
		assert_true(release_download_visible),
		assert_str_contains(release_download_text, "一键下载"),
		assert_eq(release_kicker_text, "策略档案"),
		assert_false(release_legacy_replay_visible),
		assert_str_contains(author_text, "Beralee 的作者档案"),
		assert_eq(author_kicker_text, "作者档案"),
		assert_false(author_legacy_replay_visible),
		assert_str_contains(author_text, "全部 2 个策略版本"),
		assert_str_contains(author_text, "厄诡椪 1.3.0"),
		assert_str_contains(author_text, "640.00 分"),
		assert_false(author_text.contains("μ")),
		assert_false(author_text.contains("σ")),
		assert_true(imports.size() >= 1),
		assert_true(ranking_buttons.size() >= 1),
	])
	hub.free()
	return checks


func test_strategy_marketplace_download_hands_exact_bytes_to_strict_catalog_installer() -> String:
	var hub := HubScene.instantiate()
	if not hub.has_method("configure_marketplace_install_catalog_for_test"):
		hub.free()
		return "Strategy Hub does not expose marketplace installer seam"
	var fake := FakeMarketplaceInstallCatalog.new()
	hub.call("configure_marketplace_install_catalog_for_test", fake)
	var bytes := "package".to_utf8_buffer()
	var expected := {
		"package_id": "package.unit",
		"package_version": "1.0.0",
		"archive_sha256": "A".repeat(64),
		"manifest_canonical_sha256": "B".repeat(64),
	}
	hub.call("apply_marketplace_package_download_for_test", {
		"accepted": true,
		"package_bytes": bytes,
		"expected_release": expected,
	})
	var checks := run_checks([
		assert_eq(fake.calls.size(), 1),
		assert_eq(fake.calls[0].get("bytes"), bytes),
		assert_eq(fake.calls[0].get("expected_release"), expected),
		assert_str_contains(str(hub.call("workspace_status_snapshot").get("catalog", {}).get("text", "")), "安装完成"),
	])
	hub.free()
	return checks


func _collect_label_and_button_text(root: Node) -> String:
	var result := ""
	for node: Node in root.find_children("*", "Control", true, false):
		if node is Label:
			result += (node as Label).text + "\n"
		elif node is Button:
			result += (node as Button).text + "\n"
	return result


func test_strategy_hub_shows_copyable_absolute_strategy_and_replay_storage_paths() -> String:
	var hub := HubScene.instantiate()
	if not hub.has_method("configure_storage_paths_for_test"):
		hub.free()
		return "Strategy Hub does not expose storage-path configuration"
	hub.call("configure_storage_paths_for_test")
	var snapshot: Dictionary = hub.call("storage_paths_snapshot")
	var clipboard := FakeClipboardWriter.new()
	hub.call("configure_clipboard_writer_for_test", clipboard)
	hub.call("_copy_storage_path", "strategy_packages")
	hub.call("_copy_storage_path", "native_replays")
	hub.call("_copy_storage_path", "public_replays")
	var package_label := hub.get_node_or_null("%LocalPackageFolderLabel") as Label
	var native_label := hub.get_node_or_null("%NativeReplayFolderLabel") as Label
	var public_label := hub.get_node_or_null("%PublicReplayFolderLabel") as Label
	if package_label == null or native_label == null or public_label == null:
		hub.free()
		return "Storage path labels are missing"
	var checks := run_checks([
		assert_eq(snapshot.get("strategy_packages"), ProjectSettings.globalize_path("user://ptcgdap/author_strategy_packages")),
		assert_eq(snapshot.get("native_replays"), ProjectSettings.globalize_path("user://match_records")),
		assert_eq(snapshot.get("public_replays"), ProjectSettings.globalize_path("user://ptcgdap/public_replays/live-community")),
		assert_str_contains(package_label.text, str(snapshot.get("strategy_packages", ""))),
		assert_str_contains(native_label.text, str(snapshot.get("native_replays", ""))),
		assert_str_contains(public_label.text, str(snapshot.get("public_replays", ""))),
		assert_eq(package_label.tooltip_text, snapshot.get("strategy_packages")),
		assert_eq(native_label.tooltip_text, snapshot.get("native_replays")),
		assert_eq(public_label.tooltip_text, snapshot.get("public_replays")),
		assert_eq(clipboard.values, [
			snapshot.get("strategy_packages"),
			snapshot.get("native_replays"),
			snapshot.get("public_replays"),
		], "Every path button target must be copied byte-for-byte"),
	])
	hub.free()
	return checks


func test_strategy_hub_uses_one_hud_workspace_at_a_time() -> String:
	var hub := HubScene.instantiate()
	if not hub.has_method("select_workspace_for_test"):
		hub.free()
		return "strategy hub does not expose workspace navigation for tests"
	var local_tab := hub.get_node_or_null("%LocalStrategyTab") as Button
	var replay_tab := hub.get_node_or_null("%ReplayTab") as Button
	var catalog_tab := hub.get_node_or_null("%CatalogTab") as Button
	var settings_tab := hub.get_node_or_null("%AISettingsTab") as Button
	var local_workspace := hub.get_node_or_null("%LocalStrategyWorkspace") as Control
	var replay_workspace := hub.get_node_or_null("%ReplayWorkspace") as Control
	var catalog_workspace := hub.get_node_or_null("%CatalogWorkspace") as Control
	var settings_workspace := hub.get_node_or_null("%AISettingsWorkspace") as Control
	if null in [local_tab, replay_tab, catalog_tab, settings_tab, local_workspace, replay_workspace, catalog_workspace, settings_workspace]:
		hub.free()
		return "strategy hub workspace controls are incomplete"
	hub.call("select_workspace_for_test", "catalog")
	var checks: Array[String] = [
		assert_eq(catalog_tab.get_index(), 0, "策略广场必须是首个页签"),
		assert_eq(local_tab.get_index(), 1),
		assert_eq(replay_tab.get_index(), 2),
		assert_eq(settings_tab.get_index(), 3, "AI 设置必须是末尾页签"),
		assert_eq(catalog_tab.text, "策略广场"),
		assert_eq(local_tab.text, "本地策略"),
		assert_eq(replay_tab.text, "对战录像"),
		assert_eq(settings_tab.text, "AI 设置"),
		assert_false(local_workspace.visible),
		assert_false(replay_workspace.visible),
		assert_true(catalog_workspace.visible),
		assert_false(settings_workspace.visible),
		assert_true(bool(catalog_tab.get_meta("hud_segment_active", false))),
	]
	hub.call("select_workspace_for_test", "local")
	checks.append_array([
		assert_true(local_workspace.visible),
		assert_false(replay_workspace.visible),
		assert_false(catalog_workspace.visible),
		assert_false(settings_workspace.visible),
		assert_true(bool(local_tab.get_meta("hud_segment_active", false))),
	])
	hub.call("select_workspace_for_test", "replays")
	checks.append_array([
		assert_false(local_workspace.visible),
		assert_true(replay_workspace.visible),
		assert_false(catalog_workspace.visible),
		assert_false(settings_workspace.visible),
		assert_true(bool(replay_tab.get_meta("hud_segment_active", false))),
		assert_false(bool(local_tab.get_meta("hud_segment_active", true))),
	])
	hub.call("select_workspace_for_test", "catalog")
	checks.append_array([
		assert_false(local_workspace.visible),
		assert_false(replay_workspace.visible),
		assert_true(catalog_workspace.visible),
		assert_false(settings_workspace.visible),
		assert_true(bool(catalog_tab.get_meta("hud_segment_active", false))),
	])
	hub.call("select_workspace_for_test", "settings")
	checks.append_array([
		assert_false(local_workspace.visible),
		assert_false(replay_workspace.visible),
		assert_false(catalog_workspace.visible),
		assert_true(settings_workspace.visible),
		assert_true(bool(settings_tab.get_meta("hud_segment_active", false))),
		assert_not_null(settings_workspace.get_node_or_null("AISettingsContent"), "AI 设置应复用现有设置页面内容"),
	])
	hub.free()
	return run_checks(checks)


func test_strategy_hub_embeds_existing_ai_settings_scene_when_requested() -> String:
	GameManager.set_scene_navigation_suppressed_for_tests(true)
	GameManager.goto_strategy_hub("settings")
	GameManager.consume_last_requested_scene_path()
	GameManager.set_scene_navigation_suppressed_for_tests(false)
	var hub := HubScene.instantiate()
	hub.set("_skip_service_initialization_for_tests", true)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(hub)
	await tree.process_frame
	await tree.process_frame
	var settings_workspace := hub.get_node_or_null("%AISettingsWorkspace") as ScrollContainer
	var settings_content := settings_workspace.get_node_or_null("AISettingsContent") as Control \
		if settings_workspace != null else null
	var background := settings_content.get_node_or_null("Background") as Control \
		if settings_content != null else null
	var title := settings_content.find_child("Title", true, false) as Label \
		if settings_content != null else null
	var back_button := settings_content.get_node_or_null("%BtnBack") as Button \
		if settings_content != null else null
	var save_button := settings_content.get_node_or_null("%BtnSave") as Button \
		if settings_content != null else null
	var endpoint_input := settings_content.get_node_or_null("%EndpointInput") as LineEdit \
		if settings_content != null else null
	var checks := run_checks([
		assert_true(settings_workspace != null and settings_workspace.visible),
		assert_not_null(settings_content, "AI 设置页应按需复用原 Settings 场景"),
		assert_true(settings_content != null and settings_content.custom_minimum_size.y >= 680.0),
		assert_true(background != null and not background.visible, "嵌入后不能覆盖策略中心背景"),
		assert_true(title != null and not title.visible, "策略中心已有标题，设置页不应重复显示标题"),
		assert_true(back_button != null and not back_button.visible, "返回动作由策略中心顶栏统一负责"),
		assert_true(save_button != null and save_button.visible),
		assert_not_null(endpoint_input),
		assert_false((hub.get_node("%CatalogWorkspace") as Control).visible),
		assert_true(bool((hub.get_node("%AISettingsTab") as Button).get_meta("hud_segment_active", false))),
	])
	tree.root.remove_child(hub)
	hub.free()
	return checks


func test_strategy_hub_reflows_hud_workspaces_for_portrait_and_landscape() -> String:
	var hub := HubScene.instantiate()
	if not hub.has_method("apply_non_battle_layout_for_test"):
		hub.free()
		return "strategy hub does not expose responsive layout for tests"
	var local_columns := hub.get_node_or_null("%LocalStrategyColumns") as GridContainer
	var catalog_columns := hub.get_node_or_null("%CatalogColumns") as GridContainer
	var tabs := hub.get_node_or_null("%WorkspaceTabs") as Control
	var library_panel := hub.find_child("PackageLibraryPanel", true, false) as Control
	var package_scroll := hub.find_child("LocalPackageScroll", true, false) as ScrollContainer
	if null in [local_columns, catalog_columns, tabs, package_scroll]:
		hub.free()
		return "strategy hub responsive layout controls are incomplete"
	hub.call("apply_non_battle_layout_for_test", Vector2(430, 932), "portrait")
	var checks: Array[String] = [
		assert_eq(local_columns.columns, 1),
		assert_eq(catalog_columns.columns, 1),
		assert_true(tabs.custom_minimum_size.y >= 56.0),
		assert_true(library_panel != null and library_panel.custom_minimum_size.y >= 400.0),
		assert_eq(package_scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED),
		assert_eq(str(hub.get_meta("non_battle_layout_mode", "")), "portrait"),
	]
	hub.call("apply_non_battle_layout_for_test", Vector2(1600, 900), "landscape")
	checks.append_array([
		assert_eq(local_columns.columns, 2),
		assert_eq(catalog_columns.columns, 2),
		assert_true(library_panel != null and library_panel.custom_minimum_size.y >= 450.0),
		assert_eq(package_scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO),
		assert_eq(str(hub.get_meta("non_battle_layout_mode", "")), "landscape"),
	])
	hub.free()
	return run_checks(checks)


func test_strategy_hub_renders_imported_packages_with_battle_availability() -> String:
	var hub := HubScene.instantiate()
	if not hub.has_method("apply_local_package_catalog_for_test"):
		hub.free()
		return "strategy hub does not expose the local package catalog surface"
	hub.call("apply_local_package_catalog_for_test", {
		"metadata_records": [{
			"package_id": "local.sample",
			"package_version": "1.0.0",
			"archive_sha256": "A".repeat(64),
			"install_source": "user",
			"install_sources": ["user"],
			"author": {"display_name": "本地作者"},
			"strategy": {"display_name": "18.0 玛俐长毛巨魔完整作者策略", "summary": "测试策略"},
			"deck": {"display_name": "本地卡组"},
			"status": "metadata_only",
		}],
		"ready_records": [],
		"diagnostics": [],
	})
	var list := hub.get_node("%LocalPackageList") as VBoxContainer
	var record_label := list.find_child("LocalPackageRecordLabel", true, false) as Label
	var delete_button := list.find_child("LocalPackageDeleteButton", true, false) as Button
	var rendered_text := ""
	for child: Node in list.find_children("*", "Label", true, false):
		if child is Label:
			rendered_text += (child as Label).text + "\n"
	if delete_button == null:
		hub.free()
		return "User-installed package card did not expose a delete button"
	var result := run_checks([
		assert_not_null(record_label),
		assert_not_null(delete_button),
		assert_eq(delete_button.text, "删除策略"),
		assert_eq(record_label.text, "18.0 玛俐长毛巨魔 · 本地作者 · v1.0.0"),
		assert_false("完整作者策略" in rendered_text, "Verbose package-shape suffixes must not remain in the visible package name"),
		assert_str_contains(rendered_text, "本地作者"),
		assert_str_contains(rendered_text, "已加载"),
		assert_str_contains(rendered_text, "暂不可开战"),
	])
	delete_button.pressed.emit()
	var delete_dialog := hub.get_node_or_null("%LocalPackageDeleteDialog") as ConfirmationDialog
	result += run_checks([
		assert_true(delete_dialog.visible, "Delete must require an explicit confirmation"),
		assert_str_contains(delete_dialog.dialog_text, "18.0 玛俐长毛巨魔"),
		assert_eq(hub.get("_pending_local_package_delete_ref"), {
			"package_id": "local.sample",
			"package_version": "1.0.0",
			"archive_sha256": "A".repeat(64),
		}),
	])
	hub.free()
	return result


func test_strategy_hub_offers_product_removal_for_built_in_and_user_packages() -> String:
	var hub := HubScene.instantiate()
	hub.call("apply_local_package_catalog_for_test", {
		"metadata_records": [
			{
				"package_id": "builtin.only",
				"package_version": "1.0.0",
				"archive_sha256": "B".repeat(64),
				"install_source": "built_in",
				"install_sources": ["built_in"],
				"author": {"display_name": "内置作者"},
				"strategy": {"display_name": "内置策略"},
				"deck": {"display_name": "内置卡组"},
				"status": "metadata_only",
			},
			{
				"package_id": "builtin.duplicate",
				"package_version": "1.0.0",
				"archive_sha256": "C".repeat(64),
				"install_source": "built_in",
				"install_sources": ["built_in", "user"],
				"author": {"display_name": "重复作者"},
				"strategy": {"display_name": "重复策略"},
				"deck": {"display_name": "重复卡组"},
				"status": "metadata_only",
			},
		],
		"ready_records": [],
		"diagnostics": [],
	})
	var buttons: Array[Node] = hub.get_node("%LocalPackageList").find_children(
		"LocalPackageDeleteButton", "Button", true, false
	)
	if buttons.size() != 2:
		hub.free()
		return "Expected every visible strategy to be removable, got %d" % buttons.size()
	var result := run_checks([
		assert_eq((buttons[0] as Button).text, "删除策略"),
		assert_eq((buttons[1] as Button).text, "删除策略"),
	])
	hub.free()
	return result


func test_strategy_hub_confirmed_remove_clears_a_deleted_selected_opponent() -> String:
	var hub := HubScene.instantiate()
	if not hub.has_method("configure_package_delete_catalog_for_test"):
		hub.free()
		return "Strategy Hub does not expose an isolated delete catalog seam"
	hub.call("select_workspace_for_test", "local")
	var reference := {
		"package_id": "local.delete-me",
		"package_version": "1.0.0",
		"archive_sha256": "D".repeat(64),
	}
	var empty_report := {
		"metadata_records": [],
		"ready_records": [],
		"diagnostics": [],
	}
	var fake := FakePackageDeleteCatalog.new({
		"ok": true,
		"error_code": "",
		"status": "removed",
		"removed_count": 1,
		"remaining_built_in": false,
		"catalog_discoverable": false,
		"cleanup_pending": false,
		"catalog_report": empty_report,
	})
	hub.call("configure_package_delete_catalog_for_test", fake)
	hub.call("apply_local_package_catalog_for_test", {
		"metadata_records": [reference.merged({
			"install_source": "user",
			"install_sources": ["user"],
			"author": {"display_name": "删除作者"},
			"strategy": {"display_name": "待删除策略"},
			"deck": {"display_name": "删除测试卡组"},
			"status": "metadata_only",
		})],
		"ready_records": [],
		"diagnostics": [],
	})
	var previous_selection := GameManager.get_author_strategy_selection()
	GameManager.set_author_strategy_selection(reference.merged({
		"display_name_snapshot": "待删除策略",
		"install_source": "user",
	}))
	var delete_button := hub.get_node("%LocalPackageList").find_child(
		"LocalPackageDeleteButton", true, false
	) as Button
	if delete_button == null:
		hub.free()
		return "Delete button missing before confirmation test"
	delete_button.pressed.emit()
	hub.call("_on_local_package_delete_confirmed")
	var result := run_checks([
		assert_eq(fake.calls, [reference], "Delete must bind the exact stable package reference"),
		assert_eq(GameManager.get_author_strategy_selection(), {}, "Deleted selected opponent must not remain persisted"),
		assert_eq((hub.get_node("%LocalPackageList") as VBoxContainer).get_child_count(), 1, "Empty-state card should replace the removed strategy"),
		assert_str_contains((hub.get_node("%StatusLabel") as Label).text, "已从游戏中删除"),
	])
	GameManager.reset_author_strategy_selection()
	if not previous_selection.is_empty():
		GameManager.set_author_strategy_selection(previous_selection)
	hub.free()
	return result


func test_strategy_hub_lazily_loads_the_full_public_replay_viewer_on_demand() -> String:
	var artifact: Dictionary = FixtureFactoryScript.load_developer_artifact()
	if artifact.is_empty():
		return "tracked Marnie public replay fixture could not be decoded"
	var contracts: Dictionary = ContractsScript.load_default()
	if not bool(contracts.get("accepted", false)):
		return "replay contracts unavailable: %s" % contracts
	var hub := HubScene.instantiate()
	hub.configure_local_replay_for_test(contracts.owner, FakeLocalLibrary.new(artifact))
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(hub)
	hub._open_replay_artifact(artifact, true)
	for _frame: int in range(20):
		if str(hub.startup_performance_snapshot().get("viewer_load_stage", "")) in ["ready", "resource_invalid"]:
			break
		await tree.process_frame
	var viewer: Variant = hub.get("_replay_viewer")
	var overlay := hub.get_node("%ReplayOverlay") as Control
	var status := str((hub.get_node("%StatusLabel") as Label).text)
	var checks := run_checks([
		assert_true(viewer != null and viewer.has_method("load_public_replay"), "The lightweight hub placeholder should be replaced by the real viewer on demand; status=%s viewer=%s audit=%s" % [status, viewer, hub.startup_performance_snapshot()]),
		assert_true(overlay.visible, "A validated replay should remain visible after lazy viewer creation"),
	])
	tree.root.remove_child(hub)
	hub.free()
	return checks


func test_main_menu_and_game_manager_route_to_strategy_hub() -> String:
	var menu := MainMenuScene.instantiate()
	var button := menu.find_child("BtnStrategyHub", true, false) as Button
	var legacy_settings_button := menu.find_child("BtnSettings", true, false) as Button
	if button == null:
		var names: Array[String] = []
		for candidate: Node in menu.find_children("*", "Button", true, false):
			names.append(candidate.name)
		menu.free()
		return "main menu buttons: %s" % names
	GameManager.set_scene_navigation_suppressed_for_tests(true)
	GameManager.goto_strategy_hub()
	var requested := GameManager.consume_last_requested_scene_path()
	var default_workspace: String = str(GameManager.call("consume_strategy_hub_initial_workspace")) \
		if GameManager.has_method("consume_strategy_hub_initial_workspace") else ""
	GameManager.goto_settings()
	var settings_requested := GameManager.consume_last_requested_scene_path()
	var settings_workspace: String = str(GameManager.call("consume_strategy_hub_initial_workspace")) \
		if GameManager.has_method("consume_strategy_hub_initial_workspace") else ""
	GameManager.set_scene_navigation_suppressed_for_tests(false)
	var button_exists := button != null
	var button_text := button.text if button != null else ""
	menu.free()
	return run_checks([
		assert_true(button_exists),
		assert_eq(button_text, "AI 策略中心"),
		assert_null(legacy_settings_button, "Windows 首页只应保留一个 AI 策略中心入口"),
		assert_eq(requested, "res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn"),
		assert_eq(default_workspace, "catalog"),
		assert_eq(settings_requested, "res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn"),
		assert_eq(settings_workspace, "settings"),
	])


func test_native_local_history_launches_the_formal_battle_scene_player() -> String:
	var artifact: Dictionary = FixtureFactoryScript.load_developer_artifact()
	if artifact.is_empty():
		return "tracked Marnie public replay fixture could not be decoded"
	var contracts: Dictionary = ContractsScript.load_default()
	if not bool(contracts.get("accepted", false)):
		return "replay contracts unavailable: %s" % contracts
	var library := FakeLocalLibrary.new(artifact)
	var hub := HubScene.instantiate()
	hub.configure_local_replay_for_test(contracts.owner, library)
	hub.call("configure_native_replay_for_test", FakeNativeMatchIndex.new(), FakeReplayLocator.new())
	var tree := Engine.get_main_loop() as SceneTree
	GameManager.set_scene_navigation_suppressed_for_tests(true)
	tree.root.add_child(hub)
	await tree.process_frame
	var local_list := hub.get_node("%LocalReplayList") as VBoxContainer
	var watch: Button = null
	var local_child_names: Array[String] = []
	for child: Node in local_list.find_children("*", "", true, false):
		local_child_names.append("%s:%s" % [child.name, child.get_class()])
		if child is Button and child.name == "NativeReplayWatchButton":
			watch = child as Button
	if watch != null:
		watch.pressed.emit()
	var requested_scene := GameManager.consume_last_requested_scene_path()
	var launch: Dictionary = GameManager.consume_battle_replay_launch()
	var status := str((hub.get_node("%StatusLabel") as Label).text)
	var watch_exists := watch != null
	GameManager.set_scene_navigation_suppressed_for_tests(false)
	tree.root.remove_child(hub)
	hub.free()
	return run_checks([
		assert_true(watch_exists, "local replay controls: %s" % [local_child_names]),
		assert_eq(library.load_count, 0, "Native replay must not go through the public shell viewer"),
		assert_eq(requested_scene, GameManager.SCENE_BATTLE),
		assert_eq(launch.get("match_dir"), "user://match_records/native-ai-match"),
		assert_eq(launch.get("view_player_index"), 0),
		assert_str_contains(status, "完整录像"),
	])


func test_strategy_hub_collapses_public_copy_when_complete_native_replay_exists() -> String:
	var hub := HubScene.instantiate()
	var native := {
		"match_id": "match_20260823_193412_611212",
		"match_dir": "user://match_records/match_20260823_193412_611212",
		"mode": "vs_author_strategy_ai",
		"recorded_at": "2026-08-23T19:34:12",
		"started_at_utc": "2026-08-23T11:34:12Z",
		"turn_count": 12,
		"winner_index": 0,
		"player_labels": ["玩家", "AI"],
		"view_player_index": 0,
	}
	var public_copy := {
		"source": "local",
		"replay_id": "community-windows-player-1787484852-226861300",
		"match_id": "windows-player-1787484852-226861300",
		"frame_count": 156,
		"started_at_utc": "2026-08-23T11:34:13Z",
	}
	hub.call("_render_local_replays", [native], [public_copy], 0)
	var list := hub.get_node("%LocalReplayList") as VBoxContainer
	var native_cards := list.find_children("NativeReplayCard", "PanelContainer", true, false)
	var incomplete_cards := list.find_children("IncompleteReplayCard", "PanelContainer", true, false)
	var count_label := hub.get_node("%LocalReplayCountLabel") as Label
	var checks := run_checks([
		assert_eq(native_cards.size(), 1, "The complete native replay must remain visible"),
		assert_eq(incomplete_cards.size(), 0, "A public-only copy from the same match must not appear as a second disabled replay"),
		assert_eq(count_label.text, "1 场", "Replay count should reflect unique matches rather than storage copies"),
	])
	hub.free()
	return checks


func test_strategy_hub_keeps_distinct_or_nonlocal_public_replays() -> String:
	var hub := HubScene.instantiate()
	var native := {
		"match_id": "match_20260823_193412_611212",
		"match_dir": "user://match_records/match_20260823_193412_611212",
		"mode": "vs_author_strategy_ai",
		"recorded_at": "2026-08-23T19:34:12",
		"started_at_utc": "2026-08-23T11:34:12Z",
		"turn_count": 12,
		"winner_index": 0,
		"player_labels": ["玩家", "AI"],
		"view_player_index": 0,
	}
	var public_only := {
		"source": "local",
		"replay_id": "community-another-match",
		"match_id": "another-match",
		"frame_count": 40,
		"started_at_utc": "2026-08-23T12:34:12Z",
	}
	hub.call("_render_local_replays", [native], [public_only], 0)
	var list := hub.get_node("%LocalReplayList") as VBoxContainer
	var checks := run_checks([
		assert_eq(list.find_children("NativeReplayCard", "PanelContainer", true, false).size(), 1),
		assert_eq(list.find_children("IncompleteReplayCard", "PanelContainer", true, false).size(), 1, "An unrelated public-only replay must remain visible"),
		assert_eq((hub.get_node("%LocalReplayCountLabel") as Label).text, "2 场"),
	])
	hub.free()
	return checks


func test_strategy_hub_confirmed_native_replay_delete_includes_merged_public_copy() -> String:
	var hub := HubScene.instantiate()
	if not hub.has_method("configure_replay_removal_service_for_test"):
		hub.free()
		return "Strategy Hub does not expose an isolated replay-removal seam"
	var native := {
		"match_id": "native-delete-match",
		"match_dir": "user://match_records/native-delete-match",
		"mode": "vs_ai",
		"recorded_at": "2026-08-23T19:34:12",
		"started_at_utc": "2026-08-23T11:34:12Z",
		"turn_count": 8,
		"winner_index": 0,
		"player_labels": ["玩家", "AI"],
	}
	var public_copy := {
		"source": "local",
		"replay_id": "public-copy-delete",
		"native_match_id": "native-delete-match",
		"match_id": "public-match",
		"frame_count": 20,
		"started_at_utc": "2026-08-23T11:34:12Z",
	}
	var fake := FakeReplayRemovalService.new()
	hub.call("configure_replay_removal_service_for_test", fake)
	hub.call("select_workspace_for_test", "replays")
	hub.call("_render_local_replays", [native], [public_copy], 0)
	var delete_button := hub.get_node("%LocalReplayList").find_child(
		"NativeReplayDeleteButton", true, false
	) as Button
	if delete_button == null:
		hub.free()
		return "Native replay card did not expose delete"
	delete_button.pressed.emit()
	var dialog := hub.get_node_or_null("%LocalReplayDeleteDialog") as ConfirmationDialog
	if dialog == null:
		hub.free()
		return "Replay delete confirmation dialog is missing"
	var pending: Dictionary = hub.get("_pending_local_replay_delete_ref")
	hub.call("_on_local_replay_delete_confirmed")
	var checks := run_checks([
		assert_true(dialog.visible, "Replay deletion must require confirmation"),
		assert_eq(pending.get("kind"), "native"),
		assert_eq(pending.get("public_replay_ids"), ["public-copy-delete"]),
		assert_eq(fake.calls, [{
			"kind": "native",
			"match_id": "native-delete-match",
			"match_dir": "user://match_records/native-delete-match",
			"public_replay_ids": ["public-copy-delete"],
		}]),
		assert_str_contains((hub.get_node("%StatusLabel") as Label).text, "已删除"),
	])
	hub.free()
	return checks


func test_strategy_hub_confirmed_public_only_replay_delete_uses_exact_replay_id() -> String:
	var hub := HubScene.instantiate()
	if not hub.has_method("configure_replay_removal_service_for_test"):
		hub.free()
		return "Strategy Hub does not expose an isolated replay-removal seam"
	var public_only := {
		"source": "local",
		"replay_id": "public-only-delete",
		"match_id": "public-only-match",
		"frame_count": 20,
		"started_at_utc": "2026-08-23T11:34:12Z",
	}
	var fake := FakeReplayRemovalService.new()
	hub.call("configure_replay_removal_service_for_test", fake)
	hub.call("select_workspace_for_test", "replays")
	hub.call("_render_local_replays", [], [public_only], 0)
	var delete_button := hub.get_node("%LocalReplayList").find_child(
		"PublicReplayDeleteButton", true, false
	) as Button
	if delete_button == null:
		hub.free()
		return "Public-only replay card did not expose delete"
	delete_button.pressed.emit()
	hub.call("_on_local_replay_delete_confirmed")
	var checks := run_checks([
		assert_eq(fake.calls, [{"kind": "public", "replay_id": "public-only-delete"}]),
		assert_str_contains((hub.get_node("%StatusLabel") as Label).text, "已删除"),
	])
	hub.free()
	return checks
