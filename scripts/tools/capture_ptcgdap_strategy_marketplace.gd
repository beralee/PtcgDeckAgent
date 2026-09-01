extends SceneTree

const OUTPUT_ROOT := "res://artifacts/ptcgdap/d126_strategy_marketplace_upgrade/visual"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var packed := load("res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn") as PackedScene
	if packed == null:
		_finish("strategy_hub_scene_unavailable")
		return
	var hub := packed.instantiate() as Control
	hub.set("_skip_service_initialization_for_tests", true)
	root.add_child(hub)
	for _frame: int in 8:
		await process_frame
	var release_a := _release(
		"release-marketplace-cynthia", "strategy.marketplace.cynthia",
		"package.marketplace.cynthia", "1.4.2", "A"
	)
	var release_b := _release(
		"release-marketplace-marnie", "strategy.marketplace.marnie",
		"package.marketplace.marnie", "2.1.0", "B"
	)
	var latest := [
		_item(
			"strategy.marketplace.cynthia", "竹兰烈咬陆鲨 · 稳健资源循环策略",
			"PtcgDAP Strategy Lab", "2026-08-24T19:26:00Z", release_a
		),
		_item(
			"strategy.marketplace.marnie", "玛俐长毛巨魔 · 中盘压制策略",
			"PtcgDAP", "2026-08-23T14:08:00Z", release_b
		),
	]
	hub.apply_marketplace_latest_for_test(latest, "next-latest-page")
	hub.apply_marketplace_strategy_rankings_for_test([
		_ranking_item(1, latest[0], 583333, 24, false),
		_ranking_item(2, latest[1], 416667, 12, true),
		{
			"rank": 3,
			"display_name": "仅比赛服的研究策略（尚未发布设备版）",
			"author_display_name": "Remote Researcher",
			"kaggle_score_micros": 250000,
			"win_rate_micros": 583333,
			"games": 12,
			"provisional": false,
			"download_available": false,
			"installable_release": null,
		},
	], null, "ranking-snapshot-20260824-v1")
	hub.apply_marketplace_author_rankings_for_test([
		_author_item(1, "competition.author.lab", "PtcgDAP Strategy Lab", 520833, 48, 3, false),
		_author_item(2, "competition.author.core", "PtcgDAP", 416667, 24, 2, false),
		_author_item(3, "competition.author.new", "超长作者名称用于窄屏自适应验证", 125000, 8, 0, true),
	], null, "author-snapshot-20260824-v1")
	hub.select_workspace_for_test("catalog")
	var output_root := ProjectSettings.globalize_path(OUTPUT_ROOT)
	if DirAccess.make_dir_recursive_absolute(output_root) not in [OK, ERR_ALREADY_EXISTS]:
		_finish("output_directory_failed")
		return
	var requests: Array[Dictionary] = []
	for layout: Dictionary in [
		{"prefix": "landscape", "size": Vector2i(1600, 900), "mode": "landscape"},
		{"prefix": "portrait", "size": Vector2i(600, 1000), "mode": "portrait"},
	]:
		for board: String in ["latest", "strategy_rankings", "author_rankings"]:
			requests.append({
				"name": "%s-%s" % [layout.prefix, board],
				"size": layout.size,
				"mode": layout.mode,
				"board": board,
			})
	var captures: Array[Dictionary] = []
	for request: Dictionary in requests:
		root.size = request.size
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		root.content_scale_size = request.size
		var game_manager := root.get_node_or_null("GameManager")
		if game_manager != null:
			game_manager.call("set_non_battle_layout_mode", str(request.mode), false, false)
		hub.apply_non_battle_layout_for_test(Vector2(request.size), str(request.mode))
		hub.select_marketplace_board_for_test(str(request.board))
		if request.board == "author_rankings":
			hub.apply_marketplace_author_strategies_for_test({
				"author_id": "competition.author.lab",
				"display_name": "PtcgDAP Strategy Lab",
			}, [latest[0]])
		else:
			hub.show_marketplace_strategy_for_test(
				latest[0] if request.board == "latest" else latest[1]
			)
		for _frame: int in 10:
			root.content_scale_size = request.size
			await process_frame
		var image := root.get_texture().get_image()
		if image == null:
			_finish("viewport_image_unavailable_%s" % request.name)
			return
		var path := "%s/%s.png" % [output_root, request.name]
		if image.save_png(path) != OK:
			_finish("screenshot_write_failed_%s" % request.name)
			return
		captures.append({
			"name": request.name,
			"board": request.board,
			"viewport": {"width": image.get_width(), "height": image.get_height()},
			"sha256": _sha(FileAccess.get_file_as_bytes(path)),
		})
	var report := {
		"document_type": "ptcgdap_strategy_marketplace_visual_acceptance_v1",
		"schema_version": 1,
		"captures": captures,
		"mock_data": true,
		"real_opengl_render": true,
		"production_service_connected": false,
		"official_cabt_validation": false,
		"artifact_domains": ["competition_ptcgbot", "device_ptcgai"],
	}
	var report_file := FileAccess.open("%s/visual_acceptance.json" % output_root, FileAccess.WRITE)
	if report_file == null:
		_finish("report_write_failed")
		return
	report_file.store_string(JSON.stringify(report, "\t"))
	report_file.close()
	print("PTCGDAP_STRATEGY_MARKETPLACE_VISUAL_ACCEPTANCE %s" % JSON.stringify(report))
	hub.queue_free()
	await process_frame
	quit(0)


func _release(
	release_id: String,
	strategy_id: String,
	package_id: String,
	version: String,
	sha_character: String
) -> Dictionary:
	return {
		"release_id": release_id,
		"strategy_id": strategy_id,
		"package_id": package_id,
		"package_version": version,
		"archive_sha256": sha_character.repeat(64),
		"manifest_canonical_sha256": "C".repeat(64),
		"author": {"author_id": "device.author", "display_name": "PtcgDAP Strategy Lab"},
		"strategy_display_name": strategy_id,
		"download_available": true,
		"artifact_domain": "device_ptcgai",
	}


func _item(
	strategy_id: String,
	display_name: String,
	author_name: String,
	published_at: String,
	release: Dictionary
) -> Dictionary:
	return {
		"strategy_id": strategy_id,
		"display_name": display_name,
		"summary": "以公开信息决策为边界，下载后由本机再次校验完整牌表和策略包。",
		"author": {"author_id": "device.author", "display_name": author_name},
		"author_display_name": author_name,
		"published_at_utc": published_at,
		"installable_release": release,
		"download_available": true,
	}


func _ranking_item(
	rank: int,
	item: Dictionary,
	score: int,
	games: int,
	provisional: bool
) -> Dictionary:
	var result := item.duplicate(true)
	result.merge({
		"rank": rank,
		"kaggle_score_micros": score,
		"win_rate_micros": 625000,
		"games": games,
		"provisional": provisional,
	}, true)
	return result


func _author_item(
	rank: int,
	author_id: String,
	display_name: String,
	score: int,
	games: int,
	works: int,
	provisional: bool
) -> Dictionary:
	return {
		"rank": rank,
		"author_id": author_id,
		"author_display_name": display_name,
		"kaggle_score_micros": score,
		"games": games,
		"published_strategy_count": works,
		"provisional": provisional,
	}


func _finish(code: String) -> void:
	push_error("PTCGDAP strategy marketplace capture failed: %s" % code)
	quit(1)


func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode().to_upper()
