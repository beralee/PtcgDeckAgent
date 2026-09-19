## Opt-in real provider -> game card cache -> save -> reload acceptance.
## Run with an isolated APPDATA, --live, and optionally --capture (rendered Godot).
extends SceneTree

const Source := preload("res://scripts/network/MiniappDeckSource.gd")
const CODE := "dFJ1jZgeo_xEbSTvjj"
var _finished := false
var _deck: DeckData
var _warnings := PackedStringArray()
var _failure := ""
var _capture := false
var _viewport: SubViewport


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_capture = "--capture" in args and DisplayServer.get_name() != "headless"
	var live := "--live" in args
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var scene: Control = load("res://scenes/deck_manager/DeckManager.tscn").instantiate()
	_viewport.add_child(scene)
	scene._apply_non_battle_layout_for_tests(Vector2(1280, 720), "landscape")
	scene._on_import_pressed()
	scene._select_import_source("miniapp")
	scene._apply_import_paste_text_for_tests(CODE)
	await _screenshot("miniapp-desktop")
	if live:
		scene._importer.import_completed.connect(func(deck: DeckData, warnings: PackedStringArray):
			_deck = deck
			_warnings = warnings
			_finished = true)
		scene._importer.import_failed.connect(func(message: String):
			_failure = message
			_finished = true)
		scene._on_do_import()
		var deadline := Time.get_ticks_msec() + 180000
		while not _finished and Time.get_ticks_msec() < deadline:
			await process_frame
		if not _finished:
			_failure = "Timed out waiting for live import"
	else:
		var decoded := Source.decode_response(FileAccess.get_file_as_bytes("res://tests/fixtures/deck_import/miniapp_raging_bolt.json"), CODE)
		_deck = decoded.get("deck")
		scene._import_panel_ui.show_success(_deck, "导入成功：猛雷鼓 厄诡椪（60 张卡）")
	if _deck != null and live:
		if scene._pending_import_deck != null:
			# Exercise the normal duplicate-name dialog; a bundled deck has this name.
			scene._rename_input.text = "小程序 · " + _deck.deck_name
			scene._on_confirm_import_rename()
		var saved_path := "user://decks/%d.json" % _deck.id
		if not FileAccess.file_exists(saved_path):
			printerr("Live import did not save a deck: ", scene.get_node("%ProgressLabel").text)
			quit(1)
			return
		var restored := DeckData.from_dict(JSON.parse_string(FileAccess.get_file_as_string(saved_path)))
		if restored.id != _deck.id or restored.source_id != CODE or restored.total_cards != 60 or restored.cards.size() != 31:
			_failure = "Saved deck did not preserve identity or exact 60-card list"
		var db := root.get_node("CardDatabase")
		for entry: Dictionary in restored.cards:
			if db.call("get_card", entry.set_code, entry.card_index) == null:
				_failure = "Missing playable card: " + entry.set_code + "/" + entry.card_index
		print("MINIAPP_LIVE_RESULT ", JSON.stringify({"ok": _failure == "", "name": restored.deck_name, "id": restored.id, "total": restored.total_cards, "printings": restored.cards.size(), "warnings": Array(_warnings), "error": _failure}))
	await _screenshot("miniapp-success")
	scene._on_import_pressed()
	_viewport.size = Vector2i(390, 844)
	scene._apply_non_battle_layout_for_tests(Vector2(390, 844), "portrait")
	scene._select_import_source("miniapp")
	await _screenshot("miniapp-phone")
	scene._select_import_source("image")
	await _screenshot("miniapp-image-mode")
	_viewport.queue_free()
	await process_frame
	if _failure != "":
		printerr(_failure)
	quit(0 if _failure == "" else 1)


func _screenshot(name: String) -> void:
	if not _capture:
		return
	for _i: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tmp/miniapp-import")
	_viewport.get_texture().get_image().save_png("res://tmp/miniapp-import/%s.png" % name)
