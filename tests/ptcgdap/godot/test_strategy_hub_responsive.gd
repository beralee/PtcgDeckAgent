extends TestBase

const HubScene = preload("res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn")
const HubScript = preload("res://scenes/ptcgdap_strategy_hub/StrategyHub.gd")


func test_safe_area_converts_physical_screen_coordinates_to_local_units() -> String:
	var local_to_screen := Transform2D(Vector2(2, 0), Vector2(0, 2), Vector2(100, 50))
	var content: Rect2 = HubScript.content_rect_from_screen_safe_area(
		Rect2(0, 0, 400, 800), Rect2(120, 90, 760, 1400), local_to_screen
	)
	return assert_eq(content, Rect2(10, 20, 380, 700))


func test_narrow_landscape_collapses_and_layout_sizes_are_reversible() -> String:
	var hub := HubScene.instantiate()
	hub.call("apply_non_battle_layout_for_test", Vector2(430, 932), "landscape")
	var checks: Array[String] = [
		assert_eq(hub.get_node("%AISettingsTab").text, "DeepSeek"),
		assert_eq(hub.get_node("%CatalogColumns").columns, 1),
		assert_eq(hub.get_node("%LocalStrategyColumns").columns, 1),
		assert_true(hub.get_node("%WorkspaceTabs") is GridContainer),
		assert_eq(hub.find_child("StrategyRankingScroll", true, false).vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED),
		assert_eq(hub.find_child("PackageLibraryPanel", true, false).custom_minimum_size.y, 0.0),
	]
	hub.call("apply_non_battle_layout_for_test", Vector2(1600, 900), "landscape")
	checks.append(assert_eq(hub.get_node("%AISettingsTab").text, "DeepSeek"))
	# Both player libraries use one readable column with actions above the list.
	checks.append(assert_eq(hub.get_node("%CatalogColumns").columns, 1))
	checks.append(assert_eq(hub.get_node("%LocalStrategyColumns").columns, 1))
	checks.append(assert_eq(hub.get_node("%ImportLocalPackageButton").custom_minimum_size.y, 52.0))
	hub.call("apply_non_battle_layout_for_test", Vector2(430, 932), "portrait")
	checks.append(assert_eq(hub.get_node("%AISettingsTab").text, "DeepSeek"))
	hub.call("apply_non_battle_layout_for_test", Vector2(1600, 900), "landscape")
	checks.append(assert_eq(hub.get_node("%ImportLocalPackageButton").custom_minimum_size.y, 52.0))
	hub.free()
	return run_checks(checks)


func test_actual_subviewport_contains_tabs_long_rows_and_embedded_settings() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(390, 844)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(viewport)
	var hub := HubScene.instantiate()
	hub.set("_skip_service_initialization_for_tests", true)
	viewport.add_child(hub)
	for frame in range(4):
		await tree.process_frame
	hub.call("apply_marketplace_latest_for_test", [{
		"strategy_id": "responsive-test",
		"display_name": "这是一个需要完整换行展示的很长的中文策略名称和说明内容",
		"author_display_name": "长作者名称",
		"download_available": false,
	}], null)
	for frame in range(5):
		await tree.process_frame
	var checks: Array[String] = []
	for control_name: String in ["CatalogTab", "LocalStrategyTab", "ReplayTab", "AISettingsTab", "MarketplaceDownloadButton"]:
		var control := hub.find_child(control_name, true, false) as Control
		checks.append(assert_true(control != null, control_name))
		if control != null:
			checks.append(assert_true(control.get_global_rect().end.x <= 390.5, "%s exceeds allocated viewport" % control_name))
	await _capture_viewport_if_requested(viewport, "strategy-hub-390-catalog")
	hub.call("select_workspace_for_test", "settings")
	for frame in range(8):
		await tree.process_frame
	var settings := hub.find_child("AISettingsContent", true, false) as Control
	var form := settings.get_node("VBoxContainer") as Control
	checks.append(assert_true(form.get_global_rect().position.x >= settings.get_global_rect().position.x - 0.5, "embedded form starts outside parent"))
	checks.append(assert_true(form.get_global_rect().end.x <= settings.get_global_rect().end.x + 0.5, "embedded form overflows parent"))
	checks.append(assert_true(settings.custom_minimum_size.y >= form.get_combined_minimum_size().y, "outer scroll owns complete form height"))
	await _capture_viewport_if_requested(viewport, "strategy-hub-390-settings")
	settings.call("_ensure_settings_model_picker_overlay")
	settings.call("_refresh_settings_model_picker_layout")
	var picker := settings.find_child("AISettingsModelPickerOverlay", true, false) as Control
	var workspace := hub.get_node("%AISettingsWorkspace") as ScrollContainer
	checks.append(assert_eq(picker.size, workspace.size))
	checks.append(assert_eq((settings.find_child("AISettingsModelPickerScroll", true, false) as Control).custom_minimum_size.y, 0.0))
	viewport.size = Vector2i(1600, 900)
	for frame in range(5):
		await tree.process_frame
	checks.append(assert_eq((settings.find_child("EmbeddedSettingsColumns", true, false) as GridContainer).columns, 2))
	checks.append(assert_true(workspace.visible, "resize preserves selected workspace"))
	hub.queue_free()
	await tree.process_frame
	viewport.queue_free()
	await tree.process_frame
	return run_checks(checks)


