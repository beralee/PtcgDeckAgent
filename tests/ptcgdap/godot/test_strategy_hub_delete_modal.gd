extends TestBase

const HubScene = preload("res://scenes/ptcgdap_strategy_hub/StrategyHub.tscn")
const REF := {"package_id": "delete.touch.test", "package_version": "1.0.0", "archive_sha256": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}

class DeleteCatalog extends RefCounted:
	var calls: Array = []
	var succeeds := true
	func remove_package(id: String, version: String, sha: String) -> Dictionary:
		calls.append({"package_id": id, "package_version": version, "archive_sha256": sha})
		return {"ok": succeeds, "error_code": "" if succeeds else "package_remove_failed", "catalog_discoverable": false,
			"catalog_report": {"metadata_records": [], "ready_records": [], "diagnostics": []}}

func _seed(hub: Control) -> void:
	hub.call("apply_local_package_catalog_for_test", {"metadata_records": [REF.merged({
		"install_source": "user", "install_sources": ["user"], "status": "metadata_only",
		"author": {"display_name": "测试作者"}, "strategy": {"display_name": "触摸删除测试策略"}, "deck": {"display_name": "测试卡组"}})],
		"ready_records": [], "diagnostics": []})

func _touch(hub: Control, position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = position
		event.pressed = pressed
		hub.call("_input", event)

func test_delete_confirmation_uses_readable_in_page_hud() -> String:
	var hub := HubScene.instantiate()
	var modal := hub.get_node("%LocalPackageDeleteDialog")
	if modal is Window:
		hub.free()
		return "Delete confirmation must use the HUD Control surface, not a separate Window"
	hub.call("_apply_hud_theme")
	hub.call("_apply_non_battle_layout", Vector2(900, 1800), "portrait")
	_seed(hub)
	hub.call("_on_local_package_delete_requested", REF)
	var message := hub.get_node("%LocalPackageDeleteMessage") as Label
	var panel := hub.get_node("%LocalPackageDeletePanel") as PanelContainer
	var checks := run_checks([
		assert_true(modal.visible),
		assert_str_contains(message.text, "触摸删除测试策略"),
		assert_true(message.get_theme_font_size("font_size") >= 36),
		assert_true(panel.has_theme_stylebox_override("panel")),
	])
	hub.free()
	return checks

func test_delete_hud_touch_cancel_confirm_and_failure_release_modal() -> String:
	var hub := HubScene.instantiate() as Control
	if hub.get_node("%LocalPackageDeleteDialog") is Window:
		hub.free()
		return "Native confirmation is outside the HUD touch scope"
	hub.set("_skip_service_initialization_for_tests", true)
	var catalog := DeleteCatalog.new()
	hub.call("configure_package_delete_catalog_for_test", catalog)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(hub)
	for i: int in 4:
		await tree.process_frame
	# Keep the isolated fake library from being replaced by the global deferred scan.
	var catalog_callback := Callable(hub, "_apply_local_package_catalog")
	if AuthorStrategyPackageCatalog.catalog_changed.is_connected(catalog_callback):
		AuthorStrategyPackageCatalog.catalog_changed.disconnect(catalog_callback)
	await tree.process_frame
	hub.call("_apply_non_battle_layout", Vector2(900, 1800), "portrait")
	hub.call("select_workspace_for_test", "local")
	_seed(hub)
	hub.call("_on_local_package_delete_requested", REF)
	await tree.process_frame
	var cancel := hub.get_node("%LocalPackageDeleteCancel") as Button
	var confirm := hub.get_node("%LocalPackageDeleteConfirm") as Button
	var checks: Array[String] = [assert_true(hub.get_node("%LocalPackageDeleteDialog").visible)]
	_touch(hub, cancel.get_global_rect().get_center())
	checks.append_array([
		assert_false(hub.get_node("%LocalPackageDeleteDialog").visible, "Touch cancel must close the modal"),
		assert_eq(catalog.calls.size(), 0),
		assert_eq(hub.get("_pending_local_package_delete_ref"), {}),
	])
	hub.call("_on_local_package_delete_requested", REF)
	var back := InputEventAction.new()
	back.action = "ui_cancel"
	back.pressed = true
	hub.call("_input", back)
	checks.append(assert_false(hub.get_node("%LocalPackageDeleteDialog").visible))
	checks.append(assert_eq(catalog.calls.size(), 0))
	hub.call("_on_local_package_delete_requested", REF)
	hub.notification(Control.NOTIFICATION_WM_GO_BACK_REQUEST)
	checks.append(assert_false(hub.get_node("%LocalPackageDeleteDialog").visible))
	hub.call("_on_local_package_delete_requested", REF)
	await tree.process_frame
	checks.append(assert_true(hub.get_node("%LocalPackageDeleteDialog").visible))
	_touch(hub, confirm.get_global_rect().get_center())
	hub.call("_on_local_package_delete_confirmed")
	checks.append(assert_false(hub.get_node("%LocalPackageDeleteDialog").visible, "Hide before deletion awaits or rebuilds the list"))
	await tree.process_frame
	await tree.process_frame
	checks.append(assert_eq(catalog.calls, [REF]))
	checks.append(assert_false(hub.get("_local_package_import_busy")))
	_seed(hub)
	catalog.succeeds = false
	hub.call("_on_local_package_delete_requested", REF)
	await tree.process_frame
	_touch(hub, confirm.get_global_rect().get_center())
	await tree.process_frame
	await tree.process_frame
	checks.append(assert_false(hub.get("_local_package_import_busy")))
	checks.append(assert_false(hub.get_node("%LocalPackageDeleteDialog").visible))
	checks.append(assert_eq((hub.get("_local_package_records") as Array).size(), 1))
	_touch(hub, hub.get_node("%CatalogTab").get_global_rect().get_center())
	checks.append(assert_eq(hub.get("_active_workspace"), "catalog", "Page tabs must remain usable after closing the modal"))
	hub.free()
	return run_checks(checks)
