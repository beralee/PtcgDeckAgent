extends SceneTree

const DeckPosterComposerScript := preload("res://scripts/deck_share/DeckPosterComposer.gd")

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var capture_size := Vector2i(1600, 900)
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--compact":
			capture_size = Vector2i(1280, 720)
	var output_path := "res://tmp/deck_recommendation_layout/desktop_overview_%dx%d.png" % [capture_size.x, capture_size.y]
	DisplayServer.window_set_size(capture_size)
	var deck_file := FileAccess.open("res://data/bundled_user/decks/610080.json", FileAccess.READ)
	if deck_file == null:
		push_error("Missing visual deck fixture")
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(deck_file.get_as_text())
	deck_file.close()
	if parsed is not Dictionary:
		push_error("Invalid visual deck fixture")
		quit(1)
		return
	var deck := DeckData.from_dict(parsed as Dictionary)
	var card_database := root.get_node_or_null("CardDatabase")
	var composed: Dictionary = await DeckPosterComposerScript.compose_desktop_overview_image(deck, "PTCG Train", card_database)
	var deck_image := composed.get("image", null) as Image
	if deck_image == null:
		push_error("Unable to compose visual deck image")
		quit(1)
		return
	var deck_manager_scene := load("res://scenes/deck_manager/DeckManager.tscn") as PackedScene
	var scene: Control = deck_manager_scene.instantiate()
	scene._test_deck_image_variant_override = "desktop_overview"
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scene)
	await process_frame
	DisplayServer.window_set_size(capture_size)
	await process_frame
	scene._apply_non_battle_layout_for_tests(Vector2(capture_size), "landscape")
	var recommendation := {
		"id": "visual-desktop-garden",
		"deck_id": 610080,
		"deck_name": "17.5沙奈朵",
		"title": "稳定进化，精确分配资源",
		"style_summary": "围绕沙奈朵ex建立能量循环，用低奖卡宝可梦持续交换节奏。",
		"why_play": [
			"卡组结构完整，进化线与检索配置清晰。",
			"面对不同对局时拥有灵活的攻击手选择。",
		],
		"best_for": "喜欢资源规划与中后期运营的玩家",
		"pilot_tip": "优先保证奇鲁莉安引擎稳定运转。",
		"import_url": "https://tcg.mik.moe/decks/list/610080",
		"generated_at": "2026-07-15T00:00:00Z",
		"source": {"label": "城市赛精选", "city": "沈阳", "rank": 1},
		"detail": {"sections": []},
	}
	scene._embedded_recommendations.assign([recommendation])
	scene._recommendation_articles.assign([recommendation])
	scene._current_recommendation = recommendation
	scene._store_recommendation_poster_cache(
		"visual-desktop-garden",
		deck,
		deck_image,
		ImageTexture.create_from_image(deck_image),
		recommendation
	)
	scene._recommendation_poster_states["visual-desktop-garden"] = "ready"
	scene._ensure_recommendation_section()
	scene._refresh_recommendation_cards()
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path.get_base_dir()))
	var image := root.get_texture().get_image()
	var err := image.save_png(output_path)
	print("DECK_RECOMMENDATION_CAPTURE ", output_path, " size=", image.get_size(), " state=", scene._recommendation_poster_states.get("visual-desktop-garden", ""), " err=", err)
	quit(0 if err == OK else 1)