func _capture_viewport_if_requested(viewport: SubViewport, file_name: String) -> void:
	if not "--capture-ui" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var output_dir := "res://.godot_test_user/ui-captures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	viewport.get_texture().get_image().save_png(output_dir.path_join(file_name + ".png"))


func test_hundred_wrapped_records_have_one_scroll_and_remain_reachable_after_resize() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = Vector2i(390, 844)
	tree.root.add_child(viewport)
	var hub := HubScene.instantiate()
	hub.set("_skip_service_initialization_for_tests", true)
	viewport.add_child(hub)
	await tree.process_frame
	var records: Array[Dictionary] = []
	for index in range(100):
		records.append({
			"package_id": "layout.%d" % index, "package_version": "1.0.0",
			"archive_sha256": "A".repeat(64), "install_source": "user", "install_sources": ["user"],
			"author": {"display_name": "作者"}, "status": "metadata_only",
			"strategy": {"display_name": "很长的中文策略名称需要换行展示以便玩家区分版本%d" % index},
			"deck": {"display_name": "测试牌组"},
		})
	hub.call("apply_local_package_catalog_for_test", {"metadata_records": records, "ready_records": [], "diagnostics": []})
	hub.call("select_workspace_for_test", "local")
	for frame in range(8):
		await tree.process_frame
	var workspace := hub.get_node("%LocalStrategyWorkspace") as ScrollContainer
	var list := hub.get_node("%LocalPackageList") as Control
	var last_card := list.get_child(99) as Control
	var checks: Array[String] = [
		assert_eq(list.get_child_count(), 100),
		assert_true(list.size.y >= 100 * 100.0, "all record heights participate in outer scroll extent"),
		assert_true(last_card.get_global_rect().end.x <= 390.5),
	]
	workspace.scroll_vertical = 600
	var previous_emulation := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = workspace.get_global_rect().position + Vector2(8, workspace.size.y - 30)
	var drag := InputEventScreenDrag.new()
	drag.position = press.position - Vector2(0, 100)
	var release := InputEventScreenTouch.new()
	release.position = drag.position
	if hub.has_method("_input"):
		hub.call("_input", press)
		hub.call("_input", drag)
		hub.call("_input", release)
	checks.append(assert_true(workspace.scroll_vertical > 600, "touch drag works without mouse emulation"))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulation)
	viewport.size = Vector2i(430, 932)
	for frame in range(6):
		await tree.process_frame
	checks.append(assert_true(workspace.scroll_vertical > 0, "resize must not reset scroll"))
	workspace.ensure_control_visible(last_card)
	for frame in range(3):
		await tree.process_frame
	checks.append(assert_true(last_card.get_global_rect().end.y <= workspace.get_global_rect().end.y + 1.0, "last row can be scrolled fully into view"))
	hub.queue_free()
	await tree.process_frame
	viewport.queue_free()
	await tree.process_frame
	return run_checks(checks)
