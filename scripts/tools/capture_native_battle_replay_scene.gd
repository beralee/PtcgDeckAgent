extends SceneTree

const DEFAULT_MATCH_DIR := "user://match_records/match_20260809_153147_162118"
const OUTPUT_ROOT := "res://artifacts/ptcgdap/d088_native_battle_scene_replay"
const TARGET_FRAME_INDEX := 31


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1600, 900)
	var match_dir := OS.get_environment("PTCGDAP_NATIVE_REPLAY_MATCH_DIR").strip_edges()
	if match_dir.is_empty():
		match_dir = DEFAULT_MATCH_DIR
	if not FileAccess.file_exists(match_dir.path_join("detail.jsonl")):
		_finish_with_error("native_match_missing")
		return
	var battle_scene := load("res://scenes/battle/BattleScene.tscn") as PackedScene
	if battle_scene == null:
		_finish_with_error("battle_scene_missing")
		return
	var game_manager := root.get_node_or_null("GameManager")
	if game_manager == null:
		_finish_with_error("game_manager_missing")
		return
	game_manager.set("current_mode", 0)
	game_manager.call("set_battle_replay_launch", {
		"match_dir": match_dir,
		"entry_turn_number": 3,
		"entry_source": "visual_acceptance",
		"turn_numbers": [1, 2, 3],
		"view_player_index": 0,
		"selected_deck_ids": [645436, 654034],
		"player_labels": ["宁波第28名竹兰烈咬陆鲨", "宁波亚军喷火龙大比鸟"],
	})
	var scene: Control = battle_scene.instantiate()
	root.add_child(scene)
	for _frame: int in 24:
		await process_frame
	var timeline: Array = scene.get("_replay_timeline")
	if timeline.size() <= TARGET_FRAME_INDEX:
		_finish_with_error("native_timeline_incomplete")
		return
	scene.call("_load_replay_frame", TARGET_FRAME_INDEX, false)
	for _frame: int in 16:
		await process_frame
	var hand_container := scene.find_child("HandContainer", true, false) as HBoxContainer
	var hand_scroll := scene.find_child("HandScroll", true, false) as ScrollContainer
	var hand_cards: Array[BattleCardView] = []
	if hand_container != null:
		for child: Node in hand_container.get_children():
			if child is BattleCardView:
				hand_cards.append(child as BattleCardView)
	if hand_cards.size() != 7:
		_finish_with_error("recorded_hand_not_rendered")
		return
	var hand_surface_ok := _cards_within_visible_hand_surface(hand_cards, hand_scroll)
	if not hand_surface_ok:
		_finish_with_error("hand_surface_clipped")
		return
	var public_shell_node := scene.find_child("PublicReplayBattleBackdrop", true, false)
	if public_shell_node != null:
		_finish_with_error("public_shell_renderer_present")
		return
	var play_button := scene.find_child("BtnReplayPlayPause", true, false) as Button
	var speed_option := scene.find_child("OptReplaySpeed", true, false) as OptionButton
	var continue_button := scene.find_child("BtnReplayContinue", true, false) as Button
	if play_button == null or speed_option == null or not play_button.visible or not speed_option.visible:
		_finish_with_error("native_player_controls_missing")
		return
	if continue_button != null and continue_button.visible:
		_finish_with_error("continue_from_replay_visible")
		return
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		_finish_with_error("rendering_driver_no_viewport_texture")
		return
	var image := viewport_texture.get_image()
	if image == null:
		_finish_with_error("rendering_driver_no_viewport_image")
		return
	var absolute_root := ProjectSettings.globalize_path(OUTPUT_ROOT)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_root)
	if dir_error not in [OK, ERR_ALREADY_EXISTS]:
		_finish_with_error("output_directory_failed")
		return
	var image_path := absolute_root.path_join("native_battle_scene_frame_031.png")
	if image.save_png(image_path) != OK:
		_finish_with_error("screenshot_write_failed")
		return
	var gsm := scene.get("_gsm") as GameStateMachine
	var state := gsm.game_state if gsm != null else null
	var hand_card_names: Array[String] = []
	for card: BattleCardView in hand_cards:
		hand_card_names.append(
			card.card_instance.card_data.name
			if card.card_instance != null and card.card_instance.card_data != null else ""
		)
	var report := {
		"document_type": "ptcgdap_native_battle_scene_replay_visual_acceptance_v1",
		"source_match_dir": match_dir,
		"target_frame_index": TARGET_FRAME_INDEX,
		"timeline_count": timeline.size(),
		"battle_mode": str(scene.get("_battle_mode")),
		"view_player_index": int(scene.get("_view_player")),
		"current_player_index": state.current_player_index if state != null else -1,
		"turn_number": state.turn_number if state != null else -1,
		"hand_card_count": hand_cards.size(),
		"hand_card_names": hand_card_names,
		"hand_surface_ok": hand_surface_ok,
		"battle_scene_script": str(scene.get_script().resource_path),
		"formal_display_controller": "res://scripts/ui/battle/BattleDisplayController.gd",
		"formal_visual_sequence_controller": "res://scripts/ui/battle/visuals/BattleVisualSequenceController.gd",
		"public_shell_renderer_present": false,
		"continue_from_replay_visible": false,
		"viewport": {"width": image.get_width(), "height": image.get_height()},
		"screenshot_sha256": _sha256(FileAccess.get_file_as_bytes(image_path)),
		"authoritative_rules_execution": false,
		"replay_navigation_only": true,
	}
	var report_file := FileAccess.open(absolute_root.path_join("visual_acceptance.json"), FileAccess.WRITE)
	if report_file == null:
		_finish_with_error("report_write_failed")
		return
	report_file.store_string(JSON.stringify(report, "\t"))
	report_file.close()
	print("PTCGDAP_NATIVE_BATTLE_REPLAY_VISUAL_ACCEPTANCE %s" % JSON.stringify(report))
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _cards_within_visible_hand_surface(cards: Array[BattleCardView], hand_scroll: ScrollContainer) -> bool:
	if hand_scroll == null:
		return false
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(root.size))
	var scroll_rect := hand_scroll.get_global_rect().intersection(viewport_rect)
	if scroll_rect.size.x <= 0.0 or scroll_rect.size.y <= 0.0:
		return false
	for card: BattleCardView in cards:
		var rect := card.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return false
		# Horizontal overflow is owned by the real ScrollContainer. Vertically every
		# card must remain completely inside the visible hand rail.
		if rect.position.y < scroll_rect.position.y - 1.0 or rect.end.y > scroll_rect.end.y + 1.0:
			return false
	return true


func _finish_with_error(code: String) -> void:
	push_error("PTCGDAP native battle replay visual capture failed: %s" % code)
	quit(1)


static func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode().to_upper()
