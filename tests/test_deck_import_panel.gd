extends TestBase

const Scene := preload("res://scenes/deck_manager/DeckManager.tscn")
const CODE := "dFJ1jZgeo_xEbSTvjj"


func test_source_tabs_preserve_separate_drafts_and_image_instructions() -> String:
	var scene := Scene.instantiate()
	scene._on_import_pressed()
	var input := scene.get_node("%UrlInput") as LineEdit
	input.text = "574793"
	scene._select_import_source("miniapp")
	input.text = CODE
	scene._select_import_source("image")
	var image_visible: bool = scene.find_child("BtnImageImport", true, false).visible
	var input_hidden := not input.visible
	scene._select_import_source("website")
	var website_draft := input.text
	scene._select_import_source("miniapp")
	var result := run_checks([
		assert_true(image_visible and input_hidden, "Image mode shows one relevant action and no URL field"),
		assert_eq(website_draft, "574793", "Website draft retained"),
		assert_eq(input.text, CODE, "Miniapp draft retained"),
		assert_str_contains(scene.find_child("HintLabel", true, false).text, "18 位", "Source-specific instructions"),
	])
	scene.free()
	return result


func test_pasted_miniapp_id_is_detected_and_invalid_input_stays_editable() -> String:
	var scene := Scene.instantiate()
	scene._on_import_pressed()
	scene._apply_import_paste_text_for_tests(CODE)
	var detected: String = scene._import_panel_ui.source
	scene.get_node("%UrlInput").text = "broken"
	scene._on_do_import()
	var result := run_checks([
		assert_eq(detected, "miniapp", "Paste auto-selects the right source"),
		assert_eq(scene._current_operation, "", "Invalid IDs never start a request"),
		assert_true(scene.get_node("%UrlInput").editable, "Invalid input remains editable"),
		assert_eq(scene.get_node("%UrlInput").text, "broken", "Failure preserves input"),
		assert_eq(scene._import_panel_ui.state, "error", "Inline error state"),
	])
	scene.free()
	return result


func test_busy_source_switch_and_second_submit_cannot_replace_request() -> String:
	var scene := Scene.instantiate()
	scene._on_import_pressed()
	scene._select_import_source("miniapp")
	scene._start_import_from_url(CODE, "正在读取…")
	scene._select_import_source("image")
	scene._on_do_import()
	var result := run_checks([
		assert_eq(scene._import_panel_ui.source, "miniapp", "Busy source cannot change"),
		assert_eq(scene._pending_import_start_url, CODE, "First request remains queued"),
		assert_true(scene.get_node("%BtnCloseImport").disabled, "Busy modal cannot hide its result"),
		assert_false(scene.get_node("%UrlInput").editable, "Busy input locked"),
	])
	scene.free()
	return result


func test_failed_miniapp_import_can_retry_same_code() -> String:
	var scene := Scene.instantiate()
	scene._on_import_pressed()
	scene._start_import_from_url(CODE, "正在读取…")
	scene._pending_import_start_url = ""
	scene._on_import_failed("网络中断")
	var retained: String = scene.get_node("%UrlInput").text
	var editable: bool = scene.get_node("%UrlInput").editable
	scene._on_do_import()
	var result := run_checks([
		assert_eq(retained, CODE, "Network failure retains code"),
		assert_true(editable, "Player can correct or retry"),
		assert_eq(scene._pending_import_start_url, CODE, "Retry queues the same code"),
	])
	scene.free()
	return result


func test_import_modal_fits_landscape_and_phone_viewports() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(390, 844), Vector2i(844, 390)]:
		var viewport := SubViewport.new()
		viewport.size = dimensions
		tree.root.add_child(viewport)
		var scene := Scene.instantiate()
		viewport.add_child(scene)
		scene._apply_non_battle_layout_for_tests(Vector2(dimensions), "portrait" if dimensions.x < dimensions.y else "landscape")
		scene._on_import_pressed()
		scene._select_import_source("miniapp")
		await tree.process_frame
		await tree.process_frame
		var box := scene.find_child("ImportBox", true, false) as Control
		var rect := box.get_global_rect()
		var primary := scene.get_node("%BtnDoImport") as Control
		var input := scene.get_node("%UrlInput") as Control
		var scroll := scene.find_child("ImportScroll", true, false) as ScrollContainer
		var result := run_checks([
			assert_true(rect.position.x >= 0 and rect.end.x <= dimensions.x + 1, "Modal fits viewport width %s" % dimensions),
			assert_true(rect.position.y >= 0 and rect.end.y <= dimensions.y + 1, "Modal fits viewport height %s" % dimensions),
			assert_true(input.get_global_rect().end.x <= rect.end.x and primary.get_global_rect().end.x <= rect.end.x, "Input and actions fit modal width"),
			assert_true(scroll.follow_focus, "Small screens can scroll to focused controls"),
		])
		viewport.queue_free()
		await tree.process_frame
		if result != "":
			return result
	return ""
